import { useEffect, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Button, Icon, Keycap, cx } from "@/design/components";
import { decodeSplits, formatDelta, formatTime, type ParkourEvent, type ParkourResult, type RunCourse } from "./model";
import { startMusic, stopMusic } from "./music";
import "./parkour.css";

/* The end of a run, drawn by the page (server/modules/parkour.lua decides, client/core/parkour.lua
   relays): the result card (time, personal best, rank, splits, the top 5) or the DNF card, which
   take the cursor. The run itself (clock, checkpoints, bearing, splits, 3-2-1-GO, key reminders)
   is drawn on NativeUI (client/native/parkour.lua); the page still follows the run to know what
   the card shows, and plays the course music from the countdown to the end of the run (music.ts). */

interface Split { index: number; elapsed: number }
interface RunState {
  course: RunCourse; attempt: number; phase: "loading" | "countdown" | "running" | "finished";
  best?: { timeMs: number; splits: number[] };
  splits: Split[]; finishMs?: number; result?: ParkourResult; dnf?: { reason: string; text?: string; checkpoint: number };
  finishedAt?: number;
}

const HOLD_MS = 25000;
const now = () => performance.now();

export function ParkourHud() {
  const [run, setRun] = useState<RunState | null>(null);

  useEffect(() => on<ParkourEvent>(PAGE_EVENTS.parkour, (e) => {
    if (!e || typeof e !== "object") return;
    switch (e.kind) {
      case "run": {
        if (!e.course) return;
        // a course without checkpoints arrives with checkpoints = {} (Lua's empty table)
        if (!Array.isArray(e.course.checkpoints)) e.course.checkpoints = [];
        if (e.music) startMusic(e.music.file, e.music.volume);
        setRun({
          course: e.course, attempt: e.attempt,
          phase: e.resume && e.phase === "running" ? "running" : e.phase === "finished" ? "finished" : "loading",
          best: e.best ? { timeMs: e.best.timeMs, splits: decodeSplits(e.best.splits) } : undefined,
          splits: [],
        });
        break;
      }
      case "countdown":
        setRun((r) => r && { ...r, phase: "countdown", splits: [], finishMs: undefined, result: undefined, dnf: undefined });
        break;
      case "go":
        setRun((r) => r && { ...r, phase: "running" });
        break;
      case "cp":
        setRun((r) => r && { ...r, splits: [...r.splits.filter((s) => s.index !== e.index), { index: e.index, elapsed: e.elapsedMs }] });
        break;
      case "finish":
        setRun((r) => r && { ...r, phase: "finished", finishMs: e.timeMs, finishedAt: now() });
        break;
      case "result":
        if (e.top && !Array.isArray(e.top)) e.top = [];
        setRun((r) => r && r.attempt === e.attempt ? { ...r, result: e, finishMs: e.timeMs } : r);
        break;
      case "dnf":
        setRun((r) => r && { ...r, phase: "finished", dnf: { reason: e.reason, text: e.text, checkpoint: e.checkpoint }, finishedAt: now() });
        break;
      case "ended":
        stopMusic();
        setRun(null);
        break;
      default: break;
    }
  }), []);
  useEffect(() => () => stopMusic(0), []);

  if (!run || run.phase !== "finished") return null;
  return <div className="pk-hud is-finished" aria-live="polite">
    {run.dnf ? <DnfCard run={run} /> : <ResultCard run={run} />}
  </div>;
}

/* The result and DNF cards take the cursor (F1 is the player menu): RUN AGAIN, LEADERBOARD,
   LEAVE are buttons; Enter runs again, Escape leaves. The focus goes back when the card does. */
const again = () => emit(PAGE_EVENTS.parkour, { op: "restart" });
const leave = () => emit(PAGE_EVENTS.parkour, { op: "leave" });
function useCardFocus() {
  useEffect(() => {
    emit(PAGE_EVENTS.focus, { active: true });
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat) return;
      if (e.key === "Enter") { e.preventDefault(); again(); }
      else if (e.key === "Escape" || e.key === "Delete") { e.preventDefault(); leave(); }
    };
    window.addEventListener("keydown", onKey);
    return () => { window.removeEventListener("keydown", onKey); emit(PAGE_EVENTS.focus, { active: false }); };
  }, []);
}
function CardActions({ course, back, board }: { course: string; back: number; board?: boolean }) {
  return <footer className="pk-result__actions">
    <Button variant="primary" icon="play" onClick={again}>RUN AGAIN</Button>
    {board && <Button variant="secondary" icon="trophy" onClick={() => sendAction({ type: "parkour.open", course })}>LEADERBOARD</Button>}
    <Button variant="danger" icon="log-out" onClick={leave}>LEAVE</Button>
    <span className="pk-result__back">BACK IN {back}s · <Keycap size="sm">ENTER</Keycap> AGAIN · <Keycap size="sm">ESC</Keycap> LEAVE</span>
  </footer>;
}

