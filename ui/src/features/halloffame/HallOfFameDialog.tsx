import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type HallOfFameBoard, type HallOfFameDialogPayload, type HallOfFameRow, type HallOfFameTab } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Keycap, Tabs, cx } from "@/design/components";
import { TAB_META, formatValue, mineLine, normalizeHallOfFame, podium, rankLabel, tied, updatedLine } from "./model";
import "./halloffame.css";

/* The Hall of Fame (server/modules/halloffame.lua): opened by the board at The
   Crossing (ALT + click on it, or E in front of it). One server answer per tab, from
   the server's cache; a tab already received this session shows at once. Podium for
   the top three, ranks 4-10 below, the viewer's own rank under each board. Esc or a
   right-click closes it. */

interface Page { payload: HallOfFameDialogPayload; receivedAt: number }

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
  const [pages, setPages] = useState<Partial<Record<HallOfFameTab, Page>>>(() => ({ [payload.tab]: { payload, receivedAt: Date.now() } }));
  const [refreshing, setRefreshing] = useState(false);
  const [, tick] = useState(0);

  // Every answer lands in its tab. A newer computation of the boards (a REFRESH, the
  // five-minute rebuild) makes the other tabs stale: they are asked again when shown.
  useEffect(() => {
    const now = Date.now();
    setPages((old) => {
      const computedAt = now - (payload.updatedAgoS ?? 0) * 1000;
      const keep: Partial<Record<HallOfFameTab, Page>> = {};
      for (const [t, page] of Object.entries(old) as Array<[HallOfFameTab, Page]>) {
        const pageComputedAt = page.receivedAt - (page.payload.updatedAgoS ?? 0) * 1000;
        if (t !== payload.tab && Math.abs(pageComputedAt - computedAt) < 5000) keep[t] = page;
      }
      keep[payload.tab] = { payload, receivedAt: now };
      return keep;
    });
    setRefreshing(false);
  }, [payload]);
  useEffect(() => { const t = window.setInterval(() => tick((n) => n + 1), 1000); return () => window.clearInterval(t); }, []);
  useEffect(() => { root.current?.focus(); }, []);

  const tabs = payload.tabs;
  const page = pages[tab];
  // A tab not received yet is asked for; once more if the first ask got no answer
  // (the server drops a second action of a type within 250 ms).
  useEffect(() => {
    if (page) return;
    const ask = () => sendAction({ type: "halloffame.tab", tab });
    ask();
    const retry = window.setTimeout(ask, 900);
    return () => window.clearTimeout(retry);
  }, [tab, page]);
  useEffect(() => {
    if (!refreshing) return;
    const t = window.setTimeout(() => setRefreshing(false), 8000);
    return () => window.clearTimeout(t);
  }, [refreshing]);

  const move = useCallback((step: number) => {
    setTab((current) => {
      const at = Math.max(0, tabs.indexOf(current));
      return tabs[(at + step + tabs.length) % tabs.length] ?? current;
    });
  }, [tabs]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement | null)?.tagName === "INPUT") return;
      let handled = true;
      if (e.key === "Escape") { if (!e.repeat) onClose(); }
      else if (e.key === "ArrowRight") move(1);
      else if (e.key === "ArrowLeft") move(-1);
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  }, [onClose, move]);

  const shown = page?.payload;
  const elapsedS = page ? Math.floor((Date.now() - page.receivedAt) / 1000) : 0;
  const agoS = shown?.updatedAgoS != null ? shown.updatedAgoS + elapsedS : undefined;
  const waitS = shown ? Math.max(0, shown.refreshInS ? shown.refreshInS - elapsedS : 0) : 0;
  const refresh = () => { setRefreshing(true); sendAction({ type: "halloffame.refresh", tab }); };
  const tabItems = useMemo(() => tabs.map((t) => ({ value: t, label: TAB_META[t].label, icon: TAB_META[t].icon })), [tabs]);
  const meta = TAB_META[tab];

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
    <div className="halloffame__tabs"><Tabs items={tabItems} value={tab} onChange={setTab} /></div>

    <div className="halloffame__page">
      {!shown ? <p className="halloffame__empty"><Icon name="loader" size={14} />Loading the {meta.label.toLowerCase()} boards…</p>
        : shown.boards.length === 0 ? <p className="halloffame__empty">{meta.empty}</p>
        : <>
          {tab === "wealth" && shown.wealthBankOnly && <p className="halloffame__note"><Icon name="triangle-alert" size={13} />Bank balances only: cash could not be read this time.</p>}
          <div className={cx("halloffame__grid", tab === "overview" && "is-overview")}>
            {shown.boards.map((b) => <BoardCard key={b.key} board={b} compact={tab === "overview"} />)}
          </div>
        </>}
    </div>

    <footer className="halloffame__foot">
      <span className="halloffame__feedback" role="status">{shown ? `${shown.boards.length} BOARD${shown.boards.length === 1 ? "" : "S"} · CHARACTER NAMES ONLY` : ""}</span>
      <span className="halloffame__keys">
        <span><Keycap size="sm">← →</Keycap>TABS</span>
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>
  </div>;
}

function BoardCard({ board, compact }: { board: HallOfFameBoard; compact: boolean }) {
  const mine = mineLine(board);
  const rest = compact ? [] : board.rows.slice(3);
  return <section className={cx("hof-board", compact && "is-compact")} aria-label={board.title}>
    <header className="hof-board__head">
      <span className="hof-board__title"><strong>{board.title}</strong>{board.subtitle && <small>{board.subtitle}</small>}</span>
      <Badge tone="outline">{board.ascending ? "LOWEST FIRST" : `${board.total} RANKED`}</Badge>
    </header>
    {board.rows.length === 0 ? <p className="hof-board__empty">Nobody on this board yet: the first result takes the top.</p>
      : <Podium rows={board.rows} board={board} />}
    {rest.length > 0 && <ol className="hof-list" start={4}>
      {rest.map((r, i) => <li key={`${r.rank}-${r.name}`} className={cx(r.you && "is-you")}>
        <span className="hof-list__rank">{rankLabel(r.rank)}{tied(board.rows, i + 3) && <i>=</i>}</span>
        <span className="hof-list__name">{r.name}{r.you && <Badge tone="accent">YOU</Badge>}</span>
        {r.detail && <span className="hof-list__detail">{r.detail}</span>}
        <span className="hof-list__value">{formatValue(r.value, board.unit)}</span>
      </li>)}
    </ol>}
    {mine && <p className="hof-board__mine"><Icon name="user" size={13} />{mine}</p>}
  </section>;
}

function Podium({ rows, board }: { rows: HallOfFameRow[]; board: HallOfFameBoard }) {
  return <ol className="hof-podium">
    {podium(rows).map(({ row, place }) => {
      const index = rows.indexOf(row);
      return <li key={`${row.rank}-${row.name}`} className={cx("hof-podium__step", `is-${place}`, row.you && "is-you")}>
        <span className="hof-podium__rank">{place === 1 && <Icon name="crown" size={14} />}{rankLabel(row.rank)}{tied(rows, index) && <i>=</i>}</span>
        <strong className="hof-podium__name" title={row.name}>{row.name}</strong>
        <span className="hof-podium__value">{formatValue(row.value, board.unit)}</span>
        {row.detail && <small className="hof-podium__detail">{row.detail}</small>}
        {row.you && <Badge tone="accent">YOU</Badge>}
      </li>;
    })}
  </ol>;
}
