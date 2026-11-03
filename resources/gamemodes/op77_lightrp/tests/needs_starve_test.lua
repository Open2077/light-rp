-- Starving (server/modules/needs.lua): at 0 food or 0 drink a share of max health every
-- starve tick until eating/drinking or death, health regen off meanwhile (through
-- cyberware when it holds the player, directly otherwise), a floor after a hospital
-- respawn, one notice per starving spell. No game, no DB.

local threads, handlers, notices, logs, damaged, regen, cwRefresh = {}, {}, {}, {}, {}, {}, {}
local chars, life, players = {}, {}, { 1, 2, 3 }
local damageAnswer = true

LightRpConfig = { needs = { enabled = true, tickMs = 60000, foodPerTick = 0.6, drinkPerTick = 0.9, warnAt = 20,
    starve = { tickMs = 5000, percentPerMinute = 6, bothPercentPerMinute = 12, noRegen = true, respawnFloor = 25 } } }
LightRP = {
    module = function(name, def) LightRP[name] = def; return def end,
    characters = { get = function(id) return chars[id] end },
    state = function() end,
    stateProvider = function() end,
    command = function(name, _, fn) LightRP["cmd:" .. name] = fn end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, kind = n.kind } end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
}
Open77 = {
    players = {
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        damage = function(id, amount, opts)
            damaged[#damaged + 1] = { id = id, amount = amount, opts = opts }
            if damageAnswer then return true end
            return false, "invalid_state"
        end,
    },
    stats = {
        get = function(id) return { health = { maximum = id == 2 and 400 or 200 } } end,
        setRegenEnabled = function(id, stat, on) regen[id] = { stat = stat, on = on }; return true end,
    },
}
GetPlayers = function() local list = {}; for _, id in ipairs(players) do list[#list + 1] = tostring(id) end; return list end
CreateThread = function(fn) threads[#threads + 1] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
local waits = 0
Wait = function() waits = waits + 1; if waits > 1 then error("stop") end end

dofile("server/modules/needs.lua")
local Needs = LightRP.needs
assert(#threads == 3 and type(Needs.starveTick) == "function" and type(Needs.wellFedTick) == "function", "a needs thread, a starve thread and a well-fed thread")
local function starve() Needs.starveTick() end
local function close(a, b) return math.abs(a - b) < 1e-6 end

chars[1] = { food = 50, drink = 50 }
chars[2] = { food = 0, drink = 50 }
chars[3] = { food = 0, drink = 0 }

-- one tick: 1 fed, 2 starving on food (6%/min of 400 over 5 s = 2), 3 on both (12% of 200 = 2)
starve()
assert(#damaged == 2, "only the starving take damage")
local by = {}
for _, d in ipairs(damaged) do by[d.id] = d end
assert(by[2] and close(by[2].amount, 400 * 6 / 100 * 5 / 60), "one need at 0: percentPerMinute of max health")
assert(by[3] and close(by[3].amount, 200 * 12 / 100 * 5 / 60), "both at 0: bothPercentPerMinute")
assert(by[2].opts.cause == "script" and by[2].opts.weapon == nil, "a script cause and no weapon string (refused before)")
assert(Needs.starving(2) == "food" and Needs.starving(3) == "both" and Needs.starving(1) == nil, "starving kinds")
assert(regen[2] and regen[2].on == false and regen[3].on == false and regen[1] == nil, "regen off while starving (no cyberware)")
assert(#notices == 2 and notices[1].title == "STARVING", "one notice each")

-- a second tick: damage again, no second notice
damaged = {}
starve()
assert(#damaged == 2 and #notices == 2, "keeps draining, warned once")

-- eating ends it and gives regen back (only what this module took away)
chars[2].food = 30
starve()
assert(Needs.starving(2) == nil and regen[2].on == true, "fed: regen back on")
assert(regen[1] == nil, "never touched a player it did not turn off")

-- downed/dead: no damage; a death then respawn brings both needs to the floor
damaged = {}
life[3] = "dead"
starve()
assert(#damaged == 0, "no damage while dead")
assert(Needs.starving(3) == nil, "not starving while dead")
life[3] = "alive"
starve()
assert(chars[3].food == 25 and chars[3].drink == 25, "respawn floor")
assert(Needs.starving(3) == nil, "no longer starving after the floor")
-- a floor never lowers anything
chars[1].food, chars[1].drink = 10, 90
life[1] = "dead"; starve(); life[1] = "alive"; starve()
assert(chars[1].food == 25 and chars[1].drink == 90, "only raised to the floor")

-- with cyberware holding the player, regen goes through it
LightRP.cyberware = { refreshRegen = function(id) cwRefresh[#cwRefresh + 1] = { id = id, starving = Needs.starving(id) }; return true end }
regen = {}
chars[2].food = 0
starve()
assert(#cwRefresh == 1 and cwRefresh[1].id == 2 and cwRefresh[1].starving == "food", "cyberware re-applies regen, seeing the state")
assert(regen[2] == nil, "the flag is not set directly when cyberware answered")

-- eating or drinking: no damage while the use runs (any damage would cancel it), still starving
local using = { [2] = true }
LightRP.consumables = { isActive = function(id) return using[id] == true end }
damaged = {}
starve()
assert(#damaged == 0 and Needs.starving(2) == "food", "no starvation damage while eating or drinking")
using[2] = nil
starve()
assert(#damaged == 1 and damaged[1].id == 2, "damage again once the use ends")
LightRP.consumables = nil

-- frozen in an activity
LightRP.activities = { allows = function(id) return id ~= 2 end }
damaged = {}
starve()
assert(#damaged == 0 and Needs.starving(2) == nil, "frozen while an activity owns the player")
LightRP.activities = nil

-- a refused damage is logged once
damageAnswer = false
starve(); starve()
local refused = 0
for _, line in ipairs(logs) do if line:find("starvation damage refused", 1, true) then refused = refused + 1 end end
assert(refused == 1, "refusal logged once")

-- well fed: above the threshold in food AND drink, +healthPerMinute, point by point
LightRpConfig.needs.wellFed = { threshold = 80, healthPerMinute = 5 }
local healed, hp = {}, { [1] = 150, [2] = 400, [3] = 100 }
Open77.players.get = function(id) return { health = hp[id], maxHealth = id == 2 and 400 or 200 } end
Open77.players.heal = function(id, n) healed[#healed + 1] = { id = id, n = n }; hp[id] = hp[id] + n; return true end
for id = 1, 3 do life[id] = "alive" end
chars[1].food, chars[1].drink = 95, 90   -- fed and hurt
chars[2].food, chars[2].drink = 95, 95   -- fed, full health
chars[3].food, chars[3].drink = 95, 60   -- not enough to drink
damageAnswer = true
starve()
for _ = 1, 12 do Needs.wellFedTick(5000) end   -- one minute
local got = {}
for _, h in ipairs(healed) do got[h.id] = (got[h.id] or 0) + h.n end
assert(got[1] == 5, "+5 health in a minute: " .. tostring(got[1]))
for _, h in ipairs(healed) do assert(h.n == math.floor(h.n), "whole points only") end
assert(not got[2], "full health: nothing to heal")
assert(not got[3], "below the threshold in drink: no regen")
assert(Needs.wellFed(1) and Needs.wellFed(2) and not Needs.wellFed(3))
local view = Needs.get(1)
assert(view.wellFed == true and view.regenPerMinute == 5 and view.starving == false, "the HUD state")
chars[1].drink = 70
Needs.wellFedTick(5000)
assert(not Needs.wellFed(1) and Needs.get(1).regenPerMinute == 0, "below the threshold: off")
life[2] = "dead"
Needs.wellFedTick(5000)
assert(not Needs.wellFed(2), "dead: off")
-- the starving state reaches the HUD with its drain
chars[3].food, chars[3].drink = 0, 0
starve()
local s3 = Needs.get(3)
assert(s3.starving == "both" and s3.drainPerMinute == 12, "starving on the HUD with the drain")

-- dropped: state forgotten
_G.source = 2
handlers.playerDropped()
assert(Needs.starving(2) == nil, "dropped: forgotten")

print("PASS: needs starving (percent of max health per kind, no weapon string, regen off/on with and without cyberware, one notice, dead/respawn floor, paused while eating, activity freeze, refusal logged once, well fed +5/min point by point, HUD state, drop)")
