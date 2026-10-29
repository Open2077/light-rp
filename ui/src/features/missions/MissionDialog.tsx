import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type MissionBoard, type MissionDialogPayload, type MissionDifficulty, type MissionUpdate, type PartyState } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { normalizeMission } from "./model";
import "./mission.css";

/* The mission point (The Division style): 01 choose a difficulty, 02 its board.
   Tag in alone (E) or with your squad (G, leader only); strangers fill the empty
   seats; a full board (or the host, R, with the minimum) starts the countdown.
   The squad drawer (Q) invites the players around and manages the squad. Every
   change comes back from the server (lightrp:ui:mission), nothing is assumed. */

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
  const countdown = board.state === "countdown" && board.countdownMs != null ? Math.max(0, Math.ceil((board.countdownMs - (performance.now() - received)) / 1000)) : undefined;
  const hostCanLaunch = !!mine?.host && board.state === "open" && board.members.length >= board.min;

  const session = data.session;
  const close = () => { sendAction({ type: "mission.close", session }); onClose(); };
  const tag = () => { if (mine) sendAction({ type: "mission.untag", session }); else if (!diff.locked) sendAction({ type: "mission.tag", session, difficulty: diff.id }); };
  const tagGroup = () => { if (!diff.locked && leader && !mine) sendAction({ type: "mission.tagGroup", session, difficulty: diff.id }); };
  const launch = () => { if (hostCanLaunch) sendAction({ type: "mission.launch", session }); };
  const openBoard = () => { if (!diff.locked) setView("board"); };
  const move = (step: number) => {
    const list = data.difficulties;
    const at = list.findIndex(d => d.id === selected);
    setSelected(list[(at + step + list.length) % list.length]!.id);
  };

  const withNames = (party?.members ?? []).filter(m => m.id !== data.me.id).map(m => initials(m.name).toUpperCase());
  const identity = `${initials(data.me.name).toUpperCase()} · #${data.me.citizen} · REP ${data.me.reputation}${withNames.length ? ` · WITH ${withNames.join(", ")}` : ""}`;

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
        if (k === "Backspace") setView("difficulty"); else if (k === "e") tag(); else if (k === "g") tagGroup(); else if (k === "r") launch(); else handled = false;
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
          onSelect={() => setSelected(d.id)} onOpen={() => { setSelected(d.id); if (!d.locked) setView("board"); }} />)}
      </div>
    </section> : <BoardView data={data} diff={diff} board={board} mine={!!mine} countdown={countdown} money={money} />}

    <footer className="mission__foot">
      <span className="mission__identity">{identity}</span>
      <div className="mission__keys">
        <button className="mission__key mission__key--ghost" onClick={() => setSquadOpen(v => !v)}>
          <Icon name="users" size={14} />SQUAD {party?.members ? `${squadSize}/${party.maxSize}` : ""}<kbd>Q</kbd>
          {!!party?.invites?.length && <i className="mission__badge">{party.invites.length}</i>}
        </button>
        {view === "difficulty" ? <>
          <button className="mission__key mission__key--ghost" onClick={close}>CLOSE<kbd>ESC</kbd></button>
          <button className="mission__key mission__key--primary" disabled={diff.locked} onClick={openBoard}><Icon name="chevron-right" size={15} />OPEN BOARD<kbd>⏎</kbd></button>
        </> : <>
          <button className="mission__key mission__key--ghost" onClick={() => setView("difficulty")}><Icon name="undo-2" size={14} />DIFFICULTY<kbd>BKSP</kbd></button>
          {hostCanLaunch && <button className="mission__key mission__key--launch" onClick={launch}><Icon name="swords" size={14} />LAUNCH NOW<kbd>R</kbd></button>}
          <button className="mission__key mission__key--group" disabled={!leader || !!mine || diff.locked}
            title={!party?.id ? "Invite players to your squad first (Q)." : !leader ? "Only the squad leader tags the squad in." : `Tag your squad of ${squadSize} in.`}
            onClick={tagGroup}><Icon name="users" size={14} />TAG GROUP<kbd>G</kbd></button>
          <button className={`mission__key ${mine ? "mission__key--leave" : "mission__key--primary"}`} disabled={!mine && diff.locked} onClick={tag}>
            <Icon name={mine ? "log-out" : "plus"} size={14} />{mine ? "LEAVE" : "TAG IN"}<kbd>E</kbd></button>
        </>}
      </div>
    </footer>
    {squadOpen && <SquadDrawer data={data} party={party} onClose={() => setSquadOpen(false)} />}
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

function DifficultyRow({ d, selected, mine, money, onSelect, onOpen }: { d: MissionDifficulty; selected: boolean; mine: boolean; money(n: number): string; onSelect(): void; onOpen(): void }) {
  const tone = TONE[d.id] ?? "standard";
  return <button role="option" aria-selected={selected} aria-disabled={d.locked}
    className={`mission-row is-${tone}${selected ? " is-selected" : ""}${d.locked ? " is-locked" : ""}`} onClick={onSelect} onDoubleClick={onOpen}>
    <div className="mission-row__name"><span className="mission-chip">{d.label}</span><strong>{d.label}</strong><p>{d.blurb}</p></div>
    <dl className="mission-row__stats">
      <div><dt>PAYOUT</dt><dd>{money(d.payout)}</dd></div>
      <div><dt>TIME</dt><dd>~{d.minutes} MIN</dd></div>
      <div><dt>OPERATORS</dt><dd>{d.min}-{d.max}</dd></div>
      <div><dt>UNLOCK</dt><dd>{d.requires ? `CLEAR ${d.requires}` : "OPEN"}</dd></div>
    </dl>
    <div className="mission-row__tagged">
      {d.locked ? <span className="mission-row__lock"><Icon name="lock" size={14} />COMPLETE {d.requires} FIRST</span>
        : <span><b>{d.tagged}</b>/ {d.max} TAGGED{mine && <em>YOU</em>}</span>}
      <Meter value={d.locked ? 0 : d.tagged} max={d.max} tone={tone} />
    </div>
  </button>;
}

