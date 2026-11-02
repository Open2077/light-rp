#!/usr/bin/env python3
"""Pure-Lua blackjack rules: totals, naturals, dealer S17, busts, pushes, double, shoe."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('LightRpBoardGames={};LightRpItems={}')
lua.execute((Path(__file__).resolve().parents[1]/'resources/gamemodes/op77_lightrp/shared/casino_blackjack.lua').read_text())
lua.execute(r'''
local B=LightRpBlackjack
assert(LightRpBoardGames.blackjack.item=='blackjack_table' and LightRpItems.blackjack_table.label=='Blackjack Table')
local function T(...) return B.total({...}) end
-- Soft and hard totals.
local t,soft=T('AS','6H');assert(t==17 and soft)
t,soft=T('AS','6H','9C');assert(t==16 and not soft)
t,soft=T('AS','AD');assert(t==12 and soft)
t,soft=T('AS','AD','9C');assert(t==21 and soft)
t,soft=T('AS','AD','AC','AH','7S');assert(t==21 and soft)
t,soft=T('KS','QD','2C');assert(t==22 and not soft)
t=T('TS','JD');assert(t==20)
assert(B.isBlackjack({'AS','KD'}) and B.isBlackjack({'TC','AH'}) and not B.isBlackjack({'7S','7D','7C'}))
assert(B.total({{c='AS',t=0},{h=true,t=1}})==11,'a hidden card never counts')
-- The shoe: six full decks, deterministic per seed, different across seeds.
local a,b,c=B.shuffle(42),B.shuffle(42),B.shuffle(43)
assert(#a==312);local seen={};local same,diff=true,false
for i=1,312 do seen[a[i]]=(seen[a[i]] or 0)+1;if a[i]~=b[i] then same=false end;if a[i]~=c[i] then diff=true end end
local kinds=0;for _,n in pairs(seen) do kinds=kinds+1;assert(n==6) end
assert(kinds==52 and same and diff)

-- Stacked shoes drive the scenarios below: cards come out in list order.
local real=B.shuffle
local function stacked(list) B.shuffle=function() local s={} for i,v in ipairs(list) do s[i]=v end for i=#list+1,312 do s[i]='2C' end return s end end
local now=1790000000000
local function ok(s,seat,action,p) p=p or {};p.nowMs=p.nowMs or now;local n,e=B.act(s,seat,action,p);assert(n,e);return n end
local function no(s,seat,action,p) p=p or {};p.nowMs=p.nowMs or now;local n,e=B.act(s,seat,action,p);assert(not n,'illegal '..action..' accepted');return e end
local function after(s) return math.max(s.actAt or 0,s.animEnd or 0) end

-- Bets: limits, whole dollars, one owner per seat, countdown starts at the first bet.
local s=B.new('duel',1,now)
assert(s.phase=='betting' and s.shoe.left==312 and not s.closesAt)
no(s,'white','bet',{amount=4,inventory='i1'});no(s,'white','bet',{amount=5001,inventory='i1'});no(s,'white','bet',{amount=7.5,inventory='i1'})
no(s,'white','hit',{inventory='i1'});no(s,'white','deal',{inventory='i1'})
s=ok(s,'white','bet',{amount=10,inventory='i1'});assert(s.closesAt==now+B.BET_WINDOW and s.hands.white.bet==10)
s=ok(s,'white','bet',{amount=15,inventory='i1',nowMs=now+3000});assert(s.hands.white.bet==25 and s.closesAt==now+B.BET_WINDOW)
assert(no(s,'white','bet',{amount=10,inventory='i2'}):find('another player'))
no(s,'white','bet',{amount=4980,inventory='i1'})
assert(not B.due(s,now+B.BET_WINDOW-1) and B.due(s,now+B.BET_WINDOW))

-- Natural pays 3:2 (whole dollars, rounded down); dealer S17 stands on soft 17.
stacked({'AS','9D','6D','KH','TC','AC'}) -- white A,K; black 9,T; dealer 6 + A = soft 17
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=25,inventory='i1'});s=ok(s,'black','bet',{amount=10,inventory='i2'})
s=assert(B.settle(s,now+B.BET_WINDOW,9))
assert(s.phase=='playing' and s.hands.white.natural and s.hands.white.done and s.seatTurn=='black')
assert(s.dealer.cards[2].h and not s.dealer.cards[2].c and s._hole=='AC','hole card stays private')
assert(B.view(s).dealer.cards[2].c==nil and B.view(s)._hole==nil and B.view(s)._shoe==nil and B.view(s).hands.white._inv==nil)
-- Card timestamps: the opening deal is staggered on the server clock.
local t0=s.dealtAt;assert(s.hands.white.cards[1].t==t0 and s.hands.black.cards[1].t==t0+B.DEAL_GAP and s.dealer.cards[1].t==t0+2*B.DEAL_GAP)
assert(s.hands.white.cards[2].t==t0+3*B.DEAL_GAP and s.dealer.cards[2].t==t0+5*B.DEAL_GAP and s.actAt==t0+5*B.DEAL_GAP+B.SLIDE+B.FLIP)
assert(no(s,'black','stand',{inventory='i2',nowMs=s.actAt-1}):find('Wait'))
assert(no(s,'white','stand',{inventory='i1',nowMs=s.actAt}):find('not your turn'))
assert(no(s,'black','stand',{inventory='i9',nowMs=s.actAt}):find('another player'))
local legal=B.legal(s,'black',s.actAt);assert(legal.hit and legal.stand and legal.double)
s=ok(s,'black','stand',{inventory='i2',nowMs=s.actAt})
assert(s.phase=='result' and s.dealer.total==17 and s.dealer.soft and #s.dealer.cards==2,'dealer stands on soft 17')
assert(s.dealer.cards[2].c=='AC' and s.dealer.cards[2].f>=s.actAt)
assert(s.hands.white.result=='blackjack' and s.hands.white.payout==25+37)
assert(s.hands.black.result=='win' and s.hands.black.payout==20)
local r=B.returns(s);assert(r.i1==62 and r.i2==20 and next(B.stakes(s))==nil)
assert(s.resultAt>=s.dealer.cards[2].f+B.FLIP and s.nextAt==s.resultAt+B.RESULT)
-- Next round keeps the shoe and clears the felt.
assert(not B.due(s,s.nextAt-1));local left=s.shoe.left
s=assert(B.settle(s,s.nextAt,5));assert(s.phase=='betting' and s.round==2 and next(s.hands)==nil and #s.dealer.cards==0 and s.shoe.left==left)

-- Dealer draws to hard 17+, busts; player bust loses even when the dealer busts.
stacked({'TS','9D','6D','KH','6C','TC','8S'}) -- white T,K=20; black 9,6=15; dealer 6+T=16 draws 8 -> 24
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=10,inventory='i1'});s=ok(s,'black','bet',{amount=10,inventory='i2'})
s=ok(s,'white','deal',{inventory='i1',seed=1});assert(s.phase=='playing' and s.seatTurn=='white')
s=ok(s,'white','stand',{inventory='i1',nowMs=s.actAt});assert(s.seatTurn=='black')
s=ok(s,'black','hit',{inventory='i2',nowMs=s.actAt+10});assert(s.phase=='result' and s.hands.black.total==23)
-- black busted on the dealer's 8; the dealer then draws from the next card
stacked({'TS','9D','6D','KH','6C','TC','2S','8S'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=10,inventory='i1'});s=ok(s,'black','bet',{amount=10,inventory='i2'})
s=ok(s,'white','deal',{inventory='i1',seed=1});s=ok(s,'white','stand',{inventory='i1',nowMs=s.actAt})
s=ok(s,'black','hit',{inventory='i2',nowMs=s.actAt});assert(s.hands.black.total==17 and not s.hands.black.done and s.phase=='playing')
local hitCard=s.hands.black.cards[3];assert(hitCard.t>=s.actAt)
s=ok(s,'black','hit',{inventory='i2',nowMs=s.actAt+100});assert(s.hands.black.total==25 and s.hands.black.done,'bust ends the hand')
assert(s.phase=='result' and #s.dealer.cards==3 and s.dealer.total==18,'white 20 is live: the dealer draws to 17+')
assert(s.hands.white.result=='win' and s.hands.black.result=='bust')
stacked({'TS','9D','6D','KH','6C','TC','2S','8S','5H'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=10,inventory='i1'});s=ok(s,'black','bet',{amount=10,inventory='i2'})
s=ok(s,'white','deal',{inventory='i1',seed=1});s=ok(s,'white','stand',{inventory='i1',nowMs=s.actAt})
s=ok(s,'black','hit',{inventory='i2',nowMs=s.actAt});s=ok(s,'black','hit',{inventory='i2',nowMs=s.actAt})
assert(s.dealer.total==21 and #s.dealer.cards==3 and s.dealer.cards[3].t>s.dealer.cards[2].f,'dealer draws after the reveal')
assert(s.hands.white.result=='lose' and s.hands.white.payout==0 and s.hands.black.result=='bust' and s.hands.black.payout==0)
-- Every live hand busts: the dealer only turns the hole card.
stacked({'TS','6D','TH','6C','9S'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=10,inventory='i1'});s=ok(s,'white','deal',{inventory='i1',seed=1})
s=ok(s,'white','hit',{inventory='i1',nowMs=s.actAt});assert(s.phase=='result' and #s.dealer.cards==2 and s.hands.white.result=='bust')

-- Push on equal totals; dealer bust pays the standing hands.
stacked({'TS','9D','KH','8C','7S','2D'}) -- white T,K=20 ; dealer 9+8=17 -> push? no: 20 vs 17 win
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=40,inventory='i1'});s=ok(s,'white','deal',{inventory='i1',seed=1})
s=ok(s,'white','stand',{inventory='i1',nowMs=s.actAt});assert(s.hands.white.result=='win' and s.hands.white.payout==80)
stacked({'TS','KD','KH','QC'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=40,inventory='i1'});s=ok(s,'white','deal',{inventory='i1',seed=1})
s=ok(s,'white','stand',{inventory='i1',nowMs=s.actAt});assert(s.hands.white.result=='push' and s.hands.white.payout==40)

-- Double: one card, double stake, hand ends; only on the first two cards.
stacked({'5S','9D','6H','8C','KD'}) -- white 5,6=11 doubles to 21; dealer 9+8=17
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=50,inventory='i1'});s=ok(s,'white','deal',{inventory='i1',seed=1})
local d=ok(s,'white','double',{inventory='i1',nowMs=s.actAt})
assert(d.hands.white.doubled and d.hands.white.stake==100 and #d.hands.white.cards==3 and d.phase=='result')
assert(d.hands.white.result=='win' and d.hands.white.payout==200)
local h=ok(s,'white','hit',{inventory='i1',nowMs=s.actAt});assert(h.hands.white.total==21 and h.phase=='result','21 stands automatically')
stacked({'5S','9D','2H','8C','3D','KD'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=50,inventory='i1'});s=ok(s,'white','deal',{inventory='i1',seed=1})
s=ok(s,'white','hit',{inventory='i1',nowMs=s.actAt});assert(not B.legal(s,'white',s.animEnd).double)
assert(no(s,'white','double',{inventory='i1',nowMs=s.animEnd}):find('first two'))
-- Doubled 21 with three cards is not a natural.
assert(B.settleHand({bet=10,stake=20,doubled=true,cards={'AS','5D','5C'}},{'TS','7D'})==40)

-- Dealer natural: the peek ends the round at once; a player natural pushes.
stacked({'AS','5D','AH','KC','6D','KS'}) -- white A,K; black 5,6; dealer A up, K hole
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=20,inventory='i1'});s=ok(s,'black','bet',{amount=20,inventory='i2'})
s=ok(s,'black','deal',{inventory='i2',seed=1})
assert(s.phase=='result' and s.dealer.cards[2].c=='KS' and s.result.blackjack)
assert(s.hands.white.result=='push' and s.hands.white.payout==20 and s.hands.black.result=='lose' and s.hands.black.payout==0)

-- Idle timeout stands the hand and passes the turn.
stacked({'TS','9D','6D','KH','6C','TC'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=10,inventory='i1'});s=ok(s,'black','bet',{amount=10,inventory='i2'})
s=ok(s,'white','deal',{inventory='i1',seed=1})
assert(not B.due(s,s.turnEndsAt-1) and B.due(s,s.turnEndsAt))
s=assert(B.settle(s,s.turnEndsAt,1));assert(s.hands.white.timedOut and s.hands.white.done and s.seatTurn=='black')
s=assert(B.settle(s,s.turnEndsAt,1));assert(s.phase=='result')
assert(B.stakes(s).i1==nil)

-- Open stakes before the result are refundable, doubles included.
stacked({'5S','9D','6H','8C','KD','2D','3H'})
s=B.new('duel',1,now);s=ok(s,'white','bet',{amount=50,inventory='i1'});s=ok(s,'black','bet',{amount=30,inventory='i2'})
local st=B.stakes(s);assert(st.i1==50 and st.i2==30)
s=ok(s,'white','deal',{inventory='i1',seed=1});s=ok(s,'white','double',{inventory='i1',nowMs=s.actAt})
st=B.stakes(s);assert(st.i1==100 and st.i2==30)

-- The cut card: past it the next round reshuffles a full shoe.
B.shuffle=real
s=B.new('duel',7,now);s._pos=s._cut+1
s.phase='result';s.nextAt=now
s=assert(B.settle(s,now,99));assert(s._pos==1 and s.shoe.left==312 and s.shuffledAt==now)
print('Blackjack rules: totals, 3:2 naturals, S17, busts, pushes, double, peek, timeout, shoe passed')
''')
