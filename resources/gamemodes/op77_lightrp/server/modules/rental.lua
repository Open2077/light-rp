local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- Vehicle rental. Rental desks are NPCs placed around the city, each with its
-- own stock and prices. A player walks up (proximity interaction, E), picks a
-- vehicle and a way to pay, and the car is delivered on the desk's parking spot
-- for `rentals.durationMinutes`. One rental at a time per player; it is returned
-- at any desk, taken back when the time runs out, and cleaned up on disconnect.
local Config = LightRpConfig.rentals
local Db = LightRP.db
local Rental = LightRP.module("rental", {})

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_rentals (
        id             BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
        identifier     VARCHAR(64)  NOT NULL,
        character_key  VARCHAR(64)  NOT NULL,
        spot_id        VARCHAR(48)  NOT NULL,
        vehicle_key    VARCHAR(48)  NOT NULL,
        price          BIGINT       NOT NULL,
        paid_with      VARCHAR(8)   NOT NULL,
        started_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ended_at       TIMESTAMP    NULL,
        end_reason     VARCHAR(24)  NULL
    )
]])

local spots = {}      -- id -> spot (config entry + npcId)
local rentals = {}    -- playerId -> { spotId, key, label, record, vehicleId, startedAt, expiresAt, price, paidWith, rowId }
Rental.byPlayer = rentals

local function interactionId(spot) return "rental." .. spot.id end

-- ---------------------------------------------------------------------------
-- Desks: one NPC per spot, one interaction point at its feet.

local function spawnDesk(spot)
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.create) ~= "function" then
        LightRP.log("rental desk %s: NPC API unavailable, the desk is invisible but still works", spot.id)
        return nil
    end
    -- A random face from the crowd pool, then the rest of the pool as fallbacks.
    local pool = spot.npc and spot.npc.candidates or Config.npcPool or {}
    local candidates = {}
    for i, candidate in ipairs(pool) do candidates[i] = candidate end
    for i = #candidates, 2, -1 do local j = math.random(i); candidates[i], candidates[j] = candidates[j], candidates[i] end
    for _, candidate in ipairs(candidates) do
        local definition = {
            position = { x = spot.position.x, y = spot.position.y, z = spot.position.z },
            yaw = tonumber(spot.heading) or 0.0,
            bucket = 0,
            persistent = false,
            despawnWhenUnobserved = false,
            streamingRadius = 150.0,
            -- A desk clerk: no threats, no stimuli, no barks.
            behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
        }
        if candidate.record then definition.record = candidate.record else definition.template = candidate.template end
        if type(Open77.npcs.damage) == "table" then definition.damagePolicy = Open77.npcs.damage.invulnerable or Open77.npcs.damage.immortal end
        if type(Open77.npcs.ai) == "table" then definition.aiMode = Open77.npcs.ai.tasks end
        local ok, npcId, reason = pcall(Open77.npcs.create, definition)
        if ok and npcId then
            -- The native agent is what makes a civilian wander or flee: stop it.
            -- Rendering and collision stay; the body stands where it was put.
            local stillOk, stillErr = pcall(Open77.npcs.setAIEnabled, npcId, false)
            if not stillOk or stillErr == false then LightRP.log("rental desk %s: setAIEnabled refused: %s", spot.id, tostring(stillErr)) end
            LightRP.log("rental desk %s: NPC %s spawned as %s (AI off)", spot.id, tostring(npcId), candidate.record or candidate.template)
            return npcId
        end
        LightRP.log("rental desk %s: %s refused (%s), trying the next candidate", spot.id, candidate.record or candidate.template, tostring(ok and npcId == nil and reason or npcId))
    end
    LightRP.log("rental desk %s: no NPC candidate accepted; the desk is invisible but still works", spot.id)
    return nil
end

local function stockOf(spot)
    local list = {}
    for _, item in ipairs(spot.stock or {}) do
        local entry = LightRP.vehicles.byKey[string.lower(item.key)]
        if entry then
            list[#list + 1] = { key = entry.key, label = entry.label, category = entry.category, image = item.image or entry.image,
                price = math.max(0, math.floor(tonumber(item.price) or 0)) }
        else
            LightRP.log("rental desk %s: unknown vehicle key %s in stock", spot.id, tostring(item.key))
        end
    end
    return list
end

