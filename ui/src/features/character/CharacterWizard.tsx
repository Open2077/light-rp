import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type BodyFamily, type CharacterState, type IdentityFields, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { identityFields, initialPage, ORIGIN_NOTES, STEPS, validateIdentity, type WizardPage } from "./model";
import "./wizard.css";

export function CharacterWizard() {
  const character = useStore(s => s.state.character);
  const connected = useStore(s => s.connected);
  if (!connected || character.status === "active") return null;
  return <WizardBody key={`${character.playerId}:${character.key}`} character={character} />;
}

function WizardBody({ character }: { character: CharacterState }) {
  const [page, setPage] = useState<WizardPage>(() => initialPage(character));
  const [fields, setFields] = useState(() => identityFields(character));
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [family, setFamily] = useState<BodyFamily>(character.bodyFamily ?? "male");
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
  const bodyChanged = !!character.bodyFamily && family !== character.bodyFamily;
  const set = (patch: Partial<IdentityFields>) => { setFields(f => ({ ...f, ...patch })); setFeedback(""); };
  const move = (next: WizardPage) => { if (!pending.current) { setPage(next); setFeedback(""); } };

  useEffect(() => {
    emit(PAGE_EVENTS.focus, { active: !editor });
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [editor]);
  useEffect(() => on<{ active: boolean; error?: string }>(PAGE_EVENTS.characterEditor, value => {
    setEditor(value.active === true);
    if (value.error) setFeedback(value.error);
  }), []);
  useEffect(() => {
    const previous = previousCharacter.current;
    previousCharacter.current = character;
    if (previous.step !== character.step || previous.appearanceRevision !== character.appearanceRevision) {
      if (pending.current !== "character.identity") setPage(initialPage(character));
    }
    if (character.bodyFamily) setFamily(character.bodyFamily);
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
    if (editor) return;
    heading.current?.focus();
    root.current?.querySelector(".creator__scroll")?.scrollTo(0, 0);
  }, [page, editor]);
  useEffect(() => {
    if (editor) return;
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
  }, [editor]);

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
  const title = { identity: "Every story starts with a name.", background: "Where are you coming from?", appearance: "Put a face to the name.", review: `Welcome to Night City${character.firstName ? `, ${character.firstName}` : ""}.` }[page];
  const subtitle = { identity: "This is who other players will meet. Your account name stays separate.", background: "A little context makes a character yours. Both of these choices are optional.", appearance: "Choose a body, then shape your look in the character editor.", review: "One last look before your story begins. You can go back and change anything." }[page];
  const name = `${fields.firstName} ${fields.lastName}`.trim();

  return <div ref={root} className={`creator o77-interactive${editor ? " creator--editor" : ""}`} role="dialog" aria-modal={!editor} aria-labelledby="creator-title" aria-hidden={editor || undefined}>
    <aside className="creator__scene">
      <div className="creator__brand"><span className="creator__brand-mark">LIGHT<span>/</span>RP</span><span>A new life in Night City</span></div>
      <div className="creator__scene-copy"><span className="creator__eyebrow">Your city. Your story.</span><h1>Not another face<br />in the crowd.<br /><em>Yours.</em></h1><p>Find your people. Make your own way.<br />Leave something behind.</p></div>
      <div className="creator__passport"><span className="creator__avatar">{fields.firstName.trim().charAt(0).toUpperCase() || "?"}{fields.lastName.trim().charAt(0).toUpperCase()}</span><div><span className="creator__eyebrow">Your character</span><strong>{name || "A new beginning"}</strong><span>{origin || "A story still unwritten"}</span></div><Icon name="arrow-right" size={20} /></div>
      <div className="creator__scene-foot"><span>Night City / {character.currentYear}</span><span>Make yourself at home.</span></div>
    </aside>
    <main className="creator__main">
      <header className="creator__top"><span>Character creation</span><span>{character.key === "default" ? "Character 01" : `Character ${character.key.replace("slot", "").padStart(2, "0")}`}</span></header>
      <nav aria-label="Character creation steps" className="creator__nav"><ol>{STEPS.map((s, i) => <li key={s.id}><button type="button" aria-current={page === s.id ? "step" : undefined} disabled={busy || i > index} onClick={() => move(s.id)}><span className="creator__step-num">{i < index ? <Icon name="check" size={14} /> : i + 1}</span><span>{s.label}</span></button></li>)}</ol><div className="creator__progress"><i style={{ width: `${(index + 1) * 25}%` }} /></div></nav>
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
              <fieldset className="creator__bodies"><legend>Body type</legend><div>{(["male", "female"] as const).map(body => <label key={body} className={`creator__body${family === body ? " is-selected" : ""}`}><input type="radio" name="body" value={body} checked={family === body} onChange={() => setFamily(body)} /><span className="creator__body-art"><Icon name="user" size={64} /></span><span><strong>{body === "male" ? "Masculine" : "Feminine"}</strong><small>Face, hair & details in the editor</small></span><span className="creator__radio">{family === body && <i />}</span></label>)}</div></fieldset>
              <div className="creator__editor-guide"><Icon name={character.bodyFamily ? "badge-check" : "settings"} size={24} /><div><strong>{character.bodyFamily ? "An appearance is saved." : "The details make the difference."}</strong><p>Open the editor, customise your look, then confirm to return here. Cancelling keeps your previous look.</p></div></div>
              <button type="button" className="creator__button creator__button--primary creator__open-editor" onClick={openEditor}>Open appearance editor<Icon name="arrow-right" size={18} /></button>
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
          <div className="creator__footer-actions"><button type="button" className="creator__back" disabled={index === 0 || busy} onClick={() => move(STEPS[index - 1]!.id)}><Icon name="chevron-left" size={17} />Back</button><span className="creator__footer-hint">{page === "identity" ? "Let's start with the essentials." : page === "background" ? "Your background is entirely up to you." : page === "appearance" ? (canReview && !bodyChanged ? "Ready when you are." : "Confirm your look in the editor to continue.") : "Your next chapter is waiting."}</span>
          {page === "appearance" ? <button type="button" className="creator__button creator__button--primary" disabled={!canReview || bodyChanged} onClick={() => move("review")}>Review character<Icon name="arrow-right" size={18} /></button> : <button type="submit" className="creator__button creator__button--primary" disabled={busy || (page === "review" && (!canReview || dirty))}>{busy ? <><Icon name="loader" className="creator__spinner" />{sent === "character.finish" ? "Entering the city…" : "Saving identity…"}</> : <>{page === "review" ? "Enter Night City" : page === "background" ? "Save & continue" : "Continue"}<Icon name="arrow-right" size={18} /></>}</button>}</div>
        </footer>
      </form>
    </main>
  </div>;
}
