-- =============================================================================
-- open77_seating -- shared/model.lua
-- =============================================================================
-- Pure helpers shared by both halves: the configuration defaults, the
-- approach geometry per furniture kind, prompt labels and the reason
-- vocabulary. No platform call lives here, so the offline suite loads this
-- file as-is.
--
-- Global: Open77SeatingModel. Contract: docs/world-interaction/b6-seating.md.
-- =============================================================================

local M = {}
Open77SeatingModel = M

M.VERSION = "0.3.0"

-- open77_furniture flag bits this resource reads (server/index.lua FLAGS).
M.FLAG_DEPENDENT = 32       -- a pose enabled only while its master spot is occupied
M.FLAG_WIDE = 2048          -- chained poses span more than 0.5 m (a bench row)

-- ---------------------------------------------------------------------------
-- Configuration (server; convars seed some of it, lab commands change it)
-- ---------------------------------------------------------------------------
M.DEFAULTS = {
    -- Prompts: at most `promptLimit` seats within `promptRadius` (3D) and
    -- `promptVertical` of the player, refreshed when the player has moved
    -- `promptMoveM` or every `promptRefreshMs`. Never every row within 40 m.
    promptRadius = 3.0,
    promptVertical = 1.5,
    promptLimit = 3,
    promptMoveM = 0.75,
    promptRefreshMs = 3000,
    promptPlayersPerTick = 16,
    -- How players choose a seat (`open77_seating_ui`): "prompts" (E cards on
    -- the nearest seats), "menu" (ALT + click on the furniture through
    -- open77_contextmenu, no card) or "both". The menu needs every seat in
    -- reach, not the three nearest: a table of six chairs is clicked chair by
    -- chair, so the client is sent up to `menuLimit` seats within
    -- `menuRadius` (just past `sitRange`: a seat the server would refuse as
    -- too far is not offered).
    ui = "prompts",
    menuRadius = 3.5,
    menuLimit = 8,
    -- `/sit` and `/stand` for players (`open77_seating_commands`): a server
    -- with no out-of-character commands turns them off.
    commands = true,
    -- A request (prompt, /sit) is honoured for a pose within `sitRange` on the
    -- ground and `sitVertical` in height of the player; lab commands reach
    -- `labReach` (playAt refuses past 5 m from the approach point).
    sitRange = 3.0,
    sitVertical = 1.5,
    labReach = 4.5,
    -- Two bodies closer than this on the ground overlap: the player-player
    -- separation between occupied poses and the radius of the pedestrian
    -- hold around a seat.
    separation = 0.6,
    -- Rows (M.rowOffset): a seat whose spot has neighbours of the same
    -- workspot, yaw (`rowYawDeg`), floor and line (`rowLineM` off it) within
    -- `rowSearchM` belongs to a row, and a click slides the body along it, at
    -- most halfway to a neighbour and `rowEndM` past an outer spot. The
    -- player is moved off a body in the way by at most `rowShiftM`.
    rowSearchM = 1.6,
    rowYawDeg = 5.0,
    rowLineM = 0.15,
    rowEndM = 0.3,
    rowShiftM = 0.6,
    -- Claims (open77_actions) and pedestrian holds are renewed well inside
    -- their time to live.
    claimTtlMs = 30000,
    renewEveryMs = 10000,
    -- The approach (`open77_seating_approach`): "player" (default) lets playAt
    -- carry the body onto the anchor from where the player stands, on the side
    -- the player came from; "kind" first teleports the actor to the kind's
    -- point beside the furniture (M.APPROACH), as the A3 lab lever did. Live
    -- 2026-11-02 (LightRP, The Crossing bench): a bench row authored with
    -- chair spots took the chair rule, 1.2 m behind, and stood the player
    -- behind the backrest before sitting and again after standing up.
    -- "kind" skips the move when the body already stands within
    -- `approachSkipM` of the point and refuses it when the body lands farther
    -- than `approachToleranceM` from it (furniture or a wall pushed it).
    approach = "player",
    approachSkipM = 0.35,
    approachToleranceM = 0.75,
    approachTimeoutMs = 12000,
    -- The exit after standing up: "check" (default) moves the body only when
    -- the exit looks unsafe (fell, on top, flung -- flung only after an end
    -- the player did not walk out of), "approach" puts it back on the
    -- approach point when it ended farther than `exitToleranceM` from it,
    -- "none" never moves it. Live 2026-11-02: the posture's own exit leaves
    -- the body 0.41 m in front of a bench, on its feet; "approach" then
    -- teleported a player who was already walking away.
    exitMode = "check",
    exitSettleMs = 1500,
    exitToleranceM = 0.6,
    -- A body farther than this from the seat after an end did not stand up: a
    -- server teleport, a vehicle or a carry moved it (live 2026-10-12: a Warden
    -- teleport of a seated player ended as cancelled_by_player and the exit put
    -- it back beside the stool). The exit never pulls such a body back.
    exitLeftM = 4.0,
    maxPositionAgeMs = 1500,
    -- Which poses a player may take: verification states and postures. Lying
    -- is offered like sitting and leaning: only on poses whose verification is
    -- allowed (the measured bed resource by default, A1 id #9; other beds stay
    -- unverified until walked). The `open77_seating_postures` convar narrows it.
    verification = { measured = true },
    postures = { sit = true, lean = true, lie = true },
    -- Furniture flags never offered (a dependent pose needs its master
    -- occupied first).
    excludeFlags = 32,
    -- Client intents per player per second.
    intentWindowMs = 1000,
    intentBudget = 4,
    versionCheckMs = 10000,
}

