-- The central square, shown once on the way out of the arrival hall (the guide's end, a skip,
-- a pause): server/modules/tutorial.lua sends the square's centre after the placement. Here we
-- wait for the move to be really over (op77_loadscreen's cover lifted, no game loading screen,
-- the body alive, standing near the centre, then `settleMs` more so the square has streamed),
-- then the camera circles the square, rising down and closing in, and blends back to the
-- player. The page shows a caption (ui/src/features/arrival/ArrivalTour.tsx).
-- SPACE (the first day's skip key) ends it; death, a loading screen or anything taking the
-- player ends it too. Never two at once; given up after `waitSeconds` without the conditions.
local C, E = LightRpTutorialConfig, LightRpEvents
local T = C.arrivalTour or {}
local Tour = {}
LightRpArrivalTour = Tour

local pending   -- { center, at, readySince }
local active    -- { camera, started, angle0, center, frozen, hud, seconds }

local function now() return Open77.time.monotonic() end
local function vec(x, y, z) return { x = x, y = y, z = z } end
local function clamp01(t) return math.max(0, math.min(1, t)) end
local function smoother(t) t = clamp01(t); return t * t * t * (t * (t * 6 - 15) + 10) end
local function lerp(a, b, t) return a + (b - a) * t end

local function loading()
    local screen = Open77.screen
    if screen and type(screen.isLoading) == "function" and screen.isLoading() then return true end
    if screen and type(screen.loadingState) == "function" then
        local ok, state = pcall(screen.loadingState)
        if ok and type(state) == "table" and state.active == true then return true end
    end
    if type(GetResourceState) == "function" and GetResourceState("op77_loadscreen") == "running" then
        local ok, covered = pcall(function() return exports.op77_loadscreen:isActive() end)
        if ok and covered == true then return true end
    end
    return false
end

-- Something else owns the player or the view.
local function blocked()
    local Ui = LightRpUi
    if Ui.promptActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode or Ui.creationActive then return true end
    for _, open in pairs(Ui.dialogs or {}) do if open then return true end end
    if LightRpFreecam and LightRpFreecam.isActive() then return true end
    if LightRpTutorial and LightRpTutorial.cinematic() then return true end
    local players = Open77.players
    return players ~= nil and type(players.isInVehicle) == "function" and players.isInVehicle() == true
end

-- Where the camera is at `u` (0..1) of the tour.
function Tour.pose(center, angle0, u)
    local e = smoother(u)
    local angle = math.rad(angle0 + (T.degrees or 250) * e)
    local radius = lerp(T.radius or 26, T.endRadius or 17, e)
    local height = lerp(T.height or 15, T.endHeight or 6, e)
    return vec(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z + height),
        lerp(T.fov or 58, T.endFov or 50, e)
end

local function caption(on)
    if not on then LightRpUi.send(E.page.arrivalTour, false); return end
    local skip = C.reveal and C.reveal.skip
    LightRpUi.send(E.page.arrivalTour, {
        title = T.title, subtitle = T.subtitle, lines = T.lines or {},
        durationMs = math.floor((T.seconds or 11) * 1000),
        skip = skip and (Open77.input.keyFor(skip.id) or skip.key) or nil,
    })
end

-- Back to the player: the view blends home, the body, the HUD and the voice HUD are theirs.
function Tour.stop(why)
    pending = nil
    local a = active
    if not a then return end
    active = nil
    local released = type(Open77.camera.deactivate) == "function" and Open77.camera.deactivate({ blendMs = T.returnMs or 1100 })
    if released then
        local id = a.camera
        SetTimeout((T.returnMs or 1100) + 150, function() pcall(Open77.camera.destroy, id) end)
    else
        pcall(Open77.camera.destroy, a.camera)
    end
    if a.frozen then Open77.character.setFrozen(false) end
    if a.hud then if LightRpHud then LightRpHud.restoreVanilla() else Open77.hud.setVisible("all", true) end end
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:arrival", false)
    caption(false)
    if why then LightRpUi.log("arrival tour: %s", why) end
end
function Tour.active() return active ~= nil end
function Tour.pending() return pending ~= nil end
function Tour.skip() if active then Tour.stop() end end

local function start(center, p)
    -- start on the player's side of the square, looking across it
    local angle0 = math.deg(math.atan(p.y - center.y, p.x - center.x))
    local position, fov = Tour.pose(center, angle0, 0)
    local look = vec(center.x, center.y, center.z + (T.lookHeight or 2.0))
    local id, why = Open77.camera.create({ position = position, lookAt = look, fov = fov, thirdPersonBody = true })
    if not id then LightRpUi.log("arrival tour camera: %s", tostring(why)); return false end
    if not Open77.camera.activate(id, { blendMs = T.blendMs or 900 }) then pcall(Open77.camera.destroy, id); return false end
    active = { camera = id, started = now(), angle0 = angle0, center = center, look = look, seconds = T.seconds or 11 }
    active.frozen = Open77.character.setFrozen(true) == true
    active.hud = Open77.hud.setVisible("all", false) == true
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:arrival", true)
    caption(true)
    return true
end

-- One step of the waiting or of the tour (the loop below, ~every frame).
function Tour.tick()
    if active then
        local c = Open77.character.state()
        if not c or not c.alive then return Tour.stop("the player died") end
        if loading() then return Tour.stop("a loading screen") end
        local t = now() - active.started
        if t >= active.seconds then return Tour.stop() end
        local position, fov = Tour.pose(active.center, active.angle0, t / active.seconds)
        Open77.camera.setTransform(active.camera, { position = position, fov = fov })
        Open77.camera.lookAt(active.camera, active.look)
        return
    end
    if not pending then return end
    local t = now()
    if t - pending.at > (T.waitSeconds or 60) then pending = nil; return end
    local c = Open77.character.state()
    local p = c and c.position
    local near = p and math.sqrt((p.x - pending.center.x) ^ 2 + (p.y - pending.center.y) ^ 2) <= (T.nearMetres or 45)
    if not (c and c.alive and near) or loading() or blocked() then pending.readySince = nil; return end
    pending.readySince = pending.readySince or t
    if (t - pending.readySince) * 1000 < (T.settleMs or 1800) then return end
    local center = pending.center
    pending = nil
    start(center, p)
end

RegisterNetEvent(E.net.arrivalTour, function(payload)
    if not (T.enabled and type(payload) == "table" and type(payload.center) == "table") then return end
    local x, y, z = tonumber(payload.center.x), tonumber(payload.center.y), tonumber(payload.center.z)
    if not (x and y and z) then return end
    if active then Tour.stop() end
    pending = { center = vec(x, y, z), at = now() }
end)

CreateThread(function()
    while true do
        if pending or active then
            local ok, err = pcall(Tour.tick)
            if not ok then LightRpUi.log("arrival tour: %s", tostring(err)); pcall(Tour.stop) end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then pcall(Tour.stop) end
end)
