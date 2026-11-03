import { useEffect, useMemo, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, requestClose, sendAction } from "@/bridge/open77";
import { matchesToggleKey } from "@/features/inventory/model";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { RageMenu, type RageMenuItem } from "@/design/components";
import { formatMoney, ledger, transactionLabel } from "@/bridge/money";
import type { ActivitiesState, CharacterState, GangState, JobRunState, JobState, MoneyState, PartyState } from "@/bridge/protocol";
import { dogtownMenu } from "@/features/dogtown/model";
import { menuMeta, shownTitle } from "@/features/dailies/model";
import "./menu.css";

/* The player menu (F1): a RageUI-style list menu, keyboard only, top-left. The
   tree is built from the server state on every render, so a row is never stale.
   Submenus are entries of the tree keyed by `item.target`; the navigation stack
   holds one { key, index } per level. */

interface MenuNode { title: string; subtitle?: string; tag: string; items: RageMenuItem[] }

const ROOT_INDEX = 1; // first pickable row under the CHARACTER caption

function formatDuration(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}H${String(minutes % 60).padStart(2, "0")}`;
}

/* F1 → My job: how the job is worked, from anywhere. A work-order job (job.run)
   starts, follows and abandons its run here; free item work (job.work) sets the
   GPS of each stage; every job with a guide opens it; Resign leaves the job
   (it ends a run in progress, without pay). */
function jobNodes(job: JobState, run: JobRunState | undefined, money: MoneyState): Record<string, MenuNode> {
  const fmt = (n: number) => formatMoney(n, money.currency);
  const items: RageMenuItem[] = [];
  const guide = Array.isArray(job.guide) ? job.guide.length : 0;
  if (job.name === "unemployed") {
    items.push({ id: "job-find", type: "item", text: "Find a job", icon: "briefcase", meta: "JOB CENTER",
      description: "Job Centers hire on the spot, no experience needed: follow the briefcase on the map and press E at the clerk. Sanitation, Scrapper and Courier take anyone, and each job comes with its own guide." });
  } else {
    if (guide > 0) items.push({ id: "job-guide", type: "item", text: "Job guide", icon: "book-open", meta: `${guide} PAGES`,
      description: `How ${job.label} works, step by step and with pictures: where to go, what to press, how you are paid.` });
    const route = job.run;
    if (route) {
      items.push({ separator: true }, { label: "WORK ORDERS" });
      if (run?.active) {
        items.push(
          { id: "run-status", type: "item", text: run.objective?.label ?? run.label ?? "Current run", icon: run.icon ?? "route",
            meta: `STOP ${run.index ?? 1}/${run.total ?? 1}`,
            description: [run.hint, run.orders ? `${run.carried ?? 0} of ${run.orders} orders carried · ${run.distanceKm ?? 0} km route.` : undefined,
              run.reward ? `${fmt(run.reward)} when the run is complete.` : undefined].filter(Boolean).join(" ") },
          { id: "run-gps", type: "item", text: "GPS to my next stop", icon: "navigation",
            description: "Sets your GPS on the yellow marker of your next stop again, if you lost the route." },
          { id: "run-cancel", type: "submenu", target: "runcancel", text: "Abandon this run", icon: "x", danger: true, disabled: run.busy,
            description: `Ends the run now. No pay is issued${run.orders ? " and the undelivered orders leave your bag" : ""}. Your job stays the same: you can start another one right after.` });
      } else {
        const pay = route.variable ? `FROM ${fmt(route.reward)}` : fmt(route.reward);
        const what = route.orders
          ? `${route.orders.min} to ${route.orders.max} orders drawn at random: you pick each one up, then deliver each one to its address. The pay follows the length of the route (from ${fmt(route.reward)}), into your bank at the last delivery.`
          : `${route.stops} tasks on a set route, ${fmt(route.reward)} into your bank when every task is done.`;
        items.push(route.remote
          ? { id: "run-start", type: "item", text: "Start a run", icon: "route", meta: pay,
              description: `Dispatch sends you a route right now, wherever you are. ${what} Then follow the GPS and the work order card on the right.` }
          : { id: "run-start", type: "item", text: "Start a run", icon: "route", meta: "AT A DESK",
              description: `This job's work orders are handed out at a Job Center desk: follow the briefcase on the map, press E at the clerk, then Start a run. ${what}` });
      }
    }
    const work = job.work;
    if (work) {
      items.push({ separator: true }, { label: "FREE WORK" },
        { id: "work-collect", type: "item", text: "Collection point GPS", icon: "map-pin", meta: work.raw.toUpperCase(),
          description: `Sets your GPS on the nearest collection point. Press E there: ${work.raw} goes into your bag, again and again until it is full. A vehicle trunk carries more.` },
        { id: "work-process", type: "item", text: "Processing GPS", icon: "hammer", meta: work.product.toUpperCase(),
          description: `Sets your GPS on the processing site. Press E there: every ${work.inputCount} ${work.raw} becomes ${work.outputCount} ${work.product}.` },
        { id: "work-sell", type: "item", text: "Buyer GPS", icon: "banknote", meta: `${fmt(work.price)} / UNIT`,
          description: `Sets your GPS on the buyer. Press E there: every ${work.product} in your bag is sold at ${fmt(work.price)}, paid into your bank.` });
    }
    items.push({ separator: true },
      { id: "job-pay", type: "item", text: "Paycheck", icon: "landmark", meta: job.salary > 0 ? `${fmt(job.salary)} / ${job.paycheckMinutes ?? 30} MIN` : "—",
        description: job.salary > 0 ? `${job.gradeLabel}: ${fmt(job.salary)} into your bank every ${job.paycheckMinutes ?? 30} minutes while you are in town, on top of what you earn working.` : "This grade has no salary." },
      { id: "job-quit", type: "submenu", target: "jobquit", text: "Resign", icon: "x", danger: true, disabled: run?.busy,
        description: `Leave ${job.label} and become unemployed${run?.active ? ". Your run in progress ends without pay" : ""}. A Job Center hires you again any time.` });
  }
  return {
    job: { title: "MY JOB", subtitle: job.name === "unemployed" ? "NO JOB YET" : `${job.label.toUpperCase()} // ${job.gradeLabel.toUpperCase()}`, tag: "JOB", items },
    runcancel: { title: "ABANDON RUN?", subtitle: "NO PAY WILL BE ISSUED", tag: "ABANDON", items: [
      { id: "run-cancel-confirm", type: "item", text: "Yes, abandon this run", icon: "x", danger: true,
        description: `The run ends without pay${run?.orders ? "; the orders still in your bag are taken back" : ""}.` },
      { id: "run-cancel-keep", type: "item", text: "No, keep going", icon: "arrow-left", description: "Back to your job." },
    ] },
    jobquit: { title: "RESIGN?", subtitle: `${job.label.toUpperCase()} // ${job.gradeLabel.toUpperCase()}`, tag: "RESIGN", items: [
      { id: "job-quit-confirm", type: "item", text: `Yes, leave ${job.label}`, icon: "x", danger: true,
        description: `You become unemployed${run?.active ? "; the run in progress ends without pay" : ""}. Grade and salary are lost; a Job Center hires you again at the entry grade.` },
      { id: "job-quit-keep", type: "item", text: "No, keep my job", icon: "arrow-left", description: "Back to your job." },
    ] },
  };
}

