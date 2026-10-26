/* Small SAO-flavoured controls shared by every app. */
import { forwardRef, useId, type ButtonHTMLAttributes, type CSSProperties, type InputHTMLAttributes, type ReactNode, type TextareaHTMLAttributes } from "react";
import { Crown, Users } from "lucide-react";
import { hueOf, initials } from "@/lib/format";
import { play } from "@/fx/sound";

/* ---------------------------------------------------------------- avatar */

export interface AvatarProps {
  name: string;
  seed?: string;
  size?: number;
  online?: boolean | null;
  group?: boolean;
  owner?: boolean;
  level?: number;
  ring?: "none" | "sel" | "ok" | "danger" | "ringing";
  className?: string;
}

export function Avatar({ name, seed, size = 44, online, group, owner, level, ring = "none", className }: AvatarProps) {
  const hue = hueOf(seed ?? name);
  const style = { "--size": `${size}px`, "--hue": hue, "--level": level ?? 0 } as CSSProperties;
  return (
    <span className={["avatar", `avatar--${ring}`, level ? "is-talking" : "", className].filter(Boolean).join(" ")} style={style}>
      <span className="avatar__voice" aria-hidden />
      <span className="avatar__disc">
        {group ? <Users size={Math.round(size * 0.46)} strokeWidth={2.1} /> : <span className="avatar__ini">{initials(name)}</span>}
      </span>
      {online != null && <span className={`avatar__dot ${online ? "is-on" : ""}`} aria-label={online ? "online" : "offline"} />}
      {owner && <span className="avatar__crown" aria-label="owner"><Crown size={12} strokeWidth={2.6} /></span>}
    </span>
  );
}

/* --------------------------------------------------------------- buttons */

type BtnProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  tone?: "sel" | "ghost" | "ok" | "danger" | "plain";
  icon?: ReactNode;
  small?: boolean;
  block?: boolean;
};

export function Btn({ tone = "plain", icon, small, block, className, children, onPointerEnter, ...rest }: BtnProps) {
  return (
    <button
      type="button"
      className={["btn", `btn--${tone}`, small && "btn--sm", block && "btn--block", className].filter(Boolean).join(" ")}
      onPointerEnter={onPointerEnter}
      {...rest}
    >
      {icon}
      {children != null && <span>{children}</span>}
    </button>
  );
}

export function IconBtn({ label, tone, className, children, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { label: string; tone?: "ok" | "danger" | "sel" }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={["icon-btn", tone && `icon-btn--${tone}`, className].filter(Boolean).join(" ")}
      {...rest}
    >
      {children}
    </button>
  );
}

/* ---------------------------------------------------------------- fields */

type InputProps = InputHTMLAttributes<HTMLInputElement> & { label?: string; icon?: ReactNode; error?: string | null; counter?: boolean };

export const Field = forwardRef<HTMLInputElement, InputProps>(function Field({ label, icon, error, counter, className, ...rest }, ref) {
  const id = useId();
  const len = typeof rest.value === "string" ? rest.value.length : 0;
  return (
    <label className={["field", error && "has-error", className].filter(Boolean).join(" ")} htmlFor={id}>
      {label && <span className="field__label label">{label}</span>}
      <span className="field__box">
        {icon && <span className="field__icon">{icon}</span>}
        <input id={id} ref={ref} autoComplete="off" spellCheck={false} {...rest} />
        {counter && rest.maxLength ? <span className="field__count mono">{len}/{rest.maxLength}</span> : null}
      </span>
      {error && <span className="field__error">{error}</span>}
    </label>
  );
});

export const Area = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(function Area({ className, ...rest }, ref) {
  return <textarea ref={ref} className={["area", className].filter(Boolean).join(" ")} spellCheck={false} {...rest} />;
});

/* ---------------------------------------------------------- toggle, slider */

export function Toggle({ checked, onChange, label, hint }: { checked: boolean; onChange: (v: boolean) => void; label: string; hint?: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      className={`toggle ${checked ? "is-on" : ""}`}
      onClick={() => { play("select"); onChange(!checked); }}
    >
      <span className="toggle__text">
        <span className="label">{label}</span>
        {hint && <span className="toggle__hint">{hint}</span>}
      </span>
      <span className="toggle__track"><span className="toggle__knob" /></span>
    </button>
  );
}

export function Slider({ value, min = 0, max = 1, step = 0.01, onInput, onCommit, label, display }: {
  value: number; min?: number; max?: number; step?: number; onInput: (v: number) => void; onCommit?: (v: number) => void; label: string; display?: string;
}) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <label className="slider">
      <span className="slider__head">
        <span className="label">{label}</span>
        <span className="slider__val mono">{display ?? `${Math.round(pct)}%`}</span>
      </span>
      <span className="slider__wrap" style={{ "--pct": `${pct}%` } as CSSProperties}>
        <span className="slider__track"><span className="slider__fill" /></span>
        <span className="slider__ticks" aria-hidden>{Array.from({ length: 11 }, (_, i) => <i key={i} />)}</span>
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onInput(Number(e.target.value))}
          onPointerUp={(e) => onCommit?.(Number((e.target as HTMLInputElement).value))}
          onKeyUp={(e) => onCommit?.(Number((e.target as HTMLInputElement).value))}
        />
      </span>
    </label>
  );
}

/* --------------------------------------------------------------- tabs */

export function Segmented<T extends string>({ value, options, onChange }: { value: T; options: { id: T; label: string; icon?: ReactNode; badge?: number }[]; onChange: (v: T) => void }) {
  const idx = Math.max(0, options.findIndex((o) => o.id === value));
  return (
    <div className="seg" style={{ "--n": options.length, "--idx": idx } as CSSProperties}>
      <span className="seg__thumb" aria-hidden />
      {options.map((o) => (
        <button
          key={o.id}
          type="button"
          className={`seg__opt ${o.id === value ? "is-on" : ""}`}
          onClick={() => { if (o.id !== value) { play("select"); onChange(o.id); } }}
        >
          {o.icon}
          <span className="label">{o.label}</span>
          {o.badge ? <span className="seg__badge mono">{o.badge}</span> : null}
        </button>
      ))}
    </div>
  );
}

/* ------------------------------------------------------- empty, loading */

export function Empty({ icon, title, body, action }: { icon: ReactNode; title: string; body?: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <span className="empty__icon">{icon}<span className="empty__orbit" aria-hidden /></span>
      <div className="empty__title label">{title}</div>
      {body && <div className="empty__body">{body}</div>}
      {action}
    </div>
  );
}

export function Loader({ text = "Syncing" }: { text?: string }) {
  return (
    <div className="loader">
      <span className="loader__hex" aria-hidden><i /><i /><i /></span>
      <span className="label">{text}</span>
    </div>
  );
}

export function SectionTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="sect">
      <span className="sect__mark" aria-hidden />
      <span className="sect__text label">{children}</span>
      <span className="sect__line" aria-hidden />
      {aside}
    </div>
  );
}
