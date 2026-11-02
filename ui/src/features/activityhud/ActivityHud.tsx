import { useEffect, useRef, useState, type CSSProperties } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon, Keycap } from "@/design/components";
import {
  clockValue, formatElapsed, formatRemaining, normalizeHud, normalizeResult, ordinalSuffix, teamColor, windowRows,
  type ActivityBanner, type ActivityFeedItem, type ActivityHint, type ActivityHudMessage, type ActivityHudView,
  type ActivityPhase, type ActivityProgress, type ActivityResult, type ActivityRow, type ActivityTeam, type ActivityTimer,
} from "./model";
import "./activity-hud.css";

/* The shared in-match HUD of the activity providers (arena, race, chase, turf...),
   driven by client/core/activity_hud.lua. A pure overlay: no focus, no input. The
   header sits at the top centre, the match panel in the work order's slot on the
   right, the feed beside the minimap; countdown, banners and the result card take
   the centre for a moment. While a match runs, Light RP's needs (frozen there) and
   the work order step aside; health, armour, chat, voice and notices stay. */

const FEED_MAX = 5;
const FEED_MS = 5200;
const BIG_COUNT_S = 5; // the last seconds before GO get the big digits
const PHASE_LABEL: Record<ActivityPhase, string> = { lobby: "LOBBY", countdown: "STANDBY", running: "LIVE", ended: "FINISHED" };

type Stamped<T> = T & { key: number };
type FeedEntry = Stamped<ActivityFeedItem> & { at: number };

export function ActivityHud() {
  const [hud, setHud] = useState<ActivityHudView>();
  const [at, setAt] = useState(0);
  const [feed, setFeed] = useState<FeedEntry[]>([]);
  const [banner, setBanner] = useState<Stamped<ActivityBanner>>();
  const [result, setResult] = useState<Stamped<ActivityResult>>();
  const seq = useRef(0);
  const quiet = useStore((s) => s.menuOpen || !!s.dialog);
  const away = useStore((s) => s.state.character.status !== "active" || !!s.state.character.welcomePending);
  const queued = useStore((s) => !!s.state.missionQueue);
  const working = useStore((s) => !!s.state.jobRun?.active);

  useEffect(() => on<ActivityHudMessage>(PAGE_EVENTS.activityHud, (m) => {
    if (!m || typeof m !== "object") return;
    if (m.op === "show") {
      const view = normalizeHud(m.hud);
      if (view) { setHud(view); setAt(performance.now()); }
    } else if (m.op === "clear") {
      setHud(undefined); setFeed([]);
      // The owner closing its HUD leaves the result card and the last banner their
      // time on screen; a stop, a restart or a character change takes everything.
      if (m.reason !== "cleared") { setBanner(undefined); setResult(undefined); }
    } else if (m.op === "push" && m.item) {
      const key = ++seq.current;
      if (m.kind === "feed" && m.item.text) setFeed((f) => [...f, { ...m.item, key, at: performance.now() }].slice(-FEED_MAX));
      else if (m.kind === "banner") setBanner({ ...m.item, key });
      else if (m.kind === "result") { setBanner(undefined); setResult({ ...normalizeResult(m.item), key }); }
    }
  }), []);

  useEffect(() => {
    if (!banner) return;
    const t = window.setTimeout(() => setBanner((b) => (b?.key === banner.key ? undefined : b)), banner.durationMs || 3000);
    return () => window.clearTimeout(t);
  }, [banner]);
  useEffect(() => {
    if (!result) return;
    const t = window.setTimeout(() => setResult((r) => (r?.key === result.key ? undefined : r)), result.durationMs || 8000);
    return () => window.clearTimeout(t);
  }, [result]);
  useEffect(() => {
    const oldest = feed[0];
    if (!oldest) return;
    const t = window.setTimeout(() => setFeed((f) => f.filter((x) => x.key !== oldest.key)), Math.max(0, oldest.at + FEED_MS - performance.now()));
    return () => window.clearTimeout(t);
  }, [feed]);

  // Light RP's own HUD reads this to step aside (activity-hud.css).
  const phase = hud && !away ? hud.phase : undefined;
  useEffect(() => {
    const root = document.documentElement;
    if (phase) root.dataset.activityHud = phase;
    else delete root.dataset.activityHud;
    return () => { delete root.dataset.activityHud; };
  }, [phase]);

  if (away || (!hud && !banner && !result && feed.length === 0)) return null;
  // A lobby can wait beside a work order: the order keeps its slot, the hints move up.
  const folded = hud?.phase === "lobby" && working;
  return <div className={`ah${quiet ? " is-quiet" : ""}${queued ? " is-lowered" : ""}`} aria-live="polite" data-activity={hud?.activity}>
    {hud && <Header hud={hud} at={at} hints={folded} />}
    {hud?.phase === "countdown" && <Countdown hud={hud} at={at} />}
    {hud && !folded && <Panel hud={hud} />}
    {feed.length > 0 && <ul className="ah-feed">{feed.map((f) => <li key={f.key} className={`is-${f.tone ?? "plain"}`} style={{ "--life": `${FEED_MS}ms` } as CSSProperties}><span>{f.text}</span></li>)}</ul>}
    {banner && <Banner banner={banner} />}
    {result && <ResultCard result={result} />}
  </div>;
}

