-- op77_turf server wiring: registration with Light RP, the contract events, the death
-- events, the damage arbiter, the influence exports, the commands and the tick.
-- The rules live in rules.lua, the lifecycle in war.lua, the natives in world.lua.
local C = TurfConfig
local W = TurfWorld

local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end
local function validId(id)
    id = tonumber(id)
    if id == nil or id <= 0 or id % 1 ~= 0 then return nil end
    return math.tointeger(id)
end

-- ---------------------------------------------------------------- registration

local function publishStatus(force)
    TurfCore.status(Turf.status(W.now()), force)
end

local function register()
    local def = TurfCore.definition()
    local ok, why = TurfCore.register(def)
    if ok then
        log("registered %s with Light RP (%s)", def.id, def.modes and ("sites: " .. Turf.siteList()) or "one site")
        publishStatus(true)
    else
        log("Light RP refused %s: %s", def.id, tostring(why))
    end
    return ok
end

-- Exports may not be called while this VM is still preparing: register from a thread,
-- and again whenever Light RP (re)starts (it forgets its providers when it stops).
CreateThread(function()
    for _ = 1, 30 do
        if register() then return end
        Wait(2000)
    end
end)

AddEventHandler("op77_lightrp:activity:ready", function()
    CreateThread(function() Wait(500); register() end)
end)

AddEventHandler("onResourceStart", function(name)
    if name == C.core then
        CreateThread(function() Wait(1000); register() end)
    end
end)

-- ---------------------------------------------------------------- damage arbiter

-- Light RP's PvP is off; the war's scope opens it between fighters. This arbiter
-- narrows it further: running wars only, across sides, never on a fresh spawn.
local arbiter
if type(Open77.combat) == "table" and type(Open77.combat.onDamage) == "function" then
    local ok, handle = pcall(Open77.combat.onDamage, function(event)
        local fine, verdict = pcall(Turf.damage, event, W.now())
        if not fine then return nil end
        return verdict
    end)
    if ok and handle then arbiter = handle else log("damage arbiter unavailable: %s", tostring(handle)) end
else
    log("damage arbiter API unavailable: spawn protection and same-side checks rely on combat teams only")
end

AddEventHandler("onResourceStop", function(name)
    if name == GetCurrentResourceName() then
        -- Light RP releases and returns our players itself; drop our holds and teams.
        Turf.shutdown()
        if arbiter and type(Open77.combat.offDamage) == "function" then pcall(Open77.combat.offDamage, arbiter) end
    elseif name == C.core then
        -- Light RP forgot us and returned everyone: void the war, forget the queue.
        Turf.coreStopped(W.now())
        TurfCore.lastStatus = nil
    end
end)

-- ---------------------------------------------------------------- Light RP events
-- Host-wide events raised by op77_lightrp with TriggerEvent. Never RegisterNetEvent'd:
-- a client cannot fire them.

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    local ok, text = Turf.enqueue(id, options, W.now(), true)
    if not ok then W.notify(id, "warning", text, 5000) end
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    local done, where = Turf.leaveRequest(id, W.now())
    if done and where == "queue" then W.notify(id, "info", "You left the turf war queue.", 5000) end
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = validId(playerId)
    if id == nil or activityId ~= C.activity.id then return end
    Turf.dropped(id, W.now(), reason)
    publishStatus()
end)

-- A queued player who switches character (or goes back to the selector) leaves the queue.
AddEventHandler("op77_lightrp:characterChanged", function(playerId)
    local id = validId(playerId)
    if id and Turf.dequeue(id) then W.clear(id); publishStatus() end
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id == nil then return end
    -- Light RP sends `dropped` for an owned player; this covers the order of the two.
    Turf.dropped(id, W.now(), "disconnected")
    publishStatus()
end)

-- ---------------------------------------------------------------- deaths

AddEventHandler("open77:playerKilled", function(victimId, killerId)
    local victim, killer = validId(victimId), validId(killerId)
    if victim then Turf.onDeath(victim, killer, W.now()) end
end)

AddEventHandler("open77:playerDied", function(playerId, context)
    local victim = validId(playerId)
    if victim == nil then return end
    local killer
    if type(context) == "string" then killer = validId(context:match('"killer"%s*:%s*(%d+)')) end
    Turf.onDeath(victim, killer, W.now())
end)

