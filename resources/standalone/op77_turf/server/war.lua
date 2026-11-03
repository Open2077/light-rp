-- op77_turf lifecycle: the queue, the lobby, staff-scheduled wars, the war itself, and
-- the Gang Sweeps (the public PvE variant).
--
--   queue -> lobby (countdown) -> placing -> countdown -> running -> resolved -> closed
--
-- Everything is driven by Turf.tick(now): deadlines, not timers, so the whole flow runs
-- in tests/war_test.lua against a fake world (TurfWorld), a fake Light RP (TurfCore)
-- and the real rules (TurfRules). The only asynchronous steps are placements and kit
-- hand-outs, which report back through Turf.onPlaced.
--
-- One turf war at a time (Turf.war, activity turf.war). Gang Sweeps (Turf.sweeps,
-- activity turf.pve) run beside it, each in its own bucket, up to pve.maxSweeps: a crew
-- (or a solo player) against an NPC gang. Bots (server/bots.lua) fill a war launched
-- while staff bot mode is on (war.botWar) and are every sweep's gang.
--
-- The rules step (capture, score, bounds, scope) runs once a second per war, so its
-- cost is (fighters x zones) per second, never per frame.
Turf = { queue = {}, lobby = nil, schedule = nil, war = nil, sweeps = {}, sweepQueue = {}, nextWarId = nil,
    bucketCursor = nil, testing = false, bots = false, siteCursor = 0, sweepCursor = 0, lastQueuePush = 0 }
local R = TurfRules

local function cfg() return TurfConfig end
local function W() return TurfWorld end
local function C() return TurfCore end
local function B() return TurfBots end
local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end

-- ---------------------------------------------------------------- helpers

-- Staff bot mode (op77_lightrp /lightrp.bots), and the platform can make bots.
function Turf.botMode() return Turf.bots == true and B().available() end

-- Bot mode from the core (the event, or activityBots() after a registration). Off: no
-- new bot war; a running one keeps its bots until it ends.
function Turf.setBots(on, by)
    on = on == true
    if Turf.bots == on then return false end
    Turf.bots = on
    log("staff bot mode %s (%s)%s", on and "ON" or "off", tostring(by),
        on and not B().available() and ": no NPC API on this build, wars keep their normal rules" or "")
    Turf.lastQueuePush = 0
    return true
end

function Turf.minPlayers()
    if Turf.botMode() then return 1 end
    if Turf.testing then return math.max(2, cfg().testing.minPlayers or 2) end
    return math.max(2, cfg().activity.minPlayers or 6)
end

function Turf.minAccounts()
    if Turf.botMode() then return 1 end
    if Turf.testing then return cfg().testing.minAccounts or 2 end
    return cfg().rewards.minAccounts or 4
end

function Turf.site(id)
    for _, site in ipairs(cfg().sites) do if site.id == id then return site end end
    return nil
end

