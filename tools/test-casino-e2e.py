#!/usr/bin/env python3
"""End-to-end casino tables: the REAL server and the REAL client, wired together.

Two Lua states (lupa). The server state runs server/modules/{tabletop_extra,
casino_*,board_games}.lua on the mock host of tools/test-tabletop-extra-server.py
(atomic inventory/board/claim commits); the client state runs
client/core/{tabletop_extra,casino_*,board_games}.lua on the mock SDK of
tools/test-board-games-client.py. Between them:

* every server TriggerClientEvent and every client TriggerServerEvent is
  JSON-encoded and decoded (python json) like the platform's event codec: an
  empty Lua table becomes {}, a table with holes or extra keys an object with
  string keys, and numbers come back as floats (E2E_FLOATS=0 keeps integers);
  events arrive in order after E2E_LATENCY ms;
* the page's view payload (lightrp:boardGames:view) and page actions are JSON
  round-tripped the same way;
* one simulated wall clock drives both sides; the client's GetGameTimer has an
  unrelated origin (E2E_OFFSET), so only board.serverNow links the two;
* server threads honour Wait(ms) (2 s board loop, 1 s claim loop); client
  threads honour Wait(ms) at E2E_FPS frames, every resume (threads, net event
  handlers, page handlers) metered at BOARD_BUDGET instructions;
* native props load asynchronously: a model's first spawn renders after
  E2E_LOAD_FIRST ms (the 3 MB table packs after E2E_LOAD_TABLE ms), later
  spawns after E2E_LOAD_AGAIN ms; setTransform moves position+yaw only.

Scenarios assert what the player SEES: native props (model and board-local
position), and what the page receives (view.extra).
"""
from pathlib import Path
import json, math, os, sys
import lupa.lua54 as lupa
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT/'resources/gamemodes/op77_lightrp'
FLOATS = os.getenv('E2E_FLOATS', '1') != '0'
LATENCY = int(os.getenv('E2E_LATENCY', '60'))
OFFSET = int(os.getenv('E2E_OFFSET', '-1790000000000'))   # client timer = wall + OFFSET (+ start skew)
FPS = float(os.getenv('E2E_FPS', '60'))
LOAD_FIRST = int(os.getenv('E2E_LOAD_FIRST', '400'))
# Slow by default: the live 3 MB blackjack pack took longer than the old 3 s
# render grace, which hid the ghost (no placement) and the dealt cards.
LOAD_TABLE = int(os.getenv('E2E_LOAD_TABLE', '6000'))
LOAD_AGAIN = int(os.getenv('E2E_LOAD_AGAIN', '4000'))
VERBOSE = os.getenv('E2E_VERBOSE') == '1'
SCALE = .65

# --- the platform's JSON event codec ----------------------------------------------------
def to_py(value, path='$'):
    kind = lupa.lua_type(value)
    if kind == 'table':
        items = list(value.items())
        if not items:
            return {}
        keys = [k for k, _ in items]
        if all(type(k) is int for k in keys) and sorted(keys) == list(range(1, len(keys)+1)):
            d = dict(items)
            return [to_py(d[i], f'{path}[{i}]') for i in range(1, len(keys)+1)]
        out = {}
        for k, v in items:
            if type(k) not in (int, str):
                raise TypeError(f'{path}: key {k!r} is not a string or integer')
            out[str(k)] = to_py(v, f'{path}.{k}')
        return out
    if kind is not None:
        raise TypeError(f'{path}: a Lua {kind} cannot cross the event codec')
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError(f'{path}: non-finite number')
    return value

def to_lua(rt, value, floats):
    if isinstance(value, dict):
        t = rt.table()
        for k, v in value.items():
            t[k] = to_lua(rt, v, floats)
        return t
    if isinstance(value, list):
        t = rt.table()
        for i, v in enumerate(value):
            t[i+1] = to_lua(rt, v, floats)
        return t
    if floats and type(value) is int:
        return float(value)
    return value

def json_depth(value):
    if isinstance(value, dict):
        return 1 + max((json_depth(v) for v in value.values()), default=0)
    if isinstance(value, list):
        return 1 + max((json_depth(v) for v in value), default=0)
    return 0

def roundtrip(rt, value, floats=FLOATS, limit=None):
    text = json.dumps(to_py(value), separators=(',', ':'))
    if limit and len(text) > limit:
        raise AssertionError(f'event payload {len(text)} bytes exceeds {limit}')
    return to_lua(rt, json.loads(text), floats), len(text)

