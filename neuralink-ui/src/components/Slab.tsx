/* A SAO sub-menu slab: translucent white bar with a round icon and a condensed
   uppercase label. Active = solid white with the icon in the selection colour. */
import type { CSSProperties, ReactNode } from "react";
import { ChevronRight } from "lucide-react";

export interface SlabProps {
  icon?: ReactNode;
  label: ReactNode;
  hint?: ReactNode;
  badge?: number | null;
  active?: boolean;
  cursor?: boolean;
  danger?: boolean;
  chevron?: boolean;
  index?: number;
  style?: CSSProperties;
  onClick?: () => void;
}

export function Slab({ icon, label, hint, badge, active, cursor, danger, chevron = true, index = 0, style, onClick }: SlabProps) {
  return (
    <button
      type="button"
      className={["slab", active && "is-active", cursor && "is-cursor", danger && "is-danger"].filter(Boolean).join(" ")}
      style={{ ...style, ["--i" as string]: index }}
      onClick={onClick}
    >
      {icon && <span className="slab__icon">{icon}</span>}
      <span className="slab__text">
        <span className="slab__label label">{label}</span>
        {hint && <span className="slab__hint">{hint}</span>}
      </span>
      {badge ? <span className="slab__badge mono">{badge > 99 ? "99+" : badge}</span> : null}
      {chevron && <ChevronRight className="slab__chev" size={18} strokeWidth={2.4} />}
    </button>
  );
}
