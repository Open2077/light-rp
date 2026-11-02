-- Template-backed NPC shops. The browser sends only item IDs and quantities;
-- this module owns prices, eligibility, sessions and replay protection.
local Config, Items, E = LightRpShops, LightRpItems, LightRpEvents
local Shops = LightRP.module("shops", {})
local templates, locations, sessions = {}, {}, {}
local sequence = 0
local snapshot, sendUpdate
local function integer(n, low, high)
    return type(n) == "number" and math.tointeger(n) ~= nil and n >= low and n <= high
end
local function text(s, max) return type(s) == "string" and #s > 0 and #s <= max end
local function identity(playerId)
    local c = LightRP.characters.get(playerId)
    return c and c.status == "active" and c.identifier and (c.identifier .. "#" .. c.key) or nil
end
local function guard(playerId, spot)
    if not Config.enabled then return false, "disabled" end
    if not spot then return false, "unknown_shop" end
    if not identity(playerId) then return false, "no_character" end
    if LightRP.characters.switching and LightRP.characters.switching[playerId] then return false, "busy" end
    -- With persistence disabled no wallet can load. Report that prerequisite,
    -- rather than asking an already active character to wait indefinitely.
    if not LightRP.db.ready then return false, "database_unavailable" end
    local life, position = Open77.players.getLifeState(playerId), Open77.players.position(playerId)
    if not life or life.phase ~= "alive" then return false, "not_alive" end
    if not position or (position.bucket or 0) ~= (spot.bucket or 0) then return false, "too_far" end
    if not LightRP.nearInteraction(playerId, { position = spot.position, radius = Config.range }, 0.5) then return false, "too_far" end
    if not LightRP.inventory.player(playerId) or not LightRP.money.get(playerId) then return false, "no_character" end
    return true
end

local REASONS = {
    disabled = "The shops are closed.", unknown_shop = "This shop is unavailable.",
    no_character = "Finish loading your character before shopping.", not_alive = "You cannot shop right now.",
    too_far = "You left the shop. Walk back to the vendor.",
    expired = "This shopping session expired. Speak to the vendor again.",
    invalid_cart = "The basket is invalid or exceeds the shop limits.",
    invalid_payment = "This shop does not accept that payment method.",
    unavailable_item = "This item is not offered in this shop for that transaction.",
    stale_catalogue = "The catalogue changed. Review the new prices before confirming again.",
    invalid_request = "This request is out of date. Reopen the shop before trying again.",
    insufficient_funds = "You do not have enough money in that account.",
    too_heavy = "Your bag would be too heavy. Remove some items from the basket.",
    no_room = "Not enough inventory slots for this entire basket.",
    not_enough = "You no longer have enough of these items to sell.",
    busy = "Another operation is still running. Please wait.",
    database_unavailable = "The shop cannot reach the database. Trading is unavailable.",
    database_error = "The checkout could not be saved. Check your balance before retrying.",
    transaction_unavailable = "Secure checkout is unavailable. Contact the server owner.",
    firearm_refused = "The firearm could not be registered to you. Nothing was charged.",
}
local function explain(reason) return REASONS[reason] or ("Checkout refused: " .. tostring(reason)) end

