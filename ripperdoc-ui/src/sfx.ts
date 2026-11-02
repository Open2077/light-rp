/* The interface sounds are the game's own (media/sfx, from scripts/build-assets.py). In game the
   page only names them and Lua plays them (Play2DSound, one handle per slot); in a browser the
   page plays the same files itself. */
import { emit, inGame } from "./bridge";

export type Sfx =
  | "open" | "close" | "zoom_in" | "zoom_out" | "hover" | "press" | "menu_open" | "equip" | "unequip"
  | "install" | "upgrade" | "bought" | "denied" | "tick_up" | "tick_down" | "gauge" | "glitch"
  | "scan_tag" | "scan_done" | "granted" | "beeps";

const GAIN: Partial<Record<Sfx, number>> = { hover: 0.45, tick_up: 0.5, tick_down: 0.5, scan_tag: 0.5, beeps: 0.35, glitch: 0.6 };
const pool = new Map<Sfx, HTMLAudioElement>();
let lastHover = 0;
let muted = false;

export function setMuted(value: boolean): void { muted = value; }

export function play(name: Sfx): void {
  if (muted) return;
  const now = performance.now();
  if (name === "hover") {
    if (now - lastHover < 45) return; // a sweep across a row is one tick per slot, not a buzz
    lastHover = now;
  }
  if (inGame()) { emit("rd:sound", { name }); return; }
  let audio = pool.get(name);
  if (!audio) {
    audio = new Audio(`./media/sfx/${name}.mp3`);
    audio.preload = "auto";
    pool.set(name, audio);
  }
  audio.volume = Math.min(1, 0.8 * (GAIN[name] ?? 1));
  try { audio.currentTime = 0; void audio.play().catch(() => undefined); } catch { /* not decodable yet */ }
}

/** Warm the browser cache so the first hover is not late (no-op in game). */
export function preload(): void {
  if (inGame()) return;
  for (const name of ["hover", "press", "zoom_in", "zoom_out", "open", "close", "glitch", "equip"] as Sfx[]) {
    const audio = new Audio(`./media/sfx/${name}.mp3`);
    audio.preload = "auto";
    pool.set(name, audio);
  }
}
