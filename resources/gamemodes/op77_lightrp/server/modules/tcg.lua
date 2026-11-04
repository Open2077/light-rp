-- Cyberpunk TCG (the standalone resource op77_tcg) in LightRP: sealed product is inventory items, and each
-- character is its own collector (op77_tcg asks neuralink_bridge's characterIdentity).
--
--   items  tcg_booster_wnc, tcg_booster_beta, tcg_display_wnc (shared/items.lua), sold at the NEON DECK vendor
--          (server/config/shops.lua, template tcg_shop)
--   use    asks op77_tcg to open the real thing on the player's screen (exports.op77_tcg:useSealed): a booster
--          tears open in the hands, a display has its shrink-wrap cut. The item stays in the bag until then:
--          op77_tcg takes it when the pack is actually torn / the wrap cut, through the exports below.
--   exports for op77_tcg (products: wnc, beta, box)
--          tcgSealed(playerId)                   -> { product = count }          read-only, callable synchronously
--          tcgTakeSealed(playerId, product, n)   -> true | false                 writes: Open77.exports.call only
--          tcgGiveSealed(playerId, product, n)   -> true | false, reason         writes: Open77.exports.call only
-- Without op77_tcg running, a TCG item cannot be used (it is not consumed) and the rest of LightRP is unaffected.
local Tcg = LightRP.module("tcg", {})
local Inv = LightRP.inventory

local ITEMS = { wnc = "tcg_booster_wnc", beta = "tcg_booster_beta", box = "tcg_display_wnc" }
local PRODUCTS = {}
for product, item in pairs(ITEMS) do PRODUCTS[item] = product end
Tcg.items, Tcg.products = ITEMS, PRODUCTS

local function inventoryOf(playerId)
    playerId = math.tointeger(tonumber(playerId))
    if not playerId or playerId < 1 then return nil end
    return Inv.playerId(playerId)
end

local function amount(n)
    n = math.tointeger(tonumber(n) or 1)
    if not n or n < 1 or n > 1000 then return nil end
    return n
end

local REFUSED = {
    too_heavy = "Your bag is too heavy for the packs. Make some room and cut it again.",
    no_room = "No room in your bag for the packs. Free a slot and cut it again.",
    busy = "Your inventory is busy. Try again in a moment.",
    database_unavailable = "The inventory cannot be saved right now. Nothing changed.",
}

function Tcg.sealed(playerId)
    local id, out = inventoryOf(playerId), {}
    if not id then return out end
    for product, item in pairs(ITEMS) do out[product] = Inv.count(id, item) end
    return out
end

function Tcg.take(playerId, product, n)
    local id, item, count = inventoryOf(playerId), ITEMS[product], amount(n)
    if not id or not item or not count then return false end
    local ok = Inv.removeItem(id, item, count)
    return ok == true
end

function Tcg.give(playerId, product, n)
    local id, item, count = inventoryOf(playerId), ITEMS[product], amount(n)
    if not id or not item or not count then return false, "This collector has no inventory." end
    local ok, reason = Inv.addItem(id, item, count)
    if ok then return true end
    return false, REFUSED[reason] or (Inv.explain and Inv.explain(reason)) or tostring(reason)
end

exports("tcgSealed", function(playerId) return Tcg.sealed(playerId) end)
exports("tcgTakeSealed", function(playerId, product, n) return Tcg.take(playerId, product, n) end)
exports("tcgGiveSealed", function(playerId, product, n) return Tcg.give(playerId, product, n) end)

-- Using an item: op77_tcg opens it on the player's screen; the item is not consumed here ("keep").
local function use(playerId, item)
    local product = PRODUCTS[item.name]
    local ok, started, why = pcall(function() return exports.op77_tcg:useSealed(playerId, product) end)
    if not ok or started ~= true then
        LightRP.log("tcg: %s for %s refused (%s)", tostring(item.name), tostring(playerId), tostring(ok and why or started))
        LightRP.notice(playerId, { kind = "info", title = "Cyberpunk TCG", body = "The cards are unavailable right now.", durationMs = 4000 })
        return false
    end
    return "keep", product == "box" and "Cut the shrink-wrap" or "Tear it open"
end

for item in pairs(PRODUCTS) do Inv.onUse(item, use) end

