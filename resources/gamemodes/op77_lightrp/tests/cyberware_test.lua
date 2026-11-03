-- The cyberware module (server/modules/cyberware.lua) against a fake platform and framework:
-- refusals (money, not seated), payment and refund, family replacement (the mate goes to
-- storage), storage (fitting from it costs the fitting fee, taking out costs it too), capacity
-- (refused past it, over-capacity characters keep everything and only swap lighter), durable
-- legs/arms transactions, session grants by kind (the operating system holds a Sandevistan OR a
-- Berserk), passives and the timed regeneration layers, Mantis Blades, iconics never sold, the
-- clinic payload, persistence and the staff command; street cred gating (locked view, refusal
-- before payment, capacity by tier) and the ranked PvP switch (activeInPvp).
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
-- rows: fitted (lightrp_cyberware), stored: storage (lightrp_cyberware_stock), "identifier#key#item"
local rows, stored, notices, logs, hooks = {}, {}, {}, {}, {}
local bank = { [7] = 0 }
local synced, failTransaction = 0, false
local function tableOf(sql) return sql:match("lightrp_cyberware_stock") and stored or rows end
_G.LightRP = {
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    notice = function(pid, def) notices[#notices + 1] = def end,
    result = function() end,
    eachModule = function(hook, ...) hooks[#hooks + 1] = { hook = hook, args = table.pack(...) } end,
    db = {
        ready = true, schema = function() end,
        run = function(sql, p)
            local t = tableOf(sql)
            if sql:match("^INSERT") then t[p[1] .. "#" .. p[2] .. "#" .. p[3]] = true
            elseif sql:match("^DELETE") then t[p[1] .. "#" .. p[2] .. "#" .. p[3]] = nil end
            return true
        end,
        transaction = function(queries)
            if failTransaction then return false, "database_error" end
            for _, q in ipairs(queries) do LightRP.db.run(q.query, q.values) end
            return true
        end,
        query = function(sql, p)
            local out = {}
            for key in pairs(tableOf(sql)) do
                local id, k, item = key:match("^(.-)#(.-)#(.*)$")
                if id == p[1] and k == p[2] then out[#out + 1] = { item = item } end
            end
            return out
        end,
    },
    money = {
        get = function(pid) return { bank = bank[pid], cash = 0, number = "ABC-123" } end,
        removeBank = function(pid, n) if bank[pid] < n then return false, "insufficient_funds" end bank[pid] = bank[pid] - n; return true end,
        addBank = function(pid, n) bank[pid] = bank[pid] + n; return true end,
        format = function(n) return "€$ " .. n end,
    },
    armament = { synchronize = function() synced = synced + 1; return true end },
    ripperdoc = { isSeated = function() return P.seated ~= false end },
}
function LightRP.module(name, def) def.name = name; LightRP[name] = LightRP[name] or def; return def end

dofile("server/config/cyberware.lua")
dofile("server/modules/cyberware.lua")
pump(true)
local CW = LightRpCyberwareConfig
local Cyber = LightRP.cyberware
assert(P.defs["lightrp.legs"] and P.defs["lightrp.gorilla"] and P.defs["lightrp.dash.basic"] and P.defs["lightrp.overdrive.street"]
    and P.defs["lightrp.ground_slam"], "every platform definition registered")

-- The catalogue: every implant has a capacity cost, the OS family holds Sandevistans and
-- Berserks, a full V+ set does not fit the top capacity, iconics stay out of the shop list.
local byId, bestOf = {}, {}
for _, item in ipairs(CW.items) do
    byId[item.id] = item
    assert(type(item.capacity) == "number" and item.capacity >= 1, item.id .. " has a capacity cost")
    assert(not item.iconic and item.price > 0, item.id .. " is sold")
    if not bestOf[item.family] or item.capacity > bestOf[item.family] then bestOf[item.family] = item.capacity end
end
assert(#CW.items == 32, "32 implants on sale: " .. #CW.items)
for _, id in ipairs({ "sandevistan_mk1", "sandevistan_mk3", "zetatech_apogee", "berserk_mk1", "berserk_mk3" }) do
    assert(byId[id].family == "os" and byId[id].section == "operating_system", id .. " in the operating system")
end
local full = 0
for _, cost in pairs(bestOf) do full = full + cost end
assert(full > CW.capacity.byTier[#CW.capacity.byTier] * 2, "the best of every family is far past the top capacity: " .. full)
local vplus = 0
for _, item in ipairs(CW.items) do if item.tier == 6 then vplus = vplus + item.capacity end end
assert(vplus > CW.capacity.byTier[5], "the four V+ implants alone do not fit: " .. vplus)
assert(CW.capacity.byTier[1] == 10 and CW.capacity.byTier[2] == 14 and CW.capacity.byTier[3] == 18 and CW.capacity.byTier[4] == 22
    and CW.capacity.byTier[5] == 26, "capacity by tier")
local rankII = 0
for _, item in ipairs(CW.items) do if item.tier == 2 then rankII = rankII + item.capacity end end
assert(rankII <= CW.capacity.byTier[1], "every rank II implant fits a Street body: " .. rankII)
assert(CW.fittingFee == 50, "the fitting fee")
for _, item in ipairs(CW.iconics.items) do assert(item.iconic == true and Cyber.item(item.id) == item, "iconics known to the module") end

local character = { identifier = "u1", key = "default" }
Cyber.onCharacterLoaded(7, character)
pump()

local function op(kind, id)
    local outcome
    Cyber.operate(7, kind, id, function(ok, message) outcome = { ok = ok, message = message } end)
    pump()
    return outcome
end
local function card(view, id) for _, c in ipairs(view.catalogue) do if c.id == id then return c end end end
local function used() return Cyber.capacity(7).used end

-- The clinic's view (no missions module: the gate is open, the capacity is the fallback)
local view = Cyber.view(7)
assert(view.live and #view.catalogue == #CW.items + #CW.iconics.items and view.wallet == 0, "catalogue view")
assert(view.capacity.used == 0 and view.capacity.total == CW.capacity.fallback and view.capacity.over == false, "capacity in the payload")
assert(view.fittingFee == 50 and view.removalFee == 50 and #view.stock == 0, "fees and an empty storage")
assert(card(view, "neofiber").capacity == 3 and card(view, "chimera_plating").iconic and card(view, "chimera_plating").dropOnly
    and card(view, "chimera_plating").source == "Chimera raid (Critical)", "per-implant capacity, iconic cards")
assert(card(view, "neofiber").requires == nil and card(view, "neofiber").iconic == nil, "no prerequisites, not iconic")

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

-- An iconic is never sold
r = op("install", "chimera_plating")
assert(not r.ok and r.message:find("not for sale") and r.message:find("Chimera raid"), r.message)
assert(bank[7] == 500000, "nothing taken")

-- A Mk.2 straight away, paid, persisted, granted
r = op("install", "neofiber_mk2")
assert(r.ok, r.message)
assert(bank[7] == 500000 - 30000, "price taken")
assert(rows["u1#default#neofiber_mk2"], "persisted")
assert(P.grants.dash[7] == "lightrp.dash.advanced", "advanced dash granted")
-- ... another model of the family replaces it: the Mk.2 goes to storage, nothing is lost
r = op("install", "neofiber")
assert(r.ok and r.message:find("storage"), r.message)
assert(rows["u1#default#neofiber"] and not rows["u1#default#neofiber_mk2"] and stored["u1#default#neofiber_mk2"], "replaced, the old one stored")
assert(bank[7] == 500000 - 30000 - 13000 and P.grants.dash[7] == "lightrp.dash.basic", "basic dash granted, its price paid")
-- ... and fitting the Mk.2 back from storage costs the fitting fee, not the price
local before = bank[7]
r = op("install", "neofiber_mk2")
assert(r.ok, r.message)
assert(bank[7] == before - CW.fittingFee, "only the fitting fee: " .. (before - bank[7]))
assert(stored["u1#default#neofiber"] and not stored["u1#default#neofiber_mk2"] and rows["u1#default#neofiber_mk2"], "swapped with storage")
assert(Cyber.stored(7).neofiber and Cyber.owns(7, "neofiber") == "stored" and Cyber.owns(7, "neofiber_mk2") == "fitted")
view = Cyber.view(7)
assert(view.stock[1] == "neofiber" and card(view, "neofiber").stored == true, "the payload lists the storage")

-- A failed storage write gives the money back and changes nothing
failTransaction = true
before = bank[7]
r = op("install", "titanium_bones")
assert(not r.ok and r.message:find("refunded"), r.message)
assert(bank[7] == before and not Cyber.installed(7).titanium_bones, "refunded, nothing fitted")
failTransaction = false

-- Durable legs through the platform, and a failed surgery refunds the price
before = bank[7]
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
assert(stored["u1#default#titanium_bones"], "the Titanium Bones wait in storage")
-- neofiber_mk2 4 + tendons_mk2 4 + ankles 2 + subdermal 2 + epimorphic 4
assert(used() == 16, "capacity used: " .. used())

-- Timed regeneration layers add up on top of the passives and go away
Cyber.boost(7, "berserk", 4)
Cyber.boost(7, "pain", 4)
assert(P.stats.healthRegen == 8 and P.stats.healthRegenOn == true, "two layers: " .. tostring(P.stats.healthRegen))
Cyber.boost(7, "berserk", nil)
Cyber.boost(7, "pain", 0)
assert(P.stats.healthRegen == 0 and P.stats.healthRegenOn == false, "layers gone")

-- Arms: Gorilla Arms, then Mantis Blades take the slot (Gorilla Arms leave the platform, to storage)
r = op("install", "gorilla_arms_mk2"); assert(r.ok, r.message)
assert(P.records[7].arms and P.records[7].arms.grade.id == "industrial")
r = op("install", "mantis_blades"); assert(r.ok, r.message)
assert(P.records[7].arms == nil, "Gorilla Arms removed from the platform for the blades")
assert(rows["u1#default#mantis_blades"] and not rows["u1#default#gorilla_arms_mk2"] and stored["u1#default#gorilla_arms_mk2"])
assert(used() == 21, "capacity used: " .. used())

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

-- Capacity: 21 of 26 used, a Sandevistan Mk.3 (7) does not fit; nothing is taken
before = bank[7]
r = op("install", "sandevistan_mk3")
assert(not r.ok and r.message:find("Not enough capacity") and r.message:find("7 points") and r.message:find("5 of your 26"), r.message)
assert(bank[7] == before and not Cyber.installed(7).sandevistan_mk3, "refused before any money moves")
view = Cyber.view(7)
assert(view.capacity.used == 21 and view.capacity.total == 26, "the page shows 21 / 26")
-- Taking an implant out costs the fitting fee and puts it in storage
r = op("remove", "reinforced_tendons_mk2"); assert(r.ok and r.message:find("storage"), r.message)
assert(P.records[7].legs == nil, "legs removed from the platform")
assert(bank[7] == before - CW.fittingFee and stored["u1#default#reinforced_tendons_mk2"], "fee paid, implant stored")
r = op("install", "sandevistan_mk3"); assert(r.ok, r.message)
assert(P.grants.reflex[7] == "lightrp.overdrive.combat" and used() == 24, "overdrive granted, 24 used")

-- The operating system: a Berserk replaces the Sandevistan (one native slot), its grant goes
r = op("install", "berserk_mk1"); assert(r.ok, r.message)
assert(Cyber.installed(7).berserk_mk1 and not Cyber.installed(7).sandevistan_mk3 and stored["u1#default#sandevistan_mk3"], "Berserk in, Sandevistan stored")
assert(P.grants.reflex[7] == nil, "no overdrive grant for a Berserk (grants follow the kind, not the family)")
assert(Cyber.fitted(7, "berserk").id == "berserk_mk1" and Cyber.fitted(7, "overdrive") == nil, "fitted by kind")
assert(used() == 22, "capacity used: " .. used())
before = bank[7]
r = op("install", "sandevistan_mk3"); assert(r.ok, r.message)
assert(bank[7] == before - CW.fittingFee and P.grants.reflex[7] == "lightrp.overdrive.combat", "back from storage, granted again")
local changes = 0
for _, h in ipairs(hooks) do if h.hook == "onCyberwareChanged" and h.args[1] == 7 then changes = changes + 1 end end
assert(changes >= 10, "every surgery tells the active implants: " .. changes)

-- Removal: the fitting fee, the body's own values back
before = bank[7]
r = op("remove", "epimorphic_skeleton"); assert(r.ok, r.message)
assert(bank[7] == before - CW.fittingFee, "removal fee")
assert(P.stats.healthMax == 100, "health back to the body's own")
r = op("remove", "sandevistan_mk3"); assert(r.ok, r.message)
assert(P.grants.reflex[7] == nil, "a removed Sandevistan takes its grant with it")
r = op("remove", "sandevistan_mk3")
assert(not r.ok and r.message:find("not installed"), "a stored implant is not installed")

-- Persistence across a reconnect: the body and the storage are projected again
Cyber.onDisconnected(7)
P.grants.dash[7] = nil
Cyber.onCharacterLoaded(7, character)
pump()
assert(Cyber.installed(7).neofiber_mk2 and Cyber.installed(7).mantis_blades, "reloaded from the table")
assert(Cyber.stored(7).sandevistan_mk3 and Cyber.stored(7).epimorphic_skeleton and Cyber.stored(7).neofiber, "storage reloaded")
assert(P.grants.dash[7] == "lightrp.dash.advanced", "grants come back on load")

-- Storage for drops: Cyber.store (an iconic), fitted later for the fitting fee
assert(Cyber.store(7, "chimera_plating", "iconic:test") == true and stored["u1#default#chimera_plating"], "an iconic into storage")
local ok, why = Cyber.store(7, "chimera_plating", "iconic:test")
assert(not ok and why == "owned", "owned once")
view = Cyber.view(7)
assert(card(view, "chimera_plating").dropOnly == false and card(view, "chimera_plating").stored, "an owned iconic is no longer drop-only")
before = bank[7]
r = op("install", "chimera_plating"); assert(r.ok, r.message)
assert(bank[7] == before - CW.fittingFee and P.armor[7] == 110 and P.stats.healthRegen == 1, "Chimera Plating: +110 armor, +1 health / s")
assert(stored["u1#default#subdermal_armor"], "it replaced the Subdermal Armor (to storage)")

-- Staff command: give fits (a family mate to storage), take removes everywhere, store / unstore
commands["lightrp.cyberware"](0, { "7", "give", "sandevistan_mk1" })
pump()
assert(Cyber.installed(7).sandevistan_mk1 and P.grants.reflex[7] == "lightrp.overdrive.street", "staff give")
commands["lightrp.cyberware"](0, { "7", "take", "sandevistan_mk1" })
pump()
assert(not Cyber.installed(7).sandevistan_mk1 and not Cyber.stored(7).sandevistan_mk1 and P.grants.reflex[7] == nil, "staff take")
commands["lightrp.cyberware"](0, { "7", "store", "berserk_mk3" })
pump()
assert(Cyber.stored(7).berserk_mk3, "staff store")
commands["lightrp.cyberware"](0, { "7", "unstore", "berserk_mk3" })
pump()
assert(not Cyber.stored(7).berserk_mk3, "staff unstore")

-- Street cred (docs/pve-progression.md): a rank needs a reputation tier, and the tier sets
-- the capacity. Above, without the missions module, the gate stayed open; from here the
-- character has a tier.
local NAMES, ROMAN = { "Street", "Merc", "Operator", "Edgerunner", "Legend" }, { "I", "II", "III", "IV", "V" }
local repTier = 1
LightRP.missions = {
    tier = function() return repTier end,
    tierName = function(t) return NAMES[t] end,
    tierLabel = function(t) return ROMAN[t] .. " (" .. NAMES[t] .. ")" end,
    tierInfo = function() return { tier = repTier, name = NAMES[repTier], points = 0, next = 500, nextName = "Merc" } end,
}
assert(Cyber.requiredTier({ tier = 2 }) == 1 and Cyber.requiredTier({ tier = 3 }) == 2 and Cyber.requiredTier({ tier = 5 }) == 4
    and Cyber.requiredTier({ tier = 6 }) == 5 and Cyber.requiredTier({ tier = 2, repTier = 4 }) == 4, "rank -> tier, repTier overrides")
view = Cyber.view(7)
assert(card(view, "iron_lungs").repTier == 1 and card(view, "iron_lungs").locked == false, "rank II: open to everyone")
assert(card(view, "biomonitor").repTier == 2 and card(view, "biomonitor").repName == "Merc", "rank III: Merc")
assert(card(view, "mantis_blades").locked == false, "an implant already fitted never shows locked")
assert(card(view, "sandevistan_mk3").locked == false, "an implant in storage never shows locked")
assert(card(view, "sandevistan_mk1").locked and card(view, "rara_avis").locked and card(view, "rara_avis").repTier == 5)
assert(card(view, "chimera_plating").locked == false, "an iconic is never locked by street cred")
assert(view.reputation.tier == 1 and view.reputation.name == "Street" and view.reputation.next == 500)
-- Over capacity: neofiber_mk2 4 + ankles 2 + mantis 5 + chimera 7 = 18 on a Street body (10)
assert(used() == 18, "capacity used: " .. used())
assert(view.capacity.used == 18 and view.capacity.total == 10 and view.capacity.over == true, "over capacity in the payload")
-- ... the load logs it, everything stays
logs = {}
Cyber.onCharacterLoaded(7, character)
pump()
local logged = false
for _, line in ipairs(logs) do if line:find("over capacity") and line:find("18 / 10") then logged = true end end
assert(logged and Cyber.installed(7).chimera_plating and Cyber.installed(7).mantis_blades, "over capacity: logged, nothing taken")
-- ... nothing new fits, a heavier swap neither; a lighter swap does
before = bank[7]
r = op("install", "iron_lungs")
assert(not r.ok and r.message:find("over capacity") and r.message:find("18 / 10"), r.message)
r = op("install", "aegis_dermal_plating")
assert(not r.ok, "street cred first: " .. r.message)
r = op("install", "neofiber") -- 3 instead of the Mk.2's 4, from storage
assert(r.ok, r.message)
assert(used() == 17 and bank[7] == before - CW.fittingFee, "a lighter swap is allowed")
r = op("install", "neofiber_mk2") -- back to 4: heavier
assert(not r.ok and r.message:find("over capacity"), r.message)
-- the server refuses below the tier, before any money moves
before = bank[7]
r = op("install", "rara_avis")
assert(not r.ok and r.message:find("Street cred too low") and r.message:find("V %(Legend%)"), r.message)
assert(bank[7] == before and not Cyber.installed(7).rara_avis, "nothing taken")
r = op("install", "iron_lungs_mk2")
assert(not r.ok and r.message:find("IV %(Edgerunner%)"), r.message)
-- removal always works, even of an implant above the tier
r = op("remove", "mantis_blades"); assert(r.ok, r.message)
assert(bank[7] == before - CW.fittingFee, "only the fitting fee")
r = op("remove", "chimera_plating"); assert(r.ok, r.message)
assert(used() == 5 and Cyber.capacity(7).over == false, "under capacity again: " .. used())
-- an implant in storage needs only the capacity, not the street cred (rank IV at tier I)
r = op("install", "reinforced_tendons_mk2"); assert(r.ok, r.message)
assert(used() == 9, "capacity used: " .. used())
-- tier V: the apex implants, 26 points
repTier = 5
bank[7] = 1000000
r = op("install", "rara_avis"); assert(r.ok, r.message)
assert(bank[7] == 1000000 - 95000, "rank V+ price")
assert(P.stats.healthMax == 200, "Rara Avis +100 max health: " .. tostring(P.stats.healthMax))
r = op("install", "aegis_dermal_plating"); assert(r.ok, r.message)
assert(P.armor[7] == 100, "Aegis plating")
-- neofiber 3 + ankles 2 + tendons_mk2 4 + rara 7 + aegis 7 = 23: Bioplastic (5) does not fit
assert(used() == 23, "capacity used: " .. used())
r = op("install", "bioplastic_blood_vessels")
assert(not r.ok and r.message:find("Not enough capacity"), r.message)
r = op("remove", "reinforced_tendons_mk2"); assert(r.ok, r.message)
r = op("install", "bioplastic_blood_vessels"); assert(r.ok, r.message)
assert(P.stats.healthRegen == 3, "Bioplastic +3 / s")
-- the Mk.3 dash replaces the Neofiber (3 -> 6): 27 does not fit, without the ankles it does
r = op("install", "neofiber_mk3")
assert(not r.ok and r.message:find("Not enough capacity"), r.message)
r = op("remove", "fortified_ankles"); assert(r.ok, r.message)
r = op("install", "neofiber_mk3"); assert(r.ok, r.message)
assert(P.grants.dash[7] == "lightrp.dash.apex" and used() == 25, "apex dash, 25 / 26")
-- a full V+ set never fits: the Apogee (8) on top is refused
r = op("install", "zetatech_apogee")
assert(not r.ok and r.message:find("Not enough capacity"), r.message)
assert(Cyber.capacity(7).used <= 26, "never past the capacity: " .. Cyber.capacity(7).used)
-- the new presets stay inside the platform's bounds (Open77.dash / Open77.reflex define)
local dash, od = P.defs["lightrp.dash.apex"].config, P.defs["lightrp.overdrive.apex"].config
assert(dash.staminaCost >= 0 and dash.staminaCost <= 300 and dash.cooldownMs >= 300 and dash.maxCharges >= 1 and dash.maxCharges <= 3)
assert(od.tier == "reflex_heavy" and od.durationMs >= 500 and od.durationMs <= 15000 and od.durationMs <= od.cooldownMs
    and od.cooldownMs >= 1000 and od.cooldownMs <= 600000 and od.maxCharges >= 1 and od.maxCharges <= 3)
-- an implant fitted above the tier stays active; staff give ignores the tier and the capacity
repTier = 1
commands["lightrp.cyberware"](0, { "7", "give", "sandevistan_mk3" })
pump()
assert(Cyber.installed(7).sandevistan_mk3 and P.grants.reflex[7] == "lightrp.overdrive.combat", "staff give ignores the tier")
assert(P.stats.healthMax == 200 and P.grants.dash[7] == "lightrp.dash.apex", "nothing is taken from anyone")
assert(Cyber.capacity(7).over, "over capacity after a staff give, kept")

-- Ranked PvP: activeInPvp (an owner decision) -- true keeps the implants, false suspends the
-- session grants and the passives in a non-PvE activity and restores them after.
Cyber.onActivityChanged(7, "arena.ffa", { pve = false, kind = "pvp" })
pump()
assert(P.grants.dash[7] == "lightrp.dash.apex" and P.stats.healthMax == 200, "default: implants stay on in PvP")
Cyber.onActivityChanged(7, nil, { left = "arena.ffa" })
CW.activeInPvp = false
Cyber.onActivityChanged(7, "arena.pve", { pve = true, kind = "pvp" })
pump()
assert(P.grants.dash[7] == "lightrp.dash.apex" and P.armor[7] == 100, "PvE keeps them")
Cyber.onActivityChanged(7, nil, { left = "arena.pve" })
Cyber.onActivityChanged(7, "arena.ffa", { pve = false, kind = "pvp" })
pump()
assert(P.grants.dash[7] == nil and P.grants.reflex[7] == nil and P.grants.abilities[7] == nil, "grants suspended in PvP")
assert(P.stats.healthMax == 100 and P.armor[7] == 0 and P.stats.healthRegen == 0 and P.fall[7] == true, "the body's own values")
assert(Cyber.fitted(7, "dash") == nil, "nothing counts as fitted while suspended (Berserk, optics... stand down)")
Cyber.onActivityChanged(7, nil, { left = "arena.ffa" })
pump()
assert(P.grants.dash[7] == "lightrp.dash.apex" and P.grants.reflex[7] == "lightrp.overdrive.combat", "grants back after")
assert(P.stats.healthMax == 200 and P.armor[7] == 100 and P.fall[7] == true, "passives back after (no ankles fitted now)")
CW.activeInPvp = true

-- The clinic payload stays a reasonable size (op77_ripperdoc sends it latent past 900 values)
view = Cyber.view(7)
local function count(v) if type(v) ~= "table" then return 1 end local n = 1 for _, x in pairs(v) do n = n + 2 + (type(x) == "table" and count(x) - 1 or 0) end return n end
assert(count(view) < 4000, "payload values: " .. count(view))

print("cyberware_test: ok")
