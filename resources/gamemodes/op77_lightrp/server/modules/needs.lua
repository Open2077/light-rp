-- Hunger and thirst. Server-owned percentages on the character, ticking down
-- while the player is alive, shown on the HUD, refilled by staff for now (no
-- consumables in the barebone). Below zero the character loses health per tick.
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
        if c and life and life.phase == "alive" then
            local before = { food = c.food or 100, drink = c.drink or 100 }
            c.food = math.max(0, before.food - Config.foodPerTick)
            c.drink = math.max(0, before.drink - Config.drinkPerTick)
            local crossed = function(key) return before[key] > Config.warnAt and c[key] <= Config.warnAt end
            if crossed("food") then LightRP.notice(playerId, { kind = "warning", title = "FAIM", body = "Vous avez faim. Trouvez de quoi manger." }) end
            if crossed("drink") then LightRP.notice(playerId, { kind = "warning", title = "SOIF", body = "Vous avez soif. Trouvez de quoi boire." }) end
            if (c.food <= 0 or c.drink <= 0) and Config.starveDamagePerTick > 0 then
                pcall(Open77.players.damage, playerId, Config.starveDamagePerTick, { cause = "script", weapon = "lightrp:needs" })
            end
            LightRP.state(playerId, "needs")
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.tickMs)
        local ok, err = pcall(tick)
        if not ok then LightRP.log("needs tick failed: %s", tostring(err)) end
    end
end)
