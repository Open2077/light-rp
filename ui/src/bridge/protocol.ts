/* The contract between this page and the client Lua (client/core/ui.lua), and the
   shapes the server pushes through it. Mirror of shared/events.lua: change both. */

export const PAGE_EVENTS = {
  support: "lightrp:ui:support",
  animationsAction: "lightrp:ui:animations:action",
  animationsState: "lightrp:ui:animations:state",
  animationsCatalog: "lightrp:ui:animations:catalog",
  animationsPreferences: "lightrp:ui:animations:preferences",
  // page -> Lua
  ready: "lightrp:ui:ready",
  action: "lightrp:ui:action",
  close: "lightrp:ui:close",
  focus: "lightrp:ui:focus",
  dialogState: "lightrp:ui:dialog:state", // page -> Lua: { kind, open } so a toggle key can close instead of reopening
  // Lua -> page
  dialogClose: "lightrp:ui:dialog:close", // Lua -> page: { kind } close that dialog
  creator: "lightrp:ui:creator",
  tutorial: "lightrp:ui:tutorial",
  jobRun: "lightrp:ui:jobrun", // Lua -> page: JobRunLive
  freecam: "lightrp:ui:freecam", // page -> Lua: { operation: "toggle" }; Lua -> page: FreecamState
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
  shop: "lightrp:ui:shop",
  mission: "lightrp:ui:mission", // Lua -> page: MissionUpdate (live board)
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
/** What the character wears, slot by slot (server/modules/clothing.lua): a record or false. */
export type WornSlot = "Head" | "Face" | "InnerChest" | "OuterChest" | "Legs" | "Feet" | "Outfit";
/** piece: worn alone; outfit: the worn outfit's own; over: a piece over the outfit; hidden: an outfit piece hidden. */
export type WornSource = "piece" | "outfit" | "over" | "hidden";
export interface WornState {
  ready: boolean; family?: "m" | "f"; slots: Partial<Record<WornSlot, string | false>>; changing?: boolean;
  sources?: Partial<Record<WornSlot, WornSource>>; hidden?: Partial<Record<WornSlot, string>>;
  /** The outfit worn as a layer under the clothes (the Outfit slot). */
  outfit?: { label: string; image?: string };
}
export interface UiState {
  worn?: WornState;
  tutorial?: TutorialState;
  server: ServerInfo;
  character: CharacterState;
  needs: NeedsState;
  money: MoneyState;
  rental: RentalState;
  job: JobState;
  jobRun?: JobRunState;
  jobWork?: JobWorkState;
  gang: GangState;
  vehicles: { catalog: VehicleEntry[]; owned: OwnedVehicle[]; cooldownUntil?: number };
  staff: StaffState;
  locations: Array<{ name: string; label: string }>;
  online: Array<{ id: number; name: string }>;
  party?: PartyState;
  missionQueue?: MissionQueueState;
}

/* ── Missions (server/modules/missions.lua) and squads (server/modules/parties.lua) ── */
export interface MissionDifficulty {
  id: string; label: string; blurb: string; payout: number; minutes: number;
  min: number; max: number; tier: number; locked: boolean; tagged: number;
}
export interface MissionLobbyMember { id: number; name: string; citizen: string; tier: number; host: boolean; squad?: string }
export interface MissionBoard {
  id?: string; difficulty: string; members: MissionLobbyMember[]; min: number; max: number;
  state: "open" | "countdown"; countdownMs?: number; host?: string;
}
export interface MissionNearby { id: number; name: string; citizen: string; tier: number; inSquad: boolean; mine: boolean; invited: boolean }
export interface MissionDialogPayload {
  kind: "mission"; session: string;
  point: { id: string; title: string; type: string; location: string; description: string };
  me: { id: number; name: string; citizen: string; tier: number; reputation: number; nextTier?: number };
  difficulties: MissionDifficulty[]; boards: Record<string, MissionBoard>;
  tagged?: { lobby: string; difficulty: string; host: boolean }; taggedElsewhere?: string;
  nearby: MissionNearby[];
}
export interface MissionUpdate { session: string; state?: MissionDialogPayload; closed?: boolean }
export interface PartyMember { id: number; name: string; leader: boolean; tier: number }
export interface PartyState {
  id?: string; leader?: number; members?: PartyMember[]; pending?: Array<{ id: number; name: string }>;
  invites: Array<{ party: string; from: number; fromName: string; expiresInMs: number }>; maxSize: number;
}
export type MissionQueueState = false
  | { running: false; title: string; difficulty: string; difficultyId: string; count: number; min: number; max: number; state: "open" | "countdown"; countdownMs?: number; host: boolean }
  | { running: true; instance: string; title: string; difficulty: string; difficultyId: string; endsInMs: number; members: number; squad: MissionSquadMember[] };
/** One operator in the squad frame of a running mission. `state`: alive, down (waiting for a revive), dead, recovering. */
export interface MissionSquadMember { id: number; name: string; citizen: string; host: boolean; health: number; maxHealth: number; armor: number; state: "alive" | "down" | "dead" | "recovering" }
export type UiStatePatch = Partial<UiState>;

/** The free camera, as client/core/freecam.lua publishes it. `keys` are the effective bindings. */
export interface FreecamState {
  active: boolean;
  phase?: "preparing" | "active";
  paused?: boolean;
  hints?: boolean;
  keys?: Record<string, string>;
  radius?: number;
  distance?: number;
  speed?: number;
  fov?: number;
}

export interface TutorialStop { step: string; label: string; x: number; y: number; state: "done" | "now" | "next" }

export interface TutorialState {
  active: boolean; available: boolean; status?: "active" | "paused" | "done";
  key?: string; step?: string; revision?: number; index?: number; total?: number;
  title?: string; hint?: string; line?: string; contact?: string; role?: string;
  /** A line is plain text, or text with the example UI (`demo`) played beside it. */
  dialogue?: string; lines?: Array<string | { text: string; demo?: string }>;
  /** The destination as the reveal camera titles it; the example UI of the objective card. */
  place?: string; direction?: string; demo?: string;
  /** The arrival hall from above (metres from the square, x east, y north), one entry per stop. */
  map?: TutorialStop[];
  /** The guide's own name (the quoted hint), the label of the last dialogue button, where the step is played. */
  guide?: string; action?: string; kind?: string; where?: "lobby" | "city";
  /** What the objective card lists, in order; `key` names a binding (menu, inventory, interact) drawn as a key cap. */
  todo?: Array<{ key?: "menu" | "inventory" | "interact" | "context"; text: string }>;
  practice?: { prop: string; vehicle: number; position: { x: number; y: number; z: number } };
  practiceError?: string;
  opening?: { eyebrow?: string; title?: [string, string]; subtitle?: string; place?: string };
  objective?: { position: { x: number; y: number; z: number }; label: string; radius: number; kind?: string; interaction?: string };
}

/** Sampled on the client every ~100 ms: vitals, vehicle, voice. */
export interface HudState {
  ready: boolean;
  health: { value: number; max: number };
  stamina: { value: number; max: number };
  armor: number;
  vehicle: { active: boolean; label?: string; speedKph?: number; gear?: string; health?: number; fuel?: FuelGauge };
  voice: { state: "off" | "idle" | "talking" | "muted"; level: number; range: "whisper" | "normal" | "shout" };
  clock: string; // HH:MM in-game
  street?: string;
  walk?: { mode: string; label: string; speed?: number; index?: number; count?: number }; // current walk mode once the key was used
}

/** The tank of the vehicle the player sits in, read from its state bag. */
export interface FuelGauge { litres: number; capacity: number; fraction: number; low: boolean; empty: boolean }

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
  useAction?: { label: string; durationMs: number; icon: IconNameWire };
}
export type IconNameWire = string;
export interface InventorySnapshot {
  id: string; kind: "player" | "trunk" | "drop" | "stash" | "ground" | "housing"; label: string;
  slots: number; maxWeight: number; weight: number; items: InventoryItem[];
}
export interface InventoryDialogPayload { kind: "inventory"; left: InventorySnapshot; right: InventorySnapshot; toggleKey?: string }
export interface ShopItem {
  name: string; label: string; description?: string; icon: string; image?: string;
  category: string; weight: number; stack: number; buy?: number; sell?: number; owned: number;
  effects?: InventoryItem["effects"];
}
export interface ShopDialogPayload {
  kind: "shop"; session: string; revision: number; nextRequest: number;
  shop: { id: string; name: string; label: string; subtitle?: string; template: string };
  items: ShopItem[]; payments: Array<"cash" | "bank">; maxLines: number; maxPerItem: number;
  inventory: InventorySnapshot; money: { currency: string; cash: number; bank: number };
}
export interface ShopUpdate {
  session: string; request?: number; ok?: boolean; text?: string; closed?: boolean;
  catalogueChanged?: boolean; refresh?: boolean; state?: ShopDialogPayload;
}
export interface JobOffer {
  name: string; label: string; tag: string; grades: number; entryGrade: { label: string; salary: number };
  recruitment?: { image?: string; icon?: string; environment?: string; headline?: string; description?: string; steps?: string[] };
  // variable: a route drawn per order (the courier): `reward` is the minimum, the pay follows the distance.
  route?: JobRoutePreview;
  work?: JobWorkPreview;
}
/** A job's work orders (server/modules/job_runs.lua Runs.preview). `remote`: the
 *  player menu can collect one anywhere; otherwise only at a job center desk. */
