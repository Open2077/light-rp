-- op77_playermarks: the client script against a stubbed host (players around,
-- anchors, talkers, op77_map3d's hidden dots, the page). Run from the resource
-- folder with any Lua 5.4.
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
            assert(def.page and def.entity and def.offset.z == 2.12 and def.maxDistance == 35.0)
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
_G.exports = { op77_map3d = { arePlayerDotsHidden = function(_, pid) return hiddenOnMap[tonumber(pid)] == true end } }
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.CreateThread = function() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_playermarks" end

dofile("shared/config.lua")
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
    { playerId = 7, isLocal = false, position = { x = 1, y = 2, z = 3 } },
    { playerId = 8, isLocal = false, position = { x = 4, y = 5, z = 6 } },
    { playerId = 3, isLocal = true, position = { x = 0, y = 0, z = 0 } },
    { playerId = 9, isLocal = false, position = { x = 7, y = 8, z = 9 } },
}
entities = { [7] = "1001", [8] = "1002", [9] = "0" }
PM.refresh()
assert(PM.marks["7"] and PM.marks["8"] and not PM.marks["3"] and not PM.marks["9"], "the others with a body, never yourself")
assert(anchorCount() == 2 and count("pm:add") == 2)
assert(anchors[PM.marks["7"].anchor].tag == "playermark.7")

-- a refresh with nothing new sends nothing
local before = #sent
PM.refresh()
assert(#sent == before, "steady: no page traffic")

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

-- map3d not running: nobody is hidden
_G.GetResourceState = function() return "missing" end
hiddenOnMap[7] = true
PM.refresh()
assert(PM.marks["7"], "without op77_map3d the dot stays")

print("marks_test: ok")
