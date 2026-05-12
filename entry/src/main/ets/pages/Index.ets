import { PlayerPage } from './PlayerPage';
import { ProfilePage } from './ProfilePage';

/**
 * 应用入口 —— 底部悬浮胶囊 Tabs
 * 切换动效：淡白色光影滑块跟随当前 tab 滑动，icon/text 颜色平滑过渡
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State sliderLeft: number = 0;      // 0=左, 1=右
  private tabsController: TabsController = new TabsController();

  @Builder
  RadioIcon(active: boolean) {
    Stack() {
      Column().width(20).height(20).borderRadius(10)
        .border({ width: 1.5, color: active ? '#FFFFFF' : '#5E6678' })
        .animation({ duration: 280, curve: Curve.EaseInOut })
      Column().width(10).height(10).borderRadius(5)
        .border({ width: 1.5, color: active ? '#FFFFFF' : '#5E6678' })
        .animation({ duration: 280, curve: Curve.EaseInOut })
      Column().width(4).height(4).borderRadius(2)
        .backgroundColor(active ? '#FFFFFF' : '#5E6678')
        .animation({ duration: 280, curve: Curve.EaseInOut })
    }
    .width(22).height(22)
    .alignContent(Alignment.Center)
  }

  @Builder
  PersonIcon(active: boolean) {
    Column() {
      Column().width(9).height(9).borderRadius(5)
        .border({ width: 1.4, color: active ? '#FFFFFF' : '#5E6678' })
        .animation({ duration: 280, curve: Curve.EaseInOut })
      Column().width(16).height(9)
        .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 0, bottomRight: 0 })
        .border({ width: 1.4, color: active ? '#FFFFFF' : '#5E6678' })
        .animation({ duration: 280, curve: Curve.EaseInOut })
        .margin({ top: 2 })
    }
    .width(22).height(22)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabBarItem(index: number, label: string) {
    Column() {
      if (index === 0) {
        this.RadioIcon(this.currentIndex === index);
      } else {
        this.PersonIcon(this.currentIndex === index);
      }
      Text(label)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? '#FFFFFF' : '#5E6678')
        .margin({ top: 4 })
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .animation({ duration: 280, curve: Curve.EaseInOut })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .focusable(false)
    .onClick(() => {
      animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
        this.currentIndex = index;
        this.sliderLeft = index;
      });
      this.tabsController.changeIndex(index);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex }) {
        TabContent() {
          PlayerPage()
        }
        TabContent() {
          ProfilePage()
        }
      }
      .barHeight(0)
      .animationDuration(280)
      .width('100%')
      .height('100%')
      .focusable(false)
      .onChange((idx: number) => {
        animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
          this.currentIndex = idx;
          this.sliderLeft = idx;
        });
      })

      // 悬浮胶囊 TabBar
      Stack() {
        // 淡白色光影滑块
        Column()
          .width('48%')
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FFFFFF10')
          .position({ x: this.sliderLeft === 0 ? '2%' : '50%', y: 6 })
          .animation({ duration: 280, curve: Curve.EaseInOut })

        // Tab items
        Row() {
          this.TabBarItem(0, '电台')
          this.TabBarItem(1, '个人')
        }
        .width('100%')
        .height('100%')
      }
      .width('85%')
      .height(56)
      .borderRadius(30)
      .backgroundColor('#111622')
      .shadow({ radius: 20, color: '#00000066', offsetX: 0, offsetY: -4 })
      .margin({ bottom: 24 })
      .clip(true)
      .focusable(false)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
    .focusable(false)
  }
}
