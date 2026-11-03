import { useEffect, useState } from "react";

/* Key names as the free camera's mappings report them, shown as keys a player
   recognises. Shared by the free camera's reminder bar and the tables' free
   view hints (features/board-games/TableBar.tsx). */

const ALIASES: Record<string, string> = { FORWARD: "KeyW", BACK: "KeyS", STRAFE_LEFT: "KeyA", STRAFE_RIGHT: "KeyD" };
const NAMES: Record<string, string> = { BACKSPACE: "BKSP", CONTROL: "CTRL", RETURN: "ENTER", PAGEUP: "PGUP", PAGEDOWN: "PGDN", MOUSE1: "LMB", MOUSE2: "RMB", MOUSE3: "MMB" };

/** Movement aliases follow the keyboard layout: WASD, or ZQSD on AZERTY. */
export function useKeyLayout(): Record<string, string> {
  const [layout, setLayout] = useState<Record<string, string>>({ KeyW: "W/Z", KeyS: "S", KeyA: "A/Q", KeyD: "D" }); // until the layout answers
  useEffect(() => {
    const keyboard = (navigator as Navigator & { keyboard?: { getLayoutMap?: () => Promise<Map<string, string>> } }).keyboard;
    let alive = true;
    keyboard?.getLayoutMap?.().then((map) => {
      if (!alive) return;
      const next: Record<string, string> = {};
      for (const code of Object.values(ALIASES)) next[code] = (map.get(code) ?? code.slice(3)).toUpperCase();
      setLayout(next);
    }).catch(() => undefined);
    return () => { alive = false; };
  }, []);
  return layout;
}

/** A mapped key ("forward", "CONTROL", "W") as shown on a keycap. */
export function keyLabel(key: string | undefined, layout: Record<string, string>): string {
  const raw = String(key ?? "?").toUpperCase();
  const code = ALIASES[raw];
  return code ? layout[code] ?? code.slice(3) : NAMES[raw] ?? raw;
}