/* F1 → Activities opens the Activities panel (server/modules/activities.lua); a
   running activity or a waiting request can be left from here at once. F1 → Crew
   manages the crew (server/modules/parties.lua): invites, members, matchmaking,
   leave. Inviting needs the players around: ALT + click one, or the panel's crew
   page lists them. */
function activityItems(act: ActivitiesState | undefined): RageMenuItem[] {
  const items: RageMenuItem[] = [{ id: "activities", type: "item", text: "Activities", icon: "swords",
    meta: act?.current ? "IN PLAY" : act?.queued ? "WAITING" : act ? `${act.list.length} OPEN` : undefined,
    description: "Arena, races, chases and events: status, join, your record and the leaderboards. The Crossing's terminal and the Neural-Link app Gigs & Arena open the same panel." }];
  if (act?.current && !act.current.returning) items.push({ id: "activity-leave", type: "item", text: `Leave ${act.current.label}`, icon: "log-out", danger: true,
    disabled: act.current.leaving, description: "Ends your participation. You come back where you were before it started, healed, with your own weapons." });
  else if (act?.queued) items.push({ id: "activity-leave", type: "item", text: `Cancel ${act.queued.label}`, icon: "x",
    description: "Withdraws your request: you leave its queue or lobby." });
  return items;
}

