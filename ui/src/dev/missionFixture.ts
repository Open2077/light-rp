/* ?dialog=mission: a mission point with live boards, played in the browser.
   &tagged=1 starts tagged on STANDARD. Crews (also without the dialog, for the HUD
   frame): &squad=1 or &crew=N (2-8) puts you in a crew, &member=1 makes someone
   else its leader, &matchmaking=1 opens it to matchmaking, &invite=1 adds a pending
   crew invite (the HUD prompt). Tagging, the host's launch (countdown), the
   matchmaking toggle and crew actions all answer like the server would. */
import { PAGE_EVENTS, type ActivitiesState, type MissionBoard, type MissionDialogPayload, type MissionLobbyMember, type PartyState, type UiAction } from "@/bridge/protocol";

type Fire = (name: string, payload: unknown) => void;

export function missionMock(params: URLSearchParams, fire: Fire) {
  const me: MissionLobbyMember = { id: 7, name: "Vi Asada", citizen: "007", tier: 2, host: false };
  const size = params.get("squad") === "1" ? 3 : Math.max(0, Math.min(8, Number(params.get("crew") ?? 0)));
  const squad = size > 1;
  // the crew frame's variety: a member down, one in an activity, one far, one on a board, one dead
  const roster: PartyState["members"] = [
    { id: 7, name: "Vi Asada", leader: true, tier: 2, you: true, state: "alive" },
    { id: 87, name: "Kei Mori", leader: false, tier: 1, state: "down" },
    { id: 132, name: "Rosa Vasquez", leader: false, tier: 2, state: "alive", busy: "activity", busyLabel: "Arena FFA" },
    { id: 401, name: "Nix Halloran", leader: false, tier: 1, state: "alive", far: true },
    { id: 55, name: "Dex DeShawn", leader: false, tier: 3, state: "alive", busy: "lobby", busyLabel: "Sector 04 Blackout" },
    { id: 61, name: "Mama Welles", leader: false, tier: 2, state: "alive" },
    { id: 62, name: "Jackie Welles-Okonkwo", leader: false, tier: 3, state: "dead" },
    { id: 63, name: "T-Bug", leader: false, tier: 1, state: "alive", busy: "mission", busyLabel: "Chimera" },
  ];
  const members = roster.slice(0, size).map((m) => ({ ...m }));
  if (params.get("member") === "1" && members.length > 1) { members[0]!.leader = false; members[1]!.leader = true; }
  const party: PartyState = squad
    ? { you: 7, id: "crew:1", leader: members.find((m) => m.leader)!.id, maxSize: 8, inviteSeconds: 60, invites: [], members, matchmaking: params.get("matchmaking") === "1", keys: { accept: "Y", decline: "N" } }
    : { you: 7, maxSize: 8, inviteSeconds: 60, invites: [], matchmaking: params.get("matchmaking") === "1", keys: { accept: "Y", decline: "N" } };
  if (params.get("invite") === "1") party.invites = [{ party: "crew:9", from: 55, fromName: "Dex DeShawn", expiresInMs: 52000 }];
  const leads = () => !party.id || (party.members?.length ?? 0) < 2 || party.leader === me.id;
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
      { id: "standard", label: "STANDARD", blurb: "Reduced security. Grid stays half-lit.", payout: 12000, minutes: 25, min: 2, max: 4, tier: 1, locked: false, tagged: lobbies.standard!.length, cleared: 3, openLobbies: tagged === "standard" ? 0 : 1 },
      { id: "hard", label: "HARD", blurb: "Full security roster. Shorter dark window.", payout: 22500, minutes: 30, min: 4, max: 6, tier: 2, locked: false, tagged: lobbies.hard!.length, requires: "STANDARD", cleared: 0 },
      { id: "critical", label: "CRITICAL", blurb: "Corporate response team on standby. No respawns.", payout: 40000, minutes: 45, min: 6, max: 8, tier: 3, locked: true, tagged: 0, requires: "HARD", cleared: 0 },
    ],
    boards: { standard: board("standard"), hard: board("hard"), critical: board("critical") },
    tagged: tagged ? { lobby: "lobby:" + tagged, difficulty: tagged, host: lobbies[tagged]![0]?.id === me.id } : undefined,
    entry: { crew: squad ? party.id : undefined, size: party.id ? party.members?.length ?? 1 : 1, leader: party.members?.find((m) => m.leader)?.name,
      leads: leads(), matchmaking: !!party.matchmaking, open: !!tagged && !!party.matchmaking },
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
      state: countdownAt ? "countdown" : "open", countdownMs: countdownAt ? Math.max(0, countdownAt - Date.now()) : undefined, host: lobby[0]?.id === me.id, open: !!party.matchmaking } : false });
  };
  const add = (id: string, list: MissionLobbyMember[]) => { tagged = id; lobbies[id]!.push(...list); if (lobbies[id]!.length >= spec[id as keyof typeof spec].max) countdownAt = Date.now() + 15000; };
  if (params.get("tagged") === "1") add("standard", [me]);
  return {
    open() { fire(PAGE_EVENTS.state, { party: lua(party) }); fire(PAGE_EVENTS.dialog, lua(snapshot())); push(); },
    // the crew on the HUD without any dialog (&crew=N, &invite=1)
    boot() { if (squad || party.invites.length) fire(PAGE_EVENTS.state, { party: lua(party) }); },
    queueOnly() { if (!tagged) add("standard", [me]); push(); },
    // ?mission=1: a running mission with its squad frame (one operator down, one hurt)
    running() {
      fire(PAGE_EVENTS.state, { missionQueue: { running: true, instance: "mission:1", title: "Sector 04 Blackout", difficulty: "STANDARD", difficultyId: "standard",
        endsInMs: 21 * 60000 + 14000, members: 4, squad: [
          { id: 301, name: "J. Okonkwo", citizen: "301", host: true, health: 100, maxHealth: 100, armor: 60, state: "alive" },
          { id: 7, name: "Vi Asada", citizen: "007", host: false, health: 72, maxHealth: 100, armor: 35, state: "alive" },
          { id: 87, name: "Kei Mori", citizen: "087", host: false, health: 0, maxHealth: 100, armor: 0, state: "down" },
          { id: 132, name: "Rosa Vasquez", citizen: "132", host: false, health: 22, maxHealth: 100, armor: 10, state: "alive" }],
        // &objective=eliminate|waves|oob: an authored mission's tracker (mission_engine view)
        objective: objectiveFixture(params.get("objective")) } });
    },
    handle(action: UiAction): boolean {
      switch (action.type) {
        case "mission.tag": case "mission.tagGroup":
          if (!leads()) break;
          if (squad) add(action.difficulty, (party.members ?? []).map(m => ({ id: m.id, name: m.name, citizen: String(m.id), tier: m.tier, host: false, squad: party.id })));
          else add(action.difficulty, [me]);
          break;
        case "mission.matchmaking": case "party.matchmaking": if (leads()) party.matchmaking = action.on; break;
        case "mission.untag": if (tagged) { lobbies[tagged] = lobbies[tagged]!.filter(m => m.id !== me.id && !m.squad); tagged = undefined; countdownAt = undefined; } break;
        case "mission.launch": countdownAt = Date.now() + 10000; break;
        case "mission.close": return true;
        case "party.invite": party.pending = [...(party.pending ?? []), { id: action.target, name: "Nix Halloran" }]; if (!party.id) { party.id = "crew:1"; party.leader = me.id; party.members = [{ id: me.id, name: me.name, leader: true, tier: 2, you: true, state: "alive" }]; } break;
        case "party.accept": party.invites = []; party.id = "crew:9"; party.leader = 55; party.members = [{ id: 55, name: "Dex DeShawn", leader: true, tier: 3, state: "alive" }, { id: me.id, name: me.name, leader: false, tier: 2, you: true, state: "alive" }]; break;
        case "party.kick": party.members = party.members?.filter((m) => m.id !== action.target); break;
        case "party.promote": party.leader = action.target; party.members = party.members?.map((m) => ({ ...m, leader: m.id === action.target })); break;
        case "party.decline": party.invites = []; break;
        case "party.leave": party.id = undefined; party.members = undefined; party.leader = undefined; party.pending = undefined; break;
        default: return false;
      }
      push();
      return true;
    },
  };
}

