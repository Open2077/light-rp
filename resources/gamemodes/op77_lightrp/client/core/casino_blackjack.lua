-- Blackjack presentation: cards and chips are native props animated from the
-- server's timestamps, so every client shows the same deal at the same time.
-- Nothing here decides anything: the shoe, the hole card and the money stay
-- on the server. Coordinates are board-local unscaled metres from the floor
-- under the centre of the felt arc; players sit at -Y, the dealer at +Y.
local Extra=LightRpTabletopExtraClient
local B=LightRpBlackjack
local DEPOT="open77\\assets\\op77_lightrp\\casino_blackjack\\"
local FZ=1.35                 -- felt height
local CARD_DZ=.0018           -- each overlapping card lies on the previous one
local MAX_CARDS=7             -- rendered per hand (the panel lists every card)
local SHOE={x=.70,y=.03,z=FZ+.04,yaw=0}       -- hidden inside the shoe body
local EXIT={x=.70,y=-.15,z=FZ+.02}            -- the shoe mouth, where a dealt card appears
local DISCARD={x=-.70,y=.03,z=FZ+.03}
local RACK={x=0,y=.065,z=FZ+.04}
-- Pacing comes from the shared rules (B.SLIDE, B.FLIP, B.CHIPS, B.CHIP_STAGGER,
-- B.SWEEP); these are the purely visual parts, all inside the server windows.
local SWEEP_MS=700
local SWEEP_STAGGER=250     -- per seat; the dealer's own cards go first (4 seats: done in 1.7 s < B.SWEEP)
local PULL_MS=450
local BUST_PAUSE=500        -- a busted hand's chips leave once its last card has settled
local function asset(name) return DEPOT..name..".ent" end
local BACK,TURN=asset("bj_card_back"),asset("bj_card_turn")
local FACES={}
local function face(code)
    local path=FACES[code]
    if not path then path=asset("bj_card_"..code:lower());FACES[code]=path end
    return path
end
-- Static layout, computed once: four seats around the arc, first base at +X.
local ANGLES={white=54,black=18,white2=-18,black2=-54}
local SEATS={}
for index,seat in ipairs(B.SEATS) do
    local a=math.rad(ANGLES[seat])
    local ux,uy,tx,ty=math.sin(a),-math.cos(a),math.cos(a),math.sin(a)
    local s={index=index,yaw=ANGLES[seat],ux=ux,uy=uy,tx=tx,ty=ty,
        px=.80*ux,py=.80*uy,                      -- betting circle
        wx=.80*ux+.14*tx,wy=.80*uy+.14*ty,        -- winnings beside it
        hx=1.10*ux,hy=1.10*uy,                    -- the player's edge of the rail
        cards={},ids={},bet={},win={},cardKey=seat..":cards",chipKey=seat..":chips"}
    for k=1,MAX_CARDS do
        local r=.55-(k-1)*.012
        s.cards[k]={x=r*ux+(k-1)*.032*tx,y=r*uy+(k-1)*.032*ty,z=FZ+.001+(k-1)*CARD_DZ,yaw=ANGLES[seat]}
        s.ids[k]="bj-"..seat.."-c"..k
    end
    for k=1,3 do s.bet[k]="bj-"..seat.."-b"..k;s.win[k]="bj-"..seat.."-w"..k end
    SEATS[seat]=s
end
local DEALER={cards={},ids={}}
for k=1,MAX_CARDS do
    DEALER.cards[k]={x=-.07+(k-1)*.075,y=-.24,z=FZ+.001,yaw=0}
    DEALER.ids[k]="bj-d-c"..k
