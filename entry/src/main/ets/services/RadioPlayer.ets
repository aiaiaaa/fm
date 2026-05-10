import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import avSession from '@ohos.multimedia.avsession';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

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

  async init(context: common.UIAbilityContext, cb: RadioPlayerCallbacks): Promise<void> {
    this.callbacks = cb;
    this.player = await media.createAVPlayer();
    this.bindPlayerEvents();

    // 创建 AVSession —— 锁屏控件 / 耳机线控入口
    try {
      this.session = await avSession.createAVSession(context, 'x_fm_session', 'audio');
      await this.session.activate();
      this.bindSessionEvents();
      await this.updateSessionMetadata();
    } catch (e) {
      hilog.error(0x0000, TAG, `createAVSession failed: ${JSON.stringify(e)}`);
    }
  }

  private setState(s: PlayerState): void {
    this.state = s;
    this.callbacks.onStateChange?.(s);
    this.updateSessionPlaybackState(s);
  }

  private bindPlayerEvents(): void {
    if (!this.player) {
      return;
    }
    const p = this.player;

    p.on('stateChange', (state: string, _reason: media.StateChangeReason) => {
      hilog.info(0x0000, TAG, `AVPlayer state: ${state}`);
      switch (state) {
        case 'idle':
          this.setState('idle');
          break;
        case 'initialized':
          p.audioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
            rendererFlags: 0
          };
          p.prepare().catch((e: Error) => {
            hilog.error(0x0000, TAG, `prepare failed: ${JSON.stringify(e)}`);
            this.callbacks.onError?.(e.message);
          });
          break;
        case 'prepared':
          p.play().catch((e: Error) => {
            hilog.error(0x0000, TAG, `play failed: ${JSON.stringify(e)}`);
            this.callbacks.onError?.(e.message);
          });
          break;
        case 'playing':
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
          this.setState('error');
          break;
        default:
          break;
      }
    });

    p.on('error', (err) => {
      hilog.error(0x0000, TAG, `AVPlayer error: ${JSON.stringify(err)}`);
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
    if (!this.player) {
      return;
    }
    try {
      this.currentUrl = url;
      const prev = this.state;
      this.setState('loading');
      // 如果当前不是 idle 状态，则先 reset 再重新赋 url
      if (prev !== 'idle' && prev !== 'error') {
        await this.player.reset();
      }
      this.player.url = url;
    } catch (e) {
      const err = e as Error;
      hilog.error(0x0000, TAG, `load failed: ${JSON.stringify(err)}`);
      this.callbacks.onError?.(err.message);
      this.setState('error');
    }
  }

  async play(): Promise<void> {
    if (!this.player) {
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
    if (this.player) {
      try {
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
