-- The death cover: hides the local body's first-person death.
--
-- The platform's soft death (CyberM LifeReplication.cpp, UpdateLocalDeathPose) plays the
-- PlayerVitals collapse on the local body, and the perspective arbiter's `dead` row
-- (PerspectiveArbiter.cpp) pins first person for the whole Dead / RevivePending /
-- RespawnPending window: the camera rolls onto the floor with an arm in view for as long as
-- the player is down. From the instant the local life ledger reads down, the page draws a
-- full-screen "flatline" (ui/src/features/medical/DeathCover.tsx) under the medical panel;
-- it lifts with a reboot once the body is recovering or alive.
--
-- Read-only: no life, input, focus or camera decision is taken here. Every death counts
-- (city, missions, activities, arena), whoever respawns or revives the body.
local Ui = LightRpUi
local PAGE = "lightrp:ui:medical" -- the medical panel's channel: one page feature, two kinds
local Cover = { down = false, revision = nil, cause = nil }
LightRpDeathCover = Cover

-- kill(script) + respawn in one server tick is how a body is moved (server/main.lua placeAt,
-- arena / games placements): the Dead revision is followed at once by RespawnPending. A
-- scripted death is covered only once it is still plain Dead after this grace.
Cover.SCRIPT_GRACE_MS = 150
local DOWN = { dead = true, revivepending = true, respawnpending = true }
local pending -- { revision, since }: a scripted death waiting out the placement grace

-- The client spells revive_pending / respawn_pending; tolerate the server spelling too.
local function phaseOf(state)
    return type(state) == "table" and type(state.phase) == "string" and (state.phase:gsub("_", "")) or nil
end

function Cover.read()
    local players = Open77 and Open77.players
    if type(players) ~= "table" or type(players.getLifeState) ~= "function" then return nil end
    local ok, state = pcall(players.getLifeState)
    return ok and type(state) == "table" and state or nil
end

function Cover.publish()
    return Ui.send(PAGE, { kind = "cover", down = Cover.down, revision = Cover.revision, cause = Cover.cause })
end

local function set(down, state)
    if Cover.down == down then return end
    Cover.down = down
    Cover.revision = state and tonumber(state.revision) or nil
    Cover.cause = down and state and type(state.cause) == "string" and state.cause or nil
    Cover.publish()
end

function Cover.isDown() return Cover.down end
function Cover.pending() return pending ~= nil end

-- One reading of the local life state; `now` in ms (GetGameTimer).
function Cover.update(now)
    local state = Cover.read()
    local phase = phaseOf(state)
    if not phase or not DOWN[phase] then
        pending = nil
        set(false, state)
        return
    end
    if Cover.down then pending = nil; return end
    if state.cause ~= "script" then pending = nil; set(true, state); return end
    -- Scripted: a placement passes through Dead into RespawnPending within the same tick.
    if phase ~= "dead" then pending = nil; return end
    local revision = tonumber(state.revision)
    if not pending or pending.revision ~= revision then pending = { revision = revision, since = now } end
    if now - pending.since >= Cover.SCRIPT_GRACE_MS then pending = nil; set(true, state) end
end

function Cover.bind(page)
    page:on(LightRpEvents.page.ready, function() Cover.publish() end)
end

AddEventHandler("open77:playerLifeStateChanged", function() Cover.update(GetGameTimer()) end)

-- The event is the fast path; this reading is the safety net (a missed event, a resource
-- started while dead) and runs the scripted-death grace.
CreateThread(function()
    while true do
        Wait(pending and 30 or 200)
        Cover.update(GetGameTimer())
    end
end)
