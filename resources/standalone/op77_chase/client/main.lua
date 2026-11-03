-- op77_chase client: draws the chase (1v1, Most Wanted, NCPD Escape) in Light RP's own activity HUD
-- and keeps the map fair. Decides nothing: the server sends, this draws.
--
--   op77_chase:hud    a match payload (server/match.lua, server/wanted.lua) or { state = "idle" }
--   op77_chase:queue  a queue payload ({ queued = false } when out)
--   op77_chase:feed   { text, tone, title }: a message for the HUD's feed
--   op77_chase:police (to the server) NCPD Escape: what this game did with the wanted level
--
-- The HUD is exports.op77_lightrp:ActivityHudShow / ActivityHudPush / ActivityHudClear
-- (Light RP's page, in Light RP's design). Every call is pcall'd: without it (an older
-- Light RP, the page not up) nothing is drawn here and the server keeps sending
-- notifications - this client tells it which with op77_chase:hudFeed. A feed line with no
-- HUD to land in becomes a notice through exports.op77_lightrp:Notice, and only without
-- Light RP an open77_notifications toast.
--
-- The map (op77_map3d, optional): the runner's dot is hidden from the cops
-- (setPlayerDotsHidden), the extraction point and the last dispatch sighting are blips,
-- and the runner's GPS is set to the extraction (his own waypoint is put back after).
local HUD, NOTIFY, MAP = "op77_lightrp", "open77_notifications", "op77_map3d"
local V = ChaseView

local S = { match = nil, queue = nil, shown = false, shownKey = nil, feed = nil,
    dotsKey = nil, extractionKey = nil, sightingKey = nil, waypoint = nil, waypointSet = nil }
ChaseClient = S

local function running(name)
    if type(GetResourceState) ~= "function" then return true end
    return GetResourceState(name) == "running"
end

-- exports[name]:method(...) without ever throwing: value(s) | false, reason.
local function call(name, method, ...)
    if not running(name) then return false, "not_running" end
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local target = exports[name]
        return target[method](target, table.unpack(args, 1, args.n))
    end)
    if not ok then return false, tostring(a) end
    return a, b
end
S.call = call

local KIND = { info = "info", success = "success", danger = "warning", accent = "info" }

-- A notification in Light RP's own notice (exports.op77_lightrp:Notice); the platform's
-- open77_notifications only when Light RP cannot show it (stopped, older, page not up).
local function notify(tone, title, text, ms)
    local kind, head, duration = KIND[tone or "info"] or "info", title or "NCPD Chase", ms or 5000
    if call(HUD, "Notice", { kind = kind, title = head, body = text, durationMs = duration }) == true then return end
    call(NOTIFY, "show", { type = kind, title = head, message = text, durationMs = duration })
end

-- The server routes this player's messages to the feed while the HUD is up.
local function setFeed(on)
    on = on == true
    if S.feed == on then return end
    S.feed = on
    TriggerServerEvent("op77_chase:hudFeed", on)
end

-- ---------------------------------------------------------------- HUD

local function clearHud()
    if S.shown then call(HUD, "ActivityHudClear") end
    S.shown, S.shownKey = false, nil
    setFeed(false)
end

local function showHud(hud, dedupe)
    if hud == nil then return clearHud() end
    local key = dedupe and V.key(hud) or nil
    if key and S.shown and key == S.shownKey then return true end
    local ok = call(HUD, "ActivityHudShow", hud)
    if ok == true then
        S.shown, S.shownKey = true, key
        setFeed(true)
        return true
    end
    S.shown, S.shownKey = false, nil
    setFeed(false)
    return false
end

local function pushHud(kind, payload)
    if not S.shown then return false end
    return call(HUD, "ActivityHudPush", kind, payload) == true
end

local function feed(item)
    local lines = V.split(item.text, 96)
    for _, line in ipairs(lines) do
        if not pushHud("feed", { text = line, tone = item.tone }) then
            -- No HUD (or not ours any more): the whole message as a notification.
            notify(item.tone, item.title, item.text, 6000)
            return
        end
    end
end

-- ---------------------------------------------------------------- map

local function samePoint(a, b)
    return type(a) == "table" and type(b) == "table" and math.abs((a.x or 0) - (b.x or 0)) < 1 and math.abs((a.y or 0) - (b.y or 0)) < 1
end

