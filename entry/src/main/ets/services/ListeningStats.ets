import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ListeningStats';
const STORE_NAME = 'listening_stats';

/**
 * 收听时长统计服务
 * 使用 Preferences 持久化存储累计收听时长（秒）
 */
export class ListeningStats {
  private static store: preferences.Preferences | null = null;
  private static timer: number = -1;
  private static currentMode: 'focus' | 'sleep' = 'focus';

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
    } catch (e) {
      hilog.error(0x0000, TAG, `init failed: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 开始计时（每秒累加）
   */
  static startCounting(mode: 'focus' | 'sleep'): void {
    this.stopCounting();
    this.currentMode = mode;
    this.timer = setInterval(() => {
      this.increment(1);
    }, 1000);
  }

  /**
   * 停止计时
   */
  static stopCounting(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private static async increment(seconds: number): Promise<void> {
    if (!this.store) return;
    try {
      const totalKey = 'total_seconds';
      const modeKey = `${this.currentMode}_seconds`;
      const total = await this.store.get(totalKey, 0) as number;
      const modeTotal = await this.store.get(modeKey, 0) as number;
      await this.store.put(totalKey, total + seconds);
      await this.store.put(modeKey, modeTotal + seconds);
      await this.store.flush();
    } catch (e) {
      // 静默失败
    }
  }

  /**
   * 获取统计数据
   */
  static async getStats(): Promise<{ total: number; focus: number; sleep: number }> {
    if (!this.store) {
      return { total: 0, focus: 0, sleep: 0 };
    }
    try {
      const total = await this.store.get('total_seconds', 0) as number;
      const focus = await this.store.get('focus_seconds', 0) as number;
      const sleep = await this.store.get('sleep_seconds', 0) as number;
      return { total, focus, sleep };
    } catch (e) {
      return { total: 0, focus: 0, sleep: 0 };
    }
  }

  /**
   * 格式化秒数为可读字符串
   */
  static formatSeconds(s: number): string {
    if (s < 60) return `${s}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m`;
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return m > 0 ? `${h}h${m}m` : `${h}h`;
  }
}
