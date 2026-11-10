const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    fs.mkdirSync('artifacts/fuel-browser', { recursive: true });
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = { sent: [], ready: false, fire: (name, p) => (handlers.get('lightrp:ui:' + name) || []).forEach(fn => fn(p)) };
      window.Open77 = { on: (name, fn) => handlers.set(name, [...(handlers.get(name) || []), fn]), ready() {},
        emit: (name, payload) => { window.testBridge.sent.push({ name, payload }); if (name === 'lightrp:ui:ready') window.testBridge.ready = true; } };
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5191');
    await page.waitForFunction(() => window.testBridge.ready);
    const fire = (name, payload) => page.evaluate(({name,payload}) => window.testBridge.fire(name,payload), {name,payload});
    await fire('state',{character:{status:'active',step:'done',registered:true,welcomePending:false}});
    const car = {id:9,label:'Thorton Galena',litres:12.4,capacity:55,moving:false,engineOn:false};
    const payload = {kind:'fuel',spot:{id:'pump01',name:'Fuel station',pump:1,pumps:12},pricePerLitre:3,pumpRange:7,litresPerSecond:1.2,minimumFillMs:5000,
      vehicle:car,vehicles:[car,{...car,id:10,label:'Archer Hella',unavailable:'Switch off the engine first'}],
      jerrycan:{litres:20,refillPrice:60,buyPrice:85,empty:0,full:1},money:{currency:'€$',cash:200,bank:3000}};
    await fire('dialog',payload);
    await page.getByRole('button',{name:'Continue to vehicle'}).waitFor();
    const box = await page.locator('.pump').boundingBox();
    assert(box.width<500 && box.x>1300,'compact side terminal, not fullscreen');
    await page.getByRole('button',{name:'10 L',exact:true}).click();
    assert.match(await page.locator('.pump__section-title').innerText(),/10 L/);
    await page.getByRole('button',{name:'Continue to vehicle'}).click();
    const actions = await page.evaluate(() => window.testBridge.sent.filter(x=>x.name==='lightrp:ui:action').map(x=>x.payload));
    assert.deepEqual(actions.filter(x=>x.type==='fuel.buy'),[{type:'fuel.buy',spot:'pump01',vehicle:9,litres:10,pay:'cash'}]);
    assert(await page.getByRole('button',{name:'Preparing…'}).isDisabled(),'double submit disabled');
    await fire('result',{ok:false,text:'Pump busy',action:'fuel.buy'});
    await page.getByRole('button',{name:'Continue to vehicle'}).waitFor();
    await page.getByLabel('YOUR VEHICLE AT THIS PUMP').selectOption('10');
    assert(await page.getByRole('button',{name:'Switch off the engine first'}).isDisabled());
    await page.getByLabel('YOUR VEHICLE AT THIS PUMP').selectOption('9');
    await page.screenshot({path:'artifacts/fuel-browser/terminal-1080.png'});
    await page.keyboard.press('Escape'); assert.equal(await page.locator('.pump').count(),0);
    await fire('dialog',payload);
    await page.getByRole('button',{name:'Continue to vehicle'}).waitFor();
    await fire('fuel:snapshot',{...payload,vehicle:undefined,vehicles:{}});
    await page.locator('.pump__empty').waitFor();
    assert.match(await page.locator('.pump__empty').innerText(),/No vehicle nearby/);
    await page.keyboard.press('Escape');
    await fire('dialog',{...payload,vehicle:undefined,vehicles:{}});
    await page.locator('.pump__empty').waitFor();
    await page.locator('.pump__payment label').filter({hasText:'Bank'}).click();
    await page.locator('.pump__can button').click();
    const last = await page.evaluate(() => window.testBridge.sent.filter(x=>x.name==='lightrp:ui:action').at(-1).payload);
    assert.equal(last.type,'fuel.jerrycan'); assert.equal(last.pay,'bank','bank payment without a nearby vehicle');
    await fire('dialog:close',{kind:'fuel'});
    for (const [width,height] of [[1280,720],[2560,1440]]) {
      await page.setViewportSize({width,height}); await fire('dialog',payload);
      const bounds = await page.locator('.pump').boundingBox(); assert(bounds.x>=0 && bounds.y>=0 && bounds.y+bounds.height<=height+1);
      await page.getByRole('button',{name:'Close pump'}).click();
    }
    assert.deepEqual(errors,[]);
    console.log('PASS fuel UI: compact panel, amounts, vehicle selection, engine guard, payments, duplicate submit, live refresh, handoff, responsive bounds');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1});
