-- Read-only presentation. Completed native snapshots never grant items/ammo or
-- change the server ledger. One in-flight read; reject old body/loadout results.
LightRpWeaponHud = {}
local H = LightRpWeaponHud
local pending, signature, publishedAt, lastRequest = nil, nil, -10000, -10000
local view = { active = false }
local function count(value)
    local n = tonumber(value)
    if n and n == n and n >= 0 and n <= 1000000 and n % 1 == 0 then return n end
end
-- During a raid the weapons are the mission's loadout (server/modules/mission_chimera.lua),
-- not the character's RP firearms: the HUD shows whichever kit weapon is drawn.
local function raidKit()
    local raid = LightRpRaidClient and LightRpRaidClient.state
    return raid and type(raid.kit) == "table" and next(raid.kit) ~= nil and raid.kit or nil
end
local function context()
    local kit = raidKit()
    local body = Open77.character and Open77.character.state()
    if kit then
        if not body or not body.alive or not body.attached then return nil end
        local names = {}
        for record in pairs(kit) do names[#names + 1] = record end
        table.sort(names)
        return "raid:" .. table.concat(names, ","), { kit = kit }
    end
    local state = LightRpArmamentClient and LightRpArmamentClient.state()
    if not state or not state.ready or state.busy or not state.right or not body or not body.alive or not body.attached then return nil end
    return table.concat({ tostring(state.inventoryId), tostring(state.generation), state.right.instanceId, state.left and state.left.instanceId or "" }, ":"), state
end
AddEventHandler("open77:weapons:state", function(id, slot, record, tweakDbId, active, drawn, locked,
    ammoRecord, ammoTweakDbId, total, reserve, magazine, capacity, reloading)
    if not pending or tostring(id) ~= pending.id then return end
    local index = tonumber(slot)
    if index ~= 1 and index ~= 4 and not (pending.kit and (index == 2 or index == 3)) then return end
    pending.rows[index] = { record=record, tweakDbId=tweakDbId, drawn=drawn=="true", active=active=="true",
        ammo=ammoTweakDbId, reserve=count(reserve), magazine=count(magazine), capacity=count(capacity), reloading=reloading=="true" }
end)
AddEventHandler("open77:weapons:completed", function(id, operation, accepted)
    if not pending or tostring(id) ~= pending.id or operation ~= "snapshot" then return end
    local result = pending; pending = nil
    local key, state = context()
    if accepted ~= "true" or key ~= result.signature then view={active=false}; return end
    local nextView = { active=false, hands={} }
    if state.kit then
        for slot = 1, 3 do
            local row = result.rows[slot]
            local label = row and state.kit[row.record]
            if label and row.drawn and row.active then
                local magazine, capacity = row.magazine, row.capacity
                if capacity == 0 or (magazine and capacity and magazine > capacity) then magazine, capacity = nil, nil end
                nextView.hands[1] = { hand = "right", label = label, magazine = magazine, capacity = capacity, reloading = row.reloading }
                nextView.reserve, nextView.active = row.reserve, true
                break
            end
        end
        view = nextView; publishedAt = GetGameTimer()
        return
    end
    local sharedAmmo
    for _, entry in ipairs({{hand="right",slot=1,weapon=state.right},{hand="left",slot=4,weapon=state.left}}) do
        local row = result.rows[entry.slot]
        if entry.weapon and row and row.drawn and row.active and row.tweakDbId and row.tweakDbId ~= "" and row.tweakDbId ~= "0x0000000000000000" and row.record == entry.weapon.record then
            local magazine, capacity = row.magazine, row.capacity
            if capacity == 0 or (magazine and capacity and magazine > capacity) then magazine,capacity=nil,nil end
            nextView.hands[#nextView.hands+1] = { hand=entry.hand,label=entry.weapon.label,magazine=magazine,capacity=capacity,reloading=row.reloading }
            if #nextView.hands == 1 then sharedAmmo=row.ammo;nextView.reserve=row.reserve
            elseif not sharedAmmo or sharedAmmo=="" or row.ammo~=sharedAmmo or not nextView.reserve or not row.reserve then nextView.reserve=nil
            else nextView.reserve=math.min(nextView.reserve,row.reserve) end
            nextView.active=true
        end
    end
    view=nextView; publishedAt=GetGameTimer()
end)
function H.sample()
    local key = context()
    local now = GetGameTimer()
    if key ~= signature then signature=key;pending=nil;view={active=false} end
    if not key then return {active=false} end
    if now-publishedAt > 1000 then view={active=false} end
    if pending and now-pending.at > 1500 then pending=nil;view={active=false} end
    if not pending and now-lastRequest >= 200 and Open77.weapons and type(Open77.weapons.snapshot)=="function" then
        lastRequest=now
        local ok,id=pcall(Open77.weapons.snapshot)
        if ok and id then pending={id=tostring(id),at=now,signature=key,rows={},kit=raidKit()~=nil} end
    end
    return view
end