end
-- Chip stacks: one prop per denomination column, the three largest columns.
local DENOMS={1000,500,100,25,5,1}
local MAXCOUNT={[1000]=10,[500]=1,[100]=4,[25]=3,[5]=4,[1]=4}
local LAYOUT={{{0,0}},{{-.033,0},{.033,0}},{{-.033,.02},{.033,.02},{0,-.035}}}
local stacks,stackCount={},0
local function chips(amount)
    local list=stacks[amount]
    if list then return list end
    list={};local left=amount
    for _,d in ipairs(DENOMS) do
        local n=math.floor(left/d)
        if n>0 and #list<3 then
            list[#list+1]={model=asset("bj_chips_"..d.."_"..math.min(n,MAXCOUNT[d]))}
            left=left-n*d
        end
    end
    for i,column in ipairs(list) do column.o=LAYOUT[#list][i] end
    if stackCount>256 then stacks={};stackCount=0 end
    stacks[amount]=list;stackCount=stackCount+1
    return list
end
-- Budget: a full table is ~60 props, too many to rebuild every tick. Targets
-- are built per group (dealer cards, each hand's cards, each hand's chips)
-- and reused until the group's next server-time boundary; only a group that
-- is mid-animation is rebuilt each tick. `horizon` collects that boundary.
local clockNow,horizon=0,math.huge
local budget,built=0,0
local function soon(t) if t>clockNow and t<horizon then horizon=t end end
local function moving() horizon=clockNow end
local function put(result,id,kind,model,x,y,z,yaw,smooth)
    built=built+1
    result[id]={piece={id=id,kind=kind,side="neutral",model=model,yaw=yaw,snap=not smooth},position={x=x,y=y,z=z}}
end
-- One card at server time `now`: inside the shoe, sliding, flipping, resting
-- or swept to the discard tray. A hidden card only ever uses the back model.
-- The sweep is a single target change smoothed by the renderer.
local function card(result,id,entry,slot,now,sweep)
    local t=tonumber(entry.t) or 0
    if sweep then
        if now>=sweep then
            if now>=sweep+SWEEP_MS then return end
            soon(sweep+SWEEP_MS)
            put(result,id,"card",entry.c and face(entry.c) or BACK,DISCARD.x,DISCARD.y,DISCARD.z,slot.yaw,true)
            return
        end
        soon(sweep)
    end
    if now<t then soon(t);put(result,id,"card",BACK,SHOE.x,SHOE.y,SHOE.z,SHOE.yaw);return end
    local p=(now-t)/B.SLIDE
    if p<1 then
        moving()
        local e=1-(1-p)^3
        put(result,id,"card",BACK,EXIT.x+(slot.x-EXIT.x)*e,EXIT.y+(slot.y-EXIT.y)*e,EXIT.z+(slot.z-EXIT.z)*e+.025*math.sin(p*math.pi),SHOE.yaw+(slot.yaw-SHOE.yaw)*e)
        return
    end
    local model=BACK
    if entry.c then
        local f=tonumber(entry.f) or t+B.SLIDE
        local shown=f+B.FLIP*.6
        if now>=shown then model=face(entry.c) elseif now>=f then model=TURN;soon(shown) else soon(f) end
    end
    put(result,id,"card",model,slot.x,slot.y,slot.z,slot.yaw)
end
-- A chip stack sliding from (ax,ay) to (bx,by) during [from, from+ms], or
-- (smooth) one target the renderer eases towards.
local function stack(result,ids,amount,s,ax,ay,az,bx,by,bz,from,ms,now,smooth)
    local p=1
    if from and now<from+ms and not smooth then
        if now<from then soon(from) else moving() end
        p=math.max(0,(now-from)/ms)
    end
    local x,y,z=ax+(bx-ax)*p,ay+(by-ay)*p,az+(bz-az)*p+.02*math.sin(p*math.pi)
    for i,column in ipairs(chips(amount)) do
        local o=column.o
        put(result,ids[i],"chips",column.model,x+o[1]*s.tx+o[2]*s.ux,y+o[1]*s.ty+o[2]*s.uy,z,s.yaw,smooth)
    end
end
local function lastCardEnd(hand)
    local last=hand.cards[#hand.cards]
    return last and (tonumber(last.t) or 0)+B.SLIDE+B.FLIP or 0
end
local function dealerCards(r,g,now,sweep)
    local dealer=g.dealer and g.dealer.cards or {}
    for k=1,math.min(#dealer,MAX_CARDS) do card(r,DEALER.ids[k],dealer[k],DEALER.cards[k],now,sweep) end
end
local function handCards(r,hand,s,now,sweep)
    local cards=hand.cards
    for k=1,math.min(#cards,MAX_CARDS) do card(r,s.ids[k],cards[k],s.cards[k],now,sweep) end
end
local function handChips(r,hand,s,now,sweep,resultAt)
    local stake=tonumber(hand.stake or hand.bet) or 0
    -- Lost chips go to the dealer's rack: at once on a bust, else at the reveal.
    local lost=hand.total and hand.total>21 and lastCardEnd(hand)+BUST_PAUSE
        or (resultAt and hand.result=="lose" and resultAt+s.index*B.CHIP_STAGGER)
    local pay=resultAt and (hand.payout or 0)-stake or 0
    if lost then soon(lost);soon(lost+B.CHIPS) end
    if sweep then soon(sweep);soon(sweep+SWEEP_MS) end
    if stake>0 then
        if lost and now>=lost then
            if now<lost+B.CHIPS then stack(r,s.bet,stake,s,s.px,s.py,FZ,RACK.x,RACK.y,RACK.z,lost,B.CHIPS,now) end
        elseif sweep and now>=sweep then
            if now<sweep+SWEEP_MS then stack(r,s.bet,stake,s,s.hx,s.hy,FZ+.03,s.hx,s.hy,FZ+.03,nil,0,now,true) end
        else
            stack(r,s.bet,stake,s,s.hx,s.hy,FZ+.03,s.px,s.py,FZ,tonumber(hand.betAt),PULL_MS,now)
        end
    end
    if pay>0 then
        local at=resultAt+s.index*B.CHIP_STAGGER
        if sweep and now>=sweep then
            if now<sweep+SWEEP_MS then stack(r,s.win,pay,s,s.hx,s.hy,FZ+.03,s.hx,s.hy,FZ+.03,nil,0,now,true) end
        elseif now>=at then
            stack(r,s.win,pay,s,RACK.x,RACK.y,RACK.z,s.wx,s.wy,FZ,at,B.CHIPS,now)
        else soon(at) end
    end
end
-- A new snapshot invalidates every group, but rebuilds are spread: about
-- REBUILD props per call; past that, a stale group keeps last tick's targets
-- (same round only) and a group never built yet appears a tick later.
local REBUILD=24
local caches={}
local function group(cache,key,result,fn,a,b,c,d,e)
    local entry=cache[key]
    local valid=entry and entry.gen==cache.gen and clockNow>=entry.builtAt and clockNow<entry.untilT
    if not valid then
        if budget>0 then
            horizon=math.huge;built=0
            local r={}
            fn(r,a,b,c,d,e)
            budget=budget-built
            entry={r=r,untilT=horizon,builtAt=clockNow,gen=cache.gen};cache[key]=entry
        elseif not entry then return end
    end
    for id,target in pairs(entry.r) do result[id]=target end
end
local function pieceTargets(board,result)
    local g=board.game
    if type(g)~="table" or type(g.hands)~="table" then return end
    local now=Extra.serverTime(board);clockNow=now
    local cache=caches[board.id]
    if not cache or cache.round~=g.round then cache={gen=0,round=g.round};caches[board.id]=cache end
    if cache.game~=g then cache.game=g;cache.gen=cache.gen+1 end
    budget=REBUILD
    local sweep=g.phase=="result" and tonumber(g.nextAt) and g.nextAt-B.SWEEP or nil
    local resultAt=g.phase=="result" and tonumber(g.resultAt) or nil
    group(cache,"dealer",result,dealerCards,g,now,sweep)
    for seat,hand in pairs(g.hands) do
        local s=SEATS[seat]
        if s and type(hand.cards)=="table" then
            -- The dealer collects seat by seat: staggered sweeps also spread the
            -- renderer's prop removals over several passes.
            local collect=sweep and sweep+s.index*SWEEP_STAGGER
            group(cache,s.cardKey,result,handCards,hand,s,now,collect)
            group(cache,s.chipKey,result,handChips,hand,s,now,collect,resultAt)
        end
    end
end
local function seatCamera(board)
    local seat=SEATS[Extra.seat(board) or "black"]
    return seat
end
Extra.register("blackjack",{
    operations={bet=true,deal=true,hit=true,stand=true,double=true},
    boardModel=function() return asset("blackjack_table") end,
    pieceTargets=pieceTargets,
    camera=function(board,view)
        local w=Extra.world
        if view=="top" then
            return {position=w(board,0,-.42,FZ+2.4),rotation={pitch=-89.5,yaw=board.rotation or 0,roll=0},fov=52}
        elseif view=="white" then
            local s=seatCamera(board)
            return {position=w(board,1.65*s.ux,1.65*s.uy,FZ+.85),lookAt=w(board,0,-.28,FZ),fov=50}
        elseif view=="black" then
            return {position=w(board,0,.95,FZ+.8),lookAt=w(board,0,-.55,FZ),fov=55}
        end
        return {position=w(board,1.55,-1.35,FZ+1.15),lookAt=w(board,0,-.3,FZ),fov=50}
    end,
    view=function(board)
        local g=board.game
        local seat=Extra.seat(board)
        local now=Extra.serverTime(board)
        g.clientNow=now;g.mySeat=seat
        g.legal=B.legal(g,seat,now)
        local hand=seat and g.hands and g.hands[seat]
        local text="Bet from the panel, then Hit, Stand or Double on your turn."
        if g.phase=="playing" and g.seatTurn==seat and hand then text="Your turn: Hit, Stand or Double."
        elseif g.phase=="result" then text="The dealer settles the table. Winnings arrive as cash." end
        return {extra=g,text=text}
    end,
})
