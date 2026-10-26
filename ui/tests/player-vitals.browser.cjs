// Built UI with a synthetic Lua bridge; no game, server or player data touched.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(process.env.UI_DIST || '../resources/gamemodes/op77_lightrp/web');
const output = path.resolve('artifacts/player-vitals-check');
fs.mkdirSync(output, { recursive: true });
const active = { status: 'active', registered: true, key: 'default', step: 'done', welcomePending: false, slots: [], origins: [] };
const base = { ready: true, health: { value: 100, max: 100 }, stamina: { value: 100, max: 100 }, armor: 0, voice: { state: 'idle', level: 0, range: 'normal' }, vehicle: { active: false } };
const scenarios = [
  { name: 'healthy', health: { value: 100, max: 100 }, armor: 65, stamina: { value: 100, max: 100 }, food: 82, drink: 64, expected: [100, 65, 100, 82, 64], low: 0 },
  { name: 'hungry-thirsty', health: { value: 100, max: 100 }, armor: 0, stamina: { value: 100, max: 100 }, food: 0, drink: 0, expected: [100, 0, 100, 0, 0], low: 2 },
  { name: 'critical', health: { value: 8, max: 100 }, armor: 0, stamina: { value: 7, max: 200 }, food: 10, drink: 15, expected: [8, 0, 3.5, 10, 15], low: 3 },
  { name: 'empty', health: { value: 0, max: 100 }, armor: 0, stamina: { value: 0, max: 100 }, food: 0, drink: 0, expected: [0, 0, 0, 0, 0], low: 3 },
  { name: 'custom-max', health: { value: 150, max: 300 }, armor: 100, stamina: { value: 75, max: 150 }, food: 40, drink: 75, expected: [50, 100, 50, 40, 75], low: 0 },
  { name: 'large-values', health: { value: 1000, max: 1500 }, armor: 1000, stamina: { value: 250, max: 100 }, food: 130, drink: -20, expected: [1000 / 1500 * 100, 100, 100, 100, 0], low: 1 },
];

