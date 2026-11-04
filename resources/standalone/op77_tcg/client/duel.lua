-- op77_tcg client, duels: the decks and challenges of the binder (relayed to the server), the seat prompt at the duel
-- table, the table camera and the game overlay while seated. The table itself (mats, decks, dice, Legends) is made
-- of server props every client around sees; this script only looks at it.
local C, T = TcgConfig, TcgTable
local K = TcgClient
local NET = "op77_tcg:"

local match = nil        -- the server's view of my duel (server/duel.lua view())
local prompt = nil       -- the 3D text over my chair
local promptFor = nil
local cam, camMode = nil, 1
local overlay = false    -- the duel overlay holds the cursor

local function seatOfMine() return match and match.seats and match.seats[match.you] end
local function seated() local s = seatOfMine(); return s and s.seated == true end

-- ---------------------------------------------------------------------------------------------
-- The binder: relays

local RELAY = {
    ["tcg:decks"] = function() TriggerServerEvent(NET .. "decks") end,
    ["tcg:saveDeck"] = function(d) TriggerServerEvent(NET .. "saveDeck", { key = d.key, name = d.name, legends = d.legends, cards = d.cards }) end,
    ["tcg:deleteDeck"] = function(d) TriggerServerEvent(NET .. "deleteDeck", d.key) end,
    ["tcg:selectDeck"] = function(d) TriggerServerEvent(NET .. "selectDeck", d.key) end,
    ["tcg:setPlaymat"] = function(d) TriggerServerEvent(NET .. "setPlaymat", d.id) end,
    ["tcg:nearby"] = function() TriggerServerEvent(NET .. "nearby") end,
    ["tcg:challenge"] = function(d) TriggerServerEvent(NET .. "challenge", d.target, d.deck) end,
    ["tcg:cancelChallenge"] = function(d) TriggerServerEvent(NET .. "cancelChallenge", d.id) end,
    ["tcg:answerChallenge"] = function(d) TriggerServerEvent(NET .. "answerChallenge", d.id, d.accept == true, d.deck) end,
    ["tcg:leaveMatch"] = function() TriggerServerEvent(NET .. "leaveMatch") end,
    ["tcg:choose"] = function(d) TriggerServerEvent(NET .. "choose", d.first ~= false) end,
    ["tcg:mulligan"] = function(d) TriggerServerEvent(NET .. "mulligan", d.again == true) end,
    ["tcg:sit"] = function() TriggerServerEvent(NET .. "sit") end,
    -- A game action at the table (server/duel.lua "act").
    ["tcg:act"] = function(d) TriggerServerEvent(NET .. "act", d) end,
}
for name, fn in pairs(RELAY) do K.on(name, fn) end

for _, name in ipairs({ "decks", "nearby", "challengeSent", "challengeClosed", "duelRefused" }) do
    RegisterNetEvent(NET .. name, function(p) K.send("tcg:" .. name, type(p) == "table" and p or {}) end)
end

RegisterNetEvent(NET .. "challenged", function(p)
    if type(p) ~= "table" then return end
    K.notify(("%s challenges you to a duel (%s) - /%s to answer"):format(p.name or "Someone", p.deck or "a deck", C.command))
    K.send("tcg:challenged", p)
end)

-- ---------------------------------------------------------------------------------------------
-- The table camera: three views while seated (your side, the whole table, top-down on your mat), or the game's.

local VIEWS = { "seat", "table", "mat" }

local function stopCam(blend)
    if not cam then return end
    local c = cam
    cam = nil
    pcall(Open77.camera.deactivate, { blendMs = blend or 600 })
    SetTimeout((blend or 600) + 100, function() pcall(Open77.camera.destroy, c) end)
end

local function viewPose(mode)
    local m, r = match.mat, match.rivalMat
    if not m or not r then return nil end
    local dx, dy = r.x - m.x, r.y - m.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then dx, dy = K.forward(match.yaw or 0) else dx, dy = dx / len, dy / len end
    local mid = { x = (m.x + r.x) / 2, y = (m.y + r.y) / 2, z = m.z }
    if mode == "table" then
        -- From the side of the table, both players in frame.
        local sx, sy = -dy, dx
        return { x = mid.x + sx * 1.35, y = mid.y + sy * 1.35, z = m.z + 1.05 }, mid, 48
    elseif mode == "mat" then
        return { x = m.x - dx * 0.05, y = m.y - dy * 0.05, z = m.z + 0.78 }, { x = m.x + dx * 0.02, y = m.y + dy * 0.02, z = m.z }, 50
    end
    -- From your seat: your mat in front, the rival's beyond it.
    return { x = m.x - dx * 0.42, y = m.y - dy * 0.42, z = m.z + 0.58 }, { x = m.x + dx * 0.16, y = m.y + dy * 0.16, z = m.z }, 52
