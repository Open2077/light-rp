import { Fragment, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { emit, on, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type GuideDialogPayload, type GuideTopicSummary } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Icon, Keycap, cx } from "@/design/components";
import {
  normalizeIndex, parseInline, plainText, searchGuide, toBlocks, topicOf, topicQuestions, useGuideFeed,
  type GuideAction, type GuideInline, type GuideMessage, type GuideQuestion, type GuideSearchRow,
} from "./model";
import "./guide.css";

/* Johnny at The Crossing (server/modules/guide.lua): E "Talk to Johnny" or ALT + click
   opens the `guide` dialog with the topic index. Topics come on demand, the search
   index right after the dialog. Topics → questions → answer, with breadcrumbs, Back,
   a search over every question, follow-ups and buttons that do real things (a GPS
   route, the activities panel, the job guide, F1 sections). Keyboard: ↑↓ choose,
   Enter open, Backspace / ← / right-click back, Esc close; typing searches. */

type View = { kind: "home" } | { kind: "topic"; id: string } | { kind: "question"; topicId: string; id: string };

const ACTION_ICON: Record<string, string> = {
  gps: "map-pin", activities: "swords", jobguide: "book-open", housing: "house", support: "message-square",
  animations: "hand", tutorial: "list-checks", briefing: "file-text",
};
const ACTION_LABEL: Record<string, string> = {
  gps: "Mark it on my map", activities: "Open the activities", jobguide: "Open my job guide", housing: "Open My homes",
  support: "Open Reports & support", animations: "Open the animations", tutorial: "First day guide options", briefing: "Replay the briefing",
};

export function GuideDialog() {
  const dialog = useStore((s) => s.dialog);
  const close = useStore((s) => s.closeDialog);
  const receive = useGuideFeed((s) => s.receive);
  // Always listening: the keys and the search index arrive right behind the dialog.
  useEffect(() => on<GuideMessage>(PAGE_EVENTS.guide, (m) => receive(m)), [receive]);
  const visible = dialog?.kind === "guide";
  useEffect(() => {
    emit(PAGE_EVENTS.dialogState, { kind: "guide", open: visible });
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    const off = on<{ kind?: string }>(PAGE_EVENTS.dialogClose, (p) => { if (!p?.kind || p.kind === "guide") close(); });
    return () => { off(); emit(PAGE_EVENTS.focus, { active: false }); emit(PAGE_EVENTS.dialogState, { kind: "guide", open: false }); };
  }, [visible, close]);
  const index = useMemo(() => (dialog?.kind === "guide" ? normalizeIndex(dialog) : undefined), [dialog]);
  if (!index) return null;
  return <GuideBody key={index.revision} index={index} onClose={close} />;
}

/* Ask the server for a topic the page does not hold yet: three tries, 1.2 s apart
   (a request can fall under the action throttle when the player clicks fast). */
function useTopic(topicId: string | undefined) {
  const cache = useGuideFeed((s) => (topicId ? s.topics[topicId] : undefined));
  const missing = useGuideFeed((s) => (topicId ? !!s.missing[topicId] : false));
  const revision = useGuideFeed((s) => s.revision);
  const questions = topicQuestions(cache);
  const ready = !!questions;
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    setFailed(false);
    if (!topicId || ready || missing) return;
    let tries = 1;
    sendAction({ type: "guide.topic", id: topicId });
    const t = window.setInterval(() => {
      if (tries >= 3) { window.clearInterval(t); setFailed(true); return; }
      tries += 1;
      sendAction({ type: "guide.topic", id: topicId });
    }, 1200);
    return () => window.clearInterval(t);
  }, [topicId, ready, missing, revision]);
  return { meta: cache?.meta, questions, missing, failed };
}

