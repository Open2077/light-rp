// Loads the actual standalone targeting WebUI with a mock bridge. No game,
// server connection or visible browser; static files are fulfilled in-process.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const web = path.resolve(__dirname, '../../resources/system/open77_contextmenu/web');
const cargo = { id: 'op77_lightrp/cargo', label: 'Trunk & hood', icon: 'interact' };
const controls = { id: 'op77_lightrp/controls', label: 'Vehicle controls', icon: 'tool' };
const rows = [
  { token: '1', label: 'Lock vehicle', icon: 'lock' },
  { token: '2', label: 'Access trunk inventory', submenu: cargo },
  { token: '3', label: 'Open trunk', submenu: cargo },
  { token: '4', label: 'Open hood', submenu: cargo },
  { token: '5', label: 'Start engine', submenu: controls },
  { token: '6', label: 'Turn headlights on', submenu: controls },
  { token: '7', label: 'Turn high beams on', submenu: controls },
  { token: '8', label: 'Sound horn', submenu: controls },
  { token: '9', label: 'Check vehicle status', icon: 'info' },
];
(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.BROWSER_CHANNEL || 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.route('http://context.test/**', route => {
      const file = path.resolve(web, '.' + new URL(route.request().url()).pathname);
      if (!file.startsWith(web + path.sep) || !fs.existsSync(file)) return route.fulfill({ status: 404, body: '' });
      const type = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2' }[path.extname(file)];
      return route.fulfill({ path: file, contentType: type || 'application/octet-stream' });
    });
    await page.addInitScript(() => {
      const handlers = new Map();
      window.bridge = { sent: [], fire: (name, payload) => handlers.get(name)?.(payload) };
      window.Open77 = { on: (name, fn) => handlers.set(name, fn), ready() {}, emit: (name, payload) => window.bridge.sent.push({ name, payload }) };
    });
    await page.goto('http://context.test/index.html');
    await page.waitForFunction(() => window.bridge.sent.some(e => e.name === 'context:ready'));
    const fire = (name, payload) => page.evaluate(({ name, payload }) => window.bridge.fire(name, payload), { name, payload });
    const sent = () => page.evaluate(() => window.bridge.sent);
    const clear = () => page.evaluate(() => { window.bridge.sent = []; });
    const item = name => page.getByRole('menuitem', { name, exact: true });
    const labels = () => page.locator('#actions .label').allTextContents();
    let epoch = 0;
    const open = async (actions = rows, x = .5, y = .5, scale = 1) => {
      await fire('context:open', { epoch: ++epoch, key: 'ALT', appearance: { scale } });
      await fire('context:loading', { epoch: ++epoch, x, y });
      await fire('context:menu', { epoch, target: { kind: 'vehicle', vehicleId: 10 }, distance: 2, actions });
      await clear();
    };
    const root = ['Lock vehicle', 'Trunk & hood', 'Vehicle controls', 'Check vehicle status'];
    await open();
    assert.deepEqual(await labels(), root);
    assert.equal(await item('Trunk & hood').getAttribute('aria-haspopup'), 'menu');
    await item('Trunk & hood').click();
    assert.deepEqual(await labels(), ['Back', 'Access trunk inventory', 'Open trunk', 'Open hood']);
    assert.equal(await page.locator('#title').innerText(), 'Trunk & hood');
    assert.deepEqual(await sent(), [], 'entering a submenu never selects or repicks the target');
    await item('Back').click();
    assert.deepEqual(await labels(), root);
    await item('Vehicle controls').focus();
    await page.keyboard.press('ArrowRight');
    assert.deepEqual(await labels(), ['Back', 'Start engine', 'Turn headlights on', 'Turn high beams on', 'Sound horn']);
    assert.equal(await page.evaluate(() => document.activeElement.textContent), 'Start engine');
    await page.keyboard.press('ArrowLeft');
    assert.deepEqual(await labels(), root);
    assert.equal(await page.evaluate(() => document.activeElement.textContent), 'Vehicle controls');
    await page.keyboard.press('Enter');
    await page.keyboard.press('Backspace');
    assert.deepEqual(await labels(), root);
    await item('Trunk & hood').click();
    await page.mouse.click(10, 10, { button: 'right' });
    assert.deepEqual(await labels(), root);
    assert.deepEqual(await sent(), []);

    await item('Trunk & hood').click();
    await item('Access trunk inventory').click();
    assert.deepEqual(await sent(), [{ name: 'context:select', payload: { token: '2', epoch } }]);
    assert.equal(await item('Back').isDisabled(), true);
    await page.keyboard.press('Backspace');
    assert.equal(await page.locator('#title').innerText(), 'Trunk & hood');
    await fire('context:error', { epoch, message: 'Vehicle locked.' });
    assert.equal(await item('Back').isDisabled(), false);
    await item('Back').click();
    await clear();
    await item('Vehicle controls').click();
    await page.keyboard.press('Escape');
    assert.deepEqual(await sent(), [{ name: 'context:cancel', payload: { epoch } }]);
    await fire('context:close', {});
    assert.equal(await page.locator('#workspace').isHidden(), true);

    // A new target always returns to root; old replies cannot repopulate a menu.
    await open(rows.filter(row => !row.submenu));
    assert.deepEqual(await labels(), ['Lock vehicle', 'Check vehicle status']);
    await fire('context:menu', { epoch: epoch - 1, actions: rows });
    assert.deepEqual(await labels(), ['Lock vehicle', 'Check vehicle status']);
    await open([{ token: 'flat', label: 'Existing consumer action' }]);
    assert.deepEqual(await labels(), ['Existing consumer action']);
    await item('Existing consumer action').click();
    assert.deepEqual(await sent(), [{ name: 'context:select', payload: { token: 'flat', epoch } }]);
    await open([rows[1], { token: 'other', label: 'Other trunk', submenu: { ...cargo, id: 'other/cargo' } }]);
    assert.equal(await page.locator('[data-folder]').count(), 2, 'same folder label does not mix resource owners');
    await page.locator('[data-folder="op77_lightrp/cargo"]').click();
    assert.deepEqual(await labels(), ['Back', 'Access trunk inventory']);

    // No clipping at viewport edges, including a small window and large UI scale.
    for (const [width, height] of [[640, 360], [1280, 720], [1920, 1080]]) {
      await page.setViewportSize({ width, height });
      await open(rows, .99, .99, 1.5);
      await item('Vehicle controls').click();
      const box = await page.locator('#menu').boundingBox();
      assert(box.x >= 0 && box.y >= 0 && box.x + box.width <= width && box.y + box.height <= height);
    }
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await open(); await item('Trunk & hood').click();
    assert.equal(await page.locator('#actions').evaluate(el => getComputedStyle(el).animationName), 'none');
    if (process.env.SCREENSHOT_DIR) {
      await page.locator('#menu').screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'vehicle-submenu.png') });
      await item('Back').click();
      await page.locator('#menu').screenshot({ path: path.join(process.env.SCREENSHOT_DIR, 'vehicle-context-root.png') });
    }
    assert.deepEqual(errors, []);
    console.log('PASS: compact four-entry root; mouse/keyboard/back; exact leaf tokens; busy/errors; target reset; provider isolation; old consumers; edges and reduced motion');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
