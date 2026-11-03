import assert from "node:assert/strict";
import test from "node:test";
import {
  cleanNote, formatCell, formatClock, groupRows, headcount, mvpRow, mvpStats, nextSort, normalizeRecap, outcomeTag, resultLine, rewardLines,
  scoreLine, sortRows,
} from "../src/features/recap/model.ts";

// As server/modules/recap.lua sends it: zeros left out, empty tables as {}, bots negative.
const ffa = () => normalizeRecap({
  kind: "recap", id: "arena.ffa|arena:7:3@1", source: "activity", mode: "Arena FFA", modeKind: "pvp", detail: "Round 3", durationMs: 120000,
  result: { label: "#2", tone: "neutral", placement: 2, of: 5 }, you: 1,
  columns: ["placement", "kills", "deaths", "damage", "dps", "headshots", "score", "nonsense", "kills"],
  rows: [
    { id: 3, name: "Kei", placement: 1, kills: 9, deaths: 1, damage: 2400, dps: 20, headshots: 3, score: 950 },
    { id: 1, name: "Yuki", placement: 2, kills: 6, deaths: 2, damage: 1800, dps: 15, score: 640 },
    { id: -1, name: "[BOT] Viper", bot: true, placement: 3, kills: 4, deaths: 4, damage: 900, dps: 7.5, score: 400 },
    { id: 2, name: "Jax", placement: 4, deaths: 5, score: 10, left: true },
    { id: -2, placement: 5, deaths: 6 },
    { name: "no id" },
  ],
  total: 5, lines: {}, sides: {}, mvp: { id: 3, by: "score" },
  rewards: { eddies: 875, eddiesReason: "pvp", eddiesNote: "#2 of 5 · 10 min", reputation: 40, hof: [{ board: "Most kills", before: 18, rank: 12 }, { rank: 3 }] },
})!;

test("Lua's empty tables become arrays; junk rows and columns are dropped; zeros read 0", () => {
  const p = ffa();
  assert.equal(p.rows.length, 5, "the row without an id is dropped");
  assert.deepEqual(p.columns, ["placement", "kills", "deaths", "damage", "dps", "headshots", "score"], "unknown and repeated columns dropped");
  assert.deepEqual(p.lines, []);
  assert.deepEqual(p.sides, []);
  assert.equal(p.rows[4]!.bot, true, "a negative id is a bot");
  assert.equal(p.rows[4]!.name, "Bot");
  assert.equal(formatCell("kills", p.rows[3]!, p.modeKind), "0", "a count left out is zero");
  assert.equal(formatCell("dps", p.rows[3]!, p.modeKind), "—", "no damage: no DPS");
  assert.equal(p.rewards.hof?.length, 1, "a Hall of Fame line without a board is dropped");
  assert.equal(normalizeRecap({ kind: "halloffame" }), undefined);
  assert.equal(normalizeRecap(null), undefined);
  // no columns from the server: the ones the rows carry
  const bare = normalizeRecap({ kind: "recap", rows: [{ id: 4, name: "A", kills: 2, captures: 1 }] })!;
  assert.deepEqual(bare.columns, ["kills", "captures"]);
  assert.equal(bare.result.label, "DONE");
  assert.equal(bare.result.tone, "neutral");
  assert.equal(bare.source, "activity");
  // a detail that repeats the mode is not shown twice
  assert.equal(normalizeRecap({ kind: "recap", mode: "Turf War", detail: "turf war", rows: [] })!.detail, undefined);
  assert.equal(normalizeRecap({ kind: "recap", mode: "Turf War", detail: "Gang Sweep", rows: [] })!.detail, "Gang Sweep");
});

test("cells read in their unit", () => {
  const row = { id: 1, name: "A", placement: 3, damage: 12345.4, dps: 7.25, share: 41.5, bossShare: 40, holdS: 125, timeMs: 185412, bestLapMs: 61034 };
  assert.equal(formatCell("placement", row), "#3");
  assert.equal(formatCell("damage", row), "12,345");
  assert.equal(formatCell("dps", row), "7.3");
  assert.equal(formatCell("share", row), "41.5%");
  assert.equal(formatCell("bossShare", row), "40%");
  assert.equal(formatCell("holdS", row), "2:05");
  assert.equal(formatCell("timeMs", row, "race"), "3:05.412", "a race time to the millisecond");
  assert.equal(formatCell("timeMs", row, "chase"), "3:05", "a time lasted, to the second");
  assert.equal(formatCell("bestLapMs", row), "1:01.034");
  assert.equal(formatCell("timeMs", { id: 2, name: "B" }, "race"), "—", "never finished");
  assert.equal(formatClock(3723000), "1:02:03");
  assert.equal(formatClock(59_400), "0:59");
});

