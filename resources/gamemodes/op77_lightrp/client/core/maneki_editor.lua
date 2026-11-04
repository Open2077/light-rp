-- The staff placement tool for the Maneki-neko (server/modules/maneki.lua, docs/maneki.md).
--
-- Opened from the staff desk (/lightrp.admin > Maneki-neko > Placement tool) or
-- /lightrp.maneki tool; the server decides who may. While it runs, the server streams
-- every cat around, found ones included, and this shows:
--   * a ghost cat on the surface under the crosshair, facing the camera (+ a turn);
--   * a marker over every placed cat, and the one under the crosshair is "aimed".
-- Keys (polled, the attack actions are claimed so a click never fires a weapon):
--   LEFT CLICK place · DELETE remove the aimed cat · LEFT / RIGHT turn · UP / DOWN size
--   BACKSPACE leave. The page shows the bar (ui/src/features/maneki/ManekiTool.tsx).
local E = LightRpEvents
local Ui = LightRpUi
local Editor = { active = false, yawOffset = 0, scaleIndex = 1, scales = { 1, 1.5, 2, 3 } }
LightRpManekiEditor = Editor

local AIM_DISTANCE = 35
local AIM_GROUPS = { "Static", "Terrain" }
local BLOCKED = { "Attack", "Melee", "Grenade" }
local KEYS = { place = "MOUSE1", remove = "DELETE", left = "LEFT", right = "RIGHT", up = "UP", down = "DOWN", leave = "BACKSPACE" }
local ghost, markers, claimed = nil, {}, false
local message, messageAt, messageOk = nil, 0, true

local function log(...) Ui.log(...) end
local function claim(on)
    if claimed == on then return end
    claimed = on
    for _, action in ipairs(BLOCKED) do
        if LightRpControlClaims then pcall(LightRpControlClaims.set, "maneki", action, on)
        elseif Open77.input and Open77.input.setActionBlocked then pcall(Open77.input.setActionBlocked, action, on) end
    end
end

local function removeGhost() if ghost then pcall(Open77.props.remove, ghost); ghost = nil end end
local function clearMarkers()
    for id, handle in pairs(markers) do pcall(Open77.markers.remove, handle); markers[id] = nil end
end

-- One native marker over each placed cat (green: one this character found, gold: not yet).
function Editor.refresh()
    if not Editor.active then return end
    if type(Open77.markers) ~= "table" or type(Open77.markers.create) ~= "function" then return end
    local cats = LightRpManeki and LightRpManeki.cats or {}
    for id, handle in pairs(markers) do
        if not cats[id] then pcall(Open77.markers.remove, handle); markers[id] = nil end
    end
    CreateThread(function()
        local n = 0
        for id, c in pairs(cats) do
            if Editor.active and not markers[id] then
                local h = (LightRpManeki.height or .16) * (c.s or 1)
                local handle = Open77.markers.create({ position = { x = c.x, y = c.y, z = c.z + h + 0.25 }, shape = "arrow",
                    radius = 0.12, height = 0.25, color = c.f and "#3DDC84" or "#FFCC00", style = "objective",
                    minDistance = 0, maxDistance = 120, visible = true })
                if handle then markers[id] = handle end
                n = n + 1
                if n % 6 == 0 then Wait(0) end
            end
        end
    end)
end

local function aimPoint()
    if not Open77.camera or type(Open77.camera.aimRay) ~= "function" then return nil end
    local ok, ray = pcall(Open77.camera.aimRay, AIM_DISTANCE, { groups = AIM_GROUPS })
    if not ok or ray == nil then ok, ray = pcall(Open77.camera.aimRay, AIM_DISTANCE, { dynamic = false }) end
    if not ok or type(ray) ~= "table" or not ray.hit then return nil end
    return ray.position, ray.normal
end

-- Facing the camera: the game's cat looks along its own -Y (server landing() agrees).
local function faceYaw(at)
    local ok, view = pcall(Open77.camera.view)
    if not ok or type(view) ~= "table" or type(view.position) ~= "table" then return 0 end
    local dx, dy = view.position.x - at.x, view.position.y - at.y
    local heading = math.deg(math.atan(-dx, dy)) -- yaw whose +Y points at the camera
    return (heading + 180) % 360
end

-- The page gets the bar only when something on it changed (this runs every frame).
local lastSent
local function publish(state)
    local sig = state.active and table.concat({ tostring(state.scale), tostring(state.yaw), tostring(state.aim), tostring(state.hovered),
        tostring(state.hoveredFound), tostring(state.nearby), tostring(state.message), tostring(state.ok) }, "|") or "off"
    if sig == lastSent then return end
    lastSent = sig
    Ui.send(E.page.maneki, state)
end

local function say(text, ok)
    message, messageAt, messageOk = text, GetGameTimer(), ok ~= false
end

