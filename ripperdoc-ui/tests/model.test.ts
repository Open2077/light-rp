// The clinic's rules on the page (src/model.ts): capacity, storage, iconics, the order of the
// refusals, and the browser preview's simulated surgery. The server words are mirrored.
// node --test --experimental-strip-types tests/*.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import type { Cyberware } from "../src/data.ts";
import {
  capacityAfter, capacityRefusal, eddies, familyMate, fitPrice, isDropOnly, points, refusal, repLabel, roman, simulate, usedPoints,
  type ClinicState,
} from "../src/model.ts";

const item = (id: string, section: string, capacity: number, price: number, extra: Partial<Cyberware> = {}): Cyberware => ({
  id, name: id.replace(/_/g, " "), section, icon: "cw_x", rarity: "rare", tier: 4, capacity, price, maker: "M", effect: "", lore: "", stats: [], ...extra,
});

const items: Record<string, Cyberware> = Object.fromEntries([
  item("sandevistan_mk1", "operating_system", 5, 30000, { family: "os" }),
  item("berserk_mk1", "operating_system", 5, 26000, { family: "os" }),
  item("berserk_mk3", "operating_system", 7, 64000, { family: "os" }),
  item("subdermal_armor", "integumentary", 2, 9000, { family: "armor" }),
  item("aegis_dermal_plating", "integumentary", 7, 90000, { family: "armor", locked: true, repTier: 5, repName: "Legend" }),
  item("second_heart", "circulatory", 6, 55000, { family: "heart" }),
  item("kiroshi_optics", "ocular", 1, 7000, { family: "optics" }),
  item("chimera_plating", "integumentary", 7, 0, { family: "armor", rarity: "iconic", iconic: true, source: "Chimera raid (Critical)" }),
].map((x) => [x.id, x]));

const clinic = (over: Partial<ClinicState> = {}): ClinicState => ({
  wallet: 100000, fittingFee: 50, items,
  installed: { operating_system: ["sandevistan_mk1"], integumentary: ["subdermal_armor"] },
  storage: [], capacity: { used: 7, total: 14 }, ...over,
});

test("points, labels and money", () => {
  assert.equal(points(items.berserk_mk3), 7);
  assert.equal(points(undefined), 0);
  assert.equal(roman(6), "V+");
  assert.equal(eddies(390000), "390 000");
  assert.equal(repLabel(items.aegis_dermal_plating!), "V (Legend)");
  assert.equal(usedPoints(clinic()), 7);
});

test("a family mate is replaced and its points come back", () => {
  const s = clinic();
  assert.equal(familyMate(s, items.berserk_mk1!)?.id, "sandevistan_mk1");
  assert.equal(familyMate(s, items.second_heart!), undefined);
  assert.equal(capacityAfter(s, items.berserk_mk3!), 9, "7 - 5 (Sandevistan out) + 7");
  assert.equal(capacityAfter(s, items.second_heart!), 13);
});

test("capacity: the server's refusal words, the free points counted with the mate out", () => {
  const s = clinic({ capacity: { used: 12, total: 14 } });
  assert.equal(capacityRefusal(s, items.kiroshi_optics!), null, "13 <= 14");
  assert.equal(capacityRefusal(s, items.second_heart!),
    "Not enough capacity: second heart takes 6 points, 2 of your 14 are free. Take an implant out (it goes to your storage) or earn the next street cred tier.");
  assert.equal(capacityRefusal(s, items.berserk_mk3!), null, "12 - 5 + 7 = 14");
  assert.equal(capacityRefusal(clinic({ capacity: undefined }), items.second_heart!), null, "no capacity: no limit");
});

test("over capacity: only a swap that does not make it worse", () => {
  const s = clinic({ capacity: { used: 18, total: 14, over: true } });
  assert.match(capacityRefusal(s, items.kiroshi_optics!) ?? "", /^Your body is over capacity \(18 \/ 14 points\)/);
  assert.match(capacityRefusal(s, items.berserk_mk3!) ?? "", /over capacity/, "5 out, 7 in: heavier");
  assert.equal(capacityRefusal(s, items.berserk_mk1!), null, "5 out, 5 in: allowed");
});

