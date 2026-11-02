import type { ReactNode } from "react";
import type { JobState } from "@/bridge/protocol";
import { formatMoney } from "@/bridge/money";
import { Icon } from "@/design/components";
import { Cap, Item, useStage, useTicker } from "@/features/tutorial/demos";
import "./guide-demos.css";

/* The pictures of the job guide: each page of a job's `guide` (shared/jobs.lua)
   names one with `demo`. They show the real screens and gestures in a loop and
   never send an action; with reduced motion they hold their last frame. The
   sample figures are examples, the text beside them says where the real ones are. */

type Ctx = { job: JobState; currency?: string };
const money = (n: number, currency?: string) => formatMoney(n, currency);

function Bag({ item, icon, count, weight }: { item?: string; icon: string; count: number; weight: number }) {
  return <div className="gd-bag">
    <small><Icon name="backpack" size={13} />YOUR BAG</small>
    <div className="gd-bag__slots">{count > 0 ? <Item name={item} icon={icon} count={count} /> : <span />}<span /><span /></div>
    <span className="demo-bar"><i style={{ width: `${Math.min(100, weight)}%` }} className={weight > 85 ? "is-low" : ""} /></span>
  </div>;
}
function Progress({ label, run, done }: { label: string; run: boolean; done?: boolean }) {
  return <div className="gd-progress"><small>{done ? "Done" : label}</small>
    <span className="demo-bar"><i className={run ? "is-run" : ""} style={{ width: run || done ? "100%" : "0%" }} /></span></div>;
}
function Row({ children, className }: { children: ReactNode; className?: string }) { return <div className={`gd-row ${className ?? ""}`}>{children}</div>; }

/* ---------- Courier ---------- */

// A sample route: the office, two pickups, two addresses (SVG units).
const ROUTE = [
  { x: 14, y: 70, kind: "office", label: "You" }, { x: 40, y: 50, kind: "pickup", label: "P1" }, { x: 66, y: 66, kind: "pickup", label: "P2" },
  { x: 92, y: 30, kind: "dropoff", label: "D1" }, { x: 140, y: 18, kind: "dropoff", label: "D2" },
] as const;
function CourierRoute({ currency }: Ctx) {
  const stage = useStage([700, 900, 900, 900, 900, 2200]);
  const reached = Math.min(stage, ROUTE.length - 1);
  const km = [0, 0.4, 0.8, 1.5, 2.4][reached] ?? 2.4;
  const points = ROUTE.slice(0, reached + 1).map((p) => `${p.x},${p.y}`).join(" ");
  return <div className="gd-route">
    <svg viewBox="0 0 156 84" role="img" aria-label="A delivery route: pickups first, then the addresses">
      <rect className="gd-route__ground" x={0} y={0} width={156} height={84} rx={3} />
      <path className="gd-route__street" d="M0 58 H156 M52 0 V84 M112 0 V84" />
      <polyline className="gd-route__all" points={ROUTE.map((p) => `${p.x},${p.y}`).join(" ")} />
      <polyline className="gd-route__done" points={points} />
      {ROUTE.map((p, i) => <g key={p.label} className={`gd-route__stop is-${p.kind}${i <= reached ? " is-reached" : ""}`} transform={`translate(${p.x} ${p.y})`}>
        {i === reached && <circle className="gd-route__ping" r={6} />}
        <circle r={p.kind === "office" ? 2.6 : 3.6} /><text y={-6}>{p.label}</text></g>)}
    </svg>
    <div className="gd-route__legend">
      <span><i className="is-pickup" />Pickups first</span><span><i className="is-dropoff" />Then the addresses</span>
      <b>{km.toFixed(1)} km · {stage === 5 ? money(342, currency) : "…"}</b>
    </div>
  </div>;
}

function CourierDispatch({ currency }: Ctx) {
  const stage = useStage([800, 800, 900, 2600]);
  const rows = [["book-open", "Job guide"], ["route", "Start a run"], ["landmark", "Paycheck"]] as const;
  return <div className="gd-split">
    <div className="gd-menu">
      <div className="gd-menu__head"><Cap on={stage === 0}>F1</Cap><b>{stage < 1 ? "PLAYER MENU" : "MY JOB"}</b></div>
      <ul>{(stage < 1 ? [["user", "Identity"], ["landmark", "Bank"], ["briefcase", "My job"]] as const : rows).map(([icon, label], i) =>
        <li key={label} className={(stage === 0 && i === 2) || (stage >= 2 && label === "Start a run") ? "is-on" : ""}><Icon name={icon} size={14} />{label}
          {stage === 2 && label === "Start a run" && <Cap on>↵</Cap>}</li>)}</ul>
    </div>
    <div className={`gd-ticket${stage === 3 ? " is-on" : ""}`}>
      <small><Icon name="package" size={13} />DISPATCH</small>
      {stage === 3 ? <><b>3 orders · 2.4 km</b><span>{money(342, currency)} on completion</span><em>Follow your GPS</em></>
        : <span className="gd-ticket__wait">Waiting for a route…</span>}
    </div>
  </div>;
}

