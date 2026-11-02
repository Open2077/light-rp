/* Lua -> page events into the store, with the sounds that go with them. */
import { useEffect } from "react";
import { announceReady, on } from "@/bridge/open77";
import type { CallState, SocialLive } from "@/bridge/protocol";
import { play } from "@/fx/sound";
import { blurField } from "@/shell/keys";
import { getStore, implantLocked, selectSettings, topView, type View } from "./store";
import { act, loadPings, loadScreamThread, loadThread } from "./actions";

function viewedThreadId(): number | null {
  const st = getStore();
  if (st.phase === "closed" || st.phase === "closing" || st.callView) return null;
  const v = topView(st);
  return v && v.app === "messages" && v.screen === "thread" ? v.threadId : null;
}

/** The Screamsheet window on screen, if any. */
function viewedSocial(): View | null {
  const st = getStore();
  if (st.phase === "closed" || st.phase === "closing" || st.callView) return null;
  const v = topView(st);
  return v && v.app === "social" ? v : null;
}

function socialEvent(e: SocialLive): void {
  const st = getStore();
  const v = viewedSocial();
  switch (e.kind) {
    case "post":
      // My own screams came back with the social.post reply already.
      if (e.post && !e.post.mine) st.pushFresh(e.post);
      break;
    case "ping":
      st.setSocialUnread(e.unread);
      if (v?.app === "social" && v.screen === "pings") void loadPings();
      break;
    case "stats": {
      const before = st.postLive[e.postId]?.replies ?? st.screamThreads[e.postId]?.post?.replies ?? 0;
      st.setPostLive(e.postId, { cred: e.cred, echoes: e.echoes, replies: e.replies });
      if (v?.app === "social" && v.screen === "thread" && v.postId === e.postId && e.replies > before) void loadScreamThread(e.postId);
      break;
    }
    case "deleted":
      st.removePost(e.postId);
      break;
  }
}

function callSounds(prev: CallState | null | undefined, next: CallState | null): void {
  if (!next) return;
  const prevConnected = prev ? prev.participants.filter((p) => !p.isMe && p.state === "connected").length : 0;
  const connected = next.participants.filter((p) => !p.isMe && p.state === "connected").length;
  if (next.phase === "active" && (!prev || prev.phase !== "active" || prev.id !== next.id)) play("connect");
  else if (next.phase === "active" && prev?.phase === "active" && connected > prevConnected) play("receive");
}

export function useBridgeEvents(): void {
  useEffect(() => {
    const offs = [
      on("nl:state", (s) => {
        if (!s) return;
        const st = getStore();
        const prevCall = st.state?.call;
        st.applyState(s);
        getStore().setCall(s.call ?? null);
        callSounds(prevCall, s.call ?? null);
        // Re-fetch an open thread: the snapshot dropped every cache.
        const tid = viewedThreadId();
        if (tid != null) loadThread(tid);
      }),
      on("nl:patch", (p) => {
        if (!p) return;
        const prevCall = getStore().state?.call;
        getStore().applyPatch(p);
        if ("call" in p) { getStore().setCall(p.call ?? null); callSounds(prevCall, p.call ?? null); }
      }),
      on("nl:open", (p) => {
        getStore().openUi(p ?? {});
        // without an implant the server refuses everything but implant.install
        if (p?.app === "messages" && typeof p.threadId === "number" && !implantLocked(getStore())) loadThread(p.threadId);
      }),
      on("nl:close", () => {
        const st = getStore();
        if (st.phase === "closed" || st.phase === "closing") return;
        blurField();
        play("close");
        st.closeUi();
      }),
      on("nl:thread", (p) => { if (p && typeof p.threadId === "number") getStore().threadLoaded(p); }),
      on("nl:message", (p) => {
        if (!p?.message) return;
        getStore().messageArrived(p);
        if (p.message.mine || p.message.kind === "system") return;
        if (viewedThreadId() === p.message.threadId) {
          getStore().setUnread(p.message.threadId, 0);
          void act("threads.read", { threadId: p.message.threadId }, { quiet: true });
          play("receive");
        }
      }),
      on("nl:messageUpdate", (p) => { if (p?.message && typeof p.message.id === "number") getStore().messageUpdated(p.message); }),
      on("nl:call", (c) => {
        const prev = getStore().state?.call;
        getStore().setCall(c ?? null);
        callSounds(prev, c ?? null);
      }),
      on("nl:callEnded", (e) => {
        if (!e) return;
        getStore().setEnded(e);
        play("disconnect");
      }),
      on("nl:talkers", (t) => getStore().setTalkers(t ?? {})),
      on("nl:toast", (t) => {
        if (!t) return;
        const st = getStore();
        if (implantLocked(st)) return;
        // No toast for the thread already on screen.
        if (t.kind === "message" && t.threadId != null && viewedThreadId() === t.threadId) return;
        st.pushToast({ ...t, at: t.at ?? Date.now() });
        const dnd = selectSettings(st).dnd;
        if (dnd) return;
        if (t.kind === "message") play("chime");
        else if (t.kind === "error") play("error");
        else play("toast");
      }),
      on("nl:clock", (c) => { if (c) getStore().setClock(c); }),
      on("nl:social", (e) => { if (e && typeof e.kind === "string") socialEvent(e); }),
      on("nl:keys", (k) => { if (k && typeof k.toggle === "string" && k.toggle) getStore().setToggleKey(k.toggle); }),
      on("nl:focus", (f) => {
        const keyboard = !!f?.keyboard;
        getStore().setKeyboard(keyboard);
        if (!keyboard) blurField();
      }),
    ];
    announceReady();
    return () => offs.forEach((off) => off());
  }, []);
}
