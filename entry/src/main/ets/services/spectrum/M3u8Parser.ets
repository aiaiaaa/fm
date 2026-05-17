/**
 * 极简 HLS 直播 playlist 解析器
 *
 * 只解析 #EXT-X-MEDIA-SEQUENCE / #EXT-X-TARGETDURATION / #EXTINF + segment URL。
 * 直播无 #EXT-X-ENDLIST；遇到 master playlist 时透传第一条变种 URL 让上层重新拉取。
 */

export interface Segment {
  url: string;       // 绝对 URL
  durationSec: number;
  sequence: number;  // 全局递增，用来去重已下载的分片
}

export interface PlaylistInfo {
  /** master playlist：null 表示不是 master，variantUrl 有值表示要去拉这条变种 */
  variantUrl: string | null;
  segments: Segment[];
  targetDurationSec: number;
  mediaSequence: number;
  endList: boolean; // 直播流恒为 false
}

export class M3u8Parser {
  /**
   * @param body  m3u8 文本
   * @param baseUrl playlist 自身的 URL，用来解析 segment 的相对路径
   */
  static parse(body: string, baseUrl: string): PlaylistInfo {
    const lines = body.split(/\r?\n/).map((l: string) => l.trim()).filter((l: string) => l.length > 0);

    let isMaster = false;
    let variantUrl: string | null = null;
    let mediaSequence = 0;
    let targetDuration = 6;
    let endList = false;
    const segments: Segment[] = [];

    let pendingDuration: number = -1;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.startsWith('#EXT-X-STREAM-INF')) {
        isMaster = true;
        // 紧随其后的非注释行就是变种 URL
        for (let j = i + 1; j < lines.length; j++) {
          if (!lines[j].startsWith('#')) {
            variantUrl = M3u8Parser.resolveUrl(lines[j], baseUrl);
            break;
          }
        }
        continue;
      }
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSequence = parseInt(line.substring('#EXT-X-MEDIA-SEQUENCE:'.length), 10) || 0;
        continue;
      }
      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        targetDuration = parseFloat(line.substring('#EXT-X-TARGETDURATION:'.length)) || 6;
        continue;
      }
      if (line.startsWith('#EXT-X-ENDLIST')) {
        endList = true;
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        // #EXTINF:6.000,title
        const rest = line.substring('#EXTINF:'.length);
        const comma = rest.indexOf(',');
        const numStr = comma >= 0 ? rest.substring(0, comma) : rest;
        pendingDuration = parseFloat(numStr) || 0;
        continue;
      }
      if (line.startsWith('#')) {
        continue;
      }
      // 非注释 = segment URL
      if (pendingDuration > 0) {
        const seg: Segment = {
          url: M3u8Parser.resolveUrl(line, baseUrl),
          durationSec: pendingDuration,
          sequence: mediaSequence + segments.length
        };
        segments.push(seg);
        pendingDuration = -1;
      }
    }

    const result: PlaylistInfo = {
      variantUrl: isMaster ? variantUrl : null,
      segments,
      targetDurationSec: targetDuration,
      mediaSequence,
      endList
    };
    return result;
  }

  /**
   * 把可能是相对路径的 segment URL 转成绝对 URL
   */
  private static resolveUrl(ref: string, baseUrl: string): string {
    if (/^https?:\/\//i.test(ref)) {
      return ref;
    }
    if (ref.startsWith('//')) {
      const colon = baseUrl.indexOf(':');
      const scheme = colon > 0 ? baseUrl.substring(0, colon) : 'https';
      return `${scheme}:${ref}`;
    }
    if (ref.startsWith('/')) {
      // 域名根
      const m = baseUrl.match(/^(https?:\/\/[^/]+)/i);
      return (m ? m[1] : '') + ref;
    }
    // 相对当前 playlist 路径
    const slash = baseUrl.lastIndexOf('/');
    const dir = slash > 0 ? baseUrl.substring(0, slash + 1) : baseUrl + '/';
    return dir + ref;
  }
}
