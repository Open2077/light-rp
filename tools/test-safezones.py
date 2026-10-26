"""Run the real safezone Lua modules against an isolated in-memory host/SQL adapter.
Requires lupa (Lua 5.4). No server.env or production connection is used.
"""
from pathlib import Path
import json
import os
import time
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
sql_connection = None
sql_database = None

def to_lua(value):
    if isinstance(value, (list, dict)):
        return lua.table_from({(i + 1): to_lua(v) for i, v in enumerate(value)} if isinstance(value, list) else {k: to_lua(v) for k, v in value.items()})
    return value

def from_lua(value):
    if hasattr(value, "items"):
        items = dict(value.items())
        if items and all(isinstance(k, int) for k in items) and set(items) == set(range(1, len(items) + 1)):
            return [from_lua(items[i]) for i in range(1, len(items) + 1)]
        return {k: from_lua(v) for k, v in items.items()}
    return value

lua.globals().python_encode = lambda v: json.dumps(from_lua(v))
lua.globals().python_decode = lambda v: to_lua(json.loads(v))
lua.execute(r'''
json={encode=python_encode,decode=python_decode}
clock=10;source=1;events={};threads={};messages={};modules={};commands={};permissions={};positions={};bucket={};sqlRows={};audits={};failTransaction=false;nextUUID=0
function RegisterNetEvent(n,f) events[n]=f end
function AddEventHandler(n,f) events[n]=f end
function TriggerClientEvent(n,id,p) messages[#messages+1]={name=n,id=id,p=p} end
function CreateThread(f) threads[#threads+1]=f end
function Wait() end
function GetPlayers() return {"1","2"} end
function GetPlayerIdentifier(p) return "account:"..p end
function GetPlayerRoutingBucket(p) return bucket[p] or 0 end
function GetCurrentResourceName() return "op77_lightrp" end
Open77={time={monotonic=function() return clock end},acl={isAllowed=function(p,right) return permissions[p] and permissions[p][right] or false end},players={position=function(p) return positions[p] end},routingBuckets={getPlayer=GetPlayerRoutingBucket},combat={},zones={}}
function Open77.combat.onDamage(fn) installedArbiter=fn;return fn end
function Open77.combat.offDamage(fn) if installedArbiter==fn then installedArbiter=nil end end
function Open77.zones.normalize(d) return d end
function Open77.zones.containsPlayer(p,d,options)
 assert(options and options.bucket==GetPlayerRoutingBucket(p) and options.maxAgeMs==2000 and options.grace==0,"fresh bucket-aware exact-boundary options")
 local v=positions[p];if not v then return nil,"stale_player" end
 if (v.ageMs or 0)>options.maxAgeMs then return nil,"stale_player" end
 if d.shape=="cylinder" then return (v.x-d.position.x)^2+(v.y-d.position.y)^2<=d.radius^2 and math.abs(v.z-d.position.z)<=d.maxHeight end
 if d.shape=="box" then local h=math.rad(-d.rotation);local x,y=v.x-d.position.x,v.y-d.position.y;local a,b=x*math.cos(h)-y*math.sin(h),x*math.sin(h)+y*math.cos(h);return math.abs(a)<=d.size.x/2 and math.abs(b)<=d.size.y/2 and math.abs(v.z-d.position.z)<=d.size.z/2 end
 error("geometry test adapter only implements circle and box; polygon validation is exercised separately")
end
LightRP={log=function() end}
function LightRP.module(n,m) modules[n]=m;return m end
function LightRP.command(n,o,f) commands[n]=f end
local Db={ready=true};LightRP.db=Db
function Db.schema() end
function Db.read(q,v)
 if q:find("UUID",1,true) then nextUUID=nextUUID+1;return true,{{id="zone-"..nextUUID}} end
 if q:find("safezones_audit",1,true) then local a=audits[v[1]..":"..v[2]];return true,a and {a} or {} end
 local out={};for _,row in pairs(sqlRows) do out[#out+1]=row end;return true,out
end
function Db.transaction(queries)
 if nestedPublication then local fn=nestedPublication;nestedPublication=nil;fn() end
 if failTransaction then return false end
 local q,v=queries[1].query,queries[1].values
 if q:find("INSERT INTO lightrp_safezones ",1,true) then sqlRows[v[1]]={id=v[1],definition=v[2],revision=v[3],deleted=0}
 else assert(sqlRows[v[4]].revision==v[5],"revision guard");sqlRows[v[4]]={id=v[4],definition=v[1],revision=v[2],deleted=v[3]} end
 v=queries[2].values;local key=v[1]..":"..v[2];assert(not audits[key],"duplicate mutation");audits[key]={action=v[3],zone_id=v[4],result=v[5]};return true
end
function grant(p)
 permissions[p]={};for _,verb in ipairs({"view","edit","publish","delete"}) do permissions[p]["command.admin.safezones."..verb]=true end
end
function request(op,p,player)
 clock=clock+1;source=player or 1;p=p or {};p.operation=op;p.request="request:"..clock
 events["op77_lightrp:safezones"](p)
 for i=#messages,1,-1 do if messages[i].p.kind=="response" and messages[i].p.request==p.request then return messages[i].p end end
 error("missing reply")
end
function zone(shape)
 return {label="Protected plaza",bucket=0,enabled=true,shape=shape or "circle",center={x=0,y=0,z=10},radius=10,length=10,width=10,heading=0,minZ=8,maxZ=15}
end
''')

