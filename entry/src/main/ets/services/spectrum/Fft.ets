/**
 * Radix-2 Cooley-Tukey FFT，原地变换。
 *
 * 实现要点：
 *   - 预先计算位反转表 + 旋转因子（cos/sin）
 *   - 输入复数对（re[], im[]）原地输出
 *   - size 必须是 2 的幂
 *
 * 1024 点 FFT 在 ArkTS 上每帧 ~2-4ms（千元机），完全够用。
 */
export class Fft {
  private readonly size: number;
  private readonly logSize: number;
  private readonly cosTable: Float32Array;
  private readonly sinTable: Float32Array;
  private readonly bitReverse: Uint32Array;

  constructor(size: number) {
    if ((size & (size - 1)) !== 0 || size < 2) {
      throw new Error(`Fft size must be a power of 2, got ${size}`);
    }
    this.size = size;
    this.logSize = Math.round(Math.log2(size));

    const half = size >> 1;
    this.cosTable = new Float32Array(half);
    this.sinTable = new Float32Array(half);
    for (let i = 0; i < half; i++) {
      const angle = -2 * Math.PI * i / size;
      this.cosTable[i] = Math.cos(angle);
      this.sinTable[i] = Math.sin(angle);
    }

    this.bitReverse = new Uint32Array(size);
    for (let i = 0; i < size; i++) {
      let r = 0;
      let v = i;
      for (let j = 0; j < this.logSize; j++) {
        r = (r << 1) | (v & 1);
        v >>= 1;
      }
      this.bitReverse[i] = r;
    }
  }

  getSize(): number {
    return this.size;
  }

  /**
   * 原地 FFT。
   * 输入：re[]（实部）、im[]（虚部，纯实信号则全 0）
   * 输出：覆盖 re[]、im[] 为复数频域结果
   */
  forward(re: Float32Array, im: Float32Array): void {
    const n = this.size;

    // 1) 位反转排列
    for (let i = 0; i < n; i++) {
      const j = this.bitReverse[i];
      if (j > i) {
        let t = re[i]; re[i] = re[j]; re[j] = t;
        t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }

    // 2) 蝶形运算
    for (let s = 1; s <= this.logSize; s++) {
      const m = 1 << s;
      const halfM = m >> 1;
      const step = n / m;
      for (let k = 0; k < n; k += m) {
        for (let j = 0; j < halfM; j++) {
          const tIdx = j * step;
          const cos = this.cosTable[tIdx];
          const sin = this.sinTable[tIdx];
          const ar = re[k + j + halfM];
          const ai = im[k + j + halfM];
          const tr = ar * cos - ai * sin;
          const ti = ar * sin + ai * cos;
          re[k + j + halfM] = re[k + j] - tr;
          im[k + j + halfM] = im[k + j] - ti;
          re[k + j] = re[k + j] + tr;
          im[k + j] = im[k + j] + ti;
        }
      }
    }
  }
}
