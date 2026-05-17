import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AudioVisualizer';

/**
 * 音波可视化服务：调用鸿蒙底层音频 API 获取系统音量，
 * 结合播放状态生成贴近真实播放的音波数据。
 *
 * 核心依赖（HarmonyOS NEXT API 12+ / HarmonyOS 6.10）：
 *   - @kit.AudioKit → audio.AudioManager.getVolumeManager()
 *   - AudioVolumeGroupManager.getVolumeSync / getMaxVolumeSync
 *
 * 播放状态由外部调用 setActive() 传入（来自 AVPlayer 状态回调），
 * 避免依赖 getCurrentAudioRendererInfoArray 的异步返回值。
 *
 * 调用方（UI）只需要：
 *   1) start(opts, cb)           —— 启动取样回路，cb 中拿 levels[]
 *   2) setActive(playing)        —— 播放/暂停时通知，让波形进入活跃/静默
 *   3) stop()                    —— 释放定时器
 */
export interface VisualizerOptions {
  bars: number;                // 柱条数量
  intervalMs: number;          // 采样间隔 (ms)
}

export type VisualizerCallback = (levels: number[], active: boolean) => void;

export class AudioVisualizer {
  private timer: number = -1;
  private phase: number = 0;
  private active: boolean = false;
  private opts: VisualizerOptions = { bars: 28, intervalMs: 90 };
  private cb: VisualizerCallback | null = null;
  /** 来自系统的 0..1 实时音量（媒体流） */
  private systemVolume: number = 0.6;

  async start(opts: VisualizerOptions, cb: VisualizerCallback): Promise<void> {
    this.opts = opts;
    this.cb = cb;

    // 获取系统媒体音量作为波形振幅基准
    try {
      const mgr = audio.getAudioManager();
      const volMgr = mgr.getVolumeManager();
      const groupMgr = volMgr.getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID);
      const v = groupMgr.getVolumeSync(audio.AudioVolumeType.MEDIA);
      const max = groupMgr.getMaxVolumeSync(audio.AudioVolumeType.MEDIA);
      if (max > 0) {
        this.systemVolume = Math.min(1, Math.max(0.15, v / max));
      }
    } catch (e) {
      hilog.warn(0x0000, TAG, `getVolume fallback to default: ${JSON.stringify(e)}`);
      // 使用默认值 0.6
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
    this.cb = null;
  }

  /**
   * 每一个采样 tick：生成 bars 个 [0,1] 的值。
   * - active 为 true：正常钟形波（振幅与系统音量正相关），模拟真实音频律动
   * - active 为 false：极低静默线（几乎为 0）
   *
   * 优化：增加更多频率分量和随机性，让音波看起来更贴近真实 m3u8 音频播放效果
   */
  private tick(): void {
    if (!this.cb) return;
    this.phase += 0.45;

    const N = this.opts.bars;
    const center = (N - 1) / 2;
    const levels: number[] = new Array(N);

    const baseGain = this.active ? 1.0 : 0.05;
    const volumeGain = 0.5 + this.systemVolume * 0.7;

    for (let i = 0; i < N; i++) {
      const x = (i - center) / center;            // -1..1
      const envelope = Math.exp(-x * x * 2.2);    // 中间高两边低（钟形）

      if (this.active) {
        // 多频率叠加：模拟真实音频频谱的动态变化
        const lo = Math.sin(this.phase * 0.6 + i * 0.2) * 0.30;
        const mid = Math.sin(this.phase * 1.3 + i * 0.5) * 0.40;
        const hi = Math.sin(this.phase * 2.1 + i * 0.9) * 0.20;
        const beat = (Math.random() * 0.25 - 0.125);  // 随机微扰模拟节奏
        const v = Math.abs(lo + mid + hi + beat) * envelope * baseGain * volumeGain;
        levels[i] = Math.max(0.08, Math.min(1, 0.15 + v * 1.4));
      } else {
        // 静默状态：极低但不完全为 0，保持微弱呼吸感
        const breath = Math.sin(this.phase * 0.2 + i * 0.3) * 0.02;
        levels[i] = Math.max(0.04, 0.06 + breath) * envelope;
      }
    }
    this.cb(levels, this.active);
  }
}
