if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    currentIndex?: number;
    tabsController?: TabsController;
}
import { PlayerPage } from "@bundle:com.xfm.harmony/entry/ets/pages/PlayerPage";
import { ProfilePage } from "@bundle:com.xfm.harmony/entry/ets/pages/ProfilePage";
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__currentIndex = new ObservedPropertySimplePU(0, this, "currentIndex");
        this.tabsController = new TabsController();
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.currentIndex !== undefined) {
            this.currentIndex = params.currentIndex;
        }
        if (params.tabsController !== undefined) {
            this.tabsController = params.tabsController;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__currentIndex.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __currentIndex: ObservedPropertySimplePU<number>;
    get currentIndex() {
        return this.__currentIndex.get();
    }
    set currentIndex(newValue: number) {
        this.__currentIndex.set(newValue);
    }
    private tabsController: TabsController;
    TabBarItem(icon: string, label: string, index: number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(17:5)", "entry");
            Column.layoutWeight(1);
            Column.height('100%');
            Column.justifyContent(FlexAlign.Center);
            Column.alignItems(HorizontalAlign.Center);
            Column.onClick(() => {
                this.currentIndex = index;
                this.tabsController.changeIndex(index);
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.debugLine("entry/src/main/ets/pages/Index.ets(18:7)", "entry");
            Text.fontSize(22);
            Text.fontColor(this.currentIndex === index ? '#2EE89D' : '#FFFFFF66');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/Index.ets(22:7)", "entry");
            Text.fontSize(10);
            Text.fontColor(this.currentIndex === index ? '#2EE89D' : '#FFFFFF66');
            Text.margin({ top: 4 });
            Text.fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Regular);
        }, Text);
        Text.pop();
        Column.pop();
    }
    BottomTabBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(40:5)", "entry");
            Row.width('100%');
            Row.height(64);
            Row.backgroundColor('#0A0E27EE');
            Row.border({ width: { top: 0.5 }, color: '#FFFFFF12' });
        }, Row);
        this.TabBarItem.bind(this)('\uD83C\uDFB5', '电台', 0);
        this.TabBarItem.bind(this)('\uD83D\uDC64', '个人', 1);
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(51:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor('#0A0E27');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Tabs.create({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex });
            Tabs.debugLine("entry/src/main/ets/pages/Index.ets(52:7)", "entry");
            Tabs.barHeight(0);
            Tabs.animationDuration(200);
            Tabs.layoutWeight(1);
            Tabs.onChange((idx: number) => {
                this.currentIndex = idx;
            });
        }, Tabs);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new PlayerPage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 54, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "PlayerPage" });
                }
            });
            TabContent.debugLine("entry/src/main/ets/pages/Index.ets(53:9)", "entry");
        }, TabContent);
        TabContent.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TabContent.create(() => {
                {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        if (isInitialRender) {
                            let componentCall = new ProfilePage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 58, col: 11 });
                            ViewPU.create(componentCall);
                            let paramsLambda = () => {
                                return {};
                            };
                            componentCall.paramsGenerator_ = paramsLambda;
                        }
                        else {
                            this.updateStateVarsOfChildByElmtId(elmtId, {});
                        }
                    }, { name: "ProfilePage" });
                }
            });
            TabContent.debugLine("entry/src/main/ets/pages/Index.ets(57:9)", "entry");
        }, TabContent);
        TabContent.pop();
        Tabs.pop();
        this.BottomTabBar.bind(this)();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.xfm.harmony", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
