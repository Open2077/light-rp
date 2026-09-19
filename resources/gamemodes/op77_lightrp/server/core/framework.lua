-- The framework core, server side. Loaded first; every module registers itself
-- here. Nothing in this file knows about characters, vehicles or chat.
--
--   LightRP.module(name, definition)      register a module { init(), onConnected(id), onDisconnected(id), ... }
--   LightRP.action(type, handler)         handle a UI action { type = ... } sent by a player
--   LightRP.command(name, opts, fn)       RegisterCommand with the framework's reply/log discipline
--   LightRP.reply(source, raw, ok, text)  console/chat answer to a command
--   LightRP.result(playerId, ok, text)    answer to a UI action (toast in the page)
--   LightRP.notice(playerId, def)         notification in the page (and the official package)
--   LightRP.state(playerId, patch)        push a state patch to one player's page
--   LightRP.broadcastState(patch)         push a patch to everyone
LightRP = LightRP or {}
local Config = LightRpConfig
local E = LightRpEvents

local modules = {}        -- ordered list of { name, def }
local actions = {}        -- type -> handler(playerId, payload)
local stateProviders = {} -- name -> function(playerId) -> table (one key of the UI state)

function LightRP.log(format, ...)
    print("[lightrp] " .. (select("#", ...) > 0 and string.format(format, ...) or tostring(format)))
end

function LightRP.nowMs()
    return math.floor(Open77.time.monotonic() * 1000)
end

-- ---------------------------------------------------------------------------
-- Modules

function LightRP.module(name, definition)
    assert(type(name) == "string" and type(definition) == "table", "LightRP.module(name, table)")
    definition.name = name
    modules[#modules + 1] = definition
    LightRP[name] = LightRP[name] or definition
    return definition
end

function LightRP.eachModule(hook, ...)
    for _, definition in ipairs(modules) do
        local fn = definition[hook]
        if type(fn) == "function" then
            local ok, err = pcall(fn, ...)
            if not ok then LightRP.log("module %s.%s failed: %s", definition.name, hook, tostring(err)) end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Answers to players

function LightRP.reply(source, raw, ok, text)
    LightRP.log("%s", text)
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
    end
end

function LightRP.result(playerId, ok, text, actionType)
    if playerId == nil or playerId <= 0 then return end
    TriggerClientEvent(E.net.result, playerId, { ok = ok == true, text = text, action = actionType })
end

-- A notice in the framework's own page. `kind`: info, success, warning, error,
-- police, money, item, message, contract, staff.
function LightRP.notice(playerId, definition)
    if playerId == nil then return end
    definition = definition or {}
    definition.kind = definition.kind or "info"
    definition.source = definition.source or "LIGHT RP"
    TriggerClientEvent(E.net.notice, playerId, definition)
end

function LightRP.broadcastNotice(definition)
    LightRP.notice(-1, definition)
end

-- ---------------------------------------------------------------------------
-- UI state

-- A module publishes one top-level key of the page state:
--   LightRP.stateProvider("character", function(playerId) return {...} end)
function LightRP.stateProvider(key, provider)
    stateProviders[key] = provider
end

function LightRP.buildState(playerId, keys)
    local state = {}
    for key, provider in pairs(stateProviders) do
        if keys == nil or keys[key] then
            local ok, value = pcall(provider, playerId)
            if ok then state[key] = value else LightRP.log("state provider %s failed: %s", key, tostring(value)) end
        end
    end
    return state
end

-- Push one or several keys to one player. `keys` nil = the whole state.
function LightRP.state(playerId, keys)
    if playerId == nil or playerId <= 0 then return end
    local set
    if type(keys) == "string" then set = { [keys] = true }
    elseif type(keys) == "table" then
        set = {}
        for _, key in ipairs(keys) do set[key] = true end
    end
    TriggerClientEvent(E.net.state, playerId, LightRP.buildState(playerId, set))
end

function LightRP.broadcastState(keys)
    for _, id in ipairs(GetPlayers()) do LightRP.state(id, keys) end
end

function LightRP.openMenu(playerId, view)
    TriggerClientEvent(E.net.menuOpen, playerId, { view = view })
end

-- ---------------------------------------------------------------------------
-- Actions from the page (validated server side, one handler per type)

function LightRP.action(actionType, handler)
    actions[actionType] = handler
end

local actionLastMs = {} -- playerId -> stamp; the page is throttled to 4 actions/s
RegisterNetEvent(E.net.action, function(payload)
    local playerId = source
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local last = actionLastMs[playerId]
    local now = LightRP.nowMs()
    if last and now - last < 250 then return end
    actionLastMs[playerId] = now
    local handler = actions[payload.type]
    if handler == nil then
        LightRP.result(playerId, false, "Unknown action: " .. payload.type, payload.type)
        return
    end
    local ok, err = pcall(handler, playerId, payload)
    if not ok then
        LightRP.log("action %s by %d failed: %s", payload.type, playerId, tostring(err))
        LightRP.result(playerId, false, "Action refused (internal error).", payload.type)
    end
end)

RegisterNetEvent(E.net.ready, function()
    local playerId = source
    LightRP.state(playerId)
    LightRP.eachModule("onUiReady", playerId)
end)

-- ---------------------------------------------------------------------------
-- Commands: one wrapper so every command logs and answers the same way.
--   LightRP.command("car", { restricted = false, usage = "/car <model>" }, function(source, args, raw) ... end)
-- The handler returns ok, text (or nothing to stay silent).

function LightRP.command(name, options, handler)
    options = options or {}
    RegisterCommand(name, function(source, args, raw)
        local ok, textOrErr, text = pcall(handler, source, args, raw)
        if not ok then
            LightRP.log("command %s failed: %s", name, tostring(textOrErr))
            LightRP.reply(source, raw, false, "Command failed, see the server log.")
            return
        end
        if textOrErr == nil then return end
        if textOrErr == false and text == nil and options.usage then text = "usage: " .. options.usage end
        LightRP.reply(source, raw, textOrErr == true, text or "")
    end, options.restricted == true)
end

function LightRP.joinArgs(args, from)
    local count = args.n or #args
    from = from or 1
    if count < from then return "" end
    return (table.concat(args, " ", from, count)):gsub("^%s+", ""):gsub("%s+$", "")
end

-- ---------------------------------------------------------------------------
-- Lifecycle fan-out

AddEventHandler("onPlayerConnected", function(playerIdStr, name)
    local playerId = tonumber(playerIdStr)
    if playerId == nil or playerId <= 0 then return end
    LightRP.eachModule("onConnected", playerId, name)
end)

AddEventHandler("onPlayerDisconnected", function(playerIdStr, reason)
    local playerId = tonumber(playerIdStr)
    if playerId == nil then return end
    actionLastMs[playerId] = nil
    LightRP.eachModule("onDisconnected", playerId, reason)
end)

AddEventHandler("onPlayerReady", function(playerIdStr, detail)
    local playerId = tonumber(playerIdStr)
    if playerId == nil or playerId <= 0 then return end
    LightRP.eachModule("onReady", playerId, detail)
end)

AddEventHandler("onPlayerLifeStateChanged", function(playerIdStr, previous, phase)
    local playerId = tonumber(playerIdStr)
    if playerId == nil then return end
    LightRP.eachModule("onLifeState", playerId, phase, previous)
end)

-- The protected shell raises this once the world and the player's body exist.
RegisterNetEvent("open77:session:gameplayReady", function()
    local playerId = tonumber(source)
    if playerId == nil or playerId <= 0 then return end
    LightRP.eachModule("onGameplayReady", playerId)
end)

LightRP.Config = Config
