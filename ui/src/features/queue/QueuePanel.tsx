import { useEffect, useState } from "react";
import { sendAction } from "@/bridge/open77";
import { useStore } from "@/state/store";
import { Keycap } from "@/design/components";
import { clockDown, clockUp, countLabel, keyCap, startsInMs, statusOf, waitedMs } from "./model";
import "./queue-panel.css";

/* The queue panel: shown by default whenever the player waits in a queue: an activity's
   (the core's ranked search, a provider's lobby) or a mission board's
   (server/modules/activity_queue.lua). One strip at the top centre: the mode, players
   in queue / needed, the start once it is scheduled, the wait, and the cancel key
   (client/core/queue.lua sends it; F1 > Leave queue and a click while the cursor is out
   do the same). The chat (top left), the minimap (top right), the crew frame (bottom
   left) and the notices keep their place; the activity HUD's header moves down under
   it, and its own lobby header for the same queue steps aside (ActivityHud.tsx). */
export function QueuePanel() {
  const q = useStore((s) => s.state.queue);
  const key = useStore((s) => s.state.queueKey);
  const quiet = useStore((s) => !!s.dialog);
  const away = useStore((s) => s.state.character.status !== "active" || !!s.state.character.welcomePending);
  // the running mission's chip and a fixer gig's keep the very top
  const under = useStore((s) => !!s.state.fixerGig || (!!s.state.missionQueue && s.state.missionQueue.running));
  const [received, setReceived] = useState(() => performance.now());
  const [, tick] = useState(0);
  useEffect(() => { setReceived(performance.now()); }, [q]);
  useEffect(() => {
    if (!q) return;
    const t = window.setInterval(() => tick((n) => n + 1), 250);
    return () => window.clearInterval(t);
  }, [q]);
  if (!q || away) return null;
  const elapsed = performance.now() - received;
  const status = statusOf(q);
  const count = countLabel(q);
  const left = startsInMs(q, elapsed);
  const cap = keyCap(key);
  return <section className={`qp is-${q.state}${quiet ? " is-quiet" : ""}${under ? " is-under" : ""}`} role="status"
    aria-label={`Queue: ${q.label}`} data-queue={q.id}>
    <span className={`qp-tag is-${status.tone}`}>{status.tag}</span>
    <div className="qp-id">
      <b>{q.label}</b>
      {q.mode && <small>{q.mode}</small>}
    </div>
    {count && <div className="qp-cell"><small>PLAYERS</small><b>{count}</b>{status.note && <em>{status.note}</em>}</div>}
    {left !== undefined && <div className="qp-cell is-start"><small>STARTS IN</small><b>{clockDown(left)}</b></div>}
    <div className="qp-cell"><small>WAITED</small><b>{clockUp(waitedMs(q, elapsed))}</b></div>
    <button type="button" className="qp-cancel o77-interactive" onClick={() => sendAction({ type: "queue.leave", from: "panel" })}
      title={cap ? `Leave the queue (${cap}, or F1 > Leave queue)` : "Leave the queue (F1 > Leave queue)"}>
      <Keycap size="sm">{cap ?? "F1"}</Keycap><span>{cap ? "CANCEL" : "LEAVE QUEUE"}</span>
    </button>
  </section>;
}
