import { window } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RadioPlayer, PlayerState } from '../services/RadioPlayer';
import { BackgroundTask } from '../services/BackgroundTask';
import { ListeningStats } from '../services/ListeningStats';
import { MODES, ModeId, ModeConfig } from '../model/Modes';
import { MeteorField } from '../components/MeteorField';
import { WaveVisualizer } from '../components/WaveVisualizer';

const PAGE_TAG = 'PlayerPage';

interface StarDot {
  x: number;
  y: number;
  size: number;
  opacity: number;
}

/**
 * 电台首页 —— 严格对标设计稿：
 *   顶部 X.FM LOGO
 *   ├─ "正在直播" 标题行  + LIVE 徽标 + 小波形图标
 *   ├─ 大卡片（主播放区）
 *   │    流星 + 星空 + "X.FM - 中文" + 描述 + 音波 + 上/播放/下按钮
 *   └─ "电台模式" 标题
 *        ├─ 专注电台 卡片
 *        └─ 睡眠电台 卡片
 */
@Component
export struct PlayerPage {
  @State isPlaying: boolean = false;
  @State isLoading: boolean = false;
  @State mode: ModeId = 'focus';
  @State lang: 'cn' | 'en' = 'cn';
  @State statusBarHeight: number = 40;

  // logo 4 根柱子
  @State logoBars: number[] = [10, 16, 8, 13];
  private logoTimer: number = -1;

  // LIVE 右侧的小波形（图片右上角）
  @State miniBars: number[] = [0.4, 0.7, 0.5, 0.9, 0.6];
  private miniTimer: number = -1;

  // 播放按钮外圈光晕
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
    for (let i = 0; i < 55; i++) {
      list.push({
        x: Math.random() * 100,
        y: Math.random() * 100,
        size: Math.random() < 0.15 ? 2.2 : 1.2,
        opacity: 0.2 + Math.random() * 0.55
      });
    }
    this.stars = list;

