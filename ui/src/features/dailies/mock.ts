import { PAGE_EVENTS, type DailiesState, type DailyCard, type PartyState, type TitleEntry, type TitlesState, type UiAction } from "@/bridge/protocol";

/* Browser fixture of Dailies and titles (Vite dev only), shaped as
   server/modules/dailies.lua D.view and titles.lua T.view send them, with the
   real contracts of server/config/dailies.lua. ?dialog=dailies opens the panel
   (&tab=titles on the titles). &dailies= picks the day: mixed (default: one to
   claim, one paid, a crew daily without a crewmate online, one left from yesterday),
   fresh, budget (today's budget nearly spent), allpaid, off, loading (no state).
   &titles= picks the titles: shown (default), hidden (a rank-1 title lost), none.
   &crew=1 adds a crew whose members show their titles (the crew frame). Claims,
   swaps and title picks are answered as the server would. */

const FIXERS: Record<string, string> = { okoro: "Mama Okoro", ledger: "Silas \"Ledger\" Varga", nix: "Nix Delacroix" };
const REWARD = { street: 250, action: 400, shift: 250, crew: 300, weekly: 3000 } as const;

function card(slot: DailyCard["slot"], id: string, fixer: string, title: string, brief: string, goal: string, target = 1, unit?: "m" | "s", social?: boolean): DailyCard {
  return { slot, id, fixer, fixerName: FIXERS[fixer]!, title, brief, goal, value: 0, target, unit, done: false, claimed: false, reward: REWARD[slot],
    social: social || slot === "crew" || undefined };
}
const CONTRACTS = {
  ride_along: card("street", "ride_along", "okoro", "Ride Along",
    "A million cars in this city and every one of them has one gonk in it. Share a ride. Driver, passenger, Job Center to the Crossing or as far. Talk about something.",
    "Ride 1.2 km in the same vehicle as another citizen.", 1200, "m", true),
  running_on_fumes: card("street", "running_on_fumes", "nix", "Running on Fumes",
    "real ones don't fill up til the light's blinking. bring her in under 10%. jerrycan doesn't count, that's cheating lol",
    "Refuel at a pump a car that was under 10 %, up to at least 50 %."),
  support_act: card("action", "support_act", "okoro", "Support Act",
    "Everybody wants the kill. Today you soften them up and let somebody else take the credit. Your crew, or the hired guns from the terminal. Humility, choom.",
    "Win a paid PvE arena match with more assists than kills."),
  full_truck: card("shift", "full_truck", "okoro", "Full Truck",
    "One bagful at a time is how you get a bad back, choom. Stack the trunk, go back for more, and sell it all in one go.",
    "Sell at least 11 goods in a single sale: more than one bag can carry."),
  album_cover: card("crew", "album_cover", "nix", "Album Cover",
    "crew pic at the crossing. everybody strike a pose at the same time, 10 seconds, nobody blinks",
    "At The Crossing, everyone in the crew there plays an animation within 6 m of each other for 10 s."),
  good_samaritan: card("weekly", "good_samaritan", "okoro", "Good Samaritan",
    "Three strangers this week. Not your crew. Somebody you don't know, bleeding on a street you don't live on. Mama covers the kits.",
    "Stabilize 3 different citizens outside your crew.", 3, undefined, true),
};

function day(kind: string): DailiesState | undefined {
  if (kind === "loading") return undefined;
  if (kind === "off") return { enabled: false, streak: 0, swapsLeft: 0, budget: { used: 0, max: 0 }, list: [], older: [] };
  const c = structuredClone(CONTRACTS);
  const base: DailiesState = { enabled: true, ready: true, day: 20760, resetInMs: 6 * 3600000 + 12 * 60000 + 40000, weekResetInMs: 3 * 86400000 + 4 * 3600000 + 12 * 60000,
    streak: 4, swapsLeft: 1, budget: { used: 250, max: 1200 }, list: [], older: [] };
  if (kind === "fresh") {
    c.ride_along.swappable = c.support_act.swappable = c.full_truck.swappable = true; c.album_cover.needsCrew = c.album_cover.crewLocked = true;
    return { ...base, streak: 0, budget: { used: 0, max: 1200 }, list: [c.ride_along, c.support_act, c.full_truck, c.album_cover, c.good_samaritan] };
  }
  if (kind === "allpaid") {
    for (const x of Object.values(c)) { x.done = x.claimed = true; x.value = x.target; }
    c.good_samaritan.done = c.good_samaritan.claimed = false; c.good_samaritan.value = 2;
    return { ...base, streak: 9, swapsLeft: 0, budget: { used: 1200, max: 1200 }, list: [c.ride_along, c.support_act, c.full_truck, c.album_cover, c.good_samaritan] };
  }
  c.ride_along.value = 640; c.ride_along.swappable = true;
  c.support_act.done = true; c.support_act.value = 1;
  c.full_truck.done = c.full_truck.claimed = true; c.full_truck.value = 1;
  c.album_cover.needsCrew = c.album_cover.crewLocked = true;
  c.good_samaritan.value = 1;
  if (kind === "budget") return { ...base, budget: { used: 1050, max: 1200 }, list: [c.ride_along, c.support_act, c.full_truck, c.album_cover, c.good_samaritan] };
  return { ...base, list: [c.ride_along, c.support_act, c.full_truck, c.album_cover, c.good_samaritan],
    older: [{ id: "street_performer", title: "Street Performer", reward: 250 }] };
}

