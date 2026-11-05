import { PAGE_EVENTS } from "@/bridge/protocol";

/* Dev mock (no Open77 bridge): ?maneki=tool shows the placement tool's bar,
   ?maneki=desk opens the staff desk on the Maneki-neko list with plausible answers. */
type Fire = (name: string, payload: unknown) => void;
const SPOTS = [
  { id: "mk6a1f3c2e01", x: -1442.3, y: 128.6, z: 18.4, bucket: 0, yaw: 210, scale: 1, district: "Kabuki", placedBy: "Yuki", placedAt: Date.now() - 3600e3, finds: 4, distance: 12.4 },
  { id: "mk6a1f3d9002", x: -611.2, y: 812.9, z: 31.0, bucket: 0, yaw: 90, scale: 1.5, district: "Japantown", placedBy: "Yuki", placedAt: Date.now() - 7200e3, finds: 1, distance: 954.2 },
  { id: "mk6a1f4b1703", x: 103.8, y: -405.5, z: 7.2, bucket: 0, yaw: 0, scale: 2, district: "Downtown", placedBy: "w0dm4n", placedAt: Date.now() - 86400e3, finds: 0, distance: 1820.7 },
];
export function manekiMock(fire: Fire, params: URLSearchParams) {
  const mode = params.get("maneki");
  return {
    boot() {
      if (mode === "tool") fire(PAGE_EVENTS.maneki, { active: true, scale: 1.5, yaw: 15, aim: true, nearby: 3, message: "Maneki-neko mk6a1f3c2e01 placed (3 in the city).", ok: true });
      if (mode === "desk") fire(PAGE_EVENTS.dialog, { kind: "support", scope: "staff" });
      // ?maneki=collection[&intro=1]: F1 > Maneki-neko with 7 of 18 found
      if (mode === "collection") {
        const districts = ["Kabuki", "Japantown", "Little China", "Northside", "Downtown", "Vista del Rey", "Charter Hill"];
        const found = new Set([0, 1, 3, 6, 7, 10, 14]);
        const slots = Array.from({ length: 18 }, (_, i) => found.has(i)
          ? `mk${i}|${districts[i % districts.length]}|${Date.now() - (18 - i) * 3600e3 * 7}|${i % 3 === 0 ? "shot" : "take"}|${-1400 + i * 90}|${120 + i * 40}|18`
          : "");
        fire(PAGE_EVENTS.state, { maneki: { found: found.size, total: slots.length } });
        fire(PAGE_EVENTS.dialog, { kind: "maneki", slots, found: found.size, total: slots.length, reward: 500,
          milestones: [{ count: 5, cash: 0, items: [{ name: "tcg_booster_wnc", count: 1, label: "TCG Booster · Night City" }] }, { count: 10, cash: 2500, items: [{ name: "tcg_booster_wnc", count: 2, label: "TCG Booster · Night City" }] }, { count: 25, cash: 7500, items: [{ name: "tcg_booster_beta", count: 2, label: "TCG Booster · Beta" }] }], completeMin: 10,
          title: { id: "lucky_cat", label: "Lucky Cat" }, intro: params.get("intro") === "1" || undefined });
      }
    },
    /** The staff desk's requests: true when answered. */
    receive(payload: unknown): boolean {
      const p = payload as { operation?: string; request?: string; search?: string };
      if (mode !== "desk" || !p?.request) return false;
      const reply = (data: unknown) => setTimeout(() => fire(PAGE_EVENTS.support, { kind: "response", request: p.request, ok: true, data }), 80);
      if (p.operation === "overview") { reply({ players: [], staff: [], permissions: { view: true, maneki: true, manekiEdit: true, tables: true }, jobs: [], gangs: [], database: true }); return true; }
      if (p.operation === "maneki") {
        const spots = p.search ? SPOTS.filter((s) => s.id === p.search) : SPOTS;
        reply({ spots, page: 1, pageSize: 15, total: spots.length, cats: SPOTS.length, finders: 5, mine: 1, editing: false, canEdit: true, canTeleport: true });
        return true;
      }
      return false;
    },
  };
}
