/** Pure interaction clock. The renderer never decides a hit from a stale frame. */
export type ActionKind = "progress" | "hold" | "timing";
export type Difficulty = "easy" | "normal" | "hard";
export interface TimingStep { key: string; durationMs: number; zoneStart: number; zoneWidth: number }
export interface ActionDefinition {
  id: string; kind: ActionKind; label: string; description: string; icon: string;
  style: "bar" | "ring"; durationMs: number; timeoutMs: number; key: string;
  cancellable: boolean; release: "reset" | "cancel"; steps: TimingStep[]; maxMistakes: number;
}
export interface ActionResult {
  id: string; status: "success" | "failed" | "cancelled"; reason: string;
  elapsedMs: number; hits: number; mistakes: number; score: number;
}
export interface ActionView {
  phase: "ready" | "running" | "feedback" | "done"; progress: number; remainingMs: number;
  step: number; held: boolean; hits: number; mistakes: number; feedback: string; result?: ActionResult;
}
export const DIFFICULTY = {
  easy: { durationMs: 2600, zoneWidth: .24 },
  normal: { durationMs: 2000, zoneWidth: .16 },
  hard: { durationMs: 1450, zoneWidth: .09 },
} as const;
export function timingStep(difficulty: Difficulty, key = "E", random = Math.random): TimingStep {
  const preset = DIFFICULTY[difficulty];
  return { ...preset, key, zoneStart: .28 + random() * (.6 - preset.zoneWidth) };
}
export class ActionClock {
  private started: number;
  private roundAt: number;
  private heldAt: number | null = null;
  private readyAt: number;
  private feedbackUntil = 0;
  private scores: number[] = [];
  readonly view: ActionView = { phase: "ready", progress: 0, remainingMs: 0, step: 0, held: false, hits: 0, mistakes: 0, feedback: "Get ready" };
  readonly definition: ActionDefinition;
  constructor(definition: ActionDefinition, now: number) {
    this.definition = definition;
    this.started = now; this.readyAt = now + 400; this.roundAt = this.readyAt;
    this.view.remainingMs = definition.kind === "timing" ? definition.steps[0]!.durationMs : definition.durationMs;
  }
  finish(status: ActionResult["status"], reason: string, now: number) {
    if (this.view.result) return this.view.result;
    this.view.phase = "done"; this.view.held = false;
    this.view.result = { id: this.definition.id, status, reason, elapsedMs: Math.max(0, Math.round(now - this.started)), hits: this.view.hits,
      mistakes: this.view.mistakes, score: this.scores.length ? Math.round(this.scores.reduce((a, b) => a + b, 0) / this.definition.steps.length) : 0 };
    if (status === "success" && this.definition.kind !== "timing") this.view.progress = 1;
    return this.view.result;
  }
  tick(now: number): ActionView {
    const d = this.definition, v = this.view;
    if (v.result) return v;
    if (now - this.started >= d.timeoutMs) { this.finish("failed", "timeout", now); return v; }
    if (now < this.readyAt) return v;
    if (v.phase === "feedback") {
      if (now < this.feedbackUntil) return v;
      v.step++; v.progress = 0; this.roundAt = now;
    }
    v.phase = "running";
    if (d.kind === "timing") {
      const step = d.steps[v.step]!;
      v.progress = Math.min(1, Math.max(0, (now - this.roundAt) / step.durationMs));
      v.remainingMs = Math.max(0, step.durationMs - (now - this.roundAt));
      if (v.progress >= 1) this.judge(false, 0, "Too late", now);
    } else {
      const elapsed = d.kind === "hold" ? this.heldAt === null ? 0 : now - this.heldAt : now - this.readyAt;
      v.progress = Math.min(1, Math.max(0, elapsed / d.durationMs)); v.remainingMs = Math.max(0, d.durationMs - elapsed);
      if (v.progress >= 1) this.finish("success", "completed", now);
    }
    return v;
  }
  press(now: number) {
    this.tick(now);
    const d = this.definition, v = this.view;
    if (v.phase !== "running") return;
    if (d.kind === "hold") { if (this.heldAt === null) this.heldAt = now; v.held = true; return; }
    if (d.kind !== "timing") return;
    const s = d.steps[v.step]!, position = v.progress;
    const hit = position >= s.zoneStart && position <= s.zoneStart + s.zoneWidth;
    const quality = hit ? Math.max(1, 100 - Math.abs(position - s.zoneStart - s.zoneWidth / 2) / (s.zoneWidth / 2) * 50) : 0;
    this.judge(hit, quality, hit ? quality >= 90 ? "Perfect timing" : "Good timing" : position < s.zoneStart ? "Too early" : "Too late", now);
  }
  release(now: number) {
    this.tick(now);
    if (this.definition.kind !== "hold" || this.view.result || this.heldAt === null) return;
    this.heldAt = null; this.view.held = false;
    if (this.definition.release === "cancel") this.finish("cancelled", "released", now);
    else { this.view.progress = 0; this.view.remainingMs = this.definition.durationMs; this.view.feedback = "Released — hold to restart"; }
  }
  private judge(hit: boolean, quality: number, message: string, now: number) {
    const v = this.view;
    if (hit) { v.hits++; this.scores.push(quality); } else v.mistakes++;
    v.feedback = message;
    if (v.mistakes > this.definition.maxMistakes) this.finish("failed", message === "Too early" ? "too_early" : "missed", now);
    else if (v.step + 1 >= this.definition.steps.length) this.finish("success", "completed", now);
    else { v.phase = "feedback"; this.feedbackUntil = now + 450; }
  }
}
