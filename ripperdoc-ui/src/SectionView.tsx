import { useEffect, useMemo, useRef, useState } from "react";
import { SECTION, SECTIONS, RARITY_LABEL, eddies, roman, type Body, type Cyberware } from "./data";
import { iconImage, sectionVideo, uiImage } from "./media";
import { useParallax } from "./Stage";
import { play } from "./sfx";
import { familyMate, refusal, type Session } from "./App";

/* The close-up of one section (A/D cycle): the game's paperdoll zoom on the right, tilted in
   depth with the pointer; installed slots and the clinic's stock on the left; the hovered or
   selected implant in a card over the scan, with what the surgery costs and needs. Installing
   is a hold, not a click. */

type Filter = "all" | "available" | "installed";

interface Props {
  body: Body; section: string; session: Session; used: number; leaving: boolean; busy: boolean;
  onBack(): void; onCycle(step: number): void;
  onProcedure(item: Cyberware, mode: "install" | "remove"): string | null;
}

export function SectionView({ body, section, session, used, leaving, busy, onBack, onCycle, onProcedure }: Props) {
  const def = SECTION[section]!;
  const index = SECTIONS.findIndex((s) => s.id === section);
  const installed = session.installed[section] ?? [];
  const stock = useMemo(() => session.stock.filter((c) => c.section === section), [session.stock, section]);
  const [filter, setFilter] = useState<Filter>("all");
  const [hoverItem, setHoverItem] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(installed[0] ?? stock[0]?.id ?? null);
  const [error, setError] = useState<string | null>(null);
  const tilt = useParallax<HTMLDivElement>(1.6);

  useEffect(() => { setError(null); }, [selected]);

  const shown = stock.filter((c) => filter === "all" || (filter === "installed" ? installed.includes(c.id) : refusal(session, c) === null));
  const focusId = hoverItem ?? selected;
  const focus = focusId ? session.items[focusId] : undefined;

  return (
    <div className={`rd-section ${leaving ? "is-leaving" : ""}`}>
      <div className="rd-closeup" ref={tilt}>
        <div className="rd-closeup-plane">
          <video key={`${body}_${section}`} className="rd-closeup-video" src={sectionVideo(body, section)} autoPlay loop muted playsInline />
          <div className="rd-closeup-glow" />
          <img className="rd-closeup-ring" src={uiImage("circle_1")} alt="" />
          <div className="rd-closeup-tags">
            <span style={{ left: "16%", top: "22%" }}>[{def.code}]</span>
            <span style={{ left: "70%", top: "30%" }}>SYNC {94 + (index % 5)}.{index}%</span>
            <span style={{ left: "64%", top: "74%" }}>NEURAL LOAD {Math.round((used / Math.max(1, session.capacityMax)) * 100)}%</span>
            <span style={{ left: "22%", top: "70%" }}>TISSUE // STABLE</span>
          </div>
          <div className="rd-brackets"><i /><i /><i /><i /></div>
        </div>
      </div>

      <div className="rd-panel">
        <div className="rd-nav">
          <button className="rd-key" onClick={() => onCycle(-1)} onPointerEnter={() => play("hover")}>◁ <kbd>A</kbd></button>
          <div className="rd-nav-title">
            <span className="code">{def.code}</span>
            <span className="name" data-text={def.label.toUpperCase()}>{def.label.toUpperCase()}</span>
          </div>
          <button className="rd-key" onClick={() => onCycle(1)} onPointerEnter={() => play("hover")}><kbd>D</kbd> ▷</button>
        </div>
        <div className="rd-ticks">{SECTIONS.map((s, i) => <i key={s.id} className={i === index ? "on" : ""} />)}</div>
        <p className="rd-blurb">{def.blurb}</p>

        <div className="rd-heading"><span>INSTALLED</span><em>{installed.length}/{def.slots} SLOTS</em></div>
        <div className="rd-installed">
          {Array.from({ length: def.slots + def.locked }, (_, k) => {
            const id = installed[k];
            const item = id ? session.items[id] : undefined;
            const locked = k >= def.slots;
            return (
              <button key={k} disabled={locked}
                className={`rd-socket ${item ? `filled r-${item.rarity}` : locked ? "locked" : "empty"} ${focusId === id && id ? "focus" : ""}`}
                onPointerEnter={() => { play("hover"); if (id) setHoverItem(id); }} onPointerLeave={() => setHoverItem(null)}
                onClick={() => { if (locked) { play("denied"); return; } play("press"); if (id) setSelected(id); }}>
                {item ? <img src={iconImage(item.icon)} alt="" /> : locked ? <span className="lock">LICENCE<br />REQUIRED</span> : <span className="plus" />}
              </button>
            );
          })}
        </div>

        <div className="rd-heading">
          <span>CLINIC STOCK</span><em>{stock.length} IMPLANTS</em>
          <div className="rd-filters">
            {(["all", "available", "installed"] as Filter[]).map((f) => (
              <button key={f} className={filter === f ? "on" : ""} onPointerEnter={() => play("hover")}
                onClick={() => { setFilter(f); play("tick_down"); }}>{f.toUpperCase()}</button>
            ))}
          </div>
        </div>
        <div className="rd-stock">
          {shown.map((item, i) => {
            const owned = installed.includes(item.id);
            const why = owned ? null : refusal(session, item);
            const poor = !owned && item.price > session.wallet;
            return (
              <button key={item.id} style={{ ["--i" as string]: i }}
                className={`rd-card r-${item.rarity} ${selected === item.id ? "selected" : ""} ${owned ? "owned" : ""} ${why ? "blocked" : ""}`}
                onPointerEnter={() => { setHoverItem(item.id); play("hover"); }} onPointerLeave={() => setHoverItem(null)}
                onClick={() => { setSelected(item.id); play("press"); }}>
                <span className="stripe" />
                <img src={iconImage(item.icon)} alt="" />
                <span className="name">{item.name}</span>
                <span className="meta">
                  <span className="tier">{roman(item.tier)}</span>
                  {owned ? <span className="ok">INSTALLED</span> : <span className={`price ${poor ? "poor" : ""}`}>€$ {eddies(item.price)}</span>}
                </span>
                {why && <span className="req">REQ</span>}
              </button>
            );
          })}
          {stock.length === 0 && <div className="rd-empty">NO COMPATIBLE IMPLANT IN STOCK<br /><small>This clinic cannot fit this system yet.</small></div>}
          {stock.length > 0 && shown.length === 0 && <div className="rd-empty">NOTHING MATCHES THIS FILTER</div>}
        </div>
        <button className="rd-back" onClick={() => { play("press"); onBack(); }} onPointerEnter={() => play("hover")}>
          <kbd>ESC</kbd> BACK TO FULL BODY
        </button>
      </div>

      {focus && (
        <DetailCard key={focus.id} item={focus} session={session} used={used} owned={installed.includes(focus.id)} busy={busy} error={error}
          onAct={(mode) => {
            const why = onProcedure(focus, mode);
            setError(why);
            if (!why) setSelected(focus.id);
          }} />
      )}
    </div>
  );
}

