const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const bank = require('../src/features/rental/vehicle-images.json');
const stock = [
  { key: 'maimai', label: 'Makigai MaiMai', category: 'Street', price: 60 },
  { key: 'hella', label: 'Archer Hella', category: 'Street', price: 120 },
  { key: 'cortes', label: 'Villefort Cortes', category: 'Street', price: 140 },
  { key: 'semimaru', label: 'Yaiba Semimaru', category: 'Sport', price: 90 },
  { key: 'supron', label: 'Mahir Supron', category: 'Utility', price: 180 },
];
const dialog = { kind: 'rental', spot: { id: 'citycenter', name: 'Rent-a-Ride // City Center', durationMinutes: 30, stock } };
const money = { currency: '€$', cash: 70, bank: { balance: 1500, number: 'TEST' }, history: [] };
const active = { key: 'hella', label: 'Archer Hella', spotId: 'citycenter', spotName: dialog.spot.name, price: 120, paidWith: 'bank', remainingMs: 1050000 };
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
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
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5177');
    await page.waitForFunction(() => window.testBridge?.ready);
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
    const actions = () => page.evaluate(() => window.testBridge.sent.filter(x => x.name === 'lightrp:ui:action').map(x => x.payload));
    const clear = () => page.evaluate(() => { window.testBridge.sent = []; });
    const open = async (payload = dialog) => { await fire('dialog', payload); await page.locator('.rental').waitFor(); await page.waitForFunction(() => getComputedStyle(document.querySelector('.rental')).opacity === '1'); await clear(); };
    const close = async () => { await page.getByRole('button', { name: 'Close rental', exact: true }).click(); await page.waitForSelector('.rental', { state: 'detached' }); };
    await fire('state', { character: { registered: true, status: 'active', step: 'done', key: 'test', accountName: 'UITest', playerId: 1, slots: [], origins: [], welcomePending: false }, money, rental: {} });
    await open();
    await page.waitForFunction(() => [...document.querySelectorAll('.rental-card img')].every(img => img.complete && img.naturalWidth > 0));
    assert.equal(await page.locator('.rental-card').count(), 5);
    await page.getByRole('button', { name: 'Select Archer Hella', exact: true }).click();
    assert.equal((await actions()).length, 0, 'select does not charge');
    assert.equal(await page.locator('.rental-summary h2').innerText(), 'Archer Hella');
    assert(await page.getByRole('button', { name: 'Confirm rental', exact: true }).isDisabled());
    assert.match(await page.locator('.rental-short').innerText(), /50/);
    await page.getByRole('radio', { name: /Bank account/ }).check();
    assert(!(await page.getByRole('button', { name: 'Confirm rental', exact: true }).isDisabled()));
    // Stale success and unrelated replies must not close a newly submitted reservation.
    await fire('result', { action: 'rental.rent', ok: true, text: 'Old success' });
    await page.getByRole('button', { name: 'Confirm rental', exact: true }).click();
    await page.locator('.rental__primary').evaluate(button => { button.click(); button.click(); });
    assert.deepEqual(await actions(), [{ type: 'rental.rent', spot: 'citycenter', key: 'hella', pay: 'bank' }]);
    await fire('result', { action: 'inventory.use', ok: true, text: 'Other action' });
    assert.equal(await page.locator('.rental').count(), 1);
    await fire('result', { action: 'rental.rent', ok: false, text: 'Walk up to the desk.' });
    await page.getByRole('alert').filter({ hasText: 'Walk up to the desk.' }).first().waitFor();
    assert(!(await page.getByRole('button', { name: 'Confirm rental', exact: true }).isDisabled()));
    await page.getByRole('button', { name: 'Confirm rental', exact: true }).click();
    await fire('state', { rental: { active } });
    await fire('result', { action: 'rental.rent', ok: true, text: 'Vehicle delivered.' });
    await page.waitForSelector('.rental', { state: 'detached' });
    assert((await page.evaluate(() => window.testBridge.sent)).some(x => x.name.endsWith(':focus') && x.payload.active === false));
    await open();
    assert.equal(await page.getByRole('button', { name: 'Confirm rental', exact: true }).count(), 0);
    await page.getByRole('button', { name: 'Return vehicle', exact: true }).click();
    assert.equal((await actions()).length, 0, 'return requires confirmation');
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.rental-confirm').count(), 0);
    await page.getByRole('button', { name: 'Return vehicle', exact: true }).click();
    await page.getByRole('button', { name: 'Confirm return', exact: true }).click();
    assert.deepEqual(await actions(), [{ type: 'rental.return' }]);
    await fire('state', { rental: {} });
    await fire('result', { action: 'rental.return', ok: true, text: 'Returned.' });
    await page.getByRole('button', { name: 'Confirm rental', exact: true }).waitFor();
    await page.getByRole('textbox', { name: 'Search vehicles' }).fill('  CORTES ');
    assert.equal(await page.locator('.rental-card').count(), 1);
    await page.getByRole('button', { name: 'Clear search', exact: true }).click();
    await page.locator('.rental__filters button').filter({ hasText: 'Sport' }).click();
    assert.equal(await page.locator('.rental-card').count(), 1);
    assert.match(await page.locator('.rental-card').innerText(), /Semimaru/);
    await page.getByRole('textbox', { name: 'Search vehicles' }).fill('not-a-car');
    assert.equal(await page.getByRole('button', { name: 'Confirm rental', exact: true }).count(), 0);
    await page.getByRole('button', { name: 'Clear filters', exact: true }).click();
    await page.getByRole('combobox', { name: 'Sort vehicles' }).selectOption('price-desc');
    assert.match(await page.locator('.rental-card').first().innerText(), /Supron/);
    await fire('state', { money: { ...money, bank: undefined } });
    assert(await page.getByRole('radio', { name: /Bank account/ }).isDisabled());
    await fire('state', { money });
    // Every image ships both in source and the built resource, and decodes offline.
    assert.equal(Object.keys(bank.vehicles).length, 18);
    for (const asset of Object.values(bank.vehicles)) {
      for (const base of ['../public/img/vehicles', '../../resources/gamemodes/op77_lightrp/web/img/vehicles']) assert(fs.existsSync(path.join(__dirname, base, asset.file)));
      assert(await page.evaluate(src => new Promise(resolve => { const image = new Image(); image.onload = () => resolve(image.naturalWidth >= 800); image.onerror = () => resolve(false); image.src = src; }), `img/vehicles/${asset.file}`), asset.file);
    }
    for (const viewport of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }, { width: 2560, height: 1080 }, { width: 800, height: 600 }]) {
      await page.setViewportSize(viewport);
      assert(await page.locator('.rental__workspace').evaluate(el => { const r = el.getBoundingClientRect(); return r.top >= 0 && r.left >= 0 && r.bottom <= innerHeight + 1 && r.right <= innerWidth + 1; }), 'workspace fits');
      assert(await page.locator('.rental__layout').evaluate(el => el.scrollWidth <= el.clientWidth + 1), 'no horizontal overflow');
      await page.locator('.rental-summary').evaluate(el => { el.scrollTop = 0; });
      assert(await page.getByRole('button', { name: 'Confirm rental', exact: true }).evaluate(button => {
        const r = button.getBoundingClientRect(), panel = button.closest('.rental-summary').getBoundingClientRect();
        const top = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        return r.top >= panel.top && r.bottom <= panel.bottom + 1 && (top === button || button.contains(top));
      }), 'booking is fully visible and clickable without scrolling');
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.getByRole('combobox', { name: 'Sort vehicles' }).selectOption('price-asc');
    await page.getByRole('button', { name: 'Select Yaiba Semimaru', exact: true }).click();
    await page.getByRole('radio', { name: /Bank account/ }).check();
    await page.locator('.rental-summary').evaluate(el => { el.scrollTop = 0; });
    await page.waitForFunction(() => getComputedStyle(document.querySelector('.rental-summary__photo')).opacity === '1');
    if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'rental-catalogue.png') });
    await close();
    await open({ ...dialog, spot: { ...dialog.spot, stock: {} } });
    assert.equal(await page.locator('.rental-card').count(), 0, 'Lua empty table is handled');
    assert.match(await page.locator('.rental-catalogue').innerText(), /lot is empty/);
    await close();
    await page.route('**/img/vehicles/maimai.jpg', route => route.abort());
    await open();
    await page.locator('.rental-summary__photo .rental-art-fallback').waitFor();
    await page.evaluate(() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Unidentified', code: 'Escape', bubbles: true })));
    await page.waitForSelector('.rental', { state: 'detached' });
    assert.deepEqual(errors, []);
    console.log('PASS: catalogue/search/sort; authoritative booking/return; balances; stale replies; 18 local photos; 4 viewports; empty/fallback; CEF Escape/focus');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
