import { useEffect, useMemo, useRef, useState } from "react";
import { SECTION, SECTIONS, RARITY_LABEL, eddies, roman, type Body, type Cyberware } from "./data";
import { iconImage, sectionVideo, uiImage } from "./media";
import { useParallax } from "./Stage";
import { play } from "./sfx";
import type { Session } from "./App";
import { familyMate, fitPrice, isDropOnly, isFitted, isStored, points, project, refusal, repLabel, type Projection } from "./model";
import { CapacityBar, CapacityVerdict } from "./Hud";

/* The close-up of one section (A/D cycle): the game's paperdoll zoom on the right, tilted in
   depth with the pointer; installed slots and the clinic's stock on the left; the hovered or
   selected implant in a card over the scan, with what the surgery costs and needs (eurodollars,
   street cred, capacity points). Installing is a hold, not a click. An implant taken out goes to
   the patient's storage and is fitted again for the fitting fee; an iconic is never sold. */

type Filter = "all" | "available" | "installed" | "stored";

interface Props {
  body: Body; section: string; session: Session; used: number; leaving: boolean; busy: boolean;
  onBack(): void; onCycle(step: number): void;
  onProcedure(item: Cyberware, mode: "install" | "remove"): string | null;
  /** The implant whose surgery the HUD previews (hovered, else selected), null when none. */
  onPreview(id: string | null): void;
}

