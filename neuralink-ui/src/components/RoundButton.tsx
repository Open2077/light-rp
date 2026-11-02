/* The SAO round button: white glass disc, gold fill + rotating dotted ring when
   selected, numeric badge, hover label. */
import type { CSSProperties, ReactNode } from "react";

export interface RoundButtonProps {
  icon: ReactNode;
  label?: string;
  selected?: boolean;
  cursor?: boolean;
  badge?: number | string | null;
  tone?: "glass" | "ok" | "danger" | "sel";
  size?: number;
  pulse?: boolean;
  disabled?: boolean;
  labelSide?: "left" | "right" | "none";
  className?: string;
  style?: CSSProperties;
  color?: string;
  onClick?: () => void;
  dataCol?: string;
}

export function RoundButton({
  icon, label, selected, cursor, badge, tone = "glass", size, pulse, disabled, labelSide = "left", className, style, color, onClick, dataCol,
}: RoundButtonProps) {
  const s: CSSProperties = { ...style };
  if (size) (s as Record<string, string>)["--size"] = `${size}px`;
  if (color) (s as Record<string, string>)["--app-color"] = color;
  return (
    <button
      type="button"
      className={[
        "rb", `rb--${tone}`, selected && "is-selected", cursor && "is-cursor", pulse && "is-pulse", color && "has-color", className,
      ].filter(Boolean).join(" ")}
      style={s}
      disabled={disabled}
      aria-label={label}
      aria-pressed={selected}
      data-col={dataCol}
      onClick={onClick}
    >
      <span className="rb__ring" aria-hidden>
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="47" />
        </svg>
      </span>
      <span className="rb__rim" aria-hidden><i /><i /><i /><i /></span>
      <span className="rb__disc">
        <span className="rb__icon">{icon}</span>
      </span>
      {badge != null && badge !== 0 && badge !== "" && <span className="rb__badge mono">{typeof badge === "number" && badge > 99 ? "99+" : badge}</span>}
      {label && labelSide !== "none" && <span className={`rb__label rb__label--${labelSide} label`}>{label}</span>}
    </button>
  );
}
