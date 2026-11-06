-- The temporary kit of an activity (server/modules/activity_kits.lua), on the mission's own
-- code (LightRP.kits in missions.lua) and the real armament: who may ask, the delivery and its
-- retries, the wheel, standing aside, and every exit, with a fake client holding native slots.
-- Nothing of the character may be touched: the inventory and its writes are watched throughout.
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/armament.lua")
dofile("server/config/activities.lua")
dofile("server/config/missions.lua")

-- ---------------------------------------------------------------- the host --

local clock = 1000
local threads, timers = {}, {}
_G.CreateThread = function(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = clock } end
_G.Wait = function(ms) coroutine.yield(ms or 0) end
_G.SetTimeout = function(ms, fn) timers[#timers + 1] = { at = clock + (ms or 0), fn = fn } end
local function pump()
    local moved = true
    while moved do
        moved = false
        for i = #timers, 1, -1 do
            local timer = timers[i]
            if timer and timer.at <= clock then
                table.remove(timers, i)
                CreateThread(timer.fn)
                moved = true
            end
        end
        local list = threads
        threads = {}
        for _, t in ipairs(list) do
            if t.at <= clock then
                local ok, delay = coroutine.resume(t.co)
                if not ok then error(debug.traceback(t.co, tostring(delay))) end
                if coroutine.status(t.co) ~= "dead" then
                    t.at = clock + math.max(1, delay or 0)
                    threads[#threads + 1] = t
                end
                moved = true
            else threads[#threads + 1] = t end
        end
    end
end
local function advance(ms)
    local target = clock + ms
    pump()
    while clock < target do
        clock = math.min(target, clock + 25)
        pump()
    end
end

local handlers, exported = {}, {}
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function() end
_G.TriggerClientEvent = function() end
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local reports, dropped = {}, {}
_G.TriggerEvent = function(name, ...)
    if name == "op77_lightrp:activity:kit" then
        local id, activity, report = ...
        reports[#reports + 1] = { id = id, activity = activity, report = report }
    elseif name == "op77_lightrp:activity:dropped" then
        dropped[#dropped + 1] = { ... }
    end
end
_G.exports = function(name, fn) exported[name] = fn end
local invoking
_G.GetInvokingResource = function() return invoking end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
local resources = { op77_games = "running", op77_race = "running" }
_G.GetResourceState = function(name) return resources[name] or "missing" end
_G.GetPlayers = function() return {} end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.SetPlayerRoutingBucket = function() return true end

-- ---------------------------------------------------------------- the client --

local life, slots, ops, refuse, answers = {}, {}, {}, {}, 0
local slowRespawnMs -- the platform answers a respawn before the body stands: this long before
local seq = 0
local function rowsOf(id)
    local rows = {}
    for slot = 1, 6 do
        local row = slots[id] and slots[id][slot]
        rows[#rows + 1] = row and { slot = slot, record = row.record, tweakDbId = "0xabc" .. slot, equipped = true,
            ammo = { capacity = row.capacity, magazine = row.magazine, reserve = row.reserve, total = row.magazine + row.reserve } }
            or { slot = slot, equipped = false, tweakDbId = "" }
    end
    return { slots = rows }
end
local function request(method, id, apply, ...)
    seq = seq + 1
    local request_ = seq
    ops[#ops + 1] = { method = method, id = id, args = table.pack(...) }
    local operation = method == "requestSnapshot" and "snapshot" or method
    CreateThread(function()
        Wait(25)
        if refuse.silent and refuse.silent[method] then return end
        local why = refuse[method]
        if type(why) == "function" then why = why(id) end
        if why then fire("open77:weapons:completed", id, request_, operation, false, why, nil)
        else fire("open77:weapons:completed", id, request_, operation, true, nil, apply and apply() or {}) end
        answers = answers + 1
    end)
    return request_
end
local function slotsFor(id) slots[id] = slots[id] or {}; return slots[id] end
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end, unix = function() return 1800000000 end },
    players = {
        position = function() return { x = 1, y = 2, z = 3, bucket = 0 } end,
        get = function() return { position = { x = 1, y = 2, z = 3 }, heading = 0, bucket = 0 } end,
        getLifeState = function(id) if life[id] == "gone" then return nil end return { phase = life[id] or "alive" } end,
        teleport = function() return { await = function() return true end } end,
        respawn = function(id)
            if not slowRespawnMs then life[id] = "alive"; return true end
            life[id] = "respawnpending"
            LightRP.eachModule("onLifeState", id, "respawnpending")
            SetTimeout(slowRespawnMs, function()
                if life[id] ~= "respawnpending" then return end
                life[id] = "alive"
                LightRP.eachModule("onLifeState", id, "alive")
            end)
            return true
        end,
        heal = function() return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    weapons = {
        clear = function(id) return request("clear", id, function() slots[id] = {}; return { cleared = true, slots = {} } end) end,
        remove = function(id, slot) return request("remove", id, function() slotsFor(id)[slot] = nil end) end,
        assign = function(id, record, slot, options)
            return request("assign", id, function()
                slotsFor(id)[slot] = { record = record, capacity = 30, magazine = 0, reserve = 0 }
                return { tweakDbId = "0xabc" .. slot }
            end, record, slot, options)
        end,
        setAmmo = function(id, slot, amounts)
            return request("setAmmo", id, function()
                local row = slotsFor(id)[slot]
                if row then row.reserve = amounts.reserve or row.reserve; row.magazine = amounts.magazine or row.magazine end
            end, slot, amounts)
        end,
        setActive = function(id, slot) return request("setActive", id, nil, slot) end,
        holster = function(id) return request("holster", id) end,
        setDualWieldAllowed = function(id, on) return request("setDualWieldAllowed", id, nil, on) end,
        requestSnapshot = function(id) return request("requestSnapshot", id, function() return rowsOf(id) end) end,
    },
}
local function opsOf(id, method, from)
    local n = 0
    for index = (from or 0) + 1, #ops do
        if ops[index].id == id and ops[index].method == method then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------- Light RP --

local writes = 0
local notices = {}
local chars, invs = {}, {}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
local modules = {}
local noop = function() end
_G.LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    stateProvider = noop, action = noop, command = noop, state = noop, result = noop, log = noop, broadcastState = noop,
    interaction = noop, dialog = noop,
    notice = function(id, def) notices[#notices + 1] = { id = id, def = def } end,
    nowMs = function() return clock end,
    joinArgs = function(args) return table.concat(args, " ") end,
    characters = {
        switching = {},
        get = function(id) return chars[id] end,
        displayName = function(id) return "P" .. tostring(id) end,
        isRegistered = function(id) return chars[id] ~= nil end,
    },
    money = { format = function(n) return tostring(n) end },
    medical = { isDowned = function() return false end },
    tutorial = { isActive = function() return false end },
    housing = { sessions = {} },
}
LightRP.inventory = {
    player = function(id) return invs[id] end,
    transaction = function() writes = writes + 1; return true end,
    commitDrafts = function() writes = writes + 1; return true end,
    draft = function(inv) return inv end,
    close = noop, onUse = noop,
}
dofile("server/modules/armament_store.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/armament.lua")
dofile("server/modules/activities.lua")
dofile("server/modules/activity_kits.lua")
local A, W, K, Missions = LightRP.activities, LightRP.armament, LightRP.kits, LightRP.missions
local kitOne = LightRpRaid.loadouts[1]

local RP_RECORD = "Items.Preset_Liberty_Default"
for name, spec in pairs(LightRpArmament.weapons) do
    if spec.ammo == "pistol" then RP_RECORD = spec.record; LightRpArmament.testWeapon = name; break end
end
-- A character with an RP firearm on the hip, 40 rounds in the pockets.
local function character(id)
    local weapon = LightRpArmament.testWeapon
    chars[id] = { identifier = "acct-" .. id, key = "default", status = "active", firstName = "Runner" .. id }
    invs[id] = { id = "inv-" .. id, persistent = true, kind = "player", slots = 8, items = {
        [1] = { name = weapon, count = 1, metadata = { instanceId = "instance-" .. id } },
        [2] = { name = LightRpArmament.ammo.pistol.item, count = 40 },
    } }
    W.states[invs[id].id] = { revision = 3, ammo = 0, right = "instance-" .. id }
    LightRP.eachModule("onCharacterLoaded", id)
    W.enterWorld(id, "test")
    advance(400)
    assert(slots[id] and slots[id][1] and slots[id][1].record == RP_RECORD, "the RP firearm is projected")
    assert(W.runtime[id].projectedRecords and W.runtime[id].baseline, "with a baseline")
end
local function pockets(id)
    local n = 0
    for _, item in pairs(invs[id].items) do n = n + item.count end
    return n
end

local nextId = 100
local function player(activity)
    nextId = nextId + 1
    character(nextId)
    if activity then
        invoking = activity == "games.tdm" and "op77_games" or "op77_race"
        assert(exported.activityEnter(nextId, activity))
        advance(100)
    end
    return nextId
end

invoking = "op77_games"
assert(exported.activityRegister({ id = "games.tdm", resource = "op77_games", label = "TDM", kind = "pvp", caps = {} }))
assert(exported.activityRegister({ id = "games.other", resource = "op77_games", label = "Other", kind = "pvp", caps = {} }))
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.grid", resource = "op77_race", label = "Grid", kind = "race", caps = { rpWeapons = true } }))
invoking = "op77_games"

local function reportsOf(id)
    local list = {}
    for _, row in ipairs(reports) do if row.id == id then list[#list + 1] = row.report end end
    return list
end
local function lastReport(id) local list = reportsOf(id); return list[#list] end
local function handOut(id, kit, opts)
    local ok, hand = exported.activityKit(id, A.current(id).activity, kit, opts)
    assert(ok == true, tostring(hand))
    advance(4000)
    return hand
end
local function nativeKit(id)
    local found = {}
    for slot, row in pairs(slots[id] or {}) do
        if row.record ~= RP_RECORD then found[#found + 1] = slot end
    end
    return #found > 0
end
-- The way back ends with the kit gone, the armament no longer aside, the RP gun projected.
local function backToRP(id, what)
    assert(not nativeKit(id), what .. ": no kit weapon left in a slot")
    assert(not A.handlesLoadout(id), what .. ": the kit is over")
    assert(not W.standsAside(id), what .. ": the armament is back")
    assert(slots[id][1] and slots[id][1].record == RP_RECORD, what .. ": the RP firearm is back")
    assert(pockets(id) == 41, what .. ": every round and the gun in the pockets")
end
local baseWrites = writes

-- ---------------------------------------------------------------- who may ask --

do
    local tdm, stranger = player("games.tdm"), player()
    local base = #ops
    local ok, why = exported.activityKit(stranger, "games.tdm", "assault")
    assert(ok == false and why:find("not in this activity"), "a stranger is refused")
    ok, why = exported.activityKit(tdm, "games.other", "assault")
    assert(ok == false and why:find("not in this activity"), "another activity of the same resource")
    ok, why = exported.activityKit(tdm, "games.none", "assault")
    assert(ok == false and why:find("not available"), "an activity that does not exist")
    invoking = "op77_race"
    ok, why = exported.activityKit(tdm, "games.tdm", "assault")
    assert(ok == false and why:find("another resource"), "a foreign resource")
    invoking = "op77_games"
    ok, why = exported.activityKit(tdm, "games.tdm", "no-such-kit")
    assert(ok == false and why:find("does not exist"), "an unknown kit")
    for _, bad in ipairs({ 7, { primary = "not a record" }, {}, { primary = "Items.A", secondary = 3 },
        { primary = "Items.A", reserve = 30 }, { primary = "Items.A", reserve = { -1 } }, { primary = "Items.A", reserve = { 1.5 } },
        { primary = "Items.A", reserve = { 1e9 } } }) do
        ok = exported.activityKit(tdm, "games.tdm", bad)
        assert(ok == false, "a malformed kit")
    end
    ok, why = exported.activityKit("x", "games.tdm")
    assert(ok == false and why:find("Invalid"), "an invalid player")
    advance(100)
    assert(#ops == base, "a refusal sends nothing")
    assert(not A.handlesLoadout(tdm), "no kit")
    invoking = "op77_race"
    ok, why = exported.activityKitTake(tdm, "games.tdm")
    assert(ok == false and why:find("another resource"), "a foreign take")
    invoking = "op77_games"
    ok, why = exported.activityKitTake(tdm, "games.tdm")
    assert(ok == false and why:find("no kit"), "nothing to take")
    ok, why = exported.activityKitTake(stranger, "games.tdm")
    assert(ok == false and why:find("not in this activity"), "a stranger's take")

    -- stale: after the leave, nothing; an older hand cannot take a newer kit
    local old = handOut(tdm, "assault")
    local new = handOut(tdm, "breacher")
    ok, why = exported.activityKitTake(tdm, "games.tdm", { hand = old })
    assert(ok == false and why:find("replaced"), "a stale hand")
    assert(A.kitOf(tdm).id == "breacher", "the new kit stays")
    assert(old ~= new)
    assert(exported.activityLeave(tdm, "games.tdm"))
    ok, why = exported.activityKit(tdm, "games.tdm", "assault")
    assert(ok == false and why:find("not in this activity"), "a player who left")
    ok = exported.activityKitTake(tdm, "games.tdm")
    assert(ok == false, "a stale take")
    advance(8000)
    backToRP(tdm, "stale calls")
end

-- ---------------------------------------------------------------- the delivery --

do
    -- the mission's sequence, the default kit, the armament out of the way first
    local id = player("games.tdm")
    assert(W.runtime[id].projectedRecords, "projected before the kit")
    local from = #ops
    local ok, hand = exported.activityKit(id, "games.tdm")
    assert(ok == true and type(hand) == "number", "true, hand")
    assert(W.runtime[id].projectedRecords == nil and W.runtime[id].baseline == nil, "the projection is dropped: the return owes it nothing")
    advance(1000)
    assert(opsOf(id, "assign", from) == 0, "the body lands first, as a mission's")
    advance(3000)
    local seen = {}
    for index = from + 1, #ops do if ops[index].id == id then seen[#seen + 1] = ops[index].method end end
    assert(table.concat(seen, " ") == "clear assign assign setAmmo requestSnapshot setAmmo setAmmo requestSnapshot setAmmo setActive requestSnapshot",
        "the mission's sequence: " .. table.concat(seen, " "))
    assert(slots[id][1].record == kitOne.primary and slots[id][2].record == kitOne.secondary, "the first of the mission kits")
    assert(slots[id][1].reserve == kitOne.reserve[1] and slots[id][1].magazine == 30, "reserve and a full magazine")
    local list = reportsOf(id)
    assert(#list == 3, "two weapons verified, then in hand: " .. #list)
    assert(list[1].state == "assigned" and list[1].hand == hand and list[2].state == "assigned", "verified on the way")
    assert(list[3].state == "armed" and list[3].kit == "assault", "armed")
    assert(#list[3].weapons == 2 and list[3].weapons[1].slot == 1 and list[3].weapons[1].tweakDbId == "0xabc1", "with its ids")

    -- a client still loading: retried until the snapshot shows the kit
    local late = player("games.tdm")
    local refused = 0
    refuse.assign = function(who)
        if who ~= late then return nil end
        refused = refused + 1
        return refused <= 4 and "queue_full" or nil
    end
    assert(exported.activityKit(late, "games.tdm", "breacher"))
    advance(6000)
    assert(lastReport(late) == nil, "not yet")
    advance(6000)
    assert(lastReport(late).state == "armed" and slots[late][1].record == "Items.Preset_Carnage_Default", "retried until it lands")
    refuse.assign = nil

    -- it never lands: six tries, the provider is told once
    local never = player("games.tdm")
    refuse.assign = function(who) return who == never and "queue_full" or nil end
    local before = opsOf(never, "clear")
    assert(exported.activityKit(never, "games.tdm", "assault"))
    advance(40000)
    assert(opsOf(never, "clear") - before == 6, "six attempts")
    local fails = 0
    for _, report in ipairs(reportsOf(never)) do if report.state == "failed" then fails = fails + 1 end end
    assert(fails == 1, "told once")
    refuse.assign = nil

    -- a body that dies mid-delivery stops, silently: the respawn re-issues
    local down = player("games.tdm")
    refuse.assign = function(who) return who == down and "queue_full" or nil end
    assert(exported.activityKit(down, "games.tdm", "assault"))
    advance(2000)
    life[down] = "dead"
    LightRP.eachModule("onLifeState", down, "dead")
    local stopped = opsOf(down, "clear")
    refuse.assign = nil
    advance(9000)
    assert(opsOf(down, "clear") == stopped, "no attempt on a dead body")
    assert(lastReport(down) == nil or lastReport(down).state ~= "failed", "no failure to tell")
    life[down] = "alive"
    LightRP.eachModule("onLifeState", down, "alive")
    handOut(down, "assault")
    assert(lastReport(down).state == "armed", "the re-issue lands")

    -- an explicit kit of one melee weapon: no rounds to set, armed by its record alone
    local knife = player("games.tdm")
    local mark = #ops
    assert(exported.activityKit(knife, "games.tdm", { primary = "Items.Preset_Knife_Default", label = "Knife", names = { "Knife" } }, { immediate = true }))
    advance(1000)
    assert(lastReport(knife).state == "armed", "a knife needs no rounds, immediately")
    assert(opsOf(knife, "setAmmo", mark) == 0 and opsOf(knife, "assign", mark) == 1, "one assign, no ammunition")

    -- a new hand replaces the running one: nothing of the old lands after it
    local swap = player("games.tdm")
    local old = select(2, exported.activityKit(swap, "games.tdm", "assault", { immediate = true }))
    advance(60)
    local new = select(2, exported.activityKit(swap, "games.tdm", "breacher", { immediate = true }))
    advance(3000)
    assert(slots[swap][1].record == "Items.Preset_Carnage_Default", "the new kit in hand")
    local lastOld, firstNew
    for index, op in ipairs(ops) do
        if op.id == swap and op.method == "assign" then
            if op.args[1] == kitOne.primary or op.args[1] == kitOne.secondary then lastOld = index
            elseif not firstNew then firstNew = index end
        end
    end
    assert(not lastOld or lastOld < firstNew, "no assign of the old kit after the new one")
    for _, report in ipairs(reportsOf(swap)) do
        assert(report.state == "assigned" or report.hand == new, "the old hand reports no end")
    end
    assert(old ~= new)
end

-- ---------------------------------------------------------------- a slow respawn --

do
    -- As op77_games does: the kit again as soon as respawn() answers.
    local function fallen(activity, kit)
        local id = player(activity or "games.tdm")
        handOut(id, kit or "assault")
        life[id] = "dead"
        LightRP.eachModule("onLifeState", id, "dead")
        return id
    end
    local function respawned(id)
        assert(Open77.players.respawn(id, {}) == true)
        local ok, hand = exported.activityKit(id, "games.tdm", "assault")
        assert(ok == true, tostring(hand))
        return hand
    end
    local function statesOf(id, hand)
        local n = {}
        for _, row in ipairs(reportsOf(id)) do if row.hand == hand then n[row.state] = (n[row.state] or 0) + 1 end end
        return n
    end

    -- still respawnpending past the 1.5 s: the hand waits for its alive, then lands
    slowRespawnMs = 4000
    local id = fallen()
    local mark = #ops
    local hand = respawned(id)
    assert(life[id] == "respawnpending", "the fake is slow")
    advance(3500)
    assert(opsOf(id, "assign", mark) == 0, "nothing is asked of a body that does not stand")
    assert(next(statesOf(id, hand)) == nil, "no word yet")
    advance(1000)
    assert(life[id] == "alive", "it stood")
    advance(4000)
    assert(statesOf(id, hand).armed == 1, "the kit lands on the alive")
    assert(#lastReport(id).weapons == 2 and lastReport(id).hand == hand, "with verified ids: shots are accepted")
    assert(slots[id][1].record == kitOne.primary, "in the slots")

    -- it never stands: told once, bounded, nothing sent
    slowRespawnMs = 10000000
    id = fallen()
    mark = #ops
    hand = respawned(id)
    advance(30000)
    assert(next(statesOf(id, hand)) == nil, "still waiting")
    advance(4000)
    assert(statesOf(id, hand).failed == 1, "the provider hears it, and tells the player")
    assert(opsOf(id, "assign", mark) == 0, "never asked of a body that is not up")
    advance(60000)
    assert(statesOf(id, hand).failed == 1, "once")
    -- the wheel still has its way back once the body stands
    slowRespawnMs = nil
    life[id], slots[id] = "alive", {} -- a respawn leaves the hands empty
    assert(A.drawKit(id, 1))
    advance(4000)
    assert(statesOf(id, hand).armed == 1, "the wheel hands it out again")

    -- the event went missing: the wait's end reads the phase
    slowRespawnMs = 10000000
    id = fallen()
    hand = respawned(id)
    advance(5000)
    life[id] = "alive" -- no event
    advance(32000)
    assert(statesOf(id, hand).armed == 1, "delivered all the same")

    -- a new hand replaces the waiting one: the old one says nothing, ever
    id = fallen()
    local first = respawned(id)
    local second = respawned(id)
    advance(40000)
    assert(next(statesOf(id, first)) == nil, "the replaced hand is silent")
    assert(statesOf(id, second).failed == 1, "the new one speaks")

    -- gone while waiting: nothing to tell, nothing delivered
    id = fallen()
    hand = respawned(id)
    advance(3000)
    mark = #ops
    assert(exported.activityLeave(id, "games.tdm", { returnPlayer = false }))
    slowRespawnMs = nil
    life[id] = "alive"
    LightRP.eachModule("onLifeState", id, "alive")
    advance(40000)
    assert(next(statesOf(id, hand)) == nil, "no report for a player who left")
    assert(opsOf(id, "assign", mark) == 0 or not nativeKit(id), "no kit lands after the leave")
    assert(not A.handlesLoadout(id), "and the kit is over")

    -- down again and again on one hand: a bounded number of waits
    id = player("games.tdm")
    assert(exported.activityKit(id, "games.tdm", "assault", { immediate = true }))
    local cycles = 0
    for _ = 1, 6 do
        life[id] = "dead"
        advance(2000)
        life[id] = "alive"
        LightRP.eachModule("onLifeState", id, "alive")
        life[id] = "dead"
        advance(2000)
        cycles = cycles + 1
    end
    local fails = 0
    for _, row in ipairs(reportsOf(id)) do if row.state == "failed" then fails = fails + 1 end end
    assert(fails == 1, "told once, then the hand stops: " .. fails .. " after " .. cycles)
    life[id] = "alive"
end

-- ---------------------------------------------------------------- the wheel, standing aside --

do
    local id = player("games.tdm")
    assert(W.standsAside(id), "an activity with no RP weapons stands aside before any kit")
    local view = W.view(id)
    assert(view.arsenal[1].kit == nil, "no kit: the pockets")
    handOut(id, "assault")
    view = W.view(id)
    assert(view.standAside == true and #view.arsenal == 2, "the kit's two weapons")
    assert(view.arsenal[1].instanceId == "kit:1" and view.arsenal[1].label == kitOne.names[1] and view.arsenal[1].kit == true)
    assert(view.arsenal[2].instanceId == "kit:2" and view.arsenal[2].label == kitOne.names[2] and view.arsenal[1].kitScope == "match")

    -- drawn through the same path as a mission's kit
    local mark = #ops
    W.request(id, { request = "w1", operation = "select", instanceId = "kit:2" })
    advance(200)
    assert(opsOf(id, "setActive", mark) == 1, "the slot holds it: drawn")
    assert(opsOf(id, "assign", mark) == 0, "nothing reissued")

    -- the slot is empty: handed out again under the same hand
    local hand = lastReport(id).hand
    slots[id][2] = nil
    mark = #ops
    W.request(id, { request = "w2", operation = "select", instanceId = "kit:2" })
    advance(4000)
    assert(opsOf(id, "assign", mark) == 2 and slots[id][2].record == kitOne.secondary, "reissued")
    assert(lastReport(id).hand == hand and lastReport(id).state == "armed", "the same hand")

    -- a kit of one weapon lists one, and refuses the other slot
    local one = player("games.tdm")
    handOut(one, { primary = "Items.Preset_Nova_Default", reserve = { 24 }, label = "Nova" })
    view = W.view(one)
    assert(#view.arsenal == 1 and view.arsenal[1].label == "Nova", "one weapon, one row")
    local ok, why = A.drawKit(one, 2)
    assert(ok == false and why:find("Nothing"), "no second weapon")
    assert(A.drawKit(one, 3) == false, "a slot that does not exist")

    -- a mission's kit still wins the wheel and answers from Missions
    assert(Missions.kitOf(id) == nil and Missions.handlesLoadout(id) == false, "the mission side is untouched")

    -- an activity that keeps RP weapons: aside for the kit only, RP weapons back at the take
    invoking = "op77_race"
    local keeps = player("race.grid")
    assert(not W.standsAside(keeps), "its RP weapons are live")
    local mine = handOut(keeps, "assault")
    assert(W.standsAside(keeps), "the kit puts the armament aside")
    assert(W.view(keeps).standAside == true and W.view(keeps).arsenal[1].kit, "and the wheel lists it")
    assert(exported.activityKitTake(keeps, "race.grid", { hand = mine }))
    advance(8000)
    assert(not W.standsAside(keeps) and A.owner(keeps) == "race.grid", "still in the activity, the armament back")
    assert(slots[keeps][1].record == RP_RECORD, "its RP firearm projected again")
    assert(exported.activityLeave(keeps, "race.grid"))
    invoking = "op77_games"
    advance(500)
end

-- ---------------------------------------------------------------- every exit --

do
    -- Shots fired from the kit, for each: nothing of it comes from the pockets.
    local function armed()
        local id = player("games.tdm")
        handOut(id, "assault")
        slots[id][1].magazine = 3
        assert(nativeKit(id), "in the kit")
        return id
    end

    local id = armed()
    assert(exported.activityLeave(id, "games.tdm"))
    advance(9000)
    backToRP(id, "a leave")

    -- a forfeit is the provider's leave of each body, the kit taken first by its own call
    id = armed()
    assert(exported.activityKitTake(id, "games.tdm"))
    assert(exported.activityLeave(id, "games.tdm"))
    advance(9000)
    backToRP(id, "take then leave")

    -- no way back: kept in place
    id = armed()
    assert(exported.activityLeave(id, "games.tdm", { returnPlayer = false }))
    advance(9000)
    backToRP(id, "kept in place")

    -- death at the end: the body refuses the removal until it stands again
    id = armed()
    life[id] = "dead"
    LightRP.eachModule("onLifeState", id, "dead")
    local mark = #ops
    assert(exported.activityLeave(id, "games.tdm", { returnPlayer = false }))
    advance(10000)
    assert(opsOf(id, "clear", mark) == 0, "nothing is asked of a dead body")
    assert(A.handlesLoadout(id) and nativeKit(id), "the kit waits with it")
    life[id] = "alive"
    LightRP.eachModule("onLifeState", id, "alive")
    advance(9000)
    backToRP(id, "dead at the end")

    -- the way back respawns a dead body, then the kit goes
    id = armed()
    life[id] = "dead"
    assert(exported.activityLeave(id, "games.tdm"))
    advance(1000)
    life[id] = "alive"
    LightRP.eachModule("onLifeState", id, "alive")
    advance(9000)
    backToRP(id, "dead on the way back")

    -- a refused clear is asked again, bounded, and the armament's projection still replaces it
    id = armed()
    local refused = 0
    refuse.clear = function(who)
        if who ~= id then return nil end
        refused = refused + 1
        return refused <= 2 and "unequip_rejected" or nil
    end
    assert(exported.activityLeave(id, "games.tdm"))
    advance(16000)
    refuse.clear = nil
    assert(refused >= 3, "asked again")
    backToRP(id, "a refused removal")

    -- the client answers nothing: bounded, and the way back still ends
    id = armed()
    refuse.silent = { clear = true }
    assert(exported.activityLeave(id, "games.tdm"))
    advance(90000)
    refuse.silent = nil
    assert(not A.handlesLoadout(id), "bounded")

    -- the provider stops
    id = armed()
    fire("onResourceStop", "op77_games", "stop")
    advance(9000)
    backToRP(id, "the provider stops")
    invoking = "op77_games"
    resources.op77_games = "running"
    assert(exported.activityRegister({ id = "games.tdm", resource = "op77_games", label = "TDM", kind = "pvp", caps = {} }))

    -- a character change, in the activity
    id = armed()
    local old = chars[id]
    A.onCharacterSwitched(id, { identifier = "acct-x", key = "other", status = "active" })
    assert(A.current(id) == nil, "released")
    advance(9000)
    assert(not A.handlesLoadout(id) and not nativeKit(id), "a character change")

    -- a character change on the way back: that way back stops, the kit goes all the same
    id = armed()
    life[id] = "dying" -- the way back waits for a state it can act on
    assert(exported.activityLeave(id, "games.tdm"))
    advance(100)
    A.onCharacterSwitched(id, { identifier = "acct-x", key = "other", status = "active" })
    life[id] = "alive"
    advance(9000)
    assert(not A.handlesLoadout(id) and not nativeKit(id), "a character change on the way back")
    assert(old ~= nil)

    -- a disconnect: the slots go with the client, nothing is sent, nothing stays
    id = armed()
    local sentBefore = #ops
    A.onDisconnected(id)
    advance(5000)
    assert(not A.handlesLoadout(id), "a disconnect")
    assert(opsOf(id, "clear", sentBefore) == 0, "nobody to ask")

    -- a disconnect on the way back
    id = armed()
    life[id] = "dying"
    assert(exported.activityLeave(id, "games.tdm"))
    advance(100)
    A.onDisconnected(id)
    life[id] = "gone"
    advance(5000)
    assert(not A.handlesLoadout(id), "a disconnect on the way back")

    -- the core stops: the request goes out, no thread of ours would survive
    id = armed()
    local before = opsOf(id, "clear")
    fire("onResourceStop", "op77_lightrp", "restart")
    assert(opsOf(id, "clear") == before + 1, "the core's stop empties the slots at once")
    assert(not A.handlesLoadout(id), "and forgets the kit")
    advance(200)
    assert(not nativeKit(id), "gone")
end

-- ---------------------------------------------------------------- the character --

assert(writes == baseWrites, "not one inventory write in the whole file: " .. (writes - baseWrites))
assert(#notices == 0, "no RP notice about a kit: " .. tostring(notices[1] and notices[1].def.body))
assert(K.default() == kitOne, "the kit missions preselect is the first of the list")

print("PASS: activity kits (who may ask: stranger, foreign, stale, unknown kit; delivery, retries, failure, replace, melee; wheel view and draw, reissue, standsAside; every exit: leave, take, kept in place, dead at the end, refused removal, silent client, provider stop, character change, disconnect, core stop; inventory never written)")
