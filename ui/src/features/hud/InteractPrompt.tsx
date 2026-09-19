import { useEffect, useRef, useState } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Keycap } from "@/design/components";
import "./interact.css";

/* The proximity prompt: a keycap and a few words beside the thing you can use.
   The client Lua keeps one page anchor (tag "interact") on the nearest point in
   range and tells us what it says (lightrp:ui:interact); the plugin projects the
   anchor every frame and we move the element straight from that frame, without
   a React render per frame. */

interface AnchorFrame { anchors?: Array<{ tag?: string; x: number; y: number; onScreen?: boolean }> }
interface InteractPayload { prompt?: string; key?: string }

export function InteractPrompt() {
  const [prompt, setPrompt] = useState<InteractPayload | null>(null);
  const ref = useRef<HTMLDivElement>(null);
  const seen = useRef(false);

  useEffect(() => on<InteractPayload>(PAGE_EVENTS.interact, (p) => setPrompt(p?.prompt ? p : null)), []);

  useEffect(() => {
    if (!prompt) return;
    seen.current = false;
    return on<AnchorFrame>("open77:anchors", (frame) => {
      const el = ref.current;
      if (!el) return;
      const a = frame?.anchors?.find((x) => x.tag === "interact");
      if (!a || a.onScreen === false) { el.style.opacity = "0"; return; }
      el.style.opacity = "1";
      el.style.transform = `translate(${(a.x * 100).toFixed(3)}vw, ${(a.y * 100).toFixed(3)}vh)`;
      seen.current = true;
    });
  }, [prompt]);

  if (!prompt) return null;
  return (
    <div ref={ref} className="interact" aria-live="polite" style={{ opacity: 0 }}>
      <Keycap tone="accent">{prompt.key ?? "E"}</Keycap>
      <span className="interact__text">{prompt.prompt}</span>
    </div>
  );
}
