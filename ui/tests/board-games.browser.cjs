// Seated at a table: the pointer layer and the compact bottom bar
// (ui/src/features/board-games/TableBar.tsx), driven through a fake Open77
// bridge on the BUILT page. No game, no server; static files are fulfilled
// in-process. Build the UI first (npm --prefix ui run build).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const dist = path.resolve(process.env.BOARD_GAMES_WEB_DIR || path.resolve(__dirname, '../../resources/gamemodes/op77_lightrp/web'));

const BOARD_VIEWS = [{ key: 'overhead', label: 'Overhead' }, { key: 'white', label: 'White side' }, { key: 'black', label: 'Black side' }, { key: 'orbit', label: 'Orbit' }];
const CASINO_VIEWS = [{ key: 'seat', label: 'Seat' }, { key: 'overhead', label: 'Overhead' }, { key: 'orbit', label: 'Orbit' }];
const chip = (value, presets, label = 'Chip', max = 5000) => ({ value, min: presets[0], max, presets, label });
// One realistic view per table kind, plus what the bar must do with it.
const CASES = [
  { view: { active: true, kind: 'chess', boardId: 'b12', title: 'Chess', status: 'Your turn', tone: 'turn', detail: 'You play White · 1v1', hint: 'Drag a piece or click its destination',
      actions: [{ key: 'newGame', label: 'New game', enabled: false }, { key: 'mode', label: 'Mode: 1v1', enabled: true }], views: BOARD_VIEWS, view: 'white', camera: true },
    camera: 'Camera: White side' },
  { view: { active: true, kind: 'checkers', boardId: 7, title: 'Checkers', status: 'Opponent’s turn', detail: 'You play Black · Solo vs AI', hint: 'Click a piece, then its destination',
      actions: [{ key: 'newGame', label: 'New game', enabled: true }], views: BOARD_VIEWS, view: 'overhead', camera: true },
    camera: 'Camera: Overhead' },
  { view: { active: true, kind: 'connect4', boardId: 'c4', title: 'Connect Four', status: 'Red wins', tone: 'result', detail: 'You play Red · 1v1', hint: 'Click a column to drop a disc',
      actions: [{ key: 'newGame', label: 'New game', enabled: true, primary: true }], views: BOARD_VIEWS, view: 'orbit', orbit: true, camera: true },
    camera: 'Camera: Orbit' },
  { view: { active: true, kind: 'roulette', boardId: 'r1', title: 'Roulette', status: 'Place your bets', tone: 'turn', detail: 'Your stake €$ 300 · 2 bets', hint: 'Click a number or a box on the layout', countdownMs: 12000,
      chip: chip(100, [10, 50, 100, 500, 1000, 5000]), target: 'Red · pays 1:1',
      actions: [{ key: 'bet', label: 'Place bet', enabled: true, primary: true }, { key: 'clear', label: 'Clear bets', enabled: true }, { key: 'spin', label: 'Spin', enabled: false }],
      views: CASINO_VIEWS, view: 'seat', camera: true },
    camera: 'Camera: Seat', chipDown: 50, chipUp: 500, countdown: '12 s' },
  { view: { active: true, kind: 'slots', boardId: 's3', title: 'Slot Machine', status: 'Ready', detail: 'Last spin: no win', hint: 'Click the lever to pull',
      chip: chip(10, [10, 25, 50, 100, 250], 'Bet', 250), actions: [{ key: 'pull', label: 'Pull', enabled: true, primary: true }], views: {}, view: 'seat' },
    chipDown: null, chipUp: 25 },
  { view: { active: true, kind: 'blackjack', boardId: 'bj', title: 'Blackjack', status: 'Hand 16 · Dealer 9', tone: 'turn', detail: 'Your bet €$ 1,000', hint: 'Hit, Stand or Double from the bar', countdownMs: 8000,
      chip: chip(750, [10, 50, 100, 500, 1000, 5000], 'Bet'), target: 'Seat 2',
      actions: [{ key: 'hit', label: 'Hit', enabled: true, primary: true }, { key: 'stand', label: 'Stand', enabled: true }, { key: 'double', label: 'Double', enabled: false }],
      views: CASINO_VIEWS, view: 'overhead', camera: true },
    camera: 'Camera: Overhead', chipDown: 500, chipUp: 1000, countdown: '8 s' },
  { view: { active: true, kind: 'fortune', boardId: 'f', title: 'Fortune Wheel', status: 'Place your bets', detail: '3 players at the table', hint: 'Click a felt spot to pick it', countdownMs: 20000,
      chip: chip(5000, [10, 50, 100, 500, 1000, 5000]), target: '×20 · pays 20:1',
      actions: [{ key: 'bet', label: 'Bet', enabled: true, primary: true }, { key: 'spin', label: 'Spin', enabled: true }], views: CASINO_VIEWS, view: 'seat', camera: true },
    camera: 'Camera: Seat', chipDown: 1000, chipUp: null, countdown: '20 s' },
  { view: { active: true, kind: 'pool', boardId: 'p', title: 'Pool', status: 'Your shot', tone: 'turn', detail: 'Power 64% · You: solids', hint: 'Drag back from the cue ball, release to shoot',
      actions: [{ key: 'rack', label: 'Re-rack', enabled: false }, { key: 'concede', label: 'Concede', enabled: true }], views: [{ key: 'cue', label: 'Cue' }, { key: 'overhead', label: 'Overhead' }, { key: 'orbit', label: 'Orbit' }],
      view: 'orbit', orbit: true, camera: true },
    camera: 'Camera: Orbit' },
];
// Free: on the character. Crosshair (overlay bar) and with the cursor out (H).
const ROULETTE = CASES.find(c => c.view.kind === 'roulette').view;
const FREE_VIEW = { ...ROULETTE, views: [...CASINO_VIEWS, { key: 'free', label: 'Free' }], view: 'free', camera: false, free: { cursor: false, key: 'H' } };
const FREE_CURSOR_VIEW = { ...FREE_VIEW, free: { cursor: true, key: 'H' } };
// Placing a table: the bar in its placement mode, as client/core/board_games.lua sends it.
const PLACEMENT_VIEW = { active: true, placing: true, mode: 'placement', kind: 'blackjack', title: 'Place: Blackjack', status: 'Drag it where it goes', tone: 'turn',
  detail: 'Turn 45° · Height +0.10 m', hint: 'Press or drag on the ground to move it', views: {},
  actions: [{ key: 'place.left', label: 'Left', title: 'Turn left', keycap: '←', enabled: true }, { key: 'place.right', label: 'Right', title: 'Turn right', keycap: '→', enabled: true },
    { key: 'place.up', label: 'Up', title: 'Raise', keycap: 'PgUp', enabled: true }, { key: 'place.down', label: 'Down', title: 'Lower', keycap: 'PgDn', enabled: true },
    { key: 'place.confirm', label: 'Place', title: 'Place it here', keycap: 'E', enabled: true, primary: true }] };
