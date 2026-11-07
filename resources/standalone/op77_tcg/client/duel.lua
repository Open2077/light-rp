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

-- ---------------------------------------------------------------------------------------------
-- The tutorial's 3D labels: the areas of your playmat, named on the table while the coach talks about them.

local ZONES = {
    fixer = { 0.0725, 0.53, "FIXER", "your 6 dice, waiting to be rolled", "FIXER", "tes 6 dés, pas encore lancés" },
    legends = { 0.313, 0.805, "LEGENDS", "3 Legends, face down", "LÉGENDES", "3 Légendes, face cachée" },
    field = { 0.5, 0.37, "FIELD", "your Units", "TERRAIN", "tes Units (combattants)" },
    eddies = { 0.695, 0.81, "EDDIES", "sold cards: 1 \u{20AC}$ each per turn", "EDDIES", "cartes vendues : 1 \u{20AC}$ chacune par tour" },
    deck = { 0.9325, 0.53, "DECK", "you draw from here", "PIOCHE", "tu pioches ici" },
    trash = { 0.9325, 0.82, "TRASH", "used and defeated cards", "DÉFAUSSE", "cartes utilisées et détruites" },
    gigs = { 0.705, 0.055, "GIGS", "your rolled dice: 7 to win", "GIGS", "tes dés lancés : 7 pour gagner" },
}
local labelsKey = nil
local labelLang = "en"   -- the tutorial's language, picked on the page (tcg:tutorialLang)
-- While the page shows a window (a concept, the glossary) it asks for the labels to be put away (tcg:tutorialLabels).
local labelsHidden = false

