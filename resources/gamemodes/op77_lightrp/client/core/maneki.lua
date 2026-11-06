-- The Maneki-neko collection, client side (server/modules/maneki.lua, docs/maneki.md).
--
-- The server streams the cats this character has not found yet, within ~140 m. Each one
-- is a LOCAL prop (nobody else sees it, it never leaves this machine) with a private E
-- prompt; no blip, no marker. A cat is taken with E, or shot: while the trigger is held
-- with a weapon in hand, the camera's ray is tested against every cat nearby (a sphere
-- around the figure) and a static ray says nothing stands in between. The server
-- re-checks the distance, the weapon and that it streamed that cat to us.
local E = LightRpEvents
local Ui = LightRpUi
-- count: the cats held, drawn or not: the tables leave them room in the shared prop quota.
local Maneki = { cats = {}, model = nil, height = 0.16, editing = false, count = 0 }
LightRpManeki = Maneki

local PROMPT_RADIUS = 1.8
local SHOT_RANGE = 85          -- a little under the server's shotRange
local SHOT_REPEAT_MS = 120     -- automatic fire: one test per 120 ms while the trigger is held
local HIT_PAD = 0.07           -- metres added to the cat's radius (aim assist for a 16 cm target)
local BUILD_SLICE = 4          -- props created per resume (script budget)

local function log(...) Ui.log(...) end
local function interactId(id) return "maneki." .. id end

-- ---------------------------------------------------------------------------
-- Props

local function center(c)
    local h = (Maneki.height or 0.16) * (c.s or 1)
    return { x = c.x, y = c.y, z = c.z + h * 0.5 }, math.max(0.08, h * 0.62)
end

local function spawn(c)
    if c.handle or not Maneki.model then return end
    if not Open77.props or type(Open77.props.create) ~= "function" then return end
    local handle, why = Open77.props.create({ model = Maneki.model, kind = "prop", position = { x = c.x, y = c.y, z = c.z },
        yaw = c.yaw or 0, scale = c.s or 1, physics = "none", collision = false, visible = true })
    if not handle then
        if not Maneki.reported then Maneki.reported = true; log("maneki: prop refused (%s)", tostring(why)) end
        return
    end
    c.handle = handle
end

local function despawn(c)
    if c.handle then pcall(Open77.props.remove, c.handle); c.handle = nil end
    if LightRpInteract and not c.editorOnly then LightRpInteract.setLocal(interactId(c.id), nil) end
end

local function prompt(c)
    if not LightRpInteract or Maneki.editing then return end
    LightRpInteract.setLocal(interactId(c.id), { position = { x = c.x, y = c.y, z = c.z }, radius = PROMPT_RADIUS, prompt = "Take the Maneki-neko" },
        function() TriggerServerEvent(E.net.manekiCollect, { id = c.id, how = "take" }) end)
end

