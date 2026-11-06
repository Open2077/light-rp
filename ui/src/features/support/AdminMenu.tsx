/* The admin menu's own sections (/admin, owner 2026-11-05: one menu for the platform's open77_admin
   tools and the LightRP ones). Every entry here runs a restricted server command as the operator
   (client/core/support.lua "command" -> open77:command:execute): the host checks command.<name>
   against the ACL each time, and `can` hides what the operator may not run (Overview.commands).
   The answer of each command comes back as a support "commandResult" and shows under the menu. */
import { useEffect, useRef, useState } from "react";
import type { RageMenuItem } from "@/design/components";
import { useFormFocus } from "./SupportForms";
import type { Person, Profile } from "./api";

export type AdminKind = "self" | "teleport" | "vehicles" | "vehicleList" | "items" | "itemList" | "weapons" | "weaponClass" | "ammo" | "world" | "time" | "weather" | "voice" | "missions" | "bosses" | "gigs" | "contracts" | "content" | "server";
export interface Catalog {
  vehicles: { key: string; label: string; category: string; record: string }[];
  items: { name: string; label: string; category: string }[];
  places: { name: string; label: string }[];
  weather: string[];
  /** Serialized firearms (LightRpArmament.weapons): the wheel lists them once given. */
  weapons: { id: string; label: string; class: string; ammo: string }[];
  /** Ammunition types (LightRpArmament.ammo): loose rounds, one native pool each. */
  ammo: { kind: string; label: string }[];
}
/** The server's catalogue: "a|b|c" rows (one value each on the wire). */
export function parseCatalog(raw: { vehicles?: unknown; items?: unknown; places?: unknown; weather?: unknown; weapons?: unknown; ammo?: unknown } | undefined): Catalog {
  const rows = (v: unknown) => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v) : []).filter((x): x is string => typeof x === "string").map(s => s.split("|"));
  return {
    vehicles: rows(raw?.vehicles).map(([key = "", label = "", category = "", record = ""]) => ({ key, label: label || key, category, record })).filter(v => v.key),
    items: rows(raw?.items).map(([name = "", label = "", category = "misc"]) => ({ name, label: label || name, category: category || "misc" })).filter(i => i.name),
    places: rows(raw?.places).map(([name = "", label = ""]) => ({ name, label: label || name })).filter(p => p.name),
    weather: rows(raw?.weather).map(r => r[0]!).filter(Boolean),
    weapons: rows(raw?.weapons).map(([id = "", label = "", cls = "", ammo = ""]) => ({ id, label: label || id, class: cls, ammo })).filter(w => w.id),
    ammo: rows(raw?.ammo).map(([kind = "", label = ""]) => ({ kind, label: label || kind })).filter(a => a.kind),
  };
}

export interface CommandField {
  id: string; label: string; type: "text" | "number" | "select";
  options?: { value: string; label: string }[]; initial?: string; min?: number; max?: number; maxLength?: number; placeholder?: string; optional?: boolean;
}
export interface CommandSpec {
  title: string; subtitle?: string; description?: string; fields: CommandField[];
  build: (values: Record<string, string>) => string[];
  /** A step with Cancel focused before it runs (kill, bulk actions, ...). */
  confirm?: string; danger?: boolean; close?: boolean;
}

type Entry = RageMenuItem & { run?: () => void; change?: (patch: Partial<RageMenuItem>) => void };
export interface AdminContext {
  can: (command: string) => boolean;
  run: (tokens: string[], options?: { close?: boolean }) => void;
  form: (spec: CommandSpec) => void;
  open: (kind: AdminKind, extra?: { category?: string }) => void;
  catalog?: Catalog;
  item: (id: string, text: string, run: () => void, options?: Partial<Entry>) => Entry;
  submenu: (id: string, text: string, run: () => void, options?: Partial<Entry>) => Entry;
}

const loading: Entry = { id: "loading", text: "Loading…", disabled: true };
const sep = (id: string): Entry => ({ id, separator: true } as Entry);
const title = (s: string) => s.replace(/(^|[_\s])(\w)/g, (_, a: string, b: string) => (a ? " " : "") + b.toUpperCase());

/** Only the entries the operator may run; a section with nothing left is not shown. */
function allowed(ctx: AdminContext, list: (Entry & { needs?: string })[]): Entry[] {
  const kept = list.filter(e => !e.needs || ctx.can(e.needs)).map(({ needs: _n, ...e }) => e as Entry);
  // no separator at an edge or twice in a row once entries are hidden
  return kept.filter((e, i) => !e.separator || (i > 0 && i < kept.length - 1 && !kept[i - 1]!.separator));
}
const needs = (e: Entry, command: string) => ({ ...e, needs: command });

