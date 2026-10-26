const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(process.env.UI_DIST || '../resources/gamemodes/op77_lightrp/web');
const output = path.resolve('artifacts'); fs.mkdirSync(output, { recursive: true });
const stock = [
  ['maimai','Makigai MaiMai','Street',4000], ['apollo','Brennan Apollo','Bikes',5000],
  ['galena','Thorton Galena','Street',6500], ['hella','Archer Hella','Street',10000],
  ['colby','Thorton Colby','Street',12000], ['supron','Mahir Supron','Utility',14000],
  ['quartz','Archer Quartz','Street',16000], ['cortes','Villefort Cortes','Street',28000],
  ['kusanagi','Yaiba Kusanagi','Bikes',45000], ['semimaru','Yaiba Semimaru','Sport',60000],
].map(([key,label,category,price]) => ({key,label,category,price,description:'A small footprint. A big city. Your first set of keys.'}));
const dealer = {kind:'dealership',session:'test-dealer',nextRequest:1,
  dealer:{id:'citycenter',name:'City Motors',subtitle:'Your next chapter starts here.'},
  garage:{id:'citycenter',name:'City Center // Public Garage'},stock,money:{cash:5200,bank:48000,currency:'€$'}};
const garage = {kind:'garage',session:'test-garage',nextRequest:1,maxOutside:1,
  spot:{id:'citycenter',name:'City Center // Public Garage'},vehicles:stock.slice(0,3).map((v,i)=>({...v,
    id:`owned-${i}`,status:'stored',garageId:'citycenter',garageName:'City Center // Public Garage',health:.85,canRetrieve:true,canStore:false}))};
(async()=>{
  const browser = await chromium.launch({headless:true,channel:'msedge'});
  try {
    const page = await browser.newPage({viewport:{width:1920,height:1080}});
    const errors=[]; page.on('pageerror',error=>errors.push(error.message));
    await page.route('http://vehicles.test/**',route=>{
      const url=new URL(route.request().url());const file=path.resolve(root,'.'+(url.pathname==='/'?'/index.html':url.pathname));
      if(!file.startsWith(root+path.sep)||!fs.existsSync(file))return route.fulfill({status:404});
      const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.jpg':'image/jpeg','.png':'image/png','.woff2':'font/woff2'};
      return route.fulfill({body:fs.readFileSync(file),contentType:mime[path.extname(file)]||'application/octet-stream'});
    });
    await page.addInitScript(()=>{
      const handlers={};window.testBridge={sent:[],ready:false,fire:(n,p)=>(handlers['lightrp:ui:'+n]||[]).forEach(f=>f(p))};
      window.Open77={on:(n,f)=>(handlers[n]??=[]).push(f),emit:(n,p)=>{window.testBridge.sent.push({name:n,payload:p});if(n.endsWith(':ready'))window.testBridge.ready=true;},ready(){}};
    });
    await page.goto('http://vehicles.test/');await page.waitForFunction(()=>window.testBridge.ready);
    const fire=(name,payload)=>page.evaluate(({name,payload})=>window.testBridge.fire(name,payload),{name,payload});
    const actions=()=>page.evaluate(()=>window.testBridge.sent.filter(e=>e.name==='lightrp:ui:action').map(e=>e.payload));
    await fire('state',{character:{status:'active',registered:true,key:'default',step:'done',welcomePending:false,slots:[],origins:[]}});
    await fire('dialog',dealer);await page.locator('.dealership').waitFor();
    await page.waitForFunction(()=>[...document.querySelectorAll('.dealer-car img')].every(img=>img.complete&&img.naturalWidth>0));
    assert.equal(await page.locator('.dealer-car').count(),10);
    await page.getByRole('button',{name:'Select Yaiba Semimaru',exact:true}).click();
    assert(await page.getByRole('button',{name:'Review purchase',exact:true}).isDisabled());
    await page.getByRole('button',{name:'Select Makigai MaiMai',exact:true}).click();
    for(const [width,height] of [[1920,1080],[1280,720],[800,600]]) {
      await page.setViewportSize({width,height});
      assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'no page overflow');
      await page.getByRole('button',{name:'Review purchase',exact:true}).scrollIntoViewIfNeeded();
      await page.screenshot({path:path.join(output,`dealer-${width}.png`),animations:'disabled'});
    }
    await page.setViewportSize({width:1920,height:1080});
    await page.getByRole('button',{name:'Review purchase',exact:true}).click();assert.equal((await actions()).length,0);
    await page.getByRole('button',{name:/^Confirm purchase/}).click();
    await page.locator('.dealer__primary').evaluate(el=>{el.click();el.click()});
    assert.deepEqual(await actions(),[{type:'dealership.buy',session:'test-dealer',request:1,key:'maimai',pay:'bank'}]);
    await fire('dealership',{session:'other',request:1,ok:true});assert(await page.getByRole('button',{name:'Processing purchase…'}).isDisabled());
    await fire('dealership',{session:dealer.session,request:1,ok:true,text:'Vehicle ready at the garage.',vehicleId:'owned-0',state:{...dealer,nextRequest:2,money:{...dealer.money,bank:44000}}});
    await page.getByRole('heading',{name:'The keys are yours.'}).waitFor();
    await page.getByRole('button',{name:'Head to the garage'}).click();assert.equal(await page.locator('.dealership').count(),0);
    await fire('dialog',garage);await page.locator('.garage').waitFor();
    await page.getByRole('button',{name:'Retrieve vehicle',exact:true}).click();
    assert.equal((await actions()).filter(a=>a.type==='garage.retrieve').length,1);
    const out={...garage,nextRequest:2,vehicles:garage.vehicles.map((v,i)=>i?{...v,canRetrieve:false}:{...v,status:'out',canRetrieve:false,canStore:true})};
    await fire('garage',{session:garage.session,request:1,ok:true,text:'Vehicle outside.',state:out});
    await page.getByRole('button',{name:'Store vehicle',exact:true}).click();
    await page.getByRole('button',{name:'Confirm storage',exact:true}).click();
    await fire('garage',{session:garage.session,request:2,ok:true,text:'Safely parked.',state:{...garage,nextRequest:3}});
    for(const [width,height] of [[1920,1080],[1280,720],[800,600]]) {
      await page.setViewportSize({width,height});await page.getByRole('button',{name:'Retrieve vehicle',exact:true}).scrollIntoViewIfNeeded();
      assert(await page.locator('.garage-card').first().evaluate(el=>el.scrollHeight<=el.clientHeight+2),'card information must not be clipped');
      await page.screenshot({path:path.join(output,`garage-${width}.png`),animations:'disabled'});
      assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    }
    await fire('garage',{session:garage.session,closed:true});assert.equal(await page.locator('.garage').count(),0);
    assert.deepEqual(errors,[]);
    console.log('PASS: dealer + garage browser flow, photos, 3 viewports, confirmation, insufficient funds, single-flight, acknowledgements and lifecycle.');
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
