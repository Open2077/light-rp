local Ui, C = LightRpUi, LightRpVehicleCustomization.camera
local NET, PAGE = LightRpEvents.net.customization, LightRpEvents.page.customization
local Custom, session = {}, nil
LightRpVehicleCustomizationClient = Custom
function Custom.isActive() return session ~= nil end
local function stop(notify)
    local s = session; if not s then return end
    session = nil
    if notify then TriggerServerEvent(NET, { operation = "close", session = s.id }) end
    if s.camera then Open77.camera.destroy(s.camera) end -- destroying the active definition returns the view
    if s.frozen then Open77.character.setFrozen(false) end
    Ui.dialogs.customization = nil
    Ui.setPromptFocus(false)
    Ui.send(PAGE, { kind = "closed", session = s.id })
end
local function shot(s, v)
    local a = math.rad(s.angle)
    local p = v.position
    return { position = { x = p.x + math.cos(a)*s.radius, y = p.y + math.sin(a)*s.radius, z = p.z+C.height },
        rotation = { yaw = (s.angle+90)%360, pitch = -math.deg(math.atan((C.height-C.targetHeight)/s.radius)) }, fov = C.fov }
end
local function refuse(token, text)
    if session and session.id == token then stop(false) end
    TriggerServerEvent(NET, { operation = "close", session = token })
    Ui.send(PAGE, { kind = "unavailable", session = token, text = text or "Vehicle preview is unavailable. Reopen the garage and try again." })
end
local function start(p)
    if session then stop(true) end
    local character = Open77.character.state()
    local registry = Open77.camera.cameras()
    if not Ui.ready or not Ui.characterReady or Ui.creationActive or Ui.actionFocus or Ui.supportMode
        or not character or not character.alive or not character.attached or not registry or registry.held then
        refuse(p.session); return
    end
    local v = Open77.vehicles.get(p.vehicle.vehicleId)
    if not v or not v.position or v.streamed == false then refuse(p.session); return end
    local s = { id = p.session, vehicle = p.vehicle.vehicleId, angle = (v.yaw or 0)+35, radius = C.radius,
        rotating = true, clock = GetGameTimer(), anchor = v.position }
    local transform = shot(s,v); transform.thirdPersonBody = true
    local camera, why = Open77.camera.create(transform)
    if not camera then refuse(p.session); return end
    s.camera, session = camera, s
    local frozen = Open77.character.setFrozen(true)
    if not frozen then refuse(p.session); return end
    s.frozen = true
    Ui.setMenuOpen(false)
    Ui.dialogs.customization = true
    Ui.setPromptFocus(true)
    CreateThread(function()
        local ok, failure = pcall(function()
            local accepted, blend = Open77.camera.activate(camera, { blendMs = C.blendMs })
            if not accepted then if session == s then refuse(p.session) end; return end
            if blend then local _, reason = blend:await(); if reason then if session == s then refuse(p.session) end; return end end
            if session ~= s then return end
            s.active = true
            Ui.send(PAGE, p)
        end)
        if not ok and session == s then Ui.log("vehicle camera failed: %s", tostring(failure)); refuse(p.session) end
    end)
end
RegisterNetEvent(NET, function(p)
    if type(p) ~= "table" then return end
    if p.kind == "open" then start(p)
    elseif session and p.session == session.id then
        if p.kind == "closed" then stop(false) else Ui.send(PAGE,p) end
    end
end)
function Custom.bind(page)
    page:on(PAGE, function(p)
        local s = session
        if not s or type(p) ~= "table" or p.session ~= s.id then return end
        if p.operation == "close" then stop(true)
        elseif p.operation == "camera" then
            if p.command == "rotate" then s.rotating = p.enabled == true
            elseif p.command == "left" then s.angle = s.angle-20
            elseif p.command == "right" then s.angle = s.angle+20
            elseif p.command == "zoomIn" then s.radius = math.max(4,s.radius-.5)
            elseif p.command == "zoomOut" then s.radius = math.min(10,s.radius+.5) end
        elseif p.operation == "preview" or p.operation == "save" then TriggerServerEvent(NET,p) end
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
                if not char or not char.attached or not char.alive or not Ui.characterReady or not v or not v.position
                    or (v.speed or 0)>.5 or next(v.occupants or {}) ~= nil or Ui.creationActive then stop(true); return end
                if math.abs(v.position.x-s.anchor.x)+math.abs(v.position.y-s.anchor.y)+math.abs(v.position.z-s.anchor.z)>2 then stop(true); return end
                if not s.active then return end
                if not registry or not registry.held or registry.activeCamera ~= s.camera then stop(true); return end
                local now = GetGameTimer(); local dt = math.min(.05,math.max(0,(now-s.clock)/1000)); s.clock = now
                if s.rotating then s.angle = (s.angle+C.degreesPerSecond*dt)%360 end
                local moved = Open77.camera.setTransform(s.camera, shot(s,v))
                if not moved then stop(true) end
            end)
            if not ok and session == s then Ui.log("vehicle orbit failed: %s", tostring(why)); stop(true) end
        end
    end
end)
