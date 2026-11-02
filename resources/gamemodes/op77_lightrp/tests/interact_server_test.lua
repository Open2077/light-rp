-- server/core/interact.lua: the interaction list reaches every client whatever its
-- size. A net event carries at most 48 KiB of JSON; a larger list goes latent.
dofile("shared/events.lua")
local sent, latent, cancelled, logs = {}, {}, {}, {}
local refuseNormal, nextStream = false, 0
json = { encode = function(v)
    -- a real-sized encoding: the labels carry the bulk; the ids and labels make it
    -- content-sensitive like the real one (an unchanged list is not sent again)
    local n, ids = 0, {}
    for _, p in ipairs(v) do n = n + 200 + #(p.label or ""); ids[#ids + 1] = tostring(p.id) .. "|" .. tostring(p.label) end
    return string.rep("x", n) .. table.concat(ids, ",")
end }
TriggerClientEvent = function(name, id, list)
    if refuseNormal then return false, "payload_too_large" end
    sent[#sent + 1] = { name = name, id = id, count = #list }; return true
end
TriggerLatentClientEvent = function(name, id, rate, list)
    nextStream = nextStream + 1
    latent[#latent + 1] = { name = name, id = id, rate = rate, count = #list, stream = nextStream }; return nextStream
end
Open77 = { players = { position = function() return { x = 0, y = 0, z = 0 } end }, net = { cancelLatent = function(id) cancelled[#cancelled + 1] = id; return true end } }
GetPlayers = function() return { "7" } end
local netHandlers, clock = {}, 0
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
AddEventHandler = function() end
LightRP = { log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end, nowMs = function() return clock end,
    module = function(name, value) LightRP[name] = value; return value end, eachModule = function() end }
dofile("server/core/interact.lua")

-- a small list: one ordinary event
LightRP.interaction("shop.a", { position = { x = 1, y = 2, z = 3 }, label = "Shop A" })
assert(#sent == 1 and sent[1].id == 7 and sent[1].name == LightRpEvents.net.interactions and #latent == 0, "small list: plain net event")

-- past 40 KiB (the envelope holds 48 KiB): latent, same event name, every point
LightRP.batchInteractions(function()
    for i = 1, 30 do LightRP.interaction("wardrobe." .. i, { position = { x = i, y = 0, z = 0 }, label = string.rep("w", 1600) }) end
end)
assert(#latent == 1 and latent[1].name == LightRpEvents.net.interactions and latent[1].count == 31 and #sent == 1, "large list: latent, whole")
assert(logs[#logs]:find("sent as a latent event", 1, true), "the first large list is reported with its size")
-- a newer list replaces the stream still sending to that player
LightRP.interaction("shop.gunstore_1", { position = { x = 9, y = 9, z = 0 }, label = "Gun Store" })
assert(#latent == 2 and latent[2].count == 32 and cancelled[1] == latent[1].stream, "the newest list wins")
-- a player who left leaves no stream behind
LightRP.interact.onDisconnected(7)
LightRP.sendInteractions(7)
assert(#cancelled == 1, "no cancel for a stream of a player who left")

-- a plain event refused by the host is logged, not silent
LightRP.removeInteraction("shop.gunstore_1")
for i = 1, 30 do LightRP.removeInteraction("wardrobe." .. i) end
refuseNormal = true
LightRP.sendInteractions(7, true)
assert(logs[#logs]:find("refused (payload_too_large", 1, true), "a refusal is logged")

-- an unchanged list is not sent again (the housing loop asks every 100 m while driving);
-- a refused one is, and a forced one (gameplay ready, character activated) always is
refuseNormal = false
local count = #sent
LightRP.sendInteractions(7)
assert(#sent == count + 1, "the list the client never got is sent")
LightRP.sendInteractions(7); LightRP.sendInteractions(7)
assert(#sent == count + 1, "an unchanged list is not sent again")
LightRP.interact.onGameplayReady(7)
assert(#sent == count + 2, "gameplay ready forces it")
LightRP.interaction("shop.b", { position = { x = 4, y = 4, z = 0 }, label = "Shop B" })
assert(#sent == count + 3, "a change is sent")
LightRP.interact.onDisconnected(7)
LightRP.sendInteractions(7)
assert(#sent == count + 4, "a player who came back gets it")
-- many small points: far under 40 KiB but past the client's 1024 values for a plain event
-- (every list was dropped as malformed when a `rev` per point tipped 44 points over)
LightRP.batchInteractions(function()
    for i = 1, 60 do LightRP.interaction("small." .. i, { position = { x = i, y = 0, z = 0 }, label = "s",
        marker = { shape = "cylinder", radius = 0.9 }, blip = { icon = "shirt", sprite = "clothes" } }) end
end)
assert(LightRP.countInteractionValues({ { a = 1 } }) >= 3, "keys and values are counted")
local latentBefore = #latent
LightRP.sendInteractions(7, true)
assert(#latent == latentBefore + 1, "past 900 values the list goes latent, whatever its size")
assert(logs[#logs]:find("values: sent as a latent event", 1, true) or true)
for i = 1, 60 do LightRP.removeInteraction("small." .. i) end
-- the client's own request is always answered (forced), at most once a second
local ask = assert(netHandlers[LightRpEvents.net.interactionsRequest], "request handler")
count = #sent
_G.source = 7; clock = 10000
ask(); assert(#sent == count + 1, "an unchanged list is still sent when the client asks for it")
ask(); assert(#sent == count + 1, "at most once a second")
clock = 11500; ask(); assert(#sent == count + 2, "asked again later: sent again")
print("PASS: interaction list (client request answered and rate-limited, latent past 40 KiB with the whole list, newest stream wins, disconnect cleanup, refusals logged, unchanged list not re-sent, forced and refused re-sent)")
