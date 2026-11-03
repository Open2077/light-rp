-- op77_turf server wiring: registration with Light RP (turf.war, and turf.pve when the
-- platform can make NPCs), the contract events, staff bot mode, the death and NPC events,
-- the damage arbiter, the influence exports, the commands and the tick.
-- The rules live in rules.lua, the lifecycle in war.lua, the bots in bots.lua, the
-- natives in world.lua.
local C = TurfConfig
local W = TurfWorld

local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end
local function validId(id)
    id = tonumber(id)
    if id == nil or id <= 0 or id % 1 ~= 0 then return nil end
    return math.tointeger(id)
end

local PVP, PVE = C.activity.id, C.pve.activity.id
local pveRegistered = false

-- ---------------------------------------------------------------- registration

local function publishStatus(force)
    local now = W.now()
    TurfCore.status(Turf.status(now), force, nil, now)
    if pveRegistered then TurfCore.status(Turf.pveStatus(now), force, PVE, now) end
end

local pveNotice = false
local function register()
    local def = TurfCore.definition()
    local ok, why = TurfCore.register(def)
    if not ok then
        log("Light RP refused %s: %s", def.id, tostring(why))
        return false
    end
    log("registered %s with Light RP (%s)", def.id, def.modes and ("sites: " .. Turf.siteList()) or "one site")
    -- The Gang Sweep needs NPCs (world.npcs, Open77.npcs.create/remove on this build).
    pveRegistered = false
    if C.pve.enabled and TurfBots.available() then
        local pdef = TurfCore.definition("pve")
        local fine, reason = TurfCore.register(pdef)
        pveRegistered = fine == true
        if fine then log("registered %s (%s) with Light RP", pdef.id, pdef.label)
        else log("Light RP refused %s: %s", pdef.id, tostring(reason)) end
    elseif C.pve.enabled and not pveNotice then
        pveNotice = true
        log("%s not registered: no NPC API on this build (world.npcs, Open77.npcs.create)", PVE)
    end
    -- Staff bot mode survives a provider restart: read it after every registration.
    Turf.setBots(TurfCore.bots(), "registration")
    publishStatus(true)
    return true
end

-- Exports may not be called while this VM is still preparing: register from a thread,
-- and again whenever Light RP (re)starts (it forgets its providers when it stops).
CreateThread(function()
    -- Bodies a previous run of this resource left behind (hot reload) go first.
    pcall(TurfBots.sweep)
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

-- Staff bot mode (/lightrp.bots on|off). Host-wide, raised by op77_lightrp: never
-- RegisterNetEvent'd, a client cannot fire it.
AddEventHandler("op77_lightrp:activity:bots", function(enabled)
    Turf.setBots(enabled == true, "staff switch")
    publishStatus()
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
        -- Light RP releases and returns our players itself; drop our holds, teams, bots.
        TurfBots.stopping = true
        Turf.shutdown()
        if arbiter and type(Open77.combat.offDamage) == "function" then pcall(Open77.combat.offDamage, arbiter) end
    elseif name == C.core then
        -- Light RP forgot us and returned everyone: void every war, forget the queues.
        Turf.coreStopped(W.now())
        TurfCore.forgetStatus()
        pveRegistered = false
        Turf.setBots(false, "op77_lightrp stopped")
    end
end)

-- ---------------------------------------------------------------- Light RP events
-- Host-wide events raised by op77_lightrp with TriggerEvent. Never RegisterNetEvent'd:
-- a client cannot fire them.

local function ours(activityId) return activityId == PVP or activityId == PVE end

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = validId(playerId)
    if id == nil or not ours(activityId) then return end
    if activityId == PVE then
        local ok, text = Turf.sweepJoin(id, options, W.now(), true)
        if not ok then
            W.notify(id, "warning", text, 5000, "Gang Sweep")
            TurfCore.unqueue(id, PVE)
        end
    elseif type(options) == "table" and type(options.match) == "table" then
        -- A match formed by Light RP (friendly crew split, bot fill): a war of its own.
        local ok, text = Turf.matchJoin(id, options, W.now())
        if not ok then
            W.notify(id, "warning", text, 7000, "Turf War")
            TurfCore.unqueue(id, PVP)
        end
    else
        local ok, text = Turf.enqueue(id, options, W.now(), true)
        if not ok then W.notify(id, "warning", text, 5000) end
    end
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = validId(playerId)
    if id == nil or not ours(activityId) then return end
    -- Light RP's answer to the leave (its notice, its /leave reply) already says it: no
    -- second notice of ours on top.
    Turf.leaveRequest(id, W.now(), activityId)
    publishStatus()
end)

AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = validId(playerId)
    if id == nil or not ours(activityId) then return end
    Turf.dropped(id, W.now(), reason, activityId)
    publishStatus()
end)

-- A queued player who switches character (or goes back to the selector) leaves the queues.
AddEventHandler("op77_lightrp:characterChanged", function(playerId)
    local id = validId(playerId)
    if id == nil then return end
    local a, b, c = Turf.dequeue(id), Turf.unsweep(id), Turf.unmatch(id)
    if a or b or c then W.clear(id); publishStatus() end
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id == nil then return end
    -- Light RP sends `dropped` for an owned player; this covers the order of the two.
    Turf.dropped(id, W.now(), "disconnected")
    publishStatus()
end)

-- ---------------------------------------------------------------- deaths

-- The raw killer goes along: an NPC id (a bot's kill) is never a player id.
AddEventHandler("open77:playerKilled", function(victimId, killerId)
    local victim, killer = validId(victimId), validId(killerId)
    if victim then Turf.onDeath(victim, killer, W.now(), killerId) end
end)

AddEventHandler("open77:playerDied", function(playerId, context)
    local victim = validId(playerId)
    if victim == nil then return end
    local killer, raw
    if type(context) == "string" then
        raw = context:match('"killer"%s*:%s*"?(%-?%d+)"?')
        killer = validId(raw)
    end
    Turf.onDeath(victim, killer, W.now(), raw)
end)

-- ---------------------------------------------------------------- NPC events (platform)

AddEventHandler("onNpcDied", function(npcId, killer, cause)
    local ok, err = pcall(TurfBots.onNpcDied, npcId, killer, cause, W.now())
    if not ok then log("onNpcDied: %s", tostring(err)) end
end)

AddEventHandler("onNpcDamaged", function(npcId, attacker, amount, health)
    pcall(TurfBots.onNpcDamaged, npcId, attacker, amount, health, W.now())
end)

AddEventHandler("onNpcRemoved", function(npcId, reason)
    local ok, err = pcall(TurfBots.onNpcRemoved, npcId, reason, W.now())
    if not ok then log("onNpcRemoved: %s", tostring(err)) end
end)

-- ---------------------------------------------------------------- client events
-- Our own network events: everything a client sends is checked against the server's
-- state (membership, kit ids, the war's bots) and rate-limited.

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

-- Hit reports (client/main.lua forwards the engine's open77:npc* events). An NPC id is
-- an opaque text (or an integer), never trusted beyond "a bot of the sender's war":
-- TurfBots checks the war, the sides, the states, the distance and the rates.
local hitBudget = {}
local function npcIdOk(v)
    if type(v) == "string" then return #v > 0 and #v <= 32 end
    return math.type(v) == "integer"
end
local function hitAllowed(id, now)
    local b = hitBudget[id]
    if not b or now - b.at >= 1000 then b = { at = now, n = 0 }; hitBudget[id] = b end
    b.n = b.n + 1
    return b.n <= 40
end

RegisterNetEvent("op77_turf:npcHit", function(npcId, damage)
    local id = validId(source)
    if id == nil or not npcIdOk(npcId) then return end
    local now = W.now()
    if not hitAllowed(id, now) then return end
    TurfBots.onPlayerHit(id, npcId, tonumber(damage), now)
end)

RegisterNetEvent("op77_turf:npcHurtMe", function(npcId, damage)
    local id = validId(source)
    if id == nil or not npcIdOk(npcId) then return end
    local now = W.now()
    if not hitAllowed(id, now) then return end
    TurfBots.onBotHit(id, npcId, tonumber(damage), now)
end)

RegisterNetEvent("op77_turf:npcCrossfire", function(victimNpc, attackerNpc, damage)
    local id = validId(source)
    if id == nil or not npcIdOk(victimNpc) or not npcIdOk(attackerNpc) then return end
    local now = W.now()
    if not hitAllowed(id, now) then return end
    TurfBots.onCrossfire(id, victimNpc, attackerNpc, tonumber(damage), now)
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
        if not e then _, e = Turf.sweepEntry(id) end
        if e then e.pushedKey = nil; Turf.lastQueuePush = 0 end
    end
end)

AddEventHandler("playerDropped", function()
    local id = validId(source)
    if id then lastKit[id], hitBudget[id] = nil, nil end
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
        local bots = war.bots and TurfBots.count(war) or 0
        return ("%s at %s (%s): %s %d - %d %s, %d vs %d%s. You fight for %s%s: %d kills, %d deaths, %d captures.")
            :format(war.kind == "pve" and "Gang Sweep" or "Turf war", war.site.label, war.state, war.sides[1].label,
                war.sides[1].score, war.sides[2].score, war.sides[2].label, n[1], n[2],
                bots > 0 and (" (+%d bots)"):format(bots) or "", war.sides[m.side].label, m.merc and " (mercenary)" or "",
                m.kills, m.deaths, m.captures)
    end
    local position, total, e = Turf.position(id)
    if position then
        return ("Queued for Turf War (%d/%d, %d needed)%s. /turf leave to cancel."):format(position, total, Turf.minPlayers(),
            e.gangLabel and (" for the " .. e.gangLabel) or " as a mercenary")
    end
    local g = Turf.sweepEntry(id)
    if g then
        return ("Lined up for a Gang Sweep (%d in your group, %d sweep(s) running). /turf leave to cancel.")
            :format(#g.entries, #Turf.sweeps)
    end
    local mg = Turf.matchEntry(id)
    if mg then
        return ("Your turf war match is gathering (%d/%d). /turf leave to cancel."):format(#mg.entries, #mg.players)
    end
    local s = Turf.status(now)
    local text = "Turf War: " .. tostring(s.detail) .. ". /turf join to queue."
    if pveRegistered then text = text .. " Gang Sweep (PvE): /turf sweep." end
    return text
end

local function kitList()
    local parts = {}
    for _, kit in ipairs(C.kits) do parts[#parts + 1] = ("%s (%s)"):format(kit.id, kit.blurb) end
    return table.concat(parts, ", ")
end

local USAGE = "usage: /turf [join [site]|sweep [site]|leave|kit [id]|influence|status]"

-- /turf [join [site]|sweep [site]|leave|kit [id]|influence|status]
RegisterCommand("turf", function(source, args, raw)
    local id = validId(source)
    if id == nil then W.reply(source, raw, false, "In game only.") return end
    local now = W.now()
    local sub = tostring(args and args[1] or ""):lower()
    if sub == "leave" or sub == "quit" or sub == "cancel" then
        local done, where, activity = Turf.leaveRequest(id, now)
        if done and where == "queue" then TurfCore.unqueue(id, activity) end
        publishStatus()
        if done then
            local what = activity == PVE and "Gang Sweep" or "turf war"
            W.reply(id, raw, true, where == "queue" and ("You left the %s queue."):format(what) or ("You left the %s."):format(what))
            return
        end
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
    elseif sub == "sweep" or sub == "pve" then
        if not pveRegistered then W.reply(id, raw, false, "Gang Sweep is closed right now.") return end
        local site = args[2] and tostring(args[2]):lower() or nil
        if site and not Turf.site(site) then W.reply(id, raw, false, "Unknown site. Sites: " .. Turf.siteList()) return end
        local ok, text = Turf.sweepJoin(id, { site = site }, now, false)
        publishStatus()
        W.reply(id, raw, ok, text)
    elseif sub == "" or sub == "join" or sub == "queue" then
        local site = args[2] and tostring(args[2]):lower() or nil
        if site and not Turf.site(site) then W.reply(id, raw, false, "Unknown site. Sites: " .. Turf.siteList()) return end
        local ok, text = Turf.enqueue(id, { site = site }, now, false)
        publishStatus()
        W.reply(id, raw, ok, text)
    else
        W.reply(id, raw, false, USAGE)
    end
end, false)

-- Staff (ACL command.turf.schedule / .start / .stop / .testing / .survey / .status).
-- Staff bot mode is op77_lightrp's own /lightrp.bots: no command of ours.

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

-- /turf.start [site]: the lobby closes now with whoever is queued (min players apply;
-- one is enough in staff bot mode, bots fill the sides).
RegisterCommand("turf.start", function(source, args, raw)
    local caller = validId(source) or 0
    local now = W.now()
    if Turf.war then W.reply(caller, raw, false, ("War %d is on (%s): turf.stop first."):format(Turf.war.id, Turf.war.state)) return end
    local site = args[1] and Turf.site(tostring(args[1]):lower()) or nil
    if args[1] and not site then W.reply(caller, raw, false, "Unknown site. Sites: " .. Turf.siteList()) return end
    Turf.lobby = { site = site and site.id or (Turf.lobby and Turf.lobby.site), endsAt = now, scheduled = true }
    local war = Turf.launch(now)
    publishStatus()
    local hint = Turf.botMode() and " (bot mode on: 1 is enough)" or (Turf.testing and "" or " (turf.testing on lowers it to 2)")
    W.reply(caller, raw, war ~= nil, war and ("War %d starting at %s%s."):format(war.id, war.site.label,
            war.botWar and (" with %d bots"):format(TurfBots.count(war)) or "")
        or ("Not started: %d queued, %d needed%s."):format(#Turf.queue, Turf.minPlayers(), hint))
end, true)

-- /turf.stop [all]: the running war ends now, nothing counts; also clears a lobby /
-- schedule. `all` also calls off every Gang Sweep and the sweep line-up.
RegisterCommand("turf.stop", function(source, args, raw)
    local caller = validId(source) or 0
    local now = W.now()
    local done = {}
    if Turf.war and Turf.abort(Turf.war, now, "Stopped by staff. Nothing counts.") then done[#done + 1] = "war stopped" end
    if Turf.lobby then Turf.lobby = nil; done[#done + 1] = "lobby closed" end
    if Turf.schedule then Turf.schedule = nil; done[#done + 1] = "schedule cancelled" end
    if args and tostring(args[1] or ""):lower() == "all" then
        local n = 0
        for _, war in ipairs(Turf.sweeps) do
            if Turf.abort(war, now, "Stopped by staff. Nothing counts.") then n = n + 1 end
        end
        if n > 0 then done[#done + 1] = ("%d sweep(s) stopped"):format(n) end
        local waiting = 0
        for _, g in ipairs(Turf.sweepQueue) do
            for _, e in ipairs(g.entries) do
                waiting = waiting + 1
                W.clear(e.id)
                TurfCore.unqueue(e.id, PVE)
            end
        end
        Turf.sweepQueue = {}
        if waiting > 0 then done[#done + 1] = ("%d lined-up player(s) released"):format(waiting) end
    end
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

local function describeWar(lines, war)
    lines[#lines + 1] = ("  %s %d %s at %s bucket %d: %s %d - %d %s scope=%s%s%s"):format(war.kind == "pve" and "sweep" or "war",
        war.id, war.state, war.site.id, war.bucket, war.sides[1].label, war.sides[1].score, war.sides[2].score, war.sides[2].label,
        tostring(war.scope), war.scopeError and (" (" .. tostring(war.scopeError) .. ")") or "",
        war.botWar and " BOT WAR (not counted)" or (war.match and (" MATCH %s%s"):format(tostring(war.match.id),
            war.unranked and " (unranked)" or "")) or (war.unranked and " UNRANKED" or "")
            .. (war.difficulty and (" difficulty=%s"):format(war.difficulty.id) or ""))
    for _, zone in ipairs(war.zones) do
        lines[#lines + 1] = ("    zone %s owner=%s capturing=%s %.0f%%%s"):format(zone.def.id, tostring(zone.owner),
            tostring(zone.capturing), zone.progress * 100, zone.contested and " CONTESTED" or "")
    end
    for _, mid in ipairs(war.order) do
        local m = war.members[mid]
        lines[#lines + 1] = ("    %d %s side=%d%s%s %d/%d/%d%s"):format(m.id, tostring(m.name), m.side, m.merc and " merc" or "",
            m.squad and (" squad=" .. m.squad) or "", m.kills, m.deaths, m.captures,
            m.gone and " (gone)" or m.released and " (home)" or m.leaving and " (leaving)" or m.down and " (down)" or "")
    end
    for _, line in ipairs(TurfBots.describe(war)) do lines[#lines + 1] = line end
end

RegisterCommand("turf.status", function(source, _, raw)
    local caller = validId(source) or 0
    local now = W.now()
    local s = Turf.status(now)
    local lines = { ("status %s: %s (queue %d, testing %s, bot mode %s%s, buckets %d-%d)"):format(s.phase, tostring(s.detail),
        #Turf.queue, Turf.testing and "on" or "off", Turf.bots and "ON" or "off",
        Turf.bots and not TurfBots.available() and " but no NPC API" or "", C.buckets.from, C.buckets.to) }
    for i, e in ipairs(Turf.queue) do
        lines[#lines + 1] = ("  q%d: %d %s gang=%s site=%s%s"):format(i, e.id, tostring(e.name), tostring(e.gang), tostring(e.site),
            e.squad and (" squad=" .. e.squad) or "")
    end
    if Turf.lobby then lines[#lines + 1] = ("  lobby: site=%s in %ds"):format(tostring(Turf.lobby.site),
        math.max(0, math.ceil((Turf.lobby.endsAt - now) / 1000))) end
    if Turf.schedule then lines[#lines + 1] = ("  schedule: %s in %ds"):format(Turf.schedule.site,
        math.max(0, math.ceil((Turf.schedule.at - now) / 1000))) end
    if Turf.war then describeWar(lines, Turf.war) end
    local ps = Turf.pveStatus(now)
    lines[#lines + 1] = ("  gang sweep (%s): %s %s"):format(pveRegistered and "registered" or "not registered", ps.phase,
        tostring(ps.detail))
    for _, g in ipairs(Turf.sweepQueue) do
        local ids = {}
        for _, e in ipairs(g.entries) do ids[#ids + 1] = tostring(e.id) end
        lines[#lines + 1] = ("  line-up %s: %s (expected %d, starts in %ds)"):format(g.key, table.concat(ids, ","), #g.expected,
            math.max(0, math.ceil((g.readyAt - now) / 1000)))
    end
    for _, war in ipairs(Turf.sweeps) do describeWar(lines, war) end
    lines[#lines + 1] = ("  bots: %d created, %d removed"):format(TurfBots.created, TurfBots.removed)
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

-- No body in the first seconds of this VM (a hot reload's previous bodies go first).
pcall(function() TurfBots.start(W.now()) end)

log("loaded (%s + %s, buckets %d-%d, %d sites, NPC API %s)", PVP, PVE, C.buckets.from, C.buckets.to, #C.sites,
    TurfBots.available() and "yes" or "no")
