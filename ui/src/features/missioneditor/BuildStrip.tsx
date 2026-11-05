import type { ReactNode } from "react";
import { Icon, type IconName } from "@/design/components";

export interface StripTool { id: string; label: string; icon: IconName; color: string }

/* Build mode's strip, for any editor: the world stays playable; this says what a click does. */
export function BuildStrip({ title, tools, tool, help, carrying, hovered, pickUp, message, error, children }: {
  title: string; tools: StripTool[]; tool: string; help: string; carrying?: string; hovered?: string; pickUp?: boolean; message?: string; error?: string; children?: ReactNode;
}) {
  const color = tools.find(t => t.id === tool)?.color;
  return <>
    <div className="mission-build-crosshair" aria-hidden="true" style={{ ["--tool" as string]: color }} />
    {hovered && <div className="mission-build-aim" role="status"><b>{hovered}</b><span>RIGHT-CLICK EDIT · DEL REMOVE{pickUp ? " · CLICK PICK UP" : ""}</span></div>}
    <section className="mission-build" aria-label="Build mode">
      <header><span className="mission-build__tag">BUILD MODE</span><b>{title}</b><em>{carrying != null ? `CARRYING ${carrying}` : ""}</em></header>
      <ol className="mission-build__tools">{tools.map(t => <li key={t.id} className={t.id === tool ? "is-on" : ""} style={{ ["--tool" as string]: t.color }}>
        <Icon name={t.icon} size={13} /><span>{t.label}</span></li>)}</ol>
      <p className="mission-build__help">{help}</p>
      {children}
      {(error || message) && <p className={`mission-build__feedback${error ? " is-error" : ""}`} role={error ? "alert" : "status"}>{error || message}</p>}
      <footer><span><kbd>CLICK</kbd> PLACE</span><span><kbd>RMB</kbd> SELECT</span><span><kbd>DEL</kbd> REMOVE</span><span><kbd>↑↓</kbd> TOOL</span>
        <span><kbd>←→</kbd> FACING</span><span><kbd>F11</kbd> AT MY FEET</span><span><kbd>F9</kbd> MENU</span><span className="mission-build__tip">/noclip TO FLY</span></footer>
    </section>
  </>;
}
