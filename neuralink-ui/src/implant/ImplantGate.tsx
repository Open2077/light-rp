/* The implant gate, shown instead of the interface while the character has no
   Neural-Link: the Kiroshi diagnostic and installation sequence (HoloInstall).
   Closing the page drops it all; the next open starts again at the boot. */
import { useEffect, useState } from "react";
import { getStore, useStore } from "@/store/store";
import { HoloInstall } from "./HoloInstall";

export function ImplantGate() {
  const selfInstall = useStore((s) => s.state?.implant?.selfInstall !== false);
  // opened with { install: true }: the sequence confirms by itself
  const [autoStart] = useState(() => getStore().implantAutoStart);
  useEffect(() => { if (getStore().implantAutoStart) useStore.setState({ implantAutoStart: false }); }, []);
  return (
    <div className="implant">
      <HoloInstall selfInstall={selfInstall} autoStart={autoStart} />
    </div>
  );
}
