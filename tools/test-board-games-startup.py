#!/usr/bin/env python3
"""Measure one continuous Lua 5.4 activation pass, without per-file meter resets.

Use --resource-root for a downloaded deployed resource to measure its exact
manifest. Natives only register callbacks: scheduled bodies run after activation.
The 1,000-instruction threshold applies to added board code, not the entire RP.
"""
from pathlib import Path
import argparse
import re
from lupa.lua54 import LuaRuntime

REPO = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--resource-root', type=Path, default=REPO/'resources/gamemodes/op77_lightrp')
args = parser.parse_args()
root = args.resource_root
manifest = (root/'open77.lua').read_text()
scripts = []
for side in ('shared', 'client'):
    scripts.extend(re.findall(r'^'+side+r'_script\s+"([^"]+)"', manifest, re.M))

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
registered,threads,requests={},{},{}
Open77={camera={},players={},input={}}
exports=setmetatable({},{__call=function()return true end})
function RegisterNetEvent(name,fn) registered[#registered+1]={name=name,fn=fn} end
function AddEventHandler(name,fn) registered[#registered+1]={name=name,fn=fn} end
function CreateThread(fn) threads[#threads+1]=fn end
function TriggerServerEvent(...) requests[#requests+1]={...};return true end
function RegisterKeyMapping()return true,'E' end
function GetCurrentResourceName()return 'op77_lightrp' end
function GetGameTimer()return 0 end
function Wait() error('scheduled body ran during activation') end
function TriggerEvent()return true end
function SetTimeout(delay,fn) threads[#threads+1]=fn end
-- Keep debug privately for the meter, then remove restricted sandbox globals.
local hook=debug.sethook
io,os,debug,package,require,loadfile,dofile,load,getmetatable,setmetatable=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
function beginMeter()
    activationInstructions=0
    hook(function() activationInstructions=activationInstructions+1 end,'',1)
end
function endMeter()hook();return activationInstructions end
''')
lua.globals().beginMeter()
added = 0
measurements = []
for name in scripts:
    before = lua.globals().activationInstructions
    lua.execute((root/name).read_text(), name=name)
    after = lua.globals().activationInstructions
    if name in ('shared/board_games.lua', 'shared/board_games_rules.lua',
                'shared/board_game_models.lua', 'client/core/board_games.lua',
                'client/core/control_claims.lua'):
        added += after-before
        measurements.append((name, after-before))
whole = lua.globals().endMeter()
assert added < 1000, f'board activation regressed: {added} instructions; {measurements}'
assert len(lua.globals().requests) == 0, 'network work must wait until after activation'
# start() itself may only enqueue the scheduler body, without network work or model creation.
lua.globals().beginMeter()
lua.globals().LightRpBoardGamesClient.start()
start_cost = lua.globals().endMeter()
assert len(lua.globals().requests) == 0, 'board sync ran synchronously during start()'
assert start_cost < 100, f'board start() unexpectedly expensive: {start_cost}'
print(f'continuous activation: {whole} instructions across {len(scripts)} scripts')
print(f'added board scripts: {added} instructions; deferred start: {start_cost}')
for name,cost in measurements:
    print(f'  {name}: {cost}')