function Turf.enabledSites()
    local list = {}
    for _, site in ipairs(cfg().sites) do if site.enabled ~= false then list[#list + 1] = site end end
    return list
end

function Turf.kit(id)
    for _, kit in ipairs(cfg().kits) do if kit.id == id then return kit end end
    return nil
end

local function defaultKit() return Turf.kit(cfg().defaultKit) or cfg().kits[1] end

local function present(m) return m and not m.gone and not m.released and not m.leaving end
Turf.present = present

local function lifted(point)
    local lift = tonumber(cfg().match.spawnLiftMetres) or 0
    return { x = point.x, y = point.y, z = point.z + lift, heading = point.heading or 0 }
end

local function sideLabel(war, s) return war.sides[s] and war.sides[s].label or ("Side " .. tostring(s)) end

local function eachPresent(war, fn)
    for _, id in ipairs(war.order) do
        local m = war.members[id]
        if present(m) then fn(m) end
    end
end

-- Humans present per side (bots: TurfBots.count).
function Turf.counts(war)
    local n = { 0, 0 }
    eachPresent(war, function(m) n[m.side] = n[m.side] + 1 end)
    return n
end

local function isSweep(war) return war.kind == "pve" end
local function hasBots(war) return war.botWar == true or war.kind == "pve" end

-- Every live war: the turf war, then the sweeps.
function Turf.wars()
    local list = {}
    if Turf.war then list[1] = Turf.war end
    for _, w in ipairs(Turf.sweeps) do list[#list + 1] = w end
    return list
end

function Turf.warById(id)
    if id == nil then return nil end
    if Turf.war and Turf.war.id == id then return Turf.war end
    for _, w in ipairs(Turf.sweeps) do if w.id == id then return w end end
    return nil
end

-- A member not yet released or dropped (present or leaving), and his war.
local function entryOf(id)
    for _, war in ipairs(Turf.wars()) do
        local m = war.members[id]
        if m and not m.gone and not m.released then return m, war end
    end
    return nil
end

-- ---------------------------------------------------------------- identity

-- Name, account, character and gang of a player (gang from activityPlayer: nil, or a
-- gang the config does not know the colours of, still counts; absent = unaffiliated).
function Turf.identity(id)
    local info = C().player(id) or {}
    local view = info.gang
    local gang = R.gangKey(view)
    local gi = R.gangInfo(gang, view, cfg().gangs)
    return { name = info.name or W().name(id), identifier = info.identifier, characterKey = info.characterKey,
        gang = gang, gangLabel = gi and gi.label or nil, gangColor = gi and gi.color or nil }
end

-- The Light RP squad of a join (options.squad = { id, leader, members }), as a key.
local function squadOf(opts)
    local squad = type(opts) == "table" and opts.squad or nil
    if type(squad) ~= "table" or squad.id == nil then return nil end
    return tostring(squad.id), squad
end

-- ---------------------------------------------------------------- queue

function Turf.position(id)
    for i, e in ipairs(Turf.queue) do if e.id == id then return i, #Turf.queue, e end end
    return nil
end

function Turf.dequeue(id)
    for i, e in ipairs(Turf.queue) do
        if e.id == id then
            table.remove(Turf.queue, i)
            return true, e
        end
    end
    return false
end

function Turf.memberOf(id)
    for _, war in ipairs(Turf.wars()) do
        local m = war.members[id]
        if present(m) then return m, war end
    end
    return nil
end

-- A Gang Sweep line-up entry: group, entry, group index, entry index.
function Turf.sweepEntry(id)
    for gi, g in ipairs(Turf.sweepQueue) do
        for i, e in ipairs(g.entries) do if e.id == id then return g, e, gi, i end end
    end
    return nil
end

function Turf.unsweep(id)
    local g, _, gi, i = Turf.sweepEntry(id)
    if not g then return false end
    table.remove(g.entries, i)
    if #g.entries == 0 then table.remove(Turf.sweepQueue, gi) end
    return true
end

-- Queue a player. `checked`: Light RP already ran activityCheck (the hub join).
function Turf.enqueue(id, opts, now, checked)
    if Turf.memberOf(id) then return false, "You are already in the turf war." end
    local position, total = Turf.position(id)
    if position then return true, ("You are already queued for Turf War (%d/%d)."):format(position, total) end
    if Turf.sweepEntry(id) then return false, "You are lined up for a Gang Sweep: /turf leave first." end
    if not checked then
        local ok, why = C().check(id)
        if not ok then return false, why end
    end
    opts = type(opts) == "table" and opts or {}
    local vote = type(opts.site) == "string" and Turf.site(opts.site) or nil
    if vote and vote.enabled == false then vote = nil end
    local who = Turf.identity(id)
    local entry = { id = id, at = now, site = vote and vote.id or nil, name = who.name, identifier = who.identifier,
        characterKey = who.characterKey, gang = who.gang, gangLabel = who.gangLabel, gangColor = who.gangColor,
        kit = Turf.kit(opts.kit) and opts.kit or nil, squad = squadOf(opts) }
    Turf.queue[#Turf.queue + 1] = entry
    position, total = #Turf.queue, #Turf.queue
    local side = who.gang and ("for the " .. who.gangLabel) or "as a mercenary"
    local text
    local war = Turf.war
    if war and war.state ~= "resolved" then
        text = ("Queued for Turf War %s (%d in line). A war is on at %s: you go in as soon as a side has room. /turf leave to cancel.")
            :format(side, position, war.site.label)
    else
        text = ("Queued for Turf War %s - %d/%d fighters. Keep playing, you will be pulled in when the war starts. /turf leave to cancel.")
            :format(side, total, Turf.minPlayers())
    end
    W().notify(id, "info", text, 7000)
    Turf.lastQueuePush = 0
    return true, text
end

-- Drop queued players who waited too long or disconnected.
local function maintainQueue(now)
    local timeout = (cfg().queue.timeoutSeconds or 1800) * 1000
    local i = 1
    while i <= #Turf.queue do
        local e = Turf.queue[i]
        if not W().connected(e.id) then
            table.remove(Turf.queue, i)
        elseif now - e.at > timeout then
            table.remove(Turf.queue, i)
            W().clear(e.id)
            W().notify(e.id, "info", "Nobody started a turf war in time: you left the queue. Queue again from The Crossing or /turf join.", 6000)
        else
            i = i + 1
        end
    end
end

-- The lobby's site: a scheduled one, else the most voted enabled site, else the rotation.
function Turf.pickSite(entries, cursorKey)
    cursorKey = cursorKey or "siteCursor"
    local enabled = Turf.enabledSites()
    if #enabled == 0 then return cfg().sites[1] end
    local votes, best, bestN = {}, nil, 0
    for _, e in ipairs(entries or Turf.queue) do
        if e.site then votes[e.site] = (votes[e.site] or 0) + 1 end
    end
    for _, site in ipairs(enabled) do
        local n = votes[site.id] or 0
        if n > bestN then best, bestN = site, n end
    end
    if best then return best end
    Turf[cursorKey] = (Turf[cursorKey] or 0) % #enabled + 1
    return enabled[Turf[cursorKey]]
end

-- ---------------------------------------------------------------- presentation

-- What every fighter's HUD shares (built once per push).
function Turf.sharedView(war, now)
    local phase = war.state == "resolved" and "ended" or war.state
    local view = { warId = war.id, phase = phase, mode = war.kind,
        site = { id = war.site.id, label = war.site.label, district = war.site.district },
        target = war.target, sides = {}, zones = {}, reason = war.reason, winner = war.winner, void = war.void or nil }
    for s = 1, 2 do
        local side = war.sides[s]
        local bots = war.bots and B().count(war, s) or nil
        view.sides[s] = { label = side.label, color = side.color, score = side.score, gang = side.gang, count = bots or 0,
            bots = bots }
    end
    eachPresent(war, function(m) view.sides[m.side].count = view.sides[m.side].count + 1 end)
    for i, zone in ipairs(war.zones) do
        view.zones[i] = { id = zone.def.id, label = zone.def.label, owner = zone.owner, capturing = zone.capturing,
            progress = math.floor(zone.progress * 100 + 0.5) / 100, contested = zone.contested or nil }
    end
    if war.state == "countdown" then
        view.countdownMs = math.max(0, war.countdownEndsAt - now)
    elseif war.state == "running" then
        view.remainingMs = math.max(0, war.endsAt - now)
    elseif war.state == "placing" then
        view.countdownMs = math.max(0, war.placeDeadline - now)
    elseif war.state == "resolved" then
        view.remainingMs = math.max(0, (war.releaseAt or now) - now)
        view.counted = war.counted or nil
        view.influence = war.influenceTop and #war.influenceTop > 0 and war.influenceTop or nil
    end
    return view
end

function Turf.personalView(war, m, now)
    local kit = Turf.kit(m.kit) or defaultKit()
    return { id = m.id, side = m.side, merc = m.merc or nil, kills = m.kills, deaths = m.deaths, captures = m.captures,
        hold = math.floor(m.holdSeconds or 0), kit = kit.id, kitLabel = kit.label,
        score = R.personalScore(m, cfg().scoring),
        respawnMs = m.down and m.respawnAt and math.max(0, m.respawnAt - now) or nil,
        protectedMs = (m.protectedUntil or 0) > now and (m.protectedUntil - now) or nil,
        outMs = m.outSince and math.max(0, (cfg().life.outOfBoundsSeconds or 8) * 1000 - (now - m.outSince)) or nil,
        placing = m.placing or nil }
end

function Turf.pushHud(war, now)
    local shared = Turf.sharedView(war, now)
    eachPresent(war, function(m) W().state(m.id, shared, Turf.personalView(war, m, now)) end)
    war.lastHud = now
end

-- Fighters, then bots (negative ids, "[BOT] " names), by score.
function Turf.boardRows(war)
    local rows = {}
    for _, id in ipairs(war.order) do
        local m = war.members[id]
        if m and not m.gone and not m.left then
            rows[#rows + 1] = { id = m.id, name = m.name, side = m.side, merc = m.merc or nil, kills = m.kills,
                deaths = m.deaths, captures = m.captures, score = R.personalScore(m, cfg().scoring) }
        end
    end
    if war.bots then
        for _, row in ipairs(B().rows(war, cfg().scoring)) do rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    return rows
end

function Turf.pushBoard(war, now)
    local rows = Turf.boardRows(war)
    eachPresent(war, function(m) W().board(m.id, rows) end)
    war.lastBoard, war.boardDirty = now, false
end

function Turf.sitePayload(war, m)
    local zones = {}
    for i, def in ipairs(war.site.zones) do
        zones[i] = { id = def.id, label = def.label, x = def.x, y = def.y, z = def.z, radius = def.radius }
    end
    return { warId = war.id, site = { id = war.site.id, label = war.site.label, district = war.site.district },
        bounds = war.site.bounds, zones = zones, side = m.side, mode = war.kind,
        sides = { { label = war.sides[1].label, color = war.sides[1].color }, { label = war.sides[2].label, color = war.sides[2].color } } }
end

-- Feed / banner / result to one fighter; a fighter without the shared HUD (older
-- core) gets the banners and the result as notifications instead.
local function push(m, kind, payload)
    W().push(m.id, kind, payload)
    if m.hudless and kind ~= "feed" then
        local text = payload.text or payload.subtitle or ""
        if kind == "result" and type(payload.lines) == "table" then
            local parts = {}
            for _, line in ipairs(payload.lines) do parts[#parts + 1] = ("%s %s"):format(line.label, tostring(line.value)) end
            text = text .. (text ~= "" and " - " or "") .. table.concat(parts, ", ")
        end
        W().notify(m.id, payload.tone == "danger" and "warning" or (payload.tone == "success" and "success" or "info"),
            ((payload.title and payload.title .. ": ") or "") .. text, payload.durationMs or 5000)
    end
end
Turf.push = push

local function feedAll(war, text, tone)
    eachPresent(war, function(m) push(m, "feed", { text = text, tone = tone or "info" }) end)
end
Turf.feedAll = feedAll

-- Queued players see where they stand (and the lobby countdown): sent when it changed
-- only (the client counts the lobby down on its own).
function Turf.pushQueue(now, force)
    local lobbyMs = Turf.lobby and math.max(0, Turf.lobby.endsAt - now) or nil
    local site = Turf.lobby and Turf.lobby.site and Turf.site(Turf.lobby.site) or Turf.pickSiteView()
    local warOn = Turf.war ~= nil and Turf.war.state ~= "resolved" or nil
    for i, e in ipairs(Turf.queue) do
        local view = { queued = true, position = i, total = #Turf.queue, min = Turf.minPlayers(),
            lobbyMs = lobbyMs, site = site and site.label or nil, gang = e.gangLabel, kit = e.kit or defaultKit().id,
            warOn = warOn }
        local key = ("%d|%d|%d|%s|%s|%s|%s"):format(i, #Turf.queue, view.min, tostring(Turf.lobby and Turf.lobby.endsAt),
            tostring(view.site), view.kit, tostring(warOn))
        if force or key ~= e.pushedKey then
            e.pushedKey = key
            W().state(e.id, nil, view)
        end
    end
    Turf.lastQueuePush = now
end

-- The client has no shared activity HUD (older Light RP): banners and the result go
-- out as notifications too.
function Turf.markHudless(id)
    local m = Turf.memberOf(id)
    if m then m.hudless = true end
    local _, _, e = Turf.position(id)
    if e then e.hudless = true end
    local _, se = Turf.sweepEntry(id)
    if se then se.hudless = true end
    return m ~= nil or e ~= nil or se ~= nil
end

-- The leading vote without moving the rotation cursor.
function Turf.pickSiteView()
    local cursor = Turf.siteCursor
    local site = Turf.pickSite()
    Turf.siteCursor = cursor
    return site
end

-- ---------------------------------------------------------------- status (hub)

function Turf.status(now)
    local war, queued = Turf.war, #Turf.queue
    if war and war.state ~= "closed" then
        local n = Turf.counts(war)
        local detail
        if war.state == "running" then
            detail = ("%s · %s vs %s · ~%d min left"):format(war.site.label, sideLabel(war, 1), sideLabel(war, 2),
                math.max(1, math.ceil((war.endsAt - now) / 60000)))
        elseif war.state == "resolved" then
            detail = ("%s · war over"):format(war.site.label)
        else
            detail = ("%s · %s vs %s · starting"):format(war.site.label, sideLabel(war, 1), sideLabel(war, 2))
        end
        if war.botWar then detail = detail .. " · bots" end
        return { phase = "running", players = n[1] + n[2], queued = queued, joinable = true, detail = detail }
    end
    if Turf.lobby then
        local site = Turf.lobby.site and Turf.site(Turf.lobby.site)
        return { phase = "lobby", players = 0, queued = queued, joinable = true,
            detail = ("%s%d/%d fighters · starting soon"):format(site and (site.label .. " · ") or "", queued, Turf.minPlayers()) }
    end
    if queued > 0 then
        return { phase = "lobby", players = 0, queued = queued, joinable = true,
            detail = ("%d/%d fighters queued"):format(queued, Turf.minPlayers()) }
    end
    if Turf.schedule then
        local site = Turf.site(Turf.schedule.site)
        return { phase = "idle", players = 0, queued = 0, joinable = true,
            detail = ("Scheduled: %s in ~%d min"):format(site and site.label or "a district",
                math.max(1, math.ceil((Turf.schedule.at - now) / 60000))) }
    end
    if Turf.botMode() then
        return { phase = "idle", players = 0, queued = 0, joinable = true,
            detail = "Staff bot mode: one fighter starts a war, bots fill the sides. Nothing counts." }
    end
    return { phase = "idle", players = 0, queued = 0, joinable = true,
        detail = "Gang war for a district. Queue and keep playing." }
end

-- The Gang Sweep's hub line.
function Turf.pveStatus(now)
    local P = cfg().pve
    local running, humans, waiting = 0, 0, 0
    for _, war in ipairs(Turf.sweeps) do
        if war.state ~= "closed" then
            running = running + 1
            local n = Turf.counts(war)
            humans = humans + n[1] + n[2]
        end
    end
    for _, g in ipairs(Turf.sweepQueue) do waiting = waiting + #g.entries end
    if running > 0 then
        return { phase = "running", players = humans, queued = waiting, joinable = true,
            detail = ("%d sweep%s on (%d max)%s"):format(running, running > 1 and "s" or "", P.maxSweeps or 2,
                waiting > 0 and (" · %d waiting"):format(waiting) or "") }
    end
    if waiting > 0 then
        return { phase = "lobby", players = 0, queued = waiting, joinable = true, detail = "A crew is gathering" }
    end
    return { phase = "idle", players = 0, queued = 0, joinable = true,
        detail = "Take a district from an NPC gang. Solo or with your crew." }
end

-- ---------------------------------------------------------------- schedule

function Turf.scheduleWar(siteId, minutes, now)
    local site = siteId and siteId ~= "auto" and Turf.site(siteId) or nil
    if siteId and siteId ~= "auto" and not site then return false, "Unknown site. Sites: " .. Turf.siteList() end
    if site == nil then site = Turf.pickSiteView() end
    minutes = math.max(0, math.min(240, tonumber(minutes) or 10))
    Turf.schedule = { site = site.id, at = now + math.floor(minutes * 60000), announced = {} }
    local text = minutes > 0 and ("TURF WAR at %s (%s) in %d min. Queue at The Crossing or /turf join.")
        :format(site.label, site.district or "Night City", math.ceil(minutes))
        or ("TURF WAR at %s is opening now. Queue at The Crossing or /turf join."):format(site.label)
    C().announce(text, { title = "TURF WAR", durationMs = 10000 })
    for _, mark in ipairs(cfg().lobby.announceAt or {}) do
        if mark * 1000 >= minutes * 60000 then Turf.schedule.announced[mark] = true end
    end
    log("war scheduled at %s in %.1f min", site.id, minutes)
    return true, ("Turf war scheduled at %s in %s min."):format(site.label, tostring(minutes))
end

function Turf.siteList()
    local parts = {}
    for _, site in ipairs(cfg().sites) do
        parts[#parts + 1] = site.id .. (site.enabled == false and " (staff)" or "")
    end
    return table.concat(parts, ", ")
end

local function tickSchedule(now)
    local s = Turf.schedule
    if not s then return end
    local site = Turf.site(s.site)
    local left = s.at - now
    for _, mark in ipairs(cfg().lobby.announceAt or {}) do
        if not s.announced[mark] and left <= mark * 1000 and left > 0 then
            s.announced[mark] = true
            local when = mark >= 60 and ("%d min"):format(math.floor(mark / 60)) or ("%d s"):format(mark)
            C().announce(("TURF WAR at %s in %s. Queue at The Crossing or /turf join."):format(site.label, when),
                { title = "TURF WAR", durationMs = 8000 })
        end
    end
    if left <= 0 and Turf.war == nil then
        Turf.schedule = nil
        Turf.lobby = { site = site.id, endsAt = now + (cfg().lobby.scheduledSeconds or 60) * 1000, scheduled = true }
        C().announce(("TURF WAR at %s is open: queue now at The Crossing or /turf join. Starts in %d s.")
            :format(site.label, cfg().lobby.scheduledSeconds or 60), { title = "TURF WAR", durationMs = 10000 })
        log("scheduled lobby opened at %s", site.id)
    end
end

-- ---------------------------------------------------------------- lobby

local function tickLobby(now)
    local min, max = Turf.minPlayers(), cfg().activity.maxPlayers or 24
    local lobby = Turf.lobby
    if lobby == nil then
        if #Turf.queue >= min then
            Turf.lobby = { site = nil, endsAt = now + (cfg().lobby.seconds or 45) * 1000 }
            for _, e in ipairs(Turf.queue) do
                W().notify(e.id, "info", ("Turf War starts in %d s. Finish what you are doing: you will be pulled in.")
                    :format(cfg().lobby.seconds or 45), 6000)
            end
            log("lobby opened (%d queued)", #Turf.queue)
        end
        return
    end
    if not lobby.scheduled and #Turf.queue < min then
        Turf.lobby = nil
        for _, e in ipairs(Turf.queue) do W().notify(e.id, "info", "Not enough fighters any more: the turf war waits.", 5000) end
        log("lobby closed: %d queued", #Turf.queue)
        return
    end
    if #Turf.queue >= max then
        lobby.endsAt = math.min(lobby.endsAt, now + (cfg().lobby.fullSeconds or 10) * 1000)
    end
    if now >= lobby.endsAt then Turf.launch(now) end
end

-- A fresh bucket of our range, never one a live war is using.
local function allocateBucket()
    local b = cfg().buckets
    local inUse = {}
    for _, w in ipairs(Turf.wars()) do inUse[w.bucket] = true end
    local cursor = Turf.bucketCursor or (b.from - 1)
    for _ = 1, b.to - b.from + 1 do
        cursor = cursor + 1
        if cursor > b.to then cursor = b.from end
        if not inUse[cursor] then break end
    end
    Turf.bucketCursor = cursor
    return cursor
end

-- The lobby is over: whoever can go goes, sides are formed, Light RP takes them.
-- In staff bot mode one fighter is enough: the sides are filled with bots.
function Turf.launch(now)
    local lobby = Turf.lobby
    Turf.lobby = nil
    local site = lobby and lobby.site and Turf.site(lobby.site) or Turf.pickSite(Turf.queue)
    local botWar = Turf.botMode()
    local ready = {}
    for _, e in ipairs(Turf.queue) do
        if W().connected(e.id) then
            local ok, why = C().check(e.id)
            if ok then
                ready[#ready + 1] = e
                e.notReadySince = nil
            else
                e.notReadySince = e.notReadySince or now
                local every = (cfg().queue.notReadyNoticeSeconds or 30) * 1000
                if not e.notReadyNoticeAt or now - e.notReadyNoticeAt >= every then
                    e.notReadyNoticeAt = now
                    W().notify(e.id, "warning", ("The turf war is starting, but you can't go: %s"):format(tostring(why)), 6000)
                end
            end
        end
    end
    -- Not ready for too long: out of the queue.
    local dropAfter = (cfg().queue.notReadyDropSeconds or 120) * 1000
    for i = #Turf.queue, 1, -1 do
        local e = Turf.queue[i]
        if e.notReadySince and now - e.notReadySince >= dropAfter then
            table.remove(Turf.queue, i)
            W().clear(e.id)
            W().notify(e.id, "info", "You left the turf war queue (not ready).", 5000)
        end
    end
    local function callOff(text)
        for _, e in ipairs(Turf.queue) do W().notify(e.id, "info", text, 6000) end
        if lobby and lobby.scheduled then C().announce(("Turf war at %s called off: %s"):format(site.label, text),
            { title = "TURF WAR", durationMs = 8000 }) end
        log("launch called off: %s", text)
        return nil
    end
    if #ready < Turf.minPlayers() then
        return callOff(("not enough fighters ready (%d/%d)."):format(#ready, Turf.minPlayers()))
    end
    local m = cfg().match
    local maxPlayers = cfg().activity.maxPlayers
    -- Bot mode: nobody is benched for balance, bots even the sides.
    local opts = { maxPlayers = maxPlayers, maxImbalance = botWar and maxPlayers or m.maxImbalance,
        allowTurncoats = m.allowTurncoats }
    local form = R.formSides(ready, opts)
    if not botWar then
        if #form.sides[1] == 0 or #form.sides[2] == 0 then
            -- One crew alone: it splits (a training war, mercenaries on the other side).
            -- A Light RP squad never splits: it stays whole, and the war waits.
            opts.allowTurncoats = true
            form = R.formSides(ready, opts)
        end
        if #form.sides[1] == 0 or #form.sides[2] == 0 then
            return callOff("a war needs two sides.")
        end
    else
        -- A side nobody of a gang holds gets a rival gang (its bots wear its colours).
        for s = 1, 2 do
            if form.gangs[s] == nil and #form.sides[s] == 0 then
                form.gangs[s] = R.rivalGang(cfg().bots.gangOrder, form.gangs[s == 1 and 2 or 1], cfg().gangs)
            end
        end
    end
    -- Light RP takes them (activityEnter). A refusal costs that fighter his place only.
    local byId = {}
    for _, e in ipairs(ready) do byId[e.id] = e end
    local entered = { {}, {} }
    for s = 1, 2 do
        for _, id in ipairs(form.sides[s]) do
            local ok, why = C().enter(id)
            if ok then
                entered[s][#entered[s] + 1] = id
            else
                Turf.dequeue(id)
                W().clear(id)
                W().notify(id, "warning", ("You could not join the turf war: %s"):format(tostring(why)), 6000)
            end
        end
    end
    local filled
    if botWar then filled = #entered[1] + #entered[2] >= 1
    else filled = #entered[1] > 0 and #entered[2] > 0 and #entered[1] + #entered[2] >= 2 end
    if not filled then
        for s = 1, 2 do for _, id in ipairs(entered[s]) do C().leave(id, { returnPlayer = true }) end end
        return callOff("a side could not be filled.")
    end
    for s = 1, 2 do for _, id in ipairs(entered[s]) do Turf.dequeue(id) end end
    for _, id in ipairs(form.bench) do
        if byId[id] then W().notify(id, "info", "Your crew is over-represented: you stay first in line and go in as reinforcements.", 7000) end
    end
    return Turf.start(site, form, entered, byId, now, { botWar = botWar })
end

-- ---------------------------------------------------------------- war start

local function sideInfo(form, s)
    local gang = form.gangs[s]
    if gang then
        local gi = R.gangInfo(gang, nil, cfg().gangs)
        return { gang = gang, label = gi.label, color = gi.color }
    end
    local free = cfg().freeSides[s] or cfg().freeSides[1]
    return { gang = nil, label = free.label, color = free.color }
end

local function newMember(war, id, side, merc, entry, now)
    war.sides[side].slots = war.sides[side].slots + 1
    local m = { id = id, side = side, merc = merc == true, slot = war.sides[side].slots,
        name = entry and entry.name or W().name(id), identifier = entry and entry.identifier,
        characterKey = entry and entry.characterKey, gang = entry and entry.gang, gangLabel = entry and entry.gangLabel,
        kit = entry and entry.kit or defaultKit().id, hudless = entry and entry.hudless or nil, squad = entry and entry.squad,
        kills = 0, deaths = 0, captures = 0, holdSeconds = 0, playedMs = 0, joinedAt = now, kitToken = 0 }
    -- A gang's own colours only: a merc who belongs to a gang is still a mercenary here.
    if war.sides[side].gang and m.gang == war.sides[side].gang then m.merc = false end
    war.members[id] = m
    war.order[#war.order + 1] = id
    W().setTeam(id, cfg().teamIds[side])
    return m
end

local function coverOf(war)
    return { title = isSweep(war) and "GANG SWEEP" or "TURF WAR", subtitle = war.site.label, zone = war.site.district or "Night City" }
end

local function placeMember(war, m, now, cover)
    local point = lifted(R.sideSpawn(war.site, m.side, m.slot))
    m.placing, m.placed = true, nil
    local token = war.token
    W().site(m.id, Turf.sitePayload(war, m))
    W().place(m.id, point, war.bucket, function(ok, why)
        m.placing = nil
        Turf.onPlaced(war.id, m.id, token, ok, why)
    end, cover)
end

-- A war (or a sweep) is created and its fighters placed.
--   opts = { kind = "pvp"|"pve", activity, botWar, squadKey, target, timeLimitSeconds,
--            rewards, holder = side holding every zone at the start }
function Turf.start(site, form, entered, byId, now, opts)
    opts = opts or {}
    local bucket = allocateBucket()
    if Turf.nextWarId == nil then Turf.nextWarId = now + 1 end
    local kind = opts.kind or "pvp"
    local war = { id = Turf.nextWarId, site = site, bucket = bucket, state = "placing", members = {}, order = {},
        sides = {}, zones = R.newZones(site), createdAt = now, token = 1, carry = { 0, 0 }, playedMs = 0,
        placeDeadline = now + (cfg().match.placeTimeoutSeconds or 40) * 1000, boardDirty = true, lastHud = 0, lastBoard = 0,
        kind = kind, activity = opts.activity or cfg().activity.id, botWar = opts.botWar == true or nil,
        squadKey = opts.squadKey, target = opts.target or cfg().match.targetScore,
        timeLimitMs = (opts.timeLimitSeconds or cfg().match.timeLimitSeconds or 660) * 1000,
        rewards = opts.rewards or cfg().rewards }
    Turf.nextWarId = Turf.nextWarId + 1
    for s = 1, 2 do
        local info = sideInfo(form, s)
        war.sides[s] = { gang = info.gang, label = info.label, color = info.color, score = 0, slots = 0 }
    end
    if opts.holder then
        for _, zone in ipairs(war.zones) do zone.owner = opts.holder end
    end
    war.zoneRate = opts.zoneRate
    if kind == "pve" then Turf.sweeps[#Turf.sweeps + 1] = war else Turf.war = war end
    W().setupBucket(bucket)
    local cover = coverOf(war)
    for s = 1, 2 do
        for _, id in ipairs(entered[s]) do
            local m = newMember(war, id, s, form.merc[id], byId[id], now)
            placeMember(war, m, now, cover)
        end
    end
    if hasBots(war) then B().plan(war, now) end
    local n = Turf.counts(war)
    log("%s %d created at %s bucket %d: %s (%d%s) vs %s (%d%s)", kind == "pve" and "sweep" or "war", war.id, site.id, bucket,
        war.sides[1].label, n[1], war.bots and ("+" .. B().count(war, 1) .. " bots") or "",
        war.sides[2].label, n[2], war.bots and ("+" .. B().count(war, 2) .. " bots") or "")
    Turf.pushHud(war, now)
    return war
end

function Turf.onPlaced(warId, id, token, ok, why)
    local war = Turf.warById(warId)
    if war == nil or war.token ~= token then return end
    local m = war.members[id]
    if not present(m) then return end
    m.placed, m.placeError = ok == true, why
    if not ok then log("war %d: placement of %d failed: %s", war.id, id, tostring(why)) return end
    if war.state == "running" then
        -- A late joiner (or a reinforcement) lands: protected, armed.
        local now = W().now()
        m.aliveSince = now
        m.protectedUntil = now + (cfg().life.protectionSeconds or 3) * 1000
        Turf.equip(war, m)
        war.boardDirty = true
    elseif war.state == "countdown" then
        -- (a crew member who caught up with his sweep's countdown) armed for the start
        m.aliveSince = W().now()
        Turf.equip(war, m)
        war.boardDirty = true
    end
end

-- ---------------------------------------------------------------- kits

function Turf.equip(war, m)
    m.kitToken = (m.kitToken or 0) + 1
    local token, warId = m.kitToken, war.id
    local kit = Turf.kit(m.kit) or defaultKit()
    W().equip(m.id, kit, function()
        local w = Turf.warById(warId)
        return w ~= nil and w.state ~= "resolved" and w.state ~= "closed" and present(m) and m.kitToken == token and not m.down
    end)
end

-- A kit picked: at once in the countdown or right after a spawn, else from the next life.
function Turf.chooseKit(id, kitId, now)
    local kit = Turf.kit(kitId)
    if not kit then return false, "Unknown kit." end
    local m, war = Turf.memberOf(id)
    if not m then
        local _, _, e = Turf.position(id)
        if not e then _, e = Turf.sweepEntry(id) end
        if not e then return false, "You are not queued or in a turf war." end
        e.kit = kit.id
        return true, ("Kit %s ready for the war."):format(kit.label)
    end
    m.kit = kit.id
    if war.state == "placing" then return true, ("Kit %s ready for the war."):format(kit.label) end
    if war.state == "resolved" then return true, ("Kit %s."):format(kit.label) end
    local swap = (cfg().life.kitSwapSeconds or 6) * 1000
    if war.state == "countdown" or (war.state == "running" and not m.down and m.aliveSince and now - m.aliveSince <= swap) then
        Turf.equip(war, m)
        return true, ("Kit %s."):format(kit.label)
    end
    return true, ("Kit %s from your next life."):format(kit.label)
end

function Turf.nextKit(id, now)
    local m = Turf.memberOf(id)
    local current
    if m then current = m.kit else
        local _, _, e = Turf.position(id)
        if not e then _, e = Turf.sweepEntry(id) end
        current = e and e.kit
    end
    current = current or defaultKit().id
    local kits = cfg().kits
    for i, kit in ipairs(kits) do
        if kit.id == current then return Turf.chooseKit(id, kits[i % #kits + 1].id, now) end
    end
    return Turf.chooseKit(id, kits[1].id, now)
end

-- ---------------------------------------------------------------- combat

-- Light RP's damage arbiter chain, our verdict. Fighters hurt each other only in a
-- running war, across sides, in this bucket's scope; fresh spawns are protected
-- (until they shoot). A bot's hit (when the platform runs Open77.players.damage through
-- the arbiters) follows the same rules. nil = not our business.
function Turf.damage(event, now)
    if type(event) ~= "table" then return nil end
    local v, a = tonumber(event.victim), tonumber(event.attacker)
    local vm, vwar
    if v then vm, vwar = Turf.memberOf(v) end
    local bot, bwar = B().ofNpc(event.attacker)
    if bot then
        if vm == nil or vwar ~= bwar then return false end -- a bot never hurts anyone outside its war
        if bwar.state ~= "running" or bot.side == vm.side then return false end
        if (vm.protectedUntil or 0) > now then return false end
        return true
    end
    if B().ofNpc(event.victim) then return nil end -- a bot's own pricing (TurfBots.onPlayerHit)
    local am, awar
    if a and a > 0 then am, awar = Turf.memberOf(a) end
    if vm == nil and am == nil then return nil end
    if vm and am and vwar ~= awar then return false end
    local war = vwar or awar
    if war.state ~= "running" then return false end
    if vm and am then
        if vm ~= am and vm.side == am.side then return false end
        if vm ~= am and (vm.protectedUntil or 0) > now then return false end
        if vm ~= am then am.protectedUntil = nil end
        return true
    end
    if vm then
        if a ~= nil and a > 0 then return false end -- a player outside the war
        if (vm.protectedUntil or 0) > now then return false end
        return true -- environment, falls
    end
    return false -- a fighter shooting someone outside the war
end

-- A fighter went down (death event, or seen down by the step). With no killer of his
-- war named, the bot that hit him last (within the credit window) gets the kill.
function Turf.onDeath(victimId, killerId, now, rawKiller)
    local m, war = Turf.memberOf(victimId)
    if not m or m.down then return false end
    m.down, m.downAt = true, now
    m.respawning, m.respawnTries = nil, 0
    m.deathPos = m.lastPos or W().position(victimId)
    m.outSince = nil
    if war.state ~= "running" then
        -- Before the fight (or after it): straight back up on the spawn.
        m.respawnAt = now
        return true
    end
    m.deaths = m.deaths + 1
    m.respawnAt = now + (cfg().life.respawnSeconds or 6) * 1000
    local k = killerId and war.members[killerId] or nil
    if k and k ~= m and present(k) and k.side ~= m.side then
        k.kills = k.kills + 1
        war.sides[k.side].score = war.sides[k.side].score + (cfg().scoring.killPoints or 0)
        feedAll(war, ("%s eliminated %s"):format(k.name, m.name), "danger")
    else
        local bot
        if war.bots then
            bot = B().lastHitOn(war, victimId, now)
            if not bot and rawKiller ~= nil then
                local b, bw = B().ofNpc(rawKiller)
                if bw == war then bot = b end
            end
        end
        if bot and bot.side ~= m.side then
            B().lastHit[victimId] = nil
            bot.kills = bot.kills + 1
            war.sides[bot.side].score = war.sides[bot.side].score + (cfg().scoring.killPoints or 0)
            feedAll(war, ("%s eliminated %s"):format(bot.name, m.name), "danger")
        else
            feedAll(war, ("%s is down"):format(m.name), "info")
        end
    end
    war.boardDirty = true
    return true
end

-- A bot went down. killer = { kind = "player"|"bot", id } | nil.
function Turf.botDied(war, bot, killer, now)
    local running = war.state == "running"
    if not B().markDown(war, bot, now, running) then return false end
    if not running then return true end
    local name, side
    if killer and killer.kind == "player" then
        local k = war.members[killer.id]
        if present(k) and k.side ~= bot.side then
            k.kills = k.kills + 1
            name, side = k.name, k.side
        end
    elseif killer and killer.kind == "bot" then
        local kb = B().get(war, killer.id)
        if kb and kb.side ~= bot.side then
            kb.kills = kb.kills + 1
            name, side = kb.name, kb.side
        end
    end
    if name then
        war.sides[side].score = war.sides[side].score + (cfg().scoring.killPoints or 0)
        feedAll(war, ("%s eliminated %s"):format(name, bot.name), "danger")
    else
        feedAll(war, ("%s is down"):format(bot.name), "info")
    end
    war.boardDirty = true
    return true
end

local function onAlive(war, m, now)
    m.down, m.respawning, m.respawnTries, m.respawnAt = false, nil, 0, nil
    m.aliveSince = now
    m.protectedUntil = now + (cfg().life.protectionSeconds or 3) * 1000
    if war.state == "running" or war.state == "countdown" then Turf.equip(war, m) end
end

-- Down fighters: respawn when their time comes, then wait for the new life.
local function tickRespawns(war, now)
    local life = cfg().life
    eachPresent(war, function(m)
        if not m.down then return end
        local phase = W().phase(m.id)
        if phase ~= nil and not W().isDown(phase) then
            -- Up again: the respawn we asked for, or (a few seconds on) a revive from
            -- elsewhere. Right after the death event the life state may still read
            -- "alive": that is not a new life.
            if m.respawning or now - (m.downAt or 0) >= 3000 then onAlive(war, m, now) end
            return
        end
        if m.respawning then
            if now - m.respawning > 15000 then m.respawning, m.respawnAt = nil, now end -- never arrived: ask again
            return
        end
        if m.respawnAt and now >= m.respawnAt then
            local point, zoneId = R.respawnPoint(war, war.site, m.side, m.slot, m.deathPos, life)
            point = lifted(point)
            local ok, why = W().respawn(m.id, point, war.bucket)
            if ok then
                m.respawning = now
                m.respawnZone = zoneId
            elseif W().alive(m.id) == true then
                onAlive(war, m, now)
            else
                m.respawnTries = (m.respawnTries or 0) + 1
                log("war %d: respawn of %d refused (%s), attempt %d", war.id, m.id, tostring(why), m.respawnTries)
                m.respawnAt = now + (m.respawnTries <= (life.respawnRetries or 5) and 2000 or 5000)
            end
        end
    end)
end

-- The PvP scope: the living fighters in the bucket. Rebuilt when that roster changes
-- (a death, a respawn, a join, a departure) and every 15 s to heal a silent removal
-- (a re-registered body leaves a scope on its own).
function Turf.syncScope(war, now, force)
    local roster = {}
    eachPresent(war, function(m)
        if m.placed and not m.down and m.aliveSince and now - m.aliveSince >= 1000 then roster[#roster + 1] = m.id end
    end)
    table.sort(roster)
    local key = table.concat(roster, ",")
    if not force and key == war.scopeKey and now - (war.scopeAt or 0) < 15000 then return end
    if war.scope then W().removeScope(war.scope) end
    war.scope, war.scopeKey, war.scopeAt = nil, key, now
    if #roster < 2 then return end
    local scope, why = W().createScope(war.bucket, roster)
    if scope then
        war.scope, war.scopeError = scope, nil
    elseif why ~= war.scopeError then
        war.scopeError = why
        log("war %d: PvP scope refused (%s) for %s", war.id, tostring(why), key)
    end
end

-- ---------------------------------------------------------------- the step

function Turf.onCapture(war, zone, ev, now)
    local s = ev.side
    local scoring = cfg().scoring
    war.sides[s].score = war.sides[s].score + (scoring.captureBonus or 0)
    local names = {}
    eachPresent(war, function(m)
        if m.side == s and not m.down and m.zoneIndex == zone.index then
            m.captures = m.captures + 1
            names[#names + 1] = m.name
        end
    end)
    if war.bots then
        for _, name in ipairs(B().creditCapture(war, zone.index, s)) do names[#names + 1] = name end
    end
    local label = ("%s · %s"):format(zone.def.id, zone.def.label)
    feedAll(war, ("%s captured %s"):format(sideLabel(war, s), label), "success")
    eachPresent(war, function(m)
        local mine = m.side == s
        push(m, "banner", { title = mine and ("ZONE %s CAPTURED"):format(zone.def.id) or ("ZONE %s LOST"):format(zone.def.id),
            text = ("%s - %s"):format(zone.def.label, sideLabel(war, s)), tone = mine and "success" or "danger", durationMs = 3500 })
    end)
    war.boardDirty = true
    log("war %d: %s captured %s (%s)", war.id, sideLabel(war, s), zone.def.id, table.concat(names, ", "))
end

function Turf.step(war, now)
    local dt = math.max(0, math.min(3, (now - (war.lastStep or now)) / 1000))
    war.lastStep = now
    local cap, life = cfg().capture, cfg().life
    local counts = {}
    for i = 1, #war.zones do counts[i] = { 0, 0 } end
    eachPresent(war, function(m)
        m.zoneIndex = nil
        if not m.placed then return end
        local phase = W().phase(m.id)
        if phase and W().isDown(phase) then
            if not m.down then Turf.onDeath(m.id, nil, now) end
            return
        end
        if m.down then return end
        local p = W().position(m.id)
        if p == nil or (p.bucket ~= nil and p.bucket ~= war.bucket) then return end
        m.lastPos = p
        for i, zone in ipairs(war.zones) do
            if R.inZone(zone.def, p, cap.height) then
                m.zoneIndex = i
                counts[i][m.side] = counts[i][m.side] + 1
                break
            end
        end
        if R.inBounds(war.site.bounds, p) then
            m.outSince = nil
        else
            m.outSince = m.outSince or now
            if now - m.outSince >= (life.outOfBoundsSeconds or 8) * 1000 then
                m.outSince = nil
                W().teleport(m.id, lifted(R.sideSpawn(war.site, m.side, m.slot)), war.bucket)
                W().notify(m.id, "warning", "You left the war zone: back to your side's spawn.", 4000)
            end
        end
    end)
    if war.bots then B().step(war, now, counts, dt) end
    if war.state ~= "running" then return end -- (a bot's death cannot end it, but stay safe)
    for i, zone in ipairs(war.zones) do
        local ev = R.stepZone(zone, counts[i], dt, cap)
        if ev and ev.kind == "captured" then Turf.onCapture(war, zone, ev, now) end
    end
    eachPresent(war, function(m)
        if m.placed then m.playedMs = (m.playedMs or 0) + dt * 1000 end
        local zone = m.zoneIndex and war.zones[m.zoneIndex]
        if zone and not m.down and (zone.owner == m.side or zone.capturing == m.side) then
            m.holdSeconds = (m.holdSeconds or 0) + dt
        end
    end)
    if war.bots then
        B().hold(war, dt)
        B().retask(war, now)
    end
    war.playedMs = (war.playedMs or 0) + dt * 1000
    local winner = R.stepScore(war, dt, cfg().scoring, war.target)
    if winner ~= nil then return Turf.finish(war, winner, "target", now) end
    if now >= war.endsAt then return Turf.finish(war, R.timeWinner(war), "time", now) end
    Turf.syncScope(war, now)
end

-- ---------------------------------------------------------------- late joiners

-- The side a squadmate already fights on in this war, or nil.
local function crewSide(war, squad)
    if squad == nil then return nil end
    for _, id in ipairs(war.order) do
        local o = war.members[id]
        if present(o) and o.squad == squad then return o.side end
    end
    return nil
end

local function admitLate(war, now)
    local m = cfg().match
    if not m.joinInProgress or war.state ~= "running" then return end
    if war.endsAt - now < (m.joinCutoffSeconds or 180) * 1000 then return end
    local maxPlayers = cfg().activity.maxPlayers
    local admitted = 0
    local i = 1
    while i <= #Turf.queue and admitted < 2 do
        local e = Turf.queue[i]
        local counts = Turf.counts(war)
        local side, merc = R.placeLate(counts, { war.sides[1].gang, war.sides[2].gang }, e.gang,
            { maxPlayers = maxPlayers, maxImbalance = war.botWar and maxPlayers or m.maxImbalance,
                allowTurncoats = m.allowTurncoats, crewSide = crewSide(war, e.squad) })
        local moved = false
        if side and W().connected(e.id) then
            local ok = C().check(e.id)
            if ok and C().enter(e.id) then
                table.remove(Turf.queue, i)
                moved = true
                admitted = admitted + 1
                local member = war.members[e.id]
                if member then
                    -- Back in the same war (left earlier): a fresh entry, his tallies kept.
                    member.left, member.leaving, member.released, member.gone, member.resultSent = nil, nil, nil, nil, nil
                    member.side, member.merc, member.squad = side, merc, e.squad
                    member.down = false
                    W().setTeam(e.id, cfg().teamIds[side])
                else
                    member = newMember(war, e.id, side, merc, e, now)
                end
                placeMember(war, member, now, coverOf(war))
                -- Bot mode keeps the numbers: a bot of that side makes room.
                if war.botWar then B().retire(war, side, now) end
                if war.bots then B().welcome(war, member) end
                feedAll(war, ("%s joins %s%s"):format(member.name, sideLabel(war, side), member.merc and " (mercenary)" or ""), "info")
                war.boardDirty = true
            end
        end
        if not moved then i = i + 1 end
    end
end

-- ---------------------------------------------------------------- the end

local function notCounted(war)
    if war.botWar then return "not counted (bot war)" end
    if isSweep(war) then return "not counted (too short)" end
    return "not counted (too short or too few crews)"
end

-- The board each result carries for Light RP's end-of-match recap (op77_lightrp
-- server/modules/recap.lua): every fighter (leavers marked), the bots (negative ids,
-- the ones a joining player retired too when they did anything), each side's score.
-- Damage is not measured here (the zones and kills are the war's numbers).
function Turf.recapOf(war)
    local scoring = cfg().scoring
    local rows = {}
    local function add(p, bot, left)
        rows[#rows + 1] = { id = p.id, name = p.name, side = p.side, bot = bot or nil, left = left or nil,
            kills = p.kills or 0, deaths = p.deaths or 0, captures = p.captures or 0,
            holdS = math.floor(p.holdSeconds or 0), score = R.personalScore(p, scoring),
            inMatchMs = math.floor(p.playedMs or 0) }
    end
    for _, id in ipairs(war.order or {}) do
        local m = war.members[id]
        if m then add(m, false, m.left == true or m.gone == true) end
    end
    for _, b in ipairs(type(war.bots) == "table" and war.bots or {}) do
        local did = (b.kills or 0) + (b.deaths or 0) + (b.captures or 0) > 0
        if not b.failed and (not b.retired or did) then add(b, true, b.retired == true) end
    end
    local resolved = war.state == "resolved" or war.state == "closed"
    local lines = { { label = "Site", value = tostring(war.site.label or war.site.id) } }
    if war.site.district then lines[#lines + 1] = { label = "District", value = tostring(war.site.district) } end
    if resolved and war.counted == false then lines[#lines + 1] = { label = "Counted", value = notCounted(war) } end
    return { matchId = ("turf:%s:%s@%d"):format(tostring(war.kind or "pvp"), tostring(war.id), math.floor(tonumber(war.createdAt) or 0)),
        detail = isSweep(war) and "Gang Sweep" or "Turf War", durationMs = math.floor(war.playedMs or 0),
        sides = { { id = 1, label = sideLabel(war, 1), score = war.sides[1].score or 0 },
            { id = 2, label = sideLabel(war, 2), score = war.sides[2].score or 0 } },
        winnerSide = resolved and tonumber(war.winner) or nil, rows = rows, lines = lines,
        columns = { "kills", "deaths", "captures", "holdS", "score" } }
end

-- Never lets a recap failure touch a result.
local function recapOf(war)
    local ok, recap = pcall(Turf.recapOf, war)
    if ok then return recap end
    log("war %s: recap failed: %s", tostring(war.id), tostring(recap))
    return nil
end

local function resultFor(war, m, winner, counted)
    local won = winner ~= 0 and winner == m.side
    local result = {
        placement = (winner == 0 or won) and 1 or 2,
        score = R.personalScore(m, cfg().scoring),
        won = won,
        stats = { captures = m.captures, holdSeconds = math.floor(m.holdSeconds or 0), kills = m.kills, deaths = m.deaths,
            gang = m.gang, mercenary = m.merc or false, side = sideLabel(war, m.side), site = war.site.id,
            forfeit = m.left or nil, mode = war.kind ~= "pvp" and war.kind or nil,
            bots = war.bots and B().count(war) > 0 and B().count(war) or nil },
        reputation = R.reputation(m, war, winner, war.rewards or cfg().rewards, counted),
        recap = recapOf(war), -- Light RP's end-of-match recap (recap.lua)
    }
    -- Staff bot mode: the core records nothing (and is told so).
    if war.botWar then result.test = true end
    return result
end
Turf.resultFor = resultFor

function Turf.finish(war, winner, reason, now)
    if war.state == "resolved" or war.state == "closed" then return end
    war.state, war.winner, war.reason, war.resolvedAt = "resolved", winner, reason, now
    war.releaseAt = now + (cfg().match.scoreboardSeconds or 10) * 1000
    war.token = war.token + 1
    eachPresent(war, function(m)
        if m.frozen then m.frozen = nil; W().freeze(m.id, false) end
    end)
    if war.scope then W().removeScope(war.scope); war.scope = nil end
    local counted
    if war.botWar then counted = false
    elseif isSweep(war) then counted = R.pveCounted(war, war.rewards)
    else counted = R.counted(war, cfg().rewards, Turf.minAccounts()) end
    war.counted = counted
    -- Weekly influence: a real turf war only (never a bot war, never a sweep). Memory
    -- now, database on a thread.
    local influence = war.kind == "pvp" and not war.botWar
    local deltas = (counted and influence) and R.influence(war, winner, cfg().influence) or {}
    local fighters = 0
    for _ in pairs(war.members) do fighters = fighters + 1 end
    if influence and not war.void then
        TurfInfluence.record(deltas, { site = war.site.id, gangA = war.sides[1].gang, gangB = war.sides[2].gang,
            scoreA = war.sides[1].score, scoreB = war.sides[2].score, winner = winner, fighters = fighters,
            durationS = math.floor((war.playedMs or 0) / 1000), counted = counted }, W().unix())
    end
    local top = {}
    if influence then
        for i, row in ipairs(TurfInfluence.list()) do
            if i > (cfg().influence.topSize or 6) then break end
            top[i] = { gang = row.gang, label = row.label, color = row.color, points = row.points, wins = row.wins,
                delta = deltas[row.gang] and deltas[row.gang].points or nil }
        end
    end
    war.influenceTop = top
    log("%s %d resolved (%s): %s %d - %d %s winner=%s counted=%s void=%s", isSweep(war) and "sweep" or "war", war.id,
        tostring(reason), sideLabel(war, 1), war.sides[1].score, war.sides[2].score, sideLabel(war, 2), tostring(winner),
        tostring(counted), tostring(war.void))
    local score = ("%s %d - %d %s"):format(sideLabel(war, 1), war.sides[1].score, war.sides[2].score, sideLabel(war, 2))
    Turf.pushHud(war, now)
    Turf.pushBoard(war, now)
    eachPresent(war, function(m)
        local lines = {}
        local title, tone
        if war.void then
            title, tone = isSweep(war) and "SWEEP CALLED OFF" or "WAR CALLED OFF", "info"
            lines[#lines + 1] = { label = "Result", value = war.voidReason or "Nothing counts." }
        else
            local result = resultFor(war, m, winner, counted)
            if not m.resultSent then
                C().result(m.id, result, war.activity)
                m.resultSent = true
            end
            title = winner == 0 and "DRAW" or (result.won and "VICTORY" or "DEFEAT")
            tone = winner == 0 and "info" or (result.won and "success" or "danger")
            lines[#lines + 1] = { label = "Kills / deaths", value = ("%d / %d"):format(m.kills, m.deaths) }
            lines[#lines + 1] = { label = "Captures", value = tostring(m.captures) }
            lines[#lines + 1] = { label = "Time on the zones", value = R.clock((m.holdSeconds or 0) * 1000) }
            lines[#lines + 1] = { label = "Reputation", value = result.reputation > 0 and ("+" .. result.reputation)
                or (counted and "-" or notCounted(war)) }
            local mine = m.gang and deltas[m.gang] and war.sides[m.side].gang == m.gang and not m.merc
            if mine then
                local points, rank = TurfInfluence.of(m.gang)
                lines[#lines + 1] = { label = m.gangLabel .. " influence", value = ("+%d (week %d, #%d)")
                    :format(deltas[m.gang].points, points or 0, rank or 0) }
            end
            if #top > 0 then
                local parts = {}
                for i, row in ipairs(top) do
                    if i > 3 then break end
                    parts[#parts + 1] = ("%d. %s %d"):format(i, row.label, row.points)
                end
                lines[#lines + 1] = { label = "Who holds the city", value = table.concat(parts, " · ") }
            end
        end
        push(m, "result", { title = title, placement = (winner == 0 or winner == m.side) and 1 or 2, subtitle = score,
            lines = lines, tone = tone, durationMs = (cfg().match.scoreboardSeconds or 10) * 1000,
            influence = #top > 0 and top or nil })
    end)
    -- The bots go with the war (the end board above keeps their rows).
    if war.bots then B().removeAll(war, "war_over") end
end

-- Staff stop, failed placements, core gone, last human gone: nothing counts.
function Turf.abort(war, now, reason)
    if war.state == "resolved" or war.state == "closed" then return false end
    war.void, war.voidReason = true, reason
    Turf.finish(war, 0, "aborted", now)
    return true
end

-- A side with nobody left: the other wins by forfeit (running), or the war is void.
-- A war with bots goes on while one human is in it, and is void when none is left.
local function checkSides(war, now)
    if war.state == "resolved" or war.state == "closed" then return end
    local n = Turf.counts(war)
    if hasBots(war) then
        if n[1] + n[2] == 0 then return Turf.abort(war, now, "Every fighter left. Nothing counts.") end
        return
    end
    if n[1] > 0 and n[2] > 0 then return end
    if war.state == "running" and (n[1] > 0 or n[2] > 0) then
        return Turf.finish(war, n[1] > 0 and 1 or 2, "forfeit", now)
    end
    return Turf.abort(war, now, "A side emptied before the fight. Nothing counts.")
end
Turf.checkSides = checkSides

-- ---------------------------------------------------------------- departures

-- One fighter home: out of the kit, alive, team cleared, then activityLeave (Light RP
-- teleports him back). Returns true once released.
local function releaseMember(war, m, now)
    if m.gone or m.released then return true end
    m.exitStartedMs = m.exitStartedMs or now
    -- A placement in flight would land him back here after Light RP took him home
    -- (bounded: Light RP releases on its own 15 s after a leave request).
    if m.placing and now - m.exitStartedMs < 10000 then return false end
    if W().alive(m.id) == false then
        if not m.exitRespawnMs then
            m.exitRespawnMs = now
            W().respawnInPlace(m.id, war.bucket, m.lastPos)
            return false
        end
        if now - m.exitRespawnMs < 4000 then return false end
    end
    m.released = true
    if m.frozen then m.frozen = nil; W().freeze(m.id, false) end
    W().setTeam(m.id, 0)
    W().clearKit(m.id)
    W().clear(m.id)
    C().leave(m.id, { returnPlayer = true }, war.activity)
    return true
end
Turf.releaseMember = releaseMember

-- The fighter asked to quit (hub, /turf leave): a forfeit for him (result now, no
-- reputation), home at once; his side plays on. `activity`: only that activity's
-- queue / war (nil: any). Returns done, "queue"|"war", activityId.
function Turf.leaveRequest(id, now, activity)
    local pvp, pve = cfg().activity.id, cfg().pve.activity.id
    if (activity == nil or activity == pvp) and Turf.dequeue(id) then
        W().clear(id)
        return true, "queue", pvp
    end
    if (activity == nil or activity == pve) and Turf.unsweep(id) then
        W().clear(id)
        return true, "queue", pve
    end
    local m, war = Turf.memberOf(id)
    if not m or (activity ~= nil and war.activity ~= activity) then return false end
    m.leaving, m.left = true, war.state ~= "resolved" or nil
    if war.state == "running" and not m.resultSent then
        C().result(id, resultFor(war, m, -1, false), war.activity)
        m.resultSent = true
    end
    if war.state ~= "resolved" then feedAll(war, ("%s left the %s"):format(m.name, isSweep(war) and "sweep" or "war"), "info") end
    war.boardDirty = true
    releaseMember(war, m, now)
    checkSides(war, now)
    return true, "war", war.activity
end

-- Light RP already released him (disconnect, character switch...): clean up, never leave.
function Turf.dropped(id, now, reason, activity)
    local pvp, pve = cfg().activity.id, cfg().pve.activity.id
    local queued = false
    if activity == nil or activity == pvp then queued = Turf.dequeue(id) or queued end
    if activity == nil or activity == pve then queued = Turf.unsweep(id) or queued end
    local m, war = entryOf(id)
    if not m or (activity ~= nil and war.activity ~= activity) then return queued end
    m.gone = true
    W().setTeam(id, 0)
    if m.frozen then m.frozen = nil; W().freeze(id, false) end
    log("war %d: %d dropped (%s)", war.id, id, tostring(reason))
    if war.state ~= "resolved" then feedAll(war, ("%s is gone"):format(m.name), "info") end
    war.boardDirty = true
    checkSides(war, now)
    return true
end

-- Light RP stopped: it has already returned every player it owned (contract), so
-- nobody is handed back; every war and sweep is void and the queues forgotten.
function Turf.coreStopped(now)
    for _, war in ipairs(Turf.wars()) do
        for _, id in ipairs(war.order) do
            local m = war.members[id]
            if m and not m.gone and not m.released then
                W().clear(id)
                W().setTeam(id, 0)
                if m.frozen then W().freeze(id, false) end
            end
            if m then m.gone = true end
        end
        if war.scope then W().removeScope(war.scope); war.scope = nil end
        if war.bots then B().removeAll(war, "core_stopped") end
        war.void, war.voidReason = true, "Light RP restarted. Nothing counts."
        war.state = "closed"
        log("war %d voided: op77_lightrp stopped", war.id)
    end
    Turf.war, Turf.sweeps = nil, {}
    for _, e in ipairs(Turf.queue) do W().clear(e.id) end
    for _, g in ipairs(Turf.sweepQueue) do for _, e in ipairs(g.entries) do W().clear(e.id) end end
    Turf.queue, Turf.lobby, Turf.sweepQueue = {}, nil, {}
end

-- This resource stops: Light RP returns the players itself; drop our holds, teams, bots.
function Turf.shutdown()
    local wars = Turf.wars()
    for _, war in ipairs(wars) do
        for _, id in ipairs(war.order) do
            local m = war.members[id]
            if present(m) then
                W().setTeam(id, 0)
                if m.frozen then W().freeze(id, false) end
                W().clear(id)
            end
        end
        if war.scope then W().removeScope(war.scope) end
    end
    B().shutdown(wars)
end

-- ---------------------------------------------------------------- tick

local function close(war)
    if war.scope then W().removeScope(war.scope); war.scope = nil end
    if war.bots then B().removeAll(war, "closed") end
    war.state = "closed"
    if Turf.war == war then Turf.war = nil end
    for i = #Turf.sweeps, 1, -1 do if Turf.sweeps[i] == war then table.remove(Turf.sweeps, i) end end
    log("war %d closed", war.id)
end

local function beginCountdown(war, now)
    war.state = "countdown"
    war.countdownEndsAt = now + (cfg().match.countdownSeconds or 10) * 1000
    eachPresent(war, function(m)
        if m.placed then
            m.frozen = W().freeze(m.id, true) or nil
            m.aliveSince = now
            if not m.down then Turf.equip(war, m) end
            local kit = Turf.kit(m.kit) or defaultKit()
            local text
            if isSweep(war) then
                text = ("Gang Sweep at %s: %s hold every zone. Take them back! Kit: %s (K to change).")
                    :format(war.site.label, sideLabel(war, 2), kit.label)
            else
                text = ("%s vs %s at %s. You fight for %s%s. Kit: %s (K to change). Hold the zones!")
                    :format(sideLabel(war, 1), sideLabel(war, 2), war.site.label, sideLabel(war, m.side),
                        m.merc and " as a mercenary" or "", kit.label)
            end
            W().notify(m.id, "info", text, 8000)
        end
    end)
    Turf.pushHud(war, now)
end

local function beginRunning(war, now)
    war.state = "running"
    war.startedAt = now
    war.endsAt = now + (war.timeLimitMs or (cfg().match.timeLimitSeconds or 660) * 1000)
    war.lastStep = now
    eachPresent(war, function(m)
        if m.frozen then m.frozen = nil; W().freeze(m.id, false) end
        m.protectedUntil = nil
        push(m, "banner", { title = "FIGHT", text = ("Take the zones. First to %d."):format(war.target), tone = "success",
            durationMs = 3000 })
    end)
    if war.bots then B().retask(war, now) end
    Turf.syncScope(war, now + 1000, true)
    Turf.pushHud(war, now)
    log("war %d running", war.id)
end

function Turf.tickWar(war, now)
    local state = war.state
    -- Fighters on their way out (left, or the war is over).
    for _, id in ipairs(war.order) do
        local m = war.members[id]
        if m and m.leaving and not m.released and not m.gone then releaseMember(war, m, now) end
    end
    if war.bots then B().tick(war, now) end
    if state == "placing" then
        local done = true
        eachPresent(war, function(m)
            if m.placed == false then
                m.leaving = true
                W().notify(m.id, "warning", "The war zone did not load for you: you are sent back.", 6000)
                releaseMember(war, m, now)
            elseif m.placed ~= true then
                if now >= war.placeDeadline then
                    m.leaving = true
                    releaseMember(war, m, now)
                else
                    done = false
                end
            end
        end)
        checkSides(war, now)
        if war.state == "placing" and done then beginCountdown(war, now) end
    elseif state == "countdown" then
        tickRespawns(war, now)
        if now >= war.countdownEndsAt then beginRunning(war, now)
        elseif now - (war.lastHud or 0) >= cfg().hudMs then Turf.pushHud(war, now) end
    elseif state == "running" then
        tickRespawns(war, now)
        if now - (war.lastStep or 0) >= cfg().stepMs then
            Turf.step(war, now)
            if war.state == "running" and not isSweep(war) then admitLate(war, now) end
        end
        if war.state == "running" then
            if now - (war.lastHud or 0) >= cfg().hudMs then Turf.pushHud(war, now) end
            if war.boardDirty and now - (war.lastBoard or 0) >= cfg().boardMs then Turf.pushBoard(war, now) end
        end
    elseif state == "resolved" then
        if now >= war.releaseAt then
            local pending = false
            for _, id in ipairs(war.order) do
                local m = war.members[id]
                if m and not m.gone and not m.released then
                    m.leaving = true
                    if not releaseMember(war, m, now) then pending = true end
                end
            end
            if not pending then close(war) end
        end
    end
end

-- ---------------------------------------------------------------- Gang Sweep (PvE)
--
-- A join (turf.pve) lines the player up with his crew: the core sends one join per
-- squad member, each with the same options.squad. The group starts once every online
-- member is in (or after pve.gatherSeconds), when a sweep slot is free. A crew member
-- joining while his crew's sweep runs goes straight into it.

local function sweepOf(key)
    for _, war in ipairs(Turf.sweeps) do
        if war.squadKey == key and war.state ~= "resolved" and war.state ~= "closed" then return war end
    end
    return nil
end

-- A crew member into his crew's running sweep: true | false, sentence.
function Turf.sweepLate(war, e, now)
    local P = cfg().pve
    if war.state == "resolved" or war.state == "closed" then return false, "Your crew's sweep is ending." end
    if war.state == "running" and war.endsAt - now < (P.joinCutoffSeconds or 120) * 1000 then
        return false, "Your crew's sweep is almost over."
    end
    local n = Turf.counts(war)
    if n[1] + n[2] >= (P.activity.maxPlayers or 8) then return false, "Your crew's sweep is full." end
    local ok, why = C().check(e.id, war.activity)
    if not ok then return false, why end
    ok, why = C().enter(e.id, war.activity)
    if not ok then return false, why end
    local member = war.members[e.id]
    if member then
        member.left, member.leaving, member.released, member.gone, member.resultSent = nil, nil, nil, nil, nil
        member.side, member.down = 1, false
        W().setTeam(e.id, cfg().teamIds[1])
    else
        member = newMember(war, e.id, 1, true, e, now)
    end
    placeMember(war, member, now, coverOf(war))
    B().welcome(war, member)
    local added = B().scale(war, now)
    feedAll(war, ("%s joins the sweep%s"):format(member.name, added > 0 and (" · %d more gangers"):format(added) or ""), "info")
    war.boardDirty = true
    W().notify(e.id, "info", ("Joining your crew's Gang Sweep at %s."):format(war.site.label), 5000)
    return true, "Joining your crew's Gang Sweep."
end

-- A turf.pve join. `checked`: Light RP already ran activityCheck (the hub join).
function Turf.sweepJoin(id, opts, now, checked)
    local P = cfg().pve
    if not P.enabled or not B().available() then return false, "Gang Sweep is closed right now." end
    if Turf.memberOf(id) then return false, "You are already in a fight." end
    if Turf.sweepEntry(id) then return true, "You are already lined up for a Gang Sweep." end
    if Turf.position(id) then return false, "You are queued for Turf War: /turf leave first." end
    if not checked then
        local ok, why = C().check(id, P.activity.id)
        if not ok then return false, why end
    end
    opts = type(opts) == "table" and opts or {}
    local squad, view = squadOf(opts)
    local key = squad and ("squad:" .. squad) or ("solo:" .. tostring(id))
    local vote = type(opts.site) == "string" and Turf.site(opts.site) or nil
    if vote and vote.enabled == false then vote = nil end
    local who = Turf.identity(id)
    local entry = { id = id, at = now, site = vote and vote.id or nil, name = who.name, identifier = who.identifier,
        characterKey = who.characterKey, gang = who.gang, gangLabel = who.gangLabel, gangColor = who.gangColor,
        kit = Turf.kit(opts.kit) and opts.kit or nil, squad = squad }
    local running = sweepOf(key)
    if running then return Turf.sweepLate(running, entry, now) end
    local group
    for _, g in ipairs(Turf.sweepQueue) do if g.key == key then group = g break end end
    if not group then
        local expected = {}
        if view and type(view.members) == "table" then
            for _, mid in ipairs(view.members) do
                local n = tonumber(mid)
                if n then expected[#expected + 1] = math.tointeger(n) or n end
            end
        end
        local gather = (squad and P.gatherSeconds or P.soloGatherSeconds) or 0
        group = { key = key, squad = squad, expected = expected, entries = {}, at = now, readyAt = now + gather * 1000 }
        Turf.sweepQueue[#Turf.sweepQueue + 1] = group
    end
    group.entries[#group.entries + 1] = entry
    local text
    if squad then
        text = ("Gang Sweep: your crew is gathering (%d/%d). It starts as soon as everyone is in.")
            :format(#group.entries, math.max(#group.entries, #group.expected))
    else
        text = "Gang Sweep: you go in alone. The NPC gang is waiting."
    end
    if #Turf.sweeps >= (P.maxSweeps or 2) then
        text = text .. (" Every sweep slot is taken (%d): you go in when one frees up."):format(P.maxSweeps or 2)
    end
    W().notify(id, "info", text .. " /turf leave to cancel.", 7000)
    Turf.lastQueuePush = 0
    return true, text
end

-- A crew's sweep starts (every ready member enters; the not ready stay lined up and
-- join late once they can).
function Turf.launchSweep(g, now)
    local P = cfg().pve
    local pveId = P.activity.id
    local ready, waiting = {}, {}
    for _, e in ipairs(g.entries) do
        local ok, why = false, "Your crew's sweep is full."
        if W().connected(e.id) and #ready < (P.activity.maxPlayers or 8) then ok, why = C().check(e.id, pveId) end
        if ok then
            ready[#ready + 1] = e
            e.notReadySince = nil
        elseif W().connected(e.id) then
            e.notReadySince = e.notReadySince or now
            waiting[#waiting + 1] = e
            W().notify(e.id, "warning", ("Your Gang Sweep is starting, but you can't go: %s"):format(tostring(why)), 6000)
        end
    end
    local site = Turf.pickSite(ready, "sweepCursor")
    local entered, byId, people = {}, {}, {}
    for _, e in ipairs(ready) do
        local ok, why = C().enter(e.id, pveId)
        if ok then
            entered[#entered + 1] = e.id
            byId[e.id] = e
            people[#people + 1] = e
        else
            W().clear(e.id)
            W().notify(e.id, "warning", ("You could not join the Gang Sweep: %s"):format(tostring(why)), 6000)
        end
    end
    if #waiting > 0 then
        g.entries, g.readyAt = waiting, now + 5000
        table.insert(Turf.sweepQueue, g)
    end
    if #entered == 0 then return nil end
    local humans = R.topGangs(people)
    local holder = (P.holders or {})[site.id]
    if holder == nil or holder == humans or cfg().gangs[holder] == nil then
        holder = R.rivalGang(cfg().bots.gangOrder, humans, cfg().gangs)
    end
    local merc = {}
    for _, id in ipairs(entered) do
        if not (humans ~= nil and byId[id].gang == humans) then merc[id] = true end
    end
    local rewards = R.scaledRewards(cfg().rewards, P.reputationScale or 0.6, P.rewards)
    return Turf.start(site, { gangs = { humans, holder }, merc = merc }, { entered, {} }, byId, now,
        { kind = "pve", activity = pveId, squadKey = g.key, target = P.targetScore, timeLimitSeconds = P.timeLimitSeconds,
            rewards = rewards, holder = 2, zoneRate = { 1, P.holderZoneRate or 1 } })
end

local function tickSweeps(now)
    local P = cfg().pve
    local timeout = (cfg().queue.timeoutSeconds or 1800) * 1000
    local dropAfter = (cfg().queue.notReadyDropSeconds or 120) * 1000
    local i = 1
    while i <= #Turf.sweepQueue do
        local g = Turf.sweepQueue[i]
        for j = #g.entries, 1, -1 do
            local e = g.entries[j]
            local stale = (e.notReadySince and now - e.notReadySince >= dropAfter) or now - e.at > timeout
            if not W().connected(e.id) then
                table.remove(g.entries, j)
            elseif stale then
                table.remove(g.entries, j)
                W().clear(e.id)
                W().notify(e.id, "info", "You left the Gang Sweep line-up (not ready or too long).", 5000)
            end
        end
        local running = #g.entries > 0 and sweepOf(g.key) or nil
        if #g.entries == 0 then
            table.remove(Turf.sweepQueue, i)
        elseif running then
            -- His crew is in there: each member tries to follow (5 s apart).
            for j = #g.entries, 1, -1 do
                local e = g.entries[j]
                if now >= (e.retryAt or 0) then
                    local ok, why = Turf.sweepLate(running, e, now)
                    if ok then
                        table.remove(g.entries, j)
                        e.notReadySince = nil
                    else
                        e.retryAt = now + 5000
                        e.notReadySince = e.notReadySince or now
                        if why ~= e.lastWhy then
                            e.lastWhy = why
                            W().notify(e.id, "warning", ("You can't join your crew's sweep yet: %s"):format(tostring(why)), 5000)
                        end
                    end
                end
            end
            if #g.entries == 0 then table.remove(Turf.sweepQueue, i) else i = i + 1 end
        else
            local complete = #g.expected > 0
            for _, mid in ipairs(g.expected) do
                if W().connected(mid) then
                    local inside = false
                    for _, e in ipairs(g.entries) do if e.id == mid then inside = true break end end
                    if not inside then complete = false break end
                end
            end
            if (complete or now >= g.readyAt) and #Turf.sweeps < (P.maxSweeps or 2) then
                table.remove(Turf.sweepQueue, i)
                Turf.launchSweep(g, now)
                -- (a group put back by launchSweep is at the end of the list)
            else
                i = i + 1
            end
        end
    end
end

-- Lined-up players see their crew gathering (and the wait for a slot), on change only.
function Turf.pushSweepQueue(now, force)
    local P = cfg().pve
    local full = #Turf.sweeps >= (P.maxSweeps or 2) or nil
    for gi, g in ipairs(Turf.sweepQueue) do
        local min = math.max(#g.entries, #g.expected)
        for _, e in ipairs(g.entries) do
            local view = { queued = true, mode = "pve", position = gi, total = #g.entries, min = min,
                lobbyMs = math.max(0, g.readyAt - now), site = e.site and Turf.site(e.site) and Turf.site(e.site).label or nil,
                gang = e.gangLabel, kit = e.kit or defaultKit().id, waiting = full }
            local key = ("%d|%d|%d|%s|%s|%s"):format(gi, #g.entries, min, tostring(g.readyAt), view.kit, tostring(full))
            if force or key ~= e.pushedKey then
                e.pushedKey = key
                W().state(e.id, nil, view)
            end
        end
    end
end

function Turf.tick(now)
    tickSchedule(now)
    for _, war in ipairs(Turf.wars()) do
        local ok, err = pcall(Turf.tickWar, war, now)
        if not ok then log("war %d tick error: %s", war.id, tostring(err)) end
    end
    if Turf.war == nil then
        tickLobby(now)
    end
    local ok, err = pcall(tickSweeps, now)
    if not ok then log("sweep line-up error: %s", tostring(err)) end
    if now - (Turf.lastQueuePush or 0) >= 2000 then
        maintainQueue(now)
        Turf.pushQueue(now)
        Turf.pushSweepQueue(now)
    end
end
