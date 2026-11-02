/* Single zustand store: the last Lua snapshot plus the page's own navigation
   (SAO column -> sub-panel -> window stack), thread and Screamsheet caches,
   call overlays and toasts. Side effects (bridge requests) live in store/actions.ts. */
import { create } from "zustand";
import { useShallow } from "zustand/react/shallow";
import type {
  CallEndedPayload, CallState, ClockPayload, ImplantState, Member, Message, MessagePayload, OpenPayload, Settings, SocialFeedMode,
  SocialPing, SocialPost, SocialProfile, State, TalkersPayload, ThreadPayload, ThreadSummary, ToastPayload,
} from "@/bridge/protocol";
import { DEFAULT_SETTINGS } from "@/bridge/protocol";
import { startOfDay } from "@/lib/format";

export type CoreMenuId = "status" | "phone" | "messages" | "contacts" | "social" | "settings";
export type MenuId = CoreMenuId | `app:${string}`;

export type PhoneTab = "dial" | "recents" | "favorites";
export type SettingsSection = "sound" | "display" | "about";

export type View =
  | { app: "status" }
  | { app: "phone"; tab: PhoneTab }
  | { app: "messages"; screen: "list" }
  | { app: "messages"; screen: "thread"; threadId: number }
  | { app: "messages"; screen: "new" }
  | { app: "messages"; screen: "group-new" }
  | { app: "messages"; screen: "group-info"; threadId: number }
  | { app: "contacts"; screen: "list"; filter: "all" | "favorites" }
  | { app: "contacts"; screen: "edit"; id?: number; number?: string }
  | { app: "settings"; section: SettingsSection }
  | { app: "social"; screen: "feed"; mode: SocialFeedMode }
  | { app: "social"; screen: "tag"; tag: string }
  | { app: "social"; screen: "thread"; postId: number }
  | { app: "social"; screen: "compose"; replyTo?: number; quoteOf?: number }
  | { app: "social"; screen: "profile"; handle: string }
  | { app: "social"; screen: "edit" }
  | { app: "social"; screen: "pings" }
  | { app: "social"; screen: "heat"; search?: boolean };

export interface ThreadCache {
  messages: Message[];
  members: Member[];
  hasMore: boolean;
  loading: boolean;
  loadingMore: boolean;
  /** Bumped on every server page so views can tell a prepend from an append. */
  rev: number;
  lastOp: "load" | "prepend" | "append" | "update";
}

/** A paged list of screams: a feed ("pulse", "crew", "hot", "#tag") or a profile's ("@handle"). */
export interface FeedCache { posts: SocialPost[]; hasMore: boolean; loading: boolean; loadingMore: boolean; rev: number }
export interface ScreamThreadCache { post: SocialPost | null; parents: SocialPost[]; replies: SocialPost[]; loading: boolean; missing: boolean }
export interface PingsCache { pings: SocialPing[]; hasMore: boolean; loading: boolean; loadingMore: boolean }
/** Latest known counters and my toggles per scream id, laid over every cached copy. */
export type PostLive = Partial<Pick<SocialPost, "cred" | "echoes" | "replies" | "credded" | "echoed">>;

export interface PendingMessage { tempId: number; threadId: number; body: string; at: number; failed: boolean; serverId?: number }

export interface ToastItem extends ToastPayload { key: number; born: number }

export interface EndedCard extends CallEndedPayload { key: number }

export type Phase = "closed" | "opening" | "open" | "closing";

interface Store {
  state: State | null;
  phase: Phase;
  openSeq: number;
  /** The implant installation runs (or shows its error): keeps the takeover up
      after the server's fresh state already says installed. */
  implantFlow: boolean;
  /** nl:open asked to start the installation directly (consumed by ImplantGate). */
  implantAutoStart: boolean;

  menu: MenuId | null;
  cursor: number;
  row: number;
  stack: View[];
  callView: boolean;
  navDir: "fwd" | "back";
  dial: string;

  threadCache: Record<number, ThreadCache>;
  pending: PendingMessage[];
  talkers: TalkersPayload;
  toasts: ToastItem[];
  clock: ClockPayload | null;
  toggleKey: string;
  ended: EndedCard | null;
  keyboard: boolean;
  settingsDraft: Partial<Settings>;
  seenToday: Record<number, 1>;
  dayStart: number;
  recentsSeenAt: number;

