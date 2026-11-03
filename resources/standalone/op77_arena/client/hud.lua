-- op77_arena client: the match HUD, drawn by Light RP.
--
-- No page of our own: the engine's state (`deathmatch:state`), feed, callouts and
-- notices are turned into Light RP's shared activity HUD through the op77_lightrp
-- client exports (ActivityHudShow / ActivityHudPush / ActivityHudClear). Every call
-- is protected: an older core without those exports degrades to Light RP notices.
-- No key is bound here. Bots carry `LightRpArena.bots.prefix` ("[BOT] ") on every
-- name: scoreboard, teams, kill feed.

local L = LightRpArena
local CORE = L.core

ArenaHud = { state = nil, shown = false, resultKey = nil, tag = nil }
local S = ArenaHud

local function running(name)
    if type(GetResourceState) ~= "function" then return true end
    return GetResourceState(name) == "running"
end

-- exports[CORE]:method(...) without ever throwing: value(s) | false, reason.
local function call(method, ...)
    if not running(CORE) then return false, "not_running" end
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local target = exports[CORE]
        return target[method](target, table.unpack(args, 1, args.n))
    end)
    if not ok then return false, tostring(a) end
    return a, b
end
S.call = call

local TONE = { success = "success", warning = "danger", error = "danger", info = "info" }

-- A Light RP notice from the client side (same event the core raises).
local function notify(kind, title, body, durationMs)
    TriggerEvent("op77_lightrp:notice", {
        kind = kind or "info", title = title or L.source, body = body or "",
        source = L.source, durationMs = durationMs or 5000,
    })
end
S.notify = notify

local function clear()
    if S.shown then call("ActivityHudClear") end
    S.shown, S.resultKey = false, nil
end
S.clear = clear

-- ---------------------------------------------------------------------------
-- Engine state -> activity HUD

-- Bots: a negative participant id, or the engine's `bot` flag (kept on the row of a
-- bot removed since). One marker, whatever the engine prefixed the name with.
local BOT_PREFIX = (type(L.bots) == "table" and type(L.bots.prefix) == "string") and L.bots.prefix or "[BOT] "

local function isBot(row)
    return type(row) == "table" and (row.bot == true or (tonumber(row.id) or 0) < 0)
end
S.isBot = isBot

