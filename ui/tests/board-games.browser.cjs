const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const dist = path.resolve(process.env.BOARD_GAMES_WEB_DIR || path.resolve(__dirname, '../../resources/gamemodes/op77_lightrp/web'));
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    await page.route('http://boards.test/**', route => {
      const rel = new URL(route.request().url()).pathname.slice(1) || 'index.html';
      const file = path.resolve(dist, rel);
      if (!file.startsWith(dist + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404 });
      return route.fulfill({ body: fs.readFileSync(file), contentType: { '.js': 'application/javascript', '.css': 'text/css', '.html': 'text/html' }[path.extname(file)] || 'application/octet-stream' });
    });
    await page.addInitScript(() => {
      const handlers = {};
      window.testBridge = { sent: [], fire: (name, payload) => (handlers[name] || []).forEach(fn => fn(payload)) };
      window.Open77 = { on: (name, fn) => (handlers[name] ??= []).push(fn), emit: (name, payload) => testBridge.sent.push({ name, payload }), ready() {} };
    });
    await page.goto('http://boards.test/');
    await page.waitForFunction(() => testBridge.sent.some(e => e.name.endsWith(':ready')));
    const show = view => page.evaluate(view => testBridge.fire('lightrp:boardGames:view', view), view);
    assert.equal(await page.locator('.board-games').count(), 0);
    await show({ active: true, placing: true, kind: 'checkers', axis: 'xy' });
    await page.getByText('Board placement', { exact: true }).waitFor();
    await page.mouse.move(640, 360); await page.mouse.down(); await page.mouse.move(700, 400); await page.mouse.up();
    const pointers = await page.evaluate(() => testBridge.sent.filter(e => e.name === 'lightrp:boardGames:pointer').map(e => e.payload));
    assert(pointers.some(p => p.pressed && Math.abs(p.x - .5) < .001 && Math.abs(p.y - .5) < .001));
    assert(pointers.some(p => p.released));
    assert(pointers.every(p => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1));
    await show({ active: true, kind: 'chess', side: 'black', turn: 'white', status: 'playing' });
    await page.getByText('White to move', { exact: true }).waitFor();
    await page.getByText('You play Black.', { exact: true }).waitFor();
    assert(await page.locator('.gameplay-interface').isHidden(), 'HUD and interaction must be hidden during a game');
    await page.getByRole('button', { name: 'Black side', exact: true }).click();
    assert(await page.evaluate(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:camera' && e.payload.view === 'black')));
    await show({active:true,kind:'chess',cameraView:'orbit',side:'black',turn:'white',status:'playing'});
    await page.mouse.move(800,300);await page.mouse.down({button:'right'});await page.mouse.move(850,320);await page.mouse.up({button:'right'});
    assert(await page.evaluate(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:pointer' && e.payload.rightPressed)));
    await page.mouse.wheel(0,100);
    await page.waitForFunction(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:camera' && e.payload.zoom===1));
    await show({ active: true, kind: 'chess', status: 'won', winner: 'black' });
    await page.getByText('Black wins', { exact: true }).waitFor();
    await show({ active: true, kind: 'connect4', mode: 'teams', owned: true, ply: 0, canConfigure: true, ready: false, status: 'playing', playerCount: 3, side: 'white' });
    await page.getByRole('heading', { name: 'Connect Four' }).waitFor();
    await page.getByText('Waiting for players', { exact: true }).waitFor();
    await page.getByText('2v2 teams · 3/4 players', { exact: true }).waitFor();
    const before = await page.evaluate(() => testBridge.sent.filter(e => e.name === 'lightrp:boardGames:pointer' && !e.payload.blocked).length);
    await page.getByRole('button', { name: 'Solo vs AI', exact: true }).click();
    assert(await page.evaluate(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:mode' && e.payload.mode === 'solo')));
    assert.equal(await page.evaluate(() => testBridge.sent.filter(e => e.name === 'lightrp:boardGames:pointer' && !e.payload.blocked).length), before, 'mode controls must not move a piece');
    await show({ active: true, kind: 'connect4', mode: 'solo', owned: true, ply: 1, ready: true, actor: 0, status: 'playing', turn: 'black', side: 'white' });
    await page.getByText('AI is thinking…', { exact: true }).waitFor();
    await page.getByText('Yellow to move', { exact: true }).waitFor();
    assert.equal(await page.getByRole('group', { name: 'Game mode' }).count(), 0);
    await page.getByRole('button', { name: 'New game', exact: true }).click();
    assert(await page.evaluate(() => testBridge.sent.some(e => e.name === 'lightrp:boardGames:reset')));
    await show({active:true,kind:'roulette',owned:true,ready:true,status:'playing',extra:{phase:'betting',round:1,yourStake:0}});
    await page.getByRole('heading',{name:'Roulette'}).waitFor();
    await page.getByRole('button',{name:'Spin wheel',exact:true}).click();
    assert(await page.evaluate(()=>testBridge.sent.some(e=>e.name==='lightrp:tabletop:action'&&e.payload.operation==='spin')));
    await show({active:true,kind:'roulette',ready:true,status:'playing',extra:{phase:'spinning'}});
    await page.getByText('Wheel spinning… bets are closed.',{exact:true}).waitFor();
    assert.equal(await page.getByRole('button',{name:'Place bet',exact:true}).count(),0);
    // Fresh casino tables as Lua sends them: empty lists arrive as {} objects.
    await show({active:true,kind:'blackjack',ready:true,status:'playing',extra:{"shoe": {"cut": false, "left": 312, "total": 312}, "round": 1, "dealer": {"cards": {}, "total": 0}, "mode": "duel", "ply": 0, "hands": {}, "kind": "blackjack", "captured": {}, "status": "playing", "phase": "betting", "shuffledAt": 1793648509672, "objects": {}, "clientNow": 1793648600000, "mySeat": "white", "legal": {}}});
    await page.getByRole('heading',{name:'Blackjack'}).waitFor();
    await page.getByRole('button',{name:'Place bet',exact:true}).waitFor();
    await show({active:true,kind:'slots',ready:true,status:'playing',extra:{kind:'slots',round:1,phase:'idle',result:{symbols:{}},stops:{}}});
    await page.getByRole('heading',{name:'Slot Machine'}).waitFor();
    await show({active:true,kind:'fortune',ready:true,status:'playing',extra:{kind:'fortune',round:1,phase:'betting',recent:{},bets:{},totals:{},mine:{}}});
    await page.getByRole('heading',{name:'Fortune Wheel'}).waitFor();
    assert.deepEqual(errors, [], 'casino panels must render fresh tables');
    // Every view the real Lua client sent during tools/test-casino-e2e.py
    // (E2E_VIEWS_OUT), JSON round-tripped: the panel must survive each stage.
    if (process.env.CASINO_E2E_VIEWS) {
      const recorded = JSON.parse(fs.readFileSync(process.env.CASINO_E2E_VIEWS, 'utf8'));
      let count = 0;
      for (const [game, views] of Object.entries(recorded)) {
        for (const view of views) {
          await show(view);
          if (view.active && !view.placing) assert.equal(await page.locator('.board-games').count(), 1, `${game}: overlay hidden by ${JSON.stringify(view).slice(0, 300)}`);
          assert.deepEqual(errors, [], `${game}: page error on ${JSON.stringify(view).slice(0, 300)}`);
          count++;
        }
      }
      console.log(`board games browser: replayed ${count} recorded casino views`);
    }
    // Leaving from the keyboard: Escape anywhere, Backspace outside a text field.
    const leaves = () => page.evaluate(() => testBridge.sent.filter(e => e.name === 'lightrp:boardGames:leave').length);
    await show({ active: true, kind: 'chess', side: 'white', turn: 'white', status: 'playing' });
    let leftBefore = await leaves(); await page.keyboard.press('Escape'); assert.equal(await leaves(), leftBefore + 1, "Escape leaves the table");
    await show({active:true,kind:'blackjack',ready:true,status:'playing',extra:{kind:'blackjack',phase:'betting',round:1,hands:{},dealer:{cards:{}},mySeat:'white',legal:{},clientNow:1}});
    await page.getByLabel("Bet amount").focus(); leftBefore = await leaves(); await page.keyboard.press('Backspace');
    assert.equal(await leaves(), leftBefore, "Backspace in the bet field edits the amount");
    await page.locator('h2').click(); await page.keyboard.press('Backspace'); assert.equal(await leaves(), leftBefore + 1, "Backspace outside a field leaves");
    await show({ active: false });
    await page.locator('.board-games').waitFor({ state: 'detached' });
    assert.equal(await page.locator('.board-games').count(), 0);
    await page.waitForFunction(() => !document.querySelector('.gameplay-interface').hidden);
    assert.equal(await page.locator('.gameplay-interface').getAttribute('hidden'), null, 'gameplay HUD must restore after leaving');
    assert.deepEqual(errors, []);
    console.log('board games browser: placement, pointers, modes, teams, AI, Connect Four, reset and cleanup passed');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
