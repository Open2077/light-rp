/* Inbox: threads most recent first, search, unread badges, group icons. */
import { useMemo, useState } from "react";
import { MessageSquare, MessageSquarePlus, Search, Users } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import type { ThreadSummary } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Btn, Empty, Field, IconBtn } from "@/components/ui";
import { navigate, openThread } from "@/store/actions";
import { listStamp } from "@/lib/format";
import { listKeys, useWindowKeys } from "@/shell/keys";

export function threadPeer(t: ThreadSummary) {
  return t.kind === "direct" ? t.members.find((m) => !m.isMe) ?? null : null;
}

export function preview(t: ThreadSummary): string {
  if (!t.last) return "No messages yet";
  if (t.last.kind === "system") return t.last.body;
  if (t.last.mine) return `You: ${t.last.body}`;
  if (t.kind === "group") return `${t.last.sender.split(" ")[0]}: ${t.last.body}`;
  return t.last.body;
}

export function ThreadList({ canBack }: { canBack: boolean }) {
  const threads = useStore((s) => s.state?.threads ?? EMPTY);
  const [q, setQ] = useState("");
  const [kbd, setKbd] = useState(-1);
  const list = useMemo(() => {
    const ql = q.trim().toLowerCase();
    if (!ql) return threads;
    return threads.filter((t) =>
      t.title.toLowerCase().includes(ql) ||
      (t.last?.body.toLowerCase().includes(ql) ?? false) ||
      t.members.some((m) => m.name.toLowerCase().includes(ql) || m.number.includes(ql)));
  }, [threads, q]);
  useWindowKeys(useMemo(() => listKeys(list.length, kbd, setKbd, (i) => { const t = list[i]; if (t) openThread(t.id); }), [list, kbd]));
  const unread = threads.reduce((n, t) => n + t.unread, 0);

  return (
    <Window
      icon={<MessageSquare size={22} />}
      title="Messages"
      subtitle={unread ? `${unread} unread` : `${threads.length} threads`}
      tag="NL//03-MSG"
      canBack={canBack}
      actions={
        <>
          <IconBtn label="New group" onClick={() => navigate({ app: "messages", screen: "group-new" })}><Users size={18} /></IconBtn>
          <IconBtn label="New message" tone="sel" onClick={() => navigate({ app: "messages", screen: "new" })}><MessageSquarePlus size={18} /></IconBtn>
        </>
      }
    >
      <div className="msgs">
        <Field icon={<Search size={16} />} placeholder="Search messages and people" value={q} onChange={(e) => { setQ(e.target.value); setKbd(-1); }} className="msgs__search" />
        {threads.length === 0 ? (
          <Empty
            icon={<MessageSquare size={30} />}
            title="No conversations"
            body="Start a thread with a number or a contact."
            action={<Btn tone="sel" small icon={<MessageSquarePlus size={16} />} onClick={() => navigate({ app: "messages", screen: "new" })}>New message</Btn>}
          />
        ) : list.length === 0 ? (
          <Empty icon={<Search size={30} />} title="No match" body={`Nothing for "${q}".`} />
        ) : (
          <div className="list nl-scroll">
            {list.map((t, i) => {
              const peer = threadPeer(t);
              return (
                <button
                  key={t.id}
                  type="button"
                  className={`trow ${t.unread ? "is-unread" : ""} ${kbd === i ? "is-kbd" : ""}`}
                  style={{ ["--i" as string]: Math.min(i, 14) }}
                  onClick={() => openThread(t.id)}
                >
                  <Avatar name={t.title} seed={peer?.number ?? `g${t.id}`} size={48} group={t.kind === "group"} online={peer ? peer.online : null} />
                  <span className="trow__main">
                    <span className="trow__top">
                      <span className="trow__title">{t.title}</span>
                      {t.kind === "group" && <span className="trow__count mono"><Users size={12} /> {t.members.length}</span>}
                    </span>
                    <span className={`trow__prev ${t.last?.kind === "system" ? "is-system" : ""}`}>{preview(t)}</span>
                  </span>
                  <span className="trow__side">
                    <span className="trow__time">{t.last ? listStamp(t.last.at) : ""}</span>
                    {t.unread > 0 && <span className="badge mono">{t.unread > 99 ? "99+" : t.unread}</span>}
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>
    </Window>
  );
}
