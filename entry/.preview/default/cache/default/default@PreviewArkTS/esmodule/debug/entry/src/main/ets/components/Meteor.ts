if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Meteor_Params {
    startLeft?: number;
    delay?: number;
    duration?: number;
    cycle?: number;
    color?: string;
    translateX?: number;
    translateY?: number;
    meteorOpacity?: number;
    timer?: number;
}
export class Meteor extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__startLeft = new SynchedPropertySimpleOneWayPU(params.startLeft, this, "startLeft");
        this.__delay = new SynchedPropertySimpleOneWayPU(params.delay, this, "delay");
        this.__duration = new SynchedPropertySimpleOneWayPU(params.duration, this, "duration");
        this.__cycle = new SynchedPropertySimpleOneWayPU(params.cycle, this, "cycle");
        this.__color = new SynchedPropertySimpleOneWayPU(params.color, this, "color");
        this.__translateX = new ObservedPropertySimplePU(0, this, "translateX");
        this.__translateY = new ObservedPropertySimplePU(0, this, "translateY");
        this.__meteorOpacity = new ObservedPropertySimplePU(0, this, "meteorOpacity");
        this.timer = -1;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Meteor_Params) {
        if (params.startLeft === undefined) {
            this.__startLeft.set(60);
        }
        if (params.delay === undefined) {
            this.__delay.set(0);
        }
        if (params.duration === undefined) {
            this.__duration.set(2200);
        }
        if (params.cycle === undefined) {
            this.__cycle.set(6000);
        }
        if (params.color === undefined) {
            this.__color.set('#2EE89D');
        }
        if (params.translateX !== undefined) {
            this.translateX = params.translateX;
        }
        if (params.translateY !== undefined) {
            this.translateY = params.translateY;
        }
        if (params.meteorOpacity !== undefined) {
            this.meteorOpacity = params.meteorOpacity;
        }
        if (params.timer !== undefined) {
            this.timer = params.timer;
        }
    }
    updateStateVars(params: Meteor_Params) {
        this.__startLeft.reset(params.startLeft);
        this.__delay.reset(params.delay);
        this.__duration.reset(params.duration);
        this.__cycle.reset(params.cycle);
        this.__color.reset(params.color);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__startLeft.purgeDependencyOnElmtId(rmElmtId);
        this.__delay.purgeDependencyOnElmtId(rmElmtId);
        this.__duration.purgeDependencyOnElmtId(rmElmtId);
        this.__cycle.purgeDependencyOnElmtId(rmElmtId);
        this.__color.purgeDependencyOnElmtId(rmElmtId);
        this.__translateX.purgeDependencyOnElmtId(rmElmtId);
        this.__translateY.purgeDependencyOnElmtId(rmElmtId);
        this.__meteorOpacity.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__startLeft.aboutToBeDeleted();
        this.__delay.aboutToBeDeleted();
        this.__duration.aboutToBeDeleted();
        this.__cycle.aboutToBeDeleted();
        this.__color.aboutToBeDeleted();
        this.__translateX.aboutToBeDeleted();
        this.__translateY.aboutToBeDeleted();
        this.__meteorOpacity.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __startLeft: SynchedPropertySimpleOneWayPU<number>; // 起点横坐标百分比
    get startLeft() {
        return this.__startLeft.get();
    }
    set startLeft(newValue: number) {
        this.__startLeft.set(newValue);
    }
    private __delay: SynchedPropertySimpleOneWayPU<number>; // 启动延迟（毫秒）
    get delay() {
        return this.__delay.get();
    }
    set delay(newValue: number) {
        this.__delay.set(newValue);
    }
    private __duration: SynchedPropertySimpleOneWayPU<number>; // 单次划过时长
    get duration() {
        return this.__duration.get();
    }
    set duration(newValue: number) {
        this.__duration.set(newValue);
    }
    private __cycle: SynchedPropertySimpleOneWayPU<number>; // 下次出现的周期
    get cycle() {
        return this.__cycle.get();
    }
    set cycle(newValue: number) {
        this.__cycle.set(newValue);
    }
    private __color: SynchedPropertySimpleOneWayPU<string>;
    get color() {
        return this.__color.get();
    }
    set color(newValue: string) {
        this.__color.set(newValue);
    }
    private __translateX: ObservedPropertySimplePU<number>;
    get translateX() {
        return this.__translateX.get();
    }
    set translateX(newValue: number) {
        this.__translateX.set(newValue);
    }
    private __translateY: ObservedPropertySimplePU<number>;
    get translateY() {
        return this.__translateY.get();
    }
    set translateY(newValue: number) {
        this.__translateY.set(newValue);
    }
    private __meteorOpacity: ObservedPropertySimplePU<number>;
    get meteorOpacity() {
        return this.__meteorOpacity.get();
    }
    set meteorOpacity(newValue: number) {
        this.__meteorOpacity.set(newValue);
    }
    private timer: number;
    aboutToAppear(): void {
        // 延迟启动，避免所有流星同步
        setTimeout(() => {
            this.runOnce();
            this.timer = setInterval(() => this.runOnce(), this.cycle);
        }, this.delay);
    }
    aboutToDisappear(): void {
        if (this.timer >= 0) {
            clearInterval(this.timer);
        }
    }
    private runOnce(): void {
        // 瞬间回到起点
        this.translateX = 0;
        this.translateY = 0;
        this.meteorOpacity = 0;
        Context.animateTo({
            duration: 150,
            curve: Curve.EaseOut
        }, () => {
            this.meteorOpacity = 1;
        });
        Context.animateTo({
            duration: this.duration,
            curve: Curve.EaseIn,
            onFinish: () => {
                this.meteorOpacity = 0;
            }
        }, () => {
            this.translateX = -220;
            this.translateY = 320;
        });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 光尾：一条带渐变的细线，旋转 -30 度
            Stack.create();
            Stack.debugLine("entry/src/main/ets/components/Meteor.ets(60:5)", "entry");
            // 光尾：一条带渐变的细线，旋转 -30 度
            Stack.rotate({ angle: -30 });
            // 光尾：一条带渐变的细线，旋转 -30 度
            Stack.position({ x: `${this.startLeft}%`, y: '-5%' });
            // 光尾：一条带渐变的细线，旋转 -30 度
            Stack.translate({ x: this.translateX, y: this.translateY });
            // 光尾：一条带渐变的细线，旋转 -30 度
            Stack.opacity(this.meteorOpacity);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/components/Meteor.ets(61:7)", "entry");
            Column.width(90);
            Column.height(1.5);
            Column.borderRadius(1);
            Column.linearGradient({
                angle: 90,
                colors: [
                    ['#00000000', 0],
                    [this.color, 0.6],
                    ['#FFFFFFFF', 1]
                ]
            });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 头部亮点
            Column.create();
            Column.debugLine("entry/src/main/ets/components/Meteor.ets(75:7)", "entry");
            // 头部亮点
            Column.width(4);
            // 头部亮点
            Column.height(4);
            // 头部亮点
            Column.borderRadius(2);
            // 头部亮点
            Column.backgroundColor('#FFFFFF');
            // 头部亮点
            Column.shadow({ radius: 6, color: this.color, offsetX: 0, offsetY: 0 });
            // 头部亮点
            Column.position({ x: 86, y: -1 });
        }, Column);
        // 头部亮点
        Column.pop();
        // 光尾：一条带渐变的细线，旋转 -30 度
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
