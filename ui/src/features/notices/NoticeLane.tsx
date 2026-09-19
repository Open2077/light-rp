import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { Notification } from "@/design/components";
import "./notices.css";

/* Top-right notification stack: server notices (`lightrp:ui:notice`) and command
   results. FIFO, six deep, each with its own lifetime bar; wipe-out then removal. */
export function NoticeLane() {
  const notices = useStore((s) => s.notices);
  const dismiss = useStore((s) => s.dismissNotice);
  const remove = useStore((s) => s.removeNotice);
  const [, tick] = useState(0);

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

  if (notices.length === 0) return null;
  return (
    <div className="notices o77-stack">
      {notices.map((n) => (
        <Notification key={n.id} kind={n.kind} title={n.title} body={n.body} source={n.source}
          remaining={1 - Math.min(1, (Date.now() - n.createdAt) / n.durationMs)} dismissing={n.dismissing}
          onClose={() => { dismiss(n.id); setTimeout(() => remove(n.id), 200); }} className="o77-interactive" />
      ))}
    </div>
  );
}
