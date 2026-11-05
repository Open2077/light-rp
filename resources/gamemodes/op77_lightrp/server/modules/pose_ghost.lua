-- Held poses are untouchable (owner, 2026-11-05: "le personnage se fait bouger pendant des anim").
--
-- A player in a held animation (an emote, a seat, the ripperdoc chair, a card table: every workspot
-- profile) is made non-solid to other players with the platform's ghost flag
-- (Open77.players.setGhosted, autoClear off): nobody can walk into the body and push it out of the
-- pose, and the posed player does not shove anyone either. The flag goes when the pose ends.
--
-- Not for the walkable gestures (the `layer` profiles: carry, wave, point, smoke_walk, handsback_walk):
-- the player keeps walking through the crowd with them, so they stay solid.
-- A player already ghosted by someone else (spawn protection, a gamemode) is left alone: this module
-- only clears the flag it set itself.
local PoseGhost = LightRP.module("poseGhost", {})

local LAYER = { carry = true, wave = true, point = true, smoke_walk = true, handsback_walk = true }
local ours = {} -- playerId -> true while this module holds the ghost flag

local function walkable(state)
    local steps = type(state.steps) == "table" and state.steps or {}
    local first = steps[1]
    local profile = type(first) == "table" and first.profile or state.profile
    if type(profile) ~= "string" then return false end
    return LAYER[profile] == true or profile:find("_walk$") ~= nil or profile:find("^carry") ~= nil
end

local function release(playerId)
    if not ours[playerId] then return end
    ours[playerId] = nil
    local ok, done, why = pcall(Open77.players.setGhosted, playerId, false)
    if not ok or done == false then LightRP.log("pose ghost: release of %d refused: %s", playerId, tostring(ok and why or done)) end
end

function PoseGhost.apply(playerId, state)
    if type(state) ~= "table" then return end
    if state.active == true and not walkable(state) then
        if ours[playerId] then return end
        local okRead, already = pcall(Open77.players.isGhosted, playerId)
        if okRead and already then return end -- someone else's ghost: not ours to manage
        local ok, done, why = pcall(Open77.players.setGhosted, playerId, true, { autoClear = false })
        if ok and done ~= false then ours[playerId] = true
        else LightRP.log("pose ghost: refused for %d: %s", playerId, tostring(ok and why or done)) end
    elseif state.active ~= true or walkable(state) then
        release(playerId)
    end
end

AddEventHandler("onPlayerAnimationChanged", function(playerId, value)
    playerId = tonumber(playerId)
    if not playerId then return end
    if type(value) == "string" then
        local ok, decoded = pcall(json.decode, value)
        if not ok then return end
        value = decoded
    end
    PoseGhost.apply(playerId, value)
end)

function PoseGhost.onDisconnected(playerId) ours[playerId] = nil end
-- A death ends the pose; the flag goes with it (a respawn keeps life flags).
function PoseGhost.onLifeState(playerId, phase) if phase ~= "alive" then release(playerId) end end
