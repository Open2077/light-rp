-- pose_ghost.lua: a held pose is non-solid to other players; walkable gestures stay solid; someone
-- else's ghost is never cleared; the flag goes when the pose ends, at a death and is forgotten at a drop.
local handlers, ghost, calls, logs = {}, {}, {}, {}
function AddEventHandler(name, fn) handlers[name] = fn end
json = { decode = function(s) return load("return " .. s)() end }
LightRP = {
    module = function(_, def) PoseGhostModule = def; return def end,
    log = function(fmt, ...) logs[#logs + 1] = fmt:format(...) end,
}
Open77 = { players = {
    isGhosted = function(id) return ghost[id] == true end,
    setGhosted = function(id, on, options)
        calls[#calls + 1] = { id = id, on = on, autoClear = options and options.autoClear }
        ghost[id] = on
        return true
    end,
} }
dofile("server/modules/pose_ghost.lua"); local M = PoseGhostModule
local changed = handlers.onPlayerAnimationChanged
assert(type(changed) == "function", "listens to onPlayerAnimationChanged")

local function pose(profile, active) return { active = active, playbackId = "pb", steps = { { profile = profile } } } end

-- an emote / a seat: ghosted at once, autoClear off; ended: solid again
changed("1", pose("sit_chair", true))
assert(ghost[1] == true and calls[1].autoClear == false, "a held pose is ghosted, without auto clear")
changed("1", pose("sit_chair", true))
assert(#calls == 1, "a pose already held does not ghost twice")
changed("1", pose("sit_chair", false))
assert(ghost[1] == false and #calls == 2, "the end of the pose clears the flag")

-- walkable gestures (layer profiles) stay solid
for _, p in ipairs({ "carry", "wave", "point", "smoke_walk", "handsback_walk", "carry_box" }) do
    changed("2", pose(p, true))
    assert(not ghost[2], "walkable gesture stays solid: " .. p)
end

-- someone else's ghost (spawn protection): left alone, never cleared by us
ghost[3] = true
changed("3", pose("lean_wall", true))
changed("3", pose("lean_wall", false))
assert(ghost[3] == true, "another owner's ghost is not cleared")

-- the JSON string form of the event (the platform sends a string)
changed("4", '{ active = true, playbackId = "x", steps = { { profile = "dance" } } }')
assert(ghost[4] == true, "the string payload is decoded")
-- a death ends it
M.onLifeState(4, "dead")
assert(ghost[4] == false, "death clears our ghost")
-- a drop forgets it (nothing to clear on a player who left)
changed("5", pose("sit_chair", true))
M.onDisconnected(5)
local n = #calls
changed("5", pose("sit_chair", false))
assert(#calls == n, "a dropped player is forgotten")
print("pose_ghost_test: ok")
