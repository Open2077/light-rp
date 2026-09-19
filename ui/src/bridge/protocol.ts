/* The contract between this page and the client Lua (client/core/ui.lua), and the
   shapes the server pushes through it. Mirror of shared/events.lua: change both. */

export const PAGE_EVENTS = {
  // page -> Lua
  ready: "lightrp:ui:ready",
  action: "lightrp:ui:action",
  close: "lightrp:ui:close",
  focus: "lightrp:ui:focus",
  // Lua -> page
  state: "lightrp:ui:state",
  hud: "lightrp:ui:hud",
  open: "lightrp:ui:open",
  closed: "lightrp:ui:closed",
  notice: "lightrp:ui:notice",
  result: "lightrp:ui:result",
} as const;

export type MenuView = "character" | "vehicles" | "staff" | "help";

export type BodyFamily = "male" | "female";
export type CharacterStatus = "draft" | "active" | "archived";
/** The wizard step still missing, as the server sees it. */
export type CharacterStep = "identity" | "appearance" | "confirm" | "done";

export interface CharacterSlot {
  key: string;
  status: CharacterStatus;
  name?: string;
  bodyFamily?: BodyFamily;
  playtimeMs: number;
  lastSeen?: string;
}

export interface CharacterState {
  registered: boolean;      // status === "active"
  status: CharacterStatus;
  step: CharacterStep;
  key: string;
  firstName?: string;
  lastName?: string;
  birthDate?: string;       // YYYY-MM-DD, Night City calendar
  origin?: string;
  story?: string;
  bodyFamily?: BodyFamily;
  appearanceRevision: number;
  appearanceSavedAt?: string;
  appearanceTracked: boolean; // false without a database: the body step is skipped
  accountName: string;
  playerId: number;
  userId?: string;
  playtimeMs?: number;
  slots: CharacterSlot[];
  maxSlots: number;
  origins: Array<{ key: string; label: string }>;
  minAge: number;
  currentYear: number;
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

export interface IdentityFields { firstName: string; lastName: string; birthDate?: string; origin?: string; story?: string }

/** Actions the page raises; the server validates every one of them. Two are
 *  handled by the client Lua itself because they open another package's native
 *  screen: character.appearance.open and character.wardrobe.open. */
export type UiAction =
  | ({ type: "character.identity" } & IdentityFields)
  | { type: "character.appearance.open"; mode: "ripperdoc" | "hairdresser"; family?: BodyFamily }
  | { type: "character.wardrobe.open" }
  | { type: "character.finish" }
  | { type: "character.select"; key: string }
  | { type: "character.new" }
  | { type: "character.archive"; key: string }
  | { type: "vehicle.spawn"; key: string }
  | { type: "vehicle.return" }
  | { type: "staff.tp"; target: "me" | number; location: string }
  | { type: "staff.heal"; target: "me" | number }
  | { type: "staff.announce"; text: string }
  | { type: "staff.bring"; target: number }
  | { type: "voice.range"; range: "whisper" | "normal" | "shout" }
  | { type: "menu.open"; view?: MenuView }
  | { type: "menu.close" };
