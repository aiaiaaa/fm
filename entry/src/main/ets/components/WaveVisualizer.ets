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
 *
 * !!! ArkUI 关键坑位 !!!
 *   ForEach 的 itemBuilder 闭包只在 key 变化时才会重新执行；
 *   闭包参数 `lv`（基本类型 number）是首次 build 时的快照，不会被 @State
 *   状态系统追踪。所以 height/opacity 绑定 必须 直接读 `this.levels[idx]`，
 *   ArkUI 才会在 `this.levels` 数组重新赋值时重算这些属性，从而让柱子真正动起来。
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
    // 初始化柱子数据，避免首帧布局抖动
    const init: number[] = new Array(this.bars);
    for (let i = 0; i < this.bars; i++) {
      init[i] = 0.06;
    }
    this.levels = init;

    // 采样间隔放宽到 110ms，动画 180ms（>= 间隔，UI 才有时间过渡），
    // 这样避免 animateTo 被下一帧立刻打断导致看起来"不动"。
    this.visualizer.start({ bars: this.bars, intervalMs: 110 }, (levels: number[], realActive: boolean) => {
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
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
        // 注意：这里所有依赖振幅的属性 都必须 通过 this.levels[idx] 读取，
        // 而不是闭包参数 lv，否则 ArkUI 的状态系统不会感知到变化。
        Column()
          .width(3)
          .height(Math.max(3, (this.levels[idx] ?? 0) * this.maxHeight))
          .borderRadius(2)
          .backgroundColor(this.accent)
          .opacity(0.45 + (this.levels[idx] ?? 0) * 0.55)
          .shadow(this.renderingActive
            ? { radius: 6, color: this.accent, offsetX: 0, offsetY: 0 }
            : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
      }, (_lv: number, idx: number) => `wv-${idx}`)
    }
    .height(this.maxHeight)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onAppear(() => this.onActiveChange())
  }
}
