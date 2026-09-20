import { test } from "node:test";
import assert from "node:assert/strict";
import { ActionClock, timingStep, type ActionDefinition } from "../src/features/actions/model.ts";
const base: ActionDefinition = { id: "test", kind: "progress", label: "Test", description: "", icon: "wrench", style: "bar", key: "E", cancellable: true,
  durationMs: 1000, timeoutMs: 10000, release: "reset", maxMistakes: 0, steps: [{ key: "E", durationMs: 2000, zoneStart: .4, zoneWidth: .2 }] };
test("progress waits for readiness, completes once, and ignores later input", () => {
  const c = new ActionClock(base, 0);
  assert.equal(c.tick(300).phase, "ready"); assert.equal(c.tick(900).progress, .5);
  const result = c.tick(1400).result;
  assert.equal(result?.status, "success"); assert.equal(c.finish("failed", "timeout", 2000), result);
});
test("holding requires an actual press; releasing resets or cancels", () => {
  const c = new ActionClock({ ...base, kind: "hold" }, 0);
  c.press(100); assert.equal(c.tick(2000).progress, 0);
  c.release(2001); c.press(2100); assert.equal(c.tick(2600).progress, .5);
  c.release(2700); assert.equal(c.tick(2800).progress, 0);
  c.press(3000); assert.equal(c.tick(4000).result?.status, "success");
  const release = new ActionClock({ ...base, kind: "hold", release: "cancel" }, 0);
  release.press(500); release.release(750); assert.equal(release.view.result?.reason, "released");
});
test("timing is calculated at keydown, not from the last rendered position", () => {
  const c = new ActionClock({ ...base, kind: "timing" }, 0);
  c.tick(401); c.press(1400);
  assert.equal(c.view.result?.status, "success"); assert.equal(c.view.result?.score, 100);
  const early = new ActionClock({ ...base, kind: "timing" }, 0);
  early.press(500); assert.equal(early.view.result?.reason, "too_early");
  const late = new ActionClock({ ...base, kind: "timing" }, 0);
  late.press(2500); assert.equal(late.view.result?.status, "failed");
});
test("multi-step feedback consumes no extra hit and each step has its own clock", () => {
  const c = new ActionClock({ ...base, kind: "timing", steps: [base.steps[0]!, base.steps[0]!] }, 0);
  c.press(1400); assert.equal(c.view.phase, "feedback"); c.press(1450); assert.equal(c.view.hits, 1);
  c.tick(1850); assert.equal(c.view.step, 1); c.press(2850);
  assert.equal(c.view.result?.hits, 2); assert.equal(c.view.result?.status, "success");
});
test("miss budgets, deadlines and external interruptions do not yield false success", () => {
  const c = new ActionClock({ ...base, kind: "timing", maxMistakes: 1, steps: [base.steps[0]!, base.steps[0]!] }, 0);
  c.press(500); assert.equal(c.view.mistakes, 1); c.tick(950); c.press(1950);
  assert.equal(c.view.result?.status, "success"); assert.equal(c.view.result?.score, 50);
  const idle = new ActionClock({ ...base, kind: "hold", timeoutMs: 3000 }, 0);
  assert.equal(idle.tick(3000).result?.reason, "timeout");
  const cancel = new ActionClock(base, 0); cancel.finish("cancelled", "dead", 100);
  assert.equal(cancel.tick(5000).result?.status, "cancelled");
});
test("difficulty presets always generate reachable bounded zones", () => {
  for (const difficulty of ["easy", "normal", "hard"] as const) for (const r of [0, .5, 1]) {
    const s = timingStep(difficulty, "R", () => r);
    assert.ok(s.zoneStart >= .1 && s.zoneStart + s.zoneWidth <= .9);
    assert.equal(s.key, "R");
  }
});
