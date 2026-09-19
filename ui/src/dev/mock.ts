/* Browser stand-in for the game's bridge. Installed by main.tsx when
   `window.Open77` is absent (vite dev, screenshots). Plays a plausible session:
   state, ticking HUD, a notice, and answers to actions. `?menu=1` opens the menu,
   `?staff=1` grants staff, `?registered=1` skips the registration prompt. */
import { PAGE_EVENTS, type HudState, type UiAction, type UiState } from "@/bridge/protocol";
import type { Open77Bridge } from "@/bridge/open77";

export function installMockBridge(): void {
  const params = new URLSearchParams(location.search);
  const handlers = new Map<string, Set<(payload: unknown) => void>>();
  const fire = (name: string, payload: unknown) => { for (const fn of handlers.get(name) ?? []) fn(payload); };

  const state: UiState = {
    server: { name: "Open//77 Official Roleplay", playersOnline: 12, maxPlayers: 64, version: "2.31.13+op77.82" },
    character: { registered: params.get("registered") === "1", firstName: "Yuki", lastName: "Tanaka", accountName: "Nightwolf", playerId: 7, userId: "712e7c14-aeb4-47ee-b563-f6216c078e55", playtimeMs: 5_640_000 },
    needs: { food: 64, drink: 38 },
    vehicles: {
      catalog: [
        { key: "hella", label: "Archer Hella", category: "Street" }, { key: "quartz", label: "Archer Quartz", category: "Street" },
        { key: "cortes", label: "Villefort Cortes", category: "Street" }, { key: "supron", label: "Mahir Supron", category: "Utility" },
        { key: "kusanagi", label: "Yaiba Kusanagi", category: "Bikes" }, { key: "type66", label: "Quadra Type-66", category: "Sport", staffOnly: true },
      ],
      owned: [],
    },
    staff: { isStaff: params.get("staff") === "1", role: "operator" },
    locations: [{ name: "city", label: "City Center ouest" }, { name: "hospital", label: "Hôpital" }, { name: "stoop", label: "King Stoop" }, { name: "coast", label: "Côte sud-ouest" }],
    online: [{ id: 3, name: "w0dm4n" }, { id: 8, name: "szys" }, { id: 12, name: "fronterawave" }],
  };
  const hud: HudState = {
    ready: true, health: { value: 78, max: 100 }, stamina: { value: 92, max: 100 }, armor: 40,
    vehicle: params.get("vehicle") === "1" ? { active: true, label: "ARCHER QUARTZ", speedKph: 87, gear: "3", health: 0.9 } : { active: false },
    voice: { state: "idle", level: 0, range: "normal" }, clock: "22:41", street: "KANDA ST",
  };

  const bridge: Open77Bridge = {
    on(name, handler) { (handlers.get(name) ?? handlers.set(name, new Set()).get(name)!).add(handler); },
    off(name, handler) { handlers.get(name)?.delete(handler); },
    emit(name, payload) {
      console.log("[mock] emit", name, payload);
      if (name === PAGE_EVENTS.ready) {
        setTimeout(() => {
          fire(PAGE_EVENTS.state, state);
          fire(PAGE_EVENTS.hud, hud);
          if (params.get("menu") === "1") fire(PAGE_EVENTS.open, { view: params.get("view") ?? "character" });
          setTimeout(() => fire(PAGE_EVENTS.notice, { kind: "info", title: "Bienvenue à Night City", body: "Serveur Light RP. Tapez /register Prénom Nom pour créer votre personnage.", source: "LIGHT RP", durationMs: 9000 }), 400);
        }, 30);
      }
      if (name === PAGE_EVENTS.close) fire(PAGE_EVENTS.closed, {});
      if (name === PAGE_EVENTS.action) {
        const action = payload as UiAction;
        setTimeout(() => {
          if (action.type === "register") {
            state.character = { ...state.character, registered: true, firstName: action.firstName, lastName: action.lastName };
            fire(PAGE_EVENTS.state, { character: state.character });
            fire(PAGE_EVENTS.result, { ok: true, text: `Personnage enregistré : ${action.firstName} ${action.lastName}`, action: action.type });
          } else if (action.type === "vehicle.spawn") {
            const entry = state.vehicles.catalog.find((v) => v.key === action.key);
            state.vehicles = { ...state.vehicles, owned: entry ? [{ id: 4294967306, key: entry.key, label: entry.label }] : [] };
            fire(PAGE_EVENTS.state, { vehicles: state.vehicles });
            fire(PAGE_EVENTS.result, { ok: true, text: `${entry?.label ?? action.key} livré à côté de vous.`, action: action.type });
          } else if (action.type === "vehicle.return") {
            state.vehicles = { ...state.vehicles, owned: [] };
            fire(PAGE_EVENTS.state, { vehicles: state.vehicles });
            fire(PAGE_EVENTS.result, { ok: true, text: "Véhicule rendu.", action: action.type });
          } else if (action.type === "voice.range") {
            hud.voice = { ...hud.voice, range: action.range };
            fire(PAGE_EVENTS.hud, { ...hud });
          } else {
            fire(PAGE_EVENTS.result, { ok: true, text: `${action.type} accepté`, action: action.type });
          }
        }, 120);
      }
    },
    ready() { console.log("[mock] ready"); },
  };

  // A living HUD: voice pulses, stamina wobbles, the clock advances.
  let t = 0;
  setInterval(() => {
    t += 1;
    const talking = t % 40 < 12;
    hud.voice = { ...hud.voice, state: talking ? "talking" : "idle", level: talking ? 0.3 + Math.random() * 0.6 : 0 };
    hud.stamina = { value: 70 + Math.round(Math.sin(t / 8) * 20), max: 100 };
    if (hud.vehicle.active) hud.vehicle = { ...hud.vehicle, speedKph: 80 + Math.round(Math.sin(t / 10) * 25) };
    fire(PAGE_EVENTS.hud, { ...hud });
  }, 100);

  window.Open77 = bridge;
  window.__lightrpMock = true;
  document.body.style.background = "radial-gradient(ellipse at 40% 30%, #1b2230 0%, #0b0d12 60%, #050506 100%)";
}
