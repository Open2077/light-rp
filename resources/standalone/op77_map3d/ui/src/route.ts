import * as THREE from "three";
import type { Route } from "./gps";

// The route on the map: a ribbon expanded on the GPU to a constant on-screen width,
// chevrons flowing toward the destination, the travelled part dimmed. A second,
// faint pass shows the part hidden behind buildings. A beam marks the destination.

const VERT = /* glsl */ `
attribute vec3 aDir; attribute float aSide; attribute float aDist;
uniform float uWidth;
varying float vSide; varying float vDist; varying vec3 vWorld;
void main(){
  vec3 side = normalize(vec3(-aDir.z, 0.0, aDir.x));
  float camDist = distance(cameraPosition, position);
  float w = uWidth * (camDist * 0.0085 + 2.6);
  vec3 p = position + side * aSide * w * 0.5;
  vSide = aSide; vDist = aDist; vWorld = p;
  gl_Position = projectionMatrix * viewMatrix * vec4(p, 1.0);
}`;
const FRAG = /* glsl */ `
uniform vec3 uColor; uniform vec3 uCore; uniform float uTime; uniform float uSpeed; uniform float uProgress; uniform float uAlpha; uniform float uSpacing;
varying float vSide; varying float vDist; varying vec3 vWorld;
void main(){
  float camDist = distance(cameraPosition, vWorld);
  float spacing = uSpacing * (camDist * 0.004 + 1.0);
  float u = vDist / spacing - uTime * uSpeed;
  // the edges trail the centre line: each chevron points toward the destination
  float chev = fract(u + abs(vSide) * 0.45);
  float arrow = smoothstep(0.0, 0.06, chev) * (1.0 - smoothstep(0.32, 0.4, chev));
  float edge = smoothstep(0.62, 0.98, abs(vSide));
  vec3 c = mix(uColor * 0.8, uCore, arrow * 0.9);
  c = mix(c, uColor * 1.25, edge);
  float done = step(vDist, uProgress);
  float a = uAlpha * mix(1.0, 0.28, done) * (1.0 - smoothstep(0.96, 1.0, abs(vSide)) * 0.5);
  gl_FragColor = vec4(c, a);
}`;

export class RouteView {
  readonly group = new THREE.Group();
  private uniforms = {
    uWidth: { value: 1 },
    uColor: { value: new THREE.Color("#ffcc00") },
    uCore: { value: new THREE.Color("#fff6c2") },
    uTime: { value: 0 },
    uSpeed: { value: 1.6 },
    uProgress: { value: 0 },
    uAlpha: { value: 0.95 },
    uSpacing: { value: 9 },
  };
  private visible: THREE.Mesh;
  private hidden: THREE.Mesh;
  private beam: THREE.Mesh;
  private ring: THREE.Mesh;
  // performance mode: the chevrons and the destination stand still (no redraw for them)
  private still = false;

  constructor() {
    const visMat = new THREE.ShaderMaterial({ uniforms: this.uniforms, vertexShader: VERT, fragmentShader: FRAG, transparent: true, depthWrite: false });
    const hiddenUniforms = { ...this.uniforms, uAlpha: { value: 0.4 } };
    const hidMat = new THREE.ShaderMaterial({ uniforms: hiddenUniforms, vertexShader: VERT, fragmentShader: FRAG, transparent: true, depthWrite: false, depthFunc: THREE.GreaterDepth });
    this.visible = new THREE.Mesh(new THREE.BufferGeometry(), visMat);
    this.hidden = new THREE.Mesh(new THREE.BufferGeometry(), hidMat);
    this.visible.renderOrder = 10;
    this.hidden.renderOrder = 9;
    this.visible.frustumCulled = this.hidden.frustumCulled = false;
    const beamMat = new THREE.ShaderMaterial({
      uniforms: { uColor: this.uniforms.uColor, uTime: this.uniforms.uTime },
      vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
      fragmentShader: `uniform vec3 uColor; uniform float uTime; varying vec2 vUv;
        void main(){ float a = (1.0 - vUv.y) * (0.55 + 0.25 * sin(uTime * 3.0 + vUv.y * 12.0)); gl_FragColor = vec4(uColor, a * 0.7); }`,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    this.beam = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 1, 24, 1, true), beamMat);
    this.ring = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 48), new THREE.MeshBasicMaterial({ color: "#ffcc00", transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide }));
    this.ring.rotation.x = -Math.PI / 2;
    this.group.add(this.hidden, this.visible, this.beam, this.ring);
    this.group.visible = false;
  }

  setColors(accent: string): void {
    this.uniforms.uColor.value.set(accent);
    this.uniforms.uCore.value.set(accent).lerp(new THREE.Color("#ffffff"), 0.7);
    (this.ring.material as THREE.MeshBasicMaterial).color.set(accent);
  }
  setWidth(w: number) { this.uniforms.uWidth.value = w; }
  setSpeed(s: number) { this.uniforms.uSpeed.value = s; }
  setProgress(m: number) { this.uniforms.uProgress.value = m; }
  tick(t: number) { if (!this.still) this.uniforms.uTime.value = t; }
  setPerformance(on: boolean) { this.still = on; }

  set(route: Route | null): void {
    if (!route) { this.group.visible = false; return; }
    const P = route.points, n = route.cumulative.length;
    const pos = new Float32Array(n * 2 * 3), dir = new Float32Array(n * 2 * 3), side = new Float32Array(n * 2), dist = new Float32Array(n * 2);
    for (let i = 0; i < n; i++) {
      const a = Math.max(0, i - 1), b = Math.min(n - 1, i + 1);
      const dx = P[b * 3] - P[a * 3], dy = P[b * 3 + 1] - P[a * 3 + 1];
      const l = Math.hypot(dx, dy) || 1;
      for (let s = 0; s < 2; s++) {
        const k = i * 2 + s;
        pos[k * 3] = P[i * 3]; pos[k * 3 + 1] = P[i * 3 + 2] + 1.8; pos[k * 3 + 2] = -P[i * 3 + 1];
        dir[k * 3] = dx / l; dir[k * 3 + 1] = 0; dir[k * 3 + 2] = -dy / l;
        side[k] = s === 0 ? -1 : 1;
        dist[k] = route.cumulative[i];
      }
    }
    const idx: number[] = [];
    for (let i = 0; i < n - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    g.setAttribute("aDir", new THREE.BufferAttribute(dir, 3));
    g.setAttribute("aSide", new THREE.BufferAttribute(side, 1));
    g.setAttribute("aDist", new THREE.BufferAttribute(dist, 1));
    g.setIndex(idx);
    this.visible.geometry.dispose();
    this.visible.geometry = g;
    this.hidden.geometry = g;
    const end = route.destination;
    const z = P[(n - 1) * 3 + 2];
    this.beam.position.set(end.x, z + 60, -end.y);
    this.ring.position.set(end.x, z + 0.8, -end.y);
    this.group.visible = true;
  }

  /** The destination marker keeps a readable size at any zoom. */
  scaleMarkers(cameraDistance: number, time: number): void {
    const s = Math.max(4, cameraDistance * 0.012);
    this.beam.scale.set(s * 0.35, 120 + cameraDistance * 0.05, s * 0.35);
    this.beam.position.y = this.ring.position.y + this.beam.scale.y / 2;
    const phase = this.still ? 0.35 : (time * 0.8) % 1;
    this.ring.scale.setScalar(s * 1.6 * (1 + 0.35 * phase));
    (this.ring.material as THREE.MeshBasicMaterial).opacity = 0.9 * (1 - phase);
  }
}
