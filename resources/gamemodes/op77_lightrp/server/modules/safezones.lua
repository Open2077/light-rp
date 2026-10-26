local S,G=LightRP.safezones,LightRpSafezoneGeometry
local NET="op77_lightrp:safezones"
local buckets,arbiter={},nil
local lastError=-1000
function S.rebuild()
    local built={}
    if type(Open77.zones)~="table" or type(Open77.zones.normalize)~="function" or type(Open77.zones.containsPlayer)~="function" then return false,"The server zone API is unavailable." end
    for _,zone in pairs(S.records) do
        if zone.enabled and not zone.deleted then
            local prepared,why=Open77.zones.normalize(G.definition(zone))
            if not prepared then return false,"Invalid safezone geometry: "..tostring(why) end
            built[zone.bucket]=built[zone.bucket] or {}
            built[zone.bucket][#built[zone.bucket]+1]={zone=zone,prepared=prepared}
        end
    end
    buckets=built
    return true
end
function S.snapshot(player)
    TriggerClientEvent(NET,player or -1,{kind="snapshot",ready=S.available,zones=S.list(),generation=S.generation})
end
local function playerBucket(player)
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then return Open77.routingBuckets.getPlayer(player) end
    return GetPlayerRoutingBucket(player)
end
-- A third return value distinguishes an unknown/stale read from a known exit.
function S.protected(player)
    local bucket=playerBucket(player)
    if not G.integer(bucket,0,2147483647) then return nil,false,true end
    local list=buckets[bucket]
    if not list then return nil,false,false end
    local selected,unknown=nil,false
    local policy={blockRun=false,blockShoot=false}
    local position
    for _,entry in ipairs(list) do
        local options={bucket=bucket,maxAgeMs=2000,grace=0}
        if entry.zone.fullHeight and entry.zone.shape~="poly" then
            position=position or G.point(Open77.players.position(player))
            if not position then return nil,false,true end
            options.origin=G.origin(entry.zone,position)
        end
        local inside,why=Open77.zones.containsPlayer(player,entry.prepared,options)
        if inside==nil then unknown=true end
        if inside then
            if not selected or entry.zone.id<selected.id then selected=entry.zone end
            policy.blockRun=policy.blockRun or entry.zone.blockRun==true
            policy.blockShoot=policy.blockShoot or entry.zone.blockShoot~=false
        end
    end
    return selected,selected~=nil,unknown,policy
end
local function arbitrate(event)
    if type(event)~="table" then return nil end
    local victim,attacker=tonumber(event.victim),tonumber(event.attacker)
    -- The MVP is PvP only; starvation, falling and uncredited world damage retain their policy.
    if not victim or victim<=0 or not attacker or attacker<=0 or attacker==victim then return nil end
    if not S.available then return false end
    local _,victimInside,victimUnknown=S.protected(victim)
    local _,attackerInside,attackerUnknown=S.protected(attacker)
    if victimInside or attackerInside or victimUnknown or attackerUnknown then return false end
    return nil
end
S.arbitrate=arbitrate
local function guarded(event)
    local ok,verdict=pcall(arbitrate,event)
    if ok then return verdict end
    local at=Open77.time.monotonic()
    if at-lastError>10 then LightRP.log("safezone arbiter failed; damage refused: %s",tostring(verdict));lastError=at end
    return false
end
local function install()
    if type(Open77.combat)~="table" or type(Open77.combat.onDamage)~="function" then return false,"The server damage arbiter API is unavailable." end
    local ok,handle,why=pcall(Open77.combat.onDamage,guarded)
    if not ok or not handle then return false,tostring(why or handle) end
    arbiter=handle
    return true
end
local installed,installError=install()
if not installed then LightRP.log("safezones unavailable: %s",installError) end
local lastPresence={}
function S.presence(player)
    local ok,zone,inside,unknown,policy=pcall(S.protected,player)
    local ready=S.available and ok and not unknown
    local key=(ready and "ready:" or "unavailable:")..(inside and zone and (zone.id..":"..zone.label..":"..tostring(policy.blockRun)..":"..tostring(policy.blockShoot)) or "")
    if lastPresence[player]==key then return end
    lastPresence[player]=key
    TriggerClientEvent(NET,player,{kind="presence",ready=ready,zone=ready and inside and {id=zone.id,label=zone.label,blockRun=policy.blockRun,blockShoot=policy.blockShoot} or nil})
end
LightRP.module("safezones",{
    onDatabaseReady=function()
        local ok,why=S.load()
        if ok then ok,why=S.rebuild() end
        S.ready=ok==true
        S.available=S.ready and installed
        if not S.available then LightRP.log("safezones unavailable: %s",tostring(why or installError)) else LightRP.log("safezones ready: %d published zone(s)",#S.list()) end
        S.snapshot()
    end,
    onConnected=function(player) lastPresence[player]=nil;S.snapshot(player) end,
    onUiReady=function(player) lastPresence[player]=nil;S.snapshot(player);S.presence(player) end,
    onDisconnected=function(player) lastPresence[player]=nil end,
})
CreateThread(function()
    while true do
        for _,raw in ipairs(GetPlayers()) do S.presence(tonumber(raw)) end
        Wait(500)
    end
end)
AddEventHandler("onResourceStop",function(name)
    if name~=GetCurrentResourceName() then return end
    if arbiter and Open77.combat and Open77.combat.offDamage then pcall(Open77.combat.offDamage,arbiter) end
    S.available=false
end)
