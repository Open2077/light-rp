-- The ALT target menu of every placed table (chess, checkers, Connect Four and
-- the casino tables): table MANAGEMENT only. Standing at a table it lists the
-- status, Sit, and for the owner the game mode (before the first move), New
-- game and Pick up. Playing happens in the game view (client/core/board_games.lua:
-- scripted camera, cursor picking on the table, the bottom bar of
-- client/core/table_bar.lua); there the page owns the cursor, which keeps the
-- target menu closed (the platform's cursor reads as captured), so the seated
-- rows below (Leave) are only a fallback. State changes arrive as notices
-- from observe(); the bar and the notices share the helpers exported here.
--
-- One open77_contextmenu registration with dynamic rows (>= 1.3.0): the menu
-- calls tableMenuRows(ctx) for the clicked target and tableMenuSelect(ctx)
-- with ctx.action.key. Both build the same rows from the same state, so a row
-- that is no longer valid cannot run. Every request is one the server already
-- validates (lightrp:boardGames:request join, mode, reset, pickup).
-- Targets: the table's props, the surfaces around it, and its own NPC (the
-- blackjack croupier, whose id the server publishes as board.npc).
-- The client budget is ~10k instructions per resume and this runs on every
-- ALT click on a table: a few rows, no searches.
local Ui=LightRpUi
local Client=LightRpBoardGamesClient
local Extra=LightRpTabletopExtraClient
local M={}
LightRpTableMenu=M
local REACH=3          -- metres from the player to the clicked point (menu distance)
local TABLE_REACH=4    -- metres from the player to the table (the server's own check)
local PICKUP_REACH=2
local cash -- the last RP cash the server reported (nil: unknown, nothing filtered)
function M.cash() return cash end
local function title(board) return (LightRpBoardGames[board.kind] or {}).title or "Table" end
local function money(n)
    local s=tostring(math.floor(tonumber(n) or 0))
    local out=s:reverse():gsub("(%d%d%d)","%1,"):reverse()
    return "€$ "..out:gsub("^,","")
end
M.money=money
local function notify(board,text) Client.notice(text,title(board)) end
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end

-- Rows ------------------------------------------------------------------------
local MODES={{"solo","Solo vs AI"},{"duel","1v1"},{"teams","2v2"}}
local MODE_LABEL={solo="Solo vs AI",duel="1v1",teams="2v2"}
local POOL_MODES={{"solo","Solo practice"},{"duel","1v1"}}
local POOL_LABEL={solo="Solo practice",duel="1v1"}
local status -- defined with the board helpers below
local function rowsFor(board,ctx)
    local list,runs={},{}
    local m={}
    function m.row(key,label,run,options)
        if #list>=24 then return end
        local row={key=key,label=label,icon=options and options.icon or "interact",
            submenu=options and options.submenu,description=options and options.description}
        list[#list+1]=row;runs[key]=run
    end
    local seated=Client.member(board)~=nil and Client.seated()==board
    local text=status(board)
    if text then m.row("status",text,function() notify(board,text..".") end,{icon="info"}) end
    if not seated and not Client.isActive() and M.freeSeat(board) then
        m.row("sit","Sit",function() return Client.request("join",{boardId=board.id})==true end,{icon="person"})
    end
    if seated then m.row("leave","Leave table",function() return Client.leave("menu_leave") end,{icon="person"}) end
    -- The owner configures the table from here too (the bar has the same
    -- buttons once seated): mode before the first move, else New game.
    if board.owned and (board.kind=="pool" or LightRpBoardGames[board.kind] and not Extra.supports(board.kind)) then
        local g=board.game
        local pool=board.kind=="pool"
        if (g.ply or 0)==0 and not g.chain then
            local current=board.mode or "duel"
            local folder={id="mode",label="Mode: "..((pool and POOL_LABEL or MODE_LABEL)[current] or current),icon="tool"}
            for _,mode in ipairs(pool and POOL_MODES or MODES) do if mode[1]~=current then
                m.row("mode."..mode[1],mode[2],function() return Client.request("mode",{boardId=board.id,mode=mode[1]})==true end,{submenu=folder,icon="tool"})
            end end
        elseif not (pool and LightRpPoolClient.busy(board)) then
            m.row("reset","New game",function() return Client.request("reset",{boardId=board.id})==true end,{icon="tool"})
        end
    end
    local character=Open77.character.state()
    if board.owned and character and character.position and distance(character.position,board.position)<=PICKUP_REACH then
        m.row("pickup","Pick up board",function() return Client.request("pickup",{boardId=board.id})==true end,{icon="tool"})
    end
    return list,runs
end
-- Whether a seat is free for the local player (same slots as the server).
function M.freeSeat(board)
    if board.mode=="solo" and not board.owned then return false end
    local slots=(board.mode=="teams" or board.kind=="blackjack") and {"white","black","white2","black2"}
        or board.mode=="solo" and {"white"} or {"white","black"}
    local players=board.players or {}
    for _,slot in ipairs(slots) do if players[slot]==nil then return true end end
    return false
end
-- The table a menu context points at, and how it was found (for the trace):
--   "prop":    the clicked native prop (base, collider or piece);
--   "dealer":  the table's own NPC (the blackjack croupier stands behind the
--              table and in the context ray: its hitbox is what an ALT click
--              on the far half of the felt, the shoe or the chip rack hits);
--   "surface": a surface hit next to a rendered table (and an NPC hit next to
--              a dealer table whose NPC id is not known yet).
-- Answers nil and why not.
local DEALER_KINDS={blackjack=true}
local function nearestTable(position,dealerOnly)
    local best,board=1.4,nil
    for _,candidate in pairs(Client.boards) do
        local p=candidate.position
        local d=math.sqrt((p.x-position.x)^2+(p.y-position.y)^2)
        if d<best and math.abs(p.z-position.z)<2.5 and Client.isRendered(candidate)
            and (not dealerOnly or DEALER_KINDS[candidate.kind]) then best,board=d,candidate end
    end
    return board
end
local function boardFor(ctx)
    if GetInvokingResource()~="open77_contextmenu" or type(ctx)~="table" or type(ctx.target)~="table" then return nil,"caller" end
    if not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode then return nil,"ui_busy" end
    for name,open in pairs(Ui.dialogs or {}) do if open and name~="boardGames" then return nil,"dialog_"..tostring(name) end end
    local character=Open77.character.state()
    if not character or character.alive~=true or character.attached~=true or not character.position then return nil,"character" end
    local target=ctx.target
    local board,how
    if target.kind=="prop" and target.networked==false then
        board=Client.boardOfProp(target.propId);how=board and "prop"
    elseif target.kind=="npc" then
        local npc=tonumber(target.npcId)
        if npc then for _,candidate in pairs(Client.boards) do
            if tonumber(candidate.npc)==npc then board,how=candidate,"dealer";break end
        end end
    end
    if not board and type(ctx.position)=="table" and ctx.hasSurface~=false then
        -- Any other NPC (a passer-by) is not a table: only a dealer table answers it.
        board=nearestTable(ctx.position,target.kind=="npc");how=board and "surface"
    end
    if not board then return nil,"no_table" end
    if distance(character.position,board.position)>TABLE_REACH then return nil,"far" end
    return board,how
end
M.boardFor=boardFor
-- What the ALT click hit, in the server log (at most one per 1.5 s, and only
-- near a table): a live test shows why a table did or did not answer.
local lastTargetTrace=-100000
local function traceTarget(ctx,board,how)
    local now=GetGameTimer()
    if now-lastTargetTrace<1500 or type(ctx)~="table" or type(ctx.target)~="table" then return end
    if not board then
        local character=Open77.character.state()
        local here=character and character.position
        local near=false
        if here then for _,candidate in pairs(Client.boards) do
            if distance(here,candidate.position)<=TABLE_REACH+1 then near=true;break end
        end end
        if not near then return end
    end
    lastTargetTrace=now
    local t=ctx.target
    Client.trace("menu_target",board and board.id,"kind=%s prop=%s npc=%s networked=%s record=%s via=%s board=%s",
        tostring(t.kind),tostring(t.propId),tostring(t.npcId),tostring(t.networked),tostring(t.record),tostring(how),
        board and (tostring(board.kind)..":"..tostring(board.id)) or "none")
end
exports("tableMenuRows",function(ctx)
    local board,how=boardFor(ctx)
    if how~="caller" then traceTarget(ctx,board,how) end
    if not board then return {rows={}} end
    local list=rowsFor(board,ctx)
    return {title=title(board),rows=list}
end)
exports("tableMenuSelect",function(ctx)
    local board=boardFor(ctx)
    local key=type(ctx)=="table" and type(ctx.action)=="table" and ctx.action.key
    if not board or type(key)~="string" then return false end
    local _,runs=rowsFor(board,ctx)
    local run=runs[key]
    if not run then return false end
    return run()~=false
end)
local registering=false
local function register()
    if registering then return end
    registering=true
    CreateThread(function()
        Wait(0)
        local pending,why=Open77.exports.call("open77_contextmenu","register",{
            id="tables.menu",label="Table",icon="interact",group="Table",order=-10,
            types={"prop","world","object","device","item","npc"},distance=REACH,
            rows="tableMenuRows",onSelect="tableMenuSelect",
        })
        local token
        if pending then token,why=pending:await() end
        if not token then Ui.log("table menu registration failed: %s",tostring(why)) end
        registering=false
    end)
end
M.registerMenu=register
AddEventHandler("onClientResourceStart",function(name)
    if name==GetCurrentResourceName() or name=="open77_contextmenu" then register() end
end)
RegisterNetEvent(LightRpEvents.net.state,function(patch)
    if type(patch)=="table" and type(patch.money)=="table" and type(patch.money.cash)=="number" then cash=patch.money.cash end
end)

-- Shared with the bar (client/core/table_bar.lua) ---------------------------------
local function sideName(board,side)
    if board.kind=="connect4" then return side=="white" and "Red" or "Yellow" end
    return side=="white" and "White" or "Black"
end
M.sideName=sideName
local function boardStatus(board)
    local g=board.game
    if g.status=="draw" then return "Draw" end
    if g.status=="won" then return (Client.member(board)==g.winner and "You win" or sideName(board,g.winner).." wins") end
    if not Client.isReady(board) then return "Waiting for players" end
    if tonumber(board.actor)==0 then return "AI is thinking" end
    if Client.isActor(board) then return "Your turn" end
    return sideName(board,g.turn).." to move"
end
M.boardStatus=boardStatus
local ROULETTE_LABEL={red="Red",black="Black",even="Even",odd="Odd",low="1-18",high="19-36",dozen1="1st 12",dozen2="2nd 12",dozen3="3rd 12"}
local function rouletteBetLabel(bet)
    if type(bet)=="number" then return bet==0 and "Zero" or tostring(bet) end
    return ROULETTE_LABEL[bet] or tostring(bet)
end
M.rouletteBetLabel=rouletteBetLabel
local function myRouletteStake(board,seat)
    local total=0
    for _,bet in ipairs(board.game.bets or {}) do if bet.seat==seat then total=total+(tonumber(bet.amount) or 0) end end
    return total
end
local function resultText(result)
    return ("%d %s"):format(tonumber(result.outcome) or 0,result.color=="green" and "Green" or result.color=="red" and "Red" or "Black")
end
M.resultText=resultText
-- Blackjack totals the player can see at server time `now` (a card counts once face up).
local function shownTotal(cards,now)
    local B=LightRpBlackjack
    local shown={}
    for _,card in ipairs(cards or {}) do
        local up=(tonumber(card.f) or ((tonumber(card.t) or 0)+B.SLIDE))+B.FLIP*.6
        if type(card.c)=="string" and now>=up then shown[#shown+1]=card.c end
    end
    if #shown==0 then return nil end
    local total,soft=B.total(shown)
    return (soft and total<21) and "soft "..total or tostring(total)
end
M.shownTotal=shownTotal
local RESULTS={blackjack="Blackjack",win="Win",push="Push",lose="Dealer wins",bust="Bust"}
M.RESULTS=RESULTS
-- One short line for the menu's status row: what is happening at the table.
status=function(board)
    local g=board.game
    if board.kind=="chess" or board.kind=="checkers" or board.kind=="connect4" then
        if Client.member(board) then return boardStatus(board) end
        if g.status=="won" then return sideName(board,g.winner).." won" end
        if g.status=="draw" then return "Draw" end
        return ((g.ply or 0)>0 and sideName(board,g.turn).." to move" or "New game").." · "..(MODE_LABEL[board.mode or "duel"] or "")
    elseif board.kind=="pool" then return LightRpPoolClient.status(board)
    elseif board.kind=="roulette" or board.kind=="fortune" then
        return g.phase=="spinning" and "Wheel spinning" or g.phase=="result" and "Showing the result" or "Bets open"
    elseif board.kind=="blackjack" then
        return g.phase=="betting" and "Bets open" or g.phase=="playing" and "Hand in play" or "Settling the hand"
    elseif board.kind=="slots" then
        local spin=type(g.spin)=="table" and g.spin
        return spin and Extra.serverTime(board)<(tonumber(spin.endsAt) or 0) and "Reels spinning" or "Ready"
    end
end

-- Notices -----------------------------------------------------------------------
-- Said once when it changes, beside the bar: whose turn, the result, the
-- payout. Timed reveals (reels, the dealer's hand) wait for the
-- server time at which every client shows them.
local seen={}
local later={}
local function schedule(board,serverAt,fn)
    local delay=math.max(0,(tonumber(serverAt) or 0)-Extra.serverTime(board))
    later[#later+1]={at=GetGameTimer()+delay,id=board.id,fn=fn}
end
local function fire()
    if #later==0 then return end
    local now,keep=GetGameTimer(),{}
    for _,job in ipairs(later) do
        if now>=job.at then
            local board=Client.boards[job.id]
            if board and Client.seated()==board then job.fn(board) end
        else keep[#keep+1]=job end
    end
    later=keep
end
M.fire=fire
local observers={}
function observers.board(board,old)
    local g=board.game
    local status=boardStatus(board)
    if old and old.status~=status and (status=="Your turn" or g.status~="playing") then notify(board,status..".") end
    return {status=status}
end
function observers.roulette(board,old)
    local g,seat=board.game,Extra.seat(board)
    local bets=g.bets or {}
    if old and old.round==g.round and #bets>old.bets then
        for index=old.bets+1,#bets do
            local bet=bets[index]
            if bet.seat==seat then notify(board,("%s on %s · your bets %s."):format(money(bet.amount),rouletteBetLabel(bet.bet),money(myRouletteStake(board,seat)))) end
        end
    end
    if old and old.phase~="result" and g.phase=="result" and type(g.result)=="table" then
        local won,staked=0,false
        for _,p in ipairs(g.result.payouts or {}) do if p.seat==seat then staked=true;won=won+(tonumber(p.gross) or 0) end end
        notify(board,resultText(g.result)..(staked and (won>0 and ". You win "..money(won).."." or ". No win.") or "."))
    end
    return {round=g.round,phase=g.phase,bets=#bets}
end
function observers.slots(board,old)
    local spin=type(board.game.spin)=="table" and board.game.spin
    local key=spin and tostring(spin.round)..":"..tostring(spin.at)
    if old and spin and key~=old.spin and tonumber(board.actor)==me() then
        schedule(board,spin.endsAt,function(b)
            local S=LightRpCasinoSlots
            local _,label=S.evaluate(spin.stops)
            notify(b,(tonumber(spin.gross) or 0)>0 and ("%s · %s."):format(label,money(spin.gross)) or "No win.")
        end)
    end
    return {spin=key}
end
function observers.blackjack(board,old)
    local g,seat=board.game,Extra.seat(board)
    local turn=g.phase=="playing" and g.seatTurn==seat and tostring(g.round)..":"..tostring(seat) or nil
    if old and turn and turn~=old.turn then
        schedule(board,g.actAt,function(b)
            local now=Extra.serverTime(b)
            local hand=b.game.hands and b.game.hands[seat]
            if b.game.phase~="playing" or b.game.seatTurn~=seat or not hand then return end
            notify(b,("Your turn: %s vs dealer %s. Hit, Stand or Double on the bar.")
                :format(shownTotal(hand.cards,now) or "?",shownTotal(b.game.dealer and b.game.dealer.cards,now) or "?"))
        end)
    end
    local result=g.phase=="result" and tostring(g.round) or nil
    if old and result and result~=old.result then
        schedule(board,g.resultAt,function(b)
            local hand=b.game.hands and b.game.hands[seat]
            if b.game.phase~="result" or not hand or not hand.result then return end
            local paid=tonumber(hand.payout) or 0
            notify(b,(RESULTS[hand.result] or hand.result)..(paid>0 and " · "..money(paid).." returned." or "."))
        end)
    end
    return {turn=turn or (old and old.turn),result=result or (old and old.result)}
end
function observers.fortune(board,old)
    local F=LightRpCasinoFortune
    local g=board.game
    if old and old.phase~="result" and g.phase=="result" and type(g.result)=="table" then
        local won=tonumber(g.yourWin) or 0
        notify(board,("%s wins%s"):format(F.LABEL[g.result.spot] or tostring(g.result.spot),
            won>0 and ". You won "..money(won).."." or (tonumber(g.yourStake) or 0)>0 and ". No win." or "."))
    end
    return {phase=g.phase}
end
-- Pool: each shot's outcome (fouls, groups, turn, win) once the balls stop.
function observers.pool(board,old)
    local g=board.game
    local shot=type(g.shot)=="table" and g.shot or nil
    local key=shot and tostring(shot.n)..":"..tostring(shot.at) or nil
    if old and key and key~=old.shot then
        schedule(board,LightRpPool.endsAt(g),function(b)
            local s=type(b.game.shot)=="table" and b.game.shot
            if not s or tostring(s.n)..":"..tostring(s.at)~=key then return end
            local text=LightRpPoolClient.result(b);if text then notify(b,text) end
        end)
    end
    if old and g.rack~=old.rack then
        notify(board,g.mode=="solo" and "New rack." or (g.turn==Extra.seat(board) and "New rack: your break." or "New rack: your opponent breaks."))
    end
    return {shot=key or (old and old.shot),rack=g.rack}
end
for _,kind in ipairs({"chess","checkers","connect4"}) do observers[kind]=observers.board end
-- Called by board_games.lua with every applied snapshot.
function M.observe(boards)
    local seatedBoard=Client.seated()
    local nextSeen={}
    for id,board in pairs(boards) do
        local observer=observers[board.kind]
        if observer and board==seatedBoard then nextSeen[id]=observer(board,seen[id]) end
    end
    seen=nextSeen
end
-- Called once when the local player takes a seat: how to play this table.
local HOW={
    slots="Set your bet on the bar, then click the lever (or Pull).",
    fortune="Click a spot on the felt, then Bet on the bar. Spin when everyone is in.",
    roulette="Click a number or a box on the layout, then Bet on the bar.",
    blackjack="Set your chip, then Bet on the bar. Hit, Stand or Double on your turn.",
    pool="Aim with the cursor on the cloth, hold the left button to charge, release to shoot.",
}
function M.seated(board)
    -- Start observing from this snapshot: the next change is the first notice.
    local observer=observers[board.kind]
    if observer then seen[board.id]=observer(board,nil) end
    local how=HOW[board.kind]
    if not how then
        how=("You play %s. %s"):format(sideName(board,Client.member(board)),board.kind=="connect4"
            and "Click a column to drop a disc." or "Click a piece, then its square (or drag it).")
    end
    notify(board,how.." Camera views and Leave are on the bar; Escape leaves.")
end
CreateThread(function()
    while true do
        Wait(200)
        local ok,why=pcall(fire)
        if not ok then Ui.log("table menu notices: %s",tostring(why)) end
    end
end)
