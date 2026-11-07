/* Run against `npx vite --host 127.0.0.1 --port 5177` with Playwright installed, or set
   PLAYWRIGHT_MODULE to an existing installation. Never connects to a game/server: the public
   bridge is simulated so each outgoing action and server reply is observable.
   Since the 2026-10-27 redesign: a click selects, the hover card shows the details, the actions
   live in the right-click menu, Shift + click transfers and a plain drag moves. */
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const water = { slot: 2, name: 'water', label: 'Bottle of Water', count: 6, weight: .5, icon: 'droplet', usable: true, stack: 10, description: 'Still water.', category: 'Drink' };
water.useAction = { label: 'Drinking', durationMs: 6500, icon: 'droplet' };
const soda = { slot: 9, name: 'soda', label: 'Nicola Soda', count: 1, weight: .4, icon: 'cup-soda', usable: true, stack: 10, category: 'Drink' };
const left = { id: 'player:test', kind: 'player', label: 'UI Test', slots: 30, maxWeight: 40, weight: 3.7, items: [{ slot: 1, name: 'phone', label: 'Phone', count: 1, weight: .3, icon: 'smartphone', usable: false, stack: 1 }, water, soda] };
const right = { id: 'trunk:test', kind: 'trunk', label: 'Archer Hella', slots: 20, maxWeight: 80, weight: 1, items: [{ ...water, slot: 1, count: 2 }] };
const dialog = { kind: 'inventory', left, right };
const hud = { ready: true, health: { value: 78, max: 100 }, stamina: { value: 90, max: 100 }, armor: 40, vehicle: { active: false }, voice: { state: 'idle', level: 0, range: 'normal' }, clock: '12:00' };

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (name, payload) => (handlers.get(`lightrp:ui:${name}`) || []).forEach(fn => fn(payload)) };
      window.Open77 = {
        on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]),
        emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name.endsWith(':ready')) window.testBridge.ready = true; },
        ready() {},
      };
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5177');
    await page.waitForFunction(() => window.testBridge?.ready);
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
    // the paperdoll asks for a clothing refresh 600 ms after opening: only the item actions are checked here
    const actions = () => page.evaluate(() => window.testBridge.sent.filter(x => x.name === 'lightrp:ui:action' && x.payload.type.startsWith('inventory.')).map(x => x.payload));
    const clear = () => page.evaluate(() => { window.testBridge.sent = []; });
    const open = async (payload = dialog) => {
      await fire('dialog', payload);
      await page.locator('.inventory').waitFor();
      await page.waitForFunction(() => getComputedStyle(document.querySelector('.inventory')).opacity === '1');
      await clear();
    };
    const slot = (inventory, n) => page.locator(`[data-inv="${inventory}"][data-slot="${n}"]`);
    const menu = page.getByRole('menu');
    const item = name => page.getByRole('menuitem', { name: new RegExp(name) });
    const actionsOf = async (inventory, n) => { await slot(inventory, n).click({ button: 'right' }); await menu.waitFor(); };
    const ack = () => fire('inventory', { inventories: [left, right] });
    await fire('state', { character: { registered: true, status: 'active', step: 'done', key: 'test', accountName: 'UITest', playerId: 1, slots: [], origins: [], welcomePending: false }, needs: { food: 64, drink: 38 } });
    await fire('hud', hud);
    await open();

    await slot(left.id, 2).click();
    assert.equal((await actions()).length, 0, 'a click must select, not move');
    assert.equal(await slot(left.id, 2).getAttribute('aria-pressed'), 'true');
    await slot(left.id, 2).hover();
    const card = page.getByRole('tooltip');
    await card.waitFor();
    assert.match(await card.innerText(), new RegExp(water.label));
    assert.match(await card.innerText(), /Drink\s*· 6\.5s/i);

    await actionsOf(left.id, 2);
    await item('Use one').click();
    assert.deepEqual(await actions(), [{ type: 'inventory.use', slot: 2 }]);
    assert.equal(await slot(left.id, 2).isDisabled(), true, 'one request at a time');
    assert.match(await slot(left.id, 2).innerText(), /×6/, 'no optimistic mutations');
    await fire('result', { ok: false, text: 'Too far away.', action: 'inventory.use' });
    await page.locator('.inv-keys__status.is-error', { hasText: 'Too far away.' }).waitFor();
    assert.match(await slot(left.id, 2).innerText(), /×6/);
    await ack(); await clear();

    await actionsOf(left.id, 2);
    await page.getByRole('textbox', { name: 'Quantity', exact: true }).fill('0');
    assert.equal(await item('Move to storage').isDisabled(), true);
    await page.getByRole('textbox', { name: 'Quantity', exact: true }).fill('3');
    await item('Move to storage').click();
    assert.deepEqual(await actions(), [{ type: 'inventory.move', from: { inventory: left.id, slot: 2 }, to: { inventory: right.id, slot: 1 }, count: 3 }]);
    await ack(); await clear();

    await actionsOf(left.id, 2);
    await page.getByRole('button', { name: 'All', exact: true }).click();
    await item('Split stack').click();
    assert.deepEqual(await actions(), [{ type: 'inventory.move', from: { inventory: left.id, slot: 2 }, to: { inventory: left.id, slot: 3 }, count: 3 }]);
    await ack(); await clear();

    await actionsOf(left.id, 2);
    await item('Drop on ground').click();
    assert.equal((await actions()).length, 0, 'drop must be confirmed');
    await page.getByRole('alert').filter({ hasText: 'Drop on the ground?' }).waitFor();
    await page.keyboard.press('Escape');
    assert.equal(await menu.count(), 0, 'Escape dismisses the confirmation first');
    assert.equal(await page.locator('.inventory').count(), 1);
    await actionsOf(left.id, 2);
    await item('Give to nearby player').click();
    await page.getByRole('button', { name: 'Confirm', exact: true }).click();
    assert.deepEqual(await actions(), [{ type: 'inventory.give', slot: 2, count: 6 }]);
    await ack(); await clear();

    await actionsOf(left.id, 2);
    await page.keyboard.press('Escape');
    assert.equal(await menu.count(), 0);
    assert.equal(await page.locator('.inventory').count(), 1);

    await page.getByRole('textbox', { name: 'Search items' }).fill('soda');
    assert.equal(await page.locator('.inv-panel--pockets .inv-grid .inv-tile').count(), 1);
    assert.equal(await page.locator('.inv-panel--pockets .inv-grid .inv-tile').getAttribute('data-slot'), '9');
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.inventory').count(), 0, 'Escape closes from a text field');
    const focusEvents = await page.evaluate(() => window.testBridge.sent.filter(x => x.name.endsWith(':focus')));
    assert.equal(focusEvents.at(-1).payload.active, false);
    await open();

    const drag = async (beforeUp) => {
      const a = await slot(left.id, 2).boundingBox(), b = await slot(right.id, 4).boundingBox();
      await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
      await page.mouse.down();
      await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 12 });
      await page.locator('.inv-ghost').waitFor();
      if (beforeUp) await beforeUp();
      await page.mouse.up();
    };
    await drag();
    assert.deepEqual(await actions(), [{ type: 'inventory.move', from: { inventory: left.id, slot: 2 }, to: { inventory: right.id, slot: 4 }, count: 6 }]);
    await ack(); await clear();
    await drag(ack);
    assert.equal((await actions()).length, 0, 'a server update cancels stale drags');
    await drag(() => page.evaluate(() => window.dispatchEvent(new Event('blur'))));
    assert.equal((await actions()).length, 0, 'losing focus cancels drags');
    await slot(right.id, 1).click({ modifiers: ['Shift'] });
    assert.deepEqual(await actions(), [{ type: 'inventory.move', from: { inventory: right.id, slot: 1 }, to: { inventory: left.id, slot: 2 }, count: 2 }], 'Shift + click sends the stack across');
    await ack(); await clear();

    await actionsOf(left.id, 2);
    await item('Use one').click();
    await page.evaluate(() => document.activeElement.blur());
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.inventory').count(), 0, 'Escape works while the request is pending');

    await open({ ...dialog, right: { ...right, items: {} } });
    assert.equal(await page.locator('.inv-keys__status.is-error').count(), 0, 'old errors do not survive reopening');
    assert.equal(await page.locator('.inv-panel--side .is-filled').count(), 0, 'Lua empty tables normalize');
    await slot(left.id, 2).click();
    await page.getByRole('textbox', { name: 'Search items' }).focus();
    await page.keyboard.press('i');
    assert.equal(await page.locator('.inventory').count(), 1, 'I types in a search field');
    assert.equal(await page.getByRole('textbox', { name: 'Search items' }).inputValue(), 'i');
    await page.getByRole('textbox', { name: 'Search items' }).fill('');
    await slot(left.id, 2).click();
    await page.keyboard.down('i');
    assert.equal(await page.locator('.inventory').count(), 1, 'wait for key release before restoring gameplay input');
    await page.keyboard.up('i');
    assert.equal(await page.locator('.inventory').count(), 0, 'a second I closes inventory');
    assert.equal((await actions()).filter(a => a.type === 'inventory.close').length, 1);
    await page.keyboard.down('i');
    await open({ ...dialog, toggleKey: 'K' });
    await page.keyboard.up('i');
    assert.equal(await page.locator('.inventory').count(), 1, 'opening key release must not close the new dialog');
    await page.keyboard.press('i');
    assert.equal(await page.locator('.inventory').count(), 1, 'a rebound inventory ignores the old shortcut');
    await page.keyboard.press('k');
    assert.equal(await page.locator('.inventory').count(), 0, 'the actual rebound key closes inventory');
    await open();
    await page.evaluate(() => {
      document.activeElement.dispatchEvent(new KeyboardEvent('keydown', { key: 'i', code: '', bubbles: true }));
      document.activeElement.dispatchEvent(new KeyboardEvent('keyup', { key: 'i', code: '', bubbles: true }));
    });
    assert.equal(await page.locator('.inventory').count(), 0, 'embedded Chromium may omit the physical key code');
    await open();
    await page.evaluate(() => {
      document.activeElement.dispatchEvent(new KeyboardEvent('keydown', { key: 'Unidentified', code: 'KeyI', bubbles: true }));
      document.activeElement.dispatchEvent(new KeyboardEvent('keyup', { key: 'Unidentified', code: 'KeyI', bubbles: true }));
    });
    assert.equal(await page.locator('.inventory').count(), 0, 'embedded Chromium may omit the logical key on raw key events');
    await open();
    await slot(left.id, 2).click();
    for (const [width, height] of [[1280, 720], [1920, 1080], [2560, 1440], [3440, 1440]]) {
      await page.setViewportSize({ width, height });
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `no viewport overflow at ${width}`);
      const footer = await page.locator('.inv-keys').boundingBox();
      assert.ok(footer.y + footer.height <= height + 1, `footer remains on screen at ${width}`);
      await actionsOf(left.id, 2);
      const box = await menu.boundingBox();
      assert.ok(box.x >= 0 && box.y >= 0 && box.x + box.width <= width + 1 && box.y + box.height <= height + 1, `selected item actions fit at ${width}`);
      await page.keyboard.press('Escape');
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    if (process.env.SCREENSHOT_DIR) {
      await page.waitForTimeout(350);
      await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/inventory-browser.png` });
    }
    await page.getByRole('button', { name: 'Close inventory' }).click();
    await fire('hud', { ...hud, health: { value: 20, max: 100 } });
    await fire('state', { needs: { food: 10, drink: 15 } });
    assert.equal(await page.locator('.player-vital--low').count(), 3);
    assert.match(await page.locator('.player-vitals__warning').innerText(), /Low health.*Hungry.*Thirsty/);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    assert.equal(await page.locator('.player-vital__fill').first().evaluate(el => getComputedStyle(el).transitionDuration), '0s');
    await fire('hud', hud); await fire('state', { needs: { food: 64, drink: 38 } });
    if (process.env.SCREENSHOT_DIR) {
      await page.waitForTimeout(350);
      await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/hud-browser.png` });
    }
    assert.deepEqual(errors, []);
    console.log('PASS inventory actions, quantities, confirmations, keyboard/focus, drag cancellation, Shift transfer, Lua snapshots, 4 resolutions, HUD warnings and reduced motion.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
