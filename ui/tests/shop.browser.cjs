const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const items = [
  ['water', 'Bottle of Water', 'drink', .5, 8, 2, 5, 30],
  ['burrito', 'Burrito', 'food', .4, 18, 5, 5, 35],
  ['noodles', 'Street Ramen', 'food', .5, 24, 6, 0, 40],
  ['dumplings', 'Dumpling Box', 'food', .35, 20, 5, 0, 30],
  ['soda', 'NiCola', 'drink', .4, 10, 2, 0, 20],
  ['coffee', 'Coffee', 'drink', .3, 12, 3, 0, 15],
  ['apple', 'Apple', 'food', .2, 10, 3, 0, 12],
  ['pizza', 'Synth-Pepperoni Slice', 'food', .3, 16, 4, 0, 28],
  ['proteinbar', 'Protein Bar', 'food', .15, 14, 3, 0, 20],
].map(([name, label, category, weight, buy, sell, owned, effect]) => ({ name, label, category, weight, buy, sell, owned, stack: 10,
  icon: 'package', image: `img/items/${name}.png`, description: 'Everyday essentials for life in Night City. Packed and ready to go.', effects: { [category === 'drink' ? 'drink' : 'food']: effect } }));
const initial = { kind: 'shop', session: 'test:1', revision: 1, nextRequest: 1,
  shop: { id: 'citycenter_food', name: 'Corner Market / City Center', label: 'Night City Market', subtitle: 'Good food. Cold drinks. Back to the city.', template: 'street_food' },
  items, payments: ['cash', 'bank'], maxLines: 12, maxPerItem: 20, money: { currency: '€$', cash: 20, bank: 1500 },
  inventory: { id: 'bag', kind: 'player', label: 'Bag', slots: 24, maxWeight: 25, weight: 4.5, items: [
    { name: 'water', count: 5, slot: 1, stack: 10, weight: .5 }, { name: 'burrito', count: 5, slot: 2, stack: 10, weight: .4 },
  ] },
};
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    if (process.env.UI_DIST) await page.route('http://shop.test/**', route => {
      const root = path.resolve(process.env.UI_DIST);
      const file = path.resolve(root, '.' + (new URL(route.request().url()).pathname === '/' ? '/index.html' : new URL(route.request().url()).pathname));
      if (!file.startsWith(root + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404, body: 'Not found' });
      const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2' }[path.extname(file)] || 'application/octet-stream';
      return route.fulfill({ contentType: mime, body: fs.readFileSync(file) });
    });
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (name, payload) => (handlers.get(`lightrp:ui:${name}`) || []).forEach(fn => fn(payload)) };
      window.Open77 = { on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]),
        emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name.endsWith(':ready')) window.testBridge.ready = true; }, ready() {} };
    });
    await page.goto(process.env.UI_DIST ? 'http://shop.test/' : process.env.UI_URL || 'http://127.0.0.1:5177');
    await page.waitForFunction(() => window.testBridge.ready);
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
    const actions = () => page.evaluate(() => window.testBridge.sent.filter(e => e.name === 'lightrp:ui:action').map(e => e.payload));
    await fire('state', { character: { status: 'active', registered: true, step: 'done', key: 'default', accountName: 'Test', playerId: 1, welcomePending: false, slots: [], origins: [] } });
    await fire('dialog', initial); await page.locator('.shop').waitFor();
    await page.waitForFunction(() => [...document.querySelectorAll('.shop-card img')].every(img => img.complete && img.naturalWidth));
    assert.equal(await page.locator('.shop-card').count(), 9);
    await page.getByRole('button', { name: 'Add Bottle of Water', exact: true }).click();
    await page.getByRole('button', { name: 'Add Burrito', exact: true }).click();
    assert.equal((await actions()).length, 0, 'adding to basket does not trade');
    assert(await page.getByRole('button', { name: 'Confirm purchase', exact: true }).isDisabled(), 'cash too low');
    await page.getByRole('radio', { name: /Bank/ }).check();
    assert(!(await page.getByRole('button', { name: 'Confirm purchase', exact: true }).isDisabled()));
    if (process.env.SCREENSHOT_DIR) {
      await page.locator('.shop-grid').evaluate(el => el.scrollTop = 0);
      await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'shop-desktop.png'), animations: 'disabled' });
    }
    await page.getByRole('button', { name: 'Confirm purchase', exact: true }).click();
    await page.locator('.shop__primary').evaluate(el => { el.click(); el.click(); });
    assert.deepEqual(await actions(), [{ type: 'shop.checkout', session: 'test:1', request: 1, revision: 1, mode: 'buy', pay: 'bank', lines: [{ name: 'water', count: 1 }, { name: 'burrito', count: 1 }] }]);
    await fire('shop', { session: 'wrong', request: 1, ok: true, state: initial });
    assert(await page.locator('.shop__primary').isDisabled(), 'another session cannot finish pending request');
    await fire('shop', { session: 'test:1', request: 1, ok: false, text: 'The database did not confirm.', state: { ...initial, nextRequest: 2 } });
    assert.equal(await page.locator('.shop-line').count(), 2, 'failure preserves basket');
    await page.getByRole('button', { name: 'Confirm purchase', exact: true }).click();
    assert.equal((await actions())[1].request, 2);
    await fire('shop', { session: 'test:1', request: 1, ok: true, state: initial });
    assert(await page.locator('.shop__primary').isDisabled(), 'old reply cannot settle new request');
    await fire('shop', { session: 'test:1', request: 2, ok: true, text: 'Purchase complete.', state: { ...initial, nextRequest: 3, money: { ...initial.money, bank: 1474 } } });
    await page.waitForFunction(() => !document.querySelector('.shop-line'));
    await page.getByRole('button', { name: 'Sell items', exact: true }).click();
    assert.equal(await page.locator('.shop-card').count(), 2, 'sell starts with owned items');
    await page.getByRole('button', { name: 'Add Bottle of Water', exact: true }).click();
    await page.getByRole('spinbutton', { name: 'Quantity Bottle of Water' }).fill('999');
    assert.equal(await page.getByRole('spinbutton', { name: 'Quantity Bottle of Water' }).inputValue(), '5');
    await page.getByRole('button', { name: 'Confirm sale', exact: true }).click();
    assert.equal((await actions()).at(-1).mode, 'sell');
    await fire('shop', { session: 'test:1', request: 3, ok: true, text: 'Sale complete.', state: { ...initial, nextRequest: 4, items: items.map(i => ({ ...i, owned: 0 })) } });
    await page.getByRole('heading', { name: 'Nothing to sell here yet' }).waitFor();
    await page.getByRole('button', { name: 'Show what this shop buys' }).click();
    assert.equal(await page.locator('.shop-card').count(), 9);
    assert(await page.getByRole('button', { name: 'Add Bottle of Water' }).isDisabled());
    await page.getByRole('button', { name: 'Buy items', exact: true }).click();
    await page.getByRole('button', { name: 'Drinks', exact: true }).click();
    assert.equal(await page.locator('.shop-card').count(), 3);
    await page.getByRole('textbox', { name: 'Search shop' }).fill('COFFEE');
    assert.equal(await page.locator('.shop-card').count(), 1);
    await page.getByRole('button', { name: 'Add Coffee' }).click();
    await fire('shop', { session: 'test:1', catalogueChanged: true, text: 'Catalogue updated.', state: { ...initial, nextRequest: 4, revision: 2 } });
    await page.waitForFunction(() => !document.querySelector('.shop-line'));
    assert.equal(await page.locator('.shop-line').count(), 0, 'live catalogue change clears old price basket');
    await page.getByRole('textbox', { name: 'Search shop' }).fill('does-not-exist');
    await page.getByRole('heading', { name: 'Nothing on this shelf' }).waitFor();
    await page.getByRole('button', { name: 'Clear filters' }).click();
    await page.getByRole('button', { name: 'Add Bottle of Water' }).click();
    await page.getByRole('button', { name: 'Add Burrito' }).click();
    // Desktop and compact game resolutions: both shelves and checkout stay usable.
    await fire('shop', { session: 'test:1', refresh: true, state: { ...initial, nextRequest: 4, revision: 2, money: { ...initial.money, cash: 100 } } });
    await page.waitForFunction(() => document.querySelector('.shop__bar').textContent.includes('100'));
    assert.equal(await page.locator('.shop-line').count(), 2, 'live balance refresh preserves basket');
    for (const [width, height] of [[1280, 720], [1024, 600], [1920, 1080]]) {
      await page.setViewportSize({ width, height });
      const overflow = await page.locator('.shop__workspace').evaluate(el => el.scrollWidth > el.clientWidth + 2);
      assert(!overflow, `horizontal overflow at ${width}x${height}`);
      assert(await page.locator('.shop-card').evaluateAll(cards => cards.every(el => el.scrollHeight <= el.clientHeight + 2)), 'cards must not shrink and clip their contents');
      await page.locator('.shop__primary').scrollIntoViewIfNeeded();
      const box = await page.locator('.shop__primary').boundingBox();
      assert(box.x >= 0 && box.x + box.width <= width && box.y >= 0 && box.y + box.height <= height);
      if (process.env.SCREENSHOT_DIR && width === 1280) await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'shop-720.png') });
    }
    await page.emulateMedia({ reducedMotion: 'reduce' });
    assert.equal(await page.locator('.shop').evaluate(el => getComputedStyle(el).animationName), 'none');
    await page.getByRole('button', { name: 'Close shop' }).focus();
    await page.keyboard.press('Shift+Tab');
    assert(await page.locator('.shop').evaluate(el => el.contains(document.activeElement)), 'focus stays inside shop');
    await page.keyboard.press('Escape');
    await page.waitForSelector('.shop', { state: 'detached' });
    assert((await actions()).at(-1).type === 'shop.close');
    await fire('shop', { session: 'test:1', request: 4, ok: true, state: initial });
    assert.equal(await page.locator('.shop').count(), 0, 'late response must not reopen a closed shop');
    await fire('dialog', { ...initial, session: 'test:2' });
    await fire('shop', { session: 'test:2', closed: true, text: 'You left the shop.' });
    await page.waitForSelector('.shop', { state: 'detached' });
    assert.deepEqual(errors, []);
    console.log('PASS: shop art, basket, cash/bank, buy/sell, quantity limits, search/categories, empty states, duplicate/stale replies, catalogue updates, closure/focus, responsive layout and reduced motion');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
