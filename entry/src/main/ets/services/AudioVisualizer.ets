import { hilog } from '@kit.PerformanceAnalysisKit';
import { HlsAacTap } from './spectrum/HlsAacTap';
import { BandSynthesizer } from './spectrum/BandSynthesizer';

const TAG = 'AudioVisualizer';
const BAND_COUNT = 16;

/**
 * 音频可视化服务
 *
 * 主路径（数据驱动）：
 *   m3u8 ──► HlsAacTap（旁路解封装，独立于 AVPlayer）──► ADTS 帧能量
 *           ──► BandSynthesizer（贝尔形 16 频段合成）──► UI
 *
 * 降级（任何环节失败 / 未配置流地址）：
 *   多频率正弦叠加 + 随机扰动 → 16 频段
 *
 * 调用方式：
 *   vis.attachStream(url)
 *   vis.start(cb)
 *   vis.setActive(true | false)
 *   vis.stop()
 *
 * 注：完整的真 FFT 频谱需要 PCM，HarmonyOS NEXT 的 ArkTS 层没有 AAC 解码器，
 * 必须走 NDK OH_AudioCodec。这里用 ADTS 帧字节数作为能量代理量，配合贝尔形
 * 空间分布合成出与 bbg.fm 视觉接近的频谱效果。
 */
export type SpectrumCallback = (bands: number[]) => void;

export class AudioVisualizer {
  private callback: SpectrumCallback | null = null;
  private active: boolean = false;
  private streamUrl: string = '';

  // 真实管线
  private tap: HlsAacTap | null = null;
  private synth: BandSynthesizer | null = null;
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
    this.tap?.setActive(playing);
    this.synth?.setActive(playing);
    if (!playing) {
      // 暂停时柔和归零
      this.prevBands = new Array<number>(BAND_COUNT).fill(0);
      this.emitBands(new Array<number>(BAND_COUNT).fill(0));
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
    if (this.tap) {
      const t = this.tap;
      this.tap = null;
      await t.stop();
    }
    this.synth = null;
    this.callback = null;
    this.fallbackActive = false;
  }

  /* ============= 真实管线 ============= */

  private async startRealPipeline(): Promise<void> {
    this.fallbackActive = false;
    this.receivedRealFrame = false;

    this.synth = new BandSynthesizer((bands: number[]) => {
      this.receivedRealFrame = true;
      this.emitBands(bands);
    });

    this.tap = new HlsAacTap((frameBytes: number) => {
      this.synth?.feedFrame(frameBytes);
    });

    try {
      await this.tap.start(this.streamUrl, () => {
        hilog.warn(0x0000, TAG, 'HlsAacTap reported fatal, switching to fallback');
        this.switchToFallback();
      });
      this.tap.setActive(this.active);
      this.synth.setActive(this.active);
      hilog.info(0x0000, TAG, `real pipeline started for ${this.streamUrl}`);
    } catch (e) {
      hilog.warn(0x0000, TAG, `start tap failed: ${(e as Error).message}`);
      this.switchToFallback();
      return;
    }

    // 健康检查：8 秒还没收到一帧就降级（直播第一段拉取 + TS 解封装通常 3~5 秒）
    if (this.healthCheckTimer >= 0) clearTimeout(this.healthCheckTimer);
    this.healthCheckTimer = setTimeout(() => {
      if (!this.receivedRealFrame && !this.fallbackActive) {
        hilog.warn(0x0000, TAG, 'no real frame in 8s, switching to fallback');
        this.switchToFallback();
      }
    }, 8000);
  }

  private async restartRealPipeline(): Promise<void> {
    if (this.tap) {
      const t = this.tap;
      this.tap = null;
      await t.stop();
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
    this.synth = null;
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

  private fallbackTick(): void {
    if (!this.active) {
      this.decay();
      return;
    }
    this.phase += 0.55;
    const bands: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const freqFactor = 1.0 - (i / BAND_COUNT) * 0.6;
      const lo = Math.sin(this.phase * 0.8 + i * 0.3) * 0.3;
      const mid = Math.sin(this.phase * 1.6 + i * 0.7) * 0.35;
      const hi = Math.sin(this.phase * 2.5 + i * 1.1) * 0.15;
      const rnd = (Math.random() - 0.5) * 0.25;
      const raw = Math.abs(lo + mid + hi + rnd) * freqFactor;
      bands.push(Math.max(0.08, Math.min(1, 0.2 + raw * 1.5)));
    }
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

  /* ============= 输出（带平滑） ============= */

  private emitBands(bands: number[]): void {
    if (!this.callback) return;
    // 真实管线已经做了平滑，这里只对 fallback 平滑一下
    const smoothed: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const target = bands[i] ?? 0;
      const prev = this.prevBands[i];
      const v = target > prev
        ? prev + (target - prev) * 0.7
        : prev + (target - prev) * 0.3;
      smoothed.push(v);
    }
    this.prevBands = smoothed;
    this.callback(smoothed);
  }
}
