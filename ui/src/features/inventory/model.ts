import type { InventoryItem, InventorySnapshot } from "../../bridge/protocol";

export type SlotRef = { inventory: string; slot: number };
/** Lua supplies the player's current binding, not just the default I key. */
export function matchesToggleKey(event: Pick<KeyboardEvent, "key" | "code" | "altKey" | "ctrlKey" | "metaKey">, binding = "I") {
  const key = binding.toUpperCase();
  const aliases: Record<string, string> = { ESC: "ESCAPE", RETURN: "ENTER", SPACE: " ", LEFT: "ARROWLEFT", RIGHT: "ARROWRIGHT", UP: "ARROWUP", DOWN: "ARROWDOWN", CTRL: "CONTROL", LCTRL: "CONTROL", RCTRL: "CONTROL", LALT: "ALT", RALT: "ALT", LSHIFT: "SHIFT", RSHIFT: "SHIFT" };
  const target = aliases[key] ?? key;
  if ((event.altKey && target !== "ALT") || (event.ctrlKey && target !== "CONTROL") || event.metaKey) return false;
  const logical = event.key.toUpperCase();
  // Some embedded Chromium key events expose a physical code but no logical
  // character until keypress. Do not override a real layout-aware key value.
  const missingLogicalKey = !logical || logical === "UNIDENTIFIED";
  return logical === target || (/^[0-9]$/.test(key) && event.code === `Digit${key}`)
    || (missingLogicalKey && (event.code.toUpperCase() === target || (/^[A-Z]$/.test(key) && event.code === `Key${key}`)));
}
export const kg = (value: number) => new Intl.NumberFormat("en", { maximumFractionDigits: 2 }).format(value);
const counts = new Intl.NumberFormat("en");
const compactCounts = new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 });
export const itemAmount = (item: InventoryItem, count = item.count, compact = false) => item.name === "cash"
  ? `€$ ${compact && count >= 100000 ? compactCounts.format(count) : counts.format(count)}` : `×${counts.format(count)}`;
export const quantity = (value: string, available: number) => value.trim() === "" ? available
  : /^\d+$/.test(value) && Number(value) > 0 ? Math.min(Number(value), available) : 0;
export const itemAt = (ref: SlotRef | null, inventories: InventorySnapshot[]) => ref
  ? inventories.find((inventory) => inventory.id === ref.inventory)?.items.find((item) => item.slot === ref.slot) : undefined;
export const emptySlot = (inventory: InventorySnapshot) => {
  const used = new Set(inventory.items.map((item) => item.slot));
  for (let slot = 1; slot <= inventory.slots; slot++) if (!used.has(slot)) return slot;
  return undefined;
};
// Different owners/serials must not stack, regardless of metadata key order.
const stable = (value: unknown): string => {
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, entry]) => `${JSON.stringify(key)}:${stable(entry)}`).join(",")}}`;
  return JSON.stringify(value) ?? "null";
};
export const itemIdentity = (item: InventoryItem) => `${item.name}:${stable(item.metadata ?? {})}`;
export function transferSlot(inventory: InventorySnapshot, item: InventoryItem, count: number) {
  const stack = inventory.items.find((target) => itemIdentity(target) === itemIdentity(item) && target.count + count <= target.stack);
  return stack?.slot ?? emptySlot(inventory);
}
