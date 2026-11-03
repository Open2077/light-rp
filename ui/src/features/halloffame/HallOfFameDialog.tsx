import { useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type HallOfFameBoard, type HallOfFameDialogPayload, type HallOfFameRow, type HallOfFameTab } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Keycap, Tabs, cx } from "@/design/components";
import { TAB_META, formatValue, ladderLine, mineLine, normalizeHallOfFame, pinnedRank, podium, rankLabel, tied, updatedLine } from "./model";
import "./halloffame.css";

/* The Hall of Fame (server/modules/halloffame.lua): opened by the board at The
   Crossing (ALT + click on it, or E in front of it). One server answer per tab, from
   the server's cache; a tab already received this session shows at once. Podium for
   the top three, ranks 4-10 below, the viewer's own rank under each board. A board
   clicked (or Enter on it) opens its full ladder in place of the grid: the podium,
   ranks 4-50, the viewer's rank pinned under them when outside. Esc, Backspace or a
   right-click go back from a ladder; on a tab, Esc or a right-click close the panel. */

interface Page { payload: HallOfFameDialogPayload; receivedAt: number }
/** A board's ladder, opened from `from`: its card's board until the answer lands. */
interface Ladder { key: string; from: HallOfFameTab; card: HallOfFameBoard; page?: Page; refused?: string }

const computedAt = (page: Page) => page.receivedAt - (page.payload.updatedAgoS ?? 0) * 1000;

export function HallOfFameDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "halloffame";
  const close = useCallback(() => { sendAction({ type: "halloffame.close" }); closeDialog(); }, [closeDialog]);
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "halloffame", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "halloffame") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "halloffame", open: false }); };
  }, [visible, closeDialog]);
  const payload = useMemo(() => (visible ? normalizeHallOfFame(dialog) : undefined), [visible, dialog]);
  if (!payload) return null;
  return <HallOfFameBody payload={payload} onClose={close} />;
}

