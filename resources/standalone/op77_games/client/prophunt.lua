-- Prop Hunt on this client: the view, the body on its own screen, the keys. The server decides
-- everything; this applies what it says and asks with the keys. Every lever is let go by the
-- same function: the server's "off", a silence past `leaseMs`, this resource stopping.
--   Third person for a prop (it has to see itself, N switches), first for a hunter (no peek
--   over cover). A prop has no attack, nobody picks a weapon. Nobody has a scanner, nameplate or map dot in the round:
--   those would mark a hidden body (op77_playermarks draws its own plates, Light RP only
--   hides them for kinds "pvp" and "chase").
--   setLocalPuppetVisible is newer than the devkit's build: looked up at each use. Without
--   it a prop sees its own body in third person, and N is the way out.
GamesProphuntClient = {}
local P = GamesProphuntClient

local leaseMs = 20000

local KEYS = {
    { id = "games.prophunt.next", name = "Prop Hunt: next object", key = "R", action = "next", role = "prop" },
    { id = "games.prophunt.family", name = "Prop Hunt: next family of objects", key = "V", action = "family", role = "prop" },
    { id = "games.prophunt.whistle", name = "Prop Hunt: whistle", key = "T", action = "whistle", role = "prop" },
    { id = "games.prophunt.rotate", name = "Prop Hunt: turn the object", key = "G", action = "rotate", role = "prop" },
    { id = "games.prophunt.lock", name = "Prop Hunt: lock in place", key = "O", action = "lock", role = "prop" },
    { id = "games.prophunt.view", name = "Prop Hunt: first / third person", key = "N", role = "prop", view = true },
    { id = "games.prophunt.pulse", name = "Prop Hunt: pulse", key = "Z", action = "pulse", role = "hunter" },
}

local state = nil        -- what the server said last, nil: off
local heardAt = 0
local propView = "tps"   -- the prop's own choice, kept for the session
local held = { lock = nil, attack = false, weapons = false, scanner = false, marks = false, self = false }
local said = {}

local function warn(what, why)
    local line = what .. ": " .. tostring(why)
    if said[line] then return end
    said[line] = true
    if Open77.log and Open77.log.warn then Open77.log.warn("[games:prophunt] " .. line) end
end

local function other(resource, method, ...)
    if type(GetResourceState) == "function" and GetResourceState(resource) ~= "running" then return end
    local args = table.pack(...)
    local ok, why = pcall(function()
        local target = exports[resource]
        return target[method](target, table.unpack(args, 1, args.n))
    end)
    if not ok then warn(resource, why) end
end

local function setLock(mode)
    if held.lock == mode then return end
    local api = Open77.perspective
    if type(api) ~= "table" or type(api.setThirdPerson) ~= "function" then return warn("perspective", "unavailable") end
    local ok, done, why
    if mode then ok, done, why = pcall(api.setThirdPerson, mode == "tps", true)
    else ok, done, why = pcall(api.clearThirdPersonOverride) end
    if ok and done == true then held.lock = mode else warn("perspective", ok and why or done) end
end

-- The platform drops this on a death or a new body: asked again with every state.
local function setSelf(on)
    if not on and not held.self then return end
    local fn = Open77.players.setLocalPuppetVisible
    if type(fn) ~= "function" then return warn("own body", "setLocalPuppetVisible is not on this client") end
    local ok, done, why = pcall(fn, not on)
    if ok and done == true then held.self = on else warn("own body", ok and why or done) end
end

local function setAttack(on)
    if held.attack == on then return end
    held.attack = on
    pcall(Open77.input.setActionBlocked, "Attack", on)
    pcall(Open77.input.setActionBlocked, "Melee", on)
end

-- Nothing is drawn in the round: an RP gun rests in its native slot. Lua's own setActive and
-- the held weapon's fire still work, so a hunter's issued gun is not affected.
local function setWeaponChoice(on)
    if held.weapons == on then return end
    held.weapons = on
    pcall(Open77.input.setActionBlocked, "NextWeapon", on)
    pcall(Open77.input.setActionBlocked, "WeaponWheel", on)
end

local function setScanner(on)
    if held.scanner == on then return end
    local ok, done, why = pcall(Open77.hud.setVisible, "scanner", not on)
    if ok and done ~= false then held.scanner = on else warn("scanner", ok and why or done) end
end

local function setMarks(on)
    if held.marks == on then return end
    held.marks = on
    other("op77_playermarks", "setHidden", on)
    other("op77_map3d", "setPlayerDotsHidden", on)
end

local function apply()
    local disguised = state ~= nil and state.role == "prop"
    local hunter = state ~= nil and state.role == "hunter"
    setLock(disguised and propView or (hunter and "fpp" or nil))
    setSelf(disguised)
    setAttack(disguised)
    setWeaponChoice(state ~= nil)
    setScanner(state ~= nil)
    setMarks(state ~= nil)
end

function P.reset()
    state = nil
    apply()
end

RegisterNetEvent("op77_games:prophunt", function(next)
    if type(next) ~= "table" or (next.role ~= "prop" and next.role ~= "hunter") then return P.reset() end
    state, heardAt = next, GetGameTimer()
    apply()
end)

-- A hint may name a key mapping: the key this player really has it on (client/main.lua).
function P.keys(view)
    local input = Open77.input
    if type(view.hints) ~= "table" or type(input) ~= "table" or type(input.keyFor) ~= "function" then return end
    for _, item in ipairs(view.hints) do
        if item.bind then
            local ok, key = pcall(input.keyFor, item.bind)
            if ok and type(key) == "string" then item.key = key end
        end
    end
end

local function press(key)
    if state == nil or state.role ~= key.role then return end
    if key.view then
        propView = propView == "tps" and "fpp" or "tps"
        apply()
    else
        TriggerServerEvent("op77_games:prophunt:action", key.action)
    end
end

CreateThread(function()
    for _, key in ipairs(type(RegisterKeyMapping) == "function" and KEYS or {}) do
        local ok, why = RegisterKeyMapping(key.id, key.name, key.key, function() press(key) end)
        if not ok then warn("key " .. key.id, why) end
    end
    while true do
        Wait(5000)
        if state ~= nil and GetGameTimer() - heardAt > leaseMs then P.reset() end
    end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then P.reset() end
end)
