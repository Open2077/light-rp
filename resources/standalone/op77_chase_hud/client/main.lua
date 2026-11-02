-- op77_chase_hud client: the NCPD Chase overlay. Draws what op77_chase sends and decides
-- nothing. It claims no part of Light RP's HUD, binds no key and takes no input: a
-- transparent surface on the hud layer, top centre, empty outside a chase or a queue.
--
--   op77_chase:hud    { state = placing|countdown|active|intermission|resolved|idle, role, ... }
--   op77_chase:queue  { queued, position, total, mode }
-- The page interpolates the clocks between pushes (remainingMs is anchored on receipt).
local page, ready = nil, false
local chase, queue = { state = "idle" }, { queued = false }
local creating = false

local function push()
    if not page or not ready then return end
    pcall(page.send, page, "chase:hud", { chase = chase, queue = queue })
end

RegisterNetEvent("op77_chase:hud", function(payload)
    if type(payload) ~= "table" then return end
    chase = payload
    push()
end)

RegisterNetEvent("op77_chase:queue", function(payload)
    if type(payload) ~= "table" then return end
    queue = payload
    push()
end)

local function createSurface()
    if creating or page then return end
    creating = true
    local options = { entry = "web/index.html", layer = "hud", width = 1920, height = 1080, fps = 30, zIndex = 640,
        transparent = true, visible = true }
    local created, why
    for _ = 1, 120 do
        created, why = WebUI.create(options)
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    creating = false
    if not created then print("[op77_chase_hud] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("chase:ready", function()
        ready = true
        push()
    end)
end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    CreateThread(createSurface)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    page, ready = nil, false
end)
