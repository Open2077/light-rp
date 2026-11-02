// op77_race page. Receives race:state / race:pulse / race:clear / race:menu /
// race:panel / race:editor / race:keys from client/main.lua and draws the HUD, the
// countdown, the results, the /race panel and the staff editor box. Clocks run
// locally from the anchors the server sends (elapsedMs / remainingMs at receipt).
(function () {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const bridge = typeof window.Open77 === "object" && window.Open77 && typeof window.Open77.on === "function" ? window.Open77 : null;
  const emit = (name, payload) => { if (bridge) { try { bridge.emit(name, payload || {}); } catch (_) { /* not in game */ } } };

  const MODE = { trial: "TIME TRIAL", grid: "STREET RACE", foot: "ROOFTOP RACE" };
  let state = null, receivedAt = 0, menu = null, keys = {}, editor = null, panelOpen = false;
  let selectedCourse = null, bannerUntil = 0, raf = 0;

  function fmt(ms) {
    if (ms === null || ms === undefined || !isFinite(ms)) return "-";
    ms = Math.max(0, Math.floor(ms));
    const h = Math.floor(ms / 3600000), m = Math.floor(ms / 60000) % 60, s = Math.floor(ms / 1000) % 60, r = ms % 1000;
    const pad = (v, n) => String(v).padStart(n, "0");
    return h > 0 ? `${h}:${pad(m, 2)}:${pad(s, 2)}.${pad(r, 3)}` : `${m}:${pad(s, 2)}.${pad(r, 3)}`;
  }
  function esc(text) {
    return String(text === undefined || text === null ? "" : text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function list(value) {
    if (Array.isArray(value)) return value;
    if (typeof value === "string") { try { const parsed = JSON.parse(value); return Array.isArray(parsed) ? parsed : []; } catch (_) { return []; } }
    return [];
  }
  function kbd(name) { return keys[name] ? `<kbd>${esc(keys[name])}</kbd>` : ""; }
  function ordinal(n) { const s = ["th", "st", "nd", "rd"], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); }

  // ------------------------------------------------------------- HUD --
  function elapsed(now) {
    if (!state) return 0;
    if (state.state === "finished" && state.timeMs) return state.timeMs;
    if (state.phase === "active" && state.state === "racing") return (state.elapsedMs || 0) + (now - receivedAt);
    return state.elapsedMs || 0;
  }
  function remaining(now) { return state ? Math.max(0, (state.remainingMs || 0) - (now - receivedAt)) : 0; }

  function banner(text, small, pop) {
    const el = $("banner");
    if (!text) { el.hidden = true; return; }
    el.textContent = text;
    el.className = "banner" + (small ? " small" : "") + (pop ? " pop" : "");
    el.hidden = false;
  }

  function renderHud() {
    const hud = $("hud");
    const racing = state && (state.state === "loading" || state.state === "countdown" || state.state === "racing" || state.state === "finished");
    hud.hidden = !(state && racing && state.phase !== "results");
    if (hud.hidden) return;
    $("hudMode").textContent = MODE[state.mode] || "RACE";
    $("hudCourse").textContent = state.course ? state.course.name : "";
    $("hudCheckpoint").textContent = `${state.completed || 0}/${state.progressTotal || 0}`;
    $("hudLap").textContent = `${state.lap || 1}/${state.laps || 1}`;
    $("hudBestLap").textContent = fmt(state.bestLapMs);
    const rows = list(state.rows);
    $("hudPlaceBox").hidden = rows.length < 2;
    let place = state.place;
    if (!place && rows.length > 1) {
      const me = rows.find((r) => r.self);
      place = me ? me.rank : null;
    }
    $("hudPlace").textContent = place ? `${place}/${rows.length}` : "-";
    const trial = state.mode === "trial";
    $("hudRecords").hidden = !trial;
    if (trial) {
      $("hudPb").textContent = fmt(state.personalBestMs);
      $("hudRecord").textContent = state.recordMs ? `${fmt(state.recordMs)}` : "-";
    }
    $("hudRows").innerHTML = rows.length > 1 ? rows.map((r) => {
      const out = r.state === "dnf" || r.state === "left";
      const detail = r.state === "finished" ? fmt(r.timeMs) : out ? "OUT" : `${r.progress || 0}`;
      return `<li class="${r.self ? "me" : ""}"><span class="pos">${r.rank}</span><span class="name">${esc(r.name)}</span><span class="${out ? "out" : ""}">${esc(detail)}</span></li>`;
    }).join("") : "";
    const hints = [];
    if (state.canRestart) hints.push(`${kbd("restart")} restart`);
    if (state.canRespawn) hints.push(`${kbd("respawn")} last checkpoint`);
    hints.push("/race.leave to quit");
    $("hudKeys").innerHTML = hints.join(" ");
  }

  function renderResults() {
    const card = $("results");
    const show = state && state.phase === "results";
    card.hidden = !show;
    if (!show) return;
    const finished = state.state === "finished";
    $("resultTitle").textContent = finished ? (state.place && list(state.rows).length > 1 ? `${ordinal(state.place)} place` : "Finished") : "Did not finish";
    $("resultTime").textContent = finished ? fmt(state.timeMs) : "DNF";
    const badges = [];
    const outcome = state.outcome || {};
    if (outcome.courseRecord) badges.push('<span class="good">COURSE RECORD</span>');
    else if (outcome.personalBest) badges.push('<span class="good">PERSONAL BEST</span>');
    if (outcome.previousBestMs && outcome.personalBest) badges.push(`<span>was ${fmt(outcome.previousBestMs)}</span>`);
    if (outcome.rank) badges.push(`<span>#${outcome.rank} on the board</span>`);
    if (state.bestLapMs && state.laps > 1) badges.push(`<span>best lap ${fmt(state.bestLapMs)}</span>`);
    $("resultBadges").innerHTML = badges.join("");
    const rows = list(state.rows);
    $("resultRows").innerHTML = rows.length > 1 ? rows.map((r) => `<li><span class="pos">${r.state === "finished" ? r.rank : "-"}</span><span class="name">${esc(r.name)}</span><span>${r.state === "finished" ? fmt(r.timeMs) : "DNF"}</span></li>`).join("") : "";
    resultNote();
  }
  function resultNote() {
    if (!state || state.phase !== "results") return;
    const seconds = Math.ceil(remaining(performance.now()) / 1000);
    const restart = state.canRestart ? ` Press ${keys.restart || "the restart key"} to go again.` : "";
    $("resultNote").textContent = `Back to Light RP in ${seconds} s.${restart}`;
  }

  function tick() {
    raf = 0;
    const now = performance.now();
    if (state) {
      if (state.phase === "active" || state.phase === "results" || state.state === "finished") $("hudClock").textContent = fmt(elapsed(now));
      if (state.phase === "loading") { $("hudClock").textContent = fmt(0); banner("GET READY", true); }
      else if (state.phase === "countdown") {
        const left = remaining(now);
        banner(left > 0 ? String(Math.ceil(left / 1000)) : "GO", false);
      } else if (now > bannerUntil) banner(null);
      if (state.phase === "results") resultNote();
      raf = requestAnimationFrame(tick);
    } else if (now < bannerUntil) {
      raf = requestAnimationFrame(tick);
    } else banner(null);
  }
  function loop() { if (!raf) raf = requestAnimationFrame(tick); }

  function onState(p) {
    if (!p || typeof p !== "object") return;
    state = p;
    receivedAt = performance.now();
    const rows = list(p.rows);
    // Mark our own row (rows carry player ids; the payload says which one is ours).
    rows.forEach((r) => { r.self = r.id === p.self; });
    state.rows = rows;
    renderHud();
    renderResults();
    loop();
  }
  function onPulse(p) {
    if (!p) return;
    const now = performance.now();
    if (p.kind === "go") { banner("GO", false, true); bannerUntil = now + 1200; }
    else if (p.kind === "lap") { banner(`LAP ${p.lap}/${p.laps}`, true, true); bannerUntil = now + 1500; }
    else if (p.kind === "checkpoint") { banner(fmt(p.splitMs), true, true); bannerUntil = now + 900; }
    else if (p.kind === "finish") { banner("FINISH", false, true); bannerUntil = now + 2000; }
    loop();
  }
  function onClear() {
    state = null;
    $("hud").hidden = true;
    $("results").hidden = true;
    banner(null);
  }

  // ------------------------------------------------------------- panel --
  function renderPanel() {
    $("panel").hidden = !panelOpen;
    if (!panelOpen) return;
    if (!menu) { $("activities").innerHTML = '<p class="muted">Loading...</p>'; return; }
    $("panelNote").textContent = menu.available ? "Loaner cars only. No weapons, no implants handed out. Results earn reputation, never money."
      : "Races are not available right now.";
    $("activities").innerHTML = (menu.activities || []).map((a) => {
      let meta;
      if (a.key === "trial") meta = `${a.courses} courses${a.players ? ` · ${a.players} on the clock` : ""}`;
      else if (a.windowMs !== undefined && a.windowMs !== null) meta = `${a.queued} queued · starting in ${Math.ceil(a.windowMs / 1000)} s`;
      else meta = `${a.queued}/${a.minPlayers} queued${a.running ? ` · ${a.running} running` : ""}`;
      const queuedHere = menu.queued === a.key;
      const label = a.key === "trial" ? "Start" : queuedHere ? "Queued" : "Join queue";
      const disabled = !menu.available || menu.racing || queuedHere || a.courses === 0;
      return `<div class="activity"><h4>${esc(a.label)}</h4><p>${esc(a.description)}</p><div class="meta">${esc(meta)}</div>` +
        `<button class="primary" data-join="${esc(a.key)}" ${disabled ? "disabled" : ""}>${label}</button></div>`;
    }).join("");
    const courses = menu.courses || [];
    if (!selectedCourse || !courses.some((c) => c.id === selectedCourse)) selectedCourse = courses.length ? courses[0].id : null;
    $("courses").innerHTML = courses.map((c) => {
      const top = list(c.top).map((t) => `<li>${esc(t.name)} <b>${fmt(t.timeMs)}</b></li>`).join("");
      const kind = c.onFoot ? "On foot" : esc(c.vehicleLabel || c.vehicle);
      return `<div class="course${c.id === selectedCourse ? " selected" : ""}" data-course="${esc(c.id)}"><h5>${esc(c.name)}</h5>` +
        `<div class="meta">${kind} · ${c.checkpointCount} checkpoints · ${c.laps} lap${c.laps > 1 ? "s" : ""} · ${(c.metres / 1000).toFixed(1)} km</div>` +
        (top ? `<ol>${top}</ol>` : '<div class="meta">No time yet. Set the first one.</div>') +
        (c.bestMs ? `<div class="pb">Your best ${fmt(c.bestMs)}${c.rank ? ` (#${c.rank})` : ""}</div>` : "") + "</div>";
    }).join("");
    $("startTrial").disabled = !menu.available || menu.racing || !selectedCourse;
    $("leaveButton").hidden = !(menu.racing || menu.queued);
    $("leaveButton").textContent = menu.racing ? "Leave race" : "Leave queue";
  }

  document.addEventListener("click", (event) => {
    const join = event.target.closest("[data-join]");
    if (join && !join.disabled) {
      const activity = join.getAttribute("data-join");
      emit("race:join", { activity, course: activity === "trial" ? selectedCourse : undefined });
      return;
    }
    const course = event.target.closest("[data-course]");
    if (course) { selectedCourse = course.getAttribute("data-course"); renderPanel(); }
  });
  $("panelClose").addEventListener("click", () => emit("race:close"));
  $("startTrial").addEventListener("click", () => { if (selectedCourse) emit("race:join", { activity: "trial", course: selectedCourse }); });
  $("leaveButton").addEventListener("click", () => emit("race:leave"));
  document.addEventListener("keydown", (event) => { if (event.key === "Escape" && panelOpen) emit("race:close"); });
  // The queue countdown in the panel moves without a server push.
  setInterval(() => {
    if (!panelOpen || !menu) return;
    let moved = false;
    (menu.activities || []).forEach((a) => { if (typeof a.windowMs === "number") { a.windowMs = Math.max(0, a.windowMs - 1000); moved = true; } });
    if (moved) renderPanel();
  }, 1000);

  // ------------------------------------------------------------- editor --
  function renderEditor() {
    const box = $("editor");
    box.hidden = !editor || editor.closed;
    if (box.hidden) return;
    const d = editor.draft || {};
    $("editorName").textContent = d.name || "Course";
    const vehicle = (editor.vehicles || []).find((v) => v.id === d.vehicle);
    $("editorStats").innerHTML = [
      ["Id", d.id || "(new)"], ["Type", `${d.type} · ${d.laps} lap(s)`], ["Vehicle", vehicle ? vehicle.label : d.vehicle],
      ["Start", d.start ? "set" : "missing"], ["Grid", (d.grid || []).length], ["Checkpoints", (d.checkpoints || []).length],
      ["Radius", `${d.checkpointRadius} m`],
    ].map(([k, v]) => `<span>${esc(k)}</span><b>${esc(v)}</b>`).join("");
    $("editorMessage").textContent = editor.message || "";
    $("editorKeys").innerHTML = `${kbd("editor.start")} start ${kbd("editor.checkpoint")} checkpoint ${kbd("editor.grid")} grid ${kbd("editor.undo")} undo · /race.editor save`;
  }

  // ------------------------------------------------------------- bridge --
  if (bridge) {
    bridge.on("race:state", onState);
    bridge.on("race:pulse", onPulse);
    bridge.on("race:clear", onClear);
    bridge.on("race:menu", (p) => { try { menu = JSON.parse(p && p.json); } catch (_) { menu = null; } renderPanel(); });
    bridge.on("race:panel", (p) => { panelOpen = !!(p && p.open); renderPanel(); });
    bridge.on("race:keys", (p) => { keys = p || {}; renderHud(); renderEditor(); });
    bridge.on("race:editor", (p) => { editor = p; renderEditor(); });
    bridge.on("race:config", () => {});
    try { bridge.ready(); } catch (_) { /* older bridge */ }
    emit("race:ready");
  }
})();
