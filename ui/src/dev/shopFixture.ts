import type { ShopDialogPayload } from "@/bridge/protocol";
import { itemCatalogue } from "./itemCatalogue";

/** Browser preview only. The game always uses the server's template snapshot. */
export function shopFixture(): ShopDialogPayload {
  const prices: Record<string, [number, number]> = { water: [8, 2], burrito: [18, 5], noodles: [24, 6], dumplings: [20, 5], pizza: [16, 4], synthmeat: [15, 4], onigiri: [12, 3], apple: [10, 3], candy: [6, 1], proteinbar: [14, 3], soda: [10, 2], coffee: [12, 3], juice: [12, 3], energydrink: [18, 4], electrolyte: [16, 4] };
  const items = Object.keys(prices).map(name => {
    const item = itemCatalogue.find(entry => entry.name === name)!;
    return { ...item, category: item.category ?? "misc", buy: prices[name]![0], sell: prices[name]![1], owned: ["water", "burrito"].includes(name) ? 5 : 0,
      description: item.category === "food" ? "A bite of Night City. Ready when you are." : "Take a break. Keep going." };
  });
  return {
    kind: "shop", session: "browser-preview", nextRequest: 1, revision: 1,
    shop: { id: "citycenter_food", name: "Corner Market / City Center", label: "Night City Market", subtitle: "Good food. Cold drinks. Back to the city.", template: "street_food" },
    items, maxPerItem: 20, maxLines: 12, payments: ["cash", "bank"], money: { currency: "€$", cash: 250, bank: 1500 },
    inventory: { id: "preview:bag", kind: "player", label: "Bag", slots: 24, weight: 4.5, maxWeight: 25,
      items: items.filter(item => item.owned > 0).map((item, i) => ({ ...item, slot: i + 1, count: item.owned, usable: true })) },
  };
}
