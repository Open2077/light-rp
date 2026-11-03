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
  /** What the left mouse button does at this table. */
  hint: string;
  Controls: ComponentType<ExtraControlsProps>;
}
export const EXTRA_GAMES: Record<string, ExtraGame> = {
  roulette: { name: "Roulette", openPlay: true, hint: "Use the betting controls", Controls: RouletteControls },
  slots: { name: "Slot Machine", openPlay: true, hint: "Click the lever to pull", Controls: SlotsControls },
  blackjack: { name: "Blackjack", openPlay: true, hint: "Bet, then Hit, Stand or Double from the panel", Controls: BlackjackControls },
  fortune: { name: "Fortune Wheel", openPlay: true, hint: "Click a felt spot to pick it", Controls: FortuneControls },
};
