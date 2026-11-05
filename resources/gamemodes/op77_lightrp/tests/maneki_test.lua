-- The Maneki-neko collection (server/modules/maneki.lua) with the host stubbed and no
-- database (session mode): the staff tool places cats, the server streams only the
-- unfound cats near each player, E and shots are re-checked (distance, weapon, streamed),
-- a find pays once, milestones and the title, the desk lists and removes with an audit.
local threads = {}
local function tick(n)
    for _ = 1, n or 1 do
        for i = #threads, 1, -1 do
            local co = threads[i]
            if coroutine.status(co) == "dead" then table.remove(threads, i)
            else local ok, err = coroutine.resume(co); if not ok then error(err) end end
        end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end

local positions, weapons, now = {}, {}, 0
local sent, notices, bank, titles, states, chat = {}, {}, {}, {}, {}, {}
local handlers, commands, providers, actions, results = {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerName = function(id) return positions[id] and ("P" .. id) or nil end
_G.TriggerClientEvent = function(name, id, payload) sent[#sent + 1] = { name = name, id = id, payload = payload } end
_G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
_G.exports = function() end

_G.Open77 = {
    players = { position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = p.bucket or 0, heading = 0 } end },
    weapons = { get = function(id) return weapons[id] end },
    time = { unix = function() return 1793800000 + now end, monotonic = function() return now end },
}
local staff = { [1] = true }
_G.LightRpEvents = { net = { maneki = "op77_lightrp:maneki", manekiCollect = "op77_lightrp:maneki:collect", manekiEdit = "op77_lightrp:maneki:edit" } }
_G.LightRP = {
    log = function(fmt, ...) if os.getenv("MANEKI_TEST_LOG") then print(string.format(fmt, ...)) end end,
    module = function(name, def) LightRP[name] = def; return def end,
    command = function(name, _, fn) commands[name] = fn end,
    action = function(name, fn) actions[name] = fn end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    state = function(id, key) states[#states + 1] = { id = id, key = key } end,
    stateProvider = function(key, fn) providers[key] = fn end,
    nowMs = function() return now * 1000 end,
    db = { ready = false, schema = function() end },
    support = {
        allowed = function(id, right) return staff[id] == true end,
        identity = function(id) return positions[id] and { identifier = "acc" .. id, key = "default" } end,
        text = function(v, max, min) return type(v) == "string" and #v >= (min or 1) and #v <= (max or 500) and v or nil end,
    },
    characters = {
        get = function(id) return positions[id] and { status = "active", identifier = "acc" .. id, key = "default" } end,
        displayName = function(id) return "Player " .. id end,
    },
    money = { addBank = function(id, amount, kind) bank[id] = (bank[id] or 0) + amount; return true end },
    inventory = { playerId = function(id) return "inv" .. id end,
        addItems = function(invId, list) if invFull[invId] then return false, "inventory_full" end
            for _, it in ipairs(list) do given[#given + 1] = { inv = invId, name = it.name, count = it.count } end; return true end },
    titles = { award = function(id, title) titles[#titles + 1] = { id = id, title = title }; return true end,
        defs = { lucky_cat = { id = "lucky_cat", label = "Lucky Cat" } } },
    staff = { moveTo = function(id, position, heading, cb) positions[id] = { x = position.x, y = position.y, z = position.z }; cb(true) end },
    chat = { system = function(id, text) chat[#chat + 1] = text end },
    admin = { handlers = {} },
}
invFull, given = {}, {}
LightRpItems = { tcg_booster_wnc = { label = "TCG Booster · Night City" }, tcg_booster_beta = { label = "TCG Booster · Beta" } }
LightRpShops = { templates = { tcg_shop = { items = { { name = "tcg_booster_wnc", buy = 400 }, { name = "tcg_booster_beta", buy = 600 } } } } }
dofile("server/config/maneki.lua")
assert(LightRpManeki.reward.cash == 250 and LightRpManeki.milestones[4].cash == 20000, "shipped 2026-11-05 numbers")
for _, m in ipairs(LightRpManeki.milestones) do assert(type(m.items) == "table" and #m.items > 0, "every milestone gives TCG product") end
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
LightRpManeki.reward = { cash = 500 }
LightRpManeki.milestones = { { count = 10, cash = 5000 }, { count = 25, cash = 15000 }, { count = 50, cash = 40000 } }
dofile("server/modules/maneki.lua")
local M, C = LightRP.maneki, LightRpManeki
C.milestones = { { count = 2, cash = 5000, items = { { name = "tcg_booster_wnc", count = 2 }, { name = "nope_item", count = 1 } } } }
C.completeMin = 2

local function last(id, kind)
    for i = #sent, 1, -1 do local s = sent[i]; if s.id == id and s.name == "op77_lightrp:maneki" and s.payload.kind == kind then return s.payload end end
end
local function count(kind, id) local n = 0 for _, s in ipairs(sent) do if s.payload.kind == kind and (id == nil or s.id == id) then n = n + 1 end end return n end
local function ids(list) local t = {} for _, s in ipairs(list or {}) do t[#t + 1] = s.id end table.sort(t) return table.concat(t, ",") end
local function collect(id, spot, how) handlers["op77_lightrp:maneki:collect"](spot and { id = spot, how = how }); end
-- `source` is a global the host sets per net event
local function from(id, fn, ...) _G.source = id; return fn(...) end
local function advance(s) now = now + (s or 1) end

-- No database: the module goes session-only after its grace wait.
for _ = 1, 3 do tick() end
assert(LightRP.admin.handlers.maneki and LightRP.admin.handlers.manekiAction, "desk handlers registered")

positions[1] = { x = 0, y = 0, z = 0 }       -- staff
positions[2] = { x = 60, y = 0, z = 0 }      -- a player 50 m from the first cat
positions[3] = { x = 900, y = 0, z = 0 }     -- far away
positions[4] = { x = 70, y = 0, z = 0 }      -- a shooter

-- Placement tool: only staff, only near the staff member, never on top of another cat.
assert(M.setEditor(1, true) and last(1, "editor").active == true, "editor opens for staff")
assert(not M.setEditor(2, true), "a player cannot open the tool")
from(1, handlers["op77_lightrp:maneki:edit"], { op = "place", x = 10, y = 0, z = 0, yaw = 90, scale = 1, district = "Kabuki" })
assert(last(1, "staff").ok == true, "placed: " .. tostring(last(1, "staff").text))
from(1, handlers["op77_lightrp:maneki:edit"], { op = "place", x = 10.2, y = 0, z = 0, yaw = 0, scale = 1 })
assert(last(1, "staff").ok == false and last(1, "staff").text:find("already there"), "no second cat on the same spot")
from(1, handlers["op77_lightrp:maneki:edit"], { op = "place", x = 500, y = 0, z = 0, yaw = 0, scale = 1 })
assert(last(1, "staff").ok == false and last(1, "staff").text:find("Too far"), "too far from the staff member")
from(1, handlers["op77_lightrp:maneki:edit"], { op = "place", x = 20, y = 0, z = 0, yaw = 0, scale = 9 })
assert(last(1, "staff").ok == true, "a second cat (an unknown size falls back to 1)")
from(2, handlers["op77_lightrp:maneki:edit"], { op = "place", x = 60, y = 1, z = 0 })
assert(last(2, "staff").ok == false, "a player's placement request is refused")
local all = M.rows(1, {})
assert(#all == 2, "two cats")
local catA, catB
for _, r in ipairs(all) do if r.x == 10 then catA = r.id else catB = r.id end end
assert(M.spots()[catB].scale == 1, "unknown scale -> 1")

-- Streaming: only near, only unfound; the staff in the tool sees every cat.
tick()
assert(ids(last(2, "near").spots) == ids({ { id = catA }, { id = catB } }), "player 2 gets both cats")
assert(#last(3, "near").spots == 0, "player 3 is too far")
assert(last(1, "near").editing == true, "the staff list is the editor list")

-- E: too far is refused, close enough pays once.
collect(2, catA, "take")
from(2, handlers["op77_lightrp:maneki:collect"], { id = catA, how = "take" })
assert(count("found", 2) == 0, "take from 50 m refused")
positions[2] = { x = 11, y = 0, z = 0 }
advance()
from(2, handlers["op77_lightrp:maneki:collect"], { id = catA, how = "take" })
local found = last(2, "found")
assert(found and found.id == catA and found.found == 1 and found.total == 2 and found.cash == 500, "first find")
assert(bank[2] == 500, "paid 500")
advance()
from(2, handlers["op77_lightrp:maneki:collect"], { id = catA, how = "take" })
assert(count("found", 2) == 1 and bank[2] == 500, "a second take of the same cat pays nothing")
assert(ids(last(2, "near").spots) == catB, "the found cat is no longer streamed")
assert(providers.maneki(2).found == 1 and providers.maneki(2).total == 2, "state: 1 / 2")

-- A cat never streamed to this player cannot be taken by id.
positions[3] = { x = 20.5, y = 0, z = 0 }
from(3, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "take" })
assert(count("found", 3) == 0, "not streamed yet -> refused")

-- Shots: a weapon in hand, within range.
tick()
weapons[4] = { fresh = true, drawn = false }
from(4, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "shot" })
assert(count("found", 4) == 0, "no weapon in hand -> refused")
weapons[4] = { fresh = true, drawn = true }
positions[4] = { x = 200, y = 0, z = 0 }
advance()
from(4, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "shot" })
assert(count("found", 4) == 0, "shot from 180 m refused")
positions[4] = { x = 70, y = 0, z = 0 }
advance()
from(4, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "shot" })
assert(last(4, "found") and last(4, "found").how == "shot", "shot from 50 m with a weapon")

-- Player 2 completes the set: milestone + title (completeMin 2 in this test).
tick()
advance()
from(2, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "shot" })
weapons[2] = { fresh = true, drawn = true }
advance()
from(2, handlers["op77_lightrp:maneki:collect"], { id = catB, how = "shot" })
local done = last(2, "found")
assert(done.id == catB and done.found == 2 and done.complete == true and done.title == true and done.milestone == 5000, "set complete")
assert(bank[2] == 500 + 500 + 5000, "find + find + milestone: " .. tostring(bank[2]))
assert(#given == 1 and given[1].inv == "inv2" and given[1].name == "tcg_booster_wnc" and given[1].count == 2, "milestone boosters in the inventory (unknown items skipped)")
assert(done.milestoneItems and done.milestoneItems[1].label == "TCG Booster · Night City", "the find tells the page about the boosters")
assert(#titles == 1 and titles[1].title == "lucky_cat", "title awarded once")

-- The collection panel: one slot per cat, found ones with where/when/how, the others their district only.
actions["maneki.open"](4)
local col = last(4, "collection").collection
assert(col.total == 2 and col.found == 1 and #col.slots == 2, "player 4: 1 of 2")
assert(col.slots[1] == "|Kabuki" and col.slots[2]:match("^" .. catB .. "|"), "slot A not found: its district only (no id, no position); slot B found: " .. col.slots[1] .. " / " .. col.slots[2])
local parts = {}
for f in (col.slots[2] .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
assert(parts[4] == "shot" and tonumber(parts[3]) > 0 and tonumber(parts[5]) == 20, "how, when, where")
assert(col.intro == true and col.title.label == "Lucky Cat" and col.reward == 500, "first opening explains itself")
actions["maneki.intro"](4)
actions["maneki.open"](4)
assert(last(4, "collection").collection.intro == nil, "explained once")
actions["maneki.open"](2)
assert(last(2, "collection").collection.found == 2, "player 2 has both")
local stateKeys = 0
for _, st in ipairs(states) do if st.id == 3 and st.key == "maneki" then stateKeys = stateKeys + 1 end end
assert(stateKeys >= 1, "the F1 count is pushed once the finds are read")

-- The desk: list with find counts, then an audited removal.
local list = M.list(1, { sort = "near" })
assert(list.cats == 2 and list.canEdit and #list.spots == 2, "desk list")
for _, r in ipairs(list.spots) do if r.id == catB then assert(r.finds == 2, "cat B found twice") end end
assert(M.list(2, {}) == nil, "players cannot list")
local refused = M.action(1, { action = "manekiDelete", id = catA, confirmed = true, reason = "no", mutation = "desk:test:1" })
assert(refused == nil, "a reason is required")
local removed = M.action(1, { action = "manekiDelete", id = catA, confirmed = true, reason = "Bad spot, inside a wall", mutation = "desk:test:2" })
assert(removed and removed.accepted, "removed")
assert(#M.rows(1, {}) == 1 and providers.maneki(2).total == 1, "one cat left")
local tp = M.action(1, { action = "manekiTeleport", id = catB, confirmed = true, reason = "Checking it", mutation = "desk:test:3" })
assert(tp and tp.accepted and positions[1].x ~= 0, "teleported next to the cat")

-- Reset own collection (staff only), tool off.
assert(M.resetSelf(1), "staff reset")
assert(not M.resetSelf(2), "a player cannot reset")
from(1, handlers["op77_lightrp:maneki:edit"], { op = "close" })
assert(last(1, "editor").active == false, "editor closed")

-- The chat command lists.
local ok, text = commands["lightrp.maneki"](1, {})
assert(ok and text:find("Page 1/1"), "command lists")
-- The collection panel lists each milestone's TCG product (known items only).
actions["maneki.open"](2)
local ms = last(2, "collection").collection.milestones
assert(ms[1].items and #ms[1].items == 1 and ms[1].items[1].count == 2 and ms[1].items[1].label == "TCG Booster · Night City", "milestone items on the panel")
print("maneki_test: ok")
