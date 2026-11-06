-- Staff ghost mode (/lightrp.ghost [on|off], /admin > Personal tools > Ghost mode): noclip,
-- the body hidden from the other players, no nameplate and no map dot, so a staff member can
-- watch a scene without being seen (owner, 2026-11-06).
--
-- - The body: Open77.players.setVisible (every client re-applies it to that body). The
--   platform drops the hide on death, respawn and a bucket change, so it is read back every
--   CHECK_MS while the ghost is on, and asked again.
-- - Nameplates and map dots: every client gets the ghost list (E.net.staffGhosts) when it
--   changes and when its page comes up; client/core/staff_ghost.lua asks op77_map3d to drop
--   those dots and client/core/pvp_marks.lua adds them to what op77_playermarks hides.
-- - Noclip: the ghost's own client runs the platform's /admin.self.noclip on (off at the end)
--   as the operator, so the host's ACL still decides it (E.net.staffGhost).
-- The command is restricted: staff roles hold command.lightrp.*.
local E = LightRpEvents.net
local Ghost = LightRP.module("staffGhost", {})

local CHECK_MS = 2000
local ghosts = {}       -- player id -> true

function Ghost.list()
    local out = {}
    for id in pairs(ghosts) do out[#out + 1] = id end
    table.sort(out)
    return out
end

function Ghost.isGhost(id) return ghosts[tonumber(id)] == true end

local function broadcast(target) TriggerClientEvent(E.staffGhosts, target or -1, Ghost.list()) end

-- Hidden from the others; change-gated (a read first). -> whether it is hidden now
local function hide(id)
    local read, visible = pcall(Open77.players.isVisible, id)
    if read and visible == false then return true end
    local called, ok, why = pcall(Open77.players.setVisible, id, false)
    if called and ok == true then return true end
    LightRP.log("ghost: %d not hidden: %s", id, tostring(called and why or ok))
    return false
end

local function show(id)
    local read, visible = pcall(Open77.players.isVisible, id)
    if read and visible == true then return true end
    local called, ok, why = pcall(Open77.players.setVisible, id, true)
    if called and ok == true then return true end
    LightRP.log("ghost: %d not shown: %s", id, tostring(called and why or ok))
    return false
end

-- on: true / false. -> ok, message
function Ghost.set(id, on)
    id = tonumber(id)
    if id == nil or GetPlayerName(id) == nil then return false, "No such player." end
    if on then
        ghosts[id] = true
        local hidden = hide(id)
        broadcast()
        TriggerClientEvent(E.staffGhost, id, { on = true })
        LightRP.log("ghost: %d (%s) on", id, tostring(GetPlayerName(id)))
        return true, hidden and "Ghost mode ON: noclip, invisible, no nameplate, off the map."
            or "Ghost mode ON, but the body could not be hidden yet (asked again every 2 s)."
    end
    local was = ghosts[id] == true
    ghosts[id] = nil
    local shown = show(id)
    broadcast()
    TriggerClientEvent(E.staffGhost, id, { on = false })
    if was then LightRP.log("ghost: %d (%s) off", id, tostring(GetPlayerName(id))) end
    return true, shown and "Ghost mode OFF: visible again." or "Ghost mode OFF, but showing the body was refused (asked again)."
end

LightRP.command("lightrp.ghost", { restricted = true, usage = "/lightrp.ghost [on|off]" }, function(source, args)
    if source == nil or source <= 0 then return false, "In game only." end
    local word = tostring(args[1] or ""):lower()
    local on
    if word == "" then on = not ghosts[source]
    elseif word == "on" or word == "1" or word == "true" then on = true
    elseif word == "off" or word == "0" or word == "false" then on = false
    else return false end
    return Ghost.set(source, on)
end)

-- Read-back: the hide comes back after a death, a respawn or a bucket change.
function Ghost.tick()
    local changed = false
    for id in pairs(ghosts) do
        if GetPlayerName(id) == nil then ghosts[id] = nil; changed = true
        else hide(id) end
    end
    if changed then broadcast() end
    return changed
end

CreateThread(function()
    while true do
        Wait(CHECK_MS)
        local ok, err = pcall(Ghost.tick)
        if not ok then LightRP.log("ghost: %s", tostring(err)) end
    end
end)

-- A page that comes up (a join, a reconnect, a resource restart) gets the list at once.
function Ghost.onUiReady(playerId) broadcast(playerId) end

function Ghost.onDisconnected(playerId)
    if ghosts[playerId] then ghosts[playerId] = nil; broadcast() end
end

-- The resource stops: nobody stays invisible.
AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for id in pairs(ghosts) do pcall(Open77.players.setVisible, id, true) end
end)
