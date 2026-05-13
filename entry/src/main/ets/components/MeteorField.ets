/**
 * Canvas 版流星场 —— 还原 CSS 设计稿样式
 *
 * CSS 参考规格：
 *   - 流星方向：rotate(-45deg)，即从右上往左下
 *   - 宽度 2rpx，尾迹长度 80rpx
 *   - 颜色渐变：从 rgba(82,255,161,0) → rgba(82,255,161,1)
 *   - 头部白色亮点带 box-shadow: 0 0 16rpx #52FFA1, 0 0 24rpx #00D2FF
 *   - 动画周期 6s，频率大幅降低
 *
 * 优化：
 *   - 降低出生频率（spawnCooldown 增大到 3000~5000ms）
 *   - 同屏最大 3 颗（density 默认降到 3）
 *   - 流星寿命延长到 3000~5000ms 匹配 6s 的视觉节奏
 *   - 角度固定为 -45°（即向右下 45° 滑行，与 CSS rotate(-45deg) 一致）
 */
interface Meteor {
  x: number;
  y: number;
  vx: number;
  vy: number;
  len: number;
  life: number;      // 0..1 归一化生命
  ttl: number;       // 总寿命 ms
  elapsed: number;   // 已消耗 ms
  colorMain: string;
  colorTail: string;
  width: number;
}

@Component
export struct MeteorField {
  @Prop accent: string = '#52FFA1';
  @Prop accentSecond: string = '#00D2FF';
  @Prop density: number = 3;       // 同屏最大流星数（降低频率）

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private meteors: Meteor[] = [];
  private running: boolean = false;
  private lastTs: number = 0;
  private areaW: number = 300;
  private areaH: number = 400;
  private spawnCooldown: number = 0;

  aboutToAppear(): void {
    this.running = true;
  }

  aboutToDisappear(): void {
    this.running = false;
    this.meteors = [];
  }

  private spawn(): void {
    // CSS: position absolute, top: -100rpx → 从画布顶部之上出发
    // CSS: rotate(-45deg) → 从右上向左下运动（角度 135°）
    // 出生点：随机分布在顶部区域偏右侧（让流星从右上入场）
    const startX = this.areaW * 0.3 + Math.random() * this.areaW * 0.7;
    const startY = -40 - Math.random() * 60;

    // 固定 45° 方向：向左下运动（对应 CSS rotate(-45deg) 的视觉效果）
    const angle = 135 * Math.PI / 180;  // 135° = 向左下
    const speed = 0.08 + Math.random() * 0.04;  // 慢速滑行，匹配 6s 周期
    const vx = Math.cos(angle) * speed;
    const vy = Math.sin(angle) * speed;

    // 寿命 3000~5000ms，匹配 6s animation 周期
    const ttl = 3000 + Math.random() * 2000;
    // CSS: height: 80rpx → 尾迹长度约 40px（rpx ≈ 0.5px）
    const len = 36 + Math.random() * 16;

    this.meteors.push({
      x: startX,
      y: startY,
      vx,
      vy,
      len,
      life: 0,
      ttl,
      elapsed: 0,
      colorMain: this.accent,        // #52FFA1
      colorTail: this.accent,        // 渐变尾部同色，透明度渐变
      width: 1                        // CSS: width: 2rpx ≈ 1px
    });
  }

