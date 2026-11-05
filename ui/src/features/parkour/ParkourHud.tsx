import { useEffect, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Button, Icon, Keycap, cx } from "@/design/components";
import { DIFFICULTY_LABEL, decodeSplits, formatDelta, formatTime, type ParkourEvent, type ParkourResult, type RunCourse } from "./model";
import { startMusic, stopMusic } from "./music";
import "./parkour.css";

/* The run, drawn by the page (server/modules/parkour.lua decides, client/core/parkour.lua
   relays): the clock top centre, the checkpoint count and the delta to the personal best (else
   the record) at each checkpoint, the splits on the right, the 3-2-1-GO, then the result card
   (time, personal best, rank, splits, the top 5) or the DNF card. Passive: never the focus.
   The course music plays from the countdown to the end of the run (music.ts). */

interface Split { index: number; elapsed: number; delta?: number; against?: "PB" | "REC" }
interface RunState {
  course: RunCourse; attempt: number; phase: "loading" | "countdown" | "running" | "finished";
  best?: { timeMs: number; splits: number[] }; record?: { timeMs: number; name: string; splits: number[] };
  splits: Split[]; finishMs?: number; result?: ParkourResult; dnf?: { reason: string; text?: string; checkpoint: number };
  goAt?: number; countdownEnd?: number; finishedAt?: number;
}

const HOLD_MS = 25000;
const now = () => performance.now();

