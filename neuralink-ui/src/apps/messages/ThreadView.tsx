/* One conversation: bubbles (mine right / accent, theirs left / glass), group
   sender names, centred system lines, grouped timestamps, infinite scroll up,
   composer with counter (Enter sends, Shift+Enter newline). */
import { Fragment, useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { AlertTriangle, Info, MessageSquare, Phone, RotateCw, SendHorizontal, UserPlus, Users } from "lucide-react";
import { EMPTY, useStore, type PendingMessage } from "@/store/store";
import { MAX_BODY, type Message } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Empty, IconBtn, Loader } from "@/components/ui";
import { dial, groupCall, loadOlder, loadThread, navigate, retryPending, sendMessage } from "@/store/actions";
import { dayLabel, hhmm, startOfDay } from "@/lib/format";
import { threadPeer } from "./ThreadList";

const GAP_MS = 10 * 60_000;

type Item =
  | { kind: "day"; key: string; label: string }
  | { kind: "time"; key: string; label: string }
  | { kind: "system"; key: string; m: Message }
  | { kind: "msg"; key: string; m: Message; first: boolean; last: boolean; showName: boolean }
  | { kind: "pending"; key: string; p: PendingMessage };

function buildItems(messages: Message[], pending: PendingMessage[], group: boolean): Item[] {
  const out: Item[] = [];
  let prev: Message | null = null;
  messages.forEach((m, i) => {
    const next = messages[i + 1];
    if (!prev || startOfDay(prev.at) !== startOfDay(m.at)) out.push({ kind: "day", key: `d${m.id}`, label: dayLabel(m.at) });
    else if (m.at - prev.at > GAP_MS) out.push({ kind: "time", key: `t${m.id}`, label: hhmm(m.at) });
    if (m.kind === "system") {
      out.push({ kind: "system", key: `s${m.id}`, m });
    } else {
      const sameAsPrev = !!prev && prev.kind === "text" && prev.sender.number === m.sender.number && m.at - prev.at <= GAP_MS && startOfDay(prev.at) === startOfDay(m.at);
      const sameAsNext = !!next && next.kind === "text" && next.sender.number === m.sender.number && next.at - m.at <= GAP_MS && startOfDay(next.at) === startOfDay(m.at);
      out.push({ kind: "msg", key: `m${m.id}`, m, first: !sameAsPrev, last: !sameAsNext, showName: group && !m.mine && !sameAsPrev });
    }
    prev = m;
  });
  for (const p of pending) out.push({ kind: "pending", key: `p${p.tempId}`, p });
  return out;
}

