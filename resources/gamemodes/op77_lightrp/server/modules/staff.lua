-- Staff: who is staff (ACL), the moderation commands, reports. Every command is
-- restricted (`command.lightrp.<name>` in acl.jsonc); the page's Staff tab raises
-- the same operations through actions that check the same ACL.
local Config = LightRpConfig
local Db = LightRP.db
local Staff = LightRP.module("staff", {})

LightRP.command("lightrp.uitest", { restricted = true, usage = "/lightrp.uitest <progress|circle|hold|timing|sequence|cancel>" }, function(playerId, args)
    local mode = args[1] or "progress"
    local valid = { progress = true, circle = true, hold = true, timing = true, sequence = true, cancel = true }
    if not valid[mode] or not playerId or playerId <= 0 then return false end
    TriggerClientEvent(LightRpEvents.net.actionDemo, playerId, mode)
    return true, "UI interaction preview: " .. mode
end)

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_reports (
        id         BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
        identifier VARCHAR(64)  NOT NULL,
        reporter   VARCHAR(96)  NOT NULL,
        message    VARCHAR(512) NOT NULL,
        created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        handled    TINYINT(1)   NOT NULL DEFAULT 0
    )
]])

local locationsByName = {}
for _, location in ipairs(Config.locations) do locationsByName[string.lower(location.name)] = location end

-- ACL reads: Open77.acl.isAllowed(playerId, permission) behind acl.read.
function Staff.allowed(playerId, permission)
    if type(Open77.acl) ~= "table" or type(Open77.acl.isAllowed) ~= "function" then return false end
    local ok, result = pcall(Open77.acl.isAllowed, playerId, permission)
    return ok and result == true
end

function Staff.isStaff(playerId)
    for _, permission in ipairs(Config.staffPermissions) do
        if Staff.allowed(playerId, permission) then return true end
    end
    return false
end

function Staff.role(playerId)
    if type(Open77.acl) ~= "table" or type(Open77.acl.roles) ~= "function" then return nil end
    local ok, roles = pcall(Open77.acl.roles, playerId)
    if ok and type(roles) == "table" and roles[1] then return tostring(roles[1]) end
    return nil
end

LightRP.stateProvider("staff", function(playerId)
    local staff = Staff.isStaff(playerId)
    return { isStaff = staff, role = staff and Staff.role(playerId) or nil }
end)

