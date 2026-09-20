import { test } from "node:test";
import assert from "node:assert/strict";
import { emptySlot, itemAt, itemIdentity, matchesToggleKey, quantity, transferSlot } from "../src/features/inventory/model.ts";
import type { InventoryItem, InventorySnapshot } from "../src/bridge/protocol.ts";

const item: InventoryItem = { name: "water", label: "Water", slot: 1, count: 5, weight: .5, icon: "droplet", usable: true, stack: 10 };
const inventory: InventorySnapshot = { id: "test", kind: "stash", label: "Test", slots: 2, maxWeight: 40, weight: 2.5, items: [item] };

test("toggle matches the actual binding, including AZERTY digits and named keys", () => {
  const event = { key: "i", code: "KeyI", altKey: false, ctrlKey: false, metaKey: false };
  assert.equal(matchesToggleKey(event), true);
  assert.equal(matchesToggleKey({ ...event, key: "Unidentified" }), true);
  assert.equal(matchesToggleKey({ ...event, key: "", code: "KeyK" }, "K"), true);
  assert.equal(matchesToggleKey({ ...event, key: "a", code: "KeyQ" }, "Q"), false);
  assert.equal(matchesToggleKey(event, "K"), false);
  assert.equal(matchesToggleKey({ ...event, ctrlKey: true }), false);
  assert.equal(matchesToggleKey({ ...event, key: "&", code: "Digit1" }, "1"), true);
  assert.equal(matchesToggleKey({ ...event, key: "é", code: "Digit2" }, "é"), true);
  assert.equal(matchesToggleKey({ ...event, key: "F6", code: "F6" }, "F6"), true);
  assert.equal(matchesToggleKey({ ...event, key: " ", code: "Space" }, "SPACE"), true);
});

test("quantities clamp to the actual stack and reject zero/invalid values", () => {
  assert.equal(quantity("", 5), 5);
  assert.equal(quantity("999", 5), 5);
  for (const value of ["0", "-1", "1.5", "abc", "Infinity"]) assert.equal(quantity(value, 5), 0);
  assert.equal(quantity("2", 5), 2);
});

test("selection and free slots retain server identifiers", () => {
  assert.equal(itemAt({ inventory: "other", slot: 1 }, [inventory]), undefined);
  assert.equal(itemAt({ inventory: "test", slot: 1 }, [inventory]), item);
  assert.equal(emptySlot(inventory), 2);
  assert.equal(emptySlot({ ...inventory, slots: 1 }), undefined);
});

test("transfers merge matching metadata, otherwise find an empty slot", () => {
  assert.equal(transferSlot(inventory, item, 5), 1);
  assert.equal(transferSlot(inventory, item, 6), 2);
  assert.equal(transferSlot({ ...inventory, slots: 1 }, item, 6), undefined);
  assert.equal(transferSlot(inventory, { ...item, metadata: { owner: "someone" } }, 1), 2);
  assert.equal(itemIdentity({ ...item, metadata: { owner: "a", quality: 1 } }), itemIdentity({ ...item, metadata: { quality: 1, owner: "a" } }));
  assert.notEqual(itemIdentity(item), itemIdentity({ ...item, name: "other" }));
});
