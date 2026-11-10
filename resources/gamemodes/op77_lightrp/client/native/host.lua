-- The NativeUI side of the Light RP interface: every HUD (what the player reads while
-- playing: vitals, hotbar, vehicle, weapon, crew, notices, work orders, missions...) is a
-- NativeUI document drawn on the game's own device, not a part of the WebUI page any
-- more. The page (web/, React) keeps the menus and the dialogs.
--
-- Nothing changes for the rest of the framework: the modules still call LightRpUi.send
-- and the server still pushes state patches. This host listens to the same traffic
-- (client/core/ui.lua hands every send and every patch to it) and gives each HUD module:
--
--   N.on(pageEvent, fn(payload))      a page event, as the React page received it
--   N.onState(key, fn(value, state))  a top-level state key changed (N.state is the merged copy)
--   N.onShell(fn(shell))              whether the HUD may show at all (see `shell` below)
--   N.create(spec)                    Open77.ui.create with this resource's fonts and error log
--   N.patch(doc, model, values)       doc:merge of only the fields that changed
--   N.icon(name)                      the 24 x 24 path of a page icon (client/native/icons.lua)
--
-- A module is one file in client/native/ that registers itself at load; N.start() (from
-- client/main.lua, once the page exists) creates the documents.
local N = { state = {}, hud = {}, shell = { ready = false, hidden = true, quiet = false }, docs = {} }
LightRpNative = N

local E = LightRpEvents
local pageHandlers, stateHandlers, shellHandlers, starters = {}, {}, {}, {}
local started = false

local function log(text) print("[lightrp] native: " .. tostring(text)) end
N.log = log

function N.available()
    return type(Open77.ui) == "table" and type(Open77.ui.create) == "function"
end

