import { useEffect, useMemo, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type RentalDialogPayload, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import { matchesToggleKey } from "@/features/inventory/model";
import { VehicleArt } from "./VehicleArt";
import { filterStock, formatLeft, type RentalSort } from "./model";
import "./rental.css";

export function RentalDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "rental";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "rental", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "rental") closeDialog(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, closeDialog]);
  if (dialog?.kind !== "rental") return null;
  return <RentalBody key={dialog.spot.id} payload={dialog} onClose={closeDialog} />;
}

function RentalBody({ payload, onClose }: { payload: RentalDialogPayload; onClose: () => void }) {
  const { spot } = payload;
  const money = useStore((s) => s.state.money);
  const rental = useStore((s) => s.state.rental);
  const rentalAt = useStore((s) => s.rentalReceivedAt);
  const result = useStore((s) => s.lastResult);
  const root = useRef<HTMLDivElement>(null);
  const [selected, setSelected] = useState(spot.stock[0]?.key ?? "");
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All");
  const [sort, setSort] = useState<RentalSort>("price-asc");
  const [pay, setPay] = useState<"cash" | "bank">("cash");
  const [confirmReturn, setConfirmReturn] = useState(false);
  const [sent, setSent] = useState<string | null>(null);
  const pending = useRef<string | null>(null);
  const resultBefore = useRef(result);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean } | null>(null);
  const [, tick] = useState(0);
  const active = rental.active;
  const categories = useMemo(() => ["All", ...new Set(spot.stock.map((item) => item.category))], [spot.stock]);
  const list = useMemo(() => filterStock(spot.stock, query, category, sort), [spot.stock, query, category, sort]);
  const item = list.find((entry) => entry.key === selected) ?? list[0];
  const balance = pay === "bank" ? (money.bank?.balance ?? 0) : money.cash;
  const short = item ? Math.max(0, item.price - balance) : 0;
  const fmt = (value: number) => formatMoney(value, money.currency);
  const left = active ? Math.max(0, active.remainingMs - (Date.now() - rentalAt)) : 0;
  const canRent = !!item && !active && !sent && short === 0 && (pay !== "bank" || !!money.bank);

  useEffect(() => {
    if (!active) { setConfirmReturn(false); return; }
    const timer = window.setInterval(() => tick((t) => t + 1), 1000);
    return () => window.clearInterval(timer);
  }, [active]);
  useEffect(() => {
    if (!result || result === resultBefore.current || result.action !== pending.current) return;
    const action = pending.current;
    resultBefore.current = result; pending.current = null; setSent(null); setConfirmReturn(false);
    setFeedback({ text: result.text, error: !result.ok });
    if (result.ok && action === "rental.rent") onClose();
  }, [result, onClose]);
  useEffect(() => {
    if (!sent) return;
    const timer = window.setTimeout(() => setFeedback({ text: "The server has not confirmed yet. Close and reopen the desk to check your rental before trying again.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [sent]);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (matchesToggleKey(e, "ESCAPE")) {
        e.preventDefault(); e.stopPropagation();
        if (!e.repeat) { if (confirmReturn) setConfirmReturn(false); else onClose(); }
      }
      if (e.key === "Tab") {
        const controls = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select, [tabindex="0"]') ?? [])
          .filter((el) => el.getClientRects().length > 0);
        const first = controls[0], last = controls[controls.length - 1];
        if (e.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { e.preventDefault(); last?.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [confirmReturn, onClose]);

  const issue = (action: UiAction) => {
    if (pending.current) return;
    pending.current = action.type; resultBefore.current = useStore.getState().lastResult;
    setSent(action.type); setFeedback(null); sendAction(action);
  };
  const resetFilters = () => { setQuery(""); setCategory("All"); };

  return <div ref={root} tabIndex={-1} className="rental o77-interactive" role="dialog" aria-modal="true" aria-labelledby="rental-title">
    <div className="rental__workspace">
      <header className="rental__header">
        <div><span className="rental__eyebrow"><b>LIGHT RP</b> / GET AROUND NIGHT CITY</span><h1 id="rental-title">Your next ride<span>.</span></h1></div>
        <button className="rental__close" onClick={onClose} aria-label="Close rental">Close <kbd>Esc</kbd><Icon name="x" size={18} /></button>
      </header>
      <div className="rental__location"><span><Icon name="map-pin" size={14} />{spot.name}</span><span><Icon name="clock" size={14} />{spot.durationMinutes} min per rental</span></div>
      <div className="rental__layout">
        <section className="rental-catalogue" aria-label="Vehicle catalogue">
          <div className="rental__tools">
            <label className="rental-search"><Icon name="search" size={16} /><input disabled={!!sent} aria-label="Search vehicles" placeholder="Find your ride…" value={query} onChange={(e) => setQuery(e.target.value)} />{query && <button disabled={!!sent} aria-label="Clear search" onClick={() => setQuery("")}><Icon name="x" size={14} /></button>}</label>
            <label className="rental-sort"><span>Sort by</span><select disabled={!!sent} aria-label="Sort vehicles" value={sort} onChange={(e) => setSort(e.target.value as RentalSort)}><option value="price-asc">Lowest price</option><option value="price-desc">Highest price</option><option value="name">Name A–Z</option></select></label>
          </div>
          <div className="rental__filters" aria-label="Vehicle categories">{categories.map((value) => <button key={value} disabled={!!sent} aria-pressed={category === value} onClick={() => setCategory(value)}>{value}<span>{value === "All" ? spot.stock.length : spot.stock.filter((entry) => entry.category === value).length}</span></button>)}</div>
          <div className="rental-grid" aria-label="Available vehicles">
            {list.map((entry) => <button key={entry.key} disabled={!!sent} className={`rental-card${item?.key === entry.key ? " is-selected" : ""}`} aria-pressed={item?.key === entry.key} aria-label={`Select ${entry.label}`} onClick={() => { setSelected(entry.key); setFeedback(null); }}>
              <div className="rental-card__visual"><VehicleArt vehicle={entry} /><span className="rental-card__category">{entry.category}</span>{item?.key === entry.key && <span className="rental-card__selected"><Icon name="check" size={14} /></span>}</div>
              <div className="rental-card__body"><h2>{entry.label}</h2><div><span>{spot.durationMinutes} minutes</span><strong>{fmt(entry.price)}</strong></div></div>
            </button>)}
            {list.length === 0 && <div className="rental-empty"><Icon name={spot.stock.length ? "search" : "car"} size={34} /><h2>{spot.stock.length ? "No matching rides" : "The lot is empty"}</h2><p>{spot.stock.length ? "Try a different name or category." : "No vehicles are offered at this desk right now."}</p>{spot.stock.length > 0 && <button className="rental__text-button" onClick={resetFilters}>Clear filters <Icon name="arrow-right" size={14} /></button>}</div>}
          </div>
          <div className="rental-catalogue__foot"><span>{list.length} {list.length === 1 ? "vehicle" : "vehicles"}{list.length !== spot.stock.length ? ` / ${spot.stock.length}` : ""}</span><span>Vehicle photos · VULKK / CDPR · Colours may vary</span></div>
        </section>
        <aside className="rental-summary" aria-label={active ? "Current rental" : "Reservation summary"} aria-busy={!!sent}>
          {active ? <>
            <span className="rental__eyebrow rental__eyebrow--accent">YOUR CURRENT RENTAL</span>
            <div className="rental-summary__photo"><VehicleArt vehicle={active} /></div>
            <h2>{active.label}</h2><p className="rental-summary__intro">You already have a ride. Return it before choosing another.</p>
            <div className="rental-timer"><Icon name="clock" size={20} /><div><span>Time remaining</span><strong>{formatLeft(left)}</strong></div></div>
            <dl className="rental-facts"><div><dt>Collected from</dt><dd>{active.spotName}</dd></div><div><dt>Paid by {active.paidWith}</dt><dd>{fmt(active.price)}</dd></div></dl>
            <div className="rental-summary__bottom">
              {confirmReturn ? <div className="rental-confirm" role="group" aria-label="Confirm return"><h3>Return this vehicle?</h3><p>It will be removed from the world. The rental fee is not refunded.</p><button className="rental__primary" disabled={!!sent} onClick={() => issue({ type: "rental.return" })}>{sent ? "Returning…" : "Confirm return"}<Icon name={sent ? "loader" : "check"} size={16} /></button><button className="rental__text-button" disabled={!!sent} onClick={() => setConfirmReturn(false)}>Keep my rental</button></div>
                : <><button className="rental__secondary" disabled={!!sent} onClick={() => setConfirmReturn(true)}>Return vehicle<Icon name="arrow-left-right" size={16} /></button><p className="rental-summary__hint">Return at any rental desk.</p></>}
            </div>
          </> : item ? <>
            <span className="rental__eyebrow">YOUR RESERVATION</span>
            <div className="rental-summary__photo" key={item.key}><VehicleArt vehicle={item} /></div>
            <span className="rental-summary__category">{item.category}</span><h2>{item.label}</h2>
            <dl className="rental-facts"><div><dt><Icon name="clock" size={14} /> Rental period</dt><dd>{spot.durationMinutes} minutes</dd></div><div><dt><Icon name="key-round" size={14} /> Pickup</dt><dd>Outside this desk</dd></div></dl>
            <fieldset className="rental-payment" disabled={!!sent}><legend>Pay with</legend>{(["cash", "bank"] as const).map((method) => <label key={method} className={pay === method ? "is-selected" : ""}>
              <input type="radio" name="rental-payment" value={method} checked={pay === method} disabled={method === "bank" && !money.bank} onChange={() => { setPay(method); setFeedback(null); }} />
              <Icon name={method === "cash" ? "banknote" : "credit-card"} size={18} /><span>{method === "cash" ? "Cash" : "Bank account"}<small>{method === "bank" && !money.bank ? "Unavailable" : fmt(method === "cash" ? money.cash : money.bank?.balance ?? 0)}</small></span><i aria-hidden="true" />
            </label>)}</fieldset>
            <div className="rental-summary__bottom"><div className="rental-total"><span>Total<small>One payment · {spot.durationMinutes} min</small></span><strong>{fmt(item.price)}</strong></div>
              {short > 0 && <p className="rental-short" role="status">You need {fmt(short)} more in {pay === "cash" ? "cash" : "your bank account"}.</p>}
              <button className="rental__primary" disabled={!canRent} onClick={() => { if (canRent) issue({ type: "rental.rent", spot: spot.id, key: item.key, pay }); }}>{sent ? "Reserving your ride…" : "Confirm rental"}<Icon name={sent ? "loader" : "arrow-right"} size={17} /></button>
              <p className="rental-summary__hint">Keys included. The vehicle is collected automatically when time runs out.</p>
            </div>
          </> : <div className="rental-empty rental-empty--summary"><Icon name="key-round" size={28} /><h2>Find your next ride</h2><p>Select a vehicle to review your reservation.</p></div>}
          {feedback && <p className={`rental-feedback${feedback.error ? " is-error" : ""}`} role={feedback.error ? "alert" : "status"}>{feedback.text}</p>}
        </aside>
      </div>
      <footer className="rental__footer"><span><Icon name="key-round" size={14} />One vehicle at a time. Your price is for the entire rental.</span><span><kbd>Esc</kbd> Back to the city</span></footer>
    </div>
  </div>;
}
