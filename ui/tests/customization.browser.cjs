const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const{chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const dist=path.resolve(__dirname,'../../resources/gamemodes/op77_lightrp/web');
const output=path.resolve(__dirname,'../artifacts');fs.mkdirSync(output,{recursive:true});
const state={kind:'open',session:'custom:browser',nextRequest:1,price:1000,money:{cash:500,bank:5000,currency:'€$'},vehicle:{id:'12345678-owned',vehicleId:42,label:'Archer Hella',paint:{applied:true,primary:{r:17,g:17,b:20},secondary:{r:255,g:204,b:0}}},categories:[{id:'paint',label:'Body paint',description:'Primary and secondary colors'}]};
(async()=>{
 const b=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{channel:'msedge'})});
 try{
  const p=await b.newPage({viewport:{width:1920,height:1080}}),errors=[];p.on('pageerror',e=>errors.push(String(e)));
  await p.route('http://customization.test/**',async route=>{
   const rel=new URL(route.request().url()).pathname.slice(1)||'index.html';
   const file=path.resolve(dist,rel);assert(file.startsWith(dist+path.sep));
   if(!fs.existsSync(file))return route.fulfill({status:404});
   const ext=path.extname(file);await route.fulfill({body:fs.readFileSync(file),contentType:{'.html':'text/html','.js':'application/javascript','.css':'text/css','.woff2':'font/woff2','.png':'image/png'}[ext]||'application/octet-stream'});
  });
  await p.addInitScript(()=>{
   const handlers={};window.testBridge={sent:[],ready:false,fire:(name,p)=>(handlers['lightrp:ui:'+name]||[]).forEach(f=>f(p))};
   window.Open77={on:(n,f)=>(handlers[n]??=[]).push(f),emit:(n,p)=>{testBridge.sent.push({name:n,payload:p});if(n.endsWith(':ready'))testBridge.ready=true;},ready(){}};
  });
  await p.goto('http://customization.test/');await p.waitForFunction(()=>testBridge.ready);
  const fire=(payload)=>p.evaluate(payload=>testBridge.fire('customization',payload),payload);
  await p.evaluate(()=>testBridge.fire('state',{character:{status:'active',registered:true,key:'default',step:'done',welcomePending:false,slots:[],origins:[]}}));
  await p.evaluate(()=>testBridge.fire('notice',{title:'Test notice',body:'Gameplay notification',durationMs:60000}));
  assert.equal(await p.locator('.gameplay-interface').getAttribute('hidden'),null);
  await fire({kind:'presentation',session:state.session});
  await p.waitForFunction(()=>document.querySelector('.gameplay-interface').hidden);
  await fire(state);const ui=p.getByRole('dialog',{name:'AUTO STUDIO_'});await ui.waitFor();assert(await p.locator('.gameplay-interface').isHidden());assert(await p.locator('.notices').isHidden());
  const calls=()=>p.evaluate(()=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization').map(x=>x.payload));
  const untilCalls=async n=>{await p.waitForFunction(n=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization').length>=n,n);return(await calls()).at(-1);};
  const payButton=()=>p.getByRole('button',{name:'Apply paint · €$ 1,000',exact:true});
  const original=state.vehicle.paint;
  const paid={applied:true,primary:{r:35,g:63,b:128},secondary:{r:0,g:0,b:0}};
  assert.equal(await p.getByRole('navigation',{name:'Customization categories'}).getByRole('button').count(),1);
  assert.equal(await p.getByRole('button',{name:/Preview color/}).count(),0);
  assert(await payButton().isDisabled(),'unchanged paint cannot be purchased');
  await p.getByRole('button',{name:'Paint #FFCC00',exact:true}).click();
  let sent=await untilCalls(1);assert.equal(sent.operation,'preview');assert.equal(sent.primary,'#FFCC00');
  await p.getByRole('button',{name:'Paint #AA172C',exact:true}).click();
  await p.getByRole('button',{name:'Paint #233F80',exact:true}).click();
  assert.equal((await calls()).length,1,'rapid clicks queue the latest preview without concurrent requests');
  await fire({kind:'response',session:'stale',request:1,nextRequest:2,ok:true});assert(await payButton().isDisabled());
  await fire({kind:'response',session:state.session,request:1,nextRequest:2,ok:true,paint:original});
  sent=await untilCalls(2);assert.equal(sent.request,2);assert.equal(sent.primary,'#233F80');
  await fire({kind:'response',session:state.session,request:2,nextRequest:3,ok:true,paint:original});
  await p.getByRole('button',{name:'Secondary',exact:true}).click();
  await p.getByRole('textbox',{name:'Hex color'}).fill('#000000');
  sent=await untilCalls(3);assert.equal(sent.operation,'preview');assert.equal(sent.secondary,'#000000');
  await fire({kind:'response',session:state.session,request:3,nextRequest:4,ok:true,paint:original});
  await payButton().click();sent=await untilCalls(4);assert.equal(sent.operation,'save');assert.equal(sent.pay,'bank');assert(!('price'in sent));
  assert(await p.getByRole('button',{name:'Processing payment…'}).isDisabled());assert(await p.getByRole('textbox',{name:'Hex color'}).isDisabled());
  await fire({kind:'response',session:state.session,request:4,nextRequest:5,operation:'save',ok:true,text:'Paint purchased and saved to your vehicle.',paint:paid,money:{cash:500,bank:4000,currency:'€$'}});
  await p.getByRole('status').filter({hasText:'Paint purchased'}).waitFor();assert(await payButton().isDisabled());
  assert((await p.getByRole('button',{name:/Bank/}).innerText()).includes('4,000'),'balance updated after payment');
  const overlap=(a,b)=>a.x<b.x+b.width&&a.x+a.width>b.x&&a.y<b.y+b.height&&a.y+a.height>b.y;
  for(const [width,height]of[[1920,1080],[1280,720],[800,600]]){
   await p.setViewportSize({width,height});await p.waitForTimeout(100);
   const boxes=await Promise.all(['.workshop__panel','.workshop__checkout','.workshop__camera'].map(s=>p.locator(s).boundingBox()));
   for(const box of boxes)assert(box.x>=0&&box.y>=0&&box.x+box.width<=width&&box.y+box.height<=height);
   assert(boxes[1].x>=boxes[0].x&&boxes[1].x+boxes[1].width<=boxes[0].x+boxes[0].width,'payment stays inside the original left panel');
   assert(!overlap(boxes[0],boxes[2]),'camera controls stay outside the left panel');
   await p.screenshot({path:path.join(output,`vehicle-customization-${width}.png`)});
  }
  await p.getByRole('button',{name:'Pause rotation',exact:true}).click();assert.equal((await calls()).at(-1).command,'rotate');
  await p.getByRole('button',{name:'Rotate right',exact:true}).click();assert.equal((await calls()).at(-1).command,'right');
  await p.getByRole('button',{name:/Cash/}).click();
  await p.getByRole('textbox',{name:'Hex color'}).fill('broken');assert(await payButton().isDisabled());
  const count=(await calls()).length;
  await p.getByRole('textbox',{name:'Hex color'}).fill('#38B8CB');
  sent=await untilCalls(count+1);assert.equal(sent.operation,'preview');
  await fire({kind:'response',session:state.session,request:5,nextRequest:6,ok:true,paint:paid});
  assert(await payButton().isDisabled());await p.getByText('Not enough cash.',{exact:true}).waitFor();
  await p.getByRole('button',{name:/Bank/}).click();await payButton().click();
  sent=await untilCalls(count+2);assert.equal(sent.request,6);assert.equal(sent.operation,'save');
  await fire({kind:'response',session:state.session,request:6,nextRequest:7,ok:false,paint:paid,text:'The database is unavailable. No money was moved.'});
  await p.getByRole('status').filter({hasText:'No money was moved'}).waitFor();
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);assert.equal((await calls()).at(-1).operation,'close');assert.equal(await p.locator('.gameplay-interface').getAttribute('hidden'),null);assert(await p.locator('.notices').isVisible());
  await fire(state);await ui.waitFor();await fire({kind:'closed',session:'stale'});assert.equal(await ui.count(),1);assert(await p.locator('.gameplay-interface').isHidden());await fire({kind:'closed',session:state.session});assert.equal(await ui.count(),0);
  await fire({kind:'unavailable',session:'failed',text:'Vehicle preview is unavailable.'});await p.getByText('Vehicle preview is unavailable.',{exact:true}).waitFor();
  // Lights and factory trim: per-category drafts, prices, payloads and confirmations.
  const studio={...state,session:'custom:categories',price:2500,prices:{paint:2500,lights:500,trim:2500},
   vehicle:{...state.vehicle,model:'hella',lightsHue:0.1,appearance:''},
   categories:[{id:'paint',label:'Body paint',description:'Primary and secondary colors',available:true,price:2500},
    {id:'lights',label:'Lights',description:'Headlight and lamp tint',available:true,price:500},
    {id:'trim',label:'Trim',description:'Factory variants of this model',available:true,price:2500,options:[{id:'hella_trim_a',label:'Street'},{id:'hella_trim_b',label:'Sport'}]}]};
  const sid=studio.session,respond=(request,extra)=>fire({kind:'response',session:sid,request,nextRequest:request+1,ok:true,...extra});
  await fire(studio);await ui.waitFor();
  const nav=p.getByRole('navigation',{name:'Customization categories'});
  assert.equal(await nav.getByRole('button').count(),3);
  let base=(await calls()).length;
  await nav.getByRole('button',{name:/^Lights/}).click();
  const lightsButton=()=>p.getByRole('button',{name:'Apply lights · €$ 500',exact:true});
  assert(await lightsButton().isDisabled(),'unchanged lights cannot be purchased');
  await p.getByRole('button',{name:'Light #00D8FF',exact:true}).click();
  sent=await untilCalls(base+1);assert.deepEqual([sent.operation,sent.category,sent.color,sent.stock,sent.request],['preview','lights','#00D8FF',false,1]);
  assert(!('primary'in sent)&&!('trim'in sent),'a lights request carries no other category');
  await respond(1,{confirmed:{paint:original,lightsHue:0.1,appearance:''}});
  await p.getByRole('textbox',{name:'Light hex color'}).fill('#808080');
  await p.getByText('Pick a more saturated color: a grey has no hue.',{exact:true}).waitFor();
  assert(await lightsButton().isDisabled());await p.waitForTimeout(400);assert.equal((await calls()).length,base+1,'a grey is never previewed');
  await p.getByRole('button',{name:'Light #FF1E3C',exact:true}).click();
  sent=await untilCalls(base+2);assert.equal(sent.color,'#FF1E3C');await respond(2,{confirmed:{paint:original,lightsHue:0.1,appearance:''}});
  // Paint previews in between keep the lights draft; the purchase is per category.
  await nav.getByRole('button',{name:/^Body paint/}).click();
  await p.getByRole('button',{name:'Paint #28705A',exact:true}).click();
  sent=await untilCalls(base+3);assert.equal(sent.category,'paint');await respond(3,{confirmed:{paint:original,lightsHue:0.1,appearance:''}});
  await nav.getByRole('button',{name:/^Lights/}).click();
  assert.equal(await p.getByRole('textbox',{name:'Light hex color'}).inputValue(),'#FF1E3C','the lights draft survives a category switch');
  await lightsButton().click();
  sent=await untilCalls(base+4);assert.deepEqual([sent.operation,sent.category,sent.color,sent.pay],['save','lights','#FF1E3C','bank']);
  await respond(4,{operation:'save',category:'lights',text:'Light tint purchased and saved to your vehicle.',money:{cash:500,bank:4500,currency:'€$'},
   confirmed:{paint:original,lightsHue:352/360,appearance:''}});
  await p.getByRole('status').filter({hasText:'Light tint purchased'}).waitFor();
  assert(await lightsButton().isDisabled(),'the confirmed hue is not sold again');
  for(const [width,height]of[[1920,1080],[1280,720],[800,600]]){
   await p.setViewportSize({width,height});await p.waitForTimeout(100);
   const boxes=await Promise.all(['.workshop__panel','.workshop__checkout','.workshop__camera','.workshop__categories'].map(s=>p.locator(s).boundingBox()));
   for(const box of boxes)assert(box.x>=0&&box.y>=0&&box.x+box.width<=width&&box.y+box.height<=height,'three categories fit at '+width);
   assert(!overlap(boxes[0],boxes[2]),'camera controls stay outside the left panel');
   await p.screenshot({path:path.join(output,`vehicle-customization-lights-${width}.png`)});
  }
  await p.getByRole('button',{name:'Factory lights',exact:true}).click();
  sent=await untilCalls(base+5);assert.equal(sent.stock,true);await respond(5,{confirmed:{paint:original,lightsHue:352/360,appearance:''}});
  // Trim: only the listed options, Factory trim sends stock without a name.
  await nav.getByRole('button',{name:/^Trim/}).click();
  const trims=p.getByRole('group',{name:'Factory trims'});
  assert.equal(await trims.getByRole('button').count(),3);
  const trimButton=()=>p.getByRole('button',{name:'Apply trim · €$ 2,500',exact:true});
  assert(await trimButton().isDisabled());
  await trims.getByRole('button',{name:'Sport'}).click();
  sent=await untilCalls(base+6);assert.deepEqual([sent.category,sent.trim,sent.operation],['trim','hella_trim_b','preview']);
  await respond(6,{confirmed:{paint:original,lightsHue:352/360,appearance:''}});
  await trimButton().click();sent=await untilCalls(base+7);assert.deepEqual([sent.operation,sent.trim,sent.pay],['save','hella_trim_b','bank']);
  await respond(7,{operation:'save',text:'Trim purchased and saved to your vehicle.',money:{cash:500,bank:2000,currency:'€$'},confirmed:{paint:original,lightsHue:352/360,appearance:'hella_trim_b'}});
  await p.getByRole('status').filter({hasText:'Trim purchased'}).waitFor();assert(await trimButton().isDisabled());
  await trims.getByRole('button',{name:'Factory trim'}).click();
  sent=await untilCalls(base+8);assert.equal(sent.stock,true);assert(!('trim'in sent),'factory trim names no variant');
  await respond(8,{confirmed:{paint:original,lightsHue:352/360,appearance:'hella_trim_b'}});
  await p.screenshot({path:path.join(output,'vehicle-customization-trim.png')});
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);assert.equal((await calls()).at(-1).operation,'close');
  // A category the server marks unsupported is greyed with its reason; the first usable one opens.
  await fire({...studio,session:'custom:unsupported',categories:[{...studio.categories[0],available:false,reason:'This model has no custom paint layer.'},studio.categories[1]]});
  await ui.waitFor();
  assert(await nav.getByRole('button',{name:/^Body paint/}).isDisabled());
  await nav.getByText('This model has no custom paint layer.',{exact:true}).waitFor();
  assert.equal(await lightsButton().count(),1,'the lights editor opens instead');
  await p.screenshot({path:path.join(output,'vehicle-customization-unsupported.png')});
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);
  assert.deepEqual(errors,[]);console.log('PASS: automatic/coalesced palette and HEX previews, quoted bank payment, balances, unchanged paint and insufficient cash guards, DB errors, stale acknowledgements, camera and restored left-panel layout and cinematic HUD cleanup; lights (presets, grey refusal, per-category drafts and purchase, factory lights), factory trim options and unsupported categories');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
