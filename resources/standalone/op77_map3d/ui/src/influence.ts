import * as THREE from "three";
import type { WorldUniforms } from "./world";

// Influence zones: where the players are (the server groups them, shared/influence.lua).
// Each zone is a heat field on the ground (isolines drifting outward, a hex grid that
// twinkles with the crowd, pulse waves, a turning dashed rim), a column of light over
// the busier ones, and the buildings inside it light up in its colour (world.ts reads
// uZone*). Colours and the number of waves follow the density level.

export interface InfluenceZone { id: string; x: number; y: number; z: number; radius: number; count: number; level: number }
export interface InfluenceLook { colors: string[]; beaconLevel: number; buildings: boolean }

export const MAX_ZONES = 24;
const FIELD = 1.35; // the ground field reaches this far past the zone's radius

interface Live {
  zone: InfluenceZone;
  // eased toward the zone (the server's updates are seconds apart)
  x: number; y: number; z: number; radius: number; level: number;
  alpha: number; target: number; seed: number;
  field: THREE.Mesh; beacon: THREE.Mesh;
  fieldMat: THREE.ShaderMaterial; stillMat: THREE.ShaderMaterial; beaconMat: THREE.ShaderMaterial;
  color: THREE.Color;
}

const FIELD_VERTEX = /* glsl */ `
  varying vec2 vP; varying vec3 vWorld;
  void main(){ vP = position.xy; vec4 w = modelMatrix * vec4(position, 1.0); vWorld = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`;
const FIELD_FRAGMENT = /* glsl */ `
  uniform vec3 uColor; uniform float uAlpha; uniform float uLevel; uniform float uTime; uniform float uSeed; uniform float uRadius;
  uniform vec3 uFogColor; uniform float uFogNear; uniform float uFogFar;
  varying vec2 vP; varying vec3 vWorld;
  const float TAU = 6.2831853;
  float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
  // a thin line where x crosses a whole number, about one and a half pixels wide
  float lineAt(float x){ float d = abs(fract(x + 0.5) - 0.5); return 1.0 - smoothstep(0.0, fwidth(x) * 1.6, d); }
  void main(){
    float r = length(vP) * ${FIELD.toFixed(2)};           // 1.0 = the zone's radius
    if (r > ${FIELD.toFixed(2)}) discard;
    float lv = uLevel;                                      // 1..4
    float heat = pow(1.0 - smoothstep(0.0, 1.08, r), 1.7);
    // isolines, more of them in a denser zone, drifting outward
    float iso = lineAt(r * (2.0 + lv) - uTime * 0.12) * smoothstep(1.15, 0.2, r);
    // a hex grid in world space: faint cell outlines, cells that light up with the crowd
    vec2 p = vWorld.xz / 16.0;
    vec2 a = mod(p, vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
    vec2 b = mod(p - vec2(0.5, 0.8660254), vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
    vec2 g = dot(a, a) < dot(b, b) ? a : b;
    vec2 cell = p - g;
    float hexD = max(dot(abs(g), vec2(0.8660254, 0.5)), abs(g.y));
    float hexEdge = 1.0 - smoothstep(0.0, fwidth(hexD) * 1.5, abs(hexD - 0.5));
    float n = hash(cell + uSeed);
    float lit = step(1.0 - heat * (0.25 + 0.12 * lv), n) * (0.55 + 0.45 * sin(uTime * (1.5 + n * 3.0) + n * TAU));
    float fill = lit * (1.0 - smoothstep(0.32, 0.5, hexD));
    // pulse waves leaving the centre: faster and more of them as the zone fills up
    float pulse = 0.0;
    for (int i = 0; i < 3; i++) {
      if (float(i) >= min(lv, 3.0)) break;
      float ph = fract(uTime * (0.16 + 0.05 * lv) + float(i) / 3.0 + uSeed);
      float ring = 1.0 - smoothstep(0.0, 0.035 + 0.02 * ph, abs(r - ph * 1.25));
      pulse += ring * pow(1.0 - ph, 1.6);
    }
    // the rim: dashes turning slowly, on the zone's radius
    float ang = atan(vP.y, vP.x) / TAU;
    float dash = step(0.45, fract(ang * (24.0 + 8.0 * lv) + uTime * 0.04 * (mod(uSeed * 10.0, 2.0) > 1.0 ? 1.0 : -1.0)));
    float rim = (1.0 - smoothstep(0.0, fwidth(r) * 2.0, abs(r - 1.0))) * dash;
    float k = 0.55 + 0.15 * lv;
    vec3 c = uColor * (heat * 0.32 + iso * 0.30 + hexEdge * heat * 0.22 + fill * heat * 0.75 + pulse * 0.85 + rim * 0.9) * k;
    float fog = smoothstep(uFogNear, uFogFar, distance(cameraPosition, vWorld));
    gl_FragColor = vec4(c * uAlpha * (1.0 - fog), 1.0);
  }`;

