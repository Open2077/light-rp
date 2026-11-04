-- The Cyberpunk TCG bridge (server/modules/tcg.lua): the sealed items op77_tcg reads, takes and gives through
-- LightRP's inventory, and an item use that hands over to op77_tcg without consuming the item.
local published, notices, logs = {}, {}, {}
local running, started = true, {}
local tcg = { useSealed = function(_, playerId, product)
    if playerId == 9 then return false, "no_collector" end
    started[#started + 1] = { player = playerId, product = product }
    return true
end }
_G.exports = setmetatable({}, {
    __call = function(_, name, fn) published[name] = fn end,
    __index = function(_, name) if name == "op77_tcg" and running then return tcg end error("no such resource: " .. tostring(name)) end,
})

-- A bag: item name -> count, with a number of free units (room) and a weight it refuses past.
local bags = { [3] = { items = { tcg_booster_wnc = 2, tcg_display_wnc = 1 }, room = 30 } }
local handlers = {}
local Inv = {
    playerId = function(p) return bags[p] and ("player:" .. p) or nil end,
    count = function(id, name) local b = bags[tonumber(id:match("%d+"))]; return b and (b.items[name] or 0) or 0 end,
    removeItem = function(id, name, n)
        local b = bags[tonumber(id:match("%d+"))]
        if (b.items[name] or 0) < n then return false, "not_enough" end
        b.items[name] = b.items[name] - n; b.room = b.room + n
        return true
    end,
    addItem = function(id, name, n)
        local b = bags[tonumber(id:match("%d+"))]
        if b.room < n then return false, "no_room" end
        b.items[name] = (b.items[name] or 0) + n; b.room = b.room - n
        return true
    end,
    onUse = function(name, fn) handlers[name] = fn end,
    explain = function(reason) return "explained:" .. tostring(reason) end,
}
_G.LightRP = {
    inventory = Inv,
    log = function(fmt, ...) logs[#logs + 1] = fmt:format(...) end,
    notice = function(playerId, n) notices[#notices + 1] = { player = playerId, body = n.body } end,
}
function LightRP.module(name, def) LightRP[name] = def; return def end

dofile("server/modules/tcg.lua")

-- Every sealed item is usable (a handler), and maps to its op77_tcg product.
for _, item in ipairs({ "tcg_booster_wnc", "tcg_booster_beta", "tcg_display_wnc" }) do assert(handlers[item], item .. " usable") end
assert(LightRP.tcg.products.tcg_display_wnc == "box" and LightRP.tcg.items.beta == "tcg_booster_beta")

-- Reading the bag.
local sealed = published.tcgSealed(3)
assert(sealed.wnc == 2 and sealed.box == 1 and sealed.beta == 0, "sealed counts from the bag")
assert(next(published.tcgSealed(4)) == nil, "no character inventory: nothing")

-- Taking: one booster when the pack is torn; never more than there is; nonsense refused.
assert(published.tcgTakeSealed(3, "wnc", 1) == true and bags[3].items.tcg_booster_wnc == 1, "a booster taken")
assert(published.tcgTakeSealed(3, "wnc", 5) == false and bags[3].items.tcg_booster_wnc == 1, "not more than the bag holds")
assert(published.tcgTakeSealed(3, "nope", 1) == false and published.tcgTakeSealed(3, "wnc", 0) == false
    and published.tcgTakeSealed(3, "wnc", 1.5) == false and published.tcgTakeSealed(4, "wnc", 1) == false, "invalid takes refused")

-- Giving: a display's 24 boosters; no room -> false and a sentence the player can act on.
assert(published.tcgGiveSealed(3, "wnc", 24) == true and bags[3].items.tcg_booster_wnc == 25, "24 boosters given")
bags[3].room = 3
local ok, why = published.tcgGiveSealed(3, "wnc", 24)
assert(ok == false and why:find("No room", 1, true) and bags[3].items.tcg_booster_wnc == 25, "no room: refused, explained")
assert(published.tcgGiveSealed(3, "wnc", 2000) == false, "absurd counts refused")

-- Using an item: op77_tcg starts it, the item is kept (op77_tcg takes it when the pack is really torn).
local result, text = handlers.tcg_booster_wnc(3, { name = "tcg_booster_wnc", count = 1 }, {})
assert(result == "keep" and text == "Tear it open" and started[1].player == 3 and started[1].product == "wnc", "booster use")
result, text = handlers.tcg_display_wnc(3, { name = "tcg_display_wnc", count = 1 }, {})
assert(result == "keep" and text == "Cut the shrink-wrap" and started[2].product == "box", "display use")
-- op77_tcg refuses (no collector yet) or is not running: refused, not consumed, the player told why.
assert(handlers.tcg_booster_wnc(9, { name = "tcg_booster_wnc", count = 1 }, {}) == false and #notices == 1, "refused by op77_tcg")
running = false
assert(handlers.tcg_booster_beta(3, { name = "tcg_booster_beta", count = 1 }, {}) == false and #notices == 2, "op77_tcg not running")
assert(#started == 2 and #logs == 2, "nothing started, both refusals logged")

print("PASS: tcg bridge (sealed items read / taken / given with refusals, item use hands over to op77_tcg and keeps the item)")
