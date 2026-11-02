-- The cyberware module (server/modules/cyberware.lua) against a fake platform and framework:
-- refusals (money, not seated), payment and refund, no limit (any model, family replacement), durable legs/arms transactions, session grants, passives, Mantis Blades,
-- removal and the staff command.
local clock, threads = 0, {}
_G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
_G.Wait = function(ms) clock = clock + (ms or 0); coroutine.yield() end
local function pump(daemons)
    for _ = 1, daemons and 50 or 2000 do
        local alive = false
        for i, co in ipairs(threads) do
            if co and coroutine.status(co) ~= "dead" then
                alive = true
                local ok, err = coroutine.resume(co)
                if not ok then error(err) end
            end
            if co and coroutine.status(co) == "dead" then threads[i] = false end
        end
        if not alive then threads = {} return end
    end
    if daemons then threads = {} return end -- the module's watchdog loops forever: leave it out
    error("threads never finished")
end

local handlers, netHandlers, commands = {}, {}, {}
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.json = { decode = function(s) return load("return " .. s)() end }
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end

-- The platform ------------------------------------------------------------------
local P = { records = {}, defs = {}, grants = { dash = {}, reflex = {}, abilities = {} }, stats = {}, armor = {}, fall = {},
    weaponCalls = {}, failNext = nil, nextTicket = 0, life = "alive" }
local function grantApi(kind)
    return {
        define = function(def) P.defs[def.id] = def; return { ok = true } end,
        grant = function(pid, id) P.grants[kind][pid] = id; return { ok = true } end,
        revoke = function(pid) P.grants[kind][pid] = nil; return { ok = true } end,
        current = function(pid) return P.grants[kind][pid] and { ownedByCaller = true } or nil end,
    }
end
local function complete(pid, ticket)
    local ok = P.failNext == nil
    local result = ok and "{ ok = true }" or ('{ ok = false, error = "' .. P.failNext .. '" }')
    P.failNext = nil
    fire("onCyberwareOperationCompleted", tostring(pid), ticket, result)
