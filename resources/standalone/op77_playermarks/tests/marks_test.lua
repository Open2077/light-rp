-- op77_playermarks: the client script against a stubbed host (players around,
-- anchors, talkers, op77_map3d's hidden dots, the document's feed). The document itself
-- is tests/view_test.lua. Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test marks_test.lua
local sent, anchors, nextAnchor = {}, {}, 100
local nearby, entities, talkers, hiddenOnMap = {}, {}, {}, {}
local handlers = {}

_G.Open77 = {
    players = {
        nearby = function(radius, opts)
            assert(radius == 35.0 and opts.includeSelf == false and opts.limit == 24)
            return nearby
        end,
        entity = function(pid) return entities[pid] end,
    },
    anchors = {
        create = function(def)
            assert(def.entity and def.offset.z == 1.92 and def.maxDistance == 35.0)
            assert(def.page == nil and def.render == "dot" and def.visible == false, "projected only: no page, nothing drawn")
            nextAnchor = nextAnchor + 1
            anchors[nextAnchor] = { entity = def.entity, tag = def.tag }
            return nextAnchor
        end,
        update = function(id, def) if not anchors[id] then return false end; anchors[id].entity = def.entity; return true end,
        remove = function(id) anchors[id] = nil; return true end,
        clear = function() anchors = {} end,
    },
    voice = { talkers = function() return talkers end },
}
_G.GetResourceState = function(name) return name == "op77_map3d" and "running" or "missing" end
local exported = {}
_G.exports = setmetatable({ op77_map3d = { arePlayerDotsHidden = function(_, pid) return hiddenOnMap[tonumber(pid)] == true end } },
    { __call = function(_, name, fn) exported[name] = fn end })
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.CreateThread = function() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_playermarks" end