function CourierHud({ currency }: Ctx) {
  const stage = useStage([1600, 1600, 1600, 1600]);
  const stops = ["Pick up · Noodle bar", "Pick up · Burger stand", "Deliver · Megabuilding H8", "Deliver · Kabuki block"];
  const carried = [0, 1, 2, 1][stage] ?? 0;
  return <div className="gd-hud">
    <div className="gd-hud__card">
      <div className="gd-hud__head"><Icon name="package" size={13} /><span>DELIVERY RUN</span><b>0{stage + 1} / 04</b></div>
      <h4 key={stage}>{stops[stage]}</h4>
      <p>{stage < 2 ? "Collect the order at the marker (E)." : stage === 3 ? "Hand over the last order (E): the pay lands in your bank." : "Hand over the order at the marker (E)."}</p>
      <div className="gd-hud__track"><i style={{ width: `${(stage + 1) * 25}%` }} /></div>
      <div className="gd-hud__orders"><Icon name="package" size={12} />{carried} carried · 2 orders · 2.4 km</div>
      <footer><span>{money(342, currency)} <small>on completion</small></span><small>/job gps · /job cancel</small></footer>
    </div>
    <div className="gd-hud__marker"><span className="gd-hud__beam" /><Icon name="map-pin" size={20} /><small>Yellow marker</small></div>
  </div>;
}

function CourierPickup() {
  const stage = useStage([900, 2300, 1800]);
  return <Row>
    <div className="gd-spot"><Icon name="utensils" size={26} /><small>Pickup point</small></div>
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><Progress label="Collecting the order… stay still" run={stage === 1} done={stage === 2} /></div>
    <Bag item="delivery_order" icon="package" count={stage === 2 ? 2 : 1} weight={stage === 2 ? 46 : 40} />
  </Row>;
}

function CourierDropoff({ currency }: Ctx) {
  const stage = useStage([900, 2000, 1500, 2200]);
  const last = stage === 3;
  return <Row>
    <div className={`gd-spot${stage >= 2 ? " is-done" : ""}`}><Icon name={last ? "building-2" : "house"} size={26} /><small>{last ? "Last address" : "Address"}</small>
      {stage >= 2 && <span className="gd-spot__check"><Icon name="check" size={14} /></span>}</div>
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><Progress label="Handing the order over…" run={stage === 1} done={stage >= 2} /></div>
    <div className="gd-col">
      <Bag item="delivery_order" icon="package" count={stage >= 2 ? (last ? 0 : 1) : last ? 1 : 2} weight={stage >= 2 ? 40 : 46} />
      {last && <em className="demo-fly demo-fly--in">+{money(342, currency)} BANK</em>}
    </div>
  </Row>;
}

function CourierPay({ currency }: Ctx) {
  const stage = useStage([900, 900, 900, 2600]);
  const parts = [{ label: "Base", value: 40, icon: "briefcase" }, { label: "4 stops", value: 80, icon: "map-pin" }, { label: "2.4 km", value: 216, icon: "route" }];
  const total = parts.slice(0, stage).reduce((sum, p) => sum + p.value, 0);
  return <div className="gd-pay">
    {parts.map((p, i) => <div key={p.label} className={`gd-pay__part${i < stage ? " is-on" : ""}`}>
      <Icon name={p.icon} size={16} /><span>{p.label}</span><span className="gd-pay__bar"><i style={{ width: i < stage ? `${Math.round(p.value / 2.4)}%` : "0%" }} /></span><b>+{money(p.value, currency)}</b></div>)}
    <div className={`gd-pay__total${stage === 3 ? " is-on" : ""}`}><span>Run pay</span><b>{money(stage === 3 ? 336 : total, currency)}</b></div>
    <small className="gd-note">Example figures. Your run's real pay is shown when it is drawn.</small>
  </div>;
}

