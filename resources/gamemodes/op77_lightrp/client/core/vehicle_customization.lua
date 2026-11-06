local Ui, Studio = LightRpUi, LightRpVehicleCustomization
local C = Studio.camera
local NET, PAGE = LightRpEvents.net.customization, LightRpEvents.page.customization
local Custom, session = {}, nil
LightRpVehicleCustomizationClient = Custom
-- A performance stage rebuilds the car (same id): it may vanish or shift for a moment.
local RESPAWN_GRACE_MS, WARNING_DELAY_MS, WARNING_GIVE_UP_MS = 8000, 1500, 6000
function Custom.isActive() return session ~= nil end
local function stop(notify)
    local s = session; if not s then return end
    session = nil
    if notify then TriggerServerEvent(NET, { operation = "close", session = s.id }) end
    if s.camera then Open77.camera.destroy(s.camera) end -- destroying the active definition returns the view
    if s.cinematic then
        -- ordinary HUD claims remain intact; the player's own /cinematic comes back
        local restored, reason
        if LightRpCamera then restored, reason = LightRpCamera.restoreCinematic() else restored, reason = Open77.hud.setCinematic(false) end
        if not restored then Ui.log("vehicle cinematic release failed: %s", tostring(reason)) end
    end
    if s.frozen then Open77.character.setFrozen(false) end
    if s.puppetHidden then Open77.players.setLocalPuppetVisible(true) end
    if s.interactHidden then LightRpInteract.setHidden(false) end
    Ui.dialogs.customization = nil
    Ui.setPromptFocus(false)
    Ui.send(PAGE, { kind = "closed", session = s.id })
end
-- Workshop bays are narrow: the orbit would put the camera inside a pillar or a barrel.
-- One ray per frame from the car to the wanted spot; the camera stops short of the first
-- obstacle (never closer than MIN_RADIUS). The car itself never counts as an obstacle.
local MIN_RADIUS, CLEARANCE = 2.0, 0.35
local function unobstructed(s, p, position)
    if type(Open77.world) ~= "table" or type(Open77.world.raycast) ~= "function" then return nil end
    local from = { x = p.x, y = p.y, z = p.z + s.targetHeight }
    local ok, hit = pcall(Open77.world.raycast, from, position, { entities = true })
    if not ok or type(hit) ~= "table" or not hit.hit or type(hit.distance) ~= "number" then return nil end
    if type(hit.entity) == "table" and hit.entity.vehicleId == s.vehicle then return nil end
    local dx, dy, dz = position.x - from.x, position.y - from.y, position.z - from.z
    local length = math.sqrt(dx*dx + dy*dy + dz*dz)
    if length <= 0 or hit.distance >= length then return nil end
    local keep = math.max(MIN_RADIUS, hit.distance - CLEARANCE) / length
    if keep >= 1 then return nil end
    return { x = from.x + dx*keep, y = from.y + dy*keep, z = from.z + dz*keep }
end
local function shot(s, v)
    local a = math.rad(s.angle)
    local p = v.position
    local position = { x = p.x + math.cos(a)*s.radius, y = p.y + math.sin(a)*s.radius, z = p.z+s.height }
    local radius, height = s.radius, s.height
    local clear = unobstructed(s, p, position)
    if clear then
        position, height = clear, clear.z - p.z
        radius = math.sqrt((clear.x - p.x)^2 + (clear.y - p.y)^2)
    end
    return { position = position,
        rotation = { yaw = (s.angle+90)%360, pitch = -math.deg(math.atan((height-s.targetHeight)/math.max(.1, radius))) }, fov = C.fov }
end
-- `why` goes to the client log only: the player reads the generic text.
local function refuse(token, why, text)
    Ui.log("auto studio refused: %s", tostring(why or "unknown"))
    if session and session.id == token then stop(false) end
    TriggerServerEvent(NET, { operation = "close", session = token })
    Ui.send(PAGE, { kind = "unavailable", session = token, text = text or "Vehicle preview is unavailable. Reopen the garage and try again." })
