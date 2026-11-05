import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Button, Icon, Keycap, cx } from "@/design/components";
import {
  DIFFICULTY_LABEL, decodeSplits, formatDelta, formatLength, formatTime,
  type BoardPayload, type BoardRow, type CourseCard, type ParkourDialogPayload,
} from "./model";
import "./parkour.css";

/* F1 > Parkour, /parkour, or E at a start orb (server/modules/parkour.lua M.browser): every
   published course with its record and the player's best, and the selected course's whole
   leaderboard (pages of 50, server M.sendBoard), each time with its splits against the record.
   START RUN starts it from here (the activity core brings the player back where they stood at
   the end); GPS sets the route to the start orb. */

type Sort = "near" | "name" | "popular";
const SORT_LABEL: Record<Sort, string> = { near: "NEAREST", name: "A–Z", popular: "MOST RUN" };

export function ParkourBrowser() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "parkour";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "parkour", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "parkour") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "parkour", open: false }); };
  }, [visible, closeDialog]);
  if (!visible) return null;
  return <Browser payload={dialog as unknown as ParkourDialogPayload} onClose={closeDialog} />;
}

function Browser({ payload, onClose }: { payload: ParkourDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const result = useStore((s) => s.lastResult);
  const [sort, setSort] = useState<Sort>("near");
  const courses = useMemo(() => {
    const list = [...payload.courses];
    if (sort === "near") list.sort((a, b) => (a.distance ?? 1e9) - (b.distance ?? 1e9) || a.name.localeCompare(b.name));
    else if (sort === "popular") list.sort((a, b) => b.finishes - a.finishes || a.name.localeCompare(b.name));
    else list.sort((a, b) => a.name.localeCompare(b.name));
    return list;
  }, [payload.courses, sort]);
  const [selected, setSelected] = useState<string | undefined>(payload.selected ?? courses[0]?.id);
  const [board, setBoard] = useState<BoardPayload | null>(null);
  const [opened, setOpened] = useState<number | null>(null); // rank whose splits are open
  const [feedback, setFeedback] = useState<{ text: string; ok: boolean } | null>(null);
  const seen = useRef(result);
  const course = courses.find((c) => c.id === selected);

  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => on<BoardPayload>(PAGE_EVENTS.parkour, (e) => {
    if (e?.kind !== "board") return;
    setBoard({ ...e, rows: Array.isArray(e.rows) ? e.rows : [] }); // an empty board arrives as {}
  }), []);
  useEffect(() => {
    if (!selected) return;
    setOpened(null);
    if (board?.course !== selected) { setBoard(null); sendAction({ type: "parkour.board", course: selected, page: 1 }); }
  }, [selected]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!result || result === seen.current) return;
    seen.current = result;
    if (result.action === "parkour.gps" || result.action === "parkour.start") setFeedback({ text: result.text, ok: result.ok });
  }, [result]);

  const page = (n: number) => { if (selected && board?.pages && n >= 1 && n <= board.pages) sendAction({ type: "parkour.board", course: selected, page: n }); };
  const start = () => { if (course) { setFeedback(null); sendAction({ type: "parkour.start", course: course.id }); } };
  const gps = () => { if (course) { setFeedback(null); sendAction({ type: "parkour.gps", course: course.id }); } };
  const move = (delta: number) => {
    const i = Math.max(0, courses.findIndex((c) => c.id === selected));
    const next = courses[Math.min(courses.length - 1, Math.max(0, i + delta))];
    if (next) setSelected(next.id);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      let handled = true;
      if (e.key === "Escape" || e.key === "Backspace") { if (!e.repeat) onClose(); }
      else if (e.key === "ArrowDown") move(1);
      else if (e.key === "ArrowUp") move(-1);
      else if (e.key === "Enter") start();
      else if (e.key.toLowerCase() === "g") gps();
      else if (e.key === "PageDown" || e.key === "ArrowRight") page((board?.page ?? 1) + 1);
      else if (e.key === "PageUp" || e.key === "ArrowLeft") page((board?.page ?? 1) - 1);
      else if (e.key === "Tab") setSort((s) => s === "near" ? "popular" : s === "popular" ? "name" : "near");
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  });
  useEffect(() => { document.getElementById(`pk-course-${selected}`)?.scrollIntoView({ block: "nearest" }); }, [selected]);

  const record = board?.course === selected ? board?.record : undefined;
  const recordSplits = decodeSplits(record?.splits);
  return <div className="pk-browser o77-interactive" role="dialog" aria-modal="true" aria-labelledby="pk-title" ref={root} tabIndex={-1}>
    <header className="pk-browser__bar">
      <span className="pk-browser__title" id="pk-title"><Icon name="footprints" size={15} />PARKOUR</span>
      <span className="pk-browser__route">COURSES OF NIGHT CITY · {payload.courses.length} OPEN
        <button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>

    <div className="pk-browser__main">
      <section className="pk-list" aria-label="Courses">
        <div className="pk-list__sort">{(["near", "popular", "name"] as Sort[]).map((s) =>
          <button key={s} className={cx(sort === s && "is-on")} onClick={() => setSort(s)}>{SORT_LABEL[s]}</button>)}</div>
        <div className="pk-list__rows">
          {courses.length === 0 && <p className="pk-empty"><Icon name="search" size={14} />No course is open yet. The staff build them; check again later.</p>}
          {courses.map((c) => <CourseRow key={c.id} c={c} on={c.id === selected} here={c.id === payload.here} onPick={() => setSelected(c.id)} />)}
        </div>
      </section>

      {course ? <section className="pk-detail" aria-live="polite">
        <div className="pk-detail__head">
          <div>
            <small className="pk-detail__kicker">{course.id === payload.here ? "YOU ARE AT THE START" : course.distance != null ? `START ${course.distance} M AWAY` : "COURSE"}</small>
            <h2>{course.name}</h2>
            <p>{course.description || "No description."}</p>
            <span className="pk-detail__meta">
              <i className={`pk-diff is-${course.difficulty}`}>{DIFFICULTY_LABEL[course.difficulty]}</i>
              <span><Icon name="map-pin" size={12} />{course.checkpoints} CHECKPOINT{course.checkpoints === 1 ? "" : "S"}</span>
              <span><Icon name="route" size={12} />{formatLength(course.length)}</span>
              {course.timeLimit > 0 && <span><Icon name="timer" size={12} />{course.timeLimit} MIN LIMIT</span>}
              {course.fallLine && <span><Icon name="triangle-alert" size={12} />FALL LINE</span>}
              {course.author && <span><Icon name="user" size={12} />BY {course.author.toUpperCase()}</span>}
            </span>
          </div>
          <div className="pk-detail__actions">
            <Button variant="primary" icon="play" onClick={start} disabled={payload.running === course.id}>{course.id === payload.here ? "START RUN" : "TRAVEL & START"}</Button>
            <Button variant="secondary" icon="navigation" onClick={gps}>GPS TO THE START</Button>
          </div>
        </div>

        <div className="pk-stats">
          <div className={cx("pk-stat", course.record && "is-gold")}><Icon name="crown" size={16} /><span><small>COURSE RECORD</small>
            <b>{course.record ? formatTime(course.record.timeMs) : "OPEN"}</b><em>{course.record?.name ?? "Be the first to finish"}</em></span></div>
          <div className={cx("pk-stat", course.best && "is-accent")}><Icon name="trophy" size={16} /><span><small>YOUR BEST</small>
            <b>{course.best ? formatTime(course.best.timeMs) : "—"}</b>
            <em>{course.best ? `#${course.best.rank ?? "?"} · ${course.best.runs ?? 1} finish${(course.best.runs ?? 1) === 1 ? "" : "es"}` : "Not finished yet"}</em></span></div>
          <div className="pk-stat"><Icon name="users" size={16} /><span><small>RUNNERS</small><b>{course.runners}</b><em>{course.finishes} finishes · {course.attempts} starts</em></span></div>
          {course.best && course.record && <div className="pk-stat"><Icon name="timer" size={16} /><span><small>GAP TO THE RECORD</small>
            <b>{course.best.timeMs - course.record.timeMs <= 0 ? "RECORD" : formatDelta(course.best.timeMs - course.record.timeMs)}</b><em>seconds behind</em></span></div>}
        </div>

        <div className="pk-board">
          <div className="pk-board__head">
            <small>LEADERBOARD{board?.total ? ` · ${board.total} RUNNER${board.total === 1 ? "" : "S"}` : ""}</small>
            {board?.pages && board.pages > 1 && <span className="pk-board__pages">
              <button onClick={() => page((board.page ?? 1) - 1)} disabled={(board.page ?? 1) <= 1}><Icon name="chevron-left" size={13} /></button>
              PAGE {board.page} / {board.pages}
              <button onClick={() => page((board.page ?? 1) + 1)} disabled={(board.page ?? 1) >= board.pages}><Icon name="chevron-right" size={13} /></button>
            </span>}
          </div>
          <div className="pk-board__cols"><span>#</span><span>RUNNER</span><span>TIME</span><span>GAP</span><span>FINISHES</span><span>SET</span></div>
          <div className="pk-board__rows">
            {!board || board.course !== selected ? <p className="pk-empty"><Icon name="loader" size={14} />Loading the leaderboard…</p>
              : board.error ? <p className="pk-empty">{board.error}</p>
              : !board.rows?.length ? <p className="pk-empty"><Icon name="flag" size={14} />Nobody has finished this course yet. The record is yours to take.</p>
              : board.rows.map((r) => <BoardLine key={r.rank} r={r} record={record?.timeMs} recordSplits={recordSplits}
                open={opened === r.rank} onToggle={() => setOpened(opened === r.rank ? null : r.rank)} />)}
          </div>
          {board?.best && board.course === selected && !board.rows?.some((r) => r.me) &&
            <div className="pk-board__mine"><span>#{board.best.rank ?? "?"}</span><span>YOU</span><b>{formatTime(board.best.timeMs)}</b>
              <em>{record ? formatDelta(board.best.timeMs - record.timeMs) : ""}</em></div>}
        </div>
      </section> : <section className="pk-detail"><p className="pk-empty">Pick a course on the left.</p></section>}
    </div>

    <footer className="pk-browser__foot">
      <span className={cx("pk-browser__feedback", feedback && !feedback.ok && "is-error")} role={feedback ? "alert" : "status"}>
        {feedback?.text ?? "THE START ORB IS THE CYAN BEAM · EVERY CHECKPOINT IN ORDER · THE CLOCK STARTS ON GO"}
      </span>
      <span className="pk-browser__keys">
        <span><Keycap size="sm">↑ ↓</Keycap>COURSE</span>
        <span><Keycap size="sm">← →</Keycap>PAGE</span>
        <span><Keycap size="sm">TAB</Keycap>SORT</span>
        <span><Keycap size="sm">ENTER</Keycap>START</span>
        <span><Keycap size="sm">G</Keycap>GPS</span>
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>
  </div>;
}

