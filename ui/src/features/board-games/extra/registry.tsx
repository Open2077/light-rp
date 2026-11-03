import type { ComponentType } from "react";
import { RouletteControls } from "./RouletteControls";
import { SlotsControls } from "./SlotsControls";
import { BlackjackControls } from "./BlackjackControls";
import { FortuneControls } from "./FortuneControls";

/* Casino tables plug into the board-game overlay here: one entry per kind,
   matching the Lua registrations (LightRpTabletopExtraClient.register on the
   client, LightRP.tabletopExtra.register on the server). `game` is the
   server's public view of that table. */
export type ExtraState = { [key: string]: unknown };
/** A list from Lua: an empty Lua table arrives as `{}`, not `[]`, and a sparse
    one as an object with numeric keys. Always use this before .map/.filter. */
export function asList<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[];
  if (!value || typeof value !== "object") return [];
  const record = value as Record<string, T>;
  return Object.keys(record).sort((a, b) => Number(a) - Number(b)).map(key => record[key] as T);
}
export interface ExtraControlsProps { game: ExtraState; ready?: boolean; isActor?: boolean }
export interface ExtraGame {
  name: string;
  /** Anyone seated nearby may act, without turns or game modes. */
  openPlay: boolean;
  /** What the left mouse button does at this table (panel, cursor). */
  hint: string;
  /** The same in free mode, aiming with the crosshair; defaults to `hint`. */
  freeHint?: string;
  Controls: ComponentType<ExtraControlsProps>;
}
export const EXTRA_GAMES: Record<string, ExtraGame> = {
  roulette: { name: "Roulette", openPlay: true, hint: "Use the betting controls", freeHint: "Click the table to open the bets", Controls: RouletteControls },
  slots: { name: "Slot Machine", openPlay: true, hint: "Click the lever to pull", freeHint: "Aim at the lever and click to pull", Controls: SlotsControls },
  blackjack: { name: "Blackjack", openPlay: true, hint: "Bet, then Hit, Stand or Double from the panel", freeHint: "Click the table to bet, Hit, Stand or Double", Controls: BlackjackControls },
  fortune: { name: "Fortune Wheel", openPlay: true, hint: "Click a felt spot to pick it", freeHint: "Aim at a felt spot and click to pick it", Controls: FortuneControls },
};
