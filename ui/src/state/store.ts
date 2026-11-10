import { normalizeMission, normalizeParty, normalizeQueue } from "@/features/missions/model";
import { normalizeActivities } from "@/features/activities/model";
import { normalizeRooms } from "@/features/rooms/model";
import { normalizeDailies, normalizeDailiesDialog, normalizeTitles } from "@/features/dailies/model";
import { normalizeQueue as normalizeQueuePanel } from "@/features/queue/model";
import { create } from "zustand";
import { emit } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import type { ArmamentPending, ArmamentState, GrenadeState, HotbarState, DialogPayload, HudState, InventorySnapshot, NoticeKindWire, UiState, UiStatePatch } from "@/bridge/protocol";
import type { ExtraSafezoneRules } from "@/features/safezones/model";

/** A notice raised inside the page (an editor that closed, a shop that shut). The lane is a
    NativeUI document: the page hands it to Lua (client/core/ui.lua -> LightRpNativeNotices.push). */
export interface PageNotice {
  id?: string;
  kind: NoticeKindWire;
  title?: string;
  body?: string;
  source?: string;
  durationMs: number;
}

/** Authoritative safezone presence, including the combined rules of overlapping zones. */
export interface SafezonePresence extends ExtraSafezoneRules { id: string; label: string; blockRun: boolean; blockShoot: boolean }

export const EMPTY_STATE: UiState = {
  server: { name: "Open//77 Official Roleplay", playersOnline: 0, maxPlayers: 0 },
  character: {
    registered: false, status: "draft", step: "identity", key: "default", appearanceRevision: 0, appearanceTracked: false,
    accountName: "", playerId: 0, slots: [], maxSlots: 1, origins: [], minAge: 18, currentYear: 2077, welcomePending: false,
  },
  needs: { food: 100, drink: 100 },
  money: { currency: "€$", cash: 0, history: [] },
  rental: {},
  job: { name: "unemployed", label: "Unemployed", tag: "CIVILIAN", grade: 0, gradeLabel: "Citizen", salary: 0 },
  gang: { name: "none", label: "No gang", tag: "—", grade: 0, gradeLabel: "—" },
  vehicles: { catalog: [], owned: [] },
  staff: { isStaff: false },
  locations: [],
  online: [],
};

export const EMPTY_HUD: HudState = {
  ready: false,
  health: { value: 100, max: 100 },
  stamina: { value: 100, max: 100 },
  armor: 0,
  vehicle: { active: false },
  voice: { state: "idle", level: 0, range: "normal" },
  clock: "--:--",
};

interface Store {
  boardGamesActive: boolean;
  setBoardGamesActive(value: boolean): void;
  customizationActive: boolean;
  setCustomizationActive(value: boolean): void;
  activityActive: boolean;
  setActivityActive(value: boolean): void;
  connected: boolean;
  state: UiState;
  hud: HudState;
  hotbar?: HotbarState;
  setHotbar(state: HotbarState): void;
  safezone?: SafezonePresence;
  armament?: ArmamentState;
  grenades?: GrenadeState;
  setGrenades(state: GrenadeState): void;
  grenadePending?: string;
  setGrenadePending(request?: string): void;
  armamentPending?: ArmamentPending;
  armamentFeedback?: { text: string; error: boolean };
  menuOpen: boolean; // the F1 player menu
  lastResult?: { ok: boolean; text: string; at: number; action?: string };
  dialog?: DialogPayload;      // the open server dialog (rental desk...)
  rentalReceivedAt: number;    // when `rental` last arrived, to count the time down
  welcomeReplay: boolean; // the Help tab asked for the briefing again
  /** The job guide on screen (a job name), and the one waiting for the job center to close. */
  jobGuide?: string;
  jobGuideQueued?: string;
  queueJobGuide(job: string): void;
  openJobGuide(job: string): void;
  closeJobGuide(): void;
  setConnected(value: boolean): void;
  setWelcomeReplay(value: boolean): void;
  applyState(patch: UiStatePatch): void;
  setHud(hud: HudState): void;
  setSafezone(safezone: SafezonePresence | undefined): void;
  setArmament(value: ArmamentState): void;
  setArmamentPending(value: ArmamentPending | undefined): void;
  setArmamentFeedback(value: { text: string; error: boolean } | undefined): void;
  openMenu(): void;
  closeMenu(): void;
  pushNotice(notice: PageNotice): void;
  setResult(ok: boolean, text: string, action?: string): void;
  openDialog(payload: DialogPayload): void;
  closeDialog(): void;
  updateInventories(list: InventorySnapshot[]): void;
}

let noticeSequence = 0;

