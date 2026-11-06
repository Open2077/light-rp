import { useCallback, useEffect, useRef, useState } from "react";
import { emit } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { RageMenu, isPickable } from "@/design/components";
import { editorChannel, MissionRequestTimeout, mutationKey } from "@/features/missioneditor/api";
import { BuildStrip } from "@/features/missioneditor/BuildStrip";
import { clone } from "@/features/missioneditor/model";
import { rowBuilders, useTyping, type Entry, type TextEdit } from "@/features/missioneditor/rows";
import { applyBuild, toolHelp, type BuildAction, type BuildState } from "./build";
import {
  drawing, drawingNote, duplicate, fresh, LIMITS, ninthRefused, normalizeMap, normalizeSchema, ofListing, problems, receiveListed, toolsFor,
  type Capture, type Drawn, type Game, type GameMap, type GamesReply, type Listing, type Ref, type Schema, type Spot, type Wire,
} from "./model";
import "@/features/support/support.css";
import "@/features/safezones/safezones.css";
import "@/features/missioneditor/missioneditor.css";

type Kind = "games" | "maps" | "map" | "point" | "list" | "spot" | "choice" | "issues" | "discard" | "delete";
type Page = { kind: Kind; selected?: string; key?: string; index?: number };
const message = (error: unknown) => error instanceof Error ? error.message : "The request failed.";
const coords = (p: Spot) => `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}`;
const { onEditor, request } = editorChannel<Wire>(PAGE_EVENTS.mapEditor);

