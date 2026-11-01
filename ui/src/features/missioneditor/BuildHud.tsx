import { Icon, type IconName } from "@/design/components";
import { toolHelp, toolsFor, type BuildState } from "./build";
import { BEHAVIOR_LABEL, enemyLabel, TOOL_LABEL, TRIGGER_LABEL, type Brush, type Mission, type Ref, type Tool } from "./model";

const TOOL_ICON: Record<Tool, IconName> = { spawn: "swords", checkpoint: "map-pin", start: "users", perimeter: "shield", radius: "activity",
  patrol: "route", move: "hand", board: "terminal" };
const TOOL_COLOR: Record<Tool, string> = { spawn: "#ff4d4d", checkpoint: "#22d8e2", start: "#3ddc84", perimeter: "#ffcc00", radius: "#ffcc00",
  patrol: "#d65bff", move: "#ffffff", board: "#f2f3f5" };

/* Build mode: the world stays playable; this strip says what a click does. */
export function BuildHud({ mission, build, brush, hovered, message, error }: {
  mission: Mission; build: BuildState; brush: Brush; hovered?: Ref | null; message?: string; error?: string;
}) {
  const tools = toolsFor(mission);
  const facing = build.heading == null ? "AUTO · faces you" : `${build.heading}°`;
  return <>
    <div className="mission-build-crosshair" aria-hidden="true" style={{ ["--tool" as string]: TOOL_COLOR[build.tool] }} />
    {hovered && <div className="mission-build-aim" role="status"><b>{hovered.label ?? hovered.type}</b><span>RIGHT-CLICK EDIT · DEL REMOVE{build.tool === "move" && !build.carrying ? " · CLICK PICK UP" : ""}</span></div>}
    <section className="mission-build" aria-label="Build mode">
      <header><span className="mission-build__tag">BUILD MODE</span><b>{mission.title}</b><em>{build.carrying ? `CARRYING ${build.carrying.label ?? ""}` : ""}</em></header>
      <ol className="mission-build__tools">{tools.map(t => <li key={t} className={t === build.tool ? "is-on" : ""} style={{ ["--tool" as string]: TOOL_COLOR[t] }}>
        <Icon name={TOOL_ICON[t]} size={13} /><span>{TOOL_LABEL[t]}</span></li>)}</ol>
      <p className="mission-build__help">{toolHelp(build.tool, mission, build)}</p>
      {build.tool === "spawn" && <p className="mission-build__brush"><span>BRUSH</span>{brush.count}× {enemyLabel(brush.enemy)} · {BEHAVIOR_LABEL[brush.behavior]} · {TRIGGER_LABEL[brush.trigger]} · spread {brush.spread} m</p>}
      {build.tool === "checkpoint" && <p className="mission-build__brush"><span>BRUSH</span>radius {brush.checkpointRadius} m · required</p>}
      {(build.tool === "spawn" || build.tool === "start" || build.tool === "move") && <p className="mission-build__brush"><span>FACING</span>{facing}</p>}
      {(error || message) && <p className={`mission-build__feedback${error ? " is-error" : ""}`} role={error ? "alert" : "status"}>{error || message}</p>}
      <footer><span><kbd>CLICK</kbd> PLACE</span><span><kbd>RMB</kbd> SELECT</span><span><kbd>DEL</kbd> REMOVE</span><span><kbd>↑↓</kbd> TOOL</span>
        <span><kbd>←→</kbd> FACING</span><span><kbd>F11</kbd> AT MY FEET</span><span><kbd>F9</kbd> MENU</span><span className="mission-build__tip">/noclip TO FLY</span></footer>
    </section>
  </>;
}
