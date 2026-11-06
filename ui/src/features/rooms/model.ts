import type { ActivitiesState, ActivityEntry, PartyState, RoomGame, RoomListing, RoomPlayer, RoomView, RoomsState } from "@/bridge/protocol";

/* The hosting menu (server/modules/activity_rooms.lua), read once per push. No runtime
   import from "@/": the model tests run under node --test (tests/rooms-model.test.ts). */

export const ROOMS_ACTION = "activities.rooms";
/** The menu closing: its own type, so a click just before it can never throttle it away. */
export const ROOMS_CLOSE_ACTION = "activities.rooms.close";
/** The server drops a second action of one type within 250 ms (framework.lua). */
export const ROOMS_ACTION_GAP_MS = 260;
export const UNRANKED_LINE = "Matches here are unranked and record nothing: no stats, no Hall of Fame, no pay, no reputation.";
export const CODE_MAX = 8;

const whole = (value: unknown): number | undefined => typeof value === "number" && Number.isFinite(value) ? Math.floor(value) : undefined;
const text = (value: unknown, max: number): string | undefined => {
  if (typeof value !== "string") return undefined;
  const s = value.replace(/[\u0000-\u001f]+/g, " ").trim();
  return s ? s.slice(0, max) : undefined;
};
/** Lua sends an empty list as {}. */
const list = (value: unknown): unknown[] => Array.isArray(value) ? value : [];

function normalizePlayers(raw: unknown): RoomPlayer[] {
  const out: RoomPlayer[] = [];
  for (const item of list(raw)) {
    const p = item as Record<string, unknown> | null;
    const id = whole(p?.id), name = text(p?.name, 64);
    if (id !== undefined && name) out.push({ id, name, host: p?.host === true || undefined });
  }
  return out;
}
function normalizeListing(raw: unknown): RoomListing | undefined {
  const r = raw as Record<string, unknown> | null;
  const id = whole(r?.id), activity = text(r?.activity, 64), label = text(r?.label, 64);
  if (id === undefined || !activity || !label) return undefined;
  return { id, activity, label, mode: text(r?.mode, 48), modeLabel: text(r?.modeLabel, 48), host: text(r?.host, 64) ?? "?",
    count: whole(r?.count) ?? 0, max: whole(r?.max) ?? 0, teams: whole(r?.teams) };
}
function normalizeRoom(raw: unknown): RoomView | false {
  if (!raw || typeof raw !== "object") return false;
  const r = raw as Record<string, unknown>;
  const base = normalizeListing({ ...r, teams: undefined });
  if (!base) return false;
  const teams = Array.isArray(r.teams) ? r.teams.map(normalizePlayers) : undefined;
  return { ...base, private: r.private === true, code: text(r.code, CODE_MAX), mine: r.mine === true, size: whole(r.size) ?? 0,
    least: whole(r.least), most: whole(r.most), issue: text(r.issue, 200), teams, players: teams ? undefined : normalizePlayers(r.players) };
}
export function normalizeRooms(raw: unknown): RoomsState | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r = raw as Record<string, unknown>;
  const games: RoomGame[] = [];
  for (const item of list(r.games)) {
    const g = item as Record<string, unknown> | null;
    const id = text(g?.id, 64), least = whole(g?.least), most = whole(g?.most);
    if (id && least !== undefined && most !== undefined && most >= least) games.push({ id, least, most, teams: whole(g?.teams) });
  }
  return { enabled: r.enabled === true, eligible: r.eligible === true, reason: text(r.reason, 200), full: r.full === true, games,
    list: list(r.list).map(normalizeListing).filter((x): x is RoomListing => !!x), room: normalizeRoom(r.room) };
}

