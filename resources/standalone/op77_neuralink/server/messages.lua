-- Conversations: direct (1:1) and group threads, messages and read state.
-- A message is stored first and fanned out to the online members after; an
-- offline member finds it in the unread count of their next snapshot.
local Store, C = Neural.store, NeuralConfig
local Lines = Neural.lines
local Messages = {}
Neural.messages = Messages

local function directKey(a, b)
    if a > b then a, b = b, a end
    return a .. ":" .. b
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
-- Characters, not bytes (names and messages are UTF-8); nil = invalid UTF-8.
local function length(s)
    if utf8 and utf8.len then return utf8.len(s) end
    return #s
end

-- Membership of one thread: { [lineId] = { lineId, role, active, lastRead } } + the thread row.
local function loadThread(threadId)
    local thread, err = Store.single("SELECT id, kind, title, updated_at FROM nl_threads WHERE id = ?", { threadId })
    if thread == nil then return nil, err end
    if not thread then return false end
    local rows = Store.query("SELECT line_id, role, active, last_read FROM nl_members WHERE thread_id = ?", { threadId })
    if not rows then return nil, "database_unavailable" end
    thread.members = {}
    for _, r in ipairs(rows) do
        thread.members[r.line_id] = { lineId = r.line_id, role = r.role, active = r.active == 1 or r.active == true, lastRead = r.last_read }
    end
    return thread
end

local function activeMembers(thread)
    local ids = {}
    for id, m in pairs(thread.members) do if m.active then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
end

-- Members as the viewer sees them (contact names, online dots).
local function memberView(viewerPlayerId, thread, lines)
    local s = Lines.session(viewerPlayerId)
    local list = {}
    for _, id in ipairs(activeMembers(thread)) do
        local line = lines[id]
        if line then
            list[#list + 1] = {
                number = line.number,
                name = Lines.nameFor(viewerPlayerId, line.number),
                isMe = s ~= nil and s.line.id == id,
                owner = thread.members[id].role == "owner",
                online = Lines.playerOfLine(id) ~= nil,
            }
        end
    end
    table.sort(list, function(a, b) if a.isMe ~= b.isMe then return a.isMe end return a.name:lower() < b.name:lower() end)
    return list
end

local function titleFor(viewerPlayerId, thread, members)
    if thread.kind == "group" then return thread.title or "Group" end
    for _, m in ipairs(members) do if not m.isMe then return m.name end end
    return "Conversation"
end

local function messageView(viewerPlayerId, row, lines)
    local s = Lines.session(viewerPlayerId)
    local sender = row.sender_line and lines[row.sender_line]
    return {
        id = row.id, threadId = row.thread_id, kind = row.kind, body = row.body, at = row.at,
        sender = sender and { number = sender.number, name = Lines.nameFor(viewerPlayerId, sender.number) } or { number = "", name = "" },
        mine = s ~= nil and row.sender_line == s.line.id,
    }
end

local function summaryOf(viewerPlayerId, thread, lines, last, unread)
    local s = Lines.session(viewerPlayerId)
    local members = memberView(viewerPlayerId, thread, lines)
    local lastView = nil
    if last then
        local sender = last.sender_line and lines[last.sender_line]
        lastView = {
            body = last.body, at = last.at, kind = last.kind,
            sender = sender and Lines.nameFor(viewerPlayerId, sender.number) or "",
            mine = s ~= nil and last.sender_line == s.line.id,
        }
    end
    return {
        id = thread.id, kind = thread.kind, title = titleFor(viewerPlayerId, thread, members), members = members,
        last = lastView, unread = unread or 0, updatedAt = thread.updated_at,
        isOwner = s ~= nil and thread.members[s.line.id] ~= nil and thread.members[s.line.id].role == "owner",
    }
end

-- ---------------------------------------------------------------------------
-- Snapshot of the viewer's threads (most recent first)

