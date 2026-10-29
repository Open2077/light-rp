import { useEffect, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type RaidState } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import "./raid.css";

/* The raid on screen (server/modules/mission_chimera.lua): the ready check, the
   launch countdown, the intro's letterbox and title card, the boss bar with its
   phases, the target lock, announcements, the respawn timer and the result.
   Every payload is the whole raid state; timers count down locally from it. */

// The intro's beats, as fractions of its duration: the camera cuts on the same
// numbers (CUT in resources/gamemodes/op77_lightrp/client/core/raid.lua).
const INTRO_BEATS = { closeLow: 0.18, closeHigh: 0.27, wake: 0.36, orbit: 0.40, roar: 0.86, out: 0.93 };
const CUTS = [INTRO_BEATS.closeLow, INTRO_BEATS.closeHigh, INTRO_BEATS.orbit, 0.72];
const TELEMETRY = ["MILITECH TAC-NET // UPLINK ESTABLISHED", "TARGET    MT-CHIMERA 0005-C", "STATUS    DORMANT", "SECTOR    DOGTOWN // THE ARENA"];
const SCAN = [["ARMOR", "HEAVY PLATING"], ["WEAPONS", "MINIGUN · MISSILE POD"], ["CORE", "SHIELDED"]];

const PHASES: Array<[string, string]> = [["armored", "ARMORED"], ["exposed", "EXPOSED"], ["gas", "GAS"], ["core", "CORE"]];
const pad = (n: number) => String(Math.max(0, n)).padStart(2, "0");
const clock = (s: number) => `${pad(Math.floor(s / 60))}:${pad(s % 60)}`;

export function RaidHud() {
  const [raid, setRaid] = useState<RaidState | null>(null);
  const [received, setReceived] = useState(0);
  const [banner, setBanner] = useState<RaidState["announce"] & { key: number }>();
  const [result, setResult] = useState<"victory" | "failed">();
  const [introAt, setIntroAt] = useState<number>();
  const [, tick] = useState(0);
  const me = useStore(s => s.state.character?.playerId);
  const seq = useRef(0);

  useEffect(() => on<RaidState>(PAGE_EVENTS.raid, p => {
    if (!p || !p.phase) return;
    if (p.phase === "ended") {
      setRaid(null); setIntroAt(undefined);
      if (p.result) { setResult(p.result); window.setTimeout(() => setResult(undefined), 6000); }
      return;
    }
    setResult(undefined);
    setRaid(p); setReceived(performance.now());
    if (p.intro) setIntroAt(performance.now());
    if (p.announce) { seq.current += 1; setBanner({ ...p.announce, key: seq.current }); }
  }), []);
  useEffect(() => {
    if (!banner) return;
    const t = window.setTimeout(() => setBanner(b => (b?.key === banner.key ? undefined : b)), 4200);
    return () => window.clearTimeout(t);
  }, [banner]);
  const fast = raid?.phase === "intro" || raid?.phase === "placing";
  useEffect(() => {
    if (!raid) return;
    const t = window.setInterval(() => tick(n => n + 1), fast ? 40 : 200);
    return () => window.clearInterval(t);
  }, [raid, fast]);

  if (!raid) document.documentElement.removeAttribute("data-raid-cinematic");
  if (!raid) return result ? <div className={`raid-result is-${result}`}><span>{result === "victory" ? "MISSION COMPLETE" : "MISSION FAILED"}</span></div> : null;
  const elapsed = performance.now() - received;
  const left = (ms?: number) => (ms == null ? undefined : Math.max(0, Math.ceil((ms - elapsed) / 1000)));
  const introMs = raid.intro?.durationMs ?? 11000;
  const introT = introAt != null ? (performance.now() - introAt) / introMs : 2;
  const cinematic = raid.phase === "intro" || (introT < 1 && raid.phase !== "fight");
  document.documentElement.toggleAttribute("data-raid-cinematic", cinematic);

  return <div className="raid" aria-live="polite">
    {cinematic && <Intro raid={raid} t={introT} />}
    {raid.phase === "ready" && <ReadyCheck raid={raid} me={me} seconds={left(raid.readyEndsInMs) ?? 0} />}
    {raid.phase === "launch" && <div className="raid-launch"><small>ALL OPERATORS READY</small><span>ENGAGING IN</span><b key={left(raid.launchInMs)}>{left(raid.launchInMs)}</b></div>}
    {raid.phase === "placing" && <div className="raid-launch is-placing"><small>MILITECH UPLINK</small><span>DEPLOYING THE TARGET</span></div>}
    {(raid.phase === "fight" || raid.phase === "victory" || raid.phase === "wipe") && raid.boss && <BossBar raid={raid} me={me} enrageIn={left(raid.enrageInMs)} />}
    {raid.phase === "fight" && raid.boss?.target != null && raid.boss.target === me && <div className="raid-lock"><Icon name="triangle-alert" size={18} />YOU ARE TARGETED<small>Break line of sight</small></div>}
    {raid.respawnInMs != null && raid.phase === "fight" && <div className="raid-respawn"><small>FLATLINED</small><span>REDEPLOYING IN</span><b>{left(raid.respawnInMs)}</b></div>}
    {raid.out && raid.phase === "fight" && <div className="raid-respawn is-out"><small>FLATLINED</small><span>OUT OF THE FIGHT</span><em>No respawns on this difficulty. Your squad fights on.</em></div>}
    {banner && <div key={banner.key} className={`raid-banner is-${banner.tone}`}><span>{banner.title}</span><p>{banner.body}</p></div>}
    {raid.phase === "victory" && <div className="raid-result is-victory is-live"><span>CHIMERA DOWN</span><small>{clock(raid.fightSeconds ?? 0)} · {raid.difficulty}</small></div>}
    {raid.phase === "wipe" && <div className="raid-result is-failed is-live"><span>SQUAD WIPED</span><small>The Chimera holds the arena</small></div>}
  </div>;
}

