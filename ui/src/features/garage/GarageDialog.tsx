import { useEffect, useMemo, useRef, useState } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type GarageDialogPayload, type GarageUpdate } from "@/bridge/protocol";
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
  const [confirm, setConfirm] = useState(false);
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

  const issue = (type: "garage.retrieve" | "garage.store") => {
    if (!item || pending.current != null) return;
    pending.current = payload.nextRequest; setWaiting(true); setFeedback(undefined);
    sendAction({ type, session: payload.session, request: payload.nextRequest, vehicle: item.id });
  };
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
          <div className="garage__tools"><div className="garage__tabs">{[["all", "All vehicles"], ["stored", "In storage"], ["out", "On the road"]].map(([id, name]) => <button key={id} aria-pressed={filter === id} disabled={waiting} onClick={() => setFilter(id!)}>{name}</button>)}</div>
            <label className="garage__search"><Icon name="search" size={16} /><input aria-label="Search your vehicles" placeholder="Search vehicles…" disabled={waiting} value={query} onChange={e => setQuery(e.target.value)} /></label></div>
          <div className="garage__list">{list.map(v => <button key={v.id} className={`garage-card${item?.id === v.id ? " is-selected" : ""}`} disabled={waiting} aria-pressed={item?.id === v.id} aria-label={`Select ${v.label}`} onClick={() => { setSelected(v.id); setFeedback(undefined); }}>
            <div className="garage-card__art"><VehicleArt vehicle={v} /><span className={`garage__status is-${v.status}`}><i />{v.status === "stored" ? "IN STORAGE" : "ON THE ROAD"}</span></div>
            <div className="garage-card__body"><span>{v.category}</span><h2>{v.label}</h2><p><Icon name="map-pin" size={12} />{v.garageName}</p><footer><code>#{v.id.slice(0, 8).toUpperCase()}</code><span>{condition(v.health)}% condition</span></footer></div>
          </button>)}
            {!list.length && <div className="garage__empty"><Icon name={payload.vehicles.length ? "search" : "car"} size={40} /><h2>{payload.vehicles.length ? "No matching vehicles" : "Room for your first ride"}</h2><p>{payload.vehicles.length ? "Try another name or switch the filter." : "Your personal vehicles will appear here once you own one. Rentals are managed at Rent-a-Ride."}</p>{!!payload.vehicles.length && <button onClick={() => { setQuery(""); setFilter("all"); }}>Clear filters</button>}</div>}
          </div>
        </section>
        <aside className="garage__detail" aria-busy={waiting} aria-label="Vehicle details">
          {item ? <><span className="garage__eyebrow">PERSONAL VEHICLE</span><div className="garage__preview"><VehicleArt vehicle={item} /></div><span className="garage__category">{item.category}</span><h2>{item.label}</h2><code className="garage__registration">REGISTRATION #{item.id.slice(0, 8).toUpperCase()}</code>
            <dl><div><dt>Status</dt><dd>{item.status === "stored" ? "In storage" : "On the road"}</dd></div><div><dt>Home garage</dt><dd>{item.garageName}</dd></div><div><dt>Condition</dt><dd>{condition(item.health)}%</dd></div></dl>
            <div className="garage__condition"><span style={{ width: `${condition(item.health)}%` }} /></div>
            <div className="garage__bottom">
              {confirm && item.status === "out" ? <div className="garage__confirm"><h3>Store this vehicle?</h3><p>Its condition and trunk are saved. You can collect it here again.</p><button className="garage__primary" disabled={waiting || !canPark} onClick={() => issue("garage.store")}>{waiting ? "Saving vehicle…" : "Confirm storage"}<Icon name={waiting ? "loader" : "check"} size={17} /></button><button className="garage__text" disabled={waiting} onClick={() => setConfirm(false)}>Keep it outside</button></div>
                : <><button className="garage__primary" disabled={waiting || (item.status === "stored" ? !canCollect : !canPark)} onClick={() => item.status === "stored" ? issue("garage.retrieve") : setConfirm(true)}>{waiting ? "Preparing your vehicle…" : item.status === "stored" ? "Retrieve vehicle" : "Store vehicle"}<Icon name={waiting ? "loader" : item.status === "stored" ? "arrow-right" : "car"} size={17} /></button>
                  <p className="garage__hint">{item.hint || (item.status === "stored" ? item.garageId !== payload.spot.id ? "Visit its listed garage to collect this vehicle." : out >= payload.maxOutside ? "Store your current vehicle before collecting another." : "Delivered to a free bay outside. Press L to unlock." : "Bring it nearby, stop and ask everyone to step out.")}</p></>}
            </div></> : <div className="garage__empty"><Icon name="key-round" size={32} /><h2>Make room for the road</h2><p>Select one of your vehicles to view its details.</p></div>}
          {feedback && <div className={`garage__feedback${feedback.error ? " is-error" : ""}`} role="status"><Icon name={feedback.error ? "triangle-alert" : "check"} size={16} /><span>{feedback.text}</span></div>}
        </aside>
      </div>
      <footer className="garage__footer"><Icon name="shield" size={14} /><span>After a server restart or vehicle cleanup, your ride returns to its last garage. Ownership and trunk stay with your character.</span></footer>
    </div>
  </div>;
}
