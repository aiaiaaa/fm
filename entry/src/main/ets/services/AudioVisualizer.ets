import { hilog } from '@kit.PerformanceAnalysisKit';
import { HlsAacTap } from './spectrum/HlsAacTap';
import spectrum from 'libxfm_spectrum.so';

const TAG = 'AudioVisualizer';
const BAND_COUNT = 16;

/**
 * 音频可视化服务
 *
 * 主路径（NDK 真 FFT）：
 *   m3u8 ──► HlsAacTap（旁路 TS demux，独立于 AVPlayer）
 *           ──► ADTS 帧 ──► NDK xfm_spectrum
 *                            ├─ OH_AudioCodec 解码 AAC -> PCM
 *                            └─ 1024-pt FFT -> 16 log-spaced bands
 *           ──► UI
 *
 * 降级（任何环节失败 / 未配置流地址）：
 *   多频率正弦叠加 + 随机扰动 → 16 频段
 */
export type SpectrumCallback = (bands: number[]) => void;

export class AudioVisualizer {
  private callback: SpectrumCallback | null = null;
  private active: boolean = false;
  private streamUrl: string = '';

  // 真实管线
  private tap: HlsAacTap | null = null;
  private nativeHandle: number = 0; // 0 = 未创建
  private receivedRealFrame: boolean = false;
  private healthCheckTimer: number = -1;

  // 降级管线
  private fallbackActive: boolean = false;
  private fallbackTimer: number = -1;
  private phase: number = 0;
  private prevBands: number[] = new Array<number>(BAND_COUNT).fill(0);

  /**
   * 设置当前要可视化的流 URL（m3u8）。在 start 之前或之后调用都行。
   */
  attachStream(url: string): void {
    if (this.streamUrl === url) return;
    this.streamUrl = url;
    if (this.callback) {
      // 已经在跑：重启真实管线
      this.restartRealPipeline();
    }
  }

  async start(cb: SpectrumCallback): Promise<void> {
    this.callback = cb;
    this.active = false;
    this.prevBands = new Array<number>(BAND_COUNT).fill(0);
    if (this.streamUrl) {
      await this.startRealPipeline();
    } else {
      hilog.warn(0x0000, TAG, 'no stream url, starting in fallback mode');
      this.startFallback();
    }
  }

  setActive(playing: boolean): void {
    this.active = playing;
    hilog.info(0x0000, TAG, `setActive: ${playing}`);
    // 不再 reset native：让 ring 缓冲继续，下次 setActive(true) 时无延迟。
    // 不再 emit 全 0：active 只是 UI 提示（WaveVisualizer 用它控制 opacity），
    // 实际 bands 仍由 pacer 30+ fps 发出来；暂停状态下视觉上自然变暗。
  }

  async stop(): Promise<void> {
    if (this.healthCheckTimer >= 0) {
      clearTimeout(this.healthCheckTimer);
      this.healthCheckTimer = -1;
    }
    if (this.fallbackTimer >= 0) {
      clearInterval(this.fallbackTimer);
      this.fallbackTimer = -1;
    }
    if (this.tap) {
      const t = this.tap;
      this.tap = null;
      await t.stop();
    }
    if (this.nativeHandle !== 0) {
      try { spectrum.destroy(this.nativeHandle); } catch (_e) { /* ignore */ }
      this.nativeHandle = 0;
    }
    this.callback = null;
    this.fallbackActive = false;
  }

  /* ============= 真实管线 ============= */

