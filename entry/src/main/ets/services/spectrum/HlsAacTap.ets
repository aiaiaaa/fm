import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { M3u8Parser, PlaylistInfo, Segment } from './M3u8Parser';
import { TsDemuxer } from './TsDemuxer';
import { AacDecoder } from './AacDecoder';
import { PcmFrameSink } from './Types';

const TAG = 'HlsAacTap';

/**
 * HLS 旁路解码管线
 *
 *   m3u8 轮询 ──► segment 队列 ──► HTTP GET TS ──► TsDemuxer ──► AacDecoder ──► PCM
 *
 * 与 AVPlayer 完全独立：第二份网络拉取、第二份解码，不出声只产 PCM。
 *
 * 直播策略：
 *   - 启动时只取 playlist 末尾 2 段开始解，避免一上来就追历史
 *   - playlist 每 targetDuration*0.5 秒刷新一次，新的 segment 入队
 *   - 同一 sequence 不重复下载
 *   - 出错连续 3 次 → 停止上报，让上层切到模拟降级
 */
export class HlsAacTap {
  private readonly sink: PcmFrameSink;

  private playlistUrl: string = '';
  private currentPlaylistUrl: string = '';
  private running: boolean = false;
  private active: boolean = false;

  private demuxer: TsDemuxer | null = null;
  private decoder: AacDecoder | null = null;
  private decoderReady: boolean = false;

  private playlistTimer: number = -1;
  private downloadedSeqs: Set<number> = new Set<number>();
  private segmentQueue: Segment[] = [];
  private downloading: boolean = false;
  private consecutiveErrors: number = 0;
  private onFatalError: (() => void) | null = null;

  // 第一帧 ADTS 用来探测真实采样率/声道
  private decoderInitFromAdts: boolean = false;

  constructor(sink: PcmFrameSink) {
    this.sink = sink;
  }

  setActive(active: boolean): void {
    this.active = active;
  }

