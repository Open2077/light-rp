-- op77_fireworks -- server: the command, the exports and the timers. The
-- planning logic (beats, slicing, budget, countdown, text) is pure and lives in
-- server/plan.lua; this file only adds natives and time.
--
-- ONE CLOCK, ONE AUTHORITY. Every shell goes out through Open77.effects.play,
-- which broadcasts it to the players in range of that bucket: same shell, same
-- point, same moment for everybody (rp_fireworks, from which this is ported).
-- There is no client code at all.
--
-- Every export is synchronous and never yields: the waiting happens in threads
-- this resource starts, so `exports.op77_fireworks:play(...)` is safe inline.

local Config = FireworksConfig
local Plan = FireworksPlan
local RESOURCE = GetCurrentResourceName()
-- The countdown is ONE banner updated in place (open77_notifications `replace`).
local COUNTDOWN_ID = "op77_fireworks_countdown"

local state = {
    epoch = 0,       -- a running show stops at its next beat when this moves
    show = nil,      -- the running show { name, label, bucket, startedMs, durationMs, beats, thinned }
    pending = nil,   -- the one scheduled show
    sequence = 0,
    lastShell = nil,
    lastPoint = nil,
    stopping = false,
}

local function log(fmt, ...)
    print(("[op77_fireworks] " .. fmt):format(...))
end

local function nowMs()
    return math.floor(Open77.time.monotonic() * 1000)
end

local function reply(source, raw, ok, text)
    log("%s", text)
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
    end
end

local function list(map)
    return table.concat(Plan.keys(map), ", ")
end

-- ---------------------------------------------------------------------------
-- Announcements (every connected player, whatever their bucket)
-- ---------------------------------------------------------------------------

--- A chat announcement row + a platform banner (+ the optional gamemode event).
--- Answers true, or false and a reason. Never raises.
local function announce(title, text, options)
    options = options or {}
    local A = Config.announce or {}
    if type(title) ~= "string" or Plan.clip(title, 90) == "" then title = A.title or "ANNOUNCEMENT" end
    title = Plan.clip(title, 90)
    text = Plan.clip(type(text) == "string" and text or "", 240)
    if text == "" then return false, "the announcement is empty" end
    local kind = options.kind or "info"
    local duration = math.floor(Plan.number(options.durationMs, Plan.number(A.durationMs, 12000)))
    duration = math.max(750, math.min(120000, duration))
    local sent = 0
    if A.chat ~= false and options.chat ~= false and Open77.chat then
        local called, ok = pcall(Open77.chat.broadcast, {
            type = "announcement", title = title, author = A.author, text = text,
        })
        if called and ok ~= false then sent = sent + 1 end
    end
    if A.toast ~= false and Open77.notifications then
        local called, id, reason = pcall(Open77.notifications.broadcast, {
            id = options.id,
            replace = options.id ~= nil or nil,
            type = kind,
            title = title,
            message = text,
            icon = A.icon,
            position = A.position or "top_center",
            durationMs = duration,
        })
        if called and id then
            sent = sent + 1
        else
            log("banner refused: %s", tostring(called and reason or id))
        end
    end
    if type(A.lightrpEvent) == "string" and A.lightrpEvent ~= "" then
        if pcall(TriggerEvent, A.lightrpEvent, { title = title, body = text, kind = kind, durationMs = duration }) then
            sent = sent + 1
        end
    end
    if sent == 0 then return false, "no announcement channel accepted it" end
    return true
end

--- One step of a scheduled show's script: render the configured text, announce.
local function stage(text, pending, remainingSeconds, options)
    if type(text) ~= "table" then return end
    local vars = {
        place = pending.target.label,
        show = pending.show,
        time = Plan.formatRemaining(remainingSeconds),
    }
    announce(Plan.render(text.title, vars), Plan.render(text.text, vars), options)
end

-- ---------------------------------------------------------------------------
-- Where a show goes
-- ---------------------------------------------------------------------------

