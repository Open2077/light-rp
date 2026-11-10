/* Browser stand-in for the game's bridge. Installed by main.tsx when
   `window.Open77` is absent (vite dev, screenshots). Plays a plausible session:
   state, the HUD state, a notice, and answers to actions. The HUD itself is NativeUI
   (client/native): nothing of it shows in a browser. Query flags:
   `?menu=1` opens the player menu, `?staff=1` grants staff,
   `?registered=1` skips the wizard, `?step=appearance|confirm` starts the wizard
   at that step, `?vehicle=1` seats the player, `?welcome=1` shows the first-spawn briefing,
   `?dialog=rental` opens a rental desk, `?rental=1` starts with a car out,
   `?dialog=inventory` opens the inventory (with a trunk on the right),
   `?dialog=halloffame` opens the Hall of Fame (features/halloffame/mock.ts),
   `?dialog=recap&recap=ffa|team|race|chase|turf|mission|boss|test|unranked|draw|big` opens an
   end-of-match recap (features/recap/mock.ts),
   `?tutorial=walk|edge|near|reveal` (with `?registered=1`) shows the first day guide's way to a stop (features/tutorial/mock.ts),
   `?dialog=dailies&tab=titles&dailies=mixed|fresh|budget|allpaid|off|loading&titles=shown|hidden|none&crew=1`
   opens Dailies (features/dailies/mock.ts),
   (the downed screen and the flatline cover are NativeUI: tools/native-lab, scenes medical-*) */
import { PAGE_EVENTS, type CharacterState, type HudState, type UiAction, type UiState } from "@/bridge/protocol";
import type { Open77Bridge } from "@/bridge/open77";
import { itemCatalogue } from "./itemCatalogue";
import { shopFixture } from "./shopFixture";
import { jobFixture } from "./jobFixture";
import { garageFixture } from "./garageFixture";
import { dealershipFixture } from "./dealershipFixture";
import { activitiesMock, missionMock } from "./missionFixture";
import { roomsMock } from "./roomsFixture";
import { basketSummary } from "@/features/shop/model";
import { safezonesMock } from "@/features/safezones/mock";
import { missionEditorMock } from "@/features/missioneditor/mock";
import { mapEditorMock } from "@/features/mapeditor/mock";
import { armamentMock } from "@/features/inventory/armamentMock";
import { hallOfFameMock } from "@/features/halloffame/mock";
import { recapMock } from "@/features/recap/mock";
import { guideMock } from "@/features/guide/mock";
import { dailiesMock } from "@/features/dailies/mock";
import { manekiMock } from "@/features/maneki/mock";
import { parkourMock } from "@/features/parkour/mock";
import { adminMock } from "@/features/support/mock";
import { tutorialMock } from "@/features/tutorial/mock";

const ORIGINS = [
  { key: "night_city", label: "Night City" }, { key: "badlands", label: "Badlands" }, { key: "ncus", label: "NUSA" },
  { key: "europe", label: "Europe" }, { key: "asia", label: "Asia" }, { key: "latam", label: "Latin America" },
];

