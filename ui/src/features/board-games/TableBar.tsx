import { useEffect, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import { emit, on } from "@/bridge/open77";
import { formatMoney } from "@/bridge/money";
import { Button, Keycap, cx } from "@/design/components";
import { useStore } from "@/state/store";
import { asList } from "./asList";
import "./table-bar.css";

/* Seated at a table (board games and casino tables): the Lua client runs a
   scripted camera, freezes the character and hands the page the cursor. The
   page draws a transparent layer that forwards the pointer to Lua (picking on
   the 3D table) and a compact bar at the bottom with the contextual controls.
   Lua owns every rule: the bar only shows what the view lists and sends back
   which control was used.
   Escape leaves the table (or cancels a placement): Lua has the page hold the
   keyboard with gameplay input kept and Escape consumed, so the key arrives
   here and the game's pause menu does not open. The table keys (E, H, the
   arrows, PgUp/PgDn) are forwarded to Lua too, which also reads them from
   the game: holding the keyboard must never make them dead.
   Free ("free" in the view): the player plays from the character with the
   crosshair; the bar is an overlay (no pointer layer, the gameplay HUD stays)
   until the cursor key (`free.key`) hands the page the cursor.
   Placement ("mode: placement"): the same bar with the placement controls;
   the pointer layer forwards presses and drags (Lua moves the preview where
   the cursor ray meets the ground). */

export interface TableAction { key: string; label: string; enabled: boolean; primary?: boolean; keycap?: string; title?: string }
export interface TableCameraView { key: string; label: string }
export interface TableChip { value: number; min: number; max: number; presets: number[]; label: string }
export interface TableView {
  active?: boolean;
  kind?: string;
  boardId?: string | number;
  title?: string;
  status?: string;
  tone?: "turn" | "result" | "warn";
  detail?: string;
  hint?: string;
  countdownMs?: number;
  chip?: TableChip;
  target?: string;
  actions?: TableAction[] | Record<string, TableAction>;
  views?: TableCameraView[] | Record<string, TableCameraView>;
  view?: string;
  orbit?: boolean;
  /** Free: playing from the character. `cursor`: the page has the cursor; `key`: the key that toggles it. */
  free?: { cursor?: boolean; key?: string };
  /** "placement": placing a table (the preview follows the cursor on the ground). */
  mode?: "placement";
  camera?: boolean;
  leaving?: number;
  /** Placing a table (with mode "placement"): Escape cancels. */
  placing?: boolean;
}

/** The table keys Lua uses, by KeyboardEvent.code (layout independent). */
const TABLE_KEYS: Record<string, string> = {
  KeyE: "E", KeyH: "H", ArrowLeft: "LEFT", ArrowRight: "RIGHT", PageUp: "PAGEUP", PageDown: "PAGEDOWN",
};

type Edge = "pressed" | "released" | "rightPressed" | "rightReleased";
const MOVE_INTERVAL_MS = 16;

/** The preset below / above `value` (nearest when `value` is not a preset),
    within the chip's limits. */
export function chipSteps(chip: TableChip): { lower?: number; higher?: number } {
  const value = Number(chip.value) || 0;
  const min = Number.isFinite(chip.min) ? chip.min : -Infinity;
  const max = Number.isFinite(chip.max) ? chip.max : Infinity;
  const presets = Array.from(new Set(asList<number>(chip.presets).map(Number)))
    .filter(p => Number.isFinite(p) && p >= min && p <= max)
    .sort((a, b) => a - b);
  let lower: number | undefined;
  let higher: number | undefined;
  for (const p of presets) {
    if (p < value) lower = p;
    else if (p > value && higher === undefined) higher = p;
  }
  return { lower, higher };
}

function isTyping(target: EventTarget | null): boolean {
  const el = target as HTMLElement | null;
  if (!el) return false;
  return el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT" || el.isContentEditable;
}

export function TableBar() {
  const [view, setView] = useState<TableView>({});
  const [receivedAt, setReceivedAt] = useState(0);
  const [now, setNow] = useState(() => performance.now());
  const lastMove = useRef(0);

  useEffect(() => {
    const off = on<TableView>("lightrp:boardGames:view", next => {
      const v = next && typeof next === "object" ? next : {};
      setView(v);
      const t = performance.now();
      setReceivedAt(t);
      setNow(t);
      // Free keeps the gameplay HUD: the player is on the character.
      useStore.getState().setBoardGamesActive(!!v.active && !v.free);
    });
    return () => { off(); useStore.getState().setBoardGamesActive(false); };
  }, []);

  const active = !!view.active;
  const counting = active && typeof view.countdownMs === "number" && view.countdownMs > 0;

  // Count down locally between two views (Lua resends every ~200 ms).
  useEffect(() => {
    if (!counting) return;
    const id = window.setInterval(() => setNow(performance.now()), 250);
    return () => window.clearInterval(id);
  }, [counting, receivedAt]);

  // Escape (outside a text field) leaves the table, or cancels a placement.
  // The table keys go to Lua as they are pressed and released.
  const listening = active || !!view.placing;
  useEffect(() => {
    if (!listening) return;
    const held = new Set<string>();
    const onKey = (event: KeyboardEvent) => {
      if (isTyping(event.target)) return;
      const down = event.type === "keydown";
      if (event.key === "Escape") {
        if (!down || event.repeat) return;
        event.preventDefault();
        event.stopPropagation();
        emit("lightrp:boardGames:leave", { key: "escape" });
        return;
      }
      const key = TABLE_KEYS[event.code];
      if (!key || event.ctrlKey || event.altKey || event.metaKey) return;
      if (key !== "E" && key !== "H") event.preventDefault(); // no page scroll on arrows / PgUp
      if (down) held.add(key); else held.delete(key);
      emit("lightrp:boardGames:key", { key, down, ...(down && event.repeat ? { repeat: true } : {}) });
    };
    // A key held while the page loses the keyboard never sticks.
    const release = () => { held.forEach(key => emit("lightrp:boardGames:key", { key, down: false })); held.clear(); };
    window.addEventListener("keydown", onKey);
    window.addEventListener("keyup", onKey);
    window.addEventListener("blur", release);
    return () => {
      window.removeEventListener("keydown", onKey);
      window.removeEventListener("keyup", onKey);
      window.removeEventListener("blur", release);
      release();
    };
  }, [listening]);

  // Notices stay where they are but above the pointer layer.
  useEffect(() => {
    document.documentElement.toggleAttribute("data-table-bar", active);
    return () => document.documentElement.removeAttribute("data-table-bar");
  }, [active]);

  if (!active) return null;

  const actions = asList<TableAction>(view.actions).filter(a => a && typeof a.key === "string");
  const views = asList<TableCameraView>(view.views).filter(v => v && typeof v.key === "string");
  const cameraLabel = views.find(v => v.key === view.view)?.label ?? "Free";
  const chip = view.chip && typeof view.chip === "object" ? view.chip : undefined;
  const steps = chip ? chipSteps(chip) : {};
  const secondsLeft = counting ? Math.max(0, Math.ceil(((view.countdownMs ?? 0) - (now - receivedAt)) / 1000)) : undefined;
  const leaving = typeof view.leaving === "number";
  const subline = [view.detail, view.hint].filter(Boolean).join(" · ");
  const free = view.free && typeof view.free === "object" ? view.free : undefined;
  const freeKey = (free?.key || "H").toUpperCase();
  // Free with the crosshair: the bar is a picture, the game keeps the mouse.
  const overlay = !!free && !free.cursor;
  const placement = view.mode === "placement";

  const pointer = (event: ReactPointerEvent, edge?: Edge) => {
    const t = performance.now();
    if (!edge && t - lastMove.current < MOVE_INTERVAL_MS) return;
    if (!edge) lastMove.current = t;
    emit("lightrp:boardGames:pointer", {
      x: Math.max(0, Math.min(1, event.clientX / window.innerWidth)),
      y: Math.max(0, Math.min(1, event.clientY / window.innerHeight)),
      ...(edge ? { [edge]: true } : {}),
    });
  };
  // The bar is not the table: clicks on it never reach the picking.
  const block = (event: ReactPointerEvent) => {
    event.stopPropagation();
    if (event.type === "pointermove") {
      const t = performance.now();
      if (t - lastMove.current < MOVE_INTERVAL_MS) return;
      lastMove.current = t;
    }
    emit("lightrp:boardGames:pointer", { blocked: true });
  };

  if (overlay) {
    return <div className="table-layer table-layer--overlay" data-kind={view.kind} data-view="free">
      <span className="table-crosshair" aria-hidden="true" />
      <section className={cx("table-bar", leaving && "table-bar--leaving")} aria-label="Table controls">
        <div className="table-bar__notes">
          {leaving ? <p className="table-bar__warning" role="alert">Too far from the table — step back or you leave your seat.</p>
            : <p className="table-bar__orbit table-bar__free" aria-label="Free view keys">
              <span>Crosshair: aim</span><span>Click: play</span>
              <span><Keycap size="sm">{freeKey}</Keycap> cursor for the bar</span>
              <span><Keycap size="sm">ESC</Keycap> leave</span>
            </p>}
        </div>
        <div className="table-bar__row">
          <div className="table-bar__info">
            <p className="table-bar__head">
              <span className="table-bar__title">{view.title || "Table"}</span>
              {view.status && <span className={cx("table-bar__status", view.tone && `table-bar__status--${view.tone}`)} role="status">{view.status}</span>}
              {secondsLeft !== undefined && <span className="table-bar__countdown" aria-label="Time left">{secondsLeft} s</span>}
            </p>
            {subline && <p className="table-bar__sub" title={subline}>{subline}</p>}
          </div>
          {view.target && <span className="table-bar__target" title={view.target}>{view.target}</span>}
          {chip && <span className="table-bar__stack table-bar__chip-value"><small>{chip.label || "Chip"}</small><b>{formatMoney(chip.value)}</b></span>}
        </div>
      </section>
    </div>;
  }

  return <div className="table-layer o77-interactive" data-kind={view.kind} data-view={free ? "free" : placement ? "placement" : undefined}
    onContextMenu={event => event.preventDefault()}
    onPointerMove={event => pointer(event)}
    onPointerDown={event => {
      if (event.button !== 0 && event.button !== 2) return;
      event.currentTarget.setPointerCapture(event.pointerId);
      pointer(event, event.button === 0 ? "pressed" : "rightPressed");
    }}
    onPointerUp={event => {
      if (event.button !== 0 && event.button !== 2) return;
      pointer(event, event.button === 0 ? "released" : "rightReleased");
    }}
    onPointerCancel={event => { pointer(event, "released"); pointer(event, "rightReleased"); }}
    onWheel={event => {
      if (!view.orbit || event.deltaY === 0) return;
      emit("lightrp:boardGames:camera", { zoom: Math.sign(event.deltaY) });
    }}>
    <section className={cx("table-bar", leaving && "table-bar--leaving")} aria-label="Table controls"
      onPointerDown={block} onPointerUp={block} onPointerMove={block} onWheel={event => event.stopPropagation()}>
      {(leaving || view.orbit || free || placement) && <div className="table-bar__notes">
        {leaving && <p className="table-bar__warning" role="alert">Too far from the table — step back or you leave your seat.</p>}
        {view.orbit && !leaving && <p className="table-bar__orbit">Right-drag: orbit · Wheel: zoom</p>}
        {free && !leaving && <p className="table-bar__orbit table-bar__free" aria-label="Free view keys">
          <span>Click: play</span>
          <span><Keycap size="sm">{freeKey}</Keycap> back to the crosshair</span>
        </p>}
        {placement && <p className="table-bar__orbit table-bar__free" aria-label="Placement keys">
          <span>Drag: move</span>
          <span><Keycap size="sm">←</Keycap><Keycap size="sm">→</Keycap> turn</span>
          <span><Keycap size="sm">PgUp</Keycap><Keycap size="sm">PgDn</Keycap> height</span>
          <span><Keycap size="sm">E</Keycap> place</span>
        </p>}
      </div>}
      <div className="table-bar__row">
        <div className="table-bar__info">
          <p className="table-bar__head">
            <span className="table-bar__title">{view.title || "Table"}</span>
            {view.status && <span className={cx("table-bar__status", view.tone && `table-bar__status--${view.tone}`)} role="status">{view.status}</span>}
            {secondsLeft !== undefined && <span className="table-bar__countdown" aria-label="Time left">{secondsLeft} s</span>}
          </p>
          {subline && <p className="table-bar__sub" title={subline}>{subline}</p>}
        </div>
        {view.target && <span className="table-bar__target" title={view.target}>{view.target}</span>}
        {chip && <div className="table-bar__chip" role="group" aria-label={chip.label || "Chip"}>
          <Button size="sm" variant="secondary" aria-label="Lower chip" disabled={steps.lower === undefined}
            onClick={() => steps.lower !== undefined && emit("lightrp:boardGames:chip", { amount: steps.lower })}>−</Button>
          <span className="table-bar__stack table-bar__chip-value">
            <small>{chip.label || "Chip"}</small>
            <b>{formatMoney(chip.value)}</b>
          </span>
          <Button size="sm" variant="secondary" aria-label="Raise chip" disabled={steps.higher === undefined}
            onClick={() => steps.higher !== undefined && emit("lightrp:boardGames:chip", { amount: steps.higher })}>+</Button>
        </div>}
        {actions.length > 0 && <div className="table-bar__actions">
          {actions.map(action => <Button key={action.key} size="sm" variant={action.primary ? "primary" : "secondary"}
            aria-label={action.title} title={action.title}
            disabled={!action.enabled} onClick={() => emit("lightrp:boardGames:action", { key: action.key })}>
            {action.label}{action.keycap && <Keycap size="sm" className="table-bar__keycap">{action.keycap}</Keycap>}
          </Button>)}
        </div>}
        <div className="table-bar__end">
          {views.length > 1 && <Button size="sm" variant="ghost" className="table-bar__camera" icon="video"
            aria-label={`Camera: ${cameraLabel}`} title="Switch the camera view"
            onClick={() => emit("lightrp:boardGames:camera", { cycle: true })}>
            <span className="table-bar__stack"><small>Camera</small><b>{cameraLabel}</b></span>
          </Button>}
          <Button size="sm" variant="ghost" onClick={() => emit("lightrp:boardGames:leave", {})}>
            {placement ? "Cancel" : "Leave"} <Keycap size="sm">ESC</Keycap>
          </Button>
        </div>
      </div>
    </section>
  </div>;
}
