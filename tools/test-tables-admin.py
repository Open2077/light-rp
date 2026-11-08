#!/usr/bin/env python3
"""Owner-only pickup and the staff management of placed tables (list / go to /
remove), on the real board, tabletop, roulette and blackjack modules plus the
real server/modules/board_games_admin.lua.

Reuses the mock host of tools/test-tabletop-extra-server.py (atomic commits of
board rows, inventories and claims) and adds the staff desk around it: ACL
grants per player, lightrp_staff_audit rows, Staff.moveTo, chat commands.
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'resources/gamemodes/op77_lightrp'
namespace={'__file__':str(ROOT/'tools/test-tabletop-extra-server.py')}
exec((ROOT/'tools/test-tabletop-extra-server.py').read_text().split('SOURCES=')[0],namespace)
HARNESS=namespace['HARNESS']
SOURCES=[GAME/'shared/board_games_rules.lua',GAME/'shared/tabletop_extra_rules.lua',GAME/'shared/casino_blackjack.lua',
         GAME/'server/modules/tabletop_extra.lua',GAME/'server/modules/casino_blackjack.lua',GAME/'server/modules/board_games.lua']
ADMIN=GAME/'server/modules/board_games_admin.lua'
DESK=r'''
local I,Db=LightRP.inventory,LightRP.db
-- Inventories the host has loaded: a character's, while it is online.
function I.get(id) for _,inv in pairs(inventories) do if inv.id==id then return inv end end end
function I.playerId(player) return inventories[player] and inventories[player].id end
function I.place(draft,name,count) for i=1,draft.slots do if not draft.items[i] then draft.items[i]={name=name,count=count};return count end end;return 0 end
function I.canHold(inv,name,count) for i=1,inv.slots do if not inv.items[i] then return true end end;return false,'no_room' end
Open77.routingBuckets={getPlayer=function(id) return positions[id] and positions[id].bucket end}
function GetPlayerName(id) return 'Account'..id end
-- ACL: grants[player][right] (rights of LightRpSupportConfig.permissions).
grants={}
for i=1,5 do grants[i]={} end
characters={};for i=1,5 do characters[i]={identifier='acc'..i,key='default'} end
LightRP.support={
 allowed=function(player,right) return grants[player] and grants[player][right]==true or false end,
 identity=function(player) local c=characters[player];return c,c and c.identifier end,
 text=function(v,max,min) if type(v)~='string' or #v<(min or 1) or #v>max then return nil end;return v end,
}
LightRP.admin={handlers={}}
LightRP.characters={displayName=function(id) return 'Char '..id end}
chat={};LightRP.chat={system=function(id,text) chat[id]=chat[id] or {};table.insert(chat[id],text) end}
moves={}
LightRP.staff={moveTo=function(player,position,heading,cb,bucket) moves[#moves+1]={player=player,position=position,heading=heading,bucket=bucket};cb(not refuseMove,refuseMove) end}
commands={};function LightRP.command(name,opts,fn) commands[name]={opts=opts,fn=fn} end
function command(player,line)
 local args={};for word in line:gmatch('%S+') do args[#args+1]=word end
 local name=table.remove(args,1);local c=commands[name];assert(c and c.opts.restricted==true,'restricted command '..tostring(name))
 return c.fn(player,args,line)
end
-- lightrp_staff_audit (UNIQUE actor_id, request_key) and inventory labels.
audit={};auditOrder={};labels={}
function Db.run(sql,v)
 if failAudit then return false,'db_error' end
 if sql:find('INSERT INTO lightrp_staff_audit',1,true) then
  local key=v[1]..'|'..v[9];if audit[key] then return false,'duplicate' end
  audit[key]={actor_id=v[1],actor_name=v[2],target_id=v[3],target_name=v[4],character_key=v[5],action=v[6],reason=v[7],detail=v[8],outcome='pending'}
  auditOrder[#auditOrder+1]=audit[key];return true,1
 elseif sql:find('UPDATE lightrp_staff_audit',1,true) then
  local row=audit[v[3]..'|'..v[4]];row.outcome,row.detail=v[1],v[2];return true,1
 end
 error('unhandled run '..sql)
end
local read=Db.read
function Db.read(sql,v)
 if sql:find('FROM lightrp_staff_audit',1,true) then local row=audit[v[1]..'|'..v[2]];return true,{row} end
 if sql:find('JOIN lightrp_inventories',1,true) then
  local out={};for _,row in pairs(dbBoards) do if labels[row.owner_inventory] then out[#out+1]={id=row.owner_inventory,label=labels[row.owner_inventory]} end end;return true,out
 end
 return read(sql,v)
end
-- Open77.npcs mock, as in tools/test-casino-blackjack-server.py.
npcBodies={};npcNext=0
Open77.npcs={ai={tasks=0,frozen=1,native=2},damage={mortal=0,immortal=1,invulnerable=2},tasks={}}
function Open77.npcs.create(def) npcNext=npcNext+1;npcBodies[npcNext]={def=def};return npcNext end
function Open77.npcs.remove(id) if not npcBodies[id] then return false,'npc_not_found' end;npcBodies[id]=nil;return true end
function Open77.npcs.setAIEnabled() return true end
function Open77.npcs.tasks.clear() return true end
function Open77.npcs.setTransform() return true end
function Open77.npcs.tasks.playAnimation() return 1 end
function GetCurrentResourceName() return 'op77_lightrp' end
function bodies() local n=0;for _ in pairs(npcBodies) do n=n+1 end;return n end
function dealerTick() LightRpBlackjack.dealerTick(LightRP.tabletopExtra.now()) end
H=function() return LightRP.admin.handlers end
function mkey() keySeq=(keySeq or 0)+1;return 'desk:test:'..keySeq end
function act(player,op,row,extra)
 local p={action=op,table=row.id,kind=row.kind,confirmed=true,reason='Testing the desk',mutation=mkey()}
 for k,v in pairs(extra or {}) do p[k]=v end
 return H().tableAction(player,p)
end
function rows(player,p) local r,why=H().tables(player,p or {});assert(r,why);return r end
function find(player,id) for _,r in ipairs(rows(player,{search=id}).tables) do if r.id==id then return r end end end
-- Nesting depth of a payload, the way the 176 client counts it (<= 7 tables).
function depth(t) if type(t)~='table' then return 0 end;local d=0;for _,v in pairs(t) do d=math.max(d,depth(v)) end;return d+1 end
function staff(player,rights) for _,r in ipairs(rights) do grants[player][r]=true end end
function claimsFor(inventory) local n=0;for _,row in pairs(dbClaims) do if row.inventory_id==inventory and row.round_key:find(':refund',1,true) then n=n+row.amount end end;return n end
'''
def environment():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpItems={}')
    lua.execute(HARNESS)
    lua.execute(DESK)
    for path in SOURCES: lua.execute(path.read_text())
    lua.execute(ADMIN.read_text())
    lua.execute('modules.board_games.onDatabaseReady()')
    def restart():
        lua.execute('tasks={};npcBodies={}')
        for path in SOURCES: lua.execute(path.read_text())
        lua.execute('LightRP.admin={handlers={}}')
        lua.execute(ADMIN.read_text())
        lua.execute('modules.board_games.onDatabaseReady()')
    lua.globals().restart=restart
    return lua
def scenario(name,script):
    lua=environment();lua.execute(script);print(name+': passed');return lua

scenario('pickup: only the character that placed the table, with a clear notice',r'''
local id=place('roulette',1)
assert(board(id,1).owned==true and board(id,2).owned==false,'the ALT row follows `owned`')
-- Another player.
action(2,id,'pickup');assert(board(id) and itemCount(2,'roulette_board')==1)
assert(notices[2]=='Only the character who placed this table can pick it up.',notices[2])
-- The same player (same account) on another character slot.
local own=inventories[1]
modules.board_games.onDisconnected(1)
inventories[1]={id='player:acc1#second',persistent=true,slots=10,kind='player',items={[2]={name='cash',count=50}}}
modules.board_games.onCharacterLoaded(1)
assert(board(id,1).owned==false,'another character does not own it')
notices[1]=nil;action(1,id,'pickup');assert(board(id) and itemCount(1,'roulette_board')==0)
assert(notices[1]:find('Only the character who placed',1,true),notices[1])
-- Reset/mode stay owner-only too (they can refund and wipe a game).
action(1,id,'reset');assert(notices[1]:find('Only the owner',1,true))
-- Back on the placing character: allowed.
inventories[1]=own;modules.board_games.onCharacterLoaded(1)
assert(board(id,1).owned==true)
action(1,id,'pickup');assert(not board(id) and itemCount(1,'roulette_board')==1)
''')

scenario('list: desk permission, flat paginated rows, owners, seats, money in play',r'''
assert(H().tables(4,{})==nil,'no grant: refused')
staff(4,{'tables'});assert(H().tables(4,{})==nil,'the desk view right is required too')
staff(4,{'view'})
local id=place('roulette',1);action(1,id,'join');action(2,id,'join')
game(1,id,'bet',{bet='red',amount=25});game(2,id,'bet',{bet=4,amount=40})
labels['inv3']='Offline Owner'
local other=place('roulette',3,10,0);modules.board_games.onDisconnected(3);inventories[3]=nil
local r=find(4,id)
assert(r.owner=='Char 1' and r.online==1 and r.inventory=='inv1' and r.kind=='roulette' and r.title==LightRP.boardGames.title('roulette'))
assert(r.seatedCount==2 and r.seated=='#2 Char 2, #1 Char 1',r.seated) -- seats sorted: black, white
assert(r.stakes==65 and r.resolving==nil and r.phase=='betting' and r.bucket==0 and r.placedAt and r.revision>0)
local o=find(4,other);assert(o.owner=='Offline Owner' and o.online==nil and o.stakes==0)
-- A spin in progress: the money is resolving and the row says so.
game(1,id,'spin',{});r=find(4,id);assert(r.stakes==nil and r.resolving:find('spin',1,true),tostring(r.resolving))
-- Pagination: 15 rows a page, flat (payload > data > tables > row).
for i=1,20 do place('roulette',5,i*3,40) end
local first=rows(4,{page=1});assert(first.total==22 and #first.tables==15 and first.pageSize==15)
local second=rows(4,{page=2});assert(#second.tables==7)
assert(depth({kind='response',data=first})<=4,'flat rows: '..depth({data=first}))
for _,row in ipairs(first.tables) do for k,v in pairs(row) do assert(type(v)~='table',k) end end
-- Nearest first, from the staff member's own position and instance.
positions[4]={x=60,y=40,z=0,bucket=0}
local near=rows(4,{sort='near'}).tables;assert(near[1].x==60 and near[1].distance==0,near[1].x)
assert(first.canTeleport==false and first.canDelete==false)
staff(4,{'tableTeleport','tableDelete'});local p=rows(4,{});assert(p.canTeleport and p.canDelete)
''')

scenario('go to: lands beside the table facing it, audited, instance rules',r'''
staff(4,{'view','tables'})
local id=place('blackjack',1,10,20);local row=find(4,id)
assert(act(4,'tableTeleport',row)==nil,'tableTeleport right required')
staff(4,{'tableTeleport'})
-- The reason is optional since aed8bf75 (owner, 2026-11-05): it acts at once, the staff history keeps a default line.
local quick=H().tableAction(4,{action='tableTeleport',table=id,kind='blackjack',confirmed=true,mutation=mkey()})
assert(quick and quick.accepted and auditOrder[#auditOrder].reason=='Go to table via /admin.','no reason needed')
assert(H().tableAction(4,{action='tableTeleport',table=id,kind='roulette',confirmed=true,reason='stale kind',mutation=mkey()})==nil,'stale selection refused')
local result=act(4,'tableTeleport',row)
assert(result.accepted and result.outcome=='success',result.message)
local m=moves[#moves];assert(m.player==4 and m.bucket==nil)
local d=math.sqrt((m.position.x-10)^2+(m.position.y-20)^2)
assert(d>1.4 and d<1.7 and m.position.y<20 and m.heading==0,'in front of the players edge, outside the collider: '..d)
local entry=auditOrder[#auditOrder];assert(entry.action=='tableTeleport' and entry.outcome=='success' and entry.actor_name=='Account4' and entry.target_id=='inv1' and entry.character_key==id)
-- Rotation 90: the landing turns with the table.
local landing,heading=modules.board_games_admin.landing({kind='chess',position={x=0,y=0,z=1},rotation=90})
assert(math.abs(landing.x-1.3)<1e-9 and math.abs(landing.y)<1e-9 and heading==90 and landing.z>1)
-- From a private instance back to the city: allowed, lands in bucket 0.
positions[4].bucket=9;result=act(4,'tableTeleport',row);assert(result.accepted and moves[#moves].bucket==0)
-- Into another private instance: refused, nothing moved.
local count=#moves
positions[1].bucket=7;local inside=place('roulette',1,0,0);positions[4].bucket=0
result=act(4,'tableTeleport',find(4,inside));assert(not result.accepted and result.message:find('instance 7',1,true) and #moves==count)
assert(auditOrder[#auditOrder].outcome=='failed')
-- A replayed desk request does not move twice.
local p={action='tableTeleport',table=id,kind='blackjack',confirmed=true,reason='Replay test',mutation='desk:replay:1'}
H().tableAction(4,p);count=#moves;local again=H().tableAction(4,p);assert(#moves==count and again.outcome=='success')
''')

scenario('remove: refunds, seated players, dealer NPC, permissions, busy and spinning tables',r'''
staff(4,{'view','tables','tableTeleport'})
local id=place('roulette',1);action(1,id,'join');action(2,id,'join')
game(1,id,'bet',{bet='red',amount=25});game(2,id,'bet',{bet=4,amount=40})
local row=find(4,id)
assert(act(4,'tableDelete',row)==nil and board(id),'tableDelete right required')
staff(4,{'tableDelete'})
-- A spinning wheel blocks the removal: nothing changes, the audit says why.
fixedOutcome(0) -- red and 4 lose: only refunds reach the wallets below
game(1,id,'spin',{});local before=commits
local result=act(4,'tableDelete',row);assert(not result.accepted and result.message:find('spin',1,true) and board(id) and commits==before,result.message)
assert(auditOrder[#auditOrder].outcome=='failed')
wall=board(id).game.spin.endsAt;assert(step(2000));assert(board(id).game.phase=='result');game(1,id,'nextRound',{})
game(1,id,'bet',{bet='red',amount=25});game(2,id,'bet',{bet=4,amount=40})
assert(cash(1)==950 and cash(2)==920,cash(1)..' '..cash(2))
-- A busy table (a move saving) is refused too.
LightRP.boardGames.get(id).busy=true;result=act(4,'tableDelete',row);assert(not result.accepted and board(id));LightRP.boardGames.get(id).busy=nil
-- Storage refusal: atomic, nothing removed, nothing refunded.
failDB=true;result=act(4,'tableDelete',row);failDB=false;assert(not result.accepted and board(id) and claimsFor('inv1')==0)
notices[1],notices[2]=nil,nil
result=act(4,'tableDelete',row)
assert(result.accepted and result.message:find('Refunded',1,true) and result.message:find('2 seated',1,true),result.message)
assert(not board(id) and dbBoards[id]==nil,'board and row gone')
assert(claimsFor('inv1')==25 and claimsFor('inv2')==40,'open stakes refunded exactly like pickup')
assert(notices[2]:find('A staff member removed this',1,true) and notices[2]:find('You left your seat',1,true),notices[2])
LightRP.tabletopExtra.claim(1);LightRP.tabletopExtra.claim(2);assert(cash(1)==975 and cash(2)==960)
assert(itemCount(1,'roulette_board')==0,'no return asked: the item is not given back')
local entry=auditOrder[#auditOrder];assert(entry.action=='tableDelete' and entry.outcome=='success' and entry.detail:find('no return',1,true))
-- Blackjack mid-round: stakes refunded, dealer NPC removed, seats freed.
LightRpBlackjack.shuffle=function() local s={'9C','7D','5H','6S','8C','4D'};for i=7,312 do s[i]='2C' end;return s end
local bj=place('blackjack',3,20,0);dealerTick();assert(bodies()==1);positions[5]={x=20,y=1,z=0,bucket=0}
action(3,bj,'join');action(5,bj,'join');game(3,bj,'bet',{amount=30});game(5,bj,'bet',{amount=20})
game(3,bj,'deal',{});assert(board(bj).game.phase=='playing',board(bj).game.phase)
result=act(4,'tableDelete',find(4,bj),{returnItem=true})
assert(result.accepted and bodies()==0 and next(LightRpBlackjack.dealers)==nil,result.message)
assert(claimsFor('inv3')==30 and claimsFor('inv5')==20 and itemCount(3,'blackjack_table')==1,'returned to the online owner in the same commit')
assert(notices[3]:find('back in your inventory',1,true),notices[3])
''')

scenario('remove with return: offline owner gets a pending return, delivered on next load, survives a restart',r'''
staff(4,{'view','tables','tableDelete'})
local id=place('roulette',3);local saved=inventories[3]
modules.board_games.onDisconnected(3);inventories[3]=nil
local result=act(4,'tableDelete',find(4,id),{returnItem=true})
assert(result.accepted and result.message:find('next loaded',1,true),result.message)
assert(not board(id) and dbBoards[id].data.returnPending==true and dbBoards[id].data.kind=='roulette')
assert(LightRP.boardGames.pendingReturns()==1 and rows(4).pendingReturns==1)
restart()
assert(LightRP.boardGames.pendingReturns()==1 and #list(1)==0,'a pending return is not a placed table')
-- Back with a full inventory: told to free a slot, kept pending.
saved.items={};for i=1,10 do saved.items[i]={name='cash',count=1} end
inventories[3]=saved;modules.board_games.onCharacterLoaded(3)
assert(dbBoards[id] and notices[3]:find('Free an inventory slot',1,true),notices[3])
-- A free slot: the 30 s retry (or the next load) delivers it once.
saved.items[10]=nil;modules.board_games.onCharacterLoaded(3)
assert(itemCount(3,'roulette_board')==1 and dbBoards[id]==nil and LightRP.boardGames.pendingReturns()==0)
modules.board_games.onCharacterLoaded(3);assert(itemCount(3,'roulette_board')==1,'delivered exactly once')
-- Another character of the same account never receives it.
local other=place('roulette',2);modules.board_games.onDisconnected(2);local mine=inventories[2];inventories[2]=nil
act(4,'tableDelete',find(4,other),{returnItem=true})
inventories[2]={id='player:acc2#second',persistent=true,slots=10,kind='player',items={}};modules.board_games.onCharacterLoaded(2)
assert(itemCount(2,'roulette_board')==0 and dbBoards[other])
inventories[2]=mine;mine.items={};modules.board_games.onCharacterLoaded(2);assert(itemCount(2,'roulette_board')==1 and not dbBoards[other])
''')

scenario('/lightrp.tables: list, near, tp, delete [return], ACL',r'''
local id=place('roulette',1,5,5)
assert(commands['lightrp.tables'].opts.restricted==true)
local ok,text=command(4,'lightrp.tables');assert(ok==false and text:find('permission',1,true))
staff(4,{'tables','tableTeleport'}) -- one ACL permission in the config: command.lightrp.tables
ok,text=command(4,'lightrp.tables');assert(ok and #chat[4]==2 and chat[4][2]:find(id,1,true) and chat[4][2]:find('Char 1',1,true),chat[4][2])
chat[4]={};positions[4]={x=5,y=6,z=0,bucket=0};ok=command(4,'lightrp.tables near');assert(ok and chat[4][2]:find('1.0 m',1,true),chat[4][2])
ok,text=command(4,'lightrp.tables tp '..id);assert(ok and moves[#moves].player==4,text)
ok,text=command(4,'lightrp.tables delete '..id);assert(not ok and board(id),'delete needs command.lightrp.tabledelete')
staff(4,{'tableDelete'})
ok,text=command(4,'lightrp.tables delete nope');assert(not ok and text:find('No placed table',1,true))
ok,text=command(4,'lightrp.tables delete '..id..' return');assert(ok and not board(id) and itemCount(1,'roulette_board')==1,text)
local entry=auditOrder[#auditOrder];assert(entry.action=='tableDelete' and entry.reason:find('/lightrp.tables delete',1,true) and entry.outcome=='success')
-- The server console may list and remove, not teleport.
local other=place('roulette',2,9,9)
ok,text=command(0,'lightrp.tables tp '..other);assert(not ok)
ok,text=command(0,'lightrp.tables delete '..other);assert(ok and not board(other) and auditOrder[#auditOrder].actor_id=='console')
''')