const T = (id: string, label: string, rarity: TitleEntry["rarity"], group: string, how: string, extra: Partial<TitleEntry> = {}): TitleEntry =>
  ({ id, label, rarity, group, how, ...extra });
function titles(kind: string): TitlesState {
  const list: TitleEntry[] = [
    T("merc", "Merc", "common", "reputation", "Reach reputation tier II.", { earned: true }),
    T("operator", "Operator", "rare", "reputation", "Reach reputation tier III."),
    T("edgerunner", "Edgerunner", "epic", "reputation", "Reach reputation tier IV."),
    T("legend", "Legend", "legendary", "reputation", "Reach reputation tier V."),
    T("chimera_standard", "Chimera Breaker", "common", "raids", "Clear the Chimera raid on Standard.", { earned: true }),
    T("chimera_hard", "Core Cracker", "rare", "raids", "Clear the Chimera raid on Hard."),
    T("overclock_denied", "Overclock Denied", "rare", "feats", "Kill the Chimera before its core overclocks."),
    T("flawless", "Flawless", "legendary", "feats", "Clear Chimera Critical without one operator going down in the fight."),
    T("lions_share", "Lion's Share", "epic", "feats", "Be the top contributor of a world boss that goes down."),
    T("duelist", "Duelist", "rare", "pvp", "Win 10 ranked duels.", { value: 6, count: 10 }),
    T("getaway_driver", "Getaway Driver", "rare", "pvp", "Escape NCPD Escape 10 times as the runner.", { value: 10, count: 10, earned: true }),
    T("streak_7", "Seven Days Straight", "rare", "contracts", "Claim a daily 7 UTC days in a row."),
    T("lucky_seven", "Lucky Seven", "rare", "contracts", "Complete Ledger's Lucky Number 3 times."),
    T("champion", "Champion", "live", "hall", "Hold rank 1 of the PvP wins board.", { live: true }),
    T("eddie_baron", "Eddie Baron", "live", "hall", "Hold rank 1 of the richest board.", { live: true }),
    T("most_wanted", "Most Wanted", "rare", "dogtown", "Get 5 credited kills in a row in Dogtown: the streak that puts a bounty on you.", { value: 5, count: 5, earned: true }),
    T("barghest_problem", "Barghest's Problem", "epic", "dogtown", "Reach 50 credited kills in Dogtown.", { value: 31, count: 50 }),
    T("dogtown_king", "King of Dogtown · W45", "legendary", "dogtown", "Be last week's top credited killer in Dogtown. The crown lasts until the end of the week.",
      { earned: true, expiresInMs: 3 * 86400000 + 4 * 3600000 }),
  ];
  const groups = [{ id: "reputation", label: "Reputation" }, { id: "raids", label: "Raids" }, { id: "feats", label: "Feats" }, { id: "pvp", label: "PvP" },
    { id: "contracts", label: "Dailies" }, { id: "hall", label: "Hall of Fame" }, { id: "dogtown", label: "Dogtown" }];
  if (kind === "none") return { enabled: true, groups, list };
  if (kind === "hidden") return { enabled: true, chosen: "champion", groups, list };
  return { enabled: true, shown: "dogtown_king", chosen: "dogtown_king", groups, list };
}

const SWAPS: Record<string, DailyCard> = {
  street: card("street", "the_tour", "okoro", "The Tour",
    "There's a fresh face at the Crossing with eyes like a lost cat. Show them the city: the Crossing to the Afterlife, together, no ditching. Be nice, they'll remember.",
    "Travel 750 m within 15 m of a citizen in their first 2 hours in the city.", 750, "m", true),
  action: card("action", "leg_day", "nix", "Leg Day",
    "cars r for cowards. NCPD Escape ON FOOT. alleys, stairs, fences. get away and send me ur heart rate",
    "In NCPD Escape, pick On foot and get away (extraction or clock)."),
  shift: card("shift", "full_round", "okoro", "The Full Round",
    "A real round: both pickups, then the buyer. Not the same corner twice because it's closer. The city doesn't clean itself one block at a time.",
    "Collect at both collection sites, then sell, with no sale in between.", 3),
};

