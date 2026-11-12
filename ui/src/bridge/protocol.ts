/* The contract between this page and the client Lua (client/core/ui.lua), and the
   shapes the server pushes through it. Mirror of shared/events.lua: change both. */
import type { DogtownState } from "@/features/dogtown/model";
import type { ParkourDialogPayload } from "@/features/parkour/model";

export const PAGE_EVENTS = {
  customization: "lightrp:ui:customization",
  armament: "lightrp:ui:armament",
  safezones: "lightrp:ui:safezones",
  missionEditor: "lightrp:ui:missioneditor",
  mapEditor: "lightrp:ui:mapeditor",
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
  tutorialGuide: "lightrp:ui:tutorialguide", // Lua -> page: GuideMessage, the way to the objective (client/core/tutorial_guide.lua)
  jobRun: "lightrp:ui:jobrun", // Lua -> page: JobRunLive
  freecam: "lightrp:ui:freecam", // page -> Lua: { operation: "toggle" }; Lua -> page: FreecamState
  maneki: "lightrp:ui:maneki", // Lua -> page: ManekiToolState (client/core/maneki_editor.lua)
  arrivalTour: "lightrp:ui:arrivaltour", // Lua -> page: ArrivalTourMessage | false, the square's camera tour (client/core/arrival_tour.lua)
  staffAnnounce: "lightrp:ui:staffannounce", // Lua -> page: StaffBroadcastMessage (client/core/staff_announce.lua)
  parkour: "lightrp:ui:parkour", // Lua -> page: the run HUD, the course card's leaderboard (client/core/parkour.lua); page -> Lua: { op }
  parkourEditor: "lightrp:ui:parkoureditor", // page <-> Lua: the staff parkour editor (client/core/parkour_editor.lua)
  characterEditor: "lightrp:ui:character:editor", // Lua -> page: native editor handoff { active, error? }
  state: "lightrp:ui:state",
  hud: "lightrp:ui:hud",
  open: "lightrp:ui:open",
  closed: "lightrp:ui:closed",
  notice: "lightrp:ui:notice",
  noticePush: "lightrp:ui:notice:push", // page -> Lua: a notice raised inside the page, for the native lane
  result: "lightrp:ui:result",
  dialog: "lightrp:ui:dialog",
  interact: "lightrp:ui:interact",
  inventory: "lightrp:ui:inventory",
  shop: "lightrp:ui:shop",
  mission: "lightrp:ui:mission", // Lua -> page: MissionUpdate (live board)
  raid: "lightrp:ui:raid", // Lua -> page: RaidState (server/modules/mission_chimera.lua)
  activityHud: "lightrp:ui:activityhud", // Lua -> page: ActivityHudMessage (client/core/activity_hud.lua)
  guide: "lightrp:ui:guide", // Lua -> page: GuideMessage (client/core/guide.lua, server/modules/guide.lua)
  actionStart: "lightrp:ui:activity:start",
  actionStarted: "lightrp:ui:activity:started",
  actionFinish: "lightrp:ui:activity:finish",
  actionResult: "lightrp:ui:activity:result",
  actionInput: "lightrp:ui:activity:input", // page -> Lua: the running action's raw keys (features/actions/Actions.tsx -> client/native/actions.lua)
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

export interface NeedsState {
  food: number; drink: number;
  /** server/modules/needs.lua: at 0 food and/or drink the character loses health until they eat/drink. */
  starving?: "food" | "drink" | "both" | false;
  /** Percent of max health lost per minute while starving. */
  drainPerMinute?: number;
  /** Food and drink above the threshold: health comes back by itself. */
  wellFed?: boolean;
  /** Health points regained per minute while well fed. */
  regenPerMinute?: number;
}

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
  /** The queue this player waits in, whatever it is (server/modules/activity_queue.lua); false: none. */
  queue?: QueueState;
  /** The key bound to "Light RP: leave queue", added by client/core/queue.lua; false: cleared. */
  queueKey?: string | false;
  /** A fixer gig taken and not yet running (server/modules/fixers.lua); false: none. */
  fixerGig?: FixerGigState | false;

  /** Arena, races, chases, events and The Crossing (server/modules/activities.lua A.view). */
  activities?: ActivitiesState;
  /** The game rooms (server/modules/activity_rooms.lua R.view). */
  rooms?: RoomsState;
  /** The Dogtown PvP zone (server/modules/dogtown.lua; features/dogtown). */
  dogtown?: DogtownState;
  /** A world boss whose zone you are in, or that you fought (server/modules/world_bosses.lua). */
  worldBoss?: WorldBossState | false;
  /** The last end-of-match recap kept for F1 > Last match (server/modules/recap.lua); false: none. */
  recap?: RecapState | false;
  /** Dailies (server/modules/dailies.lua D.view; features/dailies). */
  dailies?: DailiesState;
  /** Earned titles and the one shown (server/modules/titles.lua T.view; features/dailies). */
  titles?: TitlesState;
  /** The Maneki-neko collection of this character (server/modules/maneki.lua): found / hidden. */
  maneki?: { found: number; total: number };
}

