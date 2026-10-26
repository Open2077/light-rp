import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./job-run.css";

export function JobRunHud() {
  const run = useStore((s) => s.state.jobRun);
  const hidden = useStore((s) => !!s.dialog || s.menuOpen || s.state.character.status !== "active" || s.state.character.welcomePending || (s.state.tutorial?.active && s.state.tutorial.step === "outro"));
  const currency = useStore((s) => s.state.money.currency);
  if (hidden) return null;
  if (!run?.active) return null;
  const index = run.index ?? 1, total = Math.max(1, run.total ?? 1);
  return <aside className="job-run" aria-label="Current work order">
    <div className="job-run__heading"><Icon name={run.icon ?? "briefcase"} size={17} /><span>{run.label}</span><b>{String(index).padStart(2, "0")} / {String(total).padStart(2, "0")}</b></div>
    <div className="job-run__objective" key={`${run.id}:${index}`} aria-live="polite"><h2>{run.objective?.label}</h2><p>{run.busy ? "Confirming with dispatch…" : run.working ? "Work in progress. Stay at the marked point." : run.hint}</p></div>
    <div className="job-run__track" role="progressbar" aria-label="Work order progress" aria-valuenow={index - 1} aria-valuemin={0} aria-valuemax={total}><i style={{ width: `${(index - 1) / total * 100}%` }} /></div>
    <footer><span>{formatMoney(run.reward ?? 0, currency)} <small>on completion</small></span><span><kbd>/job gps</kbd><kbd>/job cancel</kbd></span></footer>
  </aside>;
}
