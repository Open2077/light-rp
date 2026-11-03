-- Recurring costs that keep eddies worth something (rules: server/config/economy.lua,
-- rationale: docs/economy-balance.md). Nothing here ever pushes a balance below
-- zero, charges inside a mission or an activity, or charges during the first day.
--
--   LightRP.sinks.collect(playerId, amount, kind, note, counterparty, partial)
--       -> paid, fromBank, fromCash. Bank first, then cash. `partial` takes what
--          is there; otherwise nothing is taken unless the whole amount is.
--   LightRP.sinks.hospitalBill(playerId)   -> bill (0 = free), reason when free
--   LightRP.sinks.chargeHospital(playerId) -> paid (medical.lua, after "Give up")
--   LightRP.sinks.fittingFee(playerId)     -> fee (0 = free), reason when free
--   LightRP.sinks.chargeFitting(playerId)  -> paid (wardrobe.lua, a saved look in a public room)
--   LightRP.sinks.fittingPrice()           -> the configured fee, for prompts
local E = LightRpEconomy or {}
local Sinks = LightRP.module("sinks", {})

local function amountOf(value) return math.max(0, math.floor(tonumber(value) or 0)) end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$ " .. tostring(n)) end

-- Minutes this character has played, the current session included.
local function playMinutes(playerId)
    local c = LightRP.characters and LightRP.characters.get(playerId)
    if not c then return nil end
    local now = LightRP.nowMs()
    return ((c.playtimeMs or 0) + math.max(0, now - (c.joinedAtMs or now))) / 60000
end

-- Why this player is not charged right now, or nil.
local function exempt(playerId, graceMinutes, death)
    local c = LightRP.characters and LightRP.characters.get(playerId)
    if not c or c.status ~= "active" then return "no_character" end
    if LightRP.tutorial and LightRP.tutorial.isActive and LightRP.tutorial.isActive(playerId) then return "first_day" end
    if LightRP.activities and LightRP.activities.owns and LightRP.activities.owns(playerId) then return "activity" end
    if death and LightRP.missions and LightRP.missions.handlesDeath and LightRP.missions.handlesDeath(playerId) then return "mission" end
    local played = playMinutes(playerId)
    if played and played < (tonumber(graceMinutes) or 0) then return "grace" end
    if not (LightRP.money and LightRP.money.get(playerId)) then return "no_wallet" end
    return nil
end
Sinks.exempt = exempt

function Sinks.collect(playerId, amount, kind, note, counterparty, partial)
    amount = amountOf(amount)
    local w = LightRP.money and LightRP.money.get(playerId)
    if amount == 0 or not w then return 0, 0, 0 end
    local bank, cash = math.max(0, w.bank or 0), math.max(0, w.cash or 0)
    if not partial and bank + cash < amount then return 0, 0, 0 end
    local fromBank = math.min(amount, bank)
    local fromCash = math.min(amount - fromBank, cash)
    local paidBank, paidCash = 0, 0
    if fromBank > 0 and LightRP.money.removeBank(playerId, fromBank, kind, note, counterparty) then paidBank = fromBank end
    if fromCash > 0 and LightRP.money.removeCash(playerId, fromCash, kind, note, counterparty) then paidCash = fromCash end
    return paidBank + paidCash, paidBank, paidCash
end

local function how(fromBank, fromCash)
    if fromBank > 0 and fromCash > 0 then return string.format("%s from the bank, %s in cash", money(fromBank), money(fromCash)) end
    return fromCash > 0 and "in cash" or "from the bank"
end

-- ---------------------------------------------------------------------------
-- Hospital

function Sinks.hospitalBill(playerId)
    local H = E.hospital or {}
    local bill = amountOf(H.bill)
    if bill == 0 then return 0, "free" end
    local why = exempt(playerId, H.graceMinutes, true)
    if why then return 0, why end
    return bill
end

function Sinks.chargeHospital(playerId)
    local H = E.hospital or {}
    local bill, why = Sinks.hospitalBill(playerId)
    if bill == 0 then
        if why == "grace" then
            LightRP.notice(playerId, { kind = "info", title = "Hospital", durationMs = 10000,
                body = "You wake up at the hospital. Newcomers are treated on the city: no bill this time." })
        end
        return 0, why
    end
    local paid, fromBank, fromCash = Sinks.collect(playerId, bill, "hospital", "Hospital care", H.counterparty or "Night City Medical", true)
    local body
    if paid == bill then
        body = string.format("You wake up at the hospital. Bill: %s, paid %s.", money(bill), how(fromBank, fromCash))
    elseif paid > 0 then
        body = string.format("You wake up at the hospital. Bill: %s. You covered %s, the rest is written off.", money(bill), money(paid))
    else
        body = string.format("You wake up at the hospital. Bill: %s, written off: you had nothing to pay with.", money(bill))
    end
    LightRP.notice(playerId, { kind = "money", title = "Hospital", durationMs = 10000, body = body })
    LightRP.log("sinks: hospital bill %d for %s, paid %d (bank %d, cash %d)", bill, tostring(playerId), paid, fromBank, fromCash)
    return paid
end

-- ---------------------------------------------------------------------------
-- Fitting rooms

function Sinks.fittingPrice() return amountOf((E.fitting or {}).fee) end

function Sinks.fittingFee(playerId)
    local F = E.fitting or {}
    local fee = amountOf(F.fee)
    if fee == 0 then return 0, "free" end
    local why = exempt(playerId, F.graceMinutes, false)
    if why then return 0, why end
    return fee
end

function Sinks.chargeFitting(playerId)
    local F = E.fitting or {}
    local fee, why = Sinks.fittingFee(playerId)
    if fee == 0 then return 0, why end
    local paid, fromBank, fromCash = Sinks.collect(playerId, fee, "fitting", "Fitting room", F.counterparty or "Fitting room", false)
    if paid == 0 then
        LightRP.notice(playerId, { kind = "info", title = "Fitting room", durationMs = 6000, body = "On the house this time: you could not cover the fee." })
        return 0, "insufficient_funds"
    end
    LightRP.notice(playerId, { kind = "money", title = "Fitting room", durationMs = 6000,
        body = string.format("New look saved. %s paid %s.", money(paid), how(fromBank, fromCash)) })
    return paid
end

LightRP.log("sinks ready: hospital bill %s, fitting room %s (first %d / %d min of play free)",
    money(amountOf((E.hospital or {}).bill)), money(Sinks.fittingPrice()),
    amountOf((E.hospital or {}).graceMinutes), amountOf((E.fitting or {}).graceMinutes))
