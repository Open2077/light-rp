-- Client side of the Neural-Link: owns the WebUI surface, the input focus,
-- the request relay to the server, the call voice-level feed, the clock and
-- the third-party app registry. The page contract is PROTOCOL.md.
--
-- Focus model (the player keeps walking while the interface is open):
--   open, browsing   -> setFocus(false, true)  mouse to the page, keys to the game
--   typing           -> setFocus(true, true)   the page takes the keyboard too
--   closed           -> setFocus(false, false)
local C = NeuralConfig
local page
local pageReady = false
local isOpen, typing = false, false
local cache = { state = nil, call = nil }     -- replayed to a (re)loaded page
local pending = {}                            -- server request id -> page request id
local nextRequest = 1
local apps = {}                               -- third-party apps: id -> { def, owner }
local soundSlots = {}                         -- sound slot -> { id, file } (see Sounds)
local toggleKey = C.toggleKey                 -- the key actually bound (the player can rebind it)

local function send(name, payload)
    if page and pageReady then page:send(name, payload == nil and {} or payload) end
end

local function appList()
    local list = {}
    for id, entry in pairs(apps) do
        list[#list + 1] = { id = id, label = entry.def.label, icon = entry.def.icon, color = entry.def.color }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- ---------------------------------------------------------------------------
-- Focus

local function applyFocus()
    if not page then return end
    if not isOpen then
        page:setFocus(false, false)
    elseif typing then
        page:setFocus(true, true)
    else
        page:setFocus(false, true)
    end
    send("nl:focus", { keyboard = isOpen and typing })
end

local function open(link)
    if not page or not pageReady then return end
    if not cache.state or not cache.state.ready then
        -- no line yet (character not chosen, database down): show the sync screen anyway
        TriggerServerEvent("op77_neuralink:hello")
    end
    isOpen, typing = true, false
    send("nl:open", link or {})
    applyFocus()
    TriggerServerEvent("op77_neuralink:interface", true)
end

local function close()
    if not isOpen then return end
    isOpen, typing = false, false
    -- a ringtone preview (up to 21 s) does not outlive the interface
    if soundSlots.preview then StopSound(soundSlots.preview.id) end
    send("nl:close", {})
    applyFocus()
    TriggerServerEvent("op77_neuralink:interface", false)
end

local function toggle() if isOpen then close() else open() end end

-- ---------------------------------------------------------------------------
-- Sounds
--
-- A resource owns at most 16 sound handles, and a finished clip keeps its
-- handle until it is destroyed: one Play2DSound per click went silent after
-- the sixteenth. Each slot (a UI sound, the ringtone preview, the two slots the
-- installation sequence shares) keeps one handle and restarts it; 15 slots in all.

local soundFailure

local function playSound(slot, file, volume)
    local entry = soundSlots[slot]
    if entry and entry.file ~= file then DestroySound(entry.id) entry = nil end
    if entry then
        local state = GetSoundState(entry.id)
        if state and state.status ~= "error" then
            StopSound(entry.id)
            SetSoundVolume(entry.id, volume)
            if PlaySound(entry.id) then return end
        end
        DestroySound(entry.id)
        entry = nil
    end
    soundSlots[slot] = nil
    local id, why = Play2DSound(file, { volume = volume })
    if id then
        soundSlots[slot] = { id = id, file = file }
    elseif why ~= soundFailure then
        soundFailure = why
        print("[neuralink] sound " .. slot .. " refused: " .. tostring(why))
    end
end

-- ---------------------------------------------------------------------------
-- The page

local function onRequest(payload, requestId)
    local op = type(payload) == "table" and payload.op or nil
    local args = type(payload) == "table" and type(payload.args) == "table" and payload.args or {}
    if type(op) ~= "string" then page:reply(requestId, "invalid_request", false) return end
    if op == "apps.launch" then
        local entry = apps[args.id]
        if not entry then page:reply(requestId, "unknown_app", false) return end
        page:reply(requestId, {}, true)
        if entry.def.closeOnLaunch ~= false then close() end
        TriggerEvent(entry.def.event, entry.def.id)
        return
    end
    -- the location of a rich message (a fixer's meeting point): a waypoint on the map,
    -- through op77_map3d when it runs (it mirrors the game's waypoint), else the game's
    if op == "map.pin" then
        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
        if not x or not y or not z or math.abs(x) > 100000 or math.abs(y) > 100000 or math.abs(z) > 100000 then
            page:reply(requestId, "invalid_request", false)
            return
        end
        local pos = { x = x, y = y, z = z }
        local ok = pcall(function() return exports.op77_map3d:setWaypoint(pos) end)
        if not ok and Open77.blips and type(Open77.blips.setWaypoint) == "function" then
            local set, done = pcall(Open77.blips.setWaypoint, pos)
            ok = set and done ~= false
        end
        TriggerEvent("op77_neuralink:waypoint", pos, type(args.label) == "string" and args.label or nil)
        if ok then page:reply(requestId, {}, true) else page:reply(requestId, "map_unavailable", false) end
        return
    end
    local id = nextRequest
    nextRequest = nextRequest + 1
    pending[id] = { page = requestId, at = Open77.time.monotonic() }
    TriggerServerEvent("op77_neuralink:request", id, op, args)
end

local function createPage()
    -- A surface cannot be created while the resource is still preparing (file
    -- scope at start): retry until the host accepts it.
    local created, why
    for attempt = 1, 120 do
        created, why = Open77.webui.create({
            entry = "web/index.html", layer = "menu", zIndex = 40,
            transparent = true, visible = true, fps = 60,
        })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then print("[neuralink] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("ui:ready", function()
        pageReady = true
        if cache.state then
            local state = {}
            for k, v in pairs(cache.state) do state[k] = v end
            state.apps = appList()
            state.call = cache.call
            send("nl:state", state)
        end
        TriggerServerEvent("op77_neuralink:hello")
        send("nl:keys", { toggle = toggleKey })
        if isOpen then send("nl:open", {}) applyFocus() end
    end)
    page:on("nl:close", function() close() end)
    page:on("nl:typing", function(payload)
        local active = type(payload) == "table" and payload.active == true
        if active ~= typing then typing = active applyFocus() end
    end)
    -- Every sound of the interface is played here: the page only names it
    -- (`ui:<name>` with the player's volume, or `preview:<ringtone>`).
    page:on("nl:sound", function(payload)
        local name = type(payload) == "table" and type(payload.name) == "string" and payload.name or ""
        local settings = cache.state and cache.state.settings or {}
        local volume = tonumber(type(payload) == "table" and payload.volume) or settings.volume or 0.8
        local ui = name:match("^ui:([%w_]+)$")
        local tone = name:match("^preview:(%w+)$")
        if ui and C.uiSounds[ui] then
            local sound = C.uiSounds[ui]
            local level = math.max(0, math.min(1, volume * sound.gain))
            if level > 0.001 then playSound(sound.slot or ("ui:" .. ui), sound.file, level) end
        elseif tone and C.ringtones[tone] then
            playSound("preview", C.ringtones[tone].file, math.max(0.05, math.min(1, volume)))
        end
    end)
    page:on("nl:request", onRequest)
end

-- ---------------------------------------------------------------------------
-- From the server

RegisterNetEvent("op77_neuralink:reply", function(id, ok, value)
    local entry = pending[id]
    if not entry then return end
    pending[id] = nil
    if page then
        if ok then page:reply(entry.page, value == nil and {} or value, true)
        else page:reply(entry.page, tostring(value or "server_error"), false) end
    end
end)

local talkersRunning = false
local function startTalkerFeed()
    if talkersRunning then return end
    talkersRunning = true
    CreateThread(function()
        while cache.call do
            local call = cache.call
            local levels = {}
            local remote = {}
            local ok, talkers = pcall(Open77.voice.talkers)
            if ok and type(talkers) == "table" then
                for _, t in ipairs(talkers) do
                    if t.talking then remote[tonumber(t.playerId) or 0] = tonumber(t.level) or 0.5 end
                end
            end
            local okStatus, status = pcall(Open77.voice.status)
            for _, p in ipairs(call.participants or {}) do
                if p.state == "connected" then
                    if p.isMe then
                        if okStatus and type(status) == "table" and status.transmitting == true and not call.muted then
                            local level = tonumber(status.inputLevel or status.microphoneActivity) or 0.5
                            levels[p.lineId] = math.max(0.15, math.min(1, level))
                        end
                    elseif p.playerId and remote[p.playerId] then
                        levels[p.lineId] = math.max(0.15, math.min(1, remote[p.playerId]))
                    end
                end
            end
            send("nl:talkers", levels)
            Wait(125)
        end
        talkersRunning = false
    end)
end

RegisterNetEvent("op77_neuralink:push", function(name, payload)
    if name == "nl:state" then
        cache.state = payload
        cache.call = type(payload) == "table" and payload.call or nil
        if type(payload) == "table" then payload.apps = appList() end
        if cache.call then startTalkerFeed() end
    elseif name == "nl:patch" and type(payload) == "table" and cache.state then
        for k, v in pairs(payload) do cache.state[k] = v end
    elseif name == "nl:call" then
        cache.call = payload
        if payload then startTalkerFeed() end
    end
    send(name, payload)
end)

-- ---------------------------------------------------------------------------
-- Clock and location for the Status app (every 10 s)

CreateThread(function()
    while true do
        if pageReady then
            local clock = {}
            local pendingCall = Open77.exports.call("open77_weather", "getState")
            local state = pendingCall and pendingCall:await() or nil
            if type(state) == "table" and state.hour then
                clock.hours, clock.minutes, clock.weather = state.hour, state.minute, state.weather
            end
            local okPlace, place = pcall(Open77.world.district)
            if okPlace and type(place) == "table" then
                -- the localized name can come back as an unresolved "LocKey#NNNN"
                local localized = type(place.localized) == "string" and not place.localized:find("^LocKey") and place.localized or nil
                local name = localized or place.subDistrict or place.district
                -- internal names are CamelCase ("CityCenter"): space them for display
                clock.district = type(name) == "string" and name:gsub("(%l)(%u)", "%1 %2") or nil
            end
            if clock.hours then send("nl:clock", clock) end
        end
        Wait(10000)
    end
end)

-- ---------------------------------------------------------------------------
-- Keys, pause and lifecycle

-- Registered once the resource runs (like op77_lightrp's keys): a call at file
-- scope, while the resource is still preparing, can be refused.
CreateThread(function()
    for attempt = 1, 40 do
        local ok, effective = RegisterKeyMapping("neuralink.toggle", "Neural-Link: open / close", C.toggleKey, toggle)
        if ok then
            if type(effective) == "string" and effective ~= "" then toggleKey = effective end
            send("nl:keys", { toggle = toggleKey })
            print("[neuralink] key " .. tostring(effective) .. " opens the Neural-Link")
            return
        end
        if attempt == 40 then print("[neuralink] key mapping refused: " .. tostring(effective)) end
        Wait(250)
    end
end)

-- The server's test harness (restricted console command) opens or closes the
-- interface: `link` is an open link ({ app = ... }) or false.
RegisterNetEvent("op77_neuralink:test", function(link)
    if type(link) == "table" then open(link) else close() end
end)

-- A server resource puts the interface away (exports.op77_neuralink:closeInterface).
RegisterNetEvent("op77_neuralink:close", function() close() end)

-- Escape outside a text field reaches the game (the page has the mouse only):
-- the pause menu opens, so the interface steps aside.
AddEventHandler("open77:pauseKey", function() close() end)

-- Pending requests the server never answered (dropped connection) fail after 15 s.
CreateThread(function()
    while true do
        Wait(5000)
        local now = Open77.time.monotonic()
        for id, entry in pairs(pending) do
            if now - entry.at > 15 then
                pending[id] = nil
                if page then page:reply(entry.page, "timeout", false) end
            end
        end
    end
end)

CreateThread(createPage)

-- ---------------------------------------------------------------------------
-- Client exports: third-party apps and deep links
--
--   exports.op77_neuralink:registerApp({ id, label, icon, color?, event, closeOnLaunch? })
--       icon = a lucide icon name; `event` is a local event fired with the app id on launch.
--   exports.op77_neuralink:unregisterApp(id)
--   exports.op77_neuralink:open({ app?, threadId?, number? }) / close() / isOpen()

exports("registerApp", function(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or not def.id:match("^[%w_%-]+$") or #def.id > 32 then return false, "invalid_id" end
    if type(def.label) ~= "string" or #def.label < 1 or #def.label > 24 then return false, "invalid_label" end
    if type(def.icon) ~= "string" or type(def.event) ~= "string" then return false, "invalid_app" end
    local owner = GetInvokingResource and GetInvokingResource() or "?"
    local existing = apps[def.id]
    if existing and existing.owner ~= owner then return false, "app_taken" end
    apps[def.id] = { owner = owner, def = { id = def.id, label = def.label, icon = def.icon, color = def.color,
        event = def.event, closeOnLaunch = def.closeOnLaunch } }
    send("nl:patch", { apps = appList() })
    return true
end)

exports("unregisterApp", function(id)
    local entry = apps[id]
    local owner = GetInvokingResource and GetInvokingResource() or "?"
    if not entry or entry.owner ~= owner then return false end
    apps[id] = nil
    send("nl:patch", { apps = appList() })
    return true
end)

exports("open", function(link) open(type(link) == "table" and link or nil) return true end)
exports("close", function() close() return true end)
exports("isOpen", function() return isOpen end)

-- Apps of a resource that stops disappear with it.
AddEventHandler("onClientResourceStop", function(name)
    local changed = false
    for id, entry in pairs(apps) do if entry.owner == name then apps[id] = nil changed = true end end
    if changed then send("nl:patch", { apps = appList() }) end
end)
