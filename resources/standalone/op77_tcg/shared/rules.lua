-- op77_tcg rules: pure functions over the catalogue, shared by the server (authority) and the tests.
-- No Open77 call in here: random numbers come from the caller (math.random on the server).
TcgRules = {}
local R = TcgRules

local byId, byTier = {}, {}
for _, e in ipairs(TcgCatalogue) do
    byId[e.id] = e
    if e.booster then
        local t = byTier[e.tier] or { cards = {}, editions = {} }
        byTier[e.tier] = t
        if not t.editions[e.card] then
            t.editions[e.card] = {}
            t.cards[#t.cards + 1] = e.card
        end
        table.insert(t.editions[e.card], e)
    end
end
R.byId = byId
R.byTier = byTier

function R.edition(id) return byId[id] end

-- The premium slot's tier from a roll in [0, total).
function R.premiumTier(roll, weights)
    local acc = 0
    for _, w in ipairs(weights) do
        acc = acc + w.weight
        if roll < acc then return w.tier end
    end
    return weights[#weights].tier
end

local function totalWeight(weights)
    local n = 0
    for _, w in ipairs(weights) do n = n + w.weight end
    return n
end

-- One edition of a base card not yet in `used`, drawn base card first (as the original set: every card is as
-- likely, whatever its number of arts). `filter(edition)` narrows the editions (missing top-tier editions).
local function pick(tier, used, random, filter)
    local t = byTier[tier]
    if not t then return nil end
    local cards = {}
    for _, card in ipairs(t.cards) do
        if not used[card] then
            if filter then
                for _, e in ipairs(t.editions[card]) do if filter(e) then cards[#cards + 1] = card break end end
            else
                cards[#cards + 1] = card
            end
        end
    end
    if #cards == 0 then return nil end
    local card = cards[random(#cards)]
    local editions = t.editions[card]
    if filter then
        local kept = {}
        for _, e in ipairs(editions) do if filter(e) then kept[#kept + 1] = e end end
        editions = kept
    end
    used[card] = true
    return editions[random(#editions)]
end

-- A sealed pack: 9 commons, 2 uncommons, then the premium card, in the order they are revealed.
-- `owned(id) -> count` lets a top-tier pull prefer an edition the collector does not have yet.
function R.roll(pack, random, owned)
    local used, out = {}, {}
    for _ = 1, pack.commons do
        local e = pick(1, used, random)
        if not e then return nil, "catalogue_incomplete" end
        out[#out + 1] = e
    end
    for _ = 1, pack.uncommons do
        local e = pick(2, used, random)
        if not e then return nil, "catalogue_incomplete" end
        out[#out + 1] = e
    end
    local tier = R.premiumTier(random(totalWeight(pack.premium)) - 1, pack.premium)
    local premium
    if tier == 5 and owned then
        premium = pick(5, used, random, function(e) return (owned(e.id) or 0) == 0 end)
    end
    premium = premium or pick(tier, used, random)
    if not premium then return nil, "catalogue_incomplete" end
    out[#out + 1] = premium
    return out
end

-- Dust for recycling `count` copies of an edition; Dust+ for a top-tier one.
function R.recycleValue(edition, count, dust)
    local per = dust.recycle[edition.tier] or 0
    local plus = (edition.tier >= 5) and (dust.dustPlusFromTop * count) or 0
    return per * count, plus
end

-- What printing an edition costs: { dust = n } or { dustPlus = n } for a Secret.
function R.printCost(edition, dust)
    if edition.tier >= 6 then return { dust = 0, dustPlus = dust.secretDustPlus } end
    return { dust = dust.print[edition.tier] or 0, dustPlus = 0 }
end

-- Completion of a collection { [id] = count }: editions owned, base cards owned, per tier.
function R.completion(owned)
    local editions, cards, seen, perTier = 0, 0, {}, {}
    for _, e in ipairs(TcgCatalogue) do
        local t = perTier[e.tier] or { owned = 0, total = 0 }
        perTier[e.tier] = t
        t.total = t.total + 1
        if (owned[e.id] or 0) > 0 then
            editions = editions + 1
            t.owned = t.owned + 1
            if not seen[e.card] then seen[e.card] = true; cards = cards + 1 end
        end
    end
    local total, totalCards, all = #TcgCatalogue, 0, {}
    for _, e in ipairs(TcgCatalogue) do if not all[e.card] then all[e.card] = true; totalCards = totalCards + 1 end end
    return { editions = editions, totalEditions = total, cards = cards, totalCards = totalCards, tiers = perTier }
end

return R
