-- Each dwelling owns its bucket. Keys, money, storage and every spatial check
-- are authoritative; the page submits IDs/revisions, never prices or positions.
local C, S, Db = LightRpHousing, LightRP.housingStore, LightRP.db
local H = LightRP.module("housing", { sessions = {}, handlers = {} })
local writing, writingPlayers, registeredPoints, streamedFrom = false, {}, {}, {}
local function character(player) return S.identity(player) end
local function current(player, c) return c and LightRP.characters.get(player)==c and GetPlayerName(player)~=nil end
local function property(value) return S.properties[tonumber(value)] end
local function contract(row) return row and row.contract_id and S.contracts[row.contract_id] or nil end
local function template(row) return row and S.templates[row.data.templateId] end
local function now() return math.floor(GetUnixTime()) end
local function bucket(row) return C.bucketBase + row.id end
local function near(player, point, expectedBucket, radius)
    local p = Open77.players.position(player)
    return p and (p.bucket or 0)==expectedBucket and S.distance(p,point)<=(radius or C.interactRadius)+0.75 or false
end
local function activePlayer(player)
    local c, life = character(player), Open77.players.getLifeState(player)
    if not c or (LightRP.characters.switching or {})[player] then return nil,"Finish loading your character first." end
    if not life or life.phase~="alive" then return nil,"You cannot do that right now." end
    if Open77.vehicles.getPlayerSeat(player) then return nil,"Step out of the vehicle first." end
    if LightRP.activities and LightRP.activities.owns(player) then return nil,"Not during an activity or a mission." end
    return c
end
function H.allowed(player)
    return LightRP.staff.allowed(player,C.permission)==true
end
function H.available()
    return C.enabled and Db.ready and S.loaded
end
function H.isBusy(player)
    -- A character must leave their dwelling before switching slots. This also
    -- prevents a switch racing a payment or a streamed relocation.
    return writingPlayers[player]~=nil or H.sessions[player]~=nil
end
function H.withWrite(players, fn)
    if writing then return nil,"Another housing operation is saving. Please retry." end
    writing=true
    for _,player in ipairs(players or {}) do writingPlayers[player]=true end
    local result=table.pack(pcall(fn))
    writing=false; writingPlayers={}
    if not result[1] then LightRP.log("housing operation failed: %s",tostring(result[2]));return nil,"Housing could not complete this operation. Refresh before retrying." end
    return table.unpack(result,2,result.n)
end
function H.hasKey(player, lease)
    local c=character(player)
    if not S.active(lease) or not c then return false end
    if S.owns(lease,c) then return true end
    for _,key in ipairs(lease.data.keys) do
        if key.identifier==c.identifier and key.key==c.key then return true end
    end
    return false
end
function H.savedPosition(player, fallback)
    local s=H.sessions[player]
    return s and s.exterior or fallback
end
local function stashBusy(lease)
    local inv=lease and LightRP.inventory.get("housing:"..lease.id)
    return inv and inv.busy or false
end
local function publicRow(player, row, detail)
    local lease=contract(row)
    local c=character(player)
    local owns=S.active(lease) and S.owns(lease,c)
    return {id=row.id,revision=row.revision,label=row.data.label,kind=row.data.kind,
        entrance=row.data.entrance,price=row.data.price,rent=row.data.rent,rentDays=row.data.rentDays,
        available=not row.contract_id and row.data.enabled and S.templateReady(template(row)),
        enabled=row.data.enabled,owned=owns,hasKey=H.hasKey(player,lease),
        locked=not lease or lease.data.locked,mode=owns and lease.data.mode or nil,
        expires=owns and lease.data.expires or nil,near=near(player,row.data.entrance,0),
        resale=owns and lease.data.mode=="purchase" and math.floor(lease.data.paid*C.resaleFraction) or 0,
        keys=owns and detail and S.clone(lease.data.keys) or nil,
        occupants=owns and #GetPlayersInBucket(bucket(row)) or nil,
        templateLabel=template(row) and template(row).data.label or "Unavailable"}
