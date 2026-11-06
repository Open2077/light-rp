import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import "./death-cover.css";

/* The flatline cover (client/core/death_cover.lua): the platform plays the local body's
   death in a pinned first person (camera rolled onto the floor, an arm in view) for as long
   as the player is down. From the Dead event the screen tears to black ("in", fully opaque
   at 150 ms), holds while down ("held"), then reboots out once the body recovers ("out").
   It draws under the medical panel (z55), the mission / raid / activity HUDs (z29-40) and
   the loading cover (op77_loadscreen, another surface at z950), and never takes input.
   While the medical panel is up its own title replaces the readout here. */
const PAGE = "lightrp:ui:medical";
export const DEATH_COVER_IN_MS = 700;
export const DEATH_COVER_OUT_MS = 1100;
type Stage = "off" | "in" | "held" | "out";
interface CoverMessage { kind?: string; down?: boolean; cause?: string; state?: { downed?: boolean } }
const SLICES = 9;

export function DeathCover() {
  const [stage, setStage] = useState<Stage>("off");
  const [epoch, setEpoch] = useState(0);
  const [downed, setDowned] = useState(false);
  const stageRef = useRef<Stage>("off");
  const timer = useRef<number | undefined>(undefined);
  useEffect(() => {
    const go = (next: Stage) => { stageRef.current = next; setStage(next); };
    const off = on<CoverMessage>(PAGE, p => {
      if (!p || typeof p !== "object") return;
      if (p.kind === "state") { setDowned(p.state?.downed === true); return; }
      if (p.kind !== "cover") return;
      window.clearTimeout(timer.current);
      if (p.down === true) {
        if (stageRef.current === "off") {
          setEpoch(n => n + 1);
          go("in");
          timer.current = window.setTimeout(() => { if (stageRef.current === "in") go("held"); }, DEATH_COVER_IN_MS);
        } else go("held"); // down again mid-reboot: solid at once
        return;
      }
      if (stageRef.current === "off") return;
      go("out");
      timer.current = window.setTimeout(() => go("off"), DEATH_COVER_OUT_MS);
    });
    return () => { off(); window.clearTimeout(timer.current); };
  }, []);
  if (stage === "off") return null;
  const rebooting = stage === "out";
  return <div key={epoch} className={`death-cover is-${stage}${downed && !rebooting ? " is-downed" : ""}`} aria-hidden={downed && !rebooting}
    role="status" aria-label={rebooting ? "Signal restored" : "Flatlined"}>
    <div className="death-cover__dim" />
    <div className="death-cover__half is-top" />
    <div className="death-cover__half is-bottom" />
    <div className="death-cover__slices">
      {Array.from({ length: SLICES }, (_, i) => <i key={i} style={{ top: `${(i * 100) / SLICES}%`, height: `${100 / SLICES + 0.4}%`, animationDelay: `${(i * 37) % 90}ms` }} className={i % 2 ? "is-right" : "is-left"} />)}
    </div>
    <div className="death-cover__noise" />
    <div className="death-cover__readout">
      <div className="death-cover__top"><span>OPEN<b>//</b>77 <small>NEURAL LINK</small></span><span className="death-cover__status">{rebooting ? "BIOMONITOR // ONLINE" : "BIOMONITOR // NO SIGNAL"}</span></div>
      <div className="death-cover__head">
        <span className="death-cover__eyebrow">{rebooting ? "SIGNAL RESTORED" : "ICE BREACH · SIGNAL LOST"}</span>
        <h1 className="death-cover__title" data-text={rebooting ? "REBOOTING" : "FLATLINED"}>{rebooting ? "REBOOTING" : "FLATLINED"}</h1>
      </div>
      <svg className="death-cover__ekg" viewBox="0 0 1600 200" preserveAspectRatio="none" aria-hidden="true">
        <path className="death-cover__ekg-track" d="M0 100 H1600" />
        {rebooting
          ? <path className="death-cover__ekg-beat" pathLength={1000} d="M0 100 H600 L630 90 L652 110 L672 100 H720 L748 24 L782 178 L808 100 H860 L888 88 L912 100 H1600" />
          : <path className="death-cover__ekg-line" pathLength={1000} d="M0 100 H260 L284 92 L302 108 L320 100 H370 L396 38 L426 164 L450 100 H500 L522 94 L540 100 H1600" />}
      </svg>
      <div className="death-cover__vitals">{rebooting
        ? <><span>HR <b>072</b></span><span>NEURAL LINK <b className="death-cover__boot" /></span><span>SYNC</span></>
        : <><span>HR <b>000</b></span><span>SpO2 <b>--</b></span><span>BP <b>--/--</b></span></>}</div>
    </div>
    <div className="death-cover__flash" />
  </div>;
}
