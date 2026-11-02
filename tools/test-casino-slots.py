#!/usr/bin/env python3
"""Pure-Lua regressions for the slot machine rules: strips, paytable, RTP, pull/settle."""
from pathlib import Path
import json
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('LightRpBoardGames={};LightRpItems={}')
lua.execute((ROOT/'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
manifest=json.loads((ROOT/'resources/assets/models/open77_casino_slots/asset-manifest.json').read_text())
lua.globals().manifestReels=lua.table_from([lua.table_from(r) for r in manifest['reels']])
lua.execute(r'''
local S=LightRpCasinoSlots
assert(LightRpBoardGames.slots.item=='slot_machine' and LightRpItems.slot_machine.label=='Slot Machine')
-- The cooked strip meshes carry exactly these reels.
for r=1,3 do for i=1,S.STOPS do assert(manifestReels[r][i]==S.REELS[r][i],'asset strip order differs') end end
local known={};for _,s in ipairs(S.SYMBOLS) do known[s]=true;assert(S.LABELS[s] and S.THREE[s]) end
for r=1,3 do assert(#S.REELS[r]==S.STOPS);for _,s in ipairs(S.REELS[r]) do assert(known[s]) end end
-- Exhaustive return to player over all 12^3 equally likely stop triples.
local total,hits,best=0,0,0
for a=0,11 do for b=0,11 do for c=0,11 do
 local m,label,symbols=S.evaluate({a,b,c});assert(m and type(label)=='string' and #symbols==3)
 total=total+m;if m>0 then hits=hits+1 end;if m>best then best=m end
 assert(S.payout({a,b,c},7)==7*m)
end end end
rtp=total/1728;hitRate=hits/1728
assert(total==1632,'RTP changed: '..total..'/1728')
assert(best==200)
-- Paytable examples (stops are 0-based).
local function stopOf(r,name) for i,s in ipairs(S.REELS[r]) do if s==name then return i-1 end end end
local function stops(a,b,c) return {stopOf(1,a),stopOf(2,b),stopOf(3,c)} end
assert(S.evaluate(stops('seven','seven','seven'))==200)
assert(S.evaluate(stops('diamond','diamond','diamond'))==100)
assert(S.evaluate(stops('cherry','cherry','cherry'))==10)
assert(S.evaluate(stops('cherry','cherry','bar'))==4)
assert(S.evaluate(stops('lemon','grape','cherry'))==2)
assert(S.evaluate(stops('cherry','bell','bar'))==1)
assert(S.evaluate(stops('bar','bar','bell'))==0)
assert(S.evaluate(stops('bell','cherry','cherry'))==0,'cherries only count from reel 1')
-- Invalid input.
for _,bad in ipairs({{0,0},{12,0,0},{-1,0,0},{0.5,0,0},{0,0,0/0},'x'}) do assert(S.evaluate(bad)==nil) end
for _,bet in ipairs({0,1001,1.5,-3,0/0}) do assert(S.payout({0,0,0},bet)==nil) end
-- Pull / settle state machine.
local now=1790000000000
local s=S.new();assert(s.phase=='idle' and s.round==0)
local function reject(seat,action,p) local n,why=S.act(s,seat,action,p);assert(not n and type(why)=='string',action) end
reject('black','pull',{bet=5,stops={0,0,0},nowMs=now})
reject('white','pull',{bet=0,stops={0,0,0},nowMs=now})
reject('white','pull',{bet=5,stops={0,0,12},nowMs=now})
reject('white','pull',{bet=5,stops={0,0,0}})
reject('white','settle',{nowMs=now})
local seven=stops('seven','seven','seven')
s=assert(S.act(s,'white','pull',{bet=5,stops=seven,nowMs=now}))
assert(s.phase=='spinning' and s.round==1 and s.spin.at==now and s.spin.endsAt==now+S.DURATION and s.spin.gross==1000)
assert(s.spin.from[1]==0 and s.spin.stops[1]==seven[1] and s.stops[3]==seven[3])
reject('white','pull',{bet=5,stops={1,1,1},nowMs=now+S.DURATION-1})
reject('white','settle',{nowMs=now+S.DURATION-1})
local settled=assert(S.act(s,'white','settle',{nowMs=now+S.DURATION}))
assert(settled.phase=='idle' and settled.last.gross==1000 and settled.last.multiplier==200 and settled.last.label=='Three Sevens')
-- An unsettled spin past its end does not block the next pull; `from` is the last stop.
local again=assert(S.act(s,'white','pull',{bet=1,stops={1,2,3},nowMs=now+S.DURATION}))
assert(again.round==2 and again.spin.from[1]==seven[1] and again.spin.gross==S.payout({1,2,3},1))
''')
print('Slot rules: strips match the cooked assets, paytable, RTP %.2f %% (hit rate %.1f %%), pull/settle: OK' % (lua.globals().rtp*100, lua.globals().hitRate*100))
