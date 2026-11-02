-- op77_turf world: every native the war uses, behind one table, so tests/war_test.lua
-- can replace it with a fake world. Nothing here decides a rule.
TurfWorld = {}
local W = TurfWorld

local ALIVE = { alive = true, recovering = true }
local DOWN = { dead = true, dying = true, respawnpending = true, revivepending = true }

local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end

function W.now() return math.floor(Open77.time.monotonic() * 1000) end

function W.unix()
    if type(Open77.time) == "table" and type(Open77.time.unix) == "function" then
        local ok, unix = pcall(Open77.time.unix)
        if ok and tonumber(unix) then return math.floor(tonumber(unix)) end
    end
    return os.time()
end

-- { x, y, z, bucket } or nil (a replicated snapshot; nil once it is 2 s old).
function W.position(id)
    local ok, p = pcall(Open77.players.position, id)
    if ok and type(p) == "table" and type(p.x) == "number" then return p end
    return nil
end

-- The life phase ("alive", "dead", "respawnpending", ...) or nil when unknown.
function W.phase(id)
    local ok, life = pcall(Open77.players.getLifeState, id)
    if not ok or type(life) ~= "table" or life.phase == nil then return nil end
    return tostring(life.phase)
end

-- true = up, false = down, nil = unknown (never judged "down" on an unknown).
function W.alive(id)
    local phase = W.phase(id)
    if phase == nil then return nil end
    if ALIVE[phase] then return true end
    return false
end

function W.isDown(phase) return DOWN[phase] == true end

function W.name(id)
    local ok, name = pcall(Open77.players.name, id)
    return ok and type(name) == "string" and name or ("#" .. tostring(id))
end

function W.connected(id)
    for _, other in ipairs(GetPlayers()) do
        if tonumber(other) == id then return true end
    end
    return false
end