-- Players only (a positive id): a bot has no dot, and the map's export takes player ids.
local function setDots(ids)
    local players = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        if type(id) == "number" and id > 0 and id % 1 == 0 then players[#players + 1] = id end
    end
    ids = players
    local key = #ids > 0 and table.concat(ids, ",") or ""
    if key == S.dotsKey then return end
    S.dotsKey = key
    if key ~= "" then call(MAP, "setPlayerDotsHidden", true, ids)
    else call(MAP, "setPlayerDotsHidden", false) end
end

local function restoreWaypoint()
    if S.waypointSet == nil then return end
    local current = call(MAP, "getWaypoint")
    -- Only if the GPS still points at the extraction (the player may have set his own).
    if current == false or current == nil or samePoint(current, S.waypointSet) then
        if type(S.waypoint) == "table" then call(MAP, "setWaypoint", S.waypoint)
        elseif current then call(MAP, "clearWaypoint") end
    end
    S.waypoint, S.waypointSet = nil, nil
end

local function setExtraction(pos, routed)
    if type(pos) ~= "table" then
        if S.extractionKey then
            S.extractionKey = nil
            call(MAP, "removeBlip", "op77_chase:extraction")
            restoreWaypoint()
        end
        return
    end
    local key = ("%.0f,%.0f"):format(pos.x or 0, pos.y or 0)
    if key == S.extractionKey then return end
    S.extractionKey = key
    call(MAP, "addBlip", { id = "extraction", position = { x = pos.x, y = pos.y, z = pos.z or 0 }, icon = "flag",
        color = "#FFCC00", label = "Extraction", description = "The runner gets out by reaching it.",
        category = "mission", pulse = true, edge = true, priority = 2 })
    if routed then
        if S.waypointSet == nil then
            local current = call(MAP, "getWaypoint")
            S.waypoint = type(current) == "table" and current or nil
        end
        S.waypointSet = { x = pos.x, y = pos.y, z = pos.z or 0 }
        call(MAP, "setWaypoint", S.waypointSet)
    end
end

local function setSighting(sighting)
    if type(sighting) ~= "table" then
        if S.sightingKey then
            S.sightingKey = nil
            call(MAP, "removeBlip", "op77_chase:sighting")
        end
        return
    end
    local key = ("%.0f,%.0f,%d"):format(sighting.x or 0, sighting.y or 0, math.floor(tonumber(sighting.radius) or 0))
    if key == S.sightingKey then return end
    S.sightingKey = key
    call(MAP, "addBlip", { id = "sighting", position = { x = sighting.x, y = sighting.y, z = sighting.z or 0 }, icon = "target",
        color = "#FF5A4E", label = ("Last sighting (%d m)"):format(math.floor(tonumber(sighting.radius) or 0)),
        description = "Dispatch: the suspect is somewhere within this radius.", category = "mission", pulse = true, edge = true,
        routable = true, priority = 2 })
end

local function syncMap()
    local m = S.match
    local playing = m ~= nil and (m.state == "placing" or m.state == "countdown" or m.state == "active" or m.state == "intermission")
    setDots(playing and m.hideDots or nil)
    setExtraction(playing and m.state == "active" and m.extraction or nil, m ~= nil and m.role == "runner")
    setSighting(playing and m.state == "active" and m.sighting or nil)
end
S.syncMap = syncMap

local function forgetMap()
    S.dotsKey, S.extractionKey, S.sightingKey = nil, nil, nil
end

-- ---------------------------------------------------------------- NCPD Escape: the police probe

-- The server sets this player's wanted level (open77_prevention applies it to this game);
-- nothing tells the server whether the game took it. While an NCPD Escape run is on with
-- stars (payload.wanted > 0), every PROBE_EVERY-th payload (the server pushes every 500 ms,
-- so ~2 s) sends what Open77.prevention.state() says: the level this game holds, and
-- whether population suppression refuses raises. A handful of numbers; the server only
-- warns about it.
local PROBE_EVERY = 4

local function policeProbe(m)
    if not (m and m.activity == V.PVE and m.police == "ncpd" and m.state == "active") then S.probeCount = nil return end
    local expected = tonumber(m.wanted) or 0
    if expected <= 0 then return end
    S.probeCount = (S.probeCount or 0) + 1
    if S.probeCount % PROBE_EVERY ~= 1 then return end
    local api = type(Open77) == "table" and Open77.prevention or nil
    if type(api) ~= "table" or type(api.state) ~= "function" then return end
    local ok, state = pcall(api.state)
    if not ok or type(state) ~= "table" then return end
    TriggerServerEvent("op77_chase:police", { expected = expected, requested = tonumber(state.requestedLevel) or 0,
        suppressed = state.populationSuppressed == true, acknowledged = state.levelAcknowledged == true,
        attached = state.scriptAttached ~= false })
end
S.policeProbe = policeProbe

-- ---------------------------------------------------------------- what the server sends

local function render()
    local m = S.match
    if m then return showHud(V.hud(m), false) end
    local hud = V.queue(S.queue)
    if hud then return showHud(hud, true) end
    clearHud()
end
S.render = render

RegisterNetEvent("op77_chase:hud", function(payload)
    if type(payload) ~= "table" then return end
    local prev = S.match
    S.match = (payload.state ~= nil and payload.state ~= "idle") and payload or nil
    render()
    syncMap()
    if S.match and S.shown then
        for _, beat in ipairs(V.beats(prev, payload)) do pushHud(beat.kind, beat.payload) end
    end
    policeProbe(S.match)
end)

RegisterNetEvent("op77_chase:queue", function(payload)
    if type(payload) ~= "table" then return end
    S.queue = payload.queued == true and payload or nil
    if S.match == nil then render() end
end)

RegisterNetEvent("op77_chase:feed", function(item)
    if type(item) ~= "table" or type(item.text) ~= "string" then return end
    feed(item)
end)

-- ---------------------------------------------------------------- lifetimes

AddEventHandler("onClientResourceStart", function(name)
    if name == HUD then
        -- Light RP's HUD is back: draw again (it lost whatever was shown).
        S.shown, S.shownKey = false, nil
        CreateThread(function() Wait(1500); render() end)
    elseif name == MAP then
        forgetMap()
    end
end)

-- The map (re)loaded: it forgot the hidden dots and the blips.
AddEventHandler("op77_map3d:ready", function()
    forgetMap()
    syncMap()
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == HUD then
        S.shown, S.shownKey = false, nil
        setFeed(false)
    elseif name == MAP then
        forgetMap()
    elseif name == GetCurrentResourceName() then
        -- The map drops our blips and hidden dots itself, Light RP our HUD; the GPS is ours.
        restoreWaypoint()
    end
end)