/** Staff map editor (/lightrp.maps): the mission editor's shell and build mode on a game map. */
export function MapEditor() {
  const [opened, setOpened] = useState(false), [ready, setReady] = useState(false);
  const [games, setGames] = useState<Game[]>([]), [game, setGame] = useState<Game>();
  const [maps, setMaps] = useState<GameMap[]>([]), [loading, setLoading] = useState<{ received: number; total: number } | null>(null);
  const [draft, setDraft] = useState<GameMap>(), [original, setOriginal] = useState("");
  const [stack, setStack] = useState<Page[]>([{ kind: "games" }]), [world, setWorld] = useState(false);
  const [editing, setEditing] = useState<TextEdit>(), [stepIndex] = useState(1);
  const [busy, setBusy] = useState(false), [unconfirmed, setUnconfirmed] = useState<"save" | "delete" | "enable">();
  const [error, setError] = useState(""), [feedback, setFeedback] = useState("");
  const [build, setBuild] = useState<BuildState>({ tool: "", heading: null });
  const [hovered, setHovered] = useState<Ref | null>(null), [buildNote, setBuildNote] = useState<{ message?: string; error?: string }>({});
  const [drawn, setDrawn] = useState<Drawn | null>(null);
  const live = useRef(true), working = useRef(false), menu = useRef<HTMLDivElement>(null);
  const mutation = useRef<{ signature: string; key: string }>();
  const top = stack[stack.length - 1]!;
  const schema: Schema | undefined = game?.schema;
  const current = useRef({ opened, draft, top, typing: false, build, schema, stream: "" });
  current.current = { ...current.current, opened, draft, top, typing: !!editing, build, schema };
  const locked = busy || !!unconfirmed;
  const changed = !!draft && JSON.stringify(draft) !== original;
  const push = (page: Page) => { setError(""); setFeedback(""); setStack(previous => [...previous, page]); };
  const pop = () => { setError(""); setStack(previous => previous.length > 1 ? previous.slice(0, -1) : previous); };
  const update = (patch: Partial<GameMap>) => setDraft(previous => previous ? { ...previous, ...patch } : previous);

  const loadGames = useCallback(async () => {
    const data = await request<GamesReply>("games");
    if (!live.current) return;
    setReady(data.ready === true);
    const list = (Array.isArray(data.games) ? data.games : []).map(g => ({ ...g, schema: normalizeSchema(g.schema) }));
    setGames(list);
    setGame(previous => previous ? list.find(g => g.id === previous.id) ?? previous : previous);
  }, []);
  const loadMaps = useCallback(async (id: string) => {
    current.current.stream = ""; /* whatever still streams is stale from here on */
    setMaps([]); setLoading(null);
    let mine = "";
    const data = await request<Listing>("list", { game: id }, sent => { mine = sent; current.current.stream = sent; });
    if (!live.current || current.current.stream !== mine) return;
    setReady(data.ready === true);
    setLoading(data.total ? { received: 0, total: data.total } : null);
  }, []);
  const run = useCallback(async (task: () => Promise<void>) => {
    if (working.current) return;
    working.current = true; setBusy(true); setError(""); setFeedback("");
    try { await task(); } catch (reason) { if (live.current) setError(message(reason)); }
    finally { working.current = false; if (live.current) setBusy(false); }
  }, []);
  const clearDraft = useCallback(() => {
    setDraft(undefined); setOriginal(""); setWorld(false); setEditing(undefined); setDrawn(null);
    setStack(previous => previous.slice(0, 2)); setUnconfirmed(undefined); mutation.current = undefined;
    emit(PAGE_EVENTS.mapEditor, { operation: "preview", map: null });
  }, []);
  const close = useCallback(() => {
    clearDraft(); setStack([{ kind: "games" }]); setGame(undefined); setOpened(false); setError("");
    current.current.stream = ""; setMaps([]); setLoading(null);
    emit(PAGE_EVENTS.mapEditor, { operation: "close" });
  }, [clearDraft]);

  /* F11 (and the menu's "place" rows): what the open page edits moves to the feet / the crosshair. */
  const place = useCallback((mode: "feet" | "aim") => run(async () => {
    const state = current.current;
    if (!state.draft || !state.opened || state.typing) return;
    const page = state.top;
    if (page.kind !== "point" && page.kind !== "list" && page.kind !== "spot") throw new Error("Open the point to place first.");
    const c = await request<Capture>("capture", { mode });
    if (!live.current || !current.current.opened) return;
    const spot: Spot = { ...c.position, heading: c.heading };
    setDraft(previous => {
      if (!previous || !page.key) return previous;
      if (page.kind === "point") return { ...previous, [page.key]: spot };
      const list = [...((previous[page.key] ?? []) as Spot[])];
      const max = current.current.schema?.lists.find(l => l.key === page.key)?.max ?? 0;
      if (page.kind === "list") { if (list.length < max) list.push(spot); } else if (page.index != null && list[page.index]) list[page.index] = spot;
      return { ...previous, [page.key]: list };
    });
  }), [run]);

  useEffect(() => {
    live.current = true;
    const off = onEditor(event => {
      if (event.kind === "map" || event.kind === "listed") {
        const { stream, schema: s } = current.current;
        if (!ofListing(stream, event)) return;
        if (event.kind === "listed") { setLoading(null); return; }
        setMaps(previous => receiveListed(stream, s, previous, event));
        setLoading(previous => previous ? { ...previous, received: Math.min(previous.total, previous.received + 1) } : previous);
        return;
      }
      if (event.kind === "drawing") { setDrawn({ total: event.total ?? 0, shown: event.shown ?? 0, full: event.full ?? 0 }); return; }
      if (event.kind === "open") {
        useStore.getState().closeDialog(); useStore.getState().closeMenu();
        setOpened(true); setWorld(false); setError(""); void run(loadGames);
      } else if (event.kind === "editor" && current.current.opened && !current.current.typing) setWorld(event.mode === "world");
      else if (event.kind === "hover") setHovered(event.hovered ?? null);
      else if (event.kind === "build") onBuild.current(event as unknown as BuildAction);
      else if (event.kind === "captureKey") void place(event.mode === "aim" ? "aim" : "feet");
      else if (event.kind === "invalidate") {
        close(); useStore.getState().pushNotice({ kind: "warning", title: "Map editor", body: event.error || "The editor closed.", durationMs: 8000 });
      }
    });
    return () => { live.current = false; off(); emit(PAGE_EVENTS.mapEditor, { operation: "close" }); };
  }, [close, place, loadGames, run]);
  useEffect(() => {
    if (!opened) return;
    emit(PAGE_EVENTS.mapEditor, { operation: "input", mode: world ? "world" : editing ? "typing" : "menu" });
    if (!world) menu.current?.focus();
  }, [opened, world, !!editing]);

  const onBuild = useRef<(a: BuildAction) => void>(() => undefined);
  onBuild.current = (a: BuildAction) => {
    const state = current.current;
    if (!state.draft || !state.opened || !state.schema) return;
    const result = applyBuild(state.schema, state.draft, state.build, a);
    if (result.map) setDraft(normalizeMap(state.schema, result.map));
    if (result.build) setBuild(result.build);
    setBuildNote({ message: result.message, error: result.error });
    if (result.select) openRef(result.select);
  };
  /* Right-click in build mode: the menu opens on the aimed point's own page. */
  const openRef = (ref: Ref) => {
    const base = stack.slice(0, 3);
    setStack([...base, ...(ref.type === "point" ? [{ kind: "point" as const, key: ref.key }]
      : [{ kind: "list" as const, key: ref.key }, { kind: "spot" as const, key: ref.key, index: (ref.index ?? 1) - 1 }])]);
    setWorld(false); setError(""); setFeedback("");
  };
  const tools = schema ? toolsFor(schema) : [];
  const enterBuild = (tool?: string) => {
    setBuild(previous => ({ ...previous, tool: tool ?? (tools.some(t => t.id === previous.tool) ? previous.tool : tools[0]?.id ?? ""), carrying: undefined }));
    setBuildNote({ message: undefined }); setHovered(null); setWorld(true);
  };
  const activeTool = tools.find(t => t.id === build.tool) ?? tools[0];
  const focus = top.kind === "point" ? `point:${top.key}` : top.kind === "spot" ? `list:${top.key}:${(top.index ?? 0) + 1}` : undefined;
  const wire = { tool: activeTool?.id ?? "", heading: build.heading, carrying: build.carrying ?? null, color: activeTool ? `${activeTool.color}ff` : null };
  const wireKey = JSON.stringify(wire);
  const toDraw = schema ? drawing(schema) : null;
  useEffect(() => {
    if (!opened || !schema) return;
    const map = draft ? { ...draft, problems: undefined } : null;
    emit(PAGE_EVENTS.mapEditor, { operation: "preview", map, focus, build: wire, layers: toDraw?.layers ?? [], area: toDraw?.area ?? null });
  }, [draft, opened, focus, wireKey, schema]);
  useTyping(opened, editing, setEditing, setError);

  const openGame = (g: Game) => run(async () => { setGame(g); current.current.schema = g.schema; setStack([{ kind: "games" }, { kind: "maps" }]); await loadMaps(g.id); });
  const edit = (source: GameMap | undefined, copy = false) => {
    if (!schema) return;
    const next = !source ? fresh(schema) : copy ? duplicate(source) : clone(source);
    setDraft(next); setOriginal(source && !copy ? JSON.stringify(next) : ""); setWorld(false); setEditing(undefined);
    setStack([{ kind: "games" }, { kind: "maps" }, { kind: "map" }]); mutation.current = undefined; setError(""); setFeedback("");
  };
  const mutate = async <T,>(what: "save" | "delete" | "enable", payload: Record<string, unknown>): Promise<T> => {
    const signature = JSON.stringify({ what, ...payload });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    try { const result = await request<T>(what, { ...payload, game: game?.id, mutation: mutation.current.key }); mutation.current = undefined; setUnconfirmed(undefined); return result; }
    catch (reason) { if (reason instanceof MissionRequestTimeout) setUnconfirmed(what); throw reason; }
  };
  const settled = (saved: GameMap) => { const m = normalizeMap(schema!, saved); setDraft(m); setOriginal(JSON.stringify(m)); };
  const save = () => run(async () => {
    if (!draft || !game) return;
    const result = await mutate<{ map: GameMap }>("save", { map: { ...draft, problems: undefined }, baseRevision: draft.revision });
    if (!live.current) return;
    settled(result.map);
    setFeedback(result.map.enabled ? "Map saved. Rooms offer it now; a match in progress keeps its copy." : "Draft saved. Players do not see it until it is enabled.");
    await loadGames(); await loadMaps(game.id);
  });
  const setEnabled = (enabled: boolean) => run(async () => {
    if (!draft?.id || !game) return;
    if (changed) throw new Error("Save your changes first.");
    const result = await mutate<{ map: GameMap }>("enable", { id: draft.id, enabled, baseRevision: draft.revision });
    if (!live.current) return;
    settled(result.map);
    setFeedback(enabled ? "Enabled: rooms offer this map now." : "Disabled: no longer offered. A match in progress finishes on it.");
    await loadGames(); await loadMaps(game.id);
  });
  const remove = () => run(async () => {
    if (!draft?.id || !game) return;
    await mutate("delete", { id: draft.id, baseRevision: draft.revision });
    if (!live.current) return;
    clearDraft(); setFeedback("Map deleted. It will not come back. A match in progress finishes on it.");
    await loadGames(); await loadMaps(game.id);
  });
  const back = () => {
    if (working.current || unconfirmed) return;
    if (editing) { setEditing(undefined); return; }
    if (top.kind === "map") { if (changed) push({ kind: "discard" }); else clearDraft(); }
    else if (top.kind === "games") close();
    else if (top.kind === "maps") { current.current.stream = ""; setLoading(null); setGame(undefined); setMaps([]); setStack([{ kind: "games" }]); emit(PAGE_EVENTS.mapEditor, { operation: "preview", map: null }); }
    else pop();
  };

  const { readOnly, item, submenu, textEntry, numberEntry, toggle } = rowBuilders<Page>({ locked, stepIndex, setEditing, setError, push });
  const placeRows = (what: string, tool: string, target?: Ref): Entry[] => [
    item("placeAim", `Place ${what} with the mouse`, () => {
      if (target) { setBuild(previous => ({ ...previous, tool: "move", carrying: target })); setBuildNote({ message: `Click where ${what} goes.` }); setHovered(null); setWorld(true); } else enterBuild(tool);
    }, { icon: "crosshair", disabled: readOnly, description: "Build mode: aim with the crosshair and click. F9 comes back to the menu." }),
    item("placeFeet", `Place ${what} at my feet`, () => { void place("feet"); }, { icon: "map-pin", disabled: readOnly, description: "Exactly where you stand, facing your direction (F11)." }),
  ];
  const coordinateRows = (prefix: string, p: Spot, change: (p: Spot) => void): Entry[] =>
    (["x", "y", "z"] as const).map(axis => numberEntry(`${prefix}:${axis}`, axis.toUpperCase(), p[axis], v => change({ ...p, [axis]: v }), -100000, 100000));

  let entries: Entry[] = [], subtitle = "GAME MAPS";
  const issues = draft && schema ? problems(schema, draft) : [];
  if (top.kind === "games") {
    entries = [...games.map(g => item(`game:${g.id}`, g.label, () => { void openGame(g); }, { type: "submenu", meta: `${g.enabled} / ${LIMITS.enabled} ON`, disabled: busy,
        description: `${g.total} map(s), ${g.enabled} enabled. Rooms list ${LIMITS.enabled} at most; a game with none is not offered.` })),
      ...(!games.length ? [item("empty", busy ? "Waiting..." : "No game: op77_games is not running", undefined, { disabled: true })] : []),
      { separator: true }, item("refresh", "Refresh", () => { void run(loadGames); }, { icon: "activity", disabled: busy }), item("close", "Close editor", close, { icon: "x", disabled: busy })];
  } else if (top.kind === "maps" && game) {
    subtitle = game.label;
    entries = [item("create", "Create a map", () => edit(undefined), { icon: "plus", disabled: busy || !ready, description: ready ? "A private draft. Nothing changes until it is saved and enabled." : "Map storage is unavailable." }),
      { separator: true },
      ...maps.map(m => item(`map:${m.id}`, m.name, () => edit(m), { type: "submenu", meta: m.enabled ? "ENABLED" : m.problems?.length ? `DRAFT · ${m.problems.length} TO FIX` : "DRAFT", disabled: busy,
        description: m.problems?.[0] ?? `Revision ${m.revision}.` })),
      ...(loading ? [item("loading", `Loading maps ${loading.received}/${loading.total}`, undefined, { disabled: true, icon: "activity" })] : []),
      ...(!maps.length && !loading ? [item("none", ready ? "No map yet" : busy ? "Waiting..." : "Storage unavailable", undefined, { disabled: true })] : [])];
  } else if (draft && schema && game) {
    subtitle = draft.name;
    const m = draft;
    const visible = schema.numbers.filter(n => !n.hidden);
    switch (top.kind) {
      case "map": {
        const refused = !m.enabled ? issues[0] ?? ninthRefused(game, false) : undefined;
        entries = [
          item("build", "Build mode: place with the mouse", () => enterBuild(), { icon: "crosshair", description: "Aim and click to place what this game needs. Up/Down change the tool, right-click selects, Delete removes. F9 comes back here." }),
          { separator: true },
          textEntry("name", "Name", m.name, v => { const t = v.trim(); if (!t || t.length > LIMITS.name) return `Choose a name of 1-${LIMITS.name} characters.`; update({ name: t }); return undefined; }, LIMITS.name, "What rooms show. Renaming keeps the map's id."),
          ...schema.points.filter(p => !p.hidden).map(p => submenu(`point:${p.key}`, p.label, { kind: "point", key: p.key }, { meta: m[p.key] ? "PLACED" : "MISSING", description: m[p.key] ? coords(m[p.key] as Spot) : "Not placed yet." })),
          ...schema.lists.map(l => submenu(`list:${l.key}`, `${l.label} list`, { kind: "list", key: l.key }, { meta: `${(m[l.key] as Spot[]).length} / ${l.max}`, description: l.min ? `At least ${l.min}.` : "Optional." })),
          ...visible.map(n => numberEntry(`number:${n.key}`, n.label, m[n.key] as number, v => update({ [n.key]: v }), n.min, n.max, n.unit, n.integer ? 5 : 1, n.integer === true)),
          ...schema.choices.map(c => submenu(`choice:${c.key}`, c.label, { kind: "choice", key: c.key }, { meta: (m[c.key] as string[]).length ? `${(m[c.key] as string[]).length} TICKED` : "ALL", description: c.about })),
          { separator: true },
          ...(issues.length ? [submenu("issues", `Fix ${issues.length} issue${issues.length > 1 ? "s" : ""}`, { kind: "issues" }, { icon: "triangle-alert", danger: true, description: issues[0] })] : []),
          item("save", unconfirmed === "save" ? "Check the save" : "Save map", save, { icon: "check", disabled: busy || unconfirmed === "delete" || unconfirmed === "enable" || !ready || (m.enabled && issues.length > 0),
            description: m.enabled && issues[0] ? `An enabled map cannot be saved like this: ${issues[0]}` : "Saved as a draft unless enabled. A stale copy is refused, not overwritten." }),
          toggle("enabled", unconfirmed === "enable" ? "Check the change" : "Map enabled", m.enabled, on => {
            if (on && refused) { setError(refused); return; }
            if (!m.id) { setError("Save the map first."); return; }
            void setEnabled(on);
          }, m.enabled ? "On: rooms offer it. A match in progress keeps its copy." : refused ?? "Off: players do not see it."),
          item("duplicate", "Duplicate map", () => edit(m, true), { disabled: readOnly, description: "A new draft from these points." }),
          submenu("delete", "Delete map", { kind: "delete" }, { danger: true, disabled: readOnly || !m.id, description: "It leaves the rooms at once and never comes back." }),
        ];
        break;
      }
      case "point": {
        const p = schema.points.find(v => v.key === top.key), at = p && m[p.key] as Spot | undefined;
        if (p) entries = [...placeRows(p.label, `point:${p.key}`),
          ...(at ? [numberEntry("heading", "Facing", at.heading ?? 0, heading => update({ [p.key]: { ...at, heading } }), -36000, 36000, "°", 15),
            ...coordinateRows("point", at, q => update({ [p.key]: q })),
            item("remove", `Remove ${p.label}`, () => { update({ [p.key]: undefined }); pop(); }, { danger: true, disabled: readOnly })] : [])];
        break;
      }
      case "list": {
        const l = schema.lists.find(v => v.key === top.key), spots = (l ? m[l.key] : []) as Spot[];
        if (l) entries = [...placeRows(`a new ${l.label}`, `list:${l.key}`), { separator: true },
          ...spots.map((s, i) => submenu(`spot:${i}`, `${l.label} ${i + 1}`, { kind: "spot", key: l.key, index: i }, { meta: `${(s.heading ?? 0).toFixed(0)}°`, description: coords(s) }))];
        break;
      }
      case "spot": {
        const l = schema.lists.find(v => v.key === top.key), i = top.index ?? 0, spots = (l ? m[l.key] : []) as Spot[], s = spots[i];
        const put = (q: Spot) => update({ [l!.key]: spots.map((v, j) => j === i ? q : v) });
        if (l && s) entries = [...placeRows(`${l.label} ${i + 1}`, `list:${l.key}`, { type: "list", key: l.key, index: i + 1, label: `${l.label} ${i + 1}` }),
          numberEntry("heading", "Facing", s.heading ?? 0, heading => put({ ...s, heading }), -36000, 36000, "°", 15),
          ...coordinateRows("spot", s, put),
          item("remove", `Remove ${l.label} ${i + 1}`, () => { update({ [l.key]: spots.filter((_, j) => j !== i) }); pop(); }, { danger: true, disabled: readOnly })];
        break;
      }
      case "choice": {
        const c = schema.choices.find(v => v.key === top.key), picked = (c ? m[c.key] : []) as string[];
        if (c) entries = c.options.map(o => toggle(`option:${o.id}`, o.label, picked.includes(o.id), on => update({ [c.key]: on ? [...picked, o.id] : picked.filter(id => id !== o.id) }), c.about));
        break;
      }
      case "issues":
        entries = issues.map((text, i) => item(`issue:${i}`, text, undefined, { disabled: true, description: text }));
        break;
      case "delete":
        entries = [item("cancel", "Keep this map", pop, { disabled: busy || unconfirmed === "delete" }),
          item("confirmDelete", unconfirmed === "delete" ? "Check deletion" : "Confirm deletion", remove, { danger: true, disabled: busy, description: "It leaves the rooms at once and never comes back, not even from the import. A match in progress finishes on it." })];
        break;
      case "discard":
        entries = [item("cancel", "Keep editing", pop), item("discard", "Discard draft", clearDraft, { danger: true, description: "Unsaved changes are lost. The saved map stays as it was." })];
        break;
      default: break;
    }
  }
  if (top.kind !== "games" && top.kind !== "discard" && top.kind !== "delete") entries.push({ separator: true }, item("back", "Back", back, { icon: "chevron-left", disabled: busy || !!unconfirmed,
    description: top.kind === "map" && changed ? "Unsaved changes will ask for confirmation." : "Return to the previous menu." }));
  if (busy) entries.push(item("working", "Waiting…", undefined, { disabled: true }));
  const selected = entries.findIndex(entry => entry.id === top.selected && isPickable(entry));
  const index = selected >= 0 ? selected : Math.max(0, entries.findIndex(isPickable));
  const shown = entries.map(entry => editing && editing.id === entry.id ? { ...entry, type: "item" as const, meta: undefined,
    description: `${editing.replace ? "[" : ""}${editing.value}${editing.replace ? "]" : "▏"}  ·  ENTER APPLY / ESC CANCEL` } : entry);
  const placing = top.kind === "point" || top.kind === "list" || top.kind === "spot";
  const preview = draft ? drawingNote(drawn) : undefined;
  return opened ? <>
    {!world && <section className="rp-support safezone-menu mission-editor" aria-label="Map editor"><div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title="LIGHT/RP" subtitle={subtitle} tag={draft ? changed ? "DRAFT" : draft.id ? "SAVED" : "NEW" : "STAFF"} items={shown} index={index} width={380} visibleRows={10}
        path={["ADMIN", "MAPS", ...(game ? [game.label.toUpperCase()] : []), ...stack.slice(2).map(page => page.kind.toUpperCase())]}
        active={!editing && !busy} onIndexChange={next => setStack(previous => previous.map((page, i) => i === previous.length - 1 ? { ...page, selected: entries[next]?.id } : page))}
        onSelect={(_, next) => entries[next]?.run?.()} onChange={(_, next, patch) => entries[next]?.change?.(patch)} onBack={back}
        footer={editing ? <><span>TYPE VALUE</span><span>ENTER APPLY</span><span>ESC CANCEL</span><span>CTRL+A SELECT ALL</span></>
          : <><span>↑↓ MOVE</span><span>←→ CHANGE</span><span>ENTER SELECT</span><span>BKSP / ESC BACK</span>{draft && <><span>F9 BUILD MODE</span>{placing && <span>F11 AT MY FEET</span>}</>}</>} />
      {error && <p className="rp-support__error" role="alert">{error}</p>}{feedback && !error && <p className="rp-support__success" role="status">{feedback}</p>}
      {preview && <p className="mission-build__brush" role="status"><span>PREVIEW</span>{preview}</p>}
    </div></section>}
    {world && draft && schema && activeTool && <BuildStrip title={draft.name} tools={tools} tool={activeTool.id} help={toolHelp(schema, draft, { ...build, tool: activeTool.id })}
      carrying={build.carrying ? build.carrying.label ?? "" : undefined} hovered={hovered?.label} pickUp={activeTool.kind === "move" && !build.carrying}
      message={buildNote.message} error={buildNote.error || error}>
      {(activeTool.kind === "point" || activeTool.kind === "list" || activeTool.kind === "move") && <p className="mission-build__brush"><span>FACING</span>{build.heading == null ? "AUTO · faces you" : `${build.heading}°`}</p>}
      {preview && <p className="mission-build__brush" role="status"><span>PREVIEW</span>{preview}</p>}
    </BuildStrip>}
  </> : null;
}
