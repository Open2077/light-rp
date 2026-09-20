const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = { id: 'test', kind: 'progress', label: 'Prepare the equipment', description: 'A test activity', icon: 'wrench', style: 'bar', durationMs: 800, timeoutMs: 10000,
  key: 'E', cancellable: true, release: 'reset', maxMistakes: 0, steps: [{ key: 'E', durationMs: 2000, zoneStart: .4, zoneWidth: .3 }] };
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const h = new Map(); window.testBridge = { sent: [], fire: (name, value) => (h.get(`lightrp:ui:${name}`) || []).forEach(fn => fn(value)) };
      window.Open77 = { ready() {}, on: (name, fn) => h.set(name, [...(h.get(name) || []), fn]), emit: (name, payload) => window.testBridge.sent.push({ name, payload }) };
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5177');
    await page.waitForFunction(() => window.testBridge.sent.some(x => x.name.endsWith(':ready')));
    const fire = (name, value) => page.evaluate(({name, value}) => window.testBridge.fire(name, value), {name, value});
    await fire('state', { character: { registered: true, status: 'active', welcomePending: false, slots: [], origins: [], accountName: 'UITest', key: 'test', step: 'done', playerId: 1 } });
    await fire('hud', { ready: true, health: { value: 100, max: 100 }, armor: 0, stamina: { value: 100, max: 100 }, vehicle: { active: false }, voice: { state: 'idle', range: 'normal', level: 0 }, clock: '12:00' });
    let seq = 0;
    const open = async (options = {}) => { const d = { ...base, ...options, id: `a${++seq}` }; await fire('activity:start', d); await page.locator('.activity').waitFor(); return d; };
    const results = () => page.evaluate(() => window.testBridge.sent.filter(x => x.name.endsWith('activity:result')).map(x => x.payload));
    let d = await open();
    await page.locator('.activity.is-success').waitFor();
    assert.equal((await results()).filter(r => r.id === d.id).length, 1);
    assert.equal((await results()).at(-1).reason, 'completed');
    await page.keyboard.press('Escape'); assert.equal((await results()).filter(r => r.id === d.id).length, 1);
    d = await open({ durationMs: 10000 }); await page.keyboard.press('Escape');
    await page.locator('.activity.is-cancelled').waitFor(); assert.equal((await results()).at(-1).id, d.id);
    d = await open({ kind: 'hold', style: 'ring' });
    await page.waitForFunction(() => document.querySelector('.activity')?.dataset.phase === 'running');
    await page.keyboard.down('e'); await page.waitForTimeout(300); await page.keyboard.up('e');
    await page.waitForFunction(() => document.querySelector('[role=progressbar]')?.getAttribute('aria-valuenow') === '0');
    await page.keyboard.down('e'); await page.locator('.activity.is-success').waitFor(); await page.keyboard.up('e');
    assert.equal((await results()).filter(r => r.id === d.id).length, 1);
    await open({ kind: 'hold', release: 'cancel' });
    await page.waitForFunction(() => document.querySelector('.activity')?.dataset.phase === 'running');
    await page.keyboard.press('e'); await page.locator('.activity.is-cancelled').waitFor();
    assert.equal((await results()).at(-1).reason, 'released');
    d = await open({ kind: 'timing' });
    await page.waitForFunction(() => parseFloat(document.querySelector('.activity__cursor').style.left) > 48);
    await page.evaluate(() => { document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Unidentified', code: 'KeyE', bubbles: true })); document.body.dispatchEvent(new KeyboardEvent('keyup', { key: 'Unidentified', code: 'KeyE', bubbles: true })); });
    await page.locator('.activity.is-success').waitFor(); assert.equal((await results()).at(-1).hits, 1);
    await open({ kind: 'timing' });
    await page.waitForFunction(() => document.querySelector('.activity')?.dataset.phase === 'running');
    await page.keyboard.press('e'); await page.locator('.activity.is-failed').waitFor(); assert.equal((await results()).at(-1).reason, 'too_early');
    await open({ kind: 'hold', cancellable: false }); await page.keyboard.press('Escape'); assert.equal(await page.locator('.activity.is-cancelled').count(), 0);
    await page.evaluate(() => window.dispatchEvent(new Event('blur'))); await page.locator('.activity.is-cancelled').waitFor(); assert.equal((await results()).at(-1).reason, 'focus_lost');
    d = await open({ durationMs: 10000 });
    await fire('activity:finish', { id: 'stale', status: 'cancelled', reason: 'interrupted' }); assert.equal(await page.locator('.activity.is-cancelled').count(), 0);
    await fire('activity:finish', { id: d.id, status: 'cancelled', reason: 'owner_stopped', elapsedMs: 0, hits: 0, mistakes: 0, score: 0 });
    await page.locator('.activity.is-cancelled').waitFor(); assert.equal((await results()).filter(r => r.id === d.id).length, 0, 'external cancellation does not echo a result');
    await open({ durationMs: 10000 }); await fire('open', {}); await page.locator('.activity.is-cancelled').waitFor(); assert.equal((await results()).at(-1).reason, 'interrupted'); await fire('closed', {});
    for (const [width, height] of [[1280,720],[1920,1080],[2560,1440],[3440,1440]]) {
      await page.setViewportSize({ width, height }); await open({ kind: 'timing', steps: [{ ...base.steps[0], durationMs: 9000 }], timeoutMs: 20000 });
      const box = await page.locator('.activity').boundingBox(); assert.ok(box.x >= 0 && box.y >= 0 && box.x + box.width <= width && box.y + box.height <= height);
      assert.equal(await page.locator('.activity').evaluate(e => e.scrollWidth > e.clientWidth), false);
    }
    assert.deepEqual(errors, []);
    const preview = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    await preview.goto((process.env.UI_URL || 'http://127.0.0.1:5177') + '/?registered=1&actions=1');
    await preview.getByRole('button', { name: /Timing check/ }).click();
    await preview.waitForFunction(() => getComputedStyle(document.querySelector('.activity')).opacity === '1');
    if (process.env.SCREENSHOT_DIR) await preview.screenshot({ path: `${process.env.SCREENSHOT_DIR}/actions-kit.png` });
    console.log('PASS progress, hold/reset/release, timing/raw CEF keys, cancel, blur, stale events, focus conflicts, exactly-once results and 4 viewports.');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
