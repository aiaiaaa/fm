/**
 * 播放模式配置 —— 专注 / 睡眠
 */
export type ModeId = 'focus' | 'sleep';

export interface ModeConfig {
  id: ModeId;
  label: string;
  tag: string;          // 卡片左上角标签
  subtitle: string;
  desc: string;
  accent: string;       // 主题色
  accentSecond: string; // 辅助色（渐变）
  bgFrom: string;       // 卡片背景渐变
  bgTo: string;
  url: string;          // 直播流 / 音频
}

export interface ModesMap {
  focus: ModeConfig;
  sleep: ModeConfig;
}

export const MODES: ModesMap = {
  focus: {
    id: 'focus',
    label: '专注',
    tag: 'AGENT · 新闻资讯',
    subtitle: 'AGENT实时广播',
    desc: '新闻 · 深度 · 文化',
    accent: '#52FFA1',
    accentSecond: '#00D2FF',
    bgFrom: '#0E1726',
    bgTo: '#0A1020',
    url: 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8'
  },
  sleep: {
    id: 'sleep',
    label: '睡眠',
    tag: 'AGENT · 助眠音乐',
    subtitle: '深夜电台',
    desc: '白噪音 · 助眠 · 安静',
    accent: '#8B7CF6',
    accentSecond: '#D6A2FF',
    bgFrom: '#1A1040',
    bgTo: '#0A0820',
    url: 'https://koe.bbg.fm/channels/2/playlist.m3u8'
  }
};
