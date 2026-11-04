import { useEffect, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type TitanAbility, type TitanState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import "./titan.css";

/* Titan Assault on screen (server/modules/mission_titan.lua): the arrival of the Titans, the class picker, the
   countdown, a slim wave counter with the kills, announcements, the respawn timer and the result. Every payload is
   the whole state; timers count down locally from it. */

const ABILITY_LABEL: Record<TitanAbility, string> = {
  missiles: "MISSILES", vortex: "VORTEX", smoke: "SMOKE", dash: "DASH", jets: "JETS", sentry: "SENTRY", flight: "FLIGHT", designator: "DESIGNATOR", core: "CORE",
};
const CLASS_ICON: Record<string, string> = { vanguard: "crosshair", ronin: "swords", northstar: "eye", legion: "shield", brawler: "hand" };
const PICK_SECONDS = 60;

export function TitanMissionHud() {
  const [titan, setTitan] = useState<TitanState | null>(null);
  const [received, setReceived] = useState(0);
  const [banner, setBanner] = useState<TitanState["announce"] & { key: number }>();
  const [result, setResult] = useState<"victory" | "failed">();
  const [, tick] = useState(0);
  const me = useStore(s => s.state.character?.playerId);
  const seq = useRef(0);

  useEffect(() => on<TitanState>(PAGE_EVENTS.titan, p => {
    if (!p || !p.phase) return;
    if (p.phase === "ended") {
      setTitan(null);
      if (p.result) { setResult(p.result); window.setTimeout(() => setResult(undefined), 6000); }
      return;
    }
    setResult(undefined);
    setTitan(p); setReceived(performance.now());
    if (p.announce) { seq.current += 1; setBanner({ ...p.announce, key: seq.current }); }
  }), []);
  useEffect(() => {
    if (!banner) return;
    const t = window.setTimeout(() => setBanner(b => (b?.key === banner.key ? undefined : b)), 4200);
    return () => window.clearTimeout(t);
  }, [banner]);
  useEffect(() => {
    if (!titan) return;
    const t = window.setInterval(() => tick(n => n + 1), 200);
    return () => window.clearInterval(t);
  }, [titan]);

  if (!titan) return result ? <div className={`titan-result is-${result}`}><span>{result === "victory" ? "ASSAULT COMPLETE" : "ASSAULT FAILED"}</span></div> : null;
  const elapsed = performance.now() - received;
  const left = (ms?: number) => (ms == null ? undefined : Math.max(0, Math.ceil((ms - elapsed) / 1000)));
  const t = titan;
  const live = t.phase === "wave" || t.phase === "intermission";

  return <div className="titan" aria-live="polite">
    {t.phase === "arrive" && <Arrive t={t} me={me} />}
    {t.phase === "pick" && <Picker t={t} me={me} seconds={left(t.pickEndsInMs) ?? 0} />}
    {t.phase === "starting" && <div className="titan-center is-quiet"><small>TITAN ASSAULT</small><span>SYSTEMS ONLINE</span></div>}
    {t.phase === "countdown" && <div className="titan-center"><small>WAVE 1</small><span>HOSTILES INBOUND IN</span><b key={left(t.startsInMs)}>{left(t.startsInMs)}</b></div>}
    {live && <WaveBar t={t} next={left(t.nextWaveInMs)} />}
    {t.down && t.respawnInMs != null && (live || t.phase === "countdown") && <div className="titan-respawn"><small>PILOT DOWN</small><span>NEW TITAN IN</span><b>{left(t.respawnInMs)}</b></div>}
    {banner && <div key={banner.key} className={`titan-banner is-${banner.tone}`}><span>{banner.title}</span><p>{banner.body}</p></div>}
    {t.phase === "victory" && <div className="titan-result is-victory is-live"><span>ASSAULT REPELLED</span><small>{t.waves} waves · {t.killsTotal ?? 0} kills · {t.difficulty}</small></div>}
    {t.phase === "wipe" && <div className="titan-result is-failed is-live"><span>CREW WIPED</span><small>The road is theirs</small></div>}
  </div>;
}

function Arrive({ t, me }: { t: TitanState; me?: number }) {
  const ops = t.operators ?? [];
  const mine = ops.find(o => o.id === me);
  return <section className="titan-card">
    <header><span className="titan-card__tag">ASSAULT</span><b>{(t.title ?? "").toUpperCase()}</b><em>{t.difficulty}</em></header>
    <h2>DEPLOYING TITANS</h2>
    <ul>{ops.map(o => <li key={o.id} className={o.titan ? "is-ready" : "is-loading"}>
      <Icon name={o.titan ? "check" : "loader"} size={13} /><span>{o.name.toUpperCase()}{o.id === me ? " · YOU" : ""}</span>
      <em>{o.titan ? "TITAN ONLINE" : "LOADING"}</em></li>)}</ul>
    <footer><span>{mine?.titan ? "Your Titan is ready · waiting for the crew" : "Loading the road on your side…"}</span></footer>
  </section>;
}

function Picker({ t, me, seconds }: { t: TitanState; me?: number; seconds: number }) {
  const ops = t.operators ?? [];
  const classes = t.classes ?? [];
  const ready = ops.filter(o => o.ready).length;
  const choosing = !t.ready && classes.length > 0;
  const root = useRef<HTMLElement>(null);
  // the page takes the mouse while you pick, and gives it back once you are ready
  useEffect(() => {
    if (!choosing) return;
    emit(PAGE_EVENTS.focus, { active: true });
    root.current?.focus();
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [choosing]);
  const pick = (id: string) => { if (id !== t.class) sendAction({ type: "titan.class", id }); };
  const go = () => { if (t.class) sendAction({ type: "titan.ready" }); };
  return <section ref={root} tabIndex={-1} className={`titan-card${choosing ? " o77-interactive is-choosing" : ""}`}
    onKeyDown={e => {
      if (!choosing || e.repeat) return;
      const n = Number(e.key);
      if (n >= 1 && n <= classes.length) { e.preventDefault(); pick(classes[n - 1]!.id); }
      else if (e.key === "Enter") { e.preventDefault(); go(); }
    }}>
    <header><span className="titan-card__tag">ASSAULT</span><b>{(t.title ?? "").toUpperCase()}</b><em>{t.difficulty}</em></header>
    <h2>CHOOSE YOUR CLASS</h2>
    <div className="titan-card__timer"><i style={{ width: `${Math.min(100, (seconds / Math.max(PICK_SECONDS, seconds)) * 100)}%` }} /><span>{String(seconds).padStart(2, "0")}s</span></div>
    <div className="titan-classes" role="radiogroup" aria-label="Class">
      {classes.map((c, i) => <button key={c.id} type="button" role="radio" aria-checked={t.class === c.id} disabled={!choosing}
        className={`titan-class${t.class === c.id ? " is-picked" : ""}`} onClick={() => pick(c.id)}>
        <span className="titan-class__key">{i + 1}</span><Icon name={CLASS_ICON[c.id] ?? "crosshair"} size={18} />
        <span className="titan-class__name"><b>{c.label}</b><small>{c.weapon}</small></span>
        <span className="titan-class__body">
          {c.ultimate && <small className="titan-class__ultimate"><Icon name="flame" size={12} /><span>{c.ultimate}</span></small>}
          <span className="titan-class__chips">
            {c.abilities.map(a => <i key={a} className={a === "core" ? "is-core" : ""}>{a === "core" ? c.core.toUpperCase() : (c.labels?.[a]?.toUpperCase() ?? ABILITY_LABEL[a])}</i>)}
          </span>
        </span>
      </button>)}
    </div>
    <p className="titan-classes__rule">Ultimate (<kbd>Y</kbd>): charged by 15 kills; kills while it runs do not charge it.</p>
    <ul>{ops.map(o => <li key={o.id} className={o.ready ? "is-ready" : ""}>
      <Icon name={o.ready ? "check" : "loader"} size={13} /><span>{o.name.toUpperCase()}{o.id === me ? " · YOU" : ""}</span>
      <em>{o.ready ? "READY" : o.class ? o.class.toUpperCase() : "PICKING"}</em></li>)}</ul>
    <footer>{t.ready ? <span>Class locked · waiting for the crew · {ready}/{ops.length}</span>
      : <><span>Pick a class (<kbd>1</kbd>-<kbd>{classes.length || 5}</kbd>) · {ready}/{ops.length} ready</span>
        <button type="button" className="titan-card__go" onClick={go} disabled={!t.class}>READY<kbd>↵</kbd></button></>}</footer>
  </section>;
}

function WaveBar({ t, next }: { t: TitanState; next?: number }) {
  const wave = t.wave ?? 0, waves = t.waves ?? 10;
  const pips = Array.from({ length: waves }, (_, i) => i + 1);
  return <div className="titan-wave">
    <header>
      <span className="titan-wave__n">WAVE <b>{wave}</b> / {waves}</span>
      <span className={`titan-wave__left${t.phase === "intermission" ? " is-rest" : ""}`}>
        {t.phase === "intermission" ? <>NEXT WAVE IN <b>{next ?? 0}</b></> : <><b>{t.enemies ?? 0}</b> HOSTILES</>}
      </span>
      <span className="titan-wave__kills"><Icon name="crosshair" size={12} /><b>{t.kills ?? 0}</b> KILLS</span>
    </header>
    <div className="titan-wave__pips">{pips.map(n => <i key={n} className={n < wave || (n === wave && t.phase === "intermission") ? "is-done" : n === wave ? "is-live" : ""} />)}</div>
  </div>;
}
