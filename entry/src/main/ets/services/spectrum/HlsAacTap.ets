import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { M3u8Parser, PlaylistInfo, Segment } from './M3u8Parser';
import { TsDemuxer } from './TsDemuxer';

const TAG = 'HlsAacTap';

/**
 * HLS 旁路解封装管线
 *
 *   m3u8 轮询 ──► segment 队列 ──► HTTP GET TS ──► TsDemuxer ──► ADTS 帧（Uint8Array）
 *
 * 与 AVPlayer 完全独立：第二份网络拉取，不出声只解封装。
 *
 * 直播策略：
 *   - 启动时只取 playlist 末尾 2 段开始解，避免一上来就追历史
 *   - playlist 每 targetDuration*0.5 秒刷新一次，新的 segment 入队
 *   - 同一 sequence 不重复下载
 *   - 出错连续 3 次 → 上层切到模拟降级
 *
 * 输出的每帧是完整 ADTS 包（含 7 字节 header），交给 NDK 模块去 AAC->PCM->FFT。
 */
export type AdtsFrameSink = (frame: Uint8Array) => void;

interface HttpHeaders {
  Accept: string;
}

export class HlsAacTap {
  private readonly sink: AdtsFrameSink;

  private playlistUrl: string = '';
  private currentPlaylistUrl: string = '';
  private running: boolean = false;
  private active: boolean = false;

  private demuxer: TsDemuxer | null = null;

  private playlistTimer: number = -1;
  private downloadedSeqs: Set<number> = new Set<number>();
  private segmentQueue: Segment[] = [];
  private downloading: boolean = false;
  private consecutiveErrors: number = 0;
  private onFatalError: (() => void) | null = null;

  constructor(sink: AdtsFrameSink) {
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

    this.demuxer = new TsDemuxer((adts: Uint8Array) => this.onAdtsFrame(adts));

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

    for (let i = 0; i < segs.length; i++) {
      const seg = segs[i];
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

  /**
   * ADTS 帧入口：直接转给 sink（NDK 解码器）
   */
  private onAdtsFrame(adts: Uint8Array): void {
    if (!this.active) return;
    this.sink(adts);
  }

  private async httpGetText(url: string): Promise<string> {
    const req = http.createHttp();
    try {
      const headers: HttpHeaders = { Accept: '*/*' };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000,
        header: headers,
        expectDataType: http.HttpDataType.STRING
      };
      const resp = await req.request(url, options);
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      const data = resp.result;
      if (typeof data === 'string') return data;
      if (data instanceof ArrayBuffer) {
        const decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(new Uint8Array(data));
      }
      return `${data}`;
    } finally {
      req.destroy();
    }
  }

  private async httpGetBinary(url: string): Promise<ArrayBuffer> {
    const req = http.createHttp();
    try {
      const headers: HttpHeaders = { Accept: '*/*' };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: 8000,
        readTimeout: 12000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: headers
      };
      const resp = await req.request(url, options);
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
