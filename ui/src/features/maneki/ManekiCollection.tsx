import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type ManekiDialogPayload } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Button, Icon, Keycap, cx } from "@/design/components";
import { ManekiArt } from "./ManekiArt";
import "./collection.css";

/* F1 > Maneki-neko (server/modules/maneki.lua M.collection): every lucky cat hidden in
   the city as a slot, in the order the staff hid them. A found one shows where and when
   this character found it, and a click (or Enter) opens the city map on that spot with
   every found cat pinned (client/core/maneki.lua showOnMap); a slot not found carries
   nothing, by design. The first opening explains the hunt (`intro`); ? shows it again. */

export interface ManekiSlot { n: number; found: boolean; id?: string; district?: string; at?: number; how?: "take" | "shot" }
export function parseSlot(raw: string, index: number): ManekiSlot {
  if (!raw) return { n: index + 1, found: false };
  const [id, district, at, how] = raw.split("|");
  return { n: index + 1, found: true, id, district: district || undefined, at: Number(at) || undefined, how: how === "shot" ? "shot" : "take" };
}
const COLS = 8;
const pad = (n: number, total: number) => String(n).padStart(Math.max(2, String(total).length), "0");
const when = (at?: number) => at ? new Date(at).toLocaleString([], { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";

export function ManekiCollection() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "maneki";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "maneki", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "maneki") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "maneki", open: false }); };
  }, [visible, closeDialog]);
  if (!visible) return null;
  return <Collection payload={dialog as ManekiDialogPayload} onClose={closeDialog} />;
}