function objectiveFixture(kind: string | null) {
  if (!kind) return undefined;
  if (kind === "waves") return { kind: "waves", phase: "intermission", enemiesLeft: 0, kills: 14, lives: 2, wave: 2, waves: 5, nextWaveInMs: 12000 };
  // &objective=briefing|down: the kit choice (like the raid's ready check), in the briefing and while down
  const kits = [
    { id: "assault", label: "ASSAULT", blurb: "Militech Ajax rifle and a Lexington sidearm. Reliable at every range." },
    { id: "breacher", label: "BREACHER", blurb: "Carnage shotgun and an Unity. Get close, hit its weak spots hard." },
    { id: "marksman", label: "MARKSMAN", blurb: "Grad precision rifle and a Nue. Pick the parts off from cover." },
    { id: "gunner", label: "GUNNER", blurb: "Defender light machine gun and a Lexington. Suppress the reinforcements." },
    { id: "tech", label: "TECH", blurb: "Achilles tech rifle and a Copperhead. Charged shots through its plating." }];
  if (kind === "briefing") return { kind: "eliminate", phase: "staging", enemiesLeft: 0, kills: 0, lives: 3, startsInMs: 24000,
    loadouts: kits, loadout: "assault", canChoose: true, ready: false, readyCount: 1, squadSize: 4 };
  if (kind === "down") return { kind: "eliminate", phase: "fight", enemiesLeft: 6, kills: 5, lives: 2, respawnInMs: 8000,
    loadouts: kits, loadout: "breacher", canChoose: true };
  return { kind: "eliminate", phase: "fight", enemiesLeft: 6, kills: 5, lives: 3, outOfBoundsMs: kind === "oob" ? 8000 : undefined,
    checkpoints: [{ label: "Loading bay", reached: true, required: true }, { label: "Office stairs", reached: false, required: true }, { label: "Roof", reached: false, required: false }] };
}