-- ---------------------------------------------------------------- client events
-- Our own network events: everything a client sends is checked against the server's
-- state (membership, kit ids) and rate-limited.

local lastKit = {}
RegisterNetEvent("op77_turf:kit", function(choice)
    local id = validId(source)
    if id == nil then return end
    local now = W.now()
    if now - (lastKit[id] or -math.huge) < 400 then return end
    lastKit[id] = now
    local ok, text
    if choice == "next" or choice == nil then ok, text = Turf.nextKit(id, now)
    elseif type(choice) == "string" and #choice <= 24 then ok, text = Turf.chooseKit(id, choice, now)
    else return end
    W.notify(id, ok and "info" or "warning", text, 2500)
end)

RegisterNetEvent("op77_turf:hudless", function()
    local id = validId(source)
    if id then Turf.markHudless(id) end
end)

-- The client script (re)started: what it should be showing now.
RegisterNetEvent("op77_turf:ready", function()
    local id = validId(source)
    if id == nil then return end
    local now = W.now()
    local m, war = Turf.memberOf(id)
    if m then
        W.site(id, Turf.sitePayload(war, m))
        W.state(id, Turf.sharedView(war, now), Turf.personalView(war, m, now))
        W.board(id, Turf.boardRows(war))
    else
        local _, _, e = Turf.position(id)
        if e then e.pushedKey = nil; Turf.lastQueuePush = 0 end
    end
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id then lastKit[id] = nil end
end)

-- ---------------------------------------------------------------- exports
-- Synchronous, memory only (never the database), so any resource may call them from
-- anywhere, Light RP's hub included:
--   exports.op77_turf:influence([limit]) -> { { gang, label, color, points, wars, wins, captures }, ... }, weekIndex
--   exports.op77_turf:influenceOf(gang)  -> points, rank | nil

exports("influence", function(limit)
    local list = TurfInfluence.list()
    limit = tonumber(limit)
    if limit and limit >= 0 then
        for i = #list, math.floor(limit) + 1, -1 do list[i] = nil end
    end
    return list, TurfInfluence.week
end)

exports("influenceOf", function(gang)
    return TurfInfluence.of(gang)
end)

-- ---------------------------------------------------------------- commands

local function describe(id, now)
    local m, war = Turf.memberOf(id)
    if m then
        local n = Turf.counts(war)
        return ("Turf war at %s (%s): %s %d - %d %s, %d vs %d. You fight for %s%s: %d kills, %d deaths, %d captures.")
            :format(war.site.label, war.state, war.sides[1].label, war.sides[1].score, war.sides[2].score, war.sides[2].label,
                n[1], n[2], war.sides[m.side].label, m.merc and " (mercenary)" or "", m.kills, m.deaths, m.captures)
    end
    local position, total, e = Turf.position(id)
    if position then
        return ("Queued for Turf War (%d/%d, %d needed)%s. /turf leave to cancel."):format(position, total, Turf.minPlayers(),
            e.gangLabel and (" for the " .. e.gangLabel) or " as a mercenary")
    end
    local s = Turf.status(now)
    return "Turf War: " .. tostring(s.detail) .. ". /turf join to queue."
end

