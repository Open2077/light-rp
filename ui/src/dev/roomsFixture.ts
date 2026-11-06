import { PAGE_EVENTS, type ActivitiesState, type ActivityEntry, type RoomView, type RoomsState, type UiAction } from "@/bridge/protocol";

/* The hosting menu in the dev preview: ?dialog=rooms, &room=host|member|private for a
   room already open, &crew=leader|member for a crew of three. It answers like server/modules/activity_rooms.lua, without rules. */

type Fire = (name: string, payload: unknown) => void;

const maps = ["Kabuki Yards", "Arroyo Plant", "Pacifica Mall", "Rancho Bridge"];
const entry = (id: string, label: string, kind: ActivityEntry["kind"], minPlayers: number, maxPlayers: number, description: string, withMaps: boolean): ActivityEntry => ({
  id, label, kind, description, minPlayers, maxPlayers, phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: kind === "race",
  modes: withMaps ? maps.map((name) => ({ id: name.toLowerCase().replace(" ", "-"), label: name })) : [], modeKey: "map", top: [],
});
const ACTIVITIES: ActivityEntry[] = [
  entry("games.tdm", "Team Deathmatch", "pvp", 2, 12, "Two teams, first to the kill limit.", true),
  entry("games.ctf", "Capture the Flag", "pvp", 2, 12, "Take their flag home, keep yours.", true),
  entry("games.gungame", "Gun Game", "pvp", 2, 12, "A new gun with every kill.", true),
  entry("games.redlight", "Red Light Green Light", "event", 2, 16, "Move on green, freeze on red.", true),
  entry("games.prophunt", "Prop Hunt", "event", 3, 12, "Hide as the scenery, or find who did.", true),
  entry("arena.ffa", "Combat Zone", "pvp", 1, 16, "Free-for-all. First to 20 frags.", false),
  entry("race.grid", "Street Race", "race", 2, 8, "Two to eight drivers, identical loaner cars.", false),
];
const GAMES: RoomsState["games"] = [
  { id: "games.tdm", teams: 2, least: 1, most: 6 }, { id: "games.ctf", teams: 2, least: 1, most: 6 }, { id: "games.gungame", least: 2, most: 12 },
  { id: "games.redlight", least: 2, most: 16 }, { id: "games.prophunt", least: 3, most: 12 }, { id: "arena.ffa", least: 2, most: 16 }, { id: "race.grid", least: 2, most: 8 },
];
const others = [{ id: 87, name: "Kei Mori" }, { id: 132, name: "Rosa Vasquez" }, { id: 401, name: "Nix Halloran" }];

export function roomsMock(params: URLSearchParams, fire: Fire) {
  const activities: ActivitiesState = {
    enabled: true, hub: { name: "The Crossing" }, list: ACTIVITIES, current: false, queued: false, mission: false, eligible: true, nearby: [], contracts: [],
    reputation: { today: 0, dailyCap: 300, maxPerResult: 60 },
  };
  const rooms: RoomsState = {
    enabled: true, eligible: params.get("blocked") !== "1", reason: params.get("blocked") === "1" ? "Step out of the vehicle first." : undefined, full: false, games: GAMES, room: false,
    list: [
      { id: 3, activity: "games.tdm", label: "Team Deathmatch", mode: "kabuki-yards", modeLabel: "Kabuki Yards", host: "Rosa Vasquez", count: 5, max: 12, teams: 2 },
      { id: 4, activity: "race.grid", label: "Street Race", host: "Nix Halloran", count: 8, max: 8 },
      { id: 7, activity: "games.prophunt", label: "Prop Hunt", host: "Kei Mori", count: 2, max: 12 },
    ],
  };
  const crew = params.get("crew");
  const party = crew ? { you: 7, leader: crew === "leader" ? 7 : 87, members: [{ id: 7 }, { id: 87 }, { id: 132 }] } : undefined;
  const push = () => fire(PAGE_EVENTS.state, { activities: structuredClone(activities), rooms: structuredClone(rooms), ...(party ? { party } : {}) });
  const answer = (ok: boolean, text: string) => setTimeout(() => fire(PAGE_EVENTS.result, { ok, text, action: "activities.rooms" }), 120);
  const me = { id: 7, name: "Vi Asada", host: true };
  const issue = (r: RoomView) => r.teams?.some((t) => t.length === 0) ? "Team B is empty: move a player." : r.count < 2 ? `${r.label} needs 2 players.` : undefined;
  const open = (id: string, mine: boolean, secret: boolean, mode?: string, size?: number) => {
    const game = GAMES.find((g) => g.id === id)!;
    const a = ACTIVITIES.find((x) => x.id === id)!;
    const room: RoomView = {
      id: 12, activity: id, label: a.label, mode, modeLabel: a.modes.find((m) => m.id === mode)?.label, host: mine ? me.name : others[0]!.name, count: 1,
      max: 0, private: secret, code: secret ? "K7QMX" : undefined, mine, size: size ?? game.most, least: game.least, most: game.most,
    };
    room.max = room.size * (game.teams ?? 1);
    if (game.teams) room.teams = [[me], []]; else room.players = [me];
    room.issue = issue(room);
    rooms.room = room;
  };
  const boot = () => {
    const seeded = params.get("room");
    if (seeded) {
      open("games.tdm", seeded !== "member", seeded === "private", "arroyo-plant");
      const r = rooms.room as RoomView;
      r.teams = [[{ ...me, host: seeded !== "member" }, { ...others[1]!, host: seeded === "member" || undefined }], [others[0]!, others[2]!]];
      r.count = 4; r.issue = undefined;
    }
    push();
    fire(PAGE_EVENTS.dialog, { kind: "rooms" });
  };
  const handle = (action: UiAction): boolean => {
    if (action.type !== "activities.rooms") return false;
    const room = rooms.room || undefined;
    switch (action.operation) {
      case "create": open(action.id, true, action.private === true, action.mode, action.size); answer(true, action.private ? "Room open. Code: K7QMX" : "Room open."); break;
      case "join":
        if (action.code && action.code !== "K7QMX") { answer(false, "No room has that code."); return true; }
        open("games.gungame", false, !!action.code);
        answer(true, "You joined Kei Mori's room.");
        break;
      case "leave": rooms.room = false; answer(true, "You left the room."); break;
      case "start": answer(true, "Friendly starting · unranked."); rooms.room = false; activities.queued = { id: "games.tdm", label: "Team Deathmatch", sinceMs: 0, match: true, friendly: true, ranked: false }; break;
      case "kick": if (room?.teams) room.teams = room.teams.map((t) => t.filter((p) => p.id !== action.target)); if (room) { room.count -= 1; room.issue = issue(room); } answer(true, "Out of the room."); break;
      case "move":
        if (room?.teams) {
          const p = room.teams.flat().find((x) => x.id === action.target)!;
          room.teams = room.teams.map((t) => t.filter((x) => x.id !== action.target));
          room.teams[action.team - 1]!.push(p);
          room.issue = issue(room);
        }
        break;
      case "settings":
        if (room) {
          if (action.mode !== undefined) { room.mode = action.mode || undefined; room.modeLabel = ACTIVITIES.find((a) => a.id === room.activity)?.modes.find((m) => m.id === action.mode)?.label; }
          if (action.size !== undefined) { room.size = action.size; room.max = action.size * (room.teams?.length ?? 1); }
          if (action.private !== undefined) { room.private = action.private; room.code = action.private ? "K7QMX" : undefined; }
        }
        break;
      default: return true;
    }
    setTimeout(push, 100);
    return true;
  };
  return { boot, handle };
}