/* ── Dailies and titles (server/modules/dailies.lua, titles.lua; docs/dailies-titles.md) ── */
export type DailySlot = "street" | "action" | "shift" | "crew" | "weekly";
/** One contract card. `value`/`target` in `unit` (m, s, or a count when absent). */
export interface DailyCard {
  slot: DailySlot; id: string; title: string; fixer: string; fixerName: string; brief: string; goal: string;
  value: number; target: number; unit?: "m" | "s"; done: boolean; claimed: boolean; reward: number;
  /** Today's free swap can replace it. */
  swappable?: boolean;
  /** A crew contract while the player has no crewmate. */
  needsCrew?: boolean;
  /** No crewmate online and not started: the card is a placeholder until one shows up. */
  crewLocked?: boolean;
  /** Done with other players (handed out only when the server has enough of them). */
  social?: boolean;
}
/** `ready` false: no character loaded yet. Countdowns are from the push. `older`: finished
 *  and unpaid from yesterday (or last week on Monday), still claimable. */
export interface DailiesState {
  enabled: boolean; ready?: boolean; day?: number; resetInMs?: number; weekResetInMs?: number;
  streak: number; swapsLeft: number; budget: { used: number; max: number };
  list: DailyCard[]; older: Array<{ id: string; title: string; reward: number }>;
}
export type TitleRarity = "common" | "rare" | "epic" | "legendary" | "live";
/** A title as the player sees it: `live` = a Hall of Fame rank-1 title, held only while rank 1;
 *  `value`/`count` = progress; `expiresInMs` (from the push) for a title that expires. */
export interface TitleEntry {
  id: string; label: string; rarity: TitleRarity; group: string; how: string;
  earned?: boolean; live?: boolean; value?: number; count?: number; expiresInMs?: number;
}
/** `chosen`: the player's pick; `shown`: what others read now (a live title not held hides it). */
export interface TitlesState {
  enabled: boolean; shown?: string; chosen?: string;
  groups: Array<{ id: string; label: string }>; list: TitleEntry[];
}
export type DailiesTab = "today" | "titles";
export interface DailiesDialogPayload { kind: "dailies"; tab: DailiesTab }
export interface WorldBossState {
  id: string; title: string; location: string; boss: string; phase: "fight" | "cleanup" | "done";
  bossHealth: number; enemiesLeft: number; fighters: number; endsInMs?: number;
  share: number; minShare: number; eligible: boolean; damage: number; kills: number; reward: number; inZone: boolean;
  /** The event's tag (WORLD BOSS, CYBERPSYCHO, GANG ATTACK: server/config/staff_events.lua). */
  tag?: string;
  /** A staff event for fun: nothing is paid or counted. */
  noPay?: boolean;
  result?: { success: boolean; share: number; pay: number; eligible: boolean; damage: number; kills: number } | null;
}
export interface FixerGigState {
  id: number; title: string; location: string; fixer: string; state: "accepted" | "countdown";
  crew: number; min: number; max: number; owner: boolean; here: number; meetInMs?: number; launchInMs?: number;
}

