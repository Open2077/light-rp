/* Phone: keypad, recents (missed in red, tap to call back, clear all) and
   favorites (starred contacts). */
import { useCallback, useEffect, useMemo, useState } from "react";
import { Delete, Grid3x3, History, Phone, PhoneCall, PhoneIncoming, PhoneMissed, PhoneOff, PhoneOutgoing, Star, Trash2, UserPlus } from "lucide-react";
import { EMPTY, useStore, type PhoneTab } from "@/store/store";
import { Window } from "@/components/Window";
import { Avatar, Btn, Empty, IconBtn, Segmented } from "@/components/ui";
import { act, dial, navigate } from "@/store/actions";
import { NUMBER_RE, type Recent } from "@/bridge/protocol";
import { displayName, duration, formatNumberInput, relative } from "@/lib/format";
import { listKeys, useWindowKeys } from "@/shell/keys";
import { missedSince } from "@/shell/menu";
import { play } from "@/fx/sound";

export function PhoneApp({ tab, canBack }: { tab: PhoneTab; canBack: boolean }) {
  const state = useStore((s) => s.state);
  const seen = useStore((s) => s.recentsSeenAt);
  const missed = missedSince(state, seen);
  const setTab = (t: PhoneTab) => useStore.getState().replaceTop({ app: "phone", tab: t });

  useEffect(() => {
    if (tab === "recents") useStore.getState().markRecentsSeen();
  }, [tab, state?.recents]);

  return (
    <Window
      icon={<Phone size={22} />}
      title="Phone"
      subtitle={state?.line ? `Your line ${state.line.number}` : "No line"}
      tag="NL//02-TEL"
      canBack={canBack}
      bodyClass="phone"
    >
      <Segmented
        value={tab}
        onChange={setTab}
        options={[
          { id: "dial", label: "Keypad", icon: <Grid3x3 size={16} /> },
          { id: "recents", label: "Recents", icon: <History size={16} />, badge: missed },
          { id: "favorites", label: "Favorites", icon: <Star size={16} /> },
        ]}
      />
      <div className="phone__pane" key={tab}>
        {tab === "dial" && <DialPad />}
        {tab === "recents" && <Recents />}
        {tab === "favorites" && <Favorites />}
      </div>
    </Window>
  );
}

/* ------------------------------------------------------------- keypad */

const KEYS: [string, string][] = [
  ["1", ""], ["2", "ABC"], ["3", "DEF"], ["4", "GHI"], ["5", "JKL"], ["6", "MNO"], ["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"], ["*", ""], ["0", "+"], ["#", ""],
];

