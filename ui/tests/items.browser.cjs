/* The item catalogue in the inventory (since the 2026-10-27 redesign: tiles, hover card, menu).
   Run against `npx vite --host 127.0.0.1 --port 5177` with Playwright installed, or set
   PLAYWRIGHT_MODULE to an existing installation. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const art = '.inventory .inv-tile.is-filled .inv-tile__art img';
    await page.goto((process.env.UI_URL || 'http://127.0.0.1:5177') + '/?registered=1&items=1');
    await page.waitForSelector(art);
    // every filled tile of the mock shows its own local bitmap, loaded
    await page.waitForFunction(selector => {
      const tiles = document.querySelectorAll('.inventory .inv-tile.is-filled'), imgs = [...document.querySelectorAll(selector)];
      return tiles.length >= 18 && imgs.length === tiles.length && imgs.every(img => img.complete && img.naturalWidth > 0);
    }, art);
    const catalogue = await page.locator(art).count();
    const names = await page.locator(art).evaluateAll(imgs => imgs.map(img => img.getAttribute('src')));
    assert.equal(new Set(names).size, catalogue);
    assert(names.every(name => /^img\/items\/[a-z0-9_-]+\.png$/.test(name) && fs.existsSync(path.join(__dirname, '../public', name))), 'local bitmaps only');
    // Each file really has a transparent background, rather than painted black.
    const transparent = await page.locator(art).evaluateAll(imgs => imgs.every(img => {
      const canvas = document.createElement('canvas'); canvas.width = img.naturalWidth; canvas.height = img.naturalHeight;
      const ctx = canvas.getContext('2d'); ctx.drawImage(img, 0, 0);
      return ctx.getImageData(0, 0, 1, 1).data[3] === 0;
    }));
    assert(transparent, 'genuine alpha backgrounds');
    // The hover card carries what the detail panel used to: category, effects.
    const kit = page.getByRole('button', { name: 'Field First Aid Kit, 2, slot 18', exact: true });
    await kit.hover();
    const card = page.getByRole('tooltip');
    await card.waitFor();
    assert.match(await card.innerText(), /Field First Aid Kit/);
    assert.match(await card.locator('.inventory-effects').innerText(), /Health\s*\+45/);
    for (const viewport of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }, { width: 2560, height: 1080 }]) {
      await page.setViewportSize(viewport);
      assert(await page.locator('.inventory .inv-tile.is-filled').evaluateAll(tiles => tiles.every(tile => {
        const r = tile.getBoundingClientRect(), art = tile.querySelector('.inv-tile__art').getBoundingClientRect();
        const label = tile.querySelector('.inv-tile__label').getBoundingClientRect();
        return art.left >= r.left - 1 && art.right <= r.right + 1 && art.top >= r.top - 1 && art.bottom <= label.top + 2;
      })), `art fits without obscuring its label at ${viewport.width}`);
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `no viewport overflow at ${viewport.width}`);
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'rp-item-catalogue.png') });
    // A missing local bitmap falls back cleanly; no broken image icon survives.
    await page.route('**/img/items/firstaid.png', route => route.abort());
    await page.reload();
    await kit.waitFor();
    await page.waitForFunction(() => {
      const tile = document.querySelector('.inventory .inv-tile[aria-label="Field First Aid Kit, 2, slot 18"] .inv-tile__art');
      return tile && !tile.querySelector('img') && tile.querySelector('svg');
    });
    assert.deepEqual(errors, []);
    console.log(`PASS: ${catalogue} transparent local images, hover card effects, 3 viewports, missing-asset fallback`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
