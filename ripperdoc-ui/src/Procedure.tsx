import { useEffect, useState } from "react";
import { SECTION, type Body } from "./data";
import { iconImage, sectionVideo } from "./media";
import type { ProcedureState } from "./App";

/* The operation itself. The close-up goes hot, the steps scroll like a surgical log; the last
   step waits for the clinic's answer (payment, parts, the implant's native installation), then
   the implant locks in, or the surgery is aborted and the patient refunded. */
const INSTALL_STEPS = ["Payment cleared // parts on the tray", "Local anaesthesia", "Incision // dermal layer", "Socket alignment", "Neural handshake", "Integration verified"];
const REMOVE_STEPS = ["Neural disconnect", "Extraction", "Socket sealed"];

export function Procedure({ state, body }: { state: ProcedureState; body: Body }) {
  const { item, mode, result, startedAt, minMs } = state;
  const steps = mode === "install" ? INSTALL_STEPS : REMOVE_STEPS;
  const [t, setT] = useState(0);
  useEffect(() => {
    let frame = 0;
    const tick = () => {
      const raw = (performance.now() - startedAt) / minMs;
      // Without an answer the log stops on its last step and the bar creeps towards 95 %.
      setT(result ? Math.min(1, raw) : Math.min(0.95, raw < 0.9 ? raw : 0.9 + (raw - 0.9) * 0.05));
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [startedAt, minMs, result]);
  const done = result !== undefined && t >= 1;
  const failed = done && !result.ok;
  const current = Math.min(steps.length - 1, Math.floor(t * steps.length));
  const label = !done ? `${Math.round(t * 100)}%`
    : failed ? "OPERATION ABORTED" : mode === "install" ? "IMPLANT ONLINE" : "IMPLANT REMOVED";
  return (
    <div className={`rd-proc ${done ? (failed ? "failed" : "done") : ""} ${mode}`}>
      <video className="rd-proc-video" src={sectionVideo(body, item.section)} autoPlay loop muted playsInline />
      <div className="rd-proc-card">
        <div className="rd-proc-kicker">{mode === "install" ? "SURGICAL PROCEDURE" : "EXTRACTION"} // {SECTION[item.section]?.label.toUpperCase()}</div>
        <div className="rd-proc-item">
          <img src={iconImage(item.icon)} alt="" />
          <div><h3>{item.name}</h3><span>{item.maker.toUpperCase()}</span></div>
        </div>
        <ol>
          {steps.map((s, i) => <li key={s} className={failed && i === current ? "bad" : i < current || (done && !failed) ? "ok" : i === current ? "now" : ""}>{s}</li>)}
        </ol>
        <div className="rd-proc-bar"><i style={{ transform: `scaleX(${t})` }} /></div>
        <div className="rd-proc-state">{label}</div>
        {failed && result?.message && <div className="rd-proc-error">{result.message}</div>}
        {done && !failed && result?.message && <div className="rd-proc-note">{result.message}</div>}
      </div>
    </div>
  );
}
