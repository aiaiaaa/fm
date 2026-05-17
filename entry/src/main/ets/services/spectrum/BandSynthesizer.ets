/**
 * 帧能量 → 16 频段
 *
 * 输入：每帧 ADTS 编码后的字节数（变化反映该帧的音频"复杂度/能量"）
 * 输出：16 个频段振幅 [0..1]
 *
 * 实现思路：
 *   1) 用滑动窗口把每帧字节数归一化成"能量等级" e ∈ [0,1]
 *   2) 16 根柱条按贝尔曲线（中间高两边低）做空间分布
 *   3) 每帧做一次相位推进，再叠一层正弦扰动，让柱条在能量下保持"舞动"
 *
 * 这样得到的视觉是 真实数据驱动 + 合成频域分布：
 *   - 安静时 e≈0，柱条几乎贴底
 *   - 有声音时 e 升高，整体高度按贝尔曲线展开
 *   - 单帧之间相位变化，柱条不会齐刷刷地一起涨落
 *
 * 注意：这不是 FFT，不是真正的频域分析。要拿真 PCM 做 FFT 需要 NDK 接 OH_AudioCodec。
 */
export type BandSink = (bands: number[]) => void;

const BAND_COUNT = 16;
const ENERGY_WINDOW = 24;

export class BandSynthesizer {
  private readonly sink: BandSink;
  private readonly window: number[] = [];
  private maxObserved: number = 1;
  private phase: number = 0;
  private prev: number[] = new Array<number>(BAND_COUNT).fill(0);
  private active: boolean = true;

  constructor(sink: BandSink) {
    this.sink = sink;
  }

  setActive(active: boolean): void {
    this.active = active;
    if (!active) {
      this.window.length = 0;
    }
  }

  reset(): void {
    this.window.length = 0;
    this.maxObserved = 1;
    this.phase = 0;
    this.prev = new Array<number>(BAND_COUNT).fill(0);
  }

  /**
   * 喂一帧 ADTS frame 长度（字节）
   */
  feedFrame(frameBytes: number): void {
    if (!this.active) return;
    if (frameBytes <= 0) return;

    this.window.push(frameBytes);
    if (this.window.length > ENERGY_WINDOW) {
      this.window.shift();
    }

    // 滚动最大值（带轻微衰减，避免一次峰值卡住归一化）
    this.maxObserved = Math.max(this.maxObserved * 0.995, frameBytes);
    if (this.maxObserved < 100) this.maxObserved = 100;

    // 当前帧能量
    const e = Math.min(1, frameBytes / this.maxObserved);

    // 平滑后的窗口能量（用作整体振幅地板）
    let avg = 0;
    for (let i = 0; i < this.window.length; i++) {
      avg += this.window[i];
    }
    avg = (avg / this.window.length) / this.maxObserved;
    avg = Math.min(1, avg);

    // 当前主能量取实时与窗口的较大值，让柱条对突发更敏感
    const energy = Math.max(e, avg * 0.85);

    // 推进相位，每帧推进 0.18 rad（~3.5deg），柱条之间相位差 0.42 rad
    this.phase += 0.18;

    const bands: number[] = new Array<number>(BAND_COUNT);
    for (let i = 0; i < BAND_COUNT; i++) {
      // 1) 贝尔形空间分布（中间高，两端低）
      const mid = (BAND_COUNT - 1) / 2;
      const distFromMid = Math.abs(i - mid) / mid; // 0 中间 → 1 两端
      const bell = Math.pow(1 - distFromMid * 0.7, 1.6);

      // 2) 时域调制：每根柱条单独的相位 + 频率，互相错开
      const mod1 = Math.sin(this.phase * 1.0 + i * 0.42) * 0.18;
      const mod2 = Math.sin(this.phase * 2.3 + i * 0.91) * 0.10;
      const noise = (Math.random() - 0.5) * 0.08;

      // 3) 合成：能量为底，加调制，乘贝尔形
      let v = energy * (0.55 + mod1 + mod2 + noise) * bell;
      // 让中间柱条天生比两边活跃一点（视觉更接近设计稿）
      v *= (1 - distFromMid * 0.35);
      v = Math.max(0, Math.min(1, v));
      bands[i] = v;
    }

    // 4) 时间平滑：上升快下降慢
    const smoothed: number[] = new Array<number>(BAND_COUNT);
    for (let i = 0; i < BAND_COUNT; i++) {
      const target = bands[i];
      const prev = this.prev[i];
      smoothed[i] = target > prev
        ? prev + (target - prev) * 0.55
        : prev + (target - prev) * 0.22;
    }
    this.prev = smoothed;
    this.sink(smoothed);
  }
}
