/**
 * 极简 MPEG-TS demuxer：从 188 字节包里抽出 AAC ADTS 帧。
 *
 * 这里只支持最常见的直播音频 TS：
 *   - 单一 PMT（PID 在 PAT 里查出来）
 *   - 单一音频轨（stream_type = 0x0F = ADTS AAC，或 0x11 = LATM AAC，本实现只对 0x0F 生效）
 *   - PES payload 已经是 ADTS 帧序列（每帧带 0xFFF sync word + 头）
 *
 * 不实现：CRC 校验、加密 TS、多 program、视频流过滤后的二次 demux。
 *
 * 输出方式：feed(chunk) 喂 chunk，回调返回切好的 ADTS 帧（含完整 ADTS header）。
 */

const TS_PACKET_SIZE = 188;
const SYNC_BYTE = 0x47;

export type AdtsFrameSink = (frame: Uint8Array) => void;

export class TsDemuxer {
  private readonly onFrame: AdtsFrameSink;

  // 跨 chunk 的残余（凑够 188 字节为止）
  private leftover: Uint8Array = new Uint8Array(0);

  // PAT/PMT
  private pmtPid: number = -1;
  private audioPid: number = -1;
  private audioStreamType: number = -1;

  // PES 累积（一个 PES 可以横跨多个 TS 包）
  private pesBuffer: Uint8Array = new Uint8Array(0);
  private pesActive: boolean = false;

  constructor(sink: AdtsFrameSink) {
    this.onFrame = sink;
  }

  reset(): void {
    this.leftover = new Uint8Array(0);
    this.pmtPid = -1;
    this.audioPid = -1;
    this.audioStreamType = -1;
    this.pesBuffer = new Uint8Array(0);
    this.pesActive = false;
  }

  /**
   * 喂入任意大小的二进制。内部按 188 字节切包后再处理。
   */
  feed(chunk: Uint8Array): void {
    let buf: Uint8Array;
    if (this.leftover.length === 0) {
      buf = chunk;
    } else {
      buf = new Uint8Array(this.leftover.length + chunk.length);
      buf.set(this.leftover, 0);
      buf.set(chunk, this.leftover.length);
    }

    // 寻找首个 sync byte
    let i = 0;
    while (i < buf.length && buf[i] !== SYNC_BYTE) {
      i++;
    }
    if (i > 0) {
      buf = buf.subarray(i);
    }

    let off = 0;
    while (off + TS_PACKET_SIZE <= buf.length) {
      if (buf[off] !== SYNC_BYTE) {
        // 同步丢失，重新找 sync byte
        let k = off + 1;
        while (k < buf.length && buf[k] !== SYNC_BYTE) {
          k++;
        }
        off = k;
        continue;
      }
      this.handlePacket(buf.subarray(off, off + TS_PACKET_SIZE));
      off += TS_PACKET_SIZE;
    }
    this.leftover = buf.subarray(off);
  }

  /**
   * 直播切片末尾要把当前 PES flush 出去
   */
  flush(): void {
    if (this.pesActive && this.pesBuffer.length > 0) {
      this.parsePes(this.pesBuffer);
    }
    this.pesBuffer = new Uint8Array(0);
    this.pesActive = false;
  }

  private handlePacket(pkt: Uint8Array): void {
    // 头部 4 字节
    // bit 23 = payload_unit_start_indicator
    const payloadStart = (pkt[1] & 0x40) !== 0;
    const pid = ((pkt[1] & 0x1F) << 8) | pkt[2];
    const adaptationFieldControl = (pkt[3] >> 4) & 0x3;

    let payloadOffset = 4;
    if ((adaptationFieldControl & 0x2) !== 0) {
      // 有 adaptation field
      const afLen = pkt[4];
      payloadOffset = 5 + afLen;
    }
    if ((adaptationFieldControl & 0x1) === 0) {
      return; // 没 payload
    }
    if (payloadOffset >= TS_PACKET_SIZE) {
      return;
    }
    const payload = pkt.subarray(payloadOffset);

    if (pid === 0x0000) {
      this.parsePat(payload, payloadStart);
      return;
    }
    if (this.pmtPid >= 0 && pid === this.pmtPid) {
      this.parsePmt(payload, payloadStart);
      return;
    }
    if (this.audioPid >= 0 && pid === this.audioPid) {
      this.collectPes(payload, payloadStart);
      return;
    }
  }

