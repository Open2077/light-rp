-- Dogtown PvP zone: polygon, PvP arbitration through combat scopes, combat tags,
-- loot rules on the real inventory + economy (transactional SQL model), stats and
-- the staff command. Never touches live data.
local noop = function() end
local function clone(v) if type(v) ~= "table" then return v end local t = {}; for k, x in pairs(v) do t[k] = clone(x) end return t end
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
dofile("server/config/dogtown.lua")
local C = LightRpDogtown
local encoded, serial = {}, 0
json = { encode = function(v) serial = serial + 1; local k = "j" .. serial; encoded[k] = clone(v); return k end,
    decode = function(k) if k == "{}" then return {} end assert(encoded[k], "invalid JSON"); return clone(encoded[k]) end }

-- ---------------------------------------------------------------------------
-- SQL model (wallets, inventories, migrations, ledger, Dogtown stats)
local state = { wallets = {}, inventories = {}, migrations = {}, ledger = {}, dogtown = {} }
local chars = {
    { identifier = "acct-a", key = "default", status = "active", firstName = "Ana", lastName = "Kill" },   -- 1 the killer
    { identifier = "acct-b", key = "default", status = "active", firstName = "Bo", lastName = "Prey" },    -- 2 the victim
    { identifier = "acct-a", key = "alt", status = "active", firstName = "Ana", lastName = "Alt" },        -- 3 the killer's other character
    { identifier = "acct-d", key = "default", status = "active", firstName = "Dee", lastName = "Crew" },   -- 4 the killer's crewmate
    { identifier = "acct-e", key = "default", status = "active", firstName = "Eli", lastName = "Broke" },  -- 5 poor
    { identifier = "acct-f", key = "default", status = "active", firstName = "Fay", lastName = "Walker" }, -- 6 a passer-by
    { identifier = "acct-g", key = "default", status = "active", firstName = "Gus", lastName = "Scoped" }, -- 7 in another resource's scope
}
local cash = { 1000, 2000, 3000, 4000, 50, 100, 500 }
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
        local r = s.dogtown[key] or { identifier = p[1], character_key = p[2], week_index = p[3], kills = 0, deaths = 0, looted = 0 }
        r.character_name, r.kills, r.deaths, r.looted = p[4], r.kills + p[5], r.deaths + p[6], r.looted + p[7]
        s.dogtown[key] = r
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
local modules, providers, notices, chatLines, replies, logs, commands, interactions = {}, {}, {}, {}, {}, {}, {}, {}
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
    parties = { of = function(id) return partyOf[id] end },
    activities = { owns = function(id) return owned[id] == true end, allows = function() return true end },
}
local INSIDE, MARKET, OWNER = { x = -1700, y = -2350, z = 31.2 }, { x = -1850, y = -2200, z = 45.4 }, { x = -1727.8, y = -2360.3, z = 31.4 }
local CITY = { x = -1188, y = 320, z = 10 }
local positions, ages, life = {}, {}, {}
local function at(id, p, bucket) positions[id] = { x = p.x, y = p.y, z = p.z, bucket = bucket or 0 } end
for id = 1, 7 do at(id, CITY) end
local function bucketOf(id) return positions[id] and positions[id].bucket or 0 end
local function capable(id) local ph = life[id] or "alive"; return ph == "alive" or ph == "recovering" end
-- The host's combat scopes (DamageAuthorityService.CombatScopes), owner = this resource.
local hostScopes, scopeOf, scopeSeq, creates = {}, {}, 0, 0
local arbiters, handlers, netHandlers, sent = {}, {}, {}, {}
local unix = 1793577600 + 86400 -- Tuesday 2026-11-03 00:00 UTC
Open77 = {
    players = {
        position = function(id) return positions[id] end, positions = function() return positions end,
        get = function(id) local p = positions[id]; return p and { position = p, ageMs = ages[id] or 0, bucket = p.bucket, heading = 90 } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function() return nil, "not_in_test" end,
    },
    routingBuckets = { getPlayer = bucketOf },
    vehicles = {},
    time = { unix = function() return unix end, monotonic = function() return clock / 1000 end },
    combat = {
        onDamage = function(fn) arbiters[#arbiters + 1] = fn; return #arbiters end, offDamage = noop,
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
-- bucket, both players registered there) and then every Lua arbiter.
local function hit(attacker, victim)
    local sa, sv = scopeOf[attacker], scopeOf[victim]
    if not (sa and sa == sv and hostScopes[sa].bucket == bucketOf(attacker) and bucketOf(attacker) == bucketOf(victim)) then return false, "friendly_fire_disabled" end
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
local function lastNotice(player) for i = #notices, 1, -1 do if notices[i].player == player then return notices[i].def end end end
local function sealedPiles()
    local list = {}
    for _, inv in pairs(I.registry) do if inv.kind == "drop" and inv.sealed then list[#list + 1] = inv end end
    return list
end
local function stat(id, scope) local s = D.statsFor(id); return s and (scope == "total" and s.total or s.weekStats) end

-- ---------------------------------------------------------------------------
-- 1. The polygon
for _, p in ipairs({ INSIDE, MARKET, OWNER, { x = -2044, y = -2406 }, { x = -1290, y = -2025 }, C.blip.position }) do assert(D.contains(p), "inside " .. p.x .. "," .. p.y) end
for _, p in ipairs({ CITY, { x = -2600, y = -2400 }, { x = -900, y = -2300 }, { x = -2200, y = -2000 } }) do assert(not D.contains(p), "outside " .. p.x .. "," .. p.y) end
assert(not D.contains(LightRpConfig.spawn.hospital), "a killed player respawns outside Dogtown (the hospital)")
assert(not D.setPolygon({ { x = 0, y = 0 }, { x = 1, y = 1 } }), "fewer than 3 points is refused")
assert(not D.setPolygon({ { x = 0, y = 0 }, { x = 1, y = 1 }, { x = "a", y = 1 } }), "a non-numeric point is refused")
-- A concave "U": the notch is outside.
assert(D.setPolygon({ { x = 0, y = 0 }, { x = 30, y = 0 }, { x = 30, y = 30 }, { x = 20, y = 30 }, { x = 20, y = 10 }, { x = 10, y = 10 }, { x = 10, y = 30 }, { x = 0, y = 30 } }, "test"))
assert(D.contains({ x = 5, y = 20 }) and D.contains({ x = 25, y = 20 }) and not D.contains({ x = 15, y = 20 }) and D.contains({ x = 15, y = 5 }))
assert(D.setPolygon(C.polygon, "config"))
for i, p in ipairs(C.polygon) do assert(type(p.x) == "number" and type(p.y) == "number", "vertex " .. i) end

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
assert(chatLines[#chatLines].text:find("You carry €$ 2,000 in cash", 1, true), "entering warns about the cash carried")
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
-- 3. Loot rules
assert(D.lootAmount(1000) == 100 and D.lootAmount(2000) == 200 and D.lootAmount(1234) == 123, "10%")
assert(D.lootAmount(10000) == 500 and D.lootAmount(999999) == 500, "capped at 500")
assert(D.lootAmount(99) == 0 and D.lootAmount(100) == 10 and D.lootAmount(0) == 0 and D.lootAmount(-5) == 0, "nothing under the threshold")
assert(D.verdict(1, 3) == "same_account", "two characters of one account")
partyOf[1] = { id = 1, members = { 1, 4 } }; partyOf[4] = partyOf[1]
assert(D.verdict(1, 4) == "crewmate", "a crewmate")
assert(D.verdict(1, 2) == nil)

-- 4. A kill drops a sealed cash bag where the victim fell.
local victimInv, killerInv = I.player(2), I.player(1)
assert(hit(1, 2))
kill(2, 1, MARKET)
local piles = sealedPiles()
assert(#piles == 1 and I.cashOf(piles[1]) == 200, "10% of 2,000 in a bag")
local bag = piles[1]
assert(bag.position.x == MARKET.x and bag.position.y == MARKET.y and bag.bucket == 0 and bag.label:find("€$ 200", 1, true))
assert(I.cashOf(victimInv) == 1800 and M.get(2).cash == 1800 and M.get(2).bank == 5000, "the bank is never touched")
local line = lastLedger(M.get(2).number)
assert(line[3] == "dogtown_loss" and line[4] == -200 and line[6] == "Ana Kill", "the victim's ledger line")
assert(stat(1).kills == 1 and stat(2).deaths == 1 and stat(1, "total").kills == 1)
assert(lastNotice(1).title == "Dogtown kill" and lastNotice(2).body:find("€$ 200", 1, true))
-- Sealed: nothing goes in, a drop beside it makes its own pile.
at(6, MARKET); local passer = I.player(6)
local refused, reason = I.move(6, passer.id, slot(passer, "cash"), bag.id, 2, 10)
assert(not refused and reason == "sealed", "nothing can be put in a cash bag")
local dropped, pile = I.drop(6, slot(passer, "cash"), 10)
assert(dropped and pile ~= bag and I.cashOf(bag) == 200, "never merged with another pile")
assert(I.move(6, pile.id, slot(pile, "cash"), passer.id, slot(passer, "cash"), 10) and M.get(6).cash == 100)
at(6, CITY)
-- The killer picks it up: the ledger says loot, the stats count it.
at(1, MARKET)
assert(I.move(1, bag.id, slot(bag, "cash"), killerInv.id, slot(killerInv, "cash"), 200))
assert(M.get(1).cash == 1200 and not I.get(bag.id), "picked up, the bag is gone")
line = lastLedger(M.get(1).number)
assert(line[3] == "dogtown_loot" and line[4] == 200 and line[6] == "Bo Prey", "the picker's ledger line")
assert(stat(1).looted == 200 and stat(1, "total").looted == 200)
-- Pair cooldown: the same killer on the same victim within 10 minutes takes nothing, scores nothing.
revive(2); at(2, MARKET); D.sweep(); assert(hit(1, 2))
kill(2, 1)
assert(#sealedPiles() == 0 and M.get(2).cash == 1800 and stat(1).kills == 1 and stat(2).deaths == 2, "pair cooldown")
assert(lastNotice(1).body:find("10 minutes", 1, true))
-- ... but the victim can still take revenge (the other direction).
revive(2); D.sweep(); assert(hit(2, 1))
kill(1, 2, INSIDE)
assert(stat(2).kills == 1 and #sealedPiles() == 1 and I.cashOf(sealedPiles()[1]) == 120, "the other direction is a fresh pair")
-- The owner picking their own bag back is not loot.
revive(1); at(1, INSIDE)
local own = sealedPiles()[1]
assert(I.move(1, own.id, slot(own, "cash"), killerInv.id, slot(killerInv, "cash"), 120))
line = lastLedger(M.get(1).number)
assert(line[3] == "inventory" and stat(1).looted == 200, "recovering your own cash is not loot")
-- After the cooldown the pair loots again.
clock = clock + C.loot.pairCooldownMs + 1
D.sweep(); assert(hit(1, 2))
kill(2, 1)
assert(stat(1).kills == 2 and #sealedPiles() == 1 and I.cashOf(sealedPiles()[1]) == 180, "10% of 1,800 after the cooldown")
-- Threshold: under 100 eddies, nothing is taken but the kill counts.
revive(2); online = { 1, 2, 5 }; at(5, OWNER); D.sweep(); assert(hit(1, 5))
kill(5, 1)
assert(M.get(5).cash == 50 and stat(1).kills == 3 and #sealedPiles() == 1 and lastNotice(1).body:find("less than", 1, true))
-- Same account: nothing, no kill (the death still counts).
revive(5); online = { 1, 3 }; at(3, OWNER); D.sweep(); assert(hit(1, 3))
kill(3, 1)
assert(M.get(3).cash == 3000 and stat(1).kills == 3 and stat(3).deaths == 1, "same account")
-- Crewmate: nothing, no kill.
revive(3); online = { 1, 4 }; at(4, OWNER); D.sweep(); assert(hit(1, 4), "crewmates can still hurt each other")
kill(4, 1)
assert(M.get(4).cash == 4000 and stat(1).kills == 3, "crewmate")
revive(4); partyOf[1], partyOf[4] = nil, nil
-- A kill that is not a Dogtown kill (no Dogtown hit, not scoped together) does nothing.
online = { 1, 6 }; at(6, CITY); D.sweep()
kill(6, 1)
assert(M.get(6).cash == 100 and stat(6).deaths == 0, "outside Dogtown nothing happens")
revive(6)

-- 5. Transfer mode: straight into the killer's pocket, through the ledger.
C.loot.mode = "transfer"
at(6, MARKET); D.sweep(); assert(hit(1, 6))
local before = M.get(1).cash
kill(6, 1)
assert(M.get(6).cash == 90 and M.get(1).cash == before + 10, "10% of 100 transferred")
assert(lastLedger(M.get(6).number)[3] == "dogtown_loss" and lastLedger(M.get(1).number)[3] == "dogtown_loot")
assert(stat(1).looted == 210 and stat(1).kills == 4)
C.loot.mode = "bag"
revive(6)

-- ---------------------------------------------------------------------------
-- 6. Stats: database rows, lifetime + this week, leaderboard
local week = D.weekIndex()
local lifetime, weekly = state.dogtown["acct-a#default#0"], state.dogtown["acct-a#default#" .. week]
assert(lifetime.kills == 4 and lifetime.looted == 210 and weekly.kills == 4 and lifetime.character_name == "Ana Kill")
assert(state.dogtown["acct-b#default#0"].deaths == 3 and state.dogtown["acct-b#default#0"].kills == 1)
assert(state.dogtown["acct-a#alt#0"].deaths == 1 and state.dogtown["acct-a#alt#0"].kills == 0, "the same-account death is a death, not a kill")
local top = D.refreshBoard(true).rows
assert(top[1].name == "Ana Kill" and top[1].kills == 4 and top[2].name == "Bo Prey" and top[2].kills == 1)
local view = providers.dogtown(1)
assert(view.mine.week.kills == 4 and view.mine.total.looted == 210 and view.top[1].name == "Ana Kill" and view.week == week)
assert(view.rules.share == 0.1 and view.rules.max == 500 and view.rules.minCash == 100 and view.rules.tagSeconds == 20 and view.rules.pairCooldownMinutes == 10)
-- Reloaded from the database on reconnect.
D.onDisconnected(1); assert(not D.statsFor(1)); D.onCharacterLoaded(1, chars[1]); assert(stat(1).kills == 4 and stat(1, "total").looted == 210)
-- Weeks start on Monday 00:00 UTC; a new week starts the weekly counters over.
local monday = 1793577600
unix = monday - 1; local sunday = D.weekIndex(); unix = monday; assert(D.weekIndex() == sunday + 1)
unix = monday + 7 * 86400
assert(stat(1).kills == 0 and stat(1, "total").kills == 4, "a new week")
assert(#D.refreshBoard(true).rows == 0)
unix = 1793577600 + 86400
-- Without a database the stats live in memory for the session.
db.ready = false
D.record(6, { kills = 2 })
top = D.refreshBoard(true).rows
assert(top[1].name == "Ana Kill" and top[1].kills == 4 and top[2].name == "Fay Walker" and top[2].kills == 2, "memory leaderboard")
db.ready = true

-- ---------------------------------------------------------------------------
-- 7. Staff survey: capture points, ask the client's district, apply for the session
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
-- What the host counts (every table, key and value, 1024 at most) for this event, and for
-- the area definition the client hands op77_map3d (6 values a point).
local function values(v) if type(v) ~= "table" then return 1 end; local n = 1; for _, x in pairs(v) do n = n + 1 + values(x) end; return n end
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

print("PASS: Dogtown polygon (concave, hospital outside); PvP scopes inside/outside/tagged/stale/activity buckets/dead/foreign scope/switch; groups of 32; loot share/cap/threshold/pair cooldown/revenge/same account/crewmate/own bag; sealed bag; transfer; ledger kinds; stats db+memory+weeks; leaderboard; survey + map outline")
