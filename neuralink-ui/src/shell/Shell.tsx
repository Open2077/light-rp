/* The opened interface: link-start sequence, info card, SAO column, sub-panel
   and the window host, all on a 3D plane that follows the (smoothed) mouse and
   sways on its own when it rests. The Night City style adds the neural field
   behind, the synapse fibres between the panels and random glitch bursts.
   Without an implant the implant gate takes its place. */
import { useEffect, useRef } from "react";
import { getStore, implantGate, useSettings, useStore } from "@/store/store";
import { play } from "@/fx/sound";
import { LinkStart } from "@/fx/LinkStart";
import { Particles } from "@/fx/Particles";
import { NeuralField } from "@/fx/NeuralField";
import { pointerTo, space, stepSpace } from "@/fx/space";
import { Synapse } from "./Synapse";
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
  const night = useSettings().style !== "sao";
  const planeRef = useRef<HTMLDivElement>(null);
  const live = phase === "open" || phase === "opening";

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

  // The plane follows the pointer (smoothed, swaying when it rests): --mx/--my
  // on the plane, the same values in `space` for the canvases.
  useEffect(() => {
    const move = (e: PointerEvent) => {
      document.documentElement.dataset.input = "mouse";
      pointerTo((e.clientX / window.innerWidth) * 2 - 1, (e.clientY / window.innerHeight) * 2 - 1);
    };
    const key = (e: KeyboardEvent) => { if (e.key.startsWith("Arrow") || e.key === "Enter") document.documentElement.dataset.input = "kbd"; };
    window.addEventListener("pointermove", move, { passive: true });
    window.addEventListener("keydown", key);
    let raf = 0, last = performance.now();
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick);
      const el = planeRef.current;
      if (!el || reducedMotion()) return;
      stepSpace(Math.min(0.1, Math.max(0, (now - last) / 1000)), false);
      last = now;
      el.style.setProperty("--mx", space.x.toFixed(4));
      el.style.setProperty("--my", space.y.toFixed(4));
    };
    if (live) raf = requestAnimationFrame(tick);
    return () => { window.removeEventListener("pointermove", move); window.removeEventListener("keydown", key); cancelAnimationFrame(raf); };
  }, [live]);

  // Glitch bursts: now and then one floating panel tears for a fraction of a second.
  useEffect(() => {
    if (!live || !night || reducedMotion()) return;
    let timer = 0, off = 0;
    const burst = () => {
      const panels = Array.from(document.querySelectorAll<HTMLElement>(".plane .nl3d"));
      const el = panels[Math.floor(Math.random() * panels.length)];
      if (el) { el.classList.add("is-glitch"); off = window.setTimeout(() => el.classList.remove("is-glitch"), 180 + Math.random() * 160); }
      timer = window.setTimeout(burst, 4200 + Math.random() * 5200);
    };
    timer = window.setTimeout(burst, 3600);
    return () => { window.clearTimeout(timer); window.clearTimeout(off); };
  }, [live, night]);

  return (
    <div className={`shell is-${phase}`} key={openSeq}>
      {phase === "opening" && !gated && <LinkStart />}
      {!gated && !night && <Particles running={live} />}
      {!gated && night && <NeuralField running={live} />}
      <div className="plane" ref={planeRef}>
        {!ready ? <SyncOverlay /> : gated ? <ImplantGate /> : <ShellBody />}
      </div>
      {!gated && night && ready && <Synapse />}
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
