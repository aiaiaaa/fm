/**
 * "个人" Tab 页 —— 基础版：头像、昵称、设置项
 */
@Component
export struct ProfilePage {
  @State autoPlay: boolean = true;
  @State sleepTimer: boolean = false;
  @State darkMode: boolean = true;

  @Builder
  SettingRow(icon: string, title: string, value: string, onTap?: () => void) {
    Row() {
      Text(icon)
        .fontSize(20)
        .width(36)
        .textAlign(TextAlign.Center)

      Text(title)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
        .margin({ left: 8 })

      Text(value)
        .fontSize(13)
        .fontColor('#FFFFFF66')

      Text('\u203A')
        .fontSize(22)
        .fontColor('#FFFFFF55')
        .margin({ left: 8 })
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      if (onTap) {
        onTap();
      }
    })
  }

  @Builder
  SwitchRow(icon: string, title: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(icon)
        .fontSize(20)
        .width(36)
        .textAlign(TextAlign.Center)

      Text(title)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
        .margin({ left: 8 })

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#2EE89D')
        .onChange((isOn: boolean) => onChange(isOn))
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#0A0E27', 0],
            ['#111636', 0.5],
            ['#0A0E27', 1]
          ]
        })

      Scroll() {
        Column() {
          // 顶部个人信息卡
          Column() {
            // 头像
            Stack() {
              Column()
                .width(80).height(80)
                .borderRadius(40)
                .linearGradient({
                  angle: 135,
                  colors: [['#2EE89D', 0], ['#00F2FE', 1]]
                })

              Text('X')
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0A0E27')
            }
            .width(80).height(80)
            .alignContent(Alignment.Center)

            Text('X.FM 听众')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .margin({ top: 14 })

            Text('保持专注，也享受睡眠')
              .fontSize(12)
              .fontColor('#FFFFFF66')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 40, bottom: 30 })

          // 统计卡片
          Row() {
            ForEach([
              { label: '收听时长', value: '0h' },
              { label: '收藏频道', value: '0' },
              { label: '专注天数', value: '0' }
            ], (item: Record<string, string>) => {
              Column() {
                Text(item.value)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2EE89D')
                Text(item.label)
                  .fontSize(11)
                  .fontColor('#FFFFFF88')
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            })
          }
          .width('90%')
          .padding({ top: 20, bottom: 20 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF08')
          .border({ width: 1, color: '#FFFFFF12' })

          // 设置分组
          Text('播放')
            .fontSize(12)
            .fontColor('#FFFFFF55')
            .letterSpacing(2)
            .margin({ top: 28, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u25B6', '启动自动续播', this.autoPlay, (v) => this.autoPlay = v)
            Divider().color('#FFFFFF10').margin({ left: 60, right: 16 })
            this.SwitchRow('\u231A', '定时关闭', this.sleepTimer, (v) => this.sleepTimer = v)
            Divider().color('#FFFFFF10').margin({ left: 60, right: 16 })
            this.SettingRow('\u266B', '音质', '标准', () => {})
          }
          .width('90%')
          .borderRadius(16)
          .backgroundColor('#FFFFFF08')
          .border({ width: 1, color: '#FFFFFF12' })
          .clip(true)

          Text('外观')
            .fontSize(12)
            .fontColor('#FFFFFF55')
            .letterSpacing(2)
            .margin({ top: 20, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u263D', '深色主题', this.darkMode, (v) => this.darkMode = v)
            Divider().color('#FFFFFF10').margin({ left: 60, right: 16 })
            this.SettingRow('\u2699', '关于 X.FM', 'v1.0.0', () => {})
          }
          .width('90%')
          .borderRadius(16)
          .backgroundColor('#FFFFFF08')
          .border({ width: 1, color: '#FFFFFF12' })
          .clip(true)

          Blank().height(60)
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
