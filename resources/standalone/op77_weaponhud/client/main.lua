-- op77_weaponhud client: reads the drawn weapon (Open77.weapons.snapshot, one request in
-- flight) and feeds the holographic weapon HUD page (web/). One small WebUI surface,
-- cropped to the bottom-left corner, created visible and transparent: the page shows and
-- hides its own content. There is no shot event: shots are magazine deltas between two
-- snapshots; reloads come from the snapshot's flag and Open77.players.isReloading().
-- A weapon that is not V's (a piloted Titan's) is handed over by a gamemode (setExternal)
-- and shown in its place, through the same show / data / hide flow.
local W = WeaponHud
local base = W.copy(WeaponHudConfig)
local config = W.copy(base)
local pageConfig = W.pageConfig(config)

local page, pageReady, creating, boundsKey = nil, false, false, nil
local pending = nil           -- { id, at, rows }
local lastRequest = -100000
local held = nil              -- { key, magazine, reloading, ... } last published
local shown = false
local lastShow, lastData = nil, nil
local suppress = {}
local insets = {}             -- owner -> px
local labels = {}             -- owner -> { record = label }
local infoCache = {}
local nativeHidden, announced = false, nil
local warned = {}

local function now() return type(GetGameTimer) == "function" and GetGameTimer() or math.floor(os.clock() * 1000) end
local function warn(key, text) if not warned[key] then warned[key] = true; print("[weaponhud] " .. text) end end
local function dbg(fmt, ...) if config.debug then print("[weaponhud] " .. string.format(fmt, ...)) end end
local function send(name, payload) if page and pageReady then pcall(page.send, page, name, payload) end end

