import assert from "node:assert/strict";
import test from "node:test";
import type { ActivitiesState, RoomView } from "../src/bridge/protocol.ts";
import {
  ROOMS_ACTION, ROOMS_ACTION_GAP_MS, ROOMS_CLOSE_ACTION, UNRANKED_LINE, cleanCode, crewLine, escapeAction, holdMs, isFreshResult, roomsScreen, hostGames, isFull, mapLine, nextTeam, normalizeRooms, roomColumns, sizeChoices, sizeLabel, slots, waitLine,
} from "../src/features/rooms/model.ts";

// As server/modules/activity_rooms.lua sends it (nil fields left out, empty lists as {}).
const state = (extra: Record<string, unknown> = {}) => normalizeRooms({
  enabled: true, eligible: true, full: false, games: [{ id: "games.tdm", teams: 2, least: 1, most: 6 }, { id: "arena.ffa", least: 2, most: 16 }],
  list: [{ id: 3, activity: "games.tdm", label: "Team Deathmatch", mode: "dust", modeLabel: "Dust", host: "Rosa", count: 3, max: 12, teams: 2 }], room: false, ...extra,
})!;
const room = (extra: Record<string, unknown> = {}) => state({
  room: { id: 3, activity: "games.tdm", label: "Team Deathmatch", host: "Rosa", count: 2, max: 4, private: false, mine: true, size: 2, least: 1, most: 6,
    teams: [[{ id: 1, name: "Rosa", host: true }], [{ id: 2, name: "Kei" }]], ...extra },
}).room as RoomView;
const activities = (ids: string[]) => ({
  list: ids.map((id) => ({ id, label: id, kind: "pvp", modes: [], joinable: true })),
}) as unknown as ActivitiesState;

test("a pushed state is kept; Lua's empty lists and junk are read safely", () => {
  const s = state();
  assert.deepEqual([s.enabled, s.eligible, s.full, s.games.length, s.list.length, s.room], [true, true, false, 2, 1, false]);
  assert.equal(s.list[0]!.modeLabel, "Dust");
  assert.equal(normalizeRooms(undefined), undefined);
  assert.equal(normalizeRooms("rooms"), undefined);
  const empty = normalizeRooms({ enabled: true, eligible: false, reason: "Not now.", games: {}, list: {}, room: false })!;
  assert.deepEqual([empty.games, empty.list, empty.room, empty.reason], [[], [], false, "Not now."]);
  const junk = normalizeRooms({ games: [{ id: 1 }, { id: "x", least: 5, most: 2 }, null], list: [{ id: "a" }, null], room: { id: "a" } })!;
  assert.deepEqual([junk.games, junk.list, junk.room, junk.enabled], [[], [], false, false]);
});

test("a room: sides, a free-for-all, an empty side sent as {}", () => {
  const r = room();
  assert.equal(r.teams!.length, 2);
  assert.equal(r.teams![0]![0]!.host, true);
  assert.equal(r.players, undefined);
  assert.equal(room({ teams: [[{ id: 1, name: "Rosa" }], {}] }).teams![1]!.length, 0);
  const free = room({ teams: undefined, players: [{ id: 1, name: "Rosa" }, { id: "x" }] });
  assert.equal(free.teams, undefined);
  assert.equal(free.players!.length, 1, "a junk player is dropped");
  assert.equal(room({ code: "K7QMX", private: true }).code, "K7QMX");
});

test("the menu lists what both sides know, in the panel's order: a missing provider disappears", () => {
  const games = hostGames(state(), activities(["arena.ffa", "arena.duel", "games.tdm"]));
  assert.deepEqual(games.map((g) => g.id), ["arena.ffa", "games.tdm"]);
  assert.equal(games[1]!.teams, 2);
  assert.deepEqual(hostGames(state(), activities(["arena.duel"])), [], "not offered");
  assert.deepEqual(hostGames(state(), activities([])), [], "not registered");
  assert.deepEqual(hostGames(undefined, undefined), []);
});

test("sizes and counts", () => {
  assert.deepEqual(sizeChoices({ least: 2, most: 4 }), [2, 3, 4]);
  assert.equal(sizeLabel(3, 2), "3v3");
  assert.equal(sizeLabel(8, undefined), "8 PLAYERS");
  assert.equal(slots({ count: 3, max: 8 }), "3 / 8");
  assert.equal(isFull({ count: 8, max: 8 }), true);
  assert.equal(isFull({ count: 3, max: 8 }), false);
  assert.equal(isFull({ count: 0, max: 0 }), false);
});

