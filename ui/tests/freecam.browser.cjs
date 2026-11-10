const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = {sent: [],ready: false,fire: (name,payload) => (handlers.get('lightrp:ui:'+name)||[]).forEach(fn=>fn(payload))};
      window.Open77 = {on:(name,fn)=>handlers.set(name,[...(handlers.get(name)||[]),fn]), emit:(name,payload)=>{
        window.testBridge.sent.push({name,payload});if(name.endsWith(':ready'))window.testBridge.ready=true;
      }, ready() {}};
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5199');
    await page.waitForFunction(()=>window.testBridge.ready);
    const fire=(name,payload)=>page.evaluate(({name,payload})=>window.testBridge.fire(name,payload),{name,payload});
    const sent=name=>page.evaluate(name=>window.testBridge.sent.filter(x=>x.name==='lightrp:ui:'+name).map(x=>x.payload),name);
    const character={registered:true,status:'active',step:'done',key:'default',playerId:1,accountName:'Test',firstName:'Alex',lastName:'Morgan',origins:[],slots:[],appearanceRevision:2,welcomePending:false};
    await fire('state',{character});
    // The player menu lists it with its key and asks Lua to toggle it.
    await fire('open',{toggleKey:'F1',freecamKey:'f6'});
    const row=page.locator('.player-menu').getByText('Free camera',{exact:true});
    await row.waitFor();
    assert.match(await page.locator('.player-menu').innerText(),/F6/,'the effective key is shown on the row');
    for(let i=0;i<8&&!(await page.locator('.player-menu .o77-rage__row--on').filter({hasText:'Free camera'}).count());i++) await page.keyboard.press('ArrowDown');
    await page.keyboard.press('Enter');
    assert.deepEqual(await sent('freecam'),[{operation:'toggle'}]);
    assert.equal((await sent('close')).length,1,'the menu gives the keyboard back first');
    await fire('closed',{});

    // The reminder bar is a NativeUI document (client/native/toolbars.lua): the page draws nothing for the camera.
    await fire('freecam',{active:true,phase:'active',hints:true,keys:{toggle:'F6'},radius:25,distance:8.4,speed:4.6,fov:52});
    assert.equal(await page.getByRole('status',{name:'Free camera'}).count(),0);
    assert.deepEqual(errors,[]);
    console.log('PASS: free camera menu row; no bar in the page');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
