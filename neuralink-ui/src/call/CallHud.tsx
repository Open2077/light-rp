/* Compact call HUD: a top-centre pill (name, timer, mute, talking glow) while
   a call runs and the call screen is not on view. */
import { MicOff, Mic, Phone, Users } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import { callTitle, useCallTimer } from "./model";
import { play } from "@/fx/sound";

export function CallHud() {
  const call = useStore((s) => s.state?.call ?? null);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const talkers = useStore((s) => s.talkers);
  const shellUp = useStore((s) => s.phase !== "closed" && s.phase !== "closing" && s.state !== null);
  const callView = useStore((s) => s.callView);
  const timer = useCallTimer(call?.startedAt ?? null);
  if (!call || call.phase === "incoming") return null;
  if (shellUp && callView) return null;

  const me = call.participants.find((p) => p.isMe);
  const meTalking = !!me && !call.muted && (talkers[me.lineId] ?? 0) > 0.05;
  const othersTalking = call.participants.some((p) => !p.isMe && (talkers[p.lineId] ?? 0) > 0.05);
  const peak = Math.max(0, ...Object.values(talkers));

  return (
    <button
      type="button"
      className={`callhud ${shellUp ? "nl-hit" : ""} ${othersTalking || meTalking ? "is-talking" : ""} ${call.muted ? "is-muted" : ""}`}
      style={{ ["--level" as string]: peak.toFixed(2) }}
      onClick={() => { if (shellUp) { play("select"); useStore.getState().setCallView(true); } }}
      tabIndex={shellUp ? 0 : -1}
    >
      <span className="callhud__glow" aria-hidden />
      <span className="callhud__icon">{call.group ? <Users size={16} /> : <Phone size={16} />}</span>
      <span className="callhud__name">{callTitle(call, contacts)}</span>
      <span className="callhud__time mono">{call.phase === "outgoing" || !timer ? "linking…" : timer}</span>
      <span className={`callhud__mic ${meTalking ? "is-live" : ""}`}>{call.muted ? <MicOff size={15} /> : <Mic size={15} />}</span>
    </button>
  );
}
