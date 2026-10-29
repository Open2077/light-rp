import type { RoadData } from "./data";

// The holographic GPS: an overlay rising from the bottom of the view while a route runs.
// Drawn in 2D with a 3D perspective, as seen from just behind and above the player: the
// roads around (thin, fading with distance), the route as a wide ribbon of chevrons
// flowing toward the destination, the player's arrow and a beam on the destination.
// Every segment is clipped just behind the arrow and far ahead, so nothing behind the
// virtual camera can project across the view.

export interface HoloRoute {
  pts: number[]; // x, y, z triples (game metres) from just behind the player onward
  s0?: number; // route distance of the first point: keeps the chevrons' phase steady
  dest?: { x: number; y: number; z?: number };
  clear?: boolean;
}

interface Pose { x: number; y: number; z: number; yaw: number }

const CAM_BACK = 30; // metres behind the player
const CAM_HEIGHT = 22; // metres above
const NEAR = -4; // drawn from 4 m behind the player
const FAR = 380; // to 380 m ahead
const SIDE = 240; // and 240 m to either side
const LEVEL = 18; // roads further above or below than this belong to another level
const CELL = 100;

export class HoloGps {
  readonly el: HTMLElement;
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private route: HoloRoute | null = null;
  private target: Pose | null = null;
  private pose: Pose | null = null;
  private last = 0;
  private accent = "#ffcc00";
  private roads: RoadData | null = null;
  private cells = new Map<number, number[]>();

  constructor(parent: HTMLElement) {
    this.el = document.createElement("section");
    this.el.className = "m3-holo";
    this.el.innerHTML = `<canvas class="m3-holo__view"></canvas>`;
    parent.appendChild(this.el);
    this.canvas = this.el.querySelector("canvas")!;
    this.ctx = this.canvas.getContext("2d")!;
    requestAnimationFrame(this.frame);
  }

  setAccent(color: string): void { this.accent = color; }

  /** The road network, bucketed in a 100 m grid of lanes. */
  setRoads(roads: RoadData): void {
    this.roads = roads;
    this.cells.clear();
    const P = roads.points;
    for (let lane = 0; lane < roads.laneOffset.length; lane++) {
      const o = roads.laneOffset[lane], n = roads.laneCount[lane];
      let lastKey = NaN;
      for (let k = 0; k < n; k++) {
        const key = cellKey(Math.floor(P[(o + k) * 3] / CELL), Math.floor(P[(o + k) * 3 + 1] / CELL));
        if (key === lastKey) continue;
        lastKey = key;
        let list = this.cells.get(key);
        if (!list) this.cells.set(key, (list = []));
        if (list[list.length - 1] !== lane) list.push(lane);
      }
    }
  }

  setRoute(r: HoloRoute | null): void {
    this.route = r && !r.clear && r.pts.length >= 6 ? r : null;
    this.el.classList.toggle("is-on", !!this.route);
  }

  /** The player's position and the direction the view looks (game yaw, degrees). */
  setPose(x: number, y: number, yaw: number, z = this.target?.z ?? 0): void { this.target = { x, y, z, yaw }; }

  private frame = (now: number): void => {
    requestAnimationFrame(this.frame);
    if (!this.route || !this.target) return;
    const dt = this.last ? Math.min(0.1, (now - this.last) / 1000) : 0;
    this.last = now;
    // glide between the 30 Hz pose updates
    const t = this.target;
    if (!this.pose) this.pose = { ...t };
    const p = this.pose, k = 1 - Math.exp(-dt * 12);
    p.x += (t.x - p.x) * k; p.y += (t.y - p.y) * k; p.z += (t.z - p.z) * (1 - Math.exp(-dt * 6));
    p.yaw += ((((t.yaw - p.yaw) % 360) + 540) % 360 - 180) * (1 - Math.exp(-dt * 9));
    this.draw(now / 1000);
  };

