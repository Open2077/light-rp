const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const{chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const dist=path.resolve(__dirname,'../../resources/gamemodes/op77_lightrp/web');
const output=path.resolve(__dirname,'../artifacts');fs.mkdirSync(output,{recursive:true});
const state={kind:'open',session:'custom:browser',nextRequest:1,vehicle:{id:'12345678-owned',vehicleId:42,label:'Archer Hella',paint:{applied:true,primary:{r:17,g:17,b:20},secondary:{r:255,g:204,b:0}}},categories:[{id:'paint',label:'Body paint',description:'Primary and secondary colors'}]};
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
  await fire(state);const ui=p.getByRole('dialog',{name:'Make it yours.'});await ui.waitFor();
  assert.equal(await p.getByRole('navigation',{name:'Customization categories'}).getByRole('button').count(),1);
  await p.getByRole('button',{name:'Paint #FFCC00',exact:true}).click();
  const calls=()=>p.evaluate(()=>testBridge.sent.filter(x=>x.name==='lightrp:ui:customization').map(x=>x.payload));
  let sent=await calls();assert.deepEqual(sent.at(-1),{session:state.session,operation:'preview',request:1,category:'paint',primary:'#FFCC00',secondary:'#FFCC00',stock:false});
  assert(await p.getByRole('button',{name:'Save changes'}).count()===0);
  await fire({kind:'response',session:'stale',request:1,nextRequest:2,ok:true});assert(await p.getByRole('button',{name:'Synchronizing…'}).isDisabled());
  await fire({kind:'response',session:state.session,request:1,nextRequest:2,ok:true,text:'Preview applied.'});
  await p.getByRole('button',{name:'Secondary',exact:true}).click();await p.getByRole('textbox',{name:'Hex color'}).fill('#000000');
  await p.getByRole('button',{name:'Save changes',exact:true}).click();sent=await calls();assert.equal(sent.at(-1).request,2);assert.equal(sent.at(-1).secondary,'#000000');assert.equal(sent.at(-1).operation,'save');
  await fire({kind:'response',session:state.session,request:2,nextRequest:3,ok:false,text:'Paint could not be saved. Your previous finish is kept.'});await p.getByRole('status').filter({hasText:'Paint could not be saved'}).waitFor();
  await p.getByRole('button',{name:'Pause rotation',exact:true}).click();assert.deepEqual((await calls()).at(-1),{session:state.session,operation:'camera',command:'rotate',enabled:false});
  await p.getByRole('button',{name:'Rotate right',exact:true}).click();assert.equal((await calls()).at(-1).command,'right');
  await p.getByRole('textbox',{name:'Hex color'}).fill('broken');assert(await p.getByRole('button',{name:'Save changes',exact:true}).isDisabled());
  await p.getByRole('textbox',{name:'Hex color'}).fill('#000000');
  for(const [width,height]of[[1920,1080],[1280,720],[800,600]]){
   await p.setViewportSize({width,height});await p.waitForTimeout(100);
   const panel=await p.locator('.workshop__panel').boundingBox(),camera=await p.locator('.workshop__camera').boundingBox();
   assert(panel.x>=0&&panel.y>=0&&panel.x+panel.width<=width&&panel.y+panel.height<=height);
   assert(camera.x>=panel.x+panel.width&&camera.x+camera.width<=width&&camera.y+camera.height<=height);
   await p.screenshot({path:path.join(output,`vehicle-customization-${width}.png`)});
  }
  await p.keyboard.press('Escape');assert.equal(await ui.count(),0);assert.equal((await calls()).at(-1).operation,'close');
  await fire(state);await fire({kind:'closed',session:'stale'});assert.equal(await ui.count(),1);await fire({kind:'closed',session:state.session});assert.equal(await ui.count(),0);
  await fire({kind:'unavailable',session:'failed',text:'Vehicle preview is unavailable.'});await p.getByText('Vehicle preview is unavailable.',{exact:true}).waitFor();
  assert.deepEqual(errors,[]);console.log('PASS: customization categories, primary/secondary preview and save, stale acknowledgements, failure feedback, invalid HEX, camera requests, responsive layout and cleanup');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
