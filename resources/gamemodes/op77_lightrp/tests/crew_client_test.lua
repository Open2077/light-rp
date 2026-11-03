-- Crews, client side (client/core/crew.lua): the ALT + click predicates and
-- requests, the invite keys, the effective key names added to the state.
dofile("shared/config.lua")
dofile("shared/events.lua")
local exported, handlers, mappings, sent, pageSent, logs = {}, {}, {}, {}, {}, {}
local invoking = "open77_contextmenu"
local registered
exports = function(name, fn) exported[name] = fn end
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
AddEventHandler = function(name, fn) handlers[name] = fn end
TriggerServerEvent = function(name, payload) sent[#sent + 1] = { name = name, payload = payload }; return true end
RegisterKeyMapping = function(id, name, key, fn) mappings[id] = { key = key, fn = fn }; return true, key end
local bound = {}
Open77 = {
    input = { keyFor = function(id) return bound[id] end },
    exports = { call = function(resource, method, defs)
        assert(resource == "open77_contextmenu" and method == "registerMany")
        registered = defs
        return { await = function() return { "t1", "t2", "t3", "t4" } end }
    end },
}
LightRpUi = { characterReady = true, dialogs = {}, log = function(...) logs[#logs + 1] = string.format(...) end,
    send = function(name, payload) pageSent[#pageSent + 1] = { name = name, payload = payload } end }
dofile("client/core/crew.lua")
local Crew = LightRpCrew
handlers.onClientResourceStart("op77_lightrp")
assert(registered and #registered == 4, "four crew actions in one batch")
local byId = {}
for _, d in ipairs(registered) do byId[d.id] = d; assert(d.canInteract == "crewContextAvailable" and d.onSelect == "crewContextSelect" and d.types[1] == "player") end
assert(byId["crew.leave"].allowSelf and byId["crew.leave"].selfOnly and not byId["crew.invite"].allowSelf, "leave is on yourself only")
assert(mappings["lightrp.crew.accept"].key == "Y" and mappings["lightrp.crew.decline"].key == "N")

local function ctx(what, playerId, self)
    return { kind = self and "self" or "target", target = { kind = "player", playerId = playerId, isLocalPlayer = self == true }, action = { data = { crew = what } } }
end
local available, select = exported.crewContextAvailable, exported.crewContextSelect

-- no crew yet: invite anyone else, nothing on yourself
Crew.sync({ you = 1, invites = {}, maxSize = 8, matchmaking = false })
assert(available(ctx("invite", 2)) and not available(ctx("invite", 1, true)), "invite another player, not yourself")
assert(not available(ctx("kick", 2)) and not available(ctx("lead", 2)) and not available(ctx("leave", 1, true)))
assert(select(ctx("invite", 2)) and sent[#sent].payload.type == "party.invite" and sent[#sent].payload.target == 2)
-- only open77_contextmenu calls the predicates
invoking = "someone_else"
assert(not available(ctx("invite", 2)) and not select(ctx("invite", 2)))
invoking = "open77_contextmenu"
-- a Light RP window open: quiet
LightRpUi.dialogs.shop = true
assert(not available(ctx("invite", 2)))
LightRpUi.dialogs.shop = false

-- leader of a crew of two with one invite out
Crew.sync({ you = 1, id = "crew:1", leader = 1, maxSize = 8, invites = {},
    members = { { id = 1, name = "Jack", leader = true, you = true }, { id = 2, name = "Kei" } }, pending = { { id = 3, name = "Rosa" } } })
assert(not available(ctx("invite", 2)), "already in the crew")
assert(not available(ctx("invite", 3)), "already invited")
assert(available(ctx("invite", 4)) and available(ctx("kick", 2)) and available(ctx("lead", 2)) and available(ctx("leave", 1, true)))
assert(not available(ctx("kick", 4)), "not in the crew")
assert(select(ctx("kick", 2)) and sent[#sent].payload.type == "party.kick" and sent[#sent].payload.target == 2)
assert(select(ctx("lead", 2)) and sent[#sent].payload.type == "party.promote")
assert(select(ctx("leave", 1, true)) and sent[#sent].payload.type == "party.leave" and sent[#sent].payload.target == nil)

-- a member: no invite, no kick, leave only
Crew.sync({ you = 2, id = "crew:1", leader = 1, maxSize = 8, invites = {},
    members = { { id = 1, name = "Jack", leader = true }, { id = 2, name = "Kei", you = true } }, pending = {} })
assert(not available(ctx("invite", 4)) and not available(ctx("kick", 1)) and not available(ctx("lead", 1)) and available(ctx("leave", 2, true)))

-- the invite keys answer the newest invite; the effective keys reach the page
bound["lightrp.crew.accept"] = "J"
local state = { you = 4, invites = { { party = "crew:1", from = 1, fromName = "Jack", expiresInMs = 50000 } }, maxSize = 8 }
Crew.sync(state)
assert(state.keys.accept == "J" and state.keys.decline == "N", "rebinds show on the prompt")
local before = #sent
mappings["lightrp.crew.accept"].fn()
assert(#sent == before + 1 and sent[#sent].payload.type == "party.accept" and sent[#sent].payload.party == "crew:1")
mappings["lightrp.crew.decline"].fn()
assert(sent[#sent].payload.type == "party.decline" and sent[#sent].payload.party == "crew:1")
bound["lightrp.crew.decline"] = "K"
handlers["open77:keybinds:changed"]()
assert(pageSent[#pageSent].payload.party.keys.decline == "K", "a rebind re-sends the keys")
-- the raid ready check keeps the shared key
bound["lightrp.crew.accept"] = nil
LightRpRaidClient = { state = { phase = "ready" } }
before = #sent
mappings["lightrp.crew.accept"].fn()
assert(#sent == before, "Y belongs to the raid's ready check while it runs")
LightRpRaidClient = nil
-- no invite: the keys do nothing
Crew.sync({ you = 4, invites = {}, maxSize = 8 })
before = #sent
mappings["lightrp.crew.accept"].fn(); mappings["lightrp.crew.decline"].fn()
assert(#sent == before)
print("PASS: crew client (four ALT + click actions, predicates per role, self only leave, invoker check, quiet under windows, requests, invite keys + rebinds, raid key precedence)")
