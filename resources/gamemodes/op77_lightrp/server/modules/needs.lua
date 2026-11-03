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
    return { food = c and c.food or 100, drink = c and c.drink or 100 }
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

local function starveTick()
    if not Config.enabled then return end
    local cfg = S()
    local tickMs = tonumber(cfg.tickMs) or 5000
    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId) or playerId
        local c = character(playerId)
        local life = Open77.players.getLifeState(playerId)
        local phase = life and life.phase or nil
        -- a hospital respawn after a death: never back into the world starving
        if c and phase == "alive" and lastPhase[playerId] == "dead" then
            local floor = tonumber(cfg.respawnFloor) or 0
            if floor > 0 and ((c.food or 100) < floor or (c.drink or 100) < floor) then
                Needs.set(playerId, math.max(c.food or 100, floor), math.max(c.drink or 100, floor))
            end
        end
        lastPhase[playerId] = phase
        local free = not LightRP.activities or LightRP.activities.allows(playerId, "needs")
        local kind = (c and phase == "alive" and free) and starveKind(c) or nil
        setStarving(playerId, kind)
        if kind then
            local pct = kind == "both" and (tonumber(cfg.bothPercentPerMinute) or 12) or (tonumber(cfg.percentPerMinute) or 6)
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

AddEventHandler("playerDropped", function()
    local id = tonumber(source) or source
    starving[id], lastPhase[id], regenOff[id] = nil, nil, nil
end)

CreateThread(function()
    while true do
        Wait(Config.tickMs)
        local ok, err = pcall(tick)
        if not ok then LightRP.log("needs tick failed: %s", tostring(err)) end
    end
end)

CreateThread(function()
    while true do
        Wait(tonumber(S().tickMs) or 5000)
        local ok, err = pcall(starveTick)
        if not ok then LightRP.log("needs starve tick failed: %s", tostring(err)) end
    end
end)
