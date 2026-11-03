// The Hall of Fame's full ladders (HallOfFameDialog.tsx), rendered at 1920x1080.
// 1. The dev mock (features/halloffame/mock.ts): overview -> a card clicked -> the
//    loading state -> the ladder (podium, ranks 4-50 scrolling inside the dialog, the
//    viewer's rank 80 pinned) -> Esc back to the overview, the card focused again;
//    races -> Enter on a card -> an ascending ladder with the viewer inside -> Backspace.
// 2. A stubbed bridge: the actions sent (halloffame.board, its retry, REFRESH with the
//    key), a refusal, stale answers ignored, ← → leaving the ladder, Esc closing a tab.
// Run against the Vite dev server: UI_URL=http://127.0.0.1:5177 node tests/halloffame.browser.cjs
// (PLAYWRIGHT_MODULE: a playwright install; SCREENSHOT_DIR: where the PNGs go).
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.UI_URL || 'http://127.0.0.1:5177';
const shots = process.env.SCREENSHOT_DIR;

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    // ---------------------------------------------------------------- the mock
    {
      const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.goto(`${base}/?registered=1&dialog=halloffame&hofdelay=500`);
      const dialog = page.locator('.halloffame');
      await dialog.waitFor();
      await page.locator('.hof-board[data-board="pvp.wins"]').waitFor();
      await page.waitForFunction(() => getComputedStyle(document.querySelector('.halloffame')).opacity === '1');
      await page.waitForTimeout(400);
      const box = await dialog.boundingBox();
      if (shots) await page.screenshot({ path: `${shots}/hof-1-overview.png` });
      assert.equal(await page.locator('.hof-board.is-link').count(), 12, 'twelve clickable podiums');
      assert.match(await page.locator('.halloffame__keys').innerText(), /FULL LADDER/);
      await page.locator('.hof-board[data-board="pvp.kills"]').hover();
      await page.waitForTimeout(200);
      if (shots) await page.screenshot({ path: `${shots}/hof-1b-hover.png`, clip: { x: box.x, y: box.y + 130, width: box.width / 2, height: 260 } });

      // a card clicked: the ladder's header at once, the rows once they land
      await page.locator('.hof-board[data-board="pvp.wins"]').click();
      await page.locator('.hof-ladder').waitFor();
      assert.match(await page.locator('.hof-ladder').innerText(), /Loading the full ladder/);
      assert.match(await page.locator('.hof-ladder__head').innerText(), /MOST WINS/);
      assert.match(await page.locator('.halloffame__strip').innerText(), /UPDATED 3 MIN AGO/, 'the tab\'s age while the ladder loads');
      if (shots) await page.screenshot({ path: `${shots}/hof-2-ladder-loading.png` });
      await page.locator('.hof-ladder__scroll').waitFor();
      await page.waitForTimeout(150);
      if (shots) await page.screenshot({ path: `${shots}/hof-3-ladder-top.png` });
      assert.equal(await page.locator('.hof-ladder .hof-podium__step').count(), 3, 'the podium');
      const listed = page.locator('.hof-ladder__scroll .hof-list li');
      assert.equal(await listed.count(), 47, 'ranks 4 to 50');
      assert.match(await listed.last().innerText(), /#48/, 'a tie across the cut: rank 48 shared to the 50th row');
      assert.equal(await page.locator('.hof-ladder__scroll .hof-list li i').count() >= 6, true, 'tie markers');
      const pinned = page.locator('.hof-ladder__mine li');
      assert.equal(await pinned.count(), 1, 'the viewer outside the fifty: pinned');
      assert.match(await pinned.innerText(), /#80/);
      assert.match(await page.locator('.hof-ladder__head').innerText(), /120 RANKED/);
      assert.match(await page.locator('.halloffame__feedback').innerText(), /TOP 50 OF 120/);
      assert.match(await page.locator('.halloffame__keys').innerText(), /BACK/);
      // the list scrolls inside the dialog; neither the dialog nor the page grows
      const sizes = await page.evaluate(() => {
        const s = document.querySelector('.hof-ladder__scroll');
        return { scroll: s.scrollHeight, client: s.clientHeight, doc: document.documentElement.scrollHeight, focused: document.activeElement === s };
      });
      assert(sizes.scroll > sizes.client + 200, `the ladder scrolls: ${JSON.stringify(sizes)}`);
      assert(sizes.doc <= 1080, `the page does not grow: ${sizes.doc}`);
      assert(sizes.focused, 'the list takes the keyboard');
      assert.deepEqual(await dialog.boundingBox(), box, 'the dialog keeps its size');
      const pinnedBox = await pinned.boundingBox();
      assert(pinnedBox.y + pinnedBox.height <= box.y + box.height, 'the pinned row inside the dialog');
      await page.keyboard.press('End');
      await page.waitForTimeout(250);
      if (shots) await page.screenshot({ path: `${shots}/hof-4-ladder-bottom.png` });
      const bottom = await listed.last().boundingBox();
      const scrollBox = await page.locator('.hof-ladder__scroll').boundingBox();
      assert(bottom.y + bottom.height <= scrollBox.y + scrollBox.height + 1, 'the 50th row reachable');

      // Esc: back to the overview, the card focused again; the dialog stays open
      await page.keyboard.press('Escape');
      await page.locator('.halloffame__grid').waitFor();
      assert.equal(await page.locator('.hof-ladder').count(), 0);
      assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-board')), 'pvp.wins', 'the card it came from');
      if (shots) await page.screenshot({ path: `${shots}/hof-5-back.png` });

      // races: Enter on a card opens an ascending ladder, the viewer inside it
      await page.getByRole('tab', { name: 'RACES' }).click();
      const trial = page.locator('.hof-board[data-board="races.race.trial"]');
      await trial.waitFor();
      await trial.focus();
      await page.keyboard.press('Enter');
      await page.locator('.hof-ladder__scroll').waitFor();
      assert.match(await page.locator('.hof-ladder__head').innerText(), /LOWEST FIRST/);
      assert.equal(await page.locator('.hof-ladder__mine').count(), 0, 'inside the fifty: nothing pinned');
      const me = page.locator('.hof-ladder__scroll .hof-list li.is-you');
      assert.equal(await me.count(), 1);
      assert.match(await me.innerText(), /#14[\s\S]*Yuki Tanaka[\s\S]*YOU/);
      await me.scrollIntoViewIfNeeded();
      await page.waitForTimeout(150);
      if (shots) await page.screenshot({ path: `${shots}/hof-6-ladder-ascending.png` });
      await page.keyboard.press('Backspace');
      await page.locator('.halloffame__grid').waitFor();
      assert.equal(await page.locator('.o77-tab--on').innerText(), 'RACES', 'back to the tab it came from');
      // an empty board on the empty fixture is covered by the stub below; Esc on a tab closes
      await page.keyboard.press('Escape');
      await page.waitForSelector('.halloffame', { state: 'detached' });
      assert.deepEqual(errors, []);
      await page.close();
    }

    // ---------------------------------------------------------------- the protocol, stubbed bridge
    {
      const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      await page.addInitScript(() => {
        const handlers = new Map();
        window.testBridge = { sent: [], ready: false, fire: (name, payload) => (handlers.get(`lightrp:ui:${name}`) || []).forEach(fn => fn(payload)) };
        window.Open77 = {
          on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]),
          emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name.endsWith(':ready')) window.testBridge.ready = true; }, ready() {},
        };
      });
      await page.goto(base);
      await page.waitForFunction(() => window.testBridge?.ready);
      const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
      const actions = () => page.evaluate(() => window.testBridge.sent.filter(x => x.name === 'lightrp:ui:action').map(x => x.payload));
      const clear = () => page.evaluate(() => { window.testBridge.sent = []; });
      await fire('state', { character: { registered: true, status: 'active', step: 'done', key: 'default', firstName: 'Jax', lastName: 'Rook', accountName: 'UITest', playerId: 1, slots: [], origins: [], welcomePending: false } });
      const rows = (n, from = 1) => Array.from({ length: n }, (_, i) => ({ rank: from + i, name: `Runner ${from + i}`, value: 900 - i }));
      const card = (key, title, extra = {}) => ({ key, title, unit: 'wins', total: 30, rows: rows(3), ...extra });
      const header = { kind: 'halloffame', title: 'HALL OF FAME', hub: 'The Crossing', tabs: ['overview', 'pvp', 'races'], database: true, updatedAgoS: 5, refreshInS: 0 };
      await fire('dialog', { ...header, tab: 'overview', boards: [card('pvp.wins', 'MOST WINS'), card('pvp.kills', 'MOST KILLS'), card('ext.empty', 'EMPTY', { total: 0, rows: [] })] });
      await page.locator('.hof-board[data-board="pvp.wins"]').waitFor();
      await clear();

      // a click asks once, then once more without an answer
      await page.locator('.hof-board[data-board="pvp.wins"]').click();
      assert.deepEqual(await actions(), [{ type: 'halloffame.board', key: 'pvp.wins', tab: 'overview' }]);
      await page.waitForTimeout(1100);
      assert.equal((await actions()).filter(a => a.type === 'halloffame.board').length, 2, 'asked again once');
      // a refusal: said in place of the ladder; Backspace goes back
      await fire('result', { action: 'halloffame.board', ok: false, text: 'That board is not on the Hall of Fame.' });
      await page.locator('.hof-ladder').getByText('That board is not on the Hall of Fame.').waitFor();
      await page.keyboard.press('Backspace');
      await page.locator('.halloffame__grid').waitFor();

      // another card: a stale ladder (another key) is ignored, the right one shows
      await clear();
      await page.locator('.hof-board[data-board="pvp.kills"]').click();
      await fire('dialog', { ...header, tab: 'overview', boards: {}, ladder: card('pvp.wins', 'MOST WINS', { rows: rows(20) }) });
      assert.match(await page.locator('.hof-ladder').innerText(), /Loading the full ladder/, 'not the board asked for');
      await fire('dialog', { ...header, tab: 'overview', boards: {}, ladder: card('pvp.kills', 'MOST KILLS', { rows: rows(20), mine: { rank: 30, value: 4 } }) });
      await page.locator('.hof-ladder__scroll').waitFor();
      assert.match(await page.locator('.hof-ladder__mine').innerText(), /#30[\s\S]*Jax Rook[\s\S]*YOU/, 'the viewer pinned with their character name');
      // REFRESH on a ladder carries its key
      await clear();
      await page.getByRole('button', { name: 'REFRESH' }).click();
      assert.deepEqual(await actions(), [{ type: 'halloffame.refresh', tab: 'overview', key: 'pvp.kills' }]);
      await fire('dialog', { ...header, tab: 'overview', boards: {}, updatedAgoS: 0, refreshInS: 30, ladder: card('pvp.kills', 'MOST KILLS', { rows: rows(25) }) });
      await page.getByRole('button', { name: /REFRESH IN/ }).waitFor();
      assert.equal(await page.locator('.hof-ladder__scroll .hof-list li').count(), 22);
      // ← →: leave the ladder for the next tab (asked, the overview's boards being older)
      await clear();
      await page.keyboard.press('ArrowRight');
      await page.locator('.hof-ladder').waitFor({ state: 'detached' });
      assert.equal(await page.locator('.o77-tab--on').innerText(), 'PVP');
      assert.deepEqual((await actions()).filter(a => a.type === 'halloffame.tab')[0], { type: 'halloffame.tab', tab: 'pvp' });
      await fire('dialog', { ...header, tab: 'pvp', updatedAgoS: 0, boards: [card('pvp.wins', 'MOST WINS', { rows: rows(10) })] });
      await page.locator('.hof-board[data-board="pvp.wins"]').waitFor();
      // a tab click leaves a ladder too; an empty ladder says so
      await page.getByRole('tab', { name: 'OVERVIEW' }).click();
      await fire('dialog', { ...header, tab: 'overview', updatedAgoS: 0, boards: [card('ext.empty', 'EMPTY', { total: 0, rows: [] })] });
      await page.locator('.hof-board[data-board="ext.empty"]').click();
      await fire('dialog', { ...header, tab: 'overview', updatedAgoS: 0, boards: {}, ladder: { key: 'ext.empty', title: 'EMPTY', unit: 'count', total: 0, rows: {} } });
      await page.locator('.hof-ladder').getByText('Nobody on this board yet').waitFor();
      await page.getByRole('tab', { name: 'PVP' }).click();
      await page.locator('.hof-ladder').waitFor({ state: 'detached' });
      // right-click: back from a ladder, closes on a tab
      await page.locator('.hof-board[data-board="pvp.wins"]').click();
      await page.mouse.click(960, 540, { button: 'right' });
      await page.locator('.halloffame__grid').waitFor();
      assert.equal(await page.locator('.halloffame').count(), 1, 'still open');
      await page.keyboard.press('Escape');
      await page.waitForSelector('.halloffame', { state: 'detached' });
      assert.deepEqual(errors, []);
      await page.close();
    }
    console.log('halloffame.browser: ok');
  } finally {
    await browser.close();
  }
})().catch((e) => { console.error(e); process.exit(1); });
