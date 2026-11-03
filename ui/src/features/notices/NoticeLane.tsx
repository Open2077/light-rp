import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { Notification } from "@/design/components";
import "./notices.css";

/* Centre-left notification stack: server notices (`lightrp:ui:notice`) and command
   results. FIFO, six deep, each with its own lifetime bar; wipe-out then removal.
   When the crew frame or its invite prompt (bottom-left stack) climbs to the
   notices' height (a big crew, a weapon out, 720p), the lane steps to their right. */
export function NoticeLane() {
  const notices = useStore((s) => s.notices);
  const creating = useStore((s) => s.connected && s.state.character.status !== "active");
  const cinematic = useStore(s => s.state.tutorial?.active && (s.state.tutorial.step === "intro" || s.state.tutorial.dialogue || s.state.tutorial.step === "outro"));
  const dismiss = useStore((s) => s.dismissNotice);
  const remove = useStore((s) => s.removeNotice);
  const [, tick] = useState(0);
  const lane = useRef<HTMLDivElement>(null);
  const [beside, setBeside] = useState<number | undefined>();

  useLayoutEffect(() => {
    const el = lane.current;
    if (!el) { if (beside !== undefined) setBeside(undefined); return; }
    const r = el.getBoundingClientRect();
    let right = 0;
    for (const crew of document.querySelectorAll<HTMLElement>(".hud__bottom-left > .crew-frame, .hud__bottom-left > .crew-invite")) {
      const c = crew.getBoundingClientRect();
      if (c.height > 0 && c.top < r.bottom + 8 && c.bottom > r.top - 8) right = Math.max(right, c.right);
    }
    const next = right > 0 ? Math.round(right + 16) : undefined;
    if (next !== beside) setBeside(next);
  });

  useEffect(() => {
    if (notices.length === 0) return;
    const timer = setInterval(() => tick((t) => t + 1), 100);
    return () => clearInterval(timer);
  }, [notices.length]);

  useEffect(() => {
    const now = Date.now();
    for (const n of notices) {
      if (n.dismissing) continue;
      if (now - n.createdAt >= n.durationMs) {
        dismiss(n.id);
        setTimeout(() => remove(n.id), 200);
      }
    }
  });

  if (creating || cinematic || notices.length === 0) return null;
  return (
    <div ref={lane} className="notices o77-stack" style={beside ? { left: beside } : undefined}>
      {notices.map((n) => (
        <Notification key={n.id} kind={n.kind} title={n.title} body={n.body} source={n.source}
          remaining={1 - Math.min(1, (Date.now() - n.createdAt) / n.durationMs)} dismissing={n.dismissing}
          onClose={() => { dismiss(n.id); setTimeout(() => remove(n.id), 200); }} className="o77-interactive" />
      ))}
    </div>
  );
}