# --- server state ------------------------------------------------------------------------
server_source = (ROOT/'tools/test-tabletop-extra-server.py').read_text()
ns = {'__file__': str(ROOT/'tools/test-tabletop-extra-server.py')}
exec(server_source.split('SOURCES=')[0], ns)
SERVER_HARNESS = ns['HARNESS']
SERVER_SOURCES = ['shared/board_games.lua', 'shared/board_games_rules.lua', 'shared/tabletop_extra.lua',
                  'shared/tabletop_extra_rules.lua', 'shared/casino_slots.lua', 'shared/casino_blackjack.lua',
                  'shared/casino_fortune.lua', 'server/modules/tabletop_extra.lua', 'server/modules/casino_slots.lua',
                  'server/modules/casino_blackjack.lua', 'server/modules/casino_fortune.lua', 'server/modules/board_games.lua']
SERVER_HOST = r'''
-- One player in the world; the harness keeps inventories 1..5.
function GetPlayers() return {'1'} end
-- Threads honour Wait(ms) on the simulated wall clock.
serverTasks={}
function CreateThread(fn) serverTasks[#serverTasks+1]={co=coroutine.create(fn),wake=wall} end
function Wait(ms) coroutine.yield(ms or 0) end
function serverFrame()
 local n=#serverTasks
 for i=1,n do local t=serverTasks[i]
  if t and t.wake<=wall and coroutine.status(t.co)~='dead' then
   local ok,delay=coroutine.resume(t.co);assert(ok,delay)
   t.wake=wall+math.max(1,tonumber(delay) or 0)
  end
 end
 for i=#serverTasks,1,-1 do if coroutine.status(serverTasks[i].co)=='dead' then table.remove(serverTasks,i) end end
end
function LightRP.nowMs() return wall-1790000000000 end
function LightRP.log(format,...) local line=string.format(format,...);logs[#logs+1]=line;if E2E_VERBOSE then print('[server] '..line) end end
function TriggerClientEvent(name,id,data) return bridgeToClient(name,id,data) end
function serverRequest(player,payload) source=player;handlers['lightrp:boardGames:request'](payload) end
function useItem(player,item) return uses[item](player) end
LightRpBoardGames=nil
'''

# --- client state ------------------------------------------------------------------------
client_source = (ROOT/'tools/test-board-games-client.py').read_text()
CLIENT_SOURCES = ['shared/board_games.lua', 'shared/tabletop_extra.lua', 'shared/tabletop_extra_rules.lua',
                  'shared/casino_slots.lua', 'shared/casino_blackjack.lua', 'shared/casino_fortune.lua',
                  'client/core/tabletop_extra.lua', 'client/core/casino_slots.lua', 'client/core/casino_blackjack.lua',
                  'client/core/casino_fortune.lua', 'client/core/board_games.lua']
