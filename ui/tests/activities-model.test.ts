import assert from "node:assert/strict";
import test from "node:test";
import { alliesFor, botsAllowed, fillDue, formatClock, formatTime, friendlyColumns, joinLabel, joinOptions, mineLine, moveTarget, normalizeActivities,
  queuedTitle, rankedLine, searchCount, searchScope, statusLine } from "../src/features/activities/model.ts";

const entry = {
  id: "race.trial", label: "Time Trial", kind: "race", description: "", minPlayers: 1, maxPlayers: 1,
  phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: true, modes: {}, modeKey: "mode", top: {},
} as never;

test("Lua's empty tables become arrays, false stays false", () => {
  const state = normalizeActivities({ enabled: true, hub: { name: "The Crossing" }, list: [entry], current: false, queued: false,
    mission: false, eligible: true, reputation: { today: 0, dailyCap: 250, maxPerResult: 50 }, nearby: {}, contracts: {} } as never)!;
  assert.deepEqual(state.nearby, []);
  assert.deepEqual(state.contracts, []);
  assert.deepEqual(state.list[0]!.modes, []);
  assert.deepEqual(state.list[0]!.top, []);
  assert.equal(state.current, false);
  assert.equal(normalizeActivities(undefined), undefined);
  const empty = normalizeActivities({ enabled: true, list: {} } as never)!;
  assert.deepEqual(empty.list, []);
  assert.equal(empty.hub.name, "The Crossing");
});

test("times and clocks", () => {
  assert.equal(formatTime(61234), "1:01.234");
  assert.equal(formatTime(undefined), "—");
  assert.equal(formatTime(Number.NaN), "—");
  assert.equal(formatClock(135000), "02:15");
  assert.equal(formatClock(-5), "00:00");
});

test("status and record lines", () => {
  const a = { ...(entry as object), modes: [], top: [] } as never;
  assert.equal(statusLine(a), "OPEN · SOLO OK");
  assert.equal(statusLine({ ...(a as object), joinable: false } as never), "CLOSED FOR NOW");
  assert.equal(statusLine({ ...(a as object), phase: "running", players: 3 } as never), "3 PLAYING");
  assert.equal(statusLine({ ...(a as object), detail: "Round 2/3" } as never), "Round 2/3");
  assert.equal(mineLine(a, undefined), "Not played yet.");
  assert.equal(mineLine(a, { played: 3, wins: 1, kills: 0, deaths: 0, reputation: 10, bestTimeMs: 61234 }), "3 played · 1 won · best 1:01.234");
});

const duel = { ...(entry as object), id: "arena.duel", label: "Duel", kind: "pvp", minPlayers: 2, maxPlayers: 2, byTime: false, modes: [], top: [],
  lobby: { bots: true, friendly: true, queue: true, brackets: true } } as never;
const teams = { ...(duel as object), id: "arena.teams", label: "Team Arena", minPlayers: 4, maxPlayers: 6,
  modes: [{ id: "2v2", label: "2v2" }, { id: "3v3", label: "3v3", botFill: false }] } as never;
const pve = { ...(entry as object), id: "arena.pve", label: "Combat Zone PvE", kind: "pvp", pve: true, minPlayers: 1, maxPlayers: 6, byTime: false,
  modes: [], top: [], lobby: { allies: true, seats: 6 } } as never;
const plain = { ...(entry as object), id: "turf.pve", kind: "pvp", pve: true, maxPlayers: 8, modes: [], top: [] } as never;

test("bots: the provider's botFill (lobby.bots) and a mode's opt-out", () => {
  assert.equal(botsAllowed(duel, undefined), true);
  assert.equal(botsAllowed(teams, "2v2"), true);
  assert.equal(botsAllowed(teams, "3v3"), false, "3v3 is real players only");
  assert.equal(botsAllowed({ ...(duel as object), lobby: { friendly: true } } as never, undefined), false, "no botFill: no bots");
  assert.equal(alliesFor(pve, 4), 2, "6 seats, crew of 4: 2 allied bots");
  assert.equal(alliesFor(pve, 1), 5);
  assert.equal(alliesFor(pve, 8), 0);
  assert.equal(alliesFor(plain, 1), 0, "no allies offered");
});

test("join options: mode, difficulty, bots only where offered", () => {
  assert.deepEqual(joinOptions(teams, "2v2", undefined, true), { mode: "2v2", bots: "true" });
  assert.deepEqual(joinOptions(teams, "3v3", undefined, true), { mode: "3v3" }, "a mode without bots never sends them");
  assert.deepEqual(joinOptions(pve, undefined, "hard", true), { difficulty: "hard", bots: "true" });
  assert.deepEqual(joinOptions(plain, undefined, "standard", true), { difficulty: "standard" });
  assert.equal(joinOptions(duel, undefined, undefined, false), undefined);
});