-- No ambient population in a war bucket (the forms Freeroam's PvP arena and op77_chase use).
function W.setupBucket(bucket)
    pcall(SetRoutingBucketPopulationEnabled, bucket, false)
    pcall(SetRoutingBucketEntityLockdownMode, bucket, "relaxed")
end

-- Loading cover (op77_loadscreen, optional): an id, or nil when the resource is absent.
function W.cover(id, opts)
    local ok, coverId = pcall(function() return exports.op77_loadscreen:cover(id, opts) end)
    return ok and coverId or nil
end

function W.uncover(id, coverId)
    if coverId == nil then return end
    pcall(function() exports.op77_loadscreen:release(id, coverId) end)
end

-- Put a player on a point inside the war bucket, asynchronously: done(ok, reason).
-- A living player is teleported (dismounted first); a player who is down is
-- respawned there instead (teleport refuses the dead).
function W.place(id, point, bucket, done, cover)
    CreateThread(function()
        local coverId = cover and W.cover(id, cover) or nil
        local ok, a, b = pcall(function()
            local position = { x = point.x, y = point.y, z = point.z }
            if W.alive(id) == false then
                local respawned, why = Open77.players.respawn(id, { position = position, heading = point.heading or 0, bucket = bucket })
                if not respawned then return false, tostring(why or "respawn_refused") end
                for _ = 1, 60 do
                    Wait(250)
                    if W.alive(id) then return true end
                end
                return false, "respawn_timeout"
            end
            local promise, why = Open77.players.teleport(id, position, {
                heading = point.heading or 0, bucket = bucket, fade = true, dismount = true, timeoutMs = 30000 })
            if not promise then return false, tostring(why or "teleport_refused") end
            local placed, failure = promise:await()
            if not placed then return false, tostring(failure or "teleport_failed") end
            return true
        end)
        W.uncover(id, coverId)
        if not ok then done(false, tostring(a)) return end
        done(a == true, b)
    end)
end

-- A living fighter back on a point of the same bucket (out of bounds), no callback.
function W.teleport(id, point, bucket)
    CreateThread(function()
        local ok, promise, why = pcall(Open77.players.teleport, id, { x = point.x, y = point.y, z = point.z },
            { heading = point.heading or 0, bucket = bucket, fade = true, dismount = true, timeoutMs = 15000 })
        if not ok or not promise then log("teleport of %d refused: %s", id, tostring(ok and why or promise)) return end
        pcall(function() promise:await() end)
    end)
end

-- A dead fighter back to life on a point: true | false, reason.
function W.respawn(id, point, bucket)
    local ok, done, why = pcall(Open77.players.respawn, id,
        { position = { x = point.x, y = point.y, z = point.z }, heading = point.heading or 0, bucket = bucket })
    if not ok then return false, tostring(done) end
    return done == true, why
end

-- Respawn a downed player where he lies (war bucket) so Light RP can move him home.
function W.respawnInPlace(id, bucket, fallback)
    local p = W.position(id) or fallback
    if p == nil then return false, "no_position" end
    return W.respawn(id, { x = p.x, y = p.y, z = p.z, heading = 0 }, bucket)
end

-- Hold (or release this resource's hold on) a player's body.
function W.freeze(id, frozen)
    if type(Open77.players.setFrozen) ~= "function" then return false end
    local ok, done = pcall(Open77.players.setFrozen, id, frozen == true)
    return ok and done == true
end

-- ---------------------------------------------------------------- combat

-- Same non-zero team = no friendly fire (platform). 0 = no team.
function W.setTeam(id, team)
    if type(Open77.combat) ~= "table" or type(Open77.combat.setTeam) ~= "function" then return false end
    local ok, done = pcall(Open77.combat.setTeam, id, math.max(0, math.floor(team or 0)))
    return ok and done == true
end

-- Global PvP is off on Light RP (platform default): a war is a PvP scope, the explicit
-- roster of living fighters in the bucket. Returns the scope id, or nil plus a reason.
function W.createScope(bucket, ids)
    if type(Open77.combat) ~= "table" or type(Open77.combat.createScope) ~= "function" then return nil, "scope_api_unavailable" end
    local ok, scope, why = pcall(Open77.combat.createScope, { bucket = bucket, players = ids })
    if not ok then return nil, tostring(scope) end
    return scope, why
end

function W.removeScope(scope)
    if scope == nil or type(Open77.combat) ~= "table" or type(Open77.combat.removeScope) ~= "function" then return false end
    local ok, done = pcall(Open77.combat.removeScope, scope)
    return ok and done == true
end

-- ---------------------------------------------------------------- kits

-- Open77.weapons answers asynchronously through open77:weapons:completed (matched to
-- this resource); the equip sequence below waits for each answer on its own thread.
local waiting = {}
AddEventHandler("open77:weapons:completed", function(player, request, _, accepted, reason, result)
    waiting[tostring(player) .. ":" .. tostring(request)] = { accepted = accepted, reason = reason, result = result }
end)

local function weapons(player, method, ...)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons[method]) ~= "function" then return nil, "weapons_api_unavailable" end
    local ok, request, why = pcall(Open77.weapons[method], player, ...)
    if not ok or not request then return nil, ok and why or request end
    local key = tostring(player) .. ":" .. tostring(request)
    local deadline = W.now() + 10000
    while not waiting[key] and W.now() < deadline do Wait(50) end
    local done = waiting[key]
    waiting[key] = nil
    if not done then return nil, "request_timeout" end
    if not done.accepted or done.accepted == "false" then return nil, done.reason end
    return done.result or true
end

local function slotsOf(snapshot) return type(snapshot) == "table" and (snapshot.slots or snapshot) or {} end
local function capacityOf(snapshot, slot)
    for _, row in ipairs(slotsOf(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == slot and type(row.ammo) == "table" then return tonumber(row.ammo.capacity) end
    end
end
local function armed(snapshot, kit)
    for _, row in ipairs(slotsOf(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == 1 then
            local a = type(row.ammo) == "table" and row.ammo or {}
            local rounds = tonumber(a.total) or ((tonumber(a.reserve) or 0) + (tonumber(a.magazine) or 0))
            return row.record == kit.primary and rounds > 0
        end
    end
    return false
end

-- Hands a kit over (Light RP's mission kit sequence): clear, primary in slot 1,
-- secondary in slot 2, reserves, full magazines, slot 1 drawn. `current()` returning
-- false (new life, war over) aborts between steps. Runs on its own thread.
function W.equip(id, kit, current)
    CreateThread(function()
        Wait(1200) -- the body lands first
        for attempt = 1, 3 do
            if not current() then return end
            local function step(method, ...)
                local result, why = weapons(id, method, ...)
                if not result and why ~= "weapon_slot_empty" then
                    log("kit %s for %d: %s refused (%s)", kit.id, id, method, tostring(why))
                end
                return result
            end
            step("clear")
            step("assign", kit.primary, 1, { active = true, addToInventory = true })
            step("assign", kit.secondary, 2, { active = false, addToInventory = true })
            for slot = 1, 2 do
                step("setAmmo", slot, { reserve = kit.reserve[slot], activate = slot == 1 })
                local capacity = capacityOf(step("requestSnapshot"), slot)
                if capacity then step("setAmmo", slot, { magazine = capacity, activate = slot == 1 }) end
            end
            step("setActive", 1)
            if not current() then return end
            if armed(weapons(id, "requestSnapshot"), kit) then return end
            log("kit %s for %d not in hand (attempt %d)", kit.id, id, attempt)
            Wait(2500)
        end
    end)
end

-- The kit goes before Light RP gives the RP weapons back (fire and forget).
function W.clearKit(id)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons.clear) ~= "function" then return false end
    local ok, request = pcall(Open77.weapons.clear, id)
    return ok and request ~= nil
end

-- ---------------------------------------------------------------- presentation

function W.state(id, shared, personal) TriggerClientEvent("op77_turf:state", id, shared, personal) end
function W.board(id, rows) TriggerClientEvent("op77_turf:board", id, rows) end
function W.site(id, payload) TriggerClientEvent("op77_turf:site", id, payload) end
function W.push(id, kind, payload) TriggerClientEvent("op77_turf:push", id, kind, payload) end
function W.clear(id) TriggerClientEvent("op77_turf:clear", id) end

function W.notify(id, kind, message, durationMs, title)
    if type(Open77.notifications) ~= "table" or type(Open77.notifications.send) ~= "function" then return end
    pcall(Open77.notifications.send, id, { type = kind or "info", title = title or "Turf War", message = message,
        durationMs = durationMs or 5000 })
end

-- The answer to a chat command (same channel as Light RP's own command replies).
function W.reply(source, raw, ok, text)
    print("[op77_turf] " .. tostring(text))
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
    end
end

-- Heading of a player (staff survey): Open77.players.get when it carries one.
function W.pose(id)
    local p = W.position(id)
    local heading
    if type(Open77.players.get) == "function" then
        local ok, read = pcall(Open77.players.get, id)
        if ok and type(read) == "table" then
            heading = tonumber(read.heading or read.yaw)
            if p == nil and type(read.position) == "table" then p = read.position end
        end
    end
    return p, heading
end
