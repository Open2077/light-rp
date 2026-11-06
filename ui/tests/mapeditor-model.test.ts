/* The map editor's model and build mode (src/features/mapeditor), and the dev preview's mock.
   Run: npx esbuild tests/mapeditor-model.test.ts --bundle --platform=node --format=esm --outfile=<tmp>/m.test.mjs && node --test <tmp>/m.test.mjs */
import { test } from "node:test";
import assert from "node:assert/strict";
import { applyBuild, toolHelp, type BuildState } from "../src/features/mapeditor/build.ts";
import { drawing, drawingNote, duplicate, fresh, ninthRefused, normalizeMap, normalizeSchema, ofListing, problems, receiveListed, toolsFor, type GameMap, type Schema } from "../src/features/mapeditor/model.ts";
import { mapEditorMock } from "../src/features/mapeditor/mock.ts";
import { editorChannel } from "../src/features/missioneditor/api.ts";
import { PAGE_EVENTS } from "../src/bridge/protocol.ts";

const schema: Schema = normalizeSchema({
  points: [{ key: "centre", label: "Play area centre", color: "#ffcc00" }, { key: "secret", label: "Secret", color: "#000000", hidden: true }],
  lists: [{ key: "spawns", label: "Spawn", color: "#3ddc84", min: 2, max: 3 }],
  numbers: [{ key: "radius", label: "Radius", min: 10, max: 100, default: 50, unit: "m" }, { key: "hidden", label: "H", min: 0, max: 1, default: 1, unit: "", hidden: true }],
  choices: [{ key: "props", label: "Objects", about: "", options: [{ id: "a", label: "A" }] }],
  area: { centre: "centre", radius: "radius", holds: ["spawns"] },
  apart: [{ a: "centre", b: "spawns", metres: 2 }],
});
const at = (x: number, y = 0) => ({ x, y, z: 0 });
const point = (build: BuildState, m: GameMap, x: number) => applyBuild(schema, m, build, { action: "place", position: at(x), heading: 90 });
const first: BuildState = { tool: "point:centre", heading: null };

test("Lua's empty tables and missing fields become lists and defaults", () => {
  const s = normalizeSchema({ points: {} as never, lists: undefined, area: { centre: "c", radius: "r", holds: {} as never } });
  assert.deepEqual(s.points, []); assert.deepEqual(s.lists, []); assert.deepEqual(s.area?.holds, []);
  const m = normalizeMap(schema, { id: "x", revision: 1, name: "X", enabled: false, spawns: {} });
  assert.deepEqual(m.spawns, []); assert.equal(m.radius, 50); assert.deepEqual(m.props, []);
  assert.deepEqual(m.problems, []);
});

test("a late stream of another game is dropped, however alike the ids", () => {
  const tdm = { id: "docks", revision: 1, name: "Docks", enabled: true, game: "games.tdm" };
  const control = { id: "docks", revision: 4, name: "Docks", enabled: false, game: "games.control" };
  let list = receiveListed("list-b", schema, [], { stream: "list-b", map: control });
  assert.equal(list[0]?.game, "games.control");
  const same = receiveListed("list-b", schema, list, { stream: "list-a", map: tdm });
  assert.equal(same, list, "the stale event changes nothing");
  assert.equal(same[0]?.revision, 4);
  assert.equal(receiveListed("", schema, list, { stream: "list-a", map: tdm }), list, "no listing open: nothing counts");
  assert.equal(receiveListed("list-b", undefined, list, { stream: "list-b", map: tdm }), list, "no schema: nothing counts");
  list = receiveListed("list-b", schema, list, { stream: "list-b", map: { ...control, revision: 5 } });
  assert.equal(list.length, 1); assert.equal(list[0]?.revision, 5);
  assert.equal(ofListing("list-b", { stream: "list-b" }), true);
  assert.equal(ofListing("list-b", { stream: "list-a" }), false);
  assert.equal(ofListing("list-b", {}), false, "an untagged event is nobody's");
  assert.equal(ofListing("", {}), false);
});

