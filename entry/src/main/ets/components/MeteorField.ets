/**
 * Canvas 版流星场 —— 替代原先用 animateTo 叠位移实现的 Meteor。
 *
 * 特性：
 *   - 使用 RenderingContext 每帧重绘，支持真正平滑的渐变尾迹
 *   - 每颗流星生命周期独立（随机出生点、速度、长度、颜色）
 *   - 自适应父容器尺寸（onAreaChange）
 *   - 低性能占用：~60fps 但每帧只做少量绘制
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
  @Prop accent: string = '#2EE89D';
  @Prop accentSecond: string = '#9FFFD8';
  @Prop density: number = 5;       // 同屏最大流星数

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
    // 从左上区域出生，向右下偏上方向滑动（更自然的流星轨迹）
    const startX = -20 + Math.random() * this.areaW * 0.4;
    const startY = -20 + Math.random() * this.areaH * 0.25;
    const speed = 0.15 + Math.random() * 0.10;      // 像素/ms（略慢更自然）
    // 角度 20°~45°：右下偏上方向滑行
    const angle = (20 + Math.random() * 25) * Math.PI / 180;
    const vx = Math.cos(angle) * speed;
    const vy = Math.sin(angle) * speed;
    const ttl = 1400 + Math.random() * 1200;
    const len = 60 + Math.random() * 80;
    const useSecond = Math.random() < 0.4;
    this.meteors.push({
      x: startX,
      y: startY,
      vx,
      vy,
      len,
      life: 0,
      ttl,
      elapsed: 0,
      colorMain: useSecond ? this.accentSecond : this.accent,
      colorTail: useSecond ? this.accentSecond : this.accent,
      width: 1.2 + Math.random() * 0.8
    });
  }

  private step(ts: number): void {
    if (!this.running) return;

    const dt = this.lastTs === 0 ? 16 : Math.min(64, ts - this.lastTs);
    this.lastTs = ts;

    // 出生节流
    this.spawnCooldown -= dt;
    if (this.spawnCooldown <= 0 && this.meteors.length < this.density) {
      this.spawn();
      this.spawnCooldown = 600 + Math.random() * 800;
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

      if (m.life >= 1 || m.x > this.areaW + m.len || m.y > this.areaH + m.len) {
        continue;
      }

      // 尾部点（和运动方向相反）
      const dir = Math.atan2(m.vy, m.vx);
      const tailX = m.x - Math.cos(dir) * m.len;
      const tailY = m.y - Math.sin(dir) * m.len;

      // 淡入淡出：前 15% 淡入，后 30% 淡出
      let alpha = 1;
      if (m.life < 0.15) {
        alpha = m.life / 0.15;
      } else if (m.life > 0.7) {
        alpha = 1 - (m.life - 0.7) / 0.3;
      }
      alpha = Math.max(0, Math.min(1, alpha));

      // 线条尾巴：渐变从透明 → 主色
      const grad = ctx.createLinearGradient(tailX, tailY, m.x, m.y);
      grad.addColorStop(0, '#00000000');
      grad.addColorStop(0.6, this.hexWithAlpha(m.colorTail, alpha * 0.55));
      grad.addColorStop(1, this.hexWithAlpha(m.colorMain, alpha));

      ctx.lineWidth = m.width;
      ctx.lineCap = 'round';
      ctx.strokeStyle = grad;
      ctx.beginPath();
      ctx.moveTo(tailX, tailY);
      ctx.lineTo(m.x, m.y);
      ctx.stroke();

      // 头部亮点
      ctx.beginPath();
      ctx.fillStyle = this.hexWithAlpha('#FFFFFF', alpha);
      ctx.shadowBlur = 8;
      ctx.shadowColor = m.colorMain;
      ctx.arc(m.x, m.y, m.width * 1.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;

      next.push(m);
    }
    this.meteors = next;
  }

  private hexWithAlpha(hex: string, alpha: number): string {
    // 支持 #RRGGBB 或 #AARRGGBB（鸿蒙风格），统一转为 #RRGGBBAA
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
        // 初次渲染
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
    // 下一帧
    setTimeout(() => this.loop(), 16);
  }
}
