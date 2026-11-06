-- Temporary kits for the activities: a provider hands a player it owns the same kit a
-- mission would, through the same code (LightRP.kits in missions.lua): assign, ammunition,
-- the armed check, the retries. The contract is in the header of activities.lua.
--
-- While a kit is held the armament stands aside (A.handlesLoadout), the weapon wheel lists
-- it and draws it (A.kitOf / A.drawKit). It touches native slots only: the character's
-- weapons stay in the inventory, nothing is spent or written, and the same way back as
-- every activity projects them again. A kit always ends in the slots being emptied and
-- read back, however the player leaves, before that way back runs; a dead body waits for
-- its return first (a dead body refuses the removal).
local A = LightRP.activities

local BUSY_SPINS = 300      -- x 50 ms: the other sequence's last request answers or times out (10 s)
local SETTLE_MS = 1500      -- the body lands first, as a mission's
local TAKE_TRIES, TAKE_RETRY_MS = 6, 3000   -- a living body, as many tries as a delivery
local DEAD_TRIES, DEAD_RETRY_MS = 120, 1000 -- a body that is not up yet
local ALIVE_WAITS, ALIVE_WAIT_MS = 3, 30000 -- a hand's waits for a body to stand, and how long each
local MAX_RESERVE = 9999

local held = {}  -- playerId -> hand { id, activity, entry, kit, verified, delivering, taking, after }
local busy = {}  -- playerId -> the hand whose thread is sending native requests
local handSeq = 0

local function Kits() return LightRP.kits end
local function pid(value)
    value = tonumber(value)
    if value and value >= 1 and value % 1 == 0 then return math.floor(value) end
    return nil
end
local function alive(id)
    local life = Open77.players.getLifeState(id)
    return life ~= nil and life.phase == "alive"
end
local function pushArmament(id)
    if LightRP.armament and type(LightRP.armament.push) == "function" then pcall(LightRP.armament.push, id) end
end
-- A sequence's request in flight lands before the next one starts: requests to one
-- player run in order, and an assign must never follow the clear that ends a kit.
local function waitTurn(id)
    local spins = 0
    while busy[id] and spins < BUSY_SPINS do Wait(50); spins = spins + 1 end
end

local function record(value)
    return type(value) == "string" and #value <= 160 and value:match("^Items%.[%w_%.]+$") and value or nil
end
-- nil, reason for anything but a kit of the config or a well-formed explicit one.
local function resolve(kit)
    local K = Kits()
    if not K then return nil, "Kits are not available." end
    if kit == nil then
        local first = K.default()
        if first then return first end
        return nil, "No kit is configured."
    end
    if type(kit) == "string" then
        local found = K.byId(kit)
        if found then return found end
        return nil, "That kit does not exist."
    end
    if type(kit) ~= "table" then return nil, "That kit does not exist." end
    local primary, secondary = record(kit.primary), record(kit.secondary)
    if not primary or (kit.secondary ~= nil and not secondary) then return nil, "A kit needs weapon records." end
    if kit.reserve ~= nil and type(kit.reserve) ~= "table" then return nil, "A kit's reserve is one number per weapon." end
    local reserve = {}
    for slot = 1, 2 do
        local rounds = kit.reserve and kit.reserve[slot]
        if rounds ~= nil then
            rounds = tonumber(rounds)
            if not rounds or rounds ~= rounds or rounds < 1 or rounds > MAX_RESERVE or rounds % 1 ~= 0 then
                return nil, "A kit's reserve is one number per weapon."
            end
            reserve[slot] = math.floor(rounds)
        end
    end
    local names = type(kit.names) == "table" and kit.names or {}
    local label = A.clean(kit.label, 48)
    return { id = "explicit", label = label, primary = primary, secondary = secondary, reserve = reserve,
        names = { A.clean(names[1], 48) or label, A.clean(names[2], 48) } }
end

-- The provider's refusals: an unknown activity, another resource's, a player it does not own.
local function ownedEntry(id, activityId)
    if not id then return nil, "Invalid player." end
    local a = type(activityId) == "string" and A.registry[activityId] or nil
    if not a then return nil, "That activity is not available." end
    if A.foreign(a.resource) then return nil, "That activity belongs to another resource." end
    local e = A.owned[id]
    if not e or e.activity ~= activityId then return nil, "That player is not in this activity." end
    return e