# Optional real SQL adapter: only a local unix socket and a newly-created test
# database. No server.env, TCP host or production database can be selected.
if os.environ.get("SAFEZONES_TEST_SOCKET"):
    import atexit
    import pymysql
    sql_database = f"open77_safezones_test_{os.getpid()}_{time.time_ns()}"
    sql_connection = pymysql.connect(unix_socket=os.environ["SAFEZONES_TEST_SOCKET"], user=os.environ.get("SAFEZONES_TEST_USER", "root"), password=os.environ.get("SAFEZONES_TEST_PASSWORD", ""), autocommit=True, cursorclass=pymysql.cursors.DictCursor)
    with sql_connection.cursor() as cursor:
        cursor.execute(f"CREATE DATABASE `{sql_database}` CHARACTER SET utf8mb4")
    sql_connection.select_db(sql_database)

    def cleanup_database():
        try:
            with sql_connection.cursor() as cursor:
                cursor.execute(f"DROP DATABASE `{sql_database}`")
        finally:
            sql_connection.close()

    atexit.register(cleanup_database)

    def execute(query, values=None):
        args = from_lua(values) if values is not None else None
        if isinstance(args, dict) and not args:
            args = []
        with sql_connection.cursor() as cursor:
            cursor.execute(query.replace("%", "%%").replace("?", "%s") if args else query, args or None)
            return cursor.fetchall() if cursor.description else cursor.rowcount

    def sql_schema(query):
        execute(query)

    def sql_read(query, values=None):
        try:
            return True, to_lua(execute(query, values))
        except Exception as error:
            print("SQL read refused:", type(error).__name__)
            return False, "database_error"

    def sql_transaction(queries):
        try:
            sql_connection.begin()
            for item in from_lua(queries):
                execute(item["query"], to_lua(item["values"]))
            sql_connection.commit()
            return True
        except Exception as error:
            sql_connection.rollback()
            print("SQL transaction rolled back:", type(error).__name__)
            return False

    lua.globals().python_sql_schema = sql_schema
    lua.globals().python_sql_read = sql_read
    lua.globals().python_sql_transaction = sql_transaction
    lua.execute(r'''
    LightRP.db.schema=python_sql_schema
    LightRP.db.read=python_sql_read
    function LightRP.db.transaction(queries)
        if nestedPublication then local fn=nestedPublication;nestedPublication=nil;fn() end
        if failTransaction then return false end
        return python_sql_transaction(queries)
    end
    ''')