function GuideBody({ index, onClose }: { index: GuideDialogPayload; onClose(): void }) {
  const root = useRef<HTMLDivElement>(null);
  const searchBox = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const ensure = useGuideFeed((s) => s.ensure);
  const liveKeys = useGuideFeed((s) => s.keys);
  const searchRows = useGuideFeed((s) => s.search);
  const cachedTopics = useGuideFeed((s) => s.topics);
  const job = useStore((s) => s.state.job);
  const openJobGuide = useStore((s) => s.openJobGuide);
  const setWelcomeReplay = useStore((s) => s.setWelcomeReplay);
  const result = useStore((s) => s.lastResult);
  const [stack, setStack] = useState<View[]>([{ kind: "home" }]);
  const [query, setQuery] = useState("");
  const [cursor, setCursor] = useState(0);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean }>();
  const sent = useRef(0);
  useEffect(() => { ensure(index.revision); }, [ensure, index.revision]);
  useEffect(() => { root.current?.focus(); }, []);
  useEffect(() => {
    if (!result || result.action !== "guide.gps" || result.at < sent.current) return;
    setFeedback({ text: result.text, error: !result.ok });
  }, [result]);

  const keys = useMemo(() => ({ ...(index.keys ?? {}), ...liveKeys }), [index.keys, liveKeys]);
  const titles = useMemo(() => Object.fromEntries(index.topics.map((t) => [t.id, t.title])), [index.topics]);
  const topicById = useMemo(() => Object.fromEntries(index.topics.map((t) => [t.id, t])), [index.topics]);
  const view = stack[stack.length - 1]!;
  const topicId = view.kind === "topic" ? view.id : view.kind === "question" ? view.topicId : undefined;
  const topic = useTopic(topicId);

  // Search: the server's index; until it lands, whatever topics are already here.
  const rows = useMemo<GuideSearchRow[]>(() => {
    const fromIndex = Object.values(searchRows);
    if (fromIndex.length > 0) return fromIndex;
    const out: GuideSearchRow[] = [];
    for (const [id, cache] of Object.entries(cachedTopics)) for (const q of topicQuestions(cache) ?? []) out.push([q.id, id, q.q, ""]);
    return out;
  }, [searchRows, cachedTopics]);
  const searching = query.trim().length > 0;
  const hits = useMemo(() => (searching ? searchGuide(query, rows, titles) : []), [searching, query, rows, titles]);
  const topicOfQuestion = (id: string) => searchRows[id]?.[1] ?? topicOf(id);
  const questionText = (id: string) => searchRows[id]?.[2]
    ?? topicQuestions(cachedTopics[topicOfQuestion(id)])?.find((q) => q.id === id)?.q ?? id;

  const go = (next: View) => { setStack((s) => [...s, next]); setQuery(""); setFeedback(undefined); };
  const openTopic = (id: string) => { setStack([{ kind: "home" }, { kind: "topic", id }]); setQuery(""); setFeedback(undefined); };
  const openQuestion = (id: string, fromSearch = false) => {
    const tid = topicOfQuestion(id);
    if (fromSearch) { setStack([{ kind: "home" }, { kind: "topic", id: tid }, { kind: "question", topicId: tid, id }]); setQuery(""); setFeedback(undefined); }
    else go({ kind: "question", topicId: tid, id });
  };
  const back = () => {
    if (searching) { setQuery(""); return; }
    if (stack.length > 1) { setStack((s) => s.slice(0, -1)); setFeedback(undefined); return; }
    onClose();
  };

  // The list ↑↓ / Enter move through, whatever the view.
  const question = view.kind === "question" ? topic.questions?.find((q) => q.id === view.id) : undefined;
  const entries: Array<{ key: string; open(): void }> = searching
    ? hits.map((h) => ({ key: h.id, open: () => openQuestion(h.id, true) }))
    : view.kind === "home" ? index.topics.map((t) => ({ key: t.id, open: () => openTopic(t.id) }))
    : view.kind === "topic" ? (topic.questions ?? []).map((q) => ({ key: q.id, open: () => openQuestion(q.id) }))
    : (question?.follow ?? []).map((id) => ({ key: id, open: () => openQuestion(id) }));
  const listKey = `${searching ? `?${query}` : ""}|${stack.map((v) => (v.kind === "home" ? "h" : v.id)).join("/")}|${entries.length}`;
  useEffect(() => { setCursor(0); }, [listKey]);
  useEffect(() => { list.current?.querySelector<HTMLElement>(`[data-index="${cursor}"]`)?.scrollIntoView({ block: "nearest" }); }, [cursor, listKey]);
  useEffect(() => { list.current?.scrollTo?.({ top: 0 }); }, [view]);

  const runAction = (a: GuideAction) => {
    switch (a.type) {
      case "gps":
        if (!a.target) return;
        sent.current = Date.now();
        setFeedback({ text: "Asking for a route…", error: false });
        sendAction({ type: "guide.gps", target: a.target });
        return;
      case "activities": onClose(); sendAction({ type: "activities.control", operation: "open", tab: a.tab ?? "activities" }); return;
      case "jobguide": onClose(); openJobGuide(job.name); return;
      case "housing": onClose(); emit(PAGE_EVENTS.action, { type: "housing.open" }); return;
      case "support": onClose(); emit(PAGE_EVENTS.support, { operation: "open", scope: "player" }); return;
      case "animations": onClose(); emit(PAGE_EVENTS.animationsAction, { action: "open" }); return;
      case "tutorial": onClose(); emit(PAGE_EVENTS.tutorial, { operation: "options" }); return;
      case "briefing": onClose(); setWelcomeReplay(true); return;
    }
  };
  const hasJobGuide = Array.isArray(job.guide) && job.guide.length > 0;
  const available = (a: GuideAction) => (a.type === "jobguide" ? hasJobGuide : a.type in ACTION_LABEL);

  const say = view.kind === "home" ? index.greeting[0]
    : view.kind === "question" ? question?.say ?? topic.meta?.say ?? topic.meta?.blurb
    : topic.meta?.say ?? topic.meta?.blurb ?? topicById[view.id]?.blurb;
  const crumbs: Array<{ label: string; depth: number }> = [{ label: index.npc.name.split(" ")[0]!.toUpperCase(), depth: 1 }];
  if (topicId) crumbs.push({ label: (topic.meta?.title ?? titles[topicId] ?? topicId).toUpperCase(), depth: 2 });
  if (view.kind === "question") crumbs.push({ label: question ? plainText(question.q, keys) : "…", depth: 3 });

  return <div className="guide o77-interactive" role="dialog" aria-modal="true" aria-labelledby="guide-name" ref={root} tabIndex={-1}
    onContextMenu={(e) => { e.preventDefault(); back(); }}
    onMouseUp={(e) => { if (e.button === 3) { e.preventDefault(); back(); } }}
    onKeyDown={(e) => {
      const inInput = (e.target as HTMLElement).tagName === "INPUT";
      let handled = true;
      if (e.key === "Escape") { if (!e.repeat) { if (inInput && query) setQuery(""); else onClose(); } }
      else if (e.key === "ArrowDown") setCursor((c) => (entries.length ? (c + 1) % entries.length : 0));
      else if (e.key === "ArrowUp") setCursor((c) => (entries.length ? (c - 1 + entries.length) % entries.length : 0));
      else if (e.key === "Enter") { if (!e.repeat) entries[cursor]?.open(); }
      else if (!inInput && (e.key === "Backspace" || e.key === "ArrowLeft")) { if (!e.repeat) back(); }
      else if (!inInput && e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey && e.key.trim() !== "") { searchBox.current?.focus(); handled = false; }
      else handled = false;
      if (handled) { e.preventDefault(); e.stopPropagation(); }
    }}>
    <header className="guide__bar">
      <span className="guide__bar-title"><Icon name="circle-help" size={15} />{(index.npc.tag ?? "THE CROSSING // GUIDE").toUpperCase()}</span>
      <span className="guide__bar-route">FAQ · {index.topics.length} TOPICS<button aria-label="Close" onClick={onClose}><Icon name="x" size={15} /></button></span>
    </header>

    <div className="guide__split">
      <aside className="guide__side">
        <div className="guide-portrait" aria-hidden="true">
          <span className="guide-portrait__frame">
            <span className="guide-portrait__mono">{initials(index.npc.name)}</span>
            <span className="guide-portrait__scan" />
          </span>
          <span className="guide-portrait__status"><i />ENGRAM · ONLINE</span>
        </div>
        <h1 id="guide-name" className="guide__name">{index.npc.name}</h1>
        {index.npc.title && <p className="guide__title">{index.npc.title}</p>}
        {say && <blockquote className="guide__say" key={say}><Rich text={say} keys={keys} /></blockquote>}
        <nav className="guide__nav" aria-label="Topics">
          {index.topics.map((t) => <button key={t.id} className={cx("guide-nav", topicId === t.id && "is-current")} onClick={() => openTopic(t.id)}>
            <Icon name={t.icon ?? "circle-help"} size={14} /><span>{t.title}</span><small>{t.count}</small>
          </button>)}
        </nav>
      </aside>

      <main className="guide__main">
        <label className="guide-search">
          <Icon name="search" size={15} />
          <input ref={searchBox} value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Ask Johnny… fuel, rent a car, /pay, crew"
            aria-label="Search every question" spellCheck={false} autoComplete="off" />
          {searching && <span className="guide-search__count">{hits.length} {hits.length === 1 ? "ANSWER" : "ANSWERS"}</span>}
          {searching && <button className="guide-search__clear" aria-label="Clear the search" onClick={() => { setQuery(""); searchBox.current?.focus(); }}><Icon name="x" size={13} /></button>}
        </label>
        {!searching && <nav className="guide__crumbs" aria-label="Where you are">
          {crumbs.map((c, i) => <Fragment key={c.depth}>
            {i > 0 && <Icon name="chevron-right" size={12} />}
            {i < crumbs.length - 1
              ? <button onClick={() => setStack((s) => s.slice(0, c.depth))}>{c.label}</button>
              : <span aria-current="page">{c.label}</span>}
          </Fragment>)}
        </nav>}

        <div className="guide__content" ref={list}>
          {searching ? <SearchResults hits={hits} cursor={cursor} keys={keys} onOpen={(id) => openQuestion(id, true)} onHover={setCursor}
              loading={rows.length === 0} />
            : view.kind === "home" ? <Home index={index} cursor={cursor} keys={keys} onOpen={openTopic} onHover={setCursor} />
            : !topic.questions ? <Waiting missing={topic.missing} failed={topic.failed} />
            : view.kind === "topic" ? <TopicView summary={topicById[view.id]} blurb={topic.meta?.blurb} questions={topic.questions} cursor={cursor} keys={keys}
                onOpen={(id) => openQuestion(id)} onHover={setCursor} />
            : question ? <Answer question={question} keys={keys} cursor={cursor} titleOf={questionText} onOpen={(id) => openQuestion(id)}
                onHover={setCursor} actions={question.actions.filter(available)} onAction={runAction} labelOf={(a) => a.label ?? ACTION_LABEL[a.type] ?? a.type} />
            : <p className="guide__empty"><Icon name="info" size={14} />That answer moved. Go back and pick it again.</p>}
        </div>
      </main>
    </div>

    <footer className="guide__foot">
      <span className={cx("guide__feedback", feedback?.error && "is-error")} role="status">
        {feedback?.text ?? `${index.topics.reduce((n, t) => n + t.count, 0)} answers · type anywhere to search · talk to ${index.npc.name.split(" ")[0]} again any time`}
      </span>
      <span className="guide__keys">
        <span><Keycap size="sm">↑↓</Keycap>CHOOSE</span>
        <span><Keycap size="sm">ENTER</Keycap>OPEN</span>
        <span><Keycap size="sm">RMB</Keycap>BACK</span>
        <span><Keycap size="sm">ESC</Keycap>CLOSE</span>
      </span>
    </footer>
  </div>;
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] ?? "?") + (parts.length > 1 ? parts[parts.length - 1]![0] : "")).toUpperCase();
}