local function markBot(name)
    name = tostring(name or "?")
    if name:sub(1, #BOT_PREFIX) == BOT_PREFIX then return name end
    name = name:gsub("^%[?[Bb][Oo][Tt]%]?%s*", "")
    return BOT_PREFIX .. (name ~= "" and name or "?")
end
S.markBot = markBot

local function nameOf(row)
    if isBot(row) then return markBot(row.name) end
    return row.name or "?"
end
S.nameOf = nameOf

local function hasBots(s)
    if type(s.instance) == "table" and (tonumber(s.instance.bots) or 0) > 0 then return true end
    for _, row in ipairs(s.rows or {}) do
        if isBot(row) and row.active ~= false then return true end
    end
    return false
end

local function isPve(s)
    return type(s.instance) == "table" and s.instance.ruleset == "pve"
end

-- PvE: a gang bot. An allied bot (Light RP "fill empty slots") is on the players'
-- side, team 1, like the players.
local function pveEnemy(row)
    return isBot(row) and tonumber(row.team) ~= 1
end
S.pveEnemy = pveEnemy

-- Unranked / friendly (op77_arena:entered), shown when no BOTS hint already says it.
local function rankHint(hints)
    if S.tag == nil then return end
    for _, hint in ipairs(hints) do
        if hint.key == "BOTS" then return end
    end
    hints[#hints + 1] = { key = "RANK", label = S.tag }
end

local function decode(payload)
    if type(payload) == "table" and type(payload.stateFragments) == "table" then
        payload = table.concat(payload.stateFragments)
    end
    if type(payload) == "string" then
        local ok, decoded = pcall(json.decode, payload)
        if not ok then return nil end
        payload = decoded
    end
    if type(payload) ~= "table" then return nil end
    payload.rows = DeathmatchWire.unpackRows(payload.rows)
    if type(payload.result) == "table" then payload.result.rows = DeathmatchWire.unpackRows(payload.result.rows) end
    return payload
end
S.decode = decode

local function titleOf(s)
    local instance = s.instance or {}
    if instance.ruleset == "blade" or s.mode == "blade" then return L.activities.blade.label end
    if instance.ruleset == "pve" then return L.activities.pve.label end
    local format = instance.format or s.mode
    if format == "1v1" then return L.activities.duel.label end
    if format == "2v2" or format == "3v3" then return L.activities.teams.label .. " " .. format end
    return L.activities.ffa.label
end

local function phaseOf(s)
    local raw = s.roundState or s.phase
    if raw == "buy" or raw == "between" then return "countdown" end
    if raw == "standings" or raw == "resolved" then return "ended" end
    return "running"
end

local function selfId(s)
    return tonumber(s.playerId) or (s.self and tonumber(s.self.id)) or nil
end

local function scoreboard(s, columns, values, teamOf)
    local rows = {}
    local me = selfId(s)
    for _, row in ipairs(s.rows or {}) do
        if #rows >= 16 then break end
        if row.active ~= false then
            rows[#rows + 1] = { name = nameOf(row), values = values(row), self = row.id == me, team = teamOf and teamOf(row) or nil }
        end
    end
    if #rows == 0 then return nil end
    return { columns = columns, rows = rows }
end

local function shieldProgress(s)
    local progress = {}
    local self = s.self or {}
    local shield = self.protection or {}
    local remaining, total = tonumber(shield.remainingMs) or 0, tonumber(shield.totalMs) or 0
    if remaining > 0 and total > 0 then
        progress[#progress + 1] = { id = "shield", label = "Spawn shield", value = math.min(1, remaining / total), tone = "info" }
    end
    if type(s.death) == "table" then
        local left = tonumber(s.death.remainingMs) or 0
        local delay = 3000
        progress[#progress + 1] = { id = "respawn", label = "Respawning", value = math.max(0, math.min(1, 1 - left / delay)), tone = "danger" }
    end
    return #progress > 0 and progress or nil
end

-- PvE: the players (and their allied bots) are one side, the gang bots the other.
local function pveTeams(s)
    local players, bots = 0, 0
    for _, row in ipairs(s.rows or {}) do
        local kills = tonumber(row.kills) or 0
        if pveEnemy(row) then bots = bots + kills else players = players + kills end
    end
    return {
        { name = "Players", color = "#FFCC00", score = players, self = true },
        { name = BOT_PREFIX .. "Gangs", color = "danger", score = bots },
    }
end

local function ffaHud(s)
    local self = s.self or {}
    local blade = (s.instance and s.instance.ruleset == "blade") or s.mode == "blade"
    local pve = isPve(s)
    local phase = phaseOf(s)
    local subtitle = s.round and ("Round %d"):format(s.round) or nil
    if not blade and type(s.weapon) == "table" and s.weapon.label then
        subtitle = (subtitle and subtitle .. " - " or "") .. s.weapon.label
    end
    local combatants = tonumber(s.participantCount) or 0
    local hints = {
        { key = "CHAT", label = "/arena.leave" },
        { key = "CHAT", label = "/arena.weapon list" },
    }
    -- Bots in a PvP round: practice, and the player is told so.
    if not pve and hasBots(s) then hints[#hints + 1] = { key = "BOTS", label = "Practice: not recorded" } end
    rankHint(hints)
    local activity = L.activities.ffa.id
    if blade then activity = L.activities.blade.id elseif pve then activity = L.activities.pve.id end
    return {
        activity = activity,
        title = titleOf(s),
        subtitle = subtitle,
        phase = phase,
        timer = s.remainingMs and { remainingMs = s.remainingMs, label = phase == "ended" and "Next round" or "Round" } or nil,
        objective = s.killLimit and ("First to %d kills"):format(s.killLimit) or nil,
        stats = {
            { label = "Kills", value = self.kills or 0 },
            { label = "Deaths", value = self.deaths or 0 },
            { label = "Rank", value = (self.rank and self.rank > 0) and ("%d/%d"):format(self.rank, math.max(combatants, self.rank)) or "-" },
            { label = "Streak", value = self.streak or 0 },
        },
        progress = shieldProgress(s),
        teams = pve and pveTeams(s) or nil,
        scoreboard = scoreboard(s, { "K", "D", "Score" }, function(row)
            return { row.kills or 0, row.deaths or 0, row.score or 0 }
        end, pve and function(row) return pveEnemy(row) and 2 or 1 end or nil),
        hints = hints,
    }
end

local function arenaHud(s)
    local arena = s.arena or {}
    local side = tonumber(arena.side) or 1
    local other = side == 1 and 2 or 1
    local wins = arena.wins or {}
    local alive = arena.aliveByTeam or {}
    local raw = s.roundState or s.phase
    local phase = phaseOf(s)
    local duel = arena.format == "1v1"
    local me = selfId(s)

    local mineName, theirName = "Your team", "Opponents"
    if duel then
        for _, row in ipairs(s.rows or {}) do
            if row.id == me then mineName = row.name or mineName
            elseif row.name or isBot(row) then theirName = nameOf(row) end
        end
    end
    local hints = {
        { key = "CHAT", label = "/arena.leave" },
        { key = "CHAT", label = "/arena.kit" },
    }
    if hasBots(s) then hints[#hints + 1] = { key = "BOTS", label = "Practice: not recorded" } end
    rankHint(hints)

    local objective
    if raw == "buy" then objective = "Pick a kit: /arena.kit"
    elseif arena.eliminated then objective = "Eliminated. Wait for the next round."
    elseif raw == "active" then objective = ("%d alive vs %d"):format(tonumber(alive[side]) or 0, tonumber(alive[other]) or 0)
    elseif raw == "resolved" then objective = "Match over. Heading back soon."
    end

    local labels = { buy = "Buy", active = "Round", between = "Next round", resolved = "Back in" }
    local self = s.self or {}
    return {
        activity = duel and L.activities.duel.id or L.activities.teams.id,
        title = titleOf(s),
        subtitle = ("Round %d - best of %d"):format(tonumber(arena.round) or 1, tonumber(arena.bestOf) or 3),
        phase = phase,
        timer = s.remainingMs and { remainingMs = s.remainingMs, label = labels[raw] or "Round" } or nil,
        countdown = phase == "countdown" and s.remainingMs or nil,
        objective = objective,
        stats = {
            { label = "Kills", value = self.kills or 0 },
            { label = "Deaths", value = self.deaths or 0 },
            { label = "Kit", value = arena.kit or "-" },
        },
        progress = shieldProgress(s),
        teams = {
            { name = mineName, color = "#FFCC00", score = tonumber(wins[side]) or 0, self = true },
            { name = theirName, color = "danger", score = tonumber(wins[other]) or 0 },
        },
        scoreboard = scoreboard(s, { "K", "D", "Dmg" }, function(row)
            return { row.kills or 0, row.deaths or 0, row.damage or 0 }
        end, function(row)
            local team = tonumber(row.team) or 0
            if team == side then return 1 elseif team == other then return 2 end
            return nil
        end),
        hints = hints,
    }
end

function S.build(s)
    if type(s) ~= "table" or s.participant ~= true then return nil end
    local format = (s.instance and s.instance.format) or s.mode
    if format == "ffa" or format == "blade" or s.mode == "ffa" or s.mode == "blade" then return ffaHud(s) end
    return arenaHud(s)
end

-- The end-of-round / end-of-match card, once per round.
function S.resultFor(s)
    if type(s) ~= "table" or s.participant ~= true then return nil end
    local raw = s.roundState or s.phase
    local self = s.self or {}
    local result = type(s.result) == "table" and s.result or {}
    if s.arena ~= nil then
        if raw ~= "resolved" then return nil end
        local arena = s.arena
        local side = tonumber(arena.side) or 1
        local wins = result.wins or arena.wins or {}
        local winner = tonumber(result.winnerSide) or 0
        local won = winner ~= 0 and winner == side
        return ("m:%s"):format(tostring(s.instanceId)), {
            title = winner == 0 and "DRAW" or (won and "MATCH WON" or "MATCH LOST"),
            placement = winner ~= 0 and (won and 1 or 2) or nil,
            subtitle = ("%d - %d"):format(tonumber(wins[side]) or 0, tonumber(wins[side == 1 and 2 or 1]) or 0),
            lines = { { label = "Kills", value = self.kills or 0 }, { label = "Deaths", value = self.deaths or 0 } },
            durationMs = 8000,
        }
    end
    if raw ~= "standings" and raw ~= "resolved" then return nil end
    if isPve(s) then
        local teams = pveTeams(s)
        local won = teams[1].score > teams[2].score
        return ("r:%s:%s"):format(tostring(s.instanceId), tostring(s.round)), {
            title = won and "PLAYERS WIN" or "BOTS WIN",
            placement = won and 1 or 2,
            subtitle = ("Players %d - %d bots"):format(teams[1].score, teams[2].score),
            lines = {
                { label = "Kills", value = self.kills or 0 },
                { label = "Deaths", value = self.deaths or 0 },
                { label = "Score", value = self.score or 0 },
            },
            durationMs = 8000,
        }
    end
    local winnerName = result.winnerName
    if winnerName ~= nil and (tonumber(result.winnerId) or 0) < 0 then winnerName = markBot(winnerName) end
    return ("r:%s:%s"):format(tostring(s.instanceId), tostring(s.round)), {
        title = (result.winnerId ~= nil and result.winnerId == selfId(s)) and "ROUND WON" or "ROUND OVER",
        placement = (self.rank and self.rank > 0) and self.rank or nil,
        subtitle = winnerName and winnerName ~= "" and (winnerName .. " takes the round") or "No clear winner",
        lines = {
            { label = "Kills", value = self.kills or 0 },
            { label = "Deaths", value = self.deaths or 0 },
            { label = "Score", value = self.score or 0 },
        },
        durationMs = 8000,
    }
end

function S.apply(s)
    S.state = s
    local hud = S.build(s)
    if hud == nil then
        clear()
        return false
    end
    local ok, why = call("ActivityHudShow", hud)
    -- A rate-limited update leaves the previous HUD on screen: still ours to clear.
    if ok == true then S.shown = true elseif why ~= "rate_limited" then S.shown = false end
    local key, card = S.resultFor(s)
    if key ~= nil and key ~= S.resultKey then
        S.resultKey = key
        local pushed = S.shown and call("ActivityHudPush", "result", card) == true
        if not pushed then
            notify(card.placement == 1 and "success" or "info", card.title, card.subtitle, card.durationMs)
        end
    end
    return S.shown
end

RegisterNetEvent("deathmatch:state", function(payload)
    local s = decode(payload)
    if s then S.apply(s) end
end)

-- Notices: a banner over the HUD in a match, a Light RP notice otherwise.
RegisterNetEvent("deathmatch:notice", function(payload)
    if type(payload) ~= "table" then return end
    local title, text = payload.title, payload.message or payload.body
    if S.shown then
        local ok = call("ActivityHudPush", "banner", {
            title = title, text = text, tone = TONE[payload.kind] or "info", durationMs = 3000,
        })
        if ok == true then return end
    end
    notify(payload.kind, title, text)
end)

RegisterNetEvent("deathmatch:killfeed", function(payload)
    if type(payload) ~= "table" or not S.shown then return end
    local me = S.state and selfId(S.state) or nil
    local killer = payload.killerName
    if killer ~= nil and (payload.killerBot == true or (tonumber(payload.killerId) or 0) < 0) then killer = markBot(killer) end
    local victim = payload.victimName or "?"
    if payload.victimBot == true or (tonumber(payload.victimId) or 0) < 0 then victim = markBot(victim) end
    local text = killer and (killer .. " > " .. victim) or (victim .. " died")
    if payload.headshot then text = text .. " (headshot)" end
    local tone = nil
    if me ~= nil and payload.killerId == me then tone = "success"
    elseif me ~= nil and payload.victimId == me then tone = "danger" end
    call("ActivityHudPush", "feed", { text = text, tone = tone })
end)

local CALLOUTS = {
    multi = "Multi-kill", streak = "Kill streak", firstBlood = "First blood", revenge = "Revenge",
    headshot = "Headshot", assist = "Assist", streakEnded = "Streak ended", double = "Double kill",
    triple = "Triple kill", lead = "You took the lead",
}

RegisterNetEvent("deathmatch:callout", function(payload)
    if type(payload) ~= "table" or not S.shown then return end
    local label = CALLOUTS[payload.kind] or tostring(payload.kind or "")
    if label == "" then return end
    local count = tonumber(payload.count) or 0
    if count > 1 then label = ("%s x%d"):format(label, count) end
    call("ActivityHudPush", "feed", { text = label, tone = "accent" })
end)

RegisterNetEvent("op77_arena:entered", function(payload)
    S.resultKey = nil
    payload = type(payload) == "table" and payload or {}
    S.tag = (payload.friendly == true and "Friendly: unranked") or (payload.unranked == true and "Unranked") or nil
end)

RegisterNetEvent("op77_arena:returned", function()
    clear()
    S.state, S.tag = nil, nil
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then clear() end
end)
