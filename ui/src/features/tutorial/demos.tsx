import { useEffect, useState, type ReactNode } from "react";
import type { TutorialStop } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { Icon } from "@/design/components";
import { useStore } from "@/state/store";
import { VehicleCluster } from "@/features/hud/VehicleCluster";
import "./demos.css";

/* Examples of the UI the first day talks about, played in a loop beside the
   dialogue (a line's `demo`) or in the objective card (a step's `demo`). They
   are pictures of the real screens, never the screens themselves: nothing here
   sends an action. With reduced motion each one holds its last frame. */

export type DemoKeys = Record<string, string | undefined>;

const still = () => typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;

/** The stage of a looping sequence: stage i lasts durations[i] ms. */
export function useStage(durations: number[]): number {
  const frozen = still();
  const [stage, setStage] = useState(frozen ? durations.length - 1 : 0);
  const length = durations.length, wait = durations[stage] ?? 1000;
  // Primitive dependencies: a re-render (a ticker beside it) must not restart the stage.
  useEffect(() => {
    if (frozen) return;
    const timer = setTimeout(() => setStage(s => (s + 1) % length), wait);
    return () => clearTimeout(timer);
  }, [stage, frozen, length, wait]);
  return stage;
}
/** A value moved by `step` every `ms`, wrapping from `to` back to `from`. */
export function useTicker(from: number, to: number, step: number, ms: number): number {
  const frozen = still();
  const [value, setValue] = useState(frozen ? to : from);
  useEffect(() => {
    if (frozen) return;
    const timer = setInterval(() => setValue(v => {
      const next = v + step;
      return (step < 0 ? next < to : next > to) ? from : next;
    }), ms);
    return () => clearInterval(timer);
  }, [from, to, step, ms, frozen]);
  return value;
}

export function Cap({ children, on, wide }: { children?: string; on?: boolean; wide?: boolean }) {
  const text = (children ?? "?").toUpperCase();
  return <kbd className={`demo-cap${on ? " is-on" : ""}${wide || text.length > 2 ? " demo-cap--wide" : ""}`}>{text}</kbd>;
}
export function Item({ name, icon, count }: { name?: string; icon: string; count?: number }) {
  const [failed, setFailed] = useState(false);
  return <span className="demo-item">
    {name && !failed ? <img src={`img/items/${name}.png`} alt="" onError={() => setFailed(true)} /> : <Icon name={icon} size={22} />}
    {count !== undefined && <b>x{count}</b>}
  </span>;
}
function Caption({ children }: { children: ReactNode }) { return <p className="demo-caption">{children}</p>; }
const DONE = <Icon name="check" size={14} />;

/* ---------- The hall from above ---------- */

export function HallMap({ stops, tour = false, compact = false }: { stops: TutorialStop[]; tour?: boolean; compact?: boolean }) {
  const route = stops.filter(s => s.step !== "intro");
  const lit = useTicker(0, route.length + 1, 1, 750);
  if (!stops.length) return null;
  const xs = stops.map(s => s.x), ys = stops.map(s => s.y);
  const pad = 14, minX = Math.min(...xs) - pad, maxX = Math.max(...xs) + pad, minY = Math.min(...ys) - pad, maxY = Math.max(...ys) + pad;
  const w = maxX - minX, h = maxY - minY;
  const at = (s: TutorialStop) => [s.x - minX, maxY - s.y] as const;
  const line = stops.map(s => at(s).join(",")).join(" ");
  return <svg className={`demo-map${compact ? " demo-map--compact" : ""}`} viewBox={`0 0 ${w} ${h}`} role="img" aria-label="Map of the arrival hall">
    <rect className="demo-map__ground" x={0} y={0} width={w} height={h} rx={4} />
    <line className="demo-map__avenue" x1={-minX} y1={0} x2={-minX} y2={h} />
    <polyline className="demo-map__route" points={line} />
    {stops.map((s, i) => {
      const [x, y] = at(s);
      const order = route.indexOf(s);
      const state = tour ? (s.step === "intro" || order < lit ? "done" : order === lit ? "now" : "next") : s.state;
      return <g key={i} className={`demo-map__stop is-${state}`} transform={`translate(${x} ${y})`}>
        {state === "now" && <circle className="demo-map__ping" r={7} />}
        <circle r={s.step === "intro" ? 2.4 : 3.4} />
        {(state === "now" || (!compact && tour)) && <text y={-6.5}>{s.label}</text>}
      </g>;
    })}
  </svg>;
}

