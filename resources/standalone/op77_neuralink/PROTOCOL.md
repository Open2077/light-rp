# op77_neuralink — page ⇄ client protocol

The Neural-Link is the in-world replacement for smartphones: a holographic
neural interface (Sword Art Online main-menu language, Cyberpunk palette)
projected in front of the player's eyes. This file is the contract between the
React page (`web/`, source in `E:/Open77/LightRP/neuralink-ui`) and the client
Lua (`client/main.lua`). The server protocol is internal to the resource.

All payloads are JSON. Times are Unix **milliseconds**. Numbers are display
strings `"NNN-NNNN"`.

## Lua → page (`page:send(name, payload)`; page: `Open77.on(name, fn)`)

| Event | Payload | Meaning |
|---|---|---|
| `nl:state` | `State` | Full snapshot. Sent after `ui:ready`, after (re)connect and on character switch. Replaces everything. |
| `nl:patch` | `Partial<State>` | Replace only the top-level keys present (`contacts`, `threads`, `recents`, `settings`, `line`, `apps`). |
| `nl:open` | `{ app?: AppId, threadId?: number, number?: string, screen?, postId?, handle?, tag? }` | Show the interface (play the opening animation). Optional deep link; `screen` (thread, profile, tag, compose, pings, heat, edit) opens a Screamsheet screen over the Pulse feed; `install: true` starts the implant installation at once when there is none. |
| `nl:close` | `{}` | Hide the interface (play the closing animation). |
| `nl:thread` | `{ threadId, messages: Message[], members: Member[], hasMore: boolean, prepend?: boolean }` | Messages of one thread (latest 40, oldest first). `prepend` = an older page for infinite scroll. |
| `nl:message` | `{ message: Message, summary: ThreadSummary }` | A new message in any thread (incoming or the server echo of mine). Update the open thread and the list. |
| `nl:call` | `CallState \| null` | Current call; none when there is no call. Lua cannot send nil, so "no call" arrives as `{}`: the page treats any payload without a numeric `id` as no call. |
| `nl:callEnded` | `{ reason: CallEndReason, number?: string, name?: string, duration?: number }` | Last call ended: show a short end card (2.5 s). |
| `nl:talkers` | `{ [lineId: string]: number }` | During a call, ~8 Hz: voice level `0..1` of each talking participant (absent = silent). |
| `nl:toast` | `Toast` | A transient holographic notification (shown even when the interface is closed). |
| `nl:clock` | `{ hours: number, minutes: number, weather?: string }` | Night City game time, every 10 s. |
| `nl:focus` | `{ keyboard: boolean }` | Lua confirms the keyboard focus state (typing mode). |
| `nl:keys` | `{ toggle: string }` | The key bound to the Neural-Link (rebindable), shown on the ringing pill. Sent on `ui:ready` and once the key mapping registers. |

## Page → Lua

| Call | Payload | Meaning |
|---|---|---|
| `Open77.ready()` → `ui:ready` | | Page loaded (send it on every load). |
| `emit("nl:close")` | `{}` | User closed the interface (Escape at top level, close button). |
| `emit("nl:typing")` | `{ active: boolean }` | A text field gained (`true`) / lost (`false`) focus. Lua switches keyboard capture: while `active` the player stops and keys go to the page; otherwise the page has the mouse only and the player keeps walking. |
| `emit("nl:sound")` | `{ name: "ui:<name>" \| "preview:<ringtone>", volume? }` | Lua plays it with Play2DSound: an interface sample (`uiSounds` in shared/config.lua, scaled by `volume`) or a ringtone file (Settings preview). The page plays no audio itself. The incoming-call ringtone is a networked 3D sound owned by the server. |
| `invoke("nl:request", { op, args })` | see below | Resolves `{ ok: true, data }` or rejects with `Error(reason)`. |

### Request ops

| `op` | `args` | `data` |
|---|---|---|
| `contacts.save` | `{ id?, name, number, favorite? }` | `Contact` |
| `contacts.delete` | `{ id }` | `{}` |
| `threads.open` | `{ threadId }` | `{}` (the messages arrive as `nl:thread`; marks read) |
| `threads.more` | `{ threadId, beforeId }` | `{}` (arrives as `nl:thread` with `prepend`) |
| `threads.direct` | `{ number }` | `{ threadId }` (find or create the 1:1 thread) |
| `threads.read` | `{ threadId }` | `{}` |
| `messages.send` | `{ threadId, body }` | `{ id }` (body 1..500 chars) |
| `groups.create` | `{ title, numbers: string[] }` | `{ threadId }` (2..15 other members) |
| `groups.rename` | `{ threadId, title }` | `{}` |
| `groups.add` | `{ threadId, number }` | `{}` |
| `groups.remove` | `{ threadId, number }` | `{}` (owner only) |
| `groups.leave` | `{ threadId }` | `{}` |
| `call.dial` | `{ number }` | `{}` (state arrives as `nl:call`) |
| `call.group` | `{ threadId }` | `{}` (rings every member of a group thread) |
| `call.accept` / `call.decline` / `call.hangup` | `{}` | `{}` |
| `call.mute` | `{ muted: boolean }` | `{}` |
| `call.add` | `{ number }` | `{}` (invite one more participant, max 6) |
| `recents.clear` | `{}` | `{}` |
| `settings.save` | `Partial<Settings>` | `Settings` |
| `apps.launch` | `{ id }` | `{}` (third-party app: Lua fires its event and closes the interface if the app asks) |

### The implant (`implant.install`)

A character starts without a Neural-Link. While `state.implant.installed` is
false the page shows only "no Neural-Link detected" and the Kiroshi installation
sequence, and the server refuses every other op with `not_installed` (the line
cannot be called and receives no toast).

