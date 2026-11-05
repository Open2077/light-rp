-- op77_ripperdoc's client (resources/standalone/op77_ripperdoc/client/main.lua), mocked engine:
-- the clinic payload is encoded in a thread that yields (a single pass ran past the client's
-- script budget: "rd:open could not be encoded: budget exceeded", 2026-11-05), reaches the page
-- as JSON text, and a page that stays silent gets the open once more after 5 s before the game
-- gets its focus back. Run from op77_lightrp (tests/run-lua.ps1).
local threads, net, handlers, sent, logs, focus = {}, {}, {}, {}, {}, nil
local now, waits = 0, 0
CreateThread = function(fn) threads[#threads + 1] = { co = coroutine.create(fn), at = now } end
Wait = function(ms) waits = waits + 1; coroutine.yield(ms or 0) end
local function step(ms)
    now = now + (ms or 0)
    for _ = 1, 200 do
        local ran = false
        for _, th in ipairs(threads) do
            if coroutine.status(th.co) == "suspended" and th.at <= now then
                local ok, wait = coroutine.resume(th.co)
                assert(ok, wait)
                th.at = now + (tonumber(wait) or 0)
                ran = true
            end
        end
        if not ran then return end
    end
end
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function() end
RegisterCommand = function() end
GetCurrentResourceName = function() return "op77_ripperdoc" end
TriggerServerEvent = function(name, text) if name == "op77_ripperdoc:diag" then logs[#logs + 1] = text end return true end
Play2DSound = function() return 1 end
StopSound, DestroySound, SetSoundVolume, PlaySound = function() end, function() end, function() end, function() return true end
GetSoundState = function() return { status = "ready" } end
local page = {
    on = function(_, name, fn) handlers[name] = fn end,
    send = function(_, name, payload) sent[#sent + 1] = { name = name, payload = payload } end,
    show = function() end,
    setFocus = function(_, on) focus = on; return true end,
}
Open77 = { webui = { create = function() return page end } }
dofile("../../standalone/op77_ripperdoc/client/main.lua")
step(0)
handlers["ui:ready"]()

-- a clinic-sized payload: 140 implants with stats
local catalogue = {}
for i = 1, 140 do
    catalogue[i] = { id = "implant_" .. i, name = "Implant " .. i, section = "arms", price = i * 100, locked = i % 3 == 0,
        stats = { { label = "Armor", value = "+" .. i }, { label = "Cooldown", value = "-" .. i .. "%" } }, lore = string.rep("lore ", 6) }
end
local function opens() local n = 0; for _, s in ipairs(sent) do if s.name == "rd:open" then n = n + 1 end end return n end

-- 1. the encoding yields: many slices, the page gets the whole payload as JSON text
waits = 0
net["op77_ripperdoc:open"]({ live = true, catalogue = catalogue, installed = {}, stock = {}, body = "female" })
step(0)
assert(waits > 10, "the encoder yields across slices: " .. waits)
assert(opens() >= 1, "the open reached the page")
local first = sent[#sent].payload
assert(type(first.__json) == "string" or type(first.__part) == "table", "sent as JSON text")
assert(focus == true, "focus taken")

-- 2. the page answers: no second open, the menu stays
handlers["rd:sound"]({ name = "open" })
step(6000); step(6000)
assert(opens() == 1 and focus == true, "an answered open is not sent again")
handlers["rd:close"]({})
assert(focus == false, "closed by the patient")

-- 3. a silent page: sent again after 5 s, closed after the second silence
sent = {}
net["op77_ripperdoc:open"]({ live = true, catalogue = catalogue, body = "female" })
step(0)
assert(opens() == 1)
step(5000)
assert(opens() == 2 and focus == true, "sent again after 5 s, focus kept")
step(5000)
assert(focus == false, "closed after the second silence")
local said = table.concat(logs, "\n")
assert(said:find("sent again", 1, true) and said:find("after 2 tries", 1, true), said)
print("ripperdoc_client_test: ok")
