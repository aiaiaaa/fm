import window from '@ohos.window';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { RadioPlayer, PlayerState } from '../services/RadioPlayer';
import { BackgroundTask } from '../services/BackgroundTask';
import { MODES, ModeId, ModeConfig } from '../model/Modes';
import { Meteor } from '../components/Meteor';

interface StarDot {
  x: number;
  y: number;
  size: number;
  opacity: number;
}

@Component
export struct PlayerPage {
  @State isPlaying: boolean = false;
  @State isLoading: boolean = false;
  @State mode: ModeId = 'focus';
  @State lang: 'cn' | 'en' = 'cn';
  @State statusBarHeight: number = 40;

  // 点阵音波 —— 按截图：一排 23 颗圆点，中间高两头低
  @State dotScales: number[] = new Array(23).fill(0.4);
  private rhythmTimer: number = -1;

  // logo 4 根柱子
  @State logoBars: number[] = [10, 16, 8, 13];
  private logoTimer: number = -1;

  // 播放按钮外圈光晕呼吸
  @State glowScale: number = 1.0;
  @State glowOpacity: number = 0.35;

  // 星空
  private stars: StarDot[] = [];

  private player: RadioPlayer = new RadioPlayer();

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
      animateTo({ duration: 420, curve: Curve.EaseInOut }, () => {
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
    animateTo({
      duration: 1800,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.glowScale = 1.18;
      this.glowOpacity = 0.55;
    });
  }

  private startRhythm(): void {
    if (this.rhythmTimer >= 0) {
      return;
    }
    this.rhythmTimer = setInterval(() => {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
        const arr: number[] = [];
        for (let i = 0; i < 23; i++) {
          const center = Math.abs(i - 11);
          const base = 1.1 - center * 0.055;
          arr.push(Math.max(0.35, base + Math.random() * 0.35 - 0.1));
        }
        this.dotScales = arr;
      });
    }, 260);
  }

  private stopRhythm(): void {
    if (this.rhythmTimer >= 0) {
      clearInterval(this.rhythmTimer);
      this.rhythmTimer = -1;
    }
    animateTo({ duration: 400 }, () => {
      this.dotScales = new Array(23).fill(0.4);
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

  private async togglePlay(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.isPlaying) {
      await this.player.pause();
    } else {
      const cfg = MODES[this.mode];
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
  @Builder
  TopNav(cfg: ModeConfig) {
    Row() {
      Row({ space: 8 }) {
        Row({ space: 3 }) {
          ForEach([0, 1, 2, 3], (i: number) => {
            Column()
              .width(3)
              .height(this.logoBars[i])
              .borderRadius(2)
              .linearGradient({
                angle: 180,
                colors: [[cfg.accent, 0], [cfg.accentSecond, 1]]
              })
          })
        }
        .alignItems(VerticalAlign.Center)
        .height(22)

        Text('X.FM')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(1.5)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(48)
    .padding({ left: 24, right: 24 })
    .justifyContent(FlexAlign.Start)
    .margin({ top: this.statusBarHeight })
  }

  // 星空层
  @Builder
  StarField() {
    Stack() {
      ForEach(this.stars, (s: StarDot, idx: number) => {
        Column()
          .width(s.size)
          .height(s.size)
          .borderRadius(s.size / 2)
          .backgroundColor('#FFFFFF')
          .opacity(s.opacity)
          .position({ x: `${s.x}%`, y: `${s.y}%` })
      }, (s: StarDot, idx: number) => `star-${idx}`)
    }
    .width('100%')
    .height('100%')
  }

  // 流星层 —— 6 条斜向划过
  @Builder
  MeteorField(cfg: ModeConfig) {
    Stack() {
      Meteor({ startLeft: 75, delay: 0,    duration: 2200, cycle: 7000, color: cfg.accent })
      Meteor({ startLeft: 60, delay: 1400, duration: 2000, cycle: 6500, color: cfg.accent })
      Meteor({ startLeft: 85, delay: 2800, duration: 2400, cycle: 7500, color: cfg.accentSecond })
      Meteor({ startLeft: 45, delay: 4000, duration: 1800, cycle: 6800, color: cfg.accent })
      Meteor({ startLeft: 70, delay: 5200, duration: 2100, cycle: 7200, color: cfg.accentSecond })
      Meteor({ startLeft: 55, delay: 6400, duration: 1900, cycle: 6600, color: cfg.accent })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  // 点阵音波 —— 一排 23 颗圆点
  @Builder
  DotVisualizer(cfg: ModeConfig) {
    Row({ space: 6 }) {
      ForEach(this.dotScales, (scale: number, idx: number) => {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(cfg.accent)
          .scale({ x: 1, y: scale })
          .opacity(0.6 + scale * 0.4)
          .shadow({
            radius: this.isPlaying ? 4 : 0,
            color: cfg.accent,
            offsetX: 0,
            offsetY: 0
          })
      }, (_: number, idx: number) => `dot-${idx}`)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .height(40)
    .width('100%')
    .margin({ top: 30, bottom: 30 })
  }

  // 中心圆形播放按钮（截图样式：大圆绿色光晕）
  @Builder
  PlayButton(cfg: ModeConfig) {
    Stack() {
      // 外光晕（呼吸）
      Column()
        .width(110)
        .height(110)
        .borderRadius(55)
        .backgroundColor(cfg.accent)
        .opacity(this.isPlaying ? this.glowOpacity * 0.6 : 0.25)
        .scale({ x: this.glowScale, y: this.glowScale })

      // 主按钮
      Stack() {
        if (this.isLoading) {
          LoadingProgress()
            .width(34)
            .height(34)
            .color('#0A0E27')
        } else if (this.isPlaying) {
          Row({ space: 8 }) {
            Column().width(6).height(26).backgroundColor('#0A0E27').borderRadius(2)
            Column().width(6).height(26).backgroundColor('#0A0E27').borderRadius(2)
          }
        } else {
          // 播放三角 ▶
          Polygon({ width: 22, height: 24 })
            .points([[0, 0], [22, 12], [0, 24]])
            .fill('#0A0E27')
            .stroke(Color.Transparent)
            .margin({ left: 4 })
        }
      }
      .width(84)
      .height(84)
      .borderRadius(42)
      .backgroundColor(cfg.accent)
      .alignContent(Alignment.Center)
      .shadow({ radius: 24, color: cfg.accent, offsetX: 0, offsetY: 0 })
    }
    .width(110)
    .height(110)
    .alignContent(Alignment.Center)
    .onClick(() => this.togglePlay())
  }

  // 左右切台箭头
  @Builder
  ArrowButton(direction: 'left' | 'right') {
    Stack() {
      Text(direction === 'left' ? '\u2039' : '\u203A')
        .fontSize(30)
        .fontColor('#FFFFFF55')
        .fontWeight(FontWeight.Lighter)
    }
    .width(44)
    .height(44)
    .alignContent(Alignment.Center)
    .onClick(() => {
      // 快速切换中英文（仅 focus 模式有效果）
      if (this.mode === 'focus') {
        this.switchLang(this.lang === 'cn' ? 'en' : 'cn');
      }
    })
  }

  // 模式切换（专注 / 睡眠）
  @Builder
  ModeSwitch(cfg: ModeConfig) {
    Row() {
      ForEach(['focus', 'sleep'] as ModeId[], (m: ModeId) => {
        Text(MODES[m].label)
          .fontSize(13)
          .fontColor(this.mode === m ? '#0A0E27' : '#FFFFFFAA')
          .fontWeight(this.mode === m ? FontWeight.Bold : FontWeight.Regular)
          .padding({ left: 18, right: 18, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor(this.mode === m ? MODES[m].accent : '#00000000')
          .animation({ duration: 250, curve: Curve.EaseOut })
          .onClick(() => this.switchMode(m))
      })
    }
    .padding(3)
    .borderRadius(20)
    .backgroundColor('#FFFFFF10')
    .border({ width: 1, color: '#FFFFFF18' })
  }

  // 卡片头部标签
  @Builder
  CardHeader(cfg: ModeConfig) {
    Row() {
      Row({ space: 8 }) {
        // 绿色呼吸点
        Stack() {
          Column()
            .width(8).height(8)
            .borderRadius(4)
            .backgroundColor(cfg.accent)
            .shadow({ radius: 8, color: cfg.accent, offsetX: 0, offsetY: 0 })
        }
        Text(cfg.tag)
          .fontSize(12)
          .fontColor(cfg.accent)
          .fontWeight(FontWeight.Medium)
      }
      .alignItems(VerticalAlign.Center)

      Blank()

      // 右侧 LIVE 胶囊
      Row({ space: 6 }) {
        Column()
          .width(6).height(6)
          .borderRadius(3)
          .backgroundColor(this.isPlaying ? '#FF5353' : '#888888')
        Text('LIVE')
          .fontSize(11)
          .fontColor('#FFFFFFAA')
          .letterSpacing(1)
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(12)
      .backgroundColor('#FFFFFF10')
      .border({ width: 1, color: '#FFFFFF18' })
    }
    .width('100%')
    .padding({ left: 22, right: 18, top: 22 })
  }

  // 主播放卡片
  @Builder
  PlayerCard() {
    const cfg = MODES[this.mode];
    Stack() {
      // 背景渐变
      Column()
        .width('100%').height('100%')
        .borderRadius(28)
        .linearGradient({
          angle: 160,
          colors: [[cfg.bgFrom, 0], [cfg.bgTo, 1]]
        })
        .border({ width: 1, color: '#FFFFFF0F' })

      // 星空
      this.StarField()
      // 流星（关键效果）
      this.MeteorField(cfg)

      Column() {
        this.CardHeader(cfg)

        Column() {
          // 模式切换
          this.ModeSwitch(cfg)
            .margin({ top: 22 })

          // 大标题
          Row() {
            Text('X.FM - ')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(this.mode === 'focus'
              ? (this.lang === 'cn' ? '中文' : 'EN')
              : '睡眠')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .margin({ top: 18 })

          Text(cfg.subtitle)
            .fontSize(14)
            .fontColor('#FFFFFFBB')
            .margin({ top: 8 })

          Text(cfg.desc)
            .fontSize(12)
            .fontColor('#FFFFFF66')
            .letterSpacing(2)
            .margin({ top: 6 })

          this.DotVisualizer(cfg)

          // 控制栏：箭头 + 播放按钮
          Row() {
            this.ArrowButton('left')
            Blank().width(12)
            this.PlayButton(cfg)
            Blank().width(12)
            this.ArrowButton('right')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 6, bottom: 32 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%').height('100%')
    }
    .width('100%')
    .aspectRatio(0.78)
    .borderRadius(28)
    .clip(true)
    .shadow({ radius: 40, color: '#00000088', offsetX: 0, offsetY: 12 })
  }

  // 底部 CHANNELS 胶囊
  @Builder
  ChannelsCapsule() {
    const cfg = MODES[this.mode];
    Column() {
      Text('CHANNELS')
        .fontSize(11)
        .fontColor('#FFFFFF55')
        .letterSpacing(4)
        .margin({ bottom: 14 })

      Row() {
        ForEach(['cn', 'en'] as Array<'cn' | 'en'>, (l: 'cn' | 'en') => {
          Text(l === 'cn' ? '中文' : 'EN')
            .fontSize(14)
            .fontColor(this.lang === l ? cfg.accent : '#FFFFFFAA')
            .fontWeight(this.lang === l ? FontWeight.Bold : FontWeight.Regular)
            .padding({ left: 30, right: 30, top: 10, bottom: 10 })
            .borderRadius(22)
            .border(
              this.lang === l
                ? { width: 1, color: cfg.accent }
                : { width: 1, color: Color.Transparent }
            )
            .animation({ duration: 250, curve: Curve.EaseOut })
            .onClick(() => this.switchLang(l))
        })
      }
      .padding(3)
      .borderRadius(26)
      .backgroundColor('#FFFFFF0D')
      .border({ width: 1, color: '#FFFFFF15' })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      // 全屏深色背景
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['#0A0E27', 0],
            ['#111636', 0.5],
            ['#0A0E27', 1]
          ]
        })

      Column() {
        this.TopNav(MODES[this.mode])

        Column() {
          this.PlayerCard()
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 20, right: 20 })

        this.ChannelsCapsule()
          .margin({ bottom: 24 })
      }
      .width('100%').height('100%')
    }
    .width('100%').height('100%')
  }
}
