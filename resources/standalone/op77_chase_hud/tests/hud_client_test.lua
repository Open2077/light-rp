-- op77_chase_hud client: the surface is created (retrying while the resource prepares),
-- nothing is pushed before the page says ready, then every server payload is forwarded.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test hud_client_test.lua
local net, handlers, sent, created = {}, {}, {}, 0
local pageHandlers = {}
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.CreateThread = function(fn) fn() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_chase_hud" end
_G.WebUI = {
    create = function(options)
        created = created + 1
        assert(options.layer == "hud" and options.transparent == true and options.entry == "web/index.html")
        if created < 3 then return nil, "resource_preparing" end
        return {
            send = function(_, name, payload) sent[#sent + 1] = { name = name, payload = payload } end,
            on = function(_, name, fn) pageHandlers[name] = fn end,
        }
    end,
}

dofile("client/main.lua")
assert(net["op77_chase:hud"] and net["op77_chase:queue"], "listens to the server")
handlers.onClientResourceStart("someone_else")
assert(created == 0)
net["op77_chase:queue"]({ queued = true, position = 1, total = 1, mode = "vehicle" })
handlers.onClientResourceStart("op77_chase_hud")
assert(created == 3, "retried while the resource was preparing")
assert(#sent == 0, "nothing before the page is ready")
pageHandlers["chase:ready"]()
assert(#sent == 1 and sent[1].name == "chase:hud" and sent[1].payload.queue.queued == true and sent[1].payload.chase.state == "idle")
net["op77_chase:hud"]({ state = "active", role = "cop", remainingMs = 1000 })
assert(#sent == 2 and sent[2].payload.chase.role == "cop" and sent[2].payload.queue.queued == true)
net["op77_chase:hud"]("garbage")
assert(#sent == 2, "non-table payloads are ignored")
handlers.onClientResourceStop("op77_chase_hud")
net["op77_chase:hud"]({ state = "idle" })
assert(#sent == 2, "nothing after stop")
print("PASS: op77_chase_hud client (surface retry, ready gate, forwarding, stop)")
