import { window } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

/**
 * 设置页面
 * - 语言：点击弹出单选对话框切换
 * - 版本号：1.0.0（纯展示）
 * - 屏幕常亮：开关
 */
@Entry
@Component
struct SettingsPage {
  @State statusBarHeight: number = 40;
  @State language: string = '简体中文';
  @State keepScreenOn: boolean = false;

  private languageOptions: string[] = ['简体中文', '繁體中文', 'English', '日本語'];

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(area.topRect.height);
    }).catch(() => {
      this.statusBarHeight = 40;
    });
  }

  private showLanguagePicker(): void {
    // 构建 buttons 列表
    const buttons: promptAction.Button[] = this.languageOptions.map((lang: string) => {
      return { text: lang, color: lang === this.language ? '#52FFA1' : '#FFFFFF' } as promptAction.Button;
    });

    promptAction.showActionMenu({
      title: '选择语言',
      buttons: buttons
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index >= 0 && result.index < this.languageOptions.length) {
        this.language = this.languageOptions[result.index];
      }
    }).catch(() => {
      // 用户取消
    });
  }

  private toggleScreenOn(isOn: boolean): void {
    this.keepScreenOn = isOn;
    // 设置屏幕常亮
    window.getLastWindow(getContext(this)).then(win => {
      win.setWindowKeepScreenOn(isOn);
    }).catch(() => {});
  }

  build() {
    Column() {
      // 背景
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')
        .position({ x: 0, y: 0 })

      // 顶部导航栏
      Row() {
        Text('\u2190')
          .fontSize(22)
          .fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
          .margin({ right: 12 })

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.statusBarHeight + 12, bottom: 16 })

      // 设置列表
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
        .onClick(() => this.showLanguagePicker())

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
      }
      .width('88%')
      .borderRadius(18)
      .backgroundColor('#111622')
      .border({ width: 0.5, color: '#0DFFFFFF' })
      .clip(true)
      .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
  }
}
