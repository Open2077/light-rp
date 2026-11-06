import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import "./arrival-tour.css";

/* The caption of the central square's camera tour, on the way out of the arrival hall
   (client/core/arrival_tour.lua): cinema bars slide in, the place's name wipes in, the
   three contacts of the square appear one after the other, a bar runs the tour's time.
   Lua sends false when the tour ends (its end, the skip key, a death); the page also
   gives up on its own a little after the tour's time. Passive: never the focus. */

export interface ArrivalTourMessage { title?: string; subtitle?: string; lines?: string[] | Record<string, string>; durationMs?: number; skip?: string }
interface Shown { title: string; subtitle: string; lines: string[]; durationMs: number; skip?: string; id: number }

const OUT_MS = 650;

export function ArrivalTour() {
  const [shown, setShown] = useState<Shown | null>(null);
  const [leaving, setLeaving] = useState(false);
  const seq = useRef(0);

  useEffect(() => on<ArrivalTourMessage | false>(PAGE_EVENTS.arrivalTour, (m) => {
    if (!m) { setLeaving(true); return; }
    seq.current += 1;
    // An empty Lua list reaches the page as {}: only a real array (or an object's values) lists lines.
    const raw = Array.isArray(m.lines) ? m.lines : m.lines && typeof m.lines === "object" ? Object.values(m.lines) : [];
    setLeaving(false);
    setShown({ id: seq.current, title: m.title || "NIGHT CITY", subtitle: m.subtitle || "", lines: raw.filter((l): l is string => typeof l === "string").slice(0, 4),
      durationMs: Math.max(3000, Math.min(30000, Number(m.durationMs) || 11000)), skip: m.skip });
  }), []);

  // leaving: gone after the exit animation; a lost "false" still ends it after the tour's time
  useEffect(() => {
    if (!shown) return;
    if (leaving) { const t = window.setTimeout(() => { setShown(null); setLeaving(false); }, OUT_MS); return () => window.clearTimeout(t); }
    const t = window.setTimeout(() => setLeaving(true), shown.durationMs + 2500);
    return () => window.clearTimeout(t);
  }, [shown, leaving]);

  // the page's own HUD, notices and queues step aside while it plays (arrival-tour.css)
  useEffect(() => {
    document.documentElement.toggleAttribute("data-arrival-tour", shown !== null);
    return () => document.documentElement.removeAttribute("data-arrival-tour");
  }, [shown]);

  if (!shown) return null;
  return <section key={shown.id} className={`at${leaving ? " is-leaving" : ""}`} role="status" aria-label={shown.title}
    style={{ ["--at-ms" as string]: `${shown.durationMs}ms` }}>
    <div className="at__bar at__bar--top" aria-hidden />
    <div className="at__bar at__bar--bottom" aria-hidden />
    <div className="at__caption">
      <span className="at__eyebrow"><i />WELCOME TO NIGHT CITY</span>
      <h1 className="at__title" data-text={shown.title}>{shown.title}</h1>
      {shown.subtitle && <p className="at__subtitle">{shown.subtitle}</p>}
      {shown.lines.length > 0 && <ul className="at__lines">
        {shown.lines.map((line, i) => <li key={i} style={{ animationDelay: `${1.2 + i * 0.55}s` }}><b>{String(i + 1).padStart(2, "0")}</b>{line}</li>)}
      </ul>}
    </div>
    <div className="at__foot">
      <span className="at__time" aria-hidden><i /></span>
      {shown.skip && <span className="at__skip"><kbd>{shown.skip}</kbd>Skip</span>}
    </div>
  </section>;
}