end

-- What THIS game can show. The server decides what is sold; the client greys what it
-- would not render (a parts pack it has not loaded, stage records TweakXL did not create).
local function running(resource)
    if type(GetResourceState) ~= "function" then return true end -- cannot tell: the server decides
    return GetResourceState(resource) == "running"
end
local function knownRecord(record)
    if type(Open77.data) ~= "table" or type(Open77.data.vehicle) ~= "function" then return true end
    local ok, found, why = pcall(Open77.data.vehicle, record)
    if not ok then return true end
    return found ~= nil or (why ~= "record_unknown" and why ~= "record_wrong_kind")
end
local function grey(entry, reason) entry.available, entry.reason = false, reason end
local function localChecks(p)
    local look = nil
    if type(Open77.vehicles.customizationAvailable) == "function" then
        local ok, state = pcall(Open77.vehicles.customizationAvailable, p.vehicle.vehicleId)
        if ok and type(state) == "table" then look = state end
    end
    for _, entry in ipairs(type(p.categories) == "table" and p.categories or {}) do
        if entry.available then
            if (entry.id == "rims" or entry.id == "body" or entry.id == "windows") and type(entry.pack) == "string" and not running(entry.pack) then
                grey(entry, Studio.unsupported.clientPack)
            elseif entry.id == "livery" and look and look.twintone == false then
                grey(entry, Studio.unsupported.clientLivery)
            elseif entry.id == "performance" and type(entry.options) == "table" then
                local any = false
                for _, stage in ipairs(entry.options.stages or {}) do
                    if stage.stage > 0 and stage.record then
                        if knownRecord(stage.record) then any = true else stage.available, stage.missing = false, true end
                    end
                end
                if not any then grey(entry, Studio.unsupported.clientStages) end
            end
        end
    end