--- `where` is a place name, "here" (the caller), or a point { x, y, z }; nil is
--- "here" for a player and the default place for the console or an export.
--- Answers { centre, bucket, label } or nil and a reason.
local function resolve(where, caller, bucket)
    caller = tonumber(caller)
    if type(where) == "table" then
        local x, y, z = Plan.number(where.x, nil), Plan.number(where.y, nil), Plan.number(where.z, nil)
        if x == nil or y == nil or z == nil then return nil, "the point needs x, y and z" end
        local b = Plan.bucket(bucket ~= nil and bucket or where.bucket or 0)
        if b == nil then return nil, "invalid routing bucket" end
        return { centre = { x = x, y = y, z = z }, bucket = b, label = Config.hereLabel or "Night City" }
    end
    if where == nil or where == "" then
        where = (caller ~= nil and caller > 0) and "here" or Config.defaultPlace
    end
    if type(where) ~= "string" then return nil, "name a place (" .. list(Config.places) .. ") or 'here'" end
    if where:lower() == "here" then
        if caller == nil or caller <= 0 then
            return nil, "the console has no position: name a place (" .. list(Config.places) .. ")"
        end
        local position = Open77.players.position(caller)
        if type(position) ~= "table" or Plan.number(position.x, nil) == nil then
            return nil, "your position is not known yet"
        end
        local b = Plan.bucket(position.bucket or 0)
        if b == nil then return nil, "your routing bucket is unknown" end
        return {
            centre = { x = position.x, y = position.y, z = position.z },
            bucket = b,
            label = Config.hereLabel or "Night City",
        }
    end
    local key, place = Plan.find(Config.places, where)
    if place == nil then
        return nil, "unknown place '" .. where .. "' (places: " .. list(Config.places) .. ", or here)"
    end
    local x, y, z = Plan.number(place.x, nil), Plan.number(place.y, nil), Plan.number(place.z, nil)
    local b = Plan.bucket(place.bucket or 0)
    if x == nil or y == nil or z == nil or b == nil then return nil, "place '" .. key .. "' is misconfigured" end
    return {
        centre = Plan.offset({ x = x, y = y, z = z }, place.heading, place.standoff),
        bucket = b,
        label = place.label or key,
    }
end

--- `/fireworks <a> [b]`: a show then a place, or just a place (default show).
local function showAndPlace(a, b)
    if a ~= nil and Plan.find(Config.shows, a) == nil and b == nil
        and (a:lower() == "here" or Plan.find(Config.places, a) ~= nil) then
        return Config.defaultShow, a
    end
    return a or Config.defaultShow, b
end

-- ---------------------------------------------------------------------------
-- The show
-- ---------------------------------------------------------------------------

--- Fire one beat. Answers true, or false and a reason.
---
--- In "registry" mode a silent shell is a registry entry with a ttl: the
--- server retires it, so its client quota slot comes back (see `shellMode` in
--- the config). A shell that carries the boom is a one-shot either way, since
--- a registry entry has no sound. Nothing needs removing on stop: an entry
--- expires by itself and the platform removes a stopped resource's entries.
local function fire(beat, target)
    local def = beat.def or {}
    local effect
    if def.effect ~= nil then
        effect = (Config.effects or {})[def.effect] or def.effect
    else
        effect = Plan.nextShell(Config.shells, state.lastShell, math.random)
        state.lastShell = effect
    end
    if type(effect) ~= "string" or effect == "" then return false, "no shells configured" end
    local point = Plan.point(def, target.centre, state.lastPoint, Config, math.random)
    state.lastPoint = point
    if Config.shellMode ~= "oneshot" and beat.sound == nil then
        local life = (Config.budget or {}).shellLifeMs
        local called, id, reason = pcall(Open77.effects.create, {
            effect = effect,
            position = point,
            bucket = target.bucket,
            ttlMs = math.max(1000, math.floor(Plan.number(life, 10000))),
            streamingRadius = math.max(10.0, math.min(2000.0, Plan.number(Config.streamingRadius, 400.0))),
        })
        if not called then return false, tostring(id) end
        if not id then return false, tostring(reason or "refused") end
        return true
    end
    local called, ok, reason = pcall(Open77.effects.play, effect, {
        position = point,
        bucket = target.bucket,
        range = math.max(1.0, math.min(500.0, Plan.number(Config.range, 500.0))),
        sound = beat.sound,
    })
    if not called then return false, tostring(ok) end
    if not ok then return false, tostring(reason or "refused") end
    return true
end

--- Walk the beats on the server clock. Times are absolute (start + offset) so
--- waits do not drift, and a thread that fell behind (a server hitch) still
--- never fires more than one slice in a tick. The epoch is read before every
--- beat: that is how `stop`, a newer show and the resource stop end it.
local function run(beats, target, epoch, startedMs, origin, after)
    local budget = Config.budget or {}
    local sliceSize = math.max(1, math.floor(Plan.number(budget.sliceSize, 8)))
    local gapMs = math.max(1, math.floor(Plan.number(budget.sliceGapMs, 60)))
    CreateThread(function()
        local failures, inTick = 0, 1
        for index = 2, #beats do
            local beat = beats[index]
            local waitMs = startedMs + (beat.at - origin) - nowMs()
            if waitMs > 0 then
                Wait(waitMs)
                inTick = 0
            elseif inTick >= sliceSize then
                Wait(gapMs)
                inTick = 0
            end
            if epoch ~= state.epoch then return end
            local ok, reason = fire(beat, target)
            if not ok then
                failures = failures + 1
                if failures == 1 then log("a shell was refused: %s", tostring(reason)) end
            end
            inTick = inTick + 1
        end
        if epoch ~= state.epoch then return end
        state.show = nil
        if failures > 0 then log("%d shell(s) refused by the effect registry", failures) end
        if after ~= nil then
            Wait(3000) -- let the last shells fade before the closing line
            if epoch == state.epoch and not state.stopping then announce(after.title, after.text) end
        end
    end)
