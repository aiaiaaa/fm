import { window, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ListeningStats } from '../services/ListeningStats';

/**
 * "个人" Tab 页
 * - 月亮头像
 * - 收听统计
 * - 定时关闭（带时长胶囊 + 自定义 picker + 开关联动）
 * - 意见反馈 / 设置 / 关于我们
 */
@Component
export struct ProfilePage {
  @State statusBarHeight: number = 40;
  @State totalTime: string = '0s';
  @State focusTime: string = '0s';
  @State sleepTime: string = '0s';

  // 定时关闭
  @State sleepTimerOn: boolean = false;
  @State selectedMinutes: number = 0; // 0 表示未选
  @State showCustomPicker: boolean = false;
  @State customPickerValue: number = 15; // picker 里的临时值

  private timerOptions: number[] = [30, 60, 90, 120];

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    }).catch(() => {
      this.statusBarHeight = 40;
    });

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

  

  /** 选中某个预设时长 */
  private selectTimer(minutes: number): void {
    if (this.selectedMinutes === minutes) {
      // 反选
      this.selectedMinutes = 0;
      this.sleepTimerOn = false;
    } else {
      this.selectedMinutes = minutes;
      this.sleepTimerOn = true;
    }
  }

  /** 开关切换 */
  private onTimerSwitchChange(isOn: boolean): void {
    this.sleepTimerOn = isOn;
    if (!isOn) {
      this.selectedMinutes = 0;
    }
  }

  /** 自定义 picker 确认 */
  private onCustomConfirm(): void {
    this.selectedMinutes = this.customPickerValue;
    this.sleepTimerOn = true;
    this.showCustomPicker = false;
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

  @Builder
  MenuRow(icon: string, title: string, onTap?: () => void) {
    Row() {
      Text(icon)
        .fontSize(18)
        .fontColor('#52FFA1')
        .margin({ right: 12 })

      Text(title)
        .fontSize(15)
        .fontColor('#DDFFFFFF')
        .layoutWeight(1)

      Text('\u203A')
        .fontSize(20)
        .fontColor('#3E4656')
    }
    .width('100%')
    .height(56)
    .padding({ left: 18, right: 18 })
    .onClick(() => { if (onTap) onTap(); })
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
              Column()
                .width(110).height(110)
                .borderRadius(55)
                .radialGradient({
                  center: ['50%', '50%'],
                  radius: 55,
                  colors: [['#0052FFA1', 0.55], ['#2252FFA1', 0.72], ['#0052FFA1', 1.0]]
                })
              Column()
                .width(96).height(96)
                .borderRadius(48)
                .shadow({ radius: 28, color: '#6052FFA1', offsetX: 0, offsetY: 0 })
              Column()
                .width(88).height(88)
                .borderRadius(44)
                .radialGradient({
                  center: ['35%', '30%'],
                  radius: 60,
                  colors: [['#1A2234', 0], ['#0D1320', 0.5], ['#060A12', 1.0]]
                })
                .shadow({ radius: 20, color: '#4052FFA1', offsetX: 0, offsetY: 0 })
              Column()
                .width(88).height(88)
                .borderRadius(44)
                .radialGradient({
                  center: ['75%', '70%'],
                  radius: 50,
                  colors: [['#0052FFA1', 0], ['#3352FFA1', 0.6], ['#5552FFA1', 0.82], ['#0052FFA1', 1.0]]
                })
              Column()
                .width(20).height(12)
                .borderRadius(6)
                .backgroundColor('#10FFFFFF')
                .opacity(0.3)
                .position({ x: 28, y: 18 })
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

          // ========== 定时关闭模块 ==========
          Column() {
            // 标题行：图标 + 标题 + 描述 + 开关
            Row() {
              Text('\u231A')
                .fontSize(18)
                .fontColor('#52FFA1')
                .margin({ right: 10 })

              Column() {
                Text('定时关闭')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#EEFFFFFF')
                Text('开启后，电台将在设定时间后自动关闭')
                  .fontSize(11)
                  .fontColor('#5E6678')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.sleepTimerOn })
                .selectedColor('#52FFA1')
                .switchPointColor('#0A0F1A')
                .onChange((isOn: boolean) => this.onTimerSwitchChange(isOn))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 时长胶囊选择区
            Row({ space: 10 }) {
              ForEach(this.timerOptions, (minutes: number) => {
                Column() {
                  Text(`${minutes}`)
                    .fontSize(this.selectedMinutes === minutes ? 20 : 16)
                    .fontWeight(this.selectedMinutes === minutes ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.selectedMinutes === minutes ? '#52FFA1' : '#8E95A3')
                  Text('分钟')
                    .fontSize(10)
                    .fontColor(this.selectedMinutes === minutes ? '#52FFA1' : '#5E6678')
                    .margin({ top: 2 })
                }
                .width(56).height(56)
                .borderRadius(28)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .border({
                  width: this.selectedMinutes === minutes ? 1.5 : 0.5,
                  color: this.selectedMinutes === minutes ? '#52FFA1' : '#1EFFFFFF'
                })
                .backgroundColor(this.selectedMinutes === minutes ? '#1552FFA1' : '#00000000')
                .onClick(() => this.selectTimer(minutes))
              }, (minutes: number) => `timer-${minutes}`)

              // 自定义按钮
              Column() {
                Text(this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes)
                  ? `${this.selectedMinutes}` : '自定义')
                  .fontSize(this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes) ? 16 : 12)
                  .fontColor(this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes)
                    ? '#52FFA1' : '#8E95A3')
              }
              .width(56).height(56)
              .borderRadius(28)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .border({
                width: (this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes)) ? 1.5 : 0.5,
                color: (this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes))
                  ? '#52FFA1' : '#1EFFFFFF'
              })
              .backgroundColor((this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes))
                ? '#1552FFA1' : '#00000000')
              .onClick(() => {
                this.customPickerValue = this.selectedMinutes > 0 && !this.timerOptions.includes(this.selectedMinutes)
                  ? this.selectedMinutes : 15;
                this.showCustomPicker = true;
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ top: 18 })
          }
          .width('88%')
          .padding({ top: 20, bottom: 20, left: 18, right: 18 })
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#0DFFFFFF' })
          .margin({ top: 28 })

          // ========== 意见反馈 / 设置 / 关于我们 ==========
          Column() {
            this.MenuRow('\uD83D\uDCAC', '意见反馈', () => { router.pushUrl({ url: 'pages/FeedbackPage' }); })
            Column().width('85%').height(0.5).backgroundColor('#0AFFFFFF').alignSelf(ItemAlign.End)
            this.MenuRow('\u2699', '设置', () => { router.pushUrl({ url: 'pages/SettingsPage' }); })
            Column().width('85%').height(0.5).backgroundColor('#0AFFFFFF').alignSelf(ItemAlign.End)
            this.MenuRow('\u24D8', '关于我们', () => { router.pushUrl({ url: 'pages/AboutPage' }); })
          }
          .width('88%')
          .borderRadius(18)
          .backgroundColor('#111622')
          .border({ width: 0.5, color: '#0DFFFFFF' })
          .clip(true)
          .margin({ top: 16 })

          Blank().height(110)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .focusable(false)

      // ========== 自定义时长 Picker 弹层 ==========
      if (this.showCustomPicker) {
        // 遮罩
        Column()
          .width('100%').height('100%')
          .backgroundColor('#80000000')
          .onClick(() => { this.showCustomPicker = false; })

        // 底部弹出面板
        Column() {
          // 顶部操作栏
          Row() {
            Text('取消')
              .fontSize(15)
              .fontColor('#5E6678')
              .onClick(() => { this.showCustomPicker = false; })

            Text('自定义时长')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#EEFFFFFF')

            Text('确定')
              .fontSize(15)
              .fontColor('#52FFA1')
              .onClick(() => this.onCustomConfirm())
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .padding({ left: 24, right: 24, top: 16, bottom: 12 })

          // Picker
          TextPicker({ range: this.buildMinuteRange(), selected: this.customPickerValue - 1 })
            .defaultPickerItemHeight(44)
            .disappearTextStyle({ color: '#335E6678', font: { size: 14 } })
            .textStyle({ color: '#5E6678', font: { size: 16 } })
            .selectedTextStyle({ color: '#52FFA1', font: { size: 22, weight: FontWeight.Bold } })
            .onChange((value: string | string[], index: number | number[]) => {
              const idx = typeof index === 'number' ? index : index[0];
              this.customPickerValue = idx + 1;
            })
            .width('100%')
            .height(200)
        }
        .width('100%')
        .backgroundColor('#1A2030')
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '65%' })
      }
    }
    .width('100%').height('100%')
    .focusable(false)
  }

  /** 生成 1~60 分钟的字符串数组给 TextPicker */
  private buildMinuteRange(): string[] {
    const arr: string[] = [];
    for (let i = 1; i <= 60; i++) {
      arr.push(`${i} 分钟`);
    }
    return arr;
  }
}
