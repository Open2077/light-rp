import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type JobCenterDialogPayload } from "@/bridge/protocol";
import { Badge, Button, HazardStripe, Icon, Keycap, ListRow } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./jobcenter.css";

/* The job center desk, opened by the server when the player presses E at the
   clerk (lightrp:ui:dialog, kind "jobcenter"). The offers come with the
   payload; the current job comes from the state. Applying sets the job at its
   entry grade; quitting goes back to unemployed. The server validates both. */

export function JobCenterDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "jobcenter";

  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape" && !e.repeat) { e.preventDefault(); closeDialog(); } };
    window.addEventListener("keydown", onKey);
    return () => { window.removeEventListener("keydown", onKey); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, closeDialog]);

  if (!visible || !dialog) return null;
  return <JobCenterBody payload={dialog as JobCenterDialogPayload} onClose={closeDialog} />;
}

function JobCenterBody({ payload, onClose }: { payload: JobCenterDialogPayload; onClose: () => void }) {
  const job = useStore((s) => s.state.job);
  const money = useStore((s) => s.state.money);
  const lastResult = useStore((s) => s.lastResult);
  const [sent, setSent] = useState<string | null>(null);
  const spot = payload.spot;
  const employed = job.name !== "unemployed";

  useEffect(() => {
    if (!lastResult || !sent || lastResult.at < Date.now() - 10000) return;
    if (lastResult.action === sent) { setSent(null); if (lastResult.ok && sent === "jobs.apply") onClose(); }
  }, [lastResult, sent, onClose]);

  return (
    <div className="jobcenter o77-interactive" role="dialog" aria-modal="true" aria-labelledby="jobcenter-title">
      <div className="jobcenter__frame">
        <header className="jobcenter__head">
          <span className="jobcenter__head-icon"><Icon name="briefcase" size={16} /></span>
          <div className="jobcenter__head-text">
            <span className="o77-tag o77-accent">JOB CENTER · PAYCHECK EVERY {payload.paycheckMinutes} MIN</span>
            <h1 id="jobcenter-title" className="jobcenter__title">{spot.name}</h1>
          </div>
          <Button variant="ghost" size="sm" icon="x" onClick={onClose}>Close</Button>
        </header>
        <HazardStripe height={4} />

        <div className="jobcenter__body">
          <section className={"jobcenter__current" + (employed ? "" : " jobcenter__current--none")}>
            <div className="jobcenter__current-text">
              <span className="o77-readout o77-accent">CURRENT JOB</span>
              <span className="jobcenter__current-label">{employed ? job.label : "Unemployed"}</span>
              <span className="o77-readout o77-dim">
                {employed ? `${job.gradeLabel.toUpperCase()} · GRADE ${job.grade}${job.salary > 0 ? ` · ${formatMoney(job.salary, money.currency)} / ${payload.paycheckMinutes} MIN` : ""}` : "PICK A JOB BELOW TO START EARNING"}
              </span>
            </div>
            {employed && (
              <Button variant="danger" size="sm" icon="x" disabled={sent !== null}
                onClick={() => { setSent("jobs.quit"); sendAction({ type: "jobs.quit" }); }}>Quit job</Button>
            )}
          </section>

          <div className="jobcenter__list">
            {payload.jobs.map((offer) => {
              const current = offer.name === job.name;
              return (
                <ListRow key={offer.name} icon="briefcase" title={offer.label}
                  subtitle={`${offer.tag} · STARTS AS ${offer.entryGrade.label.toUpperCase()} · ${offer.grades} GRADE${offer.grades > 1 ? "S" : ""}`}
                  meta={<span className="jobcenter__pay">{offer.entryGrade.salary > 0 ? `${formatMoney(offer.entryGrade.salary, money.currency)} / ${payload.paycheckMinutes} MIN` : "UNPAID"}</span>}
                  right={current ? <Badge tone="accent">CURRENT</Badge> : (
                    <Button size="sm" variant="primary" disabled={sent !== null}
                      onClick={() => { setSent("jobs.apply"); sendAction({ type: "jobs.apply", spot: spot.id, job: offer.name }); }}>Apply</Button>
                  )} />
              );
            })}
            {payload.jobs.length === 0 && <span className="o77-readout o77-disabled">NO OPENINGS RIGHT NOW</span>}
          </div>
        </div>

        <footer className="jobcenter__foot">
          <span className="o77-readout o77-disabled"><Keycap size="sm">ESC</Keycap> CLOSE · ONE JOB AT A TIME · YOUR GRADE STARTS AT THE ENTRY LEVEL</span>
        </footer>
      </div>
    </div>
  );
}