  feeds: Record<string, FeedCache>;
  screamThreads: Record<number, ScreamThreadCache>;
  profiles: Record<string, SocialProfile>;
  pings: PingsCache | null;
  postLive: Record<number, PostLive>;
  postGone: Record<number, 1>;
  /** Live screams from others, waiting behind the "new screams" pill of Pulse. */
  freshPosts: SocialPost[];
  /** Screams handed to the composer (reply / quote context). */
  composeCtx: Record<number, SocialPost>;

  applyState(s: State): void;
  applyPatch(p: Partial<State>): void;
  openUi(p: OpenPayload): void;
  setPhase(p: Phase): void;
  closeUi(): void;
  setImplantFlow(on: boolean): void;
  /** The installation finished: take the reply's implant and replay the opening. */
  implantOnline(implant: ImplantState | null): void;

  setMenu(id: MenuId | null): void;
  setCursor(i: number): void;
  setRow(i: number): void;
  resetView(v: View | null): void;
  pushView(v: View): void;
  replaceTop(v: View): void;
  back(): boolean;
  setCallView(v: boolean): void;
  setDial(n: string): void;

  threadLoading(threadId: number, more: boolean): void;
  threadLoaded(p: ThreadPayload): void;
  messageArrived(p: MessagePayload): void;
  messageUpdated(message: Message): void;
  setUnread(threadId: number, unread: number): void;
  addPending(p: PendingMessage): void;
  pendingSent(tempId: number, serverId: number): void;
  pendingFailed(tempId: number): void;
  dropPending(tempId: number): void;

  setCall(c: CallState | null): void;
  setTalkers(t: TalkersPayload): void;
  pushToast(t: ToastPayload): void;
  dismissToast(key: number): void;
  setClock(c: ClockPayload): void;
  setToggleKey(k: string): void;
  setEnded(e: CallEndedPayload | null): void;
  setKeyboard(k: boolean): void;
  setSettingsDraft(d: Partial<Settings>): void;
  replaceSettingsDraft(d: Partial<Settings>): void;
  markRecentsSeen(): void;

  setSocialUnread(unread: number): void;
  setSocialHandle(handle: string): void;
  feedLoading(key: string, more: boolean): void;
  feedLoaded(key: string, posts: SocialPost[], hasMore: boolean, more: boolean): void;
  feedFailed(key: string): void;
  prependPosts(key: string, posts: SocialPost[]): void;
  screamThreadLoading(postId: number): void;
  screamThreadLoaded(postId: number, t: Pick<ScreamThreadCache, "post" | "parents" | "replies"> | null): void;
  addReply(parentId: number, post: SocialPost): void;
  setProfile(p: SocialProfile): void;
  pingsLoading(more: boolean): void;
  pingsLoaded(pings: SocialPing[], hasMore: boolean, more: boolean): void;
  pingsSeen(): void;
  setPostLive(id: number, live: PostLive): void;
  removePost(id: number): void;
  pushFresh(p: SocialPost): void;
  takeFresh(): SocialPost[];
  rememberPost(p: SocialPost): void;
}

let toastKey = 1;
const SEEN_KEY = "nl.recentsSeenAt";
function readSeen(): number {
  try { const v = Number(localStorage.getItem(SEEN_KEY)); if (Number.isFinite(v) && v > 0) return v; } catch { /* storage may be off */ }
  return Date.now() - 86_400_000;
}
let endedKey = 1;

const menuForView = (v: View): MenuId => v.app;

function upsertSummary(list: ThreadSummary[], s: ThreadSummary): ThreadSummary[] {
  const rest = list.filter((t) => t.id !== s.id);
  return [s, ...rest].sort((a, b) => b.updatedAt - a.updatedAt);
}

const EMPTY_FEED: FeedCache = { posts: [], hasMore: false, loading: false, loadingMore: false, rev: 0 };

/** Live entries already held for these screams take the server's fresher numbers. */
function syncLive(live: Record<number, PostLive>, posts: SocialPost[]): Record<number, PostLive> {
  let next: Record<number, PostLive> | null = null;
  const visit = (p: SocialPost | null) => {
    if (!p) return;
    if (live[p.id]) {
      next ??= { ...live };
      next[p.id] = { cred: p.cred, echoes: p.echoes, replies: p.replies, credded: p.credded, echoed: p.echoed };
    }
    visit(p.echoOf);
  };
  posts.forEach(visit);
  return next ?? live;
}

