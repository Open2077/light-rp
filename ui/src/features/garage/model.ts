import type { PersonalVehicle } from "../../bridge/protocol.ts";

export function filterVehicles(vehicles: PersonalVehicle[], query: string, filter: string) {
  const needle = query.trim().toLocaleLowerCase();
  return vehicles.filter(v => (filter === "all" || v.status === filter)
    && `${v.label} ${v.category} ${v.id} ${v.garageName} ${v.plate ?? ""}`.toLocaleLowerCase().includes(needle));
}
export function condition(value: number) {
  return Math.round(Math.min(1, Math.max(0, Number.isFinite(value) ? value : 0)) * 100);
}
