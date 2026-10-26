/* Pings: who gave Street Cred, echoed, quoted, replied, mentioned or followed.
   Opening the first page marks everything read. */
import { useEffect, useMemo, useState, type ReactNode, type UIEvent } from "react";
import { AtSign, Bell, MessageCircle, Quote, Repeat2, UserPlus, Zap } from "lucide-react";
import { useStore } from "@/store/store";
import type { SocialPing, SocialPingKind } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Empty, Loader } from "@/components/ui";
import { loadPings, openProfile, openScream } from "@/store/actions";
import { relative } from "@/lib/format";
import { listKeys, useWindowKeys } from "@/shell/keys";

const KINDS: Record<SocialPingKind, { icon: ReactNode; text: string }> = {
  cred: { icon: <Zap size={15} strokeWidth={2.4} />, text: "gave you Street Cred" },
  echo: { icon: <Repeat2 size={16} strokeWidth={2.4} />, text: "echoed your scream" },
  quote: { icon: <Quote size={14} strokeWidth={2.4} />, text: "quoted your scream" },
  reply: { icon: <MessageCircle size={15} strokeWidth={2.4} />, text: "replied to you" },
  mention: { icon: <AtSign size={15} strokeWidth={2.4} />, text: "mentioned you" },
  follow: { icon: <UserPlus size={15} strokeWidth={2.4} />, text: "started following you" },
};

const openPing = (p: SocialPing) => (p.kind === "follow" || !p.post ? openProfile(p.actor.handle) : openScream(p.post.id));

export function PingsView({ canBack }: { canBack: boolean }) {
  const cache = useStore((s) => s.pings);
  const [kbd, setKbd] = useState(-1);
  const pings = cache?.pings ?? [];
  useEffect(() => {
    void loadPings();
    return () => useStore.getState().pingsSeen();
  }, []);
  useWindowKeys(useMemo(() => listKeys(pings.length, kbd, setKbd, (i) => { const p = pings[i]; if (p) openPing(p); }), [pings, kbd]));

  const onScroll = (e: UIEvent<HTMLDivElement>) => {
    const el = e.currentTarget;
    if (el.scrollHeight - el.scrollTop - el.clientHeight < 200) void loadPings(true);
  };
  const fresh = pings.filter((p) => !p.read).length;

  return (
    <Window icon={<Bell size={22} />} title="Pings" subtitle={fresh ? `${fresh} new since last time` : "All caught up"} tag="NL//06-PNG" canBack={canBack}>
      {!cache || cache.loading ? (
        <Loader text="Listening for pings" />
      ) : pings.length === 0 ? (
        <Empty icon={<Bell size={30} />} title="No pings" body="Scream something. The city will answer." />
      ) : (
        <div className="list nl-scroll" onScroll={onScroll}>
          {pings.map((p, i) => {
            const k = KINDS[p.kind] ?? KINDS.mention;
            return (
              <button
                key={p.id}
                type="button"
                className={`pingrow pingrow--${p.kind} ${p.read ? "" : "is-new"} ${kbd === i ? "is-kbd" : ""}`}
                style={{ ["--i" as string]: Math.min(i, 14) }}
                onClick={() => openPing(p)}
              >
                <span className="pingrow__kind">{k.icon}</span>
                <Avatar name={p.actor.name} seed={p.actor.seed} size={42} online={p.actor.online} />
                <span className="pingrow__main">
                  <span className="pingrow__line"><b>{p.actor.name}</b> <span className="mono">@{p.actor.handle}</span> {k.text}</span>
                  {p.post && <span className="pingrow__post">{p.post.body || "Echo"}</span>}
                </span>
                <span className="pingrow__time">{relative(p.at)}</span>
              </button>
            );
          })}
          {cache.loadingMore && <Loader text="Older pings" />}
        </div>
      )}
    </Window>
  );
}
