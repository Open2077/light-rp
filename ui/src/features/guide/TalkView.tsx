import { useEffect, useRef, useState } from "react";
import { sendAction } from "@/bridge/open77";
import type { GuideDialogPayload } from "@/bridge/protocol";
import { Icon, Keycap, cx } from "@/design/components";
import { toBlocks } from "./model";
import { Rich } from "./rich";
import { choiceKey, missingTargets, stepStart, talkRows, useTalkFeed, type TalkChoice, type TalkOpening, type TalkRow } from "./talk";
import type { GuideActions } from "./useGuideActions";
import "./talk.css";

/* Talking to Johnny, the way the game's own conversations look: his line as a
   subtitle at the bottom, the player's choices in a short list beside him, the
   world (and Johnny) left in view. A choice leads to his next line, marks a place
   on the map, opens a panel or the written FAQ. Keyboard: ↑↓ choose, Enter / F
   pick, 1-9 pick directly, ← → turn his pages, Backspace or right-click back,
   Esc leave. The next lines are asked for one step ahead (talk.ts). */

export interface FaqStart { question?: string; search?: boolean }

interface Step { id: string; cursor: number }

const ACT_ICON: Record<string, string> = {
  gps: "map-pin", activities: "swords", halloffame: "crown", faq: "file-text", search: "search", jobguide: "book-open",
  housing: "house", support: "message-square", animations: "hand", tutorial: "list-checks", briefing: "file-text",
};
const ROW_ICON: Record<string, string> = { more: "chevron-right", back: "undo-2", bye: "log-out" };
const RETRY_MS = 700;
const TRIES = 4;
const FAREWELL_MS = 1800;

function rowIcon(row: TalkRow): string | undefined {
  if (row.kind !== "choice") return ROW_ICON[row.kind];
  return row.choice?.act ? ACT_ICON[row.choice.act.type] ?? "arrow-right" : undefined;
}

