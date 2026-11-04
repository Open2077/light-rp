-- Slot machine: inventory item, table kind and pure deterministic rules.
-- No randomness here: the server picks the reel stops and passes them in.
LightRpBoardGames.slots={item="slot_machine",label="Slot Machine",title="Slot Machine",size=1,floor=0}
LightRpItems.slot_machine={label="Slot Machine",description="Use to place the machine. E: play; target menu: pick up your machine.",weight=8,stack=1,icon="package",category="misc"}

LightRpCasinoSlots={}
local S=LightRpCasinoSlots
-- Stakes per pull (owner decision 2026-11-04, docs/economy-balance.md §16: casino max
-- bets / 10). Every return is a multiple of the bet: the 200x jackpot falls with it.
S.MIN_BET,S.MAX_BET=1,100
S.BET_TEXT=("Bet between %d and %d in whole RP dollars."):format(S.MIN_BET,S.MAX_BET)
S.STOPS=12 -- stops per reel; weighting comes from how often a symbol repeats
S.SYMBOLS={"cherry","lemon","grape","bell","bar","chip","diamond","seven"}
S.LABELS={cherry="Cherry",lemon="Lemon",grape="Grape",bell="Bell",bar="Bar",chip="Chip",diamond="Diamond",seven="Seven"}
-- Reel strips in spin order. The authored strip meshes in open77_casino_slots
-- carry the same order (tools/build-casino-slots-props.py asserts it).
S.REELS={
 {"cherry","lemon","bell","grape","cherry","bar","lemon","seven","grape","chip","cherry","diamond"},
 {"lemon","grape","cherry","bell","lemon","seven","grape","bar","bell","chip","cherry","diamond"},
 {"grape","lemon","bell","cherry","lemon","bar","grape","seven","lemon","chip","bell","diamond"},
}
-- Gross returns per 1 staked (the stake is included). RTP 1632/1728 = 94.4 %.
S.THREE={seven=200,diamond=100,chip=50,bar=30,bell=18,grape=10,cherry=10,lemon=8}
S.TWO_CHERRIES=4  -- cherry on reels 1 and 2
S.MIXED_FRUIT=2   -- any cherry/lemon/grape on all three reels
S.ONE_CHERRY=1    -- cherry on reel 1: stake back
-- Shared timeline (ms after the pull) so every client and the server agree.
S.TIMING={lever=600,reelStart=250,settle=250,stops={1800,2400,3000}}
S.DURATION=3000
local FRUIT={cherry=true,lemon=true,grape=true}
local function copy(t)
 if type(t)~="table" then return t end
 local n={} for k,v in pairs(t) do n[k]=copy(v) end return n
end
local function integer(n,min,max) return type(n)=="number" and n==n and n==math.floor(n) and n>=min and n<=max end
local function validStops(stops)
 if type(stops)~="table" then return false end
 for r=1,3 do if not integer(stops[r],0,S.STOPS-1) then return false end end
 return true
end
S.validStops=validStops
-- Payline symbol of each reel for 0-based stops.
function S.symbols(stops)
 if not validStops(stops) then return nil end
 return {S.REELS[1][stops[1]+1],S.REELS[2][stops[2]+1],S.REELS[3][stops[3]+1]}
end
-- Multiplier and a short English label for the payline.
function S.evaluate(stops)
 local s=S.symbols(stops);if not s then return nil,"Invalid reel stops." end
 local a,b,c=s[1],s[2],s[3]
 if a==b and b==c then return S.THREE[a],"Three "..S.LABELS[a].."s",s end
 if a=="cherry" and b=="cherry" then return S.TWO_CHERRIES,"Two Cherries",s end
 if FRUIT[a] and FRUIT[b] and FRUIT[c] then return S.MIXED_FRUIT,"Mixed Fruit",s end
 if a=="cherry" then return S.ONE_CHERRY,"Cherry",s end
 return 0,"No win",s
end
function S.payout(stops,bet)
 if not integer(bet,S.MIN_BET,S.MAX_BET) then return nil,S.BET_TEXT end
 local multiplier,why=S.evaluate(stops);if not multiplier then return nil,why end
 return bet*multiplier
end
function S.new(mode)
 return {kind="slots",mode=mode or "duel",turn="white",status="playing",ply=0,captured={},objects={},
  round=0,phase="idle",stops={0,0,0}}
end
-- pull: {bet,stops,nowMs} from the server. settle: {nowMs} once the reels stop.
function S.act(s,seat,action,p)
 if type(s)~="table" or s.kind~="slots" or s.status~="playing" then return nil,"This machine is not ready." end
 if type(p)~="table" then return nil,"Invalid slot action." end
 local now=p.nowMs
 if type(now)~="number" or now~=now or now<0 then return nil,"The server must provide the time." end
 if action=="pull" then
  if seat~="white" then return nil,"Only the player at the machine can pull the lever." end
  if s.phase=="spinning" and s.spin and now<s.spin.endsAt then return nil,"The reels are still spinning." end
  if not integer(p.bet,S.MIN_BET,S.MAX_BET) then return nil,S.BET_TEXT end
  if not validStops(p.stops) then return nil,"The server must provide the reel stops." end
  local multiplier=S.evaluate(p.stops)
  local n=copy(s);n.round=n.round+1;n.ply=n.ply+1;n.phase="spinning";n.bet=p.bet
  n.spin={at=now,endsAt=now+S.DURATION,from=copy(s.stops),stops=copy(p.stops),bet=p.bet,gross=p.bet*multiplier,round=n.round}
  n.stops=copy(p.stops);n.last=nil
  return n
 elseif action=="settle" then
  if s.phase~="spinning" or not s.spin or now<s.spin.endsAt then return nil,"The reels are still spinning." end
  local n=copy(s);n.phase="idle";n.ply=n.ply+1
  local multiplier,label=S.evaluate(n.spin.stops)
  n.last={round=n.spin.round,bet=n.spin.bet,gross=n.spin.gross,multiplier=multiplier,label=label}
  return n
 end
 return nil,"Unknown slot action."
end