/* ---------- Beside the dialogue ---------- */

function Rules() {
  const stage = useStage([1500, 1500, 1500, 1500]);
  const rows = [
    { icon: "message-square", title: "Stay in character", body: "Talk as the person on your card." },
    { icon: "message-circle", title: "/ooc for real life", body: <span className="demo-chat">/ooc brb, door bell</span> },
    { icon: "shield-alert", title: "No random attacks", body: "Every conflict needs a story." },
    { icon: "siren", title: "/report calls staff", body: "Stuck, bug, or someone breaking rules." },
  ];
  return <ul className="demo-rules">{rows.map((r, i) => <li key={i} className={i === stage ? "is-on" : i < stage ? "is-seen" : ""}>
    <Icon name={r.icon} size={18} /><div><b>{r.title}</b><span>{r.body}</span></div></li>)}</ul>;
}

function IdentityCard() {
  const c = useStore(s => s.state.character), money = useStore(s => s.state.money);
  const stage = useStage([1400, 2600]);
  const name = [c.firstName, c.lastName].filter(Boolean).join(" ") || "Your name";
  return <div className="demo-card">
    <div className="demo-card__band"><Icon name="id-card" size={16} /><span>NIGHT CITY · CITIZEN RECORD</span></div>
    <div className="demo-card__body">
      <span className="demo-card__photo"><Icon name="user" size={30} /></span>
      <div><small>NAME</small><b>{name}</b><small>BANK ACCOUNT</small>
        <b className={`demo-card__account${stage === 1 ? " is-on" : ""}`}>{money.bank?.number ?? "NC-0000-0000"}</b></div>
    </div>
    <Caption>Player menu → <b>Identity</b></Caption>
  </div>;
}

function Money() {
  const currency = useStore(s => s.state.money.currency);
  const stage = useStage([1200, 1900, 1900, 900]);
  const fmt = (n: number) => formatMoney(n, currency);
  const bank = stage >= 1 ? 1320 : 1200, cash = stage >= 2 ? 150 : 200;
  return <div className="demo-money">
    <div className={`demo-money__col${stage === 2 ? " is-on" : ""}`}><Icon name="wallet" size={22} /><small>CASH</small><b>{fmt(cash)}</b><span>In your pocket. Hand it with <code>/pay</code>.</span>
      {stage === 2 && <i className="demo-fly demo-fly--out">-{fmt(50)}</i>}</div>
    <div className={`demo-money__col${stage === 1 ? " is-on" : ""}`}><Icon name="landmark" size={22} /><small>BANK</small><b>{fmt(bank)}</b><span>Paychecks land here. Shops take both.</span>
      {stage === 1 && <i className="demo-fly demo-fly--in">+{fmt(120)} PAYCHECK</i>}</div>
  </div>;
}

function Transfer() {
  const money = useStore(s => s.state.money);
  const stage = useStage([1100, 1500, 2000]);
  return <div className="demo-transfer">
    <div className="demo-transfer__row">
      <span className="demo-account"><small>FROM YOU</small><b>{money.bank?.number ?? "NC-0000-0000"}</b></span>
      <span className={`demo-transfer__wire is-${stage}`}><i><Icon name="send" size={14} /></i></span>
      <span className={`demo-account${stage === 2 ? " is-done" : ""}`}><small>TO</small><b>NC-4821-0077</b>{stage === 2 && <em>{DONE} {formatMoney(80, money.currency)}</em>}</span>
    </div>
    <p className="demo-warn"><Icon name="shield" size={15} />Your number is like your wallet: only to people you trust.</p>
  </div>;
}