CLIENT_HOST = r'''
LightRpBoardGames={};LightRpItems={}
Open77.network.status=function() return {playerId=1} end
gameTimer=0
function GetGameTimer() return gameTimer end
clock=nil
logs={}
function LightRpUi.log(...) local line=string.format(...);logs[#logs+1]=line;if E2E_VERBOSE then print('[client] '..line) end end
function LightRpUi.send(name,p)
 if name=='lightrp:boardGames:view' then pageView(p)
 elseif name=='notice' then lastNotice=p.body;notices[#notices+1]=p.body;if E2E_VERBOSE then print('[notice] '..tostring(p.body)) end
 elseif name=='dialogClose' then closeRequest=p end
end
notices={}
function TriggerServerEvent(name,p)
 if p.action=='diagnostic' then diagnostics[#diagnostics+1]=p;if E2E_VERBOSE then print('[diag] '..tostring(p.reason)..' '..tostring(p.details)) end end
 return bridgeToServer(name,p)
end
-- Threads honour Wait(ms); every resume is metered like the 176 client.
threads={}
function CreateThread(f) threads[#threads+1]={co=coroutine.create(f),wake=gameTimer} end
function Wait(ms) coroutine.yield(ms or 0) end
local function metered(co,...)
 local count=0;nativeCreatesInResume=0
 debug.sethook(co,function()
  count=count+100
  if count>=BOARD_BUDGET then debug.sethook();error('Open77 script execution budget exceeded '..debug.traceback('',2),0) end
 end,'',100)
 local result=table.pack(coroutine.resume(co,...))
 debug.sethook(co)
 peakInstructions=math.max(peakInstructions,count)
 assert(nativeCreatesInResume<=1,'native spawns must be staggered across resumes')
 assert(result[1],result[2])
 return table.unpack(result,2,result.n)
end
function clientFrame(now)
 gameTimer=now
 local n=#threads
 for i=1,n do local t=threads[i]
  if t and t.wake<=now and coroutine.status(t.co)~='dead' then
   local delay=metered(t.co)
   t.wake=now+math.max(.001,tonumber(delay) or 0)
  end
 end
 for i=#threads,1,-1 do if coroutine.status(threads[i].co)=='dead' then table.remove(threads,i) end end
end
-- Net event and page handlers run in their own metered resume.
function callMetered(fn,arg) metered(coroutine.create(fn),arg) end
function netEvent(name,payload) local fn=assert(events[name],'no client handler '..name);callMetered(fn,payload) end
function pageEvent(name,payload) local fn=assert(pageHandlers[name],'no page handler '..name);callMetered(fn,payload) end
-- Native props: asynchronous loading, transform history, the 256-per-owner quota.
nativeProps,modelReadyAt,nextNativeId={},{},0
DEPOTS={'open77\\assets\\op77_lightrp\\casino_blackjack\\','open77\\assets\\op77_lightrp\\casino_slots\\',
 'open77\\assets\\op77_lightrp\\casino_fortune\\','open77\\assets\\op77_lightrp\\tabletop_extra\\','open77\\assets\\op77_lightrp\\board_games\\'}
function Open77.props.create(o)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 local ok=false;for _,d in ipairs(DEPOTS) do if o.model:find(d,1,true)==1 then ok=true end end
 assert(ok,'unexpected depot '..tostring(o.model))
 assert(o.model:sub(-4)=='.ent' and o.kind=='prop' and o.scale==.65 and o.collision==false and o.physics=='none')
 local name=o.model:match('([^\\]+)%.ent$')
 assert(availableModels[name],'native asset missing from the cooked packages: '..name)
 local count=0;for _ in pairs(nativeProps) do count=count+1 end
 if count>=256 then return nil,'quota_exceeded' end
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local ready=modelReadyAt[name]
 if not ready then ready=gameTimer+(heavyModels[name] and LOAD_TABLE or LOAD_FIRST);modelReadyAt[name]=ready end
 nativeProps[id]={id=id,name=name,model=o.model,position={x=o.position.x,y=o.position.y,z=o.position.z},yaw=o.yaw,
  readyAt=math.max(ready,gameTimer+LOAD_AGAIN),created=gameTimer,failed=false,backend='raw_entity',moves=0}
 createdProps=createdProps+1
 return id
end
function Open77.props.setTransform(id,t)
 local row=nativeProps[id];if not row then return false,'not_found' end
 -- E2E_LOST_TRANSFORMS: an entity still streaming in ignores the move (answers true).
 if LOST_TRANSFORMS and gameTimer<row.readyAt then row.lost=(row.lost or 0)+1;return true end
 row.position={x=t.position.x,y=t.position.y,z=t.position.z};row.yaw=t.yaw or row.yaw;row.moves=row.moves+1
 movedProps=movedProps+1;return true
end
function Open77.props.remove(id)
 if not nativeProps[id] then return false,'not_found' end
 nativeProps[id]=nil;removedProps=removedProps+1;return true
end
function Open77.props.list()
 local out={}
 for _,row in pairs(nativeProps) do
  out[#out+1]={id=row.id,model=row.model,kind='prop',position=row.position,yaw=row.yaw,backend=row.backend,
   rendered=gameTimer>=row.readyAt,failed=row.failed}
 end
 return out
end
function Open77.camera.screenRaycast() return {hit=true,position={x=placeAt.x,y=placeAt.y,z=placeAt.z}} end
placeAt={x=0,y=0,z=0}
'''

