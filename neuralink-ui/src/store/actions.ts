/* Request flows: everything that talks to Lua through `nl:request`. Failures
   become a short error toast; callers that need the outcome await the promise. */
import { emit, request, RequestError } from "@/bridge/open77";
import { errorText } from "@/bridge/errors";
import type { RequestArgs, RequestData, RequestOp, Settings, SocialFeedMode, SocialPost } from "@/bridge/protocol";
import { play } from "@/fx/sound";
import { getStore, type View } from "./store";

let localToast = 1;

export function toastError(slug: string): void {
  play("error");
  getStore().pushToast({ id: `local-err-${localToast++}`, kind: "error", title: "Neural-Link", body: errorText(slug), at: Date.now() });
}

export function toastInfo(title: string, body: string): void {
  getStore().pushToast({ id: `local-info-${localToast++}`, kind: "info", title, body, at: Date.now() });
}

/** Request with the error surfaced as a toast. Resolves `undefined` on failure. */
export async function act<O extends RequestOp>(op: O, args: RequestArgs<O>, opts: { quiet?: boolean } = {}): Promise<RequestData<O> | undefined> {
  try {
    return await request(op, args);
  } catch (err) {
    const slug = err instanceof RequestError ? err.slug : "unknown";
    if (!opts.quiet) toastError(slug);
    return undefined;
  }
}

/** Same, but rethrows the slug for forms that show it inline. */
export async function actOrThrow<O extends RequestOp>(op: O, args: RequestArgs<O>): Promise<RequestData<O>> {
  try {
    return await request(op, args);
  } catch (err) {
    throw err instanceof RequestError ? err : new RequestError("unknown");
  }
}

/* ------------------------------------------------------------- interface */

export function userClose(): void {
  const st = getStore();
  if (st.phase === "closed" || st.phase === "closing") return;
  (document.activeElement as HTMLElement | null)?.blur?.();
  play("close");
  st.closeUi();
  emit("nl:close", {});
}

export function goBack(): void {
  if (getStore().back()) play("back");
  else userClose();
}

export function navigate(v: View, mode: "reset" | "push" = "push"): void {
  const st = getStore();
  if (mode === "reset") st.resetView(v); else st.pushView(v);
  play("select");
}

/* --------------------------------------------------------------- threads */

export function openThread(threadId: number, mode: "reset" | "push" = "push"): void {
  const st = getStore();
  if (mode === "reset") st.resetView({ app: "messages", screen: "list" });
  getStore().pushView({ app: "messages", screen: "thread", threadId });
  play("select");
  loadThread(threadId);
}

export function loadThread(threadId: number): void {
  const st = getStore();
  st.threadLoading(threadId, false);
  st.setUnread(threadId, 0);
  void act("threads.open", { threadId }).then((r) => {
    if (r === undefined) {
      const c = getStore().threadCache[threadId];
      if (c?.loading) getStore().threadLoaded({ threadId, messages: c.messages, members: c.members, hasMore: false });
    }
  });
}

export function loadOlder(threadId: number): void {
  const st = getStore();
  const c = st.threadCache[threadId];
  if (!c || !c.hasMore || c.loadingMore || c.loading) return;
  const first = c.messages[0];
  if (!first) return;
  st.threadLoading(threadId, true);
  void act("threads.more", { threadId, beforeId: first.id }, { quiet: true }).then((r) => {
    if (r === undefined) {
      const cur = getStore().threadCache[threadId];
      if (cur) getStore().threadLoaded({ threadId, messages: [], members: cur.members, hasMore: cur.hasMore, prepend: true });
    }
  });
}

export async function messageNumber(number: string): Promise<void> {
  const r = await act("threads.direct", { number });
  if (r) openThread(r.threadId, "reset");
}

let tempId = -1;
export async function sendMessage(threadId: number, body: string): Promise<boolean> {
  const st = getStore();
  const id = tempId--;
  st.addPending({ tempId: id, threadId, body, at: Date.now(), failed: false });
  play("send");
  try {
    const r = await request("messages.send", { threadId, body });
    getStore().pendingSent(id, r.id);
    return true;
  } catch (err) {
    getStore().pendingFailed(id);
    toastError(err instanceof RequestError ? err.slug : "unknown");
    return false;
  }
}

export function retryPending(tempIdValue: number): void {
  const p = getStore().pending.find((x) => x.tempId === tempIdValue);
  if (!p) return;
  getStore().dropPending(tempIdValue);
  void sendMessage(p.threadId, p.body);
}