function M.config(overrides)
    local out = {}
    for key, value in pairs(M.DEFAULTS) do
        if type(value) == "table" then
            local copy = {}
            for k, v in pairs(value) do copy[k] = v end
            out[key] = copy
        else
            out[key] = value
        end
    end
    for key, value in pairs(overrides or {}) do out[key] = value end
    return out
end

M.EXIT_MODES = { approach = true, check = true, none = true }
M.APPROACH_MODES = { player = true, kind = true }

-- ---------------------------------------------------------------------------
-- How a seat is chosen: E cards, the ALT context menu, or both
-- ---------------------------------------------------------------------------
M.UI_MODES = { prompts = true, menu = true, both = true }

function M.uiPrompts(ui) return ui == "prompts" or ui == "both" end
function M.uiMenu(ui) return ui == "menu" or ui == "both" end

-- A click on furniture lands on its seat, back, arm or top, never on the
-- anchor, which is the AI spot on the floor where the posture stands. The
-- body settles about 0.47 m from it (A3) and a wall lean is clicked up to
-- head height. So a hit names the seat whose anchor is within `MENU_HIT_GROUND`
-- on the ground and between `MENU_HIT_BELOW` under and `MENU_HIT_ABOVE` over
-- it; the nearest on the ground wins, then the nearest in height.
M.MENU_HIT_GROUND = 1.1
M.MENU_HIT_BELOW = 0.4
M.MENU_HIT_ABOVE = 2.2

--- The seat of `seats` (a list of { id, posture, anchor = { x, y, z } }) a
--- click at `hit` designates, for `posture` (nil: any), or nil.
function M.menuMatch(seats, hit, posture)
    if type(seats) ~= "table" or type(hit) ~= "table" then return nil end
    local hx, hy, hz = tonumber(hit.x), tonumber(hit.y), tonumber(hit.z)
    if not hx or not hy or not hz then return nil end
    local best, bestGround, bestHeight
    for _, seat in ipairs(seats) do
        local a = type(seat) == "table" and seat.anchor or nil
        if type(a) == "table" and (posture == nil or seat.posture == posture) and
            tonumber(a.x) and tonumber(a.y) and tonumber(a.z) then
            local dx, dy, dz = hx - a.x, hy - a.y, hz - a.z
            local ground = math.sqrt(dx * dx + dy * dy)
            if ground <= M.MENU_HIT_GROUND and dz >= -M.MENU_HIT_BELOW and dz <= M.MENU_HIT_ABOVE then
                local height = math.abs(dz)
                if best == nil or ground < bestGround - 1e-6 or
                    (math.abs(ground - bestGround) <= 1e-6 and height < bestHeight) then
                    best, bestGround, bestHeight = seat, ground, height
                end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Rows: sit where the click landed, never on somebody
