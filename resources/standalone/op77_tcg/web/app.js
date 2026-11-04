/* Cyberpunk TCG binder page. Talks to client/main.lua through window.Open77 (on / emit / ready).
   Without the bridge (a plain browser) it runs a local preview with a demo collection. */
(function () {
  "use strict";
  var O = window.Open77 || null;
  // Page errors reach the client log ([op77_tcg] page: ...).
  window.addEventListener("error", function (e) {
    try { if (window.Open77) window.Open77.emit("tcg:log", { text: String(e.message) + " @" + (e.filename || "") + ":" + (e.lineno || 0) }); } catch (x) {}
  });
  var PREVIEW = !O;
  function emit(name, payload) { if (O) { try { O.emit(name, payload || {}); } catch (e) { console.error(e); } } else { preview(name, payload || {}); } }
  function on(name, fn) { if (O) O.on(name, fn); else handlers[name] = fn; }
  var handlers = {};

  var $ = function (id) { return document.getElementById(id); };
  var el = function (tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; };

  var RARITY = {
    "Common": "--r-common", "Uncommon": "--r-uncommon", "Rare": "--r-rare", "Epic": "--r-epic",
    "Nova Rare": "--r-nova", "Iconic Legend": "--r-legend", "Iconic Other": "--r-iconic", "Secret": "--r-secret"
  };
  var TIER_NAME = { 1: "Common", 2: "Uncommon", 3: "Rare", 4: "Epic", 5: "Top tier", 6: "Secret" };
  function rc(card) { return "var(" + (RARITY[card.rarity] || "--r-common") + ")"; }
  function img(card) { return "img/cards/" + card.id + ".webp"; }

  var catalogue = [], byId = {};
  var state = { owned: {}, population: {}, sealed: {}, dust: 0, dustPlus: 0, shops: [], prices: {}, freeIn: 0, paid: false };
  var ui = { tab: "binder", spread: 0, filter: "all", search: "", shop: null, nearby: [], fresh: {}, offer: null, open: false };

  function parseCounts(s) {
    var out = {};
    String(s || "").split(",").forEach(function (part) {
      if (!part) return;
      var i = part.lastIndexOf(":");
      out[part.slice(0, i)] = Number(part.slice(i + 1)) || 0;
    });
    return out;
  }
  var SEALED = {
    wnc: { label: "Welcome to Night City", art: "img/ui/booster_wnc.webp", kind: "booster" },
    beta: { label: "Beta Edition", art: "img/ui/booster_beta.webp", kind: "booster" },
    box: { label: "Booster Display", art: "img/ui/box_retail.webp", kind: "box", contains: "wnc", count: 24 }
  };
  var RECYCLE = [0, 5, 10, 25, 60, 150, 400], PRINT = [0, 40, 80, 200, 500, 1600], SECRET_PLUS = 3;

  /* ---------------------------------------------------------------------------------------- toasts */
  var toastTimer;
  function toast(text, kind) {
    var t = $("toast"); t.textContent = text; t.className = "toast show" + (kind === "error" ? " error" : "");
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.className = "toast"; }, 3200);
  }

  /* ---------------------------------------------------------------------------------------- holo */
  function holo(node) {
    node.addEventListener("pointermove", function (ev) {
      var r = node.getBoundingClientRect();
      var x = (ev.clientX - r.left) / r.width, y = (ev.clientY - r.top) / r.height;
      node.style.setProperty("--mx", (x * 100).toFixed(1) + "%");
      node.style.setProperty("--my", (y * 100).toFixed(1) + "%");
      node.style.setProperty("--tilt-y", ((x - 0.5) * 22).toFixed(2) + "deg");
      node.style.setProperty("--tilt-x", ((0.5 - y) * 18).toFixed(2) + "deg");
    });
    node.addEventListener("pointerleave", function () {
      node.style.setProperty("--tilt-x", "0deg"); node.style.setProperty("--tilt-y", "0deg");
    });
  }
  function cardNode(card, cls) {
    var c = el("div", "card " + (cls || "") + " " + card.finish + (card.tier === 6 ? " secret" : ""));
    c.innerHTML = '<img alt="" loading="lazy" src="' + img(card) + '"><div class="sheen"></div><div class="holo"></div><div class="glare"></div>';
    holo(c);
    return c;
  }

  /* ---------------------------------------------------------------------------------------- binder */
  var FILTERS = [
    { id: "all", label: "All" }, { id: "owned", label: "Owned" }, { id: "missing", label: "Missing" },
    { id: "t1", label: "Common", c: "var(--r-common)" }, { id: "t2", label: "Uncommon", c: "var(--r-uncommon)" },
    { id: "t3", label: "Rare", c: "var(--r-rare)" }, { id: "t4", label: "Epic", c: "var(--r-epic)" },
    { id: "t5", label: "Nova / Iconic", c: "var(--r-nova)" }, { id: "t6", label: "Secret", c: "var(--r-secret)" },
    { id: "foil", label: "Foil" }, { id: "dupes", label: "Duplicates" }
  ];
  function buildChips() {
    var box = $("chips"); box.innerHTML = "";
    FILTERS.forEach(function (f) {
      var b = el("button", ui.filter === f.id ? "on" : "", f.label);
      if (f.c) b.style.setProperty("--c", f.c);
      b.onclick = function () { ui.filter = f.id; ui.spread = 0; buildChips(); renderBinder(); };
      box.appendChild(b);
    });
  }
  function visible() {
    var q = ui.search.trim().toLowerCase();
    return catalogue.filter(function (c) {
      var n = state.owned[c.id] || 0;
      if (q && c.name.toLowerCase().indexOf(q) < 0) return false;
      switch (ui.filter) {
        case "owned": return n > 0;
        case "missing": return n === 0;
        case "foil": return c.finish !== "sleeved";
        case "dupes": return n > 1;
        default: return ui.filter.charAt(0) === "t" ? c.tier === Number(ui.filter.slice(1)) : true;
      }
    });
  }
  function slot(card) {
    var n = card ? (state.owned[card.id] || 0) : 0;
    var s = el("div", "slot" + (card && n > 0 ? "" : " missing"));
    if (!card) return s;
    s.style.setProperty("--rc", rc(card));
    if (n > 0) {
      s.appendChild(cardNode(card));
      if (n > 1) s.appendChild(el("div", "count", "x" + n));
      if (ui.fresh[card.id]) s.appendChild(el("div", "new", "NEW"));
      s.appendChild(el("div", "gemline"));
      s.onclick = function () { inspect(card); };
    } else {
      s.innerHTML = '<div class="ghost"><div class="gem"></div><b>' + String(card.n).padStart(3, "0") + '</b><span>' +
        escapeHtml(card.name) + '</span><span>' + card.rarity + " &middot; " + card.finish + '</span></div>';
    }
    return s;
  }
  function escapeHtml(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function renderBinder() {
    var list = visible();
    var spreads = Math.max(1, Math.ceil(list.length / 18));
    ui.spread = Math.min(ui.spread, spreads - 1);
    var start = ui.spread * 18;
    var L = $("pageLeft"), Rt = $("pageRight");
    L.innerHTML = ""; Rt.innerHTML = "";
    for (var i = 0; i < 9; i++) L.appendChild(slot(list[start + i]));
    for (var j = 9; j < 18; j++) Rt.appendChild(slot(list[start + j]));
    $("prevBtn").disabled = ui.spread === 0;
    $("nextBtn").disabled = ui.spread >= spreads - 1;
    $("pageNo").textContent = "PAGES " + (ui.spread * 2 + 1) + "-" + (ui.spread * 2 + 2) + "  /  " + (spreads * 2) + "   ·   " + list.length + " EDITIONS";
  }
  function turn(dir) {
    var list = visible(), spreads = Math.max(1, Math.ceil(list.length / 18));
    var next = ui.spread + dir;
    if (next < 0 || next >= spreads) return;
    var t = $("turn"); t.className = "turn " + (dir > 0 ? "go-next" : "go-prev");
    setTimeout(function () { ui.spread = next; renderBinder(); }, 270);
    setTimeout(function () { t.className = "turn"; }, 560);
  }
  function renderStats() {
    var owned = 0, cards = {}, totalCards = {};
    catalogue.forEach(function (c) { totalCards[c.card] = 1; if ((state.owned[c.id] || 0) > 0) { owned++; cards[c.card] = 1; } });
    var tc = Object.keys(totalCards).length, oc = Object.keys(cards).length;
    $("statEditions").textContent = owned + " / " + catalogue.length;
    $("statCards").textContent = oc + " / " + tc;
    $("statDust").textContent = state.dust || 0;
    $("statDustPlus").textContent = state.dustPlus || 0;
    var pct = catalogue.length ? Math.round(owned / catalogue.length * 1000) / 10 : 0;
    $("progressBar").style.width = pct + "%";
    $("progressText").textContent = pct + "% complete";
    var sealed = 0; Object.keys(state.sealed || {}).forEach(function (k) { sealed += state.sealed[k] || 0; });
    $("sealedCount").textContent = sealed ? sealed : "";
  }

  /* ---------------------------------------------------------------------------------------- inspect */
  var inspecting = null;
  function inspect(card) {
    inspecting = card;
    var holder = $("inspectCard"); holder.innerHTML = "";
    holder.appendChild(cardNode(card, "big"));
    var n = state.owned[card.id] || 0;
    var r = $("inspectRarity"); r.textContent = card.rarity; r.style.setProperty("--rc", rc(card));
    $("inspectName").textContent = card.name;
    $("inspectNo").textContent = "#" + String(card.n).padStart(3, "0") + " / " + catalogue.length;
    $("inspectFinish").textContent = card.finish.charAt(0).toUpperCase() + card.finish.slice(1) + (card.tier === 6 ? " (Secret print)" : "");
    $("inspectCount").textContent = n + (n === 1 ? " copy" : " copies");
    var pop = state.population[card.id] || 0;
    $("inspectPop").textContent = pop ? pop + " pulled on this server" : "Not pulled yet on this server";
    var a = $("inspectActions"); a.innerHTML = "";
    $("givePanel").classList.add("hidden");
    function btn(label, cls, fn, disabled) { var b = el("button", cls, label); b.disabled = !!disabled; b.onclick = fn; a.appendChild(b); }
    btn("Show in hand", "primary", function () { emit("tcg:show", { id: card.id }); hideModals(); }, n < 1);
    btn("Lay on the table", "ghost", function () { emit("tcg:place", { id: card.id }); hideModals(); }, n < 1);
    btn("Give to a collector", "ghost", function () { givePanel(card); }, n < 1);
    if (n > 1) btn("Recycle " + (n - 1) + " duplicate" + (n > 2 ? "s" : "") + " (+" + RECYCLE[card.tier] * (n - 1) + " Dust)", "ghost",
      function () { emit("tcg:recycle", { id: card.id, count: n - 1 }); }, !ui.shop);
    $("inspect").classList.remove("hidden");
  }
  function givePanel(card) {
    var p = $("givePanel"); p.innerHTML = ""; p.classList.remove("hidden");
    if (!ui.nearby.length) { p.appendChild(el("div", "hint", "No collector within reach. Stand next to them.")); return; }
    ui.nearby.forEach(function (who) {
      var b = el("button", "", "Give to " + escapeHtml(who.name) + (who.distance ? " (" + who.distance.toFixed(1) + " m)" : ""));
      b.onclick = function () { emit("tcg:offer", { target: who.id, id: card.id }); p.classList.add("hidden"); toast("Offer sent to " + who.name); };
      p.appendChild(b);
    });
  }
  function hideModals() { $("inspect").classList.add("hidden"); $("offer").classList.add("hidden"); inspecting = null; }

  /* ---------------------------------------------------------------------------------------- sealed */
  function renderSealed() {
    var shelf = $("sealedShelf"); shelf.innerHTML = "";
    var any = false;
    Object.keys(SEALED).forEach(function (k) {
      var n = (state.sealed || {})[k] || 0;
      if (!n) return;
      any = true;
      var p = el("div", "product");
      p.innerHTML = '<div class="art"><img src="' + SEALED[k].art + '" alt=""></div><h4>' + SEALED[k].label + '</h4><div class="n">x' + n + '</div>';
      var b = el("div", "buttons");
      var open = el("button", "primary", SEALED[k].kind === "box" ? "Cut the wrap" : "Open a pack");
      open.onclick = function () { if (SEALED[k].kind === "box") startUnbox(k); else emit("tcg:openPack", { product: k }); };
      b.appendChild(open); p.appendChild(b); shelf.appendChild(p);
    });
    var inv = state.store === "inventory";
    $("sealedHint").textContent = any
      ? (inv ? "Your sealed product is in your inventory: open it here or use it from there. " : "") +
        "Packs open in your hands: stand at a table and the cards are dealt on it for everyone around to see."
      : (inv ? "No booster or display in your inventory. Buy some from the vendor at a Cyberpunk TCG shop."
             : "No sealed product. Visit a Cyberpunk TCG shop counter.");
  }

  /* ---------------------------------------------------------------------------------------- shop */
  function renderShop() {
    var on = !!ui.shop;
    $("shopOff").classList.toggle("hidden", on);
    $("shopOn").classList.toggle("hidden", !on);
    if (!on) return;
    var prods = $("shopProducts"); prods.innerHTML = "";
    // A gamemode that keeps sealed product in its inventory sells it at its own vendor.
    if (state.store === "inventory") prods.appendChild(el("p", "muted", "Boosters and displays are sold by the vendor at the counter. They go to your inventory."));
    else Object.keys(SEALED).forEach(function (k) {
      if (!state.paid && SEALED[k].kind !== "booster") return;
      var row = el("div", "row");
      var price = state.paid ? ((state.prices || {})[k] || 0) + " €$" : (state.freeIn > 0 ? "next free pack in " + Math.ceil(state.freeIn / 60) + " min" : "Free pack ready");
      row.innerHTML = '<img src="' + SEALED[k].art + '" alt=""><div class="grow"><b>' + SEALED[k].label + '</b><br><small>' + price + '</small></div>';
      var b = el("button", "primary", state.paid ? "Buy" : "Take");
      b.disabled = !state.paid && state.freeIn > 0;
      b.onclick = function () { emit("tcg:buy", { product: k }); };
      row.appendChild(b); prods.appendChild(row);
    });
    var rl = $("recycleList"); rl.innerHTML = "";
    var dupes = catalogue.filter(function (c) { return (state.owned[c.id] || 0) > 1; });
    var total = 0;
    dupes.forEach(function (c) {
      var n = state.owned[c.id] - 1, v = RECYCLE[c.tier] * n; total += v;
      var it = el("div", "item");
      it.innerHTML = '<img src="' + img(c) + '" alt=""><div class="grow">' + escapeHtml(c.name) + '<small>' + c.rarity + ' &middot; ' + n + ' spare &middot; +' + v + ' Dust</small></div>';
      var b = el("button", "", "Recycle"); b.onclick = function () { emit("tcg:recycle", { id: c.id, count: n }); };
      it.appendChild(b); rl.appendChild(it);
    });
    if (!dupes.length) rl.appendChild(el("div", "hint", "No duplicate: every card is a single copy."));
    var all = $("recycleAll"); all.disabled = !dupes.length; all.textContent = "Recycle every duplicate (+" + total + " Dust)";
    all.onclick = function () { dupes.forEach(function (c) { emit("tcg:recycle", { id: c.id, count: state.owned[c.id] - 1 }); }); };
    renderPrint();
  }
  function renderPrint() {
    var pl = $("printList"); pl.innerHTML = "";
    var q = ($("printSearch").value || "").toLowerCase();
    catalogue.filter(function (c) { return !(state.owned[c.id] > 0) && (!q || c.name.toLowerCase().indexOf(q) >= 0); }).slice(0, 80).forEach(function (c) {
      var dust = c.tier === 6 ? 0 : PRINT[c.tier], plus = c.tier === 6 ? SECRET_PLUS : 0;
      var it = el("div", "item");
      it.innerHTML = '<img src="' + img(c) + '" alt=""><div class="grow">' + escapeHtml(c.name) + '<small>' + c.rarity + ' &middot; ' + c.finish + ' &middot; ' +
        (plus ? plus + " Dust+" : dust + " Dust") + '</small></div>';
      var b = el("button", "", "Print");
      b.disabled = (state.dust || 0) < dust || (state.dustPlus || 0) < plus;
      b.onclick = function () { emit("tcg:print", { id: c.id }); };
      it.appendChild(b); pl.appendChild(it);
    });
  }

  /* ---------------------------------------------------------------------------------------- tabs */
  function setTab(tab) {
    ui.tab = tab;
    document.querySelectorAll(".tabs button").forEach(function (b) { b.classList.toggle("active", b.dataset.tab === tab); });
    ["binder", "sealed", "shop"].forEach(function (t) { $("tab-" + t).classList.toggle("hidden", t !== tab); });
    renderAll();
  }
  function renderAll() { renderStats(); if (ui.tab === "binder") renderBinder(); if (ui.tab === "sealed") renderSealed(); if (ui.tab === "shop") renderShop(); }

  function show() { $("app").classList.remove("hidden"); ui.open = true; }
  function hide() { $("app").classList.add("hidden"); hideModals(); ui.open = false; }

  /* ---------------------------------------------------------------------------------------- opening */
  // Sounds made by the page (WebAudio): no asset to stream; silent where the host has no audio output.
  var sfx = (function () {
    var ctx = null, master = null;
    function ac() {
      if (ctx) return ctx;
      try {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
        master = ctx.createGain(); master.gain.value = 0.55; master.connect(ctx.destination);
      } catch (e) { ctx = null; }
      return ctx;
    }
    function noise(dur, o) {
      var c = ac(); if (!c) return;
      var n = Math.floor(c.sampleRate * dur), buf = c.createBuffer(1, n, c.sampleRate), d = buf.getChannelData(0);
      for (var i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
      var src = c.createBufferSource(); src.buffer = buf;
      var f = c.createBiquadFilter(), t = c.currentTime + (o.delay || 0);
      f.type = o.type || "bandpass"; f.frequency.setValueAtTime(o.f || 2000, t); f.Q.value = o.q || 0.8;
      if (o.f2) f.frequency.exponentialRampToValueAtTime(o.f2, t + dur);
      var g = c.createGain();
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(o.v || 0.5, t + (o.a || 0.005));
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(f); f.connect(g); g.connect(master); src.start(t); src.stop(t + dur + 0.05);
    }
    function tone(freq, dur, o) {
      var c = ac(); if (!c) return; o = o || {};
      var osc = c.createOscillator(), g = c.createGain(), t = c.currentTime + (o.delay || 0);
      osc.type = o.type || "sine"; osc.frequency.setValueAtTime(freq, t);
      if (o.to) osc.frequency.exponentialRampToValueAtTime(o.to, t + dur);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(o.v || 0.3, t + (o.a || 0.01));
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      osc.connect(g); g.connect(master); osc.start(t); osc.stop(t + dur + 0.05);
    }
    var CHORD = { 2: [659, 988], 3: [523, 659, 784], 4: [523, 659, 784, 988], 5: [523, 659, 784, 1047, 1319], 6: [587, 740, 880, 1175, 1480, 1760] };
    var api = {
      unlock: function () { var c = ac(); if (c && c.state === "suspended") c.resume(); },
      crinkle: function (k) { noise(0.04 + Math.random() * 0.05, { f: 2200 + Math.random() * 3800, q: 1.4, v: 0.06 + k * 0.22 }); },
      rip: function () { noise(0.5, { f: 900, f2: 6000, q: 0.5, v: 0.8, a: 0.01 }); tone(95, 0.3, { to: 45, v: 0.45 }); },
      slide: function () { noise(0.55, { type: "lowpass", f: 1100, f2: 260, v: 0.28, a: 0.09 }); },
      flip: function () { noise(0.06, { type: "highpass", f: 2600, v: 0.5 }); tone(170, 0.09, { to: 85, v: 0.22 }); },
      whoosh: function () { noise(0.24, { f: 500, f2: 2600, q: 0.7, v: 0.16, a: 0.05 }); },
      chime: function (tier) { (CHORD[tier] || []).forEach(function (f, i) { tone(f, 1.1, { delay: i * 0.07, v: 0.11, type: "triangle" }); }); },
      hum: function (heat) { tone(90 + heat * 380, 0.13, { v: 0.04 + heat * 0.09, type: "sawtooth" }); },
      boom: function (tier) {
        tone(150, 1.1, { to: 32, v: 0.85 }); noise(0.9, { type: "lowpass", f: 2200, f2: 180, v: 0.65 });
        setTimeout(function () { api.chime(Math.max(3, tier)); }, 140);
      }
    };
    return api;
  })();

  // Sparks, foil shards and dust on a canvas over the scene.
  var fx = (function () {
    var cv = null, g = null, parts = [], running = false;
    function fit() { cv = $("fx"); g = cv.getContext("2d"); cv.width = cv.clientWidth; cv.height = cv.clientHeight; }
    function frame() {
      g.clearRect(0, 0, cv.width, cv.height);
      g.globalCompositeOperation = "lighter";
      for (var i = parts.length - 1; i >= 0; i--) {
        var p = parts[i];
        p.life -= 1 / 60;
        if (p.life <= 0) { parts.splice(i, 1); continue; }
        p.vy += p.grav; p.vx *= p.drag; p.vy *= p.drag; p.x += p.vx; p.y += p.vy; p.rot += p.spin;
        g.globalAlpha = Math.min(1, p.life / 0.4);
        g.fillStyle = p.color;
        g.save(); g.translate(p.x, p.y);
        if (p.kind === "spark") {
          g.rotate(Math.atan2(p.vy, p.vx));
          var len = p.size * 2 + Math.sqrt(p.vx * p.vx + p.vy * p.vy) * 2.2;
          g.fillRect(-len, -p.size / 3, len, p.size / 1.5);
        } else if (p.kind === "shard") {
          g.rotate(p.rot);
          g.fillRect(-p.size / 2, -p.size, p.size, p.size * 2 * Math.abs(Math.cos(p.rot * 2.5)) + 0.5);
        } else {
          g.beginPath(); g.arc(0, 0, p.size, 0, 6.283); g.fill();
        }
        g.restore();
      }
      if (parts.length) requestAnimationFrame(frame); else { running = false; g.clearRect(0, 0, cv.width, cv.height); }
    }
    function burst(x, y, n, colors, o) {
      o = o || {};
      if (!cv || cv.width !== cv.clientWidth) fit();
      var kinds = ["spark", "shard", "dot"];
      for (var i = 0; i < n; i++) {
        var ang = o.dir == null ? Math.random() * 6.283 : o.dir + (Math.random() - 0.5) * (o.spread == null ? 6.283 : o.spread);
        var sp = (o.speed || 6) * (0.3 + Math.random() * 0.9);
        parts.push({
          x: x + (Math.random() - 0.5) * (o.jitterX || 0), y: y + (Math.random() - 0.5) * (o.jitterY || 0),
          vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, grav: o.grav == null ? 0.12 : o.grav, drag: o.drag || 0.975,
          life: (o.life || 1.2) * (0.55 + Math.random() * 0.7), size: (o.size || 3) * (0.5 + Math.random()),
          rot: Math.random() * 6.28, spin: (Math.random() - 0.5) * 0.35,
          color: colors[Math.floor(Math.random() * colors.length)], kind: o.kind === "mix" ? kinds[i % 3] : (o.kind || "dot")
        });
      }
      if (!running) { running = true; requestAnimationFrame(frame); }
    }
    return { burst: burst };
  })();

  var op = null;
  var PACK_ART = { wnc: "img/ui/pack_wnc.webp", beta: "img/ui/pack_beta.webp" };
  function color(c) { return getComputedStyle(document.documentElement).getPropertyValue(RARITY[c.rarity] || "--r-common").trim() || "#ffffff"; }
  function hint(html) { var h = $("openingHint"); h.innerHTML = html; h.style.animation = "none"; void h.offsetWidth; h.style.animation = ""; }
  function centre() { var r = $("stage").getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }
  function deckNode(i) { return $("deck").querySelector('[data-index="' + i + '"]'); }
  function restart(node, cls) { node.classList.remove(cls); void node.offsetWidth; node.classList.add(cls); }
  function counter() {
    if (!op) return;
    var n = op.cards.length;
    $("counter").innerHTML = op.index === 0 ? "<b>" + n + "</b> cards inside" : "Card <b>" + op.index + "</b> / " + n;
  }

  function startOpening(d) {
    if (ub) closeUnbox(true);
    show(); sfx.unlock();
    $("binder").classList.add("hidden");
    $("opening").classList.remove("hidden");
    $("opening").style.setProperty("--sx", d.physical ? "30%" : "50%");
    $("app").classList.add("opening-on");
    var cards = (d.cards || []).map(function (id) { return byId[id]; }).filter(Boolean);
    op = { seq: d.seq, cards: cards, fresh: String(d.fresh || ""), index: 0, shown: -1, torn: false, busy: false, dealt: false,
      tearPct: 0, tearDir: 0, heat: 0, holding: false, armed: false, done: false, summarised: false, skipping: false };
    var pack = $("pack");
    pack.className = "pack";
    pack.style.setProperty("--pack-img", "url(" + (PACK_ART[d.product] || PACK_ART.wnc) + ")");
    pack.style.setProperty("--tear", "0");
    $("packTop").className = "pack-top";
    $("deck").innerHTML = ""; $("deck").className = "deck";
    $("summary").classList.add("hidden");
    $("rays").className = "rays"; $("charge").className = "charge"; $("counter").className = "counter";
    $("skipBtn").classList.remove("hidden");
    var tray = $("tray"); tray.innerHTML = "";
    cards.forEach(function (c, i) { tray.appendChild(el("div", "tslot" + (i === cards.length - 1 ? " rare" : ""))); });
    counter();
    hint('Swipe along the top of the pack to tear it open');
    wirePack(pack);
  }

  /* the pack: drag along the crimp (either way), or click / Space for a quick tear */
  function setTearDir(dir) {
    var pack = $("pack");
    op.tearDir = dir;
    pack.classList.toggle("rtl", dir < 0);
    pack.style.setProperty("--tear-origin", dir > 0 ? "100%" : "0%");
    pack.style.setProperty("--tear-dir", dir > 0 ? "1" : "-1");
  }
  function setTear(pct) {
    var pack = $("pack"), r = pack.getBoundingClientRect();
    if (pct - (op.lastCrinkle || 0) > 0.055) {
      op.lastCrinkle = pct;
      sfx.crinkle(pct);
      var x = op.tearDir > 0 ? r.left + r.width * pct : r.right - r.width * pct;
      fx.burst(x, r.top + r.height * 0.088, 5, ["#fff7c2", "#fcee09", "#ffffff"], { speed: 3.5, dir: -Math.PI / 2, spread: 2.2, kind: "spark", life: 0.5, grav: 0.18, size: 2 });
    }
    op.tearPct = pct;
    pack.style.setProperty("--tear", pct.toFixed(3));
  }
  function wirePack(pack) {
    var drag = null;
    pack.onpointerdown = function (e) {
      if (!op || op.torn) return;
      sfx.unlock();
      drag = { x0: e.clientX, base: op.tearPct, moved: false };
      pack.classList.add("dragging", "touched");
      try { pack.setPointerCapture(e.pointerId); } catch (x) { /* ignore */ }
    };
    pack.onpointermove = function (e) {
      if (!op || op.torn) return;
      var r = pack.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width, y = (e.clientY - r.top) / r.height;
      pack.style.setProperty("--py", ((x - 0.5) * 26).toFixed(1) + "deg");
      pack.style.setProperty("--px", ((0.5 - y) * 14).toFixed(1) + "deg");
      pack.style.setProperty("--shine", (100 - x * 100).toFixed(0) + "%");
      if (!drag) return;
      var dx = e.clientX - drag.x0;
      if (!op.tearDir && Math.abs(dx) > 6) setTearDir(dx > 0 ? 1 : -1);
      if (!op.tearDir) return;
      if (Math.abs(dx) > 6) drag.moved = true;
      var pct = Math.max(op.tearPct, Math.min(1, drag.base + (dx * op.tearDir) / (r.width * 0.8)));
      setTear(pct);
      if (pct >= 1) { drag = null; pack.classList.remove("dragging"); tear(); }
    };
    pack.onpointerup = pack.onpointercancel = function () {
      pack.classList.remove("dragging");
      if (!drag || !op || op.torn) { drag = null; return; }
      var click = !drag.moved;
      drag = null;
      if (click) autoTear();
    };
    pack.onpointerleave = function () {
      if (drag) return;
      pack.style.setProperty("--px", "0deg"); pack.style.setProperty("--py", "0deg");
    };
  }
  function autoTear() {
    if (!op || op.torn || op.autoTearing) return;
    op.autoTearing = true;
    $("pack").classList.add("touched");
    if (!op.tearDir) setTearDir(1);
    var t0 = performance.now(), from = op.tearPct;
    var step = function (now) {
      if (!op || op.torn) return;
      var k = Math.min(1, (now - t0) / 480);
      setTear(from + (1 - from) * k * k);
      if (k < 1) requestAnimationFrame(step); else tear();
    };
    requestAnimationFrame(step);
  }
  function tear(silent) {
    if (!op || op.torn) return;
    op.torn = true; op.busy = true;
    if (!op.tearDir) setTearDir(1);
    if (!silent) { emit("tcg:sfx", { name: "tear" }); emit("tcg:revealed", { seq: op.seq, stage: "tear" }); }
    sfx.rip();
    var pack = $("pack"), top = $("packTop"), r = pack.getBoundingClientRect();
    pack.style.setProperty("--tear", "1");
    top.style.setProperty("--fly-x", (op.tearDir < 0 ? -230 : 230) + "px");
    top.style.setProperty("--fly-r", (op.tearDir < 0 ? -70 : 70) + "deg");
    top.classList.add("off");
    pack.classList.add("opened");
    fx.burst(r.left + r.width / 2, r.top + r.height * 0.09, 46, ["#fff7c2", "#fcee09", "#ffffff", "#9ff3ff"],
      { speed: 9, dir: -Math.PI / 2, spread: 2.6, kind: "mix", life: 1, grav: 0.22, jitterX: r.width * 0.8, size: 2.6 });
    restart($("stage"), "shake");
    hint("");
    setTimeout(buildDeck, 560);
  }

  /* the deck: 12 cards out of the pack, face down, the first one on top */
  function buildDeck() {
    if (!op) return;
    var deck = $("deck"), n = op.cards.length;
    deck.innerHTML = "";
    for (var i = n - 1; i >= 0; i--) {
      var c = op.cards[i];
      var d = el("div", "dcard rise t" + c.tier);
      d.dataset.index = String(i);
      d.style.setProperty("--rc", rc(c));
      d.style.translate = (i * 0.8) + "px " + (i * -1.2) + "px";
      d.style.animationDelay = ((n - 1 - i) * 0.03) + "s";
      d.innerHTML = '<div class="glow"></div><div class="cflip"><div class="side back"><img src="img/backside.webp" alt=""></div></div>';
      var front = el("div", "side front");
      front.appendChild(cardNode(c));
      if (op.fresh.charAt(i) === "1") front.appendChild(el("div", "stamp", "NEW"));
      d.querySelector(".cflip").appendChild(front);
      deck.appendChild(d);
    }
    sfx.slide();
    deck.classList.add("live");
    deck.onpointerdown = function (e) { if (e.button === 0) press(true); };
    setTimeout(function () {
      if (!op) return;
      op.dealt = true; op.busy = false;
      markTop(); counter();
      hint('<span class="key">Click</span> or <span class="key">Space</span> to flip the next card');
    }, 650 + n * 30);
  }
  function markTop() {
    var nodes = $("deck").querySelectorAll(".dcard");
    for (var k = 0; k < nodes.length; k++) nodes[k].classList.remove("top");
    var t = op && deckNode(op.index);
    if (t && !t.classList.contains("up")) t.classList.add("top");
  }

  /* one input for mouse and keyboard: press = next card; on the rare slot, hold */
  function press(down) {
    if (!op || op.summarised) return;
    if (!op.torn) { if (down) autoTear(); return; }
    if (op.armed) { op.holding = down; if (down) charge(); return; }
    if (!down) return;
    if (op.done) { if (!op.busy) summary(); return; }
    next();
  }
  function next(silent) {
    if (!op || !op.torn || op.busy || !op.dealt) return;
    var n = op.cards.length;
    if (op.shown >= 0 && op.shown < n - 1) { toTray(op.shown); op.shown = -1; }
    if (op.index >= n) return;
    var i = op.index;
    if (i === n - 1 && silent !== true && !op.skipping) { armRare(); return; }
    flip(i, silent === true);
  }
  function flip(i, silent) {
    var c = op.cards[i], node = deckNode(i), n = op.cards.length, last = i === n - 1;
    if (!node) return;
    op.busy = true;
    if (last) { op.armed = false; op.holding = false; $("charge").classList.remove("on"); node.classList.remove("hot"); }
    node.classList.remove("top"); node.classList.add("up");
    op.shown = i; op.index = i + 1;
    if (op.fresh.charAt(i) === "1") ui.fresh[c.id] = true;
    if (!silent) emit("tcg:revealed", { seq: op.seq, stage: "card", index: i + 1 });
    sfx.flip();
    setTimeout(function () { if (op) moment(c, last); }, 170);
    markTop(); counter();
    if (i === 0) hint('<span class="key">Click</span> next card');
    if (last) {
      op.done = true;
      hint("");
      setTimeout(function () { if (op && op.done && !op.summarised) hint('<span class="key">Click</span> to see the whole pack'); }, 1800);
    }
    setTimeout(function () { if (op) op.busy = false; }, last ? 1100 : 360);
  }
  function banner(text, cssColour, small) {
    var b = el("div", "rarity-banner" + (small ? " small" : ""), text);
    b.style.setProperty("--rc", cssColour);
    $("opening").appendChild(b);
    // The banner takes the counter's line while it shows.
    $("counter").classList.add("away");
    setTimeout(function () { b.remove(); if (op && !op.done) $("counter").classList.remove("away"); }, small ? 1400 : 2700);
  }
  function moment(c, last) {
    var p = centre(), col = color(c), t = c.tier;
    if (last) {
      var fl = $("flash"); fl.style.setProperty("--fc", col); restart(fl, "go");
      restart($("opening"), "quake");
      var rays = $("rays"); rays.style.setProperty("--rc", rc(c)); rays.className = "rays blast";
      fx.burst(p.x, p.y, 70 + t * 30, [col, "#ffffff", col, col], { speed: 10 + t, kind: "mix", life: 1.7, grav: 0.13, size: 3.4 });
      banner(c.rarity, rc(c), false);
      sfx.boom(t);
      if (t >= 5) rain(col);
      setTimeout(function () { if (op && rays.classList.contains("blast")) rays.className = "rays"; }, 3400);
      return;
    }
    if (t >= 4) {
      var f2 = $("flash"); f2.style.setProperty("--fc", col); restart(f2, "go");
      fx.burst(p.x, p.y, 70, [col, "#ffffff"], { speed: 9, kind: "mix", life: 1.3, size: 3 });
      banner(c.rarity, rc(c), false); sfx.chime(t);
    } else if (t === 3) {
      fx.burst(p.x, p.y, 36, [col, "#ffffff"], { speed: 7, kind: "mix", life: 1.1, size: 2.6 });
      banner(c.rarity, rc(c), true); sfx.chime(3);
    } else if (t === 2) {
      fx.burst(p.x, p.y, 14, [col, "#ffffff"], { speed: 5, kind: "spark", life: 0.8, size: 2 });
      sfx.chime(2);
    }
  }
  function rain(col) {
    var w = window.innerWidth, k = 0;
    var drop = function () {
      if (!op || k++ > 26) return;
      for (var j = 0; j < 7; j++) fx.burst(Math.random() * w, -10, 1, [col, "#ffffff", "#fff3a0"], { speed: 2, dir: Math.PI / 2, spread: 0.6, kind: "shard", life: 3.2, grav: 0.05, drag: 0.995, size: 4 });
      setTimeout(drop, 85);
    };
    drop();
  }
  /* the rare slot: the hidden card hums in its rarity's colour, a hold charges it, letting go cools it */
  function armRare() {
    var n = op.cards.length, c = op.cards[n - 1], node = deckNode(n - 1);
    op.armed = true; op.heat = 0;
    node.classList.add("hot"); node.style.setProperty("--heat", "0");
    ["rays", "charge"].forEach(function (id) { $(id).style.setProperty("--rc", rc(c)); $(id).style.setProperty("--heat", "0"); });
    $("rays").className = "rays on"; $("charge").classList.add("on");
    hint('The rare slot... <span class="key">Hold</span> to reveal');
    counter();
  }
  function charge() {
    if (op.charging) return;
    op.charging = true;
    var node = deckNode(op.cards.length - 1), c = op.cards[op.cards.length - 1], col = color(c), last = performance.now(), hum = 0;
    var tick = function (now) {
      if (!op || !op.armed) { if (op) op.charging = false; return; }
      var dt = Math.min(0.05, (now - last) / 1000); last = now;
      op.heat = Math.max(0, Math.min(1, op.heat + (op.holding ? dt / 1.5 : -dt / 0.7)));
      [node, $("rays"), $("charge")].forEach(function (x) { x.style.setProperty("--heat", op.heat.toFixed(3)); });
      if (op.holding && now - hum > 100) {
        hum = now; sfx.hum(op.heat);
        if (op.heat > 0.25) { var p = centre(); fx.burst(p.x, p.y, 2 + Math.round(op.heat * 4), [col, "#ffffff"], { speed: 2 + op.heat * 7, kind: "spark", life: 0.5, grav: 0, jitterX: 260, jitterY: 380, size: 2 }); }
      }
      if (op.heat >= 1) { op.charging = false; flip(op.cards.length - 1, false); return; }
      if (op.heat <= 0 && !op.holding) { op.charging = false; return; }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }
  /* a revealed card flies to its slot in the tray */
  function toTray(i) {
    var node = deckNode(i); if (!node) return;
    var c = op.cards[i], slotNode = $("tray").children[i], host = $("opening").getBoundingClientRect();
    var from = node.getBoundingClientRect(), to = slotNode.getBoundingClientRect();
    var f = el("div", "flying", '<img src="' + img(c) + '" alt="">');
    f.style.width = from.width + "px"; f.style.height = from.height + "px";
    $("opening").appendChild(f);
    node.remove();
    sfx.whoosh();
    var x0 = from.left - host.left, y0 = from.top - host.top, x1 = to.left - host.left, y1 = to.top - host.top;
    var sx = to.width / from.width, sy = to.height / from.height;
    var anim = f.animate([
      { transform: "translate(" + x0 + "px," + y0 + "px) rotate(0deg) scale(1)" },
      { transform: "translate(" + ((x0 + x1) / 2 + 40) + "px," + ((y0 + y1) / 2 - 30) + "px) rotate(9deg) scale(" + ((1 + sx) / 2).toFixed(3) + ")", offset: 0.5 },
      { transform: "translate(" + x1 + "px," + y1 + "px) rotate(0deg) scale(" + sx.toFixed(3) + "," + sy.toFixed(3) + ")" }
    ], { duration: 480, easing: "cubic-bezier(.45,.05,.3,1)", fill: "forwards" });
    anim.onfinish = function () { f.remove(); fillSlot(i, c); };
  }
  function fillSlot(i, c) {
    if (!op) return;
    var s = $("tray").children[i]; if (!s) return;
    s.classList.add("filled"); s.innerHTML = ""; s.style.setProperty("--rc", rc(c));
    s.appendChild(cardNode(c));
    if (op.fresh.charAt(i) === "1") s.appendChild(el("div", "tag", "NEW"));
    if (c.tier >= 2) s.appendChild(el("div", "gem"));
  }
  function skipAll() {
    if (!op || op.summarised) return;
    op.skipping = true;
    $("skipBtn").classList.add("hidden");
    var go = function () {
      if (!op || op.summarised) return;
      if (!op.torn) { autoTear(); setTimeout(go, 700); return; }
      if (op.busy || !op.dealt) { setTimeout(go, 90); return; }
      if (op.index >= op.cards.length) { setTimeout(function () { if (op && !op.summarised) summary(); }, 2000); return; }
      if (op.armed) flip(op.cards.length - 1, false); else next();
      setTimeout(go, 140);
    };
    go();
  }
  function summary() {
    if (!op || op.summarised) return;
    op.summarised = true;
    $("skipBtn").classList.add("hidden");
    hint("");
    var n = op.cards.length, hit = op.cards[n - 1], fresh = 0;
    for (var k = 0; k < n; k++) if (op.fresh.charAt(k) === "1") fresh++;
    var owned = Object.keys(state.owned).filter(function (id) { return state.owned[id] > 0; }).length;
    $("summaryStats").innerHTML = '<span class="new"><b>' + fresh + '</b>new</span><span><b>' + (n - fresh) + '</b>dupes</span>' +
      '<span><b>' + owned + '</b>/ ' + catalogue.length + ' collected</span>';
    var h = $("summaryHit"); h.innerHTML = ""; h.style.setProperty("--rc", rc(hit));
    h.appendChild(cardNode(hit));
    if (op.fresh.charAt(n - 1) === "1") h.appendChild(el("div", "tag new", "NEW"));
    h.appendChild(el("div", "label", hit.rarity));
    var g = $("summaryGrid"); g.innerHTML = "";
    op.cards.slice(0, n - 1).forEach(function (c, i) {
      var e = el("div", "entry"); e.style.setProperty("--rc", rc(c)); e.style.animationDelay = (0.15 + i * 0.045) + "s";
      e.appendChild(cardNode(c));
      var isNew = op.fresh.charAt(i) === "1";
      e.appendChild(el("div", "tag " + (isNew ? "new" : "dup"), isNew ? "NEW" : "DUPE"));
      e.appendChild(el("div", "label", c.rarity));
      g.appendChild(e);
    });
    $("rays").className = "rays";
    $("summary").classList.remove("hidden");
  }
  function finishOpening() {
    if (!op) return;
    // Anything not revealed yet is revealed for the others at once.
    if (op.index < op.cards.length) emit("tcg:revealed", { seq: op.seq, stage: "card", index: op.cards.length });
    op = null;
    document.querySelectorAll("#opening .flying, #opening .rarity-banner").forEach(function (x) { x.remove(); });
    $("deck").innerHTML = ""; $("tray").innerHTML = ""; $("rays").className = "rays";
    $("opening").classList.add("hidden");
    $("binder").classList.remove("hidden");
    $("app").classList.remove("opening-on");
    ui.tab = "binder"; ui.filter = "all"; buildChips();
    emit("tcg:openingDone", {});
    hide();
  }

/* ---------------------------------------------------------------------------------------- display box */
  // Cut the shrink-wrap with a blade (a drag along the line, or a click / Space for one clean cut), the plastic
  // falls away in two halves and the box's packs come out one by one. Pick one to open it at once.
  var ub = null;
  function uhint(html) { var h = $("uboxHint"); h.innerHTML = html; h.style.animation = "none"; void h.offsetWidth; h.style.animation = ""; }
  function startUnbox(product) {
    var def = SEALED[product];
    if (!def || def.kind !== "box") return;
    ub = { product: product, contains: def.contains || "wnc", count: def.count || 24, pct: 0, dir: 0, cut: false, last: 0 };
    sfx.unlock();
    show();
    $("binder").classList.add("hidden");
    $("unbox").classList.remove("hidden");
    $("app").classList.add("opening-on");
    var box = $("ubox");
    box.className = "ubox";
    box.style.setProperty("--box-img", "url(" + def.art + ")");
    box.style.setProperty("--cut", "0");
    $("uboxImg").src = def.art;
    $("wrapTop").className = "wrap wrap-top";
    $("wrapBottom").className = "wrap wrap-bottom";
    $("uboxPacks").innerHTML = "";
    $("uboxActions").classList.add("hidden");
    $("uboxOpen").classList.remove("hidden");
    uhint("Run the blade along the line to cut the shrink-wrap");
    wireBox(box);
  }
  function setCut(pct) {
    var box = $("ubox"), r = box.getBoundingClientRect();
    if (pct - ub.last > 0.05) {
      ub.last = pct;
      sfx.crinkle(pct * 0.8);
      var x = ub.dir >= 0 ? r.left + r.width * (0.24 + 0.52 * pct) : r.right - r.width * (0.24 + 0.52 * pct);
      fx.burst(x, r.top + r.height * 0.76, 4, ["#ffffff", "#cdeaff", "#9ff3ff"], { speed: 3, kind: "shard", life: 0.7, grav: 0.2, size: 2.4 });
    }
    ub.pct = pct;
    box.style.setProperty("--cut", pct.toFixed(3));
  }
  function wireBox(box) {
    var drag = null;
    box.onpointerdown = function (e) {
      if (!ub || ub.cut) return;
      sfx.unlock();
      drag = { x0: e.clientX, base: ub.pct, moved: false };
      box.classList.add("touched");
      try { box.setPointerCapture(e.pointerId); } catch (x) { /* ignore */ }
    };
    box.onpointermove = function (e) {
      if (!ub || ub.cut) return;
      var r = box.getBoundingClientRect();
      box.style.setProperty("--gloss", (100 - ((e.clientX - r.left) / r.width) * 100).toFixed(0) + "%");
      if (!drag) return;
      var dx = e.clientX - drag.x0;
      if (!ub.dir && Math.abs(dx) > 6) { ub.dir = dx > 0 ? 1 : -1; box.classList.toggle("rtl", ub.dir < 0); }
      if (!ub.dir) return;
      if (Math.abs(dx) > 6) drag.moved = true;
      var pct = Math.max(ub.pct, Math.min(1, drag.base + (dx * ub.dir) / (r.width * 0.46)));
      setCut(pct);
      if (pct >= 1) { drag = null; cutWrap(); }
    };
    box.onpointerup = box.onpointercancel = function () {
      if (!drag || !ub || ub.cut) { drag = null; return; }
      var click = !drag.moved;
      drag = null;
      if (click) autoCut();
    };
  }
  function autoCut() {
    if (!ub || ub.cut || ub.auto) return;
    ub.auto = true;
    $("ubox").classList.add("touched");
    if (!ub.dir) ub.dir = 1;
    var t0 = performance.now(), from = ub.pct;
    var step = function (now) {
      if (!ub || ub.cut) return;
      var k = Math.min(1, (now - t0) / 520);
      setCut(from + (1 - from) * k);
      if (k < 1) requestAnimationFrame(step); else cutWrap();
    };
    requestAnimationFrame(step);
  }
  function cutWrap() {
    if (!ub || ub.cut) return;
    ub.cut = true;
    emit("tcg:unbox", { product: ub.product });
    sfx.rip();
    var box = $("ubox"), r = box.getBoundingClientRect();
    box.classList.add("cut");
    restart(box, "pop");
    $("wrapTop").classList.add("off");
    $("wrapBottom").classList.add("off");
    fx.burst(r.left + r.width / 2, r.top + r.height * 0.76, 40, ["#ffffff", "#cdeaff", "#9ff3ff", "#fcee09"],
      { speed: 7, kind: "mix", life: 1.1, grav: 0.18, jitterX: r.width * 0.5, size: 2.6 });
    uhint("");
    // The packs come out once the server has them in the store (tcg:state extra.unboxed), not before.
    ub.cutAt = performance.now();
    ub.timer = setTimeout(function () { unboxResult(ub && ub.product, false, "The display could not be opened."); }, 8000);
  }
  // The server's answer to the cut: deal the packs, or put the plastic back (no room in the inventory...).
  function unboxResult(product, ok, why) {
    if (!ub || !ub.cut || ub.dealt || product !== ub.product) return;
    clearTimeout(ub.timer);
    if (ok) {
      ub.dealt = true;
      setTimeout(dealBoxPacks, Math.max(0, 650 - (performance.now() - ub.cutAt)));
      return;
    }
    var box = $("ubox");
    ub.cut = false; ub.auto = false; ub.pct = 0; ub.last = 0; ub.dir = 0;
    box.className = "ubox";
    box.style.setProperty("--cut", "0");
    $("wrapTop").className = "wrap wrap-top"; $("wrapBottom").className = "wrap wrap-bottom";
    uhint((why ? why + " &middot; " : "") + "The display is still sealed");
    $("uboxOpen").classList.add("hidden");
    $("uboxActions").classList.remove("hidden");
  }
  function dealBoxPacks() {
    if (!ub) return;
    var host = $("unbox").getBoundingClientRect(), box = $("ubox").getBoundingClientRect(), holder = $("uboxPacks");
    var perRow = 12, w = 66, h = 132, gap = 10;
    var x0 = host.width / 2 - (perRow * w + (perRow - 1) * gap) / 2, y0 = box.top - host.top + box.height * 0.95;
    var sx = box.left - host.left + box.width / 2 - w / 2, sy = box.top - host.top + box.height * 0.56 - h / 2;
    var art = PACK_ART[ub.contains] || PACK_ART.wnc;
    for (var i = 0; i < ub.count; i++) {
      var col = i % perRow, row = Math.floor(i / perRow);
      var x = x0 + col * (w + gap), y = y0 + row * (h + 14);
      var p = el("div", "upack", '<img src="' + art + '" alt="">');
      p.style.left = x + "px"; p.style.top = y + "px";
      p.onclick = openFromBox;
      holder.appendChild(p);
      p.animate([
        { transform: "translate(" + (sx - x) + "px," + (sy - y) + "px) scale(.35) rotate(" + (Math.random() * 40 - 20).toFixed(0) + "deg)", opacity: 0 },
        { opacity: 1, offset: 0.25 },
        { transform: "translate(0,0) scale(1) rotate(0deg)", opacity: 1 }
      ], { duration: 520, delay: i * 55, easing: "cubic-bezier(.2,.9,.3,1.15)", fill: "backwards" });
      (function (k) { setTimeout(function () { if (ub) sfx.flip(); }, k * 55 + 420); })(i);
    }
    setTimeout(function () {
      if (!ub) return;
      uhint(ub.count + " packs " + (state.store === "inventory" ? "in your inventory" : "on your shelf") + " &middot; pick one to open it");
      $("uboxActions").classList.remove("hidden");
    }, ub.count * 55 + 600);
  }
  function openFromBox() {
    if (!ub) return;
    var product = ub.contains;
    closeUnbox(true);
    emit("tcg:openPack", { product: product });
  }
  function closeUnbox(keepOpen) {
    if (!ub) return;
    ub = null;
    $("unbox").classList.add("hidden");
    $("uboxPacks").innerHTML = "";
    $("app").classList.remove("opening-on");
    if (keepOpen) return;
    $("binder").classList.remove("hidden");
    setTab("sealed");
  }

/* ---------------------------------------------------------------------------------------- wiring */
  function close() { if (op) return finishOpening(); if (ub) return closeUnbox(); hide(); emit("tcg:close", {}); }
  $("closeBtn").onclick = close;
  $("inspectClose").onclick = hideModals;
  $("prevBtn").onclick = function () { turn(-1); };
  $("nextBtn").onclick = function () { turn(1); };
  $("search").oninput = function (e) { ui.search = e.target.value; ui.spread = 0; renderBinder(); };
  $("printSearch").oninput = renderPrint;
  $("summaryDone").onclick = finishOpening;
  $("skipBtn").onclick = skipAll;
  $("uboxOpen").onclick = openFromBox;
  $("uboxBack").onclick = function () { closeUnbox(); };
  // A hold (the rare slot) ends wherever the button or the key is let go.
  document.addEventListener("keyup", function (e) { if (op && (e.key === " " || e.key === "Enter")) press(false); });
  document.addEventListener("pointerup", function () { if (op) press(false); });
  document.querySelectorAll(".tabs button").forEach(function (b) { b.onclick = function () { setTab(b.dataset.tab); }; });
  $("offerAccept").onclick = function () { if (ui.offer) emit("tcg:answer", { id: ui.offer.id, accept: true }); ui.offer = null; $("offer").classList.add("hidden"); };
  $("offerDecline").onclick = function () { if (ui.offer) emit("tcg:answer", { id: ui.offer.id, accept: false }); ui.offer = null; $("offer").classList.add("hidden"); };
  document.addEventListener("keydown", function (e) {
    if (!ui.open) return;
    if (e.key === "Escape") { if (!$("inspect").classList.contains("hidden")) hideModals(); else close(); e.preventDefault(); }
    else if (op && (e.key === " " || e.key === "Enter")) { if (!e.repeat) press(true); e.preventDefault(); }
    else if (ub && !ub.cut && (e.key === " " || e.key === "Enter")) { autoCut(); e.preventDefault(); }
    else if (!op && ui.tab === "binder" && $("inspect").classList.contains("hidden")) {
      if (e.key === "ArrowRight") turn(1); if (e.key === "ArrowLeft") turn(-1);
    }
  });

  on("tcg:state", function (s) {
    state.owned = parseCounts(s.owned); state.population = parseCounts(s.population);
    state.sealed = s.sealed || {}; state.dust = s.dust || 0; state.dustPlus = s.dustPlus || 0;
    state.prices = s.prices || {}; state.freeIn = s.freeIn || 0; state.paid = !!s.paid; state.shops = s.shops || [];
    state.store = s.store || "binder";
    if (s.extra && s.extra.unboxed) unboxResult(s.extra.unboxed, true);
    if (s.extra && s.extra.unboxFailed) unboxResult(s.extra.unboxFailed, false);
    if (inspecting) inspect(inspecting);
    if (ui.open && !op) renderAll(); else renderStats();
  });
  on("tcg:open", function (d) {
    ui.shop = d.shop || null; ui.nearby = d.nearby || [];
    show(); $("binder").classList.remove("hidden"); $("opening").classList.add("hidden"); $("app").classList.remove("opening-on");
    setTab(d.tab === "shop" ? "shop" : (d.tab || "binder"));
  });
  on("tcg:close", function (d) {
    if (op && d && d.force) { finishOpening(); return; }
    if (!op) hide();
  });
  on("tcg:shop", function (d) { ui.shop = d.shop || null; if (ui.open && ui.tab === "shop") renderShop(); });
  on("tcg:opening", startOpening);
  // A display used from a gamemode's inventory.
  on("tcg:unboxStart", function (d) { if (SEALED[d.product]) startUnbox(d.product); });
  // The server moved the opening on (a demo, the 90 s watchdog, a reveal from elsewhere): follow it silently.
  on("tcg:advance", function (d) {
    if (!op || d.seq !== op.seq) return;
    if (d.stage === "tear") { if (!op.torn) tear(true); return; }
    var target = Number(d.index) || 0;
    var step = function () {
      if (!op || op.summarised) return;
      if (op.index >= target) {
        if (target >= op.cards.length) setTimeout(function () { if (op && !op.summarised) summary(); }, 2600);
        return;
      }
      if (!op.torn) { tear(true); setTimeout(step, 900); return; }
      if (op.busy || !op.dealt) { setTimeout(step, 120); return; }
      next(true); setTimeout(step, 650);
    };
    step();
  });
  on("tcg:notice", function (n) { if (ui.open || ub) toast(n.text, n.kind); });
  on("tcg:offer", function (o) {
    ui.offer = o; var c = byId[o.edition]; if (!c) return;
    $("offerTitle").textContent = (o.name || "A collector") + " offers you " + c.name;
    var holder = $("offerCard"); holder.replaceWith(cardNode(c, "mid"));
    var shown = document.querySelector("#offer .card"); if (shown) shown.id = "offerCard";
    show(); $("offer").classList.remove("hidden");
  });

  // The catalogue ships as a script (data/catalogue.js): the page is ready at once, no fetch.
  catalogue = (window.TCG_CATALOGUE || []).slice().sort(function (a, b) { return a.n - b.n; });
  catalogue.forEach(function (c) { byId[c.id] = c; });
  buildChips();
  renderAll();
  if (O) { try { O.ready(); } catch (e) { console.error(e); } } else startPreview();

  /* ---------------------------------------------------------------------------------------- preview */
  function preview(name, d) {
    console.log("[preview] emit", name, d);
    if (name === "tcg:unbox" || name === "tcg:openPack") {
      var sealed = Object.assign({}, state.sealed);
      if ((sealed[d.product] || 0) <= 0) { toast("No " + d.product + " left", "error"); return; }
      sealed[d.product] -= 1;
      if (name === "tcg:unbox") sealed.wnc = (sealed.wnc || 0) + 24;
      state.sealed = sealed; renderStats(); if (ui.tab === "sealed" && !op && !ub) renderSealed();
      if (name === "tcg:unbox") {
        toast("You cut the shrink-wrap: 24 Welcome to Night City packs.");
        setTimeout(function () { unboxResult(d.product, true); }, 250);
        return;
      }
    }
    if (name === "tcg:openPack") {
      var pool = function (t) { return catalogue.filter(function (c) { return c.tier === t; }); };
      var pick = function (l) { return l[Math.floor(Math.random() * l.length)]; };
      var cards = []; for (var i = 0; i < 9; i++) cards.push(pick(pool(1)).id);
      cards.push(pick(pool(2)).id, pick(pool(2)).id, pick(pool(5)).id);
      handlers["tcg:opening"]({ seq: 1, product: d.product, cards: cards, fresh: "101101011001" });
    }
  }
  function startPreview() {
    document.body.style.background = "radial-gradient(ellipse at 40% 30%, #2b3a4a, #10161e 60%, #1d1410)";
    var owned = [];
    catalogue.forEach(function (c, i) { if (i % 3 !== 1) owned.push(c.id + ":" + (i % 7 === 0 ? 3 : 1)); });
    handlers["tcg:state"]({ owned: owned.join(","), population: "", sealed: { wnc: 3, beta: 1, box: 1 }, dust: 640, dustPlus: 2, prices: {}, freeIn: 0 });
    var params = new URLSearchParams(location.search);
    handlers["tcg:open"]({ tab: params.get("tab") || "binder", shop: params.get("shop") ? 1 : null, nearby: [{ id: 2, name: "Jerem Zzzer", distance: 1.4 }] });
    if (params.get("open")) {
      preview("tcg:openPack", { product: "wnc" });
      var reveal = Number(params.get("reveal") || 0);
      if (reveal) setTimeout(function () {
        autoTear();
        var k = 0, step = function () {
          if (!op || !op.dealt || op.busy) { setTimeout(step, 150); return; }
          if (k++ < reveal) { next(true); setTimeout(step, 900); }
        };
        setTimeout(step, 1500);
      }, 900);
    }
  }
})();