test("what a join counts for, and its button", () => {
  assert.match(rankedLine(duel, undefined, false, 1), /^RANKED · humans only · players near your cyberware rank first$/);
  assert.match(rankedLine(duel, undefined, true, 1), /^UNRANKED/);
  assert.match(rankedLine(teams, "3v3", true, 1), /^RANKED/, "3v3 ignores the bots toggle");
  assert.match(rankedLine(pve, undefined, true, 4), /^2 allied bots fight beside you/);
  assert.equal(rankedLine(pve, undefined, false, 4), "PvE · reputation and pay");
  assert.equal(joinLabel(duel, undefined, false, false, false), "FIND A RANKED MATCH");
  assert.equal(joinLabel(duel, undefined, true, false, true), "PLAY WITH BOTS WITH THE CREW");
  assert.equal(joinLabel(pve, undefined, true, false, false), "JOIN");
  assert.equal(joinLabel(duel, undefined, false, true, false), "SWITCH TO THIS ONE");
});

test("the ranked search strip: count, scope, the fill offer", () => {
  const q = { id: "arena.duel", label: "Duel", sinceMs: 40000, ranked: true, lead: true,
    search: { found: 1, needed: 2, scope: "near" as const, widenInMs: 20000, bracket: 2 }, fillInMs: 80000 };
  assert.equal(queuedTitle(q), "SEARCHING · RANKED DUEL");
  assert.equal(searchCount(q), "1/2 PLAYERS");
  assert.equal(searchCount({ ...q, search: { found: 5, needed: 2 } }), "2/2 PLAYERS");
  assert.equal(searchScope(q), "NEAR YOUR RANK");
  assert.equal(searchScope({ ...q, search: { ...q.search, scope: "all" } }), "ALL RANKS");
  assert.equal(searchCount({ ...q, search: {} }), "", "a search the server lost: nothing shown");
  assert.equal(fillDue(q, 79000), false);
  assert.equal(fillDue(q, 80000), true, "the timer of the push runs out");
  assert.equal(fillDue({ ...q, lead: false }, 90000), false, "a crew member never decides on bots");
  assert.equal(fillDue({ ...q, fillInMs: undefined }, 999999), false, "no bots for this activity: no offer");
  assert.equal(queuedTitle({ ...q, search: undefined, match: true, ranked: false }), "BOT MATCH · JOINING DUEL");
  assert.equal(queuedTitle({ ...q, search: undefined, match: true, ranked: false, friendly: true, mode: "2v2" }), "FRIENDLY · JOINING DUEL 2V2");
  assert.equal(queuedTitle({ ...q, search: undefined, match: true }), "MATCH FOUND · JOINING DUEL");
  assert.equal(queuedTitle({ ...q, search: undefined }), "WAITING FOR DUEL");
});

test("the friendly set-up: Lua's empty teams, columns, moves", () => {
  const state = normalizeActivities({ enabled: true, list: {}, friendly: { id: "arena.teams", label: "Team Arena", mode: "2v2", bots: true, canBots: true,
    shape: "teams", size: 2, leader: "Vi", mine: true, bench: {}, teams: [[{ id: 7, name: "Vi", tier: 2 }], {}], teamBots: [1] } } as never)!;
  const f = state.friendly as Exclude<typeof state.friendly, false | undefined>;
  assert.deepEqual(f.teams, [[{ id: 7, name: "Vi", tier: 2 }], []]);
  assert.deepEqual(f.bench, []);
  assert.deepEqual(f.teamBots, [1, 0], "one count per team");
  const cols = friendlyColumns(f);
  assert.deepEqual(cols.map((c) => [c.title, c.team, c.bots, c.size]), [["TEAM A", 1, 1, 2], ["TEAM B", 2, 0, 2], ["BENCH", 0, 0, undefined]]);
  assert.equal(moveTarget(cols, 0, 1), 2);
  assert.equal(moveTarget(cols, 1, 1), 0, "past the last team: the bench");
  assert.equal(moveTarget(cols, 0, -1), undefined);
  const ffa = friendlyColumns({ id: "arena.ffa", label: "Combat Zone", bots: false, canBots: false, shape: "ffa", size: 0, leader: "Vi", mine: true,
    bench: [], players: [{ id: 7, name: "Vi", tier: 2 }], enemies: 4 });
  assert.deepEqual(ffa.map((c) => [c.title, c.team, c.bots]), [["PLAYING", 1, 0], ["BENCH", 0, 0]], "bots off: no AI shown");
  assert.equal(normalizeActivities({ enabled: true, list: {} } as never)!.friendly, false);
});