/** A game of the menu: the provider's activity (its label, maps, status), offered by rooms. */
export interface HostGame extends RoomGame { activity: ActivityEntry }
/** What can be hosted now, in the panel's order: an activity gone from either side is gone here. */
export function hostGames(rooms: RoomsState | undefined, activities: ActivitiesState | undefined): HostGame[] {
  const out: HostGame[] = [];
  for (const activity of activities?.list ?? []) {
    const game = rooms?.games.find((g) => g.id === activity.id);
    if (game) out.push({ ...game, activity });
  }
  return out;
}
/** The sizes a host may pick. */
export function sizeChoices(game: Pick<RoomGame, "least" | "most">): number[] {
  const out: number[] = [];
  for (let n = game.least; n <= game.most; n++) out.push(n);
  return out;
}
export function sizeLabel(size: number, teams: number | undefined): string {
  return teams ? Array.from({ length: teams }, () => size).join("v") : `${size} PLAYERS`;
}
/** "3 / 8", the room's players against its places. */
export function slots(r: Pick<RoomListing, "count" | "max">): string { return `${r.count} / ${r.max}`; }
export function isFull(r: Pick<RoomListing, "count" | "max">): boolean { return r.max > 0 && r.count >= r.max; }
/** A map's name, or what the room plays when the host left it open. */
export function mapLine(r: Pick<RoomListing, "modeLabel" | "mode">, hasMaps: boolean): string {
  return r.modeLabel ?? r.mode ?? (hasMaps ? "Any map" : "The course rotates");
}
/** What a typed code may hold: letters and digits, upper case. */
export function cleanCode(raw: string): string { return raw.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, CODE_MAX); }

export interface RoomColumn { key: string; team?: number; title: string; players: RoomPlayer[]; size: number }
/** One column per side; a free-for-all is one column. */
export function roomColumns(room: RoomView): RoomColumn[] {
  if (room.teams) return room.teams.map((players, i) => ({ key: `t${i + 1}`, team: i + 1, title: `TEAM ${String.fromCharCode(65 + i)}`, players, size: room.size }));
  return [{ key: "all", title: "PLAYERS", players: room.players ?? [], size: room.size }];
}
/** The side a click sends a player to: the next one, round. */
export function nextTeam(room: RoomView, team: number): number | undefined {
  const n = room.teams?.length ?? 0;
  return n > 1 ? team % n + 1 : undefined;
}
/** What a join does with the player's crew: the whole crew comes. The server reads the crew
    itself; this only says so. */
export function crewLine(party: Pick<PartyState, "you" | "leader" | "members"> | undefined): string | undefined {
  const others = (party?.members?.length ?? 0) - 1;
  if (others < 1) return undefined;
  return `Your crew comes with you: ${others} ${others === 1 ? "member" : "members"}, on one team in a team game.`;
}
/** What the footer says to a member who cannot start it. */
export function waitLine(room: RoomView): string {
  return room.mine ? room.issue ?? "Ready when you are." : `${room.host} hosts. You are pulled in when they start.`;
}
export type RoomsScreen = "waiting" | "closed" | "room" | "create" | "browse";
/** What the body shows. A change moves the focus off what held it: the root takes it back. */
export function roomsScreen(rooms: RoomsState | undefined, creating: boolean): RoomsScreen {
  if (!rooms) return "waiting";
  if (!rooms.enabled) return "closed";
  if (rooms.room) return "room";
  return creating ? "create" : "browse";
}
/** Esc: the form goes back to the list, any other screen closes. */
export function escapeAction(screen: RoomsScreen): "back" | "close" { return screen === "create" ? "back" : "close"; }
/** A result for this menu, newer than its last ask (or than its opening: a result outlives the menu). */
export function isFreshResult(result: { action?: string; at: number } | undefined, askedAt: number): boolean {
  return !!result && result.action === ROOMS_ACTION && result.at >= askedAt;
}
/** How long to hold an action so the server's per-type limit never eats it. */
export function holdMs(lastSentAt: number | undefined, at: number): number {
  return lastSentAt === undefined ? 0 : Math.max(0, ROOMS_ACTION_GAP_MS - (at - lastSentAt));
}
