import { useEffect, useRef, useState } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { matchesToggleKey } from "@/features/inventory/model";
import { ActionClock, timingStep, type ActionDefinition, type ActionResult, type ActionView } from "./model";
import "./actions.css";

const prettyKey = (key: string) => key === "SPACE" ? "Space" : key;
const resultTitle = (r: ActionResult) => r.status === "success" ? "Action complete" : r.status === "cancelled" ? "Action cancelled" : "Action failed";
const reasons: Record<string, string> = { completed: "You're all set.", cancelled: "You stopped the action.", released: "The key was released.",
  too_early: "Pressed before the target zone.", missed: "The target zone was missed.", timeout: "Time ran out.", focus_lost: "Focus was lost. Try again when ready.",
  interrupted: "Another screen needs your attention.", dead: "Your character cannot continue.", owner_stopped: "The activity is no longer available.", ui_timeout: "The interface did not respond." };

export function Actions() {
  const [definition, setDefinition] = useState<ActionDefinition | null>(null);
  const [external, setExternal] = useState<ActionResult | null>(null);
  const activeId = useRef<string | null>(null);
  const preview = window.__lightrpMock && new URLSearchParams(location.search).get("actions") === "1";
  const start = (d: ActionDefinition) => {
    if (!d?.id || !["progress", "hold", "timing"].includes(d.kind)) return;
    activeId.current = d.id; setExternal(null); setDefinition(d); useStore.getState().setActivityActive(true);
  };
  useEffect(() => {
    const offStart = on<ActionDefinition>(PAGE_EVENTS.actionStart, start);
    const offFinish = on<ActionResult>(PAGE_EVENTS.actionFinish, (r) => { if (r?.id === activeId.current) setExternal(r); });
    return () => { offStart(); offFinish(); };
  }, []);
  const dismiss = (id: string) => { if (activeId.current === id) { activeId.current = null; setDefinition(null); } };
  return <>
    {preview && <ActionPlayground onStart={start} />}
    {definition && <ActionRun key={definition.id} definition={definition} external={external} dismiss={dismiss} />}
  </>;
}