function squadNodes(party: PartyState | undefined, me: number): Record<string, MenuNode> {
  const leader = !!party?.id && party.leader === me;
  const inCrew = !!party?.id && (party.members?.length ?? 0) > 1;
  const items: RageMenuItem[] = [];
  if (party?.invites?.length) {
    items.push({ label: "INVITES" });
    for (const inv of party.invites) items.push(
      { id: `squad-accept:${inv.party}`, type: "item", text: `Join ${inv.fromName}'s crew`, icon: "user-plus", meta: `${Math.max(0, Math.ceil(inv.expiresInMs / 1000))} S`,
        description: "Accept the invite: your crew enters missions, the raid and activities together, behind its leader." },
      { id: `squad-decline:${inv.party}`, type: "item", text: `Decline ${inv.fromName}`, icon: "x" });
  }
  const nodes: Record<string, MenuNode> = {};
  items.push({ label: party?.members ? `MEMBERS ${party.members.length}/${party.maxSize}` : "MEMBERS" });
  if (party?.members) {
    for (const m of party.members) {
      const manage = leader && m.id !== me;
      items.push({ id: `squad-member:${m.id}`, type: manage ? "submenu" : "item", target: manage ? `member:${m.id}` : undefined, text: m.name,
        icon: m.leader ? "crown" : "user", meta: m.id === me ? "YOU" : m.state === "down" || m.state === "dead" ? m.state.toUpperCase() : m.leader ? "LEADER" : m.busy ? (m.busy === "lobby" ? "BOARD" : m.busy.toUpperCase()) : m.far ? "FAR" : undefined,
        description: manage ? "Make them crew leader or kick them from the crew." : m.leader ? "The crew leader invites, tags missions in and starts activities." : undefined });
      if (manage) nodes[`member:${m.id}`] = { title: m.name.toUpperCase(), subtitle: "CREW MEMBER", tag: "MEMBER", items: [
        { id: `squad-promote:${m.id}`, type: "item", text: "Make crew leader", icon: "crown", description: `${m.name} becomes the crew leader.` },
        { id: `squad-kick:${m.id}`, type: "item", text: "Kick from crew", icon: "user-minus", danger: true },
        { id: "squad-back", type: "item", text: "Back", icon: "arrow-left" },
      ] };
    }
    for (const p of party.pending ?? []) items.push({ id: `squad-pending:${p.id}`, type: "item", text: p.name, icon: "loader", meta: "INVITED", disabled: true });
  } else {
    items.push({ id: "squad-none", type: "item", text: "No crew: you play solo", icon: "users", disabled: true, description: "ALT + click a player > Invite to crew: the crew forms when they accept." });
  }
  const canToggle = !party?.id || leader;
  items.push({ separator: true },
    { id: "squad-invite", type: "item", text: "Invite players nearby", icon: "user-plus", disabled: !!party?.id && !leader,
      description: !!party?.id && !leader ? "Only the crew leader invites." : "ALT + click a player, or open the crew page of the Activities panel: the players within 15 m of you, one click to invite." },
    { id: "squad-matchmaking", type: "item", text: party?.matchmaking ? "Mission matchmaking: open" : inCrew ? "Mission matchmaking: crew only" : "Mission matchmaking: off", icon: party?.matchmaking ? "globe" : "lock",
      meta: party?.matchmaking ? "ON" : "OFF", disabled: !canToggle,
      description: !canToggle ? "The crew leader decides." : inCrew
        ? party?.matchmaking ? "Solo players fill your empty places on mission boards. Select to keep missions to your crew." : "Only your crew enters your missions. Select to let solo players fill the empty places."
        : party?.matchmaking ? "You join open mission boards, and players fill yours. Select to enter missions alone." : "You only enter missions alone. Select to join open boards and let players fill yours." });
  if (party?.members) items.push({ id: "squad-leave", type: "item", text: inCrew ? "Leave crew" : "Withdraw my invites", icon: "log-out", danger: true });
  return { squad: { title: "CREW", subtitle: inCrew ? `${party!.members!.length}/${party!.maxSize} MEMBERS` : "SOLO", tag: "CREW", items }, ...nodes };
}

