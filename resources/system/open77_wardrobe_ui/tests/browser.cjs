// The fitting room page in headless Chromium/Edge with a mocked Open77 bridge
// and the real catalogue (tests/fixture.cjs). Covers the layout at three
// sizes, categories and camera framing, try-on preview, favorites, outfits,
// save, the take-away choice and the close/discard flow. Run from anywhere:
//   PLAYWRIGHT_MODULE=<playwright-core> node tests/browser.cjs
// SCREENSHOT_DIR keeps the captures.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const { catalogue, openState } = require('./fixture.cjs');

const web = path.resolve(__dirname, '../web');
const shots = process.env.SCREENSHOT_DIR;

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('http://wardrobe.test/**', route => {
      const url = new URL(route.request().url());
      const file = path.resolve(web, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
      if (!file.startsWith(web + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404 });
      const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.webp': 'image/webp', '.woff2': 'font/woff2' };
      return route.fulfill({ body: fs.readFileSync(file), contentType: mime[path.extname(file)] || 'application/octet-stream' });
    });
    await page.addInitScript(() => {
      const handlers = {}; window.bridge = { sent: [], fire: (n, p) => (handlers[n] || []).forEach(f => f(p)) };
      // The game's world behind the page: a flat dark backdrop for the captures.
      document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.background = 'radial-gradient(ellipse at 50% 45%, #3a3f48, #121418 70%)'; });
      window.Open77 = { on: (n, f) => (handlers[n] ??= []).push(f), emit: (n, p) => window.bridge.sent.push([n, p]), ready() {} };
    });
    await page.goto('http://wardrobe.test/');
    const fire = (name, payload) => page.evaluate(([n, p]) => window.bridge.fire(n, p), [name, payload]);
    const sent = name => page.evaluate(n => window.bridge.sent.filter(([e]) => e === n).map(([, p]) => p), name);
    const shot = async name => { if (shots) await page.screenshot({ path: path.join(shots, name + '.png') }); };
    await page.waitForTimeout(300); if (!(await sent('wardrobe:ready')).length) console.log('ERRORS', errors);
    assert((await sent('wardrobe:ready')).length >= 1, 'handshake');

    // Open, then the catalogue streams in batches.
    await fire('wardrobe:open', openState());
    await page.locator('#room').waitFor();
    assert.equal(await page.locator('.skeleton').count() > 0, true, 'skeletons while the catalogue loads');
    assert.deepEqual((await sent('wardrobe:focus')).at(-1), { zone: 'head' }, 'Headwear frames the head');
    const items = catalogue('m');
    for (let i = 0; i < items.length; i += 48) await fire('wardrobe:catalogue', { items: items.slice(i, i + 48) });
    await fire('wardrobe:catalogue', { items: {}, complete: true }); // Lua sends an empty last batch as {}
    await fire('wardrobe:favorites', { items: [], available: true });
    await page.locator('.card').first().waitFor();
    assert.equal(await page.locator('#slots button').count(), 7);
    const headCount = items.filter(i => i.slot === 'Head').length;
    assert.equal(await page.locator('#count').innerText(), `${headCount} ITEMS`);
    assert.equal(await page.locator('.card').count(), Math.min(60, headCount), 'first batch only');
    await page.waitForFunction(() => [...document.querySelectorAll('.card img')].slice(0, 12).every(i => i.complete && i.naturalWidth > 0));
    await page.waitForTimeout(500); await shot('wardrobe-1920');
    await page.locator('#catalogue').evaluate(g => { g.scrollTop = g.scrollHeight; g.dispatchEvent(new Event('scroll')); });
    assert(await page.locator('.card').count() > 60, 'infinite scroll appends the next batch');
    await page.locator('#catalogue').evaluate(g => { g.scrollTop = 0; });

    // Categories move the camera: Footwear frames the feet.
    await page.locator('#slots button', { hasText: 'Footwear' }).click();
    assert.deepEqual((await sent('wardrobe:focus')).at(-1), { zone: 'feet' });
    assert.equal(await page.locator('#zone-label').innerText(), 'FEET');
    await page.locator('#zones button[data-zone="full"]').click();
    assert.deepEqual((await sent('wardrobe:focus')).at(-1), { zone: 'full' }, 'manual framing');

    // Try on: the preview carries the garment, the save button counts changes.
    const shoe = page.locator('.card').nth(2), record = await shoe.getAttribute('data-record');
    await shoe.click();
    const preview = (await sent('wardrobe:preview')).at(-1);
    assert.equal(preview.equipment.Feet, record);
    assert(await page.locator('.item.trying').count() === 1, 'trying sweep while the preview is pending');
    await fire('wardrobe:previewResult', { ok: true });
    assert(await page.locator('.item.selected').count() === 1);
    assert.match(await page.locator('#save').innerText(), /SAVE LOOK · 1/i);
    assert.equal(await page.locator('#saved-state').innerText(), 'UNSAVED');
    assert.match(await page.locator('.look__row.changed').innerText(), /FOOTWEAR/);

    // Favorites.
    await page.locator('.item').nth(2).hover();
    await page.locator('.item').nth(2).locator('.favorite').click();
    assert.deepEqual((await sent('wardrobe:favorite')).at(-1), { record, enabled: true });
    await fire('wardrobe:favorites', { items: [record], available: true });
    await page.locator('#filter').click();
    assert.equal(await page.locator('.card').count(), 1, 'favorites filter');
    await page.locator('#filter-all').click();

    // Drag to turn, wheel to zoom.
    const stage = await page.locator('#stage').boundingBox();
    await page.mouse.move(stage.x + stage.width / 2, stage.y + 300); await page.mouse.down();
    await page.mouse.move(stage.x + stage.width / 2 + 200, stage.y + 300, { steps: 6 }); await page.mouse.up();
    const orbit = (await sent('wardrobe:orbit')).at(-1);
    assert(orbit && orbit.degrees !== 180, 'drag turns the camera');
    await page.mouse.wheel(0, 120);
    assert.deepEqual((await sent('wardrobe:zoom')).at(-1), { delta: 1 });

    // Outfits: copy what is worn into outfit 2, rename, wear.
    await page.locator('#outfits-tab').click();
    await page.locator('.outfit').nth(1).click();
    await page.locator('#capture').click(); await fire('wardrobe:previewResult', { ok: true });
    await page.locator('#outfit-name').fill('Street'); await page.locator('#rename').click();
    assert.match(await page.locator('.outfit').nth(1).innerText(), /Street/);
    assert(await page.locator('.outfit').nth(1).locator('img').count() >= 1, 'outfit card shows its pieces');
    await page.waitForTimeout(300); await shot('wardrobe-outfits');
    await page.locator('#equipment-tab').click();

    // Save, then take it away as separate pieces.
    await page.locator('#save').click();
    const patch = (await sent('wardrobe:save')).at(-1);
    assert.equal(patch.equipment.Feet, record);
    assert.equal(patch.wardrobe.names[1], 'Street');
    const saved = openState({ revision: 4, equipment: Object.assign(openState().equipment, { Feet: record }),
      wardrobe: { active: 1, outfits: { 1: { Face: 'Items.Cop_01_Set_Glasses', Feet: record } }, names: { 0: 'Night out', 1: 'Street' } } });
    await fire('wardrobe:committed', { ok: true, state: saved });
    await page.locator('#takeaway').waitFor();
    assert.match(await page.locator('#take-pieces-text').innerText(), /1 new piece/);
    await page.waitForTimeout(350); await shot('wardrobe-takeaway');
    await page.locator('#take-outfit').click();
    assert(await page.locator('#take-name').isVisible());
    assert.equal(await page.locator('#take-name').inputValue(), 'Street', 'outfit name proposed');
    await page.locator('#take-pieces').click();
    await page.locator('#take-confirm').click();
    const take = (await sent('wardrobe:takeAway')).at(-1);
    assert.equal(take.mode, 'pieces');
    assert.deepEqual(take.pieces.map(p => p.slot), ['Feet'], 'only what this visit added');
    assert.deepEqual(take.look.map(p => p.slot).sort(), ['Face', 'Feet']);
    assert.match(take.pieces[0].icon, /^icons\/m\/[0-9a-f]{16}\.webp$/);
    await fire('wardrobe:takeAwayResult', { ok: true, text: 'Added to your bag.' });
    assert(await page.locator('#takeaway').isHidden());

    // Sizes: nothing overflows, the save button stays reachable.
    for (const [width, height] of [[1280, 720], [1600, 900]]) {
      await page.setViewportSize({ width, height }); await page.waitForTimeout(250);
      const box = await page.locator('#save').boundingBox();
      assert(box && box.y + box.height <= height && box.x + box.width <= width, `save reachable at ${width}x${height}`);
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'no page overflow');
      await shot(`wardrobe-${width}`);
    }
    await page.setViewportSize({ width: 1920, height: 1080 });

    // Close with a draft asks first.
    await page.locator('.card').nth(4).click(); await fire('wardrobe:previewResult', { ok: true });
    await page.keyboard.press('Escape');
    assert(await page.locator('#confirm').isVisible(), 'discard confirmation');
    await page.locator('#confirm-yes').click();
    assert.equal((await sent('wardrobe:close')).length, 1);
    await fire('wardrobe:closed', {});
    assert(await page.locator('#room').isHidden());
    assert.deepEqual(errors, []);
    console.log('PASS: fitting room layout (3 sizes), real catalogue + icons, infinite scroll, camera framing per category, drag/zoom, try-on, favorites, outfits, save, take-away (pieces/outfit), discard');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
