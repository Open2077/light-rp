-- Entry point: request routing, rate limits, notifications, the player
-- lifecycle and the exports other resources use.
local C = NeuralConfig
local Lines, Messages, Calls, Social = Neural.lines, Neural.messages, Neural.calls, Neural.social

-- ---------------------------------------------------------------------------
-- Rate limits: a token bucket per player for every request, plus sliding
-- windows for the actions that reach other players.

local buckets, windows = {}, {}

local function nowSeconds() return GetGameTimer() / 1000 end

local function takeToken(playerId)
    local b = buckets[playerId]
    local now = nowSeconds()
    if not b then b = { tokens = C.rate.burst, at = now }; buckets[playerId] = b end
    b.tokens = math.min(C.rate.burst, b.tokens + (now - b.at) * C.rate.requestsPerSecond)
    b.at = now
    if b.tokens < 1 then return false end
    b.tokens = b.tokens - 1
    return true
end

local WINDOWS = {
    message = { seconds = 10, max = C.rate.messagesPerTenSeconds },
    dial = { seconds = 60, max = C.rate.dialsPerMinute },
    scream = { seconds = 60, max = C.rate.screamsPerMinute },
    social = { seconds = 10, max = C.rate.socialPerTenSeconds },
}

function Neural.allow(playerId, kind)
    local rule = WINDOWS[kind]
    if not rule then return true end
    windows[playerId] = windows[playerId] or {}
    local list = windows[playerId][kind] or {}
    local now = nowSeconds()
    local kept = {}
    for _, t in ipairs(list) do if now - t < rule.seconds then kept[#kept + 1] = t end end
    if #kept >= rule.max then windows[playerId][kind] = kept return false end
    kept[#kept + 1] = now
    windows[playerId][kind] = kept
    return true
end

-- ---------------------------------------------------------------------------
-- Notifications (toasts; the page adds the sound)

local toastSeq = 0
local function toast(playerId, kind, title, body, extra)
    -- no implant, nothing projected in front of the eyes
    if not Lines.isInstalled(playerId) then return end
    toastSeq = toastSeq + 1
    local t = { id = "t" .. toastSeq, kind = kind, title = title, body = body, at = Neural.nowMs() }
    for k, v in pairs(extra or {}) do t[k] = v end
    Neural.push(playerId, "nl:toast", t)
end

function Neural.notifyMessage(playerId, message, summary)
    local s = Lines.session(playerId)
    if not s then return end
    local title = summary and summary.kind == "group" and (summary.title .. " · " .. message.sender.name) or message.sender.name
    local body = message.body
    if #body > 120 then body = body:sub(1, 117) .. "..." end
    -- the page plays the message chime with the toast (and skips it on do-not-disturb)
    toast(playerId, "message", title, body, { threadId = message.threadId, number = message.sender.number })
end

-- Screamsheet pings: "@judy_a gave you Street Cred" (opens the scream, or the profile for a follow).
function Neural.notifySocial(playerId, title, body, postId, handle)
    toast(playerId, "social", title, body ~= "" and body or "Open Screamsheet", { postId = postId, handle = handle })
end

function Neural.notifyMissedCall(playerId, call, fromNumber)
    local title = "Missed neural call"
    local body
    if call and call.group then
        body = call.group.title
    else
        local number = fromNumber
        if not number and call then
            for _, p in pairs(call.participants or {}) do if p.caller then number = p.number end end
        end
        body = number and Lines.nameFor(playerId, number) or "Unknown caller"
    end
    toast(playerId, "missed", title, body)
end

-- ---------------------------------------------------------------------------
-- The implant glows: the game's blue holocall eyes while the interface is open
-- or a call is connected, so everybody around sees who is "in their Link".

local interfaceOpen = {}
local eyesOn = {}

function Neural.refreshEyes(playerId)
    if not C.calls.holocallEyes or not playerId then return end
    local want = Lines.isInstalled(playerId) and (interfaceOpen[playerId] == true or Calls.isConnected(playerId))
    if want == (eyesOn[playerId] == true) then return end
    local ok, result, why = pcall(Open77.players.setHoloCallEyes, playerId, want)
    if ok and result then eyesOn[playerId] = want or nil
    elseif want then Neural.log("holocall eyes refused for player %d: %s", playerId, tostring(why or result)) end
end

RegisterNetEvent("op77_neuralink:interface", function(open)
    local playerId = source
    interfaceOpen[playerId] = open == true or nil
    Neural.refreshEyes(playerId)
end)

-- ---------------------------------------------------------------------------
-- Requests from the page (through the client)

local OPS = {
    ["contacts.save"] = Lines.saveContact,
    ["contacts.delete"] = Lines.deleteContact,
    ["threads.open"] = Messages.open,
    ["threads.more"] = Messages.more,
    ["threads.direct"] = Messages.direct,
    ["threads.read"] = Messages.read,
    ["messages.send"] = Messages.send,
    ["messages.action"] = Messages.action,
    ["groups.create"] = Messages.createGroup,
    ["groups.rename"] = Messages.rename,
    ["groups.add"] = Messages.addToGroup,
    ["groups.remove"] = Messages.removeFromGroup,
    ["groups.leave"] = Messages.leave,
    ["call.dial"] = Calls.dial,
    ["call.group"] = Calls.dialGroup,
    ["call.accept"] = Calls.accept,
    ["call.decline"] = Calls.decline,
    ["call.hangup"] = Calls.hangup,
    ["call.mute"] = Calls.mute,
    ["call.add"] = Calls.add,
    ["recents.clear"] = Lines.clearRecents,
    ["settings.save"] = Lines.saveSettings,
}
for op, handler in pairs(Social.OPS) do OPS[op] = handler end

-- The player installs their own implant from the "no Neural-Link" screen
-- (unless config.implant.selfInstall is off: then a ripperdoc resource does it).
OPS["implant.install"] = function(playerId)
    if Lines.isInstalled(playerId) then return { implant = Lines.implantOf(playerId) } end
    if not C.implant.selfInstall then return nil, "ripperdoc_required" end
    return Lines.setInstalled(playerId, true)
end

-- Ops whose answer changes what the requester's lists show.
local REFRESH = {
    ["contacts.save"] = true, ["contacts.delete"] = true, ["groups.create"] = true,
    ["groups.rename"] = true, ["groups.add"] = true, ["groups.remove"] = true,
}

RegisterNetEvent("op77_neuralink:request", function(requestId, op, args)
    local playerId = source
    if type(requestId) ~= "number" or type(op) ~= "string" then return end
    local function reply(ok, value)
        TriggerClientEvent("op77_neuralink:reply", playerId, requestId, ok, value)
    end
    if not takeToken(playerId) then return reply(false, "rate_limited") end
    local handler = OPS[op]
    if not handler then return reply(false, "unknown_op") end
    if op ~= "implant.install" and not Lines.isInstalled(playerId) then return reply(false, "not_installed") end
    if type(args) ~= "table" then args = {} end
    local ok, data, err = pcall(handler, playerId, args)
    if not ok then
        Neural.log("op %s failed for player %d: %s", op, playerId, tostring(data))
        return reply(false, "server_error")
    end
    if data == nil then return reply(false, err or "server_error") end
    reply(true, data)
    if REFRESH[op] then
        Neural.push(playerId, "nl:patch", { contacts = Lines.contactList(playerId), threads = Messages.summaries(playerId) })
        if op == "contacts.save" or op == "contacts.delete" then
            Neural.push(playerId, "nl:patch", { recents = Lines.recents(playerId) })
        end
    end
end)

-- The page loaded (first time, after a reload or a reconnect): send everything.
RegisterNetEvent("op77_neuralink:hello", function()
    local playerId = source
    if Lines.session(playerId) then
        Neural.push(playerId, "nl:state", Lines.snapshot(playerId))
    else
        Lines.attach(playerId)
    end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle

AddEventHandler("op77_lightrp:characterReady", function(playerId, identity)
    if type(playerId) == "number" and type(identity) == "table" then Lines.attach(playerId, identity) end
end)

AddEventHandler("op77_lightrp:characterChanged", function(playerId, identity)
    if type(playerId) ~= "number" then return end
    Lines.detach(playerId, "switch")
    if type(identity) == "table" then Lines.attach(playerId, identity)
    else Neural.push(playerId, "nl:state", Lines.snapshot(playerId)) end
end)

AddEventHandler("onPlayerReady", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if playerId then Lines.attach(playerId) end
end)

AddEventHandler("onPlayerDisconnected", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if not playerId then return end
    Lines.detach(playerId, "disconnect")
    buckets[playerId], windows[playerId] = nil, nil
    interfaceOpen[playerId], eyesOn[playerId] = nil, nil
end)

-- A resource restart: re-attach everybody already in the world.
Neural.store.onReady(function()
    for _, playerId in ipairs(GetPlayers() or {}) do
        local id = tonumber(playerId)
        if id then Lines.attach(id) end
    end
end)

-- ---------------------------------------------------------------------------
-- Test harness, restricted (ACL command.neuralink.test): offline test lines that
-- write to and call a player, to exercise the interface with one client.
--   /neuralink.test line <number> <name...>        create an offline test line
--   /neuralink.test msg <from> <to> <text...>      <from> writes to <to>
--   /neuralink.test call <from> <to>               <from> rings <to> (online)
--   /neuralink.test number <playerId>              print a player's number

RegisterCommand("neuralink.test", function(source, args)
    local function say(text)
        print("[neuralink] " .. text)
        if source and source > 0 then TriggerClientEvent("open77:command:result", source, "neuralink.test", true, text) end
    end
    local verb = args[1]
    if verb == "line" and args[2] then
        local name = table.concat(args, " ", 3)
        local line, err = Lines.ensureTestLine(args[2], #name > 0 and name or ("Test " .. args[2]))
        say(line and ("test line " .. line.number .. " (" .. line.name .. ")") or ("failed: " .. tostring(err)))
    -- a button of a rich message, pressed as that player (same path and checks as a click):
    --   neuralink.test action <playerId> <messageId> <action> [number]
    elseif verb == "action" and tonumber(args[2]) and tonumber(args[3]) and args[4] then
        local result, err = Messages.action(tonumber(args[2]), { messageId = tonumber(args[3]), action = args[4], value = args[5] })
        say(result and ("action " .. args[4] .. " pressed on message " .. args[3]) or ("refused: " .. tostring(err)))
    elseif verb == "msg" and args[2] and args[3] and args[4] then
        local from, to = Lines.lineByNumber(args[2]), Lines.lineByNumber(args[3])
        if not from or not to then return say("unknown number") end
        local id, err = Messages.inject(from, to, table.concat(args, " ", 4))
        say(id and ("message " .. id .. " sent") or ("failed: " .. tostring(err)))
    elseif verb == "call" and args[2] and args[3] then
        local from, to = Lines.lineByNumber(args[2]), Lines.lineByNumber(args[3])
        if not from or not to then return say("unknown number") end
        local id, err = Calls.inject(from, to)
        say(id and ("call " .. id .. " ringing") or ("failed: " .. tostring(err)))
    elseif verb == "number" and tonumber(args[2]) then
        local s = Lines.session(tonumber(args[2]))
        say(s and (s.line.number .. " (" .. s.line.name .. ")") or "no line")
    elseif verb == "as" and tonumber(args[2]) and args[3] then
        -- Runs one page request on behalf of a connected player, exactly as the
        -- page would send it: its pushes reach that player's real interface.
        local playerId, op = tonumber(args[2]), args[3]
        local handler = OPS[op]
        if not handler then return say("unknown op " .. op) end
        local opArgs = {}
        local raw = table.concat(args, " ", 4)
        if #raw > 0 then
            local ok, decoded = pcall(json.decode, raw)
            if not ok or type(decoded) ~= "table" then return say("args must be a JSON object") end
            opArgs = decoded
        end
        local ok, data, err = pcall(handler, playerId, opArgs)
        if not ok then return say("error: " .. tostring(data)) end
        if data == nil then return say(op .. " -> refused: " .. tostring(err)) end
        if REFRESH[op] then
            Neural.push(playerId, "nl:patch", { contacts = Lines.contactList(playerId), threads = Messages.summaries(playerId) })
        end
        say(op .. " -> ok " .. json.encode(data))
    elseif verb == "state" and tonumber(args[2]) then
        local snap = Lines.snapshot(tonumber(args[2]))
        local unread = 0
        for _, t in ipairs(snap.threads or {}) do unread = unread + (t.unread or 0) end
        say(string.format("ready=%s line=%s contacts=%d threads=%d unread=%d recents=%d call=%s",
            tostring(snap.ready), snap.line and snap.line.number or "-", #snap.contacts, #snap.threads, unread,
            #snap.recents, snap.call and (snap.call.phase .. ":" .. #snap.call.participants) or "none"))
    elseif verb == "implant" and tonumber(args[2]) and (args[3] == "on" or args[3] == "off") then
        -- /neuralink.test implant <playerId> on|off: install or remove a player's implant
        local result, err = Lines.setInstalled(tonumber(args[2]), args[3] == "on")
        say(result and ("implant " .. args[3] .. " for player " .. args[2]) or ("failed: " .. tostring(err)))
    elseif (verb == "open" or verb == "close") and tonumber(args[2]) then
        -- /neuralink.test open <playerId> [app] [screen] [postId|handle|tag] | close <playerId>
        -- (open <playerId> messages <threadId>: that conversation):
        -- drive one client's interface (screenshots of a test client without pressing its keys)
        -- ("open <playerId> install" starts the implant installation directly)
        local link = verb == "open" and { app = args[3] ~= "install" and args[3] or nil, install = args[3] == "install" or nil,
            screen = args[4], postId = tonumber(args[5]), handle = args[5], tag = args[5],
            threadId = args[3] == "messages" and tonumber(args[4]) or nil } or false
        TriggerClientEvent("op77_neuralink:test", tonumber(args[2]), link)
        say(verb .. " sent to player " .. args[2])
    elseif verb == "scream" and args[2] and args[3] then
        -- /neuralink.test scream <number> <text...>: a test line screams (district "Watson")
        local from = Lines.lineByNumber(args[2])
        if not from then return say("unknown number") end
        local id, err = Social.screamAs(from, table.concat(args, " ", 3), "Watson")
        say(id and ("scream " .. id .. " posted") or ("failed: " .. tostring(err)))
    else
        say("usage: neuralink.test line|msg|call|scream|implant|open|close|number|as|state ...")
    end
end, true)

-- Screamsheet moderation, restricted (ACL command.screamsheet.delete):
--   /screamsheet.delete <screamId>     remove a scream for everybody
RegisterCommand("screamsheet.delete", function(source, args)
    local result, err = Social.remove(tonumber(args[1]), nil)
    local text = result and ("scream " .. tostring(args[1]) .. " removed") or ("failed: " .. tostring(err))
    print("[neuralink] " .. text)
    if source and source > 0 then TriggerClientEvent("open77:command:result", source, "screamsheet.delete", result ~= nil, text) end
end, true)

-- ---------------------------------------------------------------------------
-- Exports for other server resources (all read-only or system-authored)

-- The implant (a ripperdoc resource installs or removes it when config.implant.selfInstall is off).
exports("isInstalled", function(playerId) return type(playerId) == "number" and Lines.isInstalled(playerId) or false end)
exports("install", function(playerId)
    if type(playerId) ~= "number" then return false, "invalid_player" end
    local result, err = Lines.setInstalled(playerId, true)
    return result ~= nil, err
end)
-- Another server resource asks for the implant (LightRP's first day skip). Installing
-- writes the database, which an export may not wait for (export_yielded): this is an
-- event, run on our own thread. The answer is op77_neuralink:implantChanged (true),
-- sent by Lines.setInstalled, or op77_neuralink:installFailed (playerId, reason).
AddEventHandler("op77_neuralink:requestInstall", function(playerId)
    if type(playerId) ~= "number" then return end
    CreateThread(function()
        if Lines.isInstalled(playerId) then
            TriggerEvent("op77_neuralink:implantChanged", playerId, true)
            return
        end
        local called, result, err = pcall(Lines.setInstalled, playerId, true)
        if not called or result == nil then
            local reason = called and (err or "server_error") or "server_error"
            Neural.log("requested install for player %d failed: %s", playerId, tostring(called and reason or result))
            TriggerEvent("op77_neuralink:installFailed", playerId, reason)
        end
    end)
end)
exports("uninstall", function(playerId)
    if type(playerId) ~= "number" then return false, "invalid_player" end
    local result, err = Lines.setInstalled(playerId, false)
    return result ~= nil, err
end)

-- Puts a player's interface away (a gamemode panel that needs the screen and the keyboard).
exports("closeInterface", function(playerId)
    if type(playerId) ~= "number" then return false end
    TriggerClientEvent("op77_neuralink:close", playerId)
    return true
end)

-- The phone number of a connected player's current line, or nil.
exports("getNumber", function(playerId)
    local s = type(playerId) == "number" and Lines.session(playerId)
    return s and s.line.number or nil
end)

-- The connected player holding a number, or nil.
exports("getPlayerByNumber", function(number)
    return type(number) == "string" and Lines.playerOfNumber(number) or nil
end)

-- ---------------------------------------------------------------------------
-- Calls from other server resources that touch the database. An export cannot yield
-- (the database does), so they go through a host-wide event and answer on the event
-- the caller names, from a thread:
--   TriggerEvent("op77_neuralink:rpc", requestId, op, args, replyEvent)
--   -> TriggerEvent(replyEvent, requestId, ok, result1, result2)   (ok false: result1 = reason)
-- ops: npcLine { key, number, name } -> number
--      sendMessage { from, to = playerId | number, body, meta } -> messageId, threadId
--      updateMessage { id, patch } -> true
local RPC = {}
function RPC.npcLine(a)
    local line, err = Lines.ensureNpcLine(a.key, a.number, a.name)
    if not line then return nil, err end
    return line.number
end
function RPC.sendMessage(a)
    local body = a.body
    if type(body) ~= "string" or #body < 1 then return nil, "invalid_body" end
    if not Lines.validNumber(a.from) then return nil, "invalid_number" end
    local from, err = Lines.lineByNumber(a.from)
    if not from then return nil, err or "unknown_number" end
    local toLine
    if type(a.to) == "number" then
        local s = Lines.session(a.to)
        toLine = s and s.line
    elseif Lines.validNumber(a.to) then
        toLine, err = Lines.lineByNumber(a.to)
    end
    if not toLine then return nil, err or "unknown_recipient" end
    if #body > 1000 then body = body:sub(1, 997) .. "..." end
    return Messages.deliver(from, toLine, body, type(a.meta) == "table" and a.meta or nil)
end
function RPC.updateMessage(a)
    if type(tonumber(a.id)) ~= "number" or type(a.patch) ~= "table" then return nil, "invalid_request" end
    return Messages.updateMeta(tonumber(a.id), a.patch)
end
AddEventHandler("op77_neuralink:rpc", function(requestId, op, args, replyEvent)
    -- server resources only (a client's net event never reaches a plain handler, and
    -- a player source is refused anyway)
    local from = tonumber(source)
    if from and from > 0 then return end
    if type(replyEvent) ~= "string" or not replyEvent:match("^[%w_:%-]+$") then return end
    local fn = RPC[op]
    if not fn then TriggerEvent(replyEvent, requestId, false, "unknown_op") return end
    CreateThread(function()
        local ok, a, b = pcall(fn, type(args) == "table" and args or {})
        if not ok then
            Neural.log("rpc %s failed: %s", tostring(op), tostring(a))
            TriggerEvent(replyEvent, requestId, false, "server_error")
        elseif a == nil then TriggerEvent(replyEvent, requestId, false, b or "failed")
        else TriggerEvent(replyEvent, requestId, true, a, b) end
    end)
end)

-- A system toast on one player's interface (jobs, banks, dispatch...).
exports("notify", function(playerId, title, body)
    if type(playerId) ~= "number" or type(title) ~= "string" or type(body) ~= "string" then return false end
    if not Lines.session(playerId) then return false end
    toast(playerId, "info", title:sub(1, 60), body:sub(1, 240))
    return true
end)
