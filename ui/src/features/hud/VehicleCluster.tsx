import type { HudState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import "./cluster.css";

/* The vehicle cluster: a dashboard of three arc gauges. Centre, the speed on a
   270° arc with a gear plate under the number; left, the condition; right, the
   fuel with its reserve zone in red. The vehicle name sits on a plate below.
   Everything is one SVG for the arcs plus HTML for the readouts, so the fonts
   and icons are the design system's. Angles: 0 = top, clockwise. */

const W = 540, H = 300;
const CENTRE = { x: 270, y: 140, r: 100 };
const SIDE_R = 54;
const LEFT = { x: 80, y: 146 };
const RIGHT = { x: W - 80, y: 146 };
const SPEED_MAX = 240;

function pt(cx: number, cy: number, r: number, deg: number): [number, number] {
  const a = ((deg - 90) * Math.PI) / 180;
  return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
}
function arcPath(cx: number, cy: number, r: number, from: number, to: number): string {
  const [x1, y1] = pt(cx, cy, r, from);
  const [x2, y2] = pt(cx, cy, r, to);
  return `M${x1.toFixed(2)} ${y1.toFixed(2)} A${r} ${r} 0 ${to - from > 180 ? 1 : 0} 1 ${x2.toFixed(2)} ${y2.toFixed(2)}`;
}

interface SegmentsProps {
  cx: number; cy: number; r: number; from: number; to: number; count: number;
  /** 0..1 of the sweep that is lit. */
  fill: number;
  /** Lit segments counted from the start of the sweep that are the reserve zone. */
  reserve?: number;
  /** Fill from the end of the sweep instead of the start (mirrored gauges). */
  reversed?: boolean;
  width: number; gap?: number; tone?: string;
}
function Segments({ cx, cy, r, from, to, count, fill, reserve = 0, reversed = false, width, gap = 2.4, tone = "" }: SegmentsProps) {
  const sweep = to - from, step = sweep / count;
  const lit = Math.round(Math.max(0, Math.min(1, fill)) * count);
  return <g className={`cl-seg${tone ? ` cl-seg--${tone}` : ""}`} strokeWidth={width}>
    {Array.from({ length: count }, (_, i) => {
      const a = from + i * step + gap / 2, b = from + (i + 1) * step - gap / 2;
      const order = reversed ? count - 1 - i : i;
      const on = order < lit;
      const inReserve = order < reserve;
      return <path key={i} d={arcPath(cx, cy, r, a, b)} className={`cl-seg__cell${on ? " is-on" : ""}${inReserve ? " is-reserve" : ""}`} />;
    })}
  </g>;
}

function Ticks({ cx, cy, r, from, to, count, major }: { cx: number; cy: number; r: number; from: number; to: number; count: number; major: number }) {
  const step = (to - from) / count;
  return <g className="cl-ticks">
    {Array.from({ length: count + 1 }, (_, i) => {
      const deg = from + i * step, big = i % major === 0;
      const [x1, y1] = pt(cx, cy, r, deg), [x2, y2] = pt(cx, cy, r - (big ? 7 : 3.5), deg);
      return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} className={big ? "is-major" : undefined} />;
    })}
  </g>;
}

/* Chamfered frame around a side gauge, open towards the centre. */
function SideFrame({ mirror }: { mirror: boolean }) {
  const d = "M 24 50 L 42 32 L 140 32 L 140 38 M 24 50 L 24 222 L 42 240 L 140 240 L 140 234";
  return <path d={d} className="cl-frame" transform={mirror ? `translate(${W} 0) scale(-1 1)` : undefined} />;
}

