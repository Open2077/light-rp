import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type ActivitiesState, type ActivitiesTab, type ActivityEntry, type PartyState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Keycap, Tabs, cx } from "@/design/components";
import { KIND_ICON, KIND_LABEL, formatClock, formatTime, mineLine, pickedDifficulty, repLine, roman, statusLine } from "./model";
import "./activities.css";

/* The Activities panel (server/modules/activities.lua, activities_hub.lua): opened
   by The Crossing's terminal, F1 > Activities and the Neural-Link app Gigs & Arena.
   Three tabs: the activities (status, join / leave, your record, the leaderboard),
   the contract boards of the city (a GPS route to each) and the crew. In a crew only
   the leader joins, and the crew is queued with them. Everything comes from the
   `activities` and `party` state; nothing is assumed. */

const ACTION = "activities.control";

export function ActivitiesDialog() {
  const dialog = useStore((s) => s.dialog);
  const close = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "activities";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "activities", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "activities") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "activities", open: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "activities") return null;
  const asked = dialog.tab as string | undefined;
  const tab: ActivitiesTab = asked === "contracts" ? "contracts" : asked === "crew" || asked === "squad" ? "crew" : "activities";
  return <ActivitiesBody key={tab} initialTab={tab} onClose={close} />;
}

function ActivitiesBody({ initialTab, onClose }: { initialTab: ActivitiesTab; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const state = useStore((s) => s.state.activities);
  const party = useStore((s) => s.state.party);
  const me = useStore((s) => s.state.character.playerId);
  const result = useStore((s) => s.lastResult);
  const [tab, setTab] = useState<ActivitiesTab>(initialTab);
  const [selected, setSelected] = useState<string | undefined>(undefined);
  const [modes, setModes] = useState<Record<string, string>>({});
  const [levels, setLevels] = useState<Record<string, string>>({}); // PvE difficulty per activity
  const [waiting, setWaiting] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean }>();
  const sent = useRef(0);
  // countdowns are relative to the push that carried them
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [state]);
  useEffect(() => { const t = window.setInterval(() => tick((n) => n + 1), 1000); return () => window.clearInterval(t); }, []);
  useEffect(() => { root.current?.focus(); }, [tab]);
  // the players around change while the crew tab is open
  useEffect(() => {
    if (tab !== "crew") return;
    sendAction({ type: ACTION, operation: "refresh" });
    const t = window.setInterval(() => sendAction({ type: ACTION, operation: "refresh" }), 6000);
    return () => window.clearInterval(t);
  }, [tab]);
  useEffect(() => {
    if (!result || result.action !== ACTION || result.at < sent.current) return;
    setWaiting(false);
    setFeedback({ text: result.text, error: !result.ok });
  }, [result]);
  useEffect(() => {
    if (!waiting) return;
    const t = window.setTimeout(() => { setWaiting(false); setFeedback({ text: "No answer yet. The activity may still pick you up: watch your notices.", error: true }); }, 10000);
    return () => window.clearTimeout(t);
  }, [waiting]);

  const list = state?.list ?? [];
  const activity = list.find((a) => a.id === selected) ?? list[0];
  const close = () => { sendAction({ type: ACTION, operation: "close" }); onClose(); };
  const ask = (action: Parameters<typeof sendAction>[0]) => { sent.current = Date.now(); setWaiting(true); setFeedback(undefined); sendAction(action); };
  const join = (a: ActivityEntry) => {
    const mode = modes[a.id];
    const level = a.pve ? pickedDifficulty(a, levels[a.id]) : undefined;
    const options = { ...(mode ? { [a.modeKey || "mode"]: mode } : {}), ...(level ? { difficulty: level.id } : {}) };
    ask({ type: ACTION, operation: "join", id: a.id, from: "panel", options: Object.keys(options).length > 0 ? options : undefined });
  };
  const leave = () => ask({ type: ACTION, operation: "leave" });
  const move = (step: number) => {
    if (list.length === 0) return;
    const at = Math.max(0, list.findIndex((a) => a.id === activity?.id));
    setSelected(list[(at + step + list.length) % list.length]!.id);
  };
  const tabs = useMemo(() => [
    { value: "activities" as const, label: "ACTIVITIES", icon: "swords", count: list.length || undefined },
    { value: "contracts" as const, label: "CONTRACTS", icon: "terminal", count: state?.contracts.length || undefined },
    { value: "crew" as const, label: "CREW", icon: "users", count: party?.invites?.length ? `${party.invites.length} NEW` : party?.members ? `${party.members.length}/${party.maxSize}` : undefined },
  ], [list.length, state?.contracts.length, party]);

  return <div className="activities o77-interactive" role="dialog" aria-modal="true" aria-labelledby="activities-title" ref={root} tabIndex={-1}
    onKeyDown={(e) => {
      if ((e.target as HTMLElement).tagName === "INPUT") return;
      let handled = true;
      if (e.key === "Escape") { if (!e.repeat) close(); }
      else if (tab === "activities" && e.key === "ArrowDown") move(1);
      else if (tab === "activities" && e.key === "ArrowUp") move(-1);
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    }}>
    <header className="activities__bar">
      <span className="activities__bar-title"><Icon name="swords" size={15} />{(state?.hub.name ?? "The Crossing").toUpperCase()}
        {state?.bots && <span className="activities__bar-tag" title="Staff bot mode: bots fill the missing places, results are not recorded">BOTS ON · TEST</span>}</span>
      <span className="activities__bar-route">ARENA · RACES · CHASES · EVENTS<button aria-label="Close" onClick={close}><Icon name="x" size={15} /></button></span>
    </header>
    <StatusStrip state={state} received={received} onLeave={leave} waiting={waiting} />
    <div className="activities__tabs"><Tabs items={tabs} value={tab} onChange={setTab} /></div>

    {!state ? <p className="activities__empty"><Icon name="loader" size={14} />Waiting for the activities board…</p>
      : tab === "activities" ? <div className="activities__split">
        <div className="activities__list" role="listbox" aria-label="Activities">
          {list.length === 0 && <p className="activities__empty">No activity is open right now. Arena, races and chases appear here as soon as they run.</p>}
          {list.map((a) => <ActivityRow key={a.id} a={a} selected={a.id === activity?.id} state={state}
            onSelect={() => setSelected(a.id)} />)}
        </div>
        {activity ? <ActivityDetail a={activity} state={state} party={party} mode={modes[activity.id]} level={levels[activity.id]} waiting={waiting}
          onMode={(m) => setModes((s) => ({ ...s, [activity.id]: m }))} onLevel={(d) => setLevels((s) => ({ ...s, [activity.id]: d }))}
          onJoin={() => join(activity)} onLeave={leave} /> : <div />}
      </div>
      : tab === "contracts" ? <Contracts state={state} />
      : <Crew state={state} party={party} me={me} />}

    <footer className="activities__foot">
      <span className={cx("activities__feedback", feedback?.error && "is-error")} role="status">
        {waiting ? <><Icon name="loader" size={13} />Asking…</> : feedback?.text ?? (state ? (state.bots ? "Bot mode: bots fill the missing places · results are not recorded" : repLine(state)) : "")}
      </span>
      <span className="activities__keys">
        {tab === "activities" && <span><Keycap size="sm">↑↓</Keycap>CHOOSE</span>}
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>
  </div>;
}