interface CardProps {
  item: Cyberware; session: Session; used: number; owned: boolean; busy: boolean; error: string | null;
  onAct(mode: "install" | "remove"): void;
}

function DetailCard({ item, session, used, owned, busy, error, onAct }: CardProps) {
  const mate = owned ? undefined : familyMate(session, item);
  const why = owned ? null : refusal(session, item);
  const requires = item.requires ? session.items[item.requires] : undefined;
  const requiresOk = !requires || Object.values(session.installed).flat().includes(requires.id);
  const after = used - (mate?.capacity ?? 0) + item.capacity;
  const parts = item.parts ?? 0;
  return (
    <div className={`rd-detail r-${item.rarity}`}>
      <div className="rd-detail-head">
        <span>{owned ? "INSTALLED" : "IN STOCK"}</span>
        <em>{item.maker.toUpperCase()}</em>
      </div>
      <div className="rd-detail-title">
        <div>
          <h2>{item.name}</h2>
          <div className="rarity">{RARITY_LABEL[item.rarity]} <b>TIER {roman(item.tier)}</b></div>
        </div>
        <div className="rd-detail-icon"><img src={iconImage(item.icon)} alt="" /></div>
      </div>
      <p className="effect">{item.effect}</p>
      <ul className="stats">
        {item.stats.map((s) => <li key={s.label}><span>{s.label}</span><b>{s.value}</b></li>)}
      </ul>
      <p className="lore">{item.lore}</p>
      {!owned && (
        <ul className="rd-needs">
          <li className={item.price <= session.wallet ? "ok" : "bad"}><span>Eurodollars</span><b>€$ {eddies(item.price)}</b></li>
          {parts > 0 && <li className={parts <= session.parts.have ? "ok" : "bad"}><span>{session.parts.label}</span><b>{parts} <i>/ {session.parts.have}</i></b></li>}
          <li className={after <= session.capacityMax ? "ok" : "bad"}><span>Capacity</span><b>+{item.capacity} <i>→ {after}/{session.capacityMax}</i></b></li>
          {requires && <li className={requiresOk ? "ok" : "bad"}><span>Requires</span><b>{requires.name}</b></li>}
        </ul>
      )}
      {mate && <div className="replace">REPLACES <b>{mate.name}</b></div>}
      {owned && <div className="rd-detail-foot"><span>▲ {item.capacity} CAPACITY</span><span>REMOVAL €$ {eddies(session.removalFee)}</span></div>}
      {(error ?? why) && <div className="rd-detail-error">{error ?? why}</div>}
      <HoldButton disabled={busy || (!owned && why !== null)} danger={owned}
        label={owned ? "HOLD TO REMOVE" : why ? "UNAVAILABLE" : mate ? "HOLD TO UPGRADE" : "HOLD TO INSTALL"}
        onDone={() => onAct(owned ? "remove" : "install")} />
    </div>
  );
}