test("a list's id is known before it goes out: no stream event can beat it", async () => {
  const emitted: { request: string }[] = [];
  let answer: (event: unknown) => void = () => undefined;
  (globalThis as { window?: unknown }).window = { setTimeout, Open77: {
    on: (_: string, handler: (event: unknown) => void) => { answer = handler; },
    emit: (_: string, payload: { request: string }) => { emitted.push(payload); setTimeout(() => answer({ kind: "response", request: payload.request, ok: true, data: {} }), 0); },
  } };
  const { request } = editorChannel("test:channel");
  let named = "";
  await request("list", { game: "games.tdm" }, id => { assert.equal(emitted.length, 0, "named first"); named = id; });
  assert.equal(named, emitted[0]?.request);
});

test("the preview says what it left out, and nothing when all of it fits", () => {
  assert.equal(drawingNote(null), undefined);
  assert.equal(drawingNote({ total: 33, shown: 33, full: 33 }), undefined);
  assert.match(drawingNote({ total: 65, shown: 65, full: 20 })!, /20 of 65 points drawn in full/);
  assert.match(drawingNote({ total: 601, shown: 512, full: 0 })!, /89 of 601 points not drawn/);
});

test("the mock's list and save follow the server: tagged by game, tied to the request", () => new Promise<void>((done, reject) => {
  const fired: { kind: string; stream?: string; map?: GameMap; request?: string; ok?: boolean; error?: string }[] = [];
  const mock = mapEditorMock((_, value) => fired.push(value as never), new URLSearchParams("staff=1"));
  mock.receive({ operation: "list", request: "r1", game: "games.tdm" });
  setTimeout(() => {
    try {
      const maps = fired.filter(e => e.kind === "map");
      assert.ok(maps.length > 0); assert.ok(maps.every(e => e.stream === "r1" && e.map?.game === "games.tdm"));
      mock.receive({ operation: "save", request: "r2", game: "games.prophunt", mutation: "m1", baseRevision: 1, map: maps[0]!.map });
      setTimeout(() => {
        try {
          const reply = fired.find(e => e.request === "r2");
          assert.equal(reply?.ok, false); assert.match(reply?.error ?? "", /another game/);
          done();
        } catch (e) { reject(e as Error); }
      }, 200);
    } catch (e) { reject(e as Error); }
  }, 450);
}));

test("a new map is a draft with the schema's defaults", () => {
  const m = fresh(schema);
  assert.equal(m.enabled, false); assert.equal(m.id, ""); assert.equal(m.radius, 50); assert.deepEqual(m.spawns, []);
});

test("tools come from the schema: hidden points are none, a play area gives the radius tool, Move is last", () => {
  assert.deepEqual(toolsFor(schema).map(t => t.id), ["point:centre", "list:spawns", "radius", "move"]);
  const noArea = normalizeSchema({ points: [{ key: "finish", label: "Finish", color: "#ff0000" }] });
  assert.deepEqual(toolsFor(noArea).map(t => t.id), ["point:finish", "move"]);
});

test("drawing sends layers, never a hidden point", () => {
  const d = drawing(schema);
  assert.deepEqual(d.layers.map(l => `${l.kind}:${l.key}`), ["point:centre", "list:spawns"]);
  assert.equal(d.layers[0]!.color, "#ffcc00ff");
  assert.deepEqual(d.area, { centre: "centre", radius: "radius" });
  assert.equal(drawing(normalizeSchema({})).area, null);
});

test("problems say what is missing, in the server's words", () => {
  const m = fresh(schema);
  assert.deepEqual(problems(schema, m), ["Place Play area centre.", "Spawn: at least 2, 0 placed."]);
  const done = { ...m, centre: at(0), spawns: [at(10), at(20)] };
  assert.deepEqual(problems(schema, done), []);
  assert.deepEqual(problems(schema, { ...done, spawns: [at(10), at(90)] }), ["Spawn 2 is outside the play area."]);
  assert.deepEqual(problems(schema, { ...done, spawns: [at(1), at(10)] }), ["Play area centre and Spawn 1 must be 2 m apart."]);
});

