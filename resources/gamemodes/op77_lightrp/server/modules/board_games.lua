-- The durable board and its inventory item change in the same SQL transaction.
local Inv, Db = LightRP.inventory, LightRP.db
local boards, pending, last, playerBusy = {}, {}, {}, {}
local lastDiagnostic = {}
local loaded, serial, placementBusy = false, 0, false
local REQUEST, STATE, PLACE = "lightrp:boardGames:request", "lightrp:boardGames:state", "lightrp:boardGames:place"
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_board_games (
 id VARCHAR(96) PRIMARY KEY, owner_inventory VARCHAR(96) NOT NULL, data LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
local function notice(player, body)
    LightRP.notice(player, {kind="info", title="Board Games", body=tostring(body)})
end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<100000 end
local function near(player, b, radius)
    local p=Open77.players.position(player)
    return p and (p.bucket or 0)==(b.bucket or 0) and
        (p.x-b.position.x)^2+(p.y-b.position.y)^2+(p.z-b.position.z)^2 <= radius^2
end
local function active(player)
    local inv=Inv.player(player)
    local life=Open77.players.getLifeState(player)
    return inv and inv.persistent and life and life.phase=="alive" and inv or nil
end
local function extra(kind) return LightRP.tabletopExtra and LightRP.tabletopExtra.supports(kind) end
local function newGame(kind,mode)
    if extra(kind) then return LightRP.tabletopExtra.new(kind,mode or "duel") end
    return LightRPBoardRules.new(kind)
end
local function ready(b)
    if LightRP.tabletopExtra and LightRP.tabletopExtra.openPlay(b.kind) then
        for _,id in pairs(b.players) do if active(id) and near(id,b,4) then return true end end
        return false
    end
    local slots=b.mode=="teams" and {"white","black","white2","black2"} or b.mode=="solo" and {"white"} or {"white","black"}
    for _,slot in ipairs(slots) do
        local id=b.players[slot]
        if not id or not active(id) or not near(id,b,4) then return false end
    end
    return true
end
local function actor(b)
    if b.game.status~="playing" or not ready(b) then return nil end
    if b.mode=="solo" and b.game.turn=="black" then return 0 end
    local slot=b.game.seatTurn or b.game.turn
    if not b.game.seatTurn and b.mode=="teams" and math.floor((b.game.ply or 0)/2)%2==1 then slot=slot.."2" end
    return b.players[slot]
end
-- Build 176 can answer a nil or stale position for a player who is in the
-- world, so the bucket comes from the routing table; the client filters by
-- distance itself. An unknown bucket never overwrites the client with an
-- empty list: the push is retried by the board loop instead.
local stateLogged,pushPending={},{}
local function bucketOf(player)
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then
        local bucket=Open77.routingBuckets.getPlayer(player)
        if bucket~=nil then return bucket end
    end
    local p=Open77.players.position(player)
    return p and p.bucket
end
-- The 176 client never delivers a state event carrying several boards (about
-- 15 KB), while small ones arrive. Send numbered parts of at most ~3.5 KB; the
-- client applies the list only once every part of the same sequence is in.
local STATE_PART_BYTES=3500
local stateSeq,encodedLogged={},{}
local function sendState(player,list,bucket)
    local seq=(stateSeq[player] or 0)+1;stateSeq[player]=seq
    local parts,current,size,sizes,kinds={}, {},0,{},{}
    local currentKinds={}
    for _,entry in ipairs(list) do
        local encoded=json.encode(entry)
        local bytes=type(encoded)=="string" and #encoded or STATE_PART_BYTES
        if #current>0 and size+bytes>STATE_PART_BYTES then
            parts[#parts+1]=current;sizes[#sizes+1]=size;kinds[#kinds+1]=table.concat(currentKinds,"+")
            current={};size=0;currentKinds={}
        end
        current[#current+1]=entry;size=size+bytes
        currentKinds[#currentKinds+1]=entry.kind..((entry.game and entry.game.phase) and ("/"..tostring(entry.game.phase)) or "")
        -- Temporary: the client never receives the part holding a blackjack
        -- table in play; log that entry exactly as the server encodes it.
        if entry.kind=="blackjack" and entry.game and entry.game.phase~="betting" then
            local key=tostring(entry.id)..":"..tostring(entry.revision)
            if not encodedLogged[key] then
                encodedLogged[key]=true
                LightRP.log("board_games encoded %s bytes=%d %s",key,type(encoded)=="string" and #encoded or -1,tostring(encoded):sub(1,1900))
            end
        end
    end
    parts[#parts+1]=current;sizes[#sizes+1]=size;kinds[#kinds+1]=table.concat(currentKinds,"+")
    local ok,why=true,nil
    for index,part in ipairs(parts) do
        local sent,reason=TriggerClientEvent(STATE,player,{boards=part,seq=seq,part=index,parts=#parts})
        if sent==false then ok,why=false,reason end
    end
    -- Logged whenever the part layout changes: the client reports the seq and
    -- the missing part numbers when an assembly never completes.
    local layout={}
    for index=1,#parts do layout[index]=index..":"..sizes[index].."B "..kinds[index] end
    local trace=("%d|%s|%s|%s"):format(#list,table.concat(layout,","),tostring(ok),tostring(bucket))
    if stateLogged[player]~=trace then
        stateLogged[player]=trace
        LightRP.log("board_games state push player=%d seq=%d boards=%d parts=%d bucket=%s ok=%s reason=%s layout=%s",player,seq,#list,#parts,
            tostring(bucket),tostring(ok),tostring(why),table.concat(layout," | "))
    end
end
local function push(player)
    local bucket=bucketOf(player)
    if bucket==nil then pushPending[player]=true;return end
    pushPending[player]=nil
    local list={}
    do
        for _,b in pairs(boards) do
            if bucket==(b.bucket or 0) then
                local inv=Inv.player(player)
                local game=b.game
                if extra(b.kind) then game=LightRP.tabletopExtra.view(b,inv) end
                list[#list+1]={id=b.id,kind=b.kind,position=b.position,rotation=b.rotation,
                    owner=b.owner,owned=inv and inv.id==b.ownerInventory or false,
                    players=b.players,revision=b.revision,game=game,mode=b.mode or "duel",serverNow=extra(b.kind) and LightRP.tabletopExtra.now() or nil,
                    ready=ready(b),actor=actor(b),moveSequence=b.moveSequence or 0,lastSound=b.lastSound}
            end
        end
    end
    sendState(player,list,bucket)
end
local function broadcast() for _,id in ipairs(GetPlayers()) do push(tonumber(id)) end end
local function write(b)
    return {query="INSERT INTO lightrp_board_games (id,owner_inventory,data) VALUES (?,?,?) ON DUPLICATE KEY UPDATE data=VALUES(data)",
        values={b.id,b.ownerInventory,json.encode({id=b.id,kind=b.kind,position=b.position,rotation=b.rotation,bucket=b.bucket,game=b.game,revision=b.revision,
            mode=b.mode or "duel",moveSequence=b.moveSequence or 0,lastSound=b.lastSound})}}
end
local function seated(player)
    for _,b in pairs(boards) do for _,id in pairs(b.players) do if id==player then return b end end end
end
local function updatedGame(b,game)
    local n={};for k,v in pairs(b) do n[k]=v end
    n.game=game;n.revision=b.revision+1;n.moveSequence=(b.moveSequence or 0)+1
    local capture=#(game.captured or {})>#(b.game.captured or {})
    n.lastSound=game.status=="won" and "game-win" or b.kind=="connect4" and "connect4-drop" or b.kind..(capture and "-capture" or "-move")
    if extra(b.kind) then n.lastSound="checkers-move" end
    return n
end
local function commitGame(b,game,queries,changes)
    local n=updatedGame(b,game)
    if extra(b.kind) then
        LightRP.log("board_games commit board=%s kind=%s rev=%d->%d phase=%s->%s round=%s->%s queries=%d",b.id,b.kind,b.revision,n.revision,
            tostring(b.game.phase),tostring(game.phase),tostring(b.game.round),tostring(game.round),#(queries or {}))
    end
    local sql={write(n)};for _,query in ipairs(queries or {}) do sql[#sql+1]=query end
    return Inv.commitDrafts(changes or {}, sql, function()
        b.game=game;b.revision=n.revision;b.moveSequence=n.moveSequence;b.lastSound=n.lastSound
    end)
end
local function queueAI(b)
    if extra(b.kind) then return end
    if b.aiPending or b.busy or b.mode~="solo" or actor(b)~=0 then return end
    local token,revision,original={},b.revision,b.game
    local cancelled={}
    b.aiPending=token
    CreateThread(function()
        local function current()
            return boards[b.id]==b and b.aiPending==token and b.revision==revision and
                b.game==original and not b.busy and b.mode=="solo" and actor(b)==0
        end
        local function yieldSearch()
            if not current() then error(cancelled,0) end
            Wait(0)
            if not current() then error(cancelled,0) end
        end
        Wait(450)
        if not current() then if b.aiPending==token then b.aiPending=nil end;return end
        -- Analysis reads an immutable game snapshot. Reset/pickup/leave stay
        -- available between slices; only the short durable commit owns busy.
        local locked=false
        local called,ok,why=pcall(function()
            local game,move=LightRPBoardRules.aiMove(original,yieldSearch)
            if not game then return false,move end
            yieldSearch()
            b.busy=true;locked=true
            return commitGame(b,game)
        end)
        if locked then b.busy=nil end
        if b.aiPending==token then b.aiPending=nil end
        if not called and ok==cancelled then return end
        if not called or not ok then
            local reason=called and (why or "AI move could not be saved.") or tostring(ok)
            LightRP.log("board_games AI failed board=%s kind=%s revision=%s: %s",b.id,b.kind,tostring(revision),tostring(reason))
            if b.players.white and boards[b.id]==b then notice(b.players.white,called and reason or "AI is temporarily unavailable.") end
            return
        end
        -- Publishing is a separate slice from the final rules/SQL work.
        Wait(0)
        if boards[b.id]~=b then return end
        broadcast();queueAI(b)
    end)
end

local function release(player)
    pending[player]=nil
    for _,b in pairs(boards) do
        for side,id in pairs(b.players) do if id==player then b.players[side]=nil end end
        if b.mode=="solo" and not b.players.white then b.aiPending=nil end
        if b.owner==player then b.owner=nil end
    end
    broadcast()
end
local function place(player,p,inv)
    local ticket=pending[player]; local spec=LightRpBoardGames[p.kind]
    if not loaded or not spec or not ticket or ticket.kind~=p.kind or ticket.inventory~=inv.id or LightRP.nowMs()-ticket.at>120000 then return false,"Use your board from the inventory again." end
    local pos=p.position
    if type(pos)~="table" or not finite(pos.x) or not finite(pos.y) or not finite(pos.z) or not finite(p.rotation or 0) then return false,"Invalid position." end
    local here=Open77.players.position(player)
    local candidate={position={x=pos.x,y=pos.y,z=pos.z},bucket=here and here.bucket or 0}
    if not near(player,candidate,4) then return false,"Place the board nearby." end
    for _,b in pairs(boards) do
        if b.bucket==candidate.bucket and (b.position.x-pos.x)^2+(b.position.y-pos.y)^2+(b.position.z-pos.z)^2<1.5^2 then return false,"Another board is too close." end
    end
    local draft=Inv.draft(inv); local found
    for slot,item in pairs(draft.items) do
        if item.name==spec.item then found=true;item.count=item.count-1;if item.count==0 then draft.items[slot]=nil end;break end
    end
    if not found then return false,"You no longer have this board." end
    local id
    repeat serial=serial+1;id=tostring(math.floor(Open77.time.unix()))..":"..serial until not boards[id]
    local b={id=id,kind=p.kind,owner=player,ownerInventory=inv.id,position=candidate.position,
        rotation=p.rotation or 0,bucket=candidate.bucket,players={},revision=0,mode="duel",moveSequence=0,game=newGame(p.kind,"duel")}
    local ok,why=Inv.commitDrafts({{inv,draft}},{write(b)},function() boards[b.id]=b;pending[player]=nil end)
    return ok,why
end
local function handle(player,p,inv)
    if p.action=="place" then return place(player,p,inv) end
    local b=type(p.boardId)=="string" and boards[p.boardId]
    if not b or b.busy then return false,"Board unavailable." end
    if not near(player,b,4) then return false,"Move closer to the board." end
    if p.action=="join" then
        if seated(player) then return false,"You are already in a game." end
        if b.mode=="solo" and inv.id~=b.ownerInventory then return false,"Solo mode is reserved for the board owner." end
        -- A casino table handler may declare seats=4 (blackjack) without the teams mode.
        local four=extra(b.kind) and LightRP.tabletopExtra.games[b.kind].seats==4
        local slots=(b.mode=="teams" or four) and {"white","black","white2","black2"} or b.mode=="solo" and {"white"} or {"white","black"}
        local available
        for _,slot in ipairs(slots) do if not b.players[slot] then available=slot;break end end
        if not available then return false,"All seats are already taken." end
        b.players[available]=player
        return true
    end
    b.busy=true
    local called,ok,why=pcall(function()
        if p.action=="mode" or p.action=="reset" then
            if inv.id~=b.ownerInventory then return false,"Only the owner can configure this board." end
            if p.action=="mode" and (b.game.ply or 0)>0 then return false,"Start a new game before changing the mode." end
            if p.action=="mode" and b.kind=="checkers" and b.game.chain then return false,"Finish the current game before changing the mode." end
            local mode=p.action=="reset" and (b.mode or "duel") or p.mode
            if mode~="duel" and mode~="teams" and mode~="solo" then return false,"Invalid game mode." end
            local n={};for k,v in pairs(b) do n[k]=v end
            local refunds,reason={}
            if extra(b.kind) then refunds,reason=LightRP.tabletopExtra.refunds(b) end
            if not refunds then return false,reason end
            n.mode=mode;n.game=newGame(b.kind,mode);n.revision=b.revision+1
            local queries={write(n)};for _,query in ipairs(refunds) do queries[#queries+1]=query end
            return Inv.commitDrafts({}, queries, function()
                local wasSeated=seated(player)==b
                for _,id in pairs(b.players) do if id~=player then notice(id,"The owner started a new game. Press E to rejoin.") end end
                b.mode=mode;b.game=n.game;b.revision=n.revision;b.aiPending=nil;b.players=wasSeated and {white=player} or {}
            end)
        elseif p.action=="pickup" then
            if inv.id~=b.ownerInventory then return false,"Only the owner can pick up this board." end
            local item=LightRpBoardGames[b.kind].item
            local can,reason=Inv.canHold(inv,item,1); if not can then return false,reason end
            local draft=Inv.draft(inv); local slot
            for i=1,draft.slots do if not draft.items[i] then slot=i;break end end
            if not slot then return false,"Inventory full." end
            draft.items[slot]={name=item,count=1}
            local refunds,reason={}
            if extra(b.kind) then refunds,reason=LightRP.tabletopExtra.refunds(b) end
            if not refunds then return false,reason end
            local queries={{query="DELETE FROM lightrp_board_games WHERE id=?",values={b.id}}};for _,query in ipairs(refunds) do queries[#queries+1]=query end
            return Inv.commitDrafts({{inv,draft}},queries,function() boards[b.id]=nil end)
        elseif p.action=="game" and extra(b.kind) then
            if not ready(b) then return false,"The table is not ready." end
            if p.revision~=b.revision then return false,"The table has changed. Try again." end
            return LightRP.tabletopExtra.act(player,b,p.operation,p.data or {},function(game,queries,changes) return commitGame(b,game,queries,changes) end)
        elseif p.action=="move" then
            if actor(b)~=player then return false,"It is not your turn or a player is missing." end
            if p.revision~=b.revision then return false,"The board has changed. Try again." end
            local game,reason=LightRPBoardRules.move(b.game,p.fromRow,p.fromCol,p.toRow,p.toCol,p.promotion)
            if not game then return false,reason end
            return commitGame(b,game)
        end
        return false,"Unknown action."
    end)
    b.busy=nil
    return called and ok==true,called and why or "Save failed."
end
for kind,spec in pairs(LightRpBoardGames) do
    local gameKind=kind
    Inv.onUse(spec.item,function(player)
        local inv=active(player)
        if not loaded or not inv then notice(player,"Board storage is unavailable.");return false end
        pending[player]={kind=gameKind,inventory=inv.id,at=LightRP.nowMs()}
        LightRP.log("board_games use player=%d item=%s kind=%s: placement ticket issued",player,spec.item,gameKind)
        TriggerClientEvent(PLACE,player,{kind=gameKind})
        return "keep"
    end)
end
RegisterNetEvent(REQUEST,function(p)
    local player=tonumber(source)
    if not player or player<=0 or type(p)~="table" then return end
    local now=LightRP.nowMs()
    if p.action=="diagnostic" then
        if (p.event~="stop" and p.event~="render" and p.event~="trace") or type(p.reason)~="string" or #p.reason>64 then return end
        lastDiagnostic[player]=lastDiagnostic[player] or {}
        local budget=lastDiagnostic[player]
        if p.event=="trace" then
            -- Client traces: up to 40 per 10 s per player, every reason.
            if not budget.window or now-budget.window>10000 then budget.window=now;budget.count=0 end
            budget.count=budget.count+1
            if budget.count>40 then return end
        else
            -- One diagnostic per reason per second, so a render summary cannot hide the state trace.
            if budget[p.reason] and now-budget[p.reason]<1000 then return end
            budget[p.reason]=now
        end
        local function clean(value,limit) return tostring(value or ""):sub(1,limit):gsub("[%c]"," ") end
        LightRP.log("board_games client %s player=%d board=%s reason=%s details=%s",p.event,player,clean(p.boardId,96),clean(p.reason,64),clean(p.details,180))
        return -- Diagnostics must not consume the gameplay action rate budget.
    end
    -- Leaving never waits: it touches no inventory and a busy, rate-limited or
    -- settling table must not keep a player seated against their will.
    if p.action=="leave" then
        local b=type(p.boardId)=="string" and boards[p.boardId]
        local left=0
        for _,board in pairs(b and {b} or boards) do
            for side,id in pairs(board.players) do if id==player then board.players[side]=nil;left=left+1 end end
        end
        LightRP.log("board_games leave player=%d board=%s seats=%d",player,tostring(p.boardId),left)
        broadcast()
        return
    end
    local function dropped(why)
        if p.action~="sync" then LightRP.log("board_games dropped %s player=%d board=%s op=%s: %s",tostring(p.action),player,tostring(p.boardId),tostring(p.operation),why) end
    end
    if playerBusy[player] then dropped("previous request still running");return end
    if last[player] and now-last[player]<150 then dropped("rate limit 150 ms");return end
    last[player]=now
    if p.action=="sync" then push(player);return end
    local inv=active(player)
    if not loaded then dropped("board storage not loaded");return end
    if not inv then dropped("inventory not persistent or character not alive");return end
    if inv.busy then dropped("inventory busy");return end
    if p.action=="place" and placementBusy then notice(player,"Another placement is in progress. Try again.");return end
    if p.action=="place" then placementBusy=true end
    playerBusy[player]=true;inv.busy=true
    local called,ok,why=pcall(handle,player,p,inv)
    if p.action=="join" or p.action=="leave" or p.action=="place" or p.action=="game" then
        LightRP.log("board_games %s player=%d board=%s kind=%s op=%s ok=%s reason=%s",p.action,player,tostring(p.boardId),tostring(p.kind),
            tostring(p.operation),tostring(called and ok),tostring(called and why or ok))
    end
    if p.action=="place" then placementBusy=false end
    if Inv.releaseBusy then Inv.releaseBusy(inv) else inv.busy=nil end
    playerBusy[player]=nil
    if not called or not ok then notice(player,called and (why or "Action denied.") or "Storage unavailable.") end
    broadcast()
    for _,b in pairs(boards) do queueAI(b) end
end)
-- Temporary network probe: the 176 client silently drops the state part that
-- holds a blackjack table in play. Each probe isolates one shape; the client
-- traces the ones it receives (probe_received), so the missing ids name it.
if LightRP.command then LightRP.command("lightrp.netprobe", { restricted = true, usage = "/lightrp.netprobe" }, function(source)
    local player=tonumber(source)
    if not player or player<1 then return false,"Run it in game." end
    local now=LightRP.nowMs()
    local hand={betAt=now,bet=25,total=8,cards={{t=now,c="6D"},{t=now+900,c="2H"}},stake=25,soft=false}
    local function sample(hole)
        return {lastSound="checkers-move",serverNow=now,revision=10,moveSequence=10,ready=true,players={white=player},mode="duel",
            game={phase="playing",animEnd=now+2000,mode="duel",dealtAt=now,hands={white=hand},ply=10,
                dealer={total=9,cards={{t=now+400,c="9C"},hole},soft=false},captured={},status="playing",shuffledAt=now,
                actAt=now+2000,seatTurn="white",turnEndsAt=now+22000,objects={},round=3,kind="blackjack",shoe={left=302,cut=false,total=312}},
            id="probe",position={x=0,y=0,z=0},owned=true,rotation=0,kind="blackjack",actor=player}
    end
    -- Depth ladder: depthN nests N tables below the payload (the event
    -- arguments array adds one more level on the wire).
    local function nested(depth) local t={v=1};for _=2,depth do t={a=t} end;return t end
    local probes={}
    for depth=4,10 do probes[#probes+1]={id="depth"..depth,n=nested(depth)} end
    local noHands=sample({h=true,t=now+1300});noHands.game.hands={}
    local noDealer=sample({h=true,t=now+1300});noDealer.game.dealer={total=9,soft=false}
    probes[#probes+1]={id="sample",boards={sample({h=true,t=now+1300})}}
    probes[#probes+1]={id="sample_nohands",boards={noHands}}
    probes[#probes+1]={id="sample_nodealer",boards={noDealer}}
    for _,payload in ipairs(probes) do
        local ok,why=TriggerClientEvent("lightrp:boardGames:probe",player,payload)
        LightRP.log("board_games netprobe sent %s ok=%s %s",payload.id,tostring(ok),tostring(why))
    end
    return true,"Sent "..#probes.." network probes; see the server log."
end) end
LightRP.module("board_games",{
    onDatabaseReady=function()
        local ok,rows=Db.read("SELECT id,owner_inventory,data FROM lightrp_board_games",{})
        if not ok then return end
        for _,row in ipairs(rows) do
            local decoded,b=pcall(json.decode,row.data)
            if decoded and type(b)=="table" and LightRpBoardGames[b.kind] and type(b.game)=="table" and type(b.position)=="table" then
                b.id=row.id;b.ownerInventory=row.owner_inventory;b.players={};b.owner=nil;b.mode=b.mode or "duel"
                boards[b.id]=b
            end
        end
        loaded=true;broadcast()
    end,
    onUiReady=push,
    onDisconnected=function(player) last[player]=nil;lastDiagnostic[player]=nil;stateLogged[player]=nil;pushPending[player]=nil;stateSeq[player]=nil;release(player) end,
    onCharacterLoaded=release,
    onLifeState=function(player) if not active(player) then release(player) end end,
})
AddEventHandler("onPlayerBucketChange",function(player) release(tonumber(player)) end)
local refreshTick=0
CreateThread(function()
    while true do
        Wait(2000)
        local changed=false
        for _,b in pairs(boards) do
            for side,id in pairs(b.players) do if not active(id) or not near(id,b,5) then b.players[side]=nil;changed=true end end
        end
        refreshTick=refreshTick+1
        if changed or refreshTick%5==0 then broadcast() end -- a lost part heals within 10 s
        for player in pairs(pushPending) do push(player) end
        for _,b in pairs(boards) do queueAI(b) end
        local X=LightRP.tabletopExtra
        for _,b in pairs(boards) do
            local h=X and X.games[b.kind]
            if h and h.due and not b.busy and h.due(b,X.now()) then
                LightRP.log("board_games due board=%s kind=%s phase=%s rev=%d",b.id,b.kind,tostring(b.game.phase),b.revision)
                b.busy=true
                local called,ok,why=pcall(function()
                    local game,queries=h.settle(b,X.now())
                    if game then return commitGame(b,game,queries) end
                    LightRP.log("board_games settle board=%s kind=%s returned no game: %s",b.id,b.kind,tostring(queries))
                end)
                b.busy=nil
                if called and ok then broadcast() end
                if not called or (ok==false) then LightRP.log("%s settlement failed board=%s: %s",b.kind,b.id,tostring(called and why or ok)) end
            end
        end
    end
end)
