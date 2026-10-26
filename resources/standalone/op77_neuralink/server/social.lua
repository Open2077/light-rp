-- Screamsheet: the players' social feed. In Night City lore screamsheets are
-- the printed news sheets; on the Neural-Link every citizen prints their own.
--   scream = a post         cred  = Street Cred, the like
--   echo   = a repost       quote = an echo with a comment
--   pings  = notifications  heat  = trending tags and districts
-- One profile per line (so per character), created with a handle derived from
-- the character name the first time it is needed. Counters (replies, echoes,
-- cred) live on the scream row; everything a viewer sees is hydrated here.
local Store, C = Neural.store, NeuralConfig
local S = C.social
local Lines = Neural.lines
local Social = {}
Neural.social = Social

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function length(s)
    if utf8 and utf8.len then return utf8.len(s) end
    return #s
end
local function int(v) return math.floor(tonumber(v) or 0) end
local function truthy(v) return v == 1 or v == true or v == "1" end
-- "before the newest": a cursor above every id that survives the MySQL bridge (2^53 - 1).
local NO_CURSOR = 9007199254740991

-- ---------------------------------------------------------------------------
-- Text: handles, #tags and @mentions

local HANDLE_PATTERN = "^[a-z0-9_]+$"

function Social.validHandle(handle)
    return type(handle) == "string" and #handle >= 3 and #handle <= 16 and handle:match(HANDLE_PATTERN) ~= nil
end

-- "Jack Rob" -> "jack_rob", "Rogue Amendiares" -> "rogue_a": 3 to 12 characters,
-- so a "_NNN" suffix still fits in 16.
function Social.handleBase(name)
    local base = tostring(name or ""):lower():gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if #base > 12 then
        local first, last = base:match("^([^_]+)_.-([^_]+)$")
        if first then base = first:sub(1, 10) .. "_" .. last:sub(1, 1) else base = base:sub(1, 12) end
    end
    if #base < 3 then base = "citizen" end
    return base
end

