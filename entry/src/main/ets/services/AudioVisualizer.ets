import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AudioVisualizer';
const BAND_COUNT = 16;

/**
 * 音频可视化服务 —— 使用 AudioCapturer (PLAYBACK_CAPTURE) 采集系统播放的音频 PCM，
 * 再通过简易频谱分析提取 16 个频段能量，驱动 UI 柱状音波。
 *
 * 如果设备不支持 PLAYBACK_CAPTURE（权限/API限制），自动降级为基于播放状态的模拟算法。
 *
 * 外部使用：
 *   const vis = new AudioVisualizer();
 *   vis.start(cb);         // cb 接收 16 个 [0,1] 值
 *   vis.setActive(true);   // 播放开始
 *   vis.setActive(false);  // 播放暂停
 *   vis.stop();            // 释放资源
 */
export type SpectrumCallback = (bands: number[]) => void;

export class AudioVisualizer {
  private capturer: audio.AudioCapturer | null = null;
  private callback: SpectrumCallback | null = null;
  private active: boolean = false;
  private timer: number = -1;
  private phase: number = 0;
  private useFallback: boolean = false;
  private reading: boolean = false;

  // 平滑缓冲（上一帧数据用于做衰减）
  private prevBands: number[] = new Array(BAND_COUNT).fill(0);

  async start(cb: SpectrumCallback): Promise<void> {
    this.callback = cb;

    // 尝试创建 AudioCapturer (播放内录)
    try {
      const capturerOptions: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_PLAYBACK_CAPTURE,
          capturerFlags: 0
        }
      };

      this.capturer = await audio.createAudioCapturer(capturerOptions);
      await this.capturer.start();
      this.useFallback = false;
      hilog.info(0x0000, TAG, 'AudioCapturer started (PLAYBACK_CAPTURE)');

      // 定时读取 PCM 数据并分析频谱
      this.timer = setInterval(() => {
        this.readAndAnalyze();
      }, 60);
    } catch (e) {
      hilog.warn(0x0000, TAG, `AudioCapturer not available, using fallback: ${JSON.stringify(e)}`);
      this.useFallback = true;
      // 降级：用模拟算法
      this.timer = setInterval(() => {
        this.fallbackTick();
      }, 80);
    }
  }

  setActive(playing: boolean): void {
    this.active = playing;
    if (!playing) {
      // 停止时快速衰减
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
   * 从 AudioCapturer 读取 PCM 数据并做简易频谱分析
   */
  private readAndAnalyze(): void {
    if (!this.capturer || !this.active) {
      if (!this.active) {
        this.decay();
      }
      return;
    }

    // 防止重入（上一次 read 还没完成）
    if (this.reading) return;
    this.reading = true;

    const bufferSize = 4096;
    this.capturer.read(bufferSize, true).then((buffer: ArrayBuffer) => {
      this.reading = false;
      if (buffer.byteLength <= 0) {
        this.decay();
        return;
      }

      // 解析 S16LE PCM 数据
      const sampleCount = Math.min(Math.floor(buffer.byteLength / 2), 2048);
      const samples = new Int16Array(buffer, 0, sampleCount);
      const bands = this.analyzeBands(samples);
      this.emitBands(bands);
    }).catch(() => {
      this.reading = false;
      this.decay();
    });
  }

  /**
   * 将 PCM 样本简易分为 16 个频段（不做完整 FFT，用能量分组近似）
   * 将样本分成 16 段，每段计算 RMS 能量，再做对数映射
   */
  private analyzeBands(samples: Int16Array): number[] {
    const N = samples.length;
    if (N < BAND_COUNT) {
      return new Array(BAND_COUNT).fill(0);
    }

    const segSize = Math.floor(N / BAND_COUNT);
    const bands: number[] = [];

    for (let b = 0; b < BAND_COUNT; b++) {
      let sum = 0;
      const start = b * segSize;
      for (let i = start; i < start + segSize && i < N; i++) {
        const v = samples[i] / 32768;
        sum += v * v;
      }
      const rms = Math.sqrt(sum / segSize);
      // 对数映射，让小信号也能看到
      const db = rms > 0 ? 20 * Math.log10(rms) : -60;
      // 归一化到 0..1 (假设 -60dB ~ 0dB 范围)
      const normalized = Math.max(0, Math.min(1, (db + 60) / 55));
      bands.push(normalized);
    }

    return bands;
  }

  /**
   * 降级模拟算法：基于播放状态生成伪频谱
   */
  private fallbackTick(): void {
    if (!this.active) {
      this.decay();
      return;
    }

    this.phase += 0.55;
    const bands: number[] = [];

    for (let i = 0; i < BAND_COUNT; i++) {
      // 低频段振幅较大，高频段递减（模拟真实音频频谱分布）
      const freqFactor = 1.0 - (i / BAND_COUNT) * 0.6;
      const lo = Math.sin(this.phase * 0.8 + i * 0.3) * 0.3;
      const mid = Math.sin(this.phase * 1.6 + i * 0.7) * 0.35;
      const hi = Math.sin(this.phase * 2.5 + i * 1.1) * 0.15;
      const rnd = (Math.random() - 0.5) * 0.25;
      const raw = Math.abs(lo + mid + hi + rnd) * freqFactor;
      bands.push(Math.max(0.05, Math.min(1, 0.15 + raw * 1.5)));
    }

    this.emitBands(bands);
  }

  /**
   * 输出频段数据（带平滑）
   */
  private emitBands(bands: number[]): void {
    if (!this.callback) return;

    // 平滑处理：上升快、下降慢
    const smoothed: number[] = [];
    for (let i = 0; i < BAND_COUNT; i++) {
      const target = bands[i];
      const prev = this.prevBands[i];
      const v = target > prev
        ? prev + (target - prev) * 0.7  // 上升快
        : prev + (target - prev) * 0.3; // 下降慢（拖尾效果）
      smoothed.push(v);
    }
    this.prevBands = smoothed;
    this.callback(smoothed);
  }

  /**
   * 无数据时缓慢衰减
   */
  private decay(): void {
    const bands: number[] = [];
    let allZero = true;
    for (let i = 0; i < BAND_COUNT; i++) {
      const v = this.prevBands[i] * 0.8;
      bands.push(v < 0.01 ? 0 : v);
      if (v >= 0.01) allZero = false;
    }
    if (!allZero) {
      this.emitBands(bands);
    }
  }
}