function Header({ hud, at, hints }: { hud: ActivityHudView; at: number; hints: boolean }) {
  const duel = hud.teams.length === 2 ? hud.teams : undefined;
  const middle = !!hud.timer || !!duel;
  return <header className={`ah-head is-${hud.phase}`}>
    <div className="ah-head__plate">
      <div className="ah-head__id">
        <span className={`ah-phase is-${hud.phase}`}>{PHASE_LABEL[hud.phase]}</span>
        <b>{hud.title}</b>
        {hud.subtitle && <small>{hud.subtitle}</small>}
      </div>
      {middle && <div className="ah-head__mid">
        {duel && <TeamScore team={duel[0]!} side="left" />}
        {hud.timer ? <Clock timer={hud.timer} phase={hud.phase} at={at} /> : <span className="ah-versus">VS</span>}
        {duel && <TeamScore team={duel[1]!} side="right" />}
      </div>}
    </div>
    {!duel && hud.teams.length > 0 && <ul className="ah-teams">{hud.teams.map((t, i) => <li key={i} className={t.self ? "is-self" : ""}
      style={{ "--team": teamColor(t.color) ?? "var(--o77-ink-300)" } as CSSProperties}><i /><span>{t.name}</span><b>{t.score ?? "-"}</b></li>)}</ul>}
    {hud.objective && <p className="ah-objective"><Icon name="crosshair" size={12} /><span>{hud.objective}</span></p>}
    {hints && hud.hints.length > 0 && <Hints hints={hud.hints} />}
  </header>;
}

function TeamScore({ team, side }: { team: ActivityTeam; side: "left" | "right" }) {
  return <div className={`ah-side is-${side}${team.self ? " is-self" : ""}`} style={{ "--team": teamColor(team.color) ?? "var(--o77-ink-300)" } as CSSProperties}>
    <span>{team.name}</span><b>{team.score ?? "0"}</b>
  </div>;
}

/* The clock counts locally from the snapshot; it writes its text straight to the DOM
   so a race timer to the hundredth does not re-render React sixty times a second. */
function Clock({ timer, phase, at }: { timer: ActivityTimer; phase: ActivityPhase; at: number }) {
  const box = useRef<HTMLDivElement>(null);
  const digits = useRef<HTMLElement>(null);
  useEffect(() => {
    let frame = 0, last = "";
    const moving = timer.countUp ? phase === "running" : true;
    const paint = () => {
      const value = clockValue(timer, phase, performance.now() - at);
      const text = timer.countUp ? formatElapsed(value) : formatRemaining(value);
      if (text !== last && digits.current) { digits.current.textContent = text; last = text; }
      box.current?.classList.toggle("is-low", !timer.countUp && value > 0 && value <= 10000);
      if (moving && !(!timer.countUp && value <= 0)) frame = requestAnimationFrame(paint);
    };
    paint();
    return () => cancelAnimationFrame(frame);
  }, [timer, phase, at]);
  return <div ref={box} className={`ah-clock${timer.countUp ? " is-up" : ""}`}>
    {timer.label && <small>{timer.label}</small>}<b ref={digits} />
  </div>;
}

function Countdown({ hud, at }: { hud: ActivityHudView; at: number }) {
  const [, tick] = useState(0);
  useEffect(() => {
    const t = window.setInterval(() => tick((n) => n + 1), 100);
    return () => window.clearInterval(t);
  }, []);
  if (hud.countdown == null) return <div className="ah-count is-wait"><span>GET READY</span></div>;
  const left = hud.countdown - (performance.now() - at);
  const seconds = Math.ceil(left / 1000);
  if (seconds > BIG_COUNT_S) return <div className="ah-count is-far"><small>STARTS IN</small><span>{formatRemaining(left)}</span></div>;
  return <div className="ah-count">{seconds > 0 ? <b key={seconds}>{seconds}</b> : <b key="go" className="is-go">GO</b>}</div>;
}