-- Unique lowercase #tags, ASCII letters, digits and underscores, 2..32 long.
function Social.parseTags(body)
    local tags, seen = {}, {}
    for tag in body:gmatch("#([%w_]+)") do
        tag = tag:lower()
        if #tag >= 2 and #tag <= 32 and not seen[tag] and tag:match(HANDLE_PATTERN) then
            seen[tag] = true
            tags[#tags + 1] = tag
            if #tags >= S.tagsPerScream then break end
        end
    end
    return tags
end

function Social.parseMentions(body)
    local handles, seen = {}, {}
    for handle in body:gmatch("@([%w_]+)") do
        handle = handle:lower()
        if Social.validHandle(handle) and not seen[handle] then
            seen[handle] = true
            handles[#handles + 1] = handle
            if #handles >= S.mentionsPerScream then break end
        end
    end
    return handles
end

-- A district name from the page (where the player stands), or nil.
function Social.cleanDistrict(district)
    if type(district) ~= "string" then return nil end
    district = trim(district:gsub("[%c<>]", ""))
    if district == "" or district:find("^LocKey") or length(district) == nil or length(district) > 40 then return nil end
    return district
end

-- INSERT with optional columns: the MySQL bridge wants contiguous positional
-- parameters, so a nil value becomes a literal NULL instead of a hole.
--   insertRow("t", { { "a", 1 }, { "b", nil } })
local function insertRow(tbl, columns)
    local names, marks, params = {}, {}, {}
    for _, c in ipairs(columns) do
        names[#names + 1] = c[1]
        if c[2] == nil then marks[#marks + 1] = "NULL" else marks[#marks + 1] = "?"; params[#params + 1] = c[2] end
    end
    return Store.insert("INSERT INTO " .. tbl .. " (" .. table.concat(names, ", ") .. ") VALUES (" .. table.concat(marks, ", ") .. ")", params)
end

-- LIKE pattern for a search term, wildcards escaped.
local function likeOf(q) return "%" .. q:gsub("[\\%%_]", "\\%0") .. "%" end

-- ---------------------------------------------------------------------------
-- Profiles

local function lineOf(playerId)
    local s = Lines.session(playerId)
    return s and s.line or nil, s
end

local function profileRow(lineId)
    return Store.single("SELECT line_id, handle, name, bio, created_at FROM nl_social_profiles WHERE line_id = ?", { lineId })
end

-- The profile of a line, created on first use. nil, err on a database failure.
function Social.ensureProfile(line)
    local row, err = profileRow(line.id)
    if row == nil then return nil, err end
    if row then return row end
    local base = Social.handleBase(line.name)
    local name = tostring(line.name or line.number):sub(1, S.nameLength)
    for attempt = 0, 12 do
        local handle = attempt == 0 and base or (base .. "_" .. math.random(100, 999))
        local ok, insertErr = Store.insert("INSERT INTO nl_social_profiles (line_id, handle, name, bio, created_at) VALUES (?, ?, ?, '', ?)",
            { line.id, handle, name, Neural.nowMs() })
        if ok ~= nil then return profileRow(line.id) end
        if insertErr ~= "conflict" then return nil, insertErr end
        -- the handle was taken, or the profile appeared meanwhile (two requests at once)
        local again = profileRow(line.id)
        if again then return again end
    end
    return nil, "handle_taken"
end

local function unreadOf(lineId)
    local row = Store.single("SELECT COUNT(*) AS n FROM nl_social_pings WHERE line_id = ? AND is_read = 0", { lineId })
    return row and int(row.n) or 0
end

-- { handle, unread } for the snapshot (cached on the session).
function Social.summary(playerId)
    local line, s = lineOf(playerId)
    if not line then return nil end
    if s.social then return s.social end
    local profile = Social.ensureProfile(line)
    if not profile then return nil end
    s.social = { handle = profile.handle, unread = unreadOf(line.id) }
    return s.social
end

local function setUnread(lineId, unread)
    local pid = Lines.playerOfLine(lineId)
    local s = pid and Lines.session(pid)
    if s then
        s.social = s.social or { handle = "", unread = 0 }
        s.social.unread = unread
    end
    return pid
end

-- Authors by line id: { [lineId] = { handle, name, seed, online } }.
local function authorsOf(lineIds)
    local out, ids, seen = {}, {}, {}
    for _, id in ipairs(lineIds) do
        id = int(id)
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    for i = 1, #ids, 60 do
        local chunk = { table.unpack(ids, i, math.min(#ids, i + 59)) }
        local rows = Store.query([[SELECT pr.line_id AS line_id, pr.handle AS handle, pr.name AS name, l.number AS number
            FROM nl_social_profiles pr JOIN nl_lines l ON l.id = pr.line_id
            WHERE pr.line_id IN (]] .. Store.placeholders(#chunk) .. ")", chunk)
        for _, r in ipairs(rows or {}) do
            local id = int(r.line_id)
            out[id] = { handle = r.handle, name = r.name, seed = r.number, online = Lines.playerOfLine(id) ~= nil }
        end
    end
    return out
end

local function countOf(sql, params)
    local row = Store.single(sql, params)
    return row and int(row.n) or 0
end

local function profileView(row, viewerLine)
    local lineId = int(row.line_id)
    local number = Store.single("SELECT number FROM nl_lines WHERE id = ?", { lineId })
    local credRow = Store.single("SELECT COALESCE(SUM(cred), 0) AS n FROM nl_social_posts WHERE line_id = ? AND deleted = 0", { lineId })
    local isMe = viewerLine ~= nil and viewerLine.id == lineId
    return {
        handle = row.handle, name = row.name, seed = number and number.number or row.handle,
        online = Lines.playerOfLine(lineId) ~= nil,
        bio = row.bio or "", joinedAt = int(row.created_at),
        posts = countOf("SELECT COUNT(*) AS n FROM nl_social_posts WHERE line_id = ? AND deleted = 0 AND NOT (echo_of IS NOT NULL AND body = '')", { lineId }),
        followers = countOf("SELECT COUNT(*) AS n FROM nl_social_follows WHERE followee = ?", { lineId }),
        following = countOf("SELECT COUNT(*) AS n FROM nl_social_follows WHERE follower = ?", { lineId }),
        cred = credRow and int(credRow.n) or 0,
        isMe = isMe,
        followed = not isMe and viewerLine ~= nil
            and Store.single("SELECT 1 AS x FROM nl_social_follows WHERE follower = ? AND followee = ?", { viewerLine.id, lineId }) and true or false,
        followsMe = not isMe and viewerLine ~= nil
            and Store.single("SELECT 1 AS x FROM nl_social_follows WHERE follower = ? AND followee = ?", { lineId, viewerLine.id }) and true or false,
    }
end

local function profileByHandle(handle)
    if not Social.validHandle(handle) then return false end
    return Store.single("SELECT line_id, handle, name, bio, created_at FROM nl_social_profiles WHERE handle = ?", { handle })
end

-- ---------------------------------------------------------------------------
-- Screams as one viewer sees them

local POST_COLUMNS = "p.id, p.line_id, p.body, p.reply_to, p.echo_of, p.district, p.created_at, p.deleted, p.replies, p.echoes, p.cred"

local function rowsByIds(ids)
    if #ids == 0 then return {} end
    local out = {}
    for i = 1, #ids, 60 do
        local chunk = { table.unpack(ids, i, math.min(#ids, i + 59)) }
        for _, r in ipairs(Store.query("SELECT " .. POST_COLUMNS .. " FROM nl_social_posts p WHERE p.id IN (" .. Store.placeholders(#chunk) .. ")", chunk) or {}) do
            out[int(r.id)] = r
        end
    end
    return out
end

-- Rows (any order) -> SocialPost list in the same order, for viewerLine (may be nil).
-- depth 0 hydrates echoOf one level; the embedded original is built with depth 1.
local function hydrate(rows, viewerLine, depth)
    depth = depth or 0
    if #rows == 0 then return {} end
    local ids, lineIds, echoIds, parentIds = {}, {}, {}, {}
    for _, r in ipairs(rows) do
        ids[#ids + 1] = int(r.id)
        lineIds[#lineIds + 1] = int(r.line_id)
        if r.echo_of and depth == 0 then echoIds[#echoIds + 1] = int(r.echo_of) end
        if r.reply_to then parentIds[#parentIds + 1] = int(r.reply_to) end
    end
    local authors = authorsOf(lineIds)

    -- what the viewer did on these screams
    local credded, echoed = {}, {}
    if viewerLine then
        local ph = Store.placeholders(#ids)
        local params = { viewerLine.id }
        for _, id in ipairs(ids) do params[#params + 1] = id end
        for _, r in ipairs(Store.query("SELECT post_id FROM nl_social_cred WHERE line_id = ? AND post_id IN (" .. ph .. ")", params) or {}) do
            credded[int(r.post_id)] = true
        end
        for _, r in ipairs(Store.query("SELECT echo_of FROM nl_social_posts WHERE line_id = ? AND deleted = 0 AND body = '' AND echo_of IN (" .. ph .. ")", params) or {}) do
            echoed[int(r.echo_of)] = true
        end
    end

    -- the handle each reply answers
    local parentHandles = {}
    if #parentIds > 0 then
        local parents = rowsByIds(parentIds)
        local parentLines = {}
        for _, p in pairs(parents) do parentLines[#parentLines + 1] = int(p.line_id) end
        local parentAuthors = authorsOf(parentLines)
        for id, p in pairs(parents) do
            local a = parentAuthors[int(p.line_id)]
            parentHandles[id] = a and a.handle or "unknown"
        end
    end

    -- the original of each echo / quote
    local originals = {}
    if #echoIds > 0 then
        local list = {}
        for _, r in pairs(rowsByIds(echoIds)) do if not truthy(r.deleted) then list[#list + 1] = r end end
        for _, post in ipairs(hydrate(list, viewerLine, 1)) do originals[post.id] = post end
    end

    local out = {}
    for _, r in ipairs(rows) do
        local id, lineId = int(r.id), int(r.line_id)
        local author = authors[lineId] or { handle = "unknown", name = "Unknown", seed = "?", online = false }
        local echoOf, echoGone = nil, nil
        if r.echo_of and depth == 0 then
            echoOf = originals[int(r.echo_of)]
            echoGone = echoOf == nil or nil
        end
        out[#out + 1] = {
            id = id, author = author, body = r.body or "", at = int(r.created_at),
            district = r.district,
            replyTo = r.reply_to and { id = int(r.reply_to), handle = parentHandles[int(r.reply_to)] or "unknown" } or nil,
            echoOf = echoOf, echoGone = echoGone,
            replies = int(r.replies), echoes = int(r.echoes), cred = int(r.cred),
            credded = credded[id] == true, echoed = echoed[id] == true,
            mine = viewerLine ~= nil and viewerLine.id == lineId,
        }
    end
    return out
end

local function hydrateOne(row, viewerLine) return hydrate({ row }, viewerLine)[1] end

local function postRow(id)
    id = tonumber(id)
    if not id then return false end
    local row, err = Store.single("SELECT " .. POST_COLUMNS .. " FROM nl_social_posts p WHERE p.id = ?", { id })
    if row == nil then return nil, err end
    if not row or truthy(row.deleted) then return false end
    return row
end

-- A page of rows: at most `page`, plus whether more exist.
local function paged(sql, params, page)
    params[#params + 1] = page + 1
    local rows, err = Store.query(sql .. " LIMIT ?", params)
    if not rows then return nil, err end
    local hasMore = #rows > page
    if hasMore then rows[#rows] = nil end
    return rows, hasMore
end

-- ---------------------------------------------------------------------------
-- Live updates and pings

local function broadcast(payload)
    for pid in pairs(Lines.sessions()) do Neural.push(pid, "nl:social", payload) end
end

-- Hydrated for each online viewer (credded / echoed / mine differ per viewer).
local function broadcastPost(row)
    for pid, s in pairs(Lines.sessions()) do
        if s.line.id ~= int(row.line_id) then
            Neural.push(pid, "nl:social", { kind = "post", post = hydrateOne(row, s.line) })
        end
    end
end

local function broadcastStats(postId)
    local row = Store.single("SELECT id, replies, echoes, cred FROM nl_social_posts WHERE id = ?", { postId })
    if row then broadcast({ kind = "stats", postId = int(row.id), cred = int(row.cred), echoes = int(row.echoes), replies = int(row.replies) }) end
end

local PING_TEXT = {
    cred = "gave you Street Cred",
    echo = "echoed your scream",
    quote = "quoted your scream",
    reply = "replied to you",
    mention = "mentioned you",
    follow = "started following you",
}

local function snippet(body)
    body = body or ""
    if #body > 90 then body = body:sub(1, 87) .. "..." end
    return body
end

-- A ping for lineId from actorLine; pushed live (with a toast) when they are online.
local function ping(lineId, kind, actorLine, postId, postBody)
    lineId = int(lineId)
    if lineId == actorLine.id then return end
    local now = Neural.nowMs()
    local id = insertRow("nl_social_pings", { { "line_id", lineId }, { "kind", kind }, { "actor_line", actorLine.id },
        { "post_id", postId }, { "created_at", now } })
    if not id then return end
    local unread = unreadOf(lineId)
    local pid = setUnread(lineId, unread)
    if not pid then return end
    local actor = authorsOf({ actorLine.id })[actorLine.id] or { handle = "unknown", name = actorLine.name, seed = actorLine.number, online = true }
    Neural.push(pid, "nl:social", { kind = "ping", unread = unread, ping = {
        id = int(id), kind = kind, actor = actor,
        post = postId and { id = postId, body = snippet(postBody) } or nil,
        at = now, read = false,
    } })
    Neural.notifySocial(pid, "@" .. actor.handle .. " " .. PING_TEXT[kind], snippet(postBody), postId, actor.handle)
end

-- ---------------------------------------------------------------------------
-- Requests (the page's social.* ops). Each takes (playerId, args).

local function viewer(playerId)
    local line = lineOf(playerId)
    if not line then return nil, "no_line" end
    local profile, err = Social.ensureProfile(line)
    if not profile then return nil, err end
    return line, profile
end

function Social.me(playerId)
    local line, profile = viewer(playerId)
    if not line then return nil, profile end
    local unread = unreadOf(line.id)
    setUnread(line.id, unread)
    return { profile = profileView(profile, line), unread = unread }
end

function Social.feed(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local before = tonumber(args.beforeId)
    local mode = args.mode
    local rows, hasMore
    if mode == "hot" then
        rows, err = Store.query("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
            WHERE p.deleted = 0 AND p.reply_to IS NULL AND p.created_at >= ? AND NOT (p.echo_of IS NOT NULL AND p.body = '')
            ORDER BY (p.cred + 2 * p.echoes + p.replies) DESC, p.id DESC LIMIT ?]],
            { Neural.nowMs() - S.hotHours * 3600000, S.hotShown })
        hasMore = false
    elseif mode == "crew" then
        rows, hasMore = paged("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
            WHERE p.deleted = 0 AND p.reply_to IS NULL AND p.id < ?
              AND (p.line_id = ? OR p.line_id IN (SELECT followee FROM nl_social_follows WHERE follower = ?))
            ORDER BY p.id DESC]], { before or NO_CURSOR, line.id, line.id }, S.page)
    else
        rows, hasMore = paged("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
            WHERE p.deleted = 0 AND p.reply_to IS NULL AND p.id < ? ORDER BY p.id DESC]], { before or NO_CURSOR }, S.page)
    end
    if not rows then return nil, hasMore or err end
    return { posts = hydrate(rows, line), hasMore = hasMore == true }
end

function Social.tag(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local tag = type(args.tag) == "string" and args.tag:lower():gsub("^#", "") or ""
    if not tag:match(HANDLE_PATTERN) or #tag < 2 or #tag > 32 then return nil, "invalid_body" end
    local rows, hasMore = paged("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p JOIN nl_social_tags t ON t.post_id = p.id
        WHERE t.tag = ? AND p.deleted = 0 AND p.id < ? ORDER BY p.id DESC]], { tag, tonumber(args.beforeId) or NO_CURSOR }, S.page)
    if not rows then return nil, hasMore end
    return { posts = hydrate(rows, line), hasMore = hasMore == true }
end

function Social.post(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    if type(args.body) ~= "string" then return nil, "invalid_body" end
    local body = trim(args.body)
    local len = length(body)
    if not len or len < 1 or len > S.screamLength then return nil, "invalid_body" end

    local parent, quoted
    if args.replyTo ~= nil then
        parent, err = postRow(args.replyTo)
        if parent == nil then return nil, err end
        if not parent then return nil, "unknown_post" end
    end
    if args.quoteOf ~= nil and not parent then
        quoted, err = postRow(args.quoteOf)
        if quoted == nil then return nil, err end
        if not quoted then return nil, "unknown_post" end
        -- quoting a plain echo quotes what it echoed
        if quoted.echo_of and quoted.body == "" then
            quoted = postRow(quoted.echo_of)
            if not quoted then return nil, "unknown_post" end
        end
    end
    if not Neural.allow(playerId, "scream") then return nil, "rate_limited" end

    local now = Neural.nowMs()
    local id, insertErr = insertRow("nl_social_posts", { { "line_id", line.id }, { "body", body },
        { "reply_to", parent and int(parent.id) or nil }, { "echo_of", quoted and int(quoted.id) or nil },
        { "district", Social.cleanDistrict(args.district) }, { "created_at", now } })
    if not id then return nil, insertErr end
    for _, tag in ipairs(Social.parseTags(body)) do
        Store.insert("INSERT INTO nl_social_tags (post_id, tag, created_at) VALUES (?, ?, ?)", { id, tag, now })
    end

    local pinged = {}
    if parent then
        Store.update("UPDATE nl_social_posts SET replies = replies + 1 WHERE id = ?", { int(parent.id) })
        broadcastStats(int(parent.id))
        ping(parent.line_id, "reply", line, int(id), body)
        pinged[int(parent.line_id)] = true
    elseif quoted then
        Store.update("UPDATE nl_social_posts SET echoes = echoes + 1 WHERE id = ?", { int(quoted.id) })
        broadcastStats(int(quoted.id))
        ping(quoted.line_id, "quote", line, int(id), body)
        pinged[int(quoted.line_id)] = true
    end
    for _, handle in ipairs(Social.parseMentions(body)) do
        local target = profileByHandle(handle)
        if target and not pinged[int(target.line_id)] then
            pinged[int(target.line_id)] = true
            ping(target.line_id, "mention", line, int(id), body)
        end
    end

    local row = postRow(id)
    if not row then return nil, "database_unavailable" end
    if not parent then broadcastPost(row) end
    return { post = hydrateOne(row, line) }
end

function Social.echo(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local target
    target, err = postRow(args.postId)
    if target == nil then return nil, err end
    if not target then return nil, "unknown_post" end
    if target.echo_of and target.body == "" then
        target = postRow(target.echo_of)
        if not target then return nil, "unknown_post" end
    end
    local targetId = int(target.id)
    if not Neural.allow(playerId, "social") then return nil, "rate_limited" end

    local mine = Store.single("SELECT id FROM nl_social_posts WHERE line_id = ? AND echo_of = ? AND body = '' AND deleted = 0", { line.id, targetId })
    if mine == nil then return nil, "database_unavailable" end
    local echoed
    if mine then
        Store.update("UPDATE nl_social_posts SET deleted = 1 WHERE id = ?", { int(mine.id) })
        Store.update("UPDATE nl_social_posts SET echoes = GREATEST(echoes - 1, 0) WHERE id = ?", { targetId })
        broadcast({ kind = "deleted", postId = int(mine.id) })
        echoed = false
    else
        local id = insertRow("nl_social_posts", { { "line_id", line.id }, { "body", "" }, { "echo_of", targetId },
            { "district", Social.cleanDistrict(args.district) }, { "created_at", Neural.nowMs() } })
        if not id then return nil, "database_unavailable" end
        Store.update("UPDATE nl_social_posts SET echoes = echoes + 1 WHERE id = ?", { targetId })
        ping(target.line_id, "echo", line, targetId, target.body)
        local row = postRow(id)
        if row then broadcastPost(row) end
        echoed = true
    end
    broadcastStats(targetId)
    local counts = Store.single("SELECT echoes FROM nl_social_posts WHERE id = ?", { targetId })
    return { echoed = echoed, echoes = counts and int(counts.echoes) or 0 }
end

function Social.cred(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local target
    target, err = postRow(args.postId)
    if target == nil then return nil, err end
    if not target then return nil, "unknown_post" end
    local targetId = int(target.id)
    if not Neural.allow(playerId, "social") then return nil, "rate_limited" end

    local had = Store.single("SELECT 1 AS x FROM nl_social_cred WHERE post_id = ? AND line_id = ?", { targetId, line.id })
    if had == nil then return nil, "database_unavailable" end
    local credded
    if had then
        Store.update("DELETE FROM nl_social_cred WHERE post_id = ? AND line_id = ?", { targetId, line.id })
        Store.update("UPDATE nl_social_posts SET cred = GREATEST(cred - 1, 0) WHERE id = ?", { targetId })
        credded = false
    else
        local ok, insertErr = Store.insert("INSERT INTO nl_social_cred (post_id, line_id, created_at) VALUES (?, ?, ?)", { targetId, line.id, Neural.nowMs() })
        if ok == nil and insertErr ~= "conflict" then return nil, insertErr end
        if ok ~= nil then
            Store.update("UPDATE nl_social_posts SET cred = cred + 1 WHERE id = ?", { targetId })
            ping(target.line_id, "cred", line, targetId, target.body)
        end
        credded = true
    end
    broadcastStats(targetId)
    local counts = Store.single("SELECT cred FROM nl_social_posts WHERE id = ?", { targetId })
    return { credded = credded, cred = counts and int(counts.cred) or 0 }
end

-- Removes a scream (its author, or a moderator through the console command).
function Social.remove(postId, byLineId)
    local row, err = postRow(postId)
    if row == nil then return nil, err end
    if not row then return nil, "unknown_post" end
    if byLineId and int(row.line_id) ~= byLineId then return nil, "not_author" end
    Store.update("UPDATE nl_social_posts SET deleted = 1 WHERE id = ?", { int(row.id) })
    if row.reply_to then
        Store.update("UPDATE nl_social_posts SET replies = GREATEST(replies - 1, 0) WHERE id = ?", { int(row.reply_to) })
        broadcastStats(int(row.reply_to))
    elseif row.echo_of then
        Store.update("UPDATE nl_social_posts SET echoes = GREATEST(echoes - 1, 0) WHERE id = ?", { int(row.echo_of) })
        broadcastStats(int(row.echo_of))
    end
    broadcast({ kind = "deleted", postId = int(row.id) })
    return {}
end

function Social.delete(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    return Social.remove(args.postId, line.id)
end

function Social.thread(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local row
    row, err = postRow(args.postId)
    if row == nil then return nil, err end
    if not row then return nil, "unknown_post" end
    -- the chain it answers, up to 8 screams back
    local parents, cursor = {}, row
    for _ = 1, 8 do
        if not cursor.reply_to then break end
        cursor = postRow(cursor.reply_to)
        if not cursor then break end
        table.insert(parents, 1, cursor)
    end
    local replies = Store.query("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
        WHERE p.reply_to = ? AND p.deleted = 0 ORDER BY p.id ASC LIMIT ?]], { int(row.id), S.repliesShown }) or {}
    return { post = hydrateOne(row, line), parents = hydrate(parents, line), replies = hydrate(replies, line) }
end

function Social.profile(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local handle = type(args.handle) == "string" and args.handle:lower():gsub("^@", "") or ""
    local target
    target, err = profileByHandle(handle)
    if target == nil then return nil, err end
    if not target then return nil, "unknown_handle" end
    local rows, hasMore = paged("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
        WHERE p.line_id = ? AND p.deleted = 0 AND p.reply_to IS NULL AND p.id < ? ORDER BY p.id DESC]],
        { int(target.line_id), tonumber(args.beforeId) or NO_CURSOR }, S.page)
    if not rows then return nil, hasMore end
    return { profile = profileView(target, line), posts = hydrate(rows, line), hasMore = hasMore == true }
end

function Social.follow(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local handle = type(args.handle) == "string" and args.handle:lower():gsub("^@", "") or ""
    local target
    target, err = profileByHandle(handle)
    if target == nil then return nil, err end
    if not target then return nil, "unknown_handle" end
    local targetLine = int(target.line_id)
    if targetLine == line.id then return nil, "self" end
    if not Neural.allow(playerId, "social") then return nil, "rate_limited" end
    if args.follow == true then
        local ok, insertErr = Store.insert("INSERT INTO nl_social_follows (follower, followee, created_at) VALUES (?, ?, ?)",
            { line.id, targetLine, Neural.nowMs() })
        if ok == nil and insertErr ~= "conflict" then return nil, insertErr end
        if ok ~= nil then ping(targetLine, "follow", line, nil, nil) end
    else
        Store.update("DELETE FROM nl_social_follows WHERE follower = ? AND followee = ?", { line.id, targetLine })
    end
    return { followed = args.follow == true,
        followers = countOf("SELECT COUNT(*) AS n FROM nl_social_follows WHERE followee = ?", { targetLine }) }
end

function Social.update(playerId, args)
    local line, profile = viewer(playerId)
    if not line then return nil, profile end
    local handle, name, bio = profile.handle, profile.name, profile.bio or ""
    if args.handle ~= nil then
        handle = type(args.handle) == "string" and args.handle:lower():gsub("^@", "") or ""
        if not Social.validHandle(handle) then return nil, "invalid_handle" end
    end
    if args.name ~= nil then
        name = type(args.name) == "string" and trim(args.name) or ""
        local len = length(name)
        if not len or len < 1 or len > S.nameLength then return nil, "invalid_name" end
    end
    if args.bio ~= nil then
        bio = type(args.bio) == "string" and trim(args.bio:gsub("[%c]", " ")) or ""
        local len = length(bio)
        if not len or len > S.bioLength then return nil, "invalid_body" end
    end
    if handle ~= profile.handle then
        local taken = Store.single("SELECT line_id FROM nl_social_profiles WHERE handle = ?", { handle })
        if taken == nil then return nil, "database_unavailable" end
        if taken then return nil, "handle_taken" end
    end
    local ok = Store.update("UPDATE nl_social_profiles SET handle = ?, name = ?, bio = ? WHERE line_id = ?", { handle, name, bio, line.id })
    if ok == nil then return nil, "handle_taken" end
    local s = Lines.session(playerId)
    if s and s.social then s.social.handle = handle end
    Neural.push(playerId, "nl:patch", { social = Social.summary(playerId) })
    return { profile = profileView(profileRow(line.id), line) }
end

function Social.search(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local q = type(args.q) == "string" and trim(args.q) or ""
    if length(q) == nil or #q < 2 or #q > 40 then return { profiles = {}, posts = {} } end
    if q:sub(1, 1) == "#" then
        local result = Social.tag(playerId, { tag = q })
        return { profiles = {}, posts = result and result.posts or {} }
    end
    local term = likeOf(q:gsub("^@", ""):lower())
    local profiles = {}
    for _, r in ipairs(Store.query([[SELECT line_id, handle, name, bio, created_at FROM nl_social_profiles
        WHERE handle LIKE ? OR LOWER(name) LIKE ? ORDER BY handle LIMIT 8]], { term, term }) or {}) do
        profiles[#profiles + 1] = profileView(r, line)
    end
    local posts = {}
    if q:sub(1, 1) ~= "@" then
        posts = hydrate(Store.query("SELECT " .. POST_COLUMNS .. [[ FROM nl_social_posts p
            WHERE p.deleted = 0 AND p.body LIKE ? ORDER BY p.id DESC LIMIT ?]], { likeOf(q), S.page }) or {}, line)
    end
    return { profiles = profiles, posts = posts }
end

function Social.heat(playerId)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local since = Neural.nowMs() - S.hotHours * 3600000
    local tags, districts = {}, {}
    for _, r in ipairs(Store.query([[SELECT t.tag AS tag, COUNT(*) AS n FROM nl_social_tags t JOIN nl_social_posts p ON p.id = t.post_id
        WHERE t.created_at >= ? AND p.deleted = 0 GROUP BY t.tag ORDER BY n DESC, t.tag LIMIT 16]], { since }) or {}) do
        tags[#tags + 1] = { tag = r.tag, count = int(r.n) }
    end
    for _, r in ipairs(Store.query([[SELECT district, COUNT(*) AS n FROM nl_social_posts
        WHERE created_at >= ? AND deleted = 0 AND district IS NOT NULL GROUP BY district ORDER BY n DESC LIMIT 20]], { since }) or {}) do
        districts[#districts + 1] = { district = r.district, count = int(r.n) }
    end
    local hot = Social.feed(playerId, { mode = "hot" })
    local top = {}
    for i = 1, math.min(5, hot and #hot.posts or 0) do top[i] = hot.posts[i] end
    return { tags = tags, districts = districts, hot = top }
end

function Social.pings(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local before = tonumber(args.beforeId)
    local rows, hasMore = paged([[SELECT id, kind, actor_line, post_id, created_at, is_read FROM nl_social_pings
        WHERE line_id = ? AND id < ? ORDER BY id DESC]], { line.id, before or NO_CURSOR }, S.pingsPage)
    if not rows then return nil, hasMore end
    local actorIds, postIds = {}, {}
    for _, r in ipairs(rows) do
        actorIds[#actorIds + 1] = int(r.actor_line)
        if r.post_id then postIds[#postIds + 1] = int(r.post_id) end
    end
    local actors, posts = authorsOf(actorIds), rowsByIds(postIds)
    local list = {}
    for _, r in ipairs(rows) do
        local p = r.post_id and posts[int(r.post_id)]
        list[#list + 1] = {
            id = int(r.id), kind = r.kind,
            actor = actors[int(r.actor_line)] or { handle = "unknown", name = "Unknown", seed = "?", online = false },
            post = p and not truthy(p.deleted) and { id = int(p.id), body = snippet(p.body) } or nil,
            at = int(r.created_at), read = truthy(r.is_read),
        }
    end
    if not before then
        Store.update("UPDATE nl_social_pings SET is_read = 1 WHERE line_id = ? AND is_read = 0", { line.id })
        setUnread(line.id, 0)
        Neural.push(playerId, "nl:patch", { social = Social.summary(playerId) })
    end
    return { pings = list, hasMore = hasMore == true }
end

function Social.report(playerId, args)
    local line, err = viewer(playerId)
    if not line then return nil, err end
    local row
    row, err = postRow(args.postId)
    if row == nil then return nil, err end
    if not row then return nil, "unknown_post" end
    local reason = type(args.reason) == "string" and trim(args.reason:gsub("[%c]", " ")) or ""
    if reason == "" then reason = "unspecified" end
    if #reason > 140 then reason = reason:sub(1, 140) end
    local ok, insertErr = Store.insert("INSERT INTO nl_social_reports (post_id, line_id, reason, created_at) VALUES (?, ?, ?, ?)",
        { int(row.id), line.id, reason, Neural.nowMs() })
    if ok == nil and insertErr ~= "conflict" then return nil, insertErr end
    Neural.log("scream %d reported by line %d: %s", int(row.id), line.id, reason)
    return {}
end

-- ---------------------------------------------------------------------------
-- Test lines (no player): screams from the console, see main.lua.

function Social.screamAs(line, body, district)
    local profile, err = Social.ensureProfile(line)
    if not profile then return nil, err end
    body = trim(body or "")
    local len = length(body)
    if not len or len < 1 or len > S.screamLength then return nil, "invalid_body" end
    local now = Neural.nowMs()
    local id, insertErr = insertRow("nl_social_posts", { { "line_id", line.id }, { "body", body },
        { "district", Social.cleanDistrict(district) }, { "created_at", now } })
    if not id then return nil, insertErr end
    for _, tag in ipairs(Social.parseTags(body)) do
        Store.insert("INSERT INTO nl_social_tags (post_id, tag, created_at) VALUES (?, ?, ?)", { id, tag, now })
    end
    for _, handle in ipairs(Social.parseMentions(body)) do
        local target = profileByHandle(handle)
        if target then ping(target.line_id, "mention", line, int(id), body) end
    end
    local row = postRow(id)
    if row then broadcastPost(row) end
    return int(id)
end

Social.OPS = {
    ["social.me"] = Social.me,
    ["social.feed"] = Social.feed,
    ["social.tag"] = Social.tag,
    ["social.post"] = Social.post,
    ["social.echo"] = Social.echo,
    ["social.cred"] = Social.cred,
    ["social.delete"] = Social.delete,
    ["social.thread"] = Social.thread,
    ["social.profile"] = Social.profile,
    ["social.follow"] = Social.follow,
    ["social.update"] = Social.update,
    ["social.search"] = Social.search,
    ["social.heat"] = Social.heat,
    ["social.pings"] = Social.pings,
    ["social.report"] = Social.report,
}