dofile("shared/config.lua")
dofile("client/view.lua")
dofile("client/main.lua")
local PM = PlayerMarks
PM.attach({ send = function(_, name, payload) sent[#sent + 1] = { name = name, payload = payload } end })

local function count(name)
    local n = 0
    for _, s in ipairs(sent) do if s.name == name then n = n + 1 end end
    return n
end
local function anchorCount() local n = 0; for _ in pairs(anchors) do n = n + 1 end; return n end

-- two players around (and yourself, never marked), one not streamed yet
nearby = {
    { playerId = 7, isLocal = false, name = "  Archer Hella ", position = { x = 1, y = 2, z = 3 } },
    { playerId = 8, isLocal = false, position = { x = 4, y = 5, z = 6 } },
    { playerId = 3, isLocal = true, position = { x = 0, y = 0, z = 0 } },
    { playerId = 9, isLocal = false, position = { x = 7, y = 8, z = 9 } },
}
entities = { [7] = "1001", [8] = "1002", [9] = "0" }
PM.refresh()
assert(PM.marks["7"] and PM.marks["8"] and not PM.marks["3"] and not PM.marks["9"], "the others with a body, never yourself")
assert(anchorCount() == 2 and count("pm:add") == 2)
assert(anchors[PM.marks["7"].anchor].tag == "playermark.7")
-- the plate's name: the session id in front, trimmed, a player without one shows its id
local adds = {}
for _, s in ipairs(sent) do if s.name == "pm:add" then adds[s.payload.player] = s.payload.name end end
assert(adds["7"] == "[7] Archer Hella" and adds["8"] == "[8]", tostring(adds["7"]) .. " / " .. tostring(adds["8"]))

-- a refresh with nothing new sends nothing
local before = #sent
PM.refresh()
assert(#sent == before, "steady: no page traffic")
-- a renamed player: only the name goes to the page
nearby[1].name = "Archer Hella (Mayor)"
PM.refresh()
assert(#sent == before + 1 and sent[#sent].name == "pm:name" and sent[#sent].payload.name == "[7] Archer Hella (Mayor)")
nearby[1].name = "A very long name that goes on and on"
PM.refresh()
assert(#sent[#sent].payload.name == 24 + #"[7] ", "the name cut to nameMax, the id in front")
before = #sent

-- talking: only changes reach the page; quiet capture noise still shows the waves
talkers = { { playerId = 7, talking = true, level = 0.6 }, { playerId = 8, talking = false, level = 0.3 } }
PM.talk()
local last = sent[#sent]
assert(last.name == "pm:talk" and last.payload.player == "7" and last.payload.talking == true and last.payload.level == 0.6)
assert(count("pm:talk") == 1, "player 8 is not talking: nothing to send")
PM.talk()
assert(count("pm:talk") == 1, "same level: nothing again")
talkers = { { playerId = 7, talking = true, level = 0.001 } }
PM.talk()
assert(sent[#sent].payload.talking == true and sent[#sent].payload.level == 0.0, "talking under the threshold still pulses")
talkers = {}
PM.talk()
assert(sent[#sent].payload.player == "7" and sent[#sent].payload.talking == false, "stopped talking")

-- a new body for a player (respawn): the anchor follows the new entity
entities[7] = "2001"
PM.refresh()
assert(anchors[PM.marks["7"].anchor].entity == "2001" and count("pm:add") == 2, "retargeted, not recreated")

-- a player op77_map3d hides (a chase runner) loses the dot; one who leaves too
hiddenOnMap[8] = true
nearby = { nearby[1], nearby[2] }
PM.refresh()
assert(PM.marks["7"] and not PM.marks["8"] and anchorCount() == 1 and count("pm:remove") == 1)
hiddenOnMap[8] = nil
nearby = {}
PM.refresh()
assert(next(PM.marks) == nil and anchorCount() == 0 and count("pm:remove") == 2, "nobody around: no dot")

-- a refused anchor is skipped (and said once), the others still get theirs
nearby = { { playerId = 7, isLocal = false }, { playerId = 8, isLocal = false } }
entities = { [7] = "1001", [8] = "1002" }
local create = Open77.anchors.create
Open77.anchors.create = function(def) if def.tag == "playermark.8" then return nil, "quota" end return create(def) end
PM.refresh()
assert(PM.marks["7"] and not PM.marks["8"])

-- setHidden (op77_lightrp in a PvP fight): some players, then everyone, per caller
Open77.anchors.create = create
_G.GetInvokingResource = function() return "op77_lightrp" end
nearby = { { playerId = 7, isLocal = false, name = "A" }, { playerId = 8, isLocal = false, name = "B" } }
entities = { [7] = "1001", [8] = "1002" }
PM.refresh()
assert(PM.marks["7"] and PM.marks["8"])
assert(exported.setHidden(true, { 8 }))
PM.refresh()
assert(PM.marks["7"] and not PM.marks["8"] and exported.arePlatesHidden(8) and not exported.arePlatesHidden(7), "one player hidden")
assert(exported.setHidden(true))
PM.refresh()
assert(next(PM.marks) == nil, "every plate hidden")
_G.GetInvokingResource = function() return "other" end
assert(exported.setHidden(false), "another caller's false does not lift op77_lightrp's hide")
PM.refresh()
assert(next(PM.marks) == nil)
_G.GetInvokingResource = function() return "op77_lightrp" end
assert(exported.setHidden(false))
PM.refresh()
assert(PM.marks["7"] and PM.marks["8"], "shown again")
assert(exported.setHidden(true, { 7 }))
handlers.onClientResourceStop("op77_lightrp")
PM.refresh()
assert(PM.marks["7"], "the caller stopped: its hide went with it")

-- setNames (op77_lightrp: the characters' names): the plate shows it, per caller
_G.GetResourceState = function() return "running" end
nearby = { { playerId = 7, isLocal = false, name = "AccountA" }, { playerId = 8, isLocal = false, name = "AccountB" } }
hiddenOnMap[7] = nil
PM.refresh()
assert(PM.marks["7"].name:find("AccountA"), "the account's name by default")
_G.GetInvokingResource = function() return "op77_lightrp" end
assert(exported.setNames({ [7] = "Jake Rob", ["8"] = "  ", [9] = 42 }))
PM.refresh()
assert(PM.marks["7"].name:find("Jake Rob") and not PM.marks["7"].name:find("AccountA"), "the character's name: " .. PM.marks["7"].name)
assert(PM.marks["8"].name:find("AccountB"), "a blank name keeps the account's")
assert(exported.setNames(nil))
PM.refresh()
assert(PM.marks["7"].name:find("AccountA"), "cleared: the account's again")
assert(exported.setNames({ [7] = "Jake Rob" }))
handlers.onClientResourceStop("op77_lightrp")
PM.refresh()
assert(PM.marks["7"].name:find("AccountA"), "the caller stopped: its names went with it")
_G.GetResourceState = function() return "missing" end

-- map3d not running: nobody is hidden
_G.GetResourceState = function() return "missing" end
hiddenOnMap[7] = true
PM.refresh()
assert(PM.marks["7"], "without op77_map3d the dot stays")

print("marks_test: ok")