end

--- Start a show now; a running show is replaced, not refused. The first beat is
--- fired here, synchronously, so a refused effect reaches whoever asked.
local function startShow(showName, target, after)
    if state.stopping then return false, "the fireworks resource is stopping" end
    local key, cues = Plan.find(Config.shows, showName or Config.defaultShow)
    if type(cues) ~= "table" or #cues == 0 then
        return false, "no show called '" .. tostring(showName) .. "' (shows: " .. list(Config.shows) .. ")"
    end
    local beats, thinned, duration = Plan.build(cues, Config)
    if #beats == 0 then return false, "the show '" .. key .. "' has no beat" end
    state.epoch = state.epoch + 1
    state.show = nil
    local epoch = state.epoch
    local ok, reason = fire(beats[1], target)
    if not ok then return false, "the effect registry refused it: " .. tostring(reason) end
    local startedMs = nowMs()
    state.show = {
        name = key, label = target.label, bucket = target.bucket,
        startedMs = startedMs, durationMs = duration - beats[1].at,
        beats = #beats, thinned = thinned,
    }
    run(beats, target, epoch, startedMs, beats[1].at, after)
    log("show %s at %.1f %.1f %.1f (bucket %d): %d shells over %.1f s%s", key,
        target.centre.x, target.centre.y, target.centre.z, target.bucket, #beats,
        (duration - beats[1].at) / 1000, thinned > 0 and (", " .. thinned .. " thinned by the effect budget") or "")
    return true, state.show
end

local function stopShow()
    if state.show == nil then return false, "no show is running" end
    state.epoch = state.epoch + 1
    state.show = nil
    return true
end

-- ---------------------------------------------------------------------------
-- Scheduling (one pending show at a time; a new one replaces it)
-- ---------------------------------------------------------------------------

local function cancel(silent)
    local pending = state.pending
    if pending == nil then return false, "nothing is scheduled" end
    state.pending = nil -- its thread sees this at its next mark and exits
    if silent then
        pcall(Open77.notifications.dismiss, COUNTDOWN_ID)
    else
        stage(pending.texts.cancelled, pending, 0, { id = COUNTDOWN_ID, kind = "warning", durationMs = 8000 })
    end
    log("scheduled show %s over %s cancelled", pending.show, pending.target.label)
    return true
end