/* ── Activities (server/modules/activities.lua, activities_hub.lua) ── */
export type ActivityKind = "pvp" | "race" | "chase" | "event";
export type ActivityPhase = "idle" | "lobby" | "running";
/** A character's totals in an activity (or on its shown course board). */
export interface ActivityStats {
  played: number; wins: number; kills: number; deaths: number; reputation: number;
  bestScore?: number; bestTimeMs?: number; bestPlacement?: number;
}
export interface ActivityTopRow { rank: number; name: string; wins: number; played: number; bestTimeMs?: number; bestScore?: number }
/** A PvE difficulty (docs/pve-progression.md): locked above the player's reputation tier. */
export interface ActivityDifficulty { id: string; label: string; minTier: number; tierName?: string; locked: boolean; reputation: number }
export interface ActivityEntry {
  id: string; label: string; kind: ActivityKind; description: string; minPlayers: number; maxPlayers: number;
  /** The provider's latest status (op77_lightrp:activity:status). */
  phase: ActivityPhase; players: number; queued: number; joinable: boolean; detail: string;
  /** Races rank by best time, everything else by wins. */
  byTime: boolean;
  /** Join choices (options[modeKey]); empty: the provider decides. botFill false: no bots in that mode. */
  modes: Array<{ id: string; label: string; botFill?: boolean }>; modeKey: string;
  /** What the panel offers beyond a plain join (absent: nothing). */
  lobby?: ActivityLobby;
  /** Players against bots: earns reputation; its difficulties go as options.difficulty. */
  pve?: boolean; difficulties?: ActivityDifficulty[];
  top: ActivityTopRow[];
  /** The course board the leaderboard shows (a race with courses). */
  board?: { id: string; course: string; revision: number };
  mine?: ActivityStats; mineBoard?: ActivityStats;
}
/** The lobby of an activity (server/config/activities.lua `lobby`, the provider's botFill). */
export interface ActivityLobby {
  /** PvE: "Fill empty slots with bots", allied bots up to `seats` beside the crew (still ranked). */
  allies?: boolean; seats?: number;
  /** PvP: "Play with bots" up front, and the bot fill offer of a long search (unranked). */
  bots?: boolean;
  /** PvP: a crew leader starts a friendly match inside the crew (unranked). */
  friendly?: boolean;
  /** The ranked search is the core's queue (team sizes; cyberware brackets unless brackets is absent). */
  queue?: boolean; brackets?: boolean;
}
/** A join waiting (the provider's queue, the core's ranked search, a match on its way). */
export interface ActivityQueued {
  id: string; label: string; sinceMs: number; difficulty?: string;
  /** false: a friendly, a bot match or fill, staff bot mode. */
  ranked?: boolean; mode?: string;
  /** This player decides (solo or crew leader); a crew member only follows. */
  lead?: boolean;
  /** A match formed by the core is on its way (the provider is setting it up). */
  match?: boolean; friendly?: boolean;
  /** PvE: allied bots asked. */
  allies?: number;
  /** The core's ranked search: searchers that fit now, players a match needs, near your rank or all ranks. */
  search?: { found?: number; needed?: number; scope?: "near" | "all"; widenInMs?: number; bracket?: number };
  /** The bot fill offer (unranked) opens in this long (0: open now); absent: no offer for this search. */
  fillInMs?: number;
}
export interface ActivityFriendlyPlayer { id: number; name: string; tier: number }
/** A friendly crew match being set up by the crew leader (always unranked). */
export interface ActivityFriendly {
  id: string; label: string; mode?: string;
  /** Bots take the empty places (only when canBots). */
  bots: boolean; canBots: boolean;
  /** teams: sides of `size`; split: two halves; ffa: everyone for themselves. */
  shape: "teams" | "split" | "ffa"; size: number;
  leader: string; mine: boolean; bench: ActivityFriendlyPlayer[];
  /** Why it cannot start yet. */
  issue?: string;
  teams?: ActivityFriendlyPlayer[][]; teamBots?: number[];
  players?: ActivityFriendlyPlayer[]; enemies?: number;
}
/** A mission board of the city, for the Contracts terminal (GPS only). */
export interface ActivityContract { id: string; title: string; type: string; location: string; description: string; distance?: number }
export interface ActivityNearby { id: number; name: string; distance: number; inSquad: boolean; mine: boolean; invited: boolean }
export interface ActivitiesState {
  enabled: boolean;
  hub: { name: string; position?: { x: number; y: number; z: number } };
  list: ActivityEntry[];
  /** The activity that owns the player (sinceMs at the push), or false. */
  current: false | { id: string; label: string; sinceMs: number; leaving: boolean; returning: boolean; difficulty?: string };
  /** A join asked and not entered yet (the provider's queue or lobby, the ranked search), or false. */
  queued: false | ActivityQueued;
  /** The crew's friendly match being set up (the leader edits it), or false. */
  friendly?: false | ActivityFriendly;
  lobby?: { fillAfterMs: number };
  /** On a mission: activities wait (/mission leave). */
  mission: boolean;
  /** Free for an activity, else the reason in one sentence. */
  eligible: boolean; reason?: string;
  /** PvE reputation granted today (account, UTC day) and the player's street cred tier. */
  reputation: { today: number; dailyCap: number; maxPerResult: number; pvpGrants?: boolean;
    tier?: number; tierName?: string; points?: number; next?: number; nextName?: string };
  /** Staff bot mode (/lightrp.bots): bots fill the missing places, nothing is recorded. */
  bots?: boolean;
  /** Players around (only while the panel is open), for crew invites. */
  nearby: ActivityNearby[];
  contracts: ActivityContract[];
  /** In a crew led by someone else: the leader's name (only the leader starts activities). */
  crewLeader?: string;
}
export type ActivitiesTab = "activities" | "contracts" | "dailies" | "crew";

