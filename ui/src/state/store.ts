import { create } from "zustand";
import type { HudState, MenuView, NoticeKindWire, UiState, UiStatePatch } from "@/bridge/protocol";

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
  character: { registered: false, accountName: "", playerId: 0 },
  needs: { food: 100, drink: 100 },
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
  menuOpen: boolean;
  menuView: MenuView;
  notices: Notice[];
  lastResult?: { ok: boolean; text: string; at: number };
  setConnected(value: boolean): void;
  applyState(patch: UiStatePatch): void;
  setHud(hud: HudState): void;
  openMenu(view?: MenuView): void;
  closeMenu(): void;
  setMenuView(view: MenuView): void;
  pushNotice(notice: Omit<Notice, "id" | "createdAt"> & { id?: string }): void;
  dismissNotice(id: string): void;
  removeNotice(id: string): void;
  setResult(ok: boolean, text: string): void;
}

let noticeSequence = 0;

export const useStore = create<Store>((set) => ({
  connected: false,
  state: EMPTY_STATE,
  hud: EMPTY_HUD,
  menuOpen: false,
  menuView: "character",
  notices: [],
  setConnected: (value) => set({ connected: value }),
  applyState: (patch) => set((s) => ({ state: { ...s.state, ...patch } })),
  setHud: (hud) => set({ hud }),
  openMenu: (view) => set((s) => ({ menuOpen: true, menuView: view ?? s.menuView })),
  closeMenu: () => set({ menuOpen: false }),
  setMenuView: (view) => set({ menuView: view }),
  pushNotice: (notice) => set((s) => ({
    notices: [...s.notices.slice(-5), { ...notice, id: notice.id ?? `n${++noticeSequence}`, createdAt: Date.now() }],
  })),
  dismissNotice: (id) => set((s) => ({ notices: s.notices.map((n) => (n.id === id ? { ...n, dismissing: true } : n)) })),
  removeNotice: (id) => set((s) => ({ notices: s.notices.filter((n) => n.id !== id) })),
  setResult: (ok, text) => set({ lastResult: { ok, text, at: Date.now() } }),
}));
