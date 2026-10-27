/* The WebGL layer of the installation (three.js, the HOLO-OS design): the CRT
   backdrop (dot grid, boot static, glitch tears, rolling band, a glow under
   the emblem) and the Kiroshi emblem, concentric rings in the two accents,
   each spinning at its own rate, that assemble, dock, explode and return.
   `draw` is a pure function of the parameters. */
import * as THREE from "three";
import { hash, hexRgb } from "./motion";

export const HW = 1920, HH = 1080;
const TAU = Math.PI * 2;

const arcsOf = (n: number, len: number, offset: number): [number, number][] =>
  Array.from({ length: n }, (_, i) => [offset + (i * TAU) / n - len / 2, len]);
/** The emblem, outside in; `c` picks the accent, `spin` its rate. */
export const RINGS: { r: number; w: number; arcs: [number, number][]; c: 0 | 1; spin: number }[] = [
  { r: 1.0, w: 0.03, arcs: [[0, TAU]], c: 0, spin: 0.12 },
  { r: 0.86, w: 0.08, arcs: arcsOf(4, 0.95, Math.PI / 4), c: 1, spin: -0.22 },
  { r: 0.7, w: 0.028, arcs: arcsOf(3, 1.75, 0), c: 0, spin: 0.36 },
  { r: 0.55, w: 0.09, arcs: arcsOf(2, 1.25, Math.PI / 2), c: 1, spin: -0.3 },
  { r: 0.4, w: 0.026, arcs: [[0, TAU]], c: 0, spin: 0.55 },
  { r: 0.26, w: 0.105, arcs: arcsOf(2, 2.1, 0), c: 1, spin: -0.48 },
  { r: 0.0, w: 0.075, arcs: [[0, TAU]], c: 0, spin: 0 },
];

