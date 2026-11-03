-- op77_fireworks -- the pure half: no natives, no clock, no randomness of its
-- own (a random source is passed in). Everything here is unit-tested by
-- tests/fireworks_test.lua; server/main.lua only adds the natives and timers.

FireworksPlan = {}
local P = FireworksPlan

local function number(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return n
end
P.number = number

local function integer(value, fallback)
    return math.floor(number(value, fallback))
end

-- ---------------------------------------------------------------------------
-- A show becomes a timeline of beats
-- ---------------------------------------------------------------------------

--- The sound a cue's first copy plays: `true` = the configured boom, a string =
--- that Wwise event, anything else = silence.
local function soundFor(cue, defaultSound)
    if cue.sound == true then return defaultSound end
    if type(cue.sound) == "string" and cue.sound ~= "" then return cue.sound end
    return nil
end

--- Flatten cues into beats `{ at, cue, copy, def, sound }`, ordered by time,
--- then by cue, then by copy (stable: two cues on one beat keep their order).
function P.expand(cues, defaultSound)
    local beats = {}
    for index, cue in ipairs(type(cues) == "table" and cues or {}) do
        if type(cue) == "table" then
            local at = math.max(0, integer(cue.at, 0))
            local count = math.min(200, math.max(1, integer(cue.count, 1)))
            local spread = math.max(0, integer(cue.spreadMs, 0))
            for copy = 1, count do
                beats[#beats + 1] = {
                    at = at + (copy - 1) * spread,
                    cue = index,
                    copy = copy,
                    def = cue,
                    sound = copy == 1 and soundFor(cue, defaultSound) or nil,
                }
            end
        end
    end
    table.sort(beats, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        if a.cue ~= b.cue then return a.cue < b.cue end
        return a.copy < b.copy
    end)
    return beats
end

--- No more than `size` beats in one slice of `gapMs`: the extras move to the
--- start of the next slice. A whole show's worth of effects in one server tick
--- reaches a client as one burst and overruns its per-frame script budget, which
--- loses effects AND leaks quota slots (memory note on the client effect quota).
--- Beats only ever move later, and their order is kept.
function P.slice(beats, size, gapMs)
    size = math.max(1, integer(size, 8))
    gapMs = math.max(1, integer(gapMs, 60))
    local sliceStart, inSlice, last = nil, 0, 0
    for _, beat in ipairs(beats) do
        local at = math.max(beat.at, last)
        if sliceStart == nil or at >= sliceStart + gapMs then
            sliceStart, inSlice = at, 0
        elseif inSlice >= size then
            at = sliceStart + gapMs
            sliceStart, inSlice = at, 0
        end
        inSlice = inSlice + 1
        beat.at = at
        last = at
    end
    return beats
end

--- At most `maxLive` beats alive at once, a beat living `lifeMs`. Beats over the
--- budget are dropped rather than delayed: a late shell breaks the rhythm, a
--- missing one thins it. Expects beats ordered by time (as `slice` leaves them).
--- Returns the kept beats and how many were dropped.
function P.budget(beats, maxLive, lifeMs)
    maxLive = math.max(1, integer(maxLive, 60))
    lifeMs = math.max(1, integer(lifeMs, 10000))
    local kept, dropped = {}, 0
    local expiries, head = {}, 1 -- ascending, because beats are and life is constant
    for _, beat in ipairs(beats) do
        while head <= #expiries and expiries[head] <= beat.at do head = head + 1 end
        if #expiries - head + 1 < maxLive then
            expiries[#expiries + 1] = beat.at + lifeMs
            kept[#kept + 1] = beat
        else
            dropped = dropped + 1
        end
    end
    return kept, dropped
end

--- The most beats alive at any moment, for the tests and the status line.
function P.peakLive(beats, lifeMs)
    lifeMs = math.max(1, integer(lifeMs, 10000))
    local peak, head = 0, 1
    for index, beat in ipairs(beats) do
        while beats[head].at + lifeMs <= beat.at do head = head + 1 end
        peak = math.max(peak, index - head + 1)
    end
    return peak
end

--- expand -> slice -> budget, with the configuration's numbers.
--- Returns beats, droppedCount, durationMs.
function P.build(cues, config)
    config = config or {}
    local budget = config.budget or {}
    local beats = P.expand(cues, config.sound)
    P.slice(beats, budget.sliceSize, budget.sliceGapMs)
    local kept, dropped = P.budget(beats, budget.maxLive, budget.shellLifeMs)
    local duration = #kept > 0 and kept[#kept].at or 0
    return kept, dropped, duration
end

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

--- A shell at random, minus the one just used. `rng()` answers [0, 1).
function P.nextShell(shells, last, rng)
    if type(shells) ~= "table" or #shells == 0 then return nil end
    local count = #shells
    if count == 1 then return shells[1] end
    local index = math.min(count, math.floor(number(rng(), 0) * count) + 1)
    if shells[index] == last then index = index % count + 1 end
    return shells[index]
end

--- One beat lands on a disc around `centre`, inside the height band. `sqrt` on
--- the radius roll keeps the disc uniform; a point is redrawn a few times until
--- it clears the previous one by `minSeparation`, then taken as it comes -- a
--- show must never stall on geometry.
function P.point(def, centre, last, config, rng)
    def, config = def or {}, config or {}
    local radius = math.max(0.0, number(def.radius, number(config.radius, 40.0)))
    local minHeight = number(def.minHeight, number(config.minHeight, 25.0))
    local maxHeight = number(def.maxHeight, number(config.maxHeight, 45.0))
    local separation = number(config.minSeparation, 26.0)
    local point
    for _ = 1, 8 do
        local angle = number(rng(), 0) * math.pi * 2.0
        local distance = math.sqrt(number(rng(), 0)) * radius
        point = {
            x = centre.x + math.cos(angle) * distance,
            y = centre.y + math.sin(angle) * distance,
            z = centre.z + minHeight + number(rng(), 0) * math.max(0.0, maxHeight - minHeight),
        }
        if last == nil then break end
        local dx, dy, dz = point.x - last.x, point.y - last.y, point.z - last.z
        if dx * dx + dy * dy + dz * dz >= separation * separation then break end
    end
    return point
end

--- Move a point `metres` along `heading` (degrees, 0 = +Y, counter-clockwise
--- seen from above -- the platform's yaw convention).
function P.offset(point, heading, metres)
    metres = number(metres, 0.0)
    if metres == 0.0 then return { x = point.x, y = point.y, z = point.z } end
    local radians = math.rad(number(heading, 0.0))
    return {
        x = point.x - math.sin(radians) * metres,
        y = point.y + math.cos(radians) * metres,
        z = point.z,
    }
end

--- A routing bucket is a non-negative integer; anything else is refused.
function P.bucket(value)
    local n = tonumber(value)
    if n == nil or n ~= n or n < 0 or n % 1 ~= 0 or n > 2147483647 then return nil end
    return math.floor(n)
end

--- Case-insensitive lookup of a configured place or show. Returns key, value.
function P.find(map, name)
    if type(map) ~= "table" or type(name) ~= "string" then return nil end
    local wanted = name:lower()
    for key, value in pairs(map) do
        if type(key) == "string" and key:lower() == wanted then return key, value end
    end
    return nil
end

--- Sorted keys of a table, for messages.
function P.keys(map)
    local list = {}
    for key in pairs(type(map) == "table" and map or {}) do list[#list + 1] = tostring(key) end
    table.sort(list)
    return list
end

-- ---------------------------------------------------------------------------
-- Scheduling
-- ---------------------------------------------------------------------------

--- `10` and `2.5` are minutes; `90s` and `5m` say their unit. Returns
--- milliseconds, or nil and a reason a player can read.
function P.parseDelay(text, minSeconds, maxSeconds)
    if type(text) == "number" then text = tostring(text) end
    if type(text) ~= "string" then return nil, "give a delay, e.g. 10 (minutes) or 90s" end
    local value, unit = text:lower():match("^%s*(%d+%.?%d*)%s*([sm]?)%s*$")
    value = tonumber(value)
    if value == nil then return nil, "'" .. text .. "' is not a delay (try 10, 2.5, 90s or 5m)" end
    local seconds = unit == "s" and value or value * 60
    local ms = math.floor(seconds * 1000 + 0.5)
    local low, high = number(minSeconds, 10), number(maxSeconds, 10800)
    if ms < low * 1000 then return nil, "the delay must be at least " .. P.formatRemaining(low) end
    if ms > high * 1000 then return nil, "the delay must be at most " .. P.formatRemaining(high) end
    return ms
end

--- "1 second", "45 seconds", "1 minute", "2 minutes 30 seconds".
function P.formatRemaining(seconds)
    seconds = math.max(0, math.floor(number(seconds, 0) + 0.5))
    local function unit(n, word) return n == 1 and ("1 " .. word) or (n .. " " .. word .. "s") end
    if seconds < 60 then return unit(seconds, "second") end
    local minutes, rest = math.floor(seconds / 60), seconds % 60
    if minutes >= 60 and minutes % 60 == 0 and rest == 0 then return unit(math.floor(minutes / 60), "hour") end
    if rest == 0 then return unit(minutes, "minute") end
    return unit(minutes, "minute") .. " " .. unit(rest, "second")
end

--- The countdown of a show `delayMs` away: `{ atMs, remaining, chat }` ordered
--- by time, `atMs` counted from the scheduling moment. The first announcement
--- (at 0) and the launch (at delayMs) are not part of it.
function P.countdown(delayMs, marks, options)
    options = options or {}
    delayMs = math.max(0, integer(delayMs, 0))
    local minGapMs = math.max(0, number(options.minGapSeconds, 5)) * 1000
    local chatFrom = number(options.chatFromSeconds, 30)
    local seen, list = {}, {}
    for _, mark in ipairs(type(marks) == "table" and marks or {}) do
        local seconds = math.floor(number(mark, 0))
        local remainingMs = seconds * 1000
        local atMs = delayMs - remainingMs
        if seconds > 0 and not seen[seconds] and remainingMs < delayMs and atMs >= minGapMs then
            seen[seconds] = true
            list[#list + 1] = { atMs = atMs, remaining = seconds, chat = seconds >= chatFrom }
        end
    end
    table.sort(list, function(a, b) return a.atMs < b.atMs end)
    return list
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

--- `{name}` placeholders; an unknown one is left as written.
function P.render(template, vars)
    vars = vars or {}
    return (tostring(template or ""):gsub("{(%w+)}", function(key)
        local value = vars[key]
        return value ~= nil and tostring(value) or ("{" .. key .. "}")
    end))
end

--- Control characters out, then at most `maxBytes` bytes, never cutting a UTF-8
--- sequence in half (the chat caps a line at 256 bytes, a banner at 384).
function P.clip(text, maxBytes)
    text = (tostring(text or ""):gsub("%c", " "))
    text = text:match("^%s*(.-)%s*$")
    maxBytes = math.max(0, integer(maxBytes, 240))
    if #text <= maxBytes then return text end
    local cut = maxBytes
    while cut > 0 do
        local nextByte = text:byte(cut + 1)
        if nextByte == nil or nextByte < 0x80 or nextByte >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end
