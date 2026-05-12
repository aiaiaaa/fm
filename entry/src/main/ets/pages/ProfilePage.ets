import { window } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ListeningStats } from '../services/ListeningStats';

/**
 * "个人" Tab 页
 * - 统计数据：累计总时长、专注模式时长、睡眠模式时长
 * - 设置：自动续播、定时关闭、音质
 * - 关于：弹窗显示版本信息
 */
@Component
export struct ProfilePage {
  @State autoPlay: boolean = true;
  @State sleepTimer: boolean = false;
  @State darkMode: boolean = true;
  @State statusBarHeight: number = 40;
  @State totalTime: string = '0s';
  @State focusTime: string = '0s';
  @State sleepTime: string = '0s';

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    }).catch(() => {
      this.statusBarHeight = 40;
    });

    // 初始化并加载统计数据
    const context = getContext(this) as common.UIAbilityContext;
    ListeningStats.init(context).then(() => {
      this.refreshStats();
    });
  }

  onPageShow(): void {
    this.refreshStats();
  }

  private async refreshStats(): Promise<void> {
    const stats = await ListeningStats.getStats();
    this.totalTime = ListeningStats.formatSeconds(stats.total);
    this.focusTime = ListeningStats.formatSeconds(stats.focus);
    this.sleepTime = ListeningStats.formatSeconds(stats.sleep);
  }

  private showAboutDialog(): void {
    promptAction.showDialog({
      title: '关于 X.FM',
      message: 'X.FM - AI 智能电台\n\n版本：v6.10\n平台：HarmonyOS NEXT\nSDK：API 12+\n\n由 AGENT 驱动的实时资讯播报平台。\n专注模式提供深度新闻，睡眠模式提供舒缓白噪音。\n\n© 2024-2026 X.FM Team',
      buttons: [{ text: '确定', color: '#52FFA1' }]
    });
  }

  @Builder
  SettingRow(icon: string, title: string, value: string, onTap?: () => void) {
    Row() {
      Stack() {
        Text(icon)
          .fontSize(16)
          .fontColor('#52FFA1')
      }
      .width(32).height(32)
      .borderRadius(8)
      .backgroundColor('#52FFA115')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#FFFFFFDD')
        .layoutWeight(1)
        .margin({ left: 12 })

      Text(value)
        .fontSize(12)
        .fontColor('#5E6678')

      Text('\u203A')
        .fontSize(18)
        .fontColor('#5E6678')
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
          .fontColor('#52FFA1')
      }
      .width(32).height(32)
      .borderRadius(8)
      .backgroundColor('#52FFA115')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#FFFFFFDD')
        .layoutWeight(1)
        .margin({ left: 12 })

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#52FFA1')
        .switchPointColor('#0A0F1A')
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
        .fontColor('#52FFA1')
      Text(label)
        .fontSize(11)
        .fontColor('#5E6678')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')

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
            Stack() {
              Column()
                .width(92).height(92)
                .borderRadius(46)
                .linearGradient({
                  angle: 135,
                  colors: [['#52FFA1', 0], ['#00D2FF', 1]]
                })
                .opacity(0.2)

              Column()
                .width(84).height(84)
                .borderRadius(42)
                .border({ width: 2, color: '#FFFFFF22' })

              Stack() {
                Column()
                  .width(76).height(76)
                  .borderRadius(38)
                  .backgroundColor('#111622')

                Text('X')
                  .fontSize(32)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#52FFA1')
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
              .fontColor('#5E6678')
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 8, bottom: 28 })

          // 收听统计卡片
          Column() {
            Text('收听统计')
              .fontSize(12)
              .fontColor('#5E6678')
              .letterSpacing(2)
              .margin({ bottom: 16 })

            Row() {
              this.StatItem(this.totalTime, '累计时长')
              Column().width(1).height(28).backgroundColor('#FFFFFF10')
              this.StatItem(this.focusTime, '专注模式')
              Column().width(1).height(28).backgroundColor('#FFFFFF10')
              this.StatItem(this.sleepTime, '睡眠模式')
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('88%')
          .padding({ top: 18, bottom: 18 })
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 1, color: '#FFFFFF0D' })
          .alignItems(HorizontalAlign.Center)

          // 播放设置
          Text('播放设置')
            .fontSize(12)
            .fontColor('#5E6678')
            .letterSpacing(2)
            .margin({ top: 32, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u25B6', '启动自动续播', this.autoPlay, (v: boolean) => { this.autoPlay = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF0D').alignSelf(ItemAlign.End)
            this.SwitchRow('\u231A', '定时关闭', this.sleepTimer, (v: boolean) => { this.sleepTimer = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF0D').alignSelf(ItemAlign.End)
            this.SettingRow('\u266B', '音质', '标准', () => {})
          }
          .width('88%')
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#FFFFFF0D' })
          .clip(true)

          // 其他
          Text('其他')
            .fontSize(12)
            .fontColor('#5E6678')
            .letterSpacing(2)
            .margin({ top: 24, left: 24, bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.SwitchRow('\u263D', '深色主题', this.darkMode, (v: boolean) => { this.darkMode = v; })
            Column().width('85%').height(0.5).backgroundColor('#FFFFFF0D').alignSelf(ItemAlign.End)
            this.SettingRow('\u2699', '关于 X.FM', 'v6.10', () => { this.showAboutDialog(); })
          }
          .width('88%')
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#FFFFFF0D' })
          .clip(true)

          Blank().height(110)
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