export function ParkourHud() {
  const [run, setRun] = useState<RunState | null>(null);
  const [flash, setFlash] = useState<{ key: number; text: string; tone: "good" | "bad" | "info" } | null>(null);
  const clock = useRef<HTMLElement>(null);
  const runRef = useRef<RunState | null>(null);
  runRef.current = run;

  useEffect(() => on<ParkourEvent>(PAGE_EVENTS.parkour, (e) => {
    if (!e || typeof e !== "object") return;
    switch (e.kind) {
      case "run": {
        if (!e.course) return;
        if (e.music) startMusic(e.music.file, e.music.volume);
        const elapsed = typeof e.elapsedMs === "number" ? e.elapsedMs : undefined;
        setRun({
          course: e.course, attempt: e.attempt,
          phase: e.resume && e.phase === "running" ? "running" : e.phase === "finished" ? "finished" : "loading",
          best: e.best ? { timeMs: e.best.timeMs, splits: decodeSplits(e.best.splits) } : undefined,
          record: e.record ? { timeMs: e.record.timeMs, name: e.record.name, splits: decodeSplits(e.record.splits) } : undefined,
          splits: [], goAt: elapsed != null ? now() - elapsed : undefined,
        });
        setFlash(null);
        break;
      }
      case "countdown":
        setRun((r) => r && { ...r, phase: "countdown", countdownEnd: now() + e.goInMs, splits: [], finishMs: undefined, result: undefined, dnf: undefined, goAt: undefined });
        break;
      case "go":
        setRun((r) => r && { ...r, phase: "running", goAt: now(), countdownEnd: undefined });
        break;
      case "cp":
        setRun((r) => {
          if (!r) return r;
          const against = e.bestMs != null ? "PB" : e.recordMs != null ? "REC" : undefined;
          const ref = e.bestMs ?? e.recordMs;
          const split: Split = { index: e.index, elapsed: e.elapsedMs, delta: ref != null ? e.elapsedMs - ref : undefined, against };
          if (split.delta != null) setFlash({ key: now(), text: `${against} ${formatDelta(split.delta)}`, tone: split.delta <= 0 ? "good" : "bad" });
          return { ...r, goAt: now() - e.elapsedMs, splits: [...r.splits.filter((s) => s.index !== e.index), split] };
        });
        break;
      case "finish":
        setRun((r) => r && { ...r, phase: "finished", finishMs: e.timeMs, finishedAt: now() });
        break;
      case "result":
        setRun((r) => r && r.attempt === e.attempt ? { ...r, result: e, finishMs: e.timeMs } : r);
        break;
      case "dnf":
        setRun((r) => r && { ...r, phase: "finished", dnf: { reason: e.reason, text: e.text, checkpoint: e.checkpoint }, finishedAt: now() });
        break;
      case "respawn":
        setFlash({ key: now(), text: e.reason === "fell" ? "FELL · BACK TO THE LAST CHECKPOINT" : e.reason === "died" ? "DOWN · BACK TO THE LAST CHECKPOINT" : "BACK TO THE LAST CHECKPOINT", tone: "info" });
        break;
      case "ended":
        stopMusic();
        setRun(null); setFlash(null);
        break;
      default: break;
    }
  }), []);

  // the clock: written straight into the DOM every frame (no re-render)
  useEffect(() => {
    let frame = 0;
    const tick = () => {
      const r = runRef.current;
      if (clock.current && r) {
        let ms = 0;
        if (r.phase === "finished") ms = r.finishMs ?? (r.goAt != null ? (r.finishedAt ?? now()) - r.goAt : 0);
        else if (r.phase === "running" && r.goAt != null) ms = now() - r.goAt;
        clock.current.textContent = formatTime(ms, 2);
      }
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, []);
  useEffect(() => { if (!flash) return; const t = window.setTimeout(() => setFlash(null), 2600); return () => window.clearTimeout(t); }, [flash]);
  useEffect(() => () => stopMusic(0), []);

  if (!run) return null;
  const total = run.course.checkpoints.length;
  const passed = run.splits.length;
  const last = run.splits[run.splits.length - 1];
  const target = run.best?.timeMs ?? run.record?.timeMs;
  return <div className={cx("pk-hud", run.phase === "finished" && "is-finished")} aria-live="polite">
    <header className="pk-head">
      <div className="pk-head__plate">
        <span className="pk-head__id"><b>{run.course.name}</b>
          <small>{DIFFICULTY_LABEL[run.course.difficulty] ?? "Medium"}{run.course.test ? " · STAFF TEST" : ""} · RUN {run.attempt}</small></span>
        <span className="pk-clock"><b ref={clock}>0.00</b></span>
        <span className="pk-head__cp"><small>CHECKPOINT</small><b>{Math.min(passed, total)}<em>/{total}</em></b></span>
      </div>
      <div className="pk-head__refs">
        {run.best && <span><small>PB</small>{formatTime(run.best.timeMs)}</span>}
        {run.record && <span className="is-record"><small>REC</small>{formatTime(run.record.timeMs)} · {run.record.name}</span>}
        {!run.best && !run.record && <span><small>FIRST TIME</small>NO TIME TO BEAT</span>}
        {last?.delta != null && run.phase === "running" && <span className={cx("pk-delta", last.delta <= 0 ? "is-good" : "is-bad")}>
          <small>{last.against} @ CP{last.index}</small>{formatDelta(last.delta)}</span>}
      </div>
      {total > 0 && <ol className="pk-pips" aria-hidden>{run.course.checkpoints.map((_, i) => {
        const s = run.splits.find((x) => x.index === i + 1);
        return <li key={i} className={cx(s && "is-done", s?.delta != null && (s.delta <= 0 ? "is-good" : "is-bad"), !s && i === passed && run.phase === "running" && "is-next")} />;
      })}<li className={cx("is-finish", run.phase === "finished" && !run.dnf && "is-done")} /></ol>}
    </header>

    {flash && <div key={flash.key} className={cx("pk-flash", `is-${flash.tone}`)}>{flash.text}</div>}

    {run.splits.length > 0 && run.phase !== "finished" && <aside className="pk-splits" aria-label="Splits">
      <small>SPLITS{target ? ` · VS ${run.best ? "PB" : "RECORD"}` : ""}</small>
      <ul>{run.splits.slice(-7).map((s) => <li key={s.index}>
        <span>CP {s.index}</span><b>{formatTime(s.elapsed)}</b>
        {s.delta != null && <em className={s.delta <= 0 ? "is-good" : "is-bad"}>{formatDelta(s.delta)}</em>}
      </li>)}</ul>
    </aside>}

    {run.phase === "countdown" && run.countdownEnd && <Countdown end={run.countdownEnd} />}
    {run.phase === "loading" && <div className="pk-banner">ON YOUR MARK</div>}

    {run.phase === "finished" && (run.dnf ? <DnfCard run={run} /> : <ResultCard run={run} />)}

    {run.phase !== "finished" && <footer className="pk-keys">
      <span><Keycap size="sm">HOME</Keycap>RESTART</span>
      <span><Keycap size="sm">END</Keycap>LAST CHECKPOINT</span>
      <span><Keycap size="sm">DEL</Keycap>LEAVE</span>
    </footer>}
  </div>;
}

function Countdown({ end }: { end: number }) {
  const [left, setLeft] = useState(() => Math.ceil((end - now()) / 1000));
  useEffect(() => {
    const t = window.setInterval(() => setLeft(Math.ceil((end - now()) / 1000)), 50);
    return () => window.clearInterval(t);
  }, [end]);
  const text = left > 0 ? String(left) : "GO";
  return <div className="pk-count" aria-live="assertive"><b key={text} className={cx(left <= 0 && "is-go")}>{text}</b><small>GET READY</small></div>;
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
