-- Private rooms under NEON DECK: three rooms built once in the world (neon_deck, level -1, floor z 4.0), each
-- instanced per group in its own routing bucket. A host behind the shop counter opens a room (a code is made) and
-- takes the players down; friends join with the code. Every room has a duel table with two 1v1 slots.
-- Coordinates use the shop frame of shared/table.lua (u east, v north, metres).
TcgRooms = {
    bucketBase = 5200000,     -- free range: LightRP uses 610000, 620000, 700000, 1000000+, 3000000+, 4100001-2
    maxRooms = 24,
    maxPlayers = 8,
    codeLength = 5,
    codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",   -- no I, O, 0, 1
    emptyCloseMs = 5 * 60 * 1000,                     -- a room nobody is in closes after this
    floor = 4.0,
    -- The host behind the counter (east end of the checkout counter) and where a player stands to talk to them.
    host = { u = 12.3, v = 1.84, z = 12.14, turn = 0, record = "Character.sts_hey_rey_06_receptionist",
             talk = { u = 12.3, v = 3.3, z = 12.14 }, talkRadius = 2.2,
             back = { u = 12.0, v = 3.7, z = 12.14, turn = 180 } },
    -- Room centres (u, v); inner size 7.0 x 6.6, the exit door on the south wall.
    styles = {
        shop = { label = "Neon Deck", blurb = "The shop's own look: black lacquer, yellow and neon.", u = -0.5, v = 4.5, order = 1 },
        cozy = { label = "Cozy Lounge", blurb = "Brick, oak and warm lights, a rug and full bookcases.", u = 7.1, v = 4.5, order = 2 },
        jp = { label = "Tatami Room", blurb = "Tatami, shoji screens, lanterns and a golden screen.", u = 14.7, v = 4.5, order = 3 },
    },
    -- Relative to a room's centre: where players arrive (facing the table), the exit point by the door.
    arrive = { du = 0.0, dv = -2.4, turn = 0 },
    exit = { du = 0.0, dv = -2.95, radius = 1.3 },
    half = { u = 3.5, v = 3.3 },
}

function TcgRooms.styleList()
    local out = {}
    for id, s in pairs(TcgRooms.styles) do out[#out + 1] = { id = id, label = s.label, blurb = s.blurb, order = s.order } end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

-- World point of a frame (u, v, z) (TcgTable.frame).
function TcgRooms.world(u, v, z)
    local f = TcgTable.frame
    local a = math.rad(f.yaw)
    return { x = f.ox + u * math.cos(a) - v * math.sin(a), y = f.oy + u * math.sin(a) + v * math.cos(a), z = z }
end

-- Heading for a frame turn (0 = facing +v, north).
function TcgRooms.heading(turn) return (TcgTable.frame.yaw + (turn or 0)) % 360 end

function TcgRooms.arrival(style, k)
    local s = TcgRooms.styles[style]
    if not s then return nil end
    -- several players arriving together stand side by side
    local off = ((k or 1) - 1) % 4
    local du = (off == 0 and 0) or (off == 1 and 0.7) or (off == 2 and -0.7) or 1.4
    return TcgRooms.world(s.u + TcgRooms.arrive.du + du, s.v + TcgRooms.arrive.dv, TcgRooms.floor + 0.05),
        TcgRooms.heading(TcgRooms.arrive.turn)
end

function TcgRooms.exitPoint(style)
    local s = TcgRooms.styles[style]
    return s and TcgRooms.world(s.u + TcgRooms.exit.du, s.v + TcgRooms.exit.dv, TcgRooms.floor) or nil
end

-- Which room's volume holds a world point (any bucket): its style, or nil.
function TcgRooms.styleAt(p)
    if not p or not p.z or p.z < TcgRooms.floor - 0.6 or p.z > TcgRooms.floor + 3.6 then return nil end
    local f = TcgTable.frame
    local a = math.rad(f.yaw)
    local dx, dy = p.x - f.ox, p.y - f.oy
    local u, v = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
    for id, s in pairs(TcgRooms.styles) do
        if math.abs(u - s.u) <= TcgRooms.half.u + 0.2 and math.abs(v - s.v) <= TcgRooms.half.v + 0.2 then return id end
    end
end

function TcgRooms.isRoomBucket(b) return type(b) == "number" and b > TcgRooms.bucketBase and b <= TcgRooms.bucketBase + 100000 end

function TcgRooms.hostPosition()
    local h = TcgRooms.host
    return TcgRooms.world(h.u, h.v, h.z), TcgRooms.heading(h.turn)
end
function TcgRooms.talkPoint() local t = TcgRooms.host.talk; return TcgRooms.world(t.u, t.v, t.z) end
function TcgRooms.backPoint() local b = TcgRooms.host.back; return TcgRooms.world(b.u, b.v, b.z), TcgRooms.heading(b.turn) end
