import { Fft } from './Fft';
import { PcmFrame, SpectrumSink } from './Types';

const FFT_SIZE = 1024;
const BAND_COUNT = 16;

/**
 * PCM → 16 频段振幅 [0..1]
 *
 * 实现：
 *   1. 维护一个滚动缓冲，凑够 FFT_SIZE 个采样就做一次 FFT
 *   2. Hann 窗 → FFT → magnitude → 对数分桶 → 归一化 → 与上一帧做平滑
 *   3. 输出 16 根柱条
 *
 * 频段切分：对数分布，覆盖 30Hz ~ 10kHz，匹配人耳感知
 */
export class SpectrumAnalyzer {
  private readonly fft: Fft = new Fft(FFT_SIZE);
  private readonly window: Float32Array;
  private readonly re: Float32Array = new Float32Array(FFT_SIZE);
  private readonly im: Float32Array = new Float32Array(FFT_SIZE);

  private readonly sink: SpectrumSink;
  private buffer: Float32Array = new Float32Array(0);
  private prevBands: number[] = new Array(BAND_COUNT).fill(0);
  private sampleRate: number = 44100;

  // 缓存 band 边界（采样率变化时重算）
  private bandLow: number[] = [];
  private bandHigh: number[] = [];
  private bandRateAtCalc: number = -1;

  constructor(sink: SpectrumSink) {
    this.sink = sink;

    // Hann window
    this.window = new Float32Array(FFT_SIZE);
    for (let i = 0; i < FFT_SIZE; i++) {
      this.window[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (FFT_SIZE - 1));
    }
  }

  feed(frame: PcmFrame): void {
    if (frame.sampleRate !== this.sampleRate) {
      this.sampleRate = frame.sampleRate;
      this.recomputeBands();
    } else if (this.bandRateAtCalc !== this.sampleRate) {
      this.recomputeBands();
    }

    // 串接 buffer
    if (this.buffer.length === 0) {
      this.buffer = new Float32Array(frame.samples);
    } else {
      const next = new Float32Array(this.buffer.length + frame.samples.length);
      next.set(this.buffer, 0);
      next.set(frame.samples, this.buffer.length);
      this.buffer = next;
    }

    // 凑够一帧就分析。每次取出最近 FFT_SIZE 样本（hop = FFT_SIZE，无重叠，
    // 已能稳定输出 ~40fps@44100Hz，可视化够用）
    while (this.buffer.length >= FFT_SIZE) {
      const window = this.buffer.subarray(0, FFT_SIZE);
      this.analyze(window);
      this.buffer = this.buffer.subarray(FFT_SIZE);
    }
  }

  /** 暂停 / 切流时清空内部状态 */
  reset(): void {
    this.buffer = new Float32Array(0);
    this.prevBands = new Array(BAND_COUNT).fill(0);
  }

  private analyze(samples: Float32Array): void {
    // 1) 加窗 → 复数实部
    for (let i = 0; i < FFT_SIZE; i++) {
      this.re[i] = samples[i] * this.window[i];
      this.im[i] = 0;
    }
    // 2) FFT
    this.fft.forward(this.re, this.im);

    // 3) 分 16 bins，每个 bin 求 RMS
    const bands: number[] = new Array(BAND_COUNT);
    const half = FFT_SIZE >> 1;

    for (let b = 0; b < BAND_COUNT; b++) {
      const lo = Math.max(1, this.bandLow[b]);
      const hi = Math.min(half, this.bandHigh[b]);
      let sumSq = 0;
      let count = 0;
      for (let k = lo; k < hi; k++) {
        const mag = this.re[k] * this.re[k] + this.im[k] * this.im[k];
        sumSq += mag;
        count++;
      }
      const rms = count > 0 ? Math.sqrt(sumSq / count) / FFT_SIZE : 0;
      // dB 映射，地板 -60dB
      const db = rms > 0 ? 20 * Math.log10(rms) : -100;
      let v = (db + 50) / 50; // -50dB → 0, 0dB → 1
      if (v < 0) v = 0;
      if (v > 1) v = 1;
      bands[b] = v;
    }

    // 4) 平滑：上升快、下降慢
    const smoothed: number[] = new Array(BAND_COUNT);
    for (let i = 0; i < BAND_COUNT; i++) {
      const prev = this.prevBands[i];
      const target = bands[i];
      smoothed[i] = target > prev
        ? prev + (target - prev) * 0.6
        : prev + (target - prev) * 0.25;
    }
    this.prevBands = smoothed;
    this.sink(smoothed);
  }

  /**
   * 16 个频段在 30Hz..10kHz 内做对数划分
   */
  private recomputeBands(): void {
    const fMin = 30;
    const fMax = Math.min(this.sampleRate / 2, 10000);
    const logMin = Math.log(fMin);
    const logMax = Math.log(fMax);

    const lows: number[] = [];
    const highs: number[] = [];
    for (let b = 0; b < BAND_COUNT; b++) {
      const f1 = Math.exp(logMin + (logMax - logMin) * (b / BAND_COUNT));
      const f2 = Math.exp(logMin + (logMax - logMin) * ((b + 1) / BAND_COUNT));
      const k1 = Math.floor(f1 * FFT_SIZE / this.sampleRate);
      const k2 = Math.ceil(f2 * FFT_SIZE / this.sampleRate);
      lows.push(k1);
      highs.push(Math.max(k1 + 1, k2));
    }
    this.bandLow = lows;
    this.bandHigh = highs;
    this.bandRateAtCalc = this.sampleRate;
  }
}
