import { useState, type ButtonHTMLAttributes, type HTMLAttributes, type InputHTMLAttributes, type ReactNode } from "react";
import { Icon, type IconName } from "./Icon";
import { Button, cx, type ButtonVariant } from "./core";

/* ---------- Input ---------- */
export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: ReactNode;
  hint?: ReactNode;
  icon?: IconName;
  invalid?: boolean;
  wrapperClassName?: string;
}
export function Input({ label, hint, icon, invalid, wrapperClassName, onFocus, onBlur, ...rest }: InputProps) {
  const [focus, setFocus] = useState(false);
  return (
    <label className={cx("o77-input", focus && "o77-input--focus", invalid && "o77-input--invalid", wrapperClassName)}>
      {label && <span className="o77-input__label">{label}</span>}
      <span className="o77-input__field">
        {icon && <span className="o77-input__icon"><Icon name={icon} size={14} /></span>}
        <input className="o77-input__control" {...rest}
          onFocus={(e) => { setFocus(true); onFocus?.(e); }}
          onBlur={(e) => { setFocus(false); onBlur?.(e); }} />
      </span>
      {hint && <span className="o77-input__hint">{hint}</span>}
    </label>
  );
}

/* ---------- Toggle ---------- */
export interface ToggleProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, "onChange"> {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  label?: ReactNode;
  description?: ReactNode;
}
export function Toggle({ checked = false, onChange, label, description, className, disabled, ...rest }: ToggleProps) {
  return (
    <button type="button" role="switch" aria-checked={checked} disabled={disabled}
      className={cx("o77-toggle", checked && "o77-toggle--on", className)} onClick={() => onChange?.(!checked)} {...rest}>
      <span className="o77-toggle__track"><span className="o77-toggle__knob" /></span>
      <span className="o77-toggle__text">
        {label && <span className="o77-toggle__label">{label}</span>}
        {description && <span className="o77-toggle__desc">{description}</span>}
      </span>
      <span className="o77-toggle__state">{checked ? "ON" : "OFF"}</span>
    </button>
  );
}

/* ---------- Tabs ---------- */
export interface TabItem<T extends string = string> { value: T; label: ReactNode; icon?: IconName; count?: number | string }
export interface TabsProps<T extends string> extends Omit<HTMLAttributes<HTMLDivElement>, "onChange"> {
  items: TabItem<T>[];
  value: T;
  onChange?: (value: T) => void;
  orientation?: "horizontal" | "vertical";
}
export function Tabs<T extends string>({ items, value, onChange, orientation = "horizontal", className, ...rest }: TabsProps<T>) {
  return (
    <div role="tablist" className={cx("o77-tabs", orientation === "vertical" && "o77-tabs--vertical", className)} {...rest}>
      {items.map((it) => (
        <button key={it.value} type="button" role="tab" aria-selected={it.value === value}
          className={cx("o77-tab", it.value === value && "o77-tab--on")} onClick={() => onChange?.(it.value)}>
          {it.icon && <Icon name={it.icon} size={15} />}
          {it.label}
          {it.count != null && <span className="o77-tab__count">{it.count}</span>}
        </button>
      ))}
    </div>
  );
}

/* ---------- ListRow ---------- */
export interface ListRowProps extends Omit<HTMLAttributes<HTMLDivElement>, "title"> {
  icon?: IconName;
  title: ReactNode;
  subtitle?: ReactNode;
  meta?: ReactNode;
  right?: ReactNode;
  selected?: boolean;
}
export function ListRow({ icon, title, subtitle, meta, right, selected, onClick, className, ...rest }: ListRowProps) {
  return (
    <div className={cx("o77-row", onClick && "o77-row--click", selected && "o77-row--selected", className)} onClick={onClick} {...rest}>
      {icon && <span className="o77-row__icon"><Icon name={icon} size={16} /></span>}
      <div className="o77-row__text">
        <span className="o77-row__title">{title}</span>
        {subtitle && <span className="o77-row__subtitle">{subtitle}</span>}
      </div>
      {meta && <span className="o77-row__meta">{meta}</span>}
      {right && <span className="o77-row__right">{right}</span>}
    </div>
  );
}

/* ---------- Modal ---------- */
export type ModalKind = "info" | "success" | "warning" | "error" | "danger" | "confirm" | "prompt" | "progress";
const MODAL_META: Record<ModalKind, { icon: IconName; tag: string }> = {
  info: { icon: "terminal", tag: "SYS" }, success: { icon: "check-check", tag: "OK" }, warning: { icon: "triangle-alert", tag: "WARN" },
  error: { icon: "octagon-alert", tag: "FAIL" }, danger: { icon: "triangle-alert", tag: "CONFIRM" }, confirm: { icon: "circle-help", tag: "CONFIRM" },
  prompt: { icon: "keyboard", tag: "INPUT" }, progress: { icon: "loader", tag: "BUSY" },
};
const MODAL_WIDTH = { sm: 360, md: 440, lg: 560, xl: 720 } as const;
export interface ModalAction { label: ReactNode; variant?: ButtonVariant; icon?: IconName; onClick?: () => void; disabled?: boolean }
export interface ModalProps {
  open?: boolean;
  kind?: ModalKind;
  title?: ReactNode;
  tag?: ReactNode;
  subtitle?: ReactNode;
  children?: ReactNode;
  actions?: ModalAction[];
  footerNote?: ReactNode;
  size?: keyof typeof MODAL_WIDTH;
  width?: number;
  scrim?: "blur" | "none";
  dismissible?: boolean;
  onClose?: () => void;
}
export function Modal({ open = true, kind = "info", title = "CONFIRM", tag, subtitle, children, actions = [], footerNote, size = "md", width, scrim = "blur", dismissible, onClose }: ModalProps) {
  if (!open) return null;
  const meta = MODAL_META[kind];
  return (
    <div className={cx("o77-modal-scrim o77-interactive", scrim === "none" && "o77-modal-scrim--none")}>
      <div role="dialog" aria-modal="true" className={cx("o77-modal", `o77-modal--${kind}`)} style={{ width: width ?? MODAL_WIDTH[size] }}>
        <header className="o77-modal__head">
          <Icon name={meta.icon} size={15} />
          <span className="o77-modal__title">{title}</span>
          <span className="o77-modal__tag">{tag ?? meta.tag}</span>
          {dismissible && onClose && <button type="button" className="o77-modal__close" aria-label="Close" onClick={onClose}><Icon name="x" size={14} /></button>}
        </header>
        <div className="o77-modal__body">
          {subtitle && <span className="o77-modal__subtitle">{subtitle}</span>}
          {children}
        </div>
        {(actions.length > 0 || footerNote) && (
          <footer className="o77-modal__foot">
            {footerNote && <span className="o77-modal__note">{footerNote}</span>}
            <span className="o77-modal__actions">
              {actions.map((a, i) => (
                <Button key={i} size="sm" variant={a.variant ?? "secondary"} icon={a.icon} onClick={a.onClick} disabled={a.disabled}>{a.label}</Button>
              ))}
            </span>
          </footer>
        )}
      </div>
    </div>
  );
}
