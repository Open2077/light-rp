-- The HUD lab: the real NativeUI documents of op77_lightrp (client/native, ui/native),
-- fed by scenes instead of a server. Built by tools/native-lab/build.py into a client
-- resource `lrp_hudlab` that runs without a session (see tools/native-lab/README.md).
--
-- A scene is a function that plays what the framework would send:
--
--   HudLab.scene("vitals-low", function(lab)
--       lab.hud({ health = { value = 18, max = 100 } })   -- merged into the 10 Hz HUD sample
--       lab.state({ needs = { food = 12, drink = 60 } })   -- a state patch (LightRpNative.patchState)
--       lab.page("lightrp:ui:notice", { kind = "money", title = "PAYCHECK", body = "+ 240" })
--       lab.wait(1200)
--   end)
--
-- Run one with the event `hudlab:<name>` (debug bridge: `resource.emit hudlab:vitals-low`),
-- everything in order with `hudlab:all`, and start over with `resource.restart lrp_hudlab`.
HudLab = { scenes = {}, order = {} }
local N = LightRpNative

local sample = {
    ready = true,
    health = { value = 100, max = 100 }, stamina = { value = 100, max = 100 }, armor = 0,
    vehicle = { active = false },
    voice = { state = "idle", level = 0, range = "normal" },
    clock = "12:00",
    weapon = { active = false, externalTop = 0 },
}
local function merge(into, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(into[k]) == "table" and v[1] == nil then merge(into[k], v) else into[k] = v end
    end
end

local lab = {}
function lab.hud(values) merge(sample, values) end
function lab.setHud(key, value) sample[key] = value end
function lab.state(patch) N.patchState(patch) end
function lab.page(name, payload) N.page(name, payload) end
function lab.wait(ms) Wait(ms) end
function lab.dialog(kind, open) LightRpUi.dialogs[kind] = open or nil; N.dialog(kind, open) end
function lab.menu(open) LightRpUi.menuOpen = open == true end
function lab.log(text) print("[hudlab] " .. tostring(text)) end
HudLab.lab = lab

function HudLab.scene(name, fn)
    HudLab.scenes[name] = fn
    HudLab.order[#HudLab.order + 1] = name
    AddEventHandler("hudlab:" .. name, function()
        CreateThread(function()
            print("[hudlab] scene " .. name)
            local ok, why = pcall(fn, lab)
            print("[hudlab] scene " .. name .. (ok and " done" or (" FAILED: " .. tostring(why))))
        end)
    end)
end

AddEventHandler("hudlab:all", function()
    CreateThread(function()
        for _, name in ipairs(HudLab.order) do
            print("[hudlab] scene " .. name)
            local ok, why = pcall(HudLab.scenes[name], lab)
            if not ok then print("[hudlab] scene " .. name .. " FAILED: " .. tostring(why)) end
            Wait(2500)
        end
        print("[hudlab] all scenes played")
    end)
end)
AddEventHandler("hudlab:list", function() print("[hudlab] scenes: " .. table.concat(HudLab.order, ", ")) end)

CreateThread(function()
    Wait(200)
    -- an active character, as the server's first state patch says
    N.patchState({ character = { status = "active", playerId = 1, name = "Lab Runner", welcomePending = false, origins = {}, slots = {} },
        needs = { food = 82, drink = 64 }, rental = {}, tutorial = { active = false } })
    local started = N.start()
    print("[hudlab] started=" .. tostring(started) .. ", " .. #HudLab.order .. " scene(s): hudlab:<name>, hudlab:all, hudlab:list")
    while true do
        N.page(LightRpEvents.page.hud, sample)
        Wait(100)
    end
end)
