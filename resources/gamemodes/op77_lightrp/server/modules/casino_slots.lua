-- Slot machine handler for LightRP.tabletopExtra (see its header for the contract).
-- A pull debits the stake, fixes the outcome (server math.random) and inserts the
-- payout claim in ONE commit; the claim becomes payable when the last reel stops.
-- The outcome is public from the pull on (every client animates the reels to it),
-- so pickup/reset are refused until the reels stop: a mid-spin refund would let
-- the owner read a losing outcome and void it. There is never an open stake.
local X=LightRP.tabletopExtra
local S=LightRpCasinoSlots

local function pull(player,b,seat,data,commit)
 if seat~="white" then return false,"Only the player at the machine can pull the lever." end
 local bet=tonumber(data.bet)
 if not bet or bet~=math.floor(bet) or bet<S.MIN_BET or bet>S.MAX_BET then return false,S.BET_TEXT end
 local now=X.now()
 local stops={math.random(0,S.STOPS-1),math.random(0,S.STOPS-1),math.random(0,S.STOPS-1)}
 local game,why=S.act(b.game,seat,"pull",{bet=bet,stops=stops,nowMs=now})
 if not game then return false,why end
 local inv,draft=X.stake(player,bet)
 if not inv then return false,draft end
 game._inventory=inv.id
 local key=b.id..":"..tostring(b.revision+1)
 local queries=X.claimQueries(key,{[inv.id]=game.spin.gross},game.spin.endsAt)
 -- one ledger line for the pull: the stake out, the gross return in
 return X.commitRound(commit,game,queries,{{inv,draft}},"Slots",{[inv.id]=bet},{[inv.id]=game.spin.gross},{[inv.id]=bet})
end

X.register("slots",{
 openPlay=true,
 new=function(mode) return S.new(mode) end,
 act=function(player,b,seat,operation,data,commit)
  if operation=="pull" then return pull(player,b,seat,data,commit) end
  return false,"Unknown slot machine action."
 end,
 refunds=function(b)
  local spin=b.game.spin
  if b.game.phase=="spinning" and type(spin)=="table" and X.now()<spin.endsAt then return nil,"Wait for the reels to stop." end
  return {} -- the payout claim (if any) is already durable
 end,
 view=function(b,inv)
  local game=X.strip(b.game)
  game.yours=inv~=nil and b.game._inventory==inv.id
  return game
 end,
 due=function(b,now) return b.game.phase=="spinning" and type(b.game.spin)=="table" and now>=b.game.spin.endsAt end,
 settle=function(b,now) return S.act(b.game,"white","settle",{nowMs=now}) end,
})
