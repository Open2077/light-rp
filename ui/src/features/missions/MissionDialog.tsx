import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type MissionBoard, type MissionDialogPayload, type MissionDifficulty, type MissionEntry, type MissionUpdate, type PartyState } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { normalizeMission } from "./model";
import "./mission.css";

/* The mission point (The Division style): 01 choose a difficulty, 02 its board.
   Entry is by crew: the crew leader tags the whole crew in (E), a member waits for
   the leader, a player alone is a crew of one. A crew gets its own board and
   launches at the minimum; "open to matchmaking" (M, the leader) lets strangers
   fill the empty places, and then a full board (or the host, R, with the minimum)
   starts the countdown. The crew drawer (Q) invites the players around and manages
   the crew. Every change comes back from the server (lightrp:ui:mission). */

export function MissionDialog() {
  const dialog = useStore(s => s.dialog);
  const close = useStore(s => s.closeDialog);
  const visible = dialog?.kind === "mission";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "mission", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, p => { if (!p?.kind || p.kind === "mission") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "mission", open: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "mission") return null;
  return <MissionBody key={dialog.session} initial={dialog} onClose={close} />;
}

const TONE: Record<string, string> = { standard: "standard", hard: "hard", critical: "critical" };
const pad = (n: number) => String(n).padStart(2, "0");
const initials = (name: string) => { const [first, ...rest] = name.split(" "); return rest.length ? `${first![0]}. ${rest.join(" ")}` : name; };

