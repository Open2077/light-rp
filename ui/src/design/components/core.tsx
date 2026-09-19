import type { ButtonHTMLAttributes, CSSProperties, HTMLAttributes, ReactNode } from "react";
import { Icon, type IconName } from "./Icon";

function cx(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}

/* ---------- Button ---------- */
export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
export type ButtonSize = "sm" | "md" | "lg";
export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: IconName;
  iconRight?: IconName;
  block?: boolean;
}
const ICON_SIZE: Record<ButtonSize, number> = { sm: 13, md: 15, lg: 17 };

export function Button({ variant = "primary", size = "md", icon, iconRight, block, className, children, type = "button", ...rest }: ButtonProps) {
  return (
    <button type={type} className={cx("o77-btn", `o77-btn--${variant}`, `o77-btn--${size}`, block && "o77-btn--block", className)} {...rest}>
      {icon && <Icon name={icon} size={ICON_SIZE[size]} />}
      {children}
      {iconRight && <Icon name={iconRight} size={ICON_SIZE[size]} />}
    </button>
  );
}

/* ---------- Panel ---------- */
export interface PanelProps extends Omit<HTMLAttributes<HTMLElement>, "title"> {
  title?: ReactNode;
  meta?: ReactNode;
  tone?: "default" | "accent" | "hud";
  chamfer?: "sm" | "md" | "lg" | "notch";
  scanlines?: boolean;
  padding?: CSSProperties["padding"];
  bodyClassName?: string;
}
export function Panel({ title, meta, tone = "default", chamfer = "md", scanlines, padding, bodyClassName, className, children, ...rest }: PanelProps) {
  return (
    <section className={cx("o77-panel", tone !== "default" && `o77-panel--${tone}`, `o77-panel--${chamfer}`, className)} {...rest}>
      {scanlines && <span className="o77-panel__scanlines" />}
      {(title || meta) && (
        <header className="o77-panel__head">
          <span className="o77-panel__title">{title}</span>
          {meta && <span className="o77-panel__meta">{meta}</span>}
        </header>
      )}
      <div className={cx("o77-panel__body", bodyClassName)} style={padding != null ? { padding } : undefined}>{children}</div>
    </section>
  );
}

/* ---------- Badge ---------- */
export type BadgeTone = "default" | "accent" | "outline" | "danger" | "success" | "steel";
export function Badge({ tone = "default", className, children, ...rest }: HTMLAttributes<HTMLSpanElement> & { tone?: BadgeTone }) {
  return <span className={cx("o77-badge", tone !== "default" && `o77-badge--${tone}`, className)} {...rest}>{children}</span>;
}

/* ---------- SectionHeader ---------- */
export interface SectionHeaderProps extends Omit<HTMLAttributes<HTMLDivElement>, "title"> {
  index?: ReactNode;
  title: ReactNode;
  subtitle?: ReactNode;
  right?: ReactNode;
}
export function SectionHeader({ index, title, subtitle, right, className, ...rest }: SectionHeaderProps) {
  return (
    <div className={cx("o77-section", className)} {...rest}>
      {index && <span className="o77-section__index">{index}</span>}
      <div className="o77-section__text">
        <span className="o77-section__title">{title}</span>
        {subtitle && <span className="o77-section__subtitle">{subtitle}</span>}
      </div>
      <span className="o77-section__rule" />
      {right}
    </div>
  );
}

/* ---------- HazardStripe ---------- */
export function HazardStripe({ height = 8, label, className, ...rest }: HTMLAttributes<HTMLDivElement> & { height?: number; label?: ReactNode }) {
  return (
    <div className={cx("o77-hazard", className)} {...rest}>
      <span className="o77-hazard__band" style={{ height }} />
      {label && <span className="o77-hazard__label">{label}</span>}
      <span className="o77-hazard__band" style={{ height }} />
    </div>
  );
}

/* ---------- Keycap ---------- */
export function Keycap({ tone = "default", size = "md", className, children, ...rest }: HTMLAttributes<HTMLElement> & { tone?: "default" | "accent"; size?: "sm" | "md" }) {
  return <kbd className={cx("o77-keycap", tone === "accent" && "o77-keycap--accent", size === "sm" && "o77-keycap--sm", className)} {...rest}>{children}</kbd>;
}

/* ---------- StatusChip ---------- */
export interface StatusChipProps extends HTMLAttributes<HTMLDivElement> {
  icon?: IconName;
  label?: ReactNode;
  value: ReactNode;
  tone?: "default" | "accent" | "danger";
}
export function StatusChip({ icon, label, value, tone = "default", className, ...rest }: StatusChipProps) {
  return (
    <div className={cx("o77-chip", tone !== "default" && `o77-chip--${tone}`, className)} {...rest}>
      {icon && <Icon name={icon} size={13} />}
      {label && <span className="o77-chip__label">{label}</span>}
      <span className="o77-chip__value">{value}</span>
    </div>
  );
}

export { cx };
