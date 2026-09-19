(() => {
  'use strict';
  // Presentation only. The Lua side (client/main.lua) owns targeting, the action
  // registry and every decision; this page draws what it is told and sends back
  // normalized click coordinates, the menu epoch and opaque action tokens.
  const $ = id => document.getElementById(id);
  const workspace = $('workspace'), menu = $('menu'), actions = $('actions'), status = $('status'), eye = $('eye');
  const title = $('title'), tag = $('tag'), desc = $('desc'), legend = $('legend'), eyeGlyph = $('eyeGlyph');
  let epoch = 0, opened = false, anchor = {x: .5, y: .5}, busy = false, scale = 1, showGroups = false, pointerFrame = 0, keyName = 'ALT';

  // Lucide glyphs (design system icon set), local: no icon font, no remote asset.
  // The registry only accepts these seven names plus the internal ones below.
  const GLYPHS = {
    interact: [['path', 'M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2'], ['path', 'M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2'], ['path', 'M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8'], ['path', 'M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15']],
    person: [['path', 'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'], ['circle', {cx: 12, cy: 7, r: 4}]],
    vehicle: [['path', 'M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2'], ['circle', {cx: 7, cy: 17, r: 2}], ['path', 'M9 17h6'], ['circle', {cx: 17, cy: 17, r: 2}]],
    info: [['circle', {cx: 12, cy: 12, r: 10}], ['path', 'M12 16v-4'], ['path', 'M12 8h.01']],
    lock: [['rect', {width: 18, height: 11, x: 3, y: 11, rx: 2, ry: 2}], ['path', 'M7 11V7a5 5 0 0 1 10 0v4']],
    tool: [['path', 'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z']],
    location: [['path', 'M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0'], ['circle', {cx: 12, cy: 10, r: 3}]],
    eye: [['path', 'M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0a1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0'], ['circle', {cx: 12, cy: 12, r: 3}]],
    ban: [['circle', {cx: 12, cy: 12, r: 10}], ['path', 'm4.9 4.9 14.2 14.2']],
    scan: [['path', 'M3 7V5a2 2 0 0 1 2-2h2'], ['path', 'M17 3h2a2 2 0 0 1 2 2v2'], ['path', 'M21 17v2a2 2 0 0 1-2 2h-2'], ['path', 'M7 21H5a2 2 0 0 1-2-2v-2']],
  };
  const NS = 'http://www.w3.org/2000/svg';
  function draw(svg, name) {
    svg.replaceChildren();
    for (const [kind, attrs] of GLYPHS[name] || GLYPHS.interact) {
      const el = document.createElementNS(NS, kind);
      if (typeof attrs === 'string') el.setAttribute('d', attrs);
      else for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, String(v));
      svg.append(el);
    }
    return svg;
  }
  function icon(name) {
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    return draw(svg, name);
  }
  const emit = (name, data = {}) => Open77.emit(name, {...data, epoch});
  const clamp = (v, low, high) => Math.max(low, Math.min(high, v));

  function appearance(value) {
    // The design system's accent is the default; the config may still recolour.
    const color = typeof value?.accentColor === 'string' && /^#[\da-f]{6}$/i.test(value.accentColor) ? value.accentColor : '#FFCC00';
    scale = typeof value?.scale === 'number' && Number.isFinite(value.scale) ? clamp(value.scale, .75, 1.5) : 1;
    showGroups = value?.showGroups === true;
    const root = document.documentElement.style;
    root.setProperty('--accent', color);
    root.setProperty('--ui-scale', String(scale));
    const [r, g, b] = [1, 3, 5].map(i => parseInt(color.slice(i, i + 2), 16));
    root.setProperty('--accent-quiet', `rgba(${r}, ${g}, ${b}, .12)`);
    root.setProperty('--line-soft', `rgba(${r}, ${g}, ${b}, .28)`);
  }

  // Header: what was hit and how far. Identifiers stay strings (64-bit safe).
  const KIND_LABELS = {player: 'PLAYER', vehicle: 'VEHICLE', npc: 'NPC', prop: 'PROP', door: 'DOOR', device: 'DEVICE', item: 'ITEM', object: 'OBJECT', world: 'WORLD', sky: 'SKY'};
  function describeTarget(target, distance) {
    const t = target || {};
    const kind = String(t.kind || 'world').toLowerCase();
    let head = t.isLocalPlayer ? 'YOU' : (KIND_LABELS[kind] || kind.toUpperCase());
    const parts = [];
    if (t.playerId != null && !t.isLocalPlayer) parts.push('ID ' + String(t.playerId).padStart(3, '0'));
    else if (t.vehicleId != null) parts.push('#' + String(t.vehicleId).slice(-4));
    else if (t.npcId != null) parts.push('#' + String(t.npcId).slice(-4));
    else if (t.propId != null) parts.push('#' + String(t.propId).slice(-4));
    if (kind === 'npc' && typeof t.record === 'string') head = t.record.replace(/^Character\./, '').replace(/_/g, ' ').toUpperCase().slice(0, 22);
    if (typeof distance === 'number' && Number.isFinite(distance)) parts.push(distance < 10 ? distance.toFixed(1) + 'M' : Math.round(distance) + 'M');
    return {head, tag: parts.join(' // ')};
  }

  function place() {
    const x = anchor.x * innerWidth, y = anchor.y * innerHeight, half = 20 * scale, gap = 10 * scale;
    eye.style.left = clamp(x - half, 8, innerWidth - half * 2 - 8) + 'px';
    eye.style.top = clamp(y - half, 8, innerHeight - half * 2 - 8) + 'px';
    if (menu.hidden) return;
    const right = x + half + gap;
    const left = right + menu.offsetWidth > innerWidth - 8 ? x - half - gap - menu.offsetWidth : right;
    menu.style.left = clamp(left, 8, innerWidth - menu.offsetWidth - 8) + 'px';
    menu.style.top = clamp(y - half, 8, innerHeight - menu.offsetHeight - 8) + 'px';
  }
  function message(text, loading = false, error = false) {
    status.replaceChildren(); status.title = ''; status.classList.toggle('error', error);
    status.hidden = !text;
    if (loading) { const spinner = document.createElement('span'); spinner.className = 'spinner'; spinner.setAttribute('aria-hidden', 'true'); status.append(spinner); }
    if (text) status.append(document.createTextNode(String(text)));
    eye.classList.toggle('blocked', error);
    place();
  }
  function describe(text) {
    desc.hidden = !text;
    desc.textContent = text ? String(text) : '';
    place();
  }
  function setLegend(text) { legend.textContent = text; }

  Open77.on('context:open', p => {
    epoch = p.epoch; opened = true; busy = false; anchor = {x: .5, y: .5};
    keyName = String(p.key || 'ALT').toUpperCase();
    appearance(p.appearance); workspace.hidden = false; menu.hidden = true;
    actions.replaceChildren(); message(''); describe(''); eye.classList.remove('available', 'blocked');
    draw(eyeGlyph, 'eye');
    workspace.setAttribute('aria-label', 'Hold ' + keyName + ', click a target. Release or press Escape to close.');
    place();
  });
  Open77.on('context:close', () => {
    opened = false; busy = false; workspace.hidden = true; menu.hidden = true;
    actions.replaceChildren(); eye.classList.remove('available', 'blocked');
  });
  Open77.on('context:loading', p => {
    if (!opened || !Number.isSafeInteger(p.epoch) || p.epoch < epoch) return;
    epoch = p.epoch; busy = true; anchor = {x: p.x, y: p.y}; menu.hidden = false;
    actions.replaceChildren(); describe(''); eye.classList.remove('available', 'blocked'); draw(eyeGlyph, 'scan');
    title.textContent = 'SCANNING'; tag.textContent = '';
    setLegend('HOLD [' + keyName + ']');
    message('Looking…', true);
  });
  Open77.on('context:empty', p => {
    if (!opened || p.epoch !== epoch) return;
    busy = false; draw(eyeGlyph, 'ban');
    title.textContent = 'NO TARGET'; tag.textContent = '';
    message('No target', false, true); status.title = String(p.message || 'Click another object or surface.');
    describe(p.message ? String(p.message) : '');
  });
  Open77.on('context:menu', p => {
    if (!opened || p.epoch !== epoch) return;
    busy = false; actions.replaceChildren(); message(''); describe(''); let group = '';
    const head = describeTarget(p.target, p.distance);
    title.textContent = head.head; tag.textContent = head.tag;
    const rows = Array.isArray(p.actions) ? p.actions : [];
    for (const action of rows) {
      if (showGroups && action.group !== group) {
        group = action.group; const heading = document.createElement('div'); heading.className = 'group'; heading.textContent = group; actions.append(heading);
      }
      const button = document.createElement('button'); button.type = 'button'; button.className = 'action' + (action.danger ? ' danger' : ''); button.setAttribute('role', 'menuitem');
      button.dataset.token = action.token;
      const glyph = document.createElement('span'); glyph.className = 'icon'; glyph.setAttribute('aria-hidden', 'true'); glyph.append(icon(action.icon));
      const label = document.createElement('span'); label.className = 'label'; label.textContent = action.label;
      button.title = action.description ? action.label + ' — ' + action.description : String(action.label || '');
      if (action.description) button.setAttribute('aria-description', action.description);
      button.append(glyph, label);
      // The description panel follows the hovered / focused row, like the design system's menus.
      const show = () => describe(action.description || '');
      button.addEventListener('mouseenter', show);
      button.addEventListener('focus', show);
      button.addEventListener('click', event => {
        event.stopPropagation(); if (busy) return; busy = true;
        for (const b of actions.querySelectorAll('button')) b.disabled = true;
        emit('context:select', {token: action.token});
      });
      actions.append(button);
    }
    const first = actions.querySelector('button');
    eye.classList.toggle('available', !!first);
    draw(eyeGlyph, first ? 'eye' : 'ban');
    if (!first) message('No actions');
    setLegend(first ? 'HOLD [' + keyName + '] · ↑↓ · ENTER' : 'HOLD [' + keyName + '] · PICK ANOTHER TARGET');
    menu.classList.remove('keyboard');
    place(); menu.focus({preventScroll: true});
  });
  Open77.on('context:busy', p => {
    if (!opened || p.epoch !== epoch) return;
    busy = true;
    const button = [...actions.querySelectorAll('button')].find(b => b.dataset.token === String(p.token));
    if (button) {
      button.classList.add('pending'); const glyph = button.querySelector('.icon');
      const spinner = document.createElement('span'); spinner.className = 'spinner'; glyph.replaceChildren(spinner);
    }
  });
  Open77.on('context:error', p => {
    if (!opened || p.epoch !== epoch) return;
    busy = false;
    for (const b of actions.querySelectorAll('button')) { b.disabled = false; b.classList.remove('pending'); }
    for (const spinner of actions.querySelectorAll('.spinner')) spinner.replaceWith(icon('info'));
    message('Action unavailable', false, true); status.title = String(p.message || 'Try again.');
    describe(p.message ? String(p.message) : 'Try again.');
  });
  document.addEventListener('mousemove', event => {
    menu.classList.remove('keyboard');
    if (!opened || !menu.hidden) return;
    anchor = {x: event.clientX / innerWidth, y: event.clientY / innerHeight};
    if (!pointerFrame) pointerFrame = requestAnimationFrame(() => { pointerFrame = 0; if (opened) place(); });
  });
  document.addEventListener('click', event => {
    if (opened && !busy && !menu.contains(event.target)) emit('context:pick', {x: event.clientX / innerWidth, y: event.clientY / innerHeight});
  });
  document.addEventListener('contextmenu', event => { event.preventDefault(); if (opened) emit('context:cancel'); });
  document.addEventListener('keydown', event => {
    if (!opened) return;
    if (event.key === 'Escape') { event.preventDefault(); emit('context:cancel'); }
    if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
      event.preventDefault(); const buttons = [...actions.querySelectorAll('button:not(:disabled)')]; if (!buttons.length) return;
      const current = buttons.indexOf(document.activeElement);
      const index = event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length - 1 : current < 0 ? (event.key === 'ArrowUp' ? buttons.length - 1 : 0) : (current + (event.key === 'ArrowDown' ? 1 : -1) + buttons.length) % buttons.length;
      menu.classList.add('keyboard');
      buttons[index].focus();
    }
  });
  window.addEventListener('resize', place);
  window.addEventListener('blur', () => { if (opened) emit('context:cancel'); });
  Open77.ready(); Open77.emit('context:ready', {});
})();
