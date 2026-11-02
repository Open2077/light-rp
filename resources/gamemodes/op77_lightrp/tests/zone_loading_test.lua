-- server/modules/zone_loading.lua: the loading cover over zone changes is sent to
-- op77_loadscreen through its client events only (no hard dependency).
-- Run: pwsh -File tests/run-lua.ps1 -Test zone_loading_test.lua
local sent = {}
_G.LightRP = { module = function(name, def) LightRP[name] = def; return def end }
_G.TriggerClientEvent = function(name, player, payload) sent[#sent + 1] = { name = name, player = player, payload = payload } end
dofile("server/modules/zone_loading.lua")
local Z = LightRP.zoneLoading
local id = Z.cover(7, { title = "Kabuki Studio", subtitle = "Private residence", zone = "Residence",
    target = { x = "1", y = 2, z = 3 }, other = "dropped" })
assert(id == "lightrp:1" and sent[1].name == "op77_loadscreen:cover" and sent[1].player == 7)
local p = sent[1].payload
assert(p.id == id and p.title == "Kabuki Studio" and p.zone == "Residence" and p.other == nil)
assert(p.target.x == 1 and p.target.z == 3, "the target is plain numbers")
assert(Z.cover(8, { target = { x = 1 } }) == "lightrp:2" and sent[2].payload.target == nil, "a partial target is dropped")
assert(Z.cover(0, {}) == nil and Z.cover("7", {}) == nil and #sent == 2, "player ids are checked")
Z.release(7, id)
assert(sent[3].name == "op77_loadscreen:release" and sent[3].payload.id == id)
Z.release(7, nil)
assert(#sent == 3, "nothing to release without an id")
print("PASS: zone loading cover / release events")
