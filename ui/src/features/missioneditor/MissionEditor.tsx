import { useCallback, useEffect, useRef, useState } from "react";
import { emit } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { MissionRequestTimeout, mutationKey, onEditor, request } from "./api";
import {
  BEHAVIOR_HELP, BEHAVIOR_LABEL, BEHAVIORS, BRUSH, clone, DIFFICULTIES, ENEMIES, enemyLabel, fresh, LIMITS, newId, normalizeMission, problems,
  SHAPE_LABEL, SHAPES, TOOL_LABEL, TRIGGER_LABEL, TRIGGERS, TYPE_LABEL, TYPES,
  type Behavior, type Brush, type Capture, type Checkpoint, type Listing, type Mission, type Point, type Ref, type Spawn, type Tool, type Wave,
} from "./model";
import { applyBuild, type BuildAction, type BuildState } from "./build";
import { BuildHud } from "./BuildHud";
import "@/features/support/support.css";
import "@/features/safezones/safezones.css";
import "./missioneditor.css";

type Kind = "list" | "mission" | "general" | "perimeter" | "vertices" | "vertex" | "starts" | "start" | "spawns" | "spawn"
  | "checkpoints" | "checkpoint" | "waves" | "wave" | "rules" | "fixer" | "worldboss" | "difficulties" | "difficulty" | "test" | "issues" | "discard" | "delete"
  | "brush" | "route";
type Page = { kind: Kind; selected?: string; index?: number; key?: string };
type Entry = RageMenuItem & { run?: () => void; change?: (patch: Partial<RageMenuItem>) => void };
type TextEdit = { id: string; value: string; replace: boolean; numeric: boolean; max: number; commit: (value: string) => string | undefined };
type CaptureMode = "feet" | "aim";
const STEPS = [0.1, 1, 5, 10];
const message = (error: unknown) => error instanceof Error ? error.message : "The request failed.";
const rounded = (value: number) => Math.round(value * 1000) / 1000;
const PLACEABLE: Kind[] = ["mission", "general", "perimeter", "vertices", "vertex", "starts", "start", "spawns", "spawn", "checkpoints", "checkpoint"];
const coords = (p: Point) => `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}`;

