-- op77_playermarks in the HUD lab: the NativeUI document (ui/playermarks.rml) driven as
-- client/main.lua drives it, without a world. There are no players and no anchor resolves
-- here, so the scenes feed the view its own messages (pm:config / pm:add / pm:name /
-- pm:talk / pm:remove) and answer in place of Open77.anchors.frame() through the view's lab
-- hook (PlayerMarksView.anchorSource): scripted screen positions (0..1) and distances.
-- Each scene starts from an empty screen and leaves its last state on it.
local V = PlayerMarksView
local C = PlayerMarksConfig

-- anchor id -> { x, y, distance, onScreen, move = function(a, seconds) end }
local anchors, live = {}, {}
local function clock()
    if type(GetGameTimer) == "function" then return GetGameTimer() / 1000 end
    return Open77.time.monotonic()
end
local started = clock()

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
    if not ok then print("[hudlab] op77_playermarks: no document: " .. tostring(why)) return end
    while true do
        local fine, err = pcall(V.frame)
        if not fine then print("[hudlab] op77_playermarks frame: " .. tostring(err)) end
        Wait(0)
    end
end)

local function send(name, payload) V:send(name, payload) end
local function config(page, radius)
    send("pm:config", { radius = radius or C.radius, page = page or C.page, hideUnderMenus = C.hideUnderMenus })
end

-- A plate: player id, name as client/main.lua writes it ("[id] Name"), where on screen, how far.
local function plate(id, name, x, y, distance, move)
    local key = tostring(id)
    anchors[key] = { x = x, y = y, distance = distance, move = move, born = clock() - started }
    live[key] = true
    send("pm:add", { player = key, anchor = key, name = name })
    return key
end
local function talk(id, level) send("pm:talk", { player = tostring(id), talking = level ~= nil and level ~= false, level = level or 0 }) end
local function remove(id)
    local key = tostring(id)
    send("pm:remove", { player = key })
    anchors[key], live[key] = nil, nil
end
local function clear()
    for key in pairs(live) do remove(key) end
    config()
end

-- Near, mid, far and the fading last quarter of the radius (35 m): scale 1.0 -> 0.6, fade
-- from 26.25 m. Left to right, nearest first; the last one is past the radius (no plate).
HudLab.scene("plates-distance", function(lab)
    clear()
    plate(12, "[12] Archer Hella", 0.14, 0.45, 2)
    plate(7, "[7] Jake Rob", 0.30, 0.45, 10)
    plate(31, "[31] Mara", 0.46, 0.45, 18)
    plate(4, "[4] Viktor Vektor", 0.60, 0.45, 26.25)
    plate(88, "[88] Rogue", 0.72, 0.45, 30.6)
    plate(15, "[15] Almost Gone", 0.83, 0.45, 34)
    plate(99, "[99] Past The Radius", 0.93, 0.45, 36)
    lab.wait(1500)
end)

-- Names: the longest the config allows (24 bytes + the id), accents put in capitals, an id
-- alone (no name), then a roleplay name replacing the account's (setNames -> pm:name).
HudLab.scene("plates-names", function(lab)
    clear()
    plate(128, "[128] Maximilian von Hohenber", 0.25, 0.35, 4)
    plate(9, "[9] Zoé Müller", 0.5, 0.35, 4)
    plate(41, "[41]", 0.72, 0.35, 4)
    plate(3, "[3] account_name_77", 0.5, 0.6, 6)
    lab.wait(2500)
    send("pm:name", { player = "3", name = "[3] Jackie Welles" })
    lab.wait(1500)
    -- player text with markup and braces: shown as typed ("{{" would open a data binding)
    send("pm:name", { player = "41", name = "[41] {{Late}} <Arrival> & Co" })
    lab.wait(1000)
end)

-- Voice: the bars at four levels (the threshold, low, mid, full), the chip warming up and the
-- tip pulsing; one player starts and stops twice (chip cross-fade, bars back to ink stubs).
-- A far talker shows the same at the small scale.
HudLab.scene("plates-talk", function(lab)
    clear()
    plate(1, "[1] Silent", 0.14, 0.4, 3)
    plate(2, "[2] Whisper", 0.31, 0.4, 3)
    plate(3, "[3] Low", 0.48, 0.4, 3)
    plate(4, "[4] Mid", 0.65, 0.4, 3)
    plate(5, "[5] Loud", 0.82, 0.4, 3)
    plate(6, "[6] Far Talker", 0.4, 0.65, 24)
    plate(7, "[7] On And Off", 0.62, 0.65, 5)
    lab.wait(800)
    talk(2, 0.0)  -- talking under the threshold: level 0, still live
    talk(3, 0.25)
    talk(4, 0.6)
    talk(5, 1.0)
    talk(6, 0.8)
    for _ = 1, 2 do
        talk(7, 0.7)
        lab.wait(1400)
        talk(7, false)
        lab.wait(900)
    end
    -- the level moves while talking, as the talkers' feed does ten times a second
    for i = 1, 16 do
        talk(4, 0.2 + 0.8 * math.abs(math.sin(i * 0.5)))
        lab.wait(100)
    end
    talk(7, 0.5)
end)

-- Motion: a plate crossing the screen and leaving it on the right, then coming back; one
-- walking away to the radius and back (scale and fade follow); one standing behind the
-- camera for a moment (not on screen); one removed (the player left).
HudLab.scene("plates-move", function(lab)
    clear()
    plate(21, "[21] Crossing", 0.2, 0.3, 6, function(a, t)
        a.x = 0.2 + 0.9 * math.abs(math.sin(t * 0.45))   -- past the right edge and back
        a.onScreen = a.x >= 0 and a.x <= 1
    end)
    plate(22, "[22] Walking Away", 0.3, 0.55, 3, function(a, t)
        a.distance = 19.5 + 17 * math.sin(t * 0.8 - 1.57)   -- 2.5 m .. 36.5 m
        a.y = 0.55 - 0.004 * a.distance
    end)
    plate(23, "[23] Turns Around", 0.6, 0.55, 5, function(a, t)
        a.onScreen = not (t > 2 and t < 3.5)                -- behind the camera for 1.5 s
    end)
    plate(24, "[24] Leaves", 0.8, 0.55, 5)
    plate(25, "[25] Drifting", 0.5, 0.78, 8, function(a, t)
        a.x = 0.5 + 0.08 * math.sin(t * 0.6)
        a.y = 0.78 + 0.02 * math.sin(t * 0.9)
    end)
    talk(21, 0.6)
    lab.wait(3000)
    remove(24)
    lab.wait(4500)
end)

-- Config: the distance scale and the radius are settings (shared/config.lua, pm:config). The
-- same row of plates under the defaults, then a stronger shrink and an earlier fade, then a
-- 20 m radius (the far ones go), then the defaults again.
HudLab.scene("plates-config", function(lab)
    clear()
    local row = { 3, 9, 15, 21, 27, 33 }
    for i, distance in ipairs(row) do
        plate(50 + i, ("[%d] %d m"):format(50 + i, distance), 0.1 + 0.16 * (i - 1), 0.45, distance)
    end
    lab.wait(1800)
    config({ nearScale = 1.2, farScale = 0.4, fadeFrom = 0.4 })
    lab.wait(1800)
    config(nil, 20)
    lab.wait(1800)
    config()
    lab.wait(800)
end)
