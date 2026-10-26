/* Neural-Link root: the scaled stage holds the interface (only while opened and
   after the first state), plus the always-on layers: incoming call card, call
   HUD, call-ended card and toasts (none of them without an implant). */
import { lazy, Suspense } from "react";
import { Stage, useRootTheme } from "./shell/Stage";
import { Shell } from "./shell/Shell";
import { useBridgeEvents } from "./store/events";
import { useKeyboardAndTyping } from "./shell/keys";
import { implantLocked, useStore } from "./store/store";
import { IncomingFloating } from "./call/IncomingCall";
import { CallHud } from "./call/CallHud";
import { CallEndCard } from "./call/CallEndCard";
import { Toasts } from "./toasts/Toasts";
import { isMock } from "./bridge/open77";

const MockPanel = lazy(() => import("./bridge/MockPanel"));

export function App() {
  useBridgeEvents();
  useKeyboardAndTyping();
  useRootTheme();
  const visible = useStore((s) => s.phase !== "closed" && s.state !== null);
  const locked = useStore(implantLocked);

  const showDev = isMock() && new URLSearchParams(location.search).get("dev") !== "0";
  return (
    <>
      <Stage>
        {visible && <Shell />}
        {!locked && (
          <>
            <IncomingFloating />
            <CallHud />
            <CallEndCard />
            <Toasts />
          </>
        )}
      </Stage>
      {showDev && (
        <Suspense fallback={null}>
          <MockPanel />
        </Suspense>
      )}
    </>
  );
}
