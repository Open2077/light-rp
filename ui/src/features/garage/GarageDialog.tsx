import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type GarageDialogPayload, type GarageUpdate } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { useStore } from "@/state/store";
import { Icon } from "@/design/components";
import { VehicleArt } from "@/features/rental/VehicleArt";
import { condition, filterVehicles } from "./model";
import "./garage.css";

const UPDATE = "lightrp:ui:garage";
export function GarageDialog() {
  const dialog = useStore(s => s.dialog);
  const close = useStore(s => s.closeDialog);
  const visible = dialog?.kind === "garage";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "garage", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, p => { if (!p?.kind || p.kind === "garage") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "garage", open: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "garage") return null;
  return <GarageBody key={dialog.session} payload={dialog} onClose={close} />;
}

function GarageBody({ payload, onClose }: { payload: GarageDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [selected, setSelected] = useState(payload.vehicles[0]?.id);
  const [confirm, setConfirm] = useState<false | "store" | "impound">(false);
  const [pay, setPay] = useState<"bank" | "cash">("bank");
  const money = useStore(s => s.state.money);
  const fmt = (n: number) => formatMoney(n, money.currency);
  const impoundName = payload.impound?.name ?? "the impound";
  const [waiting, setWaiting] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean }>();
  const pending = useRef<number>();
  const done = useRef(0);
  const list = useMemo(() => filterVehicles(payload.vehicles, query, filter), [payload.vehicles, query, filter]);
  const item = list.find(v => v.id === selected) ?? list[0];
  const out = payload.vehicles.filter(v => v.status === "out").length;
  const close = () => { sendAction({ type: "garage.close", session: payload.session }); onClose(); };

  useEffect(() => on<GarageUpdate>(UPDATE, update => {
    if (update.session !== payload.session) return;
    if (update.closed) { onClose(); return; }
    if (update.state) useStore.getState().openDialog(update.state);
    if (update.request !== pending.current || update.request == null || update.request <= done.current) return;
    done.current = update.request; pending.current = undefined;
    setWaiting(false); setConfirm(false);
    if (update.text) setFeedback({ text: update.text, error: !update.ok });
  }), [payload.session, onClose]);
  useEffect(() => {
    if (!waiting) return;
    const timer = window.setTimeout(() => setFeedback({ text: "Still waiting for the server. Close and reopen the garage to check the outcome. Your request will not be sent twice.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [waiting]);
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => { setConfirm(false); }, [item?.id, item?.status]);

  const issue = (type: "garage.retrieve" | "garage.store" | "garage.impound" | "garage.recover") => {
    if (!item || pending.current != null) return;
    pending.current = payload.nextRequest; setWaiting(true); setFeedback(undefined);
    if (type === "garage.recover") sendAction({ type, session: payload.session, request: payload.nextRequest, vehicle: item.id, pay });
    else sendAction({ type, session: payload.session, request: payload.nextRequest, vehicle: item.id });
  };
  const fee = item?.impound?.fee ?? 0;
  const balance = pay === "bank" ? money.bank?.balance ?? 0 : money.cash;
  const statusLabel = (s: string) => s === "stored" ? "IN STORAGE" : s === "impound" ? "IMPOUNDED" : "ON THE ROAD";
  const canCollect = !!item?.canRetrieve && out < payload.maxOutside;
  const canPark = !!item?.canStore;
  return <div className="garage o77-interactive" role="dialog" aria-modal="true" aria-labelledby="garage-title" ref={root} tabIndex={-1}
    onKeyDown={e => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); if (!e.repeat) { if (confirm && !waiting) setConfirm(false); else close(); } }
      if (e.key === "Tab") {
        const focusable = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), [tabindex="0"]') ?? []);
        const first = focusable[0], last = focusable.at(-1);
        if (e.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { e.preventDefault(); last?.focus(); }
        else if (!e.shiftKey && (document.activeElement === last || document.activeElement === root.current)) { e.preventDefault(); first?.focus(); }
      }
    }}>
    <div className="garage__workspace">
      <header className="garage__header"><div><span className="garage__eyebrow">LIGHT RP <i>/</i> PUBLIC PARKING</span><h1 id="garage-title">Your garage<span>.</span></h1><p>Your vehicles. A place to come back to.</p></div>
        <button className="garage__close" onClick={close}>Close <kbd>Esc</kbd><Icon name="x" size={17} /></button></header>
      <div className="garage__bar"><span><Icon name="map-pin" size={15} />{payload.spot.name}</span><span>{payload.vehicles.length} owned <i>/</i> {out} of {payload.maxOutside} out</span></div>
      <div className="garage__layout">
        <section className="garage__catalogue" aria-label="Personal vehicles">
          <div className="garage__tools"><div className="garage__tabs">{[["all", "All vehicles"], ["stored", "In storage"], ["out", "On the road"], ["impound", "Impound"]].map(([id, name]) => <button key={id} aria-pressed={filter === id} disabled={waiting} onClick={() => setFilter(id!)}>{name}</button>)}</div>
            <label className="garage__search"><Icon name="search" size={16} /><input aria-label="Search your vehicles" placeholder="Search vehicles…" disabled={waiting} value={query} onChange={e => setQuery(e.target.value)} /></label></div>
          <div className="garage__list">{list.map(v => <button key={v.id} className={`garage-card${item?.id === v.id ? " is-selected" : ""}`} disabled={waiting} aria-pressed={item?.id === v.id} aria-label={`Select ${v.label}`} onClick={() => { setSelected(v.id); setFeedback(undefined); }}>
            <div className="garage-card__art"><VehicleArt vehicle={v} /><span className={`garage__status is-${v.status}`}><i />{statusLabel(v.status)}</span></div>
            <div className="garage-card__body"><span>{v.category}</span><h2>{v.label}</h2><p><Icon name={v.status === "impound" ? "triangle-alert" : "map-pin"} size={12} />{v.status === "impound" ? impoundName : v.garageName}</p><footer><code>#{v.id.slice(0, 8).toUpperCase()}</code><span>{condition(v.health)}% condition</span></footer></div>
          </button>)}
            {!list.length && <div className="garage__empty"><Icon name={payload.vehicles.length ? "search" : "car"} size={40} /><h2>{payload.vehicles.length ? "No matching vehicles" : "Room for your first ride"}</h2><p>{payload.vehicles.length ? "Try another name or switch the filter." : "Your personal vehicles will appear here once you own one. Rentals are managed at Rent-a-Ride."}</p>{!!payload.vehicles.length && <button onClick={() => { setQuery(""); setFilter("all"); }}>Clear filters</button>}</div>}
          </div>
        </section>
        <aside className="garage__detail" aria-busy={waiting} aria-label="Vehicle details">
          {item ? <><span className="garage__eyebrow">PERSONAL VEHICLE</span><div className="garage__preview"><VehicleArt vehicle={item} /></div><span className="garage__category">{item.category}</span><h2>{item.label}</h2><code className="garage__registration">REGISTRATION #{item.id.slice(0, 8).toUpperCase()}</code>
            <dl><div><dt>Status</dt><dd>{item.status === "stored" ? "In storage" : item.status === "impound" ? "At the impound" : "On the road"}</dd></div>
              {item.status === "impound" && item.impound ? <><div><dt>Reason</dt><dd>{item.impound.reason}</dd></div><div><dt>Impound fee</dt><dd>{item.impound.fee > 0 ? fmt(item.impound.fee) : "Free"}</dd></div></>
                : <div><dt>Home garage</dt><dd>{item.garageName}</dd></div>}
              <div><dt>Condition</dt><dd>{condition(item.health)}%</dd></div></dl>
            <div className="garage__condition"><span style={{ width: `${condition(item.health)}%` }} /></div>
            <div className="garage__bottom">
              {item.status === "impound" ? <div className="garage__impound">
                  <p className="garage__hint">{fee > 0 ? "Pay the fee here: " : "No fee to pay: "}{item.label} is released into this garage, then driven out to a free bay when one is open.</p>
                  {fee > 0 && <div className="garage__pay" role="radiogroup" aria-label="Pay the impound fee with">{(["bank", "cash"] as const).map(method =>
                    <button key={method} role="radio" aria-checked={pay === method} disabled={waiting} onClick={() => setPay(method)}>
                      <Icon name={method === "bank" ? "landmark" : "banknote"} size={15} />{method === "bank" ? "Bank" : "Cash"}<small>{fmt(method === "bank" ? money.bank?.balance ?? 0 : money.cash)}</small></button>)}</div>}
                  <button className="garage__primary" disabled={waiting || !item.canRecover || (fee > 0 && balance < fee)} onClick={() => issue("garage.recover")}>
                    {waiting ? "Releasing your vehicle…" : fee > 0 ? `Pay ${fmt(fee)} and collect` : "Collect from the impound"}<Icon name={waiting ? "loader" : "key-round"} size={17} /></button>
                  {fee > 0 && balance < fee && <p className="garage__hint">Not enough {pay === "bank" ? "in your account" : "cash"} for the fee.</p>}
                </div>
              : confirm === "impound" && item.status === "out" ? <div className="garage__confirm"><h3>Send it to the impound?</h3><p>Stolen, lost or stuck: the city tows it from wherever it is, even with someone inside. Its condition and trunk are kept. Recover it at any public garage{(payload.impound?.fees.requested ?? 0) > 0 ? ` for ${fmt(payload.impound!.fees.requested)}` : ", free of charge"}.</p><button className="garage__primary" disabled={waiting || !item.canImpound} onClick={() => issue("garage.impound")}>{waiting ? "Calling the tow truck…" : "Tow it to the impound"}<Icon name={waiting ? "loader" : "triangle-alert"} size={17} /></button><button className="garage__text" disabled={waiting} onClick={() => setConfirm(false)}>Keep it where it is</button></div>
              : confirm === "store" && item.status === "out" ? <div className="garage__confirm"><h3>Store this vehicle?</h3><p>Its condition and trunk are saved. You can collect it here again.</p><button className="garage__primary" disabled={waiting || !canPark} onClick={() => issue("garage.store")}>{waiting ? "Saving vehicle…" : "Confirm storage"}<Icon name={waiting ? "loader" : "check"} size={17} /></button><button className="garage__text" disabled={waiting} onClick={() => setConfirm(false)}>Keep it outside</button></div>
                : <><button className="garage__primary" disabled={waiting || (item.status === "stored" ? !canCollect : !canPark)} onClick={() => item.status === "stored" ? issue("garage.retrieve") : setConfirm("store")}>{waiting ? "Preparing your vehicle…" : item.status === "stored" ? "Retrieve vehicle" : "Store vehicle"}<Icon name={waiting ? "loader" : item.status === "stored" ? "arrow-right" : "car"} size={17} /></button>
                  <button className="garage__text" disabled={waiting || !canPark} onClick={() => sendAction({ type: "customization.open", vehicle: item.id, garage: payload.spot.id })}>Customize vehicle</button>
                  <p className="garage__hint">{item.hint || (item.status === "stored" ? item.garageId !== payload.spot.id ? "Visit its listed garage to collect this vehicle." : out >= payload.maxOutside ? "Store your current vehicle before collecting another." : "Delivered to a free bay outside. Press L to unlock." : "Bring it nearby, stop and ask everyone to step out.")}</p>
                  {item.status === "out" && item.canImpound && <button className="garage__text garage__tow" disabled={waiting} onClick={() => setConfirm("impound")}><Icon name="triangle-alert" size={13} />Stolen, lost or stuck? Send it to the impound</button>}</>}
            </div></> : <div className="garage__empty"><Icon name="key-round" size={32} /><h2>Make room for the road</h2><p>Select one of your vehicles to view its details.</p></div>}
          {feedback && <div className={`garage__feedback${feedback.error ? " is-error" : ""}`} role="status"><Icon name={feedback.error ? "triangle-alert" : "check"} size={16} /><span>{feedback.text}</span></div>}
        </aside>
      </div>
      <footer className="garage__footer"><Icon name="shield" size={14} /><span>A vehicle left outside at a server restart, or lost from the streets, goes to {impoundName}: recover it at any public garage. Ownership and trunk stay with your character.</span></footer>
    </div>
  </div>;
}