function BoardView({ data, diff, board, mine, countdown, money }: { data: MissionDialogPayload; diff: MissionDifficulty; board: MissionBoard; mine: boolean; countdown?: number; money(n: number): string }) {
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
      <div><dt><Icon name="banknote" size={12} />PAYOUT</dt><dd>{money(diff.payout)}</dd></div>
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
          <span className="mission-slot__index">{pad(i + 1)}{m?.host && <Icon name="crown" size={12} />}{squad != null && <i className="mission-slot__squad" title="Tagged in as a squad" />}</span>
          {m ? <><strong>{initials(m.name).toUpperCase()}</strong><small>#{m.citizen} · TIER {m.tier}{m.id === data.me.id ? " · YOU" : ""}</small></>
            : <span className="mission-slot__open"><Icon name="plus" size={12} />OPEN</span>}
        </div>;
      })}
    </div>
    {!mine && !diff.locked && <p className="mission__hint">Tag in alone and the board fills you with other operators, or tag your squad: its empty seats are matched with players at this point.</p>}
    {mine && countdown == null && <p className="mission__hint">You are tagged. Stay near the mission point: walking away untags you.{board.members[0]?.id === data.me.id && board.members.length >= board.min ? " As host you can launch now with the operators on board." : ""}</p>}
  </section>;
}

function SquadDrawer({ data, party, onClose }: { data: MissionDialogPayload; party?: PartyState; onClose(): void }) {
  const leader = !!party?.id && party.leader === data.me.id;
  const full = (party?.members?.length ?? 1) >= (party?.maxSize ?? 8);
  return <aside className="mission-squad" aria-label="Squad">
    <header><h3><Icon name="users" size={15} />SQUAD</h3><button onClick={onClose} aria-label="Close the squad panel"><Icon name="x" size={14} /><kbd>Q</kbd></button></header>
    {!!party?.invites?.length && <section><h4>INVITES</h4>{party.invites.map(inv => <div key={inv.party} className="mission-squad__row is-invite">
      <span><Icon name="user-plus" size={13} />{inv.fromName}<small>wants you in their squad</small></span>
      <span><button className="mission-squad__btn is-yes" onClick={() => sendAction({ type: "party.accept", party: inv.party })}>ACCEPT</button>
        <button className="mission-squad__btn" onClick={() => sendAction({ type: "party.decline", party: inv.party })}>DECLINE</button></span></div>)}</section>}
    <section><h4>MEMBERS {party?.members ? `${party.members.length}/${party.maxSize}` : ""}</h4>
      {party?.members ? party.members.map(m => <div key={m.id} className="mission-squad__row">
        <span>{m.leader ? <Icon name="crown" size={13} /> : <Icon name="user" size={13} />}{m.name}<small>TIER {m.tier}{m.id === data.me.id ? " · YOU" : ""}</small></span>
        {leader && m.id !== data.me.id && <span>
          <button className="mission-squad__btn" title="Hand the lead over" onClick={() => sendAction({ type: "party.promote", target: m.id })}><Icon name="crown" size={12} /></button>
          <button className="mission-squad__btn is-no" title="Remove from the squad" onClick={() => sendAction({ type: "party.kick", target: m.id })}><Icon name="user-minus" size={12} /></button></span>}
      </div>) : <p className="mission-squad__empty">No squad. Invite the players around you: they accept here or with /party accept.</p>}
      {!!party?.pending?.length && party.pending.map(p => <div key={p.id} className="mission-squad__row is-pending"><span><Icon name="loader" size={13} />{p.name}<small>invited</small></span></div>)}
      {party?.members && <button className="mission-squad__leave" onClick={() => sendAction({ type: "party.leave" })}><Icon name="log-out" size={13} />LEAVE SQUAD</button>}
    </section>
    <section><h4>NEARBY</h4>
      {data.nearby.length ? data.nearby.map(p => <div key={p.id} className="mission-squad__row">
        <span><Icon name="user" size={13} />{p.name}<small>#{p.citizen} · TIER {p.tier}{p.mine ? " · IN YOUR SQUAD" : p.inSquad ? " · IN A SQUAD" : ""}</small></span>
        {!p.mine && <button className="mission-squad__btn is-yes" disabled={p.inSquad || p.invited || full || (!!party?.id && !leader)}
          onClick={() => sendAction({ type: "party.invite", target: p.id })}>{p.invited ? "INVITED" : "INVITE"}</button>}
      </div>) : <p className="mission-squad__empty">Nobody around. Players within 15 m of you show up here.</p>}
    </section>
  </aside>;
}
