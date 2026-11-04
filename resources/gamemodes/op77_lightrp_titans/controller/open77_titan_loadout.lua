-- op77_lightrp_titans: the Titan loadout, the one definition the server, the client resource and the controller share.
--
-- Every perk of the controller's Titan tree is a level 0..max. Nothing is bought, earned or saved: a Titan is granted
-- at full level (`defaults()`) and the server's Lua decides what one player's Titan may do by handing it another
-- complete map (`patch`). The levels keep the controller's own meaning - an upgrade level is the index into the
-- controller's value table for that perk, 0 is "not owned".
--
-- `max` is the final state of the controller's perk tables (FPC.perk.max of bt_walk_test 1.2.0 after every
-- registration up to t171): the base tree (32), ARC WAVE (4), TARGET DESIGNATOR / SENTRY MODE / FLIGHT STRIKE (3),
-- SEISMIC HAMMER (4), the main perks (3) and the three protocols (3). SWIFT STRIKES (`swordspeed`) keeps its id and
-- its three levels under the controller's final FAST CHARGE behaviour. A perk the controller does not list is not
-- a perk here.
--
-- Data and arithmetic only, no engine calls: the same source runs as a shared script of the resource (it assigns
-- the global below), under the offline protocol tests and as the controller module `open77_titan_loadout` (the same text
-- with only `local` in front of the table, kept identical by hand: a test compares them). That is why it must stay
-- valid for Lua 5.4 and LuaJIT alike. Validators accept plain tables only and what comes out is always a fresh copy,
-- never the input table. Where the host has getmetatable (the server runtime) input with a metatable is
-- refused, so no metamethod ever runs; the client resource host removes getmetatable and setmetatable alike, so
-- nothing there can attach one and a wire-decoded map cannot carry one.

local Open77TitanLoadout = {
    max = {
        -- base tree
        airdash = 1, dash = 1, dashregen = 3, skate = 3, dashcap = 2, dashdist = 2,
        jump = 1, jumpgauge = 1, jumpcharge = 2, jumpcap = 2,
        rocketcap = 2, rocketcd = 3, incendiary = 3, gas = 3,
        vortexthrow = 2, vortexcap = 3, vortexcd = 2, smokecd = 2, smokestack = 1,
        xo16 = 1, railgun = 1, predator = 1, xoammo = 2, xodamage = 2, xoreload = 2,
        railcap = 2, railcharge = 2, raildamage = 2, predcap = 2, predspin = 2, preddamage = 2,
        burstcore = 3,
        -- ARC WAVE, KEEN EDGE, SWIFT STRIKES, LONG REACH
        sword = 1, sworddamage = 2, swordspeed = 2, swordreach = 2,
        -- TARGET DESIGNATOR, SENTRY MODE, FLIGHT STRIKE
        designator = 1, sentry = 1, flight = 1,
        -- SEISMIC HAMMER, IRON FISTS, ADAMANT FRAME, HEAVY HANDS
        fist = 1, fistdamage = 2, fistarmor = 2, fiststun = 2,
        -- HULL PLATING, SHIELD CYCLER, BLAST PLATING
        hull = 3, armor = 3, blastres = 3,
        -- PROTOCOL 1, 2, 3
        proto1 = 2, proto2 = 2, proto3 = 2,
    },
}
local M = Open77TitanLoadout

-- The real getter where the host keeps it (nil in the client resource host's sandbox): never a stand-in.
local getmetatable = getmetatable

local function plain(value)
    return type(value) == "table" and (getmetatable == nil or getmetatable(value) == nil)
end

-- LuaJIT has no integer subtype: there a level stays the (integral) number it arrived as.
local tointeger = math.tointeger or function(value) return value end

-- The validators read this private copy, never `M.max`, which a caller could edit.
local MAX, IDS = {}, {}
for id, max in pairs(M.max) do
    MAX[id] = max
    IDS[#IDS + 1] = id
end
table.sort(IDS)

local function unknownKey(key)
    if type(key) == "string" then return key:sub(1, 32) end
end

-- One level: a finite whole number 0..max of `id`. Returns the level, or nil and the reason.
local function bounded(value, id)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value % 1 ~= 0 then
        return nil, "loadout_value"
    end
    if value < 0 or value > MAX[id] then return nil, "loadout_range" end
    return tointeger(value)
end

-- A fresh complete map with every perk at its maximum.
function M.defaults()
    local out = {}
    for id, max in pairs(MAX) do out[id] = max end
    return out
end

-- `value` must name every perk exactly once and nothing else. Returns a fresh complete map, or nil, a reason token
-- and the offending perk id (an unknown key is only echoed as a short string; callers log it, never relay it).
-- Reasons: loadout_invalid (not a plain table), loadout_unknown, loadout_missing, loadout_value, loadout_range.
function M.complete(value)
    if not plain(value) then return nil, "loadout_invalid" end
    local out = {}
    for id, raw in pairs(value) do
        if MAX[id] == nil then return nil, "loadout_unknown", unknownKey(id) end
        local level, reason = bounded(raw, id)
        if not level then return nil, reason, id end
        out[id] = level
    end
    for _, id in ipairs(IDS) do
        if out[id] == nil then return nil, "loadout_missing", id end
    end
    return out
end

-- `changes` is a sparse map of known perks and levels laid over `current`, the complete map the caller holds
-- (checked again here: a map that is not complete is refused as loadout_current rather than extended). Returns a fresh
-- complete map, or nil, a reason token and the offending perk id. Nothing is mutated: a refusal changes neither
-- argument, and an empty `changes` is valid.
function M.patch(current, changes)
    local out = M.complete(current)
    if not out then return nil, "loadout_current" end
    if not plain(changes) then return nil, "loadout_invalid" end
    for id, raw in pairs(changes) do
        if MAX[id] == nil then return nil, "loadout_unknown", unknownKey(id) end
        local level, reason = bounded(raw, id)
        if not level then return nil, reason, id end
        out[id] = level
    end
    return out
end

-- The perk each weapon's own upgrade rides on, by the wire's weapon names (shared.lua T.weapons): the XO-16's accelerating spin, the
-- railgun's pierce, the predator's tight zoom, ARC WAVE and SEISMIC HAMMER. A weapon whose perk is 0 cannot be selected: the server
-- refuses its `weapon` command and the controller its own switches (the grab key takes the fists out).
local WEAPON_PERK = { xo16 = "xo16", rail = "railgun", pred = "predator", sword = "sword", fist = "fist" }

-- The perk id of a weapon name, or nil for anything that is not one.
function M.weaponPerk(weapon)
    if type(weapon) == "string" then return WEAPON_PERK[weapon] end
end

-- The loadout of a class: `perks` (sparse, or nil) over the maximum of every perk, then the class weapon's perk at 1 and the other
-- four weapons' at 0. Returns a fresh complete map, or nil, a reason token (the validators' own, or loadout_weapon for a name that
-- is no weapon) and the offending perk id.
function M.forClass(weapon, perks)
    if M.weaponPerk(weapon) == nil then return nil, "loadout_weapon" end
    local out, reason, id = M.patch(M.defaults(), perks == nil and {} or perks)
    if not out then return nil, reason, id end
    local changes = {}
    for name, perk in pairs(WEAPON_PERK) do changes[perk] = (name == weapon) and 1 or 0 end
    return M.patch(out, changes)
end

return Open77TitanLoadout
