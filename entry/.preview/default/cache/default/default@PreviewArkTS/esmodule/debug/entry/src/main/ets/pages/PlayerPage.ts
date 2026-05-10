if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface PlayerPage_Params {
    isPlaying?: boolean;
    isLoading?: boolean;
    mode?: ModeId;
    lang?: 'cn' | 'en';
    statusBarHeight?: number;
    dotScales?: number[];
    rhythmTimer?: number;
    logoBars?: number[];
    logoTimer?: number;
    glowScale?: number;
    glowOpacity?: number;
    stars?: StarDot[];
    player?: RadioPlayer;
    wavePhase?: number;
}
import window from "@ohos:window";
import promptAction from "@ohos:promptAction";
import type common from "@ohos:app.ability.common";
import { RadioPlayer } from "@bundle:com.xfm.harmony/entry/ets/services/RadioPlayer";
import type { PlayerState } from "@bundle:com.xfm.harmony/entry/ets/services/RadioPlayer";
import { BackgroundTask } from "@bundle:com.xfm.harmony/entry/ets/services/BackgroundTask";
import { MODES } from "@bundle:com.xfm.harmony/entry/ets/model/Modes";
import type { ModeId, ModeConfig } from "@bundle:com.xfm.harmony/entry/ets/model/Modes";
import { Meteor } from "@bundle:com.xfm.harmony/entry/ets/components/Meteor";
interface StarDot {
    x: number;
    y: number;
    size: number;
    opacity: number;
}
export class PlayerPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__isPlaying = new ObservedPropertySimplePU(false, this, "isPlaying");
        this.__isLoading = new ObservedPropertySimplePU(false, this, "isLoading");
        this.__mode = new ObservedPropertySimplePU('focus', this, "mode");
        this.__lang = new ObservedPropertySimplePU('cn', this, "lang");
        this.__statusBarHeight = new ObservedPropertySimplePU(40, this, "statusBarHeight");
        this.__dotScales = new ObservedPropertyObjectPU(new Array(23).fill(0.4), this, "dotScales");
        this.rhythmTimer = -1;
        this.__logoBars = new ObservedPropertyObjectPU([10, 16, 8, 13], this, "logoBars");
        this.logoTimer = -1;
        this.__glowScale = new ObservedPropertySimplePU(1.0, this, "glowScale");
        this.__glowOpacity = new ObservedPropertySimplePU(0.35, this, "glowOpacity");
        this.stars = [];
        this.player = new RadioPlayer();
        this.wavePhase = 0;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: PlayerPage_Params) {
        if (params.isPlaying !== undefined) {
            this.isPlaying = params.isPlaying;
        }
        if (params.isLoading !== undefined) {
            this.isLoading = params.isLoading;
        }
        if (params.mode !== undefined) {
            this.mode = params.mode;
        }
        if (params.lang !== undefined) {
            this.lang = params.lang;
        }
        if (params.statusBarHeight !== undefined) {
            this.statusBarHeight = params.statusBarHeight;
        }
        if (params.dotScales !== undefined) {
            this.dotScales = params.dotScales;
        }
        if (params.rhythmTimer !== undefined) {
            this.rhythmTimer = params.rhythmTimer;
        }
        if (params.logoBars !== undefined) {
            this.logoBars = params.logoBars;
        }
        if (params.logoTimer !== undefined) {
            this.logoTimer = params.logoTimer;
        }
        if (params.glowScale !== undefined) {
            this.glowScale = params.glowScale;
        }
        if (params.glowOpacity !== undefined) {
            this.glowOpacity = params.glowOpacity;
        }
        if (params.stars !== undefined) {
            this.stars = params.stars;
        }
        if (params.player !== undefined) {
            this.player = params.player;
        }
        if (params.wavePhase !== undefined) {
            this.wavePhase = params.wavePhase;
        }
    }
    updateStateVars(params: PlayerPage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__isPlaying.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
        this.__mode.purgeDependencyOnElmtId(rmElmtId);
        this.__lang.purgeDependencyOnElmtId(rmElmtId);
        this.__statusBarHeight.purgeDependencyOnElmtId(rmElmtId);
        this.__dotScales.purgeDependencyOnElmtId(rmElmtId);
        this.__logoBars.purgeDependencyOnElmtId(rmElmtId);
        this.__glowScale.purgeDependencyOnElmtId(rmElmtId);
        this.__glowOpacity.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__isPlaying.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
        this.__mode.aboutToBeDeleted();
        this.__lang.aboutToBeDeleted();
        this.__statusBarHeight.aboutToBeDeleted();
        this.__dotScales.aboutToBeDeleted();
        this.__logoBars.aboutToBeDeleted();
        this.__glowScale.aboutToBeDeleted();
        this.__glowOpacity.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __isPlaying: ObservedPropertySimplePU<boolean>;
    get isPlaying() {
        return this.__isPlaying.get();
    }
    set isPlaying(newValue: boolean) {
        this.__isPlaying.set(newValue);
    }
    private __isLoading: ObservedPropertySimplePU<boolean>;
    get isLoading() {
        return this.__isLoading.get();
    }
    set isLoading(newValue: boolean) {
        this.__isLoading.set(newValue);
    }
    private __mode: ObservedPropertySimplePU<ModeId>;
    get mode() {
        return this.__mode.get();
    }
    set mode(newValue: ModeId) {
        this.__mode.set(newValue);
    }
    private __lang: ObservedPropertySimplePU<'cn' | 'en'>;
    get lang() {
        return this.__lang.get();
    }
    set lang(newValue: 'cn' | 'en') {
        this.__lang.set(newValue);
    }
    private __statusBarHeight: ObservedPropertySimplePU<number>;
    get statusBarHeight() {
        return this.__statusBarHeight.get();
    }
    set statusBarHeight(newValue: number) {
        this.__statusBarHeight.set(newValue);
    }
    // 点阵音波 —— 按截图：一排 23 颗圆点，中间高两头低
    private __dotScales: ObservedPropertyObjectPU<number[]>;
    get dotScales() {
        return this.__dotScales.get();
    }
    set dotScales(newValue: number[]) {
        this.__dotScales.set(newValue);
    }
    private rhythmTimer: number;
    // logo 4 根柱子
    private __logoBars: ObservedPropertyObjectPU<number[]>;
    get logoBars() {
        return this.__logoBars.get();
    }
    set logoBars(newValue: number[]) {
        this.__logoBars.set(newValue);
    }
    private logoTimer: number;
    // 播放按钮外圈光晕呼吸
    private __glowScale: ObservedPropertySimplePU<number>;
    get glowScale() {
        return this.__glowScale.get();
    }
    set glowScale(newValue: number) {
        this.__glowScale.set(newValue);
    }
    private __glowOpacity: ObservedPropertySimplePU<number>;
    get glowOpacity() {
        return this.__glowOpacity.get();
    }
    set glowOpacity(newValue: number) {
        this.__glowOpacity.set(newValue);
    }
    // 星空
    private stars: StarDot[];
    private player: RadioPlayer;
    aboutToAppear(): void {
        // 状态栏避让高度
        window.getLastWindow(getContext(this)).then(win => {
            const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
            this.statusBarHeight = px2vp(area.topRect.height);
        }).catch(() => {
            this.statusBarHeight = 40;
        });
        // 生成星空
        const list: StarDot[] = [];
        for (let i = 0; i < 60; i++) {
            list.push({
                x: Math.random() * 100,
                y: Math.random() * 100,
                size: Math.random() < 0.15 ? 2.5 : 1.5,
                opacity: 0.25 + Math.random() * 0.55
            });
        }
        this.stars = list;
        // 初始化播放器 + AVSession + 后台任务
        const context = getContext(this) as common.UIAbilityContext;
        this.player.init(context, {
            onStateChange: (s: PlayerState) => {
                switch (s) {
                    case 'loading':
                        this.isLoading = true;
                        break;
                    case 'playing':
                        this.isLoading = false;
                        this.isPlaying = true;
                        this.startRhythm();
                        BackgroundTask.start(context);
                        break;
                    case 'paused':
                    case 'idle':
                        this.isPlaying = false;
                        this.isLoading = false;
                        this.stopRhythm();
                        break;
                    case 'error':
                        this.isPlaying = false;
                        this.isLoading = false;
                        this.stopRhythm();
                        break;
                    default:
                        break;
                }
            },
            onError: (msg: string) => {
                promptAction.showToast({ message: `播放失败: ${msg}`, duration: 2500 });
            }
        });
        this.startLogoAnim();
        this.startGlowAnim();
    }
    aboutToDisappear(): void {
        this.stopRhythm();
        if (this.logoTimer >= 0) {
            clearInterval(this.logoTimer);
        }
        const context = getContext(this) as common.UIAbilityContext;
        BackgroundTask.stop(context);
        this.player.release();
    }
    /* ============ 动画 ============ */
    private startLogoAnim(): void {
        this.logoTimer = setInterval(() => {
            Context.animateTo({ duration: 420, curve: Curve.EaseInOut }, () => {
                this.logoBars = [
                    6 + Math.random() * 10,
                    8 + Math.random() * 14,
                    6 + Math.random() * 10,
                    7 + Math.random() * 12
                ];
            });
        }, 450);
    }
    private startGlowAnim(): void {
        Context.animateTo({
            duration: 1800,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate
        }, () => {
            this.glowScale = 1.18;
            this.glowOpacity = 0.55;
        });
    }
    private wavePhase: number;
    private startRhythm(): void {
        if (this.rhythmTimer >= 0) {
            return;
        }
        // 缩短刷新间隔，提升流畅度（150ms约等于 6~7 fps 的关键帧变换，配合 animateTo 形成丝滑过渡）
        this.rhythmTimer = setInterval(() => {
            // 每次刷新推进相位
            this.wavePhase += 0.4;
            Context.animateTo({ duration: 150, curve: Curve.Linear }, () => {
                const arr: number[] = [];
                const TOTAL_DOTS = 23;
                const CENTER = Math.floor(TOTAL_DOTS / 2); // 11
                for (let i = 0; i < TOTAL_DOTS; i++) {
                    // 1. 将索引映射到 -1.0 到 1.0 的范围
                    const x = (i - CENTER) / CENTER;
                    // 2. 高斯包络线 (Gaussian Envelope)：强制波形呈现中间高、两边平滑衰减的形态
                    // Math.exp(-x * x * 3) 中的 3 决定了衰减的陡峭程度
                    const envelope = Math.exp(-x * x * 3);
                    // 3. 复合波动生成：模拟低、中、高频的组合
                    // - 低频 (Low): 控制整体的平缓呼吸
                    const lowFreq = Math.sin(this.wavePhase * 0.8) * 0.3;
                    // - 中频 (Mid): 随索引位置变化的涟漪感
                    const midFreq = Math.sin(this.wavePhase * 1.5 + i * 0.6) * 0.4;
                    // - 高频/节奏 (High): 极小幅度的随机抖动，模拟鼓点
                    const beat = (Math.random() * 0.15 - 0.075);
                    // 4. 合成绝对值，并应用包络线
                    let waveHeight = Math.abs(lowFreq + midFreq + beat) * envelope;
                    // 5. 映射到视觉缩放比例 (基础高度 0.2，最大高度上限通过常数控制)
                    const scaleY = Math.max(0.2, 0.2 + waveHeight * 2.5);
                    arr.push(scaleY);
                }
                this.dotScales = arr;
            });
        }, 150);
    }
    private stopRhythm(): void {
        if (this.rhythmTimer >= 0) {
            clearInterval(this.rhythmTimer);
            this.rhythmTimer = -1;
        }
        // 停止时，平滑回落到一条静止的微小直线
        Context.animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
            this.dotScales = new Array(23).fill(0.15);
        });
    }
    /* ============ 交互 ============ */
    private currentUrl(): string {
        // 专注模式区分中英文，睡眠模式固定
        if (this.mode === 'focus') {
            return this.lang === 'cn'
                ? 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8'
                : 'https://koe.bbg.fm/channels/2/playlist.m3u8';
        }
        return MODES.sleep.url;
    }
    private getCurrentModeConfig(): ModeConfig {
        return this.mode === 'focus' ? MODES.focus : MODES.sleep;
    }
    private modeCfgOf(m: ModeId): ModeConfig {
        if (m === 'focus')
            return MODES.focus;
        return MODES.sleep;
    }
    private async togglePlay(): Promise<void> {
        if (this.isLoading) {
            return;
        }
        if (this.isPlaying) {
            await this.player.pause();
        }
        else {
            const cfg = this.getCurrentModeConfig();
            this.player.setTrack({
                title: `X.FM - ${this.mode === 'focus' ? (this.lang === 'cn' ? '中文' : 'EN') : '睡眠'}`,
                artist: 'X.FM',
                album: cfg.subtitle
            });
            await this.player.load(this.currentUrl());
        }
    }
    private async switchMode(m: ModeId): Promise<void> {
        if (this.mode === m) {
            return;
        }
        this.mode = m;
        if (this.isPlaying || this.isLoading) {
            await this.player.stop();
            await this.player.load(this.currentUrl());
        }
    }
    private async switchLang(l: 'cn' | 'en'): Promise<void> {
        if (this.lang === l) {
            return;
        }
        this.lang = l;
        if (this.isPlaying || this.isLoading) {
            await this.player.stop();
            await this.player.load(this.currentUrl());
        }
    }
    /* ============ UI ============ */
    // 顶部导航
    TopNav(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(256:5)", "entry");
            Row.width('100%');
            Row.height(48);
            Row.padding({ left: 24, right: 24 });
            Row.justifyContent(FlexAlign.Start);
            Row.margin({ top: this.statusBarHeight });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(257:7)", "entry");
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 3 });
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(258:9)", "entry");
            Row.alignItems(VerticalAlign.Center);
            Row.height(22);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const i = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(260:13)", "entry");
                    Column.width(3);
                    Column.height(this.logoBars[i]);
                    Column.borderRadius(2);
                    Column.linearGradient({
                        angle: 180,
                        colors: [[cfg.accent, 0], [cfg.accentSecond, 1]]
                    });
                }, Column);
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, [0, 1, 2, 3], forEachItemGenFunction);
        }, ForEach);
        ForEach.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('X.FM');
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(273:9)", "entry");
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#FFFFFF');
            Text.letterSpacing(1.5);
        }, Text);
        Text.pop();
        Row.pop();
        Row.pop();
    }
    // 星空层
    StarField(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(291:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, idx: number) => {
                const s = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(293:9)", "entry");
                    Column.width(s.size);
                    Column.height(s.size);
                    Column.borderRadius(s.size / 2);
                    Column.backgroundColor('#FFFFFF');
                    Column.opacity(s.opacity);
                    Column.position({ x: `${s.x}%`, y: `${s.y}%` });
                }, Column);
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, this.stars, forEachItemGenFunction, (s: StarDot, idx: number) => `star-${idx}`, true, true);
        }, ForEach);
        ForEach.pop();
        Stack.pop();
    }
    // 流星层 —— 6 条斜向划过
    MeteorField(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(309:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
            Stack.clip(true);
        }, Stack);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 75, delay: 0, duration: 2200, cycle: 7000, color: cfg.accent }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 310, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 75,
                            delay: 0,
                            duration: 2200,
                            cycle: 7000,
                            color: cfg.accent
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 75, delay: 0, duration: 2200, cycle: 7000, color: cfg.accent
                    });
                }
            }, { name: "Meteor" });
        }
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 60, delay: 1400, duration: 2000, cycle: 6500, color: cfg.accent }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 311, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 60,
                            delay: 1400,
                            duration: 2000,
                            cycle: 6500,
                            color: cfg.accent
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 60, delay: 1400, duration: 2000, cycle: 6500, color: cfg.accent
                    });
                }
            }, { name: "Meteor" });
        }
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 85, delay: 2800, duration: 2400, cycle: 7500, color: cfg.accentSecond }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 312, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 85,
                            delay: 2800,
                            duration: 2400,
                            cycle: 7500,
                            color: cfg.accentSecond
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 85, delay: 2800, duration: 2400, cycle: 7500, color: cfg.accentSecond
                    });
                }
            }, { name: "Meteor" });
        }
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 45, delay: 4000, duration: 1800, cycle: 6800, color: cfg.accent }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 313, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 45,
                            delay: 4000,
                            duration: 1800,
                            cycle: 6800,
                            color: cfg.accent
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 45, delay: 4000, duration: 1800, cycle: 6800, color: cfg.accent
                    });
                }
            }, { name: "Meteor" });
        }
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 70, delay: 5200, duration: 2100, cycle: 7200, color: cfg.accentSecond }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 314, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 70,
                            delay: 5200,
                            duration: 2100,
                            cycle: 7200,
                            color: cfg.accentSecond
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 70, delay: 5200, duration: 2100, cycle: 7200, color: cfg.accentSecond
                    });
                }
            }, { name: "Meteor" });
        }
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new Meteor(this, { startLeft: 55, delay: 6400, duration: 1900, cycle: 6600, color: cfg.accent }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/PlayerPage.ets", line: 315, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            startLeft: 55,
                            delay: 6400,
                            duration: 1900,
                            cycle: 6600,
                            color: cfg.accent
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        startLeft: 55, delay: 6400, duration: 1900, cycle: 6600, color: cfg.accent
                    });
                }
            }, { name: "Meteor" });
        }
        Stack.pop();
    }
    // 点阵音波 —— 一排 23 颗圆点
    DotVisualizer(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 6 });
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(325:5)", "entry");
            Row.justifyContent(FlexAlign.Center);
            Row.alignItems(VerticalAlign.Center);
            Row.height(40);
            Row.width('100%');
            Row.margin({ top: 30, bottom: 30 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, idx: number) => {
                const scale = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create();
                    Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(327:9)", "entry");
                    Column.width(6);
                    Column.height(6);
                    Column.borderRadius(3);
                    Column.backgroundColor(cfg.accent);
                    Column.scale({ x: 1, y: scale });
                    Column.opacity(0.6 + scale * 0.4);
                    Column.shadow({
                        radius: this.isPlaying ? 4 : 0,
                        color: cfg.accent,
                        offsetX: 0,
                        offsetY: 0
                    });
                }, Column);
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, this.dotScales, forEachItemGenFunction, (_: number, idx: number) => `dot-${idx}`, true, true);
        }, ForEach);
        ForEach.pop();
        Row.pop();
    }
    // 中心圆形播放按钮（截图样式：大圆绿色光晕）
    PlayButton(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(352:5)", "entry");
            Stack.width(110);
            Stack.height(110);
            Stack.alignContent(Alignment.Center);
            Stack.onClick(() => this.togglePlay());
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 外光晕（呼吸）
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(354:7)", "entry");
            // 外光晕（呼吸）
            Column.width(110);
            // 外光晕（呼吸）
            Column.height(110);
            // 外光晕（呼吸）
            Column.borderRadius(55);
            // 外光晕（呼吸）
            Column.backgroundColor(cfg.accent);
            // 外光晕（呼吸）
            Column.opacity(this.isPlaying ? this.glowOpacity * 0.6 : 0.25);
            // 外光晕（呼吸）
            Column.scale({ x: this.glowScale, y: this.glowScale });
        }, Column);
        // 外光晕（呼吸）
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 主按钮
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(363:7)", "entry");
            // 主按钮
            Stack.width(84);
            // 主按钮
            Stack.height(84);
            // 主按钮
            Stack.borderRadius(42);
            // 主按钮
            Stack.backgroundColor(cfg.accent);
            // 主按钮
            Stack.alignContent(Alignment.Center);
            // 主按钮
            Stack.shadow({ radius: 24, color: cfg.accent, offsetX: 0, offsetY: 0 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isLoading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/PlayerPage.ets(365:11)", "entry");
                        LoadingProgress.width(34);
                        LoadingProgress.height(34);
                        LoadingProgress.color('#0A0E27');
                    }, LoadingProgress);
                });
            }
            else if (this.isPlaying) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(370:11)", "entry");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(371:13)", "entry");
                        Column.width(6);
                        Column.height(26);
                        Column.backgroundColor('#0A0E27');
                        Column.borderRadius(2);
                    }, Column);
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(372:13)", "entry");
                        Column.width(6);
                        Column.height(26);
                        Column.backgroundColor('#0A0E27');
                        Column.borderRadius(2);
                    }, Column);
                    Column.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 播放三角 ▶
                        Polygon.create({ width: 22, height: 24 });
                        Polygon.debugLine("entry/src/main/ets/pages/PlayerPage.ets(376:11)", "entry");
                        // 播放三角 ▶
                        Polygon.points([[0, 0], [22, 12], [0, 24]]);
                        // 播放三角 ▶
                        Polygon.fill('#0A0E27');
                        // 播放三角 ▶
                        Polygon.stroke(Color.Transparent);
                        // 播放三角 ▶
                        Polygon.margin({ left: 4 });
                    }, Polygon);
                });
            }
        }, If);
        If.pop();
        // 主按钮
        Stack.pop();
        Stack.pop();
    }
    // 左右切台箭头
    ArrowButton(direction: 'left' | 'right', parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(399:5)", "entry");
            Stack.width(44);
            Stack.height(44);
            Stack.alignContent(Alignment.Center);
            Stack.onClick(() => {
                // 快速切换中英文（仅 focus 模式有效果）
                if (this.mode === 'focus') {
                    this.switchLang(this.lang === 'cn' ? 'en' : 'cn');
                }
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(direction === 'left' ? '\u2039' : '\u203A');
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(400:7)", "entry");
            Text.fontSize(30);
            Text.fontColor('#FFFFFF55');
            Text.fontWeight(FontWeight.Lighter);
        }, Text);
        Text.pop();
        Stack.pop();
    }
    // 模式切换（专注 / 睡眠）
    ModeSwitch(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(419:5)", "entry");
            Row.padding(3);
            Row.borderRadius(20);
            Row.backgroundColor('#FFFFFF10');
            Row.border({ width: 1, color: '#FFFFFF18' });
            Row.margin({ top: 22 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const m = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(m === 'focus' ? MODES.focus.label : MODES.sleep.label);
                    Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(421:9)", "entry");
                    globalThis.Context.animation({ duration: 250, curve: Curve.EaseOut });
                    Text.fontSize(13);
                    Text.fontColor(this.mode === m ? '#0A0E27' : '#FFFFFFAA');
                    Text.fontWeight(this.mode === m ? FontWeight.Bold : FontWeight.Regular);
                    Text.padding({ left: 18, right: 18, top: 7, bottom: 7 });
                    Text.borderRadius(16);
                    Text.backgroundColor(this.mode === m ? (m === 'focus' ? MODES.focus.accent : MODES.sleep.accent) : '#00000000');
                    globalThis.Context.animation(null);
                    Text.onClick(() => this.switchMode(m));
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, ['focus', 'sleep'] as ModeId[], forEachItemGenFunction);
        }, ForEach);
        ForEach.pop();
        Row.pop();
    }
    // 卡片头部标签
    CardHeader(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(442:5)", "entry");
            Row.width('100%');
            Row.padding({ left: 22, right: 18, top: 22 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(443:7)", "entry");
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 绿色呼吸点
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(445:9)", "entry");
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(446:11)", "entry");
            Column.width(8);
            Column.height(8);
            Column.borderRadius(4);
            Column.backgroundColor(cfg.accent);
            Column.shadow({ radius: 8, color: cfg.accent, offsetX: 0, offsetY: 0 });
        }, Column);
        Column.pop();
        // 绿色呼吸点
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(cfg.tag);
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(452:9)", "entry");
            Text.fontSize(12);
            Text.fontColor(cfg.accent);
            Text.fontWeight(FontWeight.Medium);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/PlayerPage.ets(459:7)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 右侧 LIVE 胶囊
            Row.create({ space: 6 });
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(462:7)", "entry");
            // 右侧 LIVE 胶囊
            Row.alignItems(VerticalAlign.Center);
            // 右侧 LIVE 胶囊
            Row.padding({ left: 10, right: 10, top: 4, bottom: 4 });
            // 右侧 LIVE 胶囊
            Row.borderRadius(12);
            // 右侧 LIVE 胶囊
            Row.backgroundColor('#FFFFFF10');
            // 右侧 LIVE 胶囊
            Row.border({ width: 1, color: '#FFFFFF18' });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(463:9)", "entry");
            Column.width(6);
            Column.height(6);
            Column.borderRadius(3);
            Column.backgroundColor(this.isPlaying ? '#FF5353' : '#888888');
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('LIVE');
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(467:9)", "entry");
            Text.fontSize(11);
            Text.fontColor('#FFFFFFAA');
            Text.letterSpacing(1);
        }, Text);
        Text.pop();
        // 右侧 LIVE 胶囊
        Row.pop();
        Row.pop();
    }
    // 主播放卡片
    // 主播放卡片 (增加毛玻璃质感)
    PlayerCard(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(486:5)", "entry");
            Stack.width('100%');
            Stack.aspectRatio(0.78);
            Stack.borderRadius(28);
            Stack.clip(true);
            Stack.shadow({ radius: 30, color: '#00000088', offsetX: 0, offsetY: 20 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(488:7)", "entry");
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.width('100%');
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.height('100%');
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.borderRadius(28);
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.backgroundColor('#1AFFFFFF');
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.backdropBlur(20);
            // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
            Column.border({ width: 1, color: '#33FFFFFF' });
        }, Column);
        // 1. 移除纯实色或生硬的渐变，改用较低透明度的背景 + 背景模糊 (毛玻璃)
        Column.pop();
        // 星空与流星（保持在底层）
        this.StarField.bind(this)();
        this.MeteorField.bind(this)(cfg);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(499:7)", "entry");
            Column.width('100%');
            Column.height('100%');
        }, Column);
        this.CardHeader.bind(this)(cfg);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(502:9)", "entry");
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Center);
            Column.layoutWeight(1);
            Column.justifyContent(FlexAlign.SpaceBetween);
        }, Column);
        this.ModeSwitch.bind(this)(cfg);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.create(`X.FM - ${this.mode === 'focus' ? (this.lang === 'cn' ? '中文' : 'EN') : '睡眠'}`);
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(506:11)", "entry");
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.fontSize(34);
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.fontWeight(FontWeight.Bold);
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.fontColor('#FFFFFF');
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.margin({ top: 18 });
            // 【优化】合并文本，避免中英文分离导致的对齐问题
            Text.letterSpacing(2);
        }, Text);
        // 【优化】合并文本，避免中英文分离导致的对齐问题
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(cfg.subtitle);
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(513:11)", "entry");
            Text.fontSize(14);
            Text.fontColor('#FFFFFFBB');
            Text.margin({ top: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(cfg.desc);
            Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(518:11)", "entry");
            Text.fontSize(12);
            Text.fontColor('#FFFFFF66');
            Text.letterSpacing(2);
            Text.margin({ top: 6 });
        }, Text);
        Text.pop();
        this.DotVisualizer.bind(this)(cfg);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 【优化】重构控制栏：移除产生歧义的语言切换箭头
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(527:11)", "entry");
            // 【优化】重构控制栏：移除产生歧义的语言切换箭头
            Row.width('100%');
            // 【优化】重构控制栏：移除产生歧义的语言切换箭头
            Row.justifyContent(FlexAlign.Center);
            // 【优化】重构控制栏：移除产生歧义的语言切换箭头
            Row.margin({ top: 6, bottom: 32 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 如果只有单向播放，可以考虑放入其他功能键，例如：收藏、定时
            // 此处用透明占位符保持播放按钮居中，或者直接去掉两边
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/PlayerPage.ets(530:13)", "entry");
            // 如果只有单向播放，可以考虑放入其他功能键，例如：收藏、定时
            // 此处用透明占位符保持播放按钮居中，或者直接去掉两边
            Blank.width(44);
        }, Blank);
        // 如果只有单向播放，可以考虑放入其他功能键，例如：收藏、定时
        // 此处用透明占位符保持播放按钮居中，或者直接去掉两边
        Blank.pop();
        this.PlayButton.bind(this)(cfg);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/PlayerPage.ets(532:13)", "entry");
            Blank.width(44);
        }, Blank);
        Blank.pop();
        // 【优化】重构控制栏：移除产生歧义的语言切换箭头
        Row.pop();
        Column.pop();
        Column.pop();
        Stack.pop();
    }
    // 底部胶囊 (结合逻辑优化)
    BottomControls(cfg: ModeConfig, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(555:5)", "entry");
            Column.width('100%');
            Column.height(100);
            Column.alignItems(HorizontalAlign.Center);
            Column.margin({ bottom: 24 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 【优化】条件渲染：只有 focus 模式才显示 Channel，sleep 模式可以显示定时器或留白
            if (this.mode === 'focus') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('CHANNELS');
                        Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(558:9)", "entry");
                        Text.fontSize(11);
                        Text.fontColor('#FFFFFF55');
                        Text.letterSpacing(4);
                        Text.margin({ bottom: 14 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/PlayerPage.ets(564:9)", "entry");
                        Row.padding(3);
                        Row.borderRadius(26);
                        Row.backgroundColor('#FFFFFF10');
                        Row.backdropBlur(15);
                        Row.border({ width: 1, color: '#FFFFFF15' });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const l = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(l === 'cn' ? '中文' : 'EN');
                                Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(566:13)", "entry");
                                globalThis.Context.animation({ duration: 250, curve: Curve.EaseOut });
                                Text.fontSize(14);
                                Text.fontColor(this.lang === l ? cfg.accent : '#FFFFFFAA');
                                Text.fontWeight(this.lang === l ? FontWeight.Bold : FontWeight.Regular);
                                Text.padding({ left: 30, right: 30, top: 10, bottom: 10 });
                                Text.borderRadius(22);
                                Text.backgroundColor(this.lang === l ? '#11FFFFFF' : 'transparent');
                                Text.border(this.lang === l
                                    ? { width: 1, color: cfg.accent }
                                    : { width: 1, color: 'transparent' });
                                globalThis.Context.animation(null);
                                Text.onClick(() => this.switchLang(l));
                            }, Text);
                            Text.pop();
                        };
                        this.forEachUpdateFunction(elmtId, ['cn', 'en'] as Array<'cn' | 'en'>, forEachItemGenFunction);
                    }, ForEach);
                    ForEach.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Sleep 模式下的占位或定时器 UI
                        Text.create('SLEEP TIMER');
                        Text.debugLine("entry/src/main/ets/pages/PlayerPage.ets(589:9)", "entry");
                        // Sleep 模式下的占位或定时器 UI
                        Text.fontSize(11);
                        // Sleep 模式下的占位或定时器 UI
                        Text.fontColor('#FFFFFF55');
                        // Sleep 模式下的占位或定时器 UI
                        Text.letterSpacing(4);
                        // Sleep 模式下的占位或定时器 UI
                        Text.margin({ bottom: 14 });
                    }, Text);
                    // Sleep 模式下的占位或定时器 UI
                    Text.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/PlayerPage.ets(603:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 保持深色背景，但渐变更加平滑
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(605:7)", "entry");
            // 保持深色背景，但渐变更加平滑
            Column.width('100%');
            // 保持深色背景，但渐变更加平滑
            Column.height('100%');
            // 保持深色背景，但渐变更加平滑
            Column.linearGradient({
                angle: 180,
                colors: [
                    ['#070B1D', 0],
                    ['#111636', 0.5],
                    ['#050814', 1] // 底部更暗，凸显光效
                ]
            });
        }, Column);
        // 保持深色背景，但渐变更加平滑
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(616:7)", "entry");
            Column.width('100%');
            Column.height('100%');
        }, Column);
        this.TopNav.bind(this)(this.getCurrentModeConfig());
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/PlayerPage.ets(619:9)", "entry");
            Column.layoutWeight(1);
            Column.justifyContent(FlexAlign.Center);
            Column.padding({ left: 24, right: 24 });
        }, Column);
        this.PlayerCard.bind(this)(this.getCurrentModeConfig());
        Column.pop();
        this.BottomControls.bind(this)(this.getCurrentModeConfig()) // 调用优化后的底部控件
        ;
        Column.pop();
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