/** Drop a deleted scream and the plain echoes of it; quotes keep a "deleted" embed. */
function withoutPost(list: SocialPost[], id: number): SocialPost[] {
  if (!list.some((p) => p.id === id || p.echoOf?.id === id)) return list;
  return list
    .filter((p) => p.id !== id && !(p.echoOf?.id === id && !p.body))
    .map((p) => (p.echoOf?.id === id ? { ...p, echoOf: null, echoGone: true } : p));
}

function countToday(seen: Record<number, 1>, msgs: Message[], dayStart: number): Record<number, 1> {
  let next: Record<number, 1> | null = null;
  for (const m of msgs) {
    if (m.kind !== "text" || m.at < dayStart || seen[m.id]) continue;
    next ??= { ...seen };
    next[m.id] = 1;
  }
  return next ?? seen;
}

export const useStore = create<Store>()((set, get) => ({
  state: null,
  phase: "closed",
  openSeq: 0,
  implantFlow: false,
  implantAutoStart: false,
  menu: null,
  cursor: 0,
  row: 0,
  stack: [],
  callView: false,
  navDir: "fwd",
  dial: "",
  threadCache: {},
  pending: [],
  talkers: {},
  toasts: [],
  clock: null,
  toggleKey: "F2",
  ended: null,
  keyboard: false,
  settingsDraft: {},
  seenToday: {},
  dayStart: startOfDay(Date.now()),
  recentsSeenAt: readSeen(),
  feeds: {},
  screamThreads: {},
  profiles: {},
  pings: null,
  postLive: {},
  postGone: {},
  freshPosts: [],
  composeCtx: {},

  applyState(s) {
    const prev = get().state;
    const lineChanged = prev?.line?.number !== s.line?.number;
    // Installed from outside (a ripperdoc) while "no Neural-Link" is on screen: open properly.
    const ph = get().phase;
    const linked = prev?.implant?.installed === false && s.implant?.installed !== false && !get().implantFlow && (ph === "open" || ph === "opening");
    const threadIds = new Set((s.threads ?? []).map((t) => t.id));
    set((st) => ({
      state: { ...s, settings: { ...DEFAULT_SETTINGS, ...(s.settings ?? {}) }, contacts: s.contacts ?? [], threads: s.threads ?? [], recents: s.recents ?? [], apps: s.apps ?? [], social: s.social ?? null },
      threadCache: {},
      ...(lineChanged ? { feeds: {}, screamThreads: {}, profiles: {}, pings: null, postLive: {}, postGone: {}, freshPosts: [], composeCtx: {} } : {}),
      pending: [],
      settingsDraft: {},
      seenToday: lineChanged ? {} : st.seenToday,
      // A view on a thread that no longer exists falls back to the list.
      stack: lineChanged ? [] : st.stack.filter((v) => !("threadId" in v) || threadIds.has(v.threadId)),
      menu: lineChanged ? null : st.menu,
      callView: !!s.call && (s.call.phase === "incoming" || st.callView),
      ...(linked ? { phase: "opening" as Phase, openSeq: st.openSeq + 1 } : {}),
    }));
  },

  applyPatch(p) {
    const cur = get().state;
    if (!cur) return;
    const next: State = { ...cur };
    (Object.keys(p) as (keyof State)[]).forEach((k) => {
      if (p[k] !== undefined) (next as unknown as Record<string, unknown>)[k] = p[k];
    });
    if (p.settings) next.settings = { ...DEFAULT_SETTINGS, ...p.settings };
    const threadIds = new Set(next.threads.map((t) => t.id));
    set((st) => ({
      state: next,
      settingsDraft: p.settings ? {} : st.settingsDraft,
      stack: p.threads ? st.stack.filter((v) => !("threadId" in v) || threadIds.has(v.threadId)) : st.stack,
    }));
  },

  openUi(p) {
    const st = get();
    const reopening = st.phase === "closed" || st.phase === "closing";
    const patch: Partial<Store> = {};
    if (reopening) { patch.phase = "opening"; patch.openSeq = st.openSeq + 1; patch.implantFlow = false; }
    patch.implantAutoStart = p?.install === true;
    const app = p?.app;
    if (app && app !== "home") {
      let stack: View[] = [];
      let menu: MenuId | null = null;
      if (app === "messages") {
        menu = "messages";
        stack = [{ app: "messages", screen: "list" }];
        if (typeof p.threadId === "number") stack.push({ app: "messages", screen: "thread", threadId: p.threadId });
      } else if (app === "phone") {
        menu = "phone";
        stack = [{ app: "phone", tab: p.number ? "dial" : "recents" }];
        if (p.number) patch.dial = p.number;
      } else if (app === "contacts") {
        menu = "contacts";
        stack = [{ app: "contacts", screen: "list", filter: "all" }];
        if (p.number) stack.push({ app: "contacts", screen: "edit", number: p.number });
      } else if (app === "social") {
        menu = "social"; stack = [{ app: "social", screen: "feed", mode: "pulse" }];
        if (p.screen === "thread" && typeof p.postId === "number") stack.push({ app: "social", screen: "thread", postId: p.postId });
        else if (p.screen === "profile" && p.handle) stack.push({ app: "social", screen: "profile", handle: p.handle });
        else if (p.screen === "tag" && p.tag) stack.push({ app: "social", screen: "tag", tag: p.tag });
        else if (p.screen === "compose") stack.push({ app: "social", screen: "compose" });
        else if (p.screen === "pings") stack.push({ app: "social", screen: "pings" });
        else if (p.screen === "heat") stack.push({ app: "social", screen: "heat" });
        else if (p.screen === "edit") stack.push({ app: "social", screen: "edit" });
      } else if (app === "settings") {
        menu = "settings"; stack = [{ app: "settings", section: "sound" }];
      } else if (app === "status") {
        menu = "status"; stack = [{ app: "status" }];
      } else {
        menu = `app:${app}`;
      }
      Object.assign(patch, { menu, stack, callView: false, row: 0 });
    } else if (app === "home") {
      Object.assign(patch, { menu: null, stack: [], callView: false });
    } else if (reopening) {
      // A plain open lands on the column with the last call surfaced if any.
      const c = st.state?.call;
      patch.callView = !!c;
    }
    set(patch);
  },

  setPhase(phase) { set(phase === "closed" ? { phase, implantFlow: false } : { phase }); },
  closeUi() {
    const ph = get().phase;
    if (ph === "closed" || ph === "closing") return;
    set({ phase: "closing" });
  },
  setImplantFlow(implantFlow) { set({ implantFlow }); },
  implantOnline(implant) {
    const st = get();
    if (st.phase === "closed" || st.phase === "closing") return;
    // the reply proves the install even if the fresh nl:state is still on its way
    const state = st.state ? { ...st.state, implant: implant ?? { ...st.state.implant, installed: true, installedAt: Date.now() } } : st.state;
    set({ state, implantFlow: false, phase: "opening", openSeq: st.openSeq + 1, menu: null, stack: [], callView: false });
  },

  setMenu(menu) { set({ menu, row: 0, stack: [], callView: false }); },
  setCursor(cursor) { set({ cursor }); },
  setRow(row) { set({ row }); },
  resetView(v) { set(v ? { stack: [v], menu: menuForView(v), callView: false, navDir: "fwd" } : { stack: [], navDir: "back" }); },
  pushView(v) { set((st) => ({ stack: [...st.stack, v], menu: menuForView(v), callView: false, navDir: "fwd" })); },
  replaceTop(v) { set((st) => ({ stack: [...st.stack.slice(0, -1), v] })); },
  back() {
    const st = get();
    const c = st.state?.call;
    if (st.callView && c && c.phase !== "incoming") { set({ callView: false }); return true; }
    if (st.stack.length > 1) { set({ stack: st.stack.slice(0, -1), navDir: "back" }); return true; }
    if (st.stack.length === 1) { set({ stack: [] }); return true; }
    if (st.menu) { set({ menu: null }); return true; }
    return false;
  },
  setCallView(callView) { set({ callView }); },
  setDial(dial) { set({ dial }); },

  threadLoading(threadId, more) {
    set((st) => {
      const cur = st.threadCache[threadId];
      const base: ThreadCache = cur ?? { messages: [], members: [], hasMore: false, loading: false, loadingMore: false, rev: 0, lastOp: "load" };
      return { threadCache: { ...st.threadCache, [threadId]: { ...base, loading: more ? base.loading : !cur, loadingMore: more } } };
    });
  },

  threadLoaded(p) {
    set((st) => {
      const cur = st.threadCache[p.threadId];
      const incoming = p.messages ?? [];
      let messages: Message[];
      if (p.prepend && cur) {
        const have = new Set(cur.messages.map((m) => m.id));
        messages = [...incoming.filter((m) => !have.has(m.id)), ...cur.messages];
      } else {
        messages = incoming;
      }
      const sent = new Set(messages.map((m) => m.id));
      return {
        threadCache: {
          ...st.threadCache,
          [p.threadId]: {
            messages, members: p.members ?? cur?.members ?? [], hasMore: !!p.hasMore, loading: false, loadingMore: false,
            rev: (cur?.rev ?? 0) + 1, lastOp: p.prepend ? "prepend" : "load",
          },
        },
        pending: st.pending.filter((x) => x.serverId == null || !sent.has(x.serverId)),
        seenToday: countToday(st.seenToday, incoming, st.dayStart),
      };
    });
  },

  messageArrived({ message, summary }) {
    set((st) => {
      const state = st.state ? { ...st.state, threads: summary ? upsertSummary(st.state.threads, summary) : st.state.threads } : st.state;
      const cache = st.threadCache[message.threadId];
      let threadCache = st.threadCache;
      if (cache && !cache.messages.some((m) => m.id === message.id)) {
        threadCache = {
          ...st.threadCache,
          [message.threadId]: { ...cache, messages: [...cache.messages, message], members: summary?.members ?? cache.members, rev: cache.rev + 1, lastOp: "append" },
        };
      }
      return {
        state,
        threadCache,
        pending: st.pending.filter((x) => x.serverId !== message.id),
        seenToday: countToday(st.seenToday, [message], st.dayStart),
      };
    });
  },

  messageUpdated(message) {
    set((st) => {
      const cache = st.threadCache[message.threadId];
      if (!cache || !cache.messages.some((m) => m.id === message.id)) return {};
      return { threadCache: { ...st.threadCache, [message.threadId]: { ...cache, messages: cache.messages.map((m) => (m.id === message.id ? message : m)), rev: cache.rev + 1, lastOp: "update" } } };
    });
  },

  setUnread(threadId, unread) {
    set((st) => st.state ? { state: { ...st.state, threads: st.state.threads.map((t) => (t.id === threadId ? { ...t, unread } : t)) } } : {});
  },

  addPending(p) { set((st) => ({ pending: [...st.pending, p] })); },
  pendingSent(tempId, serverId) {
    set((st) => {
      // The echo may already be in the thread: then the pending bubble goes.
      const echoed = Object.values(st.threadCache).some((c) => c.messages.some((m) => m.id === serverId));
      return { pending: echoed ? st.pending.filter((x) => x.tempId !== tempId) : st.pending.map((x) => (x.tempId === tempId ? { ...x, serverId } : x)) };
    });
  },
  pendingFailed(tempId) { set((st) => ({ pending: st.pending.map((x) => (x.tempId === tempId ? { ...x, failed: true } : x)) })); },
  dropPending(tempId) { set((st) => ({ pending: st.pending.filter((x) => x.tempId !== tempId) })); },

  setCall(call) {
    set((st) => {
      const prev = st.state?.call ?? null;
      const state = st.state ? { ...st.state, call } : st.state;
      let callView = st.callView;
      if (!call) callView = false;
      else if (call.phase === "incoming") callView = true;
      else if (!prev || prev.id !== call.id || prev.phase === "incoming") callView = true;
      return { state, callView, talkers: call ? st.talkers : {} };
    });
  },
  setTalkers(talkers) { set({ talkers: talkers ?? {} }); },
  pushToast(t) {
    set((st) => {
      const item: ToastItem = { ...t, id: t.id ?? `t${toastKey}`, at: t.at ?? Date.now(), key: toastKey++, born: Date.now() };
      const list = [...st.toasts.filter((x) => x.id !== item.id), item];
      return { toasts: list.slice(-3) };
    });
  },
  dismissToast(key) { set((st) => ({ toasts: st.toasts.filter((t) => t.key !== key) })); },
  setClock(clock) { set({ clock }); },
  setToggleKey(toggleKey) { set({ toggleKey }); },
  setEnded(e) { set({ ended: e ? { ...e, key: endedKey++ } : null }); },
  setKeyboard(keyboard) { set({ keyboard }); },
  setSettingsDraft(d) { set((st) => ({ settingsDraft: { ...st.settingsDraft, ...d } })); },
  replaceSettingsDraft(settingsDraft) { set({ settingsDraft }); },
  markRecentsSeen() {
    const at = Date.now();
    try { localStorage.setItem(SEEN_KEY, String(at)); } catch { /* storage may be off */ }
    set({ recentsSeenAt: at });
  },

  setSocialUnread(unread) {
    set((st) => (st.state?.social ? { state: { ...st.state, social: { ...st.state.social, unread: Math.max(0, unread) } } } : {}));
  },
  setSocialHandle(handle) {
    set((st) => {
      const old = st.state?.social?.handle;
      if (!st.state?.social || !old || old === handle) return {};
      const { [old]: _gone, ...profiles } = st.profiles;
      return {
        state: { ...st.state, social: { ...st.state.social, handle } },
        profiles,
        stack: st.stack.map((v) => (v.app === "social" && v.screen === "profile" && v.handle === old ? { ...v, handle } : v)),
      };
    });
  },

  feedLoading(key, more) {
    set((st) => {
      const cur = st.feeds[key];
      return { feeds: { ...st.feeds, [key]: { ...(cur ?? EMPTY_FEED), loading: more ? !!cur?.loading : !cur, loadingMore: more } } };
    });
  },
  feedLoaded(key, posts, hasMore, more) {
    set((st) => {
      const cur = st.feeds[key];
      let list = posts;
      if (more && cur) {
        const have = new Set(cur.posts.map((p) => p.id));
        list = [...cur.posts, ...posts.filter((p) => !have.has(p.id))];
      }
      // A fresh first page of Pulse already holds what the pill was waiting with.
      const newest = posts[0]?.id ?? 0;
      const freshPosts = key === "pulse" && !more ? st.freshPosts.filter((f) => f.id > newest) : st.freshPosts;
      return {
        feeds: { ...st.feeds, [key]: { posts: list, hasMore, loading: false, loadingMore: false, rev: (cur?.rev ?? 0) + 1 } },
        postLive: syncLive(st.postLive, posts),
        freshPosts,
      };
    });
  },
  feedFailed(key) {
    set((st) => {
      const cur = st.feeds[key];
      return cur ? { feeds: { ...st.feeds, [key]: { ...cur, loading: false, loadingMore: false } } } : {};
    });
  },
  prependPosts(key, posts) {
    set((st) => {
      const cur = st.feeds[key];
      if (!cur) return {};
      const add = posts.filter((p) => !cur.posts.some((x) => x.id === p.id));
      return add.length ? { feeds: { ...st.feeds, [key]: { ...cur, posts: [...add, ...cur.posts], rev: cur.rev + 1 } } } : {};
    });
  },

  screamThreadLoading(postId) {
    set((st) => {
      const cur = st.screamThreads[postId];
      return { screamThreads: { ...st.screamThreads, [postId]: cur ? { ...cur, loading: !cur.post } : { post: null, parents: [], replies: [], loading: true, missing: false } } };
    });
  },
  screamThreadLoaded(postId, t) {
    set((st) => {
      const cur = st.screamThreads[postId];
      if (!t) return { screamThreads: { ...st.screamThreads, [postId]: { post: cur?.post ?? null, parents: cur?.parents ?? [], replies: cur?.replies ?? [], loading: false, missing: !cur?.post } } };
      return {
        screamThreads: { ...st.screamThreads, [postId]: { ...t, loading: false, missing: false } },
        postLive: syncLive(st.postLive, [...(t.post ? [t.post] : []), ...t.parents, ...t.replies]),
      };
    });
  },
  addReply(parentId, post) {
    set((st) => {
      const cur = st.screamThreads[parentId];
      const live = st.postLive[parentId];
      const base = cur?.post ?? Object.values(st.feeds).flatMap((f) => f.posts).find((p) => p.id === parentId);
      return {
        screamThreads: cur && !cur.replies.some((r) => r.id === post.id) ? { ...st.screamThreads, [parentId]: { ...cur, replies: [...cur.replies, post] } } : st.screamThreads,
        postLive: { ...st.postLive, [parentId]: { ...live, replies: (live?.replies ?? base?.replies ?? 0) + 1 } },
      };
    });
  },

  setProfile(p) { set((st) => ({ profiles: { ...st.profiles, [p.handle]: p } })); },

  pingsLoading(more) {
    set((st) => ({ pings: { pings: st.pings?.pings ?? [], hasMore: st.pings?.hasMore ?? false, loading: more ? !!st.pings?.loading : !st.pings, loadingMore: more } }));
  },
  pingsLoaded(pings, hasMore, more) {
    set((st) => {
      const cur = st.pings?.pings ?? [];
      // Keep the "new" marks of this session: the server already flipped them to read.
      const fresh = new Set(cur.filter((p) => !p.read).map((p) => p.id));
      const page = pings.map((p) => (fresh.has(p.id) ? { ...p, read: false } : p));
      const list = more ? [...cur, ...page.filter((p) => !cur.some((x) => x.id === p.id))] : page;
      return { pings: { pings: list, hasMore, loading: false, loadingMore: false } };
    });
  },

  pingsSeen() {
    set((st) => (st.pings ? { pings: { ...st.pings, pings: st.pings.pings.map((p) => (p.read ? p : { ...p, read: true })) } } : {}));
  },

  setPostLive(id, live) { set((st) => ({ postLive: { ...st.postLive, [id]: { ...st.postLive[id], ...live } } })); },

  removePost(id) {
    set((st) => {
      const feeds: Record<string, FeedCache> = {};
      for (const [k, f] of Object.entries(st.feeds)) {
        const posts = withoutPost(f.posts, id);
        feeds[k] = posts === f.posts ? f : { ...f, posts, rev: f.rev + 1 };
      }
      const screamThreads: Record<number, ScreamThreadCache> = {};
      for (const [k, t] of Object.entries(st.screamThreads)) {
        if (Number(k) === id) continue;
        const post = t.post?.echoOf?.id === id ? { ...t.post, echoOf: null, echoGone: true } : t.post;
        screamThreads[Number(k)] = { ...t, post, parents: withoutPost(t.parents, id), replies: withoutPost(t.replies, id) };
      }
      return { feeds, screamThreads, postGone: { ...st.postGone, [id]: 1 }, freshPosts: withoutPost(st.freshPosts, id) };
    });
  },

  pushFresh(p) {
    set((st) => {
      if (st.freshPosts.some((x) => x.id === p.id) || st.feeds.pulse?.posts.some((x) => x.id === p.id)) return {};
      return { freshPosts: [p, ...st.freshPosts].slice(0, 50) };
    });
  },
  takeFresh() {
    const fresh = get().freshPosts;
    set({ freshPosts: [] });
    return fresh;
  },
  rememberPost(p) { set((st) => ({ composeCtx: { ...st.composeCtx, [p.id]: p } })); },
}));

