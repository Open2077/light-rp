import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type FuelDialogPayload, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./fuel.css";

/* A gas station pump. Opened by E at the pump point; the server tells us which
   vehicle is parked at the pump (if any), its tank, the price per litre and the
   jerrycans in the player's pockets. Every purchase is one server action; the
   server answers with a result and a refreshed payload, so the gauge fills from
   what the tank really holds. */

export function FuelDialog() {
  const dialog = useStore((s) => s.dialog);
  const close = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "fuel";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "fuel", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "fuel") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);
  if (dialog?.kind !== "fuel") return null;
  return <FuelBody key={dialog.spot.id} payload={dialog} onClose={close} />;
}

const SEGMENTS = 24;

function FuelBody({ payload, onClose }: { payload: FuelDialogPayload; onClose: () => void }) {
  const { spot, vehicle, jerrycan, money } = payload;
  const result = useStore((s) => s.lastResult);
  const root = useRef<HTMLDivElement>(null);
  const [pay, setPay] = useState<"cash" | "bank">("cash");
  const [litres, setLitres] = useState<number | null>(null); // null = fill up
  const [sent, setSent] = useState<string | null>(null);
  const pending = useRef<string | null>(null);
  const resultBefore = useRef(result);
  const [feedback, setFeedback] = useState<{ text: string; error?: boolean } | null>(null);
  const fmt = (value: number) => formatMoney(value, money.currency);

  const room = vehicle ? Math.max(0, Math.floor(vehicle.capacity - vehicle.litres)) : 0;
  const wanted = vehicle ? Math.max(0, Math.min(room, litres ?? room)) : 0;
  const price = Math.ceil(wanted * payload.pricePerLitre);
  const balance = pay === "bank" ? money.bank : money.cash;
  const short = Math.max(0, price - balance);
  const fraction = vehicle ? Math.max(0, Math.min(1, vehicle.litres / vehicle.capacity)) : 0;
  const preview = vehicle ? Math.max(0, Math.min(1, (vehicle.litres + wanted) / vehicle.capacity)) : 0;
  const state = !vehicle ? "none" : vehicle.litres <= 0 ? "empty" : fraction <= 0.15 ? "low" : "ok";
  const canBuy = !!vehicle && !vehicle.moving && wanted > 0 && short === 0 && !sent;
  const canPrice = jerrycan.empty > 0 ? jerrycan.refillPrice : jerrycan.buyPrice;
  const canShort = Math.max(0, canPrice - balance);

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    root.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => {
    if (!result || result === resultBefore.current || result.action !== pending.current) return;
    resultBefore.current = result; pending.current = null; setSent(null);
    setFeedback({ text: result.text, error: !result.ok });
    if (result.ok) setLitres(null);
  }, [result]);
  useEffect(() => {
    if (!sent) return;
    const timer = window.setTimeout(() => setFeedback({ text: "The pump has not answered yet. Close and reopen it to check the tank before paying again.", error: true }), 12000);
    return () => window.clearTimeout(timer);
  }, [sent]);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); if (!e.repeat) onClose(); }
      if (e.key === "Tab") {
        const controls = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled), [tabindex="0"]') ?? [])
          .filter((el) => el.getClientRects().length > 0);
        const first = controls[0], last = controls[controls.length - 1];
        if (e.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { e.preventDefault(); last?.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const issue = (action: UiAction) => {
    if (pending.current) return;
    pending.current = action.type; resultBefore.current = useStore.getState().lastResult;
    setSent(action.type); setFeedback(null); sendAction(action);
  };
  const quick = [10, 20, 30];

  return <div ref={root} tabIndex={-1} className="pump o77-interactive" role="dialog" aria-modal="true" aria-labelledby="pump-title">
    <div className="pump__panel" aria-busy={!!sent}>
      <header className="pump__header">
        <div><span className="pump__eyebrow"><i />LIGHT RP / GAS STATION</span><h1 id="pump-title">Fill her up<span>.</span></h1></div>
        <button className="pump__close" onClick={onClose} aria-label="Close pump">Close <kbd>Esc</kbd><Icon name="x" size={18} /></button>
      </header>
      <div className="pump__location"><span><Icon name="map-pin" size={14} />{spot.name}</span><span><Icon name="fuel" size={14} />{fmt(payload.pricePerLitre)} / L</span></div>

      <section className={`pump__tank pump__tank--${state}`} aria-label="Vehicle at the pump">
        {vehicle ? <>
          <div className="pump__tank-head">
            <div><span className="pump__eyebrow">AT THE PUMP</span><h2>{vehicle.label}</h2></div>
            <div className="pump__readout"><strong>{Math.round(vehicle.litres)}</strong><span>/ {Math.round(vehicle.capacity)} L</span></div>
          </div>
          <div className="pump__gauge" role="img" aria-label={`Tank ${Math.round(fraction * 100)} percent`}>
            {Array.from({ length: SEGMENTS }, (_, i) => {
              const at = (i + 1) / SEGMENTS;
              const cls = at <= fraction + 1e-4 ? " is-on" : at <= preview + 1e-4 ? " is-preview" : "";
              return <span key={i} className={`pump__cell${cls}`} />;
            })}
          </div>
          <div className="pump__tank-foot">
            <span>{state === "empty" ? <><Icon name="triangle-alert" size={12} /> Tank empty · engine cut</> : state === "low" ? <><Icon name="fuel" size={12} /> Running on reserve</> : `${Math.round(fraction * 100)}% full`}</span>
            <span>{vehicle.moving ? "Stop the vehicle to refuel" : room > 0 ? `${room} L to the brim` : "Tank is full"}</span>
          </div>
        </> : <div className="pump__none"><Icon name="car" size={30} /><h2>No vehicle at the pump</h2><p>Park within {Math.round(payload.pumpRange)} m of the pump and step out. You can still buy a jerrycan below.</p></div>}
      </section>

      {vehicle && room > 0 && <section className="pump__order" aria-label="Fuel amount">
        <div className="pump__amount">
          <span className="pump__eyebrow">AMOUNT</span>
          <div className="pump__chips">
            {quick.filter((q) => q < room).map((q) => <button key={q} disabled={!!sent} aria-pressed={litres === q} onClick={() => { setLitres(q); setFeedback(null); }}>{q} L</button>)}
            <button disabled={!!sent} aria-pressed={litres === null} onClick={() => { setLitres(null); setFeedback(null); }}>Fill up · {room} L</button>
          </div>
          <input className="pump__slider" type="range" min={1} max={room} step={1} value={wanted} disabled={!!sent} aria-label="Litres"
            onChange={(e) => { const v = Number(e.target.value); setLitres(v >= room ? null : v); setFeedback(null); }} />
        </div>
        <fieldset className="pump__payment" disabled={!!sent}><legend>Pay with</legend>{(["cash", "bank"] as const).map((method) => <label key={method} className={pay === method ? "is-selected" : ""}>
          <input type="radio" name="pump-payment" value={method} checked={pay === method} onChange={() => { setPay(method); setFeedback(null); }} />
          <Icon name={method === "cash" ? "banknote" : "credit-card"} size={16} /><span>{method === "cash" ? "Cash" : "Bank"}<small>{fmt(method === "cash" ? money.cash : money.bank)}</small></span><i aria-hidden="true" />
        </label>)}</fieldset>
      </section>}

      {vehicle && room > 0 && <div className="pump__total">
        <div><span>{wanted} L × {fmt(payload.pricePerLitre)}</span><strong>{fmt(price)}</strong></div>
        {short > 0 && <p className="pump__short" role="status">You need {fmt(short)} more in {pay === "cash" ? "cash" : "your bank account"}.</p>}
        <button className="pump__primary" disabled={!canBuy} onClick={() => { if (canBuy && vehicle) issue({ type: "fuel.buy", spot: spot.id, vehicle: vehicle.id, litres: wanted, pay }); }}>
          {sent === "fuel.buy" ? "Pumping…" : vehicle.moving ? "Stop the vehicle first" : `Refuel ${wanted} L`}<Icon name={sent === "fuel.buy" ? "loader" : "fuel"} size={17} />
        </button>
      </div>}

      <section className="pump__cans" aria-label="Jerrycans">
        <div className="pump__can-info">
          <Icon name="fuel" size={20} />
          <div><strong>Jerrycan · {jerrycan.litres} L</strong><small>{jerrycan.empty > 0 ? `You carry ${jerrycan.empty} empty can${jerrycan.empty > 1 ? "s" : ""}: refill for ${fmt(jerrycan.refillPrice)}.` : `Can + fuel for ${fmt(jerrycan.buyPrice)}. Bring it back empty and refill for ${fmt(jerrycan.refillPrice)}.`}{jerrycan.full > 0 ? ` ${jerrycan.full} full in your pockets.` : ""}</small></div>
        </div>
        <button className="pump__secondary" disabled={!!sent || canShort > 0} title={canShort > 0 ? `You need ${fmt(canShort)} more` : undefined}
          onClick={() => issue({ type: "fuel.jerrycan", spot: spot.id, pay })}>
          {sent === "fuel.jerrycan" ? "Filling…" : jerrycan.empty > 0 ? `Refill can · ${fmt(jerrycan.refillPrice)}` : `Buy full can · ${fmt(jerrycan.buyPrice)}`}
        </button>
      </section>

      {feedback && <p className={`pump__feedback${feedback.error ? " is-error" : ""}`} role={feedback.error ? "alert" : "status"}>{feedback.text}</p>}
      <footer className="pump__footer"><span><Icon name="info" size={13} />Out of fuel on the road? Use a jerrycan from your inventory next to the car.</span><span><kbd>Esc</kbd> Back to the city</span></footer>
    </div>
  </div>;
}
