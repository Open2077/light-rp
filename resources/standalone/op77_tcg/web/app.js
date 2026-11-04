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
    box: { label: "Booster Display", art: "img/ui/box_retail.webp", kind: "box" }
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
      open.onclick = function () { if (SEALED[k].kind === "box") emit("tcg:unbox", { product: k }); else emit("tcg:openPack", { product: k }); };
      b.appendChild(open); p.appendChild(b); shelf.appendChild(p);
    });
    $("sealedHint").textContent = any ? "Packs open in your hands: stand at a table and the cards are dealt on it for everyone around to see."
      : "No sealed product. Visit a Cyberpunk TCG shop counter.";
  }

  /* ---------------------------------------------------------------------------------------- shop */
  function renderShop() {
    var on = !!ui.shop;
    $("shopOff").classList.toggle("hidden", on);
    $("shopOn").classList.toggle("hidden", !on);
    if (!on) return;
    var prods = $("shopProducts"); prods.innerHTML = "";
    Object.keys(SEALED).forEach(function (k) {
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
  var op = null;
  function startOpening(d) {
    show();
    $("binder").classList.add("hidden");
    var o = $("opening"); o.classList.remove("hidden");
    $("app").classList.add("opening-on");
    var cards = (d.cards || []).map(function (id) { return byId[id]; }).filter(Boolean);
    op = { seq: d.seq, cards: cards, fresh: String(d.fresh || ""), index: 0, torn: false, busy: false };
    $("packImg").src = (SEALED[d.product] || SEALED.wnc).art;
    $("pack").className = "pack"; $("pack").classList.remove("hidden");
    $("tearFill").style.width = "0";
    $("stack").innerHTML = ""; $("revealed").innerHTML = ""; $("summary").classList.add("hidden");
    $("openingHint").textContent = "Drag across the top of the pack to tear it open";
    var pack = $("pack"), dragging = false, startX = 0;
    pack.onpointerdown = function (e) { if (op.torn) return; dragging = true; startX = e.clientX; pack.setPointerCapture(e.pointerId); };
    pack.onpointermove = function (e) {
      if (!dragging || op.torn) return;
      var r = pack.getBoundingClientRect();
      var pct = Math.max(0, Math.min(1, Math.abs(e.clientX - startX) / (r.width * 0.8)));
      $("tearFill").style.width = (pct * 100) + "%";
      if (pct >= 1) tear();
    };
    pack.onpointerup = function () { dragging = false; if (!op.torn) $("tearFill").style.width = "0"; };
  }
  function tear(silent) {
    if (!op || op.torn) return;
    op.torn = true;
    if (!silent) { emit("tcg:sfx", { name: "tear" }); emit("tcg:revealed", { seq: op.seq, stage: "tear" }); }
    var pack = $("pack"); pack.classList.add("shake");
    setTimeout(function () { pack.classList.remove("shake"); pack.classList.add("torn"); }, 250);
    setTimeout(function () {
      pack.classList.add("hidden");
      var stack = $("stack"); stack.innerHTML = "";
      for (var i = op.cards.length - 1; i >= 0; i--) {
        var c = op.cards[i];
        var f = el("div", "flipcard");
        f.innerHTML = '<div class="side back"><img src="img/backside.webp" alt=""></div><div class="side front"><img src="' + img(c) + '" alt=""></div>';
        f.style.transform = "translate(" + (i * 0.6) + "px," + (-i * 0.8) + "px)";
        f.dataset.index = String(i);
        stack.appendChild(f);
      }
      stack.onclick = next;
      $("openingHint").textContent = "Click or press SPACE to reveal the next card";
    }, 800);
  }
  function next(silent) {
    if (!op || !op.torn || op.busy) return;
    if (silent !== true) silent = false;
    if (op.index >= op.cards.length) return;
    var i = op.index, c = op.cards[i];
    var node = $("stack").querySelector('[data-index="' + i + '"]');
    op.busy = true;
    var last = i === op.cards.length - 1;
    var go = function () {
      node.style.transform = "";
      node.classList.add("up");
      if (c.tier >= 3) node.classList.add("glow-" + Math.min(6, c.tier));
      if (!silent) emit("tcg:revealed", { seq: op.seq, stage: "card", index: i + 1 });
      if (c.tier >= 4 || last) rarityMoment(c);
      var tag = op.fresh.charAt(i) === "1";
      if (tag) ui.fresh[c.id] = true;
      setTimeout(function () {
        if (!last) node.classList.add("gone");
        var mini = el("div", "mini"); mini.innerHTML = '<img src="' + img(c) + '" alt="">' + (tag ? '<div class="tag">NEW</div>' : "");
        $("revealed").appendChild(mini);
        op.index = i + 1; op.busy = false;
        if (last) setTimeout(summary, 1800);
      }, last ? 900 : 700);
    };
    if (last) {
      $("openingHint").textContent = "The rare slot...";
      $("stack").classList.add("shake");
      setTimeout(function () { $("stack").classList.remove("shake"); go(); }, 1300);
    } else go();
  }
  function rarityMoment(c) {
    var o = $("opening");
    var b = el("div", "rarity-banner", c.rarity); b.style.setProperty("--rc", rc(c)); o.appendChild(b);
    var burst = el("div", "burst"); burst.style.setProperty("--rc", rc(c)); o.appendChild(burst);
    setTimeout(function () { b.remove(); burst.remove(); }, 2300);
  }
  function summary() {
    var g = $("summaryGrid"); g.innerHTML = "";
    op.cards.forEach(function (c, i) {
      var e = el("div", "entry"); e.style.setProperty("--rc", rc(c));
      e.appendChild(cardNode(c));
      var isNew = op.fresh.charAt(i) === "1";
      e.appendChild(el("div", "tag " + (isNew ? "new" : "dup"), isNew ? "NEW" : "DUPE"));
      e.appendChild(el("div", "label", c.rarity));
      g.appendChild(e);
    });
    $("summary").classList.remove("hidden");
    $("openingHint").textContent = "";
  }
  function finishOpening() {
    if (!op) return;
    // Anything not revealed yet is revealed for the others at once.
    if (op.index < op.cards.length) emit("tcg:revealed", { seq: op.seq, stage: "card", index: op.cards.length });
    op = null;
    $("opening").classList.add("hidden");
    $("binder").classList.remove("hidden");
    $("app").classList.remove("opening-on");
    ui.tab = "binder"; ui.filter = "all"; buildChips();
    emit("tcg:openingDone", {});
    hide();
  }

  /* ---------------------------------------------------------------------------------------- wiring */
  function close() { if (op) return finishOpening(); hide(); emit("tcg:close", {}); }
  $("closeBtn").onclick = close;
  $("inspectClose").onclick = hideModals;
  $("prevBtn").onclick = function () { turn(-1); };
  $("nextBtn").onclick = function () { turn(1); };
  $("search").oninput = function (e) { ui.search = e.target.value; ui.spread = 0; renderBinder(); };
  $("printSearch").oninput = renderPrint;
  $("summaryDone").onclick = finishOpening;
  document.querySelectorAll(".tabs button").forEach(function (b) { b.onclick = function () { setTab(b.dataset.tab); }; });
  $("offerAccept").onclick = function () { if (ui.offer) emit("tcg:answer", { id: ui.offer.id, accept: true }); ui.offer = null; $("offer").classList.add("hidden"); };
  $("offerDecline").onclick = function () { if (ui.offer) emit("tcg:answer", { id: ui.offer.id, accept: false }); ui.offer = null; $("offer").classList.add("hidden"); };
  document.addEventListener("keydown", function (e) {
    if (!ui.open) return;
    if (e.key === "Escape") { if (!$("inspect").classList.contains("hidden")) hideModals(); else close(); e.preventDefault(); }
    else if (op && (e.key === " " || e.key === "Enter")) { if (!op.torn) tear(); else next(); e.preventDefault(); }
    else if (!op && ui.tab === "binder" && $("inspect").classList.contains("hidden")) {
      if (e.key === "ArrowRight") turn(1); if (e.key === "ArrowLeft") turn(-1);
    }
  });

  on("tcg:state", function (s) {
    state.owned = parseCounts(s.owned); state.population = parseCounts(s.population);
    state.sealed = s.sealed || {}; state.dust = s.dust || 0; state.dustPlus = s.dustPlus || 0;
    state.prices = s.prices || {}; state.freeIn = s.freeIn || 0; state.paid = !!s.paid; state.shops = s.shops || [];
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
  // The server moved the opening on (a demo, the 90 s watchdog, a reveal from elsewhere): follow it silently.
  on("tcg:advance", function (d) {
    if (!op || d.seq !== op.seq) return;
    if (d.stage === "tear") { if (!op.torn) tear(true); return; }
    var target = Number(d.index) || 0;
    var step = function () {
      if (!op || op.index >= target) return;
      if (!op.torn) { tear(true); setTimeout(step, 900); return; }
      if (op.busy) { setTimeout(step, 120); return; }
      next(true); setTimeout(step, 750);
    };
    step();
  });
  on("tcg:notice", function (n) { if (ui.open) toast(n.text, n.kind); });
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
    if (name === "tcg:openPack") {
      var pool = function (t) { return catalogue.filter(function (c) { return c.tier === t; }); };
      var pick = function (l) { return l[Math.floor(Math.random() * l.length)]; };
      var cards = []; for (var i = 0; i < 9; i++) cards.push(pick(pool(1)).id);
      cards.push(pick(pool(2)).id, pick(pool(2)).id, pick(pool(5)).id);
      handlers["tcg:opening"]({ seq: 1, product: d.product, cards: cards, fresh: "101101011001" });
    }
  }
  function startPreview() {
    var owned = [];
    catalogue.forEach(function (c, i) { if (i % 3 !== 1) owned.push(c.id + ":" + (i % 7 === 0 ? 3 : 1)); });
    handlers["tcg:state"]({ owned: owned.join(","), population: "", sealed: { wnc: 3, beta: 1, box: 1 }, dust: 640, dustPlus: 2, prices: {}, freeIn: 0 });
    var params = new URLSearchParams(location.search);
    handlers["tcg:open"]({ tab: params.get("tab") || "binder", shop: params.get("shop") ? 1 : null, nearby: [{ id: 2, name: "Jerem Zzzer", distance: 1.4 }] });
    if (params.get("open")) {
      preview("tcg:openPack", { product: "wnc" });
      var reveal = Number(params.get("reveal") || 0);
      if (reveal) setTimeout(function () {
        tear();
        var k = 0, step = function () { if (k++ < reveal) { next(); setTimeout(step, 1000); } };
        setTimeout(step, 1000);
      }, 900);
    }
  }
})();
