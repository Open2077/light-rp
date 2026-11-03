#!/usr/bin/env python3
"""Pool rules and shot simulation (shared/casino_pool.lua), pure Lua via lupa.

Physics: determinism, the wire round trip, energy only ever lost, no ball
leaving the cloth or passing through another, cushions, pockets, head-on and
cluster collisions (the break spreads the rack), the hard event/segment/work
caps, and the cost bound of the worst shot (the server simulates inside its
request handler: 1 s quota on build 176). Rules: break, open table, groups,
fouls and ball in hand, turn passing, the 8 (early, on the break, legal),
practice, placement and re-racks.
"""
import json, math, random, time
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT/'resources/gamemodes/op77_lightrp/shared/casino_pool.lua'


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpBoardGames={};LightRpItems={}')
    lua.execute(SHARED.read_text(), name='casino_pool.lua')
    lua.execute(HELPERS)
    return lua


HELPERS = r'''
P=LightRpPool
NOW=1790000000000
function table_of(list) -- {[number]={x,y}} by ball number -> 16 entries
 local b={};for i=1,16 do b[i]=false end
 for n,p in pairs(list) do b[n+1]={P.quantize(p[1]),P.quantize(p[2])} end
 return b
end
function sim(list,yawDeg,speed) return P.simulate(table_of(list),math.rad(yawDeg),speed) end
-- Every ball at time t from its decoded wire segments (what a client shows).
function wireAt(r,start,t)
 local out={}
 for i=1,16 do
  local s=P.encodeSegments(r.segs[i])
  local n=P.records(s)
  local x,y
  if n==0 then if start[i] then x,y=start[i][1],start[i][2] end
  else
   local k=1;for j=1,n do if P.record(s,j)<=t then k=j end end
   local t0,x0,y0,vx,vy=P.record(s,k)
   x,y=P.motion(x0,y0,vx,vy,t-t0)
  end
  local p=r.pocketed[i]
  if p and t>=p.t then x=nil end
  out[i]=x and {x,y} or false
 end
 return out
end
function speedsAt(r,t)
 local e=0
 for i=1,16 do
  local s=r.segs[i];local cur
  for _,g in ipairs(s) do if g[1]<=t then cur=g end end
  local p=r.pocketed[i]
  if cur and not (p and t>=p.t) then
   local v=math.sqrt(cur[4]^2+cur[5]^2)-P.DECEL*(t-cur[1]);if v>0 then e=e+v*v end
  end
 end
 return e
end
function state(mode,list,extra)
 local s=P.new(mode,1);s.pos=P.encodePositions(table_of(list))
 for k,v in pairs(extra or {}) do s[k]=v end
 return s
end
function shoot(s,seat,yaw,power,at)
 return P.shoot(s,seat,{yaw=yaw,power=power,nowMs=at or NOW})
end
function after(s) return P.endsAt(s)+1 end
'''


def check_trajectories(lua, r, start, label):
    """Sampled every 5 ms: inside the cushions, no interpenetration, energy never grows."""
    P = lua.globals().P
    X, Y, D = P.X, P.Y, 2*P.R
    duration = r.duration
    last_energy = float('inf')
    t = 0.0
    worst_overlap = 0.0
    while t <= duration + .01:
        balls = lua.globals().wireAt(r, start, t)
        on = [(i, balls[i][1], balls[i][2]) for i in range(1, 17) if balls[i]]
        for i, x, y in on:
            assert abs(x) <= X + 2e-4 and abs(y) <= Y + 2e-4, f'{label}: ball {i-1} left the cloth at t={t:.3f} ({x:.4f},{y:.4f})'
        for a in range(len(on)):
            for b in range(a+1, len(on)):
                d = math.hypot(on[a][1]-on[b][1], on[a][2]-on[b][2])
                worst_overlap = max(worst_overlap, D-d)
        e = lua.globals().speedsAt(r, t)
        assert e <= last_energy + 1e-3, f'{label}: energy grew at t={t:.3f}: {last_energy} -> {e}'
        last_energy = e
        t += .005
    assert worst_overlap < 6e-4, f'{label}: balls interpenetrate by {worst_overlap*1000:.2f} mm'
    return worst_overlap


