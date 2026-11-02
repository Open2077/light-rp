import * as THREE from "three";

// Game space: metres, X east, Y north, Z up. three.js scene: Y up, so
// scene (x, y, z) = game (x, z, -y).
export interface GamePos { x: number; y: number; z?: number }

export function toScene(p: GamePos, out = new THREE.Vector3()): THREE.Vector3 {
  return out.set(p.x, p.z ?? 0, -p.y);
}
export function toGame(v: THREE.Vector3): { x: number; y: number; z: number } {
  return { x: v.x, y: -v.z, z: v.y };
}
/** Game yaw (degrees, 0 = facing +Y north, counter-clockwise) to a scene heading angle about +Y. */
export function yawToSceneAngle(yawDeg: number): number {
  return (yawDeg * Math.PI) / 180;
}
export function dist2d(a: GamePos, b: GamePos): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}
export function formatDistance(m: number, units: "metric" | "imperial"): string {
  if (units === "imperial") {
    const ft = m * 3.28084;
    return ft < 1000 ? `${Math.round(ft / 10) * 10} ft` : `${(m / 1609.34).toFixed(1)} mi`;
  }
  return m < 1000 ? `${Math.max(0, Math.round(m / 5) * 5)} m` : `${(m / 1000).toFixed(m < 10000 ? 1 : 0)} km`;
}