end

local function report(id, hand, state)
    local list = {}
    for slot, tweakDbId in pairs(hand.verified) do list[#list + 1] = { slot = slot, tweakDbId = tweakDbId } end
    table.sort(list, function(x, y) return x.slot < y.slot end)
    A.emit(A.events.kit, id, hand.activity, { hand = hand.id, kit = hand.kit.id, state = state, weapons = list })
end

local deliver
local function failed(id, hand)
    LightRP.log("activities: kit %s never reached %d (%s)", hand.kit.id, id, hand.activity)
    report(id, hand, "failed")
end
-- A respawn answers before the body stands, and a death stops a delivery: the hand waits for the
-- `alive` life event (A.onLifeState), the one a mission equips on. Bounded: the wait's end reads
-- the phase once, in case the event went missing, then the provider hears "failed".
local function awaitLife(id, hand)
    hand.waits = (hand.waits or 0) + 1
    if hand.waits > ALIVE_WAITS then return failed(id, hand) end
    local wait = {}
    hand.waiting = wait
    SetTimeout(ALIVE_WAIT_MS, function()
        if hand.waiting ~= wait then return end
        hand.waiting = nil
        if held[id] ~= hand or hand.taking or A.owned[id] ~= hand.entry then return end
        if alive(id) then deliver(id, hand, 0) else failed(id, hand) end
    end)
end

deliver = function(id, hand, settleMs)
    hand.delivering, hand.waiting = true, nil
    CreateThread(function()
        local function mine() return held[id] == hand and not hand.taking end
        Wait(settleMs)
        waitTurn(id)
        if not mine() then hand.delivering = false; return end
        busy[id] = hand
        local done, snapshot = Kits().deliver(id, hand.kit, { tag = "activity " .. hand.activity .. ": kit", settleMs = 0, keep = hand.keep,
            live = function() return mine() and A.owned[id] == hand.entry and alive(id) end,
            stopped = function() return not mine() end,
            assigned = function(slot, result)
                if type(result) == "table" and result.tweakDbId ~= nil then
                    hand.verified[slot] = tostring(result.tweakDbId)
                    report(id, hand, "assigned")
                end
            end })
        if busy[id] == hand then busy[id] = nil end
        hand.delivering = false
        if not mine() then return end
        if done then
            for _, row in ipairs(Kits().slots(snapshot)) do
                local slot = type(row) == "table" and tonumber(row.slot)
                if (slot == 1 or slot == 2) and row.tweakDbId ~= nil and row.record == (slot == 1 and hand.kit.primary or hand.kit.secondary) then
                    hand.verified[slot] = tostring(row.tweakDbId)
                end
            end
            LightRP.log("activities: kit %s handed to %d (%s)", hand.kit.id, id, hand.activity)
            hand.waits, hand.armed = nil, true
            report(id, hand, "armed")
        elseif done == false then
            failed(id, hand)
        elseif A.owned[id] == hand.entry then
            awaitLife(id, hand) -- nil, still its hand and its activity: the body is not up
        end
    end)
end

function A.onLifeState(id, phase)
    local hand = held[id]
    -- a body that went down holds nothing of the kit any more: the next one is handed whole
    if hand and phase ~= "alive" then hand.armed = nil end
    if phase == "alive" and hand and hand.waiting and not hand.taking then deliver(id, hand, SETTLE_MS) end
end

-- Export activityKit. The way out needs no call: the core takes the kit back at every exit.
function A.giveKit(playerId, activityId, kit, opts)
    local id = pid(playerId)
    local e, why = ownedEntry(id, activityId)
    if not e then return false, why end
    local resolved, refused = resolve(kit)
    if not resolved then return false, refused end
    handSeq = handSeq + 1
    local hand = { id = handSeq, activity = activityId, entry = e, kit = resolved, verified = {} }
    -- The same secondary is still in slot 2 from the last kit, armed on this same body (the gun
    -- game's step up: the knife stays): only the primary is swapped, nothing is emptied.
    local before = held[id]
    if before and before.armed and before.entry == e and not before.taking and resolved.secondary
        and before.kit.secondary == resolved.secondary and before.verified[2] and alive(id) then
        hand.keep = { slot = 2, tweakDbId = before.verified[2] }
    end
    held[id] = hand -- the one before stops at its next request
    pushArmament(id)
    -- standing aside: this drops the projection, the way back owes it nothing (armament.lua)
    if LightRP.armament and type(LightRP.armament.synchronize) == "function" then pcall(LightRP.armament.synchronize, id) end
    deliver(id, hand, type(opts) == "table" and opts.immediate == true and 0 or SETTLE_MS)
    return true, hand.id
end

-- Empties the slots and reads them back, then `after`. False: no kit here.
function A.withdrawKit(id, after)
    local hand = held[id]
    if not hand then return false end
    hand.after = hand.after or {}
    if after then hand.after[#hand.after + 1] = after end
    if hand.taking then return true end
    hand.taking = true
    CreateThread(function()
        waitTurn(id)
        busy[id] = hand
        local tries, dead, confirmed = 0, 0, false
        while held[id] == hand do
            local life = Open77.players.getLifeState(id)
            if not life then break end
            if life.phase == "alive" then
                tries = tries + 1
                local K = Kits()
                local cleared, why = K.weapons(id, "clear")
                local snapshot = cleared and K.weapons(id, "requestSnapshot")
                if snapshot and not K.holds(snapshot, hand.kit) then confirmed = true; break end
                LightRP.log("activities: kit of %d still in the slots (attempt %d, %s)", id, tries, tostring(why or "snapshot"))
                if tries >= TAKE_TRIES then break end
                Wait(TAKE_RETRY_MS)
            else
                dead = dead + 1
                if dead >= DEAD_TRIES then break end
                Wait(DEAD_RETRY_MS)
            end
        end
        if busy[id] == hand then busy[id] = nil end
        local replaced = held[id] ~= hand and held[id] ~= nil
        if held[id] == hand then held[id] = nil end
        if not replaced then
            -- the armament's projection replaces whatever is left in the slots
            if not confirmed then LightRP.log("activities: kit of %d not confirmed gone, the way back goes on", id) end
            pushArmament(id)
        end
        for _, fn in ipairs(hand.after) do
            local ok, err = pcall(fn)
            if not ok then LightRP.log("activities: after a kit of %d: %s", id, tostring(err)) end
        end
    end)
    return true
end

-- Export activityKitTake. opts.hand: the hand activityKit answered (a late call for an older
-- kit is refused, the player keeps the new one).
function A.takeKit(playerId, activityId, opts)
    local id = pid(playerId)
    local e, why = ownedEntry(id, activityId)
    if not e then return false, why end
    local hand = held[id]
    if not hand or hand.activity ~= activityId then return false, "That player holds no kit of this activity." end
    local wanted = type(opts) == "table" and opts.hand or nil
    if wanted ~= nil and wanted ~= hand.id then return false, "That kit was replaced." end
    A.withdrawKit(id, function()
        -- an activity that keeps RP weapons gets them back now, the others at the way back
        if e.caps and e.caps.rpWeapons and A.owned[id] == e then A.rearm(id, true) end
    end)
    return true
end

-- The player is gone: the slots went with the client.
function A.forgetKit(id)
    held[id], busy[id] = nil, nil
end

-- Light RP stops: nothing may wait, the request goes out and the VM ends. The next VM's
-- armament replaces what the slots hold when it attaches.
function A.kitsStop()
    for id in pairs(held) do pcall(Open77.weapons.clear, id) end
    held, busy = {}, {}
end

-- Generalises Missions.handlesLoadout / kitOf / drawKit (armament.lua asks both).
function A.handlesLoadout(id) return held[id] ~= nil end
function A.kitOf(id)
    local hand = held[id]
    return hand and not hand.taking and hand.kit or nil
end
function A.drawKit(id, slot)
    local hand = held[id]
    if not hand or hand.taking or (slot ~= 1 and slot ~= 2) then return false, "No kit." end
    if slot == 2 and not hand.kit.secondary then return false, "Nothing in that slot of the kit." end
    return Kits().draw(id, slot, hand.kit, function()
        if held[id] == hand and not hand.taking and not hand.delivering then deliver(id, hand, 0) end
    end)
end

A.exported("activityKit", A.giveKit)
A.exported("activityKitTake", A.takeKit)
