-- ArenaCore: the Light RP activity contract calls, with the host stubbed.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test core_test.lua
local env = { calls = {}, events = {}, answers = {}, raise = nil }

local function pack(...) local t = table.pack(...); t.multi = true; return t end

_G.Open77 = {
    exports = {
        callSync = function(resource, name, ...)
            env.calls[#env.calls + 1] = { resource = resource, name = name, args = table.pack(...) }
            if env.raise then error(env.raise) end
            local answer = env.answers[name]
            if type(answer) == "table" and answer.multi then return table.unpack(answer, 1, answer.n) end
            return answer
        end,
    },
}
_G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
local say = print
_G.print = function() end

dofile("shared/config.lua")
dofile("shared/kabuki.lua")
dofile("shared/wire.lua")
dofile("shared/lightrp.lua")
dofile("server/core.lua")

local C = ArenaCore

-- register: the definition goes to op77_lightrp unchanged.
env.answers.activityRegister = true
assert(C.register({ id = "arena.ffa" }) == true)
assert(env.calls[1].resource == "op77_lightrp" and env.calls[1].name == "activityRegister")
env.answers.activityRegister = pack(false, "The id arena.ffa belongs to another resource.")
local ok, why = C.register({ id = "arena.ffa" })
assert(ok == false and why:find("belongs"))

-- check / enter carry the activity id; a refusal keeps Light RP's sentence.
env.calls = {}
env.answers.activityCheck = pack(false, "Step out of the vehicle first.")
ok, why = C.check(7, "arena.duel")
assert(ok == false and why == "Step out of the vehicle first.")
assert(env.calls[1].args[1] == 7 and env.calls[1].args[2] == "arena.duel")
env.answers.activityCheck = true
assert(C.check(7, "arena.ffa") == true)
env.answers.activityEnter = false
ok, why = C.enter(7, "arena.ffa")
assert(ok == false and why == "You cannot join right now.", "a bare false still gets a sentence")
env.answers.activityEnter = true
assert(C.enter(7, "arena.ffa") == true)

-- A raising export (core stopped, older core) never escapes.
env.raise = "no such export"
ok, why = C.check(7, "arena.ffa")
assert(ok == false and why == "Light RP did not answer. Try again in a moment.")
assert(C.enter(7, "arena.ffa") == false)
assert(C.leave(7, "arena.ffa") == false)
assert(C.owner(7) == nil and C.player(7) == nil and C.register({}) == false)
env.raise = nil
local saved = Open77.exports
Open77.exports = nil
ok, why = C.check(7, "arena.ffa")
assert(ok == false and why:find("did not answer"))
Open77.exports = saved

-- leave: returnPlayer defaults to true, false is kept.
env.calls = {}
env.answers.activityLeave = true
assert(C.leave(7, "arena.teams") == true)
assert(env.calls[1].args[2] == "arena.teams" and env.calls[1].args[3].returnPlayer == true)
assert(C.leave(7, "arena.teams", { returnPlayer = false }) == true and env.calls[2].args[3].returnPlayer == false)
assert(C.leave(7, "arena.teams", {}) == true and env.calls[3].args[3].returnPlayer == true)

-- owner / player
env.answers.activityOwner = "arena.ffa"
assert(C.owner(7) == "arena.ffa")
env.answers.activityOwner = nil
assert(C.owner(7) == nil)
env.answers.activityPlayer = { name = "Vee Kade", identifier = "license:abc", characterKey = "2" }
assert(C.player(7).name == "Vee Kade")
env.answers.activityPlayer = "garbage"
assert(C.player(7) == nil)

-- result / status: host-wide events; a status goes out only when it changed.
C.result(7, "arena.duel", { placement = 1, won = true, reputation = 20 })
local e = env.events[#env.events]
assert(e.name == "op77_lightrp:activity:result" and e.args[1] == 7 and e.args[2] == "arena.duel" and e.args[3].won == true)
env.events = {}
local s = { phase = "lobby", players = 0, queued = 1, joinable = true, detail = "1 waiting" }
assert(C.status("arena.duel", s) == true and C.status("arena.duel", s) == false, "same status twice is sent once")
assert(C.status("arena.teams", s) == true, "deduplicated per activity")
assert(C.status("arena.duel", s, true) == true, "forced")
C.forgetStatuses()
assert(C.status("arena.duel", s) == true, "forgotten after a core restart")
assert(#env.events == 4 and env.events[1].name == "op77_lightrp:activity:status" and env.events[1].args[1] == "arena.duel")

-- The queue shape (status.queue v1) is in the digest: a countdown running down is no
-- change, a player who joined is.
local q = { phase = "lobby", players = 0, queued = 1, joinable = true, detail = "1 waiting",
    queue = C.queue({ C.lobby({ 7 }, 2, { startsInMs = 20000 }) }) }
assert(q.queue.v == 1 and q.queue.lobbies[1].players[1] == 7 and q.queue.lobbies[1].need == 2)
assert(C.status("arena.duel", q, false, 100000) == true)
q.queue.lobbies[1].startsInMs = 15000
assert(C.status("arena.duel", q, false, 105000) == false, "the same deadline")
q.queue.lobbies[1].players = { 7, 8 }
assert(C.status("arena.duel", q, false, 105000) == true, "a player joined")
assert(C.queueDigest(nil) == "-" and #C.queue().lobbies == 0)

say("PASS: op77_arena core (contract calls, sentences, raising exports, leave defaults, status dedupe)")