/** Which root sections have something to offer. */
export function sectionHasAny(ctx: AdminContext, kind: AdminKind): boolean {
  const any = (...names: string[]) => names.some(n => ctx.can(n));
  switch (kind) {
    case "self": return any("lightrp.ghost", "admin.self.noclip", "admin.self.fly", "admin.self.god", "admin.self.heal", "admin.self.revive", "lightrp.needs", "lightrp.account", "adminfull");
    case "teleport": return any("lightrp.tp", "admin.self.maptravel", "admin.bulk.tpall");
    case "vehicles": return any("lightrp.car", "admin.veh.spawn", "lightrp.repair", "lightrp.refuel", "admin.veh.remove", "admin.world.cleanup", "admin.bulk.dvall");
    case "items": return any("lightrp.giveitem", "lightrp.giveweapon", "lightrp.giveammo");
    case "world": return any("weather.set", "weather.time.set", "lightrp.announce", "lightrp.broadcast");
    case "missions": return any("lightrp.missions", "worldboss.list", "worldboss.start", "fixers.list", "fixers.dispatch", "lightrp.dailies", "lightrp.activities", "turf.status", "lightrp.dogtown", "tcg.rooms");
    case "server": return any("lightrp.status", "admin.server.status", "lightrp.bots", "adminfull", "admin.bulk.tpall", "admin.bulk.dvall");
    default: return true;
  }
}

/** The wheel's own order: handguns first. */
export const WEAPON_CLASSES: { id: string; label: string; classes: string[] }[] = [
  { id: "handguns", label: "Handguns", classes: ["pistol", "revolver"] },
  { id: "smgs", label: "Submachine guns", classes: ["smg"] },
  { id: "shotguns", label: "Shotguns", classes: ["shotgun"] },
  { id: "rifles", label: "Assault rifles & LMGs", classes: ["rifle", "lmg"] },
  { id: "precision", label: "Precision & sniper rifles", classes: ["precision", "sniper"] },
];
const ammoLabel = (c: Catalog | undefined, kind: string) => c?.ammo.find(a => a.kind === kind)?.label || kind;
const roundOptions = (values: number[], none = false) => [...(none ? [{ value: "0", label: "No rounds" }] : []), ...values.map(v => ({ value: String(v), label: `${v} rounds` }))];
const weaponOptions = (c?: Catalog) => WEAPON_CLASSES.flatMap(g => (c?.weapons || []).filter(w => g.classes.includes(w.class)).map(w => ({ value: w.id, label: `${w.label} · ${g.label}` })));
/** A firearm and rounds of its own type, in one inventory write; the wheel shows it at once. */
export function giveWeaponSpec(c: Catalog | undefined, w: Catalog["weapons"][number], to: string, who?: string): CommandSpec {
  return { title: `Give ${w.label}`, subtitle: who, description: `A serialized firearm: it shows in the weapon wheel (TAB) at once. Rounds: ${ammoLabel(c, w.ammo).toLowerCase()}, shared by every weapon of that type.`,
    fields: [{ id: "r", label: `${ammoLabel(c, w.ammo)} with it`, type: "select", initial: "60", options: roundOptions([30, 60, 120, 250, 500], true) }],
    build: v => ["lightrp.giveweapon", to, w.id, v.r || "0"] };
}
export function giveAmmoSpec(c: Catalog | undefined, to: string, who?: string, kind?: string): CommandSpec {
  return { title: "Give ammunition", subtitle: who, description: "Loose rounds in the pockets: a weapon in hand loads them at once, the others when drawn.",
    fields: [
      ...(kind ? [] : [{ id: "k", label: "Type", type: "select" as const, options: [...(c?.ammo || []).map(a => ({ value: a.kind, label: a.label })), { value: "all", label: "Every type" }] }]),
      { id: "r", label: "Rounds", type: "select", initial: "120", options: roundOptions([30, 60, 120, 250, 500, 1000]) }],
    build: v => ["lightrp.giveammo", to, kind || v.k!, v.r!] };
}

const vehicleOptions = (c?: Catalog, by: "key" | "record" = "key") =>
  (c?.vehicles || []).filter(v => by === "key" || v.record).map(v => ({ value: by === "key" ? v.key : v.record, label: `${v.label} · ${v.category}` }));
const itemOptions = (c?: Catalog) => (c?.items || []).filter(i => i.category !== "weapon" && i.category !== "ammo").map(i => ({ value: i.name, label: `${i.label} · ${i.category}` }));
const placeOptions = (c?: Catalog) => (c?.places || []).map(p => ({ value: p.name, label: p.label }));

