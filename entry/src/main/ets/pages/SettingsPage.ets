import i18n from '@ohos.i18n';
import { window, router } from '@kit.ArkUI';
// 持久化 key 注册
PersistentStorage.persistProp<string>('settings_language', '中文');
PersistentStorage.persistProp<boolean>('settings_keepScreenOn', false);

@Entry
@Component
struct SettingsPage {
  @State statusBarHeight: number = 40;
  @StorageLink('settings_language') language: string = '中文';
  @StorageLink('settings_keepScreenOn') keepScreenOn: boolean = false;
  @State showLangDialog: boolean = false;

  // Logo 竖条动画高度
  @State logoBars: number[] = [6, 14, 10, 18];

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = Math.max(px2vp(area.topRect.height), 24);
      win.setWindowKeepScreenOn(this.keepScreenOn);
    }).catch(() => {
      this.statusBarHeight = 44;
    });

    // 简单动画：周期性改变竖条高度
    setInterval(() => {
      this.logoBars = [
        Math.floor(Math.random() * 14) + 4,
        Math.floor(Math.random() * 14) + 4,
        Math.floor(Math.random() * 14) + 4,
        Math.floor(Math.random() * 14) + 4
      ];
    }, 600);
  }

  private toggleScreenOn(isOn: boolean): void {
    this.keepScreenOn = isOn;
    window.getLastWindow(getContext(this)).then(win => {
      win.setWindowKeepScreenOn(isOn);
    }).catch(() => {});
  }

  private changeLanguage(lang: string) {
    this.language = lang;
    let langCode = lang === '中文' ? 'zh-CN' : 'en-US';
    try {
      i18n.System.setAppPreferredLanguage(langCode);
      console.info(`语言已切换为: ${langCode}`);
    } catch (error) {
      console.error(`语言切换失败: ${error}`);
    }
  }

  @Builder
  buildLangDialog() {
    Column()
      .width('100%').height('100%')
      .backgroundColor('#60000000')
      .onClick(() => { this.showLangDialog = false; })

    Stack() {
      Column() {
        Text('选择语言')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .margin({ bottom: 20 })

        Row() {
          Radio({ value: '中文', group: 'lang' })
            .checked(this.language === '中文')
            .onChange((isChecked: boolean) => {
              if (isChecked) this.changeLanguage('中文');
            })
            .width(20).height(20)
          Text($r('app.string.chinese'))
            .fontSize(15)
            .fontColor('#FFFFFF')
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8 })
        .borderRadius(8)
        .onClick(() => { this.language = '中文'; })
        .backgroundColor(this.language === '中文' ? '#10FFFFFF' : 'transparent')

        Row() {
          Radio({ value: 'English', group: 'lang' })
            .checked(this.language === 'English')
            .onChange((isChecked: boolean) => {
              if (isChecked) this.changeLanguage('English');
            })
            .width(20).height(20)
          Text('English')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8 })
        .borderRadius(8)
        .onClick(() => { this.language = 'English'; })
        .backgroundColor(this.language === 'English' ? '#10FFFFFF' : 'transparent')
        .margin({ top: 4 })

        Text($r('app.string.confirm'))
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
    }
    .width('100%').height('100%')
    .position({ x: 0, y: 0 })
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')

      Column() {
        Row({ space: 10 }) {
          Image($r('app.media.back_icon'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .margin({ left: 18 }) // 直接控制图标的左边距，确保和下面的标题对齐
            .onClick(() => {
              router.back();
            })

          Text($r('app.string.about'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(0xFFFFFF)
            .letterSpacing(2)
            .lineHeight(18)
            .margin({ top: 0, bottom: 0 })
        }
        .width('100%')
        .padding({ right: 18 }) // 移除 left:18，交由返回按钮的 margin 控制
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .backgroundColor('#0E1420')
        .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })
        .padding({ top: this.statusBarHeight + 14, bottom: 14 })

        Column() {
          Row() {
            Text($r('app.string.language'))
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
          // 下方内容的左内边距也是 18
          .padding({ left: 18, right: 18 })
          .onClick(() => { this.showLangDialog = true; })

          Divider()
            .width('90%')
            .height(0.5)
            .color('#1AFFFFFF')
            .alignSelf(ItemAlign.End)

          Row() {
            Text($r('app.string.screen_lighting'))
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

          Divider()
            .width('90%')
            .height(0.5)
            .color('#1AFFFFFF')
            .alignSelf(ItemAlign.End)

          Row() {
            Text($r('app.string.version'))
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
        .border({ width: 0.5, color: '#1DFFFFFF' })
        .clip(true)
        .margin({ top: 24 })
      }
      .width('100%')
      .height('100%')

      if (this.showLangDialog) {
        this.buildLangDialog()
      }
    }
    .width('100%').height('100%')
  }
}