// First day presentation in the page: the demos beside the dialogue and the typed lines.
// The step-complete banner, the flight to the next stop and the objective card with its
// examples are NativeUI (client/native/tutorial.lua): the page stays empty for them.
// SHOT=<prefix> saves screenshots.
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => { errors.push(e.message); console.log('PAGEERROR', e.stack); });
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (name, payload) => (handlers.get('lightrp:ui:' + name) || []).forEach(fn => fn(payload)) };
      window.Open77 = { on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]), emit: (name, payload) => {
        window.testBridge.sent.push({ name, payload }); if (name.endsWith(':ready')) window.testBridge.ready = true;
      }, ready() {} };
      addEventListener('DOMContentLoaded', () => { document.documentElement.style.background = '#2b3530'; });
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5199');
    await page.waitForFunction(() => window.testBridge.ready);
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.testBridge.fire(name, payload), { name, payload });
    const shot = async name => { if (process.env.SHOT) await page.screenshot({ path: `${process.env.SHOT}-${name}.png` }); };
    const character = { registered: true, status: 'active', step: 'done', key: 'default', playerId: 1, accountName: 'Test', firstName: 'Alex', lastName: 'Morgan', origins: [], slots: [], appearanceRevision: 2, welcomePending: false };
    const money = { currency: '€$', cash: 200, bank: { number: 'NC-1042-7781', balance: 1245 }, history: [] };
    const map = [
      { step: 'intro', label: 'Arrival Hall', x: 0, y: -101, state: 'done' }, { step: 'meet', label: 'Mara, your guide', x: 0, y: -14, state: 'done' },
      { step: 'shop', label: 'Market stall', x: 24, y: -4, state: 'done' }, { step: 'bank', label: 'Night City Bank', x: 0, y: 27.3, state: 'now' },
      { step: 'garage', label: 'Garage · Rent-a-Ride', x: -33, y: 0, state: 'next' }, { step: 'station', label: 'Fuel station', x: -26, y: -78, state: 'next' },
      { step: 'collect', label: 'Job fair', x: 22, y: -63.6, state: 'next' }, { step: 'sell', label: 'Juno, the buyer', x: 30, y: -78, state: 'next' },
    ];
    let revision = 1;
    const state = (step, extra = {}) => fire('state', { character, money, tutorial: { active: true, available: true, key: 'default', step, revision: revision++, index: 5, total: 10, title: 'Your money', hint: 'Walk to the bank.', contact: 'Idris', role: 'NIGHT CITY BANK', guide: 'Mara', where: 'lobby', map, ...extra } });
    await fire('tutorial', { phase: 'idle', keys: { menu: 'F1', inventory: 'I', interact: 'E', lock: 'L', skip: 'SPACE', way: 'G' } });

    // Demos beside the dialogue, one per line.
    const demos = ['rules', 'tour', 'card', 'money', 'transfer', 'rental', 'keys', 'vehicle', 'gauge', 'pump', 'jerrycan', 'work', 'payday'];
    await state('bank', { dialogue: 'bank', lines: demos.map(demo => ({ text: `A line about ${demo}, written at reading pace for the newcomer.`, demo })) });
    await page.locator('.first-day__conversation').waitFor();
    const line = page.locator('.first-day__line');
    assert.ok((await page.locator('.first-day__unsaid').innerText()).length > 0, 'the line is written out, not shown at once');
    assert.match(await line.innerText(), /A line about rules/, 'the whole line is laid out from the start');
    for (const [i, demo] of demos.entries()) {
      // Space while the line is written: the line whole, not the next one.
      await page.keyboard.press(' ');
      assert.equal(await page.locator('.first-day__unsaid').innerText(), '', `${demo}: space shows the line whole`);
      assert.match(await line.innerText(), new RegExp(`about ${demo},`), `${demo}: and stays on it`);
      const panel = page.locator('.first-day__showcase');
      await panel.waitFor();
      await page.waitForTimeout(demo === 'gauge' ? 2600 : 1500);
      const box = await panel.boundingBox(), talk = await page.locator('.first-day__conversation').boundingBox();
      assert(box.y + box.height <= talk.y + 1, `${demo}: the example sits above the dialogue`);
      assert(box.x + box.width <= 1920 && box.y >= 0, `${demo}: inside the screen`);
      if (['rules', 'tour', 'card', 'keys', 'gauge', 'pump', 'work'].includes(demo)) await shot(`line-${demo}`);
      // Space on a whole line: the next one.
      await page.keyboard.press(' ');
      if (i < demos.length - 1) await line.filter({ hasText: `about ${demos[i + 1]},` }).waitFor();
    }
    await page.waitForFunction(() => window.testBridge.sent.some(x => x.payload?.operation === 'next'));

    // The step is done: the banner, the flight to the next stop and the card are NativeUI, not the page.
    await state('garage', { title: 'Wheels', index: 6, place: 'Garage · Rent-a-Ride', direction: 'West of the square', objective: { position: { x: 0, y: 0, z: 0 }, label: 'Talk to the mechanic', radius: 2.7, kind: 'talk' },
      todo: [{ text: 'Follow the arrow to the garage' }, { key: 'interact', text: 'Talk to Rook' }], map: map.map(s => ({ ...s, state: s.step === 'garage' ? 'now' : s.step === 'bank' ? 'done' : s.state })) });
    await fire('tutorial', { phase: 'reveal', reveal: { name: 'Garage · Rent-a-Ride', direction: 'West of the square', distance: 46, index: 6, total: 10, durationMs: 5600 } });
    await page.waitForTimeout(300);
    assert.equal(await page.locator('.first-day').count(), 0, 'no banner, flight or card in the page');
    await fire('tutorial', { phase: 'idle', reveal: false });
    for (const demo of ['menu', 'inventory', 'shop', 'drink', 'collect', 'process', 'sell', 'context']) {
      await state(demo === 'menu' ? 'identity' : demo, { title: demo, demo, objective: undefined, todo: [{ key: 'menu', text: 'Open the player menu' }, { text: 'Select Identity' }] });
      assert.equal(await page.locator('.first-day').count(), 0, `${demo}: the card's example is not in the page`);
    }
    assert.deepEqual(errors, [], errors.join(' | '));
    console.log('PASS: thirteen dialogue examples above the dialogue, typed lines (space completes, then reads on); step banner, flight and card examples left to NativeUI (page empty)');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