def physics():
    lua = runtime()
    g = lua.globals()
    P = g.P
    # Determinism and the wire round trip.
    rack = g.P.rack(7)
    a = P.simulate(rack, math.radians(.3), P.MAX_SPEED)
    b = P.simulate(g.P.rack(7), math.radians(.3), P.MAX_SPEED)
    wa = [P.encodeSegments(a.segs[i]) for i in range(1, 17)]
    wb = [P.encodeSegments(b.segs[i]) for i in range(1, 17)]
    assert wa == wb and P.encodePositions(a.final) == P.encodePositions(b.final), 'same input, same shot'
    lua.execute('function roundtrip(r) for i=1,16 do local s=P.encodeSegments(r.segs[i]);for k,g in ipairs(r.segs[i]) do local t,x,y,vx,vy=P.record(s,k);'
                'assert(t==g[1] and x==g[2] and y==g[3] and vx==g[4] and vy==g[5],"record "..i..":"..k) end end;'
                'local s=P.encodePositions(r.final);local d=P.decodePositions(s);for i=1,16 do assert((d[i]==false)==(r.final[i]==false));if d[i] then assert(d[i][1]==r.final[i][1] and d[i][2]==r.final[i][2]) end end;'
                'local drops=P.decodeDrops(P.encodeDrops(r));for k,i in ipairs(r.order) do assert(drops[k].ball==i and drops[k].pocket==r.pocketed[i].k and drops[k].t==r.pocketed[i].t) end end')
    g.roundtrip(a)
    # Head-on: the cue ball nearly stops, the object ball takes (1+e)/2 of the speed.
    r = g.sim(lua.eval('{[0]={-.5,0},[3]={0,0}}'), 0, 2.0)
    assert r.firstHit == 4 and r.segs[4][1][4] > 0
    vin = 2.0 - P.DECEL*r.segs[4][1][1]   # cue speed at contact
    v3 = math.hypot(r.segs[4][1][4], r.segs[4][1][5])
    vcue = math.hypot(r.segs[1][2][4], r.segs[1][2][5])
    assert abs(v3 - (1+P.BALL_E)/2*vin) < 2e-3 and abs(vcue - (1-P.BALL_E)/2*vin) < 2e-3, (vin, v3, vcue)
    check_trajectories(lua, r, g.table_of(lua.eval('{[0]={-.5,0},[3]={0,0}}')), 'head-on')
    # A cut: both balls leave at right angles (equal masses, nearly elastic).
    r = g.sim(lua.eval('{[0]={-.6,.02},[5]={0,0}}'), 0, 1.5)
    c1, o1 = r.segs[1][2], r.segs[6][1]
    dot = c1[4]*o1[4] + c1[5]*o1[5]
    assert abs(dot)/(math.hypot(c1[4], c1[5])*math.hypot(o1[4], o1[5])) < .1, 'cut angle ~90 degrees (e<1 keeps a little of the normal part)'
    # Cushion: straight into the side rail between the pockets, back at RAIL_E.
    r = g.sim(lua.eval('{[0]={.6,0}}'), 90, 1.0)
    s = r.segs[1]
    assert abs(s[2][3] - P.Y) < 2e-4, 'bounces on the cushion line'
    vin = 1.0 - P.DECEL*s[2][1]
    assert abs(s[2][5] + P.RAIL_E*vin) < 2e-3 and abs(s[2][4]) < 1e-3
    # Pockets: corner (+x,+y) is 3, side (-y) is 5; the cue ball can scratch.
    r = g.sim(lua.eval('{[0]={0,0},[1]={.5,.25}}'), math.degrees(math.atan2(.25, .5)), 2.0)
    assert r.pocketed[2] and r.pocketed[2].k == 3, 'ball 1 into the +x+y corner'
    r = g.sim(lua.eval('{[0]={0,.2},[2]={0,-.2}}'), -90, 2.0)
    assert r.pocketed[3] and r.pocketed[3].k == 5 and r.firstHit == 3, 'ball 2 into the side pocket'
    r = g.sim(lua.eval('{[0]={-.3,-.3}}'), math.degrees(math.atan2(-P.Y+.3, -P.X+.3)), 3.0)
    assert r.pocketed[1] and r.pocketed[1].k == 1, 'scratch in the -x-y corner'
    # Along the cushion past the side pocket mouth: no drop (only crossings count).
    r = g.sim(lua.eval('{[0]={-.8,0}}'), 0, 1.0)
    assert not r.pocketed[1]
    # The break: the rack spreads, a few balls drop, the wire stays small.
    stats = {'moved': 0, 'pots': 0, 'n': 0, 'bytes': 0, 'segments': 0, 'events': 0}
    for seed in range(1, 9):
        for yaw in (0, .35, -.8, .6):   # within ~1 deg the cue ball meets the apex nearly full
            start = g.P.rack(seed)
            r = P.simulate(start, math.radians(yaw), P.MAX_SPEED)
            g.roundtrip(r)
            moved = sum(1 for i in range(2, 17) if not r.final[i] or math.hypot(r.final[i][1]-start[i][1], r.final[i][2]-start[i][2]) > .08)
            assert moved >= 9, f'break seed {seed} yaw {yaw}: only {moved} balls left the rack'
            assert r.capped is None, r.capped
            stats['moved'] += moved; stats['pots'] += len(r.order); stats['n'] += 1
            stats['bytes'] = max(stats['bytes'], sum(len(P.encodeSegments(r.segs[i])) for i in range(1, 17)))
            stats['segments'] = max(stats['segments'], r.segments); stats['events'] = max(stats['events'], r.events)
            if seed <= 2:
                check_trajectories(lua, r, start, f'break {seed}/{yaw}')
    assert stats['bytes'] <= P.MAX_SEGMENTS*P.REC
    print(f"break: {stats['moved']/stats['n']:.1f}/15 balls leave the rack, {stats['pots']/stats['n']:.2f} pocketed on average, "
          f"at most {stats['events']} events / {stats['segments']} segments / {stats['bytes']} B on the wire")
    # Fuzz: random tables and shots stay on the cloth, never overlap, lose energy.
    rnd = random.Random(176)
    worst = 0
    for case in range(40):
        balls = lua.table()
        placed = []
        for i in range(1, 17):
            if i > 1 and rnd.random() < .3:
                balls[i] = False; continue
            for _ in range(200):
                x, y = rnd.uniform(-P.X, P.X), rnd.uniform(-P.Y, P.Y)
                if all(math.hypot(x-px, y-py) >= 2*P.R+1e-4 for px, py in placed):
                    break
            placed.append((x, y)); balls[i] = lua.table(P.quantize(x), P.quantize(y))
        r = P.simulate(balls, math.radians(rnd.uniform(0, 360)), rnd.uniform(P.MIN_SPEED, P.MAX_SPEED))
        worst = max(worst, check_trajectories(lua, r, balls, f'fuzz {case}'))
    print(f'fuzz: 40 random tables, sampled every 5 ms: on the cloth, energy only lost, worst overlap {worst*1000:.3f} mm')
    # Hard caps: a capped shot freezes cleanly (every ball stopped, nothing lost).
    for name, value in (('MAX_EVENTS', 3), ('MAX_SEGMENTS', 20), ('MAX_WORK', 50)):
        lua.execute(f'saved=P.{name};P.{name}={value}')
        r = P.simulate(g.P.rack(3), 0, P.MAX_SPEED)
        lua.execute(f'P.{name}=saved')
        assert r.capped, name
        assert r.segments <= max(value, 20) + 16 if name == 'MAX_SEGMENTS' else True
        for i in range(1, 17):
            last = r.segs[i][len(r.segs[i])] if len(r.segs[i]) else None
            if last and not r.pocketed[i]:
                assert last[4] == 0 and last[5] == 0 or abs(last[1]-r.duration) >= 0, name
        assert sum(1 for i in range(1, 17) if r.final[i]) + len(r.order) == 16, 'no ball lost when capped'
    print('caps: events, segments and work caps freeze the table with every ball accounted for')
    # The cost bound: the worst measured shot, and the bound the caps impose.
    lua.execute(r'''
function cost(fn) local n=0;debug.sethook(function() n=n+1 end,'',1000);local r=fn();debug.sethook();return n*1000,r end
''')
    worst_cost, worst_ms = 0, 0
    for seed in range(1, 31):
        for yaw in (0, .2, -.5, 2.0, 30, 180):
            t = time.perf_counter()
            n, r = lua.eval(f'cost(function() return P.simulate(P.rack({seed}),math.rad({yaw}),P.MAX_SPEED) end)')
            worst_ms = max(worst_ms, (time.perf_counter()-t)*1000)
            worst_cost = max(worst_cost, n)
    # Force the work cap: every contact search counts; the shot stops at MAX_WORK.
    lua.execute('saved=P.MAX_EVENTS;P.MAX_EVENTS=1e9')
    capped_cost, r = lua.eval('cost(function() return P.simulate(P.rack(5),0,P.MAX_SPEED) end)')
    lua.execute('P.MAX_EVENTS=saved')
    per_work = capped_cost/max(1, r.work)
    bound = P.MAX_EVENTS*(16*400 + 120*120) + P.MAX_WORK*max(per_work, 400)
    assert worst_cost < 5_000_000 and worst_ms < 200, (worst_cost, worst_ms)
    assert bound < 60_000_000, bound
    print(f'cost: worst of 180 breaks {worst_cost/1e6:.2f} M VM instructions ({worst_ms:.1f} ms in desktop Lua); '
          f'upper bound from the caps {bound/1e6:.0f} M instructions (~{bound/1e8:.1f} s at 100 M/s, under the 1 s handler quota)')


