/* ?dialog=mission: a mission point with live boards, played in the browser.
   &tagged=1 starts tagged on STANDARD. Crews (also without the dialog, for the HUD
   frame): &squad=1 or &crew=N (2-8) puts you in a crew, &member=1 makes someone
   else its leader, &matchmaking=1 opens it to matchmaking, &invite=1 adds a pending
   crew invite (the HUD prompt). Tagging, the host's launch (countdown), the
   matchmaking toggle and crew actions all answer like the server would. */
import { PAGE_EVENTS, type ActivitiesState, type ActivityFriendly, type ActivityFriendlyPlayer, type MissionBoard, type MissionDialogPayload, type MissionLobbyMember, type PartyState, type UiAction } from "@/bridge/protocol";

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
    me: { id: me.id, name: me.name, citizen: me.citizen, tier: me.tier, reputation: 640, nextTier: 1500, tierName: "Merc" },
    difficulties: [
      { id: "standard", label: "STANDARD", blurb: "Reduced security. Grid stays half-lit.", payout: 12000, minutes: 25, min: 2, max: 4, tier: 1, locked: false, tagged: lobbies.standard!.length, cleared: 3, openLobbies: tagged === "standard" ? 0 : 1, reputation: 100, earns: 100 },
      { id: "hard", label: "HARD", blurb: "Full security roster. Shorter dark window.", payout: 22500, minutes: 30, min: 4, max: 6, tier: 2, tierName: "Merc", locked: false, tagged: lobbies.hard!.length, requires: "STANDARD", cleared: 0, reputation: 220, earns: 220 },
      { id: "critical", label: "CRITICAL", blurb: "Corporate response team on standby. No respawns.", payout: 40000, minutes: 45, min: 6, max: 8, tier: 3, tierName: "Operator", tierLocked: true, locked: true, tagged: 0, requires: "HARD", cleared: 0, reputation: 450, earns: 220, earnsAs: "HARD" },
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

/* ?dialog=activities (&tab=crew): the F1 Activities panel with the arena, races and
   a turf war, the players around and, with &member=1, a crew led by someone else.
   Crews come from missionMock (&crew=N, &invite=1). The lobby (&lobby=): search (a
   ranked duel search 40 s in, near your rank), widened (95 s: all ranks), offer (the
   bot fill offer open), match (a match on its way), friendly (the crew's friendly
   set-up; with &member=1 seen by a member). Joining, leaving, the bot fill and the
   friendly set-up answer like the server (activitiesMock). */
export function activitiesFixture(params: URLSearchParams): ActivitiesState {
  const leader = params.get("member") === "1" ? "Kei Mori" : undefined;
  const inCrew = params.get("squad") === "1" || Number(params.get("crew") ?? 0) > 1;
  return {
    enabled: true, hub: { name: "The Crossing" }, mission: false, eligible: true, current: false, queued: false,
    reputation: { today: 40, dailyCap: 300, maxPerResult: 60, tier: 2, tierName: "Merc" }, contracts: [], crewLeader: leader,
    lobby: { fillAfterMs: 120000 }, friendly: false,
    list: [
      { id: "arena.duel", label: "Duel", kind: "pvp", description: "One on one, best of three rounds. Cyberware on.", minPlayers: 2, maxPlayers: 2,
        phase: "idle", players: 0, queued: 1, joinable: true, detail: "", byTime: false, modes: [], modeKey: "mode",
        top: [{ rank: 1, name: "Dex DeShawn", wins: 14, played: 30 }], lobby: { bots: true, friendly: true, queue: true, brackets: true } },
      { id: "arena.teams", label: "Team Arena", kind: "pvp", description: "Two teams, last squad standing takes the round.", minPlayers: 4, maxPlayers: 6,
        phase: "lobby", players: 0, queued: 3, joinable: true, detail: "3 waiting", byTime: false,
        modes: [{ id: "2v2", label: "2v2" }, { id: "3v3", label: "3v3", botFill: false }], modeKey: "mode", top: [],
        lobby: { bots: true, friendly: true, queue: true, brackets: true } },
      { id: "arena.ffa", label: "Combat Zone", kind: "pvp", description: "Free-for-all drop-in. First to 20 frags.", minPlayers: 1, maxPlayers: 8,
        phase: "running", players: 3, queued: 0, joinable: true, detail: "", byTime: false, modes: [], modeKey: "mode", top: [],
        lobby: { bots: true, friendly: true } },
      { id: "arena.pve", label: "Combat Zone · PvE", kind: "pvp", pve: true, description: "Your crew against gangers, wave after wave.", minPlayers: 1, maxPlayers: 6,
        phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: false, modes: [], modeKey: "mode", top: [],
        difficulties: [{ id: "standard", label: "Standard", minTier: 1, locked: false, reputation: 30 }, { id: "hard", label: "Hard", minTier: 2, locked: false, reputation: 60 },
          { id: "critical", label: "Critical", minTier: 3, tierName: "Fixer", locked: true, reputation: 100 }], lobby: { allies: true, seats: 6 } },
      { id: "race.grid", label: "Street Race", kind: "race", description: "Grid start through Watson. Humans only when ranked.", minPlayers: 2, maxPlayers: 8,
        phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: true, modes: [{ id: "loop", label: "Watson loop" }, { id: "dash", label: "Badlands dash" }],
        modeKey: "course", top: [{ rank: 1, name: "Panam Shaw", wins: 3, played: 9, bestTimeMs: 128450 }], lobby: { bots: true, friendly: true, queue: true } },
      { id: "turf.war", label: "Turf War", kind: "pvp", description: "Two crews, three points, ten minutes.", minPlayers: 4, maxPlayers: 16,
        phase: "idle", players: 0, queued: 0, joinable: true, detail: "", byTime: false, modes: [], modeKey: "mode", top: [], lobby: { bots: true, friendly: true } },
    ],
    nearby: [
      { id: 87, name: "Kei Mori", distance: 4, inSquad: inCrew, mine: inCrew, invited: false },
      { id: 301, name: "Jackie Okonkwo", distance: 9, inSquad: false, mine: false, invited: false },
      { id: 402, name: "Panam Shaw", distance: 12, inSquad: true, mine: false, invited: false },
    ],
  };
}

const CREW: ActivityFriendlyPlayer[] = [
  { id: 7, name: "Vi Asada", tier: 2 }, { id: 87, name: "Kei Mori", tier: 1 }, { id: 132, name: "Rosa Vasquez", tier: 2 },
  { id: 401, name: "Nix Halloran", tier: 1 }, { id: 55, name: "Dex DeShawn", tier: 3 }, { id: 61, name: "Mama Welles", tier: 2 },
];

export function activitiesMock(params: URLSearchParams, fire: Fire) {
  const state = activitiesFixture(params);
  const size = params.get("squad") === "1" ? 3 : Math.max(0, Math.min(6, Number(params.get("crew") ?? 0)));
  const crew = CREW.slice(0, Math.max(size, params.get("lobby") === "friendly" ? 3 : 0));
  const member = params.get("member") === "1";
  const lua = <T,>(v: T): T => params.get("luaEmpty") === "1" ? JSON.parse(JSON.stringify(v, (_k, x) => Array.isArray(x) && x.length === 0 ? {} : x)) : v;
  const push = () => fire(PAGE_EVENTS.state, { activities: lua(structuredClone(state)) });
  const answer = (ok: boolean, text: string | undefined, action: string) => { if (text) setTimeout(() => fire(PAGE_EVENTS.result, { ok, text, action }), 150); };
  const label = (id: string) => state.list.find((a) => a.id === id)?.label ?? id;
  // a ranked search the "server" holds: its count and scope follow the clock
  let search: { id: string; mode?: string; at: number } | undefined;
  const refreshSearch = () => {
    if (!search || !state.queued) return;
    const waited = Date.now() - search.at;
    state.queued = { ...state.queued, sinceMs: waited, fillInMs: Math.max(0, 120000 - waited),
      search: { found: 1, needed: search.id === "arena.teams" ? (search.mode === "3v3" ? 6 : 4) : 2, scope: waited >= 100000 ? "all" : "near",
        widenInMs: waited < 60000 ? 60000 - waited : waited < 100000 ? 100000 - waited : undefined, bracket: 2 } };
  };
  const startSearch = (id: string, mode: string | undefined, waitedMs: number) => {
    search = { id, mode, at: Date.now() - waitedMs };
    state.queued = { id, label: label(id), sinceMs: waitedMs, ranked: true, mode, lead: !member };
    refreshSearch();
  };
  const matchOnItsWay = (id: string, ranked: boolean, friendly?: boolean) => {
    search = undefined;
    state.queued = { id, label: label(id), sinceMs: 0, ranked, match: true, friendly, lead: !member };
    // the provider takes them in a moment later: the panel closes on the way in
    setTimeout(() => { state.queued = false; state.current = { id, label: label(id), sinceMs: 0, leaving: false, returning: false }; push(); }, 4000);
  };
  // the friendly set-up, balanced by street cred (snake order)
  const balance = (mode: string | undefined): ActivityFriendly => {
    const sorted = [...crew].sort((x, y) => y.tier - x.tier);
    const size = mode === "3v3" ? 3 : 2;
    const teams: ActivityFriendlyPlayer[][] = [[], []];
    const bench: ActivityFriendlyPlayer[] = [];
    sorted.forEach((p, k) => {
      const want = Math.floor(k / 2) % 2 === 0 ? k % 2 : 1 - (k % 2);
      const pick = teams[want]!.length < size ? want : teams[1 - want]!.length < size ? 1 - want : -1;
      if (pick < 0) bench.push(p); else teams[pick]!.push(p);
    });
    return { id: "arena.teams", label: "Team Arena", mode: mode ?? "2v2", bots: false, canBots: mode !== "3v3", shape: "teams", size,
      leader: member ? "Kei Mori" : "Vi Asada", mine: !member, bench, teams, teamBots: [0, 0] };
  };
  const recheck = (f: ActivityFriendly) => {
    const teams = f.teams ?? [];
    f.teamBots = teams.map((t) => (f.bots ? Math.max(0, f.size - t.length) : 0));
    const short = teams.findIndex((t) => t.length < f.size);
    f.issue = !f.bots && short >= 0 ? `Team ${String.fromCharCode(65 + short)} has ${teams[short]!.length} of ${f.size} players: move one${f.canBots ? ", or turn bots on" : ""}.` : undefined;
    return f;
  };
  const lobby = params.get("lobby");
  if (lobby === "search") startSearch("arena.duel", undefined, 40000);
  if (lobby === "widened") startSearch("arena.duel", undefined, 95000);
  if (lobby === "offer") startSearch("arena.duel", undefined, 121000);
  if (lobby === "match") matchOnItsWay("arena.teams", true);
  if (lobby === "friendly") state.friendly = recheck(balance("2v2"));
  return {
    boot() {
      push();
      fire(PAGE_EVENTS.dialog, { kind: "activities", tab: params.get("tab") ?? "activities" });
      window.setInterval(() => { if (search) { refreshSearch(); push(); } }, 5000);
    },
    handle(action: UiAction): boolean {
      if (action.type !== "activities.control" && action.type !== "activities.lobby") return false;
      const f = state.friendly || undefined;
      let text: string | undefined, ok = true;
      if (action.type === "activities.control") {
        if (action.operation === "join") {
          const a = state.list.find((x) => x.id === action.id);
          const mode = action.options?.[a?.modeKey ?? "mode"];
          const bots = action.options?.bots === "true";
          if (!a) { ok = false; text = "That activity is not available."; }
          else if (bots && !a.pve) { matchOnItsWay(a.id, false); text = `Starting ${a.label} with bots · unranked.`; }
          else if (a.lobby?.queue && !a.pve) { startSearch(a.id, mode, 0); text = `Searching for a ranked ${a.label}${mode ? ` ${mode}` : ""} match.`; }
          else {
            search = undefined;
            const allies = bots && a.pve ? Math.max(0, (a.lobby?.seats ?? a.maxPlayers) - Math.max(1, crew.length)) : undefined;
            state.queued = { id: a.id, label: a.label, sinceMs: 0, ranked: true, lead: true, allies, difficulty: action.options?.difficulty,
              fillInMs: a.lobby?.bots && !a.pve ? 120000 : undefined };
            text = `Request sent to ${a.label}.${allies ? ` ${allies} allied bots fill the empty slots.` : ""}`;
          }
        } else if (action.operation === "leave") {
          const q = state.queued;
          search = undefined; state.queued = false; state.current = false;
          text = q ? `You left the ${q.match ? "match" : "search"} for ${q.label}.` : "You are not in an activity.";
        } else return action.operation !== "gps" ? (push(), true) : false;
      } else {
        switch (action.operation) {
          case "fill":
            if (state.queued) { matchOnItsWay(state.queued.id, false); text = `Bots fill the empty places: ${state.queued.label} starts, unranked.`; }
            break;
          case "friendly": state.friendly = recheck({ ...balance(action.mode), bots: !!action.bots && action.mode !== "3v3" }); text = "Friendly Team Arena: set the teams, then start. Unranked."; break;
          case "balance": if (f) { state.friendly = recheck({ ...balance(f.mode), bots: f.bots }); text = "Teams balanced by street cred."; } break;
          case "bots": if (f) { if (action.on && !f.canBots) { ok = false; text = "Team Arena cannot be played with bots."; } else { f.bots = action.on; recheck(f); text = f.bots ? "Bots take the empty places." : "No bots: every place needs a player."; } } break;
          case "cancel": state.friendly = false; text = "Friendly cancelled."; break;
          case "start":
            if (f?.issue) { ok = false; text = f.issue; }
            else if (f) { state.friendly = false; matchOnItsWay("arena.teams", false, true); text = "Friendly Team Arena starting · unranked."; }
            break;
          case "move":
            if (f?.teams) {
              const cols = [...f.teams, f.bench];
              const from = cols.findIndex((c) => c.some((p) => p.id === action.target));
              if (from >= 0) {
                const to = action.team === undefined ? (from + 1) % cols.length : action.team === 0 ? cols.length - 1 : action.team - 1;
                const source = cols[from]!, dest = cols[to]!;
                const at = source.findIndex((p) => p.id === action.target);
                const [p] = source.splice(at, 1);
                if (to < f.teams.length && dest.length >= f.size) source.splice(at, 0, dest.pop()!);
                dest.push(p!);
                recheck(f);
              }
            }
            break;
        }
      }
      answer(ok, text, action.type);
      push();
      return true;
    },
  };
}
