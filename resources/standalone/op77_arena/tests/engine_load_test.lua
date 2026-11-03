-- The whole server side as the manifest loads it (engine + contract + adapter), on a
-- host where every native answers nil: it must load, and the Light RP seams must be
-- the ones the engine calls.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test engine_load_test.lua
local say = print
_G.print = function() end

local commands, handlers, net, threads, events = {}, {}, {}, {}, {}

-- Any Open77.* path is a callable that answers nil.
local function stub(path)
    return setmetatable({}, {
        __index = function(t, k) local child = stub(path .. "." .. tostring(k)); rawset(t, k, child); return child end,
        __call = function() return nil end,
    })
end
_G.Open77 = stub("Open77")
Open77.time.unix = function() return 1700000000 end
Open77.time.nowMs = function() return 1000 end
Open77.time.monotonic = function() return 1 end
_G.json = { encode = function() return "{}" end, decode = function() return {} end }
_G.RegisterCommand = function(name, fn, restricted) commands[name] = { fn = fn, restricted = restricted } end
_G.AddEventHandler = function(name, fn) handlers[name] = (handlers[name] or 0) + 1 end
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.TriggerEvent = function(name, ...) events[#events + 1] = name end
_G.TriggerClientEvent = function() end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.SetTimeout = function() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.GetResourceState = function() return "running" end
_G.GetPlayers = function() return {} end
_G.GetPlayerName = function() return nil end
_G.GetPlayerIdentifiers = function() return {} end
_G.SetPlayerRoutingBucket = function() return true end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.IsPlayerAceAllowed = function() return false end
_G.SetRoutingBucketPopulationEnabled = function() end
_G.SetRoutingBucketEntityLockdownMode = function() end
_G.exports = setmetatable({}, { __index = function() return stub("exports") end, __call = function() end })

-- The manifest's shared + server lists, in order.
local manifest = io.open("open77.lua"):read("a")
local files = {}
for kind, path in manifest:gmatch('(%w+_script) "([^"]+)"') do
    if kind ~= "client_script" then files[#files + 1] = path end
end
assert(#files == 18, "4 shared + 14 server scripts, got " .. #files)
for _, path in ipairs(files) do
    local ok, err = pcall(dofile, path)
    assert(ok, path .. ": " .. tostring(err))
end

local DM, H = Deathmatch, ArenaHost
assert(DM and H and ArenaCore and LightRpArena and ArenaRecap)

-- The seams the engine resolves at call time are the adapter's.
assert(DM.sendToLobby == H.returnHome, "the way home")
assert(type(DM.moveBody) == "function", "placement by teleport/respawn, never kill -> respawn")
assert(type(DM.wantsState) == "function", "state pushes only to the people concerned")
assert(DM.round.join ~= H.engine.join and DM.arena.enqueue ~= H.engine.enqueue and DM.leave ~= H.engine.leave)
assert(FreeroamPvp.entryFailure ~= nil, "queues revalidate through Light RP")
-- Bot mode, crews and PvE ride on the same kind of seam.
assert(DM.round.begin ~= H.engine.begin and type(H.engine.begin) == "function", "rounds start through the adapter (bot fill)")
assert(DM.setTeam ~= H.engine.setTeam and DM.arena.sideOf ~= H.engine.sideOf, "PvE sides")
assert(DM.arena.planRoster == H.planRoster, "crews: the roster plan is the adapter's")
assert(type(H.engine.recordRound) == "function" and DM.ranked.recordRound ~= H.engine.recordRound, "no rating write with bots or in PvE")
assert(type(DeathmatchBots.dropPending) == "function", "bots.lua parked spawns can be dropped")
assert(DeathmatchConfig.pve and DeathmatchConfig.pve.bucket == 4100002, "PvE has its own bucket")
assert(DM.instances.kindOfBucket(4100002) == "pve" and DM.instances.kindOfBucket(4100001) == "blade")
DM.tune = DM.tune or {} -- the tunables host is not up on this stub
local pve = DM.instances.open("ffa", "pve")
assert(pve and pve.kind == "pve" and pve.bucket == 4100002 and pve.label == LightRpArena.activities.pve.label, "PvE instance")
assert(DM.instances.open("ffa", "pve") == nil, "one PvE instance")
assert(DM.instances.open("2v2", "pve") == nil, "PvE is a free-for-all ruleset only")
assert(DM.ranked.recordRound(pve, {}) == false, "PvE never rated")
DM.instances.close(pve, "test")

-- PvP scopes: the gate wraps every way an instance opens, closes are chained.
assert(type(ArenaPvp) == "table" and type(ArenaPvp.sync) == "function", "server/pvp.lua loaded")
assert(manifest:find('"combat.scope.control"', 1, true), "the scope permission is declared")
assert(DeathmatchConfig.combat.friendlyFire == false, "never global friendly fire on Light RP")
assert(type(DM.onInstanceClosed) == "function", "scope release on close")

-- Hosted switches as the engine reads them.
assert(DeathmatchConfig.freeroam == true and DeathmatchConfig.placeOnJoin == false)
assert(DeathmatchConfig.buckets.lobby == 0)
assert(DeathmatchConfig.career.tablePrefix == "op77_arena_")
assert(DeathmatchConfig.tunables.fillWithBots.value == false)

-- Commands: ours open, Arena Night staff-only; the engine's staff tools stay restricted.
for _, name in ipairs({ "arena", "arena.ffa", "arena.blade", "arena.pve", "arena.queue", "arena.leave", "arena.weapon", "arena.kit", "duel" }) do
    assert(commands[name] and commands[name].restricted == false, name)
end
assert(commands["arena.night"].restricted == true)
local restricted = {}
for name, c in pairs(commands) do if c.restricted then restricted[#restricted + 1] = name end end
table.sort(restricted)

-- Light RP's events are host-wide (AddEventHandler), never net events.
for _, name in ipairs({ "op77_lightrp:activity:join", "op77_lightrp:activity:leaveRequest",
    "op77_lightrp:activity:dropped", "op77_lightrp:activity:ready", "op77_lightrp:activity:bots" }) do
    assert(handlers[name] == 1, name)
    assert(net[name] == nil, name .. " must not be a net event")
end

local open = {}
for name, c in pairs(commands) do if not c.restricted then open[#open + 1] = name end end
table.sort(open)
say("open commands: " .. table.concat(open, " "))
say("restricted commands: " .. table.concat(restricted, " "))
say(("PASS: op77_arena engine load (%d files, %d threads, %d commands)"):format(#files, #threads, #open + #restricted))
