-- op77_speedometer: the shared logic, the NativeUI adapter (client/ui.lua: digits, ticks,
-- scale, shake, the theme layer, the names the document binds), the client with the host
-- stubbed (samples -> page events -> the document's model), and the LightRP handshake (its
-- HUD sampler stands its cluster down). Run from the resource folder:
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

-- ── the NativeUI adapter: pure parts, and the document against its model ──
local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("a")
    f:close()
    return text
end
local clock = 0
function GetGameTimer() return clock end
dofile("client/ui.lua")
do
    local U = SpeedoUi
    local digits, lead = U.number(63)
    assert(digits == "063" and lead[1] and not lead[2] and not lead[3])
    digits, lead = U.number(0); assert(digits == "000" and lead[1] and lead[2] and not lead[3], "the last zero is never a leading one")
    assert(U.number(1234) == "999" and U.number(62.5) == "063" and U.number(5, true) == "888")
    local on, off = U.glyph("8")
    assert(select(2, on:gsub("M", "")) == 7 and off == "M0 0", "8 lights the seven segments")
    on, off = U.glyph("7")
    assert(select(2, on:gsub("M", "")) == 3 and select(2, off:gsub("M", "")) == 4)

    local ticks = U.ticks("kph", 240)
    assert(#ticks == 13 and ticks[1].x == "0.00dp" and ticks[1].major and not ticks[2].major and ticks[4].major and ticks[13].x == "420.00dp")
    assert(#U.ticks("mph", 150) == 16 and U.ticks("mph", 150)[4].major)

    -- the display shrinks rather than run into the holo GPS on a narrow screen
    local l = S.pageConfig(SpeedoConfig).layout
    local scale, right, bottom = U.scale(l, 1920)
    assert(near(scale, 0.6) and right == 36 and bottom == 146)
    assert(near(U.scale(l, 1440), 0.6), "4:3 still fits")
    assert(near(U.scale(l, 1350), (1350 - 36 - (675 + 390 + 16)) / 420), "5:4 shrinks")
    assert(near(U.scale(l, 1100), 0.45), "never under minScale")
    assert(near(U.scale(S.pageConfig(S.merge(SpeedoConfig, { layout = { avoidHoloGps = false } })).layout, 1100), 0.6))
    assert(near(U.scale(S.pageConfig(S.merge(SpeedoConfig, { layout = { bottom = 400 } })).layout, 1100), 0.6), "above the GPS: no need")

    local shake = S.pageConfig(SpeedoConfig).shake
    local sx, sy = U.shake(shake, 100, 1.5); assert(sx == 0 and sy == 0, "no shake under fromKph")
    sx, sy = U.shake(shake, 400, 1.5)
    assert(near(sx, 1.6 * (math.sin(1.5 * 41.3) * 0.6 + math.sin(1.5 * 17.9) * 0.4)) and math.abs(sy) <= 1.6)
    shake.enabled = false; assert(U.shake(shake, 400, 1.5) == 0)

    -- the theme layer: only the rules that hold a theme colour, alpha kept, the gear on its own lines
    local sheet = readFile("ui/speedometer.rcss")
    assert(U.themeRcss(sheet, S.pageConfig(SpeedoConfig).theme) == nil, "nothing for the sheet's own colours")
    local layer = U.themeRcss(sheet, { accent = "#3FE0D0", core = "#FFF7DA", gear = "#FFCC00", warn = "#FF3B3B", cool = "#7FD8FF" })
    assert(layer:find(".rpm-label {", 1, true) and layer:find("color: #3fe0d0bf", 1, true), "accent swapped, alpha kept")
    assert(not layer:find(".gear", 1, true) and not layer:find("#ffcc00", 1, true), "the gear keeps its own colour")
    assert(not layer:find("@keyframes", 1, true) and not layer:find("/*", 1, true) and not layer:find(".dg1", 1, true))
    layer = U.themeRcss(sheet, { accent = "#FFCC00", core = "#FFF7DA", gear = "#FF00FF", warn = "#FF3B3B", cool = "#7FD8FF" })
    assert(layer:find(".gear-label { font-size: 22dp; line-height: 30dp; letter-spacing: 0.1em; color: #ff00ffe6; }", 1, true), layer)
    assert(select(2, layer:gsub("\n", "")) == 2, "three gear rules, nothing else")
    for line in sheet:gmatch("[^\r\n]+") do
        if line:find("@keyframes", 1, true) then assert(not line:find("#%x%x%x%x%x%x"), "no colour in keyframes: " .. line) end
    end
    assert(U.filters({ accent = "#FFCC00", glow = 1, opacity = 1, scanlines = true }, 0.6)
        == "drop-shadow(#ffcc00d9 0dp 0dp 1.20dp) drop-shadow(#ffcc006b 0dp 0dp 5.40dp) scanlines(0.3 2.00 0 0)")
    assert(U.filters({ glow = 0, opacity = 0.5, scanlines = false }, 1) == "opacity(0.50)")

    -- every name the document binds exists in the model (a missing one is an RmlUi error on every frame)
    local model = U.defaults()
    local rml = readFile("ui/speedometer.rml")
    local alias = { ["true"] = true, ["false"] = true }
    for a in rml:gmatch('data%-for="%s*([%a_][%w_]*)%s*:') do alias[a] = true end
    local function check(expr)
        expr = expr:gsub("'[^']*'", ""):gsub("&amp;", " "):gsub("&[lg]t;", " "):gsub("%.[%a_][%w_]*", "")
        for id in expr:gmatch("[%a_][%w_]*") do assert(alias[id] or model[id] ~= nil, "the document binds an unknown name: " .. id) end
    end
    local bound = 0
    for attribute, expr in rml:gmatch('data%-([%w-]+)="([^"]*)"') do
        if attribute ~= "model" then check((expr:gsub("^%s*[%a_][%w_]*%s*:", ""))); bound = bound + 1 end
    end
    for expr in rml:gmatch("{{(.-)}}") do check(expr); bound = bound + 1 end
    -- the data-for element carries nothing else: a binding on it is evaluated once more for a
    -- removed row when the array shrinks ("Could not get value from data variable")
    for tag in rml:gmatch("<[^>]*data%-for=[^>]*>") do
        local _, n = tag:gsub("data%-[%w-]+=", "")
        assert(n == 1, "a binding on a data-for element: " .. tag)
    end
    assert(bound > 100 and rml:find('data-model="sp"', 1, true))
    print("PASS NativeUI adapter")
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
    local function tick(n)
        for _ = 1, n or 1 do
            clock = clock + 50
            for i = 1, #threads do
                local co = threads[i]
                if co and coroutine.status(co) == "suspended" then
                    local ok, err = coroutine.resume(co)
                    assert(ok, err)
                end
            end
        end
    end
    -- NativeUI: a document that records what it is given; a merge may only name model fields
    local docs, fonts = {}, {}
    local screen = { width = 2560, height = 1440 }
    local function fakeDocument(spec)
        local d = { spec = spec, model = {}, events = {}, styles = {}, sheets = {}, destroyed = false }
        for k, v in pairs(spec.models.sp) do d.model[k] = v end
        function d:onEvent(kind, fn) self.events[kind] = fn end
        function d:merge(name, fields)
            assert(name == "sp" and not self.destroyed)
            for k, v in pairs(fields) do assert(spec.models.sp[k] ~= nil, "merge of an unknown field: " .. tostring(k)); self.model[k] = v end
        end
        function d:style(selector, prop, value)
            local t = self.styles[selector] or {}
            self.styles[selector] = t
            if type(prop) == "table" then for k, v in pairs(prop) do t[k] = v end else t[prop] = value end
        end
        function d:stylesheet(name, rcss) self.sheets[name] = rcss end
        function d:state() return screen end
        function d:destroy() self.destroyed = true end
        docs[#docs + 1] = d
        return d
    end
    function LoadResourceFile(resource, path) assert(resource == "op77_speedometer"); return readFile(path) end
    -- what client/main.lua sends through the page API is recorded on the way to the adapter
    local createPage = SpeedoUi.create
    SpeedoUi.create = function(options)
        local page, why = createPage(options)
        if not page then return nil, why end
        local s = { options = options, sent = {}, doc = docs[#docs], page = page }
        local send = page.send
        page.send = function(self, name, payload) s.sent[#s.sent + 1] = { name = name, payload = payload }; return send(self, name, payload) end
        surfaces[#surfaces + 1] = s
        return page
    end
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
        ui = {
            create = function(spec) return fakeDocument(spec) end,
            loadFont = function(path, family) fonts[#fonts + 1] = { path, family }; return true end,
        },
    }
    local function last(s, name)
        for i = #s.sent, 1, -1 do if s.sent[i].name == name then return s.sent[i].payload, i end end
    end
    local function count(s, name) local n = 0 for _, m in ipairs(s.sent) do if m.name == name then n = n + 1 end end return n end
    local function stateEvents() local t = {} for _, e in ipairs(events) do if e.name == "op77_speedometer:state" then t[#t + 1] = e.args[1].active end end return t end

    -- LightRP's HUD sampler in the same event bus (its own globals stubbed)
    LightRpConfig = { voice = { default = "normal", ranges = { normal = 20 } }, vehicles = { catalog = {} }, baseRecord = function(record) return record end }
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
    assert(#surfaces == 1 and #docs == 1, "one document")
    local s1 = surfaces[1]
    local doc = s1.doc
    local m = doc.model
    assert(s1.options.fps == 30 and s1.options.zIndex == 710)
    assert(doc.spec.document == "ui/speedometer.rml" and doc.spec.layer == "hud" and doc.spec.zIndex == 710 and doc.spec.visible == true)
    assert(fonts[1][1] == "ui/fonts/share-tech-mono-400.ttf" and fonts[1][2] == "Share Tech Mono")
    assert(#readFile(fonts[1][1]) > 10000, "the font ships with the resource")
    doc.events.loaded()
    assert(last(s1, "speedo:config").layout.scale == 0.6)
    -- placement and tilt from the config, the bloom at the display's scale, no theme layer for the defaults
    local stage = doc.styles["#stage"]
    assert(stage.right == "36.00dp" and stage.bottom == "146.00dp" and stage.transform == "scale(0.6000)")
    assert(doc.styles["#plane"].transform == "rotateX(8.00deg) rotateY(-16.00deg)")
    assert(doc.styles["#holo"].filter:find("drop-shadow(#ffcc00d9 0dp 0dp 1.20dp)", 1, true) and doc.sheets.theme == nil)
    assert(m.unit == "KPH" and #m.ticks == 13 and m.zeros == "dim" and not m.live)

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
    -- the document: unfolding, with the self-test (888, every tag and gauge cell)
    local U = SpeedoUi
    assert(m.live and m.enter == 1 and not m.leaving and m.name == "QUADRA TYPE66" and m.hasName)
    tick(2)
    assert(m.d1on == U.glyph("8") and m.d3on == U.glyph("8") and m.tagHbk and m.tagAbs and m.tagTcs and m.fuelLit == 10 and m.condLit == 10)
    assert(m.rpmLit > 0 and m.gear == "3" and m.pop == 0, "the strip sweeps; the first gear does not pop")
    tick(20)
    -- then the numbers, smoothed up to the sample
    assert(m.d1on == U.glyph("0") and m.lead1 and m.d2on == U.glyph("6") and not m.lead2 and m.d3on == U.glyph("3"), "063")
    assert(m.rpmLit == 15 and not m.shift and m.tagHbk and not m.tagAbs and not m.blinkAbs and not m.tagTcs)
    assert(m.fuelLit == 5 and not m.fuelNone and not m.fuelLow and m.condLit == 10 and not m.condLow)
    assert(m.lightsOn and not m.lightsCool and m.engineOn and not m.engineWarn and not m.tiresWarn and m.tires == "")
    assert(m.barFill == "scaleX(0.2625)" and m.barHead == "translateX(109.2dp)" and not m.over and not m.idle and m.shake == "none")
    -- a gear change pops, damage and flat tyres warn, the redline shifts, the shake starts
    car.gear = 4; car.rpm = 5900; car.health = 0.2; car.damage = { tires = 3 }; car.speed = 80
    tick(8)
    assert(m.gear == "4" and m.pop == 1 and m.engineWarn and not m.engineOn and m.condLow and m.tiresWarn and m.tires == "2")
    assert(m.shift and m.rpmLit >= 29 and m.over and m.shake ~= "none")
    car.gear = 3; car.rpm = 3000; car.health = 1; car.damage = nil; car.speed = 17.5
    tick(30)
    assert(m.pop == 2 and m.shake == "none" and not m.over and m.d2on == U.glyph("6"))
    -- the keyboard taken (chat): no handbrake read
    keyboard = true; tick(); assert(last(s1, "speedo:data").handbrake == false); keyboard = false
    keys.SPACE = false
    tick()
    assert(count(s1, "speedo:show") == 1, "shown once")

    -- a menu holds the cursor: hidden, back after
    cursor = true; tick()
    assert(count(s1, "speedo:hide") == 1)
    assert(m.covered and m.leaving and m.enter == 0, "stepped aside at once, folding")
    tick(10); assert(not m.live and not m.leaving, "folded away")
    cursor = false; tick()
    assert(count(s1, "speedo:show") == 2)
    assert(m.live and m.enter == 1 and not m.covered)
    tick(12)

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

    -- the server moves it: the same document, placed and scaled again, in the new unit
    local shows = count(s1, "speedo:show")
    net["op77_speedometer:config"]({ layout = { scale = 0.8, tilt = false, offsetX = 6 }, units = "mph" })
    tick()
    assert(#surfaces == 1 and not doc.destroyed and count(s1, "speedo:show") == shows, "no new document, no new unfold")
    assert(last(s1, "speedo:config").units == "mph" and near(last(s1, "speedo:data").speed, 17.5 * 2.236936))
    assert(doc.styles["#stage"].transform == "scale(0.8000)" and doc.styles["#stage"].right == "30.00dp")
    assert(doc.styles["#plane"].transform == "none" and doc.styles["#holo"].filter:find("0dp 0dp 1.60dp", 1, true))
    assert(m.unit == "MPH" and #m.ticks == 16)
    -- a theme is a stylesheet layer
    exportsMap.setConfig({ theme = { accent = "#3FE0D0", opacity = 0.5 } })
    tick()
    assert(#surfaces == 1 and last(s1, "speedo:config").theme.accent == "#3FE0D0")
    assert(doc.sheets.theme:find("#3fe0d0", 1, true) and doc.sheets.theme:find(".gear {", 1, true) == nil, "the gear stays yellow")
    assert(doc.styles["#holo"].filter:find("#3fe0d0d9", 1, true) and doc.styles["#holo"].filter:find("opacity(0.50)", 1, true))
    assert(doc.styles["#haze"].opacity == "0.50")
    -- a narrower screen: the display shrinks (read every two seconds)
    screen.width, screen.height = 1350, 1080
    tick(14)
    assert(doc.styles["#stage"].transform == ("scale(%.4f)"):format((1350 - 30 - (675 + 390 + 16)) / 420), doc.styles["#stage"].transform)
    screen.width, screen.height = 1920, 1080
    tick(14)
    assert(doc.styles["#stage"].transform == "scale(0.8000)")

    -- the document reloads (hot reload): everything is sent again, shown without the unfold
    assert(exportsMap.isShown() == true)
    doc.events.reloaded()
    assert(m.live and m.enter == 3 and m.name == "QUADRA TYPE66" and m.unit == "MPH")

    -- off: document gone, native speedometer and LightRP's cluster back
    exportsMap.setEnabled(false)
    tick()
    assert(doc.destroyed and #surfaces == 1 and exportsMap.isShown() == false)
    local st = stateEvents()
    assert(st[#st] == false and LightRpHud.externalSpeedometer == false)
    assert(claims.speedometer == true, "native claim released")
    exportsMap.setEnabled(true)
    tick()
    assert(#surfaces == 2 and not docs[2].destroyed and LightRpHud.externalSpeedometer == true and claims.speedometer == false)

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

    -- a client without NativeUI: one line, no display, nothing claimed, LightRP keeps its cluster
    Open77.ui = nil
    handlers, net, threads, exportsMap, serverEvents, events, claims = {}, {}, {}, {}, {}, {}, {}
    local printed = {}
    local realPrint = print
    print = function(text) printed[#printed + 1] = tostring(text) end
    dofile("client/main.lua")
    for _, fn in ipairs(handlers.onClientResourceStart) do fn("op77_speedometer") end
    tick(3)
    print = realPrint
    assert(#printed == 1 and printed[1]:find("NativeUI", 1, true), "one line")
    assert(#surfaces == 2 and #threads == 0 and next(claims) == nil and #serverEvents == 0)
    assert(events[1].name == "op77_speedometer:state" and events[1].args[1].active == false)
    assert(exportsMap.isShown() == false and exportsMap.setConfig({ units = "mph" }) == true)
    print("PASS without NativeUI")
end

-- ── LightRP sampler: no cluster while the speedometer runs ──
do
    local sent = {}
    LightRpUi = { send = function(_, view) sent[#sent + 1] = view end }
    LightRpWeaponHud = nil
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
