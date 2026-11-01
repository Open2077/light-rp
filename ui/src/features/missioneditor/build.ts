/* Build mode: what a click, a right click, Delete, Up/Down and Left/Right do to
   the draft. Pure functions over (mission, build state, brush): the client
   (client/core/mission_editor.lua) only measures the crosshair and sends the action. */
import { BEHAVIOR_LABEL, clone, enemyLabel, LIMITS, newId, TOOL_LABEL, TOOLS, type Brush, type Mission, type Point, type Ref, type Tool } from "./model";

export interface BuildState { tool: Tool; heading: number | null; carrying?: Ref; spawn?: string }
export interface BuildAction { action: "place" | "placeFeet" | "select" | "delete" | "tool" | "rotate" | "error"; position?: Point; heading?: number; hovered?: Ref | null; delta?: number; error?: string }
export interface BuildResult { mission?: Mission; build?: BuildState; message?: string; error?: string; select?: Ref }

const r = (n: number) => Math.round(n * 100) / 100;

/** The tools offered for this draft (the size tool only makes sense for a circle or a box). */
export function toolsFor(m: Mission): Tool[] { return TOOLS.filter(t => t !== "radius" || m.perimeter.shape !== "poly"); }

export function toolHelp(tool: Tool, m: Mission, build: BuildState): string {
  switch (tool) {
    case "spawn": return "Click: place a squad with the brush settings. Right-click a spawn to edit it.";
    case "checkpoint": return "Click: place a checkpoint. Right-click it to choose the spawns it wakes.";
    case "start": return `Click: add a squad start (${m.starts.length}/${LIMITS.starts}). Left/Right: facing.`;
    case "perimeter": return m.perimeter.shape === "poly" ? "Click: add a perimeter vertex. Walk the outline in order." : "Click: move the perimeter centre.";
    case "radius": return m.perimeter.shape === "circle" ? "Click on the edge: sets the circle radius." : "Click on a corner: sets the box length and width.";
    case "patrol": {
      const s = m.spawns.find(v => v.id === build.spawn);
      return s ? `Click: add a patrol point to ${s.label} (${s.route.length}/${LIMITS.route}).` : "Right-click a spawn point first: its route gets the patrol points.";
    }
    case "move": return build.carrying ? `Click: drop ${build.carrying.label ?? "it"} here.` : "Click an element to pick it up, then click where it goes.";
    case "board": return "Click: place the board players open in the city.";
  }
}

function label(m: Mission, ref: Ref): string {
  if (ref.type === "spawn") return m.spawns.find(s => s.id === ref.id)?.label ?? "Spawn";
  if (ref.type === "checkpoint") return m.checkpoints.find(c => c.id === ref.id)?.label ?? "Checkpoint";
  return ref.label ?? ref.type;
}

/** Moves an element (and keeps its facing when the drop gives one). */
function move(m: Mission, ref: Ref, p: Point, heading: number): boolean {
  switch (ref.type) {
    case "spawn": { const s = m.spawns.find(v => v.id === ref.id); if (!s) return false;
      const dx = p.x - s.position.x, dy = p.y - s.position.y, dz = p.z - s.position.z;
      s.route = s.route.map(q => ({ x: r(q.x + dx), y: r(q.y + dy), z: r(q.z + dz) }));   // the route travels with its squad
      s.position = p; s.heading = heading; return true; }
    case "checkpoint": { const c = m.checkpoints.find(v => v.id === ref.id); if (!c) return false; c.position = p; return true; }
    case "start": { const i = (ref.index ?? 0) - 1; if (!m.starts[i]) return false; m.starts[i] = { ...p, heading }; return true; }
    case "board": m.point = p; return true;
    case "vertex": { const i = (ref.index ?? 0) - 1; if (!m.perimeter.points[i]) return false; m.perimeter.points[i] = p; return true; }
    case "centre": m.perimeter.center = p; return true;
    case "route": { const s = m.spawns.find(v => v.id === ref.id); const i = (ref.index ?? 0) - 1; if (!s?.route[i]) return false; s.route[i] = p; return true; }
  }
}