export interface JobRoutePreview {
  label: string; reward: number; stops: number; estimate: string; description: string; variable?: boolean; orders?: { min: number; max: number };
  remote?: boolean; lifetimeMinutes?: number;
}
/** A job's free item work (server/modules/job_work.lua Work.preview). */
export interface JobWorkPreview {
  raw:string; product:string; rawItem?:string; productItem?:string; collectCount:number; collectWeight:number; inputCount:number; outputCount:number; price:number;
}
/** A page of the job guide (shared/jobs.lua `guide`). */
export interface JobGuidePage { title: string; body: string; demo?: string; tips?: string[] }
export interface JobWorkState {
  active:boolean; job?:string; kind?:"collect"|"process"|"sell"; label?:string; icon?:string;
  busy?:boolean; cycles?:number; weight?:number; maxWeight?:number;
  raw?:string; product?:string; rawCount?:number; productCount?:number; earned?:number;
}
export type JobStopKind = "work" | "lift" | "return" | "pickup" | "dropoff";
export interface JobRunStop { kind: JobStopKind; label: string; place: string; order?: number; state: "done" | "now" | "todo" }
export interface JobRunState {
  active: boolean; id?: string; job?: string; jobLabel?: string; label?: string; reward?: number;
  index?: number; total?: number; busy?: boolean; working?: boolean; icon?: string; hint?: string;
  orders?: number; carried?: number; distanceKm?: number; // courier runs
  /** Every stop of the route with its state; the run's time left when the snapshot was sent. */
  stops?: JobRunStop[]; expiresInMs?: number;
  objective?: { label: string; place?: string; kind: JobStopKind; position: { x: number; y: number; z: number }; radius: number };
}
/** Live readout of the tracker (client/core/job_runs.lua): metres to the stop, the player menu key. */
export interface JobRunLive { distance: number | false; menuKey: string; /** the GPS waypoint really routes to the stop */ gps?: boolean }
export interface JobCenterDialogPayload { kind: "jobcenter"; spot: { id: string; name: string }; jobs: JobOffer[]; paycheckMinutes: number }
export interface PersonalVehicle {
  id: string; key: string; label: string; category: string; status: "stored" | "out" | "impound";
  garageId: string; garageName: string; health: number; canRetrieve: boolean; canStore: boolean; hint?: string;
  /** Out (or lost): may be sent to the impound. At the impound: may be recovered here. */
  canImpound?: boolean; canRecover?: boolean; impound?: { reason: string; fee: number };
}
export interface GarageDialogPayload {
  kind: "garage"; session: string; nextRequest: number;
  spot: { id: string; name: string }; vehicles: PersonalVehicle[]; maxOutside: number;
  impound?: { name: string; fees: { requested: number; lost: number; restart: number } };
}
export interface GarageUpdate {
  session: string; request?: number; ok?: boolean; text?: string; closed?: boolean; state?: GarageDialogPayload;
}
export interface DealershipOffer extends RentalStockItem { description?: string }
export interface DealershipDialogPayload {
  kind: "dealership"; session: string; nextRequest: number;
  dealer: { id: string; name: string; subtitle?: string }; garage: { id: string; name: string };
  /** Bought here, the vehicle is driven out to this bay (else it waits at `garage`). */
  delivery?: { name: string };
  stock: DealershipOffer[]; money: { currency: string; cash: number; bank: number };
}
export interface DealershipUpdate {
  session: string; request?: number; ok?: boolean; text?: string; closed?: boolean; state?: DealershipDialogPayload; vehicleId?: string;
}
/** A gas station pump, sent when the player presses E at it. `vehicle` is the
 *  car parked at the pump (absent when none is within pumpRange). */
