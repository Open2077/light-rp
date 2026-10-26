/* SAO window: a big glass slab with a header (round icon, condensed title,
   mono tag, actions) and a body. Back arrow when the window stack is deep. */
import type { ReactNode } from "react";
import { ArrowLeft, X } from "lucide-react";
import { HoloPanel } from "./HoloPanel";
import { goBack } from "@/store/actions";

export interface WindowProps {
  icon: ReactNode;
  title: ReactNode;
  subtitle?: ReactNode;
  tag?: string;
  actions?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  canBack?: boolean;
  className?: string;
  bodyClass?: string;
}

export function Window({ icon, title, subtitle, tag, actions, children, footer, canBack, className, bodyClass }: WindowProps) {
  return (
    <HoloPanel className={["win", className].filter(Boolean).join(" ")} tag={tag}>
      <header className="win__head">
        {canBack ? (
          <button type="button" className="win__back" aria-label="Back" onClick={goBack}>
            <ArrowLeft size={20} strokeWidth={2.4} />
          </button>
        ) : null}
        <span className="win__icon">{icon}</span>
        <div className="win__titles">
          <div className="win__title label">{title}</div>
          {subtitle && <div className="win__sub">{subtitle}</div>}
        </div>
        <div className="win__actions">
          {actions}
          {!canBack && (
            <button type="button" className="icon-btn win__close" aria-label="Close window" onClick={goBack}>
              <X size={18} strokeWidth={2.4} />
            </button>
          )}
        </div>
      </header>
      <div className="win__rule" aria-hidden />
      <div className={["win__body", bodyClass].filter(Boolean).join(" ")}>{children}</div>
      {footer && <footer className="win__foot">{footer}</footer>}
    </HoloPanel>
  );
}