/* ------------------------------------------------------------------ calls */

export async function dial(number: string): Promise<boolean> {
  const st = getStore();
  if (st.state?.call) { toastError("in_call"); return false; }
  play("select");
  return (await act("call.dial", { number })) !== undefined;
}

export async function groupCall(threadId: number): Promise<boolean> {
  if (getStore().state?.call) { toastError("in_call"); return false; }
  play("select");
  return (await act("call.group", { threadId })) !== undefined;
}

/* --------------------------------------------------------------- settings */

let saveTimer: number | undefined;
let pendingSave: Partial<Settings> = {};

/** Apply immediately (draft), save debounced so a slider drag is one request. */
export function changeSettings(patch: Partial<Settings>, delay = 450): void {
  getStore().setSettingsDraft(patch);
  pendingSave = { ...pendingSave, ...patch };
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(flushSettings, delay);
}

async function flushSettings(): Promise<void> {
  const body = pendingSave;
  pendingSave = {};
  if (Object.keys(body).length === 0) return;
  const r = await act("settings.save", body);
  const st = getStore();
  // Drop the saved keys from the draft (or revert them on failure); keep any
  // key changed again while the request was in flight.
  const keep = { ...st.settingsDraft };
  for (const k of Object.keys(body) as (keyof Settings)[]) if (!(k in pendingSave)) delete keep[k];
  if (r && st.state) st.applyPatch({ settings: r });
  getStore().replaceSettingsDraft(keep);
}

/* ------------------------------------------------------------ screamsheet */

/** Feed cache keys: "pulse" | "crew" | "hot", "#tag" for a tag feed, "@handle" for a profile. */
export const tagKey = (tag: string) => `#${tag}`;
export const profileKey = (handle: string) => `@${handle}`;

export function openScream(postId: number, mode: "reset" | "push" = "push"): void {
  const st = getStore();
  if (mode === "reset") st.resetView({ app: "social", screen: "feed", mode: "pulse" });
  getStore().pushView({ app: "social", screen: "thread", postId });
  play("select");
}

export function openProfile(handle: string, mode: "reset" | "push" = "push"): void {
  const st = getStore();
  if (mode === "reset") st.resetView({ app: "social", screen: "feed", mode: "pulse" });
  getStore().pushView({ app: "social", screen: "profile", handle });
  play("select");
}