export interface FuelDialogPayload {
  kind: "fuel";
  spot: { id: string; name: string; pump?: number; pumps?: number };
  pricePerLitre: number;
  pumpRange: number;
  vehicle?: FuelVehicle;
  vehicles?: FuelVehicle[];
  litresPerSecond?: number;
  minimumFillMs?: number;
  busy?: boolean;
  jerrycan: { litres: number; refillPrice: number; buyPrice: number; empty: number; full: number };
  money: { currency: string; cash: number; bank: number };
}
export interface FuelVehicle { id: number; label: string; litres: number; capacity: number; moving: boolean; engineOn?: boolean; unavailable?: string; distance?: number }
export type DialogPayload = MissionDialogPayload | RentalDialogPayload | InventoryDialogPayload | ShopDialogPayload | JobCenterDialogPayload | GarageDialogPayload | DealershipDialogPayload | FuelDialogPayload | { kind: "support"; scope: "player" | "staff"; body?: string } | { kind: "housing"; admin: boolean };

export interface ActiveRental {
  spotId: string; spotName: string; key: string; label: string; price: number; paidWith: "cash" | "bank";
  image?: string;
  remainingMs: number; // at the time the state was pushed
  vehicleId?: number;
}
export interface RentalState { active?: ActiveRental }

export interface JobState {
  name: string; label: string; tag: string; grade: number; gradeLabel: string; salary: number; paycheckMinutes?: number;
  // How the job works, for the job guide and F1 → My job (server/modules/jobs.lua).
  guide?: JobGuidePage[]; run?: JobRoutePreview; work?: JobWorkPreview; art?: { image?: string; icon?: string };
}
export interface GangState { name: string; label: string; tag: string; color?: string; grade: number; gradeLabel: string }

