import * as THREE from "three";
import type { MapData } from "./data";
import type { Theme } from "./config";
import { MAX_ZONES } from "./influence";
import { AREA_GLSL, areaUniforms, type AreaUniforms } from "./areas";

// The city: the game's own 3D map meshes and its building point cloud, drawn with
// flat, theme-driven shaders (no lights, no textures): black volumes, yellow lines.
// Areas (areas.ts) are draped over every surface by the same shaders.

const FOG = /* glsl */ `
uniform vec3 uFogColor; uniform float uFogNear; uniform float uFogFar;
float fogFactor(vec3 w){ float d = distance(cameraPosition, w); return smoothstep(uFogNear, uFogFar, d); }
`;
// A key light and a cool fill from the other side: walls facing different ways read apart.
const FLAT_NORMAL = /* glsl */ `
vec3 flatNormal(vec3 w){ return normalize(cross(dFdx(w), dFdy(w))); }
float light(vec3 n){
  vec3 K = normalize(vec3(-0.45, 0.85, 0.35)), F = normalize(vec3(0.6, 0.25, -0.75));
  return 0.5 + 0.55 * max(dot(n, K), 0.0) + 0.22 * max(dot(n, F), 0.0);
}
`;

export interface WorldUniforms extends AreaUniforms {
  uFogColor: { value: THREE.Color };
  uFogNear: { value: number };
  uFogFar: { value: number };
  uTime: { value: number };
  uLod: { value: number };
  uFocus: { value: THREE.Vector3 };
  uCut: { value: number };
  // influence zones (influence.ts): scene x, scene z, radius, strength; their colours; how many
  uZone: { value: THREE.Vector4[] };
  uZoneColor: { value: THREE.Color[] };
  uZoneCount: { value: number };
}

export class World {
  readonly root = new THREE.Group();
  readonly uniforms: WorldUniforms;
  readonly pickables: THREE.Mesh[] = [];
  private layers = new Map<string, THREE.Object3D>();
  private materials: THREE.ShaderMaterial[] = [];
  private buildingGroup = new THREE.Group();
  private theme!: Theme;
  // Performance mode (2D, see app.ts): every mesh has a cheap twin of its material (flat
  // colours, no lighting, grid, fog, zones or x-ray) and the buildings their roofs only
  // (one quad per box instead of 36 indices).
  private swaps: { mesh: THREE.Mesh; geometry: [THREE.BufferGeometry, THREE.BufferGeometry]; material: [THREE.Material, THREE.Material] }[] = [];
  private performance = false;

  /** `areas`: the area layer's uniforms (areas.ts), shared by every material. */
  constructor(data: MapData, theme: Theme, areas: AreaUniforms = areaUniforms()) {
    this.uniforms = {
      uFogColor: { value: new THREE.Color() },
      uFogNear: { value: 3000 },
      uFogFar: { value: 12000 },
      uTime: { value: 0 },
      uLod: { value: 0.0025 },
      uFocus: { value: new THREE.Vector3() },
      uCut: { value: 0 },
      uZone: { value: Array.from({ length: MAX_ZONES }, () => new THREE.Vector4()) },
      uZoneColor: { value: Array.from({ length: MAX_ZONES }, () => new THREE.Color()) },
      uZoneCount: { value: 0 },
      ...areas,
    };
    this.root.add(this.buildingGroup);
    this.buildLayers(data);
    this.buildBuildings(data);
    this.applyTheme(theme);
  }

  layer(name: string): THREE.Object3D | undefined { return name === "buildings" ? this.buildingGroup : this.layers.get(name); }
  setLayerVisible(name: string, v: boolean): void { const l = this.layer(name); if (l) l.visible = v; }

  /** Performance mode: the cheap materials and the roofs-only buildings (and back). */
  setPerformance(on: boolean): void {
    if (on === this.performance) return;
    this.performance = on;
    const k = on ? 1 : 0;
    for (const s of this.swaps) { s.mesh.geometry = s.geometry[k]; s.mesh.material = s.material[k]; }
  }

  private material(kind: string, extra: Record<string, { value: unknown }>, vertex: string, fragment: string, opts: Partial<THREE.ShaderMaterialParameters> = {}) {
    const m = new THREE.ShaderMaterial({
      uniforms: { ...this.uniforms, ...extra },
      vertexShader: vertex,
      fragmentShader: fragment,
      ...opts,
    });
    m.name = kind;
    this.materials.push(m);
    return m;
  }

