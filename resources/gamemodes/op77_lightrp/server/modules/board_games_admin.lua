-- Staff management of placed tables (board games and casino tables), in the
-- staff desk (/admin > Placed tables) and as /lightrp.tables. Same rules as the
-- rest of the desk (server/modules/admin.lua): the host ACL decides
-- (LightRpSupportConfig.permissions tables / tableTeleport / tableDelete), every
-- intervention carries a reason, is written to lightrp_staff_audit BEFORE it
-- runs and gets its outcome after. The removal itself is
-- LightRP.boardGames.remove (server/modules/board_games.lua): pickup's lock,
-- refunds and removed hook, one transaction.
--
-- 176: the list travels flat (one level of rows, scalar fields, seats as text)
-- and paginated (PAGE rows, a few KB) so hundreds of tables never make one
-- oversized or too deeply nested event.
local S,Db,BG=LightRP.support,LightRP.db,LightRP.boardGames
local Admin=LightRP.admin
local TablesAdmin={};LightRP.module("board_games_admin",TablesAdmin)
local PAGE,CHAT_PAGE=15,10
local SCALE=.65 -- the tables' model scale (client/core/tabletop_extra.lua Extra.SCALE)
-- Where staff land, in unscaled table-local units: players sit at local -Y
-- (blackjack dealer at +Y), so a point beyond the players' edge clears every
-- collider; the heading faces the table.
local LANDING={chess={0,-2.0},checkers={0,-2.0},connect4={0,-2.0},roulette={.77,-2.2},
    blackjack={0,-2.4},pool={0,-2.1},fortune={0,-2.2},slots={0,-1.8}}
local DEFAULT_LANDING={0,-2.2}
local busy={}

local function finite(v) local n=tonumber(v);return n and n==n and math.abs(n)<9007199254740991 and n end
local function round(v,step) return math.floor(v/step+.5)*step end
local function console(player) return player==nil or player==0 end
-- The console passed the restricted-command gate and cannot be moved. The desk
-- additionally needs the desk's own `view` right (desk() below).
local function allowed(player,right)
    if console(player) then return right~="tableTeleport" end
    return S.allowed(player,right)
end
local function desk(player,right) return not console(player) and S.allowed(player,"view") and allowed(player,right) end
local function bucketOf(player)
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then
        local bucket=Open77.routingBuckets.getPlayer(player)
        if bucket~=nil then return bucket end
    end
    local p=Open77.players.position(player)
    return p and (p.bucket or 0)
end
local function placedAt(id) local unix=tonumber(tostring(id):match("^(%d+):"));return unix and unix*1000 or nil end
-- Owner character names: the live display name when the character is loaded,
-- else the label its inventory row was last saved with.
local function ownerNames()
    local names,online={},{}
    for _,raw in ipairs(GetPlayers()) do
        local id=tonumber(raw);local inv=id and LightRP.inventory.playerId(id)
        if inv then online[inv]=id;names[inv]=LightRP.characters.displayName(id) end
    end
    if Db.ready then
        local ok,rows=Db.read("SELECT i.id,i.label FROM lightrp_board_games b JOIN lightrp_inventories i ON i.id=b.owner_inventory",{})
        if ok then for _,row in ipairs(rows) do if not names[row.id] and row.label~="" then names[row.id]=row.label end end end
    end
    return names,online