-- A new list from the server: keep what is unchanged, drop what left, build what came,
-- a few per resume.
local generation = 0
function Maneki.apply(list, editing)
    generation = generation + 1
    local mine = generation
    local wanted = {}
    for _, row in ipairs(type(list) == "table" and list or {}) do
        if type(row) == "table" and type(row.id) == "string" and tonumber(row.x) and tonumber(row.y) and tonumber(row.z) then wanted[row.id] = row end
    end
    local editingChanged = (Maneki.editing == true) ~= (editing == true)
    Maneki.editing = editing == true
    for id, c in pairs(Maneki.cats) do
        local w = wanted[id]
        if not w or editingChanged or w.x ~= c.x or w.y ~= c.y or w.z ~= c.z or w.yaw ~= c.yaw or w.s ~= c.s then
            despawn(c); Maneki.cats[id] = nil
        else
            c.f = w.f
        end
    end
    local queue = {}
    for id, w in pairs(wanted) do
        if not Maneki.cats[id] then
            local c = { id = id, x = tonumber(w.x), y = tonumber(w.y), z = tonumber(w.z), yaw = tonumber(w.yaw) or 0, s = tonumber(w.s) or 1, f = w.f }
            Maneki.cats[id] = c
            queue[#queue + 1] = c
        elseif not Maneki.cats[id].handle then
            queue[#queue + 1] = Maneki.cats[id] -- refused earlier: the tables have made room since
        end
    end
    local count = 0
    for _ in pairs(Maneki.cats) do count = count + 1 end
    Maneki.count = count
    CreateThread(function()
        for i, c in ipairs(queue) do
            if mine ~= generation then return end
            if Maneki.cats[c.id] == c then spawn(c); if not Maneki.editing then prompt(c) end end
            if i % BUILD_SLICE == 0 then Wait(0) end
        end
        if LightRpManekiEditor then LightRpManekiEditor.refresh() end
    end)
end

function Maneki.clear()
    generation = generation + 1
    for id, c in pairs(Maneki.cats) do despawn(c); Maneki.cats[id] = nil end
    Maneki.count = 0
end

-- ---------------------------------------------------------------------------
-- Shots

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function length(a) return math.sqrt(dot(a, a)) end

-- The nearest cat the camera ray passes through, with nothing static in front of it.
function Maneki.aimed(maxDistance, includeFound)
    if not Open77.camera or type(Open77.camera.view) ~= "function" then return nil end
    local ok, view = pcall(Open77.camera.view)
    if not ok or type(view) ~= "table" or type(view.position) ~= "table" or type(view.forward) ~= "table" then return nil end
    local o, d = view.position, view.forward
    local n = length(d)
    if n < 1e-6 then return nil end
    d = { x = d.x / n, y = d.y / n, z = d.z / n }
    local best, bestT
    for _, c in pairs(Maneki.cats) do
        if includeFound or not c.f then
            local p, r = center(c)
            local rel = sub(p, o)
            local t = dot(rel, d)
            if t > 0 and t <= (maxDistance or SHOT_RANGE) + 2 then
                local miss = length({ x = rel.x - d.x * t, y = rel.y - d.y * t, z = rel.z - d.z * t })
                if miss <= r + HIT_PAD * math.max(1, t / 25) and (not bestT or t < bestT) then best, bestT = c, t end
            end
        end
    end
    if not best then return nil end
    -- Line of sight: the first static surface along the ray must not be in front of the cat.
    if type(Open77.camera.aimRay) == "function" then
        local okRay, ray = pcall(Open77.camera.aimRay, bestT + 1, { dynamic = false })
        if okRay and type(ray) == "table" and ray.hit and tonumber(ray.distance) and ray.distance < bestT - 0.3 * (best.s or 1) - 0.15 then
            return nil
        end
    end
    return best, bestT
end

local function firing()
    local C = Open77.character
    if C and type(C.aimState) == "function" then
        local ok, s = pcall(C.aimState)
        if ok and type(s) == "table" then return s.firing == true and s.weaponDrawn ~= false end
    end
    if Open77.input and type(Open77.input.isDown) == "function" then
        if Open77.input.isCaptured and Open77.input.isCaptured() == true then return false end
        -- Older clients: the left button (the server refuses a shot with no weapon in hand).
        local ok, down = pcall(Open77.input.isDown, "MOUSE1")
        return ok and down == true
    end
    return false
end

local function anyNear(range)
    local ok, state = pcall(Open77.character.state)
    local p = ok and type(state) == "table" and state.position
    if not p then return false end
    for _, c in pairs(Maneki.cats) do
        if not c.f then
            local dx, dy, dz = c.x - p.x, c.y - p.y, c.z - p.z
            if dx * dx + dy * dy + dz * dz <= range * range then return true end
        end
    end
    return false
end

CreateThread(function()
    local wasFiring, lastTest, pending = false, 0, {}
    while true do
        if next(Maneki.cats) == nil or Maneki.editing or not anyNear(SHOT_RANGE) then
            wasFiring = false
            Wait(500)
        else
            local now = GetGameTimer()
            local fire = firing()
            if fire and (not wasFiring or now - lastTest >= SHOT_REPEAT_MS) then
                lastTest = now
                local c = Maneki.aimed(SHOT_RANGE)
                if c and not pending[c.id] then
                    pending[c.id] = now
                    TriggerServerEvent(E.net.manekiCollect, { id = c.id, how = "shot" })
                end
            end
            wasFiring = fire
            for id, at in pairs(pending) do if now - at > 2500 then pending[id] = nil end end
            Wait(fire and 0 or 40)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Effects of a find: the figure is gone at once, a small burst where it stood.

-- Curated client VFX aliases (Open77.vfx.catalog) and the game's own UI jingles.
local function burst(c, shot)
    if type(Open77.vfx) == "table" and type(Open77.vfx.play) == "function" then
        local ok, handle, why = pcall(Open77.vfx.play, shot and "sparks.burst.small" or "neon.loot_drop",
            { position = { x = c.x, y = c.y, z = c.z + (Maneki.height or .16) * (c.s or 1) * .5 }, duration = shot and 2 or 1.5 })
        if (not ok or not handle) and not Maneki.vfxReported then Maneki.vfxReported = true; log("maneki: vfx refused (%s)", tostring(ok and why or handle)) end
    end
end
local function jingle(event)
    if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, event) end
end

-- ---------------------------------------------------------------------------
-- F1 > Maneki-neko: the collection panel (ui/src/features/maneki/ManekiCollection.tsx)
-- and "Show on the city map": op77_map3d opens on the spot, every found cat pinned;
-- closing the map brings the collection back.

local function split(raw)
    local out, from = {}, 1
    while true do
        local at = raw:find("|", from, true)
        if not at then out[#out + 1] = raw:sub(from); return out end
        out[#out + 1] = raw:sub(from, at - 1)
        from = at + 1
    end
end
function Maneki.parseCollection(payload)
    local list, width = {}, math.max(2, #tostring(#(payload.slots or {})))
    for i, raw in ipairs(type(payload.slots) == "table" and payload.slots or {}) do
        if type(raw) == "string" and raw ~= "" then
            local f = split(raw)
            local x, y, z = tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
            if f[1] ~= "" and x and y and z then
                list[#list + 1] = { id = f[1], district = f[2] ~= "" and f[2] or nil, at = tonumber(f[3]), how = f[4], x = x, y = y, z = z,
                    number = ("%0" .. width .. "d"):format(i) }
            end
        end
    end
    return list
end

local mapBlips, backToCollection = {}, false
local function mapCall(method, ...)
    if type(GetResourceState) ~= "function" or GetResourceState("op77_map3d") ~= "running" then return false, "not running" end
    return pcall(function(...) return exports.op77_map3d[method](exports.op77_map3d, ...) end, ...)
end
local function clearMapBlips()
    for _, id in ipairs(mapBlips) do mapCall("removeBlip", id) end
    mapBlips = {}
end
local function dateOf(ms)
    if not ms or type(os) ~= "table" or type(os.date) ~= "function" then return nil end
    local ok, text = pcall(os.date, "%d %b %Y %H:%M", math.floor(ms / 1000))
    return ok and text or nil
end

function Maneki.showOnMap(id)
    local c = Maneki.collection
    if not c then return false, "Open your collection again." end
    local target
    for _, f in ipairs(c.found) do if f.id == id then target = f end end
    if not target then return false, "That cat is not in your collection." end
    if type(GetResourceState) ~= "function" or GetResourceState("op77_map3d") ~= "running" then return false, "The city map is not available on this server." end
    clearMapBlips()
    for _, f in ipairs(c.found) do
        local selected = f.id == id
        local when = dateOf(f.at)
        local ok, blip = mapCall("addBlip", { id = "maneki." .. f.id, position = { x = f.x, y = f.y, z = f.z },
            icon = LightRpMapIcons and LightRpMapIcons.maneki or nil, color = selected and "#FFCC00" or "#B8962E",
            label = "Maneki-neko #" .. f.number, category = "maneki", pulse = selected, priority = selected and 2 or 1,
            scale = selected and 1.25 or 0.9, minimap = false,
            description = table.concat({ f.district or "Night City", f.how == "shot" and "shot down" or "taken", when and ("found " .. when) or nil }, " · ") })
        if ok and blip then mapBlips[#mapBlips + 1] = blip end
    end
    c.payload.intro = nil
    Ui.send(E.page.dialogClose, { kind = "maneki" })
    local position = { x = target.x, y = target.y, z = target.z }
    local opened = mapCall("open", position)
    if not opened then clearMapBlips(); return false, "The city map could not open." end
    mapCall("focus", position, 260)
    backToCollection = true
    return true
end

AddEventHandler("op77_map3d:closed", function()
    if #mapBlips == 0 and not backToCollection then return end
    clearMapBlips()
    if backToCollection and Maneki.collection then
        backToCollection = false
        Ui.send(E.page.dialog, Maneki.collection.payload)
    end
end)

RegisterNetEvent(E.net.maneki, function(p)
    if type(p) ~= "table" then return end
    if p.kind == "collection" and type(p.collection) == "table" then
        Maneki.collection = { payload = p.collection, found = Maneki.parseCollection(p.collection) }
        if Ui.supportMode and Ui.setSupportInput then Ui.setSupportInput("closed") end
        Ui.send(E.page.dialog, p.collection)
    elseif p.kind == "near" then
        if type(p.model) == "string" and p.model ~= "" then Maneki.model = p.model end
        Maneki.height = tonumber(p.height) or Maneki.height
        Maneki.apply(p.spots, p.editing == true)
    elseif p.kind == "found" and type(p.id) == "string" then
        local c = Maneki.cats[p.id]
        if c then
            burst(c, p.how == "shot")
            despawn(c); Maneki.cats[p.id] = nil
        end
        jingle(p.complete and "ui_jingle_achiev" or "ui_jingle_money")
    elseif (p.kind == "editor" or p.kind == "staff") and LightRpManekiEditor then
        LightRpManekiEditor.onServer(p)
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then Maneki.clear() end
end)
