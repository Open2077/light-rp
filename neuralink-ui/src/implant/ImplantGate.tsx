/* The implant gate, shown instead of the interface while the character has no
   Neural-Link: "no Neural-Link detected" -> the installation sequence -> (an
   error with Retry) -> the normal opening. Closing the page drops it all; the
   next open starts again at the diagnostic. */
import { useEffect, useState } from "react";
import { getStore, useStore } from "@/store/store";
import { NoLink, InstallError } from "./NoLink";
import { Install } from "./Install";
import { STAGE_INDEX } from "./timeline";

type View = { kind: "nolink" } | { kind: "install"; from: number; run: number } | { kind: "error"; slug: string; run: number };

export function ImplantGate() {
  const selfInstall = useStore((s) => s.state?.implant?.selfInstall !== false);
  const [view, setView] = useState<View>({ kind: "nolink" });

  const start = (from: number, run: number) => {
    getStore().setImplantFlow(true);
    setView({ kind: "install", from, run });
  };
  const failed = (slug: string) => setView((v) => ({ kind: "error", slug, run: v.kind === "install" ? v.run : 0 }));

  // opened with { install: true }: straight into the sequence
  useEffect(() => {
    if (!getStore().implantAutoStart) return;
    useStore.setState({ implantAutoStart: false });
    if (selfInstall) start(0, 1);
  }, []);

  return (
    <div className="implant">
      {view.kind === "nolink" && <NoLink selfInstall={selfInstall} onInstall={() => start(0, 1)} />}
      {view.kind === "install" && <Install key={view.run} from={view.from} onFailed={failed} />}
      {/* a retry resumes at the insertion: the boot and the flash are done */}
      {view.kind === "error" && <InstallError slug={view.slug} onRetry={() => start(STAGE_INDEX.insert, view.run + 1)} />}
    </div>
  );
}
