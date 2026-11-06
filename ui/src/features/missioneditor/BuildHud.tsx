import type { IconName } from "@/design/components";
import { BuildStrip } from "./BuildStrip";
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
  const facing = build.heading == null ? "AUTO · faces you" : `${build.heading}°`;
  return <BuildStrip title={mission.title} tools={toolsFor(mission).map(t => ({ id: t, label: TOOL_LABEL[t], icon: TOOL_ICON[t], color: TOOL_COLOR[t] }))}
    tool={build.tool} help={toolHelp(build.tool, mission, build)} carrying={build.carrying ? build.carrying.label ?? "" : undefined} hovered={hovered?.label ?? hovered?.type}
    pickUp={build.tool === "move" && !build.carrying} message={message} error={error}>
    {build.tool === "spawn" && <p className="mission-build__brush"><span>BRUSH</span>{brush.count}× {enemyLabel(brush.enemy)} · {BEHAVIOR_LABEL[brush.behavior]} · {TRIGGER_LABEL[brush.trigger]} · spread {brush.spread} m</p>}
    {build.tool === "checkpoint" && <p className="mission-build__brush"><span>BRUSH</span>radius {brush.checkpointRadius} m · required</p>}
    {(build.tool === "spawn" || build.tool === "start" || build.tool === "move") && <p className="mission-build__brush"><span>FACING</span>{facing}</p>}
  </BuildStrip>;
}
