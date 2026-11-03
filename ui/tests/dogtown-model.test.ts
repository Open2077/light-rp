import assert from "node:assert/strict";
import test from "node:test";
import { cashAtRisk, dogtownMenu, lootRule, normalizeDogtown } from "../src/features/dogtown/model.ts";

const fmt = (n: number) => `€$ ${n.toLocaleString("en-US")}`;
const rules = { mode: "bag", share: 0.1, max: 500, minCash: 100, tagSeconds: 20, pairCooldownMinutes: 10 } as const;

test("Lua's empty tables become arrays and zeros", () => {
  const d = normalizeDogtown({ enabled: true, inside: true, top: {}, mine: {}, rules: {} } as never)!;
  assert.deepEqual(d.top, []);
  assert.deepEqual(d.mine.week, { kills: 0, deaths: 0, looted: 0 });
  assert.equal(d.rules.mode, "bag");
  assert.equal(d.rules.tagSeconds, 20);
  assert.equal(normalizeDogtown(undefined), undefined);
});

test("cash at risk: the share, the cap, nothing under the threshold", () => {
  assert.equal(cashAtRisk(1000, rules), 100);
  assert.equal(cashAtRisk(1234, rules), 123);
  assert.equal(cashAtRisk(20000, rules), 500);
  assert.equal(cashAtRisk(99, rules), 0);
  assert.equal(cashAtRisk(0, rules), 0);
});

test("the loot rule names the mode", () => {
  assert.match(lootRule(rules, fmt), /10% of the cash.*at most €\$ 500, nothing under €\$ 100.*a bag where they fell/);
  assert.match(lootRule({ ...rules, mode: "transfer" }, fmt), /straight to the killer/);
});

test("F1 → Dogtown: record, leaderboard, closed zone", () => {
  const menu = dogtownMenu({ enabled: true, inside: false, rules, mine: { week: { kills: 3, deaths: 1, looted: 250 }, total: { kills: 9, deaths: 4, looted: 900 } },
    top: [{ rank: 1, name: "Ana Kill", kills: 4, deaths: 0, looted: 300 }, { rank: 2, name: "Bo Prey", kills: 1, deaths: 3, looted: 0 }], week: 2966 } as never, fmt)!;
  assert.equal(menu.item.target, "dogtown");
  assert.equal(menu.item.meta, "3 KILLS");
  const node = menu.nodes.dogtown!;
  const byId = (id: string) => node.items.find((i) => i.id === id)!;
  assert.equal(byId("dogtown-week").meta, "K 3 · D 1");
  assert.equal(byId("dogtown-total").meta, "K 9 · D 4");
  assert.equal(byId("dogtown-top:1").text, "1. Ana Kill");
  assert.equal(byId("dogtown-top:2").meta, "1 KILL");
  const inside = dogtownMenu({ enabled: true, inside: true, rules, top: [] } as never, fmt)!;
  assert.equal(inside.item.meta, "YOU ARE IN");
  assert.equal(inside.item.danger, true);
  assert.ok(inside.nodes.dogtown!.items.some((i) => i.id === "dogtown-top-none"));
  const closed = dogtownMenu({ enabled: false, rules } as never, fmt)!;
  assert.equal(closed.item.meta, "CLOSED");
  assert.equal(closed.nodes.dogtown!.subtitle, "ZONE CLOSED");
});
