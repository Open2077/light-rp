/* The contract between this page and the client Lua (client/core/ui.lua), and the
   shapes the server pushes through it. Mirror of shared/events.lua: change both. */

export const PAGE_EVENTS = {
  // page -> Lua
  ready: "lightrp:ui:ready",
  action: "lightrp:ui:action",
  close: "lightrp:ui:close",
  focus: "lightrp:ui:focus",
  dialogState: "lightrp:ui:dialog:state", // page -> Lua: { kind, open } so a toggle key can close instead of reopening
  // Lua -> page
  dialogClose: "lightrp:ui:dialog:close", // Lua -> page: { kind } close that dialog
  characterEditor: "lightrp:ui:character:editor", // Lua -> page: native editor handoff { active, error? }
  state: "lightrp:ui:state",
  hud: "lightrp:ui:hud",
  open: "lightrp:ui:open",
  closed: "lightrp:ui:closed",
  notice: "lightrp:ui:notice",
  result: "lightrp:ui:result",
  dialog: "lightrp:ui:dialog",
  interact: "lightrp:ui:interact",
  inventory: "lightrp:ui:inventory",
  actionStart: "lightrp:ui:activity:start",
  actionStarted: "lightrp:ui:activity:started",
  actionFinish: "lightrp:ui:activity:finish",
  actionResult: "lightrp:ui:activity:result",
} as const;

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
  maxAge?: number;
  nameMinLength?: number;
  nameMaxLength?: number;
  nameAllowAccents?: boolean;
  currentYear: number;
  welcomePending: boolean;     // first-spawn briefing not acknowledged yet (once per account)
  welcomeReadSeconds?: number; // how long the OK button stays locked
}

export interface NeedsState { food: number; drink: number }

/** One ledger line of the character's wallet. `amount` is signed. */
export interface MoneyTransaction {
  wallet: "cash" | "bank";
  kind: string; // opening, deposit, withdraw, transfer_in, transfer_out, pay_in, pay_out, fee, refund, staff, salary...
  amount: number;
  balanceAfter: number;
  counterparty?: string;
  note?: string;
  at?: string;
}
/** Cash in the pocket and the bank account; `bank` is absent for a draft character. */
export interface MoneyState {
  currency: string;
  cash: number;
  bank?: { number: string; balance: number };
  history: MoneyTransaction[];
}

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
  money: MoneyState;
  rental: RentalState;
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
  walk?: { mode: string; label: string; speed?: number; index?: number; count?: number }; // current walk mode once the key was used
}

export type NoticeKindWire = "info" | "success" | "warning" | "error" | "police" | "money" | "item" | "message" | "contract" | "staff";
export interface NoticePayload { id?: string; kind?: NoticeKindWire; title?: string; body?: string; source?: string; durationMs?: number }
export interface ResultPayload { ok: boolean; text: string; action?: string }

/** A rental desk's offer, sent when the player presses E at the desk. */
export interface RentalStockItem { key: string; label: string; category: string; price: number; image?: string }
export interface RentalDialogPayload {
  kind: "rental";
  spot: { id: string; name: string; stock: RentalStockItem[]; durationMinutes: number };
}
/** One slot of an inventory as the server sees it. */
export interface InventoryItem {
  slot: number; name: string; count: number; metadata?: Record<string, unknown>;
  label: string; description?: string; weight: number; icon: IconNameWire; category?: string; usable: boolean; stack: number;
  image?: string;
  effects?: { food?: number; drink?: number; health?: number };
}
export type IconNameWire = string;
export interface InventorySnapshot {
  id: string; kind: "player" | "trunk" | "drop" | "stash" | "ground"; label: string;
  slots: number; maxWeight: number; weight: number; items: InventoryItem[];
}
export interface InventoryDialogPayload { kind: "inventory"; left: InventorySnapshot; right: InventorySnapshot; toggleKey?: string }
export type DialogPayload = RentalDialogPayload | InventoryDialogPayload;

export interface ActiveRental {
  spotId: string; spotName: string; key: string; label: string; price: number; paidWith: "cash" | "bank";
  image?: string;
  remainingMs: number; // at the time the state was pushed
  vehicleId?: number;
}
export interface RentalState { active?: ActiveRental }

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
  | { type: "welcome.ack" }
  | { type: "money.deposit"; amount: number }
  | { type: "money.withdraw"; amount: number }
  | { type: "money.transfer"; to: string; amount: number; note?: string }
  | { type: "money.pay"; target: number; amount: number }
  | { type: "rental.rent"; spot: string; key: string; pay: "cash" | "bank" }
  | { type: "rental.return" }
  | { type: "inventory.open"; target?: string }
  | { type: "inventory.close" }
  | { type: "inventory.move"; from: { inventory: string; slot: number }; to: { inventory: string; slot: number }; count: number }
  | { type: "inventory.use"; slot: number }
  | { type: "inventory.drop"; slot: number; count: number }
  | { type: "inventory.give"; slot: number; count: number }
  | { type: "staff.tp"; target: "me" | number; location: string }
  | { type: "staff.heal"; target: "me" | number }
  | { type: "staff.announce"; text: string }
  | { type: "staff.bring"; target: number }
  | { type: "voice.range"; range: "whisper" | "normal" | "shout" }
  | { type: "menu.close" };
