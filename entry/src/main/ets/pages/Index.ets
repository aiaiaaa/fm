import { PlayerPage } from './PlayerPage';
import { ProfilePage } from './ProfilePage';

/**
 * 应用入口 —— 底部 Tabs 容器
 * Tab 1: 电台（PlayerPage）
 * Tab 2: 个人（ProfilePage）
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  @Builder
  TabBarItem(icon: string, label: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(22)
        .fontColor(this.currentIndex === index ? '#2EE89D' : '#FFFFFF66')

      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? '#2EE89D' : '#FFFFFF66')
        .margin({ top: 4 })
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
      this.tabsController.changeIndex(index);
    })
  }

  @Builder
  BottomTabBar() {
    Row() {
      this.TabBarItem('\uD83C\uDFB5', '电台', 0)
      this.TabBarItem('\uD83D\uDC64', '个人', 1)
    }
    .width('100%')
    .height(64)
    .backgroundColor('#0A0E27EE')
    .border({ width: { top: 0.5 }, color: '#FFFFFF12' })
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex }) {
        TabContent() {
          PlayerPage()
        }

        TabContent() {
          ProfilePage()
        }
      }
      .barHeight(0)              // 隐藏默认 tabbar，用自定义的
      .animationDuration(200)
      .layoutWeight(1)
      .onChange((idx: number) => {
        this.currentIndex = idx;
      })

      this.BottomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0E27')
  }
}