  private buildLayers(data: MapData) {
    const simpleVertex = /* glsl */ `
      varying vec3 vWorld;
      void main(){ vec4 w = modelMatrix * vec4(position, 1.0); vWorld = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`;
    const surface = (gridStrength: number) => /* glsl */ `
      uniform vec3 uColor; uniform vec3 uGrid; uniform float uGridStrength;
      varying vec3 vWorld;
      ${FOG}${FLAT_NORMAL}${AREA_GLSL}
      float gridLine(vec2 p, float step){ vec2 g = abs(fract(p / step - 0.5) - 0.5) * step; vec2 w = fwidth(p) * 1.2; vec2 l = 1.0 - smoothstep(vec2(0.0), w, g); return max(l.x, l.y); }
      void main(){
        vec3 n = flatNormal(vWorld);
        vec3 c = uColor * light(n);
        float d = distance(cameraPosition, vWorld);
        float minor = gridLine(vWorld.xz, 100.0) * (1.0 - smoothstep(600.0, 2200.0, d));
        float major = gridLine(vWorld.xz, 1000.0) * (1.0 - smoothstep(4000.0, 14000.0, d));
        c = mix(c, uGrid, (minor * 0.05 + major * 0.11) * uGridStrength * ${gridStrength.toFixed(2)});
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        c = mix(c, ar.rgb, ar.a);
        gl_FragColor = vec4(mix(c, uFogColor, fogFactor(vWorld)), 1.0);
      }`;
    // Roads and rails are flat colour: screen-space normals on their thin triangles shimmer.
    const flat = /* glsl */ `
      uniform vec3 uColor; varying vec3 vWorld;
      ${FOG}${AREA_GLSL}
      void main(){
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        gl_FragColor = vec4(mix(mix(uColor, ar.rgb, ar.a), uFogColor, fogFactor(vWorld)), 1.0);
      }`;
    // Road lines are thinner than a pixel from afar: they fade out before they can flicker.
    const lines = /* glsl */ `
      uniform vec3 uColor; uniform float uAlpha; varying vec3 vWorld;
      ${FOG}${AREA_GLSL}
      void main(){
        float d = distance(cameraPosition, vWorld);
        float f = fogFactor(vWorld) + smoothstep(700.0, 2600.0, d);
        float ain; vec3 afc; areaAt(vWorld, 0.0, ain, afc);
        gl_FragColor = vec4(mix(uColor, afc, ain * 0.85), uAlpha * clamp(1.0 - f, 0.0, 1.0));
      }`;
    const water = /* glsl */ `
      uniform vec3 uColor; uniform vec3 uLine; varying vec3 vWorld;
      ${FOG}${AREA_GLSL}
      void main(){
        float scan = smoothstep(0.92, 1.0, abs(sin(vWorld.z * 0.06))) * 0.1;
        vec3 c = mix(uColor, uLine, scan * (1.0 - smoothstep(800.0, 3000.0, distance(cameraPosition, vWorld))));
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        c = mix(c, ar.rgb, ar.a);
        gl_FragColor = vec4(mix(c, uFogColor, fogFactor(vWorld)), 1.0);
      }`;
    const landmark = /* glsl */ `
      uniform vec3 uColor; uniform vec3 uEdge; varying vec3 vWorld;
      ${FOG}${FLAT_NORMAL}${AREA_GLSL}
      void main(){
        vec3 n = flatNormal(vWorld); vec3 v = normalize(cameraPosition - vWorld);
        float rim = pow(1.0 - abs(dot(n, v)), 2.5);
        vec3 c = uColor * light(n) + uEdge * rim * 0.65;
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, smoothstep(0.6, 0.95, n.y), ain, afc);
        c = mix(c + afc * rim * 0.5 * ain, ar.rgb, ar.a);
        gl_FragColor = vec4(mix(c, uFogColor, fogFactor(vWorld)), 1.0);
      }`;
    // Performance twins: one flat colour (the grid's major lines on the ground), the areas
    // kept (they are gameplay information, not decoration).
    const flatPerf = (k: number, grid: boolean) => /* glsl */ `
      uniform vec3 uColor; ${grid ? "uniform vec3 uGrid; uniform float uGridStrength;" : ""} varying vec3 vWorld;
      ${AREA_GLSL}
      float gridLine(vec2 p, float step){ vec2 g = abs(fract(p / step - 0.5) - 0.5) * step; vec2 w = fwidth(p) * 1.2; vec2 l = 1.0 - smoothstep(vec2(0.0), w, g); return max(l.x, l.y); }
      void main(){
        vec3 c = uColor * ${k.toFixed(2)};
        ${grid ? "c = mix(c, uGrid, gridLine(vWorld.xz, 1000.0) * 0.1 * uGridStrength);" : ""}
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        gl_FragColor = vec4(mix(c, ar.rgb, ar.a), 1.0);
      }`;
    const landmarkPerf = /* glsl */ `
      uniform vec3 uColor; uniform vec3 uEdge; varying vec3 vWorld;
      ${AREA_GLSL}
      void main(){
        vec3 c = mix(uColor * 1.1, uEdge, 0.14);
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        gl_FragColor = vec4(mix(c, ar.rgb, ar.a), 1.0);
      }`;
    const perfKinds: Record<string, THREE.ShaderMaterial> = {
      terrain: this.material("terrain", { uColor: { value: new THREE.Color() }, uGrid: { value: new THREE.Color() }, uGridStrength: { value: 1 } }, simpleVertex, flatPerf(1, true)),
      cliffs: this.material("cliffs", { uColor: { value: new THREE.Color() }, uGrid: { value: new THREE.Color() }, uGridStrength: { value: 0 } }, simpleVertex, flatPerf(0.85, false)),
      water: this.material("water", { uColor: { value: new THREE.Color() }, uLine: { value: new THREE.Color() } }, simpleVertex, flatPerf(1, false)),
      landmarks: this.material("landmarks", { uColor: { value: new THREE.Color() }, uEdge: { value: new THREE.Color() } }, simpleVertex, landmarkPerf),
    };
    const kinds: Record<string, THREE.ShaderMaterial> = {
      terrain: this.material("terrain", { uColor: { value: new THREE.Color() }, uGrid: { value: new THREE.Color() }, uGridStrength: { value: 1 } }, simpleVertex, surface(1)),
      cliffs: this.material("cliffs", { uColor: { value: new THREE.Color() }, uGrid: { value: new THREE.Color() }, uGridStrength: { value: 0 } }, simpleVertex, surface(0)),
      water: this.material("water", { uColor: { value: new THREE.Color() }, uLine: { value: new THREE.Color() } }, simpleVertex, water),
      roads: this.material("roads", { uColor: { value: new THREE.Color() } }, simpleVertex, flat, { polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }),
      roadBorders: this.material("roadBorders", { uColor: { value: new THREE.Color() }, uAlpha: { value: 0.22 } }, simpleVertex, lines,
        { transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 }),
      metro: this.material("metro", { uColor: { value: new THREE.Color() } }, simpleVertex, flat),
      landmarks: this.material("landmarks", { uColor: { value: new THREE.Color() }, uEdge: { value: new THREE.Color() } }, simpleVertex, landmark),
    };
    for (const child of [...data.world.children]) {
      const name = child.name;
      const mat = kinds[name] ?? kinds.cliffs;
      child.traverse((o) => {
        const mesh = o as THREE.Mesh;
        if (!mesh.isMesh) return;
        mesh.material = mat;
        // roads, road lines and the metro are flat colour already: they keep their material
        const perf = perfKinds[name] ?? (kinds[name] ? mat : perfKinds.cliffs);
        if (perf !== mat) this.swaps.push({ mesh, geometry: [mesh.geometry, mesh.geometry], material: [mat, perf] });
        mesh.frustumCulled = name !== "terrain" && name !== "water";
        if (name === "terrain" || name === "roads") this.pickables.push(mesh);
      });
      child.renderOrder = name === "roadBorders" ? 2 : name === "roads" ? 1 : 0;
      this.layers.set(name, child);
      this.root.add(child);
    }
  }

