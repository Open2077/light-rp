-- Staff voice announcements.
--
--   /lightrp.broadcast            on air for the whole server (again: off)
--   /lightrp.broadcast <metres>   on air for everyone within that radius of you
--   /lightrp.broadcast off        off air
--
-- One "admin" voice channel per speaker (Open77.voice, non-spatial, a public-address
-- effect): the speaker may speak, the audience may listen. The audience follows the
-- speaker every refreshMs: whoever enters the radius joins, whoever leaves it goes.
-- Players already within the speaker's proximity voice stay out of the channel (they
-- hear the voice in 3D, never twice). The push-to-talk key is the usual one: the voice
-- host transmits with the "all" intent, so proximity and every speakable channel.
--
-- Every player reached (channel or proximity) is told who is on air (net event
-- op77_lightrp:announce); the client draws the halo from that speaker's voice level.
local C = LightRpAnnounce
local A = LightRP.module("announce", {})
local NET = "op77_lightrp:announce"

local casts = {}   -- speaker id -> cast

local function log(...) LightRP.log(...) end
local function bucketOf(id) return type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(id) or 0 end
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end
local function online()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and LightRP.characters.isRegistered(id) then list[#list + 1] = id end
    end
    return list
end
local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function count(set) local n = 0 for _ in pairs(set) do n = n + 1 end return n end

-- How far the speaker's own proximity voice carries (open-voice whisper/normal/shout).
local function proximityOf(id)
    local ok, p = pcall(Open77.voice.getParticipant, id)
    if ok and type(p) == "table" and type(p.proximity) == "table" then
        if p.proximity.enabled == false then return 0 end
        local d = tonumber(p.proximity.distance)
        if d then return d end
    end
    local okStatus, status = pcall(Open77.voice.status)
    return okStatus and type(status) == "table" and tonumber(status.defaultProximityDistance) or 20
end

local function view(cast, self)
    return { active = true, speaker = cast.speaker, name = cast.name, mode = cast.mode, radius = cast.radius,
        self = self == true, audience = cast.audience or 0 }
end
local function tell(id, payload) TriggerClientEvent(NET, id, payload) end

-- Who the cast reaches, and who of them needs the channel (beyond the proximity voice).
local function reach(cast)
    local targets = {}
    local here, bucket = positionOf(cast.speaker), bucketOf(cast.speaker)
    local near = proximityOf(cast.speaker)
    for _, id in ipairs(online()) do
        if id ~= cast.speaker then
            local p = positionOf(id)
            local d = (here and p and bucketOf(id) == bucket) and distance(here, p) or math.huge
            if cast.mode == "server" or d <= cast.radius then
                -- the hysteresis keeps a player at the proximity edge from flapping in and out
                local edge = cast.members[id] and (near - C.proximityHysteresis) or near
                targets[id] = { channel = d > edge }
            end
        end
    end
    return targets
end

local function refresh(cast)
    local targets = reach(cast)
    local audience = 0
    for id, t in pairs(targets) do
        local wanted = t.channel and audience < C.maxAudience
        if wanted then audience = audience + 1 end
        if wanted and not cast.members[id] then
            local ok, why = Open77.voice.addPlayer(cast.channel, id, { canSpeak = false, canListen = true })
            if ok then cast.members[id] = true
            elseif not cast.refused[id] then cast.refused[id] = true; log("announce: %d not added to the channel: %s", id, tostring(why)) end
        elseif not wanted and cast.members[id] then
            pcall(Open77.voice.removePlayer, cast.channel, id)
            cast.members[id] = nil
        end
    end
    for id in pairs(cast.members) do
        if not targets[id] then pcall(Open77.voice.removePlayer, cast.channel, id); cast.members[id] = nil end
    end
    cast.audience = count(targets)
    for id in pairs(targets) do
        if not cast.told[id] then cast.told[id] = true; tell(id, view(cast)) end
    end
    for id in pairs(cast.told) do
        if not targets[id] then cast.told[id] = nil; tell(id, { active = false, speaker = cast.speaker }) end
    end
    if audience >= C.maxAudience and not cast.capped then
        cast.capped = true
        LightRP.notice(cast.speaker, { kind = "warning", title = "ANNOUNCEMENT", durationMs = 8000,
            body = string.format("More than %d listeners: the farthest ones hear only your proximity voice.", C.maxAudience) })
    end
    if cast.lastAudience ~= cast.audience then
        cast.lastAudience = cast.audience
        tell(cast.speaker, view(cast, true))
    end
end

local function stop(speaker, why)
    local cast = casts[speaker]
    if not cast then return false end
    casts[speaker] = nil
    for id in pairs(cast.told) do tell(id, { active = false, speaker = speaker }) end
    if GetPlayerName(speaker) then tell(speaker, { active = false, speaker = speaker }) end
    pcall(Open77.voice.removeChannel, cast.channel)
    log("announce: %s off air (%s)", cast.name, tostring(why or "stopped"))
    return true
end
A.stop = stop

local function start(speaker, mode, radius)
    if casts[speaker] then stop(speaker, "restarted") end
    local channel, why = Open77.voice.createChannel({
        name = "Announcement " .. tostring(speaker), mode = "admin", persistent = false, effect = C.effect,
    })
    if not channel then return false, "The voice channel was refused: " .. tostring(why) end
    local ok, reason = Open77.voice.addPlayer(channel.id, speaker, { canSpeak = true, canListen = false })
    if not ok then
        pcall(Open77.voice.removeChannel, channel.id)
        return false, "You could not be put on air: " .. tostring(reason)
    end
    local cast = { speaker = speaker, name = LightRP.characters.displayName(speaker), mode = mode, radius = radius,
        channel = channel.id, members = {}, told = {}, refused = {}, audience = 0 }
    casts[speaker] = cast
    refresh(cast)
    tell(speaker, view(cast, true))
    log("announce: %s on air (%s%s), %d listener(s)", cast.name, mode, radius and (" " .. radius .. " m") or "", cast.audience)
    return true, string.format("On air %s, %d listener(s) now. Hold your push-to-talk key to speak; /lightrp.broadcast off to stop.",
        mode == "server" and "for the whole server" or ("within " .. radius .. " m"), cast.audience)
end
A.start = start
A.casts = function() return casts end

LightRP.command("lightrp.broadcast", { restricted = true, usage = "/lightrp.broadcast [server | <radius m> | off]" }, function(source, args)
    if not source or source <= 0 then return false, "In game only: the announcement carries your voice." end
    local arg = args[1] and string.lower(args[1]) or nil
    if arg == "off" or arg == "stop" or (arg == nil and casts[source]) then
        if stop(source, "command") then return true, "Announcement over." end
        return false, "You are not on air."
    end
    if arg == nil or arg == "server" or arg == "all" then return start(source, "server", nil) end
    local radius = tonumber(arg)
    if not radius then return false end
    radius = math.floor(math.max(C.minRadius, math.min(C.maxRadius, radius)) + 0.5)
    return start(source, "radius", radius)
end)

-- A player whose page reloads is told again on the next refresh.
function A.onUiReady(id)
    for _, cast in pairs(casts) do
        cast.told[id] = nil
        if cast.speaker == id then tell(id, view(cast, true)) end
    end
end

function A.onDisconnected(id)
    if casts[id] then stop(id, "disconnected") end
    for _, cast in pairs(casts) do cast.members[id], cast.told[id], cast.refused[id] = nil, nil, nil end
end

CreateThread(function()
    while true do
        Wait(C.refreshMs)
        for speaker, cast in pairs(casts) do
            if not GetPlayerName(speaker) then stop(speaker, "gone")
            else
                local ok, err = pcall(refresh, cast)
                if not ok then log("announce: refresh failed: %s", tostring(err)) end
            end
        end
    end
end)
