-- The events board at The Crossing (server/modules/events_board.lua): the server owns
-- the TV prop and serves its page; this file paints that page on the TV's screen
-- while the player is near it. One WebUI surface, hud-suppressed (it never draws over
-- the viewport), whose document is the board's URL, bound to the prop's screen with
-- Open77.media.bind -- the native open77_media is built on. Out of range, or without
-- a page to show, nothing exists here.
local E = LightRpEvents
local resource = GetCurrentResourceName()

local tv = nil                                      -- the server's last word (EB.info), or nil
local screen = { page = nil, native = nil, key = nil }
local retryAt, warned = 0, {}
local RETRY_MS = 30000

local function log(fmt, ...)
    if LightRpUi and LightRpUi.log then LightRpUi.log(fmt, ...) else print("[lightrp] " .. string.format(fmt, ...)) end
end
local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    log(fmt, ...)
end

local function vector(v)
    if type(v) ~= "table" then return nil end
    local x, y, z = tonumber(v.x or v[1]), tonumber(v.y or v[2]), tonumber(v.z or v[3])
    if x == nil or y == nil or z == nil then return nil end
    return { x = x, y = y, z = z }
end
-- The rectangle in the shape the native reads (named vectors).
local function nativeQuad(q)
    if type(q) ~= "table" then return nil end
    local offset, right, up = vector(q.offset), vector(q.right), vector(q.up)
    if not (offset and right and up) then return nil end
    return { offset = offset, right = right, up = up, faces = vector(q.faces), width = tonumber(q.width), height = tonumber(q.height) }
end

local function keyOf(info)
    return table.concat({ tostring(info.prop), tostring(info.url), tostring(info.width), tostring(info.height),
        tostring(info.quad and info.quad.width), tostring(info.quad and info.quad.height) }, "|")
end

local function drop()
    local media = type(Open77.media) == "table" and Open77.media or nil
    if screen.native ~= nil and media and type(media.unbind) == "function" then pcall(media.unbind, screen.native) end
    if screen.page ~= nil then pcall(function() screen.page:destroy() end) end
    screen.page, screen.native, screen.key = nil, nil, nil
end

local function materialise(info, distance)
    if type(Open77.media) ~= "table" or type(Open77.media.bind) ~= "function" or type(Open77.media.unbind) ~= "function" then
        warnOnce("media", "events board: the native media API is missing on this client: the TV stays dark")
        return false
    end
    if type(WebUI) ~= "table" or type(WebUI.create) ~= "function" then
        warnOnce("webui", "events board: WebUI unavailable: the TV stays dark")
        return false
    end
    local quad = nativeQuad(info.quad)
    if not quad then warnOnce("quad", "events board: the screen's rectangle is unreadable") return false end
    local page, why = WebUI.create({
        entry = info.url,            -- a remote URL: served under the "remote" page policy
        layer = "hud",
        width = math.floor(tonumber(info.width) or 1280),
        height = math.floor(tonumber(info.height) or 720),
        fps = math.floor(tonumber(info.fps) or 15),
        transparent = false,
        visible = true,
        hudSuppressed = true,        -- drawn on the TV's quad, never over the viewport
    })
    if page == nil then
        if why ~= "resource_preparing" then
            warnOnce("create:" .. tostring(why), "events board: page not created (%s)", tostring(why))
            retryAt = GetGameTimer() + RETRY_MS
        end
        return false
    end
    local id, bindWhy = Open77.media.bind({ prop = info.prop, page = page, label = info.label, quad = quad })
    if id == nil then
        pcall(function() page:destroy() end)
        warnOnce("bind:" .. tostring(bindWhy), "events board: screen not bound (%s)", tostring(bindWhy))
        retryAt = GetGameTimer() + RETRY_MS
        return false
    end
    screen.page, screen.native, screen.key = page, id, keyOf(info)
    log("events board: screen bound (prop %s, %.0f m away, %s)", tostring(info.prop), distance or -1, tostring(info.url))
    return true
end

local function distanceTo(p)
    if type(p) ~= "table" or type(Open77.character) ~= "table" or type(Open77.character.position) ~= "function" then return nil end
    local x, y, z = Open77.character.position() -- three numbers, not a table
    if x == nil or y == nil or z == nil then return nil end
    local dx, dy, dz = (tonumber(p.x) or 0) - x, (tonumber(p.y) or 0) - y, (tonumber(p.z) or 0) - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Once a second: in range, a screen; out of range (with some slack), none.
local function reselect()
    local info = tv
    local usable = type(info) == "table" and type(info.prop) == "string" and type(info.url) == "string" and info.url ~= ""
    if not usable then drop() return end
    if screen.key ~= nil and screen.key ~= keyOf(info) then drop() end
    local distance = distanceTo(info.position)
    if distance == nil then return end
    local radius = tonumber(info.drawRadius) or 60
    if screen.page then
        if distance > radius + (tonumber(info.drawHysteresis) or 15) then drop() end
    elseif distance <= radius and GetGameTimer() >= retryAt then
        materialise(info, distance)
    end
end

-- Staff: /lightrp.board aim -- what the crosshair is on, for the server to hang the TV
-- there. Static and terrain only (a car or a passer-by is not a wall); older clients
-- refuse `groups`, then the plain static trace.
RegisterNetEvent(E.net.eventsBoardAim, function(req)
    local reply = { token = type(req) == "table" and req.token or nil }
    local cam = type(Open77.camera) == "table" and Open77.camera or nil
    local reach = type(req) == "table" and tonumber(req.maxDistance) or 250
    if not cam or type(cam.aimRay) ~= "function" then
        reply.error = "aim_unavailable"
    else
        local ok, ray, why = pcall(cam.aimRay, reach, { groups = { "Static", "Terrain" } })
        if not ok or ray == nil then ok, ray, why = pcall(cam.aimRay, reach, { dynamic = false }) end
        if not ok or ray == nil then
            reply.error = tostring(ok and why or ray)
        elseif not ray.hit then
            reply.error = "nothing_under_crosshair"
        else
            reply.position, reply.normal = vector(ray.position), vector(ray.normal)
            if type(Open77.character) == "table" and type(Open77.character.position) == "function" then
                local x, y, z = Open77.character.position()
                if x and y and z then reply.from = { x = x, y = y, z = z } end
            end
        end
    end
    TriggerServerEvent(E.net.eventsBoardAimed, reply)
end)

RegisterNetEvent(E.net.eventsBoardTv, function(info)
    if type(info) ~= "table" then return end
    tv = info
    retryAt = 0
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ok, err = pcall(reselect)
        if not ok then warnOnce("reselect:" .. tostring(err), "events board: %s", tostring(err)) end
    end
end)

AddEventHandler("onClientResourceStart", function(name)
    -- a restarted script asks again which prop the TV is
    if name == resource then TriggerServerEvent(E.net.eventsBoardHello) end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == resource then drop() end
end)
