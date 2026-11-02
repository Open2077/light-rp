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
    if extra(kind) then return LightRpTabletopExtraRules.new(kind,mode or "duel") end
    return LightRPBoardRules.new(kind)
end
local function ready(b)
    if b.kind=="roulette" then
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
local function push(player)
    local p=Open77.players.position(player); local list={}
    if p then
        for _,b in pairs(boards) do
            if (p.bucket or 0)==b.bucket then
                local inv=Inv.player(player)
                local game=b.game
                if extra(b.kind) then
                    game=LightRpTabletopExtraRules.view(b.game)
                    if b.kind=="roulette" then
                        game.yourStake=0
                        for _,bet in ipairs(b.game._money or {}) do if inv and bet.inventory==inv.id then game.yourStake=game.yourStake+bet.amount end end
                    end
                end
                list[#list+1]={id=b.id,kind=b.kind,position=b.position,rotation=b.rotation,
                    owner=b.owner,owned=inv and inv.id==b.ownerInventory or false,
                    players=b.players,revision=b.revision,game=game,mode=b.mode or "duel",serverNow=extra(b.kind) and LightRP.tabletopExtra.now() or nil,
                    ready=ready(b),actor=actor(b),moveSequence=b.moveSequence or 0,lastSound=b.lastSound}
            end
        end
    end
    TriggerClientEvent(STATE,player,{boards=list})
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
    local sql={write(n)};for _,query in ipairs(queries or {}) do sql[#sql+1]=query end
    return Inv.commitDrafts(changes or {}, sql, function()
        b.game=game;b.revision=n.revision;b.moveSequence=n.moveSequence;b.lastSound=n.lastSound
    end)
end
local function queueAI(b)
    if b.kind=="roulette" then return end
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
    if p.action=="leave" then
        for side,id in pairs(b.players) do if id==player then b.players[side]=nil end end
        return true
    end
    if not near(player,b,4) then return false,"Move closer to the board." end
    if p.action=="join" then
        if seated(player) then return false,"You are already in a game." end
        if b.mode=="solo" and inv.id~=b.ownerInventory then return false,"Solo mode is reserved for the board owner." end
        local slots=b.mode=="teams" and {"white","black","white2","black2"} or b.mode=="solo" and {"white"} or {"white","black"}
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
        TriggerClientEvent(PLACE,player,{kind=gameKind})
        return "keep"
    end)
end
RegisterNetEvent(REQUEST,function(p)
    local player=tonumber(source)
    if not player or player<=0 or type(p)~="table" then return end
    local now=LightRP.nowMs()
    if p.action=="diagnostic" then
        if (p.event~="stop" and p.event~="render") or type(p.reason)~="string" or #p.reason>64 or (lastDiagnostic[player] and now-lastDiagnostic[player]<1000) then return end
        lastDiagnostic[player]=now
        local function clean(value,limit) return tostring(value or ""):sub(1,limit):gsub("[%c]"," ") end
        LightRP.log("board_games client %s player=%d board=%s reason=%s details=%s",p.event,player,clean(p.boardId,96),clean(p.reason,64),clean(p.details,180))
        return -- Diagnostics must not consume the gameplay action rate budget.
    end
    if playerBusy[player] then return end
    if last[player] and now-last[player]<150 then return end
    last[player]=now
    if p.action=="sync" then push(player);return end
    local inv=active(player)
    if not loaded or not inv or inv.busy then return end
    if p.action=="place" and placementBusy then notice(player,"Another placement is in progress. Try again.");return end
    if p.action=="place" then placementBusy=true end
    playerBusy[player]=true;inv.busy=true
    local called,ok,why=pcall(handle,player,p,inv)
    if p.action=="place" then placementBusy=false end
    if Inv.releaseBusy then Inv.releaseBusy(inv) else inv.busy=nil end
    playerBusy[player]=nil
    if not called or not ok then notice(player,called and (why or "Action denied.") or "Storage unavailable.") end
    broadcast()
    for _,b in pairs(boards) do queueAI(b) end
end)
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
    onDisconnected=function(player) last[player]=nil;lastDiagnostic[player]=nil;release(player) end,
    onCharacterLoaded=release,
    onLifeState=function(player) if not active(player) then release(player) end end,
})
AddEventHandler("onPlayerBucketChange",function(player) release(tonumber(player)) end)
CreateThread(function()
    while true do
        Wait(2000)
        local changed=false
        for _,b in pairs(boards) do
            for side,id in pairs(b.players) do if not active(id) or not near(id,b,5) then b.players[side]=nil;changed=true end end
        end
        if changed then broadcast() end
        for _,b in pairs(boards) do queueAI(b) end
        for _,b in pairs(boards) do
            if b.kind=="roulette" and b.game.phase=="spinning" and not b.busy and LightRP.tabletopExtra.now()>=b.game.spin.endsAt then
                b.busy=true
                local called,ok,why=pcall(function()
                    local game=LightRpTabletopExtraRules.act(b.game,"white","settle",{nowMs=LightRP.tabletopExtra.now()})
                    if game then return commitGame(b,game) end
                end)
                b.busy=nil
                if called and ok then broadcast() end
                if not called or (ok==false) then LightRP.log("roulette settlement failed board=%s: %s",b.id,tostring(called and why or ok)) end
            end
        end
    end
end)
