-- Live authoring. Captured coordinates come from the authenticated player's
-- server snapshot; edits are revision-checked, audited and persisted first.
local H,S,Db,C=LightRP.housing,LightRP.housingStore,LightRP.db,LightRpHousing
local handlers=H.handlers
local function actor(player) return GetPlayerIdentifier(player) end
local function changed(kind,row)
    if kind=="template" then S.templates[row.id]=row else S.properties[row.id]=row end
    H.refreshPoints()
end
local function save(player,kind,row,insert,action)
    local write=kind=="template" and S.templateWrite(row,insert) or S.propertyWrite(row,insert)
    local ok=Db.transaction({write,S.audit(actor(player),action or ("housing."..kind..".save"),row.id,row.data.label)})
    if not ok then return nil,"Housing storage refused the change. Nothing was changed." end
    changed(kind,row)
    return {message=kind=="template" and "Interior template saved." or "Dwelling saved.",id=row.id}
end
local function template(p)
    local row=S.templates[p.id]
    if not row or row.deleted or tonumber(p.revision)~=row.revision then return nil,"This template changed. Refresh before editing." end
    return row
end
local function property(p)
    local row=S.properties[tonumber(p.id)]
    if not row or row.deleted or tonumber(p.revision)~=row.revision then return nil,"This dwelling changed. Refresh before editing." end
    return row
end
local function occupied(row)
    for _,s in pairs(H.sessions) do if s.property==row.id then return true end end
    return #GetPlayersInBucket(C.bucketBase+row.id)>0
end
local function templateOccupied(t)
    for _,row in pairs(S.properties) do if row.data.templateId==t.id and occupied(row) then return true end end
    return false
end
local function capture(player,world)
    local p=Open77.players.position(player)
    if not p or (world and (p.bucket or 0)~=0) then return nil,"Place yourself at the exterior entrance in the shared city first." end
    return S.point({x=p.x,y=p.y,z=p.z,heading=p.yaw or p.heading or 0})
end
local function requestKey(player,p)
    local key=S.text(p.mutation,96)
    if not key or not key:match("^[%w:_%-]+$") then return nil end
    return tostring(actor(player))..":"..key
end
local function duplicate(rows,key)
    for _,row in pairs(rows) do if row.data.requestKey==key then return {message="This creation was already saved.",id=row.id} end end
end
handlers["admin.template.create"]=function(player,p)
    local key=requestKey(player,p)
    if not key then return nil,"Invalid creation request." end
    local previous=duplicate(S.templates,key);if previous then return previous end
    local label=S.text(p.label,80)
    local slots=S.integer(p.slots,1,200)
    local weight=S.integer(p.weight,1,10000)
    if not label or not slots or not weight then return nil,"Enter a name, 1–200 slots and 1–10000 kg of storage." end
    local total=0;for _,t in pairs(S.templates) do if not t.deleted then total=total+1 end end
    if total>=C.maxProperties then return nil,"Too many interior templates." end
    local id=S.uuid()
    if not id or not GetPlayerName(player) then return nil,"Creation could not finish. Please retry." end
    return save(player,"template",{id=id,revision=1,deleted=false,data={label=label,slots=slots,weight=weight,points={},requestKey=key}},true)
end
handlers["admin.template.update"]=function(player,p)
    local row,why=template(p);if not row then return nil,why end
    if templateOccupied(row) then return nil,"Everyone must leave the template's dwellings before changing it." end
    local label,slots,weight=S.text(p.label,80),S.integer(p.slots,1,200),S.integer(p.weight,1,10000)
    if not label or not slots or not weight then return nil,"Invalid name or storage capacity." end
    local edited=S.clone(row);edited.revision=edited.revision+1
    edited.data.label,edited.data.slots,edited.data.weight=label,slots,weight
    return save(player,"template",edited,false)
end
handlers["admin.template.capture"]=function(player,p)
    local row,why=template(p);if not row then return nil,why end
    if templateOccupied(row) then return nil,"Move residents outside before moving interior points." end
    if p.point~="spawn" and p.point~="exit" and p.point~="stash" and p.point~="wardrobe" then return nil,"Choose spawn, exit, storage or wardrobe." end
    local at,message=capture(player,false)
    if not at then return nil,message end
    local edited=S.clone(row);edited.revision=edited.revision+1
    if p.point=="wardrobe" and p.clear==true then edited.data.points.wardrobe=nil
    else edited.data.points[p.point]=at end
    local spawn=edited.data.points.spawn
    if spawn then for _,point in pairs(edited.data.points) do
        if S.distance(spawn,point)>C.maxInteriorRadius then return nil,"Interior points must remain within "..C.maxInteriorRadius.." m of the spawn." end
    end end
    return save(player,"template",edited,false,"housing.point."..p.point)
