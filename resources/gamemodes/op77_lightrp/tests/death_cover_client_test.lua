-- The death cover (client/core/death_cover.lua): covers the first-person death as soon as
-- the local life ledger reads down, holds through the pending phases, lifts on recovering /
-- alive; a kill(script) + respawn placement never flashes it; a scripted death that stays
-- dead is covered after the grace; nothing sticks after a quick activity respawn.
dofile("shared/events.lua")
local E = LightRpEvents
local handlers, sent, threads, pageHandlers = {}, {}, {}, {}
local life -- the local life state returned by Open77.players.getLifeState()
local clock = 0
AddEventHandler = function(name, fn) handlers[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function() end
GetGameTimer = function() return clock end
Open77 = { players = { getLifeState = function() return life end } }
LightRpUi = { send = function(name, payload) sent[#sent + 1] = { name = name, payload = payload }; return true end }
dofile("client/core/death_cover.lua")
local Cover = LightRpDeathCover
assert(#threads == 1, "one safety-net reader")

local revision = 0
-- The platform changes phase and fires the event (client spelling, snake_case).
local function phase(name, cause)
    revision = revision + 1
    life = { playerId = 4, revision = revision, phase = name, cause = cause or (life and life.cause) or "firearm" }
    handlers["open77:playerLifeStateChanged"](4, name, revision)
end
local function last() return sent[#sent] end
local function covers() local n = 0; for _, m in ipairs(sent) do if m.payload.down then n = n + 1 end end; return n end
local function advance(ms) clock = clock + ms; Cover.update(clock) end

-- alive at start: nothing to say
life = { playerId = 4, revision = 0, phase = "alive" }
Cover.update(clock)
assert(#sent == 0 and not Cover.isDown())

-- 1. alive -> dying (dead) -> respawn -> alive: covered at once, held, lifted on recovering
phase("dead", "firearm")
assert(Cover.isDown(), "covered on the Dead event itself")
assert(#sent == 1 and last().name == "lightrp:ui:medical" and last().payload.kind == "cover" and last().payload.down == true)
assert(last().payload.cause == "firearm" and last().payload.revision == revision)
advance(10000)
phase("respawn_pending")
assert(#sent == 1 and Cover.isDown(), "held through RespawnPending, no second message")
phase("recovering")
assert(not Cover.isDown() and #sent == 2 and last().payload.down == false, "lifted on recovering")
phase("alive")
assert(#sent == 2, "alive after recovering: already lifted")

-- 2. downed -> revived (medical): held for minutes and through RevivePending
sent = {}
phase("dead", "melee")
for _ = 1, 20 do advance(15000) end
phase("revive_pending")
assert(Cover.isDown() and #sent == 1)
phase("recovering")
assert(not Cover.isDown() and #sent == 2)
phase("alive")

-- the server spelling is tolerated (revivepending / respawnpending)
sent = {}
phase("dead", "firearm"); phase("revivepending"); advance(100)
assert(Cover.isDown() and #sent == 1)
phase("alive")
assert(not Cover.isDown() and #sent == 2)

-- 3. activity death with a quick (2 s) respawn: covered then lifted, nothing stuck
sent = {}
phase("dead", "firearm")
advance(2000)
phase("respawn_pending"); advance(80)
phase("recovering"); advance(500)
phase("alive"); advance(1000)
assert(not Cover.isDown() and #sent == 2 and sent[1].payload.down and not sent[2].payload.down)
-- and again right after (gun game streaks): each death covered, each respawn lifted
for _ = 1, 5 do phase("dead", "firearm"); advance(1900); phase("respawn_pending"); phase("recovering"); advance(50) end
assert(not Cover.isDown() and covers() == 6 and #sent == 12)

-- a missed event: the safety-net reading still covers and lifts
sent = {}
revision = revision + 1; life = { revision = revision, phase = "dead", cause = "explosion" }
advance(200)
assert(Cover.isDown() and #sent == 1)
revision = revision + 1; life = { revision = revision, phase = "alive" }
advance(200)
assert(not Cover.isDown() and #sent == 2)

-- 4. placement: kill(script) + respawn in one tick never shows the cover
sent = {}
phase("dead", "script")
assert(not Cover.isDown() and Cover.pending(), "a scripted death waits out the grace")
phase("respawn_pending")
advance(60); advance(200)
phase("recovering"); phase("alive"); advance(500)
assert(#sent == 0 and not Cover.isDown() and not Cover.pending(), "no flash on a placement")

-- even a slow placement: RespawnPending after a scripted Dead stays uncovered
phase("dead", "script"); advance(100); phase("respawn_pending"); advance(1000)
assert(#sent == 0 and not Cover.isDown())
phase("alive"); advance(10)

-- 5. a scripted death that stays dead (medical:restore, games out of bounds): covered after the grace
sent = {}
phase("dead", "script")
advance(100)
assert(#sent == 0)
advance(60)
assert(Cover.isDown() and #sent == 1 and last().payload.cause == "script")
phase("respawn_pending"); phase("recovering")
assert(not Cover.isDown() and #sent == 2)
phase("alive")

-- no life state (no session yet, permission missing): uncovered, never an error
sent = {}
life = nil; advance(200)
assert(#sent == 0 and not Cover.isDown())
Open77.players.getLifeState = function() error("backend unavailable") end
advance(200)
assert(#sent == 0 and not Cover.isDown())
Open77.players.getLifeState = function() return life end

-- the page (re)loads: the current cover state is published again
local fakePage = { on = function(_, name, fn) pageHandlers[name] = fn end }
Cover.bind(fakePage)
life = { revision = 99, phase = "dead", cause = "firearm" }; revision = 99
advance(10)
sent = {}
pageHandlers[E.page.ready]()
assert(#sent == 1 and sent[1].payload.kind == "cover" and sent[1].payload.down == true, "republished on page ready")

print("death_cover_client_test: ok")