  private step(ts: number): void {
    if (!this.running) return;

    const dt = this.lastTs === 0 ? 16 : Math.min(64, ts - this.lastTs);
    this.lastTs = ts;

    // 出生节流：大幅增大间隔（3000~5000ms），匹配低频出现
    this.spawnCooldown -= dt;
    if (this.spawnCooldown <= 0 && this.meteors.length < this.density) {
      this.spawn();
      this.spawnCooldown = 3000 + Math.random() * 2000;
    }

    const ctx = this.context;
    ctx.clearRect(0, 0, this.areaW, this.areaH);

    // 更新并绘制
    const next: Meteor[] = [];
    for (const m of this.meteors) {
      m.elapsed += dt;
      m.life = m.elapsed / m.ttl;
      m.x += m.vx * dt;
      m.y += m.vy * dt;

      if (m.life >= 1 || m.x < -m.len || m.y > this.areaH + m.len) {
        continue;
      }

      // 尾部点（和运动方向相反）
      const dir = Math.atan2(m.vy, m.vx);
      const tailX = m.x - Math.cos(dir) * m.len;
      const tailY = m.y - Math.sin(dir) * m.len;

      // 淡入淡出：前 10% 淡入，后 25% 淡出（更长的可见时间）
      let alpha = 1;
      if (m.life < 0.10) {
        alpha = m.life / 0.10;
      } else if (m.life > 0.75) {
        alpha = 1 - (m.life - 0.75) / 0.25;
      }
      alpha = Math.max(0, Math.min(1, alpha));

      // CSS 渐变：linear-gradient(to bottom, rgba(82,255,161,0), rgba(82,255,161,1))
      // 尾部透明 → 头部不透明
      const grad = ctx.createLinearGradient(tailX, tailY, m.x, m.y);
      grad.addColorStop(0, this.hexWithAlpha(m.colorTail, 0));          // 尾部完全透明
      grad.addColorStop(0.4, this.hexWithAlpha(m.colorTail, alpha * 0.3));
      grad.addColorStop(1, this.hexWithAlpha(m.colorMain, alpha * 0.9)); // 头部高亮

      ctx.lineWidth = m.width;
      ctx.lineCap = 'round';
      ctx.strokeStyle = grad;
      ctx.beginPath();
      ctx.moveTo(tailX, tailY);
      ctx.lineTo(m.x, m.y);
      ctx.stroke();

      // CSS: 头部白色亮点 + box-shadow: 0 0 16rpx $neon-green, 0 0 24rpx #00D2FF
      ctx.beginPath();
      ctx.fillStyle = this.hexWithAlpha('#FFFFFF', alpha);
      ctx.shadowBlur = 10;
      ctx.shadowColor = this.accent;     // #52FFA1 glow
      ctx.arc(m.x, m.y, 2.5, 0, Math.PI * 2);
      ctx.fill();

      // 第二层 glow（#00D2FF）
      ctx.beginPath();
      ctx.fillStyle = this.hexWithAlpha('#FFFFFF', alpha * 0.6);
      ctx.shadowBlur = 14;
      ctx.shadowColor = this.accentSecond;  // #00D2FF glow
      ctx.arc(m.x, m.y, 1.5, 0, Math.PI * 2);
      ctx.fill();

      ctx.shadowBlur = 0;

      next.push(m);
    }
    this.meteors = next;
  }

  private hexWithAlpha(hex: string, alpha: number): string {
    let r = 255;
    let g = 255;
    let b = 255;
    if (hex.length === 7) {
      r = parseInt(hex.substring(1, 3), 16);
      g = parseInt(hex.substring(3, 5), 16);
      b = parseInt(hex.substring(5, 7), 16);
    } else if (hex.length === 9) {
      // #AARRGGBB
      r = parseInt(hex.substring(3, 5), 16);
      g = parseInt(hex.substring(5, 7), 16);
      b = parseInt(hex.substring(7, 9), 16);
    }
    const a = Math.max(0, Math.min(255, Math.round(alpha * 255)));
    const toHex = (n: number): string => {
      const s = n.toString(16);
      return s.length === 1 ? `0${s}` : s;
    };
    return `#${toHex(r)}${toHex(g)}${toHex(b)}${toHex(a)}`;
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.lastTs = 0;
        this.loop();
      })
      .onAreaChange((_: Area, nv: Area) => {
        this.areaW = Number(nv.width);
        this.areaH = Number(nv.height);
      })
  }

  private loop(): void {
    if (!this.running) return;
    const now = Date.now();
    this.step(now);
    setTimeout(() => this.loop(), 16);
  }
}
