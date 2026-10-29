import type { RoadData } from "./data";
import type { GamePos } from "./coords";

// GPS on the game's own traffic network: every node is a one-way vehicle lane
// (worldTrafficLanePersistent), every edge one of its out-links. A* on travel time,
// from the lane under the start to the lane under the destination.

export interface Snap { lane: number; seg: number; t: number; x: number; y: number; z: number; dist: number; along: number }
export interface Maneuver { kind: "start" | "left" | "right" | "slight-left" | "slight-right" | "sharp-left" | "sharp-right" | "uturn" | "straight" | "arrive"; at: number; x: number; y: number }
export interface Route {
  points: Float32Array; // game x, y, z
  cumulative: Float32Array; // metres along the route at each point
  length: number;
  seconds: number;
  maneuvers: Maneuver[];
  lanes: number[];
  destination: GamePos;
}

const CELL = 64;
const HIGHWAY = 16384;

class MinHeap {
  private k: number[] = [];
  private v: number[] = [];
  get size() { return this.k.length; }
  push(key: number, value: number) {
    const k = this.k, v = this.v;
    k.push(key); v.push(value);
    let i = k.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (k[p] <= k[i]) break;
      [k[p], k[i]] = [k[i], k[p]]; [v[p], v[i]] = [v[i], v[p]];
      i = p;
    }
  }
  pop(): number {
    const k = this.k, v = this.v;
    const top = v[0];
    const lk = k.pop()!, lv = v.pop()!;
    if (k.length) {
      k[0] = lk; v[0] = lv;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        if (l < k.length && k[l] < k[m]) m = l;
        if (r < k.length && k[r] < k[m]) m = r;
        if (m === i) break;
        [k[m], k[i]] = [k[i], k[m]]; [v[m], v[i]] = [v[i], v[m]];
        i = m;
      }
    }
    return top;
  }
}

export class RoadGraph {
  private grid = new Map<number, number[]>(); // cell -> [lane, seg, lane, seg, ...]
  private laneEnd: Float32Array; // x, y of each lane's last point
  readonly lanes: number;

  constructor(readonly d: RoadData) {
    this.lanes = d.laneOffset.length;
    this.laneEnd = new Float32Array(this.lanes * 2);
    const P = d.points;
    for (let l = 0; l < this.lanes; l++) {
      const o = d.laneOffset[l], n = d.laneCount[l];
      this.laneEnd[l * 2] = P[(o + n - 1) * 3];
      this.laneEnd[l * 2 + 1] = P[(o + n - 1) * 3 + 1];
      for (let s = 0; s < n - 1; s++) {
        const ax = P[(o + s) * 3], ay = P[(o + s) * 3 + 1], bx = P[(o + s + 1) * 3], by = P[(o + s + 1) * 3 + 1];
        const x0 = Math.floor(Math.min(ax, bx) / CELL), x1 = Math.floor(Math.max(ax, bx) / CELL);
        const y0 = Math.floor(Math.min(ay, by) / CELL), y1 = Math.floor(Math.max(ay, by) / CELL);
        for (let cx = x0; cx <= x1; cx++) for (let cy = y0; cy <= y1; cy++) {
          const key = cx * 100003 + cy;
          let b = this.grid.get(key);
          if (!b) this.grid.set(key, (b = []));
          b.push(l, s);
        }
      }
    }
  }

  private laneLen(l: number) { return this.d.laneLength[l]; }
  private speed(l: number, avoidHighways: boolean) {
    let s = Math.max(5, this.d.laneSpeed[l] || 10);
    if (avoidHighways && this.d.laneFlags[l] & HIGHWAY) s *= 0.4;
    return s;
  }

