const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
   const handlers=new Map(),sent=[];
   const fire=(name,p)=>(handlers.get('lightrp:ui:'+name)||[]).forEach(fn=>fn(p));
   const character={registered:true,status:'active',step:'done',key:'default',playerId:1,accountName:'Test player',firstName:'Alex',lastName:'Morgan',origins:[],slots:[],appearanceRevision:2,welcomePending:false};
   const state={character,staff:{isStaff:true},online:[{id:1,name:'Alex Morgan'},{id:2,name:'Jamie Rivers'}]};
   let ticket=null,messages=[],scope='player',fail=false;
   const overview={players:[{id:2,account:'other-account',character:'default',name:'Jamie Rivers',accountName:'Jamie',status:'active',life:'alive',job:{name:'sanitation',label:'Sanitation',grade:0,gradeLabel:'Worker'},gang:{name:'none',label:'None',grade:0,gradeLabel:'None'},playtimeMs:10000}],staff:[{id:3,name:'Yuki'}],permissions:{view:true,reports:true,assign:true,audit:true,heal:true,credit:true,rename:true,job:true,noclip:true,advanced:true},jobs:[{name:'sanitation',label:'Sanitation',grades:[{value:0,label:'Worker'}]}],gangs:[{name:'none',label:'None',grades:[{value:0,label:'Citizen'}]}],database:true};
   const add=(body,role='staff',internal=false)=>{ticket.revision++;messages.push({id:messages.length+1,revision:ticket.revision,author:role==='staff'?'Yuki':'Alex Morgan',role,kind:internal?'note':'reply',body,internal,at:Date.now()});};
   window.fixture={sent,fire,ready:false,get ticket(){return ticket;},setScope(s){scope=s;fire('dialog',{kind:'support',scope:s});},fail(){fail=true;},claim(){ticket.assignee='Yuki';ticket.assigneeOnline=true;ticket.status='in_progress';ticket.assignedToMe=true;add('Case taken by Yuki.');fire('support',{kind:'changed',ticket:41});},resolve(){ticket.status='resolved';ticket.resolvedAt=Date.now();add('The elevator has been repaired.');fire('support',{kind:'changed',ticket:41});}};
   window.Open77={on:(name,fn)=>handlers.set(name,[...(handlers.get(name)||[]),fn]),ready(){},emit(name,p){
    sent.push({name,p});
    if(name==='lightrp:ui:ready'){window.fixture.ready=true;setTimeout(()=>{fire('state',state);fire('dialog',{kind:'support',scope,body:'A prefilled draft from the report command.'});},20);}
    if(name!=='lightrp:ui:support'||!p.request)return;
    setTimeout(()=>{
     if(fail&&p.operation==='mutate'){fail=false;fire('support',{kind:'response',request:p.request,ok:false,error:'Storage refused. Please retry.'});return;}
     let data;
     if(p.operation==='overview')data=overview;
     else if(p.operation==='list')data={tickets:ticket?[ticket]:[],page:1,pageSize:25,total:ticket?1:0,summary:{total:ticket?1:0,open:ticket?.status==='open'?1:0,progress:ticket?.status==='in_progress'?1:0,waiting:0,finished:0},categories:['help','player','bug','other'],maxOpen:3};
     else if(p.operation==='create'){
      ticket={id:41,subject:p.subject,category:p.category,status:'open',priority:'normal',reporter:'Alex Morgan',character:'default',reporterOnline:true,assigneeOnline:false,assignedToMe:false,revision:1,createdAt:Date.now(),updatedAt:Date.now(),unread:false};
      messages=[{id:1,revision:1,author:'Alex Morgan',role:'player',kind:'created',body:p.body,internal:false,at:Date.now()}];data={ticketId:41};
     }else if(p.operation==='detail')data={ticket,messages:messages.filter(m=>p.scope==='staff'||!m.internal),hasOlder:false,canManage:p.scope==='staff',canAssign:p.scope==='staff',canReopen:true};
     else if(p.operation==='read')data={read:true};
     else if(p.operation==='mutate'){
      add(p.body||p.action,p.scope==='staff'?'staff':'player',p.action==='note');
      if(p.action==='reopen')ticket.status='open';if(p.action==='resolve')ticket.status='resolved';if(p.action==='waiting')ticket.status='waiting_player';data={ticketId:41};
     }else if(p.operation==='player')data={...overview.players[0],firstName:'Jamie',lastName:'Rivers',birthDate:'2050-01-01',money:{cash:500,bank:1500,number:'111-222'},position:{x:1,y:2,z:3,bucket:0},history:[],canReturn:false};
     else if(p.operation==='adminAction')data={accepted:true,outcome:'success',message:'Action completed.'};
     else if(p.operation==='audit')data={entries:[{id:1,actor_name:'Yuki',target_name:'Jamie Rivers',action:'heal',reason:'Help after a collision',detail:'Action completed.',outcome:'success',at:Date.now()}],hasMore:false};
     fire('support',{kind:'response',request:p.request,ok:true,data});
    },30);
   }};
  });
  await page.goto(process.env.UI_URL||'http://127.0.0.1:5199');await page.waitForFunction(()=>window.fixture.ready);
  const root=page.locator('.rp-support'),menu=page.locator('.rp-support__menu');
  const choose=async(text,enter=true)=>{
   for(let i=0;i<70;i++){
    const selected=await menu.locator('.o77-rage__row--on .o77-rage__text').textContent();
    if(selected===text){if(enter)await page.keyboard.press('Enter');return;}
    await page.keyboard.press('ArrowDown');
   }
   throw Error('Menu row not found: '+text+'; '+await menu.innerText());
  };
  const inputMode=()=>page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.operation==='input').at(-1)?.p.mode);
  await root.waitFor();
  assert.equal(await page.getByLabel('What happened?').inputValue(),'A prefilled draft from the report command.');
  assert.equal(await inputMode(),'form');
  await page.getByRole('button',{name:'Cancel',exact:true}).click();
  assert.equal(await inputMode(),'menu');
  assert.equal(await page.locator('.rp-support__panel').count(),0,'root opens only a compact menu');
  await choose('New report');
  await page.getByLabel('Subject',{exact:true}).fill('Stuck in the elevator');await page.getByLabel('What happened?').fill('I cannot leave the elevator after using the call button.');
  await page.getByRole('button',{name:'Send report',exact:true}).click();
  await page.locator('.rp-support__record h2').filter({hasText:'Stuck in the elevator'}).waitFor();
  await page.evaluate(()=>window.fixture.claim());
  await page.locator('.rp-support__record dd').filter({hasText:'Yuki'}).waitFor();
  await choose('Reply to staff');assert.equal(await inputMode(),'form');
  await page.getByLabel('Message',{exact:true}).fill('I am still inside, thank you for taking the report.');
  // Arrow keys and Backspace edit text, without navigating the Rage menu behind it.
  await page.keyboard.press('ArrowLeft');await page.keyboard.press('Backspace');
  assert.equal(await page.locator('.rp-support__form h2').innerText(),'Reply');
  await page.getByLabel('Message',{exact:true}).fill('I am still inside, thank you for taking the report.');
  await page.evaluate(()=>window.fixture.fail());await page.getByRole('button',{name:'Send',exact:true}).click();
  await page.getByRole('alert').filter({hasText:'Storage refused'}).waitFor();assert.match(await page.getByLabel('Message',{exact:true}).inputValue(),/still inside/);
  await page.getByRole('button',{name:'Send',exact:true}).click();await page.locator('.rp-support__conversation article').filter({hasText:'I am still inside'}).waitFor();
  const retries=await page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.action==='reply'));assert.equal(retries.at(-1).p.mutation,retries.at(-2).p.mutation,'retry preserves mutation identity');
  assert.equal(await inputMode(),'menu');
  await page.evaluate(()=>window.fixture.resolve());await page.locator('.rp-support__badge').filter({hasText:'Resolved'}).waitFor();
  await choose('Reopen case');await page.getByLabel('Message',{exact:true}).fill('It happened again when I tried floor two.');await page.getByRole('button',{name:'Reopen case',exact:true}).click();
  await page.waitForFunction(()=>window.fixture.sent.some(x=>x.p?.action==='reopen'));
  await page.locator('.rp-support__form').waitFor({state:'detached'});
  assert(!await page.locator('.rp-support__conversation .is-private').count());
  await page.keyboard.press('Backspace');await page.keyboard.press('Backspace');
  assert.equal(await menu.locator('.o77-rage__title').innerText(),'LIGHT/RP');
  await page.evaluate(()=>window.fixture.setScope('staff'));
  await page.locator('.o77-rage__row:not(.o77-rage__row--disabled)').filter({hasText:'Citizens'}).waitFor();
  fs.mkdirSync('artifacts',{recursive:true});await page.screenshot({path:'artifacts/support-rage-root.png'});
  assert.equal(await page.locator('.rp-support__panel').count(),0);
  const bounds=await root.boundingBox();assert(bounds.width<=360&&bounds.height<650,'admin root stays compact');
  await choose('Reports');await page.locator('.o77-rage__text').filter({hasText:'#41'}).waitFor();
  await choose('#41 Stuck in the elevator');await page.locator('.rp-support__record h2').waitFor();
  await choose('Internal staff note');await page.getByLabel('Message',{exact:true}).fill('Staff-only investigation: <script>throw new Error("unsafe")</script>');
  await page.getByRole('button',{name:'Send',exact:true}).click();await page.locator('.rp-support__conversation .is-private').waitFor();
  await page.screenshot({path:'artifacts/support-rage-case.png'});
  for(const [width,height]of [[1920,1080],[1366,768],[2560,1080],[1024,768]]){
   await page.setViewportSize({width,height});const box=await root.boundingBox();
   assert(box.x>width*.15&&box.y>=0&&box.x+box.width<=width+1&&box.y+box.height<=height+1,'keeps the world visible at '+width);
   assert.equal(await page.evaluate(()=>document.elementFromPoint(100,Math.floor(innerHeight/2))?.closest('.rp-support')!==null),false,'no fullscreen input shield');
  }
  await choose('Reply to player');await page.getByLabel('Message',{exact:true}).fill('Draft to cancel');await page.keyboard.press('Escape');
  assert.equal(await inputMode(),'menu');assert.equal(await menu.locator('.o77-rage__title').innerText(),'CASE #41');
  await page.keyboard.press('Backspace');await page.keyboard.press('Backspace');
  await choose('Citizens');await choose('#2 Jamie Rivers');await page.locator('.rp-support__record h2').filter({hasText:'Jamie Rivers'}).waitFor();
  await page.setViewportSize({width:1920,height:1080});await page.screenshot({path:'artifacts/support-rage-profile.png'});
  await choose('Credit money');await page.getByLabel('Amount',{exact:true}).fill('250');await page.getByLabel('Reason for this intervention').fill('Restore payment after verified bug');
  const before=await page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.operation==='adminAction').length);
  await page.getByRole('button',{name:'Review intervention'}).click();await page.getByRole('alertdialog',{name:'Confirm staff intervention'}).waitFor();
  assert.equal(await page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.operation==='adminAction').length),before,'review cannot mutate');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Cancel','safe default focus');
  await page.getByRole('button',{name:'Confirm intervention'}).click();await page.getByRole('status').filter({hasText:'Action completed'}).waitFor();
  assert.equal(await page.evaluate(()=>window.fixture.sent.filter(x=>x.p?.operation==='adminAction').at(-1).p.account),'other-account');
  await page.keyboard.press('Backspace');assert.equal(await menu.locator('.o77-rage__row--on .o77-rage__text').textContent(),'#2 Jamie Rivers','back keeps selected citizen');
  await page.keyboard.press('Backspace');await choose('Staff history');await page.getByText('Help after a collision',{exact:true}).waitFor();
  await page.keyboard.press('Backspace');await page.keyboard.press('Escape');await root.waitFor({state:'detached'});assert.equal(await inputMode(),'closed');
  assert.deepEqual(errors,[]);console.log('PASS: compact Rage root/submenus, keyboard and back stack, preserved selection, menu/form input handoff, create/reply/reopen/private notes, retry identity, reviewed interventions, stable player target, history and four viewport layouts');
 }catch(e){fs.mkdirSync('artifacts',{recursive:true});const p=browser.contexts()[0]?.pages()[0];if(p)await p.screenshot({path:'artifacts/support-rage-failure.png'});throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