  private parsePat(payload: Uint8Array, payloadStart: boolean): void {
    let off = 0;
    if (payloadStart) {
      const pointer = payload[0];
      off = 1 + pointer;
    }
    if (off + 12 > payload.length) {
      return;
    }
    // table_id = 0x00, section length 在 [off+1..off+2] 低 12 位
    const sectionLen = ((payload[off + 1] & 0x0F) << 8) | payload[off + 2];
    // PAT 数据从 off+8 开始，到 off+3+sectionLen-4（去掉 CRC）
    const dataStart = off + 8;
    const dataEnd = off + 3 + sectionLen - 4;
    for (let p = dataStart; p + 4 <= dataEnd; p += 4) {
      const programNumber = (payload[p] << 8) | payload[p + 1];
      const pid = ((payload[p + 2] & 0x1F) << 8) | payload[p + 3];
      if (programNumber !== 0) {
        this.pmtPid = pid;
        return;
      }
    }
  }

  private parsePmt(payload: Uint8Array, payloadStart: boolean): void {
    let off = 0;
    if (payloadStart) {
      const pointer = payload[0];
      off = 1 + pointer;
    }
    if (off + 12 > payload.length) {
      return;
    }
    const sectionLen = ((payload[off + 1] & 0x0F) << 8) | payload[off + 2];
    const sectionEnd = off + 3 + sectionLen - 4;

    const programInfoLen = ((payload[off + 10] & 0x0F) << 8) | payload[off + 11];
    let p = off + 12 + programInfoLen;

    while (p + 5 <= sectionEnd) {
      const streamType = payload[p];
      const elementaryPid = ((payload[p + 1] & 0x1F) << 8) | payload[p + 2];
      const esInfoLen = ((payload[p + 3] & 0x0F) << 8) | payload[p + 4];

      // 0x0F = AAC ADTS, 0x11 = AAC LATM
      if (streamType === 0x0F || streamType === 0x11) {
        this.audioPid = elementaryPid;
        this.audioStreamType = streamType;
      }
      p += 5 + esInfoLen;
    }
  }

  private collectPes(payload: Uint8Array, payloadStart: boolean): void {
    if (payloadStart) {
      // 上一个 PES 完成
      if (this.pesActive && this.pesBuffer.length > 0) {
        this.parsePes(this.pesBuffer);
      }
      this.pesBuffer = new Uint8Array(payload);
      this.pesActive = true;
    } else if (this.pesActive) {
      const next = new Uint8Array(this.pesBuffer.length + payload.length);
      next.set(this.pesBuffer, 0);
      next.set(payload, this.pesBuffer.length);
      this.pesBuffer = next;
    }
  }

  /**
   * 从 PES 包里剥离 header，剩余字节按 ADTS 帧切分（仅 stream_type 0x0F 真正可用）
   */
  private parsePes(pes: Uint8Array): void {
    if (pes.length < 9) return;
    if (pes[0] !== 0x00 || pes[1] !== 0x00 || pes[2] !== 0x01) {
      return; // 不是合法 PES start code
    }
    const pesHeaderDataLen = pes[8];
    const dataOffset = 9 + pesHeaderDataLen;
    if (dataOffset >= pes.length) return;

    const data = pes.subarray(dataOffset);
    if (this.audioStreamType === 0x0F) {
      this.splitAdts(data);
    }
    // LATM (0x11) 暂不处理，留 TODO
  }

  /**
   * 按 ADTS sync word (0xFFF) 切帧，回调输出
   */
  private splitAdts(data: Uint8Array): void {
    let i = 0;
    while (i + 7 <= data.length) {
      // sync word: 12 bits = 0xFFF
      if (data[i] !== 0xFF || (data[i + 1] & 0xF0) !== 0xF0) {
        i++;
        continue;
      }
      // frame_length: 13 bits, in [3..5]
      const frameLen =
        ((data[i + 3] & 0x03) << 11) |
        (data[i + 4] << 3) |
        ((data[i + 5] & 0xE0) >> 5);
      if (frameLen < 7 || i + frameLen > data.length) {
        // 不完整，等下个 chunk
        break;
      }
      this.onFrame(data.subarray(i, i + frameLen));
      i += frameLen;
    }
  }
}
