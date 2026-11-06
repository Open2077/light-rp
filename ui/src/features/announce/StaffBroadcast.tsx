import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import "./staff-broadcast.css";

/* The staff announcement (/announce, /admin > Server announcement, other resources through
   Staff.announce): a citywide broadcast in Light RP's design instead of the platform's blue box.
   It tears in with a glitch, the text is typed out, the staff member signs it, a bar drains the
   time it stays, and it collapses out. Several in a row queue. The sounds are the game's own
   (client/core/staff_announce.lua). Passive: never the focus. */

export interface StaffBroadcastMessage { title?: string; text: string; from?: string; durationMs?: number }
interface Shown extends StaffBroadcastMessage { id: number; at: number }

const OUT_MS = 520;

export function StaffBroadcast() {
  const [queue, setQueue] = useState<Shown[]>([]);
  const [leaving, setLeaving] = useState(false);
  const seq = useRef(0);
  const current = queue[0];

  useEffect(() => on<StaffBroadcastMessage>(PAGE_EVENTS.staffAnnounce, (m) => {
    if (!m || typeof m.text !== "string" || !m.text.trim()) return;
    seq.current += 1;
    const item: Shown = { ...m, id: seq.current, at: 0 };
    setQueue((q) => [...q.slice(-4), item]);
  }), []);

  // each one stays its duration (counted from when it shows), then leaves, then the next shows
  useEffect(() => {
    if (!current) return;
    const stay = Math.max(4000, current.durationMs ?? 10000);
    const leave = window.setTimeout(() => setLeaving(true), stay);
    const next = window.setTimeout(() => { setLeaving(false); setQueue((q) => q.slice(1)); }, stay + OUT_MS);
    return () => { window.clearTimeout(leave); window.clearTimeout(next); };
  }, [current?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!current) return null;
  return <section key={current.id} className={`sb${leaving ? " is-leaving" : ""}`} role="status" aria-live="assertive"
    style={{ ["--sb-ms" as string]: `${Math.max(4000, current.durationMs ?? 10000)}ms` }}>
    <div className="sb__glitch" aria-hidden><span /><span /><span /></div>
    <header className="sb__head">
      <span className="sb__live"><i />LIVE</span>
      <span className="sb__title"><Icon name="radio" size={14} />CITYWIDE BROADCAST</span>
      <span className="sb__tag">{(current.title || "Staff announcement").toUpperCase()}</span>
    </header>
    <Typed text={current.text} />
    <footer className="sb__foot">
      <span className="sb__from">{current.from ? <>// SIGNED <b>{current.from.toUpperCase()}</b></> : "// LIGHT/RP STAFF"}</span>
      <span className="sb__bar" aria-hidden><i /></span>
    </footer>
  </section>;
}

/* The text typed out (about 28 characters a second, at most 1.6 s), with a block caret. */
function Typed({ text }: { text: string }) {
  const [n, setN] = useState(0);
  useEffect(() => {
    setN(0);
    const step = Math.max(1, Math.ceil(text.length / 45));
    const t = window.setInterval(() => setN((v) => { const next = Math.min(text.length, v + step); if (next >= text.length) window.clearInterval(t); return next; }), 35);
    return () => window.clearInterval(t);
  }, [text]);
  return <p className="sb__text">{text.slice(0, n)}{n < text.length && <i className="sb__caret" />}<span className="sb__unsaid">{text.slice(n)}</span></p>;
}
