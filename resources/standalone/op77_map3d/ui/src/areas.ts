import * as THREE from "three";

// Areas (shared/area.lua): polygons draped over the city, on the map and the minimap. No
// mesh of their own: the polygons are baked once into a small texture laid over the
// ground in world space (RG half float: signed distance to the nearest border in metres,
// positive inside, and which area a texel belongs to), and the world's shaders (world.ts,
// AREA_GLSL) read it: fill, diagonal danger hatching and a border of constant on-screen
// width on the terrain, the roads and the buildings alike, whatever their height. One
// texture read per pixel; the texture is rebuilt only when an area changes.

export interface Area {
  id: string;
  pts: number[]; // game x, y, x, y, ...
  fill: string; fillOpacity: number;
  stroke: string; strokeWidth: number;
  pattern: "hatch" | "solid";
  label?: string;
  lx?: number; ly?: number; lz?: number;
  map: boolean; minimap: boolean; pulse: boolean;
}

/** Which surface draws: the open map or the minimap (each area says where it shows). */
export type AreaView = "map" | "minimap";

/** Drawn at a time (the shaders' uniform arrays); the oldest come first. */
export const MAX_AREAS = 16;
/** Metres of signed distance the texture holds: the border is drawn within it. */
const RANGE = 32;
const MAX_TEXELS = 1024;
const MIN_TEXEL = 1.5; // metres

export interface AreaUniforms {
  uAreaTex: { value: THREE.Texture };
  uAreaBox: { value: THREE.Vector4 }; // scene x, scene z of the first texel's corner, width, depth (metres)
  uAreaCount: { value: number };
  uAreaFill: { value: THREE.Vector4[] }; // rgb, opacity
  uAreaLine: { value: THREE.Vector4[] }; // rgb, border width (px)
  uAreaFx: { value: THREE.Vector4[] }; // hatch, pulse
  uAreaHatch: { value: THREE.Vector2 }; // stripe period (metres), blend toward twice that
  uAreaHatchDir: { value: THREE.Vector2 }; // scene x, z across the stripes (unit): diagonal on screen
  uAreaPulse: { value: number };
  uAreaStrength: { value: number };
}

export function areaUniforms(): AreaUniforms {
  const blank = new THREE.DataTexture(new Uint16Array(2), 1, 1, THREE.RGFormat, THREE.HalfFloatType);
  blank.needsUpdate = true;
  return {
    uAreaTex: { value: blank },
    uAreaBox: { value: new THREE.Vector4(0, 0, 1, 1) },
    uAreaCount: { value: 0 },
    uAreaFill: { value: Array.from({ length: MAX_AREAS }, () => new THREE.Vector4()) },
    uAreaLine: { value: Array.from({ length: MAX_AREAS }, () => new THREE.Vector4()) },
    uAreaFx: { value: Array.from({ length: MAX_AREAS }, () => new THREE.Vector4()) },
    uAreaHatch: { value: new THREE.Vector2(16, 0) },
    uAreaHatchDir: { value: new THREE.Vector2(Math.SQRT1_2, Math.SQRT1_2) },
    uAreaPulse: { value: 1 },
    uAreaStrength: { value: 1 },
  };
}

/**
 * GLSL shared by the world's materials. areaAt(world, hatchWeight, inside, fillColor):
 * the colour (rgb) and coverage (a) the areas add at a world point (fill, hatching on the
 * surfaces that want it, border); `inside` and `fillColor` let a material tint itself.
 */
