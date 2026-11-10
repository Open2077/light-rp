-- The lab driver for a standalone UI resource (weapon HUD, speedometer, voice plate,
-- chat, context menu, nameplates, bubbles): scenes only, no game mode host.
--
--   HudLab.scene("speedo-cruise", function(lab) ... lab.wait(800) end)
--
-- A scene drives the resource's own page adapter (client/ui.lua or client/view.lua)
-- exactly as its client/main.lua would. `Op77UiLab` (set here, before the resource's
-- scripts load) tells an adapter it runs in the lab: draw on `Op77UiLab.layer`
-- ("debug": above the pre-game shell) and do not hide under a captured cursor.
Op77UiLab = { layer = "debug", ignoreCapture = true }
HudLab = { scenes = {}, order = {} }

local lab = {}
function lab.wait(ms) Wait(ms) end
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
AddEventHandler("hudlab:list", function() print("[hudlab] scenes: " .. table.concat(HudLab.order, ", ")) end)