test("sorting: best first, again reverses, blanks last, ties keep the match order", () => {
  const p = ffa();
  assert.deepEqual(sortRows(p.rows, {}).map((r) => r.id), [3, 1, -1, 2, -2], "no column: the server's order");
  let s = nextSort({}, "deaths");
  assert.deepEqual(s, { column: "deaths" });
  assert.deepEqual(sortRows(p.rows, s).map((r) => r.id), [3, 1, -1, 2, -2], "fewest deaths first");
  s = nextSort(s, "deaths");
  assert.deepEqual(s, { column: "deaths", reverse: true });
  assert.deepEqual(sortRows(p.rows, s).map((r) => r.id), [-2, 2, -1, 1, 3]);
  assert.deepEqual(sortRows(p.rows, nextSort(s, "kills")).map((r) => r.id), [3, 1, -1, 2, -2], "another column: best first again");
  // a blank value (DPS without damage) goes last both ways
  assert.deepEqual(sortRows(p.rows, { column: "dps" }).map((r) => r.id), [3, 1, -1, 2, -2]);
  assert.deepEqual(sortRows(p.rows, { column: "dps", reverse: true }).map((r) => r.id), [-1, 1, 3, 2, -2]);
  assert.deepEqual(nextSort({ column: "kills" }, undefined), {}, "PLAYER restores the match order");
  // a race: the lowest time first, the DNF last; a chase: the longest time first
  const race = [{ id: 1, name: "A", timeMs: 190000 }, { id: 2, name: "B" }, { id: 3, name: "C", timeMs: 185000 }];
  assert.deepEqual(sortRows(race, { column: "timeMs" }, "race").map((r) => r.id), [3, 1, 2]);
  assert.deepEqual(sortRows(race, { column: "timeMs" }, "chase").map((r) => r.id), [1, 3, 2]);
});

test("sides: grouped in the server's order, the winner marked, strays last", () => {
  const p = normalizeRecap({
    kind: "recap", source: "activity", mode: "Team Arena", you: 5, result: { label: "WIN", tone: "win" },
    sides: [{ id: 1, label: "Team A", score: 2 }, { id: 2, label: "Team B", score: 1 }], winnerSide: 1,
    rows: [{ id: 5, name: "Me", side: 1, kills: 3 }, { id: 6, name: "Them", side: 2, kills: 5 }, { id: -1, name: "Bot", side: 1 }, { id: 7, name: "Lost" }],
  })!;
  const groups = groupRows(p, sortRows(p.rows, { column: "kills" }));
  assert.deepEqual(groups.map((g) => g.key), ["side-1", "side-2", "other"]);
  assert.deepEqual(groups[0]!.rows.map((r) => r.id), [5, -1]);
  assert.equal(groups[0]!.won, true);
  assert.equal(groups[1]!.won, undefined);
  assert.equal(scoreLine(p), "TEAM A 2 - 1 TEAM B");
  assert.equal(headcount(p), "3 PLAYERS · 1 BOT");
  // one side or none: one group
  const solo = ffa();
  assert.deepEqual(groupRows(solo, solo.rows).map((g) => g.key), ["all"]);
  assert.equal(scoreLine(solo), undefined);
});