end
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    cyberware = {
        define = function(def) P.defs[def.id] = def; return true end,
        current = function(pid) P.records[pid] = P.records[pid] or { revision = 1 }; return P.records[pid] end,
        newOperationId = function() return "op" end,
        install = function(pid, def, grade)
            local d = P.defs[def]
            P.nextTicket = P.nextTicket + 1
            local ticket = "t" .. P.nextTicket
            local willFail = P.failNext ~= nil
            if not willFail then P.records[pid][d.slot] = { definition = def, grade = { id = grade } } end
            P.records[pid].revision = P.records[pid].revision + 1
            complete(pid, ticket)
            return { ok = true, ticket = ticket }
        end,
        remove = function(pid, opts)
            P.nextTicket = P.nextTicket + 1
            P.records[pid][opts.slot] = nil
            complete(pid, "t" .. P.nextTicket)
            return { ok = true, ticket = "t" .. P.nextTicket }
        end,
    },
    dash = grantApi("dash"), reflex = grantApi("reflex"), abilities = grantApi("abilities"),
    stats = {
        get = function() return { health = { maximum = 100, regenPerSecond = 0, regenEnabled = false },
            stamina = { maximum = 100, regenPerSecond = 20 }, armor = 0 } end,
        setMax = function(pid, pool, v) P.stats[pool .. "Max"] = v; return true end,
        setRegenRate = function(pid, pool, v) P.stats[pool .. "Regen"] = v; return true end,
        setRegenEnabled = function(pid, pool, v) P.stats[pool .. "RegenOn"] = v; return true end,
    },
    players = {
        getLifeState = function() return { phase = P.life } end,
        setArmor = function(pid, v) P.armor[pid] = v; return true end,
        setFallDamage = function(pid, v) P.fall[pid] = v; return true end,
    },
    weapons = {
        holster = function() return true end,
        remove = function(pid, slot) P.weaponCalls[#P.weaponCalls + 1] = "remove:" .. slot; local r = #P.weaponCalls; fire("open77:weapons:completed", pid, r, nil, true); return r end,
        assign = function(pid, record, slot) P.weaponCalls[#P.weaponCalls + 1] = "assign:" .. record .. ":" .. slot; local r = #P.weaponCalls; fire("open77:weapons:completed", pid, r, nil, true); return r end,
    },
}

-- The framework -------------------------------------------------------------------
local rows, notices, stock = {}, {}, {}
local bank, cash, parts = { [7] = 0 }, { [7] = 0 }, { ["inv7"] = 0 }
local synced = 0
_G.LightRpItems = { salvaged_parts = { label = "Salvaged Parts" } }
_G.LightRP = {
    log = function() end,
    notice = function(pid, def) notices[#notices + 1] = def end,
    result = function() end,
    db = {
        ready = true, schema = function() end,
        run = function(sql, p)
            if sql:match("lightrp_cyberware_parts") then stock[p[1] .. "#" .. p[2]] = p[3]
            elseif sql:match("^INSERT") then rows[p[1] .. "#" .. p[2] .. "#" .. p[3]] = true
            elseif sql:match("^DELETE") then rows[p[1] .. "#" .. p[2] .. "#" .. p[3]] = nil end
            return true
        end,
        single = function(sql, p)
            if sql:match("lightrp_cyberware_parts") and stock[p[1] .. "#" .. p[2]] then return { parts = stock[p[1] .. "#" .. p[2]] } end
        end,
        query = function(sql, p)
            local out = {}
            for key in pairs(rows) do
                local id, k, item = key:match("^(.-)#(.-)#(.*)$")
                if id == p[1] and k == p[2] then out[#out + 1] = { item = item } end
            end
            return out
        end,
    },
    money = {
        get = function(pid) return { bank = bank[pid], cash = cash[pid], number = "ABC-123" } end,
        removeBank = function(pid, n) if bank[pid] < n then return false, "insufficient_funds" end bank[pid] = bank[pid] - n; return true end,
        addBank = function(pid, n) bank[pid] = bank[pid] + n; return true end,
        format = function(n) return "€$ " .. n end,
    },
    inventory = {
        playerId = function(pid) return "inv" .. pid end,
        count = function(inv) return parts[inv] or 0 end,
        removeItem = function(inv, _, n) if (parts[inv] or 0) < n then return false end parts[inv] = parts[inv] - n; return true end,
        addItem = function(inv, _, n) parts[inv] = (parts[inv] or 0) + n; return true end,
    },
    armament = { synchronize = function() synced = synced + 1; return true end },
    ripperdoc = { isSeated = function() return P.seated ~= false end },
}
function LightRP.module(name, def) def.name = name; LightRP[name] = LightRP[name] or def; return def end

dofile("server/config/cyberware.lua")
dofile("server/modules/cyberware.lua")
pump(true)
local Cyber = LightRP.cyberware
assert(P.defs["lightrp.legs"] and P.defs["lightrp.gorilla"] and P.defs["lightrp.dash.basic"] and P.defs["lightrp.overdrive.street"]
    and P.defs["lightrp.ground_slam"], "every platform definition registered")

local character = { identifier = "u1", key = "default" }
Cyber.onCharacterLoaded(7, character)
pump()

local function op(kind, id)
    local outcome
    Cyber.operate(7, kind, id, function(ok, message) outcome = { ok = ok, message = message } end)
    pump()
    return outcome
end

-- The clinic's view
local view = Cyber.view(7)
assert(view.live and #view.catalogue == #LightRpCyberwareConfig.items and view.wallet == 0, "catalogue view")
assert(view.capacity == nil and view.parts == nil, "eurodollars only: no capacity, no parts")
assert(view.catalogue[1].requires == nil, "no prerequisites")

-- Refusal: money (nothing is taken)
bank[7] = 1000
local r = op("install", "neofiber")
assert(not r.ok and r.message:match("eurodollars"), r.message)
assert(bank[7] == 1000, "no money taken on a refusal")
bank[7] = 500000

-- Not on the chair
P.seated = false
r = op("install", "neofiber")
assert(not r.ok and r.message:match("operating chair"))
P.seated = true

-- No limit: a Mk.2 straight away, paid, persisted, granted
r = op("install", "neofiber_mk2")
assert(r.ok, r.message)
assert(bank[7] == 500000 - 30000, "price taken")
assert(rows["u1#default#neofiber_mk2"], "persisted")
assert(P.grants.dash[7] == "lightrp.dash.advanced", "advanced dash granted")
-- ... and any model of the family replaces it, even a lesser one (one native dash)
r = op("install", "neofiber")
assert(r.ok, r.message)
assert(rows["u1#default#neofiber"] and not rows["u1#default#neofiber_mk2"], "replaced")
assert(P.grants.dash[7] == "lightrp.dash.basic", "basic dash granted")

-- Durable legs through the platform, and a failed surgery refunds the price
local before = bank[7]
P.failNext = "native_timeout"
r = op("install", "reinforced_tendons")
assert(not r.ok and r.message:match("refunded"), r.message)
assert(bank[7] == before, "refunded")
assert(not rows["u1#default#reinforced_tendons"])
r = op("install", "reinforced_tendons_mk2")
assert(r.ok, r.message)
assert(P.records[7].legs and P.records[7].legs.grade.id == "athlete", "platform legs installed (athlete)")

-- Passives
r = op("install", "titanium_bones"); assert(r.ok, r.message)
r = op("install", "subdermal_armor"); assert(r.ok, r.message)
r = op("install", "fortified_ankles"); assert(r.ok, r.message)
assert(P.stats.healthMax == 125 and P.armor[7] == 30 and P.fall[7] == false, "health, armor and fall damage applied")
r = op("install", "epimorphic_skeleton"); assert(r.ok, r.message)
assert(P.stats.healthMax == 160, "the bones replace each other, they do not stack: " .. tostring(P.stats.healthMax))

-- Everything at once: no capacity
for _, id in ipairs({ "sandevistan_mk3", "impact_frame", "biomonitor", "iron_lungs", "adrenaline_booster", "subdermal_armor_mk2" }) do
    r = op("install", id); assert(r.ok, id .. ": " .. tostring(r.message))
end
assert(P.grants.reflex[7] == "lightrp.overdrive.combat" and P.grants.abilities[7] == "lightrp.ground_slam", "overdrive and slam granted")
assert(P.armor[7] == 60 and P.stats.staminaMax == 140, "armor Mk.2 and lungs")

-- Arms: Gorilla Arms, then Mantis Blades take the slot (Gorilla Arms leave the platform)
r = op("install", "gorilla_arms_mk2"); assert(r.ok, r.message)
assert(P.records[7].arms and P.records[7].arms.grade.id == "industrial")
r = op("install", "mantis_blades"); assert(r.ok, r.message)
assert(P.records[7].arms == nil, "Gorilla Arms removed from the platform for the blades")
assert(rows["u1#default#mantis_blades"] and not rows["u1#default#gorilla_arms_mk2"])

-- Mantis Blades: B draws them (the armament stands aside), B again sheathes them
_G.source = 7
netHandlers["op77_lightrp:cyberware:blades"]()
pump()
assert(Cyber.handlesLoadout(7), "blades drawn: the armament stands aside")
assert(P.weaponCalls[#P.weaponCalls] == "assign:Items.MantisBlades:1", "blades assigned to the arm slot")
netHandlers["op77_lightrp:cyberware:blades"]()
pump()
assert(not Cyber.handlesLoadout(7) and synced >= 1, "sheathed: RP weapons projected again")
-- B is also the holster key: with a gun or the fists in hand it puts them away (through
-- the armament) and does not draw the blades; with empty hands it draws them again.
local holsters = 0
local armamentHolster = LightRP.armament.holster
LightRP.armament.holster = function(pid) holsters = holsters + 1; return true end
Open77.weapons.get = function() return { drawn = true } end
netHandlers["op77_lightrp:cyberware:blades"]()
pump()
assert(holsters == 1 and not Cyber.handlesLoadout(7), "B with something in hand holsters it, the blades stay sheathed")
Open77.weapons.get = function() return { drawn = false } end
local noticesBefore = #notices
netHandlers["op77_lightrp:cyberware:blades"]()
pump()
assert(holsters == 1 and Cyber.handlesLoadout(7), "empty hands: B draws the blades")
assert(Cyber.sheatheBlades(7) == true and Cyber.sheatheBlades(7) == false, "the armament's holster sheathes drawn blades once")
pump()
assert(#notices == noticesBefore, "no notice on a plain B")
LightRP.armament.holster = armamentHolster; Open77.weapons.get = nil

-- Removal: a fee
r = op("remove", "reinforced_tendons_mk2"); assert(r.ok, r.message)
assert(P.records[7].legs == nil, "legs removed from the platform")
local fee = bank[7]
r = op("remove", "epimorphic_skeleton"); assert(r.ok, r.message)
assert(bank[7] == fee - LightRpCyberwareConfig.removalFee, "removal fee")
assert(P.stats.healthMax == 100, "health back to the body's own")
r = op("remove", "sandevistan_mk3"); assert(r.ok, r.message)
assert(P.grants.reflex[7] == nil, "a removed Sandevistan takes its grant with it")

-- Persistence across a reconnect: what is in the table is projected again
Cyber.onDisconnected(7)
P.grants.dash[7] = nil
Cyber.onCharacterLoaded(7, character)
pump()
assert(Cyber.installed(7).neofiber and Cyber.installed(7).mantis_blades, "reloaded from the table")
assert(P.grants.dash[7] == "lightrp.dash.basic", "grants come back on load")

-- Staff command
commands["lightrp.cyberware"](0, { "7", "give", "sandevistan_mk1" })
pump()
assert(Cyber.installed(7).sandevistan_mk1 and P.grants.reflex[7] == "lightrp.overdrive.street", "staff give")
commands["lightrp.cyberware"](0, { "7", "take", "sandevistan_mk1" })
pump()
assert(not Cyber.installed(7).sandevistan_mk1 and P.grants.reflex[7] == nil, "staff take")

print("cyberware_test: ok")