function useHold(at?: number) {
  const [left, setLeft] = useState(HOLD_MS);
  useEffect(() => {
    const t = window.setInterval(() => setLeft(Math.max(0, HOLD_MS - (now() - (at ?? now())))), 250);
    return () => window.clearInterval(t);
  }, [at]);
  return Math.ceil(left / 1000);
}

function ResultCard({ run }: { run: RunState }) {
  const r = run.result;
  const time = run.finishMs ?? r?.timeMs ?? 0;
  const splits = r ? decodeSplits(r.splits) : run.splits.map((s) => s.elapsed);
  const before = run.best;
  const back = useHold(run.finishedAt);
  const vsPrevious = r?.previous ? time - r.previous.timeMs : undefined;
  useCardFocus();
  return <section className="pk-result o77-interactive" role="dialog" aria-label="Run result">
    <header>
      <span className="pk-result__tag"><Icon name="flag" size={14} />{r?.test ? "STAFF TEST · NOT RECORDED" : "FINISH"}</span>
      <b className="pk-result__time">{formatTime(time)}</b>
      <span className="pk-result__badges">
        {r?.recordBroken && <i className="is-record"><Icon name="crown" size={12} />COURSE RECORD</i>}
        {r?.improved && !r.recordBroken && <i className="is-pb"><Icon name="trending-up" size={12} />{r.previous ? "NEW PERSONAL BEST" : "FIRST TIME SET"}</i>}
        {r && !r.improved && !r.test && vsPrevious != null && <i className="is-slow">PB {formatTime(r.previous!.timeMs)} · {formatDelta(vsPrevious)}</i>}
        {!r && <i>SAVING…</i>}
      </span>
    </header>
    <div className="pk-result__body">
      <div className="pk-result__col">
        <small>SPLITS{before ? " · VS YOUR PB BEFORE THIS RUN" : ""}</small>
        <ol className="pk-table">
          {splits.map((ms, i) => {
            const ref = before?.splits[i];
            return <li key={i}><span>CP {i + 1}</span><b>{formatTime(ms)}</b>
              {ref != null ? <em className={ms - ref <= 0 ? "is-good" : "is-bad"}>{formatDelta(ms - ref)}</em> : <em />}</li>;
          })}
          <li className="is-finish"><span>FINISH</span><b>{formatTime(time)}</b>
            {before ? <em className={time - before.timeMs <= 0 ? "is-good" : "is-bad"}>{formatDelta(time - before.timeMs)}</em> : <em />}</li>
        </ol>
      </div>
      <div className="pk-result__col">
        <small>{r?.rank ? `YOUR RANK · ${r.rank} / ${r.total ?? r.rank}` : "LEADERBOARD"}</small>
        {r?.error && <p className="pk-result__error">{r.error}</p>}
        {r?.top && r.top.length > 0 ? <ol className="pk-table pk-table--board">
          {r.top.map((t) => <li key={t.rank} className={cx(t.me && "is-me")}><span>#{t.rank}</span><b>{t.name}</b><em>{formatTime(t.timeMs)}</em></li>)}
        </ol> : !r?.test && <p className="pk-result__note">{r ? "Your time opens the board." : "Saving your time…"}</p>}
        {r?.test && <p className="pk-result__note">A staff test of the draft: nothing is written on the board.</p>}
      </div>
    </div>
    <CardActions course={run.course.id} back={back} board={!run.course.test} />
  </section>;
}

const DNF_TEXT: Record<string, string> = { time: "Time limit reached.", teleported: "You left the course.", too_fast: "Too fast for a runner." };
function DnfCard({ run }: { run: RunState }) {
  const back = useHold(run.finishedAt);
  useCardFocus();
  return <section className="pk-result is-dnf o77-interactive" role="dialog" aria-label="Did not finish">
    <header>
      <span className="pk-result__tag"><Icon name="x" size={14} />DID NOT FINISH</span>
      <b className="pk-result__time">DNF</b>
      <span className="pk-result__badges"><i>{run.dnf?.text ?? DNF_TEXT[run.dnf?.reason ?? ""] ?? "Run over."}</i></span>
    </header>
    <p className="pk-result__note">Checkpoints passed: {run.dnf?.checkpoint ?? 0} / {run.course.checkpoints.length}</p>
    <CardActions course={run.course.id} back={back} />
  </section>;
}