  /** Nearest lane point to p; with a heading (game yaw, degrees), lanes running the other way cost more. */
  snap(p: GamePos, opts: { mainOnly?: boolean; heading?: number; maxDist?: number } = {}): Snap | null {
    const P = this.d.points;
    const maxDist = opts.maxDist ?? 600;
    let best: Snap | null = null, bestScore = Infinity;
    const hx = opts.heading !== undefined ? -Math.sin((opts.heading * Math.PI) / 180) : 0;
    const hy = opts.heading !== undefined ? Math.cos((opts.heading * Math.PI) / 180) : 0;
    const seen = new Set<number>();
    for (let ring = 0; ring * CELL <= maxDist + CELL; ring++) {
      const cx = Math.floor(p.x / CELL), cy = Math.floor(p.y / CELL);
      for (let ix = cx - ring; ix <= cx + ring; ix++) for (let iy = cy - ring; iy <= cy + ring; iy++) {
        if (Math.max(Math.abs(ix - cx), Math.abs(iy - cy)) !== ring) continue;
        const b = this.grid.get(ix * 100003 + iy);
        if (!b) continue;
        for (let i = 0; i < b.length; i += 2) {
          const l = b[i], s = b[i + 1];
          const id = l * 4096 + s;
          if (seen.has(id)) continue;
          seen.add(id);
          if (opts.mainOnly && !this.d.laneMain[l]) continue;
          const o = this.d.laneOffset[l] + s;
          const ax = P[o * 3], ay = P[o * 3 + 1], az = P[o * 3 + 2], bx = P[o * 3 + 3], by = P[o * 3 + 4], bz = P[o * 3 + 5];
          const dx = bx - ax, dy = by - ay, len2 = dx * dx + dy * dy || 1;
          const t = Math.min(1, Math.max(0, ((p.x - ax) * dx + (p.y - ay) * dy) / len2));
          const x = ax + dx * t, y = ay + dy * t;
          const dist = Math.hypot(p.x - x, p.y - y);
          let score = dist;
          if (opts.heading !== undefined) {
            const len = Math.sqrt(len2);
            const align = (dx * hx + dy * hy) / len;
            score += (1 - align) * 9; // a lane the wrong way is ~18 m "further"
          }
          if (score < bestScore) {
            bestScore = score;
            const along = this.alongLane(l, s, t);
            best = { lane: l, seg: s, t, x, y, z: az + (bz - az) * t, dist, along };
          }
        }
      }
      const found = best as Snap | null;
      if (found && found.dist < ring * CELL) break;
    }
    return best;
  }

  private alongLane(l: number, s: number, t: number) {
    const P = this.d.points, o = this.d.laneOffset[l];
    let a = 0;
    for (let i = 0; i < s; i++) a += Math.hypot(P[(o + i + 1) * 3] - P[(o + i) * 3], P[(o + i + 1) * 3 + 1] - P[(o + i) * 3 + 1]);
    return a + t * Math.hypot(P[(o + s + 1) * 3] - P[(o + s) * 3], P[(o + s + 1) * 3 + 1] - P[(o + s) * 3 + 1]);
  }

  route(from: GamePos, to: GamePos, opts: { heading?: number; mainOnly?: boolean; avoidHighways?: boolean } = {}): Route | null {
    const a = this.snap(from, { heading: opts.heading, mainOnly: opts.mainOnly });
    const b = this.snap(to, { mainOnly: opts.mainOnly, maxDist: 1500 });
    if (!a || !b) return null;
    const avoid = !!opts.avoidHighways;
    const n = this.lanes;
    const g = new Float64Array(n).fill(Infinity);
    const prev = new Int32Array(n).fill(-1);
    const done = new Uint8Array(n);
    const heap = new MinHeap();
    const VMAX = 32;
    const h = (l: number) => Math.hypot(this.laneEnd[l * 2] - b.x, this.laneEnd[l * 2 + 1] - b.y) / VMAX;
    // same lane, destination ahead: no search
    if (a.lane === b.lane && b.along >= a.along) return this.build([a.lane], a, b, to);
    g[a.lane] = (this.laneLen(a.lane) - a.along) / this.speed(a.lane, avoid);
    heap.push(g[a.lane] + h(a.lane), a.lane);
    let found = -1, guard = 0;
    while (heap.size && guard++ < 400000) {
      const l = heap.pop();
      if (done[l]) continue;
      done[l] = 1;
      if (l === b.lane && l !== a.lane) { found = l; break; }
      for (let k = this.d.outStart[l]; k < this.d.outStart[l + 1]; k++) {
        const m = this.d.outLanes[k];
        if (done[m]) continue;
        const cost = m === b.lane ? b.along / this.speed(m, avoid) : this.laneLen(m) / this.speed(m, avoid);
        const ng = g[l] + cost + 0.15; // small per-junction penalty: fewer, longer lanes
        if (ng < g[m]) { g[m] = ng; prev[m] = l; heap.push(ng + h(m), m); }
      }
    }
    if (found < 0) return null;
    const path: number[] = [];
    for (let l = found; l >= 0; l = prev[l]) { path.push(l); if (l === a.lane) break; }
    path.reverse();
    if (path[0] !== a.lane) return null;
    return this.build(path, a, b, to, g[found]);
  }

