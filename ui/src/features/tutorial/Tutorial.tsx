import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { DialogueDemo, HallMap, StepDemo } from "./demos";
import "./tutorial.css";
import { VoiceTutorial, type VoiceSetup } from "./VoiceTutorial";
import { ContextLesson } from "./ContextLesson";

type Keys = { menu: string; inventory: string; interact: string; context?: string; lock?: string; skip?: string; way?: string };
/** The flight to a new destination (client/core/tutorial.lua, startReveal). */
type Reveal = { name: string; direction?: string; distance: number; index?: number; total?: number; durationMs: number };
type Presentation = { phase?: string; options?: boolean; keys?: Keys; distance?: number | false; reveal?: Reveal | false; voice?: VoiceSetup; voiceError?: string };
const control = (operation: string) => emit(PAGE_EVENTS.tutorial, { operation });
const pad = (n: number) => String(n).padStart(2, "0");

/** The line being said, written out at reading pace; `finish` shows it whole. */
function useTyping(text: string): [number, boolean, () => void] {
  // The count belongs to its text: a new line starts at 0 from its very first frame.
  const [progress, setProgress] = useState({ text, shown: 0 });
  const quiet = typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  useEffect(() => {
    if (quiet) { setProgress({ text, shown: text.length }); return; }
    setProgress({ text, shown: 0 });
    const timer = setInterval(() => setProgress(p => {
      if (p.text !== text) return p;
      if (p.shown >= text.length) { clearInterval(timer); return p; }
      return { text, shown: p.shown + 2 };
    }), 28);
    return () => clearInterval(timer);
  }, [text, quiet]);
  const shown = progress.text === text ? Math.min(progress.shown, text.length) : quiet ? text.length : 0;
  return [shown, shown >= text.length, () => setProgress({ text, shown: text.length })];
}

/** The way to the next stop, while the camera flies it: letterbox, the place, the hall from above. */
function RevealCard({ reveal, map, skip }: { reveal: Reveal; map?: Parameters<typeof HallMap>[0]["stops"]; skip?: string }) {
  return <div className="first-day__reveal" role="status" aria-label={`Next stop: ${reveal.name}`}>
    <i className="first-day__bar first-day__bar--top" /><i className="first-day__bar first-day__bar--bottom" />
    <div className="first-day__reveal-title">
      <span className="first-day__eyebrow"><Icon name="route" size={13} />NEXT STOP{reveal.index ? ` · ${pad(reveal.index)} / ${pad(reveal.total ?? 10)}` : ""}</span>
      <h2>{reveal.name}</h2>
      <p>{reveal.direction ? `${reveal.direction} · ` : ""}<b>{reveal.distance} m</b> on foot</p>
      <span className="first-day__reveal-time"><i style={{ animationDuration: `${reveal.durationMs}ms` }} /></span>
    </div>
    {map && map.length > 0 && <div className="first-day__reveal-map"><span className="first-day__eyebrow">ARRIVAL HALL</span><HallMap stops={map} compact /></div>}
    {skip && <div className="first-day__reveal-skip"><kbd className="first-day__key">{skip}</kbd>Skip</div>}
  </div>;
}

