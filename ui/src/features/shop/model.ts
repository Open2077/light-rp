import type { ShopDialogPayload, ShopItem } from "@/bridge/protocol";

export type ShopMode = "buy" | "sell";
export type Basket = Record<string, number>;
export const categoryLabel = (key: string) => ({ food: "Food", drink: "Drinks", medical: "Medical", tool: "Tools", misc: "Other", document: "Documents" }[key] ?? key);
export function filterItems(items: ShopItem[], mode: ShopMode, query: string, category: string, ownedOnly: boolean) {
  const needle = query.trim().toLocaleLowerCase();
  return items.filter(item => item[mode] != null && (mode !== "sell" || !ownedOnly || item.owned > 0)
    && (category === "all" || item.category === category)
    && (!needle || `${item.label} ${item.description ?? ""}`.toLocaleLowerCase().includes(needle)));
}
export function basketSummary(payload: ShopDialogPayload, basket: Basket, mode: ShopMode, pay: "cash" | "bank") {
  const lines = payload.items.filter(item => (basket[item.name] ?? 0) > 0).map(item => ({ item, count: basket[item.name]!, price: item[mode] ?? 0 }));
  const units = lines.reduce((n, line) => n + line.count, 0);
  const total = lines.reduce((n, line) => n + line.price * line.count, 0);
  const weight = lines.reduce((n, line) => n + line.item.weight * line.count, 0);
  const afterWeight = Math.max(0, payload.inventory.weight + (mode === "buy" ? weight : -weight));
  let issue = "";
  if (!lines.length) issue = "Add something to your basket.";
  else if (lines.length > payload.maxLines || Object.keys(basket).filter(key => basket[key]! > 0).length !== lines.length
    || lines.some(({ item, count }) => !Number.isSafeInteger(count) || count > payload.maxPerItem || item[mode] == null)) issue = "Review your basket quantities.";
  else if (!payload.payments.includes(pay)) issue = "Select an available payment method.";
  else if (mode === "sell" && lines.some(({ item, count }) => count > item.owned)) issue = "You do not have enough items to sell.";
  else if (mode === "buy" && total > payload.money[pay]) issue = "Insufficient funds. Try another payment method or reduce your basket.";
  else if (mode === "buy" && afterWeight > payload.inventory.maxWeight + 1e-6) issue = "Too heavy to carry. Remove some items.";
  else if (mode === "buy") {
    let free = payload.inventory.slots - payload.inventory.items.length;
    for (const { item, count } of lines) {
      const room = payload.inventory.items.filter(held => held.name === item.name && held.metadata == null)
        .reduce((n, held) => n + Math.max(0, item.stack - held.count), 0);
      free -= Math.ceil(Math.max(0, count - room) / Math.max(1, item.stack));
    }
    if (free < 0) issue = "Not enough free inventory slots for this basket.";
  }
  return { lines, units, total, weight, afterWeight, issue };
}
