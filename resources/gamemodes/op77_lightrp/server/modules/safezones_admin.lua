local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
local S,G,Db=LightRP.safezones,LightRpSafezoneGeometry,LightRP.db
local NET="op77_lightrp:safezones"
local sessions,lastRequest,sequence={},{},0
local function now() return Open77.time.monotonic() end
function S.invalidate(player,reason)
    sessions[player]=nil
    TriggerClientEvent(NET,player,{kind="invalidate",error=reason or "Your editing session ended."})
end
local function position(player)
    local p=Open77.players.position(player)
    if not p or not G.point(p) then return nil end
    local bucket=Open77.routingBuckets and Open77.routingBuckets.getPlayer and Open77.routingBuckets.getPlayer(player) or GetPlayerRoutingBucket(player)
    if not G.integer(bucket,0,2147483647) then return nil end
    return G.point(p),bucket
end
local function validSession(player,key)
    local s=sessions[player]
    if not s or type(key)~="string" or s.id~=key or now()>s.expires then return nil,"Capture your position to start a new editing session." end
    if not S.allowed(player,"edit") then S.invalidate(player,"Your zone editing permission was removed.");return nil,"Zone editing permission denied." end
    local p,bucket=position(player)
    if not p or bucket~=s.bucket or G.distance(p,s.anchor)>G.AUTHOR_RADIUS then S.invalidate(player,"Your position or routing bucket changed. Capture a new session.");return nil,"Editing session is no longer valid." end
    return s
end
local function capture(player,key)
    if not S.allowed(player,"edit") then return nil,"Zone editing permission denied." end
    local p,bucket=position(player)
    if not p then return nil,"Your current server position is unavailable." end
    local s=sessions[player]
    if not s or key~=s.id or s.bucket~=bucket or now()>s.expires then
        sequence=sequence+1
        s={id=("zone:%d:%d:%d"):format(player,sequence,math.floor(now()*1000)),bucket=bucket,anchor=p}
        sessions[player]=s
    end
    if G.distance(p,s.anchor)>G.AUTHOR_RADIUS then return nil,"Move closer to the editing anchor or cancel before starting elsewhere." end
    s.expires=now()+300
    return {position=p,bucket=bucket,session=s.id}
end
local function mutationKey(value)
    return type(value)=="string" and #value>=8 and #value<=96 and value:match("^[%w:_%-]+$") and value or nil
end
local function publish(player,p,action)
    if not S.allowed(player,"edit") or not S.allowed(player,action=="delete" and "delete" or "publish") then return nil,"Zone publication permission denied." end
    local session,why=validSession(player,p.session);if not session then return nil,why end
    if not S.available or not Db.ready then return nil,"Safezone protection/storage is unavailable. Nothing was changed." end
    local mutation=mutationKey(p.mutation)
    local actor=S.actor(player)
    if not mutation or not actor then return nil,"Invalid zone publication request." end
    local id=action=="delete" and p.id or type(p.zone)=="table" and p.zone.id
    if not G.integer(p.baseRevision,0,2147483646) then return nil,"Invalid zone revision." end
    local previous,err=S.previous(actor,mutation,action,id)
    if previous==nil then return nil,err end
    if previous then return previous end
    session,why=validSession(player,p.session);if not session then return nil,why end
    if not S.allowed(player,action=="delete" and "delete" or "publish") then return nil,"Your publication permission changed." end
    local old=id and S.records[id]
    if old and (old.deleted or old.revision~=p.baseRevision) then return nil,"This zone changed. Refresh before publishing." end
    if not old and p.baseRevision~=0 then return nil,"This zone no longer exists. Refresh the list." end
    local zone
    if action=="delete" then
        if not old then return nil,"This zone no longer exists." end
        zone=G.clone(old)
    else
        zone,why=G.validate(p.zone);if not zone then return nil,why end
        if zone.bucket~=session.bucket or not G.withinAnchor(zone,session.anchor) then return nil,"The zone must stay within 500 metres of this editing session and in its bucket." end
        if not old then
            if id and id~="" then return nil,"New zones cannot supply an ID." end
            if #S.list()>=G.MAX_ZONES then return nil,"The server safezone limit has been reached." end
            local ok,rows=Db.read("SELECT UUID() AS id")
            if not ok or not rows[1] or type(rows[1].id)~="string" then return nil,"Could not allocate a zone ID." end
            zone.id=rows[1].id
        end
        local prepared,reason=Open77.zones.normalize(G.definition(zone))
        if not prepared then return nil,"The platform rejected the geometry: "..tostring(reason) end
    end
    zone.revision=(old and old.revision or 0)+1
    local result,error=S.persist(actor,mutation,action,zone,p.baseRevision)
    if not result then return nil,error end
    local rebuilt,rebuildError=S.rebuild()
    if not rebuilt then S.available=false;LightRP.log("safezone cache unavailable after publication: %s",tostring(rebuildError)) end
    S.snapshot()
    return result
end
local function dispatch(player,p)
    local operation=p.operation
    if operation=="snapshot" then S.snapshot(player);S.presence(player);return {} end
    if not S.allowed(player,"view") then return nil,"Zone viewing permission denied." end
    if operation=="open" then TriggerClientEvent(NET,player,{kind="open"});return {} end
    if operation=="list" then return {zones=S.list(),permissions=S.permissions(player),ready=S.available} end
    if operation=="cancel" then sessions[player]=nil;return {} end
    if operation=="capture" then return capture(player,p.session) end
    if operation=="heartbeat" then
        local s,why=validSession(player,p.session);if not s then return nil,why end
        s.expires=now()+300;return {session=s.id}
    end
    if operation=="save" or operation=="delete" then return publish(player,p,operation=="delete" and "delete" or "save") end
    return nil,"Unknown zone operation."
end
RegisterNetEvent(NET,function(p)
    local player=tonumber(source)
    if not player or player<=0 or type(p)~="table" or type(p.request)~="string" or #p.request<1 or #p.request>96 or type(p.operation)~="string" then return end
    local at=now()
    if lastRequest[player] and at-lastRequest[player]<0.15 then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Please wait before the next zone request."});return end
    lastRequest[player]=at
    local write=p.operation=="save" or p.operation=="delete"
    if write and S.writing then TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=false,error="Another zone publication is in progress. Your draft is kept."});return end
    if write then S.writing=true end
    local ok,data,error=pcall(dispatch,player,p)
    if write then S.writing=false end
    if not ok then LightRP.log("safezone request failed: %s",tostring(data));data,error=nil,"The server could not complete this zone request." end
    TriggerClientEvent(NET,player,{kind="response",request=p.request,ok=data~=nil,data=data,error=error})
end)
LightRP.command("safezones",{restricted=true},function(player)
    if not S.allowed(player,"view") then return false,"Zone viewing permission denied." end
    TriggerClientEvent(NET,player,{kind="open"})
    return true,"Safezone manager opened."
end)
AddEventHandler("onPlayerDisconnected",function(raw) local player=tonumber(raw);sessions[player]=nil;lastRequest[player]=nil end)
CreateThread(function()
    lightrpEvery(2000, function()
        local expired={}
        for player,s in pairs(sessions) do
            local p,bucket=position(player)
            if now()>s.expires or not S.allowed(player,"edit") or not p or bucket~=s.bucket or G.distance(p,s.anchor)>G.AUTHOR_RADIUS then expired[#expired+1]=player end
        end
        for _,player in ipairs(expired) do S.invalidate(player,"Your editing session expired or your position/access changed.") end
        
    end, "safezones_admin:118")
end)