-- World labels drawn BY THIS PAGE (not open77_uikit): the duel's focus mode hides every other resource's page,
-- open77_uikit's included. Each label is a world point projected to the screen ten times a second
-- (Open77.camera.project), only while there is something to show.
local worldLabels, lastLabels = {}, ""
local function setLabel(id, entry) worldLabels[id] = entry end
local function pushLabels()
    local out, parts = {}, {}
    for id, e in pairs(worldLabels) do
        local ok, s = pcall(Open77.camera.project, e.pos)
        if ok and type(s) == "table" and s.onScreen then
            local x, y = math.floor(s.x * 1000 + 0.5) / 1000, math.floor(s.y * 1000 + 0.5) / 1000
            out[#out + 1] = { id = id, x = x, y = y, text = e.text, sub = e.sub, kind = e.kind }
            parts[#parts + 1] = id .. "@" .. x .. "," .. y .. ":" .. tostring(e.text) .. tostring(e.sub)
        end
    end
    table.sort(parts)
    local key = table.concat(parts, "|")
    if key == lastLabels then return end
    lastLabels = key
    K.send("tcg:worldLabels", { labels = out })
end
CreateThread(function()
    while true do
        Wait(100)
        if next(worldLabels) or lastLabels ~= "" then pushLabels() end
    end
end)

local function clearLabels()
    for id in pairs(worldLabels) do if id:sub(1, 2) == "z:" then worldLabels[id] = nil end end
    labelsKey = nil
end

local function tutorialLabels(p)
    local t = p and p.tutorial
    local zones = t and t.zones
    local key = zones and (t.id .. ":" .. tostring(p.id) .. ":" .. labelLang) or nil
    if labelsHidden then key = nil end
    if key == labelsKey then return end
    clearLabels()
    if not key or not p.mat then return end
    local pose = { mat = p.mat, yaw = p.yaw or 0 }
    local fr = labelLang == "fr"
    for _, name in ipairs(zones) do
        local z = ZONES[name]
        if z then
            setLabel("z:" .. name, { pos = TcgTable.onMat(pose, z[1], z[2], 0.1), text = fr and z[5] or z[3], sub = fr and z[6] or z[4], kind = "zone" })
        end
    end
    labelsKey = key
end
local function seated() local s = seatOfMine(); return s and s.seated == true end

-- ---------------------------------------------------------------------------------------------
-- The rival's hand in 3D: their cards, backs up, fanned in the air over their edge of the table, with the count
-- floating above (local props: only the player facing them sees it, nothing crosses their own view).
local rivalFan = { props = {}, key = nil }

local function clearRivalHand()
    for _, id in ipairs(rivalFan.props) do pcall(Open77.props.remove, id) end
    setLabel("rh", nil)
    rivalFan = { props = {}, key = nil }
end

local function rivalHand(p)
    local slot = p and p.slot and TcgTable.slotById(tostring(p.slot))
    local rival = p and p.seats and p.seats[p.you == 1 and 2 or 1]
    if not slot or not rival or p.ended or p.phase ~= "game" then return clearRivalHand() end
    local n = math.max(0, math.floor(tonumber(rival.handCount) or 0))
    local key = tostring(p.id) .. ":" .. n
    if key == rivalFan.key then return end
    clearRivalHand()
    rivalFan.key = key
    local seats = TcgTable.seats(slot)
    local pose = seats[p.you == 1 and 2 or 1]
    if not pose then return end
    local shown = math.min(10, n)
    local mid = (shown + 1) / 2
    for k = 1, shown do
        local off = k - mid
        local at = TcgTable.onMat(pose, 0.5 + off * 0.05, 1.1 + off * off * 0.004, 0.2 + k * 0.0012)
        local ok, id = pcall(Open77.props.create, { model = TcgTable.mesh.cardback, position = at, yaw = (pose.yaw + off * 9) % 360,
            scale = 1.35, collision = false, physics = "none" })
        if ok and id then rivalFan.props[#rivalFan.props + 1] = id end
    end
    setLabel("rh", { pos = TcgTable.onMat(pose, 0.5, 1.1, 0.34), text = n .. (n == 1 and " CARD" or " CARDS"),
        sub = (rival.name or "Rival") .. "'s hand", kind = "hand" })
end

-- ---------------------------------------------------------------------------------------------
-- Focus mode: seated at a duel table, nothing else on screen. Open77.hud.setCinematic hides the game's HUD and every
-- other resource's page that does not hold the focus (LightRP's needs and voice, the minimap, name tags...); this
-- page keeps the focus while seated, so the duel stays. Hair-thin bars (1 %). Released on leaving / resource stop.
local focusOn = false
local function focusMode(on)
    on = on == true
    if on == focusOn then return end
    if not (Open77.hud and type(Open77.hud.setCinematic) == "function") then return end
    local ok, done, why = pcall(Open77.hud.setCinematic, on, 0.01)
    if ok and done then focusOn = on else K.log("focus mode %s refused: %s", on and "on" or "off", tostring(ok and why or done)) end
end

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
    -- The tutorial: start it (Duel tab), the coach's Next.
    ["tcg:tutorial"] = function() TriggerServerEvent(NET .. "tutorial") end,
    ["tcg:tutorialNext"] = function() TriggerServerEvent(NET .. "tutorialNext") end,
    -- A window of the page is open (or closed): the 3D labels go away (or come back) so they don't cross it.
    ["tcg:tutorialLabels"] = function(d)
        local hidden = type(d) == "table" and d.hidden == true
        if hidden == labelsHidden then return end
        labelsHidden = hidden
        if hidden then clearLabels() elseif match and seated() then tutorialLabels(match) end
    end,
    -- The tutorial's language (the coach's choice): the 3D labels follow it.
    ["tcg:tutorialLang"] = function(d)
        local v = type(d) == "table" and d.lang == "fr" and "fr" or "en"
        if v == labelLang then return end
        labelLang = v
        if match and seated() then tutorialLabels(match) end
    end,
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

local function camera(d)
    if d.mode == "off" then camMode = 0
    elseif d.mode == "next" then camMode = (camMode % #VIEWS) + 1
    else
        for i, v in ipairs(VIEWS) do if v == d.mode then camMode = i end end
    end
    startCam()
    K.send("tcg:cameraMode", { mode = camMode == 0 and "off" or VIEWS[camMode] })
end
K.on("tcg:camera", camera)

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
    -- The cursor only: a page owning the keyboard turns push-to-talk off for the whole duel
    -- (2026-11-07). V (the camera) is a key mapping below; Escape stays the game's.
    if on then K.show(true, false) elseif not K.isOpen() then K.release() end
end

-- In a duel (seating or playing): nothing else opens over it on its own (client/welcome.lua).
K.inMatch = function() return match ~= nil end

-- Seated at a duel table, the binder stays closed (client/main.lua asks): decks are built before a duel.
K.binderBlocked = function() return seated() == true end

-- Closing the binder while seated hands the cursor back to the duel overlay.
K.afterClose = function() if overlay then K.show(true, false) end end

local function nearChair()
    local at = K.here()
    if not at or not match or not match.chair then return false end
    local dx, dy, dz = at.x - match.chair.x, at.y - match.chair.y, at.z - match.chair.z
    return dx * dx + dy * dy + dz * dz <= C.duel.sitReach * C.duel.sitReach
end

-- The duel is over: let go of everything at once (the camera, the cursor, any animation still on the body).
local function release()
    clearPrompt()
    clearLabels()
    clearRivalHand()
    focusMode(false)
    stopCam(0)
    overlay = false
    if not K.isOpen() then K.release() end
    if Open77.animations and type(Open77.animations.stopSelf) == "function" then pcall(Open77.animations.stopSelf) end
end

local function apply()
    if not match then return release() end
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
    if seated() then tutorialLabels(p); rivalHand(p) else clearLabels(); clearRivalHand() end
    focusMode(seated() and not p.ended)
end)

local function trySit()
    if match and not seated() and nearChair() then TriggerServerEvent(NET .. "sit") end
end

local called, okKey, why = pcall(RegisterKeyMapping, "op77_tcg.sit", "Cyberpunk TCG: sit at your duel table", "E", trySit)
if not called or not okKey then K.log("sit key refused: %s", tostring(called and why or okKey)) end

-- V: the next table view while seated (the overlay no longer owns the keyboard).
local calledCam, okCam, whyCam = pcall(RegisterKeyMapping, "op77_tcg.camera", "Cyberpunk TCG: next table view", "V",
    function() if overlay and seated() and not K.isOpen() then camera({ mode = "next" }) end end)
if not calledCam or not okCam then K.log("camera key refused: %s", tostring(calledCam and whyCam or okCam)) end

-- /tcgtutorial: a guided demonstration duel against the house at a NEON DECK table.
RegisterCommand("tcgtutorial", function() TriggerServerEvent(NET .. "tutorial") end, false)

-- Back in the game after a resource restart or a reconnect: ask for the duel in progress.
CreateThread(function()
    while not K.me() do Wait(500) end
    Wait(3000)
    TriggerServerEvent(NET .. "match")
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    clearLabels()
    clearRivalHand()
    clearPrompt()
    stopCam(0)
end)