class Sim:
    """Both runtimes on one wall clock, with the network between them."""
    def __init__(self, models_heavy=('blackjack_table', 'fortune_stand', 'slot_cabinet'), rows=(), at=None):
        self.wall = 1790000000000
        self.client_skew = 7_777    # the client booted at a different moment
        self.queue = []             # (deliverAt, side, name, payload_json)
        self.views = []             # (wall, view dict) as the page receives them
        self.sizes = {'state': 0, 'request': 0, 'view': 0}
        self.dropped = []   # events the 176 client would reject as malformed
        self.client_requests = []
        self.dropped = []
        # Server
        s = self.server = LuaRuntime(unpack_returned_tuples=True)
        s.execute('LightRpItems={}')
        s.execute(SERVER_HARNESS)
        s.globals().bridgeToClient = self._to_client
        s.globals().E2E_VERBOSE = VERBOSE
        s.execute(SERVER_HOST)
        s.globals().wall = self.wall
        # Real JSON on the server as well (board rows are stored as text).
        def encode(t):
            return json.dumps(to_py(t), separators=(',', ':'))
        def decode(text):
            return to_lua(s, json.loads(text), False)
        s.globals().json = s.table_from({'encode': encode, 'decode': decode})
        for name in SERVER_SOURCES:
            s.execute((GAME/name).read_text(), name=name)
        # Client
        cns = {'__file__': str(ROOT/'tools/test-board-games-client.py')}
        exec(client_source.split("for name in ['shared/board_game_models.lua'")[0], cns)
        c = self.client = cns['lua']
        g = c.globals()
        g.bridgeToServer = self._to_server
        g.pageView = self._page_view
        g.E2E_VERBOSE = VERBOSE
        g.LOAD_FIRST, g.LOAD_TABLE, g.LOAD_AGAIN = LOAD_FIRST, LOAD_TABLE, LOAD_AGAIN
        g.LOST_TRANSFORMS = os.getenv('E2E_LOST_TRANSFORMS') == '1'
        models = {}
        for pack in ('blackjack', 'slots', 'fortune'):
            manifest = json.loads((ROOT/f'resources/assets/models/open77_casino_{pack}/asset-manifest.json').read_text())
            for m in manifest['models']:
                models[m['name']] = True
        for pack in ('open77_tabletop_extra', 'open77_board_games'):
            manifest = json.loads((ROOT/f'resources/assets/models/{pack}/asset-manifest.json').read_text())
            for m in manifest.get('models', []):
                models[m['name']] = True
        g.availableModels = c.table_from(models)
        g.heavyModels = c.table_from({m: True for m in models_heavy})
        c.execute(CLIENT_HOST)
        # Open77.json on the client, like the game (deep games arrive as text).
        def cdecode(text):
            return to_lua(c, json.loads(text), FLOATS)
        def cencode(t):
            return json.dumps(to_py(t), separators=(',', ':'))
        c.globals().Open77.json = c.table_from({'decode': cdecode, 'encode': cencode})
        for name in CLIENT_SOURCES:
            c.execute((GAME/name).read_text(), name=name)
        c.execute('LightRpBoardGamesClient.bind(page);LightRpBoardGamesClient.start()')
        if at:
            self.server.execute(f"positions[1].x,positions[1].y,positions[1].z={at[0]},{at[1]},{at[2]}")
            self.client.execute(f"Open77.character.state().position={{x={at[0]},y={at[1]},z={at[2]}+.5}};placeAt={{x={at[0]},y={at[1]},z={at[2]}}}")
        # Rows persisted by an earlier server process (a restart reloads them).
        db = self.server.globals()['dbBoards']
        for board_id, owner, data in rows:
            db[board_id] = self.server.table_from({'id': board_id, 'owner_inventory': owner, 'data': data})
        self.server.execute('modules.board_games.onDatabaseReady()')
        self.frame_ms = 1000.0/FPS

    # -- clocks
    @property
    def client_now(self):
        return self.wall + OFFSET + self.client_skew

    def server_now(self):
        return int(self.server.eval('LightRP.tabletopExtra.now()'))

    # -- network
    def _to_client(self, name, player, data):
        text = json.dumps(to_py(data), separators=(',', ':'))
        if len(text) > 48*1024:
            raise AssertionError('Network event payload exceeds 48 KiB.')
        # The 176 client drops ("malformed network event payload") any event
        # nested deeper than 7 tables (measured live with /lightrp.netprobe).
        if json_depth(json.loads(text)) > 7:
            self.dropped.append((name, json_depth(json.loads(text))))
            return True
        self.sizes['state'] = max(self.sizes['state'], len(text))
        self.queue.append((self.wall + LATENCY, 'client', name, text))
        return True

    def _to_server(self, name, payload):
        text = json.dumps(to_py(payload), separators=(',', ':'))
        self.sizes['request'] = max(self.sizes['request'], len(text))
        self.client_requests.append(json.loads(text))
        self.queue.append((self.wall + LATENCY, 'server', name, text))
        return True

    def _page_view(self, payload):
        text = json.dumps(to_py(payload), separators=(',', ':'))
        self.sizes['view'] = max(self.sizes['view'], len(text))
        self.views.append((self.wall, json.loads(text)))

    def _deliver(self):
        due = [q for q in self.queue if q[0] <= self.wall]
        self.queue = [q for q in self.queue if q[0] > self.wall]
        for _, side, name, text in due:
            if side == 'client':
                payload = to_lua(self.client, json.loads(text), FLOATS)
                self.client.globals().netEvent(name, payload)
            else:
                payload = to_lua(self.server, json.loads(text), FLOATS)
                self.server.globals().serverRequest(1, payload)

    # -- time
    def advance(self, ms, until=None, label=None):
        end = self.wall + ms
        while self.wall < end:
            self.wall = min(end, self.wall + self.frame_ms)
            self.server.globals().wall = self.wall
            self._deliver()
            self.server.globals().serverFrame()
            self.client.globals().clientFrame(self.client_now)
            if until and until():
                return True
        if until:
            raise AssertionError(f'timed out waiting for {label or until}')
        return False

    def wait_for(self, predicate, label, limit=20000):
        if predicate():
            return
        self.advance(limit, until=predicate, label=label)

    def advance_to_server(self, ms_server):
        delta = ms_server - self.server_now()
        if delta > 0:
            self.advance(delta)

    # -- player input
    def press(self, key, hold_ms=60):
        keys = self.client.globals()['keys']
        keys[key] = True
        self.advance(hold_ms)
        keys[key] = False
        self.advance(self.frame_ms*2)

    def page(self, name, payload, think=400):
        # A human click: not within the server's 150 ms per-player request spacing.
        self.advance(think)
        lua_payload, _ = roundtrip(self.client, payload)
        self.client.globals().pageEvent(name, lua_payload)

    def interact(self, board_id):
        self.advance(400)
        point = self.client.eval(f'LightRpInteract.points["boardGames.{board_id}"]')
        assert point is not None, f'no interaction point for {board_id}'
        self.client.globals().callMetered(point.callback, None)

    # -- what the player sees
    def board(self, board_id):
        return self.client.eval(f'LightRpBoardGamesClient.boards["{board_id}"]')

    def props(self, board_id=None):
        """Native props as (name, local x, y, z, yaw) in the board's unscaled frame."""
        out = []
        b = self.board(board_id) if board_id else None
        for _, row in self.client.globals()['nativeProps'].items():
            p = row.position
            if b is not None:
                a = math.radians(b.rotation or 0)
                dx, dy = p.x - b.position.x, p.y - b.position.y
                x = (dx*math.cos(a) + dy*math.sin(a))/SCALE
                y = (-dx*math.sin(a) + dy*math.cos(a))/SCALE
                z = (p.z - b.position.z)/SCALE
            else:
                x, y, z = p.x, p.y, p.z
            out.append({'name': row.name, 'x': x, 'y': y, 'z': z, 'yaw': row.yaw,
                        'rendered': self.client_now >= row.readyAt, 'id': row.id})
        return out

    def named(self, board_id, prefix):
        return [p for p in self.props(board_id) if p['name'].startswith(prefix)]

    def view(self):
        return self.views[-1][1] if self.views else None

    def server_boards(self):
        rows = {}
        for _, row in self.server.globals()['dbBoards'].items():
            rows[row.id] = json.loads(row.data)
        return rows

    def stack_shoe(self, cards):
        self.server.globals().stackList = self.server.table_from(cards)
        self.server.execute('''
LightRpBlackjack.shuffle=function() local s={} for i,v in ipairs(stackList) do s[i]=v end for i=#stackList+1,312 do s[i]='2C' end return s end''')

    def diagnostics(self):
        return [dict(d.items()) for d in self.client.globals()['diagnostics'].values()]

    def notices(self):
        return list(self.client.globals()['notices'].values())