/* ---------- Work orders (any run job) ---------- */

function RunDesk({ currency, job }: Ctx) {
  const stage = useStage([900, 1000, 2400]);
  return <Row>
    <div className="gd-spot"><Icon name="briefcase" size={26} /><small>Job Center desk</small></div>
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><span className={`gd-button${stage === 1 ? " is-on" : ""}`}>Start a run <Icon name="arrow-right" size={13} /></span></div>
    <div className={`gd-ticket${stage === 2 ? " is-on" : ""}`}><small><Icon name={job.art?.icon ?? "route"} size={13} />WORK ORDER</small>
      {stage === 2 ? <><b>{job.run?.label ?? "Route"}</b><span>{money(job.run?.reward ?? 260, currency)} on completion</span></> : <span className="gd-ticket__wait">…</span>}</div>
  </Row>;
}

function RooftopLift() {
  const stage = useStage([900, 1600, 2000]);
  return <Row>
    <div className="gd-building"><span className={`gd-building__you is-${stage}`}><Icon name="user" size={16} /></span><Icon name="building-2" size={70} /></div>
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><b className="gd-caption">{stage === 2 ? "On the roof" : "Service access"}</b><small className="gd-note">No climbing needed</small></div>
  </Row>;
}

function RooftopClean() {
  const stage = useStage([900, 2200, 1600]);
  return <Row>
    <div className={`gd-spot${stage === 2 ? " is-done" : ""}`}><Icon name="fan" size={28} /><small>AC unit</small></div>
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><Progress label="Cleaning… stay still" run={stage === 1} done={stage === 2} /></div>
  </Row>;
}

function RunReport({ currency, job }: Ctx) {
  const stage = useStage([700, 700, 700, 2400]);
  const rows = ["Unit 1", "Unit 2", "Unit 3"];
  return <Row>
    <ul className="gd-checklist">{rows.map((r, i) => <li key={r} className={i < stage ? "is-done" : ""}><span>{i < stage ? <Icon name="check" size={12} /> : i + 1}</span>{r}</li>)}</ul>
    <div className="gd-col">{stage === 3 && <em className="demo-fly demo-fly--in">+{money(job.run?.reward ?? 260, currency)} BANK</em>}
      <b className="gd-caption">{stage === 3 ? "Report returned" : "Clean every unit"}</b></div>
  </Row>;
}

function RunCancel() {
  const stage = useStage([900, 1100, 2400]);
  return <div className="gd-split">
    <div className="gd-menu">
      <div className="gd-menu__head"><Cap>F1</Cap><b>MY JOB</b></div>
      <ul><li><Icon name="navigation" size={14} />GPS to my next stop</li>
        <li className={stage >= 1 ? "is-on is-danger" : ""}><Icon name="x" size={14} />Abandon this run{stage === 1 && <Cap on>↵</Cap>}</li></ul>
    </div>
    <div className="gd-col">
      <Bag item="delivery_order" icon="package" count={stage === 2 ? 0 : 2} weight={stage === 2 ? 34 : 46} />
      <b className="gd-caption">{stage === 2 ? "Run ended · no pay" : "Orders in your bag"}</b>
    </div>
  </div>;
}

/* ---------- Free item work ---------- */

function WorkCycle({ job, currency }: Ctx) {
  const stage = useStage([1300, 1300, 1300, 1700]);
  const w = job.work;
  const steps = [
    { label: "Collect", node: <Item name={w?.rawItem} icon="box" /> },
    { label: "Process", node: <Item name={w?.productItem} icon="package-open" /> },
    { label: "Sell", node: <span className="demo-item"><Icon name="landmark" size={22} /></span> },
  ];
  return <div className="gd-cycle">
    {steps.map((s, i) => <div key={s.label} className={`gd-cycle__step${i === stage ? " is-on" : i < stage ? " is-done" : ""}`}>
      {s.node}<b>{s.label}</b><small>{i === 0 ? w?.raw : i === 1 ? w?.product : w ? `${money(w.price, currency)} / unit` : ""}</small>
      {i < 2 && <i className="gd-cycle__arrow"><Icon name="chevron-right" size={16} /></i>}</div>)}
    {stage === 3 && <em className="demo-fly demo-fly--in">BANK</em>}
  </div>;
}

