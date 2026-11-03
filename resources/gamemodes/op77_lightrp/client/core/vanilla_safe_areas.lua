-- The game's own "safe areas" stay off on Light RP.
--
-- Vanilla marks some interiors (the Afterlife, Lizzie's, Clouds...) as staged space: the
-- city area type Safe forces empty hands (no weapon can be drawn, not even by staff), and
-- the scene tier blocks sprinting and jumping. Light RP has its own safe zones
-- (shared/safezones.lua, client/core/safezones.lua), and a player who leaves a vanilla one
-- by teleport or noclip could stay stuck unarmed everywhere ("the engine refused ...
-- weapon_not_drawn", Testing 2026-11-03). So Light RP claims the platform's suppression
-- (Open77.world.setSafeAreas(false)) for its session. The claim is keyed to this resource:
-- the host drops it when the resource stops, and leaving the game drops every claim.
--
-- The native's backend is wired a moment after client Lua starts (Cordon measured a first
-- `safe_area_backend_unavailable`), so the claim is retried briefly, asserted again on
-- world entry, and a watchdog re-claims if the state is ever read back ON.
local available, claimed, said = nil, false, nil

local function say(key, text)
    if said == key then return end
    said = key
    print("[lightrp] vanilla safe areas: " .. text)
end

local function apply(occasion)
    if Open77 == nil or Open77.world == nil or type(Open77.world.setSafeAreas) ~= "function" then
        available = false
        say("absent", "the client has no Open77.world.setSafeAreas: they stay as the game sets them")
        return false
    end
    available = true
    local ok, why = Open77.world.setSafeAreas(false)
    if ok == false then
        claimed = false
        say("refused:" .. tostring(why), "suppression refused (" .. tostring(why) .. "), retrying")
        return false
    end
    claimed = true
    say("on:" .. tostring(occasion), "turned off (" .. tostring(occasion) .. ")")
    return true
end

AddEventHandler("open77:worldReady", function() apply("world entry") end)

CreateThread(function()
    -- the first claims, until the backend answers (about 30 s at most)
    for _ = 1, 60 do
        if apply("resource start") or available == false then break end
        Wait(500)
    end
    if available == false then return end
    -- the watchdog: read it back, re-claim when it is ON again
    while true do
        Wait(5000)
        local enabled = nil
        if type(Open77.world.safeAreasEnabled) == "function" then
            local called, value = pcall(Open77.world.safeAreasEnabled)
            if called then enabled = value end
        end
        if enabled == true or not claimed then apply("recovery") end
    end
end)
