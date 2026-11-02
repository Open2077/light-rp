-- op77_chase queue (admission order, modes, eligibility) and Elo maths. Pure Lua.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test queue_elo_test.lua
dofile("shared/config.lua")
dofile("server/queue.lua")
dofile("server/elo.lua")
local Q, E = ChaseQueue, ChaseElo
local yes = function() return true end

-- ── queue: add, duplicates, positions, modes ──
do
    Q.reset()
    assert(Q.normalizeMode("CAR") == "vehicle" and Q.normalizeMode("onfoot") == "foot" and Q.normalizeMode("boat") == nil and Q.normalizeMode(nil) == nil)
    assert(Q.add(1, "car", 0) == 1)
    local pos, why = Q.add(1, "foot", 0)
    assert(pos == nil and why == "already_queued")
    assert(select(1, Q.add(2, nil, 10)) == 2)
    local p, total, entry = Q.position(2)
    assert(p == 2 and total == 2 and entry.mode == nil)
    assert(Q.remove(1) == true and Q.remove(1) == false and Q.position(2) == 1)
    print("PASS queue basics")
end

-- ── queue: pairing is FIFO among compatible modes ──
do
    Q.reset()
    Q.add(1, "foot", 0); Q.add(2, "car", 1); Q.add(3, "car", 2); Q.add(4, nil, 3)
    -- The head of the queue goes first, with the first compatible entry behind it.
    local pair = Q.pair(10, yes, { defaultMode = "vehicle" })
    assert(pair.a == 1 and pair.b == 4 and pair.mode == "foot", "foot skips the cars; no preference takes the other's")
    assert(pair.modes[1] == "foot" and pair.modes[4] == nil)
    pair = Q.pair(10, yes, { defaultMode = "vehicle" })
    assert(pair.a == 2 and pair.b == 3 and pair.mode == "vehicle")
    Q.add(5, nil, 20); Q.add(6, nil, 21)
    pair = Q.pair(30, yes, { defaultMode = "vehicle" })
    assert(pair.mode == "vehicle", "nobody asked: the default")
    assert(Q.size() == 0 and Q.pair(30, yes, {}) == nil)
    print("PASS queue pairing")
end

-- ── queue: a player who is not ready is skipped, told, then dropped ──
do
    Q.reset()
    Q.add(1, nil, 0); Q.add(2, nil, 0); Q.add(3, nil, 0)
    local busy = { [1] = "You are in a vehicle." }
    local ready = function(id) if busy[id] then return false, busy[id] end return true end
    local pair, notReady, dropped = Q.pair(1000, ready, { dropAfterMs = 120000 })
    assert(pair.a == 2 and pair.b == 3, "the next ready pair goes first")
    assert(#notReady == 1 and notReady[1].id == 1 and notReady[1].reason == "You are in a vehicle." and #dropped == 0)
    assert(Q.position(1) == 1, "still queued, still first")
    Q.add(4, nil, 2000)
    busy[4] = "You are on a mission."
    pair, notReady, dropped = Q.pair(120999, ready, { dropAfterMs = 120000 })
    assert(pair == nil and #notReady == 2 and #dropped == 0)
    pair, notReady, dropped = Q.pair(121000, ready, { dropAfterMs = 120000 })
    assert(#dropped == 1 and dropped[1].id == 1 and Q.position(1) == nil, "dropped after notReadyDropSeconds")
    -- Back to ready: the not-ready clock restarts.
    busy[4] = nil
    Q.add(5, nil, 121000)
    pair = Q.pair(121200, ready, { dropAfterMs = 120000 })
    assert(pair.a == 4 and pair.b == 5)
    print("PASS queue eligibility")
end

-- ── queue: expiry and requeue at the front ──
do
    Q.reset()
    Q.add(1, nil, 0); Q.add(2, "foot", 500)
    local gone = Q.expire(900000, 900000)
    assert(#gone == 1 and gone[1] == 1 and Q.size() == 1)
    Q.requeueFront(7, "car", 900000)
    assert(Q.position(7) == 1 and Q.position(2) == 2)
    Q.requeueFront(7, "car", 900000)
    assert(Q.size() == 2, "requeue never duplicates")
    print("PASS queue expiry")
end

-- ── Elo ──
do
    local t = E.settings(ChaseConfig.ranked)
    assert(t.startRating == 1000 and t.provisionalK == 40 and t.baseK == 20 and t.floorRating == 100)
    assert(math.abs(E.expected(1000, 1000, 400) - 0.5) < 1e-9)
    local a, b = E.blank(t), E.blank(t)
    local dA, dB, kA = E.rate(a, b, 1.0, t)
    assert(dA == 20 and dB == -20 and kA == 40, "equal provisional players: +-20")
    E.apply(a, dA, 1.0); E.apply(b, dB, 0.0, true)
    assert(a.rating == 1020 and a.wins == 1 and a.peak == 1020 and b.rating == 980 and b.losses == 1 and b.forfeits == 1)
    -- A draw between equals moves nothing; beating a stronger player pays more.
    dA, dB = E.rate(E.blank(t), E.blank(t), 0.5, t)
    assert(dA == 0 and dB == 0)
    local strong = { rating = 1400, matches = 30 }
    local weak = { rating = 1000, matches = 30 }
    local up = E.rate(weak, strong, 1.0, t)
    local down = E.rate(strong, weak, 1.0, t)
    assert(up > down and up == 18 and down >= 1, ("upset %d vs expected win %d"):format(up, down))
    -- minDelta: a near-certain win still pays 1.
    assert(E.rate({ rating = 3000, matches = 50 }, { rating = 100, matches = 50 }, 1.0, t) == 1)
    -- The floor.
    local low = { rating = 105, matches = 50 }
    dA = E.rate(low, { rating = 105, matches = 50 }, 0.0, t)
    assert(low.rating + dA == 100, "never under floorRating")
    -- Settings clamp nonsense.
    local odd = E.settings({ startRating = "x", baseK = 1e9, floorRating = 9999 })
    assert(odd.startRating == 1000 and odd.baseK == 100 and odd.floorRating == 1000)
    print("PASS elo")
end

print("PASS: op77_chase queue (FIFO, modes, eligibility skip/notice/drop, expiry, requeue) and Elo (provisional K, draw, upset, minDelta, floor, clamps)")