def near(p, x, y, z=None, tol=.012):
    return abs(p['x']-x) < tol and abs(p['y']-y) < tol and (z is None or abs(p['z']-z) < tol)

def check(condition, message):
    if not condition:
        raise AssertionError(message)

def no_render_failures(sim, label):
    bad = [d for d in sim.diagnostics() if d.get('reason') in ('board_failed', 'loop_error', 'state_error', 'view_refused')]
    check(not bad, f'{label}: client diagnostics {bad}')

def place(sim, kind, item, press_after=None):
    """Item use -> placement ghost -> E -> durable board; answers the board id."""
    before = set(sim.server_boards())
    sim.server.execute(f"inventories[1].items[1]={{name='{item}',count=1}}")
    sim.server.globals().useItem(1, item)
    sim.wait_for(lambda: sim.client.eval('LightRpBoardGamesClient.isActive()'), 'placement draft')
    if press_after is None:
        sim.wait_for(lambda: all(p['rendered'] for p in sim.props()) and sim.props(), 'ghost rendered')
        sim.advance(300)   # the validator marks the ghost ready on its 250 ms pass
    else:
        sim.advance(press_after)
    sim.press('E')
    sim.advance(400)
    new = set(sim.server_boards()) - before
    return next(iter(new)) if new else None

