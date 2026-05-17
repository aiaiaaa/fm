import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AudioVisualizer';
const BAND_COUNT = 16;
const SAMPLE_RATE = 8000;
const FRAME_SIZE = 512; // 每帧采样数

/**
 * 音频可视化服务
 *
 * 方案一（优先）：AudioCapturer + SOURCE_TYPE_PLAYBACK_CAPTURE + on('readData')
 *   实时采集系统播放的音频PCM数据，做FFT频谱分析，驱动16频段柱条
 *
 * 方案二（降级）：基于播放状态的模拟算法
 *   多频率正弦波叠加+随机扰动，低频高振幅、高频低振幅
 *
 * 外部调用：
 *   vis.start(cb)        → cb 接收 number[16]，值域 [0,1]
 *   vis.setActive(true)  → 播放中
 *   vis.setActive(false) → 暂停
 *   vis.stop()           → 释放
 */
export type SpectrumCallback = (bands: number[]) => void;

export class AudioVisualizer {
  private capturer: audio.AudioCapturer | null = null;
  private callback: SpectrumCallback | null = null;
  private active: boolean = false;
  private timer: number = -1;
  private phase: number = 0;
  private useFallback: boolean = false;
  private emptyReadCount: number = 0;

  // 平滑缓冲
  private prevBands: number[] = new Array(BAND_COUNT).fill(0);

  async start(cb: SpectrumCallback): Promise<void> {
    this.callback = cb;

    // 尝试使用 AudioCapturer 内录
    try {
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_8000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_PLAYBACK_CAPTURE,
          capturerFlags: 0
        }
      };

      this.capturer = await audio.createAudioCapturer(options);

      // 使用 on('readData') 回调方式接收 PCM 数据
      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        if (!this.active) return;
        this.processAudioData(buffer);
      });

      await this.capturer.start();
      this.useFallback = false;
      hilog.info(0x0000, TAG, 'AudioCapturer(PLAYBACK_CAPTURE) started with readData callback');

      // 启动一个检测定时器：如果3秒内没收到有效数据，切换到fallback
      setTimeout(() => {
        if (this.emptyReadCount > 30 && !this.useFallback) {
          hilog.warn(0x0000, TAG, 'No valid PCM data received, switching to fallback');
          this.switchToFallback();
        }
      }, 3000);
    } catch (e) {
      hilog.warn(0x0000, TAG, `AudioCapturer failed: ${JSON.stringify(e)}, using fallback`);
      this.switchToFallback();
    }
  }

  private switchToFallback(): void {
    this.useFallback = true;
    // 释放 capturer
    if (this.capturer) {
      try {
        this.capturer.off('readData');
        this.capturer.stop();
        this.capturer.release();
      } catch (_e) {
        // ignore
      }
      this.capturer = null;
    }
    // 启动模拟定时器
    if (this.timer < 0) {
      this.timer = setInterval(() => {
        this.fallbackTick();
      }, 80);
    }
  }

  setActive(playing: boolean): void {
    this.active = playing;
    hilog.info(0x0000, TAG, `setActive: ${playing}`);
    if (!playing) {
      this.prevBands = new Array(BAND_COUNT).fill(0);
      this.emitBands(new Array(BAND_COUNT).fill(0));
    }
  }

  async stop(): Promise<void> {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.capturer) {
      try {
        this.capturer.off('readData');
        await this.capturer.stop();
        await this.capturer.release();
      } catch (e) {
        hilog.warn(0x0000, TAG, `capturer release: ${JSON.stringify(e)}`);
      }
      this.capturer = null;
    }
    this.callback = null;
  }

  /**
   * 处理 readData 回调的 PCM 数据
   * 对 buffer 做简易 FFT（实际用 DFT 分频段求能量）
   */
  private processAudioData(buffer: ArrayBuffer): void {
    if (buffer.byteLength < 4) {
      this.emptyReadCount++;
      return;
    }

    const sampleCount = Math.floor(buffer.byteLength / 2);
    const samples = new Int16Array(buffer, 0, sampleCount);

    // 检查是否全零（权限问题导致的静音数据）
    let hasSignal = false;
    for (let i = 0; i < Math.min(sampleCount, 64); i++) {
      if (Math.abs(samples[i]) > 10) {
        hasSignal = true;
        break;
      }
    }

    if (!hasSignal) {
      this.emptyReadCount++;
      // 如果连续收到空数据超过50次，切换到fallback
      if (this.emptyReadCount > 50 && !this.useFallback) {
        hilog.warn(0x0000, TAG, 'Only silence received, switching to fallback');
        this.switchToFallback();
      }
      return;
    }

    this.emptyReadCount = 0;
    const bands = this.computeSpectrum(samples, sampleCount);
    this.emitBands(bands);
  }

  /**
   * 简易频谱分析：将时域PCM数据分成16个频段，每段计算能量（RMS）
   * 模拟频谱分布：低频段取更宽的范围（更多采样），高频段取窄范围
   */
  private computeSpectrum(samples: Int16Array, count: number): number[] {
    const bands: number[] = [];
    const usable = Math.min(count, FRAME_SIZE);

    for (let b = 0; b < BAND_COUNT; b++) {
      // 对数分频：低频段覆盖更多采样，高频段覆盖更少
      const startRatio = Math.pow(b / BAND_COUNT, 1.5);
      const endRatio = Math.pow((b + 1) / BAND_COUNT, 1.5);
      const start = Math.floor(startRatio * usable);
      const end = Math.max(start + 1, Math.floor(endRatio * usable));

      let sum = 0;
      for (let i = start; i < end && i < usable; i++) {
        const v = samples[i] / 32768.0;
        sum += v * v;
      }
      const rms = Math.sqrt(sum / (end - start));

      // 对数映射到 0..1
      const db = rms > 0.0001 ? 20 * Math.log10(rms) : -60;
      const normalized = Math.max(0, Math.min(1, (db + 50) / 45));
      bands.push(normalized);
    }
    return bands;
  }

  /**
   * 降级模拟算法
   */
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

  /**
   * 输出（带平滑）
   */
  private emitBands(bands: number[]): void {
    if (!this.callback) return;

    const smoothed: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const target = bands[i];
      const prev = this.prevBands[i];
      const v = target > prev
        ? prev + (target - prev) * 0.7
        : prev + (target - prev) * 0.3;
      smoothed.push(v);
    }
    this.prevBands = smoothed;
    this.callback(smoothed);
  }

  /**
   * 衰减
   */
  private decay(): void {
    let allZero = true;
    const bands: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const v = this.prevBands[i] * 0.85;
      bands.push(v < 0.01 ? 0 : v);
      if (v >= 0.01) allZero = false;
    }
    if (!allZero) {
      this.emitBands(bands);
    }
  }
}