base = root / "resources/gamemodes/op77_lightrp"
for name in ["shared/safezones.lua", "server/modules/safezones_store.lua", "server/modules/safezones.lua", "server/modules/safezones_admin.lua"]:
    lua.execute((base / name).read_text(), name=name)

lua.execute(r'''
local G,S=LightRpSafezoneGeometry,LightRP.safezones
grant(1);grant(2);positions[1]={x=0,y=0,z=10};positions[2]={x=50,y=0,z=10}
assert(installedArbiter({victim=1,attacker=2,amount=10})==false,"PvP refuses until the database is loaded")
modules.safezones.onDatabaseReady();assert(S.available and S.ready)
assert(request("list",{},3).ok==false,"view ACL")
local c=request("capture");assert(c.ok and c.data.session);local session=c.data.session
assert(#S.list()==0,"capturing a draft must not protect anything")
assert(installedArbiter({victim=1,attacker=2,amount=10})==nil)
local z=zone();local saved=request("save",{zone=z,baseRevision=0,mutation="create:one",session=session})
assert(saved.ok,saved.error);local id=saved.data.zone.id;assert(S.records[id].revision==1)
assert(installedArbiter({victim=1,attacker=2,amount=10})==false,"incoming PvP")
assert(installedArbiter({victim=2,attacker=1,amount=10})==false,"outgoing PvP")
assert(installedArbiter({victim=1,attacker=0,amount=10})==nil,"environment policy untouched")
assert(installedArbiter({victim=1,attacker=1,amount=10})==nil,"self damage policy untouched")
positions[1].x=10;assert(installedArbiter({victim=1,attacker=2})==false,"exact boundary")
positions[1].z=16;assert(installedArbiter({victim=1,attacker=2})==nil,"upper floor outside")
positions[1].z=10;bucket[1]=7;assert(installedArbiter({victim=1,attacker=2})==nil,"bucket isolation")
bucket[1]=0;positions[1]=nil;assert(installedArbiter({victim=1,attacker=2})==false,"stale snapshots refuse")
positions[1]={x=0,y=0,z=10}
positions[1].ageMs=2001;assert(installedArbiter({victim=1,attacker=2})==false,"age threshold is explicit");positions[1].ageMs=0
local repeatSave=request("save",{zone=z,baseRevision=0,mutation="create:one",session=session})
assert(repeatSave.ok and repeatSave.data.zone.id==id and #S.list()==1,"retry is idempotent")
z.id=id;z.label="Changed";assert(not request("save",{zone=z,baseRevision=0,mutation="edit:stale",session=session}).ok,"stale revision")
failTransaction=true;assert(not request("save",{zone=z,baseRevision=1,mutation="edit:fail",session=session}).ok);assert(S.records[id].label=="Protected plaza" and S.records[id].revision==1,"rollback leaves live cache intact")
failTransaction=false
local nested
nestedPublication=function() nested=request("save",{zone=z,baseRevision=1,mutation="edit:race",session=session},2) end
local updated=request("save",{zone=z,baseRevision=1,mutation="edit:okay",session=session})
assert(updated.ok and nested and not nested.ok and S.records[id].revision==2,"write lock spans yielding transaction")
permissions[1]["command.admin.safezones.publish"]=false
assert(not request("save",{zone=z,baseRevision=2,mutation="edit:denied",session=session}).ok,"publish ACL rechecked")
grant(1)
local foreign=zone();foreign.center.x=1000
assert(not request("save",{zone=foreign,baseRevision=0,mutation="create:far",session=session}).ok,"authoring bounds")
assert(not request("save",{zone=zone(),baseRevision=0,mutation="create:no-session",session="bogus"}).ok,"session binding")
local removed=request("delete",{id=id,baseRevision=2,mutation="delete:one",session=session})
assert(removed.ok and #S.list()==0 and S.records[id].deleted,"delete publishes tombstone")
assert(installedArbiter({victim=1,attacker=2})==nil,"deleted zone no longer protects")
modules.safezones.onDatabaseReady();assert(S.available and #S.list()==0 and S.records[id].deleted,"database reload preserves tombstone")
clock=clock+301;assert(not request("heartbeat",{session=session}).ok,"session expires")
local invalid=zone();invalid.radius=0/0;assert(not G.validate(invalid),"NaN rejected")
invalid=zone();invalid.maxZ=invalid.minZ;assert(not G.validate(invalid),"zero height rejected")
invalid=zone("poly");invalid.points={{x=0,y=0,z=10},{x=5,y=5,z=10},{x=0,y=5,z=10},{x=5,y=0,z=10}};assert(not G.validate(invalid),"crossed edges rejected")
invalid.points={{x=0,y=0,z=10},{x=5,y=0,z=10},{x=5,y=0,z=10}};assert(not G.validate(invalid),"duplicate points rejected")
invalid.points={{x=0,y=0,z=10},{x=2,y=0,z=10},{x=4,y=0,z=10}};assert(not G.validate(invalid),"collinear ring rejected")
invalid.points={{x=0,y=0,z=10},{x=5,y=0,z=10},{x=5,y=5,z=10},{x=2,y=2,z=10},{x=0,y=5,z=10}};assert(G.validate(invalid),"simple concave polygon accepted")
local box=zone("box");box.heading=450;assert(G.validate(box).heading==90,"heading canonicalized")
local canon=assert(G.validate(zone()));assert(not canon.length and not canon.points,"irrelevant shape fields stripped")
local original=Open77.zones.containsPlayer
Open77.zones.containsPlayer=function() error("host read failed") end
S.records.test=G.validate(zone());S.records.test.id="test";S.records.test.revision=1;assert(S.rebuild())
assert(installedArbiter({victim=1,attacker=2})==false,"arbiter exception fails closed")
Open77.zones.containsPlayer=original
print("PASS: safezone ACL, typed geometry, sessions, PvP/buckets/boundaries/staleness, SQL rollback/reload, idempotency, revision races and arbiter failure")
''')