/* Where the player stands: in an activity, queued, on a mission, or why not free. */
function StatusStrip({ state, received, onLeave, waiting }: { state?: ActivitiesState; received: number; onLeave(): void; waiting: boolean }) {
  if (!state) return null;
  const elapsed = (ms: number) => formatClock(ms + (performance.now() - received));
  if (state.current) {
    const c = state.current;
    return <div className="activities__strip is-live">
      <Icon name="activity" size={15} />
      <span><b>{c.returning ? "ON YOUR WAY BACK" : c.leaving ? "LEAVING" : "IN"} · {c.label.toUpperCase()}</b><small>{elapsed(c.sinceMs)}</small></span>
      {!c.returning && <Button size="sm" variant="danger" icon="log-out" disabled={waiting || c.leaving} onClick={onLeave}>LEAVE</Button>}
    </div>;
  }
  if (state.queued) {
    const q = state.queued;
    return <div className="activities__strip is-queued">
      <Icon name="loader" size={15} />
      <span><b>WAITING FOR {q.label.toUpperCase()}</b><small>{elapsed(q.sinceMs)} · keep playing, you are pulled in when it starts</small></span>
      <Button size="sm" variant="secondary" icon="x" disabled={waiting} onClick={onLeave}>CANCEL</Button>
    </div>;
  }
  if (state.mission) return <div className="activities__strip is-blocked"><Icon name="crosshair" size={15} /><span><b>ON A MISSION</b><small>Finish it or /mission leave first.</small></span></div>;
  if (!state.eligible && state.reason) return <div className="activities__strip is-blocked"><Icon name="triangle-alert" size={15} /><span><b>NOT RIGHT NOW</b><small>{state.reason}</small></span></div>;
  return <div className="activities__strip"><Icon name="check" size={15} /><span><b>READY</b><small>Pick an activity: you come back here, as you left, when it ends.</small></span></div>;
}

