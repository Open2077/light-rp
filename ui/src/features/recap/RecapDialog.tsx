import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS, type RecapColumn, type RecapDialogPayload, type RecapRow } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Icon, Keycap, cx } from "@/design/components";
import {
  COLUMN_META, MVP_BY, betterOf, formatCell, formatClock, groupRows, headcount, modeIcon, mvpRow, mvpStats, nextSort, normalizeRecap,
  outcomeTag, resultLine, rewardLines, scoreLine, sortRows, type SortState,
} from "./model";
import "./recap.css";

/* The end-of-match recap (server/modules/recap.lua, client/core/recap.lua): opened by
   the client once the player is back in the city with a clear screen, or from F1 >
   Last match. Header (mode, result, duration), the scoreboard grouped by side with the
   viewer's row highlighted (a column header sorts, PLAYER restores the match order),
   the mode's lines, the MVP and what the match paid. Esc, Enter or a right-click
   closes it. */

const ARM_MS = 350; // a key already down when it opens does not close it at once

const KIND_LABEL: Record<string, string> = {
  pvp: "PVP", pve: "PVE", race: "RACE", chase: "CHASE", event: "EVENT", mission: "CONTRACT", raid: "RAID", worldboss: "WORLD BOSS",
};

export function RecapDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "recap";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "recap", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "recap") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "recap", open: false }); };
  }, [visible, closeDialog]);
  const payload = useMemo(() => (visible ? normalizeRecap(dialog) : undefined), [visible, dialog]);
  if (!payload) return null;
  return <RecapBody key={`${payload.id}${payload.reopened ? ":again" : ""}`} payload={payload} onClose={closeDialog} />;
}