function WorkCollect({ job }: Ctx) {
  const count = useTicker(1, 6, 1, 1100);
  const w = job.work;
  return <Row>
    <div className="gd-spot"><Icon name="map-pin" size={26} /><small>Collection point</small></div>
    <div className="gd-col"><Cap on={count === 1}>E</Cap><Progress label={`Collecting ${w?.raw ?? "items"}… stay still`} run={count % 2 === 0} done={count === 6} />
      <small className="gd-note">The next one starts on its own</small></div>
    <Bag item={w?.rawItem} icon="box" count={count} weight={count * 16} />
  </Row>;
}

function WorkTrunk({ job }: Ctx) {
  const stage = useStage([1100, 900, 1600, 1600]);
  const w = job.work;
  const moved = stage >= 2 ? 5 : 0;
  return <Row>
    <Bag item={w?.rawItem} icon="box" count={5 - moved} weight={stage >= 2 ? 0 : 92} />
    <div className="gd-col"><Cap on={stage === 1} wide>ALT</Cap><span className={`gd-button${stage === 1 ? " is-on" : ""}`}><Icon name="package" size={13} />Trunk</span></div>
    <div className={`gd-trunk${stage >= 2 ? " is-on" : ""}`}><Icon name="car" size={34} />
      <div className="gd-bag__slots">{moved ? <Item name={w?.rawItem} icon="box" count={moved} /> : <span />}<span /><span /></div>
      <small>{stage === 3 ? "Room to collect again" : "Vehicle trunk"}</small></div>
  </Row>;
}

function WorkProcess({ job }: Ctx) {
  const stage = useStage([900, 1300, 1300, 1500]);
  const w = job.work;
  const done = Math.max(0, stage - 1) * 2;
  return <Row>
    <Item name={w?.rawItem} icon="box" count={Math.max(0, 5 - done)} />
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><Progress label="Processing… stay still" run={stage === 1 || stage === 2} done={stage === 3} /></div>
    <Item name={w?.productItem} icon="package-open" count={done} />
  </Row>;
}

function WorkSell({ job, currency }: Ctx) {
  const stage = useStage([900, 1600, 2300]);
  const w = job.work;
  return <Row>
    <Item name={w?.productItem} icon="package-open" count={stage === 2 ? 0 : 6} />
    <div className="gd-col"><Cap on={stage === 0}>E</Cap><Progress label="Selling…" run={stage === 1} done={stage === 2} /></div>
    <div className="gd-col"><span className="demo-item"><Icon name="landmark" size={22} /></span>
      {stage === 2 && <em className="demo-fly demo-fly--in">+{money((w?.price ?? 18) * 6, currency)} BANK</em>}</div>
  </Row>;
}

function Paycheck({ job, currency }: Ctx) {
  const minutes = job.paycheckMinutes ?? 30;
  const left = useTicker(minutes, 0, -1, Math.max(60, 3000 / Math.max(1, minutes)));
  return <Row>
    <div className="gd-clock"><Icon name="clock" size={26} /><b>{String(left).padStart(2, "0")}:00</b><small>every {minutes} min</small></div>
    <Icon name="arrow-right" size={18} />
    <div className="gd-col"><span className="demo-item"><Icon name="landmark" size={22} /></span>
      {left === 0 && <em className="demo-fly demo-fly--in">+{money(job.salary, currency)} PAYCHECK</em>}
      <b className="gd-caption">{job.gradeLabel} · {money(job.salary, currency)}</b></div>
  </Row>;
}

const DEMOS: Record<string, (ctx: Ctx) => ReactNode> = {
  "courier-route": CourierRoute, "courier-dispatch": CourierDispatch, "courier-hud": CourierHud,
  "courier-pickup": CourierPickup, "courier-dropoff": CourierDropoff, "courier-pay": CourierPay,
  "run-desk": RunDesk, "rooftop-lift": RooftopLift, "rooftop-clean": RooftopClean, "run-report": RunReport, "run-cancel": RunCancel,
  "work-cycle": WorkCycle, "work-collect": WorkCollect, "work-trunk": WorkTrunk, "work-process": WorkProcess, "work-sell": WorkSell,
  paycheck: Paycheck,
};

export function hasGuideDemo(id?: string): boolean { return !!id && id in DEMOS; }

export function GuideDemo({ id, job, currency }: { id: string; job: JobState; currency?: string }) {
  const Demo = DEMOS[id];
  return Demo ? <div className="gd" aria-hidden="true" key={id}><Demo job={job} currency={currency} /></div> : null;
}
