import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type DealershipDialogPayload, type DealershipUpdate } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { VehicleArt } from "@/features/rental/VehicleArt";
import { filterStock, type RentalSort } from "@/features/rental/model";
import "./dealership.css";

export function DealershipDialog() {
  const dialog = useStore(s => s.dialog);
  const close = useStore(s => s.closeDialog);
  const visible = dialog?.kind === "dealership";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "dealership", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, p => { if (!p?.kind || p.kind === "dealership") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "dealership", open: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "dealership") return null;
  return <Showroom key={dialog.session} payload={dialog} onClose={close} />;
}

function Showroom({ payload, onClose }: { payload: DealershipDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All");
  const [sort, setSort] = useState<RentalSort>("price-asc");
  const [selected, setSelected] = useState(payload.stock[0]?.key);
  const [pay, setPay] = useState<"bank" | "cash">("bank");
  const [confirm, setConfirm] = useState(false);
  const [waiting, setWaiting] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean; vehicle?: string }>();
  const pending = useRef<number>();
  const done = useRef(0);
  const list = useMemo(() => filterStock(payload.stock, query, category, sort), [payload.stock, query, category, sort]);
  const selection = list.find(v => v.key === selected) ?? list[0];
  const item = payload.stock.find(v => v.key === selection?.key);
  const categories = ["All", ...new Set(payload.stock.map(v => v.category))];
  const balance = payload.money[pay];
  const short = Math.max(0, (item?.price ?? 0) - balance);
  const fmt = (n: number) => formatMoney(n, payload.money.currency);
  const close = () => { sendAction({ type: "dealership.close", session: payload.session }); onClose(); };
  useEffect(() => on<DealershipUpdate>("lightrp:ui:dealership", update => {
    if (update.session !== payload.session) return;
    if (update.closed) { onClose(); return; }
    if (update.state) useStore.getState().openDialog(update.state);
    if (update.request == null || update.request !== pending.current || update.request <= done.current) return;
    done.current = update.request; pending.current = undefined;
    setWaiting(false); setConfirm(false);
    setFeedback({ text: update.text ?? "Purchase processed.", error: !update.ok, vehicle: update.vehicleId });
  }), [payload.session, onClose]);
  useEffect(() => {
    if (!waiting) return;
    const timer = window.setTimeout(() => setFeedback({ text: "Your purchase is still awaiting confirmation. Do not pay again. Close and reopen to check your balance and garage.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [waiting]);
  useEffect(() => { setConfirm(false); }, [item?.key, pay]);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  const buy = () => {
    if (!item || short > 0 || pending.current != null) return;
    pending.current = payload.nextRequest; setWaiting(true); setFeedback(undefined);
    sendAction({ type: "dealership.buy", session: payload.session, request: payload.nextRequest, key: item.key, pay });
  };
  return <div className="dealership o77-interactive" role="dialog" aria-modal="true" aria-labelledby="dealer-title" tabIndex={-1} ref={root}
    onKeyDown={e => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); if (!e.repeat) { if (confirm && !waiting) setConfirm(false); else close(); } }
      if (e.key === "Tab") {
        const elements = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), select:not(:disabled)') ?? []);
        if (e.shiftKey && (document.activeElement === elements[0] || document.activeElement === root.current)) { e.preventDefault(); elements.at(-1)?.focus(); }
        else if (!e.shiftKey && (document.activeElement === elements.at(-1) || document.activeElement === root.current)) { e.preventDefault(); elements[0]?.focus(); }
      }
    }}>
    <div className="dealer__workspace">
      <header className="dealer__header"><div><span className="dealer__eyebrow">LIGHT RP <i>/</i> {payload.dealer.name.toUpperCase()}</span><h1 id="dealer-title">Find your next ride<span>.</span></h1><p>{payload.dealer.subtitle}</p></div><button className="dealer__close" onClick={close}>Close <kbd>Esc</kbd><Icon name="x" size={17} /></button></header>
      <div className="dealer__bar"><span><Icon name="map-pin" size={15} />{payload.dealer.name}<i>/</i> Vehicle showroom</span><div><span>Cash <strong>{fmt(payload.money.cash)}</strong></span><span>Bank <strong>{fmt(payload.money.bank)}</strong></span></div></div>
      <div className="dealer__layout">
        <section className="dealer__catalogue" aria-label="Vehicles for sale">
          <div className="dealer__search-row"><label className="dealer__search"><Icon name="search" size={16} /><input aria-label="Search showroom" placeholder="Search the showroom…" disabled={waiting} value={query} onChange={e => setQuery(e.target.value)} /></label><select aria-label="Sort showroom" disabled={waiting} value={sort} onChange={e => setSort(e.target.value as RentalSort)}><option value="price-asc">Price: low to high</option><option value="price-desc">Price: high to low</option><option value="name">Name A–Z</option></select></div>
          <nav className="dealer__filters" aria-label="Vehicle categories">{categories.map(c => <button key={c} aria-pressed={category === c} disabled={waiting} onClick={() => setCategory(c)}>{c}</button>)}</nav>
          <div className="dealer__cars">{list.map(v => <button className={`dealer-car${item?.key === v.key ? " is-selected" : ""}`} key={v.key} aria-pressed={item?.key === v.key} aria-label={`Select ${v.label}`} disabled={waiting} onClick={() => { setSelected(v.key); setFeedback(undefined); }}>
            <div className="dealer-car__image"><VehicleArt vehicle={v} />{item?.key === v.key && <span><Icon name="check" size={13} /></span>}</div><div className="dealer-car__copy"><span>{v.category}</span><h2>{v.label}</h2><strong>{fmt(v.price)}</strong></div><Icon name="arrow-right" size={15} />
          </button>)}{!list.length && <div className="dealer__empty"><Icon name="search" size={32} /><h2>{payload.stock.length ? "No matching rides" : "Showroom coming soon"}</h2><p>{payload.stock.length ? "Try another name or category." : "There are no vehicles for sale at this location yet."}</p>{!!payload.stock.length && <button onClick={() => { setQuery(""); setCategory("All"); }}>Reset filters</button>}</div>}</div>
          <footer className="dealer__catalogue-foot">{list.length} vehicles <span>Ownership is tied to your character.</span></footer>
        </section>
        <aside className="dealer__detail" aria-label="Purchase details" aria-busy={waiting}>
          {item ? <><div className="dealer__hero"><VehicleArt vehicle={item} /><span className="dealer__hero-label">{item.category.toUpperCase()} COLLECTION</span></div>
            <div className="dealer__overview"><div><span className="dealer__eyebrow">MAKE IT YOURS</span><h2>{item.label}</h2></div><div className="dealer__price"><small>Purchase price</small><strong>{fmt(item.price)}</strong></div></div>
            <p className="dealer__description">{item.description}</p>
            <div className="dealer__delivery"><Icon name="key-round" size={18} /><div><strong>Ready at your public garage</strong><span>{payload.garage.name}</span></div><span>INCLUDED</span></div>
            {!feedback?.vehicle && <><fieldset className="dealer__payment" disabled={waiting}><legend>Payment method</legend>{(["bank", "cash"] as const).map(method => <label key={method} className={pay === method ? "is-selected" : ""}><input type="radio" name="dealer-payment" value={method} checked={pay === method} onChange={() => setPay(method)} /><Icon name={method === "bank" ? "credit-card" : "banknote"} size={18} /><span>{method === "bank" ? "Bank account" : "Cash"}<small>{fmt(payload.money[method])} available</small></span><i /></label>)}</fieldset>
              <div className="dealer__checkout">
                {confirm ? <div className="dealer__confirmation" role="group" aria-label="Confirm vehicle purchase"><h3>Make this {item.label} yours?</h3><p>{fmt(item.price)} will be taken from your {pay === "bank" ? "bank account" : "cash"}. The vehicle will be delivered to {payload.garage.name}. This is a purchase, not a rental.</p><button className="dealer__primary" disabled={waiting || short > 0} onClick={buy}>{waiting ? "Processing purchase…" : `Confirm purchase · ${fmt(item.price)}`}<Icon name={waiting ? "loader" : "check"} size={17} /></button><button className="dealer__back" disabled={waiting} onClick={() => setConfirm(false)}>Back to details</button></div>
                  : <><div className="dealer__total"><span>Total <small>No additional fees</small></span><strong>{fmt(item.price)}</strong></div><button className="dealer__primary" disabled={waiting || short > 0} onClick={() => setConfirm(true)}>Review purchase<Icon name="arrow-right" size={17} /></button></>}
                {short > 0 ? <p className="dealer__short" role="status">You need {fmt(short)} more in your {pay === "bank" ? "bank account" : "cash"}.</p> : <p className="dealer__balance">Balance after purchase <strong>{fmt(balance - item.price)}</strong></p>}
              </div></>}
            {feedback && <div className={`dealer__feedback${feedback.error ? " is-error" : ""}${feedback.vehicle ? " is-purchased" : ""}`} role="status"><Icon name={feedback.error ? "triangle-alert" : "check-check"} size={20} /><div>{feedback.vehicle && <h3>The keys are yours.</h3>}<p>{feedback.text}</p>{feedback.vehicle && <><code>OWNERSHIP #{feedback.vehicle.slice(0, 8).toUpperCase()}</code><button className="dealer__primary" onClick={close}>Head to the garage<Icon name="arrow-right" size={17} /></button></>}</div></div>}
          </> : <div className="dealer__empty"><Icon name="car" size={40} /><h2>A new chapter awaits.</h2><p>Select a vehicle to see the details.</p></div>}
        </aside>
      </div>
      <footer className="dealer__footer"><Icon name="shield" size={14} /><span>Permanent ownership · Saved condition & trunk · Garage recovery after server restarts</span><span>Photos: VULKK / CDPR. Appearance may vary.</span></footer>
    </div>
  </div>;
}
