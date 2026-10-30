import { useEffect, useState } from "react";
import { eddies, type SectionDef } from "./data";
import type { Phase, Session } from "./App";

/* Clinic header, wallet, cyberware capacity (segmented, game-like) and a live vitals strip. */
export function TopBar({ session, used, phase, section, onDeposit }: { session: Session; used: number; phase: Phase; section?: SectionDef; onDeposit(): void }) {
  const segments = 30;
  const per = session.capacityMax / segments;
  const filled = Math.round(used / per);
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
          <div className="rd-brand-title">RIPPERDOC <i>//</i> {session.clinic.name.toUpperCase()}</div>
          <div className="rd-brand-sub">{session.clinic.doctor.toUpperCase()} · {(session.clinic.tagline ?? "LICENSED CLINIC").toUpperCase()}</div>
        </div>
      </div>
      <div className="rd-crumb">
        <span>PATIENT</span><b>{(session.patient.name ?? "UNKNOWN").toUpperCase()}</b>
        <span>ID</span><b>{session.patient.id ?? "—"}</b>
        {section && <><span>FOCUS</span><b className="accent">{section.label.toUpperCase()}</b></>}
      </div>
      <div className="rd-meters">
        <div className="rd-capacity">
          <div className="rd-capacity-head"><span>CYBERWARE CAPACITY</span><b>{used}<i>/{session.capacityMax}</i></b></div>
          <div className="rd-capacity-bar">
            {Array.from({ length: segments }, (_, i) => <i key={i} className={i < filled ? (filled > segments * 0.85 ? "hot" : "on") : ""} style={{ ["--i" as string]: i }} />)}
          </div>
        </div>
        <div className="rd-parts">
          <span>{session.parts.label.toUpperCase()}</span>
          <b>{session.parts.have}</b>
          <em>{session.parts.stored} AT THE CLINIC · {session.parts.carried} ON YOU</em>
          {session.parts.carried > 0 && <button className="rd-handover" onClick={onDeposit}>HAND OVER {session.parts.carried}</button>}
        </div>
        <div className="rd-wallet"><span>BANK</span><b>€$ {eddies(shownWallet)}</b></div>
      </div>
    </div>
  );
}

export function BottomBar({ phase }: { phase: Phase }) {
  const keys = phase === "section" || phase === "surfacing"
    ? [["A", "D"], "Cycle systems", ["E"], "Hold to operate", ["ESC"], "Full body"]
    : [["LMB"], "Open system", ["ESC"], "Leave the chair"];
  return (
    <div className="rd-bottom">
      <Vitals />
      <div className="rd-keys">
        {keys.map((k, i) => typeof k === "string"
          ? <span key={i} className="label">{k}</span>
          : <span key={i} className="keys">{k.map((x) => <kbd key={x}>{x}</kbd>)}</span>)}
      </div>
      <div className="rd-legal">OPEN//77 MEDICAL NETWORK · NCPD SURGERY LICENCE 2077-A</div>
    </div>
  );
}

/* A heartbeat trace drawn on a canvas (no images): the patient is alive and on the table. */
function Vitals() {
  const [bpm, setBpm] = useState(72);
  useEffect(() => {
    const id = window.setInterval(() => setBpm(68 + Math.round(Math.random() * 9)), 1400);
    return () => window.clearInterval(id);
  }, []);
  return (
    <div className="rd-vitals">
      <svg viewBox="0 0 220 40" className="rd-ecg">
        <path d="M0 22 H40 L48 22 L54 8 L60 34 L66 22 H110 L118 22 L124 4 L130 36 L136 22 H180 L188 22 L194 10 L200 32 L206 22 H220" />
      </svg>
      <div className="rd-vitals-read"><b>{bpm}</b><span>BPM</span><b>98</b><span>SPO2</span><b>36.8</b><span>°C</span></div>
    </div>
  );
}
