import { useCallback, useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { Icon, RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { EditorTimeout, mutationKey, onEditor, request, tell } from "./api";
import {
  DIFFICULTIES, DIFFICULTY_LABEL, LIMITS, clone, distance, formatLength, formatTime, fresh, normalizeCourse, problems, round, roundPoint, routeLength, wire,
  type Course, type Difficulty, type Point,
} from "./model";
import "@/features/support/support.css";
import "@/features/safezones/safezones.css";
import "@/features/freecam/freecam.css";
import "./parkour.css";

/* Staff parkour editor (/lightrp.parkour, ACL command.lightrp.parkour): the keyboard shell of
   /admin and the mission editor. The page owns the draft; client/core/parkour_editor.lua
   measures (F11 at my feet, F10 where I aim), draws the draft in the world (every orb's
   trigger sphere, the route, the fall line) and runs the BUILD MODE (F9): aim and click to
   place orbs. Saving a changed route starts a new leaderboard (the server's revision). */

type Kind = "list" | "course" | "start" | "checkpoints" | "checkpoint" | "finish" | "rules" | "issues" | "delete" | "reset" | "discard";
type Page = { kind: Kind; selected?: string; index?: number };
type Entry = RageMenuItem & { run?: () => void; change?: (patch: Partial<RageMenuItem>) => void };
type TextEdit = { id: string; value: string; replace: boolean; numeric: boolean; max: number; commit: (value: string) => string | undefined };
type Capture = { position: Point; heading: number };
type Tool = "checkpoint" | "start" | "finish" | "move";
type Ref = { type: "start" | "finish" | "checkpoint"; index?: number; position?: Point; radius?: number };
const TOOLS: Tool[] = ["checkpoint", "start", "finish", "move"];
const TOOL_LABEL: Record<Tool, string> = { checkpoint: "Add checkpoint", start: "Start", finish: "Finish", move: "Move an orb" };
const message = (e: unknown) => e instanceof Error ? e.message : "The request failed.";
const coords = (p?: Point) => p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}` : "NOT PLACED";
const refLabel = (r?: Ref | null) => !r ? "" : r.type === "checkpoint" ? `Checkpoint ${r.index}` : r.type === "start" ? "Start" : "Finish";

export function ParkourEditor() {
  const [opened, setOpened] = useState(false);
  const [courses, setCourses] = useState<Course[]>([]);
  const [draft, setDraft] = useState<Course>();
  const [original, setOriginal] = useState("");
  const [stack, setStack] = useState<Page[]>([{ kind: "list" }]);
  const [world, setWorld] = useState(false);
  const [editing, setEditing] = useState<TextEdit>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(""), [feedback, setFeedback] = useState("");
  const [tool, setTool] = useState<Tool>("checkpoint");
  const [brush, setBrush] = useState(LIMITS.radius.default);
  const [carrying, setCarrying] = useState<Ref | null>(null);
  const [hovered, setHovered] = useState<Ref | null>(null);
  const [note, setNote] = useState<{ text?: string; error?: boolean }>({});
  const live = useRef(true), working = useRef(false), menu = useRef<HTMLDivElement>(null);
  const mutation = useRef<{ signature: string; key: string }>();
  const top = stack[stack.length - 1]!;
  const current = useRef({ opened, draft, top, typing: false, tool, brush, carrying });
  current.current = { opened, draft, top, typing: !!editing, tool, brush, carrying };
  const changed = !!draft && JSON.stringify(wire(draft)) + draft.status !== original;
  const update = (fn: (c: Course) => void) => setDraft((previous) => { if (!previous) return previous; const c = clone(previous); fn(c); return c; });
  const push = (page: Page) => { setError(""); setFeedback(""); setStack((s) => [...s, page]); };
  const pop = () => { setError(""); setStack((s) => s.length > 1 ? s.slice(0, -1) : s); };

  const refresh = useCallback(async () => {
    const data = await request<{ courses: Course[] }>("list");
    if (!live.current) return;
    setCourses((data.courses ?? []).map(normalizeCourse).sort((a, b) => a.name.localeCompare(b.name)));
  }, []);
  const run = useCallback(async (task: () => Promise<void>) => {
    if (working.current) return;
    working.current = true; setBusy(true); setError(""); setFeedback("");
    try { await task(); } catch (reason) { if (live.current) setError(message(reason)); }
    finally { working.current = false; if (live.current) setBusy(false); }
  }, []);
  const clearDraft = useCallback(() => {
    setDraft(undefined); setOriginal(""); setWorld(false); setEditing(undefined); setCarrying(null);
    setStack([{ kind: "list" }]); mutation.current = undefined;
    tell("preview", { course: null });
  }, []);
  const close = useCallback(() => { clearDraft(); setOpened(false); setError(""); tell("close"); }, [clearDraft]);

  /* F10 / F11 and the "place" rows: what the open page edits goes to the feet / the crosshair. */
  const place = useCallback((mode: "feet" | "aim", target?: Page) => run(async () => {
    const state = current.current;
    if (!state.draft || !state.opened || state.typing) return;
    const page = target ?? state.top;
    const c = await request<Capture>("capture", { mode });
    if (!live.current || !current.current.opened) return;
    const p = roundPoint(c.position);
    update((m) => {
      switch (page.kind) {
        case "course": case "start": m.start = { ...p, radius: m.start?.radius ?? LIMITS.radius.default, heading: m.start?.heading ?? Math.round(c.heading) }; break;
        case "finish": m.finish = { ...p, radius: m.finish?.radius ?? LIMITS.radius.default }; break;
        case "checkpoints": if (m.checkpoints.length < LIMITS.checkpoints) m.checkpoints.push({ ...p, radius: current.current.brush }); break;
        case "checkpoint": if (page.index != null && m.checkpoints[page.index]) m.checkpoints[page.index] = { ...p, radius: m.checkpoints[page.index]!.radius }; break;
        case "rules": m.floorZ = round(p.z - 2, 0.1); break;
        default: break;
      }
    });
    setFeedback(mode === "feet" ? "Placed at your feet." : "Placed where you aim.");
  }), [run]);

  // ---- events from the client ----
  const onBuild = useRef<(a: Record<string, unknown>) => void>(() => undefined);
  useEffect(() => {
    live.current = true;
    const off = onEditor((event) => {
      if (event.kind === "open") {
        useStore.getState().closeDialog(); useStore.getState().closeMenu();
        setOpened(true); setWorld(false); setError(""); void run(refresh);
      } else if (event.kind === "editor" && current.current.opened && !current.current.typing) setWorld(event.mode === "world");
      else if (event.kind === "hover") setHovered((event.hovered as Ref | null) ?? null);
      else if (event.kind === "build") onBuild.current(event);
      else if (event.kind === "captureKey") void place(event.mode === "aim" ? "aim" : "feet");
      else if (event.kind === "invalidate") {
        close(); useStore.getState().pushNotice({ kind: "warning", title: "Parkour editor", body: String(event.error || "The editor closed."), durationMs: 8000 });
      }
    });
    return () => { live.current = false; off(); tell("close"); };
  }, [close, place, refresh, run]);

  onBuild.current = (a) => {
    const state = current.current;
    if (!state.draft || !state.opened) return;
    const h = (a.hovered as Ref | null) ?? null;
    const say = (text: string, bad = false) => setNote({ text, error: bad });
    switch (a.action) {
      case "error": say(String(a.error ?? "Nothing under the crosshair."), true); break;
      case "tool": {
        const i = TOOLS.indexOf(state.tool);
        const next = TOOLS[(i + (Number(a.delta) || 1) + TOOLS.length) % TOOLS.length]!;
        setTool(next); setCarrying(null); say(`${TOOL_LABEL[next]} tool.`); break;
      }
      case "rotate":
        update((m) => { if (m.start) m.start.heading = ((m.start.heading + Number(a.delta || 0)) % 360 + 360) % 360; });
        say("Start facing turned."); break;
      case "select":
        if (!h) { say("Aim at an orb to open it in the menu.", true); break; }
        setStack([{ kind: "list" }, { kind: "course" }, ...(h.type === "checkpoint" ? [{ kind: "checkpoints" as Kind }, { kind: "checkpoint" as Kind, index: (h.index ?? 1) - 1 }] : [{ kind: h.type as Kind }])]);
        setWorld(false); break;
      case "delete":
        if (!h) { say("Aim at a checkpoint to remove it.", true); break; }
        if (h.type !== "checkpoint") { say("The start and the finish move, they are never removed.", true); break; }
        update((m) => { m.checkpoints.splice((h.index ?? 1) - 1, 1); });
        say(`Checkpoint ${h.index} removed.`); break;
      case "place": {
        const p = a.position as Point | undefined;
        if (!p) { say("Nothing under the crosshair.", true); break; }
        const at = roundPoint(p);
        if (state.tool === "move") {
          if (!state.carrying) {
            if (!h) { say("Aim at an orb and click to pick it up.", true); break; }
            setCarrying(h); say(`${refLabel(h)} picked up: click where it goes.`); break;
          }
          const ref = state.carrying;
          update((m) => {
            if (ref.type === "start" && m.start) m.start = { ...m.start, ...at };
            else if (ref.type === "finish" && m.finish) m.finish = { ...m.finish, ...at };
            else if (ref.type === "checkpoint" && m.checkpoints[(ref.index ?? 1) - 1]) m.checkpoints[(ref.index ?? 1) - 1] = { ...m.checkpoints[(ref.index ?? 1) - 1]!, ...at };
          });
          setCarrying(null); say(`${refLabel(ref)} moved.`); break;
        }
        if (state.tool === "checkpoint") {
          if (state.draft.checkpoints.length >= LIMITS.checkpoints) { say(`At most ${LIMITS.checkpoints} checkpoints.`, true); break; }
          update((m) => { m.checkpoints.push({ ...at, radius: state.brush }); });
          say(`Checkpoint ${state.draft.checkpoints.length + 1} placed.`); break;
        }
        if (state.tool === "start") { update((m) => { m.start = { ...at, radius: m.start?.radius ?? LIMITS.radius.default, heading: m.start?.heading ?? Math.round(Number(a.heading) || 0) }; }); say("Start placed."); break; }
        update((m) => { m.finish = { ...at, radius: m.finish?.radius ?? LIMITS.radius.default }; }); say("Finish placed.");
        break;
      }
      default: break;
    }
  };

  useEffect(() => {
    if (!opened) return;
    tell("input", { mode: world ? "world" : editing ? "typing" : "menu" });
    if (!world) menu.current?.focus();
  }, [opened, world, !!editing]); // eslint-disable-line react-hooks/exhaustive-deps
  const focus = top.kind === "start" || top.kind === "finish" ? top.kind : top.kind === "checkpoint" ? `checkpoint:${(top.index ?? 0) + 1}` : undefined;
  const toolWire = { name: tool, radius: tool === "checkpoint" ? brush : tool === "start" ? draft?.start?.radius ?? 3 : tool === "finish" ? draft?.finish?.radius ?? 3 : carrying?.radius ?? 2 };
  const toolKey = JSON.stringify(toolWire);
  useEffect(() => { if (opened) tell("preview", { course: draft ? wire(draft) : null, focus, tool: toolWire }); }, [draft, opened, focus, toolKey]); // eslint-disable-line react-hooks/exhaustive-deps

  // full keyboard while typing a row's value
  useEffect(() => {
    if (!opened || !editing) return;
    const handler = (event: KeyboardEvent) => {
      event.stopPropagation();
      if (event.key === "Enter") {
        event.preventDefault(); if (event.repeat) return;
        const reason = editing.commit(editing.value);
        if (reason) setError(reason); else { setEditing(undefined); setError(""); }
      } else if (event.key === "Escape") { event.preventDefault(); setEditing(undefined); setError(""); }
      else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "a") { event.preventDefault(); setEditing((e) => e ? { ...e, replace: true } : e); }
      else if (event.key === "Backspace" || event.key === "Delete") {
        event.preventDefault(); setEditing((e) => e ? { ...e, value: e.replace || event.key === "Delete" ? "" : Array.from(e.value).slice(0, -1).join(""), replace: false } : e);
      } else if (!event.ctrlKey && !event.metaKey && !event.altKey && Array.from(event.key).length === 1) {
        event.preventDefault(); const ch = event.key;
        if (editing.numeric && !/[0-9.+-]/.test(ch)) return;
        setEditing((e) => e ? { ...e, value: (e.replace ? ch : e.value + ch).slice(0, e.max), replace: false } : e);
      } else if (event.key === "Tab") event.preventDefault();
    };
    window.addEventListener("keydown", handler); return () => window.removeEventListener("keydown", handler);
  }, [opened, editing]);

  // ---- server operations ----
  const signed = (signature: string) => {
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    return mutation.current.key;
  };
  const create = () => run(async () => {
    const c = await request<Capture>("capture", { mode: "feet" });
    if (!live.current) return;
    setDraft(fresh(c)); setOriginal(""); setStack([{ kind: "list" }, { kind: "course" }]); mutation.current = undefined;
    setFeedback("New course: the start is at your feet. Add checkpoints and the finish (F9 build mode, or the menu).");
  });
  const edit = (c: Course) => { const d = clone(c); setDraft(d); setOriginal(JSON.stringify(wire(d)) + d.status); setStack([{ kind: "list" }, { kind: "course" }]); mutation.current = undefined; };
  const save = (status?: "published" | "draft") => run(async () => {
    if (!draft) return;
    const issues = problems(draft); if (issues.length) throw new Error(issues[0]!);
    const next = status ?? draft.status;
    const key = signed(JSON.stringify({ op: "save", c: wire(draft), status: next }));
    let result: { course: Course; reset?: boolean };
    try { result = await request("save", { course: wire(draft), status: next, baseRevision: draft.revision || undefined, mutation: key }); }
    catch (e) { if (e instanceof EditorTimeout) setError(e.message); throw e; }
    if (!live.current) return;
    const saved = normalizeCourse(result.course);
    setDraft(saved); setOriginal(JSON.stringify(wire(saved)) + saved.status); mutation.current = undefined;
    setFeedback(saved.status === "published"
      ? `Published.${result.reset ? " The route changed: a new leaderboard starts." : ""} The start orb is live in the city.`
      : `Saved as a draft (players do not see it).${result.reset ? " The route changed: a new leaderboard starts." : ""}`);
    await refresh();
  });
  const removeCourse = () => run(async () => {
    if (!draft?.id) return;
    await request("delete", { id: draft.id, mutation: signed(`delete:${draft.id}`) });
    if (!live.current) return;
    clearDraft(); setFeedback("Course deleted. Its start orb is gone; its times stay in the database."); await refresh();
  });
  const resetBoard = () => run(async () => {
    if (!draft?.id) return;
    const result = await request<{ course: Course }>("reset", { id: draft.id, mutation: signed(`reset:${draft.id}:${draft.revision}`) });
    if (!live.current) return;
    const saved = normalizeCourse(result.course);
    setDraft((d) => d ? { ...d, revision: saved.revision, runners: 0, record: undefined } : d); pop();
    setFeedback("Leaderboard reset: a new board starts now (the old times stay in the database).");
    await refresh();
  });
  const test = () => run(async () => {
    if (!draft) return;
    const issues = problems(draft); if (issues.length) throw new Error(issues[0]!);
    await request("test", { course: wire(draft) });
    if (!live.current) return;
    close();
  });
  const goTo = () => run(async () => { if (draft?.id) { await request("goto", { id: draft.id }); setFeedback("You are at the start."); } });
  const back = () => {
    if (working.current) return;
    if (editing) { setEditing(undefined); return; }
    if (top.kind === "course") { if (changed) push({ kind: "discard" }); else clearDraft(); }
    else if (top.kind === "list") close();
    else pop();
  };

  // ---- rows ----
  const item = (id: string, text: string, action?: () => void, options: Partial<Entry> = {}): Entry => ({ id, text, run: action, ...options });
  const submenu = (id: string, text: string, page: Page, options: Partial<Entry> = {}): Entry => item(id, text, () => push(page), { type: "submenu", ...options });
  const textEntry = (id: string, text: string, value: string, commit: (v: string) => string | undefined, max: number, description?: string): Entry =>
    item(id, text, () => { if (!busy) { setError(""); setEditing({ id, value, replace: true, numeric: false, max, commit }); } },
      { meta: value || "EMPTY", disabled: busy, description: description ?? "Enter edits this row: type, Enter applies, Escape cancels. Ctrl+A selects all." });
  const slider = (id: string, text: string, value: number, change: (v: number) => void, min: number, max: number, step: number, unit: string, description: string): Entry =>
    item(id, text, () => {
      if (busy) return;
      setError(""); setEditing({ id, value: String(value), replace: true, numeric: true, max: 12, commit: (input) => {
        const n = Number(input);
        if (input.trim() === "" || !Number.isFinite(n) || n < min || n > max) return `Enter a number from ${min} to ${max}.`;
        change(round(n, 0.1)); return undefined;
      } });
    }, { type: "slider", value, min, max, step, unit, disabled: busy, description: `${description} Left/right: ${step} ${unit}. Enter types a value.`,
      change: (patch) => { if (!busy && patch.value != null) change(Math.min(max, Math.max(min, round(patch.value, 0.1)))); } });
  const placeRows = (target: Page, what: string): Entry[] => [
    item(`feet:${what}`, `${what}: at my feet`, () => void place("feet", target), { icon: "footprints", disabled: busy, meta: "F11" }),
    item(`aim:${what}`, `${what}: where I aim`, () => void place("aim", target), { icon: "crosshair", disabled: busy, meta: "F10", description: "Aim at the spot (a roof edge, a ledge), then Enter or F10." }),
  ];

  let entries: Entry[] = [];
  let subtitle = "PARKOUR COURSES";
  const m = draft;
  if (top.kind === "list" || !m) {
    entries = [
      item("new", "New course here", create, { icon: "plus", disabled: busy, description: "The start goes at your feet, facing where you face. Then add checkpoints and the finish." }),
      { separator: true },
      ...courses.map((c) => item(`course:${c.id}`, c.name, () => edit(c), { type: "submenu", icon: c.status === "published" ? "flag" : "file-text",
        meta: `${c.status === "published" ? "LIVE" : "DRAFT"} · ${c.checkpoints.length} CP · ${formatLength(c.length ?? routeLength(c))}`,
        description: `${DIFFICULTY_LABEL[c.difficulty]} · ${c.finishes ?? 0} finishes · record ${c.record ? `${formatTime(c.record.timeMs)} by ${c.record.name}` : "open"}${c.description ? ` · ${c.description}` : ""}` })),
      ...(courses.length === 0 ? [item("none", "No course yet", undefined, { disabled: true, description: "Walk to where a course starts and pick New course here." })] : []),
      { separator: true },
      item("close", "Close the editor", close, { icon: "x" }),
    ];
  } else {
    subtitle = (m.name || "NEW COURSE").toUpperCase();
    const issues = problems(m);
    switch (top.kind) {
      case "course":
        entries = [
          textEntry("name", "Name", m.name, (v) => { if (v.trim().length < 3 || v.trim().length > LIMITS.name) return `3 to ${LIMITS.name} characters.`; update((c) => { c.name = v.trim(); }); return undefined; }, LIMITS.name),
          textEntry("description", "Description", m.description, (v) => { update((c) => { c.description = v.trim(); }); return undefined; }, LIMITS.description, "What the course card says: the route, the trick, the view."),
          item("difficulty", "Difficulty", undefined, { type: "list", options: DIFFICULTIES.map((d) => DIFFICULTY_LABEL[d]), index: DIFFICULTIES.indexOf(m.difficulty),
            change: (patch) => { if (patch.index != null) update((c) => { c.difficulty = DIFFICULTIES[patch.index!] as Difficulty; }); }, description: "A label for the players: it changes nothing in the run." }),
          { separator: true },
          submenu("start", "Start orb", { kind: "start" }, { icon: "play", meta: m.start ? `R ${m.start.radius} M` : "NOT SET" }),
          submenu("checkpoints", "Checkpoints", { kind: "checkpoints" }, { icon: "map-pin", meta: `${m.checkpoints.length} / ${LIMITS.checkpoints}`, description: "Optional: a course can go straight from the start to the finish." }),
          submenu("finish", "Finish orb", { kind: "finish" }, { icon: "flag", meta: m.finish ? `R ${m.finish.radius} M` : "NOT SET" }),
          submenu("rules", "Rules", { kind: "rules" }, { icon: "settings", meta: `${m.timeLimit ? `${m.timeLimit} MIN` : "NO LIMIT"}${m.floorZ != null ? " · FALL LINE" : ""}` }),
          { separator: true },
          item("build", "Build mode", () => { setWorld(true); setNote({ text: `${TOOL_LABEL[tool]} tool. Aim and click.` }); }, { icon: "mouse-pointer-click", meta: "F9",
            description: "Aim and LEFT CLICK to place orbs; RIGHT CLICK opens the aimed orb here; DELETE removes the aimed checkpoint; UP/DOWN tool; F9 back." }),
          item("length", "Route", undefined, { disabled: true, meta: formatLength(routeLength(m)), description: `${m.checkpoints.length} checkpoints. Revision ${m.revision || "new"}${m.record ? ` · record ${formatTime(m.record.timeMs)} by ${m.record.name}` : ""}.` }),
          ...(issues.length ? [submenu("issues", "Not ready yet", { kind: "issues" }, { icon: "triangle-alert", danger: true, meta: String(issues.length), description: issues[0] })] : []),
          item("test", "Test run (not recorded)", test, { icon: "timer", disabled: busy || issues.length > 0, description: "Run the draft as it is now, saved or not. Nothing reaches the leaderboard. The editor closes." }),
          item("publish", m.id ? (m.status === "published" ? "Save (live)" : "Save and publish") : "Publish", () => save("published"), { icon: "flag", disabled: busy || issues.length > 0,
            description: "The start orb goes live in the city (E prompt + map blip). A moved, added or removed orb, a radius or the fall line starts a new leaderboard." }),
          item("draft", m.status === "published" && m.id ? "Unpublish (save as a draft)" : "Save as a draft", () => save("draft"), { icon: "file-text", disabled: busy || issues.length > 0, description: "Kept for the staff only: no start orb, no blip, not in F1 > Parkour." }),
          ...(m.id ? [
            item("goto", "Go to the start", goTo, { icon: "navigation", disabled: busy }),
            submenu("reset", "Reset the leaderboard", { kind: "reset" }, { icon: "undo-2", danger: true, disabled: busy }),
            submenu("delete", "Delete this course", { kind: "delete" }, { icon: "trash-2", danger: true, disabled: busy }),
          ] : []),
        ];
        break;
      case "start":
        entries = [
          ...placeRows({ kind: "start" }, "Start"),
          slider("radius", "Start radius", m.start?.radius ?? 3, (v) => update((c) => { if (c.start) c.start.radius = v; }), LIMITS.radius.min, LIMITS.radius.max, 0.5, "m", "The start orb's size (the runner is placed at its centre)."),
          slider("heading", "Runner facing", m.start?.heading ?? 0, (v) => update((c) => { if (c.start) c.start.heading = ((Math.round(v) % 360) + 360) % 360; }), 0, 359, 15, "°", "Which way the runner faces on the line. At my feet: your own facing."),
          item("where", "Position", undefined, { disabled: true, meta: coords(m.start) }),
        ];
        break;
      case "finish":
        entries = [
          ...placeRows({ kind: "finish" }, "Finish"),
          slider("radius", "Finish radius", m.finish?.radius ?? 3, (v) => update((c) => { if (c.finish) c.finish.radius = v; }), LIMITS.radius.min, LIMITS.radius.max, 0.5, "m", "Touching this sphere stops the clock."),
          item("where", "Position", undefined, { disabled: true, meta: coords(m.finish) }),
        ];
        break;
      case "checkpoints":
        entries = [
          ...placeRows({ kind: "checkpoints" }, "Add a checkpoint"),
          slider("brush", "New checkpoints' radius", brush, setBrush, LIMITS.radius.min, LIMITS.radius.max, 0.5, "m", "The radius each new checkpoint gets (the menu and the build mode)."),
          { separator: true },
          ...m.checkpoints.map((c, i) => {
            const prev = i === 0 ? m.start : m.checkpoints[i - 1];
            return submenu(`cp:${i}`, `Checkpoint ${i + 1}`, { kind: "checkpoint", index: i }, { meta: `R ${c.radius} · ${prev ? Math.round(distance(prev, c)) + " M" : ""}`, description: coords(c) });
          }),
          ...(m.checkpoints.length === 0 ? [item("none", "No checkpoint", undefined, { disabled: true, description: "Optional. Without one the run goes straight from the start to the finish." })] : []),
        ];
        break;
      case "checkpoint": {
        const i = top.index ?? 0, c = m.checkpoints[i];
        if (c) entries = [
          ...placeRows({ kind: "checkpoint", index: i }, "Move it"),
          slider("radius", "Radius", c.radius, (v) => update((d) => { if (d.checkpoints[i]) d.checkpoints[i]!.radius = v; }), LIMITS.radius.min, LIMITS.radius.max, 0.5, "m", "The sphere the runner must touch."),
          item("where", "Position", undefined, { disabled: true, meta: coords(c) }),
          { separator: true },
          item("up", "Move earlier in the route", () => { if (i > 0) { update((d) => { const t = d.checkpoints[i - 1]!; d.checkpoints[i - 1] = d.checkpoints[i]!; d.checkpoints[i] = t; }); setStack((s) => s.map((p, k) => k === s.length - 1 ? { ...p, index: i - 1 } : p)); } }, { disabled: i === 0 }),
          item("down", "Move later in the route", () => { if (i < m.checkpoints.length - 1) { update((d) => { const t = d.checkpoints[i + 1]!; d.checkpoints[i + 1] = d.checkpoints[i]!; d.checkpoints[i] = t; }); setStack((s) => s.map((p, k) => k === s.length - 1 ? { ...p, index: i + 1 } : p)); } }, { disabled: i >= m.checkpoints.length - 1 }),
          item("insert", "Insert one before it, at my feet", () => void run(async () => {
            const at = await request<Capture>("capture", { mode: "feet" });
            update((d) => { if (d.checkpoints.length < LIMITS.checkpoints) d.checkpoints.splice(i, 0, { ...roundPoint(at.position), radius: brush }); });
          }), { icon: "plus", disabled: busy || m.checkpoints.length >= LIMITS.checkpoints }),
          item("remove", "Remove this checkpoint", () => { update((d) => { d.checkpoints.splice(i, 1); }); pop(); }, { icon: "trash-2", danger: true }),
        ];
        break;
      }
      case "rules":
        entries = [
          slider("limit", "Time limit", m.timeLimit, (v) => update((c) => { c.timeLimit = Math.round(v); }), 0, LIMITS.timeLimitMax, 1, "min", "0: no limit (a run still stops after 30 minutes). Past the limit the run is a DNF."),
          item("fall", "Fall line", () => update((c) => { c.floorZ = c.floorZ == null && c.start ? round(c.start.z - 6, 0.1) : undefined; }), { type: "checkbox", checked: m.floorZ != null,
            change: (patch) => update((c) => { c.floorZ = patch.checked && c.start ? round(c.start.z - 6, 0.1) : undefined; }),
            description: "Rooftop courses: a runner who drops below this height goes back to the last checkpoint, clock running (drawn in red)." }),
          ...(m.floorZ != null ? [
            slider("fallZ", "Fall line height", m.floorZ, (v) => update((c) => { c.floorZ = v; }), Math.round((m.start?.z ?? 0) - 200), Math.round((m.start?.z ?? 0) - 0.5), 1, "m", "Absolute height (the start is at " + (m.start?.z.toFixed(1) ?? "?") + " m)."),
            item("fallFeet", "Fall line 2 m under my feet", () => void place("feet", { kind: "rules" }), { icon: "footprints", disabled: busy }),
          ] : []),
        ];
        break;
      case "issues":
        entries = problems(m).map((text, i) => item(`issue:${i}`, text, undefined, { disabled: true, description: text }));
        break;
      case "delete":
        entries = [item("cancel", "Keep this course", pop), item("confirm", "Delete it", removeCourse, { danger: true, disabled: busy,
          description: "Its start orb and blip go at once. Runs in progress finish. The times stay in the database." })];
        break;
      case "reset":
        entries = [item("cancel", "Keep the leaderboard", pop), item("confirm", "Reset the leaderboard", resetBoard, { danger: true, disabled: busy,
          description: "Every player's best on this course is set aside: a new board starts now." })];
        break;
      case "discard":
        entries = [item("cancel", "Keep editing", pop), item("discard", "Discard the changes", clearDraft, { danger: true, description: "Unsaved changes are lost. The saved course stays as it was." })];
        break;
      default: break;
    }
    if (top.kind !== "discard" && top.kind !== "delete" && top.kind !== "reset") entries.push({ separator: true }, item("back", "Back", back, { icon: "chevron-left", disabled: busy }));
  }
  if (busy) entries.push(item("working", "Waiting…", undefined, { disabled: true }));
  const selectedIndex = entries.findIndex((e) => e.id === top.selected && isPickable(e));
  const index = selectedIndex >= 0 ? selectedIndex : Math.max(0, entries.findIndex(isPickable));
  const visible = entries.map((e) => editing && editing.id === e.id ? { ...e, type: "item" as const, meta: undefined,
    description: `${editing.replace ? "[" : ""}${editing.value}${editing.replace ? "]" : "▏"}  ·  ENTER APPLY / ESC CANCEL` } : e);
  const names: Partial<Record<Kind, string>> = { course: "COURSE", start: "START", checkpoints: "CHECKPOINTS", checkpoint: "CHECKPOINT", finish: "FINISH", rules: "RULES",
    issues: "ISSUES", delete: "DELETE", reset: "RESET", discard: "DISCARD" };

  if (!opened) return null;
  return <>
    {!world && <section className="rp-support safezone-menu pk-editor" aria-label="Parkour editor"><div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title="LIGHT/RP" subtitle={subtitle} tag={draft ? changed ? "DRAFT" : draft.id ? (draft.status === "published" ? "LIVE" : "SAVED") : "NEW" : "STAFF"}
        items={visible} index={index} width={390} visibleRows={11}
        path={["ADMIN", "PARKOUR", ...stack.slice(1).map((p) => names[p.kind] ?? p.kind.toUpperCase())]}
        active={!editing && !busy}
        onIndexChange={(next) => setStack((s) => s.map((p, i) => i === s.length - 1 ? { ...p, selected: entries[next]?.id } : p))}
        onSelect={(_, next) => entries[next]?.run?.()} onChange={(_, next, patch) => entries[next]?.change?.(patch)} onBack={back}
        footer={editing ? <><span>TYPE</span><span>ENTER APPLY</span><span>ESC CANCEL</span></>
          : <><span>↑↓ MOVE</span><span>←→ CHANGE</span><span>ENTER SELECT</span><span>BKSP BACK</span>{draft && <><span>F9 BUILD</span><span>F10 AIM</span><span>F11 FEET</span></>}</>} />
      {error && <p className="rp-support__error" role="alert">{error}</p>}{feedback && !error && <p className="rp-support__success" role="status">{feedback}</p>}
    </div></section>}
    {world && draft && <BuildBar course={draft} tool={tool} brush={brush} carrying={carrying} hovered={hovered} note={note.text} bad={note.error || !!error} />}
  </>;
}

function BuildBar({ course, tool, brush, carrying, hovered, note, bad }: { course: Course; tool: Tool; brush: number; carrying: Ref | null; hovered: Ref | null; note?: string; bad?: boolean }) {
  const status = carrying ? `Carrying ${refLabel(carrying)}: click where it goes.`
    : hovered ? `Aimed: ${refLabel(hovered)}. RIGHT CLICK opens it${hovered.type === "checkpoint" ? ", DELETE removes it" : ""}.`
    : tool === "checkpoint" ? `Click to add checkpoint ${course.checkpoints.length + 1}.` : tool === "move" ? "Aim at an orb and click to pick it up." : `Click to place the ${tool}.`;
  const Key = ({ children }: { children: string }) => <kbd className={"freecam__key" + (children.length > 1 ? " freecam__key--wide" : "")}>{children}</kbd>;
  return <div className="freecam pk-build" role="status" aria-label="Parkour build mode">
    <div className="freecam__head">
      <span className="freecam__title"><span className="pk-build__dot" /><Icon name="footprints" size={15} />PARKOUR · BUILD</span>
      <span className="freecam__status">{status}</span>
      <span className="freecam__readout"><b>{TOOL_LABEL[tool].toUpperCase()}</b></span>
      <span className="freecam__readout"><b>{course.checkpoints.length}</b> CP</span>
      <span className="freecam__readout"><b>{formatLength(routeLength(course))}</b></span>
      {tool === "checkpoint" && <span className="freecam__readout"><b>R {brush}</b> M</span>}
    </div>
    {note && <p className={"pk-build__message" + (bad ? " is-error" : "")}>{note}</p>}
    <ul className="freecam__keys">
      <li><Key>LMB</Key><span>Place</span></li>
      <li><Key>RMB</Key><span>Open aimed</span></li>
      <li><Key>DEL</Key><span>Remove CP</span></li>
      <li><span className="freecam__pair"><Key>↑</Key><Key>↓</Key></span><span>Tool</span></li>
      <li><span className="freecam__pair"><Key>←</Key><Key>→</Key></span><span>Start facing</span></li>
      <li className="freecam__exit"><Key>F9</Key><span>Menu</span></li>
    </ul>
  </div>;
}
