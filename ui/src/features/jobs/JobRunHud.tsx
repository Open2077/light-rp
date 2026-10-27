import { useEffect, useMemo, useState } from "react";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS, type JobRunLive, type JobRunState, type JobRunStop, type JobStopKind } from "@/bridge/protocol";
import "./job-run.css";

/* The work order tracker, docked right: a dispatch sheet. The next stop and how
   far it is, every stop of the route (a courier's orders as pickup → drop-off
   pairs), the pay, the time left, and where the options are (the player menu:
   GPS, abandon, quit). The page only displays: the server owns the run. */

const KIND: Record<JobStopKind, { tag: string; icon: string }> = {
  pickup: { tag: "PICK UP", icon: "package" },
  dropoff: { tag: "DELIVER", icon: "house" },
  work: { tag: "TASK", icon: "wrench" },
  lift: { tag: "ACCESS", icon: "arrow-down" },
  return: { tag: "RETURN", icon: "building-2" },
};

function clock(ms: number): string {
  const s = Math.max(0, Math.ceil(ms / 1000));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

/** Time left, counted down locally from the last snapshot. */
function useTimeLeft(run: JobRunState | undefined): number | null {
  const [now, setNow] = useState(() => Date.now());
  const [base, setBase] = useState<{ at: number; ms: number } | null>(null);
  useEffect(() => {
    setBase(typeof run?.expiresInMs === "number" ? { at: Date.now(), ms: run.expiresInMs } : null);
  }, [run?.id, run?.index, run?.expiresInMs]);
  useEffect(() => {
    if (!base) return;
    const t = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, [base]);
  return base ? base.ms - (now - base.at) : null;
}

function Glyph({ state }: { state: JobRunStop["state"] }) {
  return <i className={`wo-glyph is-${state}`} aria-hidden>{state === "done" ? <Icon name="check" size={11} /> : null}</i>;
}

/** A courier's orders: pickup → drop-off on one line. Other routes: their stops. */
function Manifest({ stops, orders }: { stops: JobRunStop[]; orders?: number }) {
  if (orders) {
    const rows = Array.from({ length: orders }, (_, i) => ({
      n: i + 1,
      pickup: stops.find((s) => s.kind === "pickup" && s.order === i + 1),
      dropoff: stops.find((s) => s.kind === "dropoff" && s.order === i + 1),
    }));
    return <ol className="wo-manifest">
      {rows.map((r) => {
        const live = r.pickup?.state === "now" || r.dropoff?.state === "now";
        const done = r.dropoff?.state === "done";
        return <li key={r.n} className={`${live ? "is-live" : ""} ${done ? "is-done" : ""}`}>
          <b>{String(r.n).padStart(2, "0")}</b>
          <span className="wo-leg"><Glyph state={r.pickup?.state ?? "todo"} /><em>{r.pickup?.place ?? "—"}</em></span>
          <Icon name="arrow-right" size={12} className="wo-arrow" />
          <span className="wo-leg"><Glyph state={r.dropoff?.state ?? "todo"} /><em>{r.dropoff?.place ?? "—"}</em></span>
        </li>;
      })}
    </ol>;
  }
  return <ol className="wo-manifest wo-manifest--steps">
    {stops.map((s, i) => <li key={i} className={s.state === "now" ? "is-live" : s.state === "done" ? "is-done" : ""}>
      <b>{String(i + 1).padStart(2, "0")}</b>
      <span className="wo-leg"><Glyph state={s.state} /><em>{s.place}</em></span>
    </li>)}
  </ol>;
}

export function JobRunHud() {
  const run = useStore((s) => s.state.jobRun);
  const hidden = useStore((s) => !!s.dialog || s.menuOpen || s.state.character.status !== "active" || s.state.character.welcomePending || (s.state.tutorial?.active && s.state.tutorial.step === "outro"));
  const currency = useStore((s) => s.state.money.currency);
  const [live, setLive] = useState<JobRunLive>({ distance: false, menuKey: "F1", gps: false });
  useEffect(() => on<JobRunLive>(PAGE_EVENTS.jobRun, (p) => setLive((l) => ({ ...l, ...p }))), []);
  const left = useTimeLeft(run);
  const stops = useMemo(() => run?.stops ?? [], [run?.stops]);
  if (hidden || !run?.active) return null;

  const objective = run.objective;
  const kind = KIND[objective?.kind ?? "work"] ?? KIND.work;
  const index = run.index ?? 1, total = Math.max(1, run.total ?? stops.length ?? 1);
  const order = stops[index - 1]?.order;
  const near = typeof live.distance === "number" && live.distance <= Math.max(3, objective?.radius ?? 3);
  const delivered = stops.filter((s) => s.kind === "dropoff" && s.state === "done").length;
  const status = run.busy ? "Confirming with dispatch…" : run.working ? "Working · stay on the marker" : null;
  const lastStop = index === total;

  return <aside className={`wo ${near ? "is-near" : ""}`} aria-label="Current work order">
    <header className="wo-head">
      <span className="wo-stamp">WORK ORDER</span>
      <span className="wo-job"><Icon name={run.icon ?? "briefcase"} size={13} />{run.jobLabel ?? run.label}</span>
      {left != null && <span className={`wo-timer ${left < 180000 ? "is-low" : ""}`}><Icon name="timer" size={12} />{clock(left)}</span>}
    </header>
    <div className="wo-hazard" aria-hidden />

    <section className="wo-next" key={`${run.id}:${index}`} aria-live="polite">
      <div className="wo-next__tag">
        <span><Icon name={kind.icon} size={13} />{kind.tag}{order ? ` · ${String(order).padStart(2, "0")}` : ""}</span>
        <b>STOP {String(index).padStart(2, "0")}<small>/{String(total).padStart(2, "0")}</small></b>
      </div>
      <h2>{objective?.place ?? objective?.label}</h2>
      <div className="wo-next__read">
        {near
          ? <span className="wo-press"><kbd>E</kbd>{kind.tag === "DELIVER" ? "Hand over the order" : kind.tag === "PICK UP" ? "Collect the order" : "Start the task"}</span>
          : <span className="wo-dist"><Icon name="navigation" size={14} />{typeof live.distance === "number" ? <><b>{live.distance >= 1000 ? (live.distance / 1000).toFixed(1) : live.distance}</b>{live.distance >= 1000 ? "KM" : "M"}</> : <b>—</b>}{live.gps ? <i>GPS ON</i> : <i className="is-off">NO ROUTE · {live.menuKey} › GPS</i>}</span>}
      </div>
      <p>{status ?? run.hint}</p>
    </section>

    <div className="wo-cells" role="progressbar" aria-label="Route progress" aria-valuenow={index - 1} aria-valuemin={0} aria-valuemax={total}>
      {stops.map((s, i) => <i key={i} className={`is-${s.state}`} />)}
    </div>

    {stops.length > 0 && <section className="wo-list">
      <div className="wo-list__head"><span>MANIFEST</span>{run.orders
        ? <b>{run.carried ?? 0} CARRIED · {delivered}/{run.orders} DELIVERED{run.distanceKm ? ` · ${run.distanceKm} KM` : ""}</b>
        : <b>{index - 1}/{total} DONE</b>}</div>
      <Manifest stops={stops} orders={run.orders} />
    </section>}

    <footer className="wo-foot">
      <div className="wo-pay"><b>{formatMoney(run.reward ?? 0, currency)}</b><span>{lastStop ? "ON THIS DROP" : "ON THE LAST STOP"}</span></div>
      <div className="wo-menu"><kbd>{live.menuKey}</kbd><span>MY JOB<small>GPS · ABANDON</small></span></div>
    </footer>
  </aside>;
}
