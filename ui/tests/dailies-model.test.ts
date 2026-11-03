import assert from "node:assert/strict";
import test from "node:test";
import {
  cardState, countdown, earnedCount, expiryLabel, formatAmount, hiddenNote, initials, menuMeta, normalizeDailies, normalizeDailiesDialog,
  normalizeTitles, overBudget, progressLabel, progressRatio, shownTitle, streakLine, titleSections, titleStatus, toClaim,
} from "../src/features/dailies/model.ts";

// As server/modules/dailies.lua D.view sends it: nil fields left out, empty tables as {}.
const day = () => normalizeDailies({
  enabled: true, ready: true, day: 20760, resetInMs: 3_600_000, weekResetInMs: 90_000_000, streak: 4, swapsLeft: 1,
  budget: { used: 250, max: 1200 },
  list: [
    { slot: "weekly", id: "good_samaritan", title: "Good Samaritan", fixer: "okoro", fixerName: "Mama Okoro", brief: "…", goal: "Stabilize 3.", value: 1, target: 3, done: false, claimed: false, reward: 3000 },
    { slot: "crew", id: "album_cover", title: "Album Cover", fixer: "nix", fixerName: "Nix Delacroix", brief: "…", goal: "Pose.", value: 0, target: 1, done: false, claimed: false, reward: 300, needsCrew: true },
    { slot: "street", id: "ride_along", title: "Ride Along", fixer: "okoro", fixerName: "Mama Okoro", brief: "…", goal: "Ride 1.5 km.", value: 640, target: 1500, unit: "m", done: false, claimed: false, reward: 250, swappable: true, social: true },
    { slot: "action", id: "support_act", title: "Support Act", fixer: "okoro", fixerName: "Mama Okoro", brief: "…", goal: "More assists than kills.", value: 1, target: 1, done: true, claimed: false, reward: 400 },
    { slot: "shift", id: "full_truck", title: "Full Truck", fixer: "okoro", fixerName: "Mama Okoro", brief: "…", goal: "Sell 11.", value: 1, target: 1, done: true, claimed: true, reward: 250 },
    { slot: "nonsense", id: "x", title: "X" }, { id: "no-title", slot: "street" }, "junk",
  ],
  older: [{ id: "street_performer", title: "Street Performer", reward: 250 }, { title: "no id" }],
})!;

test("Lua's empty tables become arrays, cards are ordered by slot, junk is dropped", () => {
  const empty = normalizeDailies({ enabled: true, ready: true, list: {}, older: {}, budget: {}, streak: 0, swapsLeft: 0 })!;
  assert.deepEqual(empty.list, []); assert.deepEqual(empty.older, []);
  assert.deepEqual(empty.budget, { used: 0, max: 0 });
  const d = day();
  assert.deepEqual(d.list.map((c) => c.slot), ["street", "action", "shift", "crew", "weekly"]);
  assert.equal(d.older.length, 1);
  assert.equal(d.list[0]!.unit, "m"); assert.equal(d.list[1]!.unit, undefined);
  assert.equal(normalizeDailies(undefined), undefined);
  // a paused module / no character yet
  assert.deepEqual(normalizeDailies({ enabled: false })!.enabled, false);
  assert.equal(normalizeDailies({ enabled: true, ready: false })!.ready, false);
});

test("progress reads in the contract's unit; a one-shot contract says NOT YET until done", () => {
  assert.equal(formatAmount(640, "m"), "640 m");
  assert.equal(formatAmount(1500, "m"), "1.5 km");
  assert.equal(formatAmount(3000, "m"), "3 km");
  assert.equal(formatAmount(65, "s"), "1:05");
  assert.equal(formatAmount(2.7), "2");
  const [ride, support] = day().list;
  assert.equal(progressLabel(ride!), "640 m / 1.5 km");
  assert.equal(progressLabel(support!), "DONE");
  assert.equal(progressLabel({ ...support!, done: false, value: 0 }), "NOT YET");
  assert.equal(progressLabel({ ...support!, done: false, value: 1, target: 2 }), "1 / 2");
  assert.equal(progressRatio(ride!), 640 / 1500);
  assert.equal(progressRatio({ ...ride!, value: 9999 }), 1);
});

test("card states: claim, paid, budget spent (the weekly is outside it), needs a crew", () => {
  const d = day();
  const [street, action, shift, crew, weekly] = d.list;
  assert.equal(cardState(street!, d.budget), "progress");
  assert.equal(cardState(action!, d.budget), "claimable");
  assert.equal(cardState(shift!, d.budget), "claimed");
  assert.equal(cardState(crew!, d.budget), "crew");
  const spent = { used: 1000, max: 1200 };
  assert.equal(overBudget(action!, spent), true);
  assert.equal(cardState(action!, spent), "budget");
  assert.equal(cardState({ ...weekly!, done: true }, { used: 1200, max: 1200 }), "claimable");
  assert.equal(overBudget(action!, { used: 99999, max: 0 }), false, "max 0 = no cap");
});

test("a crew daily with no crewmate online is a placeholder until one shows up; social is read", () => {
  const d = normalizeDailies({ enabled: true, ready: true, streak: 0, swapsLeft: 1, budget: { used: 0, max: 1200 }, older: {},
    list: [{ slot: "crew", id: "convoy", title: "Convoy", fixer: "nix", fixerName: "Nix", brief: "…", goal: "…", value: 0, target: 2400, unit: "m",
      done: false, claimed: false, reward: 300, needsCrew: true, crewLocked: true, social: true }] })!;
  const [crew] = d.list;
  assert.equal(crew!.crewLocked, true); assert.equal(crew!.social, true);
  assert.equal(cardState(crew!, d.budget), "locked");
  assert.equal(cardState({ ...crew!, crewLocked: undefined }, d.budget), "crew", "started: the card shows, still waiting for a crewmate");
  assert.equal(cardState({ ...crew!, done: true }, d.budget), "claimable", "a finished one is never hidden");
  const [ride, support] = day().list;
  assert.equal(ride!.social, true); assert.equal(support!.social, undefined); assert.equal(support!.crewLocked, undefined);
});

