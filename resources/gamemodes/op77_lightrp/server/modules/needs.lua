local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- Hunger and thirst. Server-owned percentages on the character, ticking down
-- while the player is alive, shown on the HUD, refilled by eating and drinking.
-- At 0 food or 0 drink the character starves (Config.starve): a share of max health
-- every few seconds until they eat/drink or die, health regen off meanwhile, and a
-- floor after a hospital respawn so nobody respawns starving into a death loop.
local Config = LightRpConfig.needs
local Needs = LightRP.module("needs", {})

local function character(playerId)
    return LightRP.characters and LightRP.characters.get(playerId)
end

function Needs.get(playerId)
    local c = character(playerId)
    -- while starving, the HUD shows it for good (not a one-off notice): what, and how fast
    local kind = Needs.starving and Needs.starving(playerId) or nil
    local fed = Needs.wellFed and Needs.wellFed(playerId) or false
    return { food = c and c.food or 100, drink = c and c.drink or 100, starving = kind or false,
        drainPerMinute = kind and Needs.drainPercent(kind) or 0,
        wellFed = fed, regenPerMinute = fed and Needs.wellFedRate() or 0 }
end

function Needs.set(playerId, food, drink)
    local c = character(playerId)
    if c == nil then return false end
    if food ~= nil then c.food = math.max(0, math.min(100, food)) end
    if drink ~= nil then c.drink = math.max(0, math.min(100, drink)) end
    LightRP.state(playerId, "needs")
    return true
end

function Needs.refill(playerId) return Needs.set(playerId, 100, 100) end

LightRP.stateProvider("needs", Needs.get)

local function tick()
    if not Config.enabled then return end
    for _, playerId in ipairs(GetPlayers()) do
        local c = character(playerId)
        local life = Open77.players.getLifeState(playerId)
        -- frozen while a mission or an activity owns the player (unless its caps say otherwise)
        if c and life and life.phase == "alive" and (not LightRP.activities or LightRP.activities.allows(playerId, "needs")) then
            local before = { food = c.food or 100, drink = c.drink or 100 }
            c.food = math.max(0, before.food - Config.foodPerTick)
            c.drink = math.max(0, before.drink - Config.drinkPerTick)
            local crossed = function(key) return before[key] > Config.warnAt and c[key] <= Config.warnAt end
            if crossed("food") then LightRP.notice(playerId, { kind = "warning", title = "HUNGRY", body = "You are hungry. Find something to eat." }) end
            if crossed("drink") then LightRP.notice(playerId, { kind = "warning", title = "THIRSTY", body = "You are thirsty. Find something to drink." }) end
            LightRP.state(playerId, "needs")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Starving

local starving = {}   -- playerId -> "food" | "drink" | "both"
local lastPhase = {}  -- playerId -> the life phase seen at the previous starve tick
local died = {}       -- playerId -> true from a death until the floor is applied after the respawn
local regenOff = {}   -- playerId -> true when this module turned health regen off itself
local damageWarned = false

local function S() return Config.starve or {} end

local function starveKind(c)
    if not c then return nil end
    local food, drink = (c.food or 100) <= 0, (c.drink or 100) <= 0
    if food and drink then return "both" end
    return food and "food" or drink and "drink" or nil
end

--- "food" | "drink" | "both" while the character starves, nil otherwise (cyberware reads it
--- to keep health regen off).
function Needs.starving(playerId) return starving[tonumber(playerId) or playerId] end
--- Percent of max health lost per minute for a starving kind.
function Needs.drainPercent(kind)
    local cfg = S()
    return kind == "both" and (tonumber(cfg.bothPercentPerMinute) or 12) or (tonumber(cfg.percentPerMinute) or 6)
end

-- Health regen follows the starving state: cyberware owns the regen rate (body + implants
-- + boosts) and asks Needs.starving; without it, the regen flag is set here directly.
local function applyRegen(playerId)
    local C = LightRP.cyberware
    if type(C) == "table" and type(C.refreshRegen) == "function" then
        local ok, done = pcall(C.refreshRegen, playerId)
        if ok and done then regenOff[playerId] = nil; return end
    end
    local St = Open77.stats
    if type(St) ~= "table" or type(St.setRegenEnabled) ~= "function" then return end
    if starving[playerId] and S().noRegen ~= false then
        if pcall(St.setRegenEnabled, playerId, "health", false) then regenOff[playerId] = true end
    elseif regenOff[playerId] then
        pcall(St.setRegenEnabled, playerId, "health", true)
        regenOff[playerId] = nil
    end
end

local function setStarving(playerId, kind)
    if starving[playerId] == kind then return end
    local was = starving[playerId]
    starving[playerId] = kind
    if kind and not was then
        LightRP.notice(playerId, { kind = "error", title = "STARVING",
            body = "You are losing health. Eat or drink something, or you will end up in the hospital." })
    end
    applyRegen(playerId)
    LightRP.state(playerId, "needs")
end

local function maxHealth(playerId)
    local St = Open77.stats
    if type(St) == "table" and type(St.get) == "function" then
        local ok, stats = pcall(St.get, playerId)
        local m = ok and type(stats) == "table" and type(stats.health) == "table" and tonumber(stats.health.maximum)
        if m and m > 0 then return m end
    end
    return 100
end

local function consuming(playerId)
    local K = LightRP.consumables
    if type(K) ~= "table" or type(K.isActive) ~= "function" then return false end
    local ok, yes = pcall(K.isActive, playerId)
    return ok and yes == true
end