/** Lua serialises an empty table as `{}`: make every snapshot's `items` an array. */
export function normalizeInventory(snap: InventorySnapshot): InventorySnapshot {
  return { ...snap, items: Array.isArray(snap.items) ? snap.items : [] };
}
function normalizeDialog(payload: DialogPayload): DialogPayload {
  if (payload.kind === "mission") return normalizeMission(payload);
  if (payload.kind === "dealership") return { ...payload, stock: Array.isArray(payload.stock) ? payload.stock : [] };
  if (payload.kind === "garage") return { ...payload, vehicles: Array.isArray(payload.vehicles) ? payload.vehicles : [] };
  if (payload.kind === "inventory") return { ...payload, left: normalizeInventory(payload.left), right: normalizeInventory(payload.right) };
  if (payload.kind === "rental") return { ...payload, spot: { ...payload.spot, stock: Array.isArray(payload.spot.stock) ? payload.spot.stock : [] } };
  if (payload.kind === "jobcenter") return { ...payload, jobs: Array.isArray(payload.jobs) ? payload.jobs : [] };
  if (payload.kind === "dailies") return normalizeDailiesDialog(payload);
  if (payload.kind === "parkour") return { ...payload, courses: Array.isArray(payload.courses) ? payload.courses : [] };
  if (payload.kind === "maneki") return { ...payload, slots: Array.isArray(payload.slots) ? payload.slots.map(String) : [], milestones: Array.isArray(payload.milestones) ? payload.milestones : [] };
  if (payload.kind === "shop") return { ...payload, items: Array.isArray(payload.items) ? payload.items : [], payments: Array.isArray(payload.payments) ? payload.payments : [], inventory: normalizeInventory(payload.inventory) };
  return payload;
}

export const useStore = create<Store>((set) => ({
  boardGamesActive: false,
  setBoardGamesActive: (value) => set({ boardGamesActive: value }),
  customizationActive: false,
  setCustomizationActive: (value) => set({ customizationActive: value }),
  activityActive: false,
  setActivityActive: (value) => set({ activityActive: value }),
  connected: false,
  state: EMPTY_STATE,
  hud: EMPTY_HUD,
  safezone: undefined,
  menuOpen: false,
  welcomeReplay: false,
  rentalReceivedAt: Date.now(),
  setConnected: (value) => set({ connected: value }),
  setWelcomeReplay: (value) => set({ welcomeReplay: value }),
  queueJobGuide: (job) => set({ jobGuideQueued: job }),
  openJobGuide: (job) => set({ jobGuide: job, jobGuideQueued: undefined }),
  closeJobGuide: () => set({ jobGuide: undefined }),
  applyState: (patch) => set((s) => ({ state: { ...s.state, ...patch,
    ...("party" in patch ? { party: normalizeParty(patch.party) } : {}),
    ...("missionQueue" in patch ? { missionQueue: normalizeQueue(patch.missionQueue) } : {}),
    ...("queue" in patch ? { queue: normalizeQueuePanel(patch.queue) } : {}),
    ...("activities" in patch ? { activities: normalizeActivities(patch.activities) } : {}),
    ...("rooms" in patch ? { rooms: normalizeRooms(patch.rooms) } : {}),
    ...("dailies" in patch ? { dailies: normalizeDailies(patch.dailies) } : {}),
    ...("titles" in patch ? { titles: normalizeTitles(patch.titles) } : {}),
    ...(patch.character ? { character: { ...patch.character,
      origins: Array.isArray(patch.character.origins) ? patch.character.origins : [],
      slots: Array.isArray(patch.character.slots) ? patch.character.slots : [],
    } } : {}),
  }, rentalReceivedAt: patch.rental ? Date.now() : s.rentalReceivedAt })),
  openDialog: (payload) => set({ dialog: normalizeDialog(payload) }),
  closeDialog: () => set({ dialog: undefined }),
  // Fresh snapshots replace the matching side of the open inventory dialog; a
  // snapshot for an unknown id (the server switched the secondary) lands on the right.
  updateInventories: (list) => set((s) => {
    if (!s.dialog || s.dialog.kind !== "inventory") return {};
    let { left, right } = s.dialog;
    for (const raw of list) {
      const snap = normalizeInventory(raw);
      if (snap.id === left.id) left = snap;
      else right = snap;
    }
    return { dialog: { ...s.dialog, left, right } };
  }),
  setHud: (hud) => set({ hud }),
  setHotbar: (hotbar) => set({ hotbar }),
  setSafezone: (safezone) => set({ safezone }),
  // Lua sends an empty list as {}: keep `arsenal` an array for every reader
  setArmament: (armament) => set({ armament: armament && !Array.isArray(armament.arsenal) ? { ...armament, arsenal: [] } : armament }),
  setGrenades: (grenades) => set({ grenades }),
  setGrenadePending: (grenadePending) => set({ grenadePending }),
  setArmamentPending: (armamentPending) => set({ armamentPending }),
  setArmamentFeedback: (armamentFeedback) => set({ armamentFeedback }),
  openMenu: () => set({ menuOpen: true }),
  closeMenu: () => set({ menuOpen: false }),
  // nothing is stored: Lua owns the lane (FIFO, lifetime, dismissal)
  pushNotice: (notice) => emit(PAGE_EVENTS.noticePush, {
    id: notice.id ?? `n${++noticeSequence}`, kind: notice.kind, title: notice.title, body: notice.body, source: notice.source, durationMs: notice.durationMs,
  }),
  setResult: (ok, text, action) => set({ lastResult: { ok, text, action, at: Date.now() } }),
}));
