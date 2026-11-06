/* The NEON DECK welcome, the page side (client/welcome.lua): five short steps the first time a collector walks up to
   the vendor - what the shop is, getting cards, the binder, the lent decks, private rooms and the tutorial duel.
   Next / Back / the step rail with the mouse; Right / Enter, Left / Backspace and Escape on the keyboard.
   The client sends tcg:welcomeOpen (the real settings: the binder's key, the commands, the lent decks); closing emits
   tcg:welcomeClose, which hands the cursor back. In a plain browser: index.html?welcome=1 (or =2..5 for a step). */
(function () {
  "use strict";
  var T = null;
  var $ = function (id) { return document.getElementById(id); };
  var open = false, step = 0, d = {}, leaving = null;

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function emit(name, payload) { if (T) T.emit(name, payload || {}); }
  function sfx(event) { emit("tcg:gameSfx", { event: event }); }
  function cmd(c) { return '<span class="tw-cmd">/' + esc(c) + "</span>"; }

  // Lucide-style strokes (24 px box).
  var ICON = {
    next: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    cards: '<rect x="3" y="5" width="11" height="15" rx="1.5" transform="rotate(-8 8.5 12.5)"/><rect x="9" y="4" width="11" height="15" rx="1.5"/>',
    door: '<path d="M4 21h16M6 21V4h9l3 2v15M12 12h.01"/>',
    play: '<circle cx="12" cy="12" r="9"/><path d="M10 8.5l5 3.5-5 3.5z"/>',
    alert: '<path d="M12 3l9.5 17h-19z"/><path d="M12 10v4M12 17h.01"/>',
    book: '<path d="M3 5.5C5.5 4 8.5 4 12 6c3.5-2 6.5-2 9-.5V19c-2.5-1.5-5.5-1.5-9 .5-3.5-2-6.5-2-9-.5z"/><path d="M12 6v13.5"/>',
    id: '<rect x="3" y="5" width="18" height="14" rx="1"/><circle cx="9" cy="11" r="2"/><path d="M14 10h4M14 14h4M6 16c1-1.5 5-1.5 6 0"/>',
    bank: '<path d="M3 10l9-5 9 5M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
    job: '<rect x="3" y="7" width="18" height="13" rx="1"/><path d="M9 7V4h6v3"/>',
    hand: '<path d="M8 13V5.5a1.5 1.5 0 013 0V11M11 10V4.5a1.5 1.5 0 013 0V11M14 10.5V6a1.5 1.5 0 013 0v7c0 4-2.5 7-6 7-2.5 0-4-1-5.5-3L3 13.5a1.5 1.5 0 012.3-1.9L8 14"/>'
  };
  function icon(name) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (ICON[name] || "") + "</svg>";
  }
  function frame(inner, cap) {
    return '<div class="frame"><span class="tick tl"></span><span class="tick br"></span>' + inner + (cap ? '<span class="cap">' + esc(cap) + "</span>" : "") + "</div>";
  }

  // A card picture by card name (the first edition of it in the catalogue), or nothing.
  function cardPic(card) {
    var list = T && T.catalogue ? T.catalogue() : [];
    for (var i = 0; i < list.length; i++) if (list[i].card === card) return T.img(list[i]);
    return null;
  }
  function picImg(card, cls) {
    var src = cardPic(card);
    return src ? '<img class="' + (cls || "") + '" src="' + esc(src) + '" alt="" decoding="async">' : '<span class="ph ' + (cls || "") + '"></span>';
  }

  /* ---------------------------------------------------------------------------------------------- the five steps */
  function inventory() { return d.store !== "binder"; }
  function binderHow() {
    var b = d.binder;
    if (b && b.key) {
      return "Press <kbd>" + esc(b.key) + "</kbd> to open the " + esc(b.menu || "menu") + ", then choose <b>" + esc(b.entry || "TCG binder") +
        "</b>. Typing " + cmd(d.command || "tcgbinder") + " in the chat does the same.";
    }
    return "Type " + cmd(d.command || "tcgbinder") + " in the chat to open it.";
  }

  var STEPS = [
    { rail: "The shop", kicker: "01 // NEON DECK",
      title: function () { return "Welcome to <em>NEON DECK</em>"; },
      body: function () {
        return '<p class="tw-lead tw-in" style="--i:1">NEON DECK is Night City\'s Cyberpunk TCG shop. Collect the cards, build a deck and duel other players at the tables, on the ground floor and upstairs.</p>' +
          '<ul class="tw-list">' +
          '<li class="tw-in" style="--i:2"><span><b>151 cards, 320 editions</b> to collect, from Common to Secret, in sleeved, foil, premium and metal finishes.</span></li>' +
          '<li class="tw-in" style="--i:3"><span><b>The goal of a duel:</b> start one of your turns holding <b>7 Gigs</b> (dice). The tutorial at the end of this guide teaches you the rest.</span></li>' +
          '<li class="tw-in" style="--i:4"><span>This guide takes a minute. <span class="dim">Use Next, or the arrow keys.</span></span></li>' +
          "</ul>";
      },
      visual: function () {
        return frame('<div class="tw-fan">' + picImg("goro_takemura_hands_unclean") + picImg("jackie_welles_pour_one_out_for_me") + picImg("v_corporate_exile") + "</div>" +
          '<img class="tw-logo" src="' + esc(tcgAsset("img/ui/logo.webp")) + '" alt="Cyberpunk TCG" decoding="async">');
      } },

    { rail: "Getting cards", kicker: "02 // CARDS",
      title: function () { return "How to get <em>cards</em>"; },
      body: function () {
        var gift = Number(d.gift) || 0;
        var where = inventory() ? "your inventory" : "the Sealed tab of your binder";
        return '<p class="tw-lead tw-in" style="--i:1">Cards come in sealed boosters of 12. Open one and the cards go straight into your binder.</p>' +
          '<ul class="tw-list">' +
          (gift > 0 ? '<li class="tw-in" style="--i:2"><span><b>A welcome gift:</b> every new collector gets ' + gift + " Welcome to Night City boosters, once. Look in " + where + ".</span></li>" : "") +
          '<li class="tw-in" style="--i:3"><span><b>Buy more</b> ' + (inventory() ? "from the vendor at this counter" : "at a TCG shop counter, in the binder's Shop tab") +
          ": Welcome to Night City and Beta Edition boosters, or a display of 24 boosters.</span></li>" +
          '<li class="tw-in" style="--i:4"><span><b>Open them</b> ' + (inventory() ? "from your inventory or " : "from ") + "the binder's Sealed tab. Stand at a table and the cards are dealt on it.</span></li>" +
          '<li class="tw-in" style="--i:5"><span><b>Duplicates</b> recycle into Dust at a TCG shop counter, and Dust prints the cards you are missing.</span></li>' +
          '<li class="tw-in" style="--i:6"><span><b>Trade:</b> hand a card from your binder to a player standing next to you.</span></li>' +
          "</ul>";
      },
      visual: function () {
        return frame('<div class="tw-sealed">' +
          '<img class="box" src="' + esc(tcgAsset("img/ui/box_retail.webp")) + '" alt="" decoding="async">' +
          '<img class="wnc" src="' + esc(tcgAsset("img/ui/booster_wnc.webp")) + '" alt="" decoding="async">' +
          '<img class="beta" src="' + esc(tcgAsset("img/ui/booster_beta.webp")) + '" alt="" decoding="async">' +
          '<span class="tw-chip" style="left:24px;top:262px">12 cards a pack</span>' +
          '<span class="tw-chip" style="left:178px;top:30px">24 packs</span>' +
          "</div>", "Boosters and displays");
      } },

    { rail: "Your binder", kicker: "03 // THE BINDER",
      title: function () { return d.binder && d.binder.key ? "Your binder: <em>" + esc(d.binder.key) + "</em>" : "Your <em>binder</em>"; },
      body: function () {
        return '<p class="tw-lead tw-in" style="--i:1">' + binderHow() + "</p>" +
          '<ul class="tw-list">' +
          '<li class="tw-in" style="--i:2"><span><b>Binder:</b> every card you own, page by page.</span></li>' +
          '<li class="tw-in" style="--i:3"><span><b>Sealed:</b> your boosters and displays, opened in your hands.</span></li>' +
          '<li class="tw-in" style="--i:4"><span><b>Shop:</b> the recycler and the card printer, at a TCG shop counter.</span></li>' +
          '<li class="tw-in" style="--i:5"><span><b>Decks:</b> build and save your decks.</span></li>' +
          '<li class="tw-in" style="--i:6"><span><b>Duel:</b> your playmat, your duel deck, challenges and the tutorial.</span></li>' +
          "</ul>";
      },
      visual: function () {
        var b = d.binder;
        var menu = '<div class="tw-menu"><div class="mh"><b>OPEN//77</b><small>PLAYER MENU</small></div><div class="ms">CHARACTER</div>' +
          '<div class="mi">' + icon("id") + "Identity</div>" + '<div class="mi">' + icon("bank") + "Bank</div>" +
          '<div class="mi">' + icon("job") + "My job</div>" + '<div class="mi">' + icon("hand") + "Animations</div>" +
          '<div class="mi on">' + icon("book") + esc(b && b.entry || "TCG binder") + "</div></div>";
        if (!(b && b.key)) menu = '<div class="tw-menu"><div class="mh"><b>CHAT</b><small>COMMAND</small></div><div class="mi on">' + icon("book") + "/" + esc(d.command || "tcgbinder") + "</div></div>";
        var chev = '<svg class="chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>';
        return frame('<div class="tw-f1">' + (b && b.key ? '<span class="tw-keycap">' + esc(b.key) + "</span>" + chev : "") + menu + "</div>", b && b.key ? "Player menu" : "Chat");
      } },

    { rail: "Loaner decks", kicker: "04 // PLAY NOW",
      title: function () { return "Play now with a <em>loaner deck</em>"; },
      body: function () {
        var lent = d.starters && d.starters.length;
        var radius = Math.round(Number(d.challengeRadius) || 15);
        return '<p class="tw-lead tw-in" style="--i:1">' + (lent
            ? "No cards yet? No problem. The shop lends its official starter decks to everyone, for free: 40 cards and 3 Legends each."
            : "Build a deck of your own in the binder's Decks tab, then play it at a table.") + "</p>" +
          '<ul class="tw-list">' +
          (lent ? '<li class="tw-in" style="--i:2"><span>In the binder\'s <b>Duel</b> tab, pick one as your duel deck. Lent decks are marked <b>(lent)</b>.</span></li>' +
                  '<li class="tw-in" style="--i:3"><span>In the <b>Decks</b> tab, copy one and tune it with your own cards.</span></li>' : "") +
          '<li class="tw-in" style="--i:4"><span><b>To play someone:</b> Duel tab, <b>Challenge a player</b> within ' + radius + " m. Once they accept, walk to your table and press <kbd>E</kbd> at your chair.</span></li>" +
          "</ul>";
      },
      visual: function () {
        var list = (d.starters || []).slice(0, 2);
        if (!list.length) return frame('<div class="tw-fan">' + picImg("mantis_blades") + picImg("kiroshi_optics") + picImg("sandevistan") + "</div>", "Your deck");
        return frame('<div class="tw-decks">' + list.map(function (s) {
          return '<div class="tw-deck"><div class="pic"><i></i>' + picImg(s.legend) + '</div><div><b>' + esc(s.name) + "</b><small>" + esc(s.subtitle) +
            '</small><span class="lent">LENT</span></div></div>';
        }).join("") + "</div>", "Free to play");
      } },

    { rail: "Rooms & tutorial", kicker: "05 // ROOMS & TUTORIAL",
      title: function () { return "Rooms &amp; the <em>tutorial</em>"; },
      body: function () {
        var code = Number(d.codeLength) || 5, max = Number(d.roomPlayers) || 8;
        return '<div class="tw-two">' +
          '<div class="tw-block tw-in" style="--i:1"><h3>' + icon("door") + "Private rooms</h3><p>Talk to the host behind the counter (<kbd>E</kbd>) to open a room under the shop, with its own duel table. You get a " +
            code + "-character code: your friends join with it, up to " + max + " players.</p></div>" +
          '<div class="tw-block tw-in" style="--i:2"><h3>' + icon("play") + "The tutorial</h3><p>A guided duel against the house, about 10 minutes. Start it in the binder's Duel tab (<b>Learn to play</b>) or type " +
            cmd(d.tutorial || "tcgtutorial") + ". It takes the nearest free table.</p></div>" +
          "</div>" +
          '<div class="tw-callout tw-in" style="--i:3">' + icon("alert") + "<span><b>Too many players, or no free table?</b> Open a private room first, then start the tutorial from inside it: it uses your room's own table.</span></div>" +
          '<p class="tw-lead tw-in" style="--i:4;margin:14px 0 0;font-size:13.5px;color:var(--o77-ink-200)">See this guide again any time: ' + cmd(d.welcome || "tcgwelcome") +
            ", or <b>How NEON DECK works</b> in the host's panel.</p>";
      },
      visual: function () {
        var letters = "K7Q2X".split("").map(function (c, i) { return '<i style="animation-delay:' + (0.6 + i * 0.09).toFixed(2) + 's">' + c + "</i>"; }).join("");
        return frame('<div><div class="tw-room" style="background-image:url(' + esc(tcgAsset("img/rooms/shop.jpg")) + ')"><span>NEON DECK // LEVEL -1</span></div>' +
          '<div class="tw-code"><small>ROOM CODE</small><b>' + letters + "</b></div>" +
          '<div class="tw-tut">' + icon("play") + "<div><b>Tutorial duel</b><small>vs the house, about 10 min</small></div></div></div>");
      } }
  ];

  /* ---------------------------------------------------------------------------------------------- the card */
  function mount() {
    if ($("welcome")) return;
    var w = document.createElement("div");
    w.id = "welcome";
    w.className = "hidden";
    w.setAttribute("role", "dialog");
    w.setAttribute("aria-modal", "true");
    w.setAttribute("aria-labelledby", "twTitle");
    w.innerHTML = '<div class="tw-scrim"></div><div class="tw-card"><span class="tw-corner"></span><span class="tw-corner b"></span><div class="tw-sweep" id="twSweep"></div>' +
      '<header class="tw-head"><span class="tw-led"></span><span class="tw-tag" id="twTag"></span><span class="tw-count" id="twCount"></span>' +
      '<button class="tw-x" id="twX" title="Close (Esc)">&times;</button></header>' +
      '<div class="tw-body"><nav class="tw-rail" id="twRail"></nav><section class="tw-stage" id="twStage"></section></div>' +
      '<footer class="tw-foot"><div class="tw-progress" id="twProgress"></div>' +
      '<span class="tw-keys"><kbd>&larr;</kbd><kbd>&rarr;</kbd> step &middot; <kbd>Esc</kbd> close</span><span class="tw-spacer"></span>' +
      '<button class="tw-btn ghost" id="twBack">Back</button><button class="tw-btn alt hidden" id="twTutorial">Start the tutorial</button>' +
      '<button class="tw-btn primary" id="twNext"></button></footer></div>';
    document.body.appendChild(w);
    var rail = "", bars = "";
    STEPS.forEach(function (s, i) {
      rail += '<button data-step="' + i + '"><span class="n">0' + (i + 1) + '</span><span class="l">' + esc(s.rail) + "</span></button>";
      bars += "<i></i>";
    });
    $("twRail").innerHTML = '<span class="tw-mark" id="twMark"></span>' + rail + '<div class="tw-rail-foot" id="twRailFoot"></div>';
    $("twProgress").innerHTML = bars;
    Array.prototype.forEach.call($("twRail").querySelectorAll("button"), function (b) {
      b.onclick = function () { go(Number(b.dataset.step)); };
    });
    $("twX").onclick = close;
    $("twBack").onclick = function () { go(step - 1); };
    $("twNext").onclick = function () { if (step >= STEPS.length - 1) finish(); else go(step + 1); };
    $("twTutorial").onclick = startTutorial;
    ["twBack", "twNext", "twTutorial", "twX"].forEach(function (id) { $(id).onmouseenter = function () { sfx("ui_menu_hover"); }; });
  }

  function render(dir) {
    var s = STEPS[step];
    var stage = $("twStage");
    stage.className = "tw-stage" + (dir < 0 ? " tw-back" : "");
    stage.innerHTML = '<div class="tw-copy"><div class="tw-kicker tw-in" style="--i:0">' + esc(s.kicker) + '</div><h2 id="twTitle" class="tw-in" style="--i:0">' + s.title() + "</h2>" +
      s.body() + '</div><div class="tw-visual">' + s.visual() + "</div>";
    // A picture the CDN does not answer leaves its frame, not a broken icon.
    Array.prototype.forEach.call(stage.querySelectorAll("img"), function (im) { im.onerror = function () { im.style.visibility = "hidden"; }; });
    $("twCount").innerHTML = "STEP <b>0" + (step + 1) + "</b> / 0" + STEPS.length;
    $("twTag").innerHTML = "NEON DECK <i>//</i> " + (d.auto ? "FIRST VISIT" : "GUIDE");
    $("twRailFoot").innerHTML = "Reopen: <b>/" + esc(d.welcome || "tcgwelcome") + "</b>";
    Array.prototype.forEach.call($("twRail").querySelectorAll("button"), function (b, i) {
      b.classList.toggle("on", i === step);
      b.classList.toggle("done", i < step);
    });
    $("twMark").style.transform = "translateY(" + (26 + step * 60) + "px)";
    Array.prototype.forEach.call($("twProgress").children, function (bar, i) { bar.classList.toggle("on", i <= step); });
    var last = step >= STEPS.length - 1;
    $("twBack").disabled = step === 0;
    $("twNext").innerHTML = (last ? "Got it" : "Next") + icon("next");
    $("twTutorial").classList.toggle("hidden", !last);
    // the sweep runs again on every step
    var sw = $("twSweep");
    sw.style.animation = "none"; void sw.offsetWidth; sw.style.animation = "";
  }

  function go(i) {
    if (!open || i < 0 || i >= STEPS.length || i === step) return;
    var dir = i > step ? 1 : -1;
    sfx("ui_menu_onpress");
    step = i;
    render(dir);
  }

  function show(payload) {
    mount();
    d = payload || {};
    if (leaving) { clearTimeout(leaving); leaving = null; }
    var w = $("welcome");
    w.classList.remove("hidden", "leaving");
    open = true;
    step = 0;
    render(1);
    sfx("ui_menu_open");
    setTimeout(function () { var n = $("twNext"); if (n && open) n.focus({ preventScroll: true }); }, 50);
  }

  // Hides the card (with its exit) without telling the client: it asked, or it is told by close().
  function hide() {
    var w = $("welcome");
    if (!w || !open) return;
    open = false;
    w.classList.add("leaving");
    leaving = setTimeout(function () { w.classList.add("hidden"); w.classList.remove("leaving"); leaving = null; }, 280);
  }

  function close() {
    if (!open) return;
    hide();
    sfx("ui_menu_onpress");
    emit("tcg:welcomeClose", { step: step + 1, done: step >= STEPS.length - 1 });
  }
  function finish() { close(); }
  function startTutorial() {
    if (!open) return;
    hide();
    sfx("ui_menu_item_crafting_done");
    emit("tcg:welcomeClose", { step: step + 1, done: true });
    emit("tcg:tutorial", {});
  }

  function onKey(e) {
    if (!open) return;
    var k = e.key;
    // Enter / Space on a focused button of the guide: that button (the browser clicks it).
    if ((k === "Enter" || k === " ") && e.target && e.target.tagName === "BUTTON" && $("welcome").contains(e.target)) { e.stopImmediatePropagation(); return; }
    if (k === "Escape") close();
    else if (k === "ArrowRight" || k === "Enter" || k === " ") { if (step >= STEPS.length - 1) { if (k !== " ") finish(); } else go(step + 1); }
    else if (k === "ArrowLeft" || k === "Backspace") go(step - 1);
    else return;
    // The binder and the rooms panel listen too: this key was for the guide.
    e.preventDefault();
    e.stopImmediatePropagation();
  }

  function init() {
    T = window.TCG;
    mount();
    T.on("tcg:welcomeOpen", show);
    T.on("tcg:welcomeClose", hide);
    // Capture phase: before the binder's own keys (app.js) and the rooms panel (rooms.js).
    document.addEventListener("keydown", onKey, true);
    window.TCGWELCOME = { show: show, close: close, isOpen: function () { return open; }, go: go, step: function () { return step; } };
    if (T.preview) preview();
  }
  if (window.TCG) init(); else document.addEventListener("tcg:binderReady", init);

  function preview() {
    var q = Number(new URLSearchParams(location.search).get("welcome") || 0);
    if (!q) return;
    setTimeout(function () {
      T.hide();
      show({ auto: true, binder: { key: "F1", menu: "player menu", entry: "TCG binder" }, command: "tcgbinder", tutorial: "tcgtutorial", welcome: "tcgwelcome",
        gift: 3, store: "inventory", roomPlayers: 8, codeLength: 5, challengeRadius: 15,
        starters: [{ id: "embracing_power", name: "Embracing Power", subtitle: "Arasaka starter deck - Red / Green", legend: "goro_takemura_hands_unclean" },
                   { id: "the_heist", name: "The Heist", subtitle: "Mercs starter deck - Blue / Yellow", legend: "v_corporate_exile" }] });
      if (q > 1) for (var i = 1; i < q; i++) go(i);
    }, 400);
  }
})();
