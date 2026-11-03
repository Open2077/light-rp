import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type DailiesState, type DailiesTab, type DailyCard, type TitleEntry, type TitlesState, type UiAction } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Keycap, Tabs, cx } from "@/design/components";
import {
  RARITY_LABEL, SLOT_META, cardState, countdown, earnedCount, expiryLabel, hiddenNote, initials, normalizeDailiesDialog,
  progressLabel, progressRatio, shownTitle, streakLine, titleSections, titleStatus, toClaim,
} from "./model";
import "./rarity.css";
import "./dailies.css";

/* Dailies (server/modules/dailies.lua) and titles (titles.lua): F1 > Dailies, or
   F1 > Identity > Title; the activities terminal shows the same Today page in its
   Dailies tab (DailiesToday below). Today: four dailies, written by the fixer who
   orders them, and the weekly, each with what the server checks, the progress, the
   pay and one claim. Titles: what others read after your name, every title and how
   to earn it. The page only shows and asks: the server checks every daily and pays
   every claim. Esc, a right-click or the close button closes it; ← → change tab. */

const SWAP_ARM_MS = 3500;   // the swap asks twice: the progress of the replaced contract is lost
const ANSWER_MS = 9000;     // no answer by then: say so and unlock

export function DailiesDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "dailies";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "dailies", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "dailies") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "dailies", open: false }); };
  }, [visible, closeDialog]);
  const payload = useMemo(() => (visible ? normalizeDailiesDialog(dialog) : undefined), [visible, dialog]);
  if (!payload) return null;
  return <DailiesBody key={payload.tab} initialTab={payload.tab} onClose={closeDialog} />;
}

/** One request at a time, cleared by its answer (the server drops a second action of a type within 250 ms). */
function useRequest() {
  const result = useStore((s) => s.lastResult);
  const [pending, setPending] = useState<{ type: string; key: string } | null>(null);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean } | null>(null);
  const before = useRef(result);
  useEffect(() => {
    if (!pending || !result || result === before.current || result.action !== pending.type) return;
    before.current = result; setPending(null);
    setFeedback({ text: result.text, error: !result.ok });
  }, [result, pending]);
  useEffect(() => {
    if (!pending) return;
    const t = window.setTimeout(() => { setPending(null); setFeedback({ text: "No answer from the server yet. Check the list before trying again.", error: true }); }, ANSWER_MS);
    return () => window.clearTimeout(t);
  }, [pending]);
  const send = useCallback((action: UiAction, key: string) => {
    if (pending) return;
    before.current = useStore.getState().lastResult;
    setPending({ type: action.type, key }); setFeedback(null); sendAction(action);
  }, [pending]);
  return { pending, feedback, send };
}

/** A countdown pushed by the server, counted down locally. */
function useLeft(ms: number | undefined, stamp: unknown): number | undefined {
  const [base, setBase] = useState(() => ({ at: Date.now(), ms }));
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => { setBase({ at: Date.now(), ms }); }, [ms, stamp]);
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(t); }, []);
  return base.ms === undefined ? undefined : Math.max(0, base.ms - (now - base.at));
}

function DailiesBody({ initialTab, onClose }: { initialTab: DailiesTab; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const dailies = useStore((s) => s.state.dailies);
  const titles = useStore((s) => s.state.titles);
  const character = useStore((s) => s.state.character);
  const currency = useStore((s) => s.state.money.currency);
  const [tab, setTab] = useState<DailiesTab>(initialTab);
  const request = useRequest();
  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      let handled = true;
      if (e.key === "Escape") { if (!e.repeat) onClose(); }
      else if (e.key === "ArrowRight" || e.key === "ArrowLeft") setTab((t) => (t === "today" ? "titles" : "today"));
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  }, [onClose]);

  const claim = toClaim(dailies);
  const tabs = useMemo(() => [
    { value: "today" as const, label: "TODAY", icon: "list-checks", count: claim > 0 ? claim : undefined },
    { value: "titles" as const, label: "TITLES", icon: "crown", count: titles?.enabled ? `${earnedCount(titles)}/${titles.list.length}` : undefined },
  ], [claim, titles]);
  const name = `${character.firstName ?? ""} ${character.lastName ?? ""}`.trim() || character.accountName || "You";
  const fmt = (n: number) => formatMoney(n, currency);

  return <div className="dailies o77-interactive" role="dialog" aria-modal="true" aria-labelledby="dailies-title" ref={root} tabIndex={-1}>
    <header className="dailies__bar">
      <span className="dailies__bar-title" id="dailies-title"><Icon name="list-checks" size={15} />DAILIES</span>
      <span className="dailies__bar-route">MAMA OKORO · LEDGER · NIX<button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>
    <div className="dailies__tabs"><Tabs items={tabs} value={tab} onChange={setTab} /></div>

    {tab === "today"
      ? <TodayPage d={dailies} fmt={fmt} request={request} />
      : <TitlesPage t={titles} name={name} request={request} />}

    <footer className="dailies__foot">
      <span className={cx("dailies__feedback", request.feedback?.error && "is-error")} role={request.feedback?.error ? "alert" : "status"}>
        {request.pending ? "WAITING FOR THE SERVER…" : request.feedback ? request.feedback.text : tab === "today"
          ? "PAID INTO YOUR BANK · PROGRESS COUNTS ONCE PER ACCOUNT"
          : "SHOWN IN THE RP CHAT, ON YOUR CREW'S FRAME AND IN THE HALL OF FAME"}
      </span>
      <span className="dailies__keys">
        <span><Keycap size="sm">← →</Keycap>TABS</span>
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>
  </div>;
}

