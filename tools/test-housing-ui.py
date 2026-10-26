"""Keyboard/UI contract tests in Chromium against the Vite preview on 5196.

Real React components and bridge messages, deterministic server replies. SQL and
access-control behavior are tested separately by test-housing.py.
Requires playwright (or artifacts/housing/python-deps) and installed Chromium.
"""
from pathlib import Path
import json
import os
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'artifacts/housing/python-deps'))
from playwright.sync_api import sync_playwright, expect

output = root / 'artifacts/housing'
output.mkdir(parents=True, exist_ok=True)
point = dict(x=-1200, y=1100, z=44, heading=92)
fixture = dict(now=1800000000, admin=True, canAdmin=True, recovery=[], players=[dict(id=2, name='Alex Morgan', identifier='test-alex', key='default')],
    templates=[dict(id='template-one', revision=3, label='Megabuilding studio', slots=40, weight=150, ready=True, points=dict(spawn=point,exit=point,stash=point))],
    properties=[dict(id=1, revision=7, label='Megabuilding H10 · Apartment 0412', kind='apartment', entrance=point, price=50000, rent=2500, rentDays=7,
        enabled=True, available=True, owned=False, hasKey=False, locked=True, near=True, resale=0, templateId='template-one', templateLabel='Megabuilding studio')])
fixture['properties'] += [dict(fixture['properties'][0], id=i, label=f'Test unit {i:03}') for i in range(2, 13)]

bridge = r"""fixture => {
  window.housingCalls=[]; window.housingResponses=[]; window.housingFixture=fixture;
  const callbacks=new Map(); let value;
  window.housingReply=(name,data)=>{for(const fn of callbacks.get(name)||[])fn(data);};
  Object.defineProperty(window,'Open77',{configurable:true,get:()=>value,set:bridge=>{
    const originalOn=bridge.on.bind(bridge),originalEmit=bridge.emit.bind(bridge);
    bridge.on=(name,fn)=>{if(!callbacks.has(name))callbacks.set(name,new Set());callbacks.get(name).add(fn);originalOn(name,fn);};
    bridge.emit=(name,p)=>{
      if(name==='lightrp:ui:support'&&p.operation==='housing'){
        window.housingCalls.push(structuredClone(p));
        let data={message:'Saved.'};
        if(p.action==='browse'){
          data=structuredClone(window.housingFixture);data.pages={};
          data.counts={properties:fixture.properties.length,templates:fixture.templates.length};
          for(const field of ['properties','templates','players','recovery']){
            let rows=data[field].filter(r=>!p.search||(r.label||r.name||'').toLowerCase().includes(p.search.toLowerCase()));
            if(field==='properties'&&p.view==='mine')rows=rows.filter(r=>r.owned||r.hasKey);
            if(field==='templates'&&p.view==='chooseTemplate')rows=rows.filter(r=>r.ready);
            const pages=Math.max(1,Math.ceil(rows.length/10)),page=Math.min(pages,p.page||1);
            data.pages[field]={page,pages,total:rows.length};data[field]=rows.slice((page-1)*10,page*10);
            const selected=rows.find(r=>r.id===p.id);
            if(selected&&!data[field].some(r=>r.id===p.id))data[field].push(selected);
          }
        }
        else if(p.action==='occupants')data={players:fixture.players};
        else if(p.action==='admin.template.create'){
          data.id='created-template';fixture.templates.push({id:data.id,revision:1,label:p.label,slots:p.slots,weight:p.weight,points:{},ready:false});
        }else if(p.action==='admin.template.capture'){
          const t=fixture.templates.find(t=>t.id===p.id);t.points[p.point]={x:1,y:2,z:3,heading:4};t.revision++;
        }else if(p.action==='stash'){
          const box=(id,kind,label)=>({id,kind,label,slots:40,maxWeight:150,weight:0,items:[]});
          window.housingReply('lightrp:ui:dialog',{kind:'inventory',left:box('player','player','Pockets'),right:box('home','housing','Home storage')});
          data={message:'Storage opened.',close:true};
        }
        setTimeout(()=>{window.housingReply(name,{kind:'response',request:p.request,ok:true,data});window.housingResponses.push(p.action);},35);return;
      }
      if(name==='lightrp:ui:action'&&p.type==='housing.open'){window.housingReply('lightrp:ui:dialog',{kind:'housing',admin:!!p.admin});return;}
      originalEmit(name,p);
    };value=bridge;
  }});
}"""

