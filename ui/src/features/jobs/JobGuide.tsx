import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type JobGuidePage, type JobState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import { GuideDemo, hasGuideDemo } from "./guideDemos";
import "./job-guide.css";

/* The job guide: a guided modal, page by page, that explains the job the player
   holds. It opens by itself once the job center closes after a hire, and again
   from F1 → My job → Job guide. The pages are the job's `guide` in
   shared/jobs.lua; each names its picture (`demo`, guideDemos.tsx). */

export function JobGuide() {
  const open = useStore((s) => s.jobGuide);
  const close = useStore((s) => s.closeJobGuide);
  const job = useStore((s) => s.state.job);
  const pages = Array.isArray(job.guide) ? job.guide : [];
  const visible = !!open && open === job.name && pages.length > 0;
  // A guide queued for a job the player no longer holds is dropped.
  useEffect(() => { if (open && !visible) close(); }, [open, visible, close]);
  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [visible]);
  if (!visible) return null;
  return <JobGuideBody key={job.name} job={job} pages={pages} onClose={close} />;
}

function JobGuideBody({ job, pages, onClose }: { job: JobState; pages: JobGuidePage[]; onClose: () => void }) {
  const currency = useStore((s) => s.state.money.currency);
  const run = useStore((s) => s.state.jobRun);
  const [index, setIndex] = useState(0);
  const root = useRef<HTMLDivElement>(null);
  const page = pages[index]!;
  const last = index === pages.length - 1;
  const tips = Array.isArray(page.tips) ? page.tips : [];
  const canDispatch = !!job.run?.remote && !run?.active;
  const go = (next: number) => setIndex(Math.max(0, Math.min(pages.length - 1, next)));

  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") { event.preventDefault(); event.stopPropagation(); if (!event.repeat) onClose(); }
      else if (event.key === "ArrowRight" && !last) { event.preventDefault(); setIndex((i) => Math.min(pages.length - 1, i + 1)); }
      else if (event.key === "ArrowLeft") { event.preventDefault(); setIndex((i) => Math.max(0, i - 1)); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [last, pages.length, onClose]);

  const image = job.art?.image && /^img\/jobs\/[a-z0-9-]+\.(webp|png|jpg)$/.test(job.art.image) ? job.art.image : undefined;
  const salary = job.salary > 0 ? `${formatMoney(job.salary, currency)} / ${job.paycheckMinutes ?? 30} min` : null;

  return <div className="job-guide o77-interactive" role="dialog" aria-modal="true" aria-labelledby="job-guide-title" ref={root} tabIndex={-1}>
    <div className="job-guide__frame">
      <aside className="job-guide__side">
        {image && <img className="job-guide__art" src={image} alt="" draggable={false} />}
        <span className="job-guide__shade" />
        <div className="job-guide__who">
          <span className="job-guide__eyebrow"><i />JOB GUIDE</span>
          <span className="job-guide__tag">{job.tag}</span>
          <strong>{job.label}</strong>
          <small>{job.gradeLabel}{salary ? ` · ${salary}` : ""}</small>
        </div>
        <ol className="job-guide__steps" aria-label="Guide pages">
          {pages.map((p, i) => <li key={i}><button type="button" className={i === index ? "is-on" : i < index ? "is-seen" : ""}
            aria-current={i === index ? "step" : undefined} onClick={() => go(i)}>
            <b>{String(i + 1).padStart(2, "0")}</b><span>{p.title}</span>{i < index && <Icon name="check" size={13} />}</button></li>)}
        </ol>
      </aside>
      <section className="job-guide__main">
        <header className="job-guide__top">
          <span className="job-guide__count">{String(index + 1).padStart(2, "0")} <small>/ {String(pages.length).padStart(2, "0")}</small></span>
          <button type="button" className="job-guide__close" onClick={onClose}>Close <kbd>Esc</kbd><Icon name="x" size={16} /></button>
        </header>
        <div className="job-guide__stage" key={index}>
          {hasGuideDemo(page.demo) ? <GuideDemo id={page.demo!} job={job} currency={currency} />
            : <span className="job-guide__glyph"><Icon name={job.art?.icon ?? "briefcase"} size={64} /></span>}
        </div>
        <div className="job-guide__text" key={`t${index}`}>
          <h2 id="job-guide-title">{page.title}</h2>
          <p>{page.body}</p>
          {tips.length > 0 && <ul className="job-guide__tips">{tips.map((tip) => <li key={tip}><Icon name="info" size={13} />{tip}</li>)}</ul>}
        </div>
        <footer className="job-guide__nav">
          <button type="button" className="job-guide__back" disabled={index === 0} onClick={() => go(index - 1)}><Icon name="arrow-left" size={15} />Back</button>
          <span className="job-guide__dots" aria-hidden="true">{pages.map((_, i) => <i key={i} className={i === index ? "is-on" : i < index ? "is-seen" : ""} />)}</span>
          {!last ? <button type="button" className="job-guide__next" onClick={() => go(index + 1)}>Next<Icon name="arrow-right" size={16} /></button>
            : <span className="job-guide__end">
              {canDispatch && <button type="button" className="job-guide__alt" onClick={() => { sendAction({ type: "jobs.start", from: "menu" }); onClose(); }}>
                <Icon name="route" size={15} />Start my first run</button>}
              <button type="button" className="job-guide__next" onClick={onClose}>Got it<Icon name="check" size={16} /></button>
            </span>}
        </footer>
        <p className="job-guide__hint"><kbd>←</kbd><kbd>→</kbd> Pages · Find this guide again in <b>F1 → My job</b></p>
      </section>
    </div>
  </div>;
}
