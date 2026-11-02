-- Roulette stakes and payouts are durable inventory transactions. A disconnected
-- winner has a claim bound to the character inventory, never to a recycled seat.
local X={};LightRP.tabletopExtra=X
local Inv,Db=LightRP.inventory,LightRP.db
local paying={}
local lastClaimFailure={}
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_roulette_claims (
 round_key VARCHAR(128) NOT NULL, inventory_id VARCHAR(96) NOT NULL,
 amount BIGINT NOT NULL, available_at BIGINT NOT NULL, paid TINYINT NOT NULL DEFAULT 0,
 PRIMARY KEY(round_key,inventory_id), INDEX roulette_unpaid(inventory_id,paid,available_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
function X.now() return math.floor(Open77.time.unix()*1000) end
function X.supports(kind) return kind=="roulette" end
local function copy(t) if type(t)~="table" then return t end;local n={};for k,v in pairs(t) do n[k]=copy(v) end;return n end
local function seatOf(b,player) for seat,id in pairs(b.players) do if id==player then return seat end end end
local function claimQueries(key,totals,at)
 local out={}
 for inventory,amount in pairs(totals) do if amount>0 then
  out[#out+1]={query="INSERT INTO lightrp_roulette_claims (round_key,inventory_id,amount,available_at,paid) VALUES (?,?,?,?,0)",values={key,inventory,amount,at}}
 end end
 return out
end
function X.refunds(b)
 if b.kind=="roulette" and b.game.phase=="spinning" then return nil,"Wait for the roulette spin to finish." end
 if b.kind~="roulette" or not b.game._money or #b.game._money==0 then return {} end
 if b.game.phase~="betting" then return {} end
 local sums={};for _,bet in ipairs(b.game._money) do sums[bet.inventory]=(sums[bet.inventory] or 0)+bet.amount end
 return claimQueries(b.game._roundKey..":refund",sums,X.now())
end
function X.act(player,b,operation,data,commit)
 local R=LightRpTabletopExtraRules
 local seat=seatOf(b,player)
 if not seat then return false,"Join the table first." end
 if type(operation)~="string" or type(data)~="table" then return false,"Invalid tabletop action." end
 if operation=="bet" then
  local amount=tonumber(data.amount)
  if not amount or amount~=math.floor(amount) or amount<1 or amount>1000000 then return false,"Bet between 1 and 1,000,000 in whole RP dollars." end
  local game,why=R.act(b.game,seat,"bet",{bet=data.bet,amount=amount})
  if not game then return false,why end
  local inv=Inv.player(player);if not inv or not inv.persistent then return false,"Your inventory is not ready." end
  local draft=Inv.draft(inv);local ok,reason=Inv.adjustCash(draft,-amount)
  if not ok then return false,reason=="insufficient_funds" and "Not enough cash for this bet." or reason end
  game._roundKey=b.game._roundKey or (b.id..":"..tostring(b.revision+1))
  game._money=copy(b.game._money or {})
  game._money[#game._money+1]={inventory=inv.id,seat=seat,bet=data.bet,amount=amount}
  return commit(game,{},{{inv,draft}})
 elseif operation=="spin" then
  local game,why=R.act(b.game,seat,"spin",{outcome=math.random(0,36),nowMs=X.now(),seedAngle=math.random()*360})
  if not game then return false,why end
  game._roundKey=b.game._roundKey or (b.id..":"..tostring(b.revision+1));game._money=copy(b.game._money or {})
  local sums={}
  for _,bet in ipairs(game._money) do
   local gross=R.roulettePayout(bet.bet,game.spin.outcome,bet.amount)
   sums[bet.inventory]=(sums[bet.inventory] or 0)+gross
  end
  return commit(game,claimQueries(game._roundKey,sums,game.spin.endsAt))
 elseif operation=="nextRound" then
  local game,why=R.act(b.game,seat,"nextRound",{})
  if not game then return false,why end
  game._money=nil;game._roundKey=nil
  return commit(game)
 end
 return false,"Unknown roulette action."
end
function X.claim(player)
 if not Db.ready then return end
 local inv=Inv.player(player);if not inv or not inv.persistent or inv.busy then return end
 if paying[inv.id] then return end
 paying[inv.id]=true
 local called,ok,amount=pcall(function()
  return Inv.transaction(player,function(current)
   local read,rows=Db.read("SELECT round_key,amount FROM lightrp_roulette_claims WHERE inventory_id=? AND paid=0 AND available_at<=? ORDER BY available_at LIMIT 30",{current.id,X.now()})
   if not read then return false,"Roulette claim storage is unavailable." end
   if #rows==0 then return false end
   local total,queries=0,{}
   for _,row in ipairs(rows) do
    local n=tonumber(row.amount);if not n or n~=math.floor(n) or n<=0 or n>9007199254740991-total then return false,"Invalid pending roulette claim." end
    total=total+n
    queries[#queries+1]={query="UPDATE lightrp_roulette_claims SET paid=1 WHERE round_key=? AND inventory_id=? AND paid=0",values={row.round_key,current.id}}
   end
   local draft=Inv.draft(current);local can,why=Inv.adjustCash(draft,total);if not can then return false,why end
   local saved,why=Inv.commitDrafts({{current,draft}},queries)
   return saved,saved and total or why
  end)
 end)
 paying[inv.id]=nil
 if not called or (not ok and amount and amount~="busy") then
  local at=X.now()
  if not lastClaimFailure[inv.id] or at-lastClaimFailure[inv.id]>10000 then
   lastClaimFailure[inv.id]=at
   LightRP.log("roulette claim failed inventory=%s: %s",inv.id,tostring(called and amount or ok))
  end
 end
 local current=Inv.player(player)
 if called and ok and current and current.id==inv.id then LightRP.notice(player,{kind="success",title="Roulette",body="Received €$ "..tostring(amount).." in roulette winnings/refunds."}) end
end
LightRP.module("tabletop_extra",{onCharacterLoaded=function(player) X.claim(player) end})
CreateThread(function()
 while true do Wait(1000);if Db.ready then for _,id in ipairs(GetPlayers()) do X.claim(tonumber(id)) end end end
end)
