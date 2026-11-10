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
  await fire(state);const ui=p.getByRole('dialog',{name:'AUTO STUDIO_'});await ui.waitFor();assert(await p.locator('.gameplay-interface').isHidden());
  // Camera framing presets follow the selected category: counted apart from the requests.
  const calls=()=>p.evaluate(()=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization'&&x.payload.command!=='preset').map(x=>x.payload));
  const presets=()=>p.evaluate(()=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization'&&x.payload.command==='preset').map(x=>x.payload.category));
  const untilCalls=async n=>{await p.waitForFunction(n=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization'&&x.payload.command!=='preset').length>=n,n);return(await calls()).at(-1);};
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
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);assert.equal((await calls()).at(-1).operation,'close');assert.equal(await p.locator('.gameplay-interface').getAttribute('hidden'),null);
  await fire(state);await ui.waitFor();await fire({kind:'closed',session:'stale'});assert.equal(await ui.count(),1);assert(await p.locator('.gameplay-interface').isHidden());await fire({kind:'closed',session:state.session});assert.equal(await ui.count(),0);
  await fire({kind:'unavailable',session:'failed',text:'Vehicle preview is unavailable.'});await p.waitForFunction(()=>testBridge.sent.some(x=>x.name==='lightrp:ui:notice:push'&&x.payload.kind==='error'&&x.payload.title==='Auto Studio'&&x.payload.body==='Vehicle preview is unavailable.'));assert.equal(await p.getByText('Vehicle preview is unavailable.',{exact:true}).count(),0,'the notice is handed to Lua, not drawn by the page');
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
  // The complete studio: ten categories in a compact grid, greyed ones selectable with their reason.
  await p.setViewportSize({width:1920,height:1080});
  const full={...state,session:'custom:full',price:2500,money:{cash:500,bank:100000,currency:'€$'},
   prices:{paint:2500,livery:4000,rims:6000,body:3500,neon:5000,lights:500,plate:2500},
   vehicle:{...state.vehicle,model:'hella',lightsHue:0.1,appearance:''},
   confirmed:{paint:original,lightsHue:0.1,appearance:'',profile:'',body:{},plate:'',stage:0},
   categories:[{id:'paint',label:'Body paint',description:'Primary and secondary colors',available:true},
    {id:'livery',label:'Livery',description:'Factory two-tone schemes',available:true,options:[{id:'tt_1',label:'Scheme 1',main:'#C81414',secondary:'#0A0A0A'},{id:'tt_2',label:'Scheme 2'}]},
    {id:'rims',label:'Rims',description:'Aftermarket wheels and finish',available:true,pack:'lightrp_vk_rims',options:[
     {id:'rim_classic',label:'Classic 10',variants:[{id:'chrome',label:'Chrome'},{id:'black',label:'Black'}]},{id:'rim_dish',label:'Deep dish',variants:[{id:'chrome',label:'Chrome'},{id:'black',label:'Black'}]}]},
    {id:'body',label:'Body kit',description:'Wings, lips, skirts, roof and bars',available:true,options:[
     {id:'spoiler',label:'Wing',parts:[{id:'wing_street',label:'Street wing',variants:[{id:'carbon',label:'Carbon'},{id:'white',label:'White'}]},{id:'wing_gt',label:'GT wing',variants:[{id:'carbon',label:'Carbon'}]}]},
     {id:'lip',label:'Front lip',parts:[{id:'lip_splitter',label:'Splitter',variants:[{id:'carbon',label:'Carbon'},{id:'black',label:'Black'}]}]}]},
    {id:'neon',label:'Neon',description:'Under-chassis lights',available:true,options:{colors:[{id:'cyan',label:'Cyan',color:'#00E5FF'},{id:'red',label:'Red',color:'#FF1E3C'}],
     intensities:[{id:'low',label:'Low',value:300},{id:'medium',label:'Medium',value:600},{id:'high',label:'High',value:1200}]}},
    {id:'lights',label:'Lights',description:'Headlight and lamp tint',available:true},
    {id:'trim',label:'Trim',description:'Factory variants of this model',available:false,reason:'No factory trim is offered for this model.'},
    {id:'plate',label:'Plate',description:'Registration number',available:true,options:{minLength:7,maxLength:7,charset:'A-Z0-9'}},
    {id:'windows',label:'Windows',description:'Window tint',available:false,soon:true,reason:'Coming soon.'},
    {id:'performance',label:'Performance',description:'Engine stages 1 to 3',available:true,options:{current:0,removal:1000,stages:[
     {stage:0,label:'Stock',record:'Vehicle.base',available:true},{stage:1,label:'Stage 1',price:2500,record:'Vehicle.base_o77s1',available:true},
     {stage:2,label:'Stage 2',price:3500,record:'Vehicle.base_o77s2',available:false,missing:true},{stage:3,label:'Stage 3',price:5000,record:'Vehicle.base_o77s3',available:true}]}}]};
  const fid=full.session,answer=(request,extra)=>fire({kind:'response',session:fid,request,nextRequest:request+1,ok:true,...extra});
  const view=(extra)=>({...full.confirmed,...extra}),rimHeld={rim:{id:'rim_dish',variant:'black'}};
  await fire(full);await ui.waitFor();
  assert.equal(await nav.getByRole('button').count(),10);
  assert(await p.locator('.workshop__categories--grid').isVisible(),'more than four categories: compact grid');
  base=(await calls()).length;
  // Greyed categories stay aria-disabled for assistive tech, yet a click opens them on their reason.
  await nav.getByRole('button',{name:/^Windows/}).click({force:true});
  await p.locator('.workshop__locked').getByText('Coming soon.',{exact:true}).waitFor();
  assert(await p.getByRole('button',{name:'Coming soon · —',exact:true}).isDisabled(),'nothing to buy on a greyed category');
  assert.equal(await nav.getByRole('button',{name:/^Windows/}).getAttribute('aria-disabled'),'true');
  await nav.getByRole('button',{name:/^Trim/}).click({force:true});
  await p.locator('.workshop__locked').getByText('No factory trim is offered for this model.',{exact:true}).waitFor();
  // Rims: rim then finish, framing preset, a warning from this game's client.
  await nav.getByRole('button',{name:/^Rims/}).click();
  await p.waitForFunction(()=>testBridge.sent.filter(x=>x.payload?.command==='preset').at(-1)?.payload.category==='rims');
  const rimsGroup=p.getByRole('group',{name:'Rims',exact:true});
  await rimsGroup.getByRole('button',{name:'Deep dish'}).click();
  sent=await untilCalls(base+1);assert.deepEqual([sent.operation,sent.category,sent.rim,sent.variant],['preview','rims','rim_dish','chrome']);
  await answer(1,{confirmed:view()});
  await p.getByRole('group',{name:'Rim finish'}).getByRole('button',{name:'Black'}).click();
  sent=await untilCalls(base+2);assert.equal(sent.variant,'black');await answer(2,{confirmed:view()});
  await fire({kind:'warning',session:fid,category:'rims',text:'These parts are invisible in your game: its parts pack is missing. Reconnect to download it.'});
  await p.getByRole('alert').filter({hasText:'invisible in your game'}).waitFor();
  const rimsButton=()=>p.getByRole('button',{name:'Apply rims · €$ 6,000',exact:true});
  await rimsButton().click();sent=await untilCalls(base+3);assert.deepEqual([sent.operation,sent.rim,sent.variant,sent.pay],['save','rim_dish','black','bank']);
  await answer(3,{operation:'save',text:'Rims purchased and saved to your vehicle.',money:{cash:500,bank:94000,currency:'€$'},confirmed:view(rimHeld)});
  await p.getByRole('status').filter({hasText:'Rims purchased'}).waitFor();assert(await rimsButton().isDisabled(),'confirmed rims are not sold twice');
  assert.equal(await p.getByRole('alert').count(),0,'a new rims answer clears the old warning');
  // Body kit: one part per group, priced per group changed.
  await nav.getByRole('button',{name:/^Body kit/}).click();
  await p.getByRole('group',{name:'Wing',exact:true}).getByRole('button',{name:'GT wing'}).click();
  sent=await untilCalls(base+4);assert.deepEqual(sent.parts,{spoiler:{part:'wing_gt',variant:'carbon'}});await answer(4,{confirmed:view(rimHeld)});
  await p.getByRole('group',{name:'Wing',exact:true}).getByRole('button',{name:'Street wing'}).click();
  sent=await untilCalls(base+5);assert.deepEqual(sent.parts,{spoiler:{part:'wing_street',variant:'carbon'}},'a second wing replaces the first');
  await answer(5,{confirmed:view(rimHeld)});
  await p.getByRole('button',{name:'Apply body kit · €$ 3,500',exact:true}).waitFor();
  await p.getByRole('group',{name:'Front lip',exact:true}).getByRole('button',{name:'Splitter'}).click();
  sent=await untilCalls(base+6);assert.deepEqual(sent.parts,{spoiler:{part:'wing_street',variant:'carbon'},lip:{part:'lip_splitter',variant:'carbon'}});
  await answer(6,{confirmed:view(rimHeld)});
  await p.getByRole('button',{name:'Apply body kit · €$ 7,000',exact:true}).waitFor();
  // Neon: presets, a colour too dark is never previewed, brightness steps, no neon.
  await nav.getByRole('button',{name:/^Neon/}).click();
  await p.getByRole('button',{name:'Neon Cyan',exact:true}).click();
  sent=await untilCalls(base+7);assert.deepEqual([sent.category,sent.color,sent.intensity],['neon','#00E5FF','medium']);await answer(7,{});
  await p.getByRole('textbox',{name:'Neon hex color'}).fill('#101010');
  await p.getByText('This color is too dark to light anything.',{exact:true}).waitFor();await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+7,'a colour too dark is never previewed');
  await p.getByRole('button',{name:'Neon Red',exact:true}).click();sent=await untilCalls(base+8);await answer(8,{});
  await p.getByRole('group',{name:'Neon brightness'}).getByRole('button',{name:'High'}).click();
  sent=await untilCalls(base+9);assert.deepEqual([sent.color,sent.intensity],['#FF1E3C','high']);await answer(9,{});
  await p.getByRole('button',{name:'Apply neon · €$ 5,000',exact:true}).waitFor();
  await p.getByRole('button',{name:'No neon',exact:true}).click();sent=await untilCalls(base+10);assert.equal(sent.stock,true);await answer(10,{});
  // Plate: normalised, previewed only once the format is met; the server answers availability.
  await nav.getByRole('button',{name:/^Plate/}).click();
  await p.getByRole('textbox',{name:'Plate number'}).fill('ab 12');await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+10,'an incomplete plate is not sent');
  await p.getByRole('textbox',{name:'Plate number'}).fill('abc 1234');
  sent=await untilCalls(base+11);assert.deepEqual([sent.operation,sent.category,sent.plate],['preview','plate','ABC1234']);
  await answer(11,{text:'This plate is available.'});await p.getByRole('status').filter({hasText:'This plate is available.'}).waitFor();
  await p.getByRole('button',{name:'Register plate · €$ 2,500',exact:true}).click();
  sent=await untilCalls(base+12);assert.deepEqual([sent.operation,sent.plate],['save','ABC1234']);
  await answer(12,{operation:'save',text:'Plate registered to your vehicle.',confirmed:view({...rimHeld,plate:'ABC1234'})});
  await p.locator('.workshop__header').getByText('ABC1234').waitFor();
  // Performance: no preview, a stage this game lacks is disabled, a removal fee going down.
  await nav.getByRole('button',{name:/^Performance/}).click();
  const stagesGroup=p.getByRole('group',{name:'Performance stages'});
  assert(await stagesGroup.getByRole('button',{name:/^Stage 2/}).isDisabled(),'a stage record missing in this game');
  await stagesGroup.getByRole('button',{name:/^Stage 3/}).click();await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+12,'a stage is never previewed');
  await p.getByRole('button',{name:'Fit stage · €$ 11,000',exact:true}).waitFor();
  await stagesGroup.getByRole('button',{name:/^Stage 1/}).click();
  await p.getByRole('button',{name:'Fit stage · €$ 2,500',exact:true}).click();
  sent=await untilCalls(base+13);assert.deepEqual([sent.operation,sent.category,sent.stage,sent.pay],['save','performance',1,'bank']);
  await answer(13,{operation:'save',text:'Stage fitted and saved to your vehicle.',confirmed:view({...rimHeld,plate:'ABC1234',stage:1})});
  await p.locator('.workshop__header').getByText('ABC1234 · STAGE 1').waitFor();
  await stagesGroup.getByRole('button',{name:/^Stock/}).click();await p.getByRole('button',{name:'Fit stage · €$ 1,000',exact:true}).waitFor();
  // Livery: a scheme goes on the factory paint layer, so the paint draft follows.
  await nav.getByRole('button',{name:/^Livery/}).click();
  await p.getByRole('group',{name:'Factory schemes'}).getByRole('button',{name:'Scheme 1'}).click();
  sent=await untilCalls(base+14);assert.deepEqual([sent.category,sent.profile],['livery','tt_1']);await answer(14,{});
  await nav.getByRole('button',{name:/^Body paint/}).click();
  assert.equal(await p.getByRole('button',{name:'Factory finish',exact:true}).getAttribute('aria-pressed'),'true','the car shows the factory layer under the scheme');
  const framed=await presets();
  for(const c of['windows','trim','rims','body','neon','plate','performance','livery','paint'])assert(framed.includes(c),'framing preset sent for '+c);
  await fire({kind:'camera',session:fid,rotating:false});await p.getByRole('button',{name:'Resume rotation',exact:true}).waitFor();
  for(const [width,height]of[[1920,1080],[1280,720],[800,600]]){
   await p.setViewportSize({width,height});await p.waitForTimeout(100);
   const boxes=await Promise.all(['.workshop__panel','.workshop__checkout','.workshop__camera','.workshop__categories','.workshop__editor'].map(s=>p.locator(s).boundingBox()));
   for(const box of boxes.slice(0,4))assert(box.x>=0&&box.y>=0&&box.x+box.width<=width&&box.y+box.height<=height,'ten categories fit at '+width);
   assert(boxes[3].y+boxes[3].height<=boxes[1].y,'the category grid stays above the checkout at '+width);
   assert(boxes[3].x>=boxes[0].x&&boxes[3].x+boxes[3].width<=boxes[0].x+boxes[0].width,'the category grid stays inside the panel at '+width);
   assert.deepEqual(await p.locator('.workshop__panel').evaluate(e=>[e.scrollLeft,e.scrollWidth<=e.clientWidth]),[0,true],'nothing widens the panel at '+width);
   assert(await nav.evaluate(e=>e.scrollWidth<=e.clientWidth),'long descriptions are cut, not widening the grid at '+width);
   assert(boxes[4].height>=40,`the editor keeps room at ${width}: ${JSON.stringify(boxes[4])}`);
   assert(!overlap(boxes[0],boxes[2]),'camera controls stay outside the left panel');
   await p.screenshot({path:path.join(output,`vehicle-customization-full-${width}.png`)});
  }
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);
  // Wave 2: sub-panels under neon and lights, the engine sound heard on request, stickers
  // within the decal budget the server reports, the tag. (Lua sends an empty list as {}.)
  const w2={...full,session:'custom:wave2',prices:{...full.prices,neonAnimation:2500,lightColors:1500,engineSound:6000,stickers:1500,tag:2000},
   confirmed:{...full.confirmed,neon:{color:'#3CFF6E',intensity:'medium'},engineSound:'',stickers:{}},
   categories:[...full.categories.slice(0,5),
    {id:'neonAnimation',parent:'neon',label:'Animation',description:'Pulse, strobe, chase, rainbow',available:true,options:{
     modes:[{id:'pulse',label:'Pulse',speed:true},{id:'strobe',label:'Strobe',speed:true},{id:'chase',label:'Chase',speed:true,color2:true},{id:'speed',label:'Follows speed'}],
     speeds:[{id:'slow',label:'Slow'},{id:'medium',label:'Medium'},{id:'fast',label:'Fast'}],colors:[{id:'cyan',label:'Cyan',color:'#00E5FF'},{id:'amber',label:'Amber',color:'#FFB000'}]}},
    full.categories[5],
    {id:'lightColors',parent:'lights',label:'Lamp colors',description:'Brake, reverse, blinkers, interior',available:true,options:{
     groups:[{id:'brake',label:'Brake lights',safety:true,refuse:['blue']},{id:'reverse',label:'Reverse lights',refuse:{}},{id:'blinkers',label:'Blinkers',safety:true,refuse:['red','blue']},{id:'interior',label:'Interior',refuse:{}}],
     presets:['#FF1E3C','#FFB000','#00E5FF','#2F6BFF'],minBrightness:0.35}},
    ...full.categories.slice(6,8),
    {id:'stickers',label:'Stickers',description:"Decals from the city's crews",available:true,options:{maxPerCar:12,budget:{base:0,maximum:12},stickers:[
     {id:'st.v1',label:'Valentinos I',group:'Valentinos',decals:1},{id:'st.v2',label:'Valentinos II',group:'Valentinos',decals:2},{id:'st.dealer',label:'Dealer stripe',group:'Dealer',decals:3}]}},
    {id:'tag',label:'Tag',description:'Your own painted text',available:true,options:{fonts:[{id:'marker',label:'Marker'},{id:'block',label:'Block'}],
     spots:[{id:'door_left',label:'Left door'},{id:'hood',label:'Hood'}],colors:['#F2F4FF','#FFCC00'],minLength:1,maxLength:12,charset:'A-Z a-z 0-9 space - . ! ? # &'}},
    ...full.categories.slice(8),
    {id:'engineSound',label:'Engine sound',description:'Engine and exhaust note',available:true,options:{preview:true,respawns:true,sounds:[{id:'s01',label:'Inline-six, rough'},{id:'s02',label:'V8, deep'}]}}]};
  const wid=w2.session,reply=(request,extra)=>fire({kind:'response',session:wid,request,nextRequest:request+1,ok:true,...extra});
  await p.setViewportSize({width:1920,height:1080});
  await fire(w2);await ui.waitFor();
  assert.equal(await nav.getByRole('button').count(),13,'sub-panels are listed under their parent, not in the nav');
  base=(await calls()).length;
  await nav.getByRole('button',{name:/^Neon/}).click();
  await p.getByRole('group',{name:'Neon panels'}).getByRole('button',{name:'Animation'}).click();
  assert.equal(await nav.getByRole('button',{name:/^Neon/}).getAttribute('aria-current'),'page','the parent stays current in the nav');
  await p.waitForFunction(()=>testBridge.sent.filter(x=>x.payload?.command==='preset').at(-1)?.payload.category==='neonAnimation');
  const modes=p.getByRole('group',{name:'Neon animations'});
  await modes.getByRole('button',{name:'Pulse'}).click();
  sent=await untilCalls(base+1);assert.deepEqual([sent.operation,sent.category,sent.mode,sent.speed,sent.color2],['preview','neonAnimation','pulse','medium',undefined]);await reply(1,{});
  await modes.getByRole('button',{name:'Chase'}).click();
  sent=await untilCalls(base+2);assert.deepEqual([sent.mode,sent.speed,sent.color2],['chase','medium','#00E5FF'],'a two-color mode gets a second color');await reply(2,{});
  await p.getByRole('group',{name:'Second color'}).getByRole('button',{name:'Second color Amber'}).click();
  sent=await untilCalls(base+3);assert.equal(sent.color2,'#FFB000');await reply(3,{});
  await p.screenshot({path:path.join(output,'vehicle-customization-wave2-animation.png')});
  await modes.getByRole('button',{name:'Follows speed'}).click();
  sent=await untilCalls(base+4);assert.deepEqual([sent.mode,sent.speed,sent.color2],['speed',undefined,undefined],'a reactive mode has no speed');await reply(4,{});
  assert.equal(await p.getByRole('group',{name:'Animation speed'}).count(),0);
  await p.getByRole('button',{name:'Apply animation · €$ 2,500',exact:true}).waitFor();
  // Lamp colors: the looks of an emergency vehicle are not offered.
  await nav.getByRole('button',{name:/^Lights/}).click();
  await p.getByRole('group',{name:'Lights panels'}).getByRole('button',{name:'Lamp colors'}).click();
  assert(await p.getByRole('group',{name:'Blinkers',exact:true}).getByRole('button',{name:'Blinkers #FF1E3C'}).isDisabled(),'no red blinkers');
  assert(await p.getByRole('group',{name:'Brake lights',exact:true}).getByRole('button',{name:'Brake lights #2F6BFF'}).isDisabled(),'no blue brake lights');
  await p.getByRole('group',{name:'Reverse lights',exact:true}).getByRole('button',{name:'Reverse lights #00E5FF'}).click();
  sent=await untilCalls(base+5);assert.deepEqual([sent.category,sent.lamps],['lightColors',{reverse:'#00E5FF'}]);await reply(5,{});
  await p.getByRole('button',{name:'Apply lamp colors · €$ 1,500',exact:true}).waitFor();
  await p.screenshot({path:path.join(output,'vehicle-customization-wave2-lamps.png')});
  // Engine sound: choosing rebuilds nothing; the car plays it on request.
  await nav.getByRole('button',{name:/^Engine sound/}).click();
  await p.getByRole('group',{name:'Engine sounds'}).getByRole('button',{name:/V8, deep/}).click();await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+5,'choosing a sound rebuilds nothing');
  await p.getByRole('button',{name:'Fit engine sound · €$ 6,000',exact:true}).waitFor();
  await p.getByRole('button',{name:'Hear it on the car',exact:true}).click();
  sent=await untilCalls(base+6);assert.deepEqual([sent.operation,sent.category,sent.sound],['preview','engineSound','s02']);await reply(6,{});
  assert(await p.getByRole('button',{name:'Hear it on the car',exact:true}).isDisabled(),'the car already plays it');
  // Stickers: per sticker added, within the budget the server reports (a livery preview changes it).
  await nav.getByRole('button',{name:/^Stickers/}).click();
  const meter=p.getByRole('meter',{name:'Decals'});assert.equal(await meter.getAttribute('aria-valuenow'),'0');
  const valentinos=p.getByRole('group',{name:'Valentinos',exact:true});
  await valentinos.getByRole('button',{name:/Valentinos I$/}).click();
  sent=await untilCalls(base+7);assert.deepEqual(sent.stickers,['st.v1']);await reply(7,{budget:{base:0,maximum:12}});
  await valentinos.getByRole('button',{name:/^Valentinos II/}).click();
  sent=await untilCalls(base+8);assert.deepEqual(sent.stickers,['st.v1','st.v2']);await reply(8,{budget:{base:0,maximum:12}});
  assert.equal(await meter.getAttribute('aria-valuenow'),'3');
  await p.getByRole('button',{name:'Apply stickers · €$ 3,000',exact:true}).waitFor();
  await nav.getByRole('button',{name:/^Livery/}).click();
  await p.getByRole('group',{name:'Factory schemes'}).getByRole('button',{name:'Scheme 2'}).click();
  sent=await untilCalls(base+9);assert.equal(sent.profile,'tt_2');await reply(9,{budget:{base:9,maximum:12}});
  await nav.getByRole('button',{name:/^Stickers/}).click();
  assert.equal(await meter.getAttribute('aria-valuenow'),'12','the livery preview takes its decals');
  await p.getByRole('group',{name:'Dealer',exact:true}).getByRole('button',{name:/^Dealer stripe/}).click();
  await p.getByText('Too many decals: 15 of 12. Remove a sticker.',{exact:true}).waitFor();await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+9,'over the budget, nothing is previewed');
  assert(await p.getByRole('button',{name:/^Apply stickers/}).isDisabled());
  await p.screenshot({path:path.join(output,'vehicle-customization-wave2-stickers.png')});
  await p.getByRole('group',{name:'Dealer',exact:true}).getByRole('button',{name:/^Dealer stripe/}).click();
  // Tag: spaces folded, the first font and spot by default, a character outside the set never sent.
  await nav.getByRole('button',{name:/^Tag/}).click();
  await p.getByRole('textbox',{name:'Tag text'}).fill('Night  Owl');
  sent=await untilCalls(base+10);assert.deepEqual([sent.category,sent.text,sent.font,sent.spot,sent.color],['tag','Night Owl','marker','door_left','#F2F4FF']);await reply(10,{});
  await p.getByRole('button',{name:'Paint tag · €$ 2,000',exact:true}).waitFor();
  await p.screenshot({path:path.join(output,'vehicle-customization-wave2-tag.png')});
  await p.getByRole('textbox',{name:'Tag text'}).fill('héllo');await p.waitForTimeout(400);
  assert.equal((await calls()).length,base+10,'a character outside the set is never sent');
  for(const [width,height]of[[1920,1080],[1280,720],[800,600]]){
   await p.setViewportSize({width,height});await p.waitForTimeout(100);
   const boxes=await Promise.all(['.workshop__panel','.workshop__checkout','.workshop__categories','.workshop__editor'].map(s=>p.locator(s).boundingBox()));
   for(const box of boxes.slice(0,3))assert(box.x>=0&&box.y>=0&&box.x+box.width<=width&&box.y+box.height<=height,'thirteen categories fit at '+width+': '+JSON.stringify(boxes));
   assert(boxes[2].y+boxes[2].height<=boxes[1].y,'the category grid stays above the checkout at '+width);
   assert(boxes[3].height>=40,`the editor keeps room at ${width}: ${JSON.stringify(boxes[3])}`);
   await p.screenshot({path:path.join(output,`vehicle-customization-wave2-${width}.png`)});
  }
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);
  // A stored stage the car does not run (its records were offline when it came out): the page
  // prices from the stored stage, as the server quotes, and never offers it again.
  const dormant={...full,session:'custom:dormant',confirmed:{...full.confirmed,stage:0,storedStage:1},
   categories:full.categories.map(c=>c.id==='performance'?{...c,options:{...c.options,current:1}}:c)};
  await fire(dormant);await ui.waitFor();
  await nav.getByRole('button',{name:/^Performance/}).click();
  const dormantStages=p.getByRole('group',{name:'Performance stages'});
  assert((await dormantStages.getByRole('button',{name:/^Stock/}).innerText()).includes('fitted'),'the car runs stock');
  assert((await dormantStages.getByRole('button',{name:/^Stage 1/}).innerText()).includes('paid, park the car to fit it'),'the stored stage is named');
  assert.equal(await dormantStages.getByRole('button',{name:/^Stage 1/}).getAttribute('aria-pressed'),'true','the stored stage is the confirmed choice');
  await dormantStages.getByRole('button',{name:/^Stage 3/}).click();
  await p.getByRole('button',{name:'Fit stage · €$ 8,500',exact:true}).waitFor(); // 3,500 + 5,000 from the stored Stage 1
  await dormantStages.getByRole('button',{name:/^Stage 1/}).click();
  assert(await p.getByRole('button',{name:/^Fit stage/}).isDisabled(),'the stored stage is not sold again');
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);
  assert.deepEqual(errors,[]);console.log('PASS: automatic/coalesced palette and HEX previews, quoted bank payment, balances, unchanged paint and insufficient cash guards, DB errors, stale acknowledgements, camera and restored left-panel layout and cinematic HUD cleanup; lights (presets, grey refusal, per-category drafts and purchase, factory lights), factory trim options and unsupported categories; full studio: compact grid, selectable locked categories, framing presets, rims and finish, exclusive body groups priced per group, neon presets/brightness/dark refusal, plate format and availability, stages without preview and removal fee, linked livery, client warnings, camera state and ten-category layout; wave 2: sub-panels, neon animation modes, lamp colors without emergency looks, engine sound on request, stickers within the decal budget, tag, thirteen-category layout; a dormant stored stage priced from like the server');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
