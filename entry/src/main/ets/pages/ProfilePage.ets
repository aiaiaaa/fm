import { window } from '@kit.ArkUI';

/**
 * "个人" Tab 页 —— 与 PlayerPage 统一深空暗黑风格
 *
 * 设计要素：
 *   - 深色渐变背景（#070B1D → #0E1333 → #050814）
 *   - 圆形头像带绿色渐变边框 + 光晕
 *   - 统计数据卡片半透明毛玻璃
 *   - 设置列表采用圆角分组 + 微边框
 *   - 所有强调色保持 #2EE89D
 */
@Component
export struct ProfilePage {
  @State autoPlay: boolean = true;
  @State sleepTimer: boolean = false;
  @State darkMode: boolean = true;
  @State statusBarHeight: number = 40;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    }).catch(() => {
      this.statusBarHeight = 40;
    });
  }

  @Builder
  SettingRow(icon: string, title: string, value: string, onTap?: () => void) {
    Row() {
      Stack() {
        Text(icon)
          .fontSize(16)
          .fontColor('#2EE89D')
      }
      .width(32).height(32)
      .borderRadius(8)
      .backgroundColor('#2EE89D15')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#FFFFFFDD')
        .layoutWeight(1)
        .margin({ left: 12 })

      Text(value)
        .fontSize(12)
        .fontColor('#FFFFFF55')

      Text('\u203A')
        .fontSize(18)
        .fontColor('#FFFFFF44')
        .margin({ left: 8 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
    .onClick(() => {
      if (onTap) {
        onTap();
      }
    })
  }

  @Builder
  SwitchRow(icon: string, title: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Stack() {
        Text(icon)
          .fontSize(16)
          .fontColor('#2EE89D')
      }
      .width(32).height(32)
      .borderRadius(8)
      .backgroundColor('#2EE89D15')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#FFFFFFDD')
        .layoutWeight(1)
        .margin({ left: 12 })

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#2EE89D')
        .switchPointColor('#0A0E27')
        .onChange((isOn: boolean) => onChange(isOn))
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
  }

  @Builder
  StatItem(value: string, label: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2EE89D')
      Text(label)
        .fontSize(11)
        .fontColor('#FFFFFF77')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      // 深色背景，与 PlayerPage 一致
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#070B1D', 0], ['#0E1333', 0.5], ['#050814', 1]]
        })

      Scroll() {
        Column() {
          // 顶部标题
          Row() {
            Text('个人')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ top: this.statusBarHeight + 16, bottom: 28 })

          // 个人信息卡片
          Column() {
            // 头像：外圈绿色渐变光环
            Stack() {
              // 光晕
              Column()
                .width(92).height(92)
                .borderRadius(46)
                .linearGradient({
                  angle: 135,
                  colors: [['#2EE89D', 0], ['#00F2FE', 1]]
                })
                .opacity(0.25)

              // 外环
              Column()
                .width(84).height(84)
                .borderRadius(42)
                .border({ width: 2.5, color: '#2EE89D' })
                .shadow({ radius: 16, color: '#2EE89D55', offsetX: 0, offsetY: 0 })

              // 内部
              Stack() {
                Column()
                  .width(76).height(76)
                  .borderRadius(38)
                  .linearGradient({
                    angle: 135,
                    colors: [['#12183A', 0], ['#1A2248', 1]]
                  })

                Text('X')
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2EE89D')
              }
              .width(76).height(76)
              .alignContent(Alignment.Center)
            }
            .width(92).height(92)
            .alignContent(Alignment.Center)

            Text('X.FM 听众')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .margin({ top: 16 })

            Text('保持专注，也享受睡眠')
              .fontSize(12)
              .fontColor('#FFFFFF66')
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 28 })

          // 统计卡片
          Row() {
            this.StatItem('0h', '收听时长')
            Column().width(1).height(28).backgroundColor('#FFFFFF15')
            this.StatItem('0', '收藏频道')
            Column().width(1).height(28).backgroundColor('#FFFFFF15')
            this.StatItem('0', '专注天数')
          }
          .width('88%')
          .padding({ top: 18, bottom: 18 })
          .borderRadius(18)
          .linearGradient({
            angle: 135,
            colors: [['#12183A', 0], ['#0E1230', 1]]
          })
          .border({ width: 1, color: '#FFFFFF12' })
          .shadow({ radius: 12, color: '#00000044', offsetX: 0, offsetY: 4 })
          .alignItems(VerticalAlign.Center)

          // 播放设置
          Text('播放设置')
            .fontSize(12)
            .fontColor('#FFFFFF55')
            .letterSpacing(2)
            .margin({ top: 32, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u25B6', '启动自动续播', this.autoPlay, (v: boolean) => { this.autoPlay = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF10').alignSelf(ItemAlign.End)
            this.SwitchRow('\u231A', '定时关闭', this.sleepTimer, (v: boolean) => { this.sleepTimer = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF10').alignSelf(ItemAlign.End)
            this.SettingRow('\u266B', '音质', '标准', () => {})
          }
          .width('88%')
          .borderRadius(18)
          .linearGradient({
            angle: 160,
            colors: [['#10152E', 0], ['#0C1028', 1]]
          })
          .border({ width: 1, color: '#FFFFFF10' })
          .clip(true)

          // 外观设置
          Text('外观')
            .fontSize(12)
            .fontColor('#FFFFFF55')
            .letterSpacing(2)
            .margin({ top: 24, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u263D', '深色主题', this.darkMode, (v: boolean) => { this.darkMode = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF10').alignSelf(ItemAlign.End)
            this.SettingRow('\u2699', '关于 X.FM', 'v6.10', () => {})
          }
          .width('88%')
          .borderRadius(18)
          .linearGradient({
            angle: 160,
            colors: [['#10152E', 0], ['#0C1028', 1]]
          })
          .border({ width: 1, color: '#FFFFFF10' })
          .clip(true)

          Blank().height(80)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
  }
}
