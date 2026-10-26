/* state.ready === false: the server has not assigned a line yet. */
import { X } from "lucide-react";
import { userClose } from "@/store/actions";

const STEPS = ["Cortex handshake", "Bio-signature", "Line allocation", "Network registry"];

export function SyncOverlay() {
  return (
    <div className="sync nl-hit" role="status" aria-live="polite">
      <div className="sync__orb" aria-hidden>
        <span className="sync__ring sync__ring--a" />
        <span className="sync__ring sync__ring--b" />
        <span className="sync__ring sync__ring--c" />
        <span className="sync__core" />
      </div>
      <div className="sync__title label">Synchronising neural link…</div>
      <div className="sync__bar" aria-hidden><span /></div>
      <ul className="sync__steps mono">
        {STEPS.map((s, i) => (
          <li key={s} style={{ ["--i" as string]: i }}><span className="sync__dot" />{s}</li>
        ))}
      </ul>
      <button type="button" className="btn btn--ghost btn--sm sync__close" onClick={userClose}><X size={16} /> <span>Close</span></button>
    </div>
  );
}