function remove(m: Mission, ref: Ref): string | undefined {
  switch (ref.type) {
    case "spawn": m.spawns = m.spawns.filter(s => s.id !== ref.id);
      m.checkpoints = m.checkpoints.map(c => ({ ...c, spawns: c.spawns.filter(id => id !== ref.id) }));
      m.waves = m.waves.map(w => ({ ...w, spawns: w.spawns.filter(id => id !== ref.id) })); return;
    case "checkpoint": m.checkpoints = m.checkpoints.filter(c => c.id !== ref.id); return;
    case "start": if (m.starts.length <= 1) return "A mission keeps at least one squad start.";
      m.starts = m.starts.filter((_, i) => i !== (ref.index ?? 0) - 1); return;
    case "vertex": m.perimeter.points = m.perimeter.points.filter((_, i) => i !== (ref.index ?? 0) - 1); return;
    case "route": { const s = m.spawns.find(v => v.id === ref.id); if (s) s.route = s.route.filter((_, i) => i !== (ref.index ?? 0) - 1); return; }
    case "board": return "The board cannot be removed: move it instead.";
    case "centre": return "The perimeter centre cannot be removed: move it instead.";
  }
}

export function applyBuild(m0: Mission, build: BuildState, brush: Brush, a: BuildAction): BuildResult {
  if (a.action === "error") return { error: a.error ?? "The crosshair hit nothing." };
  if (a.action === "tool") {
    const tools = toolsFor(m0), i = Math.max(0, tools.indexOf(build.tool));
    const tool = tools[(i + (a.delta ?? 1) + tools.length) % tools.length]!;
    return { build: { ...build, tool, carrying: tool === "move" ? build.carrying : undefined }, message: `${TOOL_LABEL[tool]} · ${toolHelp(tool, m0, build)}` };
  }
  if (a.action === "rotate") {
    const heading = (((build.heading ?? 0) + (a.delta ?? 15)) % 360 + 360) % 360;
    return { build: { ...build, heading }, message: `Facing ${heading}°. Left/Right turn it; it applies to the next placement.` };
  }
  const hovered = a.hovered ?? undefined;
  if (a.action === "select") {
    if (!hovered) return { error: "Aim at an element (it turns white) to select it." };
    return { select: hovered, build: hovered.type === "spawn" || hovered.type === "route" ? { ...build, spawn: hovered.id } : build,
      message: `${label(m0, hovered)} selected.` };
  }
  const m = clone(m0);
  if (a.action === "delete") {
    if (!hovered) return { error: "Aim at an element (it turns white) to remove it." };
    const refused = remove(m, hovered);
    if (refused) return { error: refused };
    return { mission: m, build: build.carrying && build.carrying.type === hovered.type && build.carrying.id === hovered.id ? { ...build, carrying: undefined } : build,
      message: `${label(m0, hovered)} removed.` };
  }
  // place / placeFeet
  const p = a.position, heading = a.heading ?? 0;
  if (!p) return { error: "The crosshair hit nothing." };
  switch (build.tool) {
    case "spawn": {
      if (m.spawns.length >= LIMITS.spawns) return { error: `At most ${LIMITS.spawns} spawn points.` };
      const id = newId("s", m.spawns.map(s => s.id));
      const trigger = brush.trigger === "wave" && m.type !== "waves" ? "start" : brush.trigger;
      const behavior = brush.behavior === "patrol" ? "assault" : brush.behavior;   // a patrol gets its behaviour with its first patrol point
      m.spawns.push({ id, label: `Spawn ${m.spawns.length + 1}`, position: p, heading, enemy: brush.enemy, count: brush.count, trigger,
        behavior, radius: brush.radius, alertRange: brush.alertRange, spread: brush.spread, route: [] });
      return { mission: m, build: { ...build, spawn: id },
        message: `Spawn ${m.spawns.length}: ${brush.count}× ${enemyLabel(brush.enemy)}, ${BEHAVIOR_LABEL[behavior].toLowerCase()}${trigger !== "start" ? ` (${trigger === "wave" ? "add it to a wave" : "link it from a checkpoint"})` : ""}.` };
    }
    case "checkpoint": {
      if (m.checkpoints.length >= LIMITS.checkpoints) return { error: `At most ${LIMITS.checkpoints} checkpoints.` };
      const id = newId("c", m.checkpoints.map(c => c.id));
      m.checkpoints.push({ id, label: `Checkpoint ${m.checkpoints.length + 1}`, position: p, radius: brush.checkpointRadius, required: true, spawns: [] });
      return { mission: m, message: `Checkpoint ${m.checkpoints.length} placed. Right-click it to choose the spawns it wakes.` };
    }
    case "start":
      if (m.starts.length >= LIMITS.starts) return { error: `At most ${LIMITS.starts} squad starts.` };
      m.starts.push({ ...p, heading });
      return { mission: m, message: `Squad start ${m.starts.length} placed, facing ${Math.round(heading)}°.` };
    case "perimeter": {
      const z = m.perimeter;
      if (z.shape === "poly") {
        if (z.points.length >= LIMITS.vertices) return { error: `At most ${LIMITS.vertices} vertices.` };
        z.points.push(p);
        if (!z.fullHeight && (p.z < z.minZ + 1 || p.z > z.maxZ - 1)) { z.minZ = Math.min(z.minZ, r(p.z - 5)); z.maxZ = Math.max(z.maxZ, r(p.z + 20)); }
        return { mission: m, message: `Vertex ${z.points.length} placed.${z.points.length < 3 ? ` ${3 - z.points.length} more to close the shape.` : ""}` };
      }
      const h = z.maxZ - z.minZ;
      z.center = p;
      if (!z.fullHeight) { z.minZ = r(p.z - Math.min(10, h / 3)); z.maxZ = r(z.minZ + h); }
      return { mission: m, message: "Perimeter centre moved." };
    }
    case "radius": {
      const z = m.perimeter;
      if (z.shape === "circle") {
        z.radius = Math.min(250, Math.max(0.5, r(Math.hypot(p.x - z.center.x, p.y - z.center.y))));
        return { mission: m, message: `Perimeter radius ${z.radius} m.` };
      }
      if (z.shape === "box") {
        const a2 = -z.heading * Math.PI / 180, dx = p.x - z.center.x, dy = p.y - z.center.y;
        z.length = Math.min(500, Math.max(0.5, r(2 * Math.abs(dx * Math.cos(a2) - dy * Math.sin(a2)))));
        z.width = Math.min(500, Math.max(0.5, r(2 * Math.abs(dx * Math.sin(a2) + dy * Math.cos(a2)))));
        return { mission: m, message: `Perimeter box ${z.length} × ${z.width} m.` };
      }
      return { error: "A polygon is sized by its vertices (Perimeter tool)." };
    }
    case "patrol": {
      const s = m.spawns.find(v => v.id === build.spawn);
      if (!s) return { error: "Right-click a spawn point first: its route gets the patrol points." };
      if (s.route.length >= LIMITS.route) return { error: `At most ${LIMITS.route} patrol points per spawn point.` };
      s.route.push(p);
      const switched = s.behavior !== "patrol";
      s.behavior = "patrol";
      return { mission: m, message: `${s.label}: patrol point ${s.route.length}.${switched ? " Its behaviour is now Patrol." : ""}` };
    }
    case "move": {
      if (!build.carrying) {
        if (!hovered) return { error: "Aim at an element (it turns white) to pick it up." };
        return { build: { ...build, carrying: hovered }, message: `${label(m0, hovered)} picked up. Click where it goes.` };
      }
      if (!move(m, build.carrying, p, heading)) return { build: { ...build, carrying: undefined }, error: "That element no longer exists." };
      return { mission: m, build: { ...build, carrying: undefined }, message: `${label(m0, build.carrying)} moved.` };
    }
    case "board": m.point = p; return { mission: m, message: "Mission board moved." };
  }
}
