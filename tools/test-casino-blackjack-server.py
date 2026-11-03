#!/usr/bin/env python3
"""Blackjack controller + RP-money regressions on the real board/tabletop modules.

Reuses the mock host of tools/test-tabletop-extra-server.py (atomic commits of
board rows, inventories and claims), loads the real blackjack rules and server
handler, and drives four seated players through stacked shoes.
"""
from pathlib import Path
import json
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
source=(ROOT/'tools/test-tabletop-extra-server.py').read_text()
namespace={'__file__':str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(source.split('SOURCES=')[0],namespace)
HARNESS=namespace['HARNESS']
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'shared/casino_blackjack.lua',
         GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/casino_blackjack.lua',GAME/'server/modules/board_games.lua']
EXTRA=r'''
B=LightRpBlackjack
realShuffle=B.shuffle
function stack(list) B.shuffle=function() local s={} for i,v in ipairs(list) do s[i]=v end for i=#list+1,312 do s[i]='2C' end return s end end
function seated(id) local ids={} for p=1,4 do action(p,id,'join') end return ids end
function view(id,player) return board(id,player).game end
-- Walk every public table a client receives: no private key, ever.
function private(t,path)
 if type(t)~='table' then return end
 for k,v in pairs(t) do
  if type(k)=='string' and k:sub(1,1)=='_' then return (path or '')..'.'..k end
  local found=private(v,(path or '')..'.'..tostring(k));if found then return found end
 end
end
function totalUnpaid() local n=0;for _,row in pairs(dbClaims) do if row.paid==0 then n=n+row.amount end end;return n end
function claimRows() local n=0;for _ in pairs(dbClaims) do n=n+1 end;return n end
-- Open77.npcs mock (server natives checked with the devkit, build 156): integer
-- policies, AI pause, transform, the full-body animation task.
npcBodies={};npcLog={};npcNext=0;refuseRecords={}
Open77.npcs={ai={tasks=0,frozen=1,native=2},damage={mortal=0,immortal=1,invulnerable=2},tasks={}}
function Open77.npcs.create(def)
 assert(type(def.record)=='string' and type(def.damagePolicy)=='number' and type(def.aiMode)=='number')
 if refuseRecords[def.record] then return nil,'npc_record_invalid' end
 npcNext=npcNext+1;npcBodies[npcNext]={def=def,ai=true,position=def.position,yaw=def.yaw,bucket=def.bucket};return npcNext
end
function Open77.npcs.remove(id) if not npcBodies[id] then return false,'npc_not_found' end;npcBodies[id]=nil;return true end
function Open77.npcs.setAIEnabled(id,on) assert(type(on)=='boolean');npcBodies[id].ai=on;npcLog[#npcLog+1]='ai:'..tostring(on);return true end
function Open77.npcs.tasks.clear(id) npcBodies[id].anim=nil;npcLog[#npcLog+1]='clear';return true end
function Open77.npcs.setTransform(id,t) npcBodies[id].position=t.position;npcBodies[id].yaw=t.yaw;npcLog[#npcLog+1]='transform';return true end
function Open77.npcs.tasks.playAnimation(id,clip,o) npcLog[#npcLog+1]='anim:'..clip;npcBodies[id].anim={clip=clip,timeoutMs=o.timeoutMs,loop=o.loop};return #npcLog end
function GetCurrentResourceName() return 'op77_lightrp' end
function dealerTick(at) if at then wall=at end;LightRpBlackjack.dealerTick(LightRP.tabletopExtra.now()) end
function dealerGame(id) for _,b in pairs(LightRpBlackjack.dealers) do if b.board.id==id then return b.board.game end end end
function anims() local n=0;for _,l in ipairs(npcLog) do if l:find('^anim:') then n=n+1 end end;return n end
function bodies() local list={} for id,b in pairs(npcBodies) do b.id=id;list[#list+1]=b end;return list end
function untilPhase(id,phase) for i=1,40 do if view(id).phase==phase then return end;wall=wall+1000;step(2000) end error('phase '..phase..' never reached') end
'''
def environment():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpItems={}')
    lua.execute(HARNESS)
    for path in SOURCES:
        lua.execute(path.read_text())
    lua.execute(EXTRA)
    lua.execute('modules.board_games.onDatabaseReady()')
    # A server restart: fresh module state (and threads), boards reloaded from
    # the persisted rows, NPCs gone with the previous process.
    def restart():
        lua.execute('tasks={};npcBodies={};npcLog={}')
        for path in SOURCES:
            lua.execute(path.read_text())
        lua.execute('modules.board_games.onDatabaseReady()')
    lua.globals().restart=restart
    return lua
def scenario(name,script):
    lua=environment();lua.execute(script);print(name+': passed');return lua
def pyvalue(v):
    if hasattr(v,'items'):
        d={k:pyvalue(x) for k,x in v.items()}
        if d and all(isinstance(k,int) for k in d): return [d[i] for i in sorted(d)]
        return {str(k):x for k,x in d.items()}
    return v

scenario('stakes: whole-dollar limits, insufficient cash, atomic debit, four seats',r'''
local id=place('blackjack',1);seated(id)
local b=board(id);assert(b.players.white==1 and b.players.black==2 and b.players.white2==3 and b.players.black2==4,'four seats')
action(5,id,'join');assert(notices[5]:find('All seats'))
for _,amount in ipairs({4,7.5,-5,5001,'x'}) do local before=commits;game(1,id,'bet',{amount=amount});assert(cash(1)==1000 and commits==before) end
game(2,id,'bet',{amount=1001});assert(cash(2)==1000 and notices[2]:find('Not enough cash'),notices[2])
failDB=true;game(1,id,'bet',{amount=25});failDB=false;assert(cash(1)==1000 and next(view(id).hands)==nil)
game(1,id,'bet',{amount=25});assert(cash(1)==975 and view(id).hands.white.bet==25 and view(id).closesAt)
game(1,id,'bet',{amount=5});assert(cash(1)==970 and view(id).hands.white.bet==30)
game(1,id,'bet',{amount=4971});assert(cash(1)==970 and view(id).hands.white.bet==30,'hand max 5000')
assert(dbBoards[id].data.game.hands.white._inv=='inv1' and dbBoards[id].data.game._roundKey)
assert(not private(view(id)),private(view(id)))
''')

scenario('turns: seat order, wrong seat and wrong owner rejected, hole card never public',r'''
stack({'TS','9D','5C','7H','6D','KH','8C','2S','9S','QH','4D','3S','TD','KC'})
local id=place('blackjack',1);seated(id)
for p=1,4 do game(p,id,'bet',{amount=10}) end
game(3,id,'deal',{});local g=view(id)
assert(g.phase=='playing' and g.seatTurn=='white' and g.dealer.cards[2].h and not g.dealer.cards[2].c)
-- QH is the hole card and appears nowhere else on the table.
for p=1,5 do local v=view(id,p);assert(not private(v),private(v));assert(v.dealer.cards[2].c==nil) end
assert(dbBoards[id].data.game._hole=='QH')
wall=g.actAt
local revision=board(id).revision
game(2,id,'hit',{});assert(board(id).revision==revision and notices[2]:find('not your turn'),notices[2])
game(2,id,'stand',{});game(2,id,'double',{});assert(board(id).revision==revision and cash(2)==990)
game(1,id,'stand',{});assert(view(id).seatTurn=='black')
-- A replacement character in a seat cannot play the absent owner's hand.
local owner=inventories[2];modules.board_games.onDisconnected(2)
inventories[2]={id='other-character',persistent=true,slots=10,items={[2]={name='cash',count=500}}}
action(2,id,'join');assert(board(id).players.black==2)
revision=board(id).revision;game(2,id,'hit',{});assert(board(id).revision==revision and notices[2]:find('another player'),notices[2])
game(2,id,'double',{});assert(cash(2)==500 and board(id).revision==revision)
inventories[2]=owner
game(2,id,'double',{});assert(cash(2)==980 and view(id).hands.black.doubled and view(id).seatTurn=='white2')
for _,p in ipairs({3,4}) do wall=math.max(wall,view(id).animEnd or 0);game(p,id,'stand',{}) end
g=view(id);assert(g.phase=='result' and g.dealer.cards[2].c=='QH' and g.dealer.cards[2].f)
for p=1,5 do assert(not private(view(id,p))) end
''')

scenario('payouts: durable claims at the reveal end, paid exactly once, nothing more next round',r'''
-- white T,K=20 ; black 9,9=18 ; white2 A,K natural ; black2 5,7=12 ; dealer 6 up, T hole -> draws 2C=18
stack({'TS','9D','AH','5C','6D','KH','9C','KC','7H','TD'})
local id=place('blackjack',1);seated(id)
for p,amount in ipairs({100,50,20,30}) do game(p,id,'bet',{amount=amount}) end
assert(cash(1)==900 and cash(2)==950 and cash(3)==980 and cash(4)==970)
game(1,id,'deal',{});wall=view(id).actAt
game(1,id,'stand',{});game(2,id,'stand',{})
local before=commits;failDB=true;game(4,id,'stand',{});failDB=false
assert(view(id).phase=='playing' and claimRows()==0,'failed settlement leaves no claims')
game(4,id,'stand',{})
local g=view(id);assert(g.phase=='result' and g.dealer.total==18)
assert(g.hands.white.result=='win' and g.hands.black.result=='push' and g.hands.white2.result=='blackjack' and g.hands.black2.result=='lose')
assert(unpaid('inv1')==200 and unpaid('inv2')==50 and unpaid('inv3')==50 and unpaid('inv4')==0)
wall=g.resultAt-1;for p=1,4 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==900 and cash(3)==980,'paid before the reveal ended')
wall=g.resultAt;for p=1,4 do LightRP.tabletopExtra.claim(p) end
assert(cash(1)==1100 and cash(2)==1000 and cash(3)==1030 and cash(4)==970)
for p=1,4 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==1100 and cash(3)==1030 and totalUnpaid()==0)
local rows=claimRows()
wall=g.nextAt;assert(step(2000));g=view(id);assert(g.phase=='betting' and g.round==2 and next(g.hands)==nil)
assert(claimRows()==rows and totalUnpaid()==0)
''')

scenario('refunds: reset and pickup before the result return every open stake once',r'''
stack({'5S','9D','6H','8C','KD','2D','3H','4S'})
local id=place('blackjack',1);seated(id)
game(1,id,'bet',{amount=50});game(2,id,'bet',{amount=30})
game(1,id,'deal',{});wall=view(id).actAt;game(1,id,'double',{})
assert(cash(1)==900 and cash(2)==970 and view(id).phase=='playing')
local revision=board(id).revision
failDB=true;action(1,id,'reset');failDB=false;assert(board(id).revision==revision and claimRows()==0)
action(1,id,'reset');assert(view(id).phase=='betting' and next(view(id).hands)==nil)
assert(unpaid('inv1')==100 and unpaid('inv2')==30)
for p=1,2 do LightRP.tabletopExtra.claim(p) end;assert(cash(1)==1000 and cash(2)==1000 and totalUnpaid()==0)
-- Pickup during betting refunds in the same delete/item transaction.
seated(id);game(3,id,'bet',{amount=40});assert(cash(3)==960)
action(1,id,'pickup');assert(not board(id) and itemCount(1,'blackjack_table')==1 and unpaid('inv3')==40)
LightRP.tabletopExtra.claim(3);assert(cash(3)==1000)
-- A settled round refunds nothing on pickup: its claims already exist.
stack({'TS','6D','KH','TC'})
-- (player 4 owns it: the harness places a table into slot 1, where 1's cash now sits)
id=place('blackjack',4);action(4,id,'join');game(4,id,'bet',{amount=10});game(4,id,'deal',{});wall=view(id).actAt
game(4,id,'stand',{});assert(view(id).phase=='result' and unpaid('inv4')==20)
action(4,id,'pickup');assert(not board(id) and unpaid('inv4')==20)
''')

scenario('timers: betting countdown deals, idle turns stand, the round resolves unattended',r'''
stack({'TS','9D','6D','KH','6C','TC'})
local id=place('blackjack',1);seated(id)
game(1,id,'bet',{amount=10});game(2,id,'bet',{amount=10})
local g=view(id);wall=g.closesAt-1;step(2000);assert(view(id).phase=='betting')
wall=g.closesAt;step(2000);g=view(id);assert(g.phase=='playing' and g.seatTurn=='white')
wall=g.turnEndsAt-1;step(2000);assert(view(id).seatTurn=='white')
wall=g.turnEndsAt;step(2000);g=view(id);assert(g.seatTurn=='black' and g.hands.white.timedOut and g.hands.white.done)
-- Everyone walks away: the timeout still finishes the hand and pays.
for p=1,4 do modules.board_games.onDisconnected(p) end
wall=g.turnEndsAt;step(2000);g=view(id,5);assert(g.phase=='result')
assert(unpaid('inv1')==20 and unpaid('inv2')==0)
''')

scenario('dealer NPC: placed behind the shoe facing the players, fallback record, pickup removes it',r"""
local D=B.DEALER
-- Table at (10,20,0), rotation 0: the dealer stands at +Y, 0.72 unscaled * 0.65.
positions[1]={x=10,y=20,z=0,bucket=0}
local id=place('blackjack',1,10,20);assert(#bodies()==0,'NPCs spawn from the dealer tick, not inside the commit')
dealerTick()
local list=bodies();assert(#list==1,'one dealer per table')
local npc=list[1]
assert(npc.def.record==D.candidates[1].record and npc.def.damagePolicy==2 and npc.def.aiMode==0 and npc.ai==false,'invulnerable, AI off')
assert(npc.def.behavior.combatEnabled==false and npc.def.behavior.perceptionEnabled==false and npc.def.behavior.voiceEnabled==false)
assert(npc.def.persistent==false and npc.def.despawnWhenUnobserved==false and npc.bucket==0)
assert(math.abs(npc.position.x-10)<1e-9 and math.abs(npc.position.y-(20+.72*.65))<1e-9 and npc.position.z==0,'behind the felt, on the floor')
assert(npc.yaw==180,'faces the players at -Y')
dealerTick();assert(#bodies()==1,'no duplicate on the next tick')
-- Clients learn the dealer's NPC id (the ALT menu on the croupier opens the table's menu).
assert(board(id,1).npc==npc.id,'the snapshot publishes the dealer NPC id: '..tostring(board(id,1).npc))
-- The table's rotation turns the stand point and the facing with it.
local at,yaw=LightRpBlackjack.dealerStand({position={x=0,y=0,z=0},rotation=90})
assert(math.abs(at.x+.72*.65)<1e-9 and math.abs(at.y)<1e-9 and yaw==270,'rotation 90: dealer at -X facing +X')
-- Pickup removes the NPC.
action(1,id,'pickup');assert(not board(id) and #bodies()==0,'picked up: dealer gone')
assert(next(LightRpBlackjack.dealers)==nil)
-- A refused record falls back to the next candidate; a table in another bucket keeps it.
refuseRecords[D.candidates[1].record]=true
positions[2]={x=30,y=0,z=0,bucket=4}
local other=place('blackjack',2,30,0);dealerTick()
list=bodies();assert(#list==1 and list[1].def.record==D.candidates[2].record and list[1].bucket==4,'fallback record, table bucket')
-- No platform NPCs at all: the table still works, retried a bounded number of times.
action(2,other,'pickup');assert(#bodies()==0)
local api=Open77.npcs;Open77.npcs=nil
local third=place('blackjack',2,40,0)
for i=1,20 do dealerTick(wall+10000) end
local tries=0;for _,line in ipairs(logs) do if line:find('no NPC (attempt',1,true) then tries=tries+1 end end
assert(tries==6,'bounded retries '..tries)
Open77.npcs=api
""")

scenario('dealer NPC: the restart restores it, the resource stop removes it',r"""
positions[1]={x=10,y=20,z=0,bucket=0}
local id=place('blackjack',1,10,20);dealerTick();assert(#bodies()==1)
seated(id);game(1,id,'bet',{amount=10});game(1,id,'deal',{})
-- The resource stops: the dealer goes with it (the platform also clears owned NPCs).
handlers.onResourceStop('another_resource');assert(#bodies()==1)
handlers.onResourceStop('op77_lightrp');assert(#bodies()==0)
restart()
B=LightRpBlackjack
assert(#bodies()==0);dealerTick()
local list=bodies();assert(#list==1 and math.abs(list[1].position.y-(20+.72*.65))<1e-9,'reloaded table gets its dealer back')
-- Mid-round reload: the cards already on the felt get no gesture.
dealerTick(wall+500);assert(anims()==0 and bodies()[1].ai==false,'no gesture for old cards')
""")

scenario('dealer NPC: a subtle gesture while the cards leave the shoe, AI back off after',r"""
positions[1]={x=0,y=0,z=0,bucket=0}
stack({'TS','9D','6D','KH','7C','QH','3H'})
local id=place('blackjack',1);seated(id);dealerTick()
local npc=bodies()[1];assert(npc.ai==false and anims()==0)
game(1,id,'bet',{amount=10});game(2,id,'bet',{amount=10});dealerTick();assert(anims()==0 and npc.ai==false,'a bet is no card')
game(1,id,'deal',{});local g=dealerGame(id)
dealerTick(g.dealtAt);assert(npc.ai==true and npc.anim and npc.anim.clip==B.DEALER.gesture and npc.anim.loop,'gesture with the first card')
assert(npc.anim.timeoutMs==g.animEnd-g.dealtAt,'the clip ends with the deal '..tostring(npc.anim.timeoutMs))
dealerTick(g.animEnd-1);assert(npc.ai==true)
dealerTick(g.animEnd);assert(npc.ai==false and npc.anim==nil and table.concat(npcLog,',',#npcLog-2)=='clear,ai:false,transform','tasks cleared, AI off, back on its mark after the deal')
local count=#npcLog;dealerTick(g.actAt);assert(#npcLog==count,'quiet during the turn')
-- Stands: the hole card turns and the dealer draws; another gesture over that window.
wall=g.actAt;game(1,id,'stand',{});game(2,id,'stand',{});g=dealerGame(id)
assert(g.phase=='result' and g.revealAt)
dealerTick(g.revealAt-1);assert(npc.ai==false,'still during the reveal pause')
dealerTick(g.revealAt);assert(npc.ai==true and npc.anim.timeoutMs==g.animEnd-g.revealAt)
dealerTick(g.animEnd);assert(npc.ai==false)
-- Gesture off: nothing toggles.
B.DEALER.gesture=nil;count=#npcLog
wall=g.nextAt;step(2000);game(1,id,'bet',{amount=10});game(1,id,'deal',{});g=dealerGame(id)
dealerTick(g.dealtAt+100);assert(#npcLog==count and npc.ai==false)
""")

lua=scenario('public view stays small at the worst case (four 7-card hands, 8-card dealer)',r'''
local twos={'2S','2H','2D','2C'};local threes={'3S','3H','3D','3C'}
local list={}
local function add(c) list[#list+1]=c end
for pass=1,2 do for p=1,4 do add(twos[p]) end;add(pass==1 and '2D' or '3D') end
for p=1,4 do for _,c in ipairs({'2S','2H','2D','3S','3H'}) do add(c) end end
stack(list)
worstId=place('blackjack',1);seated(worstId)
for p=1,4 do inventories[p].items[2]={name='cash',count=100000};game(p,worstId,'bet',{amount=4999}) end
game(1,worstId,'deal',{});wall=view(worstId).actAt
for p=1,4 do for i=1,5 do wall=math.max(wall,view(worstId).animEnd or 0);game(p,worstId,'hit',{}) end;game(p,worstId,'stand',{}) end
local g=view(worstId);assert(g.phase=='result' and #g.dealer.cards==8)
for p=1,4 do assert(#g.hands[LightRpBlackjack.SEATS[p]].cards==7) end
''')
entry=next(b for b in lua.eval('list(1)').values() if b['id']==lua.eval('worstId'))
size=len(json.dumps(pyvalue(entry),separators=(',',':')))
game=len(json.dumps(pyvalue(entry['game']),separators=(',',':')))
assert size<3000,size
print(f'public view size: board entry {size} bytes, game {game} bytes (limit ~3 KB)')
print('Blackjack server: all money, turn, privacy, timer and size scenarios passed')
# The dealer's stand point uses the casino tables' model scale: keep it equal to the client's.
import re
client_scale=re.search(r'^local SCALE=([\d.]+)',(GAME/'client/core/tabletop_extra.lua').read_text(),re.M).group(1)
server_scale=re.search(r'^local SCALE=([\d.]+)',(GAME/'server/modules/casino_blackjack.lua').read_text(),re.M).group(1)
assert client_scale==server_scale,(client_scale,server_scale)
print(f'dealer NPC scale matches the client tables ({server_scale})')
