import assert from "node:assert/strict";
import test from "node:test";
import { formatValue, mineLine, normalizeHallOfFame, podium, rankLabel, tied, updatedLine } from "../src/features/halloffame/model.ts";

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
