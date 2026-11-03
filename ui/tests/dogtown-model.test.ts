import assert from "node:assert/strict";
import test from "node:test";
import { cashAtRisk, dogtownMenu, lootRule, normalizeDogtown, stakeMissing, stakeRule } from "../src/features/dogtown/model.ts";

const fmt = (n: number) => `€$ ${n.toLocaleString("en-US")}`;
// server/config/dogtown.lua as the server sends it (dogtown.lua D.rules).
const rules = { mode: "bag", share: 0.1, min: 100, max: 750, bonus: 0.25, bonusDailyCap: 3000, reserveSeconds: 15, tagSeconds: 20,
  pairCooldownMinutes: 10, stake: 1000, graceSeconds: 10, gankCrew: 4, gankFactor: 0.5, underdogBonus: 0.5,
  bountyStreak: 5, bountyPerKill: 250, bountyMax: 1500 } as const;

test("Lua's empty tables become arrays and zeros", () => {
  const d = normalizeDogtown({ enabled: true, inside: true, top: {}, mine: {}, rules: {}, stake: {} } as never)!;
  assert.deepEqual(d.top, []);
  assert.deepEqual(d.mine.week, { kills: 0, deaths: 0, looted: 0, bestStreak: 0 });
  assert.equal(d.rules.mode, "bag");
  assert.equal(d.rules.tagSeconds, 20);
  assert.equal(d.rules.gankFactor, 1);
  assert.deepEqual(d.stake, { required: 0, cash: 0, missing: 0, short: false, evictInMs: 0 });
  assert.equal(d.bounty, false);
  assert.equal(normalizeDogtown(undefined), undefined);
});

test("cash at risk: the share, at least the minimum, at most the cap, never more than carried", () => {
  assert.equal(cashAtRisk(2000, rules), 200);
  assert.equal(cashAtRisk(1234, rules), 123);
  assert.equal(cashAtRisk(500, rules), 100);
  assert.equal(cashAtRisk(60, rules), 60);
  assert.equal(cashAtRisk(20000, rules), 750);
  assert.equal(cashAtRisk(0, rules), 0);
});

test("the stake: what is missing, and the rule in words", () => {
  assert.equal(stakeMissing(50, rules), 950);
  assert.equal(stakeMissing(1000, rules), 0);
  assert.equal(stakeMissing(-5, rules), 1000);
  assert.match(stakeRule(rules, fmt), /€\$ 1,000 in cash on you.*the bank doesn't count.*after 10 s inside/);
});

test("the loot rule names the bag, the bonus and the reserve", () => {
  assert.match(lootRule(rules, fmt), /10% of the cash.*at least €\$ 100, at most €\$ 750.*sealed bag where they fell, with a 25% server bonus.*crew has it for 15 s/);
  assert.match(lootRule({ ...rules, mode: "transfer" }, fmt), /straight to the killer, with a 25% server bonus/);
});

test("F1 → Dogtown: rules, record, streak, leaderboard, closed zone", () => {
  const menu = dogtownMenu({ enabled: true, inside: false, rules, bonusToday: 420,
    mine: { week: { kills: 3, deaths: 1, looted: 250, bestStreak: 2 }, total: { kills: 9, deaths: 4, looted: 900, bestStreak: 4 } },
    top: [{ rank: 1, name: "Ana Kill", kills: 4, deaths: 0, looted: 300 }, { rank: 2, name: "Bo Prey", kills: 1, deaths: 3, looted: 0 }], week: 2966 } as never, fmt)!;
  assert.equal(menu.item.target, "dogtown");
  assert.equal(menu.item.meta, "3 KILLS");
  const node = menu.nodes.dogtown!;
  const byId = (id: string) => node.items.find((i) => "id" in i && i.id === id) as { meta?: string; text?: string; description?: string; danger?: boolean } | undefined;
  assert.equal(byId("dogtown-stake")!.meta, "€$ 1,000 CASH");
  assert.equal(byId("dogtown-cash")!.meta, "10% · €$ 100–€$ 750");
  assert.match(byId("dogtown-bonus")!.description!, /capped at €\$ 3,000 a day per account.*€\$ 420 earned today/);
  assert.match(byId("dogtown-crews")!.description!, /4 or more members.*only 50% of the normal loss.*adds 50%/);
  assert.match(byId("dogtown-bounty")!.description!, /5 kills in a row.*€\$ 250 per kill.*up to €\$ 1,500/);
  assert.match(byId("dogtown-fair")!.description!, /within 10 minutes: no kill, no loss, no bonus/);
  assert.equal(byId("dogtown-week")!.meta, "K 3 · D 1");
  assert.match(byId("dogtown-total")!.description!, /best streak 4/);
  assert.equal(byId("dogtown-streak"), undefined, "no streak, no line");
  assert.equal(byId("dogtown-top:1")!.text, "1. Ana Kill");
  assert.equal(byId("dogtown-top:2")!.meta, "1 KILL");
  const inside = dogtownMenu({ enabled: true, inside: true, rules, top: [], streak: 3 } as never, fmt)!;
  assert.equal(inside.item.meta, "YOU ARE IN");
  assert.equal(inside.item.danger, true);
  const items = inside.nodes.dogtown!.items;
  assert.ok(items.some((i) => "id" in i && i.id === "dogtown-top-none"));
  const streak = items.find((i) => "id" in i && i.id === "dogtown-streak") as { meta?: string; description?: string };
  assert.equal(streak.meta, "3 IN A ROW");
  assert.match(streak.description!, /2 more kills without dying/);
  const wanted = dogtownMenu({ enabled: true, inside: true, rules, top: [], streak: 5, bounty: true, bountyReward: 1250, bounties: 1 } as never, fmt)!;
  assert.equal(wanted.item.meta, "BOUNTY ON YOU");
  const bountyLine = wanted.nodes.dogtown!.items.find((i) => "id" in i && i.id === "dogtown-streak") as { text?: string; description?: string };
  assert.equal(bountyLine.text, "Bounty on you");
  assert.match(bountyLine.description!, /€\$ 1,250/);
  const short = dogtownMenu({ enabled: true, inside: true, rules, top: [], stake: { short: true, missing: 950 } } as never, fmt)!;
  assert.equal((short.nodes.dogtown!.items.find((i) => "id" in i && i.id === "dogtown-stake") as { danger?: boolean }).danger, true);
  const closed = dogtownMenu({ enabled: false, rules } as never, fmt)!;
  assert.equal(closed.item.meta, "CLOSED");
  assert.equal(closed.nodes.dogtown!.subtitle, "ZONE CLOSED");
});