function N.on(name, fn)
    local list = pageHandlers[name]
    if not list then list = {}; pageHandlers[name] = list end
    list[#list + 1] = fn
end
function N.onState(key, fn)
    local list = stateHandlers[key]
    if not list then list = {}; stateHandlers[key] = list end
    list[#list + 1] = fn
end
function N.onShell(fn) shellHandlers[#shellHandlers + 1] = fn end
--- Runs when the documents may be created (and at once when they already are).
function N.onStart(fn)
    starters[#starters + 1] = fn
    if started then fn() end
end

local function call(fn, ...)
    local ok, why = pcall(fn, ...)
    if not ok then log("handler failed: " .. tostring(why)) end
end

--- Every LightRpUi.send, whether the page is ready or not.
function N.page(name, payload)
    if name == E.page.hud and type(payload) == "table" then N.hud = payload end
    local list = pageHandlers[name]
    if not list then return end
    for i = 1, #list do call(list[i], payload) end
end

--- Every state patch (the same shallow merge as the page's store).
function N.patchState(patch)
    if type(patch) ~= "table" then return end
    for key, value in pairs(patch) do N.state[key] = value end
    for key, value in pairs(patch) do
        local list = stateHandlers[key]
        if list then for i = 1, #list do call(list[i], value, N.state) end end
    end
end

-- ---- values ------------------------------------------------------------------------
local function same(a, b, depth)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" or depth > 6 then return false end
    for k, v in pairs(a) do if not same(v, b[k], depth + 1) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
N.same = function(a, b) return same(a, b, 0) end

local sent = {}
--- doc:merge(model, values) of the fields that differ from what this document was last given.
function N.patch(doc, model, values)
    if not doc then return end
    local key = tostring(doc:id()) .. ":" .. model
    local last = sent[key]
    if not last then last = {}; sent[key] = last end
    local changed, any = {}, false
    for k, v in pairs(values) do
        if not same(last[k], v, 0) then changed[k] = v; last[k] = v; any = true end
    end
    if any then doc:merge(model, changed) end
end
function N.forget(doc, model) if doc then sent[tostring(doc:id()) .. ":" .. model] = nil end end

function N.icon(name)
    return LightRpIcons and (LightRpIcons[name] or LightRpIcons.package) or ""
end
function N.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function N.percent(value, max)
    value, max = tonumber(value), tonumber(max) or 100
    if not value or value ~= value or max <= 0 then return 0 end
    return N.clamp(value / max * 100, 0, 100)
end
function N.round(v) return math.floor((tonumber(v) or 0) + 0.5) end
--- mm:ss of a duration in milliseconds.
function N.clock(ms)
    local total = math.max(0, math.floor((tonumber(ms) or 0) / 1000))
    return ("%02d:%02d"):format(total // 60, total % 60)
end
function N.now() return GetGameTimer and GetGameTimer() or 0 end

-- ---- documents ---------------------------------------------------------------------
local FONTS = {
    { "ui/native/fonts/share-tech-mono-400.ttf", "Share Tech Mono" },
    { "ui/native/fonts/zen-dots-400.ttf", "Zen Dots" },
}
local fontsLoaded = false
local function loadFonts()
    if fontsLoaded then return end
    fontsLoaded = true
    for _, font in ipairs(FONTS) do
        local ok, done, why = pcall(Open77.ui.loadFont, font[1], font[2], false)
        if not ok or not done then log("font " .. font[1] .. " not loaded: " .. tostring(ok and why or done)) end
    end
end

--- Open77.ui.create for a HUD document: layer "hud" unless told otherwise, errors logged.
function N.create(spec)
    if not N.available() then return nil, "nativeui_unavailable" end
    loadFonts()
    spec.layer = spec.layer or "hud"
    -- the HUD lab draws over the pre-game shell, which owns the system layer
    if LightRpNativeLab and LightRpNativeLab.layer then spec.layer = LightRpNativeLab.layer end
    if spec.visible == nil then spec.visible = true end
    local doc, why = Open77.ui.create(spec)
    if not doc then
        log("document " .. tostring(spec.document) .. " refused: " .. tostring(why))
        return nil, why
    end
    doc:onEvent("error", function(name, detail)
        log(tostring(spec.document) .. " " .. tostring(name) .. ": " .. tostring(detail and detail.message))
    end)
    N.docs[#N.docs + 1] = doc
    return doc
end

-- ---- the shell: may the HUD show? -----------------------------------------------------
-- ready   the first HUD sample is in and an active character is playing
-- hidden  another interface owns the screen: NativeUI draws above every WebUI page, so
--         the HUD steps aside under the F1 menu, a dialog, the phone, the pause menu
--         (anything holding the cursor), the vehicle workshop and the table games
-- quiet   the inventory is open (the page used to fade the HUD under it)
local dialogsOpen, covers = {}, {}
local function anyDialog()
    for _, open in pairs(dialogsOpen) do if open then return true end end
    return false
end
--- A module that covers the world (customization, a table game) hides the HUD while it does.
function N.cover(name, active)
    covers[name] = active == true or nil
end
local function computeShell()
    local character = N.state.character
    local tutorial = N.state.tutorial
    local active = type(character) == "table" and character.status == "active"
    local intro = type(tutorial) == "table" and tutorial.active == true and (tutorial.step == "intro" or tutorial.dialogue ~= nil and tutorial.dialogue ~= false)
    local ready = N.hud.ready == true and active and not intro
    local captured = false
    if type(Open77.input) == "table" and type(Open77.input.isCaptured) == "function" then
        local ok, _, cursor = pcall(Open77.input.isCaptured)
        captured = ok and cursor == true
    end
    -- the HUD lab (tools/native-lab) runs without a session, under the shell's cursor
    if LightRpNativeLab and LightRpNativeLab.ignoreCapture then captured = false end
    local ui = LightRpUi
    local hidden = captured or (ui and ui.menuOpen == true) or anyDialog() or next(covers) ~= nil
        or (ui and type(ui.loadingScreen) == "function" and ui.loadingScreen() == true)
    return ready, hidden == true, dialogsOpen.inventory == true
end
local function refreshShell()
    local ready, hidden, quiet = computeShell()
    local s = N.shell
    if s.ready == ready and s.hidden == hidden and s.quiet == quiet then return end
    s.ready, s.hidden, s.quiet = ready, hidden, quiet
    for i = 1, #shellHandlers do call(shellHandlers[i], s) end
end
N.refreshShell = refreshShell

--- The page reported a dialog opening or closing (client/core/ui.lua, dialogState).
function N.dialog(kind, open)
    dialogsOpen[kind] = open == true or nil
    refreshShell()
end

function N.start()
    if started or not N.available() then
        if not N.available() then log("NativeUI is not available on this client: the HUD is not drawn") end
        return started
    end
    started = true
    for i = 1, #starters do call(starters[i]) end
    CreateThread(function()
        while true do
            refreshShell()
            Wait(120)
        end
    end)
    log(("%d document(s)"):format(#N.docs))
    return true
end
