-- op77_fireworks: the planning logic, then the server against a stubbed host on a
-- virtual clock. Run from anywhere:
--   pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll>
local realPrint, load_file = print, dofile
-- The resource sandbox has no os/io/require: make a use of them fail here too.
os, io, require = nil, nil, nil

local function check(condition, message)
    if not condition then error(message or "check failed", 2) end
end

load_file("server/config.lua")
load_file("server/plan.lua")
-- Reassigned by boot(): every boot reloads the configuration the server reads.
local P, C, B = FireworksPlan, FireworksConfig, FireworksConfig.budget

-- ── expand ──
do
    local beats = P.expand({
        { at = 1000, count = 3, spreadMs = 200, sound = true },
        { at = 1000, effect = "confetti", count = 2, spreadMs = 0 },
        { at = 0, sound = "custom_event" },
        { at = 500, count = 2, spreadMs = 100, sound = false },
    }, "boom")
    local ats, sounds = {}, {}
    for i, b in ipairs(beats) do ats[i] = b.at; sounds[i] = tostring(b.sound) end
    check(table.concat(ats, ",") == "0,500,600,1000,1000,1000,1200,1400", table.concat(ats, ","))
    check(beats[1].sound == "custom_event" and beats[2].sound == nil and beats[3].sound == nil)
    check(beats[4].cue == 1 and beats[4].copy == 1 and beats[4].sound == "boom", "stable order on a shared beat")
    check(beats[5].cue == 2 and beats[6].cue == 2 and beats[5].sound == nil, "an effect cue without `sound` is silent")
    check(beats[7].sound == nil and beats[8].sound == nil, "only the first copy booms")
    check(#P.expand({ { count = 1e9 } }) == 200, "a cue's count is capped")
    check(#P.expand(nil) == 0 and #P.expand({ "junk" }) == 0)
    realPrint("PASS expand")
end

-- ── slice ──
do
    local cues = { { at = 0, count = 20, spreadMs = 0 } }
    local beats = P.slice(P.expand(cues), 8, 60)
    local per = {}
    for i, b in ipairs(beats) do
        per[b.at] = (per[b.at] or 0) + 1
        check(i == 1 or b.copy > beats[i - 1].copy, "order kept")
    end
    check(per[0] == 8 and per[60] == 8 and per[120] == 4, "8/8/4")
    -- a late beat inside a full slice moves to the next one, never earlier
    beats = P.slice(P.expand({ { at = 0, count = 8 }, { at = 30 } }), 8, 60)
    check(beats[9].at == 60, "full slice pushes the extra to the next slice: " .. beats[9].at)
    beats = P.slice(P.expand({ { at = 0, count = 3 }, { at = 30 } }), 8, 60)
    check(beats[4].at == 30, "a beat that fits is not moved")
    realPrint("PASS slice")
end

-- ── budget ──
do
    local dense = P.expand({ { at = 0, count = 100, spreadMs = 50 } }) -- 20 shells a second
    local kept, dropped = P.budget(dense, 60, 10000)
    check(#kept + dropped == 100 and dropped > 0, "an over-dense show is thinned")
    check(P.peakLive(kept, 10000) <= 60, "never more than maxLive alive: " .. P.peakLive(kept, 10000))
    check(P.peakLive(dense, 10000) == 100)
    local sparse = P.expand({ { at = 0, count = 30, spreadMs = 1000 } })
    local keptSparse, droppedSparse = P.budget(sparse, 12, 10000)
    check(droppedSparse == 0 and #keptSparse == 30, "a shell frees its slot when it expires")
    realPrint("PASS budget")
end

-- ── every shipped preset fits the budget untouched ──
do
    for name, cues in pairs(C.shows) do
        local raw = P.expand(cues, C.sound)
        local beats, dropped, duration = P.build(cues, C)
        check(dropped == 0, name .. ": thinned " .. dropped)
        check(#beats == #raw, name .. ": every beat kept")
        check(P.peakLive(beats, B.shellLifeMs) <= B.maxLive, name .. ": peak " .. P.peakLive(beats, B.shellLifeMs))
        local per = {}
        for _, b in ipairs(beats) do
            per[b.at] = (per[b.at] or 0) + 1
            check(per[b.at] <= B.sliceSize, name .. ": slice overflow at " .. b.at)
            check(b.def.effect == nil or C.effects[b.def.effect] ~= nil, name .. ": unknown effect " .. tostring(b.def.effect))
        end
        check(duration > 0 and duration < 60000, name .. ": duration " .. duration)
        local booms = 0
        for _, b in ipairs(beats) do if b.sound then booms = booms + 1 end end
        realPrint(("  %-12s %3d shells, %5.1f s, peak %d alive, %d one-shot booms"):format(name, #beats,
            duration / 1000, P.peakLive(beats, B.shellLifeMs), booms))
    end
    check(C.shows.burst and C.shows.finale, "a short burst and a finale ship")
    realPrint("PASS presets")
end

-- ── countdown ──
do
    local S = C.schedule
    local function marks(delayMs)
        local out = {}
        for i, m in ipairs(P.countdown(delayMs, S.marks, S)) do out[i] = m.remaining .. (m.chat and "c" or "") end
        return table.concat(out, ",")
    end
    check(marks(600000) == "300c,120c,60c,30c,10,5,4,3,2,1", marks(600000))
    check(marks(120000) == "60c,30c,10,5,4,3,2,1", marks(120000))
    check(marks(12000) == "5,4,3,2,1", "10 s would land 2 s after the first banner: " .. marks(12000))
    check(marks(62000) == "30c,10,5,4,3,2,1", "60 s would land 2 s after the first banner: " .. marks(62000))
    local list = P.countdown(600000, S.marks, S)
    for i = 2, #list do check(list[i].atMs > list[i - 1].atMs, "ascending") end
    check(list[1].atMs == 300000 and list[#list].atMs == 599000)
    check(#P.countdown(600000, { 60, 60, 0, -5 }, S) == 1, "duplicates and junk ignored")
    realPrint("PASS countdown")
end

-- ── delays and time ──
do
    local lo, hi = C.schedule.minSeconds, C.schedule.maxSeconds
    check(P.parseDelay("10", lo, hi) == 600000)
    check(P.parseDelay("2.5", lo, hi) == 150000)
    check(P.parseDelay("90s", lo, hi) == 90000)
    check(P.parseDelay(" 5M ", lo, hi) == 300000)
    check(P.parseDelay(30, lo, hi) == 1800000, "a number is minutes")
    check(P.parseDelay("5s", lo, hi) == nil, "under the minimum")
    check(P.parseDelay("181m", lo, hi) == nil, "over the maximum")
    local none, why = P.parseDelay("soon", lo, hi)
    check(none == nil and why:find("not a delay"), why)
    check(P.parseDelay(nil, lo, hi) == nil and P.parseDelay("-5", lo, hi) == nil and P.parseDelay("1e9", lo, hi) == nil)
    check(P.formatRemaining(1) == "1 second" and P.formatRemaining(45) == "45 seconds")
    check(P.formatRemaining(60) == "1 minute" and P.formatRemaining(90) == "1 minute 30 seconds")
    check(P.formatRemaining(600) == "10 minutes" and P.formatRemaining(7200) == "2 hours")
    check(P.formatRemaining(59.6) == "1 minute" and P.formatRemaining(-3) == "0 seconds")
    realPrint("PASS delays")
end

-- ── text ──
do
    check(P.render("Over {place} in {time}.", { place = "The Crossing", time = "5 minutes" }) == "Over The Crossing in 5 minutes.")
    check(P.render("{unknown} {place}", { place = "x" }) == "{unknown} x")
    check(P.render(nil, {}) == "")
    check(P.clip("  a\nb\tc  ", 10) == "a b c", "control characters out, trimmed")
    check(P.clip(("x"):rep(300), 240) == ("x"):rep(240))
    local accented = ("\195\169"):rep(10) -- "é" x10, 20 bytes
    check(P.clip(accented, 5) == ("\195\169"):rep(2), "never half a UTF-8 sequence")
    check(P.clip(accented, 6) == ("\195\169"):rep(3))
    check(P.clip(nil, 10) == "")
    realPrint("PASS text")
end

-- ── placement ──
do
    math.randomseed(77)
    local centre = { x = 100.0, y = -50.0, z = 20.0 }
    local last, cleared = nil, 0
    for _ = 1, 200 do
        local p = P.point({}, centre, last, C, math.random)
        local dx, dy = p.x - centre.x, p.y - centre.y
        check(dx * dx + dy * dy <= C.radius * C.radius + 1e-6, "inside the radius")
        check(p.z >= centre.z + C.minHeight - 1e-6 and p.z <= centre.z + C.maxHeight + 1e-6, "inside the height band")
        if last then
            local ex, ey, ez = p.x - last.x, p.y - last.y, p.z - last.z
            if ex * ex + ey * ey + ez * ez >= C.minSeparation * C.minSeparation then cleared = cleared + 1 end
        end
        last = p
    end
    check(cleared >= 190, "consecutive shells clear each other: " .. cleared)
    local low = P.point({ radius = 5, minHeight = 6, maxHeight = 9 }, centre, nil, C, math.random)
    check(low.z >= 26 and low.z <= 29, "a cue's own geometry wins")
    local seen, previous = {}, nil
    for _ = 1, 200 do
        local s = P.nextShell(C.shells, previous, math.random)
        check(s ~= previous, "never the same shell twice in a row")
        seen[s], previous = true, s
    end
    local kinds = 0
    for _ in pairs(seen) do kinds = kinds + 1 end
    check(kinds == #C.shells, "every shell is used")
    check(P.nextShell({ "one" }, "one", math.random) == "one" and P.nextShell({}, nil, math.random) == nil)
    local ahead = P.offset({ x = 0, y = 0, z = 5 }, 0, 10)
    check(math.abs(ahead.x) < 1e-9 and math.abs(ahead.y - 10) < 1e-9 and ahead.z == 5, "yaw 0 faces +Y")
    local left = P.offset({ x = 0, y = 0, z = 5 }, 90, 10)
    check(math.abs(left.x + 10) < 1e-9 and math.abs(left.y) < 1e-9, "yaw 90 faces -X")
    check(P.bucket(0) == 0 and P.bucket("3") == 3 and P.bucket(-1) == nil and P.bucket(1.5) == nil and P.bucket(nil) == nil)
    local key, place = P.find(C.places, "CROSSING")
    check(key == "crossing" and place.bucket == 0 and P.find(C.places, "nowhere") == nil)
    check(math.abs(place.x + 756.581) < 1e-9 and math.abs(place.y - 777.257) < 1e-9, "the hub is spawn.afterTutorial")
    realPrint("PASS placement")
end

-- ===========================================================================
-- The server, on a virtual clock
-- ===========================================================================

local clock, tasks, hitchMs = 1000000, {}, 0
local plays, chats, toasts, results, events, logs = {}, {}, {}, {}, {}, {}
local commands, exported, handlers, positions, toastIds = {}, {}, {}, {}, {}
local playResult, playReason, cleared = true, nil, 0

local function reset()
    clock, tasks, hitchMs = 1000000, {}, 0
    plays, chats, toasts, results, events, logs = {}, {}, {}, {}, {}, {}
    commands, exported, handlers, toastIds = {}, {}, {}, {}
    playResult, playReason, cleared = true, nil, 0
end

function CreateThread(fn) tasks[#tasks + 1] = { co = coroutine.create(fn), wake = clock } end
function Wait(ms)
    check(coroutine.isyieldable(), "Wait outside a thread")
    check(type(ms) == "number" and ms >= 0, "bad wait")
    coroutine.yield(ms)
end
-- Run every thread due before `ms` from now, in wake order. `hitchMs` makes the
-- next resume late, like a server stall.
local function advance(ms)
    local target = clock + ms
    while true do
        local due
        for _, t in ipairs(tasks) do
            if not t.dead and t.wake <= target and (due == nil or t.wake < due.wake) then due = t end
        end
        if due == nil then break end
        clock = math.max(clock, due.wake) + hitchMs
        hitchMs = 0
        local ok, waited = coroutine.resume(due.co)
        check(ok, tostring(waited))
        if coroutine.status(due.co) == "dead" then due.dead = true else due.wake = clock + waited end
    end
    clock = math.max(clock, target)
end

function GetCurrentResourceName() return "op77_fireworks" end
function RegisterCommand(name, fn, restricted) commands[name] = { fn = fn, restricted = restricted } end
function exports(name, fn) exported[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function TriggerClientEvent(name, target, raw, ok, text)
    results[#results + 1] = { name = name, target = target, ok = ok, text = text }
    return true
end
function TriggerEvent(name, payload) events[#events + 1] = { name = name, payload = payload }; return true end
print = function(line) logs[#logs + 1] = line end

Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    players = { position = function(id) return positions[id] end },
    effects = {
        play = function(effect, options)
            plays[#plays + 1] = { kind = "oneshot", effect = effect, options = options, at = clock }
            return playResult, playReason
        end,
        create = function(definition)
            plays[#plays + 1] = { kind = "registry", effect = definition.effect, options = definition, at = clock }
            if not playResult then return nil, playReason end
            return tostring(#plays)
        end,
    },
    chat = {
        broadcast = function(message)
            check(type(message) == "table" and #message.text <= 256 and #message.title <= 96, "chat row shape")
            chats[#chats + 1] = message
            return true
        end,
    },
    notifications = {
        -- Mirrors the prelude: an id may only be reused with `replace`.
        broadcast = function(definition)
            check(type(definition.message) == "string" and #definition.message <= 384, "banner body")
            check(definition.title == nil or #definition.title <= 96, "banner title")
            check(definition.durationMs >= 750 and definition.durationMs <= 120000, "banner duration")
            if definition.id ~= nil then
                check(definition.id:match("^[%w_:%-%.]+$") ~= nil, "banner id")
                if toastIds[definition.id] and definition.replace ~= true then return nil, "duplicate_notification_id" end
                toastIds[definition.id] = true
            end
            toasts[#toasts + 1] = definition
            return definition.id or ("n" .. #toasts)
        end,
        dismiss = function(id) toastIds[id] = nil; return true end,
        clear = function() cleared = cleared + 1; toastIds = {}; return true end,
    },
}

local CROSSING = { x = -756.581, y = 777.257, z = 22.454 }
local function boot()
    reset()
    positions = {
        [1] = { x = 10.0, y = 20.0, z = 30.0, bucket = 0 },
        [2] = { x = 500.0, y = -200.0, z = 15.0, bucket = 7 },
    }
    load_file("server/config.lua")
    load_file("server/plan.lua")
    P, C, B = FireworksPlan, FireworksConfig, FireworksConfig.budget
    load_file("server/main.lua")
end
local function run(source, line)
    local args = {}
    for word in line:gmatch("%S+") do args[#args + 1] = word end
    commands.fireworks.fn(source, args, "fireworks " .. line)
    return results[#results]
end
local function lastLog() return logs[#logs] or "" end
local function reply(source, line)
    local before = #results
    run(source, line)
    if source == 0 then return { ok = nil, text = lastLog() } end
    check(#results == before + 1, "one answer per command")
    return results[#results]
end
local function maxPerTick()
    local per, peak = {}, 0
    for _, p in ipairs(plays) do per[p.at] = (per[p.at] or 0) + 1; peak = math.max(peak, per[p.at]) end
    return peak
end
local function beatsOf(name) local b = P.build(C.shows[name], C); return #b end

-- ── loading ──
do
    boot()
    check(commands.fireworks and commands.fireworks.restricted == true, "the command is ACL-restricted")
    for _, name in ipairs({ "play", "playFor", "schedule", "opening", "announce", "stop", "status" }) do
        check(type(exported[name]) == "function", "export " .. name)
    end
    check(type(handlers.onResourceStop) == "function")
    check(#plays == 0 and #chats == 0 and #toasts == 0, "loading fires and announces nothing")
    realPrint("PASS server: load")
end

-- ── a show at the hub ──
do
    boot()
    local answer = reply(1, "burst crossing")
    check(answer.ok and answer.text:find("The Crossing") and answer.text:find("bucket 0"), answer.text)
    check(#plays == 1, "the first shell is fired synchronously")
    advance(30000)
    check(#plays == beatsOf("burst"), "every shell fired: " .. #plays)
    local booms = 0
    for _, p in ipairs(plays) do
        local o = p.options
        check(o.bucket == 0, "bucket 0")
        local dx, dy = o.position.x - CROSSING.x, o.position.y - CROSSING.y
        check(dx * dx + dy * dy <= 40.0 * 40.0 + 1e-6, "over the hub")
        check(o.position.z >= CROSSING.z + 9.0 and o.position.z <= CROSSING.z + 45.0)
        if p.kind == "oneshot" then
            booms = booms + 1
            check(o.sound == C.sound and o.range == 500.0, "a one-shot carries the boom, broadcast range")
        else
            check(o.ttlMs == C.budget.shellLifeMs and o.streamingRadius == 400.0 and o.sound == nil,
                "a silent shell is a registry entry the server retires")
        end
    end
    check(booms == 3, "only the boom shells are one-shots: " .. booms)
    check(maxPerTick() <= C.budget.sliceSize, "sliced: " .. maxPerTick())
    check(exported.status().show == nil, "the show ends on its own")

    -- the rp_fireworks behaviour, one config switch away
    boot()
    C.shellMode = "oneshot"
    reply(1, "burst crossing")
    advance(30000)
    booms = 0
    for _, p in ipairs(plays) do
        check(p.kind == "oneshot" and p.options.range == 500.0, "every shell a one-shot")
        if p.options.sound then booms = booms + 1 end
    end
    check(#plays == beatsOf("burst") and booms == 3, "the boom only on the cues that ask for it")
    realPrint("PASS server: show at a place (registry and oneshot modes)")
end

-- ── here, console, unknowns, refusals ──
do
    boot()
    check(reply(2, "celebration").ok, "a player's default place is here")
    advance(20000)
    check(#plays == beatsOf("celebration"))
    for _, p in ipairs(plays) do
        check(p.options.bucket == 7, "the caller's bucket")
        local dx, dy = p.options.position.x - 500.0, p.options.position.y + 200.0
        check(dx * dx + dy * dy <= 7.0 * 7.0 + 1e-6, "over the caller")
    end
    plays = {}
    check(reply(1, "here").ok and plays[1].options.bucket == 0, "a lone place argument takes the default show")
    advance(30000); plays = {}
    run(0, "burst")
    check(#plays == 1 and plays[1].options.bucket == 0, "the console's default is the hub")
    advance(30000); plays = {}
    run(0, "burst here")
    check(#plays == 0 and lastLog():find("console has no position"), lastLog())
    local bad = reply(1, "nope crossing")
    check(not bad.ok and bad.text:find("no show called") and bad.text:find("finale"), bad.text)
    bad = reply(1, "burst atlantis")
    check(not bad.ok and bad.text:find("unknown place") and bad.text:find("crossing"), bad.text)
    positions[1] = nil
    bad = reply(1, "burst")
    check(not bad.ok and bad.text:find("position is not known"), bad.text)
    playResult, playReason = false, "quota_exceeded"
    bad = reply(2, "burst crossing")
    check(not bad.ok and bad.text:find("quota_exceeded"), bad.text)
    advance(30000)
    check(#plays == 1 and exported.status().show == nil, "a refused opening beat starts nothing")
    plays = {}
    bad = reply(2, "celebration crossing")
    check(plays[1].kind == "registry" and not bad.ok and bad.text:find("quota_exceeded"), "a refused registry shell too")
    advance(30000)
    check(#plays == 1)
    realPrint("PASS server: here, console, refusals")
end

-- ── stop and replace ──
do
    boot()
    reply(1, "finale crossing")
    advance(5000)
    local fired = #plays
    check(fired > 1 and fired < beatsOf("finale"))
    local stopped = reply(1, "stop")
    check(stopped.ok and stopped.text:find("Show stopped"), stopped.text)
    advance(60000)
    check(#plays == fired, "nothing after stop")
    check(not reply(1, "stop").ok, "nothing left to stop")

    plays = {}
    reply(1, "burst crossing")
    advance(2000)
    local burstFired = #plays
    reply(1, "celebration crossing")
    advance(30000)
    check(#plays == burstFired + beatsOf("celebration"), "a new show replaces the running one")
    realPrint("PASS server: stop, replace")
end

-- ── a server stall never bunches the catch-up into one tick ──
do
    boot()
    reply(1, "finale crossing")
    advance(1000)
    hitchMs = 6000
    advance(60000)
    check(#plays == beatsOf("finale"), "all shells still fire")
    check(maxPerTick() <= C.budget.sliceSize, "catch-up sliced: " .. maxPerTick())
    realPrint("PASS server: stall")
end

-- ── schedule with countdown ──
do
    boot()
    local answer = reply(1, "in 2 burst crossing")
    check(answer.ok and answer.text:find("2 minutes") and answer.text:find("8 countdown"), answer.text)
    check(#chats == 1 and chats[1].type == "announcement" and chats[1].text == "Fireworks over The Crossing in 2 minutes.", chats[1] and chats[1].text)
    check(#toasts == 1 and toasts[1].id == "op77_fireworks_countdown" and toasts[1].position == "top_center")
    advance(60000)
    check(#chats == 2 and chats[2].text:find("in 1 minute%."), chats[2].text)
    advance(30000)
    check(#chats == 3 and chats[3].text:find("in 30 seconds"), chats[3].text)
    advance(29500)
    check(#plays == 0 and #chats == 3, "the final seconds tick the banner only")
    check(#toasts == 9, "one banner per mark: " .. #toasts)
    for _, t in ipairs(toasts) do check(t.id == "op77_fireworks_countdown", "one banner, updated in place") end
    for i = 2, #toasts do check(toasts[i].replace == true) end
    check(toasts[9].message:find("in 1 second"), toasts[9].message)
    local s = exported.status()
    check(s.pending and s.pending.show == "burst" and s.pending.inMs == 500, "status sees the pending show")
    advance(1000)
    check(#plays >= 1 and #chats == 4 and chats[4].text:find("Look up"), "launch line + first shell")
    advance(30000)
    check(#plays == beatsOf("burst") and exported.status().pending == nil)
    realPrint("PASS server: schedule")
end

-- ── cancel, replace a schedule, console scheduling ──
do
    boot()
    reply(1, "in 1 finale")
    advance(10000)
    local cancelled = reply(1, "cancel")
    check(cancelled.ok, cancelled.text)
    check(chats[#chats].text:find("cancelled"), "players are told")
    local announced = #chats + #toasts
    advance(120000)
    check(#plays == 0 and #chats + #toasts == announced, "a cancelled schedule is silent afterwards")
    check(not reply(1, "cancel").ok)

    reply(1, "in 1 burst crossing")
    local second = reply(1, "in 30s celebration crossing")
    check(second.ok and second.text:find("replaces"), second.text)
    advance(120000)
    check(#plays == beatsOf("celebration"), "only the newest schedule fires")

    plays = {}
    run(0, "in 90s finale")
    advance(89000)
    check(#plays == 0)
    advance(2000)
    check(#plays >= 1 and plays[1].options.bucket == 0, "the console schedules over the hub")
    run(0, "in 1 burst here")
    check(lastLog():find("console has no position"), lastLog())
    check(not reply(1, "in soon").ok and not reply(1, "in 5s").ok, "bad delays refused")
    realPrint("PASS server: cancel, replace, console")
end

-- ── the opening-night macro ──
do
    boot()
    local answer = reply(2, "opening 30s")
    check(answer.ok and answer.text:find("finale over The Crossing"), answer.text)
    check(chats[1].title == "OPENING NIGHT" and chats[1].text:find("in 30 seconds"), chats[1].text)
    advance(30000)
    check(#plays == 1 and plays[1].options.bucket == 0, "the finale starts over the hub, bucket 0, not the caller's")
    local dx = plays[1].options.position.x - CROSSING.x
    check(math.abs(dx) <= 60, "over The Crossing")
    advance(60000)
    check(#plays == beatsOf("finale"), "the whole finale")
    local closing = chats[#chats]
    check(closing.title == "OPENING NIGHT" and closing.text:find("activities start at The Crossing"), closing.text)
    -- default delay
    boot()
    check(reply(1, "opening").ok)
    check(exported.status().pending.inMs == C.opening.delaySeconds * 1000)
    check(reply(1, "opening 1 atlantis").ok == false)
    realPrint("PASS server: opening night")
end

-- ── announcements ──
do
    boot()
    local answer = reply(1, "announce Server restart in 10 minutes")
    check(answer.ok, answer.text)
    check(chats[1].type == "announcement" and chats[1].title == "ANNOUNCEMENT" and chats[1].author == "LIGHT RP")
    check(chats[1].text == "Server restart in 10 minutes" and toasts[1].message == chats[1].text)
    check(toasts[1].id == nil, "a free announcement never replaces the countdown banner")
    check(not reply(1, "announce").ok, "empty refused")
    check(exported.announce(nil, ("long "):rep(200)) == true)
    check(#chats[#chats].text <= 240 and #toasts[#toasts].message <= 240)
    local ok = exported.announce("ARENA NIGHT", "Arena opens at 21:00.")
    check(ok and chats[#chats].title == "ARENA NIGHT")
    check(exported.announce("x", nil) == false and exported.announce("x", 42) == false)
    -- the optional gamemode event
    C.announce.lightrpEvent = "op77_lightrp:announce"
    exported.announce(nil, "Hello")
    check(events[#events].name == "op77_lightrp:announce" and events[#events].payload.body == "Hello")
    C.announce.lightrpEvent = nil
    C.announce.chat, C.announce.toast = false, false
    check(exported.announce(nil, "Nobody") == false, "no channel, no claim of success")
    realPrint("PASS server: announcements")
end

-- ── exports are synchronous and never yield ──
do
    boot()
    check(not coroutine.isyieldable(), "called from the main chunk, like a sync export")
    check(exported.play("burst", "crossing") == true)
    local ok, info = exported.play("celebration", { x = 1, y = 2, z = 3 }, 4)
    check(ok and info.bucket == 4 and plays[#plays].options.bucket == 4, "a point takes the given bucket")
    check(exported.play("burst", "crossing", 99) == true and plays[#plays].options.bucket == 0, "a place keeps its own bucket")
    check(exported.play("burst", { x = 1, y = 2, z = 3 }, -1) == false, "a negative bucket is refused")
    check(exported.play("burst", { x = 1, y = 2 }) == false)
    check(exported.play("burst", "here") == false, "an export has no caller position")
    check(exported.play("burst") == true and plays[#plays].options.bucket == 0, "default place for an export")
    check(exported.playFor(2, "celebration") == true and plays[#plays].options.bucket == 7)
    check(exported.playFor(0, "burst") == false and exported.playFor(99, "burst") == false)
    check(exported.schedule("burst", "crossing", 5) == false, "under the minimum delay")
    check(exported.schedule("burst", "crossing", 20) == true)
    check(exported.opening(15, "crossing") == true and exported.status().pending.show == "finale")
    local s = exported.status()
    check(s.show and s.pending and #s.shows == 3 and s.places[1] == "crossing")
    check(exported.stop() == true and exported.status().show == nil and exported.status().pending == nil)
    check(exported.stop() == false)
    realPrint("PASS server: exports")
end

-- ── resource stop: nothing fires or speaks afterwards ──
do
    boot()
    reply(1, "finale crossing")
    reply(1, "in 1 burst crossing")
    advance(3000)
    handlers.onResourceStop("some_other_resource")
    advance(1000)
    local fired, spoken = #plays, #chats + #toasts
    check(fired > 1)
    handlers.onResourceStop("op77_fireworks")
    check(cleared == 1, "banners cleared")
    advance(180000)
    check(#plays == fired and #chats + #toasts == spoken, "silent after stop")
    local late = reply(1, "burst crossing")
    check(not late.ok and late.text:find("stopping"), late.text)
    check(exported.schedule("burst", "crossing", 30) == false)
    realPrint("PASS server: resource stop")
end

print = realPrint
print("PASS: op77_fireworks -- plan (expand, slice, budget, presets, countdown, delays, text, placement) and server (place, here, console, refusals, stop, replace, stall, schedule, cancel, opening night, announcements, exports, resource stop)")
