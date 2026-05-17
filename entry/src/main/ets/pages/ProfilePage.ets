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
      .backgroundColor('#1552FFA1')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#DDFFFFFF')
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
    .focusable(false)
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
      .backgroundColor('#1552FFA1')
      .alignContent(Alignment.Center)

      Text(title)
        .fontSize(14)
        .fontColor('#DDFFFFFF')
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
        .backgroundColor(0x0A0F1A)

      Scroll() {
        Column() {
          // 顶部标题
          Row() {
            Text('我的')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(0xFFFFFF)
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ top: this.statusBarHeight + 16, bottom: 28 })

          // 个人信息卡片 —— 月亮效果头像
          Column() {
            Stack() {
              // 最外层：大范围柔和绿色辉光（模拟月球周围的大气散射光晕）
              Column()
                .width(110).height(110)
                .borderRadius(55)
                .radialGradient({
                  center: ['50%', '50%'],
                  radius: 55,
                  colors: [['#0052FFA1', 0.55], ['#2252FFA1', 0.72], ['#0052FFA1', 1.0]]
                })

              // 外部辉光环：模拟月球边缘的绿色大气折射光
              Column()
                .width(96).height(96)
                .borderRadius(48)
                .shadow({ radius: 28, color: '#6052FFA1', offsetX: 0, offsetY: 0 })

              // 月球球体 —— 暗面（主体深色球，左上微亮模拟反射）
              Column()
                .width(88).height(88)
                .borderRadius(44)
                .radialGradient({
                  center: ['35%', '30%'],
                  radius: 60,
                  colors: [['#1A2234', 0], ['#0D1320', 0.5], ['#060A12', 1.0]]
                })
                .shadow({ radius: 20, color: '#4052FFA1', offsetX: 0, offsetY: 0 })

              // 月球表面：亮边缘弧光（右下侧绿色新月形高光）
              Column()
                .width(88).height(88)
                .borderRadius(44)
                .radialGradient({
                  center: ['75%', '70%'],
                  radius: 50,
                  colors: [['#0052FFA1', 0], ['#3352FFA1', 0.6], ['#5552FFA1', 0.82], ['#0052FFA1', 1.0]]
                })

              // 顶部微弱反光点（模拟月表凸起反射）
              Column()
                .width(20).height(12)
                .borderRadius(6)
                .backgroundColor('#10FFFFFF')
                .opacity(0.3)
                .position({ x: 28, y: 18 })

              // 月球表面"陨石坑"质感 —— 用几个小暗点模拟
              Column()
                .width(8).height(8)
                .borderRadius(4)
                .backgroundColor('#08000000')
                .position({ x: 36, y: 42 })
              Column()
                .width(5).height(5)
                .borderRadius(3)
                .backgroundColor('#06000000')
                .position({ x: 52, y: 55 })
              Column()
                .width(6).height(6)
                .borderRadius(3)
                .backgroundColor('#05000000')
                .position({ x: 24, y: 60 })
            }
            .width(110).height(110)
            .alignContent(Alignment.Center)

            Text('X.FM 听众')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(0xFFFFFF)
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
              Column().width(1).height(28).backgroundColor('#10FFFFFF')
              this.StatItem(this.focusTime, '专注模式')
              Column().width(1).height(28).backgroundColor('#10FFFFFF')
              this.StatItem(this.sleepTime, '睡眠模式')
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('88%')
          .padding({ top: 18, bottom: 18 })
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 1, color: '#0DFFFFFF' })
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
            Column().width('85%').height(0.5).backgroundColor(0x0DFFFFFF).alignSelf(ItemAlign.End)
            this.SwitchRow('\u231A', '定时关闭', this.sleepTimer, (v: boolean) => { this.sleepTimer = v; })
            Column().width('85%').height(0.5).backgroundColor(0x0DFFFFFF).alignSelf(ItemAlign.End)
            this.SettingRow('\u266B', '音质', '标准', () => {})
          }
          .width('88%')
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#0DFFFFFF' })
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
            Column().width('85%').height(0.5).backgroundColor(0x0DFFFFFF).alignSelf(ItemAlign.End)
            this.SettingRow('\u2699', '关于 X.FM', 'v6.10', () => { this.showAboutDialog(); })
          }
          .width('88%')
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#0DFFFFFF' })
          .clip(true)

          Blank().height(110)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .focusable(false)
    }
    .width('100%').height('100%')
    .focusable(false)
  }
}
