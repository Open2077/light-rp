import { Fragment, useEffect, type HTMLAttributes, type ReactNode } from "react";
import { Icon, type IconName } from "./Icon";
import { cx } from "./core";

/* Keyboard-first list menu in the RageUI tradition (design system: Menus /
   RageMenu): a single vertical column, one highlighted row, left/right edits the
   row in place, Enter descends, Backspace ascends. The description panel and
   the N/M counter belong to the menu, not to the rows. Fully controlled: it
   never mutates its own items. */

export type RageItemType = "item" | "checkbox" | "list" | "slider" | "submenu";

export interface RageMenuItem {
  id?: string;
  type?: RageItemType;
  text?: string;
  icon?: IconName;
  /** Right-aligned mono readout (item/submenu rows only). */
  meta?: string;
  /** Sentence shown in the description panel while this row is highlighted. */
  description?: string;
  disabled?: boolean;
  /** Red row: destructive or illegal. */
  danger?: boolean;
  /** Renders a hairline divider instead of a row. */
  separator?: boolean;
  /** Renders a non-pickable section caption instead of a row. */
  label?: string;
  checked?: boolean;
  options?: string[];
  index?: number;
  value?: number;
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  /** submenu: your own payload, read in onSelect. */
  target?: string;
}

export interface RageMenuProps extends Omit<HTMLAttributes<HTMLDivElement>, "title" | "onChange" | "onSelect"> {
  title?: string;
  subtitle?: string;
  /** Left side of the counter bar. Default "MENU". */
  tag?: string;
  items?: RageMenuItem[];
  /** Index of the highlighted row (controlled). */
  index?: number;
  /** Breadcrumb of submenu titles, e.g. ["PLAYER", "IDENTITY"]. */
  path?: string[];
  /** Rows shown before the list scrolls. Default 9. */
  visibleRows?: number;
  description?: string;
  footer?: ReactNode;
  width?: number;
  /** Bind the keyboard only while true. Default true. */
  active?: boolean;
  onIndexChange?: (index: number) => void;
  onChange?: (item: RageMenuItem, index: number, patch: Partial<RageMenuItem>) => void;
  onSelect?: (item: RageMenuItem, index: number) => void;
  onBack?: () => void;
}

export function isPickable(it: RageMenuItem | undefined): boolean {
  return !!it && !it.separator && !it.label && !it.disabled;
}

const SLIDER_CELLS = 12;

function Row({ item, active }: { item: RageMenuItem; active: boolean }) {
  if (item.separator) return <div className="o77-rage__sep" />;
  if (item.label) return <div className="o77-rage__caption">{item.label}</div>;
  const t = item.type ?? "item";
  const pct = t === "slider" ? ((item.value ?? 0) - (item.min ?? 0)) / ((item.max ?? 100) - (item.min ?? 0)) : 0;
  return (
    <div className={cx("o77-rage__row", active && "o77-rage__row--on", item.danger && "o77-rage__row--danger", item.disabled && "o77-rage__row--disabled")}>
      {item.icon && <Icon name={item.icon} size={14} className="o77-rage__icon" />}
      <span className="o77-rage__text">{item.text}</span>

      {t === "checkbox" && (
        <span className={cx("o77-rage__check", item.checked && "o77-rage__check--on")}>
          {item.checked && <Icon name="check" size={11} />}
        </span>
      )}

      {t === "list" && (
        <span className="o77-rage__list">
          <Icon name="chevron-left" size={12} />
          <span className="o77-rage__list-value">{item.options?.[item.index ?? 0] ?? "--"}</span>
          <Icon name="chevron-right" size={12} />
        </span>
      )}

      {t === "slider" && (
        <span className="o77-rage__slider">
          <span className="o77-rage__cells">
            {Array.from({ length: SLIDER_CELLS }).map((_, i) => (
              <span key={i} className={cx("o77-rage__cell", (i + 1) / SLIDER_CELLS <= pct + 0.0001 && "o77-rage__cell--on")} />
            ))}
          </span>
          <span className="o77-rage__slider-value">{item.value}{item.unit ?? ""}</span>
        </span>
      )}

      {t === "submenu" && <Icon name="chevron-right" size={13} />}

      {item.meta && t !== "list" && t !== "slider" && <span className="o77-rage__meta">{item.meta}</span>}
    </div>
  );
}