(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    for (const deviceScaleFactor of [1, 1.5]) {
      const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor, reducedMotion: 'reduce' });
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.route('http://vitals.test/**', route => {
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
      await page.goto('http://vitals.test/');
      await page.waitForFunction(() => window.testBridge.ready);
      const fire = (name, data) => page.evaluate(({ name, data }) => window.testBridge.fire(name, data), { name, data });
      await fire('state', { character: active });
      assert.equal(await page.locator('.player-vitals').count(), 0, 'wait for native stats');
      for (const [width, height] of [[1920,1080], [1280,720], [2560,1440], [800,600], [375,667], [320,568]]) {
        await page.setViewportSize({ width, height });
        for (const scenario of scenarios) {
          await fire('state', { needs: { food: scenario.food, drink: scenario.drink } });
          await fire('hud', { ...base, health: scenario.health, armor: scenario.armor, stamina: scenario.stamina });
          await page.locator('.player-vitals').waitFor();
          await page.evaluate(() => document.fonts.ready);
          assert.equal(await page.locator('.player-vital').count(), 5);
          assert.equal(await page.locator('.player-vital--low').count(), scenario.low);
          const percentages = await page.locator('.player-vital').evaluateAll(els => els.map(el => Number(el.dataset.percent)));
          percentages.forEach((pct, index) => assert.ok(Math.abs(pct - scenario.expected[index]) < .00001, `${scenario.name}: gauge ${index} percentage`));
          assert.equal(await page.locator('[data-vital="health"] .player-vital__number').innerText(), String(scenario.health.value));
          assert.equal(await page.locator('[data-vital="health"] .player-vital__limit').innerText(), `/ ${scenario.health.max}`);
          const violations = await page.evaluate(() => {
            const issues = [];
            const vitals = [...document.querySelectorAll('.player-vital')];
            const bounds = vitals.map(el => el.getBoundingClientRect());
            const overlap = (a, b) => a.left < b.right - .1 && a.right > b.left + .1 && a.top < b.bottom - .1 && a.bottom > b.top + .1;
            if (bounds[0].width < bounds[1].width * 1.4) issues.push('health not dominant');
            const warning = document.querySelector('.player-vitals__warning')?.getBoundingClientRect();
            vitals.forEach((vital, index) => {
              const rect = bounds[index];
              if (rect.left < 0 || rect.right > innerWidth || rect.bottom > innerHeight) issues.push(`${index}: off-screen`);
              bounds.slice(index + 1).forEach(other => { if (overlap(rect, other)) issues.push(`${index}: overlapping gauges`); });
              if (warning && overlap(warning, rect)) issues.push(`${index}: warning overlaps gauge`);
              const label = vital.querySelector('.player-vital__caption');
              if (label.scrollWidth > label.clientWidth + 1) issues.push(`${index}: overflowing label`);
              const range = document.createRange(); range.selectNodeContents(vital.querySelector('.player-vital__number'));
              const number = range.getBoundingClientRect();
              const icon = vital.querySelector('.player-vital__icon').getBoundingClientRect();
              if (overlap(number, icon)) issues.push(`${index}: number/icon overlap`);
              const arc = vital.querySelector('.player-vital__track');
              const matrix = arc.getScreenCTM();
              const halfStroke = Math.max(parseFloat(getComputedStyle(arc).strokeWidth), parseFloat(getComputedStyle(vital.querySelector('.player-vital__fill')).strokeWidth)) * Math.hypot(matrix.a, matrix.b) / 2;
              const length = arc.getTotalLength();
              for (let step = 0; step <= 200; step++) {
                const point = arc.getPointAtLength(length * step / 200).matrixTransform(matrix);
                for (const content of [number, icon]) {
                  if (point.x + halfStroke > content.left && point.x - halfStroke < content.right && point.y + halfStroke > content.top && point.y - halfStroke < content.bottom) {
                    issues.push(`${index}: ${content === number ? 'number' : 'icon'} touches ring at ${point.x.toFixed(1)},${point.y.toFixed(1)}; bounds ${JSON.stringify(content.toJSON())}`); return;
                  }
                }
              }
              const pct = Number(vital.dataset.percent);
              const fill = vital.querySelector('.player-vital__fill');
              if (Math.abs(parseFloat(fill.style.strokeDashoffset) - (100 - pct)) > .001) issues.push(`${index}: wrong fill`);
              if (pct === 0 && getComputedStyle(fill).opacity !== '0') issues.push(`${index}: zero gauge has a fill`);
              if (getComputedStyle(fill).transitionDuration !== '0s') issues.push(`${index}: reduced motion ignored`);
            });
            return issues;
          });
          if (width === 1920 && deviceScaleFactor === 1 || violations.length) {
            await page.evaluate(() => { document.body.style.background = 'repeating-linear-gradient(115deg, #b1a48e 0 60px, #beb29d 61px 65px, #a89a82 66px 130px)'; });
            await page.screenshot({ path: path.join(output, violations.length ? 'layout-failure.png' : `${scenario.name}.png`), clip: { x: 0, y: height - 165, width: Math.min(430, width), height: 165 } });
          }
          assert.deepEqual(violations, [], `${width}px @${deviceScaleFactor}: ${scenario.name}`);
        }
      }
      // Live damage/healing feedback and critical styling must clear on recovery.
      await fire('state', { needs: { food: 100, drink: 100 } });
      await fire('hud', base);
      await page.waitForFunction(() => !document.querySelector('.player-vital__delta'));
      await fire('hud', { ...base, health: { value: 8, max: 100 } });
      await page.waitForFunction(() => document.querySelector('.player-vital__delta')?.textContent === '-92');
      assert.equal(await page.locator('.player-vital--critical').count(), 1);
      await page.waitForFunction(() => !document.querySelector('.player-vital__delta'));
      await fire('hud', base);
      await page.waitForFunction(() => document.querySelector('.player-vital__delta')?.textContent === '+92');
      assert.equal(await page.locator('.player-vital--critical').count(), 0);
      assert.equal(await page.locator('.player-vitals__warning').count(), 0);
      await page.emulateMedia({ reducedMotion: 'no-preference' });
      assert.match(await page.locator('.player-vital__fill').first().evaluate(el => getComputedStyle(el).transitionProperty), /stroke-dashoffset/);
      await fire('state', { character: { ...active, status: 'draft', registered: false } });
      assert.equal(await page.locator('.player-vitals').count(), 0, 'hidden during character creation');
      assert.deepEqual(errors, []);
      await page.close();
    }
    console.log('PASS: 5 live dials; 6 states × 6 viewports × 2 pixel densities; ring/text spacing, damage/healing, warning recovery, custom maxima, reduced motion and character gating.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
