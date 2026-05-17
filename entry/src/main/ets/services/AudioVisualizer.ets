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

  // active=false 时把 UI 衰减到 0 用的状态：1.0=刚暂停，逐步降到 0=完全静止
  private idlePhase: number = 1.0;

  // ADTS 节流队列：HlsAacTap 一次性把整个 segment 几百帧同步 emit 出来，
  // 如果直接灌进 NDK，输入队列瞬间打满（cap=32），后续帧全被丢；codec 飞速
  // 解码完攒在 ring 里给 pacer，pacer 排空之后 ring 又空 4 秒。视觉就是
  // "动一下卡一下"。这边按 AAC 帧的真实播放节拍（23ms/帧）匀速喂给 NDK，
  // 整条管线变成稳态流。
  private adtsQueue: Uint8Array[] = [];
  private adtsTickTimer: number = -1;
  private static readonly ADTS_TICK_MS = 23;
  private static readonly ADTS_QUEUE_MAX = 256; // ~6s buffer，超出丢老帧

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
    const wasPlaying = this.active;
    this.active = playing;
    hilog.info(0x0000, TAG, `setActive: ${playing}`);
    if (!playing && wasPlaying) {
      // 暂停瞬间立刻把 UI 衰减到 0（pacer 不知道我们暂停了，这边主动做）
      this.idlePhase = 1.0;
    }
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
    if (this.adtsTickTimer >= 0) {
      clearInterval(this.adtsTickTimer);
      this.adtsTickTimer = -1;
    }
    this.adtsQueue = [];
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
      // 不再直接调 spectrum.feedAdts —— 入队，由 tick timer 23ms 一帧匀速喂。
      if (this.adtsQueue.length >= AudioVisualizer.ADTS_QUEUE_MAX) {
        this.adtsQueue.shift(); // 丢最老的
      }
      this.adtsQueue.push(adts);
    });

    // 启动节流 tick：每 23ms（= 1024 samples / 44.1kHz，AAC 一帧时长）从队列
    // 取一帧喂给 NDK。这个间隔等于音频实际播放节拍，所以 ADTS 流入 NDK 的
    // 速率 = NDK 解码 PCM 的速率 = pacer emit bands 的速率 = 视觉刷新速率。
    if (this.adtsTickTimer >= 0) clearInterval(this.adtsTickTimer);
    this.adtsTickTimer = setInterval(() => {
      if (this.nativeHandle === 0 || this.adtsQueue.length === 0) return;
      const frame = this.adtsQueue.shift()!;
      try {
        spectrum.feedAdts(this.nativeHandle, frame);
      } catch (e) {
        hilog.warn(0x0000, TAG, `feedAdts threw: ${(e as Error).message}`);
      }
    }, AudioVisualizer.ADTS_TICK_MS);

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
    if (this.adtsTickTimer >= 0) {
      clearInterval(this.adtsTickTimer);
      this.adtsTickTimer = -1;
    }
    this.adtsQueue = [];
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
    if (this.adtsTickTimer >= 0) {
      clearInterval(this.adtsTickTimer);
      this.adtsTickTimer = -1;
    }
    this.adtsQueue = [];
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
    // active=false 时（用户没按播放、或暂停中），UI 不应该跟着真实音频律动。
    // 不简单丢帧 —— 那样过去的状态会冻在屏幕上；而是按指数曲线从最后一帧
    // 衰减到 0，几百毫秒内自然平静下来。这样：
    //   1) "还没播放"时柱条立刻就静止了（idlePhase=1 → 真实 bands 被乘上 0）
    //   2) 暂停时柱条柔和回落到底
    //   3) 一旦 setActive(true)，下一帧立刻是真实 bands，反应灵敏
    if (!this.active) {
      this.idlePhase *= 0.85; // ~150ms 衰减到 ~10%
      if (this.idlePhase < 0.01) this.idlePhase = 0;
      const damped = bands.map((v: number) => v * this.idlePhase);
      this.prevBands = damped;
      this.callback(damped);
      return;
    }
    this.idlePhase = 1.0;
    this.prevBands = bands;
    this.callback(bands);
  }
}
