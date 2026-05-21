import { window, router } from '@kit.ArkUI';

@Entry
@Component
struct FeedbackPage {
  @State statusBarHeight: number = 40;
  @State selectedCategory: string = '播放问题';
  @State feedbackContent: string = '';

  private categories: string[] = ['播放问题', '兼容问题', '其他BUG'];

  aboutToAppear(): void {
    window.getLastWindow(getContext(this)).then(win => {
      const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = Math.max(px2vp(area.topRect.height), 24);
    }).catch(() => {
      this.statusBarHeight = 44;
    });
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .backgroundColor('#0A0F1A')

      Column() {
        // 1. 复用设置页的头部
        Row({ space: 10 }) {
          Image($r('app.media.back_icon'))
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .margin({left: 38})
            .onClick(() => {
              router.back();
            })

          Text('意见反馈')
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
            // 2. 问题分类
            Text('问题分类')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width('100%')
              .margin({ top: 24, bottom: 16 })

            Row({ space: 12 }) {
              ForEach(this.categories, (item: string) => {
                Text(item)
                  .fontSize(14)
                  .fontColor(this.selectedCategory === item ? '#0A0F1A' : '#DDFFFFFF')
                  .backgroundColor(this.selectedCategory === item ? '#52FFA1' : '#1A2030')
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .borderRadius(16)
                  .onClick(() => {
                    this.selectedCategory = item;
                  })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)

            // 3. 反馈内容输入框
            Text('反馈内容')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width('100%')
              .margin({ top: 32, bottom: 16 })

            TextArea({ placeholder: '请详细描述您遇到的问题，以便我们更好地为您解决...' })
              .width('100%')
              .height(180)
              .backgroundColor('#111622')
              .fontColor('#FFFFFF')
              .placeholderColor('#5E6678')
              .fontSize(15)
              .borderRadius(12)
              .border({ width: 0.5, color: '#1DFFFFFF' })
              .padding(16)
              .onChange((value: string) => {
                this.feedbackContent = value;
              })

            // 4. 提交按钮
            Button('提交反馈')
              .width('100%')
              .height(50)
              .backgroundColor(this.feedbackContent.length > 0 ? '#52FFA1' : '#2A3040')
              .fontColor(this.feedbackContent.length > 0 ? '#0A0F1A' : '#5E6678')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(25)
              .margin({ top: 40 })
              .onClick(() => {
                if (this.feedbackContent.length > 0) {
                  // 这里处理提交逻辑
                  router.back();
                }
              })
          }
          .width('88%')
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%').height('100%')
  }
}