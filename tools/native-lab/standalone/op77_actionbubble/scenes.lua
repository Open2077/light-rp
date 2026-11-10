-- op77_actionbubble in the HUD lab: the NativeUI document (ui/actionbubble.rml) driven as
-- client/main.lua drives it, without a world. No anchor resolves here, so the scenes feed
-- the view its own messages (ab:add / ab:update / ab:anchor / ab:remove, the payload of
-- pageDef in client/main.lua) and answer in place of Open77.anchors.frame() through the
-- view's lab hook (ActionBubbleView.anchorSource): scripted screen positions (0..1) and
-- distances. Each scene starts from an empty screen; a bubble with a duration ends as it
-- does in game (ab:remove when its time is up), the others stay on screen.
local V = ActionBubbleView
local C = ActionBubbleConfig

local function clock() return Open77.time.monotonic() end
local started = clock()

-- anchor id -> { x, y, distance, onScreen, move = function(a, seconds) end }
local anchors, live, generation, count = {}, {}, 0, 0

V.anchorSource = function()
    local t = clock() - started
    local out = {}
    for id, a in pairs(anchors) do
        if a.move then a.move(a, t - a.born) end
        out[#out + 1] = { id = id, projected = true, onScreen = a.onScreen ~= false, x = a.x, y = a.y, distance = a.distance }
    end
    return out
end

-- The document, then the frame loop client/main.lua runs.
CreateThread(function()
    local ok, why = V.start({ hideUnderMenus = true })
    if not ok then print("[hudlab] op77_actionbubble: no document: " .. tostring(why)) return end
    while true do
        local fine, err = pcall(V.frame)
        if not fine then print("[hudlab] op77_actionbubble frame: " .. tostring(err)) end
        Wait(0)
    end
end)

local function send(name, payload) V:send(name, payload) end

-- A target in the world: where it is on screen and how far.
local function anchor(id, x, y, distance, move)
    anchors[id] = { x = x, y = y, distance = distance, move = move, born = clock() - started }
    return id
end

-- What client/main.lua sends for a bubble (pageDef).
local function payload(id, anchorId, def)
    local kind = C.kinds[def.kind or "action"] or C.kinds.action
    local asterisks = def.asterisks
    if asterisks == nil then asterisks = (def.kind or "action") == "action" end
    local duration = def.duration == nil and C.duration or def.duration
    return {
        id = id, text = def.text, kind = def.kind or "action", label = kind.label, accent = def.accent or kind.accent,
        icon = def.icon, author = def.author, asterisks = asterisks, side = def.side or "auto",
        duration = duration, remaining = duration, maxDistance = def.maxDistance or C.maxDistance,
        anchor = anchorId or false, group = def.group or ("lab:" .. tostring(anchorId)),
    }
end

-- Ends a bubble when its time is up, as the lifetime loop of client/main.lua does.
local function expire(id, seconds)
    if not (seconds > 0) then return end
    local mine = generation
    live[id].ends = (live[id].ends or 0) + 1
    local turn = live[id].ends
    CreateThread(function()
        Wait(math.floor(seconds * 1000))
        if generation == mine and live[id] and live[id].ends == turn then
            send("ab:remove", { id = id })
            live[id] = nil
        end
    end)
end

local function show(anchorId, def)
    count = count + 1
    local id = "lab:" .. count
    local p = payload(id, anchorId, def)
    live[id] = { anchor = anchorId, def = def }
    send("ab:add", p)
    expire(id, p.duration)
    return id
end

local function update(id, patch)
    local entry = live[id]
    if not entry then return end
    for k, v in pairs(patch) do entry.def[k] = v end
    local p = payload(id, entry.anchor, entry.def)
    send("ab:update", p)
    expire(id, p.duration)
end

local function hide(id)
    if not live[id] then return end
    send("ab:remove", { id = id })
    live[id] = nil
end

local function clear()
    generation = generation + 1
    for id in pairs(live) do
        send("ab:remove", { id = id, instant = true })
        live[id] = nil
    end
    for id in pairs(anchors) do anchors[id] = nil end
end

-- The entrance of one short bubble: the pin pops, the ring pulses, the leader draws, the
-- card unfolds (330 ms), the text types out of glitch characters, the brackets fade in, the
-- sheen sweeps once. It has no duration: it stays, floating, with no bar.
HudLab.scene("bubble-enter", function(lab)
    clear()
    anchor("a", 0.42, 0.55, 4)
    show("a", { text = "Opens the trunk", icon = "trunk", duration = 0 })
    lab.wait(3000)
end)

-- A short line, a long one (two to three lines, cut at 96 bytes by the validation) and one
-- per kind (accent colours; only `action` wears asterisks), with and without an icon.
HudLab.scene("bubble-kinds", function(lab)
    clear()
    anchor("a", 0.12, 0.34, 4); anchor("b", 0.38, 0.34, 4); anchor("c", 0.66, 0.34, 4)
    anchor("d", 0.12, 0.74, 4); anchor("e", 0.38, 0.74, 4); anchor("f", 0.62, 0.74, 4)
    show("a", { text = "Nods", duration = 0 })
    show("b", { text = "Takes the keys out of the left pocket, drops them, picks them up again and unlocks the door",
        icon = "key", duration = 0 })
    show("c", { text = "Engine running", kind = "state", icon = "car", duration = 0 })
    lab.wait(400)
    show("d", { text = "Over here!", kind = "speech", icon = "chat", duration = 0 })
    show("e", { text = "Armed & dangerous <3 {{x}}", kind = "alert", icon = "alert", duration = 0 }) -- markup and braces, shown as typed
    show("f", { text = "Searching the vehicle, this will take a while so stand back and keep your hands where I can see them",
        kind = "system", icon = "search", accent = "#9B8CFF", duration = 0 })
    lab.wait(3000)
end)

-- An update while shown (the new text types in at once, the bar starts over), then the bar
-- running out and the exit: the card folds, the leader retracts, the pin shrinks.
HudLab.scene("bubble-update", function(lab)
    clear()
    anchor("a", 0.45, 0.55, 4)
    local id = show("a", { text = "Opens the trunk", icon = "trunk", duration = 6 })
    lab.wait(2400)
    update(id, { text = "Closes the trunk, slowly", duration = 3 })
    lab.wait(1500)
    -- a new accent and icon: the bubble is rebuilt as it stands, without its entrance
    update(id, { text = "Locks the vehicle", icon = "lock", accent = "#2EE6E0", duration = 2.5 })
    lab.wait(3500)
end)

-- Three bubbles on one target stack upward, oldest at the bottom, while the target moves
-- slowly; the middle one ends first and the one above comes down.
HudLab.scene("bubble-stack", function(lab)
    clear()
    anchor("car", 0.4, 0.7, 5, function(a, t)
        a.x = 0.4 + 0.06 * math.sin(t * 0.7)
        a.y = 0.7 + 0.02 * math.sin(t * 1.1)
    end)
    show("car", { text = "Unlocks the vehicle", icon = "unlock", duration = 0, group = "vehicle:50" })
    lab.wait(900)
    local middle = show("car", { text = "Opens the trunk and looks inside for a long moment, moving a few boxes around",
        icon = "trunk", duration = 0, group = "vehicle:50" })
    lab.wait(900)
    show("car", { text = "Trunk open", kind = "state", icon = "box", duration = 0, group = "vehicle:50" })
    lab.wait(2800)
    hide(middle)
    lab.wait(2000)
end)

-- "me" (exports.op77_actionbubble:me): a replicated action on your own character, close to
-- the camera (third person: the collar, about 2.5 m away), five seconds, then gone.
HudLab.scene("bubble-me", function(lab)
    clear()
    anchor("self", 0.5, 0.62, 2.5, function(a, t)
        a.x = 0.5 + 0.01 * math.sin(t * 2.0)   -- the body sways as it walks
        a.y = 0.62 + 0.006 * math.sin(t * 4.0)
    end)
    show("self", { text = "Unlocks the vehicle", icon = "unlock", duration = 5, group = "player:7" })
    lab.wait(6200)
end)

-- Screen edges: past two thirds of the width the card goes to the left of its pin; near the
-- right, left and top edges it is kept on screen (12 / 12 / 10 px) and the leader bends to
-- it; `side` forces a side. One target slides from the left edge to the right one.
HudLab.scene("bubble-edges", function(lab)
    clear()
    anchor("right", 0.985, 0.4, 4); anchor("left", 0.02, 0.4, 4); anchor("top", 0.3, 0.03, 4)
    anchor("forced", 0.55, 0.85, 4); anchor("slide", 0.1, 0.62, 4, function(a, t)
        a.x = 0.5 - 0.45 * math.cos(t * 0.55)
    end)
    show("right", { text = "At the right edge of the screen", icon = "eye", duration = 0 })
    show("left", { text = "Forced left at the left edge", icon = "hand", side = "left", duration = 0 })
    show("top", { text = "Under the top edge", icon = "gear", duration = 0 })
    show("forced", { text = "Forced to the left", side = "left", kind = "state", duration = 0 })
    show("slide", { text = "Changes side at two thirds", icon = "car", duration = 0 })
    lab.wait(7000)
end)

-- Distance: the scale goes from 1 (up to 5 m) to 0.75 (from 7.7 m), the bubble fades over
-- the last quarter of its maxDistance (25 m) and is gone past it. A row at fixed distances,
-- and one target walking away and back; one leaves the screen and returns.
HudLab.scene("bubble-distance", function(lab)
    clear()
    local row = { 3, 6, 9, 19, 22, 24.5 }
    for i, distance in ipairs(row) do
        local id = anchor("d" .. i, 0.06 + 0.15 * (i - 1), 0.32, distance)
        show(id, { text = ("%s m"):format(distance), icon = "search", duration = 0 })
    end
    anchor("walker", 0.3, 0.75, 3, function(a, t)
        a.distance = 14.5 + 12.5 * math.sin(t * 0.8 - 1.57)   -- 2 m .. 27 m
        a.y = 0.75 - 0.006 * a.distance
    end)
    show("walker", { text = "Walks away and comes back", icon = "eye", duration = 0 })
    anchor("turner", 0.7, 0.75, 5, function(a, t)
        a.onScreen = not (t > 2.5 and t < 4.5)                 -- behind the camera for 2 s
    end)
    show("turner", { text = "Off screen for a moment", kind = "state", duration = 0 })
    lab.wait(7500)
end)