function Home({ index, cursor, keys, onOpen, onHover }: { index: GuideDialogPayload; cursor: number; keys: Record<string, string>; onOpen(id: string): void; onHover(i: number): void }) {
  if (index.topics.length === 0) return <p className="guide__empty"><Icon name="info" size={14} />Nothing to ask about right now.</p>;
  return <>
    {index.greeting.length > 1 && <p className="guide__lead"><Rich text={index.greeting[1]!} keys={keys} /></p>}
    <div className="guide-topics" role="listbox" aria-label="Topics">
      {index.topics.map((t: GuideTopicSummary, i) => <button key={t.id} data-index={i} role="option" aria-selected={i === cursor}
        className={cx("guide-topic", i === cursor && "is-selected")} onClick={() => onOpen(t.id)} onMouseEnter={() => onHover(i)}>
        <span className="guide-topic__icon"><Icon name={t.icon ?? "circle-help"} size={17} /></span>
        <span className="guide-topic__text"><strong>{t.title}</strong>{t.blurb && <small><Rich text={t.blurb} keys={keys} /></small>}</span>
        <span className="guide-topic__count">{t.count}</span>
      </button>)}
    </div>
  </>;
}

function TopicView({ summary, blurb, questions, cursor, keys, onOpen, onHover }: {
  summary?: GuideTopicSummary; blurb?: string; questions: GuideQuestion[]; cursor: number; keys: Record<string, string>; onOpen(id: string): void; onHover(i: number): void;
}) {
  return <>
    {(blurb ?? summary?.blurb) && <p className="guide__lead"><Rich text={(blurb ?? summary?.blurb)!} keys={keys} /></p>}
    <div className="guide-questions" role="listbox" aria-label="Questions">
      {questions.map((q, i) => <QuestionRow key={q.id} index={i} selected={i === cursor} text={q.q} keys={keys} onOpen={() => onOpen(q.id)} onHover={() => onHover(i)} />)}
    </div>
  </>;
}

