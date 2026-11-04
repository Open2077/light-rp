-- Fortune Wheel controller. The server picks the segment and the laps, debits
-- stakes and writes the winners' durable claims in the same transaction as the
-- spin; claims open when the spin ends. Clients only animate the plan.
local X=LightRP.tabletopExtra
local F=LightRpCasinoFortune
local function roundKey(b) return b.game._roundKey or (b.id..":"..tostring(b.revision+1)) end
local function act(player,b,seat,operation,data,commit)
 if operation=="bet" then
  local amount=tonumber(data.amount)
  if not amount or amount~=math.floor(amount) or amount<F.MIN_BET or amount>F.MAX_BET then
   return false,("Bet between %d and %d whole RP dollars."):format(F.MIN_BET,F.MAX_BET)
  end
  local inv=LightRP.inventory.player(player)
  if not inv or not inv.persistent then return false,"Your inventory is not ready." end
  -- Rules first (closed bets, limits), then the cash debit, then one commit.
  local key=b.game.phase=="result" and (b.id..":"..tostring(b.revision+1)) or roundKey(b)
  local game,why=F.bet(b.game,{inventory=inv.id,seat=seat,spot=data.spot,amount=amount,roundKey=key})
  if not game then return false,why end
  local staked,draft=X.stake(player,amount)
  if not staked then return false,draft end
  return commit(game,{},{{staked,draft}})
 elseif operation=="spin" then
  local key=b.game.phase=="result" and (b.id..":"..tostring(b.revision+1)) or roundKey(b)
  local game,totals=F.spin(b.game,{outcome=math.random(0,F.SEGMENTS-1),laps=math.random(2,3),nowMs=X.now(),roundKey=key})
  if not game then return false,totals end
  local staked={}
  for _,m in ipairs(game._money or {}) do staked[m.inventory]=(staked[m.inventory] or 0)+m.amount end
  return X.commitRound(commit,game,X.claimQueries(game._roundKey,totals,game.spin.endsAt),nil,"Fortune Wheel",staked,totals)
 end
 return false,"Unknown wheel action."
end
X.register("fortune",{
 openPlay=true,
 new=function(mode) return F.new(mode) end,
 act=act,
 refunds=function(b)
  if b.game.phase=="spinning" then return nil,"Wait for the wheel to stop." end
  local sums=F.stakes(b.game)
  if next(sums)==nil then return {} end
  return X.claimQueries(b.game._roundKey..":refund",sums,X.now())
 end,
 view=function(b,inv) return F.view(b.game,inv and inv.id) end,
 due=function(b,now) return b.game.phase=="spinning" and type(b.game.spin)=="table" and now>=b.game.spin.endsAt end,
 settle=function(b,now) local game=F.settle(b.game,now);return game end,
})