| op | args | data |
|---|---|---|
| `implant.install` | `{}` | `{ implant }`, then a fresh `nl:state`; `ripperdoc_required` when `config.implant.selfInstall` is off |

`state.implant` is `{ installed, installedAt, model, selfInstall }`.

### Screamsheet (`social.*`)

The players' social feed, app id `social`. Vocabulary: **scream** (a post, 280
characters), **Street Cred** (the like), **echo** (a repost; a **quote** is an
echo with a comment), **pings** (notifications), **Net Heat** (trending). One
profile per line, created on first use with a handle from the character name.
Types are `SocialProfile`, `SocialPost`, `SocialPing`, `SocialHeat` in
`neuralink-ui/src/bridge/protocol.ts`.

| op | args | data |
|---|---|---|
| `social.me` | `{}` | `{ profile, unread }` |
| `social.feed` | `{ mode: "pulse" \| "crew" \| "hot", beforeId? }` | `{ posts, hasMore }` (pulse = everyone, crew = people I follow and me, hot = 24 h best) |
| `social.tag` | `{ tag, beforeId? }` | `{ posts, hasMore }` |
| `social.post` | `{ body, replyTo?, quoteOf?, district? }` | `{ post }` (`district` = where the player stands, from `nl:clock`) |
| `social.echo` | `{ postId, district? }` | `{ echoed, echoes }` (toggle) |
| `social.cred` | `{ postId }` | `{ credded, cred }` (toggle) |
| `social.delete` | `{ postId }` | `{}` (author only) |
| `social.thread` | `{ postId }` | `{ post, parents, replies }` |
| `social.profile` | `{ handle, beforeId? }` | `{ profile, posts, hasMore }` |
| `social.follow` | `{ handle, follow }` | `{ followed, followers }` |
| `social.update` | `{ handle?, name?, bio? }` | `{ profile }` |
| `social.search` | `{ q }` | `{ profiles, posts }` (`#tag` searches a tag, `@x` handles only) |
| `social.heat` | `{}` | `{ tags, districts, hot }` |
| `social.pings` | `{ beforeId? }` | `{ pings, hasMore }` (the first page marks all read) |
| `social.report` | `{ postId, reason }` | `{}` |

Live: `nl:social` carries `{ kind: "post", post }` (someone else screamed or
echoed), `{ kind: "ping", ping, unread }`, `{ kind: "stats", postId, cred,
echoes, replies }` and `{ kind: "deleted", postId }`. A ping also raises an
`nl:toast` of kind `social` (`postId`, or `handle` for a follow). The snapshot
carries `social: { handle, unread }`.

Errors are short slugs the page turns into human text: `unknown_number`,
`unavailable` (callee offline), `busy`, `in_call`, `not_member`, `not_owner`,
`group_full`, `invalid_body`, `invalid_name`, `invalid_number`, `rate_limited`,
`no_line`, `database_unavailable`, `self`; Screamsheet adds `handle_taken`,
`invalid_handle`, `unknown_handle`, `unknown_post`, `not_author`; the implant
adds `not_installed` and `ripperdoc_required`.

## Shapes

```ts
type AppId = "home" | "phone" | "messages" | "contacts" | "settings" | "status" | string;

interface State {
  ready: boolean;                 // false while the server has not assigned a line yet
  line: { number: string; name: string } | null;
  settings: Settings;
  contacts: Contact[];
  threads: ThreadSummary[];       // most recent first
  recents: Recent[];              // most recent first, max 60
  apps: App[];                    // third-party apps registered by other resources
  call: CallState | null;
}
interface Settings {
  ringtone: "aurora" | "link" | "pulse" | "silent";
  volume: number;                 // 0..1
  dnd: boolean;                   // do not disturb: no ring, toasts muted
  accent: "sao" | "cyan" | "magenta";   // sao = white glass + gold selection (default)
  intensity: number;              // 0.3..1: hologram glow/scanline strength
  theme: "light" | "dark";        // dark = smoked black glass, light ink (sao style only)
  style: "cyberpunk" | "sao";     // cyberpunk = navy glass, cut corners, cyan lines, red selection (default)
}
interface Contact { id: number; name: string; number: string; favorite: boolean; online: boolean; }
interface Member { number: string; name: string; isMe: boolean; owner: boolean; online: boolean; }
interface ThreadSummary {
  id: number; kind: "direct" | "group"; title: string;   // direct: the other side's contact name or number
  members: Member[];
  last: { body: string; sender: string; at: number; mine: boolean; kind: "text" | "system" } | null;
  unread: number; updatedAt: number; isOwner: boolean;
}
interface Message {
  id: number; threadId: number; kind: "text" | "system";
  sender: { number: string; name: string };              // system: number ""
  body: string; at: number; mine: boolean;
}
interface Recent {
  id: number; number: string; name: string;
  direction: "in" | "out"; status: "answered" | "missed" | "declined" | "busy" | "unavailable";
  at: number; duration: number;                          // seconds
}
type CallPhase = "outgoing" | "incoming" | "active";
interface CallState {
  id: number; phase: CallPhase;
  startedAt: number | null;      // when the first other participant connected
  muted: boolean;
  group: { threadId: number; title: string } | null;
  participants: { lineId: string; number: string; name: string;
                  state: "ringing" | "connected" | "left"; muted: boolean; isMe: boolean }[];
  canAdd: boolean;
}
type CallEndReason = "hangup" | "declined" | "busy" | "unavailable" | "missed" | "no_answer" | "dropped";
interface Toast {
  id: string; kind: "message" | "call" | "missed" | "info" | "error";
  title: string; body: string; threadId?: number; number?: string; at: number;
}
interface App { id: string; label: string; icon: string; color?: string; }   // icon = lucide name
```