function DialPad() {
  const number = useStore((s) => s.dial);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const inCall = useStore((s) => !!s.state?.call);
  const [pressed, setPressed] = useState<string | null>(null);
  const set = (v: string) => useStore.getState().setDial(formatNumberInput(v));
  const valid = NUMBER_RE.test(number);
  const match = valid ? contacts.find((c) => c.number === number) : undefined;
  const suggestions = useMemo(() => {
    const digits = number.replace(/\D/g, "");
    if (!digits || valid) return [];
    return contacts.filter((c) => c.number.replace(/\D/g, "").startsWith(digits)).slice(0, 3);
  }, [number, contacts, valid]);

  const press = (k: string) => {
    if (!/\d/.test(k)) { play("tick"); return; }
    play("tick");
    setPressed(k);
    window.setTimeout(() => setPressed((p) => (p === k ? null : p)), 140);
    set(useStore.getState().dial + k);
  };
  const back = () => { play("back"); set(useStore.getState().dial.replace(/\D/g, "").slice(0, -1)); };
  const call = async () => { if (valid && (await dial(number))) set(""); };

  const keyHandler = useCallback((e: KeyboardEvent) => {
    if (/^\d$/.test(e.key)) { press(e.key); return true; }
    if (e.key === "Backspace") { back(); return true; }
    if (e.key === "Enter") { void call(); return true; }
    return false;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [number]);
  useWindowKeys(keyHandler);

  return (
    <div className="dial">
      <div className="dial__display">
        <input
          className="dial__input mono"
          value={number}
          placeholder="555-0000"
          inputMode="numeric"
          onChange={(e) => set(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void call(); } }}
          aria-label="Number"
        />
        <div className="dial__who">
          {match ? <><Avatar name={match.name} seed={match.number} size={22} online={match.online} /> {match.name}</> : valid ? "Unknown number" : suggestions.length ? "" : "Enter a 7-digit number"}
          {suggestions.map((c) => (
            <button key={c.id} type="button" className="dial__sugg" onClick={() => { play("select"); set(c.number); }}>
              {c.name} <span className="mono">{c.number}</span>
            </button>
          ))}
        </div>
        <IconBtn label="Delete digit" onClick={back} disabled={!number} className="dial__bs"><Delete size={22} /></IconBtn>
      </div>
      <div className="dial__grid">
        {KEYS.map(([k, sub], i) => (
          <button
            key={k}
            type="button"
            className={`dial__key ${pressed === k ? "is-pressed" : ""}`}
            style={{ ["--i" as string]: i }}
            onClick={() => press(k)}
          >
            <span className="dial__digit">{k}</span>
            <span className="dial__letters mono">{sub}</span>
          </button>
        ))}
      </div>
      <div className="dial__actions">
        {valid && !match && (
          <Btn tone="ghost" small icon={<UserPlus size={16} />} onClick={() => navigate({ app: "contacts", screen: "edit", number }, "reset")}>Save</Btn>
        )}
        <button type="button" className={`callbtn ${valid && !inCall ? "" : "is-off"}`} disabled={!valid || inCall} onClick={call} aria-label="Call">
          <span className="callbtn__glow" aria-hidden />
          <PhoneCall size={30} strokeWidth={2.2} />
        </button>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------- recents */

function RecentIcon({ r }: { r: Recent }) {
  if (r.direction === "in" && r.status === "missed") return <PhoneMissed size={18} />;
  if (r.status === "declined" || r.status === "busy" || r.status === "unavailable") return <PhoneOff size={18} />;
  return r.direction === "in" ? <PhoneIncoming size={18} /> : <PhoneOutgoing size={18} />;
}

const STATUS_TEXT: Record<Recent["status"], string> = { answered: "", missed: "Missed", declined: "Declined", busy: "Busy", unavailable: "Unreachable" };

function Recents() {
  const recents = useStore((s) => s.state?.recents ?? EMPTY);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const [confirm, setConfirm] = useState(false);
  const [kbd, setKbd] = useState(-1);
  useWindowKeys(useMemo(() => listKeys(recents.length, kbd, setKbd, (i) => { const r = recents[i]; if (r) void dial(r.number); }), [recents, kbd]));

  if (recents.length === 0) return <Empty icon={<History size={30} />} title="No recent calls" body="Calls you make and receive appear here." />;
  return (
    <div className="recents">
      <div className="recents__bar">
        <span className="label recents__count">{recents.length} calls</span>
        {confirm ? (
          <span className="recents__confirm">
            <span>Clear all recents?</span>
            <Btn small tone="danger" onClick={async () => { setConfirm(false); if (await act("recents.clear", {})) play("back"); }}>Clear</Btn>
            <Btn small tone="ghost" onClick={() => setConfirm(false)}>Cancel</Btn>
          </span>
        ) : (
          <Btn small tone="ghost" icon={<Trash2 size={15} />} onClick={() => setConfirm(true)}>Clear all</Btn>
        )}
      </div>
      <div className="list nl-scroll">
        {recents.map((r, i) => {
          const missed = r.direction === "in" && r.status === "missed";
          const name = displayName(contacts, r.number, r.name);
          const known = contacts.find((c) => c.number === r.number);
          return (
            <button
              key={r.id}
              type="button"
              className={`lrow ${missed ? "is-missed" : ""} ${kbd === i ? "is-kbd" : ""}`}
              style={{ ["--i" as string]: Math.min(i, 14) }}
              onClick={() => void dial(r.number)}
              title={`Call ${name}`}
            >
              <span className={`lrow__kind ${missed ? "is-missed" : r.status !== "answered" ? "is-dim" : ""}`}><RecentIcon r={r} /></span>
              <span className="lrow__main">
                <span className="lrow__title">{name}</span>
                <span className="lrow__sub">
                  {name !== r.number && <span className="mono">{r.number}</span>}
                  <span>{r.direction === "in" ? "Incoming" : "Outgoing"}{STATUS_TEXT[r.status] ? ` · ${STATUS_TEXT[r.status]}` : ""}{r.status === "answered" && r.duration > 0 ? ` · ${duration(r.duration)}` : ""}</span>
                </span>
              </span>
              <span className="lrow__side">
                <span className="lrow__time">{relative(r.at)}</span>
                {!known && <span className="lrow__tag label">Unknown</span>}
              </span>
              <span className="lrow__call"><PhoneCall size={18} /></span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

/* ----------------------------------------------------------- favorites */

function Favorites() {
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const favs = useMemo(() => contacts.filter((c) => c.favorite).sort((a, b) => a.name.localeCompare(b.name)), [contacts]);
  const [kbd, setKbd] = useState(-1);
  useWindowKeys(useMemo(() => listKeys(favs.length, kbd, setKbd, (i) => { const c = favs[i]; if (c) void dial(c.number); }), [favs, kbd]));
  if (favs.length === 0) {
    return (
      <Empty
        icon={<Star size={30} />}
        title="No favorites"
        body="Star a contact to pin it here."
        action={<Btn tone="ghost" small onClick={() => navigate({ app: "contacts", screen: "list", filter: "all" }, "reset")}>Open contacts</Btn>}
      />
    );
  }
  return (
    <div className="favs nl-scroll">
      {favs.map((c, i) => (
        <button
          key={c.id}
          type="button"
          className={`fav ${kbd === i ? "is-kbd" : ""}`}
          style={{ ["--i" as string]: i }}
          onClick={() => void dial(c.number)}
        >
          <Avatar name={c.name} seed={c.number} size={78} online={c.online} />
          <span className="fav__name">{c.name}</span>
          <span className="fav__num mono">{c.number}</span>
          <span className="fav__call"><PhoneCall size={15} /> Call</span>
        </button>
      ))}
    </div>
  );
}
