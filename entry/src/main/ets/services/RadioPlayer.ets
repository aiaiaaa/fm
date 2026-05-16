import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { avSession } from '@kit.AVSessionKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG = 'RadioPlayer';

export type PlayerState = 'idle' | 'loading' | 'playing' | 'paused' | 'error';

export interface TrackInfo {
  title: string;
  artist: string;
  album: string;
}

export interface RadioPlayerCallbacks {
  onStateChange?: (state: PlayerState) => void;
  onError?: (msg: string) => void;
}

/**
 * 基于 AVPlayer + AVSession 封装的 HLS 直播播放器
 * - AVPlayer: 实际播放 m3u8
 * - AVSession: 支持锁屏 / 通知中心 / 耳机线控
 * - 配合 module.json5 里的 "backgroundModes": ["audioPlayback"] 实现后台续播
 */
export class RadioPlayer {
  private player: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private currentUrl: string = '';
  private currentTrack: TrackInfo = { title: 'X.FM', artist: 'X.FM', album: 'AGENT实时广播' };
  private callbacks: RadioPlayerCallbacks = {};
  private state: PlayerState = 'idle';
  private loadTimeoutId: number = -1;

  async init(context: common.UIAbilityContext, cb: RadioPlayerCallbacks): Promise<void> {
    this.callbacks = cb;

    // 创建 AVSession —— 锁屏控件 / 耳机线控入口
    try {
      this.session = await avSession.createAVSession(context, 'x_fm_session', 'audio');
      await this.session.activate();
      this.bindSessionEvents();
      await this.updateSessionMetadata();
    } catch (e) {
      hilog.error(0x0000, TAG, `createAVSession failed: ${JSON.stringify(e)}`);
    }

    hilog.info(0x0000, TAG, `init: AVSession ready, player will be created on first load`);
  }

  private setState(s: PlayerState): void {
    this.state = s;
    hilog.info(0x0000, TAG, `setState: ${s}`);
    this.callbacks.onStateChange?.(s);
    this.updateSessionPlaybackState(s);
  }

  /**
   * 每次 load 都重新创建 AVPlayer 实例，确保干净的状态
   * 这是 HarmonyOS AVPlayer 最可靠的使用模式
   */
  private async createFreshPlayer(): Promise<media.AVPlayer> {
    // 先释放旧的
    if (this.player) {
      try {
        this.player.off('stateChange');
        this.player.off('error');
        await this.player.release();
      } catch (e) {
        hilog.warn(0x0000, TAG, `release old player: ${JSON.stringify(e)}`);
      }
      this.player = null;
    }

    const p = await media.createAVPlayer();
    hilog.info(0x0000, TAG, `createFreshPlayer: created, state = ${p.state}`);
    this.player = p;
    this.bindPlayerEvents(p);
    return p;
  }

  private bindPlayerEvents(p: media.AVPlayer): void {
    p.on('stateChange', (state: string, _reason: media.StateChangeReason) => {
      hilog.info(0x0000, TAG, `[stateChange] avplayer=${state}, internal=${this.state}`);
      switch (state) {
        case 'idle':
          if (this.state !== 'loading') {
            this.setState('idle');
          }
          break;
        case 'initialized':
          hilog.info(0x0000, TAG, `[stateChange] initialized -> waiting microtask then set audioRendererInfo + prepare()`);
          // 使用微任务延迟确保 AVPlayer 内部状态完全切换到 initialized
          Promise.resolve().then(() => {
            hilog.info(0x0000, TAG, `[initialized] now setting audioRendererInfo, player.state = ${p.state}`);
            try {
              p.audioRendererInfo = {
                usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
                rendererFlags: 0
              };
            } catch (e) {
              hilog.error(0x0000, TAG, `set audioRendererInfo failed: ${JSON.stringify(e)}, skipping...`);
            }
            p.prepare().catch((e: Error) => {
              hilog.error(0x0000, TAG, `prepare failed: ${JSON.stringify(e)}`);
              this.clearLoadTimeout();
              this.callbacks.onError?.(e.message);
              this.setState('error');
            });
          });
          break;
        case 'prepared':
          hilog.info(0x0000, TAG, `[stateChange] prepared -> calling play()`);
          p.play().catch((e: Error) => {
            hilog.error(0x0000, TAG, `play failed: ${JSON.stringify(e)}`);
            this.clearLoadTimeout();
            this.callbacks.onError?.(e.message);
            this.setState('error');
          });
          break;
        case 'playing':
          this.clearLoadTimeout();
          this.setState('playing');
          break;
        case 'paused':
          this.setState('paused');
          break;
        case 'stopped':
        case 'completed':
          this.setState('idle');
          break;
        case 'error':
          this.clearLoadTimeout();
          this.setState('error');
          break;
        default:
          hilog.info(0x0000, TAG, `[stateChange] unhandled state: ${state}`);
          break;
      }
    });

    p.on('error', (err) => {
      hilog.error(0x0000, TAG, `[on error] ${JSON.stringify(err)}`);
      this.clearLoadTimeout();
      this.setState('error');
      this.callbacks.onError?.(err.message || 'unknown');
    });
  }