/* ── Game rooms (server/modules/activity_rooms.lua): a friendly with no crew requirement ── */
/** What can be hosted now. Labels, maps and limits come from the `activities` list.
 *  `least` / `most`: the range of `size`, per side with `teams`, the whole room without. */
export interface RoomGame { id: string; teams?: number; least: number; most: number }
/** A public room, as the browse list shows it. */
export interface RoomListing {
  id: number; activity: string; label: string; mode?: string; modeLabel?: string; host: string; count: number; max: number; teams?: number;
}
export interface RoomPlayer { id: number; name: string; host?: boolean }
/** The room this player is in. `code`: a private room's. `mine`: this player hosts. */
export interface RoomView {
  id: number; activity: string; label: string; mode?: string; modeLabel?: string; host: string; count: number; max: number;
  private: boolean; code?: string; mine: boolean; size: number; least?: number; most?: number;
  /** Why it cannot start yet. */
  issue?: string;
  teams?: RoomPlayer[][]; players?: RoomPlayer[];
}
export interface RoomsState {
  enabled: boolean;
  /** Free to host or join, else the reason in one sentence. */
  eligible: boolean; reason?: string;
  /** The server's room limit is reached. */
  full: boolean;
  games: RoomGame[]; list: RoomListing[]; room: false | RoomView;
}

/** The Hall of Fame at The Crossing (server/modules/halloffame.lua): one tab per
 *  dialog payload, from the server cache. Names are character names only. */
export type HallOfFameTab = "overview" | "pvp" | "races" | "pve" | "missions" | "wealth";
export type HallOfFameUnit = "wins" | "kills" | "time" | "eddies" | "rep" | "count" | "clears" | "points";
/** `title`: the character's shown title (titles.lua), when it has one. */
export interface HallOfFameRow { rank: number; name: string; value: number; detail?: string; you?: boolean; title?: string }
export interface HallOfFameBoard {
  key: string; title: string; subtitle?: string; unit: HallOfFameUnit; ascending?: boolean; total: number;
  rows: HallOfFameRow[]; mine?: { rank: number; value: number; detail?: string };
}
/** `ladder`: the answer to `halloffame.board` (a card clicked), one board's full ladder
 *  (top `ladderSize`, the viewer's own rank in `mine`) under the header of `tab`, the
 *  tab it was opened from; `boards` is empty then. */
export interface HallOfFameDialogPayload {
  kind: "halloffame"; title: string; hub: string; tab: HallOfFameTab; tabs: HallOfFameTab[]; boards: HallOfFameBoard[];
  database: boolean; updatedAgoS?: number; refreshInS?: number; wealthBankOnly?: boolean; ladder?: HallOfFameBoard;
}

/** The end-of-match recap (server/modules/recap.lua): one activity match, mission or
 *  world boss as one player saw it. Zero values are left out of the rows. Bots carry
 *  negative ids. `dps` = damage dealt ÷ seconds in the match. */
export type RecapColumn = "placement" | "kills" | "deaths" | "assists" | "damage" | "damageTaken" | "dps" | "headshots" | "bossShare"
  | "share" | "captures" | "holdS" | "roundsWon" | "busts" | "escapes" | "points" | "timeMs" | "bestLapMs" | "checkpoints" | "score";
