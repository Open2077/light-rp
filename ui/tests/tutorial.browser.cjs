const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      const handlers = new Map();
      window.testBridge = {sent: [],ready: false,fire: (name,payload) => (handlers.get('lightrp:ui:'+name)||[]).forEach(fn=>fn(payload)),
        raw: (name,payload) => (handlers.get(name)||[]).forEach(fn=>fn(payload))};
      window.Open77 = {on:(name,fn)=>handlers.set(name,[...(handlers.get(name)||[]),fn]), emit:(name,payload)=>{
        window.testBridge.sent.push({name,payload});if(name.endsWith(':ready'))window.testBridge.ready=true;
      }, ready() {}};
    });
    await page.goto(process.env.UI_URL || 'http://127.0.0.1:5199');
    await page.waitForFunction(()=>window.testBridge.ready);
    const fire=(name,payload)=>page.evaluate(({name,payload})=>window.testBridge.fire(name,payload),{name,payload});
    const sent=()=>page.evaluate(()=>window.testBridge.sent.filter(x=>x.name==='lightrp:ui:tutorial').map(x=>x.payload.operation).filter(Boolean));
    const character={registered:true,status:'active',step:'done',key:'default',playerId:1,accountName:'Test',firstName:'Alex',lastName:'Morgan',origins:[],slots:[],appearanceRevision:2,welcomePending:false};
    let revision=1;
    const state=async(step,extra={})=>fire('state',{character,tutorial:{active:true,available:true,key:'default',step,revision:revision++,index:1,total:6,title:'First day',hint:'Follow the guide',contact:'Mara',...extra}});
    await state('intro');await fire('tutorial',{phase:'opening',keys:{menu:'F2',inventory:'B',interact:'G'}});
    await page.getByRole('dialog',{name:'Your first day'}).waitFor();
    await page.getByRole('button',{name:'Skip scene'}).click();
    assert.deepEqual(await sent(),['intro']);
    assert.equal(await page.getByRole('dialog').count(),1,'client click never completes the server step');
    await fire('tutorial',{phase:'confirming'});
    assert.match(await page.locator('.first-day__opening-foot').innerText(),/arrival to be confirmed/);
    assert.equal(await page.locator('.first-day__curtain.is-open').count(),1,'the completed shot does not put a black curtain back over the world');
    await fire('tutorial',{phase:'intro_retry'});
    await page.getByRole('button',{name:'Retry arrival'}).click();
    assert.deepEqual(await sent(),['intro','intro'],'recovery remains clickable even after the previous request was busy');
    await state('meet');await page.getByLabel('First day objective').waitFor();
    assert.equal(await page.getByRole('dialog').count(),0);
    await state('meet',{dialogue:'welcome',lines:['Welcome to the city.','Use your bag and meet the clerk.']});
    await page.getByRole('button',{name:'Go on',exact:true}).click();
    assert.match(await page.locator('.first-day__line').innerText(),/meet the clerk/);
    await page.getByRole('button',{name:'Show me around'}).click();
    await page.getByRole('button',{name:'Saving…'}).evaluate(el=>el.click());
    assert.equal((await sent()).filter(x=>x==='next').length,1,'no duplicate completion from a double click');
    await fire('result',{action:'tutorial.control',ok:false,text:'Walk back to Mara.'});
    await page.getByRole('alert').filter({hasText:'Walk back to Mara.'}).first().waitFor();
    await state('identity');
    assert.match(await page.locator('.first-day__objective').innerText(),/F2/,'effective key bindings are displayed');
    await fire('open',{toggleKey:'F2'});await page.getByText('PLAYER MENU',{exact:true}).waitFor();
    const closes=()=>page.evaluate(()=>window.testBridge.sent.filter(x=>x.name==='lightrp:ui:close').length);
    const closeCount=await closes();
    await page.keyboard.up('F2');assert.equal(await closes(),closeCount,'opening release does not close menu');
    await page.keyboard.press('F1');assert.equal(await closes(),closeCount,'obsolete binding does not close menu');
    await page.keyboard.press('Enter');
    await page.waitForFunction(()=>window.testBridge.sent.some(x=>x.payload?.operation==='identity'));
    await page.keyboard.down('F2');assert.equal(await closes(),closeCount,'held key cannot reopen menu');
    await page.keyboard.up('F2');assert.equal(await closes(),closeCount+1,'effective key closes once on release');
    await fire('closed',{});
    await state('inventory');assert.match(await page.locator('.first-day__objective').innerText(),/B · INVENTORY/);
    // The to-do list: key caps follow the player's bindings, the card sits on the right, a finished step is acknowledged.
    await state('shop',{title:'Your first purchase',index:4,total:10,objective:{position:{x:0,y:0,z:0},label:'Browse shop',radius:2.5,kind:'interact'},
      todo:[{text:'Follow the arrow to the vendor'},{key:'interact',text:'Open the shop'},{key:'inventory',text:'Check your bag'}]});
    assert.deepEqual(await page.locator('.first-day__key').allInnerTexts(),['G','B'],'key caps show the effective bindings');
    assert.equal(await page.locator('.first-day__todo li').count(),3);
    assert.equal(await page.locator('.first-day__steps li.is-done').count(),3);assert.equal(await page.locator('.first-day__steps li.is-now').count(),1);
    await page.locator('.first-day__done').filter({hasText:'First day'}).waitFor();
    // The way (client/core/tutorial_guide.lua): the card's line, the waypoint in view, the arrow on the ring out of view.
    const anchors=list=>page.evaluate(list=>window.testBridge.raw('open77:anchors',{anchors:list}),list);
    await fire('tutorialguide',{label:'Browse shop',distance:42,angle:30,rise:0});
    assert.match(await page.locator('.first-day__distance').innerText(),/42 m[\s\S]*Browse shop/);
    assert.equal(await page.locator('.fd-way__edge.is-shown').count(),1,'no anchor in view: the arrow on the ring');
    await anchors([{tag:'tutorial.guide',x:.4,y:.45,depth:30,onScreen:true}]);
    assert.equal(await page.locator('.fd-way__waypoint.is-shown').count(),1,'in view: the waypoint');
    assert.equal(await page.locator('.fd-way__edge.is-shown').count(),0);
    assert.match(await page.locator('.fd-way__waypoint').innerText(),/Browse shop[\s\S]*42 m/i);
    await anchors([{tag:'tutorial.guide',x:.4,y:.45,depth:-3,onScreen:false}]);
    assert.equal(await page.locator('.fd-way__edge.is-shown').count(),1,'behind the camera: the arrow again');
    await fire('tutorialguide',{label:'Browse shop',distance:2,angle:0});
    assert.equal(await page.locator('.is-shown').count(),0,'within reach the prompt takes over');
    await fire('tutorialguide',{label:'Browse shop',distance:42,angle:30});
    await fire('tutorialguide',{hide:true});assert.equal(await page.locator('.first-day__distance').count(),0);
    assert.equal(await page.locator('.fd-way__waypoint.is-shown, .fd-way__edge.is-shown').count(),0,'hidden by the client: nothing left on screen');
    await fire('tutorialguide',{label:'Browse shop',distance:42,angle:30});await page.waitForTimeout(4200);
    assert.equal(await page.locator('.fd-way__edge.is-shown').count(),0,'a client that stopped talking: the pointer goes by itself');
    assert.equal(await page.locator('.first-day__distance').count(),0);
    for(const [width,height] of [[1920,1080],[1366,768],[2560,1080],[1024,768]]) {
      await page.setViewportSize({width,height});
      const box=await page.locator('.first-day__objective').boundingBox();
      assert(box.x>width/2&&box.x+box.width<=width&&box.y>=0&&box.y+box.height<=height&&Math.abs(box.y+box.height/2-height/2)<3,'objective card sits middle right at '+width+' '+JSON.stringify(box));
    }
    await page.setViewportSize({width:1920,height:1080});
    await fire('tutorial',{options:true});
    await page.getByRole('button',{name:'Continue on my own'}).click();
    assert((await sent()).includes('pause'));
    await fire('state',{tutorial:{active:false,available:true,status:'paused',step:'inventory',key:'default',revision:revision++}});
    assert.equal(await page.locator('.first-day').count(),0);
    await fire('tutorial',{options:true});await page.getByRole('button',{name:'Resume guide'}).click();
    assert((await sent()).includes('resume'));
    await state('outro',{lines:['Your real work order is ready.','Welcome to Night City.']});
    await fire('dialog',{kind:'jobcenter',spot:{id:'citycenter',name:'Office'},jobs:[],paycheckMinutes:30});
    assert.equal(await page.locator('.first-day__conversation').count(),0,'the work desk retains its focus until closed');
    await page.keyboard.press('Escape');
    await page.getByRole('button',{name:'Go on',exact:true}).waitFor();
    for(const [width,height] of [[1920,1080],[1366,768],[2560,1080],[1024,768]]) {
      await page.setViewportSize({width,height});
      const box=await page.locator('.first-day__conversation').boundingBox();
      assert(box.x>=0&&box.y>=0&&box.x+box.width<=width+1&&box.y+box.height<=height+1,'dialogue fits '+width);
    }
    await page.getByRole('button',{name:'Go on',exact:true}).click();
    await page.getByRole('button',{name:'See you around, Mara'}).click();
    await state('bank',{dialogue:'bank',contact:'Idris',role:'NIGHT CITY BANK',guide:'Mara',action:'Understood',lines:['Your account is open.']});
    await page.getByRole('dialog',{name:'Conversation with Idris'}).waitFor();
    assert.match(await page.locator('.first-day__portrait').innerText(),/^I/,'the portrait is the contact of the step');
    await page.getByRole('button',{name:'Understood'}).click();
    assert.equal((await sent()).filter(x=>x==='next').length,2,'every contact of the hall moves on with the same request');
    assert((await sent()).includes('finish'));
    await fire('state',{tutorial:{active:false,available:true,status:'done'}});
    assert.equal(await page.locator('.first-day').count(),0);
    await fire('state',{character:{...character,status:'draft'},tutorial:{active:true,available:true,step:'intro'}});
    assert.equal(await page.locator('.first-day').count(),0,'slot creation cannot inherit tutorial overlays');
    assert.deepEqual(errors,[]);
    console.log('PASS: intro, dialogue, actual identity observation, remapped keys, duplicate/failure handling, pause/resume, dialog ownership, four viewports, authoritative completion, slot cleanup');
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
