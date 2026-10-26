/* Keyboard + typing focus.
   - Any text field focus emits `nl:typing {active:true}`, losing it `{active:false}`
     (debounced across field-to-field moves).
   - Escape: in a field -> blur; otherwise back one level; top level -> close.
   - Arrows / Enter drive the column, the sub-panel and registered window lists. */
import { useEffect } from "react";
import { emit } from "@/bridge/open77";
import { getStore, implantGate, type View } from "@/store/store";
import { goBack, userClose } from "@/store/actions";
import { play } from "@/fx/sound";
import { columnItems, missedSince, panelRows } from "./menu";

export function isTextField(el: Element | null): el is HTMLInputElement | HTMLTextAreaElement {
  if (!el || (el as HTMLElement).dataset?.nlIgnore) return false;
  if (el instanceof HTMLTextAreaElement) return !el.readOnly;
  if (el instanceof HTMLInputElement) return ["text", "search", "tel", "number", "email", "url", "password", ""].includes(el.type) && !el.readOnly;
  return (el as HTMLElement).isContentEditable === true;
}

let typing = false;
let typingTimer: number | undefined;
function syncTyping(): void {
  window.clearTimeout(typingTimer);
  typingTimer = window.setTimeout(() => {
    const active = isTextField(document.activeElement);
    if (active !== typing) {
      typing = active;
      emit("nl:typing", { active });
    }
  }, 0);
}

export function isTyping(): boolean { return typing; }

/** Blur whatever field holds the caret (closing, Lua revoked focus). */
export function blurField(): void {
  const el = document.activeElement as HTMLElement | null;
  if (isTextField(el)) el.blur();
}

/* -------------------------------------------- window-level key handlers */

type KeyHandler = (e: KeyboardEvent) => boolean;
const windowHandlers: KeyHandler[] = [];

/** Register a handler for keys while a window is the active level. The last
    registered wins; return true when the key was consumed. */
export function useWindowKeys(handler: KeyHandler, enabled = true): void {
  useEffect(() => {
    if (!enabled) return;
    windowHandlers.push(handler);
    return () => {
      const i = windowHandlers.lastIndexOf(handler);
      if (i >= 0) windowHandlers.splice(i, 1);
    };
  }, [handler, enabled]);
}

function activate(view: View): void {
  getStore().resetView(view);
  play("select");
}

export function selectColumn(id: string): void {
  const st = getStore();
  if (id === "call") { st.setMenu(null); st.setCallView(true); play("select"); return; }
  if (id.startsWith("app:")) return; // launched by the column component
  st.setMenu(st.menu === id ? null : (id as never));
  play(st.menu === id ? "back" : "select");
}

function onKeyDown(e: KeyboardEvent): void {
  const st = getStore();
  const target = e.target as Element | null;
  if (isTextField(target)) {
    if (e.key === "Escape") { e.preventDefault(); (target as HTMLElement).blur(); }
    return;
  }
  if (st.phase === "closed" || st.phase === "closing" || !st.state) return;
  // No implant: no column to drive, Escape aborts (the buttons take Enter natively).
  if (implantGate(st)) {
    if (e.key === "Escape") { e.preventDefault(); userClose(); }
    return;
  }

  if (e.key === "Escape") {
    e.preventDefault();
    goBack();
    return;
  }

  const atWindow = st.stack.length > 0 || st.callView;
  if (atWindow) {
    for (let i = windowHandlers.length - 1; i >= 0; i--) {
      if (windowHandlers[i]!(e)) { e.preventDefault(); return; }
    }
    if (e.key === "ArrowLeft" || e.key === "Backspace") { e.preventDefault(); goBack(); }
    return;
  }
  if (e.key === "Backspace") { e.preventDefault(); goBack(); return; }

  const missed = missedSince(st.state, st.recentsSeenAt);
  if (st.menu) {
    const rows = panelRows(st.menu, st.state, missed);
    if (rows.length === 0) return;
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const d = e.key === "ArrowDown" ? 1 : -1;
      st.setRow((st.row + d + rows.length) % rows.length);
      play("tick");
    } else if (e.key === "Enter" || e.key === "ArrowRight") {
      e.preventDefault();
      const row = rows[Math.min(st.row, rows.length - 1)];
      if (row) activate(row.view);
    } else if (e.key === "ArrowLeft") {
      e.preventDefault();
      goBack();
    }
    return;
  }

  const items = columnItems(st.state, missed, !!st.state.call);
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {
    e.preventDefault();
    const d = e.key === "ArrowDown" ? 1 : -1;
    st.setCursor((st.cursor + d + items.length) % items.length);
    play("tick");
  } else if (e.key === "Enter" || e.key === "ArrowRight") {
    e.preventDefault();
    const it = items[Math.min(st.cursor, items.length - 1)];
    if (it) document.querySelector<HTMLButtonElement>(`[data-col="${CSS.escape(it.id)}"]`)?.click();
  }
}

export function useKeyboardAndTyping(): void {
  useEffect(() => {
    const fin = () => syncTyping();
    document.addEventListener("focusin", fin);
    document.addEventListener("focusout", fin);
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("focusin", fin);
      document.removeEventListener("focusout", fin);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, []);
}

/* ------------------------------------------------------ list navigation */

/** Up/Down/Enter over a list of `count` rows in the active window. */
export function listKeys(count: number, index: number, setIndex: (i: number) => void, onEnter: (i: number) => void): KeyHandler {
  return (e) => {
    if (count === 0) return false;
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      const d = e.key === "ArrowDown" ? 1 : -1;
      const next = index < 0 ? (d > 0 ? 0 : count - 1) : (index + d + count) % count;
      setIndex(next);
      play("tick");
      requestAnimationFrame(() => document.querySelector(".is-kbd")?.scrollIntoView({ block: "nearest" }));
      return true;
    }
    if (e.key === "Enter" && index >= 0 && index < count) { onEnter(index); return true; }
    return false;
  };
}