function MissionBody({ initial, onClose }: { initial: MissionDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const [data, setData] = useState(initial);
  const [view, setView] = useState<"difficulty" | "board">(initial.tagged ? "board" : "difficulty");
  const firstOpen = initial.difficulties.find(d => d.id === initial.tagged?.difficulty) ?? initial.difficulties.find(d => !d.locked) ?? initial.difficulties[0]!;
  const [selected, setSelected] = useState(firstOpen.id);
  const [squadOpen, setSquadOpen] = useState(false);
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  const party = useStore(s => s.state.party);
  const currency = useStore(s => s.state.money.currency);
  const money = (n: number) => formatMoney(n, currency);

  useEffect(() => on<MissionUpdate>(PAGE_EVENTS.mission, u => {
    if (!u || u.session !== initial.session) return;
    if (u.closed) { onClose(); return; }
    if (u.state) { setData(normalizeMission(u.state)); setReceived(performance.now()); }
  }), [initial.session, onClose]);
  useEffect(() => { const t = window.setInterval(() => tick(n => n + 1), 250); return () => window.clearInterval(t); }, []);
  useEffect(() => { root.current?.focus(); }, [view, squadOpen]);

  const diff = data.difficulties.find(d => d.id === selected) ?? data.difficulties[0]!;
  const board = data.boards[diff.id]!;
  const mine = data.tagged?.difficulty === diff.id ? data.tagged : undefined;
  const leader = !!party?.id && party.leader === data.me.id;
  const squadSize = party?.members?.length ?? 1;
  // how this player enters (the server's word; the crew state as a fallback)
  const entry: MissionEntry = data.entry ?? { size: party?.id ? squadSize : 1, leads: !party?.id || squadSize < 2 || leader,
    leader: party?.members?.find(m => m.leader)?.name, crew: party?.id && squadSize > 1 ? party.id : undefined, matchmaking: !!party?.matchmaking, open: false };
  const countdown = board.state === "countdown" && board.countdownMs != null ? Math.max(0, Math.ceil((board.countdownMs - (performance.now() - received)) / 1000)) : undefined;
  const hostCanLaunch = !!mine?.host && board.state === "open" && board.members.length >= board.min;

  const session = data.session;
  const close = () => { sendAction({ type: "mission.close", session }); onClose(); };
  const tag = () => { if (mine) sendAction({ type: "mission.untag", session }); else if (!diff.locked && entry.leads) sendAction({ type: "mission.tag", session, difficulty: diff.id }); };
  const matchmaking = () => { if (entry.leads) sendAction({ type: "mission.matchmaking", session, on: !entry.matchmaking }); };
  const launch = () => { if (hostCanLaunch) sendAction({ type: "mission.launch", session }); };
  // a crew member may look at any board: their leader picks, and below what they have
  // unlocked they still play it, for their own reward (the server's rule)
  const viewable = (d: MissionDifficulty) => !d.locked || !entry.leads;
  const openBoard = () => { if (viewable(diff)) setView("board"); };
  const move = (step: number) => {
    const list = data.difficulties;
    const at = list.findIndex(d => d.id === selected);
    setSelected(list[(at + step + list.length) % list.length]!.id);
  };

  const withNames = (party?.members ?? []).filter(m => m.id !== data.me.id).map(m => initials(m.name).toUpperCase());
  const identity = `${initials(data.me.name).toUpperCase()} · #${data.me.citizen} · REP ${data.me.reputation}${data.me.tierName ? ` · ${ROMAN[data.me.tier] ?? data.me.tier} ${data.me.tierName.toUpperCase()}` : ""}${withNames.length ? ` · WITH ${withNames.join(", ")}` : ""}`;

  return <div className="mission o77-interactive" role="dialog" aria-modal="true" aria-labelledby="mission-title" ref={root} tabIndex={-1}
    onKeyDown={e => {
      const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
      if (e.repeat && k !== "ArrowUp" && k !== "ArrowDown") return;
      if ((e.target as HTMLElement).tagName === "INPUT") return;
      let handled = true;
      if (k === "Escape") { if (squadOpen) setSquadOpen(false); else close(); }
      else if (k === "q") setSquadOpen(v => !v);
      else if (squadOpen) handled = false;
      else if (view === "difficulty") {
        if (k === "ArrowDown") move(1); else if (k === "ArrowUp") move(-1); else if (k === "Enter") openBoard(); else handled = false;
      } else {
        if (k === "Backspace") setView("difficulty"); else if (k === "e" || k === "g") tag(); else if (k === "m") matchmaking(); else if (k === "r") launch(); else handled = false;
      }
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    }}>
    <header className="mission__bar">
      <span className="mission__bar-title"><Icon name="terminal" size={15} />MISSION POINT</span>
      <span className="mission__bar-route">{data.point.type} // {data.point.location}<button aria-label="Close" onClick={close}><Icon name="x" size={15} /></button></span>
    </header>
    <MissionArt type={data.point.type} location={data.point.location} />
    {data.taggedElsewhere && <div className="mission__elsewhere"><Icon name="triangle-alert" size={14} />You are tagged on {data.taggedElsewhere}. Tagging here moves you.</div>}

    {view === "difficulty" ? <section className="mission__choose">
      <h1 id="mission-title" className="mission__title">{data.point.title}</h1>
      <p className="mission__brief">{data.point.description}</p>
      <h2 className="mission__step">01 · CHOOSE DIFFICULTY</h2>
      <div className="mission__rows" role="listbox" aria-label="Difficulty">
        {data.difficulties.map(d => <DifficultyRow key={d.id} d={d} selected={d.id === selected} mine={data.tagged?.difficulty === d.id} money={money}
          member={!entry.leads} onSelect={() => setSelected(d.id)} onOpen={() => { setSelected(d.id); if (viewable(d)) setView("board"); }} />)}
      </div>
    </section> : <BoardView data={data} diff={diff} board={board} mine={!!mine} countdown={countdown} money={money} entry={entry} />}

    <footer className="mission__foot">
      <span className="mission__identity">{identity}</span>
      <div className="mission__keys">
        <button className="mission__key mission__key--ghost" onClick={() => setSquadOpen(v => !v)}>
          <Icon name="users" size={14} />CREW {party?.members ? `${squadSize}/${party.maxSize}` : "· SOLO"}<kbd>Q</kbd>
          {!!party?.invites?.length && <i className="mission__badge">{party.invites.length}</i>}
        </button>
        {view === "difficulty" ? <>
          <button className="mission__key mission__key--ghost" onClick={close}>CLOSE<kbd>ESC</kbd></button>
          <button className="mission__key mission__key--primary" disabled={!viewable(diff)} onClick={openBoard}><Icon name="chevron-right" size={15} />OPEN BOARD<kbd>⏎</kbd></button>
        </> : <>
          <button className="mission__key mission__key--ghost" onClick={() => setView("difficulty")}><Icon name="undo-2" size={14} />DIFFICULTY<kbd>BKSP</kbd></button>
          {hostCanLaunch && <button className="mission__key mission__key--launch" onClick={launch}><Icon name="swords" size={14} />LAUNCH NOW<kbd>R</kbd></button>}
          <button className={`mission__key mission__key--group${entry.matchmaking ? " is-on" : ""}`} disabled={!entry.leads}
            title={!entry.leads ? "The crew leader decides." : entry.size > 1
              ? entry.matchmaking ? "Solo players fill your empty places. Select to keep it to your crew." : "Only your crew enters. Select to let solo players fill the empty places."
              : entry.matchmaking ? "You join open boards and players fill yours. Select to enter alone." : "You enter alone. Select to join open boards and let players fill yours."}
            onClick={matchmaking}><Icon name={entry.matchmaking ? "globe" : "lock"} size={14} />{entry.matchmaking ? "MATCHMAKING ON" : entry.size > 1 ? "CREW ONLY" : "MATCHMAKING OFF"}<kbd>M</kbd></button>
          <button className={`mission__key ${mine ? "mission__key--leave" : "mission__key--primary"}`} disabled={!mine && (diff.locked || !entry.leads)}
            title={!mine && !entry.leads ? `${entry.leader ?? "Your crew leader"} tags the crew in. Leave the crew to go solo.` : undefined} onClick={tag}>
            <Icon name={mine ? "log-out" : "plus"} size={14} />{mine ? "LEAVE" : entry.size > 1 ? `TAG CREW IN (${entry.size})` : "TAG IN"}<kbd>E</kbd></button>
        </>}
      </div>
    </footer>
    {squadOpen && <SquadDrawer data={data} party={party} entry={entry} onToggle={matchmaking} onClose={() => setSquadOpen(false)} />}
  </div>;
}

/* The banner: no artwork yet, so a generated one (grid, glow, hazard stripes, the mission type). */
function MissionArt({ type, location }: { type: string; location: string }) {
  return <div className="mission__art" aria-hidden>
    <div className="mission__art-grid" /><div className="mission__art-glow" /><div className="mission__art-stripes" />
    <span className="mission__art-type">{type}</span>
    <span className="mission__art-label">{type} · {location}</span>
  </div>;
}

function Meter({ value, max, tone }: { value: number; max: number; tone: string }) {
  return <div className={`mission__meter is-${tone}`} style={{ "--cells": max } as CSSProperties}>
    {Array.from({ length: max }, (_, i) => <i key={i} className={i < value ? "is-on" : ""} />)}</div>;
}

const ROMAN = ["", "I", "II", "III", "IV", "V"];

function DifficultyRow({ d, selected, mine, member, money, onSelect, onOpen }: { d: MissionDifficulty; selected: boolean; mine: boolean; member: boolean; money(n: number): string; onSelect(): void; onOpen(): void }) {
  const tone = TONE[d.id] ?? "standard";
  // what opens it: the street cred tier (docs/pve-progression.md), then the clear ladder
  const rep = d.tier > 1 ? `REP ${ROMAN[d.tier] ?? d.tier}` : "";
  const unlock = [rep, d.requires ? `CLEAR ${d.requires}` : ""].filter(Boolean).join(" + ") || "OPEN";
  // a crew member is never refused the leader's pick: locked for them alone, it still pays their own reward
  const lock = (d.tierLocked ? `REP TIER ${ROMAN[d.tier] ?? d.tier}${d.tierName ? ` · ${d.tierName.toUpperCase()}` : ""}` : `COMPLETE ${d.requires} FIRST`)
    + (member && d.earns != null ? ` · WITH THE CREW +${d.earns} REP` : "");
  return <button role="option" aria-selected={selected} aria-disabled={d.locked}
    className={`mission-row is-${tone}${selected ? " is-selected" : ""}${d.locked ? " is-locked" : ""}`} onClick={onSelect} onDoubleClick={onOpen}>
    <div className="mission-row__name"><span className="mission-chip">{d.label}</span><strong>{d.label}</strong><p>{d.blurb}</p></div>
    <dl className="mission-row__stats">
      <div><dt>PAYOUT</dt><dd>{d.paidToday ? "PAID TODAY" : money(d.payout)}</dd></div>
      <div><dt>TIME</dt><dd>~{d.minutes} MIN</dd></div>
      <div><dt>OPERATORS</dt><dd>{d.min}-{d.max}</dd></div>
      <div><dt>UNLOCK</dt><dd>{unlock}</dd></div>
    </dl>
    <div className="mission-row__tagged">
      {d.locked ? <span className="mission-row__lock"><Icon name="lock" size={14} />{lock}</span>
        : <span><b>{d.tagged}</b>/ {d.max} TAGGED{mine && <em>YOU</em>}</span>}
      <Meter value={d.locked ? 0 : d.tagged} max={d.max} tone={tone} />
    </div>
  </button>;
}

function BoardView({ data, diff, board, mine, countdown, money, entry }: { data: MissionDialogPayload; diff: MissionDifficulty; board: MissionBoard; mine: boolean; countdown?: number; money(n: number): string; entry: MissionEntry }) {
  const tone = TONE[diff.id] ?? "standard";
  const need = Math.max(0, board.min - board.members.length), room = board.max - board.members.length;
  const status = countdown != null ? `LAUNCHING IN ${pad(countdown)}` : need > 0 ? `NEED ${need} MORE` : room > 0 ? `READY · ${room} OPEN` : "FULL";
  const squads = useMemo(() => { const ids = [...new Set(board.members.map(m => m.squad).filter(Boolean))]; return new Map(ids.map((s, i) => [s, i])); }, [board.members]);
  return <section className={`mission__board is-${tone}`}>
    <div className="mission__board-head">
      <h2 className="mission__step">02 · BOARD</h2>
      <h1 id="mission-title" className="mission__title mission__title--small">{data.point.title}</h1>
      <span className="mission-chip">{diff.label}</span>
      <i className="mission__rule" />
      {board.host && <span className="mission__host"><Icon name="crown" size={13} />HOST · {initials(board.host).toUpperCase()}</span>}
    </div>
    <dl className="mission__stats">
      <div><dt><Icon name="banknote" size={12} />PAYOUT</dt><dd>{money(diff.payout)}{diff.paidToday ? " · PAID TODAY" : ""}</dd></div>
      <div><dt><Icon name="timer" size={12} />TIME</dt><dd>~{diff.minutes} MIN</dd></div>
      <div><dt><Icon name="users" size={12} />OPERATORS</dt><dd>{diff.min}-{diff.max}</dd></div>
      <div><dt><Icon name="shield" size={12} />COMPLETED</dt><dd>{diff.cleared ?? 0}×</dd></div>
    </dl>
    <div className={`mission__count${countdown != null ? " is-countdown" : ""}`}>
      <span className="mission__count-big"><b>{board.members.length}</b>/{board.max}</span>
      <span className="mission__count-status">{status}</span>
      <Meter value={board.members.length} max={board.max} tone={tone} />
    </div>
    <div className="mission__slots" style={{ "--cols": Math.min(board.max, 4) } as CSSProperties}>
      {Array.from({ length: board.max }, (_, i) => {
        const m = board.members[i];
        const squad = m?.squad ? squads.get(m.squad) : undefined;
        return <div key={i} className={`mission-slot${m ? " is-taken" : ""}${m?.id === data.me.id ? " is-me" : ""}${squad != null ? ` squad-${squad % 3}` : ""}`}>
          <span className="mission-slot__index">{pad(i + 1)}{m?.host && <Icon name="crown" size={12} />}{squad != null && <i className="mission-slot__squad" title="Tagged in as a crew" />}</span>
          {m ? <><strong>{initials(m.name).toUpperCase()}</strong><small>#{m.citizen} · TIER {m.tier}{m.id === data.me.id ? " · YOU" : ""}</small></>
            : <span className="mission-slot__open"><Icon name="plus" size={12} />OPEN</span>}
        </div>;
      })}
    </div>
    {!mine && (!diff.locked || !entry.leads) && <p className="mission__hint">{entryHint(entry, diff)}</p>}
    {mine && countdown == null && <p className="mission__hint">You are tagged. Stay near the mission point: walking away untags you.
      {entry.open ? " Matchmaking fills the empty places." : board.members.length < board.min ? ` This board takes your crew only: ${diff.label} needs ${board.min}. Grow the crew, or turn matchmaking on (M).` : ""}
      {entry.open && board.members[0]?.id === data.me.id && board.members.length >= board.min ? " As host you can launch now with the operators on board." : ""}</p>}
  </section>;
}

/* What happens when this player tags in, in one or two sentences. */
function entryHint(entry: MissionEntry, diff: MissionDifficulty): string {
  if (!entry.leads) {
    const lead = `${entry.leader ?? "Your crew leader"} tags the crew in: you enter together. Leave the crew (Q) to go solo.`;
    if (!diff.locked) return lead;
    // below what this member has unlocked: they still play it in full, for their own reward
    const why = diff.tierLocked ? "is above your street cred" : `is not open to you yet (complete ${diff.requires} first)`;
    const earns = diff.earnsAs ? `the ${diff.earnsAs} reward (+${diff.earns ?? 0} REP)` : diff.earns ? `+${diff.earns} REP` : "no reputation";
    return `${lead} ${diff.label} ${why}: with the crew you still play it, and earn ${earns}.`;
  }
  const who = entry.size > 1 ? `Your crew of ${entry.size}` : "You";
  if (entry.matchmaking) return `Matchmaking on: ${entry.size > 1 ? "your crew joins" : "you join"} the fullest open board with room, and solo players fill the empty places.`;
  const open = diff.openLobbies ? `${diff.openLobbies} open board${diff.openLobbies > 1 ? "s" : ""} here ${diff.openLobbies > 1 ? "are" : "is"} looking for operators` : "";
  if (entry.size < diff.min) return `${diff.label} needs ${diff.min} operators. Invite players to your crew (Q, or ALT + click a player), or turn matchmaking on (M)${open ? `: ${open}` : ""}.`;
  return `${who} enter${entry.size > 1 ? "s" : ""} alone: nobody else joins, and the launch starts as soon as you tag in.${open ? ` ${open}: turn matchmaking on (M) to join.` : ""}`;
}

function SquadDrawer({ data, party, entry, onToggle, onClose }: { data: MissionDialogPayload; party?: PartyState; entry: MissionEntry; onToggle(): void; onClose(): void }) {
  const leader = !!party?.id && party.leader === data.me.id;
  const full = (party?.members?.length ?? 1) >= (party?.maxSize ?? 8);
  return <aside className="mission-squad" aria-label="Crew">
    <header><h3><Icon name="users" size={15} />CREW</h3><button onClick={onClose} aria-label="Close the crew panel"><Icon name="x" size={14} /><kbd>Q</kbd></button></header>
    {!!party?.invites?.length && <section><h4>INVITES</h4>{party.invites.map(inv => <div key={inv.party} className="mission-squad__row is-invite">
      <span><Icon name="user-plus" size={13} />{inv.fromName}<small>wants you in their crew</small></span>
      <span><button className="mission-squad__btn is-yes" onClick={() => sendAction({ type: "party.accept", party: inv.party })}>ACCEPT</button>
        <button className="mission-squad__btn" onClick={() => sendAction({ type: "party.decline", party: inv.party })}>DECLINE</button></span></div>)}</section>}
    <section><h4>MEMBERS {party?.members ? `${party.members.length}/${party.maxSize}` : ""}</h4>
      {party?.members ? party.members.map(m => <div key={m.id} className="mission-squad__row">
        <span>{m.leader ? <Icon name="crown" size={13} /> : <Icon name="user" size={13} />}{m.name}<small>TIER {m.tier}{m.id === data.me.id ? " · YOU" : ""}</small></span>
        {leader && m.id !== data.me.id && <span>
          <button className="mission-squad__btn" title="Make crew leader" onClick={() => sendAction({ type: "party.promote", target: m.id })}><Icon name="crown" size={12} /></button>
          <button className="mission-squad__btn is-no" title="Kick from crew" onClick={() => sendAction({ type: "party.kick", target: m.id })}><Icon name="user-minus" size={12} /></button></span>}
      </div>) : <p className="mission-squad__empty">No crew: you play solo. Invite the players around you (or ALT + click one): they accept with the prompt keys, F1 &gt; Crew or /crew accept.</p>}
      {!!party?.pending?.length && party.pending.map(p => <div key={p.id} className="mission-squad__row is-pending"><span><Icon name="loader" size={13} />{p.name}<small>invited</small></span></div>)}
      {party?.members && <button className="mission-squad__leave" onClick={() => sendAction({ type: "party.leave" })}><Icon name="log-out" size={13} />{squadOf(party) > 1 ? "LEAVE CREW" : "WITHDRAW INVITES"}</button>}
    </section>
    <section><h4>MATCHMAKING</h4>
      <div className="mission-squad__row">
        <span><Icon name={entry.matchmaking ? "globe" : "lock"} size={13} />{entry.matchmaking ? "OPEN TO MATCHMAKING" : entry.size > 1 ? "CREW ONLY" : "MATCHMAKING OFF"}
          <small>{entry.matchmaking ? "solo players fill the empty places" : entry.size > 1 ? "nobody else joins your missions" : "you only enter alone"}</small></span>
        {entry.leads && <button className="mission-squad__btn is-yes" onClick={onToggle}>{entry.matchmaking ? "CLOSE" : "OPEN"}</button>}
      </div>
    </section>
    <section><h4>NEARBY</h4>
      {data.nearby.length ? data.nearby.map(p => <div key={p.id} className="mission-squad__row">
        <span><Icon name="user" size={13} />{p.name}<small>#{p.citizen} · TIER {p.tier}{p.mine ? " · IN YOUR CREW" : p.inSquad ? " · IN A CREW" : ""}</small></span>
        {!p.mine && <button className="mission-squad__btn is-yes" disabled={p.inSquad || p.invited || full || (!!party?.id && !leader)}
          onClick={() => sendAction({ type: "party.invite", target: p.id })}>{p.invited ? "INVITED" : "INVITE"}</button>}
      </div>) : <p className="mission-squad__empty">Nobody around. Players within 15 m of you show up here.</p>}
    </section>
  </aside>;
}
const squadOf = (party?: PartyState) => party?.members?.length ?? 0;