end

local function startCam()
    if not match or not seated() or camMode == 0 then return stopCam(600) end
    local eye, focus, fov = viewPose(VIEWS[camMode])
    if not eye then return end
    local old = cam
    local ok, created, why = pcall(Open77.camera.create, { position = eye, lookAt = focus, fov = fov, thirdPersonBody = true })
    if not ok or created == nil then return K.log("table camera refused: %s", tostring(ok and why or created)) end
    local called, activated, reason = pcall(Open77.camera.activate, created, { blendMs = 800 })
    if not called or activated ~= true then
        pcall(Open77.camera.destroy, created)
        return K.log("table camera not activated: %s", tostring(called and reason or activated))
    end
    cam = created
    if old then SetTimeout(900, function() pcall(Open77.camera.destroy, old) end) end
end

K.on("tcg:camera", function(d)
    if d.mode == "off" then camMode = 0
    elseif d.mode == "next" then camMode = (camMode % #VIEWS) + 1
    else
        for i, v in ipairs(VIEWS) do if v == d.mode then camMode = i end end
    end
    startCam()
    K.send("tcg:cameraMode", { mode = camMode == 0 and "off" or VIEWS[camMode] })
end)

-- ---------------------------------------------------------------------------------------------
-- The seat prompt and the overlay

local function clearPrompt()
    local kit = K.uikit()
    if prompt and kit then pcall(kit.clearText3D, prompt) end
    prompt, promptFor = nil, nil
end

local function showPrompt()
    local key = "seat:" .. tostring(match.id)
    if promptFor == key then return end
    clearPrompt()
    local kit = K.uikit()
    if not kit or not match.chair then return end
    local rival = match.seats[match.you == 1 and 2 or 1]
    local ok, handle = pcall(kit.drawText3D, { position = { x = match.chair.x, y = match.chair.y, z = match.chair.z + 1.25 },
        text = "Your seat", sublabel = ("Duel vs %s - E to sit down"):format(rival and rival.name or "your rival"),
        maxDistance = 25, accent = "#FCEE09", color = "#F2F6F8" })
    if ok then prompt, promptFor = handle, key end
end

local function setOverlay(on)
    if on == overlay then return end
    overlay = on
    if on then K.show(true) elseif not K.isOpen() then K.release() end
end

-- Seated at a duel table, the binder stays closed (client/main.lua asks): decks are built before a duel.
K.binderBlocked = function() return seated() == true end

-- Closing the binder while seated hands the cursor back to the duel overlay.
K.afterClose = function() if overlay then K.show(true) end end

local function nearChair()
    local at = K.here()
    if not at or not match or not match.chair then return false end
    local dx, dy, dz = at.x - match.chair.x, at.y - match.chair.y, at.z - match.chair.z
    return dx * dx + dy * dy + dz * dz <= C.duel.sitReach * C.duel.sitReach
end

local function apply()
    if not match then
        clearPrompt()
        stopCam(700)
        setOverlay(false)
        return
    end
    if seated() then
        clearPrompt()
        if not cam and camMode ~= 0 then startCam() end
        setOverlay(true)
    else
        showPrompt()
        setOverlay(false)
    end
end

RegisterNetEvent(NET .. "match", function(p)
    if type(p) ~= "table" then return end
    if p.ended or p.none then
        local was = match
        match = nil
        apply()
        K.send("tcg:match", p)
        if p.ended and was then
            K.notify(p.won and "You won the duel." or (p.winner and (p.winner .. " won the duel.") or tostring(p.reason or "The duel is over.")))
        end
        return
    end
    local first = not match or match.id ~= p.id
    match = p
    if first then camMode = 1 end
    K.send("tcg:match", p)
    apply()
end)

local function trySit()
    if match and not seated() and nearChair() then TriggerServerEvent(NET .. "sit") end
end

local called, okKey, why = pcall(RegisterKeyMapping, "op77_tcg.sit", "Cyberpunk TCG: sit at your duel table", "E", trySit)
if not called or not okKey then K.log("sit key refused: %s", tostring(called and why or okKey)) end

-- Back in the game after a resource restart or a reconnect: ask for the duel in progress.
CreateThread(function()
    while not K.me() do Wait(500) end
    Wait(3000)
    TriggerServerEvent(NET .. "match")
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    clearPrompt()
    stopCam(0)
end)
