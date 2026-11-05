-- The one /admin (owner, 2026-11-05): op77_lightrp answers /admin and /lightrp.admin with the staff
-- desk; the overview carries the operator's runnable commands (ACL projection, one string); the
-- catalogue (vehicles, items, places, weather) travels as "a|b|c" rows under the net event's
-- 1024-value cap; /lightrp.repair fixes the vehicle the operator sits in or the nearest one.
local noop = function() end
dofile("shared/config.lua"); dofile("shared/items.lua"); dofile("shared/events.lua")
for _, f in ipairs({ "shared/armament.lua", "shared/board_games.lua", "shared/casino_blackjack.lua", "shared/casino_fortune.lua",
    "shared/casino_pool.lua", "shared/casino_slots.lua", "shared/consumables.lua", "shared/grenades.lua", "shared/medical.lua" }) do
    local ok, why = pcall(dofile, f)
    if not ok then print("(skipped " .. f .. ": " .. tostring(why):sub(1, 80) .. ")") end
end
local commands, opened, allowedPerms = {}, {}, {}
LightRP = {
    db = { ready = true, schema = noop, read = function() return true, {} end, run = function() return true end },
    module = function(n, t) LightRP[n] = t; return t end, log = noop,
    command = function(name, options, fn) commands[name] = { options = options, fn = fn } end,
    staff = { allowed = function(_, perm) return allowedPerms[perm] == true end },
    characters = { get = function() return { identifier = "op77:a", key = "default", status = "active" } end, displayName = function() return "Nico" end },
    jobs = { get = function() return { label = "None" } end, gang = function() return { label = "None" } end },
    support = {
        allowed = function(_, right) return right == "view" or right == "audit" end,
        identity = function() return { identifier = "op77:a", key = "default", status = "active" } end,
        open = function(player, scope) opened[#opened + 1] = { player, scope }; return true end,
        text = function(v) return v end,
    },
}
LightRpSupportConfig = { permissions = { view = "command.admin" } }
LightRpJobs, LightRpGangs = {}, {}
GetPlayers = function() return { 1 } end
GetPlayerName = function() return "Nightwolf" end
exports = function() end
local repaired, seat, closest = {}, nil, nil
Open77 = {
    players = { getLifeState = function() return { phase = "alive" } end },
    vehicles = {
        getPlayerSeat = function() return seat end,
        closest = function() return closest end,
        repair = function(id, scope) repaired[#repaired + 1] = { id, scope }; return id ~= 99 end,
    },
}
LightRP.fuel = { seed = function(id, how) repaired.fuel = { id, how } end }
dofile("server/modules/admin.lua")
local A = LightRP.admin

-- /admin and /lightrp.admin: restricted, open the staff desk
assert(commands.admin and commands["lightrp.admin"], "/admin and /lightrp.admin are registered")
assert(commands.admin.options.restricted == true, "/admin is restricted (command.admin)")
assert(commands.admin.fn(1) == nil and opened[1][2] == "staff", "/admin opens the staff desk, silently")
LightRP.support.open = function() return false, "Staff access denied." end
local ok, why = commands.admin.fn(1)
assert(ok == false and why == "Staff access denied.", "a refusal is reported")

-- the overview carries the runnable commands, projected through the ACL, as one string
allowedPerms["command.admin.self.noclip"] = true
allowedPerms["command.lightrp.giveitem"] = true
allowedPerms["command.worldboss.start"] = true
local overview = A.overview(1)
assert(type(overview.commands) == "string", "commands travel as one string")
local granted = {}
for name in overview.commands:gmatch("[^,]+") do granted[name] = true end
assert(granted["admin.self.noclip"] and granted["lightrp.giveitem"] and granted["worldboss.start"], "granted commands listed")
assert(not granted["admin.bulk.dvall"] and not granted["adminfull"], "ungranted commands hidden")

-- the catalogue: rows of strings, under the 1024-value cap of a plain net event
local catalog = A.handlers.adminCatalog(1)
local function values(v) if type(v) ~= "table" then return 1 end local n = 1; for _, x in pairs(v) do n = n + values(x) end return n end
assert(values(catalog) < 900, "catalogue fits a net event: " .. values(catalog) .. " values")
assert(#catalog.vehicles > 10 and #catalog.items > 20 and #catalog.places > 0 and #catalog.weather > 0, "catalogue filled")
for _, row in ipairs(catalog.vehicles) do assert(select(2, row:gsub("|", "")) == 3, "vehicle row key|label|category|record: " .. row) end
for _, row in ipairs(catalog.items) do assert(select(2, row:gsub("|", "")) == 2, "item row name|label|category: " .. row) end
local cats = {}
for _, row in ipairs(catalog.items) do cats[row:match("|([^|]*)$")] = true end
assert(not catalog.items[1]:find("^cash|"), "cash is not offered")
print(("catalogue: %d vehicles, %d items, %d places, %d values"):format(#catalog.vehicles, #catalog.items, #catalog.places, values(catalog)))
LightRP.support.allowed = function() return false end
assert(A.handlers.adminCatalog(1) == nil, "the catalogue needs the staff view")

-- /lightrp.repair: the seat, else the nearest, else an id; refuels too
local repair = commands["lightrp.repair"].fn
seat = { vehicleId = 41 }
ok = repair(1, {})
assert(ok == true and repaired[1][1] == 41 and repaired[1][2] == "full" and repaired.fuel[1] == 41, "repairs the vehicle sat in")
seat, closest = nil, { id = 52 }
assert(repair(1, {}) == true and repaired[2][1] == 52, "else the nearest one")
closest = nil
ok, why = repair(1, {})
assert(ok == false and why:find("No vehicle"), "nothing around: refused")
assert(repair(1, { "99" }) == false, "a failed repair is reported")
print("admin_menu_test: ok")
