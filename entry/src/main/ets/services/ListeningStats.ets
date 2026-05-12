import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ListeningStats';
const STORE_NAME = 'listening_stats';

// 模块级变量（ArkTS不允许static方法中使用this）
let store: preferences.Preferences | null = null;
let timer: number = -1;
let currentMode: 'focus' | 'sleep' = 'focus';

export interface StatsData {
  total: number;
  focus: number;
  sleep: number;
}

/**
 * 收听时长统计服务
 * 使用 Preferences 持久化存储累计收听时长（秒）
 */
export class ListeningStats {

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      store = await preferences.getPreferences(context, STORE_NAME);
    } catch (e) {
      hilog.error(0x0000, TAG, `init failed: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 开始计时（每秒累加）
   */
  static startCounting(mode: 'focus' | 'sleep'): void {
    ListeningStats.stopCounting();
    currentMode = mode;
    timer = setInterval(() => {
      ListeningStats.increment(1);
    }, 1000);
  }

  /**
   * 停止计时
   */
  static stopCounting(): void {
    if (timer >= 0) {
      clearInterval(timer);
      timer = -1;
    }
  }

  private static async increment(seconds: number): Promise<void> {
    if (!store) return;
    try {
      const totalKey = 'total_seconds';
      const modeKey = `${currentMode}_seconds`;
      const total = await store.get(totalKey, 0) as number;
      const modeTotal = await store.get(modeKey, 0) as number;
      await store.put(totalKey, total + seconds);
      await store.put(modeKey, modeTotal + seconds);
      await store.flush();
    } catch (e) {
      // 静默失败
    }
  }

  /**
   * 获取统计数据
   */
  static async getStats(): Promise<StatsData> {
    const empty: StatsData = { total: 0, focus: 0, sleep: 0 };
    if (!store) {
      return empty;
    }
    try {
      const total = await store.get('total_seconds', 0) as number;
      const focus = await store.get('focus_seconds', 0) as number;
      const sleep = await store.get('sleep_seconds', 0) as number;
      const result: StatsData = { total, focus, sleep };
      return result;
    } catch (e) {
      return empty;
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