function HallOfFameBody({ payload, onClose }: { payload: HallOfFameDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const [tab, setTab] = useState<HallOfFameTab>(payload.tab);
  const [pages, setPages] = useState<Partial<Record<HallOfFameTab, Page>>>(() =>
    (payload.ladder ? {} : { [payload.tab]: { payload, receivedAt: Date.now() } }));
  const [ladder, setLadder] = useState<Ladder | undefined>(() => (payload.ladder
    ? { key: payload.ladder.key, from: payload.tab, card: payload.ladder, page: { payload, receivedAt: Date.now() } } : undefined));
  const [refreshing, setRefreshing] = useState(false);
  const [, tick] = useState(0);
  const returnTo = useRef<string | undefined>(undefined); // the card to focus again after its ladder

  // Every answer lands in its tab, or in the ladder that asked for it. A newer
  // computation of the boards (a REFRESH, the five-minute rebuild) makes the other
  // tabs stale: they are asked again when shown.
  useEffect(() => {
    const page: Page = { payload, receivedAt: Date.now() };
    setPages((old) => {
      const keep: Partial<Record<HallOfFameTab, Page>> = {};
      for (const [t, kept] of Object.entries(old) as Array<[HallOfFameTab, Page]>) {
        if ((payload.ladder || t !== payload.tab) && Math.abs(computedAt(kept) - computedAt(page)) < 5000) keep[t] = kept;
      }
      if (!payload.ladder) keep[payload.tab] = page;
      return keep;
    });
    const board = payload.ladder;
    if (board) setLadder((cur) => (cur && cur.key === board.key ? { ...cur, card: board, page, refused: undefined } : cur));
    setRefreshing(false);
  }, [payload]);
  useEffect(() => { const t = window.setInterval(() => tick((n) => n + 1), 1000); return () => window.clearInterval(t); }, []);
  useEffect(() => { root.current?.focus(); }, []);

  // A ladder the server refused (a board gone, wealth switched off): said in its place.
  const result = useStore((s) => s.lastResult);
  const seenResult = useRef(result);
  useEffect(() => {
    if (!result || result === seenResult.current) return;
    seenResult.current = result;
    if (result.action === "halloffame.board" && !result.ok) setLadder((cur) => (cur && !cur.page ? { ...cur, refused: result.text } : cur));
  }, [result]);

  const tabs = payload.tabs;
  const page = pages[tab];
  // A tab not received yet is asked for; once more if the first ask got no answer
  // (the server drops a second action of a type within 250 ms). Same for a ladder.
  useEffect(() => {
    if (page || ladder) return;
    const ask = () => sendAction({ type: "halloffame.tab", tab });
    ask();
    const retry = window.setTimeout(ask, 900);
    return () => window.clearTimeout(retry);
  }, [tab, page, ladder]);
  const waitingFor = ladder && !ladder.page && !ladder.refused ? ladder.key : undefined;
  const waitingFrom = ladder?.from;
  useEffect(() => {
    if (!waitingFor || !waitingFrom) return;
    const ask = () => sendAction({ type: "halloffame.board", key: waitingFor, tab: waitingFrom });
    ask();
    const retry = window.setTimeout(ask, 900);
    return () => window.clearTimeout(retry);
  }, [waitingFor, waitingFrom]);
  useEffect(() => {
    if (!refreshing) return;
    const t = window.setTimeout(() => setRefreshing(false), 8000);
    return () => window.clearTimeout(t);
  }, [refreshing]);

  // Back from a ladder: the card that opened it takes the focus again once its tab shows.
  useEffect(() => {
    const key = returnTo.current;
    if (ladder || !key) return;
    const card = root.current?.querySelector<HTMLElement>(`[data-board="${CSS.escape(key)}"]`);
    if (card) { returnTo.current = undefined; card.focus(); }
  }, [ladder, pages, tab]);

  const openLadder = useCallback((board: HallOfFameBoard) => {
    returnTo.current = undefined;
    setLadder({ key: board.key, from: tab, card: board });
  }, [tab]);
  const back = useCallback(() => {
    if (!ladder) return;
    returnTo.current = ladder.key;
    setTab(ladder.from);
    setLadder(undefined);
  }, [ladder]);
  const pickTab = useCallback((next: HallOfFameTab) => { setLadder(undefined); setTab(next); }, []);
  const move = useCallback((step: number) => {
    setLadder(undefined);
    setTab((current) => {
      const at = Math.max(0, tabs.indexOf(current));
      return tabs[(at + step + tabs.length) % tabs.length] ?? current;
    });
  }, [tabs]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement | null)?.tagName === "INPUT") return;
      let handled = true;
      if (e.key === "Escape") { if (!e.repeat) { if (ladder) back(); else onClose(); } }
      else if (e.key === "Backspace" && ladder) { if (!e.repeat) back(); }
      else if (e.key === "ArrowRight") move(1);
      else if (e.key === "ArrowLeft") move(-1);
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); if (ladder) back(); else onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  }, [onClose, move, back, ladder]);

  // The strip reads the answer on screen: the ladder's, or its tab's while it loads.
  const current = ladder?.page ?? page;
  const shown = current?.payload;
  const elapsedS = current ? Math.floor((Date.now() - current.receivedAt) / 1000) : 0;
  const agoS = shown?.updatedAgoS != null ? shown.updatedAgoS + elapsedS : undefined;
  const waitS = shown ? Math.max(0, shown.refreshInS ? shown.refreshInS - elapsedS : 0) : 0;
  const refresh = () => { setRefreshing(true); sendAction({ type: "halloffame.refresh", tab, ...(ladder ? { key: ladder.key } : {}) }); };
  const tabItems = useMemo(() => tabs.map((t) => ({ value: t, label: TAB_META[t].label, icon: TAB_META[t].icon })), [tabs]);
  const meta = TAB_META[tab];
  const ladderBoard = ladder?.page?.payload.ladder;
  const feedback = ladder ? (ladderBoard ? `${ladderLine(ladderBoard)} · CHARACTER NAMES ONLY` : "")
    : shown ? `${shown.boards.length} BOARD${shown.boards.length === 1 ? "" : "S"} · CHARACTER NAMES ONLY` : "";

  return <div className="halloffame o77-interactive" role="dialog" aria-modal="true" aria-labelledby="halloffame-title" ref={root} tabIndex={-1}>
    <header className="halloffame__bar">
      <span className="halloffame__bar-title" id="halloffame-title"><Icon name="crown" size={15} />{payload.title} · {payload.hub.toUpperCase()}</span>
      <span className="halloffame__bar-route">PVP · RACES · PVE · MISSIONS<button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>
    <div className={cx("halloffame__strip", shown && !shown.database && "is-session")}>
      <Icon name={shown && !shown.database ? "triangle-alert" : "clock"} size={15} />
      <span>
        <b>{shown && !shown.database ? "THIS SESSION ONLY" : updatedLine(agoS)}</b>
        <small>{shown && !shown.database
          ? "No database: these boards hold the results since the server started, and reset with it."
          : "The best characters of the city. The boards are rebuilt every five minutes."}</small>
      </span>
      <Button size="sm" variant="secondary" icon={refreshing ? "loader" : "clock"} disabled={!shown || refreshing || waitS > 0} onClick={refresh}>
        {refreshing ? "UPDATING" : waitS > 0 ? `REFRESH IN ${waitS} S` : "REFRESH"}
      </Button>
    </div>
    <div className="halloffame__tabs"><Tabs items={tabItems} value={tab} onChange={pickTab} /></div>

    <div className={cx("halloffame__page", ladder && "is-ladder")}>
      {ladder ? <LadderView ladder={ladder} onBack={back} />
        : !shown ? <p className="halloffame__empty"><Icon name="loader" size={14} />Loading the {meta.label.toLowerCase()} boards…</p>
        : shown.boards.length === 0 ? <p className="halloffame__empty">{meta.empty}</p>
        : <>
          {tab === "wealth" && shown.wealthBankOnly && <p className="halloffame__note"><Icon name="triangle-alert" size={13} />Bank balances only: cash could not be read this time.</p>}
          <div className={cx("halloffame__grid", tab === "overview" && "is-overview")}>
            {shown.boards.map((b) => <BoardCard key={b.key} board={b} compact={tab === "overview"} onOpen={openLadder} />)}
          </div>
        </>}
    </div>

    <footer className="halloffame__foot">
      <span className="halloffame__feedback" role="status">{feedback}</span>
      <span className="halloffame__keys">
        {ladder ? <>
          <span><Keycap size="sm">← →</Keycap>TABS</span>
          <span><Keycap size="sm">ESC</Keycap><Keycap size="sm">BKSP</Keycap>BACK</span>
        </> : <>
          <span><Keycap size="sm">ENTER</Keycap>FULL LADDER</span>
          <span><Keycap size="sm">← →</Keycap>TABS</span>
          <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
        </>}
      </span>
    </footer>
  </div>;
}

