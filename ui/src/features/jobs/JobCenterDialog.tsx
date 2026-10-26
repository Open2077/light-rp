import { useEffect, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type JobCenterDialogPayload, type JobOffer, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./jobcenter.css";

export function JobCenterDialog() {
  const dialog = useStore((s) => s.dialog);
  const close = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "jobcenter";
  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    emit(PAGE_EVENTS.dialogState, { kind: "jobcenter", open: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "jobcenter") close(); });
    return () => { off(); emit(PAGE_EVENTS.dialogState, { kind: "jobcenter", open: false }); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "jobcenter") return null;
  return <JobCenterBody key={dialog.spot.id} payload={dialog} onClose={close} />;
}

function JobArt({ offer }: { offer: JobOffer }) {
  const [failed, setFailed] = useState(false);
  // Only images shipped inside this resource, never arbitrary payload URLs.
  const path = offer.recruitment?.image;
  const safe = path && /^img\/jobs\/[a-z0-9-]+\.(webp|png|jpg)$/.test(path);
  return safe && !failed
    ? <img className="job-card__art" src={path} alt="" draggable={false} onError={() => setFailed(true)} />
    : <span className="job-card__art job-card__fallback"><Icon name={offer.recruitment?.icon ?? "briefcase"} size={100} /></span>;
}