const BG_VS = `varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;
const BG_FS = `
varying vec2 vUv;
uniform float uTime, uStatic, uGlitch, uGlowR, uGlowI;
uniform vec2 uRes, uGlow; uniform vec3 uColA, uColB;
float h21(vec2 p){ p = fract(p*vec2(123.34,456.21)); p += dot(p, p+45.32); return fract(p.x*p.y); }
void main(){
  vec2 uv = vUv; float asp = uRes.x/uRes.y;
  vec2 c = uv - 0.5; c.x *= asp; float r2 = dot(c,c);
  float band = floor(uv.y*30.0) + floor(uTime*17.0)*7.0;
  float gb = step(1.0 - uGlitch*0.35, h21(vec2(band, 7.1)));
  uv.x += gb*(h21(vec2(band, 3.3))-0.5)*0.12*uGlitch;
  vec3 col = vec3(0.016,0.019,0.03);
  vec2 g = fract(uv*vec2(48.0, 27.0)) - 0.5;
  float dots = smoothstep(0.08, 0.0, length(g));
  col += vec3(0.05,0.07,0.09)*dots*0.5;
  vec2 d = uv - uGlow; d.x *= asp; float gr = dot(d,d);
  col += uColA*uGlowI*exp(-gr/(uGlowR*uGlowR))*0.35;
  col += uColB*uGlowI*exp(-gr/(uGlowR*uGlowR*0.22))*0.22;
  float roll = smoothstep(0.0, 0.1, abs(fract(uv.y + uTime*0.06) - 0.5));
  col *= 0.9 + 0.1*roll;
  float n = h21(floor(vUv*uRes*0.5) + fract(uTime*13.7)*100.0);
  col = mix(col, vec3(n)*0.45, uStatic*uStatic);
  col *= 1.0 - 0.75*r2;
  col += (h21(vUv*uRes + fract(uTime)*37.0)-0.5)*0.03;
  gl_FragColor = vec4(col, 1.0);
}`;

export interface EmblemParams {
  /** centre x, y and radius, in stage pixels */
  pos: [number, number, number];
  /** per ring, 0 scattered → 1 in place */
  assemble: number[];
  explode: number;
  pulse: number;
  spinT: number;
  tilt: number;
  alpha: number;
}
export interface GLParams { T: number; W: number; glitch: number; stat: number; emb: EmblemParams }

type Arc = THREE.Group & { userData: { dx: number; dy: number; h: number } };

export class HoloGL {
  private renderer: THREE.WebGLRenderer;
  private colA = new THREE.Color("#2ee6e0");
  private colB = new THREE.Color("#ff3fb8");
  private vA = new THREE.Vector3();
  private vB = new THREE.Vector3();
  private palKey = "";
  private bgScene = new THREE.Scene();
  private bgCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private bgU: Record<string, THREE.IUniform>;
  private scene = new THREE.Scene();
  private cam = new THREE.PerspectiveCamera(30, HW / HH, 1, 20000);
  private matA: THREE.MeshBasicMaterial;
  private matB: THREE.MeshBasicMaterial;
  private glowA: THREE.MeshBasicMaterial;
  private glowB: THREE.MeshBasicMaterial;
  private emblem = new THREE.Group();
  private rings: { rg: THREE.Group; arcs: Arc[] }[];
  private disposables: { dispose(): void }[] = [];

  constructor(canvas: HTMLCanvasElement) {
    const R = (this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: "high-performance" }));
    R.setPixelRatio(1);
    R.setSize(HW, HH, false);
    R.autoClear = false;
    this.bgU = {
      uTime: { value: 0 }, uStatic: { value: 1 }, uGlitch: { value: 0 }, uGlowR: { value: 0.3 }, uGlowI: { value: 0 },
      uRes: { value: new THREE.Vector2(HW, HH) }, uGlow: { value: new THREE.Vector2(0.5, 0.5) }, uColA: { value: this.vA }, uColB: { value: this.vB },
    };
    const bgGeo = new THREE.PlaneGeometry(2, 2);
    const bgMat = new THREE.ShaderMaterial({ uniforms: this.bgU, vertexShader: BG_VS, fragmentShader: BG_FS, depthTest: false, depthWrite: false });
    this.bgScene.add(new THREE.Mesh(bgGeo, bgMat));
    this.disposables.push(bgGeo, bgMat);
    this.cam.position.z = HH / 2 / Math.tan(Math.PI / 12);
    this.cam.lookAt(0, 0, 0);
    const mk = (col: THREE.Color) => {
      const m = new THREE.MeshBasicMaterial({ color: col.clone(), transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
      this.disposables.push(m);
      return m;
    };
    this.matA = mk(this.colA); this.matB = mk(this.colB); this.glowA = mk(this.colA); this.glowB = mk(this.colB);
    this.scene.add(this.emblem);
    this.rings = RINGS.map((Rg, i) => {
      const rg = new THREE.Group();
      this.emblem.add(rg);
      const mat = Rg.c ? this.matB : this.matA, glow = Rg.c ? this.glowB : this.glowA;
      const arcs = Rg.arcs.map(([s, len], j) => {
        const a = new THREE.Group() as Arc;
        const add = (geo: THREE.BufferGeometry, m: THREE.Material) => { this.disposables.push(geo); a.add(new THREE.Mesh(geo, m)); };
        if (Rg.r === 0) {
          add(new THREE.CircleGeometry(Rg.w, 48), mat);
          add(new THREE.CircleGeometry(Rg.w * 2.2, 48), glow);
        } else {
          add(new THREE.RingGeometry(Rg.r - Rg.w / 2, Rg.r + Rg.w / 2, 96, 1, s, len), mat);
          add(new THREE.RingGeometry(Rg.r - Rg.w * 1.9, Rg.r + Rg.w * 1.9, 96, 1, s - 0.03, len + 0.06), glow);
        }
        const mid = s + len / 2;
        a.userData = { dx: Rg.r === 0 ? 0 : Math.cos(mid), dy: Rg.r === 0 ? 0 : Math.sin(mid), h: hash(i * 7 + j * 3 + 1) };
        rg.add(a);
        return a;
      });
      return { rg, arcs };
    });
  }

  private setPalette(a: string, b: string) {
    const key = a + "|" + b;
    if (key === this.palKey) return;
    this.palKey = key;
    const ra = hexRgb(a), rb = hexRgb(b);
    this.vA.set(ra[0] / 255, ra[1] / 255, ra[2] / 255);
    this.vB.set(rb[0] / 255, rb[1] / 255, rb[2] / 255);
    this.colA.set(a); this.colB.set(b);
  }

  draw(p: GLParams, palette: [string, string]) {
    this.setPalette(palette[0], palette[1]);
    const E = p.emb, U = this.bgU;
    U.uTime!.value = p.W; U.uStatic!.value = p.stat; U.uGlitch!.value = p.glitch;
    (U.uGlow!.value as THREE.Vector2).set(E.pos[0] / HW, 1 - E.pos[1] / HH);
    U.uGlowR!.value = (E.pos[2] / HH) * 1.7;
    U.uGlowI!.value = E.alpha * (0.6 + 0.8 * E.pulse);
    const G = this.emblem;
    G.position.set(E.pos[0] - HW / 2, HH / 2 - E.pos[1], 0);
    G.scale.setScalar(Math.max(0.001, E.pos[2] * (1 + 0.16 * E.pulse)));
    const asm = E.assemble.reduce((s, v) => s + v, 0) / E.assemble.length;
    G.rotation.x = E.tilt * 0.28 * Math.sin(p.W * 0.37) + (1 - asm) * 1.1;
    G.rotation.y = E.tilt * 0.42 * Math.sin(p.W * 0.29);
    this.rings.forEach((Rr, i) => {
      Rr.rg.rotation.z = RINGS[i]!.spin * E.spinT;
      const a0 = E.assemble[i] ?? 1;
      const disp = Math.max(1 - a0, E.explode);
      for (const a of Rr.arcs) {
        const u = a.userData;
        a.position.set(u.dx * disp * 1.3, u.dy * disp * 1.3, disp * 2.2 * (u.h - 0.5));
        a.rotation.x = (1 - a0) * 2.2 * (u.h > 0.5 ? 1 : -1);
      }
    });
    const boost = 1 + 1.3 * E.pulse;
    this.matA.opacity = E.alpha; this.matB.opacity = E.alpha;
    this.glowA.opacity = E.alpha * 0.2 * boost; this.glowB.opacity = E.alpha * 0.18 * boost;
    this.matA.color.copy(this.colA).multiplyScalar(boost); this.matB.color.copy(this.colB).multiplyScalar(boost);
    this.glowA.color.copy(this.colA); this.glowB.color.copy(this.colB);
    const R = this.renderer;
    R.clear();
    R.render(this.bgScene, this.bgCam);
    R.clearDepth();
    R.render(this.scene, this.cam);
  }

  dispose() {
    for (const d of this.disposables) { try { d.dispose(); } catch { /* already gone */ } }
    try { this.renderer.dispose(); this.renderer.forceContextLoss(); } catch { /* already lost */ }
  }
}