function ActionRun({ definition: d, external, dismiss }: { definition: ActionDefinition; external: ActionResult | null; dismiss: (id: string) => void }) {
  const clock = useRef(new ActionClock(d, performance.now()));
  const [view, setView] = useState<ActionView>({ ...clock.current.view });
  const sent = useRef(false);
  const blocked = useStore((s) => !!s.dialog || s.menuOpen || s.welcomeReplay || s.state.character.welcomePending || s.state.character.status !== "active");
  const dead = useStore((s) => s.hud.ready && s.hud.health.value <= 0);
  const finish = (status: ActionResult["status"], reason: string) => clock.current.finish(status, reason, performance.now());

  useEffect(() => {
    if (external) { clock.current.finish(external.status, external.reason, performance.now()); sent.current = true; setView({ ...clock.current.view, result: external }); useStore.getState().setActivityActive(false); }
  }, [external]);
  useEffect(() => { if (blocked) finish("cancelled", "interrupted"); else if (dead) finish("cancelled", "dead"); }, [blocked, dead]);
  useEffect(() => {
    let frame = 0;
    let pressed: string | null = null;
    emit(PAGE_EVENTS.actionStarted, { id: d.id });
    const render = () => {
      const v = clock.current.tick(performance.now());
      setView({ ...v });
      if (v.result) {
        useStore.getState().setActivityActive(false);
        if (!sent.current) { sent.current = true; emit(PAGE_EVENTS.actionResult, v.result); }
      } else frame = requestAnimationFrame(render);
    };
    frame = requestAnimationFrame(render);
    const down = (e: KeyboardEvent) => {
      if (clock.current.view.result) return;
      if (e.key === "Escape" || e.code === "Escape") { e.preventDefault(); e.stopPropagation(); if (d.cancellable && !e.repeat) finish("cancelled", "cancelled"); return; }
      const key = d.kind === "timing" ? d.steps[clock.current.view.step]?.key : d.key;
      if (!key || d.kind === "progress" || !matchesToggleKey(e, key)) return;
      e.preventDefault(); e.stopPropagation();
      if (e.repeat || pressed !== null) return;
      pressed = e.code || e.key.toUpperCase();
      clock.current.press(performance.now());
    };
    const up = (e: KeyboardEvent) => {
      if (pressed === null || (e.code || e.key.toUpperCase()) !== pressed) return;
      pressed = null; if (clock.current.view.result) return;
      e.preventDefault(); e.stopPropagation(); clock.current.release(performance.now());
    };
    const blur = () => { pressed = null; finish("cancelled", "focus_lost"); };
    const visibility = () => { if (document.hidden) blur(); };
    window.addEventListener("keydown", down); window.addEventListener("keyup", up); window.addEventListener("blur", blur);
    document.addEventListener("visibilitychange", visibility);
    return () => { cancelAnimationFrame(frame); window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); window.removeEventListener("blur", blur); document.removeEventListener("visibilitychange", visibility); };
  }, [d]);
  useEffect(() => {
    if (!view.result) return;
    const timer = window.setTimeout(() => dismiss(d.id), 1400);
    return () => clearTimeout(timer);
  }, [view.result, d.id, dismiss]);

  const result = view.result, timing = d.kind === "timing", ring = d.style === "ring" && !timing;
  const step = d.steps[view.step];
  const instruction = view.phase === "ready" ? "Get ready" : timing ? view.phase === "feedback" ? view.feedback : "Press in the yellow zone"
    : d.kind === "hold" ? view.held ? "Keep holding" : view.feedback.startsWith("Released") ? view.feedback : "Hold to continue" : "In progress";
  return <section className={`activity activity--${ring ? "ring" : timing ? "timing" : "bar"}${result ? ` is-${result.status}` : ""}${view.held ? " is-held" : ""}`} aria-label={d.label} data-phase={view.phase} data-kind={d.kind}>
    <div className="activity__eyebrow"><span>Light RP <i /> {timing ? "Precision action" : d.kind === "hold" ? "Hold action" : "Activity"}</span>
      {timing && <span>{Math.min(view.step + 1, d.steps.length)} <b>/ {d.steps.length}</b></span>}</div>
    <div className="activity__main">
      {ring ? <div className="activity__dial" role="progressbar" aria-label={d.label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(view.progress * 100)}>
        <svg viewBox="0 0 80 80" aria-hidden="true"><circle cx="40" cy="40" r="34" /><circle className="activity__arc" cx="40" cy="40" r="34" pathLength="100" strokeDasharray="100" strokeDashoffset={100 - view.progress * 100} /></svg>
        {result ? <Icon name={result.status === "success" ? "check" : "x"} size={24} /> : <span>{Math.floor(view.progress * 100)}<small>%</small></span>}
      </div> : <span className="activity__icon"><Icon name={result ? result.status === "success" ? "check" : "x" : d.icon} size={22} /></span>}
      <div className="activity__copy"><h2>{result ? resultTitle(result) : d.label}</h2><p>{result ? reasons[result.reason] ?? "The action was stopped." : d.description}</p></div>
      {!result && !timing && !ring && <span className="activity__percent">{Math.floor(view.progress * 100)}<small>%</small></span>}
    </div>
    {!ring && <div className={`activity__track${timing ? " activity__track--timing" : ""}`} role={timing ? "img" : "progressbar"} aria-label={timing ? "Press when the white cursor enters the striped yellow zone" : d.label}
      aria-valuemin={timing ? undefined : 0} aria-valuemax={timing ? undefined : 100} aria-valuenow={timing ? undefined : Math.round(view.progress * 100)}>
      {timing && step ? <><span className="activity__zone" style={{ left: `${step.zoneStart * 100}%`, width: `${step.zoneWidth * 100}%` }}><i /></span><span className="activity__cursor" style={{ left: `${view.progress * 100}%` }} /></>
        : <span className="activity__fill" style={{ transform: `scaleX(${view.progress})` }} />}
    </div>}
    <div className="activity__footer"><span className="activity__instruction" role="status" aria-live="polite">
      {result ? timing && result.status === "success" ? `${result.hits} / ${d.steps.length} hits · ${result.score}% precision` : result.status === "success" ? "Completed" : "No action completed"
        : <>{d.kind !== "progress" && <kbd className={view.held ? "is-down" : ""}>{prettyKey(timing ? step?.key ?? "E" : d.key)}</kbd>}{instruction}</>}
    </span>
      {!result && (timing ? <span className="activity__steps" aria-label={`${view.hits} hits, ${view.mistakes} misses`}>{d.steps.map((_, i) => <i key={i} className={i < view.hits + view.mistakes ? "is-done" : i === view.step ? "is-current" : ""} />)}</span>
        : <span className="activity__time">{Math.ceil(view.remainingMs / 1000)}s left</span>)}
    </div>
    {!result && <div className="activity__cancel">{d.cancellable ? <><kbd>Esc</kbd> Cancel</> : "Stay with the action"}{timing && d.maxMistakes > 0 && <span>{view.mistakes} / {d.maxMistakes} misses allowed</span>}</div>}
  </section>;
}