  private draw(time: number): void {
    const c = this.canvas, dpr = Math.min(2, window.devicePixelRatio || 1);
    const W = c.clientWidth, H = c.clientHeight;
    if (!W || !H) return;
    if (c.width !== Math.round(W * dpr) || c.height !== Math.round(H * dpr)) { c.width = Math.round(W * dpr); c.height = Math.round(H * dpr); }
    const g = this.ctx;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    const pose = this.pose!, a = (pose.yaw * Math.PI) / 180;
    // game yaw 0 faces +Y and turns counter-clockwise: forward and right in the plane
    const fx = -Math.sin(a), fy = Math.cos(a), rx = Math.cos(a), ry = Math.sin(a);
    const focal = H * 1.15, horizon = H * 0.08, cx = W / 2;
    const local = (x: number, y: number): [number, number] => {
      const dx = x - pose.x, dy = y - pose.y;
      return [dx * rx + dy * ry, dx * fx + dy * fy];
    };
    const project = (lx: number, ly: number): [number, number, number] => {
      const z = ly + CAM_BACK;
      return [cx + (lx / z) * focal, horizon + (CAM_HEIGHT / z) * focal, z];
    };
    // a segment cut to the visible band [NEAR, FAR]; null when nothing of it is in view
    const clip = (p0: [number, number], p1: [number, number]): [[number, number], [number, number]] | null => {
      let a0 = p0, a1 = p1;
      if (a0[1] < NEAR && a1[1] < NEAR) return null;
      if (a0[1] > FAR && a1[1] > FAR) return null;
      const cut = (u: [number, number], v: [number, number], ly: number): [number, number] => {
        const f = (ly - u[1]) / (v[1] - u[1]);
        return [u[0] + (v[0] - u[0]) * f, ly];
      };
      if (a0[1] < NEAR) a0 = cut(a0, a1, NEAR); else if (a1[1] < NEAR) a1 = cut(a1, a0, NEAR);
      if (a0[1] > FAR) a0 = cut(a0, a1, FAR); else if (a1[1] > FAR) a1 = cut(a1, a0, FAR);
      if (Math.abs(a0[0]) > SIDE && Math.abs(a1[0]) > SIDE && Math.sign(a0[0]) === Math.sign(a1[0])) return null;
      return [a0, a1];
    };
    // widths keep a mild perspective: the same road reads alike ahead and across the view
    const scale = (z: number) => 0.5 + 0.5 * Math.min(1, CAM_BACK / Math.max(1, z));
    const accent = this.accent;
    g.lineCap = "round"; g.lineJoin = "round";

    // the roads around, on the player's level, in three distance bands
    if (this.roads) {
      const P = this.roads.points, seen = new Set<number>();
      const bands: Path2D[] = [new Path2D(), new Path2D(), new Path2D()];
      const ccx = Math.floor(pose.x / CELL), ccy = Math.floor(pose.y / CELL), reach = 4;
      for (let gx = ccx - reach; gx <= ccx + reach; gx++) for (let gy = ccy - reach; gy <= ccy + reach; gy++) {
        for (const lane of this.cells.get(cellKey(gx, gy)) ?? []) {
          if (seen.has(lane)) continue;
          seen.add(lane);
          const o = this.roads.laneOffset[lane], n = this.roads.laneCount[lane];
          let prev: [number, number] | null = null, prevZ = 0;
          for (let k = 0; k < n; k++) {
            const i = (o + k) * 3, l = local(P[i], P[i + 1]), z = P[i + 2];
            if (prev && Math.abs(z - pose.z) < LEVEL && Math.abs(prevZ - pose.z) < LEVEL) {
              const s = clip(prev, l);
              if (s) {
                const d = Math.hypot((s[0][0] + s[1][0]) / 2, (s[0][1] + s[1][1]) / 2);
                const band = d < 110 ? 0 : d < 220 ? 1 : 2;
                const q0 = project(s[0][0], s[0][1]), q1 = project(s[1][0], s[1][1]);
                bands[band].moveTo(q0[0], q0[1]); bands[band].lineTo(q1[0], q1[1]);
              }
            }
            prev = l; prevZ = z;
          }
        }
      }
      g.lineWidth = 2;
      [0.42, 0.26, 0.12].forEach((alpha, i) => { g.strokeStyle = withAlpha(accent, alpha); g.stroke(bands[i]); });
    }

    // the route, from just behind the arrow
    const pts = this.route!.pts, segs: { q0: [number, number, number]; q1: [number, number, number]; d0: number; d1: number }[] = [];
    let along = this.route!.s0 ?? 0;
    for (let i = 0; i + 5 < pts.length; i += 3) {
      const p0 = local(pts[i], pts[i + 1]), p1 = local(pts[i + 3], pts[i + 4]);
      const len = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]);
      const s = clip(p0, p1);
      if (s && len > 0) {
        // route distances of the clipped ends, for the chevrons
        const f0 = Math.hypot(s[0][0] - p0[0], s[0][1] - p0[1]) / len, f1 = Math.hypot(s[1][0] - p0[0], s[1][1] - p0[1]) / len;
        segs.push({ q0: project(s[0][0], s[0][1]), q1: project(s[1][0], s[1][1]), d0: along + len * f0, d1: along + len * f1 });
      }
      along += len;
    }
    // the translucent halo passes in one path each (overlapping segments would darken
    // every joint), the bright core per segment so it keeps the perspective
    const path = new Path2D();
    let open = false, mid = CAM_BACK;
    segs.forEach((sg, i) => {
      const joined = i > 0 && Math.hypot(sg.q0[0] - segs[i - 1].q1[0], sg.q0[1] - segs[i - 1].q1[1]) < 0.5;
      if (!open || !joined) path.moveTo(sg.q0[0], sg.q0[1]);
      path.lineTo(sg.q1[0], sg.q1[1]);
      open = true;
    });
    if (segs.length) mid = segs[Math.min(segs.length - 1, 2)].q0[2];
    for (const [width, alpha] of [[30, 0.16], [16, 0.4]] as const) {
      g.strokeStyle = withAlpha(accent, alpha);
      g.lineWidth = width * scale(mid);
      g.stroke(path);
    }
    g.strokeStyle = withAlpha(accent, 0.95);
    g.shadowColor = accent; g.shadowBlur = 8;
    for (const sg of segs) {
      g.lineWidth = Math.max(1, 7 * scale(sg.q0[2]));
      g.beginPath(); g.moveTo(sg.q0[0], sg.q0[1]); g.lineTo(sg.q1[0], sg.q1[1]); g.stroke();
    }
    g.shadowBlur = 0;
    // chevrons flowing toward the destination, at fixed route distances (no jumping)
    const spacing = 14, shift = (time * 18) % spacing;
    g.fillStyle = "rgba(255, 255, 255, 0.9)";
    for (const sg of segs) {
      const span = sg.d1 - sg.d0;
      if (span <= 0) continue;
      const ang = Math.atan2(sg.q1[1] - sg.q0[1], sg.q1[0] - sg.q0[0]);
      for (let s = Math.ceil((sg.d0 - shift) / spacing) * spacing + shift; s < sg.d1; s += spacing) {
        const f = (s - sg.d0) / span;
        const x = sg.q0[0] + (sg.q1[0] - sg.q0[0]) * f, y = sg.q0[1] + (sg.q1[1] - sg.q0[1]) * f;
        const size = 5.5 * scale(sg.q0[2] + (sg.q1[2] - sg.q0[2]) * f);
        g.save(); g.translate(x, y); g.rotate(ang);
        g.beginPath(); g.moveTo(size, 0); g.lineTo(-size, -size * 0.9); g.lineTo(-size * 0.4, 0); g.lineTo(-size, size * 0.9); g.closePath(); g.fill();
        g.restore();
      }
    }
    // a beam on the destination when it is in view
    const dest = this.route!.dest;
    if (dest) {
      const l = local(dest.x, dest.y);
      if (l[1] > NEAR && l[1] < FAR && Math.abs(l[0]) < SIDE) {
        const [x, y, z] = project(l[0], l[1]), h = Math.min(90, (60 * CAM_BACK) / z);
        const grad = g.createLinearGradient(x, y - h, x, y);
        grad.addColorStop(0, withAlpha(accent, 0)); grad.addColorStop(1, withAlpha(accent, 0.85));
        g.fillStyle = grad; g.fillRect(x - 2, y - h, 4, h);
      }
    }
    // the player
    const [px, py] = project(0, 0);
    g.fillStyle = "#ffffff"; g.shadowColor = accent; g.shadowBlur = 14;
    g.beginPath(); g.moveTo(px, py - 15); g.lineTo(px + 11, py + 9); g.lineTo(px, py + 4); g.lineTo(px - 11, py + 9); g.closePath(); g.fill();
    g.shadowBlur = 0;
  }
}

function cellKey(x: number, y: number): number { return (x + 2048) * 4096 + (y + 2048); }

function withAlpha(color: string, alpha: number): string {
  const m = /^#([0-9a-f]{6})$/i.exec(color.trim());
  if (!m) return color;
  const n = parseInt(m[1], 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}
