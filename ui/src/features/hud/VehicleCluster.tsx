import type { HudState } from "@/bridge/protocol";
import { Icon } from "@/design/components";
import "./cluster.css";

/* The vehicle cluster: one compact plate, three arc gauges. Centre, the speed
   on a 240° arc with the gear under the number; left, the condition; right,
   the fuel with its reserve zone in red. The vehicle name runs under the
   plate. Arcs are SVG, readouts are HTML so fonts and icons stay the design
   system's. Drawn at W x H and shown at SCALE. Angles: 0 = top, clockwise. */

const W = 400, H = 214;
const SCALE = 0.56;
const CENTRE = { x: 200, y: 96, r: 70 };
const SIDE_R = 40;
const LEFT = { x: 62, y: 108 };
const RIGHT = { x: W - 62, y: 108 };
const SPEED_MAX = 240;
const SPEED_FROM = -120, SPEED_TO = 120;

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
  /** Lit segments counted from the start of the fill that form the reserve zone. */
  reserve?: number;
  /** Fill from the end of the sweep instead of the start (mirrored gauges). */
  reversed?: boolean;
  width: number; gap?: number; tone?: string;
}
function Segments({ cx, cy, r, from, to, count, fill, reserve = 0, reversed = false, width, gap = 3, tone = "" }: SegmentsProps) {
  const step = (to - from) / count;
  const lit = Math.round(Math.max(0, Math.min(1, fill)) * count);
  return <g className={`cl-seg${tone ? ` cl-seg--${tone}` : ""}`} strokeWidth={width}>
    {Array.from({ length: count }, (_, i) => {
      const a = from + i * step + gap / 2, b = from + (i + 1) * step - gap / 2;
      const order = reversed ? count - 1 - i : i;
      return <path key={i} d={arcPath(cx, cy, r, a, b)} className={`cl-seg__cell${order < lit ? " is-on" : ""}${order < reserve ? " is-reserve" : ""}`} />;
    })}
  </g>;
}

export function VehicleCluster({ vehicle }: { vehicle: HudState["vehicle"] }) {
  const speed = Math.max(0, vehicle.speedKph ?? 0);
  const health = Math.max(0, Math.min(1, vehicle.health ?? 1));
  const fuel = vehicle.fuel;
  const fuelFraction = fuel ? Math.max(0, Math.min(1, fuel.fraction)) : 0;
  const fuelState = !fuel ? "none" : fuel.empty ? "empty" : fuel.low ? "low" : "ok";
  const gear = vehicle.gear ?? "N";
  const label = (vehicle.label ?? "VEHICLE").toUpperCase();

  return <div className="cluster-frame" style={{ width: Math.round(W * SCALE), height: Math.round(H * SCALE) }} aria-hidden="true">
    <div className={`cluster cluster--fuel-${fuelState}`} style={{ width: W, height: H, transform: `scale(${SCALE})` }}>
      <svg className="cluster__svg" viewBox={`0 0 ${W} ${H}`} width={W} height={H}>
        {/* One plate for the three gauges, chamfered top corners */}
        <path className="cl-plate" d={`M 14 22 L 30 6 L ${W - 30} 6 L ${W - 14} 22 L ${W - 14} 178 L ${W - 26} 190 L 26 190 L 14 178 Z`} />
        <path className="cl-accent" d={`M 30 6 L 110 6 M ${W - 110} 6 L ${W - 30} 6`} />

        {/* Speed */}
        <path className="cl-track" d={arcPath(CENTRE.x, CENTRE.y, CENTRE.r + 8, SPEED_FROM, SPEED_TO)} />
        <Segments cx={CENTRE.x} cy={CENTRE.y} r={CENTRE.r} from={SPEED_FROM} to={SPEED_TO} count={30} fill={speed / SPEED_MAX} width={10} />

        {/* Condition, filling upwards on the left */}
        <Segments cx={LEFT.x} cy={LEFT.y} r={SIDE_R} from={190} to={350} count={12} fill={health} width={9} tone="condition" />

        {/* Fuel, mirrored, reserve zone at the bottom */}
        <Segments cx={RIGHT.x} cy={RIGHT.y} r={SIDE_R} from={10} to={170} count={12} fill={fuelFraction} reserve={2} reversed width={9} tone="fuel" />
      </svg>

      <div className="cluster__speed" style={{ left: CENTRE.x, top: CENTRE.y - 4 }}>
        <span className="cluster__speed-value">{String(Math.min(999, Math.round(speed))).padStart(3, "0")}</span>
        <span className="cluster__speed-unit">KM/H</span>
      </div>
      <div className="cluster__gear" style={{ left: CENTRE.x, top: CENTRE.y + 66 }}><b>{gear}</b></div>

      <div className="cluster__side" style={{ left: LEFT.x + 6, top: LEFT.y }}>
        <Icon name="activity" size={20} />
        <span className="cluster__side-value">{Math.round(health * 100)}</span>
        <span className="cluster__side-unit">COND</span>
      </div>
      <div className="cluster__side cluster__side--fuel" style={{ left: RIGHT.x - 6, top: RIGHT.y }}>
        <Icon name="fuel" size={20} />
        <span className="cluster__side-value">{fuel ? (fuel.empty ? "0" : Math.round(fuel.litres)) : "--"}</span>
        <span className="cluster__side-unit">{fuelState === "empty" ? "EMPTY" : fuelState === "low" ? "RESERVE" : "LITRES"}</span>
      </div>

      <span className="cluster__name" style={{ top: H - 10 }}>{label}</span>
    </div>
  </div>;
}
