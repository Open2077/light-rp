/* ?dialog=mission: a mission point with live boards, played in the browser.
   &tagged=1 starts tagged on STANDARD; &squad=1 puts you in a squad of three;
   &invite=1 adds a pending squad invite. Tagging, the squad tag, the host's
   launch (countdown) and squad actions all answer like the server would. */
import { PAGE_EVENTS, type MissionBoard, type MissionDialogPayload, type MissionLobbyMember, type PartyState, type UiAction } from "@/bridge/protocol";

type Fire = (name: string, payload: unknown) => void;

export function missionMock(params: URLSearchParams, fire: Fire) {
  const me: MissionLobbyMember = { id: 214, name: "Vi Asada", citizen: "214", tier: 2, host: false };
  const squad = params.get("squad") === "1";
  const party: PartyState = squad
    ? { id: "squad:1", leader: 214, maxSize: 8, invites: [], members: [
        { id: 214, name: "Vi Asada", leader: true, tier: 2 }, { id: 87, name: "Kei Mori", leader: false, tier: 1 }, { id: 132, name: "Rosa Vasquez", leader: false, tier: 2 }] }
    : { maxSize: 8, invites: [] };
  if (params.get("invite") === "1") party.invites = [{ party: "squad:9", from: 55, fromName: "Dex DeShawn", expiresInMs: 60000 }];
  const lobbies: Record<string, MissionLobbyMember[]> = {
    standard: [{ id: 301, name: "J. Okonkwo", citizen: "301", tier: 1, host: true }],
    hard: [301, 302, 303, 304, 305].map((id, i) => ({ id, name: ["Ana Reyes", "Bo Tanaka", "Cy Novak", "Dee Park", "Eli Stone"][i]!, citizen: String(id), tier: 2, host: i === 0 })),
    critical: [],
  };
  const spec = { standard: { min: 2, max: 4 }, hard: { min: 4, max: 6 }, critical: { min: 6, max: 8 } } as const;
  let tagged: string | undefined, countdownAt: number | undefined;
  const board = (id: keyof typeof spec): MissionBoard => {
    const members = lobbies[id]!.map((m, i) => ({ ...m, host: i === 0 }));
    return { id: "lobby:" + id, difficulty: id, members, min: spec[id].min, max: spec[id].max,
      state: countdownAt && tagged === id ? "countdown" : "open", countdownMs: countdownAt && tagged === id ? Math.max(0, countdownAt - Date.now()) : undefined,
      host: members[0]?.name };
  };
  const snapshot = (): MissionDialogPayload => ({
    kind: "mission", session: "mission:1",
    point: { id: "sector04_blackout", title: "Sector 04 Blackout", type: "HEIST", location: "SECTOR 04 // SUBSTATION C",
      description: "Cut district power and hit the depository inside the dark window. Pick the tier, then tag in on its board." },
    me: { id: me.id, name: me.name, citizen: me.citizen, tier: me.tier, reputation: 640, nextTier: 1500 },
    difficulties: [
      { id: "standard", label: "STANDARD", blurb: "Reduced security. Grid stays half-lit.", payout: 12000, minutes: 25, min: 2, max: 4, tier: 1, locked: false, tagged: lobbies.standard!.length, cleared: 3 },
      { id: "hard", label: "HARD", blurb: "Full security roster. Shorter dark window.", payout: 22500, minutes: 30, min: 4, max: 6, tier: 2, locked: false, tagged: lobbies.hard!.length, requires: "STANDARD", cleared: 0 },
      { id: "critical", label: "CRITICAL", blurb: "Corporate response team on standby. No respawns.", payout: 40000, minutes: 45, min: 6, max: 8, tier: 3, locked: true, tagged: 0, requires: "HARD", cleared: 0 },
    ],
    boards: { standard: board("standard"), hard: board("hard"), critical: board("critical") },
    tagged: tagged ? { lobby: "lobby:" + tagged, difficulty: tagged, host: lobbies[tagged]![0]?.id === me.id } : undefined,
    nearby: [
      { id: 87, name: "Kei Mori", citizen: "087", tier: 1, inSquad: squad, mine: squad, invited: false },
      { id: 132, name: "Rosa Vasquez", citizen: "132", tier: 2, inSquad: squad, mine: squad, invited: false },
      { id: 401, name: "Nix Halloran", citizen: "401", tier: 1, inSquad: false, mine: false, invited: false },
    ],
  });
  // &luaEmpty=1: empty lists arrive as {} (what Lua's JSON encoder sends)
  const lua = <T,>(v: T): T => params.get("luaEmpty") === "1" ? JSON.parse(JSON.stringify(v, (_k, x) => Array.isArray(x) && x.length === 0 ? {} : x)) : v;
  const push = () => {
    fire(PAGE_EVENTS.mission, { session: "mission:1", state: lua(snapshot()) });
    const lobby = tagged ? lobbies[tagged]! : undefined;
    fire(PAGE_EVENTS.state, { party: lua(party), missionQueue: tagged && lobby ? { running: false, title: "Sector 04 Blackout", difficulty: tagged.toUpperCase(), difficultyId: tagged,
      count: lobby.length, min: spec[tagged as keyof typeof spec].min, max: spec[tagged as keyof typeof spec].max,
      state: countdownAt ? "countdown" : "open", countdownMs: countdownAt ? Math.max(0, countdownAt - Date.now()) : undefined, host: lobby[0]?.id === me.id } : false });
  };
  const add = (id: string, list: MissionLobbyMember[]) => { tagged = id; lobbies[id]!.push(...list); if (lobbies[id]!.length >= spec[id as keyof typeof spec].max) countdownAt = Date.now() + 15000; };
  if (params.get("tagged") === "1") add("standard", [me]);
  return {
    open() { fire(PAGE_EVENTS.state, { party: lua(party) }); fire(PAGE_EVENTS.dialog, lua(snapshot())); push(); },
    queueOnly() { if (!tagged) add("standard", [me]); push(); },
    // ?mission=1: a running mission with its squad frame (one operator down, one hurt)
    running() {
      fire(PAGE_EVENTS.state, { missionQueue: { running: true, instance: "mission:1", title: "Sector 04 Blackout", difficulty: "STANDARD", difficultyId: "standard",
        endsInMs: 21 * 60000 + 14000, members: 4, squad: [
          { id: 301, name: "J. Okonkwo", citizen: "301", host: true, health: 100, maxHealth: 100, armor: 60, state: "alive" },
          { id: 7, name: "Vi Asada", citizen: "007", host: false, health: 72, maxHealth: 100, armor: 35, state: "alive" },
          { id: 87, name: "Kei Mori", citizen: "087", host: false, health: 0, maxHealth: 100, armor: 0, state: "down" },
          { id: 132, name: "Rosa Vasquez", citizen: "132", host: false, health: 22, maxHealth: 100, armor: 10, state: "alive" }] } });
    },
    handle(action: UiAction): boolean {
      switch (action.type) {
        case "mission.tag": add(action.difficulty, [me]); break;
        case "mission.tagGroup": add(action.difficulty, (party.members ?? []).map(m => ({ id: m.id, name: m.name, citizen: String(m.id), tier: m.tier, host: false, squad: party.id }))); break;
        case "mission.untag": if (tagged) { lobbies[tagged] = lobbies[tagged]!.filter(m => m.id !== me.id && !m.squad); tagged = undefined; countdownAt = undefined; } break;
        case "mission.launch": countdownAt = Date.now() + 10000; break;
        case "mission.close": return true;
        case "party.invite": party.pending = [...(party.pending ?? []), { id: action.target, name: "Nix Halloran" }]; if (!party.id) { party.id = "squad:1"; party.leader = me.id; party.members = [{ id: me.id, name: me.name, leader: true, tier: 2 }]; } break;
        case "party.accept": party.invites = []; party.id = "squad:9"; party.leader = 55; party.members = [{ id: 55, name: "Dex DeShawn", leader: true, tier: 3 }, { id: me.id, name: me.name, leader: false, tier: 2 }]; break;
        case "party.decline": party.invites = []; break;
        case "party.leave": party.id = undefined; party.members = undefined; party.leader = undefined; party.pending = undefined; break;
        default: return false;
      }
      push();
      return true;
    },
  };
}
