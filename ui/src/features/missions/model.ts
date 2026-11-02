import type { MissionBoard, MissionDialogPayload, MissionObjective, MissionQueueState, PartyState } from "@/bridge/protocol";

/* Lua serialises an empty table as `{}`: every list of a mission snapshot and of
   the squad state becomes an array here, before anything renders it. */
const list = <T,>(value: unknown): T[] => (Array.isArray(value) ? value : []) as T[];

export function normalizeMission(p: MissionDialogPayload): MissionDialogPayload {
  const boards: Record<string, MissionBoard> = {};
  for (const [id, b] of Object.entries(p.boards && typeof p.boards === "object" ? p.boards : {})) boards[id] = { ...b, members: list(b?.members) };
  return { ...p, difficulties: list(p.difficulties), nearby: list(p.nearby), boards };
}

export function normalizeQueue(q: MissionQueueState | undefined): MissionQueueState | undefined {
  if (!q || typeof q !== "object" || !q.running) return q;
  const objective = q.objective && typeof q.objective === "object"
    ? { ...q.objective, checkpoints: q.objective.checkpoints ? list<NonNullable<MissionObjective["checkpoints"]>[number]>(q.objective.checkpoints) : undefined } : undefined;
  return { ...q, squad: list(q.squad), objective };
}

export function normalizeParty(p: PartyState | undefined): PartyState | undefined {
  if (!p || typeof p !== "object") return p;
  return { ...p, invites: list(p.invites), members: p.members ? list(p.members) : undefined, pending: p.pending ? list(p.pending) : undefined };
}
