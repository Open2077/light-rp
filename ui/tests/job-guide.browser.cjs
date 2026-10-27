const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

// The job guide (a guided modal after a hire, and from F1 → My job) and the
// F1 work menu: start / GPS / abandon a run, item work GPS, every guide picture.
const DEMOS = ['courier-route', 'courier-dispatch', 'courier-hud', 'courier-pickup', 'courier-dropoff', 'courier-pay', 'run-cancel',
  'run-desk', 'rooftop-lift', 'rooftop-clean', 'run-report', 'work-cycle', 'work-collect', 'work-trunk', 'work-process', 'work-sell', 'paycheck'];

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map(); window.sent = [];
      window.Open77 = {
        on: (e, f) => { if (!handlers.has(e)) handlers.set(e, new Set()); handlers.get(e).add(f); },
        off: (e, f) => handlers.get(e)?.delete(f), emit: (e, p) => window.sent.push([e, p]), ready() {},
      };
      window.fire = (e, p) => handlers.get(`lightrp:ui:${e}`)?.forEach(f => f(p));
    });
    await page.goto(process.env.TEST_URL || 'http://127.0.0.1:5197/');
    await page.waitForFunction(() => window.sent.some(([e]) => e === 'lightrp:ui:ready'));
    const fixture = await page.evaluate(async () => (await import('/src/dev/jobFixture.ts')).jobFixture());
    const fire = (e, p) => page.evaluate(([e, p]) => window.fire(e, p), [e, p]);
    const actions = () => page.evaluate(() => window.sent.filter(([e]) => e === 'lightrp:ui:action').map(([, p]) => p));
    const shot = async (name) => { if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/${name}.png` }); };
    const character = await page.evaluate(async () => ({ ...(await import('/src/state/store.ts')).EMPTY_STATE.character, status: 'active', registered: true, accountName: 'Test', firstName: 'Test', lastName: 'Worker' }));
    const unemployed = { name: 'unemployed', label: 'Unemployed', tag: 'CIVILIAN', grade: 0, gradeLabel: 'Citizen', salary: 0, paycheckMinutes: 30 };
    const guide = [
      { title: 'Welcome, Courier', body: 'Restaurants hand you orders; you bring them to apartments.', demo: 'courier-route', tips: ['One run at a time.'] },
      { title: 'Get a run', body: 'F1 → My job → Start a run.', demo: 'courier-dispatch', tips: {} },
      { title: 'If plans change', body: 'Abandon from F1.', demo: 'run-cancel' },
    ];
    const courier = { name: 'delivery', label: 'Courier', tag: 'FOOD & PARCEL DELIVERY', grade: 0, gradeLabel: 'Runner', salary: 45, paycheckMinutes: 30,
      art: { image: 'img/jobs/delivery.webp', icon: 'package' }, guide,
      run: { label: 'Delivery run', reward: 80, stops: 6, estimate: 'Random route', description: '', variable: true, orders: { min: 2, max: 3 }, remote: true } };
    await fire('state', { character, job: unemployed, jobRun: { active: false } });

    // 1. Hired at the desk: the guide waits for the desk to close, then opens on page 1.
    await fire('dialog', fixture);
    await page.locator('.job-card').first().waitFor();
    await page.getByRole('button', { name: 'Explore Courier', exact: true }).click();
    await page.getByRole('button', { name: 'Choose Courier', exact: true }).click();
    await page.getByRole('button', { name: 'Confirm job', exact: true }).click();
    await fire('state', { job: courier });
    await fire('result', { ok: true, action: 'jobs.apply', text: 'Hired: Courier, Runner.' });
    await page.waitForSelector('.jobcenter__confirm', { state: 'detached' });
    assert.equal(await page.locator('.job-guide').count(), 0, 'the guide waits for the desk to close');
    await page.keyboard.press('Escape');
    await page.waitForSelector('.jobcenter', { state: 'detached' });
    await page.locator('.job-guide').waitFor();
    assert.equal(await page.locator('#job-guide-title').innerText(), 'Welcome, Courier');
    assert.equal(await page.locator('.job-guide__steps li').count(), 3);
    const focus = await page.evaluate(() => window.sent.filter(([e]) => e === 'lightrp:ui:focus').map(([, p]) => p.active));
    assert.equal(focus.at(-1), true, 'the guide owns the focus');
    await page.waitForTimeout(1200); await shot('guide-1');

    // 2. Pages: arrows and buttons; the last one offers the first run (remote dispatch).
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('#job-guide-title').innerText(), 'Get a run');
    assert.equal(await page.locator('.job-guide__tips li').count(), 0, 'a Lua empty table is no tip');
    await page.getByRole('button', { name: 'Next', exact: true }).click();
    assert.equal(await page.locator('#job-guide-title').innerText(), 'If plans change');
    await page.getByRole('button', { name: /Back/ }).click(); await page.getByRole('button', { name: 'Next', exact: true }).click();
    await shot('guide-last');
    await page.getByRole('button', { name: 'Start my first run', exact: true }).click();
    assert.deepEqual((await actions()).at(-1), { type: 'jobs.start', from: 'menu' });
    await page.waitForSelector('.job-guide', { state: 'detached' });
    assert.equal(await page.evaluate(() => window.sent.filter(([e]) => e === 'lightrp:ui:focus').at(-1)[1].active), false);

    // 3. F1 → My job: the guide again, then start a run from anywhere.
    const menu = async (...path) => {
      await fire('open', {}); await page.locator('.player-menu').waitFor();
      for (const text of path) {
        for (let i = 0; i < 30; i++) {
          if ((await page.locator('.o77-rage__row--on .o77-rage__text').textContent()) === text) break;
          await page.keyboard.press('ArrowDown');
        }
        assert.equal(await page.locator('.o77-rage__row--on .o77-rage__text').textContent(), text);
        await page.keyboard.press('Enter');
      }
    };
    const rows = () => page.locator('.o77-rage__row .o77-rage__text').allTextContents();
    await menu('My job');
    assert.deepEqual(await rows(), ['Job guide', 'Start a run', 'Paycheck']);
    await page.keyboard.press('ArrowDown'); await page.waitForTimeout(150); await shot('menu-job');
    await page.keyboard.press('ArrowUp');
    await page.keyboard.press('Enter');
    await page.locator('.job-guide').waitFor();
    assert.equal(await page.locator('#job-guide-title').innerText(), 'Welcome, Courier', 'reopened at page 1');
    await page.keyboard.press('Escape'); await page.waitForSelector('.job-guide', { state: 'detached' });
    await fire('closed', {});
    await menu('My job', 'Start a run');
    assert.deepEqual((await actions()).at(-1), { type: 'jobs.start', from: 'menu' });
    await fire('closed', {});

    // 4. A run in progress: status, GPS, abandon behind a confirmation.
    await fire('state', { jobRun: { active: true, id: 'r', job: 'delivery', label: 'Delivery run', reward: 342, index: 2, total: 6, icon: 'package', orders: 3, carried: 1, distanceKm: 2.4,
      hint: 'Collect the order at the marker (E).', objective: { label: 'Pick up · Burger stand', kind: 'pickup', position: { x: 0, y: 0, z: 0 }, radius: 2.6 } } });
    await menu('My job');
    assert.deepEqual(await rows(), ['Job guide', 'Pick up · Burger stand', 'GPS to my next stop', 'Abandon this run', 'Paycheck']);
    await page.keyboard.press('ArrowDown'); await page.waitForTimeout(150); await shot('menu-run');
    await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter');
    assert.deepEqual((await actions()).at(-1), { type: 'jobs.gps' });
    await fire('closed', {});
    await menu('My job', 'Abandon this run');
    assert.deepEqual(await rows(), ['Yes, abandon this run', 'No, keep going']);
    const before = (await actions()).length;
    await page.keyboard.press('ArrowDown'); await page.keyboard.press('Enter');
    assert.equal((await actions()).length, before, 'keep going sends nothing');
    assert.equal(await page.locator('.o77-rage__row--on .o77-rage__text').textContent(), 'Abandon this run', 'back on the row');
    await page.keyboard.press('Enter'); await page.keyboard.press('Enter');
    assert.deepEqual((await actions()).at(-1), { type: 'jobs.cancel' });
    await fire('state', { jobRun: { active: false } });
    await page.keyboard.press('Escape'); await fire('closed', {});

    // 5. Free item work: the GPS of each stage; unemployed: where to find a job.
    const sanitation = { name: 'sanitation', label: 'Sanitation', tag: 'CITY SERVICES', grade: 0, gradeLabel: 'Trainee', salary: 40, paycheckMinutes: 30,
      art: { image: 'img/jobs/sanitation.webp', icon: 'trash-2' }, guide: [{ title: 'Welcome to Sanitation', body: 'Collect, sort, sell.', demo: 'work-cycle' }],
      work: { raw: 'Trash Bag', product: 'Recyclables', rawItem: 'trashbag', productItem: 'recyclables', collectCount: 1, collectWeight: 4, inputCount: 1, outputCount: 1, price: 18 } };
    await fire('state', { job: sanitation });
    for (const [row, stage] of [['Collection point GPS', 'collect'], ['Processing GPS', 'process'], ['Buyer GPS', 'sell']]) {
      await menu('My job', row);
      assert.deepEqual((await actions()).at(-1), { type: 'jobs.locate', job: 'sanitation', stage });
      await fire('closed', {});
    }
    await fire('state', { job: unemployed });
    await menu('My job');
    assert.deepEqual(await rows(), ['Find a job']);
    await page.keyboard.press('Escape'); await page.keyboard.press('Escape'); await fire('closed', {});

    // 6. Every picture renders (and a guide queued for a job no longer held is dropped).
    await page.evaluate(async () => (await import('/src/state/store.ts')).useStore.getState().openJobGuide('delivery'));
    assert.equal(await page.locator('.job-guide').count(), 0, 'not the current job: dropped');
    for (const [i, demo] of DEMOS.entries()) {
      const holder = demo.startsWith('work') ? sanitation : demo === 'paycheck' ? sanitation : courier;
      await fire('state', { job: { ...holder, guide: [{ title: demo, body: 'Picture check.', demo }] } });
      await page.evaluate(async (name) => (await import('/src/state/store.ts')).useStore.getState().openJobGuide(name), holder.name);
      await page.locator('.job-guide .gd').waitFor();
      await page.waitForTimeout(i === 0 ? 2500 : 1700);
      await shot(`demo-${demo}`);
      await page.keyboard.press('Escape'); await page.waitForSelector('.job-guide', { state: 'detached' });
    }
    for (const [width, height] of [[1280, 720], [800, 900]]) {
      await page.setViewportSize({ width, height });
      await fire('state', { job: courier });
      await page.evaluate(async () => (await import('/src/state/store.ts')).useStore.getState().openJobGuide('delivery'));
      await page.locator('.job-guide').waitFor(); await page.waitForTimeout(600);
      const box = await page.getByRole('button', { name: 'Next', exact: true }).boundingBox();
      assert(box && box.x + box.width <= width && box.y + box.height <= height, `Next reachable at ${width}x${height}`);
      await shot(`guide-${width}`);
      await page.keyboard.press('Escape');
    }
    assert.deepEqual(errors, []);
    console.log('PASS: guide after a hire once the desk closes, pages/keys/focus, first run from the guide, F1 My job (guide, start anywhere, GPS, abandon with confirmation, item work GPS, unemployed), every guide picture, small screens');
  } finally { await browser.close(); }
})().catch((error) => { console.error(error); process.exit(1); });
