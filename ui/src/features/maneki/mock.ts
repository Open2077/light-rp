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
