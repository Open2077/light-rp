-- op77_ripperdoc's server transport (resources/standalone/op77_ripperdoc/server/main.lua): a
-- clinic payload past 900 values (or 40 KiB) goes as a latent event under the same name, a
-- small one as a plain event; a newer payload replaces a stream still in flight, and replacing
-- an "open" still in flight sends the newer payload as the "open". Run from op77_lightrp.
local exported, net, plain, latent, cancelled = {}, {}, {}, {}, {}
local inFlight = {}
_G.exports = function(name, fn) exported[name] = fn end
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.AddEventHandler = function() end
_G.RegisterCommand = function() end
local hostEvents = {}
_G.TriggerEvent = function(name, ...) hostEvents[#hostEvents + 1] = { name = name, args = table.pack(...) } end
local say = print
_G.print = function() end
_G.json = { encode = function(v)
    local function enc(x)
        if type(x) == "table" then
            local parts = {}
            for k, item in pairs(x) do parts[#parts + 1] = tostring(k) .. ":" .. enc(item) end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(x)
    end
    return enc(v)
end }
_G.TriggerClientEvent = function(name, pid, payload) plain[#plain + 1] = { name = name, pid = pid, payload = payload } return true end
local seq = 0
_G.TriggerLatentClientEvent = function(name, pid, rate, payload)
    seq = seq + 1
    local id = "s" .. seq
    latent[#latent + 1] = { name = name, pid = pid, rate = rate, payload = payload, id = id }
    inFlight[id] = true
    return id
end
_G.Open77 = {
    time = { monotonic = function() return 0 end },
    net = { cancelLatent = function(id) cancelled[#cancelled + 1] = id; local was = inFlight[id] == true; inFlight[id] = nil; return was end },
}

dofile("../../standalone/op77_ripperdoc/server/main.lua")
local T = RipperdocTransport
assert(T and T.LATENT_VALUES == 900, "transport exposed for tests")

-- A clinic-sized payload: 34 implants with their stats
local catalogue = {}
for i = 1, 34 do
    catalogue[i] = { id = "item" .. i, name = "Implant " .. i, section = "nervous", icon = "cw_x", rarity = "epic", tier = 4, price = 26000,
        family = "f" .. i, maker = "Maker", effect = "Does a thing.", lore = "Lore.", capacity = 4, repTier = 3, repName = "Operator", locked = false,
        stats = { { label = "A", value = "1" }, { label = "B", value = "2" }, { label = "C", value = "3" } } }
end
local big = { live = true, catalogue = catalogue, installed = {}, stock = {}, wallet = 1000, fittingFee = 50, capacity = { used = 4, total = 18, over = false } }
assert(T.countValues(big) > 900, "a full clinic payload is past the plain limit: " .. T.countValues(big))

-- open: latent, under the same name
assert(exported.open(7, big) == true)
assert(#latent == 1 and latent[1].name == "op77_ripperdoc:open" and latent[1].pid == 7 and #plain == 0, "open as a latent event")
-- an update while the open is still in flight: the open is cancelled, the update goes as the open
assert(exported.update(7, big) == true)
assert(cancelled[1] == "s1" and #latent == 2 and latent[2].name == "op77_ripperdoc:open", "a replaced open stays an open")
-- the open arrived; the next update is an update
inFlight.s2 = nil
assert(exported.update(7, big) == true)
assert(#latent == 3 and latent[3].name == "op77_ripperdoc:update", "an update after the open arrived")
-- a small payload and the result stay plain events
exported.update(7, { live = true, catalogue = {} })
assert(#plain == 1 and plain[1].name == "op77_ripperdoc:update", "small: plain")
exported.result(7, { ok = true, message = "done" })
assert(#plain == 2 and plain[2].name == "op77_ripperdoc:result")
-- close cancels a stream in flight
exported.update(7, big)
exported.close(7)
assert(cancelled[#cancelled] == latent[#latent].id and plain[#plain].name == "op77_ripperdoc:close", "close cancels the stream")
assert(exported.update(7, big) == nil, "closed: nothing sent")

-- the guide seen: relayed to the clinic's owner only for an open interface, only as seen = true
local function guideEvents()
    local n = 0
    for _, e in ipairs(hostEvents) do if e.name == "op77_ripperdoc:guide" then n = n + 1 end end
    return n
end
_G.source = 8
net["op77_ripperdoc:guide"]({ seen = true })
assert(guideEvents() == 0, "not open: nothing relayed")
exported.open(8, { live = true, catalogue = {} })
net["op77_ripperdoc:guide"]({ seen = false })
net["op77_ripperdoc:guide"]("seen")
assert(guideEvents() == 0, "only { seen = true }")
net["op77_ripperdoc:guide"]({ seen = true })
local last = hostEvents[#hostEvents]
assert(guideEvents() == 1 and last.args[1] == 8 and last.args[2].seen == true, "relayed to the host with the player id")

say("ripperdoc_transport_test: ok")