export interface IdentityFields { firstName: string; lastName: string; birthDate?: string; origin?: string; story?: string }

/** Actions the page raises; the server validates every one of them. Two are
 *  handled by the client Lua itself because they open another package's native
 *  screen: character.appearance.open and character.wardrobe.open. */
export type UiAction =
  | { type: "mission.tag" | "mission.tagGroup"; session: string; difficulty: string }
  | { type: "mission.untag" | "mission.launch" | "mission.close"; session: string }
  | { type: "party.invite" | "party.kick" | "party.promote"; target: number }
  | { type: "party.accept" | "party.decline"; party?: string }
  | { type: "party.leave" }
  | { type: "dealership.buy"; session: string; request: number; key: string; pay: "cash" | "bank" }
  | { type: "dealership.close"; session: string }
  | { type: "garage.retrieve" | "garage.store" | "garage.impound"; session: string; request: number; vehicle: string }
  | { type: "garage.recover"; session: string; request: number; vehicle: string; pay?: "cash" | "bank" }
  | { type: "garage.close"; session: string }
  | { type: "shop.checkout"; session: string; request: number; revision: number; mode: "buy" | "sell"; pay: "cash" | "bank"; lines: Array<{ name: string; count: number }> }
  | { type: "shop.close"; session: string }
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
  | { type: "fuel.buy"; spot: string; vehicle: number; litres: number; pay: "cash" | "bank" }
  | { type: "fuel.jerrycan"; spot: string; pay: "cash" | "bank" }
  | { type: "fuel.refresh"; spot: string }
  | { type: "inventory.open"; target?: string }
  | { type: "inventory.close" }
  | { type: "clothing.refresh" }
  | { type: "clothing.takeOff"; slot: WornSlot; label?: string; icon?: string }
  | { type: "clothing.show"; slot: WornSlot }
  | { type: "clothing.makeOutfit"; name?: string }
  | { type: "inventory.move"; from: { inventory: string; slot: number }; to: { inventory: string; slot: number }; count: number }
  | { type: "inventory.use"; slot: number }
  | { type: "inventory.drop"; slot: number; count: number }
  | { type: "inventory.give"; slot: number; count: number }
  | { type: "jobs.apply"; spot: string; job: string }
  | { type: "jobs.quit" }
  | { type: "jobs.start"; from?: "menu" }
  | { type: "jobs.gps" }
  | { type: "jobs.locate"; job:string; stage:"collect"|"process"|"sell" }
  | { type: "jobs.cancel" }
  | { type: "staff.tp"; target: "me" | number; location: string }
  | { type: "staff.heal"; target: "me" | number }
  | { type: "staff.announce"; text: string }
  | { type: "staff.bring"; target: number }
  | { type: "voice.range"; range: "whisper" | "normal" | "shout" }
  | { type: "menu.close" };