export type RecapRow = { id: number; name: string; bot?: boolean; side?: number; left?: boolean; outcome?: string } & Partial<Record<RecapColumn, number>>;
export interface RecapSide { id: number; label: string; score?: number }
export interface RecapRewards {
  test?: boolean; eddies?: number; eddiesReason?: string; eddiesNote?: string; reputation?: number; reputationCapped?: boolean;
  tier?: { tier: number; name?: string; points?: number; next?: number; nextName?: string; up?: boolean };
  hof?: Array<{ board: string; before?: number; rank: number }>;
}
export interface RecapDialogPayload {
  kind: "recap"; id: string; source: "activity" | "mission" | "worldboss"; mode: string; modeKind?: string; detail?: string; durationMs?: number;
  result: { label: string; tone: "win" | "loss" | "neutral"; placement?: number; of?: number };
  test?: boolean; unranked?: boolean; you: number; columns: RecapColumn[]; sides: RecapSide[]; winnerSide?: number;
  rows: RecapRow[]; total: number; lines: Array<{ label: string; value: string }>; mvp?: { id: number; by?: string };
  rewards: RecapRewards; reopened?: boolean;
}
/** F1 > Last match: the latest recap the server keeps for this player. */
export interface RecapState { last?: { id: string; mode?: string; result?: string; test?: boolean } }

/* ── Missions (server/modules/missions.lua) and crews (server/modules/parties.lua) ── */
export interface MissionDifficulty {
  id: string; label: string; blurb: string; payout: number; minutes: number;
  min: number; max: number; tier: number; locked: boolean; tagged: number;
  requires?: string; cleared?: number; // the difficulty to complete first at this point; how often this one was completed
  /** Lobbies open to matchmaking with room for this player's crew (shown to a closed crew). */
  openLobbies?: number;
  /** `tier` is the reputation tier it needs; tierLocked: the player is below it. */
  tierName?: string; tierLocked?: boolean;
  /** Reputation of a success: in full (`reputation`), and what this player earns (`earns`). Below
   *  what they have unlocked a crew member still plays it with their leader, for the reward of the
   *  highest difficulty they have unlocked (`earnsAs`, its label; absent when it is this one). */
  reputation?: number; earns?: number; earnsAs?: string;
  /** Full pay already earned today at this mission and difficulty (mission_pay.lua): a repeat pays a small share until 00:00 UTC. */
  paidToday?: boolean;
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
  me: { id: number; name: string; citizen: string; tier: number; reputation: number; nextTier?: number; tierName?: string };
  difficulties: MissionDifficulty[]; boards: Record<string, MissionBoard>;
  tagged?: { lobby: string; difficulty: string; host: boolean }; taggedElsewhere?: string;
  nearby: MissionNearby[];
  /** How this player enters: alone (a crew of one) or with their crew; only its leader tags in. */
  entry?: MissionEntry;
}
export interface MissionEntry {
  crew?: string; size: number; leader?: string; leads: boolean;
  /** Open to matchmaking: strangers fill the empty places (the crew's flag, or the solo player's). */
  matchmaking: boolean;
  /** The lobby this player is tagged in takes strangers. */
  open: boolean;
}
export interface MissionUpdate { session: string; state?: MissionDialogPayload; closed?: boolean }
/** One member on the crew frame. `busy`: what keeps them (mission, lobby = tagged on a board, activity),
 *  `far`: out of reach of the viewer (another instance, or past the configured distance). */
export interface PartyMember {
  id: number; name: string; leader: boolean; tier: number; you?: boolean;
  state?: "alive" | "down" | "dead"; busy?: "mission" | "lobby" | "activity"; busyLabel?: string; far?: boolean;
  /** The member's shown title and its rarity (titles.lua), when they show one. */
  title?: string; titleRarity?: TitleRarity;
}
export interface CrewInvite { party: string; from: number; fromName: string; expiresInMs: number }
/** The crew (server/modules/parties.lua "party" state). Without `id` the player is alone. `keys`: the
 *  effective invite keys, added by client/core/crew.lua. */
export interface PartyState {
  you?: number; id?: string; leader?: number; members?: PartyMember[];
  pending?: Array<{ id: number; name: string; expiresInMs?: number }>;
  invites: CrewInvite[]; maxSize: number; inviteSeconds?: number; matchmaking?: boolean;
  keys?: { accept?: string; decline?: string };
}
/** The queue panel's view (server/modules/activity_queue.lua Q.view). Times are from the push:
 *  the page counts the wait up and the start down on its own. `need`/`max`: "3 / 6" or "3 / 2-8". */
