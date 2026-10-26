// Synthetic bridge + the shipped UI. No game, vehicle or player is modified.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(process.env.UI_DIST || '../resources/gamemodes/op77_lightrp/web');
const output = path.resolve('artifacts/vehicle-cluster-check');
fs.mkdirSync(output, { recursive: true });
const scenarios = [
  { name: 'stationary', speedKph: 0, gear: 'R', health: 1, label: 'Thorton Galena', fuel: { litres: 39, capacity: 55, fraction: 39/55, low: false, empty: false } },
  { name: 'three-digits', speedKph: 188, gear: '6', health: 1, label: 'Quadra Type-66', fuel: { litres: 100, capacity: 100, fraction: 1, low: false, empty: false } },
  { name: 'reserve', speedKph: 87, gear: '3', health: .28, label: 'Archer Quartz', fuel: { litres: 6.4, capacity: 55, fraction: .116, low: true, empty: false } },
  { name: 'empty', speedKph: 0, gear: 'N', health: 0, label: 'Thorton Galena', fuel: { litres: 0, capacity: 55, fraction: 0, low: true, empty: true } },
  { name: 'unknown', speedKph: 999, gear: '10', health: .99, label: 'Vehicle' },
  { name: 'long-name', speedKph: 240, gear: '6', health: 1, label: 'Quadra Type-66 Cthulhu // Limited Night City Edition', fuel: { litres: 1000, capacity: 1000, fraction: 1, low: false, empty: false } },
];

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    for (const deviceScaleFactor of [1, 1.5]) {
      const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor });
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.route('http://cluster.test/**', route => {
        const url = new URL(route.request().url());
        const file = path.resolve(root, '.' + (url.pathname === '/' ? '/index.html' : url.pathname));
        if (!file.startsWith(root + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404 });
        const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
        return route.fulfill({ body: fs.readFileSync(file), contentType: mime[path.extname(file)] || 'application/octet-stream' });
      });
      await page.addInitScript(() => {
        const handlers = {};
        window.testBridge = { ready: false, fire: (name, data) => (handlers['lightrp:ui:' + name] || []).forEach(fn => fn(data)) };
        window.Open77 = { on: (name, fn) => (handlers[name] ??= []).push(fn), emit: name => { if (name.endsWith(':ready')) window.testBridge.ready = true; }, ready() {} };
      });
      await page.goto('http://cluster.test/');
      await page.waitForFunction(() => window.testBridge.ready);
      await page.evaluate(() => window.testBridge.fire('state', { character: { status: 'active', registered: true, key: 'default', step: 'done', welcomePending: false, slots: [], origins: [] } }));
      for (const [width, height] of [[1920,1080], [1280,720], [2560,1440], [800,600]]) {
        await page.setViewportSize({ width, height });
        for (const scenario of scenarios) {
          await page.evaluate(vehicle => window.testBridge.fire('hud', {
            ready: true, health: { value: 100, max: 100 }, stamina: { value: 100, max: 100 }, armor: 0,
            voice: { state: 'idle', level: 0, range: 'normal' }, vehicle: { active: true, ...vehicle },
          }), scenario);
          await page.locator('.cluster__speed-value').waitFor();
          await page.evaluate(() => document.fonts.ready);
          const violations = await page.evaluate(() => {
            const issues = [];
            const box = document.querySelector('.cluster').getBoundingClientRect();
            const labels = [...document.querySelectorAll('.cluster__speed span, .cluster__side span, .cluster__side svg, .cluster__gear b')].map(el => {
              // Text ink is narrower than its grid lane. Range includes the font's
              // ascender/descender area, making this check conservative.
              const range = document.createRange(); range.selectNodeContents(el);
              const rect = el instanceof SVGElement ? el.getBoundingClientRect() : range.getBoundingClientRect();
              return { rect, name: el.textContent || 'icon' };
            });
            function intersects(a, b) { return a.left < b.right - .2 && a.right > b.left + .2 && a.top < b.bottom - .2 && a.bottom > b.top + .2; }
            for (let i = 0; i < labels.length; i++) {
              const { rect: a, name } = labels[i];
              if (a.left < box.left || a.right > box.right || a.top < box.top || a.bottom > box.bottom) issues.push(`${name}: outside cluster`);
              for (let j = i + 1; j < labels.length; j++) if (intersects(a, labels[j].rect)) issues.push(`${name}: overlaps ${labels[j].name}`);
              for (const arc of document.querySelectorAll('.cluster__svg .cl-seg__cell, .cluster__svg .cl-track')) {
                const matrix = arc.getScreenCTM();
                const halfStroke = parseFloat(getComputedStyle(arc).strokeWidth) * Math.hypot(matrix.a, matrix.b) / 2;
                const length = arc.getTotalLength();
                for (let step = 0; step <= 40; step++) {
                  const point = arc.getPointAtLength(length * step / 40).matrixTransform(matrix);
                  if (point.x + halfStroke > a.left && point.x - halfStroke < a.right && point.y + halfStroke > a.top && point.y - halfStroke < a.bottom) {
                    issues.push(`${name}: touches gauge arc`); break;
                  }
                }
              }
            }
            const name = document.querySelector('.cluster__name').getBoundingClientRect();
            if (name.left < box.left || name.right > box.right) issues.push('vehicle name outside cluster');
            const frame = document.querySelector('.cluster-frame').getBoundingClientRect();
            if (frame.left < 0 || frame.right > innerWidth || frame.bottom > innerHeight) issues.push('cluster outside screen');
            return issues;
          });
          if (violations.length) {
            await page.locator('.cluster-frame').screenshot({ path: path.join(output, 'layout-failure.png'), animations: 'disabled' });
            console.log(await page.evaluate(() => [...document.querySelectorAll('.cluster__speed span, .cluster__side span')].map(el => {
              const range = document.createRange(); range.selectNodeContents(el); const css = getComputedStyle(el);
              return { text: el.textContent, font: css.font, box: el.getBoundingClientRect().toJSON(), textBox: range.getBoundingClientRect().toJSON() };
            })));
          }
          assert.deepEqual(violations, [], `${width}px @${deviceScaleFactor}: ${scenario.name}`);
          assert.equal(await page.locator('.cluster__speed-value').innerText(), String(scenario.speedKph).padStart(3, '0'));
          if (width === 1920 && deviceScaleFactor === 1) {
            await page.locator('.cluster-frame').screenshot({ path: path.join(output, `${scenario.name}.png`), animations: 'disabled' });
          }
        }
      }
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.evaluate(() => window.testBridge.fire('hud', { ready: true, health: { value: 100, max: 100 }, stamina: { value: 100, max: 100 }, armor: 0, vehicle: { active: false } }));
      assert.equal(await page.locator('.cluster-frame').count(), 0);
      assert.deepEqual(errors, []);
      await page.close();
    }
    console.log('PASS: vehicle cluster, 6 readout states × 4 resolutions × 2 pixel densities; text/arc spacing and vehicle exit.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