export const AREA_GLSL = /* glsl */ `
uniform sampler2D uAreaTex; uniform vec4 uAreaBox; uniform float uAreaCount;
uniform vec4 uAreaFill[${MAX_AREAS}]; uniform vec4 uAreaLine[${MAX_AREAS}]; uniform vec4 uAreaFx[${MAX_AREAS}];
uniform vec2 uAreaHatch; uniform vec2 uAreaHatchDir; uniform float uAreaPulse; uniform float uAreaStrength;
float areaStripes(vec2 p, float s){
  float u = dot(p, uAreaHatchDir) / s;
  float aa = fwidth(u) * 1.2;
  float f = fract(u);
  return smoothstep(0.0, aa, f) * (1.0 - smoothstep(0.42, 0.42 + aa, f));
}
vec4 areaAt(vec3 w, float hatchWeight, out float inside, out vec3 fillColor){
  inside = 0.0; fillColor = vec3(0.0);
  if (uAreaCount < 0.5) return vec4(0.0);
  vec2 uv = (w.xz - uAreaBox.xy) / uAreaBox.zw;
  if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) return vec4(0.0);
  vec2 s = texture2D(uAreaTex, uv).rg;
  if (s.g < 0.5) return vec4(0.0);
  int i = int(clamp(floor(s.g + 0.5), 1.0, ${MAX_AREAS}.0)) - 1;
  float d = s.r;                                   // metres to the nearest border, + inside
  float aa = max(fwidth(d), 1e-3);                 // metres per pixel, about
  vec4 fill = uAreaFill[i]; vec4 line = uAreaLine[i]; vec4 fx = uAreaFx[i];
  float pulse = mix(1.0, 0.55 + 0.45 * uAreaPulse, fx.y);
  inside = smoothstep(-0.5 * aa, 0.5 * aa, d);
  fillColor = fill.rgb;
  float hatch = 0.0;
  if (fx.x > 0.5 && hatchWeight > 0.0) {
    hatch = mix(areaStripes(w.xz, uAreaHatch.x), areaStripes(w.xz, uAreaHatch.x * 2.0), uAreaHatch.y) * hatchWeight;
  }
  float a = inside * fill.a * (fx.x > 0.5 ? 0.5 + 1.25 * hatch : 1.0) * pulse;
  float hw = 0.5 * line.w * aa;                    // half the border, in metres
  float edge = line.w > 0.01 ? 1.0 - smoothstep(hw - 0.5 * aa, hw + 0.5 * aa, abs(d)) : 0.0;
  edge *= mix(1.0, 0.7 + 0.3 * uAreaPulse, fx.y);
  vec3 c = mix(fill.rgb, line.rgb, edge);
  return vec4(c, clamp(max(a, edge * 0.95), 0.0, 1.0) * uAreaStrength);
}
`;

/**
 * The stripes stay anchored to the ground (nothing swims while panning) but run from the
 * bottom left to the top right of the screen whatever the camera's heading and tilt: their
 * direction is the screen's diagonal laid on the ground, the forward part stretched by the
 * tilt's foreshortening. Writes the unit vector across them (scene x, z) into `out`.
 */
export function hatchDirection(cam: THREE.Camera, out: THREE.Vector2): THREE.Vector2 {
  cam.updateMatrixWorld();
  const e = cam.matrixWorld.elements; // columns: right (0..2), up (4..6), back (8..10)
  let rx = e[0], rz = e[2];
  let ux = e[4] - e[8], uz = e[6] - e[10]; // screen up on the ground: the camera's up and forward
  const rl = Math.hypot(rx, rz), ul = Math.hypot(ux, uz);
  if (rl < 1e-6 || ul < 1e-6) return out.set(Math.SQRT1_2, Math.SQRT1_2);
  rx /= rl; rz /= rl;
  const k = Math.max(0.3, e[9]); // cosine of the tilt from straight down
  ux /= ul * k; uz /= ul * k;
  const dx = rx + ux, dz = rz + uz, dl = Math.hypot(dx, dz) || 1;
  return out.set(dz / dl, -dx / dl);
}

/** Polygon centroid, or the middle of the widest span through it when it falls outside (concave). */
export function labelPoint(pts: number[]): { x: number; y: number } {
  const n = pts.length / 2;
  let a2 = 0, cx = 0, cy = 0;
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    const x0 = pts[i * 2], y0 = pts[i * 2 + 1], x1 = pts[j * 2], y1 = pts[j * 2 + 1];
    const k = x0 * y1 - x1 * y0;
    a2 += k; cx += (x0 + x1) * k; cy += (y0 + y1) * k;
  }
  const c = Math.abs(a2) > 1e-6 ? { x: cx / (3 * a2), y: cy / (3 * a2) } : { x: pts[0], y: pts[1] };
  if (containsPoint(pts, c.x, c.y)) return c;
  const xs = crossings(pts, c.y);
  let best = 0, at = c;
  for (let k = 0; k + 1 < xs.length; k += 2) if (xs[k + 1] - xs[k] > best) { best = xs[k + 1] - xs[k]; at = { x: (xs[k] + xs[k + 1]) / 2, y: c.y }; }
  return at;
}