function Rental() {
  const stage = useStage([900, 900, 1100, 2200]);
  const cars = [["Makigai MaiMai", 90], ["Thorton Galena", 120], ["Archer Hella", 150]] as const;
  return <div className="demo-panel">
    <div className="demo-panel__head"><Icon name="car" size={16} />RENT-A-RIDE<span>30 MIN</span></div>
    {stage < 3 ? <ul className="demo-list">{cars.map(([label, price], i) =>
      <li key={label} className={i === Math.min(stage, 1) ? "is-on" : ""}><Icon name="car" size={16} /><span>{label}</span><b>€${price}</b>
        {i === 1 && stage === 2 && <em className="demo-press">RENT</em>}</li>)}</ul>
      : <div className="demo-result"><Icon name="map-pin" size={22} /><b>Parked beside the desk</b><span>Return it at any desk.</span></div>}
  </div>;
}

function Keys({ keys }: { keys: DemoKeys }) {
  const stage = useStage([900, 1600, 900, 1700]);
  const locked = stage === 1 || stage === 2;
  return <div className="demo-keys">
    <div className={`demo-keys__car${locked ? " is-locked" : ""}`}>
      <Icon name="car" size={64} />
      {stage === 1 && <span className="demo-ripple" />}
      {stage === 3 && <><span className="demo-ripple" /><span className="demo-ripple demo-ripple--late" /></>}
    </div>
    <div className="demo-keys__state">
      <Cap on={stage === 1 || stage === 3}>{keys.lock ?? "L"}</Cap>
      <b className={locked ? "is-locked" : "is-open"}><Icon name={locked ? "lock" : "lock-open"} size={16} />{locked ? "LOCKED" : "UNLOCKED"}</b>
      <span>{stage === 1 ? "One bip: locked" : stage === 3 ? "Two bips: unlocked" : "From a few metres"}</span>
    </div>
  </div>;
}

function VehicleMenu() {
  const stage = useStage([1000, 900, 900, 900, 900]);
  const rows = [["package", "Trunk"], ["wrench", "Hood"], ["key-round", "Engine"], ["zap", "Lights"]] as const;
  return <div className="demo-panel">
    <div className="demo-panel__head"><Cap on={stage > 0} wide>ALT</Cap>Hold, look at your car</div>
    <ul className="demo-list">{rows.map(([icon, label], i) =>
      <li key={label} className={stage > 0 && i === stage - 1 ? "is-on" : stage === 0 ? "is-dim" : ""}><Icon name={icon} size={16} /><span>{label}</span></li>)}</ul>
  </div>;
}

function Gauge() {
  const litres = useTicker(34, 1, -0.5, 110);
  const speed = useTicker(40, 96, 0.8, 110);
  const fraction = litres / 50;
  return <div className="demo-gauge">
    <VehicleCluster vehicle={{ active: true, label: "Makigai MaiMai", speedKph: speed, gear: "3", health: 0.92,
      fuel: { litres, capacity: 50, fraction, low: fraction < 0.15, empty: litres <= 1 } }} />
    <Caption>{fraction < 0.15 ? <><b className="demo-alert">RESERVE</b>: find a station now</> : <>The gauge on your dashboard, right side</>}</Caption>
  </div>;
}

function Pump({ keys }: { keys: DemoKeys }) {
  const stage = useStage([1000, 1000, 1000, 2600]);
  const litres = useTicker(0, 30, 1, 70);
  const rows = [["map-pin", "Park by a pump"], ["key-round", "Engine off"], ["footprints", "Step out"], ["fuel", "Use the pump"]] as const;
  return <div className="demo-pump">
    <ol>{rows.map(([icon, label], i) => <li key={label} className={i < stage ? "is-done" : i === stage ? "is-on" : ""}>
      <span>{i < stage ? DONE : <Icon name={icon} size={15} />}</span>{label}{i === 3 && <Cap on={stage === 3}>{keys.interact ?? "E"}</Cap>}</li>)}</ol>
    <div className={`demo-pump__meter${stage === 3 ? " is-on" : ""}`}><small>LITRES</small><b>{stage === 3 ? litres.toFixed(0) : "0"}</b><small>TO PAY</small><b>{formatMoney(stage === 3 ? Math.ceil(litres * 2.4) : 0)}</b></div>
  </div>;
}

