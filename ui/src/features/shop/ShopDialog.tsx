import { useEffect, useMemo, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type ShopDialogPayload, type ShopItem, type ShopUpdate } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { Icon } from "@/design/components";
import { ItemArt } from "@/features/inventory/ItemArt";
import { basketSummary, categoryLabel, filterItems, type Basket, type ShopMode } from "./model";
import "./shop.css";

function Art({ item }: { item: ShopItem }) {
  return <ItemArt item={{ ...item, slot: 0, count: 1, usable: false }} />;
}

export function ShopDialog() {
  const dialog = useStore(s => s.dialog);
  const close = useStore(s => s.closeDialog);
  const visible = dialog?.kind === "shop";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "shop", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, p => { if (!p?.kind || p.kind === "shop") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "shop", open: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "shop") return null;
  return <ShopBody key={dialog.session} payload={dialog} onClose={close} />;
}

function ShopBody({ payload, onClose }: { payload: ShopDialogPayload; onClose: () => void }) {
  const root = useRef<HTMLDivElement>(null);
  const [mode, setMode] = useState<ShopMode>("buy");
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const [ownedOnly, setOwnedOnly] = useState(true);
  const [pay, setPay] = useState<"cash" | "bank">(payload.payments[0] ?? "cash");
  const [baskets, setBaskets] = useState<Record<ShopMode, Basket>>({ buy: {}, sell: {} });
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean }>();
  const pending = useRef<{ request: number; mode: ShopMode }>();
  const done = useRef(0);
  const selectedPay = payload.payments.includes(pay) ? pay : payload.payments[0] ?? "cash";
  const basket = baskets[mode];
  const summary = useMemo(() => basketSummary(payload, basket, mode, selectedPay), [payload, basket, mode, selectedPay]);
  const categories = [...new Set(payload.items.filter(item => item[mode] != null).map(item => item.category))];
  const list = filterItems(payload.items, mode, query, category, ownedOnly);
  const fmt = (n: number) => formatMoney(n, payload.money.currency);
  const close = () => { sendAction({ type: "shop.close", session: payload.session }); onClose(); };

  useEffect(() => on<ShopUpdate>(PAGE_EVENTS.shop, update => {
    if (update.session !== payload.session) return;
    if (update.closed) {
      if (update.text) useStore.getState().pushNotice({ kind: "info", title: "Shop closed", body: update.text, durationMs: 6000 });
      onClose(); return;
    }
    if (update.refresh) {
      if (!pending.current && update.state) useStore.getState().openDialog(update.state);
      return;
    }
    if (update.catalogueChanged) {
      if (pending.current) return;
      setBaskets({ buy: {}, sell: {} });
    } else {
      if (!pending.current || update.request !== pending.current.request || update.request <= done.current) return;
      done.current = update.request;
      const submittedMode = pending.current.mode;
      pending.current = undefined; setBusy(false);
      if (update.ok) setBaskets(previous => ({ ...previous, [submittedMode]: {} }));
    }
    if (update.state) useStore.getState().openDialog(update.state);
    if (update.text) setFeedback({ text: update.text, error: update.ok === false || update.catalogueChanged });
  }), [payload.session, onClose]);
  useEffect(() => {
    if (!busy) return;
    const timer = window.setTimeout(() => setFeedback({ text: "Still waiting for the server. Do not submit again. Reopen the shop to check your balance and items.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [busy]);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => {
    const keydown = (event: KeyboardEvent) => {
      if (event.key === "Escape") { event.preventDefault(); event.stopPropagation(); if (!event.repeat) close(); }
      if (event.key === "Tab") {
        const controls = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), [tabindex="0"]') ?? []).filter(el => el.getClientRects().length);
        const first = controls[0], last = controls[controls.length - 1];
        if (event.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { event.preventDefault(); last?.focus(); }
        else if (!event.shiftKey && (document.activeElement === last || document.activeElement === root.current)) { event.preventDefault(); first?.focus(); }
      }
    };
    window.addEventListener("keydown", keydown);
    return () => window.removeEventListener("keydown", keydown);
  });

  const quantity = (item: ShopItem, next: number) => {
    if (pending.current) return;
    const max = mode === "sell" ? Math.min(payload.maxPerItem, item.owned) : payload.maxPerItem;
    const value = Math.max(0, Math.min(max, Math.trunc(next) || 0));
    if (!basket[item.name] && value && summary.lines.length >= payload.maxLines) {
      setFeedback({ text: `Choose up to ${payload.maxLines} different items per basket.`, error: true }); return;
    }
    setBaskets(previous => {
      const nextBasket = { ...previous[mode], [item.name]: value };
      if (!value) delete nextBasket[item.name];
      return { ...previous, [mode]: nextBasket };
    });
    setFeedback(undefined);
  };
  const checkout = () => {
    if (pending.current || summary.issue) return;
    const request = payload.nextRequest;
    pending.current = { request, mode }; setBusy(true); setFeedback(undefined);
    sendAction({ type: "shop.checkout", session: payload.session, request, revision: payload.revision, mode, pay: selectedPay,
      lines: summary.lines.map(({ item, count }) => ({ name: item.name, count })) });
  };
  const changeMode = (next: ShopMode) => { setMode(next); setQuery(""); setCategory("all"); setFeedback(undefined); };
  const clearFilters = () => { setQuery(""); setCategory("all"); setOwnedOnly(false); };

  return <div className="shop o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="shop-title">
    <div className="shop__workspace">
      <header className="shop__header">
        <div><span className="shop__eyebrow"><b>LIGHT RP</b> / YOUR NEIGHBOURHOOD STORE</span><h1 id="shop-title">{payload.shop.label}<span>.</span></h1><p>{payload.shop.subtitle}</p></div>
        <button className="shop__close" onClick={close} aria-label="Close shop">Back to the city <kbd>Esc</kbd><Icon name="x" size={18} /></button>
      </header>
      <div className="shop__bar"><span><Icon name="map-pin" size={15} />{payload.shop.name}</span><div><span>Cash <strong>{fmt(payload.money.cash)}</strong></span><span>Bank <strong>{fmt(payload.money.bank)}</strong></span></div></div>
      <div className="shop__layout">
        <section className="shop-catalogue" aria-label="Shop catalogue">
          <div className="shop__tools">
            <div className="shop-tabs" aria-label="Transaction type">{(["buy", "sell"] as const).map(value => <button key={value} disabled={busy} aria-pressed={mode === value} onClick={() => changeMode(value)}><Icon name={value === "buy" ? "package" : "arrow-left-right"} size={16} />{value === "buy" ? "Buy items" : "Sell items"}{Object.keys(baskets[value]).length > 0 && <span>{Object.keys(baskets[value]).length}</span>}</button>)}</div>
            <label className="shop-search"><Icon name="search" size={16} /><input aria-label="Search shop" placeholder="Something in mind?" value={query} disabled={busy} onChange={event => setQuery(event.target.value)} />{query && <button aria-label="Clear search" disabled={busy} onClick={() => setQuery("")}><Icon name="x" size={14} /></button>}</label>
          </div>
          <div className="shop__filters"><div>{["all", ...categories].map(value => <button key={value} disabled={busy} aria-pressed={category === value} onClick={() => setCategory(value)}>{value === "all" ? "Everything" : categoryLabel(value)}</button>)}</div>{mode === "sell" && <label><input type="checkbox" checked={ownedOnly} disabled={busy} onChange={event => setOwnedOnly(event.target.checked)} /> In my bag only</label>}</div>
          <div className="shop-grid">
            {list.map(item => {
              const count = basket[item.name] ?? 0;
              const max = mode === "sell" ? Math.min(item.owned, payload.maxPerItem) : payload.maxPerItem;
              return <article key={item.name} className={`shop-card${count ? " is-added" : ""}`}>
                <div className="shop-card__visual"><Art item={item} /><span>{categoryLabel(item.category)}</span>{count > 0 && <b><Icon name="check" size={11} />{count} in basket</b>}</div>
                <div className="shop-card__body"><h2>{item.label}</h2><p>{item.description}</p><div className="shop-card__facts"><span>{item.weight.toFixed(2)} kg</span><span>{item.owned} in bag</span>{item.effects?.food ? <span><Icon name="sandwich" size={11} />+{item.effects.food}</span> : item.effects?.drink ? <span><Icon name="droplet" size={11} />+{item.effects.drink}</span> : null}</div>
                  <button className="shop-card__add" disabled={busy || count >= max} onClick={() => quantity(item, count + 1)} aria-label={`Add ${item.label}`}><strong>{fmt(item[mode]!)}</strong><span>{count >= max ? (max === 0 ? "None to sell" : "Limit reached") : "Add"}<span aria-hidden="true">+</span></span></button>
                </div>
              </article>;
            })}
            {!list.length && <div className="shop-empty"><Icon name={mode === "sell" ? "backpack" : "search"} size={32} /><h2>{mode === "sell" && ownedOnly ? "Nothing to sell here yet" : "Nothing on this shelf"}</h2><p>{mode === "sell" ? "This vendor buys only the listed items. Personalised items stay in your bag." : "Try another category or search."}</p><button onClick={clearFilters} disabled={busy}>{mode === "sell" ? "Show what this shop buys" : "Clear filters"}<Icon name="arrow-right" size={15} /></button></div>}
          </div>
          <footer className="shop-catalogue__foot"><span>{list.length} items · Prices per unit</span><span>{mode === "buy" ? "Always stocked. No purchase until you confirm." : "Selling removes items from your bag."}</span></footer>
        </section>
        <aside className="shop-basket" aria-label="Shopping basket" aria-busy={busy}>
          <div className="shop-basket__heading"><div><span className="shop__eyebrow">{mode === "buy" ? "YOUR BASKET" : "YOUR SALE"}</span><h2>{summary.units ? `${summary.units} ${summary.units === 1 ? "item" : "items"}` : "Pack something good."}</h2></div>{summary.lines.length > 0 && <button disabled={busy} className="shop__text" onClick={() => setBaskets(previous => ({ ...previous, [mode]: {} }))}>Clear</button>}</div>
          <div className="shop-basket__lines">
            {!summary.lines.length && <div className="shop-basket__empty"><Icon name="package-open" size={36} /><p>Your basket is empty.</p><span>{mode === "buy" ? "Pick a few essentials from the shelves." : "Choose the items you want to sell."}</span></div>}
            {summary.lines.map(({ item, count, price }) => <div className="shop-line" key={item.name}><Art item={item} /><div><h3>{item.label}</h3><span>{fmt(price)} each</span><div className="shop-stepper"><button disabled={busy} aria-label={`Decrease ${item.label}`} onClick={() => quantity(item, count - 1)}>−</button><input disabled={busy} type="number" min="0" max={mode === "sell" ? Math.min(item.owned, payload.maxPerItem) : payload.maxPerItem} step="1" aria-label={`Quantity ${item.label}`} value={count} onChange={event => quantity(item, Number(event.target.value))} /><button disabled={busy || count >= (mode === "sell" ? Math.min(item.owned, payload.maxPerItem) : payload.maxPerItem)} aria-label={`Increase ${item.label}`} onClick={() => quantity(item, count + 1)}>+</button></div></div><div className="shop-line__end"><strong>{fmt(price * count)}</strong><button disabled={busy} aria-label={`Remove ${item.label}`} onClick={() => quantity(item, 0)}><Icon name="x" size={13} /></button></div></div>)}
          </div>
          <div className="shop-basket__checkout">
            <div className={`shop-capacity${summary.afterWeight > payload.inventory.maxWeight ? " is-full" : ""}`}><div><span><Icon name="backpack" size={13} /> Bag after {mode === "buy" ? "purchase" : "sale"}</span><span>{summary.afterWeight.toFixed(1)} / {payload.inventory.maxWeight} kg</span></div><div className="shop-capacity__track"><i style={{ width: `${Math.min(100, summary.afterWeight / Math.max(1, payload.inventory.maxWeight) * 100)}%` }} /></div></div>
            <fieldset className="shop-payment" disabled={busy}><legend>{mode === "buy" ? "Pay with" : "Receive in"}</legend>{payload.payments.map(method => <label key={method} className={selectedPay === method ? "is-selected" : ""}><input type="radio" name="shop-payment" checked={selectedPay === method} onChange={() => { setPay(method); setFeedback(undefined); }} /><Icon name={method === "cash" ? "banknote" : "credit-card"} size={17} /><span>{method === "cash" ? "Cash" : "Bank"}<small>{fmt(payload.money[method])}</small></span></label>)}</fieldset>
            <div className="shop-total"><span>{mode === "buy" ? "Total to pay" : "You receive"}<small>{summary.lines.length} / {payload.maxLines} different items</small></span><strong>{fmt(summary.total)}</strong></div>
            {summary.issue && summary.lines.length > 0 && <p className="shop-warning" role="status"><Icon name="info" size={14} />{summary.issue}</p>}
            <button className="shop__primary" disabled={busy || !!summary.issue} onClick={checkout}>{busy ? "Checking out…" : mode === "buy" ? "Confirm purchase" : "Confirm sale"}<Icon name={busy ? "loader" : "arrow-right"} size={18} /></button>
            <p className="shop-basket__hint">{mode === "buy" ? "Delivered straight to your inventory." : "Only standard items are accepted. No undo after sale."}</p>
            {feedback && <p className={`shop-feedback${feedback.error ? " is-error" : ""}`} role={feedback.error ? "alert" : "status"}><Icon name={feedback.error ? "info" : "check-check"} size={16} />{feedback.text}</p>}
          </div>
        </aside>
      </div>
    </div>
  </div>;
}
