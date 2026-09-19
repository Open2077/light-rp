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

export const useStore = create<Store>((set) => ({
  connected: false,
  state: EMPTY_STATE,
  hud: EMPTY_HUD,
  menuOpen: false,
  notices: [],
  welcomeReplay: false,
  rentalReceivedAt: Date.now(),
  setConnected: (value) => set({ connected: value }),
  setWelcomeReplay: (value) => set({ welcomeReplay: value }),
  applyState: (patch) => set((s) => ({ state: { ...s.state, ...patch }, rentalReceivedAt: patch.rental ? Date.now() : s.rentalReceivedAt })),
  openDialog: (payload) => set({ dialog: payload }),
  closeDialog: () => set({ dialog: undefined }),
  // Fresh snapshots replace the matching side of the open inventory dialog; a
  // snapshot for an unknown id (the server switched the secondary) lands on the right.
  updateInventories: (list) => set((s) => {
    if (!s.dialog || s.dialog.kind !== "inventory") return {};
    let { left, right } = s.dialog;
    for (const snap of list) {
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
