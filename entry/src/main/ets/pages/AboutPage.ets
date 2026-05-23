import { window, router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';

@Entry
@Component
struct AboutPage {
  @State statusBarHeight: number = 40;

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = Math.max(px2vp(area.topRect.height), 24);
    }).catch(() => {
      this.statusBarHeight = 44;
    });
  }

  // 复制文本到剪贴板
  copyToClipboard(text: string) {
    let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    let systemPasteboard = pasteboard.getSystemPasteboard();
    systemPasteboard.setData(pasteData).then(() => {
      promptAction.showToast({ message: '复制成功', bottom: 80 });
    }).catch(() => {
      promptAction.showToast({ message: '复制失败', bottom: 80 });
    });
  }

  // 拉起浏览器跳转
  openBrowser(url: string) {
    let context = getContext(this) as common.UIAbilityContext;
    let want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    context.startAbility(want).catch(() => {
      promptAction.showToast({ message: '无法打开外部浏览器' });
    });
  }

  // 修改 Builder，支持传入右侧图标资源和点击事件
  @Builder
  ContactRow(label: Resource, value: string, iconRes?: Resource, onClickAction?: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#5E6678')
        .fontWeight(FontWeight.Bold)
        .width(60)
      Text(value)
        .fontSize(15)
        .fontColor('#DDFFFFFF')
        .layoutWeight(1)

      if (iconRes) {
        Image(iconRes)
          .width(16)
          .height(16)
          .fillColor('#99FFFFFF')
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (onClickAction) {
        onClickAction();
      }
    })
  }

  build() {
    Stack() {
      // 背景
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

        Scroll() {
          Column() {
            Row() {
              Text($r('app.string.contact_us'))
                .fontSize(16)
                .fontColor('#99FFFFFF')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 12 })
            .backgroundColor('#1A1F2B')
            .margin({ top: 0 })

            Column() {
              this.ContactRow($r('app.string.mail'), 'service@vanfan.com', $r('app.media.ic_copy'), () => {
                this.copyToClipboard('service@vanfan.com');
              })

              Divider()
                .width('85%')
                .height(0.5)
                .color('#1AFFFFFF')
                .alignSelf(ItemAlign.End)

              this.ContactRow($r('app.string.tiktok'), 'X.FM', undefined, () => {
                this.openBrowser('https://www.douyin.com/search/X.FM');
              })

              Divider()
                .width('85%')
                .height(0.5)
                .color('#1AFFFFFF')
                .alignSelf(ItemAlign.End)

              this.ContactRow($r('app.string.official_web'), 'vanfan.com/xfm', undefined, () => {
                this.openBrowser('https://vanfan.com/xfm');
              })
            }
            .width('100%')
            .backgroundColor('#111622')

            Row() {
              Text($r('app.string.app_developer'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#99FFFFFF')
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 12 })
            .backgroundColor('#1A1F2B')

            // 创作者简介卡片
            Column() {
              Text(
                'X.FM 是由 AGENT 驱动的实时资讯播报平台，致力于用 AI 技术重塑电台体验。' +
                  '我们相信信息可以更智能、更个性化、更沉浸。' +
                  '专注模式提供深度新闻，睡眠模式提供舒缓白噪音，' +
                  '让每一位听众都能在 X.FM 找到属于自己的声音空间。'
              )
                .fontSize(14)
                .fontColor('#BBFFFFFF')
                .lineHeight(24)
                .width('100%')
                .padding(18)
            }
            .width('100%')
            .backgroundColor('#111622')
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Column() {
          Row({ space: 24 }) {
            Text($r('app.string.terms'))
              .fontSize(12)
              .fontColor('#5E6678')
              .decoration({ type: TextDecorationType.None })
              .onClick(() => {
                this.openBrowser('https://vanfan.com/terms');
              })
            Text('|')
              .fontSize(12)
              .fontColor('#3E4656')
            Text($r('app.string.privacy'))
              .fontSize(12)
              .fontColor('#5E6678')
              .decoration({ type: TextDecorationType.None })
              .onClick(() => {
                this.openBrowser('https://vanfan.com/terms');
              })
          }
          .justifyContent(FlexAlign.Center)

          Text('渝ICP备202103333号-6A')
            .fontSize(11)
            .fontColor('#5E6678')
            .margin({ top: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 16, bottom: 32 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}