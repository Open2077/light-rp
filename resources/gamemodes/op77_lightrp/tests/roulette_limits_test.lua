-- Roulette stakes (prod audit 2026-11-04, docs/economy-balance.md §15, divided by 10 by
-- the owner decision of §16): 1 to 100 a bet and 500 per character and spin, like the
-- fortune wheel. The pure rules, then
-- the server controller (server/modules/tabletop_extra.lua) with the inventory and
-- SQL stubbed: the limit follows the character, whatever seat it bets from.
dofile("shared/tabletop_extra_rules.lua")
local R = LightRpTabletopExtraRules
assert(R.MIN_BET == 1 and R.MAX_BET == 100 and R.MAX_ROUND == 500)
local s = R.new("roulette")
assert(R.act(s, "white", "bet", { bet = "red", amount = 100 }), "the table limit is a valid bet")
local refused, why = R.act(s, "white", "bet", { bet = "red", amount = 101 })
assert(not refused and why:find("between 1 and 100", 1, true), tostring(why))
assert(not R.act(s, "white", "bet", { bet = "red", amount = 1000 }), "the old 1,000 limit is gone")
assert(not R.act(s, "white", "bet", { bet = 17, amount = 1000000 }), "a million on a number (36 million back) is gone")

local cash = { inv1 = 100000, inv2 = 100000 }
local inventories = { [1] = { id = "inv1", persistent = true }, [2] = { id = "inv2", persistent = true } }
Open77 = { time = { unix = function() return 1000 end } }
CreateThread = function() end
LightRP = {
    db = { schema = function() end, ready = false }, log = function() end, notice = function() end,
    module = function(_, t) return t end,
    inventory = {
        player = function(p) return inventories[p] end,
        draft = function(inv) return { inv = inv, delta = 0 } end,
        adjustCash = function(draft, n)
            if cash[draft.inv.id] + draft.delta + n < 0 then return false, "insufficient_funds" end
            draft.delta = draft.delta + n
            return true
        end,
    },
}
dofile("server/modules/tabletop_extra.lua")
local X = LightRP.tabletopExtra
local board = { id = "t1", kind = "roulette", revision = 1, players = { white = 1, black = 2, white2 = 1 }, game = X.new("roulette") }
local function commit(game, _, changes)
    board.game, board.revision = game, board.revision + 1
    for _, c in ipairs(changes or {}) do cash[c[1].id] = cash[c[1].id] + c[2].delta end
    return true
end
local function bet(player, what, amount) return X.act(player, board, "bet", { bet = what, amount = amount }, commit) end

for i = 1, 5 do assert(bet(1, i % 2 == 0 and "red" or 17, 100), "bet " .. i) end
local ok, reason = bet(1, "black", 1)
assert(not ok and reason:find("limited to 500 per spin", 1, true), tostring(reason))
assert(cash.inv1 == 99500, "a refused bet debits nothing")
ok, reason = bet(2, "black", 101)
assert(not ok and reason:find("between 1 and 100", 1, true), tostring(reason))
assert(bet(2, "black", 100) and cash.inv2 == 99900, "another character has their own limit")
-- the spin pays from the stakes as before: at most 36 x 100 on a straight number
assert(X.act(1, board, "spin", {}, commit))
assert(board.game.phase == "spinning")
print("PASS: roulette limits (1-100 a bet, 500 per character and spin, refused bets debit nothing)")
