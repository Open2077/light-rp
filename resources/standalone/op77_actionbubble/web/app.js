/* Action bubbles page. Two feeds:
   - `ab:add` / `ab:update` / `ab:anchor` / `ab:remove` from the client script:
     what each bubble says and which anchor carries it (DOM changes);
   - `open77:anchors` from the plugin, every frame: where each anchor is on
     screen. It only writes transforms and a few custom properties.
   A bubble plays its entrance the first time its anchor is on screen. */
(() => {
  "use strict";
  const root = document.getElementById("bubbles");
  const bubbles = new Map();          // id -> state
  const frame = new Map();            // anchor id -> { x, y, distance, onScreen }
  let scheduled = 0;
  const W = () => window.innerWidth, H = () => window.innerHeight;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const safeColor = (v) => /^#[0-9a-f]{6}$/i.test(String(v || "")) ? String(v) : "#FFCC00";

  // Stroke icons (24 px grid).
  const ICONS = {
    hand: '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 11V4.5a1.5 1.5 0 0 1 3 0V12M14 11.5V6a1.5 1.5 0 0 1 3 0v8c0 4-2.5 7-6.5 7S5 18.5 4 16l-1.6-3.6a1.4 1.4 0 0 1 2.4-1.4L8 15"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l3 3M14 9l2 2"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    unlock: '<rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V7a4 4 0 0 1 7.5-2"/>',
    box: '<path d="M3 7l9-4 9 4v10l-9 4-9-4z"/><path d="M3 7l9 4 9-4M12 11v10"/>',
    trunk: '<path d="M3 15h18v5H3zM5 15l2-6h10l2 6M9 18h6"/>',
    car: '<path d="M3 16v-4l2-5h14l2 5v4z"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M5 12h14"/>',
    door: '<path d="M6 21V3h12v18M3 21h18"/><circle cx="14.5" cy="12" r="0.8"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    chat: '<path d="M4 5h16v11H9l-5 4z"/>',
    alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18h.01"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/>',
    wrench: '<path d="M14.5 6.5a4.5 4.5 0 0 0 5.6 5.6L12 20.2a2.1 2.1 0 0 1-3-3l8.1-8.1"/><path d="M14.5 6.5L17 4"/>',
    phone: '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
    cash: '<rect x="2" y="6" width="20" height="12" rx="1"/><circle cx="12" cy="12" r="3"/>',
    heart: '<path d="M12 20s-8-4.6-8-10.2A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 8 2.8C20 15.4 12 20 12 20z"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
  };
  const GLYPHS = "!<>-_\\/[]{}=+*^?#%&$@0123456789ABCDEFXZ";

  // ── building a bubble ──
  function build(def) {
    const el = document.createElement("div");
    el.className = "ab";
    el.innerHTML =
      '<svg class="ab__lead"><polyline points="0,0 0,0 0,0"/><circle r="2" cx="0" cy="0"/></svg>' +
      '<div class="ab__pin"><b></b><i></i></div>' +
      '<div class="ab__rig"><div class="ab__card"><div class="ab__body">' +
      '<span class="ab__slab"></span><span class="ab__slab"></span><span class="ab__slab"></span>' +
      '<div class="ab__face">' +
      '<p class="ab__text"><span class="ab__icon"></span><em>*</em><span class="ab__t"></span><em>*</em></p><div class="ab__timer"><i></i></div></div>' +
      '<span class="ab__corner ab__corner--tl"></span><span class="ab__corner ab__corner--br"></span>' +
      '</div></div></div>';
    root.append(el);
    const s = {
      id: def.id, el, def,
      line: el.querySelector("polyline"), dot: el.querySelector("circle"),
      rig: el.querySelector(".ab__rig"), card: el.querySelector(".ab__card"), body: el.querySelector(".ab__body"),
      face: el.querySelector(".ab__face"), text: el.querySelector(".ab__t"),
      phase: Math.random() * 6.28, entered: false, leaving: false, typed: null, w: 0, h: 0, seq: ++seq,
    };
    bubbles.set(def.id, s);
    fill(s, def, true);
    return s;
  }
  let seq = 0;

  function fill(s, def, fresh) {
    const changed = fresh || s.def.text !== def.text;
    s.def = def;
    const el = s.el;
    el.style.setProperty("--accent", safeColor(def.accent));
    el.classList.toggle("has-asterisks", def.asterisks === true);
    el.classList.toggle("is-infinite", !(def.remaining > 0));
    el.querySelector(".ab__icon").innerHTML = ICONS[def.icon] ? `<svg viewBox="0 0 24 24">${ICONS[def.icon]}</svg>` : "";
    el.querySelector(".ab__icon").style.display = ICONS[def.icon] ? "" : "none";
    if (changed) {
      if (s.entered) scramble(s, String(def.text), 0); else s.text.textContent = "";
    }
    if (!fresh && def.remaining > 0 && s.entered) restartTimer(s, def.remaining, 0);
    measure(s);
  }

  function measure(s) {
    // the card's size at scale 1 (the text is laid out at its final length)
    // and kept at that width, so the card does not grow while the text types in
    const keep = [...s.text.childNodes];
    s.text.textContent = String(s.def.text);
    s.card.style.width = "max-content";
    s.w = s.face.offsetWidth + 1; s.h = s.face.offsetHeight; // layout sizes: transforms do not change them
    s.card.style.width = `${s.w}px`;
    s.text.replaceChildren(...keep);
  }

  function restartTimer(s, seconds, delay) {
    const bar = s.el.querySelector(".ab__timer i");
    s.el.style.setProperty("--dur", `${seconds}s`);
    s.el.style.setProperty("--delay", `${delay}s`);
    bar.style.animation = "none"; void bar.offsetWidth; bar.style.animation = "";
  }

  // Text resolves left to right out of random glyphs.
  function scramble(s, text, delayMs) {
    const start = performance.now() + delayMs, per = clamp(520 / Math.max(1, text.length), 9, 24);
    s.typed = { text, start, per };
    typeTick();
  }
  let typing = 0;
  function typeTick() {
    if (typing) return;
    typing = requestAnimationFrame(() => {
      typing = 0;
      const t = performance.now();
      let busy = false;
      for (const s of bubbles.values()) {
        const ty = s.typed;
        if (!ty) continue;
        const done = Math.floor((t - ty.start) / ty.per);
        if (done >= ty.text.length) { s.text.textContent = ty.text; s.typed = null; continue; }
        busy = true;
        if (done < 0) { s.text.textContent = ""; continue; }
        const tail = Math.min(4, ty.text.length - done);
        let noise = "";
        for (let i = 0; i < tail; i++) noise += ty.text[done + i] === " " ? " " : GLYPHS[(Math.random() * GLYPHS.length) | 0];
        s.text.innerHTML = "";
        s.text.append(ty.text.slice(0, done));
        const n = document.createElement("b"); n.className = "is-scramble"; n.textContent = noise; n.style.fontWeight = "inherit";
        s.text.append(n);
      }
      if (busy) typeTick();
    });
  }

  function enter(s) {
    s.entered = true;
    s.el.classList.add("is-in");
    scramble(s, String(s.def.text), 560);
    if (s.def.remaining > 0) restartTimer(s, s.def.remaining - 0.75 > 0.5 ? s.def.remaining - 0.75 : s.def.remaining, 0.75);
  }

  function leave(s, instant) {
    if (s.leaving) return;
    s.leaving = true;
    if (instant || !s.entered) { s.el.remove(); bubbles.delete(s.id); return; }
    s.el.classList.add("is-out");
    setTimeout(() => { s.el.remove(); bubbles.delete(s.id); }, 720);
  }

  // ── placing: every frame the plugin publishes, coalesced to the paint ──
  function schedule() {
    if (scheduled) return;
    scheduled = requestAnimationFrame(() => { scheduled = 0; place(); });
  }

  function place() {
    const t = performance.now() / 1000, vw = W(), vh = H();
    // bubbles on the same target stack upward, oldest at the bottom
    const groups = new Map();
    for (const s of bubbles.values()) {
      const key = s.def.group || s.id;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(s);
    }
    for (const list of groups.values()) list.sort((a, b) => a.seq - b.seq);

    for (const list of groups.values()) {
      let stack = 0;
      for (const s of list) {
        const a = s.def.anchor ? frame.get(s.def.anchor) : null;
        const visible = !!a && a.onScreen !== false;
        s.el.classList.toggle("is-shown", visible);
        if (!visible) continue;
        if (!s.entered && !s.leaving) {
          enter(s);
        }
        const x = a.x * vw, y = a.y * vh, d = Number(a.distance) || 0;
        const k = clamp(8 / (d + 3), 0.75, 1.0) * (vh / 1080);
        const maxD = Number(s.def.maxDistance) || 25;
        const fade = 1 - clamp((d - maxD * 0.75) / (maxD * 0.25), 0, 1);
        const left = s.def.side === "left" || (s.def.side !== "right" && a.x > 0.66);
        // where the card attaches, relative to the pin
        const reach = 50 * k, rise = 62 * k + stack;
        const cx = left ? -reach : reach, cy = -rise;
        stack += (s.h + 8) * k;
        // keep the card on screen
        const cardW = s.w * k, cardH = s.h * k;
        let ax = x + cx, ay = y + cy;
        if (!left && ax + cardW > vw - 12) ax = vw - 12 - cardW;
        if (left && ax - cardW < 12) ax = 12 + cardW;
        if (ay - cardH / 2 < 10) ay = 10 + cardH / 2;
        const dx = ax - x, dy = ay - y;
        s.el.classList.toggle("is-left", left);
        s.el.style.setProperty("--s", k.toFixed(3));
        s.el.style.setProperty("--fade", fade.toFixed(3));
        s.el.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
        // the leader: a diagonal, then a short run into the card's edge
        const ex = dx - (left ? -10 : 10) * k, mx = ex - (left ? -18 : 18) * k;
        const pts = `0,0 ${mx.toFixed(1)},${dy.toFixed(1)} ${dx.toFixed(1)},${dy.toFixed(1)}`;
        if (s.pts !== pts) {
          s.pts = pts;
          s.line.setAttribute("points", pts);
          s.dot.setAttribute("cx", dx.toFixed(1)); s.dot.setAttribute("cy", dy.toFixed(1));
          const len = Math.hypot(mx, dy) + Math.abs(dx - mx);
          s.el.style.setProperty("--len", len.toFixed(1));
        }
        // the card: scaled, turned toward the screen centre, floating
        const turn = (left ? 16 : -16) + (a.x - 0.5) * -22;
        const tilt = 7 + (a.y - 0.5) * -10;
        const bob = Math.sin(t * 1.7 + s.phase) * 3;
        const sway = Math.sin(t * 0.9 + s.phase) * 2.2;
        s.rig.style.transform = `translate3d(${dx.toFixed(1)}px, ${(dy - cardH / 2).toFixed(1)}px, 0) scale(${k.toFixed(3)})`;
        if (left) s.card.style.left = `${-s.w}px`; else s.card.style.left = "0px";
        s.body.style.setProperty("--pose", `translateY(${bob.toFixed(2)}px) rotateY(${(turn + sway).toFixed(2)}deg) rotateX(${tilt.toFixed(2)}deg)`);
      }
    }
    // a slow float even when the camera stands still
    if (bubbles.size > 0) schedule();
  }

  function emit(name, payload) { try { Open77.emit(name, payload); } catch (_) { /* not in game */ } }

  // ── feeds ──
  Open77.on("ab:add", (def) => {
    if (!def || typeof def.id !== "string") return;
    const old = bubbles.get(def.id);
    if (old) { old.el.remove(); bubbles.delete(def.id); }
    build(def);
    schedule();
  });
  Open77.on("ab:update", (def) => {
    const s = def && bubbles.get(def.id);
    if (s && !s.leaving) { fill(s, def, false); schedule(); }
  });
  Open77.on("ab:anchor", (msg) => {
    const s = msg && bubbles.get(msg.id);
    if (s) { s.def.anchor = msg.anchor || false; schedule(); }
  });
  Open77.on("ab:remove", (msg) => {
    const s = msg && bubbles.get(msg.id);
    if (s) leave(s, msg.instant === true);
  });
  Open77.on("open77:anchors", (msg) => {
    frame.clear();
    for (const a of (msg && Array.isArray(msg.anchors) ? msg.anchors : [])) frame.set(String(a.id), a);
    schedule();
  });
  window.addEventListener("resize", () => { for (const s of bubbles.values()) measure(s); schedule(); });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => { for (const s of bubbles.values()) measure(s); });

  Open77.ready();
  emit("ab:ready", {});
})();
