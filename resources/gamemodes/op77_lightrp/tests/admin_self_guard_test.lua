-- open77_admin (resources/system/open77_admin/server/main.lua): a missing target is refused, and kick/ban never act on whoever typed them (/ban alone banned the owner, 2026-11-06).
local cmds, outs = {}, {}
Open77AdminConfig = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return {} end }) end })
Open77AdminConfig.limits = { actionIntervalMs = 0, readIntervalMs = 0 }
Open77AdminConfig.aliases = { enabled = true, map = { ban = "admin.moderate.ban" } }
Open77AdminCatalog = { count = 0 }
Open77AdminConfig.locations = {}
Open77 = setmetatable({ time = { monotonic = function() return 1 end }, players = { name = function(id) return id == 3 and "Owner" or id == 5 and "Other" or nil end } },
  { __index = function() return setmetatable({}, { __index = function() return function() return nil end end }) end })
RegisterCommand = function(name, fn) cmds[name] = fn end
TriggerClientEvent = function(_, _, _, ok, text) outs[#outs + 1] = { ok = ok, text = text } end
AddEventHandler = function() end; RegisterNetEvent = function() end; CreateThread = function() end; SetTimeout = function() end
GetPlayers = function() return {} end; GetPlayerName = function(id) return Open77.players.name(id) end
exports = setmetatable({}, { __call = function() end })
local ok, err = pcall(dofile, "../../system/open77_admin/server/main.lua")
assert(ok, err)
assert(Admin and Admin.register and Admin.resolveTarget, "Admin exported")
assert(Admin.resolveTarget(3, nil) == nil, "a missing target is refused")
assert(Admin.resolveTarget(3, "me") == 3, "me, said out loud, still works")
local banned = {}
local spec = { mutation = true, handler = function(source, args) banned[#banned + 1] = args[1]; return true end }
Admin.register("admin.moderate.ban", spec)
outs = {}
spec.handler(3, { "me", n = 1 }, "ban me")
assert(#banned == 0 and outs[#outs] and outs[#outs].ok == false and outs[#outs].text:find("yourself"), "ban me refused")
spec.handler(3, { "3", n = 1 }, "ban 3")
assert(#banned == 0, "ban <own id> refused")
spec.handler(3, { "5", n = 1 }, "ban 5")
assert(banned[1] == "5", "another player still banned")
spec.handler(0, { "5", n = 1 }, "ban 5")
assert(banned[2] == "5", "the console still bans")
print("PASS admin self-protection")