function Jerrycan() {
  const stage = useStage([1300, 1300, 2000]);
  return <div className="demo-can">
    <div className="demo-can__slot"><Item icon="fuel" /><b>Jerrycan</b><small>10 L · 12 kg</small></div>
    <Icon name="arrow-right" size={20} />
    <div className="demo-can__tank"><small>TANK</small><span className="demo-bar"><i style={{ width: stage === 2 ? "24%" : "4%" }} className={stage === 2 ? "" : "is-low"} /></span>
      <b>{stage === 2 ? "+10 L" : stage === 1 ? "Pouring…" : "Empty, far from a station"}</b></div>
  </div>;
}

function Work({ currency }: { currency?: string }) {
  const stage = useStage([1300, 1300, 1300, 1500]);
  const rows = [["box", "Collect"], ["wrench", "Process"], ["banknote", "Sell"]] as const;
  return <div className="demo-work">
    {rows.map(([icon, label], i) => <div key={label} className={`demo-work__stage${i === stage ? " is-on" : i < stage ? " is-done" : ""}`}>
      <span><Icon name={icon} size={24} /></span><b>{label}</b>{i < 2 && <i className="demo-work__arrow"><Icon name="chevron-right" size={16} /></i>}</div>)}
    {stage === 3 && <em className="demo-fly demo-fly--in">+{formatMoney(45, currency)} PAY</em>}
  </div>;
}

function Payday() {
  const money = useStore(s => s.state.money);
  const stage = useStage([1200, 2600]);
  const balance = money.bank?.balance ?? 0;
  return <div className="demo-panel">
    <div className="demo-panel__head"><Icon name="landmark" size={16} />NIGHT CITY BANK<span>{money.bank?.number ?? ""}</span></div>
    <div className="demo-result"><small>BALANCE</small><b className={stage === 1 ? "is-on" : ""}>{formatMoney(balance, money.currency)}</b>
      <span>{stage === 1 ? <>{DONE} Practice pay received</> : "Player menu → Identity"}</span></div>
  </div>;
}

/* ---------- In the objective card ---------- */

