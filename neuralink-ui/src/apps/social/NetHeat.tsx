/* Net Heat: what Night City screams about right now. District heat bars that
   burn hotter with traffic, the trending #tags, the Hot screams, and search
   over citizens and screams. */
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { Activity, Flame, Hash, MapPin, RefreshCw, Search, UserRound } from "lucide-react";
import type { SocialHeat, SocialPost, SocialProfile } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Avatar, Empty, Field, IconBtn, Loader, SectionTitle } from "@/components/ui";
import { act, openProfile, openTag } from "@/store/actions";
import { play } from "@/fx/sound";
import { ScreamCard, countLabel } from "./ScreamCard";

export function NetHeat({ search, canBack }: { search: boolean; canBack: boolean }) {
  const [heat, setHeat] = useState<SocialHeat | null>(null);
  const [failed, setFailed] = useState(false);
  const [q, setQ] = useState("");
  const [res, setRes] = useState<{ q: string; profiles: SocialProfile[]; posts: SocialPost[] } | null>(null);
  const [searching, setSearching] = useState(false);
  const seq = useRef(0);

  const load = async () => {
    const r = await act("social.heat", {}, { quiet: true });
    if (r) setHeat(r); else setFailed(true);
  };
  useEffect(() => { void load(); }, []);

  useEffect(() => {
    const ql = q.trim();
    const n = ++seq.current;
    if (ql.length < 2) { setRes(null); setSearching(false); return; }
    setSearching(true);
    const t = window.setTimeout(async () => {
      const r = await act("social.search", { q: ql }, { quiet: true });
      if (n !== seq.current) return;
      setSearching(false);
      setRes({ q: ql, profiles: r?.profiles ?? [], posts: r?.posts ?? [] });
    }, 320);
    return () => window.clearTimeout(t);
  }, [q]);

  const total = heat?.districts.reduce((n, d) => n + d.count, 0) ?? 0;

  return (
    <Window
      icon={<Activity size={22} />}
      title="Net Heat"
      subtitle={heat ? `${countLabel(total)} screams across the city · last 24 h` : "Night City · last 24 h"}
      tag="NL//06-HEAT"
      canBack={canBack}
      bodyClass="sheat"
      actions={<IconBtn label="Refresh" onClick={() => { play("select"); void load(); }}><RefreshCw size={18} /></IconBtn>}
    >
      <Field icon={<Search size={16} />} placeholder="Search citizens, screams, #tags" value={q} autoFocus={search} onChange={(e) => setQ(e.target.value)} className="sheat__search" />
      <div className="sheat__scroll nl-scroll">
        {q.trim().length >= 2 ? (
          searching && !res ? <Loader text="Scanning the sheet" /> : res && <Results res={res} />
        ) : !heat ? (
          failed ? <Empty icon={<Activity size={30} />} title="No signal" body="The Net Heat feed is offline." /> : <Loader text="Reading the grid" />
        ) : (
          <>
            <Districts list={heat.districts} />
            <SectionTitle aside={<span className="mono sheat__aside">{heat.tags.length} tags</span>}>Trending</SectionTitle>
            <Tags list={heat.tags} />
            <SectionTitle aside={<Flame size={16} className="sheat__flame" />}>Hot screams</SectionTitle>
            {heat.hot.length === 0 ? <div className="sheat__none">Nothing is burning yet.</div> : heat.hot.map((p, i) => <ScreamCard key={p.id} post={p} index={i} />)}
          </>
        )}
      </div>
    </Window>
  );
}

function Districts({ list }: { list: SocialHeat["districts"] }) {
  const max = Math.max(1, ...list.map((d) => d.count));
  return (
    <section className="hmap">
      <header className="hmap__head">
        <span className="hmap__title label"><MapPin size={15} strokeWidth={2.4} /> District heat</span>
        <span className="hmap__legend mono"><i className="is-cold" />cold<i className="is-hot" />burning</span>
      </header>
      {list.length === 0 ? <div className="sheat__none">The grid is silent.</div> : (
        <div className="hmap__rows">
          {list.slice(0, 12).map((d, i) => {
            const t = d.count / max;
            return (
              <div key={d.district} className={`hbar ${t > 0.75 ? "is-burning" : t > 0.4 ? "is-warm" : ""}`} style={{ "--t": t.toFixed(3), "--i": i } as CSSProperties}>
                <span className="hbar__rank mono">{String(i + 1).padStart(2, "0")}</span>
                <span className="hbar__name label">{d.district}</span>
                <span className="hbar__track">
                  <span className="hbar__fill"><span className="hbar__ember" /></span>
                </span>
                <span className="hbar__count mono">{countLabel(d.count)}</span>
                {t > 0.75 && <Flame className="hbar__flame" size={15} strokeWidth={2.4} />}
              </div>
            );
          })}
        </div>
      )}
    </section>
  );
}

function Tags({ list }: { list: SocialHeat["tags"] }) {
  if (list.length === 0) return <div className="sheat__none">No tag is trending.</div>;
  const max = Math.max(1, ...list.map((t) => t.count));
  return (
    <div className="tcloud">
      {list.slice(0, 18).map((t, i) => {
        const k = t.count / max;
        const tag = t.tag.replace(/^#/, "");
        return (
          <button key={tag} type="button" className={`tcloud__tag ${k > 0.66 ? "is-hot" : k > 0.33 ? "is-warm" : ""}`} style={{ "--k": k.toFixed(3), "--i": i } as CSSProperties} onClick={() => openTag(tag)}>
            <Hash size={14} strokeWidth={2.6} />
            <span>{tag}</span>
            <span className="tcloud__n mono">{countLabel(t.count)}</span>
          </button>
        );
      })}
    </div>
  );
}

function Results({ res }: { res: { q: string; profiles: SocialProfile[]; posts: SocialPost[] } }) {
  if (res.profiles.length === 0 && res.posts.length === 0) return <Empty icon={<Search size={30} />} title="No match" body={`Nothing for "${res.q}".`} />;
  return (
    <>
      {res.profiles.length > 0 && (
        <>
          <SectionTitle aside={<span className="mono sheat__aside">{res.profiles.length}</span>}>Citizens</SectionTitle>
          <div className="sres__people">
            {res.profiles.map((p, i) => (
              <button key={p.handle} type="button" className="prow sres__person" style={{ ["--i" as string]: i }} onClick={() => openProfile(p.handle)}>
                <Avatar name={p.name} seed={p.seed} size={40} online={p.online} />
                <span className="prow__text">
                  <span className="prow__name">{p.name}</span>
                  <span className="prow__num mono">@{p.handle} · {countLabel(p.followers)} followers</span>
                </span>
                {p.followsMe && <span className="phead__chip label">Follows you</span>}
                <UserRound size={16} className="sres__go" />
              </button>
            ))}
          </div>
        </>
      )}
      {res.posts.length > 0 && (
        <>
          <SectionTitle aside={<span className="mono sheat__aside">{res.posts.length}</span>}>Screams</SectionTitle>
          {res.posts.map((p, i) => <ScreamCard key={p.id} post={p} index={i} />)}
        </>
      )}
    </>
  );
}