  private build(path: number[], a: Snap, b: Snap, to: GamePos, seconds?: number): Route {
    const P = this.d.points;
    const out: number[] = [];
    const push = (x: number, y: number, z: number) => {
      const n = out.length;
      if (n >= 3 && Math.hypot(out[n - 3] - x, out[n - 2] - y) < 0.5) return;
      out.push(x, y, z);
    };
    path.forEach((l, i) => {
      const o = this.d.laneOffset[l], n = this.d.laneCount[l];
      const first = i === 0, last = i === path.length - 1;
      if (first) push(a.x, a.y, a.z);
      const s0 = first ? a.seg + 1 : 0;
      const s1 = last ? b.seg : n - 1;
      for (let s = s0; s <= s1; s++) push(P[(o + s) * 3], P[(o + s) * 3 + 1], P[(o + s) * 3 + 2]);
      if (last) push(b.x, b.y, b.z);
    });
    const points = new Float32Array(out);
    const count = points.length / 3;
    const cumulative = new Float32Array(count);
    for (let i = 1; i < count; i++) cumulative[i] = cumulative[i - 1] + Math.hypot(points[i * 3] - points[i * 3 - 3], points[i * 3 + 1] - points[i * 3 - 2]);
    const length = cumulative[count - 1] || 0;
    let secs = seconds;
    if (secs === undefined) secs = length / Math.max(5, this.d.laneSpeed[a.lane] || 10);
    return { points, cumulative, length, seconds: secs, maneuvers: maneuvers(points, cumulative), lanes: path, destination: to };
  }
}

/** Turns along a polyline: heading change measured over ~20 m either side of each vertex. */
function maneuvers(p: Float32Array, cum: Float32Array): Maneuver[] {
  const n = cum.length;
  const out: Maneuver[] = [{ kind: "start", at: 0, x: p[0], y: p[1] }];
  if (n < 3) { out.push({ kind: "arrive", at: cum[n - 1] ?? 0, x: p[(n - 1) * 3], y: p[(n - 1) * 3 + 1] }); return out; }
  const pointAt = (dist: number) => {
    let i = 1;
    while (i < n - 1 && cum[i] < dist) i++;
    const span = cum[i] - cum[i - 1] || 1, t = Math.min(1, Math.max(0, (dist - cum[i - 1]) / span));
    return [p[(i - 1) * 3] + (p[i * 3] - p[(i - 1) * 3]) * t, p[(i - 1) * 3 + 1] + (p[i * 3 + 1] - p[(i - 1) * 3 + 1]) * t];
  };
  let lastAt = -1e9;
  for (let i = 1; i < n - 1; i++) {
    const at = cum[i];
    if (at - lastAt < 35 || at < 15 || cum[n - 1] - at < 15) continue;
    const [bx, by] = pointAt(at - 20), [ax, ay] = pointAt(at + 20);
    const h1 = Math.atan2(p[i * 3 + 1] - by, p[i * 3] - bx);
    const h2 = Math.atan2(ay - p[i * 3 + 1], ax - p[i * 3]);
    let d = ((h2 - h1) * 180) / Math.PI;
    while (d > 180) d -= 360;
    while (d < -180) d += 360;
    const ad = Math.abs(d);
    if (ad < 28) continue;
    const left = d > 0; // counter-clockwise in game space (X east, Y north) is a left turn
    const kind: Maneuver["kind"] = ad > 150 ? "uturn" : ad > 110 ? (left ? "sharp-left" : "sharp-right") : ad > 50 ? (left ? "left" : "right") : left ? "slight-left" : "slight-right";
    out.push({ kind, at, x: p[i * 3], y: p[i * 3 + 1] });
    lastAt = at;
  }
  out.push({ kind: "arrive", at: cum[n - 1], x: p[(n - 1) * 3], y: p[(n - 1) * 3 + 1] });
  return out;
}

/** Where the player is along a route: distance along it, and how far off it. */
export function progressOn(route: Route, p: GamePos, hint = 0): { along: number; off: number; index: number } {
  const P = route.points, n = route.cumulative.length;
  let best = { along: 0, off: Infinity, index: 0 };
  const from = Math.max(0, hint - 40), to = Math.min(n - 1, hint + 400);
  const scan = (a: number, b: number) => {
    for (let i = a; i < b; i++) {
      const ax = P[i * 3], ay = P[i * 3 + 1], bx = P[i * 3 + 3], by = P[i * 3 + 4];
      const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1;
      const t = Math.min(1, Math.max(0, ((p.x - ax) * dx + (p.y - ay) * dy) / l2));
      const off = Math.hypot(p.x - ax - dx * t, p.y - ay - dy * t);
      if (off < best.off) best = { along: route.cumulative[i] + Math.sqrt(l2) * t, off, index: i };
    }
  };
  scan(from, to);
  if (best.off > 60) scan(0, n - 1);
  return best;
}