end
-- After a rims / body / window tint / livery change, what this game skipped (customizationAvailable).
-- A livery whose template this game lacks (pack missing or older than the server's) is
-- reported as `profile:<id>:not_for_model`: the pack resource is server-only, so its state
-- cannot be read here beforehand.
-- A tint still waiting for its glass meshes (`pending_mesh`) is checked again.
local function skippedWarning(s, category)
    local ok, state = pcall(Open77.vehicles.customizationAvailable, s.vehicle)
    if not ok or type(state) ~= "table" then return nil, true end
    if (state.appliedRev or 0) < (state.rev or 0) then return nil, false end -- not applied yet
    local prefix = category == "rims" and "attach:rims." or category == "windows" and "tint:"
        or category == "livery" and "profile:"
        or ("attach:" .. GetCurrentResourceName() .. ":")
    for _, entry in ipairs(state.skipped or {}) do
        if type(entry) == "string" and entry:sub(1, #prefix) == prefix then
            local reason = entry:match(":([%w_]+)$")
            if reason == "pending_mesh" then return nil, false end
            return Studio.warnings[reason] or Studio.warnings.other, true
        end
    end
    return nil, true
end

-- Per-category framing, eased in. Angles are relative to the car's heading.
local function ease(t) return t < .5 and 2*t*t or 1 - (-2*t + 2)^2/2 end
local function preset(s, v, name)
    local target = C.presets and (C.presets[name] or C.presets.default)
    if not target then return end
    local yaw = v.yaw or 0
    -- shortest way round to the new angle
    local goal = s.angle + ((yaw + target.angle - s.angle + 180) % 360 - 180)
    s.blend = { at = GetGameTimer(), from = { angle = s.angle, radius = s.radius, height = s.height, targetHeight = s.targetHeight },
        to = { angle = goal, radius = target.radius, height = target.height, targetHeight = target.targetHeight } }
    s.rotating = target.orbit ~= false
end
local function blend(s, now)
    local b = s.blend
    if not b then return end
    local t = math.min(1, math.max(0, (now - b.at) / math.max(1, C.presetMs or 1)))
    local k = ease(t)
    for key, goal in pairs(b.to) do s[key] = b.from[key] + (goal - b.from[key]) * k end
    if t >= 1 then s.blend = nil end
end

local function start(p)
    if session then stop(true) end
    local character = Open77.character.state()
    local registry = Open77.camera.cameras()
    local busy = (not Ui.ready and "ui not ready") or (not Ui.characterReady and "character not ready")
        or (Ui.creationActive and "character creation") or (Ui.actionFocus and "action focus")
        or (Ui.supportMode and ("support " .. tostring(Ui.supportMode)))
        or ((not character or not character.alive or not character.attached) and "character not alive and attached")
        or (not registry and "camera registry unavailable") or (registry.held and "camera held")
    if busy then refuse(p.session, busy); return end
    local v = Open77.vehicles.get(p.vehicle.vehicleId)
    if not v or not v.position or v.streamed == false then refuse(p.session, "vehicle not streamed " .. tostring(p.vehicle.vehicleId)); return end
    local s = { id = p.session, vehicle = p.vehicle.vehicleId, angle = (v.yaw or 0)+35, radius = C.radius,
        height = C.height, targetHeight = C.targetHeight, rotating = true, clock = GetGameTimer(), anchor = v.position }
    local transform = shot(s,v); transform.thirdPersonBody = true
    local camera, why = Open77.camera.create(transform)
    if not camera then refuse(p.session, "camera create: " .. tostring(why)); return end
    s.camera, session = camera, s
    local frozen, frozenWhy = Open77.character.setFrozen(true)
    if not frozen then refuse(p.session, "freeze: " .. tostring(frozenWhy)); return end
    s.frozen = true
    Ui.setMenuOpen(false)
    Ui.dialogs.customization = true
    Ui.setPromptFocus(true)
    local hidden, reason = Open77.hud.setCinematic(true, 0.01)
    if not hidden then refuse(p.session, "cinematic: " .. tostring(reason)); return end
    s.cinematic = true
    -- The orbit passes behind the player standing on the marker, who then hides the car
    -- (measured 2026-11-06, Bay 01). Hide the avatar on this screen only: other players
    -- still see them. A client without the native keeps the avatar visible.
    if type(Open77.players) == "table" and type(Open77.players.setLocalPuppetVisible) == "function" then
        local ok, why = Open77.players.setLocalPuppetVisible(false)
        if ok == true then s.puppetHidden = true else Ui.log("studio avatar hide unavailable: %s", tostring(why)) end
    end
    -- The studio marker's light cylinder crosses the foreground on part of the orbit, and
    -- the bay's prompt would float over the car: hide markers, rings and prompts until close.
    if LightRpInteract then LightRpInteract.setHidden(true); s.interactHidden = true end
    localChecks(p)
    Ui.send(PAGE, { kind = "presentation", session = s.id })
    CreateThread(function()
        local ok, failure = pcall(function()
            local accepted, blend = Open77.camera.activate(camera, { blendMs = C.blendMs })
            if not accepted then if session == s then refuse(p.session, "camera activate: " .. tostring(blend)) end; return end
            if blend then local _, reason = blend:await(); if reason then if session == s then refuse(p.session, "camera blend: " .. tostring(reason)) end; return end end
            if session ~= s then return end
            s.active = true
            Ui.send(PAGE, p)
        end)
        if not ok and session == s then refuse(p.session, "camera: " .. tostring(failure)) end
    end)
end
RegisterNetEvent(NET, function(p)
    if type(p) ~= "table" then return end
    if p.kind == "open" then
        -- The server sends the category tree as JSON text (too deep for a net event), one
        -- text per category (json.decode refuses a text over 1024 values).
        if type(p.categoriesJson) == "table" then
            local categories = {}
            for i, text in ipairs(p.categoriesJson) do
                local ok, decoded, why = pcall(json.decode, text)
                if not ok or type(decoded) ~= "table" then
                    refuse(p.session, string.format("category %d of %d (%d bytes): %s", i, #p.categoriesJson,
                        type(text) == "string" and #text or 0, tostring(ok and why or decoded))); return
                end
                categories[i] = decoded
            end
            p.categories, p.categoriesJson = categories, nil
        end
        start(p)
    elseif session and p.session == session.id then
        if p.kind == "closed" then stop(false)
        else
            if p.kind == "response" and p.ok and (p.category == "rims" or p.category == "body" or p.category == "windows"
                or p.category == "livery")
                and type(Open77.vehicles.customizationAvailable) == "function" then
                local now = GetGameTimer()
                session.check = { category = p.category, at = now + WARNING_DELAY_MS, until_ = now + WARNING_GIVE_UP_MS }
            end
            Ui.send(PAGE,p)
        end
    end
end)
function Custom.bind(page)
    page:on(PAGE, function(p)
        local s = session
        if not s or type(p) ~= "table" or p.session ~= s.id then return end
        if p.operation == "close" then stop(true)
        elseif p.operation == "camera" then
            if p.command ~= "preset" then s.blend = nil end -- a manual move ends the framing
            if p.command == "rotate" then s.rotating = p.enabled == true
            elseif p.command == "left" then s.angle = s.angle-20
            elseif p.command == "right" then s.angle = s.angle+20
            elseif p.command == "zoomIn" then s.radius = math.max(4,s.radius-.5)
            elseif p.command == "zoomOut" then s.radius = math.min(10,s.radius+.5)
            elseif p.command == "preset" and type(p.category) == "string" then
                local v = Open77.vehicles.get(s.vehicle)
                if v then preset(s, v, p.category) end
                Ui.send(PAGE, { kind = "camera", session = s.id, rotating = s.rotating })
            end
        elseif p.operation == "preview" or p.operation == "save" then
            if p.operation == "save" and p.category == "performance" then s.graceUntil = GetGameTimer() + RESPAWN_GRACE_MS end
            TriggerServerEvent(NET,p)
        end
    end)
end
AddEventHandler("onClientResourceStop",function(name) if name == GetCurrentResourceName() then stop(true) end end)
CreateThread(function()
    while true do
        Wait(session and 0 or 200)
        local s = session
        if s then
            local ok, why = pcall(function()
                local char, v, registry = Open77.character.state(), Open77.vehicles.get(s.vehicle), Open77.camera.cameras()
                local now = GetGameTimer()
                local respawning = s.graceUntil and now < s.graceUntil
                if respawning and (not v or not v.position or v.streamed == false) then return end
                if not char or not char.attached or not char.alive or not Ui.characterReady or not v or not v.position
                    or (v.speed or 0)>.5 or next(v.occupants or {}) ~= nil or Ui.creationActive then stop(true); return end
                if math.abs(v.position.x-s.anchor.x)+math.abs(v.position.y-s.anchor.y)+math.abs(v.position.z-s.anchor.z)>2 then
                    if not respawning then stop(true); return end
                    s.anchor = v.position -- the rebuilt car settles where the engine puts it
                end
                if not s.active then return end
                if not registry or not registry.held or registry.activeCamera ~= s.camera then stop(true); return end
                local dt = math.min(.05,math.max(0,(now-s.clock)/1000)); s.clock = now
                blend(s, now)
                if s.rotating and not s.blend then s.angle = (s.angle+C.degreesPerSecond*dt)%360 end
                local moved = Open77.camera.setTransform(s.camera, shot(s,v))
                if not moved then stop(true); return end
                local check = s.check
                if check and now >= check.at then
                    local text, done = skippedWarning(s, check.category)
                    if text then Ui.send(PAGE, { kind = "warning", session = s.id, category = check.category, text = text }) end
                    if done or now >= check.until_ then s.check = nil else check.at = now + 500 end
                end
            end)
            if not ok and session == s then Ui.log("vehicle orbit failed: %s", tostring(why)); stop(true) end
        end
    end
end)
