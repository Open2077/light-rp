/* A scrolling column of scream cards with infinite "load more" at the bottom
   and Up / Down / Enter keyboard navigation. */
import { forwardRef, useMemo, useState, type ReactNode, type UIEvent } from "react";
import type { SocialPost } from "@/bridge/protocol";
import { Loader } from "@/components/ui";
import { openScream } from "@/store/actions";
import { listKeys, useWindowKeys } from "@/shell/keys";
import { ScreamCard } from "./ScreamCard";

interface Props {
  posts: SocialPost[];
  hasMore: boolean;
  loadingMore: boolean;
  onMore: () => void;
  head?: ReactNode;
  empty?: ReactNode;
  className?: string;
}

/** The scream a card opens: the original for a plain echo. */
export const openTarget = (p: SocialPost) => (!p.body && p.echoOf ? p.echoOf.id : p.id);

export const ScreamList = forwardRef<HTMLDivElement, Props>(function ScreamList({ posts, hasMore, loadingMore, onMore, head, empty, className }, ref) {
  const [kbd, setKbd] = useState(-1);
  useWindowKeys(useMemo(() => listKeys(posts.length, kbd, setKbd, (i) => { const p = posts[i]; if (p) openScream(openTarget(p)); }), [posts, kbd]));

  const onScroll = (e: UIEvent<HTMLDivElement>) => {
    const el = e.currentTarget;
    if (hasMore && !loadingMore && el.scrollHeight - el.scrollTop - el.clientHeight < 260) onMore();
  };

  return (
    <div className={["screams nl-scroll", className].filter(Boolean).join(" ")} ref={ref} onScroll={onScroll}>
      {head}
      {posts.length === 0 && !hasMore ? empty : posts.map((p, i) => <ScreamCard key={p.id} post={p} index={i} kbd={kbd === i} />)}
      {loadingMore ? <Loader text="Pulling older screams" /> : hasMore ? (
        <button type="button" className="screams__more label" onClick={onMore}>Load more</button>
      ) : posts.length > 0 ? <div className="screams__end mono">// end of the sheet</div> : null}
    </div>
  );
});
