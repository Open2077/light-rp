-- op77_weaponhud: the shared logic, the NativeUI adapter (client/ui.lua: digits, cells, the
-- theme layer, the names the document binds), the client with the host stubbed (snapshot
-- rows -> page events -> the document's model: shots, reloads, switches), and the LightRP
-- handshake (its own readout stands down, the grenade chip lifts the HUD, RP names). Run
-- from the resource folder:
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
    -- arm cyberware: melee, a readable name, never an ammo counter
    local mantis = W.describe("Items.MantisBlades", nil, WeaponHudCatalogue)
    assert(mantis.melee and mantis.name == "MANTIS BLADES" and mantis.type == "ARM BLADES" and mantis.class == "BLADE", "mantis blades")
    local electric = W.describe("Items.AdvancedMantisBladesElectricLegendaryPlusPlus", nil, WeaponHudCatalogue)
    assert(electric.melee and electric.name == "ELECTRIC MANTIS BLADES", electric.name)
    assert(W.describe("x", { itemType = "ItemType.Cyb_NanoWires" }, {}).melee, "monowire by item type")
    assert(W.recordName("Items.SomeNewWeapon") == "SOME NEW WEAPON")
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

-- ── the NativeUI adapter: pure parts, and the document against its model ──
local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("a")
    f:close()
    return text
end
function GetGameTimer() return 0 end
dofile("client/ui.lua")
do
    local U = WeaponHudUi
    local s, lead = U.number(21)
    assert(s == "021" and lead[1] and not lead[2] and not lead[3])
    s, lead = U.number(0); assert(s == "000" and lead[1] and lead[2] and not lead[3], "the last zero is never a leading one")
    s, lead = U.number(1234); assert(s == "999" and not lead[1])
    assert(U.number(nil) == "---" and U.number("test") == "888")
    local on, off = U.glyph("8")
    assert(select(2, on:gsub("M", "")) == 7 and off == "M0 0", "8 lights the seven segments")
    on, off = U.glyph("1")
    assert(select(2, on:gsub("M", "")) == 2 and select(2, off:gsub("M", "")) == 5)
    assert(on:find("M67.89 7.70", 1, true), "segment b, slanted: " .. on)
    local count, per = U.cellLayout(21, 36); assert(count == 21 and per == 1)
    count, per = U.cellLayout(100, 36); assert(count == 34 and per == 3)
    assert(U.cellLayout(nil, 36) == 0 and U.cellLayout(0, 36) == 0)

    -- the theme layer: only the rules that hold a theme colour, alpha kept, nothing for the defaults
    local sheet = readFile("ui/weaponhud.rcss")
    assert(U.themeRcss(sheet, { accent = "#FFCC00", core = "#FFF7DA", warn = "#FF3B3B", cool = "#7FD8FF" }) == nil)
    local layer = U.themeRcss(sheet, { accent = "#3FE0D0", core = "#FFF7DA", warn = "#FF3B3B", cool = "#FFCC00" })
    assert(layer:find(".name-text {", 1, true) and layer:find("color: #3fe0d0eb", 1, true), "accent swapped, alpha kept")
    assert(layer:find(".badge.is-smart { color: #ffcc00; border-color: #ffcc00cc; }", 1, true), "cool swapped in one pass")
    assert(not layer:find("@keyframes", 1, true) and not layer:find("/*", 1, true) and not layer:find(".dg1", 1, true))
    for line in sheet:gmatch("[^\r\n]+") do
        if line:find("@keyframes", 1, true) then assert(not line:find("#%x%x%x%x%x%x"), "no colour in keyframes: " .. line) end
    end
    local holo, edge = U.filters({ accent = "#FFCC00", glow = 1, opacity = 1, scanlines = true }, 0.6)
    assert(holo == "drop-shadow(#ffcc00d9 0dp 0dp 1.20dp) drop-shadow(#ffcc006b 0dp 0dp 5.40dp) scanlines(0.3 2.00 0 0)", holo)
    assert(edge == "drop-shadow(#ffcc00cc 0dp 0dp 3.60dp)")
    assert(U.filters({ glow = 0, opacity = 1, scanlines = false }, 1) == "none")
    assert(U.filters({ glow = 0, opacity = 0.5, scanlines = false }, 1) == "opacity(0.50)")

    -- every name the document binds exists in the model (a missing one is an RmlUi error on every frame)
    local model = U.defaults()
    local rml = readFile("ui/weaponhud.rml")
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
    assert(bound > 40 and rml:find('data-model="wh"', 1, true))
    print("PASS NativeUI adapter")
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
    -- NativeUI: a document that records what it is given; a merge may only name model fields
    local docs, fonts = {}, {}
    local function fakeDocument(spec)
        local d = { spec = spec, model = {}, events = {}, styles = {}, sheets = {}, animations = {}, destroyed = false }
        for k, v in pairs(spec.models.wh) do d.model[k] = v end
        function d:onEvent(kind, fn) self.events[kind] = fn end
        function d:merge(name, fields)
            assert(name == "wh" and not self.destroyed)
            for k, v in pairs(fields) do assert(spec.models.wh[k] ~= nil, "merge of an unknown field: " .. tostring(k)); self.model[k] = v end
        end
        function d:style(selector, prop, value)
            local t = self.styles[selector] or {}
            self.styles[selector] = t
            if type(prop) == "table" then for k, v in pairs(prop) do t[k] = v end else t[prop] = value end
        end
        function d:stylesheet(name, rcss) self.sheets[name] = rcss end
        function d:animate(selector, anim) self.animations[#self.animations + 1] = { selector = selector, spec = anim } end
        function d:destroy() self.destroyed = true end
        docs[#docs + 1] = d
        return d
    end
    function LoadResourceFile(resource, path) assert(resource == "op77_weaponhud"); return readFile(path) end
    -- what client/main.lua sends through the page API is recorded on the way to the adapter
    local createPage = WeaponHudUi.create
    WeaponHudUi.create = function(options)
        local page, why = createPage(options)
        if not page then return nil, why end
        local s = { options = options, sent = {}, doc = docs[#docs], page = page }
        local send = page.send
        page.send = function(self, n, p) s.sent[#s.sent + 1] = { name = n, payload = p }; return send(self, n, p) end
        surfaces[#surfaces + 1] = s
        return page
    end
    -- the snapshot answers on the next tick, like the engine (rows, then completion)
    local inflight = {}
    Open77 = {
        hud = { setVisible = function(c, v) claims[c] = v; return true, v end },
        input = { isCaptured = function() return false, cursor end },
        character = { isArmed = function() return armed end },
        players = { isReloading = function() return reloadingNow end, isInVehicle = function() return inVehicle end },
        data = { weapon = function(record) if record == "Items.Preset_Lexington_Default" then return { displayName = "Lexington" } end return nil, "record_unknown" end },
        weapons = { snapshot = function() requests = requests + 1; inflight[#inflight + 1] = requests; return requests end },
        ui = {
            create = function(spec) return fakeDocument(spec) end,
            loadFont = function(path, family) fonts[#fonts + 1] = { path, family }; return true end,
        },
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
    local doc = s and s.doc
    assert(doc and #docs == 1 and s.options.zIndex == 705)
    assert(doc.spec.document == "ui/weaponhud.rml" and doc.spec.layer == "hud" and doc.spec.zIndex == 705 and doc.spec.visible == true)
    assert(fonts[1][1] == "ui/fonts/share-tech-mono-400.ttf" and fonts[1][2] == "Share Tech Mono")
    assert(#readFile(fonts[1][1]) > 10000, "the font ships with the resource")
    doc.events.loaded()
    assert(last(s, "weapon:config").layout.left == 36)
    -- placement and tilt from the config, the bloom at the display's scale, no theme layer for the defaults
    local stage = doc.styles["#stage"]
    assert(stage.left == "36.00dp" and stage.bottom == "142.00dp" and stage.transform == "scale(0.6000)")
    assert(doc.styles["#plane"].transform == "rotateX(8.00deg) rotateY(16.00deg)")
    assert(doc.styles["#holo"].filter:find("drop-shadow(#ffcc00d9 0dp 0dp 1.20dp)", 1, true) and doc.sheets.theme == nil)
    assert(doc.model.live == false and doc.model.zeros == "dim")

    -- LightRP's sampler: its readout stands down, labels and lift go to the HUD
    local hudThreadCount = #threads
    LightRpHud.start()
    tick()
    assert(hudViews[#hudViews].weapon.active == false, "no legacy readout")
    assert(last(s, "weapon:inset").px == 0 and #doc.animations == 0)
    chip = true; tick()
    assert(last(s, "weapon:inset").px == 30, "lifted above the grenade chip")
    local lift = doc.animations[#doc.animations]
    assert(lift.selector == "#lift" and lift.spec.to.y == -30 and lift.spec.duration == 0.3)

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
    -- the document: unfolding, with the self-test (888, every cell)
    local m = doc.model
    local eight, one, zero, two = WeaponHudUi.glyph("8"), WeaponHudUi.glyph("1"), WeaponHudUi.glyph("0"), WeaponHudUi.glyph("2")
    assert(m.live and m.enter == 1 and m.test and not m.leaving and m.name == "SERVICE PISTOL")
    assert(m.klass == "POWER" and m.hasKlass and not m.klassSmart and m.kind == "HANDGUN" and m.hasKind)
    assert(#m.cells == 21 and m.d1on == eight and m.d3on == eight)
    tick(3)
    assert(not m.test and m.d1on == zero and m.lead1 and m.d2on == two and not m.lead2 and m.d3on == one, "021 after the self-test")
    assert(m.cells[21].on and m.cells[21].tip and m.cells[20].on and not m.cells[20].tip)
    assert(m.reserve == "120" and not m.reserveOut and m.tag == "" and m.fill == "scaleX(1.0000)" and not m.melee)

    -- three shots between two samples
    lexington(18); step()
    assert(last(s, "weapon:data").shots == 3 and count(s, "weapon:show") == 1)
    assert(m.hit == 1 and m.kick == 1 and m.e1 == 1 and m.e2 == 1 and m.e3 == 1, "digits flicker, the plate kicks, three cells fly off")
    assert(m.cells[18].tip and not m.cells[19].on and m.d2on == one and m.fill == "scaleX(0.8571)")
    assert(m.ew == "16.67dp" and m.e1x == "354.00dp", "the ejected cells sit where cells 19-21 were: " .. m.e1x)
    lexington(17); step(); assert(m.hit == 2 and m.kick == 2 and m.e1 == 2 and m.e2 == 1, "the next shot restarts them")
    -- low, then empty
    lexington(4); step(); assert(last(s, "weapon:data").low)
    assert(m.low and m.tag == "LOW AMMO" and m.tagKind == 0)
    lexington(0); step(); d = last(s, "weapon:data"); assert(d.empty and not d.low)
    assert(m.empty and not m.low and m.tag == "RELOAD" and m.tagKind == 1 and m.lead1 and m.lead2 and m.fill == "scaleX(0.0000)")
    -- reload: the flag, then the refill
    lexington(0, true); step(); assert(last(s, "weapon:data").reloading)
    assert(m.reloading and not m.empty and m.tag == "RELOADING" and m.tagKind == 2)
    reloadingNow = true; lexington(0); step(); assert(last(s, "weapon:data").reloading, "isReloading counts too")
    reloadingNow = false; lexington(21); step(); d = last(s, "weapon:data")
    assert(d.reloaded and d.magazine == 21 and d.shots == 0)
    assert(not m.reloading and m.cells[21].tip, "the cells refill at once (their sweep is the sheet's)")
    tick(8)
    assert(m.d2on == two and m.d3on == one and m.tag == "", "the count rolled up to 021")

    -- a menu takes the cursor: hidden; back after (a new unfold)
    cursor = true; step(); assert(count(s, "weapon:hide") == 1)
    assert(m.covered and m.leaving and m.enter == 0, "stepped aside at once, folding")
    tick(2); assert(not m.live and not m.leaving)
    cursor = false; step(); assert(count(s, "weapon:show") == 2)
    assert(m.live and m.enter == 1 and m.test)
    tick(); assert(not m.covered)

    -- switch weapons: a new unfold
    slots[1] = nil
    slots[2] = { "Items.Preset_Katana_Default", "0xBB", "true", "true", "false", "", "", "-1", "-1", "-1", "-1", "false" }
    step()
    show = last(s, "weapon:show")
    assert(count(s, "weapon:show") == 3 and show.class == "BLADE" and show.melee, show.name)
    assert(m.enter == 2 and m.test and #m.cells == 0, "a new unfold for the new weapon")
    tick(3)
    assert(m.melee and m.meleeClass == "BLADE" and m.reserve == "---" and m.tag == "" and m.d1on == WeaponHudUi.glyph("-"))

    -- holster
    armed = false; step(); assert(count(s, "weapon:hide") == 2)
    armed = true; step(); assert(count(s, "weapon:show") == 4)

    -- a scene hides it
    exportsMap.hide("cutscene"); step(); assert(count(s, "weapon:hide") == 3)
    exportsMap.show("cutscene"); step(); assert(count(s, "weapon:show") == 5)

    -- the server restyles: a theme is a stylesheet layer, a layout change moves the same document
    net["op77_weaponhud:config"]({ theme = { accent = "#3FE0D0" } }); tick()
    assert(#surfaces == 1 and last(s, "weapon:config").theme.accent == "#3FE0D0")
    assert(doc.sheets.theme:find("#3fe0d0", 1, true) and not doc.sheets.theme:find("#ffcc00", 1, true))
    assert(doc.styles["#holo"].filter:find("#3fe0d0d9", 1, true))
    exportsMap.setConfig({ layout = { scale = 0.8, tilt = false, offsetY = 10 }, theme = { opacity = 0.5 } }); tick()
    assert(#surfaces == 1 and not doc.destroyed)
    assert(doc.styles["#stage"].transform == "scale(0.8000)" and doc.styles["#stage"].bottom == "132.00dp")
    assert(doc.styles["#plane"].transform == "none" and doc.styles["#haze"].opacity == "0.50")
    assert(doc.styles["#holo"].filter:find("0dp 0dp 1.60dp", 1, true) and doc.styles["#holo"].filter:find("opacity(0.50)", 1, true))
    net["op77_weaponhud:config"]({ reset = true }); tick()
    assert(doc.sheets.theme == nil and doc.styles["#haze"].opacity == nil and doc.styles["#stage"].transform == "scale(0.6000)")

    -- the document reloads (hot reload): everything is sent again, shown without the unfold
    assert(exportsMap.isShown() == true)
    doc.events.reloaded()
    assert(doc.model.live and doc.model.enter == 3 and not doc.model.test and doc.model.name ~= "WEAPON")

    -- off: the document goes, LightRP's readout and the native HUD come back
    exportsMap.setEnabled(false); tick()
    assert(doc.destroyed and exportsMap.isShown() == false)
    assert(LightRpHud.externalWeaponHud == false and claims.weapon == true)
    tick(); assert(legacySamples > 0 and hudViews[#hudViews].weapon.active == true, "legacy readout back")
    exportsMap.setEnabled(true); tick()
    assert(LightRpHud.externalWeaponHud == true and #surfaces == 2 and not docs[2].destroyed)

    -- stops: LightRP takes over
    for _, fn in ipairs(handlers.onClientResourceStop) do fn("op77_weaponhud") end
    assert(LightRpHud.externalWeaponHud == false)
    print("PASS client + LightRP")

    -- a client without NativeUI: one line, no HUD, nothing claimed, LightRP keeps its readout
    Open77.ui = nil
    handlers, net, threads, exportsMap, events, claims = {}, {}, {}, {}, {}, {}
    local asked = requests
    local printed = {}
    local realPrint = print
    print = function(text) printed[#printed + 1] = tostring(text) end
    dofile("client/main.lua")
    for _, fn in ipairs(handlers.onClientResourceStart) do fn("op77_weaponhud") end
    tick(3)
    print = realPrint
    assert(#printed == 1 and printed[1]:find("NativeUI", 1, true), "one line")
    assert(#surfaces == 2 and #threads == 0 and next(claims) == nil and requests == asked)
    assert(events[1].name == "op77_weaponhud:state" and events[1].args[1].active == false)
    assert(exportsMap.isShown() == false and exportsMap.setConfig({ layout = { scale = 0.7 } }) == true)
    print("PASS without NativeUI")
end