export type QueueState = false | {
  v: 1; id: string; label: string; mode?: string; count?: number; need?: number; max?: number;
  sinceMs: number; startsInMs?: number; state: "waiting" | "starting" | "joining";
  /** Queued by the crew leader: leaving takes only you out. */
  crew?: boolean; source: "core" | "provider" | "mission";
};
export type MissionQueueState = false
  | { running: false; title: string; difficulty: string; difficultyId: string; count: number; min: number; max: number; state: "open" | "countdown"; countdownMs?: number; host: boolean; open?: boolean }
  | { running: true; instance: string; title: string; difficulty: string; difficultyId: string; endsInMs: number; members: number; squad: MissionSquadMember[]; objective?: MissionObjective };
/** An authored mission's progress for this operator (server/modules/mission_engine.lua view()). Countdowns are from the push. */
export interface MissionObjective {
  kind: "eliminate" | "waves"; phase: "staging" | "fight" | "intermission" | "wave" | "done";
  enemiesLeft: number; kills: number; lives: number; startsInMs?: number;
  wave?: number; waves?: number; nextWaveInMs?: number;
  checkpoints?: Array<{ label: string; reached: boolean; required: boolean }>;
  outOfBoundsMs?: number; respawnInMs?: number; spectating?: boolean;
  /** The kit choice (like the raid's ready check): the list while it can be changed (briefing, down),
   *  this operator's pick, and during the briefing whether they said ready. */
  loadouts?: Array<{ id: string; label: string; blurb: string }>; loadout?: string; canChoose?: boolean;
  ready?: boolean; readyCount?: number; squadSize?: number;
}
/** The raid (server/modules/mission_chimera.lua view()), plus one-shot fields. */
export interface RaidState {
  instance?: string; phase: "ready" | "launch" | "placing" | "intro" | "fight" | "victory" | "wipe" | "ended";
  title?: string; difficulty?: string; difficultyId?: string; result?: "victory" | "failed";
  operators?: Array<{ id: number; name: string; ready: boolean; down: boolean; loaded?: boolean }>;
  loaded?: boolean; arena?: { x: number; y: number; z: number }; bossId?: string;
  readyEndsInMs?: number; launchInMs?: number; readyKey?: string;
  boss?: { healthPercent: number; phase: string; label: string; enraged: boolean; repairing?: boolean; repairInMs?: number; target?: number; targetName?: string };
  adds?: number; lives?: number; respawnInMs?: number; out?: boolean; fightSeconds?: number; enrageInMs?: number;
  announce?: { title: string; body: string; tone: "info" | "warning" | "danger" | "success"; at: number };
  intro?: { boss: { x: number; y: number; z: number }; durationMs: number; difficulty: string; operators: number };
  loadouts?: Array<{ id: string; label: string; blurb: string }>; loadout?: string;
}
/** One operator on the crew frame of a running mission. `state`: alive, down (waiting for a revive), dead, recovering. */
export interface MissionSquadMember { id: number; name: string; citizen: string; host: boolean; health: number; maxHealth: number; armor: number; state: "alive" | "down" | "dead" | "recovering" }
export type UiStatePatch = Partial<UiState>;

/** F1 > Maneki-neko (server/modules/maneki.lua M.collection): one slot per cat in the city, in
 *  the order the staff hid them. A found slot is "id|district|at|how|x|y|z"; a slot not found is
 *  "" and carries nothing. `intro`: the panel has never explained itself to this character. */
export interface ManekiDialogPayload {
  kind: "maneki"; slots: string[]; found: number; total: number; reward: number;
  milestones: Array<{ count: number; cash: number; items?: Array<{ name: string; count: number; label: string }> }>; completeMin: number;
  title?: { id: string; label: string }; intro?: boolean; shotRange?: number; enabled?: boolean;
}

