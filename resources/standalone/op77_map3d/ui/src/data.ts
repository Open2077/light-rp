import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { inGame } from "./bridge";

// The exported game map (tools/export_web.py writes data/*).
export interface District { name: string; offset: number; count: number; min: number[]; span: number[]; maxSize: number }
export interface Manifest {
  format: string;
  world: { file: string; layers: Record<string, { triangles: number; vertices: number }> };
  buildings: { file: string; stride: number; count: number; districts: District[] };
  roads: { file: string; lanes: number; points: number; arrays: Record<string, { offset: number; length: number; type: string }>; flags: Record<string, number> };
  districts: Record<string, { center: number[] }>;
}

export interface RoadData {
  points: Float32Array; // game x, y, z
  laneMain: Uint8Array;
  laneOffset: Uint32Array;
  laneCount: Uint16Array;
  laneFlags: Uint16Array;
  laneSpeed: Uint8Array;
  laneLength: Float32Array;
  outStart: Uint32Array;
  outLanes: Uint32Array;
}

export interface MapData {
  manifest: Manifest;
  world: THREE.Group;
  buildings: ArrayBuffer;
  roads: RoadData;
}

// In game the page may only fetch declared resource files through open77:// (connect-src
// open77:), and WebAssembly is refused, so world.glb is quantized, not meshopt-compressed.
// Renaming the resource folder? Set window.MAP3D_RESOURCE before this module runs.
const RESOURCE = (window as { MAP3D_RESOURCE?: string }).MAP3D_RESOURCE ?? "op77_map3d";
const BASE = inGame ? `open77://${RESOURCE}/web/data/` : "./data/";

async function fetchBuffer(name: string, progress: (f: number) => void): Promise<ArrayBuffer> {
  const res = await fetch(BASE + name);
  if (!res.ok) throw new Error(`map data ${name}: ${res.status}`);
  const total = Number(res.headers.get("content-length")) || 0;
  if (!res.body || !total) { const b = await res.arrayBuffer(); progress(1); return b; }
  const reader = res.body.getReader();
  const out = new Uint8Array(total);
  let got = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    out.set(value, got);
    got += value.length;
    progress(got / total);
  }
  return out.buffer;
}

function typed(buf: ArrayBuffer, a: { offset: number; length: number; type: string }) {
  switch (a.type.replace(/^[<>|]/, "")) {
    case "f4": return new Float32Array(buf, a.offset, a.length);
    case "u4": return new Uint32Array(buf, a.offset, a.length);
    case "u2": return new Uint16Array(buf, a.offset, a.length);
    case "u1": return new Uint8Array(buf, a.offset, a.length);
    default: throw new Error("unknown array type " + a.type);
  }
}

export async function loadMapData(onProgress: (label: string, f: number) => void): Promise<MapData> {
  const res = await fetch(BASE + "manifest.json");
  if (!res.ok) throw new Error(`map data manifest.json: ${res.status}`);
  const manifest = (await res.json()) as Manifest;
  const parts = { world: 0, buildings: 0, roads: 0 };
  const report = (k: keyof typeof parts, label: string) => (f: number) => {
    parts[k] = f;
    onProgress(label, (parts.world + parts.buildings + parts.roads) / 3);
  };
  const [worldBuf, buildings, roadsBuf] = await Promise.all([
    fetchBuffer(manifest.world.file, report("world", "TERRAIN")),
    fetchBuffer(manifest.buildings.file, report("buildings", "BUILDINGS")),
    fetchBuffer(manifest.roads.file, report("roads", "ROAD NETWORK")),
  ]);
  const loader = new GLTFLoader();
  const gltf = await loader.parseAsync(worldBuf, BASE);
  return { manifest, world: gltf.scene, buildings, roads: readRoads(manifest, roadsBuf) };
}

/** Only the road network (the holographic GPS draws the roads around the player). */
export async function loadRoadData(): Promise<RoadData> {
  const res = await fetch(BASE + "manifest.json");
  if (!res.ok) throw new Error(`map data manifest.json: ${res.status}`);
  const manifest = (await res.json()) as Manifest;
  return readRoads(manifest, await fetchBuffer(manifest.roads.file, () => {}));
}

function readRoads(manifest: Manifest, roadsBuf: ArrayBuffer): RoadData {
  const A = manifest.roads.arrays;
  return {
    points: typed(roadsBuf, A.points) as Float32Array,
    laneMain: typed(roadsBuf, A.laneMain) as Uint8Array,
    laneOffset: typed(roadsBuf, A.laneOffset) as Uint32Array,
    laneCount: typed(roadsBuf, A.laneCount) as Uint16Array,
    laneFlags: typed(roadsBuf, A.laneFlags) as Uint16Array,
    laneSpeed: typed(roadsBuf, A.laneSpeed) as Uint8Array,
    laneLength: typed(roadsBuf, A.laneLength) as Float32Array,
    outStart: typed(roadsBuf, A.outStart) as Uint32Array,
    outLanes: typed(roadsBuf, A.outLanes) as Uint32Array,
  };
}