  private async startRealPipeline(): Promise<void> {
    this.fallbackActive = false;
    this.receivedRealFrame = false;

    // 创建 native 实例。bands 回调由 napi_threadsafe_function 切回 ArkTS 主线程。
    try {
      this.nativeHandle = spectrum.create((bands: number[]) => {
        this.receivedRealFrame = true;
        this.emitBands(bands);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `spectrum.create failed: ${(e as Error).message}`);
      this.switchToFallback();
      return;
    }

    this.tap = new HlsAacTap((adts: Uint8Array) => {
      if (this.nativeHandle !== 0) {
        try {
          spectrum.feedAdts(this.nativeHandle, adts);
        } catch (e) {
          hilog.warn(0x0000, TAG, `feedAdts threw: ${(e as Error).message}`);
        }
      }
    });

    try {
      await this.tap.start(this.streamUrl, () => {
        hilog.warn(0x0000, TAG, 'HlsAacTap reported fatal, switching to fallback');
        this.switchToFallback();
      });
      // 不再调 tap.setActive —— active 只用来控制 UI opacity，不影响数据流。
      // 让 ADTS 从启动就一直流到 NDK，pacer 在 ring buffer 攒帧，用户点播放
      // 时立即就有现成数据可显示。
      hilog.info(0x0000, TAG, `real pipeline started for ${this.streamUrl}`);
      hilog.warn(0x0000, TAG, `pipeline started, waiting for bands... handle=${this.nativeHandle}`);
    } catch (e) {
      hilog.warn(0x0000, TAG, `start tap failed: ${(e as Error).message}`);
      this.switchToFallback();
      return;
    }

    // 健康检查放宽到 12 秒：HLS 拉第一段（playlist + 2s+ segment 下载 + TS 解封装）
    // 5 秒比较紧，慢网/CDN 冷启动下经常超时误降级。
    if (this.healthCheckTimer >= 0) clearTimeout(this.healthCheckTimer);
    this.healthCheckTimer = setTimeout(() => {
      if (!this.receivedRealFrame && !this.fallbackActive) {
        hilog.warn(0x0000, TAG, 'no real frame in 12s, switching to fallback');
        this.switchToFallback();
      }
    }, 12000);
  }

  private async restartRealPipeline(): Promise<void> {
    if (this.tap) {
      const t = this.tap;
      this.tap = null;
      await t.stop();
    }
    if (this.nativeHandle !== 0) {
      try { spectrum.destroy(this.nativeHandle); } catch (_e) { /* ignore */ }
      this.nativeHandle = 0;
    }
    if (this.fallbackTimer >= 0) {
      clearInterval(this.fallbackTimer);
      this.fallbackTimer = -1;
    }
    this.fallbackActive = false;
    if (this.streamUrl) {
      await this.startRealPipeline();
    }
  }

  private async switchToFallback(): Promise<void> {
    if (this.fallbackActive) return;
    this.fallbackActive = true;
    if (this.tap) {
      const t = this.tap;
      this.tap = null;
      await t.stop();
    }
    if (this.nativeHandle !== 0) {
      try { spectrum.destroy(this.nativeHandle); } catch (_e) { /* ignore */ }
      this.nativeHandle = 0;
    }
    this.startFallback();
  }

  /* ============= 降级管线 ============= */

  private startFallback(): void {
    this.fallbackActive = true;
    if (this.fallbackTimer >= 0) clearInterval(this.fallbackTimer);
    this.fallbackTimer = setInterval(() => {
      this.fallbackTick();
    }, 80);
  }

  /**
   * 降级显示：故意做成"一眼能看出是降级"的样子
   *   - 全 16 根柱条等高、低位置
   *   - 整体非常缓慢地呼吸（2.5s 一个周期），区别于任何真实音频
   * 这样肉眼就知道真实管线没产出，需要看 hilog 排查。
   */
  private fallbackTick(): void {
    if (!this.active) {
      this.decay();
      return;
    }
    this.phase += 0.04;
    const breath = 0.06 + 0.04 * (Math.sin(this.phase) + 1) * 0.5; // 0.06..0.10
    const bands: number[] = new Array<number>(BAND_COUNT).fill(breath);
    this.emitBands(bands);
  }

  private decay(): void {
    let allZero = true;
    const bands: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const v = this.prevBands[i] * 0.85;
      bands.push(v < 0.01 ? 0 : v);
      if (v >= 0.01) allZero = false;
    }
    if (!allZero) this.emitBands(bands);
  }

  /* ============= 输出（透传，不再二次平滑） ============= */

  private emitBands(bands: number[]): void {
    if (!this.callback) return;
    // native 已经做了 attack/release 平滑，这里直接透传给 UI。
    // fallback 模式 emit 的本来就是连续的呼吸/正弦值，也不需要二次平滑。
    this.prevBands = bands;
    this.callback(bands);
  }
}
