// The action bar's input relay (src/features/actions/Actions.tsx). The bar is drawn and judged on
// NativeUI (client/native/actions.lua): the page renders nothing, acknowledges the start and forwards
// the running action's raw keys on lightrp:ui:activity:input. It never decides a result itself.
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
    const inputs = (id) => page.evaluate(id => window.testBridge.sent.filter(x => x.name === 'lightrp:ui:activity:input' && (!id || x.payload.id === id)).map(x => x.payload), id);
    const kinds = async (id) => (await inputs(id)).map(p => p.key ? `${p.kind}:${p.key}` : p.kind);
    const open = async (options = {}) => { const d = { ...base, ...options, id: `a${++seq}` }; await fire('activity:start', d);
      await page.waitForFunction(id => window.testBridge.sent.some(x => x.name.endsWith('activity:started') && x.payload.id === id), d.id); return d; };
    const finish = (d) => fire('activity:finish', { id: d.id, status: 'cancelled', reason: 'cancelled', elapsedMs: 0, hits: 0, mistakes: 0, score: 0 });
    const settle = () => page.waitForTimeout(30);

    // start: acknowledged, then "ready"; nothing drawn
    let d = await open();
    assert.deepEqual(await kinds(d.id), ['ready']);
    assert.equal(await page.locator('.activity, [data-kind]').count(), 0, 'the bar is native: the page draws nothing');
    // a progress action listens to Escape only
    await page.keyboard.press('e'); await page.keyboard.press('Escape'); await settle();
    assert.deepEqual(await kinds(d.id), ['ready', 'escape']);
    await finish(d);

    // hold: down / up of its key, repeats dropped, other keys ignored
    d = await open({ kind: 'hold', style: 'ring' });
    await page.keyboard.down('e');
    await page.evaluate(() => document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'e', code: 'KeyE', repeat: true, bubbles: true })));
    await page.keyboard.press('q'); await page.keyboard.up('e'); await settle();
    assert.deepEqual(await kinds(d.id), ['ready', 'down:E', 'up:E']);
    // Escape is consumed even when repeated, relayed once
    await page.evaluate(() => { document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
      document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', repeat: true, bubbles: true })); });
    await settle(); assert.deepEqual((await kinds(d.id)).slice(-1), ['escape']); assert.equal((await kinds(d.id)).filter(k => k === 'escape').length, 1);
    // the page lost the focus
    await page.evaluate(() => window.dispatchEvent(new Event('blur'))); await settle();
    assert.deepEqual((await kinds(d.id)).slice(-1), ['blur']);
    await finish(d);

    // timing: every step's key, raw CEF key events (no logical key) included
    d = await open({ kind: 'timing', steps: [{ ...base.steps[0], key: 'E' }, { ...base.steps[0], key: 'R' }] });
    await page.evaluate(() => { document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Unidentified', code: 'KeyE', bubbles: true }));
      document.body.dispatchEvent(new KeyboardEvent('keyup', { key: 'Unidentified', code: 'KeyE', bubbles: true })); });
    await page.keyboard.press('r'); await settle();
    assert.deepEqual(await kinds(d.id), ['ready', 'down:E', 'up:E', 'down:R', 'up:R']);
    await finish(d);

    // a SPACE action
    d = await open({ kind: 'hold', key: 'SPACE' });
    await page.keyboard.press('Space'); await settle();
    assert.deepEqual(await kinds(d.id), ['ready', 'down:SPACE', 'up:SPACE']);

    // a stale finish changes nothing; the action's own finish stops the relay
    await fire('activity:finish', { id: 'stale', status: 'cancelled', reason: 'interrupted' });
    await page.keyboard.press('Space'); await settle();
    assert.equal((await kinds(d.id)).length, 5);
    await finish(d);
    await page.keyboard.press('Space'); await page.keyboard.press('Escape'); await settle();
    assert.equal((await kinds(d.id)).length, 5, 'nothing relayed once the action finished');

    // the page never decides an outcome
    assert.equal(await page.evaluate(() => window.testBridge.sent.filter(x => x.name.endsWith('activity:result')).length), 0);
    // invalid starts are ignored
    await fire('activity:start', { id: 'bad', kind: 'other' }); await settle();
    assert.equal((await inputs('bad')).length, 0);
    assert.deepEqual(errors, []);
    console.log('PASS action relay: start ack + ready, no DOM, progress/hold/timing keys, repeats, raw CEF keys, SPACE, Escape, blur, stale and own finish, never a result.');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
