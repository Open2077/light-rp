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

-- The client host drops a plain net event of more than 1024 JSON values
-- (kMaximumEventValues, scripting/src/ResourceHost.cpp) or ~48 KiB, and tells the
-- server nothing. On 2026-11-03 the whole state (activities, crews, missions, ...)
-- crossed it: the page never got it, kept its empty default character and reopened
-- the creator over an active character until a lone `character` push arrived. A
-- state too large for one event goes one key per event, `character` first; a key
-- still too large alone goes as a latent event (reassembled by the host and
-- delivered under the same name). Counted generously, with margin, like interact.lua.
local STATE_PLAIN_VALUES, STATE_PLAIN_BYTES, STATE_LATENT_RATE = 900, 40 * 1024, 512 * 1024
local function countStateValues(value, limit, n)
    n = (n or 0) + 1
    if type(value) ~= "table" then return n end
    for _, item in pairs(value) do
        n = countStateValues(item, limit, n + 1) -- the key, then the value
        if n > limit then return n end
    end
    return n
end
local function fitsPlainEvent(payload)
    local values = countStateValues(payload, STATE_PLAIN_VALUES)
    if values > STATE_PLAIN_VALUES then return false, values end
    if values > 200 and type(json) == "table" and type(json.encode) == "function" then
        local ok, text = pcall(json.encode, payload)
        if ok and type(text) == "string" and #text > STATE_PLAIN_BYTES then return false, values, #text end
    end
    return true, values
end
LightRP.stateFitsPlainEvent = fitsPlainEvent
local splitReported, latentReported = false, {}

