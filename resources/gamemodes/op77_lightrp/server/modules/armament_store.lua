local Db,C=LightRP.db,LightRpArmament
local W={states={},runtime={},pending={},serialOwners={},loaded=false}
LightRP.armament=W
function W.clone(v) if type(v)~="table" then return v end;local t={};for k,x in pairs(v) do t[k]=W.clone(x) end;return t end
function W.integer(n,lo,hi) return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=hi end
function W.uuid()
    local ok,rows=Db.read("SELECT UUID() AS id")
    return ok and rows[1] and type(rows[1].id)=="string" and rows[1].id or nil
end
function W.validId(id) return type(id)=="string" and #id>=8 and #id<=64 and id:match("^[%w_-]+$")~=nil end
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_armament (
 inventory_id VARCHAR(96) NOT NULL PRIMARY KEY, revision INT NOT NULL,
 definition MEDIUMTEXT NOT NULL, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_weapon_instances (
 instance_id VARCHAR(64) NOT NULL PRIMARY KEY, inventory_id VARCHAR(96) NOT NULL,
 item_name VARCHAR(64) NOT NULL, retired TINYINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_weapon_instance_audit (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, instance_id VARCHAR(64) NOT NULL,
 source_inventory VARCHAR(96) NOT NULL, target_inventory VARCHAR(96) NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_armament_operations (
 inventory_id VARCHAR(96) NOT NULL, mutation VARCHAR(96) NOT NULL,
 operation VARCHAR(16) NOT NULL, revision INT NOT NULL,
 PRIMARY KEY (inventory_id,mutation), created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
function W.stateWrite(id,s)
    return {query=[[INSERT INTO lightrp_armament (inventory_id,revision,definition) VALUES (?,?,?)
     ON DUPLICATE KEY UPDATE revision=VALUES(revision),definition=VALUES(definition)]],values={id,s.revision,json.encode(s)}}
end
function W.load(inv)
    if W.states[inv.id] then return W.states[inv.id] end
    if not Db.ready then return nil,"Armament storage is unavailable." end
    local ok,rows=Db.read("SELECT revision,definition FROM lightrp_armament WHERE inventory_id=?",{inv.id})
    if not ok then return nil,"Armament storage could not be read." end
    local s={revision=0,ammo=0}
    if rows[1] then
        local decoded,value=pcall(json.decode,rows[1].definition)
        if not decoded or type(value)~="table" or not W.integer(value.ammo,0,C.maxAmmo) or not W.integer(tonumber(rows[1].revision),0,2147483646) then return nil,"Stored armament data is invalid." end
        s={revision=tonumber(rows[1].revision),ammo=value.ammo,right=value.right,left=value.left}
        if (s.right and not W.validId(s.right)) or (s.left and (not W.validId(s.left) or s.left==s.right or not s.right)) then return nil,"Stored weapon loadout is invalid." end
    end
    W.states[inv.id]=s
    return s
end
local function collect(inv,draft,allowMint)
    local found={}
    for slot,item in pairs(draft.items) do
        if C.weapons[item.name] then
            if not inv.persistent then return nil,"Firearms can only be stored in durable inventories. Ground piles and temporary trunks are unavailable." end
            if item.count~=1 then return nil,"Serialized firearms cannot stack." end
            local meta=type(item.metadata)=="table" and W.clone(item.metadata) or {}
            local id=meta.instanceId
            if not id and allowMint then id=W.uuid();if not id then return nil,"Could not allocate a firearm serial." end end
            if not W.validId(id) then return nil,"This firearm has no valid server serial." end
            if found[id] then return nil,"A firearm serial appears more than once." end
            meta.instanceId=id;item.metadata=meta
            found[id]={slot=slot,name=item.name,inventory=inv.id}
        end
    end
    return found
end
-- Called within the inventory's ordinary locks. Its extra writes share the
-- inventory transaction; no owner cache changes until onCommitted is called.
function W.prepare(changes)
    local before,after,invById={},{},{}
    for _,change in ipairs(changes) do
        local inv,draft=change[1],change[2];invById[inv.id]=inv
        local old,why=collect(inv,{items=W.clone(inv.items)},false)
        if not old then return false,why end
        local new,reason=collect(inv,draft,true)
        if not new then return false,reason end
        for id,item in pairs(old) do if before[id] then return false,"Duplicate existing firearm serial." end;before[id]=item end
        for id,item in pairs(new) do if after[id] then return false,"A firearm cannot be duplicated between inventories." end;after[id]=item end
    end
    local queries,owners={},{ }
    local touched={};for id in pairs(before) do touched[id]=true end;for id in pairs(after) do touched[id]=true end
    for id in pairs(touched) do
        local a,b=before[id],after[id]
        if a and b and a.name~=b.name then return false,"A firearm serial cannot change its model." end
        if not a or not b or a.inventory~=b.inventory then
            if a then
                local s=W.states[a.inventory]
                if not s and invById[a.inventory].kind=="player" then s=W.load(invById[a.inventory]);if not s then return false,"The firearm loadout could not be read." end end
                if s and (s.right==id or s.left==id) then return false,"Unequip this firearm before transferring, selling or removing it." end
                for _,rt in pairs(W.runtime) do if rt.inventory==a.inventory and rt.busy then return false,"Weapon synchronization is in progress." end end
            end
            local ok,rows=Db.read("SELECT inventory_id,item_name,retired FROM lightrp_weapon_instances WHERE instance_id=?",{id})
            if not ok then return false,"Firearm serial storage is unavailable." end
            local row=rows[1]
            if a then
                if not row or tonumber(row.retired)~=0 or row.inventory_id~=a.inventory or row.item_name~=a.name then return false,"Firearm ownership could not be verified." end
                queries[#queries+1]={query="UPDATE lightrp_weapon_instances SET inventory_id=?,retired=? WHERE instance_id=? AND inventory_id=? AND retired=0",values={b and b.inventory or "",b and 0 or 1,id,a.inventory}}
            else
                if row then return false,"This firearm serial already exists." end
                queries[#queries+1]={query="INSERT INTO lightrp_weapon_instances (instance_id,inventory_id,item_name,retired) VALUES (?,?,?,0)",values={id,b.inventory,b.name}}
            end
            queries[#queries+1]={query="INSERT INTO lightrp_weapon_instance_audit (instance_id,source_inventory,target_inventory) VALUES (CASE WHEN ROW_COUNT()=1 THEN ? ELSE NULL END,?,?)",values={id,a and a.inventory or "",b and b.inventory or ""}}
            owners[id]=b and b.inventory or false
        end
    end
    return true,nil,queries,function() for id,owner in pairs(owners) do W.serialOwners[id]=owner end end
end
function W.find(inv,id)
    for slot,item in pairs(inv.items) do if C.weapons[item.name] and item.count==1 and type(item.metadata)=="table" and item.metadata.instanceId==id then return item,slot end end
end
