/**
 * NDK 模块对外接口声明（ArkTS 端使用）
 *
 * 用法：
 *   import spectrum from 'libxfm_spectrum.so';
 *   const handle = spectrum.create((bands: number[]) => { ... });
 *   spectrum.feedAdts(handle, adtsFrame);
 *   spectrum.destroy(handle);
 */

export interface XfmSpectrum {
  /**
   * 创建一个分析器实例。
   * @param onBands 16 频段振幅 [0..1] 回调（在 napi 线程，调用方需负责切回 UI 线程）
   * @returns 实例 handle，传给后续接口
   */
  create(onBands: (bands: number[]) => void): number;

  /**
   * 喂一帧带 ADTS 头的 AAC 数据。
   * @param handle create() 返回值
   * @param frame 完整 ADTS 帧（含 7 字节 header）
   */
  feedAdts(handle: number, frame: Uint8Array): void;

  /**
   * 复位内部状态（暂停/切流时调用）
   */
  reset(handle: number): void;

  /**
   * 释放实例
   */
  destroy(handle: number): void;
}

declare const spectrum: XfmSpectrum;
export default spectrum;