--- After a death, once back in the world: both needs raised to at least `respawnFloor`
--- (never lowered). The hospital calls it at once; the starve tick catches any other respawn.
function Needs.afterRespawn(playerId)
    playerId = tonumber(playerId) or playerId
    died[playerId] = nil
    local c = character(playerId)
    local floor = tonumber(S().respawnFloor) or 0
    if c == nil or floor <= 0 then return false end
    if (c.food or 100) >= floor and (c.drink or 100) >= floor then return false end
    return Needs.set(playerId, math.max(c.food or 100, floor), math.max(c.drink or 100, floor))
end

local function starveTick()
    if not Config.enabled then return end
    local cfg = S()
    local tickMs = tonumber(cfg.tickMs) or 5000
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId) or playerId
        local c = character(playerId)
        local life = Open77.players.getLifeState(playerId)
        local phase = life and life.phase or nil
        -- back in the world after a death: never starving. A respawn goes dead -> recovering (the
        -- grace) -> alive, so "the previous tick was dead" missed it and players came back at 0 / 0.
        if phase == "dead" then died[playerId] = true end
        if c and died[playerId] and (phase == "alive" or phase == "recovering") then Needs.afterRespawn(playerId) end
        lastPhase[playerId] = phase
        local free = not LightRP.activities or LightRP.activities.allows(playerId, "needs")
        local kind = (c and phase == "alive" and free) and starveKind(c) or nil
        setStarving(playerId, kind)
        -- Eating or drinking: no damage meanwhile. Any damage cancels the use (consumables.lua,
        -- both sides), so a starving player could never eat their way out (owner, 2026-11-03).
        if kind and not consuming(playerId) then
            local pct = Needs.drainPercent(kind)
            local amount = maxHealth(playerId) * pct / 100 * tickMs / 60000
            if amount > 0 then
                local ok, applied, why = pcall(Open77.players.damage, playerId, amount, { cause = "script" })
                if (not ok or applied == false) and not damageWarned then
                    damageWarned = true
                    LightRP.log("needs: starvation damage refused for %s: %s", tostring(playerId), tostring(ok and why or applied))
                end
            end
        end
    end
end
Needs.starveTick = starveTick

-- ---------------------------------------------------------------------------
-- Well fed: above the threshold in food AND drink, health comes back by itself,
-- point by point (the remainder carries over between ticks).

local fedState = {}   -- playerId -> true while well fed (HUD)
local fedCarry = {}   -- playerId -> health points owed, below one

local function W() return Config.wellFed or {} end
function Needs.wellFedRate() return tonumber(W().healthPerMinute) or 5 end
function Needs.wellFed(playerId) return fedState[tonumber(playerId) or playerId] == true end

local function healthOf(playerId)
    local ok, p = pcall(Open77.players.get, playerId)
    if ok and type(p) == "table" then return tonumber(p.health), tonumber(p.maxHealth) end
end

local function wellFedTick(elapsedMs)
    if not Config.enabled then return end
    local threshold = tonumber(W().threshold) or 80
    local rate = Needs.wellFedRate()
    for _, raw in ipairs(GetPlayers()) do
        local playerId = tonumber(raw) or raw
        local c = character(playerId)
        local life = Open77.players.getLifeState(playerId)
        local free = not LightRP.activities or LightRP.activities.allows(playerId, "needs")
        local fed = c ~= nil and life ~= nil and life.phase == "alive" and free
            and (c.food or 0) > threshold and (c.drink or 0) > threshold
        if fed ~= (fedState[playerId] == true) then
            fedState[playerId] = fed or nil
            if not fed then fedCarry[playerId] = nil end
            LightRP.state(playerId, "needs")
        end
        if fed and rate > 0 and type(Open77.players.heal) == "function" then
            local health, max = healthOf(playerId)
            if health and max and health < max then
                local owed = (fedCarry[playerId] or 0) + rate * elapsedMs / 60000
                local whole = math.floor(owed)
                fedCarry[playerId] = owed - whole
                if whole > 0 then pcall(Open77.players.heal, playerId, math.min(whole, max - health)) end
            else
                fedCarry[playerId] = 0
            end
        end
    end
end
Needs.wellFedTick = wellFedTick

AddEventHandler("playerDropped", function()
    local id = tonumber(source) or source
    starving[id], lastPhase[id], regenOff[id], died[id] = nil, nil, nil, nil
    fedState[id], fedCarry[id] = nil, nil
end)

CreateThread(function()
    lightrpEvery(Config.tickMs, function()
        
        local ok, err = pcall(tick)
        if not ok then LightRP.log("needs tick failed: %s", tostring(err)) end
    end, "needs:227")
end)

CreateThread(function()
    while true do
        Wait(tonumber(S().tickMs) or 5000)
        local ok, err = pcall(starveTick)
        if not ok then LightRP.log("needs starve tick failed: %s", tostring(err)) end
    end
end)

CreateThread(function()
    while true do
        local ms = tonumber(S().tickMs) or 5000
        Wait(ms)
        local ok, err = pcall(wellFedTick, ms)
        if not ok then LightRP.log("needs well-fed tick failed: %s", tostring(err)) end
    end
end)

-- Staff: set a character's food and drink (tests, events, a stuck player).
LightRP.command("lightrp.needs", { restricted = true, usage = "/lightrp.needs <id|me> <food 0-100> <drink 0-100>" }, function(source, args)
    local target = (args[1] == nil or args[1] == "me") and source or tonumber(args[1])
    local food, drink = tonumber(args[2]), tonumber(args[3])
    if not target or target <= 0 or not food or not drink then return false end
    if not Needs.set(target, food, drink) then return false, "No character for that player." end
    return true, string.format("Needs of %s: food %d, drink %d.", LightRP.characters.displayName and LightRP.characters.displayName(target) or tostring(target), math.floor(food), math.floor(drink))
end)