// The busiest bars, for the layout checks.
const BUSY = [
  FREE_VIEW, FREE_CURSOR_VIEW, PLACEMENT_VIEW, { ...PLACEMENT_VIEW, status: 'Too far: bring it closer', tone: 'warn' },
  CASES.find(c => c.view.kind === 'blackjack').view,
  { ...CASES.find(c => c.view.kind === 'roulette').view, target: 'Split 17/20 · pays 17:1 · corner bets closed soon', leaving: 2500, detail: 'Your stake €$ 12,300 · 9 bets on the layout this round', hint: 'Click a number or a box on the layout to choose the target' },
  { ...CASES.find(c => c.view.kind === 'pool').view, leaving: 1200 },
];

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.BROWSER_CHANNEL ? { channel: process.env.BROWSER_CHANNEL } : {}), ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    await page.route('http://boards.test/**', route => {
      const rel = new URL(route.request().url()).pathname.slice(1) || 'index.html';
      const file = path.resolve(dist, rel);
      if (!file.startsWith(dist + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404, body: '' });
      return route.fulfill({ body: fs.readFileSync(file), contentType: { '.js': 'application/javascript', '.css': 'text/css', '.html': 'text/html', '.woff2': 'font/woff2' }[path.extname(file)] || 'application/octet-stream' });
    });
    await page.addInitScript(() => {
      const handlers = {};
      window.testBridge = { sent: [], fire: (name, payload) => (handlers[name] || []).forEach(fn => fn(payload)) };
      window.Open77 = { on: (name, fn) => (handlers[name] ??= []).push(fn), emit: (name, payload) => testBridge.sent.push({ name, payload }), ready() {} };
    });
    await page.goto('http://boards.test/');
    await page.waitForFunction(() => testBridge.sent.some(e => e.name.endsWith(':ready')));
    // JSON round trip, as through the bridge; resolves once React has painted it.
    const show = view => page.evaluate(async view => {
      testBridge.fire('lightrp:boardGames:view', JSON.parse(view));
      await new Promise(resolve => requestAnimationFrame(() => setTimeout(resolve, 0)));
    }, JSON.stringify(view));
    const clear = () => page.evaluate(() => { testBridge.sent = []; });
    const sent = name => page.evaluate(name => testBridge.sent.filter(e => e.name === name).map(e => e.payload), name);
    const bar = page.getByLabel('Table controls');
    const gameplayHidden = () => page.locator('.gameplay-interface').evaluate(el => el.hidden);

    assert.equal(await page.locator('.table-layer').count(), 0, 'nothing drawn before a view');
    assert.equal(await gameplayHidden(), false);

    for (const { view, camera, chipDown, chipUp, countdown } of CASES) {
      const kind = view.kind;
      await show(view);
      await bar.waitFor();
      await clear();
      assert.equal(await gameplayHidden(), true, `${kind}: gameplay HUD hidden while seated`);
      assert.equal(await page.locator('.table-bar__title').innerText(), view.title.toUpperCase(), `${kind}: title`);
      assert.equal(await bar.getByRole('status').innerText(), view.status, `${kind}: status`);
      if (countdown) assert.equal(await page.locator('.table-bar__countdown').innerText(), countdown, `${kind}: countdown`);
      else assert.equal(await page.locator('.table-bar__countdown').count(), 0, `${kind}: no countdown`);
      if (view.target) assert.equal(await page.locator('.table-bar__target').innerText(), view.target);
      else assert.equal(await page.locator('.table-bar__target').count(), 0, `${kind}: no target pill`);

      // Only the given actions, in order, with their state.
      const buttons = page.locator('.table-bar__actions button');
      assert.deepEqual(await buttons.allInnerTexts(), view.actions.map(a => a.label.toUpperCase()), `${kind}: actions`);
      for (const [i, action] of view.actions.entries()) {
        assert.equal(await buttons.nth(i).isEnabled(), action.enabled, `${kind}: ${action.key} enabled`);
        assert.equal(await buttons.nth(i).evaluate(el => el.classList.contains('o77-btn--primary')), !!action.primary, `${kind}: ${action.key} primary`);
      }
      const usable = view.actions.find(a => a.enabled);
      await bar.getByRole('button', { name: usable.label, exact: true }).click();
      assert.deepEqual(await sent('lightrp:boardGames:action'), [{ key: usable.key }], `${kind}: action emitted`);
      assert.deepEqual((await sent('lightrp:boardGames:pointer')).filter(p => !p.blocked), [], `${kind}: a bar click never reaches the table`);
      assert((await sent('lightrp:boardGames:pointer')).some(p => p.blocked), `${kind}: bar click reports blocked`);

      // Chip stepping through the presets.
      if (view.chip) {
        const lower = bar.getByRole('button', { name: 'Lower chip' });
        const raise = bar.getByRole('button', { name: 'Raise chip' });
        assert.equal(await bar.getByRole('group', { name: view.chip.label }).count(), 1);
        assert.match(await page.locator('.table-bar__chip-value b').innerText(), new RegExp(`^€\\$ ${view.chip.value.toLocaleString('en-US')}$`));
        assert.equal(await lower.isEnabled(), chipDown !== null, `${kind}: lower enabled`);
        assert.equal(await raise.isEnabled(), chipUp !== null, `${kind}: raise enabled`);
        await clear();
        if (chipDown !== null) await lower.click();
        if (chipUp !== null) await raise.click();
        assert.deepEqual(await sent('lightrp:boardGames:chip'), [chipDown, chipUp].filter(v => v !== null).map(amount => ({ amount })), `${kind}: chip presets`);
      } else assert.equal(await page.locator('.table-bar__chip').count(), 0, `${kind}: no chip`);

      // Camera switch.
      const cam = bar.getByRole('button', { name: /^Camera:/ });
      if (camera) {
        assert.equal(await cam.getAttribute('aria-label'), camera, `${kind}: camera label`);
        assert.match((await cam.innerText()).replace(/\s+/g, ' '), new RegExp(`CAMERA ${camera.slice(8).toUpperCase()}`));
        await clear(); await cam.click();
        assert.deepEqual(await sent('lightrp:boardGames:camera'), [{ cycle: true }], `${kind}: camera cycle`);
      } else assert.equal(await cam.count(), 0, `${kind}: no camera button without views`);

      // Picking on the table: normalized coordinates and edges.
      const { width, height } = page.viewportSize();
      await clear();
      await page.mouse.move(width * .5, height * .4);
      await page.mouse.down(); await page.mouse.move(width * .55, height * .45); await page.mouse.up();
      let pointers = await sent('lightrp:boardGames:pointer');
      const pressed = pointers.find(p => p.pressed);
      assert(pressed && Math.abs(pressed.x - .5) < .002 && Math.abs(pressed.y - .4) < .002, `${kind}: pressed at the cursor ${JSON.stringify(pointers)}`);
      const released = pointers.find(p => p.released);
      assert(released && Math.abs(released.x - .55) < .002 && Math.abs(released.y - .45) < .002, `${kind}: released`);
      assert(pointers.every(p => p.blocked || (p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1)));
      await page.mouse.move(width * .3, height * .3); await page.mouse.down({ button: 'right' }); await page.mouse.up({ button: 'right' });
      pointers = await sent('lightrp:boardGames:pointer');
      assert(pointers.some(p => p.rightPressed) && pointers.some(p => p.rightReleased), `${kind}: right button edges`);

      // Pressing on the bar: blocked, never a pressed edge.
      await clear();
      const info = await page.locator('.table-bar__info').boundingBox();
      await page.mouse.move(info.x + info.width / 2, info.y + info.height / 2);
      await page.mouse.down(); await page.mouse.up();
      pointers = await sent('lightrp:boardGames:pointer');
      assert(pointers.some(p => p.blocked), `${kind}: bar press blocked`);
      assert(!pointers.some(p => p.pressed || p.released), `${kind}: bar press is not a table press`);

      // Wheel zooms only in an orbit view.
      await clear();
      await page.mouse.move(width * .5, height * .4);
      await page.mouse.wheel(0, 120);
      if (view.orbit) {
        await page.waitForFunction(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:camera' && e.payload.zoom === 1));
        await page.mouse.wheel(0, -120);
        await page.waitForFunction(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:camera' && e.payload.zoom === -1));
        assert.equal(await page.locator('.table-bar__orbit').innerText(), 'Right-drag: orbit · Wheel: zoom');
      } else {
        await page.waitForTimeout(50);
        assert.deepEqual(await sent('lightrp:boardGames:camera'), [], `${kind}: no zoom outside orbit`);
        assert.equal(await page.locator('.table-bar__orbit').count(), 0);
      }

      // Leave: the button (it shows ESC) and Escape; Backspace is not a leave key any more.
      await clear();
      const leave = bar.getByRole('button', { name: /Leave/ });
      assert.match(await leave.innerText(), /ESC/, `${kind}: the Leave button shows Escape`);
      await leave.click();
      await page.keyboard.press('Backspace');
      await page.keyboard.press('Escape');
      assert.deepEqual(await sent('lightrp:boardGames:leave'), [{}, { key: 'escape' }], `${kind}: leave by button and Escape only`);
      assert.deepEqual(errors, [], `${kind}: page errors`);
    }

    // Free, crosshair: the bar is an overlay (nothing takes the pointer, the
    // gameplay HUD stays), a dot marks the centre, the cursor key is shown.
    await show(FREE_VIEW);
    await bar.waitFor();
    assert.equal(await gameplayHidden(), false, 'Free keeps the gameplay HUD');
    assert.equal(await page.locator('.table-crosshair').count(), 1, 'the crosshair dot');
    const freeText = await page.getByLabel('Free view keys').innerText();
    for (const expected of [/Crosshair: aim/, /Click: play/, /H/, /cursor for the bar/, /ESC/]) assert.match(freeText, expected);
    assert.equal(await page.locator('.table-bar button').count(), 0, 'no buttons without the cursor');
    assert.equal(await page.locator('.table-layer').evaluate(el => getComputedStyle(el).pointerEvents), 'none', 'the overlay never takes the pointer');
    assert.match(await bar.getByRole('status').innerText(), new RegExp(ROULETTE.status));
    await clear();
    const vp = page.viewportSize();
    await page.mouse.click(vp.width * .5, vp.height * .4);
    assert.deepEqual(await sent('lightrp:boardGames:pointer'), [], 'a click in Free reaches the game, not the page');
    // The table keys go to Lua, the cursor key included; Escape still leaves.
    await page.keyboard.press('h');
    await page.keyboard.press('Escape');
    assert.deepEqual(await sent('lightrp:boardGames:key'), [{ key: 'H', down: true }, { key: 'H', down: false }], 'H forwarded');
    assert.deepEqual(await sent('lightrp:boardGames:leave'), [{ key: 'escape' }], 'Escape leaves from Free');
    // Free with the cursor out: the full bar, the pointer layer, HUD still shown.
    await show(FREE_CURSOR_VIEW);
    await page.getByRole('button', { name: /^Camera:/ }).waitFor();
    assert.equal(await gameplayHidden(), false);
    assert.equal(await page.locator('.table-crosshair').count(), 0);
    assert.match(await page.getByLabel('Free view keys').innerText(), /back to the crosshair/);
    assert.equal(await page.getByRole('button', { name: /^Camera:/ }).getAttribute('aria-label'), 'Camera: Free');
    await clear();
    await page.mouse.move(vp.width * .5, vp.height * .4);
    await page.mouse.down(); await page.mouse.up();
    assert((await sent('lightrp:boardGames:pointer')).some(p => p.pressed), 'a click with the cursor still picks');

    // Placing a table: the bar in its placement mode. A press and a drag on
    // the world go to Lua; the buttons step; Cancel and Escape cancel; the
    // keys are forwarded (held arrows with their release).
    await show(PLACEMENT_VIEW);
    await bar.waitFor();
    assert.equal(await page.locator('.table-bar__title').innerText(), 'PLACE: BLACKJACK');
    assert.match(await page.getByLabel('Placement keys').innerText(), /Drag: move.*turn.*height.*place/s);
    const placeButtons = page.locator('.table-bar__actions button');
    assert.deepEqual((await placeButtons.allInnerTexts()).map(t => t.replace(/\s+/g, ' ').trim()), ['LEFT ←', 'RIGHT →', 'UP PGUP', 'DOWN PGDN', 'PLACE E']);
    assert.equal(await bar.getByRole('button', { name: 'Place it here' }).evaluate(el => el.classList.contains('o77-btn--primary')), true);
    assert.equal(await bar.getByRole('button', { name: /^Camera:/ }).count(), 0);
    await clear();
    await bar.getByRole('button', { name: 'Turn left' }).click();
    await bar.getByRole('button', { name: 'Raise' }).click();
    await bar.getByRole('button', { name: 'Place it here' }).click();
    assert.deepEqual(await sent('lightrp:boardGames:action'), [{ key: 'place.left' }, { key: 'place.up' }, { key: 'place.confirm' }]);
    await clear();
    await page.mouse.move(vp.width * .4, vp.height * .3); await page.mouse.down();
    await page.mouse.move(vp.width * .45, vp.height * .35); await page.mouse.up();
    const drag = await sent('lightrp:boardGames:pointer');
    assert(drag.some(p => p.pressed) && drag.some(p => p.released) && drag.some(p => !p.pressed && !p.released && !p.blocked), `placement drag forwarded ${JSON.stringify(drag)}`);
    await clear();
    await page.keyboard.down('ArrowLeft'); await page.keyboard.up('ArrowLeft');
    await page.keyboard.press('PageUp'); await page.keyboard.press('e');
    assert.deepEqual(await sent('lightrp:boardGames:key'), [{ key: 'LEFT', down: true }, { key: 'LEFT', down: false },
      { key: 'PAGEUP', down: true }, { key: 'PAGEUP', down: false }, { key: 'E', down: true }, { key: 'E', down: false }], 'placement keys forwarded');
    await clear();
    const cancel = bar.getByRole('button', { name: /Cancel/ });
    assert.match(await cancel.innerText(), /ESC/);
    await cancel.click();
    await page.keyboard.press('Escape');
    assert.deepEqual(await sent('lightrp:boardGames:leave'), [{}, { key: 'escape' }], 'Cancel and Escape cancel a placement');
    assert.deepEqual(errors, [], 'page errors in Free and placement');

    // The countdown runs locally between two views.
    await show(CASES.find(c => c.view.kind === 'roulette').view);
    await page.waitForFunction(() => document.querySelector('.table-bar__countdown')?.textContent === '11 s', null, { timeout: 3000 });

    // Lua empty tables arrive as {}: nothing to show, nothing crashes.
    await show({ active: true, kind: 'blackjack', boardId: 1, title: 'Blackjack', status: 'Waiting for players', actions: {}, views: {}, view: '', chip: { value: 0, min: 0, max: 0, presets: {}, label: 'Bet' } });
    await bar.waitFor();
    assert.equal(await page.locator('.table-bar__actions').count(), 0);
    assert.equal(await bar.getByRole('button', { name: /^Camera:/ }).count(), 0);
    assert.equal(await bar.getByRole('button', { name: 'Lower chip' }).isEnabled(), false);
    assert.equal(await bar.getByRole('button', { name: 'Raise chip' }).isEnabled(), false);
    await show({ active: true, kind: 'chess', boardId: 2, title: 'Chess', actions: { 1: { key: 'newGame', label: 'New game', enabled: true }, 2: { key: 'resign', label: 'Resign', enabled: true } }, views: {}, view: 'overhead' });
    assert.deepEqual(await page.locator('.table-bar__actions button').allInnerTexts(), ['NEW GAME', 'RESIGN'], 'sparse Lua lists read in order');

    // Walking away: the warning.
    await show({ ...CASES[0].view, leaving: 1500 });
    assert.match(await bar.getByRole('alert').innerText(), /Too far from the table — step back or you leave your seat\./);

    // Layout: the bar never covers the table centre, keeps 16 px gutters, stays short.
    const boxes = {};
    for (const size of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }]) {
      await page.setViewportSize(size);
      for (const view of [...CASES.map(c => c.view), ...BUSY]) {
        await show(view);
        await bar.waitFor();
        await page.waitForTimeout(220); // entry animation
        const box = await bar.boundingBox();
        const label = `${size.width}x${size.height} ${view.kind}${view.mode ? ` ${view.mode}${view.tone === 'warn' ? ' far' : ''}` : ''}${view.free ? (view.free.cursor ? ' free+cursor' : ' free') : ''}${view.leaving ? ' (leaving)' : ''}`;
        const centre = { x0: size.width * .25, x1: size.width * .75, y0: size.height * .25, y1: size.height * .75 };
        const intersects = box.x < centre.x1 && box.x + box.width > centre.x0 && box.y < centre.y1 && box.y + box.height > centre.y0;
        assert(!intersects, `${label}: bar ${JSON.stringify(box)} covers the centre`);
        assert(box.x >= 16 && box.x + box.width <= size.width - 16, `${label}: gutters ${JSON.stringify(box)}`);
        assert(box.height <= 120, `${label}: height ${box.height}`);
        assert(box.width <= 960.5, `${label}: width ${box.width}`);
        const bottomGap = size.height - (box.y + box.height);
        assert(bottomGap >= 16 && bottomGap <= 24, `${label}: bottom offset ${bottomGap}`);
        const fit = await page.evaluate(() => {
          const row = document.querySelector('.table-bar__row'), status = document.querySelector('.table-bar__status');
          return { overflow: row.scrollWidth > row.clientWidth + 1, statusCut: !!status && status.scrollWidth > status.clientWidth + 1 };
        });
        assert.deepEqual(fit, { overflow: false, statusCut: false }, `${label}: every control fits, the status is never cut`);
        boxes[label] = box;
      }
    }
    for (const [label, b] of Object.entries(boxes)) console.log(`  ${label.padEnd(30)} x=${Math.round(b.x)} y=${Math.round(b.y)} w=${Math.round(b.width)} h=${Math.round(b.height)}`);
    if (process.env.TABLE_BAR_SHOTS) {
      fs.mkdirSync(process.env.TABLE_BAR_SHOTS, { recursive: true });
      for (const size of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }]) {
        await page.setViewportSize(size);
        for (const [index, view] of [BUSY[0], BUSY[1], BUSY[2], BUSY[4], CASES[0].view].entries()) {
          await show(view); await page.waitForTimeout(250);
          await page.screenshot({ path: path.join(process.env.TABLE_BAR_SHOTS, `${size.width}-${index}-${view.kind}${view.leaving ? '-leaving' : ''}.png`) });
        }
      }
    }

    // Standing up: everything gone, the gameplay HUD back.
    await show({ active: false });
    await page.locator('.table-layer').waitFor({ state: 'detached' });
    assert.equal(await gameplayHidden(), false, 'gameplay HUD restored after leaving');
    assert.equal(await page.evaluate(() => document.documentElement.hasAttribute('data-table-bar')), false);
    await clear();
    await page.mouse.click(300, 300); await page.keyboard.press('Backspace'); await page.keyboard.press('Escape'); await page.keyboard.press('e');
    assert.deepEqual(await page.evaluate(() => testBridge.sent.filter(e => e.name.startsWith('lightrp:boardGames:'))), [], 'nothing sent once standing');
    assert.deepEqual(errors, []);
    console.log(`board games browser: ${CASES.length} table kinds (actions, chip, camera, pointer, wheel, leave), empty Lua lists, countdown, warning, layout at 1280x720 and 1920x1080 passed; Free (overlay with crosshair, cursor key, HUD kept), placement bar (buttons, drag, keys, cancel), key forwarding and Escape passed`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
