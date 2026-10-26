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
    const bar=page.getByRole('status',{name:'Free camera'});
    assert.equal(await bar.count(),0,'nothing on screen while the player looks through their own eyes');

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

    // The reminder bar: the keys the player really has, the range, the readouts.
    const keys={toggle:'F6',forward:'forward',back:'back',left:'strafe_left',right:'strafe_right',up:'SPACE',down:'C',boost:'SHIFT',slow:'CTRL',reset:'R',hints:'H',exit:'BACKSPACE'};
    await fire('freecam',{active:true,phase:'preparing',hints:true,keys,radius:25,distance:0,speed:4,fov:60});
    await bar.waitFor();assert.match(await bar.innerText(),/Stepping out/);
    await fire('freecam',{active:true,phase:'active',hints:true,keys,radius:25,distance:8.4,speed:4.6,fov:52});
    const text=await bar.innerText();
    for(const expected of [/8\.4\s*\/ 25 M/,/4\.6\s*M\/S/,/52\s*° LENS/,/SPACE/,/SHIFT/,/CTRL/,/BKSP/,/F6/,/MOVE/i,/LEAVE/i,/HIDE KEYS/i]) assert.match(text,expected);
    const cross=(await bar.locator('.freecam__cross kbd').allInnerTexts()).join('');
    assert.ok(cross==='WASD'||cross==='ZQSD','layout aliases are shown as real keys: '+cross);
    assert.equal(await bar.locator('.freecam__range--ok').count(),1);
    const box=await bar.boundingBox();
    assert.ok(box.y+box.height<=1080&&box.y>800&&Math.abs(box.x+box.width/2-960)<2,'bottom centre of the screen');
    if(process.env.SHOT){await page.evaluate(()=>{document.body.style.background='linear-gradient(120deg,#39424a,#8d979d)'});await page.waitForTimeout(900);await page.screenshot({path:process.env.SHOT+'-bar.png'});}

    // Rebound keys are shown as bound; the gauge warns near and at the limit.
    await fire('freecam',{active:true,phase:'active',hints:true,keys:{...keys,forward:'UP',up:'E'},radius:25,distance:21,speed:4,fov:60});
    assert.equal((await bar.locator('.freecam__cross kbd').first().innerText()),'UP');
    assert.equal(await bar.locator('.freecam__range--near').count(),1);
    await fire('freecam',{active:true,phase:'active',hints:true,keys,radius:25,distance:25,speed:4,fov:60});
    assert.match(await bar.innerText(),/RANGE LIMIT/);
    if(process.env.SHOT){await page.waitForTimeout(500);await page.screenshot({path:process.env.SHOT+'-limit.png',clip:{x:400,y:880,width:1120,height:200}});}
    await fire('freecam',{active:true,phase:'active',paused:true,hints:true,keys,radius:25,distance:25,speed:4,fov:60});
    assert.match(await bar.innerText(),/Paused/);

    // Hidden reminder: a discreet tag that says how to bring it back; then gone with the camera.
    await fire('freecam',{active:true,phase:'active',hints:false,keys,radius:25,distance:3,speed:4,fov:60});
    assert.equal(await bar.locator('.freecam__keys').count(),0);
    assert.match(await bar.innerText(),/H/);
    await fire('freecam',{active:false});
    assert.equal(await bar.count(),0);
    assert.deepEqual(errors,[]);
    console.log('PASS: free camera menu row, reminder bar, layout keys, range gauge, pause, hidden reminder');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