test("a flat area ignores height, a sphere does not", () => {
  const flat = normalizeSchema({ ...schema, area: { ...schema.area!, flat: true } });
  const m = { ...fresh(flat), centre: at(0), spawns: [{ x: 10, y: 0, z: 500 }, at(20)] };
  assert.deepEqual(problems(flat, m), []);
  assert.equal(problems(schema, m as GameMap).length, 1);
});

test("the ninth map is refused before asking, an enabled one is never counted against itself", () => {
  assert.match(ninthRefused({ label: "Prop Hunt", enabled: 8 }, false)!, /Prop Hunt already has 8 enabled maps/);
  assert.equal(ninthRefused({ label: "Prop Hunt", enabled: 7 }, false), undefined);
  assert.equal(ninthRefused({ label: "Prop Hunt", enabled: 8 }, true), undefined);
});

test("a click places the tool's point, then adds to the tool's list up to its max", () => {
  let m = fresh(schema);
  const r = point(first, m, 5);
  m = r.map!;
  assert.deepEqual(m.centre, { ...at(5), heading: 90 });
  const list: BuildState = { tool: "list:spawns", heading: null };
  for (let i = 1; i <= 3; i++) m = point(list, m, i * 10).map!;
  assert.equal((m.spawns as unknown[]).length, 3);
  const over = point(list, m, 40);
  assert.match(over.error!, /At most 3/); assert.equal(over.map, undefined);
});

test("placing does not touch the map it was given", () => {
  const m = fresh(schema);
  point({ tool: "list:spawns", heading: null }, m, 1);
  assert.deepEqual(m.spawns, []);
});

test("the radius tool measures from the centre, inside the number's limits", () => {
  const radius: BuildState = { tool: "radius", heading: null };
  const empty = fresh(schema);
  assert.match(point(radius, empty, 30).error!, /centre/);
  const m = { ...empty, centre: at(0) };
  assert.equal(applyBuild(schema, m, radius, { action: "place", position: at(30, 40) }).map!.radius, 50);
  assert.equal(point(radius, m, 3).map!.radius, 10, "the minimum");
  assert.equal(point(radius, m, 3000).map!.radius, 100, "the maximum");
});

test("right click selects, Delete removes: a point goes, a list closes up", () => {
  const m = { ...fresh(schema), centre: at(0), spawns: [at(1), at(2), at(3)] };
  const list = { type: "list" as const, key: "spawns", index: 2, label: "Spawn 2" }, centre = { type: "point" as const, key: "centre", label: "Centre" };
  assert.equal(applyBuild(schema, m, first, { action: "select", hovered: centre }).select, centre);
  assert.match(applyBuild(schema, m, first, { action: "select" }).error!, /Aim at/);
  assert.equal(applyBuild(schema, m, first, { action: "delete", hovered: centre }).map!.centre, undefined);
  assert.deepEqual(applyBuild(schema, m, first, { action: "delete", hovered: list }).map!.spawns, [at(1), at(3)]);
  assert.match(applyBuild(schema, m, first, { action: "delete" }).error!, /Aim at/);
});

test("Move picks up and drops; a carried point deleted meanwhile is said", () => {
  const move: BuildState = { tool: "move", heading: null };
  const m = { ...fresh(schema), centre: at(0), spawns: [at(1), at(2)] };
  const list = { type: "list" as const, key: "spawns", index: 2, label: "Spawn 2" };
  assert.match(applyBuild(schema, m, move, { action: "place", position: at(9) }).error!, /pick it up/);
  const picked = applyBuild(schema, m, move, { action: "place", position: at(9), hovered: list });
  assert.equal(picked.build!.carrying, list); assert.equal(picked.map, undefined);
  const dropped = applyBuild(schema, m, picked.build!, { action: "place", position: at(9), heading: 10 });
  assert.deepEqual((dropped.map!.spawns as unknown[])[1], { ...at(9), heading: 10 });
  assert.equal(dropped.build!.carrying, undefined);
  const gone = { ...m, spawns: [at(1)] };
  assert.match(applyBuild(schema, gone, picked.build!, { action: "place", position: at(9) }).error!, /no longer exists/);
  const removed = applyBuild(schema, m, picked.build!, { action: "delete", hovered: list });
  assert.equal(removed.build!.carrying, undefined, "deleting what you carry drops it");
});