if sql_connection:
    # Simulate an independent writer after our loaded revision: the SQL CAS
    # must abort both zone and audit even though the memory check still passes.
    lua.execute(r'''
    local S=LightRP.safezones
    S.records.test=nil
    modules.safezones.onDatabaseReady()
    positions[1]={x=0,y=0,z=10};grant(1)
    local c=request("capture")
    assert(c.ok)
    casSession=c.data.session
    local saved=request("save",{zone=zone(),baseRevision=0,mutation="cas:create",session=casSession})
    assert(saved.ok,saved.error);casId=saved.data.zone.id
    ''')
    with sql_connection.cursor() as cursor:
        cursor.execute("UPDATE lightrp_safezones SET revision=revision+1 WHERE id=%s", (lua.globals().casId,))
    lua.execute(r'''
    local z=zone();z.id=casId;z.label="Must not publish"
    local result=request("save",{zone=z,baseRevision=1,mutation="cas:lost-update",session=casSession})
    assert(not result.ok,"lost SQL CAS must refuse")
    assert(LightRP.safezones.records[casId].revision==1 and LightRP.safezones.records[casId].label=="Protected plaza","lost CAS must not alter cache")
    ''')
    with sql_connection.cursor() as cursor:
        cursor.execute("SELECT COUNT(*) AS n FROM lightrp_safezones_audit WHERE mutation=%s", ("cas:lost-update",))
        assert cursor.fetchone()["n"] == 0, "lost CAS audit must roll back"
        cursor.execute("SELECT definition,revision FROM lightrp_safezones WHERE id=%s", (lua.globals().casId,))
        row = cursor.fetchone()
        assert row["revision"] == 2 and json.loads(row["definition"])["label"] == "Protected plaza"
    print("PASS: real MariaDB transactions, SQL revision conflict rejection and atomic audit rollback")