function Panel({ hud }: { hud: ActivityHudView }) {
  const { stats, progress, scoreboard, hints } = hud;
  if (stats.length === 0 && progress.length === 0 && !scoreboard && hints.length === 0) return null;
  // The panel keeps to the work order's slot (max(38vh, 300px), activity-hud.css): the
  // table gets the height the stats, bars and hints leave, at 25 px a row.
  const statRows = stats.length === 3 ? 1 : Math.ceil(stats.length / 2);
  const room = Math.max(window.innerHeight * 0.38, 300) - (statRows ? 20 + 46 * statRows : 0)
    - (progress.length ? 24 + 26 * progress.length : 0) - (hints.length ? 48 : 0) - 36;
  const rows = Math.min(8, Math.max(3, Math.floor(room / 25)));
  return <aside className="ah-panel" aria-label={hud.title}>
    {stats.length > 0 && <dl className={`ah-stats n${stats.length}`}>{stats.map((s, i) => <div key={i}><dt>{s.label}</dt><dd>{s.value}</dd></div>)}</dl>}
    {progress.length > 0 && <div className="ah-bars">{progress.map((p) => <Bar key={p.id} bar={p} />)}</div>}
    {scoreboard && <Board columns={scoreboard.columns} rows={scoreboard.rows} teams={hud.teams} max={rows} />}
    {hints.length > 0 && <Hints hints={hints} />}
  </aside>;
}

function Bar({ bar }: { bar: ActivityProgress }) {
  const pct = Math.round(Math.min(1, Math.max(0, bar.value)) * 100);
  return <div className={`ah-bar is-${bar.tone ?? "accent"}`}>
    {bar.label && <div className="ah-bar__head"><span>{bar.label}</span><b>{pct}%</b></div>}
    <div className="ah-bar__track"><i style={{ width: `${pct}%` }} /></div>
  </div>;
}

function Board({ columns, rows, teams, max }: { columns: string[]; rows: ActivityRow[]; teams: ActivityTeam[]; max: number }) {
  const grid = { gridTemplateColumns: `20px minmax(0, 1fr)${" minmax(36px, auto)".repeat(columns.length)}` };
  return <div className="ah-board">
    {columns.some((c) => c !== "") && <div className="ah-board__row is-head" style={grid}>
      <span>#</span><span />{columns.map((c, i) => <span key={i}>{c}</span>)}
    </div>}
    {windowRows(rows, max).map((r, i) => r
      ? <div key={`${r.rank}-${r.name}`} className={`ah-board__row${r.self ? " is-self" : ""}`} style={grid}>
          <b>{r.rank}</b>
          <span className="ah-board__name">{r.team != null && <i style={{ background: teamColor(teams[r.team - 1]?.color) ?? "var(--o77-ink-300)" }} />}<em>{r.name}</em></span>
          {columns.map((_, c) => <span key={c}>{r.values?.[c] ?? "-"}</span>)}
        </div>
      : <div key={`gap-${i}`} className="ah-board__gap" aria-hidden="true" />)}
  </div>;
}

function Hints({ hints }: { hints: ActivityHint[] }) {
  return <ul className="ah-hints">{hints.map((h, i) => <li key={i}><Keycap size="sm" className="ah-key">{h.key}</Keycap><span>{h.label}</span></li>)}</ul>;
}

function Banner({ banner }: { banner: Stamped<ActivityBanner> }) {
  return <div key={banner.key} className={`ah-banner is-${banner.tone ?? "accent"}`} style={{ "--life": `${banner.durationMs}ms` } as CSSProperties}>
    {banner.title && <b>{banner.title}</b>}
    {banner.text && <p>{banner.text}</p>}
  </div>;
}

function ResultCard({ result }: { result: Stamped<ActivityResult> }) {
  const place = result.placement;
  const numeric = typeof place === "number";
  return <section key={result.key} className={`ah-result${numeric && place === 1 ? " is-first" : ""}`} style={{ "--life": `${result.durationMs}ms` } as CSSProperties}>
    <div className="ah-result__top">
      {place != null && <div className="ah-result__place">{numeric ? <><b>{place}</b><sup>{ordinalSuffix(place)}</sup></> : <b className="is-word">{place}</b>}</div>}
      <div className="ah-result__id">
        <small>RESULT</small>
        {result.title && <h2>{result.title}</h2>}
        {result.subtitle && <p>{result.subtitle}</p>}
      </div>
    </div>
    {(result.lines?.length ?? 0) > 0 && <dl className="ah-result__lines">{result.lines!.map((l, i) => <div key={i}><dt>{l.label}</dt><dd>{l.value}</dd></div>)}</dl>}
    <i className="ah-result__life" aria-hidden="true" />
  </section>;
}