function Shops.setTemplate(id, definition)
    if not text(id, 48) or not id:match("^[%w_-]+$") or type(definition) ~= "table" then return false, "invalid_template" end
    if not text(definition.label, 64) or (definition.subtitle and not text(definition.subtitle, 180)) then return false, "invalid_label" end
    if type(definition.items) ~= "table" or #definition.items > 100 then return false, "invalid_items" end
    local nextTemplate = { label = definition.label, subtitle = definition.subtitle, items = {}, byName = {}, payments = {},
        revision = (templates[id] and templates[id].revision or 0) + 1 }
    for _, payment in ipairs(definition.payments or { "cash" }) do
        if (payment ~= "cash" and payment ~= "bank") or nextTemplate.payments[payment] then return false, "invalid_payment" end
        nextTemplate.payments[payment] = true
        nextTemplate.payments[#nextTemplate.payments + 1] = payment
    end
    if #nextTemplate.payments == 0 then return false, "invalid_payment" end
    for _, item in ipairs(definition.items) do
        if type(item) ~= "table" or not Items[item.name] or nextTemplate.byName[item.name] then return false, "invalid_item" end
        if item.buy == nil and item.sell == nil then return false, "missing_price" end
        for _, price in ipairs({ "buy", "sell" }) do
            if item[price] ~= nil and not integer(item[price], 1, LightRpConfig.economy.maxTransaction) then return false, "invalid_price" end
        end
        if item.buy and item.sell and item.sell > item.buy then return false, "resale_above_purchase" end
        local entry = { name = item.name, buy = item.buy, sell = item.sell }
        nextTemplate.items[#nextTemplate.items + 1], nextTemplate.byName[item.name] = entry, entry
    end
    templates[id] = nextTemplate
    for playerId, session in pairs(sessions) do
        if session.spot.template == id and not session.busy then
            sendUpdate(playerId, { session = session.id, text = explain("stale_catalogue"), catalogueChanged = true, state = snapshot(playerId, session) })
        end
    end
    return true
end

function snapshot(playerId, session)
    local t, inv, w = templates[session.spot.template], LightRP.inventory.player(playerId), LightRP.money.get(playerId)
    if not t or not inv or not w then return nil end
    session.inventoryRevision, session.cash, session.bank = inv.revision or 0, w.cash, w.bank
    local offers = {}
    for _, offer in ipairs(t.items) do
        local item = Items[offer.name]
        offers[#offers + 1] = { name = offer.name, label = item.label, description = item.description, image = item.image,
            icon = item.icon, category = item.category or "misc", weight = item.weight, stack = item.stack,
            buy = offer.buy, sell = offer.sell, owned = LightRP.inventory.plainCount(inv, offer.name),
            effects = item.use and { food = item.use.food, drink = item.use.drink, health = item.use.health } or nil }
    end
    return { kind = "shop", session = session.id, revision = t.revision, nextRequest = session.nextRequest,
        shop = { id = session.spot.id, name = session.spot.name, label = t.label, subtitle = t.subtitle, template = session.spot.template },
        items = offers, payments = { table.unpack(t.payments) }, maxLines = Config.maxLines, maxPerItem = Config.maxPerItem,
        inventory = LightRP.inventory.snapshot(inv), money = { currency = LightRpConfig.economy.currency, cash = w.cash, bank = w.bank } }
end
function sendUpdate(playerId, payload) TriggerClientEvent(E.net.shop, playerId, payload) end
local function close(playerId, reason)
    local s = sessions[playerId]
    if not s then return end
    sessions[playerId] = nil
    sendUpdate(playerId, { session = s.id, closed = true, text = reason and explain(reason) or nil })
end

function Shops.open(playerId, id)
    local spot = locations[id]
    local ok, reason = guard(playerId, spot)
    if not ok then return false, reason end
    if sessions[playerId] and sessions[playerId].busy then return false, "busy" end
    sequence = sequence + 1
    local s = { id = tostring(sequence) .. ":" .. tostring(LightRP.nowMs()), spot = spot, identity = identity(playerId),
        nextRequest = 1, expires = LightRP.nowMs() + Config.sessionMs }
    sessions[playerId] = s
    LightRP.inventory.close(playerId)
    LightRP.dialog(playerId, "shop", snapshot(playerId, s))
    return true
end

local function validateCart(t, payload)
    if payload.mode ~= "buy" and payload.mode ~= "sell" then return nil, "invalid_cart" end
    if not t.payments[payload.pay] then return nil, "invalid_payment" end
    if type(payload.lines) ~= "table" then return nil, "invalid_cart" end
    local count = 0
    for k in pairs(payload.lines) do
        count = count + 1
        if not integer(k, 1, Config.maxLines) or count > Config.maxLines then return nil, "invalid_cart" end
    end
    if count == 0 or count ~= #payload.lines then return nil, "invalid_cart" end
    local lines, seen, total = {}, {}, 0
    for _, line in ipairs(payload.lines) do
        if type(line) ~= "table" or type(line.name) ~= "string" or seen[line.name] or not integer(line.count, 1, Config.maxPerItem) then return nil, "invalid_cart" end
        local offer = t.byName[line.name]
        if not offer or not offer[payload.mode] then return nil, "unavailable_item" end
        total = total + offer[payload.mode] * line.count
        if total > LightRpConfig.economy.maxTransaction then return nil, "invalid_cart" end
        seen[line.name] = true
        lines[#lines + 1] = { name = line.name, count = line.count }
    end
    return lines, total
end

function Shops.checkout(playerId, payload)
    local s = sessions[playerId]
    if not s or payload.session ~= s.id then
        sendUpdate(playerId, { session = payload.session, request = payload.request, ok = false, closed = true, text = explain("expired") })
        return false, "expired"
    end
    -- Repeat of an acknowledged request returns its receipt, never another trade.
    if s.receipt and payload.request == s.receipt.request then sendUpdate(playerId, s.receipt); return s.receipt.ok end
    if s.busy then return false, "busy" end -- original request is still settling
    local ok, reason = guard(playerId, s.spot)
    if not ok or s.identity ~= identity(playerId) or LightRP.nowMs() > s.expires then
        close(playerId, reason or "expired"); return false, reason or "expired"
    end
    if not integer(payload.request, 1, 1000000) or payload.request ~= s.nextRequest then
        close(playerId, "invalid_request"); return false, "invalid_request"
    end
    local t = templates[s.spot.template]
    local lines, total
    if payload.revision ~= t.revision then reason = "stale_catalogue"
    else lines, total = validateCart(t, payload); if not lines then reason = total end end
    s.busy = true
    ok = false
    if lines then
        local called, accepted, why = pcall(LightRP.inventory.trade, playerId, payload.mode, lines, payload.pay, total, s.spot.name)
        ok, reason = called and accepted == true, called and why or "database_error"
    end
    s.nextRequest, s.expires, s.busy = s.nextRequest + 1, LightRP.nowMs() + Config.sessionMs, false
    local message = ok and ((payload.mode == "buy" and "Purchase complete. " or "Sale complete. ") .. LightRP.money.format(total)
        .. (payload.mode == "buy" and " paid from " or " received in ") .. payload.pay .. ".") or explain(reason)
    s.receipt = { session = s.id, request = payload.request, ok = ok, text = message }
    if sessions[playerId] == s then
        s.receipt.state = snapshot(playerId, s)
        sendUpdate(playerId, s.receipt)
    end
    if ok then
        LightRP.log("shop %s: %s %s via %s for %s", s.spot.id, s.identity, payload.mode, payload.pay, total)
        LightRP.eachModule("onShopCheckout", playerId, payload.mode, s.spot.id, total)
    end
    return ok, reason
end

function Shops.onInteract(playerId, id)
    local key = type(id) == "string" and id:match("^shop%.(.+)$")
    if key then
        local ok, reason = Shops.open(playerId, key)
        if not ok then LightRP.result(playerId, false, explain(reason), "shop.open") end
    end
end
function Shops.isBusy(playerId) return sessions[playerId] and sessions[playerId].busy == true end
function Shops.onDisconnected(playerId) sessions[playerId] = nil end
function Shops.onCharacterLoaded(playerId) close(playerId, "expired") end
function Shops.onLifeState(playerId, phase) if phase ~= "alive" then close(playerId, "not_alive") end end

LightRP.action("shop.checkout", function(playerId, payload) Shops.checkout(playerId, payload) end)
LightRP.action("shop.close", function(playerId, payload)
    local s = sessions[playerId]
    if s and s.id == payload.session and not s.busy then sessions[playerId] = nil end
end)

CreateThread(function()
    if not Config.enabled then return end
    for id, def in pairs(Config.templates) do
        local ok, reason = Shops.setTemplate(id, def)
        if not ok then LightRP.log("shop template %s rejected: %s", id, reason) end
    end
    Wait(600)
    for _, spot in ipairs(Config.locations) do
        if templates[spot.template] and not locations[spot.id] then
            local npc = Open77.npcs
            if type(npc) ~= "table" or type(npc.create) ~= "function" then
                LightRP.log("shops CLOSED: NPC API unavailable")
                return
            end
            local def = { record = spot.npc.record, position = spot.position, yaw = spot.yaw or 0, bucket = spot.bucket or 0,
                persistent = false, despawnWhenUnobserved = false, streamingRadius = 150,
                behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
                damagePolicy = npc.damage and (npc.damage.invulnerable or npc.damage.immortal), aiMode = npc.ai and npc.ai.tasks }
            local called, npcId, reason = pcall(npc.create, def)
            if called and npcId then
                pcall(npc.setAIEnabled, npcId, false)
                spot.npcId = npcId
                locations[spot.id] = spot
                LightRP.interaction("shop." .. spot.id, { position = spot.position, radius = Config.range, bucket = spot.bucket or 0,
                    label = spot.name, prompt = "Browse shop", key = "E", promptHeight = 1.1, ring = false,
                    blip = spot.blip and { icon = spot.blip.icon, color = spot.blip.color, size = spot.blip.size,
                        sprite = spot.blip.sprite, title = spot.name, description = spot.blip.description } })
                LightRP.log("shop %s: NPC %s linked to template %s", spot.id, npcId, spot.template)
            else LightRP.log("shop %s CLOSED: vendor spawn failed (%s)", spot.id, tostring(reason or npcId)) end
        else LightRP.log("shop %s CLOSED: duplicate location or unknown template %s", spot.id, spot.template) end
    end
end)
CreateThread(function()
    while true do
        Wait(1000)
        for playerId, s in pairs(sessions) do
            if not s.busy then
                local ok, reason = guard(playerId, s.spot)
                if not ok or identity(playerId) ~= s.identity or LightRP.nowMs() > s.expires then close(playerId, reason or "expired")
                else
                    local inv, w = LightRP.inventory.player(playerId), LightRP.money.get(playerId)
                    if not inv.busy and not w.busy and ((inv.revision or 0) ~= s.inventoryRevision or w.cash ~= s.cash or w.bank ~= s.bank) then
                        sendUpdate(playerId, { session = s.id, refresh = true, state = snapshot(playerId, s) })
                    end
                end
            end
        end
    end
end)
AddEventHandler("onNpcRemoved", function(id)
    for key, spot in pairs(locations) do
        if spot.npcId == tonumber(id) then
            locations[key] = nil; LightRP.removeInteraction("shop." .. key)
            for playerId, s in pairs(sessions) do if s.spot == spot then close(playerId, "unknown_shop") end end
        end
    end
end)