export function ThreadView({ threadId, canBack }: { threadId: number; canBack: boolean }) {
  const summary = useStore((s) => s.state?.threads.find((t) => t.id === threadId) ?? null);
  const cache = useStore((s) => s.threadCache[threadId]);
  const allPending = useStore((s) => s.pending);
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const inCall = useStore((s) => !!s.state?.call);
  const pending = useMemo(() => allPending.filter((p) => p.threadId === threadId && !(cache?.messages.some((m) => m.id === p.serverId) ?? false)), [allPending, threadId, cache]);
  const scroller = useRef<HTMLDivElement>(null);
  const before = useRef<{ h: number; t: number } | null>(null);
  const seen = useRef<Set<number> | null>(null);
  const [atBottom, setAtBottom] = useState(true);

  useEffect(() => {
    if (!useStore.getState().threadCache[threadId]) loadThread(threadId);
  }, [threadId]);

  const group = summary?.kind === "group";
  const items = useMemo(() => buildItems(cache?.messages ?? [], pending, group), [cache?.messages, pending, group]);

  // Scroll: bottom on first load, keep position on prepend, follow on append when near the bottom.
  useLayoutEffect(() => {
    const el = scroller.current;
    if (!el || !cache) return;
    if (cache.lastOp === "prepend" && before.current) {
      el.scrollTop = el.scrollHeight - before.current.h + before.current.t;
      before.current = null;
    } else if (cache.lastOp === "load") {
      el.scrollTop = el.scrollHeight;
    }
  }, [cache?.rev]); // eslint-disable-line

  useEffect(() => {
    const el = scroller.current;
    if (!el || !cache || cache.lastOp !== "append") return;
    const last = cache.messages[cache.messages.length - 1];
    if (atBottom || last?.mine) el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [cache?.rev]); // eslint-disable-line

  useEffect(() => {
    const el = scroller.current;
    if (el && pending.length) el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [pending.length]);

  // Track which messages were already on screen, to animate only new arrivals.
  const isNew = (id: number) => seen.current != null && !seen.current.has(id) && cache?.lastOp === "append";
  useEffect(() => {
    if (!cache || cache.loading) return;
    seen.current ??= new Set();
    for (const m of cache.messages) seen.current.add(m.id);
  });

  const onScroll = () => {
    const el = scroller.current;
    if (!el) return;
    const bottom = el.scrollHeight - el.scrollTop - el.clientHeight < 140;
    if (bottom !== atBottom) setAtBottom(bottom);
    if (el.scrollTop < 60 && cache?.hasMore && !cache.loadingMore && !cache.loading) {
      before.current = { h: el.scrollHeight, t: el.scrollTop };
      loadOlder(threadId);
    }
  };

  if (!summary) {
    return (
      <Window icon={<MessageSquare size={22} />} title="Thread" tag="NL//03-MSG" canBack={canBack}>
        <Empty icon={<AlertTriangle size={30} />} title="Thread unavailable" body="You are no longer part of this conversation." />
      </Window>
    );
  }

  const peer = threadPeer(summary);
  const peerContact = peer ? contacts.find((c) => c.number === peer.number) : undefined;
  const online = summary.members.filter((m) => !m.isMe && m.online).length;
  const subtitle = group
    ? `${summary.members.length} members · ${online} online`
    : peer ? `${peer.number}${peer.online ? " · online" : " · offline"}` : "";

  return (
    <Window
      className="win--thread"
      icon={<Avatar name={summary.title} seed={peer?.number ?? `g${summary.id}`} size={40} group={group} online={peer ? peer.online : null} />}
      title={summary.title}
      subtitle={subtitle}
      tag={`THR-${String(summary.id).padStart(4, "0")}`}
      canBack={canBack}
      actions={
        <>
          {peer && !peerContact && (
            <IconBtn label="Save contact" onClick={() => navigate({ app: "contacts", screen: "edit", number: peer.number })}><UserPlus size={18} /></IconBtn>
          )}
          <IconBtn
            label={group ? "Group call" : "Call"}
            tone="ok"
            disabled={inCall}
            onClick={() => { if (group) void groupCall(summary.id); else if (peer) void dial(peer.number); }}
          >
            {group ? <Users size={18} /> : <Phone size={18} />}
          </IconBtn>
          {group && <IconBtn label="Group info" onClick={() => navigate({ app: "messages", screen: "group-info", threadId: summary.id })}><Info size={18} /></IconBtn>}
        </>
      }
      bodyClass="thread"
      footer={<Composer threadId={threadId} />}
    >
      <div className="thread__scroll nl-scroll" ref={scroller} onScroll={onScroll}>
        {!cache || cache.loading ? (
          <Loader text="Decrypting thread" />
        ) : (
          <>
            <div className="thread__head">
              {cache.loadingMore ? <Loader text="Loading older" /> : cache.hasMore ? <span className="thread__more mono">scroll up for older</span> : (
                <span className="thread__start">
                  <Avatar name={summary.title} seed={peer?.number ?? `g${summary.id}`} size={58} group={group} />
                  <span className="label">{group ? "Group created" : "Start of the conversation"}</span>
                  <span className="mono">end-to-end neural encryption</span>
                </span>
              )}
            </div>
            {items.length === 0 && <div className="thread__empty">Say hello.</div>}
            {items.map((it) => {
              switch (it.kind) {
                case "day": return <div key={it.key} className="tdiv"><span className="label">{it.label}</span></div>;
                case "time": return <div key={it.key} className="tdiv tdiv--time"><span className="mono">{it.label}</span></div>;
                case "system": return <div key={it.key} className={`sysmsg ${isNew(it.m.id) ? "is-new" : ""}`}><span>{it.m.body}</span></div>;
                case "msg": return (
                  <Fragment key={it.key}>
                    {it.showName && <div className="bname" style={{ ["--hue" as string]: hue(it.m.sender.number) }}>{it.m.sender.name}</div>}
                    <div className={`bubble-row ${it.m.mine ? "is-mine" : ""} ${it.first ? "is-first" : ""} ${it.last ? "is-last" : ""} ${isNew(it.m.id) ? "is-new" : ""}`}>
                      {group && !it.m.mine && <span className="bubble-row__av">{it.last && <Avatar name={it.m.sender.name} seed={it.m.sender.number} size={30} />}</span>}
                      <div className="bubble">
                        <span className="bubble__text">{it.m.body}</span>
                        <span className="bubble__time mono">{hhmm(it.m.at)}</span>
                      </div>
                    </div>
                  </Fragment>
                );
                case "pending": return (
                  <div key={it.key} className={`bubble-row is-mine is-first is-last is-pending ${it.p.failed ? "is-failed" : ""}`}>
                    <div className="bubble">
                      <span className="bubble__text">{it.p.body}</span>
                      <span className="bubble__time mono">
                        {it.p.failed ? (
                          <button type="button" className="bubble__retry" onClick={() => retryPending(it.p.tempId)}><RotateCw size={12} /> Retry</button>
                        ) : <span className="bubble__dots"><i /><i /><i /></span>}
                      </span>
                    </div>
                  </div>
                );
              }
              return null;
            })}
          </>
        )}
      </div>
      {!atBottom && (
        <button type="button" className="thread__jump" onClick={() => scroller.current?.scrollTo({ top: scroller.current.scrollHeight, behavior: "smooth" })}>
          Latest
        </button>
      )}
    </Window>
  );
}

function hue(key: string): number {
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
  return h % 360;
}

/* ------------------------------------------------------------ composer */

function Composer({ threadId }: { threadId: number }) {
  const [body, setBody] = useState("");
  const ref = useRef<HTMLTextAreaElement>(null);
  const len = body.length;
  const ok = body.trim().length > 0 && len <= MAX_BODY;

  const fit = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(124, el.scrollHeight)}px`;
  }, []);
  useLayoutEffect(fit, [body, fit]);

  const send = () => {
    if (!ok) return;
    const text = body.replace(/\s+$/, "");
    setBody("");
    void sendMessage(threadId, text);
  };

  return (
    <div className="composer">
      <div className="composer__box">
        <textarea
          ref={ref}
          className="composer__input"
          rows={1}
          value={body}
          maxLength={MAX_BODY}
          placeholder="Neural message…"
          spellCheck={false}
          onChange={(e) => setBody(e.target.value.slice(0, MAX_BODY))}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); }
          }}
        />
        <span className={`composer__count mono ${len > MAX_BODY - 50 ? "is-warn" : ""} ${len >= MAX_BODY ? "is-max" : ""}`}>{len}/{MAX_BODY}</span>
      </div>
      <button type="button" className={`composer__send ${ok ? "is-ready" : ""}`} disabled={!ok} onClick={send} aria-label="Send">
        <SendHorizontal size={22} strokeWidth={2.2} />
      </button>
    </div>
  );
}