function Collection({ payload, onClose }: { payload: ManekiDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const currency = useStore((s) => s.state.money.currency);
  const result = useStore((s) => s.lastResult);
  const fmt = (n: number) => formatMoney(n, currency);
  const slots = useMemo(() => payload.slots.map(parseSlot), [payload.slots]);
  const firstFound = Math.max(0, slots.findIndex((s) => s.found));
  const [index, setIndex] = useState(firstFound);
  const [intro, setIntro] = useState(payload.intro === true);
  const [feedback, setFeedback] = useState<string | null>(null);
  const opened = useRef(result);
  const selected = slots[index];
  const found = payload.found, total = payload.total;
  const ratio = total > 0 ? found / total : 0;
  const next = payload.milestones.filter((m) => m.count > found).sort((a, b) => a.count - b.count)[0];
  const complete = total > 0 && found >= total;
  const titleReady = total >= payload.completeMin;

  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => { if (result && result !== opened.current && result.action === "maneki.map" && !result.ok) setFeedback(result.text); }, [result]);
  const showOnMap = (slot?: ManekiSlot) => { if (slot?.found && slot.id) { setFeedback(null); sendAction({ type: "maneki.map", id: slot.id }); } };
  const closeIntro = () => { if (payload.intro) sendAction({ type: "maneki.intro" }); payload.intro = false; setIntro(false); root.current?.focus(); };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      let handled = true;
      if (intro) {
        if (e.key === "Escape" || e.key === "Enter" || e.key === " ") closeIntro(); else handled = false;
      } else if (e.key === "Escape" || e.key === "Backspace") { if (!e.repeat) onClose(); }
      else if (e.key === "ArrowRight") setIndex((i) => Math.min(slots.length - 1, i + 1));
      else if (e.key === "ArrowLeft") setIndex((i) => Math.max(0, i - 1));
      else if (e.key === "ArrowDown") setIndex((i) => Math.min(slots.length - 1, i + COLS));
      else if (e.key === "ArrowUp") setIndex((i) => Math.max(0, i - COLS));
      else if (e.key === "Enter") showOnMap(slots[index]);
      else if (e.key === "?" || e.key.toLowerCase() === "h") setIntro(true);
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    };
    const onContext = (e: MouseEvent) => { e.preventDefault(); if (intro) closeIntro(); else onClose(); };
    window.addEventListener("keydown", onKey, true);
    window.addEventListener("contextmenu", onContext, true);
    return () => { window.removeEventListener("keydown", onKey, true); window.removeEventListener("contextmenu", onContext, true); };
  });
  useEffect(() => { document.getElementById(`maneki-slot-${index}`)?.scrollIntoView({ block: "nearest" }); }, [index]);

  return <div className="maneki o77-interactive" role="dialog" aria-modal="true" aria-labelledby="maneki-title" ref={root} tabIndex={-1}>
    <header className="maneki__bar">
      <span className="maneki__bar-title" id="maneki-title"><Icon name="coins" size={15} />MANEKI-NEKO</span>
      <span className="maneki__bar-route">LUCKY CATS OF NIGHT CITY
        <button className="maneki__help" onClick={() => setIntro(true)}><Icon name="circle-help" size={14} />HOW IT WORKS</button>
        <button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button>
      </span>
    </header>

    <section className="maneki__strip" aria-label="Your collection">
      <div className="maneki-progress">
        <span className="maneki-progress__count"><b>{found}</b><em>/ {total}</em></span>
        <span className="maneki-progress__text"><small>FOUND BY THIS CHARACTER</small>
          <i className="maneki-progress__bar" aria-hidden><i style={{ width: `${ratio * 100}%` }} /></i>
          <small>{total === 0 ? "NO CAT HIDDEN YET" : complete ? "COLLECTION COMPLETE" : `${total - found} STILL OUT THERE`}</small></span>
      </div>
      <div className="maneki-stat"><Icon name="coins" size={15} /><span><small>EVERY FIND</small><b>+{fmt(payload.reward)}</b></span></div>
      <div className={cx("maneki-stat", !next && "is-done")}><Icon name="badge-check" size={15} />
        <span><small>{next ? `NEXT MILESTONE · ${next.count} FOUND` : "NEXT MILESTONE"}</small>
          <b>{next ? [next.cash > 0 ? `+${fmt(next.cash)}` : "", milestoneItems(next) ? `+${milestoneItems(next)}` : ""].filter(Boolean).join(" ") : "ALL PAID"}</b></span></div>
      {payload.title && <div className={cx("maneki-stat", complete && titleReady && "is-done")}><Icon name="crown" size={15} />
        <span><small>TITLE · {payload.title.label.toUpperCase()}</small><b>{complete && titleReady ? "EARNED" : titleReady ? "FIND THEM ALL" : `FROM ${payload.completeMin} CATS`}</b></span></div>}
    </section>

    <div className="maneki__main">
      <section className="maneki__grid" aria-label="Slots">
        {slots.length === 0 && <p className="maneki__empty"><Icon name="search" size={14} />No Maneki-neko is hidden in the city yet. The staff place them; check again later.</p>}
        {slots.map((s, i) => <button key={i} id={`maneki-slot-${i}`} className={cx("maneki-card", s.found ? "is-found" : "is-locked", i === index && "is-selected")}
          onMouseEnter={() => setIndex(i)} onFocus={() => setIndex(i)} onClick={() => { setIndex(i); showOnMap(s); }}
          aria-label={s.found ? `Maneki-neko ${s.n}, found in ${s.district ?? "Night City"}. Show on the map.` : `Maneki-neko ${s.n}, not found yet`}>
          <span className="maneki-card__n">#{pad(s.n, total)}</span>
          <ManekiArt locked={!s.found} size={58} />
          <span className="maneki-card__label">{s.found ? (s.district ?? "Night City") : "???"}</span>
          {s.found && <span className="maneki-card__how" title={s.how === "shot" ? "Shot down" : "Taken"}><Icon name={s.how === "shot" ? "crosshair" : "hand"} size={11} /></span>}
        </button>)}
      </section>

      <aside className="maneki__detail" aria-live="polite">
        {selected ? <>
          <div className={cx("maneki__portrait", selected.found ? "is-found" : "is-locked")}><ManekiArt locked={!selected.found} size={150} /></div>
          <small className="maneki__detail-n">MANEKI-NEKO #{pad(selected.n, total)}</small>
          {selected.found ? <>
            <h2>{selected.district ?? "Night City"}</h2>
            <dl>
              <dt>Found</dt><dd>{when(selected.at)}</dd>
              <dt>How</dt><dd>{selected.how === "shot" ? "Shot down" : "Taken by hand"}</dd>
            </dl>
            <Button variant="primary" icon="map-pin" block onClick={() => showOnMap(selected)}>Show on the city map</Button>
            <p className="maneki__note">The map opens on the spot where you found it, with every cat of your collection pinned. Close the map to come back here.</p>
          </> : <>
            <h2>Not found yet</h2>
            <p className="maneki__note">Somewhere in Night City. No marker, no hint: keep your eyes open.</p>
          </>}
        </> : <p className="maneki__note">Your collection shows here.</p>}
      </aside>
    </div>

    <footer className="maneki__foot">
      <span className={cx("maneki__feedback", feedback && "is-error")} role={feedback ? "alert" : "status"}>
        {feedback ?? "PAID INTO YOUR BANK · EACH CAT ONCE PER CHARACTER · ONLY YOU SEE YOUR CATS"}
      </span>
      <span className="maneki__keys">
        <span><Keycap size="sm">← ↑ → ↓</Keycap>SELECT</span>
        <span><Keycap size="sm">ENTER</Keycap>MAP</span>
        <span><Keycap size="sm">?</Keycap>HELP</span>
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>

    {intro && <Intro reward={fmt(payload.reward)} first={payload.intro === true} title={payload.title?.label} onDone={closeIntro} />}
  </div>;
}

