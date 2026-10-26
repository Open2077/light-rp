import { clone, EXTRA_RESTRICTIONS, fresh, normalizeZone, type Zone } from "./model";
import { PAGE_EVENTS } from "@/bridge/protocol";

/** Browser fixture only: publishes no presence unless explicitly requested. */
export function safezonesMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const position = { x: -1200, y: 1100, z: 44 };
  const allowed = params.get("staff") === "1";
  const zones: Zone[] = [{ ...fresh({ position, bucket: 0, session: "mock" }), id: "kabuki-clinic", label: "Clinique de Kabuki", revision: 1 }];
  if (params.get("safezonesLegacy") === "1") {
    const legacy: Partial<Zone> = { ...zones[0] };
    delete legacy.blockRun; delete legacy.blockShoot; delete legacy.fullHeight;
    for (const { key } of EXTRA_RESTRICTIONS) delete legacy[key];
    zones[0] = legacy as Zone;
  }
  let generation = 1, step = 0;
  const replies = new Map<string, unknown>();
  const presence = () => {
    if (params.get("safezonesPresence") !== "1") return;
    const active = zones.filter(z => z.enabled).map(normalizeZone), zone = active[0];
    fire(PAGE_EVENTS.safezones, { kind: "presence", ready: true, zone: zone ? {
      id: zone.id, label: zone.label, blockRun: active.some(z => z.blockRun), blockShoot: active.some(z => z.blockShoot),
      ...Object.fromEntries(EXTRA_RESTRICTIONS.map(({ key }) => [key, active.some(z => z[key])])),
    } : undefined });
  };
  const snapshot = () => { fire(PAGE_EVENTS.safezones, { kind: "snapshot", ready: true, generation, zones: clone(zones) }); presence(); };
  const boot = () => {
    snapshot();
    if (params.get("safezones") === "1") fire(PAGE_EVENTS.safezones, { kind: "open" });
  };
  const receive = (payload: unknown) => {
    const p = payload as { operation: string; request?: string; zone?: Zone; id?: string; baseRevision?: number; mutation?: string; session?: string; mode?: string };
    if (p.operation === "input" || p.operation === "preview" || p.operation === "close") return;
    if (p.operation === "snapshot") { snapshot(); return; }
    if (p.operation === "open") { if (allowed) fire(PAGE_EVENTS.safezones, { kind: "open" }); return; }
    const respond = (ok: boolean, data?: unknown, error?: string) => fire(PAGE_EVENTS.safezones, { kind: "response", request: p.request, ok, data, error });
    setTimeout(() => {
      if (!allowed) { respond(false, undefined, "Permission staff requise."); return; }
      if (p.operation === "list") respond(true, { ready: true, zones: clone(zones), permissions: { view: true, edit: true, publish: true, delete: true } });
      else if (p.operation === "capture") {
        const angle = step++ * Math.PI / 2;
        respond(true, { position: { x: position.x + Math.cos(angle) * 8, y: position.y + Math.sin(angle) * 8, z: position.z }, bucket: 0, session: "browser-safezone-session" });
      } else if (p.operation === "heartbeat" || p.operation === "cancel") respond(true, {});
      else if (p.operation === "save" && p.zone) {
        if (p.mutation && replies.has(p.mutation)) { respond(true, replies.get(p.mutation)); return; }
        const old = zones.find(z => z.id === p.zone!.id);
        if (old && old.revision !== p.baseRevision) { respond(false, undefined, "Cette zone a changé. Rechargez-la avant de publier."); return; }
        const saved = normalizeZone({ ...clone(p.zone), id: p.zone.id || `mock-zone-${Date.now()}`, revision: (old?.revision ?? 0) + 1 });
        if (old) zones.splice(zones.indexOf(old), 1, saved); else zones.push(saved);
        const data = { zone: clone(saved) }; if (p.mutation) replies.set(p.mutation, data);
        generation++; snapshot(); respond(true, data);
      } else if (p.operation === "delete") {
        if (p.mutation && replies.has(p.mutation)) { respond(true, replies.get(p.mutation)); return; }
        const i = zones.findIndex(z => z.id === p.id);
        if (i < 0 || zones[i]!.revision !== p.baseRevision) { respond(false, undefined, "La zone a changé. Rechargez la liste."); return; }
        zones.splice(i, 1); const data = { id: p.id }; if (p.mutation) replies.set(p.mutation, data);
        generation++; snapshot(); respond(true, data);
      }
    }, 140);
  };
  return { boot, receive };
}