-- ---------------------------------------------------------------------------
-- A bench is authored as a row of chair spots (The Crossing: four
-- `sit_chair` spots, 1.31 m apart on a bench, 0.92 m across its divider),
-- which the data cannot tell from a row of chairs. So the click itself is the
-- proof of a seat under it: the body slides to the clicked point along the
-- row only when the hit is on a surface at seat-to-backrest height
-- (`ROW_HIT_HEIGHT`) over the floor anchor, and from just in front of the
-- spot to behind it (`ROW_HIT_DEPTH`, positive = behind). A click between two
-- chairs hits the floor; a table is in front of its chairs.
M.ROW_HIT_HEIGHT = { 0.2, 1.4 }
M.ROW_HIT_DEPTH = { -0.15, 1.1 }
M.ROW_STEP = 0.05
-- A seated body sits about this far behind its floor anchor (A3: 0.41-0.47 m);
-- another player's body there or on the anchor is in the way.
M.SEAT_BACK = 0.45

-- The smallest difference between two yaws, in degrees.
function M.yawDelta(a, b)
    local d = ((tonumber(a) or 0) - (tonumber(b) or 0)) % 360
    if d > 180 then d = 360 - d end
    return d
end

-- (lateral, depth) of `point` in the frame of `pose`: metres to its right and
-- behind it (the seat side), on the ground.
function M.frame(pose, point)
    local rx, ry = M.right(pose.yaw)
    local fx, fy = M.forward(pose.yaw)
    local dx, dy = point.x - pose.x, point.y - pose.y
    return dx * rx + dy * ry, -(dx * fx + dy * fy)
end

--- Whether `other` is a spot of the same row as `pose`: same workspot, yaw
--- and floor, on its line, within `c.rowSearchM` of it.
function M.sameRow(pose, other, c)
    if type(other) ~= "table" or other.spot == pose.spot then return false end
    if pose.resource ~= nil and other.resource ~= pose.resource then return false end
    if M.yawDelta(other.yaw, pose.yaw) > c.rowYawDeg or math.abs((other.z or 0) - pose.z) > 0.1 then return false end
    local lateral, depth = M.frame(pose, other)
    return math.abs(depth) <= c.rowLineM and math.abs(lateral) > M.ROW_STEP and math.abs(lateral) <= c.rowSearchM
end

