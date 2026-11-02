-- Offline test of rich messages (server/messages.lua): a resource's line (an NPC
-- fixer) texts a player with a meta (card, buttons, location), the player presses a
-- button (messages.action -> op77_neuralink:messageAction), the resource resolves it
-- (updateMeta -> nl:messageUpdate), a contact-input button needs a valid number, a
-- reply to an NPC line raises op77_neuralink:npcMessage.
-- Run from the resource folder: lua54 tests/rich_messages_test.lua
local failures, checks = 0, 0
local function check(cond, label)
    checks = checks + 1
    if not cond then failures = failures + 1; print("FAIL " .. label) end
end

local events = {}
function TriggerEvent(name, ...) events[#events + 1] = { name = name, args = { ... } } end
json = {
    encode = function(v)
        local function enc(x)
            if type(x) == "table" then
                if #x > 0 then local p = {} for _, y in ipairs(x) do p[#p + 1] = enc(y) end return "[" .. table.concat(p, ",") .. "]" end
                local p = {} for k, y in pairs(x) do p[#p + 1] = string.format("%q:%s", tostring(k), enc(y)) end table.sort(p) return "{" .. table.concat(p, ",") .. "}"
            elseif type(x) == "string" then return string.format("%q", x) end
            return tostring(x)
        end
        return enc(v)
    end,
}
-- the decoder only needs to read back what encode wrote: keep the tables by text
local encoded = {}
local rawEncode = json.encode
json.encode = function(v) local s = rawEncode(v); encoded[s] = v; return s end
json.decode = function(s) local v = encoded[s]; if not v then error("unknown json") end
    local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, x in pairs(t) do o[k] = copy(x) end return o end
    return copy(v) end

-- ---------------------------------------------------------------------------
-- In-memory store answering the statements of messages.lua

local db = { threads = {}, members = {}, messages = {} }
local seq = { threads = 0, messages = 0 }
local function membersOf(threadId)
    local out = {}
    for _, m in ipairs(db.members) do if m.thread_id == threadId then out[#out + 1] = m end end
    return out
end
local Store = { ready = true }
function Store.placeholders(n) return string.rep("?", n, ",") end
function Store.single(sql, p)
    if sql:find("FROM nl_threads WHERE direct_key") then for _, t in pairs(db.threads) do if t.direct_key == p[1] then return { id = t.id } end end return false end
    if sql:find("FROM nl_threads WHERE id") then local t = db.threads[p[1]]; return t and { id = t.id, kind = t.kind, title = t.title, updated_at = t.updated_at } or false end
    if sql:find("FROM nl_messages WHERE id = ?", 1, true) then local m = db.messages[p[1]]; if not m then return false end local c = {} for k, v in pairs(m) do c[k] = v end return c end
    if sql:find("ORDER BY id DESC LIMIT 1") then local best; for _, m in pairs(db.messages) do if m.thread_id == p[1] and (not best or m.id > best.id) then best = m end end if not best then return false end local c = {} for k, v in pairs(best) do c[k] = v end return c end
    if sql:find("COUNT%(%*%)") then return { n = 0 } end
    if sql:find("MAX%(id%)") then local n = 0 for _, m in pairs(db.messages) do if m.thread_id == p[1] and m.id > n then n = m.id end end return { id = n } end
    error("unexpected single: " .. sql)
end
function Store.query(sql, p)
    if sql:find("FROM nl_members WHERE thread_id = ?", 1, true) then return membersOf(p[1]) end
    error("unexpected query: " .. sql)
end
function Store.insert(sql, p)
    if sql:find("INTO nl_threads") then seq.threads = seq.threads + 1; db.threads[seq.threads] = { id = seq.threads, kind = "direct", direct_key = p[1], updated_at = p[3] }; return seq.threads end
    if sql:find("INTO nl_messages") then
        seq.messages = seq.messages + 1
        db.messages[seq.messages] = { id = seq.messages, thread_id = p[1], sender_line = p[2], kind = p[3], body = p[4], at = p[5], meta = sql:find("meta") and p[6] or nil }
        return seq.messages
    end
    error("unexpected insert: " .. sql)
end
function Store.update(sql, p)
    if sql:find("INSERT INTO nl_members") then
        for _, m in ipairs(db.members) do if m.thread_id == p[1] and m.line_id == p[2] then m.active = 1; return true end end
        db.members[#db.members + 1] = { thread_id = p[1], line_id = p[2], role = p[3], active = 1, last_read = 0 }
        return true
    end
    if sql:find("UPDATE nl_messages SET meta") then db.messages[p[2]].meta = p[1]; return true end
    return true
end

-- lines: 1 = the fixer's NPC line, 10/20 = players 1 and 2
local LINES = { [1] = { id = 1, number = "555-0619", name = "Nix" }, [10] = { id = 10, number = "555-0001", name = "Jack" }, [20] = { id = 20, number = "555-0002", name = "Kei" } }
local Lines = {
    session = function(pid) local l = LINES[pid * 10]; return l and { line = l, contacts = {} } end,
    playerOfLine = function(id) return id >= 10 and id / 10 or nil end,
    nameFor = function(_, number) for _, l in pairs(LINES) do if l.number == number then return l.name end end return number end,
    linesByIds = function(ids) local o = {} for _, id in ipairs(ids) do o[id] = LINES[id] end return o end,
    isNpcLine = function(id) return id == 1 and "fixer_nix" or nil end,
    validNumber = function(n) return type(n) == "string" and n:match("^%d%d%d%-%d%d%d%d$") ~= nil end,
}
local pushes, toasts = {}, {}
Neural = {
    store = Store, lines = Lines, nowMs = function() return 1000 end,
    push = function(pid, name, payload) pushes[#pushes + 1] = { pid = pid, name = name, payload = payload } end,
    notifyMessage = function(pid, message) toasts[#toasts + 1] = { pid = pid, message = message } end,
    allow = function() return true end,
}
NeuralConfig = { limits = { bodyLength = 500, threadsListed = 50, messagesPage = 40 } }
dofile("server/messages.lua")
local Messages = Neural.messages

-- ---------------------------------------------------------------------------

local meta = { source = "op77_lightrp", ref = "gig:1:1", card = { title = "Burn Notice", tag = "GIG" },
    actions = { { id = "accept", label = "Take the job", style = "primary" }, { id = "share", label = "Share", input = "contact" } },
    location = { x = 1, y = 2, z = 3, label = "the meet point" } }
local id, threadId = Messages.deliver(LINES[1], LINES[10], "Got work for you.", meta)
check(type(id) == "number" and type(threadId) == "number", "deliver returns message and thread ids")
check(db.messages[id].meta ~= nil, "meta stored in its column")
local pushed
for _, p in ipairs(pushes) do if p.name == "nl:message" and p.pid == 1 then pushed = p.payload.message end end
check(pushed and pushed.meta and pushed.meta.card.title == "Burn Notice" and pushed.meta.actions[1].id == "accept", "the page gets the meta")
check(pushed and pushed.sender.name == "Nix" and pushed.sender.npc == true, "the sender is the NPC line, flagged")
check(#toasts == 1 and toasts[1].pid == 1, "a rich text still toasts")

-- a button pressed by the recipient
events = {}
local r, err = Messages.action(1, { messageId = id, action = "accept" })
check(r ~= nil, "action accepted: " .. tostring(err))
check(#events == 1 and events[1].name == "op77_neuralink:messageAction" and events[1].args[1] == 1, "the owner resource hears the button")
local ev = events[1] and events[1].args[2] or {}
check(ev.action == "accept" and ev.ref == "gig:1:1" and ev.source == "op77_lightrp" and ev.messageId == id, "with its ref and source")
-- unknown action, outsider, contact input
check(select(2, Messages.action(1, { messageId = id, action = "nope" })) == "no_action", "unknown action refused")
check(select(2, Messages.action(2, { messageId = id, action = "accept" })) == "not_member", "a non-member cannot press")
check(select(2, Messages.action(1, { messageId = id, action = "share", value = "nope" })) == "invalid_number", "share needs a number")
check(select(2, Messages.action(1, { messageId = id, action = "share", value = "555-0001" })) == "self", "not your own number")
events = {}
check(Messages.action(1, { messageId = id, action = "share", value = "555-0002" }) ~= nil and events[1].args[2].value == "555-0002", "share carries the number")

-- the resource resolves it
pushes = {}
check(Messages.updateMeta(id, { resolved = { label = "Job taken", tone = "ok" } }) == true, "updateMeta")
local upd
for _, p in ipairs(pushes) do if p.name == "nl:messageUpdate" then upd = p.payload.message end end
check(upd and upd.meta.resolved.label == "Job taken" and upd.meta.card.title == "Burn Notice", "pushed again with the merged meta")
check(select(2, Messages.action(1, { messageId = id, action = "accept" })) == "already_answered", "answered buttons are closed")
check(Messages.updateMeta(id, { resolved = false }) and db.messages[id].meta and json.decode(db.messages[id].meta).resolved == nil, "false removes a key")
check(select(2, Messages.updateMeta(999, {})) == "unknown_message", "unknown message")

-- a plain reply to the NPC line
events = {}
check(Messages.send(1, { threadId = threadId, body = "who is this?" }) ~= nil, "reply sent")
local npcEv
for _, e in ipairs(events) do if e.name == "op77_neuralink:npcMessage" then npcEv = e.args end end
check(npcEv and npcEv[1] == 1 and npcEv[2].npc == "fixer_nix" and npcEv[2].body == "who is this?", "the NPC's resource hears the reply")

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then error("rich messages test failed") end
print("PASS: rich messages (deliver with meta, npc sender, action event + guards, contact input, updateMeta push + close, npc reply hook)")