  /**
   * 启动管线
   * @param playlistUrl m3u8 URL
   * @param onFatal 出现连续错误时上层切到降级
   */
  async start(playlistUrl: string, onFatal?: () => void): Promise<void> {
    if (this.running) {
      await this.stop();
    }
    this.running = true;
    this.active = true;
    this.playlistUrl = playlistUrl;
    this.currentPlaylistUrl = playlistUrl;
    this.onFatalError = onFatal ?? null;
    this.consecutiveErrors = 0;
    this.downloadedSeqs.clear();
    this.segmentQueue = [];

    this.demuxer = new TsDemuxer((adts) => this.onAdtsFrame(adts));
    this.decoder = new AacDecoder((pcm) => {
      if (this.active) this.sink(pcm);
    });

    // 立即拉一次 playlist；之后定时刷新
    await this.refreshPlaylist();
    this.scheduleNextPlaylistFetch(2000);
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.playlistTimer >= 0) {
      clearTimeout(this.playlistTimer);
      this.playlistTimer = -1;
    }
    this.demuxer?.flush();
    this.demuxer = null;
    if (this.decoder) {
      const d = this.decoder;
      this.decoder = null;
      this.decoderReady = false;
      this.decoderInitFromAdts = false;
      await d.release();
    }
    this.segmentQueue = [];
    this.downloadedSeqs.clear();
  }

  private scheduleNextPlaylistFetch(ms: number): void {
    if (!this.running) return;
    if (this.playlistTimer >= 0) clearTimeout(this.playlistTimer);
    this.playlistTimer = setTimeout(() => {
      this.refreshPlaylist().catch((e: Error) => {
        hilog.warn(0x0000, TAG, `refreshPlaylist err: ${e.message}`);
        this.bumpError();
      });
    }, ms);
  }

  private async refreshPlaylist(): Promise<void> {
    if (!this.running) return;
    let body: string;
    try {
      body = await this.httpGetText(this.currentPlaylistUrl);
    } catch (e) {
      const err = e as Error;
      hilog.warn(0x0000, TAG, `playlist fetch failed: ${err.message}`);
      this.bumpError();
      this.scheduleNextPlaylistFetch(3000);
      return;
    }

    let info: PlaylistInfo;
    try {
      info = M3u8Parser.parse(body, this.currentPlaylistUrl);
    } catch (e) {
      hilog.warn(0x0000, TAG, `parse playlist failed: ${(e as Error).message}`);
      this.bumpError();
      this.scheduleNextPlaylistFetch(3000);
      return;
    }

    // master playlist：换成第一条变种
    if (info.variantUrl) {
      this.currentPlaylistUrl = info.variantUrl;
      this.scheduleNextPlaylistFetch(0);
      return;
    }

    // 首次只取末尾 2 段
    const isFirst = this.downloadedSeqs.size === 0;
    const segs = isFirst ? info.segments.slice(-2) : info.segments;

    for (const seg of segs) {
      if (!this.downloadedSeqs.has(seg.sequence)) {
        this.downloadedSeqs.add(seg.sequence);
        this.segmentQueue.push(seg);
      }
    }

    // 触发下载循环
    this.pumpDownload();

    const nextDelay = Math.max(1500, info.targetDurationSec * 500);
    this.scheduleNextPlaylistFetch(nextDelay);
  }

  private async pumpDownload(): Promise<void> {
    if (this.downloading) return;
    this.downloading = true;
    try {
      while (this.running && this.segmentQueue.length > 0) {
        const seg = this.segmentQueue.shift()!;
        try {
          const bin = await this.httpGetBinary(seg.url);
          if (this.demuxer) {
            this.demuxer.feed(new Uint8Array(bin));
          }
          this.consecutiveErrors = 0;
        } catch (e) {
          hilog.warn(0x0000, TAG, `segment fetch ${seg.sequence} failed: ${(e as Error).message}`);
          this.bumpError();
        }
      }
    } finally {
      this.downloading = false;
    }
  }

  private bumpError(): void {
    this.consecutiveErrors++;
    if (this.consecutiveErrors >= 3 && this.onFatalError) {
      this.onFatalError();
    }
  }

  private onAdtsFrame(adts: Uint8Array): void {
    if (!this.decoder) return;

    if (!this.decoderReady) {
      // 从第一帧 ADTS 头解析采样率/声道，用于初始化解码器
      const parsed = HlsAacTap.parseAdtsHeader(adts);
      if (!parsed) return;
      const dec = this.decoder;
      this.decoderInitFromAdts = true;
      dec.init(parsed.sampleRate, parsed.channels).then((ok: boolean) => {
        this.decoderReady = ok;
        if (!ok) {
          hilog.error(0x0000, TAG, 'AacDecoder init failed, falling back');
          this.onFatalError?.();
          return;
        }
        // init 完成后再喂这一帧
        dec.feed(adts);
      }).catch(() => {
        this.onFatalError?.();
      });
      return;
    }

    this.decoder.feed(adts);
  }

  /**
   * 解析 ADTS 头取采样率 + 声道数
   *   header 7 字节固定（无 CRC）
   *   sampling_frequency_index = bits 18..21
   *   channel_configuration   = bits 23..25
   */
  private static parseAdtsHeader(adts: Uint8Array): { sampleRate: number, channels: number } | null {
    if (adts.length < 7) return null;
    if (adts[0] !== 0xFF || (adts[1] & 0xF0) !== 0xF0) return null;
    const sfIndex = (adts[2] >> 2) & 0x0F;
    const channels = ((adts[2] & 0x01) << 2) | ((adts[3] >> 6) & 0x03);
    const SR_TABLE: number[] = [
      96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
      16000, 12000, 11025, 8000, 7350, 0, 0, 0
    ];
    const sr = SR_TABLE[sfIndex];
    if (sr === 0 || channels === 0) return null;
    return { sampleRate: sr, channels };
  }

  private async httpGetText(url: string): Promise<string> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        header: { 'Accept': '*/*' }
      });
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      const data = resp.result;
      if (typeof data === 'string') return data;
      if (data instanceof ArrayBuffer) {
        return new TextDecoder().decode(new Uint8Array(data));
      }
      return String(data);
    } finally {
      req.destroy();
    }
  }

  private async httpGetBinary(url: string): Promise<ArrayBuffer> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: { 'Accept': '*/*' }
      });
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      if (resp.result instanceof ArrayBuffer) {
        return resp.result;
      }
      throw new Error('response not ArrayBuffer');
    } finally {
      req.destroy();
    }
  }
}