function CourseRow({ c, on: selected, here, onPick }: { c: CourseCard; on: boolean; here: boolean; onPick(): void }) {
  return <button id={`pk-course-${c.id}`} className={cx("pk-course", selected && "is-on", here && "is-here")} onClick={onPick} onFocus={onPick}>
    <span className="pk-course__top"><b>{c.name}</b><i className={`pk-diff is-${c.difficulty}`}>{DIFFICULTY_LABEL[c.difficulty]}</i></span>
    <span className="pk-course__meta">{c.checkpoints} CP · {formatLength(c.length)}{c.distance != null ? ` · ${c.distance >= 1000 ? (c.distance / 1000).toFixed(1) + " KM" : c.distance + " M"} AWAY` : ""}</span>
    <span className="pk-course__times">
      <span><Icon name="crown" size={11} />{c.record ? formatTime(c.record.timeMs) : "OPEN"}</span>
      <span className={cx(c.best && "is-mine")}><Icon name="trophy" size={11} />{c.best ? formatTime(c.best.timeMs) : "—"}</span>
    </span>
    {here && <span className="pk-course__here">HERE</span>}
  </button>;
}

function BoardLine({ r, record, recordSplits, open, onToggle }: { r: BoardRow; record?: number; recordSplits: number[]; open: boolean; onToggle(): void }) {
  const splits = decodeSplits(r.splits);
  const date = r.at ? new Date(r.at).toLocaleDateString([], { day: "numeric", month: "short" }) : "—";
  return <>
    <button className={cx("pk-row", r.me && "is-me", r.rank <= 3 && `is-top is-top-${r.rank}`, open && "is-open")} onClick={onToggle}>
      <span className="pk-row__rank">{r.rank <= 3 ? <Icon name="medal" size={13} /> : null}{r.rank}</span>
      <span className="pk-row__name">{r.name}{r.me && <i>YOU</i>}</span>
      <b>{formatTime(r.timeMs)}</b>
      <em>{record != null && r.rank > 1 ? formatDelta(r.timeMs - record) : r.rank === 1 ? "RECORD" : ""}</em>
      <span>{r.runs}</span>
      <span>{date}</span>
    </button>
    {open && <div className="pk-row__splits">
      {splits.length === 0 ? <span className="pk-empty">No checkpoint on this course: start to finish.</span>
        : splits.map((ms, i) => {
          const ref = recordSplits[i];
          return <span key={i}><small>CP {i + 1}</small><b>{formatTime(ms)}</b>
            {ref != null && r.rank > 1 && <em className={ms - ref <= 0 ? "is-good" : "is-bad"}>{formatDelta(ms - ref)}</em>}</span>;
        })}
    </div>}
  </>;
}
