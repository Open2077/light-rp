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
gadgetStock={};gadgetJobs={};gadgetActive=nil;suppressGadgets=false
for _,method in ipairs({"requestGadgets","giveGadget","takeGadget"})do
 local name=method
 Open77.weapons[name]=function(player,...)
  sequence=sequence+1;gadgetJobs[#gadgetJobs+1]={id=sequence,player=player,op=name=="requestGadgets"and"gadgets"or name,args=table.pack(...)};return sequence
 end
end
CreateThread(function()
 while true do
  if not suppressGadgets then
   local pending=gadgetJobs;gadgetJobs={}
   for _,j in ipairs(pending)do
    local a=j.args
    if j.op=="giveGadget"then gadgetStock[a[1]]=(gadgetStock[a[1]]or 0)+a[2];gadgetActive=a[1]
    elseif j.op=="takeGadget"then local record=a[1]or gadgetActive;if record then gadgetStock[record]=0;if gadgetActive==record then gadgetActive=nil end end end
    local rows={};for record,n in pairs(gadgetStock)do if n>0 then rows[#rows+1]={slot=1,record=record,tweakDbId="hash:"..record,quantity=n,active=gadgetActive==record}end end
    for _,fn in ipairs(events["open77:weapons:completed"])do fn(j.player,j.id,j.op,true,nil,j.op=="gadgets"and rows or{gadget={quantity=0}})end
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
assert(Inv.addItem(inv.id,"grenade_frag",3));assert(Inv.addItem(inv.id,"grenade_emp",2))
local frag="Items.GrenadeFragRegular";local emp="Items.GrenadeEMPRegular"
start("equip","grenade_frag","test:frag:equip")
assert(G.view(1).ready and G.view(1).count==3 and gadgetStock[frag]==3,"equip projects ownership without consuming")
start("equip","grenade_frag","test:frag:equip")
assert(gadgetStock[frag]==3 and Inv.count(inv.id,"grenade_frag")==3,"replayed selection does not duplicate native stock")
assert(not Inv.removeItem(inv.id,"grenade_frag",1),"equipped grenade stock is locked")
gadgetStock[frag]=2
for _,fn in ipairs(events.onGadgetConsumed)do fn(1,frag,2);fn(1,frag,0);fn(1,frag,2)end
tick(1400)
assert(Inv.count(inv.id,"grenade_frag")==2,"duplicate/stale notifications reconcile one fresh count")
-- SQL failure cannot remove inventory items; native spent count is retried.
failSql=true;gadgetStock[frag]=1;tick(1200)
assert(Inv.count(inv.id,"grenade_frag")==2 and not G.view(1).ready)
failSql=false;start("sync",nil,"test:sync:retry")
assert(Inv.count(inv.id,"grenade_frag")==1 and gadgetStock[frag]==1)
start("equip","grenade_emp","test:emp:equip")
assert(gadgetStock[frag]==0 and gadgetStock[emp]==2 and G.view(1).selected=="grenade_emp")
-- An unauthorized native increase is never credited; sync resets it exactly.
gadgetStock[emp]=9;tick(1200);assert(Inv.count(inv.id,"grenade_emp")==2 and not G.view(1).ready)
start("sync",nil,"test:emp:reset");assert(gadgetStock[emp]==2 and G.view(1).ready)
start("unequip",nil,"test:emp:unequip")
assert(not G.view(1).selected and gadgetStock[emp]==0 and Inv.count(inv.id,"grenade_emp")==2)
assert(Inv.removeItem(inv.id,"grenade_emp",1))
-- Generic item Use selects a grenade while preserving the stack.
local fragSlot=slotOf("grenade_frag")
for i=1,40 do if not W.runtime[1].busy then break end;tick(50)end
assert(Inv.use(1,fragSlot));tick(1300)
assert(G.view(1).selected=="grenade_frag" and Inv.count(inv.id,"grenade_frag")==1 and gadgetStock[frag]==1)
gadgetStock[frag]=0;tick(1400)
assert(Inv.count(inv.id,"grenade_frag")==0 and not G.view(1).selected,"last throw clears selection without trapping future grants")
-- Pending native gadget writes use the weapon queue's timeout quarantine.
for i=1,40 do if not W.runtime[1].busy then break end;tick(50)end
suppressGadgets=true;assert(G.start(1,"sync"));tick(13000)
assert(W.runtime[1].quarantine and not G.view(1).ready)
assert(not G.start(1,"sync"));suppressGadgets=false;tick(300)
assert(not W.runtime[1].quarantine)
print("PASS: counted grenade selection, exact native stock, fresh consumption/replays, SQL rollback, switch/unequip, inventory locks, generic Use and timeout quarantine")
''')
