/* The Kiroshi installation sequence: a fixed ~16 s timeline (shorter with
   reduced motion) driving seven scenes, the stage rail and the global
   percentage. `implant.install` goes out when the insertion starts; the
   timeline runs its full length whatever the server does, and the last stage
   waits for the reply. A failure hands the slug back to the gate. */
import { useEffect, useRef, useState } from "react";
import { Check, X } from "lucide-react";
import { request, RequestError } from "@/bridge/open77";
import type { ImplantState } from "@/bridge/protocol";
import { play } from "@/fx/sound";
import { userClose } from "@/store/actions";
import { useStore } from "@/store/store";
import { reducedMotion } from "@/shell/Stage";
import { buildPlan, STAGE_INDEX, type Plan } from "./timeline";
import { IrisGlyph } from "./Kiroshi";
import { BootScene, CalibrateScene, FlashScene, IdentityScene, InsertScene, OnlineScene, SynapseScene } from "./stages";

/** The page gives up on the reply this long after asking (Lua's own timeout is 15-20 s). */
const REPLY_TIMEOUT_MS = 22_000;
const LEAVE_MS = 420;

export interface InstallProps {
  /** Stage to start from: 0, or the insertion on a retry. */
  from: number;
  onFailed(slug: string): void;
}

export function Install({ from, onFailed }: InstallProps) {
  const [plan] = useState<Plan>(() => buildPlan(reducedMotion()));
  const [stage, setStage] = useState(from);
  const [leaving, setLeaving] = useState<number | null>(null);
  const [holding, setHolding] = useState(false);
  const pctRef = useRef<HTMLSpanElement>(null);
  const barRef = useRef<HTMLSpanElement>(null);
  const failed = useRef(onFailed);
  failed.current = onFailed;
  const implant = useStore((s) => s.state?.implant);
  const line = useStore((s) => s.state?.line);
  const model = implant?.model || "Kiroshi NL-77 Synapse";
  const name = line?.name || "Unknown citizen";

  // The driver: one rAF loop for the clock, cues, request, hold and the percentage.
  useEffect(() => {
    let alive = true;
    let raf = 0;
    const begin = plan.stages[from]!.start;
    const online = plan.stages[STAGE_INDEX.online]!;
    const insert = plan.stages[STAGE_INDEX.insert]!;
    let t0 = performance.now() - begin;
    let shown = from;
    let asked = false;
    let reply: { implant: ImplantState | null } | null = null;
    let held = false;
    const fired = new Set<number>();
    plan.cues.forEach((c, i) => { if (c.at < begin) fired.add(i); });

    const ask = () => {
      asked = true;
      let timer = 0;
      const timeout = new Promise<never>((_, reject) => { timer = window.setTimeout(() => reject(new RequestError("timeout")), REPLY_TIMEOUT_MS); });
      Promise.race([request("implant.install", {}), timeout]).then(
        (data) => { if (alive) reply = { implant: data?.implant && typeof data.implant === "object" ? data.implant : null }; },
        (err) => { if (alive) { alive = false; failed.current(err instanceof RequestError ? err.slug : "unknown"); } },
      ).finally(() => window.clearTimeout(timer));
    };

    const frame = (now: number) => {
      if (!alive) return;
      let e = now - t0;
      if (!asked && e >= insert.start) ask();
      // the last stage starts only with the reply in hand: hold the clock just short of it
      if (e >= online.start && !reply) {
        e = online.start - 1;
        t0 = now - e;
        if (!held) { held = true; setHolding(true); }
      } else if (held) { held = false; setHolding(false); }

      plan.cues.forEach((c, i) => { if (!fired.has(i) && e >= c.at) { fired.add(i); play(c.sound); } });

      let idx = 0;
      plan.stages.forEach((s, i) => { if (e >= s.start) idx = i; });
      if (idx !== shown) {
        setLeaving(shown);
        shown = idx;
        setStage(idx);
      }
      const done = e >= plan.total;
      const pct = done ? 100 : Math.min(99, Math.floor((e / plan.total) * 100));
      if (pctRef.current) pctRef.current.textContent = String(pct);
      if (barRef.current) barRef.current.style.transform = `scaleX(${(Math.min(e, plan.total) / plan.total).toFixed(4)})`;
      if (done) {
        alive = false;
        useStore.getState().implantOnline(reply?.implant ?? null);
        return;
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => { alive = false; cancelAnimationFrame(raf); };
  }, [plan, from]);

  useEffect(() => {
    if (leaving == null) return;
    const t = window.setTimeout(() => setLeaving(null), reducedMotion() ? 10 : LEAVE_MS);
    return () => window.clearTimeout(t);
  }, [leaving, stage]);

  const scene = (i: number) => {
    const s = plan.stages[i]!;
    switch (s.id) {
      case "boot": return <BootScene />;
      case "flash": return <FlashScene dur={s.dur} />;
      case "insert": return <InsertScene model={model} dur={s.dur} />;
      case "synapse": return <SynapseScene dur={s.dur} scanAt={plan.scanAt} />;
      case "calibrate": return <CalibrateScene dur={s.dur} />;
      case "identity": return <IdentityScene name={name} number={line?.number ?? "---"} grantAt={plan.grantAt} holding={holding} />;
      case "online": return <OnlineScene model={model} name={name} />;
    }
  };

  return (
    <div className="iseq nl-hit" role="status" aria-live="polite" aria-label="Neural-Link installation">
      <div className="iseq__top">
        <span className="iseq__progress" aria-hidden><span ref={barRef} /></span>
      </div>
      <header className="iseq__head">
        <IrisGlyph size={40} className="iseq__logo" />
        <div className="iseq__brand">
          <span className="label">Kiroshi Optics</span>
          <span className="mono">NEURAL-LINK INSTALLER · {model.toUpperCase()}</span>
        </div>
      </header>
      <div className="iseq__pct" aria-label="progress">
        <span className="mono" ref={pctRef}>0</span><i className="mono">%</i>
      </div>

      <ol className="iseq__rail">
        {plan.stages.map((s, i) => {
          const state = i < stage ? "done" : i === stage ? "active" : "todo";
          return (
            <li key={s.id} className={`irail is-${state}`} style={{ ["--d" as string]: `${s.dur}ms` }}>
              <span className="irail__mark">{state === "done" ? <Check size={14} strokeWidth={3} /> : <b className="mono">{i + 1}</b>}</span>
              <span className="irail__name label">{s.name}</span>
              {state === "active" && <span className="irail__fill" aria-hidden><i key={`${s.id}-${holding}`} className={holding ? "is-hold" : ""} /></span>}
            </li>
          );
        })}
      </ol>

      {/* the SAO white flash, over the rail but under the "online" words */}
      {plan.stages[stage]!.id === "online" && <span className="ion__flash" style={{ ["--d" as string]: `${plan.stages[stage]!.dur}ms` }} aria-hidden />}
      <div className="iseq__view">
        {/* same key in and out: the leaving scene keeps its state while it fades */}
        {(leaving != null && leaving !== stage ? [leaving, stage] : [stage]).map((i) => (
          <div className={`iseq__stage ${i === stage ? "is-in" : "is-out"}`} key={`s-${i}`} style={{ ["--d" as string]: `${plan.stages[i]!.dur}ms` }}>{scene(i)}</div>
        ))}
      </div>

      <button type="button" className="iseq__abort mono" onClick={userClose}><X size={14} /> ESC · abort installation</button>
    </div>
  );
}
