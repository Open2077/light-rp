(() => {
  "use strict";

  // Fed by client/core/safezone_tile.lua:
  //   zone:state  { inside, label?, hint?, instant? }
  // Inside: the tile pops, the label unfolds ("SAFE ZONE" decoding, the hint typing), holds,
  // folds back into the tile. Leaving: amber "LEAVING SAFE ZONE", then the tile goes.
  // Without the game, ?state=idle|enter|label|leave&hint=... previews it.
  const HOLD_MS = 2600, LEAVE_HOLD_MS = 1500, FOLD_MS = 300, GO_MS = 320;
  const GLYPHS = "█▓▒░<>/\\#%&*+=-_";
  // The voice plate (open-voice) as measured on screen: its right edge 31 px from the
  // screen's, 357 px wide and its top 91 px above the bottom at full size; it shrinks to
  // .78 / .64 on 4:3 / 5:4 (its app.css). The rental chip ends 160 px from the right edge.
  const VOICE = { right: 31, width: 357, base: 26, height: 65 };
  const RENTAL_LEFT = 170;

  const root = document.getElementById("zone");
  const title = document.getElementById("title");
  const hint = document.getElementById("hint");
  let timers = [], inside = false, decoding = 0;

  function place() {
    const w = window.innerWidth, h = window.innerHeight || 1080;
    const ar = w / h;
    const s = ar <= 13 / 10 ? 0.64 : ar <= 13 / 9 ? 0.78 : 1;
    const left = w - VOICE.right - VOICE.width * s + 2;
    const bottom = VOICE.base + VOICE.height * s + 10 * s;
    root.style.left = `${left}px`;
    root.style.bottom = `${bottom}px`;
    root.style.transform = `scale(${s})`;
    // the label stops short of the rental chip; the tilt brings its far end ~8 % closer
    const room = (w - RENTAL_LEFT - (left + (38 + 8) * s)) / s / 1.08;
    root.style.setProperty("--label-max", `${Math.max(80, Math.floor(room))}px`);
  }
  window.addEventListener("resize", place);
  place();

  function later(fn, ms) { timers.push(setTimeout(fn, ms)); }
  function clear() { for (const t of timers) clearTimeout(t); timers = []; cancelAnimationFrame(decoding); }

  // "SAFE ZONE" resolving out of glyphs, left to right
  function decode(text, ms) {
    const start = performance.now();
    const step = () => {
      const k = Math.min(1, (performance.now() - start) / ms);
      const fixed = Math.floor(text.length * k);
      let out = text.slice(0, fixed);
      for (let i = fixed; i < text.length; i++) out += text[i] === " " ? " " : GLYPHS[(Math.random() * GLYPHS.length) | 0];
      title.textContent = out;
      if (k < 1) decoding = requestAnimationFrame(step);
    };
    step();
  }
  function type(text, delay) {
    hint.textContent = "";
    [...text].forEach((ch, i) => later(() => { hint.textContent += ch; }, delay + i * 22));
  }

  function enter(p, instant) {
    clear();
    inside = true;
    root.classList.remove("is-leaving", "is-going", "is-open");
    root.classList.add("is-live", "is-shown");
    root.title = p.label ? `Safe zone: ${p.label}` : "Safe zone";
    if (instant) { root.classList.remove("is-arriving"); return; }
    root.classList.remove("is-arriving"); void root.offsetWidth; root.classList.add("is-arriving");
    later(() => {
      root.classList.add("is-open");
      decode("SAFE ZONE", 420);
      type(p.hint || "", 260);
    }, 220);
    later(() => root.classList.remove("is-open"), 220 + HOLD_MS);
    later(() => root.classList.remove("is-arriving"), 220 + HOLD_MS + FOLD_MS);
  }

  function leave(instant) {
    clear();
    if (!inside && !root.classList.contains("is-live")) return;
    inside = false;
    if (instant) { root.classList.remove("is-live", "is-shown", "is-open", "is-leaving", "is-arriving"); return; }
    root.classList.remove("is-arriving");
    root.classList.add("is-leaving", "is-open");
    decode("LEAVING SAFE ZONE", 360);
    type("Protection off", 200);
    later(() => root.classList.remove("is-open"), LEAVE_HOLD_MS);
    later(() => { root.classList.add("is-going"); }, LEAVE_HOLD_MS + FOLD_MS);
    later(() => root.classList.remove("is-live", "is-shown", "is-leaving", "is-going"), LEAVE_HOLD_MS + FOLD_MS + GO_MS);
  }

  function state(p) {
    if (!p || typeof p !== "object") return;
    if (p.inside) { if (!inside || p.instant) enter(p, p.instant === true); else root.title = p.label ? `Safe zone: ${p.label}` : "Safe zone"; }
    else leave(p.instant === true);
  }

  const bridge = typeof window.Open77 === "object" && window.Open77 && typeof window.Open77.on === "function" ? window.Open77 : null;
  if (bridge) {
    bridge.on("zone:state", state);
    try { bridge.ready(); } catch (_) { /* older bridge */ }
    try { bridge.emit("zone:ready", {}); } catch (_) { /* not in game */ }
    return;
  }
  // preview
  const q = new URLSearchParams(location.search);
  const s = q.get("state") || "idle";
  const h = q.get("hint") ?? "No PvP · No shooting";
  if (s === "idle") state({ inside: true, hint: h, instant: true });
  else if (s === "enter" || s === "label") state({ inside: true, hint: h });
  else if (s === "leave") { state({ inside: true, hint: h, instant: true }); setTimeout(() => state({ inside: false }), 300); }
  window.__zonePreview = { state };
})();