function buildTree(character: CharacterState, money: MoneyState, job: JobState, gang: GangState, run: JobRunState | undefined, freecamKey?: string): Record<string, MenuNode> {
  const name = `${character.firstName ?? ""} ${character.lastName ?? ""}`.trim() || character.accountName || "";
  const id = String(character.playerId).padStart(3, "0");
  const origin = character.origins.find((o) => o.key === character.origin)?.label;
  const age = character.birthDate ? character.currentYear - Number(character.birthDate.slice(0, 4)) : null;
  return {
    root: {
      title: "OPEN//77", subtitle: "PLAYER MENU", tag: "PLAYER",
      items: [
        { label: "CHARACTER" },
        { id: "identity", type: "submenu", text: "Identity", icon: "id-card", meta: `ID ${id}`, target: "identity",
          description: "Your citizen record: ID, name, birth date, origin and bank account." },
        { id: "bank", type: "submenu", text: "Bank", icon: "landmark", meta: money.bank ? formatMoney(money.bank.balance, money.currency) : "—", target: "bank",
          description: "Cash, account balance, account number and your last operations." },
        { id: "job", type: "submenu", text: "My job", icon: "briefcase", target: "job",
          meta: job.name === "unemployed" ? "NONE" : run?.active ? `RUN ${run.index ?? 1}/${run.total ?? 1}` : job.label.toUpperCase(),
          description: job.name === "unemployed" ? "No job yet: where to find one."
            : `${job.label}: the job guide${job.run ? ", your work orders (start, GPS, abandon)" : ""}${job.work ? ", the GPS of each work stage" : ""} and your paycheck.` },
        { id: "animations", type: "item", text: "Animations", icon: "hand", description: "Gestures, postures and activities. Your favorites and quick-access animations in a dedicated side panel." },
        { id: "freecam", type: "item", text: "Free camera", icon: "video", meta: freecamKey,
          description: "Detach the view from your character to watch the scene from another angle. On foot, within a short range; your character stays in place." },
        { id: "housing", type: "item", text: "My homes", icon: "map-pin", description: "Find a home, manage rent and keys, or recover stored belongings." },
        { separator: true },
        { label: "SERVER" },
        { id: "briefing", type: "item", text: "Server briefing", icon: "info", description: "Read the welcome briefing again: what Light Roleplay means here." },
        { id: "tutorial", type: "item", text: "First day guide", icon: "map-pin", description: "The arrival hall's introduction to the city. Resume, pause or revisit your first day." },
        { id: "support", type: "item", text: "Reports & support", icon: "message-square", description: "Open a private report, read staff replies and follow your case." },
        { separator: true },
        { id: "close", type: "item", text: "Close", icon: "x", description: "Close the menu. Backspace or Escape does the same." },
      ],
    },
    bank: {
      title: "BANK", subtitle: money.bank ? `NIGHT CITY BANK // ${money.bank.number}` : "NO ACCOUNT YET", tag: "BANK",
      items: [
        { id: "cash", type: "item", text: "Cash", icon: "banknote", meta: formatMoney(money.cash, money.currency), description: "What you carry. /pay <id> <amount> hands it to someone next to you." },
        { id: "balance", type: "item", text: "Account", icon: "landmark", meta: money.bank ? formatMoney(money.bank.balance, money.currency) : "—", description: "Your balance at Night City Bank." },
        { id: "number", type: "item", text: "Account number", icon: "credit-card", meta: money.bank?.number ?? "—", description: "Give it to whoever has to wire you money: /transfer <number> <amount>." },
        { id: "total", type: "item", text: "Total", icon: "wallet", meta: formatMoney(money.cash + (money.bank?.balance ?? 0), money.currency) },
        ...(ledger(money).length > 0 ? [{ separator: true } as RageMenuItem, { label: "LAST OPERATIONS" } as RageMenuItem] : []),
        ...ledger(money).slice(0, 6).map((t, i): RageMenuItem => ({
          id: `tx${i}`, type: "item", text: transactionLabel(t), icon: t.wallet === "bank" ? "landmark" : "banknote",
          meta: formatMoney(t.amount, money.currency, true), danger: t.amount < 0 && t.kind !== "deposit" && t.kind !== "withdraw",
          description: [t.counterparty, t.note, t.at?.slice(0, 16)].filter(Boolean).join(" · ") || undefined,
        })),
      ],
    },
    identity: {
      title: "IDENTITY", subtitle: `${name.toUpperCase()} // ID ${id}`, tag: "IDENTITY",
      items: [
        { id: "id", type: "item", text: "Citizen ID", icon: "id-card", meta: id, description: "Your number on this server, the one other players use in commands." },
        { id: "first", type: "item", text: "First name", icon: "user", meta: character.firstName ?? "—", description: "The name the others read in the chat." },
        { id: "last", type: "item", text: "Last name", icon: "user", meta: character.lastName ?? "—" },
        { id: "born", type: "item", text: "Born", icon: "calendar", meta: character.birthDate ? `${character.birthDate} · ${age}Y` : "—",
          description: "Night City calendar, year " + character.currentYear + "." },
        { id: "origin", type: "item", text: "Origin", icon: "map-pin", meta: origin ?? "—" },
        { separator: true },
        { id: "job", type: "item", text: "Job", icon: "briefcase", meta: job.name === "unemployed" ? "UNEMPLOYED" : `${job.tag} · ${job.gradeLabel.toUpperCase()}`,
          description: job.name === "unemployed" ? "No job yet. Ask around town." : `${job.label}, grade ${job.grade}${job.salary > 0 ? ` · ${formatMoney(job.salary, money.currency)} every ${job.paycheckMinutes ?? 30} min` : ""}.` },
        { id: "gang", type: "item", text: "Gang", icon: "shield", meta: gang.name === "none" ? "NONE" : `${gang.tag} · ${gang.gradeLabel.toUpperCase()}`,
          description: gang.name === "none" ? "No affiliation." : `${gang.label}, ${gang.gradeLabel} (grade ${gang.grade}).` },
        { separator: true },
        { id: "account", type: "item", text: "Bank account", icon: "landmark", meta: money.bank?.number ?? "—",
          description: money.bank ? `Night City Bank. Balance ${formatMoney(money.bank.balance, money.currency)}, ${formatMoney(money.cash, money.currency)} in your pocket.` : "No account yet." },
        { id: "playtime", type: "item", text: "Time in the city", icon: "clock", meta: formatDuration(character.playtimeMs ?? 0) },
        { id: "status", type: "item", text: "Record", icon: "badge-check", meta: character.status === "active" ? "ACTIVE" : "DRAFT",
          description: character.story ? character.story : "No backstory written." },
      ],
    },
    ...jobNodes(job, run, money),
  };
}

