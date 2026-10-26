local Db=LightRP.db
local M={records={},subjects={},treatments={},attempts={},internal={},lastRequest={},restoring={}}
LightRP.medical=M
function M.clone(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=M.clone(x)end;return out end
function M.uuid()
 local ok,rows=Db.read("SELECT UUID() AS id")
 return ok and rows[1]and rows[1].id or nil
end
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_medical_deaths (
 inventory_id VARCHAR(96) NOT NULL PRIMARY KEY, token VARCHAR(64) NOT NULL,
 revision INT NOT NULL, status VARCHAR(16) NOT NULL, definition MEDIUMTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_medical_attempts (
 id VARCHAR(64) NOT NULL PRIMARY KEY, actor_inventory VARCHAR(96) NOT NULL,
 patient_inventory VARCHAR(96) NOT NULL, death_token VARCHAR(64) NOT NULL,
 status VARCHAR(16) NOT NULL, definition MEDIUMTEXT NOT NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
function M.load(inv)
 if M.records[inv.id]~=nil then return M.records[inv.id]or nil end
 local ok,rows=Db.read("SELECT token,revision,status,definition FROM lightrp_medical_deaths WHERE inventory_id=?",{inv.id})
 if not ok then return nil,"Medical records are unavailable."end
 if not rows[1]then M.records[inv.id]=false;return nil end
 local decoded,r=pcall(json.decode,rows[1].definition)
 if not decoded or type(r)~="table"or type(r.since)~="number"or type(r.position)~="table"or type(r.position.x)~="number"or type(r.bucket)~="number"then return nil,"Stored medical record is invalid."end
 r.token,r.revision,r.status=rows[1].token,tonumber(rows[1].revision),rows[1].status
 if r.status~="downed"and r.status~="reviving"and r.status~="hospital"then return nil,"Stored medical phase is invalid."end
 M.records[inv.id]=r;return r
end
function M.write(invId,r)
 return {query="UPDATE lightrp_medical_deaths SET revision=?,status=?,definition=? WHERE inventory_id=? AND token=? AND revision=?",values={r.revision,r.status,json.encode(r),invId,r.token,r.revision-1}}
end
-- A NOT NULL guard receipt makes zero-row CAS updates abort the whole SQL
-- transaction. Guard IDs are deterministic and separate from real escrow IDs.
function M.appendWrite(queries,invId,r)
 queries[#queries+1]=M.write(invId,r)
 queries[#queries+1]={query=[[INSERT INTO lightrp_medical_attempts (id,actor_inventory,patient_inventory,death_token,status,definition)
 VALUES (CASE WHEN ROW_COUNT()=1 THEN ? ELSE NULL END,?,?,?,'guard',?)]],
 values={"guard:"..r.token..":"..r.revision,invId,invId,r.token,"{}"}}
 return queries
end
function M.readAttempt(id)
 local ok,rows=Db.read("SELECT status,definition FROM lightrp_medical_attempts WHERE id=?",{id})
 if not ok or not rows[1]then return nil,"Medical treatment receipt is unavailable."end
 local decoded,a=pcall(json.decode,rows[1].definition)
 if not decoded or type(a)~="table"then return nil,"Medical treatment receipt is invalid."end
 a.status=rows[1].status;return a
end
function M.removeRecord(invId,token,extra)
 local queries=extra or{}
 queries[#queries+1]={query="DELETE FROM lightrp_medical_deaths WHERE inventory_id=? AND token=?",values={invId,token}}
 local ok,why=Db.transaction(queries)
 if ok and M.records[invId]and M.records[invId].token==token then M.records[invId]=false end
 return ok,why
end
