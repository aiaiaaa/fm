/**
 * 单颗流星：从右上 → 左下斜向划过卡片
 * 用独立 @Component + animateTo 循环，实现真正"流动"的效果
 */
@Component
export struct Meteor {
  @Prop startLeft: number = 60;   // 起点横坐标百分比
  @Prop delay: number = 0;        // 启动延迟（毫秒）
  @Prop duration: number = 2200;  // 单次划过时长
  @Prop cycle: number = 6000;     // 下次出现的周期
  @Prop color: string = '#2EE89D';

  @State translateX: number = 0;
  @State translateY: number = 0;
  @State meteorOpacity: number = 0;

  private timer: number = -1;

  aboutToAppear(): void {
    // 延迟启动，避免所有流星同步
    setTimeout(() => {
      this.runOnce();
      this.timer = setInterval(() => this.runOnce(), this.cycle);
    }, this.delay);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  private runOnce(): void {
    // 瞬间回到起点
    this.translateX = 0;
    this.translateY = 0;
    this.meteorOpacity = 0;

    animateTo({
      duration: 150,
      curve: Curve.EaseOut
    }, () => {
      this.meteorOpacity = 1;
    });

    animateTo({
      duration: this.duration,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.meteorOpacity = 0;
      }
    }, () => {
      this.translateX = -220;
      this.translateY = 320;
    });
  }

  build() {
    // 光尾：一条带渐变的细线，旋转 -30 度
    Stack() {
      Column()
        .width(90)
        .height(1.5)
        .borderRadius(1)
        .linearGradient({
          angle: 90,
          colors: [
            ['#00000000', 0],
            [this.color, 0.6],
            ['#FFFFFFFF', 1]
          ]
        })

      // 头部亮点
      Column()
        .width(4)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 6, color: this.color, offsetX: 0, offsetY: 0 })
        .position({ x: 86, y: -1 })
    }
    .rotate({ angle: -30 })
    .position({ x: `${this.startLeft}%`, y: '-5%' })
    .translate({ x: this.translateX, y: this.translateY })
    .opacity(this.meteorOpacity)
  }
}
