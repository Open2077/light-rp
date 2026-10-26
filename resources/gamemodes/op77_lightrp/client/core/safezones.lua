-- Staff authoring uses the existing RP page. Only the server decides protection;
-- the draft below is private drawing, never a claim that a player is protected.
local E, Ui = LightRpEvents, LightRpUi
local NET, PAGE = "op77_lightrp:safezones", "lightrp:ui:safezones"
local Editor = { active = false, mode = "closed", draft = nil }
LightRpSafezones = Editor
local snapshot = { kind = "snapshot", ready = false, zones = {}, generation = -1 }
local presence = { kind = "presence", ready = false }
local drawKey = "lightrp:safezones:draft"
local drawWarning, started = false, false
local function send(value) Ui.send(PAGE, value) end
local heldActions,controlWarnings={},{}
local function blockAction(action,blocked)
    if (heldActions[action]==true)==blocked then return end
    local api=Open77.input and Open77.input.setActionBlocked
    if type(api)~="function" then return end
    local ok,result,why
    if LightRpControlClaims then
        ok,result,why=pcall(LightRpControlClaims.set,"safezones",action,blocked)
    else ok,result,why=pcall(api,action,blocked) end
    if ok and result==true then heldActions[action]=blocked;return end
    if not controlWarnings[action] then
        controlWarnings[action]=true
        Ui.log("safezone control %s unavailable: %s",action,tostring(ok and why or result))
    end
end
local function syncControls(release)
    local character=not release and Open77.character.state()
    local zone=not release and presence.ready and presence.zone
        and character and character.alive and character.attached and presence.zone or nil
    local blockRun=zone and zone.blockRun==true or false
    for _,rule in ipairs(LightRpSafezoneGeometry.RULES) do
        local blocked=false
        if zone then
            blocked=zone[rule.key]
            if blocked==nil then blocked=rule.default end
        end
        blockAction(rule.action,blocked)
    end
    if LightRpMovement and LightRpMovement.setSafezone then LightRpMovement.setSafezone(blockRun) end
