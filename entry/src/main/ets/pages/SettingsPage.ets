import { window } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';

/**
 * 设置页面
 * - 顶部导航栏（< 返回 + 标题）带阴影与内容区分隔
 * - 语言：点击弹出居中小弹窗，Radio 单选"中文 / English"
 * - 版本号：1.0.0（纯展示）
 * - 屏幕常亮：开关
 * - 所有可变设置使用 @StorageLink 持久化
 */

// 在页面加载前注册持久化 key（只需调用一次，重复调用安全）
PersistentStorage.persistProp<string>('settings_language', '中文');
PersistentStorage.persistProp<boolean>('settings_keepScreenOn', false);

@Entry
@Component
struct SettingsPage {
  @State statusBarHeight: number = 40;
  @StorageLink('settings_language') language: string = '中文';
  @StorageLink('settings_keepScreenOn') keepScreenOn: boolean = false;

  // 语言弹窗
  @State showLangDialog: boolean = false;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
      // 应用已保存的屏幕常亮设置
      win.setWindowKeepScreenOn(this.keepScreenOn);
    }).catch(() => {
      this.statusBarHeight = 40;
    });
  }

  private toggleScreenOn(isOn: boolean): void {
    this.keepScreenOn = isOn;
    window.getLastWindow(getContext(this)).then(win => {
      win.setWindowKeepScreenOn(isOn);
    }).catch(() => {});
  }

  build() {
    Stack() {
      // 全屏背景
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')

      Column() {
        // ======== 顶部导航栏（带阴影"帽子"） ========
        Row() {
          // 内层容器宽度与下方列表卡片一致（88% 居中），这样图标的左边缘
          // 才会跟列表里"语言/屏幕常亮/版本号"文字开头精确对齐。
          Row() {
            Text('\u2039')
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .onClick(() => { router.back(); })
              .padding({ right: 6 })

            Text('设置')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
          }
          .width('88%')
          .padding({ left: 18, right: 18 })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: this.statusBarHeight + 14, bottom: 14 })
        .backgroundColor('#0E1420')
        .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })

        // ======== 设置列表 ========
        Column() {
          // 语言
          Row() {
            Text('语言')
              .fontSize(15)
              .fontColor('#DDFFFFFF')
              .layoutWeight(1)

            Text(this.language)
              .fontSize(14)
              .fontColor('#5E6678')

            Text('\u203A')
              .fontSize(18)
              .fontColor('#3E4656')
              .margin({ left: 8 })
          }
          .width('100%')
          .height(56)
          .padding({ left: 18, right: 18 })
          .onClick(() => { this.showLangDialog = true; })

          // 分割线
          Column()
            .width('90%')
            .height(0.5)
            .backgroundColor('#0AFFFFFF')
            .alignSelf(ItemAlign.End)

          // 屏幕常亮
          Row() {
            Text('屏幕常亮')
              .fontSize(15)
              .fontColor('#DDFFFFFF')
              .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.keepScreenOn })
              .selectedColor('#52FFA1')
              .switchPointColor('#0A0F1A')
              .onChange((isOn: boolean) => this.toggleScreenOn(isOn))
          }
          .width('100%')
          .height(56)
          .padding({ left: 18, right: 18 })

          // 分割线
          Column()
            .width('90%')
            .height(0.5)
            .backgroundColor('#0AFFFFFF')
            .alignSelf(ItemAlign.End)

          // 版本号
          Row() {
            Text('版本号')
              .fontSize(15)
              .fontColor('#DDFFFFFF')
              .layoutWeight(1)

            Text('1.0.0')
              .fontSize(14)
              .fontColor('#5E6678')
          }
          .width('100%')
          .height(56)
          .padding({ left: 18, right: 18 })
        }
        .width('88%')
        .borderRadius(18)
        .backgroundColor('#111622')
        .border({ width: 0.5, color: '#0DFFFFFF' })
        .clip(true)
        .margin({ top: 24 })
      }
      .width('100%')
      .height('100%')

      // ======== 语言选择弹窗（居中，灰偏亮背景，Radio 单选） ========
      if (this.showLangDialog) {
        // 遮罩
        Column()
          .width('100%').height('100%')
          .backgroundColor('#60000000')
          .onClick(() => { this.showLangDialog = false; })

        // 弹窗卡片
        Column() {
          Text('选择语言')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .margin({ bottom: 20 })

          // 中文选项
          Row() {
            Radio({ value: '中文', group: 'lang' })
              .checked(this.language === '中文')
              .onChange((isChecked: boolean) => {
                if (isChecked) this.language = '中文';
              })
              .width(20).height(20)

            Text('中文')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center)
          .onClick(() => { this.language = '中文'; })

          // English 选项
          Row() {
            Radio({ value: 'English', group: 'lang' })
              .checked(this.language === 'English')
              .onChange((isChecked: boolean) => {
                if (isChecked) this.language = 'English';
              })
              .width(20).height(20)

            Text('English')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center)
          .onClick(() => { this.language = 'English'; })

          // 确定按钮
          Text('确定')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#52FFA1')
            .margin({ top: 16 })
            .alignSelf(ItemAlign.End)
            .onClick(() => { this.showLangDialog = false; })
        }
        .width('70%')
        .padding({ top: 24, bottom: 20, left: 24, right: 24 })
        .borderRadius(16)
        .backgroundColor('#2A2E38')
        .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 8 })
        .position({ x: '15%', y: '35%' })
      }
    }
    .width('100%').height('100%')
  }
}