# =========================================================================================
def connect4():
    """Board games share the JSON path: a Connect Four row with holes arrives as an object."""
    sim = Sim()
    sim.advance(500)
    board_id = place(sim, 'connect4', 'connect4_board')
    check(board_id, 'E placed the Connect Four board')
    sim.wait_for(lambda: sim.named(board_id, 'connect4_board'), 'board prop')
    sim.interact(board_id)
    sim.wait_for(lambda: sim.client.eval('LightRpBoardGamesClient.isActive()'), 'seated camera')
    sim.page('lightrp:boardGames:mode', {'mode': 'solo'})
    sim.advance(1500)
    b = sim.board(board_id)
    check(b is not None and b.mode == 'solo', f'solo mode: board mode {b and b.mode}, notices {sim.notices()}, diagnostics {sim.diagnostics()}')
    rev = sim.board(board_id).revision
    sim.client.execute(f'TriggerServerEvent("lightrp:boardGames:request",{{action="move",boardId="{board_id}",fromRow=0,fromCol=0,toRow=6,toCol=4,revision={rev}}})')
    sim.wait_for(lambda: len(sim.named(board_id, 'connect4_white_disc')) == 1, 'player disc prop', 8000)
    sim.wait_for(lambda: len(sim.named(board_id, 'connect4_black_disc')) == 1, 'AI disc prop', 15000)
    sim.advance(3000)
    discs = sim.named(board_id, 'connect4_')
    discs = [d for d in discs if d['name'] != 'connect4_board']
    check(all(d['z'] < .9 for d in discs), f'discs settled into the grid {discs}')
    no_render_failures(sim, 'connect4')
    print(f'connect4 e2e: place, join, solo, drop, AI reply, discs visible and settled: OK ({len(discs)} discs)')
    return sim

