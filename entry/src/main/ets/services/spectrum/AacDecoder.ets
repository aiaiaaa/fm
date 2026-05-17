import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PcmFrame } from './Types';

const TAG = 'AacDecoder';

/**
 * AAC ADTS → PCM 解码器（AVCodecKit 包装）
 *
 * !!! 重要 !!!
 *   HarmonyOS 的 AVCodec 异步解码 API 在不同版本上略有差异：
 *     - 旧版（OpenHarmony 3.x）走 media.createAudioDecoderByMime + on('inputBufferAvailable')
 *     - 新版（HarmonyOS NEXT / API 12+）建议用 @kit.AVCodecKit 的 AudioDecoder
 *   下面这版以 media.createAudioDecoderByMime 为准（NEXT 的 media 模块也兼容）。
 *   如果你的 SDK 报"找不到 createAudioDecoderByMime"，把下方 createDecoder 一行换成
 *   AVCodecKit 的等价 API 即可，其它流程通用。
 *
 * 调用顺序：
 *   1) await init(sampleRate, channelCount, audioObjectType)
 *   2) 持续 feed(adtsFrame)
 *   3) PCM 通过 onPcm 回调输出
 *   4) release()
 */
export type PcmCallback = (frame: PcmFrame) => void;

export class AacDecoder {
  private decoder: media.AudioDecoder | null = null;
  private readonly onPcm: PcmCallback;
  private sampleRate: number = 44100;
  private channelCount: number = 2;
  private inputQueue: Uint8Array[] = [];
  private inputAvailable: number[] = [];
  private released: boolean = false;
  private framePresentationUs: number = 0;

  constructor(onPcm: PcmCallback) {
    this.onPcm = onPcm;
  }

  async init(sampleRate: number, channelCount: number): Promise<boolean> {
    this.sampleRate = sampleRate;
    this.channelCount = channelCount;

    try {
      this.decoder = await media.createAudioDecoderByMime('audio/mp4a-latm');
    } catch (e) {
      hilog.error(0x0000, TAG, `createAudioDecoderByMime failed: ${JSON.stringify(e)}`);
      return false;
    }

    const dec = this.decoder!;

    // 配置参数。键名在 OH 标准里是 string，这里用最常见的几个；
    // 个别 SDK 可能要求 'sample_rate' 这种下划线写法，配置失败时回退一次。
    const baseFormat: Record<string, number | string> = {
      'audio_sample_format': 1,            // SAMPLE_FORMAT_S16LE = 1
      'sample_rate': sampleRate,
      'channel_count': channelCount,
      'audio_aac_is_adts': 1,              // 输入是 ADTS
      'mime': 'audio/mp4a-latm'
    };

    try {
      await dec.configure(baseFormat as Record<string, Object>);
      await dec.prepare();
    } catch (e) {
      hilog.error(0x0000, TAG, `decoder configure/prepare failed: ${JSON.stringify(e)}`);
      return false;
    }

    // 输入 buffer 可用回调
    dec.on('inputBufferAvailable', (buf: media.AudioBuffer) => {
      if (this.released) return;
      const idx = buf.index;
      if (this.inputQueue.length > 0) {
        const frame = this.inputQueue.shift()!;
        this.fillAndQueueInput(idx, frame);
      } else {
        // 暂存 idx，留给下一帧 feed 用
        this.inputAvailable.push(idx);
      }
    });

    // 输出 PCM 回调
    dec.on('outputBufferAvailable', (buf: media.AudioBuffer) => {
      if (this.released) return;
      try {
        const pcm = AacDecoder.bufferToFloat32(buf, this.channelCount);
        if (pcm.length > 0) {
          this.onPcm({
            samples: pcm,
            sampleRate: this.sampleRate,
            ptsMs: buf.timeMs
          });
        }
      } catch (e) {
        hilog.warn(0x0000, TAG, `decode output handle err: ${JSON.stringify(e)}`);
      }
      // 一定要把 output buffer 还回去
      try {
        dec.freeOutputBuffer(buf.index);
      } catch (_e) {
        // ignore
      }
    });

    dec.on('error', (err) => {
      hilog.error(0x0000, TAG, `decoder error: ${JSON.stringify(err)}`);
    });

    try {
      await dec.start();
    } catch (e) {
      hilog.error(0x0000, TAG, `decoder.start failed: ${JSON.stringify(e)}`);
      return false;
    }

    hilog.info(0x0000, TAG, `AacDecoder ready @ ${sampleRate}Hz x${channelCount}`);
    return true;
  }

