(() => {
  "use strict";

  // Fed by client/main.lua:
  //   weapon:config  the sanitized config (shared/weaponhud.lua WeaponHud.pageConfig)
  //   weapon:show    { key, name, type, class, melee, capacity, instant? }  drawn / switched
  //   weapon:hide    {}                                                     holstered
  //   weapon:data    { magazine, capacity, reserve, reloading, shots, reloaded, low, empty, left? }
  //   weapon:inset   { px }   lift above a growing bottom-left stack
  // Shots are the magazine deltas the client measured (there is no shot event); the page
  // animates them. Without the game, URL parameters drive a preview: see preview() below.
  const W = 420;
  const ENTER_MS = 600, EXIT_MS = 340, SELFTEST_MS = 480, ROLL_MS = 420;

  const $ = (id) => document.getElementById(id);
  const stage = $("stage"), rig = $("rig"), holo = $("holo"), plane = $("plane");
  const nameEl = $("name"), klass = $("klass"), kind = $("kind"), cellsEl = $("cells");
  const digitsSvg = $("digits"), reserveEl = $("reserve"), tagEl = $("tag"), progress = $("progress"), leftHand = $("leftHand");

  let cfg = {
    leadingZeros: "dim", lowAmmo: 0.25, lowAmmoMax: 10, maxCells: 36,
    layout: { left: 36, bottom: 142, offsetX: 0, offsetY: 0, scale: 0.6, tilt: true, tiltX: 8, tiltY: 16, maxInset: 60 },
    theme: { accent: "#FFCC00", core: "#FFF7DA", warn: "#FF3B3B", cool: "#7FD8FF", glow: 1, opacity: 1, scanlines: true, flicker: true },
  };
  let inset = 0;

  // ── seven-segment digits (op77_speedometer's) ──
  const SEG = { 0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg", 9: "abcdfg", "-": "g", " ": "" };
  const DW = 64, DH = 112, T = 11, GAP = 2.2, ADV = 82;
  const hSeg = (cy, x0, x1) => { const h = T / 2; return [[x0, cy], [x0 + h, cy - h], [x1 - h, cy - h], [x1, cy], [x1 - h, cy + h], [x0 + h, cy + h]]; };
  const vSeg = (cx, y0, y1) => { const h = T / 2; return [[cx, y0], [cx + h, y0 + h], [cx + h, y1 - h], [cx, y1], [cx - h, y1 - h], [cx - h, y0 + h]]; };
  const SEGMENTS = {
    a: hSeg(T / 2, T / 2 + GAP, DW - T / 2 - GAP), g: hSeg(DH / 2, T / 2 + GAP, DW - T / 2 - GAP), d: hSeg(DH - T / 2, T / 2 + GAP, DW - T / 2 - GAP),
    f: vSeg(T / 2, T / 2 + GAP, DH / 2 - GAP), b: vSeg(DW - T / 2, T / 2 + GAP, DH / 2 - GAP),
    e: vSeg(T / 2, DH / 2 + GAP, DH - T / 2 - GAP), c: vSeg(DW - T / 2, DH / 2 + GAP, DH - T / 2 - GAP),
  };
  const svgNs = "http://www.w3.org/2000/svg";
  const digits = [0, 1, 2].map((i) => {
    const g = document.createElementNS(svgNs, "g");
    g.setAttribute("class", "dg");
    g.setAttribute("transform", `translate(${i * ADV} 0) matrix(1 0 -0.09 1 ${(DH * 0.09).toFixed(2)} 0)`);
    const segs = {};
    for (const [k, pts] of Object.entries(SEGMENTS)) {
      const p = document.createElementNS(svgNs, "polygon");
      p.setAttribute("points", pts.map((q) => q.map((v) => v.toFixed(2)).join(",")).join(" "));
      g.appendChild(p); segs[k] = p;
    }
    digitsSvg.appendChild(g);
    return { g, segs, ch: null, lead: null };
  });
  function setDigit(d, ch, lead) {
    if (d.ch !== ch) { d.ch = ch; const on = SEG[ch] || ""; for (const k in d.segs) d.segs[k].classList.toggle("on", on.includes(k)); }
    if (d.lead !== lead) { d.lead = lead; d.g.classList.toggle("is-lead", lead); }
  }
  function setNumber(n) {
    if (n === "test") { for (const d of digits) setDigit(d, "8", false); return; }
    if (n === null || n === undefined) { for (const d of digits) setDigit(d, "-", false); return; }
    const s = String(Math.max(0, Math.min(999, Math.round(n)))).padStart(3, "0");
    const first = s.search(/[1-9]/);
    for (let i = 0; i < 3; i++) setDigit(digits[i], s[i], i < 2 && (first < 0 || i < first));
  }

  // ── magazine cells ──
  let cells = [], perCell = 1, litCells = -1;
  function buildCells(capacity) {
    cellsEl.textContent = "";
    cells = [];
    litCells = -1;
    if (!capacity) return;
    const n = Math.min(cfg.maxCells, capacity);
    perCell = Math.ceil(capacity / n);
    const count = Math.ceil(capacity / perCell);
    for (let i = 0; i < count; i++) { const c = document.createElement("i"); c.style.setProperty("--i", String(i)); cellsEl.appendChild(c); cells.push(c); }
  }
  function setCells(magazine, eject) {
    const lit = magazine == null ? 0 : Math.ceil(magazine / perCell);
    if (lit === litCells && !eject) return;
    if (eject && litCells > lit) {
      // the cells just emptied fly off (three at most per sample)
      for (let i = Math.max(lit, litCells - 3); i < litCells; i++) {
        const c = cells[i]; if (!c) continue;
        const e = document.createElement("b");
        e.className = "eject";
        e.style.left = `${c.offsetLeft}px`; e.style.width = `${c.offsetWidth}px`;
        cellsEl.appendChild(e);
        setTimeout(() => e.remove(), 320);
      }
    }
    litCells = lit;
    cells.forEach((c, i) => { c.classList.toggle("on", i < lit); c.classList.toggle("tip", i === lit - 1); });
  }

  // ── config & placement ──
  function rgb(hex) { const m = /^#?([0-9a-f]{6})$/i.exec(hex || ""); if (!m) return null; const n = parseInt(m[1], 16); return `${n >> 16}, ${(n >> 8) & 255}, ${n & 255}`; }
  function applyConfig(next) {
    if (next && typeof next === "object") cfg = { ...cfg, ...next, layout: { ...cfg.layout, ...(next.layout || {}) }, theme: { ...cfg.theme, ...(next.theme || {}) } };
    const root = document.documentElement.style;
    for (const k of ["accent", "core", "warn", "cool"]) { const c = rgb(cfg.theme[k]); if (c) { root.setProperty(`--${k}`, cfg.theme[k]); root.setProperty(`--${k}-rgb`, c); } }
    root.setProperty("--glow", String(cfg.theme.glow));
    root.setProperty("--opacity", String(cfg.theme.opacity));
    stage.classList.toggle("has-scanlines", cfg.theme.scanlines !== false);
    stage.classList.toggle("zeros-lit", cfg.leadingZeros === "lit");
    stage.classList.toggle("zeros-off", cfg.leadingZeros === "off");
    stage.classList.toggle("is-flat", !cfg.layout.tilt);
    plane.style.setProperty("--tilt", cfg.layout.tilt ? `rotateX(${cfg.layout.tiltX}deg) rotateY(${cfg.layout.tiltY}deg)` : "none");
    layout();
  }
  function layout() {
    const L = cfg.layout;
    const lift = Math.max(0, Math.min(L.maxInset, inset));
    stage.style.left = `${Math.max(0, L.left + L.offsetX)}px`;
    stage.style.bottom = `${Math.max(0, L.bottom - L.offsetY) + lift}px`;
    stage.style.transform = `scale(${L.scale})`;
  }

  // ── state ──
  let current = null;       // weapon:show payload
  let data = null;          // last weapon:data
  let live = false, enteredAt = 0, hideTimer = 0, testTimer = 0;
  let shownMag = null, roll = null, nextGlitch = performance.now() + 5000, raf = 0;

  function show(p) {
    clearTimeout(hideTimer); clearTimeout(testTimer);
    const switched = !current || current.key !== p.key;
    current = p;
    nameEl.textContent = p.name || "WEAPON";
    klass.textContent = p.class || "";
    klass.className = `badge${p.class ? " is-" + String(p.class).toLowerCase() : ""}`;
    kind.textContent = p.type || "";
    if (switched || cells.length === 0) buildCells(p.melee ? 0 : p.capacity);
    stage.classList.remove("is-off");
    stage.classList.add("is-live");
    if (p.instant) {
      stage.classList.add("is-on", "is-instant");
    } else {
      stage.classList.remove("is-on", "is-instant");
      void stage.offsetWidth;
      stage.classList.add("is-on");
      // self-test: every segment and cell lit for a moment
      stage.classList.add("is-test");
      setNumber("test");
      testTimer = setTimeout(() => { stage.classList.remove("is-test"); render(false); }, SELFTEST_MS);
      shownMag = null;
    }
    enteredAt = performance.now();
    live = true;
    if (!p.instant) return;
    render(false);
  }
  function hide() {
    if (!live) return;
    live = false;
    clearTimeout(testTimer);
    stage.classList.remove("is-instant", "is-test");
    stage.classList.replace("is-on", "is-off");
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => { stage.classList.remove("is-live", "is-off"); current = null; }, EXIT_MS + 40);
  }

  function retrigger(el, cls) { el.classList.remove(cls); void el.getBoundingClientRect(); el.classList.add(cls); }

  function render(animate) {
    if (!current || stage.classList.contains("is-test")) return;
    const d = data || {};
    const melee = current.melee || d.capacity == null;
    if (!current.melee && d.capacity && cells.length === 0) buildCells(d.capacity);
    stage.classList.toggle("is-melee", !!current.melee);
    stage.classList.toggle("is-reloading", !!d.reloading && !melee);
    stage.classList.toggle("is-empty", !!d.empty && !d.reloading && !melee);
    stage.classList.toggle("is-low", !!d.low && !d.empty && !d.reloading);
    reserveEl.textContent = melee || d.reserve == null ? "---" : String(d.reserve).padStart(3, "0");
    reserveEl.classList.toggle("is-out", d.reserve === 0);
    let tag = "", tagClass = "tag";
    if (melee && current.melee) { tag = "MELEE"; tagClass += " is-melee"; }
    else if (d.reloading) { tag = "RELOADING"; tagClass += " is-reloading"; }
    else if (d.empty) { tag = d.reserve === 0 ? "NO AMMO" : "RELOAD"; tagClass += " is-reload"; }
    else if (d.low) tag = "LOW AMMO";
    tagEl.textContent = tag; tagEl.className = tagClass;
    progress.style.setProperty("--fill", d.capacity ? String(Math.max(0, Math.min(1, (d.magazine || 0) / d.capacity))) : "0");
    leftHand.textContent = d.left && d.left.magazine != null ? `LEFT ${String(d.left.magazine).padStart(2, "0")}${d.left.capacity ? " / " + d.left.capacity : ""}` : "";

    if (melee) { setNumber(null); setCells(null, false); shownMag = null; return; }
    const mag = d.magazine;
    if (animate && d.shots > 0) {
      retrigger(digitsSvg, "hit");
      retrigger(rig, "kick");
      setCells(mag, true);
      shownMag = mag; roll = null;
      setNumber(mag);
    } else if (animate && shownMag != null && mag != null && mag > shownMag) {
      // reload done: the count rolls up while the cells refill in a sweep
      roll = { from: shownMag, to: mag, at: performance.now() };
      setCells(mag, false);
      tick();
    } else {
      if (!roll) { shownMag = mag; setNumber(mag); }
      setCells(mag, false);
    }
  }
  function tick() {
    raf = 0;
    if (roll) {
      const k = Math.min(1, (performance.now() - roll.at) / ROLL_MS);
      const e = 1 - Math.pow(1 - k, 3);
      shownMag = Math.round(roll.from + (roll.to - roll.from) * e);
      setNumber(shownMag);
      if (k >= 1) roll = null; else raf = requestAnimationFrame(tick);
    }
  }

  function onData(p) {
    if (!p || typeof p !== "object") return;
    data = p;
    if (live) render(true);
    // the odd flicker
    const t = performance.now();
    if (cfg.theme.flicker && live && t > nextGlitch && t - enteredAt > ENTER_MS) {
      holo.classList.add("is-glitch");
      setTimeout(() => holo.classList.remove("is-glitch"), 70 + Math.random() * 60);
      nextGlitch = t + 4000 + Math.random() * 6000;
    }
  }

  // ── bridge ──
  const bridge = typeof window.Open77 === "object" && window.Open77 && typeof window.Open77.on === "function" ? window.Open77 : null;
  applyConfig(null);
  if (bridge) {
    bridge.on("weapon:config", applyConfig);
    bridge.on("weapon:show", show);
    bridge.on("weapon:hide", hide);
    bridge.on("weapon:data", onData);
    bridge.on("weapon:inset", (p) => { inset = Number(p && p.px) || 0; layout(); });
    try { bridge.ready(); } catch (_) { /* older bridge */ }
    try { bridge.emit("weapon:ready", {}); } catch (_) { /* not in game */ }
  } else {
    preview();
  }

  // Browser preview: index.html?mag=21&cap=21&reserve=120&name=LEXINGTON&class=POWER&type=HANDGUN
  // &state=low|empty|reloading|melee&left=8&instant=0&inset=28&tilt=0&flicker=0&demo=1
  // window.__weaponPreview.fire(n) / .reload() / .holster() drive it from a script.
  function preview() {
    const q = new URLSearchParams(location.search);
    const num = (k, d) => (q.has(k) ? Number(q.get(k)) : d);
    const patch = { layout: {}, theme: {} };
    if (q.has("tilt")) patch.layout.tilt = q.get("tilt") !== "0";
    if (q.has("scale")) patch.layout.scale = num("scale", 0.6);
    if (q.has("flicker")) patch.theme.flicker = q.get("flicker") !== "0";
    applyConfig(patch);
    inset = num("inset", 0); layout();
    const state = q.get("state") || "";
    const cap = num("cap", 21);
    let mag = state === "empty" ? 0 : state === "low" ? 4 : num("mag", 18);
    let reserve = num("reserve", 120);
    const melee = state === "melee";
    const dataOf = (extra = {}) => ({ magazine: melee ? null : mag, capacity: melee ? null : cap, reserve: melee ? null : reserve,
      reloading: state === "reloading", shots: 0, low: mag > 0 && mag <= Math.min(10, Math.max(1, Math.round(cap * 0.25))), empty: mag === 0,
      left: q.has("left") ? { magazine: num("left", 8), capacity: 10 } : undefined, ...extra });
    if (q.get("hidden") === "1") return;
    data = dataOf();
    show({ key: "1:x", name: q.get("name") ?? (melee ? "SATORI" : "LEXINGTON"), class: q.get("class") ?? (melee ? "BLADE" : "POWER"),
      type: q.get("type") ?? (melee ? "KATANA" : "HANDGUN"), melee, capacity: melee ? null : cap, instant: q.get("instant") !== "0" });
    window.__weaponPreview = {
      fire(n = 1) { const before = mag; mag = Math.max(0, mag - n); onData(dataOf({ shots: before - mag })); },
      reload(phase) { if (phase === "start") onData(dataOf({ reloading: true })); else { const take = Math.min(cap - mag, reserve); mag += take; reserve -= take; onData(dataOf({ reloaded: true })); } },
      holster() { hide(); },
    };
    if (q.get("demo") === "1") {
      let busy = false;
      setInterval(() => {
        if (busy) return;
        if (mag > 0) { window.__weaponPreview.fire(1); return; }
        busy = true;
        window.__weaponPreview.reload("start");
        setTimeout(() => { window.__weaponPreview.reload("end"); busy = false; }, 1400);
      }, 160);
    }
  }
})();