/** The entries of one admin section. */
export function adminSection(ctx: AdminContext, kind: AdminKind, extra: { category?: string } = {}): { title: string; subtitle: string; entries: Entry[] } {
  const { item, submenu, run, form, can } = ctx;
  if (kind === "self") return { title: "PERSONAL TOOLS", subtitle: "YOU", entries: allowed(ctx, [
    needs(item("ghost", "Ghost mode", () => run(["lightrp.ghost"], { close: true }), { icon: "eye-off", description: "Toggle. Noclip, your body hidden from the players, no nameplate, off their map. The menu closes; /lightrp.ghost or Ghost mode again to come back." }), "lightrp.ghost"),
    needs(item("noclip", "Noclip", () => run(["admin.self.noclip"], { close: true }), { icon: "navigation", description: "Toggle. The menu closes; type /noclip or reopen /admin to stop." }), "admin.self.noclip"),
    needs(item("fly", "Fly", () => run(["admin.self.fly"], { close: true }), { icon: "navigation", description: "Same switch as noclip, granted separately." }), "admin.self.fly"),
    needs(item("speed", "Noclip speed…", () => form({ title: "Noclip speed", fields: [{ id: "v", label: "Metres per second", type: "select", initial: "25", options: ["5", "10", "25", "50", "100", "250"].map(v => ({ value: v, label: `${v} m/s` })) }], build: v => ["admin.self.speed", v.v!] }), { icon: "gauge" }), "admin.self.speed"),
    needs(item("god", "God mode", () => run(["admin.self.god"]), { icon: "shield", description: "Toggle your own damage immunity." }), "admin.self.god"),
    needs(item("heal", "Heal myself", () => run(["admin.self.heal"]), { icon: "heart-pulse" }), "admin.self.heal"),
    needs(item("revive", "Revive myself", () => run(["admin.self.revive"]), { icon: "heart-pulse", description: "Back on your feet where you fell." }), "admin.self.revive"),
    needs(item("needs", "Fill hunger and thirst", () => run(["lightrp.needs", "me", "100", "100"]), { icon: "utensils" }), "lightrp.needs"),
    needs(item("account", "My account", () => run(["lightrp.account", "me"]), { icon: "id-card", description: "Account, character and bank number, in the result line." }), "lightrp.account"),
    needs(item("inventory", "My inventory (log)", () => run(["lightrp.inv"]), { icon: "backpack" }), "lightrp.inv"),
    sep("s1"),
    needs(item("console", "Platform console", () => run(["adminfull"], { close: true }), { icon: "terminal", description: "The full Open77 console (props, effects, every vehicle): takes the mouse." }), "adminfull"),
  ]) };

  if (kind === "teleport") {
    const places = ctx.catalog ? ctx.catalog.places : undefined;
    return { title: "TELEPORT", subtitle: "MOVE YOURSELF", entries: allowed(ctx, [
      needs(item("map", "Pick on the map", () => run(["admin.self.maptravel", "on"], { close: true }), { icon: "map-pin", description: "Open the world map and double-click a spot: you are placed there." }), "admin.self.maptravel"),
      needs(item("coords", "Coordinates…", () => form({ title: "Teleport to coordinates", description: "Game space: metres, X east, Y north, Z up.", fields: [
        { id: "x", label: "X", type: "number" }, { id: "y", label: "Y", type: "number" }, { id: "z", label: "Z", type: "number" }], build: v => ["lightrp.tp", "me", v.x!, v.y!, v.z!] }), { icon: "crosshair" }), "lightrp.tp"),
      ...(can("lightrp.tp") ? [sep("s1"), ...(!places ? [loading] : places.map(p => item(`place:${p.name}`, p.label, () => run(["lightrp.tp", "me", p.name]), { icon: "navigation", meta: p.name.toUpperCase() })))] : []),
      ...(can("admin.bulk.tpall") ? [sep("s2"), item("tpall", "Bring everyone to me", () => form({ title: "Bring everyone", danger: true, confirm: "Every other ready, alive player is moved around you, one at a time. Stand on open, level ground first.", fields: [], build: () => ["admin.bulk.tpall", "confirm"] }), { icon: "users", danger: true })] : []),
    ]) };
  }

  if (kind === "vehicles") return { title: "VEHICLES", subtitle: "SPAWN · REPAIR · CLEAN UP", entries: allowed(ctx, [
    needs(submenu("lightrp", "Spawn a LightRP vehicle", () => ctx.open("vehicleList"), { icon: "car", meta: ctx.catalog ? String(ctx.catalog.vehicles.length) : undefined, description: "The server's catalogue, with fuel and keys like a player's car." }), "lightrp.car"),
    needs(item("record", "Spawn any game vehicle…", () => form({ title: "Spawn a game vehicle", description: "A Vehicle.* record or a short alias from the platform catalogue (2.31).", fields: [{ id: "r", label: "Record or alias", type: "text", maxLength: 120, placeholder: "Vehicle.v_sport1_quadra_turbo_player" }], build: v => ["admin.veh.spawn", v.r!] }), { icon: "car" }), "admin.veh.spawn"),
    sep("s1"),
    needs(item("repair", "Repair and refuel", () => run(["lightrp.repair"]), { icon: "wrench", description: "The vehicle you sit in, else the nearest within 10 m." }), "lightrp.repair"),
    needs(item("refuel", "Refuel only", () => run(["lightrp.refuel"]), { icon: "fuel" }), "lightrp.refuel"),
    needs(item("impound", "Impound the nearest vehicle", () => form({ title: "Impound", confirm: "The vehicle you sit in (or the nearest) goes to the impound lot; its owner pays the fee to get it back.", fields: [], build: () => ["lightrp.impound"] }), { icon: "lock" }), "lightrp.impound"),
    needs(item("rentals", "Rental desks (log)", () => run(["lightrp.rentals"]), { icon: "key-round" }), "lightrp.rentals"),
    needs(item("fuelrate", "Fuel consumption…", () => form({ title: "Fuel consumption", fields: [{ id: "m", label: "Multiplier", type: "select", initial: "1", options: ["0.5", "1", "1.5", "2", "3"].map(v => ({ value: v, label: `x${v}` })) }], build: v => ["lightrp.fuelrate", v.m!] }), { icon: "gauge" }), "lightrp.fuelrate"),
    sep("s2"),
    needs(item("mine", "Remove my spawned vehicles", () => run(["admin.veh.remove", "mine"]), { icon: "trash-2" }), "admin.veh.remove"),
    needs(item("cleanup", "Remove every admin vehicle", () => run(["admin.world.cleanup"]), { icon: "recycle", description: "Unoccupied vehicles spawned from the admin tools." }), "admin.world.cleanup"),
    needs(item("dvall", "Remove EVERY vehicle", () => form({ title: "Remove every vehicle", danger: true, confirm: "All network vehicles, every resource and instance, once their occupants are out. Players' cars go back to their garages.", fields: [], build: () => ["admin.bulk.dvall", "confirm"] }), { icon: "trash-2", danger: true }), "admin.bulk.dvall"),
  ]) };

  if (kind === "vehicleList") {
    const rows = ctx.catalog?.vehicles;
    return { title: "LIGHTRP VEHICLES", subtitle: rows ? `${rows.length} MODELS` : "LOADING", entries: !rows ? [loading] : rows.map(v => item(`veh:${v.key}`, v.label, () => run(["lightrp.car", v.key]), { icon: "car", meta: v.category.toUpperCase(), description: `${v.key} · spawns beside you` })) };
  }

  if (kind === "items") {
    const rows = ctx.catalog?.items;
    const groups = new Map<string, number>();
    // firearms and rounds have their own pages (serials, the wheel, rounds by type)
    rows?.filter(i => i.category !== "weapon" && i.category !== "ammo").forEach(i => groups.set(i.category, (groups.get(i.category) || 0) + 1));
    return { title: "ITEMS & WEAPONS", subtitle: "GIVE TO YOURSELF", entries: !rows ? [loading] : allowed(ctx, [
      needs(submenu("weapons", "Weapons", () => ctx.open("weapons"), { icon: "crosshair", meta: String(ctx.catalog?.weapons.length ?? ""), description: "Every firearm, with rounds of its type: it shows in your weapon wheel (TAB) at once." }), "lightrp.giveweapon"),
      needs(submenu("ammo", "Ammunition", () => ctx.open("ammo"), { icon: "box", meta: String(ctx.catalog?.ammo.length ?? ""), description: "Loose rounds by type: the weapon in hand loads them at once." }), "lightrp.giveammo"),
      needs(item("mine", "My weapons and rounds", () => run(["lightrp.weapons", "me"]), { icon: "list-checks", description: "What your wheel lists and the rounds of each type, in the result line." }), "lightrp.weapons"),
      sep("i1"),
      ...(can("lightrp.giveitem") ? [...groups.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([cat, n]) => submenu(`cat:${cat}`, title(cat), () => ctx.open("itemList", { category: cat }), { icon: "package", meta: String(n) })) : []),
      { id: "hint", text: "To give a player: Players > them > Give", disabled: true } as Entry,
    ]) };
  }

  if (kind === "weapons") {
    const list = ctx.catalog?.weapons;
    return { title: "WEAPONS", subtitle: "INTO YOUR WHEEL", entries: !list ? [loading] : [
      ...WEAPON_CLASSES.map(g => ({ g, n: list.filter(w => g.classes.includes(w.class)).length })).filter(x => x.n > 0)
        .map(({ g, n }) => submenu(`class:${g.id}`, g.label, () => ctx.open("weaponClass", { category: g.id }), { icon: "crosshair", meta: String(n) })),
    ] };
  }

  if (kind === "weaponClass") {
    const group = WEAPON_CLASSES.find(g => g.id === extra.category);
    const list = (ctx.catalog?.weapons || []).filter(w => group?.classes.includes(w.class)).sort((a, b) => a.label.localeCompare(b.label));
    return { title: (group?.label || "WEAPONS").toUpperCase(), subtitle: `${list.length} FIREARMS`, entries: list.map(w =>
      item(`weapon:${w.id}`, w.label, () => form(giveWeaponSpec(ctx.catalog, w, "me")), { icon: "crosshair", meta: ammoLabel(ctx.catalog, w.ammo).split(" ")[0]!.toUpperCase(), description: `${w.class} · ${ammoLabel(ctx.catalog, w.ammo).toLowerCase()}` })) };
  }

  if (kind === "ammo") {
    const list = ctx.catalog?.ammo;
    return { title: "AMMUNITION", subtitle: "INTO YOUR POCKETS", entries: !list ? [loading] : [
      ...list.map(a => item(`ammo:${a.kind}`, a.label, () => form(giveAmmoSpec(ctx.catalog, "me", undefined, a.kind)), { icon: "box", meta: a.kind.toUpperCase() })),
      item("ammo:all", "Every type", () => form(giveAmmoSpec(ctx.catalog, "me", undefined, "all")), { icon: "box" }),
    ] };
  }

  if (kind === "itemList") {
    const rows = (ctx.catalog?.items || []).filter(i => i.category === extra.category);
    return { title: title(extra.category || "items").toUpperCase(), subtitle: `${rows.length} ITEMS`, entries: rows.map(i => item(`item:${i.name}`, i.label, () => form({ title: `Give ${i.label}`, subtitle: i.name, fields: [{ id: "n", label: "Count", type: "number", initial: "1", min: 1, max: 1000 }], build: v => ["lightrp.giveitem", "me", i.name, v.n || "1"] }), { meta: i.name })) };
  }

  if (kind === "world") {
    const weather = ctx.catalog?.weather || ["sunny", "cloudy", "rain", "fog"];
    const times: [string, string][] = [["06:00", "Dawn"], ["09:00", "Morning"], ["12:00", "Noon"], ["17:00", "Afternoon"], ["19:30", "Sunset"], ["23:00", "Night"], ["03:00", "Deep night"]];
    const time: Entry[] = allowed(ctx, [
      ...(can("weather.time.set") ? times.map(([t, label]) => item(`time:${t}`, `${label}`, () => run(["weather.time.set", t]), { icon: "clock", meta: t })) : []),
      needs(item("time", "Exact time…", () => form({ title: "Set the time", fields: [{ id: "t", label: "HH:MM", type: "text", maxLength: 8, placeholder: "21:30" }], build: v => ["weather.time.set", v.t!] }), { icon: "clock" }), "weather.time.set"),
      needs(item("freeze", "Freeze time", () => run(["weather.time.freeze"]), { icon: "timer" }), "weather.time.freeze"),
      needs(item("resume", "Resume time", () => run(["weather.time.resume"]), { icon: "timer" }), "weather.time.resume"),
    ]);
    const sky: Entry[] = allowed(ctx, [
      ...(can("weather.set") ? weather.map(w => item(`weather:${w}`, title(w), () => run(["weather.set", w, "15"]), { icon: "cloud-sun", description: "Blends over 15 seconds." })) : []),
      needs(item("next", "Next weather", () => run(["weather.next"]), { icon: "cloud-sun" }), "weather.next"),
      needs(item("randomOn", "Random weather: on", () => run(["weather.random", "on"]), { icon: "cloud-sun" }), "weather.random"),
      needs(item("randomOff", "Random weather: off", () => run(["weather.random", "off"]), { icon: "cloud-sun" }), "weather.random"),
    ]);
    const voice: Entry[] = allowed(ctx, [
      needs(item("announce", "Announcement…", () => form({ title: "Server announcement", fields: [{ id: "t", label: "Message", type: "text", maxLength: 200, placeholder: "Restart in 10 minutes." }], confirm: "Every player sees this announcement.", build: v => ["lightrp.announce", v.t!] }), { icon: "radio" }), "lightrp.announce"),
      needs(item("bcServer", "Voice broadcast: whole server", () => run(["lightrp.broadcast", "server"]), { icon: "mic", description: "Your voice reaches everyone. Turn it off here." }), "lightrp.broadcast"),
      needs(item("bcRadius", "Voice broadcast: 150 m around", () => run(["lightrp.broadcast", "150"]), { icon: "mic" }), "lightrp.broadcast"),
      needs(item("bcOff", "Voice broadcast: off", () => run(["lightrp.broadcast", "off"]), { icon: "mic-off" }), "lightrp.broadcast"),
    ]);
    return { title: "WORLD", subtitle: "TIME · WEATHER · VOICE", entries: [
      ...(time.length ? [submenu("time", "Time", () => ctx.open("time"), { icon: "clock", meta: String(time.length), description: "Presets from dawn to deep night, an exact time, freeze or resume the clock." })] : []),
      ...(sky.length ? [submenu("weather", "Weather", () => ctx.open("weather"), { icon: "cloud-sun", meta: String(sky.length), description: "Every weather of the city, the next one, random weather on or off." })] : []),
      ...(voice.length ? [submenu("voice", "Announcements & voice", () => ctx.open("voice"), { icon: "radio", meta: String(voice.length), description: "A server announcement, your voice to the whole server or around you." })] : []),
    ], parts: { time, weather: sky, voice } } as ReturnType<typeof adminSection> & { parts: Record<string, Entry[]> };
  }

  if (kind === "missions") {
    const bosses: Entry[] = allowed(ctx, [
    needs(item("bossList", "World bosses: schedule", () => run(["worldboss.list"]), { icon: "skull" }), "worldboss.list"),
    needs(item("bossStart", "Start the next world boss now", () => run(["worldboss.start"]), { icon: "skull" }), "worldboss.start"),
    needs(item("bossPick", "Start a world boss…", () => form({ title: "Start a world boss", fields: [{ id: "m", label: "Mission id or title", type: "text", maxLength: 80 }], build: v => ["worldboss.start", v.m!] }), { icon: "skull" }), "worldboss.start"),
    needs(item("bossNext", "Next world boss in…", () => form({ title: "Schedule the next boss", fields: [{ id: "n", label: "Minutes from now", type: "number", initial: "10", min: 1, max: 1440 }], build: v => ["worldboss.next", v.n!] }), { icon: "timer" }), "worldboss.next"),
    needs(item("bossWin", "End the boss fight: victory", () => form({ title: "End the boss fight", confirm: "The world boss ends as a WIN: rewards are paid to the participants.", fields: [], build: () => ["worldboss.stop", "win"] }), { icon: "crown" }), "worldboss.stop"),
    needs(item("bossStop", "Cancel the boss fight", () => form({ title: "Cancel the boss fight", danger: true, confirm: "The world boss ends without rewards.", fields: [], build: () => ["worldboss.stop"] }), { icon: "x", danger: true }), "worldboss.stop"),
    ]);
    const gigs: Entry[] = allowed(ctx, [
    needs(item("gigList", "Fixer gigs: open offers", () => run(["fixers.list"]), { icon: "briefcase" }), "fixers.list"),
    needs(item("gigNow", "Send a fixer gig now", () => run(["fixers.dispatch", "now"]), { icon: "send" }), "fixers.dispatch"),
    needs(item("gigOn", "Automatic gigs: on", () => run(["fixers.dispatch", "on"]), { icon: "briefcase" }), "fixers.dispatch"),
    needs(item("gigOff", "Automatic gigs: off", () => run(["fixers.dispatch", "off"]), { icon: "briefcase" }), "fixers.dispatch"),
    needs(item("gigCancel", "Cancel a gig…", () => form({ title: "Cancel a fixer gig", fields: [{ id: "g", label: "Gig id (see open offers)", type: "text", maxLength: 40 }], build: v => ["fixers.cancel", v.g!] }), { icon: "x" }), "fixers.cancel"),
    ]);
    const contracts: Entry[] = allowed(ctx, [
    needs(item("dailies", "Daily contracts: status", () => run(["lightrp.dailies", "status"]), { icon: "list-checks" }), "lightrp.dailies"),
    needs(item("dailiesOn", "Daily contracts: on", () => run(["lightrp.dailies", "on"]), { icon: "list-checks" }), "lightrp.dailies"),
    needs(item("dailiesOff", "Daily contracts: off", () => run(["lightrp.dailies", "off"]), { icon: "list-checks" }), "lightrp.dailies"),
    needs(item("activities", "Activities: status", () => run(["lightrp.activities"]), { icon: "activity" }), "lightrp.activities"),
    needs(item("turf", "Turf war: status", () => run(["turf.status"]), { icon: "flame" }), "turf.status"),
    needs(item("turfStart", "Turf war: start", () => run(["turf.start"]), { icon: "flame" }), "turf.start"),
    needs(item("turfStop", "Turf war: stop", () => form({ title: "Stop the turf war", confirm: "The running turf war ends now.", fields: [], build: () => ["turf.stop"] }), { icon: "flame" }), "turf.stop"),
    needs(item("dogtown", "Dogtown: status", () => run(["lightrp.dogtown", "status"]), { icon: "shield-alert" }), "lightrp.dogtown"),
    needs(item("rooms", "TCG private rooms", () => run(["tcg.rooms"]), { icon: "box" }), "tcg.rooms"),
    ]);
    return { title: "MISSIONS & EVENTS", subtitle: "BOSSES · GIGS · CONTRACTS", entries: [
      ...allowed(ctx, [needs(item("editor", "Mission editor", () => run(["lightrp.missions"], { close: true }), { icon: "swords", description: "Missions, world bosses and fixer gigs: create, edit, test, pin them all on the map." }), "lightrp.missions")]),
      ...(bosses.length ? [submenu("bosses", "World bosses", () => ctx.open("bosses"), { icon: "skull", meta: String(bosses.length), description: "The schedule, start one now or a given one, end the fight." })] : []),
      ...(gigs.length ? [submenu("gigs", "Fixer gigs", () => ctx.open("gigs"), { icon: "briefcase", meta: String(gigs.length), description: "Open offers, send one now, automatic dispatch, cancel." })] : []),
      ...(contracts.length ? [submenu("contracts", "Contracts & activities", () => ctx.open("contracts"), { icon: "list-checks", meta: String(contracts.length), description: "Daily contracts, activities, turf war, Dogtown, TCG rooms." })] : []),
    ], parts: { bosses, gigs, contracts } } as ReturnType<typeof adminSection> & { parts: Record<string, Entry[]> };
  }

  // a sub-section: the parent builds it (one place for each list)
  const parents: Record<string, [AdminKind, string, string]> = { time: ["world", "TIME", "CLOCK"], weather: ["world", "WEATHER", "SKY"], voice: ["world", "ANNOUNCEMENTS & VOICE", "TO EVERYONE"],
    bosses: ["missions", "WORLD BOSSES", "SCHEDULE · FIGHT"], gigs: ["missions", "FIXER GIGS", "OFFERS · DISPATCH"], contracts: ["missions", "CONTRACTS & ACTIVITIES", "DAILIES · TURF · ROOMS"] };
  const parent = parents[kind];
  if (parent) {
    const built = adminSection(ctx, parent[0]) as ReturnType<typeof adminSection> & { parts?: Record<string, Entry[]> };
    return { title: parent[1], subtitle: parent[2], entries: built.parts?.[kind] || [] };
  }

  if (kind === "server") return { title: "SERVER", subtitle: "STATUS · BULK ACTIONS", entries: allowed(ctx, [
    needs(item("status", "LightRP status", () => run(["lightrp.status"]), { icon: "activity" }), "lightrp.status"),
    needs(item("platform", "Platform status", () => run(["admin.server.status"]), { icon: "server" }), "admin.server.status"),
    needs(item("botsOn", "Ambient bots: on", () => run(["lightrp.bots", "on"]), { icon: "bot" }), "lightrp.bots"),
    needs(item("botsOff", "Ambient bots: off", () => run(["lightrp.bots", "off"]), { icon: "bot" }), "lightrp.bots"),
    sep("s1"),
    needs(item("tpall", "Bring everyone to me", () => form({ title: "Bring everyone", danger: true, confirm: "Every other ready, alive player is moved around you, one at a time. Stand on open, level ground first.", fields: [], build: () => ["admin.bulk.tpall", "confirm"] }), { icon: "users", danger: true }), "admin.bulk.tpall"),
    needs(item("dvall", "Remove EVERY vehicle", () => form({ title: "Remove every vehicle", danger: true, confirm: "All network vehicles, every resource and instance, once their occupants are out.", fields: [], build: () => ["admin.bulk.dvall", "confirm"] }), { icon: "trash-2", danger: true }), "admin.bulk.dvall"),
    needs(item("cancel", "Cancel the running bulk action", () => run(["admin.bulk.cancel"]), { icon: "x" }), "admin.bulk.cancel"),
    sep("s2"),
    needs(item("console", "Platform console", () => run(["adminfull"], { close: true }), { icon: "terminal", description: "The full Open77 console: props, effects, lights, every vehicle record." }), "adminfull"),
  ]) };

  return { title: "ADMIN", subtitle: "", entries: [] };
}

