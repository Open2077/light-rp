import { useEffect, useRef, useState } from "react";
import { useStore } from "@/state/store";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type FuelDialogPayload, type UiAction } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./fuel.css";

export function FuelDialog() {
  const dialog = useStore(s => s.dialog), close = useStore(s => s.closeDialog);
  const visible = dialog?.kind === "fuel";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "fuel", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, p => { if (!p?.kind || p.kind === "fuel") close(); });
    const update = on<FuelDialogPayload>("lightrp:ui:fuel:snapshot", p => {
      const current = useStore.getState().dialog;
      if (current?.kind === "fuel" && current.spot.id === p?.spot?.id) useStore.getState().openDialog(p);
    });
    return () => { off(); update(); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, close]);
  return dialog?.kind === "fuel" ? <FuelBody key={dialog.spot.id} payload={dialog} close={close} /> : null;
}
function FuelBody({ payload: p, close }: { payload: FuelDialogPayload; close: () => void }) {
  const [vehicleId, setVehicleId] = useState(p.vehicle?.id);
  const [litres, setLitres] = useState<number | null>(null);
  const [pay, setPay] = useState<"cash" | "bank">("cash");
  const [pending, setPending] = useState<string | null>(null), [message, setMessage] = useState("");
  const result = useStore(s => s.lastResult);
  const baseline = useRef(result), sent = useRef(false), root = useRef<HTMLDivElement>(null);
  // Empty Lua tables can arrive as {} rather than []; live refresh must not
  // crash the panel when the last vehicle leaves the forecourt.
  const vehicles = Array.isArray(p.vehicles) ? p.vehicles : (p.vehicle ? [p.vehicle] : []);
  const v = vehicles.find(v => v.id === vehicleId) ?? vehicles[0];
  const room = v ? Math.max(0, Math.floor(v.capacity - v.litres)) : 0;
  const amount = Math.max(0, Math.min(room, litres ?? room));
  const cost = Math.ceil(amount * p.pricePerLitre), balance = p.money[pay];
  const duration = Math.max((p.minimumFillMs ?? 5000) / 1000, Math.ceil(amount / (p.litresPerSecond ?? 1.2)));
  const canCost = p.jerrycan.empty ? p.jerrycan.refillPrice : p.jerrycan.buyPrice;
  const fmt = (n: number) => formatMoney(n, p.money.currency);
  const blocked = p.busy ? "This pump is in use" : !v ? "Park beside the pump" : v.unavailable || (v.engineOn ? "Switch off the engine first" : v.moving ? "Park the vehicle first" : !room ? "Tank already full" : cost > balance ? "Insufficient funds" : "");
  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => {
    if (!pending || !result || result === baseline.current || result.action !== pending) return;
    sent.current = false; setPending(null); setMessage(result.text);
  }, [result, pending]);
  useEffect(() => {
    if (pending) return;
    const timer = window.setInterval(() => sendAction({ type: "fuel.refresh", spot: p.spot.id }), 2500);
    return () => clearInterval(timer);
  }, [p.spot.id, pending]);
  useEffect(() => {
    if (!pending) return;
    const timer = window.setTimeout(() => setMessage("Still waiting for the pump. Close and reopen to check its state; do not submit again."), 9000);
    return () => clearTimeout(timer);
  }, [pending]);
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); if (!e.repeat) close(); }
      if (e.key !== "Tab") return;
      const buttons = Array.from(root.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled)') ?? []);
      const first = buttons[0], last = buttons[buttons.length - 1];
      if (e.shiftKey && (document.activeElement === first || document.activeElement === root.current)) { e.preventDefault(); last?.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
    };
    window.addEventListener("keydown", key); return () => window.removeEventListener("keydown", key);
  }, [close]);
  const issue = (action: UiAction) => {
    if (sent.current) return;
    sent.current = true; baseline.current = result; setPending(action.type); setMessage(""); sendAction(action);
  };
  return <div className="pump o77-interactive" ref={root} tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="pump-title">
    <header className="pump__header"><div className="pump__brand"><Icon name="fuel" size={27} /><span>LIGHT RP<small>SELF-SERVICE / CHOOH2</small></span></div><button className="pump__close" onClick={close} aria-label="Close pump"><Icon name="x" size={19} /></button></header>
    <div className="pump__intro"><span className="pump__eyebrow">{p.spot.name} · PUMP {String(p.spot.pump ?? 1).padStart(2, "0")}</span><h1 id="pump-title">A little further<span>.</span></h1><p>Park. Engine off. Step outside.</p></div>
    <div className="pump__tariff"><span>Price per litre</span><strong>{fmt(p.pricePerLitre)} <small>/ L</small></strong></div>
    <section className="pump__vehicle">
      <label className="pump__eyebrow" htmlFor="pump-vehicle">YOUR VEHICLE AT THIS PUMP</label>
      {vehicles.length ? <>
        <select id="pump-vehicle" value={v?.id} disabled={!!pending} onChange={e => { setVehicleId(Number(e.target.value)); setLitres(null); }}>
          {vehicles.map(car => <option key={car.id} value={car.id}>{car.label} · #{car.id}</option>)}
        </select>
        {v && <><div className="pump__readout"><strong>{v.litres.toFixed(1)} <small>L</small></strong><span>{v.capacity} L capacity</span></div>
          <div className="pump__gauge" role="img" aria-label={"Tank " + Math.round(v.litres / v.capacity * 100) + " percent"}><i style={{ width: Math.min(100, (v.litres + amount) / v.capacity * 100) + "%" }} /><b style={{ width: Math.min(100, v.litres / v.capacity * 100) + "%" }} /></div>
          <div className="pump__legend"><span><i /> Current fuel</span><span><i /> After your fill</span></div>
        </>}
      </> : <div className="pump__empty"><Icon name="car" size={28} /><p>No vehicle nearby<small>Park within {p.pumpRange} m. The list refreshes automatically.</small></p></div>}
    </section>
    {v && room > 0 && <section className="pump__amount">
      <div className="pump__section-title"><label htmlFor="pump-litres">How much?</label><strong>{amount} L <small>≈ {duration}s</small></strong></div>
      <div className="pump__chips">{[10, 20, 30].filter(n => n < room).map(n => <button key={n} disabled={!!pending} aria-pressed={litres === n} onClick={() => setLitres(n)}>{n} L</button>)}<button disabled={!!pending} aria-pressed={litres === null} onClick={() => setLitres(null)}>Fill up</button></div>
      <input id="pump-litres" type="range" min={1} max={room} step={1} value={amount} disabled={!!pending} aria-label="Litres" onChange={e => setLitres(Number(e.target.value))} />
    </section>}
    <fieldset className="pump__payment" disabled={!!pending}><legend>Payment method</legend>{(["cash", "bank"] as const).map(method => <label key={method} className={pay === method ? "is-selected" : ""}><input type="radio" name="fuel-payment" checked={pay === method} onChange={() => setPay(method)} /><Icon name={method === "cash" ? "banknote" : "credit-card"} size={17} /><span>{method === "cash" ? "Cash" : "Bank"}<small>{fmt(p.money[method])}</small></span></label>)}</fieldset>
    {v && <div className="pump__checkout"><div><span>Estimated total</span><strong>{fmt(cost)}</strong></div><button className="pump__primary" disabled={!!pending || !!blocked} onClick={() => issue({ type: "fuel.buy", spot: p.spot.id, vehicle: v.id, litres: amount, pay })}>{pending === "fuel.buy" ? "Preparing…" : blocked || "Continue to vehicle"}<Icon name="arrow-right" size={18} /></button></div>}
    <p className="pump__instructions"><Icon name="info" size={16} /><span>Then stand beside your vehicle and press <kbd>E</kbd>. Stay still while filling. Payment is taken only when the action completes.</span></p>
    <section className="pump__can"><Icon name="fuel" size={21} /><div><strong>On-the-road backup</strong><small>{p.jerrycan.empty ? "Refill your empty can" : "Jerrycan + " + p.jerrycan.litres + " L of fuel"}</small></div><button disabled={!!pending || !!p.busy || canCost > balance} onClick={() => issue({ type: "fuel.jerrycan", spot: p.spot.id, pay })}>{pending === "fuel.jerrycan" ? "Preparing…" : fmt(canCost)}</button></section>
    {message && <p className="pump__feedback" role="alert">{message}</p>}
    <footer className="pump__footer"><span><kbd>Esc</kbd> Close</span><span>Timed filling · Cancel without charge</span></footer>
  </div>;
}