  private buildBuildings(data: MapData) {
    const stride = data.manifest.buildings.stride;
    const box = new THREE.BoxGeometry(1, 1, 1);
    const vertex = /* glsl */ `
      attribute vec3 iPos; attribute vec4 iQuat; attribute vec3 iSize;
      uniform vec3 uMin; uniform vec3 uSpan; uniform float uMaxSize; uniform float uLod;
      varying vec3 vLocal; varying vec3 vLocalN; varying vec3 vSize; varying vec3 vWorld; varying float vTall; varying vec3 vNormal;
      vec3 qrot(vec4 q, vec3 v){ return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v); }
      void main(){
        vec3 c = uMin + iPos * uSpan;
        vec3 s = max(iSize * uMaxSize, vec3(0.25));
        float far = distance(cameraPosition, c);
        // small boxes far away shrink away smoothly instead of popping in and out
        float th = far * uLod;
        float keep = smoothstep(th, th * 1.7, max(s.x, max(s.y, s.z)));
        if (keep < 0.01) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }
        s *= keep;
        vec4 q = normalize(iQuat);
        vec3 w = c + qrot(q, position * s);
        vLocal = position; vLocalN = normal; vSize = s; vWorld = w; vNormal = qrot(q, normal);
        vTall = clamp((c.y + s.y * 0.5) / 260.0, 0.0, 1.0);
        gl_Position = projectionMatrix * viewMatrix * vec4(w, 1.0);
      }`;
    const fragment = /* glsl */ `
      uniform vec3 uFace; uniform vec3 uTop; uniform vec3 uEdge; uniform float uEdgeStrength;
      uniform vec3 uFocus; uniform float uCut; uniform float uTime;
      uniform vec4 uZone[${MAX_ZONES}]; uniform vec3 uZoneColor[${MAX_ZONES}]; uniform int uZoneCount;
      varying vec3 vLocal; varying vec3 vLocalN; varying vec3 vSize; varying vec3 vWorld; varying float vTall; varying vec3 vNormal;
      ${FOG}${FLAT_NORMAL}${AREA_GLSL}
      void main(){
        // x-ray: what stands between the camera and the focus (the player on the minimap)
        // is cut away inside a cone, with a screen-door rim so the volume still reads
        if (uCut > 0.0) {
          vec3 toF = uFocus - cameraPosition; float L = length(toF); vec3 dir = toF / L;
          vec3 r = vWorld - cameraPosition; float t = dot(r, dir);
          if (t > 0.0 && t < L - 1.5) {
            float rad = uCut * (0.75 + 0.25 * t / L);
            float k = 1.0 - smoothstep(rad * 0.65, rad, length(r - dir * t));
            float cell = mod(floor(gl_FragCoord.x) + floor(gl_FragCoord.y), 2.0);
            if (k > 0.9 || (k > 0.35 && cell > 0.5) || (k > 0.1 && mod(floor(gl_FragCoord.x * 0.5) + floor(gl_FragCoord.y * 0.5), 2.0) > 0.5 && cell > 0.5)) discard;
          }
        }
        vec3 d = (0.5 - abs(vLocal)) * vSize;
        vec3 an = abs(vLocalN);
        float e = 1e6, faceMin = 1e6;
        if (an.x < 0.5) { e = min(e, d.x); faceMin = min(faceMin, vSize.x); }
        if (an.y < 0.5) { e = min(e, d.y); faceMin = min(faceMin, vSize.y); }
        if (an.z < 0.5) { e = min(e, d.z); faceMin = min(faceMin, vSize.z); }
        float w = fwidth(e);
        // a soft line about 1.5 px wide: a hard 1 px line crawls as soon as the camera moves
        float line = 1.0 - smoothstep(w * 0.7, w * 2.1, e);
        // only faces many pixels wide get an outline: tiny boxes far away would turn into
        // flickering solid lines
        line *= smoothstep(w * 9.0, w * 24.0, faceMin);
        vec3 n = normalize(vNormal);
        float top = smoothstep(0.6, 0.95, n.y);
        vec3 base = mix(uFace, uTop, top) * light(n);
        base *= 0.85 + 0.45 * vTall;
        base += uEdge * 0.035 * vTall * (0.4 + 0.6 * top);
        float fade = fogFactor(vWorld);
        float strength = uEdgeStrength * mix(0.35, 0.8, vTall) * mix(1.0, 1.5, top);
        vec3 c = mix(base, uEdge, clamp(line * strength, 0.0, 1.0) * (1.0 - fade));
        // influence zones: inside one, the outlines take its colour and burn brighter, the
        // walls warm up from the ground and a scan band climbs them
        float zi = 0.0; vec3 zc = vec3(0.0);
        for (int i = 0; i < ${MAX_ZONES}; i++) {
          if (i >= uZoneCount) break;
          vec4 z = uZone[i];
          float k = (1.0 - smoothstep(z.z * 0.3, z.z * 1.08, distance(vWorld.xz, z.xy))) * z.w;
          if (k > zi) { zi = k; zc = uZoneColor[i]; }
        }
        if (zi > 0.002) {
          float h = vLocal.y + 0.5;
          float band = smoothstep(0.93, 1.0, fract(vWorld.y / 45.0 - uTime * 0.35));
          c = mix(c, zc * 1.35, clamp(line * (strength + 0.7), 0.0, 1.0) * zi * (1.0 - fade));
          c += zc * zi * (0.16 * pow(1.0 - h, 2.0) + band * 0.22 * (1.0 - top)) * (1.0 - fade);
        }
        // areas: inside one, the outlines take its colour, the roofs its hatching, the
        // walls a cast of it; its border runs over roofs and walls like over the ground
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, top, ain, afc);
        if (ar.a > 0.002 || ain > 0.002) {
          c = mix(c, afc * 1.3, clamp(line * (strength + 0.6), 0.0, 1.0) * ain * (1.0 - fade));
          c = mix(c, ar.rgb, ar.a * (1.0 - fade));
        }
        gl_FragColor = vec4(mix(c, uFogColor, fade), 1.0);
      }`;
    // Performance: the roof only, one quad per box seen from straight above, with its
    // outline (the map's look) and the areas; taller roofs are lighter so height still reads.
    const roofVertex = /* glsl */ `
      attribute vec3 iPos; attribute vec4 iQuat; attribute vec3 iSize;
      uniform vec3 uMin; uniform vec3 uSpan; uniform float uMaxSize; uniform float uLod;
      varying vec2 vLocal; varying vec2 vSize; varying vec3 vWorld; varying float vTall;
      vec3 qrot(vec4 q, vec3 v){ return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v); }
      void main(){
        vec3 c = uMin + iPos * uSpan;
        vec3 s = max(iSize * uMaxSize, vec3(0.25));
        float th = distance(cameraPosition, c) * uLod;
        float keep = smoothstep(th, th * 1.7, max(s.x, s.z));
        if (keep < 0.01) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }
        s *= keep;
        vec3 w = c + qrot(normalize(iQuat), vec3(position.x, 0.5, position.y) * s);
        vLocal = position.xy; vSize = s.xz; vWorld = w;
        vTall = clamp((c.y + s.y * 0.5) / 260.0, 0.0, 1.0);
        gl_Position = projectionMatrix * viewMatrix * vec4(w, 1.0);
      }`;
    const roofFragment = /* glsl */ `
      uniform vec3 uFace; uniform vec3 uTop; uniform vec3 uEdge; uniform float uEdgeStrength;
      varying vec2 vLocal; varying vec2 vSize; varying vec3 vWorld; varying float vTall;
      ${AREA_GLSL}
      void main(){
        vec2 d = (0.5 - abs(vLocal)) * vSize;
        float e = min(d.x, d.y), w = fwidth(e);
        float line = (1.0 - smoothstep(w * 0.7, w * 2.1, e)) * smoothstep(w * 9.0, w * 24.0, min(vSize.x, vSize.y));
        vec3 c = mix(uFace, uTop, 0.35 + 0.45 * vTall) * (0.9 + 0.3 * vTall);
        float strength = uEdgeStrength * mix(0.5, 1.15, vTall);
        c = mix(c, uEdge, clamp(line * strength, 0.0, 1.0));
        float ain; vec3 afc; vec4 ar = areaAt(vWorld, 1.0, ain, afc);
        if (ar.a > 0.002 || ain > 0.002) {
          c = mix(c, afc * 1.3, clamp(line * (strength + 0.6), 0.0, 1.0) * ain);
          c = mix(c, ar.rgb, ar.a);
        }
        gl_FragColor = vec4(c, 1.0);
      }`;
    const roof = new THREE.PlaneGeometry(1, 1);
    const CELL = 600;
    for (const d of data.manifest.buildings.districts) {
      const view = new DataView(data.buildings, d.offset * stride, d.count * stride);
      // bucket the district's boxes into a grid so frustum culling has something to cull
      const buckets = new Map<string, number[]>();
      for (let i = 0; i < d.count; i++) {
        const o = i * stride;
        const x = d.min[0] + (view.getUint16(o, true) / 65535) * d.span[0];
        const z = d.min[2] + (view.getUint16(o + 4, true) / 65535) * d.span[2];
        const key = `${Math.floor(x / CELL)}:${Math.floor(z / CELL)}`;
        let b = buckets.get(key);
        if (!b) buckets.set(key, (b = []));
        b.push(i);
      }
      const extra = {
        uMin: { value: new THREE.Vector3(...d.min) },
        uSpan: { value: new THREE.Vector3(...d.span) },
        uMaxSize: { value: d.maxSize },
        uFace: { value: new THREE.Color() }, uTop: { value: new THREE.Color() }, uEdge: { value: new THREE.Color() },
        uEdgeStrength: { value: 0.85 },
      };
      const mat = this.material("buildings", extra, vertex, fragment);
      const roofMat = this.material("buildings", extra, roofVertex, roofFragment, { side: THREE.DoubleSide });
      const bytes = new Uint8Array(data.buildings, d.offset * stride, d.count * stride);
      for (const idx of buckets.values()) {
        const n = idx.length;
        const pos = new Uint16Array(n * 3), quat = new Int8Array(n * 4), size = new Uint16Array(n * 3);
        const sphere = new THREE.Box3();
        const tmp = new THREE.Vector3();
        idx.forEach((i, k) => {
          const o = i * stride;
          const dv = new DataView(bytes.buffer, bytes.byteOffset + o, stride);
          for (let a = 0; a < 3; a++) { pos[k * 3 + a] = dv.getUint16(a * 2, true); size[k * 3 + a] = dv.getUint16(10 + a * 2, true); }
          for (let a = 0; a < 4; a++) quat[k * 4 + a] = dv.getInt8(6 + a);
          tmp.set(d.min[0] + (pos[k * 3] / 65535) * d.span[0], d.min[1] + (pos[k * 3 + 1] / 65535) * d.span[1], d.min[2] + (pos[k * 3 + 2] / 65535) * d.span[2]);
          sphere.expandByPoint(tmp);
        });
        const g = new THREE.InstancedBufferGeometry();
        g.index = box.index;
        g.setAttribute("position", box.getAttribute("position"));
        g.setAttribute("normal", box.getAttribute("normal"));
        g.setAttribute("iPos", new THREE.InstancedBufferAttribute(pos, 3, true));
        g.setAttribute("iQuat", new THREE.InstancedBufferAttribute(quat, 4, true));
        g.setAttribute("iSize", new THREE.InstancedBufferAttribute(size, 3, true));
        g.instanceCount = n;
        sphere.expandByScalar(d.maxSize * 0.5);
        g.boundingBox = sphere;
        g.boundingSphere = sphere.getBoundingSphere(new THREE.Sphere());
        const mesh = new THREE.Mesh(g, mat);
        mesh.name = "buildings:" + d.name;
        this.buildingGroup.add(mesh);
        // the roofs share the boxes' instance buffers (uploaded once)
        const rg = new THREE.InstancedBufferGeometry();
        rg.index = roof.index;
        rg.setAttribute("position", roof.getAttribute("position"));
        for (const a of ["iPos", "iQuat", "iSize"]) rg.setAttribute(a, g.getAttribute(a));
        rg.instanceCount = n;
        rg.boundingBox = g.boundingBox;
        rg.boundingSphere = g.boundingSphere;
        this.swaps.push({ mesh, geometry: [g, rg], material: [mat, roofMat] });
      }
    }
  }

