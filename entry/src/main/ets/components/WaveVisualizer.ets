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
  @Prop @Watch('onStreamUrlChange') streamUrl: string = '';
  @Prop accent: string = '#52FFA1';
  @Prop bars: number = 16;
  @Prop maxHeight: number = 72;

  @State levels: number[] = new Array(16).fill(0);

  private visualizer: AudioVisualizer = new AudioVisualizer();

  aboutToAppear(): void {
    this.levels = new Array(this.bars).fill(0);
    if (this.streamUrl) {
      this.visualizer.attachStream(this.streamUrl);
    }
    // native pacer 在 ring 空时会跳过 tick（不再重发 stale frame），
    // 所以 UI 这边收到的是"有数据时的连续帧 + 偶尔的间隔"。给 ArkUI
    // 一个短动画用来在帧间补间，比直接赋值看起来自然得多；曲线选
    // EaseOut 让上升快、收尾柔和，比 Linear 视觉上更有"弹性"。
    this.visualizer.start((bands: number[]) => {
      animateTo({ duration: 80, curve: Curve.EaseOut }, () => {
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

  onStreamUrlChange(): void {
    if (this.streamUrl) {
      this.visualizer.attachStream(this.streamUrl);
    }
  }

  build() {
    Row({ space: 5 }) {
      // !!! ArkUI 关键坑位：
      //   ForEach itemBuilder 的闭包参数 lv 是首次 build 的 number 快照，
      //   ArkUI 状态系统不会追踪它。只有读取 this.levels[idx]（真正的 @State）
      //   时框架才会建立依赖关系，这样 levels 数组重新赋值时 height / opacity
      //   才会刷新，柱子才会真的"动"起来。
      ForEach(this.levels, (_lv: number, idx: number) => {
        Column()
          .width(6)
          .height(Math.max(6, (this.levels[idx] ?? 0) * this.maxHeight))
          .borderRadius(3)
          .linearGradient({
            angle: 180,
            colors: this.getBarColors(idx)
          })
          .shadow(this.active && (this.levels[idx] ?? 0) > 0.4
            ? { radius: 8, color: this.glowColor(idx), offsetX: 0, offsetY: 0 }
            : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
          .opacity(this.active ? (0.85 + (this.levels[idx] ?? 0) * 0.15) : 0.25)
      }, (_: number, idx: number) => `wv-${idx}`)
    }
    .height(this.maxHeight)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Bottom)
  }

  /**
   * 每根柱条的渐变色：从左到右 绿→青 过渡。
   * 顶部用饱和度更高的霓虹色，底部带半透明，配合 .shadow() 模拟发光。
   */
  private getBarColors(idx: number): [string, number][] {
    const t = idx / (this.bars - 1);
    // 顶部：#7CFFB8（饱和绿）→ #56E8FF（饱和青），明显比之前的 #52FFA1 / #00D2FF 更亮
    const tr = Math.round(0x7C + (0x56 - 0x7C) * t);
    const tg = Math.round(0xFF + (0xE8 - 0xFF) * t);
    const tb = Math.round(0xB8 + (0xFF - 0xB8) * t);
    const top = `#${tr.toString(16).padStart(2, '0')}${tg.toString(16).padStart(2, '0')}${tb.toString(16).padStart(2, '0')}`;
    // 底部：同色调降亮度 + 半透明
    const bottom = `${top}80`;
    return [[top, 0], [bottom, 1]];
  }

  /** 用于发光效果的颜色（饱和顶色） */
  private glowColor(idx: number): string {
    const t = idx / (this.bars - 1);
    return t < 0.5 ? '#7CFFB8' : '#56E8FF';
  }
}
