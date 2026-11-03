-- LightRP.state (server/core/framework.lua) and the client host's event limits:
-- a plain net event over 1024 JSON values is dropped silently by the client, so a
-- state too large for one event goes one key per event, `character` first, and a
-- key still too large alone goes as a latent event. No game, no database.
dofile("shared/config.lua")
dofile("shared/events.lua")
local noop = function() end
local sent, latent, logs = {}, {}, {}
Open77 = { time = { monotonic = function() return 1 end } }
RegisterNetEvent, AddEventHandler, RegisterCommand = noop, noop, noop
GetCurrentResourceName = function() return "op77_lightrp" end
GetPlayers = function() return { 1 } end
TriggerClientEvent = function(name, id, payload) sent[#sent + 1] = { name = name, id = id, payload = payload }; return true end
TriggerLatentClientEvent = function(name, id, rate, payload) latent[#latent + 1] = { name = name, id = id, rate = rate, payload = payload }; return 7 end
print = function(line) logs[#logs + 1] = line end
-- the host's json global, enough for a byte count
json = { encode = function(value)
    local function enc(v)
        if type(v) == "table" then
            local parts = {}
            for k, item in pairs(v) do parts[#parts + 1] = '"' .. tostring(k) .. '":' .. enc(item) end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif type(v) == "string" then return '"' .. v .. '"' end
        return tostring(v)
    end
    return enc(value)
end }
dofile("server/core/framework.lua")
local E = LightRpEvents

local function check(cond, msg) if not cond then error(msg, 2) end end
local function keys(payload) local list = {}; for k in pairs(payload) do list[#list + 1] = k end; table.sort(list); return table.concat(list, ",") end
local function list(n, width)
    local out = {}
    for i = 1, n do out[i] = { id = i, label = string.rep("x", width or 4) } end
    return out
end

local size = { character = 10, activities = 10, online = 10 }
LightRP.stateProvider("character", function(id) return { playerId = id, status = "active", slots = list(size.character) } end)
LightRP.stateProvider("activities", function() return { list = list(size.activities) } end)
LightRP.stateProvider("online", function() return list(size.online) end)

-- small: one plain event, as before
LightRP.state(1)
check(#sent == 1 and #latent == 0, "a small state is one event")
check(sent[1].name == E.net.state and keys(sent[1].payload) == "activities,character,online", "every key in it")
check(#logs == 0, "nothing logged for a state that fits")

-- the 2026-11-03 case: the whole state over the limit, each key under it
sent, logs = {}, {}
size.activities, size.online = 120, 90 -- 120*5 + 90*5 values, each key alone < 900
LightRP.state(1)
check(#latent == 0, "no key needs the latent path")
check(#sent == 3, "one event per key, got " .. #sent)
check(keys(sent[1].payload) == "character", "character goes first")
check(sent[1].payload.character.status == "active", "the real character, not a default")
check(keys(sent[2].payload) == "activities" and keys(sent[3].payload) == "online", "then the others, sorted")
for _, event in ipairs(sent) do check(LightRP.stateFitsPlainEvent(event.payload), "every part fits a plain event") end
check(#logs == 1 and logs[1]:find("one per key", 1, true), "the split is logged once")
LightRP.state(1)
check(#logs == 1, "and only once")

-- a single key too large alone: latent, the others stay plain
sent, latent, logs = {}, {}, {}
size.activities = 400
LightRP.state(1)
check(#latent == 1 and keys(latent[1].payload) == "activities", "the oversized key goes latent")
check(latent[1].name == E.net.state and latent[1].rate > 0, "under the same event name")
check(#sent == 2 and keys(sent[1].payload) == "character" and keys(sent[2].payload) == "online", "the rest stay plain, character first")
check(logs[1] and logs[1]:find("latent", 1, true), "the latent key is logged")

-- a partial push of one small key never splits
sent, latent = {}, {}
LightRP.state(1, "character")
check(#sent == 1 and keys(sent[1].payload) == "character" and #latent == 0, "a character push is one plain event")

-- bytes count too: few values but long strings
sent, latent = {}, {}
size.activities, size.online = 60, 10
LightRP.stateProvider("activities", function() return { list = list(size.activities, 900) } end) -- ~55 KB
LightRP.state(1)
check(#latent == 1 and keys(latent[1].payload) == "activities", "a key over the byte budget goes latent")

-- no latent transport: logged, nothing thrown
TriggerLatentClientEvent = nil
sent, logs = {}, {}
LightRP.state(1)
check(#sent == 2, "the keys that fit are still sent")
local found = false
for _, line in ipairs(logs) do if line:find("no latent transport", 1, true) then found = true end end
check(found, "a key that cannot be sent is logged")

print = _G.print
io.write("state_transport_test: ok\n")
