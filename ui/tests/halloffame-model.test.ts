import assert from "node:assert/strict";
import test from "node:test";
import { formatValue, ladderLine, mineLine, normalizeHallOfFame, pinnedRank, podium, rankLabel, tied, updatedLine } from "../src/features/halloffame/model.ts";

test("Lua's empty tables become arrays; junk rows and boards are dropped", () => {
  const p = normalizeHallOfFame({ kind: "halloffame", title: "HALL OF FAME", hub: "The Crossing", tab: "pvp", tabs: {}, database: false,
    boards: [{ key: "pvp.wins", title: "MOST WINS", unit: "wins", total: 2, rows: {} }, { title: "no key" },
      { key: "pvp.kills", title: "MOST KILLS", unit: "nonsense", total: 1, rows: [{ rank: 1, name: "Kei Mori", value: 9, title: "Most Wanted" }, { rank: 2, value: 3 }] }] })!;
  assert.equal(p.boards[1]!.rows[0]!.title, "Most Wanted", "the shown title (titles.lua) is kept");
  assert.equal(p.tab, "pvp");
  assert.deepEqual(p.tabs, ["overview", "pvp", "races", "pve", "missions"], "no tab list: every tab but wealth");
  assert.equal(p.boards.length, 2);
  assert.deepEqual(p.boards[0]!.rows, []);
  assert.equal(p.boards[1]!.unit, "count");
  assert.equal(p.boards[1]!.rows.length, 1, "a row without a name is dropped");
  assert.equal(p.database, false);
  assert.equal(normalizeHallOfFame({ kind: "activities" }), undefined);
  assert.equal(normalizeHallOfFame(undefined), undefined);
  const wealthless = normalizeHallOfFame({ kind: "halloffame", tab: "wealth", tabs: ["overview", "pvp"], boards: [] })!;
  assert.equal(wealthless.tab, "wealth");
  assert.deepEqual(wealthless.tabs, ["overview", "pvp"]);
});

test("values read in their unit", () => {
  assert.equal(formatValue(61234, "time"), "1:01.234");
  assert.equal(formatValue(1284500, "eddies"), "€$ 1,284,500");
  assert.equal(formatValue(1, "wins"), "1 WIN");
  assert.equal(formatValue(12, "wins"), "12 WINS");
  assert.equal(formatValue(2450, "rep"), "2,450 REP");
  assert.equal(formatValue(7, "count"), "7");
  assert.equal(rankLabel(3), "#03");
  assert.equal(updatedLine(undefined), "NOT COMPUTED YET");
  assert.equal(updatedLine(12), "UPDATED JUST NOW");
  assert.equal(updatedLine(185), "UPDATED 3 MIN AGO");
  assert.equal(updatedLine(7300), "UPDATED 2 H AGO");
});

test("podium 2-1-3, shared ranks, the viewer's line", () => {
  const rows = [{ rank: 1, name: "A", value: 9 }, { rank: 2, name: "B", value: 7 }, { rank: 2, name: "C", value: 7 }, { rank: 4, name: "D", value: 5 }];
  assert.deepEqual(podium(rows).map((p) => `${p.place}:${p.row.name}`), ["2:B", "1:A", "3:C"]);
  assert.deepEqual(podium(rows.slice(0, 1)).map((p) => p.place), [1]);
  assert.equal(tied(rows, 1), true);
  assert.equal(tied(rows, 2), true);
  assert.equal(tied(rows, 3), false);
  const board = { key: "pvp.wins", title: "MOST WINS", unit: "wins" as const, total: 15, rows, mine: { rank: 14, value: 4, detail: "7 played" } };
  assert.equal(mineLine(board), "YOU #14 OF 15 · 4 WINS · 7 played");
  assert.equal(mineLine({ ...board, rows: [...rows, { rank: 5, name: "Me", value: 4, you: true }] }), undefined, "already highlighted in the list");
  assert.equal(mineLine({ ...board, mine: undefined }), undefined, "not ranked: nothing");
});

test("a ladder answer: one board under the tab's header, its rows and the viewer's rank", () => {
  const rows = Array.from({ length: 50 }, (_, i) => ({ rank: i === 49 ? 49 : i + 1, name: `Name ${i + 1}`, value: 500 - i, detail: "d", title: i === 0 ? "Champion" : undefined }));
  const p = normalizeHallOfFame({ kind: "halloffame", tab: "overview", tabs: ["overview", "pvp"], boards: {}, database: true, updatedAgoS: 4,
    ladder: { key: "pvp.wins", title: "MOST WINS", subtitle: "Arena", unit: "wins", total: 312, rows: [...rows, { rank: 51, value: 1 }],
      mine: { rank: 80, value: 12, detail: "40 played" } } })!;
  assert.equal(p.tab, "overview", "the tab it was opened from");
  assert.deepEqual(p.boards, [], "Lua's empty boards: no tab boards with a ladder");
  const ladder = p.ladder!;
  assert.equal(ladder.key, "pvp.wins");
  assert.equal(ladder.rows.length, 50, "a row without a name is dropped");
  assert.equal(ladder.rows[0]!.title, "Champion");
  assert.equal(ladder.total, 312);
  assert.equal(tied(ladder.rows, 49), true, "a tie across the cut keeps its marker");
  assert.deepEqual(pinnedRank(ladder), { rank: 80, value: 12, detail: "40 played" }, "outside the fifty: pinned under the list");
  assert.equal(ladderLine(ladder), "TOP 50 OF 312");
  const inside = { ...ladder, rows: ladder.rows.map((r, i) => (i === 29 ? { ...r, you: true as const } : r)), mine: { rank: 30, value: 471 } };
  assert.equal(pinnedRank(inside), undefined, "inside: the highlighted row says it");
  assert.equal(pinnedRank({ ...ladder, mine: undefined }), undefined, "not ranked: nothing pinned");
  assert.equal(ladderLine({ ...ladder, rows: ladder.rows.slice(0, 14), total: 14 }), "14 RANKED");
  const ascending = normalizeHallOfFame({ kind: "halloffame", tab: "races", tabs: [], boards: [],
    ladder: { key: "races.race.trial", title: "TIME TRIAL", unit: "time", ascending: true, total: 0, rows: {} } })!;
  assert.equal(ascending.ladder!.ascending, true);
  assert.deepEqual(ascending.ladder!.rows, [], "an empty ladder");
  assert.equal(normalizeHallOfFame({ kind: "halloffame", tab: "pvp", tabs: [], boards: [] })!.ladder, undefined, "a tab answer has no ladder");
});
