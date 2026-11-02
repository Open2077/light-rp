import type { ComponentType } from "react";
import { RouletteControls } from "./RouletteControls";
import { SlotsControls } from "./SlotsControls";

/* Casino tables plug into the board-game overlay here: one entry per kind,
   matching the Lua registrations (LightRpTabletopExtraClient.register on the
   client, LightRP.tabletopExtra.register on the server). `game` is the
   server's public view of that table. */
export type ExtraState = { [key: string]: unknown };
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
};
