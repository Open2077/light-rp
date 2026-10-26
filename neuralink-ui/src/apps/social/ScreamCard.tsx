/* One scream: author line with district stamp, highlighted body, echo / reply /
   quote context and the action row (reply, echo, Street Cred with its chrome
   burst, "…" menu). Plain echoes show the original under an "echoed" header
   and act on it. */
import { useEffect, useRef, useState, type CSSProperties, type MouseEvent, type RefObject } from "react";
import { Ellipsis, Flag, MapPin, MessageCircle, Quote, Repeat2, Trash2, Zap } from "lucide-react";
import { useStore, usePostLive } from "@/store/store";
import { HANDLE_RE, type SocialAuthor, type SocialPost } from "@/bridge/protocol";
import { Avatar } from "@/components/ui";
import { composeOn, deleteScream, openProfile, openScream, openTag, reportScream, toggleCred, toggleEcho } from "@/store/actions";
import { dayLabel, hhmm, relative } from "@/lib/format";
import { play } from "@/fx/sound";

const TOKEN_RE = /([#@][A-Za-z0-9_]+)/g;
const REPORT_REASONS = ["Spam", "Harassment", "Doxxing", "Impersonation"];

export function countLabel(n: number): string {
  if (n < 1000) return String(Math.max(0, n));
  if (n < 10_000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
  return `${Math.round(n / 1000)}k`;
}

const stop = (fn: () => void) => (e: MouseEvent) => { e.stopPropagation(); fn(); };

/** Body text with #tags and @handles as links. */
export function ScreamText({ text, className }: { text: string; className?: string }) {
  const parts = text.split(TOKEN_RE);
  return (
    <span className={className}>
      {parts.map((part, i) => {
        if (i % 2 === 0) return part;
        const word = part.slice(1).toLowerCase();
        if (part[0] === "#") return <button key={i} type="button" className="stoken stoken--tag" onClick={stop(() => openTag(word))}>{part}</button>;
        if (!HANDLE_RE.test(word)) return part;
        return <button key={i} type="button" className="stoken stoken--handle" onClick={stop(() => openProfile(word))}>{part}</button>;
      })}
    </span>
  );
}

export function DistrictStamp({ district }: { district: string | null }) {
  if (!district) return null;
  return <span className="sdistrict mono"><MapPin size={11} strokeWidth={2.4} />{district}</span>;
}

function Author({ a, big }: { a: SocialAuthor; big?: boolean }) {
  return (
    <>
      <button type="button" className="scream__name" onClick={stop(() => openProfile(a.handle))}>{a.name}</button>
      <span className={`scream__handle mono ${big ? "is-big" : ""}`}>@{a.handle}</span>
    </>
  );
}

/* --------------------------------------------------------------- card */

export type ScreamVariant = "feed" | "focus" | "parent" | "reply";

export function ScreamCard({ post, index = 0, variant = "feed", kbd, rail }: { post: SocialPost; index?: number; variant?: ScreamVariant; kbd?: boolean; rail?: boolean }) {
  const gone = useStore((s) => !!s.postGone[post.id]);
  const originGone = useStore((s) => (post.echoOf ? !!s.postGone[post.echoOf.id] : false));
  const plainEcho = !post.body && (!!post.echoOf || !!post.echoGone);
  if (gone) return null;
  if (plainEcho) {
    if (!post.echoOf || originGone) return null;
    return <ScreamInner post={post.echoOf} echoedBy={post.author} index={index} variant={variant} kbd={kbd} rail={rail} />;
  }
  return <ScreamInner post={post} index={index} variant={variant} kbd={kbd} rail={rail} />;
}

function ScreamInner({ post: raw, echoedBy, index, variant, kbd, rail }: { post: SocialPost; echoedBy?: SocialAuthor; index: number; variant: ScreamVariant; kbd?: boolean; rail?: boolean }) {
  const post = usePostLive(raw);
  const me = useStore((s) => s.state?.social?.handle);
  const embedGone = useStore((s) => (raw.echoOf ? !!s.postGone[raw.echoOf.id] : false));
  const focus = variant === "focus";

  return (
    <article
      className={`scream scream--${variant} ${kbd ? "is-kbd" : ""} ${rail ? "has-rail" : ""}`}
      style={{ "--i": Math.min(index, 14) } as CSSProperties}
      onClick={focus ? undefined : () => openScream(post.id)}
    >
      {echoedBy && (
        <div className="scream__echoed label">
          <Repeat2 size={14} strokeWidth={2.4} />
          {echoedBy.handle === me ? "You echoed" : <><button type="button" onClick={stop(() => openProfile(echoedBy.handle))}>@{echoedBy.handle}</button> echoed</>}
        </div>
      )}
      <div className="scream__grid">
        <div className="scream__side">
          <button type="button" className="scream__av" onClick={stop(() => openProfile(post.author.handle))} aria-label={`@${post.author.handle}`}>
            <Avatar name={post.author.name} seed={post.author.seed} size={focus ? 56 : 46} online={post.author.online} />
          </button>
          {rail && <span className="scream__rail" aria-hidden />}
        </div>
        <div className="scream__main">
          <div className="scream__top">
            <span className="scream__who"><Author a={post.author} big={focus} /></span>
            {!focus && <span className="scream__time" title={`${dayLabel(post.at)} ${hhmm(post.at)}`}>{relative(post.at)}</span>}
            <DistrictStamp district={post.district} />
          </div>
          {post.replyTo && (
            <div className="scream__replying">
              Replying to <button type="button" className="stoken stoken--handle" onClick={stop(() => openProfile(post.replyTo!.handle))}>@{post.replyTo.handle}</button>
            </div>
          )}
          {post.body && <ScreamText text={post.body} className="scream__body" />}
          {post.echoOf && !embedGone ? <ScreamEmbed post={post.echoOf} /> : (post.echoGone || embedGone) && <div className="sembed sembed--gone">This scream was deleted.</div>}
          {focus && (
            <div className="scream__meta">
              <span className="mono">{hhmm(post.at)} · {dayLabel(post.at)}</span>
              <span><b className="mono">{countLabel(post.cred)}</b> Street Cred</span>
              <span><b className="mono">{countLabel(post.echoes)}</b> {post.echoes === 1 ? "Echo" : "Echoes"}</span>
              <span><b className="mono">{countLabel(post.replies)}</b> {post.replies === 1 ? "Reply" : "Replies"}</span>
            </div>
          )}
          <Actions post={post} />
        </div>
      </div>
    </article>
  );
}

/* ------------------------------------------------------------ actions */

function Actions({ post }: { post: SocialPost }) {
  const [burst, setBurst] = useState(0);
  const [menu, setMenu] = useState<"" | "down" | "up">("");
  const moreRef = useRef<HTMLDivElement>(null);

  const cred = () => {
    if (!post.credded) setBurst((b) => b + 1);
    void toggleCred(post);
  };
  const openMenu = () => {
    if (menu) { setMenu(""); return; }
    // Open upward when the scroller has no room below.
    const el = moreRef.current;
    const box = el?.closest(".nl-scroll")?.getBoundingClientRect();
    const r = el?.getBoundingClientRect();
    const scale = Number(getComputedStyle(document.documentElement).getPropertyValue("--stage-scale")) || 1;
    setMenu(box && r && box.bottom - r.bottom < 190 * scale ? "up" : "down");
    play("select");
  };

  return (
    <div className="sacts" onClick={(e) => e.stopPropagation()}>
      <button type="button" className="sact sact--reply" onClick={() => composeOn(post, "reply")} aria-label="Reply">
        <span className="sact__icon"><MessageCircle size={17} strokeWidth={2.2} /></span>
        <span className="sact__count mono">{post.replies ? countLabel(post.replies) : ""}</span>
      </button>
      <button type="button" className={`sact sact--echo ${post.echoed ? "is-on" : ""}`} onClick={() => void toggleEcho(post)} aria-pressed={post.echoed} aria-label="Echo">
        <span className="sact__icon"><Repeat2 size={18} strokeWidth={2.2} /></span>
        <span className="sact__count mono">{post.echoes ? countLabel(post.echoes) : ""}</span>
      </button>
      <button type="button" className={`sact sact--cred ${post.credded ? "is-on" : ""}`} onClick={cred} aria-pressed={post.credded} aria-label="Street Cred">
        <span className="sact__icon">
          <Zap size={17} strokeWidth={2.2} />
          {burst > 0 && <CredBurst key={burst} />}
        </span>
        <span className="sact__label label">Cred</span>
        <span className="sact__count mono">{countLabel(post.cred)}</span>
      </button>
      <div className="sact-more" ref={moreRef}>
        <button type="button" className={`sact sact--more ${menu ? "is-on" : ""}`} onClick={openMenu} aria-label="More">
          <span className="sact__icon"><Ellipsis size={18} strokeWidth={2.4} /></span>
        </button>
        {menu && <ScreamMenu post={post} up={menu === "up"} onClose={() => setMenu("")} anchor={moreRef} />}
      </div>
    </div>
  );
}

/** The "+CRED" chrome burst: shards, two shock rings and the rising label. */
function CredBurst() {
  return (
    <span className="credburst" aria-hidden>
      <span className="credburst__flash" />
      <span className="credburst__ring" />
      <span className="credburst__ring credburst__ring--2" />
      {Array.from({ length: 10 }, (_, i) => <i key={i} style={{ "--a": `${i * 36 + (i % 2) * 14}deg`, "--d": `${24 + (i % 3) * 7}px` } as CSSProperties} />)}
      <span className="credburst__text">+CRED</span>
    </span>
  );
}

function ScreamMenu({ post, up, onClose, anchor }: { post: SocialPost; up: boolean; onClose: () => void; anchor: RefObject<HTMLDivElement> }) {
  const [step, setStep] = useState<"" | "delete" | "report">("");
  useEffect(() => {
    const down = (e: PointerEvent) => { if (!anchor.current?.contains(e.target as Node)) onClose(); };
    document.addEventListener("pointerdown", down);
    return () => document.removeEventListener("pointerdown", down);
  }, [anchor, onClose]);

  return (
    <div className={`smenu ${up ? "is-up" : ""}`} role="menu">
      {step === "" && (
        <>
          <button type="button" className="smenu__item" onClick={() => { onClose(); composeOn(post, "quote"); }}><Quote size={16} /> Quote</button>
          {post.mine && <button type="button" className="smenu__item is-danger" onClick={() => { play("select"); setStep("delete"); }}><Trash2 size={16} /> Delete</button>}
          {!post.mine && <button type="button" className="smenu__item" onClick={() => { play("select"); setStep("report"); }}><Flag size={16} /> Report</button>}
        </>
      )}
      {step === "delete" && (
        <>
          <div className="smenu__head label">Delete this scream?</div>
          <button type="button" className="smenu__item is-danger" onClick={() => { onClose(); void deleteScream(post.id); }}><Trash2 size={16} /> Delete for good</button>
          <button type="button" className="smenu__item" onClick={() => { play("back"); setStep(""); }}>Keep it</button>
        </>
      )}
      {step === "report" && (
        <>
          <div className="smenu__head label">Report for</div>
          {REPORT_REASONS.map((r) => (
            <button key={r} type="button" className="smenu__item" onClick={() => { onClose(); void reportScream(post.id, r.toLowerCase()); }}>{r}</button>
          ))}
        </>
      )}
    </div>
  );
}

/* -------------------------------------------------------------- embed */

/** A compact, read-only scream (quote embed, reply / quote context). */
export function ScreamEmbed({ post, static: isStatic }: { post: SocialPost; static?: boolean }) {
  return (
    <div className={`sembed ${isStatic ? "is-static" : ""}`} onClick={isStatic ? undefined : stop(() => openScream(post.id))}>
      <div className="sembed__top">
        <Avatar name={post.author.name} seed={post.author.seed} size={24} />
        <span className="sembed__name">{post.author.name}</span>
        <span className="sembed__handle mono">@{post.author.handle}</span>
        <span className="sembed__time">{relative(post.at)}</span>
        <DistrictStamp district={post.district} />
      </div>
      {post.body ? <ScreamText text={post.body} className="sembed__body" /> : <span className="sembed__body is-echo">Echo of @{post.echoOf?.author.handle ?? "deleted"}</span>}
    </div>
  );
}
