import { PAGE_EVENTS, type UiAction } from "@/bridge/protocol";
import { guideFixture } from "./fixture";
import type { GuideMessage, GuideSearchRow } from "./model";
import type { TalkNode } from "./talk";
import { talkFixture } from "./talkFixture";

/* Browser fixture of Johnny (Vite dev only). ?dialog=guide opens it the way the
   server does: the dialog (index and the dialogue's opening), then the keys, the
   opening's next nodes and the search index. Nodes come when the page asks
   (guide.node, with their children), topics too (guide.topic), "Mark on map" and the
   Hall of Fame answer with a toast. &talk=0 opens the FAQ alone (no dialogue),
   &rebind=1 shows a rebound inventory key (K), &slow=1 delays nodes and topics by
   1.5 s, &lost=1 never answers them (the retry and the error line),
   &press=ArrowDown,Enter,… walks the dialog with those keys, 300 ms apart
   (screenshots of a node, a topic or an answer). */
export function guideMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const { index, search, topics } = guideFixture;
  const revision = index.revision;
  const keys: Record<string, string> = { ...(index.keys ?? {}), ...(params.get("rebind") === "1" ? { inventory: "K" } : {}) };
  const send = (m: GuideMessage) => fire(PAGE_EVENTS.guide, { ...m, effectiveKeys: keys });
  const rows: GuideSearchRow[] = search.flatMap((m) => (Array.isArray(m.search) ? m.search : []));
  const talk = params.get("talk") === "0" ? undefined : talkFixture.opening;
  const talkNodes: Record<string, TalkNode> = Object.fromEntries(talkFixture.nodes.map((n) => [n.id, n]));
  // a node and the nodes its choices lead to, as the server answers guide.node
  const talkAnswer = (id: string, withSelf: boolean): GuideMessage => {
    const node = id === talkFixture.opening.root ? talkFixture.opening.node : talkNodes[id];
    const talkRevision = talkFixture.opening.revision;
    if (!node) return { talk: { revision: talkRevision, missing: id } };
    const children = node.choices.map((c) => (c.to ? talkNodes[c.to] : undefined)).filter((n): n is TalkNode => !!n);
    return { talk: { revision: talkRevision, nodes: withSelf ? [node, ...children] : children } };
  };

  // A topic the fixture does not carry: its questions with a note in place of the answer.
  const placeholder = (id: string): GuideMessage[] | undefined => {
    const summary = index.topics.find((t) => t.id === id);
    if (!summary) return undefined;
    const questions = rows.filter((r) => r[1] === id).map(([qid, , q]) => ({
      id: qid, q, a: ["(Dev fixture) This topic's answers come from the server in game.", "> Six topics carry their real answers here: First day, Controls, Money, Jobs, Vehicles, Help."],
      follow: [], actions: [],
    }));
    return [{ revision, topic: { id, title: summary.title, icon: summary.icon, blurb: summary.blurb }, questions, part: 1, parts: 1 }];
  };

  return {
    boot() {
      if (params.get("dialog") !== "guide") return;
      fire(PAGE_EVENTS.dialog, talk ? { ...index, talk } : index);
      send({ revision });
      if (talk) send(talkAnswer(talk.root, false));
      for (const m of search) send(m);
      (params.get("press") ?? "").split(",").filter(Boolean).forEach((key, i) => window.setTimeout(() => {
        const target = document.activeElement instanceof HTMLElement && document.activeElement !== document.body ? document.activeElement : document.querySelector(".guide");
        target?.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }));
      }, 400 + i * 300));
    },
    /** True when the action was the guide's. */
    handle(action: UiAction): boolean {
      if (action.type === "guide.topic") {
        if (params.get("lost") === "1") return true;
        const messages = topics[action.id] ?? placeholder(action.id) ?? [{ revision, missing: action.id }];
        window.setTimeout(() => messages.forEach(send), params.get("slow") === "1" ? 1500 : 120);
        return true;
      }
      if (action.type === "guide.node") {
        if (params.get("lost") === "1") return true;
        const message = talkAnswer(action.id, true);
        window.setTimeout(() => send(message), params.get("slow") === "1" ? 1500 : 120);
        return true;
      }
      if (action.type === "guide.panel") {
        window.setTimeout(() => fire(PAGE_EVENTS.result, { ok: true, text: "(Dev fixture) The Hall of Fame opens here in game.", action: "guide.panel" }), 150);
        return true;
      }
      if (action.type === "guide.gps") {
        const names: Record<string, string> = { jobcenter: "Job Center // City Center", rental: "Rent-a-Ride // City Center", garage: "Public Garage // City Center",
          dealership: "Westbrook Dealership", starter: "your studio", crossing: "The Crossing", fuel: "Fuel station", food: "the nearest food shop", dogtown: "Dogtown" };
        window.setTimeout(() => fire(PAGE_EVENTS.result, { ok: true, text: `GPS set: ${names[action.target] ?? action.target}.`, action: "guide.gps" }), 150);
        return true;
      }
      if (action.type === "guide.open") { window.setTimeout(() => this.boot(), 50); return true; }
      return false;
    },
  };
}