function JobCenterBody({ payload, onClose }: { payload: JobCenterDialogPayload; onClose: () => void }) {
  const job = useStore((s) => s.state.job);
  const run = useStore((s) => s.state.jobRun);
  const currency = useStore((s) => s.state.money.currency);
  const result = useStore((s) => s.lastResult);
  const root = useRef<HTMLDivElement>(null);
  const confirmation = useRef<HTMLDivElement>(null);
  const [selected, setSelected] = useState(() => payload.jobs.find((entry) => entry.name === job.name)?.name ?? payload.jobs[0]?.name ?? "");
  const [confirm, setConfirm] = useState<"apply" | "quit" | "cancel" | null>(null);
  const [sent, setSent] = useState<string | null>(null);
  const pending = useRef<string | null>(null);
  const resultBefore = useRef(result);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean } | null>(null);
  const offer = payload.jobs.find((entry) => entry.name === selected) ?? payload.jobs[0];
  const employed = job.name !== "unemployed";
  const current = offer?.name === job.name;
  const fmt = (value: number) => formatMoney(value, currency);
  const pays = payload.paycheckMinutes > 0;

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => {
    if (!confirm) return;
    const previous = document.activeElement as HTMLElement | null;
    confirmation.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, [confirm]);
  useEffect(() => {
    if (!result || result === resultBefore.current || result.action !== pending.current) return;
    const action = pending.current;
    resultBefore.current = result; pending.current = null; setSent(null);
    setFeedback({ text: result.text, error: !result.ok });
    if (result.ok) { setConfirm(null); if (action === "jobs.start" || action === "jobs.locate") onClose(); }
  }, [result, onClose]);
  useEffect(() => {
    if (!sent) return;
    const timer = window.setTimeout(() => setFeedback({ text: "Still waiting for the server. Close and reopen the desk to check your job before trying again.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [sent]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault(); event.stopPropagation();
        if (!event.repeat) { if (confirm && !pending.current) setConfirm(null); else onClose(); }
      }
      if (event.key === "Tab") {
        const scope = confirm ? confirmation.current : root.current;
        const controls = Array.from(scope?.querySelectorAll<HTMLElement>('button:not(:disabled), [tabindex="0"]') ?? [])
          .filter((el) => el.getClientRects().length > 0);
        const first = controls[0], last = controls[controls.length - 1];
        if (!controls.length) { event.preventDefault(); scope?.focus(); }
        else if (event.shiftKey && (document.activeElement === first || document.activeElement === scope)) { event.preventDefault(); last?.focus(); }
        else if (!event.shiftKey && (document.activeElement === last || document.activeElement === scope)) { event.preventDefault(); first?.focus(); }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [confirm, onClose]);

  const select = (name: string) => { if (!confirm && !pending.current) setSelected(name); };
  const issue = (action: UiAction) => {
    if (pending.current) return;
    pending.current = action.type; resultBefore.current = useStore.getState().lastResult;
    setSent(action.type); setFeedback(null); sendAction(action);
  };
  const browseKey = (event: ReactKeyboardEvent<HTMLButtonElement>, index: number) => {
    let next: number;
    if (event.key === "ArrowRight") next = (index + 1) % payload.jobs.length;
    else if (event.key === "ArrowLeft") next = (index - 1 + payload.jobs.length) % payload.jobs.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = payload.jobs.length - 1;
    else return;
    event.preventDefault(); root.current?.querySelectorAll<HTMLButtonElement>(".job-card")[next]?.focus();
  };

  return <div className="jobcenter o77-interactive" role="dialog" aria-modal="true" aria-labelledby="jobcenter-title" ref={root} tabIndex={-1}>
    <div className="jobcenter__workspace" aria-hidden={confirm ? true : undefined} {...(confirm ? { inert: "" } : {})}>
      <header className="jobcenter__header">
        <div><span className="jobcenter__eyebrow"><i />LIGHT RP / EMPLOYMENT OFFICE</span><h1 id="jobcenter-title">The city needs <em>you.</em></h1><p>Three ways to make a living. Find your kind of work.</p></div>
        <button className="jobcenter__close" onClick={onClose}>Back to the city <kbd>Esc</kbd><Icon name="x" size={18} /></button>
      </header>
      <div className="jobcenter__location"><span><Icon name="map-pin" size={14} />{payload.spot.name}</span><span>{String(payload.jobs.length).padStart(2, "0")} OPEN POSITIONS <b /> NO EXPERIENCE REQUIRED</span></div>
      <section className="jobcenter__cards" aria-label="Available jobs">
        {payload.jobs.map((entry, index) => {
          const active = offer?.name === entry.name;
          const info = entry.recruitment;
          return <button type="button" key={entry.name} className={`job-card${active ? " is-active" : ""}`}
            aria-label={`Explore ${entry.label}`} aria-expanded={active} aria-controls={`job-details-${entry.name}`}
            onMouseEnter={() => select(entry.name)} onFocus={() => select(entry.name)} onClick={() => select(entry.name)} onKeyDown={(event) => browseKey(event, index)}>
            <JobArt offer={entry} /><span className="job-card__shade" />
            <span className="job-card__top"><span className="job-card__number">0{index + 1}<small>/ 0{payload.jobs.length}</small></span><Icon name={info?.icon ?? "briefcase"} size={24} /></span>
            {job.name === entry.name && <span className="job-card__current"><Icon name="check" size={12} /> YOUR JOB</span>}
            <span className="job-card__copy">
              <span className="job-card__tag">{entry.tag}</span><span className="job-card__title">{entry.label}</span>
              <span className="job-card__headline">{info?.headline ?? "Find your place in Night City."}</span>
              <span id={`job-details-${entry.name}`} className="job-card__details" hidden={!active}>
                <span className="job-card__description">{info?.description ?? `Join as ${entry.entryGrade.label}.`}</span>
                {Array.isArray(info?.steps) && <span className="job-card__steps">{info.steps.map((step, i) => <span key={step}><b>0{i + 1}</b>{step}</span>)}</span>}
              </span>
              <span className="job-card__bottom"><span><Icon name="map-pin" size={13} />{info?.environment ?? "Night City"}</span><span className="job-card__expand"><Icon name={active ? "check" : "arrow-right"} size={18} /></span></span>
            </span>
          </button>;
        })}
        {!payload.jobs.length && <div className="jobcenter__empty"><Icon name="briefcase" size={40} /><h2>No openings right now.</h2><p>Check back at this desk later. Your current job is unchanged.</p></div>}
      </section>
      <footer className="jobcenter__contract">
        <div className="jobcenter__employment"><span className="jobcenter__eyebrow">YOUR CURRENT JOB</span><strong>{employed ? job.label : "A fresh start."}</strong>
          {employed ? <button className="jobcenter__text" disabled={!!sent} onClick={() => { setFeedback(null); setConfirm("quit"); }}>Leave this job <Icon name="arrow-right" size={13} /></button> : <small>You are not employed yet.</small>}
        </div>
        {offer && <><div className="jobcenter__terms"><span className="jobcenter__eyebrow">{current ? "YOUR GRADE" : "STARTING GRADE"}</span><strong>{current ? job.gradeLabel : offer.entryGrade.label}</strong><small>{offer.grades} career grades</small></div>
          <div className="jobcenter__terms"><span className="jobcenter__eyebrow">{offer.work?"SELL FINISHED GOODS":"COMPLETE A RUN"}</span><strong>{offer.work?`${fmt(offer.work.price)} / unit`:offer.route ? fmt(offer.route.reward) : "Not available"}</strong><small>{offer.work?`${offer.work.inputCount} ${offer.work.raw} → ${offer.work.outputCount} ${offer.work.product}`:offer.route ? `${offer.route.stops} tasks · ${offer.route.estimate} · Bank payment` : "No route configured"}</small></div>
          {offer.work?<button className="jobcenter__primary" disabled={!!sent} onClick={()=>issue({type:"jobs.locate",job:offer.name,stage:"collect"})}>{sent?"Setting GPS…":"Find a collection point"}<Icon name="map-pin" size={19}/></button>:
          <button className="jobcenter__primary" disabled={!!sent || (current && !offer.route && !run?.active)} onClick={() => {
            setFeedback(null);
            if (!current) setConfirm("apply");
            else if (run?.active) onClose();
            else issue({ type: "jobs.start" });
          }}>{sent === "jobs.start" ? "Requesting route…" : current ? run?.active ? "Continue my run" : "Start a run" : `Choose ${offer.label}`}<Icon name="arrow-right" size={19} /></button>}</>}
      </footer>
      {offer?.work&&<div className="jobcenter__footnote"><span>FREE ACTIVITY · No shift or employment required · {offer.work.collectWeight} kg per collection</span><div className="jobcenter__work-links">
        <button className="jobcenter__text" disabled={!!sent} onClick={()=>issue({type:"jobs.locate",job:offer.name,stage:"process"})}>Processing GPS <Icon name="hammer" size={14}/></button>
        <button className="jobcenter__text" disabled={!!sent} onClick={()=>issue({type:"jobs.locate",job:offer.name,stage:"sell"})}>Buyer GPS <Icon name="banknote" size={14}/></button>
        {!current&&<button className="jobcenter__text" disabled={!!sent} onClick={()=>{setFeedback(null);setConfirm("apply");}}>Choose as my job <Icon name="briefcase" size={14}/></button>}
      </div></div>}
      <div className="jobcenter__footnote"><span><kbd>←</kbd><kbd>→</kbd> Explore jobs <span>·</span> Hover or focus to discover</span>
        {run?.active ? <button className="jobcenter__text" disabled={!!sent || run.busy} onClick={() => setConfirm("cancel")}>Cancel current run · No payment <Icon name="x" size={13} /></button>
          : <span>{offer?.work?"Collect → Process → Sell · Keep your items between sessions":"AC maintenance · GPS included · Paid on completion"}</span>}</div>
      {feedback && !confirm && <p className={`jobcenter__feedback${feedback.error ? " is-error" : ""}`} role={feedback.error ? "alert" : "status"}>{feedback.text}</p>}
    </div>
    {confirm && <div className="jobcenter__veil"><div className="jobcenter__confirm" ref={confirmation} tabIndex={-1} role="alertdialog" aria-modal="true" aria-labelledby="job-confirm-title" aria-describedby="job-confirm-description" aria-busy={!!sent}>
      <span className="jobcenter__confirm-icon"><Icon name={confirm === "quit" ? "briefcase" : offer?.recruitment?.icon ?? "briefcase"} size={28} /></span>
      <span className="jobcenter__eyebrow">{confirm === "quit" ? "LEAVE YOUR JOB" : "YOUR NEXT CHAPTER"}</span>
      <h2 id="job-confirm-title">{confirm === "cancel" ? "Abandon this run?" : confirm === "quit" ? `Leave ${job.label}?` : `Join ${offer?.label}?`}</h2>
      <p id="job-confirm-description">{confirm === "cancel" ? "Your progress will be lost and no payment will be issued. Your job stays unchanged and rooftop service exits remain available." : confirm === "quit" ? "You will become unemployed and stop receiving this salary. Any unfinished run is cancelled. Joining again starts at the entry grade." : `${employed ? `This replaces ${job.label} and cancels any unfinished run. ` : ""}You start as ${offer?.entryGrade.label}. Your existing grade will not carry over.`}</p>
      {confirm === "apply" && <div className="jobcenter__confirm-pay"><span>Starting bank paycheck</span><strong>{pays ? `${fmt(offer?.entryGrade.salary ?? 0)} / ${payload.paycheckMinutes} min` : "Automatic salary disabled"}</strong></div>}
      {feedback && <p className={`jobcenter__feedback${feedback.error ? " is-error" : ""}`} role={feedback.error ? "alert" : "status"}>{feedback.text}</p>}
      <button className="jobcenter__primary" disabled={!!sent || (confirm === "apply" && (!offer || current))} onClick={() => {
        if (confirm === "quit") issue({ type: "jobs.quit" });
        else if (confirm === "cancel") issue({ type: "jobs.cancel" });
        else if (offer && !current) issue({ type: "jobs.apply", spot: payload.spot.id, job: offer.name });
      }}>{sent ? "Waiting for the server…" : confirm === "cancel" ? "Cancel this run" : confirm === "quit" ? "Confirm leaving" : "Confirm job"}<Icon name={sent ? "loader" : "check"} size={18} /></button>
      <button className="jobcenter__cancel" onClick={() => { if (pending.current) onClose(); else setConfirm(null); }}>{sent ? "Close and check later" : "Keep browsing"}</button>
    </div></div>}
  </div>;
}
