// Areas on the page (ui/src/areas.ts): what reaches the shaders. The baked field must
// hold the signed distance to the nearest border (positive inside, even-odd like the Lua
// side), the area of each texel (the newest on top, a border's area just outside it), stay
// within the texture budget and be quick for a real outline (Light RP's Dogtown).
// Run from the resource folder: node tests/areas_test.mjs   (needs ui/node_modules)
import { createRequire } from "node:module";
import assert from "node:assert/strict";
const require = createRequire(new URL("../ui/package.json", import.meta.url));
const esbuild = require("esbuild");
const out = await esbuild.build({ entryPoints: [new URL("../ui/src/areas.ts", import.meta.url).pathname.replace(/^\/(\w:)/, "$1")], bundle: true, format: "esm", write: false, platform: "node" });
const mod = await import("data:text/javascript;base64," + Buffer.from(out.outputFiles[0].text).toString("base64"));
const { bakeAreas, labelPoint, containsPoint, normalizeArea, AREA_GLSL, MAX_AREAS } = mod;

// sample the field at a game position (nearest texel)
function at(field, x, y) {
  const [minX, minZ, w, h] = field.box;
  const c = Math.floor(((x - minX) / w) * field.width), r = Math.floor(((-y - minZ) / h) * field.height);
  assert.ok(c >= 0 && r >= 0 && c < field.width && r < field.height, `(${x}, ${y}) inside the field`);
  const o = (r * field.width + c) * 2;
  return { d: field.data[o], slot: field.data[o + 1] };
}

// a 200 m square
const square = [0, 0, 200, 0, 200, 200, 0, 200];
let f = bakeAreas([{ pts: square }]);
assert.equal(bakeAreas([]), null, "no area, no texture");
let s = at(f, 100, 100);
assert.ok(s.d === 32 && s.slot === 1, "deep inside: clamped positive distance, slot 1");
s = at(f, 100, 10);
assert.ok(Math.abs(s.d - 10) < 1.2 && s.slot === 1, `10 m inside the south edge: ~ +10 (${s.d})`);
s = at(f, 100, -10);
assert.ok(Math.abs(s.d + 10) < 1.2 && s.slot === 1, `10 m outside: ~ -10 and still the border's area (${s.d})`);
s = at(f, -15, -15);
assert.ok(Math.abs(s.d + 21.2) < 1.5 && s.slot === 1, `outside a corner: distance to the corner (${s.d})`);
s = at(f, -30, -30);
assert.ok(s.d === -32 && s.slot === 0, "past the distance range: nothing");
const [minX, minZ] = f.box;
assert.ok(minX <= -32 && minZ <= -232, "the field reaches past the outline by the distance range");
const corner = { d: f.data[0], slot: f.data[1] };
assert.ok(corner.d === -32 && corner.slot === 0, "far outside: nothing");
assert.ok(Math.abs(f.box[2] / f.width - 1.5) < 1e-9, "1.5 m texels for a small area");

// concave "U": the notch is outside, as on the server
const u = [0, 0, 300, 0, 300, 300, 200, 300, 200, 100, 100, 100, 100, 300, 0, 300];
f = bakeAreas([{ pts: u }]);
assert.ok(at(f, 150, 250).d < 0 && at(f, 50, 250).d > 0 && at(f, 250, 250).d > 0 && at(f, 150, 50).d > 0, "the notch of a U is outside");
assert.ok(!containsPoint(u, 150, 250) && containsPoint(u, 50, 250));
const lp = labelPoint(u);
assert.ok(containsPoint(u, lp.x, lp.y), `a concave label point falls inside (${lp.x}, ${lp.y})`);
const sq = labelPoint(square);
assert.ok(Math.abs(sq.x - 100) < 1e-9 && Math.abs(sq.y - 100) < 1e-9, "a convex label point is the centroid");

// two areas: the newer one is on top where they overlap; each keeps its own slot
const b = [150, 150, 400, 150, 400, 400, 150, 400];
f = bakeAreas([{ pts: square }, { pts: b }]);
assert.equal(at(f, 50, 50).slot, 1);
assert.equal(at(f, 180, 180).slot, 2, "overlap: the newer area");
assert.equal(at(f, 300, 300).slot, 2);
assert.ok(Math.abs(at(f, 180, 165).d - 15) < 1.5 || Math.abs(at(f, 180, 165).d - 20) < 1.5, "inside both: distance to the nearest border of either");

// a city-wide set stays within 1024 texels a side
f = bakeAreas([{ pts: [-6000, -4000, 3000, -4000, 3000, 5000, -6000, 5000] }]);
assert.ok(f.width <= 1024 && f.height <= 1024, `capped (${f.width} x ${f.height})`);

// Light RP's Dogtown (30 points, about 1.5 x 1.4 km): fast enough to bake on a change
const dogtown = [-2550, -2726.6, -2410, -2846.6, -2450, -3006.6, -2410, -3146.6, -1930, -3066.6, -1910, -3006.6, -1690, -2946.6, -1510, -2866.6,
  -1510, -2806.6, -1370, -2766.6, -1250, -2586.6, -1290, -2366.6, -1050, -2246.6, -1010, -2146.6, -1050, -1886.6, -1150, -1806.6,
  -1390, -1786.6, -1550, -1906.6, -1570, -2026.6, -1830, -2086.6, -1930, -2206.6, -2030, -2206.6, -2070, -2286.6, -2150, -2286.6,
  -2230, -2426.6, -2350, -2466.6, -2350, -2546.6, -2430, -2566.6, -2430, -2626.6, -2530, -2666.6];
const t0 = performance.now();
f = bakeAreas([{ pts: dogtown }]);
const ms = performance.now() - t0;
assert.ok(ms < 1500, `Dogtown baked in ${ms.toFixed(0)} ms`);
assert.ok(at(f, -2044, -2406).d > 0 && at(f, -1754.6, -2490.6).d > 0, "the Chimera arena and the zone's centre are inside");
assert.ok(at(f, -2200, -2000).d < 0 && at(f, -1000, -2300).d < 0, "the city north of the walls and the east are outside");
assert.ok(containsPoint(dogtown, -1754.6, -2640), "Light RP's label point is inside");

// what Lua sends is checked again
assert.equal(normalizeArea({ id: "a", pts: [0, 0, 1, 1] }), null, "fewer than 3 points");
assert.equal(normalizeArea({ id: "a", pts: [0, 0, 1, 1, 2] }), null, "an odd count");
assert.equal(normalizeArea({ id: "a", pts: [0, 0, 1, NaN, 2, 2] }), null, "a non-finite value");
assert.equal(normalizeArea({ pts: square }), null, "an id");
const n = normalizeArea({ id: 7, pts: square, fill: "red", fillOpacity: 4, strokeWidth: -1, pattern: "dots", label: "x".repeat(99) });
assert.ok(n.id === "7" && n.fill === "#FF2E3C" && n.stroke === "#FF2E3C" && n.fillOpacity === 1 && n.strokeWidth === 0 && n.pattern === "hatch" && n.label.length === 64 && n.map && n.minimap && !n.pulse);
assert.ok(AREA_GLSL.includes(`uAreaFill[${MAX_AREAS}]`) && MAX_AREAS === 16, "the shaders' arrays follow MAX_AREAS (shared/area.lua MAX_PER_OWNER)");

console.log(`PASS: areas (signed distance, slots, concave, overlap, size cap, Dogtown bake ${ms.toFixed(0)} ms, ${f.width} x ${f.height} texels, page validation)`);
