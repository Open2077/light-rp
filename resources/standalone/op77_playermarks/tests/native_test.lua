-- op77_playermarks on a client with the native nameplate drawer (Open77.nameplates.style):
-- the theme, no page, each player's label and hidden state through Open77.nameplates.set,
-- the exports, world re-entry, stop, open77_nameplates standing down, and the fallbacks to
-- the page. Run from the resource folder with any Lua 5.4.
local S -- the stubbed host of the current boot

local function boot(options)
    options = options or {}
    S = {
        styles = {}, renders = {}, sets = {}, removes = {}, clears = 0, resets = 0,
        pages = 0, anchorsCreated = 0, logs = {}, handlers = {}, exported = {}, threads = {},
        nearby = {}, all = {}, localId = 3, mapHidden = {}, states = {},
        platform = { running = false, enabled = true, calls = {} },
        refuseSet = {}, styleRefusals = options.styleRefusals or {},
    }
    local nameplates = {
        set = function(pid, opts)
            assert(type(pid) == "number", "set takes the numeric player id")
            if S.refuseSet[pid] then return nil, S.refuseSet[pid] end
            local copy = {}
            for k, v in pairs(opts) do copy[k] = v end
            S.sets[#S.sets + 1] = { id = pid, opts = copy }
            S.states[pid] = copy
            return true
        end,
        remove = function(pid)
            S.removes[#S.removes + 1] = pid
            if S.states[pid] == nil then return nil, "not_found" end
            S.states[pid] = nil
            return true
        end,
        clear = function() S.clears = S.clears + 1; S.states = {}; return true end,
        render = function(on)
            S.renders[#S.renders + 1] = on
            if options.refuseRender then return nil, "nameplates_backend_unavailable" end
            return true
        end,
        resetStyle = function() S.resets = S.resets + 1; return true end,
        snapshot = function() return {} end,
        setTalking = function() return true end,
    }
    if options.style ~= false then
        nameplates.style = function(theme)
            local refusal = table.remove(S.styleRefusals, 1)
            if refusal then return nil, refusal end
            S.styles[#S.styles + 1] = theme
            return true
        end
    end
    _G.Open77 = {
        players = {
            nearby = function(radius, opts)
                assert(radius > 1000 and opts.includeSelf == false and opts.limit == nil, "every streamed player, no cap")
                return S.nearby
            end,
            all = function() return S.all end,
            localId = function() return S.localId end,
            entity = function() return "1001" end,
        },
        anchors = {
            create = function() S.anchorsCreated = S.anchorsCreated + 1; return 1 end,
            update = function() return true end, remove = function() return true end, clear = function() end,
        },
        voice = { talkers = function() return {} end },
        nameplates = nameplates,
    }
    _G.WebUI = { create = function() S.pages = S.pages + 1; return { on = function() end, send = function() end } end }
    _G.GetResourceState = function(name)
        if name == "op77_map3d" then return "running" end
        if name == "open77_nameplates" then return S.platform.running and "running" or "missing" end
        return "missing"
    end
    _G.exports = setmetatable({
        op77_map3d = { arePlayerDotsHidden = function(_, pid) return S.mapHidden[tonumber(pid)] == true end },
        open77_nameplates = {
            isEnabled = function() return S.platform.enabled end,
            setEnabled = function(_, on)
                S.platform.enabled = on ~= false
                S.platform.calls[#S.platform.calls + 1] = on
                return true
            end,
        },
    }, { __call = function(_, name, fn) S.exported[name] = fn end })
    _G.AddEventHandler = function(name, fn) S.handlers[name] = fn end
    _G.CreateThread = function(fn) S.threads[#S.threads + 1] = fn end
    _G.Wait = function() end
    _G.GetCurrentResourceName = function() return "op77_playermarks" end
    _G.GetInvokingResource = function() return "op77_lightrp" end
    _G.print = function(text) S.logs[#S.logs + 1] = tostring(text) end
    dofile("shared/config.lua")
    if options.config then options.config(PlayerMarksConfig) end
    dofile("client/main.lua")
    return PlayerMarks
end

local function setsSince(n) return #S.sets - n end
local function last() return S.sets[#S.sets] end
local function logged(pattern)
    for _, line in ipairs(S.logs) do if line:find(pattern) then return true end end
    return false
end

-- ---------------------------------------------------------------------------------------
-- Start: the Light RP theme, the drawer on, no page.
local PM = boot()
S.nearby = {
    { playerId = 7, isLocal = false, name = "  Archer Hella " },
    { playerId = 8, isLocal = false },
    { playerId = 3, isLocal = true, name = "Me" },
}
S.all = { 3, 7, 8, 9 }
S.handlers.onClientResourceStart("op77_playermarks")
assert(#S.styles == 1, "the theme is set once at start")
assert(S.renders[1] == true and #S.renders == 1, "the drawer is turned on")
assert(S.pages == 0 and S.anchorsCreated == 0 and #S.threads == 1, "no page and no anchors with the native drawer, one sync loop")
local t = S.styles[1]
local expected = {
    font = "chakra", size = 13, letterSpacing = 0.08, uppercase = true,
    textColor = "#F2F3F5", textShadow = "#000000CC",
    shape = "chamfer", corner = 6, paddingX = 9.5, paddingY = 4,
    background = "#060608BD", backgroundTalking = "#241B00D1",
    border = "#FFCC0024", borderTalking = "#FFCC0073", borderWidth = 1,
    accent = "#FFCC00", accentSide = "left", accentWidth = 2,
    voice = "bars", voiceIdle = "#565A66", voiceIdleVisible = true,
    pin = 9, pinWidth = 1, tip = "diamond", tipSize = 7, tipGlow = true, tipPulse = true,
    nearScale = 1.0, farScale = 0.6, fadeFrom = 0.75, fade = 160,
    maxDistance = 35.0, occlusion = true, offset = 0.0, showDistance = false,
}
for key, value in pairs(expected) do
    assert(t[key] == value, ("theme %s: %s, expected %s"):format(key, tostring(t[key]), tostring(value)))
end
for key, value in pairs(t) do
    assert(expected[key] ~= nil, "unexpected theme key " .. key)
    if type(value) == "string" and value:sub(1, 1) == "#" then
        assert(value:match("^#%x%x%x%x%x%x$") or value:match("^#%x%x%x%x%x%x%x%x$"), "colour " .. key)
    end
end

-- Each other player's label, never yourself; a player never seen with a body and without a
-- character name keeps the drawer's default (no override).
assert(S.states[7] and S.states[7].label == "[7] Archer Hella" and S.states[7].visible == true)
assert(S.states[8] and S.states[8].label == "[8]")
assert(S.states[3] == nil and S.states[9] == nil)
assert(S.states[7].color == nil and S.states[7].maxDistance == nil, "colour and range stay the theme's")

-- Steady: nothing to call.
local before = #S.sets
PM.sync()
assert(setsSince(before) == 0 and #S.removes == 0, "steady: no native calls")

-- ---------------------------------------------------------------------------------------
-- setHidden: applied at once, per caller.
assert(S.exported.setHidden(true, { 8 }))
assert(S.states[8].visible == false and S.states[8].label == nil, "player 8 hidden at once")
assert(S.exported.arePlatesHidden(8) and not S.exported.arePlatesHidden(7))
assert(S.exported.setHidden(true))
assert(S.renders[#S.renders] == false, "everyone hidden: the drawer is off")
assert(S.states[7].visible == false and S.states[9] and S.states[9].visible == false,
    "and every player of the session is hidden too, the one without a body here included")
_G.GetInvokingResource = function() return "other" end
assert(S.exported.setHidden(false), "another caller's false does not lift op77_lightrp's hide")
assert(S.states[7].visible == false)
_G.GetInvokingResource = function() return "op77_lightrp" end
assert(S.exported.setHidden(false))
assert(S.renders[#S.renders] == true, "shown again: the drawer is back on")
assert(S.states[7].label == "[7] Archer Hella" and S.states[8].label == "[8]" and S.states[9] == nil,
    "labels back; the player without a body is the drawer's default again")
-- A caller that stops takes its hide with it, at once.
assert(S.exported.setHidden(true, { 7 }))
assert(S.states[7].visible == false)
S.handlers.onClientResourceStop("op77_lightrp")
assert(S.states[7].visible == true, "the caller stopped: its hide went with it")

-- An id hidden before this client lists the player: hidden from the start.
assert(S.exported.setHidden(true, { 12 }))
assert(S.states[12] and S.states[12].visible == false)
assert(S.exported.setHidden(false))
assert(S.states[12] == nil, "not in the session: the override goes")

-- ---------------------------------------------------------------------------------------
-- setNames: the characters' names, even for a player whose body is not here yet.
assert(S.exported.setNames({ [7] = "Jake Rob", [9] = "Vik Vektor" }))
assert(S.states[7].label == "[7] Jake Rob" and S.states[9].label == "[9] Vik Vektor")
assert(S.exported.setNames(nil))
assert(S.states[7].label == "[7] Archer Hella" and S.states[9] == nil)

-- A name with a control character, and one cut by nameMax inside a UTF-8 sequence.
S.nearby[2] = { playerId = 8, isLocal = false, name = "Ana\tBel" }
PM.sync()
assert(S.states[8].label == "[8] Ana Bel", S.states[8].label)
S.nearby[2] = { playerId = 8, isLocal = false, name = string.rep("a", 23) .. "\195\169z" }
PM.sync()
assert(S.states[8].label == "[8] " .. string.rep("a", 23), "the broken UTF-8 tail is dropped: " .. S.states[8].label)

-- op77_map3d hides a player (a chase runner).
S.mapHidden[8] = true
PM.sync()
assert(S.states[8].visible == false)
S.mapHidden[8] = nil
PM.sync()
assert(S.states[8].visible == true)

-- A player who leaves the session loses the override.
S.nearby = { S.nearby[1] }
S.all = { 3, 7 }
PM.sync()
assert(S.states[8] == nil and S.removes[#S.removes] == 8)

-- A plate another resource owns: said once, tried again on the next sync.
S.nearby[2] = { playerId = 8, isLocal = false, name = "B" }
S.all = { 3, 7, 8 }
S.refuseSet[8] = "owned_by_another_resource"
PM.sync()
PM.sync()
assert(S.states[8] == nil and logged("owned_by_another_resource"))
S.refuseSet[8] = nil
PM.sync()
assert(S.states[8] and S.states[8].label == "[8] B", "claimed once the other resource let go")

-- ---------------------------------------------------------------------------------------
-- World re-entry: the theme and the drawer asked again, every plate set again.
local styles, renders = #S.styles, #S.renders
before = #S.sets
S.handlers["open77:worldReady"]()
assert(#S.styles == styles + 1 and S.renders[#S.renders] == true and #S.renders == renders + 1)
assert(setsSince(before) == 2, "both plates set again")

-- open77_nameplates running too: asked to stand down, given back on stop.
S.platform.running = true
PM.sync()
assert(S.platform.calls[1] == false and S.platform.enabled == false)
PM.sync()
assert(#S.platform.calls == 1, "asked once")
S.handlers.onClientResourceStop("op77_playermarks")
assert(S.clears == 1, "stop: the overrides and the render request released")
assert(S.platform.calls[2] == true and S.platform.enabled == true, "open77_nameplates given back")
assert(PM.native.on == false)

-- open77_nameplates already off by someone else: not ours to give back.
boot()
S.platform.running, S.platform.enabled = true, false
S.handlers.onClientResourceStart("op77_playermarks")
S.handlers.onClientResourceStop("op77_playermarks")
assert(#S.platform.calls == 0)

-- ---------------------------------------------------------------------------------------
-- Fallbacks.
-- A theme key this drawer does not know costs only that key.
boot({ styleRefusals = { "unknown_style_key:tipPulse" } })
S.handlers.onClientResourceStart("op77_playermarks")
assert(#S.styles == 1 and S.styles[1].tipPulse == nil and S.styles[1].accent == "#FFCC00" and S.pages == 0)
assert(logged("tipPulse"))
-- A theme refused for another reason: the page.
boot({ styleRefusals = { "permission_denied:ui.nameplates" } })
S.handlers.onClientResourceStart("op77_playermarks")
assert(#S.styles == 0 and #S.renders == 0 and #S.threads == 3, "no render; the page's three threads")
S.threads[1]()
assert(S.pages == 1 and PlayerMarks.native.on == false, "the page")
-- The drawer refused: the theme withdrawn, the page.
boot({ refuseRender = true })
S.handlers.onClientResourceStart("op77_playermarks")
assert(PlayerMarks.native.on == false and S.resets == 1 and #S.threads == 3)
-- An older client (no style) and native = false: the page, untouched.
boot({ style = false })
S.handlers.onClientResourceStart("op77_playermarks")
assert(PlayerMarks.native.on == false and #S.renders == 0 and #S.threads == 3)
boot({ config = function(c) c.native = false end })
S.handlers.onClientResourceStart("op77_playermarks")
assert(PlayerMarks.native.on == false and #S.styles == 0 and #S.renders == 0 and #S.threads == 3)

io.write("native_test: ok\n")
