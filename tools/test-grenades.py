"""Exercise actual inventory + weapon queue + grenades with asynchronous native boundaries."""
from pathlib import Path
import runpy
ns=runpy.run_path(str(Path(__file__).with_name('test-armament.py')))
lua=ns['lua']
lua.execute('''
dofile("shared/grenades.lua")
local db=LightRP.db;local oldRead,oldTransaction=db.read,db.transaction
local savedGrenades,receipts={},{}
function db.read(q,v)
 if q:find("FROM lightrp_grenade_operations",1,true)then local op=receipts[v[1]..":"..v[2]];return true,op and{{operation=op}}or{}end
 if q:find("FROM lightrp_grenades",1,true)then return true,savedGrenades[v[1]]and{savedGrenades[v[1]]}or{}end
 return oldRead(q,v)
end
function db.transaction(queries)
 local ok,why=oldTransaction(queries);if not ok then return false,why end
 for _,q in ipairs(queries)do
  local v=q.values
  if q.query:find("INSERT INTO lightrp_grenades ",1,true)then assert(v[3]~=nil,"SQL NULL uses an explicit empty selection");savedGrenades[v[1]]={revision=v[2],selected_item=v[3]}end
  if q.query:find("INSERT INTO lightrp_grenade_operations",1,true)then local key=v[1]..":"..v[2];assert(not receipts[key]);receipts[key]=v[3]end
 end
 return true
end
-- Real 2.x semantics: inventory membership does NOT shrink on throws.
-- Usable charges are a separate, managed pool. Legacy gadget readers must not
-- be used to infer consumption or these regression tests fail immediately.
gadgetStock={ ["Items.GrenadeFragRegular"]=5,["Items.GrenadeEMPRegular"]=2 }
chargeKit={kind="grenade",record="Items.GrenadeFragRegular",count=2,capacity=2,equipped=true,recharge=true,managed=false,sequence=0}
chargeJobs={};suppressGadgets=false;failChargeConfigure=false
for _,method in ipairs({"requestGadgets","giveGadget","takeGadget"})do
 Open77.weapons[method]=function()error("Legacy gadget stacks are not throw counts")end
end
Open77.consumables={}
for _,method in ipairs({"configure","snapshot"})do
 local name=method
 Open77.consumables[name]=function(player,kind,options)
  sequence=sequence+1;chargeJobs[#chargeJobs+1]={id=sequence,player=player,method=name,kind=kind,options=options};return sequence
 end
end
CreateThread(function()
 while true do
  if not suppressGadgets then
   local pending=chargeJobs;chargeJobs={}
   for _,j in ipairs(pending)do
    assert(j.kind=="grenade","grenade integration must never alter healing charges")
    if j.method=="configure"then
     local a=j.options
     chargeKit={kind=j.kind,record=a.record,count=a.count,capacity=a.capacity,equipped=a.equipped,recharge=a.recharge,managed=true,sequence=chargeKit.sequence+1}
    end
    local accepted,reason=true,nil
    if j.method=="configure"and failChargeConfigure then chargeKit.count=math.max(0,chargeKit.count-1);accepted=false;reason="consumable_readback_mismatch"end
    for _,fn in ipairs(events["open77:weapons:completed"])do fn(j.player,j.id,"consumable",accepted,reason,W.clone(chargeKit))end
   end
  end
  Wait(25)
 end
end)
dofile("server/modules/grenades.lua")
local G=LightRP.grenades
local function start(op,item,key)
 for i=1,40 do if not W.runtime[1].busy then break end;tick(50)end
 local ok,why=G.start(1,op,item,key);assert(ok,why);tick(900)
end
assert(Inv.addItem(inv.id,"grenade_frag",5));assert(Inv.addItem(inv.id,"grenade_emp",2))
local frag="Items.GrenadeFragRegular";local emp="Items.GrenadeEMPRegular"
start("equip","grenade_frag","test:frag:equip")
assert(G.view(1).ready and G.view(1).count==5 and chargeKit.count==5 and not chargeKit.recharge and chargeKit.managed,"equip projects ownership without consuming")
start("equip","grenade_frag","test:frag:equip")
assert(chargeKit.count==5 and Inv.count(inv.id,"grenade_frag")==5,"replayed selection does not duplicate native stock")
start("equip","grenade_frag","test:frag:toggle-off")
assert(not G.view(1).selected and not chargeKit.equipped and Inv.count(inv.id,"grenade_frag")==5,"reuse stows without consuming")
start("equip","grenade_frag","test:frag:toggle-on")
assert(G.view(1).selected=="grenade_frag" and chargeKit.count==5,"reuse draws stored grenades")
failChargeConfigure=true;start("sync",nil,"test:partial:write")
assert(not G.view(1).ready and Inv.count(inv.id,"grenade_frag")==5,"partial native writes do not consume inventory")
failChargeConfigure=false;start("sync",nil,"test:partial:retry")
assert(G.view(1).ready and chargeKit.count==5 and Inv.count(inv.id,"grenade_frag")==5)
assert(not Inv.removeItem(inv.id,"grenade_frag",1),"equipped grenade stock is locked")
chargeKit.count=4;chargeKit.sequence=chargeKit.sequence+1
for _,fn in ipairs(events.onConsumableUsed)do fn(1,"grenade",frag,4,1,10);fn(1,"grenade",frag,0,1,9);fn(1,"grenade",frag,4,1,10)end
tick(1400)
assert(Inv.count(inv.id,"grenade_frag")==4 and gadgetStock[frag]==5,"unchanged gadget stack, duplicate/stale notifications reconcile one fresh count")
-- SQL failure cannot remove inventory items; native spent count is retried.
failSql=true;chargeKit.count=3;tick(1200)
assert(Inv.count(inv.id,"grenade_frag")==4 and not G.view(1).ready)
failSql=false;start("sync",nil,"test:sync:retry")
assert(Inv.count(inv.id,"grenade_frag")==3 and chargeKit.count==3)
start("equip","grenade_emp","test:emp:equip")
assert(chargeKit.record==emp and chargeKit.count==2 and G.view(1).selected=="grenade_emp")
-- An unauthorized native increase is never credited; sync resets it exactly.
chargeKit.count=9;chargeKit.capacity=9;tick(1200);assert(Inv.count(inv.id,"grenade_emp")==2 and not G.view(1).ready)
start("sync",nil,"test:emp:reset");assert(chargeKit.count==2 and G.view(1).ready)
start("unequip",nil,"test:emp:unequip")
assert(not G.view(1).selected and chargeKit.count==0 and not chargeKit.equipped and Inv.count(inv.id,"grenade_emp")==2)
assert(Inv.removeItem(inv.id,"grenade_emp",1))
-- Generic item Use selects a grenade while preserving the stack.
local fragSlot=slotOf("grenade_frag")
for i=1,40 do if not W.runtime[1].busy then break end;tick(50)end
assert(Inv.use(1,fragSlot));tick(1300)
assert(G.view(1).selected=="grenade_frag" and Inv.count(inv.id,"grenade_frag")==3 and chargeKit.count==3)
chargeKit.count=0;tick(1400)
assert(Inv.count(inv.id,"grenade_frag")==0 and not G.view(1).selected,"last throw clears selection without trapping future grants")
-- Pending native gadget writes use the weapon queue's timeout quarantine.
for i=1,40 do if not W.runtime[1].busy then break end;tick(50)end
suppressGadgets=true;assert(G.start(1,"sync"));tick(13000)
assert(W.runtime[1].quarantine and not G.view(1).ready)
assert(not G.start(1,"sync"));suppressGadgets=false;tick(300)
assert(not W.runtime[1].quarantine)
local api=Open77.consumables;Open77.consumables=nil
assert(not G.start(1,"sync")and not G.view(1).ready,"unsupported clients/servers cannot fall back to unlimited gadget stacks")
Open77.consumables=api
print("PASS: finite grenade charges with constant gadget membership, recharge disabled, fresh consumption/replays, SQL rollback, switch/unequip, inventory locks, generic Use and timeout quarantine")
''')