function QuestionRow({ index, selected, text, sub, keys, onOpen, onHover }: { index: number; selected: boolean; text: string; sub?: string; keys: Record<string, string>; onOpen(): void; onHover(): void }) {
  return <button data-index={index} role="option" aria-selected={selected} className={cx("guide-question", selected && "is-selected")} onClick={onOpen} onMouseEnter={onHover}>
    <Icon name="chevron-right" size={14} />
    <span className="guide-question__text"><span><Rich text={text} keys={keys} /></span>{sub && <small>{sub}</small>}</span>
  </button>;
}

function SearchResults({ hits, cursor, keys, loading, onOpen, onHover }: {
  hits: ReturnType<typeof searchGuide>; cursor: number; keys: Record<string, string>; loading: boolean; onOpen(id: string): void; onHover(i: number): void;
}) {
  if (hits.length === 0) return <p className="guide__empty"><Icon name={loading ? "loader" : "info"} size={14} />
    {loading ? "Johnny is still sorting his notes…" : "Nothing on that. Try another word, or pick a topic on the left."}</p>;
  return <div className="guide-questions" role="listbox" aria-label="Answers">
    {hits.map((h, i) => <QuestionRow key={h.id} index={i} selected={i === cursor} text={h.q} sub={h.topicTitle} keys={keys} onOpen={() => onOpen(h.id)} onHover={() => onHover(i)} />)}
  </div>;
}