test("storage: fitted for the fee, past the street cred gate, still bound by capacity", () => {
  const s = clinic({ storage: ["aegis_dermal_plating"], wallet: 60 });
  assert.equal(fitPrice(s, items.aegis_dermal_plating!), 50);
  assert.equal(refusal(s, items.aegis_dermal_plating!), null, "owned: no street cred, 7 - 2 + 7 = 12, the fee paid");
  const poor = clinic({ storage: ["aegis_dermal_plating"], wallet: 40 });
  assert.equal(refusal(poor, items.aegis_dermal_plating!), "Not enough eurodollars in your bank account (€$ 50).");
  const full = clinic({ storage: ["second_heart"], capacity: { used: 12, total: 14 } });
  assert.match(refusal(full, items.second_heart!) ?? "", /^Not enough capacity/);
});

test("the refusals come in the server's order", () => {
  const s = clinic({ wallet: 10 });
  assert.equal(refusal(s, items.sandevistan_mk1!), "Already installed.");
  assert.equal(refusal(s, items.chimera_plating!), "Iconic implants are not for sale: Chimera raid (Critical) drops it.");
  assert.match(refusal(s, items.aegis_dermal_plating!) ?? "", /^Street cred too low: aegis dermal plating needs reputation tier V \(Legend\)/);
  assert.match(refusal(clinic({ wallet: 10, capacity: { used: 12, total: 14 } }), items.second_heart!) ?? "", /^Not enough capacity/, "capacity before money");
  assert.equal(refusal(s, items.second_heart!), "Not enough eurodollars in your bank account (€$ 55 000).");
  assert.equal(refusal(clinic(), items.second_heart!), null);
});

test("taking out: the fee, and only what is fitted", () => {
  assert.equal(refusal(clinic(), items.subdermal_armor!, "remove"), null);
  assert.equal(refusal(clinic({ wallet: 49 }), items.subdermal_armor!, "remove"), "Taking it out costs €$ 50.");
  assert.equal(refusal(clinic(), items.second_heart!, "remove"), "This implant is not installed.");
});

test("an iconic: drop only until owned, then fitted from storage like any implant", () => {
  const s = clinic();
  assert.equal(isDropOnly(s, items.chimera_plating!), true);
  const owned = clinic({ storage: ["chimera_plating"] });
  assert.equal(isDropOnly(owned, items.chimera_plating!), false);
  assert.equal(refusal(owned, items.chimera_plating!), null, "7 - 2 (armor out) + 7 = 12");
  const after = simulate(owned, items.chimera_plating!, "install");
  assert.equal(isDropOnly({ ...owned, ...after }, items.chimera_plating!), false, "fitted: still not a drop");
});

test("the preview's surgery: mate and removed implants to storage, fee or price paid, points recounted", () => {
  const s = clinic({ storage: ["berserk_mk1"] });
  const fit = simulate(s, items.berserk_mk1!, "install");
  assert.deepEqual(fit.installed.operating_system, ["berserk_mk1"]);
  assert.deepEqual(fit.storage, ["sandevistan_mk1"], "the Sandevistan waits in storage, the Berserk left it");
  assert.equal(fit.wallet, 100000 - 50, "from storage: the fitting fee");
  assert.deepEqual(fit.capacity, { used: 7, total: 14, over: false });

  const buy = simulate(s, items.second_heart!, "install");
  assert.equal(buy.wallet, 100000 - 55000);
  assert.deepEqual(buy.installed.circulatory, ["second_heart"]);
  assert.equal(buy.capacity?.used, 13);

  const out = simulate(s, items.subdermal_armor!, "remove");
  assert.deepEqual(out.installed.integumentary, []);
  assert.deepEqual(out.storage, ["berserk_mk1", "subdermal_armor"]);
  assert.equal(out.wallet, 100000 - 50);
  assert.equal(out.capacity?.used, 5);
});