/* ------------------------------------------------------------ selectors */

export const selectSettings = (s: Store): Settings => ({ ...DEFAULT_SETTINGS, ...(s.state?.settings ?? {}), ...s.settingsDraft });

export const topView = (s: Store): View | null => s.stack[s.stack.length - 1] ?? null;

export const getStore = () => useStore.getState();

/** No implant on this character (an older server without `implant` counts as installed). */
export const implantMissing = (s: Store): boolean => s.state?.implant?.installed === false;
/** The "no Neural-Link" / installation takeover replaces the interface. */
export const implantGate = (s: Store): boolean => !!s.state?.ready && (implantMissing(s) || s.implantFlow);
/** Calls and toasts stay hidden while there is no implant or the installation runs. */
export const implantLocked = (s: Store): boolean => implantMissing(s) || s.implantFlow;

/** Effective settings (server + unsaved draft), shallow-stable for React. */
export const useSettings = (): Settings => useStore(useShallow(selectSettings));

/** A scream with the latest known counters and toggles laid over it. */
export function usePostLive(p: SocialPost): SocialPost {
  const live = useStore((s) => s.postLive[p.id]);
  return live ? { ...p, ...live } : p;
}

/** Stable empty array for selectors (a fresh `[]` would re-render forever). */
export const EMPTY: never[] = [];