/** The staff desk's "Places & content" section: the editors and the world's fixtures. */
export function contentEntries(ctx: AdminContext, base: Entry[]): Entry[] {
  const { item, run } = ctx;
  return [...base, ...allowed(ctx, [
    sep("c1"),
    needs(item("boardWhere", "Job board: where is it", () => run(["lightrp.board", "where"]), { icon: "map-pin" }), "lightrp.board"),
    needs(item("boardRespawn", "Job board: respawn", () => run(["lightrp.board", "respawn"]), { icon: "undo-2" }), "lightrp.board"),
    needs(item("guideWhere", "Guide NPC: where is it", () => run(["lightrp.guide", "where"]), { icon: "map-pin" }), "lightrp.guide"),
    needs(item("guideRespawn", "Guide NPC: respawn", () => run(["lightrp.guide", "respawn"]), { icon: "undo-2" }), "lightrp.guide"),
    needs(item("hofRefresh", "Hall of fame: refresh", () => run(["lightrp.halloffame", "refresh"]), { icon: "crown" }), "lightrp.halloffame"),
  ])];
}

/** The platform and LightRP tools on one citizen's page (below the audited interventions). */
export function playerTools(ctx: AdminContext, p: Profile | Person): Entry[] {
  const { item, run, form } = ctx, id = String(p.id), who = `${p.name} · #${p.id}`;
  return allowed(ctx, [
    needs(item("spectate", "Spectate (noclip beside)", () => run(["admin.player.observe", id], { close: true }), { icon: "eye", description: "Teleport beside them with noclip on." }), "admin.player.observe"),
    needs(item("reviveHere", "Revive in place", () => run(["admin.player.revive", id]), { icon: "heart-pulse" }), "admin.player.revive"),
    needs(item("godOther", "Toggle god mode", () => run(["admin.player.god", id]), { icon: "shield" }), "admin.player.god"),
    needs(item("needsOther", "Fill hunger and thirst", () => run(["lightrp.needs", id, "100", "100"]), { icon: "utensils" }), "lightrp.needs"),
    needs(item("tpPlace", "Send to a place…", () => form({ title: "Send to a place", subtitle: who, fields: [{ id: "p", label: "Place", type: "select", options: placeOptions(ctx.catalog) }], build: v => ["lightrp.tp", id, v.p!] }), { icon: "navigation" }), "lightrp.tp"),
    needs(item("giveWeapon", "Give a weapon…", () => form({ title: "Give a weapon", subtitle: who, description: "A serialized firearm with rounds of its own type: it shows in their weapon wheel (TAB) at once.",
      fields: [{ id: "w", label: "Weapon", type: "select", options: weaponOptions(ctx.catalog) }, { id: "r", label: "Rounds of its type", type: "select", initial: "60", options: roundOptions([30, 60, 120, 250, 500], true) }],
      build: v => ["lightrp.giveweapon", id, v.w!, v.r || "0"] }), { icon: "crosshair" }), "lightrp.giveweapon"),
    needs(item("giveAmmo", "Give ammunition…", () => form(giveAmmoSpec(ctx.catalog, id, who)), { icon: "box" }), "lightrp.giveammo"),
    needs(item("theirWeapons", "Their weapons and rounds", () => run(["lightrp.weapons", id]), { icon: "list-checks" }), "lightrp.weapons"),
    needs(item("takeWeapon", "Take a weapon…", () => form({ title: "Take a weapon", subtitle: who, description: "One they carry and do not hold in a hand.", danger: true,
      fields: [{ id: "w", label: "Weapon", type: "select", options: weaponOptions(ctx.catalog) }], confirm: "The weapon leaves their inventory for good.",
      build: v => ["lightrp.takeweapon", id, v.w!] }), { icon: "trash-2", danger: true }), "lightrp.takeweapon"),
    needs(item("giveItem", "Give an item…", () => form({ title: "Give an item", subtitle: who, fields: [{ id: "i", label: "Item", type: "select", options: itemOptions(ctx.catalog) }, { id: "n", label: "Count", type: "number", initial: "1", min: 1, max: 1000 }], build: v => ["lightrp.giveitem", id, v.i!, v.n || "1"] }), { icon: "package" }), "lightrp.giveitem"),
    needs(item("giveVehicle", "Give a vehicle (garage)…", () => form({ title: "Give a vehicle", subtitle: who, description: "Owned for good: filed in their garage.", fields: [{ id: "v", label: "Vehicle", type: "select", options: vehicleOptions(ctx.catalog) }], confirm: "The vehicle becomes theirs.", build: v => ["lightrp.givevehicle", id, v.v!] }), { icon: "car" }), "lightrp.givevehicle"),
    needs(item("spawnBeside", "Spawn a vehicle beside them…", () => form({ title: "Spawn beside", subtitle: who, fields: [{ id: "r", label: "Vehicle", type: "select", options: vehicleOptions(ctx.catalog, "record") }], build: v => ["admin.veh.give", id, v.r!] }), { icon: "car" }), "admin.veh.give"),
    needs(item("cred", "Street cred…", () => form({ title: "Street cred", subtitle: who, description: "Adds (or removes, negative) reputation points.", fields: [{ id: "n", label: "Points", type: "number", initial: "100", min: -100000, max: 100000 }], build: v => ["missions.rep", id, v.n!] }), { icon: "crown" }), "missions.rep"),
    needs(item("gig", "Offer a fixer gig", () => run(["fixers.offer", id]), { icon: "briefcase" }), "fixers.offer"),
    needs(item("missionWin", "Complete their mission", () => run(["missions.complete", id]), { icon: "check" }), "missions.complete"),
    needs(item("missionFail", "Fail their mission", () => form({ title: "Fail the mission", subtitle: who, confirm: "Their running mission ends as a failure.", fields: [], build: () => ["missions.fail", id, "staff"] }), { icon: "x" }), "missions.fail"),
    needs(item("dailies", "Daily contracts", () => run(["lightrp.dailies", "status", id]), { icon: "list-checks" }), "lightrp.dailies"),
    needs(item("acc", "Account details", () => run(["lightrp.account", id]), { icon: "id-card" }), "lightrp.account"),
    needs(item("roomExit", "Out of their TCG room", () => run(["tcg.rooms", "exit", id]), { icon: "log-out" }), "tcg.rooms"),
    needs(item("kill", "Kill", () => form({ title: "Kill", subtitle: who, danger: true, confirm: "Their character dies (hospital flow).", fields: [], build: () => ["admin.player.kill", id] }), { icon: "skull", danger: true }), "admin.player.kill"),
  ]);
}

