-- op77_chase Elo: Pursuit's ladder maths (base resources/gamemodes/pursuit/server/ranked.lua),
-- pure Lua. A MATCH is rated, never a round: with two rounds and swapped roles both players
-- play each side once, so a cop/runner imbalance cancels inside the match.
--   * the change is proportional to the expectation (beating a stronger player pays more);
--   * a draw is S = 0.5;
--   * K is provisionalK for a player's first provisionalMatches, then baseK;
--   * an abandonment is rated exactly as a loss.
ChaseElo = {}
local E = ChaseElo

function E.settings(raw)
    raw = raw or {}
    local function number(value, fallback, low, high)
        local n = tonumber(value)
        if n == nil or n ~= n then return fallback end
        if n < low then return low end
        if n > high then return high end
        return n
    end
    local function integer(value, fallback, low, high) return math.floor(number(value, fallback, low, high) + 0.5) end
    local t = {
        enabled = raw.enabled ~= false,
        startRating = integer(raw.startRating, 1000, 100, 5000),
        spread = number(raw.spread, 400.0, 50.0, 2000.0),
        baseK = number(raw.baseK, 20.0, 1.0, 100.0),
        provisionalK = number(raw.provisionalK, 40.0, 1.0, 200.0),
        provisionalMatches = integer(raw.provisionalMatches, 10, 0, 100),
        floorRating = integer(raw.floorRating, 100, 0, 5000),
        minDelta = integer(raw.minDelta, 1, 0, 50),
        rateUnplayedForfeit = raw.rateUnplayedForfeit == true,
        leaderboardSize = integer(raw.leaderboardSize, 10, 1, 25),
    }
    if t.floorRating > t.startRating then t.floorRating = t.startRating end
    return t
end

function E.expected(a, b, spread)
    return 1.0 / (1.0 + 10.0 ^ ((b - a) / spread))
end

local function roundHalfAway(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return -math.floor(-value + 0.5)
end

function E.kFor(record, t)
    if (record.matches or 0) < t.provisionalMatches then return t.provisionalK end
    return t.baseK
end

function E.delta(rating, opponentRating, score, k, t)
    local delta = roundHalfAway(k * (score - E.expected(rating, opponentRating, t.spread)))
    if score >= 1.0 and delta < t.minDelta then delta = t.minDelta end
    if score <= 0.0 and delta > -t.minDelta then delta = -t.minDelta end
    return delta
end

function E.blank(t)
    return { rating = t.startRating, matches = 0, wins = 0, losses = 0, draws = 0, forfeits = 0, busts = 0, escapes = 0, peak = t.startRating }
end

-- Rate one match. `a` and `b` are records (rating, matches...); `scoreA` is 1, 0.5 or 0.
-- Returns the two deltas and the K used; mutates nothing.
function E.rate(a, b, scoreA, t)
    local kA, kB = E.kFor(a, t), E.kFor(b, t)
    local dA = E.delta(a.rating, b.rating, scoreA, kA, t)
    local dB = E.delta(b.rating, a.rating, 1.0 - scoreA, kB, t)
    if a.rating + dA < t.floorRating then dA = t.floorRating - a.rating end
    if b.rating + dB < t.floorRating then dB = t.floorRating - b.rating end
    return dA, dB, kA, kB
end

-- Apply a delta and the counters to a record (in place).
function E.apply(record, delta, score, forfeit)
    record.rating = record.rating + delta
    record.matches = (record.matches or 0) + 1
    if score >= 1.0 then record.wins = (record.wins or 0) + 1
    elseif score <= 0.0 then record.losses = (record.losses or 0) + 1
    else record.draws = (record.draws or 0) + 1 end
    if forfeit and score <= 0.0 then record.forfeits = (record.forfeits or 0) + 1 end
    if record.rating > (record.peak or record.rating) then record.peak = record.rating end
    return record
end
