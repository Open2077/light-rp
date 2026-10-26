/* The opened interface: link-start sequence, info card, SAO column, sub-panel
   and the window host, all on a slightly tilted 3D plane that follows the
   mouse a few degrees. Without an implant the implant gate takes its place. */
import { useEffect, useRef } from "react";
import { getStore, implantGate, useStore } from "@/store/store";
import { play } from "@/fx/sound";
import { LinkStart } from "@/fx/LinkStart";
import { Particles } from "@/fx/Particles";
import { InfoCard } from "./InfoCard";
import { Column, columnLayout } from "./Column";
import { SubPanel } from "./SubPanel";
import { WindowHost } from "./WindowHost";
import { SyncOverlay } from "./SyncOverlay";
import { columnItems, missedSince } from "./menu";
import { reducedMotion } from "./Stage";
import { ImplantGate } from "@/implant/ImplantGate";

const OPEN_MS = 1500;
const CLOSE_MS = 330;
let soundedSeq = -1;

export function Shell() {
  const phase = useStore((s) => s.phase);
  const openSeq = useStore((s) => s.openSeq);
  const ready = useStore((s) => !!s.state?.ready);
  const gated = useStore(implantGate);
  const planeRef = useRef<HTMLDivElement>(null);

  // Phase timers: opening -> open, closing -> closed.
  useEffect(() => {
    if (phase === "opening") {
      // the gate has its own sounds: no "open" chime for a dead interface
      if (soundedSeq !== openSeq) { soundedSeq = openSeq; if (!implantGate(getStore())) play("open"); }
      const t = window.setTimeout(() => useStore.getState().setPhase("open"), reducedMotion() ? 50 : OPEN_MS);
      return () => window.clearTimeout(t);
    }
    if (phase === "closing") {
      const t = window.setTimeout(() => useStore.getState().setPhase("closed"), reducedMotion() ? 30 : CLOSE_MS);
      return () => window.clearTimeout(t);
    }
    return undefined;
  }, [phase, openSeq]);

  // Mouse parallax: two CSS variables on the plane, written once per frame.
  useEffect(() => {
    let raf = 0;
    let mx = 0, my = 0;
    const move = (e: PointerEvent) => {
      document.documentElement.dataset.input = "mouse";
      mx = (e.clientX / window.innerWidth) * 2 - 1;
      my = (e.clientY / window.innerHeight) * 2 - 1;
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        const el = planeRef.current;
        if (!el || reducedMotion()) return;
        el.style.setProperty("--mx", mx.toFixed(3));
        el.style.setProperty("--my", my.toFixed(3));
      });
    };
    const key = (e: KeyboardEvent) => { if (e.key.startsWith("Arrow") || e.key === "Enter") document.documentElement.dataset.input = "kbd"; };
    window.addEventListener("pointermove", move, { passive: true });
    window.addEventListener("keydown", key);
    return () => { window.removeEventListener("pointermove", move); window.removeEventListener("keydown", key); cancelAnimationFrame(raf); };
  }, []);

  return (
    <div className={`shell is-${phase}`} key={openSeq}>
      {phase === "opening" && !gated && <LinkStart />}
      {!gated && <Particles running={phase === "open" || phase === "opening"} />}
      <div className="plane" ref={planeRef}>
        {!ready ? <SyncOverlay /> : gated ? <ImplantGate /> : <ShellBody />}
      </div>
    </div>
  );
}

function ShellBody() {
  const state = useStore((s) => s.state);
  const seen = useStore((s) => s.recentsSeenAt);
  const menu = useStore((s) => s.menu);
  const callView = useStore((s) => s.callView);
  const hasCall = useStore((s) => !!s.state?.call);
  const missed = missedSince(state, seen);
  const items = columnItems(state, missed, hasCall);
  const layout = columnLayout(items.length);
  const selIndex = items.findIndex((it) => (it.id === "call" ? callView : it.id === menu));
  const anchorY = selIndex >= 0 ? layout.centers[selIndex]! : 540;

  return (
    <>
      <InfoCard />
      <Column items={items} layout={layout} />
      {menu && !callView && !menu.startsWith("app:") && <SubPanel key={menu} anchorY={anchorY} missed={missed} />}
      <WindowHost />
    </>
  );
}
