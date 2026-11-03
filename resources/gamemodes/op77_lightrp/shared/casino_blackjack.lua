-- Blackjack: item, kind and pure authoritative rules. No randomness and no
-- money here: the server passes shuffle seeds and the clock, and turns the
-- settled hands into durable claims. Private state lives in "_" keys (the
-- shoe, the dealer's hole card, stake owners) and never reaches a client.
LightRpBoardGames.blackjack={item="blackjack_table",label="Blackjack Table",title="Blackjack",size=1,floor=0}
LightRpItems.blackjack_table={label="Blackjack Table",description="Use to place the table. E: play; target menu: pick up your table.",weight=8,stack=1,icon="package",category="misc"}

LightRpBlackjack={}
local B=LightRpBlackjack
-- Dealing order: first base (the dealer's left) to third base.
B.SEATS={"white","black","white2","black2"}
B.MIN_BET,B.MAX_BET=5,5000
B.DECKS=6
B.RESERVE=78          -- cut card: reshuffle once fewer cards remain (75% penetration)
-- Pacing (ms on the server clock). A real table breathes: cards come out of
-- the shoe one by one, the dealer pauses before handing over the turn and
-- before turning the hole card, draws one card at a time, and leaves the
-- result on the felt before collecting. Every client animates from these
-- timestamps, so they also decide what everyone sees and when.
B.BET_WINDOW=15000    -- countdown once the first bet is down
B.DEAL_GAP=800        -- between two cards of the opening deal
B.SLIDE=600           -- shoe to spot
B.FLIP=350            -- face-down to face-up
B.DEAL_PAUSE=1000     -- after the opening deal, before the first turn
B.TURN=25000          -- idle player: automatic stand
B.REVEAL_PAUSE=1000   -- after the last decision, before the hole card turns
B.DRAW_PAUSE=700      -- hole card face-up, before the dealer's first draw
B.DRAW_GAP=1200       -- between two dealer cards (each one rests ~0.25 s)
B.SETTLE_PAUSE=500    -- last dealer card face-up, before the result and the chips
B.CHIPS=800           -- chips to the rack / payout from the rack
B.CHIP_STAGGER=300    -- per seat, first base first, when the chips move at the result
B.RESULT=6500         -- result on the felt before the next round (sweep included)
B.SWEEP=2000          -- before the next round: cards to the discard tray

-- The croupier NPC standing behind every placed table (server/modules/
-- casino_blackjack.lua). `x`, `y` are board-local unscaled metres like the
-- client adapter's coordinates (dealer side = +Y, behind the shoe, the chip
-- rack and the wooden apron that ends at y=.26); the server applies the
-- table's 0.65 scale and rotation, and turns the body to face the players.
-- Records are tried in order until Open77.npcs.create accepts one: a game
-- croupier first (the Kabuki street-story gambling den, base game), then the
-- suited crowd faces the rental desks already spawn. No real-person likeness.
B.DEALER={
 x=0,y=.72,
 candidates={
  {record="Character.sts_wat_kab_07_croupiers"},
  {record="Character.mws_hey_07_zetatech_executive"},
  {record="Character.sts_hey_rey_06_receptionist"},
 },
 streamingRadius=60.0,
}

local function copy(t)
 if type(t)~="table" then return t end
 local n={} for k,v in pairs(t) do n[k]=copy(v) end return n
end
B.copy=copy
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<9007199254740991 end
local function integer(n,min,max) return finite(n) and n==math.floor(n) and n>=min and n<=max end
local function seatIndex(seat) for i,s in ipairs(B.SEATS) do if s==seat then return i end end end
B.seatIndex=seatIndex

local VALUES={A=11,T=10,J=10,Q=10,K=10}
function B.cardValue(code) local r=code:sub(1,1);return VALUES[r] or tonumber(r) end
-- Cards are codes ("AS", "TD") or public entries ({c="AS",t=ms}); a hidden
-- entry has no code and does not count. Answers the best total and softness.
function B.total(cards)
 local total,aces=0,0
 for _,card in ipairs(cards or {}) do
  local code=type(card)=="table" and card.c or card
  if type(code)=="string" then
   local v=B.cardValue(code)
   if v==11 then aces=aces+1 end
   total=total+v
  end
 end
 while total>21 and aces>0 do total=total-10;aces=aces-1 end
 return total,aces>0
end
function B.isBlackjack(cards)
 if #(cards or {})~=2 then return false end
 local total=B.total(cards);return total==21
end

-- Deterministic Park-Miller shuffle of B.DECKS decks from a server seed.
function B.shuffle(seed,decks)
 local cards={}
 for _=1,decks or B.DECKS do
  for s in ("SHDC"):gmatch(".") do for r in ("A23456789TJQK"):gmatch(".") do cards[#cards+1]=r..s end end
 end
 local state=math.floor(tonumber(seed) or 1)%2147483647
 if state<=0 then state=state+2147483646 end
 for i=#cards,2,-1 do
  state=(state*16807)%2147483647
  local j=math.floor(state%i)+1
  cards[i],cards[j]=cards[j],cards[i]
 end
 return cards
end
local function reshuffle(s,seed,now)
 s._shoe=B.shuffle(seed,B.DECKS);s._pos=1;s._cut=#s._shoe-B.RESERVE
 s.shuffledAt=now
end
local function publishShoe(s)
 s.shoe={left=#s._shoe-s._pos+1,total=#s._shoe,cut=s._pos>s._cut}
end
local function draw(s)
 if s._pos>#s._shoe then reshuffle(s,(#s._shoe*7919+s.round*104729)%2147483646+1,s.shuffledAt) end
 local card=s._shoe[s._pos];s._shoe[s._pos]=false;s._pos=s._pos+1
 return card
end

function B.new(mode,seed,now)
 local s={kind="blackjack",mode=mode or "duel",status="playing",ply=0,captured={},objects={},
  round=1,phase="betting",hands={},dealer={cards={},total=0}}
 reshuffle(s,seed or 1,now);publishShoe(s)
 return s
end

local function refresh(hand)
 hand.total,hand.soft=B.total(hand.cards)
end
local function refreshDealer(s)
 s.dealer.total,s.dealer.soft=B.total(s.dealer.cards)
end
-- When the last animated card has finished flipping.
local function cardEnd(card) return (card.f or (card.t+B.SLIDE))+B.FLIP end
-- Gross return for one settled hand (stake included), and the result label.
function B.settleHand(hand,dealerCards)
 local stake=hand.stake or hand.bet
 local total=B.total(hand.cards)
 local dealer=B.total(dealerCards)
 local dealerBJ=B.isBlackjack(dealerCards)
 local playerBJ=B.isBlackjack(hand.cards) and not hand.doubled
 if total>21 then return 0,"bust" end
 if dealerBJ then if playerBJ then return stake,"push" end return 0,"lose" end
 if playerBJ then return stake+math.floor(stake*3/2),"blackjack" end
 if dealer>21 or total>dealer then return stake*2,"win" end
 if total==dealer then return stake,"push" end
 return 0,"lose"
end

-- `at` is when the last player's card has settled: the dealer waits
-- REVEAL_PAUSE, turns the hole card, then draws one card at a time.
local function finish(s,at)
 -- Reveal the hole card, draw to 17 (stand on all 17s), settle every hand.
 local d=s.dealer
 local hole=d.cards[2]
 local reveal=at+B.REVEAL_PAUSE
 if hole and s._hole then hole.c=s._hole;hole.h=nil;hole.f=reveal;s._hole=nil end
 local last=reveal+B.FLIP
 local live=false
 for _,hand in pairs(s.hands) do
  if hand.total<=21 and not (B.isBlackjack(hand.cards) and not hand.doubled) then live=true end
 end
 if live and not B.isBlackjack(d.cards) then
  local t=reveal+B.FLIP+B.DRAW_PAUSE
  while B.total(d.cards)<17 do
   d.cards[#d.cards+1]={c=draw(s),t=t}
   last=t+B.SLIDE+B.FLIP;t=t+B.DRAW_GAP
  end
 end
 refreshDealer(s)
 s.phase="result";s.seatTurn=nil;s.turnEndsAt=nil
 -- resultAt is also when the claims become payable (server handler).
 s.revealAt=reveal;s.resultAt=last+B.SETTLE_PAUSE;s.nextAt=s.resultAt+B.RESULT;s.animEnd=last
 s.result={dealer=d.total,bust=d.total>21,blackjack=B.isBlackjack(d.cards)}
 for _,hand in pairs(s.hands) do
  hand.payout,hand.result=B.settleHand(hand,d.cards);hand.done=true
 end
 publishShoe(s)
 return s
end

local function nextTurn(s,from,at)
 local start=from and seatIndex(from)+1 or 1
 for i=start,#B.SEATS do
  local hand=s.hands[B.SEATS[i]]
  if hand and not hand.done then
   s.seatTurn=B.SEATS[i];s.turnEndsAt=at+B.TURN
   return s
  end
 end
 return finish(s,at)
end

local function deal(s,now,seed)
 if s._pos>s._cut then reshuffle(s,seed or 1,now) end
 local order={}
 for _,seat in ipairs(B.SEATS) do if s.hands[seat] then order[#order+1]=seat end end
 if #order==0 then return nil,"Place a bet first." end
 s.phase="playing";s.closesAt=nil;s.dealtAt=now
 s.dealer={cards={},total=0}
 local t=now
 for pass=1,2 do
  for _,seat in ipairs(order) do
   local hand=s.hands[seat];hand.cards[#hand.cards+1]={c=draw(s),t=t};t=t+B.DEAL_GAP
  end
  if pass==1 then s.dealer.cards[1]={c=draw(s),t=t}
  else s._hole=draw(s);s.dealer.cards[2]={h=true,t=t} end
  t=t+B.DEAL_GAP
 end
 local ends=t-B.DEAL_GAP+B.SLIDE+B.FLIP
 -- The cards settle, the dealer pauses, then the first player is asked.
 s.actAt=ends+B.DEAL_PAUSE;s.animEnd=ends
 for _,seat in ipairs(order) do
  local hand=s.hands[seat];refresh(hand)
  if hand.total==21 then hand.done=true;hand.natural=true end
 end
 refreshDealer(s)
 -- The dealer peeks under a ten or an ace: a natural ends the round at once.
 local up=B.cardValue(s.dealer.cards[1].c)
 if (up==10 or up==11) and B.total({s.dealer.cards[1].c,s._hole})==21 then return finish(s,ends) end
 return nextTurn(s,nil,s.actAt)
end

function B.legal(s,seat,now)
 local hand=s.phase=="playing" and s.seatTurn==seat and s.hands[seat]
 if not hand or hand.done or (now and s.actAt and now<s.actAt) then return {hit=false,stand=false,double=false} end
 return {hit=true,stand=true,double=#hand.cards==2 and not hand.doubled}
end

local function stand(s,seat,at)
 s.hands[seat].done=true
 return nextTurn(s,seat,at)
end

-- p.nowMs is the server clock; p.inventory names the stake owner (opaque);
-- p.seed shuffles a fresh shoe when the cut card has come out.
function B.act(s,seat,action,p)
 p=p or {}
 if type(s)~="table" or s.kind~="blackjack" or s.status~="playing" then return nil,"This table is closed." end
 if not seatIndex(seat) or type(action)~="string" then return nil,"Invalid blackjack action." end
 local now=p.nowMs
 if not finite(now) or now<0 then return nil,"The server must provide the time." end
 if action=="bet" then
  if s.phase~="betting" then return nil,"Bets are closed for this hand." end
  if not integer(p.amount,1,B.MAX_BET) then return nil,("Bet between %d and %d whole RP dollars."):format(B.MIN_BET,B.MAX_BET) end
  local hand=s.hands[seat]
  if hand and hand._inv~=p.inventory then return nil,"This seat already holds another player's bet." end
  local total=(hand and hand.bet or 0)+p.amount
  if total<B.MIN_BET or total>B.MAX_BET then return nil,("A hand takes %d to %d RP dollars."):format(B.MIN_BET,B.MAX_BET) end
  local n=copy(s)
  n.hands[seat]=n.hands[seat] or {cards={},total=0,_inv=p.inventory}
  n.hands[seat].bet=total;n.hands[seat].stake=total;n.hands[seat].betAt=now
  n.closesAt=n.closesAt or now+B.BET_WINDOW
  n.ply=n.ply+1
  return n
 elseif action=="deal" then
  if s.phase~="betting" then return nil,"The cards are already out." end
  local hand=s.hands[seat]
  if not hand or hand._inv~=p.inventory then return nil,"Place a bet to deal." end
  local n=copy(s);n.ply=n.ply+1
  return deal(n,now,p.seed)
 elseif action=="hit" or action=="stand" or action=="double" then
  if s.phase~="playing" then return nil,"No hand is being played." end
  if s.seatTurn~=seat then return nil,"It is not your turn." end
  local hand=s.hands[seat]
  if not hand or hand.done then return nil,"It is not your turn." end
  if hand._inv~=p.inventory then return nil,"This hand belongs to another player." end
  if s.actAt and now<s.actAt then return nil,"Wait for the cards to be dealt." end
  local n=copy(s);n.ply=n.ply+1
  local h=n.hands[seat]
  if action=="stand" then return stand(n,seat,math.max(now,n.animEnd or now)) end
  if action=="double" then
   if #h.cards~=2 or h.doubled then return nil,"Double only on your first two cards." end
   h.doubled=true;h.stake=h.bet*2
  end
  local t=math.max(now,n.animEnd or now)
  h.cards[#h.cards+1]={c=draw(n),t=t};refresh(h)
  n.animEnd=t+B.SLIDE+B.FLIP;n.turnEndsAt=n.animEnd+B.TURN
  publishShoe(n)
  if action=="double" or h.total>=21 then h.done=true;return nextTurn(n,seat,n.animEnd) end
  return n
 end
 return nil,"Unknown blackjack action."
end

-- Timed progress run by the server board loop.
function B.due(s,now)
 if type(s)~="table" or s.kind~="blackjack" or not finite(now) then return false end
 if s.phase=="betting" then return s.closesAt~=nil and now>=s.closesAt end
 if s.phase=="playing" then return s.turnEndsAt~=nil and now>=s.turnEndsAt end
 if s.phase=="result" then return s.nextAt~=nil and now>=s.nextAt end
 return false
end
function B.settle(s,now,seed)
 if not B.due(s,now) then return nil,"Nothing to settle." end
 local n=copy(s);n.ply=n.ply+1
 if s.phase=="betting" then return deal(n,now,seed) end
 if s.phase=="playing" then
  local seat=n.seatTurn;n.hands[seat].done=true;n.hands[seat].timedOut=true
  return nextTurn(n,seat,math.max(now,n.animEnd or now))
 end
 -- Next round: the shoe carries over until the cut card.
 n.round=n.round+1;n.phase="betting";n.hands={};n.dealer={cards={},total=0}
 n.closesAt=nil;n.actAt=nil;n.resultAt=nil;n.nextAt=nil;n.seatTurn=nil;n.turnEndsAt=nil
 n.result=nil;n.dealtAt=nil;n.animEnd=nil;n.revealAt=nil;n._roundKey=nil;n._hole=nil
 if n._pos>n._cut then reshuffle(n,seed or 1,now) end
 publishShoe(n)
 return n
end
-- Total gross return per stake owner once the round is settled.
function B.returns(s)
 local sums={}
 if s.phase~="result" then return sums end
 for _,hand in pairs(s.hands) do
  if hand._inv and (hand.payout or 0)>0 then sums[hand._inv]=(sums[hand._inv] or 0)+hand.payout end
 end
 return sums
end
-- Total open stakes per owner before the round is settled (refunds).
function B.stakes(s)
 local sums={}
 if s.phase=="result" then return sums end
 for _,hand in pairs(s.hands) do
  if hand._inv then sums[hand._inv]=(sums[hand._inv] or 0)+(hand.stake or hand.bet or 0) end
 end
 return sums
end
local function stripPrivate(t)
 if type(t)~="table" then return t end
 local n={}
 for k,v in pairs(t) do if not(type(k)=="string" and k:sub(1,1)=="_") then n[k]=stripPrivate(v) end end
 return n
end
function B.view(s) return stripPrivate(s) end
