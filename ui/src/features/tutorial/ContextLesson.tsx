import { Icon } from "@/design/components";
import "./lessons.css";
export function ContextLesson({ step, alt = "ALT" }: { step?: string; alt?: string }) {
  const prop = step === "context_prop", sub = step === "vehicle_open" || step === "vehicle_close";
  const action = prop ? "Inspect practice crate" : step === "vehicle_unlock" ? "Unlock vehicle" : step === "vehicle_open" ? "Open trunk" : "Close trunk";
  return <div className="context-lesson" aria-label="How to use the Alt menu">
    <div className="context-lesson__gesture"><kbd>{alt}</kbd><span>HOLD</span><b>+</b><Icon name="mouse-pointer-click" size={26} /><span>LEFT CLICK</span></div>
    <div className="context-lesson__scene"><span className="context-lesson__target"><Icon name={prop ? "box" : "car"} size={54} /><i /></span><div className="context-lesson__menu"><small>{sub ? 'TRUNK & HOOD' : prop ? 'PRACTICE CRATE' : 'PRACTICE CAR'}</small>{sub && <span><Icon name="chevron-left" size={12} />Back</span>}<b><Icon name={prop ? "info" : step === 'vehicle_unlock' ? 'lock-open' : 'package-open'} size={14} />{action}</b></div></div>
    <p>Keep holding <strong>{alt}</strong> while you select. Release to close.</p>
    <div className="context-lesson__scope"><span><Icon name="box" size={13} />Objects</span><span><Icon name="car" size={13} />Vehicles</span><span><Icon name="users" size={13} />People</span></div>
    <small>Only actions supported by this server and target appear.</small>
  </div>;
}
