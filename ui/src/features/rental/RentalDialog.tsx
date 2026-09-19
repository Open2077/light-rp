import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type RentalDialogPayload } from "@/bridge/protocol";
import { Badge, Button, HazardStripe, Icon, Keycap, ListRow, Tabs } from "@/design/components";
import { formatMoney } from "@/bridge/money";
import "./rental.css";

/* The rental desk, opened by the server when the player presses E at a desk
   (lightrp:ui:dialog, kind "rental"). Stock and prices come with the payload;
   balances and the current rental come from the state. The server validates
   the rent and the return; a successful result closes the dialog. */

function formatLeft(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
}

export function RentalDialog() {
  const dialog = useStore((s) => s.dialog);
  const closeDialog = useStore((s) => s.closeDialog);
  const visible = dialog?.kind === "rental";

  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape" && !e.repeat) { e.preventDefault(); closeDialog(); } };
    window.addEventListener("keydown", onKey);
    return () => { window.removeEventListener("keydown", onKey); emit(PAGE_EVENTS.focus, { active: false }); };
  }, [visible, closeDialog]);

  if (!visible || !dialog) return null;
  return <RentalBody payload={dialog as RentalDialogPayload} onClose={closeDialog} />;
}

function RentalBody({ payload, onClose }: { payload: RentalDialogPayload; onClose: () => void }) {
  const money = useStore((s) => s.state.money);
  const rental = useStore((s) => s.state.rental);
  const rentalAt = useStore((s) => s.rentalReceivedAt);
  const lastResult = useStore((s) => s.lastResult);
  const [pay, setPay] = useState<"cash" | "bank">("cash");
  const [sent, setSent] = useState<string | null>(null);
  const [, tick] = useState(0);
  const spot = payload.spot;
  const active = rental.active;

  useEffect(() => {
    const timer = setInterval(() => tick((t) => t + 1), 1000);
    return () => clearInterval(timer);
  }, []);
  // A rent that went through closes the desk; a refusal frees the buttons.
  useEffect(() => {
    if (!lastResult || !sent || lastResult.at < Date.now() - 10000) return;
    if (lastResult.action === sent) { setSent(null); if (lastResult.ok && sent === "rental.rent") onClose(); }
  }, [lastResult, sent, onClose]);

  const balance = pay === "bank" ? (money.bank?.balance ?? 0) : money.cash;
  const left = active ? Math.max(0, active.remainingMs - (Date.now() - rentalAt)) : 0;

  return (
    <div className="rental o77-interactive" role="dialog" aria-modal="true" aria-labelledby="rental-title">
      <div className="rental__frame">
        <header className="rental__head">
          <span className="rental__head-icon"><Icon name="car" size={16} /></span>
          <div className="rental__head-text">
            <span className="o77-tag o77-accent">VEHICLE RENTAL · {spot.durationMinutes} MIN</span>
            <h1 id="rental-title" className="rental__title">{spot.name}</h1>
          </div>
          <Button variant="ghost" size="sm" icon="x" onClick={onClose}>Close</Button>
        </header>
        <HazardStripe height={4} />

        <div className="rental__body">
          {active ? (
            <section className="rental__current">
              <div className="rental__current-text">
                <span className="o77-readout o77-accent">CURRENT RENTAL</span>
                <span className="rental__current-label">{active.label}</span>
                <span className="o77-readout o77-dim">{active.spotName.toUpperCase()} · PAID {formatMoney(active.price, money.currency)} ({active.paidWith.toUpperCase()})</span>
              </div>
              <div className="rental__current-right">
                <span className="rental__timer">{formatLeft(left)}</span>
                <Button variant="danger" size="sm" icon="x" disabled={sent !== null}
                  onClick={() => { setSent("rental.return"); sendAction({ type: "rental.return" }); }}>Return vehicle</Button>
              </div>
            </section>
          ) : (
            <section className="rental__pay">
              <span className="o77-readout o77-dim">PAY WITH</span>
              <Tabs value={pay} onChange={setPay} items={[
                { value: "cash", label: `Cash · ${formatMoney(money.cash, money.currency)}`, icon: "banknote" },
                { value: "bank", label: `Bank · ${formatMoney(money.bank?.balance ?? 0, money.currency)}`, icon: "landmark" },
              ]} />
            </section>
          )}

          <div className="rental__list">
            {spot.stock.map((item) => {
              const affordable = balance >= item.price;
              const blocked = !!active || sent !== null;
              return (
                <ListRow key={item.key} icon="car" title={item.label} subtitle={item.category.toUpperCase()}
                  meta={<span className={"rental__price" + (!affordable && !active ? " rental__price--short" : "")}>{formatMoney(item.price, money.currency)}</span>}
                  right={<Button size="sm" variant={affordable && !blocked ? "primary" : "secondary"} disabled={blocked || !affordable}
                    onClick={() => { setSent("rental.rent"); sendAction({ type: "rental.rent", spot: spot.id, key: item.key, pay }); }}>
                    {active ? "Out" : affordable ? "Rent" : "Short"}
                  </Button>} />
              );
            })}
            {spot.stock.length === 0 && <span className="o77-readout o77-disabled">NOTHING IN THE LOT RIGHT NOW</span>}
          </div>
        </div>

        <footer className="rental__foot">
          <span className="o77-readout o77-disabled"><Keycap size="sm">ESC</Keycap> CLOSE · ONE VEHICLE AT A TIME · RETURN AT ANY DESK</span>
          {active && <Badge tone="accent">{formatLeft(left)} LEFT</Badge>}
        </footer>
      </div>
    </div>
  );
}
