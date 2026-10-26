/* Page <-> client Lua contract of op77_neuralink. Mirrors
   resources/standalone/op77_neuralink/PROTOCOL.md: keep both in sync. Times are
   Unix milliseconds, numbers are display strings "NNN-NNNN". */

export type AppId = "home" | "phone" | "messages" | "contacts" | "settings" | "status" | (string & {});

export type Ringtone = "aurora" | "link" | "pulse" | "silent";
export type Accent = "sao" | "cyan" | "magenta";
export type Theme = "light" | "dark";
/** cyberpunk = navy glass, cut corners, cyan lines, red selection (default); sao = the original white glass. */
export type Style = "cyberpunk" | "sao";

export interface Settings {
  ringtone: Ringtone;
  volume: number; // 0..1
  dnd: boolean;
  accent: Accent;
  intensity: number; // 0.3..1
  theme: Theme;
  style: Style;
}

export interface Line { number: string; name: string }

export interface Contact { id: number; name: string; number: string; favorite: boolean; online: boolean }

export interface Member { number: string; name: string; isMe: boolean; owner: boolean; online: boolean }

export interface ThreadLast { body: string; sender: string; at: number; mine: boolean; kind: "text" | "system" }

export interface ThreadSummary {
  id: number;
  kind: "direct" | "group";
  title: string;
  members: Member[];
  last: ThreadLast | null;
  unread: number;
  updatedAt: number;
  isOwner: boolean;
}

export interface Message {
  id: number;
  threadId: number;
  kind: "text" | "system";
  sender: { number: string; name: string };
  body: string;
  at: number;
  mine: boolean;
}

export type RecentStatus = "answered" | "missed" | "declined" | "busy" | "unavailable";

export interface Recent {
  id: number;
  number: string;
  name: string;
  direction: "in" | "out";
  status: RecentStatus;
  at: number;
  duration: number; // seconds
}

export type CallPhase = "outgoing" | "incoming" | "active";

export interface CallParticipant {
  lineId: string;
  number: string;
  name: string;
  state: "ringing" | "connected" | "left";
  muted: boolean;
  isMe: boolean;
}

export interface CallState {
  id: number;
  phase: CallPhase;
  startedAt: number | null;
  muted: boolean;
  group: { threadId: number; title: string } | null;
  participants: CallParticipant[];
  canAdd: boolean;
}

export type CallEndReason = "hangup" | "declined" | "busy" | "unavailable" | "missed" | "no_answer" | "dropped";

export interface ToastPayload {
  id: string;
  kind: "message" | "call" | "missed" | "info" | "error" | "social";
  title: string;
  body: string;
  threadId?: number;
  number?: string;
  /** kind "social": the scream to open on click (absent for a follow). */
  postId?: number;
  /** kind "social": the handle to open when there is no postId. */
  handle?: string;
  at: number;
}

export interface ThirdPartyApp { id: string; label: string; icon: string; color?: string }

/** The implant. Without one the player sees only "no Neural-Link detected" and
    the installation sequence; the line cannot be called meanwhile. */
export interface ImplantState {
  installed: boolean;
  installedAt: number | null;
  /** "Kiroshi NL-77 Synapse" */
  model: string;
  /** false: the player cannot install it alone (a ripperdoc does, through a server export). */
  selfInstall: boolean;
}

export interface State {
  ready: boolean;
  line: Line | null;
  settings: Settings;
  contacts: Contact[];
  threads: ThreadSummary[];
  recents: Recent[];
  apps: ThirdPartyApp[];
  call: CallState | null;
  /** Screamsheet: my handle and unread pings; null before the line is ready. */
  social: SocialSummary | null;
  implant: ImplantState;
}

/* ------------------------------------------------------------ Screamsheet */
/* The players' social feed (app id "social"). In Night City lore screamsheets
   are the printed news sheets; here every citizen prints their own.
     scream  = a post (280 chars)          cred  = the like (Street Cred)
     echo    = a repost (body empty)       quote = an echo with a comment
     pings   = notifications               heat  = trending (tags, districts) */

export const SCREAM_MAX = 280;
export const HANDLE_RE = /^[a-z0-9_]{3,16}$/;
export const BIO_MAX = 160;
export const SOCIAL_NAME_MAX = 32;

export interface SocialSummary { handle: string; unread: number }

/** The few author fields every scream carries. `seed` keys the avatar colours. */
export interface SocialAuthor { handle: string; name: string; seed: string; online: boolean }

export interface SocialProfile extends SocialAuthor {
  bio: string;
  joinedAt: number;
  posts: number;
  followers: number;
  following: number;
  /** Street Cred received on all their screams. */
  cred: number;
  isMe: boolean;
  /** I follow them. */
  followed: boolean;
  /** They follow me. */
  followsMe: boolean;
}

