import { PAGE_EVENTS } from "@/bridge/protocol";
import { clone, fresh, normalizeMission, type Mission } from "./model";

/** Browser fixture of the mission editor (`?missioneditor=1&staff=1`). */
export function missionEditorMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const origin = { x: -1435, y: 1252, z: 23 };
  const allowed = params.get("staff") === "1";
  let step = 0;
  const sample: Mission = { ...fresh({ position: origin, heading: 90 }), id: "mock-warehouse", revision: 2, title: "Warehouse sweep", location: "Kabuki",
    description: "Maelstrom took the warehouse. Clear it.",
    spawns: [
      { id: "s1", label: "Loading bay", position: { x: -1420, y: 1250, z: 23 }, heading: 270, enemy: "maelstrom", count: 4, trigger: "start", behavior: "defend", radius: 10, alertRange: 25, spread: 2, route: [] },
      { id: "s2", label: "Office", position: { x: -1440, y: 1275, z: 27 }, heading: 180, enemy: "maelstrom", count: 3, trigger: "checkpoint", behavior: "ambush", radius: 12, alertRange: 15, spread: 1.5, route: [] },
    ],
    checkpoints: [{ id: "c1", label: "Office stairs", position: { x: -1438, y: 1265, z: 23 }, radius: 4, required: true, spawns: ["s2"] }] };
  const missions: Mission[] = [sample, { ...clone(sample), id: "mock-holdout", title: "Last stand at the docks", type: "waves", revision: 1,
    spawns: [{ id: "w1", label: "North gate", position: { x: -1410, y: 1270, z: 23 }, heading: 200, enemy: "militech", count: 5, trigger: "wave", behavior: "assault", radius: 12, alertRange: 25, spread: 3, route: [] }],
    checkpoints: [], waves: [{ delaySeconds: 10, spawns: ["w1"] }, { delaySeconds: 20, spawns: ["w1"] }] }];
  const replies = new Map<string, unknown>();
  const boot = () => { if (params.get("missioneditor") === "1") fire(PAGE_EVENTS.missionEditor, { kind: "open" }); };
  const receive = (payload: unknown) => {
    const p = payload as { operation: string; request?: string; mission?: Mission; id?: string; baseRevision?: number; mutation?: string; mode?: string };
    if (p.operation === "input" || p.operation === "preview" || p.operation === "close") return;
    const respond = (ok: boolean, data?: unknown, error?: string) => fire(PAGE_EVENTS.missionEditor, { kind: "response", request: p.request, ok, data, error });
    setTimeout(() => {
      if (p.operation === "capture") {
        const a = step++ * 0.9;
        const r = (n: number) => Math.round(n * 100) / 100;
        respond(true, { position: { x: r(origin.x + Math.cos(a) * 12), y: r(origin.y + Math.sin(a) * 12), z: origin.z }, heading: (step * 40) % 360 });
        return;
      }
      if (!allowed) { respond(false, undefined, "Mission editor permission denied."); return; }
      if (p.operation === "list") respond(true, { ready: true, missions: clone(missions) });
      else if (p.operation === "save" && p.mission) {
        if (p.mutation && replies.has(p.mutation)) { respond(true, replies.get(p.mutation)); return; }
        const old = missions.find(m => m.id === p.mission!.id);
        if (old && old.revision !== p.baseRevision) { respond(false, undefined, "This mission changed meanwhile. Refresh before publishing."); return; }
        const saved = normalizeMission({ ...clone(p.mission), id: p.mission.id || `mock-${Date.now()}`, revision: (old?.revision ?? 0) + 1 });
        if (old) missions.splice(missions.indexOf(old), 1, saved); else missions.push(saved);
        const data = { mission: clone(saved) }; if (p.mutation) replies.set(p.mutation, data);
        respond(true, data);
      } else if (p.operation === "delete") {
        const i = missions.findIndex(m => m.id === p.id);
        if (i < 0) { respond(false, undefined, "This mission no longer exists."); return; }
        missions.splice(i, 1); respond(true, { id: p.id });
      } else if (p.operation === "test") respond(true, { launched: true });
      else respond(false, undefined, "Unknown mission editor operation.");
    }, 120);
  };
  return { boot, receive };
}
