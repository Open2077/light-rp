import { useEffect, useState } from "react";
import { eddies, roman, type SectionDef } from "./data";
import type { Phase, Session } from "./App";
import type { Capacity, Projection } from "./model";

/* Clinic header, wallet, cyberware capacity (segmented, game-like) and a live vitals strip. */
export function TopBar({ session, used, phase, section, onGuide, preview }: { session: Session; used: number; phase: Phase; section?: SectionDef; onGuide?: () => void; preview?: Projection }) {
  const [shownWallet, setShownWallet] = useState(session.wallet);
  useEffect(() => {
    // The wallet rolls to its new value like a counter.
    let frame = 0;
    const from = shownWallet, to = session.wallet, t0 = performance.now();
    const step = () => {
      const p = Math.min(1, (performance.now() - t0) / 700);
      setShownWallet(Math.round(from + (to - from) * (1 - Math.pow(1 - p, 3))));
      if (p < 1) frame = requestAnimationFrame(step);
    };
    frame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frame);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session.wallet]);
  return (
    <div className={`rd-top ${phase === "boot" ? "is-boot" : ""}`}>
      <div className="rd-brand">
        <div className="rd-brand-mark"><span>R</span></div>
        <div>
          <div className="rd-brand-title">RIPPERDOC <i>//</i> CLINIC</div>
          <div className="rd-brand-sub">LICENSED CYBERNETIC SURGERY · NIGHT CITY</div>
        </div>
      </div>
      <div className="rd-crumb">
        <span>PATIENT</span><b>{(session.patient.name ?? "UNKNOWN").toUpperCase()}</b>
        <span>ID</span><b>{session.patient.id ?? "—"}</b>
        {section && <><span>FOCUS</span><b className="accent">{section.label.toUpperCase()}</b></>}
      </div>
      <div className="rd-meters">
        {session.reputation && (
          <div className={`rd-parts rd-rep ${preview?.verdict === "rep" ? "is-short" : ""}`} title={session.reputation.next !== undefined
            ? `${session.reputation.points ?? 0} / ${session.reputation.next} to ${session.reputation.nextName ?? "the next tier"}` : undefined}>
            <span>STREET CRED</span><b>{roman(session.reputation.tier)}</b>
            {session.reputation.name && <em>{session.reputation.name.toUpperCase()}</em>}
          </div>
        )}
        {session.capacity && <CapacityMeter cap={session.capacity} preview={preview} />}
        <div className="rd-parts"><span>IMPLANTS</span><b>{used}</b></div>
        <div className={`rd-wallet ${preview && preview.cost > 0 ? (preview.walletAfter < 0 ? "is-short" : "is-spending") : ""}`}>
          <span>BANK</span><b>€$ {eddies(shownWallet)}</b>
          {preview && preview.cost > 0 && (
            <em key={`${preview.cost}:${preview.walletAfter < 0}`}>− €$ {eddies(preview.cost)}{preview.walletAfter < 0 ? " · SHORT" : ""}</em>
          )}
        </div>
        {session.guide && (
          <button className="rd-guide-open" disabled={!onGuide} onClick={onGuide} title="How capacity, street cred and storage work (H)">
            <i>?</i><span>GUIDE</span>
          </button>
        )}
      </div>
    </div>
  );
}

/* Capacity points fitted over the body's total (it grows with the street cred tier): one
   segment per point. With a preview (the hovered / selected implant), the bar shows the surgery
   before it happens: the points it adds pulse in, the points it frees blink out, and anything past
   the total turns red, with the verdict next to the numbers. */
function CapacityMeter({ cap, preview }: { cap: Capacity; preview?: Projection }) {
  const over = cap.over === true || cap.used > cap.total;
  return (
    <div className={`rd-parts rd-cap ${over ? "over" : ""} ${preview ? `is-preview v-${preview.verdict}` : ""}`}
      title={over ? "Over capacity: you keep what is fitted, only a lighter swap fits." : `${cap.total - cap.used} points free`}>
      <span>CAPACITY</span>
      <b>{cap.used}{preview && preview.after !== cap.used && <s key={preview.after}> → {preview.after}</s>}<i> / {cap.total}</i></b>
      <CapacityBar cap={cap} preview={preview} />
      {preview ? <CapacityVerdict cap={cap} preview={preview} /> : over && <em>OVER CAPACITY</em>}
    </div>
  );
}

/** The segmented bar, with the surgery's preview drawn on it. */
export function CapacityBar({ cap, preview, className = "rd-cap-bar" }: { cap: Capacity; preview?: Projection; className?: string }) {
  const used = cap.used, total = cap.total;
  const after = preview ? preview.after : used;
  const keep = preview ? used - preview.freed : used;   // points that stay as they are
  const segments = Math.min(40, Math.max(total, used, after));
  return (
    <div className={className}>
      {Array.from({ length: segments }, (_, k) => {
        let state = "";
        if (k < Math.min(keep, after)) state = k >= total ? "x" : "on";
        else if (preview && k < after) state = k >= total ? "add over" : "add";
        else if (preview && k < used) state = "free";
        else if (!preview && k < used) state = k >= total ? "x" : "on";
        return <i key={k} className={`${state} ${k === total - 1 ? "edge" : ""}`} style={{ ["--k" as string]: k }} />;
      })}
    </div>
  );
}

/** The verdict next to the numbers: it fits (and what is left), it frees points, or it overflows. */
export function CapacityVerdict({ cap, preview }: { cap: Capacity; preview: Projection }) {
  const left = cap.total - preview.after;
  const [kind, text] = preview.mode === "remove" ? ["free", `FREES ${preview.freed} PT`]
    : preview.over > 0 && preview.verdict === "ok" ? ["warn", "LIGHTER SWAP OK"]
    : preview.over > 0 ? ["bad", `OVER BY ${preview.over}`]
    : preview.freed > 0 ? ["ok", `SWAP · ${left} LEFT`]
    : ["ok", `FITS · ${left} LEFT`];
  return <em key={`${kind}:${text}`} className={`rd-verdict ${kind}`}>{text}</em>;
}

export function BottomBar({ phase, guide }: { phase: Phase; guide?: boolean }) {
  const keys = (phase === "section" || phase === "surfacing"
    ? [["A", "D"], "Cycle systems", ["E"], "Hold to operate", ["ESC"], "Full body"]
    : [["LMB"], "Open system", ["ESC"], "Leave the chair"]).concat(guide ? [["H"], "Guide"] : []);
  return (
    <div className="rd-bottom">
      <div className="rd-keys">
        {keys.map((k, i) => typeof k === "string"
          ? <span key={i} className="label">{k}</span>
          : <span key={i} className="keys">{k.map((x) => <kbd key={x}>{x}</kbd>)}</span>)}
      </div>
      <div className="rd-legal">OPEN//77 MEDICAL NETWORK · NCPD SURGERY LICENCE 2077-A</div>
    </div>
  );
}