test("Up/Down walk the schema's tools and wrap; Left/Right turn by the delta", () => {
  const m = fresh(schema);
  assert.equal(applyBuild(schema, m, first, { action: "tool", delta: 1 }).build!.tool, "list:spawns");
  assert.equal(applyBuild(schema, m, first, { action: "tool", delta: -1 }).build!.tool, "move");
  assert.equal(applyBuild(schema, m, { ...first, carrying: undefined }, { action: "rotate", delta: 15 }).build!.heading, 15);
  assert.equal(applyBuild(schema, m, { ...first, heading: 0 }, { action: "rotate", delta: -15 }).build!.heading, 345);
  assert.match(applyBuild(schema, m, first, { action: "error", error: "Sky." }).error!, /Sky/);
  assert.match(applyBuild(schema, m, first, { action: "place" }).error!, /hit nothing/);
});

test("a tool the schema does not have falls back to its first", () => {
  assert.ok(point({ tool: "gone", heading: null }, fresh(schema), 1).map!.centre);
  assert.match(toolHelp(schema, fresh(schema), { tool: "list:spawns", heading: null }), /0\/3/);
});

test("duplicate: a new draft, disabled, the name within its limit", () => {
  const m = { ...fresh(schema), id: "a", revision: 7, enabled: true, name: "x".repeat(32), problems: ["no"] };
  const copy = duplicate(m);
  assert.equal(copy.id, ""); assert.equal(copy.revision, 0); assert.equal(copy.enabled, false); assert.deepEqual(copy.problems, []);
  assert.ok(copy.name.length <= 32 && copy.name.endsWith(" copy"));
});

/* ---- the mock behind the dev preview ---- */
function harness(staff = true) {
  const events: { kind: string; [key: string]: unknown }[] = [];
  const mock = mapEditorMock((name, value) => { assert.equal(name, PAGE_EVENTS.mapEditor); events.push(value as never); }, new URLSearchParams(staff ? "mapeditor=1&staff=1" : "mapeditor=1"));
  const ask = async (operation: string, payload: Record<string, unknown> = {}) => {
    const request = `r${events.length}`;
    mock.receive({ ...payload, operation, request });
    await new Promise(resolve => setTimeout(resolve, 200));
    return events.find(e => e.kind === "response" && e.request === request) as { ok: boolean; data: never; error?: string };
  };
  return { mock, ask, events };
}

test("the mock opens, lists, refuses a stranger", async () => {
  const { mock, ask, events } = harness();
  mock.boot(); assert.equal(events[0]!.kind, "open");
  const games = await ask("games");
  assert.equal(games.ok, true); assert.equal((games.data as { games: unknown[] }).games.length, 2);
  const stranger = harness(false);
  assert.match((await stranger.ask("games")).error!, /permission denied/);
});

test("the mock holds the server's rules: draft, stale, the ninth", async () => {
  const { ask } = harness();
  const draft = await ask("save", { game: "games.tdm", map: { id: "", revision: 0, name: "Half", enabled: false }, baseRevision: 0 });
  assert.equal(draft.ok, true);
  const map = (draft.data as { map: GameMap }).map;
  assert.ok(map.problems!.length > 0, "it says what is missing");
  assert.match((await ask("enable", { game: "games.tdm", id: map.id, enabled: true, baseRevision: 1 })).error!, /cannot be enabled/);
  assert.match((await ask("enable", { game: "games.tdm", id: "watson-docks", enabled: false, baseRevision: 9 })).error!, /changed meanwhile/);
  const ninth = await ask("save", { game: "games.prophunt", map: { id: "", revision: 0, name: "Ninth", enabled: true, propsSpawn: at(0), huntersSpawn: at(5), radius: 60 }, baseRevision: 0 });
  assert.match(ninth.error!, /already has 8 enabled maps/);
});