/** The staff placement tool for the Maneki-neko, as client/core/maneki_editor.lua publishes it. */
export interface ManekiToolState {
  active: boolean; scale?: number; yaw?: number; aim?: boolean; hovered?: string; hoveredFound?: boolean;
  nearby?: number; message?: string; ok?: boolean;
}

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
  /** externalTop: op77_weaponhud's hologram is up and reaches this high (px from the screen bottom); 0 = not shown. */
  weapon?: { active: boolean; externalTop?: number; reserve?: number; hands?: Array<{
    hand: "right" | "left"; label: string; magazine?: number; capacity?: number; reloading: boolean;
  }> };
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
export interface HotbarState { ready: boolean; inventoryId?: string; revision: number; items: InventoryItem[]; visible: boolean; showKey?: string; slotKeys?: string[] }
export interface InventorySnapshot {
  id: string; kind: "player" | "trunk" | "drop" | "stash" | "ground" | "housing"; label: string;
  slots: number; maxWeight: number; weight: number; items: InventoryItem[];
}
export interface InventoryDialogPayload { kind: "inventory"; left: InventorySnapshot; right: InventorySnapshot; toggleKey?: string }
export interface GrenadeState { ready: boolean; busy: boolean; revision: number; selected?: string; label?: string; count: number; error?: string }
export type ArmamentHand = "right" | "left";
export type ArmamentOperation = "state" | "equip" | "unequip" | "holster" | "ammo" | "sync" | "select";
/** A serialized weapon in the pockets, as the weapon wheel lists it. */
export interface ArsenalWeapon {
  slot: number; instanceId: string; name: string; label: string; class?: string; ammo?: string; ammoLabel?: string;
  rounds?: number; image?: string; dual?: boolean; hand?: "right" | "left";
  /** A temporary kit weapon (instanceId "kit:1" / "kit:2"): a mission's, or a match's with kitScope "match". */
  kit?: boolean;
  kitScope?: "match";
}
export interface ArmamentWeapon {
  instanceId: string; name: string; label: string; record: string; nativeSlot: 1 | 4;
  magazine?: number; capacity?: number; ammo?: string; class?: string; dual?: boolean;
}
export interface ArmamentState {
  ready: boolean; busy: boolean; revision: number;
  right?: ArmamentWeapon; left?: ArmamentWeapon;
  holstered?: boolean; arsenal?: ArsenalWeapon[];
  ammo: { pistol: { remaining: number; label: string; item?: string } } & Record<string, { remaining: number; label: string; item?: string } | undefined>;
  error?: string;
}
export interface ArmamentArgs { slot?: number; instanceId?: string; hand?: ArmamentHand; baseRevision?: number; unarmed?: boolean }
export interface ArmamentPending {
  operation: Exclude<ArmamentOperation, "state">; args: ArmamentArgs; mutation: string;
  uncertain: boolean;
}
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
  /** The Big Contract is offered: two couriers of one crew split one big order list (job_runs.lua Runs.startDuo). */
  duo?: boolean;
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
  /** A half of a Big Contract: the partner's name and which half (A or B). */
  duo?: { partner?: string; half?: string };
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
  /** Out and wrecked (destroyed / exploded / health 0): the tow charges the insurance excess. */
  wrecked?: boolean;
  /** Registration plate bought at the Auto Studio, and the fitted performance stage (0 = stock). */
  plate?: string; stage?: number;
}
export interface GarageDialogPayload {
  kind: "garage"; session: string; nextRequest: number;
  spot: { id: string; name: string }; vehicles: PersonalVehicle[]; maxOutside: number;
  impound?: { name: string; fees: { requested: number; destroyed?: number; lost: number; restart: number } };
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
export type DialogPayload = MissionDialogPayload | RentalDialogPayload | InventoryDialogPayload | ShopDialogPayload | JobCenterDialogPayload | GarageDialogPayload | DealershipDialogPayload | FuelDialogPayload | { kind: "support"; scope: "player" | "staff"; body?: string } | { kind: "housing"; admin: boolean } | { kind: "activities"; tab?: ActivitiesTab } | HallOfFameDialogPayload | GuideDialogPayload | { kind: "rooms" }
  | RecapDialogPayload | DailiesDialogPayload | ManekiDialogPayload | ParkourDialogPayload;

/** Johnny at The Crossing (server/modules/guide.lua): the dialog carries the index only;
 *  the search index and the topics follow as GuideMessage (features/guide/model.ts).
 *  `talk`: the dialogue's opening node (server/modules/guide_dialogue.lua), checked by
 *  normalizeOpening (features/guide/talk.ts); without it the FAQ opens as before. */
export interface GuideTopicSummary { id: string; title: string; icon?: string; blurb?: string; count: number }
export interface GuideDialogPayload {
  kind: "guide"; revision: string; npc: { name: string; title?: string; tag?: string };
  greeting: string[]; topics: GuideTopicSummary[]; keys?: Record<string, string>;
  talk?: { revision: string; root: string; node: unknown; farewell?: string };
}

export interface ActiveRental {
  spotId: string; spotName: string; key: string; label: string; price: number; paidWith: "cash" | "bank";
  image?: string;
  remainingMs: number; // at the time the state was pushed
  vehicleId?: number;
  extendPrice?: number; extendMinutes?: number; extensionsLeft?: number;
  warnMs?: number; // the countdown blinks (and shows how to extend) under this
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
  | { type: "raid.ready" }
  | { type: "raid.loadout"; id: string }
  | { type: "mission.loadout"; id: string }
  | { type: "mission.ready" }
  | { type: "mission.tag" | "mission.tagGroup"; session: string; difficulty: string }
  | { type: "mission.untag" | "mission.launch" | "mission.close"; session: string }
  | { type: "mission.matchmaking"; session: string; on: boolean }
  | { type: "party.invite" | "party.kick" | "party.promote"; target: number }
  | { type: "party.accept" | "party.decline"; party?: string }
  | { type: "party.leave" }
  | { type: "party.matchmaking"; on: boolean }
  | { type: "queue.leave"; from: "key" | "menu" | "panel" }
  | { type: "activities.control"; operation: "open" | "refresh" | "close" | "leave"; tab?: ActivitiesTab }
  | { type: "activities.control"; operation: "join"; id: string; from?: string; options?: Record<string, string> }
  | { type: "activities.control"; operation: "gps"; id: string }
  | { type: "activities.lobby"; operation: "fill" | "balance" | "cancel" | "start" }
  | { type: "activities.lobby"; operation: "friendly"; id: string; mode?: string; bots?: boolean }
  | { type: "activities.lobby"; operation: "move"; target: number; team?: number }
  | { type: "activities.lobby"; operation: "bots"; on: boolean }
  | { type: "activities.rooms"; operation: "open" | "leave" | "start" }
  | { type: "activities.rooms.close" }
  | { type: "activities.rooms"; operation: "create"; id: string; mode?: string; size?: number; private?: boolean }
  | { type: "activities.rooms"; operation: "join"; id?: number; code?: string }
  | { type: "activities.rooms"; operation: "kick"; target: number }
  | { type: "activities.rooms"; operation: "move"; target: number; team: number }
  | { type: "activities.rooms"; operation: "settings"; mode?: string; size?: number; private?: boolean }
  | { type: "halloffame.open" | "halloffame.tab"; tab?: HallOfFameTab; from?: string }
  | { type: "halloffame.refresh"; tab?: HallOfFameTab; key?: string }
  | { type: "halloffame.board"; key: string; tab: HallOfFameTab }
  | { type: "halloffame.close" }
  | { type: "recap.open" | "recap.close" }
  | { type: "dailies.open"; tab?: DailiesTab }
  | { type: "dailies.claim"; id: string }
  | { type: "dailies.swap"; slot: DailySlot }
  | { type: "dailies.refresh" }
  | { type: "maneki.open" }
  | { type: "maneki.intro" }
  | { type: "maneki.map"; id: string }
  | { type: "parkour.open"; course?: string }
  | { type: "parkour.board"; course: string; page: number }
  | { type: "parkour.start"; course: string }
  | { type: "parkour.gps"; course: string }
  | { type: "titles.select"; id: string }
  | { type: "guide.open"; from?: string }
  | { type: "guide.topic"; id: string }
  | { type: "guide.gps"; target: string }
  | { type: "guide.node"; id: string }
  | { type: "guide.panel"; panel: "halloffame" }
  | { type: "customization.open"; vehicle: string; garage: string }
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
  | { type: "rental.extend"; pay: "cash" | "bank" }
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
  | { type: "jobs.start"; from?: "menu"; duo?: boolean }
  | { type: "jobs.gps" }
  | { type: "jobs.locate"; job:string; stage:"collect"|"process"|"sell" }
  | { type: "jobs.cancel" }
  | { type: "staff.tp"; target: "me" | number; location: string }
  | { type: "staff.heal"; target: "me" | number }
  | { type: "staff.announce"; text: string }
  | { type: "staff.bring"; target: number }
  | { type: "voice.range"; range: "whisper" | "normal" | "shout" }
  | { type: "menu.close" };