end
local function page(rows, requested)
    local size=S.integer(C.pageSize,1,10) or 10
    local pages=math.max(1,math.ceil(#rows/size))
    local selected=math.min(pages,S.integer(requested,1,1000000) or 1)
    local values={};for i=(selected-1)*size+1,math.min(#rows,selected*size) do values[#values+1]=rows[i] end
    return values,{page=selected,pages=pages,total=#rows}
end
function H.snapshot(player, admin, options)
    if not H.available() then return nil,"Housing storage is unavailable. Existing homes and belongings are preserved." end
    if admin and not H.allowed(player) then return nil,"Housing administration permission required." end
    local c=character(player)
    if not c then return nil,"Load an active character first." end
    options=type(options)=="table" and options or {}
    local view=options.view or "all"
    local search=(S.text(options.search,80) or ""):lower()
    local function matches(label) return search=="" or tostring(label):lower():find(search,1,true)~=nil end
    local out={properties={},recovery={},templates={},players={},admin=admin==true,canAdmin=H.allowed(player),now=now(),
        defaults={slots=C.defaultSlots,weight=C.defaultWeight,rentDays=C.rentDays},maxInteriorRadius=C.maxInteriorRadius,resaleFraction=C.resaleFraction,
        counts={properties=0,mine=0,nearby=0,available=0,templates=0,recovery=0},pages={}}
    for _,row in pairs(S.properties) do
        local mine=not row.deleted and row.data.starter and (function() local lease=contract(row);return S.owns(lease,c) or H.hasKey(player,lease) end)()
        -- Starter studios are given, never sold: only their residents see them.
        if not row.deleted and (not row.data.starter or admin or mine) then
            local item=publicRow(player,row,row.id==tonumber(options.id))
            out.counts.properties=out.counts.properties+1
            if item.owned or item.hasKey then out.counts.mine=out.counts.mine+1 end
            if item.near then out.counts.nearby=out.counts.nearby+1 end
            if item.available then out.counts.available=out.counts.available+1 end
            if admin then
                item.templateId=row.data.templateId
                item.occupants=#GetPlayersInBucket(bucket(row))
                local lease=contract(row)
                item.tenant=lease and {identifier=lease.identifier,key=lease.character_key,name=lease.data.name,mode=lease.data.mode,expires=lease.data.expires} or nil
            end
            if matches(item.label) and (view~="mine" or item.owned or item.hasKey)
                and (view~="nearby" or item.near) and (view~="available" or item.available) then
                out.properties[#out.properties+1]=item
            end
        end
    end
    table.sort(out.properties,function(a,b)return a.id<b.id end)
    out.properties,out.pages.properties=page(out.properties,options.page)
    local selected=property(options.id)
    if selected and not selected.deleted then
        local found=false;for _,item in ipairs(out.properties) do if item.id==selected.id then found=true end end
        if not found then
            local item=publicRow(player,selected,true)
            if admin then
                item.templateId=selected.data.templateId
                item.occupants=#GetPlayersInBucket(bucket(selected))
                local lease=contract(selected)
                item.tenant=lease and {identifier=lease.identifier,key=lease.character_key,name=lease.data.name,mode=lease.data.mode,expires=lease.data.expires}
            end
            out.properties[#out.properties+1]=item
        end
    end
    for _,lease in pairs(S.contracts) do
        if lease.ended_at>0 and S.owns(lease,c) then
            out.recovery[#out.recovery+1]={id=lease.id,label=lease.data.label,entrance=lease.data.entrance,endedAt=lease.ended_at,
                near=near(player,lease.data.entrance,0),reason=lease.data.endReason}
        end
    end
    table.sort(out.recovery,function(a,b)return a.endedAt>b.endedAt end)
    out.counts.recovery=#out.recovery
    out.recovery,out.pages.recovery=page(out.recovery,options.page)
    if view~="recovery" and view~="all" then out.recovery={} end
    local s=H.sessions[player]
    out.inside=s and {propertyId=s.property,phase=s.phase,label=s.label} or nil
    if admin then
        for _,t in pairs(S.templates) do if not t.deleted then
            out.counts.templates=out.counts.templates+1
            if (view=="templates" or view=="template" or view=="chooseTemplate" or view=="all")
                and (view~="chooseTemplate" or S.templateReady(t)) and (matches(t.data.label) or t.id==options.id) then
            out.templates[#out.templates+1]={id=t.id,revision=t.revision,label=t.data.label,points=S.clone(t.data.points),
                slots=t.data.slots,weight=t.data.weight,ready=S.templateReady(t)}
            end
        end end
        table.sort(out.templates,function(a,b)return a.label<b.label end)
        local detail
        for _,item in ipairs(out.templates) do if item.id==options.id then detail=item end end
        out.templates,out.pages.templates=page(out.templates,options.page)
        if detail then local found=false;for _,item in ipairs(out.templates)do if item.id==detail.id then found=true end end;if not found then out.templates[#out.templates+1]=detail end end
    end
    if (admin and (view=="assign" or view=="all")) or (view=="people" and S.active(contract(property(options.id))) and S.owns(contract(property(options.id)),c)) then
        for _,id in ipairs(GetPlayers()) do
            local target=character(id)
            local name=target and LightRP.characters.displayName(id)
            if target and matches(name) then out.players[#out.players+1]={id=id,name=name,identifier=target.identifier,key=target.key} end
        end
        table.sort(out.players,function(a,b)return a.id<b.id end)
        out.players,out.pages.players=page(out.players,options.page)
    end
    return out
end
-- The homes a character lives in or holds a key to, for its map and GPS
-- (client/core/homes.lua): pushed again after every tenancy or key change.
function H.homes(player)
    local c=character(player)
    local out={}
    if not c or not H.available() then return out end
    for _,row in pairs(S.properties) do
        local lease=contract(row)
        if not row.deleted and S.active(lease) and (S.owns(lease,c) or H.hasKey(player,lease)) then
            out[#out+1]={id=row.id,label=row.data.label,entrance=S.clone(row.data.entrance),owned=S.owns(lease,c),
                building=row.data.starter and C.starter and C.starter.building or nil}
        end
    end
    table.sort(out,function(a,b)return a.id<b.id end)
    return out
end
LightRP.stateProvider("homes",function(player) return H.homes(player) end)
function H.syncHomes()
    for _,id in ipairs(GetPlayers()) do id=tonumber(id);if id and character(id) then LightRP.state(id,"homes") end end
end

function H.open(player, admin)
    local state,why=H.snapshot(player,admin)
    if not state then return false,why end
    LightRP.dialog(player,"housing",{admin=admin==true})
    return true
end
function H.refreshPoints()
    LightRP.batchInteractions(function()
    for id in pairs(registeredPoints) do LightRP.removeInteraction(id) end
    registeredPoints={}
    local function point(id,at,world,label,prompt,blip)
        registeredPoints[id]=true
        LightRP.interaction(id,{position=at,bucket=world,radius=C.interactRadius,label=label,prompt=prompt,key="E",ring=true,
            streamGroup=blip and "housing" or nil,streamLimit=blip and C.visibleEntrances or nil,
            blip=blip and {icon="house",title=label,color="#FFCC00",size=36} or nil})
    end
    local entrances={}
    for _,row in pairs(S.properties) do if not row.deleted and row.data.enabled then
        local p=row.data.entrance
        local key=math.floor(p.x*2+0.5)..":"..math.floor(p.y*2+0.5)..":"..math.floor(p.z*2+0.5)
        local group=entrances[key]
        if not group then entrances[key]={row=row,count=1}
        else group.count=group.count+1;if row.id<group.row.id then group.row=row end end
        local t=template(row)
        if S.templateReady(t) then
            point("housing.exit."..row.id,t.data.points.exit,bucket(row),row.data.label,"Leave home")
            point("housing.stash."..row.id,t.data.points.stash,bucket(row),row.data.label,"Open storage")
            if t.data.points.wardrobe then point("housing.wardrobe."..row.id,t.data.points.wardrobe,bucket(row),row.data.label,"Change outfit") end
        end
    end end
    for _,group in pairs(entrances) do
        local row=group.row
        local label=row.data.starter and C.starter and C.starter.building
            or group.count>1 and ("Homes · "..group.count.." units") or row.data.label
        point("housing.door."..row.id,row.data.entrance,0,label,"View homes",true)
    end
    end)
end

local function relocation(player, s, point, targetBucket, arriving)
    s.phase=arriving and "entering" or "leaving"
    local c=character(player)
    LightRP.inventory.close(player)
    local cover=LightRP.zoneLoading and LightRP.zoneLoading.cover(player,{title=arriving and s.label or "Night City",
        subtitle=arriving and "Private residence" or "Street level",zone=arriving and "Residence" or nil})
    CreateThread(function()
        local promise,why=Open77.players.teleport(player,point,{heading=point.heading or 0,bucket=targetBucket,fade=true,
            timeoutMs=S.integer(C.transitionTimeoutMs,1000,30000) or 30000})
        local placed
        if promise then placed,why=promise:await() end
        if LightRP.zoneLoading then LightRP.zoneLoading.release(player,cover) end
        if H.sessions[player]~=s or not current(player,c) then return end
        if placed and placed~=false and GetPlayerRoutingBucket(player)==targetBucket then
            if arriving then s.phase="inside"
            else H.sessions[player]=nil end
            LightRP.sendInteractions(player)
            LightRP.inventory.refreshHousingAccess()
    H.syncHomes()
            LightRP.notice(player,{kind="info",title=arriving and s.label or "Back in Night City",body=arriving and "Your home is ready." or "You have left the dwelling."})
        else
            s.phase="recovery"
            LightRP.log("housing relocation for %d failed: %s",player,tostring(why))
            LightRP.notice(player,{kind="warning",title="Housing travel",body="The world did not finish loading. F1 > My homes > Leave returns you safely."})
        end
    end)
end
function H.enter(player,row)
    if writing then return nil,"Housing is saving an update. Retry in a moment." end
    local c,why=activePlayer(player)
    if not c then return nil,why end
    if H.sessions[player] then return nil,"Leave your current home first." end
    local lease=contract(row)
    if not row or row.deleted or not row.data.enabled or not S.templateReady(template(row)) or not S.active(lease) then return nil,"This dwelling is unavailable." end
    if not near(player,row.data.entrance,0) then return nil,"Walk to this dwelling's entrance." end
    if lease.data.locked and not H.hasKey(player,lease) then return nil,"The door is locked. Ask the resident for a key." end
    local count=0;for _,s in pairs(H.sessions) do if s.property==row.id then count=count+1 end end
    if count>=C.maxGuests then return nil,"This dwelling is full." end
    local s={property=row.id,contract=lease.id,bucket=bucket(row),exterior=S.clone(row.data.entrance),label=row.data.label,character=c}
    H.sessions[player]=s
    c.lastKnown=S.clone(s.exterior)
    relocation(player,s,template(row).data.points.spawn,s.bucket,true)
    return {message="Entering "..row.data.label..".",close=true}
end
function H.preview(player,t)
    local c,why=activePlayer(player)
    if not c then return nil,why end
    if H.sessions[player] or GetPlayerRoutingBucket(player)~=0 then return nil,"Return to the shared city before previewing an interior." end
    local at=Open77.players.position(player)
    if not at then return nil,"Your position is not available yet." end
    local exterior=S.point({x=at.x,y=at.y,z=at.z,heading=at.yaw or 0})
    local s={preview=true,template=t.id,bucket=C.bucketBase+50000000+player,exterior=exterior,label=t.data.label.." (preview)",character=c}
    if #GetPlayersInBucket(s.bucket)>0 then return nil,"The preview instance is occupied." end
    H.sessions[player]=s;c.lastKnown=S.clone(exterior)
    relocation(player,s,t.data.points.spawn,s.bucket,true)
    return {message="Previewing the interior. F1 > My homes > Leave returns you.",close=true}
end
function H.leave(player, forced)
    local s=H.sessions[player]
    if not s then return nil,"You are not inside a dwelling." end
    if s.phase=="entering" or s.phase=="leaving" then return nil,"Wait for the current transfer to finish." end
    local c,why=activePlayer(player)
    if not c then return nil,why end
    local row=property(s.property)
    if not forced and not s.preview and s.phase~="recovery" and (not row or not near(player,template(row).data.points.exit,s.bucket)) then
        return nil,"Walk to the exit, or use F1 > My homes > Leave if a transition failed."
    end
    relocation(player,s,s.exterior,0,false)
    return {message="Returning to the city.",close=true}
end
-- Straight into a home the character holds a key to, from wherever they are
-- (the end of the first day guide): no walk to the street door.
function H.moveIn(player,row)
    if writing then return nil,"Housing is saving an update. Retry in a moment." end
    local c,why=activePlayer(player)
    if not c then return nil,why end
    if H.sessions[player] then return nil,"Leave your current home first." end
    local lease=contract(row)
    if not row or row.deleted or not S.templateReady(template(row)) or not H.hasKey(player,lease) then return nil,"This dwelling is unavailable." end
    local s={property=row.id,contract=lease.id,bucket=bucket(row),exterior=S.clone(row.data.entrance),label=row.data.label,character=c}
    H.sessions[player]=s
    c.lastKnown=S.clone(s.exterior)
    relocation(player,s,template(row).data.points.spawn,s.bucket,true)
    return true
end

-- Waking up at home: a resident who logged out inside comes back inside.
local function sleeper(c)
    if not C.wakeUpAtHome or not c or not H.available() then return nil end
    for _,lease in pairs(S.contracts) do
        if lease.data.asleep and S.active(lease) and S.owns(lease,c) then
            local row=property(lease.property_id)
            if row and not row.deleted and row.data.enabled~=false and row.contract_id==lease.id and S.templateReady(template(row)) then return row,lease end
        end
    end
end
local function setAsleep(lease,value)
    if not lease or (lease.data.asleep==true)==value then return end
    local edited=S.clone(lease);edited.data.asleep=value or nil
    if Db.transaction({S.contractWrite(edited)}) then S.contracts[lease.id]=edited end
end
-- Asked by server/main.lua for a join: nil keeps the usual rules.
function H.spawnPoint(player)
    local row=sleeper(character(player))
    if not row then return nil end
    local spawn=template(row).data.points.spawn
    return {name="home",position={x=spawn.x,y=spawn.y,z=spawn.z},heading=spawn.heading or 0,bucket=bucket(row),home=row.id}
end
-- The join placement put them inside: open the session that lets them out.
function H.arrived(player,point)
    local c=character(player)
    local row,lease=sleeper(c)
    if not row or row.id~=point.home or H.sessions[player] then return end
    local s={property=row.id,contract=lease.id,bucket=bucket(row),exterior=S.clone(row.data.entrance),label=row.data.label,character=c,phase="entering"}
    H.sessions[player]=s
    c.lastKnown=S.clone(s.exterior)
    setAsleep(lease,false)
    CreateThread(function()
        -- The respawn applies the bucket with the body; wait for both.
        for _=1,40 do
            if H.sessions[player]~=s or not current(player,c) then return end
            local life=Open77.players.getLifeState(player)
            if GetPlayerRoutingBucket(player)==s.bucket and life and life.phase=="alive" then
                s.phase="inside"
                LightRP.sendInteractions(player)
                LightRP.inventory.refreshHousingAccess()
    H.syncHomes()
                LightRP.notice(player,{kind="info",title=s.label,body="Welcome home."})
                return
            end
            Wait(250)
        end
        if H.sessions[player]==s then s.phase="recovery" end
    end)
end
local function canUseStorage(player,lease,deposit)
    local c=character(player)
    if not c or not H.available() then return false end
    local life=Open77.players.getLifeState(player)
    if not life or life.phase~="alive" or (LightRP.characters.switching or {})[player] then return false end
    if lease.ended_at>0 then return not deposit and S.owns(lease,c) and near(player,lease.data.entrance,0,C.stashRadius) end
    local row=property(lease.property_id)
    local s=H.sessions[player]
    return row and row.contract_id==lease.id and s and s.phase=="inside" and s.contract==lease.id
        and H.hasKey(player,lease) and near(player,template(row).data.points.stash,s.bucket,C.stashRadius) or false
end
function H.openStorage(player,lease)
    if not lease then return nil,"Storage not found." end
    local function access(id,deposit)
        return canUseStorage(id,S.contracts[lease.id] or lease,deposit)
    end
    local boundary=utf8.offset(lease.data.label,51)
    local label=boundary and lease.data.label:sub(1,boundary-1) or lease.data.label
    local ok,why=LightRP.inventory.openHousingStash(player,lease.id,label.." storage",lease.data.slots,lease.data.weight,access)
    if not ok then return nil,"Storage unavailable: "..tostring(why) end
    return {message="Storage opened.",close=true}
end

local function revision(row,p)
    return row and not row.deleted and tonumber(p.revision)==row.revision
end
local function commit(player,amount,writes,apply,kind,label,method)
    if amount~=0 then
        local ok,why=LightRP.money.exchange(player,method or "bank",amount,writes,apply,kind,label,"Night City Housing")
        return ok,ok and nil or LightRP.money.explain(why)
    end
    local ok=Db.transaction(writes)
    if ok then apply() end
    return ok,ok and nil or "Housing could not be saved. Nothing changed."
end
function H.acquire(player,row,mode,target)
    local c=target or character(player)
    if not c then return nil,"No active character." end
    if not row or row.deleted or row.contract_id or not row.data.enabled or not S.templateReady(template(row)) then return nil,"This home is no longer available." end
    local amount=mode=="purchase" and row.data.price or mode=="rent" and row.data.rent or 0
    if mode~="assigned" and amount<=0 then return nil,"This offer is disabled." end
    local count=0;for _,lease in pairs(S.contracts) do if S.active(lease) and S.owns(lease,c) then count=count+1 end end
    if count>=C.maxOwned then return nil,"This character has reached the housing limit." end
    local id=S.uuid()
    if not id then return nil,"Housing storage is unavailable." end
    if not target and (not current(player,c) or not near(player,row.data.entrance,0)) then return nil,"Your character or location changed. Nothing was charged." end
    local t=template(row)
    local lease={id=id,property_id=row.id,identifier=c.identifier,character_key=c.key,ended_at=0,
        data={mode=mode,name=target and target.displayName or LightRP.characters.displayName(player),paid=amount,started=now(),
            expires=mode=="rent" and now()+row.data.rentDays*86400 or nil,keys={},locked=true,
            label=row.data.label,entrance=S.clone(row.data.entrance),slots=t.data.slots,weight=t.data.weight}}
    local updated=S.clone(row);updated.contract_id=id;updated.revision=updated.revision+1
    local writes={S.contractWrite(lease,true),S.propertyWrite(updated),S.audit(GetPlayerIdentifier(player),"housing."..mode,row.id,c.identifier.."#"..c.key)}
    local ok,why=commit(player,-amount,writes,function() S.properties[row.id]=updated;S.contracts[id]=lease end,
        "housing_"..mode,row.data.label,"bank")
    if not ok then return nil,why end
    LightRP.inventory.refreshHousingAccess()
    H.syncHomes()
    return {message=mode=="rent" and "Lease started. Rent is prepaid; renew before it expires." or "Dwelling assigned to your character."}
end
function H.retire(player,row,reason,refund)
    local lease=contract(row)
    if not lease then return nil,"This dwelling is already vacant." end
    if stashBusy(lease) then return nil,"Someone is moving an item. Retry in a moment." end
    for _,s in pairs(H.sessions) do
        if s.property==row.id and (s.phase=="entering" or s.phase=="leaving") then return nil,"Wait for residents to finish travelling." end
    end
    local retired=S.clone(lease);retired.ended_at=now();retired.data.endReason=reason
    local updated=S.clone(row);updated.contract_id=nil;updated.revision=updated.revision+1
    local writes={S.contractWrite(retired),S.propertyWrite(updated),S.audit(player and GetPlayerIdentifier(player) or "system","housing.end",row.id,reason..": "..lease.identifier.."#"..lease.character_key)}
    local ok,why=commit(player,refund or 0,writes,function() S.properties[row.id]=updated;S.contracts[lease.id]=retired end,"housing_sale",row.data.label,"bank")
    if not ok then return nil,why end
    LightRP.inventory.refreshHousingAccess()
    H.syncHomes()
    for id,s in pairs(H.sessions) do if s.property==row.id then H.leave(id,true) end end
    return {message="Dwelling released. Stored belongings can be recovered at its former entrance from My homes."}
end
function H.renew(player,row)
    local lease=contract(row)
    if not lease or lease.data.mode~="rent" or not S.active(lease) then return nil,"There is no active rental to renew." end
    if row.data.rent<=0 then return nil,"Renewal is disabled. Contact the owner." end
    local expiry=lease.data.expires+row.data.rentDays*86400
    if expiry>now()+C.maxRentAheadDays*86400 then return nil,"You have prepaid the maximum rental period." end
    local renewed=S.clone(lease);renewed.data.expires=expiry
    local updated=S.clone(row);updated.revision=updated.revision+1
    local ok,why=commit(player,-row.data.rent,{S.contractWrite(renewed),S.propertyWrite(updated),S.audit(GetPlayerIdentifier(player),"housing.renew",row.id,tostring(expiry))},
        function() S.contracts[lease.id]=renewed;S.properties[row.id]=updated end,"housing_rent",row.data.label,"bank")
    return ok and {message="Rent renewed for "..row.data.rentDays.." days."} or nil,why
end
function H.ownerAction(player,row,p)
    local lease=contract(row)
    if not S.active(lease) or not S.owns(lease,character(player)) then return nil,"Only the resident can manage this dwelling." end
    if p.action=="renew" then return H.renew(player,row) end
    if p.action=="release" then return H.retire(player,row,"released",0) end
    if p.action=="sell" then
        if lease.data.mode~="purchase" then return nil,"Only a purchased home can be sold." end
        return H.retire(player,row,"sold",math.floor(lease.data.paid*C.resaleFraction))
    end
    local edited=S.clone(lease)
    if p.action=="lock" then
        if type(p.locked)~="boolean" then return nil,"Choose the lock state." end
        edited.data.locked=p.locked
    elseif p.action=="key.add" then
        if #edited.data.keys>=C.maxKeys then return nil,"Too many spare keys." end
        local target=tonumber(p.player);local c=target and character(target)
        if not c or c.identifier~=p.identifier or c.key~=p.character then return nil,"The selected character changed. Refresh the list." end
        if S.owns(lease,c) then return nil,"The resident already has a key." end
        for _,key in ipairs(edited.data.keys) do if key.identifier==c.identifier and key.key==c.key then return nil,"This character already has a key." end end
        edited.data.keys[#edited.data.keys+1]={identifier=c.identifier,key=c.key,name=LightRP.characters.displayName(target)}
    elseif p.action=="key.remove" then
        local removed=false
        for i,key in ipairs(edited.data.keys) do if key.identifier==p.identifier and key.key==p.character then table.remove(edited.data.keys,i);removed=true;break end end
        if not removed then return nil,"Key not found." end
    else return nil,"Unknown housing operation." end
    local updated=S.clone(row);updated.revision=updated.revision+1
    local ok=Db.transaction({S.contractWrite(edited),S.propertyWrite(updated),S.audit(GetPlayerIdentifier(player),"housing."..p.action,row.id,p.identifier or tostring(p.locked))})
    if not ok then return nil,"The access change could not be saved." end
    S.contracts[lease.id]=edited;S.properties[row.id]=updated
    LightRP.inventory.refreshHousingAccess()
    H.syncHomes()
    return {message="Dwelling access updated."}
end

function H.handle(player,p)
    if not H.available() then return nil,"Housing storage is unavailable. Please retry shortly." end
    if p.action=="browse" then
        local allowed={root=true,nearby=true,mine=true,available=true,properties=true,property=true,templates=true,template=true,recovery=true,keys=true,people=true,assign=true,chooseTemplate=true}
        local options=S.clone(p);if not allowed[options.view] then options.view="root" end
        return H.snapshot(player,p.admin==true,options)
    end
    if p.action=="occupants" then
        local row=property(p.id);local lease=contract(row)
        if not S.owns(lease,character(player)) then return nil,"Resident access required." end
        local people={};for _,id in ipairs(GetPlayers()) do local c=character(id);if c then people[#people+1]={id=id,identifier=c.identifier,key=c.key,name=LightRP.characters.displayName(id)} end end
        local values,info=page(people,p.page)
        return {players=values,page=info}
    end
    local c,why=activePlayer(player)
    if not c then return nil,why end
    if p.action=="leave" then return H.leave(player,false) end
    if p.action=="enter" then return H.enter(player,property(p.id)) end
    if p.action=="recover" then
        local lease=S.contracts[p.contract]
        if not lease or lease.ended_at==0 or not S.owns(lease,c) then return nil,"No belongings to recover." end
        return H.openStorage(player,lease)
    end
    if p.action=="stash" then return H.openStorage(player,contract(property(p.id))) end
    local players={player};if tonumber(p.player) then players[#players+1]=tonumber(p.player) end
    return H.withWrite(players,function()
        if type(p.action)=="string" and p.action:sub(1,6)=="admin." then
            if not H.allowed(player) then return nil,"Housing administration permission required." end
            local fn=H.handlers[p.action]
            if not fn then return nil,"Unknown housing administration operation." end
            return fn(player,p)
        end
        local row=property(p.id)
        if not revision(row,p) then return nil,"This dwelling changed. Refresh before confirming." end
        if p.action=="buy" or p.action=="rent" then
            if not near(player,row.data.entrance,0) then return nil,"Walk to the dwelling's entrance to sign." end
            return H.acquire(player,row,p.action=="buy" and "purchase" or "rent")
        end
        return H.ownerAction(player,row,p)
    end)
end

function H.onInteract(player,id)
    local action,value=id:match("^housing%.(%w+)%.(%d+)$")
    local row=property(value)
    if not action or not row then return end
    local result,why
    if action=="door" then result,why=H.open(player,false)
    elseif action=="exit" then result,why=H.leave(player,false)
    elseif action=="stash" then result,why=H.openStorage(player,contract(row))
    elseif action=="wardrobe" then
        local s=H.sessions[player]
        if s and s.property==row.id and s.phase=="inside" and H.hasKey(player,contract(row)) then result,why=LightRP.wardrobe.open(player)
        else why="Only residents and key holders can use this wardrobe." end
    end
    if not result then LightRP.result(player,false,why or "Access denied.","housing") end
end
function H.onDatabaseReady()
    local ok,why=S.load()
    if not ok then LightRP.log("housing disabled: %s",why);return end
    H.refreshPoints()
    LightRP.log("housing storage ready")
end
local function forget(player,restoreBucket)
    local s=H.sessions[player]
    if not s then return end
    local c=LightRP.characters.get(player)
    if c==s.character then c.lastKnown=S.clone(s.exterior) end
    LightRP.inventory.close(player)
    H.sessions[player]=nil
    if restoreBucket and GetPlayerRoutingBucket(player)==s.bucket then SetPlayerRoutingBucket(player,0) end
    if restoreBucket then LightRP.sendInteractions(player) end
end
function H.onDisconnected(player)
    local s=H.sessions[player]
    local lease=s and not s.preview and s.phase=="inside" and S.contracts[s.contract]
    if lease and S.active(lease) and S.owns(lease,s.character) then setAsleep(lease,true) end
    forget(player,false);streamedFrom[player]=nil
end
function H.onCharacterLoaded(player) forget(player,true) end
function H.onLifeState(player,phase)
    if phase=="dead" then forget(player,true) end
end
CreateThread(function()
    while true do
        Wait(2000)
        if H.available() then
            for _,id in ipairs(GetPlayers()) do
                local at=Open77.players.position(id)
                if at and at.bucket==0 and S.distance(at,streamedFrom[id])>C.entranceRefreshDistance then
                    streamedFrom[id]=S.clone(at);LightRP.sendInteractions(id)
                end
            end
            for _,row in pairs(S.properties) do
                local lease=contract(row)
                if lease and lease.ended_at==0 and not S.active(lease) then
                    H.withWrite({},function() return H.retire(nil,row,"expired",0) end)
                end
            end
            for player,s in pairs(H.sessions) do
                if s.phase=="inside" then
                    local row=property(s.property)
                    if GetPlayerRoutingBucket(player)~=s.bucket then forget(player,false);LightRP.sendInteractions(player)
                    elseif not s.preview and (not row or row.contract_id~=s.contract or not S.active(contract(row))) then H.leave(player,true) end
                end
            end
        end
    end
end)
AddEventHandler("onResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    for player,s in pairs(H.sessions) do
        local c=LightRP.characters.get(player);if c==s.character then c.lastKnown=S.clone(s.exterior) end
        Open77.players.teleport(player,s.exterior,{heading=s.exterior.heading,bucket=0,timeoutMs=30000})
    end
end)
LightRP.action("housing.open",function(player,p)
    local ok,why=H.open(player,p.admin==true)
    if not ok then LightRP.result(player,false,why,"housing.open") end
end)
-- No /housing: F1 > My homes opens the menu, and its Leave entry also ends a stuck transfer.
LightRP.command("housingadmin",{},function(player) return H.open(player,true) end)
LightRP.admin.handlers.housing=H.handle
