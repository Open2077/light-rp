/* One scream in context: the chain it answers (dim, joined by a holo line),
   the scream itself, a reply composer, then its replies. */
import { useEffect, useLayoutEffect, useRef } from "react";
import { AlertTriangle, MessageCircle, Radio } from "lucide-react";
import { useStore } from "@/store/store";
import { Window } from "@/components/Window";
import { Empty, Loader, SectionTitle } from "@/components/ui";
import { loadScreamThread } from "@/store/actions";
import { ScreamCard, countLabel } from "./ScreamCard";
import { ScreamComposer } from "./Compose";

export function ScreamThread({ postId, canBack }: { postId: number; canBack: boolean }) {
  const t = useStore((s) => s.screamThreads[postId]);
  const gone = useStore((s) => !!s.postGone[postId]);
  const replies = useStore((s) => s.postLive[postId]?.replies ?? s.screamThreads[postId]?.post?.replies ?? 0);
  const scroller = useRef<HTMLDivElement>(null);
  const focusRef = useRef<HTMLDivElement>(null);
  const placed = useRef(false);

  useEffect(() => { void loadScreamThread(postId); }, [postId]);

  // Land on the focused scream with a hint of the chain above it.
  useLayoutEffect(() => {
    if (placed.current || !t?.post || !scroller.current || !focusRef.current) return;
    placed.current = true;
    if (t.parents.length) scroller.current.scrollTop = Math.max(0, focusRef.current.offsetTop - 70);
  }, [t?.post, t?.parents.length]);

  const post = t?.post;
  const onSent = () => requestAnimationFrame(() => scroller.current?.scrollTo({ top: scroller.current.scrollHeight, behavior: "smooth" }));

  return (
    <Window
      icon={<Radio size={22} />}
      title="Scream"
      subtitle={post ? `@${post.author.handle} · ${countLabel(replies)} ${replies === 1 ? "reply" : "replies"}` : "Screamsheet"}
      tag={`SCR-${String(postId).padStart(5, "0")}`}
      canBack={canBack}
      bodyClass="sthread"
    >
      {gone || t?.missing ? (
        <Empty icon={<AlertTriangle size={30} />} title="Scream gone" body="It was deleted, or it never hit the sheet." />
      ) : !post ? (
        <Loader text="Tracing the thread" />
      ) : (
        <div className="sthread__scroll nl-scroll" ref={scroller}>
          {t.parents.length > 0 && (
            <div className="sthread__parents">
              {t.parents.map((p, i) => <ScreamCard key={p.id} post={p} index={i} variant="parent" rail />)}
            </div>
          )}
          <div ref={focusRef} className="sthread__focus">
            <ScreamCard post={post} variant="focus" />
          </div>
          <div className="sthread__reply">
            <ScreamComposer replyTo={post.id} compact onSent={onSent} />
          </div>
          <SectionTitle>Replies · {t.replies.length}</SectionTitle>
          {t.replies.length === 0 ? (
            <div className="sthread__none"><MessageCircle size={18} /> No replies yet. Start the noise.</div>
          ) : t.replies.map((r, i) => <ScreamCard key={r.id} post={r} index={i} variant="reply" />)}
        </div>
      )}
    </Window>
  );
}