export function VehicleCluster({ vehicle }: { vehicle: HudState["vehicle"] }) {
  const speed = Math.max(0, vehicle.speedKph ?? 0);
  const health = Math.max(0, Math.min(1, vehicle.health ?? 1));
  const fuel = vehicle.fuel;
  const fuelFraction = fuel ? Math.max(0, Math.min(1, fuel.fraction)) : 0;
  const fuelState = !fuel ? "none" : fuel.empty ? "empty" : fuel.low ? "low" : "ok";
  const gear = vehicle.gear ?? "N";
  const label = (vehicle.label ?? "VEHICLE").toUpperCase();
  const SPEED_FROM = -135, SPEED_TO = 135;

  return <div className={`cluster cluster--fuel-${fuelState}`} style={{ width: W, height: H }} aria-hidden="true">
    <svg className="cluster__svg" viewBox={`0 0 ${W} ${H}`} width={W} height={H}>
      {/* Backplates */}
      <path className="cl-plate" d="M 176 8 L 364 8 L 386 30 L 386 216 L 352 250 L 188 250 L 154 216 L 154 30 Z" />
      <path className="cl-plate cl-plate--side" d="M 16 44 L 40 22 L 132 22 L 146 36 L 146 236 L 132 250 L 40 250 L 16 228 Z" />
      <path className="cl-plate cl-plate--side" d="M 16 44 L 40 22 L 132 22 L 146 36 L 146 236 L 132 250 L 40 250 L 16 228 Z" transform={`translate(${W} 0) scale(-1 1)`} />
      <SideFrame mirror={false} /><SideFrame mirror />

      {/* Speed: outer hairline, ticks, segments */}
      <path className="cl-hair" d={arcPath(CENTRE.x, CENTRE.y, CENTRE.r + 10, SPEED_FROM - 2, SPEED_TO + 2)} />
      <Ticks cx={CENTRE.x} cy={CENTRE.y} r={CENTRE.r + 8} from={SPEED_FROM} to={SPEED_TO} count={40} major={10} />
      <Segments cx={CENTRE.x} cy={CENTRE.y} r={CENTRE.r - 4} from={SPEED_FROM} to={SPEED_TO} count={36} fill={speed / SPEED_MAX} width={9} />
      {[0, 60, 120, 180, 240].map((v) => {
        const [x, y] = pt(CENTRE.x, CENTRE.y, CENTRE.r + 25, SPEED_FROM + (v / SPEED_MAX) * (SPEED_TO - SPEED_FROM));
        return <text key={v} x={x} y={y} className="cl-scale">{v}</text>;
      })}
      {/* Needle marker on the hairline */}
      {(() => {
        const deg = SPEED_FROM + Math.min(1, speed / SPEED_MAX) * (SPEED_TO - SPEED_FROM);
        const [x, y] = pt(CENTRE.x, CENTRE.y, CENTRE.r + 14, deg);
        return <polygon className="cl-needle" points="0,-6 5,3 -5,3" transform={`translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${deg + 180})`} />;
      })()}
      {/* Gear plate */}
      <path className="cl-gear" d={`M ${CENTRE.x - 32} ${CENTRE.y + 84} L ${CENTRE.x - 21} ${CENTRE.y + 71} L ${CENTRE.x + 21} ${CENTRE.y + 71} L ${CENTRE.x + 32} ${CENTRE.y + 84} L ${CENTRE.x + 21} ${CENTRE.y + 97} L ${CENTRE.x - 21} ${CENTRE.y + 97} Z`} />
      <line className="cl-hair" x1={CENTRE.x - 104} y1={CENTRE.y + 84} x2={CENTRE.x - 38} y2={CENTRE.y + 84} />
      <line className="cl-hair" x1={CENTRE.x + 38} y1={CENTRE.y + 84} x2={CENTRE.x + 104} y2={CENTRE.y + 84} />

      {/* Condition: left arc, filling upwards */}
      <path className="cl-hair" d={arcPath(LEFT.x, LEFT.y, SIDE_R + 8, 190, 350)} />
      <Segments cx={LEFT.x} cy={LEFT.y} r={SIDE_R} from={190} to={350} count={16} fill={health} width={9} tone="condition" />

      {/* Fuel: right arc, mirrored, reserve zone red at the bottom */}
      <path className="cl-hair" d={arcPath(RIGHT.x, RIGHT.y, SIDE_R + 8, 10, 170)} />
      <Segments cx={RIGHT.x} cy={RIGHT.y} r={SIDE_R} from={10} to={170} count={16} fill={fuelFraction} reserve={3} reversed width={9} tone="fuel" />

      {/* Name plate */}
      <path className="cl-name-plate" d={`M 150 ${H - 30} L 160 ${H - 41} L ${W - 160} ${H - 41} L ${W - 150} ${H - 30} L ${W - 160} ${H - 19} L 160 ${H - 19} Z`} />
      <path className="cl-hair cl-hair--slash" d={`M 116 ${H - 22} L 128 ${H - 38} M 130 ${H - 22} L 142 ${H - 38} M ${W - 116} ${H - 22} L ${W - 128} ${H - 38} M ${W - 130} ${H - 22} L ${W - 142} ${H - 38}`} />
    </svg>

    {/* Readouts */}
    <div className="cluster__speed" style={{ left: CENTRE.x, top: CENTRE.y - 4 }}>
      <span className="cluster__dashes"><i /><i className="is-on" /><i /></span>
      <span className="cluster__speed-value">{String(Math.min(999, Math.round(speed))).padStart(3, "0")}</span>
      <span className="cluster__speed-unit">KM/H</span>
    </div>
    <div className="cluster__gear" style={{ left: CENTRE.x, top: CENTRE.y + 84 }}><small>GEAR</small><b>{gear}</b></div>

    <div className="cluster__side" style={{ left: LEFT.x + 8, top: LEFT.y }}>
      <Icon name="activity" size={16} />
      <span className="cluster__side-label">CONDITION</span>
      <span className="cluster__side-value">{Math.round(health * 100)}</span>
      <span className="cluster__side-unit">/100</span>
    </div>

    <div className="cluster__side cluster__side--fuel" style={{ left: RIGHT.x - 8, top: RIGHT.y }}>
      <Icon name="fuel" size={16} />
      <span className="cluster__side-label">FUEL</span>
      <span className="cluster__side-value">{fuel ? (fuel.empty ? "0" : Math.round(fuel.litres)) : "--"}</span>
      <span className="cluster__side-unit">L</span>
    </div>
    {fuelState === "low" && <span className="cluster__flag" style={{ left: RIGHT.x, top: RIGHT.y + 72 }}><Icon name="fuel" size={12} /> RESERVE</span>}
    {fuelState === "empty" && <span className="cluster__flag cluster__flag--empty" style={{ left: RIGHT.x, top: RIGHT.y + 72 }}><Icon name="triangle-alert" size={12} /> OUT OF FUEL</span>}

    <span className="cluster__name" style={{ top: H - 30 }}>{label}</span>
  </div>;
}
