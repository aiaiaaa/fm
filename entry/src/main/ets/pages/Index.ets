import { PlayerPage } from './PlayerPage';
import { ProfilePage } from './ProfilePage';

/**
 * 应用入口 —— 底部悬浮胶囊 Tabs
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  @Builder
  RadioIcon(active: boolean) {
    Stack() {
      Column().width(20).height(20).borderRadius(10)
        .border({ width: 1.5, color: active ? '#52FFA1' : '#5E6678' })
      Column().width(10).height(10).borderRadius(5)
        .border({ width: 1.5, color: active ? '#52FFA1' : '#5E6678' })
      Column().width(4).height(4).borderRadius(2)
        .backgroundColor(active ? '#52FFA1' : '#5E6678')
    }
    .width(22).height(22)
    .alignContent(Alignment.Center)
  }

  @Builder
  PersonIcon(active: boolean) {
    Column() {
      Column().width(9).height(9).borderRadius(5)
        .border({ width: 1.4, color: active ? '#52FFA1' : '#5E6678' })
      Column().width(16).height(9)
        .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 0, bottomRight: 0 })
        .border({ width: 1.4, color: active ? '#52FFA1' : '#5E6678' })
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
        .fontColor(this.currentIndex === index ? '#52FFA1' : '#5E6678')
        .margin({ top: 4 })
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
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
      .animationDuration(220)
      .width('100%')
      .height('100%')
      .onChange((idx: number) => {
        this.currentIndex = idx;
      })

      // 悬浮胶囊 TabBar
      Row() {
        this.TabBarItem(0, '电台')
        this.TabBarItem(1, '个人')
      }
      .width('85%')
      .height(56)
      .borderRadius(30)
      .backgroundColor('#111622')
      .border({ width: 1, color: '#FFFFFF0D' })
      .shadow({ radius: 20, color: '#00000066', offsetX: 0, offsetY: -4 })
      .margin({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0F1A')
  }
}
