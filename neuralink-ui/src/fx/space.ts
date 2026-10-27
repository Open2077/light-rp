/* The interface's sense of space: one smoothed pointer (-1..1 on both axes) with
   a slow idle sway, shared by the 3D plane (CSS variables), the neural field
   canvas and the synapse links. Shell drives it with a single rAF loop. */

export const space = {
  /** smoothed pointer, -1..1 (left/top negative) */
  x: 0,
  y: 0,
  /** seconds since the loop started */
  t: 0,
};

let targetX = 0, targetY = 0;
let lastMove = 0;

export function pointerTo(nx: number, ny: number): void {
  targetX = nx;
  targetY = ny;
  lastMove = performance.now();
}

/** Advance by dt seconds: critically damped follow, plus a lissajous drift when the mouse rests. */
export function stepSpace(dt: number, still: boolean): void {
  space.t += dt;
  const idle = still ? 1 : Math.min(1, Math.max(0, (performance.now() - lastMove - 2500) / 2500));
  const swayX = Math.sin(space.t * 0.31) * 0.16 + Math.sin(space.t * 0.73) * 0.04;
  const swayY = Math.sin(space.t * 0.23 + 1.3) * 0.1;
  const tx = targetX * (1 - idle * 0.6) + swayX * idle;
  const ty = targetY * (1 - idle * 0.6) + swayY * idle;
  const k = 1 - Math.exp(-dt * 4.2);
  space.x += (tx - space.x) * k;
  space.y += (ty - space.y) * k;
}