/** A command with its fields, then a confirmation when asked; the answer shows under the menu. */
export function CommandForm({ spec, onCancel, onRun }: { spec: CommandSpec; onCancel: () => void; onRun: (tokens: string[]) => void }) {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(spec.fields.map(f => [f.id, f.initial ?? (f.type === "select" ? f.options?.[0]?.value ?? "" : "")])));
  // no confirmation step (owner, 2026-11-05: "faut que ça soit rapide"): the fields, then Run
  const [confirm, setConfirm] = useState(false), [error, setError] = useState("");
  const cancel = useRef<HTMLButtonElement>(null), ref = useFormFocus();
  useEffect(() => { if (confirm) cancel.current?.focus(); else ref.current?.querySelector<HTMLElement>("input,select,button[data-submit]")?.focus(); }, [confirm, ref]);
  const tokens = () => spec.build(values).map(t => String(t).trim()).filter(Boolean);
  const submit = () => {
    for (const f of spec.fields) {
      const v = (values[f.id] || "").trim();
      if (!f.optional && !v) { setError(`${f.label}: required.`); return; }
      if (f.type === "number" && v && (!Number.isFinite(Number(v)) || (f.min !== undefined && Number(v) < f.min) || (f.max !== undefined && Number(v) > f.max))) { setError(`${f.label}: out of range.`); return; }
    }
    setError("");
    onRun(tokens());
  };
  return <div className="rp-support__action"><h2>{spec.title}</h2>{spec.subtitle && <p>{spec.subtitle}</p>}{spec.description && <p>{spec.description}</p>}
    {confirm ? <div className="rp-support__confirm" role="alertdialog" aria-label={`Confirm: ${spec.title}`}><h3>Confirm?</h3><p>{spec.confirm}</p>
      <blockquote>/{tokens().join(" ")}</blockquote>
      <footer><button ref={cancel} onClick={() => (spec.fields.length ? setConfirm(false) : onCancel())}>Cancel</button><button className={spec.danger ? "is-danger" : "is-primary"} onClick={submit}>Confirm</button></footer>
    </div> : <form className="rp-support__form" ref={ref} onSubmit={e => { e.preventDefault(); submit(); }}>
      {spec.fields.map(f => <label key={f.id}>{f.label}
        {f.type === "select"
          ? <select value={values[f.id]} onChange={e => setValues(v => ({ ...v, [f.id]: e.target.value }))}>{(f.options || []).map(o => <option key={o.value} value={o.value}>{o.label}</option>)}</select>
          : <input type={f.type === "number" ? "number" : "text"} min={f.min} max={f.max} maxLength={f.maxLength ?? 120} placeholder={f.placeholder} value={values[f.id]} onChange={e => setValues(v => ({ ...v, [f.id]: e.target.value }))} />}
      </label>)}
      <footer><button type="button" onClick={onCancel}>Back</button><button data-submit className={spec.danger ? "is-danger" : "is-primary"}>Run</button></footer>
    </form>}{error && <p className="rp-support__error" role="alert">{error}</p>}</div>;
}
