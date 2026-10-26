import { create } from "zustand";
import type { DialogPayload, HudState, InventorySnapshot, NoticeKindWire, UiState, UiStatePatch } from "@/bridge/protocol";

export interface Notice {
  id: string;
  kind: NoticeKindWire;
  title?: string;
  body?: string;
  source?: string;
  createdAt: number;
  durationMs: number;
  dismissing?: boolean;
}

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
  activityActive: boolean;
  setActivityActive(value: boolean): void;
  connected: boolean;
  state: UiState;
  hud: HudState;
  menuOpen: boolean; // the F1 player menu
  notices: Notice[];
  lastResult?: { ok: boolean; text: string; at: number; action?: string };
  dialog?: DialogPayload;      // the open server dialog (rental desk...)
  rentalReceivedAt: number;    // when `rental` last arrived, to count the time down
  welcomeReplay: boolean; // the Help tab asked for the briefing again
  setConnected(value: boolean): void;
  setWelcomeReplay(value: boolean): void;
  applyState(patch: UiStatePatch): void;
  setHud(hud: HudState): void;
  openMenu(): void;
  closeMenu(): void;
  pushNotice(notice: Omit<Notice, "id" | "createdAt"> & { id?: string }): void;
  dismissNotice(id: string): void;
  removeNotice(id: string): void;
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
  if (payload.kind === "dealership") return { ...payload, stock: Array.isArray(payload.stock) ? payload.stock : [] };
  if (payload.kind === "garage") return { ...payload, vehicles: Array.isArray(payload.vehicles) ? payload.vehicles : [] };
  if (payload.kind === "inventory") return { ...payload, left: normalizeInventory(payload.left), right: normalizeInventory(payload.right) };
  if (payload.kind === "rental") return { ...payload, spot: { ...payload.spot, stock: Array.isArray(payload.spot.stock) ? payload.spot.stock : [] } };
  if (payload.kind === "jobcenter") return { ...payload, jobs: Array.isArray(payload.jobs) ? payload.jobs : [] };
  if (payload.kind === "shop") return { ...payload, items: Array.isArray(payload.items) ? payload.items : [], payments: Array.isArray(payload.payments) ? payload.payments : [], inventory: normalizeInventory(payload.inventory) };
  return payload;
}

export const useStore = create<Store>((set) => ({
  activityActive: false,
  setActivityActive: (value) => set({ activityActive: value }),
  connected: false,
  state: EMPTY_STATE,
  hud: EMPTY_HUD,
  menuOpen: false,
  notices: [],
  welcomeReplay: false,
  rentalReceivedAt: Date.now(),
  setConnected: (value) => set({ connected: value }),
  setWelcomeReplay: (value) => set({ welcomeReplay: value }),
  applyState: (patch) => set((s) => ({ state: { ...s.state, ...patch,
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
  openMenu: () => set({ menuOpen: true }),
  closeMenu: () => set({ menuOpen: false }),
  pushNotice: (notice) => set((s) => ({
    notices: [...s.notices.slice(-5), { ...notice, id: notice.id ?? `n${++noticeSequence}`, createdAt: Date.now() }],
  })),
  dismissNotice: (id) => set((s) => ({ notices: s.notices.map((n) => (n.id === id ? { ...n, dismissing: true } : n)) })),
  removeNotice: (id) => set((s) => ({ notices: s.notices.filter((n) => n.id !== id) })),
  setResult: (ok, text, action) => set({ lastResult: { ok, text, action, at: Date.now() } }),
}));
