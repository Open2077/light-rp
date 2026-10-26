/* "Link start": a thin light ring expands from the centre of the view, a hex
   shimmer band sweeps across, the scanlines flash once. Pure CSS animations on
   transform/opacity; unmounted when the opening phase ends. The Night City
   style turns it into a glitched boot (cyberpunk.css) with its own words. */
import { useEffect } from "react";
import { useSettings } from "@/store/store";
import { play } from "./sound";

export function LinkStart() {
  const cyber = useSettings().style !== "sao";
  // the glitch lands just after the "open" sound, on its own slot
  useEffect(() => {
    if (!cyber) return undefined;
    const t = window.setTimeout(() => play("glitch"), 90);
    return () => window.clearTimeout(t);
  }, [cyber]);
  return (
    <div className="linkstart" aria-hidden>
      <span className="linkstart__flash" />
      <span className="linkstart__ring linkstart__ring--a" />
      <span className="linkstart__ring linkstart__ring--b" />
      <span className="linkstart__ring linkstart__ring--c" />
      <span className="linkstart__cross" />
      <div className="linkstart__band">
        <svg width="100%" height="100%">
          <defs>
            <pattern id="nl-hex" width="28" height="48.5" patternUnits="userSpaceOnUse" patternTransform="scale(1.1)">
              <path d="M14 0 L28 8.08 L28 24.25 L14 32.33 L0 24.25 L0 8.08 Z M14 32.33 L14 48.5" fill="none" stroke="currentColor" strokeWidth="1.1" />
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#nl-hex)" />
        </svg>
      </div>
      <div className="linkstart__text">
        <span className="linkstart__word label">{cyber ? "Neural-Link" : "Link start"}</span>
        <span className="linkstart__sub mono">{cyber ? "kiroshi nl-77 · synapse handshake ok" : "neural handshake · ok"}</span>
      </div>
    </div>
  );
}
