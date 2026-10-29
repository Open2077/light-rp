-- The raid on this client (server/modules/mission_chimera.lua runs it): the
-- ready key, the raid sounds and music, the strike telegraphs and the intro
-- cinematic. The page draws the rest (ui/src/features/missions/RaidHud.tsx)
-- from the same payloads.
--
-- The intro is seven shots cut on one camera, timed on the payload's
-- durationMs (the page cuts its flashes, scan and title card on the same
-- fractions, see INTRO_BEATS in RaidHud.tsx): the approach through the smoke,
-- two close-ups while the machine is scanned, the wake-up (shake, the game's
-- landing and EMP effects), a low orbit under the title card, a push-in under
-- its guns, then the view blends back to the player. The body is frozen and the
-- vanilla HUD hidden meanwhile; the music starts with the first shot.
local E = LightRpEvents
local KEY = LightRpConfig.keys.raidReady
local Raid = { state = nil }
LightRpRaidClient = Raid

local function now() return Open77.time.monotonic() end
local function log(fmt, ...) LightRpUi.log("raid: " .. fmt, ...) end
local function vec(x, y, z) return { x = x, y = y, z = z } end
local function lerp(a, b, t) return vec(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t) end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function smooth(t) t = clamp(t, 0, 1); return t * t * t * (t * (t * 6 - 15) + 10) end

-- ---------------------------------------------------------------------------
-- The game's volume sliders. Open77's audio is a second path to the speakers
-- that the game's settings do not reach (docs: wiki/sound.md), so the raid reads
-- Settings > Sound itself: music by Master and Music, sounds by Master and SFX,
-- on a square-root curve (the plain product of two low sliders, 5 x 5, was
-- inaudible). Until the first read lands it assumes half volume rather than full.