test("header facts, outcome tags, the MVP", () => {
  const p = ffa();
  assert.equal(resultLine(p), "OF 5", "under a #2 result, the field only");
  assert.equal(resultLine({ ...p, result: { label: "WIN", tone: "win", placement: 1, of: 6 } }), "#1 OF 6");
  assert.equal(resultLine({ ...p, result: { label: "FINISHED", tone: "win", placement: 1, of: 1 } }), "#1");
  assert.equal(resultLine({ ...p, result: { label: "COMPLETE", tone: "win" } }), undefined);
  assert.equal(p.rows[2]!.name, "Viper", "a bot's [BOT] prefix goes: the BOT badge says it");
  assert.equal(headcount(p), "3 PLAYERS · 2 BOTS");
  const cut = normalizeRecap({ kind: "recap", rows: [{ id: 1, name: "A" }, { id: -1 }], total: 40 })!;
  assert.equal(headcount(cut), "40 ON THE BOARD · TOP 2 SHOWN");
  assert.equal(outcomeTag(p.rows[3]!), "LEFT");
  assert.equal(outcomeTag({ id: 1, name: "A", outcome: "dnf" }), "DNF");
  assert.equal(outcomeTag({ id: 1, name: "A", outcome: "escaped" }), "ESCAPED");
  assert.equal(outcomeTag({ id: 1, name: "A" }), undefined);
  const mvp = mvpRow(p)!;
  assert.equal(mvp.name, "Kei");
  assert.deepEqual(mvpStats(p, mvp).map((s) => `${s.head} ${s.value}`), ["K 9", "D 1", "DMG 2,400"], "the placement is not one of its numbers");
  assert.equal(mvpRow({ ...p, mvp: { id: 99 } }), undefined, "an MVP not on the board shows no card");
});

test("the rewards line reads what the paying modules reported", () => {
  const p = ffa();
  assert.deepEqual(rewardLines(p.rewards).map((l) => `${l.label}|${l.value}|${l.note ?? ""}`), [
    "EDDIES|+€$ 875|#2 of 5 · 10 min",
    "REPUTATION|+40 REP|",
    "HALL OF FAME|MOST KILLS #12|Up from #18.",
  ]);
  assert.deepEqual(rewardLines({ test: true }).map((l) => l.value), ["NO REWARDS"], "TEST: nothing else, even if a module reported");
  const none = rewardLines({ eddies: 0, eddiesReason: "bots", reputation: 0, reputationCapped: true });
  assert.deepEqual(none.map((l) => `${l.label}|${l.value}|${l.note}`), ["EDDIES|NONE|Bots took part: no pay.", "REPUTATION|+0 REP|Reputation limit reached for now."]);
  // a mission at a repeat rate: the reason and the module's own words
  const repeat = rewardLines({ eddies: 600, eddiesReason: "cooldown", eddiesNote: " (25% of €$ 2,400: this job paid you in full less than 30 min ago)" });
  assert.equal(repeat[0]!.note, "Repeat run: reduced pay. · 25% of €$ 2,400: this job paid you in full less than 30 min ago");
  const tier = rewardLines({ reputation: 180, tier: { tier: 3, name: "Solo", points: 2140, next: 3000, nextName: "Legend", up: true } });
  assert.deepEqual(tier.map((l) => `${l.label}|${l.value}|${l.note ?? ""}`), ["REPUTATION|+180 REP|", "TIER UP|TIER 3 · SOLO|2,140 / 3,000 REP to Legend"]);
  assert.equal(rewardLines({ tier: { tier: 5 } })[0]!.note, "Top tier reached.");
  assert.deepEqual(rewardLines({ hof: [{ board: "Wins", rank: 9 }] }).map((l) => l.note), ["New on the board."]);
  assert.deepEqual(rewardLines({}, true).map((l) => `${l.value}|${l.note}`), ["NONE|Unranked match: no pay."]);
  assert.deepEqual(rewardLines({ eddiesReason: "something_new" }).map((l) => l.note), ["something new"], "an unknown reason still reads");
  assert.equal(cleanNote(" (crew of 3, shared pot)"), "crew of 3, shared pot");
  assert.equal(cleanNote("   "), undefined);
});

test("a full board of 32 normalizes and sorts", () => {
  const rows = Array.from({ length: 32 }, (_, i) => ({ id: i < 16 ? i + 1 : -(i - 15), name: `P${i}`, kills: (i * 7) % 13, damage: (i * 131) % 977, placement: i + 1 }));
  const p = normalizeRecap({ kind: "recap", rows, total: 40, you: 3, columns: ["placement", "kills", "damage", "dps"] })!;
  assert.equal(p.rows.length, 32);
  const sorted = sortRows(p.rows, { column: "kills" });
  for (let i = 1; i < sorted.length; i++) assert.ok((sorted[i - 1]!.kills ?? 0) >= (sorted[i]!.kills ?? 0));
  assert.equal(headcount(p), "40 ON THE BOARD · TOP 32 SHOWN");
});
