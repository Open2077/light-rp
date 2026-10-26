import { useCallback, useEffect, useRef, useState } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { mutationKey, request, ZoneRequestTimeout } from "./api";
import { clone, extraRuleDefaults, EXTRA_RESTRICTIONS, fresh, invalid, normalizeZone, SHAPES, shapeName, type Capture, type Listing, type Permissions, type Wire, type Zone } from "./model";
import "@/features/support/support.css";
import "./safezones.css";

type Page = { kind: "list" | "zone" | "geometry" | "rules" | "vertices" | "vertex" | "discard" | "delete"; selected?: string };
type Entry = RageMenuItem & { run?: () => void; change?: (patch: Partial<RageMenuItem>) => void };
type TextEdit = { id: string; value: string; replace: boolean; numeric: boolean; commit: (value: string) => string | undefined };
const NO_PERMISSIONS: Permissions = { view: false, edit: false, publish: false, delete: false };
const STEPS = [0.1, 1, 5, 10];
const message = (error: unknown) => error instanceof Error ? error.message : "The request failed.";
const rounded = (value: number) => Math.round(value * 1000) / 1000;

/** Reuses the keyboard shell used by /admin and F1, without an authoring form. */
export function Safezones() {
  const [opened, setOpened] = useState(false), [zones, setZones] = useState<Zone[]>([]);
  const [ready, setReady] = useState(false), [permissions, setPermissions] = useState(NO_PERMISSIONS);
  const [draft, setDraft] = useState<Zone>(), [original, setOriginal] = useState("");
  const [session, setSession] = useState(""), [world, setWorld] = useState(false), [vertex, setVertex] = useState(0);
  const [stack, setStack] = useState<Page[]>([{ kind: "list" }]), [query, setQuery] = useState("");
  const [editing, setEditing] = useState<TextEdit>(), [stepIndex, setStepIndex] = useState(1);
  const [busy, setBusy] = useState(false), [unconfirmed, setUnconfirmed] = useState<"save" | "delete">();
  const [error, setError] = useState(""), [feedback, setFeedback] = useState("");
  const [captureMode, setCaptureMode] = useState<"append" | "replace">("append");
  const live = useRef(true), working = useRef(false), generation = useRef(-1), menu = useRef<HTMLDivElement>(null);
  const mutation = useRef<{ signature: string; key: string }>();
  const current = useRef({ opened, draft, session, vertex, captureMode, unconfirmed, canEdit: permissions.edit, typing: !!editing });
  current.current = { opened, draft, session, vertex, captureMode, unconfirmed, canEdit: permissions.edit, typing: !!editing };
  const top = stack[stack.length - 1]!, locked = busy || !!unconfirmed, readOnly = locked || !permissions.edit;
  const changed = !!draft && JSON.stringify(draft) !== original;
  const update = (patch: Partial<Zone>) => setDraft(previous => previous ? { ...previous, ...patch } : previous);
  const push = (kind: Page["kind"]) => { setError(""); setStack(previous => [...previous, { kind }]); };
  const pop = () => { setError(""); setStack(previous => previous.length > 1 ? previous.slice(0, -1) : previous); };
  const refresh = useCallback(async () => {
    const data = await request<Listing>("list");
    if (!live.current) return;
    setZones(Array.isArray(data.zones) ? data.zones.map(normalizeZone) : []);
    setPermissions(data.permissions ?? NO_PERMISSIONS); setReady(data.ready === true);
  }, []);
  const run = useCallback(async (task: () => Promise<void>) => {
    if (working.current) return;
    working.current = true; setBusy(true); setError(""); setFeedback("");
    try { await task(); } catch (reason) { if (live.current) setError(message(reason)); }
    finally { working.current = false; if (live.current) setBusy(false); }
  }, []);
  const clearDraft = useCallback(() => {
    setDraft(undefined); setOriginal(""); setSession(""); setWorld(false); setEditing(undefined);
    setStack([{ kind: "list" }]); setUnconfirmed(undefined); mutation.current = undefined;
    emit(PAGE_EVENTS.safezones, { operation: "preview", zone: null });
    emit(PAGE_EVENTS.safezones, { operation: "cancel" });
  }, []);
  const close = useCallback(() => {
    clearDraft(); setOpened(false); setError(""); emit(PAGE_EVENTS.safezones, { operation: "close" });
  }, [clearDraft]);
  const capture = useCallback(() => run(async () => {
    const state = current.current;
    if (!state.draft || !state.opened || state.unconfirmed || !state.canEdit || state.typing) return;
    if (state.draft.shape === "poly" && state.captureMode === "append" && state.draft.points.length >= 32) throw new Error("A polygon can have at most 32 vertices.");
    const data = await request<Capture>("capture", { session: state.session || undefined });
    if (!live.current || !current.current.opened) return;
    if (data.bucket !== state.draft.bucket) throw new Error("Your instance changed. Close this draft and start a new session.");
    setSession(data.session);
    setDraft(previous => {
      if (!previous) return previous;
      if (previous.shape !== "poly") return { ...previous, center: data.position };
      const points = [...previous.points];
      if (state.captureMode === "replace" && points[state.vertex]) points[state.vertex] = data.position;
      else if (points.length < 32) { points.push(data.position); setVertex(points.length - 1); }
      return { ...previous, points };
    });
  }), [run]);
  useEffect(() => {
    live.current = true;
    const off = on<Wire>(PAGE_EVENTS.safezones, event => {
      if (event.kind === "open") {
        useStore.getState().closeDialog(); useStore.getState().closeMenu();
        setOpened(true); setWorld(false); setError(""); void run(refresh);
      } else if (event.kind === "snapshot") {
        const revision = event.generation ?? 0;
        if (revision < generation.current) return;
        generation.current = revision; setReady(event.ready === true);
        setZones(Array.isArray(event.zones) ? event.zones.map(normalizeZone) : []);
        if (!event.ready) useStore.getState().setSafezone(undefined);
      } else if (event.kind === "presence") {
        const zone = event.ready === true ? event.zone : undefined;
        useStore.getState().setSafezone(zone ? { id: zone.id, label: zone.label, blockRun: zone.blockRun ?? false, blockShoot: zone.blockShoot ?? true, ...extraRuleDefaults(zone) } : undefined);
        setReady(event.ready === true);
      } else if (event.kind === "editor" && current.current.opened && !current.current.typing) setWorld(event.mode === "world");
      else if (event.kind === "captureKey") void capture();
      else if (event.kind === "invalidate") {
        close(); useStore.getState().pushNotice({ kind: "warning", title: "Safe zones", body: event.error || "Your editing session ended.", durationMs: 8000 });
      }
    });
    return () => { live.current = false; off(); useStore.getState().setSafezone(undefined); emit(PAGE_EVENTS.safezones, { operation: "close" }); };
  }, [capture, close, refresh, run]);
  useEffect(() => {
    if (!opened) return;
    emit(PAGE_EVENTS.safezones, { operation: "input", mode: world ? "world" : editing ? "typing" : "menu" });
    if (!world) menu.current?.focus();
  }, [opened, world, !!editing]);
  useEffect(() => { if (opened) emit(PAGE_EVENTS.safezones, { operation: "preview", zone: draft ?? null }); }, [draft, opened]);
  useEffect(() => {
    if (!opened || !session) return;
    const timer = window.setInterval(() => { void request("heartbeat", { session: current.current.session }).catch(reason => { if (live.current && current.current.opened) setError(message(reason)); }); }, 60000);
    return () => window.clearInterval(timer);
  }, [opened, session]);
  // Full keyboard capture while typing a selected row; no input, form or cursor.
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
        setEditing(previous => previous ? { ...previous, value: (previous.replace ? character : previous.value + character).slice(0, previous.numeric ? 24 : 80), replace: false } : previous);
      } else if (event.key === "Tab") event.preventDefault();
    };
    window.addEventListener("keydown", handler); return () => window.removeEventListener("keydown", handler);
  }, [opened, editing]);
  const edit = (source?: Zone, duplicate = false) => run(async () => {
    if (source && !permissions.edit) {
      const next = clone(source); setDraft(next); setOriginal(JSON.stringify(next)); setSession("");
      setVertex(0); setWorld(false); setStack([{ kind: "list" }, { kind: "zone" }]); return;
    }
    if (!duplicate) await request("cancel");
    const data = await request<Capture>("capture");
    if (!live.current || !current.current.opened) return;
    if (source && source.bucket !== data.bucket) throw new Error("Enter this zone's instance before editing it.");
    const next = source ? clone(source) : fresh(data);
    if (duplicate) { next.id = ""; next.revision = 0; next.label = `${next.label.slice(0, 72)} copy`; }
    setDraft(next); setOriginal(source && !duplicate ? JSON.stringify(next) : ""); setSession(data.session);
    setVertex(0); setWorld(false); setStack([{ kind: "list" }, { kind: "zone" }]); setEditing(undefined);
    setCaptureMode("append"); mutation.current = undefined;
  });
  const publish = () => run(async () => {
    if (!draft) return;
    const reason = invalid(draft); if (reason) throw new Error(reason);
    const signature = JSON.stringify({ operation: "save", zone: draft, session });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    let result: { zone: Zone };
    try { result = await request<{ zone: Zone }>("save", { zone: draft, baseRevision: draft.revision, mutation: mutation.current.key, session }); }
    catch (reason) { if (reason instanceof ZoneRequestTimeout) setUnconfirmed("save"); throw reason; }
    if (!live.current) return;
    const saved = normalizeZone(result.zone); setDraft(saved); setOriginal(JSON.stringify(saved));
    mutation.current = undefined; setUnconfirmed(undefined); setFeedback("Zone saved. Its published settings are now active."); await refresh();
  });
  const remove = () => run(async () => {
    if (!draft?.id) return;
    const signature = JSON.stringify({ operation: "delete", id: draft.id, revision: draft.revision, session });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    try { await request("delete", { id: draft.id, baseRevision: draft.revision, mutation: mutation.current.key, session }); }
    catch (reason) { if (reason instanceof ZoneRequestTimeout) setUnconfirmed("delete"); throw reason; }
    if (!live.current) return;
    clearDraft(); setFeedback("Zone deleted."); await refresh();
  });
  const back = () => {
    if (working.current || unconfirmed) return;
    if (editing) { setEditing(undefined); return; }
    if (top.kind === "zone") { if (changed) push("discard"); else clearDraft(); }
    else if (top.kind === "list") close();
    else { if (top.kind === "vertex") setCaptureMode("append"); pop(); }
  };
  const item = (id: string, text: string, run?: () => void, options: Partial<Entry> = {}): Entry => ({ id, text, run, ...options });
  const submenu = (id: string, text: string, next: Page["kind"], options: Partial<Entry> = {}): Entry => item(id, text, () => push(next), { type: "submenu", ...options });
  const textEntry = (id: string, text: string, value: string, commit: (value: string) => string | undefined, disabled = false): Entry => item(id, text, () => {
    if (disabled) return;
    setError(""); setEditing({ id, value, replace: true, numeric: false, commit });
  }, { meta: value || "EMPTY", disabled: locked || disabled && permissions.edit, description: disabled && !permissions.edit ? `Read only. ${value}` : "Enter edits this row. Type, then Enter applies or Escape cancels. Ctrl+A selects all." });
  const numberEntry = (id: string, text: string, value: number, change: (value: number) => void, min: number, max: number, disabled = false, unit = "m"): Entry => item(id, text, () => {
    if (readOnly || disabled) return;
    setError(""); setEditing({ id, value: String(value), replace: true, numeric: true, commit: input => {
      const n = input.trim() === "" ? NaN : Number(input);
      if (!Number.isFinite(n) || n < min || n > max) return `Enter a number from ${min} to ${max}.`;
      change(rounded(n)); return undefined;
    } });
  }, { type: "slider", value, min, max, step: STEPS[stepIndex], unit, disabled: locked || disabled,
    change: patch => { if (!readOnly && patch.value != null) change(rounded(patch.value)); }, description: !permissions.edit ? `Read only. ${value} ${unit}.` : `Left/right adjusts by ${STEPS[stepIndex]} ${unit}. Enter types an exact value on this row.` });
  const toggle = (id: string, text: string, checked: boolean, change: (checked: boolean) => void, description: string): Entry => item(id, text, () => { if (!readOnly) change(!checked); }, { type: "checkbox", checked, disabled: locked, change: patch => { if (!readOnly) change(patch.checked === true); }, description: `${!permissions.edit ? "Read only. " : ""}${description}` });

  let entries: Entry[] = [], subtitle = "SAFE ZONES";
  const problem = draft ? invalid(draft) : undefined;
  if (top.kind === "list") {
    const filtered = zones.filter(zone => zone.label.toLocaleLowerCase().includes(query.toLocaleLowerCase()));
    entries = [item("create", "Create a zone", () => { void edit(); }, { icon: "plus", disabled: readOnly || !permissions.publish || !ready, description: "Start a private draft at your server-observed position. Nothing changes until publication." }),
      textEntry("search", "Search zones", query, value => { setQuery(value.trim()); return undefined; }, busy), { separator: true },
      ...filtered.map(zone => item(`zone:${zone.id}`, zone.label, () => { void edit(zone); }, { icon: "shield", meta: zone.enabled ? "ACTIVE" : "INACTIVE", disabled: busy, description: `${shapeName[zone.shape]} · instance ${zone.bucket} · revision ${zone.revision}` })),
      ...(!filtered.length ? [item("empty", ready ? "No matching zones" : "Protection unavailable", undefined, { disabled: true })] : []), { separator: true },
      item("refresh", "Refresh", () => { void run(refresh); }, { icon: "activity", disabled: busy }), item("close", "Close menu", close, { icon: "x", disabled: busy })];
  } else if (draft) {
    subtitle = draft.label;
    if (top.kind === "zone") {
      entries = [textEntry("name", "Name", draft.label, value => { const label = value.trim(); if (!label || label.length > 80) return "Choose a name of 1–80 characters."; update({ label }); return undefined; }, readOnly),
        item("shape", "Shape", undefined, { type: "list", options: SHAPES.map(shape => shapeName[shape]), index: SHAPES.indexOf(draft.shape), disabled: locked, change: patch => { const shape = SHAPES[patch.index ?? 0]; if (!readOnly && shape) { update({ shape }); setCaptureMode("append"); } }, description: !permissions.edit ? "Read only." : "Use left/right to choose a cylinder, oriented box or polygon." }),
        toggle("enabled", "Zone enabled", draft.enabled, enabled => update({ enabled }), "Applied only after publication. Overlapping active zones keep their own protection."),
        submenu("geometry", "Geometry and placement", "geometry", { description: "Dimensions, centre, height and exact coordinates." }),
        ...(draft.shape === "poly" ? [submenu("vertices", "Polygon vertices", "vertices", { meta: `${draft.points.length} / 32`, description: "Capture vertices at your feet, then adjust any point from its submenu." })] : []),
        submenu("rules", "Restrictions", "rules", { description: "Player controls blocked inside the published zone. Weapon switching remains available." }),
        item("world", "Place in the world", () => setWorld(true), { icon: "footprints", description: "F9 returns to the menu. F10 captures your position. Only you can see the preview." }), { separator: true },
        item("save", unconfirmed === "save" ? "Check publication" : "Publish zone", publish, { icon: "check", disabled: busy || unconfirmed === "delete" || !permissions.edit || !permissions.publish || !!problem || !ready, description: problem || "Validate and save this draft before updating the live protection." }),
        item("duplicate", "Duplicate zone", () => { void edit(draft, true); }, { disabled: readOnly || !permissions.publish, description: "Create an independent draft from these settings." }),
        submenu("delete", "Delete zone", "delete", { danger: true, disabled: readOnly || !draft.id || !permissions.delete, description: "Review the deletion before removing this zone's protection." })];
    } else if (top.kind === "geometry") {
      entries = [item("step", "Adjustment step", undefined, { type: "list", options: STEPS.map(step => `${step} m / °`), index: stepIndex, change: patch => setStepIndex(patch.index ?? 1), description: "Changes the left/right increment. Enter on any number for exact keyboard entry." }),
        toggle("fullHeight", "Full height (above and below)", draft.fullHeight, fullHeight => update({ fullHeight }), "Ignore floor and ceiling at every altitude. Their saved values remain available when turned off."),
        numberEntry("floor", "Floor Z", draft.minZ, minZ => update({ minZ }), -100000, 100000, draft.fullHeight), numberEntry("ceiling", "Ceiling Z", draft.maxZ, maxZ => update({ maxZ }), -100000, 100000, draft.fullHeight),
        ...(draft.shape === "circle" ? [numberEntry("radius", "Radius", draft.radius, radius => update({ radius }), 0.5, 250)] : []),
        ...(draft.shape === "box" ? [numberEntry("length", "Length", draft.length, length => update({ length }), 0.5, 500), numberEntry("width", "Width", draft.width, width => update({ width }), 0.5, 500), numberEntry("heading", "Heading", draft.heading, heading => update({ heading }), -36000, 36000, false, "°")] : []),
        ...(draft.shape !== "poly" ? [item("capture", "Set centre at my feet", () => { void capture(); }, { icon: "map-pin", disabled: readOnly }), ...(["x", "y", "z"] as const).map(axis => numberEntry(`centre:${axis}`, `Centre ${axis.toUpperCase()}`, draft.center[axis], value => update({ center: { ...draft.center, [axis]: value } }), -100000, 100000))] : [submenu("vertices", "Edit polygon vertices", "vertices", { meta: String(draft.points.length) })])];
    } else if (top.kind === "rules") {
      entries = [toggle("blockRun", "Block running", draft.blockRun, blockRun => update({ blockRun }), "Keep players at walking speed; slower walk preferences are preserved."),
        toggle("blockShoot", "Block shooting", draft.blockShoot, blockShoot => update({ blockShoot }), "Block the native fire action. Turning this off never disables server PvP protection."),
        ...EXTRA_RESTRICTIONS.map(rule => toggle(rule.key, rule.label, draft[rule.key], checked => update({ [rule.key]: checked }), rule.key === "blockConsumables" ? "Blocks native healing/inhaler hotkeys only. RP food and drink items remain usable." : rule.key === "blockWeaponWheel" ? "Blocks the weapon wheel. Direct weapon switching remains available." : "Applied after publication. Overlapping active restrictions combine."))];
    } else if (top.kind === "vertices") {
      entries = [item("add", "Add vertex at my feet", () => { setCaptureMode("append"); current.current.captureMode = "append"; void capture(); }, { icon: "plus", disabled: readOnly || draft.points.length >= 32, description: "F10 also adds a point. Walk around the outline in order." }),
        item("undo", "Undo last vertex", () => { update({ points: draft.points.slice(0, -1) }); setVertex(previous => Math.max(0, Math.min(previous, draft.points.length - 2))); }, { disabled: readOnly || !draft.points.length }), { separator: true },
        ...draft.points.map((point, index) => item(`vertex:${index}`, `Vertex ${index + 1}`, () => { setVertex(index); setCaptureMode("replace"); push("vertex"); }, { type: "submenu", meta: `${point.x.toFixed(1)}, ${point.y.toFixed(1)}`, description: `X ${point.x.toFixed(2)} · Y ${point.y.toFixed(2)} · Z ${point.z.toFixed(2)}. Edit coordinates or capture a replacement.` }))];
    } else if (top.kind === "vertex") {
      const point = draft.points[vertex];
      if (point) entries = [item("capture", `Replace vertex ${vertex + 1} at my feet`, () => { void capture(); }, { icon: "map-pin", disabled: readOnly, description: "F10 replaces this selected vertex while its submenu is open." }),
        ...(["x", "y", "z"] as const).map(axis => numberEntry(`vertex:${axis}`, axis.toUpperCase(), point[axis], value => update({ points: draft.points.map((p, index) => index === vertex ? { ...p, [axis]: value } : p) }), -100000, 100000)),
        item("removeVertex", "Remove this vertex", () => { update({ points: draft.points.filter((_, index) => index !== vertex) }); setVertex(0); setCaptureMode("append"); pop(); }, { danger: true, disabled: readOnly, description: "Changes only the draft. A published polygon still needs at least three vertices." })];
    } else if (top.kind === "delete") entries = [item("cancel", "Keep this zone", pop, { disabled: busy || unconfirmed === "delete" }), item("confirmDelete", unconfirmed === "delete" ? "Check deletion" : "Confirm deletion", remove, { danger: true, disabled: busy || !permissions.delete || !permissions.edit, description: "Remove this zone after server confirmation. Other overlapping zones keep their protection." })];
    else if (top.kind === "discard") entries = [item("cancel", "Keep editing", pop), item("discard", "Discard draft", clearDraft, { danger: true, description: "Discard unpublished changes. The last saved zone remains unchanged." })];
    if (top.kind !== "discard" && top.kind !== "delete") entries.push({ separator: true }, item("back", "Back", back, { icon: "chevron-left", disabled: busy || !!unconfirmed, description: top.kind === "zone" && changed ? "Unpublished changes will ask for confirmation." : "Return to the previous menu." }));
  }
  if (busy) entries.push(item("working", "Waiting for the server…", undefined, { disabled: true }));
  const selected = entries.findIndex(entry => entry.id === top.selected && isPickable(entry));
  const index = selected >= 0 ? selected : Math.max(0, entries.findIndex(isPickable));
  const visibleEntries = entries.map(entry => editing && editing.id === entry.id ? { ...entry, type: "item" as const, meta: undefined, description: `${editing.replace ? "[" : ""}${editing.value}${editing.replace ? "]" : "▏"}  ·  ENTER APPLY / ESC CANCEL` } : entry);
  return opened ? <>
    {!world && <section className="rp-support safezone-menu" aria-label="Safe zone menu"><div className="rp-support__menu" ref={menu} tabIndex={-1}>
      <RageMenu title="LIGHT/RP" subtitle={subtitle} tag={draft ? !permissions.edit ? "READ ONLY" : changed ? "DRAFT" : "SAVED" : "STAFF"} items={visibleEntries} index={index} width={350} visibleRows={9} path={["ADMIN", "SAFE ZONES", ...stack.slice(1).map(page => page.kind.toUpperCase())]}
        active={!editing && !busy} onIndexChange={next => setStack(previous => previous.map((page, i) => i === previous.length - 1 ? { ...page, selected: entries[next]?.id } : page))}
        onSelect={(_, next) => entries[next]?.run?.()} onChange={(_, next, patch) => entries[next]?.change?.(patch)} onBack={back}
        footer={editing ? <><span>TYPE VALUE</span><span>ENTER APPLY</span><span>ESC CANCEL</span><span>CTRL+A SELECT ALL</span></> : <><span>↑↓ MOVE</span><span>←→ CHANGE</span><span>ENTER SELECT</span><span>BKSP / ESC BACK</span>{draft && <><span>F9 WORLD / MENU</span><span>F10 {draft.shape === "poly" ? captureMode === "replace" ? "REPLACE VERTEX" : "ADD VERTEX" : "CAPTURE CENTRE"}</span></>}</>} />
      {error && <p className="rp-support__error" role="alert">{error}</p>}{feedback && !error && <p className="rp-support__success" role="status">{feedback}</p>}
    </div></section>}
    {world && <div className="safezone-world-hint"><b>{draft?.label ?? "SAFE ZONES"}</b><span>PRIVATE PREVIEW · F9 MENU{draft ? ` · F10 ${draft.shape === "poly" ? captureMode === "replace" ? "REPLACE VERTEX" : "ADD VERTEX" : "CAPTURE CENTRE"}` : ""}</span>{error && <small>{error}</small>}</div>}
  </> : null;
}
