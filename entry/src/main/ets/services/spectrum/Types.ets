/**
 * 频谱可视化管线的公共类型
 */

export interface PcmFrame {
  /** 单声道，归一化到 [-1, 1] 的浮点采样 */
  samples: Float32Array;
  /** 采样率（Hz） */
  sampleRate: number;
  /** 可选 PTS（毫秒），用于跟 AVPlayer 做对齐 */
  ptsMs?: number;
}

export type PcmFrameSink = (frame: PcmFrame) => void;

export type SpectrumSink = (bands: number[]) => void;
