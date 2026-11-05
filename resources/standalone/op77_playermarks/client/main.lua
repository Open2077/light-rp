-- The nameplates on this client: one Open77.anchors anchor per other player around
-- (an entity anchor follows the body; the plugin projects it every frame and
-- pushes the screen position to the page, which only draws), and the talkers'
-- voice levels for the radio waves.
local C = PlayerMarksConfig

local page, pageReady = nil, false
local marks = {}          -- player id (string) -> { anchor, entity, name, talking, level }
local anchorsOk = type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
local warned = {}

local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print("[playermarks] " .. text)
end

local function send(name, payload)
    if page and pageReady then page:send(name, payload) end
end

-- exports[name]:method(...) without throwing, only when that resource runs.
local function call(name, method, ...)
    if type(GetResourceState) == "function" and GetResourceState(name) ~= "running" then return nil end
    local args = table.pack(...)
    local ok, value = pcall(function()
        local target = exports[name]
        return target[method](target, table.unpack(args, 1, args.n))
    end)
    if ok then return value end
    return nil
end

-- What other resources hid (setHidden): owner -> true (every plate) or { [player id] = true }.
local hiddenBy = {}

-- A player op77_map3d keeps off the map (a chase runner) gets no plate either, nor one a
-- resource hid (op77_lightrp: the players in a PvP fight).
local function hidden(pid)
    local key = tostring(pid)
    for _, set in pairs(hiddenBy) do
        if set == true or set[key] then return true end
    end
    return call("op77_map3d", "arePlayerDotsHidden", pid) == true
end

local function drop(key)
    local m = marks[key]
    if not m then return end
    if m.anchor then pcall(Open77.anchors.remove, m.anchor) end
    marks[key] = nil
    send("pm:remove", { player = key })
end

-- The name a plate shows: the player's name as the platform lists it, trimmed.
local function nameOf(p)
    local name = type(p.name) == "string" and p.name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then name = "#" .. tostring(p.playerId or p.id or "?") end
    if #name > C.nameMax then name = name:sub(1, C.nameMax) end
    return name
end

-- The other players around with a streamed body: player id (string) -> { entity, name }.
local function around()
    local out, count = {}, 0
    local ok, list = pcall(Open77.players.nearby, C.radius, { includeSelf = false, limit = C.max })
    if not ok or type(list) ~= "table" then return out end
    for _, p in ipairs(list) do
        local pid = p.playerId or p.id
        if pid ~= nil and not p.isLocal and count < C.max and not hidden(pid) then
            local okEntity, entity = pcall(Open77.players.entity, pid)
            if okEntity and entity and tostring(entity) ~= "0" then
                out[tostring(pid)] = { entity = tostring(entity), name = nameOf(p) }
                count = count + 1
            end
        end
    end
    return out
end

-- Creates, retargets and removes anchors to match the players around.
local function refresh()
    if not anchorsOk or not page or not pageReady then return end
    local now = around()
    for key in pairs(marks) do
        if not now[key] then drop(key) end
    end
    for key, seen in pairs(now) do
        local entity, name = seen.entity, seen.name
        local m = marks[key]
        if m and m.entity ~= entity then
            local ok, res = pcall(Open77.anchors.update, m.anchor, { entity = entity })
            if ok and res ~= false then m.entity = entity else drop(key); m = nil end
        end
        if not m then
            local id, why = Open77.anchors.create({ page = page, entity = entity, offset = { x = 0, y = 0, z = C.height },
                tag = "playermark." .. key, maxDistance = C.radius, minDistance = 0.0 })
            if id then
                m = { anchor = id, entity = entity, name = name, talking = false, level = 0 }
                marks[key] = m
                send("pm:add", { player = key, anchor = tostring(id), name = name })
            else
                if why == "anchors_backend_unavailable" then anchorsOk = false end
                warn("anchor:" .. tostring(why), "anchor refused: " .. tostring(why))
            end
        elseif m.name ~= name then
            m.name = name
            send("pm:name", { player = key, name = name })
        end
    end
end

-- The talkers' state on the dots; only changes go to the page.
local function talk()
    if not pageReady or next(marks) == nil then return end
    local ok, talkers = pcall(Open77.voice.talkers)
    if not ok or type(talkers) ~= "table" then talkers = {} end
    local now = {}
    for _, t in ipairs(talkers) do
        local level = math.max(0, math.min(1, tonumber(t.level) or 0))
        if t.playerId ~= nil and t.talking == true then now[tostring(t.playerId)] = math.max(level, C.talkThreshold) end
    end
    for key, m in pairs(marks) do
        local level = now[key] or 0
        local talking = level > 0
        level = math.floor(level * 20 + 0.5) / 20
        if talking ~= m.talking or math.abs(level - m.level) >= 0.05 then
            m.talking, m.level = talking, level
            send("pm:talk", { player = key, talking = talking, level = level })
        end
    end
end

-- setHidden(true[, ids]): hide every plate (no ids) or those players' (a list of server ids);
-- setHidden(false): show again what this caller hid. Each caller's choice replaces its
-- previous one and goes when it stops; the next refresh (refreshMs) applies it.
local function setHidden(owner, on, ids)
    if on ~= true then hiddenBy[owner] = nil; return true end
    if ids == nil then hiddenBy[owner] = true; return true end
    if type(ids) ~= "table" then return false end
    local set = {}
    for _, id in ipairs(ids) do set[tostring(id)] = true end
    hiddenBy[owner] = set
    return true
end
exports("setHidden", function(on, ids)
    local owner = (type(GetInvokingResource) == "function" and GetInvokingResource()) or "export"
    return setHidden(owner, on, ids)
end)
exports("arePlatesHidden", function(pid) return hidden(pid) end)

-- For the offline tests: the loop bodies and the state, no game needed.
PlayerMarks = { refresh = refresh, talk = talk, marks = marks, setHidden = setHidden,
    attach = function(p) page, pageReady = p, true end }

local function createPage()
    local created, why
    for _ = 1, 2400 do -- up to 10 min: a slow first load keeps the resource preparing for minutes (2026-11-05)
        created, why = WebUI.create({
            entry = "web/index.html", layer = "hud", width = 1920, height = 1080,
            fps = 60, zIndex = 600, transparent = true, visible = true,
        })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then print("[playermarks] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("pm:ready", function()
        pageReady = true
        send("pm:config", { radius = C.radius, page = C.page })
        for key, m in pairs(marks) do
            send("pm:add", { player = key, anchor = tostring(m.anchor), name = m.name })
            send("pm:talk", { player = key, talking = m.talking, level = m.level })
        end
    end)
    if not anchorsOk then warn("anchors", "Open77.anchors unavailable on this client: no dots") end
end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() or C.enabled == false then return end
    CreateThread(createPage)
    CreateThread(function()
        while true do
            local ok, err = pcall(refresh)
            if not ok then warn("refresh", "refresh failed: " .. tostring(err)) end
            Wait(C.refreshMs)
        end
    end)
    CreateThread(function()
        while true do
            local ok, err = pcall(talk)
            if not ok then warn("talk", "talkers failed: " .. tostring(err)) end
            Wait(C.talkMs)
        end
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then
        if anchorsOk then pcall(Open77.anchors.clear) end
        return
    end
    hiddenBy[name] = nil
end)
