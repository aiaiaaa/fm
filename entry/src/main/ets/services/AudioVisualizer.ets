import audio from '@ohos.multimedia.audio';
import hilog from '@ohos.hilog';

const TAG = 'AudioVisualizer';

/**
 * 音波可视化服务：调用鸿蒙底层音频 API 感知系统输出状态，
 * 并据此生成更贴近真实播放的音波数据。
 *
 * 核心依赖：
 *   - @ohos.multimedia.audio 的 AudioStreamManager：订阅 RENDERER 变化
 *   - AudioVolumeGroupManager：读取当前媒体音量
 *
 * 调用方（UI）只需要：
 *   1) start(cb)                 —— 启动取样回路，cb 中拿 levels[]
 *   2) setActive(playing)        —— 播放/暂停时通知，让波形进入活跃/静默
 *   3) stop()                    —— 释放监听与定时器
 */
export interface VisualizerOptions {
  bars: number;                // 柱条数量
  intervalMs: number;          // 采样间隔 (ms)
}

export type VisualizerCallback = (levels: number[], active: boolean) => void;

export class AudioVisualizer {
  private streamMgr: audio.AudioStreamManager | null = null;
  private volumeMgr: audio.AudioVolumeGroupManager | null = null;
  private timer: number = -1;
  private phase: number = 0;
  private active: boolean = false;
  private opts: VisualizerOptions = { bars: 28, intervalMs: 90 };
  private cb: VisualizerCallback | null = null;
  /** 来自系统的 0..1 实时音量（媒体流） */
  private systemVolume: number = 0.6;
  /** 来自系统的 renderer 是否处于 RUNNING 状态 */
  private systemRunning: boolean = false;

  async start(opts: VisualizerOptions, cb: VisualizerCallback): Promise<void> {
    this.opts = opts;
    this.cb = cb;

    try {
      const mgr = audio.getAudioManager();
      this.streamMgr = mgr.getStreamManager();

      // 订阅 renderer 状态变化：音频是否真的在输出
      this.streamMgr.on('audioRendererChange', (infoArray: audio.AudioRendererChangeInfo[]) => {
        let anyRunning = false;
        for (const info of infoArray) {
          if (info.rendererState === audio.AudioState.STATE_RUNNING) {
            anyRunning = true;
            break;
          }
        }
        this.systemRunning = anyRunning;
      });

      // 音量管理：读取当前媒体音量作为波形基准振幅
      const vgm = await mgr.getVolumeManager().getVolumeGroupManager(audio.DEFAULT_VOLUME_GROUP_ID);
      this.volumeMgr = vgm;
      await this.refreshVolume();
      vgm.on('volumeChange', () => {
        this.refreshVolume();
      });
    } catch (e) {
      hilog.warn(0x0000, TAG, `native audio api unavailable, fallback to synthetic: ${JSON.stringify(e)}`);
      // 即便鸿蒙原生 API 不可用，也要继续用合成波形，保证 UI 有反馈
    }

    // 启动采样回路
    this.timer = setInterval(() => this.tick(), this.opts.intervalMs);
  }

  setActive(playing: boolean): void {
    this.active = playing;
  }

  async stop(): Promise<void> {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    try {
      this.streamMgr?.off('audioRendererChange');
    } catch (_e) {
      // ignore
    }
    try {
      this.volumeMgr?.off('volumeChange');
    } catch (_e) {
      // ignore
    }
    this.streamMgr = null;
    this.volumeMgr = null;
    this.cb = null;
  }

  private async refreshVolume(): Promise<void> {
    if (!this.volumeMgr) return;
    try {
      const v = await this.volumeMgr.getVolume(audio.AudioVolumeType.MEDIA);
      const max = await this.volumeMgr.getMaxVolume(audio.AudioVolumeType.MEDIA);
      if (max > 0) {
        this.systemVolume = Math.min(1, Math.max(0.15, v / max));
      }
    } catch (e) {
      hilog.warn(0x0000, TAG, `getVolume failed: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 每一个采样 tick：生成 bars 个 [0,1] 的值。
   * - active 为 true 且系统 renderer 在跑：正常钟形波
   * - active 为 true 但系统未 running：半振幅暖场
   * - active 为 false：极低静默线
   */
  private tick(): void {
    if (!this.cb) return;
    this.phase += 0.45;

    const N = this.opts.bars;
    const center = (N - 1) / 2;
    const levels: number[] = new Array(N);

    const baseGain = this.active ? (this.systemRunning ? 1.0 : 0.55) : 0.08;
    const volumeGain = 0.5 + this.systemVolume * 0.7;

    for (let i = 0; i < N; i++) {
      const x = (i - center) / center;            // -1..1
      const envelope = Math.exp(-x * x * 2.2);    // 中间高两边低
      const lo = Math.sin(this.phase * 0.7 + i * 0.25) * 0.35;
      const mid = Math.sin(this.phase * 1.4 + i * 0.55) * 0.45;
      const beat = this.active ? (Math.random() * 0.2 - 0.1) : 0;
      const v = Math.abs(lo + mid + beat) * envelope * baseGain * volumeGain;
      levels[i] = Math.max(0.06, Math.min(1, 0.12 + v * 1.35));
    }
    this.cb(levels, this.active && this.systemRunning);
  }
}