// Performance mode: the same disc, still (no isolines, hex cells, waves or turning rim):
// its colour fading from the centre and a plain rim on the radius.
const STILL_FRAGMENT = /* glsl */ `
  uniform vec3 uColor; uniform float uAlpha; uniform float uLevel;
  varying vec2 vP;
  void main(){
    float r = length(vP) * ${FIELD.toFixed(2)};
    if (r > ${FIELD.toFixed(2)}) discard;
    float heat = pow(1.0 - smoothstep(0.0, 1.08, r), 1.7);
    float rim = 1.0 - smoothstep(0.0, fwidth(r) * 2.0, abs(r - 1.0));
    gl_FragColor = vec4(uColor * (heat * 0.4 + rim * 0.9) * (0.55 + 0.15 * uLevel) * uAlpha, 1.0);
  }`;

const BEACON_VERTEX = /* glsl */ `
  varying float vH; varying vec3 vWorld; varying vec3 vN;
  void main(){ vH = position.y; vec4 w = modelMatrix * vec4(position, 1.0); vWorld = w.xyz; vN = normalize(mat3(modelMatrix) * normal); gl_Position = projectionMatrix * viewMatrix * w; }`;
const BEACON_FRAGMENT = /* glsl */ `
  uniform vec3 uColor; uniform float uAlpha; uniform float uTime; uniform float uLevel;
  uniform vec3 uFogColor; uniform float uFogNear; uniform float uFogFar;
  varying float vH; varying vec3 vWorld; varying vec3 vN;
  void main(){
    vec3 v = normalize(cameraPosition - vWorld);
    float edge = pow(1.0 - abs(dot(normalize(vN), v)), 1.5);     // the column's sides glow, its middle is thin
    float fade = pow(1.0 - vH, 1.4);
    float bands = smoothstep(0.75, 1.0, fract(vH * (6.0 + 2.0 * uLevel) - uTime * 0.7));
    float k = fade * (0.25 + edge * 0.75) + bands * fade * 0.5;
    float fog = smoothstep(uFogNear, uFogFar, distance(cameraPosition, vWorld));
    gl_FragColor = vec4(uColor * k * uAlpha * (0.6 + 0.1 * uLevel) * (1.0 - fog), 1.0);
  }`;

export class InfluenceLayer {
  readonly group = new THREE.Group();
  private live = new Map<string, Live>();
  private look: InfluenceLook = { colors: ["#3FE0D0", "#FFCC00", "#FF8A1F", "#FF2E3C"], beaconLevel: 2, buildings: true };
  private fieldGeo = new THREE.CircleGeometry(1, 96);
  private beaconGeo = new THREE.CylinderGeometry(1, 1, 1, 40, 1, true).translate(0, 0.5, 0);
  private shown = true;
  private beacons = true;
  // performance mode: still discs, no beacons, no lit buildings, no easing (no redraws)
  private still = false;

  constructor(private uniforms: WorldUniforms) {
    this.group.name = "influence";
    this.group.renderOrder = 3;
  }

  setLook(look: Partial<InfluenceLook>): void {
    this.look = { ...this.look, ...look };
    for (const l of this.live.values()) this.paint(l);
  }

  /** The zones the server sent; the ones that left fade out. */
  set(zones: InfluenceZone[]): void {
    const seen = new Set<string>();
    for (const z of zones.slice(0, MAX_ZONES)) {
      seen.add(z.id);
      const l = this.live.get(z.id);
      if (l) { l.zone = z; l.target = 1; this.paint(l); continue; }
      this.live.set(z.id, this.create(z));
    }
    for (const [id, l] of this.live) if (!seen.has(id)) l.target = 0;
  }

  /** On the open map (beacons) or the minimap (the ground and the buildings only). */
  setView(full: boolean, visible: boolean): void {
    this.beacons = full;
    this.shown = visible;
    this.group.visible = visible;
  }

  /** Something is drawn and moves: the view must keep redrawing. */
  get active(): boolean { return !this.still && this.shown && this.live.size > 0; }

  setPerformance(on: boolean): void {
    this.still = on;
    for (const l of this.live.values()) l.field.material = on ? l.stillMat : l.fieldMat;
  }

  zonesForLabels(): { zone: InfluenceZone; color: string; alpha: number; top: THREE.Vector3 }[] {
    const out = [];
    for (const l of this.live.values()) {
      const h = l.level >= this.look.beaconLevel ? 120 + 90 * l.level : 40;
      out.push({ zone: l.zone, color: "#" + l.color.getHexString(), alpha: l.alpha, top: new THREE.Vector3(l.x, l.z + h, -l.y) });
    }
    return out;
  }

