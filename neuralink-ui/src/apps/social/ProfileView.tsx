/* A citizen's sheet: holographic cover generated from their seed, identity,
   counters, follow, then their screams. */
import { useEffect, useMemo, type CSSProperties } from "react";
import { CalendarDays, Megaphone, PenLine, UserCheck, UserPen, UserPlus, UserRound, UserX } from "lucide-react";
import { useStore } from "@/store/store";
import type { SocialProfile } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Btn, Empty, IconBtn, Loader } from "@/components/ui";
import { follow, loadProfile, navigate, profileKey } from "@/store/actions";
import { hueOf } from "@/lib/format";
import { ScreamList } from "./ScreamList";
import { ScreamText, countLabel } from "./ScreamCard";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** Cover parameters derived from the seed: three hues, an angle, a barcode. */
function coverOf(seed: string) {
  const h = hueOf(seed);
  const k = hueOf(`${seed}:cover`);
  const bars = Array.from({ length: 26 }, (_, i) => 1 + ((k >> (i % 12)) + i * 7) % 4);
  return {
    style: { "--h1": h, "--h2": (h + 55 + (k % 50)) % 360, "--h3": (h + 180 + (k % 70)) % 360, "--ang": `${(k % 140) + 20}deg`, "--gx": `${15 + (k % 70)}%` } as CSSProperties,
    bars,
    id: `NC-${(hueOf(`${seed}:id`) * 7919).toString(16).toUpperCase().padStart(6, "0").slice(-6)}`,
  };
}

export function ProfileCover({ seed, handle }: { seed: string; handle: string }) {
  const c = useMemo(() => coverOf(seed), [seed]);
  return (
    <div className="pcover" style={c.style} aria-hidden>
      <span className="pcover__grid" />
      <span className="pcover__scan" />
      <span className="pcover__sweep" />
      <span className="pcover__id mono">{c.id} // @{handle}</span>
      <span className="pcover__bars">{c.bars.map((w, i) => <i key={i} style={{ width: w * 2 }} />)}</span>
    </div>
  );
}

function ProfileHead({ p }: { p: SocialProfile }) {
  const joined = new Date(p.joinedAt);
  return (
    <div className="phead">
      <ProfileCover seed={p.seed} handle={p.handle} />
      <div className="phead__bar">
        <span className="phead__av"><Avatar name={p.name} seed={p.seed} size={104} ring="sel" online={p.online} /></span>
        <span className="phead__acts">
          {p.isMe ? (
            <Btn tone="ghost" icon={<UserPen size={16} />} onClick={() => navigate({ app: "social", screen: "edit" })}>Edit profile</Btn>
          ) : p.followed ? (
            <Btn className="phead__unfollow" icon={<UserCheck size={16} />} onClick={() => void follow(p.handle, false)}>
              <span className="is-idle">Following</span><span className="is-hover">Unfollow</span>
            </Btn>
          ) : (
            <Btn tone="sel" icon={<UserPlus size={16} />} onClick={() => void follow(p.handle, true)}>Follow</Btn>
          )}
        </span>
      </div>
      <div className="phead__id">
        <div className="phead__name">{p.name}</div>
        <div className="phead__handle">
          <span className="mono">@{p.handle}</span>
          {p.followsMe && !p.isMe && <span className="phead__chip label">Follows you</span>}
          {p.isMe && <span className="phead__chip is-me label">You</span>}
        </div>
        {p.bio ? <ScreamText text={p.bio} className="phead__bio" /> : <div className="phead__bio is-empty">{p.isMe ? "No bio yet. Tell the city who you are." : "No bio."}</div>}
        <div className="phead__joined"><CalendarDays size={14} /> Joined {MONTHS[joined.getMonth()]} {joined.getFullYear()}</div>
      </div>
      <div className="pstats">
        <Stat value={p.posts} label="Screams" />
        <Stat value={p.followers} label="Followers" />
        <Stat value={p.following} label="Following" />
        <Stat value={p.cred} label="Street Cred" hot />
      </div>
    </div>
  );
}

function Stat({ value, label, hot }: { value: number; label: string; hot?: boolean }) {
  return (
    <div className={`pstat ${hot ? "is-hot" : ""}`}>
      <span className="pstat__val mono">{countLabel(value)}</span>
      <span className="pstat__label label">{label}</span>
    </div>
  );
}

export function ProfileView({ handle: asked, canBack }: { handle: string; canBack: boolean }) {
  const mine = useStore((s) => s.state?.social?.handle ?? "");
  const handle = asked || mine;
  const profile = useStore((s) => (handle ? s.profiles[handle] : undefined));
  const feed = useStore((s) => (handle ? s.feeds[profileKey(handle)] : undefined));

  useEffect(() => { if (handle) void loadProfile(handle); }, [handle]);

  const missing = !profile && feed && !feed.loading;
  return (
    <Window
      icon={<UserRound size={22} />}
      title={profile?.name ?? "Profile"}
      subtitle={handle ? `@${handle}` : "Screamsheet"}
      tag="NL//06-CIT"
      canBack={canBack}
      bodyClass="sprofile"
      actions={profile?.isMe ? <IconBtn label="Compose" tone="sel" onClick={() => navigate({ app: "social", screen: "compose" })}><PenLine size={18} /></IconBtn> : null}
    >
      {!handle || missing ? (
        <Empty icon={<UserX size={30} />} title="No such citizen" body={handle ? `Nobody answers to @${handle}.` : "Your neural profile is not ready yet."} />
      ) : !profile || !feed || feed.loading ? (
        <Loader text="Pulling the file" />
      ) : (
        <ScreamList
          posts={feed.posts}
          hasMore={feed.hasMore}
          loadingMore={feed.loadingMore}
          onMore={() => void loadProfile(handle, true)}
          head={<ProfileHead p={profile} />}
          empty={<div className="sprofile__none"><Megaphone size={18} /> {profile.isMe ? "You have not screamed yet." : "Silent so far."}</div>}
        />
      )}
    </Window>
  );
}
