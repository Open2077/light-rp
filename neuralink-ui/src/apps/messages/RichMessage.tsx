/* What another resource attached to a message (MessageMeta): a job card, a location
   that pins a waypoint on the map, and buttons answered once (Accept / Pass / Share).
   A button with `input: "contact"` asks for a contact or a number first (sharing a
   fixer's gig with a crewmate). The sender resource answers with nl:messageUpdate:
   the buttons give way to the resolved state. */
import { useState } from "react";
import { Check, MapPin, Share2, X } from "lucide-react";
import type { Message, MessageAction } from "@/bridge/protocol";
import { ContactPicker } from "@/components/ContactPicker";
import { act, toastInfo } from "@/store/actions";
import { play } from "@/fx/sound";

const asList = <T,>(v: unknown): T[] => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v as Record<string, T>) : []) as T[];

function icon(a: MessageAction) {
  if (a.input === "contact") return <Share2 size={14} />;
  if (a.style === "danger") return <X size={14} />;
  if (a.style === "primary") return <Check size={14} />;
  return null;
}

export function RichMessage({ m }: { m: Message }) {
  const meta = m.meta;
  const [busy, setBusy] = useState<string | null>(null);
  const [picking, setPicking] = useState<MessageAction | null>(null);
  if (!meta) return null;
  const actions = asList<MessageAction>(meta.actions);
  const lines = asList<string>(meta.card?.lines);
  const loc = meta.location;

  const press = async (a: MessageAction, value?: string) => {
    if (busy) return;
    if (a.input === "contact" && !value) { play("select"); setPicking(a); return; }
    setBusy(a.id);
    play("select");
    const done = await act("messages.action", { messageId: m.id, action: a.id, ...(value ? { value } : {}) });
    setBusy(null);
    // the sender resource answers (a notice, the message updated); the picker closes
    if (done && value) setPicking(null);
  };

  const pin = async () => {
    if (!loc) return;
    play("select");
    const done = await act("map.pin", { x: loc.x, y: loc.y, z: loc.z, ...(loc.label ? { label: loc.label } : {}) });
    if (done) toastInfo("Waypoint set", loc.label ?? "Pinned on your map.");
  };

  return (
    <div className="rich" onClick={(e) => e.stopPropagation()}>
      {meta.card && (
        <div className="rich__card">
          {meta.card.tag && <span className="rich__tag mono">{meta.card.tag}</span>}
          <b className="rich__title">{meta.card.title}</b>
          {meta.card.subtitle && <span className="rich__sub">{meta.card.subtitle}</span>}
          {lines.length > 0 && <ul className="rich__lines">{lines.map((l, i) => <li key={i}>{l}</li>)}</ul>}
        </div>
      )}
      {loc && (
        <button type="button" className="btn btn--sm btn--ghost rich__pin" onClick={() => { void pin(); }}>
          <MapPin size={14} /> <span>{loc.label ? `Pin ${loc.label}` : "Pin on map"}</span>
        </button>
      )}
      {meta.resolved ? (
        <span className={`rich__resolved rich__resolved--${meta.resolved.tone ?? "dim"} mono`}>{meta.resolved.label}</span>
      ) : actions.length > 0 && (
        <div className="rich__actions">
          {actions.map((a) => (
            <button key={a.id} type="button" disabled={busy !== null}
              className={`btn btn--sm ${a.style === "primary" ? "btn--ok" : a.style === "danger" ? "btn--danger" : "btn--ghost"} ${picking?.id === a.id ? "is-on" : ""}`}
              onClick={() => { if (picking?.id === a.id) setPicking(null); else void press(a); }}>
              {icon(a)} <span>{busy === a.id ? "…" : a.label}</span>
            </button>
          ))}
        </div>
      )}
      {picking && !meta.resolved && (
        <div className="rich__picker">
          <span className="label">{picking.label}: pick a contact or type a number</span>
          <ContactPicker mode="single" onPick={(number) => { void press(picking, number); }} pickLabel="Send" />
        </div>
      )}
    </div>
  );
}