export function installMockBridge(): void {
  const params = new URLSearchParams(location.search);
  const handlers = new Map<string, Set<(payload: unknown) => void>>();
  const fire = (name: string, payload: unknown) => { for (const fn of handlers.get(name) ?? []) fn(payload); };
  const safezones = safezonesMock(fire, params);
  const guide = guideMock(fire, params); // ?dialog=guide: the guide NPC's FAQ
  const missionEditor = missionEditorMock(fire, params);
  const mapEditor = mapEditorMock(fire, params);
  const armament = armamentMock(fire, params);
  const hallOfFame = hallOfFameMock(fire, params);
  const recap = recapMock(fire, params);
  const dailies = dailiesMock(fire, params);
  const maneki = manekiMock(fire, params); // ?maneki=desk|collection
  const parkour = parkourMock(fire, params); // ?parkour=hud|count|result|record|dnf|browser|editor
  const admin = adminMock(fire, params); // ?admin=1: the admin menu
  const firstDay = tutorialMock(fire, params); // ?tutorial=walk|edge|near|reveal: the first day guide's way to a stop

  const registered = params.get("registered") === "1";
  const shop = shopFixture();
  const garage = garageFixture();
  const mission = missionMock(params, (n, p) => fire(n, p));
  const activities = activitiesMock(params, (n, p) => fire(n, p)); // ?dialog=activities (&lobby=search|widened|offer|match|friendly)
  const rooms = roomsMock(params, (n, p) => fire(n, p)); // ?dialog=rooms (&room=host|member|private)
  const dealership = dealershipFixture();
  const step = (params.get("step") as CharacterState["step"] | null) ?? (registered ? "done" : "identity");
  const character: CharacterState = {
    registered, status: registered ? "active" : "draft", step, key: "default",
    firstName: step !== "identity" ? "Yuki" : undefined, lastName: step !== "identity" ? "Tanaka" : undefined,
    birthDate: step !== "identity" ? "2052-03-14" : undefined, origin: step !== "identity" ? "night_city" : undefined,
    story: step !== "identity" ? "Part-time netrunner, courier the rest of the time. Sleeps little, drives fast." : undefined,
    bodyFamily: "female",
    appearanceRevision: step === "confirm" || step === "done" ? 3 : 0, appearanceSavedAt: step === "done" ? "2077-09-19 22:41:00" : undefined,
    appearanceTracked: true, accountName: "Nightwolf", playerId: 7, userId: "712e7c14-aeb4-47ee-b563-f6216c078e55", playtimeMs: 5_640_000,
    slots: registered
      ? [{ key: "default", status: "active", name: "Yuki Tanaka", bodyFamily: "female", playtimeMs: 5_640_000, lastSeen: "2077-09-19" },
         { key: "slot2", status: "draft", name: "Marco Reyes", bodyFamily: "male", playtimeMs: 0 }]
      : [{ key: "default", status: "draft", playtimeMs: 0 }],
    maxSlots: 3, origins: ORIGINS, minAge: 18, maxAge: 90, currentYear: 2077,
    nameMinLength: 2, nameMaxLength: 24, nameAllowAccents: true,
    welcomePending: registered && params.get("welcome") === "1", welcomeReadSeconds: Number(params.get("read") ?? 15),
  };
  const state: UiState = {
    server: { name: "Open//77 Official Roleplay", playersOnline: 12, maxPlayers: 64, version: "2.31.13+op77.82" },
    character,
    needs: (() => {
      // ?starve=both|food|drink: starving banner; ?starve=fed: well fed regen
      const st = new URLSearchParams(location.search).get("starve");
      if (st === "fed") return { food: 92, drink: 88, wellFed: true, regenPerMinute: 5 };
      if (st === "both" || st === "food" || st === "drink")
        return { food: st === "drink" ? 46 : 0, drink: st === "food" ? 52 : 0, starving: st, drainPerMinute: st === "both" ? 12 : 6 };
      return { food: 64, drink: 38 };
    })(),
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
    job: { name: "sanitation", label: "NC Sanitation", tag: "SANITATION", grade: 1, gradeLabel: "Collector", salary: 60, paycheckMinutes: 30 },
    gang: { name: "valentinos", label: "Valentinos", tag: "VALENTINOS", color: "#D9A441", grade: 0, gradeLabel: "Recruit" },
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
    vehicle: params.get("vehicle") === "1" ? { active: true, label: "ARCHER QUARTZ", speedKph: 87, gear: "3", health: 0.9,
      fuel: params.get("fuel") === "empty" ? { litres: 0, capacity: 55, fraction: 0, low: true, empty: true }
        : params.get("fuel") === "low" ? { litres: 6.4, capacity: 55, fraction: 0.116, low: true, empty: false }
        : { litres: 31.7, capacity: 55, fraction: 0.576, low: false, empty: false } } : { active: false },
    voice: { state: "idle", level: 0, range: "normal" }, clock: "22:41", street: "KANDA ST",
    // ?weaponhud=external: op77_weaponhud's hologram is up and reaches 282 px (LightRP's readout stands down)
    weapon: params.get("weaponhud") === "external" ? { active: false, externalTop: 282 } : params.has("weaponhud") ? {
      active: params.get("weaponhud") !== "holstered", reserve: params.get("weaponhud") === "unknown" ? undefined : 59,
      hands: [
        { hand: "right", label: "Militech Lexington", magazine: params.get("weaponhud") === "unknown" ? undefined : params.get("weaponhud") === "empty" ? 0 : 21, capacity: 21, reloading: params.get("weaponhud") === "reload" },
        ...(params.get("weaponhud") === "dual" ? [{ hand: "left" as const, label: "Tsunami Nue", magazine: 10, capacity: 10, reloading: false }] : []),
      ],
    } : undefined,
    walk: params.get("walk") === "1" ? { mode: "walk", label: "WALK", speed: 1.5, index: 2, count: 3 } : undefined,
  };

  const patchCharacter = (patch: Partial<CharacterState>) => {
    state.character = { ...state.character, ...patch };
    fire(PAGE_EVENTS.state, { character: state.character });
  };
  const result = (ok: boolean, text: string, action: string) => fire(PAGE_EVENTS.result, { ok, text, action });
  let pumpLitres = params.get("fuel") === "empty" ? 0 : 18.3;
  let cans = { empty: 1, full: 0 };
  const fuelFixture = () => ({
    kind: "fuel" as const, spot: { id: "citycenter", name: "Gas Station // City Center" }, pricePerLitre: 3, pumpRange: 7,
    vehicle: params.get("novehicle") === "1" ? undefined : { id: 7306, label: "Thorton Galena", litres: pumpLitres, capacity: 55, moving: false },
    jerrycan: { litres: 20, refillPrice: 60, buyPrice: 85, ...cans },
    money: { currency: "€$", cash: state.money.cash, bank: state.money.bank?.balance ?? 0 },
  });

  const bridge: Open77Bridge = {
    on(name, handler) { (handlers.get(name) ?? handlers.set(name, new Set()).get(name)!).add(handler); },
    off(name, handler) { handlers.get(name)?.delete(handler); },
    emit(name, payload) {
      console.log("[mock] emit", name, payload);
      if (name === PAGE_EVENTS.safezones) { safezones.receive(payload); return; }
      if (name === PAGE_EVENTS.support && (maneki.receive(payload) || admin.receive(payload))) return;
      if (name === PAGE_EVENTS.missionEditor) { missionEditor.receive(payload); return; }
      if (name === PAGE_EVENTS.mapEditor) { mapEditor.receive(payload); return; }
      if (name === PAGE_EVENTS.parkourEditor) { parkour.editor(payload); return; }
      if (name === "lightrp:ui:grenades") { armament.receiveGrenade(payload); return; }
      if (name === PAGE_EVENTS.armament) { armament.receive(payload); return; }
    // the weapon wheel: Lua releases the focus and answers commit / cancel
    if (name === "lightrp:ui:weaponwheel") { const p = payload as { kind?: string; commit?: boolean }; if (p?.kind === "close") fire("lightrp:ui:weaponwheel", { kind: p.commit ? "commit" : "cancel" }); return; }
      if (name === PAGE_EVENTS.ready) {
        setTimeout(() => {
          // ?run=courier|task: an active work order; &near=1 stands on the marker
          const runKind = params.get("run");
          if (runKind) {
            state.job = runKind === "courier"
              ? { name: "delivery", label: "Courier", tag: "COURIER", grade: 0, gradeLabel: "Rider", salary: 0, paycheckMinutes: 30 }
              : state.job;
            state.jobRun = mockRun(runKind === "courier");
            if (params.get("duo") === "1") state.jobRun.duo = { partner: "Kei Mori", half: "A" };
          }
          // what the character wears, for the inventory's Worn column
          state.worn = { ready: true, family: "f", slots: { Head: "Items.Balaclava_02_basic_04", Face: false, InnerChest: "Items.TShirt_01_basic_01",
            OuterChest: "Items.Coat_01_basic_01", Legs: "Items.Pants_01_basic_01", Feet: "Items.Boots_01_basic_01", Outfit: false } };
          // ?outfit=1: an outfit worn as a layer, a cap over it, its glasses hidden
          if (params.get("outfit") === "1") state.worn = { ...state.worn, outfit: { label: "Street", image: undefined },
            sources: { Head: "over", Face: "hidden", InnerChest: "outfit", OuterChest: "outfit", Legs: "outfit", Feet: "outfit" },
            hidden: { Face: "Items.Glasses_01_basic_01" }, slots: { ...state.worn.slots, Face: false } };
          safezones.boot();
          missionEditor.boot();
          mapEditor.boot();
          armament.boot();
  // ?wheel=N: hold Control to open the wheel (as the CTRL key mapping does), ?wheelopen=1 opens it at once
  if (params.has("wheel")) {
    let open = false;
    const show = () => { if (!open) { open = true; fire("lightrp:ui:weaponwheel", { kind: "open", key: "CTRL" }); } };
    window.addEventListener("keydown", e => { if (e.key === "Control") show(); });
    window.addEventListener("keyup", e => { if (e.key === "Control" && open) { open = false; fire("lightrp:ui:weaponwheel", { kind: "commit" }); } });
    if (params.get("wheelopen") === "1") setTimeout(show, 600);
  }
          if (firstDay.tutorial) state.tutorial = firstDay.tutorial;
          fire(PAGE_EVENTS.state, state);
          firstDay.boot();
          fire(PAGE_EVENTS.hud, hud);
          if (params.get("dialog") === "shop") fire(PAGE_EVENTS.dialog, shop);
          if (params.get("dialog") === "garage") fire(PAGE_EVENTS.dialog, garage);
          if (params.get("dialog") === "dealership") fire(PAGE_EVENTS.dialog, dealership);
          mission.boot();
          hallOfFame.boot();
          recap.boot();
          guide.boot();
          dailies.boot();
          maneki.boot();
          parkour.boot();
          admin.boot();
          if (params.get("dialog") === "activities") activities.boot();
          if (params.get("dialog") === "rooms") rooms.boot();
          if (params.get("dialog") === "mission") mission.open();
          else if (params.get("queue") === "1") mission.queueOnly();
          if (params.get("mission") === "1") mission.running();
          if (params.get("menu") === "1") fire(PAGE_EVENTS.open, {});
          if (params.get("dialog") === "inventory" && params.get("weapons") !== "1") fire(PAGE_EVENTS.dialog, { kind: "inventory",
            left: { id: "player:1", kind: "player", label: "Yuki Tanaka", slots: 30, maxWeight: 40, weight: 6.3, items: [
              { slot: 1, name: "phone", label: "Phone", count: 1, weight: 0.3, icon: "smartphone", image: "img/items/phone.png", usable: false, stack: 1, description: "Your holo." },
              { slot: 2, name: "water", label: "Bottle of Water", count: 3, weight: 0.5, icon: "droplet", usable: true, stack: 10, description: "Still water." },
              { slot: 3, name: "burrito", label: "Burrito", count: 2, weight: 0.4, icon: "sandwich", usable: true, stack: 10 },
              { slot: 4, name: "bandage", label: "Bandage", count: 4, weight: 0.2, icon: "bandage", usable: true, stack: 10 },
              { slot: 7, name: "wrench", label: "Wrench", count: 1, weight: 1.2, icon: "wrench", image: "img/items/wrench.png", usable: false, stack: 1 },
              { slot: 9, name: "scrap", label: "Scrap", count: 12, weight: 1.0, icon: "box", image: "img/items/scrap.png", usable: false, stack: 50 },
              { slot: 10, name: "clothing", label: "Aviator Glasses", count: 1, weight: 0.2, icon: "glasses", category: "clothing", usable: true, stack: 1, description: "A garment. Use it to put it on or take it off.", metadata: { record: "Items.Glasses_01_basic_01", slot: "Face" } },
              { slot: 11, name: "cash", label: "Cash", count: 459, weight: 0, icon: "banknote", category: "currency", usable: false, stack: 1000000 } ] },
            right: { id: "trunk:7306", kind: "trunk", label: "Archer Hella", slots: 20, maxWeight: 80, weight: 8, items: [
              { slot: 1, name: "repairkit", label: "Repair Kit", count: 1, weight: 3.0, icon: "hammer", usable: false, stack: 2 },
              { slot: 2, name: "trashbag", label: "Trash Bag", count: 1, weight: 4.0, icon: "package", usable: false, stack: 5 } ] } });
          if (params.get("items") === "1") fire(PAGE_EVENTS.dialog, { kind: "inventory",
            left: { id: "player:catalogue", kind: "player", label: "RP consumables · preview", slots: 30, maxWeight: 40,
              weight: itemCatalogue.reduce((sum, item) => sum + item.weight * item.count, 0), items: itemCatalogue },
            right: { id: "ground", kind: "ground", label: "Ground", slots: 1, maxWeight: 0, weight: 0, items: [] } });
          // &duo=1: the courier offers the Big Contract (job_runs.lua), and a courier run is one half of it
          if (params.get("dialog") === "jobcenter") { const f = jobFixture(); if (params.get("duo") === "1") for (const j of f.jobs) if (j.route?.variable) j.route.duo = true; fire(PAGE_EVENTS.dialog, f); }
          if (params.get("dialog") === "fuel") fire(PAGE_EVENTS.dialog, fuelFixture());
          if (params.get("dialog") === "rental") fire(PAGE_EVENTS.dialog, { kind: "rental", spot: { id: "citycenter", name: "Rent-a-Ride // City Center", durationMinutes: 30, stock: [
            { key: "maimai", label: "Makigai MaiMai", category: "Street", price: 60 }, { key: "hella", label: "Archer Hella", category: "Street", price: 120 },
            { key: "cortes", label: "Villefort Cortes", category: "Street", price: 140 }, { key: "semimaru", label: "Yaiba Semimaru", category: "Sport", price: 90 },
            { key: "supron", label: "Mahir Supron", category: "Utility", price: 180 } ] } });
          if (registered && params.get("dialog") !== "shop") setTimeout(() => fire(PAGE_EVENTS.notice, { kind: "info", title: "Welcome to Night City", body: "Light RP server. F1 opens your player menu, /help lists the commands.", source: "LIGHT RP", durationMs: 9000 }), 400);
        }, 30);
      }
      if (name === PAGE_EVENTS.close) fire(PAGE_EVENTS.closed, {});
      if (name === PAGE_EVENTS.action) {
        const action = payload as UiAction;
        if (mission.handle(action)) return;
        if (parkour.action(action as { type: string })) return;
        if (params.get("dialog") === "activities" && activities.handle(action)) return;
        if (params.get("dialog") === "rooms" && rooms.handle(action)) return;
        if (hallOfFame.handle(action)) return;
        if (recap.handle(action)) return;
        if (guide.handle(action)) return;
        if (dailies.handle(action)) return;
        setTimeout(() => {
          switch (action.type) {
            case "dealership.buy": {
              const item = dealership.stock.find(v => v.key === action.key);
              if (!item || action.request !== dealership.nextRequest) break;
              const ok = dealership.money[action.pay] >= item.price;
              if (ok) dealership.money[action.pay] -= item.price;
              dealership.nextRequest++;
              fire("lightrp:ui:dealership", { session: dealership.session, request: action.request, ok,
                vehicleId: ok ? "1b922040-preview-owned" : undefined,
                text: ok ? `Your ${item.label} is waiting at ${dealership.garage.name}.` : "Insufficient funds.", state: structuredClone(dealership) });
              break;
            }
            case "dealership.close": break;
            case "garage.retrieve":
            case "garage.store": {
              const vehicle = garage.vehicles.find(v => v.id === action.vehicle);
              if (!vehicle || action.request !== garage.nextRequest) break;
              vehicle.status = action.type === "garage.retrieve" ? "out" : "stored";
              vehicle.canRetrieve = vehicle.status === "stored";
              vehicle.canStore = vehicle.status === "out";
              garage.nextRequest++;
              fire("lightrp:ui:garage", { session: garage.session, request: action.request, ok: true,
                text: vehicle.status === "out" ? "Your vehicle is parked outside. Press L to unlock." : "Vehicle and trunk stored safely.", state: structuredClone(garage) });
              break;
            }
            case "garage.close": break;
            case "shop.close": break;
            case "shop.checkout": {
              const summary = basketSummary(shop, Object.fromEntries(action.lines.map(line => [line.name, line.count])), action.mode, action.pay);
              const ok = !summary.issue;
              if (ok) {
                shop.money = { ...shop.money, [action.pay]: shop.money[action.pay] + (action.mode === "buy" ? -summary.total : summary.total) };
                shop.items = shop.items.map(item => ({ ...item, owned: item.owned + (action.mode === "buy" ? 1 : -1) * (action.lines.find(line => line.name === item.name)?.count ?? 0) }));
                shop.inventory = { ...shop.inventory, weight: summary.afterWeight,
                  items: shop.items.filter(item => item.owned > 0).flatMap(item => Array.from({ length: Math.ceil(item.owned / item.stack) }, (_, index) => ({ ...item, slot: 0, count: Math.min(item.stack, item.owned - index * item.stack), usable: true }))).map((item, i) => ({ ...item, slot: i + 1 })) };
              }
              shop.nextRequest = action.request + 1;
              fire(PAGE_EVENTS.shop, { session: action.session, request: action.request, ok,
                text: ok ? `${action.mode === "buy" ? "Purchase" : "Sale"} complete. Preview only — no real items or money.` : summary.issue, state: { ...shop } });
              break;
            }
            case "character.identity": {
              const c = state.character;
              const hasBody = c.bodyFamily != null;
              patchCharacter({ firstName: action.firstName, lastName: action.lastName, birthDate: action.birthDate, origin: action.origin, story: action.story,
                step: c.status === "active" ? "done" : hasBody ? "confirm" : "appearance" });
              result(true, `Identity saved: ${action.firstName} ${action.lastName}`, action.type);
              break;
            }
            case "character.appearance.open":
              fire(PAGE_EVENTS.characterEditor, { active: true });
              // The native mirror would open here; the mock "saves" a body two seconds later.
              setTimeout(() => {
                const c = state.character;
                patchCharacter({ bodyFamily: action.family ?? c.bodyFamily ?? "female", appearanceRevision: c.appearanceRevision + 1,
                  appearanceSavedAt: "2077-09-19 22:41:00", step: c.status === "active" ? "done" : c.firstName ? "confirm" : "identity" });
                fire(PAGE_EVENTS.notice, { kind: "success", title: "Appearance saved", body: `Revision ${state.character.appearanceRevision}.`, source: "LIGHT RP", durationMs: 5000 });
                fire(PAGE_EVENTS.characterEditor, { active: false });
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
            case "fuel.buy": {
              const price = Math.ceil(action.litres * 3);
              if (action.pay === "cash") state.money.cash -= price; else if (state.money.bank) state.money.bank.balance -= price;
              pumpLitres = Math.min(55, pumpLitres + action.litres);
              fire(PAGE_EVENTS.state, { money: state.money });
              result(true, `Refuelled ${action.litres} L for €$ ${price}.`, action.type);
              fire(PAGE_EVENTS.dialog, fuelFixture());
              break;
            }
            case "fuel.jerrycan": {
              const price = cans.empty > 0 ? 60 : 85;
              cans = { empty: Math.max(0, cans.empty - 1), full: cans.full + 1 };
              if (action.pay === "cash") state.money.cash -= price; else if (state.money.bank) state.money.bank.balance -= price;
              fire(PAGE_EVENTS.state, { money: state.money });
              result(true, `${price === 60 ? "Jerrycan refilled" : "Jerrycan bought"} for €$ ${price}.`, action.type);
              fire(PAGE_EVENTS.dialog, fuelFixture());
              break;
            }
            case "rental.return":
              state.rental = {};
              fire(PAGE_EVENTS.state, { rental: state.rental });
              result(true, "Vehicle returned.", action.type);
              break;
            case "jobs.apply": {
              const offer = jobFixture().jobs.find((j) => j.name === action.job);
              if (!offer) { result(false, "Unknown job.", action.type); break; }
              state.job = { name: offer.name, label: offer.label, tag: offer.tag, grade: 0, gradeLabel: offer.entryGrade.label, salary: offer.entryGrade.salary, paycheckMinutes: 30 };
              state.jobRun = { active: false };
              fire(PAGE_EVENTS.state, { job: state.job, jobRun: state.jobRun });
              result(true, `Hired: ${action.job}.`, action.type);
              break;
            }
            case "clothing.refresh":
              fire(PAGE_EVENTS.state, { worn: state.worn }); break;
            case "clothing.makeOutfit":
              if (state.worn) { state.worn = { ...state.worn, outfit: { label: action.name || "My outfit" },
                sources: Object.fromEntries(Object.entries(state.worn.slots).filter(([, v]) => v).map(([k]) => [k, "outfit"])) }; fire(PAGE_EVENTS.state, { worn: state.worn }); }
              result(true, "Your outfit is made.", "inventory.makeOutfit"); break;
            case "clothing.takeOff":
              if (state.worn) { state.worn = { ...state.worn, slots: { ...state.worn.slots, [action.slot]: false } }; fire(PAGE_EVENTS.state, { worn: state.worn }); }
              result(true, "Taking it off…", "inventory.takeOff"); break;
            case "jobs.locate":
              result(true, "GPS set. No shift or employment required.", action.type); break;
            case "jobs.start": {
              const offer = jobFixture().jobs.find((j) => j.name === state.job.name);
              if (!offer?.route) { result(false, "Choose a job first.", action.type); break; }
              state.jobRun = offer.route.variable
                ? { active: true, id: "mock-work-order", job: offer.name, label: offer.route.label, reward: 342,
                    index: 2, total: 6, icon: "package", orders: 3, carried: 1, distanceKm: 2.4,
                    hint: "Collect the order at the marker (E). Keep 1 kg free in your bag.",
                    objective: { label: "Pick up · Burger stand", kind: "pickup", position: { x: 0, y: 0, z: 0 }, radius: 2.6 } }
                : { active: true, id: "mock-work-order", job: offer.name, label: offer.route.label, reward: offer.route.reward,
                    index: 1, total: 4, icon: offer.recruitment?.icon, hint: "Follow the yellow marker. Press E at the work point.",
                    objective: { label: "Collect the first load", kind: "work", position: { x: 0, y: 0, z: 0 }, radius: 2.6 } };
              if (action.duo) state.jobRun.duo = { partner: "Kei Mori", half: "A" };
              fire(PAGE_EVENTS.state, { jobRun: state.jobRun });
              result(true, "Work order assigned.", action.type); break;
            }
            case "jobs.cancel":
              state.jobRun = { active: false }; fire(PAGE_EVENTS.state, { jobRun: state.jobRun });
              result(true, "Work order cancelled.", action.type); break;
            case "jobs.quit":
              state.job = { name: "unemployed", label: "Unemployed", tag: "CIVILIAN", grade: 0, gradeLabel: "Citizen", salary: 0, paycheckMinutes: 30 };
              state.jobRun = { active: false };
              fire(PAGE_EVENTS.state, { job: state.job, jobRun: state.jobRun });
              result(true, "You quit your job.", action.type);
              break;
            case "welcome.ack":
              patchCharacter({ welcomePending: false });
              break;
            case "inventory.use":
              armament.useGrenade(action.slot);result(true,"Item selected.",action.type);break;
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
    if(params.get("hotbar")==="1")fire("lightrp:ui:hotbar",{kind:"state",state:armament.hotbar(),visible:true,showKey:"TAB",slotKeys:["1","2","3","4","5"]});
  }, 100);

  window.Open77 = bridge;
  window.__lightrpMock = true;
  document.body.style.background = "radial-gradient(ellipse at 40% 30%, #1b2230 0%, #0b0d12 60%, #050506 100%)";
}

/** A run in progress for ?run=: a courier with three orders (one picked up), or a task route. */
function mockRun(courier: boolean): import("@/bridge/protocol").JobRunState {
  if (courier) {
    const pick = ["Station kiosk", "Misty's Esoterica", "Tom's Diner"], drop = ["Megabuilding H10", "Afterlife", "Lizzie's Bar"];
    const steps = [...pick.map((p, i) => ({ kind: "pickup" as const, place: p, order: i + 1 })), ...drop.map((p, i) => ({ kind: "dropoff" as const, place: p, order: i + 1 }))];
    const index = 2;
    return { active: true, id: "mock-run", job: "delivery", jobLabel: "Courier", label: "Delivery run", reward: 554, icon: "package",
      index, total: steps.length, orders: 3, carried: 1, distanceKm: 4.4, expiresInMs: 23 * 60000 + 14000,
      hint: "Go to the yellow marker and press E to collect the order. It needs 1 kg free in your bag.",
      stops: steps.map((s, i) => ({ ...s, label: `${s.kind === "pickup" ? "Pick up" : "Deliver"} · ${s.place}`, state: i + 1 < index ? "done" as const : i + 1 === index ? "now" as const : "todo" as const })),
      objective: { label: `Pick up · ${pick[1]}`, place: pick[1], kind: "pickup", position: { x: 0, y: 0, z: 0 }, radius: 2.6 } };
  }
  const places = ["Collect the first load", "Arasaka Waterfront bins", "Kabuki market", "Return to the depot"];
  return { active: true, id: "mock-run", job: "sanitation", jobLabel: "NC Sanitation", label: "Collection round", reward: 220, icon: "trash-2",
    index: 3, total: places.length, expiresInMs: 2 * 60000 + 40000, hint: "Follow the yellow marker. Press E at the work point.",
    stops: places.map((p, i) => ({ kind: i === 3 ? "return" as const : "work" as const, label: p, place: p, state: i + 1 < 3 ? "done" as const : i + 1 === 3 ? "now" as const : "todo" as const })),
    objective: { label: places[2]!, place: places[2], kind: "work", position: { x: 0, y: 0, z: 0 }, radius: 2.6 } };
}
