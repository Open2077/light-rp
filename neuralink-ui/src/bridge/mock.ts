/* Browser stand-in for the game's bridge (installed by main.tsx when
   `window.Open77` is absent). Plays a believable Neural-Link session and answers
   every request op of PROTOCOL.md.

   URL flags (combine freely):
     ?open=1                  open the interface once the state arrives
     &app=messages|phone|contacts|social|settings|status|home   deep link
     &thread=2                with app=messages: open that thread
     &number=555-0142         with app=phone/contacts: prefill
     &call=incoming|incoming-group|outgoing|active|group   start in that call state
     &toast=1                 push sample toasts
     &ended=1                 show a call-ended card
     &sync=1                  start with ready=false (synchronising) for 3 s
     &accent=cyan|magenta     start with that accent
     &style=sao               the original SAO look (default: cyberpunk)
     &social=live             a stranger screams every ~20 s, a ping every other time
     &district=Japantown      the district nl:clock reports (default Kabuki)
     &implant=0|ripper|fail   no implant yet (ripper: only a ripperdoc installs it; fail: the first install fails)
     &dev=0                   hide the mock control strip
   Console: window.nlMock.incoming(), .incomingGroup(), .message(), .toast(), .scream(), .ping(), .open(), .close(), .implant(on) */
import type {
  CallEndReason, CallParticipant, CallState, Contact, ImplantState, Member, Message, Recent, RequestOp, Settings, SocialAuthor, SocialHeat,
  SocialLive, SocialPing, SocialPingKind, SocialPost, SocialProfile, State, ThreadSummary, ToastPayload,
} from "./protocol";
import { BIO_MAX, DEFAULT_SETTINGS, HANDLE_RE, NUMBER_RE, SCREAM_MAX, SOCIAL_NAME_MAX } from "./protocol";
import type { Open77Bridge } from "./open77";

const ME = { number: "555-0177", name: "Yuki Tanaka", lineId: "L-0177" };

/** Every line that exists on the mock "network". online=false -> unavailable. */
const DIRECTORY: Record<string, { name: string; online: boolean; busy?: boolean }> = {
  "555-0142": { name: "Judy Alvarez", online: true },
  "555-0199": { name: "Panam Palmer", online: true },
  "555-0110": { name: "Viktor Vektor", online: false },
  "555-0123": { name: "Misty Olszewski", online: true },
  "555-0168": { name: "River Ward", online: false },
  "555-0105": { name: "Goro Takemura", online: true, busy: true },
  "555-0131": { name: "Dakota Smith", online: true },
  "555-0164": { name: "Kerry Eurodyne", online: true },
  "555-0190": { name: "Mitch Anderson", online: true },
  [ME.number]: { name: ME.name, online: true },
};

const REPLIES = [
  "Copy that. On my way.",
  "Give me five, choom.",
  "Preem. See you at the Afterlife?",
  "You serious? Ha. Alright.",
  "Can't talk now, NCPD on my tail.",
  "Sending you the coords in a sec.",
  "Got it. Stay frosty.",
  "Delta out of there if it gets hot.",
];

