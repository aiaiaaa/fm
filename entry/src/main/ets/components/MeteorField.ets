/**
 * 优化版流星场：向右下偏上划过
 * 视觉规格：
 * - 方向：约 30°-45°（左上往右下）
 * - 性能：减少 shadow 重绘频次
 * - 效果：更平滑的尾迹与发光头
 */

interface Meteor {
  x: number;
  y: number;
  vx: number;
  vy: number;
  len: number;
  life: number;
  ttl: number;
  elapsed: number;
  colorMain: string;
  colorTail: string;
  width: number;
  angle: number; // 记录角度用于渲染旋转
}

@Component
export struct MeteorField {
  @Prop accent: string = '#52FFA1';
  @Prop accentSecond: string = '#00D2FF';
  @Prop density: number = 3;

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
    // 角度：30度到45度之间（0度是水平向右，增加角度则向下偏）
    // "向右下偏上" 意味着角度较小，更接近水平
    const angleDeg = 30 + Math.random() * 15;
    const angleRad = angleDeg * Math.PI / 180;

    // 出生点优化：为了向右下划，流星应从左侧边缘或顶部边缘出生
    let startX: number;
    let startY: number;

    if (Math.random() > 0.5) {
      // 顶部出生（偏左侧）
      startX = Math.random() * this.areaW * 0.4 - 50;
      startY = -50;
    } else {
      // 左侧出生（偏上方）
      startX = -50;
      startY = Math.random() * this.areaH * 0.4 - 50;
    }

    const speed = 0.12 + Math.random() * 0.08; // 稍微提升一点速度，增加动感
    const ttl = 2500 + Math.random() * 2500;
    const len = 60 + Math.random() * 40; // 增长尾迹

    this.meteors.push({
      x: startX,
      y: startY,
      vx: Math.cos(angleRad) * speed,
      vy: Math.sin(angleRad) * speed,
      len: len,
      life: 0,
      ttl: ttl,
      elapsed: 0,
      colorMain: this.accent,
      colorTail: this.accent,
      width: 1.2,
      angle: angleRad
    });
  }

  private step(ts: number): void {
    if (!this.running) return;

    const dt = this.lastTs === 0 ? 16 : Math.min(64, ts - this.lastTs);
    this.lastTs = ts;

    this.spawnCooldown -= dt;
    if (this.spawnCooldown <= 0 && this.meteors.length < this.density) {
      this.spawn();
      this.spawnCooldown = 2000 + Math.random() * 3000;
    }

    const ctx = this.context;
    // 使用 clearRect 清除，确保透明背景
    ctx.clearRect(0, 0, this.areaW, this.areaH);

    const next: Meteor[] = [];
    for (const m of this.meteors) {
      m.elapsed += dt;
      m.life = m.elapsed / m.ttl;
      m.x += m.vx * dt;
      m.y += m.vy * dt;

      // 边界检查：出右侧或底部则消失
      if (m.life >= 1 || m.x > this.areaW + m.len || m.y > this.areaH + m.len) {
        continue;
      }

      // 计算尾部坐标
      const tailX = m.x - Math.cos(m.angle) * m.len;
      const tailY = m.y - Math.sin(m.angle) * m.len;

      // 透明度处理
      let alpha = 1;
      if (m.life < 0.15) alpha = m.life / 0.15; // 淡入
      else if (m.life > 0.7) alpha = 1 - (m.life - 0.7) / 0.3; // 淡出

      // 1. 绘制尾迹
      ctx.save();
      const grad = ctx.createLinearGradient(tailX, tailY, m.x, m.y);
      grad.addColorStop(0, this.hexWithAlpha(m.colorTail, 0));
      grad.addColorStop(1, this.hexWithAlpha(m.colorMain, alpha * 0.8));

      ctx.lineWidth = m.width;
      ctx.lineCap = 'round';
      ctx.strokeStyle = grad;
      ctx.beginPath();
      ctx.moveTo(tailX, tailY);
      ctx.lineTo(m.x, m.y);
      ctx.stroke();
      ctx.restore();

      // 2. 绘制头部亮点（双重 Glow 优化）
      ctx.save();
      const headSize = 1.2 + (1 - m.life) * 1.5; // 头部随时间稍微变小

      // 合并 Glow 效果
      ctx.shadowBlur = 12;
      ctx.shadowColor = this.accent;
      ctx.fillStyle = this.hexWithAlpha('#FFFFFF', alpha);
      ctx.beginPath();
      ctx.arc(m.x, m.y, headSize, 0, Math.PI * 2);
      ctx.fill();

      // 叠加第二层偏蓝的光晕
      ctx.shadowBlur = 18;
      ctx.shadowColor = this.accentSecond;
      ctx.beginPath();
      ctx.arc(m.x, m.y, headSize * 0.6, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      next.push(m);
    }
    this.meteors = next;
  }

  // 辅助函数：颜色处理
  private hexWithAlpha(hex: string, alpha: number): string {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
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
    this.step(Date.now());
    // 鸿蒙环境下，建议使用 requestAnimationFrame
    // 若在较低版本中使用，可保留 setTimeout
    setTimeout(() => this.loop(), 30);
  }
}