with sync_playwright() as p:
    chromium = Path(os.environ['LOCALAPPDATA']) / 'ms-playwright/chromium-1228/chrome-win64/chrome.exe'
    browser = p.chromium.launch(executable_path=str(chromium) if chromium.exists() else None, headless=True)
    page = browser.new_page(viewport=dict(width=1280, height=720), device_scale_factor=1)
    errors=[]
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.add_init_script('(' + bridge + ')(' + json.dumps(fixture) + ')')
    page.goto('http://127.0.0.1:5196/?registered=1&staff=1')
    page.wait_for_function('window.__lightrpMock === true')
    page.evaluate("async () => { const {useStore}=await import('/src/state/store.ts'); useStore.getState().openDialog({kind:'housing',admin:true}); }")
    expect(page.get_by_text('Interior templates',exact=True)).to_be_visible()

    def choose(text):
        expect(page.locator('.rp-housing .o77-rage__text').filter(has_text='Loading housing')).to_have_count(0)
        for _ in range(35):
            selected=page.locator('.rp-housing .o77-rage__row--on .o77-rage__text')
            if selected.count() and selected.inner_text().casefold()==text.casefold():
                page.keyboard.press('Enter')
                return
            page.keyboard.press('ArrowDown')
        page.screenshot(path=str(output/'housing-ui-failure.png'))
        raise AssertionError('Could not select ' + text + '\n' + page.locator('.rp-housing').inner_text())

    choose('Interior templates')
    choose('Create interior template')
    expect(page.get_by_label('Template name')).to_be_focused()
    page.get_by_label('Template name').fill('Test apartment template')
    page.get_by_label('Storage slots').fill('60')
    page.get_by_label('Storage capacity (kg)').fill('250')
    page.screenshot(path=str(output/'housing-admin-template-form.png'))
    page.get_by_role('button',name='Save template',exact=True).click()
    expect(page.locator('.rp-housing .o77-rage__title')).to_have_text('Test apartment template')
    choose('Capture spawn here')
    expect(page.locator('.rp-housing .rp-support__success')).to_have_text('Saved.')
    page.wait_for_function("window.housingFixture.templates.at(-1).points.spawn !== undefined")
    captured=page.evaluate("window.housingCalls.find(p=>p.action==='admin.template.capture')")
    assert captured['point']=='spawn' and 'position' not in captured, 'positions must be captured on server'
    assert captured['revision']==1
    page.keyboard.press('Escape');page.keyboard.press('Escape')
    choose('Dwellings');choose('Create dwelling here')
    choose('Megabuilding studio')
    expect(page.get_by_role('combobox',name='Interior template',exact=True)).to_be_visible()
    assert page.get_by_role('combobox',name='Interior template',exact=True).locator('option').count()==1, 'incomplete interiors cannot be assigned'
    page.get_by_label('Dwelling name').fill('Unit 405')
    page.get_by_label('Purchase price (€$, 0 disables buying)').fill('60000')
    page.screenshot(path=str(output/'housing-admin-property-form.png'))
    page.keyboard.press('Escape');page.keyboard.press('Escape');page.keyboard.press('Escape')
    page.evaluate("async () => { const {useStore}=await import('/src/state/store.ts'); useStore.getState().openDialog({kind:'housing',admin:false}); }")
    expect(page.get_by_text('At this entrance',exact=True)).to_be_visible()
    choose('At this entrance');choose('Megabuilding H10 · Apartment 0412')
    choose('Buy this home')
    expect(page.get_by_role('heading',name='Buy home',exact=True)).to_be_visible()
    assert not page.evaluate("window.housingCalls.some(p=>p.action==='buy')"), 'selection must not charge before confirmation'
    page.screenshot(path=str(output/'housing-player-purchase.png'))
    bounds=page.locator('.rp-housing').bounding_box()
    assert bounds['x']>=0 and bounds['x']+bounds['width']<=1280 and bounds['y']+bounds['height']<=720
    page.get_by_role('button',name='Confirm',exact=True).click()
    page.wait_for_function("window.housingCalls.some(p=>p.action==='buy')")
    purchase=page.evaluate("window.housingCalls.find(p=>p.action==='buy')")
    assert purchase['id']==1 and purchase['revision']==7 and 'price' not in purchase, 'authoritative price and stale quote protection'

    page.evaluate("async () => { const {useStore}=await import('/src/state/store.ts'); useStore.getState().openDialog({kind:'housing',admin:true}); }")
    choose('Dwellings');choose('Next page (1/2)');choose('Test unit 012')
    expect(page.locator('.rp-housing .o77-rage__title')).to_have_text('Test unit 012')
    page.keyboard.press('Escape')
    choose('Search by name')
    page.get_by_label('Name',exact=True).fill('Test unit 011')
    page.get_by_role('button',name='Search',exact=True).click()
    choose('Test unit 011')
    expect(page.locator('.rp-housing .o77-rage__title')).to_have_text('Test unit 011')
    assert page.evaluate("window.housingCalls.some(p=>p.action==='browse'&&p.view==='properties'&&p.page===2)")
    assert page.evaluate("window.housingCalls.some(p=>p.action==='browse'&&p.search==='Test unit 011'&&p.page===1)")

    # The inventory dialog can arrive before the housing RPC response. Its late
    # close:true must not dismiss the newly opened inventory.
    page.evaluate("""async () => {
      const h=window.housingFixture.properties[0];Object.assign(h,{owned:true,hasKey:true,available:false,mode:'purchase'});
      window.housingFixture.inside={propertyId:h.id,phase:'inside',label:h.label};
      const {useStore}=await import('/src/state/store.ts');useStore.getState().openDialog({kind:'housing',admin:false});
    }""")
    choose('My homes & shared keys');choose('Megabuilding H10 · Apartment 0412');choose('Open home storage')
    page.wait_for_function("window.housingResponses.includes('stash')")
    expect(page.get_by_role('button',name='Close inventory',exact=True)).to_be_visible()
    expect(page.locator('.rp-housing')).to_have_count(0)
    page.screenshot(path=str(output/'housing-inventory-handoff.png'))
    assert not errors, errors
    print('Housing UI passed: keyboard authoring, forms, captured coordinates, template filtering, purchase confirmation, pagination, search, inventory handoff and 1280×720 layout.')
    browser.close()
