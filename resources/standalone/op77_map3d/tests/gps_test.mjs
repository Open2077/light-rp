// GPS on the real road data: routes between random points all over the city must
// exist, follow linked lanes, start and end near the asked points, and be fast.
// Run from the resource folder: node tests/gps_test.mjs   (needs ui/node_modules)
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
const require = createRequire(new URL("../ui/package.json", import.meta.url));
const esbuild = require("esbuild");
const out = await esbuild.build({ entryPoints: [new URL("../ui/src/gps.ts", import.meta.url).pathname.replace(/^\/(\w:)/, "$1")], bundle: true, format: "esm", write: false, platform: "node" });
const mod = await import("data:text/javascript;base64," + Buffer.from(out.outputFiles[0].text).toString("base64"));
const dir = new URL("../web/data/", import.meta.url);
const manifest = JSON.parse(readFileSync(new URL("manifest.json", dir)));
const buf = readFileSync(new URL("roads.bin", dir));
const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
const T = { f4: Float32Array, u4: Uint32Array, u2: Uint16Array, u1: Uint8Array };
const roads = {};
for (const [k, a] of Object.entries(manifest.roads.arrays)) roads[k] = new T[a.type.replace(/^[<>|]/, "")](ab, a.offset, a.length);
const g = new mod.RoadGraph(roads);

// random spots on the main network (so a route must exist)
let seed = 7;
const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const mainLanes = [];
for (let l = 0; l < g.lanes; l++) if (roads.laneMain[l]) mainLanes.push(l);
const spot = () => {
  const l = mainLanes[Math.floor(rnd() * mainLanes.length)];
  const o = roads.laneOffset[l];
  return { x: roads.points[o * 3] + (rnd() - 0.5) * 20, y: roads.points[o * 3 + 1] + (rnd() - 0.5) * 20, z: roads.points[o * 3 + 2] };
};
let ok = 0, worst = 0, total = 0, bad = 0;
const N = 200;
for (let i = 0; i < N; i++) {
  const a = spot(), b = spot();
  const t0 = performance.now();
  const r = g.route(a, b, { mainOnly: true });
  const ms = performance.now() - t0;
  worst = Math.max(worst, ms); total += ms;
  if (!r) continue;
  // consecutive lanes must be linked
  for (let k = 0; k + 1 < r.lanes.length; k++) {
    const l = r.lanes[k], m = r.lanes[k + 1];
    let linked = false;
    for (let j = roads.outStart[l]; j < roads.outStart[l + 1]; j++) if (roads.outLanes[j] === m) linked = true;
    if (!linked) { bad++; break; }
  }
  const n = r.cumulative.length;
  const startOff = Math.hypot(r.points[0] - a.x, r.points[1] - a.y), endOff = Math.hypot(r.points[(n - 1) * 3] - b.x, r.points[(n - 1) * 3 + 1] - b.y);
  if (startOff > 40 || endOff > 40) { bad++; continue; }
  if (r.maneuvers[0].kind !== "start" || r.maneuvers.at(-1).kind !== "arrive") { bad++; continue; }
  ok++;
}
console.log(`routes ${ok}/${N}, invalid ${bad}, avg ${(total / N).toFixed(1)} ms, worst ${worst.toFixed(1)} ms`);
// progress along a route
const a = { x: -1450, y: 140 }, b = { x: -747.8, y: 914.6 };
const r = g.route(a, b, { mainOnly: true });
const mid = Math.floor(r.cumulative.length / 2);
const pr = mod.progressOn(r, { x: r.points[mid * 3] + 3, y: r.points[mid * 3 + 1] });
console.log(`city center -> kabuki: ${r.length.toFixed(0)} m, ${r.maneuvers.length - 2} turns, progress at mid ${(pr.along / r.length * 100).toFixed(0)}% off ${pr.off.toFixed(1)} m`);
if (ok < N * 0.97 || bad > 0 || worst > 250 || pr.off > 5) { console.error("FAIL"); process.exit(1); }
console.log("PASS: GPS routes on the game's traffic network");