export function dailiesMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  let d = day(params.get("dailies") ?? "mixed");
  const t = titles(params.get("titles") ?? "shown");
  const result = (ok: boolean, text: string, action: string) => fire(PAGE_EVENTS.result, { ok, text, action });
  const push = () => fire(PAGE_EVENTS.state, { dailies: d, titles: t });
  const crew = (): PartyState => {
    const shown = t.list.find((e) => e.id === t.shown);
    return { you: 7, id: "party:1", leader: 7, maxSize: 4, invites: [], members: [
      { id: 7, name: "Yuki Tanaka", leader: true, tier: 3, you: true, title: shown?.label, titleRarity: shown?.rarity },
      { id: 87, name: "Kei Mori", leader: false, tier: 2, title: "Getaway Driver", titleRarity: "rare" },
      { id: 132, name: "Rosa Vasquez", leader: false, tier: 4, title: "Legend", titleRarity: "legendary", busy: "activity" },
      { id: 140, name: "Jax Romero", leader: false, tier: 1 },
    ] };
  };
  return {
    boot() {
      if (d || params.get("dialog") === "dailies") push();
      if (params.get("crew") === "1") fire(PAGE_EVENTS.state, { party: crew() });
      if (params.get("dialog") === "dailies") fire(PAGE_EVENTS.dialog, { kind: "dailies", tab: params.get("tab") === "titles" ? "titles" : "today" });
    },
    /** true when the action was one of the panel's */
    handle(action: UiAction): boolean {
      if (action.type === "dailies.open") {
        window.setTimeout(() => { push(); fire(PAGE_EVENTS.dialog, { kind: "dailies", tab: action.tab ?? "today" }); }, 120);
        return true;
      }
      if (action.type === "dailies.refresh") { window.setTimeout(push, 60); return true; }
      if (action.type === "dailies.claim") {
        window.setTimeout(() => {
          if (!d) return result(false, "Load your character first.", action.type);
          const c = d.list.find((x) => x.id === action.id && x.done && !x.claimed);
          const old = d.older.find((x) => x.id === action.id);
          if (!c && !old) return result(false, "This daily is not finished yet, or it was already paid.", action.type);
          const reward = c ? c.reward : old!.reward;
          if (c && c.slot !== "weekly" && d.budget.used + reward > d.budget.max) return result(false, "Dailies budget reached (€$ 1,200 per day). It resets at 00:00 UTC.", action.type);
          if (c) { c.claimed = true; if (c.slot !== "weekly") d.budget = { ...d.budget, used: d.budget.used + reward }; }
          else d.older = d.older.filter((x) => x.id !== action.id);
          d = { ...d, list: [...d.list], streak: c && c.slot !== "weekly" && d.streak === 4 ? 5 : d.streak };
          fire(PAGE_EVENTS.notice, { kind: "money", title: `+€$ ${reward.toLocaleString("en-US")}`, body: `${c?.title ?? old!.title} · paid by ${c?.fixerName ?? "Nix Delacroix"}.`, source: "LIGHT RP", durationMs: 7000 });
          push(); result(true, `+€$ ${reward.toLocaleString("en-US")}`, action.type);
        }, 260);
        return true;
      }
      if (action.type === "dailies.swap") {
        window.setTimeout(() => {
          const next = SWAPS[action.slot];
          if (!d || !next || d.swapsLeft <= 0) return result(false, "You already used today's free swap.", action.type);
          d = { ...d, swapsLeft: d.swapsLeft - 1, list: d.list.map((x) => (x.slot === action.slot ? { ...next } : { ...x, swappable: undefined })) };
          push(); result(true, `New daily: ${next.title}.`, action.type);
        }, 220);
        return true;
      }
      if (action.type === "titles.select") {
        window.setTimeout(() => {
          if (action.id === "none") { t.chosen = undefined; t.shown = undefined; push(); return result(true, "Title hidden.", action.type); }
          const e = t.list.find((x) => x.id === action.id);
          if (!e?.earned) return result(false, "You have not earned this title.", action.type);
          t.chosen = t.shown = e.id;
          push(); if (params.get("crew") === "1") fire(PAGE_EVENTS.state, { party: crew() });
          result(true, `Title shown: ${e.label}.`, action.type);
        }, 180);
        return true;
      }
      return false;
    },
  };
}
