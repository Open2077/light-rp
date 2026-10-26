import { test } from "node:test";
import assert from "node:assert/strict";
import { basketSummary, filterItems } from "../src/features/shop/model.ts";
import type { ShopDialogPayload } from "../src/bridge/protocol.ts";
const payload: ShopDialogPayload = {
  kind: "shop", session: "1", revision: 1, nextRequest: 1, shop: { id: "test", name: "Test", label: "Market", template: "food" },
  maxLines: 2, maxPerItem: 20, payments: ["cash", "bank"], money: { currency: "€$", cash: 10, bank: 100 },
  inventory: { id: "p", kind: "player", label: "Bag", slots: 2, weight: 4, maxWeight: 10, items: [
    { name: "water", label: "Water", slot: 1, count: 8, weight: .5, stack: 10, icon: "droplet", usable: true },
  ] },
  items: [
    { name: "water", label: "Water", icon: "droplet", category: "drink", weight: .5, stack: 10, owned: 8, buy: 8, sell: 2 },
    { name: "burrito", label: "Burrito", icon: "sandwich", category: "food", weight: .4, stack: 10, owned: 0, buy: 18, sell: 5 },
  ],
};
test("search, categories and buy/sell/owned filters", () => {
  assert.equal(filterItems(payload.items, "buy", " WATer ", "all", true).length, 1);
  assert.equal(filterItems(payload.items, "buy", "", "food", true)[0]?.name, "burrito");
  assert.equal(filterItems(payload.items, "sell", "", "all", true).length, 1);
  assert.equal(filterItems(payload.items, "sell", "", "all", false).length, 2);
  assert.equal(filterItems([{ ...payload.items[0]!, sell: undefined }], "sell", "", "all", false).length, 0);
});
test("totals, funds, counts, weights and complete-basket slots", () => {
  assert.match(basketSummary(payload, {}, "buy", "cash").issue, /Add/);
  assert.match(basketSummary(payload, { water: 2 }, "buy", "cash").issue, /funds/);
  const summary = basketSummary(payload, { water: 2 }, "buy", "bank");
  assert.equal(summary.issue, ""); assert.equal(summary.total, 16); assert.equal(summary.afterWeight, 5);
  assert.match(basketSummary(payload, { water: 3, burrito: 1 }, "buy", "bank").issue, /slots/);
  assert.match(basketSummary({ ...payload, inventory: { ...payload.inventory, maxWeight: 4 } }, { water: 1 }, "buy", "bank").issue, /heavy/);
  assert.match(basketSummary(payload, { water: 21 }, "buy", "bank").issue, /quantities/);
  assert.match(basketSummary(payload, { water: 1.5 }, "buy", "bank").issue, /quantities/);
  assert.match(basketSummary(payload, { deleted: 1, water: 1 }, "buy", "bank").issue, /quantities/);
  assert.match(basketSummary(payload, { water: 9 }, "sell", "cash").issue, /enough items/);
  const sale = basketSummary(payload, { water: 3 }, "sell", "cash");
  assert.equal(sale.total, 6); assert.equal(sale.afterWeight, 2.5); assert.equal(sale.issue, "");
});