type Request = ReturnType<typeof useRequest>;

/** The activities terminal's Dailies tab: the Today page and its claims, on the same
 *  `dailies` state as F1 > Dailies (a claim in one shows in the other on the next push). */
export function DailiesToday() {
  const dailies = useStore((s) => s.state.dailies);
  const currency = useStore((s) => s.state.money.currency);
  const request = useRequest();
  useEffect(() => { sendAction({ type: "dailies.refresh" }); }, []);
  const fmt = (n: number) => formatMoney(n, currency);
  return <div className="dailies-embed">
    <TodayPage d={dailies} fmt={fmt} request={request} />
    <p className={cx("dailies__feedback dailies-embed__feedback", request.feedback?.error && "is-error")} role={request.feedback?.error ? "alert" : "status"}>
      {request.pending ? "WAITING FOR THE SERVER…" : request.feedback ? request.feedback.text : "PAID INTO YOUR BANK · THE SAME LIST AS F1 › DAILIES"}
    </p>
  </div>;
}

/* ── Today ── */

function TodayPage({ d, fmt, request }: { d?: DailiesState; fmt(n: number): string; request: Request }) {
  const reset = useLeft(d?.resetInMs, d);
  const weekReset = useLeft(d?.weekResetInMs, d);
  const [armed, setArmed] = useState<string | null>(null);
  useEffect(() => {
    if (!armed) return;
    const t = window.setTimeout(() => setArmed(null), SWAP_ARM_MS);
    return () => window.clearTimeout(t);
  }, [armed]);

  if (!d) return <p className="dailies__empty"><Icon name="loader" size={14} />Reading today's dailies…</p>;
  if (!d.enabled) return <p className="dailies__empty"><Icon name="lock" size={14} />Dailies are paused right now. Progress you made is kept.</p>;
  if (!d.ready) return <p className="dailies__empty"><Icon name="loader" size={14} />Load your character to see today's dailies.</p>;

  const daily = d.list.filter((c) => c.slot !== "weekly");
  const weekly = d.list.find((c) => c.slot === "weekly");
  const spent = d.budget.max > 0 ? Math.min(1, d.budget.used / d.budget.max) : 0;
  const claimCard = (c: { id: string }) => request.send({ type: "dailies.claim", id: c.id }, c.id);
  const swap = (c: DailyCard) => {
    if (armed !== c.slot) { setArmed(c.slot); return; }
    setArmed(null); request.send({ type: "dailies.swap", slot: c.slot }, c.slot);
  };

  return <div className="dailies__page">
    <section className="dailies__strip" aria-label="Today">
      <div className="dailies-stat">
        <Icon name="clock" size={15} />
        <span><small>NEW DAILIES IN</small><b>{reset === undefined ? "—" : reset > 0 ? countdown(reset) : "ANY SECOND"}</b></span>
      </div>
      <div className={cx("dailies-stat", d.streak > 0 && "is-lit")}>
        <Icon name="flame" size={15} />
        <span><small>STREAK</small><b>{streakLine(d.streak)}</b></span>
      </div>
      <div className="dailies-stat is-budget">
        <Icon name="coins" size={15} />
        <span><small>PAID TODAY</small><b>{fmt(d.budget.used)}{d.budget.max > 0 && <em> / {fmt(d.budget.max)}</em>}</b>
          {d.budget.max > 0 && <i className="dailies-stat__bar" aria-hidden><i style={{ width: `${spent * 100}%` }} /></i>}</span>
      </div>
      <div className={cx("dailies-stat", d.swapsLeft === 0 && "is-dim")}>
        <Icon name="undo-2" size={15} />
        <span><small>FREE SWAP</small><b>{d.swapsLeft > 0 ? `${d.swapsLeft} LEFT` : "USED"}</b></span>
      </div>
    </section>

    <div className="dailies__main">
      <section className="dailies__grid" aria-label="Today's dailies">
        {daily.map((c) => <ContractCard key={c.id} card={c} d={d} fmt={fmt} request={request}
          armed={armed === c.slot} onClaim={() => claimCard(c)} onSwap={() => swap(c)} />)}
        {daily.length === 0 && <p className="dailies__empty">No daily today: none of their sources is running on this server.</p>}
      </section>

      <aside className="dailies__rail">
        {weekly ? <ContractCard card={weekly} d={d} fmt={fmt} request={request} weekly onClaim={() => claimCard(weekly)}
          ends={weekReset === undefined ? undefined : countdown(weekReset)} />
          : <p className="dailies__note">No weekly this week.</p>}
        {d.older.length > 0 && <section className="dailies-older" aria-label="Unpaid">
          <header><Icon name="triangle-alert" size={13} />FINISHED, NOT PAID YET</header>
          <ul>{d.older.map((o) => <li key={o.id}>
            <span>{o.title}</span>
            <Button size="sm" icon={request.pending?.key === o.id ? "loader" : "coins"} disabled={!!request.pending} onClick={() => claimCard(o)}>
              {fmt(o.reward)}
            </Button>
          </li>)}</ul>
          <small>Finished on an earlier day: claim them before they expire.</small>
        </section>}
        <p className="dailies__note">
          Street, Action and Crew are the city's dailies when enough people are on; on a quiet server you get one you can do alone.
          Shift follows your job. Resets at 00:00 UTC, the weekly on Monday. Missed a day? The streak starts again.
        </p>
      </aside>
    </div>
  </div>;
}

