-- op77_tcg, the NEON DECK welcome: a short guide on the TCG page (web/welcome.js) the first time a collector walks
-- up to the vendor (TcgConfig.welcome: anchor, radius). Once per collector: the server keeps "seen" in tcg.db
-- (tcg_seen, per character with a framework) and says so in the state (welcomed = true / false); this client also
-- never opens it on its own twice in a session. Reopened at will with /tcgwelcome or the rooms panel's button.
-- It never opens on its own over something else: a loading screen, a duel, a vehicle, the binder or the rooms panel,
-- a pack being opened, another page holding the cursor or the keyboard (chat, F1 menu), the game's menus.
-- Cost: one distance test every checkMs; the natives above are only asked when the player stands in range.
local K = TcgClient
local W = TcgConfig.welcome or {}
local NET = "op77_tcg:"

TcgWelcome = {}
local open = false        -- the guide is on screen
local autoShown = false   -- opened on its own this session
local since = nil         -- when the player came in range (and nothing was in the way)

local function nowMs() return type(GetGameTimer) == "function" and GetGameTimer() or math.floor(os.clock() * 1000) end

-- A native that may be missing or refused: its results, or nil.
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

function TcgWelcome.inRange(p)
    local a = W.anchor
    if type(p) ~= "table" or type(a) ~= "table" or type(p.x) ~= "number" then return false end
    local dx, dy, r = p.x - a.x, p.y - a.y, W.radius or 4.5
    return dx * dx + dy * dy <= r * r and math.abs((p.z or 0) - a.z) <= (W.height or 2.5)
end

local function loading()
    if Open77.screen and ask(Open77.screen.isLoading) == true then return true end
    if type(GetResourceState) == "function" and GetResourceState("op77_loadscreen") == "running" then
        local ok, covered = pcall(function() return exports.op77_loadscreen:isActive() end)
        if ok and covered == true then return true end
    end
    return false
end

-- Why the guide must not open on its own right now (nil: nothing in the way).
function TcgWelcome.blocked()
    if loading() then return "loading" end
    if K.inMatch and K.inMatch() then return "duel" end
    if K.isOpen() or (K.roomsOpen and K.roomsOpen()) or (K.busy and K.busy()) then return "tcg" end
    if Open77.character and ask(Open77.character.isInVehicle) == true then return "vehicle" end
    if Open77.cursor and ask(Open77.cursor.isCaptured) == true then return "cursor" end
    if Open77.input then
        local keyboard, cursor = ask(Open77.input.isCaptured)
        if keyboard == true or cursor == true then return "input" end
    end
    if Open77.session and ask(Open77.session.isMenuOpen) == true then return "menu" end
    return nil
end

function TcgWelcome.isOpen() return open end

-- What the page words from the real settings (the binder's key, the commands, the lent decks, where packs go).
local function payload(auto)
    local starters = {}
    if TcgConfig.duel.lendStarters ~= false then
        for _, s in ipairs(TcgStarters) do starters[#starters + 1] = { id = s.id, name = s.name, subtitle = s.subtitle, legend = s.legends[1] } end
    end
    local gift = 0
    for _, n in pairs(TcgConfig.starter or {}) do gift = gift + n end
    local st = K.state()
    return { auto = auto == true, binder = W.binder, command = TcgConfig.command, tutorial = "tcgtutorial", welcome = W.command,
             starters = starters, gift = gift, store = type(st) == "table" and st.store or nil,
             roomPlayers = TcgRooms.maxPlayers, codeLength = TcgRooms.codeLength, challengeRadius = TcgConfig.duel.challengeRadius }
end

function TcgWelcome.show(auto)
    if open then return true end
    if not K.ready() then
        if not auto then K.notify("The card page is still loading: try again in a moment.") end
        return false
    end
    open = true
    if auto then
        autoShown = true
        local st = K.state()
        if type(st) == "table" then st.welcomed = true end
        TriggerServerEvent(NET .. "seen", "welcome")
    end
    K.show(true)
    K.send("tcg:welcomeOpen", payload(auto))
    -- A gamemode closes its own panels over ours (LightRP: the inventory).
    TriggerEvent("op77_tcg:focus")
    return true
end

function TcgWelcome.close()
    if not open then return end
    open = false
    K.send("tcg:welcomeClose", {})
    -- The cursor goes back to the game, unless the binder / the rooms panel is still up, or the duel overlay takes it.
    if not K.isOpen() and not (K.roomsOpen and K.roomsOpen()) then K.release() end
    if K.afterClose then K.afterClose() end
end

-- One look: opens the guide once the player has stood in range, unseen, with nothing in the way, for settleMs.
function TcgWelcome.tick(now)
    if open or autoShown or W.enabled == false then since = nil; return false end
    local st = K.state()
    -- Only an explicit "not seen" opens it (no state yet, an older server: never).
    if type(st) ~= "table" or st.welcomed ~= false or not K.ready() then since = nil; return false end
    if not TcgWelcome.inRange(K.here()) or TcgWelcome.blocked() then since = nil; return false end
    since = since or now
    if now - since < (W.settleMs or 0) then return false end
    since = nil
    return TcgWelcome.show(true)
end

K.on("tcg:welcomeOpen", function() TcgWelcome.show(false) end)
K.on("tcg:welcomeClose", function() TcgWelcome.close() end)

RegisterCommand(W.command or "tcgwelcome", function()
    if open then TcgWelcome.close() else TcgWelcome.show(false) end
end, false)

if W.enabled ~= false then
    CreateThread(function()
        while true do
            Wait(W.checkMs or 500)
            local ok, err = pcall(TcgWelcome.tick, nowMs())
            if not ok then K.log("welcome: %s", tostring(err)) end
        end
    end)
end