export interface SocialPost {
  id: number;
  author: SocialAuthor;
  /** Empty for a plain echo. #tags and @handles are plain text, the page highlights them. */
  body: string;
  at: number;
  /** Night City district it was screamed from ("Kabuki", "Japantown"...), or null. */
  district: string | null;
  /** A reply: the scream it answers. */
  replyTo: { id: number; handle: string } | null;
  /** An echo (body "") or a quote (body set): the original, hydrated, one level deep. Null when deleted. */
  echoOf: SocialPost | null;
  /** true when echoOf pointed at a scream that has since been deleted. */
  echoGone?: boolean;
  replies: number;
  echoes: number;
  cred: number;
  /** I gave it Street Cred. */
  credded: boolean;
  /** I echoed it. */
  echoed: boolean;
  mine: boolean;
}

export type SocialFeedMode = "pulse" | "crew" | "hot";

export type SocialPingKind = "cred" | "echo" | "quote" | "reply" | "mention" | "follow";
export interface SocialPing {
  id: number;
  kind: SocialPingKind;
  actor: SocialAuthor;
  /** The scream concerned (mine for cred/echo/quote... the new one for reply/mention); null for follow. */
  post: { id: number; body: string } | null;
  at: number;
  read: boolean;
}

export interface SocialHeat {
  /** Most used #tags over the last 24 h. */
  tags: { tag: string; count: number }[];
  /** Screams per district over the last 24 h, most active first. */
  districts: { district: string; count: number }[];
  /** Most Street Cred + echoes over the last 24 h. */
  hot: SocialPost[];
}

export type SocialLive =
  | { kind: "post"; post: SocialPost }                  // someone screamed (top-level or echo): "new screams" banner
  | { kind: "ping"; ping: SocialPing; unread: number }  // a ping for me
  | { kind: "stats"; postId: number; cred: number; echoes: number; replies: number }
  | { kind: "deleted"; postId: number };

/* ---------------------------------------------------------------- events */

export interface OpenPayload {
  app?: AppId;
  threadId?: number;
  number?: string;
  /** Screamsheet deep links: a screen over the Pulse feed (postId for thread, handle for profile, tag for tag). */
  screen?: "thread" | "profile" | "tag" | "compose" | "pings" | "heat" | "edit";
  postId?: number;
  handle?: string;
  tag?: string;
  /** Without an implant: start the installation at once instead of the diagnostic screen (a ripperdoc scene). */
  install?: boolean;
}
export interface ThreadPayload { threadId: number; messages: Message[]; members: Member[]; hasMore: boolean; prepend?: boolean }
export interface MessagePayload { message: Message; summary: ThreadSummary }
export interface CallEndedPayload { reason: CallEndReason; number?: string; name?: string; duration?: number }
export type TalkersPayload = Record<string, number>;
export interface ClockPayload { hours: number; minutes: number; weather?: string; /** Night City district the player stands in. */ district?: string }
export interface FocusPayload { keyboard: boolean }
/** The key bound to the Neural-Link (the player can rebind it). */
export interface KeysPayload { toggle: string }

/** Lua -> page. */
export interface InboundEvents {
  "nl:state": State;
  "nl:patch": Partial<State>;
  "nl:open": OpenPayload;
  "nl:close": Record<string, never>;
  "nl:thread": ThreadPayload;
  "nl:message": MessagePayload;
  "nl:call": CallState | null;
  "nl:callEnded": CallEndedPayload;
  "nl:talkers": TalkersPayload;
  "nl:toast": ToastPayload;
  "nl:clock": ClockPayload;
  "nl:focus": FocusPayload;
  "nl:keys": KeysPayload;
  "nl:social": SocialLive;
}

/** `nl:sound` names. Lua plays every sound with Play2DSound: the interface
    samples for `ui:<name>`, the ringtone files for `preview:<ringtone>`. */
export type SoundName = `ui:${string}` | `preview:${Ringtone}`;

/** Page -> Lua. */
export interface OutboundEvents {
  "nl:close": Record<string, never>;
  "nl:typing": { active: boolean };
  "nl:sound": { name: SoundName; volume?: number };
}

/* --------------------------------------------------------------- requests */

