// The unified /admin (ui/src/features/support/AdminMenu.tsx) on the dev mock (?admin=1,
// ui/src/features/support/mock.ts): the root sections, a catalogue spawn and its answer, a
// player's grouped page and a form, a destructive action reviewed with Cancel focused, the
// world and missions sub-sections, an ACL-refused answer shown as an error.
// npm --prefix ui run dev -- --port 5199 --strictPort --host 127.0.0.1, then
// PLAYWRIGHT_MODULE=<playwright> node ui/tests/admin-menu.browser.cjs
const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:process.env.BROWSER_CHANNEL||'msedge'});
 try{
  const page=await browser.newPage({viewport:{width:1920,height:1080}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const sent=[];page.on('console',m=>{const t=m.text();if(t.startsWith('[mock] emit lightrp:ui:support'))sent.push(t);});
  await page.goto((process.env.UI_URL||'http://127.0.0.1:5199')+'/?admin=1');
  const menu=page.locator('.rp-support__menu');
  await menu.waitFor();
  const current=()=>menu.locator('.o77-rage__row--on .o77-rage__text').textContent();
  const title=()=>menu.locator('.o77-rage__title').innerText();
  const choose=async(text,enter=true)=>{
   for(let i=0;i<70;i++){if(await current()===text){if(enter)await page.keyboard.press('Enter');return;}await page.keyboard.press('ArrowDown');}
   throw Error('Menu row not found: '+text+'; '+await menu.innerText());
  };
  const status=()=>page.locator('.rp-support__success, .rp-support__error').first().innerText();
  await page.locator('.o77-rage__row:not(.o77-rage__row--disabled)').filter({hasText:'Players'}).waitFor();
  assert.equal(await title(),'LIGHT/RP');
  // the root: every section reachable (the list scrolls: walk it with the keyboard)
  for(const s of ['Reports','Players','Personal tools','Teleport','Vehicles','Items & weapons','World','Missions & events','Places & content','Server','Staff history'])
   await choose(s,false);
  await page.keyboard.press('ArrowUp');await choose('Reports',false);
  // a catalogue spawn: the command's answer shows under the menu
  await choose('Vehicles');assert.equal(await title(),'VEHICLES');
  await choose('Spawn a LightRP vehicle');await choose('Makigai MaiMai');
  await page.locator('.rp-support__success').filter({hasText:'lightrp.car maimai: done'}).waitFor();
  await page.keyboard.press('Backspace');await page.keyboard.press('Backspace');
  // a player: quick moves, the groups, a give form
  await choose('Players');await choose('#2 Jerem Kade');await page.locator('.rp-support__record h2').filter({hasText:'Jerem Kade'}).waitFor();
  assert.equal(await title(),'PLAYER');
  const rows=await menu.locator('.o77-rage__text').allInnerTexts();
  assert(rows.length<=16,'the player page stays short: '+rows.length);
  await choose('Give');await choose('Give an item…');
  await page.getByLabel('Count').fill('3');await page.getByRole('button',{name:'Run',exact:true}).click();
  await page.locator('.rp-support__success').filter({hasText:'lightrp.giveitem 2 water 3: done'}).waitFor();
  await page.keyboard.press('Backspace');
  // a destructive action: review step, Cancel focused, the exact command shown, refused by the "ACL"
  await choose('Moderation');await choose('Kill');
  await page.getByRole('alertdialog').waitFor();
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Cancel','safe default focus');
  assert.match(await page.getByRole('alertdialog').innerText(),/admin\.player\.kill 2/);
  await page.getByRole('button',{name:'Confirm',exact:true}).click();
  await page.locator('.rp-support__error').filter({hasText:'Refused'}).waitFor();
  for(let i=0;i<3;i++)await page.keyboard.press('Backspace');
  assert.equal(await title(),'LIGHT/RP');
  // world and missions sub-sections
  await choose('World');await choose('Weather');await choose('Rain');
  await page.locator('.rp-support__success').filter({hasText:'weather.set rain 15: done'}).waitFor();
  await page.keyboard.press('Backspace');await page.keyboard.press('Backspace');
  await choose('Missions & events');await choose('World bosses');assert.equal(await title(),'WORLD BOSSES');
  await choose('Start the next world boss now');await page.locator('.rp-support__success').filter({hasText:'worldboss.start: done'}).waitFor();
  for(const [width,height]of [[1920,1080],[1366,768],[1024,768]]){
   await page.setViewportSize({width,height});const box=await page.locator('.rp-support').boundingBox();
   assert(box.x+box.width<=width+1&&box.y+box.height<=height+1,'fits at '+width);
  }
  fs.mkdirSync('artifacts',{recursive:true});await page.screenshot({path:'artifacts/admin-menu.png'});
  assert.deepEqual(errors,[]);
  console.log('PASS: unified /admin (root sections, catalogue spawn + answer, grouped player page, give form, reviewed destructive action with Cancel focused and its refusal, world weather, world bosses, three viewports)');
 }catch(e){fs.mkdirSync('artifacts',{recursive:true});const p=browser.contexts()[0]?.pages()[0];if(p)await p.screenshot({path:'artifacts/admin-menu-failure.png'});throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