/** A board's card: the whole card opens its full ladder (click, Enter or Space). */
function BoardCard({ board, compact, onOpen }: { board: HallOfFameBoard; compact: boolean; onOpen(board: HallOfFameBoard): void }) {
  const mine = mineLine(board);
  const rest = compact ? [] : board.rows.slice(3);
  const onKeyDown = (e: ReactKeyboardEvent) => {
    if (e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    if (!e.repeat) onOpen(board);
  };
  return <section className={cx("hof-board", "is-link", compact && "is-compact")} role="button" tabIndex={0} data-board={board.key}
    aria-label={`${board.title}: open the full ladder`} onClick={() => onOpen(board)} onKeyDown={onKeyDown}>
    <header className="hof-board__head">
      <span className="hof-board__title"><strong>{board.title}</strong>{board.subtitle && <small>{board.subtitle}</small>}</span>
      <span className="hof-board__badges">
        <Badge tone="outline">{board.ascending ? "LOWEST FIRST" : `${board.total} RANKED`}</Badge>
        <Icon name="chevron-right" size={15} className="hof-board__go" />
      </span>
    </header>
    {board.rows.length === 0 ? <p className="hof-board__empty">Nobody on this board yet: the first result takes the top.</p>
      : <Podium rows={board.rows} board={board} />}
    {rest.length > 0 && <RankList board={board} from={3} />}
    {mine && <p className="hof-board__mine"><Icon name="user" size={13} />{mine}</p>}
  </section>;
}

/** One board's full ladder: the podium, ranks 4 on in a list that scrolls, the
 *  viewer's own rank pinned under it when their row is not in the list. */
function LadderView({ ladder, onBack }: { ladder: Ladder; onBack(): void }) {
  const scroller = useRef<HTMLDivElement>(null);
  const loaded = ladder.page?.payload.ladder;
  const board = loaded ?? ladder.card;
  const pinned = loaded ? pinnedRank(loaded) : undefined;
  const character = useStore((s) => s.state.character);
  const me = [character?.firstName, character?.lastName].filter(Boolean).join(" ");
  // The list takes the keyboard (↑ ↓, Page Up/Down) once it shows.
  useEffect(() => { if (loaded) scroller.current?.focus({ preventScroll: true }); }, [loaded]);

  return <section className="hof-board hof-ladder" aria-label={`${board.title}: full ladder`}>
    <header className="hof-ladder__head">
      <Button size="sm" variant="secondary" icon="chevron-left" onClick={onBack}>BACK</Button>
      <span className="hof-board__title hof-ladder__title"><strong>{board.title}</strong>{board.subtitle && <small>{board.subtitle}</small>}</span>
      <span className="hof-board__badges">
        {loaded && <Badge tone="outline">{loaded.total} RANKED</Badge>}
        {board.ascending && <Badge tone="outline">LOWEST FIRST</Badge>}
      </span>
    </header>
    {ladder.refused ? <p className="halloffame__empty"><Icon name="triangle-alert" size={14} />{ladder.refused}</p>
      : !loaded ? <p className="halloffame__empty"><Icon name="loader" size={14} />Loading the full ladder…</p>
      : loaded.rows.length === 0 ? <p className="hof-board__empty">Nobody on this board yet: the first result takes the top.</p>
      : <>
        <div className="hof-ladder__scroll" ref={scroller} tabIndex={0} aria-label={`${loaded.title}: ranks`}>
          <div className="hof-ladder__podium"><Podium rows={loaded.rows} board={loaded} /></div>
          {loaded.rows.length > 3 && <RankList board={loaded} from={3} />}
        </div>
        {pinned && <ol className="hof-list hof-ladder__mine" aria-label="Your rank">
          <li className="is-you">
            <span className="hof-list__rank">{rankLabel(pinned.rank)}</span>
            <span className="hof-list__name">{me || "You"}<Badge tone="accent">YOU</Badge></span>
            {pinned.detail && <span className="hof-list__detail">{pinned.detail}</span>}
            <span className="hof-list__value">{formatValue(pinned.value, loaded.unit)}</span>
          </li>
        </ol>}
      </>}
  </section>;
}

/** The ranked rows after the podium, `from` = the index of the first one. */
function RankList({ board, from }: { board: HallOfFameBoard; from: number }) {
  return <ol className="hof-list" start={from + 1}>
    {board.rows.slice(from).map((r, i) => <li key={`${r.rank}-${r.name}-${i}`} className={cx(r.you && "is-you")}>
      <span className="hof-list__rank">{rankLabel(r.rank)}{tied(board.rows, i + from) && <i>=</i>}</span>
      <span className="hof-list__name">{r.name}{r.title && <small className="hof-title">{r.title}</small>}{r.you && <Badge tone="accent">YOU</Badge>}</span>
      {r.detail && <span className="hof-list__detail">{r.detail}</span>}
      <span className="hof-list__value">{formatValue(r.value, board.unit)}</span>
    </li>)}
  </ol>;
}

function Podium({ rows, board }: { rows: HallOfFameRow[]; board: HallOfFameBoard }) {
  return <ol className="hof-podium">
    {podium(rows).map(({ row, place }) => {
      const index = rows.indexOf(row);
      return <li key={`${row.rank}-${row.name}`} className={cx("hof-podium__step", `is-${place}`, row.you && "is-you")}>
        <span className="hof-podium__rank">{place === 1 && <Icon name="crown" size={14} />}{rankLabel(row.rank)}{tied(rows, index) && <i>=</i>}</span>
        <strong className="hof-podium__name" title={row.name}>{row.name}</strong>
        {row.title && <small className="hof-title hof-podium__title">{row.title}</small>}
        <span className="hof-podium__value">{formatValue(row.value, board.unit)}</span>
        {row.detail && <small className="hof-podium__detail">{row.detail}</small>}
        {row.you && <Badge tone="accent">YOU</Badge>}
      </li>;
    })}
  </ol>;
}
