-- Mission enemies (shared/mission_defs.lua): every entry well formed, ids unique, the new
-- families present (6th Street, Wraiths nomads, Voodoo Boys, cyberpsychos), the editor's mirror
-- (ui/src/features/missioneditor/model.ts) listing the same ids in the same order, and a
-- definition using a cyberpsycho as a world boss validating.
-- (shared/safezones.lua carries the geometry mission_defs.lua validates perimeters with)
local function readAll(path)
    local f = assert(io.open(path, "rb")); local s = f:read("a"); f:close(); return s
end
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
local D = LightRpMissionDefs

local seen, groups, psychos = {}, {}, 0
for i, e in ipairs(D.ENEMIES) do
    assert(type(e.id) == "string" and e.id:match("^[%w_]+$"), "enemy " .. i .. " id")
    assert(not seen[e.id], "duplicate enemy id " .. e.id)
    seen[e.id] = true
    assert(type(e.label) == "string" and #e.label > 0 and #e.label <= 48, e.id .. " label")
    assert((e.record ~= nil) ~= (e.template ~= nil), e.id .. ": a record or a template, not both")
    if e.record then assert(e.record:match("^Character%.[%w_]+$"), e.id .. " record " .. e.record) end
    assert(type(e.group) == "string" and #e.group > 0, e.id .. " group")
    groups[e.group] = (groups[e.group] or 0) + 1
    if e.psycho then psychos = psychos + 1; assert(e.group == "Cyberpsychos", e.id .. " psycho group") end
    assert(D.ENEMY[e.id] == e)
end
for _, g in ipairs({ "6th Street", "Nomads", "Voodoo Boys", "Cyberpsychos" }) do
    assert((groups[g] or 0) > 0, "no enemy in " .. g)
end
assert(psychos >= 2, "at least two different cyberpsychos")

-- the editor's mirror: same ids, same order
local ts = readAll("../../../ui/src/features/missioneditor/model.ts")
local block = ts:match("export const ENEMIES = %[(.-)%] as const;")
assert(block, "model.ts ENEMIES block")
local mirror = {}
for id in block:gmatch('id: "([%w_]+)"') do mirror[#mirror + 1] = id end
assert(#mirror == #D.ENEMIES, ("the editor lists %d enemies, the server %d"):format(#mirror, #D.ENEMIES))
for i, e in ipairs(D.ENEMIES) do assert(mirror[i] == e.id, "editor mirror out of order at " .. i .. ": " .. tostring(mirror[i])) end

-- a world boss whose boss is a cyberpsycho, guarded by the new factions, validates
local O = { x = 100, y = 100, z = 10 }
local psycho
for _, e in ipairs(D.ENEMIES) do if e.psycho then psycho = e.id break end end
local def = { title = "Psycho Sighting", description = "", location = "Kabuki", type = "eliminate", enabled = true,
    point = O, perimeter = { shape = "circle", center = O, radius = 40, minZ = 0, maxZ = 40 },
    starts = { { x = 100, y = 100, z = 10, heading = 0 } },
    spawns = {
        { id = "boss", label = "Psycho", position = { x = 105, y = 100, z = 10 }, enemy = psycho, count = 1, trigger = "start" },
        { id = "g1", position = { x = 110, y = 100, z = 10 }, enemy = "sixthstreet", count = 2, trigger = "start" },
        { id = "g2", position = { x = 110, y = 105, z = 10 }, enemy = "wraiths", count = 2, trigger = "start" },
        { id = "g3", position = { x = 110, y = 110, z = 10 }, enemy = "voodooboys", count = 2, trigger = "checkpoint" },
    },
    worldBoss = { enabled = true, boss = "boss", health = 20, reward = 20000, minShare = 5, minutes = 15 } }
local ok, why = D.validate(def)
assert(ok, tostring(why))
assert(ok.spawns[1].enemy == psycho and ok.spawns[3].enemy == "wraiths")
local bad = D.clone(def); bad.spawns[2].enemy = "aldecaldos"
assert(not D.validate(bad), "an unknown enemy is refused")

print(("PASS: mission enemies (%d entries, %d cyberpsychos, groups 6th Street/Nomads/Voodoo Boys/Cyberpsychos, editor mirror in sync, psycho world boss validates)"):format(#D.ENEMIES, psychos))
