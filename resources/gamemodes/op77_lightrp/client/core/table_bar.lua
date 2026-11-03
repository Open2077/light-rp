-- The bar at the bottom of the game view (ui/src/features/board-games/TableBar.tsx):
-- the table's title and a short status, the chip amount, the target picked on
-- the table and the buttons that make sense right now, computed per game from
-- the snapshot the client already has. board_games.lua adds the camera views
-- and Leave, sends the model to the page and routes its clicks back here.
--
-- Each kind registers a builder: M.register(kind,function(board,b) end) with
--   b.status(text,tone)      -- tone: "turn" (you act), "result", "warn" or nil
--   b.detail(text)           -- a second, quieter line
--   b.hint(text)             -- what the left mouse button does on the table
--   b.countdown(serverAt)    -- seconds left until a server time
--   b.chip{value,min,max,set,label}  -- the amount selector (- / value / +)
--   b.target(label)          -- the betting target selected on the table
--   b.button(key,label,run,{enabled=,primary=})
-- M.run(board,key) rebuilds the model from the current state and runs only an
-- offered, enabled button: a click that arrives after a phase change is
-- dropped. Every request is one the server already validates
-- (lightrp:boardGames:request mode/reset, tabletop `game` operations through
-- LightRpTabletopExtraClient.command). Builders run in the render resume of
-- the 176 client (~10k instructions): a few dozen operations, no searches.
local Client=LightRpBoardGamesClient
local Extra=LightRpTabletopExtraClient
local Menu=LightRpTableMenu
local M={}
LightRpTableBar=M
local builders={}
function M.register(kind,builder) builders[kind]=builder end
local money=Menu.money
local function affordable(amount) local cash=Menu.cash();return cash==nil or amount<=cash end
local function command(board,operation,data) return Extra.command(board,operation,data)==true end
local function me()
    local state=Open77.network.status();return state and tonumber(state.playerId)