test("what the room plays", () => {
  assert.equal(mapLine({ modeLabel: "Dust", mode: "dust" }, true), "Dust");
  assert.equal(mapLine({ mode: "dust" }, true), "dust");
  assert.equal(mapLine({}, true), "Any map");
  assert.equal(mapLine({}, false), "The course rotates");
});

test("a typed code is letters and digits, upper case, bounded", () => {
  assert.equal(cleanCode(" k7-qmx "), "K7QMX");
  assert.equal(cleanCode("abcdefghijkl"), "ABCDEFGH");
  assert.equal(cleanCode("é!"), "");
});

test("columns and moves: one per side, a free-for-all is one and moves nobody", () => {
  const r = room();
  assert.deepEqual(roomColumns(r).map((c) => [c.title, c.team, c.size, c.players.length]), [["TEAM A", 1, 2, 1], ["TEAM B", 2, 2, 1]]);
  assert.equal(nextTeam(r, 1), 2);
  assert.equal(nextTeam(r, 2), 1, "round");
  const free = room({ teams: undefined, players: [{ id: 1, name: "Rosa" }] });
  assert.deepEqual(roomColumns(free).map((c) => [c.title, c.team]), [["PLAYERS", undefined]]);
  assert.equal(nextTeam(free, 1), undefined);
});

test("the room says why it waits, and what it records", () => {
  assert.equal(waitLine(room({ issue: "Team B is empty." })), "Team B is empty.");
  assert.equal(waitLine(room()), "Ready when you are.");
  assert.match(waitLine(room({ mine: false })), /Rosa hosts/);
  assert.match(UNRANKED_LINE, /unranked and record nothing/);
});

test("two quick actions keep the server's gap", () => {
  assert.ok(ROOMS_ACTION_GAP_MS > 250);
  assert.equal(holdMs(undefined, 1000), 0);
  assert.equal(holdMs(1000, 1100), ROOMS_ACTION_GAP_MS - 100);
  assert.equal(holdMs(1000, 2000), 0);
});

test("the screens: Esc closes every one but the form, which goes back", () => {
  assert.equal(roomsScreen(undefined, false), "waiting");
  assert.equal(roomsScreen({ ...state(), enabled: false }, true), "closed");
  assert.equal(roomsScreen(state(), false), "browse");
  assert.equal(roomsScreen(state(), true), "create");
  const inRoom = { ...state(), room: room() };
  assert.equal(roomsScreen(inRoom, true), "room", "a room opened over the form");
  for (const screen of ["waiting", "closed", "browse", "room"] as const) assert.equal(escapeAction(screen), "close");
  assert.equal(escapeAction("create"), "back");
});

test("a result is for this menu only if it is newer than its opening or its last ask", () => {
  const openedAt = 5000;
  assert.equal(isFreshResult(undefined, openedAt), false);
  assert.equal(isFreshResult({ action: ROOMS_ACTION, at: 4000 }, openedAt), false, "the last session's text stays out");
  assert.equal(isFreshResult({ action: ROOMS_ACTION, at: 5000 }, openedAt), true);
  assert.equal(isFreshResult({ action: "activities.control", at: 6000 }, openedAt), false);
  assert.equal(isFreshResult({ at: 6000 }, openedAt), false);
});

test("closing has an action type of its own: the per-type limit cannot eat it after a click", () => {
  assert.notEqual(ROOMS_CLOSE_ACTION, ROOMS_ACTION);
});

test("the menu says what a join does with the crew", () => {
  const member = (id: number) => ({ id, name: `P${id}`, leader: false, tier: 1 });
  const trio = [member(1), member(2), member(3)];
  assert.equal(crewLine(undefined), undefined);
  assert.equal(crewLine({ you: 1 }), undefined, "no crew");
  assert.equal(crewLine({ you: 1, leader: 1, members: [member(1)] }), undefined, "a crew of one still waiting for answers");
  assert.match(crewLine({ you: 1, leader: 1, members: trio })!, /comes with you: 2 members/);
  assert.match(crewLine({ you: 1, leader: 1, members: trio.slice(0, 2) })!, /1 member,/);
  assert.match(crewLine({ you: 2, leader: 1, members: trio })!, /comes with you: 2 members/, "a member brings it too");
});