export function SectionView({ body, section, session, used, leaving, busy, onBack, onCycle, onProcedure, onPreview }: Props) {
  const def = SECTION[section]!;
  const index = SECTIONS.findIndex((s) => s.id === section);
  const installed = session.installed[section] ?? [];
  const stock = useMemo(() => session.stock.filter((c) => c.section === section), [session.stock, section]);
  const storedHere = stock.filter((c) => isStored(session, c.id)).length;
  const sockets = Math.max(def.slots, installed.length);
  const [filter, setFilter] = useState<Filter>("all");
  const [hoverItem, setHoverItem] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(installed[0] ?? stock[0]?.id ?? null);
  const [error, setError] = useState<string | null>(null);
  const tilt = useParallax<HTMLDivElement>(1.6);

  useEffect(() => { setError(null); }, [selected]);

  const shown = stock.filter((c) => filter === "all"
    || (filter === "installed" ? installed.includes(c.id)
      : filter === "stored" ? isStored(session, c.id)
      : refusal(session, c) === null));
  const focusId = hoverItem ?? selected;
  const focus = focusId ? session.items[focusId] : undefined;
  useEffect(() => { onPreview(leaving ? null : focusId); }, [focusId, leaving, onPreview]);
  useEffect(() => () => onPreview(null), [onPreview]);

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
            <span style={{ left: "64%", top: "74%" }}>IMPLANTS {String(used).padStart(2, "0")} // ONLINE</span>
            <span style={{ left: "22%", top: "70%" }}>
              {session.capacity ? `CAPACITY ${session.capacity.used}/${session.capacity.total}` : "TISSUE // STABLE"}
            </span>
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

        <div className="rd-heading">
          <span>INSTALLED</span><em>{installed.length}/{sockets} SLOTS</em>
          {storedHere > 0 && <em className="rd-stored-count">{storedHere} IN STORAGE</em>}
        </div>
        <div className="rd-installed">
          {Array.from({ length: sockets + def.locked }, (_, k) => {
            const id = installed[k];
            const item = id ? session.items[id] : undefined;
            const locked = k >= sockets;
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
            {(["all", "available", "installed", "stored"] as Filter[]).map((f) => (
              <button key={f} className={filter === f ? "on" : ""} onPointerEnter={() => play("hover")}
                onClick={() => { setFilter(f); play("tick_down"); }}>{f.toUpperCase()}</button>
            ))}
          </div>
        </div>
        <div className="rd-stock">
          {shown.map((item, i) => {
            const fitted = installed.includes(item.id);
            const stored = !fitted && isStored(session, item.id);
            const drop = !fitted && isDropOnly(session, item);
            const why = fitted ? null : refusal(session, item);
            const poor = !fitted && !drop && fitPrice(session, item) > session.wallet;
            const locked = !fitted && !stored && item.locked === true;
            const p = fitted ? undefined : project(session, item);
            return (
              <button key={item.id} style={{ ["--i" as string]: i }}
                className={`rd-card r-${item.rarity} ${selected === item.id ? "selected" : ""} ${fitted ? "owned" : ""} ${why ? `blocked v-${p?.verdict}` : ""} ${locked ? "locked" : ""}`}
                onPointerEnter={() => { setHoverItem(item.id); play("hover"); }} onPointerLeave={() => setHoverItem(null)}
                onClick={() => { setSelected(item.id); play("press"); }}>
                <span className="stripe" />
                {session.capacity && <span className={`pts ${fitted ? "" : p?.verdict === "room" ? "bad" : "fits"}`}>{points(item)} PT</span>}
                <img src={iconImage(item.icon)} alt="" />
                <span className="name">{item.name}</span>
                <span className="meta">
                  <span className="tier">{roman(item.tier)}</span>
                  {fitted ? <span className="ok">INSTALLED</span>
                    : stored ? <span className={`stored ${poor ? "poor" : ""}`}>STORED</span>
                    : drop ? <span className="drop">ICONIC</span>
                    : <span className={`price ${poor ? "poor" : ""}`}>€$ {eddies(item.price)}</span>}
                </span>
                {drop ? <span className="req drop">DROP</span>
                  : locked ? <span className="req lock">REP {roman(item.repTier ?? 0)}</span>
                  : p?.verdict === "room" ? <span className="req room">NO ROOM</span>
                  : p?.verdict === "money" ? <span className="req money">NO €$</span>
                  : why && <span className="req">REQ</span>}
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
        <DetailCard key={focus.id} item={focus} session={session} busy={busy} error={error}
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
  item: Cyberware; session: Session; busy: boolean; error: string | null;
  onAct(mode: "install" | "remove"): void;
}

function DetailCard({ item, session, busy, error, onAct }: CardProps) {
  const fitted = isFitted(session, item.id);
  const stored = !fitted && isStored(session, item.id);
  const drop = !fitted && isDropOnly(session, item);
  const mate = fitted ? undefined : familyMate(session, item);
  const why = refusal(session, item, fitted ? "remove" : "install");
  const price = fitPrice(session, item);
  const cap = session.capacity;
  const p = project(session, item);
  const after = p.after;
  // the capacity line on its own (an implant can be locked AND too heavy): a lighter swap on a body over its limit is fine
  const room = p.over === 0 || (p.mate !== undefined && p.after <= p.used);
  const head = fitted ? "INSTALLED" : stored ? "IN YOUR STORAGE" : drop ? "ICONIC // NOT FOR SALE" : "IN STOCK";
  const label = fitted ? `HOLD TO TAKE OUT · €$ ${eddies(session.fittingFee)}`
    : drop ? "NOT FOR SALE"
    : item.locked && !stored ? `LOCKED · REP ${roman(item.repTier ?? 0)}`
    : why ? "UNAVAILABLE"
    : stored ? `${mate ? "HOLD TO SWAP" : "HOLD TO FIT"} · €$ ${eddies(price)}`
    : mate ? "HOLD TO REPLACE" : "HOLD TO INSTALL";
  return (
    <div className={`rd-detail r-${item.rarity}`}>
      <StatusBanner p={p} item={item} stored={stored} drop={drop} />
      <div className="rd-detail-head">
        <span>{head}</span>
        <em>{item.maker.toUpperCase()}</em>
      </div>
      <div className="rd-detail-title">
        <div>
          <h2>{item.name}</h2>
          <div className="rarity">{RARITY_LABEL[item.rarity] ?? item.rarity} <b>TIER {roman(item.tier)}</b>{cap && <b>{points(item)} PT</b>}</div>
        </div>
        <div className="rd-detail-icon"><img src={iconImage(item.icon)} alt="" /></div>
      </div>
      <p className="effect">{item.effect}</p>
      <ul className="stats">
        {item.stats.map((s) => <li key={s.label}><span>{s.label}</span><b>{s.value}</b></li>)}
      </ul>
      <p className="lore">{item.lore}</p>
      {drop && <div className="rd-source">DROPS FROM <b>{(item.source ?? "bosses and raids").toUpperCase()}</b></div>}
      {!fitted && !drop && (
        <ul className="rd-needs">
          {!stored && item.repTier !== undefined && item.repTier > 1 && (
            <li className={item.locked ? "bad" : "ok"}><span>Street cred</span>
              <b>REP {repLabel(item).toUpperCase()} <i>/ {session.reputation ? roman(session.reputation.tier) : "—"}</i></b></li>
          )}
          {cap && (
            <li className={`rd-need-cap ${room ? "ok" : "bad"}`}><span>Capacity</span>
              <b>{cap.used} → {after} <i>/ {cap.total} PT</i></b>
              <CapacityBar cap={cap} preview={p} className="rd-cap-bar mini" />
              <CapacityVerdict cap={cap} preview={p} />
            </li>
          )}
          <li className={price <= session.wallet ? "ok" : "bad"}><span>{stored ? "Fitting fee" : "Price"}</span>
            <b>€$ {eddies(price)} <i>/ €$ {eddies(session.wallet)}</i></b></li>
        </ul>
      )}
      {mate && !drop && <div className="replace">REPLACES <b>{mate.name}</b> · IT GOES TO YOUR STORAGE</div>}
      {fitted && <div className="rd-detail-foot"><span>INSTALLED</span><span>TAKE OUT → STORAGE · €$ {eddies(session.fittingFee)}</span></div>}
      {fitted && cap && (
        <div className="rd-need-cap ok solo"><span>Capacity after</span><b>{cap.used} → {after} <i>/ {cap.total} PT</i></b>
          <CapacityBar cap={cap} preview={p} className="rd-cap-bar mini" /><CapacityVerdict cap={cap} preview={p} /></div>
      )}
      {(error ?? why) && !drop && <div className="rd-detail-error">{error ?? why}</div>}
      <HoldButton disabled={busy || drop || why !== null} danger={fitted} label={label}
        onDone={() => onAct(fitted ? "remove" : "install")} />
    </div>
  );
}

/* What the surgery would do, in one line at the top of the card: ready (install, swap, fit from
   storage, take out) in green, or the exact reason it would be refused in red. */
function StatusBanner({ p, item, stored, drop }: { p: Projection; item: Cyberware; stored: boolean; drop: boolean }) {
  const [kind, title, sub] = drop ? ["drop", "DROPS ONLY", `Never sold: ${item.source ?? "bosses and raids"} drop it.`]
    : p.mode === "remove" ? (p.verdict === "ok" ? ["remove", "INSTALLED", `Taking it out frees ${p.freed} PT · it goes to your storage`]
      : ["bad", "NOT ENOUGH €$", "Taking it out costs the fitting fee."])
    : p.verdict === "rep" ? ["bad", `STREET CRED ${roman(item.repTier ?? 0)} NEEDED`, `Reach ${item.repName ?? "that tier"} with PvE missions, raids and gigs.`]
    : p.verdict === "room" ? ["bad", "NOT ENOUGH CAPACITY", `Over by ${p.over} PT · take an implant out or raise your street cred`]
    : p.verdict === "money" ? ["bad", "NOT ENOUGH €$", `It costs €$ ${eddies(p.cost)} · you have €$ ${eddies(p.walletAfter + p.cost)}`]
    : p.mate ? ["ok", stored ? "READY TO SWAP" : "READY TO REPLACE", `${p.mate.name} goes to your storage`]
    : ["ok", stored ? "READY TO FIT" : "READY TO INSTALL", stored ? "From your storage · fitting fee only" : "Surgery included"];
  return (
    <div key={`${kind}:${title}`} className={`rd-status ${kind}`}>
      <i className="dot" /><b>{title}</b><span>{sub}</span>
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