-- ── gamemode handshake (LightRP's own weapon readout stands down while this one runs) ──
local function announce()
    local active = config.enabled ~= false
    if announced == active then return end
    announced = active
    TriggerEvent("op77_weaponhud:state", { active = active })
end
AddEventHandler("op77_weaponhud:query", function() announced = nil; announce() end)

local function syncNative()
    local want = config.enabled ~= false and config.hideNativeWeaponHud ~= false
    if want == nativeHidden then return end
    if type(Open77.hud) ~= "table" or type(Open77.hud.setVisible) ~= "function" then return end
    local ok, accepted = pcall(Open77.hud.setVisible, "weapon", not want)
    if ok and accepted then nativeHidden = want else warn("native", "cannot claim the native weapon HUD: " .. tostring(accepted)) end
end

-- ── lift and names from gamemodes ──
local function insetPx()
    local px = 0
    for _, v in pairs(insets) do px = math.max(px, v) end
    return math.min(px, pageConfig.layout.maxInset)
end
local function setInset(owner, px)
    px = tonumber(px) or 0
    insets[tostring(owner)] = px > 0 and px or nil
    send("weapon:inset", { px = insetPx() })
end
AddEventHandler("op77_weaponhud:inset", setInset)
AddEventHandler("op77_weaponhud:labels", function(owner, map)
    labels[tostring(owner)] = type(map) == "table" and map or nil
    held = held and W.copy(held) or nil
    if held then held.name = nil end -- re-described on the next sample
end)
local function labelFor(record)
    for _, map in pairs(labels) do if type(map[record]) == "string" then return { [record] = map[record] } end end
end

local function describe(record)
    local info = infoCache[record]
    if info == nil and record ~= "" and type(Open77.data) == "table" and type(Open77.data.weapon) == "function" then
        local ok, value = pcall(Open77.data.weapon, record)
        info = ok and type(value) == "table" and value or false
        infoCache[record] = info
    end
    return W.describe(record, info or nil, WeaponHudCatalogue, labelFor(record), config.weaponNames)
end

-- ── the surface ──
local function createSurface()
    if creating then return end
    creating = true
    local bounds = W.bounds(pageConfig)
    local key = string.format("%d:%d:%d:%d", bounds.x, bounds.y, bounds.width, bounds.height)
    if page then pcall(page.destroy, page); page, pageReady = nil, false end
    local options = {
        entry = "web/index.html", layer = "hud", width = 1920, height = 1080, transparent = true, visible = true,
        fps = math.max(10, math.min(60, math.floor(tonumber(config.fps) or 30))),
        zIndex = math.floor(tonumber(config.zIndex) or 705), drawBounds = bounds,
    }
    local created, why
    for _ = 1, 120 do
        created, why = WebUI.create(options)
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created and why == "invalid_webui_draw_bounds" then
        warn("bounds", "crop refused, drawn on a full-screen surface")
        options.drawBounds = nil
        created, why = WebUI.create(options)
    end
    creating = false
    if not created then print("[weaponhud] no WebUI surface: " .. tostring(why)) return end
    page, boundsKey = created, key
    created:on("weapon:ready", function()
        pageReady = true
        send("weapon:config", pageConfig)
        send("weapon:inset", { px = insetPx() })
        if shown and lastShow then
            send("weapon:show", W.merge(lastShow, { instant = true }))
            if lastData then send("weapon:data", lastData) end
        end
    end)
end

local function syncSurface()
    if config.enabled == false then
        if page then pcall(page.destroy, page); page, pageReady, boundsKey = nil, false, nil end
        shown = false
        return
    end
    local b = W.bounds(pageConfig)
    local key = string.format("%d:%d:%d:%d", b.x, b.y, b.width, b.height)
    if (page == nil or key ~= boundsKey) and not creating then shown = false; CreateThread(createSurface) end
end

local function apply(patch)
    if type(patch) ~= "table" then return false end
    if patch.reset then config = W.copy(base) else config = W.merge(config, patch) end
    pageConfig = W.pageConfig(config)
    send("weapon:config", pageConfig)
    syncNative(); syncSurface(); announce()
    return true
end

-- ── sampling ──
local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function cursorTaken()
    if type(Open77.input) ~= "table" or type(Open77.input.isCaptured) ~= "function" then return false end
    local ok, _, cursor = pcall(Open77.input.isCaptured)
    return ok and cursor == true
end
local function armedHint()
    -- Cheap gate before asking for a snapshot; nil when the client does not expose it.
    if type(Open77.character) == "table" then return read(Open77.character.isArmed) end
end

-- Draws one weapon, or folds the display away when `w` is nil. `w` = { key, magazine, capacity, reserve, reloading, left?, boost? };
-- `describe()` answers { name, type, class, melee } and runs only when the page needs to know the weapon (shown, switched,
-- renamed). Shots are the magazine deltas against the last weapon drawn.
local function present(w, describe)
    if not w then
        if shown then shown = false; send("weapon:hide", {}); dbg("hide") end
        held = nil
        return
    end
    local cur = { key = w.key, magazine = w.magazine, reloading = w.reloading }
    local change = W.diff(held, cur)
    if change.switched or not shown or (held and held.name == nil) then
        local d = describe()
        lastShow = { key = w.key, name = d.name, type = d.type, class = d.class, melee = d.melee, capacity = w.capacity }
        cur.name = d.name
        if change.switched or not shown then
            lastData = nil
            shown = true
            send("weapon:show", lastShow)
            dbg("show %s (%s)", d.name, w.key)
        else
            send("weapon:show", W.merge(lastShow, { instant = true }))
        end
    else
        cur.name = held.name
    end
    if lastShow and lastShow.melee then
        -- blades, fists, arm cyberware: no magazine, no reserve, never "NO AMMO"
        lastData = { melee = true, shots = 0, reloaded = false, low = false, empty = false, boost = w.boost == true }
    else
        lastData = {
            magazine = w.magazine, capacity = w.capacity, reserve = w.reserve, reloading = w.reloading,
            shots = change.shots, reloaded = change.reloaded == true,
            low = W.low(w.magazine, w.capacity, pageConfig), empty = w.magazine == 0,
            left = w.left, boost = w.boost == true,
        }
    end
    send("weapon:data", lastData)
    held = cur
end

-- Whether the display may show now: the surface exists and no rule hides it (disabled, a menu holds the cursor, a vehicle
-- when showInVehicles is off, a gamemode's hide()).
local function mayShow(armed)
    local inVehicle = read(type(Open77.players) == "table" and Open77.players.isInVehicle or nil) == true
    return page ~= nil and W.shouldShow(config, { armed = armed, busy = cursorTaken(), inVehicle = inVehicle, suppressed = next(suppress) ~= nil })
end

-- ── a weapon that is not V's (a piloted Titan's) ──
-- A gamemode that owns such a weapon hands it over with setExternal; it is shown instead of the snapshot's weapon for as
-- long as it is set: no snapshot is asked, the same display rules apply. With several owners the latest to set one wins.
local externals = {}          -- owner -> { seq, weapon = W.external(state) }
local externalSeq = 0
local function external()
    local best
    for _, entry in pairs(externals) do if not best or entry.seq > best.seq then best = entry end end
    return best and best.weapon or nil
end
local function setExternal(owner, state)
    owner = tostring(owner)
    if state == nil then externals[owner] = nil; return true end
    local weapon = W.external(state)
    if not weapon then return false end
    local entry = externals[owner]
    if entry then
        entry.weapon = weapon
    else
        externalSeq = externalSeq + 1
        externals[owner] = { seq = externalSeq, weapon = weapon }
    end
    pending = nil -- a snapshot in flight is not this weapon's
    return true
end

local function publishExternal(weapon)
    present(mayShow(true) and weapon or nil, function()
        return { name = weapon.name, type = weapon.type, class = weapon.class, melee = weapon.melee }
    end)
end

local function publish(rows)
    if external() then return end -- the snapshot answered after a weapon was handed over
    local right, left = W.held(rows)
    if not right and left then right, left = left, nil end
    local reloadingNow = read(type(Open77.players) == "table" and Open77.players.isReloading or nil) == true
    if not mayShow(right ~= nil) then return present(nil) end
    present({
        key = right.slot .. ":" .. right.tweakDbId, magazine = right.magazine, capacity = right.capacity, reserve = right.reserve,
        reloading = right.reloading or reloadingNow,
        left = left and { magazine = left.magazine, capacity = left.capacity } or nil,
    }, function() return describe(right.record) end)
end

local function step()
    local t = now()
    if pending and t - pending.at > 1500 then pending = nil end
    local weapon = external()
    if weapon then
        publishExternal(weapon)
        return true -- a weapon is handed over: keep the display's pace even while a menu hides it
    end
    local armed = armedHint()
    if armed == false then
        pending = nil
        publish({})
        return false
    end
    if not pending and type(Open77.weapons) == "table" and type(Open77.weapons.snapshot) == "function" then
        lastRequest = t
        local ok, id = pcall(Open77.weapons.snapshot)
        if ok and id then pending = { id = tostring(id), at = t, rows = {} } end
    end
    return shown
end

AddEventHandler("open77:weapons:state", function(id, ...)
    if not pending or tostring(id) ~= pending.id then return end
    local r = W.row(...)
    if r.slot >= 1 and r.slot <= 6 then pending.rows[r.slot] = r end
end)
AddEventHandler("open77:weapons:completed", function(id, operation, accepted)
    if not pending or tostring(id) ~= pending.id or operation ~= "snapshot" then return end
    local result = pending
    pending = nil
    if accepted ~= "true" then return end
    publish(result.rows)
end)

-- ── start ──
AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    announce(); syncNative(); syncSurface()
    if type(TriggerServerEvent) == "function" then TriggerServerEvent("op77_weaponhud:hello") end
    CreateThread(function()
        while true do
            local active = step()
            Wait(math.max(50, math.floor(tonumber(active and config.pollMs or config.idleMs) or 200)))
        end
    end)
    CreateThread(function()
        for _ = 1, 30 do
            if nativeHidden or config.enabled == false or config.hideNativeWeaponHud == false then break end
            Wait(2000)
            syncNative()
        end
    end)
end)
AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then
        suppress[name] = nil; insets[name] = nil; labels[name] = nil; externals[name] = nil
        return
    end
    TriggerEvent("op77_weaponhud:state", { active = false })
