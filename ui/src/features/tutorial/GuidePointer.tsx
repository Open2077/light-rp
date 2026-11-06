import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import { GUIDE_ANCHOR, GUIDE_CLOSE_M, currentWay, edgePoint, formatDistance, subscribeWay } from "./guide";
import "./guide.css";

/* The way to the objective, on the HUD (client/core/tutorial_guide.lua):
   - in view: a waypoint over the objective, its name and distance, pinned to the page
     anchor the plugin projects every frame;
   - out of view (behind, beside, or no anchor on an older client): an arrow on a ring
     round the screen centre, turned toward it, with the distance;
   - within a few metres: nothing, the objective's own prompt takes over.
   Written straight into the DOM: the anchor moves every frame. */

interface AnchorFrame { anchors?: Array<{ tag?: string; x: number; y: number; depth?: number; onScreen?: boolean }> }
const MARGIN_X = 0.03, MARGIN_Y = 0.06;

export function GuidePointer() {
  const waypoint = useRef<HTMLDivElement>(null);
  const edge = useRef<HTMLDivElement>(null);
  const arrow = useRef<HTMLElement>(null);
  const anchor = useRef<{ x: number; y: number; onScreen: boolean } | null>(null);
  const texts = useRef<Record<string, HTMLElement | null>>({});

  useEffect(() => {
    const paint = () => {
      const way = currentWay();
      const w = waypoint.current, e = edge.current;
      if (!w || !e) return;
      const shown = !!way && way.distance >= GUIDE_CLOSE_M;
      const a = anchor.current;
      const inView = shown && !!a && a.onScreen && a.x >= MARGIN_X && a.x <= 1 - MARGIN_X && a.y >= MARGIN_Y && a.y <= 1 - MARGIN_Y;
      w.classList.toggle("is-shown", inView);
      e.classList.toggle("is-shown", shown && !inView);
      if (!way) return;
      const distance = formatDistance(way.distance);
      const rise = Math.abs(way.rise) >= 2 ? `${way.rise > 0 ? "▲" : "▼"} ${Math.abs(way.rise)} m` : "";
      for (const [key, value] of [["label", way.label], ["distance", distance], ["rise", rise], ["edgeDistance", rise ? `${distance} · ${rise}` : distance]] as const) {
        const el = texts.current[key];
        if (el && el.textContent !== value) el.textContent = value;
      }
      if (inView && a) w.style.transform = `translate(${(a.x * 100).toFixed(3)}vw, ${(a.y * 100).toFixed(3)}vh)`;
      else if (shown) {
        const p = edgePoint(way.angle);
        e.style.transform = `translate(${(p.x * 100).toFixed(3)}vw, ${(p.y * 100).toFixed(3)}vh)`;
        if (arrow.current) arrow.current.style.transform = `rotate(${p.turn.toFixed(1)}deg)`;
      }
    };
    const offWay = subscribeWay(paint);
    const offAnchor = on<AnchorFrame>("open77:anchors", (frame) => {
      const found = Array.isArray(frame?.anchors) ? frame.anchors.find((x) => x?.tag === GUIDE_ANCHOR) : undefined;
      anchor.current = found && Number.isFinite(found.x) && Number.isFinite(found.y)
        ? { x: found.x, y: found.y, onScreen: found.onScreen !== false && (found.depth ?? 1) > 0 } : null;
      paint();
    });
    // the client stopped talking (a reload, a stopped resource): the pointer goes on its own
    const stale = window.setInterval(paint, 500);
    paint();
    return () => { offWay(); offAnchor(); window.clearInterval(stale); };
  }, []);

  const set = (key: string) => (el: HTMLElement | null) => { texts.current[key] = el; };
  return <div className="fd-way" aria-hidden>
    <div className="fd-way__waypoint" ref={waypoint}>
      <div className="fd-way__pin">
        <b ref={set("label")} className="fd-way__label" />
        <span className="fd-way__mark"><i /><svg viewBox="0 0 24 24" width="22" height="22"><path d="M12 21 4 9h16Z" /></svg></span>
        <span className="fd-way__distance" ref={set("distance")} />
        <em className="fd-way__rise" ref={set("rise")} />
      </div>
    </div>
    <div className="fd-way__edge" ref={edge}>
      <span className="fd-way__arrow" ref={arrow}><svg viewBox="0 0 24 24" width="26" height="26"><path d="M12 2 19 21 12 16.5 5 21Z" /></svg></span>
      <span className="fd-way__distance" ref={set("edgeDistance")} />
    </div>
  </div>;
}

/** The card's line: an arrow turned toward the objective, the distance, its name. */
export function GuideReadout() {
  const [way, setWay] = useState(() => currentWay());
  useEffect(() => {
    const update = () => setWay((before) => {
      const next = currentWay();
      if (!next || !before) return next;
      return next.label === before.label && Math.round(next.distance) === Math.round(before.distance)
        && Math.abs(next.angle - before.angle) < 4 && next.rise === before.rise ? before : next;
    });
    const off = subscribeWay(update);
    const stale = window.setInterval(update, 1000);
    return () => { off(); window.clearInterval(stale); };
  }, []);
  if (!way) return null;
  return <div className="first-day__distance">
    <span className="first-day__beacon" style={{ transform: `rotate(${(-way.angle).toFixed(0)}deg)` }}>
      <svg viewBox="0 0 24 24" width="14" height="14" aria-hidden><path d="M12 2 19 21 12 16.5 5 21Z" fill="currentColor" /></svg>
    </span>
    <b>{formatDistance(way.distance)}</b><span>{way.label}</span>
  </div>;
}
