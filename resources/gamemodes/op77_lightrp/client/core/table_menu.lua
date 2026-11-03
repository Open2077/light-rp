-- The ALT target menu of every placed table (chess, checkers, Connect Four and
-- the casino tables). There is no table panel or HUD: aiming at a table and
-- clicking it with ALT held lists only what this player can do right now,
-- computed from the snapshot the client already has (seated or not, phase,
-- turn, owner, legal moves, cash). Moves on the boards stay on the crosshair
-- and the left button (client/core/board_games.lua); state changes arrive as
-- notices from observe().
--
-- One open77_contextmenu registration with dynamic rows (>= 1.3.0): the menu
-- calls tableMenuRows(ctx) for the clicked target and tableMenuSelect(ctx)
-- with ctx.action.key. Both build the same rows from the same state, so a row
-- that is no longer valid (the turn passed, the bets closed) cannot run.
-- Every request is the one the server already validates: lightrp:boardGames:
-- request actions (join, mode, reset, pickup) and the tabletop `game`
-- operations sent by LightRpTabletopExtraClient.command.
--
-- Each kind registers a builder: M.register(kind,function(board,m,ctx) end),
-- where m.row(key,label,run,options) adds a row (options: icon, submenu,
-- description). The client budget is ~10k instructions per resume and this
-- runs on every ALT click on a table: builders stay a few dozen rows, no
-- searches beyond the table's own lists.
local Ui=LightRpUi
local Client=LightRpBoardGamesClient
local Extra=LightRpTabletopExtraClient
local M={}
LightRpTableMenu=M
local builders={}
local REACH=3          -- metres from the player to the clicked point (menu distance)
local TABLE_REACH=4    -- metres from the player to the table (the server's own check)
local PICKUP_REACH=2
local PRESETS={10,50,100,500,1000}
local cash -- the last RP cash the server reported (nil: unknown, nothing filtered)
function M.register(kind,builder) builders[kind]=builder end
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
local function affordable(amount) return cash==nil or amount<=cash end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end

-- Rows ------------------------------------------------------------------------
local function rowsFor(board,ctx)
    local list,runs={},{}
    local m={}
    function m.row(key,label,run,options)
        if #list>=24 then return end
        local row={key=key,label=label,icon=options and options.icon or "interact",
            submenu=options and options.submenu,description=options and options.description}
        list[#list+1]=row;runs[key]=run
    end
    local seat=Client.member(board)
    local seated=seat~=nil and Client.seated()==board
    local builder=builders[board.kind]
    if seated and builder then builder(board,m,ctx) end
    if not seated and not Client.isActive() and M.freeSeat(board) then
        m.row("sit","Sit",function() return Client.request("join",{boardId=board.id})==true end,{icon="person"})
    end
    if seated then m.row("leave","Leave table",function() return Client.leave("menu_leave") end,{icon="person"}) end
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
-- The table a menu context points at: the clicked native prop (base, collider
-- or piece) or, for a surface hit, the nearest rendered table within reach.
local function boardFor(ctx)
    if GetInvokingResource()~="open77_contextmenu" or type(ctx)~="table" or type(ctx.target)~="table" then return end
    if not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.actionFocus or Ui.supportMode then return end
    for name,open in pairs(Ui.dialogs or {}) do if open and name~="boardGames" then return end end
    local character=Open77.character.state()
    if not character or character.alive~=true or character.attached~=true or not character.position then return end
    local board=ctx.target.kind=="prop" and ctx.target.networked==false and Client.boardOfProp(ctx.target.propId) or nil
    if not board and type(ctx.position)=="table" and ctx.hasSurface~=false then
        local best=1.4
        for _,candidate in pairs(Client.boards) do
            local p=candidate.position
            local d=math.sqrt((p.x-ctx.position.x)^2+(p.y-ctx.position.y)^2)
            if d<best and math.abs(p.z-ctx.position.z)<2.5 and Client.isRendered(candidate) then best,board=d,candidate end
        end
    end
    if not board or distance(character.position,board.position)>TABLE_REACH then return end
    return board
end
exports("tableMenuRows",function(ctx)
    local board=boardFor(ctx);if not board then return {rows={}} end
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
            types={"prop","world","object","device","item"},distance=REACH,
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

-- Shared pieces ---------------------------------------------------------------
-- A folder of amount presets: within [min,max] (after `already` on the table)
-- and the cash; `current` is left out (the folder label shows it).
local function presets(m,prefix,folder,min,max,current,already,run)
    for _,amount in ipairs(PRESETS) do
        local total=(already or 0)+amount
        if amount~=current and total>=min and total<=max and affordable(amount) then
            m.row(prefix..amount,money(amount),function() return run(amount) end,{submenu=folder})
        end
    end
end
local function command(board,operation,data) return Extra.command(board,operation,data)==true end
local chips={roulette=10}

-- Chess, checkers, Connect Four -------------------------------------------------
local MODES={{"solo","Solo vs AI"},{"duel","1v1"},{"teams","2v2"}}
local MODE_LABEL={solo="Solo vs AI",duel="1v1",teams="2v2"}
local function sideName(board,side)
    if board.kind=="connect4" then return side=="white" and "Red" or "Yellow" end
    return side=="white" and "White" or "Black"
end
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
local function hint(board)
    if board.kind=="connect4" then return "Aim at a column and click to drop a disc." end
    return "Aim at a piece and click it, then click its destination (or hold and drag)."
end
local function boardGame(board,m)
    local g=board.game
    m.row("status",boardStatus(board),function()
        local count=0;for _ in pairs(board.players or {}) do count=count+1 end
        local slots=board.mode=="teams" and 4 or board.mode=="solo" and 1 or 2
        notify(board,("%s · %s · %d/%d players · you play %s. %s"):format(boardStatus(board),MODE_LABEL[board.mode or "duel"],
            count,slots,sideName(board,Client.member(board)),hint(board)))
    end,{icon="info"})
    if not board.owned then return end
    if (g.ply or 0)==0 and not g.chain then
        local current=board.mode or "duel"
        local folder={id="mode",label="Mode: "..MODE_LABEL[current],icon="tool"}
        for _,mode in ipairs(MODES) do if mode[1]~=current then
            m.row("mode."..mode[1],mode[2],function() return Client.request("mode",{boardId=board.id,mode=mode[1]})==true end,{submenu=folder,icon="tool"})
        end end
    else
        m.row("reset","New game",function() return Client.request("reset",{boardId=board.id})==true end,{icon="tool"})
    end
end
for _,kind in ipairs({"chess","checkers","connect4"}) do M.register(kind,boardGame) end

-- Roulette --------------------------------------------------------------------
local ROULETTE_BETS={
    {"red","Red","Pays 1 to 1"},{"black","Black","Pays 1 to 1"},{"even","Even","Pays 1 to 1"},{"odd","Odd","Pays 1 to 1"},
    {"low","1-18","Pays 1 to 1"},{"high","19-36","Pays 1 to 1"},{"dozen1","1-12","Pays 2 to 1"},{"dozen2","13-24","Pays 2 to 1"},
    {"dozen3","25-36","Pays 2 to 1"},{"number:0","Zero","Pays 35 to 1"},
}
local ROULETTE_LABEL={}
for _,bet in ipairs(ROULETTE_BETS) do ROULETTE_LABEL[bet[1]]=bet[2] end
local function rouletteBetLabel(bet)
    if type(bet)=="number" then return bet==0 and "Zero" or tostring(bet) end
    return ROULETTE_LABEL[bet] or tostring(bet)
end
local function myRouletteStake(board,seat)
    local total=0
    for _,bet in ipairs(board.game.bets or {}) do if bet.seat==seat then total=total+(tonumber(bet.amount) or 0) end end
    return total
end
local function resultText(result)
    return ("%d %s"):format(tonumber(result.outcome) or 0,result.color=="green" and "Green" or result.color=="red" and "Red" or "Black")
end
M.register("roulette",function(board,m)
    local g,seat=board.game,Client.member(board) and Extra.seat(board)
    local chip=chips.roulette
    if g.phase=="betting" then
        local stake=tonumber(g.yourStake) or myRouletteStake(board,seat)
        m.row("status",stake>0 and "Your bets: "..money(stake) or "Place your bets",function()
            local parts={}
            for _,bet in ipairs(g.bets or {}) do if bet.seat==seat then parts[#parts+1]=money(bet.amount).." on "..rouletteBetLabel(bet.bet) end end
            notify(board,#parts>0 and table.concat(parts,", ") or "No bets yet. Pick a chip, then a bet.")
        end,{icon="info"})
        local chipFolder={id="chip",label="Chip: "..money(chip),icon="tool"}
        presets(m,"chip.",chipFolder,1,1000000,chip,0,function(amount) chips.roulette=amount;notify(board,"Chip: "..money(amount));return true end)
        if affordable(chip) then
            local betFolder={id="bet",label="Bet "..money(chip),icon="interact"}
            for _,bet in ipairs(ROULETTE_BETS) do
                m.row("bet."..bet[1],bet[2],function() return command(board,"bet",{bet=bet[1],amount=chip}) end,{submenu=betFolder,description=bet[3]})
            end
        end
        m.row("spin","Spin",function() return command(board,"spin") end)
    elseif g.phase=="spinning" then
        m.row("status","Wheel spinning",function() notify(board,"The wheel is spinning: bets are closed.") end,{icon="info"})
    elseif g.phase=="result" then
        local result=type(g.result)=="table" and g.result
        m.row("status",result and "Result: "..resultText(result) or "Result",function()
            if result then notify(board,resultText(result)..".") end
        end,{icon="info"})
        m.row("next","Next round",function() return command(board,"nextRound") end)
    end
end)

-- Slot machine ------------------------------------------------------------------
local function slotsSpinning(board)
    local spin=type(board.game.spin)=="table" and board.game.spin
    return spin and Extra.serverTime(board)<(tonumber(spin.endsAt) or 0)
end
M.register("slots",function(board,m)
    local Slots=LightRpCasinoSlotsClient
    local S=LightRpCasinoSlots
    local bet=Slots.bet()
    local spinning=slotsSpinning(board)
    -- The last finished pull: the current spin once its reels stopped.
    local last=type(board.game.spin)=="table" and not spinning and board.game.spin
        or type(board.game.last)=="table" and board.game.last
    local status=spinning and "Reels spinning" or last and (tonumber(last.gross) or 0)>0 and "Last: "..money(last.gross)
        or last and "Last: no win" or "Ready"
    m.row("status",status,function()
        notify(board,("Bet %s. Three of a kind pays up to x%d; Cherry, Cherry x%d; any 3 fruit x%d. Middle row only.")
            :format(money(bet),S.THREE.seven,S.TWO_CHERRIES,S.MIXED_FRUIT))
    end,{icon="info"})
    if tonumber(board.actor)~=me() then return end -- watchers: only the first seat pulls
    presets(m,"bet.",{id="bet",label="Bet: "..money(bet),icon="tool"},S.MIN_BET,S.MAX_BET,bet,0,function(amount)
        Slots.setBet(amount);notify(board,"Bet: "..money(amount)..". Click the lever or use Pull.");return true
    end)
    if not spinning and affordable(bet) then
        m.row("pull","Pull ("..money(bet)..")",function() return command(board,"pull",{bet=bet}) end)
    end
end)

-- Blackjack -----------------------------------------------------------------------
-- Totals the player can see at server time `now` (a card counts once face up).
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
M.register("blackjack",function(board,m)
    local B=LightRpBlackjack
    local g=board.game
    local seat=Extra.seat(board)
    local hand=seat and type(g.hands)=="table" and g.hands[seat] or nil
    local now=Extra.serverTime(board)
    if g.phase=="betting" then
        local placed=hand and tonumber(hand.bet) or 0
        m.row("status",placed>0 and "Your bet: "..money(placed) or "Place a bet",function()
            local closes=tonumber(g.closesAt)
            notify(board,(placed>0 and "Your bet: "..money(placed)..". " or "")..(closes and ("Dealing in %d s."):format(math.max(0,math.ceil((closes-now)/1000)))
                or ("Bets %d to %s. Blackjack pays 3 to 2."):format(B.MIN_BET,money(B.MAX_BET))))
        end,{icon="info"})
        local folder={id="bet",label=placed>0 and "Add to bet" or "Bet",icon="interact"}
        presets(m,"bet.",folder,B.MIN_BET,B.MAX_BET,nil,placed,function(amount) return command(board,"bet",{amount=amount}) end)
        if hand then m.row("deal","Deal now",function() return command(board,"deal") end) end
    elseif g.phase=="playing" then
        local mine=hand and shownTotal(hand.cards,now)
        local dealer=shownTotal(g.dealer and g.dealer.cards,now)
        m.row("status",(mine and "Hand "..mine or "Dealing")..(dealer and " · Dealer "..dealer or ""),function()
            notify(board,g.seatTurn==seat and "Your turn." or "Another seat is playing.")
        end,{icon="info"})
        local legal=B.legal(g,seat,now)
        if legal.hit then m.row("hit","Hit ("..(mine or "?")..")",function() return command(board,"hit") end) end
        if legal.stand then m.row("stand","Stand ("..(mine or "?")..")",function() return command(board,"stand") end) end
        if legal.double and affordable(tonumber(hand.bet) or 0) then
            m.row("double","Double ("..money(hand.bet)..")",function() return command(board,"double") end)
        end
    elseif g.phase=="result" then
        local revealed=now>=(tonumber(g.resultAt) or 0)
        local text=not revealed and "Dealer plays" or hand and hand.result and RESULTS[hand.result] or "Next hand shortly"
        if revealed and hand and (tonumber(hand.payout) or 0)>0 then text=text.." · "..money(hand.payout) end
        m.row("status",text,function() notify(board,text..".") end,{icon="info"})
    end
end)

-- Fortune wheel ------------------------------------------------------------------
M.register("fortune",function(board,m)
    local F=LightRpCasinoFortune
    local Fortune=LightRpCasinoFortuneClient
    local g=board.game
    local chip=Fortune.chip()
    local stake=tonumber(g.yourStake) or 0
    if g.phase=="spinning" then
        m.row("status","Wheel spinning",function() notify(board,"The wheel is spinning: bets are closed.") end,{icon="info"})
        return
    end
    local result=g.phase=="result" and type(g.result)=="table" and g.result
    local status=result and ("Result: %s"):format(F.LABEL[result.spot] or tostring(result.spot))..((tonumber(g.yourWin) or 0)>0 and " · "..money(g.yourWin) or "")
        or stake>0 and "Your bets: "..money(stake) or "Place your bets"
    m.row("status",status,function()
        local parts={}
        for _,spot in ipairs(F.SPOTS) do
            local amount=type(g.yourBets)=="table" and tonumber(g.yourBets[spot])
            if amount and amount>0 then parts[#parts+1]=money(amount).." on "..F.LABEL[spot] end
        end
        notify(board,#parts>0 and table.concat(parts,", ") or "Pick a chip, then a multiplier (or click a spot on the felt).")
    end,{icon="info"})
    presets(m,"chip.",{id="chip",label="Chip: "..money(chip),icon="tool"},F.MIN_BET,F.MAX_BET,chip,0,function(amount)
        Fortune.setChip(amount);notify(board,"Chip: "..money(amount)..". Click a spot on the felt or use Bet.");return true
    end)
    if affordable(chip) and stake+chip<=F.MAX_ROUND then
        local folder={id="bet",label="Bet "..money(chip),icon="interact"}
        for _,spot in ipairs(F.SPOTS) do
            m.row("bet."..spot,F.LABEL[spot],function() return command(board,"bet",{spot=spot,amount=chip}) end,
                {submenu=folder,description=("Pays %d to 1"):format(F.MULTIPLIER[spot])})
        end
    end
    m.row("spin","Spin",function() return command(board,"spin") end)
end)

-- Pool --------------------------------------------------------------------------
-- Shots are played on the cloth (crosshair + left button, casino_pool.lua);
-- the menu holds the status, the rack and the owner's mode / new game.
M.register("pool",function(board,m)
    local Pool=LightRpPoolClient
    local g=board.game
    m.row("status",Pool.status(board),function() notify(board,Pool.describe(board)) end,{icon="info"})
    local busy=Pool.busy(board)
    if g.mode=="solo" and (g.ply or 0)>0 and not busy then
        m.row("rerack","Re-rack",function() return command(board,"rerack") end,{icon="tool"})
    elseif g.mode~="solo" and g.status=="won" and not busy then
        m.row("rerack","Rematch (re-rack)",function() return command(board,"rerack") end,{icon="tool"})
    end
    if not board.owned then return end
    if (g.ply or 0)==0 then
        local solo=board.mode=="solo"
        local folder={id="mode",label="Mode: "..(solo and "Solo practice" or "1v1"),icon="tool"}
        local mode,label=solo and "duel" or "solo",solo and "1v1" or "Solo practice"
        m.row("mode."..mode,label,function() return Client.request("mode",{boardId=board.id,mode=mode})==true end,{submenu=folder,icon="tool"})
    elseif not busy then
        m.row("reset","New game",function() return Client.request("reset",{boardId=board.id})==true end,{icon="tool"})
    end
end)

-- Notices -----------------------------------------------------------------------
-- What the panel used to show, said once when it changes: whose turn, the
-- result, the payout. Timed reveals (reels, the dealer's hand) wait for the
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
            notify(b,("Your turn: %s vs dealer %s. Hold ALT on the table: Hit, Stand or Double.")
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
function M.seated(board)
    -- Start observing from this snapshot: the next change is the first notice.
    local observer=observers[board.kind]
    if observer then seen[board.id]=observer(board,nil) end
    local how
    if board.kind=="chess" or board.kind=="checkers" or board.kind=="connect4" then
        how=("You play %s. %s"):format(sideName(board,Client.member(board)),hint(board))
    elseif board.kind=="slots" then how="Click the lever to pull."
    elseif board.kind=="fortune" then how="Click a spot on the felt to bet your chip."
    elseif board.kind=="pool" then how="Aim at the cloth with the crosshair, hold the left button to charge, release to shoot."
    else how="Bets and moves are in the ALT menu." end
    notify(board,how.." Hold ALT and click the table for options. Backspace: leave.")
end
CreateThread(function()
    while true do
        Wait(200)
        local ok,why=pcall(fire)
        if not ok then Ui.log("table menu notices: %s",tostring(why)) end
    end
end)
