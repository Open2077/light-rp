import { test } from "node:test";
import assert from "node:assert/strict";
import { condition, filterVehicles } from "../src/features/garage/model.ts";
import type { PersonalVehicle } from "../src/bridge/protocol.ts";

const vehicles: PersonalVehicle[] = [
  { id: "one", key: "hella", label: "Archer Hella", category: "Street", status: "stored", garageId: "city", garageName: "City Center", health: .5, canRetrieve: true, canStore: false },
  { id: "two", key: "apollo", label: "Brennan Apollo", category: "Bikes", status: "out", garageId: "coast", garageName: "Coast", health: 1, canRetrieve: false, canStore: true, plate: "NC77ABC", stage: 2 },
];
test("personal garage filters by name, registration, location and status", () => {
  assert.equal(filterVehicles(vehicles, "  ARCHER ", "all")[0]?.id, "one");
  assert.equal(filterVehicles(vehicles, "coast", "out")[0]?.id, "two");
  assert.equal(filterVehicles(vehicles, "two", "stored").length, 0);
  assert.equal(filterVehicles([], "", "all").length, 0);
  assert.equal(filterVehicles(vehicles, "nc77a", "all")[0]?.id, "two", "the Auto Studio plate is searchable");
});
test("condition is readable and bounded", () => {
  assert.equal(condition(.835), 84); assert.equal(condition(9), 100);
  assert.equal(condition(-1), 0); assert.equal(condition(NaN), 0);
});
