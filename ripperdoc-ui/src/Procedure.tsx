import { useEffect, useState } from "react";
import { SECTION, type Body, type Cyberware } from "./data";
import { iconImage, sectionVideo } from "./media";

/* The operation itself (preview only: the real installation comes with the system). The close-up
   goes hot, the steps scroll like a surgical log, the implant locks into the socket. */
const INSTALL_STEPS = ["Local anaesthesia", "Incision // dermal layer", "Socket alignment", "Neural handshake", "Firmware calibration", "Integration verified"];
const REMOVE_STEPS = ["Neural disconnect", "Extraction", "Socket sealed"];

export function Procedure({ item, mode, body }: { item: Cyberware; mode: "install" | "remove"; body: Body }) {
  const steps = mode === "install" ? INSTALL_STEPS : REMOVE_STEPS;
  const total = mode === "install" ? 4600 : 1800;
  const [t, setT] = useState(0);
  useEffect(() => {
    const t0 = performance.now();
    let frame = 0;
    const tick = () => { setT(Math.min(1, (performance.now() - t0) / total)); frame = requestAnimationFrame(tick); };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [total]);
  const done = t >= 1;
  const current = Math.min(steps.length - 1, Math.floor(t * steps.length));
  return (
    <div className={`rd-proc ${done ? "done" : ""} ${mode}`}>
      <video className="rd-proc-video" src={sectionVideo(body, item.section)} autoPlay loop muted playsInline />
      <div className="rd-proc-card">
        <div className="rd-proc-kicker">{mode === "install" ? "SURGICAL PROCEDURE" : "EXTRACTION"} // {SECTION[item.section]!.label.toUpperCase()}</div>
        <div className="rd-proc-item">
          <img src={iconImage(item.icon)} alt="" />
          <div><h3>{item.name}</h3><span>{item.maker.toUpperCase()}</span></div>
        </div>
        <ol>
          {steps.map((s, i) => <li key={s} className={i < current || done ? "ok" : i === current ? "now" : ""}>{s}</li>)}
        </ol>
        <div className="rd-proc-bar"><i style={{ transform: `scaleX(${t})` }} /></div>
        <div className="rd-proc-state">{done ? (mode === "install" ? "IMPLANT ONLINE" : "IMPLANT REMOVED") : `${Math.round(t * 100)}%`}</div>
      </div>
    </div>
  );
}