local mix = { master = 0.5, music = 0.5, sfx = 0.5, known = false }
local function readMix()
    if type(Open77.settings) ~= "table" or type(Open77.settings.request) ~= "function" then return end
    -- the pause menu reads its groups through the same reply buffer
    if Open77.session and type(Open77.session.isPauseMenuOpen) == "function" and Open77.session.isPauseMenuOpen() then return end
    local ok, requested = pcall(Open77.settings.request, "/audio/volume")
    if not ok or not requested then return end
    local values, previous = {}, -1
    for attempt = 1, 18 do
        Wait(60)
        values = Open77.settings.values() or {}
        if #values == previous and (#values > 0 or attempt >= 10) then break end
        previous = #values
    end
    local found = {}
    for _, e in ipairs(values) do
        if e.type ~= "meta" and type(e.name) == "string" and tonumber(e.value) then
            local top = (tonumber(e.max) or 0) > 0 and tonumber(e.max) or 100
            found[e.name] = clamp(tonumber(e.value) / top, 0, 1)
        end
    end
    if found.MasterVolume then
        mix.master, mix.music, mix.sfx = found.MasterVolume, found.MusicVolume or 1, found.SfxVolume or 1
        if not mix.known then log("game volume: master %.2f music %.2f sfx %.2f", mix.master, mix.music, mix.sfx) end
        mix.known = true
    elseif not mix.known then
        log("game volume unreadable (%d values)", #values)
    end
end
local function musicGain() return math.sqrt(mix.master * mix.music) end
local function sfxGain() return math.sqrt(mix.master * mix.sfx) end

-- ---------------------------------------------------------------------------
-- Sounds: one handle each, destroyed when done (16 handles per resource). They
-- sit under the game's mix: the guns and the machine carry the fight. The files
-- themselves are 12 dB down (and the music 20 dB): quiet even at volume 1.

local DURATION = { raid_ready = 1.0, raid_tick = 0.4, raid_alarm = 5.3, raid_reveal = 0.7, raid_title = 4.3, raid_phase = 1.4,
    raid_wave = 1.3, raid_enrage = 2.8, raid_victory = 5.5, raid_wipe = 8.2 }
local VOLUME = { raid_ready = 0.8, raid_tick = 0.56, raid_alarm = 0.64, raid_reveal = 1.0, raid_title = 0.96, raid_phase = 0.8,
    raid_wave = 0.72, raid_enrage = 0.96, raid_victory = 1.0, raid_wipe = 1.0 }
local playing = {}
local function play(name)
    if not DURATION[name] or type(Open77.audio) ~= "table" then return end
    if not mix.known and not mix.waited then
        -- the first raid sound waits (up to 1.5 s) for the game's sliders
        mix.waited = true
        CreateThread(function()
            local until_ = now() + 1.5
            while not mix.known and now() < until_ do Wait(50) end
            play(name)
        end)
        return
    end
    if playing[name] then pcall(Open77.audio.destroy, playing[name]); playing[name] = nil end
    local ok, id = pcall(Open77.audio.play2D, "assets/audio/" .. name .. ".wav", { volume = clamp((VOLUME[name] or 0.8) * sfxGain(), 0, 1) })
    if not ok or not id then return end
    playing[name] = id
    SetTimeout(math.floor(DURATION[name] * 1000) + 300, function()
        if playing[name] == id then pcall(Open77.audio.destroy, id); playing[name] = nil end
    end)
end

-- ---------------------------------------------------------------------------
-- The fight's music: looped, low, faded out at the end.

local music -- { id, volume, target, file }
local function setMusic(def)
    if def and type(def.file) == "string" then
        if music and music.file == def.file then music.target = def.volume or 0.35; return end
        if music then pcall(Open77.audio.destroy, music.id) end
        local level = def.volume or 0.35
        local ok, id = pcall(Open77.audio.play2D, def.file, { volume = clamp(level * musicGain(), 0, 1), loop = true })
        if not ok or not id then log("music refused: %s", tostring(id)); music = nil; return end
        music = { id = id, volume = level, target = level, file = def.file }
        -- the client log says what is actually playing (a loud music report = check this line)
        SetTimeout(2500, function()
            local ok2, st = pcall(Open77.audio.getState, id)
            if ok2 and type(st) == "table" then log("music %s volume=%s status=%s", def.file, tostring(st.volume), tostring(st.status)) end
        end)
    elseif music then
        music.target = 0
    end
end
CreateThread(function()
    while true do
        Wait(100)
        if music then
            local step = music.target > music.volume and 0.01 or -0.015
            if math.abs(music.target - music.volume) <= math.abs(step) then music.volume = music.target
            else music.volume = music.volume + step end
            if music.target == 0 and music.volume <= 0.02 then pcall(Open77.audio.destroy, music.id); music = nil
            else pcall(Open77.audio.setVolume, music.id, clamp(music.volume * musicGain(), 0, 1)) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The game's own effects, for this client only (the shared blasts are the
-- server's). A duration releases the handle when the effect is done.

local effects = {}
local function vfx(name, position, seconds)
    if type(Open77.vfx) ~= "table" then return end
    local ok, id = pcall(Open77.vfx.play, name, { position = position, duration = seconds or 6 })
    if not ok or not id then log("vfx %s refused: %s", name, tostring(id)); return end
    effects[id] = true
    SetTimeout(math.floor((seconds or 6) * 1000) + 500, function() effects[id] = nil end)
    return id
end

-- ---------------------------------------------------------------------------
-- Strikes: where the next blast lands. Three native 3D markers per spot -- the
-- zone's edge, a ring closing in on the centre and a translucent wall rising
-- with it -- over the game's own indicator. Barrage spots are red under the
-- missile-barrage indicator; the purge is cyan around the machine, charging
-- with the game's EMP, and its ring snaps outward when it discharges.

local STRIKE = {
    barrage = { color = { r = 255, g = 38, b = 48 }, wall = 1.5, indicator = "base\\fx\\quest\\q114\\q114_missile_barage_indicator.effect" },
    purge = { color = { r = 46, g = 230, b = 224 }, wall = 2.8, indicator = "electric.emp.big", release = 0.35 },
}
local strikes = {}
local animating = false

local function marker(options)
    if type(Open77.markers) ~= "table" then return nil end
    local ok, id = pcall(Open77.markers.create, options)
    if ok and id then return id end
    log("strike marker refused: %s", tostring(id))
end
local function update(id, patch) if id then pcall(Open77.markers.update, id, patch) end end
local function dropStrike(s)
    for _, id in pairs(s.markers) do pcall(Open77.markers.remove, id) end
    s.markers = {}
end

local function animate()
    if animating then return end
    animating = true
    CreateThread(function()
        while #strikes > 0 do
            local t = now()
            for i = #strikes, 1, -1 do
                local s = strikes[i]
                local k = (t - s.started) / s.total
                local m = s.markers
                if k < 1 then
                    -- closes in, slowly then fast: the last half-second is the warning
                    update(m.closing, { radius = math.max(0.1, s.radius * (1 - 0.94 * k ^ 1.6)) })
                    update(m.wall, { height = 0.05 + s.style.wall * k ^ 2.2 })
                elseif s.style.release and k < 1 + s.style.release / s.total then
                    -- the purge discharges: the ring snaps out past the edge, the wall drops
                    local r = (k - 1) * s.total / s.style.release
                    update(m.closing, { radius = s.radius * (0.1 + 1.15 * smooth(r)) })
                    update(m.wall, { height = math.max(0.02, s.style.wall * (1 - r)) })
                    if m.edge then pcall(Open77.markers.remove, m.edge); m.edge = nil end
                else
                    dropStrike(s)
                    table.remove(strikes, i)
                end
            end
            Wait(16)
        end
        animating = false
    end)
end

local function telegraph(list)
    if type(list) ~= "table" then return end
    for _, spot in ipairs(list) do
        local style = STRIKE[spot.kind] or STRIKE.barrage
        local r = tonumber(spot.radius) or 4
        local ground = vec(spot.x, spot.y, spot.z + 0.05)
        local c = style.color
        local s = { started = now(), total = math.max(0.3, (tonumber(spot.delayMs) or 2000) / 1000), radius = r, style = style, markers = {} }
        s.markers.edge = marker({ position = ground, shape = "ring", radius = r, color = { r = c.r, g = c.g, b = c.b, a = 235 }, maxDistance = 180 })
        s.markers.closing = marker({ position = ground, shape = "ring", radius = r, color = { r = c.r, g = c.g, b = c.b, a = 255 }, maxDistance = 180 })
        s.markers.wall = marker({ position = ground, shape = "cylinder", radius = r, height = 0.05,
            color = { r = c.r, g = c.g, b = c.b, a = 70 }, maxDistance = 180 })
        vfx(style.indicator, vec(spot.x, spot.y, spot.z), s.total + 0.3)
        strikes[#strikes + 1] = s
    end
    animate()
end

-- ---------------------------------------------------------------------------
-- The intro cinematic

-- Fractions of the intro: keep INTRO_BEATS in RaidHud.tsx on the same numbers.
local CUT = { closeLow = 0.18, closeHigh = 0.27, wake = 0.36, orbit = 0.40, push = 0.72, out = 0.93 }
local LANDING = "base\\fx\\quest\\q113\\q113_smasher\\q113_smasher_land_effect.effect"

local intro -- { camera, started, duration, boss, f, s, frozen, hud, beats }

local function endIntro(blend)
    if not intro then return end
    local s = intro
    intro = nil
    if s.camera then
        local released = blend and type(Open77.camera.deactivate) == "function" and Open77.camera.deactivate({ blendMs = 900 })
        if released then SetTimeout(1000, function() pcall(Open77.camera.destroy, s.camera) end)
        else pcall(Open77.camera.destroy, s.camera) end
    end
    if s.frozen then Open77.character.setFrozen(false) end
    if s.hud then if LightRpHud then LightRpHud.restoreVanilla() else Open77.hud.setVisible("all", true) end end
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:raid", false)
end

-- Around the boss: `fwd` metres along the squad->boss axis, `side` across it, `up` above its feet.
local function at(s, fwd, side, up)
    local b = s.boss
    return vec(b.x + s.f.x * fwd + s.s.x * side, b.y + s.f.y * fwd + s.s.y * side, b.z + up)
end

-- Where the camera is, what it looks at and its field of view at fraction u.
local function shot(s, u)
    local b = s.boss
    if u < CUT.closeLow then
        -- the approach: low behind the squad, through the smoke
        local k = smooth(u / CUT.closeLow)
        return lerp(at(s, -26, 4, 1.4), at(s, -19, 3, 1.7), k), vec(b.x, b.y, b.z + 3.0), 42 - 3 * k
    elseif u < CUT.closeHigh then
        -- close-up, the hull: a slow slide along it
        local k = (u - CUT.closeLow) / (CUT.closeHigh - CUT.closeLow)
        return lerp(at(s, -3, 5.5, 0.7), at(s, -2.2, 4.2, 0.9), k), at(s, 0, 0, 1.4 + 0.4 * k), 30
    elseif u < CUT.wake then
        -- close-up, the guns, from the other side and above
        local k = (u - CUT.closeHigh) / (CUT.wake - CUT.closeHigh)
        return lerp(at(s, -4.6, -5.2, 4.3), at(s, -4.0, -4.4, 4.0), k), at(s, 0, 0, 3.5), 26
    elseif u < CUT.orbit then
        -- it wakes up: wide and low, the lens punches in
        local k = (u - CUT.wake) / (CUT.orbit - CUT.wake)
        return at(s, -13, -2, 0.45), at(s, 0, 0, 3.8), 64 - 12 * smooth(k)
    elseif u < CUT.push then
        -- a fast low orbit, looking up at it
        local k = smooth((u - CUT.orbit) / (CUT.push - CUT.orbit))
        local base = math.atan(-s.f.y, -s.f.x) - 1.1
        local a, r = base + 2.2 * k, 11 - 2 * k
        return vec(b.x + math.cos(a) * r, b.y + math.sin(a) * r, b.z + 1.0 + 0.4 * k), vec(b.x, b.y, b.z + 3.2), 52 - 4 * k
    else
        -- push in under its guns
        local k = smooth((u - CUT.push) / (CUT.out - CUT.push))
        return lerp(at(s, -9, 2.5, 0.8), at(s, -5.6, 1.6, 0.7), k), at(s, 0, 0, 3.8 + 0.6 * k), 48 - 10 * k
    end
end

-- What happens on the timeline besides the camera: shakes, effects, sounds.
local function beats(s)
    local b = s.boss
    local function on(p) return vec(b.x, b.y, b.z + p) end
    return {
        { at = 0.0, run = function() vfx("smoke.exterior", at(s, -12, 1, 0), s.duration + 4) end },
        { at = 0.19, run = function() vfx("sparks.burst.small", at(s, -1.2, 1.6, 1.6), 3) end },
        { at = 0.24, run = function() vfx("sparks.burst.small", at(s, -1.0, 2.2, 0.9), 3) end },
        { at = 0.28, run = function() vfx("electric.arc", on(3.2), 3) end },
        { at = CUT.wake, run = function()
            pcall(Open77.camera.shake, s.camera, "explosion", 2.2, 700)
            pcall(Open77.camera.shake, s.camera, "earthquake", 0.9, 2200)
            vfx(LANDING, on(0), 5); vfx("cyber.emp_blast", on(1.6), 4); vfx("sparks.burst.large", on(3.0), 4)
            play("raid_reveal")
        end },
        { at = 0.55, run = function() vfx("sparks.burst.small", at(s, 1.4, -1.8, 2.6), 3) end },
        { at = 0.86, run = function()
            pcall(Open77.camera.shake, s.camera, "explosion", 1.4, 600)
            vfx("sparks.burst.large", on(3.6), 4); vfx("cyber.emp_blast", on(2.4), 4)
            play("raid_reveal")
        end },
    }
end

local function startIntro(data)
    endIntro(false)
    if type(data) ~= "table" or type(data.boss) ~= "table" then return end
    local b = data.boss
    -- the axis the shots are built on: from the squad to the machine. Operators
    -- standing next to it give no direction, so the arena's entrance does.
    local me = Open77.character.state()
    local from = me and me.position
    if not from or (from.x - b.x) ^ 2 + (from.y - b.y) ^ 2 < 64 then from = data.entry or data.arena end
    if not from then return end
    local dx, dy = b.x - from.x, b.y - from.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then dx, dy, d = 0, 1, 1 end
    local s = { started = now(), duration = math.max(4, (tonumber(data.durationMs) or 12000) / 1000), boss = b,
        f = vec(dx / d, dy / d, 0), s = vec(-dy / d, dx / d, 0) }
    local position, look, fov = shot(s, 0)
    local id, why = Open77.camera.create({ position = position, lookAt = look, fov = fov, thirdPersonBody = true })
    if not id then log("intro camera refused: %s", tostring(why)); return end
    if not Open77.camera.activate(id, { blendMs = 500 }) then Open77.camera.destroy(id); return end
    s.camera = id
    s.beats = beats(s)
    s.frozen = Open77.character.setFrozen(true) == true
    s.hud = Open77.hud.setVisible("all", false) == true
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:raid", true)
    intro = s
    CreateThread(function()
        while intro == s do
            local u = (now() - s.started) / s.duration
            if u >= 1 then endIntro(true); break end
            local p, l, f = shot(s, u)
            Open77.camera.setTransform(s.camera, { position = p, fov = f })
            Open77.camera.lookAt(s.camera, l)
            for _, beat in ipairs(s.beats) do
                if not beat.done and u >= beat.at then beat.done = true; pcall(beat.run) end
            end
            Wait(0)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- From the server

-- "Loaded": the loading screen is gone and the body has stood in the arena for
-- three seconds. Sent until the server's view says so (it checks the position);
-- until then the ready check keeps this operator out and hands out no weapon.
local loadReporter = false
local function arenaReady()
    if Open77.screen and type(Open77.screen.isLoading) == "function" then
        local ok, loading = pcall(Open77.screen.isLoading)
        if ok and loading == true then return false end
    end
    local me = Open77.character.state()
    if not me or not me.alive or not me.attached or not me.position then return false end
    local a = Raid.state and Raid.state.arena
    return not a or (me.position.x - a.x) ^ 2 + (me.position.y - a.y) ^ 2 <= 80 * 80
end
local function reportLoaded()
    if loadReporter then return end
    loadReporter = true
    CreateThread(function()
        local since, sent
        while Raid.state and Raid.state.loaded == false do
            if arenaReady() then
                since = since or now()
                if now() - since >= 3 and (not sent or now() - sent >= 2) then sent = now(); TriggerServerEvent(E.net.raidLoaded) end
            else
                since = nil
            end
            Wait(250)
        end
        loadReporter = false
    end)
end

-- The local player's shots on the Chimera: the engine prices its body near zero,
-- the raid prices each confirmed hit server-side (LightRpRaid.bodyHits).
local lastHit = 0
AddEventHandler("open77:npcHit", function(npcId)
    local s = Raid.state
    if not s or s.phase ~= "fight" or not s.bossId or tostring(npcId) ~= s.bossId then return end
    local t = now()
    if t - lastHit < 0.03 then return end -- a shotgun's pellets in one frame count once per frame
    lastHit = t
    TriggerServerEvent(E.net.raidHit, s.bossId)
end)

local mixReader = false
local function followMix()
    if mixReader then return end
    mixReader = true
    CreateThread(function()
        while Raid.state do
            readMix()
            Wait(10000)
        end
        mixReader = false
    end)
end

RegisterNetEvent(E.net.raid, function(payload)
    if type(payload) ~= "table" then return end
    if payload.phase == "ended" then
        endIntro(true)
        setMusic(nil)
        Raid.state = nil
        LightRpUi.send(E.page.raid, { phase = "ended", result = payload.result })
        return
    end
    Raid.state = payload
    followMix()
    if payload.loaded == false then reportLoaded() end
    if payload.sound then play(payload.sound) end
    if payload.intro then startIntro(payload.intro) end
    if payload.strikes then telegraph(payload.strikes) end
    setMusic(payload.music)
    if payload.phase == "fight" and intro then endIntro(true) end
    LightRpUi.send(E.page.raid, payload)
end)

local ok, effective = pcall(RegisterKeyMapping, KEY.id, KEY.name, KEY.key, function()
    if Raid.state and Raid.state.phase == "ready" and Raid.state.loaded ~= false then TriggerServerEvent(E.net.raidReady) end
end)
if not ok then log("ready key refused: %s", tostring(effective)) end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    TriggerServerEvent(E.net.raidHello)
    -- know the game's sliders before any raid sound
    CreateThread(function() Wait(5000); readMix() end)
end)
AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    endIntro(false)
    for _, id in pairs(playing) do pcall(Open77.audio.destroy, id) end
    if music then pcall(Open77.audio.destroy, music.id) end
    for _, s in ipairs(strikes) do dropStrike(s) end
    strikes = {}
    for id in pairs(effects) do pcall(Open77.vfx.stop, id) end
end)
