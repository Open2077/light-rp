import assert from "node:assert/strict";
import test from "node:test";
import { filterStock, formatLeft } from "../src/features/rental/model.ts";

const stock = [
  { key: "hella", label: "Archer Hella", category: "Street", price: 120 },
  { key: "maimai", label: "Makigai MaiMai", category: "Street", price: 60 },
  { key: "semimaru", label: "Yaiba Semimaru", category: "Sport", price: 90 },
];
test("rental search, categories and sorting compose without mutating server stock", () => {
  assert.deepEqual(filterStock(stock, "", "All", "price-asc").map((v) => v.key), ["maimai", "semimaru", "hella"]);
  assert.deepEqual(filterStock(stock, "", "All", "price-desc").map((v) => v.key), ["hella", "semimaru", "maimai"]);
  assert.deepEqual(filterStock(stock, "", "All", "name").map((v) => v.key), ["hella", "maimai", "semimaru"]);
  assert.deepEqual(filterStock(stock, "  HELLA  ", "Street", "name").map((v) => v.key), ["hella"]);
  assert.equal(filterStock(stock, "hella", "Sport", "name").length, 0);
  assert.equal(filterStock([], "", "All", "price-asc").length, 0);
  assert.equal(stock[0].key, "hella");
});
test("rental clock clamps expired and invalid durations and supports long rentals", () => {
  assert.equal(formatLeft(1800000), "30:00");
  assert.equal(formatLeft(1), "00:01");
  assert.equal(formatLeft(-100), "00:00");
  assert.equal(formatLeft(NaN), "00:00");
  assert.equal(formatLeft(7200000), "120:00");
});
