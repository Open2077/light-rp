-- op77_weaponhud: the shared logic, the client with the host stubbed (snapshot rows ->
-- page events, shots, reloads, switches), and the LightRP handshake (its own readout
-- stands down, the grenade chip lifts the HUD, RP names). Run from the resource folder:
--   pwsh -NoProfile -File tests/run-lua.ps1
-- The client Lua sandbox has no setmetatable / load / require / debug...: removed here too.
setmetatable, getmetatable, rawget, rawset, rawequal, load, loadstring, require, debug = nil, nil, nil, nil, nil, nil, nil, nil, nil

-- ── shared ──
dofile("shared/config.lua")
dofile("shared/weaponhud.lua")
dofile("client/catalogue.lua")
local W = WeaponHud
do
    local page = W.pageConfig(WeaponHudConfig)
    assert(page.layout.left == 36 and page.layout.bottom == 142 and page.layout.scale == 0.6 and page.layout.tiltY == 16)
    local bad = W.pageConfig(W.merge(WeaponHudConfig, { layout = { scale = 9, maxInset = -3 }, theme = { warn = "nope" }, maxCells = 500 }))
    assert(bad.layout.scale == 1.6 and bad.layout.maxInset == 0 and bad.theme.warn == "#FF3B3B" and bad.maxCells == 60)

    -- crop: anchored bottom-left, room for the lift, never past the bottom edge
    local b = W.bounds(page)
    assert(b.x == 0 and b.width == 36 + 252 + 48, "width " .. b.width)
    assert(b.y == -(142 + 60 + 126 + 48) and b.height == 126 + 96 + 60, "y " .. b.y .. " h " .. b.height)
    assert(b.y + b.height <= 0)

    -- snapshot rows (string transport, -1 = unknown)
    local r = W.row("1", "Items.Preset_Lexington_Default", "0x00000017AABBCCDD", "true", "true", "false", "Ammo.HandgunAmmo", "0x1", "141", "120", "21", "21", "false")
    assert(r.slot == 1 and r.drawn and r.active and not r.empty and r.magazine == 21 and r.capacity == 21 and r.reserve == 120 and not r.reloading)
    local unknown = W.row("2", "", "0x0000001", "false", "false", "false", "", "", "-1", "-1", "-1", "-1", "false")
    assert(unknown.magazine == nil and unknown.capacity == nil and unknown.reserve == nil)
    assert(W.row("3", "", "", "false", "false").empty)
    assert(W.row("1", "x", "0x1", "true", "true", "false", "", "", "0", "0", "30", "0", "true").capacity == nil, "zero capacity = unknown")
    local left = W.row("4", "Items.Preset_Burya_Default", "0x2", "true", "true", "false", "", "", "0", "40", "9", "10", "false")
    local right, l = W.held({ [1] = r, [2] = unknown, [4] = left })
    assert(right == r and l == left)
    local holstered = W.row("1", "x", "0x1", "true", "false")
    assert(W.held({ [1] = holstered }) == nil)

    -- names and classes: labels > config names > the game's name > the record
    local d = W.describe("Items.Preset_Lexington_Default", { displayName = "Lexington" }, WeaponHudCatalogue)
    assert(d.name == "LEXINGTON" and d.class == "POWER" and d.type == "HANDGUN" and not d.melee, d.class)
    assert(W.describe("Items.Preset_Lexington_Default", nil, WeaponHudCatalogue, { ["Items.Preset_Lexington_Default"] = "Service pistol" }).name == "SERVICE PISTOL")
    assert(W.describe("Items.Preset_Unknown_Thing", {}, {}).name == "UNKNOWN THING")
    assert(W.describe("", nil, {}).name == "WEAPON")
    assert(W.describe("x", { itemType = "ItemType.Wea_SubmachineGun", evolution = "WeaponEvolution.Smart" }, {}).class == "SMART")
    assert(W.describe("x", { itemType = "ItemType.Wea_SubmachineGun" }, {}).type == "SMG")
    local katana = W.describe("Items.Preset_Katana_Default", nil, WeaponHudCatalogue)
    assert(katana.class == "BLADE" and katana.melee and katana.type == "KATANA", tostring(katana.class))
    local tech, smart = 0, 0
    for _, v in pairs(WeaponHudCatalogue) do if v:sub(1, 1) == "T" then tech = tech + 1 elseif v:sub(1, 1) == "S" then smart = smart + 1 end end
    assert(tech > 100 and smart > 100, "catalogue has tech and smart weapons")

    -- what changed
    assert(W.diff(nil, { key = "a", magazine = 21 }).switched)
    assert(W.diff({ key = "a", magazine = 21 }, { key = "a", magazine = 18 }).shots == 3)
    assert(W.diff({ key = "a", magazine = 18 }, { key = "a", magazine = 15, reloading = true }).shots == 0, "no shots counted while reloading")
    assert(W.diff({ key = "a", magazine = 2 }, { key = "a", magazine = 21 }).reloaded)
    assert(W.diff({ key = "a", magazine = 2 }, { key = "b", magazine = 30 }).switched)
    assert(W.low(4, 21, page) and not W.low(10, 21, page) and not W.low(0, 21, page) and W.low(10, 100, page) and not W.low(11, 100, page))

    assert(W.shouldShow(WeaponHudConfig, { armed = true }))
    assert(not W.shouldShow(WeaponHudConfig, { armed = false }))
    assert(not W.shouldShow(WeaponHudConfig, { armed = true, busy = true }))
    assert(W.shouldShow(WeaponHudConfig, { armed = true, inVehicle = true }), "kept in vehicles by default")
    assert(not W.shouldShow({ showInVehicles = false }, { armed = true, inVehicle = true }))
    assert(not W.shouldShow(WeaponHudConfig, { armed = true, suppressed = true }))
    print("PASS shared")
