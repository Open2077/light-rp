/* The scream composer (character ring, district line, Ctrl+Enter sends) and
   the Compose window around it, with the reply / quote context on top. */
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { MapPin, Megaphone, MessageCircle, PenLine, Quote } from "lucide-react";
import { getStore, useStore } from "@/store/store";
import { SCREAM_MAX, type SocialPost } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Btn, Loader } from "@/components/ui";
import { act, scream } from "@/store/actions";
import { ScreamEmbed } from "./ScreamCard";

const WARN_AT = 260;

function CharRing({ len }: { len: number }) {
  const r = 13;
  const c = 2 * Math.PI * r;
  const pct = Math.min(1, len / SCREAM_MAX);
  const state = len > SCREAM_MAX ? "is-over" : len >= WARN_AT ? "is-warn" : "";
  return (
    <span className={`cring ${state}`} title={`${len}/${SCREAM_MAX}`}>
      <svg viewBox="0 0 34 34" aria-hidden>
        <circle className="cring__track" cx="17" cy="17" r={r} />
        <circle className="cring__fill" cx="17" cy="17" r={r} style={{ strokeDasharray: c, strokeDashoffset: c * (1 - pct) }} />
      </svg>
      {len >= WARN_AT && <span className="cring__left mono">{SCREAM_MAX - len}</span>}
    </span>
  );
}

export function ScreamComposer({ replyTo, quoteOf, autoFocus, compact, onSent }: {
  replyTo?: number; quoteOf?: number; autoFocus?: boolean; compact?: boolean; onSent?: (p: SocialPost) => void;
}) {
  const district = useStore((s) => s.clock?.district);
  const name = useStore((s) => s.state?.line?.name ?? "Me");
  const seed = useStore((s) => { const h = s.state?.social?.handle; return (h && s.profiles[h]?.seed) || s.state?.line?.number || h || "me"; });
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const ref = useRef<HTMLTextAreaElement>(null);
  const len = body.length;
  const ok = body.trim().length > 0 && len <= SCREAM_MAX && !busy;

  const fit = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(compact ? 120 : 220, Math.max(compact ? 44 : 120, el.scrollHeight))}px`;
  }, [compact]);
  useLayoutEffect(fit, [body, fit]);
  useEffect(() => { if (autoFocus) ref.current?.focus(); }, [autoFocus]);

  const send = async () => {
    if (!ok) return;
    setBusy(true);
    const post = await scream(body.trim(), { replyTo, quoteOf });
    setBusy(false);
    if (!post) return;
    setBody("");
    onSent?.(post);
  };

  return (
    <div className={`scomp ${compact ? "scomp--compact" : ""}`}>
      <div className="scomp__row">
        <Avatar name={name} seed={seed} size={compact ? 38 : 46} />
        <div className="scomp__box">
          <textarea
            ref={ref}
            className="scomp__input"
            rows={compact ? 1 : 4}
            value={body}
            placeholder={replyTo != null ? "Scream your reply…" : quoteOf != null ? "Add your take…" : "What's happening in Night City?"}
            spellCheck={false}
            onChange={(e) => setBody(e.target.value.slice(0, SCREAM_MAX + 120))}
            onKeyDown={(e) => {
              if (e.key === "Enter" && (e.ctrlKey || e.metaKey) && !e.nativeEvent.isComposing) { e.preventDefault(); void send(); }
            }}
          />
        </div>
      </div>
      <div className="scomp__bar">
        <span className={`scomp__from ${district ? "" : "is-unknown"}`}>
          <MapPin size={14} strokeWidth={2.4} />
          {district ? <>Screaming from <b>{district}</b></> : "Location unknown"}
        </span>
        <span className="scomp__hint mono">ctrl+enter</span>
        <CharRing len={len} />
        <Btn tone="sel" small={compact} icon={<Megaphone size={16} />} disabled={!ok} onClick={() => void send()}>
          {busy ? "Sending…" : replyTo != null ? "Reply" : "Scream"}
        </Btn>
      </div>
    </div>
  );
}

/* --------------------------------------------------------------- window */

function useContextPost(id: number | undefined): SocialPost | null | undefined {
  const cached = useStore((s) => (id != null ? s.composeCtx[id] ?? s.screamThreads[id]?.post ?? null : null));
  const [missing, setMissing] = useState(false);
  useEffect(() => {
    if (id == null || getStore().composeCtx[id] || getStore().screamThreads[id]?.post) return;
    void act("social.thread", { postId: id }, { quiet: true }).then((r) => {
      if (r?.post) getStore().rememberPost(r.post);
      else setMissing(true);
    });
  }, [id]);
  if (id == null) return undefined;
  return cached ?? (missing ? null : undefined);
}

export function ComposeView({ replyTo, quoteOf, canBack }: { replyTo?: number; quoteOf?: number; canBack: boolean }) {
  const ctxId = replyTo ?? quoteOf;
  const ctx = useContextPost(ctxId);
  const kind = replyTo != null ? "reply" : quoteOf != null ? "quote" : "new";

  const done = () => {
    const st = getStore();
    if (st.stack.length > 1) st.back();
    else st.resetView({ app: "social", screen: "feed", mode: "pulse" });
  };

  return (
    <Window
      icon={kind === "reply" ? <MessageCircle size={22} /> : kind === "quote" ? <Quote size={22} /> : <PenLine size={22} />}
      title={kind === "reply" ? "Reply" : kind === "quote" ? "Quote" : "Compose"}
      subtitle={ctx ? `${kind === "reply" ? "Replying to" : "Quoting"} @${ctx.author.handle}` : `Up to ${SCREAM_MAX} characters, #tags and @handles`}
      tag="NL//06-NEW"
      canBack={canBack}
      bodyClass="scompose"
    >
      {ctxId != null && (
        <div className="scompose__ctx">
          <span className="scompose__ctxlabel label">{kind === "reply" ? "Replying to" : "Quoting"}</span>
          {ctx ? <ScreamEmbed post={ctx} static /> : ctx === null ? <div className="sembed sembed--gone">This scream was deleted.</div> : <Loader text="Fetching scream" />}
        </div>
      )}
      <ScreamComposer replyTo={replyTo} quoteOf={quoteOf} autoFocus onSent={done} />
    </Window>
  );
}
