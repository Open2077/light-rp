/* Holographic notification slabs, top right: max 3, 5 s each, visible even
   when the interface is closed. Clickable only while it is open. */
import { useEffect, useState } from "react";
import { AlertTriangle, Info, Megaphone, MessageSquare, PhoneCall, PhoneMissed } from "lucide-react";
import { useStore, type ToastItem } from "@/store/store";
import { dial, openProfile, openScream, openThread } from "@/store/actions";
import { hhmm } from "@/lib/format";
import { play } from "@/fx/sound";

const LIFE = 5000;

const ICONS = {
  message: <MessageSquare size={20} />,
  call: <PhoneCall size={20} />,
  missed: <PhoneMissed size={20} />,
  info: <Info size={20} />,
  error: <AlertTriangle size={20} />,
  social: <Megaphone size={20} />,
};

export function Toasts() {
  const toasts = useStore((s) => s.toasts);
  const open = useStore((s) => s.phase === "open" || s.phase === "opening");
  return (
    <div className={`toasts ${open ? "is-open" : ""}`} aria-live="polite">
      {toasts.map((t, i) => <Toast key={t.key} t={t} depth={toasts.length - 1 - i} clickable={open} />)}
    </div>
  );
}

function Toast({ t, depth, clickable }: { t: ToastItem; depth: number; clickable: boolean }) {
  const [leaving, setLeaving] = useState(false);
  useEffect(() => {
    const left = Math.max(400, LIFE - (Date.now() - t.born));
    const a = window.setTimeout(() => setLeaving(true), left);
    const b = window.setTimeout(() => useStore.getState().dismissToast(t.key), left + 320);
    return () => { window.clearTimeout(a); window.clearTimeout(b); };
  }, [t.key, t.born]);

  const actionable = clickable && ((t.kind === "message" && t.threadId != null) || ((t.kind === "missed" || t.kind === "call") && !!t.number) || (t.kind === "social" && (t.postId != null || !!t.handle)));
  const onClick = () => {
    if (!clickable) return;
    if (t.kind === "message" && t.threadId != null) openThread(t.threadId, "reset");
    else if ((t.kind === "missed" || t.kind === "call") && t.number) void dial(t.number);
    else if (t.kind === "social" && t.postId != null) openScream(t.postId, "reset");
    else if (t.kind === "social" && t.handle) openProfile(t.handle, "reset");
    else play("back");
    useStore.getState().dismissToast(t.key);
  };

  return (
    <div
      className={`toast toast--${t.kind} ${leaving ? "is-leaving" : ""} ${clickable ? "nl-hit" : ""} ${actionable ? "is-actionable" : ""}`}
      style={{ ["--depth" as string]: depth }}
      onClick={onClick}
      role="status"
    >
      <span className="toast__icon">{ICONS[t.kind] ?? ICONS.info}</span>
      <span className="toast__text">
        <span className="toast__top">
          <span className="toast__title">{t.title}</span>
          <span className="toast__time mono">{hhmm(t.at || Date.now())}</span>
        </span>
        <span className="toast__body">{t.body}</span>
      </span>
      <span className="toast__life" style={{ animationDuration: `${LIFE}ms` }} aria-hidden />
      <span className="toast__scan" aria-hidden />
    </div>
  );
}
