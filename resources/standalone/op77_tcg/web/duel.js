/* Cyberpunk TCG, the table side of the binder: the deck builder (official rules), the playmat, challenges, and the
   duel overlay while seated at a NEON DECK table. Talks through window.TCG (web/app.js) and client/duel.lua.
   In a plain browser it previews everything with a fake server (?tab=decks, ?tab=duel, ?duel=seated|mulligan|main). */
(function () {
  "use strict";
  var CARDS = window.TCG_CARDS || {};
  var RULES = { legends: 3, min: 40, max: 50, copies: 3, nameMax: 32 };
  var COLOURS = ["Red", "Green", "Blue", "Yellow"];
  var COLOUR_CSS = { Red: "#ff3d4a", Green: "#3fd28c", Blue: "#2fa4ff", Yellow: "#fcee09" };
  var TYPES = ["Legend", "Unit", "Gear", "Program"];
  var MATS = [
    { id: "netrunner", label: "Netrunner" }, { id: "arasaka", label: "Arasaka" }, { id: "militech", label: "Militech" },
    { id: "aldecaldo", label: "Aldecaldos" }, { id: "card0", label: "Night City" }, { id: "card1", label: "Afterlife" }
  ];
  var T = null;
  var $ = function (id) { return document.getElementById(id); };
  // An empty Lua table reaches the page as {} (JSON object), not []: every list from the client goes through list().
  function list(x) { return Array.isArray(x) ? x : (x && typeof x === "object" ? Object.keys(x).map(function (k) { return x[k]; }) : []); }
  var D = { decks: [], starters: [], playmat: "netrunner", selected: "", max: 12, asked: false };
  var edit = null;            // { key, name, legends: [], cards: { slug: n }, dirty }
  var pool = { type: "all", colour: "all", search: "", owned: true };
  var duel = { nearby: [], freeTables: 0, tables: 2, outgoing: null, incoming: null, match: null, matchAt: 0, cam: "seat",
               result: null, dismissed: {} };
  var art = {};               // base card slug -> its card picture (the first edition)
  var gameRenderer = null;    // web/table.js: the game once the setup is done

  function el(tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  function esc(s) { return T.escapeHtml(s == null ? "" : s); }
  function label(c) { return c.subtitle ? c.name + ": " + c.subtitle : c.name; }
  function parseCards(text) {
    var out = {};
    String(text || "").split(",").forEach(function (p) { var m = /^(\w+):(\d+)$/.exec(p); if (m) out[m[1]] = (out[m[1]] || 0) + Number(m[2]); });
    return out;
  }
  function encodeCards(cards) {
    return Object.keys(cards).filter(function (k) { return cards[k] > 0; }).sort().map(function (k) { return k + ":" + cards[k]; }).join(",");
  }
  function splitList(text) { return String(text || "").split(",").filter(Boolean); }

  // Copies owned per base card: every finish of every edition counts.
  function owned() {
    var out = {}, st = T.state().owned || {};
    T.catalogue().forEach(function (e) { var n = st[e.id] || 0; if (n > 0) out[e.card] = (out[e.card] || 0) + n; });
    return out;
  }

  // shared/decks.lua TcgDecks.validate, for live feedback (the server has the last word).
  function validate(deck, own) {
    var errors = [], names = {}, legends = list(deck.legends);
    if (legends.length !== RULES.legends) errors.push("Pick " + RULES.legends + " Legends (" + legends.length + "/" + RULES.legends + ").");
    var limits = { Red: 0, Green: 0, Blue: 0, Yellow: 0 }, used = { Red: 0, Green: 0, Blue: 0, Yellow: 0 };
    legends.forEach(function (slug) {
      var c = CARDS[slug];
      if (!c) { errors.push("Unknown Legend " + slug + "."); return; }
      if (c.type !== "Legend") { errors.push(label(c) + " is not a Legend."); return; }
      if (names[c.name]) errors.push("Two Legends named " + c.name + ": Legends need different names.");
      names[c.name] = true;
      if (own && (own[slug] || 0) < 1) errors.push("You don't own " + label(c) + ".");
      if (c.color && limits[c.color] != null && c.ram) limits[c.color] += c.ram;
    });
    var count = 0;
    Object.keys(deck.cards || {}).forEach(function (slug) {
      var n = deck.cards[slug], c = CARDS[slug];
      if (!c || n <= 0) return;
      count += n;
      if (c.type === "Legend") errors.push(label(c) + " is a Legend: Legends go in the three Legend slots.");
      if (n > RULES.copies) errors.push(n + " copies of " + label(c) + ": at most " + RULES.copies + ".");
      if (c.color && used[c.color] != null) {
        used[c.color] = Math.max(used[c.color], c.ram || 0);
        if ((c.ram || 0) > limits[c.color]) errors.push(label(c) + " needs " + (c.ram || 0) + " " + c.color + " RAM; your Legends give " + limits[c.color] + ".");
      }
      if (own && (own[slug] || 0) < n) errors.push(n + " copies of " + label(c) + " in the deck, you own " + (own[slug] || 0) + ".");
    });
    if (count < RULES.min) errors.push(count + " cards in the main deck: at least " + RULES.min + ".");
    if (count > RULES.max) errors.push(count + " cards in the main deck: at most " + RULES.max + ".");
    return { ok: errors.length === 0, errors: errors, count: count, limits: limits, used: used };
  }

  function cardImg(slug) { return art[slug] || "img/backside.webp"; }
  function miniCard(slug, cls) {
    var c = CARDS[slug] || {};
    var n = el("div", "tc " + (cls || ""));
    n.innerHTML = '<img alt="" loading="lazy" src="' + cardImg(slug) + '">';
    n.dataset.card = slug;
    return n;
  }
  function colourDot(c) { return '<i class="cdot" style="--c:' + (COLOUR_CSS[c.color] || "#777") + '"></i>'; }
  // Rules text: {Keyword} markers as keyword badges.
  function rulesHtml(text) {
    return esc(text || "").replace(/\{([^}]+)\}/g, '<b class="kw">$1</b>').replace(/\n/g, "<br>");
  }

  /* ------------------------------------------------------------------------------------------- decks tab */
  function allDecks() { return D.decks.concat(D.starters); }
  function deckByKey(key) { var all = allDecks(); for (var i = 0; i < all.length; i++) if (all[i].key === key) return all[i]; return null; }
  function legalDecks() { return allDecks().filter(function (d) { return d.ok; }); }

  function newEdit(from) {
    edit = { key: null, name: "New deck", legends: [], cards: {}, dirty: false };
    if (from) {
      edit.key = from.starter ? null : from.key;
      edit.name = from.starter ? (from.name + " (copy)").slice(0, RULES.nameMax) : from.name;
      edit.legends = splitList(from.legends);
      edit.cards = parseCards(from.cards);
      edit.dirty = !!from.starter;
    }
  }

  function renderDeckList() {
    var box = $("dkDecks"); box.innerHTML = "";
    $("dkCount").textContent = D.decks.length + " / " + D.max;
    if (!D.decks.length) box.appendChild(el("p", "hint", "No deck yet. Build one, or copy a starter deck the shop lends."));
    D.decks.forEach(function (d) {
      var it = el("button", "dk-item" + (edit && edit.key === d.key ? " on" : ""));
      var legs = splitList(d.legends);
      it.innerHTML = '<div class="dk-faces"></div><div class="grow"><b>' + esc(d.name) + "</b><small>" +
        (d.ok ? '<span class="ok">LEGAL</span> ' + d.count + " cards" : '<span class="bad">DRAFT</span> ' + esc((d.errors && d.errors[0]) || "")) +
        "</small></div>" + (D.selected === d.key ? '<span class="dk-star" title="Your duel deck">&#9733;</span>' : "");
      legs.slice(0, 3).forEach(function (s) { it.firstChild.appendChild(miniCard(s, "xs")); });
      it.onclick = function () { if (!confirmLeave()) return; newEdit(d); renderDecks(); };
      box.appendChild(it);
    });
    var st = $("dkStarters"); st.innerHTML = "";
    D.starters.forEach(function (d) {
      var it = el("div", "dk-item starter");
      it.innerHTML = '<div class="dk-faces"></div><div class="grow"><b>' + esc(d.name) + "</b><small>" + esc(d.subtitle || "") + "</small></div>";
      splitList(d.legends).forEach(function (s) { it.firstChild.appendChild(miniCard(s, "xs")); });
      var use = el("button", "ghost small" + (D.selected === d.key ? " on" : ""), D.selected === d.key ? "&#9733; Duel deck" : "Use");
      use.onclick = function (ev) { ev.stopPropagation(); T.emit("tcg:selectDeck", { key: d.key }); D.selected = d.key; renderDecks(); };
      var copy = el("button", "ghost small", "Copy");
      copy.onclick = function (ev) { ev.stopPropagation(); if (!confirmLeave()) return; newEdit(d); renderDecks(); };
      it.appendChild(use); it.appendChild(copy);
      st.appendChild(it);
    });
    $("dkNew").disabled = D.decks.length >= D.max;
  }

  var leaveArmed = 0;
  function confirmLeave() {
    if (!edit || !edit.dirty) return true;
    if (Date.now() - leaveArmed < 2500) return true;
    leaveArmed = Date.now();
    T.toast("Unsaved changes: click again to drop them.", "error");
    return false;
  }

  function addCard(slug) {
    var c = CARDS[slug]; if (!c) return;
    if (c.type === "Legend") {
      if (edit.legends.indexOf(slug) >= 0) return;
      if (edit.legends.length >= RULES.legends) return T.toast("Three Legends already: click one to take it out.", "error");
      for (var i = 0; i < edit.legends.length; i++) if (CARDS[edit.legends[i]].name === c.name) return T.toast("Your Legends need different names.", "error");
      edit.legends.push(slug);
    } else {
      var n = edit.cards[slug] || 0;
      if (n >= RULES.copies) return T.toast("At most " + RULES.copies + " copies of a card.", "error");
      edit.cards[slug] = n + 1;
    }
    edit.dirty = true; renderEditor();
  }
  function removeCard(slug) {
    var c = CARDS[slug]; if (!c) return;
    if (c.type === "Legend") edit.legends = edit.legends.filter(function (s) { return s !== slug; });
    else if (edit.cards[slug]) { edit.cards[slug] -= 1; if (!edit.cards[slug]) delete edit.cards[slug]; }
    edit.dirty = true; renderEditor();
  }

  function sortKey(slug) {
    var c = CARDS[slug];
    return [TYPES.indexOf(c.type), COLOURS.indexOf(c.color), c.cost == null ? 99 : c.cost, c.name];
  }
  function bySort(a, b) {
    var x = sortKey(a), y = sortKey(b);
    for (var i = 0; i < x.length; i++) { if (x[i] < y[i]) return -1; if (x[i] > y[i]) return 1; }
    return 0;
  }

  function renderPool(own) {
    var grid = $("dkPool"); grid.innerHTML = "";
    var q = pool.search.trim().toLowerCase();
    var list = Object.keys(CARDS).filter(function (slug) {
      var c = CARDS[slug];
      if (pool.type !== "all" && c.type !== pool.type) return false;
      if (pool.colour !== "all" && c.color !== pool.colour) return false;
      if (pool.owned && !(own[slug] > 0)) return false;
      if (q && (label(c) + " " + (c.tags || []).join(" ") + " " + (c.text || "")).toLowerCase().indexOf(q) < 0) return false;
      return true;
    }).sort(bySort);
    if (!list.length) grid.appendChild(el("p", "hint", pool.owned ? "None of your cards match. Untick \"Owned only\" to plan with the whole set." : "No card matches."));
    list.forEach(function (slug) {
      var c = CARDS[slug], have = own[slug] || 0;
      var inDeck = c.type === "Legend" ? (edit.legends.indexOf(slug) >= 0 ? 1 : 0) : (edit.cards[slug] || 0);
      var t = el("div", "dk-tile" + (have ? "" : " unowned") + (inDeck ? " in" : ""));
      t.appendChild(miniCard(slug));
      t.appendChild(el("div", "dk-badges", '<span class="own">x' + have + "</span>" + (inDeck ? '<span class="use">' + inDeck + "</span>" : "")));
      t.dataset.hint = "Click: add to the deck   Right click: take one out";
      t.onclick = function () { addCard(slug); };
      t.oncontextmenu = function (ev) { ev.preventDefault(); removeCard(slug); };
      grid.appendChild(t);
    });
  }

  function renderEditor() {
    if (!edit) newEdit(null);
    var own = owned();
    var v = validate(edit, own);
    $("dkName").value = edit.name;
    var saved = edit.key && deckByKey(edit.key);
    $("dkStatus").innerHTML = v.ok ? '<span class="ok">LEGAL</span>' : '<span class="bad">' + v.errors.length + " TO FIX</span>";
    if (edit.dirty) $("dkStatus").innerHTML += ' <span class="dirty">unsaved</span>';
    $("dkDelete").disabled = !saved;
    $("dkUse").disabled = !saved || !saved.ok || edit.dirty;
    $("dkUse").textContent = saved && D.selected === edit.key ? "★ Duel deck" : "Use for duels";
    // Legends
    var lg = $("dkLegends"); lg.innerHTML = "";
    for (var i = 0; i < RULES.legends; i++) {
      var slug = edit.legends[i];
      var s = el("div", "dk-legend" + (slug ? "" : " empty"));
      if (slug) {
        var c = CARDS[slug];
        s.appendChild(miniCard(slug, "md"));
        s.appendChild(el("div", "dk-leg-info", "<b>" + esc(c.name) + "</b><small>" + esc(c.subtitle) + "</small>" +
          '<span class="ram" style="--c:' + COLOUR_CSS[c.color] + '">' + (c.ram || 0) + " " + c.color + " RAM</span>"));
        s.dataset.hint = "Click: take this Legend out";
        s.onclick = (function (x) { return function () { removeCard(x); }; })(slug);
      } else {
        s.innerHTML = '<div class="tc md ph"><span>LEGEND ' + (i + 1) + "</span></div><div class=\"dk-leg-info\"><small>Pick a Legend in the pool</small></div>";
      }
      lg.appendChild(s);
    }
    // Meters
    $("dkMain").textContent = v.count;
    $("dkMain").className = v.count >= RULES.min && v.count <= RULES.max ? "ok" : "bad";
    var ram = $("dkRam"); ram.innerHTML = "";
    COLOURS.forEach(function (col) {
      var lim = v.limits[col], use = v.used[col];
      var r = el("div", "dk-ramrow" + (use > lim ? " over" : ""));
      var pips = "";
      for (var k = 1; k <= Math.max(6, lim, use); k++) pips += '<i class="' + (k <= lim ? "l" : "") + (k <= use ? " u" : "") + '"></i>';
      r.innerHTML = '<span class="n" style="--c:' + COLOUR_CSS[col] + '">' + col + '</span><span class="pips" style="--c:' + COLOUR_CSS[col] + '">' + pips +
        '</span><span class="v">' + use + " / " + lim + "</span>";
      ram.appendChild(r);
    });
    var er = $("dkErrors"); er.innerHTML = "";
    v.errors.slice(0, 6).forEach(function (e) { er.appendChild(el("li", "", esc(e))); });
    if (v.errors.length > 6) er.appendChild(el("li", "more", "+" + (v.errors.length - 6) + " more"));
    if (v.ok) er.appendChild(el("li", "good", "Ready for a duel."));
    // The deck list
    var dc = $("dkCards"); dc.innerHTML = "";
    var slugs = Object.keys(edit.cards).filter(function (s) { return edit.cards[s] > 0 && CARDS[s]; }).sort(bySort);
    TYPES.slice(1).forEach(function (type) {
      var group = slugs.filter(function (s) { return CARDS[s].type === type; });
      if (!group.length) return;
      var n = group.reduce(function (a, s) { return a + edit.cards[s]; }, 0);
      dc.appendChild(el("h4", "", type + "s <small>" + n + "</small>"));
      group.forEach(function (s) {
        var c = CARDS[s];
        var row = el("div", "dk-row" + ((own[s] || 0) < edit.cards[s] ? " short" : ""));
        row.innerHTML = '<span class="cost">' + (c.cost == null ? "-" : c.cost) + "</span>" + colourDot(c) + '<span class="nm">' + esc(label(c)) +
          '</span><span class="qty">' + edit.cards[s] + "</span>";
        var minus = el("button", "", "&minus;"), plus = el("button", "", "+");
        minus.onclick = function () { removeCard(s); }; plus.onclick = function () { addCard(s); };
        row.appendChild(minus); row.appendChild(plus);
        row.dataset.card = s;
        dc.appendChild(row);
      });
    });
    if (!slugs.length) dc.appendChild(el("p", "hint", "Click cards in the pool to add them. 40 to 50 cards, at most 3 of each."));
    renderPool(own);
    renderDeckList();
  }

  function buildPoolFilters() {
    var types = $("dkTypes"); types.innerHTML = "";
    ["all"].concat(TYPES).forEach(function (t) {
      var b = el("button", pool.type === t ? "on" : "", t === "all" ? "All" : t + "s");
      b.onclick = function () { pool.type = t; buildPoolFilters(); renderEditor(); };
      types.appendChild(b);
    });
    var cols = $("dkColours"); cols.innerHTML = "";
    ["all"].concat(COLOURS).forEach(function (c) {
      var b = el("button", pool.colour === c ? "on" : "", c === "all" ? "Any colour" : c);
      if (c !== "all") b.style.setProperty("--c", COLOUR_CSS[c]);
      b.onclick = function () { pool.colour = c; buildPoolFilters(); renderEditor(); };
      cols.appendChild(b);
    });
  }

  function renderDecks() {
    if (!D.asked) { D.asked = true; T.emit("tcg:decks", {}); }
    if (!edit) newEdit(D.decks.filter(function (d) { return d.key === D.selected; })[0] || D.decks[0] || null);
    renderEditor();
    // The deck guide opens by itself the first time (web/deckguide.js); the "Deck guide" button opens it again.
    var G = window.TCGDECKGUIDE;
    $("dkHelp").onclick = function () { if (G) G.show(0); };
    if (G && G.firstTime() && !G.isOpen()) setTimeout(function () { if ($("tab-decks") && !$("tab-decks").classList.contains("hidden")) G.show(0); }, 400);
  }

  /* ------------------------------------------------------------------------------------------- duel tab */
  function renderDuel() {
    if (!D.asked) { D.asked = true; T.emit("tcg:decks", {}); }
    if (!duel.askedNearby) { duel.askedNearby = true; T.emit("tcg:nearby", {}); }
    var mats = $("duMats"); mats.innerHTML = "";
    MATS.forEach(function (m) {
      var b = el("button", "du-mat" + (D.playmat === m.id ? " on" : ""));
      b.innerHTML = '<img alt="" src="img/mats/' + m.id + '.webp"><span>' + esc(m.label) + "</span>" + (D.playmat === m.id ? '<em>ON YOUR SIDE</em>' : "");
      b.onclick = function () { D.playmat = m.id; T.emit("tcg:setPlaymat", { id: m.id }); renderDuel(); };
      mats.appendChild(b);
    });
    // The duel in progress
    var cur = $("duCurrent");
    var m = duel.match;
    if (m) {
      var rival = m.seats[m.you === 1 ? 2 : 1];
      cur.className = "du-box live";
      cur.innerHTML = "<h3>Your duel</h3><p><b>vs " + esc(rival.name) + "</b> (" + esc(rival.deck) + ")<br>" + esc(m.label) + "</p><p class=\"hint\">" +
        (m.seats[m.you].seated ? "You are seated." : "Walk to your chair at the table (the yellow marker) and press <b>E</b>.") + "</p>";
      var lv = el("button", "ghost danger", "Leave the duel");
      lv.onclick = leaveClick(lv);
      cur.appendChild(lv);
    } else {
      cur.className = "du-box hidden";
    }
    // Deck pick
    var sel = $("duDeck"); sel.innerHTML = "";
    var legal = legalDecks();
    legal.forEach(function (d) {
      var o = el("option", "", esc(d.name) + (d.starter ? " (lent)" : "") + " - " + d.count + " cards");
      o.value = d.key; if (d.key === D.selected) o.selected = true; sel.appendChild(o);
    });
    if (!legal.length) sel.appendChild(el("option", "", "No legal deck yet"));
    if (legal.length && !deckByKey(D.selected)) { D.selected = legal[0].key; }
    var chosen = deckByKey(D.selected);
    $("duDeckHint").innerHTML = chosen ? "Legends: " + splitList(chosen.legends).map(function (s) { return esc(CARDS[s] ? CARDS[s].name : s); }).join(", ") : "Build one in the Decks tab.";
    sel.onchange = function () { D.selected = sel.value; T.emit("tcg:selectDeck", { key: sel.value }); renderDuel(); };
    // Players around
    $("duTables").textContent = duel.freeTables + " of " + duel.tables + " duel tables free at NEON DECK";
    var pl = $("duPlayers"); pl.innerHTML = "";
    if (!duel.nearby.length) pl.appendChild(el("p", "hint", "Nobody close enough. Stand next to the collector you want to play."));
    duel.nearby.forEach(function (p) {
      var row = el("div", "du-player");
      row.innerHTML = '<span class="grow"><b>' + esc(p.name) + "</b>" + (p.busy ? "<small>in a duel</small>" : "") + "</span>";
      var b = el("button", "primary small", "Challenge");
      b.disabled = !!p.busy || !chosen || !chosen.ok || !duel.freeTables || !!duel.match || !!duel.outgoing;
      b.onclick = function () { T.emit("tcg:challenge", { target: p.id, deck: D.selected }); };
      row.appendChild(b); pl.appendChild(row);
    });
    var out = $("duOutgoing"); out.innerHTML = "";
    if (duel.outgoing) {
      out.innerHTML = '<span class="pulse"></span>Waiting for <b>' + esc(duel.outgoing.name) + "</b> to answer... ";
      var c = el("button", "ghost small", "Cancel");
      c.onclick = function () { T.emit("tcg:cancelChallenge", { id: duel.outgoing.id }); duel.outgoing = null; renderDuel(); };
      out.appendChild(c);
    }
    var pill = $("duelPill");
    if (pill) pill.textContent = duel.incoming ? "!" : "";
  }

  function leaveClick(btn) {
    var armed = 0;
    return function () {
      if (Date.now() - armed < 3000) { T.emit("tcg:leaveMatch", {}); btn.textContent = "Leaving..."; return; }
      armed = Date.now();
      var phase = duel.match && duel.match.phase;
      btn.textContent = phase === "main" ? "Click again to concede" : "Click again to leave";
      setTimeout(function () { if (Date.now() - armed >= 3000) btn.textContent = btn.dataset.label || "Leave the table"; }, 3100);
    };
  }

  /* ------------------------------------------------------------------------------------------- challenges */
  function showChallenge() {
    var ch = duel.incoming;
    if (!ch) { $("challengeModal").classList.add("hidden"); return; }
    $("chTitle").textContent = (ch.name || "A collector") + " challenges you to a duel";
    $("chText").innerHTML = "Their deck: <b>" + esc(ch.deck) + "</b>. A NEON DECK table is set for you both as soon as you accept.";
    var sel = $("chDeck"); sel.innerHTML = "";
    var legal = legalDecks();
    legal.forEach(function (d) { var o = el("option", "", esc(d.name) + (d.starter ? " (lent)" : "")); o.value = d.key; if (d.key === D.selected) o.selected = true; sel.appendChild(o); });
    $("chAccept").disabled = !legal.length;
    if (!legal.length) sel.appendChild(el("option", "", "No legal deck: build one first"));
    T.show();
    $("challengeModal").classList.remove("hidden");
  }
  function answer(accept) {
    var ch = duel.incoming; if (!ch) return;
    T.emit("tcg:answerChallenge", { id: ch.id, accept: accept, deck: $("chDeck").value });
    duel.incoming = null;
    $("challengeModal").classList.add("hidden");
    renderBanner();
    if (T.ui.tab === "duel") renderDuel();
  }

  /* ------------------------------------------------------------------------------------------- the duel overlay */
  function remainingMs() {
    var m = duel.match;
    if (!m || m.deadline == null) return null;
    return Math.max(0, m.deadline - (Date.now() - duel.matchAt));
  }
  function clock(ms) { var s = Math.ceil(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

  function renderBanner() {
    var b = $("dhBanner"), m = duel.match, html = "";
    if (duel.result) {
      html = '<div class="dh-result ' + (duel.result.won ? "won" : "") + '"><b>' + (duel.result.won ? "VICTORY" : (duel.result.winner ? "DEFEAT" : "DUEL OVER")) +
        "</b><span>" + esc(duel.result.reason || "") + "</span></div>";
    } else if (m && !m.seats[m.you].seated) {
      var rival = m.seats[m.you === 1 ? 2 : 1], left = remainingMs();
      html = '<div class="dh-call"><span class="tag">DUEL</span><b>vs ' + esc(rival.name) + "</b><span>" + esc(m.label) +
        "</span><span>Walk to your chair (yellow marker) and press <kbd>E</kbd> to sit down</span>" + (left != null ? '<span class="clock"></span>' : "") + "</div>";
    } else if (duel.incoming && !T.ui.open) {
      html = '<div class="dh-call"><span class="tag">CHALLENGE</span><b>' + esc(duel.incoming.name) + "</b><span>challenges you to a duel - type <kbd>/tcgbinder</kbd> to answer</span></div>";
    }
    // Rebuilt only when it changes: a rebuild replays the entry animation.
    if (b.dataset.key !== html) { b.innerHTML = html; b.dataset.key = html; }
    tick(b);
    b.classList.toggle("hidden", !html);
    var seated = !!(m && m.seats[m.you].seated);
    $("dhSeated").classList.toggle("hidden", !seated);
    $("duelHud").classList.toggle("hidden", !html && !seated);
  }

  // The countdowns: only their text changes every half second.
  function tick(root) {
    var left = remainingMs();
    root.querySelectorAll(".clock").forEach(function (n) { n.textContent = left != null ? clock(left) : ""; });
  }

  function legendsHtml(seat) {
    return '<div class="dh-legends">' + seat.legends.map(function (l) {
      return '<i class="lg' + (l.spent ? " spent" : "") + '"' + (l.card ? ' data-card="' + l.card + '"' : "") + ">" +
        (l.card ? '<img src="' + cardImg(l.card) + '">' : "") + "</i>";
    }).join("") + "</div>";
  }
  function seatHtml(seat, mine) {
    var mul = seat.mulligan === "kept" ? "kept" : (seat.mulligan === "mulligan" ? "mulliganed" : "");
    return '<div class="dh-name"><b>' + esc(seat.name) + "</b><small>" + esc(seat.deck) + "</small></div>" + legendsHtml(seat) +
      '<div class="dh-counts"><span title="Cards in the deck"><i class="ico i-deck"></i>' + seat.library + "</span>" +
      (mine ? "" : '<span title="Cards in hand"><i class="ico i-hand"></i>' + seat.handCount + "</span>") +
      (seat.roll ? '<span title="d20 for the first player"><i class="ico i-d20"></i>' + seat.roll + "</span>" : "") +
      (mul ? "<span>" + mul + "</span>" : "") + "</div>";
  }

  function renderCentre() {
    var m = duel.match, c = $("dhCentre");
    var me = m.seats[m.you], rival = m.seats[m.you === 1 ? 2 : 1];
    var left = remainingMs(), html = "", buttons = [];
    var timer = left != null ? '<div class="clock"></div>' : "";
    if (m.phase === "seating") {
      html = "<h2>Waiting for " + esc(rival.name) + "</h2><p>They are on their way to the table.</p>";
    } else if (m.phase === "choose") {
      var mine = m.decider === m.you;
      html = '<div class="dh-dice"><div class="d20 ' + (me.roll > rival.roll ? "win" : "") + '"><span>' + me.roll + "</span><small>you</small></div>" +
        '<div class="d20 ' + (rival.roll > me.roll ? "win" : "") + '"><span>' + rival.roll + "</span><small>" + esc(rival.name) + "</small></div></div>" +
        (mine ? "<h2>You won the roll</h2><p>Who goes first? The first player starts with two Legends spent.</p>" :
          "<h2>" + esc(rival.name) + " won the roll</h2><p>They choose who goes first.</p>");
      if (mine) buttons = [["Go first", function () { T.emit("tcg:choose", { first: true }); }, "primary"],
                           ["Go second", function () { T.emit("tcg:choose", { first: false }); }, "ghost"]];
    } else if (m.phase === "mulligan") {
      var mineM = m.decider === m.you;
      var whoFirst = m.first === m.you ? "You go first" : esc(m.seats[m.first].name) + " goes first";
      html = "<h2>" + (mineM ? "Your opening hand" : "Waiting for " + esc(rival.name)) + "</h2><p>" + whoFirst + ". " +
        (mineM ? "Keep these six cards, or mulligan once: shuffle them back and draw six new ones." : "They keep their hand or mulligan.") + "</p>";
      if (mineM) buttons = [["Keep", function () { T.emit("tcg:mulligan", { again: false }); }, "primary"],
                            ["Mulligan", function () { T.emit("tcg:mulligan", { again: true }); }, "ghost"]];
    } else if (m.phase === "main") {
      var active = m.seats[m.active];
      html = '<h2 class="small">Turn ' + m.turn + " - " + (m.active === m.you ? "your turn" : esc(active.name) + "'s turn") + "</h2>";
      c.classList.add("compact");
    }
    if (m.phase !== "main") c.classList.remove("compact");
    var key = html + timer + buttons.map(function (b) { return b[0]; }).join("|");
    if (c.dataset.key === key) { tick(c); return; }
    c.dataset.key = key;
    c.innerHTML = html + timer;
    tick(c);
    if (buttons.length) {
      var row = el("div", "actions");
      buttons.forEach(function (b) { var n = el("button", b[2], b[0]); n.onclick = b[1]; row.appendChild(n); });
      c.appendChild(row);
    }
  }

  /* ------------------------------------------------------------------------------------------- the card preview */
  // Hovering any card picture (the hand, a visible card on the table, the deck builder) shows it large at the screen
  // edge, with its rules, its stats and what its keywords mean; on the left when the hovered card is on the right.
  var KEYWORDS = {
    "Play": "When you play this card.",
    "Attack": "When this Unit attacks: it is spent to declare the attack, the effect resolves before the React step.",
    "Call": "When this Legend is flipped face up by Call a Legend.",
    "Defeated": "When this card is defeated (its last state on the field counts).",
    "Adrenaline": "Can attack the turn it is played: it ignores Lag for attacking.",
    "Blocker": "When a rival Unit attacks, you may spend this Unit to become the attack's target instead.",
    "Go Solo": "Pay this Legend's cost to play it as a ready Unit that can attack this turn. If it leaves the field, it is removed from the game.",
    "Quick": "Can also be used as a reaction during the Rival's React step. Its cost is still paid.",
    "Spend": "Spend this Unit or Legend to use the effect. Lagging Units cannot."
  };
  var previewing = null;
  function cardPreview(slug, hint, onLeft) {
    var box = $("cardPreview");
    if (!box) { box = el("div", "hidden", ""); box.id = "cardPreview"; document.body.appendChild(box); }
    var c = slug && CARDS[slug];
    if (!c) { box.className = "hidden"; previewing = null; return; }
    var key = slug + "|" + (hint || "") + "|" + (onLeft ? "l" : "r");
    if (previewing === key) return;
    previewing = key;
    box.className = onLeft ? "left" : "";
    var stats = ['<span class="pv-type">' + esc(c.type) + "</span>"];
    if (c.cost != null) stats.push('<span class="pv-stat"><small>COST</small>' + c.cost + " &euro;$</span>");
    if (c.power != null) stats.push('<span class="pv-stat"><small>POWER</small>' + c.power + "</span>");
    if (c.color) stats.push('<span class="pv-stat ram" style="--c:' + (COLOUR_CSS[c.color] || "#888") + '"><small>' +
      (c.ram ? "RAM" : "COLOUR") + "</small>" + (c.ram ? c.ram + " " : "") + esc(c.color) + "</span>");
    if (c.sell) stats.push('<span class="pv-sell">SELL TAG</span>');
    var kws = (c.keywords || []).filter(function (k) { return KEYWORDS[k]; }).map(function (k) {
      return "<li><b>" + esc(k.toUpperCase()) + "</b> " + esc(KEYWORDS[k]) + "</li>";
    }).join("");
    var own = owned()[slug] || 0;
    box.innerHTML = "";
    box.appendChild(miniCard(slug, "xl"));
    box.appendChild(el("div", "pv-info", "<h3>" + esc(c.name) + "</h3>" + (c.subtitle ? "<h4>" + esc(c.subtitle) + "</h4>" : "") +
      '<div class="pv-stats">' + stats.join("") + "</div>" +
      (c.text ? '<div class="pv-text">' + rulesHtml(c.text) + "</div>" : "") +
      (kws ? '<ul class="pv-kw">' + kws + "</ul>" : "") +
      ((c.tags && c.tags.length) ? '<div class="pv-tags">' + c.tags.map(esc).join(" &middot; ") + "</div>" : "") +
      '<div class="pv-own">In your binder: <b>' + own + "</b></div>" +
      (hint ? '<div class="pv-hint">' + esc(hint) + "</div>" : "")));
  }
  document.addEventListener("mouseover", function (e) {
    var n = e.target.closest ? e.target.closest("[data-card]") : null;
    if (n && n.closest("#cardPreview")) n = null;
    if (!n) { if (previewing) cardPreview(null); return; }
    var hintNode = n.closest("[data-hint]");
    // At the table: always on the right. In the binder: on the left when the card hovered is on the right half.
    cardPreview(n.dataset.card, hintNode ? hintNode.dataset.hint : "", !n.closest("#duelHud") && e.clientX > window.innerWidth * 0.55);
  });

  function zoom(slug) {
    var z = $("dhZoom"), c = CARDS[slug];
    if (!slug || !c) { z.classList.add("hidden"); return; }
    z.innerHTML = "";
    z.appendChild(miniCard(slug, "xl"));
    z.appendChild(el("div", "dh-zinfo", "<h3>" + esc(c.name) + "</h3><small>" + esc(c.subtitle) + "</small><p>" + esc(c.type) +
      (c.cost != null ? " - cost " + c.cost : "") + (c.power != null ? " - power " + c.power : "") + (c.ram ? " - " + c.ram + " " + c.color + " RAM" : "") +
      (c.sell ? " - Sell Tag" : "") + "</p><div class=\"txt\">" + rulesHtml(c.text) + "</div>" +
      ((c.tags && c.tags.length) ? '<div class="tags">' + c.tags.map(esc).join(" &middot; ") + "</div>" : "")));
    z.classList.remove("hidden");
    z.onclick = function () { z.classList.add("hidden"); };
  }

  function renderHand() {
    var m = duel.match, h = $("dhHand");
    var hand = splitList(m.hand);
    if (h.dataset.hand === m.hand) return;
    h.dataset.hand = m.hand;
    h.innerHTML = "";
    var n = hand.length;
    hand.forEach(function (slug, i) {
      var k = el("div", "dh-card");
      var mid = (n - 1) / 2;
      k.style.setProperty("--r", ((i - mid) * 4).toFixed(1) + "deg");
      k.style.setProperty("--y", (Math.abs(i - mid) * Math.abs(i - mid) * 3).toFixed(1) + "px");
      k.style.setProperty("--d", (i * 70) + "ms");
      k.appendChild(miniCard(slug, "lg"));
      k.dataset.hint = "Your hand";
      h.appendChild(k);
    });
  }

  function renderHud() {
    renderBanner();
    var m = duel.match;
    if (!m || !m.seats[m.you].seated) return;
    var me = m.seats[m.you], rival = m.seats[m.you === 1 ? 2 : 1];
    $("dhRival").innerHTML = seatHtml(rival, false);
    $("dhYou").innerHTML = seatHtml(me, true);
    // Only the lines that are new slide in (a rebuild would replay every line).
    var logBox = $("dhLog"), lines = list(m.log).slice(-6), before = logBox.dataset.lines ? JSON.parse(logBox.dataset.lines) : [];
    if (JSON.stringify(lines) !== logBox.dataset.lines) {
      var shift = 0;
      while (shift < before.length && JSON.stringify(before.slice(shift)) !== JSON.stringify(lines.slice(0, before.length - shift))) shift++;
      var known = before.length - shift;
      logBox.innerHTML = lines.map(function (l, i) { return "<p" + (i >= known ? ' class="new"' : "") + ">" + esc(l) + "</p>"; }).join("");
      logBox.dataset.lines = JSON.stringify(lines);
    }
    $("dhSeated").classList.toggle("game", m.phase === "game");
    if (m.phase === "game" && gameRenderer) { gameRenderer.render(m); return; }
    if (gameRenderer) gameRenderer.clear();
    renderCentre();
    renderHand();
    $("dhView").textContent = "View: " + duel.cam;
  }

  /* ------------------------------------------------------------------------------------------- events */
  function bind() {
    T.on("tcg:decks", function (d) {
      D.decks = list(d.decks); D.starters = list(d.starters); D.playmat = d.playmat || D.playmat; D.selected = d.selected || "";
      D.max = d.max || D.max;
      var ex = d.extra || {};
      if (ex.saved && edit) { edit.key = ex.saved; edit.dirty = false; }
      if (ex.deleted && edit && edit.key === ex.deleted) newEdit(D.decks[0] || null);
      if (T.ui.open && T.ui.tab === "decks") renderDecks();
      if (T.ui.open && T.ui.tab === "duel") renderDuel();
      if (duel.incoming && !$("challengeModal").classList.contains("hidden")) showChallenge();
    });
    T.on("tcg:nearby", function (d) {
      duel.nearby = list(d.players); duel.freeTables = d.freeTables || 0; duel.tables = d.tables || 2;
      if (T.ui.open && T.ui.tab === "duel") renderDuel();
    });
    T.on("tcg:challenged", function (d) {
      duel.incoming = d;
      if (T.ui.open) showChallenge();
      renderBanner();
      if (T.ui.tab === "duel") renderDuel();
    });
    T.on("tcg:challengeSent", function (d) { duel.outgoing = d; if (T.ui.tab === "duel") renderDuel(); });
    T.on("tcg:challengeClosed", function (d) {
      if (duel.outgoing && duel.outgoing.id === d.id) duel.outgoing = null;
      if (duel.incoming && duel.incoming.id === d.id) {
        duel.incoming = null; $("challengeModal").classList.add("hidden");
        if (d.reason === "cancelled" || d.reason === "expired" || d.reason === "left") T.toast("The challenge was withdrawn.");
      }
      if (d.reason === "declined") T.toast("Your challenge was declined.");
      renderBanner();
      if (T.ui.tab === "duel") renderDuel();
    });
    T.on("tcg:match", function (d) {
      if (d.ended || d.none) {
        if (d.ended) {
          duel.result = { won: d.won, winner: d.winner, reason: d.reason };
          setTimeout(function () { duel.result = null; renderBanner(); }, 7000);
        }
        duel.match = null; zoom(null);
        $("dhHand").dataset.hand = "";
        if (gameRenderer) gameRenderer.clear();
      } else {
        // Lua's seats 1 and 2 arrive as a JSON array: index them by seat number again.
        if (Array.isArray(d.seats)) d.seats = { 1: d.seats[0], 2: d.seats[1] };
        [1, 2].forEach(function (i) { var s = d.seats[i]; if (s && !Array.isArray(s.legends)) s.legends = []; });
        if (!Array.isArray(d.log)) d.log = [];
        if (!duel.match || duel.match.id !== d.id) { duel.cam = "seat"; duel.outgoing = null; }
        duel.match = d; duel.matchAt = Date.now();
        // Seated: the binder steps aside for the table.
        // At the table the binder is put away: decks are built before a duel, never during one.
        if (d.seats[d.you].seated && T.ui.open && !T.isBusy()) T.closeBinder();
      }
      renderHud();
      if (T.ui.open && T.ui.tab === "duel") renderDuel();
    });
    T.on("tcg:cameraMode", function (d) { duel.cam = d.mode || "seat"; $("dhView").textContent = "View: " + duel.cam; });

    $("dkNew").onclick = function () { if (!confirmLeave()) return; newEdit(null); renderDecks(); };
    $("dkName").oninput = function (e) { edit.name = e.target.value.slice(0, RULES.nameMax); edit.dirty = true; $("dkStatus").innerHTML = $("dkStatus").innerHTML.replace(/ <span class="dirty">unsaved<\/span>/, "") + ' <span class="dirty">unsaved</span>'; };
    $("dkSave").onclick = function () {
      T.emit("tcg:saveDeck", { key: edit.key, name: edit.name, legends: edit.legends.join(","), cards: encodeCards(edit.cards) });
    };
    $("dkUse").onclick = function () { if (edit.key) { T.emit("tcg:selectDeck", { key: edit.key }); D.selected = edit.key; renderEditor(); } };
    var delArmed = 0;
    $("dkDelete").onclick = function () {
      if (!edit.key) return;
      if (Date.now() - delArmed > 2500) { delArmed = Date.now(); T.toast("Click Delete again to throw this deck away.", "error"); return; }
      T.emit("tcg:deleteDeck", { key: edit.key });
    };
    $("dkSearch").oninput = function (e) { pool.search = e.target.value; renderPool(owned()); };
    $("dkOwnedOnly").onchange = function (e) { pool.owned = e.target.checked; renderPool(owned()); };
    buildPoolFilters();
    $("duRefresh").onclick = function () { T.emit("tcg:nearby", {}); };
    $("duTutorial").onclick = function () { T.emit("tcg:tutorial", {}); T.closeBinder(); };
    $("chAccept").onclick = function () { answer(true); };
    $("chDecline").onclick = function () { answer(false); };
    $("dhView").onclick = function () { T.emit("tcg:camera", { mode: "next" }); };
    $("dhLeave").dataset.label = "Leave the table";
    $("dhLeave").onclick = leaveClick($("dhLeave"));
    document.addEventListener("keydown", function (e) {
      if (!duel.match || T.ui.open) return;
      if (e.key === "Escape") zoom(null);
      if (e.key === "v" || e.key === "V") T.emit("tcg:camera", { mode: "next" });
    });
    // The clocks, the pending challenge when the binder opens, the duel tab's player list.
    setInterval(function () {
      if (duel.match && duel.match.deadline != null) {
        if (!duel.match.seats[duel.match.you].seated) renderBanner();
        else if (duel.match.phase === "game") { if (gameRenderer) gameRenderer.tick(); }
        else renderCentre();
      }
      if (duel.incoming && T.ui.open && $("challengeModal").classList.contains("hidden")) showChallenge();
      if (duel.incoming && !T.ui.open) renderBanner();
    }, 500);
    setInterval(function () { if (T.ui.open && T.ui.tab === "duel") T.emit("tcg:nearby", {}); }, 5000);
  }

  function init() {
    if (T) return;
    T = window.TCG;
    var best = {};
    T.catalogue().forEach(function (e) {
      var b = best[e.card];
      var score = e.tier * 10 + (e.finish === "sleeved" ? 0 : 1);
      if (!b || score < b.score || (score === b.score && e.n < b.n)) best[e.card] = { score: score, n: e.n, id: e.id };
    });
    Object.keys(best).forEach(function (k) { art[k] = "img/cards/" + best[k].id + ".webp"; });
    T.tab("decks", renderDecks);
    T.tab("duel", renderDuel);
    // What web/table.js (the game at the table) uses from here.
    window.TCGDUEL = {
      T: T, CARDS: CARDS, COLOUR_CSS: COLOUR_CSS, cardImg: cardImg, miniCard: miniCard, esc: esc, label: label, el: el,
      clock: clock, remainingMs: remainingMs, duel: duel, splitList: splitList, legendsHtml: legendsHtml,
      setGameRenderer: function (r) { gameRenderer = r; }
    };
    document.dispatchEvent(new Event("tcg:duelReady"));
    bind();
    if (T.preview) previewSetup();
  }
  if (window.TCG) init(); else document.addEventListener("tcg:binderReady", init);

  /* ------------------------------------------------------------------------------------------- preview (no game) */
  function previewSetup() {
    var H = T.previewHandlers;
    var params = new URLSearchParams(location.search);
    var mine = [];
    function fire(name, d) { setTimeout(function () { if (H[name]) H[name](d); }, 120); }
    function decksPayload(extra) {
      var own = owned();
      return { decks: mine.map(function (d) { var v = validate({ legends: splitList(d.legends), cards: parseCards(d.cards) }, own);
        return { key: d.key, name: d.name, legends: d.legends, cards: d.cards, ok: v.ok, errors: v.errors.slice(0, 4), count: v.count }; }),
        starters: [
          { key: "s:embracing_power", name: "Embracing Power", subtitle: "Arasaka starter deck - Red / Green", ok: true, count: 40, starter: true,
            legends: "goro_takemura_hands_unclean,saburo_arasaka_stubborn_patriarch,yorinobu_arasaka_embracing_destruction",
            cards: "arasaka_emergency_radioport:2,chrome_fang:2,corpo_security:3,corporate_surveillance:3,emergency_atlus:2,field_operator:2,goro_takemura_losing_his_way:2,industrial_assembly:2,mantis_blades:3,maxtac_av:2,minotaur:2,over_the_edge:2,ruthless_lowlife:3,sandevistan:3,satori_sword_of_saburo:3,shattered_memories:2,swordwise_huscle:2" },
          { key: "s:the_heist", name: "The Heist", subtitle: "Mercs starter deck - Blue / Yellow", ok: true, count: 40, starter: true,
            legends: "v_corporate_exile,jackie_welles_pour_one_out_for_me,viktor_vektor_sit_down_and_relax", cards: "" }],
        playmat: D.playmat, selected: D.selected || "s:embracing_power", max: 12, extra: extra };
    }
    var hands = ["mantis_blades", "corpo_security", "sandevistan", "ruthless_lowlife", "chrome_fang", "maxtac_av"];
    var view = { id: 7, slot: "nd_a", label: "NEON DECK - Table 1 A", you: 1, phase: "seating", deadline: 170000, decider: 1, first: 1, turn: 0, active: 1,
      hand: "", log: ["Yuki vs Jerem Zzzer at NEON DECK - Table 1 A."],
      seats: [{ name: "Yuki", side: "south", playmat: "netrunner", seated: false, deck: "Embracing Power", library: 40, handCount: 0, legends: [] },
              { name: "Jerem Zzzer", side: "north", playmat: "arasaka", seated: true, deck: "The Heist", library: 40, handCount: 0, legends: [] }] };
    function setup() {
      view.phase = "choose"; view.seats[0].roll = 17; view.seats[1].roll = 9; view.decider = 1; view.deadline = 25000;
      view.log.push("d20: Yuki rolls 17, Jerem Zzzer rolls 9.", "Yuki chooses who goes first.");
    }
    function deal(first) {
      view.first = first; view.phase = "mulligan"; view.decider = first; view.deadline = 60000; view.hand = hands.join(",");
      view.seats.forEach(function (s, i) { s.library = 34; s.handCount = 6; s.mulligan = "deciding";
        s.legends = [{ spent: i + 1 === first }, { spent: i + 1 === first }, { spent: false }]; });
      view.log.push((first === 1 ? "Yuki" : "Jerem Zzzer") + " goes first.");
    }
    window.TCG_PREVIEW_HOOK = function (name, d) {
      if (window.TCG_PREVIEW_HOOK_GAME && window.TCG_PREVIEW_HOOK_GAME(name, d)) return true;
      if (name === "tcg:decks") { fire("tcg:decks", decksPayload()); return true; }
      if (name === "tcg:saveDeck") {
        var key = d.key || String(100 + mine.length);
        mine = mine.filter(function (x) { return x.key !== key; }).concat([{ key: key, name: d.name, legends: d.legends, cards: d.cards }]);
        T.toast("Deck saved: " + d.name + "."); fire("tcg:decks", decksPayload({ saved: key })); return true;
      }
      if (name === "tcg:deleteDeck") { mine = mine.filter(function (x) { return x.key !== d.key; }); fire("tcg:decks", decksPayload({ deleted: d.key })); return true; }
      if (name === "tcg:selectDeck") { D.selected = d.key; fire("tcg:decks", decksPayload()); return true; }
      if (name === "tcg:setPlaymat") { D.playmat = d.id; return true; }
      if (name === "tcg:nearby") { fire("tcg:nearby", { players: [{ id: 2, name: "Jerem Zzzer" }, { id: 4, name: "Kiri", busy: true }], freeTables: 2, tables: 2 }); return true; }
      if (name === "tcg:challenge") {
        fire("tcg:challengeSent", { id: 1, to: 2, name: "Jerem Zzzer" });
        setTimeout(function () { H["tcg:challengeClosed"]({ id: 1, reason: "accepted" }); H["tcg:match"](JSON.parse(JSON.stringify(view))); }, 1800);
        return true;
      }
      if (name === "tcg:answerChallenge") { if (d.accept) fire("tcg:match", JSON.parse(JSON.stringify(view))); return true; }
      if (name === "tcg:sit") { view.seats[0].seated = true; setup(); fire("tcg:match", JSON.parse(JSON.stringify(view))); return true; }
      if (name === "tcg:choose") { deal(d.first ? 1 : 2); fire("tcg:match", JSON.parse(JSON.stringify(view))); return true; }
      if (name === "tcg:mulligan") {
        view.seats[0].mulligan = d.again ? "mulligan" : "kept"; view.seats[1].mulligan = "kept";
        if (d.again) view.hand = ["kiroshi_optics", "corporate_surveillance", "field_operator", "mantis_blades", "over_the_edge", "minotaur"].join(",");
        view.phase = "main"; view.turn = 1; view.active = view.first; view.deadline = null; view.log.push("The game begins: turn 1.");
        fire("tcg:match", JSON.parse(JSON.stringify(view))); return true;
      }
      if (name === "tcg:leaveMatch") { fire("tcg:match", { id: 7, ended: true, won: false, winner: "Jerem Zzzer", reason: "Yuki conceded." }); return true; }
      if (name === "tcg:camera") { var modes = ["seat", "table", "mat"]; fire("tcg:cameraMode", { mode: modes[(modes.indexOf(duel.cam) + 1) % 3] }); return true; }
      return false;
    };
    var dm = params.get("duel");
    if (["walk", "seated", "mulligan", "main"].indexOf(dm) >= 0) {
      setTimeout(function () {
        T.hide();
        if (dm === "walk") { view.seats[0].seated = false; }
        else {
          view.seats[0].seated = true; setup();
          if (dm === "mulligan" || dm === "main") deal(1);
          if (dm === "main") { view.phase = "main"; view.turn = 1; view.deadline = null; view.seats[0].mulligan = "kept"; view.seats[1].mulligan = "kept"; }
        }
        H["tcg:match"](JSON.parse(JSON.stringify(view)));
      }, 400);
    }
    if (params.get("challenged")) setTimeout(function () { H["tcg:challenged"]({ id: 3, from: 2, name: "Jerem Zzzer", deck: "The Heist", ms: 60000 }); }, 600);
  }
})();
