-- The safe-zone tile (client/core/safezone_tile.lua): its hint lists only what the zone
-- enforces (shared/safezones.lua rules and defaults), it follows the server's presence,
-- animates the first time and replays without animation after a page reload.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test safezone_tile_test.lua
-- The client sandbox has no setmetatable / load / require / debug: removed here too.
setmetatable, getmetatable, rawget, rawset, load, require, debug = nil, nil, nil, nil, nil, nil, nil

local handlers, threads, sent, logs = {}, {}, {}, {}
local zone, alive, onReady = nil, true, nil
function AddEventHandler(name, fn) handlers[name] = fn end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function GetCurrentResourceName() return "op77_lightrp" end
local created
WebUI = { create = function(options)
    created = options
    return { on = function(_, name, fn) if name == "zone:ready" then onReady = fn end end,
        send = function(_, name, payload) sent[#sent + 1] = { name = name, payload = payload } end }
end }
Open77 = { character = { state = function() return { alive = alive, attached = true } end } }
LightRpUi = { characterReady = true, creationActive = false, log = function(...) logs[#logs + 1] = string.format(...) end }
LightRpSafezones = { presenceZone = function() return zone end }

dofile("shared/safezones.lua")
dofile("client/core/safezone_tile.lua")
local T = LightRpSafezoneTile

-- the hint: PvP always, the zone's blocked rules with their defaults (blockShoot defaults on)
assert(T.hint({}) == "No PvP · No shooting", T.hint({}))
assert(T.hint({ blockShoot = false }) == "No PvP")
assert(T.hint({ blockRun = true }) == "No PvP · Walk only · No shooting" or T.hint({ blockRun = true }) == "No PvP · No shooting · Walk only", T.hint({ blockRun = true }))
assert(T.hint({ blockRun = true, blockJump = true, blockMelee = true, blockGrenades = true }):match("%+%d$"), "more rules collapse into +N")

local function tick() for _, co in ipairs(threads) do if coroutine.status(co) == "suspended" then assert(coroutine.resume(co)) end end end
local function last() return sent[#sent] and sent[#sent].payload end

handlers.onClientResourceStart("op77_lightrp")
tick()
assert(created and created.entry == "web/safezone/index.html" and created.visible == true and created.drawBounds.x < 0, "own small surface")
tick()
assert(#sent == 0, "nothing sent before the page is ready")
onReady()
assert(last().inside == false, "outside at first")

zone = { label = "Hub", blockShoot = true }
tick()
local p = last()
assert(p.inside and p.label == "Hub" and p.hint == "No PvP · No shooting" and p.instant == false, "entering animates")
local n = #sent
tick(); assert(#sent == n, "no resend while unchanged")

-- dead: as the controls see it, not protected
alive = false; tick(); assert(last().inside == false)
alive = true; tick(); assert(last().inside == true)

-- a page reload replays without the animation
onReady()
assert(last().inside and last().instant == true)

zone = nil; tick()
assert(last().inside == false and last().instant == false, "leaving animates")
print("PASS safe-zone tile")
