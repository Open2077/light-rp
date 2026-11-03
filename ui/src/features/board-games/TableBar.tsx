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
   which control was used. */

export interface TableAction { key: string; label: string; enabled: boolean; primary?: boolean }
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
  camera?: boolean;
  leaving?: number;
}

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
      useStore.getState().setBoardGamesActive(!!v.active);
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

  // Escape belongs to the game's pause menu; Backspace (outside a text field)
  // leaves the table when the page has the keyboard.
  useEffect(() => {
    if (!active) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== "Backspace" || event.repeat || isTyping(event.target)) return;
      event.preventDefault();
      emit("lightrp:boardGames:leave", {});
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active]);

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

  return <div className="table-layer o77-interactive" data-kind={view.kind}
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
      {(leaving || view.orbit) && <div className="table-bar__notes">
        {leaving && <p className="table-bar__warning" role="alert">Too far from the table — step back or you leave your seat.</p>}
        {view.orbit && !leaving && <p className="table-bar__orbit">Right-drag: orbit · Wheel: zoom</p>}
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
            disabled={!action.enabled} onClick={() => emit("lightrp:boardGames:action", { key: action.key })}>{action.label}</Button>)}
        </div>}
        <div className="table-bar__end">
          {views.length > 1 && <Button size="sm" variant="ghost" className="table-bar__camera" icon="video"
            aria-label={`Camera: ${cameraLabel}`} title="Switch the camera view"
            onClick={() => emit("lightrp:boardGames:camera", { cycle: true })}>
            <span className="table-bar__stack"><small>Camera</small><b>{cameraLabel}</b></span>
          </Button>}
          <Button size="sm" variant="ghost" onClick={() => emit("lightrp:boardGames:leave", {})}>
            Leave <Keycap size="sm">BACKSPACE</Keycap>
          </Button>
        </div>
      </div>
    </section>
  </div>;
}
