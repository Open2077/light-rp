-- Dogtown PvP zone: polygon and exits, PvP arbitration through combat scopes and crew
-- teams, the stake (warning, escort, vehicles), combat tags, the loss and its bonus
-- bag (reserve, daily cap, anti-gank), bounties on op77_map3d, the strict pair
-- cooldown, combat logs, the hospital waiver, stats + Hall of Fame boards, the staff
-- command and the cleanup on stop, on the real inventory + economy (transactional SQL
-- model). Never touches live data.
local noop = function() end
local function clone(v) if type(v) ~= "table" then return v end local t = {}; for k, x in pairs(v) do t[k] = clone(x) end return t end
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("server/config/dogtown.lua")
local C = LightRpDogtown
-- Sections 1-15 test the zone without the entry protection; section 16 turns it back on.
local PROTECTION = C.entryProtection
C.entryProtection = { ms = 0 }
-- Sections 1-17 and 18 test the pocket-only stake (stake.bank = false, the rule before
-- 2026-11-12); section 17b tests the bank rule, the shipped default.
assert(C.stake.bank == true, "the bank counts by default")
C.stake.bank = false
local encoded, serial = {}, 0
json = { encode = function(v) serial = serial + 1; local k = "j" .. serial; encoded[k] = clone(v); return k end,
    decode = function(k) if k == "{}" then return {} end assert(encoded[k], "invalid JSON"); return clone(encoded[k]) end }

-- ---------------------------------------------------------------------------
-- SQL model (wallets, inventories, migrations, ledger, Dogtown stats and daily bonus)
local state = { wallets = {}, inventories = {}, migrations = {}, ledger = {}, dogtown = {}, bonus = {}, bestStreakColumn = false, alters = 0 }
local chars = {
    { identifier = "acct-a", key = "default", status = "active", firstName = "Ana", lastName = "Kill" },   -- 1 the killer
    { identifier = "acct-b", key = "default", status = "active", firstName = "Bo", lastName = "Prey" },    -- 2 the victim
    { identifier = "acct-a", key = "alt", status = "active", firstName = "Ana", lastName = "Alt" },        -- 3 the killer's other character
    { identifier = "acct-d", key = "default", status = "active", firstName = "Dee", lastName = "Crew" },   -- 4 the killer's crewmate
    { identifier = "acct-e", key = "default", status = "active", firstName = "Eli", lastName = "Broke" },  -- 5 under the stake
    { identifier = "acct-f", key = "default", status = "active", firstName = "Fay", lastName = "Walker" }, -- 6 a passer-by
    { identifier = "acct-g", key = "default", status = "active", firstName = "Gus", lastName = "Scoped" }, -- 7 in another resource's scope
}
local cash = { 1000, 2000, 3000, 4000, 50, 100, 1500 }
for i, c in ipairs(chars) do
    local number = string.format("A%02d-B%02d", i, i)
    state.wallets[number] = { account_number = number, identifier = c.identifier, character_key = c.key, owner_name = c.firstName, cash = cash[i], bank = 5000 }
