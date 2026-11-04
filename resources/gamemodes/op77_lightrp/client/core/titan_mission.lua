-- Titan Assault on this client (server/modules/mission_titan.lua runs it): the arrival report, the relay of
-- a hostile's hits on the local pilot, the ground probe the server asks for, the arrows over a wave's last hostiles, and the state the page
-- draws (ui/src/features/missions/TitanMissionHud.tsx). The pilot's own blows on the hostiles are not relayed from here: the
-- Titan resource reports them (onTitanNpcHit) and the server prices them.
local E = LightRpEvents
local Titan = { state = nil, enemies = {} }
LightRpTitanMissionClient = Titan

local function now() return Open77.time.monotonic() end
local function log(fmt, ...) LightRpUi.log("titan: " .. fmt, ...) end

-- The ids of the run's hostiles, as the server last listed them: the only NPCs this client relays hits from.
local function setEnemies(ids)
    Titan.enemies = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do Titan.enemies[tostring(id)] = true end
end

-- ---------------------------------------------------------------------------
-- Arrival: the loading screen is gone and the body has stood in the arena for two seconds. Sent until the
-- server's view says so (it checks position and bucket itself); the Titan is spawned on its acceptance.
local arriveReporter = false
local function arenaReady()
    if Open77.screen and type(Open77.screen.isLoading) == "function" then
        local ok, loading = pcall(Open77.screen.isLoading)
        if ok and loading == true then return false end
    end
    local me = Open77.character.state()
    if not me or not me.alive or not me.attached or not me.position then return false end
    local a = Titan.state and Titan.state.arena
    return not a or (me.position.x - a.x) ^ 2 + (me.position.y - a.y) ^ 2 <= 80 * 80
end
local function reportArrival()
    if arriveReporter then return end
    arriveReporter = true
    CreateThread(function()
        local since, sent
        while Titan.state and Titan.state.arrived == false do
            if arenaReady() then
                since = since or now()
                if now() - since >= 2 and (not sent or now() - sent >= 2) then sent = now(); TriggerServerEvent(E.net.titanArrived) end
            else
                since = nil
            end
            Wait(250)
        end
        arriveReporter = false
    end)
end

-- ---------------------------------------------------------------------------
-- A hostile this client simulates hit a pilot: the server checks it and applies it (the same relay the raid and the
-- authored missions use; the platform's victim path reports the same hit from the victim and wins when present).
AddEventHandler("open77:npcPlayerHit", function(victim, npc, epoch, amount)
    local s = Titan.state
    if s and s.phase == "wave" and Titan.enemies[tostring(npc)] then
        TriggerServerEvent(E.net.titanNpcHit, victim, npc, epoch, amount)
    end
end)

-- ---------------------------------------------------------------------------
-- The ground probe: the server picks points on a ring around the pilots and cannot see the terrain. For each, a ray
-- straight down finds the ground. Open77.world.raycast traces Static and Dynamic only and falls through the open terrain
-- of the Badlands (collision group Terrain), so the Titan resource traces both groups for us (its `ground` export).
-- Terrain is the ground; a static hit up to `flush` metres above it is a slab or a rock flush with it, which a hostile
-- stands on; higher is a tree, a boulder or a roof, refused. No terrain at all (the city) leaves the static ground. The
-- answer is the indices of the good points and their heights.
local PROBE = { reach = 40, flush = 0.6, perFrame = 4 }
local function groundOf(answer)
    if type(answer) ~= "table" then return nil end
    local terrain, static = tonumber(answer.terrain), tonumber(answer.static)
    if terrain then
        if not static or static < terrain then return terrain end
        if static <= terrain + PROBE.flush then return static end
        return nil
    end
    return static
end
RegisterNetEvent(E.net.titanProbe, function(payload)
    if type(payload) ~= "table" or type(payload.points) ~= "table" then return end
    local requestId, points = payload.id, payload.points
    -- a ground check of living hostiles looks further (one may hang far over its ground); the spawn probe, PROBE.reach
    local reach = math.min(math.max(tonumber(payload.reach) or PROBE.reach, 1), 200)
    CreateThread(function()
        local indices, heights = {}, {}
        for first = 1, math.min(#points, 32), PROBE.perFrame do
            local chunk = {}
            for i = first, math.min(first + PROBE.perFrame - 1, #points, 32) do chunk[#chunk + 1] = points[i] end
            local called, answers, why = pcall(function() return exports.op77_lightrp_titans:ground(chunk, reach) end)
            if not called or type(answers) ~= "table" then
                log("ground probe unavailable: %s", tostring(called and why or answers))
                break
            end
            for k = 1, #chunk do
                local z = groundOf(answers[k])
                if z then indices[#indices + 1], heights[#heights + 1] = first + k - 1, z end
            end
            Wait(0)
        end
        TriggerServerEvent(E.net.titanGround, requestId, indices, heights)
    end)
end)

-- ---------------------------------------------------------------------------
-- The last hostiles of a wave: a red arrow above each, where the server last saw it (it sends the list every 250 ms while
-- fewer than ten are left, and an empty one when that is over). An arrow follows its hostile from list to list and goes
-- when the hostile is no longer listed.
local MARK = { lift = 2.6, max = 16,
    style = { shape = "arrow", radius = 1.0, height = 1.4, color = { r = 255, g = 59, b = 59, a = 230 }, maxDistance = 500 } }
local marks = {} -- hostile id -> marker handle
local function clearMarks()
    for key, handle in pairs(marks) do
        pcall(Open77.markers.remove, handle)
        marks[key] = nil
    end
end
local markRefused = false
RegisterNetEvent(E.net.titanMarks, function(list)
    if type(list) ~= "table" or type(Open77.markers) ~= "table" or type(Open77.markers.create) ~= "function" then return end
    local listed = {}
    for i, m in ipairs(list) do
        if i > MARK.max then break end
        local x, y, z = type(m) == "table" and tonumber(m.x), type(m) == "table" and tonumber(m.y), type(m) == "table" and tonumber(m.z)
        if x and y and z and m.id ~= nil then
            local key = tostring(m.id)
            local at = { x = x, y = y, z = z + MARK.lift }
            listed[key] = true
            if marks[key] then
                pcall(Open77.markers.update, marks[key], { position = at })
            else
                local options = { position = at }
                for k, v in pairs(MARK.style) do options[k] = v end
                local ok, handle, why = pcall(Open77.markers.create, options)
                if ok and handle then
                    marks[key] = handle
                elseif not markRefused then
                    markRefused = true -- said once: the next lists try again
                    log("hostile arrow refused: %s", tostring(ok and why or handle))
                end
            end
        end
    end
    for key, handle in pairs(marks) do
        if not listed[key] then
            pcall(Open77.markers.remove, handle)
            marks[key] = nil
        end
    end
end)

-- ---------------------------------------------------------------------------
-- From the server

RegisterNetEvent(E.net.titan, function(payload)
    if type(payload) ~= "table" then return end
    if payload.phase == "ended" then
        Titan.state = nil
        setEnemies(nil)
        clearMarks()
        LightRpUi.send(E.page.titan, { phase = "ended", result = payload.result })
        return
    end
    Titan.state = payload
    if payload.enemyIds then
        setEnemies(payload.enemyIds)
    end
    if payload.arrived == false then reportArrival() end
    -- the page does not need the relay filter
    local page = {}
    for k, v in pairs(payload) do if k ~= "enemyIds" then page[k] = v end end
    LightRpUi.send(E.page.titan, page)
end)

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then TriggerServerEvent(E.net.titanHello) end
end)