function MenuDemo({ keys }: { keys: DemoKeys }) {
  const stage = useStage([900, 700, 700, 1600]);
  const rows = ["Identity", "Inventory", "Animations", "Free camera"];
  return <div className="demo-mini">
    <Cap on={stage === 0}>{keys.menu ?? "F1"}</Cap>
    <ul className={`demo-mini__menu${stage > 0 ? " is-open" : ""}`}>{rows.map((r, i) =>
      <li key={r} className={i === 0 && stage >= 2 ? (stage === 3 ? "is-picked" : "is-on") : ""}>{r}{i === 0 && stage === 3 && <Icon name="mouse-pointer-click" size={13} />}</li>)}</ul>
  </div>;
}
function InventoryDemo({ keys }: { keys: DemoKeys }) {
  const stage = useStage([900, 2600]);
  return <div className="demo-mini">
    <Cap on={stage === 0}>{keys.inventory ?? "I"}</Cap>
    <div className={`demo-mini__grid${stage > 0 ? " is-open" : ""}`}>
      <Item name="water" icon="droplet" count={5} /><Item name="burrito" icon="sandwich" count={5} /><span /><span /><span /><span />
    </div>
  </div>;
}
function ShopDemo({ keys }: { keys: DemoKeys }) {
  const stage = useStage([900, 900, 900, 900, 1500]);
  return <div className="demo-mini">
    <Cap on={stage === 0}>{keys.interact ?? "E"}</Cap>
    <div className="demo-mini__shop">
      <span className={stage >= 1 ? "is-on" : ""}><Item name="water" icon="droplet" /><Icon name="plus" size={12} /></span>
      <span className="demo-mini__pay"><i className={stage >= 2 && stage % 2 === 0 ? "is-on" : ""}>CASH</i><i className={stage === 3 ? "is-on" : ""}>BANK</i></span>
      <span className={`demo-mini__confirm${stage === 4 ? " is-done" : stage === 3 ? " is-on" : ""}`}>{stage === 4 ? DONE : "CONFIRM"}</span>
    </div>
  </div>;
}
function DrinkDemo({ keys }: { keys: DemoKeys }) {
  const stage = useStage([900, 800, 2000, 1400]);
  return <div className="demo-mini">
    <Cap on={stage === 0}>{keys.inventory ?? "I"}</Cap>
    <span className={`demo-mini__use${stage >= 1 ? " is-on" : ""}`}><Item name="water" icon="droplet" /><i>USE</i></span>
    <span className={`demo-ring${stage === 2 ? " is-run" : stage === 3 ? " is-done" : ""}`}><Icon name={stage === 3 ? "check" : "footprints"} size={14} /></span>
    <span className="demo-mini__vital"><Icon name="droplet" size={14} /><span className="demo-bar"><i style={{ width: stage === 3 ? "78%" : "38%" }} /></span></span>
  </div>;
}
function ActivityDemo({ keys, kind }: { keys: DemoKeys; kind: "collect" | "process" | "sell" }) {
  const stage = useStage([900, 2200, 1500]);
  const from = { collect: null, process: "box", sell: "package-open" }[kind];
  const to = { collect: "box", process: "package-open", sell: "landmark" }[kind];
  const label = { collect: "Collecting… stay still", process: "Sorting parts… stay still", sell: "Selling" }[kind];
  return <div className="demo-mini">
    <Cap on={stage === 0}>{keys.interact ?? "E"}</Cap>
    {from && <span className={`demo-mini__token${stage >= 1 ? " is-gone" : ""}`}><Icon name={from} size={18} /></span>}
    <span className="demo-mini__progress"><small>{stage === 2 ? "Done" : label}</small><span className="demo-bar"><i className={stage === 1 ? "is-run" : ""} style={{ width: stage === 0 ? "0%" : "100%" }} /></span></span>
    <span className={`demo-mini__token${stage === 2 ? " is-new" : " is-wait"}`}><Icon name={to} size={18} />{kind === "sell" && stage === 2 && <b>+€$</b>}</span>
  </div>;
}

/** The title over a dialogue demo. */
const TITLES: Record<string, string> = {
  rules: "Out there", tour: "Your first day", card: "Your citizen card", money: "Cash and bank", transfer: "Bank transfer",
  rental: "Rent-a-Ride desk", keys: "Your key", vehicle: "Vehicle menu", gauge: "Your dashboard", pump: "At the pump",
  jerrycan: "Jerrycan", work: "Honest work", payday: "Your account",
};

export function DialogueDemo({ id, keys, map }: { id: string; keys: DemoKeys; map?: TutorialStop[] }) {
  const currency = useStore(s => s.state.money.currency);
  const body = {
    rules: <Rules />, tour: map?.length ? <HallMap stops={map} tour /> : null, card: <IdentityCard />, money: <Money />,
    transfer: <Transfer />, rental: <Rental />, keys: <Keys keys={keys} />, vehicle: <VehicleMenu />, gauge: <Gauge />,
    pump: <Pump keys={keys} />, jerrycan: <Jerrycan />, work: <Work currency={currency} />, payday: <Payday />,
  }[id];
  if (!body) return null;
  return <aside className="first-day__showcase" key={id} aria-label={`Example: ${TITLES[id] ?? id}`}>
    <header><span>EXAMPLE</span><b>{TITLES[id] ?? id}</b></header>
    {body}
  </aside>;
}

export function StepDemo({ id, keys }: { id: string; keys: DemoKeys }) {
  const body = {
    menu: <MenuDemo keys={keys} />, inventory: <InventoryDemo keys={keys} />, shop: <ShopDemo keys={keys} />, drink: <DrinkDemo keys={keys} />,
    collect: <ActivityDemo keys={keys} kind="collect" />, process: <ActivityDemo keys={keys} kind="process" />, sell: <ActivityDemo keys={keys} kind="sell" />,
  }[id];
  return body ? <div className="first-day__demo" aria-hidden="true" key={id}>{body}</div> : null;
}