const KIT_ICON: Record<string, string> = { assault: "crosshair", breacher: "flame", marksman: "eye", gunner: "zap", tech: "radio" };

function ReadyCheck({ raid, me, seconds }: { raid: RaidState; me?: number; seconds: number }) {
  const ops = raid.operators ?? [];
  const ready = ops.filter(o => o.ready).length;
  const mine = ops.find(o => o.id === me);
  const kits = raid.loadouts ?? [];
  const total = 45;
  const choosing = !mine?.ready && kits.length > 0;
  // ready only once this client finished loading the arena (the server refuses before)
  const loading = raid.loaded === false;
  const root = useRef<HTMLElement>(null);
  // the page takes the mouse while you pick, and gives it back once you are ready
  useEffect(() => {
    if (!choosing) return;
    emit(PAGE_EVENTS.focus, { active: true });
    root.current?.focus();
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [choosing]);
  const pick = (id: string) => { if (id !== raid.loadout) sendAction({ type: "raid.loadout", id }); };
  const go = () => sendAction({ type: "raid.ready" });
  return <section ref={root} tabIndex={-1} className={`raid-ready${choosing ? " o77-interactive is-choosing" : ""}`}
    onKeyDown={e => {
      if (!choosing || e.repeat) return;
      const n = Number(e.key);
      if (n >= 1 && n <= kits.length) { e.preventDefault(); pick(kits[n - 1]!.id); }
      else if (!loading && (e.key === "Enter" || e.key.toLowerCase() === (raid.readyKey ?? "Y").toLowerCase())) { e.preventDefault(); go(); }
    }}>
    <header><span className="raid-ready__tag">RAID</span><b>{(raid.title ?? "").toUpperCase()}</b><em>{raid.difficulty}</em></header>
    <h2>READY CHECK</h2>
    <div className="raid-ready__timer"><i style={{ width: `${Math.min(100, (seconds / total) * 100)}%` }} /><span>{pad(seconds)}s</span></div>
    <ul>{ops.map(o => <li key={o.id} className={o.ready ? "is-ready" : o.loaded === false ? "is-loading" : ""}>
      <Icon name={o.ready ? "check" : "loader"} size={13} /><span>{o.name.toUpperCase()}{o.id === me ? " · YOU" : ""}</span>
      <em>{o.ready ? "READY" : o.loaded === false ? "LOADING" : "STANDING BY"}</em></li>)}</ul>
    {kits.length > 0 && <div className="raid-kits" role="radiogroup" aria-label="Loadout">
      {kits.map((k, i) => <button key={k.id} type="button" role="radio" aria-checked={raid.loadout === k.id} disabled={!choosing}
        className={`raid-kit${raid.loadout === k.id ? " is-picked" : ""}`} onClick={() => pick(k.id)}>
        <span className="raid-kit__key">{i + 1}</span><Icon name={KIT_ICON[k.id] ?? "crosshair"} size={16} />
        <b>{k.label}</b><small>{k.blurb}</small></button>)}
    </div>}
    <footer>{mine?.ready ? <span>Loadout issued · waiting for the squad · {ready}/{ops.length}</span>
      : <><span>{loading ? "Loading the arena…" : <>Pick a loadout (<kbd>1</kbd>-<kbd>{kits.length || 5}</kbd>) · {ready}/{ops.length} ready</>}</span>
        <button type="button" className="raid-ready__go" onClick={go} disabled={loading}>{loading ? "LOADING" : "READY"}<kbd>{raid.readyKey ?? "Y"}</kbd></button></>}</footer>
  </section>;
}

function Intro({ raid, t }: { raid: RaidState; t: number }) {
  const B = INTRO_BEATS;
  const scanning = t >= B.closeLow && t < B.wake + 0.04;
  const confirmed = t >= B.wake;
  const scan = Math.min(100, Math.round(((t - B.closeLow) / (B.wake - B.closeLow)) * 100));
  const lines = Math.min(TELEMETRY.length, Math.floor(t / 0.035) + 1);
  const cut = CUTS.find(c => t >= c && t < c + 0.012);
  return <div className={`raid-intro${t >= B.out ? " is-out" : ""}${t >= B.wake && t < B.wake + 0.05 ? " is-jolt" : ""}`}>
    <i className="raid-intro__bar is-top" /><i className="raid-intro__bar is-bottom" />
    {cut != null && <i key={cut} className="raid-intro__cut" />}
    {t >= B.wake && t < B.wake + 0.06 && <i className="raid-intro__flash" />}
    {t >= B.roar && t < B.roar + 0.05 && <i className="raid-intro__flash is-soft" />}
    {t < B.closeLow && <div className="raid-intro__telemetry">
      {TELEMETRY.slice(0, lines).map((l, i) => <span key={i}>{l}</span>)}
    </div>}
    {t < B.wake && <div className="raid-intro__warn"><Icon name="siren" size={14} />HOSTILE WAR MACHINE DETECTED</div>}
    {scanning && <div className={`raid-intro__scan${confirmed ? " is-confirmed" : ""}`}>
      <i /><i /><i /><i />
      <header>{confirmed ? "THREAT CONFIRMED" : "ANALYSING"}<b>{confirmed ? "" : `${Math.max(0, scan)}%`}</b></header>
      <dl>{SCAN.filter((_, i) => scan >= 20 + i * 28).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}</dl>
    </div>}
    {t > B.orbit + 0.02 && t < B.out + 0.04 && <div className="raid-intro__card">
      <small>MILITECH · AV-HEAVY WAR MACHINE</small>
      <h1 data-text="CHIMERA">CHIMERA</h1>
      <p>DOGTOWN // THE ARENA</p>
      <div className="raid-intro__meta"><span className={`raid-chip is-${raid.difficultyId}`}>{raid.difficulty}</span>
        <span>THREAT</span><span className="raid-intro__threat">{Array.from({ length: 5 }, (_, i) =>
          <i key={i} className={i < (raid.difficultyId === "critical" ? 5 : raid.difficultyId === "hard" ? 4 : 3) ? "is-on" : ""} />)}</span>
        <span>{raid.intro?.operators ?? raid.operators?.length ?? 1} OPERATOR{(raid.intro?.operators ?? 1) > 1 ? "S" : ""}</span></div>
    </div>}
  </div>;
}

function BossBar({ raid, me, enrageIn }: { raid: RaidState; me?: number; enrageIn?: number }) {
  const b = raid.boss!;
  const pct = Math.max(0, Math.min(100, b.healthPercent));
  const lives = raid.lives ?? 0;
  // The game draws the Chimera's own health bar at the top: this is the raid's strip under it.
  return <section className={`raid-boss${b.enraged ? " is-enraged" : ""}${raid.phase === "victory" ? " is-dead" : ""}`} data-health={Math.ceil(pct)}>
    <footer>
      <span className="raid-boss__phase">{(PHASES.find(p => p[0] === b.phase)?.[1]) ?? b.phase?.toUpperCase()}</span>
      {b.enraged && <span className="raid-boss__enrage"><Icon name="flame" size={12} />OVERCLOCKED</span>}
      {b.repairing && <span className="raid-boss__shield"><Icon name="shield" size={12} />SHIELDED{b.repairInMs != null ? ` ${Math.ceil(b.repairInMs / 1000)}s` : ""}</span>}
      <span><Icon name="users" size={12} />{raid.adds ?? 0} HOSTILES</span>
      <span><Icon name="heart-pulse" size={12} />{lives < 0 ? "RESPAWNS ∞" : lives === 0 ? "NO RESPAWNS" : `${lives} RESPAWN${lives > 1 ? "S" : ""}`}</span>
      <span><Icon name="timer" size={12} />{clock(raid.fightSeconds ?? 0)}</span>
      {enrageIn != null && !b.enraged && <span className={enrageIn <= 60 ? "is-hot" : ""}><Icon name="flame" size={12} />OVERCLOCK {clock(enrageIn)}</span>}
      {b.target != null && b.target !== me && b.targetName && <span className="is-hot"><Icon name="triangle-alert" size={12} />LOCKED ON {b.targetName.toUpperCase()}</span>}
    </footer>
  </section>;
}