function RecapBody({ payload: p, onClose }: { payload: RecapDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const [sort, setSort] = useState<SortState>({});
  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => {
    const armedAt = Date.now() + ARM_MS;
    const armed = () => Date.now() >= armedAt;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" && e.key !== "Enter") return;
      e.preventDefault(); e.stopPropagation();
      if (!e.repeat && armed()) onClose();
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); if (armed()) onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  }, [onClose]);

  const rows = useMemo(() => sortRows(p.rows, sort, p.modeKind), [p, sort]);
  const groups = useMemo(() => groupRows(p, rows), [p, rows]);
  const mvp = mvpRow(p);
  const mine = p.rows.find((r) => r.id === p.you);
  const score = scoreLine(p);
  const placed = resultLine(p);
  const rewards = rewardLines(p.rewards, p.unranked);
  const title = p.source === "mission" ? "MISSION RECAP" : p.source === "worldboss" ? "WORLD BOSS RECAP" : "MATCH RECAP";
  const sortDir = (c: RecapColumn): "ascending" | "descending" => {
    const high = betterOf(c, p.modeKind) === "high";
    return high !== !!sort.reverse ? "descending" : "ascending";
  };

  return <div className="recap o77-interactive" role="dialog" aria-modal="true" aria-labelledby="recap-title" ref={root} tabIndex={-1}>
    <header className="recap__bar">
      <span className="recap__bar-title"><Icon name={modeIcon(p)} size={15} />{title}{p.reopened && <span className="recap__bar-tag">LAST MATCH</span>}</span>
      <span className="recap__bar-route">{KIND_LABEL[p.modeKind ?? ""] ?? "ACTIVITY"}<button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>

    <section className={cx("recap__head", `is-${p.result.tone}`)}>
      <div className="recap__result">
        <strong>{p.result.label}</strong>
        {placed && <small>{placed}</small>}
      </div>
      <div className="recap__title">
        <h2 id="recap-title">{p.mode}</h2>
        <span className="recap__facts">
          {p.detail && <span>{p.detail.toUpperCase()}</span>}
          {p.durationMs !== undefined && <span><Icon name="clock" size={13} />{formatClock(p.durationMs)}</span>}
          <span><Icon name="users" size={13} />{headcount(p)}</span>
        </span>
        {score && <span className="recap__score">{score}</span>}
      </div>
      {(p.test || p.unranked) && <div className="recap__chips">
        {p.test && <Badge tone="steel">TEST</Badge>}
        {p.unranked && <Badge tone="outline">UNRANKED</Badge>}
      </div>}
    </section>

    <div className="recap__main">
      <section className="recap__board" aria-label="Scoreboard">
        {p.rows.length === 0 ? <p className="recap__empty">Nobody on the board.</p>
          : <table>
            <thead><tr>
              <th className="recap__th-name" aria-sort={sort.column ? undefined : "other"}>
                <button className={cx(!sort.column && "is-sorted")} title="The match's own order" onClick={() => setSort({})}>PLAYER</button>
              </th>
              {p.columns.map((c) => <th key={c} aria-sort={sort.column === c ? sortDir(c) : undefined}>
                <button className={cx(sort.column === c && "is-sorted")} title={COLUMN_META[c].title} onClick={() => setSort((s) => nextSort(s, c))}>
                  {COLUMN_META[c].head}{sort.column === c && <i aria-hidden="true">{sortDir(c) === "descending" ? "▼" : "▲"}</i>}
                </button>
              </th>)}
            </tr></thead>
            {groups.map((g) => <tbody key={g.key}>
              {(g.side || p.sides.length >= 2) && <tr className={cx("recap__group", g.won && "is-won")}>
                <th colSpan={p.columns.length + 1}>
                  <span className="recap__group-label">{g.side ? g.side.label.toUpperCase() : "OTHERS"}</span>
                  {g.side?.score !== undefined && <b>{g.side.score}</b>}
                  {g.won && <Badge tone="accent">WIN</Badge>}
                  {g.side && mine?.side === g.side.id && <small>YOUR SIDE</small>}
                </th>
              </tr>}
              {g.rows.map((row) => <Row key={row.id} row={row} p={p} mvp={mvp?.id === row.id} sorted={sort.column} />)}
            </tbody>)}
          </table>}
      </section>

      <aside className="recap__rail">
        {mvp && <section className="recap-card recap-mvp" aria-label="MVP">
          <header><Icon name="crown" size={14} />MVP<small>{MVP_BY[p.mvp?.by ?? ""] ?? ""}</small></header>
          <strong title={mvp.name}>{mvp.name}{mvp.id === p.you && <Badge tone="accent">YOU</Badge>}</strong>
          {mvpStats(p, mvp).length > 0 && <dl className="recap-mvp__stats">
            {mvpStats(p, mvp).map((s) => <div key={s.column}><dt title={COLUMN_META[s.column].title}>{s.head}</dt><dd>{s.value}</dd></div>)}
          </dl>}
        </section>}
        {p.lines.length > 0 && <section className="recap-card" aria-label="The match">
          <header><Icon name="list-checks" size={14} />{p.source === "activity" ? "THE MATCH" : "THE RUN"}</header>
          <dl className="recap-lines">{p.lines.map((l, i) => <div key={`${l.label}-${i}`}><dt>{l.label}</dt><dd>{l.value}</dd></div>)}</dl>
        </section>}
        <section className="recap-card recap-rewards" aria-label="Rewards">
          <header><Icon name="coins" size={14} />REWARDS</header>
          <ul>{rewards.map((r) => <li key={r.key} className={cx(r.tone && `is-${r.tone}`)}>
            <span className="recap-rewards__label">{r.label}</span>
            <strong>{r.value}</strong>
            {r.note && <small>{r.note}</small>}
          </li>)}</ul>
        </section>
      </aside>
    </div>

    <footer className="recap__foot">
      <span className="recap__feedback" role="status">
        {p.columns.includes("dps") ? "DPS = DAMAGE DEALT ÷ SECONDS IN THE MATCH · " : ""}CLICK A COLUMN TO SORT
      </span>
      <span className="recap__keys">
        <span><Keycap size="sm">ESC</Keycap><Keycap size="sm">ENTER</Keycap>CLOSE</span>
        <span><Keycap size="sm">F1</Keycap>LAST MATCH</span>
      </span>
    </footer>
  </div>;
}

function Row({ row, p, mvp, sorted }: { row: RecapRow; p: RecapDialogPayload; mvp: boolean; sorted?: RecapColumn }) {
  const tag = outcomeTag(row);
  const you = row.id === p.you;
  return <tr className={cx(you && "is-you", row.bot && "is-bot", row.left && "is-left")}>
    <td className="recap__name">
      <span>
        {mvp && <Icon name="crown" size={13} className="recap__mvp-icon" />}
        <b title={row.name}>{row.name}</b>
        {you && <Badge tone="accent">YOU</Badge>}
        {row.bot && <Badge tone="outline">BOT</Badge>}
        {tag && <em>{tag}</em>}
      </span>
    </td>
    {p.columns.map((c) => <td key={c} className={cx(sorted === c && "is-sorted", row[c] === undefined && "is-blank")}>{formatCell(c, row, p.modeKind)}</td>)}
  </tr>;
}