end
handlers["admin.template.delete"]=function(player,p)
    local row,why=template(p);if not row then return nil,why end
    for _,home in pairs(S.properties) do if not home.deleted and home.data.templateId==row.id then return nil,"Remove or reassign this template's dwellings first." end end
    local edited=S.clone(row);edited.deleted=true;edited.revision=edited.revision+1
    return save(player,"template",edited,false,"housing.template.delete")
end
handlers["admin.template.preview"]=function(player,p)
    local row,why=template(p);if not row then return nil,why end
    if not row.data.points.spawn then return nil,"Capture the interior spawn first." end
    return H.preview(player,row)
end
local function propertyDefinition(p,old)
    local label=S.text(p.label,80)
    local t=S.templates[p.templateId]
    local price,rent,days=S.integer(p.price,0,1000000000),S.integer(p.rent,0,1000000000),S.integer(p.rentDays,1,90)
    if not label or not S.templateReady(t) or not price or not rent or not days
        or (p.kind~="apartment" and p.kind~="house") or type(p.enabled)~="boolean" then
        return nil,"Choose a completed template, a name, a dwelling type, prices and a 1–90 day rental period."
    end
    return {label=label,kind=p.kind,templateId=t.id,price=price,rent=rent,rentDays=days,enabled=p.enabled,entrance=old and S.clone(old.entrance)}
end
handlers["admin.property.create"]=function(player,p)
    local key=requestKey(player,p)
    if not key then return nil,"Invalid creation request." end
    local previous=duplicate(S.properties,key);if previous then return previous end
    local data,why=propertyDefinition(p)
    if not data then return nil,why end
    local entry,message=capture(player,true)
    if not entry then return nil,message end
    local count=0;for _,row in pairs(S.properties) do if not row.deleted and not row.data.starter then count=count+1 end end
    if count>=C.maxProperties or S.nextId>C.maxProperties*10000 then return nil,"The dwelling limit has been reached." end
    data.entrance,data.requestKey=entry,key
    local id=S.nextId;S.nextId=id+1
    return save(player,"property",{id=id,revision=1,deleted=false,data=data},true)
end
handlers["admin.property.update"]=function(player,p)
    local row,why=property(p);if not row then return nil,why end
    local data,message=propertyDefinition(p,row.data)
    if not data then return nil,message end
    if row.contract_id and (data.templateId~=row.data.templateId or data.enabled~=row.data.enabled) then return nil,"Revoke the tenancy before changing the interior or disabling the dwelling." end
    if occupied(row) then return nil,"Wait until the dwelling is empty before editing it." end
    local edited=S.clone(row);edited.data=data;edited.data.requestKey=row.data.requestKey;edited.revision=edited.revision+1
    return save(player,"property",edited,false)
end
handlers["admin.property.capture"]=function(player,p)
    local row,why=property(p);if not row then return nil,why end
    if row.contract_id or occupied(row) then return nil,"The dwelling must be vacant before its exterior entrance can move." end
    local at,message=capture(player,true);if not at then return nil,message end
    local edited=S.clone(row);edited.data.entrance=at;edited.revision=edited.revision+1
    return save(player,"property",edited,false,"housing.entrance.move")
end
handlers["admin.property.delete"]=function(player,p)
    local row,why=property(p);if not row then return nil,why end
    if row.contract_id or occupied(row) then return nil,"Revoke the tenancy and let everyone leave before deleting this dwelling." end
    local edited=S.clone(row);edited.deleted=true;edited.revision=edited.revision+1
    return save(player,"property",edited,false,"housing.property.delete")
end
handlers["admin.assign"]=function(player,p)
    local row,why=property(p);if not row then return nil,why end
    local identifier,key=S.text(p.identifier,128),S.text(p.character,64)
    if not identifier or not key then return nil,"Select an active character." end
    local ok,rows=Db.read("SELECT first_name,last_name,status FROM lightrp_characters WHERE identifier=? AND character_key=?",{identifier,key})
    if not ok or not rows[1] or rows[1].status~="active" then return nil,"Active character not found." end
    return H.acquire(player,row,"assigned",{identifier=identifier,key=key,status="active",displayName=(rows[1].first_name or "").." "..(rows[1].last_name or "")})
end
handlers["admin.revoke"]=function(player,p)
    local row,why=property(p);if not row then return nil,why end
    local reason=S.text(p.reason,160)
    if not reason or #reason<4 then return nil,"Give a reason for revoking this tenancy." end
    return H.retire(player,row,"admin: "..reason,0)
end