end
local db = { ready = true, schema = noop, query = function() return {} end }
function db.read(sql, p)
    if sql:find("lightrp_inventories", 1, true) then return true, state.inventories[p[1]] and { clone(state.inventories[p[1]]) } or {} end
    if sql:find("lightrp_cash_migrations", 1, true) then return true, state.migrations[p[1]] and { clone(state.migrations[p[1]]) } or {} end
    if sql:find("lightrp_wallets", 1, true) then
        for _, w in pairs(state.wallets) do if w.identifier == p[1] and w.character_key == p[2] then return true, { clone(w) } end end
        return true, {}
    end
    if sql:find("FROM lightrp_dogtown_stats WHERE identifier", 1, true) then
        local rows = {}
        for _, r in pairs(state.dogtown) do
            if r.identifier == p[1] and r.character_key == p[2] and (r.week_index == 0 or r.week_index == p[3]) then rows[#rows + 1] = clone(r) end
        end
        return true, rows
    end
    if sql:find("WHERE week_index = ? AND kills > 0", 1, true) then
        local rows = {}
        for _, r in pairs(state.dogtown) do if r.week_index == p[1] and r.kills > 0 then rows[#rows + 1] = clone(r) end end
        table.sort(rows, function(a, b) if a.kills ~= b.kills then return a.kills > b.kills end return a.looted > b.looted end)
        local limit = tonumber(sql:match("LIMIT (%d+)"))
        while #rows > limit do table.remove(rows) end
        return true, rows
    end
    if sql:find("FROM lightrp_dogtown_stats WHERE week_index = 0 AND (kills > 0 OR best_streak > 0)", 1, true) then
        local rows = {}
        for _, r in pairs(state.dogtown) do if r.week_index == 0 and (r.kills > 0 or r.best_streak > 0) then rows[#rows + 1] = clone(r) end end
        return true, rows
    end
    if sql:find("FROM lightrp_dogtown_bonus_daily", 1, true) then
        local minted = state.bonus[p[1] .. "#" .. p[2]]
        return true, minted and { { minted = minted } } or {}
    end
    if sql:find("information_schema.COLUMNS", 1, true) then return true, { { n = state.bestStreakColumn and 1 or 0 } } end
    error("unmodelled read: " .. sql)
end
function db.single(sql, p)
    if sql:find("SELECT 1", 1, true) then return state.wallets[p[1]] and { x = 1 } end
    local ok, rows = db.read(sql, p); return ok and rows[1]
end
local function apply(s, sql, p)
    if sql:find("INSERT INTO lightrp_inventories", 1, true) then s.inventories[p[1]] = { items = p[6], slots = p[4], max_weight = p[5] }
    elseif sql:find("INSERT INTO lightrp_cash_migrations", 1, true) then
        s.migrations[p[1]] = { account_number = p[1], inventory_id = p[2], legacy_cash = p[3], inventory_before = p[4], slots_before = p[5] }
    elseif sql:find("INSERT INTO lightrp_wallets", 1, true) then s.wallets[p[1]] = { account_number = p[1], identifier = p[2], character_key = p[3], owner_name = p[4], cash = p[5], bank = p[6] }
    elseif sql:find("SET cash = 0", 1, true) then s.wallets[p[1]].cash = 0
    elseif sql:find("SET bank = ?", 1, true) then s.wallets[p[2]].bank = p[1]
    elseif sql:find("INSERT INTO lightrp_transactions", 1, true) then s.ledger[#s.ledger + 1] = clone(p)
    elseif sql:find("SET owner_name", 1, true) then s.wallets[p[2]].owner_name = p[1]
    elseif sql:find("INSERT INTO lightrp_dogtown_stats", 1, true) then
        local key = p[1] .. "#" .. p[2] .. "#" .. p[3]
        local r = s.dogtown[key] or { identifier = p[1], character_key = p[2], week_index = p[3], kills = 0, deaths = 0, looted = 0, best_streak = 0 }
        r.character_name, r.kills, r.deaths, r.looted = p[4], r.kills + p[5], r.deaths + p[6], r.looted + p[7]
        r.best_streak = math.max(r.best_streak, p[8])
        s.dogtown[key] = r
    elseif sql:find("INSERT INTO lightrp_dogtown_bonus_daily", 1, true) then
        local key = p[1] .. "#" .. p[2]
        s.bonus[key] = math.max(s.bonus[key] or 0, p[3])
    elseif sql:find("ALTER TABLE lightrp_dogtown_stats ADD COLUMN best_streak", 1, true) then s.bestStreakColumn, s.alters = true, s.alters + 1
    else error("unmodelled write: " .. sql) end
end
function db.run(sql, p) apply(state, sql, p); return true, 1 end
function db.transaction(writes)
    local draft = clone(state)
    for _, q in ipairs(writes) do apply(draft, q.query, q.values) end
    state = draft; return true
end

-- ---------------------------------------------------------------------------
-- Framework and host stubs
local clock = 100000
local modules, providers, notices, chatLines, replies, logs, commands, interactions, boards = {}, {}, {}, {}, {}, {}, {}, {}, {}
local owned, partyOf = {}, {}
LightRP = { db = db, log = function(f, ...) logs[#logs + 1] = select("#", ...) > 0 and string.format(f, ...) or tostring(f) end,
    module = function(n, t) LightRP[n] = t; modules[#modules + 1] = t; return t end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    command = function(n, _, fn) commands[n] = fn end, state = noop, broadcastState = noop,
    stateProvider = function(k, fn) providers[k] = fn end,
    notice = function(p, d) notices[#notices + 1] = { player = p, def = d } end, result = noop, action = noop,
    reply = function(source, raw, ok, text) replies[#replies + 1] = { source = source, ok = ok, text = text } end,
    interaction = function(id, d) interactions[id] = d end, removeInteraction = function(id) interactions[id] = nil end,
    dialog = noop, nowMs = function() return clock end, joinArgs = function() return "" end,
    characters = { get = function(id) return chars[id] end, isRegistered = function(id) return chars[id] ~= nil and chars[id].status == "active" end,
        displayName = function(id) return chars[id] and (chars[id].firstName .. " " .. chars[id].lastName) or ("#" .. id) end },
    chat = { system = function(p, text) chatLines[#chatLines + 1] = { player = p, text = text } end },
    parties = { of = function(id) return partyOf[id] end,
        members = function(id)
            local p = partyOf[id]
            if not p then return { id } end
            local list = {}; for i, m in ipairs(p.members) do list[i] = m end; return list
        end },
    activities = { owns = function(id) return owned[id] == true end, allows = function() return true end },
    hallOfFame = { registerBoard = function(key, def) boards[key] = def end },
}
local INSIDE, MARKET, OWNER = { x = -1700, y = -2350, z = 31.2 }, { x = -1850, y = -2200, z = 45.4 }, { x = -1727.8, y = -2360.3, z = 31.4 }
local CITY = { x = -1188, y = 320, z = 10 }
local positions, ages, life = {}, {}, {}
local function at(id, p, bucket) positions[id] = { x = p.x, y = p.y, z = p.z, bucket = bucket or 0 } end
for id = 1, 7 do at(id, CITY) end
local function bucketOf(id) return positions[id] and positions[id].bucket or 0 end
local function capable(id) local ph = life[id] or "alive"; return ph == "alive" or ph == "recovering" end
-- The host's combat scopes (DamageAuthorityService.CombatScopes), owner = this resource,
-- and its combat teams (global per player: the same nonzero team never hurts itself).
local hostScopes, scopeOf, scopeSeq, creates, hostTeams = {}, {}, 0, 0, {}
local arbiters, handlers, netHandlers, sent = {}, {}, {}, {}
local teleports, teleportFail, seats, occupants, transforms = {}, nil, {}, {}, {}
local unix = 1793577600 + 86400 -- Tuesday 2026-11-03 00:00 UTC
local DAY = math.floor(unix / 86400)
Open77 = {
    players = {
        position = function(id) return positions[id] end, positions = function() return positions end,
        get = function(id) local p = positions[id]; return p and { position = p, ageMs = ages[id] or 0, bucket = p.bucket, heading = 90 } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, pos, opts)
            if teleportFail then return nil, teleportFail end
            teleports[#teleports + 1] = { id = id, pos = clone(pos), opts = clone(opts) }
            return { await = function() at(id, pos, opts and opts.bucket or 0); return true end }
        end,
        getVehicleSeat = function(id) return seats[id] end,
    },
    routingBuckets = { getPlayer = bucketOf },
    vehicles = {
        seats = function() return { "seat_front_left", "seat_front_right", "seat_back_left", "seat_back_right" } end,
        occupantInSeat = function(vehicle, seat) return occupants[vehicle] and occupants[vehicle][seat] end,
        setTransform = function(vehicle, def) transforms[#transforms + 1] = { id = vehicle, def = clone(def) }; return true end,
    },
    time = { unix = function() return unix end, monotonic = function() return clock / 1000 end },
    combat = {
        onDamage = function(fn) arbiters[#arbiters + 1] = fn; return #arbiters end, offDamage = noop,
        setTeam = function(id, team) hostTeams[id] = team; return true end,
        createScope = function(def)
            local list = def.players
            if type(list) ~= "table" or #list < 2 or #list > 32 then return nil, "invalid_scope" end
            local count = 0; for _ in pairs(hostScopes) do count = count + 1 end
            if count >= 8 then return nil, "scope_limit" end
            for _, p in ipairs(list) do
                if bucketOf(p) ~= def.bucket or not capable(p) then return nil, "player_unavailable" end
                if scopeOf[p] then return nil, "player_scoped" end
            end
            scopeSeq, creates = scopeSeq + 1, creates + 1
            local id = string.format("%032x", scopeSeq)
            hostScopes[id] = { bucket = def.bucket, players = {} }
            for _, p in ipairs(list) do hostScopes[id].players[p] = true; scopeOf[p] = id end
            return id
        end,
        removeScope = function(id)
            local s = hostScopes[id]
            if not s then return nil, "scope_unavailable" end
            for p in pairs(s.players) do scopeOf[p] = nil end
            hostScopes[id] = nil
            return true
        end,
    },
}
-- op77_map3d's server exports (colon calls: the proxy comes first).
local blips = {}
exports = { op77_map3d = {
    addBlip = function(_, target, def) local id = "srv:op77_lightrp:" .. def.id; blips[id] = { target = target, def = clone(def) }; return id end,
    updateBlip = function(_, id, patch) if not blips[id] then return false, "unknown_blip" end; for k, v in pairs(patch) do blips[id].def[k] = clone(v) end; return true end,
    removeBlip = function(_, id) local had = blips[id] ~= nil; blips[id] = nil; return had end,
} }
local online = {}
GetPlayers = function() local list = {}; for i, id in ipairs(online) do list[i] = id end; return list end
GetPlayerName = function(id) return "P" .. id end
GetPlayerRoutingBucket = bucketOf
GetCurrentResourceName = function() return "op77_lightrp" end
TriggerClientEvent = function(name, player, payload) sent[#sent + 1] = { name = name, player = player, payload = payload } end
AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
CreateThread = function(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
Wait = function() coroutine.yield("wait") end
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end

dofile("server/modules/inventory.lua"); dofile("server/modules/economy.lua"); dofile("server/modules/dogtown.lua")
local I, M, D = LightRP.inventory, LightRP.money, LightRP.dogtown
for id = 1, 7 do I.onCharacterLoaded(id, chars[id]); M.onCharacterLoaded(id, chars[id]); D.onCharacterLoaded(id, chars[id]) end
for id = 1, 7 do assert(M.get(id).cash == cash[id] and I.cashOf(I.player(id)) == cash[id], "wallet " .. id .. " migrated") end

local function slot(inv, name) for k, v in pairs(inv.items) do if v.name == name then return k end end end
-- One hit through the host's gate (global friendly fire off: a shared scope in the
-- bucket, both players registered there, not on one team) and then every Lua arbiter.
local function hit(attacker, victim)
    local sa, sv = scopeOf[attacker], scopeOf[victim]
    if not (sa and sa == sv and hostScopes[sa].bucket == bucketOf(attacker) and bucketOf(attacker) == bucketOf(victim)) then return false, "friendly_fire_disabled" end
    local ta, tv = hostTeams[attacker] or 0, hostTeams[victim] or 0
    if ta ~= 0 and ta == tv then return false, "same_team" end
    for _, fn in ipairs(arbiters) do if fn({ victim = victim, attacker = attacker, amount = 10 }) == false then return false, "arbiter" end end
    fire("open77:playerDamaged", tostring(victim), tostring(attacker), "10", "ballistic", "", "torso", "90", "100", "0", "0")
    return true
end
local function kill(victim, killer, where)
    life[victim] = "dead"
    fire("open77:playerKilled", tostring(victim), tostring(killer), json.encode({ phase = "dead", killer = killer, position = where or positions[victim] }))
    D.onLifeState(victim, "dead", "alive")
end
local function revive(id) life[id] = "alive"; D.onLifeState(id, "alive", "dead") end
local function lastLedger(number) for i = #state.ledger, 1, -1 do if state.ledger[i][1] == number then return state.ledger[i] end end end
local function ledgerKind(number, kind) for i = #state.ledger, 1, -1 do local l = state.ledger[i]; if l[1] == number and l[3] == kind then return l end end end
local function lastNotice(player) for i = #notices, 1, -1 do if notices[i].player == player then return notices[i].def end end end
local function noticeTitled(player, title) for i = #notices, 1, -1 do if notices[i].player == player and notices[i].def.title == title then return notices[i].def end end end
local function countTitled(player, title) local n = 0; for _, x in ipairs(notices) do if x.player == player and x.def.title == title then n = n + 1 end end; return n end
local function logged(text) for i = #logs, 1, -1 do if logs[i]:find(text, 1, true) then return logs[i] end end end
local function sealedPiles()
    local list = {}
    for _, inv in pairs(I.registry) do if inv.kind == "drop" and inv.sealed then list[#list + 1] = inv end end
    return list
end
local function onlyPile() local list = sealedPiles(); assert(#list == 1, #list .. " sealed piles"); return list[1] end
local function clearPiles() for _, pile in ipairs(sealedPiles()) do I.removeDrop(pile) end end
-- Takes a whole pile into the player's pocket (standing on it).
local function take(player, pile)
    at(player, pile.position)
    local inv = I.player(player)
    return I.move(player, pile.id, slot(pile, "cash"), inv.id, slot(inv, "cash"), I.cashOf(pile))
end
local function stat(id, scope) local s = D.statsFor(id); return s and (scope == "total" and s.total or s.weekStats) end
-- What the host counts (every table, key and value, 1024 at most) for an event.
local function values(v) if type(v) ~= "table" then return 1 end; local n = 1; for _, x in pairs(v) do n = n + 1 + values(x) end; return n end
local function crew(id, members) local p = { id = id, leader = members[1], members = members }; for _, m in ipairs(members) do partyOf[m] = p end; D.onPartyChanged(id, members) end
local function disband(members) for _, m in ipairs(members) do partyOf[m] = nil end; D.onPartyChanged(nil, members) end
local function pin(id) return blips["srv:op77_lightrp:dogtown.bounty." .. id] end

-- ---------------------------------------------------------------------------
-- 1. The polygon and its exits
for _, p in ipairs({ INSIDE, MARKET, OWNER, { x = -2044, y = -2406 }, { x = -1290, y = -2025 }, C.blip.position }) do assert(D.contains(p), "inside " .. p.x .. "," .. p.y) end
for _, p in ipairs({ CITY, { x = -2600, y = -2400 }, { x = -900, y = -2300 }, { x = -2200, y = -2000 } }) do assert(not D.contains(p), "outside " .. p.x .. "," .. p.y) end
assert(not D.contains(LightRpConfig.spawn.hospital.position), "a killed player respawns outside Dogtown (the hospital)")
assert(not D.setPolygon({ { x = 0, y = 0 }, { x = 1, y = 1 } }), "fewer than 3 points is refused")
assert(not D.setPolygon({ { x = 0, y = 0 }, { x = 1, y = 1 }, { x = "a", y = 1 } }), "a non-numeric point is refused")
-- A concave "U": the notch is outside.
assert(D.setPolygon({ { x = 0, y = 0 }, { x = 30, y = 0 }, { x = 30, y = 30 }, { x = 20, y = 30 }, { x = 20, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 30 }, { x = 0, y = 30 } }, "test"))
assert(D.contains({ x = 5, y = 20 }) and D.contains({ x = 25, y = 20 }) and not D.contains({ x = 15, y = 20 }) and D.contains({ x = 15, y = 5 }))
assert(D.setPolygon(C.polygon, "config"))
for i, p in ipairs(C.polygon) do assert(type(p.x) == "number" and type(p.y) == "number", "vertex " .. i) end
-- Every configured exit stands outside; one inside is ignored; the nearest wins; none: the hospital.
assert(#C.exits >= 2 and #D.exits() == #C.exits, "every configured exit is outside the polygon")
assert(D.nearestExit(INSIDE).id == "pacifica_west" and D.nearestExit({ x = -1050, y = -2100 }).id == "stadium_east")
table.insert(C.exits, { id = "bad", x = INSIDE.x, y = INSIDE.y, z = INSIDE.z })
assert(#D.exits() == #C.exits - 1, "an exit inside the walls is ignored"); table.remove(C.exits)
local configuredExits = C.exits; C.exits = {}
assert(D.nearestExit(INSIDE).id == "hospital", "no usable exit: the hospital"); C.exits = configuredExits

-- ---------------------------------------------------------------------------
-- 2. Arbitration: inside, outside, tagged, activity buckets, switched off
online = { 1, 2, 6 }
at(1, INSIDE); at(2, MARKET); at(6, CITY)
D.sweep(true)
assert(D.roster()[1] and D.roster()[1] == D.roster()[2] and not D.roster()[6], "both inside share a scope, the passer-by has none")
assert(not hit(1, 6) and not hit(6, 1), "outside Dogtown, global PvP stays off")
assert(hit(1, 2) and D.tagged(1) and D.tagged(2), "inside: anyone can kill anyone; a hit tags both")
assert(providers.dogtown(2).inside and providers.dogtown(2).tagged and providers.dogtown(2).armed)
assert(not providers.dogtown(6).inside and not providers.dogtown(6).tagged)
local entry = chatLines[#chatLines].text
assert(entry:find("stake is €$ 1,000", 1, true) and entry:find("You carry €$ 2,000", 1, true), "entering names the stake and the cash carried")
-- A tagged player who steps out stays attackable until the tag runs out.
at(2, CITY); clock = clock + 5000; D.sweep()
assert(D.roster()[2] and hit(1, 2), "tagged and outside: still attackable")
assert(not providers.dogtown(2).inside and providers.dogtown(2).tagged)
clock = clock + C.combatTagMs + 1
assert(not hit(1, 2), "tag over, outside: the arbiter refuses before the next sweep")
D.sweep()
assert(not D.roster()[2] and not scopeOf[2], "the next sweep drops the grant")
assert(not hit(1, 2) and not hit(2, 1))
-- A stale position keeps the last answer (no flicker).
at(2, MARKET); D.sweep(); assert(D.roster()[2])
ages[2] = 10000; at(2, CITY); D.sweep(); assert(D.roster()[2] and D.inside(2), "a stale read keeps the player inside")
ages[2] = nil; D.sweep(); assert(not D.roster()[2])
-- Activity and mission buckets never get Dogtown PvP, even at Dogtown coordinates.
at(2, MARKET, 4100001); D.sweep()
assert(not D.roster()[2] and not D.inside(2) and not hit(1, 2), "an arena bucket in Dogtown is not Dogtown")
at(2, MARKET, 3000007); D.sweep(); assert(not D.roster()[2], "a mission bucket neither")
at(2, MARKET, 0); owned[2] = true; D.sweep()
assert(not D.roster()[2], "a player an activity owns in the city bucket is left out")
owned[2] = nil; D.sweep(); assert(D.roster()[2] and hit(1, 2))
-- Downed / dead players hold no grant.
life[2] = "dead"; D.onLifeState(2, "dead", "alive"); D.sweep(); assert(not D.roster()[2])
revive(2); D.sweep(); assert(D.roster()[2])
-- A player another resource already scoped is left out, the others keep PvP.
online = { 1, 2, 6, 7 }; at(7, OWNER); scopeOf[7] = "foreign"
D.sweep(true)
assert(D.roster()[1] and D.roster()[2] and not D.roster()[7] and scopeOf[7] == "foreign", "one refused player does not block the group")
scopeOf[7] = nil; clock = clock + 4000; D.sweep(); assert(D.roster()[7], "retried once released")
online = { 1, 2, 6 }; at(7, CITY); D.sweep()
-- The switch.
assert(commands["lightrp.dogtown"](0, { "off" }, "lightrp.dogtown off") == true)
assert(not D.isEnabled() and next(hostScopes) == nil and not D.tagged(1), "off: every grant removed, tags cleared")
D.sweep(); assert(not hit(1, 2) and not providers.dogtown(1).inside and not providers.dogtown(1).enabled)
local okStatus, text = commands["lightrp.dogtown"](0, { "status" }, "lightrp.dogtown status")
assert(okStatus and text:find("Dogtown OFF", 1, true))
assert(commands["lightrp.dogtown"](0, { "on" }, "lightrp.dogtown on") == true and D.isEnabled())
D.sweep(); assert(hit(1, 2))
-- Groups: at most 32 per scope, even, west to east, at most 8 scopes.
local many = {}; for i = 1, 40 do many[i] = 1000 + i end
local groups = D.groups(many); assert(#groups == 2 and #groups[1] == 20 and #groups[2] == 20)
many = {}; for i = 1, 300 do many[i] = 1000 + i end
groups = D.groups(many); assert(#groups == 8); for _, g in ipairs(groups) do assert(#g == 32) end
assert(#D.groups({ 1 }) == 0, "alone: nobody to fight, no scope")

-- ---------------------------------------------------------------------------
-- 3. Crews: one combat team per crew in the scope, updated when crews change
local TEAM = C.teamBase
online = { 1, 2, 4 }; at(4, OWNER)
crew("crew:1", { 1, 4 }); D.sweep()
assert(D.roster()[4] and hostTeams[1] == TEAM + 1 and hostTeams[4] == TEAM + 1 and (hostTeams[2] or 0) == 0, "crewmates share a team")
assert(select(2, hit(1, 4)) == "same_team" and not hit(4, 1), "crewmates never hurt each other")
assert(hit(1, 2) and hit(4, 2), "the crew still fights everyone else")
hostTeams[4] = 0
assert(select(2, hit(1, 4)) == "arbiter", "between two team updates the arbiter refuses crewmates")
hostTeams[4] = TEAM + 1
disband({ 1, 4 })
assert(hostTeams[1] == 0 and hostTeams[4] == 0 and hit(1, 4), "the crew gone, its team goes")
-- Leaving the roster puts a player back on no team, unless an activity took them.
crew("crew:1", { 1, 4 }); assert(hostTeams[4] == TEAM + 1)
at(4, CITY); clock = clock + C.combatTagMs + 1; D.sweep()
assert(not D.roster()[4] and hostTeams[4] == 0 and D.teams()[4] == nil, "out of the zone: no team")
at(4, OWNER); D.sweep(); assert(hostTeams[4] == TEAM + 1)
owned[4] = true; D.sweep()
assert(not D.roster()[4] and hostTeams[4] == TEAM + 1 and D.teams()[4] == nil, "an activity's team is left alone")
owned[4] = nil; hostTeams[4] = 0
disband({ 1, 4 }); D.sweep()
assert(hostTeams[1] == 0 and hostTeams[4] == 0)

-- ---------------------------------------------------------------------------
-- 4. The stake: warned with the amount missing, no PvP, escorted out after the grace
online = { 1, 2, 5, 6 }; at(5, INSIDE); at(6, MARKET)
local t0 = clock
D.sweep()
local warn = noticeTitled(5, "DOGTOWN · NO STAKE")
assert(warn and warn.body:find("€$ 950 missing", 1, true) and warn.body:find("10 s", 1, true), "warned with the amount missing")
assert(noticeTitled(6, "DOGTOWN · NO STAKE").body:find("€$ 900 missing", 1, true))
assert(not D.roster()[5] and not hit(1, 5) and not hit(5, 1), "under the stake: no PvP either way")
local view5 = providers.dogtown(5)
assert(view5.stake.short and view5.stake.missing == 950 and view5.stake.required == 1000 and view5.stake.cash == 50 and view5.stake.evictInMs == C.stake.graceMs)
-- Topping up in time ends it.
assert(M.addCash(6, 900, "test", "Top-up"))
D.sweep(); assert(not D.short(6) and D.roster()[6], "carrying the stake again: back in the fight")
assert(countTitled(5, "DOGTOWN · NO STAKE") == 1, "warned once")
-- An escort the host refuses is retried 3 s later.
clock = t0 + C.stake.graceMs; teleportFail = "player_unavailable"; D.sweep()
assert(positions[5].x == INSIDE.x and D.short(5) and logged("escorting Eli Broke out refused"), "a refused escort waits")
teleportFail = nil; clock = clock + 1000; D.sweep(); assert(#teleports == 0, "not at once")
clock = clock + 2000; D.sweep()
local tp = teleports[#teleports]
assert(tp and tp.id == 5 and tp.opts.dismount == true and tp.opts.bucket == 0 and tp.opts.fade == true, "escorted on foot")
assert(positions[5].x == C.exits[1].x and positions[5].y == C.exits[1].y and not D.short(5), "to the nearest exit")
assert(noticeTitled(5, "Escorted out of Dogtown").body:find("Pacifica, west of the market", 1, true) and logged("Eli Broke escorted out to pacifica_west"))
D.sweep(); assert(not D.inside(5) and not D.short(5))
-- A driver alone takes the car out, parked beside them; a car with passengers stays.
seats[5] = { vehicleId = 77, seat = "seat_front_left" }; occupants[77] = { seat_front_left = 5 }
assert(D.soloCar(5) == 77)
occupants[77].seat_back_left = 6; assert(D.soloCar(5) == nil, "a passenger: the car stays"); occupants[77].seat_back_left = nil
seats[6] = { vehicleId = 77, seat = "seat_front_right" }; assert(D.soloCar(6) == nil, "a passenger never takes the car"); seats[6] = nil
at(5, INSIDE); D.sweep(); clock = clock + C.stake.graceMs; D.sweep()
local moved = transforms[#transforms]
assert(moved and moved.id == 77 and moved.def.yaw == C.exits[1].heading and math.abs(moved.def.position.x - (C.exits[1].x + 4)) < 0.01, "the car parked beside its driver")
assert(noticeTitled(5, "Escorted out of Dogtown").body:find("with your car", 1, true) and positions[5].x == C.exits[1].x)
seats[5], occupants[77] = nil, nil

-- ---------------------------------------------------------------------------
-- 5. The loss and the bonus
assert(D.lossAmount(1000) == 100 and D.lossAmount(2000) == 200 and D.lossAmount(1234) == 123, "10%")
assert(D.lossAmount(500) == 100 and D.lossAmount(150) == 100, "at least 100")
assert(D.lossAmount(99) == 99 and D.lossAmount(50) == 50, "never more than carried")
assert(D.lossAmount(7500) == 750 and D.lossAmount(999999) == 750, "at most 750")
assert(D.lossAmount(0) == 0 and D.lossAmount(-5) == 0)
local terms = D.killTerms(1, 2, 2000)
assert(terms.loss == 200 and terms.bonus == 50 and not terms.gank and not terms.underdog, "+25% bonus")
assert(D.verdict(1, 3) == "same_account", "two characters of one account")
partyOf[1] = { id = "crew:1", members = { 1, 4 } }; partyOf[4] = partyOf[1]
assert(D.verdict(1, 4) == "crewmate", "a crewmate"); partyOf[1], partyOf[4] = nil, nil
assert(D.verdict(1, 2) == nil)

-- ---------------------------------------------------------------------------
-- 6. A credited kill drops the loss + the bonus as a sealed bag, reserved to the killer's crew.
online = { 1, 2, 6 }; at(1, INSIDE); at(2, MARKET); at(6, CITY); D.sweep()
local victimInv, killerInv = I.player(2), I.player(1)
assert(hit(1, 2))
kill(2, 1, MARKET)
local bag = onlyPile()
assert(I.cashOf(bag) == 250, "10% of 2,000 + the 25% server bonus")
assert(bag.position.x == MARKET.x and bag.position.y == MARKET.y and bag.bucket == 0 and bag.label:find("€$ 250", 1, true))
assert(I.cashOf(victimInv) == 1800 and M.get(2).cash == 1800 and M.get(2).bank == 5000, "the bank is never touched")
local line = lastLedger(M.get(2).number)
assert(line[3] == "dogtown_loss" and line[4] == -200 and line[6] == "Ana Kill", "the victim's ledger line")
assert(stat(1).kills == 1 and stat(2).deaths == 1 and stat(1, "total").kills == 1 and stat(1).bestStreak == 1 and D.streak(1) == 1)
assert(state.bonus["acct-a#" .. DAY] == 50 and logged("dogtown bonus: +50 minted into a cash bag for acct-a"), "the bonus is counted per account and logged")
assert(lastNotice(1).title == "Dogtown kill" and lastNotice(1).body:find("€$ 50 bonus", 1, true) and lastNotice(2).body:find("€$ 200", 1, true))
assert(bag.reserve.untilMs == clock + C.loot.reserveMs and bag.reserve.allows(1) and not bag.reserve.allows(6) and not bag.reserve.allows(2))
at(6, MARKET); local passer = I.player(6)
local refused, reason = I.move(6, bag.id, slot(bag, "cash"), passer.id, slot(passer, "cash"), 10)
assert(not refused and reason == "reserved", "a passer-by waits for the reserve")
partyOf[1] = { id = "crew:9", members = { 1, 6 } }; partyOf[6] = partyOf[1]
assert(bag.reserve.allows(6), "the killer's crew may take it"); partyOf[1], partyOf[6] = nil, nil
at(6, CITY)
-- Sealed: nothing goes in, a drop beside it makes its own pile.
at(1, MARKET)
refused, reason = I.move(1, killerInv.id, slot(killerInv, "cash"), bag.id, 2, 10)
assert(not refused and reason == "sealed", "nothing can be put in a cash bag")
local dropped, pile = I.drop(1, slot(killerInv, "cash"), 10)
assert(dropped and pile ~= bag and I.cashOf(bag) == 250, "never merged with another pile")
assert(I.move(1, pile.id, slot(pile, "cash"), killerInv.id, slot(killerInv, "cash"), 10) and M.get(1).cash == 1000)
-- The killer picks it up: the ledger says loot and names the bonus, the stats count it.
assert(I.move(1, bag.id, slot(bag, "cash"), killerInv.id, slot(killerInv, "cash"), 250))
assert(M.get(1).cash == 1250 and not I.get(bag.id), "picked up, the bag is gone")
line = lastLedger(M.get(1).number)
assert(line[3] == "dogtown_loot" and line[4] == 250 and line[6] == "Bo Prey" and line[7]:find("€$ 50 server bonus", 1, true), "the picker's ledger line")
assert(stat(1).looted == 250 and stat(1, "total").looted == 250)

-- ---------------------------------------------------------------------------
-- 7. Pair cooldown: the same killer on the same victim within 10 minutes counts for NOTHING.
revive(2); at(2, MARKET); D.sweep(); assert(hit(1, 2))
kill(2, 1)
assert(#sealedPiles() == 0 and M.get(2).cash == 1800 and stat(1).kills == 1 and stat(2).deaths == 1 and D.streak(1) == 1, "no kill, no death, no loss")
assert(state.bonus["acct-a#" .. DAY] == 50 and lastNotice(1).body:find("10 minutes", 1, true) and lastNotice(2).body:find("kept your cash", 1, true))
-- ... but the victim can still take revenge (the other direction is a fresh pair).
revive(2); D.sweep(); assert(hit(2, 1))
kill(1, 2, INSIDE)
local own = onlyPile()
assert(stat(2).kills == 1 and stat(1).deaths == 1 and I.cashOf(own) == 125 + 31 and M.get(1).cash == 1125, "10% of 1,250 + 25%")
assert(D.streak(1) == 0 and D.streak(2) == 1 and state.bonus["acct-b#" .. DAY] == 31, "dying ends a streak")
-- The hospital bill is waived after a Dogtown death, until shortly after getting up.
assert(D.waivesHospital(1) and not D.waivesHospital(6))
revive(1); at(1, INSIDE)
refused, reason = I.move(1, own.id, slot(own, "cash"), killerInv.id, slot(killerInv, "cash"), 156)
assert(not refused and reason == "reserved", "the victim waits for the reserve too")
clock = clock + 10000; assert(D.waivesHospital(1))
clock = clock + 5001; assert(not D.waivesHospital(1), "back on their feet: the next bill applies")
C.waiveHospitalBill = false; assert(not D.waivesHospital(2)); C.waiveHospitalBill = true
-- After the reserve anyone may take it; the owner taking their own bag back is not loot.
assert(I.move(1, own.id, slot(own, "cash"), killerInv.id, slot(killerInv, "cash"), 156))
line = lastLedger(M.get(1).number)
assert(line[3] == "inventory" and stat(1).looted == 250 and M.get(1).cash == 1281, "recovering your own cash is not loot")
-- Revived under the stake: warned and escorted like anyone else.
at(6, MARKET); D.sweep()
assert(M.get(6).cash == 1000 and D.roster()[6])
assert(hit(2, 6)); kill(6, 2, MARKET)
local bag6 = onlyPile()
assert(I.cashOf(bag6) == 125 and M.get(6).cash == 900 and D.streak(2) == 2)
revive(6); D.sweep()
assert(D.short(6) and not D.roster()[6] and lastNotice(6).body:find("€$ 100 missing", 1, true), "revived under the stake")
assert(take(2, bag6) and M.get(2).cash == 1925)
at(6, CITY); D.sweep(); assert(not D.short(6), "out of the zone: no more warning")

-- ---------------------------------------------------------------------------
-- 8. Same account, crewmates, outside: nothing at all.
online = { 1, 3 }; at(1, INSIDE); at(3, OWNER); D.sweep(); assert(hit(1, 3))
kill(3, 1)
assert(M.get(3).cash == 3000 and stat(1).kills == 1 and stat(3).deaths == 0 and #sealedPiles() == 0, "same account: no kill, no death, no loss")
assert(lastNotice(1).body:find("Same account", 1, true))
revive(3)
online = { 1, 4 }; at(4, OWNER); crew("crew:1", { 1, 4 }); D.sweep()
assert(not hit(1, 4), "crewmates cannot hurt each other")
kill(4, 1) -- a fall or an explosion during the fight: still scoped together
assert(M.get(4).cash == 4000 and stat(1).kills == 1 and stat(4).deaths == 0, "crewmate")
revive(4); disband({ 1, 4 })
online = { 1, 6 }; at(6, CITY); D.sweep()
local deaths6 = stat(6).deaths
kill(6, 1)
assert(M.get(6).cash == 900 and stat(6).deaths == deaths6, "outside Dogtown nothing happens")
revive(6)

-- ---------------------------------------------------------------------------
-- 9. Transfer mode: straight into the killer's pocket, the bonus paid beside it.
C.loot.mode = "transfer"
online = { 1, 7 }; at(7, OWNER); D.sweep(); assert(hit(1, 7))
local before, mintedA = M.get(1).cash, state.bonus["acct-a#" .. DAY]
kill(7, 1)
assert(M.get(7).cash == 1350 and M.get(1).cash == before + 150 + 37, "10% of 1,500 + 25%")
assert(lastLedger(M.get(7).number)[3] == "dogtown_loss" and ledgerKind(M.get(1).number, "dogtown_loot")[4] == 150)
local bonusLine = lastLedger(M.get(1).number)
assert(bonusLine[3] == "dogtown_bonus" and bonusLine[4] == 37 and bonusLine[6] == "Gus Scoped", "the bonus has its own ledger line")
assert(state.bonus["acct-a#" .. DAY] == mintedA + 37 and logged("dogtown bonus: +37 to acct-a"))
assert(stat(1).looted == 250 + 150 + 37 and stat(1).kills == 2)
C.loot.mode = "bag"; revive(7)

-- ---------------------------------------------------------------------------
-- 10. The daily bonus cap: per killer ACCOUNT and UTC day, read back from the database.
C.loot.bonusDailyCap = 70
online = { 2, 7 }; at(2, OWNER); D.sweep(); assert(hit(2, 7))
kill(7, 2)
local capped = onlyPile() -- acct-b had 31 + 25 = 56 today: 14 left of 70
assert(I.cashOf(capped) == 135 + 14 and state.bonus["acct-b#" .. DAY] == 70 and D.bonusLeft("acct-b") == 0, "the bonus stops at the cap")
assert(lastNotice(2).body:find("daily bonus limit (€$ 70) reached", 1, true))
assert(take(2, capped)); revive(7)
C.loot.bonusDailyCap = 3000
-- A new UTC day starts over; coming back reads the day's total from the database.
unix = unix + 86400; assert(D.bonusLeft("acct-b") == 3000)
unix = unix - 86400; assert(D.bonusLeft("acct-b") == 3000 - 70)

-- ---------------------------------------------------------------------------
-- 11. Anti-gank: a crew of 4+ in the zone halves the loss (the bag and its bonus with
-- it); killing a member of a bigger crew adds +50% to the bonus.
online = { 1, 2, 4, 6, 7 }; at(1, INSIDE); at(2, MARKET); at(4, OWNER); at(6, MARKET); at(7, OWNER)
crew("crew:2", { 4, 1, 6, 7 }); D.sweep()
assert(D.crewInZone(4) == 4 and D.crewInZone(2) == 1, "a stakeless crewmate in the zone still counts")
state.bonus["acct-d#" .. DAY] = 2990 -- earned before a restart
assert(hit(4, 2))
local cash2 = M.get(2).cash
kill(2, 4, OWNER)
local gank = onlyPile()
local halved = math.floor(D.lossAmount(cash2) * C.antiGank.lossFactor)
assert(I.cashOf(gank) == halved + 10 and M.get(2).cash == cash2 - halved, "half the loss; the bonus stops at the cap read back from the database")
assert(state.bonus["acct-d#" .. DAY] == 3000 and lastNotice(4).body:find("halved", 1, true) and lastNotice(2).body:find("outnumbered", 1, true))
assert(take(4, gank))
revive(2); D.sweep(); assert(hit(2, 4))
local cash4, mintedB = M.get(4).cash, state.bonus["acct-b#" .. DAY]
kill(4, 2, OWNER)
local underdog = onlyPile()
local loss4 = D.lossAmount(cash4)
local extra = math.floor(loss4 * 0.25 * 1.5)
assert(I.cashOf(underdog) == loss4 + extra and state.bonus["acct-b#" .. DAY] == mintedB + extra, "a bigger crew: bonus x 1.5")
assert(lastNotice(2).body:find("bigger crew", 1, true))
assert(take(2, underdog)); revive(4)
disband({ 4, 1, 6, 7 })

-- ---------------------------------------------------------------------------
-- 12. Bounty: five credited kills in a row put a pin on everyone's map, and pay whoever
-- takes the target down.
clock = clock + C.loot.pairCooldownMs + 1 -- every pair is fresh
assert(M.addCash(6, 1100, "test", "Top-up"))
online = { 1, 2, 4, 6, 7 }; at(1, INSIDE); at(2, OWNER); at(4, OWNER); at(6, MARKET); at(7, OWNER); D.sweep()
assert(D.streak(2) == 1)
for _, victim in ipairs({ 1, 4, 7 }) do assert(hit(2, victim), "hit " .. victim); kill(victim, 2); revive(victim); D.sweep() end
assert(D.streak(2) == 4 and next(D.bounties()) == nil and next(blips) == nil, "no bounty under 5")
assert(hit(2, 6)); kill(6, 2); revive(6)
clearPiles()
local wanted = pin(2)
assert(D.streak(2) == 5 and D.bounties()[2] and wanted and wanted.target == -1, "a bounty pin for everyone")
assert(wanted.def.icon == "crosshair" and wanted.def.label == "BOUNTY · Bo Prey" and wanted.def.position.x == OWNER.x and wanted.def.description:find("€$ 1,250", 1, true))
assert(noticeTitled(2, "BOUNTY ON YOU") and noticeTitled(1, "DOGTOWN BOUNTY") and noticeTitled(7, "DOGTOWN BOUNTY"))
assert(D.bountyReward(2) == 1250 and providers.dogtown(2).bounty and providers.dogtown(2).bountyReward == 1250 and providers.dogtown(1).bounties == 1)
-- The pin follows the target.
at(2, INSIDE); clock = clock + C.bounty.refreshMs; D.sweep()
assert(wanted.def.position.x == INSIDE.x and wanted.def.position.y == INSIDE.y, "moved on the map")
-- Taking the target down pays the bounty (pocket cash, ledger, daily cap) and lifts the pin.
local cash1, mintedA2 = M.get(1).cash, state.bonus["acct-a#" .. DAY]
local cash2c = M.get(2).cash
assert(hit(1, 2)); kill(2, 1)
assert(not D.bounties()[2] and not pin(2) and D.streak(2) == 0, "the pin goes with the target")
local reward = lastLedger(M.get(1).number)
assert(reward[3] == "dogtown_bounty" and reward[4] == 1250 and reward[6] == "Bo Prey" and reward[7]:find("5-kill streak", 1, true))
assert(M.get(1).cash == cash1 + 1250 and noticeTitled(1, "BOUNTY CLAIMED") and logged("dogtown bounty: +1250 to acct-a"))
assert(state.bonus["acct-a#" .. DAY] == mintedA2 + 1250 + math.floor(D.lossAmount(cash2c) * 0.25), "the bounty counts in the daily cap")
clearPiles()
-- Leaving the zone ends a streak and lifts the pin; so do any death and a disconnect.
C.bounty.streak = 1
D.markBounty(1)
assert(D.streak(1) == 1 and pin(1))
at(1, CITY); clock = clock + C.combatTagMs + 1; D.sweep()
assert(D.streak(1) == 0 and not pin(1) and noticeTitled(1, "Bounty lifted"), "left the zone")
at(1, INSIDE); revive(2); D.sweep()
assert(hit(4, 1)); kill(1, 4); revive(1)
assert(pin(4))
C.bounty.perKill = 2000; assert(D.bountyReward(4) == C.bounty.max, "capped"); C.bounty.perKill = 250
life[4] = "dead"; D.onLifeState(4, "dead", "alive"); revive(4)
assert(not pin(4) and D.streak(4) == 0, "any death")
D.sweep(); assert(hit(7, 6)); kill(6, 7); revive(6)
assert(pin(7))
D.onDisconnected(7)
assert(not pin(7) and not D.bounties()[7], "a disconnect")
D.onCharacterLoaded(7, chars[7])
C.bounty.streak = 5; clearPiles()

-- ---------------------------------------------------------------------------
-- 13. Combat log: disconnecting mid-fight drops the bag of a death (no bonus), reserved
-- to the last attacker's crew (onDisconnecting: inventory and wallet still loaded).
online = { 1, 2 }; at(1, INSIDE); at(2, MARKET); revive(2)
clock = clock + C.combatTagMs + 1; D.sweep(); assert(hit(1, 2))
local cash2b, mintedA3 = M.get(2).cash, state.bonus["acct-a#" .. DAY]
LightRP.eachModule("onDisconnecting", 2, "quit")
local logBag = onlyPile()
local lossLog = D.lossAmount(cash2b)
assert(I.cashOf(logBag) == lossLog and M.get(2).cash == cash2b - lossLog, "the loss of a death, no bonus")
assert(logBag.position.x == MARKET.x and logBag.reserve.allows(1) and not logBag.reserve.allows(6))
assert(lastLedger(M.get(2).number)[3] == "dogtown_loss" and logged("combat log by Bo Prey") and state.bonus["acct-a#" .. DAY] == mintedA3)
assert(lastNotice(1).body:find("logged out mid-fight", 1, true))
D.onDisconnected(2); D.onCharacterLoaded(2, chars[2])
assert(take(1, logBag))
line = lastLedger(M.get(1).number); assert(line[3] == "dogtown_loot" and line[7]:find("Combat-log", 1, true))
-- Not tagged, dying, or the zone off: nothing.
clock = clock + C.combatTagMs + 1; D.sweep()
assert(D.combatLog(2) == nil, "not tagged")
assert(hit(1, 2)); life[2] = "dead"; assert(D.combatLog(2) == nil, "dying: the kill counts instead"); life[2] = "alive"
D.setEnabled(false, "test"); assert(D.combatLog(2) == nil, "zone off"); D.setEnabled(true, "test")
assert(#sealedPiles() == 0)

-- ---------------------------------------------------------------------------
-- 14. Stats: database rows (lifetime + week, best streak), leaderboard, page, Hall of Fame
local week = D.weekIndex()
local life2, life1 = state.dogtown["acct-b#default#0"], state.dogtown["acct-a#default#0"]
assert(life2.kills == 8 and life2.deaths == 3 and life2.best_streak == 5 and life2.looted == 125 + 149 + loss4 + extra,
    string.format("Bo: credited kills %d, deaths %d, best streak %d, loot %d", life2.kills, life2.deaths, life2.best_streak, life2.looted))
assert(life1.kills == 3 and life1.deaths == 3 and life1.best_streak == 1 and state.dogtown["acct-a#default#" .. week].kills == 3 and life1.character_name == "Ana Kill")
assert(state.dogtown["acct-a#alt#0"] == nil, "a blocked pair writes nothing")
local top = D.refreshBoard(true).rows
assert(top[1].name == "Bo Prey" and top[1].kills == 8 and top[2].name == "Ana Kill" and top[2].kills == 3)
local view = providers.dogtown(2)
assert(view.mine.total.kills == 8 and view.mine.total.bestStreak == 5 and view.mine.week.looted == life2.looted and view.top[1].name == "Bo Prey" and view.week == week)
local r = view.rules
assert(r.stake == 1000 and r.share == 0.1 and r.min == 100 and r.max == 750 and r.bonus == 0.25 and r.bonusDailyCap == 3000 and r.reserveSeconds == 15
    and r.tagSeconds == 20 and r.pairCooldownMinutes == 10 and r.graceSeconds == 10 and r.gankCrew == 4 and r.gankFactor == 0.5 and r.underdogBonus == 0.5
    and r.bountyStreak == 5 and r.bountyPerKill == 250 and r.bountyMax == 1500, "the page gets the live rules")
assert(view.stake.required == 1000 and view.bonusToday == state.bonus["acct-b#" .. DAY])
assert(values(view) < 900, "the page state fits a plain event (" .. values(view) .. " values)")
-- Reloaded from the database on reconnect.
D.onDisconnected(2); assert(not D.statsFor(2)); D.onCharacterLoaded(2, chars[2])
assert(stat(2, "total").kills == 8 and stat(2, "total").bestStreak == 5 and stat(2).looted == life2.looted)
-- Weeks start on Monday 00:00 UTC; a new week starts the weekly counters over.
local monday = 1793577600
unix = monday - 1; local sunday = D.weekIndex(); unix = monday; assert(D.weekIndex() == sunday + 1)
unix = monday + 7 * 86400
assert(stat(2).kills == 0 and stat(2, "total").kills == 8, "a new week")
assert(#D.refreshBoard(true).rows == 0)
unix = 1793577600 + 86400
-- The Hall of Fame boards: lifetime, credited kills only.
assert(boards["dogtown.kills"] and boards["dogtown.kills"].tab == "pvp" and boards["dogtown.streak"].tab == "pvp" and boards["dogtown.streak"].overview == false)
local function keyOf(identifier, key) return identifier .. "#" .. (key or "default") end
local function byKey(rows) local t = {}; for _, row in ipairs(rows) do t[row.key] = row end; return t end
local ctx = { db = db, read = db.read, keyOf = keyOf }
local kills = byKey(boards["dogtown.kills"].provider(ctx))
assert(kills["acct-b#default"].value == 8 and kills["acct-b#default"].detail == "K/D 2.67 · best streak 5" and kills["acct-b#default"].name == "Bo Prey")
assert(kills["acct-a#alt"] == nil and kills["acct-e#default"] == nil, "no credited kill, no row")
local streaks = byKey(boards["dogtown.streak"].provider(ctx))
assert(streaks["acct-b#default"].value == 5 and streaks["acct-b#default"].detail == "8 kills · K/D 2.67")
-- Without a database the stats live in memory for the session.
db.ready = false
D.record(6, { kills = 9, streak = 9 })
top = D.refreshBoard(true).rows
assert(top[1].name == "Fay Walker" and top[1].kills == 9 and top[2].name == "Bo Prey", "memory leaderboard")
kills = byKey(boards["dogtown.kills"].provider({ keyOf = keyOf }))
assert(kills["acct-f#default"].value == 9 and kills["acct-b#default"].value == 8, "memory Hall of Fame")
db.ready = true
-- A table from before best_streak gets the column once.
D.onDatabaseReady()
assert(state.bestStreakColumn and state.alters == 1 and logged("migrated: lightrp_dogtown_stats.best_streak added"))
D.onDatabaseReady(); assert(state.alters == 1, "once")

-- ---------------------------------------------------------------------------
-- 15. Staff: exits, status, survey (points, the client's district, apply for the session)
at(1, { x = -2300, y = -1900, z = 12.5 })
local okExit, exitLine = commands["lightrp.dogtown"](1, { "survey", "exit" }, "")
assert(okExit and exitLine:find('id = "exit_5"', 1, true) and exitLine:find("x = -2300.0, y = -1900.0, z = 12.50, heading = 90.0", 1, true))
at(1, INSIDE)
local noExit, why = commands["lightrp.dogtown"](1, { "survey", "exit" }, "")
assert(noExit == false and why:find("inside the polygon", 1, true))
local _, status = commands["lightrp.dogtown"](0, { "status" }, "")
assert(status:find("4 exit(s)", 1, true) and status:find("stake €$ 1,000", 1, true) and status:find("loss 10%", 1, true) and status:find("bonus 25%", 1, true))
local function answerProbe(player, district)
    for i = #sent, 1, -1 do
        local s = sent[i]
        if s.name == "op77_lightrp:dogtown" and s.player == player and s.payload.kind == "probe" then
            source = player
            netHandlers["op77_lightrp:dogtown:report"]({ kind = "probe", token = s.payload.token, district = district })
            return
        end
    end
    error("no probe sent")
end
at(1, { x = 0, y = 0, z = 0 }); assert(commands["lightrp.dogtown"](1, { "survey", "add" }, "") == nil); answerProbe(1, "Westbrook")
assert(replies[#replies].text:find("Point #1", 1, true) and replies[#replies].text:find("Westbrook", 1, true))
at(1, { x = 100, y = 0, z = 0 }); commands["lightrp.dogtown"](1, { "survey", "add" }, ""); answerProbe(1, "Dogtown")
at(1, { x = 0, y = 100, z = 0 }); commands["lightrp.dogtown"](1, { "survey", "add" }, ""); answerProbe(1, "Dogtown")
assert(replies[#replies].text:find("Point #3", 1, true))
local listed = select(2, commands["lightrp.dogtown"](1, { "survey", "list" }, ""))
assert(listed:find("3 point", 1, true) and logs[#logs]:find("{ x = 100.0, y = 0.0 }, -- surveyed (Dogtown)", 1, true))
local function lastConfig() for i = #sent, 1, -1 do if sent[i].payload and sent[i].payload.kind == "config" then return sent[i] end end end
assert(commands["lightrp.dogtown"](1, { "survey", "apply" }, "") == true)
assert(D.contains({ x = 10, y = 10 }) and not D.contains(INSIDE) and select(2, D.polygon()):find("survey", 1, true))
local applied = lastConfig()
assert(applied.player == -1 and #applied.payload.outline == 6 and applied.payload.outline[3] == 100, "the surveyed outline reaches every map at once")
assert(applied.payload.area.label == C.area.label and applied.payload.area.labelPosition == nil, "a label point outside the surveyed zone is dropped")
assert(commands["lightrp.dogtown"](1, { "survey", "reset" }, "") == true and D.contains(INSIDE))
local back = lastConfig().payload
assert(#back.outline == #C.polygon * 2 and back.outline[1] == C.polygon[1].x and back.area.labelPosition.x == C.area.labelPosition.x, "reset: the configured outline again")
assert(select(2, commands["lightrp.dogtown"](0, { "survey", "add" }, "")):find("player in game", 1, true), "the console cannot survey")
-- The engine's district against the polygon: logged, never granted from.
at(1, CITY); source = 1
netHandlers["op77_lightrp:dogtown:report"]({ kind = "district", district = "Dogtown" })
assert(logs[#logs]:find("engine says Dogtown, polygon says outside", 1, true))
-- The map pin config reaches the client, with the zone's outline and look for op77_map3d.
source = 1; netHandlers["op77_lightrp:dogtown:report"]({ kind = "hello" })
local cfg = sent[#sent].payload
assert(cfg.kind == "config" and cfg.blip.position.x == C.blip.position.x)
assert(cfg.area.fill == "#FF2E3C" and cfg.area.pattern == "hatch" and cfg.area.minimap == true and cfg.area.label == "DOGTOWN · DANGER ZONE")
assert(D.contains(C.area.labelPosition), "the configured label point is inside the zone")
assert(values(cfg) < 1024, "the config event fits (" .. values(cfg) .. " values)")
-- A surveyed polygon of up to 512 points reaches the map as at most 150, its shape kept.
local ring = {}
for k = 1, 512 do local t = (k - 1) / 512 * 2 * math.pi; ring[k] = { x = -1750 + math.cos(t) * 500 + (k % 2) * 0.01, y = -2500 + math.sin(t) * 400 } end
ring[129] = { x = -1750, y = -2500 + 400 * 1.6 } -- a sharp spike: kept
assert(D.setPolygon(ring, "test"))
local o = D.outline()
assert(#o == 300, "decimated to 150 points (" .. #o / 2 .. ")")
local spike = false
for i = 1, #o, 2 do if o[i] == -1750 and o[i + 1] == -1860 then spike = true end end
assert(spike, "the most significant vertex survives")
for i = 1, #o do assert(o[i] * 10 == math.floor(o[i] * 10 + 0.5), "rounded to 0.1 m") end
D.sendConfig(1)
assert(values(sent[#sent].payload) < 1024, "the largest config event fits (" .. values(sent[#sent].payload) .. " values)")
local points = {}
for i = 1, #o, 2 do points[#points + 1] = { x = o[i], y = o[i + 1] } end
local def = { id = "lightrp.dogtown", points = points, fill = "#FF2E3C", fillOpacity = 0.22, stroke = "#FF2E3C", strokeWidth = 2.5, pattern = "hatch",
    label = C.area.label, labelPosition = { x = 1, y = 2 }, map = true, minimap = true, pulse = false }
assert(values(def) < 1024, "and so does the area definition (" .. values(def) .. " values)")
assert(D.setPolygon(C.polygon, "config"))

-- ---------------------------------------------------------------------------
-- 16. Entry protection: two minutes out of the PvP grant after walking in.
C.entryProtection = PROTECTION
assert(C.entryProtection.ms == 120000 and C.entryProtection.rearmMs == 60000, "two minutes, re-armed after a minute away")
online = { 1, 7 }
for _, id in ipairs({ 1, 7 }) do D.onDisconnected(id); life[id] = "alive"; at(id, CITY) end
disband({ 1, 4 })
assert(D.staked(1) and D.staked(7), "both carry the stake")
D.sweep()
-- 1 walks in first: protected, out of the grant; then the camper at the gate.
at(1, INSIDE); D.sweep()
assert(D.protected(1) and not D.roster()[1] and noticeTitled(1, "DOGTOWN · ENTRY PROTECTION"), "entering protects")
assert(chatLines[#chatLines].text:find("Entry protection: 120 s.", 1, true), "the entry line names it")
clock = clock + 120001; D.sweep()
assert(not D.protected(1) and noticeTitled(1, "DOGTOWN · PROTECTION OVER"), "it runs out, with a warning")
-- 7 walks in past the camper.
at(7, MARKET); D.sweep()
local start7 = clock
assert(D.protected(7) and not D.roster()[7], "the newcomer is protected")
local page7 = providers.dogtown(7)
assert(page7.protected and page7.protectedInMs == 120000 and page7.rules.protectionSeconds == 120 and page7.inside and not page7.armed)
assert(not hit(1, 7) and not hit(7, 1), "nobody can hurt them, nor they anyone")
-- the arbiter refuses too, should both still hold a scope from an earlier sweep
assert(D.arbitrate({ victim = 7, attacker = 1 }) == nil or D.arbitrate({ victim = 7, attacker = 1 }) == false)
-- Stepping back out and in does not reset the timer.
clock = clock + 5000; at(7, CITY); D.sweep(); clock = clock + 5000; at(7, MARKET); D.sweep()
assert(D.protected(7) and D.protectedMs(7) == 120000 - 10000, "same countdown after a step out")
clock = start7 + 120001; D.sweep()
assert(not D.protected(7) and D.roster()[7] and D.roster()[1] and hit(1, 7), "after two minutes: fair game")
assert(D.tagged(7))
-- Tagged: no new protection on a re-entry.
at(7, CITY); D.sweep(); clock = clock + 2000; at(7, MARKET); D.sweep()
assert(not D.protected(7), "never while combat-tagged")
-- Back out (tag over), 30 s away: not re-armed yet.
clock = clock + C.combatTagMs + 1; at(7, CITY); D.sweep()
clock = clock + 30000; D.sweep(); at(7, MARKET); D.sweep()
assert(not D.protected(7), "30 s away is not enough")
-- A minute away: re-armed.
at(7, CITY); D.sweep(); clock = clock + 61000; D.sweep(); at(7, MARKET); D.sweep()
assert(D.protected(7) and not D.roster()[7], "re-armed after a minute out")
clock = clock + 120001; D.sweep(); assert(not D.protected(7))
-- A death (any) re-arms it at once.
life[7] = "dead"; D.onLifeState(7, "dead"); revive(7); at(7, CITY); D.sweep(); at(7, MARKET); D.sweep()
assert(D.protected(7), "after a death the next entry is protected")
-- A death while protected ends it (the hospital is outside anyway).
life[7] = "dead"; D.onLifeState(7, "dead"); assert(not D.protected(7)); revive(7)
-- Switched off: nothing on entry.
C.entryProtection = { ms = 0 }
at(7, CITY); D.sweep(); D.onLifeState(7, "dead"); revive(7); at(7, MARKET); D.sweep()
assert(not D.protected(7) and D.roster()[7], "ms = 0: no protection")
C.entryProtection = PROTECTION
-- Zone off: no protection reported.
at(7, CITY); D.sweep(); D.onLifeState(7, "dead"); revive(7); at(7, MARKET); D.sweep(); assert(D.protected(7))
D.setEnabled(false, "test"); assert(not D.protected(7) and not providers.dogtown(7).protected); D.setEnabled(true, "test")
clock = clock + 120001; D.sweep()
online = { 1, 2, 6 }
C.entryProtection = { ms = 0 } -- the stop section below fights at once

-- ---------------------------------------------------------------------------
-- 17. Doors held open (open77_doors): areas and ids, claimed, never auto-closing.
local doorReg, configures, registers = {}, 0, 0
local function door(id, x, y, extra)
    local d = { id = id, bucket = 0, position = { x = x, y = y, z = 30 }, open = false, locked = true, sealed = true,
        automatic = false, autoClose = true, lift = false }
    for k, v in pairs(extra or {}) do d[k] = v end
    doorReg[#doorReg + 1] = d
    return d
end
local area = C.openDoors.areas[1]
local A = door("0xAAAA000000000001", area.x + 5, area.y - 8)                          -- in the area
local B = door(C.openDoors.ids[1], -1430, -2760)                                      -- listed by id, far away
local Cd = door("0xAAAA000000000003", area.x + area.radius + 5, area.y)              -- just outside the area
local Lf = door("0xAAAA000000000004", area.x, area.y, { lift = true })                -- a lift door: never
local E = door("0xAAAA000000000005", area.x - 3, area.y + 3, { owner = "open77_elevators" }) -- another resource's
for i = 1, 20 do door(string.format("0xBBBB%012X", i), 500 + i, 500) end             -- filler: two more pages
exports.open77_doors = {
    list = function(_, bucket, offset, limit)
        assert(bucket == 0 and limit == 16)
        local out = {}
        for i = offset + 1, math.min(#doorReg, offset + limit) do out[#out + 1] = clone(doorReg[i]) end
        return { doors = out, total = #doorReg, nextOffset = offset + #out < #doorReg and offset + #out or nil }
    end,
    register = function(_, desc)
        registers = registers + 1
        for _, d in ipairs(doorReg) do
            if d.id == desc.id then
                if d.owner and d.owner ~= "op77_lightrp" then return nil, "owned_by_other_resource" end
                d.owner = "op77_lightrp"; return clone(d)
            end
        end
        return nil, "invalid_descriptor"
    end,
    configure = function(_, id, bucket, patch)
        configures = configures + 1
        for _, d in ipairs(doorReg) do
            if d.id == id then
                if d.owner ~= "op77_lightrp" then return false, "not_owner" end
                for k, v in pairs(patch) do d[k] = v end
                if d.locked or d.sealed then d.open = false end
                return true
            end
        end
        return false, "unknown"
    end,
}
assert(#C.openDoors.ids == 6 and area.id == "nw_checkpoint", "the checkpoint opened by hand on Testing")
local held, seen = D.holdDoors()
assert(seen == #doorReg and held == 2, "every page read, two doors held (" .. held .. "/" .. seen .. ")")
for _, d in ipairs({ A, B }) do
    assert(d.owner == "op77_lightrp" and d.open and not d.locked and not d.sealed and not d.automatic and d.autoClose == false, d.id .. " held open")
end
assert(not Cd.owner and not Cd.open, "outside the area: untouched")
assert(not Lf.owner and not Lf.open, "a lift door: untouched")
assert(E.owner == "open77_elevators" and not E.open and logged("door 0xAAAA000000000005 not held open (claim: owned_by_other_resource)"))
assert(logged("door 0xAAAA000000000001 held open at"), "each claim is logged with its position")
-- Settled: the next pass changes nothing.
local before = configures; D.holdDoors(); assert(configures == before, "nothing to change on a settled door")
-- An admin (or a quest) closes one: the next pass opens it again.
A.open, A.autoClose = false, true; D.holdDoors()
assert(A.open and A.autoClose == false, "closed by hand: opened again")
-- Ids match whatever their case; open77_doors gone: logged, no error.
assert(D.wantsDoor({ id = C.openDoors.ids[2]:lower(), bucket = 0, position = { x = 0, y = 0, z = 0 } }))
assert(not D.wantsDoor({ id = C.openDoors.ids[2], bucket = 7, position = { x = 0, y = 0, z = 0 } }), "only the city bucket")
exports.open77_doors = nil
assert(D.holdDoors() == 0 and logged("open77_doors unavailable"))

-- ---------------------------------------------------------------------------
-- 17b. The bank rule (stake.bank, default since 2026-11-12): the stake counts pocket
-- cash + bank; a death's loss is paid from the pocket first, the bank tops it up.
C.stake.bank = true
online = { 5, 6 }; at(5, INSIDE); at(6, INSIDE); revive(5); revive(6)
clock = clock + C.loot.pairCooldownMs + C.combatTagMs + 1
D.sweep()
local w5 = M.get(5)
local pocket5, bank5 = w5.cash, w5.bank
local loss5 = D.lossAmount(pocket5 + bank5)
assert(pocket5 < C.stake.minCash and pocket5 < loss5 and bank5 > loss5, "Eli: a short pocket (" .. pocket5 .. "), a bank (" .. bank5 .. ")")
assert(D.fundsOf(5) == pocket5 + bank5 and D.staked(5), "the bank counts in the stake")
assert(not D.short(5) and D.roster()[5], "a short pocket is no longer left out")
local view5b = providers.dogtown(5)
assert(view5b.stake.cash == pocket5 + bank5 and view5b.stake.bank == true and view5b.rules.stakeBank == true, "the page counts the bank")
assert(hit(6, 5)); kill(5, 6, INSIDE)
local bankBag = onlyPile()
assert(I.cashOf(bankBag) >= loss5, "the bag holds the whole loss in cash: " .. I.cashOf(bankBag) .. " for " .. loss5)
assert(M.get(5).cash == 0 and M.get(5).bank == bank5 - (loss5 - pocket5), "the pocket paid first, the bank the rest")
local wd = ledgerKind(M.get(5).number, "dogtown_withdraw")
assert(wd, "the top-up is on the victim's ledger")
assert(lastNotice(5).body:find("cash first, then your bank", 1, true), lastNotice(5).body)
assert(take(6, bankBag))
-- a refused withdrawal (the database): the pocket pays alone
revive(5); clock = clock + C.loot.pairCooldownMs + 1; D.sweep()
assert(M.addCash(5, 300, "test", "Pocket"))
local bankBefore = M.get(5).bank
local withdraw = M.withdraw
M.withdraw = function() return false, "database_error" end
local covered = D.cover(5, 500)
M.withdraw = withdraw
assert(covered == 300 and M.get(5).bank == bankBefore and logged("bank top-up of 200 for Eli Broke refused"), "a refused top-up: the pocket alone")
assert(D.cover(5, 200) == 200 and M.get(5).bank == bankBefore, "a pocket that covers it: the bank is not touched")
C.stake.bank = false
assert(not D.staked(5) and D.fundsOf(5) == 300, "bank = false: the pocket only")
online = {}; D.sweep()

-- ---------------------------------------------------------------------------
-- 18. Stopping the resource takes everything with it: scopes, teams, pins, bags.
online = { 1, 2, 4 }; at(1, INSIDE); at(2, MARKET); at(4, OWNER); revive(2)
crew("crew:3", { 1, 4 }); D.sweep()
C.bounty.streak = 1
assert(hostTeams[1] == TEAM + 3 and hit(4, 2)); kill(2, 4)
local left = onlyPile()
assert(pin(4) and next(hostScopes))
fire("onResourceStop", "op77_lightrp")
assert(next(hostScopes) == nil and hostTeams[1] == 0 and hostTeams[4] == 0, "scopes and teams released")
assert(next(blips) == nil and not I.get(left.id), "bounty pins and cash bags removed")
C.bounty.streak = 5

print("PASS: Dogtown polygon + exits; PvP scopes inside/outside/tagged/stale/activity buckets/dead/foreign scope/switch; groups of 32; crew teams; stake warning/top-up/escort/retry/solo car; loss min/max/carried; bonus bag + reserve + sealed; strict pair cooldown/revenge/own bag; bank stake + pocket-first loss with bank top-up; hospital waiver; revive under stake; same account/crewmate/outside; transfer + bonus line; daily cap (db read, new day); anti-gank halving + underdog; bounty pin/follow/claim/left/death/disconnect/cap; combat log; stats + best streak + migration; leaderboard; page rules; Hall of Fame boards; survey + exits + map outline; entry protection (2 min, step-out, tag, re-arm, death, off); doors held open (areas, ids, lifts, foreign owner, re-open); cleanup on stop")
