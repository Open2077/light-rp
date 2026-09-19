/* The contract between this page and the client Lua (client/core/ui.lua), and the
   shapes the server pushes through it. Mirror of shared/events.lua: change both. */

export const PAGE_EVENTS = {
  // page -> Lua
  ready: "lightrp:ui:ready",
  action: "lightrp:ui:action",
  close: "lightrp:ui:close",
  // Lua -> page
  state: "lightrp:ui:state",
  hud: "lightrp:ui:hud",
  open: "lightrp:ui:open",
  closed: "lightrp:ui:closed",
  notice: "lightrp:ui:notice",
  result: "lightrp:ui:result",
} as const;

export type MenuView = "character" | "vehicles" | "staff" | "help";

export interface CharacterState {
  registered: boolean;
  firstName?: string;
  lastName?: string;
  accountName: string;
  playerId: number;
  userId?: string;
  playtimeMs?: number;
}

export interface NeedsState { food: number; drink: number }

export interface VehicleEntry { key: string; label: string; category: string; staffOnly?: boolean }
export interface OwnedVehicle { id: number; key: string; label: string }

export interface StaffState { isStaff: boolean; role?: string; permissions?: string[] }

export interface ServerInfo { name: string; playersOnline: number; maxPlayers: number; version?: string }

/** Everything the server knows about this player that the UI shows. Sent whole on
 *  connect, then as partial patches (every top-level key optional). */
export interface UiState {
  server: ServerInfo;
  character: CharacterState;
  needs: NeedsState;
  vehicles: { catalog: VehicleEntry[]; owned: OwnedVehicle[]; cooldownUntil?: number };
  staff: StaffState;
  locations: Array<{ name: string; label: string }>;
  online: Array<{ id: number; name: string }>;
}
export type UiStatePatch = Partial<UiState>;

/** Sampled on the client every ~100 ms: vitals, vehicle, voice. */
export interface HudState {
  ready: boolean;
  health: { value: number; max: number };
  stamina: { value: number; max: number };
  armor: number;
  vehicle: { active: boolean; label?: string; speedKph?: number; gear?: string; health?: number };
  voice: { state: "off" | "idle" | "talking" | "muted"; level: number; range: "whisper" | "normal" | "shout" };
  clock: string; // HH:MM in-game
  street?: string;
}

export type NoticeKindWire = "info" | "success" | "warning" | "error" | "police" | "money" | "item" | "message" | "contract" | "staff";
export interface NoticePayload { id?: string; kind?: NoticeKindWire; title?: string; body?: string; source?: string; durationMs?: number }
export interface ResultPayload { ok: boolean; text: string; action?: string }

/** Actions the page raises; the server validates every one of them. */
export type UiAction =
  | { type: "register"; firstName: string; lastName: string }
  | { type: "vehicle.spawn"; key: string }
  | { type: "vehicle.return" }
  | { type: "staff.tp"; target: "me" | number; location: string }
  | { type: "staff.heal"; target: "me" | number }
  | { type: "staff.announce"; text: string }
  | { type: "staff.bring"; target: number }
  | { type: "voice.range"; range: "whisper" | "normal" | "shout" }
  | { type: "menu.open"; view?: MenuView }
  | { type: "menu.close" };
