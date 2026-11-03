import { useEffect, useRef, useState } from "react";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type ActivitiesTab } from "@/bridge/protocol";
import { useStore } from "@/state/store";

/* What a guide button or a dialogue choice does, for the FAQ panel and the
   dialogue alike. A GPS route and the Hall of Fame wait for the server's answer
   (shown as `feedback`); the panels close the guide and open themselves. */

export interface GuideActionLike { type: string; target?: string; tab?: ActivitiesTab }

export function useGuideActions(onClose: () => void) {
  const job = useStore((s) => s.state.job);
  const openJobGuide = useStore((s) => s.openJobGuide);
  const setWelcomeReplay = useStore((s) => s.setWelcomeReplay);
  const result = useStore((s) => s.lastResult);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean }>();
  const sent = useRef(0);
  useEffect(() => {
    if (!result || (result.action !== "guide.gps" && result.action !== "guide.panel") || result.at < sent.current) return;
    setFeedback({ text: result.text, error: !result.ok });
  }, [result]);

  const hasJobGuide = Array.isArray(job.guide) && job.guide.length > 0;
  /** False for an action the player cannot use right now (a job guide without a job). */
  const available = (type: string) => (type === "jobguide" ? hasJobGuide : true);

  /** Returns false when the action is not one of the guide's. */
  const run = (a: GuideActionLike): boolean => {
    switch (a.type) {
      case "gps":
        if (!a.target) return false;
        sent.current = Date.now();
        setFeedback({ text: "Asking for a route…", error: false });
        sendAction({ type: "guide.gps", target: a.target });
        return true;
      case "halloffame":
        sent.current = Date.now();
        setFeedback({ text: "Pulling up the board…", error: false });
        sendAction({ type: "guide.panel", panel: "halloffame" });
        return true;
      case "activities": onClose(); sendAction({ type: "activities.control", operation: "open", tab: a.tab ?? "activities" }); return true;
      case "jobguide": onClose(); openJobGuide(job.name); return true;
      case "housing": onClose(); emit(PAGE_EVENTS.action, { type: "housing.open" }); return true;
      case "support": onClose(); emit(PAGE_EVENTS.support, { operation: "open", scope: "player" }); return true;
      case "animations": onClose(); emit(PAGE_EVENTS.animationsAction, { action: "open" }); return true;
      case "tutorial": onClose(); emit(PAGE_EVENTS.tutorial, { operation: "options" }); return true;
      case "briefing": onClose(); setWelcomeReplay(true); return true;
    }
    return false;
  };

  return { run, available, feedback, setFeedback };
}
export type GuideActions = ReturnType<typeof useGuideActions>;