  tick(t: number, dt: number): void {
    const ease = this.still ? 1 : 1 - Math.exp(-dt * 3);
    const zones = this.uniforms.uZone.value, colors = this.uniforms.uZoneColor.value;
    let n = 0;
    for (const [id, l] of this.live) {
      const z = l.zone;
      l.x += (z.x - l.x) * ease; l.y += (z.y - l.y) * ease; l.z += (z.z - l.z) * ease;
      l.radius += (z.radius - l.radius) * ease; l.level += (z.level - l.level) * ease;
      l.alpha = this.still ? l.target : l.alpha + (l.target - l.alpha) * (1 - Math.exp(-dt * (l.target > l.alpha ? 2.5 : 4)));
      if (l.target === 0 && l.alpha < 0.01) { this.dispose(l); this.live.delete(id); continue; }
      const R = l.radius * FIELD;
      l.field.position.set(l.x, l.z + 3, -l.y);
      l.field.scale.set(R, R, 1);
      const fu = l.fieldMat.uniforms;
      fu.uAlpha.value = l.alpha; fu.uLevel.value = l.level; fu.uTime.value = t; fu.uRadius.value = l.radius;
      const su = l.stillMat.uniforms;
      su.uAlpha.value = l.alpha; su.uLevel.value = l.level;
      const beacon = this.beacons && !this.still && z.level >= this.look.beaconLevel;
      l.beacon.visible = beacon;
      if (beacon) {
        const rb = THREE.MathUtils.clamp(l.radius * 0.05, 5, 28);
        l.beacon.position.set(l.x, l.z, -l.y);
        l.beacon.scale.set(rb, 120 + 90 * l.level, rb);
        const bu = l.beaconMat.uniforms;
        bu.uAlpha.value = l.alpha; bu.uTime.value = t; bu.uLevel.value = l.level;
      }
      if (this.look.buildings && !this.still && n < MAX_ZONES) {
        zones[n].set(l.x, -l.y, l.radius, l.alpha * (0.55 + 0.12 * l.level));
        colors[n].copy(l.color);
        n++;
      }
    }
    this.uniforms.uZoneCount.value = this.shown ? n : 0;
  }

  clear(): void { for (const l of this.live.values()) l.target = 0; }

  private create(z: InfluenceZone): Live {
    const common = { uFogColor: this.uniforms.uFogColor, uFogNear: this.uniforms.uFogNear, uFogFar: this.uniforms.uFogFar };
    const fieldMat = new THREE.ShaderMaterial({
      uniforms: { ...common, uColor: { value: new THREE.Color() }, uAlpha: { value: 0 }, uLevel: { value: z.level }, uTime: { value: 0 },
        uSeed: { value: Math.random() }, uRadius: { value: z.radius } },
      vertexShader: FIELD_VERTEX, fragmentShader: FIELD_FRAGMENT,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    const beaconMat = new THREE.ShaderMaterial({
      uniforms: { ...common, uColor: { value: new THREE.Color() }, uAlpha: { value: 0 }, uTime: { value: 0 }, uLevel: { value: z.level } },
      vertexShader: BEACON_VERTEX, fragmentShader: BEACON_FRAGMENT,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    const stillMat = new THREE.ShaderMaterial({
      uniforms: { uColor: { value: new THREE.Color() }, uAlpha: { value: 0 }, uLevel: { value: z.level } },
      vertexShader: FIELD_VERTEX, fragmentShader: STILL_FRAGMENT,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    const field = new THREE.Mesh(this.fieldGeo, this.still ? stillMat : fieldMat);
    field.rotation.x = -Math.PI / 2;
    field.renderOrder = 3;
    field.frustumCulled = false;
    const beacon = new THREE.Mesh(this.beaconGeo, beaconMat);
    beacon.renderOrder = 4;
    beacon.frustumCulled = false;
    this.group.add(field, beacon);
    const l: Live = { zone: z, x: z.x, y: z.y, z: z.z, radius: z.radius * 0.6, level: z.level, alpha: 0, target: 1,
      seed: Math.random(), field, beacon, fieldMat, stillMat, beaconMat, color: new THREE.Color() };
    this.paint(l);
    return l;
  }

  private paint(l: Live): void {
    const c = this.look.colors;
    l.color.set(c[Math.max(0, Math.min(c.length - 1, Math.round(l.zone.level) - 1))] ?? "#FFCC00");
    l.fieldMat.uniforms.uColor.value.copy(l.color);
    l.stillMat.uniforms.uColor.value.copy(l.color);
    l.beaconMat.uniforms.uColor.value.copy(l.color);
  }

  private dispose(l: Live): void {
    this.group.remove(l.field, l.beacon);
    l.fieldMat.dispose();
    l.stillMat.dispose();
    l.beaconMat.dispose();
  }
}