  applyTheme(theme: Theme): void {
    this.theme = theme;
    this.uniforms.uFogColor.value.set(theme.background);
    for (const m of this.materials) {
      const u = m.uniforms as Record<string, { value: any }>;
      switch (m.name) {
        case "terrain": u.uColor.value.set(theme.terrain); u.uGrid.value.set(theme.terrainGrid); break;
        case "cliffs": u.uColor.value.set(theme.terrain); u.uGrid.value.set(theme.terrainGrid); break;
        case "water": u.uColor.value.set(theme.water); u.uLine.value.set(theme.waterLine); break;
        case "roads": u.uColor.value.set(theme.road); break;
        case "roadBorders": u.uColor.value.set(theme.roadEdge); break;
        case "metro": u.uColor.value.set(theme.metro); break;
        case "landmarks": u.uColor.value.set(theme.building); u.uEdge.value.set(theme.landmark); break;
        case "buildings": u.uFace.value.set(theme.building); u.uTop.value.set(theme.buildingTop); u.uEdge.value.set(theme.buildingEdge); break;
      }
    }
  }

  /** Fog follows the camera distance so the city fades into the theme's void. */
  updateFog(cameraDistance: number): void {
    const k = Math.max(0.05, 1 - this.theme.fog);
    this.uniforms.uFogNear.value = cameraDistance * (0.9 + 2.2 * k);
    this.uniforms.uFogFar.value = cameraDistance * (2.2 + 6 * k) + 1500;
  }
}
