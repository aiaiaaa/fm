import { AudioVisualizer } from '../services/AudioVisualizer';

/**
 * 音波可视化组件 —— 16 根柱条，由真实音频 PCM 数据驱动
 *
 * 视觉效果（对标设计稿）：
 *   - 左侧柱条最高（低频能量大），向右递减
 *   - 柱条带圆角，颜色从绿色渐变到青色
 *   - 播放时根据真实音频频谱律动
 *   - 暂停时柔和衰减归零
 */
@Component
export struct WaveVisualizer {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop accent: string = '#52FFA1';
  @Prop bars: number = 16;
  @Prop maxHeight: number = 42;

  @State levels: number[] = new Array(16).fill(0);

  private visualizer: AudioVisualizer = new AudioVisualizer();

  aboutToAppear(): void {
    this.levels = new Array(this.bars).fill(0);
    this.visualizer.start((bands: number[]) => {
      animateTo({ duration: 60, curve: Curve.Linear }, () => {
        this.levels = bands;
      });
    });
    if (this.active) {
      this.visualizer.setActive(true);
    }
  }

  aboutToDisappear(): void {
    this.visualizer.stop();
  }

  onActiveChange(): void {
    this.visualizer.setActive(this.active);
  }

  build() {
    Row({ space: 4 }) {
      // !!! ArkUI 关键坑位：
      //   ForEach itemBuilder 的闭包参数 lv 是首次 build 的 number 快照，
      //   ArkUI 状态系统不会追踪它。只有读取 this.levels[idx]（真正的 @State）
      //   时框架才会建立依赖关系，这样 levels 数组重新赋值时 height / opacity
      //   才会刷新，柱子才会真的"动"起来。
      ForEach(this.levels, (_lv: number, idx: number) => {
        Column()
          .width(5)
          .height(Math.max(5, (this.levels[idx] ?? 0) * this.maxHeight))
          .borderRadius(2.5)
          .linearGradient({
            angle: 180,
            colors: this.getBarColors(idx)
          })
          .opacity(this.active ? (0.6 + (this.levels[idx] ?? 0) * 0.4) : 0.2)
      }, (_: number, idx: number) => `wv-${idx}`)
    }
    .height(this.maxHeight)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Bottom)
  }

  /**
   * 每根柱条的渐变色：从左到右 绿→青 过渡
   */
  private getBarColors(idx: number): [string, number][] {
    // 16根柱条从 #52FFA1(绿) 渐变到 #00D2FF(青)
    const t = idx / (this.bars - 1);
    const r = Math.round(0x52 + (0x00 - 0x52) * t);
    const g = Math.round(0xFF + (0xD2 - 0xFF) * t);
    const b = Math.round(0xA1 + (0xFF - 0xA1) * t);
    const topColor = `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
    const bottomColor = topColor + '66'; // 带透明度的底色
    return [[topColor, 0], [bottomColor, 1]];
  }
}