function Messages.summaries(playerId)
    local s = Lines.session(playerId)
    if not s then return {} end
    local rows = Store.query([[SELECT t.id, t.kind, t.title, t.updated_at FROM nl_members m
        JOIN nl_threads t ON t.id = m.thread_id WHERE m.line_id = ? AND m.active = 1
        ORDER BY t.updated_at DESC LIMIT ?]], { s.line.id, C.limits.threadsListed })
    if not rows or #rows == 0 then return {} end
    local ids = {}
    local threads = {}
    for _, t in ipairs(rows) do ids[#ids + 1] = t.id; t.members = {}; threads[t.id] = t end
    local ph = Store.placeholders(#ids)
    local members = Store.query("SELECT thread_id, line_id, role, active, last_read FROM nl_members WHERE thread_id IN (" .. ph .. ")", ids) or {}
    local lineIds, seen = {}, {}
    for _, m in ipairs(members) do
        threads[m.thread_id].members[m.line_id] = { lineId = m.line_id, role = m.role, active = m.active == 1 or m.active == true, lastRead = m.last_read }
        if not seen[m.line_id] then seen[m.line_id] = true; lineIds[#lineIds + 1] = m.line_id end
    end
    local lasts = {}
    local lastRows = Store.query("SELECT id, thread_id, sender_line, kind, body, at FROM nl_messages WHERE id IN (SELECT MAX(id) FROM nl_messages WHERE thread_id IN (" .. ph .. ") GROUP BY thread_id)", ids) or {}
    for _, r in ipairs(lastRows) do
        lasts[r.thread_id] = r
        if r.sender_line and not seen[r.sender_line] then seen[r.sender_line] = true; lineIds[#lineIds + 1] = r.sender_line end
    end
    local unreadParams = { s.line.id, s.line.id }
    for _, id in ipairs(ids) do unreadParams[#unreadParams + 1] = id end
    local unreadRows = Store.query([[SELECT msg.thread_id AS thread_id, COUNT(*) AS n FROM nl_messages msg
        JOIN nl_members mm ON mm.thread_id = msg.thread_id AND mm.line_id = ?
        WHERE msg.id > mm.last_read AND (msg.sender_line IS NULL OR msg.sender_line <> ?) AND msg.thread_id IN (]] .. ph .. [[)
        GROUP BY msg.thread_id]], unreadParams) or {}
    local unread = {}
    for _, r in ipairs(unreadRows) do unread[r.thread_id] = tonumber(r.n) or 0 end
    local lines = Lines.linesByIds(lineIds)
    local out = {}
    for _, t in ipairs(rows) do out[#out + 1] = summaryOf(playerId, threads[t.id], lines, lasts[t.id], unread[t.id]) end
    return out
end

local function summaryFor(playerId, thread)
    local s = Lines.session(playerId)
    if not s then return nil end
    local ids = activeMembers(thread)
    local last = Store.single("SELECT id, thread_id, sender_line, kind, body, at FROM nl_messages WHERE thread_id = ? ORDER BY id DESC LIMIT 1", { thread.id }) or nil
    if last and last.sender_line then ids[#ids + 1] = last.sender_line end
    local me = thread.members[s.line.id]
    local unread = Store.single([[SELECT COUNT(*) AS n FROM nl_messages WHERE thread_id = ? AND id > ?
        AND (sender_line IS NULL OR sender_line <> ?)]], { thread.id, me and me.lastRead or 0, s.line.id })
    return summaryOf(playerId, thread, Lines.linesByIds(ids), last or nil, unread and tonumber(unread.n) or 0)
end

-- ---------------------------------------------------------------------------
-- Reading

local function requireMember(playerId, threadId)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    threadId = tonumber(threadId)
    if not threadId then return nil, "not_member" end
    local thread, err = loadThread(threadId)
    if thread == nil then return nil, err end
    if not thread or not thread.members[s.line.id] or not thread.members[s.line.id].active then return nil, "not_member" end
    return thread, s
end

local function sendPage(playerId, thread, beforeId)
    local rows
    if beforeId then
        rows = Store.query("SELECT id, thread_id, sender_line, kind, body, at FROM nl_messages WHERE thread_id = ? AND id < ? ORDER BY id DESC LIMIT ?",
            { thread.id, beforeId, C.limits.messagesPage + 1 })
    else
        rows = Store.query("SELECT id, thread_id, sender_line, kind, body, at FROM nl_messages WHERE thread_id = ? ORDER BY id DESC LIMIT ?",
            { thread.id, C.limits.messagesPage + 1 })
    end
    if not rows then return nil, "database_unavailable" end
    local hasMore = #rows > C.limits.messagesPage
    if hasMore then rows[#rows] = nil end
    local ids, seen = activeMembers(thread), {}
    for _, id in ipairs(ids) do seen[id] = true end
    for _, r in ipairs(rows) do if r.sender_line and not seen[r.sender_line] then seen[r.sender_line] = true; ids[#ids + 1] = r.sender_line end end
    local lines = Lines.linesByIds(ids)
    local messages = {}
    for i = #rows, 1, -1 do messages[#messages + 1] = messageView(playerId, rows[i], lines) end
    Neural.push(playerId, "nl:thread", { threadId = thread.id, messages = messages, members = memberView(playerId, thread, lines),
        hasMore = hasMore, prepend = beforeId ~= nil })
    return true
end

function Messages.markRead(playerId, thread, s)
    local newest = Store.single("SELECT MAX(id) AS id FROM nl_messages WHERE thread_id = ?", { thread.id })
    local id = newest and tonumber(newest.id) or 0
    if id > (thread.members[s.line.id].lastRead or 0) then
        Store.update("UPDATE nl_members SET last_read = ? WHERE thread_id = ? AND line_id = ?", { id, thread.id, s.line.id })
        thread.members[s.line.id].lastRead = id
    end
end

function Messages.open(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    local ok, err = sendPage(playerId, thread, nil)
    if not ok then return nil, err end
    Messages.markRead(playerId, thread, s)
    return {}
end

function Messages.more(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    local before = tonumber(args.beforeId)
    if not before then return nil, "invalid_request" end
    local ok, err = sendPage(playerId, thread, before)
    if not ok then return nil, err end
    return {}
end

function Messages.read(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    Messages.markRead(playerId, thread, s)
    return {}
end

-- ---------------------------------------------------------------------------
-- Writing

-- Stores a message and pushes it (with the fresh summary) to every online member.
local function post(thread, senderLineId, kind, body)
    local at = Neural.nowMs()
    -- The id comes from the INSERT itself: re-reading "the newest" could pick a
    -- message another member posted in the same instant.
    local id, err = Store.insert("INSERT INTO nl_messages (thread_id, sender_line, kind, body, at) VALUES (?, ?, ?, ?, ?)",
        { thread.id, senderLineId, kind, body, at })
    if not id then return nil, err end
    Store.update("UPDATE nl_threads SET updated_at = ? WHERE id = ?", { at, thread.id })
    local row = { id = id, thread_id = thread.id, sender_line = senderLineId, kind = kind, body = body, at = at }
    thread.updated_at = at
    if senderLineId and thread.members[senderLineId] then
        -- the sender has read their own message
        Store.update("UPDATE nl_members SET last_read = ? WHERE thread_id = ? AND line_id = ?", { row.id, thread.id, senderLineId })
        thread.members[senderLineId].lastRead = row.id
    end
    local ids = activeMembers(thread)
    if senderLineId then ids[#ids + 1] = senderLineId end
    local lines = Lines.linesByIds(ids)
    for _, lineId in ipairs(activeMembers(thread)) do
        local pid = Lines.playerOfLine(lineId)
        if pid then
            local summary = summaryFor(pid, thread)
            local message = messageView(pid, row, lines)
            Neural.push(pid, "nl:message", { message = message, summary = summary })
            if kind == "text" and lineId ~= senderLineId then Neural.notifyMessage(pid, message, summary) end
        end
    end
    return row.id
end
Messages.post = post

local function addMember(thread, lineId, role)
    local at = Neural.nowMs()
    local ok, err = Store.update([[INSERT INTO nl_members (thread_id, line_id, role, active, last_read, joined_at)
        VALUES (?, ?, ?, 1, 0, ?) ON DUPLICATE KEY UPDATE active = 1, role = VALUES(role)]], { thread.id, lineId, role, at })
    if not ok then return nil, err end
    thread.members[lineId] = { lineId = lineId, role = role, active = true, lastRead = 0 }
    return true
end

function Messages.direct(playerId, args)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    if args.number == s.line.number then return nil, "self" end
    local other, err = Lines.lineByNumber(args.number)
    if other == nil then return nil, err end
    if not other then return nil, "unknown_number" end
    local key = directKey(s.line.id, other.id)
    local row = Store.single("SELECT id FROM nl_threads WHERE direct_key = ?", { key })
    if row == nil then return nil, "database_unavailable" end
    local threadId = row and row.id
    if not threadId then
        local now = Neural.nowMs()
        threadId, err = Store.insert("INSERT INTO nl_threads (kind, title, direct_key, created_at, updated_at) VALUES ('direct', NULL, ?, ?, ?)", { key, now, now })
        if not threadId then
            if err ~= "conflict" then return nil, err end
            local again = Store.single("SELECT id FROM nl_threads WHERE direct_key = ?", { key })
            if not again then return nil, "database_unavailable" end
            threadId = again.id
        end
    end
    local thread = loadThread(threadId)
    if not thread then return nil, "database_unavailable" end
    -- a direct thread someone "left" (deleted) comes back for both sides
    for _, id in ipairs({ s.line.id, other.id }) do
        if not thread.members[id] or not thread.members[id].active then
            local ok, addErr = addMember(thread, id, "member")
            if not ok then return nil, addErr end
        end
    end
    Neural.push(playerId, "nl:patch", { threads = Messages.summaries(playerId) })
    return { threadId = threadId }
end

function Messages.send(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    if type(args.body) ~= "string" then return nil, "invalid_body" end
    local body = trim(args.body)
    if #body < 1 or length(body) == nil or length(body) > C.limits.bodyLength then return nil, "invalid_body" end
    if not Neural.allow(playerId, "message") then return nil, "rate_limited" end
    local id, err = post(thread, s.line.id, "text", body)
    if not id then return nil, err end
    return { id = id }
end

local function systemMessage(thread, text)
    return post(thread, nil, "system", text)
end

function Messages.createGroup(playerId, args)
    local s = Lines.session(playerId)
    if not s then return nil, "no_line" end
    local title = type(args.title) == "string" and trim(args.title) or ""
    if #title < 1 or length(title) == nil or length(title) > C.limits.groupTitle then return nil, "invalid_name" end
    if type(args.numbers) ~= "table" then return nil, "invalid_number" end
    local lines, seen = {}, { [s.line.number] = true }
    for _, number in ipairs(args.numbers) do
        if not Lines.validNumber(number) then return nil, "invalid_number" end
        if not seen[number] then
            seen[number] = true
            local line, err = Lines.lineByNumber(number)
            if line == nil then return nil, err end
            if not line then return nil, "unknown_number" end
            lines[#lines + 1] = line
        end
    end
    if #lines < 2 then return nil, "group_too_small" end
    if #lines + 1 > C.limits.groupMembers then return nil, "group_full" end
    local now = Neural.nowMs()
    local threadId, err = Store.insert("INSERT INTO nl_threads (kind, title, direct_key, created_at, updated_at) VALUES ('group', ?, NULL, ?, ?)", { title, now, now })
    if not threadId then return nil, err end
    local thread = { id = threadId, kind = "group", title = title, updated_at = now, members = {} }
    local ok, addErr = addMember(thread, s.line.id, "owner")
    if not ok then return nil, addErr end
    for _, line in ipairs(lines) do addMember(thread, line.id, "member") end
    systemMessage(thread, string.format("%s created the group \"%s\".", s.line.name, title))
    return { threadId = threadId }
end

local function requireOwner(playerId, threadId)
    local thread, s = requireMember(playerId, threadId)
    if not thread then return nil, s end
    if thread.kind ~= "group" then return nil, "not_group" end
    if thread.members[s.line.id].role ~= "owner" then return nil, "not_owner" end
    return thread, s
end

function Messages.rename(playerId, args)
    local thread, s = requireOwner(playerId, args.threadId)
    if not thread then return nil, s end
    local title = type(args.title) == "string" and trim(args.title) or ""
    if #title < 1 or length(title) == nil or length(title) > C.limits.groupTitle then return nil, "invalid_name" end
    local ok, err = Store.update("UPDATE nl_threads SET title = ? WHERE id = ?", { title, thread.id })
    if not ok then return nil, err end
    thread.title = title
    systemMessage(thread, string.format("%s renamed the group to \"%s\".", s.line.name, title))
    return {}
end

function Messages.addToGroup(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    if thread.kind ~= "group" then return nil, "not_group" end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    if #activeMembers(thread) >= C.limits.groupMembers then return nil, "group_full" end
    local line, err = Lines.lineByNumber(args.number)
    if line == nil then return nil, err end
    if not line then return nil, "unknown_number" end
    if thread.members[line.id] and thread.members[line.id].active then return nil, "already_member" end
    local ok, addErr = addMember(thread, line.id, "member")
    if not ok then return nil, addErr end
    systemMessage(thread, string.format("%s added %s.", s.line.name, line.name))
    return {}
end

function Messages.removeFromGroup(playerId, args)
    local thread, s = requireOwner(playerId, args.threadId)
    if not thread then return nil, s end
    if not Lines.validNumber(args.number) then return nil, "invalid_number" end
    local line, err = Lines.lineByNumber(args.number)
    if line == nil then return nil, err end
    if not line or not thread.members[line.id] or not thread.members[line.id].active then return nil, "not_member" end
    if line.id == s.line.id then return nil, "self" end
    systemMessage(thread, string.format("%s removed %s.", s.line.name, line.name))
    local ok, upErr = Store.update("UPDATE nl_members SET active = 0 WHERE thread_id = ? AND line_id = ?", { thread.id, line.id })
    if not ok then return nil, upErr end
    thread.members[line.id].active = false
    local pid = Lines.playerOfLine(line.id)
    if pid then Neural.push(pid, "nl:patch", { threads = Messages.summaries(pid) }) end
    return {}
end

function Messages.leave(playerId, args)
    local thread, s = requireMember(playerId, args.threadId)
    if not thread then return nil, s end
    if thread.kind == "group" then
        systemMessage(thread, string.format("%s left the group.", s.line.name))
        -- an owner who leaves hands the group to the longest-standing member
        if thread.members[s.line.id].role == "owner" then
            local heir
            for _, id in ipairs(activeMembers(thread)) do if id ~= s.line.id then heir = heir or id end end
            if heir then
                Store.update("UPDATE nl_members SET role = 'owner' WHERE thread_id = ? AND line_id = ?", { thread.id, heir })
                thread.members[heir].role = "owner"
            end
        end
    end
    local ok, err = Store.update("UPDATE nl_members SET active = 0, role = 'member' WHERE thread_id = ? AND line_id = ?", { thread.id, s.line.id })
    if not ok then return nil, err end
    Neural.push(playerId, "nl:patch", { threads = Messages.summaries(playerId) })
    return {}
end

-- Test harness (restricted command): a line writes to another, online or not.
function Messages.inject(fromLine, toLine, body)
    local key = directKey(fromLine.id, toLine.id)
    local row = Store.single("SELECT id FROM nl_threads WHERE direct_key = ?", { key })
    if row == nil then return nil, "database_unavailable" end
    local threadId = row and row.id
    if not threadId then
        local now = Neural.nowMs()
        local err
        threadId, err = Store.insert("INSERT INTO nl_threads (kind, title, direct_key, created_at, updated_at) VALUES ('direct', NULL, ?, ?, ?)", { key, now, now })
        if not threadId then return nil, err end
    end
    local thread = loadThread(threadId)
    if not thread then return nil, "database_unavailable" end
    for _, id in ipairs({ fromLine.id, toLine.id }) do
        if not thread.members[id] or not thread.members[id].active then addMember(thread, id, "member") end
    end
    return post(thread, fromLine.id, "text", body)
end

-- Active members' line ids of a group thread the player belongs to (group calls).
function Messages.groupLines(playerId, threadId)
    local thread, s = requireMember(playerId, threadId)
    if not thread then return nil, s end
    if thread.kind ~= "group" then return nil, "not_group" end
    return activeMembers(thread), thread, s
end
