/* Screamsheet feeds: Pulse / Crew / Hot (or one #tag), refresh, infinite
   scroll, and the floating "N new screams" pill fed by live posts on Pulse. */
import { useEffect, useRef, useState } from "react";
import { ArrowUp, Flame, Hash, Megaphone, PenLine, Radio, RefreshCw, Search, Users } from "lucide-react";
import { EMPTY, getStore, useStore } from "@/store/store";
import type { SocialFeedMode } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Btn, Empty, IconBtn, Loader, Segmented } from "@/components/ui";
import { loadFeed, navigate, tagKey } from "@/store/actions";
import { play } from "@/fx/sound";
import { ScreamList } from "./ScreamList";

const MODES: Record<SocialFeedMode, { sub: string; empty: [string, string] }> = {
  pulse: { sub: "Pulse · every citizen, live", empty: ["The sheet is blank", "Nobody has screamed yet. Be the first."] },
  crew: { sub: "Crew · people you follow", empty: ["Your crew is quiet", "Follow citizens from their profile to fill this feed."] },
  hot: { sub: "Hot · best of the last 24 h", empty: ["Nothing is burning", "Give Street Cred to the screams that matter."] },
};

export function FeedView({ mode, tag, canBack }: { mode?: SocialFeedMode; tag?: string; canBack: boolean }) {
  const key = tag != null ? tagKey(tag) : mode ?? "pulse";
  const feed = useStore((s) => s.feeds[key]);
  const fresh = useStore((s) => (key === "pulse" ? s.freshPosts : EMPTY));
  const scroller = useRef<HTMLDivElement>(null);
  const [spin, setSpin] = useState(false);

  useEffect(() => {
    if (!getStore().feeds[key]) void loadFeed(key);
  }, [key]);

  const refresh = async () => {
    play("select");
    setSpin(true);
    if (key === "pulse") getStore().takeFresh();
    await loadFeed(key);
    setSpin(false);
    scroller.current?.scrollTo({ top: 0, behavior: "smooth" });
  };
  const showFresh = () => {
    const st = getStore();
    st.prependPosts("pulse", st.takeFresh());
    play("select");
    scroller.current?.scrollTo({ top: 0, behavior: "smooth" });
  };
  const setMode = (m: SocialFeedMode) => getStore().replaceTop({ app: "social", screen: "feed", mode: m });
  const meta = tag == null ? MODES[mode ?? "pulse"] : null;
  const count = feed?.posts.length ?? 0;

  return (
    <Window
      icon={tag != null ? <Hash size={22} /> : <Megaphone size={22} />}
      title={tag != null ? `#${tag}` : "Screamsheet"}
      subtitle={meta ? meta.sub : `${count}${feed?.hasMore ? "+" : ""} screams on this tag`}
      tag={tag != null ? "NL//06-TAG" : "NL//06-SCR"}
      canBack={canBack}
      bodyClass="sfeed"
      actions={
        <>
          <IconBtn label="Search" onClick={() => navigate({ app: "social", screen: "heat", search: true })}><Search size={18} /></IconBtn>
          <IconBtn label="Refresh" className={spin ? "is-spinning" : ""} onClick={() => void refresh()}><RefreshCw size={18} /></IconBtn>
          <IconBtn label="Compose" tone="sel" onClick={() => navigate({ app: "social", screen: "compose" })}><PenLine size={18} /></IconBtn>
        </>
      }
    >
      {tag == null && (
        <Segmented
          value={mode ?? "pulse"}
          onChange={setMode}
          options={[
            { id: "pulse", label: "Pulse", icon: <Radio size={16} />, badge: fresh.length || undefined },
            { id: "crew", label: "Crew", icon: <Users size={16} /> },
            { id: "hot", label: "Hot", icon: <Flame size={16} /> },
          ]}
        />
      )}
      <div className="sfeed__pane" key={key}>
        {fresh.length > 0 && (
          <button type="button" className="sfresh" onClick={showFresh}>
            <ArrowUp size={16} strokeWidth={2.6} />
            <span className="sfresh__avs">
              {fresh.slice(0, 3).map((p) => <Avatar key={p.id} name={p.author.name} seed={p.author.seed} size={24} />)}
            </span>
            <span className="label">{fresh.length} new scream{fresh.length > 1 ? "s" : ""}</span>
          </button>
        )}
        {!feed || feed.loading ? (
          <Loader text="Tuning in" />
        ) : (
          <ScreamList
            ref={scroller}
            posts={feed.posts}
            hasMore={feed.hasMore}
            loadingMore={feed.loadingMore}
            onMore={() => void loadFeed(key, true)}
            empty={
              meta ? (
                <Empty
                  icon={<Megaphone size={30} />}
                  title={meta.empty[0]}
                  body={meta.empty[1]}
                  action={<Btn tone="sel" small icon={<PenLine size={16} />} onClick={() => navigate({ app: "social", screen: "compose" })}>Scream</Btn>}
                />
              ) : <Empty icon={<Hash size={30} />} title="No screams" body={`Nothing tagged #${tag} yet.`} />
            }
          />
        )}
      </div>
    </Window>
  );
}
