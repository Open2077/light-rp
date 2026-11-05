// /admin > Events (ui/src/features/support/EventsTools.tsx) against a fixture of
// server/modules/staff_events.lua: the hub, the launch configurator and its review, a live
// event called off, a spot saved, an event night started, the random world bosses toggle.
// npm --prefix ui run dev -- --port 5199 --strictPort, then
// PLAYWRIGHT_MODULE=<playwright> node ui/tests/staff-events.browser.cjs
const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.BROWSER_CHANNEL||'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
   const handlers=new Map(),sent=[];
   const fire=(name,p)=>(handlers.get('lightrp:ui:'+name)||[]).forEach(fn=>fn(p));
   const character={registered:true,status:'active',step:'done',key:'default',playerId:1,accountName:'Test staff',firstName:'Yuki',lastName:'Sato',origins:[],slots:[],appearanceRevision:2,welcomePending:false};
   const state={character,staff:{isStaff:true},online:[{id:1,name:'Yuki Sato'},{id:2,name:'Jamie Rivers'}]};
   const job={name:'none',label:'None',grade:0,gradeLabel:'None'};
   const overview={players:[{id:2,account:'acc-2',character:'default',name:'Jamie Rivers',accountName:'Jamie',status:'active',life:'alive',job,gang:job,playtimeMs:1}],
    staff:[],permissions:{view:true,events:true,eventsPay:true},jobs:[],gangs:[],database:true};
   const view={live:[],bosses:[{id:'wb-1',title:'Burn Notice',location:'Kabuki'}],
    psychos:[{id:'psycho_kabuki',label:'Watson, Kabuki'},{id:'psycho_mox',label:'Northside (Mox, mantis blades)'}],
    crews:[{id:'sixthstreet',label:'6th Street'},{id:'maelstrom',label:'Maelstrom'}],
    levels:[{id:'normal',label:'Normal',blurb:'As designed.'},{id:'hard',label:'Hard',blurb:'Tougher.'},{id:'brutal',label:'Brutal',blurb:'For a full crew.'}],
    presets:[{id:'psycho_night',label:'Psycho Night',blurb:'Cyberpsychos one after another.',rounds:5,min:2},{id:'boss_rush',label:'Boss Rush',blurb:'Back to back.',rounds:4,min:1},
     {id:'gang_war',label:'Gang War',blurb:'Several gangs at once.',rounds:3,min:2},{id:'siege',label:'Siege',blurb:'Gang after gang.',rounds:3,min:2}],
    spots:[{id:'sp1',name:'Plaza',district:'Watson',by:'Yuki',distance:120}],night:null,maxLive:4,maxRounds:8,random:{enabled:true,nextInMs:600000},
    minutes:{default:15,min:5,max:60},radius:{default:50,min:25,max:150},canPay:true,inCity:true};
   let seq=0;
   window.fixture={sent,fire,ready:false,view};
   window.Open77={on:(name,fn)=>handlers.set(name,[...(handlers.get(name)||[]),fn]),ready(){},emit(name,p){
    sent.push({name,p});
    if(name==='lightrp:ui:ready'){window.fixture.ready=true;setTimeout(()=>{fire('state',state);fire('dialog',{kind:'support',scope:'staff'});},20);}
    if(name!=='lightrp:ui:support'||!p.request)return;
    setTimeout(()=>{
     let data,ok=true,error;
     if(p.operation==='overview')data=overview;
     else if(p.operation==='events')data=JSON.parse(JSON.stringify(view));
     else if(p.operation==='eventsAction'){
      const done=message=>({accepted:true,outcome:'success',message});
      if(p.action==='launch'){
       seq++;view.live.push({id:'worldboss:'+seq,kind:p.kind,title:'Cyberpsycho sighting',boss:p.name||'Static',location:p.location||'Night City',phase:'fight',health:100,fighters:0,enemies:1,endsInMs:600000,by:'P1',pay:p.pay===true,distance:12});
       data=done(`${p.name||'Static'} is out in ${p.location||'Night City'}.`);
      }else if(p.action==='stop'){view.live=view.live.filter(e=>e.id!==p.id);data=done('Called off: nobody is paid.');}
      else if(p.action==='spotSave'){view.spots.push({id:'sp'+(view.spots.length+1),name:p.name,district:'',by:'Yuki',distance:0});data=done(`Spot "${p.name}" saved.`);}
      else if(p.action==='night'){view.night={preset:p.preset,label:'Psycho Night',round:0,rounds:p.rounds,phase:'intro',nextInMs:30000,won:0,played:0,live:0,by:'P1'};data=done('Psycho Night announced: 5 round(s), the first in 30 s.');}
      else if(p.action==='random'){view.random.enabled=p.enabled;data=done(p.enabled?'Random world bosses are on.':'Random world bosses are off until the next restart.');}
      else if(p.action==='goto')data=done('Teleported.');
      else{ok=false;error='Unknown event action.';}
     }
     fire('support',{kind:'response',request:p.request,ok,data,error});
    },30);
   }};
  });
  await page.goto(process.env.UI_URL||'http://127.0.0.1:5199');await page.waitForFunction(()=>window.fixture.ready);
  const root=page.locator('.rp-support'),menu=page.locator('.rp-support__menu'),panel=page.locator('.rp-support__panel');
  const current=()=>menu.locator('.o77-rage__row--on .o77-rage__text').textContent();
  const choose=async(text,enter=true)=>{
   for(let i=0;i<70;i++){
    if(await current()===text){if(enter)await page.keyboard.press('Enter');return;}
    await page.keyboard.press('ArrowDown');
   }
   throw Error('Menu row not found: '+text+'; '+await menu.innerText());
  };
  const title=()=>menu.locator('.o77-rage__title').innerText();
  const actions=()=>page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.operation==='eventsAction').map(x=>x.p));
  await root.waitFor();
  await page.locator('.o77-rage__row:not(.o77-rage__row--disabled)').filter({hasText:'Events'}).waitFor();
  // /admin > Missions & events > Staff events (the unified admin menu)
  await choose('Missions & events');await choose('Staff events');
  await page.locator('.o77-rage__text').filter({hasText:'No world event out'}).waitFor();
  assert.equal(await title(),'EVENTS');
  // ── the launch configurator: every option moves the summary ──
  await choose('Launch an event');assert.equal(await title(),'LAUNCH AN EVENT');
  const summary=()=>panel.locator('.rp-support__record h2').innerText();
  assert.equal(await summary(),'Cyberpsycho: A random cyberpsycho');
  await choose('Event',false);await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>document.querySelector('.rp-support__panel .rp-support__record h2')?.textContent==='Gang attack: A random gang');
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>document.querySelector('.rp-support__panel .rp-support__record h2')?.textContent==='World boss: Burn Notice');
  assert.match(await panel.innerText(),/Where: Kabuki/,'a world boss starts at its own place');
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>document.querySelector('.rp-support__panel .rp-support__record h2')?.textContent==='Cyberpsycho: A random cyberpsycho');
  await choose('Cyberpsycho',false);await page.keyboard.press('ArrowRight');
  await page.waitForFunction(()=>document.querySelector('.rp-support__panel .rp-support__record h2')?.textContent==='Cyberpsycho: Watson, Kabuki');
  await choose('Where',false);await page.keyboard.press('ArrowRight');
  await page.locator('.rp-support__panel p').filter({hasText:'on #2 Jamie Rivers'}).waitFor();
  await choose('Level',false);await page.keyboard.press('ArrowRight');
  await page.locator('.rp-support__panel p').filter({hasText:'Level: Hard'}).waitFor();
  assert.match(await panel.innerText(),/For fun: nothing is paid or counted/);
  fs.mkdirSync('artifacts',{recursive:true});await page.screenshot({path:'artifacts/staff-events-launch.png'});
  await choose('Review and launch');
  await page.getByLabel('Place name the city is told').fill("Tom's Diner");await page.getByLabel('Boss name').fill('Static');
  await page.getByRole('button',{name:'Review',exact:true}).click();
  await page.getByRole('alertdialog',{name:'Confirm the event'}).waitFor();
  assert.equal((await actions()).length,0,'review cannot launch');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Cancel','safe default focus');
  await page.getByRole('button',{name:'Launch',exact:true}).click();
  await page.getByRole('status').filter({hasText:"Static is out in Tom's Diner."}).waitFor();
  const launch=(await actions()).at(-1);
  assert.deepEqual([launch.action,launch.kind,launch.where,launch.target,launch.enemy,launch.level,launch.pay,launch.silent,launch.confirmed,launch.location,launch.name],
   ['launch','psycho','player',2,'psycho_kabuki','hard',false,false,true,"Tom's Diner",'Static']);
  assert.equal(typeof launch.mutation,'string');
  assert.equal(await title(),'EVENTS','back to the hub');
  // ── the live event, called off ──
  await page.locator('.o77-rage__text').filter({hasText:"Static · Tom's Diner"}).waitFor();
  await choose("Static · Tom's Diner",false);await panel.locator('h2').filter({hasText:'Static'}).waitFor();
  await page.screenshot({path:'artifacts/staff-events-hub.png'});
  await choose("Static · Tom's Diner");assert.equal(await title(),'CYBERPSYCHO');
  await choose('Call it off');await page.getByLabel('Note for the staff history (optional)').fill('Test event');
  await page.getByRole('button',{name:'Review',exact:true}).click();await page.getByRole('button',{name:'Confirm',exact:true}).click();
  await page.getByRole('status').filter({hasText:'Called off'}).waitFor();
  assert.equal(await title(),'EVENTS');await page.locator('.o77-rage__text').filter({hasText:'No world event out'}).waitFor();
  const stop=(await actions()).at(-1);assert.equal(stop.action,'stop');assert.equal(stop.id,'worldboss:1');assert.equal(stop.reason,'Test event');
  // ── a spot saved here ──
  await choose('Saved spots');await choose('Save a spot here');
  await page.getByLabel('Spot name').fill('Market behind the clinic');
  await page.getByRole('button',{name:'Review',exact:true}).click();await page.getByRole('button',{name:'Save spot',exact:true}).click();
  await page.getByRole('status').filter({hasText:'saved'}).waitFor();
  await page.locator('.o77-rage__text').filter({hasText:'Market behind the clinic'}).waitFor();
  assert.equal(await title(),'SAVED SPOTS','a saved spot stays on the list');
  await page.keyboard.press('Backspace');
  // ── an event night ──
  await choose('Event nights');assert.equal(await title(),'EVENT NIGHTS');
  await panel.locator('h2').filter({hasText:'Psycho Night: 5 rounds'}).waitFor();
  await choose('Review and start');await page.getByRole('button',{name:'Review',exact:true}).click();
  await page.getByRole('button',{name:'Start the night',exact:true}).click();await page.getByRole('status').filter({hasText:'Psycho Night announced'}).waitFor();
  const night=(await actions()).at(-1);
  assert.deepEqual([night.action,night.preset,night.rounds,night.where,night.level,night.pay],['night','psycho_night',5,'spots','normal',false]);
  // ── random world bosses off ──
  await choose('Random world bosses');await page.getByRole('status').filter({hasText:'off until the next restart'}).waitFor();
  assert.equal((await actions()).at(-1).enabled,false);
  for(const [width,height]of [[1920,1080],[1366,768],[1024,768]]){
   await page.setViewportSize({width,height});const box=await root.boundingBox();
   assert(box.x+box.width<=width+1&&box.y+box.height<=height+1,'fits at '+width);
  }
  await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  assert.deepEqual(errors,[]);
  console.log('PASS: staff events desk (hub, launch configurator: kind / psycho / where / level move the summary, reviewed launch with its payload and mutation key, live event called off, spot saved, event night started, random world bosses off, three viewports)');
 }catch(e){fs.mkdirSync('artifacts',{recursive:true});const p=browser.contexts()[0]?.pages()[0];if(p)await p.screenshot({path:'artifacts/staff-events-failure.png'});throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
