(() => {
  "use strict";

  // Fed by client/main.lua:
  //   speedo:config  the sanitized config (shared/speedo.lua Speedo.pageConfig)
  //   speedo:show    { name, instant? }   the player sat down: enter animation
  //   speedo:hide    {}                   the player left: exit animation
  //   speedo:data    { speed, kph, gear, rpm?, handbrake, abs, tcs, lights, engine,
  //                    health, damaged, tires, brokenLights, reversing, fuel? }
  // The page smooths the numbers between samples (20 Hz) and draws at the surface's rate.
  // Without the game (a browser), URL parameters drive a preview: see preview() below.
  const W = 420, H = 232;
  const HOLO_GPS = { width: 780, height: 320, gap: 16 }; // op77_map3d's holo surface, bottom centre
  const RPM_CELLS = 30, RPM_RED = 0.86, GAUGE_CELLS = 10;
  const ENTER_MS = 640, EXIT_MS = 380, SELFTEST_MS = 520;

  const $ = (id) => document.getElementById(id);
  const stage = $("stage"), rig = $("rig"), holo = $("holo");
  const nameEl = $("name"), unitEl = $("unit"), gearEl = $("gear"), gearValue = $("gearValue");
  const tagHbk = $("tagHbk"), tagAbs = $("tagAbs"), tagTcs = $("tagTcs");
  const icoLights = $("icoLights"), icoEngine = $("icoEngine"), icoTires = $("icoTires"), tireCount = $("tireCount");
  const barFill = $("barFill"), barHead = $("barHead"), barTicks = $("barTicks");
  const rpmBox = document.querySelector(".rpm");
  const fuelGauge = $("fuelGauge"), condGauge = $("condGauge");

  let cfg = {
    units: "kph", unitLabel: "KPH", speedMax: 240, showVehicleName: true, leadingZeros: "dim",
    layout: { right: 36, bottom: 146, offsetX: 0, offsetY: 0, scale: 0.6, tilt: true, tiltX: 8, tiltY: -16, avoidHoloGps: true, minScale: 0.45 },
    theme: { accent: "#FFCC00", core: "#FFF7DA", gear: "#FFCC00", warn: "#FF3B3B", cool: "#7FD8FF", glow: 1, opacity: 1, scanlines: true, flicker: true },
    shake: { enabled: true, fromKph: 130, fullKph: 260, amplitude: 1.6 },
  };

  // ── seven-segment digits ──
  // segments a b c d e f g; each digit 64 x 112, slanted, advance 82.
  const SEG = { 0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg", 9: "abcdfg", "-": "g", " ": "" };
  const DW = 64, DH = 112, T = 11, GAP = 2.2, ADV = 82;
  function hSeg(cy, x0, x1) { const h = T / 2; return [[x0, cy], [x0 + h, cy - h], [x1 - h, cy - h], [x1, cy], [x1 - h, cy + h], [x0 + h, cy + h]]; }
  function vSeg(cx, y0, y1) { const h = T / 2; return [[cx, y0], [cx + h, y0 + h], [cx + h, y1 - h], [cx, y1], [cx - h, y1 - h], [cx - h, y0 + h]]; }
  const SEGMENTS = {
    a: hSeg(T / 2, T / 2 + GAP, DW - T / 2 - GAP),
    g: hSeg(DH / 2, T / 2 + GAP, DW - T / 2 - GAP),
    d: hSeg(DH - T / 2, T / 2 + GAP, DW - T / 2 - GAP),
    f: vSeg(T / 2, T / 2 + GAP, DH / 2 - GAP),
    b: vSeg(DW - T / 2, T / 2 + GAP, DH / 2 - GAP),
    e: vSeg(T / 2, DH / 2 + GAP, DH - T / 2 - GAP),
    c: vSeg(DW - T / 2, DH / 2 + GAP, DH - T / 2 - GAP),
  };
  const svgNs = "http://www.w3.org/2000/svg";
  const digitsSvg = $("digits");
  const digits = [0, 1, 2].map((i) => {
    const g = document.createElementNS(svgNs, "g");
    g.setAttribute("class", "dg");
    // slant: x' = x + (DH - y) * 0.09 (top leans right)
    g.setAttribute("transform", `translate(${i * ADV} 0) matrix(1 0 -0.09 1 ${(DH * 0.09).toFixed(2)} 0)`);
    const segs = {};
    for (const [k, pts] of Object.entries(SEGMENTS)) {
      const p = document.createElementNS(svgNs, "polygon");
      p.setAttribute("points", pts.map((q) => q.map((v) => v.toFixed(2)).join(",")).join(" "));
      g.appendChild(p);
      segs[k] = p;
    }
    digitsSvg.appendChild(g);
    return { g, segs, ch: null, lead: null };
  });
  function setDigit(d, ch, lead) {
    if (d.ch !== ch) {
      d.ch = ch;
      const on = SEG[ch] || "";
      for (const k in d.segs) d.segs[k].classList.toggle("on", on.includes(k));
    }
    if (d.lead !== lead) { d.lead = lead; d.g.classList.toggle("is-lead", lead); }
  }
  function setNumber(n, test) {
    if (test) { for (const d of digits) setDigit(d, "8", false); return; }
    const s = String(Math.max(0, Math.min(999, Math.round(n)))).padStart(3, "0");
    const firstSig = s.search(/[1-9]/);
    for (let i = 0; i < 3; i++) setDigit(digits[i], s[i], i < 2 && (firstSig < 0 || i < firstSig));
  }

  // ── cells ──
  function cells(parent, n) { const out = []; for (let i = 0; i < n; i++) { const c = document.createElement("i"); parent.appendChild(c); out.push(c); } return out; }
  const rpmCells = cells($("rpm"), RPM_CELLS);
  rpmCells.forEach((c, i) => { if (i >= Math.floor(RPM_CELLS * RPM_RED)) c.classList.add("red"); });
  const fuelCells = cells(fuelGauge.querySelector(".vgauge__cells"), GAUGE_CELLS);
  const condCells = cells(condGauge.querySelector(".vgauge__cells"), GAUGE_CELLS);
  let rpmLit = -1;
  function setRpm(f) {
    const lit = Math.round(Math.max(0, Math.min(1, f)) * RPM_CELLS);
    if (lit === rpmLit) return;
    rpmLit = lit;
    rpmCells.forEach((c, i) => { c.classList.toggle("on", i < lit); c.classList.toggle("hot", i < lit && i >= lit - 2 && !c.classList.contains("red")); });
    rpmBox.classList.toggle("is-shift", f >= 0.95);
  }
  function setGauge(list, f) { const lit = Math.round(Math.max(0, Math.min(1, f)) * list.length); list.forEach((c, i) => c.classList.toggle("on", i < lit)); }
  function ticks() {
    barTicks.textContent = "";
    const step = cfg.units === "mph" ? 10 : 20;
    for (let v = 0; v <= cfg.speedMax + 0.01; v += step) {
      const t = document.createElement("i");
      t.style.left = `${(v / cfg.speedMax) * 100}%`;
      if (v % (step * 3) === 0) t.classList.add("major");
      barTicks.appendChild(t);
    }
  }

  // ── config ──
  function rgb(hex) { const m = /^#?([0-9a-f]{6})$/i.exec(hex || ""); if (!m) return null; const n = parseInt(m[1], 16); return `${n >> 16}, ${(n >> 8) & 255}, ${n & 255}`; }
  function applyConfig(next) {
    if (next && typeof next === "object") cfg = { ...cfg, ...next, layout: { ...cfg.layout, ...(next.layout || {}) }, theme: { ...cfg.theme, ...(next.theme || {}) }, shake: { ...cfg.shake, ...(next.shake || {}) } };
    const root = document.documentElement.style;
    for (const k of ["accent", "core", "gear", "warn", "cool"]) {
      const c = rgb(cfg.theme[k]);
      if (c) { root.setProperty(`--${k}`, cfg.theme[k]); root.setProperty(`--${k}-rgb`, c); }
    }
    root.setProperty("--glow", String(cfg.theme.glow));
    root.setProperty("--opacity", String(cfg.theme.opacity));
    stage.classList.toggle("has-scanlines", cfg.theme.scanlines !== false);
    stage.classList.toggle("no-name", !cfg.showVehicleName);
    stage.classList.toggle("zeros-lit", cfg.leadingZeros === "lit");
    stage.classList.toggle("zeros-off", cfg.leadingZeros === "off");
    stage.classList.toggle("is-flat", !cfg.layout.tilt);
    $("plane").style.setProperty("--tilt", cfg.layout.tilt ? `rotateX(${cfg.layout.tiltX}deg) rotateY(${cfg.layout.tiltY}deg)` : "none");
    unitEl.textContent = cfg.unitLabel || (cfg.units === "mph" ? "MPH" : "KPH");
    ticks();
    layout();
  }

  // Bottom right, right/bottom from the config (CSS px of a 1080-high screen, like the
  // surface's crop in shared/speedo.lua). On a narrow screen it shrinks rather than
  // run into op77_map3d's holo GPS at the bottom centre.
  let scale = 1;
  function layout() {
    const L = cfg.layout;
    const right = Math.max(0, L.right - L.offsetX), bottom = Math.max(0, L.bottom - L.offsetY);
    let s = L.scale;
    if (L.avoidHoloGps && bottom < HOLO_GPS.height + HOLO_GPS.gap) {
      const free = window.innerWidth - right - (window.innerWidth / 2 + HOLO_GPS.width / 2 + HOLO_GPS.gap);
      if (W * s > free) s = Math.max(L.minScale, Math.min(s, free / W));
    }
    scale = s;
    stage.style.right = `${right}px`;
    stage.style.bottom = `${bottom}px`;
    stage.style.transform = `scale(${s.toFixed(4)})`;
  }
  window.addEventListener("resize", layout);

  // ── state ──
  let target = null;          // last speedo:data
  let shownSpeed = 0, shownRpm = 0;
  let live = false;           // showing (or entering)
  let enteredAt = 0;
  let hideTimer = 0;
  let lastGear = null;
  let last = performance.now();
  let raf = 0;
  let nextGlitch = performance.now() + 4000;

  function show(p) {
    clearTimeout(hideTimer);
    nameEl.textContent = (p && p.name) || "";
    stage.classList.toggle("no-name", !cfg.showVehicleName || !(p && p.name));
    stage.classList.remove("is-off");
    stage.classList.add("is-live");
    if (p && p.instant) {
      stage.classList.add("is-on", "is-instant");
      enteredAt = performance.now() - ENTER_MS;
    } else {
      stage.classList.remove("is-on", "is-instant");
      void stage.offsetWidth; // restart the animation
      stage.classList.add("is-on");
      enteredAt = performance.now();
      shownSpeed = 0; shownRpm = 0;
    }
    live = true;
    loop();
  }
  function hide() {
    if (!live) return;
    live = false;
    stage.classList.remove("is-instant");
    stage.classList.replace("is-on", "is-off");
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => { stage.classList.remove("is-live", "is-off"); cancelAnimationFrame(raf); raf = 0; }, EXIT_MS + 40);
  }

  function frame(now) {
    raf = 0;
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    const t = target || { speed: 0, kph: 0, gear: "N", rpm: 0 };
    const since = now - enteredAt;
    const testing = live && since < SELFTEST_MS;

    // numbers: a critically damped follow of the 20 Hz samples
    shownSpeed += (t.speed - shownSpeed) * (1 - Math.exp(-dt * 11));
    if (Math.abs(t.speed - shownSpeed) < 0.05) shownSpeed = t.speed;
    const rpmTarget = typeof t.rpm === "number" ? t.rpm : Math.min(1, t.kph / 160);
    shownRpm += (rpmTarget - shownRpm) * (1 - Math.exp(-dt * 16));

    if (testing) {
      // self-test: every segment lit, the strip sweeps up and back
      setNumber(0, true);
      const k = since / SELFTEST_MS;
      setRpm(Math.sin(Math.PI * k));
      setGauge(fuelCells, 1); setGauge(condCells, 1);
      for (const el of [tagHbk, tagAbs, tagTcs]) el.classList.add("on");
    } else {
      setNumber(shownSpeed, false);
      setRpm(shownRpm);
      tagHbk.classList.toggle("on", !!t.handbrake);
      tagAbs.classList.toggle("on", !!t.abs); tagAbs.classList.toggle("blink", !!t.abs);
      tagTcs.classList.toggle("on", !!t.tcs); tagTcs.classList.toggle("blink", !!t.tcs);
      const fuel = t.fuel;
      fuelGauge.classList.toggle("is-none", !fuel);
      fuelGauge.classList.toggle("is-low", !!(fuel && fuel.low && !fuel.empty));
      fuelGauge.classList.toggle("is-empty", !!(fuel && fuel.empty));
      setGauge(fuelCells, fuel ? fuel.fraction : 0);
      const health = typeof t.health === "number" ? t.health : 1;
      condGauge.classList.toggle("is-low", !!t.damaged);
      setGauge(condCells, health);
    }

    // speed bar
    const f = Math.max(0, Math.min(1, shownSpeed / cfg.speedMax));
    barFill.style.transform = `scaleX(${f.toFixed(4)})`;
    barHead.style.transform = `translateX(${(f * (W - 4)).toFixed(1)}px)`;
    stage.classList.toggle("is-over", t.speed > cfg.speedMax);

    // gear
    const gear = String(t.gear || "N");
    if (gear !== lastGear) {
      gearValue.textContent = gear;
      gearEl.classList.toggle("is-r", gear === "R");
      gearEl.classList.toggle("is-n", gear === "N");
      if (lastGear !== null && !testing) { gearEl.classList.remove("pop"); void gearEl.offsetWidth; gearEl.classList.add("pop"); }
      lastGear = gear;
    }

    // icons: lights (high beams in the cool colour), engine, tyres
    const lights = t.lights | 0;
    icoLights.classList.toggle("on", lights === 1 && !t.brokenLights);
    icoLights.classList.toggle("cool", lights === 2 && !t.brokenLights);
    icoLights.classList.toggle("warn", lights > 0 && t.brokenLights > 0);
    icoEngine.classList.toggle("on", !!t.engine && !t.damaged);
    icoEngine.classList.toggle("warn", !!t.damaged);
    icoTires.classList.toggle("warn", t.tires > 0);
    tireCount.textContent = t.tires > 0 ? String(t.tires) : "";
    stage.classList.toggle("is-idle", !testing && t.engine === false && t.kph < 1);

    // high-speed shake: two incommensurate sines per axis, nothing random frame to frame
    let sx = 0, sy = 0;
    const sh = cfg.shake;
    if (sh.enabled && live && !testing && t.kph > sh.fromKph) {
      const a = Math.min(1, (t.kph - sh.fromKph) / Math.max(1, sh.fullKph - sh.fromKph)) * sh.amplitude;
      const s = now / 1000;
      sx = a * (Math.sin(s * 41.3) * 0.6 + Math.sin(s * 17.9) * 0.4);
      sy = a * (Math.sin(s * 37.1 + 1.3) * 0.6 + Math.sin(s * 23.7) * 0.4);
    }
    rig.style.transform = sx || sy ? `translate(${sx.toFixed(2)}px, ${sy.toFixed(2)}px)` : "";

    // the odd flicker
    if (cfg.theme.flicker && live && !testing && now > nextGlitch) {
      holo.classList.add("is-glitch");
      setTimeout(() => holo.classList.remove("is-glitch"), 70 + Math.random() * 60);
      nextGlitch = now + 3500 + Math.random() * 6000;
    }

    if (live || stage.classList.contains("is-off")) raf = requestAnimationFrame(frame);
  }
  function loop() { if (!raf) { last = performance.now(); raf = requestAnimationFrame(frame); } }

  function data(p) { if (p && typeof p === "object") { target = p; if (live) loop(); } }

  // ── bridge ──
  const bridge = typeof window.Open77 === "object" && window.Open77 && typeof window.Open77.on === "function" ? window.Open77 : null;
  applyConfig(null);
  if (bridge) {
    bridge.on("speedo:config", applyConfig);
    bridge.on("speedo:show", show);
    bridge.on("speedo:hide", hide);
    bridge.on("speedo:data", data);
    try { bridge.ready(); } catch (_) { /* older bridge */ }
    try { bridge.emit("speedo:ready", {}); } catch (_) { /* not in game */ }
  } else {
    preview();
  }

  // Browser preview: index.html?speed=63&gear=3&rpm=0.55&hbk=1&abs=0&tcs=0&lights=1&fuel=0.4
  // &health=0.9&engine=1&tires=0&name=QUADRA%20TYPE-66&units=kph&instant=1&demo=0&tilt=1
  // &scale=1&accent=FFCC00 ; demo=1 drives a loop (accelerates, shifts, brakes).
  function preview() {
    const q = new URLSearchParams(location.search);
    const num = (k, d) => (q.has(k) ? Number(q.get(k)) : d);
    const patch = { units: q.get("units") === "mph" ? "mph" : "kph", layout: {}, theme: {} };
    patch.unitLabel = patch.units === "mph" ? "MPH" : "KPH";
    patch.speedMax = num("max", patch.units === "mph" ? 150 : 240);
    if (q.has("tilt")) patch.layout.tilt = q.get("tilt") !== "0";
    if (q.has("scale")) patch.layout.scale = num("scale", 0.6);
    if (q.has("right")) patch.layout.right = num("right", 36);
    if (q.has("bottom")) patch.layout.bottom = num("bottom", 146);
    if (q.has("accent")) patch.theme.accent = "#" + q.get("accent");
    if (q.has("glow")) patch.theme.glow = num("glow", 1);
    if (q.has("zeros")) patch.leadingZeros = q.get("zeros");
    if (q.has("flicker")) patch.theme.flicker = q.get("flicker") !== "0";
    applyConfig(patch);
    const kph = num("speed", 63) * (patch.units === "mph" ? 1.609344 : 1);
    const state = {
      speed: num("speed", 63), kph, gear: q.get("gear") || "3", rpm: num("rpm", 0.55),
      handbrake: q.get("hbk") === "1", abs: q.get("abs") === "1", tcs: q.get("tcs") === "1",
      lights: num("lights", 1), engine: q.get("engine") !== "0", health: num("health", 0.92),
      damaged: num("health", 0.92) < 0.35, tires: num("tires", 0), brokenLights: 0, reversing: q.get("gear") === "R",
      fuel: q.get("fuel") === "none" ? undefined : { fraction: num("fuel", 0.62), low: num("fuel", 0.62) <= 0.15, empty: num("fuel", 0.62) <= 0 },
    };
    if (q.get("hidden") === "1") return;
    data(state);
    show({ name: q.get("name") ?? "QUADRA TYPE-66", instant: q.get("instant") !== "0" });
    shownSpeed = state.speed; shownRpm = state.rpm;
    if (q.get("demo") === "1") {
      let v = 0, g = 1, dir = 1;
      setInterval(() => {
        v = Math.max(0, Math.min(250, v + dir * (dir > 0 ? 1.9 : 4.5)));
        if (v >= 250) dir = -1; if (v <= 0) dir = 1;
        const top = [0, 45, 85, 125, 165, 205, 999];
        while (v > top[g] && g < 6) g++;
        while (g > 1 && v < top[g - 1] - 8) g--;
        const lo = top[g - 1], hi = Math.min(top[g], 260);
        data({ ...state, speed: v, kph: v, gear: String(g), rpm: 0.25 + 0.75 * Math.min(1, (v - lo) / (hi - lo)), abs: dir < 0 && v > 20, handbrake: false });
      }, 50);
    }
  }
})();
