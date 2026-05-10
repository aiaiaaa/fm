if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ProfilePage_Params {
    autoPlay?: boolean;
    sleepTimer?: boolean;
    darkMode?: boolean;
}
export class ProfilePage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__autoPlay = new ObservedPropertySimplePU(true, this, "autoPlay");
        this.__sleepTimer = new ObservedPropertySimplePU(false, this, "sleepTimer");
        this.__darkMode = new ObservedPropertySimplePU(true, this, "darkMode");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ProfilePage_Params) {
        if (params.autoPlay !== undefined) {
            this.autoPlay = params.autoPlay;
        }
        if (params.sleepTimer !== undefined) {
            this.sleepTimer = params.sleepTimer;
        }
        if (params.darkMode !== undefined) {
            this.darkMode = params.darkMode;
        }
    }
    updateStateVars(params: ProfilePage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__autoPlay.purgeDependencyOnElmtId(rmElmtId);
        this.__sleepTimer.purgeDependencyOnElmtId(rmElmtId);
        this.__darkMode.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__autoPlay.aboutToBeDeleted();
        this.__sleepTimer.aboutToBeDeleted();
        this.__darkMode.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __autoPlay: ObservedPropertySimplePU<boolean>;
    get autoPlay() {
        return this.__autoPlay.get();
    }
    set autoPlay(newValue: boolean) {
        this.__autoPlay.set(newValue);
    }
    private __sleepTimer: ObservedPropertySimplePU<boolean>;
    get sleepTimer() {
        return this.__sleepTimer.get();
    }
    set sleepTimer(newValue: boolean) {
        this.__sleepTimer.set(newValue);
    }
    private __darkMode: ObservedPropertySimplePU<boolean>;
    get darkMode() {
        return this.__darkMode.get();
    }
    set darkMode(newValue: boolean) {
        this.__darkMode.set(newValue);
    }
    SettingRow(icon: string, title: string, value: string, onTap?: () => void, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfilePage.ets(12:5)", "entry");
            Row.width('100%');
            Row.height(54);
            Row.padding({ left: 16, right: 16 });
            Row.onClick(() => {
                if (onTap) {
                    onTap();
                }
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(13:7)", "entry");
            Text.fontSize(20);
            Text.width(36);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(18:7)", "entry");
            Text.fontSize(15);
            Text.fontColor('#FFFFFF');
            Text.layoutWeight(1);
            Text.margin({ left: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(24:7)", "entry");
            Text.fontSize(13);
            Text.fontColor('#FFFFFF66');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('\u203A');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(28:7)", "entry");
            Text.fontSize(22);
            Text.fontColor('#FFFFFF55');
            Text.margin({ left: 8 });
        }, Text);
        Text.pop();
        Row.pop();
    }
    SwitchRow(icon: string, title: string, value: boolean, onChange: (v: boolean) => void, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfilePage.ets(45:5)", "entry");
            Row.width('100%');
            Row.height(54);
            Row.padding({ left: 16, right: 16 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(icon);
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(46:7)", "entry");
            Text.fontSize(20);
            Text.width(36);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(51:7)", "entry");
            Text.fontSize(15);
            Text.fontColor('#FFFFFF');
            Text.layoutWeight(1);
            Text.margin({ left: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Toggle.create({ type: ToggleType.Switch, isOn: value });
            Toggle.debugLine("entry/src/main/ets/pages/ProfilePage.ets(57:7)", "entry");
            Toggle.selectedColor('#2EE89D');
            Toggle.onChange((isOn: boolean) => onChange(isOn));
        }, Toggle);
        Toggle.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/ProfilePage.ets(67:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 背景
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(69:7)", "entry");
            // 背景
            Column.width('100%');
            // 背景
            Column.height('100%');
            // 背景
            Column.linearGradient({
                angle: 180,
                colors: [
                    ['#0A0E27', 0],
                    ['#111636', 0.5],
                    ['#0A0E27', 1]
                ]
            });
        }, Column);
        // 背景
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/ProfilePage.ets(80:7)", "entry");
            Scroll.width('100%');
            Scroll.height('100%');
            Scroll.scrollBar(BarState.Off);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(81:9)", "entry");
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部个人信息卡
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(83:11)", "entry");
            // 顶部个人信息卡
            Column.width('100%');
            // 顶部个人信息卡
            Column.padding({ top: 40, bottom: 30 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 头像
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/ProfilePage.ets(85:13)", "entry");
            // 头像
            Stack.width(80);
            // 头像
            Stack.height(80);
            // 头像
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(86:15)", "entry");
            Column.width(80);
            Column.height(80);
            Column.borderRadius(40);
            Column.linearGradient({
                angle: 135,
                colors: [['#2EE89D', 0], ['#00F2FE', 1]]
            });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('X');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(94:15)", "entry");
            Text.fontSize(34);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#0A0E27');
        }, Text);
        Text.pop();
        // 头像
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('X.FM 听众');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(102:13)", "entry");
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#FFFFFF');
            Text.margin({ top: 14 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('保持专注，也享受睡眠');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(108:13)", "entry");
            Text.fontSize(12);
            Text.fontColor('#FFFFFF66');
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        // 顶部个人信息卡
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 统计卡片
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfilePage.ets(117:11)", "entry");
            // 统计卡片
            Row.width('90%');
            // 统计卡片
            Row.padding({ top: 20, bottom: 20 });
            // 统计卡片
            Row.borderRadius(16);
            // 统计卡片
            Row.backgroundColor('#FFFFFF08');
            // 统计卡片
            Row.border({ width: 1, color: '#FFFFFF12' });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const item = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(123:15)", "entry");
                    Column.layoutWeight(1);
                    Column.alignItems(HorizontalAlign.Center);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(item.value);
                    Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(124:17)", "entry");
                    Text.fontSize(20);
                    Text.fontWeight(FontWeight.Bold);
                    Text.fontColor('#2EE89D');
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(item.label);
                    Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(128:17)", "entry");
                    Text.fontSize(11);
                    Text.fontColor('#FFFFFF88');
                    Text.margin({ top: 4 });
                }, Text);
                Text.pop();
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, [
                { label: '收听时长', value: '0h' },
                { label: '收藏频道', value: '0' },
                { label: '专注天数', value: '0' }
            ], forEachItemGenFunction);
        }, ForEach);
        ForEach.pop();
        // 统计卡片
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 设置分组
            Text.create('播放');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(144:11)", "entry");
            // 设置分组
            Text.fontSize(12);
            // 设置分组
            Text.fontColor('#FFFFFF55');
            // 设置分组
            Text.letterSpacing(2);
            // 设置分组
            Text.margin({ top: 28, left: 24, bottom: 10 });
            // 设置分组
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        // 设置分组
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(151:11)", "entry");
            Column.width('90%');
            Column.borderRadius(16);
            Column.backgroundColor('#FFFFFF08');
            Column.border({ width: 1, color: '#FFFFFF12' });
            Column.clip(true);
        }, Column);
        this.SwitchRow.bind(this)('\u25B6', '启动自动续播', this.autoPlay, (v) => this.autoPlay = v);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfilePage.ets(153:13)", "entry");
            Divider.color('#FFFFFF10');
            Divider.margin({ left: 60, right: 16 });
        }, Divider);
        this.SwitchRow.bind(this)('\u231A', '定时关闭', this.sleepTimer, (v) => this.sleepTimer = v);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfilePage.ets(155:13)", "entry");
            Divider.color('#FFFFFF10');
            Divider.margin({ left: 60, right: 16 });
        }, Divider);
        this.SettingRow.bind(this)('\u266B', '音质', '标准', () => { });
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('外观');
            Text.debugLine("entry/src/main/ets/pages/ProfilePage.ets(164:11)", "entry");
            Text.fontSize(12);
            Text.fontColor('#FFFFFF55');
            Text.letterSpacing(2);
            Text.margin({ top: 20, left: 24, bottom: 10 });
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ProfilePage.ets(171:11)", "entry");
            Column.width('90%');
            Column.borderRadius(16);
            Column.backgroundColor('#FFFFFF08');
            Column.border({ width: 1, color: '#FFFFFF12' });
            Column.clip(true);
        }, Column);
        this.SwitchRow.bind(this)('\u263D', '深色主题', this.darkMode, (v) => this.darkMode = v);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfilePage.ets(173:13)", "entry");
            Divider.color('#FFFFFF10');
            Divider.margin({ left: 60, right: 16 });
        }, Divider);
        this.SettingRow.bind(this)('\u2699', '关于 X.FM', 'v1.0.0', () => { });
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/ProfilePage.ets(182:11)", "entry");
            Blank.height(60);
        }, Blank);
        Blank.pop();
        Column.pop();
        Scroll.pop();
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
