/**
 * 音波可视化组件 —— 播放时展示动态音波柱状图
 *
 * 效果：中间高两侧低的钟形分布，带渐变色和发光，
 *       播放时柱条随机律动，暂停时归于静默。
 *
 * 不再依赖 AudioVisualizer 服务，直接内部驱动动画，
 * 确保只要 active=true 就一定有动效。
 */
@Component
export struct WaveVisualizer {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop accent: string = '#52FFA1';
  @Prop bars: number = 32;
  @Prop maxHeight: number = 42;

  @State levels: number[] = [];

  private timer: number = -1;
  private phase: number = 0;

  aboutToAppear(): void {
    this.levels = new Array(this.bars).fill(0.06);
    if (this.active) {
      this.startAnim();
    }
  }

  aboutToDisappear(): void {
    this.stopAnim();
  }

  onActiveChange(): void {
    if (this.active) {
      this.startAnim();
    } else {
      this.stopAnim();
      // 归于静默
      animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        const N = this.bars;
        const center = (N - 1) / 2;
        const arr: number[] = [];
        for (let i = 0; i < N; i++) {
          const x = (i - center) / center;
          const env = Math.exp(-x * x * 3);
          arr.push(0.06 * env + 0.03);
        }
        this.levels = arr;
      });
    }
  }

  private startAnim(): void {
    if (this.timer >= 0) return;
    this.timer = setInterval(() => {
      this.phase += 0.5;
      const N = this.bars;
      const center = (N - 1) / 2;
      const arr: number[] = [];

      for (let i = 0; i < N; i++) {
        const x = (i - center) / center; // -1..1
        const envelope = Math.exp(-x * x * 2.0); // 钟形

        // 多频率叠加模拟音频律动
        const lo = Math.sin(this.phase * 0.7 + i * 0.25) * 0.28;
        const mid = Math.sin(this.phase * 1.4 + i * 0.55) * 0.35;
        const hi = Math.sin(this.phase * 2.3 + i * 0.85) * 0.18;
        const rnd = (Math.random() - 0.5) * 0.2;
        const raw = Math.abs(lo + mid + hi + rnd);
        const v = (0.2 + raw * 1.3) * envelope;
        arr.push(Math.max(0.08, Math.min(1, v)));
      }

      animateTo({ duration: 80, curve: Curve.Linear }, () => {
        this.levels = arr;
      });
    }, 85);
  }

  private stopAnim(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  build() {
    Row({ space: 2 }) {
      ForEach(this.levels, (lv: number, idx: number) => {
        Column()
          .width(3)
          .height(Math.max(3, lv * this.maxHeight))
          .borderRadius(1.5)
          .linearGradient({
            angle: 180,
            colors: this.active
              ? [[this.accent, 0], [this.shiftColor(this.accent, 0.6), 1]]
              : [['#2A3040', 0], ['#1A2030', 1]]
          })
          .opacity(this.active ? (0.5 + lv * 0.5) : 0.3)
      }, (_: number, idx: number) => `wv-${idx}`)
    }
    .height(this.maxHeight)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Bottom)
  }

  /**
   * 简单地将 hex 颜色的亮度做偏移，用于渐变第二色
   */
  private shiftColor(hex: string, factor: number): string {
    // 简单处理：对于 #52FFA1 这类，降低亮度作为渐变底部色
    // 返回一个带透明度的版本
    const alpha = Math.round(factor * 255).toString(16).padStart(2, '0');
    return hex + alpha;
  }
}