end)
RegisterNetEvent("op77_weaponhud:config", function(patch) apply(patch) end)

-- ── exports (any client resource) ──
exports("setConfig", function(patch) return apply(patch) end)
exports("getConfig", function() return W.copy(config) end)
exports("setEnabled", function(on) return apply({ enabled = on ~= false }) end)
exports("isEnabled", function() return config.enabled ~= false end)
exports("isShown", function() return shown end)
exports("hide", function(reason) suppress[tostring(reason or GetInvokingResource() or "export")] = true; return true end)
exports("show", function(reason) suppress[tostring(reason or GetInvokingResource() or "export")] = nil; return true end)
-- Lift above a growing bottom-left stack (px, CSS of a 1080-high screen; 0 = none).
exports("setInset", function(px) setInset(GetInvokingResource() or "export", px) return true end)
-- Names for records, e.g. { ["Items.Preset_Lexington_Default"] = "Service pistol" }.
exports("setLabels", function(map) labels[GetInvokingResource() or "export"] = type(map) == "table" and map or nil; return true end)
-- A weapon that is not one of V's, shown instead of the drawn weapon until it is cleared: a piloted Titan's, for example.
-- setExternal({ key, name, class?, type?, melee?, magazine?, capacity?, reserve?, reloading?, boost? }) sets or updates it (call it
-- again with the new magazine; `key` tells one weapon from another: a new key unfolds the display), setExternal(nil) clears
-- it. Per calling resource, cleared when that resource stops. Returns false for a state that names nothing. `boost = true`
-- makes the readout glow (a core burns).
exports("setExternal", function(state) return setExternal(GetInvokingResource() or "export", state) end)
