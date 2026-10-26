import { useEffect, useState } from "react";
import type { CallParticipant, CallState, Contact } from "@/bridge/protocol";
import { displayName, duration } from "@/lib/format";

export function others(call: CallState): CallParticipant[] {
  return call.participants.filter((p) => !p.isMe);
}

/** Who is calling (incoming): the connected other side, else the first one. */
export function caller(call: CallState): CallParticipant | undefined {
  const o = others(call);
  return o.find((p) => p.state === "connected") ?? o[0];
}

export function callTitle(call: CallState, contacts: Contact[]): string {
  if (call.group) return call.group.title;
  const o = others(call).filter((p) => p.state !== "left");
  const list = o.length ? o : others(call);
  if (list.length === 0) return "Call";
  if (list.length === 1) return displayName(contacts, list[0]!.number, list[0]!.name);
  return `${displayName(contacts, list[0]!.number, list[0]!.name)} +${list.length - 1}`;
}

/** Live "m:ss" since startedAt (1 Hz). */
export function useCallTimer(startedAt: number | null): string | null {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (startedAt == null) return;
    setNow(Date.now());
    const t = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(t);
  }, [startedAt]);
  return startedAt == null ? null : duration((now - startedAt) / 1000);
}
