#!/usr/bin/env python3
"""Pool table on the real board/tabletop server modules (no money involved).

Reuses the mock host of tools/test-tabletop-extra-server.py: placement, seats,
modes (solo practice and 1v1 only), shot validation (seat, turn, numbers, the
shot in flight), replayed requests (revision), ball in hand, re-racks, the
persisted row, and the size and nesting of the state a client receives.
"""
from pathlib import Path
import json
from lupa.lua54 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT/'resources/gamemodes/op77_lightrp'
source = (ROOT/'tools/test-tabletop-extra-server.py').read_text()
namespace = {'__file__': str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(source.split('SOURCES=')[0], namespace)
HARNESS = namespace['HARNESS']
SOURCES = [GAME/'shared/board_games_rules.lua', GAME/'shared/tabletop_extra_rules.lua', GAME/'shared/casino_pool.lua',
           GAME/'server/modules/tabletop_extra.lua', GAME/'server/modules/casino_pool.lua', GAME/'server/modules/board_games.lua']
EXTRA = r'''
P=LightRpPool
function view(id,player) return board(id,player).game end
function serverNow() return LightRP.tabletopExtra.now() end
function untilStill(id) local g=view(id);local e=P.endsAt(g);if wall<e then wall=e+1 end end
function shot(player,id,yaw,power) game(player,id,'shoot',{yaw=yaw,power=power}) end
'''


def environment():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpItems={}')
    lua.execute(HARNESS)
    lua.execute("LightRpBoardGames.pool=nil")
    for path in SOURCES:
        lua.execute(path.read_text(), name=path.name)
    lua.execute(EXTRA)
    lua.execute('modules.board_games.onDatabaseReady()')
    return lua


def scenario(name, script):
    lua = environment()
    lua.execute(script)
    print(name + ': passed')
    return lua


def pyvalue(v):
    if hasattr(v, 'items'):
        d = {k: pyvalue(x) for k, x in v.items()}
        if d and all(isinstance(k, int) for k in d):
            return [d[i] for i in sorted(d)]
        return {str(k): x for k, x in d.items()}
    return v


def depth(value):
    if isinstance(value, dict):
        return 1 + max((depth(v) for v in value.values()), default=0)
    if isinstance(value, list):
        return 1 + max((depth(v) for v in value), default=0)
    return 0


scenario('placement, seats and modes: 1v1 by default, solo practice for the owner, no 2v2', r'''
local id=place('pool',1)
local b=board(id);assert(b.kind=='pool' and b.mode=='duel' and b.game.phase=='break' and b.game.ply==0)
action(1,id,'join');action(2,id,'join');b=board(id)
assert(b.players.white==1 and b.players.black==2 and b.ready and b.actor==1,'white breaks')
action(3,id,'join');assert(notices[3]:find('All seats'))
action(1,id,'mode',{mode='teams'});assert(notices[1]:find('no such mode'),notices[1]);assert(board(id).mode=='duel')
action(2,id,'mode',{mode='solo'});assert(notices[2]:find('Only the owner'))
action(1,id,'mode',{mode='solo'});b=board(id);assert(b.mode=='solo' and b.game.mode=='solo' and b.players.white==1 and not b.players.black)
action(2,id,'join');assert(notices[2]:find('owner'),'practice is the owner\'s table')
-- Practice: the owner shoots alone (actor), turn always white.
b=board(id);assert(b.ready and b.actor==1)
shot(1,id,0,1);local g=view(id);assert(g.ply==1 and g.shot and g.turn=='white' and g.phase=='practice')
-- The mode locks once the break is played; New game (reset) reopens it.
action(1,id,'mode',{mode='duel'});assert(board(id).mode=='solo' and notices[1]:find('new game'))
untilStill(id);action(1,id,'reset');assert(view(id).ply==0 and view(id).phase=='break')
action(1,id,'mode',{mode='duel'});assert(board(id).mode=='duel')
''')

scenario('shots: only the seated player whose turn it is, valid numbers, nothing while balls roll, no replay', r'''
local id=place('pool',1);action(1,id,'join');action(2,id,'join')
local rev=board(id).revision
shot(2,id,0,1);assert(board(id).revision==rev and notices[2]:find('not your turn') or notices[2]:find('not your shot'),notices[2])
for _,bad in ipairs({{yaw='x',power=1},{yaw=0,power=2},{yaw=0,power=-1},{yaw=0/0,power=.5},{yaw=1e12,power=.5},{power=.5},{yaw=0}}) do
 game(1,id,'shoot',bad);assert(board(id).revision==rev,'refused: '..tostring(bad.yaw)..'/'..tostring(bad.power))
end
action(4,id,'game',{revision=rev,operation='shoot',data={yaw=0,power=1}});assert(board(id).revision==rev and notices[4]:find('Join'),'a stranger cannot shoot')
-- The break.
local before=wall
shot(1,id,0,1)
local b=board(id);local g=b.game
assert(b.revision==rev+1 and g.ply==1 and g.shot.by=='white' and g.shot.at>=before+P.LEAD and g.shot.dur>500)
assert(type(g.shot.segs)=='table' and #g.shot.segs==16 and type(g.shot.segs[1])=='string' and #g.shot.segs[1]>=P.REC)
assert(dbBoards[id].data.game.shot.n==1,'the shot is persisted with the table')
local found=false;for _,line in ipairs(logs) do if line:find('pool shot board='..id,1,true) then found=true end end;assert(found,'each shot is logged')
-- The same request again (same revision): refused, nothing simulated twice.
action(1,id,'game',{revision=rev,operation='shoot',data={yaw=10,power=.5}})
assert(board(id).revision==rev+1 and notices[1]:find('changed'),notices[1])
-- While the balls roll nobody shoots, even the right player with the new revision.
local turn=g.turn;local player=turn=='white' and 1 or 2
shot(player,id,0,.5);assert(board(id).revision==rev+1 and notices[player]:find('Wait for the balls'),notices[player])
untilStill(id)
if not g.inHand then shot(player,id,180,.3);assert(board(id).revision==rev+2,'after the balls stop the next shot runs') end
''')

scenario('ball in hand: the incoming player places the cue ball, then shoots; a won game re-racks', r'''
local id=place('pool',1);action(1,id,'join');action(2,id,'join')
-- A chosen layout (ball number -> {x,y}) written into the durable row and
-- reloaded, like a server restart would.
local function arrange(list,fields)
 local balls={};for i=1,16 do balls[i]=false end
 for n,p in pairs(list) do balls[n+1]={P.quantize(p[1]),P.quantize(p[2])} end
 local g=LightRpPool.copy(view(id));g.pos=P.encodePositions(balls)
 for k,v in pairs(fields or {}) do g[k]=v end
 return g
end
local function setGame(g)
 local row=dbBoards[id];row.data.game=g;modules.board_games.onDatabaseReady()
 action(1,id,'join');action(2,id,'join')
end
setGame(arrange({[0]={-.3,-.3},[3]={.6,.4},[12]={.5,-.4}},{phase='play',solids='white',turn='white'}))
local rev=board(id).revision
shot(1,id,math.deg(math.atan(-P.Y+.3,-P.X+.3)),.8)
local g=view(id);assert(g.last.foul=='scratch' and g.inHand=='table' and g.turn=='black',tostring(g.last.foul))
untilStill(id)
game(1,id,'place',{x=-5000,y=0});assert(view(id).inHand,'white may not place for black')
game(2,id,'shoot',{yaw=0,power=.5});assert(view(id).inHand and notices[2]:find('Place the cue ball'),notices[2])
game(2,id,'place',{x='a',y=0});game(2,id,'place',{x=99999999,y=0});assert(view(id).inHand)
game(2,id,'place',{x=-5000,y=0});g=view(id);assert(not g.inHand and P.decodePositions(g.pos)[1][1]==-.5)
-- Black pots the 8 too early: white wins; nobody shoots; either player re-racks.
setGame(arrange({[0]={0,0},[8]={.5,.25},[3]={-.6,-.4},[12]={.5,-.4}},{phase='play',solids='white',turn='black'}))
shot(2,id,math.deg(math.atan(.25,.5)),.4);g=view(id)
assert(g.status=='won' and g.winner=='white' and g.last.reason=='eight_early')
untilStill(id);shot(1,id,0,.5);assert(view(id).status=='won')
game(2,id,'rerack',{});g=view(id);assert(g.status=='playing' and g.rack==2 and g.breaker=='black' and g.turn=='black' and board(id).actor==2)
''')

lua = scenario('the state a client receives stays small and shallow after the hardest break', r'''
worstId=place('pool',1);action(1,worstId,'join');action(2,worstId,'join')
shot(1,worstId,0,1)
''')
entry = next(b for b in lua.eval('list(1)').values() if b['id'] == lua.eval('worstId'))
value = pyvalue(entry)
size = len(json.dumps(value, separators=(',', ':')))
# A state part is payload > boards > board > game ...: the client drops events deeper than 7 tables.
assert depth({'boards': [value]}) <= 7, depth({'boards': [value]})
assert 'gameJson' not in value and size < 3000, size
print(f'public board entry after a full-power break: {size} bytes, payload depth {depth({"boards": [value]})} (limits: ~3 KB, 7)')
print('Pool server: placement, modes, shot validation, replay, ball in hand, win and re-rack, state size: OK')