export function TalkView({ index, opening, keys, active, actions, onClose, onFaq }: {
  index: GuideDialogPayload; opening: TalkOpening; keys: Record<string, string>; active: boolean;
  actions: GuideActions; onClose(): void; onFaq(start: FaqStart): void;
}) {
  const root = useRef<HTMLDivElement>(null);
  const [stack, setStack] = useState<Step[]>([{ id: opening.root, cursor: 0 }]);
  const [page, setPage] = useState(0);
  const [cursor, setCursor] = useState(0);
  const [seen, setSeen] = useState<ReadonlySet<string>>(() => new Set());
  const [leaving, setLeaving] = useState(false);
  const [failed, setFailed] = useState(false);
  const start = useTalkFeed((s) => s.start);
  const nodes = useTalkFeed((s) => s.nodes);
  const id = stack[stack.length - 1]!.id;
  // the opening is the one this conversation started with (the greeting has variants)
  const nodeOf = (at: string) => (at === opening.root ? opening.node : nodes[at]);
  const node = nodeOf(id);
  const gone = useTalkFeed((s) => !!s.missing[id]);
  const atRoot = stack.length === 1;

  useEffect(() => { start(opening); }, [start, opening]);
  useEffect(() => { if (active) root.current?.focus(); }, [active]);

  // The node on screen, or the nodes its choices lead to, not here yet: ask for the
  // node (the answer brings its children too). A few tries: a click can fall under
  // the server's action throttle.
  const need = !node ? (gone ? undefined : id) : missingTargets(node, nodes).length > 0 ? id : undefined;
  useEffect(() => {
    setFailed(false);
    if (!need || !active) return;
    let tries = 1;
    sendAction({ type: "guide.node", id: need });
    const t = window.setInterval(() => {
      if (tries >= TRIES) { window.clearInterval(t); setFailed(true); return; }
      tries += 1;
      sendAction({ type: "guide.node", id: need });
    }, RETRY_MS);
    return () => window.clearInterval(t);
  }, [need, active]);

  // "That's all.": his last word, then the dialogue closes (any key or click sooner).
  useEffect(() => {
    if (!leaving) return;
    const t = window.setTimeout(onClose, FAREWELL_MS);
    return () => window.clearTimeout(t);
  }, [leaving, onClose]);

  const pages = node?.pages ?? [];
  const pageIndex = node ? Math.min(page, pages.length - 1) : 0;
  const offer = (c: TalkChoice) => !c.act || actions.available(c.act.type);
  const rows = node ? talkRows(node, pageIndex, atRoot, offer) : talkRows(undefined, 0, atRoot);
  useEffect(() => { setCursor((c) => Math.min(c, Math.max(0, rows.length - 1))); }, [rows.length]);

  const lines = leaving ? [opening.farewell ?? "…"]
    : node ? pages[pageIndex] ?? []
    : gone ? ["That's gone. Ask me something else."]
    : failed ? ["Lost my train of thought. Talk to me again."]
    : ["…"];

  const go = (to: string) => {
    setStack((s) => [...s.slice(0, -1), { ...s[s.length - 1]!, cursor }, { id: to, cursor: 0 }]);
    setPage(0); setCursor(0); actions.setFeedback(undefined);
  };
  const back = () => {
    if (stack.length < 2) return;
    const previous = stack[stack.length - 2]!;
    const before = nodeOf(previous.id);
    setStack((s) => s.slice(0, -1));
    // back where the choices were: his last page
    setPage(before ? before.pages.length - 1 : 0); setCursor(previous.cursor); actions.setFeedback(undefined);
  };
  const leave = () => { if (opening.farewell) setLeaving(true); else onClose(); };

  const pick = (row: TalkRow | undefined) => {
    if (!row) return;
    if (row.kind === "more") { setPage(pageIndex + 1); setCursor(0); return; }
    if (row.kind === "back") { back(); return; }
    if (row.kind === "bye") { leave(); return; }
    const c = row.choice;
    if (!c) return;
    setSeen((s) => new Set(s).add(choiceKey(c)));
    if (c.to) { go(c.to); return; }
    const a = c.act!;
    if (a.type === "faq") onFaq({ question: a.id });
    else if (a.type === "search") onFaq({ search: true });
    else actions.run(a);
  };
  const turn = (delta: number) => {
    if (!node) return;
    const next = Math.max(0, Math.min(pages.length - 1, pageIndex + delta));
    if (next !== pageIndex) { setPage(next); setCursor(0); }
  };

  const steps = node ? stepStart(pages, pageIndex) : 1;
  const name = index.npc.name;
  const feedback = actions.feedback;

  return <div className={cx("talk o77-interactive", leaving && "is-leaving")} role="dialog" aria-modal="true" aria-label={`Talking to ${name}`}
    ref={root} tabIndex={-1} hidden={!active}
    onContextMenu={(e) => { e.preventDefault(); if (leaving) onClose(); else back(); }}
    // a click keeps the keyboard on the dialogue, so Enter picks the highlighted row
    onMouseDown={(e) => { e.preventDefault(); if (leaving) onClose(); }}
    onMouseUp={(e) => { if (e.button === 3) { e.preventDefault(); back(); } }}
    onKeyDown={(e) => {
      let handled = true;
      if (leaving) { if (!e.repeat) onClose(); }
      else if (e.key === "Escape") { if (!e.repeat) onClose(); }
      else if (e.key === "ArrowDown") setCursor((c) => (rows.length ? (c + 1) % rows.length : 0));
      else if (e.key === "ArrowUp") setCursor((c) => (rows.length ? (c - 1 + rows.length) % rows.length : 0));
      else if (e.key === "Enter" || e.key === " " || e.key === "f" || e.key === "F") { if (!e.repeat) pick(rows[cursor]); }
      else if (/^[1-9]$/.test(e.key)) { if (!e.repeat) { const i = Number(e.key) - 1; if (rows[i]) { setCursor(i); pick(rows[i]); } } }
      else if (e.key === "ArrowRight") turn(1);
      else if (e.key === "ArrowLeft") { if (pageIndex > 0) turn(-1); else if (!e.repeat) back(); }
      else if (e.key === "Backspace") { if (!e.repeat) back(); }
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    }}>

    <div className="talk__stage">
      {!leaving && <div className="talk__choices" role="listbox" aria-label="What you say">
        {rows.map((row, i) => {
          const icon = rowIcon(row);
          const asked = row.choice ? seen.has(choiceKey(row.choice)) : false;
          return <button key={row.key} role="option" aria-selected={i === cursor}
            className={cx("talk-choice", `is-${row.kind}`, i === cursor && "is-selected", asked && "is-seen")}
            onClick={() => pick(row)} onMouseEnter={() => setCursor(i)}>
            <span className="talk-choice__num">{i < 9 ? i + 1 : ""}</span>
            <span className="talk-choice__label"><Rich text={row.label} keys={keys} /></span>
            {icon && <Icon name={icon} size={14} className="talk-choice__icon" />}
            {i === cursor && <Keycap size="sm" className="talk-choice__key">F</Keycap>}
          </button>;
        })}
      </div>}

      <section className="talk__sub" aria-live="polite">
        <header className="talk__who">
          <strong>{name}</strong>
          {index.npc.title && <span className="talk__tag">{index.npc.title}</span>}
          {node && pages.length > 1 && !leaving && <span className="talk__pips" aria-label={`Page ${pageIndex + 1} of ${pages.length}`}>
            {pages.map((_, i) => <i key={i} className={cx(i === pageIndex && "is-on", i < pageIndex && "is-read")} />)}
          </span>}
        </header>
        <div className="talk__lines" key={`${id}:${pageIndex}:${leaving ? "bye" : ""}`}>
          {toBlocks(lines).map((b, i) => b.kind === "p" ? <p key={i}><Rich text={b.text} keys={keys} /></p>
            : b.kind === "tip" ? <p key={i} className="talk__tip"><Icon name="info" size={13} /><span><Rich text={b.text} keys={keys} /></span></p>
            : b.kind === "steps" ? <ol key={i} start={steps}>{b.items.map((t, j) => <li key={j}><Rich text={t} keys={keys} /></li>)}</ol>
            : <ul key={i}>{b.items.map((t, j) => <li key={j}><Rich text={t} keys={keys} /></li>)}</ul>)}
        </div>
        {feedback && !leaving && <p className={cx("talk__feedback", feedback.error && "is-error")} role="status">
          <Icon name={feedback.error ? "triangle-alert" : "map-pin"} size={13} />{feedback.text}
        </p>}
      </section>

      <footer className={cx("talk__keys", leaving && "is-hidden")} aria-hidden="true">
        <span><Keycap size="sm">↑↓</Keycap>CHOOSE</span>
        <span><Keycap size="sm">F</Keycap>SAY</span>
        {!atRoot && <span><Keycap size="sm">RMB</Keycap>BACK</span>}
        <span><Keycap size="sm">ESC</Keycap>LEAVE</span>
      </footer>
    </div>
  </div>;
}