--- The lateral offset (metres along the pose's right; 0 = the spot itself)
--- at which a body sits for a click at `hit` (nil: no click, the spot), given
--- the spots of the same row (`neighbours`, M.sameRow) and the points already
--- occupied (`occupants`: seated anchors and other players' bodies). A free
--- offset as near the click as possible, at most `c.rowShiftM` from it; nil,
--- "seat_taken" when every place within that is in somebody's way.
function M.rowOffset(pose, hit, neighbours, occupants, c)
    local left, right = nil, nil
    for _, other in ipairs(neighbours or {}) do
        local s = M.frame(pose, other)
        if s > 0 and (right == nil or s < right) then right = s end
        if s < 0 and (left == nil or s > left) then left = s end
    end
    local lo, hi, want = 0, 0, 0
    if left ~= nil or right ~= nil then
        lo = left and left / 2 or -c.rowEndM
        hi = right and right / 2 or c.rowEndM
        if type(hit) == "table" then
            local s, depth = M.frame(pose, hit)
            local height = hit.z - pose.z
            if height >= M.ROW_HIT_HEIGHT[1] and height <= M.ROW_HIT_HEIGHT[2] and
                depth >= M.ROW_HIT_DEPTH[1] and depth <= M.ROW_HIT_DEPTH[2] then
                want = math.max(lo, math.min(hi, s))
            end
        end
    end
    local rx, ry = M.right(pose.yaw)
    local fx, fy = M.forward(pose.yaw)
    local separation = c.separation
    local function free(s)
        local ax, ay = pose.x + rx * s, pose.y + ry * s
        local bx, by = ax - fx * M.SEAT_BACK, ay - fy * M.SEAT_BACK
        for _, o in ipairs(occupants or {}) do
            if math.abs((o.z or pose.z) - pose.z) <= 1.0 then
                local d1 = math.sqrt((o.x - ax) ^ 2 + (o.y - ay) ^ 2)
                local d2 = math.sqrt((o.x - bx) ^ 2 + (o.y - by) ^ 2)
                if d1 <= separation + 1e-6 or d2 <= separation + 1e-6 then return false end
            end
        end
        return true
    end
    if free(want) then return want end
    -- Step away from the click, right then left, within the row and rowShiftM.
    for k = 1, math.floor(c.rowShiftM / M.ROW_STEP + 1e-6) do
        for _, s in ipairs({ want + k * M.ROW_STEP, want - k * M.ROW_STEP }) do
            if s >= lo - 1e-9 and s <= hi + 1e-9 and free(s) then return s end
        end
    end
    return nil, "seat_taken"
end

-- The pose `s` metres along the right of `pose` (same yaw and floor).
function M.slide(pose, s)
    if s == 0 then return pose end
    local rx, ry = M.right(pose.yaw)
    local out = {}
    for k, v in pairs(pose) do out[k] = v end
    out.x, out.y = pose.x + rx * s, pose.y + ry * s
    return out
end

-- ---------------------------------------------------------------------------
-- Approach geometry
-- ---------------------------------------------------------------------------
-- Where the actor stands before the posture carries the body onto the
-- anchor, in the furniture's frame: `ahead` metres along the pose's facing
-- (negative = behind it) and `side` metres to its right. Inference from the
-- kinds, not a measurement except where noted:
--   behind 1.2 m  seats at a table or a counter (the table/counter is in
--                 front): the a3.go stand point every live seat used
--                 (chair, bench through chair poses, barstool, bar seat,
--                 interior chair; A3, A2 and the A1 ten ids);
--   front 1.0 m   the wall/backrest is behind (wall leans, couches,
--                 benches with their own family);
--   right 1.0 m   lying furniture other than beds (couches, benches);
--   player        no offset known: the actor's own position is the
--                 approach (rails: front and back leans share one kind).
M.APPROACH = {
    chair = { ahead = -1.2, side = 0 },
    chair_lean_back = { ahead = -1.2, side = 0 },
    chair_table = { ahead = -1.2, side = 0 },
    barstool = { ahead = -1.2, side = 0 },
    -- Live 2026-10-12 (bar seat #10): the point 1.2 m behind lands on the step of the bar wall
    -- (approach_blocked); playAt from where the player stands seats it (arrivalRadius 0.75).
    bar_seat = "player",
    stool = { ahead = -1.2, side = 0 },
    armchair = { ahead = 1.0, side = 0 },
    netrunner_chair = { ahead = -1.2, side = 0 },
    sit_other = { ahead = -1.2, side = 0 },
    lean_bar = { ahead = -1.0, side = 0 },
    lean_table = { ahead = -1.0, side = 0 },
    lean_wall = { ahead = 1.0, side = 0 },
    couch = { ahead = 1.0, side = 0 },
    bench = { ahead = 1.0, side = 0 },
    ledge = { ahead = -1.0, side = 0 },
    curb = { ahead = 1.0, side = 0 },
    stairs = { ahead = 1.0, side = 0 },
    table = { ahead = 1.0, side = 0 },
    bed_edge = { ahead = 1.0, side = 0 },
    -- Live 2026-10-12, A1 id #9: the point beside the bed was approach_blocked; lying from where the
    -- player stands works on both rigs (with the client's anchored settle window).
    bed = "player",
    couch_lie = { ahead = 0, side = 1.0 },
    bench_lie = { ahead = 0, side = 1.0 },
    lean_rail = "player",
}

-- Named overrides a lab command or an export may pass instead of the kind's.
M.APPROACH_NAMES = {
    back = { ahead = -1.2, side = 0 },
    front = { ahead = 1.0, side = 0 },
    left = { ahead = 0, side = -1.0 },
    right = { ahead = 0, side = 1.0 },
    player = "player",
    none = "none",
}

-- REDengine convention shared by playAt and Open77.props: yaw in degrees
-- about +Z, 0 faces +Y, so forward is (-sin, cos) and right is (cos, sin).
function M.forward(yaw)
    local r = math.rad(tonumber(yaw) or 0.0)
    return -math.sin(r), math.cos(r)
end

function M.right(yaw)
    local r = math.rad(tonumber(yaw) or 0.0)
    return math.cos(r), math.sin(r)
end

-- The approach point of `pose` ({ x, y, z, yaw }) for `kind`, or nil when the
-- actor's own position serves ("player") or none is wanted ("none"). `name`,
-- when given, overrides the kind's rule. The point is 5 cm above the anchor,
-- which sits on the floor under the furniture.
function M.approachPoint(kind, pose, name)
    local rule = name and M.APPROACH_NAMES[name] or M.APPROACH[kind] or M.APPROACH_NAMES.back
    if type(rule) ~= "table" then return nil, rule end
    local fx, fy = M.forward(pose.yaw)
    local rx, ry = M.right(pose.yaw)
    return { x = pose.x + fx * rule.ahead + rx * rule.side, y = pose.y + fy * rule.ahead + ry * rule.side,
        z = pose.z + 0.05 }, "offset"
end

-- ---------------------------------------------------------------------------
-- Small values
-- ---------------------------------------------------------------------------
function M.playerId(value)
    local n = tonumber(value)
    if n == nil or n ~= n or n % 1 ~= 0 or n < 1 or n > 2147483647 then return nil end
    return math.tointeger(n)
end

-- A furniture id is the decimal global node id (it exceeds 2^63: a string).
function M.furnitureId(value)
    if math.type(value) == "integer" and value > 0 then return tostring(value) end
    if type(value) == "string" and #value >= 1 and #value <= 20 and value:match("^%d+$") then return value end
    return nil
end

function M.ground(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function M.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.vector(value)
    if type(value) ~= "table" then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    return { x = x, y = y, z = z }
end

-- ---------------------------------------------------------------------------
-- Labels
-- ---------------------------------------------------------------------------
local NOUN = {
    chair = "chair", chair_lean_back = "chair", chair_table = "chair", barstool = "stool", bar_seat = "bar seat",
    stool = "stool", armchair = "armchair", netrunner_chair = "chair", couch = "couch", bench = "bench",
    ledge = "ledge", curb = "curb", stairs = "steps", table = "table", bed_edge = "bed", sit_other = "seat",
    bed = "bed", couch_lie = "couch", bench_lie = "bench", lean_wall = "wall", lean_rail = "rail",
    lean_bar = "counter", lean_table = "table",
}
local VERB = { sit = "Sit on the ", lean = "Lean on the ", lie = "Lie down on the " }

function M.label(kind, posture)
    return (VERB[posture] or "Use the ") .. (NOUN[kind] or "seat")
end

-- ---------------------------------------------------------------------------
-- Reasons (every one is produced by the server half and exercised by the suite)
-- ---------------------------------------------------------------------------
M.REASONS = {
    -- request shape and state
    "invalid_player", "invalid_furniture", "unknown_furniture", "unknown_spot", "furniture_unavailable",
    "indexing", "no_playable_pose", "already_seated", "not_seated", "actor_busy",
    -- actor state, re-derived on the server
    "player_unavailable", "player_not_ready", "player_not_alive", "player_in_vehicle", "position_unavailable",
    "position_stale", "in_combat", "too_far", "bucket_not_enabled",
    -- occupancy
    "seat_taken", "target_claimed", "claims_unavailable", "npc_occupied",
    -- approach and presentation
    "approach_failed", "approach_blocked", "approach_timeout", "animation_refused",
    -- ends of a seat
    "stood", "cancelled_by_player", "anchor_unreached", "moved", "dead", "disconnected", "bucket_changed",
    "vehicle", "combat", "claim_lost", "furniture_changed", "resource_stopping", "animation_interrupted",
}

local reasonSet = {}
for _, reason in ipairs(M.REASONS) do reasonSet[reason] = true end
function M.isReason(value) return reasonSet[value] == true end

-- Ends after which the body is put back on its approach point (when the
-- exit mode asks for it): the actor stood up, or the posture never reached
-- the anchor, or the seat was taken away from under a living actor.
M.EXIT_REASONS = {
    stood = true, cancelled_by_player = true, anchor_unreached = true, claim_lost = true,
    furniture_changed = true, approach_blocked = true,
}

-- Ends the player walks out of: the posture's own exit puts the body on its
-- feet in front of the seat and the player may already be walking away when
-- the exit is checked, so distance alone never moves the body ("check").
M.EXIT_WALKED = { stood = true, cancelled_by_player = true }

return M
