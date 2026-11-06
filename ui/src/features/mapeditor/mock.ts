import { PAGE_EVENTS } from "@/bridge/protocol";
import { clone } from "@/features/missioneditor/model";
import { LIMITS, normalizeMap, normalizeSchema, problems, type Game, type GameMap, type Schema } from "./model";

const ARENA: Partial<Schema> = {
  points: [{ key: "centre", label: "Play area centre", color: "#ffcc00" }],
  lists: [{ key: "spawns", label: "Spawn", color: "#3ddc84", min: 2, max: 32 }],
  numbers: [{ key: "radius", label: "Play area radius", min: 10, max: 400, default: 70, unit: "m" }],
  area: { centre: "centre", radius: "radius", holds: ["spawns"] },
};
const PROPHUNT: Partial<Schema> = {
  points: [{ key: "propsSpawn", label: "Props' spawn", color: "#3ddc84" }, { key: "huntersSpawn", label: "Hunters' spawn", color: "#ff4d4d" }],
  numbers: [{ key: "radius", label: "Play area radius", min: 10, max: 400, default: 65, unit: "m" },
    { key: "hideSeconds", label: "Hide time", min: 10, max: 180, default: 45, unit: "s", integer: true },
    { key: "roundSeconds", label: "Hunt time", min: 60, max: 1200, default: 300, unit: "s", integer: true }],
  choices: [{ key: "props", label: "Objects", about: "None ticked: every object.", options: [{ id: "container.barrel", label: "Barrel" }, { id: "kitchen.fridge", label: "Fridge" }, { id: "crate.small", label: "Small crate" }] }],
  area: { centre: "propsSpawn", radius: "radius", flat: true, holds: ["huntersSpawn"] },
};

/** Browser fixture of the map editor (`?mapeditor=1&staff=1`). */
export function mapEditorMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const origin = { x: -1579, y: 3031, z: 8 };
  const allowed = params.get("staff") === "1";
  const games: Game[] = [
    { id: "games.tdm", label: "Team Deathmatch", schema: normalizeSchema(ARENA), total: 0, enabled: 0 },
    { id: "games.prophunt", label: "Prop Hunt", schema: normalizeSchema(PROPHUNT), total: 0, enabled: 0 },
  ];
  const maps: Record<string, GameMap[]> = {
    "games.tdm": [{ id: "watson-docks", revision: 1, name: "Watson Docks", enabled: true, centre: origin, radius: 55,
      spawns: [{ x: -1540, y: 3037, z: 8, heading: 87 }, { x: -1619, y: 3025, z: 8, heading: 300 }] },
    { id: "half-built", revision: 2, name: "Half built", enabled: false, radius: 70, spawns: [{ x: -1540, y: 3037, z: 8, heading: 87 }] }],
    "games.prophunt": Array.from({ length: 8 }, (_, i) => ({ id: `map-${i + 1}`, revision: 1, name: `Hideout ${i + 1}`, enabled: true, propsSpawn: origin,
      huntersSpawn: { ...origin, x: origin.x + 10 }, radius: 60, hideSeconds: 45, roundSeconds: 300, props: [] })),
  };
  const replies = new Map<string, unknown>();
  let step = 0;
  const stored = (game: Game, m: GameMap) => { const n = normalizeMap(game.schema, clone(m)); n.problems = problems(game.schema, n); n.game = game.id; return n; };
  const count = () => games.map(g => ({ ...g, total: maps[g.id]!.length, enabled: maps[g.id]!.filter(m => m.enabled).length }));
  const boot = () => { if (params.get("mapeditor") === "1") fire(PAGE_EVENTS.mapEditor, { kind: "open" }); };
  const receive = (payload: unknown) => {
    const p = payload as { operation: string; request?: string; game?: string; map?: GameMap; id?: string; enabled?: boolean; baseRevision?: number; mutation?: string };
    if (p.operation === "input" || p.operation === "preview" || p.operation === "close") return;
    const respond = (ok: boolean, data?: unknown, error?: string) => fire(PAGE_EVENTS.mapEditor, { kind: "response", request: p.request, ok, data, error });
    setTimeout(() => {
      if (p.operation === "capture") {
        const a = step++ * 0.9, r = (n: number) => Math.round(n * 100) / 100;
        respond(true, { position: { x: r(origin.x + Math.cos(a) * 12), y: r(origin.y + Math.sin(a) * 12), z: origin.z }, heading: (step * 40) % 360 });
        return;
      }
      if (!allowed) { respond(false, undefined, "Map editor permission denied."); return; }
      if (p.operation === "games") { respond(true, { ready: true, games: count(), maxEnabled: LIMITS.enabled, maxMaps: 32 }); return; }
      const game = games.find(g => g.id === p.game);
      if (!game) { respond(false, undefined, "That game is not available: op77_games must be running."); return; }
      const list = maps[game.id]!;
      if (p.operation === "list") {
        respond(true, { ready: true, total: list.length, streamed: true });
        list.forEach((m, i) => setTimeout(() => fire(PAGE_EVENTS.mapEditor, { kind: "map", stream: p.request, index: i + 1, total: list.length, map: stored(game, m) }), 60 * (i + 1)));
        setTimeout(() => fire(PAGE_EVENTS.mapEditor, { kind: "listed", stream: p.request, total: list.length }), 60 * (list.length + 1));
        return;
      }
      if (p.mutation && replies.has(p.mutation)) { respond(true, replies.get(p.mutation)); return; }
      const finish = (data: unknown) => { if (p.mutation) replies.set(p.mutation, data); respond(true, data); };
      const old = list.find(m => m.id === (p.operation === "save" ? p.map?.id : p.id));
      if (old && old.revision !== p.baseRevision) { respond(false, undefined, "This map changed meanwhile. Refresh before saving."); return; }
      const gate = (m: GameMap) => {
        const issues = problems(game.schema, normalizeMap(game.schema, m));
        if (issues.length) return `This map cannot be enabled. ${issues[0]}`;
        if (list.filter(x => x.enabled && x.id !== m.id).length >= LIMITS.enabled) return `${game.label} already has ${LIMITS.enabled} enabled maps, the most the rooms menu can list. Disable one first.`;
        return undefined;
      };
      if (p.operation === "save" && p.map) {
        if (p.map.id && p.map.game !== game.id) { respond(false, undefined, "This map belongs to another game. Refresh the list."); return; }
        const why = p.map.enabled ? gate(p.map) : undefined;
        if (why) { respond(false, undefined, why); return; }
        const saved: GameMap = { ...clone(p.map), id: p.map.id || p.map.name.toLowerCase().replace(/[^a-z0-9]+/g, "-"), revision: (old?.revision ?? 0) + 1 };
        if (old) list.splice(list.indexOf(old), 1, saved); else list.push(saved);
        finish({ map: stored(game, saved) });
      } else if (p.operation === "enable" && old) {
        const next = { ...old, enabled: p.enabled === true, revision: old.revision + 1 };
        const why = next.enabled ? gate(next) : undefined;
        if (why) { respond(false, undefined, why); return; }
        list.splice(list.indexOf(old), 1, next);
        finish({ map: stored(game, next) });
      } else if (p.operation === "delete" && old) { list.splice(list.indexOf(old), 1); finish({ id: old.id }); }
      else respond(false, undefined, "This map no longer exists.");
    }, 120);
  };
  return { boot, receive };
}