CreateThread(function()
    if not Config.enabled then return end
    Wait(500) -- let the platform finish its own start-up before the world gets NPCs
    for _, entry in ipairs(Config.spots or {}) do
        local spot = {}
        for k, v in pairs(entry) do spot[k] = v end
        spot.items = stockOf(spot)
        spot.npcId = spawnDesk(spot)
        spots[spot.id] = spot
        LightRP.interaction(interactionId(spot), {
            position = spot.position, radius = Config.interactRadius or 2.0,
            label = spot.name, prompt = "Rent a vehicle", key = Config.key or "E", promptHeight = 1.1,
            marker = Config.marker, ring = false,
            blip = Config.blip and { icon = Config.blip.icon, color = Config.blip.color, size = Config.blip.size,
                sprite = Config.blip.sprite, title = Config.blip.title or "Rent-a-Ride",
                description = (spot.name or "Rent-a-Ride") .. "\n" .. (Config.blip.description or "") } or nil,
        })
    end
    LightRP.log("rental: %d desk(s) open, %d min per rental", #(Config.spots or {}), Config.durationMinutes or 30)
end)

-- ---------------------------------------------------------------------------
-- Rentals

local function remaining(r) return math.max(0, r.expiresAt - LightRP.nowMs()) end

local function extendMinutes() return math.max(1, math.floor(tonumber(Config.extendMinutes) or 30)) end
-- Pro rata of what the rental cost: price × extendMinutes / durationMinutes, rounded up.
local function extendPrice(r)
    local base = math.max(0, math.floor(tonumber(r.price) or 0))
    return math.ceil(base * extendMinutes() / math.max(1, tonumber(Config.durationMinutes) or 60))
end
local function firstWarnMs()
    local most = 0
    for _, minutes in ipairs(Config.warnMinutes or { 10, 2 }) do most = math.max(most, tonumber(minutes) or 0) end
    return most * 60000
end

local function view(playerId)
    local r = rentals[playerId]
    if r == nil then return nil end
    return { spotId = r.spotId, spotName = spots[r.spotId] and spots[r.spotId].name or r.spotId, key = r.key, label = r.label,
        image = r.image, price = r.price, paidWith = r.paidWith, remainingMs = remaining(r), vehicleId = r.vehicleId,
        extendPrice = extendPrice(r), extendMinutes = extendMinutes(), warnMs = firstWarnMs(),
        extensionsLeft = math.max(0, (tonumber(Config.maxExtensions) or 4) - (r.extensions or 0)) }
end

LightRP.stateProvider("rental", function(playerId) return { active = view(playerId) } end)

local function dialogPayload(playerId, spot)
    return { spot = { id = spot.id, name = spot.name, stock = spot.items, durationMinutes = Config.durationMinutes or 60 }, rental = view(playerId) }
end

local function endRental(playerId, reason)
    local r = rentals[playerId]
    if r == nil then return false, "no_rental" end
    rentals[playerId] = nil
    if r.vehicleId ~= nil then pcall(Open77.vehicles.remove, r.vehicleId) end
    if Db.ready and r.rowId then
        Db.run("UPDATE lightrp_rentals SET ended_at = CURRENT_TIMESTAMP, end_reason = ? WHERE id = ?", { reason, r.rowId })
    end
    if GetPlayerName(playerId) ~= nil then LightRP.state(playerId, "rental") end
    return true, r
end

function Rental.get(playerId) return rentals[playerId] end

function Rental.rent(playerId, spotId, key, pay)
    if not Config.enabled then return false, "disabled" end
    if LightRP.activities and not LightRP.activities.allows(playerId, "vehicles") then return false, "activity" end
    local spot = spots[tostring(spotId or "")]
    if spot == nil then return false, "unknown_desk" end
    if rentals[playerId] then return false, "already_renting" end
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return false, "no_character" end
    if LightRP.money.get(playerId) == nil then return false, "no_wallet" end
    if not LightRP.nearInteraction(playerId, { position = spot.position, radius = (Config.interactRadius or 2.5) }, 4.0) then return false, "too_far" end
    local item
    for _, entry in ipairs(spot.items) do if entry.key == string.lower(tostring(key or "")) then item = entry end end
    if item == nil then return false, "not_in_stock" end
    pay = pay == "bank" and "bank" or "cash"
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return false, "not_alive" end

    -- Pay first, deliver second, refund on failure: the wallet never floats.
    local charge = pay == "bank" and LightRP.money.removeBank or LightRP.money.removeCash
    local refund = pay == "bank" and LightRP.money.addBank or LightRP.money.addCash
    if item.price > 0 then
        local paid, reason = charge(playerId, item.price, "rental", "Rental: " .. item.label, spot.name)
        if not paid then return false, reason end
    end
    local parking = spot.parking or { position = spot.position, heading = spot.heading }
    local position = Open77.players.position(playerId)
    local vehicleId, reason = Open77.vehicles.create({
        record = LightRP.vehicles.byKey[item.key].record,
        position = { x = parking.position.x, y = parking.position.y, z = parking.position.z },
        yaw = tonumber(parking.heading) or 0,
        bucket = position and position.bucket or 0,
    })
    if vehicleId == nil then
        if item.price > 0 then refund(playerId, item.price, "refund", "Rental refused: " .. tostring(reason), spot.name) end
        return false, "vehicle_refused"
    end
    -- Keys authorise the renter to unlock; the car starts locked for everyone.
    if LightRP.fuel then LightRP.fuel.seed(vehicleId, "rental") end -- a rental never comes with a full tank
    LightRP.keys.give(vehicleId, playerId, { label = item.label, owner = true })
    LightRP.keys.lock(vehicleId, true, playerId)
    local now = LightRP.nowMs()
    local r = { spotId = spot.id, key = item.key, label = item.label, image = item.image, vehicleId = vehicleId, startedAt = now,
        expiresAt = now + (Config.durationMinutes or 60) * 60000, price = item.price, paidWith = pay, extensions = 0, warned = {} }
    rentals[playerId] = r
    if Db.ready and c.identifier then
        local ok, result = Db.run("INSERT INTO lightrp_rentals (identifier, character_key, spot_id, vehicle_key, price, paid_with) VALUES (?, ?, ?, ?, ?, ?)",
            { c.identifier, c.key, spot.id, item.key, item.price, pay })
        local row = ok and Db.single("SELECT MAX(id) AS id FROM lightrp_rentals WHERE identifier = ? AND character_key = ?", { c.identifier, c.key })
        r.rowId = row and tonumber(row.id) or nil
    end
    LightRP.state(playerId, "rental")
    LightRP.notice(playerId, { kind = "success", title = spot.name, durationMs = 10000,
        body = string.format("%s is parked outside for %d minutes. You have the keys: press L to unlock it. Type /extendrental to keep it longer; bring it back to any desk when you are done.",
            item.label, Config.durationMinutes or 60) })
    LightRP.log("rental: %s rented %s at %s for %s (%s)", LightRP.characters.displayName(playerId), item.key, spot.id, LightRP.money.format(item.price), pay)
    return true, r
end

-- More time on the rental in progress, paid pro rata (bank unless `cash`); anywhere, by the
-- command or the desk's Extend button.
function Rental.extend(playerId, pay)
    local r = rentals[playerId]
    if r == nil then return false, "no_rental" end
    if (r.extensions or 0) >= (tonumber(Config.maxExtensions) or 4) then return false, "max_extensions" end
    if LightRP.money.get(playerId) == nil then return false, "no_wallet" end
    pay = pay == "cash" and "cash" or "bank"
    local price = extendPrice(r)
    local desk = spots[r.spotId] and spots[r.spotId].name or "Rent-a-Ride"
    if price > 0 then
        local charge = pay == "bank" and LightRP.money.removeBank or LightRP.money.removeCash
        local paid, reason = charge(playerId, price, "rental", "Rental extension: " .. r.label, desk)
        if not paid then return false, reason end
        if rentals[playerId] ~= r then -- taken back while the payment was written
            local refund = pay == "bank" and LightRP.money.addBank or LightRP.money.addCash
            refund(playerId, price, "refund", "Rental extension refunded: " .. r.label, desk)
            return false, "no_rental"
        end
    end
    local minutes = extendMinutes()
    r.expiresAt = math.max(r.expiresAt, LightRP.nowMs()) + minutes * 60000
    r.extensions = (r.extensions or 0) + 1
    r.warned = {}
    LightRP.state(playerId, "rental")
    LightRP.notice(playerId, { kind = "success", title = "Rental extended", durationMs = 8000,
        body = string.format("%s: %d more minutes for %s. %d min left in total.", r.label, minutes, LightRP.money.format(price),
            math.ceil(remaining(r) / 60000)) })
    LightRP.log("rental: %s extended %s by %d min for %s (%s)", LightRP.characters.displayName(playerId), r.key, minutes, LightRP.money.format(price), pay)
    return true, { label = r.label, price = price, minutes = minutes }
end

function Rental.giveBack(playerId)
    local ok, r = endRental(playerId, "returned")
    if not ok then return false, r end
    LightRP.notice(playerId, { kind = "info", title = "Vehicle returned", body = r.label .. " is back in the lot. Thanks for renting with us.", durationMs = 8000 })
    return true, r
end

-- ---------------------------------------------------------------------------
-- Hooks, actions

function Rental.onInteract(playerId, id)
    for _, spot in pairs(spots) do
        if interactionId(spot) == id then
            LightRP.dialog(playerId, "rental", dialogPayload(playerId, spot))
            return
        end
    end
end

function Rental.onDisconnected(playerId) endRental(playerId, "disconnect") end
function Rental.onCharacterSwitched(playerId) endRental(playerId, "switch") end

CreateThread(function()
    lightrpEvery(10000, function()
        
        local now = LightRP.nowMs()
        for playerId, r in pairs(rentals) do
            if now >= r.expiresAt then
                local _, ended = endRental(playerId, "expired")
                if ended and GetPlayerName(playerId) then
                    LightRP.notice(playerId, { kind = "warning", title = "Rental over", body = ended.label .. " was taken back by the agency.", durationMs = 10000 })
                end
            else
                -- The countdown notices (the HUD chip blinks from the first): how to keep the car.
                r.warned = r.warned or {}
                for _, minutes in ipairs(Config.warnMinutes or { 10, 2 }) do
                    minutes = tonumber(minutes) or 0
                    if minutes > 0 and r.expiresAt - now <= minutes * 60000 and not r.warned[minutes] then
                        r.warned[minutes] = true
                        if GetPlayerName(playerId) then
                            local canExtend = (r.extensions or 0) < (tonumber(Config.maxExtensions) or 4)
                            LightRP.notice(playerId, { kind = "warning", title = "Rental ending", durationMs = 12000,
                                body = canExtend and string.format("%s goes back to the agency in %d min. Type /extendrental to add %d min for %s (bank; /extendrental cash to pay cash), or use Extend at any Rent-a-Ride desk.",
                                    r.label, math.ceil((r.expiresAt - now) / 60000), extendMinutes(), LightRP.money.format(extendPrice(r)))
                                    or string.format("%s goes back to the agency in %d min. It cannot be extended again.", r.label, math.ceil((r.expiresAt - now) / 60000)) })
                            LightRP.state(playerId, "rental")
                        end
                    end
                end
            end
        end
    end, "rental:219")
end)

local REASONS = {
    unknown_desk = "That rental desk does not exist.", already_renting = "You already have a vehicle out. Return it first.",
    no_character = "Finish your character first.", no_wallet = "You have no wallet yet.", too_far = "Walk up to the desk.",
    not_in_stock = "This desk does not rent that model.", not_alive = "Not right now.", vehicle_refused = "The lot could not deliver the vehicle; you were refunded.",
    no_rental = "You have no rental to return.", disabled = "Rentals are closed.",
    insufficient_funds = "Insufficient funds.", busy = "Another operation is still running, try again.",
    activity = "No rentals during an activity.",
    max_extensions = "This rental cannot be extended any further. Return it and rent again.",
}
local function explain(reason) return REASONS[reason] or LightRP.money.explain(reason) end

LightRP.action("rental.rent", function(playerId, payload)
    local ok, result = Rental.rent(playerId, payload.spot, payload.key, payload.pay)
    LightRP.result(playerId, ok, ok and string.format("%s rented for %s.", result.label, LightRP.money.format(result.price)) or explain(result), "rental.rent")
end)

LightRP.action("rental.extend", function(playerId, payload)
    local ok, result = Rental.extend(playerId, payload.pay)
    LightRP.result(playerId, ok, ok and string.format("%s extended by %d min for %s.", result.label, result.minutes, LightRP.money.format(result.price)) or explain(result), "rental.extend")
end)

LightRP.command("extendrental", { usage = "/extendrental [bank|cash]" }, function(source, args)
    local ok, result = Rental.extend(tonumber(source) or source, args and args[1] and string.lower(tostring(args[1])) or "bank")
    if ok then return true, string.format("%s extended by %d min for %s.", result.label, result.minutes, LightRP.money.format(result.price)) end
    return false, explain(result)
end)

LightRP.action("rental.return", function(playerId)
    local ok, result = Rental.giveBack(playerId)
    LightRP.result(playerId, ok, ok and (result.label .. " returned.") or explain(result), "rental.return")
end)

LightRP.command("lightrp.rentals", { restricted = true }, function()
    local lines, count = {}, 0
    for playerId, r in pairs(rentals) do
        count = count + 1
        lines[#lines + 1] = string.format("%s: %s (%d min left)", LightRP.characters.displayName(playerId), r.label, math.ceil(remaining(r) / 60000))
    end
    return true, count == 0 and "No rental in progress." or table.concat(lines, " · ")
end)