# =========================================================================================
def blackjack():
    sim = Sim()
    sim.advance(500)
    check(sim.client_requests and sim.client_requests[0]['action'] == 'sync', 'client syncs at start')
    # Deck: white T,6 ; dealer 9 up, 7 hole ; white hits 4 (=20) ; dealer 7+9=16 draws 5 -> 21.
    sim.stack_shoe(['TS', '9D', '6H', '7C', '4D', '5S', 'KH', 'QH', 'JH', 'TH'])
    board_id = place(sim, 'blackjack', 'blackjack_table')
    check(board_id, 'E placed the blackjack table')
    sim.wait_for(lambda: sim.board(board_id) is not None, 'table state on the client')
    sim.wait_for(lambda: sim.named(board_id, 'blackjack_table'), 'table prop')
    check(sim.client.eval('not LightRpBoardGamesClient.isActive()'), 'placement closed')
    # Join through the E interaction point.
    sim.interact(board_id)
    sim.wait_for(lambda: sim.client.eval('LightRpBoardGamesClient.isActive()'), 'seated camera')
    v = sim.view()
    check(v['kind'] == 'blackjack' and v['extra']['mySeat'] == 'white' and v['extra']['phase'] == 'betting', f'betting view {v.get("extra")}')
    # Bet through the page action path.
    sim.page('lightrp:tabletop:action', {'operation': 'bet', 'data': {'amount': 25}})
    sim.wait_for(lambda: (sim.view()['extra'].get('hands') or {}).get('white'), 'bet in the view')
    v = sim.view()['extra']
    check(v['hands']['white']['bet'] == 25 and v['closesAt'], f'bet view {v}')
    closes = int(v['closesAt'])
    cash = sim.server.eval('cash(1)')
    check(cash == 975, f'stake debited, cash {cash}')
    sim.wait_for(lambda: len(sim.named(board_id, 'bj_chips_')) == 1, 'bet chips on the felt', 3000)
    sim.advance(800)    # the stack slides from the rail to the circle in 400 ms
    chips = sim.named(board_id, 'bj_chips_25_1')
    a = math.radians(54)
    check(chips and near(chips[0], .80*math.sin(a), -.80*math.cos(a), 1.35, .02), f'chips in the betting circle {chips}')
    # The countdown: the page counts down from the projected server clock.
    sim.advance(5000)
    left = (closes - sim.view()['extra']['clientNow'])/1000
    check(4 < left < 5.5, f'countdown follows the server clock ({left:.2f} s left)')
    check(not sim.named(board_id, 'bj_card_'), 'no cards before the deal')
    sim.advance_to_server(closes)
    # The server deals on its next 2 s board tick.
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['phase'] == 'playing', 'server deal', 2500)
    game = sim.server_boards()[board_id]['game']
    dealt = game['dealtAt']
    hand = game['hands']['white']['cards']; dealer = game['dealer']['cards']
    check([c['c'] for c in hand] == ['TS', '6H'] and dealer[0]['c'] == '9D' and game['_hole'] == '7C', f'dealt {hand} {dealer}')
    # What reaches the client and the page.
    sim.wait_for(lambda: sim.view()['extra']['phase'] == 'playing', 'playing view', 1000)
    v = sim.view()['extra']
    check(len(v['hands']['white']['cards']) == 2 and len(v['dealer']['cards']) == 2, f'view cards {v}')
    check('c' not in v['dealer']['cards'][1], 'hole card hidden in the view')
    seat = [( (.55-(k)*.012)*math.sin(a) + k*.032*math.cos(a), (.55-(k)*.012)*-math.cos(a) + k*.032*math.sin(a)) for k in range(7)]
    dealer_slot = [(-.07+k*.075, -.24) for k in range(7)]
    # Card timeline: white c1 at dealt, dealer c1 at +450, white c2 at +900, hole at +1350.
    timeline = [('TS', seat[0], hand[0]['t']), ('9D', dealer_slot[0], dealer[0]['t']),
                ('6H', seat[1], hand[1]['t']), (None, dealer_slot[1], dealer[1]['t'])]
    B = sim.server.globals().LightRpBlackjack
    slide, flip = B.SLIDE, B.FLIP
    seen_motion = set()
    def snapshot(label):
        if VERBOSE:
            print(label, sim.server_now()-dealt, [(p['name'], round(p['x'], 3), round(p['y'], 3)) for p in sim.named(board_id, 'bj_card')])
    for code, slot, t in timeline:
        # While sliding, a back is between the shoe mouth and the spot.
        sim.advance_to_server(int(t) + slide//2)
        snapshot('mid')
        backs = [p for p in sim.named(board_id, 'bj_card_back') if not near(p, .70, .03, None, .02)
                 and not near(p, slot[0], slot[1], None, .02)]
        moving = [p for p in backs if min(.70, slot[0]) - .02 <= p['x'] <= max(.70, slot[0]) + .02]
        check(moving, f'card {code or "hole"} slides out of the shoe at t+{slide//2} ms: props {sim.named(board_id, "bj_card")}')
        seen_motion.add(code)
    sim.advance_to_server(int(dealer[1]['t']) + slide + flip + 400)
    snapshot('settled')
    for code, slot, t in timeline:
        name = 'bj_card_' + (code.lower() if code else 'back')
        found = [p for p in sim.named(board_id, name) if near(p, slot[0], slot[1], 1.35, .015)]
        check(found, f'{name} rests on its spot {slot}: props {sim.named(board_id, "bj_card")}')
    check(not sim.named(board_id, 'bj_card_7c'), 'hole card is never a face prop before the reveal')
    v = sim.view()['extra']
    check(v['legal']['hit'] and v['legal']['stand'], f'player may act {v["legal"]}')
    no_render_failures(sim, 'deal')
    # Hit: the 4D slides to the third spot.
    sim.page('lightrp:tabletop:action', {'operation': 'hit', 'data': {}})
    sim.wait_for(lambda: len(sim.server_boards()[board_id]['game']['hands']['white']['cards']) == 3, 'hit on the server', 1000)
    t3 = sim.server_boards()[board_id]['game']['hands']['white']['cards'][2]['t']
    sim.advance_to_server(int(t3) + slide + flip + 300)
    check([p for p in sim.named(board_id, 'bj_card_4d') if near(p, seat[2][0], seat[2][1], None, .015)], f'hit card on the third spot {sim.named(board_id, "bj_card")}')
    check(sim.view()['extra']['hands']['white']['total'] == 20, 'view total 20')
    # Stand: the dealer reveals 7C and draws 5S to 21.
    sim.page('lightrp:tabletop:action', {'operation': 'stand', 'data': {}})
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['phase'] == 'result', 'dealer play', 1000)
    game = sim.server_boards()[board_id]['game']
    check(game['dealer']['total'] == 21 and game['hands']['white']['result'] == 'lose', f'result {game["dealer"]} {game["hands"]["white"]}')
    reveal = game['dealer']['cards'][1]['f']
    sim.advance_to_server(int(reveal) + flip + 200)
    check([p for p in sim.named(board_id, 'bj_card_7c') if near(p, dealer_slot[1][0], dealer_slot[1][1], None, .015)], 'hole card flipped face-up')
    third = game['dealer']['cards'][2]['t']
    sim.advance_to_server(int(third) + slide + flip + 300)
    check([p for p in sim.named(board_id, 'bj_card_5s') if near(p, dealer_slot[2][0], dealer_slot[2][1], None, .015)], f'dealer draw on its spot {sim.named(board_id, "bj_card")}')
    v = sim.view()['extra']
    check(v['phase'] == 'result', 'result view')
    # Lost chips slide into the rack and disappear.
    sim.advance_to_server(int(game['resultAt']) + 250 + B.CHIPS + 300)
    check(not sim.named(board_id, 'bj_chips_'), f'lost stack collected {sim.named(board_id, "bj_chips_")}')
    # Sweep, then the next round.
    sim.advance_to_server(int(game['nextAt']) + 100)
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['round'] == 2, 'next round', 2500)
    sim.wait_for(lambda: not sim.named(board_id, 'bj_card_'), 'felt cleared', 2000)
    sim.wait_for(lambda: sim.view()['extra']['phase'] == 'betting' and sim.view()['extra']['round'] == 2, 'betting view round 2', 2500)
    no_render_failures(sim, 'round 1')
    # Second round on the same shoe (KH, QH | JH, TH): a winning hand, paid out.
    sim.page('lightrp:tabletop:action', {'operation': 'bet', 'data': {'amount': 25}})
    sim.wait_for(lambda: (sim.view()['extra'].get('hands') or {}).get('white'), 'round 2 bet')
    sim.page('lightrp:tabletop:action', {'operation': 'deal', 'data': {}})
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['phase'] == 'playing', 'deal now', 1000)
    game = sim.server_boards()[board_id]['game']
    sim.advance_to_server(int(game['actAt']) + 300)
    check(len(sim.named(board_id, 'bj_card_')) == 4, f'round 2 shows four cards {sim.named(board_id, "bj_card")}')
    sim.page('lightrp:tabletop:action', {'operation': 'stand', 'data': {}})
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['phase'] == 'result', 'round 2 result', 1000)
    game = sim.server_boards()[board_id]['game']
    sim.advance_to_server(int(game['resultAt']) + 250 + B.CHIPS + 300)
    if game['hands']['white']['result'] == 'win':
        check(sim.named(board_id, 'bj_chips_'), 'winnings stack beside the bet')
    sim.advance(1500)
    no_render_failures(sim, 'round 2')
    print(f'blackjack e2e: place, join, bet, countdown deal, slide/flip timeline, hit, stand, reveal, draw, '
          f'chips, sweep, next round: OK (cash {sim.server.eval("cash(1)")}, peak {sim.client.eval("peakInstructions")} '
          f'instructions/resume, largest state part {sim.sizes["state"]} B, view {sim.sizes["view"]} B)')
    return sim