    // 初始化播放器 + AVSession + 后台任务
    const context = getContext(this) as common.UIAbilityContext;
    ListeningStats.init(context);
    this.player.init(context, {
      onStateChange: (s: PlayerState) => {
        hilog.info(0x0000, PAGE_TAG, `onStateChange: ${s}`);
        switch (s) {
          case 'loading':
            this.isLoading = true;
            break;
          case 'playing':
            this.isLoading = false;
            this.isPlaying = true;
            BackgroundTask.start(context);
            ListeningStats.startCounting(this.mode === 'focus' ? 'focus' : 'sleep');
            break;
          case 'paused':
          case 'idle':
            this.isPlaying = false;
            this.isLoading = false;
            ListeningStats.stopCounting();
            break;
          case 'error':
            this.isPlaying = false;
            this.isLoading = false;
            ListeningStats.stopCounting();
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
    this.startMiniAnim();
    this.startGlowAnim();
  }

  aboutToDisappear(): void {
    if (this.logoTimer >= 0) clearInterval(this.logoTimer);
    if (this.miniTimer >= 0) clearInterval(this.miniTimer);
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

  private startMiniAnim(): void {
    this.miniTimer = setInterval(() => {
      animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
        this.miniBars = this.miniBars.map(() => 0.3 + Math.random() * 0.7);
      });
    }, 300);
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

  /* ============ 播放控制 ============ */

  private currentUrl(): string {
    if (this.mode === 'focus') {
      return this.lang === 'cn'
        ? 'https://koe.bbg.fm/channels/2/playlist.m3u8'
        : 'https://lhttp.qtfm.cn/live/20500010/64k.mp3';
    }
    return MODES.sleep.url;
  }

  private currentCfg(): ModeConfig {
    return this.mode === 'focus' ? MODES.focus : MODES.sleep;
  }

  private currentTitle(): string {
    if (this.mode === 'focus') {
      return this.lang === 'cn' ? 'X.FM - 中文' : 'X.FM - EN';
    }
    return 'X.FM - 睡眠';
  }

  private async togglePlay(): Promise<void> {
    hilog.info(0x0000, PAGE_TAG, `togglePlay: isLoading=${this.isLoading}, isPlaying=${this.isPlaying}, mode=${this.mode}, lang=${this.lang}`);
    if (this.isLoading) return;
    if (this.isPlaying) {
      hilog.info(0x0000, PAGE_TAG, `togglePlay: calling pause`);
      await this.player.pause();
      return;
    }
    const cfg = this.currentCfg();
    this.player.setTrack({
      title: this.currentTitle(),
      artist: 'X.FM',
      album: cfg.subtitle
    });
    // 若已加载同一路但为暂停 → 直接 play；否则 load 新流
    if (this.player.getState() === 'paused') {
      hilog.info(0x0000, PAGE_TAG, `togglePlay: resuming from paused`);
      await this.player.play();
    } else {
      const url = this.currentUrl();
      hilog.info(0x0000, PAGE_TAG, `togglePlay: loading new url = ${url}`);
      await this.player.load(url);
    }
  }

  private async switchMode(m: ModeId): Promise<void> {
    if (this.mode === m) return;
    this.mode = m;
    if (this.isPlaying || this.isLoading) {
      await this.player.stop();
      await this.player.load(this.currentUrl());
    }
  }

  private async switchLang(l: 'cn' | 'en'): Promise<void> {
    if (this.lang === l) return;
    this.lang = l;
    if (this.isPlaying || this.isLoading) {
      await this.player.stop();
      await this.player.load(this.currentUrl());
    }
  }

  /* ============ UI Builders ============ */

  @Builder
  LogoHeader() {
    Row({ space: 10 }) {
      Row({ space: 3 }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Column()
            .width(4)
            .height(this.logoBars[i])
            .borderRadius(2)
            .linearGradient({
              angle: 180,
              colors: [[0x52FFA1, 0], [0x00D2FF, 1]]
            })
        }, (i: number) => `lb-${i}`)
      }
      .alignItems(VerticalAlign.Center)
      .height(22)

      Text('X.FM')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(0xFFFFFF)
        .letterSpacing(2)
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .margin({ top: this.statusBarHeight + 12, bottom: 24 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SectionTitle(title: string) {
    Row() {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(0xFFFFFF)
        .layoutWeight(1)

      // 仅 "正在直播" 显示 LIVE + mini wave
      if (title === '正在直播') {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Column().width(7).height(7).borderRadius(4).backgroundColor(0x52FFA1)
              .shadow({ radius: 6, color: '#52FFA1', offsetX: 0, offsetY: 0 })
            Text('LIVE')
              .fontSize(12)
              .fontColor(0xCCFFFFFF)
              .letterSpacing(1)
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 10, right: 12, top: 4, bottom: 4 })
          .borderRadius(14)
          .border({ width: 1, color: 0x0DFFFFFF })
          .backgroundColor(0x08FFFFFF)

          Row({ space: 2 }) {
            ForEach(this.miniBars, (lv: number, idx: number) => {
              Column()
                .width(2)
                .height(4 + lv * 14)
                .borderRadius(1)
                .backgroundColor('#52FFA1')
                .opacity(0.65 + lv * 0.35)
            }, (_: number, idx: number) => `mini-${idx}`)
          }
          .alignItems(VerticalAlign.Center)
          .height(20)
        }
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .margin({ bottom: 14 })
  }

  // 星空
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

  // 播放按钮
  @Builder
  PlayButton() {
    Stack() {
      // 外光晕
      Column()
        .width(84)
        .height(84)
        .borderRadius(42)
        .backgroundColor('#52FFA1')
        .opacity(this.isPlaying ? this.glowOpacity * 0.6 : 0.22)
        .scale({ x: this.glowScale, y: this.glowScale })

      // 主按钮
      Stack() {
        if (this.isLoading) {
          LoadingProgress().width(30).height(30).color('#0A0E27')
        } else if (this.isPlaying) {
          Row({ space: 7 }) {
            Column().width(5).height(22).backgroundColor('#0A0E27').borderRadius(2)
            Column().width(5).height(22).backgroundColor('#0A0E27').borderRadius(2)
          }
        } else {
          Polygon({ width: 20, height: 22 })
            .points([[0, 0], [20, 11], [0, 22]])
            .fill('#0A0E27')
            .stroke(Color.Transparent)
            .margin({ left: 4 })
        }
      }
      .width(68)
      .height(68)
      .borderRadius(34)
      .backgroundColor('#52FFA1')
      .alignContent(Alignment.Center)
      .shadow({ radius: 22, color: '#52FFA1', offsetX: 0, offsetY: 0 })
    }
    .width(84)
    .height(84)
    .alignContent(Alignment.Center)
    .focusable(false)
    .onClick(() => this.togglePlay())
  }

  // 中间大卡片（正在直播）
  @Builder
  LiveCard(cfg: ModeConfig) {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .borderRadius(24)
        .linearGradient({
          angle: 160,
          colors: [['#111622', 0], ['#0E1320', 0.6], ['#0A0E1A', 1]]
        })
        .border({ width: 1, color: '#08FFFFFF' })
        .shadow({ radius: 30, color: '#88000000', offsetX: 0, offsetY: 10 })

      // 星空
      this.StarField()
      // 流星层（降低密度到 3，匹配 CSS 6s 周期的低频效果）
      MeteorField({ accent: cfg.accent, accentSecond: cfg.accentSecond, density: 3 })

      Column() {
        // 顶部标签 "AGENT · 实时播报"
        Row({ space: 8 }) {
          Column()
            .width(8).height(8)
            .borderRadius(4)
            .backgroundColor(cfg.accent)
            .shadow({ radius: 6, color: cfg.accent, offsetX: 0, offsetY: 0 })
          Text('AGENT')
            .fontSize(12).fontColor(cfg.accent).fontWeight(FontWeight.Medium)
          Text('·')
            .fontSize(12).fontColor('#88FFFFFF')
          Text(this.mode === 'focus' ? '实时播报' : '助眠播放')
            .fontSize(12).fontColor('#CCFFFFFF')
        }
        .width('100%')
        .padding({ left: 22, top: 20 })
        .alignItems(VerticalAlign.Center)

        Blank()

        // 中部文字
        Column() {
          Text(this.currentTitle())
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(1.5)

          Text(this.mode === 'focus' ? 'AGENT正在为您播报' : cfg.subtitle)
            .fontSize(13)
            .fontColor('#AAFFFFFF')
            .margin({ top: 10 })

          Text(cfg.desc)
            .fontSize(12)
            .fontColor('#5E6678')
            .letterSpacing(2)
            .margin({ top: 6 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // 音波
        Column() {
          WaveVisualizer({
            active: this.isPlaying,
            streamUrl: this.currentUrl(),
            accent: cfg.accent,
            bars: 16,
            maxHeight: 72
          })
        }
        .width('100%')
        .margin({ top: 24 })

        // 上一台 / 播放 / 下一台
        Row() {
          Stack() {
            Polygon({ width: 14, height: 16 })
              .points([[14, 0], [0, 8], [14, 16]])
              .fill('#5E6678')
              .stroke(Color.Transparent)
          }
          .width(44).height(44)
          .alignContent(Alignment.Center)
          .focusable(false)
          .onClick(() => {
            if (this.mode === 'focus') this.switchLang(this.lang === 'cn' ? 'en' : 'cn');
          })

          Blank().width(30)
          this.PlayButton()
          Blank().width(30)

          Stack() {
            Polygon({ width: 14, height: 16 })
              .points([[0, 0], [14, 8], [0, 16]])
              .fill('#5E6678')
              .stroke(Color.Transparent)
          }
          .width(44).height(44)
          .alignContent(Alignment.Center)
          .focusable(false)
          .onClick(() => {
            if (this.mode === 'focus') this.switchLang(this.lang === 'cn' ? 'en' : 'cn');
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 22, bottom: 26 })

        Blank().height(4)
      }
      .width('100%').height('100%')
    }
    .width('100%')
    .aspectRatio(0.85)
    .borderRadius(24)
    .clip(true)
  }

  /* ============ 电台模式 卡片 ============ */

  @Builder
  ModeIcon(m: ModeId) {
    if (m === 'focus') {
      // 同心圆雷达样式
      Stack() {
        Column().width(60).height(60).borderRadius(30)
          .border({ width: 1.5, color: '#1AFFFFFF' })
        Column().width(42).height(42).borderRadius(21)
          .border({ width: 1.5, color: '#33FFFFFF' })
        Column().width(22).height(22).borderRadius(11)
          .backgroundColor('#52FFA1')
          .shadow({ radius: 10, color: '#52FFA1', offsetX: 0, offsetY: 0 })
      }
      .width(60).height(60)
      .alignContent(Alignment.Center)
    } else {
      // 月亮（Unicode 符号即可）
      Stack() {
        Text('\uD83C\uDF19')
          .fontSize(50)
      }
      .width(60).height(60)
      .alignContent(Alignment.Center)
    }
  }

  @Builder
  ModeCard(m: ModeId) {
    Column() {
      Blank().height(18)
      this.ModeIcon(m)

      Text(m === 'focus' ? '专注电台' : '睡眠电台')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(m === 'focus' ? '#52FFA1' : '#B69CFF')
        .margin({ top: 18 })

      Text(m === 'focus' ? '深度资讯，专注当下' : '舒缓声音，伴你入眠')
        .fontSize(12)
        .fontColor('#99FFFFFF')
        .margin({ top: 8 })

      Blank().layoutWeight(1)

      // 底部胶囊按钮
      Row({ space: 6 }) {
        Row({ space: 2 }) {
          ForEach([0.4, 0.8, 0.5, 0.9, 0.4], (lv: number, idx: number) => {
            Column()
              .width(2)
              .height(4 + lv * 10)
              .borderRadius(1)
              .backgroundColor(m === 'focus' ? '#52FFA1' : '#B69CFF')
          }, (_: number, idx: number) => `mc-${m}-${idx}`)
        }
        .alignItems(VerticalAlign.Center)
        .height(16)

        Text(m === 'focus' ? (this.mode === 'focus' && this.isPlaying ? '正在直播' : '正在直播') : '助眠播放')
          .fontSize(13)
          .fontColor('#DDFFFFFF')
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(18)
      .backgroundColor(m === 'focus' ? '#2252FFA1' : '#338B7CF6')
      .border({ width: 0.5, color: '#0DFFFFFF' })
      .margin({ bottom: 22 })
    }
    .layoutWeight(1)
    .height(220)
    .borderRadius(22)
    .linearGradient({
      angle: 160,
      colors: m === 'focus'
        ? [['#0E1E1A', 0], ['#111622', 1]]
        : [['#161230', 0], ['#111622', 1]]
    })
    .border({
      width: 0.5,
      color: '#0DFFFFFF'
    })
    .alignItems(HorizontalAlign.Center)
    .focusable(false)
    .onClick(() => this.switchMode(m))
  }

  @Builder
  ModeRow() {
    Row({ space: 12 }) {
      this.ModeCard('focus')
      this.ModeCard('sleep')
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%').height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0A0F1A', 0], ['#0A0F1A', 0.5], ['#0A0F1A', 1]]
        })

      Scroll() {
        Column() {
          this.LogoHeader()

          this.SectionTitle('正在直播')
          Column() {
            this.LiveCard(this.currentCfg())
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .margin({ bottom: 28 })

          this.SectionTitle('电台模式')
          this.ModeRow()

          // 留白高度需超过底部悬浮胶囊TabBar（56+20=76vp）
          Blank().height(110)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .focusable(false)
    }
    .width('100%')
    .height('100%')
    .focusable(false)
  }
}