export function installMockBridge(): void {
  window.__neuralinkMock = true;
  const params = new URLSearchParams(location.search);
  const handlers = new Map<string, Set<(payload: unknown) => void>>();
  const fire = (name: string, payload: unknown, delay = 0) => {
    window.setTimeout(() => { for (const fn of handlers.get(name) ?? []) fn(structuredClone(payload)); }, delay);
  };

  const now = Date.now();
  const min = 60_000, hour = 3_600_000;
  let open = false;
  let nextMsgId = 1000;
  let nextThreadId = 10;
  let nextRecentId = 100;
  let nextContactId = 20;
  let nextCallId = 1;

  const accent = params.get("accent");
  const settings: Settings = {
    ...DEFAULT_SETTINGS,
    accent: accent === "cyan" || accent === "magenta" ? accent : "sao",
    theme: params.get("theme") === "dark" ? "dark" : "light",
    style: params.get("style") === "sao" ? "sao" : "cyberpunk",
  };

  const implantFlag = params.get("implant");
  const implant: ImplantState = {
    installed: implantFlag == null || implantFlag === "1",
    installedAt: implantFlag == null || implantFlag === "1" ? now - 40 * 86_400_000 : null,
    model: "Kiroshi NL-77 Synapse",
    selfInstall: implantFlag !== "ripper",
  };
  let installFailsOnce = implantFlag === "fail";

  const contacts: Contact[] = [
    { id: 1, name: "Judy Alvarez", number: "555-0142", favorite: true, online: true },
    { id: 2, name: "Panam Palmer", number: "555-0199", favorite: true, online: true },
    { id: 3, name: "Viktor Vektor", number: "555-0110", favorite: false, online: false },
    { id: 4, name: "Misty Olszewski", number: "555-0123", favorite: true, online: true },
    { id: 5, name: "River Ward", number: "555-0168", favorite: false, online: false },
    { id: 6, name: "Goro Takemura", number: "555-0105", favorite: false, online: true },
  ];

  const nameOf = (number: string) => contacts.find((c) => c.number === number)?.name ?? number;
  const member = (number: string, owner = false): Member => ({
    number, name: number === ME.number ? ME.name : nameOf(number), isMe: number === ME.number, owner, online: number === ME.number || !!DIRECTORY[number]?.online,
  });

  interface MockThread { id: number; kind: "direct" | "group"; title: string; members: Member[]; messages: Message[]; unread: number }
  const threads: MockThread[] = [];

  const mk = (threadId: number, from: string, body: string, at: number, kind: "text" | "system" = "text"): Message => ({
    id: nextMsgId++, threadId, kind, body, at,
    sender: kind === "system" ? { number: "", name: "" } : { number: from, name: from === ME.number ? ME.name : nameOf(from) },
    mine: kind !== "system" && from === ME.number,
  });

  // 1: direct with Judy.
  {
    const id = 1;
    const t: MockThread = { id, kind: "direct", title: "Judy Alvarez", members: [member(ME.number), member("555-0142")], messages: [], unread: 2 };
    const lines: [string, string, number][] = [
      ["555-0142", "Hey V... I mean, Yuki. You still up?", 3 * hour],
      [ME.number, "Always. What's up?", 3 * hour - 2 * min],
      ["555-0142", "Found something in the braindance archive. Need a second pair of eyes.", 3 * hour - 4 * min],
      [ME.number, "Lizzie's?", 3 * hour - 5 * min],
      ["555-0142", "Yeah. Back room. Come alone.", 3 * hour - 6 * min],
      [ME.number, "On my way. 20 min.", 2.9 * hour],
      ["555-0142", "Thanks for tonight. Seriously.", 18 * min],
      ["555-0142", "Next round's on me.", 17 * min],
    ];
    for (const [from, body, ago] of lines) t.messages.push(mk(id, from, body, now - ago));
    threads.push(t);
  }
  // 2: group Aldecaldos Run (I own it), long history for infinite scroll.
  {
    const id = 2;
    const nums = [ME.number, "555-0199", "555-0168", "555-0123"];
    const t: MockThread = { id, kind: "group", title: "Aldecaldos Run", members: nums.map((n, i) => member(n, i === 0)), messages: [], unread: 5 };
    t.messages.push(mk(id, "", "Yuki Tanaka created the group", now - 30 * hour, "system"));
    const chatter = [
      "Convoy leaves at dawn.", "Who's bringing the Thorton?", "Me. Tank's full.", "Watch out for Raffen Shiv near the canyon.",
      "Copy.", "I'll scout the north ridge.", "Need more ammo, anyone?", "Got a crate in the trunk.", "Sun's coming up, move it.",
      "Radio check.", "Loud and clear.", "Eyes on a Militech drone, 2 o'clock.", "Going dark for 10.", "Back. All clear.",
    ];
    for (let i = 0; i < 64; i++) {
      const from = nums[(i * 7 + 3) % nums.length]!;
      t.messages.push(mk(id, from, chatter[i % chatter.length]!, now - 29 * hour + i * 25 * min));
    }
    t.messages.push(mk(id, "", "Misty Olszewski joined the group", now - 2 * hour, "system"));
    t.messages.push(mk(id, "555-0123", "The cards say this run goes well. Mostly.", now - 1.5 * hour));
    t.messages.push(mk(id, "555-0199", "Mostly?", now - 1.4 * hour));
    t.messages.push(mk(id, "555-0199", "Gas station on Route 66 in 30. Don't be late.", now - 6 * min));
    t.messages.sort((a, b) => a.at - b.at);
    threads.push(t);
  }
  // 3: direct with Viktor.
  {
    const id = 3;
    const t: MockThread = { id, kind: "direct", title: "Viktor Vektor", members: [member(ME.number), member("555-0110")], messages: [], unread: 0 };
    t.messages.push(mk(id, "555-0110", "Your new cyberdeck is ready. Swing by the clinic.", now - 26 * hour));
    t.messages.push(mk(id, ME.number, "Tomorrow morning. Thanks Vik.", now - 25.5 * hour));
    t.messages.push(mk(id, "555-0110", "Don't push the overclock, kid. I mean it.", now - 25 * hour));
    threads.push(t);
  }
  // 4: group Afterlife Crew, owned by Judy.
  {
    const id = 4;
    const nums = ["555-0142", ME.number, "555-0105", "555-0164"];
    const t: MockThread = { id, kind: "group", title: "Afterlife Crew", members: nums.map((n, i) => member(n, i === 0)), messages: [], unread: 0 };
    t.messages.push(mk(id, "", "Judy Alvarez created the group", now - 50 * hour, "system"));
    t.messages.push(mk(id, "555-0164", "Gig tonight at the Rainbow Cadenza. Be there.", now - 49 * hour));
    t.messages.push(mk(id, "555-0105", "I do not attend concerts.", now - 48.8 * hour));
    t.messages.push(mk(id, "555-0142", "You do now.", now - 48.7 * hour));
    t.messages.push(mk(id, ME.number, "I'll save you a seat, Goro.", now - 48.5 * hour));
    t.messages.push(mk(id, "", "Goro Takemura renamed the group to \"Afterlife Crew\"", now - 47 * hour, "system"));
    threads.push(t);
  }

  const summary = (t: MockThread): ThreadSummary => {
    const last = t.messages[t.messages.length - 1];
    const meMember = t.members.find((m) => m.isMe);
    return {
      id: t.id, kind: t.kind, title: t.title, members: t.members.map((m) => ({ ...m })),
      last: last ? { body: last.body, sender: last.kind === "system" ? "" : last.sender.name, at: last.at, mine: last.mine, kind: last.kind } : null,
      unread: t.unread, updatedAt: last?.at ?? now, isOwner: !!meMember?.owner,
    };
  };
  const summaries = () => threads.map(summary).sort((a, b) => b.updatedAt - a.updatedAt);

  let recents: Recent[] = [
    { id: 1, number: "555-0199", name: "Panam Palmer", direction: "in", status: "missed", at: now - 11 * min, duration: 0 },
    { id: 2, number: "555-0142", name: "Judy Alvarez", direction: "out", status: "answered", at: now - 2 * hour, duration: 192 },
    { id: 3, number: "555-0131", name: "555-0131", direction: "in", status: "declined", at: now - 5 * hour, duration: 0 },
    { id: 4, number: "555-0168", name: "River Ward", direction: "out", status: "unavailable", at: now - 9 * hour, duration: 0 },
    { id: 5, number: "555-0110", name: "Viktor Vektor", direction: "in", status: "answered", at: now - 26 * hour, duration: 431 },
    { id: 6, number: "555-0123", name: "Misty Olszewski", direction: "in", status: "missed", at: now - 28 * hour, duration: 0 },
    { id: 7, number: "555-0105", name: "Goro Takemura", direction: "out", status: "busy", at: now - 52 * hour, duration: 0 },
  ];
  const addRecent = (number: string, direction: "in" | "out", status: Recent["status"], duration = 0) => {
    recents = [{ id: nextRecentId++, number, name: nameOf(number), direction, status, at: Date.now(), duration }, ...recents].slice(0, 60);
    fire("nl:patch", { recents });
  };

  const apps = [
    { id: "delamain", label: "Delamain Cab", icon: "car-taxi-front", color: "#f5a623" },
    { id: "bank", label: "NC Bank", icon: "landmark", color: "#38d39f" },
  ];

  const state = (ready: boolean): State => ({
    ready,
    line: ready ? { number: ME.number, name: ME.name } : null,
    settings,
    contacts,
    threads: ready ? summaries() : [],
    recents: ready ? recents : [],
    apps: ready ? apps : [],
    call: ready ? call : null,
    social: ready ? { handle: citizens[ME_ID]!.handle, unread: unreadPings() } : null,
    implant: { ...implant },
  });

  /* ---------------------------------------------------------- calls */

  let call: CallState | null = null;
  const callTimers: number[] = [];
  let talkTimer: number | undefined;
  const levels: Record<string, number> = {};
  const clearCallTimers = () => { while (callTimers.length) window.clearTimeout(callTimers.pop()); };
  const meP = (state: CallParticipant["state"] = "connected"): CallParticipant => ({ lineId: ME.lineId, number: ME.number, name: ME.name, state, muted: false, isMe: true });
  const otherP = (number: string, state: CallParticipant["state"]): CallParticipant => ({ lineId: `L-${number.slice(-4)}`, number, name: nameOf(number), state, muted: false, isMe: false });
  const pushCall = () => {
    if (call) {
      const connected = call.participants.filter((p) => p.state === "connected").length;
      if (call.phase !== "incoming" && connected >= 2 && call.startedAt == null) call.startedAt = Date.now();
      if (call.phase === "outgoing" && connected >= 2) call.phase = "active";
      call.canAdd = call.phase === "active" && call.participants.filter((p) => p.state !== "left").length < 6;
    }
    fire("nl:call", call);
  };
  const endCall = (reason: CallEndReason, number?: string, name?: string) => {
    clearCallTimers();
    const dur = call?.startedAt ? Math.round((Date.now() - call.startedAt) / 1000) : undefined;
    const other = call?.participants.find((p) => !p.isMe);
    call = null;
    window.clearInterval(talkTimer); talkTimer = undefined;
    fire("nl:call", null);
    fire("nl:callEnded", { reason, number: number ?? other?.number, name: name ?? (number ? nameOf(number) : other?.name), duration: dur });
  };
  const startTalkers = () => {
    if (talkTimer) return;
    talkTimer = window.setInterval(() => {
      if (!call || call.phase !== "active") return;
      const out: Record<string, number> = {};
      for (const p of call.participants) {
        if (p.state !== "connected") continue;
        if (p.isMe && call.muted) continue;
        const prev = levels[p.lineId] ?? 0;
        const speaking = Math.sin(Date.now() / (p.isMe ? 2100 : 1300 + p.lineId.charCodeAt(5) * 40)) > (p.isMe ? 0.55 : 0.2);
        const target = speaking ? 0.3 + Math.random() * 0.7 : 0;
        const v = prev * 0.45 + target * 0.55;
        levels[p.lineId] = v;
        if (v > 0.04) out[p.lineId] = Math.round(v * 100) / 100;
      }
      fire("nl:talkers", out);
    }, 125);
  };
  const ringOut = (numbers: string[], group: CallState["group"]) => {
    call = { id: nextCallId++, phase: "outgoing", startedAt: null, muted: false, group, participants: [meP(), ...numbers.map((n) => otherP(n, "ringing"))], canAdd: false };
    pushCall();
    numbers.forEach((n, i) => {
      callTimers.push(window.setTimeout(() => {
        if (!call) return;
        const p = call.participants.find((x) => x.number === n);
        if (!p) return;
        const dir = DIRECTORY[n];
        if (!dir?.online || dir.busy) {
          if (!group) { addRecent(n, "out", dir?.busy ? "busy" : "unavailable"); endCall(dir?.busy ? "busy" : "unavailable", n); return; }
          p.state = "left";
        } else {
          p.state = "connected";
          if (!group) addRecent(n, "out", "answered");
        }
        if (group && call.participants.every((x) => x.isMe || x.state === "left")) { endCall("no_answer"); return; }
        pushCall();
        if (call?.phase === "active") startTalkers();
      }, 2400 + i * 900));
    });
  };
  const ringIn = (fromNumber: string, group?: { threadId: number }) => {
    if (call) return;
    const t = group ? threads.find((x) => x.id === group.threadId) : undefined;
    const others = t ? t.members.filter((m) => !m.isMe).map((m) => m.number) : [fromNumber];
    call = {
      id: nextCallId++, phase: "incoming", startedAt: null, muted: false,
      group: t ? { threadId: t.id, title: t.title } : null,
      participants: [meP("ringing"), ...others.map((n) => otherP(n, n === fromNumber ? "connected" : "ringing"))],
      canAdd: false,
    };
    pushCall();
    callTimers.push(window.setTimeout(() => {
      if (call?.phase !== "incoming") return;
      addRecent(fromNumber, "in", "missed");
      fire("nl:toast", { id: `missed-${Date.now()}`, kind: "missed", title: "Missed call", body: nameOf(fromNumber), number: fromNumber, at: Date.now() } satisfies ToastPayload);
      endCall("missed", fromNumber);
    }, 30_000));
  };

  /* ------------------------------------------------------- messages */

  const pushMessage = (t: MockThread, m: Message) => {
    t.messages.push(m);
    fire("nl:message", { message: m, summary: summary(t) });
  };
  const incomingText = (threadId?: number) => {
    const t = threads.find((x) => x.id === (threadId ?? 1)) ?? threads[0]!;
    const from = t.members.filter((m) => !m.isMe)[Math.floor(Math.random() * (t.members.length - 1))] ?? t.members[0]!;
    t.unread += 1;
    const m = mk(t.id, from.number, REPLIES[Math.floor(Math.random() * REPLIES.length)]!, Date.now());
    pushMessage(t, m);
    fire("nl:toast", { id: `msg-${m.id}`, kind: "message", title: t.kind === "group" ? `${from.name} · ${t.title}` : from.name, body: m.body, threadId: t.id, at: m.at } satisfies ToastPayload);
  };

  /* ------------------------------------------------------- screamsheet */

  interface Citizen { handle: string; name: string; seed: string; online: boolean; bio: string; joinedAt: number; followersBase: number; credBase: number }
  interface MockPost { id: number; by: string; body: string; at: number; district: string | null; replyTo: number | null; echoOf: number | null; cred: Set<string>; credBase: number; echoBase: number; deleted?: boolean }

  const day = 24 * hour;
  const citizens: Record<string, Citizen> = {
    me: { handle: "yuki_t", name: ME.name, seed: ME.number, online: true, bio: "Netrunner for hire. Kabuki noodle critic. #kabuki", joinedAt: now - 41 * day, followersBase: 37, credBase: 112 },
    judy: { handle: "judy_a", name: "Judy Alvarez", seed: "555-0142", online: true, bio: "BD editor. Laguna Bend forever. Mox till I die. #braindance", joinedAt: now - 380 * day, followersBase: 2840, credBase: 9120 },
    panam: { handle: "panam", name: "Panam Palmer", seed: "555-0199", online: true, bio: "Aldecaldos. Badlands born. Don't call me princess.", joinedAt: now - 300 * day, followersBase: 1960, credBase: 6400 },
    vik: { handle: "vik_vektor", name: "Viktor Vektor", seed: "555-0110", online: false, bio: "Ripperdoc, Little China. Walk-ins welcome, gonks not. #ripperdoc", joinedAt: now - 520 * day, followersBase: 3310, credBase: 7020 },
    misty: { handle: "misty", name: "Misty Olszewski", seed: "555-0123", online: true, bio: "Esoterica, next to Vik's. The cards never lie. People do.", joinedAt: now - 410 * day, followersBase: 1210, credBase: 3980 },
    rogue: { handle: "rogue_amendiares", name: "Rogue Amendiares", seed: "rogue-afterlife", online: true, bio: "Queen of the #afterlife. If you have to ask the price, you can't afford the gig.", joinedAt: now - 700 * day, followersBase: 8800, credBase: 20400 },
    ncpd: { handle: "ncpd_watch", name: "NCPD Watch", seed: "ncpd-scanner", online: true, bio: "Unofficial scanner feed. Not affiliated with NCPD. Stay safe, Night City.", joinedAt: now - 640 * day, followersBase: 15400, credBase: 31800 },
    river: { handle: "river_w", name: "River Ward", seed: "555-0168", online: false, bio: "Ex-NCPD detective. Now just a guy with a truck and a conscience.", joinedAt: now - 210 * day, followersBase: 640, credBase: 1890 },
    kerry: { handle: "kerry_eurodyne", name: "Kerry Eurodyne", seed: "555-0164", online: true, bio: "Samurai. Solo. Still loud. #samurai", joinedAt: now - 900 * day, followersBase: 42100, credBase: 88800 },
  };
  const ME_ID = "me";
  const follows = new Set(["me>judy", "me>panam", "me>misty", "me>rogue", "judy>me", "panam>me", "vik>me", "river>me", "kerry>me", "judy>panam", "misty>vik"]);

  let nextPostId = 5000;
  const posts: MockPost[] = [];
  const add = (by: string, ago: number, district: string | null, body: string, o: { replyTo?: number; echoOf?: number; cred?: string[]; credBase?: number; echoBase?: number } = {}) => {
    const p: MockPost = { id: nextPostId++, by, body, at: now - ago, district, replyTo: o.replyTo ?? null, echoOf: o.echoOf ?? null, cred: new Set(o.cred ?? []), credBase: o.credBase ?? 0, echoBase: o.echoBase ?? 0 };
    posts.push(p);
    return p.id;
  };
  add("ncpd", 29 * hour, "Northside", "Scanner chatter: #maxtac rolling into Northside. Cyberpsycho reported near the H10 loading docks. Stay inside.", { credBase: 140, echoBase: 31 });
  const p2 = add("judy", 27 * hour, "Japantown", "Anyone else find Lizzie's new #braindance batch... off? The edits are wrong. Somebody's been tampering.", { credBase: 88, echoBase: 6, cred: ["misty"] });
  add("misty", 26.6 * hour, "Japantown", "@judy_a the cards showed the Tower reversed this morning. Be careful what you dive into.", { replyTo: p2, credBase: 12 });
  const p4 = add("vik", 26 * hour, "Little China", "PSA: if your Kiroshi optics start showing ads in your dreams, that's not a feature. Come see me. #ripperdoc", { credBase: 210, echoBase: 18 });
  const p5 = add("rogue", 25 * hour, "Watson", "New gig board is up at the #afterlife. Serious edgerunners only. Leave the tourists at the door.", { credBase: 320, echoBase: 44, cred: ["me"] });
  add("panam", 23.5 * hour, "Badlands", "Sandstorm over the Badlands tonight. Convoy waits till dawn. If you're on Route 66, find cover. #badlands", { credBase: 64, echoBase: 5 });
  add("river", 23 * hour, "Heywood", "Kids are racing again under the Heywood overpass. Somebody's gonna get flatlined. #heywood", { credBase: 23 });
  add("ncpd", 22 * hour, "Pacifica", "Voodoo Boys blackout in #pacifica: grid down from the Grand Imperial Mall to the coast. Avoid West Wind Estate.", { credBase: 180, echoBase: 27 });
  add("judy", 21 * hour, "Japantown", "", { echoOf: p5 });
  add("kerry", 20 * hour, "City Center", "Playing a surprise set at the Rainbow Cadenza. Bring earplugs or don't. #samurai", { credBase: 1240, echoBase: 210 });
  const p11 = add("me", 19 * hour, "Kabuki", "Just ate the worst noodles of my life at a Kabuki stand. 10/10, would get food poisoning again. #kabuki", { credBase: 9, cred: ["judy", "vik"] });
  const p12 = add("judy", 18.8 * hour, "Kabuki", "@yuki_t the one by the canal? Rookie mistake, choom.", { replyTo: p11, credBase: 4, cred: ["me"] });
  add("me", 18.6 * hour, "Kabuki", "@judy_a the canal one. My stomach is filing a complaint with #arasaka HR.", { replyTo: p12, credBase: 6, cred: ["rogue"] });
  const p14 = add("ncpd", 18 * hour, "Corpo Plaza", "Heavy #arasaka security at Corpo Plaza. Roads closed around the tower. Rumour says a board meeting went sideways.", { credBase: 410, echoBase: 63 });
  add("rogue", 17.5 * hour, "Watson", "Sideways is one word for it. Anyone with intel, you know where to find me.", { echoOf: p14, credBase: 190, echoBase: 12 });
  add("misty", 16 * hour, "Japantown", "Reading cards tonight at Esoterica. Walk-ins only. No, I can't tell you if your ex is coming back.", { credBase: 57 });
  const p17 = add("vik", 15 * hour, "Little China", "#trauma_team platinum doesn't cover stupidity. Ask me how I know.", { credBase: 260, echoBase: 22 });
  add("panam", 14 * hour, "Badlands", "", { echoOf: p17 });
  add("river", 13 * hour, "Santo Domingo", "Arroyo factories pumping something weird into the air again. Santo Domingo smells like burnt plastic.", { credBase: 33, echoBase: 2 });
  const p20 = add("judy", 12 * hour, "Northside", "Clouds dolls are protesting outside the Mox tonight. If you care about workers in this city, show up. #northside", { credBase: 150, echoBase: 19, cred: ["me", "panam"] });
  add("panam", 11.8 * hour, "Badlands", "@judy_a I'll bring the Thorton. And friends.", { replyTo: p20, credBase: 30 });
  add("me", 11.5 * hour, "Watson", "", { echoOf: p20 });
  add("ncpd", 10 * hour, "Rancho Coronado", "Multi-car pileup on the Rancho Coronado interchange. #trauma_team AV on site. Expect delays.", { credBase: 75, echoBase: 14 });
  add("kerry", 9 * hour, "Westbrook", "Somebody in North Oak keeps stealing my koi. I know it's you, Rich.", { credBase: 2210, echoBase: 340 });
  const p24 = add("me", 8 * hour, "The Glen", "The Glen market had real oranges today. REAL ONES. Paid 300 eddies and I'm not sorry.", { credBase: 14, cred: ["judy", "panam", "misty"] });
  add("rogue", 7 * hour, "Vista del Rey", "Valentinos are celebrating in Vista del Rey. Fireworks, chrome, and nobody's paying for drinks.", { credBase: 140, echoBase: 9 });
  add("misty", 6 * hour, "Little China", "Vik fixed my optics last week. Now I only see ads when I'm awake. Progress. #ripperdoc", { echoOf: p4, credBase: 61, echoBase: 3 });
  add("misty", 5 * hour, "Japantown", "@yuki_t the oranges are a sign. Of what, I won't say.", { echoOf: p24, credBase: 11 });
  const p27 = add("ncpd", 4 * hour, "Watson", "#maxtac unit spotted again near Kabuki market. Third time this week. What's going on in Watson?", { credBase: 230, echoBase: 41 });
  add("river", 3.5 * hour, "Heywood", "@yuki_t still owe you for the Heywood job. Drinks at Lizzie's?", { credBase: 3 });
  add("judy", 3 * hour, "Kabuki", "", { echoOf: p27 });
  add("panam", 2 * hour, "Badlands", "Dawn convoy made it through. Aldecaldos don't break. #badlands #aldecaldos", { credBase: 96, echoBase: 8, cred: ["me"] });
  add("vik", 1.2 * hour, "Little China", "Clinic's closed tomorrow. Even ripperdocs need sleep. Emergencies go to #trauma_team, if you can afford them.", { credBase: 48, echoBase: 4 });
  add("river", 50 * min, "Watson", "@ncpd_watch heard the same over the old frequencies. Something big is brewing.", { replyTo: p27, credBase: 18 });
  add("misty", 25 * min, "Japantown", "Full moon tonight. Good night for a reading, bad night for a #braindance.", { credBase: 22 });
  add("rogue", 12 * min, "Watson", "Afterlife's open late. First drink's on the house for anyone who brings me a working Militech chip. #afterlife", { credBase: 77, echoBase: 6 });
  add("kerry", 5 * min, "City Center", "New track drops at midnight. It's loud. It's angry. It's about #arasaka.", { credBase: 860, echoBase: 120 });

  const LIVE_LINES: [string, string][] = [
    ["Kabuki", "Night market's packed. Somebody's selling counterfeit Kiroshis again. #kabuki"],
    ["Watson", "#maxtac AV just flew over Watson, low. Lights off, everyone."],
    ["Japantown", "Tyger Claws closed Jig-Jig Street for a 'private event'. Sure."],
    ["Pacifica", "Grid's back in #pacifica. For now."],
    ["Corpo Plaza", "Saw an #arasaka exec cry in the Corpo Plaza fountain. Best day of my life."],
    ["Heywood", "Valentinos throwing a street party in Heywood. Bring your own chrome."],
    ["City Center", "Traffic on the City Center loop is a war crime. #trauma_team stuck in it too."],
    ["Arroyo", "Arroyo smells like ozone and bad decisions tonight."],
    ["Westbrook", "Charter Hill rents went up again. Guess I live in my car now."],
    ["The Glen", "Ran into a Netwatch agent at a Glen noodle bar. He tipped well. Suspicious."],
  ];

  const cit = (id: string) => citizens[id] ?? citizens[ME_ID]!;
  const idOfHandle = (h: string) => Object.keys(citizens).find((k) => citizens[k]!.handle === h);
  const author = (id: string): SocialAuthor => { const c = cit(id); return { handle: c.handle, name: c.name, seed: c.seed, online: c.online }; };
  const alive = () => posts.filter((p) => !p.deleted);
  const findPost = (id: unknown) => posts.find((p) => p.id === id && !p.deleted);

  const hydrate = (p: MockPost, depth = 0): SocialPost => {
    const orig = p.echoOf != null ? posts.find((x) => x.id === p.echoOf) : undefined;
    const parent = p.replyTo != null ? posts.find((x) => x.id === p.replyTo) : undefined;
    const refs = alive().filter((x) => x.echoOf === p.id);
    return {
      id: p.id, author: author(p.by), body: p.body, at: p.at, district: p.district,
      replyTo: parent ? { id: parent.id, handle: cit(parent.by).handle } : null,
      echoOf: orig && !orig.deleted && depth === 0 ? hydrate(orig, 1) : null,
      echoGone: p.echoOf != null && (!orig || !!orig.deleted) ? true : undefined,
      replies: alive().filter((x) => x.replyTo === p.id).length,
      echoes: p.echoBase + refs.length,
      cred: p.credBase + p.cred.size,
      credded: p.cred.has(ME_ID),
      echoed: refs.some((x) => x.by === ME_ID && !x.body),
      mine: p.by === ME_ID,
    };
  };
  const profileOf = (id: string): SocialProfile => {
    const c = cit(id);
    const mineAll = alive().filter((p) => p.by === id);
    return {
      ...author(id), bio: c.bio, joinedAt: c.joinedAt,
      posts: mineAll.filter((p) => p.body).length,
      followers: c.followersBase + [...follows].filter((f) => f.endsWith(`>${id}`)).length,
      following: [...follows].filter((f) => f.startsWith(`${id}>`)).length + (id === ME_ID ? 0 : 40 + (c.joinedAt % 90)),
      cred: c.credBase + mineAll.reduce((n, p) => n + p.cred.size, 0),
      isMe: id === ME_ID, followed: follows.has(`${ME_ID}>${id}`), followsMe: follows.has(`${id}>${ME_ID}`),
    };
  };
  /** Newest first by id, or in the given order, from after `beforeId`. */
  const pageOf = <T extends { id: number }>(list: T[], beforeId: unknown, size: number) => {
    let start = 0;
    if (typeof beforeId === "number") {
      const i = list.findIndex((x) => x.id === beforeId);
      start = i >= 0 ? i + 1 : list.findIndex((x) => x.id < beforeId);
      if (start < 0) start = list.length;
    }
    const items = list.slice(start, start + size);
    return { items, hasMore: start + size < list.length };
  };
  const statsOf = (id: number) => {
    const p = posts.find((x) => x.id === id);
    if (!p) return;
    const h = hydrate(p);
    fire("nl:social", { kind: "stats", postId: id, cred: h.cred, echoes: h.echoes, replies: h.replies } satisfies SocialLive, 60);
  };

  let nextPingId = 900;
  const PING_TEXT: Record<SocialPingKind, string> = {
    cred: "gave you Street Cred", echo: "echoed your scream", quote: "quoted your scream", reply: "replied to you", mention: "mentioned you", follow: "started following you",
  };
  const pings: SocialPing[] = [];
  const seedPing = (kind: SocialPingKind, by: string, postId: number | null, ago: number, read: boolean) => {
    const p = postId != null ? posts.find((x) => x.id === postId) : undefined;
    pings.push({ id: nextPingId++, kind, actor: author(by), post: p ? { id: p.id, body: p.body } : null, at: now - ago, read });
  };
  {
    const byBody = (start: string) => posts.find((p) => p.body.startsWith(start))?.id ?? null;
    seedPing("follow", "river", null, 9 * day, true);
    for (let i = 0; i < 12; i++) seedPing("cred", ["judy", "panam", "vik", "misty", "rogue", "kerry"][i % 6]!, p11, 18 * hour - i * 4 * min, true);
    seedPing("cred", "rogue", byBody("@judy_a the canal"), 17 * hour, true);
    seedPing("reply", "judy", p12, 18.8 * hour, true);
    seedPing("quote", "misty", byBody("@yuki_t the oranges"), 5 * hour, false);
    seedPing("mention", "river", byBody("@yuki_t still owe"), 3.5 * hour, false);
    seedPing("echo", "panam", p24, 2 * hour, false);
    seedPing("follow", "kerry", null, 1 * hour, false);
    seedPing("cred", "judy", p24, 30 * min, false);
    pings.sort((a, b) => b.at - a.at);
  }
  const unreadPings = () => pings.filter((p) => !p.read).length;
  const ping = (kind: SocialPingKind, by: string, postId: number | null) => {
    const p = postId != null ? posts.find((x) => x.id === postId) : undefined;
    const item: SocialPing = { id: nextPingId++, kind, actor: author(by), post: p ? { id: p.id, body: p.body } : null, at: Date.now(), read: false };
    pings.unshift(item);
    fire("nl:social", { kind: "ping", ping: item, unread: unreadPings() } satisfies SocialLive);
    fire("nl:toast", {
      id: `soc-${item.id}`, kind: "social", title: `${item.actor.name} @${item.actor.handle}`, body: `${PING_TEXT[kind]}${p?.body ? `: "${p.body.slice(0, 60)}"` : ""}`,
      postId: kind === "follow" ? undefined : p?.id, handle: kind === "follow" ? item.actor.handle : undefined, at: item.at,
    } satisfies ToastPayload, 40);
  };
  const others = () => Object.keys(citizens).filter((k) => k !== ME_ID);
  const pick = <T,>(list: T[]): T => list[Math.floor(Math.random() * list.length)]!;
  const district = () => params.get("district") ?? "Kabuki";

  const liveScream = () => {
    const [where, body] = pick(LIVE_LINES);
    const p: MockPost = { id: nextPostId++, by: pick(others()), body, at: Date.now(), district: where, replyTo: null, echoOf: null, cred: new Set(), credBase: Math.floor(Math.random() * 30), echoBase: 0 };
    posts.push(p);
    fire("nl:social", { kind: "post", post: hydrate(p) } satisfies SocialLive);
  };
  const livePing = () => {
    const mine = alive().filter((p) => p.by === ME_ID && p.body);
    const target = pick(mine);
    const by = pick(others());
    if (!target) { ping("follow", by, null); return; }
    target.cred.add(by);
    statsOf(target.id);
    ping("cred", by, target.id);
  };

  const BASE_DISTRICTS: Record<string, number> = {
    Watson: 48, Kabuki: 41, "City Center": 37, Japantown: 33, Heywood: 27, Pacifica: 22, "Little China": 19, Northside: 17,
    "Corpo Plaza": 15, "Vista del Rey": 12, "The Glen": 11, "Santo Domingo": 9, Westbrook: 8, Arroyo: 6, "Rancho Coronado": 5, Badlands: 4,
  };
  const BASE_TAGS: Record<string, number> = { arasaka: 38, afterlife: 26, maxtac: 22, trauma_team: 19, braindance: 15, pacifica: 12, kabuki: 9, ripperdoc: 8, badlands: 7, samurai: 6, northside: 4, aldecaldos: 3 };
  const heat = (): SocialHeat => {
    const since = Date.now() - day;
    const recent = alive().filter((p) => p.at >= since);
    const d: Record<string, number> = { ...BASE_DISTRICTS };
    const t: Record<string, number> = { ...BASE_TAGS };
    for (const p of recent) {
      if (p.district) d[p.district] = (d[p.district] ?? 0) + 1;
      for (const m of p.body.matchAll(/#([a-z0-9_]+)/gi)) { const k = m[1]!.toLowerCase(); t[k] = (t[k] ?? 0) + 1; }
    }
    return {
      districts: Object.entries(d).map(([district, count]) => ({ district, count })).sort((a, b) => b.count - a.count),
      tags: Object.entries(t).map(([tag, count]) => ({ tag, count })).sort((a, b) => b.count - a.count),
      hot: hotList().slice(0, 6).map((p) => hydrate(p)),
    };
  };
  const hotList = () => {
    const since = Date.now() - day;
    const score = (p: MockPost) => { const h = hydrate(p); return h.cred + h.echoes * 2; };
    return alive().filter((p) => p.at >= since && p.replyTo == null && p.body).sort((a, b) => score(b) - score(a));
  };
  const timeline = () => alive().filter((p) => p.replyTo == null).sort((a, b) => b.id - a.id);
  const validBody = (b: unknown) => { const s = String(b ?? "").trim(); if (s.length < 1 || s.length > SCREAM_MAX) fail("invalid_body"); return s; };

  /* ---------------------------------------------------------- requests */

  type Handler = (args: Record<string, unknown>) => unknown | Promise<unknown>;
  const fail = (reason: string): never => { throw new Error(reason); };
  const thread = (id: unknown) => threads.find((t) => t.id === id) ?? fail("not_member");
  const validNumber = (n: unknown): string => (typeof n === "string" && NUMBER_RE.test(n) ? n : fail("invalid_number"));

  const ops: Record<RequestOp, Handler> = {
    "contacts.save": (a) => {
      const name = String(a.name ?? "").trim();
      if (name.length < 1 || name.length > 32) fail("invalid_name");
      const number = validNumber(a.number);
      if (number === ME.number) fail("self");
      let c = contacts.find((x) => x.id === a.id);
      if (c) { c.name = name; c.number = number; if (typeof a.favorite === "boolean") c.favorite = a.favorite; }
      else { c = { id: nextContactId++, name, number, favorite: !!a.favorite, online: !!DIRECTORY[number]?.online }; contacts.push(c); }
      for (const t of threads) {
        for (const m of t.members) if (m.number === number) m.name = name;
        if (t.kind === "direct" && t.members.some((m) => m.number === number)) t.title = name;
      }
      fire("nl:patch", { contacts, threads: summaries() }, 30);
      return { ...c };
    },
    "contacts.delete": (a) => {
      const i = contacts.findIndex((x) => x.id === a.id);
      if (i >= 0) contacts.splice(i, 1);
      fire("nl:patch", { contacts }, 30);
      return {};
    },
    "threads.open": (a) => {
      const t = thread(a.threadId);
      t.unread = 0;
      const msgs = t.messages.slice(-40);
      fire("nl:thread", { threadId: t.id, messages: msgs, members: t.members, hasMore: t.messages.length > msgs.length }, 180);
      fire("nl:patch", { threads: summaries() }, 200);
      return {};
    },
    "threads.more": (a) => {
      const t = thread(a.threadId);
      const older = t.messages.filter((m) => m.id < Number(a.beforeId));
      const page = older.slice(-40);
      fire("nl:thread", { threadId: t.id, messages: page, members: t.members, hasMore: older.length > page.length, prepend: true }, 450);
      return {};
    },
    "threads.direct": (a) => {
      const number = validNumber(a.number);
      if (number === ME.number) fail("self");
      if (!DIRECTORY[number]) fail("unknown_number");
      let t = threads.find((x) => x.kind === "direct" && x.members.some((m) => m.number === number));
      if (!t) {
        t = { id: nextThreadId++, kind: "direct", title: nameOf(number), members: [member(ME.number), member(number)], messages: [], unread: 0 };
        threads.push(t);
        fire("nl:patch", { threads: summaries() });
      }
      return { threadId: t.id };
    },
    "threads.read": (a) => { const t = thread(a.threadId); t.unread = 0; return {}; },
    "messages.send": (a) => {
      const t = thread(a.threadId);
      const body = String(a.body ?? "");
      if (body.trim().length < 1 || body.length > 500) fail("invalid_body");
      if (body.trim().toLowerCase() === "/fail") fail("rate_limited");
      const m = mk(t.id, ME.number, body, Date.now());
      window.setTimeout(() => pushMessage(t, m), 140);
      // A reply from someone online, a little later.
      const others = t.members.filter((x) => !x.isMe && x.online);
      if (others.length) {
        window.setTimeout(() => {
          const from = others[Math.floor(Math.random() * others.length)]!;
          const r = mk(t.id, from.number, REPLIES[Math.floor(Math.random() * REPLIES.length)]!, Date.now());
          if (!open) t.unread += 1;
          pushMessage(t, r);
          if (!open) fire("nl:toast", { id: `msg-${r.id}`, kind: "message", title: from.name, body: r.body, threadId: t.id, at: r.at } satisfies ToastPayload);
        }, 2200 + Math.random() * 1500);
      }
      return { id: m.id };
    },
    "groups.create": (a) => {
      const title = String(a.title ?? "").trim();
      if (title.length < 1 || title.length > 32) fail("invalid_name");
      const numbers = Array.isArray(a.numbers) ? [...new Set(a.numbers.map(validNumber))] : [];
      if (numbers.includes(ME.number)) fail("self");
      if (numbers.length < 2) fail("invalid_number");
      if (numbers.length > 15) fail("group_full");
      for (const n of numbers) if (!DIRECTORY[n]) fail("unknown_number");
      const t: MockThread = { id: nextThreadId++, kind: "group", title, members: [member(ME.number, true), ...numbers.map((n) => member(n))], messages: [], unread: 0 };
      t.messages.push(mk(t.id, "", `${ME.name} created the group`, Date.now(), "system"));
      threads.push(t);
      fire("nl:patch", { threads: summaries() });
      return { threadId: t.id };
    },
    "groups.rename": (a) => {
      const t = thread(a.threadId);
      const title = String(a.title ?? "").trim();
      if (title.length < 1 || title.length > 32) fail("invalid_name");
      t.title = title;
      pushMessage(t, mk(t.id, "", `${ME.name} renamed the group to "${title}"`, Date.now(), "system"));
      return {};
    },
    "groups.add": (a) => {
      const t = thread(a.threadId);
      const number = validNumber(a.number);
      if (!DIRECTORY[number]) fail("unknown_number");
      if (t.members.length >= 16) fail("group_full");
      if (t.members.some((m) => m.number === number)) return {};
      t.members.push(member(number));
      pushMessage(t, mk(t.id, "", `${ME.name} added ${nameOf(number)}`, Date.now(), "system"));
      fire("nl:thread", { threadId: t.id, messages: t.messages.slice(-40), members: t.members, hasMore: t.messages.length > 40 }, 60);
      return {};
    },
    "groups.remove": (a) => {
      const t = thread(a.threadId);
      if (!t.members.find((m) => m.isMe)?.owner) fail("not_owner");
      const number = validNumber(a.number);
      t.members = t.members.filter((m) => m.number !== number);
      pushMessage(t, mk(t.id, "", `${ME.name} removed ${nameOf(number)}`, Date.now(), "system"));
      fire("nl:thread", { threadId: t.id, messages: t.messages.slice(-40), members: t.members, hasMore: t.messages.length > 40 }, 60);
      return {};
    },
    "groups.leave": (a) => {
      const t = thread(a.threadId);
      threads.splice(threads.indexOf(t), 1);
      fire("nl:patch", { threads: summaries() });
      return {};
    },
    "call.dial": (a) => {
      const number = validNumber(a.number);
      if (call) fail("in_call");
      if (number === ME.number) fail("self");
      if (!DIRECTORY[number]) fail("unknown_number");
      ringOut([number], null);
      return {};
    },
    "call.group": (a) => {
      if (call) fail("in_call");
      const t = thread(a.threadId);
      ringOut(t.members.filter((m) => !m.isMe).map((m) => m.number), { threadId: t.id, title: t.title });
      return {};
    },
    "call.accept": () => {
      if (!call || call.phase !== "incoming") return {};
      clearCallTimers();
      call.phase = "active";
      call.startedAt = Date.now();
      for (const p of call.participants) if (p.isMe || p.state === "connected") p.state = "connected";
      const caller = call.participants.find((p) => !p.isMe && p.state === "connected");
      if (caller) addRecent(caller.number, "in", "answered");
      // Group calls: the rest pick up one by one.
      call.participants.filter((p) => p.state === "ringing").forEach((p, i) => callTimers.push(window.setTimeout(() => {
        if (!call) return;
        p.state = DIRECTORY[p.number]?.online ? "connected" : "left";
        pushCall();
      }, 1500 + i * 1200)));
      pushCall();
      startTalkers();
      return {};
    },
    "call.decline": () => {
      if (!call) return {};
      const caller = call.participants.find((p) => !p.isMe);
      if (caller) addRecent(caller.number, "in", "declined");
      endCall("declined");
      return {};
    },
    "call.hangup": () => { if (call) endCall("hangup"); return {}; },
    "call.mute": (a) => {
      if (!call) return {};
      call.muted = !!a.muted;
      const me = call.participants.find((p) => p.isMe);
      if (me) me.muted = call.muted;
      pushCall();
      return {};
    },
    "call.add": (a) => {
      if (!call || call.phase !== "active") fail("unavailable");
      const number = validNumber(a.number);
      if (number === ME.number) fail("self");
      if (!DIRECTORY[number]) fail("unknown_number");
      if (call!.participants.filter((p) => p.state !== "left").length >= 6) fail("group_full");
      if (call!.participants.some((p) => p.number === number && p.state !== "left")) return {};
      call!.participants.push(otherP(number, "ringing"));
      pushCall();
      callTimers.push(window.setTimeout(() => {
        const p = call?.participants.find((x) => x.number === number);
        if (!p) return;
        p.state = DIRECTORY[number]?.online && !DIRECTORY[number]?.busy ? "connected" : "left";
        pushCall();
      }, 2600));
      return {};
    },
    "recents.clear": () => { recents = []; fire("nl:patch", { recents }, 20); return {}; },
    "settings.save": (a) => {
      Object.assign(settings, a);
      return { ...settings };
    },
    "implant.install": () => {
      if (implant.installed) return { implant: { ...implant } };
      if (!implant.selfInstall) fail("ripperdoc_required");
      // the real server takes a database write; the fresh state goes out before the reply, as in Lua
      return new Promise((resolve, reject) => window.setTimeout(() => {
        if (installFailsOnce) { installFailsOnce = false; reject(new Error("database_unavailable")); return; }
        implant.installed = true;
        implant.installedAt = Date.now();
        fire("nl:state", state(true));
        resolve({ implant: { ...implant } });
      }, 1500));
    },
    "apps.launch": (a) => {
      const app = apps.find((x) => x.id === a.id);
      fire("nl:toast", { id: `app-${Date.now()}`, kind: "info", title: app?.label ?? "App", body: app?.id === "delamain" ? "A cab is on its way to your location." : "Opening secure session...", at: Date.now() } satisfies ToastPayload, 200);
      if (app?.id === "delamain") { open = false; fire("nl:close", {}, 120); }
      return {};
    },
    "social.me": () => ({ profile: profileOf(ME_ID), unread: unreadPings() }),
    "social.feed": (a) => {
      const mode = a.mode === "crew" || a.mode === "hot" ? a.mode : "pulse";
      const list = mode === "hot" ? hotList()
        : mode === "crew" ? timeline().filter((p) => p.by === ME_ID || follows.has(`${ME_ID}>${p.by}`))
        : timeline();
      const { items, hasMore } = pageOf(list, a.beforeId, 10);
      return { posts: items.map((p) => hydrate(p)), hasMore };
    },
    "social.tag": (a) => {
      const tag = String(a.tag ?? "").replace(/^#/, "").toLowerCase();
      const re = new RegExp(`#${tag}(?![a-z0-9_])`, "i");
      const { items, hasMore } = pageOf(alive().filter((p) => re.test(p.body)).sort((x, y) => y.id - x.id), a.beforeId, 10);
      return { posts: items.map((p) => hydrate(p)), hasMore };
    },
    "social.post": (a) => {
      const body = validBody(a.body);
      if (body.toLowerCase() === "/fail") fail("rate_limited");
      const replyTo = a.replyTo != null ? findPost(a.replyTo) ?? fail("unknown_post") : undefined;
      const quoteOf = a.quoteOf != null ? findPost(a.quoteOf) ?? fail("unknown_post") : undefined;
      const p: MockPost = {
        id: nextPostId++, by: ME_ID, body, at: Date.now(), district: typeof a.district === "string" ? a.district : null,
        replyTo: replyTo?.id ?? null, echoOf: quoteOf?.id ?? null, cred: new Set(), credBase: 0, echoBase: 0,
      };
      posts.push(p);
      if (replyTo) statsOf(replyTo.id);
      if (quoteOf) statsOf(quoteOf.id);
      // Somebody in the crew always notices.
      window.setTimeout(() => {
        if (p.deleted) return;
        const by = pick(["judy", "panam", "misty", "rogue"]);
        p.cred.add(by);
        statsOf(p.id);
        ping("cred", by, p.id);
      }, 3000);
      return { post: hydrate(p) };
    },
    "social.echo": (a) => {
      const orig = findPost(a.postId) ?? fail("unknown_post");
      const mine = alive().find((p) => p.echoOf === orig.id && p.by === ME_ID && !p.body);
      if (mine) mine.deleted = true;
      else posts.push({ id: nextPostId++, by: ME_ID, body: "", at: Date.now(), district: typeof a.district === "string" ? a.district : null, replyTo: null, echoOf: orig.id, cred: new Set(), credBase: 0, echoBase: 0 });
      statsOf(orig.id);
      const h = hydrate(orig);
      return { echoed: h.echoed, echoes: h.echoes };
    },
    "social.cred": (a) => {
      const p = findPost(a.postId) ?? fail("unknown_post");
      if (p.cred.has(ME_ID)) p.cred.delete(ME_ID); else p.cred.add(ME_ID);
      statsOf(p.id);
      return { credded: p.cred.has(ME_ID), cred: p.credBase + p.cred.size };
    },
    "social.delete": (a) => {
      const p = findPost(a.postId) ?? fail("unknown_post");
      if (p.by !== ME_ID) fail("not_author");
      p.deleted = true;
      for (const e of posts) if (e.echoOf === p.id && !e.body) e.deleted = true;
      fire("nl:social", { kind: "deleted", postId: p.id } satisfies SocialLive, 40);
      if (p.replyTo != null) statsOf(p.replyTo);
      if (p.echoOf != null) statsOf(p.echoOf);
      return {};
    },
    "social.thread": (a) => {
      const p = findPost(a.postId) ?? fail("unknown_post");
      const parents: SocialPost[] = [];
      let up = p.replyTo != null ? findPost(p.replyTo) : undefined;
      while (up && parents.length < 20) { parents.unshift(hydrate(up)); up = up.replyTo != null ? findPost(up.replyTo) : undefined; }
      const replies = alive().filter((x) => x.replyTo === p.id).sort((x, y) => x.at - y.at).map((x) => hydrate(x));
      return { post: hydrate(p), parents, replies };
    },
    "social.profile": (a) => {
      const id = idOfHandle(String(a.handle ?? "")) ?? fail("unknown_handle");
      const { items, hasMore } = pageOf(timeline().filter((p) => p.by === id), a.beforeId, 10);
      return { profile: profileOf(id), posts: items.map((p) => hydrate(p)), hasMore };
    },
    "social.follow": (a) => {
      const id = idOfHandle(String(a.handle ?? "")) ?? fail("unknown_handle");
      if (id === ME_ID) fail("self");
      const key = `${ME_ID}>${id}`;
      if (a.follow) follows.add(key); else follows.delete(key);
      return { followed: follows.has(key), followers: profileOf(id).followers };
    },
    "social.update": (a) => {
      const me = citizens[ME_ID]!;
      if (a.handle !== undefined) {
        const h = String(a.handle);
        if (!HANDLE_RE.test(h)) fail("invalid_handle");
        if (h !== me.handle && idOfHandle(h)) fail("handle_taken");
        me.handle = h;
      }
      if (a.name !== undefined) {
        const n = String(a.name).trim();
        if (n.length < 1 || n.length > SOCIAL_NAME_MAX) fail("invalid_name");
        me.name = n;
      }
      if (a.bio !== undefined) {
        const b = String(a.bio).trim();
        if (b.length > BIO_MAX) fail("invalid_body");
        me.bio = b;
      }
      fire("nl:patch", { social: { handle: me.handle, unread: unreadPings() } }, 30);
      return { profile: profileOf(ME_ID) };
    },
    "social.search": (a) => {
      const q = String(a.q ?? "").trim().toLowerCase().replace(/^[#@]/, "");
      if (q.length < 1) return { profiles: [], posts: [] };
      const profiles = Object.keys(citizens).filter((k) => citizens[k]!.handle.includes(q) || citizens[k]!.name.toLowerCase().includes(q)).map(profileOf);
      const found = alive().filter((p) => p.body.toLowerCase().includes(q)).sort((x, y) => y.id - x.id).slice(0, 20).map((p) => hydrate(p));
      return { profiles, posts: found };
    },
    "social.heat": () => heat(),
    "social.pings": (a) => {
      const { items, hasMore } = pageOf(pings, a.beforeId, 15);
      const out = items.map((p) => ({ ...p }));
      if (a.beforeId == null) for (const p of pings) p.read = true;
      return { pings: out, hasMore };
    },
    "social.report": (a) => { findPost(a.postId) ?? fail("unknown_post"); return {}; },
  };

  /* ------------------------------------------------------------ bridge */

  const bridge: Open77Bridge = {
    on(name, fn) {
      let s = handlers.get(name);
      if (!s) { s = new Set(); handlers.set(name, s); }
      s.add(fn);
    },
    off(name, fn) { handlers.get(name)?.delete(fn); },
    emit(name, payload) {
      if (name === "nl:close") { open = false; fire("nl:close", {}); }
      else if (name === "nl:typing") fire("nl:focus", { keyboard: !!(payload as { active?: boolean })?.active }, 20);
      else if (name === "nl:sound") console.debug("[mock] nl:sound", payload);
    },
    invoke(name, payload) {
      return new Promise((resolve, reject) => {
        window.setTimeout(() => {
          if (name !== "nl:request") { reject(new Error("unknown_event")); return; }
          const { op, args } = (payload ?? {}) as { op: RequestOp; args?: Record<string, unknown> };
          const fn = ops[op];
          if (!fn) { reject(new Error("unknown_op")); return; }
          if (op !== "implant.install" && !implant.installed) { reject(new Error("not_installed")); return; }
          const failed = (err: unknown) => reject(err instanceof Error ? err : new Error(String(err)));
          try { Promise.resolve(fn(args ?? {})).then((data) => resolve({ ok: true, data }), failed); }
          catch (err) { failed(err); }
        }, 90 + Math.random() * 120);
      });
    },
    ready() {
      const sync = params.get("sync") === "1";
      fire("nl:state", state(!sync), 120);
      if (sync) window.setTimeout(() => fire("nl:state", state(true)), 3200);
      const tick = () => {
        const d = new Date();
        const h = (d.getHours() + 21) % 24; // Night City runs a few hours off
        fire("nl:clock", { hours: h, minutes: d.getMinutes(), weather: h >= 20 || h < 5 ? "Light rain" : "Clear", district: district() });
      };
      tick();
      window.setInterval(tick, 10_000);

      if (params.get("open") === "1") {
        const thread = params.get("thread");
        window.setTimeout(() => {
          open = true;
          fire("nl:open", { app: params.get("app") ?? undefined, threadId: thread ? Number(thread) : undefined, number: params.get("number") ?? undefined });
        }, 250);
      }
      const c = params.get("call");
      window.setTimeout(() => {
        if (c === "incoming") ringIn("555-0142");
        else if (c === "incoming-group") ringIn("555-0199", { threadId: 2 });
        else if (c === "outgoing") { ringOut(["555-0123"], null); clearCallTimers(); }
        else if (c === "active" || c === "group") {
          if (c === "group") ringOut(["555-0199", "555-0123", "555-0168"], { threadId: 2, title: "Aldecaldos Run" });
          else ringOut(["555-0142"], null);
          clearCallTimers();
          for (const p of call!.participants) p.state = p.number === "555-0168" ? "ringing" : "connected";
          call!.startedAt = Date.now() - 83_000;
          pushCall();
          startTalkers();
        }
      }, 400);
      if (params.get("toast") === "1") {
        fire("nl:toast", { id: "demo-1", kind: "message", title: "Panam Palmer · Aldecaldos Run", body: "Gas station on Route 66 in 30. Don't be late.", threadId: 2, at: Date.now() } satisfies ToastPayload, 600);
        fire("nl:toast", { id: "demo-2", kind: "missed", title: "Missed call", body: "Misty Olszewski", number: "555-0123", at: Date.now() } satisfies ToastPayload, 900);
        fire("nl:toast", { id: "demo-3", kind: "info", title: "Neural-Link", body: "Firmware 2.7.7 synchronised.", at: Date.now() } satisfies ToastPayload, 1200);
      }
      if (params.get("social") === "live") {
        let n = 0;
        window.setInterval(() => { if (n++ % 2) livePing(); else liveScream(); }, 20_000);
      }
      if (params.get("ended") === "1") fire("nl:callEnded", { reason: "hangup", number: "555-0142", name: "Judy Alvarez", duration: 187 }, 700);
    },
  };
  window.Open77 = bridge;

  const api = {
    open: (app?: string, threadId?: number) => { open = true; fire("nl:open", { app, threadId }); },
    close: () => { open = false; fire("nl:close", {}); },
    incoming: () => ringIn("555-0142"),
    incomingGroup: () => ringIn("555-0199", { threadId: 2 }),
    message: (threadId?: number) => incomingText(threadId),
    toast: (kind: ToastPayload["kind"] = "info") => fire("nl:toast", { id: `dev-${Date.now()}`, kind, title: kind === "error" ? "Link error" : "Neural-Link", body: kind === "error" ? "Signal lost near Pacifica." : "Night City Grid: traffic alert on Route 101.", at: Date.now() } satisfies ToastPayload),
    hangup: () => { if (call) endCall("dropped"); },
    scream: () => liveScream(),
    ping: () => livePing(),
    state: () => fire("nl:state", state(true)),
    /** Install (true) or remove (false) the implant, as a ripperdoc resource would. */
    implant: (on: boolean) => {
      implant.installed = on;
      implant.installedAt = on ? Date.now() : null;
      fire("nl:state", state(true));
    },
    isOpen: () => open,
  };
  (window as unknown as { nlMock: typeof api }).nlMock = api;
}

export type MockApi = {
  open(app?: string, threadId?: number): void; close(): void; incoming(): void; incomingGroup(): void;
  message(threadId?: number): void; toast(kind?: ToastPayload["kind"]): void; hangup(): void; scream(): void; ping(): void; state(): void;
  implant(on: boolean): void; isOpen(): boolean;
};
export const mockApi = (): MockApi | undefined => (window as unknown as { nlMock?: MockApi }).nlMock;