  private bindSessionEvents(): void {
    if (!this.session) {
      return;
    }
    this.session.on('play', () => {
      this.play();
    });
    this.session.on('pause', () => {
      this.pause();
    });
    this.session.on('stop', () => {
      this.stop();
    });
  }

  private async updateSessionMetadata(): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      const metadata: avSession.AVMetadata = {
        assetId: 'xfm-live',
        title: this.currentTrack.title,
        artist: this.currentTrack.artist,
        album: this.currentTrack.album
      };
      await this.session.setAVMetadata(metadata);
    } catch (e) {
      hilog.error(0x0000, TAG, `setAVMetadata failed: ${JSON.stringify(e)}`);
    }
  }

  private async updateSessionPlaybackState(s: PlayerState): Promise<void> {
    if (!this.session) {
      return;
    }
    let state: number = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
    switch (s) {
      case 'playing':
        state = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
        break;
      case 'paused':
        state = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
        break;
      case 'loading':
        state = avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
        break;
      case 'error':
        state = avSession.PlaybackState.PLAYBACK_STATE_ERROR;
        break;
      default:
        state = avSession.PlaybackState.PLAYBACK_STATE_IDLE;
    }
    try {
      await this.session.setAVPlaybackState({ state });
    } catch (e) {
      hilog.error(0x0000, TAG, `setAVPlaybackState failed: ${JSON.stringify(e)}`);
    }
  }

  setTrack(info: TrackInfo): void {
    this.currentTrack = info;
    this.updateSessionMetadata();
  }

  async load(url: string): Promise<void> {
    try {
      this.currentUrl = url;
      this.setState('loading');

      // 每次 load 都创建全新的 AVPlayer 实例
      const p = await this.createFreshPlayer();

      hilog.info(0x0000, TAG, `load: fresh player state = ${p.state}`);

      // 启动超时保护：20 秒
      this.clearLoadTimeout();
      this.loadTimeoutId = setTimeout(() => {
        if (this.state === 'loading') {
          hilog.error(0x0000, TAG, `load timeout after 20s, url: ${url}`);
          this.callbacks.onError?.('加载超时，请检查网络');
          this.setState('error');
          p.reset().catch(() => {});
        }
      }, 20000);

      // 设置 url 触发状态流转: idle -> initialized -> prepared -> playing
      hilog.info(0x0000, TAG, `load: setting url = ${url}`);
      p.url = url;
      hilog.info(0x0000, TAG, `load: url has been set, waiting for stateChange...`);
    } catch (e) {
      const err = e as Error;
      hilog.error(0x0000, TAG, `load exception: ${JSON.stringify(err)}`);
      this.callbacks.onError?.(err.message);
      this.setState('error');
      this.clearLoadTimeout();
    }
  }

  private clearLoadTimeout(): void {
    if (this.loadTimeoutId >= 0) {
      clearTimeout(this.loadTimeoutId);
      this.loadTimeoutId = -1;
    }
  }

  async play(): Promise<void> {
    if (!this.player) {
      if (this.currentUrl) {
        await this.load(this.currentUrl);
      }
      return;
    }
    try {
      if (this.state === 'paused') {
        await this.player.play();
      } else if (this.currentUrl) {
        await this.load(this.currentUrl);
      }
    } catch (e) {
      const err = e as Error;
      this.callbacks.onError?.(err.message);
    }
  }

  async pause(): Promise<void> {
    if (!this.player) {
      return;
    }
    try {
      await this.player.pause();
    } catch (e) {
      hilog.error(0x0000, TAG, `pause failed: ${JSON.stringify(e)}`);
    }
  }

  async stop(): Promise<void> {
    if (!this.player) {
      return;
    }
    try {
      await this.player.stop();
    } catch (e) {
      hilog.error(0x0000, TAG, `stop failed: ${JSON.stringify(e)}`);
    }
  }

  async release(): Promise<void> {
    this.clearLoadTimeout();
    if (this.player) {
      try {
        this.player.off('stateChange');
        this.player.off('error');
        await this.player.release();
      } catch (e) {
        hilog.error(0x0000, TAG, `release failed: ${JSON.stringify(e)}`);
      }
      this.player = null;
    }
    if (this.session) {
      try {
        await this.session.deactivate();
        await this.session.destroy();
      } catch (e) {
        hilog.error(0x0000, TAG, `session destroy failed: ${JSON.stringify(e)}`);
      }
      this.session = null;
    }
  }

  getState(): PlayerState {
    return this.state;
  }
}
