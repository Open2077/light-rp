// op77_loadscreen page: one script for both surfaces.
//   <body data-mode="connect">  the server loadscreen the Open77 shell mounts while
//                               the world streams during the join ("server" and
//                               "progress" events, sent by the shell).
//   <body data-mode="ingame">   the zone cover of client/main.lua ("cover:*" events).
// Opened in a plain browser (no window.Open77) it plays a demo so it can be previewed:
//   connect.html                 simulated 28 s load, looping
//   index.html?demo=1&title=Kabuki%20Studio&subtitle=Private%20residence&zone=Watson
(function () {
  "use strict";
  var body = document.body;
  var mode = body.getAttribute("data-mode") === "ingame" ? "ingame" : "connect";
  var host = window.Open77;
  var params = new URLSearchParams(window.location.search);

  var TIPS = [
    "Use /me to describe an action and /do to describe the scene around you.",
    "Your character does not know the server rules. You do.",
    "The /ooc channel is for technical questions only. Everything else is played in character.",
    "Store your vehicle in a garage. A car left on the street ends up at the impound.",
    "Voice carries 15 metres. Move closer to whisper.",
    "Fear of death applies at all times. A drawn weapon is a drawn weapon.",
    "Press F1 to open your player menu: identity, job, homes and vehicles."
  ];
  var STAGES = {
    connect: [[0, "HANDSHAKE // GATEWAY"], [12, "AUTH // SESSION KEY"], [30, "STREAMING SECTOR 04"],
      [55, "SYNC // WORLD STATE"], [75, "COMPILING SHADERS"], [92, "SPAWN // STANDBY"]],
    zone: [[0, "ROUTING // DESTINATION"], [18, "STREAMING DISTRICT"], [55, "SYNC // WORLD STATE"],
      [85, "ARRIVAL // STANDBY"]]
  };
  var SEGMENTS = 60;

  // ------------------------------------------------------------------ markup
  var root = document.createElement("div");
  root.className = "ls-root";
  root.innerHTML =
    '<div class="ls-stage" id="ls-stage">' +
      '<img class="ls-sky" src="./img/skyline.webp" alt="">' +
      '<div class="ls-scrim"></div><div class="ls-scan"></div><div class="ls-refresh"></div>' +
      '<div class="ls-caption ls-caption--1"><b>Night City<br>More Stories</b><i></i></div>' +
      '<div class="ls-caption ls-caption--2"><b>Play<br>Meet<br>Build<br>Belong</b><i></i></div>' +
      '<div class="ls-caption ls-caption--3"><b>Same City<br>Different<br>People</b><i></i></div>' +
      '<div class="ls-caption ls-caption--4"><b>A Brighter<br>Night<br>Together</b><i></i></div>' +
      '<div class="ls-brand">' +
        '<img class="ls-logo" src="./img/logo-77.png" alt="//77">' +
        '<div class="ls-name"><i></i><b>Light RP</b><i></i></div>' +
        '<div class="ls-tagline">Roleplay // Casual // Real People</div>' +
      '</div>' +
      '<div class="ls-progress">' +
        '<div class="ls-dest"><span>Destination //</span><b id="ls-title"></b><em id="ls-subtitle"></em></div>' +
        '<div class="ls-row">' +
          '<div class="ls-status"><span class="dim">Loading</span><span class="acc" id="ls-stagename"></span><span class="ls-cursor"></span></div>' +
          '<div class="ls-pct"><b id="ls-pct">000</b><span>%</span></div>' +
        '</div>' +
        '<div class="ls-bar"><div class="ls-segs" id="ls-segs"></div></div>' +
        '<div class="ls-tip"><span>Tip //</span><b id="ls-tip"></b></div>' +
      '</div>' +
      '<div class="ls-log" id="ls-log"></div>' +
      '<div class="ls-corner"><div class="ls-clock" id="ls-clock"></div><div class="ls-sector" id="ls-sector">Night City // Sector 04</div></div>' +
    '</div>';
  body.appendChild(root);

  var $ = function (id) { return document.getElementById(id); };
  var stageEl = $("ls-stage"), pctEl = $("ls-pct"), stageNameEl = $("ls-stagename"), tipEl = $("ls-tip"),
    logEl = $("ls-log"), clockEl = $("ls-clock"), sectorEl = $("ls-sector"), titleEl = $("ls-title"),
    subtitleEl = $("ls-subtitle"), segsEl = $("ls-segs");
  var segs = [];
  for (var i = 0; i < SEGMENTS; i++) { var s = document.createElement("span"); segsEl.appendChild(s); segs.push(s); }

  // ------------------------------------------------------------------ scale
  function fit() {
    var w = window.innerWidth || 1920, h = window.innerHeight || 1080;
    stageEl.style.setProperty("--ls-scale", String(Math.min(w / 1920, h / 1080)));
  }
  window.addEventListener("resize", fit);
  fit();

  // ------------------------------------------------------------------ state
  var stages = mode === "ingame" ? STAGES.zone : STAGES.connect;
  var shown = 0;          // what the bar draws (0..100, never goes back inside one load)
  var target = 0;         // what we are told (0..100)
  var lastStage = null, log = [], drawnPct = -1, drawnSegs = -1;
  var sim = null;         // { start, tau, cap } simulated fill while nothing real arrives
  var external = false;   // a real value arrived for this load
  var tipIndex = Math.floor(Math.random() * TIPS.length), tipTimer = null;

  function pad(n) { return String(n).padStart(2, "0"); }
  function clock() { var d = new Date(); return pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds()); }
  function stageFor(p) { var name = stages[0][1]; for (var k = 0; k < stages.length; k++) if (p >= stages[k][0]) name = stages[k][1]; return name; }

  function renderLog() {
    var html = "";
    var lines = log.slice(-5);
    for (var k = 0; k < lines.length; k++) {
      html += "<div><span>" + lines[k].t + "</span><span></span></div>";
    }
    logEl.innerHTML = html;
    var rows = logEl.children;
    for (var j = 0; j < rows.length; j++) rows[j].lastChild.textContent = lines[j].msg;
  }

  function showTip(next) {
    if (next) tipIndex = (tipIndex + 1) % TIPS.length;
    tipEl.classList.remove("in");
    void tipEl.offsetWidth; // restart the wipe
    tipEl.textContent = TIPS[tipIndex];
    tipEl.classList.add("in");
  }
  function startTips() {
    if (tipTimer) clearInterval(tipTimer);
    showTip(false);
    tipTimer = setInterval(function () { showTip(true); }, 6500);
  }

  function resetLoad() {
    shown = 0; target = 0; external = false; lastStage = null; log = []; drawnPct = -1; drawnSegs = -1;
    renderLog();
  }

  function draw() {
    var pct = Math.max(0, Math.min(100, Math.round(shown)));
    if (pct !== drawnPct) {
      drawnPct = pct;
      pctEl.textContent = String(pct).padStart(3, "0");
      var on = 0;
      for (var k = 0; k < SEGMENTS; k++) if ((k + 1) / SEGMENTS <= pct / 100) on = k + 1;
      if (on !== drawnSegs) {
        for (var n = 0; n < SEGMENTS; n++) segs[n].className = n < on ? "on" : "";
        drawnSegs = on;
      }
    }
    var stage = stageFor(pct);
    if (stage !== lastStage) {
      var t = clock();
      if (lastStage) log.push({ t: t, msg: lastStage + " // OK" });
      log.push({ t: t, msg: stage });
      log = log.slice(-6);
      lastStage = stage;
      stageNameEl.textContent = stage;
      renderLog();
    }
  }

  function tick() {
    clockEl.textContent = clock();
    if (sim && !external) {
      var el = performance.now() - sim.start;
      if (sim.loop) {
        // the design's preview curve: 0 -> 100 over `dur`, hold, restart
        var u = Math.min(1, el / sim.dur);
        target = 100 * (1 - Math.pow(1 - u, 1.6));
        if (u >= 1 && el > sim.dur + 2800) { sim.start = performance.now(); resetLoad(); return; }
      } else {
        target = Math.max(target, sim.cap * (1 - Math.exp(-el / sim.tau)));
      }
    }
    // a finished load runs to 100 % quickly: the cover leaves ~650 ms later
    var done = target >= 100;
    if (target > shown) shown = Math.min(target, shown + Math.max(done ? 3 : 0.6, (target - shown) * (done ? 0.4 : 0.22)));
    draw();
  }
  setInterval(tick, 100);

  function setReal(fraction) {
    var f = Number(fraction);
    if (!isFinite(f) || f < 0) return; // indeterminate: keep the estimate running
    external = true;
    target = Math.max(target, Math.min(100, f * 100));
  }
  // The design's hook for a game client: window.o77SetProgress(0..100).
  window.o77SetProgress = function (p) { setReal(Number(p) / 100); };

  // ------------------------------------------------------------------ connect mode
  if (mode === "connect") {
    startTips();
    resetLoad();
    draw();
    if (host && typeof host.on === "function") {
      // The shell sends an estimate then the engine's real fill, 0..1.
      try { host.on("progress", function (p) { if (p) setReal(p.fraction); }); } catch (e) { /* ignore */ }
      try { host.on("server", function () { /* the mark is the server identity */ }); } catch (e) { /* ignore */ }
      try { host.ready(); } catch (e) { /* ignore */ }
    } else {
      sim = { start: performance.now(), dur: 28000, loop: true };
    }
    return;
  }

  // ------------------------------------------------------------------ in-game cover
  var hideTimer = null, current = null;

  function text(v, max) { return typeof v === "string" ? v.slice(0, max || 80) : ""; }

  function show(p) {
    p = p || {};
    if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
    var fresh = !body.classList.contains("ls-shown") || body.classList.contains("ls-leaving");
    current = p;
    var title = text(p.title, 64), subtitle = text(p.subtitle, 64);
    titleEl.textContent = title;
    subtitleEl.textContent = subtitle;
    body.classList.toggle("ls-has-dest", title !== "");
    sectorEl.textContent = "Night City // " + (text(p.zone, 40) || "Sector 04");
    if (fresh) {
      resetLoad();
      var expected = Math.max(1500, Math.min(60000, Number(p.expectedMs) || 7000));
      sim = { start: performance.now(), tau: expected / 2.3, cap: 92 };
      body.classList.remove("ls-leaving");
      body.classList.add("ls-shown");
      startTips();
      draw();
    }
  }
  function complete() { external = true; target = 100; }
  function hide() {
    if (!body.classList.contains("ls-shown") || body.classList.contains("ls-leaving")) return;
    complete();
    body.classList.add("ls-leaving");
    hideTimer = setTimeout(function () {
      hideTimer = null;
      body.classList.remove("ls-shown", "ls-leaving", "ls-has-dest");
      if (tipTimer) { clearInterval(tipTimer); tipTimer = null; }
      sim = null; current = null;
      if (host && typeof host.emit === "function") { try { host.emit("cover:hidden", {}); } catch (e) { /* ignore */ } }
    }, 560);
  }

  if (host && typeof host.on === "function") {
    try {
      host.on("cover:show", show);
      host.on("cover:progress", function (p) { if (p && current) setReal(p.value); });
      host.on("cover:complete", complete);
      host.on("cover:hide", hide);
      host.ready();
    } catch (e) { /* ignore */ }
  } else if (params.get("demo")) {
    show({ title: params.get("title") || "Kabuki Studio", subtitle: params.get("subtitle") || "Private residence",
      zone: params.get("zone") || "Watson", expectedMs: Number(params.get("ms")) || 7000 });
    var at = Number(params.get("at"));
    if (isFinite(at) && at > 0) { external = true; target = shown = at; draw(); }
  }
  window.__op77Loadscreen = { show: show, hide: hide, complete: complete, progress: setReal };
})();
