-- Staff weapons (/admin > Weapons & ammo, a player's Give group; owner, 2026-11-05: "les armes
-- données via menu admin apparaissent dans la roue des armes du joueur, pouvoir donner
-- correctement des munitions").
--
-- A firearm is a serialized inventory item: armament_store mints its serial inside the
-- inventory transaction, so a weapon given here is a real one (wheel, equip, trade, shop
-- resale) and never a bare native grant that the projection takes back. Its rounds are loose
-- items of its ammunition type. Weapon and rounds land in ONE all-or-nothing write; then the
-- player's weapon wheel is refreshed at once and, with a weapon in hand, the new rounds are
-- loaded now (the 2 s observe loop would within 2 s anyway).
--
--   /lightrp.giveweapon <id|me> <weapon> [rounds]     weapon: weapon_lexington, lexington, a record or a label
--   /lightrp.giveammo <id|me> <pistol|rifle|shotgun|sniper|all> <rounds>
--   /lightrp.takeweapon <id|me> <weapon>               one instance not in hand
--   /lightrp.weapons <id|me>                           what the wheel lists, rounds per type
local W, C, Inv = LightRP.armament, LightRpArmament, LightRP.inventory
local AW = LightRP.module("armamentAdmin", {})
local MAX_ROUNDS = 2000

local function lower(v) return string.lower(tostring(v or "")) end
function AW.weapon(token)
    token = lower(token)
    if token == "" then return nil end
    if C.weapons[token] then return token end
    if C.weapons["weapon_" .. token] then return "weapon_" .. token end
    for id, spec in pairs(C.weapons) do
        if lower(spec.record) == token or lower(spec.label) == token then return id end
    end
end
function AW.ammo(token)
    token = lower(token)
    if C.ammo[token] then return token end
    for kind, spec in pairs(C.ammo) do if spec.item == token then return kind end end
end
local function target(source, arg)
    if arg == nil or arg == "me" then return source and source > 0 and source or nil end
    local id = tonumber(arg)
    return id and GetPlayerName(id) ~= nil and id or nil
end
local function name(player) return LightRP.characters and LightRP.characters.displayName(player) or ("#" .. tostring(player)) end
local function explain(why) return Inv.explain and Inv.explain(why) or ("Refused: " .. tostring(why)) end

-- The wheel shows the new weapon now, and a weapon in hand loads the new rounds now.
function AW.refresh(player)
    if type(W.push) == "function" then pcall(W.push, player) end
    local rt = W.runtime and W.runtime[player]
    local inv = Inv.player(player)
    local s = inv and W.states and W.states[inv.id]
    if rt and s and s.right and type(W.synchronize) == "function" then
        CreateThread(function()
            Wait(250)
            local again = W.runtime and W.runtime[player]
            if again and again.ready and not again.busy then pcall(W.synchronize, player, true) end
        end)
    end
end

local function rounds(count)
    count = math.tointeger(tonumber(count) or 0)
    if not count or count < 0 or count > MAX_ROUNDS then return nil end
    return count
end

function AW.giveWeapon(player, weapon, count)
    local inv = Inv.player(player)
    if not inv then return false, "That player's inventory is not loaded yet." end
    local spec = C.weapons[weapon]
    if not spec then return false, "Unknown weapon." end
    count = rounds(count)
    if not count then return false, ("Rounds: 0 to %d."):format(MAX_ROUNDS) end
    local list = { { name = weapon, count = 1 } }
    local ammo = C.ammo[spec.ammo]
    if count > 0 then list[#list + 1] = { name = ammo.item, count = count } end
    local ok, why = Inv.addItems(inv.id, list)
    if not ok then return false, explain(why) end
    AW.refresh(player)
    LightRP.notice(player, { kind = "staff", title = "Weapon received", durationMs = 8000,
        body = count > 0 and ("%s and %d %s. Pick it from the weapon wheel (TAB)."):format(spec.label, count, ammo.label:lower())
            or ("%s. Pick it from the weapon wheel (TAB)."):format(spec.label) })
    LightRP.log("staff weapon: %s (+%d %s) to %d", weapon, count, spec.ammo, player)
    return true, ("%s%s given to %s."):format(spec.label, count > 0 and (" + " .. count .. " " .. ammo.label:lower()) or "", name(player))
end

function AW.giveAmmo(player, kind, count)
    local inv = Inv.player(player)
    if not inv then return false, "That player's inventory is not loaded yet." end
    count = rounds(count)
    if not count or count < 1 then return false, ("Rounds: 1 to %d."):format(MAX_ROUNDS) end
    local list, labels = {}, {}
    local kinds = {}
    if kind == "all" then for k in pairs(C.ammo) do kinds[#kinds + 1] = k end; table.sort(kinds) else kinds[1] = kind end
    for _, k in ipairs(kinds) do
        local spec = C.ammo[k]
        if not spec then return false, "Unknown ammunition type." end
        list[#list + 1] = { name = spec.item, count = count }
        labels[#labels + 1] = spec.label:lower()
    end
    local ok, why = Inv.addItems(inv.id, list)
    if not ok then return false, explain(why) end
    AW.refresh(player)
    LightRP.notice(player, { kind = "staff", title = "Ammunition received", durationMs = 6000,
        body = ("%d %s. A weapon in hand loads them from your pockets."):format(count, table.concat(labels, ", ")) })
    return true, ("%d %s given to %s."):format(count, table.concat(labels, ", "), name(player))
end

-- One instance of that model the player does not hold in a hand (armament_store refuses to
-- move an equipped serial anyway).
function AW.takeWeapon(player, weapon)
    local inv = Inv.player(player)
    if not inv then return false, "That player's inventory is not loaded yet." end
    local s = W.states and W.states[inv.id] or {}
    local draft = Inv.draft(inv)
    local found, inHand = nil, false
    for slot, item in pairs(draft.items) do
        if item.name == weapon then
            local id = type(item.metadata) == "table" and item.metadata.instanceId
            if id and (s.right == id or s.left == id) then inHand = true
            elseif not found then found = slot end
        end
    end
    if not found then return false, inHand and "That weapon is in their hand: it goes back to the pockets first (B or the wheel's top slot), then retry." or "They do not have this weapon." end
    draft.items[found] = nil
    local ok, why = Inv.commitDrafts({ { inv, draft } })
    if not ok then return false, explain(why) end
    AW.refresh(player)
    return true, ("%s taken from %s."):format(C.weapons[weapon].label, name(player))
end

function AW.summary(player)
    local inv = Inv.player(player)
    if not inv then return false, "That player's inventory is not loaded yet." end
    local view = type(W.view) == "function" and W.view(player) or {}
    local parts = {}
    for _, row in ipairs(type(view.arsenal) == "table" and view.arsenal or {}) do
        parts[#parts + 1] = row.label .. (row.hand and (" [" .. row.hand .. "]") or "")
    end
    local stock = {}
    for kind, spec in pairs(C.ammo) do stock[#stock + 1] = ("%s %d"):format(kind, Inv.count(inv.id, spec.item)) end
    table.sort(stock)
    return true, ("%s: %s · rounds: %s"):format(name(player), #parts > 0 and table.concat(parts, ", ") or "no firearm", table.concat(stock, ", "))
end

LightRP.command("lightrp.giveweapon", { restricted = true, usage = "/lightrp.giveweapon <id|me> <weapon> [rounds]" }, function(source, args)
    local player = target(source, args[1])
    if not player then return false, "Unknown player." end
    local weapon = AW.weapon(args[2])
    if not weapon then
        local ids = {}; for id in pairs(C.weapons) do ids[#ids + 1] = id:gsub("^weapon_", "") end; table.sort(ids)
        return false, "Unknown weapon. Weapons: " .. table.concat(ids, ", ")
    end
    return AW.giveWeapon(player, weapon, args[3] or 0)
end)
LightRP.command("lightrp.giveammo", { restricted = true, usage = "/lightrp.giveammo <id|me> <pistol|rifle|shotgun|sniper|all> <rounds>" }, function(source, args)
    local player = target(source, args[1])
    if not player then return false, "Unknown player." end
    local kind = lower(args[2]) == "all" and "all" or AW.ammo(args[2])
    if not kind then return false, "Ammunition: pistol, rifle, shotgun, sniper or all." end
    return AW.giveAmmo(player, kind, args[3])
end)
LightRP.command("lightrp.takeweapon", { restricted = true, usage = "/lightrp.takeweapon <id|me> <weapon>" }, function(source, args)
    local player = target(source, args[1])
    if not player then return false, "Unknown player." end
    local weapon = AW.weapon(args[2])
    if not weapon then return false, "Unknown weapon." end
    return AW.takeWeapon(player, weapon)
end)
LightRP.command("lightrp.weapons", { restricted = true, usage = "/lightrp.weapons <id|me>" }, function(source, args)
    local player = target(source, args[1])
    if not player then return false, "Unknown player." end
    return AW.summary(player)
end)
