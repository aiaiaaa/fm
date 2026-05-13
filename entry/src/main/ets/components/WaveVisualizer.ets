import { AudioVisualizer } from '../services/AudioVisualizer';

/**
 * 音波可视化组件（柱状）—— 图片中的绿色钟形条形图。
 *
 * 底层数据源：AudioVisualizer
 *   - 订阅鸿蒙 AudioStreamManager.audioRendererChange 感知是否真在放音
 *   - 订阅 AudioVolumeGroupManager.volumeChange 感知媒体音量
 *   - 合成出 bars 根柱子的 [0,1] 振幅
 *
 * 样式与图片保持一致：中间最高，两边递减，圆角条。
 */
@Component
export struct WaveVisualizer {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop accent: string = '#52FFA1';
  @Prop bars: number = 32;
  @Prop maxHeight: number = 42;

  @State levels: number[] = [];
  @State renderingActive: boolean = false;

  private visualizer: AudioVisualizer = new AudioVisualizer();

  aboutToAppear(): void {
    this.levels = new Array(this.bars).fill(0.04);
    this.visualizer.start({ bars: this.bars, intervalMs: 90 }, (levels: number[], realActive: boolean) => {
      animateTo({ duration: 90, curve: Curve.Linear }, () => {
        this.levels = levels;
        this.renderingActive = realActive;
      });
    });
    this.visualizer.setActive(this.active);
  }

  aboutToDisappear(): void {
    this.visualizer.stop();
  }

  /**
   * 当外部 active 属性变化时同步给底层可视化器
   */
  onActiveChange(): void {
    this.visualizer.setActive(this.active);
  }

  build() {
    Row({ space: 3 }) {
      ForEach(this.levels, (lv: number, idx: number) => {
        Column()
          .width(3)
          .height(Math.max(4, lv * this.maxHeight))
          .borderRadius(2)
          .backgroundColor(this.accent)
          .opacity(0.55 + lv * 0.45)
          .shadow(this.renderingActive ? { radius: 6, color: this.accent, offsetX: 0, offsetY: 0 } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
      }, (_: number, idx: number) => `wv-${idx}`)
    }
    .height(this.maxHeight)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onAppear(() => this.onActiveChange())
  }
}