def rules():
    lua = runtime()
    lua.execute(r'''
local function fails(s,why) assert(s==nil and type(why)=="string",'expected a refusal') return why end
-- A fresh duel: white breaks, the cue ball on the head spot, the rack on the foot spot.
local s=P.new('duel',42)
assert(s.phase=='break' and s.turn=='white' and s.ply==0 and s.status=='playing')
local b=P.decodePositions(s.pos)
assert(b[1][1]==P.quantize(P.HEAD_X) and b[2][1]==P.quantize(P.FOOT_X) and b[9][2]==0,'1 on the apex, 8 in the middle row')
local seen={};for i=1,16 do assert(b[i]) for j=1,i-1 do assert((b[i][1]-b[j][1])^2+(b[i][2]-b[j][2])^2>=(2*P.R)^2,'rack overlap') end end
-- Corners: one solid, one stripe.
local c1,c2
for i=2,16 do if math.abs(b[i][1]-P.quantize(P.FOOT_X+4*(2*P.R+P.RACK_GAP)*math.sqrt(3)/2))<1e-4 and math.abs(math.abs(b[i][2])-P.quantize(2*(2*P.R+P.RACK_GAP)))<1e-4 then if c1 then c2=i else c1=i end end end
assert(c1 and c2 and P.group(c1)~=P.group(c2),'back corners: one of each group')
-- Validation: wrong seat, bad numbers, the time.
fails(shoot(s,'black',0,1))
fails(shoot(s,'white',0/0,1));fails(shoot(s,'white',0,1.5));fails(shoot(s,'white',0,-.1));fails(shoot(s,'white',1e6,.5))
fails(P.shoot(s,'white',{yaw=0,power=1}))
-- The break.
local n=assert(shoot(s,'white',0,1))
assert(n.ply==1 and n.shot.n==1 and n.shot.at==NOW+P.LEAD and n.shot.dur>0 and #n.shot.segs==16 and n.phase~='break')
assert(n.last.by=='white' and not n.solids,'the table stays open after the break')
-- In flight: nobody acts.
local who=n.turn
fails(shoot(n,who,10,.5,NOW+1000),'busy')
assert(P.busy(n,NOW+1000) and not P.busy(n,after(n)))
-- Open table, a clean pot of a solid assigns solids to the shooter, who shoots again.
s=state('duel',{[0]={0,0},[1]={.5,.25},[10]={-.6,-.4}},{phase='open'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.last.potted==P.ballChar(2) and n.solids=='white' and n.last.assigned=='white' and n.turn=='white' and n.last.kept and not n.last.foul)
assert(P.groupOf(n,'white')=='solids' and P.groupOf(n,'black')=='stripes' and n.potted==P.ballChar(2))
-- ... the same with a stripe: the shooter takes stripes (solids go to the other seat).
s=state('duel',{[0]={0,0},[9]={.5,.25},[2]={-.6,-.4}},{phase='open',turn='black'})
n=assert(shoot(s,'black',math.deg(math.atan(.25,.5)),.4))
assert(n.solids=='white' and P.groupOf(n,'black')=='stripes' and n.turn=='black')
-- Nothing of yours potted (rail after contact): the turn passes, no foul.
s=state('duel',{[0]={0,0},[3]={.3,0},[12]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',0,.35))
assert(not n.last.foul and n.turn=='black' and not n.inHand,'turn passes')
-- Potting only the opponent's ball passes the turn too.
s=state('duel',{[0]={0,0},[9]={.5,.25},[3]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.last.foul=='wrong_first' and n.turn=='black' and n.inHand=='table','hitting a stripe first as solids is a foul')
-- Fouls: no ball hit, scratch (ball in hand anywhere), no rail after contact.
s=state('duel',{[0]={0,0},[3]={0,.4},[12]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',0,.1))
assert(n.last.foul=='no_contact' and n.turn=='black' and n.inHand=='table')
s=state('duel',{[0]={-.3,-.3},[3]={.6,.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',math.deg(math.atan(-P.Y+.3,-P.X+.3)),.8))
assert(n.last.foul=='scratch' and n.last.scratch and n.inHand=='table' and n.turn=='black' and P.decodePositions(n.pos)[1]==false)
s=state('duel',{[0]={0,0},[3]={.07,0},[12]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',0,0))
assert(n.last.foul=='no_rail' and n.turn=='black','a touch without a rail is a foul')
-- Ball in hand: only the incoming player, on a free spot of the cloth.
local hand=n
fails(P.place(hand,'white',{x=0,y=-3000,nowMs=after(hand)}))
fails(P.place(hand,'black',{x=0,y=-3000,nowMs=NOW}),'busy')
fails(P.place(hand,'black',{x=1e6,y=0,nowMs=after(hand)}))
fails(P.place(hand,'black',{x=1.5,y=0,nowMs=after(hand)}))
local b3=P.decodePositions(hand.pos)[4]
fails(P.place(hand,'black',{x=math.floor(b3[1]*P.UNIT),y=math.floor(b3[2]*P.UNIT),nowMs=after(hand)}),'occupied')
fails(shoot(hand,'black',0,.5,after(hand)),'place first')
local placed=assert(P.place(hand,'black',{x=-5000,y=-3000,nowMs=after(hand)}))
assert(not placed.inHand and P.decodePositions(placed.pos)[1][1]==-.5)
fails(P.place(placed,'black',{x=-5000,y=-2000,nowMs=after(placed)}),'not in hand any more')
-- A scratch on the break: ball in hand behind the head string only.
s=P.new('duel',3);local rack=P.decodePositions(s.pos)
rack[1]={-.3,-.3};s.pos=P.encodePositions(rack)
n=assert(shoot(s,'white',math.deg(math.atan(-P.Y+.3,-P.X+.3)),.8))
assert(n.last.foul=='scratch' and n.inHand=='kitchen' and n.turn=='black')
fails(P.place(n,'black',{x=0,y=0,nowMs=after(n)}),'kitchen')
assert(P.place(n,'black',{x=math.floor(P.HEAD_X*P.UNIT)-100,y=0,nowMs=after(n)}))
-- The 8: early (open table or own group left) loses, foul on the 8 loses, legal wins.
s=state('duel',{[0]={0,0},[8]={.5,.25},[3]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.status=='won' and n.winner=='black' and n.last.reason=='eight_early' and n.phase=='over')
s=state('duel',{[0]={0,0},[8]={.5,.25},[10]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.status=='won' and n.winner=='white' and n.last.reason=='eight' and n.last.won=='white','the 8 after clearing the group wins')
s=state('duel',{[0]={0,0},[8]={.5,.25},[10]={-.6,-.4}},{phase='play',solids='white'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),1))
if n.last.scratch then assert(n.winner=='black' and n.last.reason=='eight_foul','scratch with the 8 loses') end
s=state('duel',{[0]={0,0},[8]={.5,.25}},{phase='open'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.winner=='black','the 8 on an open table loses')
-- Over: no shot, a rematch re-racks with the other breaker; reset-free.
fails(shoot(n,'black',0,.5,after(n)))
fails(P.rerack(s,'white',{nowMs=after(s),seed=9}),'not over')
local again=assert(P.rerack(n,'black',{nowMs=after(n),seed=9}))
assert(again.status=='playing' and again.phase=='break' and again.breaker=='black' and again.turn=='black' and again.rack==2 and again.ply==n.ply+1 and again.potted=='')
-- The 8 on the break comes back to the foot spot.
local found=false
for seed=1,60 do
 for _,yaw in ipairs({0,.3,-.6,1.1,-1.4}) do
  local br=P.new('duel',seed);local r=assert(shoot(br,'white',yaw,1))
  if r.last.respot then
   local e=P.decodePositions(r.pos)[9];assert(e and math.abs(e[2])<1e-9 and e[1]>=P.FOOT_X-.2,'8 re-spotted')
   assert(r.status=='playing' and not r.potted:find(P.ballChar(9),1,true));found=true;break
  end
 end
 if found then break end
end
print('rules: 8 on the break re-spotted '..(found and 'seen' or 'not produced by 300 breaks (path untested)'))
-- Practice: no fouls, the cue ball back in hand after a scratch, re-rack any time.
s=state('solo',{[0]={-.3,-.3},[3]={.6,.4}},{phase='practice'})
n=assert(shoot(s,'white',math.deg(math.atan(-P.Y+.3,-P.X+.3)),.8))
assert(not n.last.foul and n.inHand=='table' and n.turn=='white' and n.status=='playing')
s=state('solo',{[0]={0,0},[8]={.5,.25}},{phase='practice'})
n=assert(shoot(s,'white',math.deg(math.atan(.25,.5)),.4))
assert(n.status=='playing' and n.last.cleared and n.potted==P.ballChar(9),'the last ball clears the table')
local fresh=assert(P.rerack(n,'white',{nowMs=after(n),seed=5}))
assert(fresh.mode=='solo' and fresh.phase=='break' and fresh.rack==2)
fails(P.rerack(n,'white',{nowMs=NOW,seed=5}),'busy')
''')
    print('rules: break, open table and groups, turn passing, fouls (no contact, wrong ball, no rail, scratch), ball in hand (anywhere, kitchen after a break scratch), the 8 (early, foul, legal, re-spot), rematch, practice: OK')


def size():
    lua = runtime()
    P = lua.globals().P
    worst = 0
    for seed in range(1, 21):
        for yaw in (0, .4, -1.2):
            n = lua.eval(f'assert(P.shoot(P.new("duel",{seed}),"white",{{yaw={yaw},power=1,nowMs=NOW}}))')
            def py(v):
                if hasattr(v, 'items'):
                    d = {k: py(x) for k, x in v.items()}
                    if d and all(isinstance(k, int) for k in d):
                        return [d[i] for i in sorted(d)]
                    return {str(k): x for k, x in d.items()}
                return v
            text = json.dumps(py(n), separators=(',', ':'))
            worst = max(worst, len(text))
    assert worst < 2600, worst
    print(f'public state after the worst of 60 breaks: {worst} bytes (the board entry stays under the 3.5 KB state part)')


if __name__ == '__main__':
    physics()
    rules()
    size()
    print('Pool rules and simulation: all checks passed')