def blackjack_live():
    """The live table after a restart: the persisted row of round 2, a second table, a slot machine."""
    live = json.loads(Path(os.getenv('E2E_LIVE_ROW', '/home/dop42/.cache/casino-e2e/bj-live-state.json')).read_text()) \
        if Path(os.getenv('E2E_LIVE_ROW', '/home/dop42/.cache/casino-e2e/bj-live-state.json')).exists() else None
    if live is None:
        print('blackjack live row: skipped (no sample)');return
    pos = live['position']
    other = json.loads(json.dumps(live));other['id'] = '1793649300:2'
    other['position'] = {'x': pos['x']+2.2, 'y': pos['y'], 'z': pos['z']}
    rows = [(live['id'], 'inv1', json.dumps(live)), (other['id'], 'inv2', json.dumps(other))]
    sim = Sim(rows=rows, at=(pos['x'], pos['y']-1.0, pos['z']))
    sim.wall = sim.wall + 3_700_000_000   # the row was written in 2026, the harness clock is earlier
    sim.server.globals().wall = sim.wall
    sim.advance(1500)
    board_id = live['id']
    sim.wait_for(lambda: sim.board(board_id) is not None, 'reloaded table on the client')
    # A slot machine next to the tables.
    sim.client.execute(f"placeAt={{x={pos['x']-1.8},y={pos['y']},z={pos['z']}}}")
    slots = place(sim, 'slots', 'slot_machine')
    check(slots, 'slot machine placed')
    sim.advance(3000)
    sim.interact(board_id)
    sim.wait_for(lambda: sim.client.eval('LightRpBoardGamesClient.isActive()'), 'seated camera')
    sim.page('lightrp:tabletop:action', {'operation': 'bet', 'data': {'amount': 25}})
    sim.wait_for(lambda: (sim.view()['extra'].get('hands') or {}).get('white'), 'bet in the view')
    closes = int(sim.view()['extra']['closesAt'])
    sim.advance_to_server(closes)
    sim.wait_for(lambda: sim.server_boards()[board_id]['game']['phase'] == 'playing', 'server deal', 2500)
    game = sim.server_boards()[board_id]['game']
    sim.advance_to_server(int(game['actAt']) + 400)
    cards = sim.named(board_id, 'bj_card_')
    check(len(cards) == 4, f'live table: four cards after the deal, client shows {cards}; view {sim.view()["extra"].get("phase")}')
    no_render_failures(sim, 'live table')
    print(f'blackjack live row: reloaded round {game["round"]} deals four visible cards: OK')
    return sim


if __name__ == '__main__':
    # Scenarios written so far; slots and fortune still need theirs.
    only = sys.argv[1:] or [n for n in ('connect4', 'blackjack', 'slots', 'fortune') if n in globals()]
    dump = {}
    for name in only:
        sim = globals()[name]()
        if sim is not None:
            seen, views = set(), []
            for _, v in sim.views:
                key = json.dumps(v, sort_keys=True)
                if key not in seen:
                    seen.add(key);views.append(v)
            dump[name] = views
    # The page's inputs, for ui/tests/board-games.browser.cjs (CASINO_E2E_VIEWS).
    if os.getenv('E2E_VIEWS_OUT'):
        Path(os.environ['E2E_VIEWS_OUT']).write_text(json.dumps(dump))