/* Hold-to-confirm: a surgery is not a misclick. Mouse or E, 900 ms. */
function HoldButton({ label, disabled, danger, onDone }: { label: string; disabled: boolean; danger: boolean; onDone(): void }) {
  const [progress, setProgress] = useState(0);
  const start = useRef<number | null>(null);
  const frame = useRef(0);
  const ticked = useRef(0);
  const begin = () => {
    if (disabled) { play("denied"); return; }
    if (start.current !== null) return;
    start.current = performance.now();
    ticked.current = 0;
    play("gauge");
    const step = () => {
      if (start.current === null) return;
      const p = Math.min(1, (performance.now() - start.current) / 900);
      setProgress(p);
      if (Math.floor(p * 4) > ticked.current) { ticked.current = Math.floor(p * 4); play("tick_up"); }
      if (p >= 1) { start.current = null; setProgress(0); onDone(); return; }
      frame.current = requestAnimationFrame(step);
    };
    frame.current = requestAnimationFrame(step);
  };
  const end = () => { if (start.current !== null) { start.current = null; cancelAnimationFrame(frame.current); setProgress(0); } };
  // Stable key listeners calling the latest begin/end: a re-render must not cancel a hold.
  const handlers = useRef({ begin, end });
  handlers.current = { begin, end };
  useEffect(() => {
    const down = (e: KeyboardEvent) => { if ((e.key === "e" || e.key === "E" || e.key === "Enter") && !e.repeat) handlers.current.begin(); };
    const up = (e: KeyboardEvent) => { if (e.key === "e" || e.key === "E" || e.key === "Enter") handlers.current.end(); };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    return () => { window.removeEventListener("keydown", down); window.removeEventListener("keyup", up); handlers.current.end(); };
  }, []);
  return (
    <button className={`rd-hold ${danger ? "danger" : ""} ${disabled ? "off" : ""}`}
      onPointerDown={begin} onPointerUp={end} onPointerLeave={end} onPointerEnter={() => play("hover")}>
      <span className="fill" style={{ transform: `scaleX(${progress})` }} />
      <kbd>E</kbd><span className="label">{label}</span>
    </button>
  );
}