function ActivityRow({ a, selected, state, onSelect }: { a: ActivityEntry; selected: boolean; state: ActivitiesState; onSelect(): void }) {
  const mine = state.current && state.current.id === a.id ? "IN" : state.queued && state.queued.id === a.id ? "QUEUED" : undefined;
  return <button role="option" aria-selected={selected} onClick={onSelect}
    className={cx("activity-row", `is-${a.phase}`, selected && "is-selected", !a.joinable && "is-closed")}>
    <span className="activity-row__icon"><Icon name={KIND_ICON[a.kind] ?? "zap"} size={18} /></span>
    <span className="activity-row__text">
      <strong>{a.label}</strong>
      <small>{statusLine(a)}</small>
    </span>
    <span className="activity-row__meta">
      {mine ? <Badge tone="accent">{mine}</Badge> : <Badge tone={a.phase === "running" ? "success" : "outline"}>{a.phase === "idle" ? "OPEN" : a.phase.toUpperCase()}</Badge>}
      <span>{a.players}<i>/{a.maxPlayers}</i></span>
    </span>
  </button>;
}

function ActivityDetail({ a, state, party, mode, level, waiting, onMode, onLevel, onJoin, onLeave }: {
  a: ActivityEntry; state: ActivitiesState; party?: PartyState; mode?: string; level?: string; waiting: boolean;
  onMode(mode: string): void; onLevel(difficulty: string): void; onJoin(): void; onLeave(): void;
}) {
  const inside = !!state.current && state.current.id === a.id;
  const queuedHere = !!state.queued && state.queued.id === a.id;
  const busyElsewhere = !!state.current && !inside;
  const blocked = !state.eligible && !inside && !queuedHere;
  const crewSize = party?.id && party.members ? party.members.length : 1;
  // PvE: the difficulty picked (the first open one by default), locked above the street cred tier
  const picked = a.pve ? pickedDifficulty(a, level) : undefined;
  const tooHard = picked?.locked ? `${picked.label} needs reputation tier ${roman(picked.minTier)}${picked.tierName ? ` (${picked.tierName})` : ""}.` : undefined;
  const why = busyElsewhere ? `You are in ${state.current && state.current.label}.`
    : state.crewLeader && !inside && !queuedHere ? `${state.crewLeader} leads your crew and starts activities. Leave the crew to go solo.`
    : !a.joinable ? `${a.label} is not taking players right now.` : blocked ? state.reason : tooHard;
  const board = a.board;
  const record = board ? a.mineBoard : a.mine;
  return <section className="activity-detail" aria-labelledby="activities-title">
    <div className="activity-detail__head">
      <Badge tone="accent">{KIND_LABEL[a.kind] ?? "EVENT"}</Badge>
      {a.pve && <Badge tone="success">PVE</Badge>}
      <h1 id="activities-title">{a.label}</h1>
    </div>
    {a.description && <p className="activity-detail__brief">{a.description}</p>}
    <dl className="activity-detail__stats">
      <div><dt><Icon name="users" size={12} />PLAYERS</dt><dd>{a.minPlayers === a.maxPlayers ? a.maxPlayers : `${a.minPlayers}-${a.maxPlayers}`}</dd></div>
      <div><dt><Icon name="activity" size={12} />NOW</dt><dd>{a.players} IN · {a.queued} WAITING</dd></div>
      <div><dt><Icon name="crown" size={12} />RANKED BY</dt><dd>{a.byTime ? "BEST TIME" : "WINS"}</dd></div>
      <div><dt><Icon name="badge-check" size={12} />EARNS</dt><dd>{a.pve ? (picked ? `UP TO ${picked.reputation} REP` : "REPUTATION") : "WINS · RANKING"}</dd></div>
    </dl>
    {a.pve && (a.difficulties?.length ?? 0) > 0 && !inside && !queuedHere && <div className="activity-detail__modes" role="radiogroup" aria-label="Difficulty">
      {a.difficulties!.map((d) => <button key={d.id} role="radio" aria-checked={picked?.id === d.id} aria-disabled={d.locked}
        title={d.locked ? `Reputation tier ${roman(d.minTier)}${d.tierName ? ` (${d.tierName})` : ""}: PvE missions, raids, gigs and PvE activities earn it.` : `Up to ${d.reputation} reputation`}
        className={cx("activity-mode", picked?.id === d.id && "is-on", d.locked && "is-locked")} onClick={() => onLevel(d.id)}>
        {d.locked && <Icon name="lock" size={11} />}{d.label.toUpperCase()}{d.locked ? ` · REP ${roman(d.minTier)}` : ""}</button>)}
    </div>}
    {a.modes.length > 0 && !inside && !queuedHere && <div className="activity-detail__modes" role="radiogroup" aria-label="Mode">
      <button role="radio" aria-checked={!mode} className={cx("activity-mode", !mode && "is-on")} onClick={() => onMode("")}>ANY</button>
      {a.modes.map((m) => <button key={m.id} role="radio" aria-checked={mode === m.id} className={cx("activity-mode", mode === m.id && "is-on")}
        onClick={() => onMode(m.id)}>{m.label.toUpperCase()}</button>)}
    </div>}
    <div className="activity-detail__actions">
      {inside ? <Button variant="danger" icon="log-out" disabled={waiting || (state.current && (state.current.leaving || state.current.returning))} onClick={onLeave}>LEAVE {a.label.toUpperCase()}</Button>
        : queuedHere ? <Button variant="secondary" icon="x" disabled={waiting} onClick={onLeave}>CANCEL MY REQUEST</Button>
        : <Button icon="chevron-right" disabled={waiting || !!why} onClick={onJoin}>{state.queued ? "SWITCH TO THIS ONE" : crewSize > 1 && !state.crewLeader ? "JOIN WITH THE CREW" : "JOIN"}</Button>}
      {why ? <span className="activity-detail__why"><Icon name="triangle-alert" size={13} />{why}</span>
        : crewSize > 1 && !inside && !queuedHere && <span className="activity-detail__why is-info"><Icon name="users" size={13} />Your {crewSize - 1} crew member{crewSize > 2 ? "s are" : " is"} queued with you.</span>}
    </div>

    <h2 className="activity-detail__step">YOUR RECORD{board ? ` · ${board.course.toUpperCase()}` : ""}</h2>
    <p className="activity-detail__mine">{mineLine(a, record)}</p>

    <h2 className="activity-detail__step">LEADERBOARD{board ? ` · ${board.course.toUpperCase()}${board.revision ? ` REV ${board.revision}` : ""}` : ""}</h2>
    {a.top.length === 0 ? <p className="activity-detail__mine">Nobody on the board yet: the first result takes the top.</p>
      : <ol className="activity-top">{a.top.map((r) => <li key={r.rank} className={cx(r.rank === 1 && "is-first")}>
        <span className="activity-top__rank">{String(r.rank).padStart(2, "0")}</span>
        <span className="activity-top__name">{r.name}</span>
        <span className="activity-top__value">{a.byTime ? formatTime(r.bestTimeMs) : `${r.wins} W · ${r.played} P`}</span>
      </li>)}</ol>}
  </section>;
}

