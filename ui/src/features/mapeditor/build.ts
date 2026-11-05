/* Build mode of the map editor: what a click, a right click, Delete, Up/Down and Left/Right do to
   the draft. Pure functions, as the mission editor's build.ts: the client only measures. */
import { clone } from "@/features/missioneditor/model";
import { toolsFor, type GameMap, type Point, type Ref, type Schema, type Spot, type Tool } from "./model";

export interface BuildState { tool: string; heading: number | null; carrying?: Ref }
export interface BuildAction { action: "place" | "placeFeet" | "select" | "delete" | "tool" | "rotate" | "error"; position?: Point; heading?: number; hovered?: Ref | null; delta?: number; error?: string }
export interface BuildResult { map?: GameMap; build?: BuildState; message?: string; error?: string; select?: Ref }

const r = (n: number) => Math.round(n * 100) / 100;
const spots = (map: GameMap, key: string) => (map[key] ?? []) as Spot[];
const toolOf = (schema: Schema, id: string): Tool => { const tools = toolsFor(schema); return tools.find(t => t.id === id) ?? tools[0]!; };

export function toolHelp(schema: Schema, map: GameMap, build: BuildState): string {
  const tool = toolOf(schema, build.tool);
  if (tool.kind === "point") return `Click: place ${tool.label}. Left/Right: facing.`;
  if (tool.kind === "list") {
    const l = schema.lists.find(v => v.key === tool.key)!;
    return `Click: add a ${l.label} (${spots(map, l.key).length}/${l.max}). Left/Right: facing.`;
  }
  if (tool.kind === "radius") return "Click on the edge: sets the play area's radius.";
  return build.carrying ? `Click: drop ${build.carrying.label ?? "it"} here.` : "Click a placed point to pick it up, then click where it goes.";
}

export function applyBuild(schema: Schema, map0: GameMap, build: BuildState, a: BuildAction): BuildResult {
  if (a.action === "error") return { error: a.error ?? "The crosshair hit nothing." };
  const tools = toolsFor(schema);
  if (a.action === "tool") {
    const i = Math.max(0, tools.findIndex(t => t.id === build.tool));
    const tool = tools[(i + (a.delta ?? 1) + tools.length) % tools.length]!;
    const next = { ...build, tool: tool.id, carrying: tool.kind === "move" ? build.carrying : undefined };
    return { build: next, message: `${tool.label} · ${toolHelp(schema, map0, next)}` };
  }
  if (a.action === "rotate") {
    const heading = (((build.heading ?? 0) + (a.delta ?? 15)) % 360 + 360) % 360;
    return { build: { ...build, heading }, message: `Facing ${heading}°. Left/Right turn it; it applies to the next placement.` };
  }
  const hovered = a.hovered ?? undefined;
  if (a.action === "select") {
    if (!hovered) return { error: "Aim at a point (it turns white) to select it." };
    return { select: hovered, message: `${hovered.label ?? hovered.key} selected.` };
  }
  const map = clone(map0);
  if (a.action === "delete") {
    if (!hovered) return { error: "Aim at a point (it turns white) to remove it." };
    if (hovered.type === "point") delete map[hovered.key];
    else map[hovered.key] = spots(map, hovered.key).filter((_, i) => i !== (hovered.index ?? 0) - 1);
    const carried = build.carrying;
    return { map, build: carried && carried.key === hovered.key && carried.index === hovered.index ? { ...build, carrying: undefined } : build,
      message: `${hovered.label ?? hovered.key} removed.` };
  }
  // place / placeFeet
  const p = a.position, heading = a.heading ?? 0;
  if (!p) return { error: "The crosshair hit nothing." };
  const tool = toolOf(schema, build.tool);
  const spot: Spot = { ...p, heading };
  switch (tool.kind) {
    case "point":
      map[tool.key!] = spot;
      return { map, message: `${tool.label} placed, facing ${Math.round(heading)}°.` };
    case "list": {
      const l = schema.lists.find(v => v.key === tool.key)!, list = spots(map, l.key);
      if (list.length >= l.max) return { error: `At most ${l.max}: ${l.label}.` };
      map[l.key] = [...list, spot];
      return { map, message: `${l.label} ${list.length + 1} placed, facing ${Math.round(heading)}°.` };
    }
    case "radius": {
      const area = schema.area!, centre = map[area.centre] as Spot | undefined;
      const number = schema.numbers.find(n => n.key === area.radius)!;
      if (!centre) return { error: "Place the centre of the play area first." };
      map[area.radius] = Math.min(number.max, Math.max(number.min, r(Math.hypot(p.x - centre.x, p.y - centre.y))));
      return { map, message: `Play area radius ${map[area.radius] as number} m.` };
    }
    case "move": {
      const carried = build.carrying;
      if (!carried) {
        if (!hovered) return { error: "Aim at a point (it turns white) to pick it up." };
        return { build: { ...build, carrying: hovered }, message: `${hovered.label ?? hovered.key} picked up. Click where it goes.` };
      }
      if (carried.type === "point") { if (!map[carried.key]) return { build: { ...build, carrying: undefined }, error: "That point no longer exists." }; map[carried.key] = spot; }
      else {
        const list = spots(map, carried.key), i = (carried.index ?? 0) - 1;
        if (!list[i]) return { build: { ...build, carrying: undefined }, error: "That point no longer exists." };
        list[i] = spot;
      }
      return { map, build: { ...build, carrying: undefined }, message: `${carried.label ?? carried.key} moved.` };
    }
  }
}
