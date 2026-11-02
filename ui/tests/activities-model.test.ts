import assert from "node:assert/strict";
import test from "node:test";
import { formatClock, formatTime, mineLine, normalizeActivities, statusLine } from "../src/features/activities/model.ts";

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
