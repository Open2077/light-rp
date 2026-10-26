const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const profiles = [
  ['armscrossed', 'Arms crossed', 'postures'], ['dance', 'Dance', 'dance'], ['drink', 'Drink', 'consumables'],
  ['handsup', 'Hands up', 'gestures'], ['sit', 'Sit down', 'seated'], ['repair', 'Repair', 'work'],
  ['wave', 'Wave', 'social'], ['phone', 'Phone', 'interactions'], ['lean', 'Lean', 'relaxation'],
  ['clap', 'Applaud', 'social'], ['think', 'Thinking', 'emotions'], ['guitar', 'Guitar', 'music'],
].map(([id, label, category]) => ({ id, label, category, clip: `${id}_01`, clips: [`${id}_01`, `${id}_02`, `${id}_03`], clipPrefix: `${id}_`, prop: id === 'drink' ? 'can' : '', placement: id === 'sit' ? 'chair' : 'standing' }));
const initial = { open: true, busy: false, loaded: true, loading: false, current: false, message: '', toggleKey: 'F3', stopKey: 'X' };
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  const output = path.resolve('artifacts/animations-browser'); fs.mkdirSync(output, { recursive: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (name, payload) => (handlers.get(`lightrp:ui:${name}`) || []).forEach(fn => fn(payload)) };
      window.Open77 = { on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]), ready() {},
        emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name === 'lightrp:ui:ready') window.testBridge.ready = true; } };
    });
    const load = async () => {
      await page.goto(process.env.UI_URL || 'http://127.0.0.1:5191');
      await page.waitForFunction(() => window.testBridge?.ready);
      await fire('state', { character: { status: 'active', step: 'done', registered: true, userId: 'test', key: 'test', accountName: 'Test', welcomePending: false } });
    };
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
    const actions = () => page.evaluate(() => window.testBridge.sent.filter(x => x.name === 'lightrp:ui:animations:action' && x.payload.action !== 'preferences').map(x => x.payload));
    const clear = () => page.evaluate(() => { window.testBridge.sent = []; });
    const catalog = async revision => {
      for (let batch = 1; batch <= 3; batch++) await fire('animations:catalog', { revision, total: 3, batch, profiles: profiles.slice((batch - 1) * 4, batch * 4) });
    };
    await load(); await fire('animations:state', initial);
    await fire('animations:catalog', { revision: 1, total: 3, batch: 1, profiles: profiles.slice(0, 4) });
    assert.equal(await page.locator('.rp-anim-card').count(), 0, 'partial catalog never renders');
    await catalog(1); await page.locator('.rp-anim-card').first().waitFor();
    assert.equal(await page.locator('.rp-anim-card').count(), 12);
    await fire('animations:catalog', { revision: 0, total: 1, batch: 1, profiles: [] });
    assert.equal(await page.locator('.rp-anim-card').count(), 12, 'stale catalog ignored');
    await page.getByLabel('Search animations').fill('danse');
    assert.equal(await page.locator('.rp-anim-card').count(), 3, 'search includes aliases + variants');
    await page.getByRole('button', { name: 'Select Dance 1', exact: true }).click();
    await page.getByLabel('Next variant', { exact: true }).click();
    assert.match(await page.locator('.rp-anim-variant').innerText(), /Variant 2 \/ 3/);
    await page.getByLabel('Favorite selected variant', { exact: true }).click();
    await page.getByRole('button', { name: 'Assign selected', exact: true }).click();
    await page.getByRole('button', { name: 'Assign slot 1', exact: true }).click();
    await page.getByLabel('Animation duration').selectOption('5000');
    await clear(); await page.getByRole('button', { name: 'Play animation', exact: true }).click();
    assert.deepEqual((await actions()).at(-1), { action: 'play', profile: 'dance', clip: 'dance_02', loop: false, durationMs: 5000 });
    await fire('animations:state', { ...initial, open: false, current: { active: true, playbackId: 'play:1', step: 0, steps: [{ profile: 'dance', clip: 'dance_02' }], remainingMs: 5000 } });
    await page.locator('.rp-anim-playing').waitFor(); assert.equal(await page.locator('.rp-animations').count(), 0);
    await load(); await catalog(1); await fire('animations:state', initial);
    await page.getByRole('button', { name: /^Favorites/ }).click(); assert.equal(await page.locator('.rp-anim-card').count(), 1);
    assert.match(await page.locator('.rp-anim-card').innerText(), /Dance/);
    await page.getByRole('button', { name: 'Recent', exact: true }).click(); assert.equal(await page.locator('.rp-anim-card').count(), 1, 'history records accepted playback');
    await clear(); await page.keyboard.press('1');
    assert.equal((await actions()).at(-1).clip, 'dance_02', 'quick access retains exact variant');
    await clear(); await page.evaluate(() => window.dispatchEvent(new KeyboardEvent('keydown', { key: '&', code: '', bubbles: true })));
    assert.equal((await actions()).at(-1).clip, 'dance_02', 'embedded Chromium without code supports AZERTY');
    await page.getByLabel('Search animations').fill(''); await page.getByLabel('Search animations').press('1');
    assert.equal((await actions()).length, 1, 'typing must never play a quick slot');
    await page.getByLabel('Search animations').fill(''); await page.getByRole('button', { name: 'Discover', exact: true }).click();
    await page.getByLabel('Animation category').selectOption('work'); assert.equal(await page.locator('.rp-anim-card').count(), 1);
    await page.getByLabel('Animation category').selectOption('all');
    await page.getByLabel('List view', { exact: true }).click(); assert.ok(await page.locator('.rp-anim-library.is-list').count());
    await page.getByLabel('Grid view', { exact: true }).click();
    await page.getByRole('button', { name: 'Select Drink 1', exact: true }).click();
    for (const [width, height] of [[1920, 1080], [1280, 720], [2560, 1440], [3440, 1440]]) {
      await page.setViewportSize({ width, height });
      await page.waitForTimeout(260);
      const rect = await page.locator('.rp-animations').boundingBox();
      assert.ok(rect.x > width * .5 && rect.y >= 0 && rect.y + rect.height <= height, `non-fullscreen in bounds at ${width}`);
      for (const selector of ['.rp-anim-library', '.rp-anim-detail', '.rp-anim-quick', '.rp-animations__footer']) {
        const box = await page.locator(selector).boundingBox();
        assert.ok(box.y + box.height <= rect.y + rect.height + 1, `${selector} must fit at ${width}x${height}`);
      }
      assert.ok(await page.locator('.rp-anim-library').evaluate(el => el.clientHeight >= 84));
      assert.ok((await page.locator('.rp-anim-card').first().boundingBox()).height >= 90, 'grid rows must scroll, never compress or clip their labels');
      await page.screenshot({ path: path.join(output, `${width}x${height}.png`), omitBackground: true });
    }
    await clear(); await page.getByLabel('Close animations', { exact: true }).click();
    assert.equal((await actions()).at(-1).action, 'close');
    await fire('animations:state', { ...initial, busy: true });
    await page.waitForFunction(() => document.querySelector('.rp-anim-play')?.disabled === true);
    assert.ok(await page.getByRole('button', { name: 'Play animation', exact: true }).isDisabled());
    await fire('animations:state', initial); await clear();
    await page.getByLabel('Search animations').focus(); await page.keyboard.press('Escape');
    assert.equal((await actions()).at(-1).action, 'close', 'Escape works in search');
    await clear(); await page.getByLabel('Search animations').blur(); await page.keyboard.down('F3');
    assert.equal((await actions()).length, 0, 'toggle waits for release');
    await page.keyboard.up('F3'); assert.equal((await actions()).at(-1).action, 'close');
    await fire('open', {});
    await page.locator('.rp-animations').waitFor({ state: 'hidden' });
    assert.equal(await page.locator('.rp-animations').count(), 0, 'other dialogs supersede animations');
    assert.deepEqual(errors, []);
    console.log('PASS: catalogue revisions, aliases, variants, favorites, persistent slots, authoritative recents, keyboard, focus arbitration, 4 responsive viewports');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
