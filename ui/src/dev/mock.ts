/* Browser stand-in for the game's bridge. Installed by main.tsx when
   `window.Open77` is absent (vite dev, screenshots). Plays a plausible session:
   state, ticking HUD, a notice, and answers to actions. Query flags:
   `?menu=1` opens the player menu, `?staff=1` grants staff,
   `?registered=1` skips the wizard, `?step=appearance|confirm` starts the wizard
   at that step, `?vehicle=1` seats the player, `?welcome=1` shows the first-spawn briefing,
   `?dialog=rental` opens a rental desk, `?rental=1` starts with a car out,
   `?interact=1` shows the proximity prompt. */
import { PAGE_EVENTS, type CharacterState, type HudState, type UiAction, type UiState } from "@/bridge/protocol";
import type { Open77Bridge } from "@/bridge/open77";

const ORIGINS = [
  { key: "night_city", label: "Night City" }, { key: "badlands", label: "Badlands" }, { key: "ncus", label: "NUSA" },
  { key: "europe", label: "Europe" }, { key: "asia", label: "Asia" }, { key: "latam", label: "Latin America" },
];

export function installMockBridge(): void {
  const params = new URLSearchParams(location.search);
  const handlers = new Map<string, Set<(payload: unknown) => void>>();
  const fire = (name: string, payload: unknown) => { for (const fn of handlers.get(name) ?? []) fn(payload); };

  const registered = params.get("registered") === "1";
  const step = (params.get("step") as CharacterState["step"] | null) ?? (registered ? "done" : "identity");
  const character: CharacterState = {
    registered, status: registered ? "active" : "draft", step, key: "default",
    firstName: step !== "identity" ? "Yuki" : undefined, lastName: step !== "identity" ? "Tanaka" : undefined,
    birthDate: step !== "identity" ? "2052-03-14" : undefined, origin: step !== "identity" ? "night_city" : undefined,
    story: step !== "identity" ? "Part-time netrunner, courier the rest of the time. Sleeps little, drives fast." : undefined,
    bodyFamily: step === "confirm" || step === "done" ? "female" : undefined,
    appearanceRevision: step === "confirm" || step === "done" ? 3 : 0, appearanceSavedAt: step === "done" ? "2077-09-19 22:41:00" : undefined,
    appearanceTracked: true, accountName: "Nightwolf", playerId: 7, userId: "712e7c14-aeb4-47ee-b563-f6216c078e55", playtimeMs: 5_640_000,
    slots: registered
      ? [{ key: "default", status: "active", name: "Yuki Tanaka", bodyFamily: "female", playtimeMs: 5_640_000, lastSeen: "2077-09-19" },
         { key: "slot2", status: "draft", name: "Marco Reyes", bodyFamily: "male", playtimeMs: 0 }]
      : [{ key: "default", status: "draft", playtimeMs: 0 }],
    maxSlots: 3, origins: ORIGINS, minAge: 18, currentYear: 2077,
    welcomePending: registered && params.get("welcome") === "1", welcomeReadSeconds: Number(params.get("read") ?? 15),
  };
  const state: UiState = {
    server: { name: "Open//77 Official Roleplay", playersOnline: 12, maxPlayers: 64, version: "2.31.13+op77.82" },
    character,
    needs: { food: 64, drink: 38 },
    money: registered ? {
      currency: "€$", cash: 340, bank: { number: "K7F-2QD", balance: 2860 },
      history: [
        { wallet: "bank", kind: "salary", amount: 420, balanceAfter: 2860, counterparty: "NC Sanitation", note: "Garbage run · route 4", at: "2077-09-19 21:10:00" },
        { wallet: "cash", kind: "pay_out", amount: -60, balanceAfter: 340, counterparty: "Marco Reyes", at: "2077-09-19 20:48:00" },
        { wallet: "bank", kind: "transfer_out", amount: -300, balanceAfter: 2440, counterparty: "Judy Alvarez · 9QM-T3W", note: "Rent", at: "2077-09-18 23:05:00" },
        { wallet: "cash", kind: "withdraw", amount: 400, balanceAfter: 400, counterparty: "Night City Bank", at: "2077-09-18 22:59:00" },
        { wallet: "bank", kind: "opening", amount: 1500, balanceAfter: 1500, counterparty: "Night City Bank", note: "Account opened", at: "2077-09-17 19:30:00" },
      ],
    } : { currency: "€$", cash: 0, history: [] },
    rental: params.get("rental") === "1"
      ? { active: { spotId: "citycenter", spotName: "Rent-a-Ride // City Center", key: "hella", label: "Archer Hella", price: 120, paidWith: "cash", remainingMs: 17 * 60000 + 42000 } }
      : {},
    vehicles: {
      catalog: [
        { key: "hella", label: "Archer Hella", category: "Street" }, { key: "quartz", label: "Archer Quartz", category: "Street" },
        { key: "cortes", label: "Villefort Cortes", category: "Street" }, { key: "supron", label: "Mahir Supron", category: "Utility" },
        { key: "kusanagi", label: "Yaiba Kusanagi", category: "Bikes" }, { key: "type66", label: "Quadra Type-66", category: "Sport", staffOnly: true },
      ],
      owned: [],
    },
    staff: { isStaff: params.get("staff") === "1", role: "operator" },
    locations: [{ name: "city", label: "City Center West" }, { name: "hospital", label: "Hospital" }, { name: "stoop", label: "King Stoop" }, { name: "coast", label: "South-west Coast" }],
    online: [{ id: 3, name: "w0dm4n" }, { id: 8, name: "szys" }, { id: 12, name: "fronterawave" }],
  };
  const hud: HudState = {
    ready: true, health: { value: 78, max: 100 }, stamina: { value: 92, max: 100 }, armor: 40,
    vehicle: params.get("vehicle") === "1" ? { active: true, label: "ARCHER QUARTZ", speedKph: 87, gear: "3", health: 0.9 } : { active: false },
    voice: { state: "idle", level: 0, range: "normal" }, clock: "22:41", street: "KANDA ST",
  };

  const patchCharacter = (patch: Partial<CharacterState>) => {
    state.character = { ...state.character, ...patch };
    fire(PAGE_EVENTS.state, { character: state.character });
  };
  const result = (ok: boolean, text: string, action: string) => fire(PAGE_EVENTS.result, { ok, text, action });

  const bridge: Open77Bridge = {
    on(name, handler) { (handlers.get(name) ?? handlers.set(name, new Set()).get(name)!).add(handler); },
    off(name, handler) { handlers.get(name)?.delete(handler); },
    emit(name, payload) {
      console.log("[mock] emit", name, payload);
      if (name === PAGE_EVENTS.ready) {
        setTimeout(() => {
          fire(PAGE_EVENTS.state, state);
          fire(PAGE_EVENTS.hud, hud);
          if (params.get("menu") === "1") fire(PAGE_EVENTS.open, {});
          if (params.get("interact") === "1") {
            fire(PAGE_EVENTS.interact, { id: "rental.citycenter", prompt: "Rent a vehicle", key: "E" });
            setInterval(() => fire("open77:anchors", { anchors: [{ id: "1", tag: "interact", kind: "position", x: 0.52 + Math.sin(Date.now() / 900) * 0.01, y: 0.55, depth: 3, distance: 3, onScreen: true }] }), 33);
          }
          if (params.get("dialog") === "rental") fire(PAGE_EVENTS.dialog, { kind: "rental", spot: { id: "citycenter", name: "Rent-a-Ride // City Center", durationMinutes: 30, stock: [
            { key: "maimai", label: "Makigai MaiMai", category: "Street", price: 60 }, { key: "hella", label: "Archer Hella", category: "Street", price: 120 },
            { key: "cortes", label: "Villefort Cortes", category: "Street", price: 140 }, { key: "semimaru", label: "Yaiba Semimaru", category: "Bikes", price: 90 },
            { key: "supron", label: "Mahir Supron", category: "Utility", price: 180 }, { key: "type66", label: "Quadra Type-66", category: "Sport", price: 900 } ] } });
          setTimeout(() => fire(PAGE_EVENTS.notice, { kind: "info", title: "Welcome to Night City", body: "Light RP server. F1 opens your player menu, /help lists the commands.", source: "LIGHT RP", durationMs: 9000 }), 400);
        }, 30);
      }
      if (name === PAGE_EVENTS.close) fire(PAGE_EVENTS.closed, {});
      if (name === PAGE_EVENTS.action) {
        const action = payload as UiAction;
        setTimeout(() => {
          switch (action.type) {
            case "character.identity": {
              const c = state.character;
              const hasBody = c.bodyFamily != null;
              patchCharacter({ firstName: action.firstName, lastName: action.lastName, birthDate: action.birthDate, origin: action.origin, story: action.story,
                step: c.status === "active" ? "done" : hasBody ? "confirm" : "appearance" });
              result(true, `Identity saved: ${action.firstName} ${action.lastName}`, action.type);
              break;
            }
            case "character.appearance.open":
              // The native mirror would open here; the mock "saves" a body two seconds later.
              setTimeout(() => {
                const c = state.character;
                patchCharacter({ bodyFamily: action.family ?? c.bodyFamily ?? "female", appearanceRevision: c.appearanceRevision + 1,
                  appearanceSavedAt: "2077-09-19 22:41:00", step: c.status === "active" ? "done" : c.firstName ? "confirm" : "identity" });
                fire(PAGE_EVENTS.notice, { kind: "success", title: "Appearance saved", body: `Revision ${state.character.appearanceRevision}.`, source: "LIGHT RP", durationMs: 5000 });
              }, 2000);
              break;
            case "character.finish":
              patchCharacter({ status: "active", registered: true, step: "done", welcomePending: true,
                slots: state.character.slots.map((s) => (s.key === state.character.key ? { ...s, status: "active", name: `${state.character.firstName} ${state.character.lastName}`, bodyFamily: state.character.bodyFamily } : s)) });
              result(true, `Welcome to Night City, ${state.character.firstName} ${state.character.lastName}.`, action.type);
              break;
            case "character.new": {
              const key = `slot${state.character.slots.length + 1}`;
              patchCharacter({ key, status: "draft", registered: false, step: "identity", firstName: undefined, lastName: undefined, birthDate: undefined,
                origin: undefined, story: undefined, bodyFamily: undefined, appearanceRevision: 0, appearanceSavedAt: undefined,
                slots: [...state.character.slots, { key, status: "draft", playtimeMs: 0 }] });
              result(true, "New slot opened: create this character.", action.type);
              break;
            }
            case "character.select": {
              const slot = state.character.slots.find((s) => s.key === action.key);
              if (slot) patchCharacter({ key: slot.key, status: slot.status, registered: slot.status === "active", step: slot.status === "active" ? "done" : "identity",
                firstName: slot.name?.split(" ")[0], lastName: slot.name?.split(" ")[1], bodyFamily: slot.bodyFamily });
              result(true, `Character loaded: ${slot?.name ?? action.key}`, action.type);
              break;
            }
            case "character.archive":
              patchCharacter({ slots: state.character.slots.filter((s) => s.key !== action.key) });
              result(true, "Character archived.", action.type);
              break;
            case "money.deposit": case "money.withdraw": {
              const m = state.money;
              if (!m.bank) { result(false, "You have no wallet yet.", action.type); break; }
              const out = action.type === "money.deposit";
              if ((out ? m.cash : m.bank.balance) < action.amount) { result(false, "Insufficient funds.", action.type); break; }
              const cash = m.cash + (out ? -action.amount : action.amount);
              const bank = { ...m.bank, balance: m.bank.balance + (out ? action.amount : -action.amount) };
              state.money = { ...m, cash, bank, history: [
                { wallet: out ? "bank" : "cash", kind: out ? "deposit" : "withdraw", amount: action.amount, balanceAfter: out ? bank.balance : cash, counterparty: "Night City Bank" },
                ...m.history] };
              fire(PAGE_EVENTS.state, { money: state.money });
              result(true, `€$ ${action.amount.toLocaleString("en-US")} ${out ? "deposited" : "withdrawn"}.`, action.type);
              break;
            }
            case "rental.rent": {
              if (state.rental.active) { result(false, "You already have a vehicle out. Return it first.", action.type); break; }
              const price = action.key === "type66" ? 900 : action.key === "supron" ? 180 : action.key === "cortes" ? 140 : action.key === "hella" ? 120 : action.key === "semimaru" ? 90 : 60;
              const m = state.money;
              if ((action.pay === "bank" ? (m.bank?.balance ?? 0) : m.cash) < price) { result(false, "Insufficient funds.", action.type); break; }
              state.money = action.pay === "bank" && m.bank ? { ...m, bank: { ...m.bank, balance: m.bank.balance - price } } : { ...m, cash: m.cash - price };
              state.rental = { active: { spotId: action.spot, spotName: "Rent-a-Ride // City Center", key: action.key, label: action.key.toUpperCase(), price, paidWith: action.pay, remainingMs: 30 * 60000 } };
              fire(PAGE_EVENTS.state, { money: state.money, rental: state.rental });
              result(true, `${action.key.toUpperCase()} rented for €$ ${price}.`, action.type);
              break;
            }
            case "rental.return":
              state.rental = {};
              fire(PAGE_EVENTS.state, { rental: state.rental });
              result(true, "Vehicle returned.", action.type);
              break;
            case "welcome.ack":
              patchCharacter({ welcomePending: false });
              break;
            case "voice.range":
              hud.voice = { ...hud.voice, range: action.range };
              fire(PAGE_EVENTS.hud, { ...hud });
              break;
            default:
              result(true, `${action.type} accepted`, action.type);
          }
        }, 120);
      }
    },
    ready() { console.log("[mock] ready"); },
  };

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