/* The city's contract boards: the missions run there as before; this sets the route. */
function Contracts({ state }: { state: ActivitiesState }) {
  return <section className="activities__page">
    <p className="activities__hint">Missions start at their own boards around the city. Pick one: the GPS takes you there, and its board works as usual.</p>
    <div className="activities__rows">
      <div className="activities-line">
        <span className="activities-line__icon"><Icon name="swords" size={16} /></span>
        <span className="activities-line__text"><strong>{state.hub.name}</strong><small>The activities hub · Westbrook esplanade</small></span>
        <Button size="sm" variant="secondary" icon="navigation" onClick={() => sendAction({ type: ACTION, operation: "gps", id: "hub" })}>GPS</Button>
      </div>
      {state.contracts.length === 0 && <p className="activities__empty">No contract board is open.</p>}
      {state.contracts.map((c) => <div key={c.id} className="activities-line">
        <span className="activities-line__icon"><Icon name="terminal" size={16} /></span>
        <span className="activities-line__text"><strong>{c.title}</strong><small>{c.type} · {c.location}{c.description ? ` — ${c.description}` : ""}</small></span>
        <span className="activities-line__meta">{c.distance != null ? (c.distance >= 1000 ? `${(c.distance / 1000).toFixed(1)} KM` : `${c.distance} M`) : "—"}</span>
        <Button size="sm" variant="secondary" icon="navigation" onClick={() => sendAction({ type: ACTION, operation: "gps", id: c.id })}>GPS</Button>
      </div>)}
    </div>
  </section>;
}