  feed(adts: Uint8Array): void {
    if (!this.decoder || this.released) return;
    if (this.inputAvailable.length > 0) {
      const idx = this.inputAvailable.shift()!;
      this.fillAndQueueInput(idx, adts);
    } else {
      // 防爆：积压超过 64 帧就丢老帧（直播视觉对积压不敏感）
      if (this.inputQueue.length > 64) {
        this.inputQueue.shift();
      }
      this.inputQueue.push(adts);
    }
  }

  async release(): Promise<void> {
    this.released = true;
    if (this.decoder) {
      try {
        this.decoder.off('inputBufferAvailable');
        this.decoder.off('outputBufferAvailable');
        this.decoder.off('error');
        await this.decoder.stop();
        await this.decoder.release();
      } catch (e) {
        hilog.warn(0x0000, TAG, `release: ${JSON.stringify(e)}`);
      }
      this.decoder = null;
    }
    this.inputQueue = [];
    this.inputAvailable = [];
  }

  private fillAndQueueInput(idx: number, adts: Uint8Array): void {
    if (!this.decoder) return;
    try {
      const dec = this.decoder;
      // OH 的 AudioBuffer 通常通过 getInputBuffer(idx) 拿到 ArrayBuffer，
      // 这里用一个安全包装：先尝试拿底层 buffer，写入数据再 queue。
      const inputBuffer: ArrayBuffer = AacDecoder.getInputArrayBuffer(dec, idx);
      const view = new Uint8Array(inputBuffer);
      view.set(adts);
      const meta: media.AudioBuffer = {
        index: idx,
        size: adts.length,
        offset: 0,
        timeMs: this.framePresentationUs / 1000,
        flags: 0
      } as media.AudioBuffer;
      // AAC 帧时长 = 1024 / sampleRate * 1e6 微秒
      this.framePresentationUs += Math.round(1024 * 1_000_000 / this.sampleRate);
      dec.queueInputBuffer(meta);
    } catch (e) {
      hilog.warn(0x0000, TAG, `fillInput err: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 跨 SDK 适配的输入 buffer 获取：优先 getInputBuffer(idx)，否则尝试同步属性。
   * 真机上以实际 SDK 为准——这是最可能需要在 DevEco 里微调的一行。
   */
  private static getInputArrayBuffer(dec: media.AudioDecoder, idx: number): ArrayBuffer {
    const anyDec = dec as Object as Record<string, Function>;
    if (typeof anyDec['getInputBuffer'] === 'function') {
      return anyDec['getInputBuffer'](idx) as ArrayBuffer;
    }
    throw new Error('decoder has no getInputBuffer(idx); please adapt to AVCodecKit API');
  }

  /**
   * media.AudioBuffer → 单声道 Float32 [-1,1]
   */
  private static bufferToFloat32(buf: media.AudioBuffer, channels: number): Float32Array {
    const anyBuf = buf as Object as Record<string, Object>;
    let raw: ArrayBuffer | null = null;
    if (anyBuf['buffer'] instanceof ArrayBuffer) {
      raw = anyBuf['buffer'] as ArrayBuffer;
    }
    if (!raw) {
      return new Float32Array(0);
    }
    const offset = (typeof anyBuf['offset'] === 'number') ? anyBuf['offset'] as number : 0;
    const size = (typeof anyBuf['size'] === 'number') ? anyBuf['size'] as number : raw.byteLength;
    const i16 = new Int16Array(raw, offset, size >> 1);

    const monoLen = Math.floor(i16.length / channels);
    const out = new Float32Array(monoLen);
    if (channels === 1) {
      for (let i = 0; i < monoLen; i++) {
        out[i] = i16[i] / 32768;
      }
    } else {
      // 多声道下混到单声道
      for (let i = 0; i < monoLen; i++) {
        let sum = 0;
        for (let c = 0; c < channels; c++) {
          sum += i16[i * channels + c];
        }
        out[i] = sum / (channels * 32768);
      }
    }
    return out;
  }
}