/** Where a horizontal line at y crosses the outline, sorted (even-odd pairs are inside). */
function crossings(pts: number[], y: number): number[] {
  const n = pts.length / 2, xs: number[] = [];
  for (let i = 0, j = n - 1; i < n; j = i++) {
    const ay = pts[i * 2 + 1], by = pts[j * 2 + 1];
    if ((ay > y) !== (by > y)) xs.push(pts[i * 2] + ((y - ay) * (pts[j * 2] - pts[i * 2])) / (by - ay));
  }
  return xs.sort((p, q) => p - q);
}

/** Planar even-odd test (shared/area.lua's rule). */
export function containsPoint(pts: number[], x: number, y: number): boolean {
  let inside = false;
  const n = pts.length / 2;
  for (let i = 0, j = n - 1; i < n; j = i++) {
    const ax = pts[i * 2], ay = pts[i * 2 + 1], bx = pts[j * 2], by = pts[j * 2 + 1];
    if ((ay > y) !== (by > y) && x < ((bx - ax) * (y - ay)) / (by - ay) + ax) inside = !inside;
  }
  return inside;
}

export interface AreaField { width: number; height: number; box: [number, number, number, number]; data: Float32Array }

/**
 * The texture's content for a list of areas (pure, testable): per texel, the signed
 * distance in metres to the nearest border (clamped to +-RANGE, positive inside any area)
 * and the area's slot (1-based; outside, within RANGE of a border, the nearest border's
 * area, so a border's colour and width reach past the outline).
 * Texel (c, r) covers scene x minX + c * texel and scene z (= -game y) minZ + r * texel.
 */
export function bakeAreas(list: { pts: number[] }[]): AreaField | null {
  if (!list.length) return null;
  let minX = Infinity, minZ = Infinity, maxX = -Infinity, maxZ = -Infinity;
  for (const a of list) for (let i = 0; i < a.pts.length; i += 2) {
    const x = a.pts[i], z = -a.pts[i + 1];
    if (x < minX) minX = x; if (x > maxX) maxX = x; if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
  }
  const pad = RANGE + 8;
  minX -= pad; minZ -= pad; maxX += pad; maxZ += pad;
  const texel = Math.max(MIN_TEXEL, Math.max(maxX - minX, maxZ - minZ) / MAX_TEXELS);
  const W = Math.max(2, Math.ceil((maxX - minX) / texel)), H = Math.max(2, Math.ceil((maxZ - minZ) / texel));
  const dist = new Float32Array(W * H).fill(RANGE);
  const region = new Uint8Array(W * H);
  const near = new Uint8Array(W * H);
  list.forEach((a, k) => {
    const slot = k + 1;
    const n = a.pts.length / 2;
    const X = (i: number) => a.pts[i * 2], Z = (i: number) => -a.pts[i * 2 + 1];
    // inside: even-odd spans per row of texel centres
    for (let r = 0; r < H; r++) {
      const z = minZ + (r + 0.5) * texel;
      const xs: number[] = [];
      for (let i = 0, j = n - 1; i < n; j = i++) {
        const az = Z(i), bz = Z(j);
        if ((az > z) !== (bz > z)) xs.push(X(i) + ((z - az) * (X(j) - X(i))) / (bz - az));
      }
      if (xs.length < 2) continue;
      xs.sort((p, q) => p - q);
      for (let s = 0; s + 1 < xs.length; s += 2) {
        const c0 = Math.max(0, Math.ceil((xs[s] - minX) / texel - 0.5)), c1 = Math.min(W - 1, Math.floor((xs[s + 1] - minX) / texel - 0.5));
        for (let c = c0; c <= c1; c++) region[r * W + c] = slot;
      }
    }
    // the band along each border: distance to the nearest edge
    for (let i = 0, j = n - 1; i < n; j = i++) {
      const ax = X(j), az = Z(j), bx = X(i), bz = Z(i);
      const dx = bx - ax, dz = bz - az, len2 = dx * dx + dz * dz || 1e-9;
      const c0 = Math.max(0, Math.floor((Math.min(ax, bx) - RANGE - minX) / texel)), c1 = Math.min(W - 1, Math.ceil((Math.max(ax, bx) + RANGE - minX) / texel));
      const r0 = Math.max(0, Math.floor((Math.min(az, bz) - RANGE - minZ) / texel)), r1 = Math.min(H - 1, Math.ceil((Math.max(az, bz) + RANGE - minZ) / texel));
      for (let r = r0; r <= r1; r++) {
        const pz = minZ + (r + 0.5) * texel;
        for (let c = c0; c <= c1; c++) {
          const px = minX + (c + 0.5) * texel;
          const t = Math.max(0, Math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2));
          const ex = ax + dx * t - px, ez = az + dz * t - pz;
          const d = Math.sqrt(ex * ex + ez * ez);
          const o = r * W + c;
          if (d < dist[o]) { dist[o] = d; near[o] = slot; }
        }
      }
    }
  });
  const data = new Float32Array(W * H * 2);
  for (let o = 0; o < W * H; o++) {
    const inside = region[o] !== 0;
    data[o * 2] = inside ? dist[o] : -dist[o];
    data[o * 2 + 1] = inside ? region[o] : dist[o] < RANGE ? near[o] : 0;
  }
  return { width: W, height: H, box: [minX, minZ, W * texel, H * texel], data };
}