export interface RequestOps {
  "contacts.save": { args: { id?: number; name: string; number: string; favorite?: boolean }; data: Contact };
  "contacts.delete": { args: { id: number }; data: Record<string, never> };
  "threads.open": { args: { threadId: number }; data: Record<string, never> };
  "threads.more": { args: { threadId: number; beforeId: number }; data: Record<string, never> };
  "threads.direct": { args: { number: string }; data: { threadId: number } };
  "threads.read": { args: { threadId: number }; data: Record<string, never> };
  "messages.send": { args: { threadId: number; body: string }; data: { id: number } };
  "groups.create": { args: { title: string; numbers: string[] }; data: { threadId: number } };
  "groups.rename": { args: { threadId: number; title: string }; data: Record<string, never> };
  "groups.add": { args: { threadId: number; number: string }; data: Record<string, never> };
  "groups.remove": { args: { threadId: number; number: string }; data: Record<string, never> };
  "groups.leave": { args: { threadId: number }; data: Record<string, never> };
  "call.dial": { args: { number: string }; data: Record<string, never> };
  "call.group": { args: { threadId: number }; data: Record<string, never> };
  "call.accept": { args: Record<string, never>; data: Record<string, never> };
  "call.decline": { args: Record<string, never>; data: Record<string, never> };
  "call.hangup": { args: Record<string, never>; data: Record<string, never> };
  "call.mute": { args: { muted: boolean }; data: Record<string, never> };
  "call.add": { args: { number: string }; data: Record<string, never> };
  "recents.clear": { args: Record<string, never>; data: Record<string, never> };
  "settings.save": { args: Partial<Settings>; data: Settings };
  "apps.launch": { args: { id: string }; data: Record<string, never> };
  /** Installs the implant (the only op allowed without one). */
  "implant.install": { args: Record<string, never>; data: { implant: ImplantState } };

  "social.me": { args: Record<string, never>; data: { profile: SocialProfile; unread: number } };
  "social.feed": { args: { mode: SocialFeedMode; beforeId?: number }; data: { posts: SocialPost[]; hasMore: boolean } };
  "social.tag": { args: { tag: string; beforeId?: number }; data: { posts: SocialPost[]; hasMore: boolean } };
  /** replyTo: answer a scream. quoteOf: quote it (echo with a comment). district: where I am (from nl:clock). */
  "social.post": { args: { body: string; replyTo?: number; quoteOf?: number; district?: string }; data: { post: SocialPost } };
  /** Toggle a plain echo of a scream. */
  "social.echo": { args: { postId: number; district?: string }; data: { echoed: boolean; echoes: number } };
  /** Toggle my Street Cred on a scream. */
  "social.cred": { args: { postId: number }; data: { credded: boolean; cred: number } };
  "social.delete": { args: { postId: number }; data: Record<string, never> };
  /** A scream, the chain it answers (oldest first) and its replies (oldest first). */
  "social.thread": { args: { postId: number }; data: { post: SocialPost; parents: SocialPost[]; replies: SocialPost[] } };
  "social.profile": { args: { handle: string; beforeId?: number }; data: { profile: SocialProfile; posts: SocialPost[]; hasMore: boolean } };
  "social.follow": { args: { handle: string; follow: boolean }; data: { followed: boolean; followers: number } };
  "social.update": { args: { handle?: string; name?: string; bio?: string }; data: { profile: SocialProfile } };
  "social.search": { args: { q: string }; data: { profiles: SocialProfile[]; posts: SocialPost[] } };
  "social.heat": { args: Record<string, never>; data: SocialHeat };
  /** Pings, newest first; the first page marks everything read. */
  "social.pings": { args: { beforeId?: number }; data: { pings: SocialPing[]; hasMore: boolean } };
  "social.report": { args: { postId: number; reason: string }; data: Record<string, never> };
}

export type RequestOp = keyof RequestOps;
export type RequestArgs<O extends RequestOp> = RequestOps[O]["args"];
export type RequestData<O extends RequestOp> = RequestOps[O]["data"];

export interface RequestEnvelope<O extends RequestOp = RequestOp> { op: O; args: RequestArgs<O> }
export type RequestResult<O extends RequestOp = RequestOp> = { ok: true; data: RequestData<O> } | { ok: false; reason?: string; error?: string };

export const ERROR_SLUGS = [
  "unknown_number", "unavailable", "busy", "in_call", "not_member", "not_owner", "group_full",
  "invalid_body", "invalid_name", "invalid_number", "rate_limited", "no_line", "database_unavailable", "self",
  "handle_taken", "invalid_handle", "unknown_handle", "unknown_post", "not_author",
  "not_installed", "ripperdoc_required",
] as const;
export type ErrorSlug = (typeof ERROR_SLUGS)[number];

export const DEFAULT_SETTINGS: Settings = { ringtone: "aurora", volume: 0.7, dnd: false, accent: "sao", intensity: 0.8, theme: "light", style: "cyberpunk" };

export const NUMBER_RE = /^\d{3}-\d{4}$/;
export const MAX_BODY = 500;
export const GROUP_MIN_OTHERS = 2;
export const GROUP_MAX_OTHERS = 15;
export const CALL_MAX_PARTICIPANTS = 6;