export function PlayerMenu() {
  const open = useStore((s) => s.menuOpen);
  const character = useStore((s) => s.state.character);
  const money = useStore((s) => s.state.money);
  const job = useStore((s) => s.state.job);
  const gang = useStore((s) => s.state.gang);
  const jobRun = useStore((s) => s.state.jobRun);
  const openJobGuide = useStore((s) => s.openJobGuide);
  const tutorial = useStore((s) => s.state.tutorial);
  const staff = useStore((s) => s.state.staff);
  const activities = useStore((s) => s.state.activities);
  const party = useStore((s) => s.state.party);
  const dogtown = useStore((s) => s.state.dogtown);
  const recap = useStore((s) => s.state.recap);
  const dailies = useStore((s) => s.state.dailies);
  const titles = useStore((s) => s.state.titles);
  const setWelcomeReplay = useStore((s) => s.setWelcomeReplay);
  const [stack, setStack] = useState<Array<{ key: string; index: number }>>([{ key: "root", index: ROOT_INDEX }]);
  const [toggleKey, setToggleKey] = useState("F1");
  const [freecamKey, setFreecamKey] = useState<string | undefined>(undefined);
  useEffect(() => on<{ toggleKey?: string; freecamKey?: string }>(PAGE_EVENTS.open, p => { setToggleKey(p.toggleKey || "F1"); setFreecamKey(p.freecamKey ? p.freecamKey.toUpperCase() : undefined); }), []);
  const chapter = stack[stack.length - 1]?.key;
  useEffect(() => {
    if (open && chapter === "identity" && tutorial?.active && tutorial.step === "identity") {
      emit(PAGE_EVENTS.tutorial, { operation: "identity" });
    }
  }, [open, chapter, tutorial?.active, tutorial?.step, tutorial?.revision]);

  // Every open starts at the root, on the first row.
  useEffect(() => { if (open) setStack([{ key: "root", index: ROOT_INDEX }]); }, [open]);

  // Lua consumes the effective mapping while this menu owns focus. Close on
  // release so the native mapping cannot reopen it from the same held key.
  useEffect(() => {
    if (!open) return;
    let pressed = false;
    const down = (e: KeyboardEvent) => {
      if (!e.repeat && matchesToggleKey(e, toggleKey)) { e.preventDefault(); pressed = true; }
    };
    const up = (e: KeyboardEvent) => {
      if (pressed && matchesToggleKey(e, toggleKey)) { e.preventDefault(); pressed = false; requestClose(); }
    };
    const blur = () => { pressed = false; };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); window.removeEventListener("blur", blur); };
  }, [open, toggleKey]);

  const tree = useMemo(() => {
    const nodes = buildTree(character, money, job, gang, jobRun, freecamKey);
    // While the first day runs, leaving it is one choice away (the objective card points here).
    const guide = nodes.root?.items.findIndex((i) => "id" in i && i.id === "tutorial") ?? -1;
    if (tutorial?.active && guide >= 0) nodes.root!.items.splice(guide + 1, 0, {id:"tutorial-skip",type:"item",text:"Skip the tutorial",icon:"log-out",
      description:"Leave the first day now: your Neural-Link is installed and you get your Kabuki starter studio, its door a short walk away. You can come back to the guide later."});
    if (staff.isStaff && nodes.root) nodes.root.items.splice(nodes.root.items.length - 2, 0, {id:"admin",type:"item",text:"Staff desk",icon:"shield",description:"LightRP administration and support cases."});
    // Activities and the crew, under the homes
    const homes = nodes.root?.items.findIndex((i) => "id" in i && i.id === "housing") ?? -1;
    if (homes >= 0) nodes.root!.items.splice(homes + 1, 0, ...activityItems(activities), { id: "squad", type: "submenu", target: "squad", text: "Crew", icon: "users",
      meta: party?.invites?.length ? `${party.invites.length} INVITE${party.invites.length > 1 ? "S" : ""}` : party?.members ? `${party.members.length}/${party.maxSize}` : "SOLO",
      description: "Your crew: accept invites, see the members, invite the players around you, mission matchmaking, leave." });
    Object.assign(nodes, squadNodes(party, character.playerId));
    // Dogtown (the PvP zone), under the squad.
    const dt = dogtownMenu(dogtown, (n) => formatMoney(n, money.currency)), squad = nodes.root?.items.findIndex((i) => "id" in i && i.id === "squad") ?? -1;
    if (dt && squad >= 0) { nodes.root!.items.splice(squad + 1, 0, dt.item); Object.assign(nodes, dt.nodes); }
    // The last end-of-match recap (server/modules/recap.lua), under the crew
    const last = recap ? recap.last : undefined;
    const crew = nodes.root?.items.findIndex((i) => "id" in i && i.id === "squad") ?? -1;
    if (last && crew >= 0) nodes.root!.items.splice(crew + 1, 0, { id: "recap", type: "item", text: "Last match", icon: "list-checks",
      meta: last.test ? "TEST" : last.result, description: `The recap of your last ${last.mode ?? "match"}: the scoreboard, your numbers, the MVP and what it paid.` });
    // Daily Contracts under the homes, the title in the identity card (features/dailies)
    const home = nodes.root?.items.findIndex((i) => "id" in i && i.id === "housing") ?? -1;
    if (dailies && home >= 0) nodes.root!.items.splice(home + 1, 0, { id: "dailies", type: "item", text: "Daily Contracts", icon: "list-checks", meta: menuMeta(dailies),
      description: "Four small jobs a day from Mama Okoro, Ledger and Nix, and a big one every week, paid into your bank. Your titles are in there too." });
    const lastName = nodes.identity?.items.findIndex((i) => "id" in i && i.id === "last") ?? -1;
    const badge = shownTitle(titles);
    if (titles?.enabled && lastName >= 0) nodes.identity!.items.splice(lastName + 1, 0, { id: "identity-title", type: "item", text: "Title", icon: "crown",
      meta: badge ? badge.label.toUpperCase() : "NONE",
      description: "What others read after your name in the chat, on your crew's frame and in the Hall of Fame. Select to pick one you earned." });
    return nodes;
  }, [character, money, job, gang, jobRun, staff.isStaff, freecamKey, tutorial?.active, activities, party, dogtown, recap, dailies, titles]);
  if (!open || character.status !== "active") return null;

  const root = tree.root!;
  const top = stack[stack.length - 1] ?? { key: "root", index: ROOT_INDEX };
  const node = tree[top.key] ?? root;
  const path = stack.map((s) => (tree[s.key] ?? root).tag);
  const setIndex = (i: number) => setStack((s) => s.map((e, n) => (n === s.length - 1 ? { ...e, index: i } : e)));
  const back = () => { if (stack.length > 1) setStack((s) => s.slice(0, -1)); else requestClose(); };
  const select = (item: RageMenuItem) => {
    if (item.type === "submenu" && item.target && tree[item.target]) return setStack((s) => [...s, { key: item.target!, index: 0 }]);
    if (item.id === "briefing") { setWelcomeReplay(true); requestClose(); return; }
    if (item.id === "tutorial") { requestClose(); emit(PAGE_EVENTS.tutorial, { operation: "options" }); return; }
    if (item.id === "tutorial-skip") { requestClose(); emit(PAGE_EVENTS.tutorial, { operation: "skip-ask" }); return; }
    if (item.id === "support" || item.id === "admin") { requestClose(); emit(PAGE_EVENTS.support, {operation:"open",scope:item.id === "admin" ? "staff" : "player"}); return; }
    if (item.id === "animations") { requestClose(); emit(PAGE_EVENTS.animationsAction, { action: "open" }); return; }
    if (item.id === "freecam") { requestClose(); emit(PAGE_EVENTS.freecam, { operation: "toggle" }); return; }
    if (item.id === "housing") { requestClose(); emit(PAGE_EVENTS.action, { type: "housing.open" }); return; }
    if (item.id === "job-guide") { requestClose(); openJobGuide(job.name); return; }
    if (item.id === "run-start") { requestClose(); sendAction({ type: "jobs.start", from: "menu" }); return; }
    if (item.id === "run-gps") { requestClose(); sendAction({ type: "jobs.gps" }); return; }
    if (item.id === "run-cancel-confirm") { sendAction({ type: "jobs.cancel" }); setStack((s) => s.slice(0, -1)); return; }
    if (item.id === "run-cancel-keep" || item.id === "job-quit-keep") { setStack((s) => s.slice(0, -1)); return; }
    if (item.id === "job-quit-confirm") { sendAction({ type: "jobs.quit" }); setStack((s) => s.slice(0, -1)); return; }
    if (item.id === "work-collect" || item.id === "work-process" || item.id === "work-sell") {
      requestClose(); sendAction({ type: "jobs.locate", job: job.name, stage: item.id.slice(5) as "collect" | "process" | "sell" }); return;
    }
    if (item.id === "activities" || item.id === "squad-invite") {
      requestClose(); sendAction({ type: "activities.control", operation: "open", tab: item.id === "squad-invite" ? "crew" : "activities" }); return;
    }
    if (item.id === "recap") { sendAction({ type: "recap.open" }); requestClose(); return; }
    if (item.id === "dailies" || item.id === "identity-title") { sendAction({ type: "dailies.open", tab: item.id === "identity-title" ? "titles" : "today" }); requestClose(); return; }
    if (item.id === "activity-leave") { sendAction({ type: "activities.control", operation: "leave" }); requestClose(); return; }
    if (item.id === "squad-leave") { sendAction({ type: "party.leave" }); setStack((s) => s.slice(0, -1)); return; }
    if (item.id === "squad-matchmaking") { sendAction({ type: "party.matchmaking", on: !party?.matchmaking }); return; }
    if (item.id === "squad-back") { setStack((s) => s.slice(0, -1)); return; }
    const [verb, arg] = (item.id ?? "").split(":");
    if (verb === "squad-accept" && arg) { sendAction({ type: "party.accept", party: arg }); return; }
    if (verb === "squad-decline" && arg) { sendAction({ type: "party.decline", party: arg }); return; }
    if ((verb === "squad-promote" || verb === "squad-kick") && arg) {
      sendAction({ type: verb === "squad-promote" ? "party.promote" : "party.kick", target: Number(arg) }); setStack((s) => s.slice(0, -1)); return;
    }
    if (item.id === "close") requestClose();
  };

  return (
    <div className="player-menu">
      <RageMenu title={node.title} subtitle={node.subtitle} tag={node.tag} items={node.items} index={top.index} path={path}
        width={340} onIndexChange={setIndex} onSelect={select} onBack={back}
        footer={<><span>[↑↓] MOVE</span><span>[ENTER] SELECT</span><span>[BKSP] BACK</span><span>[{toggleKey}] CLOSE</span></>} />
    </div>
  );
}
