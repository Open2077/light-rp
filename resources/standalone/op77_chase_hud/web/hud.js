/* NCPD Chase overlay. One feed, `chase:hud` { chase, queue }, pushed by client/main.lua
   whenever op77_chase sends something. The page only draws: clocks are anchored on
   receipt (remainingMs) and counted down locally between pushes. Text goes through
   textContent only. Browser preview: index.html?demo=active|countdown|intermission|resolved|queue */
(() => {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const el = {
    hud: $("hud"), band: $("band"), roleCell: $("roleCell"), role: $("role"), clockLabel: $("clockLabel"), clock: $("clock"),
    roundLabel: $("roundLabel"), score: $("score"), sepCell: $("sepCell"), sep: $("sep"),
    meter: $("meter"), meterLabel: $("meterLabel"), meterPct: $("meterPct"), fill: $("fill"), hint: $("hint"),
    card: $("card"), cardKicker: $("cardKicker"), cardTitle: $("cardTitle"), cardSub: $("cardSub"),
    queue: $("queue"), queueText: $("queueText"),
  };

  // Same wording as server/rules.lua (R.LINES), from one side.
  const LINES = {
    runner_escaped: ["You lost him.", "He got away."],
    runner_busted: ["Busted.", "You were busted."],
    runner_down: ["Target down.", "You went down."],
    cop_down: ["The cop is down.", "You went down."],
    time_expired: ["You survived the clock.", "Out of time."],
    runner_timed_out: ["Time's up - you never lost him.", "Time's up - you never shook him."],
    opponent_left: ["Your opponent left.", "You left the chase."],
    aborted: ["Called off.", "Called off."],
  };
  const line = (outcome, won) => { const l = LINES[outcome]; return l ? (won ? l[0] : l[1]) : (won ? "You win." : "Round over."); };

  let chase = { state: "idle" }, queue = { queued: false };
  let anchorMs = 0, anchorRemaining = null, timer = 0;

  const num = (v) => (typeof v === "number" && isFinite(v) ? v : null);
  const show = (node, on) => { node.hidden = !on; };
  const text = (node, value) => { const s = value == null ? "" : String(value); if (node.textContent !== s) node.textContent = s; };
  const pct = (v) => Math.max(0, Math.min(100, Math.round((num(v) || 0) * 100)));
  const remaining = () => (anchorRemaining == null ? null : Math.max(0, anchorRemaining - (performance.now() - anchorMs)));
  function clock(ms) {
    if (ms == null) return "-";
    const s = Math.ceil(ms / 1000), m = Math.floor(s / 60);
    return `${m}:${String(s % 60).padStart(2, "0")}`;
  }
  const secs = (ms) => (ms == null ? "" : `${Math.ceil(ms / 1000)}s`);

  function setMeter(kind, value, classes, label) {
    show(el.meter, true);
    el.meter.className = `meter ${kind} ${classes.join(" ")}`.trim();
    text(el.meterLabel, label);
    text(el.meterPct, `${pct(value)}%`);
    el.fill.style.width = `${pct(value)}%`;
  }

  function hint(message, alarm) {
    show(el.hint, !!message);
    el.hint.className = alarm ? "hint alarm" : "hint";
    text(el.hint, message);
  }

  function card(kicker, title, sub, tone) {
    show(el.card, true);
    text(el.cardKicker, kicker);
    text(el.cardTitle, title);
    el.cardTitle.className = tone ? `title ${tone}` : "title";
    text(el.cardSub, sub);
  }

  function roundText(c) {
    const n = num(c.round) || 0, total = num(c.roundCount) || 1;
    return c.decider ? "Decider" : `Round ${Math.max(1, n)}/${total}`;
  }

  function render() {
    const c = chase || {}, q = queue || {};
    const state = c.state || "idle";
    const inMatch = state !== "idle";
    show(el.queue, !inMatch && q.queued === true);
    if (!inMatch && q.queued === true) {
      const pos = num(q.position), total = num(q.total);
      const mode = q.mode === "foot" ? "on foot" : (q.mode === "vehicle" ? "by car" : "car or foot");
      text(el.queueText, pos ? `Queued ${pos}/${total || pos} - ${mode}` : `Queued - ${mode}`);
    }
    show(el.hud, inMatch);
    if (!inMatch) { stopTimer(); return; }

    const role = c.role === "cop" ? "cop" : (c.role === "runner" ? "runner" : "");
    el.roleCell.dataset.role = role;
    text(el.role, role ? role.toUpperCase() : "-");
    text(el.roundLabel, roundText(c));
    text(el.score, `${num(c.scoreSelf) || 0} - ${num(c.scoreOpponent) || 0}`);
    const left = remaining();

    show(el.meter, false); hint(""); show(el.card, false); show(el.sepCell, false);
    el.clock.className = "value";

    if (state === "placing") {
      text(el.clockLabel, "Time"); text(el.clock, "-");
      card(roundText(c), "Stand by", c.opponentName ? `Against ${c.opponentName}` : "Moving to the chase area");
    } else if (state === "countdown") {
      text(el.clockLabel, "Start"); text(el.clock, clock(left));
      const s = left == null ? "" : String(Math.max(1, Math.ceil(left / 1000)));
      const sub = role === "runner" ? `You run. Hold a ${Math.round(num(c.escapeDistance) || 0)} m gap to escape.`
        : (role === "cop" ? `You hunt. Stay within ${Math.round(num(c.bustDistance) || 0)} m to make the arrest.` : "");
      card(`${roundText(c)}${c.opponentName ? ` - vs ${c.opponentName}` : ""}`, s, sub);
      if (c.boarding) hint(c.boarding.metres != null ? `Your car is ${c.boarding.metres} m away - driver door on the left` : "Get in your car");
    } else if (state === "active") {
      text(el.clockLabel, c.overtime ? "Overtime" : "Time");
      text(el.clock, c.overtime ? "OT" : clock(left));
      if (c.overtime) el.clock.className = "value overtime";
      if (role === "runner" && num(c.separation) != null) {
        show(el.sepCell, true);
        const sep = num(c.separation);
        text(el.sep, `${Math.round(sep)} m`);
        el.sep.className = sep <= (num(c.bustDistance) || 0) ? "value close" : (sep >= (num(c.escapeDistance) || Infinity) ? "value safe" : "value");
      }
      const escape = num(c.escapeProgress);
      if (escape != null) {
        setMeter("escape", escape, [role === "runner" ? "mine" : "theirs", c.escapeFilling ? "" : "recovering"],
          role === "runner" ? "Escaping" : "He is getting away");
      } else if (c.copReleased && num(c.bustMeter) != null) {
        const v = num(c.bustMeter);
        // Closing = filling; in range but not closing = slow drain; out of range = drain.
        const classes = [];
        if (!c.bustClosing) classes.push(c.bustContact ? "contact" : "draining");
        if (v >= 0.75) classes.push("critical");
        setMeter("bust", v, classes, role === "cop" ? "Arrest" : "Being arrested");
      }
      if (num(c.stalledMs) != null) hint(`Crash - engine stalled ${secs(num(c.stalledMs))}`, true);
      else if (c.boarding) hint(c.boarding.metres != null ? `Your car is ${c.boarding.metres} m away - get in` : "Get in your car");
      else if (!c.copReleased) hint(role === "cop" ? "Hold - the runner has a head start" : "Head start - go");
      else if (c.bustClosing) hint(role === "cop" ? "Arrest in progress - stay on him" : "You are being cuffed - move!", role === "runner");
      else if (c.bustContact) hint(role === "cop" ? "In range - he has to stop for the cuffs" : "He is on you - keep moving", role === "runner");
    } else if (state === "intermission") {
      text(el.clockLabel, "Next"); text(el.clock, clock(left));
      const next = num(c.nextRound);
      card(`${roundText(c)} over`, line(c.outcome, !!c.won),
        `${c.nextIsDecider ? "Decider" : `Round ${next || ""}`} in ${secs(left)} - roles swap`, c.won ? "win" : "loss");
    } else if (state === "resolved") {
      text(el.clockLabel, "Back in"); text(el.clock, clock(left));
      const result = c.matchResult;
      const title = result === "void" ? "Called off" : (result === "draw" ? "Draw" : (result === "win" ? "Match won" : "Match lost"));
      const tone = result === "win" ? "win" : (result === "loss" ? "loss" : "");
      const sub = result === "void" ? "Nothing counts." : `${line(c.outcome, !!c.won)}  ${num(c.scoreSelf) || 0} - ${num(c.scoreOpponent) || 0}`;
      card("NCPD Chase", title, sub, tone);
    }
    startTimer();
  }

  // Ten redraws a second while a clock runs; nothing at all otherwise.
  function startTimer() { if (!timer) timer = setInterval(render, 100); }
  function stopTimer() { if (timer) { clearInterval(timer); timer = 0; } }

  function receive(msg) {
    if (!msg || typeof msg !== "object") return;
    if (msg.chase && typeof msg.chase === "object") {
      chase = msg.chase;
      anchorRemaining = num(chase.remainingMs);
      anchorMs = performance.now();
    }
    if (msg.queue && typeof msg.queue === "object") queue = msg.queue;
    render();
  }

  const bridge = typeof window.Open77 === "object" && window.Open77 && typeof window.Open77.on === "function" ? window.Open77 : null;
  if (bridge) {
    bridge.on("chase:hud", receive);
    try { bridge.ready(); } catch (_) { /* older bridge */ }
    try { bridge.emit("chase:ready", {}); } catch (_) { /* not in game */ }
  } else {
    const demo = new URLSearchParams(location.search).get("demo") || "active";
    const base = { role: "runner", opponentName: "Jackie", round: 1, roundCount: 2, scoreSelf: 0, scoreOpponent: 1,
      bustDistance: 8, escapeDistance: 100 };
    const samples = {
      queue: { chase: { state: "idle" }, queue: { queued: true, position: 1, total: 1, mode: "vehicle" } },
      countdown: { chase: Object.assign({}, base, { state: "countdown", remainingMs: 7000, boarding: { metres: 3 } }) },
      active: { chase: Object.assign({}, base, { state: "active", remainingMs: 143000, copReleased: true, bustMeter: 0.62,
        bustClosing: true, separation: 6.4 }) },
      intermission: { chase: Object.assign({}, base, { state: "intermission", remainingMs: 8000, outcome: "runner_escaped", won: true, nextRound: 2 }) },
      resolved: { chase: Object.assign({}, base, { state: "resolved", remainingMs: 5000, outcome: "runner_busted", won: false,
        matchResult: "loss" }) },
    };
    receive(samples[demo] || samples.active);
  }
})();
