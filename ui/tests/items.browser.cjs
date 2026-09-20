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
    await page.goto((process.env.UI_URL || 'http://127.0.0.1:5177') + '/?registered=1&items=1');
    await page.waitForSelector('.inventory-slot img');
    await page.waitForFunction(() => {
      const imgs = [...document.querySelectorAll('.inventory-slot img')];
      return imgs.length === 18 && imgs.every(img => img.complete && img.naturalWidth > 0);
    });
    const names = await page.locator('.inventory-slot img').evaluateAll(imgs => imgs.map(img => img.getAttribute('src')));
    assert.equal(new Set(names).size, 18);
    // Each file really has a transparent background, rather than painted black.
    const transparent = await page.locator('.inventory-slot img').evaluateAll(imgs => imgs.every(img => {
      const canvas = document.createElement('canvas'); canvas.width = img.naturalWidth; canvas.height = img.naturalHeight;
      const ctx = canvas.getContext('2d'); ctx.drawImage(img, 0, 0);
      return ctx.getImageData(0, 0, 1, 1).data[3] === 0;
    }));
    assert(transparent, 'genuine alpha backgrounds');
    await page.getByRole('button', { name: 'Field First Aid Kit, 2, slot 18', exact: true }).click();
    await page.waitForFunction(() => document.querySelector('.inventory-detail img')?.complete);
    assert.match(await page.locator('.inventory-effects').innerText(), /Health\s*\+45/);
    for (const viewport of [{ width: 1280, height: 720 }, { width: 1920, height: 1080 }, { width: 2560, height: 1080 }]) {
      await page.setViewportSize(viewport);
      assert(await page.locator('.inventory-detail__art').evaluate(box => {
        const r = box.getBoundingClientRect(), img = box.querySelector('img').getBoundingClientRect();
        return img.top >= r.top && img.bottom <= r.bottom && img.left >= r.left && img.right <= r.right;
      }), 'detail image stays within the art area');
      assert(await page.locator('.inventory-slot.is-filled').evaluateAll(slots => slots.every(slot => {
        const r = slot.getBoundingClientRect(), art = slot.querySelector('.inventory-slot__icon').getBoundingClientRect();
        const label = slot.querySelector('.inventory-slot__label').getBoundingClientRect();
        return art.left >= r.left && art.right <= r.right && art.top >= r.top && art.bottom <= label.top + 2;
      })), 'art fits without obscuring its label');
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForFunction(() => getComputedStyle(document.querySelector('.inventory-detail__item')).opacity === '1');
    if (process.env.SCREENSHOT_DIR) await page.screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'rp-item-catalogue.png') });
    // A missing local bitmap falls back cleanly; no broken image icon survives.
    await page.route('**/img/items/firstaid.png', route => route.abort());
    await page.reload();
    await page.getByRole('button', { name: 'Field First Aid Kit, 2, slot 18', exact: true }).click();
    await page.waitForSelector('.inventory-detail__art svg');
    assert.equal(await page.locator('.inventory-detail__art img').count(), 0);
    assert.equal(fs.readdirSync(path.join(__dirname, '../public/img/items')).filter(name => name.endsWith('.png')).length, 18);
    assert.deepEqual(errors, []);
    console.log('PASS: 18 transparent local images, detail effects, 3 viewports, missing-asset fallback');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
