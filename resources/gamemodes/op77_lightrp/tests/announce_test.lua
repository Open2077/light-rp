-- Staff voice announcements (server/modules/announce.lua) with the host and the voice
-- authority stubbed: server-wide and radius casts, the audience following the speaker,
-- nobody hearing twice (the proximity voice), the halo told to everyone reached, the
-- audience cap, stop, the speaker leaving.
local threads = {}
local function tick()
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end

local positions, buckets = {}, {}
local sent = {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerName = function(id) return positions[id] and ("P" .. id) or nil end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.TriggerClientEvent = function(name, id, payload) sent[#sent + 1] = { name = name, id = id, payload = payload } end
_G.RegisterNetEvent = function() end

-- the voice authority: channels and memberships, the speaker's proximity reach
local channels, chanSeq, proximity = {}, 0, {}
_G.Open77 = {
    players = { position = function(id) return positions[id] end, get = function(id) return { position = positions[id] } end },
    voice = {
        status = function() return { defaultProximityDistance = 20 } end,
        getParticipant = function(id) return { playerId = id, proximity = { enabled = true, distance = proximity[id] or 20 } } end,
        createChannel = function(o) chanSeq = chanSeq + 1; channels[chanSeq] = { options = o, members = {} }; return { id = chanSeq } end,
        removeChannel = function(id) channels[id] = nil; return true end,
        addPlayer = function(id, player, perm)
            local c = channels[id]
            if not c then return false, "unknown_channel" end
            c.members[player] = { canSpeak = perm.canSpeak, canListen = perm.canListen }
            return true
        end,
        removePlayer = function(id, player) if channels[id] then channels[id].members[player] = nil end return true end,
    },
}

local notices, commands, modules = {}, {}, {}
_G.LightRP = {
    log = function(fmt, ...) if os.getenv("ANNOUNCE_TEST_LOG") then print(string.format(fmt, ...)) end end,
    module = function(name, def) modules[name] = def; return def end,
    command = function(name, _, fn) commands[name] = fn end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    characters = { isRegistered = function(id) return positions[id] ~= nil end, displayName = function(id) return "Player " .. id end },
}
dofile("server/config/announce.lua")
dofile("server/modules/announce.lua")
local A, C = LightRP.announce or modules.announce, LightRpAnnounce
local announce = commands["lightrp.broadcast"]

local function members(ch) local n = 0 for _ in pairs(channels[ch].members) do n = n + 1 end return n end
local function lastTo(id)
    local last
    for _, s in ipairs(sent) do if s.id == id and s.name == "op77_lightrp:announce" then last = s.payload end end
    return last
end

-- the staff member (1) at the origin; 2 next to them (proximity), 3 at 100 m, 4 at 400 m,
-- 5 at 100 m in another routing bucket
positions[1] = { x = 0, y = 0, z = 0 }
positions[2] = { x = 8, y = 0, z = 0 }
positions[3] = { x = 100, y = 0, z = 0 }
positions[4] = { x = 400, y = 0, z = 0 }
positions[5] = { x = 0, y = 100, z = 0 }; buckets[5] = 7

-- ── server-wide ──
assert(not announce(0, {}), "the console has no voice")
local ok, text = announce(1, {})
assert(ok and text:find("whole server"), tostring(text))
local ch = next(channels)
assert(channels[ch].options.mode == "admin" and channels[ch].options.persistent == false and channels[ch].options.effect.spatialBlend == 0, "a non-spatial admin channel")
assert(channels[ch].members[1].canSpeak and not channels[ch].members[1].canListen, "the speaker speaks, does not hear themself")
assert(not channels[ch].members[2], "within the proximity voice: no double voice")
assert(channels[ch].members[3] and channels[ch].members[4] and channels[ch].members[5], "everyone else, every bucket")
assert(channels[ch].members[3].canListen and not channels[ch].members[3].canSpeak, "the audience only listens")
for id = 2, 5 do assert(lastTo(id) and lastTo(id).active and lastTo(id).speaker == 1 and lastTo(id).mode == "server", "the halo for " .. id) end
local me = lastTo(1)
assert(me.active and me.self and me.audience == 4, "the speaker's own halo, 4 listening")

-- ── the speaker shouts: the proximity reach grows, 3 is within it now (no double voice) ──
proximity[1] = 120
tick()
assert(not channels[ch].members[3], "3 hears the proximity voice now")
assert(lastTo(3).active, "but still sees the halo")
-- back to normal: the hysteresis needs a real move to come back
proximity[1] = 20
tick()
assert(channels[ch].members[3], "3 back in the channel")

-- ── off, then a radius ──
assert(announce(1, { "off" }))
assert(channels[ch] == nil, "the channel removed")
for id = 1, 5 do assert(lastTo(id).active == false, "the halo goes for " .. id) end
assert(not announce(1, { "off" }), "not on air")

ok, text = announce(1, { "150" })
assert(ok and text:find("within 150 m"), tostring(text))
ch = next(channels)
assert(channels[ch].members[3] and not channels[ch].members[4], "4 is out of the radius")
assert(not channels[ch].members[5], "another bucket is out of reach in radius mode")
assert(lastTo(3).mode == "radius" and lastTo(3).radius == 150)
assert(lastTo(4) == nil or lastTo(4).active == false, "4 does not see it")

-- ── the speaker walks: the audience follows ──
positions[1] = { x = 300, y = 0, z = 0 }
tick()
assert(channels[ch].members[4] and not channels[ch].members[3], "4 in, 3 out (200 m away)")
assert(lastTo(4).active and lastTo(3).active == false, "the halo follows")
assert(lastTo(1).audience == 1, "the speaker's count updates")

-- ── the radius is clamped ──
assert(announce(1, { "1" }))
assert(lastTo(1).radius == C.minRadius)
assert(not announce(1, { "loud" }), "not a radius")

-- ── the cap ──
announce(1, { "off" })
positions[1] = { x = 0, y = 0, z = 0 }
for id = 10, 10 + C.maxAudience + 5 do positions[id] = { x = 500 + id, y = 0, z = 0 } end
announce(1, { "server" })
ch = next(channels)
assert(members(ch) == C.maxAudience + 1, "the audience capped (+ the speaker): " .. members(ch))
local capped
for _, n in ipairs(notices) do if n.id == 1 and n.body:find("More than") then capped = true end end
assert(capped, "the speaker is told")

-- ── a listener leaves, the speaker leaves ──
-- (the platform drops a disconnected player from every channel itself)
positions[3] = nil
modules.announce.onDisconnected(3)
assert(not modules.announce.casts()[1].members[3] and not modules.announce.casts()[1].told[3], "forgotten")
positions[1] = nil
modules.announce.onDisconnected(1)
assert(next(channels) == nil, "the speaker gone: the channel goes")
assert(lastTo(4).active == false, "and every halo")

print("PASS: announcements (server-wide + every bucket, admin channel speak/listen, no double voice by proximity with hysteresis, halo to everyone reached, off, radius + bucket, audience following the speaker, clamp, cap + notice, disconnects)")
