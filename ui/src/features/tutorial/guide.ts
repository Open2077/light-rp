import { useEffect } from "react";
import { on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";

/** The way to the objective (client/core/tutorial_guide.lua): sent when it changes, at least
    once a second while it shows. `angle`: degrees from the camera's heading, positive to the
    left; `rise`: metres up (or down, negative) when the climb is worth saying. */
export interface GuideMessage { label?: string; distance?: number; angle?: number; rise?: number; hide?: boolean }
export interface GuideWay { label: string; distance: number; angle: number; rise: number }

/** The page anchor the client keeps over the objective; the plugin projects it every frame. */
export const GUIDE_ANCHOR = "tutorial.guide";
/** Nothing heard for this long: the client stopped guiding, the pointer goes. */
export const GUIDE_STALE_MS = 3500;
/** Closer than this the objective's own prompt (E) takes over. */
export const GUIDE_CLOSE_M = 4;

let latest: { way: GuideWay | null; at: number } = { way: null, at: 0 };
const listeners = new Set<() => void>();

export function readWay(message: GuideMessage | null | undefined): GuideWay | null {
  if (!message || message.hide || typeof message.distance !== "number" || !Number.isFinite(message.distance)) return null;
  const angle = typeof message.angle === "number" && Number.isFinite(message.angle) ? message.angle : 0;
  const rise = typeof message.rise === "number" && Number.isFinite(message.rise) ? message.rise : 0;
  return { label: typeof message.label === "string" ? message.label : "", distance: Math.max(0, message.distance), angle, rise };
}

/** The current way, or null when there is none or it went stale. */
export function currentWay(now = performance.now()): GuideWay | null {
  return latest.way && now - latest.at <= GUIDE_STALE_MS ? latest.way : null;
}

export function subscribeWay(fn: () => void): () => void {
  listeners.add(fn);
  return () => { listeners.delete(fn); };
}

export function feedWay(message: GuideMessage | null | undefined) {
  latest = { way: readWay(message), at: performance.now() };
  for (const fn of listeners) fn();
}

/** Mounted once by the always-present Tutorial: the pointer and the card can come and go without missing a message. */
export function useGuideFeed() {
  useEffect(() => on<GuideMessage>(PAGE_EVENTS.tutorialGuide, feedWay), []);
}

export function formatDistance(metres: number): string {
  return metres >= 1000 ? `${(metres / 1000).toFixed(1)} km` : `${Math.round(metres)} m`;
}

/** Where the edge arrow sits for a bearing: on an ellipse round the screen centre, clear of
    the objective card on the right. `angle` positive to the left; returns viewport fractions. */
export function edgePoint(angle: number, rx = 0.25, ry = 0.31): { x: number; y: number; turn: number } {
  const turn = -angle; // clockwise from straight up
  const r = (turn * Math.PI) / 180;
  return { x: 0.5 + Math.sin(r) * rx, y: 0.5 - Math.cos(r) * ry, turn };
}