interface Label { el: HTMLElement; pos: THREE.Vector3 }
const projected = new THREE.Vector3();

export class AreaLayer {
  private areas = new Map<string, Area>();
  private texture: THREE.DataTexture | null = null;
  private blank: THREE.Texture;
  private built = "";
  private warned = false;
  private lists: Partial<Record<AreaView, Area[]>> = {}; // shown(), until the next change
  private labels = new Map<string, Label>();
  /** Where the open map's labels go (under the blips). */
  labelRoot: HTMLElement | null = null;
  /** Ground height under a label point (the map's terrain), set by the app once it can raycast. */
  heightAt: ((x: number, y: number) => number | null) | null = null;

  constructor(private uniforms: AreaUniforms) { this.blank = uniforms.uAreaTex.value; }

  get size(): number { return this.areas.size; }

  upsert(p: any): boolean {
    const a = normalizeArea(p);
    if (!a) return false;
    this.areas.set(a.id, a);
    this.changed();
    const l = this.labels.get(a.id);
    if (l) { l.el.remove(); this.labels.delete(a.id); }
    return true;
  }
  remove(ids: unknown[]): void {
    for (const id of ids) {
      const key = String(id);
      this.areas.delete(key);
      const l = this.labels.get(key);
      if (l) { l.el.remove(); this.labels.delete(key); }
    }
    this.changed();
  }
  private changed(): void { this.built = ""; this.lists = {}; }
  clear(): void { this.remove([...this.areas.keys()]); }

  /** The areas a view draws, oldest first, at most MAX_AREAS. */
  private shown(view: AreaView): Area[] {
    const cached = this.lists[view];
    if (cached) return cached;
    const list = [...this.areas.values()].filter((a) => (view === "map" ? a.map : a.minimap));
    if (list.length > MAX_AREAS && !this.warned) { this.warned = true; console.warn(`[map3d] ${list.length} areas: only the first ${MAX_AREAS} are drawn`); }
    return (this.lists[view] = list.slice(0, MAX_AREAS));
  }

  /** A pulsing area is drawn in this view: keep redrawing. */
  pulsing(view: AreaView): boolean { return this.shown(view).some((a) => a.pulse); }

  /** Before drawing a view: the texture for its areas (rebuilt when they changed) and the per-frame uniforms. */
  prepare(view: AreaView, t: number, hatchMetres: number, strength: number, cam?: THREE.Camera): void {
    const list = this.shown(view);
    // the same areas on the map and the minimap (the usual case): opening the map keeps the texture
    const key = "#" + list.map((a) => a.id).join("|");
    const u = this.uniforms;
    if (key !== this.built) {
      this.built = key;
      this.texture?.dispose();
      this.texture = null;
      u.uAreaTex.value = this.blank;
      const field = bakeAreas(list);
      if (field) {
        const half = new Uint16Array(field.data.length);
        for (let i = 0; i < half.length; i++) half[i] = THREE.DataUtils.toHalfFloat(field.data[i]);
        const tex = new THREE.DataTexture(half, field.width, field.height, THREE.RGFormat, THREE.HalfFloatType);
        tex.minFilter = tex.magFilter = THREE.LinearFilter;
        tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
        tex.generateMipmaps = false;
        tex.needsUpdate = true;
        this.texture = tex;
        u.uAreaTex.value = tex;
        u.uAreaBox.value.set(...field.box);
      }
      list.forEach((a, i) => {
        const f = new THREE.Color(a.fill), s = new THREE.Color(a.stroke);
        u.uAreaFill.value[i].set(f.r, f.g, f.b, a.fillOpacity);
        u.uAreaLine.value[i].set(s.r, s.g, s.b, a.strokeWidth);
        u.uAreaFx.value[i].set(a.pattern === "hatch" ? 1 : 0, a.pulse ? 1 : 0, 0, 0);
      });
      u.uAreaCount.value = field ? list.length : 0;
    }
    // stripes about a constant number of pixels apart: a power of two in metres, eased
    // toward the next so they never slide while zooming
    const lv = Math.log2(Math.max(0.5, hatchMetres));
    u.uAreaHatch.value.set(Math.pow(2, Math.floor(lv)), lv - Math.floor(lv));
    if (cam) hatchDirection(cam, u.uAreaHatchDir.value);
    u.uAreaPulse.value = 0.5 + 0.5 * Math.sin(t * 2.6);
    u.uAreaStrength.value = strength;
  }

