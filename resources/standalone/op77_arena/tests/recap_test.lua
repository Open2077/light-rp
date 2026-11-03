-- The scoreboard a Light RP result carries for the end-of-match recap
-- (server/lightrp_recap.lua): damage taken in scoring.lua (bots both ways, cleared
-- each round), an FFA round with its bots marked, PvE sides, and a team match summed
-- over its rounds with each round's winner. Real scoring.lua, the host stubbed.
local T = 1000000
Deathmatch = {
    nowMs = function() return T end,
    finite = function(v) v = tonumber(v); if v == nil or v ~= v or v == math.huge or v == -math.huge then return nil end return v end,
    playerName = function(id) return "acct" .. id end,
    log = function() end,
    notice = function() end,
    broadcastState = function() end,
    playerId = function(v) local n = tonumber(v); return n and math.floor(n) or nil end,
    instances = { registry = {}, humans = function(instance)
        local out = {}
        for id in pairs(instance.members) do if id > 0 then out[#out + 1] = id end end
        table.sort(out)
        return out
    end },
}
DeathmatchConfig = { scoring = { kill = 100, assist = 50, assistThreshold = 0.3 } }
Open77 = { players = { name = function(id) return "p" .. id end, getLifeState = function() return { phase = "dead" } end,
    position = function() return nil end }, npcs = { get = function() return nil end } }
AddEventHandler, RegisterNetEvent, RegisterCommand, TriggerClientEvent, TriggerEvent = function() end, function() end, function() end, function() end, function() end
dofile("server/scoring.lua")
local DM, S = Deathmatch, Deathmatch.scoring
ArenaHost = { entered = {}, night = nil }
local H = ArenaHost
dofile("server/lightrp_recap.lua")
local AR = ArenaRecap
local function rowOf(rows, id) for _, row in ipairs(rows) do if row.id == id then return row end end end

-- ── damage taken: a player on a bot (bots.lua credits it), a bot on a player ──
local ffa = { id = 7, format = "ffa", ruleset = "standard", members = { [3] = true, [4] = true }, actors = { [-2] = true } }
DM.instances.registry[7] = ffa
S.addParticipant(ffa, 3); S.addParticipant(ffa, 4); S.addParticipant(ffa, -2, { name = "[BOT] Rex", bot = true })
S.beginRound(ffa, "7:3")
assert(S.creditDamage(ffa, 3, -2, 40, { maxHealth = 100 }))
assert(S.creditDamage(ffa, -2, 3, 25, { maxHealth = 100 }))
assert(S.creditDamage(ffa, 4, 3, 10, { maxHealth = 100 }))
assert(S.creditDamage(ffa, nil, 4, 5, { maxHealth = 100 }), "a fall: taken, nobody credited")
local rows = S.rows(ffa)
assert(rowOf(rows, 3).damage == 40 and rowOf(rows, 3).damageTaken == 35)
assert(rowOf(rows, -2).damage == 25 and rowOf(rows, -2).damageTaken == 40 and rowOf(rows, -2).bot == true)
assert(rowOf(rows, 4).damage == 10 and rowOf(rows, 4).damageTaken == 5)
S.beginRound(ffa, "7:4")
assert(S.rows(ffa)[1].damageTaken == 0, "cleared with the round")
S.beginRound(ffa, "7:3")
S.creditDamage(ffa, 3, -2, 40, { maxHealth = 100 }); S.creditDamage(ffa, -2, 3, 25, { maxHealth = 100 }); S.creditDamage(ffa, 4, 3, 10, { maxHealth = 100 })

-- ── one FFA round: every participant, bots marked, time in the round ──
ffa.round = { id = "7:3", number = 3, startedAtMs = T - 90000, state = "standings" }
H.entered[3] = { instanceId = 7, atMs = T - 300000 }
H.entered[4] = { instanceId = 7, atMs = T - 30000 } -- dropped in late
local recap = AR.ffa(ffa, 3)
assert(recap.matchId == "arena:7:3" and recap.durationMs == 90000 and recap.detail == "Round 3")
assert(#recap.rows == 3)
local bot = rowOf(recap.rows, -2)
assert(bot.bot == true and bot.name == "[BOT] Rex" and bot.damage == 25 and bot.damageTaken == 40 and bot.inMatchMs == 90000)
assert(rowOf(recap.rows, 3).inMatchMs == 90000 and rowOf(recap.rows, 4).inMatchMs == 30000, "from the round start or the entry")
assert(rowOf(recap.rows, 3).placement and rowOf(recap.rows, 3).bot == nil)
assert(recap.lines[1].value == "3" and recap.lines[2].label == "Winner" and recap.lines[2].value == "acct3")

-- ── PvE: players against bots ──
local pve = AR.pve(ffa, 4, 2, true)
assert(pve.sides[1].label == "Operators" and pve.sides[1].score == 4 and pve.sides[2].score == 2 and pve.winnerSide == 1)
assert(rowOf(pve.rows, -2).side == 2 and rowOf(pve.rows, 3).side == 1)

-- ── a 2v2 match summed over its rounds, bots included, each round's winner ──
local teams = { id = 9, format = "2v2", members = { [5] = true, [6] = true }, actors = { [-4] = true, [-5] = true } }
DM.instances.registry[9] = teams
for _, id in ipairs({ 5, 6, -4, -5 }) do S.addParticipant(teams, id, id < 0 and { bot = true } or nil) end
S.setTeam(teams, 5, 1); S.setTeam(teams, -4, 1); S.setTeam(teams, 6, 2); S.setTeam(teams, -5, 2)
teams.match = { format = "2v2", sides = { [5] = 1, [6] = 2 }, wins = { 0, 0 }, state = "playing", startedAtMs = T - 1000 }
H.entered[5] = { instanceId = 9, atMs = T - 1000 }
H.entered[6] = { instanceId = 9, atMs = T - 1000 }
-- round 1: side 1 wins
S.beginRound(teams, "9:1")
teams.round = { id = "9:1", number = 1, state = "active" }
S.creditDamage(teams, 5, 6, 100, { maxHealth = 100 }); S.creditKill(teams, 5, 6, {})
S.creditDamage(teams, -5, -4, 60, { maxHealth = 100 })
AR.sample(teams)
teams.round.state, teams.round.winnerSide, teams.match.wins = "between", 1, { 1, 0 }
AR.sample(teams)
-- round 2: side 2 wins (the board clears)
T = T + 60000
S.beginRound(teams, "9:2")
teams.round = { id = "9:2", number = 2, state = "active" }
S.creditDamage(teams, 6, 5, 100, { maxHealth = 100 }); S.creditKill(teams, 6, 5, {})
AR.sample(teams)
teams.round.state, teams.round.winnerSide, teams.match.wins = "between", 2, { 1, 1 }
-- round 3: side 1 wins, the match resolves; no tick after the last round
T = T + 60000
S.beginRound(teams, "9:3")
teams.round = { id = "9:3", number = 3, state = "active" }
S.creditDamage(teams, 5, 6, 50, { maxHealth = 100 }); S.creditDamage(teams, -4, 6, 50, { maxHealth = 100 }); S.creditKill(teams, -4, 6, {})
teams.round.state, teams.round.winnerSide = "resolved", 1
teams.match.state = "resolved"
teams.match.result = { reason = "best_of", winnerSide = 1, wins = { 2, 1 }, rounds = 3 }
local m = AR.match(teams)
assert(m.matchId:match("^arena:9:m%d+$") and m.winnerSide == 1 and m.sides[1].score == 2 and m.sides[2].score == 1)
assert(m.durationMs == 121000 and m.detail == "2v2")
local p5, p6, b4 = rowOf(m.rows, 5), rowOf(m.rows, 6), rowOf(m.rows, -4)
assert(p5.side == 1 and p6.side == 2 and b4.side == 1 and b4.bot == true)
assert(p5.kills == 1 and p5.deaths == 1 and p5.damage == 150 and p5.damageTaken == 100, "three rounds summed")
assert(p6.kills == 1 and p6.deaths == 2 and p6.damage == 100 and p6.damageTaken == 200)
assert(b4.kills == 1 and b4.damage == 50 and b4.damageTaken == 60)
local lines = {}
for _, l in ipairs(m.lines) do lines[l.label] = l.value end
assert(lines.Rounds == "2 - 1" and lines["Round 1"] == "Team A" and lines["Round 2"] == "Team B" and lines["Round 3"] == "Team A")
-- the same match asked again (a second player's result) is the same board
local again = AR.match(teams)
assert(again.matchId == m.matchId and rowOf(again.rows, 5).damage == 150)
-- a forfeit says so
teams.match.result.reason = "opponents_left"
assert(AR.match(teams).detail == "2v2 · opponents_left")
print("op77_arena recap_test: ok")
