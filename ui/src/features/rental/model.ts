import type { RentalStockItem } from "../../bridge/protocol";

export type RentalSort = "price-asc" | "price-desc" | "name";
export function filterStock(stock: RentalStockItem[], query: string, category: string, sort: RentalSort) {
  const search = query.trim().toLocaleLowerCase();
  return stock.filter((item) => (category === "All" || item.category === category)
    && `${item.label} ${item.key} ${item.category}`.toLocaleLowerCase().includes(search))
    .sort((a, b) => (sort === "name" ? a.label.localeCompare(b.label) : sort === "price-desc" ? b.price - a.price : a.price - b.price) || a.label.localeCompare(b.label));
}
export function formatLeft(ms: number): string {
  const total = Number.isFinite(ms) ? Math.max(0, Math.ceil(ms / 1000)) : 0;
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}
