import { useLayoutEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";

/* While op77_weaponhud's hologram is up (a weapon out) the page's own weapon readout
   stands down, and the stack above it (the crew frame, the safe-zone chip) would drop
   onto the hologram. This keeps the stack clear up to the hologram's top edge
   (hud.weapon.externalTop, px from the screen bottom). Its own bottom does not depend on
   its height (the stack grows upward from the vitals), so one measure is stable. */
export function WeaponGap() {
  const top = useStore((s) => s.hud.weapon?.externalTop ?? 0);
  const ref = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState(0);
  useLayoutEffect(() => {
    if (top <= 0) { setHeight(0); return; }
    const measure = () => {
      const el = ref.current;
      if (!el) return;
      const below = window.innerHeight - el.getBoundingClientRect().bottom;
      setHeight(Math.max(0, Math.ceil(top - below)));
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [top]);
  if (top <= 0) return null;
  return <div ref={ref} className="hud__weapon-gap" style={{ height }} aria-hidden="true" />;
}
