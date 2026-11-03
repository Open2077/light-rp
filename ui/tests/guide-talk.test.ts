import assert from "node:assert/strict";
import test from "node:test";
import { choiceKey, missingTargets, normalizeNode, normalizeOpening, stepStart, talkRows, useTalkFeed, TALK_LABELS } from "../src/features/guide/talk.ts";
import { talkFixture } from "../src/features/guide/talkFixture.ts";

test("a node from Lua: {} lists, bad choices and empty pages are cleaned", () => {
  const node = normalizeNode({
    id: "money", pages: [["Honest work or dirty work.", "", 3], {}],
    choices: [
      { label: "Get me a job.", to: "job" },
      { label: "Mark it.", act: { type: "gps", target: "jobcenter" } },
      { label: "No target.", act: { type: "gps" } },
      { label: "Write it down.", act: { type: "faq", id: "money.pay" } },
      { label: "No id.", act: { type: "faq" } },
      { label: "Unknown.", act: { type: "teleport" } },
      { label: "", to: "x" },
      { label: "Nothing" },
    ],
  });
  assert.ok(node);
  assert.deepEqual(node.pages, [["Honest work or dirty work."]]);
  assert.deepEqual(node.choices.map((c) => c.label), ["Get me a job.", "Mark it.", "Write it down."]);
  assert.deepEqual(normalizeNode({ id: "empty", pages: {}, choices: {} }), { id: "empty", pages: [["…"]], choices: [] });
  assert.equal(normalizeNode({ pages: [] }), undefined);
});

test("the opening must be the root node", () => {
  const node = { id: "hello", pages: [["Hi."]], choices: [] };
  assert.equal(normalizeOpening({ revision: "1", root: "hello", node: { ...node, id: "other" } }), undefined);
  assert.equal(normalizeOpening({ root: "hello", node }), undefined);
  const opening = normalizeOpening({ revision: "1", root: "hello", node, farewell: "" });
  assert.ok(opening);
  assert.equal(opening.farewell, undefined);
  assert.equal(normalizeOpening({ revision: "1", root: "hello", node, farewell: "Bye." })?.farewell, "Bye.");
});

test("the feed keeps a revision's nodes and starts over on another", () => {
  const feed = useTalkFeed.getState();
  const hello = { id: "hello", pages: [["Hi."]], choices: [{ label: "Go.", to: "first" }] };
  feed.start({ revision: "r1", root: "hello", node: hello });
  feed.receive({ revision: "r1", nodes: [{ id: "first", pages: [["First."]], choices: [] }] });
  feed.receive({ revision: "r1", missing: "gone" });
  assert.deepEqual(Object.keys(useTalkFeed.getState().nodes).sort(), ["first", "hello"]);
  assert.equal(useTalkFeed.getState().missing.gone, true);
  // a new conversation on the same revision keeps what arrived
  feed.start({ revision: "r1", root: "hello", node: { ...hello, pages: [["Hey."]] } });
  assert.ok(useTalkFeed.getState().nodes.first);
  assert.deepEqual(useTalkFeed.getState().nodes.hello?.pages, [["Hey."]]);
  // the node that was missing arrives
  feed.receive({ revision: "r1", nodes: [{ id: "gone", pages: [["Back."]], choices: [] }] });
  assert.equal(useTalkFeed.getState().missing.gone, undefined);
  // another revision: the tree changed on the server
  feed.receive({ revision: "r2", nodes: [{ id: "money", pages: [["Eddies."]], choices: [] }] });
  assert.deepEqual(Object.keys(useTalkFeed.getState().nodes), ["money"]);
  feed.receive(undefined);
  feed.receive({ nodes: [] } as never);
  assert.equal(useTalkFeed.getState().revision, "r2");
});

test("missing targets: the nodes a node leads to that the page lacks", () => {
  const node = { id: "a", pages: [["A."]], choices: [{ label: "B.", to: "b" }, { label: "C.", to: "c" }, { label: "B again.", to: "b" }, { label: "Map.", act: { type: "gps" as const, target: "x" } }] };
  assert.deepEqual(missingTargets(node, { c: { id: "c", pages: [], choices: [] } }), ["b"]);
  assert.deepEqual(missingTargets(undefined, {}), []);
});

test("rows: Go on while pages remain, then the choices, Back and That's all", () => {
  const node = { id: "fuel", pages: [["One."], ["Two."]], choices: [
    { label: "Mark it.", act: { type: "gps" as const, target: "fuel" } },
    { label: "My job guide.", act: { type: "jobguide" as const } },
    { label: "More.", to: "more" },
  ] };
  assert.deepEqual(talkRows(node, 0, false).map((r) => r.label), [TALK_LABELS.more, TALK_LABELS.back, TALK_LABELS.bye]);
  assert.deepEqual(talkRows(node, 1, false).map((r) => r.kind), ["choice", "choice", "choice", "back", "bye"]);
  // at the opening there is nothing to go back to; a choice the player cannot use is hidden
  const rows = talkRows(node, 1, true, (c) => c.act?.type !== "jobguide");
  assert.deepEqual(rows.map((r) => r.label), ["Mark it.", "More.", TALK_LABELS.bye]);
  assert.equal(new Set(talkRows(node, 1, false).map((r) => r.key)).size, 5, "row keys are unique");
  assert.deepEqual(talkRows(undefined, 0, false).map((r) => r.kind), ["back", "bye"]);
  assert.equal(choiceKey(node.choices[0]!), "act:gps:fuel");
  assert.equal(choiceKey(node.choices[2]!), "more");
});

test("numbered steps cut by a page break keep counting", () => {
  const pages = [["Here's how:", "1. Park.", "2. Pay."], ["3. Fill.", "4. Go."], ["Done."]];
  assert.equal(stepStart(pages, 0), 1);
  assert.equal(stepStart(pages, 1), 3);
  assert.equal(stepStart(pages, 2), 1);
  assert.equal(stepStart([["1. A.", "2. B."], ["3. C."]], 1), 3);
});

test("the dev fixture is a whole tree the page accepts as it is", () => {
  const opening = normalizeOpening(talkFixture.opening);
  assert.ok(opening, "the opening normalizes");
  const nodes = new Map(talkFixture.nodes.map((n) => [n.id, n]));
  nodes.set(opening.root, opening.node);
  assert.ok(opening.node.choices.length >= 5 && opening.node.choices.length <= 7, "five to seven first choices");
  for (const node of nodes.values()) {
    assert.deepEqual(normalizeNode(node), node, `${node.id}: nothing dropped by the page`);
    assert.ok(node.pages.every((p) => p.length <= 3), `${node.id}: three lines a page at most`);
    for (const c of node.choices) if (c.to) assert.ok(nodes.has(c.to), `${node.id}: "${c.label}" leads to ${c.to}`);
  }
  // every node reachable from the opening
  const seen = new Set([opening.root]);
  const todo = [opening.root];
  while (todo.length) for (const c of nodes.get(todo.shift()!)!.choices) if (c.to && !seen.has(c.to)) { seen.add(c.to); todo.push(c.to); }
  assert.equal(seen.size, nodes.size);
});