export function openTag(tag: string): void {
  navigate({ app: "social", screen: "tag", tag: tag.replace(/^#/, "").toLowerCase() });
}

/** Open the composer on a scream: a reply, or a quote. */
export function composeOn(post: SocialPost, kind: "reply" | "quote"): void {
  getStore().rememberPost(post);
  navigate(kind === "reply" ? { app: "social", screen: "compose", replyTo: post.id } : { app: "social", screen: "compose", quoteOf: post.id });
}

/** First page (or the next one with `more`) of a feed, a tag or a profile. */
export async function loadFeed(key: string, more = false): Promise<void> {
  const st = getStore();
  const cur = st.feeds[key];
  if (more && (!cur || !cur.hasMore || cur.loading || cur.loadingMore)) return;
  const beforeId = more ? cur?.posts[cur.posts.length - 1]?.id : undefined;
  st.feedLoading(key, more);
  let page: { posts: SocialPost[]; hasMore: boolean } | undefined;
  if (key.startsWith("#")) {
    page = await act("social.tag", { tag: key.slice(1), beforeId }, { quiet: more });
  } else if (key.startsWith("@")) {
    const r = await act("social.profile", { handle: key.slice(1), beforeId }, { quiet: true });
    if (r) getStore().setProfile(r.profile);
    page = r;
  } else {
    page = await act("social.feed", { mode: key as SocialFeedMode, beforeId }, { quiet: more });
  }
  if (page) getStore().feedLoaded(key, page.posts ?? [], !!page.hasMore, more);
  else getStore().feedFailed(key);
}

export function loadProfile(handle: string, more = false): Promise<void> {
  return loadFeed(profileKey(handle), more);
}

export async function loadScreamThread(postId: number): Promise<void> {
  getStore().screamThreadLoading(postId);
  const r = await act("social.thread", { postId }, { quiet: true });
  getStore().screamThreadLoaded(postId, r ? { post: r.post, parents: r.parents ?? [], replies: r.replies ?? [] } : null);
}

let pingsFirst: Promise<void> | null = null;

export function loadPings(more = false): Promise<void> {
  if (more) return fetchPings(true);
  // One first page at a time: a second one would find everything already read.
  pingsFirst ??= fetchPings(false).finally(() => { pingsFirst = null; });
  return pingsFirst;
}

async function fetchPings(more: boolean): Promise<void> {
  const st = getStore();
  const cur = st.pings;
  if (more && (!cur || !cur.hasMore || cur.loading || cur.loadingMore)) return;
  const beforeId = more ? cur?.pings[cur.pings.length - 1]?.id : undefined;
  st.pingsLoading(more);
  const r = await act("social.pings", { beforeId }, { quiet: more });
  // The first page marks everything read on the server.
  if (r && !more) getStore().setSocialUnread(0);
  getStore().pingsLoaded(r?.pings ?? cur?.pings ?? [], r ? !!r.hasMore : false, more && !!r);
}

const inflight = new Set<string>();

/** Optimistic Street Cred toggle, rolled back on error. */
export async function toggleCred(post: SocialPost): Promise<void> {
  const key = `cred:${post.id}`;
  if (inflight.has(key)) return;
  inflight.add(key);
  const prev = { credded: post.credded, cred: post.cred };
  const on = !post.credded;
  getStore().setPostLive(post.id, { credded: on, cred: Math.max(0, post.cred + (on ? 1 : -1)) });
  play(on ? "select" : "back");
  try {
    const r = await request("social.cred", { postId: post.id });
    getStore().setPostLive(post.id, { credded: r.credded, cred: r.cred });
  } catch (err) {
    getStore().setPostLive(post.id, prev);
    toastError(err instanceof RequestError ? err.slug : "unknown");
  } finally {
    inflight.delete(key);
  }
}

/** Optimistic plain echo toggle, rolled back on error. */
export async function toggleEcho(post: SocialPost): Promise<void> {
  const key = `echo:${post.id}`;
  if (inflight.has(key)) return;
  inflight.add(key);
  const prev = { echoed: post.echoed, echoes: post.echoes };
  const on = !post.echoed;
  getStore().setPostLive(post.id, { echoed: on, echoes: Math.max(0, post.echoes + (on ? 1 : -1)) });
  play(on ? "select" : "back");
  try {
    const r = await request("social.echo", { postId: post.id, district: getStore().clock?.district });
    getStore().setPostLive(post.id, { echoed: r.echoed, echoes: r.echoes });
  } catch (err) {
    getStore().setPostLive(post.id, prev);
    toastError(err instanceof RequestError ? err.slug : "unknown");
  } finally {
    inflight.delete(key);
  }
}

/** Scream (or reply / quote). The new scream lands in the caches it belongs to. */
export async function scream(body: string, ctx: { replyTo?: number; quoteOf?: number } = {}): Promise<SocialPost | null> {
  const r = await act("social.post", { body, replyTo: ctx.replyTo, quoteOf: ctx.quoteOf, district: getStore().clock?.district });
  if (!r?.post) return null;
  play("send");
  const st = getStore();
  if (ctx.replyTo != null) st.addReply(ctx.replyTo, r.post);
  else {
    st.prependPosts("pulse", [r.post]);
    st.prependPosts("crew", [r.post]);
    const me = st.state?.social?.handle;
    if (me) st.prependPosts(profileKey(me), [r.post]);
  }
  return r.post;
}

export async function deleteScream(postId: number): Promise<void> {
  if ((await act("social.delete", { postId })) === undefined) return;
  play("back");
  const st = getStore();
  st.removePost(postId);
  const top = st.stack[st.stack.length - 1];
  if (top?.app === "social" && top.screen === "thread" && top.postId === postId) st.back();
}

export async function reportScream(postId: number, reason: string): Promise<void> {
  if ((await act("social.report", { postId, reason })) === undefined) return;
  play("select");
  toastInfo("Screamsheet", "Report filed. The sysops will take a look.");
}

export async function follow(handle: string, on: boolean): Promise<void> {
  const r = await act("social.follow", { handle, follow: on });
  if (!r) return;
  play(r.followed ? "select" : "back");
  const st = getStore();
  const p = st.profiles[handle];
  if (p) st.setProfile({ ...p, followed: r.followed, followers: r.followers });
  // Crew depends on who I follow: refetch it next time.
  if (st.feeds.crew) void loadFeed("crew");
}