LightRP.stateProvider("locations", function()
    local list = {}
    for _, location in ipairs(Config.locations) do list[#list + 1] = { name = location.name, label = location.label } end
    return list
end)

-- ---------------------------------------------------------------------------
-- Moving players

local function parseTarget(source, value)
    if value == nil or value == "" or value == "me" then return source end
    local id = tonumber(value)
    if id == nil or GetPlayerName(id) == nil then return nil end
    return id
end

-- Alive: teleport. Dead: respawn there. `callback(ok, reason)`. `bucket`
-- (optional): the routing bucket to land in; nil keeps the current one.
function Staff.moveTo(playerId, position, heading, callback, bucket)
    local life = Open77.players.getLifeState(playerId)
    if life == nil then return callback(false, "player_not_found") end
    if life.phase == "dead" then
        return callback(Open77.players.respawn(playerId, {
            position = position, heading = heading or 0, bucket = bucket or life.bucket or 0,
            health = Config.spawn.health, graceMs = Config.spawn.graceMs,
        }))
    end
    CreateThread(function()
        local promise, reason = Open77.players.teleport(playerId, position, { heading = heading or 0, dismount = true, bucket = bucket })
        if promise == nil then return callback(false, reason) end
        local placed, why = promise:await()
        callback(placed ~= nil and placed ~= false, why)
    end)
end

function Staff.heal(playerId)
    local life = Open77.players.getLifeState(playerId)
    if life and life.phase ~= "alive" then
        local ok, reason = Open77.players.revive(playerId, {})
        if not ok then return false, reason end
    else
        local ok, reason = Open77.players.heal(playerId, 10000)
        if not ok then return false, reason end
    end
    LightRP.needs.refill(playerId)
    return true
end

-- `opts` (another resource's announcement, below): { title, durationMs }; the
-- title also signs the chat line. Without it: the staff announcement.
-- The banner (2026-11-06, the owner: the platform's blue box replaced by our DA, animated, with a
-- Cyberpunk sound): every player gets op77_lightrp:staffannounce, drawn by
-- ui/src/features/announce/StaffBroadcast.tsx; the chat keeps its line for the log.
function Staff.announce(text, opts)
    opts = type(opts) == "table" and opts or {}
    local title = opts.title
    LightRP.chat.broadcast(title and title:upper() or "STAFF", text, Config.chat.colors.staff)
    local duration = math.floor(tonumber(opts.durationMs) or 0)
    if duration <= 0 then duration = math.min(20000, math.max(8000, 5000 + #text * 70)) end
    TriggerClientEvent(LightRpEvents.net.staffAnnounce, -1, { title = title or "Staff announcement", text = text,
        from = type(opts.from) == "string" and opts.from:sub(1, 48) or nil, durationMs = duration })
end

-- The same announcement for other server resources (op77_fireworks...):
--   TriggerEvent("op77_lightrp:announce", text, { title = "Opening night", durationMs = 10000 })
--   TriggerEvent("op77_lightrp:announce", { body = text, title = ..., durationMs = ... })  -- op77_fireworks' shape
-- A host-wide server event: never a network event, a client cannot raise it.
local lastResourceAnnounce = -math.huge
local function announceText(value, min, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value < min then return nil end
    if #value > max then
        local cut = max
        while cut > 0 do local b = value:byte(cut + 1); if not b or b < 0x80 or b >= 0xC0 then break end; cut = cut - 1 end
        value = value:sub(1, cut)
    end
    return value
end
AddEventHandler("op77_lightrp:announce", function(text, opts)
    if type(text) == "table" then opts, text = text, text.body end
    text = announceText(text, 2, 200)
    if not text then return end
    local now = LightRP.nowMs()
    if now - lastResourceAnnounce < 1000 then LightRP.log("announce dropped (one per second): %s", text); return end
    lastResourceAnnounce = now
    opts = type(opts) == "table" and opts or {}
    local duration = tonumber(opts.durationMs) or 12000
    if duration ~= duration then duration = 12000 end
    duration = math.floor(math.max(3000, math.min(30000, duration)))
    Staff.announce(text, { title = announceText(opts.title, 1, 40), durationMs = duration })
end)

function Staff.report(playerId, message)
    if not LightRP.support then return false end
    return LightRP.support.open(playerId,"player",LightRP.support.text(message,2000))
end

-- ---------------------------------------------------------------------------
-- Actions (page): the ACL gate is the same permission the command carries.

local function gated(permission, handler)
    return function(playerId, payload)
        if not Staff.allowed(playerId, permission) then
            return LightRP.result(playerId, false, "Denied: you lack " .. permission .. ".", payload.type)
        end
        handler(playerId, payload)
    end
end

LightRP.action("staff.tp", gated("command.lightrp.tp", function(playerId, payload)
    local target = parseTarget(playerId, payload.target == "me" and "me" or tostring(payload.target or ""))
    local location = locationsByName[string.lower(tostring(payload.location or ""))]
    if target == nil or location == nil then return LightRP.result(playerId, false, "Unknown target or place.", "staff.tp") end
    Staff.moveTo(target, location.position, location.heading, function(ok, reason)
        LightRP.result(playerId, ok, ok and (LightRP.characters.displayName(target) .. " → " .. location.label) or ("Teleport refused: " .. tostring(reason)), "staff.tp")
    end)
end))

-- The instance a moved player lands in: the destination's when it differs from theirs
-- (a bring, a goto across instances), else nil (stays where they are).
local function bucketTo(mover, destination)
    local from = Open77.players.position(mover)
    local to = destination and (destination.bucket or 0) or 0
    if from and (from.bucket or 0) ~= to then return to end
    return nil
end
Staff.bucketTo = bucketTo

LightRP.action("staff.bring", gated("command.lightrp.bring", function(playerId, payload)
    local target = parseTarget(playerId, tostring(payload.target or ""))
    if target == nil or target == playerId then return LightRP.result(playerId, false, "Unknown target.", "staff.bring") end
    local here = Open77.players.position(playerId)
    if here == nil then return LightRP.result(playerId, false, "Your position is unknown.", "staff.bring") end
    Staff.moveTo(target, { x = here.x + 1.5, y = here.y, z = here.z }, 0, function(ok, reason)
        LightRP.result(playerId, ok, ok and (LightRP.characters.displayName(target) .. " brought to you.") or ("Denied: " .. tostring(reason)), "staff.bring")
    end, bucketTo(target, here))
end))

LightRP.action("staff.heal", gated("command.lightrp.heal", function(playerId, payload)
    local target = parseTarget(playerId, payload.target == "me" and "me" or tostring(payload.target or ""))
    if target == nil then return LightRP.result(playerId, false, "Unknown target.", "staff.heal") end
    local ok, reason = Staff.heal(target)
    LightRP.result(playerId, ok, ok and (LightRP.characters.displayName(target) .. " healed.") or ("Denied: " .. tostring(reason)), "staff.heal")
end))

LightRP.action("staff.announce", gated("command.lightrp.announce", function(playerId, payload)
    local text = tostring(payload.text or ""):sub(1, 200)
    if #text < 2 then return LightRP.result(playerId, false, "Message too short.", "staff.announce") end
    Staff.announce(text)
    LightRP.result(playerId, true, "Announcement sent.", "staff.announce")
end))

-- ---------------------------------------------------------------------------
-- Commands

-- /report is registered by support.lua and opens the durable private desk.

LightRP.command("lightrp.tp", { restricted = true, usage = "/lightrp.tp <id|me> <place | x y z>" }, function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil then return false end
    local location = args[2] and locationsByName[string.lower(args[2])]
    local position, heading, label
    if location then
        position, heading, label = location.position, location.heading or 0, location.label
    else
        local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        if x == nil or y == nil or z == nil then
            local names = {}
            for _, l in ipairs(Config.locations) do names[#names + 1] = l.name end
            return false, "Places: " .. table.concat(names, ", ") .. " (or x y z)"
        end
        position, heading, label = { x = x, y = y, z = z }, 0, string.format("%.1f, %.1f, %.1f", x, y, z)
    end
    Staff.moveTo(target, position, heading, function(ok, reason)
        LightRP.reply(source, raw, ok, ok and (LightRP.characters.displayName(target) .. " → " .. label) or ("Teleport refused: " .. tostring(reason)))
    end)
end)

LightRP.command("lightrp.bring", { restricted = true, usage = "/lightrp.bring <id>" }, function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil or target == source then return false end
    local here = Open77.players.position(source)
    if here == nil then return false, "Your position is unknown." end
    Staff.moveTo(target, { x = here.x + 1.5, y = here.y, z = here.z }, 0, function(ok, reason)
        LightRP.reply(source, raw, ok, ok and (LightRP.characters.displayName(target) .. " brought to you.") or ("Denied: " .. tostring(reason)))
    end, bucketTo(target, here))
end)

LightRP.command("lightrp.goto", { restricted = true, usage = "/lightrp.goto <id>" }, function(source, args, raw)
    local target = parseTarget(source, args[1])
    if target == nil or target == source then return false end
    local there = Open77.players.position(target)
    if there == nil then return false, "Target position unknown." end
    Staff.moveTo(source, { x = there.x + 1.5, y = there.y, z = there.z }, 0, function(ok, reason)
        LightRP.reply(source, raw, ok, ok and ("You are next to " .. LightRP.characters.displayName(target)) or ("Denied: " .. tostring(reason)))
    end, bucketTo(source, there))
end)

-- /lightrp.bucket <id|me> <instance>: the player stays where they stand, in another instance.
LightRP.command("lightrp.bucket", { restricted = true, usage = "/lightrp.bucket <id|me> <instance> (0 = the city)" }, function(source, args)
    local target = parseTarget(source, args[1])
    local bucket = tonumber(args[2])
    if target == nil or not bucket or bucket < 0 or bucket ~= math.floor(bucket) then return false end
    if type(SetPlayerRoutingBucket) ~= "function" then return false, "Instances are not available on this server." end
    local ok, set = pcall(SetPlayerRoutingBucket, target, math.floor(bucket))
    if not ok or set == false then return false, "The instance could not be changed." end
    return true, ("%s moved to instance %d."):format(LightRP.characters.displayName(target), math.floor(bucket))
end)

LightRP.command("lightrp.heal", { restricted = true, usage = "/lightrp.heal <id|me>" }, function(source, args)
    local target = parseTarget(source, args[1])
    if target == nil then return false end
    local ok, reason = Staff.heal(target)
    return ok, ok and (LightRP.characters.displayName(target) .. " healed.") or ("Denied: " .. tostring(reason))
end)

local function announceCommand(source, args)
    local text = LightRP.joinArgs(args)
    if text == "" then return false end
    Staff.announce(text:sub(1, 200), { from = source and source > 0 and (GetPlayerName(source) or nil) or "Server" })
    return true, "announced: " .. text:sub(1, 200)
end
LightRP.command("lightrp.announce", { restricted = true, usage = "/lightrp.announce <message>" }, announceCommand)
-- /announce answers here on a LightRP server, before open77_admin's (command dispatch walks the
-- running resources in ordinal name order: op77_lightrp sorts first, as for /admin), so the
-- announcement shows in Light RP's banner instead of the platform's box. Same right.
LightRP.command("announce", { restricted = true, usage = "/announce <message>" }, announceCommand)

LightRP.command("lightrp.setname", { restricted = true, usage = "/lightrp.setname <id> <FirstName> <LastName>" }, function(source, args)
    local target = parseTarget(source, args[1])
    if target == nil or args[2] == nil or args[3] == nil then return false end
    local ok, reason = LightRP.characters.setIdentity(target, { firstName = args[2], lastName = args[3] })
    if not ok then return false, "Name refused: " .. tostring(reason) end
    LightRP.chat.system(target, "The staff renamed your character: " .. LightRP.characters.displayName(target))
    return true, "Character renamed: " .. LightRP.characters.displayName(target)
end)

LightRP.command("lightrp.car", { restricted = true, usage = "/lightrp.car <model>" }, function(source, args)
    if args[1] == nil then return false end
    return LightRP.vehicles.request(source, args[1], true)
end)

LightRP.command("lightrp.status", { restricted = true }, function()
    local players = GetPlayers()
    local registered = 0
    for _, id in ipairs(players) do if LightRP.characters.isRegistered(id) then registered = registered + 1 end end
    return true, string.format("%s: %d players (%d characters), database %s.",
        Config.serverName, #players, registered, Db.ready and "online" or "offline")
end)
