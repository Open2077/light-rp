-- op77_tcg private rooms, the client side (server/rooms.lua, shared/rooms.lua):
-- - by the NEON DECK counter, a 3D label over the host and E opens the rooms panel (create a room, join with a code);
-- - inside a room, a label over the door and E takes the player back up to the shop;
-- - the page shows the panel and, while in a room, a small badge with the code (web/rooms.js).
local K = TcgClient
local R = TcgRooms
local NET = "op77_tcg:"

local state = { room = nil, styles = R.styleList() }
local panelOpen = false
local labels = {}   -- id -> { h = handle, key = text key }

local function flat(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

local function setLabel(id, want)
    local kit = K.uikit()
    local cur = labels[id]
    if not want then
        if cur and kit then pcall(kit.clearText3D, cur.h) end
        labels[id] = nil
        return
    end
    if cur and cur.key == want.key then return end
    if cur and kit then pcall(kit.clearText3D, cur.h) end
    labels[id] = nil
    if not kit then return end
    local ok, h = pcall(kit.drawText3D, { position = want.position, text = want.text, sublabel = want.sublabel,
        maxDistance = want.max or 12, accent = want.accent or "#00F0FF", color = "#F2F6F8" })
    if ok and h then labels[id] = { h = h, key = want.key } end
end

local function nearTalk(p, extra)
    local t = R.talkPoint()
    return p and math.abs(p.z - t.z) < 2.5 and flat(p, t) <= R.host.talkRadius + (extra or 0)
end

local function atExit(p, extra)
    local style = p and R.styleAt(p)
    if not style then return nil end
    local e = R.exitPoint(style)
    return flat(p, e) <= R.exit.radius + (extra or 0) and style or nil
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    K.send("tcg:roomsClose", {})
    if not K.isOpen() then K.release() end
end

local function openPanel()
    panelOpen = true
    K.show(true)
    K.send("tcg:roomsOpen", state)
    TriggerServerEvent(NET .. "rooms")
end

-- E: the host (open the panel) or the room's door (back up).
local function interact()
    local p = K.here()
    if not p then return end
    if nearTalk(p) then return openPanel() end
    if atExit(p) then
        K.send("tcg:roomLeaving", {})
        TriggerServerEvent(NET .. "roomExit")
    end
end
local called, okKey, why = pcall(RegisterKeyMapping, "op77_tcg.rooms", "Cyberpunk TCG: private rooms (counter host, room door)", "E", interact)
if not called or not okKey then K.log("rooms key refused: %s", tostring(called and why or okKey)) end

-- The labels, a few times a second.
CreateThread(function()
    local host = R.hostPosition()
    while true do
        Wait(300)
        local p = K.here()
        if p then
            setLabel("host", nearTalk(p, 6) and { position = { x = host.x, y = host.y, z = host.z + 2.05 }, text = "PRIVATE ROOMS",
                sublabel = "E: open a room or join your friends with a code", key = "host", max = 9 } or nil)
            local style = R.styleAt(p)
            if style then
                local e = R.exitPoint(style)
                setLabel("exit", { position = { x = e.x, y = e.y, z = e.z + 2.2 }, text = "EXIT",
                    sublabel = "E: back up to NEON DECK", accent = "#FCEE0A", key = "exit:" .. style, max = 8 })
            else
                setLabel("exit", nil)
            end
            if panelOpen and not nearTalk(p, 2.5) then closePanel() end
        end
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Server -> page

RegisterNetEvent(NET .. "roomState", function(d)
    if type(d) ~= "table" then return end
    state = { room = d.room, styles = d.styles or state.styles }
    K.send("tcg:roomState", state)
end)

RegisterNetEvent(NET .. "roomEntered", function(room)
    closePanel()
    K.send("tcg:roomEntered", type(room) == "table" and room or {})
end)

-- ---------------------------------------------------------------------------------------------
-- Page -> server

K.on("tcg:roomCreate", function(d) TriggerServerEvent(NET .. "roomCreate", tostring(d.style or "")) end)
K.on("tcg:roomJoin", function(d) TriggerServerEvent(NET .. "roomJoin", tostring(d.code or "")) end)
K.on("tcg:roomLeave", function() closePanel(); TriggerServerEvent(NET .. "roomExit") end)
K.on("tcg:roomsClose", function() closePanel() end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for id in pairs(labels) do setLabel(id, nil) end
end)

-- Back after a reconnect / resource restart: ask where we stand.
CreateThread(function()
    Wait(4000)
    TriggerServerEvent(NET .. "rooms")
end)
