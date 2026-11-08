const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'E:/Open77/Gta2CPPuppet/node_modules/playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, reducedMotion: 'reduce' });
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.addInitScript(() => {
      const handlers=new Map();
      const state={available:true,configured:true,captureEnabled:true,inputDevice:'mic',outputDevice:'headset',inputs:[{id:'',name:'Default'},{id:'mic',name:'USB microphone'}],outputs:[{id:'',name:'Default'},{id:'headset',name:'USB headphones'}],inputVolume:1,outputVolume:1,activation:false,threshold:.25,key:'N',level:0,testing:false,signalDetected:false,distance:10,rangeKey:'F10'};
      const fire=(name,payload)=>(handlers.get('lightrp:ui:'+name)||[]).forEach(fn=>fn(payload));
      window.testBridge={sent:[],ready:false,fire,voice:state};
      window.Open77={on:(name,fn)=>handlers.set(name,[...(handlers.get(name)||[]),fn]),ready(){},emit:(name,payload)=>{
        window.testBridge.sent.push({name,payload});if(name.endsWith(':ready'))window.testBridge.ready=true;
        if(payload?.operation!=='voice')return;
        if(payload.action==='test')state.testing=payload.value;
        if(payload.action==='set'){
          const fields={InputDevice:'inputDevice',OutputDevice:'outputDevice',PushToTalkKey:'key'};
          if(fields[payload.name])state[fields[payload.name]]=payload.value;
          if(payload.name==='VoiceActivation')state.activation=payload.value===1;
          if(payload.name==='VoiceActivationThreshold')state.threshold=payload.value/100;
        }
        if(['begin','refresh','set','test'].includes(payload.action))queueMicrotask(()=>fire('tutorial',{voice:{...state},voiceError:''}));
      }};
      addEventListener('DOMContentLoaded',()=>{document.documentElement.style.background='#334239';});
    });
    await page.goto(process.env.UI_URL||'http://127.0.0.1:5199');await page.waitForFunction(()=>window.testBridge.ready);
    const fire=(name,payload)=>page.evaluate(({name,payload})=>window.testBridge.fire(name,payload),{name,payload});
    const character={registered:true,status:'active',step:'done',key:'default',playerId:1,accountName:'Test',firstName:'Alex',lastName:'Morgan',origins:[],slots:[],appearanceRevision:2,welcomePending:false};
    const guide=(step,extra={})=>fire('state',{character,tutorial:{active:true,available:true,key:'default',step,revision:1,index:2,total:13,title:'Find your voice',guide:'Mara',where:'lobby',...extra}});
    const shot=async name=>page.screenshot({path:path.resolve('../artifacts/tutorial-alt-voice/'+name+'.png')});
    const action=async name=>page.evaluate(name=>window.testBridge.sent.filter(x=>x.payload?.operation==='voice'&&x.payload?.action===name).length,name);
    await guide('voice');await page.getByRole('heading',{name:'Be heard. On your terms.'}).waitFor();
    assert(await action('begin'));assert.match(await page.locator('.voice-lesson__notice').innerText(),/already completed/);await shot('voice-choice');
    await page.getByRole('button',{name:'Set up my voice'}).click();
    await page.getByLabel('Microphone',{exact:true}).selectOption('');
    assert.equal(await page.getByLabel('Microphone',{exact:true}).inputValue(),'');
    await page.getByRole('button',{name:'Continue',exact:true}).click();
    await page.getByRole('button',{name:'Change push-to-talk button'}).click();await page.keyboard.press('Escape');
    assert.equal(await page.locator('.first-day__options').count(),0,'Escape while rebinding only cancels capture');
    for(const [button,key] of [[0,'MOUSE1'],[1,'MOUSE3'],[2,'MOUSE2'],[3,'MOUSE4'],[4,'MOUSE5']]){
      await page.getByRole('button',{name:'Change push-to-talk button'}).click();
      await page.locator('.voice-lesson__body h3').dispatchEvent('mousedown',{button});
      await page.waitForFunction(key=>window.testBridge.voice.key===key,key);
      await page.waitForTimeout(520);
    }
    await page.getByRole('button',{name:'Change push-to-talk button'}).click();await page.keyboard.press('KeyV');
    assert.equal(await page.getByRole('button',{name:'Change push-to-talk button'}).innerText(),'V');
    await shot('voice-binding');
    await page.getByRole('button',{name:'Voice activation',exact:false}).click();
    await page.getByRole('slider',{name:'Activation threshold'}).fill('40');
    await page.getByRole('button',{name:'Continue',exact:true}).click();
    assert(await page.getByRole('button',{name:'Save & continue'}).isDisabled(),'a fake confirmation cannot pass without a measured input');
    await page.getByRole('button',{name:'Start local test'}).click();
    await page.evaluate(()=>{window.testBridge.voice.level=.55;window.testBridge.voice.signalDetected=true;window.testBridge.fire('tutorial',{voice:{...window.testBridge.voice}});});
    // the meter renders on React's next pass, not inside the evaluate that fired the state: wait for it
    await page.waitForFunction(()=>document.querySelector('[role=meter]')?.getAttribute('aria-valuenow')==='55',null,{timeout:5000});
    assert.match(await page.locator('.voice-lesson__range').innerText(),/F10/,'the server range key is shown');
    await page.getByLabel('I can hear myself clearly, without echo or distortion.').check();
    assert(await page.getByRole('button',{name:'Save & continue'}).isEnabled());
    for(const [w,h] of [[1920,1080],[1366,768],[1024,768],[3440,1440]]){
      await page.setViewportSize({width:w,height:h});
      const b=await page.locator('.voice-lesson').boundingBox();assert(b.x>=0&&b.y>=0&&b.x+b.width<=w+1&&b.y+b.height<=h+1,`voice fits ${w}x${h}`);
      await page.getByRole('button',{name:'Save & continue'}).scrollIntoViewIfNeeded();await shot(`voice-test-${w}`);
    }
    await page.getByRole('button',{name:'Save & continue'}).click();assert.equal(await action('complete'),1);
    await guide('identity');assert(await action('end'),'leaving the step stops loopback');
    for(const button of ['My voice is already configured','Continue without voice setup']){
      await guide('voice');await page.getByRole('button',{name:button}).click();await guide('identity');
    }
    assert(await action('configured'));assert(await action('skip'));
    await guide('voice');await page.keyboard.press('Escape');await page.locator('.first-day__options').waitFor();assert(await action('end'));
    await page.getByRole('button',{name:'Continue guide'}).click();await page.getByRole('heading',{name:'Be heard. On your terms.'}).waitFor();
    await fire('tutorial',{voice:{...await page.evaluate(()=>window.testBridge.voice),available:false},voiceError:'Device disconnected'});
    await page.getByRole('button',{name:'Set up my voice'}).click();assert(await page.getByRole('button',{name:'Continue',exact:true}).isDisabled());assert.match(await page.locator('.voice-lesson').innerText(),/Device disconnected/);
    await guide('context_prop',{index:8,kind:'context',demo:'context',title:'Alt opens the world',todo:[{text:'Stand near the marked crate'},{key:'context',text:'Keep holding it; left-click the crate'},{text:'Click Inspect practice crate in the menu'}],line:'Keep Alt held while choosing. Releasing it or pressing Escape closes the menu. Objects, cars and people offer different actions.'});
    for(const [w,h] of [[1920,1080],[1366,768],[1024,768]]){
      await page.setViewportSize({width:w,height:h});const b=await page.locator('.first-day__objective').boundingBox();assert(b.y>=0&&b.y+b.height<=h+1,`context fits ${w}x${h}`);await shot(`context-prop-${w}`);
    }
    await guide('vehicle_open',{index:9,kind:'context',demo:'context',title:'Explore the submenus',todo:[{key:'context',text:'Hold and click the car again'},{text:'Open Trunk & hood → Open trunk'}]});
    assert.match(await page.locator('.context-lesson').innerText(),/TRUNK & HOOD[\s\S]*Open trunk/);await shot('context-car');
    assert.deepEqual(errors,[]);console.log('PASS: voice choices, devices, keyboard + five mouse binds, Escape cancellation, genuine meter gating, local test lifecycle, offline/skip/reopen, server range key, 4 viewports and Alt prop/car instructions');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1);});
