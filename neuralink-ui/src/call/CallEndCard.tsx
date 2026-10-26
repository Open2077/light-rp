/* nl:callEnded: a short end card (2.5 s) with the reason and duration. */
import { useEffect } from "react";
import { PhoneOff } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import { endReasonText } from "@/bridge/errors";
import { displayName, duration } from "@/lib/format";

export function CallEndCard() {
  const ended = useStore((s) => s.ended);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  useEffect(() => {
    if (!ended) return;
    const t = window.setTimeout(() => useStore.getState().setEnded(null), 2500);
    return () => window.clearTimeout(t);
  }, [ended]);
  if (!ended) return null;
  const who = ended.number ? displayName(contacts, ended.number, ended.name) : ended.name;
  const bad = ended.reason !== "hangup";
  return (
    <div className={`endcard ${bad ? "is-bad" : ""}`} key={ended.key} role="status">
      <span className="endcard__icon"><PhoneOff size={20} /></span>
      <span className="endcard__text">
        <span className="endcard__reason label">{endReasonText(ended.reason)}</span>
        <span className="endcard__who">{who ?? "Neural call"}{ended.duration ? <span className="mono"> · {duration(ended.duration)}</span> : null}</span>
      </span>
      <span className="endcard__bar" aria-hidden />
    </div>
  );
}
