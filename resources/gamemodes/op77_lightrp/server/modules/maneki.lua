-- The Maneki-neko collection: lucky cats hidden by the staff around Night City
-- (server/config/maneki.lua, docs/maneki.md).
--
--   * No blip, no marker, no list: the server streams to each player only the cats
--     they have not found yet, within streamRadius of the player (its own position
--     feed), nearest first. The client draws them as local props (client/core/maneki.lua).
--   * A cat is taken with E (takeRadius) or by shooting it (shotRange, a weapon in
--     hand). Both are re-checked here; the client only says which cat and how.
--   * Each character finds each cat once (lightrp_maneki_finds). Every find pays,
--     milestones pay more, the whole set gives the "Lucky Cat" title.
--   * Staff place, list, visit and remove cats from the staff desk (/lightrp.admin >
--     Maneki-neko) or /lightrp.maneki. Every placement and removal is written to
--     lightrp_staff_audit like the other desk interventions.
local C, E, Db, S = LightRpManeki, LightRpEvents, LightRP.db, LightRP.support
local M = LightRP.module("maneki", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_maneki_spots (
    id VARCHAR(24) NOT NULL PRIMARY KEY,
    x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
    yaw FLOAT NOT NULL DEFAULT 0, scale FLOAT NOT NULL DEFAULT 1, bucket INT NOT NULL DEFAULT 0,
    district VARCHAR(48) NOT NULL DEFAULT '', placed_by VARCHAR(96) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL, KEY maneki_live (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_maneki_finds (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, spot_id VARCHAR(24) NOT NULL,
    method VARCHAR(8) NOT NULL DEFAULT 'take', found_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key, spot_id), KEY maneki_spot (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local spots, order = {}, {}   -- id -> spot { id, x, y, z, yaw, scale, bucket, district, placedBy, placedAt }; ids oldest first
local loadedSpots = false
local finds = {}              -- "identifier#key" -> { [spotId] = true }
local findCount = {}          -- spotId -> number of characters that found it
local sent = {}               -- playerId -> { key, ids = { [id] = true }, sig }
local editors = {}            -- playerId -> true while the placement tool runs
local lastCollect = {}        -- playerId -> ms
local busy = {}               -- spot id -> true while a find or a removal is written
local dirty = true

local function log(...) LightRP.log(...) end
local function finite(v) local n = tonumber(v); return n and n == n and math.abs(n) < 1e7 and n or nil end
local function round(v, step) step = step or .01; return math.floor(v / step + .5) * step end
local function unix()
    local ok, v = pcall(function() return Open77.time.unix() end)
    return ok and math.floor(tonumber(v) or 0) or 0
end
local function keyOf(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if c and c.status == "active" and c.identifier and c.key then return c.identifier .. "#" .. c.key, c end
end
local function console(player) return player == nil or player == 0 end
local function allowed(player, right)
    if console(player) then return right ~= "manekiTeleport" and right ~= "manekiEditor" end
    return S.allowed(player, right)
end
local function desk(player, right) return not console(player) and S.allowed(player, "view") and S.allowed(player, right) end
local function positionOf(player)
    local p = Open77.players.position(player)
    if not p then return nil end
    local bucket = p.bucket
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then
        local b = Open77.routingBuckets.getPlayer(player)
        if b ~= nil then bucket = b end
    end
    return { x = p.x, y = p.y, z = p.z, bucket = bucket or 0, heading = p.heading }
end
local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function total() return #order end
M.spots = function() return spots end

-- ---------------------------------------------------------------------------
-- Storage

local function addSpot(s)
    if not spots[s.id] then order[#order + 1] = s.id end
    spots[s.id] = s
end
local function dropSpot(id)
    spots[id] = nil
    for i, v in ipairs(order) do if v == id then table.remove(order, i) break end end
end

function M.onDatabaseReady()
    local ok, rows = Db.read([[SELECT id, x, y, z, yaw, scale, bucket, district, placed_by, UNIX_TIMESTAMP(created_at) AS at
        FROM lightrp_maneki_spots WHERE deleted_at IS NULL ORDER BY created_at, id]], {})
    if not ok then log("maneki: spots could not be read; the collection is off until a restart"); return end
    spots, order = {}, {}
    for _, r in ipairs(rows) do
        addSpot({ id = r.id, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), yaw = tonumber(r.yaw) or 0,
            scale = tonumber(r.scale) or 1, bucket = tonumber(r.bucket) or 0, district = r.district or "",
            placedBy = r.placed_by or "", placedAt = (tonumber(r.at) or 0) * 1000 })
    end
    local okCount, counts = Db.read([[SELECT spot_id, COUNT(*) AS n FROM lightrp_maneki_finds GROUP BY spot_id]], {})
    findCount = {}
    if okCount then for _, r in ipairs(counts) do findCount[r.spot_id] = tonumber(r.n) or 0 end end
    loadedSpots, dirty = true, true
    finds, sent = {}, {}
    log("maneki: %d cat(s) hidden in the city", #order)
end

-- The finds of one character, read once (nil while unreadable: nothing is streamed then).
local function findsOf(key)
    if finds[key] then return finds[key] end
    if not Db.ready then finds[key] = {}; return finds[key] end
    local identifier, ck = key:match("^(.*)#([^#]+)$")
    local ok, rows = Db.read("SELECT spot_id FROM lightrp_maneki_finds WHERE identifier = ? AND character_key = ?", { identifier, ck })
    if not ok then return nil end
    local set = {}
    for _, r in ipairs(rows) do set[r.spot_id] = true end
    finds[key] = set
    return set
end
local function foundCount(set)
    local n = 0
    for id in pairs(set or {}) do if spots[id] then n = n + 1 end end
    return n
end

LightRP.stateProvider("maneki", function(playerId)
    if C.enabled == false then return nil end
    local key = keyOf(playerId)
    local set = key and finds[key]
    if not set then return nil end
    return { found = foundCount(set), total = total() }
end)

-- ---------------------------------------------------------------------------
-- Streaming

local function payload(s, found)
    return { id = s.id, x = round(s.x), y = round(s.y), z = round(s.z), yaw = round(s.yaw, .1), s = s.scale, f = found or nil }
end
local function streamTo(player, force)
    local key = keyOf(player)
    local p = key and positionOf(player)
    local set = key and findsOf(key)
    local editing = editors[player] == true
    local list = {}
    if p and set and loadedSpots and C.enabled ~= false then
        local radius = C.streamRadius or 140
        for _, id in ipairs(order) do
            local s = spots[id]
            if s.bucket == p.bucket and (editing or not set[id]) then
                local d = distance(s, p)
                if d <= radius then list[#list + 1] = { s = s, d = d } end
            end
        end
        table.sort(list, function(a, b) return a.d < b.d end)
    end
    local cap = editing and 50 or (C.maxStreamed or 40)
    local out, ids, sig = {}, {}, {}
    for i = 1, math.min(#list, cap) do
        local s = list[i].s
        local found = editing and set and set[s.id] or nil
        out[#out + 1] = payload(s, found)
        ids[s.id] = true
        sig[#sig + 1] = s.id .. (found and "+" or "")
    end
    table.sort(sig)
    local signature = (editing and "E|" or "P|") .. table.concat(sig, ",")
    local previous = sent[player]
    if not force and previous and previous.key == key and previous.sig == signature then return end
    sent[player] = { key = key, ids = ids, sig = signature }
    TriggerClientEvent(E.net.maneki, player, { kind = "near", spots = out, editing = editing or nil,
        model = C.model, height = C.height })
end
M.streamTo = streamTo

CreateThread(function()
    local last = 0
    while true do
        Wait(500)
        local now = LightRP.nowMs()
        if dirty or now - last >= (C.scanMs or 2000) then
            local force = dirty
            dirty, last = false, now
            for _, raw in ipairs(GetPlayers()) do
                local id = tonumber(raw)
                if id then
                    local ok, err = pcall(streamTo, id, false)
                    if not ok then log("maneki stream %d failed: %s", id, tostring(err)) end
                end
                if not force then Wait(0) end
            end
        end
    end
end)

local function forget(player) sent[player], editors[player], lastCollect[player] = nil, nil, nil end
function M.onCharacterLoaded(player) sent[player] = nil; dirty = true end
function M.onCharacterSwitched(player) sent[player] = nil; dirty = true end
function M.onCharacterActivated(player) sent[player] = nil; dirty = true; LightRP.state(player, "maneki") end
function M.onDisconnected(player) forget(player) end
-- The page asks for its state when it comes up: it gets ours too (and the streamed set again).
function M.onGameplayReady(player) sent[player] = nil; dirty = true end

-- ---------------------------------------------------------------------------
-- Collecting

local function payMilestones(player, found)
    local paid = {}
    for _, m in ipairs(C.milestones or {}) do
        if found == m.count and (m.cash or 0) > 0 then
            local ok = LightRP.money.addBank(player, m.cash, "collectible", ("Maneki-neko: %d found"):format(found), "Maneki-neko")
            if ok then paid[#paid + 1] = m end
        end
    end
    return paid
end

function M.collect(player, p)
    if C.enabled == false or type(p) ~= "table" or not loadedSpots then return end
    local id, how = p.id, p.how
    if type(id) ~= "string" or #id > 24 or (how ~= "take" and how ~= "shot") then return end
    local now = LightRP.nowMs()
    if now - (lastCollect[player] or -1e9) < (C.collectCooldownMs or 400) then return end
    lastCollect[player] = now
    local key = keyOf(player)
    local s = spots[id]
    local streamed = sent[player] and sent[player].ids[id]
    if not key or not s or not streamed or busy[id .. key] then return end
    local set = findsOf(key)
    if not set or set[id] then return end
    local at = positionOf(player)
    if not at or at.bucket ~= s.bucket then return end
    local d = distance(s, at)
    if how == "take" and d > (C.takeRadius or 4) then
        log("maneki: take of %s by %d refused at %.1f m", id, player, d); return
    end
    if how == "shot" then
        if d > (C.shotRange or 90) then log("maneki: shot of %s by %d refused at %.1f m", id, player, d); return end
        local ok, w = pcall(function() return Open77.weapons.get(player) end)
        if ok and type(w) == "table" and w.fresh and w.drawn == false then
            log("maneki: shot of %s by %d refused: no weapon in hand", id, player); return
        end
    end
    busy[id .. key] = true
    local identifier, ck = key:match("^(.*)#([^#]+)$")
    local wrote, affected = true, 1
    if Db.ready then
        wrote, affected = Db.run("INSERT IGNORE INTO lightrp_maneki_finds (identifier, character_key, spot_id, method) VALUES (?, ?, ?, ?)",
            { identifier, ck, id, how })
    end
    busy[id .. key] = nil
    if not wrote then
        LightRP.notice(player, { kind = "warning", title = "Maneki-neko", body = "The find could not be saved. Try again in a moment." })
        return
    end
    set[id] = true
    if tonumber(affected) == 0 then streamTo(player, true); return end -- already stored (another session)
    findCount[id] = (findCount[id] or 0) + 1
    local found, all = foundCount(set), total()
    local cash = C.reward and C.reward.cash or 0
    local paid = cash > 0 and LightRP.money.addBank(player, cash, "collectible", "Maneki-neko found", "Maneki-neko")
    local milestones = payMilestones(player, found)
    local complete = found >= all and all >= (C.completeMin or 10)
    local titled = complete and C.completeTitle and LightRP.titles and LightRP.titles.award(player, C.completeTitle) or false
    log("maneki: %s found %s by %s (%d/%d, %.1f m)", LightRP.characters.displayName(player) or tostring(player), id, how, found, all, d)
    TriggerClientEvent(E.net.maneki, player, { kind = "found", id = id, how = how, found = found, total = all,
        cash = paid and cash or 0, milestone = milestones[1] and milestones[1].cash or nil, complete = complete or nil, title = titled or nil })
    local lines = { ("%d / %d found"):format(found, all) }
    if paid then lines[#lines + 1] = ("+€$ %s to your bank"):format(tostring(cash)) end
    for _, m in ipairs(milestones) do lines[#lines + 1] = ("Milestone %d: +€$ %s"):format(m.count, tostring(m.cash)) end
    if complete then lines[#lines + 1] = titled and "Every cat found: title \"Lucky Cat\" unlocked." or "Every cat found!" end
    LightRP.notice(player, { kind = "item", title = how == "shot" and "Maneki-neko shot down" or "Maneki-neko found",
        body = table.concat(lines, " · "), durationMs = complete and 12000 or 7000 })
    LightRP.state(player, "maneki")
    streamTo(player, true)
end
RegisterNetEvent(E.net.manekiCollect, function(p) M.collect(source, p) end)

-- ---------------------------------------------------------------------------
-- Staff: audit, placement, removal

local sequence = 0
local function actorOf(player)
    if console(player) then return { identifier = "console", name = "Server console" } end
    local c = S.identity(player)
    return c and { identifier = c.identifier, name = GetPlayerName(player) or "?" }
end
local function describe(s)
    return ("cat %s · %.1f, %.1f, %.1f · instance %d · size %s%s"):format(s.id, s.x, s.y, s.z, s.bucket or 0, tostring(s.scale),
        s.district ~= "" and (" · " .. s.district) or "")
end
-- Audit first (pending), act, then the outcome: the desk's rule (admin.lua).
local function audited(player, op, s, reason, mutation, act)
    local actor = actorOf(player)
    if not actor then return nil, "Your account is still loading." end
    if not mutation then sequence = sequence + 1; mutation = ("maneki:%d:%d"):format(unix(), sequence) end
    if Db.ready then
        local ok, previous = Db.read("SELECT outcome, detail FROM lightrp_staff_audit WHERE actor_id = ? AND request_key = ?", { actor.identifier, mutation })
        if not ok then return nil, "The audit log is unavailable; nothing was changed." end
        if previous[1] then
            local r = previous[1]
            return { accepted = r.outcome == "success", outcome = r.outcome, message = r.detail }
        end
        local saved = Db.run([[INSERT INTO lightrp_staff_audit (actor_id, actor_name, target_id, target_name, character_key, action, reason, detail, request_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { actor.identifier, actor.name, s.id, "Maneki-neko", s.id, op, reason, describe(s):sub(1, 500), mutation })
        if not saved then return nil, "The audit could not be saved; nothing was changed." end
    end
    local called, success, label = pcall(act)
    if not called then log("maneki %s failed: %s", op, tostring(success)); success, label = false, "The action failed; see the server log." end
    label = tostring(label or (success and "Done." or "Refused."))
    local written = true
    if Db.ready then
        written = Db.run("UPDATE lightrp_staff_audit SET outcome = ?, detail = ? WHERE actor_id = ? AND request_key = ?",
            { success and "success" or "failed", (describe(s) .. " · " .. label):sub(1, 500), actor.identifier, mutation })
    end
    log("staff %s %s by %s: %s", op, s.id, actor.name, label)
    return { accepted = success == true, outcome = written and (success and "success" or "failed") or "pending", message = label }
end

local function newId()
    sequence = sequence + 1
    return ("mk%x%03x%02x"):format(unix(), math.random(0, 0xfff), sequence % 256)
end

-- A placement from the tool (client/core/maneki_editor.lua) or a command.
function M.place(player, p, reason)
    if not allowed(player, "manekiEdit") then return nil, "Maneki-neko placement permission required." end
    if not loadedSpots and Db.ready then return nil, "The collection is not loaded yet." end
    if #order >= (C.maxSpots or 600) then return nil, "The collection is full (" .. tostring(C.maxSpots) .. " cats)." end
    local x, y, z = finite(p.x), finite(p.y), finite(p.z)
    if not x or not y or not z then return nil, "Invalid position." end
    local scale = 1
    for _, v in ipairs(C.scales or { 1 }) do if math.abs(v - (tonumber(p.scale) or 1)) < 1e-3 then scale = v end end
    local bucket = 0
    if not console(player) then
        local at = positionOf(player)
        if not at then return nil, "Your position is unavailable." end
        if distance(at, { x = x, y = y, z = z }) > (C.placeMaxDistance or 80) then return nil, "Too far from you: walk closer to where the cat goes." end
        bucket = at.bucket or 0
    end
    for _, id in ipairs(order) do
        local o = spots[id]
        if o.bucket == bucket and distance(o, { x = x, y = y, z = z }) < 0.6 then return nil, "Another cat (" .. id .. ") is already there." end
    end
    local district = type(p.district) == "string" and p.district:gsub("[^%w%s%-%.' ]", ""):sub(1, 48) or ""
    local actor = actorOf(player)
    local s = { id = newId(), x = round(x, .001), y = round(y, .001), z = round(z, .001), yaw = round((tonumber(p.yaw) or 0) % 360, .1),
        scale = scale, bucket = bucket, district = district, placedBy = actor and actor.name or "?", placedAt = unix() * 1000 }
    return audited(player, "manekiPlace", s, reason or "Maneki-neko placement tool", p.mutation, function()
        if Db.ready then
            local ok = Db.run([[INSERT INTO lightrp_maneki_spots (id, x, y, z, yaw, scale, bucket, district, placed_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                { s.id, s.x, s.y, s.z, s.yaw, s.scale, s.bucket, s.district, s.placedBy })
            if not ok then return false, "The cat could not be saved." end
        end
        addSpot(s)
        dirty = true
        for _, raw in ipairs(GetPlayers()) do local id = tonumber(raw); if id then LightRP.state(id, "maneki") end end
        return true, ("Maneki-neko %s placed (%d in the city)."):format(s.id, #order)
    end)
end

function M.remove(player, id, reason, mutation)
    if not allowed(player, "manekiEdit") then return nil, "Maneki-neko removal permission required." end
    local s = spots[id]
    if not s then return nil, "No cat with id " .. tostring(id) .. "." end
    if busy[id] then return nil, "Another staff action is running on this cat." end
    busy[id] = true
    local result, why = audited(player, "manekiDelete", s, reason, mutation, function()
        if Db.ready and not Db.run("UPDATE lightrp_maneki_spots SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?", { id }) then
            return false, "The removal could not be saved."
        end
        dropSpot(id)
        dirty = true
        for _, raw in ipairs(GetPlayers()) do local pid = tonumber(raw); if pid then LightRP.state(pid, "maneki") end end
        return true, ("Maneki-neko %s removed (%d left). Finds already made stay in the players' history."):format(id, #order)
    end)
    busy[id] = nil
    return result, why
end

local function landing(s)
    -- A step back from the cat, in front of its face. Yaw 0 points the model's +Y north;
    -- the game's cat looks along its own -Y, so its face points at yaw + 180.
    local a = math.rad(s.yaw or 0)
    local fx, fy = math.sin(a), -math.cos(a)
    return { x = s.x + fx * 1.6, y = s.y + fy * 1.6, z = s.z + .1 }, (s.yaw or 0) % 360
end
function M.teleport(player, id, reason, mutation)
    if console(player) then return nil, "Only an in-game staff member can be moved." end
    if not allowed(player, "maneki") then return nil, "Maneki-neko permission required." end
    local s = spots[id]
    if not s then return nil, "No cat with id " .. tostring(id) .. "." end
    return audited(player, "manekiTeleport", s, reason, mutation, function()
        local here = positionOf(player)
        local target = s.bucket or 0
        if here and here.bucket ~= target and target ~= 0 then return false, ("This cat is in instance %d; you are in %d."):format(target, here.bucket) end
        local position, heading = landing(s)
        local done, ok, why = false, false, nil
        LightRP.staff.moveTo(player, position, heading, function(success, failure) ok, why, done = success, failure, true end,
            here and here.bucket ~= target and target or nil)
        local waited = 0
        while not done and waited < 15000 do Wait(20); waited = waited + 20 end
        return ok, ok and ("You are next to Maneki-neko %s."):format(id) or ("Teleport refused: " .. tostring(why or "timeout"))
    end)
end

function M.setEditor(player, active)
    if console(player) then return false, "Only an in-game staff member can place cats." end
    if active and not desk(player, "manekiEdit") then return false, "Maneki-neko placement permission required." end
    editors[player] = active and true or nil
    sent[player] = nil
    dirty = true
    TriggerClientEvent(E.net.maneki, player, { kind = "editor", active = active == true, scales = C.scales, model = C.model,
        height = C.height, maxDistance = C.placeMaxDistance })
    return true, active and "Placement tool on: aim, LEFT CLICK to place." or "Placement tool off."
end
function M.isEditing(player) return editors[player] == true end

function M.resetSelf(player)
    if not desk(player, "manekiEdit") then return false, "Maneki-neko placement permission required." end
    local key = keyOf(player)
    if not key then return false, "Your character is not loaded." end
    local identifier, ck = key:match("^(.*)#([^#]+)$")
    if Db.ready and not Db.run("DELETE FROM lightrp_maneki_finds WHERE identifier = ? AND character_key = ?", { identifier, ck }) then
        return false, "The reset could not be saved."
    end
    for id in pairs(finds[key] or {}) do if findCount[id] then findCount[id] = math.max(0, findCount[id] - 1) end end
    finds[key] = {}
    sent[player] = nil
    dirty = true
    LightRP.state(player, "maneki")
    log("maneki: %s reset their own collection", GetPlayerName(player) or tostring(player))
    return true, "Your collection was reset: every cat is back for this character (no money is taken back)."
end

-- The placement tool's requests.
RegisterNetEvent(E.net.manekiEdit, function(p)
    local player = source
    if type(p) ~= "table" then return end
    local function reply(ok, text) TriggerClientEvent(E.net.maneki, player, { kind = "staff", ok = ok == true, text = text, op = p.op }) end
    if p.op == "close" then M.setEditor(player, false); return end
    if not editors[player] or not desk(player, "manekiEdit") then reply(false, "The placement tool is not open."); return end
    if p.op == "place" then
        local r, why = M.place(player, p)
        reply(r and r.accepted, r and r.message or why)
    elseif p.op == "delete" and type(p.id) == "string" then
        local s, at = spots[p.id], positionOf(player)
        if not s or not at or distance(s, at) > 25 then reply(false, "Walk up to that cat to remove it."); return end
        local r, why = M.remove(player, p.id, "Removed with the placement tool")
        reply(r and r.accepted, r and r.message or why)
    end
end)

-- ---------------------------------------------------------------------------
-- The staff desk (server/modules/support.lua routes these through LightRP.admin.handlers)

local PAGE, CHAT_PAGE = 15, 10
local function rows(player, opts)
    local from = not console(player) and positionOf(player) or nil
    local query = type(opts.search) == "string" and opts.search:lower():sub(1, 64) or ""
    local out = {}
    for _, id in ipairs(order) do
        local s = spots[id]
        local r = { id = s.id, x = round(s.x, .1), y = round(s.y, .1), z = round(s.z, .1), bucket = s.bucket, yaw = s.yaw, scale = s.scale,
            district = s.district, placedBy = s.placedBy, placedAt = s.placedAt, finds = findCount[id] or 0 }
        if from and from.bucket == s.bucket then r.distance = round(distance(s, from), .1) end
        if query == "" or (("%s %s %s"):format(r.id, r.district, r.placedBy)):lower():find(query, 1, true) then out[#out + 1] = r end
    end
    if opts.sort == "near" and from then
        table.sort(out, function(a, b)
            if (a.distance ~= nil) ~= (b.distance ~= nil) then return a.distance ~= nil end
            if a.distance and a.distance ~= b.distance then return a.distance < b.distance end
            return a.id < b.id
        end)
    else
        table.sort(out, function(a, b) if a.placedAt ~= b.placedAt then return a.placedAt > b.placedAt end return a.id > b.id end)
    end
    return out
end
M.rows = rows

function M.list(player, p)
    if not desk(player, "maneki") then return nil, "Maneki-neko permission required." end
    if not loadedSpots and Db.ready then return nil, "The collection is not loaded yet." end
    local page = math.min(math.max(1, math.floor(finite(p.page) or 1)), 10000)
    local all = rows(player, { search = p.search, sort = p.sort })
    local out = {}
    for i = (page - 1) * PAGE + 1, math.min(#all, page * PAGE) do out[#out + 1] = all[i] end
    local key = keyOf(player)
    local mine = key and finds[key]
    local finders = 0
    if Db.ready then
        local ok, r = Db.read("SELECT COUNT(DISTINCT identifier, character_key) AS n FROM lightrp_maneki_finds", {})
        finders = ok and r[1] and tonumber(r[1].n) or 0
    end
    return { spots = out, page = page, pageSize = PAGE, total = #all, cats = #order, finders = finders,
        mine = mine and foundCount(mine) or 0, editing = editors[player] == true,
        canEdit = desk(player, "manekiEdit"), canTeleport = desk(player, "maneki") }
end

function M.action(player, p)
    local op = p.action
    if op == "manekiEditor" then
        local ok, message = M.setEditor(player, p.active ~= false)
        if not ok then return nil, message end
        return { accepted = true, outcome = "success", message = message, close = p.active ~= false }
    elseif op == "manekiResetSelf" then
        local ok, message = M.resetSelf(player)
        if not ok then return nil, message end
        return { accepted = true, outcome = "success", message = message }
    end
    if op ~= "manekiTeleport" and op ~= "manekiDelete" then return nil, "Unknown Maneki-neko action." end
    if not desk(player, op == "manekiDelete" and "manekiEdit" or "maneki") then return nil, "You do not have permission for this action." end
    if p.confirmed ~= true then return nil, "Confirm the selected cat and action first." end
    local reason = S.text(p.reason, 500, 4)
    if not reason then return nil, "Add a reason (4–500 characters) for the audit log." end
    if type(p.mutation) ~= "string" or #p.mutation < 8 or #p.mutation > 96 or not p.mutation:match("^[%w:_%-]+$") then return nil, "Invalid action request." end
    if type(p.id) ~= "string" or not spots[p.id] then return nil, "This cat no longer exists. Refresh the list." end
    if op == "manekiTeleport" then return M.teleport(player, p.id, reason, p.mutation) end
    return M.remove(player, p.id, reason, p.mutation)
end

if LightRP.admin and LightRP.admin.handlers then
    LightRP.admin.handlers.maneki = M.list
    LightRP.admin.handlers.manekiAction = M.action
end

-- ---------------------------------------------------------------------------
-- /lightrp.maneki

local USAGE = "/lightrp.maneki [page | near] · tool · tp <id> · delete <id> · here [size] · reset"
LightRP.command("lightrp.maneki", { restricted = true, usage = USAGE }, function(player, args)
    if not allowed(player, "maneki") then return false, "Maneki-neko permission required." end
    local sub = tostring(args[1] or ""):lower()
    if sub == "tool" or sub == "place" then
        return M.setEditor(player, not editors[player])
    elseif sub == "tp" then
        local r, why = M.teleport(player, tostring(args[2] or ""), "Chat command /lightrp.maneki tp")
        if not r then return false, why end
        return r.accepted, r.message
    elseif sub == "delete" then
        local r, why = M.remove(player, tostring(args[2] or ""), "Chat command /lightrp.maneki delete")
        if not r then return false, why end
        return r.accepted, r.message
    elseif sub == "here" then
        if console(player) then return false, "Only in game." end
        local at = positionOf(player)
        if not at then return false, "Your position is unavailable." end
        local r, why = M.place(player, { x = at.x, y = at.y, z = at.z, yaw = at.heading or 0, scale = tonumber(args[2]) or 1 }, "Chat command /lightrp.maneki here")
        if not r then return false, why end
        return r.accepted, r.message
    elseif sub == "reset" then
        return M.resetSelf(player)
    end
    local near = sub == "near"
    local list = rows(player, { sort = near and "near" or nil })
    if #list == 0 then return true, "No Maneki-neko placed yet. " .. USAGE end
    local pages = math.max(1, math.ceil(#list / CHAT_PAGE))
    local page = near and 1 or math.min(pages, math.max(1, math.floor(tonumber(args[1]) or 1)))
    local say = function(text) if console(player) then log("%s", text) else LightRP.chat.system(player, text) end end
    say(("Maneki-neko: %d in the city (%s, page %d/%d). %s"):format(#list, near and "nearest first" or "newest first", page, pages, USAGE))
    for i = (page - 1) * CHAT_PAGE + 1, math.min(#list, page * CHAT_PAGE) do
        local r = list[i]
        say(("%s · %.1f, %.1f, %.1f · inst %d%s · size %s · found %d×%s"):format(r.id, r.x, r.y, r.z, r.bucket,
            r.distance and (" · " .. r.distance .. " m") or "", tostring(r.scale), r.finds, r.district ~= "" and (" · " .. r.district) or ""))
    end
    return true, ("Page %d/%d shown."):format(page, pages)
end)

-- Without a database bridge at all: the session keeps what the staff place. With one,
-- onDatabaseReady loads the cats however long the database takes at boot.
CreateThread(function()
    Wait(5000)
    if not Db.ready and not loadedSpots and not (Db.available and Db.available()) then
        loadedSpots = true; log("maneki: no database, cats placed now last this session only")
    end
end)
