/* The keyboard shell's rows and its typing mode, for any editor on RageMenu. */
import { useEffect, type Dispatch, type SetStateAction } from "react";
import type { RageMenuItem } from "@/design/components";

export type Entry = RageMenuItem & { run?: () => void; change?: (patch: Partial<RageMenuItem>) => void };
export type TextEdit = { id: string; value: string; replace: boolean; numeric: boolean; max: number; commit: (value: string) => string | undefined };
export const STEPS = [0.1, 1, 5, 10];
export const rounded = (value: number) => Math.round(value * 1000) / 1000;

/** Full keyboard capture while typing a row's value. */
export function useTyping(opened: boolean, editing: TextEdit | undefined, setEditing: Dispatch<SetStateAction<TextEdit | undefined>>, setError: (text: string) => void) {
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
}

export function rowBuilders<Page>({ locked, stepIndex, setEditing, setError, push }: {
  locked: boolean; stepIndex: number; setEditing: (edit: TextEdit) => void; setError: (text: string) => void; push: (page: Page) => void;
}) {
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
  return { readOnly, item, submenu, textEntry, numberEntry, toggle, choice };
}
