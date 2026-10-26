/* Incoming call: a small ringing pill at the top while the interface is
   closed (IncomingFloating); the full card, pulsing rings around the caller,
   Accept / Decline, docked in the panel area once it is open. The ringtone
   itself is a server-side 3D sound. */
import { Phone, PhoneOff, Users } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import type { CallState } from "@/bridge/protocol";
import { HoloPanel } from "@/components/HoloPanel";
import { Avatar } from "@/components/ui";
import { act } from "@/store/actions";
import { displayName } from "@/lib/format";
import { play } from "@/fx/sound";
import { caller, others } from "./model";

export function IncomingCall({ call }: { call: CallState }) {
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const from = caller(call);
  const name = call.group ? call.group.title : from ? displayName(contacts, from.number, from.name) : "Unknown";
  const sub = call.group
    ? `${from ? displayName(contacts, from.number, from.name) : "Someone"} is calling the group · ${others(call).length} members`
    : from && displayName(contacts, from.number, from.name) !== from.number ? from.number : "Unknown number";

  const accept = () => { play("select"); void act("call.accept", {}); };
  const decline = () => { play("back"); void act("call.decline", {}); };

  return (
    <HoloPanel className="incoming incoming--docked" tag="NL//CALL-IN">
      <div className="incoming__label label">{call.group ? "Incoming group call" : "Incoming neural call"}</div>
      <div className="incoming__orb">
        <span className="incoming__wave" style={{ ["--d" as string]: "0s" }} />
        <span className="incoming__wave" style={{ ["--d" as string]: "0.6s" }} />
        <span className="incoming__wave" style={{ ["--d" as string]: "1.2s" }} />
        <span className="incoming__dotring" aria-hidden><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="48" /></svg></span>
        <Avatar name={name} seed={call.group ? `g${call.group.threadId}` : from?.number ?? "?"} size={132} group={!!call.group} />
      </div>
      <div className="incoming__name">{name}</div>
      <div className="incoming__sub mono">{sub}</div>
      {call.group && (
        <div className="incoming__members">
          {others(call).slice(0, 6).map((p) => (
            <span key={p.lineId} className={`incoming__m ${p.state === "connected" ? "is-on" : ""}`} title={p.name}>
              <Avatar name={displayName(contacts, p.number, p.name)} seed={p.number} size={30} />
            </span>
          ))}
          {others(call).length > 6 && <span className="incoming__more mono">+{others(call).length - 6}</span>}
          <Users size={14} />
        </div>
      )}
      <div className="incoming__actions">
          <button type="button" className="cbtn cbtn--danger" onClick={decline}>
            <span className="cbtn__disc"><PhoneOff size={30} /></span><span className="label">Decline</span>
          </button>
          <button type="button" className="cbtn cbtn--ok cbtn--throb" onClick={accept}>
            <span className="cbtn__disc"><Phone size={30} /></span><span className="label">Accept</span>
          </button>
      </div>
    </HoloPanel>
  );
}

/** While the interface is closed: a small ringing pill at the top of the
    screen, the same family as the call HUD. Opening the Neural-Link expands it
    into the full card (docked in the panel area). */
export function IncomingFloating() {
  const call = useStore((s) => s.state?.call ?? null);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const key = useStore((s) => s.toggleKey);
  const shellUp = useStore((s) => s.phase !== "closed" && s.state !== null);
  if (!call || call.phase !== "incoming" || shellUp) return null;
  const from = caller(call);
  const name = call.group ? call.group.title : from ? displayName(contacts, from.number, from.name) : "Unknown";
  const known = !call.group && !!from && name !== from.number;
  return (
    <div className="inpill" key={call.id}>
      <span className="inpill__icon">
        <span className="inpill__wave" style={{ ["--d" as string]: "0s" }} />
        <span className="inpill__wave" style={{ ["--d" as string]: "0.6s" }} />
        {call.group ? <Users size={17} /> : <Phone size={17} />}
      </span>
      <span className="inpill__text">
        <span className="inpill__label label">{call.group ? "Incoming group call" : "Incoming call"}</span>
        <span className="inpill__name">
          {name}
          {known && <span className="inpill__num mono">{from!.number}</span>}
        </span>
      </span>
      <span className="inpill__key"><kbd className="mono">{key}</kbd><span className="label">answer</span></span>
    </div>
  );
}
