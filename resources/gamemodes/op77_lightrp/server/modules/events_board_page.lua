-- The events board's page (server/modules/events_board.lua serves it): one answer
-- holding the HTML, the CSS (the Light RP design system's tokens, ui/src/design), the
-- JS and the fonts (events_board_fonts.lua). It polls view.json next to itself and
-- rotates its panels; a 1280x720 stage scaled to whatever shows it, the TV's surface
-- or a browser behind the server's reverse proxy.
--
--   NEXT UP    the turf war and the world boss: live, forming, scheduled (counting
--              down on the page) or "none scheduled"
--   ON NOW     the activities, live first, then forming, then open
--   THIS WEEK  the weekly boards (skipped when there are none)
--   RECORDS    the all-time boards (skipped while every one is empty)
--
-- Every text that came from the server is set with textContent, never as markup.
local Page = {}
LightRpEventsBoardPage = Page

local TEMPLATE = [==[<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Events board</title>
<style>
/*__FONTS__*/
:root {
  --o77-black: #050506; --o77-ink-900: #0A0A0C; --o77-ink-800: #111114; --o77-ink-700: #17181C;
  --o77-ink-600: #202127; --o77-ink-500: #2B2D34; --o77-ink-400: #3A3D46; --o77-ink-300: #565A66;
  --o77-ink-200: #8A8F9C; --o77-ink-100: #C3C7D1; --o77-white: #F2F3F5;
  --o77-yellow-400: #FFCC00; --o77-yellow-900: #241B00;
  --o77-red: #FF2E3C; --o77-red-dim: #7A1119; --o77-steel: #7FB4D6; --o77-steel-dim: #1E3B4C; --o77-green: #8FE04A;
  --surface-app: var(--o77-ink-900); --surface-panel: var(--o77-ink-800); --surface-raised: var(--o77-ink-700);
  --text-hi: var(--o77-white); --text-body: var(--o77-ink-100); --text-dim: var(--o77-ink-200);
  --text-on-accent: var(--o77-black); --accent: var(--o77-yellow-400); --accent-quiet: rgba(255, 204, 0, .12);
  --line-hairline: rgba(255, 204, 0, .14); --line-soft: rgba(255, 204, 0, .28); --line-neutral: var(--o77-ink-500);
  --font-display: "Zen Dots", "Chakra Petch", "Bahnschrift", sans-serif;
  --font-core: "Chakra Petch", "Bahnschrift", "Segoe UI", sans-serif;
  --font-mono: "Share Tech Mono", "Cascadia Mono", "Consolas", monospace;
  --glow-text: 0 0 12px rgba(255, 204, 0, .45);
  --tex-scanline: repeating-linear-gradient(to bottom, rgba(255, 255, 255, .035) 0px, rgba(255, 255, 255, .035) 1px, transparent 1px, transparent 3px);
  --tex-grid: linear-gradient(rgba(255, 204, 0, .07) 1px, transparent 1px) 0 0 / 24px 24px, linear-gradient(90deg, rgba(255, 204, 0, .07) 1px, transparent 1px) 0 0 / 24px 24px;
  --clip-chamfer: polygon(10px 0, 100% 0, 100% calc(100% - 10px), calc(100% - 10px) 100%, 0 100%, 0 10px);
  --clip-chamfer-lg: polygon(18px 0, 100% 0, 100% calc(100% - 18px), calc(100% - 18px) 100%, 0 100%, 0 18px);
  --clip-tag: polygon(0 0, 100% 0, calc(100% - 8px) 100%, 0 100%);
  --ease-mech: cubic-bezier(.85, 0, .15, 1);
}
*, *::before, *::after { box-sizing: border-box; }
html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: var(--o77-black); }
body { color: var(--text-body); font-family: var(--font-core); -webkit-font-smoothing: antialiased; cursor: default; user-select: none; }
.stage { position: absolute; left: 0; top: 0; width: 1280px; height: 720px; transform-origin: 0 0; display: flex; flex-direction: column;
  background: var(--surface-app); overflow: hidden; }
.stage::before { content: ""; position: absolute; inset: 0; background: var(--tex-grid); opacity: .5; pointer-events: none; }
.stage::after { content: ""; position: absolute; inset: 0; background: var(--tex-scanline); pointer-events: none; z-index: 5; }

.bar { position: relative; z-index: 1; flex: none; height: 64px; display: flex; align-items: center; justify-content: space-between;
  padding: 0 32px; background: var(--accent); color: var(--text-on-accent); }
.bar__title { display: flex; align-items: center; gap: 16px; font: 700 30px/1 var(--font-mono); letter-spacing: .14em; white-space: nowrap; text-transform: uppercase; }
.bar__sep { opacity: .45; }
.pips { display: flex; gap: 8px; }
.pip { width: 36px; height: 8px; background: rgba(5, 5, 6, .25); }
.pip.is-on { background: var(--o77-black); }

.main { position: relative; z-index: 1; flex: 1; min-height: 0; }
.panel { position: absolute; inset: 26px 32px 22px; display: none; flex-direction: column; gap: 18px; }
.panel.is-active { display: flex; }
.panel.is-enter { animation: wipe .32s var(--ease-mech) both; }
@keyframes wipe { from { clip-path: inset(0 100% 0 0); } to { clip-path: inset(0 0 0 0); } }
.panel__head { flex: none; display: flex; align-items: baseline; gap: 20px; }
.panel__title { font: 400 42px/1 var(--font-display); color: var(--text-hi); letter-spacing: .02em; }
.panel__sub { font: 400 24px/1 var(--font-mono); letter-spacing: .16em; color: var(--text-dim); text-transform: uppercase; }
.tuning { position: absolute; inset: 0; display: grid; place-items: center; font: 400 44px/1 var(--font-display); color: var(--text-dim); letter-spacing: .06em; }

.foot { position: relative; z-index: 1; flex: none; height: 52px; display: flex; align-items: center; justify-content: space-between; gap: 24px;
  padding: 0 32px; background: var(--surface-panel); border-top: 1px solid var(--line-soft);
  font: 400 24px/1 var(--font-mono); letter-spacing: .1em; color: var(--text-body); text-transform: uppercase; white-space: nowrap; }
.foot__join { overflow: hidden; text-overflow: ellipsis; }
.foot__join::before { content: ""; display: inline-block; width: 12px; height: 12px; margin-right: 14px; background: var(--accent); vertical-align: 2px; }
.foot__status { color: var(--o77-red); animation: blink 1.2s steps(1) infinite; }
@keyframes blink { 0%, 49% { opacity: 1; } 50%, 100% { opacity: .2; } }

/* NEXT UP */
.cards { flex: 1; min-height: 0; display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.card { position: relative; display: flex; flex-direction: column; gap: 14px; padding: 26px 30px 26px 36px; min-width: 0; overflow: hidden;
  background: var(--surface-panel); border: 1px solid var(--line-neutral); clip-path: var(--clip-chamfer-lg); }
.card::before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 6px; background: var(--o77-ink-400); }
.card.is-live::before { background: var(--o77-red); }
.card.is-forming::before { background: var(--accent); }
.card.is-scheduled::before { background: var(--o77-steel); }
.card__top { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.card__kicker { font: 400 26px/1 var(--font-mono); letter-spacing: .22em; color: var(--text-dim); text-transform: uppercase; }
.chip { flex: none; font: 700 22px/1 var(--font-mono); letter-spacing: .16em; padding: 8px 16px 7px 12px; clip-path: var(--clip-tag);
  background: var(--o77-ink-500); color: var(--text-hi); text-transform: uppercase; white-space: nowrap; }
.chip.is-live { background: var(--o77-red); color: var(--o77-white); }
.chip.is-forming { background: var(--accent); color: var(--o77-black); }
.chip.is-scheduled { background: var(--o77-steel); color: var(--o77-black); }
.card__headline { font: 400 58px/1.05 var(--font-display); color: var(--text-hi); letter-spacing: .01em; }
.card.is-live .card__headline { color: var(--o77-red); text-shadow: 0 0 18px rgba(255, 46, 60, .35); }
.card.is-forming .card__headline, .card.is-scheduled .card__headline { color: var(--accent); text-shadow: var(--glow-text); }
.card.is-none .card__headline, .card.is-open .card__headline, .card.is-over .card__headline { font-size: 40px; line-height: 1.15; color: var(--text-body); }
.card__where { font: 700 40px/1.1 var(--font-core); color: var(--text-hi); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.card__line { font: 500 29px/1.25 var(--font-core); color: var(--text-body); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.meter { height: 16px; background: var(--o77-red-dim); }
.meter > i { display: block; height: 100%; background: var(--o77-red); }
.card__stats { margin-top: auto; display: flex; flex-wrap: wrap; gap: 8px 28px; font: 400 27px/1 var(--font-mono); letter-spacing: .1em; color: var(--text-dim); text-transform: uppercase; }
.card__stats b { color: var(--text-hi); font-weight: 400; }

/* ON NOW */
.rows { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; overflow: hidden; }
.row { flex: none; display: grid; grid-template-columns: 168px minmax(0, 1fr) auto; align-items: center; gap: 22px; padding: 10px 22px;
  min-height: 62px; background: var(--surface-panel); border-left: 5px solid var(--o77-ink-400); }
.row.is-live { border-left-color: var(--o77-red); background: linear-gradient(90deg, rgba(255, 46, 60, .14), var(--surface-panel) 45%); }
.row.is-forming { border-left-color: var(--accent); background: linear-gradient(90deg, var(--accent-quiet), var(--surface-panel) 45%); }
.row .chip { justify-self: start; }
.row__text { min-width: 0; }
.row__label { display: block; font: 700 32px/1.1 var(--font-core); color: var(--text-hi); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row__line { display: block; margin-top: 3px; font: 500 22px/1.2 var(--font-core); color: var(--text-dim); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row__count { font: 400 28px/1 var(--font-mono); letter-spacing: .08em; color: var(--text-dim); white-space: nowrap; text-transform: uppercase; }
.row__count b { color: var(--text-hi); font-weight: 400; }
.row.is-more { min-height: 44px; border-left-color: transparent; background: none; font: 400 24px/1 var(--font-mono); letter-spacing: .12em; color: var(--text-dim); text-transform: uppercase; display: block; }

/* boards */
.boards { flex: 1; min-height: 0; display: grid; gap: 24px; }
.board { display: flex; flex-direction: column; gap: 10px; padding: 22px 26px; min-width: 0; overflow: hidden;
  background: var(--surface-panel); border: 1px solid var(--line-neutral); clip-path: var(--clip-chamfer); }
.board__title { font: 400 30px/1.1 var(--font-display); color: var(--text-hi); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.board__sub { font: 400 20px/1 var(--font-mono); letter-spacing: .16em; color: var(--text-dim); text-transform: uppercase; margin-bottom: 6px; }
.board__empty { font: 500 28px/1.3 var(--font-core); color: var(--text-dim); }
.entry { display: grid; grid-template-columns: 62px minmax(0, 1fr) auto; align-items: center; gap: 14px; padding: 9px 0; border-top: 1px solid var(--line-hairline); }
.entry__rank { font: 400 30px/1 var(--font-mono); color: var(--text-dim); }
.entry__name { display: flex; align-items: center; gap: 12px; min-width: 0; font: 700 30px/1.15 var(--font-core); color: var(--text-hi); }
.entry__name span { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.entry__swatch { flex: none; width: 16px; height: 16px; }
.entry__value { font: 400 28px/1 var(--font-mono); color: var(--text-body); white-space: nowrap; }
.entry.is-first .entry__rank, .entry.is-first .entry__value { color: var(--accent); }
.boards.is-3 .board__title { font-size: 25px; line-height: 1.15; white-space: normal; height: 2.3em; }
.boards.is-3 .entry__name { font-size: 26px; }
.boards.is-3 .entry__value { font-size: 24px; }
.boards.is-3 .entry { grid-template-columns: 52px minmax(0, 1fr) auto; }
</style>
</head>
<body>
<div class="stage" id="stage">
  <header class="bar">
    <div class="bar__title"><span id="hub"></span><span class="bar__sep">//</span><span id="title"></span></div>
    <div class="pips" id="pips"></div>
  </header>
  <main class="main" id="main"><div class="tuning" id="tuning">TUNING IN</div></main>
  <footer class="foot"><span class="foot__join" id="join"></span><span class="foot__status" id="status"></span></footer>
</div>
<script>
(function () {
  'use strict';
  var CFG = __CONFIG__;
  var stage = document.getElementById('stage');
  var main = document.getElementById('main');
  var pips = document.getElementById('pips');
  var status = document.getElementById('status');
  function fit() {
    var s = Math.min(window.innerWidth / 1280, window.innerHeight / 720) || 1;
    stage.style.transform = 'translate(' + ((window.innerWidth - 1280 * s) / 2) + 'px,' + ((window.innerHeight - 720 * s) / 2) + 'px) scale(' + s + ')';
  }
  window.addEventListener('resize', fit);
  fit();

  // view.json sits next to the page, whatever path a proxy serves it under
  var base = location.pathname.replace(/index\.html$/, '');
  if (base.slice(-1) !== '/') base += '/';
  var DATA = base + 'view.json';

  var view = null, fetchedAt = 0, failures = 0, current = null, timers = [], rotateTimer = null;
  document.getElementById('hub').textContent = CFG.hub || 'The Crossing';
  document.getElementById('title').textContent = CFG.title || "WHAT'S ON";

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
  }
  function list(x) { return Array.isArray(x) ? x : []; }
  function num(x) { return typeof x === 'number' && isFinite(x) ? x : 0; }
  function serverNow() { return view ? num(view.now) + (Date.now() - fetchedAt) : 0; }
  function fmt(ms, approx) {
    var m = Math.ceil(ms / 60000), t = approx ? '~' : '';
    if (ms < 60000) return approx ? '~1 MIN' : Math.max(1, Math.ceil(ms / 1000)) + ' S';
    if (m >= 90) { var h = Math.floor(m / 60), r = m % 60; return t + h + ' H' + (r ? ' ' + r + ' MIN' : ''); }
    return t + m + ' MIN';
  }
  // a text with {t}, counted down every second from a server time
  function timed(node, tpl, at, due, approx) {
    if (typeof at !== 'number' || String(tpl).indexOf('{t}') < 0) { node.textContent = tpl || ''; return node; }
    timers.push({ node: node, tpl: String(tpl), at: at, due: due, approx: approx === true });
    return node;
  }
  function tick() {
    var now = serverNow();
    timers.forEach(function (t) {
      var left = t.at - now;
      t.node.textContent = left > 0 ? t.tpl.replace('{t}', fmt(left, t.approx)) : (t.due || t.tpl.replace('{t}', 'NOW'));
    });
  }

  var CHIPS = { live: 'LIVE', forming: 'FORMING', scheduled: 'SCHEDULED', open: 'OPEN', over: 'OVER' };

  function card(kicker, d, boss) {
    d = d || {};
    var state = (CHIPS[d.state] || d.state === 'none') ? d.state : 'none';
    var c = el('div', 'card is-' + state);
    var top = el('div', 'card__top');
    top.appendChild(el('div', 'card__kicker', kicker));
    if (CHIPS[state] && state !== 'open') top.appendChild(el('span', 'chip is-' + state, CHIPS[state]));
    c.appendChild(top);
    c.appendChild(timed(el('div', 'card__headline'), d.headline || '', d.atMs, d.due, d.approx));
    if (d.where) c.appendChild(el('div', 'card__where', d.where));
    if (d.line) c.appendChild(el('div', 'card__line', d.line));
    if (boss && state === 'live' && typeof d.health === 'number') {
      var meter = el('div', 'meter'), fill = el('i');
      fill.style.width = Math.round(Math.max(0, Math.min(1, d.health)) * 100) + '%';
      meter.appendChild(fill);
      c.appendChild(meter);
    }
    var stats = el('div', 'card__stats');
    function stat(n, label) { var s = el('span'); s.appendChild(el('b', null, n)); s.appendChild(document.createTextNode(' ' + label)); stats.appendChild(s); }
    if (boss && state === 'live') {
      stat(num(d.fighters), num(d.fighters) === 1 ? 'FIGHTER' : 'FIGHTERS');
      if (typeof d.endsAtMs === 'number') stats.appendChild(timed(el('span'), '{t} LEFT', d.endsAtMs, 'TIME UP'));
    } else if (!boss && (state === 'live' || state === 'forming')) {
      if (state === 'live') stat(num(d.players), 'FIGHTING');
      if (num(d.queued) > 0 || state === 'forming') stat(num(d.queued), 'QUEUED');
    }
    if (stats.childNodes.length) c.appendChild(stats);
    return c;
  }

  function renderNext(panel, v) {
    var cards = el('div', 'cards');
    cards.appendChild(card('TURF WAR', v.turf, false));
    cards.appendChild(card('WORLD BOSS', v.boss, true));
    panel.appendChild(cards);
  }

  function renderLive(panel, v) {
    var rows = el('div', 'rows');
    panel.appendChild(rows);
    var items = list(v.activities);
    items.forEach(function (a) {
      var state = CHIPS[a.state] ? a.state : 'open';
      var row = el('div', 'row is-' + state);
      row.appendChild(el('span', 'chip is-' + state, CHIPS[state]));
      var text = el('div', 'row__text');
      text.appendChild(el('span', 'row__label', a.label || ''));
      if (a.line && state !== 'open') text.appendChild(el('span', 'row__line', a.line));
      row.appendChild(text);
      var count = el('div', 'row__count');
      function part(n, label) {
        if (count.childNodes.length) count.appendChild(document.createTextNode(' \u00B7 '));
        count.appendChild(el('b', null, n));
        count.appendChild(document.createTextNode(' ' + label));
      }
      if (state === 'live') part(num(a.players), 'IN');
      if (num(a.queued) > 0) part(num(a.queued), 'QUEUED');
      row.appendChild(count);
      rows.appendChild(row);
    });
    return rows;
  }
  // rows past the screen go, and the screen says how many
  function used(rows) { var last = rows.lastChild; return last ? last.offsetTop + last.offsetHeight - rows.offsetTop : 0; }
  function fitRows(rows) {
    var dropped = 0;
    while (rows.childNodes.length > 1 && used(rows) > rows.clientHeight + 1) { rows.removeChild(rows.lastChild); dropped++; }
    if (dropped > 0) {
      if (used(rows) + 52 > rows.clientHeight && rows.childNodes.length > 1) { rows.removeChild(rows.lastChild); dropped++; }
      rows.appendChild(el('div', 'row is-more', '+' + dropped + ' MORE IN F1 > ACTIVITIES'));
    }
  }

  function renderBoards(panel, boards) {
    var grid = el('div', 'boards' + (boards.length >= 3 ? ' is-3' : ''));
    grid.style.gridTemplateColumns = 'repeat(' + Math.max(1, Math.min(3, boards.length)) + ', minmax(0, 1fr))';
    boards.slice(0, 3).forEach(function (b) {
      var box = el('div', 'board');
      box.appendChild(el('div', 'board__title', b.title || ''));
      if (b.subtitle) box.appendChild(el('div', 'board__sub', b.subtitle));
      var rows = list(b.rows);
      if (!rows.length) box.appendChild(el('div', 'board__empty', b.empty || 'Nobody yet.'));
      rows.forEach(function (r, i) {
        var e = el('div', 'entry' + (num(r.rank) === 1 || (i === 0 && !r.rank) ? ' is-first' : ''));
        e.appendChild(el('span', 'entry__rank', '#' + (num(r.rank) || i + 1)));
        var name = el('span', 'entry__name');
        if (typeof r.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(r.color)) { var sw = el('i', 'entry__swatch'); sw.style.background = r.color; name.appendChild(sw); }
        name.appendChild(el('span', null, r.name || '?'));
        e.appendChild(name);
        e.appendChild(el('span', 'entry__value', r.value || ''));
        box.appendChild(e);
      });
      grid.appendChild(box);
    });
    panel.appendChild(grid);
  }

  var PANELS = [
    { id: 'next', title: 'NEXT UP', show: function () { return true; }, render: renderNext },
    { id: 'live', title: 'ON NOW', sub: 'Activities', show: function (v) { return list(v.activities).length > 0; },
      render: function (panel, v) { return renderLive(panel, v); }, after: fitRows },
    { id: 'week', title: 'THIS WEEK', show: function (v) { return list(v.weekly).length > 0; },
      render: function (panel, v) { renderBoards(panel, list(v.weekly)); } },
    { id: 'records', title: 'RECORDS', sub: 'All time',
      show: function (v) { return list(v.records).some(function (b) { return list(b.rows).length > 0; }); },
      render: function (panel, v) { renderBoards(panel, list(v.records)); } },
  ];

  function shown() { return view ? PANELS.filter(function (p) { return p.show(view); }) : []; }

  // enter: the panel changed (wiped in); a data refresh redraws it in place
  function draw(enter) {
    timers = [];
    var panels = shown();
    if (!panels.length) return;
    if (!current || panels.indexOf(current) < 0) { current = panels[0]; enter = true; }
    main.textContent = '';
    var panel = el('section', 'panel is-active' + (enter ? ' is-enter' : ''));
    var head = el('div', 'panel__head');
    head.appendChild(el('div', 'panel__title', current.title));
    if (current.sub) head.appendChild(el('div', 'panel__sub', current.sub));
    panel.appendChild(head);
    main.appendChild(panel);
    var made = current.render(panel, view);
    if (current.after && made) current.after(made);
    pips.textContent = '';
    panels.forEach(function (p) { pips.appendChild(el('i', 'pip' + (p === current ? ' is-on' : ''))); });
    tick();
  }

  function rotate() {
    var panels = shown();
    if (panels.length) {
      var i = panels.indexOf(current), next = panels[(i + 1) % panels.length];
      var changed = next !== current;
      current = next;
      draw(changed);
    }
    rotateTimer = setTimeout(rotate, Math.max(3000, num(view && view.rotateMs) || CFG.rotateMs || 5000));
  }

  function poll() {
    var wait = Math.max(2000, num(view && view.pollMs) || CFG.pollMs || 10000);
    fetch(DATA, { cache: 'no-store' }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    }).then(function (data) {
      if (!data || typeof data !== 'object') throw new Error('bad data');
      var first = !view;
      view = data;
      fetchedAt = Date.now();
      failures = 0;
      status.textContent = '';
      if (data.hub) document.getElementById('hub').textContent = data.hub;
      if (data.title) document.getElementById('title').textContent = data.title;
      document.getElementById('join').textContent = data.join || '';
      draw(first);
      if (first) { clearTimeout(rotateTimer); rotateTimer = setTimeout(rotate, Math.max(3000, num(data.rotateMs) || 5000)); }
    }).catch(function () {
      failures++;
      if (failures >= 2 || !view) status.textContent = 'NO SIGNAL';
      wait = Math.min(wait, 5000);
    }).then(function () { setTimeout(poll, wait); });
  }

  setInterval(tick, 1000);
  poll();
})();
</script>
</body>
</html>
]==]

-- A JSON string safe inside a <script> (no "<", ">" or "&" left to close it).
local function jsonString(value)
    local s = tostring(value or ""):gsub('[%c"\\<>&]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end)
    return '"' .. s .. '"'
end
Page.jsonString = jsonString

-- The @font-face rules, from events_board_fonts.lua (system fonts without it).
function Page.fontsCss()
    local F = LightRpEventsBoardFonts
    if type(F) ~= "table" or type(F.faces) ~= "table" then return "" end
    local rules = {}
    for _, f in ipairs(F.faces) do
        if type(f.data) == "string" and f.data:match("^[%w%+/=]+$") then
            rules[#rules + 1] = string.format("@font-face{font-family:'%s';font-style:normal;font-weight:%d;font-display:block;src:url(data:font/woff2;base64,%s) format('woff2');}",
                (tostring(f.family):gsub("[^%w ]", "")), math.floor(tonumber(f.weight) or 400), f.data)
        end
    end
    return table.concat(rules, "\n")
end

-- opts: { title, hub, pollMs, rotateMs } -> the page's HTML
function Page.render(opts)
    opts = opts or {}
    local config = string.format('{"title":%s,"hub":%s,"pollMs":%d,"rotateMs":%d}', jsonString(opts.title), jsonString(opts.hub),
        math.floor(tonumber(opts.pollMs) or 10000), math.floor(tonumber(opts.rotateMs) or 5000))
    local fonts = Page.fontsCss()
    local html = TEMPLATE:gsub("/%*__FONTS__%*/", function() return fonts end, 1)
    html = html:gsub("__CONFIG__", function() return config end, 1)
    return html
end
