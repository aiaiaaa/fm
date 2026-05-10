import { PlayerPage } from './PlayerPage';
import { ProfilePage } from './ProfilePage';

/**
 * 应用入口 —— 底部 Tabs 容器
 * Tab 1: 电台（PlayerPage）
 * Tab 2: 个人（ProfilePage）
 *
 * 底部 TabBar 按截图实现：
 *   - 左：雷达/圆点图标 + "电台"（激活时绿色）
 *   - 右：人物轮廓图标 + "个人"
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
        .border({ width: 1.5, color: active ? '#2EE89D' : '#FFFFFF77' })
      Column().width(10).height(10).borderRadius(5)
        .border({ width: 1.5, color: active ? '#2EE89D' : '#FFFFFF77' })
      Column().width(4).height(4).borderRadius(2)
        .backgroundColor(active ? '#2EE89D' : '#FFFFFF77')
    }
    .width(22).height(22)
    .alignContent(Alignment.Center)
  }

  @Builder
  PersonIcon(active: boolean) {
    Column() {
      // 头
      Column().width(9).height(9).borderRadius(5)
        .border({ width: 1.4, color: active ? '#2EE89D' : '#FFFFFF77' })
      // 身
      Column().width(16).height(9)
        .borderRadius({ topLeft: 8, topRight: 8, bottomLeft: 0, bottomRight: 0 })
        .border({ width: 1.4, color: active ? '#2EE89D' : '#FFFFFF77' })
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
        .fontColor(this.currentIndex === index ? '#2EE89D' : '#FFFFFF88')
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

  @Builder
  BottomTabBar() {
    Row() {
      this.TabBarItem(0, '电台')
      this.TabBarItem(1, '个人')
    }
    .width('100%')
    .height(68)
    .backgroundColor('#0A0E27EE')
    .border({ width: { top: 0.5 }, color: '#FFFFFF12' })
    .backdropBlur(20)
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
      .barHeight(0)
      .animationDuration(220)
      .layoutWeight(1)
      .onChange((idx: number) => {
        this.currentIndex = idx;
      })

      this.BottomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#070B1D')
  }
}
