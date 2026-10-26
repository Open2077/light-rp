local G,Db=LightRpSafezoneGeometry,LightRP.db
local S={records={},generation=0,ready=false,available=false,writing=false}
LightRP.safezones=S
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_safezones (
 id VARCHAR(64) NOT NULL PRIMARY KEY, definition MEDIUMTEXT NOT NULL,
 revision INT NOT NULL, deleted TINYINT NOT NULL DEFAULT 0,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_safezones_audit (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, actor VARCHAR(128) NOT NULL,
 mutation VARCHAR(96) NOT NULL, action VARCHAR(16) NOT NULL, zone_id VARCHAR(64) NOT NULL,
 result MEDIUMTEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY safezone_mutation (actor,mutation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
function S.allowed(player,verb)
    if not player or player<=0 or type(Open77.acl)~="table" or type(Open77.acl.isAllowed)~="function" then return false end
    local ok,value=pcall(Open77.acl.isAllowed,player,"command.admin.safezones."..verb)
    return ok and value==true
end
function S.permissions(player)
    local p={};for _,verb in ipairs({"view","edit","publish","delete"}) do p[verb]=S.allowed(player,verb) end;return p
end
function S.list()
    local list={};for _,z in pairs(S.records) do if not z.deleted then list[#list+1]=G.clone(z) end end
    table.sort(list,function(a,b) return a.label==b.label and a.id<b.id or a.label<b.label end)
    return list
end
function S.actor(player)
    local actor=GetPlayerIdentifier(player)
    if type(actor)~="string" or #actor==0 or #actor>128 then return nil end
    return actor
end
function S.previous(actor,mutation,action,id)
    local ok,rows=Db.read("SELECT action,zone_id,result FROM lightrp_safezones_audit WHERE actor=? AND mutation=?",{actor,mutation})
    if not ok then return nil,"Safezone storage is unavailable." end
    if not rows[1] then return false end
    if rows[1].action~=action or (id and id~="" and rows[1].zone_id~=id) then return nil,"This request key was already used for a different operation." end
    local valid,result=pcall(json.decode,rows[1].result)
    if not valid or type(result)~="table" then return nil,"Stored request result is invalid." end
    return result
end
function S.persist(actor,mutation,action,zone,baseRevision)
    local old=S.records[zone.id]
    local deleted=action=="delete"
    local result=deleted and {id=zone.id} or {zone=G.clone(zone)}
    local query
    if old then
        query={query="UPDATE lightrp_safezones SET definition=?,revision=?,deleted=? WHERE id=? AND revision=?",values={json.encode(zone),zone.revision,deleted and 1 or 0,zone.id,baseRevision}}
    else
        query={query="INSERT INTO lightrp_safezones (id,definition,revision,deleted) VALUES (?,?,?,0)",values={zone.id,json.encode(zone),zone.revision}}
    end
    -- ROW_COUNT is evaluated on the transaction connection immediately after
    -- the versioned write. A lost SQL CAS inserts NULL into NOT NULL actor,
    -- aborting and rolling back the whole transaction instead of publishing a
    -- cache update whose zone write silently affected zero rows.
    local ok=Db.transaction({query,{query="INSERT INTO lightrp_safezones_audit (actor,mutation,action,zone_id,result) VALUES (CASE WHEN ROW_COUNT()=1 THEN ? ELSE NULL END,?,?,?,?)",values={actor,mutation,action,zone.id,json.encode(result)}}})
    if not ok then return nil,"Safezone storage refused the change. Nothing was published." end
    zone.deleted=deleted
    S.records[zone.id]=zone
    S.generation=S.generation+1
    return result
end
function S.load()
    local ok,rows=Db.read("SELECT id,definition,revision,deleted FROM lightrp_safezones")
    if not ok then return false,"Safezone storage is unavailable." end
    local records={}
    local count=0
    for _,row in ipairs(rows) do
        local decoded,data=pcall(json.decode,row.definition)
        local zone,why
        if decoded then zone,why=G.validate(data) end
        if not zone or zone.id~=row.id or not G.integer(tonumber(row.revision),1,2147483647) then return false,"Invalid stored safezone "..tostring(row.id)..": "..tostring(why) end
        zone.revision=tonumber(row.revision);zone.deleted=tonumber(row.deleted)==1
        records[zone.id]=zone
        if not zone.deleted then count=count+1 end
    end
    if count>G.MAX_ZONES then return false,"Stored safezone count exceeds limit." end
    S.records=records;S.generation=S.generation+1
    return true
end