  /** The labelled area the player stands in (the minimap's line), if any. */
  at(x: number, y: number, view: AreaView): Area | null {
    let found: Area | null = null;
    for (const a of this.shown(view)) if (a.label && containsPoint(a.pts, x, y)) found = a;
    return found;
  }

  /** The open map's labels, placed with its camera. */
  placeLabels(cam: THREE.Camera, W: number, H: number, visible: boolean): void {
    if (!this.labelRoot) return;
    const seen = new Set<string>();
    if (visible) {
      for (const a of this.shown("map")) {
        if (!a.label) continue;
        seen.add(a.id);
        let l = this.labels.get(a.id);
        if (!l) {
          const p = a.lx !== undefined && a.ly !== undefined ? { x: a.lx, y: a.ly } : labelPoint(a.pts);
          const z = a.lz ?? this.heightAt?.(p.x, p.y) ?? 0;
          const el = document.createElement("div");
          el.className = "m3-area";
          el.style.setProperty("--ac", a.stroke);
          el.innerHTML = `<b>${WARNING}<span>${escapeText(a.label)}</span></b>`; // a changed area gets a new label
          this.labelRoot.appendChild(el);
          l = { el, pos: new THREE.Vector3(p.x, z + 2, -p.y) };
          this.labels.set(a.id, l);
        }
        const v = projected.copy(l.pos).project(cam);
        const vis = v.z < 1 && Math.abs(v.x) < 1.05 && Math.abs(v.y) < 1.05;
        l.el.style.display = vis ? "" : "none";
        if (vis) l.el.style.transform = `translate(${((v.x * 0.5 + 0.5) * W).toFixed(0)}px, ${((-v.y * 0.5 + 0.5) * H).toFixed(0)}px)`;
      }
    }
    for (const [id, l] of this.labels) if (!seen.has(id)) l.el.style.display = "none";
  }
}

const WARNING = `<svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor"><path d="M12 2.5 23 21.5H1zM11 9v6h2V9zm0 8v2h2v-2z" fill-rule="evenodd"/></svg>`;

function escapeText(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

const HEX = /^#[0-9a-fA-F]{6}$/;
/** What Lua sent (shared/area.lua A.page), checked again: a page never trusts its input. */
export function normalizeArea(p: any): Area | null {
  if (!p || (typeof p.id !== "string" && typeof p.id !== "number")) return null;
  const pts = Array.isArray(p.pts) ? p.pts : [];
  if (pts.length < 6 || pts.length % 2 !== 0 || pts.length > 400 || !pts.every((v: unknown) => typeof v === "number" && isFinite(v))) return null;
  const fill = typeof p.fill === "string" && HEX.test(p.fill) ? p.fill : "#FF2E3C";
  const num = (v: unknown, lo: number, hi: number, d: number) => (typeof v === "number" && isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d);
  return {
    id: String(p.id), pts,
    fill, fillOpacity: num(p.fillOpacity, 0, 1, 0.22),
    stroke: typeof p.stroke === "string" && HEX.test(p.stroke) ? p.stroke : fill, strokeWidth: num(p.strokeWidth, 0, 8, 2),
    pattern: p.pattern === "solid" ? "solid" : "hatch",
    label: typeof p.label === "string" && p.label ? p.label.slice(0, 64) : undefined,
    lx: typeof p.lx === "number" && isFinite(p.lx) ? p.lx : undefined,
    ly: typeof p.ly === "number" && isFinite(p.ly) ? p.ly : undefined,
    lz: typeof p.lz === "number" && isFinite(p.lz) ? p.lz : undefined,
    map: p.map !== false, minimap: p.minimap !== false, pulse: p.pulse === true,
  };
}
