-- Starter studio: grant at the end of the first day, move-in, privacy of the
-- units, waking up at home, reuse of a released unit. Pure stubs, no SQL.
local now, uuid, writes = 1700000000, 0, {}
local positions, buckets, life, names, points, threads = {}, {}, {}, {}, {}, {}
json = { encode = function() return "{}" end, decode = function() return {} end }
function GetUnixTime() return now end
function GetPlayerName(id) return names[id] end
function GetPlayerIdentifier(id) return "license:" .. id end
function GetPlayers() local out = {} for id in pairs(names) do out[#out + 1] = id end return out end
function GetPlayersInBucket() return {} end
function GetPlayerRoutingBucket(id) return buckets[id] or 0 end
function SetPlayerRoutingBucket(id, b) buckets[id] = b end
function CreateThread(fn) threads[#threads + 1] = fn end
function Wait() end
function AddEventHandler() end
local function runThreads() local queue = threads; threads = {}; for i = 1, #queue do queue[i]() end end

local characters = {}
LightRP = {
    db = { ready = true, schema = function() end, single = function() return nil end,
        read = function(sql) if sql:find("UUID") then uuid = uuid + 1; return true, { { id = "lease-" .. uuid } } end return true, {} end,
        transaction = function(list) for _, w in ipairs(list) do writes[#writes + 1] = w end return true end },
    module = function(name, def) LightRP[name] = def; return def end,
    log = function() end, admin = { handlers = {} }, action = function() end, command = function() end,
    characters = { switching = {}, get = function(id) return characters[id] end, displayName = function(id) return "Player " .. id end },
    staff = { allowed = function() return false end },
    inventory = { close = function() end, refreshHousingAccess = function() end, get = function() end },
    notice = function() end, sendInteractions = function() end, dialog = function() end, result = function() end,
    batchInteractions = function(fn) fn() end,
    interaction = function(id, d) points[id] = d end, removeInteraction = function(id) points[id] = nil end,
}
Open77 = {
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        getLifeState = function(id) return life[id] and { phase = life[id] } end,
        teleport = function(id, p, o)
            return { await = function() positions[id] = { x = p.x, y = p.y, z = p.z }; buckets[id] = o.bucket; return true end }
        end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
}

dofile("server/config/housing.lua")
dofile("server/modules/housing_store.lua")
dofile("server/modules/housing.lua")
dofile("server/modules/housing_admin.lua")
dofile("server/modules/housing_starter.lua")
threads = {} -- the housing watchdog loop is not run here
local H, S, Starter, cfg = LightRP.housing, LightRP.housingStore, LightRP.housing.starter, LightRpHousing.starter

local function join(id)
    names[id], life[id], buckets[id] = "p" .. id, "alive", 620000
    positions[id] = { x = 6724, y = 2400, z = 400 }
    characters[id] = { identifier = "license:" .. id, key = "default", status = "active" }
end

H.onDatabaseReady(); Starter.onDatabaseReady()
local t = S.templates[cfg.templateId]
assert(t and S.templateReady(t) and t.data.points.wardrobe, "the starter template is written from the config")
assert(t.data.points.spawn.x == cfg.points.spawn.x and t.data.points.exit.z == cfg.points.exit.z)
t.data.points.stash.x = 1; Starter.onDatabaseReady()
assert(S.templates[cfg.templateId].data.points.stash.x == 1, "an existing template keeps the administrators' captures")

-- Move-in straight from the hall.
join(1)
assert(Starter.moveIn(1) == true)
local row = Starter.home(characters[1])
assert(row and row.data.starter and row.data.label == "Kabuki Studio 0001" and row.data.price == 0)
assert(S.contracts[row.contract_id].data.mode == "assigned" and S.contracts[row.contract_id].data.locked == true)
assert(H.sessions[1] and H.sessions[1].phase == "entering")
assert(H.sessions[1].exterior.x == cfg.entrance.x, "leaving the studio leads to the street door")
runThreads()
assert(H.sessions[1].phase == "inside" and buckets[1] == LightRpHousing.bucketBase + row.id)
assert(positions[1].z == cfg.points.spawn.z)
assert(characters[1].lastKnown.x == cfg.entrance.x, "the saved position is the street door, never the interior")
assert(Starter.grant(1).id == row.id, "one studio per character")
assert(points["housing.exit." .. row.id] and points["housing.stash." .. row.id] and points["housing.wardrobe." .. row.id])
assert(points["housing.door." .. row.id].label == cfg.building)

-- A second newcomer gets their own unit, and sees only theirs.
join(2)
local row2 = Starter.grant(2)
assert(row2 and row2.id ~= row.id and row2.data.entrance.x == row.data.entrance.x)
local view = H.snapshot(2, false, { view = "all" })
assert(#view.properties == 1 and view.properties[1].id == row2.id and view.properties[1].owned)
local doors = 0; for id in pairs(points) do if id:match("^housing%.door%.") then doors = doors + 1 end end
assert(doors == 1, "all units share one street door")

-- Logged out at home: wakes up inside.
H.onDisconnected(1)
assert(S.contracts[row.contract_id].data.asleep == true)
assert(H.sessions[1] == nil)
join(1)
local home = H.spawnPoint(1)
assert(home and home.home == row.id and home.bucket == LightRpHousing.bucketBase + row.id and home.position.z == cfg.points.spawn.z)
buckets[1] = home.bucket
H.arrived(1, home)
runThreads()
assert(H.sessions[1].phase == "inside" and not S.contracts[row.contract_id].data.asleep)
assert(H.spawnPoint(1) == nil, "the wake-up is used once")
-- Logged out outside: the usual rules.
H.sessions[1] = nil
H.onDisconnected(1)
assert(H.spawnPoint(1) == nil)

-- A released unit is reused before a new one is built.
names[2] = "p2"; positions[2] = { x = 0, y = 0, z = 0 }; buckets[2] = 0
assert(H.handle(2, { action = "release", id = row2.id, revision = S.properties[row2.id].revision }))
assert(Starter.home(characters[2]) == nil)
join(3)
assert(Starter.grant(3).id == row2.id)
local starters = 0; for _, r in pairs(S.properties) do if r.data.starter then starters = starters + 1 end end
assert(starters == 2)
print("PASS: starter template, move-in from the hall, one private unit each behind one door, wake up at home, reuse of released units")
