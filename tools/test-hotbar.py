"""Actual inventory and hotbar: no duplicate item store, no trusting stale slot bindings."""
from pathlib import Path
import runpy
ns=runpy.run_path(str(Path(__file__).with_name('test-grenades.py')))
lua=ns['lua']
lua.execute('''
dofile("server/modules/hotbar.lua")
local H=LightRP.hotbar
assert(next(inv.viewers)==nil)
-- the armament run leaves unpacked rounds (inventory items) in the first row; this test owns slots 4 and 6
if Inv.count(inv.id,"ammo_pistol")>0 then assert(Inv.removeItem(inv.id,"ammo_pistol",Inv.count(inv.id,"ammo_pistol"))) end
assert(Inv.addItem(inv.id,"water",3,nil,4))
assert(Inv.addItem(inv.id,"repairkit",1,nil,6))
local state=H.snapshot(1)
assert(state.ready and state.inventoryId==inv.id)
for _,item in ipairs(state.items)do assert(item.slot<=5)end
local last=messages[#messages]
assert(last.name=="op77_lightrp:hotbar"and last.p.state.items,"closed inventory mutations still update quick slots")
local before=Inv.count(inv.id,"water")
local packet={slot=4,inventoryId=inv.id,revision=inv.revision or 0}
assert(H.use(1,packet));assert(Inv.count(inv.id,"water")==before-1)
tick(300)
assert(not H.use(1,packet)and Inv.count(inv.id,"water")==before-1,"old snapshot cannot consume another item")
assert(not H.use(1,{slot=6,inventoryId=inv.id,revision=inv.revision or 0}),"only the first row is bound")
assert(not H.use(1,{slot=4,inventoryId="another-character",revision=inv.revision or 0}))
-- The hotbar must keep the existing timed-consumption path.
local active,started=false,false
local original=LightRpItems.water.consumeAction
LightRpItems.water.consumeAction="test_drink"
LightRP.consumables={isActive=function()return active end,begin=function(player,source,slot,item)
 assert(source==inv and slot==4 and item.name=="water");active=true;started=true;return true
end}
tick(300);assert(H.use(1,{slot=4,inventoryId=inv.id,revision=inv.revision or 0})and started)
assert(Inv.count(inv.id,"water")==before-1,"timed use does not consume eagerly")
tick(300);assert(not H.use(1,{slot=4,inventoryId=inv.id,revision=inv.revision or 0}),"active use cannot be started twice")
LightRpItems.water.consumeAction=original;LightRP.consumables=nil
local life=Open77.players.getLifeState;Open77.players.getLifeState=function()return{phase="dead"}end
assert(not H.snapshot(1).ready and not H.use(1,{slot=4,inventoryId=inv.id,revision=inv.revision or 0}))
Open77.players.getLifeState=life
assert(not H.snapshot(2).ready and #H.snapshot(2).items==0,"another player never gets this inventory")
hooks.hotbar.onCharacterLoaded(1,{status="active"})
print("PASS: first-row bindings, closed-inventory pushes, live counts, stale/other-inventory guards, timed-use reuse, busy/death checks")
''')