local function kitList()
    local parts = {}
    for _, kit in ipairs(C.kits) do parts[#parts + 1] = ("%s (%s)"):format(kit.id, kit.blurb) end
    return table.concat(parts, ", ")
end

-- /turf [join [site]|leave|kit [id]|influence|status]
RegisterCommand("turf", function(source, args, raw)
    local id = validId(source)
    if id == nil then W.reply(source, raw, false, "In game only.") return end
    local now = W.now()
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "leave" or sub == "quit" or sub == "cancel" then
        local done, where = Turf.leaveRequest(id, now)
        if done and where == "queue" then TurfCore.unqueue(id) end
        publishStatus()
        if done then W.reply(id, raw, true, where == "queue" and "You left the turf war queue." or "You left the turf war.") return end
        W.reply(id, raw, false, "You are not queued or in a turf war.")
    elseif sub == "kit" then
        local choice = args[2] and tostring(args[2]):lower() or nil
        if not choice then W.reply(id, raw, true, "Kits: " .. kitList() .. ". /turf kit <id>, or the kit key.") return end
        local ok, text = Turf.chooseKit(id, choice, now)
        W.reply(id, raw, ok, ok and text or (text .. " Kits: " .. kitList()))
    elseif sub == "influence" or sub == "top" or sub == "city" then
        W.reply(id, raw, true, TurfInfluence.describe(C.influence.topSize))
    elseif sub == "status" then
        W.reply(id, raw, true, describe(id, now))
    elseif sub == "" or sub == "join" or sub == "queue" then
        local site = args[2] and tostring(args[2]):lower() or nil
        if site and not Turf.site(site) then W.reply(id, raw, false, "Unknown site. Sites: " .. Turf.siteList()) return end
        local ok, text = Turf.enqueue(id, { site = site }, now, false)
        publishStatus()
        W.reply(id, raw, ok, text)
    else
        W.reply(id, raw, false, "usage: /turf [join [site]|leave|kit [id]|influence|status]")
    end
end, false)

-- Staff (ACL command.turf.schedule / .start / .stop / .testing / .survey / .status).

-- /turf.schedule <site|auto> <minutes> | cancel
RegisterCommand("turf.schedule", function(source, args, raw)
    local caller = validId(source) or 0
    local now = W.now()
    local first = args[1] and tostring(args[1]):lower() or nil
    if first == "cancel" then
        if not Turf.schedule then W.reply(caller, raw, false, "No war is scheduled.") return end
        local site = Turf.site(Turf.schedule.site)
        Turf.schedule = nil
        TurfCore.announce(("The turf war at %s is called off."):format(site and site.label or "the district"),
            { title = "TURF WAR", durationMs = 8000 })
        publishStatus()
        W.reply(caller, raw, true, "Scheduled war cancelled.")
        return
    end
    if not first or tonumber(args[2]) == nil then
        W.reply(caller, raw, false, "usage: turf.schedule <site|auto> <minutes> | cancel  (sites: " .. Turf.siteList() .. ")")
        return
    end
    local ok, text = Turf.scheduleWar(first, tonumber(args[2]), now)
    publishStatus()
    W.reply(caller, raw, ok, text)
end, true)

-- /turf.start [site]: the lobby closes now with whoever is queued (min players apply).
RegisterCommand("turf.start", function(source, args, raw)
    local caller = validId(source) or 0
    local now = W.now()
    if Turf.war then W.reply(caller, raw, false, ("War %d is on (%s): turf.stop first."):format(Turf.war.id, Turf.war.state)) return end
    local site = args[1] and Turf.site(tostring(args[1]):lower()) or nil
    if args[1] and not site then W.reply(caller, raw, false, "Unknown site. Sites: " .. Turf.siteList()) return end
    Turf.lobby = { site = site and site.id or (Turf.lobby and Turf.lobby.site), endsAt = now, scheduled = true }
    local war = Turf.launch(now)
    publishStatus()
    W.reply(caller, raw, war ~= nil, war and ("War %d starting at %s."):format(war.id, war.site.label)
        or ("Not started: %d queued, %d needed%s."):format(#Turf.queue, Turf.minPlayers(),
            Turf.testing and "" or " (turf.testing on lowers it to 2)"))
end, true)

-- /turf.stop: the running war ends now, nothing counts; also clears a lobby / schedule.
RegisterCommand("turf.stop", function(source, _, raw)
    local caller = validId(source) or 0
    local now = W.now()
    local done = {}
    if Turf.war and Turf.abort(Turf.war, now, "Stopped by staff. Nothing counts.") then done[#done + 1] = "war stopped" end
    if Turf.lobby then Turf.lobby = nil; done[#done + 1] = "lobby closed" end
    if Turf.schedule then Turf.schedule = nil; done[#done + 1] = "schedule cancelled" end
    publishStatus()
    W.reply(caller, raw, #done > 0, #done > 0 and table.concat(done, ", ") or "Nothing to stop.")
end, true)

-- /turf.testing on|off: two players start a war (staff tests). Never leave it on.
RegisterCommand("turf.testing", function(source, args, raw)
    local caller = validId(source) or 0
    local value = args[1] and tostring(args[1]):lower() or nil
    if value == "on" then Turf.testing = true elseif value == "off" then Turf.testing = false
    else W.reply(caller, raw, false, ("usage: turf.testing on|off (now %s)"):format(Turf.testing and "on" or "off")) return end
    log("testing mode %s", Turf.testing and "ON" or "off")
    publishStatus()
    W.reply(caller, raw, true, ("Turf War testing mode %s: %d players start a war, %d accounts make it count.")
        :format(Turf.testing and "ON" or "off", Turf.minPlayers(), Turf.minAccounts()))
end, true)

-- /turf.survey [label]: the caller's position and heading, in config syntax.
RegisterCommand("turf.survey", function(source, args, raw)
    local caller = validId(source)
    if caller == nil then W.reply(source, raw, false, "In game only.") return end
    local p, heading = W.pose(caller)
    if p == nil then W.reply(caller, raw, false, "No position yet: move a step and try again.") return end
    local label = table.concat(args or {}, " ")
    local line = ("{ x = %.3f, y = %.3f, z = %.3f, heading = %.1f }, -- %s (bucket %s)"):format(p.x, p.y, p.z,
        tonumber(heading) or 0, label ~= "" and label or "survey", tostring(p.bucket))
    log("survey by %d: %s", caller, line)
    W.reply(caller, raw, true, line)
end, true)

RegisterCommand("turf.status", function(source, _, raw)
    local caller = validId(source) or 0
    local now = W.now()
    local s = Turf.status(now)
    local lines = { ("status %s: %s (queue %d, testing %s, buckets %d-%d)"):format(s.phase, tostring(s.detail), #Turf.queue,
        Turf.testing and "on" or "off", C.buckets.from, C.buckets.to) }
    for i, e in ipairs(Turf.queue) do
        lines[#lines + 1] = ("  q%d: %d %s gang=%s site=%s"):format(i, e.id, tostring(e.name), tostring(e.gang), tostring(e.site))
    end
    if Turf.lobby then lines[#lines + 1] = ("  lobby: site=%s in %ds"):format(tostring(Turf.lobby.site),
        math.max(0, math.ceil((Turf.lobby.endsAt - now) / 1000))) end
    if Turf.schedule then lines[#lines + 1] = ("  schedule: %s in %ds"):format(Turf.schedule.site,
        math.max(0, math.ceil((Turf.schedule.at - now) / 1000))) end
    local war = Turf.war
    if war then
        lines[#lines + 1] = ("  war %d %s at %s bucket %d: %s %d - %d %s scope=%s%s"):format(war.id, war.state, war.site.id,
            war.bucket, war.sides[1].label, war.sides[1].score, war.sides[2].score, war.sides[2].label, tostring(war.scope),
            war.scopeError and (" (" .. tostring(war.scopeError) .. ")") or "")
        for _, zone in ipairs(war.zones) do
            lines[#lines + 1] = ("    zone %s owner=%s capturing=%s %.0f%%%s"):format(zone.def.id, tostring(zone.owner),
                tostring(zone.capturing), zone.progress * 100, zone.contested and " CONTESTED" or "")
        end
        for _, mid in ipairs(war.order) do
            local m = war.members[mid]
            lines[#lines + 1] = ("    %d %s side=%d%s %d/%d/%d%s"):format(m.id, tostring(m.name), m.side, m.merc and " merc" or "",
                m.kills, m.deaths, m.captures,
                m.gone and " (gone)" or m.released and " (home)" or m.leaving and " (leaving)" or m.down and " (down)" or "")
        end
    end
    lines[#lines + 1] = "  " .. TurfInfluence.describe(C.influence.topSize)
    W.reply(caller, raw, true, table.concat(lines, "\n"))
end, true)

-- ---------------------------------------------------------------- threads

CreateThread(function()
    local tickMs = math.floor(1000 / math.max(1, C.tickHz or 4))
    local lastStatus = 0
    while true do
        Wait(tickMs)
        local now = W.now()
        local ok, err = pcall(Turf.tick, now)
        if not ok then log("tick error: %s", tostring(err)) end
        if now - lastStatus >= 1000 then
            lastStatus = now
            publishStatus()
        end
    end
end)

-- The week's influence: loaded from the database at start, refreshed each minute (a
-- new week starts from zero). Database work only ever on this resource's threads.
CreateThread(function()
    Wait(2000)
    while true do
        local ok, err = pcall(TurfInfluence.refresh, W.unix())
        if not ok then log("influence refresh failed: %s", tostring(err)) end
        Wait(60000)
    end
end)

log("loaded (%s, buckets %d-%d, %d sites)", C.activity.id, C.buckets.from, C.buckets.to, #C.sites)