test("the F1 line counts what waits, else what is paid", () => {
  const d = day();
  assert.equal(toClaim(d), 2); // Support Act + yesterday's Street Performer
  assert.equal(menuMeta(d), "2 TO CLAIM");
  const quiet = { ...d, older: [], list: d.list.map((c) => (c.id === "support_act" ? { ...c, claimed: true } : c)) };
  assert.equal(menuMeta(quiet), "2/4 PAID");
  assert.equal(menuMeta(normalizeDailies({ enabled: false })), "PAUSED");
  assert.equal(menuMeta(normalizeDailies({ enabled: true, ready: false })), undefined);
  assert.equal(menuMeta(undefined), undefined);
});

test("countdowns, initials, streak", () => {
  assert.equal(countdown(3_600_000), "01:00:00");
  assert.equal(countdown(6 * 3_600_000 + 12 * 60_000 + 40_000), "06:12:40");
  assert.equal(countdown(90_000_000), "1D 01H");
  assert.equal(countdown(-5), "00:00:00");
  assert.equal(initials("Mama Okoro"), "MO");
  assert.equal(initials("Silas \"Ledger\" Varga"), "SV");
  assert.equal(initials("Nix"), "N");
  assert.equal(initials(""), "?");
  assert.equal(streakLine(0), "NONE YET"); assert.equal(streakLine(1), "1 DAY"); assert.equal(streakLine(9), "9 DAYS");
});

test("the dialog opens on Today unless it asks for the titles", () => {
  assert.deepEqual(normalizeDailiesDialog({ kind: "dailies", tab: "titles" }), { kind: "dailies", tab: "titles" });
  assert.deepEqual(normalizeDailiesDialog({ kind: "dailies", tab: "nope" }), { kind: "dailies", tab: "today" });
  assert.deepEqual(normalizeDailiesDialog(undefined), { kind: "dailies", tab: "today" });
});

// As titles.lua T.view sends it.
const titles = () => normalizeTitles({
  enabled: true, shown: "most_wanted", chosen: "most_wanted",
  groups: [{ id: "pvp", label: "PvP" }, { id: "hall", label: "Hall of Fame" }, { id: "dogtown", label: "Dogtown" }, { id: "raids", label: "Raids" }],
  list: [
    { id: "duelist", label: "Duelist", rarity: "rare", group: "pvp", how: "Win 10 ranked duels.", value: 14, count: 10 },
    { id: "champion", label: "Champion", rarity: "live", group: "hall", how: "Hold rank 1.", live: true },
    { id: "most_wanted", label: "Most Wanted", rarity: "rare", group: "dogtown", how: "5 in a row.", earned: true, value: 5, count: 5 },
    { id: "dogtown_king", label: "King of Dogtown · W45", rarity: "legendary", group: "dogtown", how: "Top killer.", earned: true, expiresInMs: 7_200_000 },
    { id: "odd", label: "Odd", rarity: "mythic", group: "secret", how: "?" },
    { label: "no id" },
  ],
})!;

test("titles: sections in the server's order, empty ones out, unknown groups under Other", () => {
  const t = titles();
  assert.equal(t.list.length, 5);
  assert.equal(t.list.find((e) => e.id === "odd")!.rarity, "common");
  assert.equal(t.list.find((e) => e.id === "duelist")!.value, 10, "progress is capped at the count");
  const sections = titleSections(t);
  assert.deepEqual(sections.map((s) => s.id), ["pvp", "hall", "dogtown", "other"]);
  assert.equal(sections.find((s) => s.id === "dogtown")!.earned, 2);
  assert.equal(earnedCount(t), 2);
  const bare = normalizeTitles({ enabled: true, list: {} })!;
  assert.deepEqual(bare.list, []); assert.deepEqual(titleSections(bare), []);
  assert.equal(normalizeTitles({ enabled: false })!.enabled, false);
});

test("titles: shown, earned, a rank-1 title not held, locked; a chosen title lost is explained", () => {
  const t = titles();
  const by = (id: string) => t.list.find((e) => e.id === id)!;
  assert.equal(titleStatus(by("most_wanted"), t), "shown");
  assert.equal(titleStatus(by("dogtown_king"), t), "earned");
  assert.equal(titleStatus(by("champion"), t), "live");
  assert.equal(titleStatus(by("duelist"), t), "locked");
  assert.equal(shownTitle(t)!.label, "Most Wanted");
  assert.equal(hiddenNote(t), undefined);
  const lost = { ...t, shown: undefined, chosen: "champion" };
  assert.equal(titleStatus(by("champion"), lost), "hidden");
  assert.match(hiddenNote(lost)!, /retake rank 1/);
  const expired = { ...t, shown: undefined, chosen: "duelist" };
  assert.match(hiddenNote(expired)!, /run out/);
  // a shown or chosen id the list does not carry is ignored
  assert.equal(normalizeTitles({ enabled: true, shown: "ghost", chosen: "ghost", list: [] })!.shown, undefined);
});

test("expiry labels", () => {
  assert.equal(expiryLabel(7_200_000), "ENDS IN 2H 00M");
  assert.equal(expiryLabel(3 * 86_400_000 + 4 * 3_600_000), "ENDS IN 3D 04H");
  assert.equal(expiryLabel(30_000), "ENDS IN 1M");
});
