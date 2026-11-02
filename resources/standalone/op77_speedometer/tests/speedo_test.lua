-- op77_speedometer: the shared logic, the client with the host stubbed, and the LightRP
-- handshake (its HUD sampler stands its cluster down). Run from the resource folder:
--   pwsh -NoProfile -File tests/run-lua.ps1
-- The client Lua sandbox has no setmetatable / load / require / debug...: remove them so a
-- use in the code under test fails here too.
setmetatable, getmetatable, rawget, rawset, rawequal, load, loadstring, require, debug = nil, nil, nil, nil, nil, nil, nil, nil, nil

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

-- ── shared ──
dofile("shared/config.lua")
dofile("shared/speedo.lua")
local S = Speedo
do
    local page = S.pageConfig(SpeedoConfig)
    assert(page.units == "kph" and page.unitLabel == "KPH" and page.speedMax == 240)
    assert(page.layout.right == 36 and page.layout.bottom == 146 and near(page.layout.scale, 0.6))
    assert(page.theme.accent == "#FFCC00" and page.theme.gear == "#FFCC00")

    -- a bad patch cannot break the page
    local bad = S.pageConfig(S.merge(SpeedoConfig, { units = "furlongs", layout = { scale = 99, right = "x" }, theme = { accent = "red", glow = -4 }, leadingZeros = "maybe" }))
    assert(bad.units == "kph" and bad.layout.scale == 1.6 and bad.layout.right == 36)
    assert(bad.theme.accent == "#FFCC00" and bad.theme.glow == 0 and bad.leadingZeros == "dim")
    local mph = S.pageConfig(S.merge(SpeedoConfig, { units = "mph", theme = { accent = "#3fe0d0" } }))
    assert(mph.unitLabel == "MPH" and mph.speedMax == 150 and mph.theme.accent == "#3FE0D0" and mph.theme.gear == "#FFCC00")

    -- merge: nested tables merge, arrays replace, the base is untouched
    local merged = S.merge(SpeedoConfig, { layout = { scale = 0.8 }, handbrakeKeys = { "X" } })
    assert(merged.layout.scale == 0.8 and merged.layout.right == 36 and #merged.handbrakeKeys == 1)
    assert(SpeedoConfig.layout.scale == 0.6 and #SpeedoConfig.handbrakeKeys == 2)

    -- crop: anchored bottom-right, never past the bottom edge, never into the voice HUD's
    -- rows when the display sits at the default place
    local b = S.bounds(page)
    assert(b.x == -(36 + 252 + 48) and b.width == 36 + 252 + 48, "x " .. b.x)
    assert(b.y == -(146 + 140 + 48) and b.height == 140 + 96, "y " .. b.y .. " h " .. b.height)
    assert(b.y + b.height <= 0)
    local low = S.bounds(S.pageConfig(S.merge(SpeedoConfig, { layout = { bottom = 0, offsetY = 30 } })))
    assert(low.y + low.height <= 0, "clamped to the bottom edge")
    local moved = S.bounds(S.pageConfig(S.merge(SpeedoConfig, { layout = { offsetX = 20 } })))
    assert(moved.width == b.width - 20)

    assert(S.vehicleName("Vehicle.v_sport2_quadra_type66_player") == "QUADRA TYPE66")
    assert(S.vehicleName("Vehicle.v_x", { ["Vehicle.v_x"] = "Turbo" }) == "TURBO")
    assert(S.isDriver({ seat = "seat_front_left" }) and not S.isDriver({ seat = "seat_front_right" }) and not S.isDriver(nil))

    local car = { speed = 17.5, gear = 3, rpm = 3300, rpmMax = 6000, flags = 1 | 64, health = 0.9, brake = 0, damage = { tires = 5, lights = 0 } }
    local s = S.sample(car, SpeedoConfig, { handbrake = true, fuel = { litres = 6, capacity = 60 } })
    assert(near(s.speed, 63) and near(s.kph, 63) and s.gear == "3" and near(s.rpm, 0.55))
    assert(s.handbrake and not s.abs and not s.tcs and s.lights == 1 and s.engine and not s.damaged and s.tires == 2)
    assert(near(s.fuel.fraction, 0.1) and s.fuel.low and not s.fuel.empty)
    s = S.sample({ speed = -3, gear = -1, flags = 128 | 64, health = 0.2, brake = 1 }, S.merge(SpeedoConfig, { units = "mph" }), {})
    assert(s.gear == "R" and s.reversing and near(s.speed, 3 * 2.236936) and s.lights == 2 and not s.engine and s.damaged)
    assert(not s.abs, "no ABS reversing")
    assert(s.rpm == nil and s.fuel == nil)
    s = S.sample({ speed = 30, gear = 4, brake = 0.9, burnout = true }, SpeedoConfig, {})
    assert(s.abs and s.tcs and s.gear == "4")
    assert(S.sample({ speed = 0, gear = 0 }, SpeedoConfig, {}).gear == "N")

    local base = { seated = true, driver = true, busy = false, suppressed = false }
    assert(S.shouldShow(SpeedoConfig, base))
    assert(not S.shouldShow({ enabled = false }, base))
    assert(not S.shouldShow(SpeedoConfig, { seated = true, driver = false }))
    assert(S.shouldShow({ showForPassengers = true }, { seated = true, driver = false }))
    assert(not S.shouldShow(SpeedoConfig, { seated = true, driver = true, busy = true }))
    assert(S.shouldShow({ hideUnderMenus = false }, { seated = true, driver = true, busy = true }))
    assert(not S.shouldShow(SpeedoConfig, { seated = true, driver = true, suppressed = true }))
    assert(not S.shouldShow(SpeedoConfig, { seated = false, driver = false }))
    print("PASS shared")
end

-- ── client + LightRP handshake, host stubbed ──
do
    local handlers, net, threads, exportsMap, serverEvents = {}, {}, {}, {}, {}
    local events = {}               -- local events fired, in order
    local surfaces, claims = {}, {}
    local seat, car, cursor, keyboard, keys = nil, nil, false, false, {}
    local bagValues = { fuel = 30, fuelMax = 60 }

    function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
    function TriggerEvent(name, ...) events[#events + 1] = { name = name, args = { ... } }; for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
    function RegisterNetEvent(name, fn) net[name] = fn end
    function TriggerServerEvent(name) serverEvents[#serverEvents + 1] = name end
    function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
    function Wait() coroutine.yield() end
    function exports(name, fn) exportsMap[name] = fn end
    function GetCurrentResourceName() return "op77_speedometer" end
    function GetInvokingResource() return "tester" end
    local function tick()
        for i = 1, #threads do
            local co = threads[i]
            if co and coroutine.status(co) == "suspended" then
                local ok, err = coroutine.resume(co)
                assert(ok, err)
            end
        end
    end
    WebUI = { create = function(options)
        local s = { options = options, sent = {}, on = {}, destroyed = false }
        s.page = {
            on = function(_, name, fn) s.on[name] = fn end,
            send = function(_, name, payload) s.sent[#s.sent + 1] = { name = name, payload = payload } end,
            destroy = function() s.destroyed = true end,
        }
        surfaces[#surfaces + 1] = s
        return s.page
    end }
    Open77 = {
        hud = { setVisible = function(c, v) claims[c] = v; return true, v end },
        input = {
            isCaptured = function() return keyboard, cursor end,
            isDown = function(k) return keys[k] == true end,
        },
        vehicles = {
            flags = { engineOn = 1, destroyed = 4, lightsOn = 64, highBeams = 128 },
            getPlayerSeat = function() return seat end,
            get = function(id) if seat and id == seat.vehicleId then return car end end,
        },
        state = { entity = function(kind, id) assert(kind == "vehicle" and id == 7); return { get = function(_, k) return bagValues[k] end } end },
    }
    local function last(s, name)
        for i = #s.sent, 1, -1 do if s.sent[i].name == name then return s.sent[i].payload, i end end
    end
    local function count(s, name) local n = 0 for _, m in ipairs(s.sent) do if m.name == name then n = n + 1 end end return n end
    local function stateEvents() local t = {} for _, e in ipairs(events) do if e.name == "op77_speedometer:state" then t[#t + 1] = e.args[1].active end end return t end

    -- LightRP's HUD sampler in the same event bus (its own globals stubbed)
    LightRpConfig = { voice = { default = "normal", ranges = { normal = 20 } }, vehicles = { catalog = {} } }
    LightRpEvents = { page = { hud = "lightrp:ui:hud" } }
    local hudSent = {}
    LightRpUi = { send = function(name, view) hudSent[#hudSent + 1] = view end }
    dofile("../../gamemodes/op77_lightrp/client/core/hud.lua")

    dofile("client/main.lua")
    for _, fn in ipairs(handlers.onClientResourceStart) do fn("op77_speedometer") end
    assert(stateEvents()[1] == true, "announced active")
    assert(LightRpHud.externalSpeedometer == true, "LightRP heard it")
    assert(claims.speedometer == false, "native speedometer hidden")
    assert(serverEvents[1] == "op77_speedometer:hello")

    tick()
    assert(#surfaces == 1, "one surface")
    local s1 = surfaces[1]
    local o = s1.options
    assert(o.visible == true and o.transparent == true and o.fps == 30 and o.zIndex == 710 and o.layer == "hud")
    assert(o.drawBounds and o.drawBounds.x == -336 and o.drawBounds.height == 236)
    s1.on["speedo:ready"]()
    assert(last(s1, "speedo:config").layout.scale == 0.6)

    -- on foot: nothing
    tick()
    assert(count(s1, "speedo:show") == 0)

    -- driver: shown, data in the configured units
    seat = { vehicleId = 7, seat = "seat_front_left" }
    car = { record = "Vehicle.v_sport2_quadra_type66_player", speed = 17.5, gear = 3, rpm = 3000, rpmMax = 6000, flags = 1 | 64, health = 1 }
    keys.SPACE = true
    tick()
    assert(count(s1, "speedo:show") == 1 and last(s1, "speedo:show").name == "QUADRA TYPE66")
    local d = last(s1, "speedo:data")
    assert(near(d.speed, 63) and d.gear == "3" and d.handbrake and near(d.fuel.fraction, 0.5) and d.lights == 1)
    -- the keyboard taken (chat): no handbrake read
    keyboard = true; tick(); assert(last(s1, "speedo:data").handbrake == false); keyboard = false
    keys.SPACE = false
    tick()
    assert(count(s1, "speedo:show") == 1, "shown once")

    -- a menu holds the cursor: hidden, back after
    cursor = true; tick()
    assert(count(s1, "speedo:hide") == 1)
    cursor = false; tick()
    assert(count(s1, "speedo:show") == 2)

    -- getting out: hidden as the exit starts
    seat.exiting = true; tick()
    assert(count(s1, "speedo:hide") == 2)
    seat.exiting = nil

    -- passenger: not by default, yes once allowed
    seat = { vehicleId = 7, seat = "seat_front_right" }
    tick(); assert(count(s1, "speedo:show") == 2)
    exportsMap.setConfig({ showForPassengers = true })
    tick(); assert(count(s1, "speedo:show") == 3)

    -- a scene asks it away, then gives it back
    exportsMap.hide("cutscene"); tick(); assert(count(s1, "speedo:hide") == 3)
    exportsMap.show("cutscene"); tick(); assert(count(s1, "speedo:show") == 4)

    -- the server moves it: a new crop, so a new surface (the old one destroyed)
    net["op77_speedometer:config"]({ layout = { scale = 0.8 }, units = "mph" })
    tick()
    assert(#surfaces == 2 and s1.destroyed, "recreated for the new crop")
    local s2 = surfaces[2]
    assert(s2.options.drawBounds.width == 36 + 336 + 48)
    s2.on["speedo:ready"]()
    assert(last(s2, "speedo:config").units == "mph")
    tick()
    assert(count(s2, "speedo:show") == 1 and near(last(s2, "speedo:data").speed, 17.5 * 2.236936))
    -- a theme-only patch keeps the surface
    exportsMap.setConfig({ theme = { accent = "#3FE0D0" } })
    tick()
    assert(#surfaces == 2 and last(s2, "speedo:config").theme.accent == "#3FE0D0")

    -- off: surface gone, native speedometer and LightRP's cluster back
    exportsMap.setEnabled(false)
    tick()
    assert(s2.destroyed and #surfaces == 2)
    local st = stateEvents()
    assert(st[#st] == false and LightRpHud.externalSpeedometer == false)
    assert(claims.speedometer == true, "native claim released")
    exportsMap.setEnabled(true)
    tick()
    assert(#surfaces == 3 and LightRpHud.externalSpeedometer == true and claims.speedometer == false)

    -- reset goes back to the file's values
    net["op77_speedometer:config"]({ reset = true })
    assert(exportsMap.getConfig().units == "kph" and exportsMap.getConfig().layout.scale == 0.6)

    -- LightRP asks after its own (re)start: answered
    local before = #stateEvents()
    TriggerEvent("op77_speedometer:query")
    assert(#stateEvents() == before + 1 and LightRpHud.externalSpeedometer == true)

    -- the speedometer stops: LightRP takes the vehicle readout back
    for _, fn in ipairs(handlers.onClientResourceStop) do fn("op77_speedometer") end
    assert(LightRpHud.externalSpeedometer == false)
    print("PASS client + LightRP handshake")
end

-- ── LightRP sampler: no cluster while the speedometer runs ──
do
    local sent = {}
    LightRpUi = { send = function(_, view) sent[#sent + 1] = view end }
    local threads = {}
    CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
    Open77 = {
        vehicles = { getPlayerSeat = function() return { vehicleId = 7, seat = "seat_front_left" } end,
            get = function() return { record = "Vehicle.v_x", speed = 10, gear = 2, health = 1 } end },
    }
    LightRpHud.externalSpeedometer = true
    LightRpHud.start()
    assert(coroutine.resume(threads[#threads]))
    assert(sent[#sent].vehicle.active == false, "cluster stands down")
    LightRpHud.externalSpeedometer = false
    assert(coroutine.resume(threads[#threads]))
    assert(sent[#sent].vehicle.active == true and sent[#sent].vehicle.gear == "2", "cluster back")
    print("PASS LightRP cluster")
end
