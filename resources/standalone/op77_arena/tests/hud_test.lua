-- client/hud.lua: engine state -> Light RP's activity HUD (ActivityHud* exports),
-- with the fallback to Light RP notices when the exports are missing or refuse.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test hud_test.lua
local say = print
_G.print = function() end

local env = { shows = {}, pushes = {}, clears = 0, events = {}, net = {}, handlers = {}, state = "running", answer = { true } }

local core = {}
function core.ActivityHudShow(self, hud) env.shows[#env.shows + 1] = hud; return table.unpack(env.answer) end
function core.ActivityHudPush(self, kind, payload) env.pushes[#env.pushes + 1] = { kind = kind, payload = payload }; return table.unpack(env.answer) end
function core.ActivityHudClear(self) env.clears = env.clears + 1; return true end

_G.exports = { op77_lightrp = core }
_G.GetResourceState = function() return env.state end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
_G.AddEventHandler = function(name, fn) env.handlers[name] = fn end
_G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
local decoded = {}
_G.json = { decode = function(s) return decoded[s] end }

dofile("shared/config.lua")
dofile("shared/kabuki.lua")
dofile("shared/wire.lua")
dofile("shared/lightrp.lua")
dofile("client/hud.lua")

local S = ArenaHud
local function notices()
    local out = {}
    for _, e in ipairs(env.events) do if e.name == "op77_lightrp:notice" then out[#out + 1] = e.args[1] end end
    return out
end

local function ffaState(over)
    local s = {
        playerId = 3, participant = true, mode = "ffa", phase = "active", roundState = "active",
        instanceId = 1, round = 2, killLimit = 25, remainingMs = 120000, participantCount = 3,
        weapon = { key = "ajax", label = "Ajax" },
        instance = { id = 1, format = "ffa", ruleset = "standard" },
        self = { id = 3, rank = 2, kills = 4, deaths = 1, score = 400, streak = 2, protection = { remainingMs = 1000, totalMs = 4000 } },
        rows = DeathmatchWire.packRows({
            { id = 4, name = "Vee", kills = 6, deaths = 0, score = 600, active = true },
            { id = 3, name = "Jackie", kills = 4, deaths = 1, score = 400, active = true },
            { id = 5, name = "Gone", kills = 1, deaths = 3, score = 100, active = false },
        }),
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

-- ── Combat Zone HUD shape ──
do
    env.net["deathmatch:state"](ffaState())
    local hud = env.shows[#env.shows]
    assert(hud and S.shown == true)
    assert(hud.activity == "arena.ffa" and hud.title == "Combat Zone" and hud.phase == "running")
    assert(hud.subtitle == "Round 2 - Ajax" and hud.objective == "First to 25 kills")
    assert(hud.timer.remainingMs == 120000 and hud.timer.label == "Round")
    assert(#hud.stats <= 4 and hud.stats[1].value == 4 and hud.stats[3].value == "2/3")
    assert(hud.progress[1].id == "shield" and hud.progress[1].value == 0.25)
    assert(#hud.scoreboard.rows == 2, "players who left are not listed")
    assert(hud.scoreboard.rows[2].self == true and hud.scoreboard.rows[1].values[1] == 6)
    assert(#hud.hints <= 4)
    for _, hint in ipairs(hud.hints) do assert(hint.key ~= "TAB", "TAB is the weapon wheel") end
    assert(#env.pushes == 0, "no result card mid-round")
    say("PASS combat zone hud")
end

-- ── Blade Night: no gun in the subtitle, its own activity id ──
do
    env.net["deathmatch:state"](ffaState({ mode = "blade", instance = { id = 2, format = "ffa", ruleset = "blade" }, instanceId = 2 }))
    local hud = env.shows[#env.shows]
    assert(hud.activity == "arena.blade" and hud.title == "Blade Night" and hud.subtitle == "Round 2")
    say("PASS blade night hud")
end

-- ── the end of a round: one result card per round ──
do
    env.pushes = {}
    local over = ffaState({ phase = "standings", roundState = "standings", remainingMs = 8000,
        result = { winnerId = 4, winnerName = "Vee" } })
    env.net["deathmatch:state"](over)
    env.net["deathmatch:state"](over)
    local hud = env.shows[#env.shows]
    assert(hud.phase == "ended" and hud.timer.label == "Next round")
    assert(#env.pushes == 1 and env.pushes[1].kind == "result")
    local card = env.pushes[1].payload
    assert(card.title == "ROUND OVER" and card.placement == 2 and card.subtitle == "Vee takes the round")
    -- Next round, and this one is won.
    env.net["deathmatch:state"](ffaState({ round = 3, phase = "standings", roundState = "standings",
        result = { winnerId = 3, winnerName = "Jackie" } }))
    assert(#env.pushes == 2 and env.pushes[2].payload.title == "ROUND WON")
    say("PASS round result card")
end

-- ── a duel: names, sides, countdown, match card ──
do
    env.pushes = {}
    local duel = {
        playerId = 3, participant = true, mode = "1v1", phase = "buy", roundState = "buy", instanceId = 7, remainingMs = 5000,
        instance = { id = 7, format = "1v1", ruleset = "standard" },
        self = { id = 3, kills = 1, deaths = 0 },
        arena = { side = 2, format = "1v1", round = 2, bestOf = 3, wins = { 0, 1 }, aliveByTeam = { 1, 1 }, kit = "rifle" },
        rows = { { id = 3, name = "Jackie", team = 2, kills = 1, deaths = 0, damage = 300 }, { id = 4, name = "Vee", team = 1, kills = 0, deaths = 1, damage = 120 } },
    }
    env.net["deathmatch:state"](duel)
    local hud = env.shows[#env.shows]
    assert(hud.activity == "arena.duel" and hud.title == "Duel" and hud.phase == "countdown" and hud.countdown == 5000)
    assert(hud.subtitle == "Round 2 - best of 3" and hud.objective == "Pick a kit: /arena.kit")
    assert(hud.teams[1].name == "Jackie" and hud.teams[1].score == 1 and hud.teams[1].self == true)
    assert(hud.teams[2].name == "Vee" and hud.teams[2].score == 0)
    assert(hud.scoreboard.rows[1].team == 1 and hud.scoreboard.rows[2].team == 2, "own side first")
    duel.phase, duel.roundState = "resolved", "resolved"
    duel.result = { winnerSide = 2, wins = { 0, 2 } }
    env.net["deathmatch:state"](duel)
    env.net["deathmatch:state"](duel)
    assert(#env.pushes == 1 and env.pushes[1].payload.title == "MATCH WON" and env.pushes[1].payload.subtitle == "2 - 0")
    -- Team Arena keeps the generic team names.
    duel.arena.format, duel.instance.format, duel.instanceId = "3v3", "3v3", 8
    duel.phase, duel.roundState, duel.result = "active", "active", nil
    env.net["deathmatch:state"](duel)
    hud = env.shows[#env.shows]
    assert(hud.activity == "arena.teams" and hud.title == "Team Arena 3v3" and hud.teams[1].name == "Your team")
    assert(hud.objective == "1 alive vs 1")
    say("PASS duel + team hud")
end

-- ── feed and banners while shown ──
do
    env.pushes, env.events = {}, {}
    env.net["deathmatch:killfeed"]({ killerId = 3, killerName = "Jackie", victimId = 4, victimName = "Vee", headshot = true })
    assert(env.pushes[1].kind == "feed" and env.pushes[1].payload.text == "Jackie > Vee (headshot)" and env.pushes[1].payload.tone == "success")
    env.net["deathmatch:killfeed"]({ killerId = 4, killerName = "Vee", victimId = 3, victimName = "Jackie" })
    assert(env.pushes[2].payload.tone == "danger")
    env.net["deathmatch:callout"]({ kind = "streak", count = 3 })
    assert(env.pushes[3].payload.text == "Kill streak x3" and env.pushes[3].payload.tone == "accent")
    env.net["deathmatch:notice"]({ kind = "warning", title = "QUEUE CANCELLED", message = "Step out of the vehicle first." })
    assert(env.pushes[4].kind == "banner" and env.pushes[4].payload.tone == "danger" and #notices() == 0)
    say("PASS feed + banners")
end

-- ── the way home clears; a state without a match clears ──
do
    local clears = env.clears
    env.net["op77_arena:returned"]()
    assert(env.clears == clears + 1 and S.shown == false and S.state == nil)
    env.net["op77_arena:returned"]()
    assert(env.clears == clears + 1, "nothing to clear twice")
    env.pushes = {}
    env.net["deathmatch:killfeed"]({ killerId = 3, killerName = "Jackie", victimId = 4, victimName = "Vee" })
    assert(#env.pushes == 0, "no feed without a HUD")
    env.net["deathmatch:state"](ffaState())
    env.net["deathmatch:state"]({ playerId = 3, participant = false })
    assert(S.shown == false)
    say("PASS clear")
end

-- ── fragments on the wire ──
do
    decoded["{part1}{part2}"] = ffaState({ instanceId = 9, round = 1 })
    env.net["deathmatch:state"]({ stateFragments = { "{part1}", "{part2}" } })
    assert(S.shown == true and env.shows[#env.shows].subtitle:find("Round 1"))
    say("PASS wire fragments")
end

-- ── an older core: exports missing / raising / Light RP stopped -> notices ──
do
    env.events, env.pushes = {}, {}
    exports.op77_lightrp = setmetatable({}, { __index = function() error("No such export ActivityHudShow") end })
    env.net["op77_arena:returned"]()
    env.net["deathmatch:state"](ffaState({ instanceId = 10 }))
    assert(S.shown == false, "a raising export never escapes")
    env.net["deathmatch:notice"]({ kind = "success", title = "ROUND WON", message = "You won the round." })
    local n = notices()
    assert(#n == 1 and n[1].title == "ROUND WON" and n[1].body == "You won the round." and n[1].source == "COMBAT ZONE")
    env.net["deathmatch:state"](ffaState({ instanceId = 10, round = 4, phase = "standings", roundState = "standings",
        result = { winnerId = 3, winnerName = "Jackie" } }))
    n = notices()
    assert(#n == 2 and n[2].title == "ROUND WON" and n[2].kind == "info", "the result card becomes a notice")
    exports.op77_lightrp = core
    env.state = "stopped"
    env.events = {}
    env.net["deathmatch:state"](ffaState({ instanceId = 11 }))
    assert(S.shown == false and #env.shows > 0)
    env.state = "running"
    say("PASS fallback without the HUD exports")
end

-- ── a rate-limited update keeps the HUD ours to clear ──
do
    env.net["deathmatch:state"](ffaState({ instanceId = 12 }))
    assert(S.shown == true)
    env.answer = { false, "rate_limited" }
    env.net["deathmatch:state"](ffaState({ instanceId = 12 }))
    assert(S.shown == true)
    env.answer = { false, "invalid_hud" }
    env.net["deathmatch:state"](ffaState({ instanceId = 12 }))
    assert(S.shown == false)
    env.answer = { true }
    say("PASS rate limit")
end

-- ── stopping the resource clears ──
do
    env.net["deathmatch:state"](ffaState({ instanceId = 13 }))
    local clears = env.clears
    env.handlers["onClientResourceStop"]("op77_lightrp")
    assert(env.clears == clears)
    env.handlers["onClientResourceStop"]("op77_arena")
    assert(env.clears == clears + 1)
    say("PASS resource stop")
end

-- ── bots: the [BOT] marker everywhere, the practice hint, PvE sides ──
do
    env.pushes, env.events = {}, {}
    -- Combat Zone with bots (staff bot mode): names marked, hint shown.
    env.net["deathmatch:state"](ffaState({ instanceId = 20, instance = { id = 20, format = "ffa", ruleset = "standard", bots = 2 },
        rows = {
            { id = 3, name = "Jackie", kills = 4, deaths = 1, score = 400, active = true },
            { id = -1, name = "[BOT] Ash", bot = true, kills = 2, deaths = 2, score = 200, active = true },
            { id = -2, name = "BOT 2", kills = 1, deaths = 3, score = 100, active = true },
        } }))
    local hud = env.shows[#env.shows]
    assert(hud.scoreboard.rows[1].name == "Jackie")
    assert(hud.scoreboard.rows[2].name == "[BOT] Ash", "the engine's prefix is not doubled")
    assert(hud.scoreboard.rows[3].name == "[BOT] 2", "the engine's fallback name is re-marked")
    local hinted = false
    for _, hint in ipairs(hud.hints) do if hint.key == "BOTS" and hint.label:find("not recorded") then hinted = true end end
    assert(hinted and #hud.hints <= 4, "bot practice is said on screen")
    -- Without bots: no hint.
    env.net["deathmatch:state"](ffaState({ instanceId = 21 }))
    hud = env.shows[#env.shows]
    for _, hint in ipairs(hud.hints) do assert(hint.key ~= "BOTS") end
    -- Kill feed.
    env.net["deathmatch:killfeed"]({ killerId = -1, killerName = "Ash", killerBot = true, victimId = 3, victimName = "Jackie" })
    assert(env.pushes[#env.pushes].payload.text == "[BOT] Ash > Jackie" and env.pushes[#env.pushes].payload.tone == "danger")
    env.net["deathmatch:killfeed"]({ killerId = 3, killerName = "Jackie", victimId = -2, victimName = "[BOT] Rook", victimBot = true })
    assert(env.pushes[#env.pushes].payload.text == "Jackie > [BOT] Rook")
    -- A duel against a bot: the opponent's name is marked.
    env.net["deathmatch:state"]({
        playerId = 3, participant = true, mode = "1v1", phase = "active", roundState = "active", instanceId = 22, remainingMs = 5000,
        instance = { id = 22, format = "1v1", ruleset = "standard", bots = 1 },
        self = { id = 3, kills = 0, deaths = 0 },
        arena = { side = 1, format = "1v1", round = 1, bestOf = 3, wins = { 0, 0 }, aliveByTeam = { 1, 1 } },
        rows = { { id = 3, name = "Jackie", team = 1 }, { id = -5, name = "Ash", team = 2, bot = true } },
    })
    hud = env.shows[#env.shows]
    assert(hud.teams[2].name == "[BOT] Ash" and hud.scoreboard.rows[2].name == "[BOT] Ash")
    local duelHint = false
    for _, hint in ipairs(hud.hints) do if hint.key == "BOTS" then duelHint = true end end
    assert(duelHint and #hud.hints <= 4)
    -- PvE: its own activity and title, players vs bots, no practice hint (it is recorded).
    local pve = ffaState({ instanceId = 23, mode = "ffa", instance = { id = 23, format = "ffa", ruleset = "pve", bots = 3 },
        rows = {
            { id = 3, name = "Jackie", kills = 4, deaths = 1, score = 400, active = true },
            { id = 4, name = "Vee", kills = 2, deaths = 0, score = 200, active = true },
            { id = -7, name = "[BOT] Ash", bot = true, kills = 1, deaths = 3, score = 100, active = true },
        } })
    env.net["deathmatch:state"](pve)
    hud = env.shows[#env.shows]
    assert(hud.activity == "arena.pve" and hud.title == LightRpArena.activities.pve.label)
    assert(hud.teams[1].name == "Players" and hud.teams[1].score == 6 and hud.teams[1].self == true)
    assert(hud.teams[2].name == "[BOT] Gangs" and hud.teams[2].score == 1)
    assert(hud.scoreboard.rows[1].team == 1 and hud.scoreboard.rows[3].team == 2 and hud.scoreboard.rows[3].name == "[BOT] Ash")
    for _, hint in ipairs(hud.hints) do assert(hint.key ~= "BOTS", "PvE is not practice") end
    env.pushes = {}
    pve.phase, pve.roundState, pve.result = "standings", "standings", { winnerId = 3, winnerName = "Jackie" }
    env.net["deathmatch:state"](pve)
    assert(#env.pushes == 1 and env.pushes[1].payload.title == "PLAYERS WIN" and env.pushes[1].payload.subtitle == "Players 6 - 1 bots")
    say("PASS bots + PvE hud")
end

say("PASS: op77_arena hud (shape, limits, result once, feed, fallback to notices, rate limit, clear, bots, PvE)")
