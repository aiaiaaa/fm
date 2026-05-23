import { window, router } from '@kit.ArkUI';

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

  @Builder
  ContactRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#5E6678')
        .width(60)
      Text(value)
        .fontSize(15)
        .fontColor('#DDFFFFFF')
        .layoutWeight(1)
    }
    .width('100%')
    .height(52)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')

      Column() {
        // 头部 —— 沿用设置页头部样式
        Row({ space: 10 }) {
          Image($r('app.media.back_icon'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .margin({ left: 38 })
            .onClick(() => {
              router.back();
            })

          Text('关于我们')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(0xFFFFFF)
            .letterSpacing(2)
            .lineHeight(18)
            .margin({ top: 0, bottom: 0 })
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .backgroundColor('#0E1420')
        .shadow({ radius: 12, color: '#40000000', offsetX: 0, offsetY: 4 })
        .padding({ top: this.statusBarHeight + 14, bottom: 14 })

        Scroll() {
          Column() {
            // ========== 联系我们 ==========

            Text('联系我们')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width('100%')
              .margin({ top: 24, bottom: 8 })

            Column() {
              this.ContactRow('邮件', 'serivice@vanfan.com')

              Divider()
                .width('85%')
                .height(0.5)
                .color('#1AFFFFFF')
                .alignSelf(ItemAlign.End)

              this.ContactRow('抖音', 'X.FM')

              Divider()
                .width('85%')
                .height(0.5)
                .color('#1AFFFFFF')
                .alignSelf(ItemAlign.End)

              this.ContactRow('官网', 'vanfan.com/xfm')
            }
            .width('88%')
            .borderRadius(18)
            .backgroundColor('#111622')
            .border({ width: 0.5, color: '#1DFFFFFF' })
            .clip(true)

            // ========== XFM创作者 ==========

            Text('XFM创作者')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width('100%')
              .margin({ top: 28, bottom: 8 })

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
            .width('88%')
            .borderRadius(18)
            .backgroundColor('#111622')
            .border({ width: 0.5, color: '#1DFFFFFF' })

            // ========== 底部协议与备案 ==========

            Column() {
              // 第一行：服务协议 + 隐私协议
              Row({ space: 24 }) {
                Text('服务协议')
                  .fontSize(12)
                  .fontColor('#5E6678')
                  .decoration({ type: TextDecorationType.None })
                Text('|')
                  .fontSize(12)
                  .fontColor('#3E4656')
                Text('隐私协议')
                  .fontSize(12)
                  .fontColor('#5E6678')
                  .decoration({ type: TextDecorationType.None })
              }
              .justifyContent(FlexAlign.Center)

              // 第二行：备案信息
              Text('渝ICP备2021332666号-A6')
                .fontSize(11)
                .fontColor('#3E4656')
                .margin({ top: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 48, bottom: 32 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%').height('100%')
  }
}