export function Tutorial() {
  const guide = useStore(s => s.state.tutorial);
  const character = useStore(s => s.state.character);
  const otherDialog = useStore(s => !!s.dialog || s.menuOpen || s.welcomeReplay);
  const connected = useStore(s => s.connected);
  const result = useStore(s => s.lastResult);
  const [presentation, setPresentation] = useState<Presentation>({ phase: "waiting" });
  const [options, setOptions] = useState(false);
  const [line, setLine] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  // The step just finished, shown for a moment over the card when the next one arrives.
  const [done, setDone] = useState("");
  const previous = useRef<{ key?: string; step?: string; title?: string }>({});
  const root = useRef<HTMLDivElement>(null);
  const readOn = useRef<() => void>(() => undefined);
  const current = connected && character.status === "active";
  const intro = !!guide?.active && guide.step === "intro";
  const dialogue = !!guide?.active && (!!guide.dialogue || guide.step === "outro");
  const voiceLesson = !!guide?.active && guide.step === "voice";
  const modal = current && !otherDialog && (intro || dialogue || options || voiceLesson);
  const visible = current && !!guide?.active && !otherDialog;
  const lines = (Array.isArray(guide?.lines) ? guide.lines : []).map(l => typeof l === "string" ? { text: l, demo: undefined } : { text: l?.text ?? "", demo: l?.demo });
  const last = line >= lines.length - 1;
  const said = lines[line]?.text ?? "";
  const [typed, complete, finishTyping] = useTyping(said);
  const keys: Keys = { menu: "F1", inventory: "I", interact: "E", context: "ALT", lock: "L", skip: "SPACE", way: "G", ...presentation.keys };
  const reveal = presentation.phase === "reveal" && presentation.reveal ? presentation.reveal : null;
  // Who speaks: the contact of the step (the arrival hall has several), the guide for everything else.
  const guideName = guide?.guide ?? "Mara";
  const speaker = guide?.contact ?? guideName;
  const opening = guide?.opening;
  const openingTitle = opening?.title ?? ["Your first", "day."];
  const todo = Array.isArray(guide?.todo) ? guide.todo : [];
  const total = Math.max(1, guide?.total ?? 10), index = Math.min(total, Math.max(1, guide?.index ?? 1));

  useEffect(() => on<Presentation>(PAGE_EVENTS.tutorial, p => {
    setPresentation(s => ({ ...s, ...p }));
    if (p.options) setOptions(true);
  }), []);
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const changed = () => emit(PAGE_EVENTS.tutorial, { reducedMotion: media.matches });
    changed(); media.addEventListener("change", changed);
    return () => media.removeEventListener("change", changed);
  }, []);
  useEffect(() => { setLine(0); setBusy(false); setError(""); }, [guide?.key, guide?.step, guide?.revision, guide?.dialogue]);
  useEffect(() => {
    const before = previous.current;
    previous.current = { key: guide?.key, step: guide?.active ? guide.step : undefined, title: guide?.title };
    if (!guide?.active || !before.step || before.key !== guide.key || before.step === guide.step || before.step === "intro" || !before.title) return;
    setDone(before.title);
    const timer = setTimeout(() => setDone(""), 2600);
    return () => clearTimeout(timer);
  }, [guide?.active, guide?.key, guide?.step, guide?.title]);
  useEffect(() => { if (!current) { setOptions(false); setBusy(false); } }, [current]);
  useEffect(() => {
    if (result?.action === "tutorial.control" && !result.ok) { setBusy(false); setError(result.text); }
  }, [result]);
  useEffect(() => {
    if (!busy) return;
    const timer = setTimeout(() => { setBusy(false); setError("Still waiting for the guide. You can retry or use /tutorial pause."); }, intro ? 32000 : 10000);
    return () => clearTimeout(timer);
  }, [busy, intro]);
  useEffect(() => {
    if (!modal) return;
    emit(PAGE_EVENTS.focus, { active: true });
    emit(PAGE_EVENTS.dialogState, { kind: "tutorial", open: true });
    root.current?.focus();
    return () => {
      emit(PAGE_EVENTS.dialogState, { kind: "tutorial", open: false });
      emit(PAGE_EVENTS.focus, { active: false });
    };
  }, [modal]);
  useEffect(() => {
    if (!modal) return;
    const key = (e: KeyboardEvent) => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); setOptions(true); }
      // Space / Enter read on: the line whole first, then the next one. A focused button keeps its own click.
      if (!voiceLesson && (e.key === " " || e.key === "Enter") && !(document.activeElement instanceof HTMLButtonElement)) {
        e.preventDefault(); if (!e.repeat) readOn.current();
      }
      if (e.key !== "Tab") return;
      const nodes = [...(root.current?.querySelectorAll<HTMLElement>("button:not(:disabled), input:not(:disabled), select:not(:disabled), summary") ?? [])];
      const first = nodes[0], end = nodes[nodes.length - 1];
      if (!e.shiftKey && (document.activeElement === end || document.activeElement === root.current)) { e.preventDefault(); first?.focus(); }
      else if (e.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { e.preventDefault(); end?.focus(); }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [modal, voiceLesson]);

  const issue = (operation: string) => { if (busy && !(operation === "intro" && presentation.phase === "intro_retry")) return; setBusy(true); setError(""); control(operation); };
  const goOn = () => { if (!last) setLine(n => n + 1); else issue(guide?.step === "outro" ? "finish" : "next"); };
  readOn.current = () => { if (!dialogue || options) return; if (!complete) finishTyping(); else goOn(); };
  if (!current || (!visible && !options) || otherDialog) return null;
  const pause = () => { control("pause"); setOptions(false); setBusy(false); };
  const keyHint = guide?.step === "identity" ? `${keys.menu} · IDENTITY`
    : guide?.step === "inventory" || guide?.step === "drink" ? `${keys.inventory} · INVENTORY`
    : `${keys.interact} · INTERACT`;
  return <div className={`first-day${modal ? " first-day--modal o77-interactive" : ""}${intro ? " first-day--intro" : ""}`}>
    {modal && <div className="first-day__modal" role="dialog" aria-modal="true" aria-label={options ? "First day guide options" : intro ? "Your first day" : voiceLesson ? "Voice setup guide" : `Conversation with ${speaker}`} tabIndex={-1} ref={root}>
      {intro && !options && <>
        <div className={`first-day__curtain${["opening", "confirming", "intro_retry"].includes(presentation.phase ?? "") ? " is-open" : ""}`} />
        <div className="first-day__opening"><span>{opening?.eyebrow ?? "LIGHT/RP · CHAPTER 02"}</span><h1>{openingTitle[0]}<br /><em>{openingTitle[1]}</em></h1><p>{opening?.subtitle ?? "A name. A guide. A place to start."}</p></div>
        <div className="first-day__opening-foot"><span>{presentation.phase === "opening" ? (opening?.place ?? "ARRIVAL HALL") : presentation.phase === "confirming" ? "Waiting for your arrival to be confirmed…" : presentation.phase === "intro_retry" ? "Arrival not confirmed. Retry, or press Esc to pause the guide." : "Arriving…"}</span><button onClick={() => issue("intro")} disabled={busy && presentation.phase !== "intro_retry"}>{presentation.phase === "intro_retry" ? "Retry arrival" : presentation.phase === "confirming" ? "Continue" : "Skip scene"} <Icon name="arrow-right" size={15} /></button></div>
      </>}
      {options ? <section className="first-day__options">
        <span className="first-day__eyebrow">LIGHT/RP / FIRST DAY GUIDE</span><h2>Your city. Your pace.</h2>
        <p>{guide?.active ? (guide.where === "lobby" ? "Take a break whenever you like. Your progress is saved. Continuing on your own takes you out of the arrival hall, to Night City." : "Take a break whenever you like. Your progress is saved.") : guide?.status === "done" ? "You've found your feet. You can revisit the guide whenever you like." : `Let ${guideName} show you your citizen card, your inventory, a shop, the bank and how to earn your first eddies.`}</p>
        <div>{guide?.active ? <><button className="first-day__primary" onClick={() => setOptions(false)}>Continue guide</button><button onClick={pause}>Continue on my own</button><button onClick={() => { control("gps"); setOptions(false); }}>Show objective on GPS</button></> : <><button className="first-day__primary" disabled={busy || guide?.available === false} onClick={() => { control("resume"); setOptions(false); }}>{guide?.status === "done" ? "Revisit first day" : guide?.status === "paused" ? "Resume guide" : "Start first day"}</button><button onClick={() => setOptions(false)}>Not now</button></>}</div>
        <small>Find this guide in {keys.menu} → First day guide, or type /tutorial.</small>
      </section> : voiceLesson ? <VoiceTutorial state={presentation.voice} error={presentation.voiceError} /> : dialogue && <div className="first-day__talk">
        {lines[line]?.demo && <DialogueDemo id={lines[line].demo!} keys={keys} map={guide?.map} />}
        <section className="first-day__conversation" key={`${guide?.dialogue}:${guide?.step}`}>
          <div className="first-day__speaker"><span className={`first-day__portrait${complete ? "" : " is-talking"}`}>{speaker.charAt(0).toUpperCase()}<span /></span><div><span className="first-day__eyebrow">{guide?.step === "outro" ? `INCOMING MESSAGE / ${speaker.toUpperCase()}` : guide?.role}</span><h2>{speaker}</h2></div>
            <span className="first-day__pages" aria-label={`Line ${line + 1} of ${lines.length}`}>{lines.map((_, i) => <i key={i} className={i < line ? "is-done" : i === line ? "is-now" : ""} />)}</span></div>
          {/* The whole line is laid out from the start: the unsaid part is transparent, so nothing reflows while it is written. */}
          <p className="first-day__line" key={line} onClick={() => finishTyping()}>{said.slice(0, typed)}<span className="first-day__unsaid">{said.slice(typed)}</span></p>
          <footer><button onClick={pause}>I'll find my own way</button><span>{guide?.step === "outro" ? "Your items and progress are kept." : <><kbd>SPACE</kbd> read on</>}</span><button className="first-day__primary" disabled={busy} onClick={goOn}>{busy ? "Saving…" : !last ? "Go on" : guide?.action ?? (guide?.step === "outro" ? `See you around, ${speaker}` : "Show me around")}<Icon name="arrow-right" size={17} /></button></footer>
        </section>
      </div>}
      {error && <div className="first-day__error" role="alert">{error}</div>}
    </div>}
    {visible && !modal && done && <div className="first-day__done" key={done} role="status">
      <svg className="first-day__tick" viewBox="0 0 52 52" aria-hidden="true"><circle cx="26" cy="26" r="23" /><path d="M15 27l7 7 15-16" /></svg>
      <div><span className="first-day__eyebrow">STEP COMPLETE</span><b>{done}</b></div>
      <ol aria-hidden="true">{Array.from({ length: total }, (_, i) => <li key={i} className={i + 1 < index ? "is-done" : i + 1 === index ? "is-now" : ""} />)}</ol>
    </div>}
    {visible && !modal && reveal && <RevealCard reveal={reveal} map={guide?.map} skip={keys.skip} />}
    {visible && !modal && !reveal && <aside className="first-day__objective" aria-label="First day objective">
      <header>
        <span className="first-day__eyebrow">FIRST DAY</span>
        <span className="first-day__count"><b>{String(guide?.index ?? 1).padStart(2, "0")}</b> / {String(total).padStart(2, "0")}</span>
      </header>
      <ol className="first-day__steps" aria-hidden="true">{Array.from({ length: total }, (_, i) =>
        <li key={i} className={i + 1 < index ? "is-done" : i + 1 === index ? "is-now" : ""} />)}</ol>
      <div className="first-day__task" key={guide?.step} aria-live="polite">
        <h2>{guide?.title}</h2>
        {todo.length > 0 ? <ul className="first-day__todo">{todo.map((row, i) =>
          <li key={i} style={{ animationDelay: `${120 + i * 90}ms` }}>
            {row.key ? <kbd className="first-day__key">{keys[row.key] ?? row.key}</kbd>
              : <span className="first-day__bullet"><Icon name={i === 0 && guide?.objective ? "map-pin" : "chevron-right"} size={14} /></span>}
            <span>{row.text}</span>
          </li>)}</ul> : <p>{guide?.hint}</p>}
        {guide?.demo === "context" ? <ContextLesson step={guide.step} alt={keys.context} /> : guide?.demo && <StepDemo id={guide.demo} keys={keys} />}
        {guide?.practiceError && <p role="alert">{guide.practiceError} Type /tutorial resume to retry.</p>}
      </div>
      {guide?.objective && typeof presentation.distance === "number" && <div className="first-day__distance">
        <span className="first-day__beacon"><Icon name="arrow-down" size={13} /></span>
        <b>{presentation.distance} m</b><span>{guide.objective.label}</span>
      </div>}
      {guide?.line && <blockquote><span>{guideName.toUpperCase()}</span>{guide.line}</blockquote>}
      <footer>{guide?.objective ? <span className="first-day__way"><kbd className="first-day__waykey">{keys.way}</kbd>Show me the way</span>
        : todo.length > 0 ? <span>{keys.menu} → First day guide</span> : <kbd>{keyHint}</kbd>}<span>/tutorial pause</span></footer>
    </aside>}
  </div>;
}
