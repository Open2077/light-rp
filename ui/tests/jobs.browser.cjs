const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
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
    const job = { name: 'unemployed', label: 'Unemployed', tag: 'CIVILIAN', grade: 0, gradeLabel: 'Citizen', salary: 0 };
    const character = await page.evaluate(async () => ({ ...(await import('/src/state/store.ts')).EMPTY_STATE.character, status: 'active', registered: true, accountName: 'Test', firstName: 'Test', lastName: 'Worker' }));
    await fire('state', { character, job });
    await fire('dialog', fixture);
    await page.locator('.job-card').first().waitFor(); await page.evaluate(() => document.fonts.ready); await page.waitForTimeout(900);
    assert.equal(await page.locator('.job-card').count(), 3);
    assert(await page.locator('img.job-card__art').evaluateAll(imgs => imgs.length === 3 && imgs.every(img => img.complete && img.naturalWidth > 0)));
    await page.getByRole('button', { name: 'Explore Scrapper', exact: true }).hover(); await page.waitForTimeout(700);
    assert.equal(await page.locator('.job-card.is-active').getAttribute('aria-label'), 'Explore Scrapper');
    assert.equal((await actions()).length, 0, 'hover must not hire');
    await page.getByRole('button', { name: 'Explore Scrapper', exact: true }).focus();
    await page.keyboard.press('ArrowRight');
    assert.equal(await page.locator('.job-card.is-active').getAttribute('aria-label'), 'Explore Courier');
    await page.mouse.move(2, 2); await page.waitForTimeout(650);
    await page.getByRole('button', { name: 'Choose Courier', exact: true }).click();
    await page.getByRole('alertdialog').waitFor();
    await page.getByRole('button', { name: 'Confirm job', exact: true }).click();
    await page.locator('.jobcenter__confirm .jobcenter__primary').evaluate(el => { el.click(); el.click(); });
    assert.deepEqual(await actions(), [{ type: 'jobs.apply', spot: 'citycenter', job: 'delivery' }]);
    await fire('result', { ok: true, action: 'jobs.quit', text: 'Unrelated reply' });
    assert(await page.locator('.jobcenter__confirm .jobcenter__primary').isDisabled());
    await fire('result', { ok: false, action: 'jobs.apply', text: 'Database unavailable' });
    await page.getByRole('button', { name: 'Confirm job', exact: true }).waitFor();
    await page.getByRole('button', { name: 'Confirm job', exact: true }).click();
    await fire('state', { job: { ...job, name: 'delivery', label: 'Courier', gradeLabel: 'Runner', salary: 45 } });
    await fire('result', { ok: true, action: 'jobs.apply', text: 'Hired.' });
    await page.waitForSelector('.jobcenter__confirm', { state: 'detached' });
    await page.getByRole('button', { name: 'Explore Courier', exact: true }).focus(); await page.mouse.move(2, 2);
    // The courier's pay follows the drawn route: a minimum and the order range.
    const terms = await page.locator('.jobcenter__terms').allInnerTexts();
    assert(terms.some(text => /From/.test(text) && /2–3 orders/.test(text)), 'variable pay and order range shown');
    for (const [width, height] of [[1920,1080], [1280,720], [1024,600], [800,900]]) {
      await page.setViewportSize({ width, height }); await page.waitForTimeout(650);
      const overflow = await page.locator('.jobcenter').evaluate(el => el.scrollWidth > el.clientWidth + 2);
      assert(!overflow, `no horizontal overflow ${width}`);
      await page.getByRole('button', { name: 'Start a run', exact: true }).scrollIntoViewIfNeeded();
      const box = await page.getByRole('button', { name: 'Start a run', exact: true }).boundingBox();
      assert(box.x >= 0 && box.x + box.width <= width && box.y >= 0 && box.y + box.height <= height, 'CTA usable');
      if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/jobs-${width}.png` });
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    assert.equal(await page.locator('.jobcenter').evaluate(el => getComputedStyle(el).animationName), 'none');
    await page.getByRole('button', { name: 'Start a run', exact: true }).click();
    const run = { active: true, id: 'test-order', index: 2, total: 6, label: 'Delivery run', icon: 'package', reward: 342,
      orders: 3, carried: 1, distanceKm: 2.4,
      objective: { label: 'Pick up · Burger stand', kind: 'pickup', position: { x: 0, y: 0, z: 0 }, radius: 2.6 }, hint: 'Collect the order at the marker (E).' };
    await fire('state', { jobRun: run }); await fire('result', { ok: true, action: 'jobs.start', text: 'Route assigned.' });
    await page.waitForSelector('.jobcenter', { state: 'detached' });
    assert(await page.locator('.job-run').isVisible());
    assert.match(await page.locator('.job-run__orders').innerText(), /1 carried · 3 orders · 2.4 km/i);
    if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: `${process.env.SCREENSHOT_DIR}/jobs-run-hud.png` });
    await fire('dialog', fixture); await page.getByRole('button', { name: /Cancel current run/ }).click();
    await page.getByRole('button', { name: 'Cancel this run', exact: true }).click();
    assert.equal((await actions()).at(-1).type, 'jobs.cancel');
    await fire('state', { jobRun: { active: false } }); await fire('result', { ok: true, action: 'jobs.cancel', text: 'Cancelled.' });
    await page.waitForSelector('.jobcenter__confirm', { state: 'detached' });
    await page.keyboard.press('Escape'); await page.waitForSelector('.jobcenter', { state: 'detached' });
    assert.equal(await page.locator('.job-run').count(), 0);
    const dialogEvents = await page.evaluate(() => window.sent.filter(([e]) => e === 'lightrp:ui:dialog:state').map(([,p]) => p));
    assert.deepEqual(dialogEvents.at(-1), { kind: 'jobcenter', open: false });
    await fire('state', { job }); // neither employment nor a shift gates item work
    for (const [stage, button] of [['collect','Find a collection point'], ['process','Processing GPS'], ['sell','Buyer GPS']]) {
      await fire('dialog', fixture);
      await page.getByRole('button', { name: 'Explore Scrapper', exact: true }).focus();
      await page.mouse.move(2,2);
      assert.equal(await page.getByRole('button', { name: 'Start a run', exact: true }).count(), 0);
      await page.getByText(/No shift or employment required/).waitFor();
      await page.getByRole('button', { name: button, exact: true }).click();
      assert.deepEqual((await actions()).at(-1), { type:'jobs.locate',job:'scrapper',stage });
      await fire('result', {ok:true,action:'jobs.locate',text:'GPS set.'});
      await page.waitForSelector('.jobcenter', {state:'detached'});
    }
    await fire('state', {jobWork:{active:true,kind:'collect',label:'Scrap collection',raw:'Scrap',product:'Salvaged Parts',rawCount:8,productCount:2,weight:12,maxWeight:40}});
    assert.equal(await page.locator('.job-run').count(),0, 'free item work uses the activity bar without a duplicate mission panel');
    await fire('state', {jobWork:{active:false}});
    assert.equal(await page.getByLabel('Current item work').count(),0);
    await fire('dialog', { ...fixture, jobs: {} });
    await page.getByText('No openings right now.').waitFor(); await page.keyboard.press('Escape');
    assert.deepEqual(errors, []);
    console.log('PASS: art/keyboard/confirmation, courier work orders, free collect/process/buyer GPS without employment or shift, no duplicate work panel, focus release, four resolutions, reduced motion');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
