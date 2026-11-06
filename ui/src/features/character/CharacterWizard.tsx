import { useEffect, useRef, useState } from "react";
import { Camera, Volume2, VolumeX, Sun } from "lucide-react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type CharacterState, type IdentityFields, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { identityFields, initialPage, ORIGIN_NOTES, STEPS, validateIdentity, type WizardPage } from "./model";
import "./wizard.css";

export function CharacterWizard() {
  const character = useStore(s => s.state.character);
  const connected = useStore(s => s.connected);
  // playerId 0 = the empty default, not a character the server sent: another key
  // can reach the page first, and that must not open the creator over a real one.
  if (!connected || !character.playerId || character.status === "active") return null;
  return <WizardBody key={`${character.playerId}:${character.key}`} character={character} />;
}

function WizardBody({ character }: { character: CharacterState }) {
  const supportOpen = useStore(s => s.dialog?.kind === "support");
  const [page, setPage] = useState<WizardPage>(() => initialPage(character));
  const [fields, setFields] = useState(() => identityFields(character));
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const family = character.bodyFamily ?? "male";
  const nativePending = character.appearanceTracked && !character.bodyFamily;
  const [scene, setScene] = useState<{ phase: string; error?: string }>({ phase: "waiting" });
  const placing = scene.phase === "placement";
  // The cover hides the arrival's teleport; it never stays for good (2026-11-05, a black screen at
  // creation): the client shows the scene anyway after its own deadlines, and should that word never
  // come, the cover lifts by itself after 30 s on whatever the game shows.
  const [coverStale, setCoverStale] = useState(false);
  const sceneReady = scene.phase === "ready" || coverStale;
  const [muted, setMuted] = useState(false);
  const [reduced, setReduced] = useState(() => window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [editor, setEditor] = useState(false);
  const [sent, setSent] = useState<string | null>(null);
  const [feedback, setFeedback] = useState("");
  const [slow, setSlow] = useState(false);
  const pending = useRef<string | null>(null);
  const submittedIdentity = useRef<IdentityFields | null>(null);
  const root = useRef<HTMLDivElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const previousCharacter = useRef(character);
  const result = useStore(s => s.lastResult);
  const resultBefore = useRef(result);
  const errors = validateIdentity(fields, character);
  const index = STEPS.findIndex(s => s.id === page);
  const origins = Array.isArray(character.origins) ? character.origins : [];
  const origin = origins.find(o => o.key === fields.origin)?.label;
  const busy = !!sent;
  const dirty = JSON.stringify(fields) !== JSON.stringify(identityFields(character));
  const canReview = character.step === "confirm" || character.step === "done";
  const set = (patch: Partial<IdentityFields>) => { setFields(f => ({ ...f, ...patch })); setFeedback(""); };
  const move = (next: WizardPage) => { if (!pending.current) { setPage(next); setFeedback(""); } };

  useEffect(() => {
    if (supportOpen) return;
    emit(PAGE_EVENTS.focus, { active: !editor && !nativePending && !placing });
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [editor, nativePending, placing, supportOpen]);
  useEffect(() => on<{ active: boolean; error?: string }>(PAGE_EVENTS.characterEditor, value => {
    setEditor(value.active === true);
    if (value.error) setFeedback(value.error);
  }), []);
  useEffect(() => on<{ phase: string; error?: string }>(PAGE_EVENTS.creator, setScene), []);
  useEffect(() => {
    setCoverStale(false);
    if (scene.phase === "ready" || scene.phase === "closed" || scene.phase === "editor" || scene.phase === "placement") return;
    const id = window.setTimeout(() => setCoverStale(true), 30000);
    return () => window.clearTimeout(id);
  }, [scene.phase]);
  useEffect(() => {
    emit(PAGE_EVENTS.creator, { shot: page, muted, reducedMotion: reduced });
  }, [page, muted, reduced, editor]);
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const changed = () => setReduced(media.matches);
    media.addEventListener("change", changed);
    return () => media.removeEventListener("change", changed);
  }, []);
  useEffect(() => {
    const previous = previousCharacter.current;
    previousCharacter.current = character;
    if (previous.step !== character.step || previous.appearanceRevision !== character.appearanceRevision) {
      if (pending.current !== "character.identity") setPage(initialPage(character));
    }
  }, [character]);
  useEffect(() => {
    if (!result || result === resultBefore.current || result.action !== pending.current) return;
    // State and acknowledgements can arrive separately; keep the draft intact
    // until both confirm this save, rather than replacing it with stale state.
    if (result.ok && pending.current === "character.identity") {
      const submitted = submittedIdentity.current;
      if (!submitted || !character.firstName || !character.lastName
        || character.firstName.toLowerCase() !== submitted.firstName.toLowerCase()
        || character.lastName.toLowerCase() !== submitted.lastName.toLowerCase()
        || (character.birthDate ?? "") !== (submitted.birthDate ?? "")
        || (character.origin ?? "") !== (submitted.origin ?? "")
        || (character.story ?? "") !== (submitted.story ?? "")) return;
    }
    resultBefore.current = result;
    const action = pending.current;
    // Completion is authoritative: never activate a character from a success toast.
    if (result.ok && action === "character.finish") return;
    pending.current = null; setSent(null); setSlow(false);
    if (!result.ok) { setFeedback(result.text); return; }
    if (action === "character.identity") {
      const c = useStore.getState().state.character;
      setFields(identityFields(c)); setPage("appearance");
    }
  }, [result, character]);
  useEffect(() => {
    if (!sent) return;
    const timer = window.setTimeout(() => setSlow(true), 12000);
    return () => window.clearTimeout(timer);
  }, [sent]);
  useEffect(() => {
    if (editor || nativePending || placing || supportOpen) return;
    heading.current?.focus();
    root.current?.querySelector(".creator__scroll")?.scrollTo(0, 0);
  }, [page, editor, nativePending, placing, supportOpen]);
  useEffect(() => {
    if (editor || nativePending || placing || supportOpen) return;
    const key = (e: KeyboardEvent) => {
      if (e.key === "Escape" || e.code === "Escape") { e.preventDefault(); e.stopPropagation(); }
      if (e.key !== "Tab") return;
      const nodes = [...(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), [tabindex="0"]') ?? [])].filter(el => el.getClientRects().length > 0);
      const first = nodes[0], last = nodes[nodes.length - 1];
      if (e.shiftKey && (document.activeElement === first || document.activeElement === heading.current)) { e.preventDefault(); last?.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [editor, nativePending, placing, supportOpen]);

  const issue = (action: UiAction) => {
    if (pending.current) return;
    pending.current = action.type; resultBefore.current = useStore.getState().lastResult;
    setSent(action.type); setFeedback(""); setSlow(false); sendAction(action);
  };
  const identityNext = () => {
    setTouched({ firstName: true, lastName: true, birthDate: true });
    if (Object.keys(errors).length) {
      root.current?.querySelector<HTMLInputElement>(`[name="${Object.keys(errors)[0]}"]`)?.focus(); return;
    }
    move("background");
  };
  const saveIdentity = () => {
    if (Object.keys(errors).length) { move("identity"); setTouched({ firstName: true, lastName: true, birthDate: true }); return; }
    const payload = { firstName: fields.firstName.trim(), lastName: fields.lastName.trim(), birthDate: fields.birthDate || undefined, origin: fields.origin || undefined, story: fields.story?.trim() || undefined };
    submittedIdentity.current = payload;
    issue({ type: "character.identity", ...payload });
  };
  const openEditor = () => {
    setFeedback(""); setEditor(true);
    emit(PAGE_EVENTS.focus, { active: false });
    sendAction({ type: "character.appearance.open", mode: "ripperdoc", family });
  };
  const title = { identity: "A new name.\nA new beginning.", background: "Every arrival\nhas a story.", appearance: "Make yourself\nat home.", review: `Welcome to Night City${character.firstName ? `, ${character.firstName}` : ""}.` }[page];
  const subtitle = { identity: "This is who other players will meet. Your account name stays separate.", background: "A little context makes a character yours. Both of these choices are optional.", appearance: "Your look is saved. Take a moment, or revisit the details before you head into the city.", review: "One last look before your story begins. You can go back and change anything." }[page];
  const name = `${fields.firstName} ${fields.lastName}`.trim();

  const hidden = editor || nativePending || placing || supportOpen;
  return <div ref={root} className={`creator o77-interactive${hidden ? " creator--editor" : ""}${reduced ? " creator--still" : ""}${!sceneReady ? " creator--preparing" : ""}`} role="dialog" aria-modal={!hidden} aria-labelledby="creator-title" aria-hidden={hidden || undefined}>
    <div className="creator__loading-cover" aria-hidden="true" />
    <div className="creator__shade" aria-hidden="true" />
    <header className="creator__masthead">
      <div className="creator__brand"><span className="creator__brand-mark">LIGHT<span>/</span>RP</span><span>YOUR NEXT CHAPTER</span></div>
      <div className="creator__location"><span className="creator__live-dot" /><span>NIGHT CITY <b> / </b> ARRIVAL</span><Sun size={14} /><span>12:00</span></div>
    </header>
    <aside className="creator__scene">
      <div className="creator__scene-copy"><span className="creator__eyebrow">Chapter 01 / Arrival</span><h1>A city of millions.<br /><em>A story that's yours.</em></h1></div>
      <nav aria-label="Character creation steps" className="creator__nav"><ol>{STEPS.map((s, i) => <li key={s.id}><button type="button" aria-current={page === s.id ? "step" : undefined} disabled={busy || i > index} onClick={() => move(s.id)}><span className="creator__step-num">{i < index ? <Icon name="check" size={14} /> : `0${i + 1}`}</span><span>{s.label}</span><span className="creator__step-line" /></button></li>)}</ol></nav>
      <div className="creator__passport"><span className="creator__eyebrow">One way to Night City</span><strong>{name || "Your seat is waiting."}</strong><span>{origin ? `${origin} → Night City` : "Somewhere behind you. Everything ahead."}</span></div>
    </aside>
    <main className="creator__main">
      <header className="creator__top"><span>NEW RESIDENT</span><span>0{index + 1} <b>/</b> 04</span></header>
      <div className="creator__progress"><i style={{ width: `${(index + 1) * 25}%` }} /></div>
      <form className="creator__form" aria-busy={busy} onSubmit={e => { e.preventDefault(); if (busy) return; if (page === "identity") identityNext(); else if (page === "background") saveIdentity(); else if (page === "review" && canReview && !dirty) issue({ type: "character.finish" }); }}>
        <div className="creator__scroll">
          <section key={page} className="creator__page">
            <span className="creator__eyebrow">Step 0{index + 1} / 04 <span>— {STEPS[index]?.detail}</span></span>
            <h2 id="creator-title" ref={heading} tabIndex={-1}>{title}</h2><p className="creator__intro">{subtitle}</p>
            {page === "identity" && <>
              <div className="creator__two">{(["firstName", "lastName"] as const).map((key, i) => <label className="creator__field" key={key}><span>{i === 0 ? "First name" : "Last name"}<small>Required</small></span><input name={key} value={fields[key]} onChange={e => set({ [key]: e.target.value })} onBlur={() => setTouched(t => ({ ...t, [key]: true }))} autoComplete="off" spellCheck={false} maxLength={character.nameMaxLength ?? 24} placeholder={i === 0 ? "e.g. Alex" : "e.g. Morgan"} aria-invalid={!!(touched[key] && errors[key])} aria-describedby={`hint-${key}`} disabled={busy} /><span id={`hint-${key}`} className={`creator__hint${touched[key] && errors[key] ? " creator__hint--error" : ""}`}>{touched[key] && errors[key] ? errors[key] : `${character.nameMinLength ?? 2}–${character.nameMaxLength ?? 24} characters`}</span></label>)}</div>
              <label className="creator__field creator__birth"><span>Date of birth<small>Optional</small></span><div className="creator__date"><Icon name="calendar" size={18} /><input name="birthDate" value={fields.birthDate ?? ""} onChange={e => set({ birthDate: e.target.value })} onBlur={() => setTouched(t => ({ ...t, birthDate: true }))} placeholder="YYYY-MM-DD" maxLength={10} inputMode="numeric" autoComplete="off" aria-invalid={!!(touched.birthDate && errors.birthDate)} aria-describedby="hint-birth" disabled={busy} />{fields.birthDate && !errors.birthDate && <span className="creator__age">{character.currentYear - Number(fields.birthDate.slice(0, 4))} years</span>}</div><span id="hint-birth" className={`creator__hint${touched.birthDate && errors.birthDate ? " creator__hint--error" : ""}`}>{touched.birthDate && errors.birthDate ? errors.birthDate : `The year is ${character.currentYear}. Choose an age between ${character.minAge} and ${character.maxAge ?? 90}, or leave this blank.`}</span></label>
              <div className="creator__note"><Icon name="info" size={18} /><p>A character, not a username.<span>Use a roleplay name. Numbers and special symbols are not accepted.</span></p></div>
            </>}
            {page === "background" && <>
              <fieldset className="creator__origins" disabled={busy}><legend>Place of origin <small>Optional</small></legend><div>{origins.map(o => <label className={`creator__origin${fields.origin === o.key ? " is-selected" : ""}`} key={o.key}><input type="radio" name="origin" value={o.key} checked={fields.origin === o.key} onChange={() => set({ origin: o.key })} /><Icon name="map-pin" size={17} /><span>{o.label}</span>{fields.origin === o.key && <Icon name="check" size={16} />}</label>)}</div></fieldset>
              <div className="creator__origin-note"><span>{fields.origin ? ORIGIN_NOTES[fields.origin] ?? "Your roots are part of the story. What comes next is up to you." : "Leave your past open, or choose where it began."}</span>{fields.origin && <button type="button" onClick={() => set({ origin: "" })} disabled={busy}>Clear</button>}</div>
              <label className="creator__field"><span>Your story<small>Optional</small></span><textarea name="story" value={fields.story ?? ""} onChange={e => set({ story: e.target.value })} maxLength={600} rows={4} placeholder="What brought you here? What are you looking for? A few lines are enough." disabled={busy} /><span className="creator__hint creator__story-hint"><span>No long biography needed. Leave room for what happens next.</span><span>{(fields.story ?? "").length} / 600</span></span></label>
            </>}
            {page === "appearance" && <>
              {!character.appearanceTracked && <div className="creator__note"><Icon name="info" /><p>Local session<span>Appearance persistence is unavailable on this server. This step is optional.</span></p></div>}
              <div className="creator__appearance-card"><Icon name="badge-check" size={26} /><div><span className="creator__eyebrow">Your appearance</span><strong>{character.bodyFamily === "female" ? "Feminine" : "Masculine"} · Saved</strong><p>The person in front of you. The rest is up to you.</p></div></div>
              <div className="creator__editor-guide"><Icon name={character.bodyFamily ? "badge-check" : "settings"} size={24} /><div><strong>{character.bodyFamily ? "An appearance is saved." : "The details make the difference."}</strong><p>Open the editor, customise your look, then confirm to return here. Cancelling keeps your previous look.</p></div></div>
              <button type="button" className="creator__button creator__button--primary creator__open-editor" disabled={!sceneReady} onClick={openEditor}>Open appearance editor<Icon name="arrow-right" size={18} /></button>
            </>}
            {page === "review" && <>
              <div className="creator__review"><div className="creator__review-name"><span className="creator__avatar">{character.firstName?.charAt(0)}{character.lastName?.charAt(0)}</span><div><small>Your identity</small><h3>{character.firstName} {character.lastName}</h3></div><button type="button" onClick={() => move("identity")} disabled={busy}>Edit<Icon name="chevron-right" size={14} /></button></div><dl><div><dt>Date of birth</dt><dd>{character.birthDate || "Not specified"}</dd></div><div><dt>Origin</dt><dd>{origins.find(o => o.key === character.origin)?.label || "Not specified"}</dd></div><div><dt>Appearance</dt><dd>{character.bodyFamily ? `${character.bodyFamily === "male" ? "Masculine" : "Feminine"} · Saved` : character.appearanceTracked ? "Not saved yet" : "Local session"}</dd></div></dl>{character.story && <p className="creator__review-story">{character.story}</p>}<button type="button" className="creator__text-button" onClick={() => move("appearance")} disabled={busy}>Revisit appearance<Icon name="chevron-right" size={14} /></button></div>
              <div className="creator__note"><Icon name="footprints" size={21} /><p>You're almost home.<span>After confirming, a quick welcome guide will help you find your feet.</span></p></div>
              {dirty && <div className="creator__feedback" role="alert">You have unsaved identity changes. Go back to Background and save them first.</div>}
            </>}
          </section>
        </div>
        <footer className="creator__footer">
          {(feedback || slow) && <div className="creator__feedback" role="alert"><Icon name="triangle-alert" size={17} /><span>{feedback || "Still waiting for the server. Your request has not been sent twice. If this continues, reconnect to resume your saved character."}</span></div>}
          <div className="creator__footer-actions"><button type="button" className="creator__back" disabled={index === 0 || busy} onClick={() => move(STEPS[index - 1]!.id)}><Icon name="chevron-left" size={17} />Back</button><span className="creator__footer-hint">{page === "identity" ? "Let's start with the essentials." : page === "background" ? "Your background is entirely up to you." : page === "appearance" ? (canReview ? "Ready when you are." : "Confirm your look in the editor to continue.") : "Your next chapter is waiting."}</span>
          {page === "appearance" ? <button type="button" className="creator__button creator__button--primary" disabled={!canReview} onClick={() => move("review")}>Review character<Icon name="arrow-right" size={18} /></button> : <button type="submit" className="creator__button creator__button--primary" disabled={busy || (page === "review" && (!canReview || dirty))}>{busy ? <><Icon name="loader" className="creator__spinner" />{sent === "character.finish" ? "Entering the city…" : "Saving identity…"}</> : <>{page === "review" ? "Enter Night City" : page === "background" ? "Save & continue" : "Continue"}<Icon name="arrow-right" size={18} /></>}</button>}</div>
        </footer>
      </form>
    </main>
    <footer className="creator__film-footer">
      <span className="creator__film-note">SAME STREETS. DIFFERENT STORIES.</span>
      <div className="creator__scene-state" role="status">{scene.phase === "error" ? <><span>{scene.error}</span><button type="button" onClick={() => emit(PAGE_EVENTS.creator, { retry: true })}>Retry scene</button></> : !["ready", "editor", "closed"].includes(scene.phase) ? <><Icon name="loader" className="creator__spinner" size={12} />Setting the scene…</> : null}</div>
      <div className="creator__scene-controls"><button type="button" aria-label="Reduce camera motion" aria-pressed={reduced} title={reduced ? "Resume camera movement" : "Hold the camera still"} onClick={() => setReduced(v => !v)}><Camera size={16} /><span>{reduced ? "STILL CAMERA" : "CINEMATIC"}</span></button><span className="creator__control-divider" /><button type="button" aria-label="Mute background music" aria-pressed={muted} onClick={() => setMuted(v => !v)}>{muted ? <VolumeX size={16} /> : <Volume2 size={16} />}<span>CLOUDY DAY</span><span className={`creator__equalizer${muted ? " is-muted" : ""}`} aria-hidden="true"><i /><i /><i /><i /></span></button></div>
    </footer>
  </div>;
}
