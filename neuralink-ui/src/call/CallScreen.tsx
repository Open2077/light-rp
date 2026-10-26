/* Outgoing ("Linking…" with orbiting dots) and active call (timer, live voice
   rings from nl:talkers, mute, add participant, hang up). */
import { useState } from "react";
import { Mic, MicOff, PhoneOff, UserPlus, Users, X } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import { CALL_MAX_PARTICIPANTS, type CallParticipant, type CallState } from "@/bridge/protocol";
import { HoloPanel } from "@/components/HoloPanel";
import { ContactPicker } from "@/components/ContactPicker";
import { Avatar } from "@/components/ui";
import { act } from "@/store/actions";
import { displayName } from "@/lib/format";
import { play } from "@/fx/sound";
import { callTitle, others, useCallTimer } from "./model";

const STATE_TEXT: Record<CallParticipant["state"], string> = { ringing: "Ringing…", connected: "Linked", left: "Left" };

export function CallScreen({ call }: { call: CallState }) {
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const talkers = useStore((s) => s.talkers);
  const timer = useCallTimer(call.startedAt);
  const [adding, setAdding] = useState(false);
  const title = callTitle(call, contacts);
  const outgoing = call.phase === "outgoing";
  const people = call.participants.filter((p) => p.state !== "left" || !p.isMe);
  const me = call.participants.find((p) => p.isMe);
  const meLevel = me ? talkers[me.lineId] ?? 0 : 0;
  const live = call.participants.filter((p) => p.state !== "left").length;
  const peak = outgoing ? 0 : Math.max(0, ...Object.values(talkers));

  const hangup = () => { play("back"); void act("call.hangup", {}); };
  const mute = () => { play("select"); void act("call.mute", { muted: !call.muted }); };
  const add = async (number: string) => { if (await act("call.add", { number })) { play("select"); setAdding(false); } };

  return (
    <HoloPanel className={`callscreen ${outgoing ? "is-outgoing" : "is-active"}`} tag={`NL//CALL-${String(call.id).padStart(4, "0")}`}>
      <div className="callscreen__bg" aria-hidden><i /><i /><i /></div>
      <header className="callscreen__head">
        <span className="callscreen__kind label">{call.group ? <><Users size={15} /> Group call</> : outgoing ? "Outgoing call" : "Neural call"}</span>
        <div className="callscreen__title">{title}</div>
        <div className="callscreen__status">
          {outgoing || call.startedAt == null ? (
            <span className="linking"><span className="label">Linking</span><span className="linking__dots"><i /><i /><i /></span></span>
          ) : (
            <span className="callscreen__timer mono"><span className="rec-dot" />{timer}</span>
          )}
        </div>
      </header>

      {outgoing && others(call).length === 1 ? (
        <div className="orbit">
          <span className="orbit__path" />
          <span className="orbit__sat" style={{ ["--d" as string]: "0s" }} />
          <span className="orbit__sat" style={{ ["--d" as string]: "-0.8s" }} />
          <span className="orbit__sat" style={{ ["--d" as string]: "-1.6s" }} />
          <Avatar name={title} seed={others(call)[0]!.number} size={128} ring="ringing" />
        </div>
      ) : (
        <div className={`parts parts--n${Math.min(6, people.length)}`}>
          {people.map((p, i) => {
            const level = p.state === "connected" && !(p.isMe && call.muted) ? talkers[p.lineId] ?? 0 : 0;
            const name = p.isMe ? "You" : displayName(contacts, p.number, p.name);
            return (
              <div key={p.lineId} className={`part is-${p.state} ${level > 0.05 ? "is-talking" : ""}`} style={{ ["--i" as string]: i }}>
                <Avatar name={p.isMe ? me?.name ?? "You" : name} seed={p.number} size={92} level={level} ring={p.state === "ringing" ? "ringing" : "none"} />
                <span className="part__name">{name}</span>
                <span className="part__state mono">
                  {(p.isMe ? call.muted : p.muted) && p.state === "connected" ? <><MicOff size={12} /> muted</> : STATE_TEXT[p.state]}
                </span>
              </div>
            );
          })}
        </div>
      )}

      {adding && (
        <div className="callscreen__add">
          <div className="callscreen__addhead">
            <span className="label">Add to call · {live}/{CALL_MAX_PARTICIPANTS}</span>
            <button type="button" className="icon-btn" aria-label="Close" onClick={() => setAdding(false)}><X size={18} /></button>
          </div>
          <ContactPicker mode="single" exclude={call.participants.filter((p) => p.state !== "left").map((p) => p.number)} onPick={add} pickLabel="Invite" />
        </div>
      )}

      <div className={`wave ${peak > 0.05 ? "is-live" : ""}`} style={{ ["--level" as string]: peak.toFixed(2) }} aria-hidden>
        {Array.from({ length: 32 }, (_, i) => <i key={i} style={{ ["--i" as string]: i }} />)}
      </div>
      <footer className="callscreen__controls">
        <button type="button" className={`cbtn ${call.muted ? "cbtn--on" : ""} ${meLevel > 0.05 ? "is-talking" : ""}`} onClick={mute} disabled={outgoing}>
          <span className="cbtn__disc">{call.muted ? <MicOff size={26} /> : <Mic size={26} />}</span>
          <span className="label">{call.muted ? "Unmute" : "Mute"}</span>
        </button>
        <button type="button" className="cbtn cbtn--danger cbtn--big" onClick={hangup}>
          <span className="cbtn__disc"><PhoneOff size={32} /></span>
          <span className="label">{outgoing ? "Cancel" : "Hang up"}</span>
        </button>
        <button type="button" className={`cbtn ${adding ? "cbtn--on" : ""}`} onClick={() => { play("select"); setAdding((v) => !v); }} disabled={!call.canAdd}>
          <span className="cbtn__disc"><UserPlus size={26} /></span>
          <span className="label">Add</span>
        </button>
      </footer>
    </HoloPanel>
  );
}
