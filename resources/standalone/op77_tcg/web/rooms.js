/* Cyberpunk TCG private rooms, the page side (client/rooms.lua): the panel the counter host opens (pick a room style
   and open it, or join friends with their code), and while in a room a small badge with its code. In a plain browser:
   index.html?rooms=1 (the panel) or ?rooms=in (the panel and the badge inside a room). */
(function () {
  "use strict";
  var T = null;
  var $ = function (id) { return document.getElementById(id); };
  var state = { room: null, styles: [] };
  var open = false;
  var STYLE_FALLBACK = [
    { id: "shop", label: "Neon Deck", blurb: "The shop's own look: black lacquer, yellow and neon." },
    { id: "cozy", label: "Cozy Lounge", blurb: "Brick, oak and warm lights, a rug and full bookcases." },
    { id: "jp", label: "Tatami Room", blurb: "Tatami, shoji screens, lanterns and a golden screen." }
  ];

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function el(tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  function emit(name, d) { if (T) T.emit(name, d || {}); }
  function sfx(event) { emit("tcg:gameSfx", { event: event }); }

  function mount() {
    if ($("roomsPanel")) return;
    var p = el("div", "rm-panel hidden");
    p.id = "roomsPanel";
    document.body.appendChild(p);
    var b = el("div", "rm-badge hidden");
    b.id = "roomBadge";
    document.body.appendChild(b);
  }

  function msg(text, bad) {
    var m = $("rmMsg");
    if (!m) return;
    m.textContent = text || "";
    m.className = "rm-msg" + (bad ? " bad" : "");
  }

  function render() {
    mount();
    var p = $("roomsPanel");
    p.classList.toggle("hidden", !open);
    renderBadge();
    if (!open) return;
    var styles = (state.styles && state.styles.length ? state.styles : STYLE_FALLBACK);
    var r = state.room;
    var h = '<div class="rm-head"><span class="rm-dot"></span><span class="rm-kicker">NEON DECK &middot; LEVEL -1</span>' +
      '<button class="rm-x" id="rmClose" title="Close">&times;</button></div>' +
      '<h2>Private rooms</h2><p class="rm-sub">A room of your own under the shop: a duel table, peace and quiet. Open one, then give the code to your friends.</p>';
    if (r) {
      h += '<div class="rm-in"><div class="rm-in-l"><span class="rm-kicker">YOU ARE IN</span><b>' + esc(r.label) + '</b>' +
        '<span class="rm-players">' + esc((r.players || []).join(", ")) + " &middot; " + (r.count || 0) + "/" + (r.max || 8) + "</span></div>" +
        '<div class="rm-code"><span class="rm-kicker">ROOM CODE</span><b>' + esc(r.code) + "</b></div></div>" +
        '<div class="rm-actions"><button class="rm-btn ghost danger" id="rmLeave">Leave the room</button></div>';
    } else {
      h += '<div class="rm-section"><span class="rm-kicker">OPEN A ROOM</span></div><div class="rm-styles">';
      styles.forEach(function (s) {
        h += '<button class="rm-style" data-style="' + esc(s.id) + '"><span class="rm-shot" style="background-image:url(' + tcgAsset("img/rooms/" + esc(s.id) + ".jpg") + ')"><i class="rm-tag-' + esc(s.id) + '"></i></span>' +
          "<b>" + esc(s.label) + "</b><small>" + esc(s.blurb) + '</small><span class="rm-go">Open this room</span></button>';
      });
      h += '</div><div class="rm-section"><span class="rm-kicker">JOIN YOUR FRIENDS</span></div>' +
        '<div class="rm-join"><input id="rmCode" maxlength="5" placeholder="CODE" autocomplete="off" spellcheck="false">' +
        '<button class="rm-btn" id="rmJoin">Join</button></div>';
    }
    h += '<div class="rm-msg" id="rmMsg"></div>';
    p.innerHTML = '<div class="rm-card">' + h + "</div>";
    $("rmClose").onclick = close;
    if (r) {
      $("rmLeave").onclick = function () { sfx("ui_menu_onpress"); msg("Going back up..."); emit("tcg:roomLeave", {}); };
    } else {
      Array.prototype.forEach.call(p.querySelectorAll(".rm-style"), function (b) {
        b.onmouseenter = function () { sfx("ui_menu_hover"); };
        b.onclick = function () {
          sfx("ui_menu_item_crafting_done");
          Array.prototype.forEach.call(p.querySelectorAll(".rm-style"), function (x) { x.disabled = true; });
          b.classList.add("going");
          msg("Taking you down...");
          emit("tcg:roomCreate", { style: b.dataset.style });
        };
      });
      var input = $("rmCode");
      input.oninput = function () { input.value = input.value.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 5); };
      input.onkeydown = function (e) { if (e.key === "Enter") join(); e.stopPropagation(); };
      $("rmJoin").onclick = join;
    }
  }
  function join() {
    var code = ($("rmCode").value || "").trim();
    if (code.length < 5) { msg("A room code has 5 characters.", true); sfx("ui_menu_perk_buy_fail"); return; }
    sfx("ui_menu_onpress");
    msg("Looking for room " + code + "...");
    emit("tcg:roomJoin", { code: code });
  }

  function renderBadge() {
    var b = $("roomBadge");
    if (!b) return;
    var r = state.room;
    b.classList.toggle("hidden", !r || open);
    if (r) b.innerHTML = '<span class="rm-dot"></span><span>PRIVATE ROOM &middot; ' + esc(r.label).toUpperCase() + '</span><b>' + esc(r.code) +
      '</b><span class="rm-n">' + (r.count || 0) + "/" + (r.max || 8) + "</span>";
  }

  function close() {
    if (!open) return;
    open = false;
    render();
    emit("tcg:roomsClose", {});
  }

  function init() {
    T = window.TCG;
    mount();
    T.on("tcg:roomsOpen", function (d) { open = true; if (d) state = { room: d.room || null, styles: d.styles || state.styles }; render(); sfx("ui_menu_open"); });
    T.on("tcg:roomsClose", function () { open = false; render(); });
    T.on("tcg:roomState", function (d) { state = { room: d && d.room || null, styles: (d && d.styles) || state.styles }; render(); });
    T.on("tcg:roomEntered", function (r) { open = false; state.room = r; render(); sfx("ui_jingle_new_area"); });
    T.on("tcg:roomLeaving", function () { sfx("ui_menu_onpress"); });
    document.addEventListener("keydown", function (e) { if (open && e.key === "Escape") { e.preventDefault(); close(); } });
    if (T.preview) preview();
  }
  if (window.TCG) init(); else document.addEventListener("tcg:binderReady", init);

  function preview() {
    var q = new URLSearchParams(location.search).get("rooms");
    if (!q) return;
    var styles = STYLE_FALLBACK;
    setTimeout(function () {
      T.hide();
      if (q === "in") {
        T.previewHandlers["tcg:roomState"]({ styles: styles, room: { code: "K7Q2X", style: "jp", label: "Tatami Room", players: ["Yuki", "Jerem Zzzer"], count: 2, max: 8 } });
      }
      T.previewHandlers["tcg:roomsOpen"]({ styles: styles, room: q === "in" ? state.room : null });
    }, 400);
  }
})();