export function RageMenu({
  title = "OPEN//77", subtitle, tag, items = [], index = 0, path = [], visibleRows = 9,
  description, footer, width = 320, active = true, onIndexChange, onChange, onSelect, onBack, className, style, ...rest
}: RageMenuProps) {
  const pick = (from: number, dir: 1 | -1) => {
    if (!items.length) return from;
    let i = from;
    for (let n = 0; n < items.length; n++) {
      i = (i + dir + items.length) % items.length;
      if (isPickable(items[i])) return i;
    }
    return from;
  };

  useEffect(() => {
    if (!active) return;
    const onKey = (e: KeyboardEvent) => {
      const cur = items[index];
      const k = e.key;
      if (!["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Enter", "Backspace", "Escape"].includes(k)) return;
      e.preventDefault();
      if (e.repeat && (k === "Enter" || k === "Backspace" || k === "Escape")) return;
      if (k === "ArrowUp") return onIndexChange?.(pick(index, -1));
      if (k === "ArrowDown") return onIndexChange?.(pick(index, 1));
      if (k === "Backspace" || k === "Escape") return onBack?.();
      if (!cur || cur.disabled) return;
      if (k === "Enter") return onSelect?.(cur, index);
      const dir = k === "ArrowLeft" ? -1 : 1;
      if (cur.type === "list" && onChange) {
        const len = cur.options?.length || 1;
        return onChange(cur, index, { index: (((cur.index ?? 0) + dir) % len + len) % len });
      }
      if (cur.type === "slider" && onChange) {
        const step = cur.step ?? 5, min = cur.min ?? 0, max = cur.max ?? 100;
        return onChange(cur, index, { value: Math.max(min, Math.min(max, (cur.value ?? 0) + dir * step)) });
      }
      if (cur.type === "checkbox" && onChange) return onChange(cur, index, { checked: !cur.checked });
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, items, index, onIndexChange, onChange, onSelect, onBack]);

  const pickables = items.filter(isPickable);
  const current = items[index];
  const pickableIndex = current ? pickables.indexOf(current) : -1;
  const start = Math.max(0, Math.min(items.length - visibleRows, index - Math.floor(visibleRows / 2)));
  const window_ = items.length > visibleRows ? items.slice(start, start + visibleRows) : items;
  const text = current?.description ?? description;

  return (
    <div {...rest} className={cx("o77-rage", className)} style={{ width, ...style }}>
      <div className="o77-rage__banner">
        <div className="o77-rage__title">{title}</div>
        {subtitle && <div className="o77-rage__subtitle">{subtitle}</div>}
      </div>
      {path.length > 0 && (
        <div className="o77-rage__path">
          {path.map((p, i) => (
            <Fragment key={i}>
              {i > 0 && <Icon name="chevron-right" size={10} />}
              <span className={cx(i === path.length - 1 && "o77-rage__path--on")}>{p}</span>
            </Fragment>
          ))}
        </div>
      )}
      <div className="o77-rage__rows" style={{ maxHeight: visibleRows * 32 + 14 }}>
        {window_.map((it, i) => <Row key={`${it.id ?? i}-${start + i}`} item={it} active={items[index] === it} />)}
      </div>
      <div className="o77-rage__counter">
        <span>{tag ?? "MENU"}</span>
        <span className="o77-rage__counter-n">{pickableIndex + 1} / {pickables.length}</span>
      </div>
      {text && <div className="o77-rage__desc">{text}</div>}
      <div className="o77-rage__legend">
        {footer ?? <><span>[↑↓] MOVE</span><span>[←→] EDIT</span><span>[ENTER] SELECT</span><span>[BKSP] BACK</span></>}
      </div>
    </div>
  );
}
