/* A game map as the server keeps it (server/modules/game_maps.lua): flat, its fields named by the
   game's schema (declared next to the game's rules, op77_games/server/modes). The server is the
   authority: `problems` mirrors server/modules/game_map_rules.lua R.problems so the menu can
   say what is missing before asking. */
import { clone, type Capture, type Point } from "@/features/missioneditor/model";
import type { EditorEvent } from "@/features/missioneditor/api";
import type { IconName } from "@/design/components";

export type { Capture, Point };
export interface Spot extends Point { heading?: number }
export interface SchemaPoint { key: string; label: string; color: string; hidden?: boolean }
export interface SchemaList { key: string; label: string; color: string; min: number; max: number }
export interface SchemaNumber { key: string; label: string; min: number; max: number; default: number; unit: string; integer?: boolean; hidden?: boolean }
export interface SchemaChoice { key: string; label: string; about: string; options: { id: string; label: string }[] }
export interface Schema {
  points: SchemaPoint[]; lists: SchemaList[]; numbers: SchemaNumber[]; choices: SchemaChoice[];
  area?: { centre: string; radius: string; flat?: boolean; holds: string[] };
  apart: { a: string; b: string; metres: number }[];
}
export interface Game { id: string; label: string; schema: Schema; total: number; enabled: number }
/** `game`: stamped by the server on every map it sends. Ids repeat across games, a save sends it back. */
export interface GameMap { id: string; revision: number; name: string; enabled: boolean; game?: string; problems?: string[]; [key: string]: unknown }
/** What the crosshair points at (client/core/map_editor.lua). */
export interface Ref { type: "point" | "list"; key: string; index?: number; label?: string; position?: Point }
export interface Listing { ready?: boolean; total?: number; streamed?: boolean }
export interface GamesReply { ready?: boolean; games?: Game[]; maxEnabled?: number; maxMaps?: number }
export interface Wire extends EditorEvent {
  mode?: string; stream?: string; index?: number; total?: number; map?: GameMap; hovered?: Ref | null; shown?: number; full?: number;
}
/** What the 3D preview fits under the line cap (client/core/map_editor.lua). */
export type Drawn = Required<Pick<Wire, "total" | "shown" | "full">>;

export const LIMITS = { enabled: 8, name: 32 };
const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? value : []) as T[];

/** Lua sends empty arrays as {} and omits nil fields. */
export function normalizeSchema(s: Partial<Schema> | undefined): Schema {
  return { points: list(s?.points), lists: list(s?.lists), numbers: list(s?.numbers),
    choices: list<SchemaChoice>(s?.choices).map(c => ({ ...c, options: list(c.options) })),
    area: s?.area ? { ...s.area, holds: list(s.area.holds) } : undefined, apart: list(s?.apart) };
}
export function normalizeMap(schema: Schema, m: GameMap): GameMap {
  const out: GameMap = { ...m, problems: list(m.problems) };
  for (const l of schema.lists) out[l.key] = list(m[l.key]);
  for (const n of schema.numbers) out[n.key] = m[n.key] ?? n.default;
  for (const c of schema.choices) out[c.key] = list(m[c.key]);
  return out;
}
/** A list streams one map per event: only the listing open now counts, a late one is another game's. */
export const ofListing = (open: string, event: Pick<Wire, "stream">) => open !== "" && event.stream === open;
/** The list once this event landed: the same list when the event is stale. */
export function receiveListed(open: string, schema: Schema | undefined, list: GameMap[], event: Pick<Wire, "stream" | "map">): GameMap[] {
  if (!schema || !event.map || !ofListing(open, event)) return list;
  const m = normalizeMap(schema, event.map);
  return [...list.filter(x => x.id !== m.id), m].sort((a, b) => a.name === b.name ? a.id.localeCompare(b.id) : a.name.localeCompare(b.name));
}
/** What the build mode says when the preview left something out, or undefined. */
export function drawingNote(d: Drawn | null): string | undefined {
  if (!d) return undefined;
  if (d.shown < d.total) return `${d.total - d.shown} of ${d.total} points not drawn: too many for the preview, the nearest are shown.`;
  if (d.full < d.total) return `${d.full} of ${d.total} points drawn in full, the others as simple markers: nearest first.`;
  return undefined;
}