end
local sequence = 0
local outgoing, draining, lastSent = {}, false, -1000
local function forward(payload)
    if type(payload.request) ~= "string" then
        sequence = sequence + 1
        payload.request = "client:" .. tostring(GetGameTimer()) .. ":" .. tostring(sequence)
    end
    if #outgoing >= 32 then
        send({ kind = "response", request = payload.request, ok = false, error = "Too many pending requests. Your draft is kept." })
        return
    end
    outgoing[#outgoing + 1] = payload
    if draining then return end
    draining = true
    CreateThread(function()
        while #outgoing > 0 do
            local delay = 180 - (GetGameTimer() - lastSent)
            if delay > 0 then Wait(delay) end
            local nextRequest = table.remove(outgoing, 1)
            lastSent = GetGameTimer()
            TriggerServerEvent(NET, nextRequest)
        end
        draining = false
    end)
end
local function notifyServer(operation)
    forward({ operation = operation })
end

local function clearDraw()
    if Open77.debugDraw and Open77.debugDraw.clear then pcall(Open77.debugDraw.clear, drawKey) end
end
local function input(mode)
    if mode ~= "menu" and mode ~= "form" and mode ~= "typing" and mode ~= "world" then mode = "closed" end
    Editor.mode = mode
    if mode == "world" or mode == "closed" then Ui.setSupportInput("closed")
    elseif mode == "typing" then
        -- A menu row owns full keyboard input while its value is being edited.
        -- Keep the cursor hidden; this is still the existing keyboard menu.
        Ui.setSupportInput("form")
        if Ui.page then Ui.page:setConsumedKeys({}); Ui.page:setFocus(true, false) end
    else Ui.setSupportInput(mode) end
end
local function cleanup(notify)
    Editor.active, Editor.draft = false, nil
    input("closed")
    clearDraw()
    if notify then send({ kind = "invalidate", error = notify }) end
end

RegisterNetEvent(NET, function(value)
    if type(value) ~= "table" then return end
    if value.kind == "snapshot" then
        local generation = tonumber(value.generation)
        if not generation or generation < snapshot.generation then return end
        snapshot = value
        if not value.ready then presence={kind="presence",ready=false};syncControls() end
    elseif value.kind == "presence" then presence = value;syncControls()
    elseif value.kind == "open" then
        if not Ui.characterReady or Ui.creationActive or Ui.actionFocus then
            return send({ kind = "invalidate", error = "Finish your current activity before editing zones." })
        end
        Ui.setMenuOpen(false)
        if LightRpAnimations then LightRpAnimations.close() end
        Editor.active = true
        input("menu")
    elseif value.kind == "invalidate" then cleanup() end
    send(value)
end)

local function finite(n) return type(n) == "number" and n == n and math.abs(n) <= 100000 end
local function point(p) return type(p) == "table" and finite(p.x) and finite(p.y) and finite(p.z) end

-- Draw only boundary walls, without a misleading fan across concave polygons.
-- debugDraw batches expire even if resource shutdown prevents explicit cleanup.
function Editor.geometry(zone)
    if type(zone) ~= "table" or not finite(zone.minZ) or not finite(zone.maxZ) or (not zone.fullHeight and zone.minZ >= zone.maxZ) then return nil end
    local low,high=zone.minZ,zone.maxZ
    if zone.fullHeight then
        -- Infinite walls cannot be drawn. Show a local slice around the author;
        -- the published rule ignores Z, and the inspector labels that explicitly.
        local state=Open77.character.state()
        local altitude=state and state.position and state.position.z or zone.center and zone.center.z or 0
        low,high=altitude-10,altitude+20
    end
    local points = {}
    if zone.shape == "circle" and point(zone.center) and finite(zone.radius) and zone.radius > 0 and zone.radius <= 250 then
        for i = 0, 47 do
            local angle = i * math.pi / 24
            points[#points + 1] = { x = zone.center.x + math.cos(angle) * zone.radius, y = zone.center.y + math.sin(angle) * zone.radius }
        end
    elseif zone.shape == "box" and point(zone.center) and finite(zone.length) and finite(zone.width) and finite(zone.heading)
        and zone.length > 0 and zone.width > 0 and zone.length <= 500 and zone.width <= 500 then
        local angle = zone.heading * math.pi / 180
        local c, s = math.cos(angle), math.sin(angle)
        for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local x, y = corner[1] * zone.length / 2, corner[2] * zone.width / 2
            points[#points + 1] = { x = zone.center.x + c * x - s * y, y = zone.center.y + s * x + c * y }
        end
    elseif zone.shape == "poly" and type(zone.points) == "table" and #zone.points <= 32 then
        for _, p in ipairs(zone.points) do
            if not point(p) then return nil end
            points[#points + 1] = p
        end
    else return nil end
    local batch = { lines = {}, triangles = {}, ttl = 0.35, maxDistance = 1000 }
    local function line(a, b, color) batch.lines[#batch.lines + 1] = { a = a, b = b, color = color or "#ffcc00ed" } end
    for i, p in ipairs(points) do
        local a, b = { x = p.x, y = p.y, z = low }, { x = p.x, y = p.y, z = high }
        line(a, b)
        -- Small cross makes each editable vertex visible at the floor.
        line({ x = p.x - .15, y = p.y, z = low }, { x = p.x + .15, y = p.y, z = low }, "#f2f3f5ff")
        if #points > 1 and (zone.shape ~= "poly" or #points >= 3 or i < #points) then
            local q = points[i % #points + 1]
            local c, d = { x = q.x, y = q.y, z = low }, { x = q.x, y = q.y, z = high }
            line(a, c); line(b, d)
            if #points >= 3 then
                batch.triangles[#batch.triangles + 1] = { a = a, b = b, c = c, color = "#ffcc001f" }
                batch.triangles[#batch.triangles + 1] = { a = b, b = d, c = c, color = "#ffcc001f" }
            end
        end
    end
    return batch
end

function Editor.bind(page)
    page:on(E.page.ready, function()
        send(snapshot); send(presence)
        notifyServer("snapshot")
    end)
    page:on(PAGE, function(p)
        if type(p) ~= "table" or type(p.operation) ~= "string" then return end
        if p.operation == "preview" then
            if not Editor.active then return end
            Editor.draft = type(p.zone) == "table" and p.zone or nil
            if not Editor.draft then clearDraw() end
        elseif p.operation == "input" then
            if Editor.active then input(p.mode) end
        elseif p.operation == "close" then
            cleanup()
            notifyServer("cancel")
        else forward(p) end
    end)
end

function Editor.start()
    if started then return end
    started = true
    RegisterKeyMapping("lightrp.safezones.inspector", "Safezones: world / menu", "F9", function()
        if not Editor.active or Editor.mode == "typing" then return end
        local mode = Editor.mode == "world" and "menu" or "world"
        input(mode); send({ kind = "editor", mode = mode })
    end)
    RegisterKeyMapping("lightrp.safezones.capture", "Safezones: capture current position", "F10", function()
        if Editor.active and Editor.draft and Editor.mode ~= "typing" then send({ kind = "captureKey" }) end
    end)
    CreateThread(function()
        while true do
            Wait(100)
            syncControls()
            if Editor.active then
                local state = Open77.character.state()
                if not state or not state.alive or not state.attached then
                    cleanup("Zone editor closed because your character is unavailable.")
                    notifyServer("cancel")
                elseif Editor.draft then
                    local batch = Editor.geometry(Editor.draft)
                    if batch and Open77.debugDraw and Open77.debugDraw.set then
                        local ok, result = pcall(Open77.debugDraw.set, drawKey, batch)
                        if (not ok or result == false) and not drawWarning then
                            drawWarning = true
                            Ui.send(E.page.notice, { kind = "error", title = "Zone editor", body = "3D preview unavailable. Update your client and check the world.debug permission." })
                        end
                    else clearDraw() end
                end
            end
        end
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then cleanup();syncControls(true) end
end)
