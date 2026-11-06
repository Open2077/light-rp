import { PAGE_EVENTS } from "@/bridge/protocol";

/* Dev mock (no Open77 bridge): ?admin=1 opens the admin menu (/admin) with every right, two players,
   the catalogue and an answer to each command it runs. */
type Fire = (name: string, payload: unknown) => void;
const COMMANDS = ["lightrp.ghost", "admin.self.noclip", "admin.self.fly", "admin.self.speed", "admin.self.god", "admin.self.heal", "admin.self.revive", "admin.self.maptravel",
  "admin.player.revive", "admin.player.god", "admin.player.kill", "admin.player.observe", "admin.veh.spawn", "admin.veh.give", "admin.veh.remove", "admin.world.cleanup",
  "admin.bulk.tpall", "admin.bulk.dvall", "admin.bulk.cancel", "admin.server.status", "adminfull", "weather.set", "weather.next", "weather.random", "weather.time.set",
  "weather.time.freeze", "weather.time.resume", "lightrp.tp", "lightrp.car", "lightrp.repair", "lightrp.refuel", "lightrp.impound", "lightrp.rentals", "lightrp.fuelrate",
  "lightrp.giveitem", "lightrp.giveweapon", "lightrp.giveammo", "lightrp.takeweapon", "lightrp.weapons", "lightrp.givevehicle", "lightrp.needs", "lightrp.account", "lightrp.inv", "lightrp.status", "lightrp.bots", "lightrp.announce", "lightrp.broadcast",
  "lightrp.missions", "lightrp.activities", "lightrp.dailies", "lightrp.dogtown", "lightrp.guide", "lightrp.board", "lightrp.halloffame", "worldboss.list", "worldboss.start",
  "worldboss.stop", "worldboss.next", "fixers.list", "fixers.dispatch", "fixers.offer", "fixers.cancel", "missions.launch", "missions.complete", "missions.fail", "missions.rep",
  "turf.status", "turf.start", "turf.stop", "tcg.rooms"];
const job = (label: string) => ({ name: label.toLowerCase(), label, grade: 0, gradeLabel: "Recruit" });
const PLAYERS = [
  { id: 1, account: "op77:nightwolf", character: "default", name: "Nico Vance", accountName: "Nightwolf", status: "active", job: job("Unemployed"), gang: job("None"), life: "alive", playtimeMs: 7200e3 },
  { id: 2, account: "op77:jeremzzzer", character: "default", name: "Jerem Kade", accountName: "Jeremzzzer", status: "active", job: job("Courier"), gang: job("None"), life: "alive", playtimeMs: 3600e3 },
];
export function adminMock(fire: Fire, params: URLSearchParams) {
  const on = params.get("admin") === "1";
  return {
    boot() { if (on) fire(PAGE_EVENTS.dialog, { kind: "support", scope: "staff" }); },
    receive(payload: unknown): boolean {
      const p = payload as { operation?: string; request?: string; tokens?: string[]; target?: number };
      if (!on) return false;
      if (p?.operation === "command") {
        const raw = (p.tokens || []).join(" ");
        setTimeout(() => fire(PAGE_EVENTS.support, { kind: "commandResult", raw, ok: !raw.startsWith("admin.player.kill"), text: raw.startsWith("admin.player.kill") ? "Refused: not in this mock." : `${raw}: done (mock).` }), 150);
        return true;
      }
      if (!p?.request) return false;
      const reply = (data: unknown) => setTimeout(() => fire(PAGE_EVENTS.support, { kind: "response", request: p.request, ok: true, data }), 80);
      if (p.operation === "overview") {
        reply({ players: PLAYERS, staff: [{ id: 1, name: "Nightwolf" }], commands: COMMANDS.join(","), jobs: [], gangs: [], database: true,
          permissions: { view: true, reports: true, audit: true, tables: true, maneki: true, housing: true, safezones: true, gotoPlayer: true, bring: true, heal: true, warn: true, kick: true, ban: true, credit: true, debit: true, rename: true, job: true, gang: true } });
        return true;
      }
      if (p.operation === "adminCatalog") {
        reply({
          vehicles: ["maimai|Makigai MaiMai|Street|Vehicle.v_standard2_makigai_maimai_player", "galena|Thorton Galena|Street|Vehicle.v_standard2_thorton_galena_player", "apollo|Brennan Apollo|Bike|Vehicle.v_sportbike2_brennan_apollo_player", "kusanagi|Yaiba Kusanagi|Bike|Vehicle.v_sportbike1_yaiba_kusanagi_player"],
          items: ["water|Bottle of Water|drink", "medkit|MaxDoc Mk.1|medical", "weapon_lexington|Militech Lexington|weapon", "weapon_unity|Arasaka Unity|weapon", "ammo_handgun|Handgun rounds|ammo", "tcg_booster_wnc|TCG Booster · Night City|collectible"],
          places: ["city|City Center West", "hospital|Hospital", "stoop|King Stoop", "north|North Promenade"],
          weather: ["sunny", "cloudy", "rain", "fog", "sandstorm"],
          weapons: ["weapon_lexington|Militech Lexington|pistol|pistol", "weapon_overture|Malorian Arms Overture|revolver|pistol", "weapon_m221_saratoga|M221 Saratoga|smg|pistol", "weapon_crusher|Budget Arms Crusher|shotgun|shotgun", "weapon_m251s_ajax|Militech M251s Ajax|rifle|rifle", "weapon_spt32_grad|SPT32 Grad|sniper|sniper"],
          ammo: ["pistol|Handgun rounds", "rifle|Rifle rounds", "shotgun|Shotgun shells", "sniper|Sniper rounds"],
        });
        return true;
      }
      if (p.operation === "player") {
        const person = PLAYERS.find(x => x.id === p.target) || PLAYERS[0]!;
        reply({ ...person, firstName: person.name.split(" ")[0], lastName: person.name.split(" ")[1], birthDate: "2049-04-12", origin: "Night City", story: "Fresh off the bus.", money: { cash: 1200, bank: 5400, number: "NC-0042" }, position: { x: -667, y: -382, z: 9, bucket: 0 }, history: [], canReturn: false });
        return true;
      }
      if (p.operation === "list") { reply({ tickets: [], page: 1, pageSize: 10, total: 0, summary: { total: 0, open: 0, progress: 0, waiting: 0, finished: 0 }, categories: [], maxOpen: 3 }); return true; }
      if (p.operation === "audit") { reply({ entries: [], page: 1, hasMore: false }); return true; }
      return false;
    },
  };
}