end
-- The chip ladder the - / + buttons walk, clipped to each game's limits.
local LADDER={1,5,10,25,50,100,250,500,1000,2500,5000,10000,25000,50000,100000,250000,500000,1000000}
local function ladder(min,max)
    local out={}
    for _,amount in ipairs(LADDER) do if amount>=min and amount<=max then out[#out+1]=amount end end
    return out
end
local ladders={}
local function build(board)
    local builder=builders[board.kind]
    local model={actions={}}
    local runs,setChip={},nil
    local b={}
    function b.status(text,tone) model.status=text;model.tone=tone end
    function b.detail(text) model.detail=text end
    function b.hint(text) model.hint=text end
    function b.target(label) model.target=label end
    function b.countdown(serverAt)
        local left=tonumber(serverAt) and serverAt-Extra.serverTime(board)
        if left and left>0 then model.countdownMs=math.floor(left) end
    end
    function b.chip(spec)
        local key=spec.min..":"..spec.max
        ladders[key]=ladders[key] or ladder(spec.min,spec.max)
        model.chip={value=spec.value,min=spec.min,max=spec.max,presets=ladders[key],label=spec.label or "Chip"}
        setChip=spec.set
    end
    function b.button(key,label,run,options)
        if #model.actions>=8 then return end
        local enabled=not options or options.enabled~=false
        model.actions[#model.actions+1]={key=key,label=label,enabled=enabled,primary=options and options.primary or nil}
        if enabled then runs[key]=run end
    end
    if builder then builder(board,b) end
    return model,runs,setChip
end
function M.model(board)
    local model=build(board)
    return model
end
function M.run(board,key)
    local _,runs=build(board)
    local run=runs[key]
    if not run then return false end
    return run()~=false
end
-- The chip: any whole amount within the game's limits (the page offers the ladder).
function M.setChip(board,amount)
    local model,_,set=build(board)
    if not set or not model.chip or type(amount)~="number" or amount~=math.floor(amount)
        or amount<model.chip.min or amount>model.chip.max then return false end
    return set(amount)~=false
end

-- Chess, checkers, Connect Four ---------------------------------------------------
local MODE_LABEL={solo="Solo vs AI",duel="1v1",teams="2v2"}
local NEXT_MODE={duel="solo",solo="teams",teams="duel"}
local function boardBar(board,b)
    local g=board.game
    local status=Menu.boardStatus(board)
    b.status(status,status=="Your turn" and "turn" or g.status~="playing" and "result" or nil)
    b.detail(("You play %s · %s"):format(Menu.sideName(board,Client.member(board)),MODE_LABEL[board.mode or "duel"] or "1v1"))
    if board.kind=="connect4" then b.hint("Click a column to drop a disc")
    else b.hint("Click a piece, then its square (or drag it)") end
    if not board.owned then return end
    if (g.ply or 0)==0 and not g.chain then
        local current=board.mode or "duel"
        b.button("mode","Mode: "..(MODE_LABEL[current] or current),function()
            return Client.request("mode",{boardId=board.id,mode=NEXT_MODE[current] or "duel"})==true
        end)
    else
        b.button("reset","New game",function() return Client.request("reset",{boardId=board.id})==true end)
    end
end
for _,kind in ipairs({"chess","checkers","connect4"}) do M.register(kind,boardBar) end

-- Roulette --------------------------------------------------------------------------
local rouletteChip=10
M.register("roulette",function(board,b)
    local g=board.game
    if g.phase=="spinning" then
        b.status("Wheel spinning");b.detail("Bets are closed")
        if type(g.spin)=="table" then b.countdown(g.spin.endsAt) end
        return
    end
    if g.phase=="result" then
        local result=type(g.result)=="table" and g.result
        local seat=Extra.seat(board)
        local won,staked=0,false
        for _,p in ipairs(result and result.payouts or {}) do if p.seat==seat then staked=true;won=won+(tonumber(p.gross) or 0) end end
        b.status(result and Menu.resultText(result) or "Result","result")
        if staked then b.detail(won>0 and "You win "..money(won) or "No win") end
        b.button("next","Next round",function() return command(board,"nextRound") end,{primary=true})
        return
    end
    local stake=tonumber(g.yourStake) or 0
    b.status(stake>0 and "Your bets "..money(stake) or "Place your bets")
    local R=LightRpTabletopExtraRules
    rouletteChip=math.max(R.MIN_BET,math.min(R.MAX_BET,rouletteChip))
    b.chip{value=rouletteChip,min=R.MIN_BET,max=R.MAX_BET,set=function(amount) rouletteChip=amount end}
    local sel=Extra.selection(board)
    if sel then b.target(sel.label.." · pays "..Extra.roulettePays(sel.key))
    else b.hint("Click a number or a box on the layout") end
    local chip=rouletteChip
    b.button("bet",sel and "Bet "..money(chip).." on "..sel.label or "Bet "..money(chip),function()
        return command(board,"bet",{bet=sel.key,amount=chip})
    end,{enabled=sel~=nil and affordable(chip) and stake+chip<=R.MAX_ROUND,primary=true})
    b.button("spin","Spin",function() return command(board,"spin") end)
end)

-- Slot machine -------------------------------------------------------------------------
M.register("slots",function(board,b)
    local Slots=LightRpCasinoSlotsClient
    local S=LightRpCasinoSlots
    local bet=Slots.bet()
    local spin=type(board.game.spin)=="table" and board.game.spin
    local spinning=spin and Extra.serverTime(board)<(tonumber(spin.endsAt) or 0)
    local last=spin and not spinning and spin or type(board.game.last)=="table" and board.game.last
    if spinning then b.status("Reels spinning")
    elseif last and (tonumber(last.gross) or 0)>0 then b.status("Won "..money(last.gross),"result")
    elseif last then b.status("No win")
    else b.status("Ready") end
    b.chip{label="Bet",value=bet,min=S.MIN_BET,max=S.MAX_BET,set=function(amount) return Slots.setBet(amount) end}
    if tonumber(board.actor)~=me() then b.detail("Another player is at the lever");return end
    b.hint("Click the lever to pull")
    b.button("pull","Pull "..money(bet),function() return command(board,"pull",{bet=bet}) end,
        {enabled=not spinning and affordable(bet),primary=true})
end)

-- Blackjack ------------------------------------------------------------------------------
local blackjackChip=10
M.register("blackjack",function(board,b)
    local B=LightRpBlackjack
    local g=board.game
    local seat=Extra.seat(board)
    local hand=seat and type(g.hands)=="table" and g.hands[seat] or nil
    local now=Extra.serverTime(board)
    if g.phase=="betting" then
        local placed=hand and tonumber(hand.bet) or 0
        b.status(placed>0 and "Your bet "..money(placed) or "Place a bet")
        if tonumber(g.closesAt) then b.countdown(g.closesAt);b.detail("Dealing soon") else b.detail("Blackjack pays 3 to 2") end
        b.chip{value=blackjackChip,min=B.MIN_BET,max=B.MAX_BET,set=function(amount) blackjackChip=amount end}
        local sel=Extra.selection(board)
        if sel then b.target(sel.label) else b.hint("Click your betting circle, then Bet") end
        local chip=blackjackChip
        b.button("bet",(placed>0 and "Add " or "Bet ")..money(chip),function() return command(board,"bet",{amount=chip}) end,
            {enabled=placed+chip<=B.MAX_BET and affordable(chip),primary=true})
        b.button("deal","Deal now",function() return command(board,"deal") end,{enabled=hand~=nil})
    elseif g.phase=="playing" then
        local mine=hand and Menu.shownTotal(hand.cards,now)
        local dealer=Menu.shownTotal(g.dealer and g.dealer.cards,now)
        local legal=B.legal(g,seat,now)
        local turn=legal.hit or legal.stand
        b.status((mine and "Hand "..mine or "Dealing")..(dealer and " · Dealer "..dealer or ""),turn and "turn" or nil)
        if not hand then b.detail("Watching this round");return end
        if not turn then b.detail(g.seatTurn==seat and "Wait for the cards" or "Another seat is playing") end
        b.button("hit","Hit",function() return command(board,"hit") end,{enabled=legal.hit==true,primary=true})
        b.button("stand","Stand",function() return command(board,"stand") end,{enabled=legal.stand==true})
        b.button("double","Double "..money(hand.bet),function() return command(board,"double") end,
            {enabled=legal.double==true and affordable(tonumber(hand.bet) or 0)})
    elseif g.phase=="result" then
        local revealed=now>=(tonumber(g.resultAt) or 0)
        local text=not revealed and "Dealer plays" or hand and hand.result and Menu.RESULTS[hand.result] or "Next hand shortly"
        b.status(text,revealed and hand and hand.result and "result" or nil)
        if revealed and hand and (tonumber(hand.payout) or 0)>0 then b.detail(money(hand.payout).." returned") end
        if tonumber(g.nextAt) then b.countdown(g.nextAt) end
    end
end)

-- Fortune wheel -----------------------------------------------------------------------------
M.register("fortune",function(board,b)
    local F=LightRpCasinoFortune
    local Fortune=LightRpCasinoFortuneClient
    local g=board.game
    if g.phase=="spinning" then
        b.status("Wheel spinning");b.detail("Bets are closed")
        if type(g.spin)=="table" then b.countdown((tonumber(g.spin.startedAt) or 0)+(tonumber(g.spin.spinMs) or 0)) end
        return
    end
    local chip=Fortune.chip()
    local stake=tonumber(g.yourStake) or 0
    local result=g.phase=="result" and type(g.result)=="table" and g.result
    if result then
        b.status(("%s wins"):format(F.LABEL[result.spot] or tostring(result.spot)),"result")
        local won=tonumber(g.yourWin) or 0
        if won>0 then b.detail("You won "..money(won)) end
    else b.status(stake>0 and "Your bets "..money(stake) or "Place your bets") end
    b.chip{value=chip,min=F.MIN_BET,max=F.MAX_BET,set=function(amount) return Fortune.setChip(amount) end}
    local sel=Extra.selection(board)
    if sel then b.target(("%s · pays %d to 1"):format(sel.label,F.MULTIPLIER[sel.key] or 0))
    else b.hint("Click a spot on the felt") end
    b.button("bet",sel and "Bet "..money(chip).." on "..sel.label or "Bet "..money(chip),function()
        return command(board,"bet",{spot=sel.key,amount=chip})
    end,{enabled=sel~=nil and affordable(chip) and stake+chip<=F.MAX_ROUND,primary=true})
    b.button("spin","Spin",function() return command(board,"spin") end)
end)

-- Pool ---------------------------------------------------------------------------------------
M.register("pool",function(board,b)
    local Pool=LightRpPoolClient
    local g=board.game
    local busy=Pool.busy(board)
    b.status(Pool.status(board),Pool.canShoot(board) and "turn" or g.status=="won" and "result" or nil)
    if Pool.charging(board) then b.detail(("Power %d%%"):format(math.floor(Pool.chargePower()*100+.5)))
    elseif Pool.placing(board) then b.hint("Click the cloth to place the cue ball")
    elseif Pool.canShoot(board) then b.hint("Aim with the cursor, hold the left button, release to shoot") end
    if g.mode=="solo" and (g.ply or 0)>0 and not busy then
        b.button("rerack","Re-rack",function() return command(board,"rerack") end)
    elseif g.mode~="solo" and g.status=="won" and not busy then
        b.button("rerack","Rematch",function() return command(board,"rerack") end,{primary=true})
    end
    if not board.owned then return end
    if (g.ply or 0)==0 then
        local solo=board.mode=="solo"
        b.button("mode","Mode: "..(solo and "Practice" or "1v1"),function()
            return Client.request("mode",{boardId=board.id,mode=solo and "duel" or "solo"})==true
        end)
    elseif not busy then
        b.button("reset","New game",function() return Client.request("reset",{boardId=board.id})==true end)
    end
end)
