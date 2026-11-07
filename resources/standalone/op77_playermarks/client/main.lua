-- The nameplates on this client. One of two drawers, picked at start:
--
--   native  a client whose plugin draws the plates itself (Open77.nameplates.style exists):
--           the Light RP look is handed over once as a theme, and from then on this script
--           only says, per player, what the plate reads and whether it shows
--           (Open77.nameplates.set). The plugin projects, occludes (no plate through a wall),
--           smooths and fades every plate in the frame that presents it, and reads the voice
--           levels itself. No page, no anchors, no per-frame Lua.
--   page    an older client: one Open77.anchors anchor per other player around (an entity
--           anchor follows the body; the plugin projects it every frame and pushes the
--           screen position to the page, which only draws), and the talkers' voice levels
--           for the voice bars. It trails the camera on a fast turn (418 px measured) and
--           shows through walls; it stays exactly as it was for the clients without the
--           native drawer.
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
-- The names other resources gave (setNames): owner -> { [player id] = name }. A roleplay
-- gamemode shows the character's name instead of the account's (op77_lightrp).
local namesBy = {}

-- Hidden by a caller of setHidden (every plate, or this player's).
local function hiddenByCallers(pid)
    local key = tostring(pid)
    for _, set in pairs(hiddenBy) do
        if set == true or set[key] then return true end
    end
    return false
end

-- Some caller hid every plate (setHidden(true) without ids: Prop Hunt).
local function allHidden()
    for _, set in pairs(hiddenBy) do
        if set == true then return true end
    end
    return false
end

-- A player op77_map3d keeps off the map (a chase runner) gets no plate either, nor one a
-- resource hid (op77_lightrp: the players in a PvP fight).
local function hidden(pid)
    return hiddenByCallers(pid) or call("op77_map3d", "arePlayerDotsHidden", pid) == true
end

local function drop(key)
    local m = marks[key]
    if not m then return end
    if m.anchor then pcall(Open77.anchors.remove, m.anchor) end
    marks[key] = nil
    send("pm:remove", { player = key })
end

-- The name a caller gave this player (setNames), if any.
local function callerName(id)
    for _, names in pairs(namesBy) do
        if type(names[id]) == "string" then return names[id] end
    end
    return nil
end

-- The name a plate shows: the player's name as the platform lists it, trimmed, with the
-- session id in front ("[12] Archer Hella", config showId). A player without a name shows
-- the id alone.
local function nameOf(p)
    local id = tostring(p.playerId or p.id or "?")
    local name = callerName(id) or p.name
    name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if #name > C.nameMax then name = name:sub(1, C.nameMax) end
    if C.showId == false then return name ~= "" and name or ("#" .. id) end
    if name == "" then return "[" .. id .. "]" end
    return "[" .. id .. "] " .. name
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

-- ---------------------------------------------------------------------------------------
-- The native drawer.
-- ---------------------------------------------------------------------------------------

-- The page's look (web/app.css) as the native drawer's theme. Colours are the CSS values,
-- an rgba() alpha written as its two hex digits, round(alpha * 255).
local function theme()
    local scale = C.page or {}
    return {
        font = "chakra",              -- .pm__name: "Chakra Petch" 600 (the plugin's ui face is Chakra Petch SemiBold)
        size = 13,                    -- .pm__name: 13px
        letterSpacing = 0.08,         -- .pm__name: letter-spacing 0.08em
        uppercase = true,             -- .pm__name: text-transform uppercase
        textColor = "#F2F3F5",        -- --text-hi
        textShadow = "#000000CC",     -- .pm__name: text-shadow 0 1px 2px rgba(0, 0, 0, 0.8)
        shape = "chamfer",            -- .pm__chip: clip-path cuts the top-left and bottom-right corners
        corner = 6,                   -- .pm__chip: 6px cuts
        paddingX = 9.5,               -- .pm__chip: padding 4px 10px 4px 9px (one value for both sides: same width)
        paddingY = 4,
        background = "#060608BD",     -- --surface-hud rgba(6, 6, 8, 0.74)
        backgroundTalking = "#241B00D1", -- .pm.is-talking .pm__chip: rgba(36, 27, 0, 0.82)
        border = "#FFCC0024",         -- .pm__chip: inset 1px --accent-quiet rgba(255, 204, 0, 0.14)
        borderTalking = "#FFCC0073",  -- .pm.is-talking .pm__chip: inset 1px rgba(255, 204, 0, 0.45)
        borderWidth = 1,
        accent = "#FFCC00",           -- --accent (--o77-yellow-400)
        accentSide = "left",          -- .pm__chip::before: left 0, top 6px (under the cut), bottom 0
        accentWidth = 2,              -- .pm__chip::before: width 2px
        voice = "bars",               -- .pm__voice: three bars, lit with --accent while talking
        voiceIdle = "#565A66",        -- --idle (--o77-ink-300)
        voiceIdleVisible = true,      -- the three ink stubs show while silent too
        pin = 9,                      -- .pm__pin: 9px hairline (accent fading to 25 %, as the drawer draws it)
        pinWidth = 1,                 -- .pm__pin: 1px
        tip = "diamond",              -- .pm__tip: a square turned 45 degrees
        tipSize = 7,                  -- .pm__tip: 5px square, 7px corner to corner (the drawer's size is the diagonal)
        tipGlow = true,               -- .pm__tip: box-shadow 0 0 6px rgba(255, 204, 0, 0.55)
        tipPulse = true,              -- .pm.is-talking .pm__tip: pm-tip pulse
        nearScale = scale.nearScale or 1.0, -- config page.nearScale
        farScale = scale.farScale or 0.6,   -- config page.farScale
        fadeFrom = scale.fadeFrom or 0.75,  -- config page.fadeFrom
        fade = 160,                   -- .pm: transition opacity 160ms
        maxDistance = C.radius,       -- config radius (the anchors' maxDistance)
        occlusion = true,             -- new: no plate through a wall (the page had none)
        offset = C.height - 1.92,     -- config height over the drawer's own head anchor (root + 1.92 standing)
        showDistance = false,         -- the page showed no distance
    }
end

-- Every player of the session that has a body here is within this many metres: the plates
-- themselves stop at `radius` (the theme's maxDistance), but a player's label and hidden
-- state are set as soon as their body streams in, before they are close enough to show.
local ROSTER_RADIUS = 10000.0

local Native = {
    on = false,
    rendering = nil, -- what render() was last told (nil: tell it again)
    applied = {},    -- player id (string) -> signature of the override this resource holds
    names = {},      -- player id (string) -> the account name, as last seen with a body here
    mapHidden = {},  -- player id (string) -> op77_map3d hid that player, as last seen with a body here
}

local function nativeAvailable()
    local np = type(Open77) == "table" and Open77.nameplates or nil
    return type(np) == "table" and np.style ~= nil and type(np.render) == "function"
        and type(np.set) == "function" and type(np.remove) == "function"
end

-- style() is all or nothing: a key this client's drawer does not know (or a value it
-- refuses) costs only that key, said once in the log, and the rest of the theme stays.
local function applyStyle()
    local t = theme()
    for _ = 1, 16 do
        local ok, done, why = pcall(Open77.nameplates.style, t)
        if ok and done then return true end
        local reason = tostring(ok and why or done)
        local key = reason:match("^unknown_style_key:(.+)$") or reason:match("^invalid_style_value:(.+)$")
        if key == nil or t[key] == nil then
            warn("style", "theme refused: " .. reason)
            return false
        end
        warn("style:" .. key, "theme key dropped (" .. reason .. ")")
        t[key] = nil
    end
    return false
end

local function nativeRender(on)
    if Native.rendering == on then return end
    local ok, done, why = pcall(Open77.nameplates.render, on)
    -- render(false) answers not_found when a world exit already dropped the request: off too.
    if ok and (done or not on) then
        Native.rendering = on
    else
        warn("render:" .. tostring(on), "render(" .. tostring(on) .. ") refused: " .. tostring(ok and why or done))
    end
end

-- A name cut at nameMax bytes can end inside a UTF-8 sequence: drop the broken tail.
local function trimUtf8(text)
    local n = #text
    for i = n, math.max(1, n - 3), -1 do
        local b = text:byte(i)
        if b < 0x80 then return text end
        if b >= 0xC0 then
            local need = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or 2
            if n - i + 1 >= need then return text end
            return text:sub(1, i - 1)
        end
    end
    return text
end

-- The plate's label: the page's name, without control characters (set() refuses them).
local function labelOf(key, account)
    local text = nameOf({ playerId = key, name = account }):gsub("%c", " ")
    return trimUtf8(text)
end

-- What the plate of `key` should be. nil: no override (the drawer's default, the platform's
-- name), for a player never seen with a body here and without a caller's name.
local function nativeOptions(key, everyone)
    if everyone or hiddenByCallers(key) or Native.mapHidden[key] then return { visible = false } end
    local account = Native.names[key]
    if account == nil and callerName(key) == nil then return nil end
    return { label = labelOf(key, account), visible = true }
end

-- One set()/remove() per player per change, never per tick.
local function nativeApply(key, options)
    local signature = options and ((options.visible == false and "h" or "v") .. "\1" .. (options.label or "")) or nil
    if Native.applied[key] == signature then return end
    local pid = tonumber(key)
    if options == nil then
        pcall(Open77.nameplates.remove, pid)
        Native.applied[key] = nil
        return
    end
    local ok, done, why = pcall(Open77.nameplates.set, pid, options)
    if ok and done then
        Native.applied[key] = signature
    else
        -- Not recorded: tried again on the next sync (another resource may let go of it).
        local reason = tostring(ok and why or done)
        warn("set:" .. reason, "plate for " .. key .. " refused: " .. reason)
    end
end

local function localKey()
    if type(Open77.players.localId) ~= "function" then return nil end
    local ok, id = pcall(Open77.players.localId)
    return (ok and id ~= nil) and tostring(id) or nil
end

-- open77_nameplates (the platform's own plates) is not in Light RP's load lists. Should an
-- operator add it, it would label the same players: next to the page that is a second set
-- of plates, and with the native drawer a second owner of the one drawer, which keeps it
-- drawing through setHidden(true) (Prop Hunt). So while this resource runs it asks
-- open77_nameplates to stand down (its setEnabled export) and gives it back on stop.
local platformStoodDown = false
local function standDownPlatformPlates()
    if call("open77_nameplates", "isEnabled") ~= true then return end
    if call("open77_nameplates", "setEnabled", false) == true then
        platformStoodDown = true
        warn("platform", "open77_nameplates runs too: asked to stand down, these plates are op77_playermarks'")
    end
end
local function giveBackPlatformPlates()
    if not platformStoodDown then return end
    platformStoodDown = false
    call("open77_nameplates", "setEnabled", true)
end

-- Every player of the session: the label and hidden state of their plate.
local function nativeSync()
    if not Native.on then return end
    standDownPlatformPlates()
    local everyone = allHidden()
    nativeRender(not everyone)
    local me = localKey()
    local want = {}
    -- With a body here: decided now.
    local ok, list = pcall(Open77.players.nearby, ROSTER_RADIUS, { includeSelf = false })
    if ok and type(list) == "table" then
        for _, p in ipairs(list) do
            local pid = p.playerId or p.id
            local key = pid ~= nil and tostring(pid) or nil
            if key and not p.isLocal and key ~= me then
                Native.names[key] = type(p.name) == "string" and p.name or ""
                Native.mapHidden[key] = call("op77_map3d", "arePlayerDotsHidden", pid) == true
                want[key] = true
            end
        end
    end
    -- The rest of the session (no body here): ready before they stream in.
    if type(Open77.players.all) == "function" then
        local okAll, ids = pcall(Open77.players.all)
        if okAll and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local key = tostring(id)
                if key ~= me then want[key] = true end
            end
        end
    end
    -- The players a caller hid by id, whether or not this client lists them yet.
    for _, set in pairs(hiddenBy) do
        if type(set) == "table" then
            for key in pairs(set) do
                if key ~= me then want[key] = true end
            end
        end
    end
    for key in pairs(want) do nativeApply(key, nativeOptions(key, everyone)) end
    -- Gone from the session: the override goes with them.
    for key in pairs(Native.applied) do
        if not want[key] then nativeApply(key, nil) end
    end
    for key in pairs(Native.names) do
        if not want[key] then Native.names[key] = nil; Native.mapHidden[key] = nil end
    end
end

-- The theme, then the drawer. false: this client draws with the page.
local function startNative()
    if C.native == false or not nativeAvailable() then return false end
    if not applyStyle() then
        warn("native", "native nameplates without the Light RP theme: page instead")
        return false
    end
    local ok, done, why = pcall(Open77.nameplates.render, true)
    if not (ok and done) then
        warn("native", "native nameplates refused (" .. tostring(ok and why or done) .. "): page instead")
        pcall(Open77.nameplates.resetStyle)
        return false
    end
    Native.on, Native.rendering = true, true
    local synced, err = pcall(nativeSync)
    if not synced then warn("sync", "sync failed: " .. tostring(err)) end
    return true
end

local function syncNow()
    if not Native.on then return end
    local ok, err = pcall(nativeSync)
    if not ok then warn("sync", "sync failed: " .. tostring(err)) end
end

-- ---------------------------------------------------------------------------------------
-- Exports (the same for both drawers).
-- ---------------------------------------------------------------------------------------

-- setHidden(true[, ids]): hide every plate (no ids) or those players' (a list of server ids);
-- setHidden(false): show again what this caller hid. Each caller's choice replaces its
-- previous one and goes when it stops. The native drawer applies it at once, the page on the
-- next refresh (refreshMs).
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
    local done = setHidden(owner, on, ids)
    syncNow()
    return done
end)
exports("arePlatesHidden", function(pid) return hidden(pid) end)

-- setNames({ [player id] = name, ... }): the plates show these names instead of the accounts'
-- (a roleplay character's name); setNames(nil) or {} gives the accounts' back. Each caller's
-- list replaces its previous one and goes when it stops; applied like setHidden.
local function setNames(owner, names)
    if type(names) ~= "table" then namesBy[owner] = nil; return true end
    local set, any = {}, false
    for id, name in pairs(names) do
        if type(name) == "string" and name:match("%S") and tonumber(id) then
            set[tostring(math.floor(tonumber(id)))] = name:sub(1, 64); any = true
        end
    end
    namesBy[owner] = any and set or nil
    return true
end
exports("setNames", function(names)
    local owner = (type(GetInvokingResource) == "function" and GetInvokingResource()) or "export"
    local done = setNames(owner, names)
    syncNow()
    return done
end)

-- For the offline tests: the loop bodies and the state, no game needed.
PlayerMarks = { refresh = refresh, talk = talk, marks = marks, setHidden = setHidden, setNames = setNames,
    attach = function(p) page, pageReady = p, true end,
    native = Native, sync = nativeSync, theme = theme }

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
    if startNative() then
        CreateThread(function()
            while Native.on do
                Wait(C.refreshMs)
                syncNow()
            end
        end)
        return
    end
    CreateThread(createPage)
    CreateThread(function()
        while true do
            standDownPlatformPlates()
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

-- A native world exit drops every render request (the theme and the overrides stay, but
-- player ids may now name other people): ask again, and set every plate again.
AddEventHandler("open77:worldReady", function()
    if not Native.on then return end
    applyStyle()
    Native.rendering = nil
    for key in pairs(Native.applied) do Native.applied[key] = "!" end
    Native.names, Native.mapHidden = {}, {}
    syncNow()
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then
        if Native.on then
            Native.on = false
            -- clear() releases everything this resource asked of the drawer: its overrides
            -- and its render request (the theme goes with the resource).
            pcall(Open77.nameplates.clear)
        elseif anchorsOk then
            pcall(Open77.anchors.clear)
        end
        giveBackPlatformPlates()
        return
    end
    hiddenBy[name] = nil
    namesBy[name] = nil
    if name == "open77_nameplates" then platformStoodDown = false end
    syncNow()
end)
