-- The RP staff desk. State is fetched only by authenticated, permitted staff;
-- no roster, balances, account IDs or internal history are broadcast to players.
local S,Db,C=LightRP.support,LightRP.db,LightRpSupportConfig
local Admin=LightRP.module("admin",{handlers={}})
local returned,busy={},{}
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_staff_audit (
 id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, actor_id VARCHAR(128) NOT NULL,
 actor_name VARCHAR(96) NOT NULL, target_id VARCHAR(128) NOT NULL DEFAULT '',
 target_name VARCHAR(96) NOT NULL DEFAULT '', character_key VARCHAR(64) NOT NULL DEFAULT '',
 action VARCHAR(32) NOT NULL, reason VARCHAR(500) NOT NULL, detail VARCHAR(500) NOT NULL DEFAULT '',
 outcome VARCHAR(16) NOT NULL DEFAULT 'pending', request_key VARCHAR(96) NOT NULL,
 created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 UNIQUE KEY staff_request (actor_id,request_key), KEY staff_target (target_id,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
local function read(sql,values) local ok,r=Db.read(sql,values);if not ok then error("database_error",0) end;return r end
local function finite(v) local n=tonumber(v);return n and n==n and math.abs(n)<9007199254740991 and n end
local function current(player,c) return c and LightRP.characters.get(player)==c and GetPlayerName(player)~=nil end
local function permitted(player,right) return S.allowed(player,"view") and S.allowed(player,right) end
local function grants(player)
    local out={};for name in pairs(C.permissions) do out[name]=S.allowed(player,name) end
    out.housing=LightRP.housing and LightRP.housing.allowed(player) or false
    out.safezones=LightRP.safezones and LightRP.safezones.allowed(player,"view") or false
    for _,entry in ipairs({{"noclip","admin.self.noclip"},{"god","admin.self.god"},{"advanced","adminfull"},{"observe","admin.player.observe"}}) do out[entry[1]]=LightRP.staff.allowed(player,"command."..entry[2]) end
    return out
end
-- One /admin (owner, 2026-11-05: "merge /admin et /lightrp.admin dans un seul gros menu"). The staff
-- desk is the server's admin menu: the platform's open77_admin tools (noclip, vehicles, weather,
-- bulk actions...) and the LightRP ones (missions, world bosses, gigs, items...) run from it as the
-- restricted commands they already are, through open77:command:execute, so the host's ACL still
-- decides every one of them. The page only shows what the operator may run: this list, projected
-- through the ACL, travels as one comma-separated string (the 1024-value cap of a net event).
local COMMANDS={
 "admin.self.noclip","admin.self.fly","admin.self.speed","admin.self.god","admin.self.heal","admin.self.revive","admin.self.maptravel",
 "admin.player.revive","admin.player.god","admin.player.kill","admin.player.observe",
 "admin.veh.spawn","admin.veh.give","admin.veh.remove","admin.world.cleanup","admin.bulk.tpall","admin.bulk.dvall","admin.bulk.cancel",
 "admin.server.status","adminfull",
 "weather.set","weather.next","weather.random","weather.time.set","weather.time.freeze","weather.time.resume",
 "lightrp.ghost","lightrp.tp","lightrp.car","lightrp.repair","lightrp.refuel","lightrp.impound","lightrp.rentals","lightrp.fuelrate",
 "lightrp.giveitem","lightrp.giveweapon","lightrp.giveammo","lightrp.takeweapon","lightrp.weapons","lightrp.givevehicle","lightrp.needs","lightrp.account","lightrp.inv","lightrp.status","lightrp.bots",
 "lightrp.announce","lightrp.broadcast","lightrp.missions","lightrp.activities","lightrp.dailies","lightrp.dogtown",
 "lightrp.guide","lightrp.board","lightrp.halloffame",
 "worldboss.list","worldboss.start","worldboss.stop","worldboss.next",
 "fixers.list","fixers.dispatch","fixers.offer","fixers.cancel",
 "missions.launch","missions.complete","missions.fail","missions.rep",
 "turf.status","turf.start","turf.stop","tcg.rooms",
}
local function commandGrants(player)
    local out={}
    for _,name in ipairs(COMMANDS) do if LightRP.staff.allowed(player,"command."..name) then out[#out+1]=name end end
    return table.concat(out,",")
end
local function catalogue(source)
    local out={};for key,entry in pairs(source) do
        local grades={};for n,g in pairs(entry.grades) do grades[#grades+1]={value=n,label=g.label} end
        table.sort(grades,function(a,b)return a.value<b.value end)
        out[#out+1]={name=key,label=entry.label,grades=grades}
    end;table.sort(out,function(a,b)return a.label<b.label end);return out
end
function Admin.overview(player)
    if not S.allowed(player,"view") then return nil,"Staff access denied." end
    local roster,staff={},{}
    for _,id in ipairs(GetPlayers()) do
        local c=S.identity(id)
        if c then
            local life=Open77.players.getLifeState(id)
            local row={id=id,account=c.identifier,character=c.key,name=LightRP.characters.displayName(id),accountName=GetPlayerName(id),status=c.status,
                job=LightRP.jobs.get(id),gang=LightRP.jobs.gang(id),life=life and life.phase or "loading",playtimeMs=c.playtimeMs or 0}
            roster[#roster+1]=row
            if permitted(id,"reports") then staff[#staff+1]={id=id,name=GetPlayerName(id)} end
        end
    end
    table.sort(roster,function(a,b)return a.id<b.id end)
    return {players=roster,staff=staff,permissions=grants(player),commands=commandGrants(player),jobs=catalogue(LightRpJobs),gangs=catalogue(LightRpGangs),database=Db.ready}
end
-- What the admin menu offers in its lists, as "a|b|c" strings (one value each, see COMMANDS):
-- LightRP vehicles (key|label|category|record), items (name|label|category), teleport places
-- (name|label), the weather presets, the firearms (id|label|class|ammo) and the ammunition
-- types (kind|label).
function Admin.catalog(player)
    if not S.allowed(player,"view") then return nil,"Staff access denied." end
    local vehicles,items,places={},{},{}
    local cfg=LightRpConfig or {}
    for _,v in ipairs(cfg.vehicles and cfg.vehicles.catalog or {}) do
        if type(v.key)=="string" then vehicles[#vehicles+1]=table.concat({v.key,tostring(v.label or v.key),tostring(v.category or ""),tostring(v.record or "")},"|") end
    end
    for name,item in pairs(LightRpItems or {}) do
        if type(name)=="string" and name~="cash" and type(item)=="table" and #items<800 then
            items[#items+1]=table.concat({name,tostring(item.label or name):gsub("|","/"),tostring(item.category or "misc")},"|")
        end
    end
    table.sort(items)
    for _,l in ipairs(cfg.locations or {}) do if type(l.name)=="string" then places[#places+1]=l.name.."|"..tostring(l.label or l.name) end end
    local weapons,ammo={},{}
    local A=LightRpArmament or {}
    for id,w in pairs(A.weapons or {}) do weapons[#weapons+1]=table.concat({id,tostring(w.label or id),tostring(w.class or ""),tostring(w.ammo or "")},"|") end
    table.sort(weapons)
    for kind,a in pairs(A.ammo or {}) do ammo[#ammo+1]=kind.."|"..tostring(a.label or kind) end
    table.sort(ammo)
    return {vehicles=vehicles,items=items,places=places,weapons=weapons,ammo=ammo,weather={"sunny","lightclouds","cloudy","rain","heavyclouds","fog","pollution","sandstorm"}}
end
function Admin.player(player,p)
    if not S.allowed(player,"view") then return nil,"Staff access denied." end
    local id=finite(p.target);local c=id and S.identity(id)
    if not c or c.identifier~=p.account or c.key~=p.character then return nil,"That player or character changed. Refresh the roster." end
    local position=Open77.players.position(id)
    local money=LightRP.money.get(id)
    local history={}
    if S.allowed(player,"audit") then history=read("SELECT id,actor_name,target_name,action,reason,detail,outcome,UNIX_TIMESTAMP(created_at)*1000 AS at FROM lightrp_staff_audit WHERE target_id=? ORDER BY id DESC LIMIT 30",{c.identifier}) end
    if not S.allowed(player,"view") or not current(id,c) then return nil,"Your access or the selected player changed." end
    if not S.allowed(player,"audit") then history={} end
    return {id=id,account=c.identifier,character=c.key,name=LightRP.characters.displayName(id),accountName=GetPlayerName(id),
        firstName=c.firstName,lastName=c.lastName,birthDate=c.birthDate,origin=c.origin,story=c.story,status=c.status,
        job=LightRP.jobs.get(id),gang=LightRP.jobs.gang(id),position=position,needs=LightRP.buildState(id,{needs=true}).needs,
        money=money and {cash=money.cash,bank=money.bank,number=money.number},history=history,
        canReturn=returned[id] and returned[id].character==c or false}
end
function Admin.audit(player,p)
    if not permitted(player,"audit") then return nil,"Audit permission required." end
    local page=math.min(math.max(1,math.floor(finite(p.page) or 1)),10000)
    local list=read("SELECT id,actor_name,target_name,action,reason,detail,outcome,UNIX_TIMESTAMP(created_at)*1000 AS at FROM lightrp_staff_audit ORDER BY id DESC LIMIT 26 OFFSET "..((page-1)*25))
    if not permitted(player,"audit") then return nil,"Audit permission was revoked." end
    local more=#list>25;if more then table.remove(list) end
    return {entries=list,page=page,hasMore=more}
end
local DEFAULT_REASON={warn="Please respect the server rules.",kick="Kicked by staff.",ban="Banned by staff.",credit="Staff credit via /admin.",debit="Staff debit via /admin.",setBucket="Instance changed via /admin."}
-- What the player is told after a staff action on them. "Go to" stays silent: a staff member may
-- join someone discreetly (ghost mode), and players saw "gotoPlayer: Via /admin." (2026-11-06).
local SILENT={gotoPlayer=true}
local TOLD={warn="Warning from staff",bring="Brought by staff",returnPlayer="Taken back by staff",heal="Healed by staff",
 credit="Money added by staff",debit="Money removed by staff",job="Job changed by staff",gang="Gang changed by staff",
 rename="Name changed by staff",setBucket="Instance changed by staff"}
function Admin.toldOf(op,reason)
    if SILENT[op] then return nil end
    local title=TOLD[op] or "Staff intervention"
    if not reason or reason=="Via /admin." or reason==DEFAULT_REASON[op] then return title end
    return title..": "..reason
end
local function actionDetail(p)
    if p.action=="job" or p.action=="gang" then return tostring(p.name).." / "..tostring(p.grade) end
    if p.action=="credit" or p.action=="debit" then return tostring(p.wallet).." / "..tostring(p.amount) end
    if p.action=="rename" then return tostring(p.firstName).." "..tostring(p.lastName) end
    if p.action=="ban" then return p.duration=="permanent" and "permanent" or tostring(p.duration).." seconds" end
    if p.action=="setBucket" then return "instance "..tostring(p.bucket) end
    return ""
end
local function kickReason(reason)
    local value=reason:gsub("%s+"," ")
    local bytes=math.min(#value,127)
    while not utf8.len(value:sub(1,bytes)) do bytes=bytes-1 end
    return value:sub(1,bytes)
end
local function execute(player,target,c,p,reason)
    local op=p.action
    if op=="heal" then return LightRP.staff.heal(target)
    elseif op=="rename" then return LightRP.characters.adminRename(target,p.firstName,p.lastName)
    elseif op=="job" then return LightRP.jobs.setJob(target,p.name,p.grade)
    elseif op=="gang" then return LightRP.jobs.setGang(target,p.name,p.grade)
    elseif op=="credit" or op=="debit" then
        local amount=finite(p.amount)
        if not amount or amount<1 or amount>10000000 or amount~=math.floor(amount) or (p.wallet~="cash" and p.wallet~="bank") then return false,"Enter a whole amount between 1 and 10,000,000." end
        local M=LightRP.money
        -- A credit is capped per grant (economy.lua Money.staffGrantRefusal, docs/economy-balance.md
        -- §16). The reason (4-500 characters, the audit) is the ledger note, cut to its 160 bytes.
        if op=="credit" and M.staffGrantRefusal then
            if not M.staffReason(reason) then return false,("A credit needs a reason of at least %d characters."):format(M.staffGrantRule().minReason) end
            local refusal=M.staffGrantRefusal(player,amount)
            if refusal then return false,refusal end
        end
        local note=M.clip and M.clip(reason,160) or reason:sub(1,160)
        local f=op=="credit" and (p.wallet=="cash" and M.addCash or M.addBank) or (p.wallet=="cash" and M.removeCash or M.removeBank)
        return f(target,amount,"staff",note,GetPlayerName(player))
    elseif op=="warn" then
        LightRP.notice(target,{kind="warning",title="Staff warning",body=reason,durationMs=20000})
        LightRP.chat.system(target,"Staff warning: "..reason);return true
    elseif op=="kick" then
        return Open77.players.kick(target,kickReason(reason))
    elseif op=="ban" then
        local duration=finite(p.duration)
        if p.duration~="permanent" and (not duration or duration<60 or duration>315360000 or duration~=math.floor(duration)) then return false,"Choose a valid ban duration." end
        local identifier=Open77.players.identifier(target)
        if not identifier then return false,"No authenticated player identity." end
        return Open77.access.ban(identifier,reason,duration,GetPlayerName(target))
    elseif op=="announce" then LightRP.staff.announce(reason,{from=GetPlayerName(player)});return true
    elseif op=="setBucket" then
        -- the player stays where they stand, in another instance (routing bucket)
        local bucket=finite(p.bucket)
        if not bucket or bucket<0 or bucket>2147483647 or bucket~=math.floor(bucket) then return false,"Enter an instance number (0 is the city)." end
        if type(SetPlayerRoutingBucket)~="function" then return false,"Instances are not available on this server." end
        local okSet,set=pcall(SetPlayerRoutingBucket,target,math.floor(bucket))
        if not okSet or set==false then return false,"The instance could not be changed." end
        return true,("Moved to instance %d."):format(math.floor(bucket))
    end
    local moved,position,heading=target,nil,0
    if op=="gotoPlayer" then position=Open77.players.position(target);moved=player
    elseif op=="bring" then position=Open77.players.position(player)
    elseif op=="returnPlayer" then
        local saved=returned[target];if not saved or saved.character~=c then return false,"No saved return position for this session." end
        position,heading=saved.position,saved.heading
    else return false,"Unknown admin action." end
    if not position then return false,"Position unavailable." end
    local before=Open77.players.position(moved)
    if not before then return false,"Position unavailable." end
    -- Another instance (owner 2026-11-06: "si je bring change le de bucket automatiquement"): the
    -- moved player lands in the destination's instance. Character creation is refused above
    -- (only active characters reach here).
    local bucket=position.bucket or 0
    local destination={x=position.x+(op=="returnPlayer" and 0 or 1.5),y=position.y,z=position.z}
    local done,ok,why=false,false,nil
    LightRP.staff.moveTo(moved,destination,heading,function(success,failure) ok,why,done=success,failure,true end,
        bucket~=(before.bucket or 0) and bucket or nil)
    while not done do Wait(20) end
    if ok and op=="bring" and current(target,c) then returned[target]={character=c,position=before,heading=before.heading or 0}
    elseif ok and op=="returnPlayer" then returned[target]=nil end
    return ok,why
end
function Admin.action(player,p)
    local actor=S.identity(player);local op=p.action
    if not actor or not permitted(player,op) then return nil,"You do not have permission for this action." end
    -- no confirmation step and no reason to type (owner, 2026-11-05: "faut que ça soit rapide"): a
    -- missing reason becomes a default line; the staff history still records every intervention
    local reason=S.text(p.reason,500,4)
    if not reason then
        if op=="announce" then return nil,"Write the announcement." end
        reason=DEFAULT_REASON[op] or "Via /admin."
    end
    if type(p.mutation)~="string" or #p.mutation<8 or #p.mutation>96 or not p.mutation:match("^[%w:_%-]+$") then return nil,"Invalid action request." end
    local previous=read("SELECT outcome,detail FROM lightrp_staff_audit WHERE actor_id=? AND request_key=?",{actor.identifier,p.mutation})[1]
    if previous then return {accepted=previous.outcome=="success",outcome=previous.outcome,message=previous.outcome=="pending" and "This action was submitted. Check the player and audit log before doing anything else." or previous.detail} end
    local target=op=="announce" and player or finite(p.target)
    local c=target and S.identity(target)
    if not c or (op~="announce" and (c.identifier~=p.account or c.key~=p.character)) then return nil,"The selected player or character changed. Refresh the roster." end
    if c.status~="active" and op~="kick" and op~="ban" and op~="warn" then return nil,"Let the player finish character creation first." end
    if (op=="kick" or op=="ban") and target==player then return nil,"You cannot kick or ban yourself here." end
    if busy[target] then return nil,"An intervention is already running for this player." end
    busy[target]=c
    local called,accepted,message=pcall(function()
        local ok=Db.run([[INSERT INTO lightrp_staff_audit (actor_id,actor_name,target_id,target_name,character_key,action,reason,detail,request_key) VALUES (?,?,?,?,?,?,?,?,?)]],
            {actor.identifier,GetPlayerName(player),c.identifier,LightRP.characters.displayName(target),c.key,op,reason,actionDetail(p):sub(1,500),p.mutation})
        if not ok then return nil,"The audit could not be saved; nothing was changed." end
        local success,why=false,"Access or player changed."
        if current(player,actor) and current(target,c) and permitted(player,op) then success,why=execute(player,target,c,p,reason) end
        local label=success and "Action completed." or tostring(why or "Action refused.")
        local saved=Db.run("UPDATE lightrp_staff_audit SET outcome=?,detail=? WHERE actor_id=? AND request_key=?",{success and "success" or "failed",(actionDetail(p).." · "..label):sub(1,500),actor.identifier,p.mutation})
        local told=success and current(target,c) and target~=player and Admin.toldOf(op,reason)
        if told then LightRP.notice(target,{kind="staff",title="Staff intervention",body=told,durationMs=12000}) end
        return {accepted=success==true,outcome=saved and (success and "success" or "failed") or "pending",message=label..(saved and "" or " Audit confirmation pending; do not repeat this action.")}
    end)
    if busy[target]==c then busy[target]=nil end
    if not called then LightRP.log("admin %s failed: %s",tostring(op),tostring(accepted));return nil,"The action could not finish. Check its audit entry before retrying." end
    return accepted,message
end
Admin.handlers={overview=Admin.overview,player=Admin.player,audit=Admin.audit,adminAction=Admin.action,adminCatalog=Admin.catalog}
function Admin.onDisconnected(player) returned[player],busy[player]=nil,nil end
exports("openAdmin",function(player)
    if GetInvokingResource()~="open77_admin" or not S.allowed(player,"view") then return false,"Staff access denied." end
    return S.open(player,"staff")
end)
-- /admin is this menu on a LightRP server. Command dispatch walks the running resources in ordinal
-- name order and takes the first match: op77_lightrp sorts before open77_admin, so this answers and
-- the platform's compact menu no longer opens over it (its console stays on /adminfull, and every
-- open77_admin command keeps working, from this menu or typed). Same right: command.admin.
local function openDesk(player)
    local ok,why=S.open(player,"staff")
    if ok==false then return false,why end
    return nil
end
LightRP.command("admin",{restricted=true},openDesk)
LightRP.command("lightrp.admin",{restricted=true},openDesk)

-- Repair the vehicle the operator sits in, or the nearest one within 10 m (or an id), and fill it.
LightRP.command("lightrp.repair",{restricted=true,usage="/lightrp.repair [vehicleId]"},function(player,args)
    local id=tonumber(args[1])
    if not id and player and player>0 then
        local seat=Open77.vehicles.getPlayerSeat(player)
        if type(seat)=="table" and seat.vehicleId then id=seat.vehicleId end
        if not id then
            local ok,entry=pcall(Open77.vehicles.closest,player,{radius=10.0})
            if ok and type(entry)=="table" then id=entry.id or entry.vehicleId end
        end
    end
    if not id then return false,"No vehicle: sit in one, stand next to one or give an id." end
    local ok=Open77.vehicles.repair(id,"full")
    if not ok then return false,"Vehicle "..tostring(id).." could not be repaired." end
    if LightRP.fuel and type(LightRP.fuel.seed)=="function" then pcall(LightRP.fuel.seed,id,"full") end
    return true,"Vehicle "..tostring(id).." repaired."
end)
