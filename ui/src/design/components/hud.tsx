import type { HTMLAttributes, ReactNode } from "react";
import { Icon, type IconName } from "./Icon";
import { cx } from "./core";

/* ---------- VitalBar ---------- */
export type VitalTone = "health" | "armor" | "food" | "drink" | "stamina" | "accent" | "fuel";
const VITAL_META: Record<VitalTone, { code: string; icon: IconName }> = {
  health: { code: "HP", icon: "heart-pulse" },
  armor: { code: "AR", icon: "shield" },
  food: { code: "FD", icon: "beef" },
  drink: { code: "DR", icon: "droplet" },
  stamina: { code: "ST", icon: "zap" },
  accent: { code: "--", icon: "activity" },
  fuel: { code: "FUEL", icon: "fuel" },
};
const BAR_HEIGHT = { sm: "var(--bar-h-sm)", md: "var(--bar-h-md)", lg: "var(--bar-h-lg)" } as const;

export interface VitalBarProps extends HTMLAttributes<HTMLDivElement> {
  tone?: VitalTone;
  value?: number;
  max?: number;
  label?: ReactNode;
  size?: keyof typeof BAR_HEIGHT;
  width?: number | string;
  segments?: number;
  showValue?: boolean;
  showIcon?: boolean;
  critical?: number;
}
export function VitalBar({
  tone = "health", value = 100, max = 100, label, size = "md", width = "var(--bar-w)",
  segments = 20, showValue = true, showIcon = true, critical = 25, className, ...rest
}: VitalBarProps) {
  const meta = VITAL_META[tone];
  const pct = Math.max(0, Math.min(100, max > 0 ? (value / max) * 100 : 0));
  const low = pct <= critical;
  return (
    <div className={cx("o77-vital", `o77-vital--${tone}`, low && "o77-vital--low", className)} {...rest}>
      {showIcon && <span className="o77-vital__icon"><Icon name={meta.icon} size={size === "lg" ? 16 : 13} /></span>}
      <div style={{ width }}>
        {(label || showValue) && (
          <div className="o77-vital__meta">
            <span className="o77-vital__code">{label ?? meta.code}</span>
            {showValue && <span className="o77-vital__value">{Math.round(pct)}</span>}
          </div>
        )}
        <div className="o77-vital__track" style={{ height: BAR_HEIGHT[size] }}>
          {Array.from({ length: segments }, (_, i) => (
            <span key={i} className={cx("o77-vital__cell", (i + 1) / segments <= pct / 100 + 1e-4 && "o77-vital__cell--on")} />
          ))}
        </div>
      </div>
    </div>
  );
}

/* ---------- MicIndicator ---------- */
export type MicState = "off" | "idle" | "talking" | "muted";
export type VoiceRange = "whisper" | "normal" | "shout";
const MIC_STATES: Record<MicState, { color: string; icon: IconName; text: string }> = {
  off: { color: "var(--voice-off)", icon: "mic-off", text: "VOICE OFF" },
  idle: { color: "var(--voice-idle)", icon: "mic", text: "OPEN" },
  talking: { color: "var(--voice-live)", icon: "mic", text: "TRANSMIT" },
  muted: { color: "var(--voice-muted)", icon: "mic-off", text: "MUTED" },
};
const RANGES: Array<{ id: VoiceRange; label: string; color: string }> = [
  { id: "whisper", label: "WHISPER", color: "var(--voice-whisper)" },
  { id: "normal", label: "NORMAL", color: "var(--voice-live)" },
  { id: "shout", label: "SHOUT", color: "var(--voice-shout)" },
];
const MIC_BARS = 14;

export interface MicIndicatorProps extends HTMLAttributes<HTMLDivElement> {
  state?: MicState;
  level?: number;
  range?: VoiceRange;
  rangeMetres?: Partial<Record<VoiceRange, number>>;
  onRangeChange?: (range: VoiceRange) => void;
  showRange?: boolean;
  showMeter?: boolean;
  keyHint?: string;
}
export function MicIndicator({
  state = "idle", level = 0, range = "normal", rangeMetres, onRangeChange, showRange = true, showMeter = true, keyHint = "N", className, ...rest
}: MicIndicatorProps) {
  const s = MIC_STATES[state];
  const active = state === "talking";
  const current = RANGES.find((r) => r.id === range) ?? RANGES[1]!;
  const lit = Math.round(Math.max(0, Math.min(1, active ? level : 0)) * MIC_BARS);
  return (
    <div className={cx("o77-mic", active && "o77-mic--talking", className)} {...rest}>
      <div className="o77-mic__row">
        <span className="o77-mic__glyph" style={{ color: s.color }}><Icon name={s.icon} size={16} /></span>
        <span className="o77-mic__state" style={{ color: s.color }}>{s.text}</span>
        {showMeter && (
          <span className="o77-mic__meter">
            {Array.from({ length: MIC_BARS }, (_, i) => {
              const on = i < lit;
              const peak = i >= MIC_BARS - 3;
              return <span key={i} className="o77-mic__bar" style={{ height: 5 + (i / MIC_BARS) * 11, background: on ? (peak ? "var(--voice-peak)" : current.color) : undefined }} />;
            })}
          </span>
        )}
      </div>
      {showRange && (
        <div className="o77-mic__ranges">
          {RANGES.map((r) => {
            const on = r.id === current.id;
            const metres = rangeMetres?.[r.id];
            return (
              <button key={r.id} type="button" className={cx("o77-mic__range", on && "o77-mic__range--on")}
                style={on ? { background: r.color } : undefined} onClick={() => onRangeChange?.(r.id)}>
                {r.label}{metres != null && <span className="o77-mic__range-m">{metres}M</span>}
              </button>
            );
          })}
          <span className="o77-mic__hint">[{keyHint}]</span>
        </div>
      )}
    </div>
  );
}
