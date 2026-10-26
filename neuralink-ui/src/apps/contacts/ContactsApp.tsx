/* Contacts: alphabetical sections with a letter index, favourite star,
   online dot, call / message / edit actions. */
import { useMemo, useRef, useState } from "react";
import { BookUser, MessageSquare, Pencil, Phone, Search, Star, UserPlus } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import type { Contact } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Btn, Empty, Field, IconBtn, Segmented } from "@/components/ui";
import { act, dial, messageNumber, navigate } from "@/store/actions";
import { listKeys, useWindowKeys } from "@/shell/keys";
import { play } from "@/fx/sound";

const letterOf = (name: string) => {
  const c = name.trim()[0]?.toUpperCase() ?? "#";
  return /[A-Z]/.test(c) ? c : "#";
};

export function ContactsApp({ filter, canBack }: { filter: "all" | "favorites"; canBack: boolean }) {
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const inCall = useStore((s) => !!s.state?.call);
  const [q, setQ] = useState("");
  const [kbd, setKbd] = useState(-1);
  const scroller = useRef<HTMLDivElement>(null);

  const list = useMemo(() => {
    const ql = q.trim().toLowerCase();
    return contacts
      .filter((c) => filter === "all" || c.favorite)
      .filter((c) => !ql || c.name.toLowerCase().includes(ql) || c.number.includes(ql))
      .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
  }, [contacts, q, filter]);

  const sections = useMemo(() => {
    const out: { letter: string; items: { c: Contact; idx: number }[] }[] = [];
    list.forEach((c, idx) => {
      const l = letterOf(c.name);
      const last = out[out.length - 1];
      if (last && last.letter === l) last.items.push({ c, idx });
      else out.push({ letter: l, items: [{ c, idx }] });
    });
    return out;
  }, [list]);
  const letters = sections.map((s) => s.letter);

  useWindowKeys(useMemo(() => listKeys(list.length, kbd, setKbd, (i) => { const c = list[i]; if (c) void dial(c.number); }), [list, kbd]));

  const setFilter = (f: "all" | "favorites") => useStore.getState().replaceTop({ app: "contacts", screen: "list", filter: f });
  const toggleFav = async (c: Contact) => {
    play("select");
    await act("contacts.save", { id: c.id, name: c.name, number: c.number, favorite: !c.favorite });
  };
  const jump = (l: string) => {
    play("tick");
    scroller.current?.querySelector(`[data-letter="${l}"]`)?.scrollIntoView({ block: "start", behavior: "smooth" });
  };

  return (
    <Window
      icon={<BookUser size={22} />}
      title="Contacts"
      subtitle={`${contacts.length} saved · ${contacts.filter((c) => c.online).length} online`}
      tag="NL//04-DIR"
      canBack={canBack}
      actions={<IconBtn label="Add contact" tone="sel" onClick={() => navigate({ app: "contacts", screen: "edit" })}><UserPlus size={18} /></IconBtn>}
    >
      <div className="contacts">
        <div className="contacts__bar">
          <Segmented value={filter} onChange={setFilter} options={[{ id: "all", label: "All" }, { id: "favorites", label: "Favorites", icon: <Star size={14} /> }]} />
          <Field icon={<Search size={16} />} placeholder="Search" value={q} onChange={(e) => { setQ(e.target.value); setKbd(-1); }} />
        </div>
        {list.length === 0 ? (
          contacts.length === 0 ? (
            <Empty icon={<BookUser size={30} />} title="No contacts" body="Save the numbers you meet in Night City."
              action={<Btn tone="sel" small icon={<UserPlus size={16} />} onClick={() => navigate({ app: "contacts", screen: "edit" })}>Add contact</Btn>} />
          ) : (
            <Empty icon={filter === "favorites" ? <Star size={30} /> : <Search size={30} />} title={filter === "favorites" && !q ? "No favorites" : "No match"} body={filter === "favorites" && !q ? "Tap the star on a contact to pin it." : undefined} />
          )
        ) : (
          <div className="contacts__body">
            <div className="list nl-scroll" ref={scroller}>
              {sections.map((s) => (
                <div key={s.letter} className="csec">
                  <div className="csec__letter label" data-letter={s.letter}>{s.letter}</div>
                  {s.items.map(({ c, idx }) => (
                    <div key={c.id} className={`crow ${kbd === idx ? "is-kbd" : ""}`} style={{ ["--i" as string]: Math.min(idx, 14) }}>
                      <Avatar name={c.name} seed={c.number} size={44} online={c.online} />
                      <span className="crow__main">
                        <span className="crow__name">{c.name}</span>
                        <span className="crow__num mono">{c.number}<span className={`crow__state ${c.online ? "is-on" : ""}`}>{c.online ? "online" : "offline"}</span></span>
                      </span>
                      <span className="crow__acts">
                        <IconBtn label={c.favorite ? "Unstar" : "Star"} className={`star ${c.favorite ? "is-on" : ""}`} onClick={() => toggleFav(c)}><Star size={17} /></IconBtn>
                        <IconBtn label="Message" onClick={() => void messageNumber(c.number)}><MessageSquare size={17} /></IconBtn>
                        <IconBtn label="Call" tone="ok" disabled={inCall} onClick={() => void dial(c.number)}><Phone size={17} /></IconBtn>
                        <IconBtn label="Edit" onClick={() => navigate({ app: "contacts", screen: "edit", id: c.id })}><Pencil size={16} /></IconBtn>
                      </span>
                    </div>
                  ))}
                </div>
              ))}
            </div>
            {letters.length > 1 && (
              <div className="alpha" aria-label="Index">
                {letters.map((l) => <button key={l} type="button" className="alpha__l mono" onClick={() => jump(l)}>{l}</button>)}
              </div>
            )}
          </div>
        )}
      </div>
    </Window>
  );
}