export function fresh(schema: Schema): GameMap { return normalizeMap(schema, { id: "", revision: 0, name: "New map", enabled: false }); }
export function duplicate(map: GameMap): GameMap {
  const copy = clone(map);
  return { ...copy, id: "", revision: 0, enabled: false, problems: [], name: `${map.name.slice(0, LIMITS.name - 5)} copy` };
}

const spotsOf = (schema: Schema, map: GameMap, key: string): { at: Spot; label: string }[] => {
  const point = schema.points.find(p => p.key === key);
  if (point) return map[key] ? [{ at: map[key] as Spot, label: point.label }] : [];
  const l = schema.lists.find(v => v.key === key);
  return l ? list<Spot>(map[key]).map((at, i) => ({ at, label: `${l.label} ${i + 1}` })) : [];
};
const gap = (a: Spot, b: Spot, flat: boolean) => Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2 + (flat ? 0 : (a.z - b.z) ** 2));

/** What stops this map being enabled, in the server's order and words. */
export function problems(schema: Schema, map: GameMap): string[] {
  const out: string[] = [];
  for (const p of schema.points) if (!p.hidden && !map[p.key]) out.push(`Place ${p.label}.`);
  for (const l of schema.lists) {
    const have = list(map[l.key]).length;
    if (have < l.min) out.push(`${l.label}: at least ${l.min}, ${have} placed.`);
  }
  const area = schema.area;
  if (area) {
    const centre = map[area.centre] as Spot | undefined, radius = map[area.radius] as number | undefined;
    if (centre && radius != null) for (const key of area.holds) for (const spot of spotsOf(schema, map, key)) {
      if (gap(spot.at, centre, area.flat === true) > radius) out.push(`${spot.label} is outside the play area.`);
    }
  }
  for (const pair of schema.apart) {
    let reported = false;
    for (const a of spotsOf(schema, map, pair.a)) for (const b of spotsOf(schema, map, pair.b)) {
      if (!reported && gap(a.at, b.at, true) < pair.metres) { reported = true; out.push(`${a.label} and ${b.label} must be ${pair.metres} m apart.`); }
    }
  }
  return out;
}

/** Why this game takes no further enabled map, or undefined. */
export function ninthRefused(game: Pick<Game, "label" | "enabled">, alreadyEnabled: boolean): string | undefined {
  if (alreadyEnabled || game.enabled < LIMITS.enabled) return undefined;
  return `${game.label} already has ${LIMITS.enabled} enabled maps, the most the rooms menu can list. Disable one first.`;
}

/** The build mode's tools, from the schema, in the Up/Down order. */
export interface Tool { id: string; kind: "point" | "list" | "radius" | "move"; key?: string; label: string; color: string; icon: IconName }
export function toolsFor(schema: Schema): Tool[] {
  const tools: Tool[] = [];
  for (const p of schema.points) if (!p.hidden) tools.push({ id: `point:${p.key}`, kind: "point", key: p.key, label: p.label, color: p.color, icon: "map-pin" });
  for (const l of schema.lists) tools.push({ id: `list:${l.key}`, kind: "list", key: l.key, label: l.label, color: l.color, icon: "users" });
  if (schema.area) tools.push({ id: "radius", kind: "radius", label: "Radius", color: "#ffcc00", icon: "activity" });
  tools.push({ id: "move", kind: "move", label: "Move", color: "#ffffff", icon: "hand" });
  return tools;
}

/** What client/core/map_editor.lua needs to draw and aim: the positions only, never a hidden one. */
export function drawing(schema: Schema) {
  return { layers: [...schema.points.filter(p => !p.hidden).map(p => ({ key: p.key, kind: "point" as const, label: p.label, color: `${p.color}ff` })),
    ...schema.lists.map(l => ({ key: l.key, kind: "list" as const, label: l.label, color: `${l.color}ff` }))],
    area: schema.area ? { centre: schema.area.centre, radius: schema.area.radius } : null };
}
