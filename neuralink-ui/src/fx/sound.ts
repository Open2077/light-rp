/* UI sounds: the page only names them. Lua plays the Cyberpunk 2077 samples shipped in the
   resource (audio/ui_*.wav, mapping in shared/config.lua `uiSounds`) with
   Play2DSound, so they go through the game's own audio rather than the browser.
   The ringtone is NOT here: the server plays it as a 3D sound at the callee and
   the Settings preview asks Lua for the real file (`nl:sound preview:<name>`). */
import { emit, isMock } from "@/bridge/open77";
import { getStore, selectSettings } from "@/store/store";

export type UiSound = "tick" | "select" | "back" | "open" | "close" | "send" | "chime" | "receive" | "connect" | "disconnect" | "error" | "toast" | "glitch"
  // the implant installation (Lua plays them on two shared slots, see implant/timeline.ts)
  | "implant_denied" | "implant_glitch" | "implant_boot" | "implant_flash" | "implant_calibrate" | "implant_granted"
  | "implant_insert" | "implant_scan" | "implant_online";

let lastTick = 0;

export function play(name: UiSound): void {
  const settings = selectSettings(getStore());
  if (name === "chime" && settings.dnd) return;
  const volume = Math.max(0, Math.min(1, settings.volume));
  if (volume <= 0.001) return;
  if (name === "tick") {
    // hover ticks fire per element crossed: keep them to a light patter
    const now = performance.now();
    if (now - lastTick < 60) return;
    lastTick = now;
  }
  if (isMock()) console.debug(`[neuralink] sound ${name}`);
  emit("nl:sound", { name: `ui:${name}`, volume });
}