-- Push one or several keys to one player. `keys` nil = the whole state.
function LightRP.state(playerId, keys)
    if playerId == nil or playerId <= 0 then return end
    local set
    if type(keys) == "string" then set = { [keys] = true }
    elseif type(keys) == "table" then
        set = {}
        for _, key in ipairs(keys) do set[key] = true end
    end
    local state = LightRP.buildState(playerId, set)
    if fitsPlainEvent(state) then
        TriggerClientEvent(E.net.state, playerId, state)
        return
    end
    local order = {}
    for key in pairs(state) do if key ~= "character" then order[#order + 1] = key end end
    table.sort(order)
    if state.character ~= nil then table.insert(order, 1, "character") end
    if not splitReported then
        splitReported = true
        LightRP.log("state for player %s: over %d values or %d bytes, sent as %d events (one per key)", tostring(playerId), STATE_PLAIN_VALUES, STATE_PLAIN_BYTES, #order)
    end
    for _, key in ipairs(order) do
        local part = { [key] = state[key] }
        local fits, values, bytes = fitsPlainEvent(part)
        if fits then
            TriggerClientEvent(E.net.state, playerId, part)
        elseif type(TriggerLatentClientEvent) == "function" then
            local id, why = TriggerLatentClientEvent(E.net.state, playerId, STATE_LATENT_RATE, part)
            if not id then
                LightRP.log("state key %s for player %s not sent (%s)", key, tostring(playerId), tostring(why))
            elseif not latentReported[key] then
                latentReported[key] = true
                LightRP.log("state key %s: %d+ values, %s bytes: sent as a latent event", key, values, tostring(bytes or "?"))
            end
        else
            LightRP.log("state key %s for player %s too large for one event and no latent transport", key, tostring(playerId))
        end
    end
end

-- The instruction quota (1M) is shared by every thread of the resource within one
-- tick, and a quota error can take the whole server down (2026-11-06, 70 players:
-- every join rebuilt the online list for everyone in one tick). Inside a thread the
-- push is spread over ticks, a few players per tick.
local BROADCAST_SLICE = 4
function LightRP.broadcastState(keys)
    local yieldable = coroutine.isyieldable()
    for index, id in ipairs(GetPlayers()) do
        LightRP.state(id, keys)
        if yieldable and index % BROADCAST_SLICE == 0 then Wait(0) end
    end
end

-- ---------------------------------------------------------------------------
-- Living with the instruction quota. Past it the host kills whichever task is running,
-- through any pcall (2026-11-06, ~90 players). Two consequences, two tools:
--
-- LightRP.every(ms, fn, name[, busyMs]): a periodic job that survives a killed run. The
-- next run is scheduled before this one starts (a `while true` thread dies with its first
-- killed pass), and a run still going (fn may Wait) is not doubled: a newer run skips
-- until it ends, or until `busyMs` (30 s) proves it was killed.
function LightRP.every(ms, fn, name, busyMs)
    ms = tonumber(ms) or 1000 -- never a tight loop on a missing setting
    local busyUntil = 0
    local function step()
        SetTimeout(ms, step)
        local now = LightRP.nowMs()
        if now < busyUntil then return end
        busyUntil = now + (busyMs or 30000)
        local ok, err = pcall(fn)
        busyUntil = 0
        if not ok then LightRP.log("%s failed: %s", tostring(name or "periodic job"), tostring(err)) end
    end
    if type(SetTimeout) == "function" then SetTimeout(ms, step) end
end

-- LightRP.expireFlags(name, table, maxMs[, field]) / LightRP.expireFlag(name, isSet, clear, maxMs):
-- a flag a killed task set and never cleared ("busy", "settling", a lock...) blocked its
-- player, shop, garage or the whole server until a restart. Every 5 s each watched flag
-- is sampled; one seen set at EVERY sample for maxMs (60 s by default; real operations
-- hold them for milliseconds) is released and logged. `field`: the flag is t[key][field].
local watchedFlags = {}
function LightRP.expireFlags(name, tbl, maxMs, field)
    watchedFlags[#watchedFlags + 1] = { name = name, tbl = tbl, maxMs = maxMs or 60000, field = field, seen = {} }
end
function LightRP.expireFlag(name, isSet, clear, maxMs)
    watchedFlags[#watchedFlags + 1] = { name = name, isSet = isSet, clear = clear, maxMs = maxMs or 60000 }
end
local FLAG_SAMPLE_MS = 5000
local function sweepFlags()
    local now = LightRP.nowMs()
    for _, w in ipairs(watchedFlags) do
        if w.tbl then
            local seen = {}
            for key, value in pairs(w.tbl) do
                local on
                if w.field == nil then on = value else on = type(value) == "table" and value[w.field] end
                if on then
                    -- continuous only if it was also set at the previous sample
                    local since = w.seen[key] or now
                    if now - since >= w.maxMs then
                        if w.field == nil then w.tbl[key] = nil else value[w.field] = nil end
                        LightRP.log("stale flag %s[%s] released after %d s (the task holding it never finished)", w.name, tostring(key), math.floor((now - since) / 1000))
                    else
                        seen[key] = since
                    end
                end
            end
            w.seen = seen
        else
            local ok, on = pcall(w.isSet)
            if ok and on then
                w.since = w.since or now
                if now - w.since >= w.maxMs then
                    pcall(w.clear)
                    LightRP.log("stale flag %s released after %d s (the task holding it never finished)", w.name, math.floor((now - w.since) / 1000))
                    w.since = nil
                end
            else
                w.since = nil
            end
        end
    end
end
LightRP.every(FLAG_SAMPLE_MS, sweepFlags, "stale flag sweep")
LightRP.sweepStaleFlags = sweepFlags -- tests

-- Who is online changed (join, leave, rename): one coalesced push at most every
-- 1.5 s from its own thread, never inside the connect/disconnect handlers.
local onlineDirty = false
function LightRP.onlineChanged() onlineDirty = true end
LightRP.every(1500, function()
    if onlineDirty then
        onlineDirty = false
        LightRP.broadcastState({ "server", "online" })
    end
end, "online list push")


-- ---------------------------------------------------------------------------
-- Actions from the page (validated server side, one handler per type)

function LightRP.action(actionType, handler)
    actions[actionType] = handler
end

-- playerId -> { [type] = stamp }: 4 actions/s per action TYPE. One shared stamp
-- per player made one click eat the next: the F1 menu sends its item, then the
-- client sends menu.close as it closes, and a periodic refresh could land just
-- before a click; the dropped one was never answered (2026-11-03, "Leave" in F1
-- did nothing inside an activity).
local actionLastMs = {}
local throttledLogMs = {}
RegisterNetEvent(E.net.action, function(payload)
    local playerId = source
    if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
    local stamps = actionLastMs[playerId]
    if stamps == nil then stamps = {}; actionLastMs[playerId] = stamps end
    local last = stamps[payload.type]
    local now = LightRP.nowMs()
    if last and now - last < 250 then
        if now - (throttledLogMs[playerId] or -60000) >= 60000 then
            throttledLogMs[playerId] = now
            LightRP.log("action %s by %s throttled (another one %d ms before)", payload.type, tostring(playerId), now - last)
        end
        return
    end
    stamps[payload.type] = now
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
    actionLastMs[playerId], throttledLogMs[playerId] = nil, nil
    -- Before any module unloads the player (inventory, wallet, character): a module that
    -- must still act on them (Dogtown's combat-log bag) does it here. A hook may await
    -- (this handler is a scheduler coroutine); onDisconnected runs once it is done.
    LightRP.eachModule("onDisconnecting", playerId, reason)
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

-- ---------------------------------------------------------------------------
-- NPCs (desk clerks, rental and job center staff) belong to the Lua VM that
-- made them. The host removes a resource's NPCs when it stops, but NOT on a hot
-- reload (`refresh`): the old VM's NPCs stay in the world and the new VM spawns
-- its own on top of them. So a VM clears every NPC this resource owns when it
-- starts (orphans of the previous generation) and when it stops.
local function clearOwnedNpcs(why)
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.all) ~= "function" then return end
    local ok, list = pcall(Open77.npcs.all)
    if not ok or type(list) ~= "table" then return end
    local removed = 0
    for _, npc in ipairs(list) do
        local id = type(npc) == "table" and (npc.id or npc.npcId) or npc
        if id and pcall(Open77.npcs.remove, id) then removed = removed + 1 end
    end
    if removed > 0 then LightRP.log("removed %d NPC(s) left by the previous generation (%s)", removed, why) end
end
clearOwnedNpcs("start")
AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then clearOwnedNpcs("stop") end
end)

LightRP.Config = Config