local function stop(notifyServer)
    if not Editor.active then return end
    Editor.active = false
    removeGhost(); clearMarkers(); claim(false)
    publish({ active = false })
    if notifyServer then TriggerServerEvent(E.net.manekiEdit, { op = "close" }) end
end

local function loop()
    local down, held = {}, {}
    local lastAim, aim, normal, hovered = 0, nil, nil, nil
    local placingUntil = 0
    while Editor.active do
        local now = GetGameTimer()
        local typing = Open77.input.isCaptured and Open77.input.isCaptured() == true
        local menu = Open77.session and type(Open77.session.isMenuOpen) == "function" and Open77.session.isMenuOpen() == true
        local pressed = {}
        for name, key in pairs(KEYS) do
            local isDown = not typing and not menu and Open77.input.isDown(key) == true
            if isDown and not down[name] then pressed[name] = true; held[name] = now end
            if isDown and held[name] and now - held[name] > 350 and (name == "left" or name == "right") then pressed[name] = true; held[name] = now - 270 end
            down[name] = isDown
        end
        if pressed.leave then stop(true); break end
        if pressed.left then Editor.yawOffset = (Editor.yawOffset + 15) % 360 end
        if pressed.right then Editor.yawOffset = (Editor.yawOffset - 15) % 360 end
        if pressed.up then Editor.scaleIndex = math.min(#Editor.scales, Editor.scaleIndex + 1) end
        if pressed.down then Editor.scaleIndex = math.max(1, Editor.scaleIndex - 1) end
        if now - lastAim >= 50 then
            lastAim = now
            aim, normal = aimPoint()
            hovered = LightRpManeki and LightRpManeki.aimed(AIM_DISTANCE, true) or nil
        end
        local scale = Editor.scales[Editor.scaleIndex] or 1
        local yaw = aim and (faceYaw(aim) + Editor.yawOffset) % 360 or 0
        local steep = normal and tonumber(normal.z) and normal.z < 0.6
        if aim and not hovered then
            if not ghost and LightRpManeki and LightRpManeki.model then
                ghost = Open77.props.create({ model = LightRpManeki.model, kind = "prop", position = aim, yaw = yaw, scale = scale,
                    physics = "none", collision = false, visible = true })
            elseif ghost then
                pcall(Open77.props.setTransform, ghost, { position = aim, yaw = yaw, scale = { x = scale, y = scale, z = scale } })
            end
        else
            removeGhost()
        end
        if pressed.place and now >= placingUntil then
            if hovered then say("A cat is already there: DELETE removes it.", false)
            elseif not aim then say("Aim at a surface within " .. AIM_DISTANCE .. " m.", false)
            elseif steep then say("Too steep: aim at a floor, a shelf or a ledge.", false)
            else
                placingUntil = now + 600
                local district
                if Open77.world and type(Open77.world.district) == "function" then
                    local ok, d = pcall(Open77.world.district, aim)
                    if ok and type(d) == "table" then district = d.subDistrict or d.district end
                end
                TriggerServerEvent(E.net.manekiEdit, { op = "place", x = aim.x, y = aim.y, z = aim.z, yaw = yaw, scale = scale, district = district })
                say("Placing…", true)
            end
        end
        if pressed.remove then
            if hovered then TriggerServerEvent(E.net.manekiEdit, { op = "delete", id = hovered.id }); say("Removing " .. hovered.id .. "…", true)
            else say("Aim at a placed cat to remove it.", false) end
        end
        local count = 0
        if LightRpManeki then for _ in pairs(LightRpManeki.cats) do count = count + 1 end end
        publish({ active = true, scale = scale, yaw = math.floor(Editor.yawOffset), aim = aim ~= nil and not steep, hovered = hovered and hovered.id or nil,
            hoveredFound = hovered and hovered.f == true or nil, nearby = count,
            message = message and now - messageAt < 4000 and message or nil, ok = messageOk })
        Wait(0)
    end
end

function Editor.onServer(p)
    if p.kind == "editor" then
        if p.active then
            if type(p.scales) == "table" and #p.scales > 0 then Editor.scales = p.scales end
            Editor.scaleIndex = math.min(Editor.scaleIndex, #Editor.scales)
            if Editor.active then return end
            Editor.active = true
            claim(true)
            Ui.setMenuOpen(false)
            say("Aim at a surface and LEFT CLICK to hide a cat there.", true)
            log("maneki: placement tool on")
            Editor.refresh()
            CreateThread(function()
                local ok, err = pcall(loop)
                if not ok then log("maneki tool failed: %s", tostring(err)); stop(true) end
            end)
        else
            stop(false)
            log("maneki: placement tool off")
        end
    elseif p.kind == "staff" then
        say(tostring(p.text or ""), p.ok == true)
        if p.ok and p.op == "place" then
            if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, "ui_menu_item_weapon_equip") end
        end
    end
end

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then stop(false) end
end)
