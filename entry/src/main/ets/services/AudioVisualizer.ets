import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AudioVisualizer';

/**
 * 音波可视化服务：调用鸿蒙底层音频 API 感知系统输出状态，
 * 并据此生成更贴近真实播放的音波数据。
 *
 * 核心依赖（HarmonyOS NEXT API 12+ / HarmonyOS 6.10）：
 *   - @kit.AudioKit → audio.AudioStreamManager：
 *     通过 getCurrentAudioRendererInfoArray 轮询当前 renderer 状态
 *   - AudioVolumeManager：通过 getVolumeSync 读取媒体音量
 *
 * 注意：API 12+ 中 AudioRendererChangeInfo 已移除 rendererState 字段，
 * AudioVolumeGroupManager 也不再支持 on('volumeChange')。
 * 因此本实现采用轮询方式获取音频状态。
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

      // 通过轮询 getCurrentAudioRendererInfoArray 感知音频输出状态
      // 这是 API 12+ 推荐的方式，替代 on('audioRendererChange') 中已移除的 rendererState
      this.pollRendererState();

      // 获取音量：使用 AudioVolumeManager 的 getVolumeSync（API 12+）
      this.refreshVolume(mgr);
    } catch (e) {
      hilog.warn(0x0000, TAG, `native audio api init: ${JSON.stringify(e)}`);
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
    this.streamMgr = null;
    this.cb = null;
  }

  /**
   * 轮询当前活跃的 AudioRenderer 列表来判断是否有音频正在输出。
   * getCurrentAudioRendererInfoArray 返回当前所有活跃的 renderer 信息。
   */
  private pollRendererState(): void {
    if (!this.streamMgr) return;
    try {
      // getCurrentAudioRendererInfoArray 是同步 API（API 12+）
      const infoArray = this.streamMgr.getCurrentAudioRendererInfoArray();
      // 如果有任何活跃 renderer，认为系统正在播放音频
      this.systemRunning = infoArray.length > 0;
    } catch (e) {
      // 轮询失败不影响 UI
      hilog.debug(0x0000, TAG, `pollRendererState: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 获取系统媒体音量（API 12+ 使用 getVolumeSync）
   */
  private refreshVolume(mgr: audio.AudioManager): void {
    try {
      const volMgr = mgr.getVolumeManager();
      const groupMgr = volMgr.getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID);
      const v = groupMgr.getVolumeSync(audio.AudioVolumeType.MEDIA);
      const max = groupMgr.getMaxVolumeSync(audio.AudioVolumeType.MEDIA);
      if (max > 0) {
        this.systemVolume = Math.min(1, Math.max(0.15, v / max));
      }
    } catch (e) {
      hilog.warn(0x0000, TAG, `refreshVolume failed: ${JSON.stringify(e)}`);
      // 使用默认值 0.6
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

    // 每 3 次 tick（约 270ms）轮询一次 renderer 状态，减少性能开销
    if (Math.floor(this.phase * 10) % 3 === 0) {
      this.pollRendererState();
    }

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
