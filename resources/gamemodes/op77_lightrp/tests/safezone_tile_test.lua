-- The safe-zone tile (client/native/safezone_tile.lua, a NativeUI document): its hint lists
-- only what the zone enforces (shared/safezones.lua rules and defaults), it follows the
-- server's presence, animates the first time and replays without animation after a document
-- reload; under a menu or a dialog it steps aside with the HUD.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test safezone_tile_test.lua
-- The client sandbox has no setmetatable / load / require / debug: removed here too.
setmetatable, getmetatable, rawget, rawset, load, require, debug = nil, nil, nil, nil, nil, nil, nil

local handlers, threads, logs = {}, {}, {}
local zone, alive = nil, true
local clock = 0
function AddEventHandler(name, fn) handlers[name] = fn end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function GetCurrentResourceName() return "op77_lightrp" end
function GetGameTimer() return clock end

-- the document: what was created, its classes, its texts
local created, docEvents = nil, {}
local classes, texts, told = {}, {}, 0
local doc = {}
function doc:class(sel, name, on) classes[sel .. " " .. name] = on == true end
function doc:text(sel, value) texts[sel] = value end
function doc:style() end
function doc:batch(fn) fn() end
function doc:onEvent(kind, fn) docEvents[kind] = fn end
function doc:id() return 1 end

-- the host (client/native/host.lua), reduced to what the tile uses
local starters, shellHandlers = {}, {}
LightRpNative = {
    shell = { ready = true, hidden = false, quiet = false },
    create = function(spec) created = spec; return doc end,
    onStart = function(fn) starters[#starters + 1] = fn end,
    onShell = function(fn) shellHandlers[#shellHandlers + 1] = fn end,
    now = function() return clock end,
    log = function(text) logs[#logs + 1] = tostring(text) end,
}
Open77 = { ui = { create = function() return doc end }, character = { state = function() return { alive = alive, attached = true } end } }
LightRpUi = { characterReady = true, creationActive = false, log = function(...) logs[#logs + 1] = string.format(...) end }
LightRpSafezones = { presenceZone = function() return zone end }

dofile("shared/safezones.lua")
dofile("client/native/safezone_tile.lua")
local T = LightRpSafezoneTile

-- the hint: PvP always, the zone's blocked rules with their defaults (blockShoot defaults on)
assert(T.hint({}) == "No PvP · No shooting", T.hint({}))
assert(T.hint({ blockShoot = false }) == "No PvP")
assert(T.hint({ blockRun = true }) == "No PvP · Walk only · No shooting" or T.hint({ blockRun = true }) == "No PvP · No shooting · Walk only", T.hint({ blockRun = true }))
assert(T.hint({ blockRun = true, blockJump = true, blockMelee = true, blockGrenades = true }):match("%+%d$"), "more rules collapse into +N")

-- one tick: 16 ms pass, every waiting thread runs once
local function tick(times)
    for _ = 1, times or 1 do
        clock = clock + 16
        for i = 1, #threads do
            local co = threads[i]
            if coroutine.status(co) == "suspended" then assert(coroutine.resume(co)) end
        end
    end
end
-- T.last is replaced on every state the document is told ({ inside, label, hint, instant }): count them
local seen
local function last()
    if T.last ~= seen then seen = T.last; told = told + 1 end
    return T.last
end
local function shown(name) return classes["#zone " .. name] == true end

handlers.onClientResourceStart("op77_lightrp")
tick()
assert(created == nil and T.last == nil, "nothing told before the document exists")
for _, fn in ipairs(starters) do fn() end -- LightRpNative.start()
assert(created and created.document == "ui/native/safezone_tile.rml", "its own small document")
assert(T.page == doc and T.ready == true)
assert(last().inside == false, "outside at first")
assert(not shown("is-live"), "no tile outside a zone")

zone = { label = "Hub", blockShoot = true }
tick()
local p = last()
assert(p.inside and p.label == "Hub" and p.hint == "No PvP · No shooting" and p.instant == false, "entering animates")
assert(shown("is-live") and shown("is-shown"), "the tile shows inside a zone")
local n = told
tick(); last(); assert(told == n, "no resend while unchanged")

-- entering teaches it: the label unfolds with the title and the hint, then folds back
tick(70) -- past 220 ms, the decode and the typing
assert(shown("is-open") and texts["#zone-title"] == "SAFE ZONE" and texts["#zone-hint"] == "No PvP · No shooting",
    "the label unfolds: " .. tostring(texts["#zone-title"]) .. " / " .. tostring(texts["#zone-hint"]))
tick(200) -- past the 2.6 s hold and the fold
assert(not shown("is-open") and not shown("is-label") and shown("is-shown"), "the label folds back, the tile rests")

-- dead: as the controls see it, not protected
alive = false; tick(); assert(last().inside == false)
alive = true; tick(); assert(last().inside == true)

-- a character being created, or not ready yet: no zone
LightRpUi.creationActive = true; tick(); assert(last().inside == false)
LightRpUi.creationActive = false; tick(); assert(last().inside == true)
LightRpUi.characterReady = false; tick(); assert(last().inside == false)
LightRpUi.characterReady = true; tick(); assert(last().inside == true)

-- a document reload replays without the animation
docEvents.reloaded()
assert(last().inside and last().instant == true)
assert(shown("is-live") and shown("is-shown") and not shown("is-open"), "replayed at rest")

-- under a menu or a dialog the tile steps aside with the HUD, and comes back
for _, fn in ipairs(shellHandlers) do fn({ ready = true, hidden = true, quiet = false }) end
assert(classes["#root is-covered"] == true, "covered with the HUD")
for _, fn in ipairs(shellHandlers) do fn({ ready = true, hidden = false, quiet = false }) end
assert(classes["#root is-covered"] == false)

zone = nil; tick()
assert(last().inside == false and last().instant == false, "leaving animates")
assert(shown("is-leaving") and shown("is-open"), "the amber label unfolds")
tick(60)
assert(texts["#zone-title"] == "LEAVING SAFE ZONE" and texts["#zone-hint"] == "Protection off")
tick(120) -- past 1.5 s, the fold and the tile going
assert(not shown("is-live") and not shown("is-leaving"), "then the tile goes")
assert(#logs == 0, table.concat(logs, "; "))
print("PASS safe-zone tile")
