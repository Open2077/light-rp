const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (n, p) => (handlers.get(`lightrp:ui:${n}`) || []).forEach(fn => fn(p)) };
      window.Open77 = { on: (n, fn) => handlers.set(n, [...(handlers.get(n) || []), fn]), ready() {},
        emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name.endsWith(':ready')) window.testBridge.ready = true; } };
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5177');
    await page.waitForFunction(() => window.testBridge.ready);
    const item = { slot: 1, name: 'cash', label: 'Eurodollars', count: 1000000000, weight: 0, icon: 'banknote', usable: false,
      stack: 1000000000, category: 'currency', image: 'img/items/cash.png', description: 'Physical cash. One unit is worth €$1. Split, give or store it like any other item. Only the cash in your pockets can be spent.' };
    const left = { id: 'player:test', kind: 'player', label: 'Pockets', slots: 30, maxWeight: 40, weight: 0, items: [item] };
    const right = { id: 'stash:test', kind: 'stash', label: 'Storage', slots: 20, maxWeight: 50, weight: 0, items: [] };
    await page.evaluate(({ left, right }) => {
      window.testBridge.fire('state', { character: { registered: true, status: 'active', step: 'done', key: 'test', accountName: 'UITest', playerId: 1, slots: [], origins: [], welcomePending: false } });
      window.testBridge.fire('dialog', { kind: 'inventory', left, right });
    }, { left, right });
    const cashSlot = page.locator('[data-inv="player:test"][data-slot="1"]');
    await cashSlot.click();
    await page.waitForFunction(() => [...document.querySelectorAll('.inventory img')].every(img => img.complete && img.naturalWidth > 0));
    assert.match(await cashSlot.innerText(), /€\$ 1B/);
    assert.match(await page.locator('.inventory-detail').innerText(), /Weightless/);
    assert.match(await page.locator('.inventory-detail').innerText(), /1,000,000,000/);
    assert.equal(await page.getByRole('button', { name: 'Use one', exact: true }).count(), 0);
    const quantity = page.getByRole('textbox', { name: 'Quantity', exact: true });
    await quantity.fill('1000000000'); assert.equal(await quantity.inputValue(), '1000000000');
    await page.getByRole('button', { name: 'Move to storage', exact: true }).click();
    const actions = await page.evaluate(() => window.testBridge.sent.filter(x => x.name.endsWith(':action')).map(x => x.payload));
    assert.deepEqual(actions.at(-1), { type: 'inventory.move', from: { inventory: left.id, slot: 1 }, to: { inventory: right.id, slot: 1 }, count: 1000000000 });
    await page.evaluate(({ left, right }) => window.testBridge.fire('inventory', { inventories: [left, right] }), { left, right });
    for (const [width, height] of [[1280, 720], [1920, 1080], [2560, 1440]]) {
      await page.setViewportSize({ width, height });
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      const size = await page.locator('.inventory-detail').evaluate(el => ({ client: el.clientHeight, scroll: el.scrollHeight }));
      assert.ok(size.scroll <= size.client + 1, `cash actions fit at ${width}`);
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/cash-inventory-browser.png` });
    assert.deepEqual(errors, []);
    console.log('PASS cash UI: image, weightless display, compact/exact amounts, 10-digit quantity, transfer payload, 3 resolutions, no JS errors');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
