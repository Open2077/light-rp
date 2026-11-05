/* Cyberpunk TCG: the game at the duel table (after the setup). The server plays the rules (shared/game.lua); this
   page shows the table state, lights up what you may do and animates what happens: draws, Gig rolls, plays, attacks.
   - Top: the rival's board (their Units, their Gigs). Bottom: yours, your hand, your Legends and €$.
   - Click a card in your hand: Play / Sell (Gear: then click the Unit or face-up Legend to equip).
   - Click one of your Units: Attack, then click their Gigs or one of their spent Units.
   - Your Legends: Call (face down, 1 €$) or Play to the field / Go Solo (face up).
   In a plain browser: index.html?duel=game | react | steal | roll (a static table for the look). */
(function () {
  "use strict";
  var X = null;          // window.TCGDUEL (web/duel.js)
  var $ = function (id) { return document.getElementById(id); };
  var sel = null;        // { kind: "equip", hand, card } | { kind: "attack", uid } | { kind: "steal", picks: [] }
  var seenEvents = null; // the events of the last view, so a re-render does not replay them
  var handKeys = [];     // the hand last drawn (slug#occurrence), to animate only the new cards

  function arr(x) { return Array.isArray(x) ? x : (x && typeof x === "object" ? Object.keys(x).map(function (k) { return x[k]; }) : []); }
  function el(tag, cls, html) { return X.el(tag, cls, html); }
  function esc(s) { return X.esc(s); }
  function act(type, extra) { var d = extra || {}; d.type = type; X.T.emit("tcg:act", d); }
  function card(slug) { return X.CARDS[slug] || {}; }
  function rivalOf(m) { return m.seats[m.you === 1 ? 2 : 1]; }

  function normalise(m) {
    [1, 2].forEach(function (i) {
      var s = m.seats[i];
      if (!s) return;
      s.field = arr(s.field); s.gigs = arr(s.gigs); s.fixer = arr(s.fixer); s.legends = arr(s.legends);
    });
    m.events = arr(m.events);
    m.options = m.options || {};
    m.options.roll = arr(m.options.roll);
    m.options.attackers = arr(m.options.attackers);
    m.options.blockers = arr(m.options.blockers);
    m.options.activate = arr(m.options.activate);
    m.options.quick = arr(m.options.quick);
    m.options.costs = arr(m.options.costs);
    if (m.prompt) m.prompt.options = arr(m.prompt.options);
  }

  /* ------------------------------------------------------------------------------------------- pieces */
  function dieNode(kind, value, owner, cls) {
    var d = el("div", "tb-die " + kind + " o" + owner + (cls ? " " + cls : ""));
    d.innerHTML = "<b>" + (value == null ? kind.slice(1) : value) + "</b><small>" + kind + "</small>";
    return d;
  }

  // A Unit on the board: its card, power, Lag, Gear, spent sideways. Keyed by uid so it is not rebuilt.
  function unitNode(u, mine) {
    var n = el("div", "tb-unit");
    n.dataset.uid = u.uid;
    var face = X.miniCard(u.card, "bd");
    n.appendChild(face);
    n.appendChild(el("span", "tb-pow", ""));
    n.appendChild(el("span", "tb-tags", ""));
    n.classList.add("enter");
    setTimeout(function () { n.classList.remove("enter"); }, 600);
    n.addEventListener("click", function (ev) { ev.stopPropagation(); unitClick(u.uid, mine); });
    return n;
  }
  function updateUnit(n, u, m, mine) {
    n.classList.toggle("spent", !!u.spent);
    n.classList.toggle("lag", !!u.lag && !u.solo);
    n.querySelector(".tb-pow").textContent = u.power;
    var tags = [];
    if (u.legend) tags.push(u.solo ? "GO SOLO" : "LEGEND");
    if (u.lag && !u.solo) tags.push("LAG");
    var gear = X.splitList(u.gear);
    if (gear.length) tags.push("+" + gear.length + " GEAR");
    n.querySelector(".tb-tags").textContent = tags.join(" · ");
    var o = m.options;
    var can = false;
    if (mine && m.step === "main" && o.mine) can = o.attackers.indexOf(u.uid) >= 0 || (sel && sel.kind === "equip");
    if (mine && m.step === "react" && o.blockers.length) can = o.blockers.indexOf(u.uid) >= 0;
    if (!mine && sel && sel.kind === "attack") can = !!u.spent;
    n.classList.toggle("can", can);
    n.classList.toggle("attacking", !!(m.attack && m.attack.attacker === u.uid));
    n.classList.toggle("target", !!(m.attack && m.attack.target === u.uid));
    n.classList.toggle("picked", !!(sel && sel.kind === "attack" && sel.uid === u.uid));
  }

  // Keyed list: new nodes animate in, gone ones fade out.
  function keyed(box, items, key, make, update) {
    var have = {};
    Array.prototype.forEach.call(box.children, function (c) { if (c.dataset.key) have[c.dataset.key] = c; });
    var keep = {};
    items.forEach(function (it, i) {
      var k = key(it);
      keep[k] = true;
      var n = have[k];
      if (!n) { n = make(it); n.dataset.key = k; }
      update(n, it, i);
      if (box.children[i] !== n) box.insertBefore(n, box.children[i] || null);
    });
    Object.keys(have).forEach(function (k) {
      if (keep[k]) return;
      var n = have[k];
      delete n.dataset.key;
      n.classList.add("leave");
      setTimeout(function () { if (n.parentNode) n.parentNode.removeChild(n); }, 380);
    });
  }

  function boardHtml(box, seat, m, mine) {
    if (!box.querySelector(".tb-field")) {
      box.innerHTML = '<div class="tb-gigs"></div><div class="tb-field"></div>';
      box.querySelector(".tb-gigs").addEventListener("click", function (ev) { if (!ev.target.closest(".tb-die")) gigAreaClick(mine); });
    }
    var field = box.querySelector(".tb-field"), gigs = box.querySelector(".tb-gigs");
    keyed(field, seat.field, function (u) { return "u" + u.uid; }, function (u) { return unitNode(u, mine); },
      function (n, u) { updateUnit(n, u, m, mine); });
    field.classList.toggle("empty", seat.field.length === 0);
    keyed(gigs, seat.gigs, function (g) { return "g" + g.uid; }, function (g) {
      var d = dieNode(g.kind, g.value, g.owner === m.you ? "me" : "rv", "enter");
      d.dataset.uid = g.uid;
      setTimeout(function () { d.classList.remove("enter"); }, 600);
      d.addEventListener("click", function (ev) { ev.stopPropagation(); gigClick(g.uid, mine); });
      return d;
    }, function (n, g) {
      n.classList.toggle("pickable", !mine && sel && sel.kind === "steal");
      n.classList.toggle("picked", !!(sel && sel.kind === "steal" && sel.picks.indexOf(g.uid) >= 0));
    });
    var cred = seat.streetCred;
    gigs.dataset.count = seat.gigs.length + " / 7 Gigs" + (cred != null ? "  ·  Street Cred " + cred : "");
    gigs.classList.toggle("target", !mine && ((sel && sel.kind === "attack") || (m.attack && m.attack.target === "gigs" && m.attack.owner === m.you)));
    gigs.classList.toggle("threat", mine && m.attack && m.attack.target === "gigs" && m.attack.defender === m.you);
  }

  /* ------------------------------------------------------------------------------------------- your hand */
  function renderHand(m) {
    var h = $("dhHand");
    var hand = X.splitList(m.hand);
    var counts = {}, keys = hand.map(function (s) { counts[s] = (counts[s] || 0) + 1; return s + "#" + counts[s]; });
    var drawn = m.events.filter(function (e) { return e.kind === "draw" && e.seat === m.you; }).length;
    var fresh = {};
    // The cards new since the last view; on a first view (a reconnect), only the ones just drawn.
    if (drawn && handKeys.length) keys.forEach(function (k) { if (handKeys.indexOf(k) < 0) fresh[k] = true; });
    else if (drawn) keys.slice(-drawn).forEach(function (k) { fresh[k] = true; });
    handKeys = keys;
    // Rebuild only when the hand changes; otherwise refresh what is playable.
    if (h.dataset.hand !== m.hand) {
      h.dataset.hand = m.hand;
      h.innerHTML = "";
      var n = hand.length, mid = (n - 1) / 2, k = 0;
      hand.forEach(function (slug, i) {
        var c = el("div", "dh-card");
        c.style.setProperty("--r", ((i - mid) * Math.min(4, 22 / Math.max(1, n))).toFixed(1) + "deg");
        c.style.setProperty("--y", (Math.abs(i - mid) * Math.abs(i - mid) * Math.min(3, 18 / Math.max(1, n))).toFixed(1) + "px");
        c.style.setProperty("--i", i);
        c.dataset.index = i + 1;
        c.dataset.card = slug;
        c.dataset.hint = "Click: play or sell";
        var inner = el("div", "dh-flip");
        inner.appendChild(X.miniCard(slug, "lg"));
        inner.appendChild(el("div", "dh-back"));
        c.appendChild(inner);
        if (fresh[keys[i]]) { c.classList.add("drawn"); c.style.setProperty("--d", (k++ * 180) + "ms"); }
        else c.classList.add("settled");
        c.addEventListener("click", function (ev) { ev.stopPropagation(); handClick(c, i + 1, slug); });
        h.appendChild(c);
      });
      // A hovered card pushes its neighbours aside.
      h.onmousemove = function (ev) {
        var t = ev.target.closest(".dh-card");
        var idx = t ? Array.prototype.indexOf.call(h.children, t) : -1;
        Array.prototype.forEach.call(h.children, function (c, j) {
          c.style.setProperty("--push", idx < 0 || j === idx ? "0px" : ((j < idx ? -1 : 1) * Math.max(0, 46 - Math.abs(j - idx) * 10)) + "px");
          c.classList.toggle("hot", j === idx);
        });
      };
      h.onmouseleave = function () { Array.prototype.forEach.call(h.children, function (c) { c.style.setProperty("--push", "0px"); c.classList.remove("hot"); }); };
    }
    var o = m.options, main = m.step === "main" && o.mine;
    Array.prototype.forEach.call(h.children, function (c) {
      var cc = card(c.dataset.card);
      var cost = o.costs && o.costs[Number(c.dataset.index) - 1] != null ? o.costs[Number(c.dataset.index) - 1] : (cc.cost || 0);
      var playable = main && cc.type !== "Legend" && cost <= o.eddies;
      var sellable = main && o.sell && cc.sell;
      c.classList.toggle("playable", !!playable);
      c.classList.toggle("sellable", !!sellable && !playable);
      c.classList.toggle("chosen", !!(sel && sel.kind === "equip" && sel.hand === Number(c.dataset.index)));
    });
  }

  /* ------------------------------------------------------------------------------------------- popover */
  function popover(anchor, buttons, title) {
    var p = $("tbPop");
    p.innerHTML = title ? "<h5>" + esc(title) + "</h5>" : "";
    buttons.forEach(function (b) {
      var n = el("button", b.cls || "ghost", b.label);
      n.disabled = !!b.disabled;
      if (b.why) n.title = b.why;
      n.onclick = function (ev) { ev.stopPropagation(); closePop(); b.fn(); };
      p.appendChild(n);
    });
    var r = anchor.getBoundingClientRect();
    p.classList.remove("hidden");
    p.style.left = Math.round(r.left + r.width / 2) + "px";
    p.style.top = Math.round(r.top - 12) + "px";
    p.classList.remove("show"); void p.offsetWidth; p.classList.add("show");
  }
  function closePop() { $("tbPop").classList.add("hidden"); }

  function handClick(node, index, slug) {
    closePop();
    var m = X.duel.match, o = m.options, c = card(slug);
    if (!(m.step === "main" && o.mine)) return hint("Wait for your turn.");
    var buttons = [];
    if (c.type === "Legend") return hint("Legends are played from your Legends area.");
    var cost = o.costs && o.costs[index - 1] != null ? o.costs[index - 1] : (c.cost || 0);
    var verb = c.type === "Gear" ? "Equip" : (c.type === "Program" ? "Run" : "Play");
    buttons.push({ label: verb + " &middot; " + cost + " &euro;$", cls: "primary", disabled: cost > o.eddies,
      why: cost > o.eddies ? "Not enough €$" : "", fn: function () {
        if (c.type === "Gear") { sel = { kind: "equip", hand: index, card: slug }; hint("Click the Unit or face-up Legend to equip."); rerender(); }
        else act("play", { hand: index, card: slug });
      } });
    if (c.sell) buttons.push({ label: "Sell for 1 &euro;$", disabled: !o.sell, why: o.sell ? "" : "Already sold this turn",
      fn: function () { act("sell", { hand: index, card: slug }); } });
    popover(node, buttons, c.name);
  }

  function unitClick(uid, mine) {
    closePop();
    var m = X.duel.match, o = m.options;
    if (sel && sel.kind === "equip" && mine) { act("play", { hand: sel.hand, card: sel.card, target: uid }); sel = null; return; }
    if (sel && sel.kind === "attack" && !mine) { act("attack", { uid: sel.uid, target: uid }); sel = null; return; }
    if (mine && m.step === "react" && o.blockers.indexOf(uid) >= 0) { act("block", { uid: uid }); return; }
    if (mine && m.step === "main" && o.mine) {
      if (o.attackers.indexOf(uid) < 0) return hint("This Unit cannot attack now (spent or Lag).");
      sel = { kind: "attack", uid: uid };
      hint("Click your rival's Gigs, or one of their spent Units.");
      rerender();
    }
  }
  function gigAreaClick(mine) {
    if (!mine && sel && sel.kind === "attack") { act("attack", { uid: sel.uid, target: "gigs" }); sel = null; }
  }
  function gigClick(uid, mine) {
    closePop();
    var m = X.duel.match;
    if (!mine && sel && sel.kind === "steal") {
      var i = sel.picks.indexOf(uid);
      if (i >= 0) sel.picks.splice(i, 1); else if (sel.picks.length < m.options.steal) sel.picks.push(uid);
      rerender();
      return;
    }
    gigAreaClick(mine);
  }

  function legendClick(node, k) {
    closePop();
    var m = X.duel.match, o = m.options, me = m.seats[m.you], l = me.legends[k - 1];
    if (!l || l.onField || l.removed) return;
    if (sel && sel.kind === "equip" && l.card) { act("play", { hand: sel.hand, card: sel.card, target: "L" + k }); sel = null; return; }
    var reacting = m.step === "react" && m.attack && m.attack.defender === m.you;
    if (!l.card) {
      if (!((m.step === "main" && o.mine) || reacting)) return hint("You Call a Legend on your turn, or as a reaction.");
      return popover(node, [{ label: "Call &middot; 1 &euro;$", cls: "primary", disabled: !o.call, why: o.call ? "" : "Once per turn, 1 €$",
        fn: function () { act("call", { legend: k }); } }], "Face-down Legend");
    }
    var c = card(l.card);
    if (!(m.step === "main" && o.mine)) return;
    var solo = (c.keywords || []).indexOf("Go Solo") >= 0;
    popover(node, [{ label: (solo ? "Go Solo" : "Play to the field") + (c.cost == null ? "" : " &middot; " + c.cost + " &euro;$"), cls: "primary",
      disabled: c.cost == null || c.cost > o.eddies, why: c.cost == null ? "Null cost: stays in the Legends area" : "",
      fn: function () { act("legend", { legend: k }); } }], c.name);
  }

  /* ------------------------------------------------------------------------------------------- your side panel */
  function renderYou(m) {
    var me = m.seats[m.you];
    var box = $("dhYou");
    var legends = me.legends.map(function (l, i) {
      var cls = "lg" + (l.spent ? " spent" : "") + (l.onField ? " gone" : "") + (l.removed ? " gone" : "");
      return '<i class="' + cls + '" data-leg="' + (i + 1) + '"' + (l.card ? ' data-card="' + l.card + '"' : "") + ">" +
        (l.card ? '<img src="' + X.cardImg(l.card) + '">' : "") + "</i>";
    }).join("");
    box.innerHTML = '<div class="dh-name"><b>' + esc(me.name) + "</b><small>" + esc(me.deck) + "</small></div>" +
      '<div class="dh-legends tb-legs">' + legends + "</div>" +
      '<div class="tb-money"><b>' + m.options.eddies + '</b><small>&euro;$ ready</small></div>' +
      '<div class="dh-counts"><span title="Cards in your deck"><i class="ico i-deck"></i>' + me.library + "</span>" +
      '<span title="Eddies (ready / total)">' + me.eddiesReady + "/" + me.eddies + " Eddies</span>" +
      '<span title="Trash">' + me.trash + " in trash</span></div>";
    Array.prototype.forEach.call(box.querySelectorAll("[data-leg]"), function (n) {
      n.addEventListener("click", function (ev) { ev.stopPropagation(); legendClick(n, Number(n.dataset.leg)); });
    });
    var rival = rivalOf(m);
    $("dhRival").innerHTML = '<div class="dh-name"><b>' + esc(rival.name) + "</b><small>" + esc(rival.deck) + "</small></div>" +
      X.legendsHtml(rival) +
      '<div class="dh-counts"><span title="Cards in their deck"><i class="ico i-deck"></i>' + rival.library + "</span>" +
      '<span title="Cards in their hand"><i class="ico i-hand"></i>' + rival.handCount + "</span>" +
      '<span title="Eddies (ready / total)">' + rival.eddiesReady + "/" + rival.eddies + " &euro;$</span>" +
      '<span title="Trash">' + rival.trash + " trash</span></div>";
  }

  /* ------------------------------------------------------------------------------------------- the turn panel */
  var hintTimer = null;
  function hint(text) {
    var h = $("tbHint");
    if (!h) return;
    h.textContent = text;
    h.classList.remove("show"); void h.offsetWidth; h.classList.add("show");
    clearTimeout(hintTimer);
    hintTimer = setTimeout(function () { h.classList.remove("show"); }, 3200);
  }

  function renderPanel(m) {
    var c = $("dhCentre"), o = m.options, me = m.seats[m.you], rival = rivalOf(m);
    var mineTurn = m.active === m.you;
    var title = "", body = "", buttons = [], extra = null;
    var key = [m.step, m.active, m.turn, JSON.stringify(o), sel ? JSON.stringify(sel) : "", JSON.stringify(m.attack || null),
      m.prompt ? m.prompt.id + ":" + JSON.stringify(picks) : ""].join("|");
    if (c.dataset.key === key) return tick();
    c.dataset.key = key;
    var src = m.prompt && m.prompt.source ? card(m.prompt.source) : null;
    if (m.prompt && m.prompt.mine) {
      var p = m.prompt;
      if (picks.id !== p.id) picks = { id: p.id, list: [] };
      title = esc(p.title);
      body = (src && src.name ? "<b>" + esc(src.name) + "</b> &middot; " : "") +
        (p.max === 0 ? "Look, then continue." : p.max === 1 ? (p.optional ? "Pick one, or skip." : "Pick one.") :
          (p.optional || !p.min ? "Pick up to " + p.max + "." : (p.min === p.max ? "Pick " + p.max + "." : "Pick " + p.min + " to " + p.max + ".")));
      extra = el("div", "tb-choices" + (p.options.some(function (o) { return o.card; }) ? " cards" : ""));
      p.options.forEach(function (o, i) {
        var b = el("button", "tb-choice" + (o.disabled ? " off" : "") + (picks.list.indexOf(i + 1) >= 0 ? " on" : ""));
        if (o.card) { b.appendChild(X.miniCard(o.card, "bd")); b.dataset.card = o.card; }
        b.appendChild(el("span", "", esc(o.label)));
        b.disabled = !!o.disabled || p.max === 0;
        b.onclick = function () {
          var k = picks.list.indexOf(i + 1);
          if (p.max === 1) { act("answer", { prompt: p.id, picks: String(i + 1) }); return; }
          if (k >= 0) picks.list.splice(k, 1); else if (picks.list.length < p.max) picks.list.push(i + 1);
          c.dataset.key = ""; rerender();
        };
        extra.appendChild(b);
      });
      if (p.max > 1 || p.max === 0) {
        var need = p.optional ? 0 : p.min;
        buttons.push([p.max === 0 ? "Continue" : "Confirm (" + picks.list.length + ")", function () { act("answer", { prompt: p.id, picks: picks.list.join(",") }); },
          "primary", p.max > 0 && (picks.list.length < need || picks.list.length > p.max)]);
      }
      if (p.optional && p.max === 1) buttons.push(["Skip", function () { act("answer", { prompt: p.id, picks: "" }); }, "ghost"]);
    } else if (m.prompt) {
      title = esc(m.prompt.who) + " is choosing";
      body = src && src.name ? "<b>" + esc(src.name) + "</b>" : "A card effect resolves.";
    } else if (o.waiting) {
      title = "Resolving";
      body = "A card effect resolves...";
    } else if (m.step === "roll" && mineTurn) {
      title = "Roll a Gig in";
      body = "Pick a die from your fixer area. The d20 comes last.";
      extra = el("div", "tb-fixer");
      o.roll.forEach(function (r) {
        var d = dieNode(r.die, null, "me", r.ok ? "rollable" : "locked");
        d.title = r.ok ? "Roll the " + r.die : "The d20 is rolled when it is the last die";
        if (r.ok) d.addEventListener("click", function () { act("roll", { die: r.die }); d.classList.add("rolling"); });
        extra.appendChild(d);
      });
    } else if (m.step === "main" && mineTurn) {
      title = "Your turn &middot; " + m.turn;
      if (sel && sel.kind === "attack") body = "Attack: click their <b>Gigs</b> or one of their <b>spent</b> Units.";
      else if (sel && sel.kind === "equip") body = "Equip: click one of your Units or face-up Legends.";
      else body = "Play cards, sell one, Call a Legend, attack with ready Units, then end your turn.";
      if (sel) buttons.push(["Cancel", function () { sel = null; rerender(); }, "ghost"]);
      buttons.push(["End turn", function () { sel = null; act("endTurn"); }, "primary"]);
      extra = effectsList(o, false);
    } else if (m.step === "react" && m.attack && m.attack.defender === m.you) {
      var a = m.attack;
      var att = rival.field.filter(function (u) { return u.uid === a.attacker; })[0];
      title = "You are attacked";
      body = "<b>" + esc(att ? card(att.card).name : "A Unit") + "</b> (" + (att ? att.power : "?") + ") attacks " +
        (a.target === "gigs" ? "your <b>Gigs</b>" : "one of your Units") + ". React: block with a ready <b>Blocker</b>" +
        (o.call ? ", Call a Legend" : "") + ", or let it through.";
      buttons.push(["Let it through", function () { act("resolve"); }, "primary"]);
      var hand = X.splitList(m.hand);
      o.quick.forEach(function (hi) {
        buttons.push(["Quick: " + esc(card(hand[hi - 1]).name), function () { act("quick", { hand: hi, card: hand[hi - 1] }); }, "ghost"]);
      });
      extra = effectsList(o, true);
    } else if (m.step === "steal" && m.attack && m.attack.owner === m.you) {
      if (!sel || sel.kind !== "steal") sel = { kind: "steal", picks: [] };
      title = "Steal " + o.steal + " Gig" + (o.steal > 1 ? "s" : "");
      body = "Click " + (o.steal > 1 ? "the Gigs" : "the Gig") + " you take from your rival (they keep their values).";
      buttons.push(["Steal", function () { act("steal", { uids: sel.picks.join(",") }); sel = null; }, "primary",
        sel.picks.length !== o.steal]);
    } else {
      title = esc(m.seats[m.active].name) + "'s turn &middot; " + m.turn;
      body = m.step === "react" ? "Your rival decides how to react..." : (m.step === "steal" ? "Your rival picks the Gigs they steal..." :
        (m.step === "roll" ? "Your rival rolls a Gig in..." : "Your rival is playing."));
    }
    c.className = "dh-centre tb-panel" + (mineTurn ? " mine" : "");
    c.innerHTML = '<div class="clock"></div><h2>' + title + "</h2><p>" + body + "</p>" +
      (m.overtime ? '<p class="tb-ot">OVERTIME: 7 Gigs win at once.</p>' : "") + '<div class="tb-hint" id="tbHint"></div>';
    if (extra) c.appendChild(extra);
    if (buttons.length) {
      var row = el("div", "actions");
      buttons.forEach(function (b) { var n = el("button", b[2], b[0]); n.disabled = !!b[3]; n.onclick = b[1]; row.appendChild(n); });
      c.appendChild(row);
    }
    tick();
  }
  // Activated effects ("X €$, {Spend}: ..."): one row each, greyed out when they can't be used now.
  function effectsList(o, reacting) {
    if (!o.activate || !o.activate.length) return null;
    var box = el("div", "tb-effects");
    box.appendChild(el("h6", "", reacting ? "Quick effects" : "Effects"));
    o.activate.forEach(function (a) {
      var b = el("button", "tb-effect" + (a.ok ? "" : " off"));
      b.dataset.card = a.card;
      b.innerHTML = "<b>" + esc(card(a.card).name || a.card) + "</b><span>" + esc(a.text || "") + "</span>" + (a.ok ? "" : "<em>" + esc(a.why || "") + "</em>");
      b.disabled = !a.ok;
      b.onclick = function () { act("activate", { uid: a.uid, id: a.id }); };
      box.appendChild(b);
    });
    return box;
  }
  var picks = { id: null, list: [] };

  function tick() {
    var left = X.remainingMs();
    var c = document.querySelector("#dhCentre .clock");
    if (c) { c.textContent = left != null ? X.clock(left) : ""; c.classList.toggle("low", left != null && left < 10000); }
  }

  /* ------------------------------------------------------------------------------------------- what happened */
  function fx(node, ms) { $("tbFx").appendChild(node); setTimeout(function () { if (node.parentNode) node.parentNode.removeChild(node); }, ms); }

  function playEvents(m) {
    var key = JSON.stringify(m.events);
    if (!m.events.length || key === seenEvents) return;
    seenEvents = key;
    m.events.forEach(function (e, i) {
      setTimeout(function () {
        if (e.kind === "roll") {
          var mine = e.seat === m.you;
          var d = dieNode(e.die, 1, mine ? "me" : "rv", "tb-rolling" + (mine ? "" : " rival"));
          var b = d.querySelector("b"), sides = Number(e.die.slice(1)), n = 0;
          var spin = setInterval(function () { b.textContent = 1 + Math.floor(Math.random() * sides); if (++n > 14) { clearInterval(spin); b.textContent = e.value; d.classList.add("landed"); } }, 60);
          fx(d, 2300);
        } else if (e.kind === "draw" && e.seat !== m.you) {
          fx(el("div", "tb-flyback"), 900);
        } else if (e.kind === "play" || e.kind === "legend" || e.kind === "program" || e.kind === "equip" || e.kind === "sell" || e.kind === "call") {
          if (e.seat === m.you && e.kind !== "call") return;
          var show = el("div", "tb-reveal " + e.kind);
          show.appendChild(X.miniCard(e.card, "lg"));
          show.appendChild(el("span", "", { play: "PLAYS", legend: "LEGEND", program: "PROGRAM", equip: "EQUIPS", sell: "SELLS", call: "CALL" }[e.kind]));
          fx(show, 1900);
        } else if (e.kind === "attack") {
          var n = document.querySelector('.tb-unit[data-uid="' + e.uid + '"]');
          if (n) { n.classList.remove("lunge"); void n.offsetWidth; n.classList.add("lunge"); }
        } else if (e.kind === "fight") {
          fx(el("div", "tb-clash", "<b>" + e.pa + "</b><i>VS</i><b>" + e.pd + "</b>"), 1400);
        } else if (e.kind === "steal") {
          var g = document.querySelector('.tb-die[data-uid="' + e.uid + '"]');
          if (g) { g.classList.remove("stolen"); void g.offsetWidth; g.classList.add("stolen"); }
        }
      }, i * 260);
    });
  }

  /* ------------------------------------------------------------------------------------------- render */
  var last = null;
  function rerender() { if (last) render(last); }
  function render(m) {
    normalise(m);
    last = m;
    if (sel && !(m.step === "main" || m.step === "steal")) sel = null;
    if (sel && sel.kind === "steal" && m.step !== "steal") sel = null;
    document.body.classList.toggle("tb-on", true);
    renderYou(m);
    boardHtml($("tbRival"), rivalOf(m), m, false);
    boardHtml($("tbMine"), m.seats[m.you], m, true);
    renderHand(m);
    renderPanel(m);
    renderCoach(m);
    playEvents(m);
  }

  /* ------------------------------------------------------------------------------------------- the tutorial's coach */
  // The coach panel (top centre) and what it points at: overlay elements light up, a hand card glows.
  var COACH_TARGETS = {
    legends: "#dhYou .tb-legs", hand: "#dhHand", rival: "#dhRival", rivalBoard: "#tbRival .tb-field", rivalGigs: "#tbRival .tb-gigs",
    myBoard: "#tbMine .tb-field", myGigs: "#tbMine .tb-gigs", money: "#dhYou .tb-money", panel: "#dhCentre",
    endTurn: "#dhCentre .actions .primary", log: "#dhLog"
  };
  function renderCoach(m) {
    var box = $("tbCoach"), t = m.tutorial, TU = window.TCGTUTO;
    Array.prototype.forEach.call(document.querySelectorAll(".coach-focus"), function (n) { n.classList.remove("coach-focus"); });
    if (TU) TU.renderFree(!t && !!m.isTutorial);
    if (!t) { box.classList.add("hidden"); box.dataset.key = ""; return; }
    box.classList.remove("hidden");
    var key = t.id + "|" + !!m.prompt + "|" + (TU ? TU.lang() : "en");
    if (box.dataset.key !== key) {
      var fresh = String(box.dataset.key || "").split("|")[0] !== t.id;
      box.dataset.key = key;
      if (TU) TU.render(box, t, m, function (name, d) { X.T.emit(name, d || {}); });
      else box.innerHTML = "<h3>" + esc(t.title) + "</h3><p>" + esc(t.text) + "</p>";
      if (fresh) { box.classList.remove("show"); void box.offsetWidth; box.classList.add("show"); }
    }
    (t.ui ? arr(t.ui) : []).forEach(function (name) {
      var sel = COACH_TARGETS[name];
      Array.prototype.forEach.call(sel ? document.querySelectorAll(sel) : [], function (n) { n.classList.add("coach-focus"); });
    });
    if (t.card) {
      var c = document.querySelector('#dhHand .dh-card[data-card="' + t.card + '"]');
      if (c) c.classList.add("coach-focus");
    }
  }
  function clear() {
    sel = null; last = null; seenEvents = null; handKeys = [];
    ["tbRival", "tbMine", "tbFx"].forEach(function (id) { var n = $(id); if (n) n.innerHTML = ""; });
    var coach = $("tbCoach"); if (coach) { coach.classList.add("hidden"); coach.dataset.key = ""; }
    if (window.TCGTUTO) { window.TCGTUTO.reset(); window.TCGTUTO.renderFree(false); }
    closePop();
    document.body.classList.remove("tb-on");
  }

  document.addEventListener("click", function (ev) { if (!ev.target.closest("#tbPop")) closePop(); });
  document.addEventListener("keydown", function (ev) { if (ev.key === "Escape" && sel) { sel = null; rerender(); } });

  function init() {
    if (X) return;
    X = window.TCGDUEL;
    X.setGameRenderer({ render: render, clear: clear, tick: tick });
    X.rerenderCoach = function () { var b = $("tbCoach"); if (b) b.dataset.key = ""; rerender(); };
    X.T.on("tcg:duelRefused", function (d) {
      var why = String(d.reason || "Not allowed.");
      // The tutorial's own refusals, in the coach's language.
      if (why.indexOf("Tutorial:") === 0 && window.TCGTUTO && window.TCGTUTO.lang() === "fr") why = "Pas maintenant : suis les étapes du coach (en haut).";
      else if (why.indexOf("Tutorial:") === 0) why = "Not now: follow the coach's steps (top of the screen).";
      hint(why);
    });
    if (X.T.preview) preview();
  }
  if (window.TCGDUEL) init(); else document.addEventListener("tcg:duelReady", init);

  /* ------------------------------------------------------------------------------------------- preview (no game) */
  function preview() {
    var mode = new URLSearchParams(location.search).get("duel");
    if (["game", "react", "steal", "roll", "prompt", "multi", "effects", "tutorial"].indexOf(mode) < 0) return;
    var u = function (uid, slug, power, o) { return Object.assign({ uid: uid, card: slug, power: power, spent: false, lag: false, gear: "" }, o || {}); };
    var view = { id: 9, slot: "nd_a", label: "NEON DECK - Table 1 A", you: 1, phase: "game", step: mode === "game" ? "main" : mode,
      active: mode === "react" ? 2 : 1, turn: 5, first: 1, deadline: 140000, hand: "mantis_blades,corpo_security,chrome_fang,over_the_edge,kiroshi_optics",
      log: ["Turn 5: Yuki.", "Yuki rolls the d8: 6.", "Jerem plays Delamain Cab (4 power)."],
      events: mode === "roll" ? [] : [{ kind: "draw", seat: 1 }, { kind: "roll", seat: 1, die: "d8", value: 6, uid: 31 }],
      attack: mode === "react" ? { attacker: 21, owner: 2, defender: 1, target: "gigs" } : (mode === "steal" ? { attacker: 11, owner: 1, defender: 2, target: "gigs", steal: 1 } : null),
      options: { mine: mode !== "react", eddies: 4, sell: true, call: true, attackers: [11], blockers: mode === "react" ? [12] : [], steal: mode === "steal" ? 1 : null,
        roll: mode === "roll" ? [{ die: "d4", ok: true }, { die: "d10", ok: true }, { die: "d12", ok: true }, { die: "d20", ok: false }] : [] },
      seats: {
        1: { name: "Yuki", deck: "Embracing Power", seated: true, library: 27, handCount: 5, eddies: 3, eddiesReady: 2, trash: 4, streetCred: 9,
             legends: [{ spent: true, card: "goro_takemura_hands_unclean" }, { spent: false }, { spent: false }],
             field: [u(11, "ruthless_lowlife", 4), u(12, "corpo_security", 2, { spent: false }), u(13, "chrome_fang", 6, { lag: true, gear: "mantis_blades" })],
             gigs: [{ uid: 31, kind: "d8", value: 6, owner: 1 }, { uid: 32, kind: "d4", value: 3, owner: 1 }], fixer: ["d10", "d12", "d20"] },
        2: { name: "Jerem Zzzer", deck: "The Heist", seated: true, library: 26, handCount: 4, eddies: 2, eddiesReady: 1, trash: 3, streetCred: 12,
             legends: [{ spent: false }, { spent: true, card: "v_corporate_exile" }, { spent: false }],
             field: [u(21, "delamain_cab", 4, { spent: true }), u(22, "psycho_squad", 6)],
             gigs: [{ uid: 41, kind: "d10", value: 7, owner: 2 }, { uid: 42, kind: "d6", value: 5, owner: 2 }], fixer: ["d4", "d12", "d20"] }
      } };
    if (mode === "prompt" || mode === "multi" || mode === "effects" || mode === "tutorial") view.step = "main";
    if (mode === "tutorial") {
      view.hand = "mantis_blades,emergency_atlus,japantown_jonin,corporate_surveillance,kiroshi_optics,floor_it,field_operator";
      var sid = new URLSearchParams(location.search).get("step") || "sell";
      view.isTutorial = true;
      view.tutorial = { index: 11, total: 30, id: sid, title: "Sell a card for money", card: sid === "sell" ? "mantis_blades" : null, ui: ["hand"],
        expect: ({ sell: "sell", roll: "roll", play: "play", attack: "attack", pick: "steal", react: "resolve", call: "call" })[sid] || null,
        next: ["language", "welcome", "table", "legends", "hand", "d20", "draw", "gigs", "money", "lag", "fight", "done"].indexOf(sid) >= 0,
        final: sid === "done", house: ["house1", "house2", "house3", "block", "stolen"].indexOf(sid) >= 0,
        text: "Mantis Blades has a Sell Tag. Click it in your hand, then Sell: it goes face down into your Eddies and pays 1 \u20AC$ every turn from now on. You may sell one card per turn." };
    }
    if (mode === "prompt") view.prompt = { id: 5, mine: true, title: "Defeat a rival Unit with power 4 or less", min: 1, max: 1, optional: false,
      source: "bonnie_and_clyde", options: [{ label: "Delamain Cab (4)", card: "delamain_cab", uid: 21 }, { label: "Psycho Squad (6)", card: "psycho_squad", uid: 22, disabled: true }] };
    if (mode === "multi") view.prompt = { id: 6, mine: true, title: "Up to 2 Gears (cost 2 or less)", min: 0, max: 2, optional: true, source: "viktor_vektor_sit_down_and_relax",
      options: [{ label: "Mantis Blades", card: "mantis_blades" }, { label: "Psycho Squad", card: "psycho_squad", disabled: true }, { label: "Kiroshi Optics", card: "kiroshi_optics" },
        { label: "Riot Shield", card: "riot_shield" }, { label: "Gorilla Arms", card: "gorilla_arms", disabled: true }] };
    if (mode === "effects") view.options.activate = [
      { uid: 12, card: "kerry_eurodyne_the_last_rockerboy", id: "kerry_eurodyne_the_last_rockerboy", ok: true, cost: 0, text: "Spend: draw 2 if you control a Gig with 8+ value" },
      { uid: 30, card: "hanako_arasaka_daughter_of_the_emperor", id: "hanako_arasaka_daughter_of_the_emperor", ok: false, why: "It is spent.", text: "Spend: swap a friendly Gig with a rival Gig" }];
    setTimeout(function () {
      X.T.hide();
      X.T.previewHandlers["tcg:match"](JSON.parse(JSON.stringify(view)));
    }, 500);
    window.TCG_PREVIEW_HOOK_GAME = function (name, d) {
      if (name !== "tcg:act") return false;
      if (d.type === "roll") { view.events = [{ kind: "roll", seat: 1, die: d.die, value: 1 + Math.floor(Math.random() * Number(d.die.slice(1))), uid: 99 }]; view.step = "main"; }
      else { X.T.toast("act: " + d.type); return true; }
      X.T.previewHandlers["tcg:match"](JSON.parse(JSON.stringify(view)));
      return true;
    };
  }
})();
