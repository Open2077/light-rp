-- Blackjack table handler (see the contract in tabletop_extra.lua). The rules
-- in shared/casino_blackjack.lua decide the hands; this file binds stakes to
-- character inventories, seeds the shoe and turns settled hands into durable
-- claims, available when the dealer's reveal has finished on every client.
local X=LightRP.tabletopExtra
local B=LightRpBlackjack
local Inv=LightRP.inventory
local function seed() return math.random(1,2147483646) end
local function inventoryId(player)
 local inv=Inv.player(player)
 return inv and inv.persistent and inv.id or nil
end
-- The round became settled in this change: one claim per stake owner, paid
-- once the reveal animation ends.
local function claims(before,after)
 if after.phase~="result" or before.phase=="result" then return {} end
 return X.claimQueries(after._roundKey,B.returns(after),after.resultAt)
end
local function act(player,b,seat,operation,data,commit)
 local now=X.now()
 local inventory=inventoryId(player)
 if not inventory then return false,"Your inventory is not ready." end
 if operation=="bet" then
  local amount=tonumber(data.amount)
  if not amount or amount~=math.floor(amount) or amount<1 or amount>B.MAX_BET then
   return false,("Bet between %d and %d whole RP dollars."):format(B.MIN_BET,B.MAX_BET)
  end
  local game,why=B.act(b.game,seat,"bet",{amount=amount,nowMs=now,inventory=inventory})
  if not game then return false,why end
  local inv,draft=X.stake(player,amount)
  if not inv then return false,draft end
  game._roundKey=b.game._roundKey or (b.id..":"..tostring(b.revision+1))
  return commit(game,{},{{inv,draft}})
 elseif operation=="double" then
  local hand=b.game.hands and b.game.hands[seat]
  local game,why=B.act(b.game,seat,"double",{nowMs=now,inventory=inventory})
  if not game then return false,why end
  local inv,draft=X.stake(player,hand.bet)
  if not inv then return false,draft end
  return commit(game,claims(b.game,game),{{inv,draft}})
 elseif operation=="hit" or operation=="stand" or operation=="deal" then
  local game,why=B.act(b.game,seat,operation,{nowMs=now,inventory=inventory,seed=seed()})
  if not game then return false,why end
  return commit(game,claims(b.game,game))
 end
 return false,"Unknown blackjack action."
end
X.register("blackjack",{
 openPlay=true,
 seats=4,
 new=function(mode) return B.new(mode,seed(),X.now()) end,
 act=act,
 view=function(b) return B.view(b.game) end,
 -- Open stakes go back to their owners when the table is reset or picked up
 -- before the hand resolves; a settled round already holds its claims.
 refunds=function(b)
  local sums=B.stakes(b.game)
  if next(sums)==nil or not b.game._roundKey then return {} end
  return X.claimQueries(b.game._roundKey..":refund",sums,X.now())
 end,
 due=function(b,now) return B.due(b.game,now) end,
 settle=function(b,now)
  local game=B.settle(b.game,now,seed())
  if not game then return nil end
  return game,claims(b.game,game)
 end,
})