end
local function seatedText(b)
    local seats,list={}, {}
    for seat in pairs(b.players) do seats[#seats+1]=seat end
    table.sort(seats)
    for _,seat in ipairs(seats) do
        local id=b.players[seat]
        list[#list+1]=("#%d %s"):format(id,tostring(LightRP.characters.displayName(id) or "?"))
    end
    return table.concat(list,", "),#list
end
local function row(b,names,online,from)
    local stakes,resolving=BG.money(b)
    local seated,count=seatedText(b)
    local p=b.position
    local out={id=b.id,kind=b.kind,title=BG.title(b.kind),owner=names[b.ownerInventory] or "Unknown character",inventory=b.ownerInventory,
        online=online[b.ownerInventory],x=round(p.x,.1),y=round(p.y,.1),z=round(p.z,.1),bucket=b.bucket or 0,revision=b.revision or 0,
        placedAt=placedAt(b.id),seated=seated,seatedCount=count,phase=type(b.game)=="table" and tostring(b.game.phase or b.game.status or "") or "",
        stakes=stakes,resolving=resolving,busy=b.busy and true or nil}
    if from and (b.bucket or 0)==(from.bucket or 0) then out.distance=round(math.sqrt((p.x-from.x)^2+(p.y-from.y)^2+(p.z-from.z)^2),.1) end
    return out
end
local function matches(r,query)
    if query=="" then return true end
    return (("%s %s %s %s %s"):format(r.id,r.kind,r.title,r.owner,r.inventory)):lower():find(query,1,true)~=nil
end
-- Answers every matching row (flat), sorted newest first or nearest first.
function TablesAdmin.rows(player,opts)
    opts=opts or {}
    local names,online=ownerNames()
    local from=not console(player) and Open77.players.position(player) or nil
    if from then from={x=from.x,y=from.y,z=from.z,bucket=bucketOf(player) or from.bucket or 0} end
    local query=type(opts.search)=="string" and opts.search:lower():sub(1,64) or ""
    local rows={}
    for _,b in ipairs(BG.all()) do
        local r=row(b,names,online,from)
        if matches(r,query) then rows[#rows+1]=r end
    end
    if opts.sort=="near" and from then
        table.sort(rows,function(a,b)
            if (a.distance~=nil)~=(b.distance~=nil) then return a.distance~=nil end
            if a.distance and a.distance~=b.distance then return a.distance<b.distance end
            return a.id<b.id
        end)
    else
        table.sort(rows,function(a,b)
            if (a.placedAt or 0)~=(b.placedAt or 0) then return (a.placedAt or 0)>(b.placedAt or 0) end
            return a.id>b.id
        end)
    end
    return rows
end
function TablesAdmin.list(player,p)
    if not desk(player,"tables") then return nil,"Placed tables permission required." end
    if not BG.loaded() then return nil,"Table storage is not loaded yet." end
    local page=math.min(math.max(1,math.floor(finite(p.page) or 1)),10000)
    local rows=TablesAdmin.rows(player,{search=p.search,sort=p.sort})
    local out={}
    for i=(page-1)*PAGE+1,math.min(#rows,page*PAGE) do out[#out+1]=rows[i] end
    return {tables=out,page=page,pageSize=PAGE,total=#rows,pendingReturns=BG.pendingReturns(),
        canTeleport=desk(player,"tableTeleport"),canDelete=desk(player,"tableDelete")}
end

-- Interventions --------------------------------------------------------------
local function landing(b)
    local o=LANDING[b.kind] or DEFAULT_LANDING
    local a=math.rad(tonumber(b.rotation) or 0);local c,s=math.cos(a),math.sin(a)
    local x,y=o[1]*SCALE,o[2]*SCALE
    local spec=LightRpBoardGames[b.kind] or {}
    local p=b.position
    return {x=p.x+x*c-y*s,y=p.y+x*s+y*c,z=p.z-(tonumber(spec.floor) or 0)*SCALE+.15},(tonumber(b.rotation) or 0)%360
end
TablesAdmin.landing=landing
local function teleport(player,b)
    if console(player) then return false,"Only an in-game staff member can be moved." end
    local here,target=bucketOf(player),b.bucket or 0
    if here~=target and target~=0 then
        return false,("This table is in instance %d (a private interior); you are in instance %s. Enter that instance first."):format(target,tostring(here))
    end
    local position,heading=landing(b)
    local done,ok,why=false,false,nil
    LightRP.staff.moveTo(player,position,heading,function(success,failure) ok,why,done=success,failure,true end,here~=target and target or nil)
    while not done do Wait(20) end
    return ok,ok and ("You are next to the %s table %s."):format(BG.title(b.kind),b.id) or ("Teleport refused: "..tostring(why))
end
local function remove(player,b,returnItem)
    local actorName=console(player) and "Server console" or GetPlayerName(player)
    local ok,detail=BG.remove(b.id,{returnItem=returnItem,actor=actorName})
    if not ok then return false,detail end
    local item=detail.item=="returned" and "Board item returned to the owner's inventory." or
        detail.item=="pending" and "Board item will be returned when the owner's character is next loaded with a free slot." or "Board item not returned."
    return true,("%s table %s removed. %s%s%s"):format(BG.title(b.kind),b.id,
        detail.refunded>0 and ("Refunded €$ "..detail.refunded.." of open stakes. ") or "",
        #detail.seated>0 and (#detail.seated.." seated player(s) removed. ") or "",item)
end
local function describe(b,extra)
    local p=b.position
    return (("%s %s · owner %s · %.1f, %.1f, %.1f · instance %d%s"):format(b.kind,b.id,tostring(b.ownerInventory),p.x,p.y,p.z,b.bucket or 0,extra or "")):sub(1,500)
end
local function actorOf(player)
    if console(player) then return {identifier="console",name="Server console"} end
    local c=S.identity(player)
    return c and {identifier=c.identifier,name=GetPlayerName(player),character=c}
end
local sequence=0
-- Audit first (pending), act, then record the outcome. `mutation` dedupes a
-- retried desk request; commands get a fresh key.
local function audited(player,op,b,reason,mutation,returnItem)
    local actor=actorOf(player)
    if not actor then return nil,"Your account is still loading." end
    if not allowed(player,op) then return nil,"You do not have permission for this action." end
    if not mutation then sequence=sequence+1;mutation=("cmd:%d:%d"):format(math.floor(Open77.time.unix()),sequence) end
    local ok,previous=Db.read("SELECT outcome,detail FROM lightrp_staff_audit WHERE actor_id=? AND request_key=?",{actor.identifier,mutation})
    if not ok then return nil,"The audit log is unavailable; nothing was changed." end
    if previous[1] then
        local r=previous[1]
        return {accepted=r.outcome=="success",outcome=r.outcome,message=r.outcome=="pending" and "This action was submitted. Check the table list and audit log before doing anything else." or r.detail}
    end
    if busy[b.id] then return nil,"Another staff action is running on this table." end
    busy[b.id]=true
    local called,result,message=pcall(function()
        local names=ownerNames()
        local owner=names[b.ownerInventory] or ""
        local detail=describe(b,op=="tableDelete" and (returnItem and " · return item" or " · no return") or "")
        local saved=Db.run([[INSERT INTO lightrp_staff_audit (actor_id,actor_name,target_id,target_name,character_key,action,reason,detail,request_key) VALUES (?,?,?,?,?,?,?,?,?)]],
            {actor.identifier,actor.name,tostring(b.ownerInventory):sub(1,128),tostring(owner):sub(1,96),tostring(b.id):sub(1,64),op,reason,detail,mutation})
        if not saved then return {accepted=false,outcome="failed",message="The audit could not be saved; nothing was changed."} end
        local success,label=false,"Access or table changed."
        local current=BG.get(b.id)==b and allowed(player,op) and (console(player) or actorOf(player)~=nil and S.identity(player)==actor.character)
        if current then
            if op=="tableTeleport" then success,label=teleport(player,b) else success,label=remove(player,b,returnItem) end
        end
        label=tostring(label or (success and "Done." or "Refused."))
        local written=Db.run("UPDATE lightrp_staff_audit SET outcome=?,detail=? WHERE actor_id=? AND request_key=?",
            {success and "success" or "failed",(detail.." · "..label):sub(1,500),actor.identifier,mutation})
        LightRP.log("staff %s %s by %s (%s): %s",op,b.id,actor.name,actor.identifier,label)
        return {accepted=success==true,outcome=written and (success and "success" or "failed") or "pending",
            message=label..(written and "" or " Audit confirmation pending; do not repeat this action.")}
    end)
    busy[b.id]=nil
    if not called then LightRP.log("staff table %s failed: %s",tostring(op),tostring(result));return nil,"The action could not finish. Check its audit entry before retrying." end
    return result,message
end
function TablesAdmin.action(player,p)
    local op=p.action
    if op~="tableTeleport" and op~="tableDelete" then return nil,"Unknown table action." end
    if not desk(player,op) then return nil,"You do not have permission for this action." end
    -- acts at once, the reason optional (owner, 2026-11-05); the staff history keeps a default line
    local reason=S.text(p.reason,500,4) or (op=="tableDelete" and "Table removed via /admin." or "Go to table via /admin.")
    if type(p.mutation)~="string" or #p.mutation<8 or #p.mutation>96 or not p.mutation:match("^[%w:_%-]+$") then return nil,"Invalid action request." end
    local b=BG.get(p.table)
    if not b or b.kind~=p.kind then return nil,"This table no longer exists or changed. Refresh the list." end
    return audited(player,op,b,reason,p.mutation,p.returnItem==true)
end
Admin.handlers.tables=TablesAdmin.list
Admin.handlers.tableAction=TablesAdmin.action

-- /lightrp.tables ------------------------------------------------------------
local USAGE="/lightrp.tables [page | near] · /lightrp.tables tp <id> · /lightrp.tables delete <id> [return]"
local function say(player,raw,ok,text)
    if console(player) then LightRP.log("%s",text) else LightRP.chat.system(player,text) end
end
LightRP.command("lightrp.tables",{restricted=true,usage=USAGE},function(player,args,raw)
    if not allowed(player,"tables") then return false,"Placed tables permission required." end
    if not BG.loaded() then return false,"Table storage is not loaded yet." end
    local sub=tostring(args[1] or ""):lower()
    if sub=="tp" or sub=="delete" then
        local b=BG.get(args[2])
        if not b then return false,"No placed table with id "..tostring(args[2] or "?")..". List them with /lightrp.tables." end
        local op=sub=="tp" and "tableTeleport" or "tableDelete"
        local returnItem=sub=="delete" and tostring(args[3] or ""):lower()=="return"
        local result,why=audited(player,op,b,"Chat command /lightrp.tables "..sub,nil,returnItem)
        if not result then return false,why end
        return result.accepted,result.message
    end
    local near=sub=="near"
    local page=near and 1 or math.max(1,math.floor(finite(args[1]) or 1))
    local rows=TablesAdmin.rows(player,{sort=near and "near" or nil})
    if #rows==0 then return true,"No placed tables." end
    local pages=math.max(1,math.ceil(#rows/CHAT_PAGE))
    page=math.min(page,pages)
    say(player,raw,true,("Placed tables: %d (%s, page %d/%d). %s"):format(#rows,near and "nearest first" or "newest first",page,pages,USAGE))
    for i=(page-1)*CHAT_PAGE+1,math.min(#rows,page*CHAT_PAGE) do
        local r=rows[i]
        local money=r.resolving and (" · resolving: "..r.resolving) or (r.stakes and r.stakes>0 and (" · €$ "..r.stakes.." in play") or "")
        say(player,raw,true,("%s · %s · %s%s · %.1f, %.1f, %.1f · inst %d%s · %s%s"):format(r.id,r.title,r.owner,r.online and (" (#"..r.online..")") or " (offline)",
            r.x,r.y,r.z,r.bucket,r.distance and (" · "..r.distance.." m") or "",r.seatedCount>0 and ("seated: "..r.seated) or "nobody seated",money))
    end
    return true,("Page %d/%d shown."):format(page,pages)
end)
