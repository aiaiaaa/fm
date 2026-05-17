import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AudioVisualizer';
const BAND_COUNT = 16;

/**
 * 音频可视化服务 —— 基于播放状态生成 16 频段动态数据驱动音波柱状图
 *
 * 采用算法模拟方式：低频段振幅大、高频段递减，多频率叠加 + 随机扰动
 * 产生自然的音频频谱律动效果。播放时活跃，暂停时衰减归零。
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
  private callback: SpectrumCallback | null = null;
  private active: boolean = false;
  private timer: number = -1;
  private phase: number = 0;

  // 平滑缓冲（上一帧数据用于做衰减）
  private prevBands: number[] = new Array(BAND_COUNT).fill(0);

  async start(cb: SpectrumCallback): Promise<void> {
    this.callback = cb;
    hilog.info(0x0000, TAG, 'AudioVisualizer started');

    // 启动模拟频谱生成
    this.timer = setInterval(() => {
      this.tick();
    }, 80);
  }

  setActive(playing: boolean): void {
    this.active = playing;
    hilog.info(0x0000, TAG, `setActive: ${playing}`);
    if (!playing) {
      // 停止时快速衰减到零
      this.prevBands = new Array(BAND_COUNT).fill(0);
      this.emitBands(new Array(BAND_COUNT).fill(0));
    }
  }

  async stop(): Promise<void> {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.callback = null;
  }

  /**
   * 每帧 tick：基于播放状态生成 16 个频段的模拟频谱
   * 效果：左侧（低频）柱条高，右侧（高频）递减，多频率叠加产生律动
   */
  private tick(): void {
    if (!this.active) {
      this.decay();
      return;
    }

    this.phase += 0.55;
    const bands: number[] = [];

    for (let i = 0; i < BAND_COUNT; i++) {
      // 低频段振幅较大，高频段递减（模拟真实音频频谱分布）
      const freqFactor = 1.0 - (i / BAND_COUNT) * 0.6;

      // 多频率叠加模拟音频律动
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
   * 输出频段数据（带平滑：上升快、下降慢产生拖尾效果）
   */
  private emitBands(bands: number[]): void {
    if (!this.callback) return;

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
      const v = this.prevBands[i] * 0.85;
      bands.push(v < 0.01 ? 0 : v);
      if (v >= 0.01) allZero = false;
    }
    if (!allZero) {
      this.emitBands(bands);
    }
  }
}
