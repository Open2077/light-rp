import assert from "node:assert/strict";
import test from "node:test";
import {
  QUEUE_LEAVE_ITEM, clockDown, clockUp, countLabel, keyCap, leaveText, missing, normalizeQueue, queueMenuItem, repeatsPanel, startsInMs,
  statusOf, waitedMs, type QueueView,
} from "../src/features/queue/model.ts";

// As server/modules/activity_queue.lua sends it (nil fields left out).
const view = (extra: Record<string, unknown> = {}) => normalizeQueue({
  v: 1, id: "chase.wanted", label: "Most Wanted", count: 3, need: 3, max: 8, sinceMs: 12000, state: "waiting", source: "provider", ...extra,
}) as QueueView;

test("a pushed view is kept; junk is dropped; false and garbage are no queue", () => {
  const q = view({ mode: "car or foot" });
  assert.deepEqual([q.id, q.label, q.mode, q.count, q.need, q.max, q.sinceMs, q.state, q.source], ["chase.wanted", "Most Wanted", "car or foot", 3, 3, 8, 12000, "waiting", "provider"]);
  assert.equal(normalizeQueue(false), false);
  assert.equal(normalizeQueue(undefined), false);
  assert.equal(normalizeQueue({ v: 1, label: "No id" }), false);
  assert.equal(normalizeQueue("queue"), false);
  const junk = view({ count: -1, need: "6", max: Infinity, sinceMs: NaN, state: "dancing", source: "elsewhere", crew: "yes", mode: 7 });
  assert.equal(junk.count, undefined);
  assert.equal(junk.need, undefined);
  assert.equal(junk.max, undefined, "no max without a need");
  assert.equal(junk.sinceMs, 0);
  assert.equal(junk.state, "waiting");
  assert.equal(junk.source, "provider");
  assert.equal(junk.crew, undefined);
  assert.equal(junk.mode, undefined);
  assert.equal(view({ label: "x".repeat(200) }).label.length, 64, "labels are cut");
});

test("players in queue against the players it takes: 3 / 6, 3 / 2-8, a count alone", () => {
  assert.equal(countLabel(view({ count: 3, need: 6, max: undefined })), "3 / 6");
  assert.equal(countLabel(view({ count: 3, need: 2, max: 8 })), "3 / 2-8");
  assert.equal(countLabel(view({ count: 2, need: 2, max: 2 })), "2 / 2", "max == need reads once");
  assert.equal(countLabel(view({ count: 5, need: undefined, max: undefined })), "5");
  assert.equal(countLabel(view({ count: undefined, need: 4, max: undefined })), "1 / 4", "you are one at least");
  assert.equal(countLabel(view({ count: undefined, need: undefined, max: undefined })), undefined);
  assert.equal(missing(view({ count: 1, need: 3 })), 2);
  assert.equal(missing(view({ count: 4, need: 3 })), 0);
});

test("the wait counts up and the start down from the push, never below zero", () => {
  const q = view({ sinceMs: 65000, startsInMs: 9500, state: "starting" });
  assert.equal(waitedMs(q, 5000), 70000);
  assert.equal(clockUp(waitedMs(q, 5000)), "1:10");
  assert.equal(clockUp(3723000), "1:02:03");
  assert.equal(clockUp(-5), "0:00");
  assert.equal(startsInMs(q, 2000), 7500);
  assert.equal(clockDown(7500), "0:08", "rounded up: 0:00 only when it is over");
  assert.equal(clockDown(0), "0:00");
  assert.equal(startsInMs(q, 20000), 0);
  assert.equal(startsInMs(view(), 1000), undefined);
  // a countdown only while starting
  assert.equal(view({ startsInMs: 5000, state: "waiting" }).startsInMs, undefined);
  assert.equal(view({ startsInMs: 5000, state: undefined }).state, "starting", "a start without a state is a start");
});

test("the tag: queued, tagged, starting, launching, match found; the note says how many more", () => {
  assert.deepEqual(statusOf(view({ count: 1, need: 3 })), { tag: "QUEUED", note: "NEED 2 MORE", tone: "plain" });
  assert.deepEqual(statusOf(view({ count: 3, need: 3 })), { tag: "QUEUED", note: undefined, tone: "plain" });
  assert.equal(statusOf(view({ source: "mission", id: "missions" })).tag, "TAGGED");
  assert.deepEqual(statusOf(view({ state: "starting", startsInMs: 4000 })), { tag: "STARTING", tone: "accent" });
  assert.equal(statusOf(view({ state: "starting", startsInMs: 4000, source: "mission" })).tag, "LAUNCHING");
  assert.deepEqual(statusOf(view({ state: "joining" })), { tag: "MATCH FOUND", note: "JOINING", tone: "go" });
});

test("the cancel key: the bound one, U until the client says, none once cleared", () => {
  assert.equal(keyCap("K"), "K");
  assert.equal(keyCap(undefined), "U");
  assert.equal(keyCap(false), undefined);
  assert.equal(keyCap("  "), undefined);
  assert.equal(keyCap("PAGEDOWN-LONG-NAME"), "PAGEDOWN-LON");
});

test("F1: Leave queue while queued, sending what the key sends; nothing otherwise", () => {
  assert.equal(queueMenuItem(false), undefined);
  assert.equal(queueMenuItem(undefined), undefined);
  const item = queueMenuItem(view({ count: 2, need: 3, mode: "by car" }))!;
  assert.equal(item.id, QUEUE_LEAVE_ITEM);
  assert.equal(item.text, "Leave queue");
  assert.equal(item.meta, "2 / 3-8");
  assert.match(item.description!, /^Most Wanted · by car\. Withdraws you/);
  assert.equal(queueMenuItem(view({ count: undefined, need: undefined, max: undefined }))!.meta, "WAITING");
  assert.match(leaveText(view({ crew: true })), /your crew keeps waiting/);
  assert.match(leaveText(view({ source: "mission", id: "missions", label: "Data Heist" })), /^Untags you from Data Heist/);
});

test("the provider's own lobby header for the same queue steps aside; anything else stays", () => {
  const q = view();
  assert.equal(repeatsPanel(q, "chase.wanted", "lobby"), true);
  assert.equal(repeatsPanel(q, "chase.wanted", "running"), false, "a match keeps its HUD");
  assert.equal(repeatsPanel(q, "race.editor", "lobby"), false, "another lobby stays");
  assert.equal(repeatsPanel(false, "chase.wanted", "lobby"), false);
  assert.equal(repeatsPanel(q, undefined, "lobby"), false);
});