/** Staff mission editor (/lightrp.missions): the keyboard shell of /admin and the safe zones. */
export function MissionEditor() {
  const [opened, setOpened] = useState(false), [missions, setMissions] = useState<Mission[]>([]), [ready, setReady] = useState(false);
  const [fixers, setFixers] = useState<{ id: string; name: string }[]>([]);
  const [mapPins, setMapPins] = useState(false);
  // the list fills mission by mission (`mission` events after `list`)
  const [loading, setLoading] = useState<{ received: number; total: number } | null>(null);
  const [draft, setDraft] = useState<Mission>(), [original, setOriginal] = useState("");
  const [stack, setStack] = useState<Page[]>([{ kind: "list" }]), [world, setWorld] = useState(false);
  const [editing, setEditing] = useState<TextEdit>(), [stepIndex, setStepIndex] = useState(1);
  const [busy, setBusy] = useState(false), [unconfirmed, setUnconfirmed] = useState<"save" | "delete">();
  const [error, setError] = useState(""), [feedback, setFeedback] = useState("");
  const [build, setBuild] = useState<BuildState>({ tool: "spawn", heading: null }), [brush, setBrush] = useState<Brush>(BRUSH);
  const [hovered, setHovered] = useState<Ref | null>(null), [buildNote, setBuildNote] = useState<{ message?: string; error?: string }>({});
  const live = useRef(true), working = useRef(false), menu = useRef<HTMLDivElement>(null);
  const mutation = useRef<{ signature: string; key: string }>();
  const top = stack[stack.length - 1]!;
  const current = useRef({ opened, draft, top, typing: false, build, brush });
  current.current = { opened, draft, top, typing: !!editing, build, brush };
  const locked = busy || !!unconfirmed;
  const changed = !!draft && JSON.stringify(draft) !== original;
  const update = (patch: Partial<Mission> | ((m: Mission) => Partial<Mission>)) =>
    setDraft(previous => previous ? { ...previous, ...(typeof patch === "function" ? patch(previous) : patch) } : previous);
  const push = (page: Page) => { setError(""); setFeedback(""); setStack(previous => [...previous, page]); };
  const pop = () => { setError(""); setStack(previous => previous.length > 1 ? previous.slice(0, -1) : previous); };

  const refresh = useCallback(async () => {
    const data = await request<Listing>("list");
    if (!live.current) return;
    setReady(data.ready === true);
    setFixers(Array.isArray(data.fixers) ? data.fixers : []);
    if (data.streamed) {
      // each mission arrives in its own event: the menu stays usable meanwhile
      setMissions([]);
      setLoading(data.total ? { received: 0, total: data.total } : null);
    } else setMissions(Array.isArray(data.missions) ? data.missions.map(normalizeMission) : []);
  }, []);
  const run = useCallback(async (task: () => Promise<void>) => {
    if (working.current) return;
    working.current = true; setBusy(true); setError(""); setFeedback("");
    try { await task(); } catch (reason) { if (live.current) setError(message(reason)); }
    finally { working.current = false; if (live.current) setBusy(false); }
  }, []);
  const clearDraft = useCallback(() => {
    setDraft(undefined); setOriginal(""); setWorld(false); setEditing(undefined);
    setStack([{ kind: "list" }]); setUnconfirmed(undefined); mutation.current = undefined;
    emit(PAGE_EVENTS.missionEditor, { operation: "preview", mission: null });
  }, []);
  const close = useCallback(() => {
    clearDraft(); setOpened(false); setError(""); emit(PAGE_EVENTS.missionEditor, { operation: "close" });
  }, [clearDraft]);

  /* F10 / F11 (and the menu's "place" rows): what the open page edits moves to the feet / the crosshair. */
  const place = useCallback((mode: CaptureMode) => run(async () => {
    const state = current.current;
    if (!state.draft || !state.opened || state.typing) return;
    const page = state.top;
    if (!PLACEABLE.includes(page.kind)) throw new Error("Open the element to place first (board, perimeter, start, spawn or checkpoint).");
    const c = await request<Capture>("capture", { mode });
    if (!live.current || !current.current.opened) return;
    const p = c.position;
    setDraft(previous => {
      if (!previous) return previous;
      const m = clone(previous);
      const z = m.perimeter;
      switch (page.kind) {
        case "mission": case "general": m.point = p; break;
        case "perimeter":
          if (z.shape === "poly") { if (z.points.length < LIMITS.vertices) z.points.push(p); }
          else { z.center = p; if (!z.fullHeight) { const h = z.maxZ - z.minZ; z.minZ = rounded(p.z - Math.min(10, h / 3)); z.maxZ = rounded(z.minZ + h); } }
          break;
        case "vertices": if (z.points.length < LIMITS.vertices) z.points.push(p); break;
        case "vertex": if (page.index != null && z.points[page.index]) z.points[page.index] = p; break;
        case "starts": if (m.starts.length < LIMITS.starts) m.starts.push({ ...p, heading: c.heading }); break;
        case "start": if (page.index != null && m.starts[page.index]) m.starts[page.index] = { ...p, heading: c.heading }; break;
        case "spawns": if (m.spawns.length < LIMITS.spawns) {
          const id = newId("s", m.spawns.map(s => s.id));
          const b = current.current.brush;
          m.spawns.push({ id, label: `Spawn ${m.spawns.length + 1}`, position: p, heading: c.heading, enemy: b.enemy, count: b.count,
            trigger: b.trigger === "wave" && m.type !== "waves" ? "start" : b.trigger, behavior: b.behavior === "patrol" ? "assault" : b.behavior,
            radius: b.radius, alertRange: b.alertRange, spread: b.spread, route: [] });
        } break;
        case "spawn": { const s = m.spawns.find(s => s.id === page.key); if (s) { s.position = p; s.heading = c.heading; } break; }
        case "checkpoints": if (m.checkpoints.length < LIMITS.checkpoints) {
          const id = newId("c", m.checkpoints.map(c => c.id));
          m.checkpoints.push({ id, label: `Checkpoint ${m.checkpoints.length + 1}`, position: p, radius: current.current.brush.checkpointRadius, required: true, spawns: [] });
        } break;
        case "checkpoint": { const cp = m.checkpoints.find(c => c.id === page.key); if (cp) cp.position = p; break; }
        default: break;
      }
      return m;
    });
  }), [run]);

  useEffect(() => {
    live.current = true;
    const off = onEditor(event => {
      if (event.kind === "mission" && event.mission) {
        const m = normalizeMission(event.mission);
        setMissions(previous => [...previous.filter(x => x.id !== m.id), m]
          .sort((a, b) => a.title === b.title ? a.id.localeCompare(b.id) : a.title.localeCompare(b.title)));
        setLoading(previous => previous ? { ...previous, received: Math.min(previous.total, previous.received + 1) } : previous);
        return;
      }
      if (event.kind === "listed") { setLoading(null); return; }
      if (event.kind === "open") {
        useStore.getState().closeDialog(); useStore.getState().closeMenu();
        setOpened(true); setWorld(false); setError(""); void run(refresh);
      } else if (event.kind === "editor" && current.current.opened && !current.current.typing) setWorld(event.mode === "world");
      else if (event.kind === "hover") setHovered((event as unknown as { hovered?: Ref | null }).hovered ?? null);
      else if (event.kind === "build") onBuild.current(event as unknown as BuildAction);
      else if (event.kind === "captureKey") void place(event.mode === "aim" ? "aim" : "feet");
      else if (event.kind === "invalidate") {
        close(); useStore.getState().pushNotice({ kind: "warning", title: "Mission editor", body: event.error || "The editor closed.", durationMs: 8000 });
      }
    });
    return () => { live.current = false; off(); emit(PAGE_EVENTS.missionEditor, { operation: "close" }); };
  }, [close, place, refresh, run]);
  useEffect(() => {
    if (!opened) return;
    emit(PAGE_EVENTS.missionEditor, { operation: "input", mode: world ? "world" : editing ? "typing" : "menu" });
    if (!world) menu.current?.focus();
  }, [opened, world, !!editing]);
  // Build mode actions (client/core/mission_editor.lua) -> build.ts
  const onBuild = useRef<(a: BuildAction) => void>(() => undefined);
  onBuild.current = (a: BuildAction) => {
    const state = current.current;
    if (!state.draft || !state.opened) return;
    const result = applyBuild(state.draft, state.build, state.brush, a);
    if (result.mission) setDraft(normalizeMission(result.mission));
    if (result.build) setBuild(result.build);
    setBuildNote({ message: result.message, error: result.error });
    if (result.select) openRef(result.select);
  };
  /* Right-click in build mode: the menu opens on the aimed element's own page. */
  const openRef = (ref: Ref) => {
    const base: Page[] = [{ kind: "list" }, { kind: "mission" }];
    const pages: Page[] = ref.type === "spawn" ? [{ kind: "spawns" }, { kind: "spawn", key: ref.id }]
      : ref.type === "route" ? [{ kind: "spawns" }, { kind: "spawn", key: ref.id }, { kind: "route", key: ref.id }]
      : ref.type === "checkpoint" ? [{ kind: "checkpoints" }, { kind: "checkpoint", key: ref.id }]
      : ref.type === "start" ? [{ kind: "starts" }, { kind: "start", index: (ref.index ?? 1) - 1 }]
      : ref.type === "vertex" ? [{ kind: "perimeter" }, { kind: "vertices" }, { kind: "vertex", index: (ref.index ?? 1) - 1 }]
      : ref.type === "centre" ? [{ kind: "perimeter" }] : [{ kind: "general" }];
    setStack([...base, ...pages]); setWorld(false); setError(""); setFeedback("");
  };
  const enterBuild = (tool?: Tool, spawn?: string) => {
    setBuild(previous => ({ ...previous, tool: tool ?? previous.tool, carrying: undefined, spawn: spawn ?? previous.spawn }));
    setBuildNote({ message: tool ? `${TOOL_LABEL[tool]} tool.` : undefined }); setHovered(null); setWorld(true);
  };
  const focus = top.kind === "perimeter" || top.kind === "vertices" || top.kind === "vertex" ? "perimeter"
    : top.kind === "start" ? `start:${(top.index ?? 0) + 1}` : top.kind === "spawn" ? `spawn:${top.key}`
    : top.kind === "checkpoint" ? `checkpoint:${top.key}` : top.kind === "general" || top.kind === "mission" ? "board" : undefined;
  const buildWire = { tool: build.tool, heading: build.heading, carrying: build.carrying ?? null, spawn: build.spawn ?? null,
    count: brush.count, spread: brush.spread, radius: brush.checkpointRadius };
  const buildKey = JSON.stringify(buildWire);
  useEffect(() => { if (opened) emit(PAGE_EVENTS.missionEditor, { operation: "preview", mission: draft ?? null, focus, build: buildWire }); }, [draft, opened, focus, buildKey]);
  // Full keyboard capture while typing a row's value.
  useEffect(() => {
    if (!opened || !editing) return;
    const handler = (event: KeyboardEvent) => {
      event.stopPropagation();
      if (event.key === "Enter") {
        event.preventDefault(); if (event.repeat) return;
        const reason = editing.commit(editing.value);
        if (reason) setError(reason); else { setEditing(undefined); setError(""); }
      } else if (event.key === "Escape") { event.preventDefault(); setEditing(undefined); setError(""); }
      else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "a") { event.preventDefault(); setEditing(previous => previous ? { ...previous, replace: true } : previous); }
      else if (event.key === "Backspace" || event.key === "Delete") {
        event.preventDefault(); setEditing(previous => previous ? { ...previous, value: previous.replace || event.key === "Delete" ? "" : Array.from(previous.value).slice(0, -1).join(""), replace: false } : previous);
      } else if (!event.ctrlKey && !event.metaKey && !event.altKey && Array.from(event.key).length === 1) {
        event.preventDefault(); const character = event.key;
        if (editing.numeric && !/[0-9eE+.-]/.test(character)) return;
        setEditing(previous => previous ? { ...previous, value: (previous.replace ? character : previous.value + character).slice(0, previous.max), replace: false } : previous);
      } else if (event.key === "Tab") event.preventDefault();
    };
    window.addEventListener("keydown", handler); return () => window.removeEventListener("keydown", handler);
  }, [opened, editing]);

  const edit = (source?: Mission, duplicate = false) => run(async () => {
    let next: Mission;
    if (source) next = clone(source);
    else next = fresh(await request<Capture>("capture", { mode: "feet" }));
    if (!live.current || !current.current.opened) return;
    if (duplicate) { next.id = ""; next.revision = 0; next.title = `${next.title.slice(0, 54)} copy`; }
    setDraft(next); setOriginal(source && !duplicate ? JSON.stringify(next) : ""); setWorld(false); setEditing(undefined);
    setStack([{ kind: "list" }, { kind: "mission" }]); mutation.current = undefined;
  });
  const publish = () => run(async () => {
    if (!draft) return;
    const issues = problems(draft); if (issues.length) throw new Error(issues[0]!);
    const signature = JSON.stringify({ operation: "save", mission: draft });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    let result: { mission: Mission };
    try { result = await request<{ mission: Mission }>("save", { mission: draft, baseRevision: draft.revision, mutation: mutation.current.key }); }
    catch (reason) { if (reason instanceof MissionRequestTimeout) setUnconfirmed("save"); throw reason; }
    if (!live.current) return;
    const saved = normalizeMission(result.mission); setDraft(saved); setOriginal(JSON.stringify(saved));
    mutation.current = undefined; setUnconfirmed(undefined);
    setFeedback(!saved.enabled ? "Mission saved (disabled: no board in the city)."
      : saved.fixer?.enabled ? "Gig published. No board: the fixers hand it out."
      : saved.worldBoss?.enabled ? "World boss published. No board: it appears at random in the city." : "Mission published. Its board is live in the city.");
    await refresh();
  });
  const remove = () => run(async () => {
    if (!draft?.id) return;
    const signature = JSON.stringify({ operation: "delete", id: draft.id, revision: draft.revision });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    try { await request("delete", { id: draft.id, baseRevision: draft.revision, mutation: mutation.current.key }); }
    catch (reason) { if (reason instanceof MissionRequestTimeout) setUnconfirmed("delete"); throw reason; }
    if (!live.current) return;
    clearDraft(); setFeedback("Mission deleted. Runs in progress finish normally."); await refresh();
  });
  const test = (difficulty: string) => run(async () => {
    if (!draft?.id) throw new Error("Publish the mission before testing it.");
    if (changed) throw new Error("Publish your changes first: the test runs the published version.");
    await request("test", { id: draft.id, difficulty });
    if (!live.current) return;
    close();
  });
  const back = () => {
    if (working.current || unconfirmed) return;
    if (editing) { setEditing(undefined); return; }
    if (top.kind === "mission") { if (changed) push({ kind: "discard" }); else clearDraft(); }
    else if (top.kind === "list") close();
    else pop();
  };

  // ---- row builders --------------------------------------------------------
  const readOnly = locked;
  const item = (id: string, text: string, action?: () => void, options: Partial<Entry> = {}): Entry => ({ id, text, run: action, ...options });
  const submenu = (id: string, text: string, page: Page, options: Partial<Entry> = {}): Entry => item(id, text, () => push(page), { type: "submenu", ...options });
  const textEntry = (id: string, text: string, value: string, commit: (value: string) => string | undefined, max = 60, description?: string): Entry => item(id, text, () => {
    if (readOnly) return;
    setError(""); setEditing({ id, value, replace: true, numeric: false, max, commit });
  }, { meta: value || "EMPTY", disabled: locked, description: description ?? "Enter edits this row. Type, then Enter applies or Escape cancels. Ctrl+A selects all." });
  const numberEntry = (id: string, text: string, value: number, change: (value: number) => void, min: number, max: number, unit = "m", step?: number, integer = false): Entry => item(id, text, () => {
    if (readOnly) return;
    setError(""); setEditing({ id, value: String(value), replace: true, numeric: true, max: 24, commit: input => {
      const n = input.trim() === "" ? NaN : Number(input);
      if (!Number.isFinite(n) || n < min || n > max || (integer && !Number.isInteger(n))) return `Enter ${integer ? "a whole number" : "a number"} from ${min} to ${max}.`;
      change(rounded(n)); return undefined;
    } });
  }, { type: "slider", value, min, max, step: step ?? STEPS[stepIndex], unit, disabled: locked,
    change: patch => { if (!readOnly && patch.value != null) { const v = Math.min(max, Math.max(min, integer ? Math.round(patch.value) : rounded(patch.value))); change(v); } },
    description: `Left/right adjusts by ${step ?? STEPS[stepIndex]} ${unit}. Enter types an exact value.` });
  const toggle = (id: string, text: string, checked: boolean, change: (checked: boolean) => void, description: string): Entry => item(id, text, () => { if (!readOnly) change(!checked); },
    { type: "checkbox", checked, disabled: locked, change: patch => { if (!readOnly) change(patch.checked === true); }, description });
  const choice = <T extends string,>(id: string, text: string, options: readonly T[], labels: (v: T) => string, value: T, change: (v: T) => void, description: string): Entry =>
    item(id, text, undefined, { type: "list", options: options.map(labels), index: Math.max(0, options.indexOf(value)), disabled: locked,
      change: patch => { const v = options[patch.index ?? 0]; if (!readOnly && v) change(v); }, description });
  const placeRows = (what: string, target: Tool | Ref): Entry[] => [
    item("placeAim", `Place ${what} with the mouse`, () => {
      if (typeof target === "string") enterBuild(target);
      else { setBuild(previous => ({ ...previous, tool: "move", carrying: { ...target, label: target.label ?? what } })); setBuildNote({ message: `Click where ${what} goes.` }); setHovered(null); setWorld(true); }
    }, { icon: "crosshair", disabled: readOnly, description: "Build mode: aim with the crosshair and click. F9 comes back to the menu." }),
    item("placeFeet", `Place ${what} at my feet`, () => { void place("feet"); }, { icon: "map-pin", disabled: readOnly, description: "Exactly where you stand, facing your direction (F11)." }),
  ];
  const coordinateRows = (prefix: string, p: Point, change: (p: Point) => void): Entry[] =>
    (["x", "y", "z"] as const).map(axis => numberEntry(`${prefix}:${axis}`, axis.toUpperCase(), p[axis], v => change({ ...p, [axis]: v }), -100000, 100000));

  // Every mission on the map: where its fight is (the perimeter's centre, a polygon's centroid, else the board).
  const pinOf = (m: Mission) => {
    const z = m.perimeter;
    const c = z && z.shape === "poly" && z.points.length
      ? z.points.reduce((s, q) => ({ x: s.x + q.x / z.points.length, y: s.y + q.y / z.points.length, z: s.z + q.z / z.points.length }), { x: 0, y: 0, z: 0 })
      : z && z.center ? z.center : m.point;
    const kind = !m.enabled ? "off" : m.worldBoss.enabled ? "boss" : m.fixer.enabled ? "gig" : "board";
    return { id: m.id, title: m.title, location: m.location, kind, x: c.x, y: c.y, z: c.z };
  };
  const showPins = async (on: boolean, track?: string) => {
    const r = await request<{ shown: number; tracked?: boolean }>("pins", { on, pins: on ? missions.filter(m => m.id).map(pinOf) : [], track });
    setMapPins(on);
    return r;
  };
  let entries: Entry[] = [], subtitle = "MISSIONS";
  const issues = draft ? problems(draft) : [];
  if (top.kind === "list") {
    entries = [item("create", "Create a mission", () => { void edit(); }, { icon: "plus", disabled: busy || !ready, description: ready ? "Start a private draft where you stand: board, start and perimeter around you. Nothing changes until publication." : "Mission storage is unavailable." }),
      { separator: true },
      ...missions.map(m => item(`mission:${m.id}`, m.title, () => { void edit(m); }, { icon: m.type === "waves" ? "shield" : "swords", meta: !m.enabled ? "DISABLED" : m.fixer.enabled ? `GIG · ${TYPE_LABEL[m.type].toUpperCase()}` : m.worldBoss.enabled ? `BOSS · ${TYPE_LABEL[m.type].toUpperCase()}` : TYPE_LABEL[m.type].toUpperCase(), disabled: busy,
        description: `${TYPE_LABEL[m.type]} · ${m.spawns.length} spawn point(s) · ${m.checkpoints.length} checkpoint(s)${m.type === "waves" ? ` · ${m.waves.length} wave(s)` : ""} · revision ${m.revision}` })),
      ...(loading ? [item("loading", `Loading missions ${loading.received}/${loading.total}`, undefined, { disabled: true, icon: "activity" })] : []),
      ...(!missions.length && !loading ? [item("empty", ready ? "No authored mission yet" : busy ? "Waiting..." : "Storage unavailable", undefined, { disabled: true })] : []), { separator: true },
      item("mapPins", "Show every mission on the map", () => { void run(async () => { await showPins(!mapPins); }); },
        { type: "checkbox", checked: mapPins, icon: "map-pin", disabled: busy || !missions.length,
          change: patch => { void run(async () => { await showPins(patch.checked === true); }); },
          description: "Pins on the map and the 3D map: red = world boss, gold = fixer gig, cyan = board mission, grey = disabled. They stay after the editor closes, until you turn them off here." }),
      item("refresh", "Refresh", () => { void run(refresh); }, { icon: "activity", disabled: busy }), item("close", "Close editor", close, { icon: "x", disabled: busy })];
  } else if (draft) {
    subtitle = draft.title;
    const m = draft, z = m.perimeter;
    const setSpawn = (id: string, patch: Partial<Spawn>) => update(d => ({ spawns: d.spawns.map(s => s.id === id ? { ...s, ...patch } : s) }));
    const setCheckpoint = (id: string, patch: Partial<Checkpoint>) => update(d => ({ checkpoints: d.checkpoints.map(c => c.id === id ? { ...c, ...patch } : c) }));
    const setWave = (index: number, patch: Partial<Wave>) => update(d => ({ waves: d.waves.map((w, i) => i === index ? { ...w, ...patch } : w) }));
    switch (top.kind) {
      case "mission":
        entries = [
          item("build", "Build mode: place with the mouse", () => enterBuild(), { icon: "crosshair", description: "Aim and click to place spawns, checkpoints, starts, the perimeter and patrol routes. Up/Down change the tool, right-click selects, Delete removes. F9 comes back here." }),
          submenu("brush", "Spawn brush", { kind: "brush" }, { meta: `${brush.count}× ${enemyLabel(brush.enemy).toUpperCase()}`, description: "What every new spawn point starts with: enemy, count, behaviour, trigger, spread." }),
          { separator: true },
          submenu("general", "General", { kind: "general" }, { meta: TYPE_LABEL[m.type].toUpperCase(), description: "Title, type, description, board position, activation." }),
          submenu("perimeter", "Perimeter", { kind: "perimeter" }, { meta: SHAPE_LABEL[z.shape].toUpperCase(), description: "The zone the squad must stay in. Out of it: warning, then death after the delay set in Rules." }),
          submenu("starts", "Squad starts", { kind: "starts" }, { meta: `${m.starts.length} / ${LIMITS.starts}`, description: "Where the operators appear in the mission instance (inside the perimeter)." }),
          submenu("spawns", "Enemy spawn points", { kind: "spawns" }, { meta: `${m.spawns.length} / ${LIMITS.spawns}`, description: "Who spawns, how many, where, and when (start, checkpoint or wave)." }),
          submenu("checkpoints", "Checkpoints", { kind: "checkpoints" }, { meta: `${m.checkpoints.length} / ${LIMITS.checkpoints}`, description: "Points the squad must reach. Entering one wakes its spawn points." }),
          ...(m.type === "waves" ? [submenu("waves", "Waves", { kind: "waves" }, { meta: `${m.waves.length} / ${LIMITS.waves}`, description: "The waves in order. Each starts its delay after the previous one is cleared." })] : []),
          submenu("rules", "Rules", { kind: "rules" }, { meta: `${m.outOfBounds.graceSeconds}s · ${m.respawn.lives} lives`, description: "Out-of-zone delay, team respawns." }),
          submenu("worldboss", "World boss", { kind: "worldboss" }, { meta: m.worldBoss.enabled ? "BOSS" : "OFF", description: m.worldBoss.enabled
            ? "A world boss: no board, it appears at random in the city and anybody fights it; the reward is shared by contribution." : "Turn this mission into an open-world boss event." }),
          submenu("fixer", "Fixer gig", { kind: "fixer" }, { meta: m.fixer.enabled ? "GIG" : "BOARD", description: m.fixer.enabled
            ? "A fixer gig: no board in the city. The fixers text it to players at random; they share it with their crew." : "A board mission (players tag in). Turn it into a fixer gig here." }),
          submenu("difficulties", "Difficulties and rewards", { kind: "difficulties" }, { description: "Payout, time limit, squad size and enemy strength per difficulty." }),
          { separator: true },
          ...(issues.length ? [submenu("issues", `Fix ${issues.length} issue${issues.length > 1 ? "s" : ""}`, { kind: "issues" }, { icon: "triangle-alert", danger: true, description: issues[0] })] : []),
          item("save", unconfirmed === "save" ? "Check publication" : "Publish mission", publish, { icon: "check", disabled: busy || unconfirmed === "delete" || issues.length > 0 || !ready,
            description: issues[0] ?? "Validate and save. An enabled mission gets its board in the city at once." }),
          submenu("test", "Test now", { kind: "test" }, { icon: "zap", disabled: busy || !m.id || changed, description: !m.id ? "Publish once to test." : changed ? "Publish your changes first: the test runs the published version." : "Launch it alone now (no payout, no unlock). /mission leave ends it." }),
          item("gps", "Show on the map and set the GPS", () => { void run(async () => { const r = await showPins(true, m.id); if (!r.tracked) throw new Error("Publish the mission first: only saved missions are pinned."); }); },
            { icon: "map-pin", disabled: busy || !m.id, description: !m.id ? "Publish once to pin it." : "Pins every mission on the map (see the list) and routes your GPS to this one." }),
          item("duplicate", "Duplicate mission", () => { void edit(m, true); }, { disabled: readOnly, description: "An independent draft from these settings." }),
          submenu("delete", "Delete mission", { kind: "delete" }, { danger: true, disabled: readOnly || !m.id, description: "Remove its board. Runs in progress finish normally." }),
        ];
        break;
      case "general":
        entries = [
          textEntry("title", "Title", m.title, v => { const t = v.trim(); if (!t || t.length > 60) return "Choose a title of 1–60 characters."; update({ title: t }); return undefined; }),
          choice("type", "Mission type", TYPES, t => TYPE_LABEL[t], m.type, type => update(d => ({ type,
            spawns: type === "eliminate" ? d.spawns.map(s => s.trigger === "wave" ? { ...s, trigger: "start" as const } : s) : d.spawns,
            waves: type === "eliminate" ? [] : d.waves })),
            "Elimination: kill every enemy and reach the required checkpoints. Survival: hold the zone through every wave."),
          textEntry("location", "Location", m.location, v => { if (v.trim().length > 40) return "40 characters at most."; update({ location: v.trim() }); return undefined; }, 40, "Shown on the board (e.g. Kabuki, Watson)."),
          textEntry("description", "Description", m.description, v => { if (v.trim().length > 240) return "240 characters at most."; update({ description: v.trim() }); return undefined; }, 240, "The briefing on the board. Empty: a default line for the type."),
          toggle("enabled", "Mission enabled", m.enabled, enabled => update({ enabled }), "Disabled: saved but no board in the city."),
          { separator: true },
          ...placeRows("the board", { type: "board", label: "the board" }),
          ...coordinateRows("board", m.point, point => update({ point })),
        ];
        break;
      case "perimeter":
        entries = [
          choice("shape", "Shape", SHAPES, s => SHAPE_LABEL[s], z.shape, shape => update(d => ({ perimeter: { ...d.perimeter, shape } })), "Cylinder, oriented box or polygon (like the safe zones)."),
          item("step", "Adjustment step", undefined, { type: "list", options: STEPS.map(s => `${s} m / °`), index: stepIndex, change: patch => setStepIndex(patch.index ?? 1), description: "Left/right increment of the number rows." }),
          toggle("fullHeight", "Full height", z.fullHeight, fullHeight => update(d => ({ perimeter: { ...d.perimeter, fullHeight } })), "Ignore floor and ceiling (outdoor zones). Off: leaving above or below also counts as out."),
          ...(!z.fullHeight ? [numberEntry("floor", "Floor Z", z.minZ, minZ => update(d => ({ perimeter: { ...d.perimeter, minZ } })), -100000, 100000),
            numberEntry("ceiling", "Ceiling Z", z.maxZ, maxZ => update(d => ({ perimeter: { ...d.perimeter, maxZ } })), -100000, 100000)] : []),
          ...(z.shape === "circle" ? [numberEntry("radius", "Radius", z.radius, radius => update(d => ({ perimeter: { ...d.perimeter, radius } })), 0.5, 250)] : []),
          ...(z.shape === "box" ? [numberEntry("length", "Length", z.length, length => update(d => ({ perimeter: { ...d.perimeter, length } })), 0.5, 500),
            numberEntry("width", "Width", z.width, width => update(d => ({ perimeter: { ...d.perimeter, width } })), 0.5, 500),
            numberEntry("heading", "Heading", z.heading, heading => update(d => ({ perimeter: { ...d.perimeter, heading } })), -36000, 36000, "°")] : []),
          ...(z.shape === "poly" ? [submenu("vertices", "Polygon vertices", { kind: "vertices" }, { meta: `${z.points.length} / ${LIMITS.vertices}`, description: "Walk the outline in order: F10 adds a vertex at your feet, F11 where you aim." })]
            : [...placeRows("the centre", { type: "centre", label: "the perimeter centre" }), ...coordinateRows("centre", z.center, center => update(d => ({ perimeter: { ...d.perimeter, center } })))]),
        ];
        break;
      case "vertices":
        entries = [...placeRows("a new vertex", "perimeter"),
          item("undo", "Undo last vertex", () => update(d => ({ perimeter: { ...d.perimeter, points: d.perimeter.points.slice(0, -1) } })), { disabled: readOnly || !z.points.length }),
          { separator: true },
          ...z.points.map((p, i) => submenu(`vertex:${i}`, `Vertex ${i + 1}`, { kind: "vertex", index: i }, { meta: `${p.x.toFixed(1)}, ${p.y.toFixed(1)}` }))];
        break;
      case "vertex": {
        const i = top.index ?? 0, p = z.points[i];
        if (p) entries = [...placeRows(`vertex ${i + 1}`, { type: "vertex", index: i + 1 }),
          ...coordinateRows("vertex", p, q => update(d => ({ perimeter: { ...d.perimeter, points: d.perimeter.points.map((v, j) => j === i ? q : v) } }))),
          item("removeVertex", "Remove this vertex", () => { update(d => ({ perimeter: { ...d.perimeter, points: d.perimeter.points.filter((_, j) => j !== i) } })); pop(); }, { danger: true, disabled: readOnly })];
        break;
      }
      case "starts":
        entries = [...placeRows("a new start", "start"), { separator: true },
          ...m.starts.map((s, i) => submenu(`start:${i}`, `Start ${i + 1}`, { kind: "start", index: i }, { meta: `${s.heading.toFixed(0)}°`, description: coords(s) }))];
        break;
      case "start": {
        const i = top.index ?? 0, s = m.starts[i];
        if (s) entries = [...placeRows(`start ${i + 1}`, { type: "start", index: i + 1 }),
          numberEntry("heading", "Facing", s.heading, heading => update(d => ({ starts: d.starts.map((v, j) => j === i ? { ...v, heading } : v) })), 0, 359.99, "°", 15),
          ...coordinateRows("start", s, q => update(d => ({ starts: d.starts.map((v, j) => j === i ? { ...v, ...q } : v) }))),
          item("removeStart", "Remove this start", () => { update(d => ({ starts: d.starts.filter((_, j) => j !== i) })); pop(); }, { danger: true, disabled: readOnly || m.starts.length <= 1, description: "A mission keeps at least one start." })];
        break;
      }
      case "spawns":
        entries = [...placeRows("a new spawn point", "spawn"), item("brushHere", "Spawn brush", () => push({ kind: "brush" }), { type: "submenu", meta: `${brush.count}× ${enemyLabel(brush.enemy).toUpperCase()}`, description: "Settings of new spawn points." }), { separator: true },
          ...m.spawns.map(s => submenu(`spawn:${s.id}`, s.label, { kind: "spawn", key: s.id }, { meta: `${s.count}× ${s.trigger.toUpperCase()}`, description: `${enemyLabel(s.enemy)} · ${TRIGGER_LABEL[s.trigger]} · ${coords(s.position)}` }))];
        break;
      case "spawn": {
        const s = m.spawns.find(v => v.id === top.key);
        if (s) {
          const triggers = m.type === "waves" ? TRIGGERS : TRIGGERS.filter(t => t !== "wave");
          const linkedBy = [...m.checkpoints.filter(c => c.spawns.includes(s.id)).map(c => c.label), ...m.waves.flatMap((w, i) => w.spawns.includes(s.id) ? [`Wave ${i + 1}`] : [])];
          entries = [
            textEntry("label", "Name", s.label, v => { const t = v.trim(); if (t.length > 40) return "40 characters at most."; setSpawn(s.id, { label: t || s.label }); return undefined; }, 40),
            choice("enemy", "Enemy", ENEMIES.map(e => e.id), id => enemyLabel(id), s.enemy as (typeof ENEMIES)[number]["id"], enemy => setSpawn(s.id, { enemy }), "Who spawns here."),
            numberEntry("count", "Enemies", s.count, count => setSpawn(s.id, { count }), 1, LIMITS.count, "", 1, true),
            choice("trigger", "Spawns", triggers, t => TRIGGER_LABEL[t], s.trigger, trigger => update(d => ({ spawns: d.spawns.map(v => v.id === s.id ? { ...v, trigger } : v),
              checkpoints: trigger === "checkpoint" ? d.checkpoints : d.checkpoints.map(c => ({ ...c, spawns: c.spawns.filter(id => id !== s.id) })),
              waves: trigger === "wave" ? d.waves : d.waves.map(w => ({ ...w, spawns: w.spawns.filter(id => id !== s.id) })) })),
            s.trigger === "start" ? "Spawns when the mission starts." : s.trigger === "checkpoint" ? "Link it from a checkpoint's page." : "Add it to waves from the Waves page."),
            item("links", "Linked from", undefined, { disabled: true, meta: linkedBy.length ? String(linkedBy.length) : "NONE", description: linkedBy.join(", ") || (s.trigger === "start" ? "Spawns at the start." : "Not linked yet: it would never spawn.") }),
            choice("behavior", "Behaviour", BEHAVIORS, b => BEHAVIOR_LABEL[b], s.behavior, (behavior: Behavior) => setSpawn(s.id, { behavior }), BEHAVIOR_HELP[s.behavior]),
            ...(s.behavior === "defend" || s.behavior === "wander" ? [numberEntry("radius", "Area radius", s.radius, radius => setSpawn(s.id, { radius }), 1, 60, "m", 1)] : []),
            ...(s.behavior !== "assault" ? [numberEntry("alert", "Alert range", s.alertRange, alertRange => setSpawn(s.id, { alertRange }), 3, 150, "m", 5)] : []),
            ...(s.behavior === "patrol" || s.route.length ? [submenu("route", "Patrol route", { kind: "route", key: s.id }, { meta: `${s.route.length} / ${LIMITS.route}`, description: "The points the squad walks through, in a loop from the spawn point." })] : []),
            numberEntry("spread", "Group spread", s.spread, spread => setSpawn(s.id, { spread }), 0, 10, "m", 0.5),
            numberEntry("heading", "Facing", s.heading, heading => setSpawn(s.id, { heading }), 0, 359.99, "°", 15),
            ...placeRows("this spawn point", { type: "spawn", id: s.id, label: s.label }),
            item("asBrush", "Use these settings as the brush", () => { setBrush(b => ({ ...b, enemy: s.enemy, count: s.count, trigger: s.trigger, behavior: s.behavior, radius: s.radius, alertRange: s.alertRange, spread: s.spread })); setFeedback("Brush updated: new spawn points copy this one."); }, { icon: "check", disabled: readOnly }),
            ...coordinateRows("spawn", s.position, position => setSpawn(s.id, { position })),
            item("removeSpawn", "Remove this spawn point", () => { update(d => ({ spawns: d.spawns.filter(v => v.id !== s.id),
              checkpoints: d.checkpoints.map(c => ({ ...c, spawns: c.spawns.filter(id => id !== s.id) })), waves: d.waves.map(w => ({ ...w, spawns: w.spawns.filter(id => id !== s.id) })) })); pop(); },
            { danger: true, disabled: readOnly, description: "Also removed from its checkpoints and waves." }),
          ];
        }
        break;
      }
      case "route": {
        const s = m.spawns.find(v => v.id === top.key);
        if (s) entries = [
          item("addRoute", "Add patrol points with the mouse", () => enterBuild("patrol", s.id), { icon: "crosshair", disabled: readOnly || s.route.length >= LIMITS.route, description: "Build mode with the Patrol route tool on this spawn point: each click adds the next point." }),
          item("clearRoute", "Clear the route", () => setSpawn(s.id, { route: [] }), { danger: true, disabled: readOnly || !s.route.length }),
          { separator: true },
          ...s.route.map((q, i) => item(`route:${i}`, `Patrol point ${i + 1}`, () => setSpawn(s.id, { route: s.route.filter((_, j) => j !== i) }), { meta: "ENTER REMOVES", description: coords(q) })),
        ];
        break;
      }
      case "brush":
        entries = [
          choice("enemy", "Enemy", ENEMIES.map(e => e.id), id => enemyLabel(id), brush.enemy as (typeof ENEMIES)[number]["id"], enemy => setBrush(b => ({ ...b, enemy })), "Who new spawn points put out."),
          numberEntry("count", "Enemies", brush.count, count => setBrush(b => ({ ...b, count })), 1, LIMITS.count, "", 1, true),
          choice("trigger", "Spawns", m.type === "waves" ? TRIGGERS : TRIGGERS.filter(t => t !== "wave"), t => TRIGGER_LABEL[t], brush.trigger, trigger => setBrush(b => ({ ...b, trigger })), "When new spawn points spawn."),
          choice("behavior", "Behaviour", BEHAVIORS.filter(b => b !== "patrol"), b => BEHAVIOR_LABEL[b], brush.behavior, (behavior: Behavior) => setBrush(b => ({ ...b, behavior })), `${BEHAVIOR_HELP[brush.behavior]} (Patrol: add patrol points to a spawn with the Patrol route tool.)`),
          numberEntry("radius", "Area radius", brush.radius, radius => setBrush(b => ({ ...b, radius })), 1, 60, "m", 1),
          numberEntry("alert", "Alert range", brush.alertRange, alertRange => setBrush(b => ({ ...b, alertRange })), 3, 150, "m", 5),
          numberEntry("spread", "Group spread", brush.spread, spread => setBrush(b => ({ ...b, spread })), 0, 10, "m", 0.5),
          numberEntry("cpRadius", "New checkpoint radius", brush.checkpointRadius, checkpointRadius => setBrush(b => ({ ...b, checkpointRadius })), 1, 30, "m", 0.5),
          toggle("autoFacing", "Facing: toward me", build.heading == null, on => setBuild(b => ({ ...b, heading: on ? null : 0 })), "On: what you place faces where you stand. Off: Left/Right in build mode set the facing."),
          { separator: true },
          item("buildNow", "Build mode", () => enterBuild("spawn"), { icon: "crosshair" }),
        ];
        break;
      case "checkpoints":
        entries = [...placeRows("a new checkpoint", "checkpoint"), { separator: true },
          ...m.checkpoints.map(c => submenu(`checkpoint:${c.id}`, c.label, { kind: "checkpoint", key: c.id }, { meta: `${c.spawns.length} SPAWN${c.spawns.length === 1 ? "" : "S"}${c.required ? "" : " · OPT"}`, description: `${c.radius} m · ${coords(c.position)}` }))];
        break;
      case "checkpoint": {
        const c = m.checkpoints.find(v => v.id === top.key);
        if (c) {
          const candidates = m.spawns.filter(s => s.trigger === "checkpoint");
          entries = [
            textEntry("label", "Name", c.label, v => { const t = v.trim(); if (t.length > 40) return "40 characters at most."; setCheckpoint(c.id, { label: t || c.label }); return undefined; }, 40),
            numberEntry("radius", "Radius", c.radius, radius => setCheckpoint(c.id, { radius }), 1, 30, "m", 0.5),
            toggle("required", "Required", c.required, required => setCheckpoint(c.id, { required }), "Elimination: the mission is done only once every required checkpoint was reached."),
            ...placeRows("this checkpoint", { type: "checkpoint", id: c.id, label: c.label }),
            ...coordinateRows("checkpoint", c.position, position => setCheckpoint(c.id, { position })),
            { separator: true },
            item("wakes", "Wakes these spawn points", undefined, { disabled: true, meta: `${c.spawns.length}`, description: candidates.length ? "Toggle below. Only spawn points set to 'Woken by a checkpoint' are listed." : "No spawn point is set to 'Woken by a checkpoint' yet." }),
            ...candidates.map(s => toggle(`wake:${s.id}`, s.label, c.spawns.includes(s.id), on => setCheckpoint(c.id, { spawns: on ? [...c.spawns, s.id] : c.spawns.filter(id => id !== s.id) }),
              `${s.count}× ${enemyLabel(s.enemy)}`)),
            { separator: true },
            item("removeCheckpoint", "Remove this checkpoint", () => { update(d => ({ checkpoints: d.checkpoints.filter(v => v.id !== c.id) })); pop(); }, { danger: true, disabled: readOnly }),
          ];
        }
        break;
      }
      case "waves":
        entries = [item("addWave", "Add a wave", () => update(d => ({ waves: [...d.waves, { delaySeconds: d.waves.length ? 15 : 10, spawns: [] }] })), { icon: "plus", disabled: readOnly || m.waves.length >= LIMITS.waves }),
          { separator: true },
          ...m.waves.map((w, i) => submenu(`wave:${i}`, `Wave ${i + 1}`, { kind: "wave", index: i }, { meta: `${w.spawns.length} SPAWN${w.spawns.length === 1 ? "" : "S"} · ${w.delaySeconds}s`,
            description: w.spawns.map(id => m.spawns.find(s => s.id === id)?.label ?? id).join(", ") || "No spawn point yet." }))];
        break;
      case "wave": {
        const i = top.index ?? 0, w = m.waves[i];
        if (w) {
          const candidates = m.spawns.filter(s => s.trigger === "wave");
          const total = w.spawns.reduce((n, id) => n + (m.spawns.find(s => s.id === id)?.count ?? 0), 0);
          entries = [
            numberEntry("delay", "Delay before it starts", w.delaySeconds, delaySeconds => setWave(i, { delaySeconds }), 0, 300, "s", 5, true),
            item("total", "Enemies (Standard)", undefined, { disabled: true, meta: String(total) }),
            { separator: true },
            ...candidates.map(s => toggle(`wave:${s.id}`, s.label, w.spawns.includes(s.id), on => setWave(i, { spawns: on ? [...w.spawns, s.id] : w.spawns.filter(id => id !== s.id) }),
              `${s.count}× ${enemyLabel(s.enemy)}`)),
            ...(!candidates.length ? [item("none", "No wave spawn point yet", undefined, { disabled: true, description: "Create spawn points set to 'In a wave' first." })] : []),
            { separator: true },
            item("up", "Move earlier", () => { if (i > 0) { update(d => { const waves = [...d.waves]; [waves[i - 1], waves[i]] = [waves[i]!, waves[i - 1]!]; return { waves }; }); pop(); } }, { disabled: readOnly || i === 0 }),
            item("removeWave", "Remove this wave", () => { update(d => ({ waves: d.waves.filter((_, j) => j !== i) })); pop(); }, { danger: true, disabled: readOnly }),
          ];
        }
        break;
      }
      case "fixer": {
        const contactIds = ["any", ...fixers.map(f => f.id)];
        const contactName = (id: string) => id === "any" ? "Any fixer (random)" : fixers.find(f => f.id === id)?.name ?? id;
        entries = [
          toggle("fixerEnabled", "Fixer gig", m.fixer.enabled, enabled => update(d => ({ fixer: { ...d.fixer, enabled }, worldBoss: enabled ? { ...d.worldBoss, enabled: false } : d.worldBoss })),
            "On: no board in the city, nobody tags in. The fixers text this job to players at random (Neural-Link), with the meet point = the board position. Off: a board mission."),
          choice("fixerContact", "Fixer", contactIds, contactName, contactIds.includes(m.fixer.contact) ? m.fixer.contact : "any",
            contact => update(d => ({ fixer: { ...d.fixer, contact } })), "Who sends the job. Any: a random fixer each time."),
          textEntry("fixerBrief", "Fixer brief", m.fixer.brief, v => { if (v.trim().length > 240) return "240 characters at most."; update(d => ({ fixer: { ...d.fixer, brief: v.trim() } })); return undefined; }, 240,
            "The objective the fixer writes once the job is taken. Empty: the mission description."),
          item("fixerHelp", "How a gig plays", undefined, { disabled: true, description: "A fixer texts one player: Take the job / Pass. Taken: the brief with the meet point (Pin on map) and the objective; the player shares the job with contacts or numbers, who join the crew. Everyone who took it meets at the point: countdown, then the mission runs at the offered difficulty and pays each operator." }),
        ];
        break;
      }
      case "worldboss": {
        const spawnIds = m.spawns.filter(s => s.trigger === "start").map(s => s.id);
        const spawnLabel = (id: string) => m.spawns.find(s => s.id === id)?.label ?? "Choose...";
        const w = m.worldBoss;
        const set = (patch: Partial<typeof w>) => update(d => ({ worldBoss: { ...d.worldBoss, ...patch } }));
        entries = [
          toggle("wbEnabled", "World boss", w.enabled, enabled => update(d => ({ worldBoss: { ...d.worldBoss, enabled, boss: d.worldBoss.boss || spawnIds[0] || "" },
            fixer: enabled ? { ...d.fixer, enabled: false } : d.fixer })),
            "On: no board, nobody tags in. It appears at random in the city (bucket 0) and anybody in the zone fights it. The perimeter is the event zone (no out-of-zone death)."),
          ...(spawnIds.length ? [choice("wbBoss", "Boss", spawnIds, spawnLabel, spawnIds.includes(w.boss) ? w.boss : spawnIds[0]!, boss => set({ boss }),
            "The start spawn point whose enemies are the boss (its name is the boss's). Give it a Cyberpsycho enemy for a classic sighting. The other start spawns guard it; non-start spawns come as reinforcements at 66 % and 33 %.")]
            : [item("wbNoSpawn", "Boss", undefined, { disabled: true, meta: "NO START SPAWN", description: "Place a spawn point that spawns at the start: it will be the boss." })]),
          numberEntry("wbHealth", "Boss health", w.health, health => set({ health }), 1, 200, "x", 1, true),
          numberEntry("wbReward", "Reward pool", w.reward, reward => set({ reward }), 0, 1000000, "€$", 1000, true),
          numberEntry("wbMinShare", "Minimum share", w.minShare, minShare => set({ minShare }), 0, 50, "%", 1, true),
          numberEntry("wbMinutes", "Time limit", w.minutes, minutes => set({ minutes }), 5, 120, "min", 1, true),
          item("wbHelp", "How a world boss plays", undefined, { disabled: true, description: "Announced to the whole city with a blip. Entering the zone shows the boss bar, the objective and your share. Every point of damage on the boss and its guards counts, plus each kill; at the end the pool is shared by score among those at or above the minimum share. A latecomer's last shot or an idle player gets nothing. Time out: the boss leaves, nobody is paid." }),
        ];
        break;
      }
      case "rules":
        entries = [
          numberEntry("grace", "Out-of-zone delay", m.outOfBounds.graceSeconds, graceSeconds => update({ outOfBounds: { graceSeconds } }), 3, 60, "s", 1, true),
          numberEntry("lives", "Team respawns", m.respawn.lives, lives => update(d => ({ respawn: { ...d.respawn, lives } })), 0, 50, "", 1, true),
          numberEntry("respawn", "Respawn delay", m.respawn.seconds, seconds => update(d => ({ respawn: { ...d.respawn, seconds } })), 3, 60, "s", 1, true),
          item("rulesHelp", "How it plays", undefined, { disabled: true, description: "Out of the perimeter an operator sees a countdown, then dies. A death spends one team respawn (back at a start); with none left the operator is out. Nobody standing: crew wiped, mission failed." }),
        ];
        break;
      case "difficulties":
        entries = m.difficulties.map(d => submenu(`difficulty:${d.id}`, d.label, { kind: "difficulty", key: d.id }, { meta: `€$${d.payout.toLocaleString("en-US")}`, description: `${d.minutes} min · squad ${d.min}–${d.max} · enemies ×${d.enemyCount} count, ×${d.enemyHealth} health, ×${d.enemyDamage} damage` }));
        break;
      case "difficulty": {
        const d = m.difficulties.find(v => v.id === top.key);
        const set = (patch: Partial<typeof DIFFICULTIES[number]>) => update(x => ({ difficulties: x.difficulties.map(v => v.id === top.key ? { ...v, ...patch } : v) }));
        if (d) entries = [
          numberEntry("payout", "Payout", d.payout, payout => set({ payout }), 0, 1000000, "€$", 500, true),
          numberEntry("minutes", "Time limit", d.minutes, minutes => set({ minutes }), 3, 120, "min", 1, true),
          numberEntry("min", "Squad minimum", d.min, min => set({ min }), 1, 8, "", 1, true),
          numberEntry("max", "Squad maximum", d.max, max => set({ max }), 1, 8, "", 1, true),
          numberEntry("enemyCount", "Enemy count ×", d.enemyCount, enemyCount => set({ enemyCount }), 0.25, 5, "×", 0.25),
          numberEntry("enemyHealth", "Enemy health ×", d.enemyHealth, enemyHealth => set({ enemyHealth }), 0.25, 5, "×", 0.25),
          numberEntry("enemyDamage", "Enemy damage ×", d.enemyDamage, enemyDamage => set({ enemyDamage }), 0.25, 5, "×", 0.25),
          textEntry("blurb", "Board line", d.blurb, v => { if (v.trim().length > 120) return "120 characters at most."; set({ blurb: v.trim() || d.blurb }); return undefined; }, 120),
        ];
        break;
      }
      case "test":
        entries = [...m.difficulties.map(d => item(`test:${d.id}`, `Launch ${d.label}`, () => { void test(d.id); }, { icon: "zap", disabled: busy,
          description: `You alone, now, in a private instance. ${d.minutes} min. No payout, no unlock. /mission leave abandons it.` }))];
        break;
      case "issues":
        entries = issues.map((text, i) => item(`issue:${i}`, text, undefined, { disabled: true, description: text }));
        break;
      case "delete":
        entries = [item("cancel", "Keep this mission", pop, { disabled: busy || unconfirmed === "delete" }),
          item("confirmDelete", unconfirmed === "delete" ? "Check deletion" : "Confirm deletion", remove, { danger: true, disabled: busy, description: "Its board disappears from the city. Runs in progress finish normally." })];
        break;
      case "discard":
        entries = [item("cancel", "Keep editing", pop), item("discard", "Discard draft", clearDraft, { danger: true, description: "Unpublished changes are lost. The published mission stays as it was." })];
        break;
      default: break;
    }
    if (top.kind !== "discard" && top.kind !== "delete") entries.push({ separator: true }, item("back", "Back", back, { icon: "chevron-left", disabled: busy || !!unconfirmed,
      description: top.kind === "mission" && changed ? "Unpublished changes will ask for confirmation." : "Return to the previous menu." }));
  }
  if (busy) entries.push(item("working", "Waiting…", undefined, { disabled: true }));
  const selected = entries.findIndex(entry => entry.id === top.selected && isPickable(entry));
  const index = selected >= 0 ? selected : Math.max(0, entries.findIndex(isPickable));
  const visible = entries.map(entry => editing && editing.id === entry.id ? { ...entry, type: "item" as const, meta: undefined,
    description: `${editing.replace ? "[" : ""}${editing.value}${editing.replace ? "]" : "▏"}  ·  ENTER APPLY / ESC CANCEL` } : entry);
  const placing = PLACEABLE.includes(top.kind);
  const pathNames: Partial<Record<Kind, string>> = { mission: "MISSION", general: "GENERAL", perimeter: "PERIMETER", vertices: "VERTICES", vertex: "VERTEX",
    starts: "STARTS", start: "START", spawns: "SPAWNS", spawn: "SPAWN", checkpoints: "CHECKPOINTS", checkpoint: "CHECKPOINT", waves: "WAVES", wave: "WAVE",
    rules: "RULES", difficulties: "DIFFICULTIES", difficulty: "DIFFICULTY", test: "TEST", issues: "ISSUES", discard: "DISCARD", delete: "DELETE",
    brush: "BRUSH", route: "PATROL" };
  return opened ? <>
    {!world && <section className="rp-support safezone-menu mission-editor" aria-label="Mission editor"><div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title="LIGHT/RP" subtitle={subtitle} tag={draft ? changed ? "DRAFT" : draft.id ? "SAVED" : "NEW" : "STAFF"} items={visible} index={index} width={380} visibleRows={10}
        path={["ADMIN", "MISSIONS", ...stack.slice(1).map(page => pathNames[page.kind] ?? page.kind.toUpperCase())]}
        active={!editing && !busy} onIndexChange={next => setStack(previous => previous.map((page, i) => i === previous.length - 1 ? { ...page, selected: entries[next]?.id } : page))}
        onSelect={(_, next) => entries[next]?.run?.()} onChange={(_, next, patch) => entries[next]?.change?.(patch)} onBack={back}
        footer={editing ? <><span>TYPE VALUE</span><span>ENTER APPLY</span><span>ESC CANCEL</span><span>CTRL+A SELECT ALL</span></>
          : <><span>↑↓ MOVE</span><span>←→ CHANGE</span><span>ENTER SELECT</span><span>BKSP / ESC BACK</span>{draft && <><span>F9 BUILD MODE</span>{placing && <span>F11 AT MY FEET</span>}</>}</>} />
      {error && <p className="rp-support__error" role="alert">{error}</p>}{feedback && !error && <p className="rp-support__success" role="status">{feedback}</p>}
    </div></section>}
    {world && draft && <BuildHud mission={draft} build={build} brush={brush} hovered={hovered} message={buildNote.message} error={buildNote.error || error} />}
  </> : null;
}