function ActionPlayground({ onStart }: { onStart: (d: ActionDefinition) => void }) {
  const active = useStore((s) => s.activityActive);
  const [selected, setSelected] = useState("progress");
  const presets = [
    { id: "progress", icon: "wrench", label: "Progress bar", text: "Repair, gather, prepare. A calm, readable timer." },
    { id: "ring", icon: "clock", label: "Circular progress", text: "The same action in a compact radial format." },
    { id: "hold", icon: "hand", label: "Hold a key", text: "Keep E pressed. Release to reset your progress." },
    { id: "timing", icon: "zap", label: "Timing check", text: "One press. Catch the highlighted window." },
    { id: "sequence", icon: "activity", label: "Multi-step check", text: "Three increasingly precise steps. E, R, then E." },
  ];
  const launch = (id: string) => {
    setSelected(id);
    const kind = id === "hold" ? "hold" : id === "timing" || id === "sequence" ? "timing" : "progress";
    onStart({ id: `preview-${Date.now()}`, kind, label: kind === "timing" ? "Calibrate the relay" : kind === "hold" ? "Secure the connection" : "Prepare the equipment",
      description: kind === "timing" ? "Stop the cursor inside the highlighted area." : "Keep everything steady. You're nearly there.", icon: kind === "timing" ? "zap" : "wrench",
      style: id === "ring" || id === "hold" ? "ring" : "bar", durationMs: 5000, timeoutMs: 30000, key: "E", cancellable: true, release: "reset", maxMistakes: 0,
      steps: id === "sequence" ? [timingStep("easy", "E"), timingStep("normal", "R"), timingStep("hard", "E")] : [timingStep("easy")] });
  };
  return <main className="action-lab o77-interactive"><header><span>Light RP / Interaction kit</span><h1>Small actions.<br /><em>Clear feedback.</em></h1><p>Progress, hold and precision checks. One visual language.<br />Ready to connect to your jobs.</p></header>
    <div className="action-lab__presets">{presets.map((p, i) => <button key={p.id} disabled={active} className={selected === p.id ? "is-selected" : ""} onClick={() => launch(p.id)}><span className="action-lab__number">0{i + 1}</span><Icon name={p.icon} size={25} /><strong>{p.label}</strong><p>{p.text}</p><span className="action-lab__try">Try interaction <Icon name="arrow-right" size={17} /></span></button>)}</div>
    <footer><span>Client-side UI · No items, money or job rewards.</span><span><kbd>E</kbd> / <kbd>R</kbd> Interact <i /> <kbd>Esc</kbd> Cancel</span></footer>
  </main>;
}