/** A milestone's TCG product, short: "2 BOOSTERS", "1 DISPLAY + 3 BOOSTERS" ("" for none). */
function milestoneItems(m: { items?: Array<{ name: string; count: number }> }): string {
  const parts = (m.items ?? []).map((it) => {
    const kind = it.name.includes("display") ? "DISPLAY" : "BOOSTER";
    return `${it.count} ${kind}${it.count > 1 ? "S" : ""}`;
  });
  return parts.join(" + ");
}

function Intro({ reward, first, title, onDone }: { reward: string; first: boolean; title?: string; onDone(): void }) {
  const steps: Array<{ icon: "eye" | "hand" | "coins" | "crown" | "map-pin"; head: string; body: string }> = [
    { icon: "eye", head: "Hidden in Night City", body: "Lucky cats are tucked away all over the city: on counters, shelves, ledges, rooftops. No map marker, no blip, no hint. You find them by looking." },
    { icon: "hand", head: "Take it or shoot it", body: "Walk up to a cat and press E, or hit it with a shot from a distance. Each cat counts once for your character, and only you see the ones you still have to find." },
    { icon: "coins", head: "Paid on the spot", body: `Every cat pays ${reward} into your bank. Milestones pay more along the way, with Cyberpunk TCG boosters and displays.` },
    { icon: "crown", head: "The whole set", body: title ? `Find every cat in the city to earn the title "${title}".` : "Find every cat in the city to complete the collection." },
    { icon: "map-pin", head: "Your collection, here", body: "F1 > Maneki-neko. Click a cat you found to see on the city map where you found it." },
  ];
  return <div className="maneki-intro" role="dialog" aria-modal="true" aria-labelledby="maneki-intro-title">
    <div className="maneki-intro__card">
      <div className="maneki-intro__art"><ManekiArt size={120} /></div>
      <div className="maneki-intro__body">
        <small>{first ? "NEW COLLECTION" : "HOW IT WORKS"}</small>
        <h2 id="maneki-intro-title">The Maneki-neko hunt</h2>
        <ol>{steps.map((s, i) => <li key={s.icon} style={{ animationDelay: `${0.08 + i * 0.07}s` }}>
          <span className="maneki-intro__icon"><Icon name={s.icon} size={16} /></span>
          <span><b>{s.head}</b><span>{s.body}</span></span></li>)}</ol>
        <footer><Button variant="primary" icon="search" onClick={onDone} autoFocus>{first ? "Start hunting" : "Got it"}</Button><span><Keycap size="sm">ENTER</Keycap></span></footer>
      </div>
    </div>
  </div>;
}