end

-- ── client + LightRP, host stubbed ──
do
    local handlers, net, threads, exportsMap = {}, {}, {}, {}
    local events, surfaces, claims = {}, {}, {}
    local armed, cursor, reloadingNow, inVehicle = false, false, false, false
    local slots = {}            -- slot -> row args (strings)
    local requests = 0
    local clock = 0

    function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
    function TriggerEvent(name, ...) events[#events + 1] = { name = name, args = { ... } }; for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
    function RegisterNetEvent(name, fn) net[name] = fn end
    function TriggerServerEvent() end
    function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
    function Wait() coroutine.yield() end
    function exports(name, fn) exportsMap[name] = fn end
    function GetCurrentResourceName() return "op77_weaponhud" end
    function GetInvokingResource() return "tester" end
    function GetGameTimer() return clock end
    local function tick(n)
        for _ = 1, n or 1 do
            clock = clock + 100
            for i = 1, #threads do
                local co = threads[i]
                if co and coroutine.status(co) == "suspended" then local ok, err = coroutine.resume(co); assert(ok, err) end
            end
        end
    end
    WebUI = { create = function(options)
        local s = { options = options, sent = {}, on = {}, destroyed = false }
        s.page = { on = function(_, n, fn) s.on[n] = fn end, send = function(_, n, p) s.sent[#s.sent + 1] = { name = n, payload = p } end,
            destroy = function() s.destroyed = true end }
        surfaces[#surfaces + 1] = s
        return s.page
    end }
    -- the snapshot answers on the next tick, like the engine (rows, then completion)
    local inflight = {}
    Open77 = {
        hud = { setVisible = function(c, v) claims[c] = v; return true, v end },
        input = { isCaptured = function() return false, cursor end },
        character = { isArmed = function() return armed end },
        players = { isReloading = function() return reloadingNow end, isInVehicle = function() return inVehicle end },
        data = { weapon = function(record) if record == "Items.Preset_Lexington_Default" then return { displayName = "Lexington" } end return nil, "record_unknown" end },
        weapons = { snapshot = function() requests = requests + 1; inflight[#inflight + 1] = requests; return requests end },
    }
    local function answer()
        local list = inflight; inflight = {}
        for _, id in ipairs(list) do
            for slot = 1, 6 do
                local a = slots[slot] or { "", "", "false", "false", "false", "", "", "-1", "-1", "-1", "-1", "false" }
                TriggerEvent("open77:weapons:state", tostring(id), tostring(slot), table.unpack(a))
            end
            TriggerEvent("open77:weapons:completed", tostring(id), "snapshot", "true")
        end
    end
    local function step(n) for _ = 1, n or 1 do tick(); answer() end end
    local function lexington(mag, reloading)
        slots[1] = { "Items.Preset_Lexington_Default", "0xAA", "true", "true", "false", "Ammo.HandgunAmmo", "0x1", "141", "120", tostring(mag), "21", reloading and "true" or "false" }
    end
    local function last(s, name) for i = #s.sent, 1, -1 do if s.sent[i].name == name then return s.sent[i].payload end end end
    local function count(s, name) local n = 0 for _, m in ipairs(s.sent) do if m.name == name then n = n + 1 end end return n end

    -- LightRP's sampler in the same event bus
    LightRpConfig = { voice = { default = "normal", ranges = { normal = 20 } }, vehicles = { catalog = {} } }
    LightRpEvents = { page = { hud = "lightrp:ui:hud" } }
    local hudViews = {}
    LightRpUi = { send = function(_, view) hudViews[#hudViews + 1] = view end }
    local chip = false
    LightRpGrenadesClient = { chipShown = function() return chip end }
    LightRpArmamentClient = { state = function() return { right = { record = "Items.Preset_Lexington_Default", label = "Service pistol" } } end }
    local legacySamples = 0
    LightRpWeaponHud = { sample = function() legacySamples = legacySamples + 1; return { active = true, hands = {} } end }
    dofile("../../gamemodes/op77_lightrp/client/core/hud.lua")

    dofile("client/main.lua")
    for _, fn in ipairs(handlers.onClientResourceStart) do fn("op77_weaponhud") end
    assert(LightRpHud.externalWeaponHud == true, "LightRP heard it")
    assert(claims.weapon == false, "native weapon HUD hidden")
    tick()
    local s = surfaces[1]
    assert(s and s.options.drawBounds.x == 0 and s.options.zIndex == 705 and s.options.visible == true)
    s.on["weapon:ready"]()
    assert(last(s, "weapon:config").layout.left == 36)

    -- LightRP's sampler: its readout stands down, labels and lift go to the HUD
    local hudThreadCount = #threads
    LightRpHud.start()
    tick()
    assert(hudViews[#hudViews].weapon.active == false and legacySamples == 0, "no legacy readout, no legacy snapshot")
    assert(last(s, "weapon:inset").px == 0)
    chip = true; tick()
    assert(last(s, "weapon:inset").px == 30, "lifted above the grenade chip")

    -- nothing drawn: no snapshot, nothing shown
    step(2)
    assert(requests == 0 and count(s, "weapon:show") == 0)

    -- draw: shown with the RP name, data
    armed = true; lexington(21)
    step()
    local show = last(s, "weapon:show")
    assert(show and show.name == "SERVICE PISTOL" and show.class == "POWER" and show.type == "HANDGUN" and show.capacity == 21, show and show.name)
    local d = last(s, "weapon:data")
    assert(d.magazine == 21 and d.reserve == 120 and d.shots == 0 and not d.low and not d.empty)

    -- three shots between two samples
    lexington(18); step()
    assert(last(s, "weapon:data").shots == 3 and count(s, "weapon:show") == 1)
    -- low, then empty
    lexington(4); step(); assert(last(s, "weapon:data").low)
    lexington(0); step(); d = last(s, "weapon:data"); assert(d.empty and not d.low)
    -- reload: the flag, then the refill
    lexington(0, true); step(); assert(last(s, "weapon:data").reloading)
    reloadingNow = true; lexington(0); step(); assert(last(s, "weapon:data").reloading, "isReloading counts too")
    reloadingNow = false; lexington(21); step(); d = last(s, "weapon:data")
    assert(d.reloaded and d.magazine == 21 and d.shots == 0)

    -- a menu takes the cursor: hidden; back after (a new unfold)
    cursor = true; step(); assert(count(s, "weapon:hide") == 1)
    cursor = false; step(); assert(count(s, "weapon:show") == 2)

    -- switch weapons: a new unfold
    slots[1] = nil
    slots[2] = { "Items.Preset_Katana_Default", "0xBB", "true", "true", "false", "", "", "-1", "-1", "-1", "-1", "false" }
    step()
    show = last(s, "weapon:show")
    assert(count(s, "weapon:show") == 3 and show.class == "BLADE" and show.melee, show.name)

    -- holster
    armed = false; step(); assert(count(s, "weapon:hide") == 2)
    armed = true; step(); assert(count(s, "weapon:show") == 4)

    -- a scene hides it
    exportsMap.hide("cutscene"); step(); assert(count(s, "weapon:hide") == 3)
    exportsMap.show("cutscene"); step(); assert(count(s, "weapon:show") == 5)

    -- the server restyles: theme only keeps the surface, a layout change recreates it
    net["op77_weaponhud:config"]({ theme = { accent = "#3FE0D0" } }); tick()
    assert(#surfaces == 1 and last(s, "weapon:config").theme.accent == "#3FE0D0")
    exportsMap.setConfig({ layout = { scale = 0.8 } }); tick()
    assert(#surfaces == 2 and s.destroyed)

    -- off: LightRP's readout and the native HUD come back
    exportsMap.setEnabled(false); tick()
    assert(LightRpHud.externalWeaponHud == false and claims.weapon == true)
    tick(); assert(legacySamples > 0, "legacy readout sampled again")
    exportsMap.setEnabled(true); tick()
    assert(LightRpHud.externalWeaponHud == true)

    -- stops: LightRP takes over
    for _, fn in ipairs(handlers.onClientResourceStop) do fn("op77_weaponhud") end
    assert(LightRpHud.externalWeaponHud == false)
    print("PASS client + LightRP")
end
