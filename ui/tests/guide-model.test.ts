import assert from "node:assert/strict";
import test from "node:test";
import { arr, normalizeIndex, parseInline, plainText, searchGuide, toBlocks, topicOf, topicQuestions, useGuideFeed } from "../src/features/guide/model.ts";
import { guideFixture } from "../src/features/guide/fixture.ts";

test("answer lines become paragraphs, bullets, steps and tips", () => {
  const blocks = toBlocks(["Intro **bold**.", "- one", "- two", "1. first", "2. second", "> a tip", "", "Outro"]);
  assert.deepEqual(blocks.map((b) => b.kind), ["p", "bullets", "steps", "tip", "p"]);
  assert.deepEqual(blocks[1], { kind: "bullets", items: ["one", "two"] });
  assert.deepEqual(blocks[2], { kind: "steps", items: ["first", "second"] });
  assert.deepEqual(blocks[3], { kind: "tip", text: "a tip" });
});

test("inline markup: code, bold holding a key, the player's key", () => {
  const parts = parseInline("Type `/pay 12 50`, press **{key:interact} twice** then {key:inventory}.");
  assert.deepEqual(parts.map((p) => p.kind), ["text", "code", "text", "bold", "text", "key", "text"]);
  assert.deepEqual(parts[3], { kind: "bold", parts: [{ kind: "key", name: "interact" }, { kind: "text", text: " twice" }] });
  assert.equal(plainText("Press {key:inventory} for **the bag** (`I`).", { inventory: "K" }), "Press K for the bag (I).");
  assert.equal(plainText("{key:unknown}", {}), "UNKNOWN");
});

test("search: every word must match the question, its tags or its topic", () => {
  const rows: Array<[string, string, string, string]> = [
    ["vehicles.fuel", "vehicles", "How do I refuel?", "fuel gas petrol pump"],
    ["vehicles.rent", "vehicles", "How do I rent a car?", "rent rental car"],
    ["money.pay", "money", "How do I pay someone?", "pay give cash /pay"],
  ];
  const titles = { vehicles: "Vehicles & fuel", money: "Money" };
  assert.deepEqual(searchGuide("petrol", rows, titles).map((h) => h.id), ["vehicles.fuel"]);
  assert.deepEqual(searchGuide("rent car", rows, titles).map((h) => h.id), ["vehicles.rent"]);
  assert.deepEqual(searchGuide("/pay", rows, titles).map((h) => h.id), ["money.pay"]);
  assert.equal(searchGuide("vehicles", rows, titles).length, 2, "the topic title matches");
  assert.deepEqual(searchGuide("rent zebra", rows, titles), []);
  assert.deepEqual(searchGuide("   ", rows, titles), []);
  assert.equal(searchGuide("fuel", rows, titles)[0]!.id, "vehicles.fuel", "a word in the question ranks first");
});

test("the feed: revisions, parts, keys, missing topics", () => {
  const feed = useGuideFeed.getState();
  feed.ensure("r1");
  feed.receive({ revision: "r1", effectiveKeys: { inventory: "K" } });
  feed.receive({ revision: "r1", search: [["a.one", "a", "One?", ""]], part: 1, parts: 2 });
  feed.receive({ revision: "r1", search: {} as never, part: 2, parts: 2 });
  let s = useGuideFeed.getState();
  assert.equal(s.keys.inventory, "K");
  assert.deepEqual(s.searchParts.sort(), [1, 2]);
  assert.ok(s.search["a.one"]);
  // a topic in two parts is complete only with both; Lua's {} lists become arrays
  feed.receive({ revision: "r1", topic: { id: "a", title: "A" }, questions: [{ id: "a.two", q: "Two?", a: ["x"], follow: {} as never, actions: {} as never }], part: 2, parts: 2 });
  assert.equal(topicQuestions(useGuideFeed.getState().topics.a), undefined);
  feed.receive({ revision: "r1", topic: { id: "a", title: "A" }, questions: [{ id: "a.one", q: "One?", a: ["y"], follow: ["a.two"], actions: [] }], part: 1, parts: 2 });
  const questions = topicQuestions(useGuideFeed.getState().topics.a)!;
  assert.deepEqual(questions.map((q) => q.id), ["a.one", "a.two"]);
  assert.deepEqual(questions[1]!.follow, []);
  assert.deepEqual(questions[1]!.actions, []);
  feed.receive({ revision: "r1", missing: "gone" });
  assert.equal(useGuideFeed.getState().missing.gone, true);
  // a new revision drops the cache, the keys stay
  feed.receive({ revision: "r2", search: [["b.one", "b", "B?", ""]], part: 1, parts: 1 });
  s = useGuideFeed.getState();
  assert.equal(s.revision, "r2");
  assert.equal(s.search["a.one"], undefined);
  assert.deepEqual(s.topics, {});
  assert.equal(s.keys.inventory, "K");
  // a keys-only message (rebinding) changes the keys, nothing else
  feed.receive({ effectiveKeys: { inventory: "J" } });
  assert.equal(useGuideFeed.getState().keys.inventory, "J");
  assert.equal(useGuideFeed.getState().revision, "r2");
});

test("index normalization, ids and the generated fixture", () => {
  const index = normalizeIndex({ kind: "guide", revision: "r", npc: { name: "Johnny Silverhand" }, greeting: {} as never, topics: {} as never });
  assert.deepEqual(index.greeting, []);
  assert.deepEqual(index.topics, []);
  assert.deepEqual(index.keys, {});
  assert.deepEqual(arr({}), []);
  assert.equal(topicOf("vehicles.fuel"), "vehicles");
  // the fixture is what the server sends: every topic of the index, every searchable question
  const f = guideFixture;
  assert.equal(f.index.npc.name, "Johnny Silverhand");
  const rows = f.search.flatMap((m) => arr<[string, string, string, string]>(m.search));
  const counted = f.index.topics.reduce((n, t) => n + t.count, 0);
  assert.equal(rows.length, counted, "the search index lists every question of the index");
  for (const [id, topic] of Object.entries(f.topics)) {
    const total = f.topics[id]!.reduce((n, m) => n + arr(m.questions).length, 0);
    assert.equal(total, f.index.topics.find((t) => t.id === id)!.count, `${id}: every question`);
    for (const m of topic) for (const q of arr<{ a: string[] }>(m.questions)) for (const line of q.a) assert.ok(!line.includes("—"), `${id}: resolved`);
  }
  assert.ok(searchGuide("rent car", rows, Object.fromEntries(f.index.topics.map((t) => [t.id, t.title]))).some((h) => h.id === "vehicles.rent"));
});
