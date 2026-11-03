-- Cyberware on the client. The server (server/modules/cyberware.lua, cyberware_active.lua)
-- checks every implant and decides; this file only offers the keys and the menu entries.
--   B   holster / Mantis Blades: puts away whatever is in the hands, and with empty hands draws
--       the Mantis Blades of a player who has them.
--   X   Berserk (a Berserk fitted in the operating system; the Sandevistans' X is bound by the
--       platform's reflex resource, and the two never share a body).
--   ALT + click a player or an NPC: "Scan" (Kiroshi optics), "Mark for crew" (Kiroshi
--       Clairvoyant) -- shown only when the server's kit says the optics are fitted.
-- Dash (Ctrl), Ground Slam (G) and the Sandevistan (X) are bound by their platform resources.
-- The server sends on "op77_lightrp:cyberware": the kit, and the crew marks (an arrow above the
-- marked target, moved with every update, gone on "unmark" or when its time runs out).
local E, Ui = LightRpEvents, LightRpUi
local resource = GetCurrentResourceName()
local KEY = { id = "lightrp.cyberware.blades", name = "Light RP: holster / Mantis Blades", key = "B" }
local BERSERK = { id = "lightrp.cyberware.berserk", name = "Light RP: Berserk", key = "X" }

local kit = { scan = false, mark = false, berserk = false }
local marks = {} -- id -> { marker, x, y, z, player, untilMs }

local function busy()
    if not Ui or not Ui.characterReady or Ui.actionFocus or Ui.menuOpen or Ui.promptActive then return true end
    for _, open in pairs(Ui.dialogs or {}) do if open then return true end end
    return false
end

local function action(payload)
    local ok, reason = TriggerServerEvent(E.net.action, payload)
    if not ok and Ui and Ui.log then Ui.log("cyberware %s not sent: %s", tostring(payload.type), tostring(reason)) end
    return ok == true
end

CreateThread(function()
    local ok, effective = RegisterKeyMapping(KEY.id, KEY.name, KEY.key, function()
        if LightRpUi and (LightRpUi.menuOpen or LightRpUi.promptActive) then return end
        TriggerServerEvent("op77_lightrp:cyberware:blades")
    end)
    if not ok then print("[lightrp] Mantis Blades key mapping failed: " .. tostring(effective)) end
    ok, effective = RegisterKeyMapping(BERSERK.id, BERSERK.name, BERSERK.key, function()
        if not kit.berserk or busy() then return end
        action({ type = "cyberware.berserk" })
    end)
    if not ok then print("[lightrp] Berserk key mapping failed: " .. tostring(effective)) end
end)

-- ---------------------------------------------------------------------------
-- ALT + click: Scan / Mark for crew

local function targetOf(context)
    if GetInvokingResource() ~= "open77_contextmenu" or type(context) ~= "table" then return nil end
    local t = context.target
    if type(t) ~= "table" or busy() then return nil end
    if t.kind == "player" then
        if context.kind == "self" or t.isLocalPlayer == true or type(t.playerId) ~= "number" then return nil end
        return { kind = "player", playerId = t.playerId }
    end
    if t.kind == "npc" then return { kind = "npc", npcId = tonumber(t.npcId) } end
    return nil
end

local function choice(context)
    local target = targetOf(context)
    if not target then return nil end
    local data = type(context.action) == "table" and context.action.data
    local what = type(data) == "table" and data.cyberware
    if what == "scan" and kit.scan then return what, target end
    -- the Clairvoyant locks onto players and the server's own NPCs (an ambient NPC has no id)
    if what == "mark" and kit.mark and (target.kind == "player" or target.npcId ~= nil) then return what, target end
    return nil
end
exports("cyberwareContextAvailable", function(context) return choice(context) ~= nil end)
exports("cyberwareContextSelect", function(context)
    local what, target = choice(context)
    if not what then return false end
    return action({ type = what == "scan" and "cyberware.scan" or "cyberware.mark", target = target })
end)

local function register()
    local definitions = {
        { id = "cyberware.scan", label = "Scan (Kiroshi)", icon = "info", types = { "player", "npc" }, group = "Cyberware", order = 1, distance = 12,
            canInteract = "cyberwareContextAvailable", onSelect = "cyberwareContextSelect", data = { cyberware = "scan" } },
        { id = "cyberware.mark", label = "Mark for crew", icon = "location", types = { "player", "npc" }, group = "Cyberware", order = 2, distance = 12,
            canInteract = "cyberwareContextAvailable", onSelect = "cyberwareContextSelect", data = { cyberware = "mark" } },
    }
    local pending, reason = Open77.exports.call("open77_contextmenu", "registerMany", definitions)
    local tokens
    if pending then tokens, reason = pending:await() end
    if not tokens then
        if Ui and Ui.log then Ui.log("cyberware context registration failed: %s", tostring(reason)) end
        return
    end
    if Ui and Ui.log then Ui.log("cyberware context ready: %d actions", #definitions) end
end
AddEventHandler("onClientResourceStart", function(name)
    if name == resource or name == "open77_contextmenu" then CreateThread(register) end
end)

-- ---------------------------------------------------------------------------
-- Crew marks: an arrow above the target

local function nowMs() return math.floor(Open77.time.monotonic() * 1000) end

local function unmark(id)
    local m = marks[id]
    if not m then return end
    marks[id] = nil
    if m.marker then pcall(Open77.markers.remove, m.marker) end
end

local function above(x, y, z) return { x = x, y = y, z = z + 2.3 } end

local function mark(p)
    if type(p.id) ~= "string" or not tonumber(p.x) or not tonumber(p.y) or not tonumber(p.z) then return end
    local m = marks[p.id]
    local untilMs = nowMs() + math.max(0, math.min(tonumber(p.remainingMs) or 0, 60000))
    if not m then
        local marker, why = Open77.markers.create({ position = above(p.x, p.y, p.z), shape = "arrow", radius = 0.45, height = 0.6,
            color = { r = 255, g = 59, b = 59, a = 220 }, maxDistance = 250 })
        if not marker and Ui and Ui.log then Ui.log("cyberware mark arrow refused: %s", tostring(why)) end
        m = { marker = marker }
        marks[p.id] = m
    end
    m.x, m.y, m.z, m.player, m.untilMs = p.x, p.y, p.z, tonumber(p.player), untilMs
    if m.marker then pcall(Open77.markers.update, m.marker, { position = above(p.x, p.y, p.z) }) end
end

RegisterNetEvent("op77_lightrp:cyberware", function(p)
    if type(p) ~= "table" then return end
    if p.kind == "kit" then
        kit.scan, kit.mark, kit.berserk = p.scan == true, p.mark == true, p.berserk == true
    elseif p.kind == "mark" then
        mark(p)
    elseif p.kind == "unmark" and type(p.id) == "string" then
        unmark(p.id)
    end
end)

-- Between two server updates a marked player is followed from this client's own view of him;
-- an arrow whose time ran out (a lost "unmark") goes by itself.
CreateThread(function()
    while true do
        if next(marks) == nil then
            Wait(500)
        else
            Wait(100)
            local t = nowMs()
            local near
            for id, m in pairs(marks) do
                if t > m.untilMs + 1500 then
                    unmark(id)
                elseif m.player and m.marker then
                    near = near or (Open77.players.nearby(250) or {})
                    for _, entry in ipairs(near) do
                        if entry.playerId == m.player and type(entry.position) == "table" then
                            pcall(Open77.markers.update, m.marker, { position = above(entry.position.x, entry.position.y, entry.position.z) })
                            break
                        end
                    end
                end
            end
        end
    end
end)