/* The crew (server/modules/parties.lua): players who play missions, the raid and
   activities together. ALT + click a player does the same as the buttons here. */
function Crew({ state, party, me }: { state: ActivitiesState; party?: PartyState; me: number }) {
  const leader = !!party?.id && party.leader === me;
  const inCrew = !!party?.id && (party.members?.length ?? 0) > 1;
  const full = (party?.members?.length ?? 1) >= (party?.maxSize ?? 8);
  const canToggle = !party?.id || leader;
  return <section className="activities__page activities__squad">
    <p className="activities__hint">Your crew enters missions, the Chimera raid and activities together: its leader tags in or joins, and the crew follows. ALT + click a player to invite them. Invites last {party?.inviteSeconds ?? 60} seconds.</p>
    {!!party?.invites?.length && <><h2 className="activity-detail__step">INVITES</h2>
      {party.invites.map((inv) => <div key={inv.party} className="activities-line">
        <span className="activities-line__icon"><Icon name="user-plus" size={16} /></span>
        <span className="activities-line__text"><strong>{inv.fromName}</strong><small>wants you in their crew</small></span>
        <Button size="sm" icon="check" onClick={() => sendAction({ type: "party.accept", party: inv.party })}>ACCEPT</Button>
        <Button size="sm" variant="ghost" onClick={() => sendAction({ type: "party.decline", party: inv.party })}>DECLINE</Button>
      </div>)}</>}
    <h2 className="activity-detail__step">MEMBERS{party?.members ? ` ${party.members.length}/${party.maxSize}` : ""}</h2>
    {party?.members ? party.members.map((m) => <div key={m.id} className="activities-line">
      <span className="activities-line__icon"><Icon name={m.leader ? "crown" : "user"} size={16} /></span>
      <span className="activities-line__text"><strong>{m.name}</strong><small>{m.leader ? "LEADER" : "MEMBER"}{m.id === me ? " · YOU" : ""}{m.state && m.state !== "alive" ? ` · ${m.state.toUpperCase()}` : ""}{m.busyLabel ? ` · ${m.busyLabel.toUpperCase()}` : ""}{m.far && m.id !== me ? " · FAR" : ""}</small></span>
      {leader && m.id !== me && <>
        <Button size="sm" variant="ghost" icon="crown" title="Hand the lead over" onClick={() => sendAction({ type: "party.promote", target: m.id })}>LEAD</Button>
        <Button size="sm" variant="ghost" icon="user-minus" title="Kick from the crew" onClick={() => sendAction({ type: "party.kick", target: m.id })}>KICK</Button>
      </>}
    </div>) : <p className="activities__empty">No crew yet: you play solo. Invite the players around you below, or ALT + click one.</p>}
    {party?.pending?.map((p) => <div key={p.id} className="activities-line is-pending">
      <span className="activities-line__icon"><Icon name="loader" size={16} /></span>
      <span className="activities-line__text"><strong>{p.name}</strong><small>invited</small></span>
    </div>)}
    {party?.members && <div className="activities__row-actions"><Button size="sm" variant="danger" icon="log-out" onClick={() => sendAction({ type: "party.leave" })}>{inCrew ? "LEAVE CREW" : "WITHDRAW INVITES"}</Button></div>}
    <h2 className="activity-detail__step">MISSION MATCHMAKING</h2>
    <div className="activities-line">
      <span className="activities-line__icon"><Icon name={party?.matchmaking ? "globe" : "lock"} size={16} /></span>
      <span className="activities-line__text"><strong>{party?.matchmaking ? "OPEN TO MATCHMAKING" : inCrew ? "CREW ONLY" : "MATCHMAKING OFF"}</strong>
        <small>{!canToggle ? "The crew leader decides." : inCrew
          ? party?.matchmaking ? "Solo players fill the empty places on mission boards." : "Nobody else joins your missions. Open it to let solo players fill the empty places."
          : party?.matchmaking ? "You join open mission boards, and players fill yours." : "You only enter missions alone. Turn it on to join open boards."}</small></span>
      {canToggle && <Button size="sm" variant="secondary" icon={party?.matchmaking ? "lock" : "globe"}
        onClick={() => sendAction({ type: "party.matchmaking", on: !party?.matchmaking })}>{party?.matchmaking ? (inCrew ? "CREW ONLY" : "TURN OFF") : (inCrew ? "OPEN" : "TURN ON")}</Button>}
    </div>
    <h2 className="activity-detail__step">NEARBY</h2>
    {state.nearby.length === 0 ? <p className="activities__empty">Nobody around. Players within 15 m of you show up here.</p>
      : state.nearby.map((p) => <div key={p.id} className="activities-line">
        <span className="activities-line__icon"><Icon name="user" size={16} /></span>
        <span className="activities-line__text"><strong>{p.name}</strong><small>{p.distance} M{p.mine ? " · IN YOUR CREW" : p.inSquad ? " · IN A CREW" : ""}</small></span>
        {!p.mine && <Button size="sm" variant="secondary" icon="user-plus" disabled={p.inSquad || p.invited || full || (!!party?.id && !leader)}
          onClick={() => sendAction({ type: "party.invite", target: p.id })}>{p.invited ? "INVITED" : "INVITE"}</Button>}
      </div>)}
  </section>;
}
