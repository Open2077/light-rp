/* Player marks page. Two feeds:
   - `pm:add` / `pm:remove` / `pm:talk` / `pm:config` from the client script:
     which anchor carries which player's dot, and who is talking how loud;
   - `open77:anchors` from the plugin, every frame: where each anchor is on
     screen. Only transforms and custom properties are written here. */
(() => {
  "use strict";
  const root = document.getElementById("marks");
  const marks = new Map();            // player id -> { el, anchor }
  const byAnchor = new Map();         // anchor id -> mark
  const cfg = { radius: 35, page: { nearScale: 1.0, farScale: 0.55, fadeFrom: 0.8 } };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const safeColor = (v) => /^#[0-9a-f]{6}$/i.test(String(v || "")) ? String(v) : null;

  function build(player, anchor) {
    const el = document.createElement("div");
    el.className = "pm";
    el.innerHTML = '<div class="pm__rig">'
      + '<span class="pm__wave"></span><span class="pm__wave"></span><span class="pm__wave"></span>'
      + '<span class="pm__dot"></span></div>';
    root.appendChild(el);
    const m = { player, anchor, el };
    marks.set(player, m);
    byAnchor.set(anchor, m);
    return m;
  }
  function remove(player) {
    const m = marks.get(player);
    if (!m) return;
    m.el.remove();
    marks.delete(player);
    if (byAnchor.get(m.anchor) === m) byAnchor.delete(m.anchor);
  }

  function emit(name, payload) { try { Open77.emit(name, payload); } catch (_) { /* not in game */ } }

  Open77.on("pm:config", (c) => {
    if (!c) return;
    const color = safeColor(c.color);
    if (color) document.documentElement.style.setProperty("--mark", color);
    if (Number(c.radius) > 0) cfg.radius = Number(c.radius);
    if (c.page) Object.assign(cfg.page, c.page);
  });
  Open77.on("pm:add", (msg) => {
    if (!msg || typeof msg.player !== "string" || typeof msg.anchor !== "string") return;
    remove(msg.player);
    build(msg.player, msg.anchor);
  });
  Open77.on("pm:remove", (msg) => { if (msg) remove(String(msg.player)); });
  Open77.on("pm:talk", (msg) => {
    const m = msg && marks.get(String(msg.player));
    if (!m) return;
    m.el.classList.toggle("is-talking", msg.talking === true);
    m.el.style.setProperty("--lvl", clamp(Number(msg.level) || 0, 0, 1).toFixed(2));
  });
  Open77.on("open77:anchors", (msg) => {
    const vw = window.innerWidth, vh = window.innerHeight;
    const seen = new Set();
    for (const a of (msg && Array.isArray(msg.anchors) ? msg.anchors : [])) {
      const m = byAnchor.get(String(a.id));
      if (!m) continue;
      const shown = a.onScreen !== false && a.projected !== false;
      m.el.classList.toggle("is-shown", shown);
      if (!shown) continue;
      seen.add(m);
      const d = Number(a.distance) || 0;
      const t = clamp(d / cfg.radius, 0, 1);
      const k = (cfg.page.nearScale + (cfg.page.farScale - cfg.page.nearScale) * t) * (vh / 1080);
      const fadeFrom = cfg.page.fadeFrom;
      const fade = 1 - clamp((t - fadeFrom) / (1 - fadeFrom), 0, 1);
      m.el.style.transform = `translate3d(${(a.x * vw).toFixed(1)}px, ${(a.y * vh).toFixed(1)}px, 0)`;
      m.el.style.setProperty("--s", k.toFixed(3));
      m.el.style.setProperty("--fade", fade.toFixed(3));
    }
    // an anchor missing from the frame is out of range or not streamed: hidden
    for (const m of marks.values()) if (!seen.has(m)) m.el.classList.remove("is-shown");
  });

  Open77.ready();
  emit("pm:ready", {});
})();
