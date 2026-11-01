/* Build mode of the mission editor (src/features/missioneditor/build.ts).
   Run: npx esbuild tests/missioneditor-build.test.ts --bundle --platform=node --format=esm --outfile=<tmp>/b.test.mjs && node --test <tmp>/b.test.mjs */
import { test } from "node:test";
import assert from "node:assert/strict";
import { applyBuild, toolsFor, type BuildState } from "../src/features/missioneditor/build.ts";
import { BRUSH, fresh, type Mission } from "../src/features/missioneditor/model.ts";

const base = (): Mission => fresh({ position: { x: 0, y: 0, z: 10 }, heading: 0 });
const at = (x: number, y: number) => ({ x, y, z: 10 });
const spawnTool: BuildState = { tool: "spawn", heading: null };

test("a click places a squad with the brush and selects it for the patrol tool", () => {
  const r = applyBuild(base(), spawnTool, { ...BRUSH, enemy: "maelstrom", count: 5, behavior: "ambush", spread: 3 }, { action: "place", position: at(5, 5), heading: 90 });
  const s = r.mission!.spawns[0]!;
  assert.equal(s.enemy, "maelstrom"); assert.equal(s.count, 5); assert.equal(s.behavior, "ambush"); assert.equal(s.spread, 3); assert.equal(s.heading, 90);
  assert.equal(r.build!.spawn, s.id); assert.match(r.message!, /5× Maelstrom ganger, ambush/);
});

test("a wave brush on an Elimination mission spawns at start; a patrol brush waits for its first point", () => {
  const r = applyBuild(base(), spawnTool, { ...BRUSH, trigger: "wave", behavior: "patrol" }, { action: "place", position: at(1, 1) });
  assert.equal(r.mission!.spawns[0]!.trigger, "start"); assert.equal(r.mission!.spawns[0]!.behavior, "assault");
});

test("patrol points go to the selected spawn point and switch it to Patrol", () => {
  const m = applyBuild(base(), spawnTool, BRUSH, { action: "place", position: at(5, 5) });
  const build = m.build!;
  assert.match(applyBuild(m.mission!, { ...build, tool: "patrol", spawn: undefined }, BRUSH, { action: "place", position: at(9, 9) }).error!, /Right-click a spawn/);
  const p = applyBuild(m.mission!, { ...build, tool: "patrol" }, BRUSH, { action: "place", position: at(9, 9) });
  const s = p.mission!.spawns[0]!;
  assert.deepEqual(s.route, [at(9, 9)]); assert.equal(s.behavior, "patrol"); assert.match(p.message!, /now Patrol/);
});

test("move: pick up the aimed element, drop it; its patrol route travels with it", () => {
  let m = applyBuild(base(), spawnTool, BRUSH, { action: "place", position: at(5, 5) });
  m = applyBuild(m.mission!, { ...m.build!, tool: "patrol" }, BRUSH, { action: "place", position: at(8, 5) });
  const id = m.mission!.spawns[0]!.id;
  const move: BuildState = { tool: "move", heading: null };
  assert.match(applyBuild(m.mission!, move, BRUSH, { action: "place", position: at(0, 0) }).error!, /Aim at an element/);
  const picked = applyBuild(m.mission!, move, BRUSH, { action: "place", position: at(5, 5), hovered: { type: "spawn", id } });
  assert.equal(picked.build!.carrying!.id, id); assert.equal(picked.mission, undefined);
  const dropped = applyBuild(m.mission!, picked.build!, BRUSH, { action: "place", position: at(15, 5), heading: 45 });
  const s = dropped.mission!.spawns[0]!;
  assert.deepEqual(s.position, at(15, 5)); assert.deepEqual(s.route[0], at(18, 5)); assert.equal(s.heading, 45); assert.equal(dropped.build!.carrying, undefined);
});

test("delete removes the aimed element and its links; the board and the last start are protected", () => {
  let m = applyBuild(base(), spawnTool, { ...BRUSH, trigger: "checkpoint" }, { action: "place", position: at(5, 5) });
  const id = m.mission!.spawns[0]!.id;
  m = applyBuild(m.mission!, { tool: "checkpoint", heading: null }, BRUSH, { action: "place", position: at(2, 2) });
  const mission = { ...m.mission!, checkpoints: m.mission!.checkpoints.map(c => ({ ...c, spawns: [id] })) };
  const removed = applyBuild(mission, spawnTool, BRUSH, { action: "delete", hovered: { type: "spawn", id } });
  assert.equal(removed.mission!.spawns.length, 0); assert.deepEqual(removed.mission!.checkpoints[0]!.spawns, []);
  assert.match(applyBuild(mission, spawnTool, BRUSH, { action: "delete", hovered: { type: "board" } }).error!, /cannot be removed/);
  assert.match(applyBuild(mission, spawnTool, BRUSH, { action: "delete", hovered: { type: "start", index: 1 } }).error!, /at least one squad start/);
  assert.match(applyBuild(mission, spawnTool, BRUSH, { action: "delete" }).error!, /Aim at an element/);
});

test("perimeter tools: polygon vertices, circle radius from the edge, box size from a corner", () => {
  const poly = base(); poly.perimeter.shape = "poly";
  let r = applyBuild(poly, { tool: "perimeter", heading: null }, BRUSH, { action: "place", position: at(10, 0) });
  assert.equal(r.mission!.perimeter.points.length, 1); assert.match(r.message!, /2 more to close/);
  assert.ok(!toolsFor(poly).includes("radius"), "no size tool for a polygon");
  r = applyBuild(base(), { tool: "radius", heading: null }, BRUSH, { action: "place", position: at(30, 40) });
  assert.equal(r.mission!.perimeter.radius, 50);
  const box = base(); box.perimeter.shape = "box"; box.perimeter.heading = 90;
  r = applyBuild(box, { tool: "radius", heading: null }, BRUSH, { action: "place", position: at(5, 20) });
  assert.equal(r.mission!.perimeter.length, 40); assert.equal(r.mission!.perimeter.width, 10);
});

test("tools cycle with Up/Down, facing turns with Left/Right, select opens the aimed element", () => {
  const m = base();
  assert.equal(applyBuild(m, spawnTool, BRUSH, { action: "tool", delta: -1 }).build!.tool, "board");
  assert.equal(applyBuild(m, spawnTool, BRUSH, { action: "tool", delta: 1 }).build!.tool, "checkpoint");
  assert.equal(applyBuild(m, { tool: "spawn", heading: 350 }, BRUSH, { action: "rotate", delta: 15 }).build!.heading, 5);
  assert.equal(applyBuild(m, spawnTool, BRUSH, { action: "rotate", delta: -15 }).build!.heading, 345);
  const sel = applyBuild(m, spawnTool, BRUSH, { action: "select", hovered: { type: "spawn", id: "s9" } });
  assert.equal(sel.select!.id, "s9"); assert.equal(sel.build!.spawn, "s9");
  assert.match(applyBuild(m, spawnTool, BRUSH, { action: "error", error: "Nothing under the crosshair" }).error!, /Nothing/);
});