/* ?dialog=activities (&tab=crew): the F1 Activities panel with two activities, the
   players around and, with &member=1, a crew led by someone else. Crews come from
   missionMock (&crew=N, &invite=1). */
export function activitiesFixture(params: URLSearchParams): ActivitiesState {
  const leader = params.get("member") === "1" ? "Kei Mori" : undefined;
  const inCrew = params.get("squad") === "1" || Number(params.get("crew") ?? 0) > 1;
  return {
    enabled: true, hub: { name: "The Crossing" }, mission: false, eligible: true, current: false, queued: false,
    reputation: { today: 40, dailyCap: 300, maxPerResult: 60 }, contracts: [], crewLeader: leader,
    list: [
      { id: "arena", label: "Arena", kind: "pvp", description: "Free-for-all in the Crossing pit. First to 20 frags.", minPlayers: 2, maxPlayers: 12,
        phase: "lobby", players: 0, queued: 3, joinable: true, detail: "3 waiting", byTime: false,
        modes: [{ id: "ffa", label: "FREE FOR ALL" }, { id: "teams", label: "TEAMS" }], modeKey: "mode", top: [{ rank: 1, name: "Dex DeShawn", wins: 14, played: 30 }] },
      { id: "turf", label: "Turf War", kind: "pvp", description: "Two crews, three points, ten minutes.", minPlayers: 4, maxPlayers: 16,
        phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: false, modes: [], modeKey: "mode", top: [] },
    ],
    nearby: [
      { id: 87, name: "Kei Mori", distance: 4, inSquad: inCrew, mine: inCrew, invited: false },
      { id: 301, name: "Jackie Okonkwo", distance: 9, inSquad: false, mine: false, invited: false },
      { id: 402, name: "Panam Shaw", distance: 12, inSquad: true, mine: false, invited: false },
    ],
  };
}