local function schedule(showName, target, delayMs, texts, after)
    if state.stopping then return false, "the fireworks resource is stopping" end
    local key, cues = Plan.find(Config.shows, showName or Config.defaultShow)
    if type(cues) ~= "table" or #cues == 0 then
        return false, "no show called '" .. tostring(showName) .. "' (shows: " .. list(Config.shows) .. ")"
    end
    local S = Config.schedule or {}
    local replaced = state.pending ~= nil
    state.sequence = state.sequence + 1
    local startMs = nowMs()
    local pending = {
        id = state.sequence, show = key, target = target,
        startMs = startMs, fireAtMs = startMs + delayMs,
        texts = type(texts) == "table" and texts or Config.texts or {},
        after = after,
    }
    state.pending = pending
    local marks = Plan.countdown(delayMs, S.marks, S)
    stage(pending.texts.scheduled, pending, delayMs / 1000, { id = COUNTDOWN_ID, durationMs = 15000 })
    CreateThread(function()
        for _, mark in ipairs(marks) do
            local waitMs = startMs + mark.atMs - nowMs()
            if waitMs > 0 then Wait(waitMs) end
            if state.pending ~= pending then return end
            stage(pending.texts.countdown, pending, mark.remaining, {
                id = COUNTDOWN_ID, chat = mark.chat, durationMs = mark.chat and 15000 or 2500,
            })
        end
        local waitMs = pending.fireAtMs - nowMs()
        if waitMs > 0 then Wait(waitMs) end
        if state.pending ~= pending then return end
        state.pending = nil
        stage(pending.texts.launch, pending, 0, { id = COUNTDOWN_ID, kind = "success", durationMs = 8000 })
        local closing
        if type(pending.after) == "table" then
            local vars = { place = target.label, show = key, time = "" }
            closing = { title = Plan.render(pending.after.title, vars), text = Plan.render(pending.after.text, vars) }
        end
        local ok, reason = startShow(key, target, closing)
        if not ok then log("scheduled show %s did not start: %s", key, tostring(reason)) end
    end)
    log("show %s scheduled over %s (bucket %d) in %s, %d countdown mark(s)%s", key, target.label,
        target.bucket, Plan.formatRemaining(delayMs / 1000), #marks, replaced and ", replacing the previous one" or "")
    return true, { id = pending.id, show = key, label = target.label, inMs = delayMs, marks = #marks, replaced = replaced }
end

local function opening(delayMs, where, caller)
    local O = Config.opening or {}
    local target, reason = resolve(where or O.place, caller)
    if target == nil then return false, reason end
    local texts = O.texts or {}
    return schedule(O.show or "finale", target, delayMs or math.floor(Plan.number(O.delaySeconds, 300) * 1000),
        texts, texts.after)
end

local function status()
    local now = nowMs()
    local show, pending = state.show, state.pending
    return {
        show = show and { name = show.name, label = show.label, bucket = show.bucket,
            elapsedMs = now - show.startedMs, durationMs = show.durationMs, beats = show.beats } or nil,
        pending = pending and { show = pending.show, label = pending.target.label, bucket = pending.target.bucket,
            inMs = math.max(0, pending.fireAtMs - now) } or nil,
        shows = Plan.keys(Config.shows),
        places = Plan.keys(Config.places),
    }
end

local function statusLine()
    local s = status()
    local parts = {}
    if s.show then
        parts[#parts + 1] = ("Running: %s over %s (%s of %s)."):format(s.show.name, s.show.label,
            Plan.formatRemaining(s.show.elapsedMs / 1000), Plan.formatRemaining(s.show.durationMs / 1000))
    else
        parts[#parts + 1] = "No show running."
    end
    if s.pending then
        parts[#parts + 1] = ("Scheduled: %s over %s in %s."):format(s.pending.show, s.pending.label,
            Plan.formatRemaining(s.pending.inMs / 1000))
    else
        parts[#parts + 1] = "Nothing scheduled."
    end
    parts[#parts + 1] = "Shows: " .. table.concat(s.shows, ", ") .. ". Places: " .. table.concat(s.places, ", ") .. ", here."
    return table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------
-- Exports (synchronous, never yield; answer true/false + reason, never raise)
-- ---------------------------------------------------------------------------

local function delayFromSeconds(seconds)
    local S = Config.schedule or {}
    return Plan.parseDelay(tostring(Plan.number(seconds, -1)) .. "s", S.minSeconds, S.maxSeconds)
end

-- play(show, where, bucket): `where` = a place name or { x, y, z }; `bucket`
-- only applies to a point (a place keeps its own).
exports("play", function(show, where, bucket)
    local target, reason = resolve(where, nil, bucket)
    if target == nil then return false, reason end
    return startShow(show, target)
end)

-- playFor(playerId, show): over a player, in that player's routing bucket
-- (a podium inside an activity instance, a race finish).
exports("playFor", function(playerId, show)
    playerId = tonumber(playerId)
    if playerId == nil or playerId <= 0 then return false, "invalid player id" end
    local target, reason = resolve("here", playerId)
    if target == nil then return false, reason end
    return startShow(show, target)
end)

-- schedule(show, where, delaySeconds, bucket): with the countdown announcements.
exports("schedule", function(show, where, delaySeconds, bucket)
    local delayMs, reason = delayFromSeconds(delaySeconds)
    if delayMs == nil then return false, reason end
    local target; target, reason = resolve(where, nil, bucket)
    if target == nil then return false, reason end
    return schedule(show, target, delayMs)
end)

exports("opening", function(delaySeconds, where)
    local delayMs, reason = nil, nil
    if delaySeconds ~= nil then
        delayMs, reason = delayFromSeconds(delaySeconds)
        if delayMs == nil then return false, reason end
    end
    return opening(delayMs, where)
end)

exports("announce", function(title, text) return announce(title, text) end)

exports("stop", function()
    local stopped = stopShow()
    local cancelled = cancel(false)
    if not stopped and not cancelled then return false, "nothing to stop" end
    return true
end)

exports("status", status)

-- ---------------------------------------------------------------------------
-- The command (restricted: `command.fireworks`)
-- ---------------------------------------------------------------------------

local USAGE = "/fireworks [show] [place|here] | in <delay> [show] [place|here] | opening [delay] [place|here]"
    .. " | announce <text> | stop | cancel | status. Delay: minutes (10, 2.5) or 90s / 5m."

local function command(source, args, raw)
    source = tonumber(source) or 0
    args = type(args) == "table" and args or {}
    local function answer(ok, text) reply(source, raw, ok, text) end
    local sub = args[1] ~= nil and tostring(args[1]):lower() or nil
    local S = Config.schedule or {}

    if sub == "help" then return answer(true, USAGE) end
    if sub == "status" or sub == "list" then return answer(true, statusLine()) end

    if sub == "stop" then
        local stopped = stopShow()
        local cancelled = cancel(false)
        if not stopped and not cancelled then return answer(false, "Nothing to stop: no show running, nothing scheduled.") end
        return answer(true, (stopped and "Show stopped." or "No show was running.")
            .. (cancelled and " Scheduled show cancelled." or ""))
    end

    if sub == "cancel" then
        local ok, reason = cancel(false)
        return answer(ok, ok and "Scheduled show cancelled." or ("Nothing to cancel: " .. reason .. "."))
    end

    if sub == "announce" then
        local text = table.concat(args, " ", 2)
        if Plan.clip(text, 240) == "" then return answer(false, "Usage: /fireworks announce <text>") end
        local ok, reason = announce(nil, text)
        return answer(ok, ok and "Announcement sent to every player." or ("Announcement failed: " .. reason .. "."))
    end

    if sub == "opening" then
        local delayMs, reason = nil, nil
        if args[2] ~= nil then
            delayMs, reason = Plan.parseDelay(args[2], S.minSeconds, S.maxSeconds)
            if delayMs == nil then return answer(false, "Opening night: " .. reason .. ".") end
        end
        local ok, info = opening(delayMs, args[3], source)
        if not ok then return answer(false, "Opening night: " .. tostring(info) .. ".") end
        return answer(true, ("Opening night scheduled: %s over %s in %s.%s"):format(info.show, info.label,
            Plan.formatRemaining(info.inMs / 1000), info.replaced and " It replaces the previous schedule." or ""))
    end

    if sub == "in" then
        local delayMs, reason = Plan.parseDelay(args[2], S.minSeconds, S.maxSeconds)
        if delayMs == nil then return answer(false, "Usage: /fireworks in <delay> [show] [place|here] -- " .. reason .. ".") end
        local showName, where = showAndPlace(args[3], args[4])
        local target; target, reason = resolve(where, source)
        if target == nil then return answer(false, "No show: " .. reason .. ".") end
        local ok, info = schedule(showName, target, delayMs)
        if not ok then return answer(false, "No show: " .. tostring(info) .. ".") end
        return answer(true, ("Scheduled: %s over %s in %s (%d countdown announcements).%s"):format(info.show,
            info.label, Plan.formatRemaining(info.inMs / 1000), info.marks,
            info.replaced and " It replaces the previous schedule." or ""))
    end

    local showName, where = showAndPlace(args[1], args[2])
    local target, reason = resolve(where, source)
    if target == nil then return answer(false, "No show: " .. reason .. ".") end
    local ok, info = startShow(showName, target)
    if not ok then return answer(false, "No show: " .. tostring(info) .. ".") end
    answer(true, ("Lighting up the sky: %s over %s (bucket %d), %s.%s"):format(info.name, info.label, info.bucket,
        Plan.formatRemaining(info.durationMs / 1000),
        info.thinned > 0 and (" " .. info.thinned .. " shells thinned by the effect budget.") or ""))
end

RegisterCommand(Config.command or "fireworks", function(source, args, raw)
    local ok, err = pcall(command, source, args, raw)
    if not ok then
        log("command failed: %s", tostring(err))
        reply(tonumber(source) or 0, raw, false, "Command failed, see the server log.")
    end
end, true)

-- ---------------------------------------------------------------------------
-- Clean stop: nothing fires and nothing is announced after this. One-shots need
-- no removal (they expire on their own), and the platform clears this
-- resource's banners when it stops; clearing them here is belt and braces.
-- ---------------------------------------------------------------------------

AddEventHandler("onResourceStop", function(name)
    if name ~= RESOURCE then return end
    state.stopping = true
    state.epoch = state.epoch + 1
    state.show, state.pending = nil, nil
    if Open77.notifications then pcall(Open77.notifications.clear) end
end)

log("ready -- shows: %s; places: %s; command /%s", list(Config.shows), list(Config.places), Config.command or "fireworks")
