-- Deck building, the official rules (docs/RULES.md §6; Comprehensive Rules 7.3 and 3.20):
--   exactly 3 Legends, all with different names; a main deck of 40-50 non-Legend cards; at most 3 copies of a
--   card (name + subtitle: one catalogue base card); every card's RAM at most its colour's limit, the sum of the
--   Legends' RAM in that colour. op77_tcg adds: a collector builds from the copies they own (any finish counts).
-- A deck is { name, legends = { slug, slug, slug }, cards = { [slug] = n } } (slugs: TcgCards keys).
-- web/app.js mirrors validate() for live feedback; the server's verdict is the one that counts.
TcgDecks = { legends = 3, min = 40, max = 50, copies = 3, maxDecks = 12, nameMax = 32 }
TcgDecks.colors = { "Red", "Green", "Blue", "Yellow" }

function TcgDecks.encode(cards)
    local parts = {}
    for slug, n in pairs(cards or {}) do
        if n > 0 then parts[#parts + 1] = slug .. ":" .. n end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function TcgDecks.parse(text)
    local out = {}
    for slug, n in tostring(text or ""):gmatch("([%w_]+):(%d+)") do out[slug] = (out[slug] or 0) + tonumber(n) end
    return out
end

function TcgDecks.ramLimits(legends)
    local limits = { Red = 0, Green = 0, Blue = 0, Yellow = 0 }
    for _, slug in ipairs(legends or {}) do
        local c = TcgCards[slug]
        if c and c.type == "Legend" and c.color and limits[c.color] and c.ram then
            limits[c.color] = limits[c.color] + c.ram
        end
    end
    return limits
end

local function label(c) return c.subtitle ~= "" and (c.name .. ": " .. c.subtitle) or c.name end
TcgDecks.label = label

-- owned: nil (no ownership check) or function(slug) -> copies the collector owns.
-- Returns ok, errors (sentences), info { count, limits, used = { colour = highest RAM used } }.
function TcgDecks.validate(deck, owned)
    local errors = {}
    local function err(fmt, ...) errors[#errors + 1] = fmt:format(...) end
    local legends = deck.legends or {}
    local names = {}
    if #legends ~= TcgDecks.legends then err("Pick %d Legends (%d/%d).", TcgDecks.legends, #legends, TcgDecks.legends) end
    for _, slug in ipairs(legends) do
        local c = TcgCards[slug]
        if not c then err("Unknown Legend %s.", tostring(slug))
        elseif c.type ~= "Legend" then err("%s is not a Legend.", label(c))
        else
            if names[c.name] then err("Two Legends named %s: Legends need different names.", c.name) end
            names[c.name] = true
            if owned and (owned(slug) or 0) < 1 then err("You don't own %s.", label(c)) end
        end
    end
    local limits = TcgDecks.ramLimits(legends)
    local used = { Red = 0, Green = 0, Blue = 0, Yellow = 0 }
    local count = 0
    for slug, n in pairs(deck.cards or {}) do
        local c = TcgCards[slug]
        if not c then err("Unknown card %s.", tostring(slug))
        elseif n > 0 then
            count = count + n
            if c.type == "Legend" then err("%s is a Legend: Legends go in the three Legend slots.", label(c)) end
            if n > TcgDecks.copies then err("%d copies of %s: at most %d.", n, label(c), TcgDecks.copies) end
            if c.color and used[c.color] then
                used[c.color] = math.max(used[c.color], c.ram or 0)
                if (c.ram or 0) > limits[c.color] then
                    err("%s needs %d %s RAM; your Legends give %d.", label(c), c.ram or 0, c.color, limits[c.color])
                end
            end
            if owned then
                local have = owned(slug) or 0
                if have < n then err("%d copies of %s in the deck, you own %d.", n, label(c), have) end
            end
        end
    end
    if count < TcgDecks.min then err("%d cards in the main deck: at least %d.", count, TcgDecks.min) end
    if count > TcgDecks.max then err("%d cards in the main deck: at most %d.", count, TcgDecks.max) end
    return #errors == 0, errors, { count = count, limits = limits, used = used }
end