function ContractCard({ card, d, fmt, request, weekly, armed, ends, onClaim, onSwap }: {
  card: DailyCard; d: DailiesState; fmt(n: number): string; request: Request; weekly?: boolean; armed?: boolean; ends?: string;
  onClaim(): void; onSwap?(): void;
}) {
  const meta = SLOT_META[card.slot];
  const state = cardState(card, d.budget);
  const busy = request.pending?.key === card.id || request.pending?.key === card.slot;
  if (state === "locked") return <article className="contract is-locked" aria-label={`${meta.label}: waiting for a crewmate`}>
    <header className="contract__head">
      <span className="contract__slot"><Icon name={meta.icon} size={12} />{meta.label}</span>
      <span className="contract__reward">{fmt(card.reward)}</span>
    </header>
    <h3 className="contract__title">Crew daily</h3>
    <p className="contract__locked"><Icon name="users" size={16} />
      <span>Shows up when a crewmate is online. Make or join a crew: F1 › Crew, or ALT + click a player.</span></p>
  </article>;
  return <article className={cx("contract", `is-${state}`, weekly && "is-weekly")} aria-label={`${meta.label}: ${card.title}`}>
    <header className="contract__head">
      <span className="contract__slot"><Icon name={meta.icon} size={12} />{meta.label}</span>
      {card.social && card.slot !== "crew" && <Badge tone="outline" title="Done with other players: handed out when enough people are on the server.">WITH OTHERS</Badge>}
      {ends && <small className="contract__ends">ENDS IN {ends}</small>}
      <span className="contract__reward">{fmt(card.reward)}</span>
    </header>
    <h3 className="contract__title">{card.title}</h3>
    <div className="contract__msg">
      <span className="contract__avatar" aria-hidden>{initials(card.fixerName)}</span>
      <div className="contract__bubble"><b>{card.fixerName}</b><p>{card.brief}</p></div>
    </div>
    <p className="contract__goal"><span>THE JOB</span>{card.goal}</p>
    <div className="contract__progress">
      <i className="contract__bar" role="progressbar" aria-label="Progress" aria-valuenow={Math.round(progressRatio(card) * 100)} aria-valuemin={0} aria-valuemax={100}>
        <i style={{ width: `${progressRatio(card) * 100}%` }} />
      </i>
      <span>{progressLabel(card)}</span>
    </div>
    <footer className="contract__foot">
      {state === "claimable" && <Button size="sm" icon={busy ? "loader" : "coins"} disabled={!!request.pending} onClick={onClaim}>
        {busy ? "PAYING…" : `CLAIM ${fmt(card.reward)}`}</Button>}
      {state === "budget" && <span className="contract__note is-warn"><Icon name="lock" size={12} />Today's dailies budget is spent. Resets at 00:00 UTC.</span>}
      {state === "crew" && <span className="contract__note"><Icon name="users" size={12} />Needs a crewmate: F1 › Crew.</span>}
      {state === "progress" && card.slot === "weekly" && <span className="contract__note">Outside the daily budget.</span>}
      {card.swappable && onSwap && state !== "claimed" && <button className={cx("contract__swap", armed && "is-armed")} disabled={!!request.pending} onClick={onSwap}>
        {busy ? "SWAPPING…" : armed ? "SURE? ITS PROGRESS IS LOST" : "SWAP · FREE"}<Icon name="undo-2" size={12} /></button>}
    </footer>
    {state === "claimed" && <span className="contract__stamp">PAID</span>}
  </article>;
}

/* ── Titles ── */

function TitlesPage({ t, name, request }: { t?: TitlesState; name: string; request: Request }) {
  const sections = useMemo(() => (t ? titleSections(t) : []), [t]);
  if (!t) return <p className="dailies__empty"><Icon name="loader" size={14} />Reading your titles…</p>;
  if (!t.enabled) return <p className="dailies__empty"><Icon name="lock" size={14} />Titles are switched off on this server.</p>;
  const shown = shownTitle(t);
  const hidden = hiddenNote(t);
  const select = (id: string) => request.send({ type: "titles.select", id }, `title:${id}`);

  return <div className="dailies__page">
    <section className="titles-plate" aria-label="Your title">
      <div className="titles-plate__read">
        <small>OTHERS READ</small>
        <strong>{name}{shown && <><i aria-hidden>·</i><span className={cx("title-rarity", `is-${shown.rarity}`)}>{shown.label}</span></>}</strong>
        <p>{shown ? "Next to your name in the RP chat, on your crew's frame and on the Hall of Fame boards."
          : hidden ?? "No title for now. Pick one you earned below."}</p>
      </div>
      <div className="titles-plate__side">
        <span className="titles-plate__count"><b>{earnedCount(t)}</b>/{t.list.length} EARNED</span>
        {(t.chosen || t.shown) && <Button size="sm" variant="secondary" icon="eye" disabled={!!request.pending} onClick={() => select("none")}>HIDE MY TITLE</Button>}
      </div>
    </section>
    <div className="titles-groups">
      {sections.map((s) => <section key={s.id} className="titles-group" aria-label={s.label}>
        <header><span>{s.label.toUpperCase()}</span><small>{s.earned}/{s.items.length}</small></header>
        <ul>{s.items.map((e) => <TitleRow key={e.id} entry={e} t={t} request={request} onSelect={() => select(e.id)} />)}</ul>
      </section>)}
      {sections.length === 0 && <p className="dailies__empty">No title can be earned on this server yet.</p>}
    </div>
  </div>;
}

function TitleRow({ entry: e, t, request, onSelect }: { entry: TitleEntry; t: TitlesState; request: Request; onSelect(): void }) {
  const status = titleStatus(e, t);
  const busy = request.pending?.key === `title:${e.id}`;
  return <li className={cx("title-row", `is-${status}`)}>
    <span className={cx("title-row__gem title-rarity", `is-${e.rarity}`)} aria-hidden />
    <span className="title-row__main">
      <b className={cx("title-rarity", `is-${e.rarity}`)}>{e.label}</b>
      <small><em>{RARITY_LABEL[e.rarity]}</em>{e.how}</small>
      {e.count !== undefined && !e.earned && <span className="title-row__progress">
        <i aria-hidden><i style={{ width: `${Math.min(1, (e.value ?? 0) / Math.max(1, e.count)) * 100}%` }} /></i><em>{e.value ?? 0}/{e.count}</em>
      </span>}
    </span>
    <span className="title-row__side">
      {e.earned && e.expiresInMs !== undefined && <small className="title-row__ends">{expiryLabel(e.expiresInMs)}</small>}
      {status === "shown" && <Badge tone="accent">SHOWN</Badge>}
      {status === "hidden" && <Badge tone="outline">CHOSEN · HIDDEN</Badge>}
      {status === "earned" && <Button size="sm" variant="secondary" icon={busy ? "loader" : undefined} disabled={!!request.pending} onClick={onSelect}>SHOW</Button>}
      {status === "live" && <span className="title-row__lock"><Icon name="crown" size={12} />RANK 1 ONLY</span>}
      {status === "locked" && <span className="title-row__lock"><Icon name="lock" size={12} /></span>}
    </span>
  </li>;
}