function Waiting({ missing, failed }: { missing: boolean; failed: boolean }) {
  if (missing) return <p className="guide__empty is-error"><Icon name="triangle-alert" size={14} />That topic is gone. Close and talk to Johnny again.</p>;
  if (failed) return <p className="guide__empty is-error"><Icon name="triangle-alert" size={14} />No answer from Johnny. Close and talk to him again.</p>;
  return <p className="guide__empty"><Icon name="loader" size={14} className="guide__spin" />Johnny is thinking…</p>;
}

function Answer({ question, keys, cursor, actions, titleOf, labelOf, onOpen, onHover, onAction }: {
  question: GuideQuestion; keys: Record<string, string>; cursor: number; actions: GuideAction[];
  titleOf(id: string): string; labelOf(a: GuideAction): string; onOpen(id: string): void; onHover(i: number): void; onAction(a: GuideAction): void;
}) {
  return <article className="guide-answer">
    <h2 className="guide-answer__q"><Rich text={question.q} keys={keys} /></h2>
    <div className="guide-answer__body">
      {toBlocks(question.a).map((b, i) => b.kind === "p" ? <p key={i}><Rich text={b.text} keys={keys} /></p>
        : b.kind === "tip" ? <p key={i} className="guide-answer__tip"><Icon name="info" size={14} /><span><Rich text={b.text} keys={keys} /></span></p>
        : b.kind === "steps" ? <ol key={i}>{b.items.map((t, j) => <li key={j}><Rich text={t} keys={keys} /></li>)}</ol>
        : <ul key={i}>{b.items.map((t, j) => <li key={j}><Rich text={t} keys={keys} /></li>)}</ul>)}
    </div>
    {actions.length > 0 && <div className="guide-answer__actions">
      {actions.map((a, i) => <button key={`${a.type}:${a.target ?? a.tab ?? i}`} className={cx("guide-action", a.type === "gps" && "is-gps")} onClick={() => onAction(a)}>
        <Icon name={ACTION_ICON[a.type] ?? "arrow-right"} size={14} />{labelOf(a)}
      </button>)}
    </div>}
    {question.follow.length > 0 && <>
      <h3 className="guide-answer__step">ASK NEXT</h3>
      <div className="guide-questions" role="listbox" aria-label="Ask next">
        {question.follow.map((id, i) => <QuestionRow key={id} index={i} selected={i === cursor} text={titleOf(id)} keys={keys} onOpen={() => onOpen(id)} onHover={() => onHover(i)} />)}
      </div>
    </>}
  </article>;
}

/* ---------- inline markup ---------- */

function Rich({ text, keys }: { text: string; keys: Record<string, string> }) {
  return <>{renderInline(parseInline(text), keys)}</>;
}
function renderInline(parts: GuideInline[], keys: Record<string, string>): ReactNode[] {
  return parts.map((p, i) => p.kind === "text" ? <Fragment key={i}>{p.text}</Fragment>
    : p.kind === "code" ? <code key={i} className="guide-code">{p.text}</code>
    : p.kind === "bold" ? <strong key={i}>{renderInline(p.parts, keys)}</strong>
    : <Keycap key={i} size="sm" className="guide-key">{keys[p.name] ?? p.name.toUpperCase()}</Keycap>);
}
