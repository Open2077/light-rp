-- Casino tables plug in here. Stakes and payouts are durable inventory
-- transactions: a disconnected winner has a claim bound to the character
-- inventory, never to a recycled seat. Each game registers a handler:
--   X.register(kind,{
--     new=function(mode) return game end,                 -- fresh authoritative state
--     act=function(player,b,seat,operation,data,commit) end, -- commit(game,queries,changes)
--     view=function(b,inv) return publicGame end,         -- optional; default strips "_" keys
--     refunds=function(b) return queries end,             -- optional; nil,reason blocks pickup/reset
--     due=function(b,now) return bool end,                -- optional timed settlement...
--     settle=function(b,now) return game,queries end,     -- ...run by the board loop
--     openPlay=true,                                      -- anyone seated nearby may act
--     modes={duel=true,solo=true},                        -- optional; the board modes the owner may pick
--     placed=function(b) end,                             -- optional: the table exists (placed, or loaded at start)
--     removed=function(b) end,                            -- optional: the table was picked up
--     npc=function(b) return npcId end,                   -- optional: the table's own NPC (the
--                                                         -- blackjack dealer), published to clients
--                                                         -- so the ALT menu resolves it to its table
--   })
-- placed/removed run after the durable write (or the start-up load) and must
-- not yield or fail the caller: they are protected and only logged.
-- Helpers for handlers: X.now, X.copy, X.stake, X.claimQueries, X.strip.
local X={};LightRP.tabletopExtra=X
X.games={}
local Inv,Db=LightRP.inventory,LightRP.db
local paying={}
local lastClaimFailure={}
-- What X.claim knows per inventory id, so that it does not lock every
-- inventory every second (a locked inventory makes other money requests
-- wait): nil = unknown (one lock-free read decides), false = nothing to pay,
-- a number = the earliest known available_at of a claim written since.
-- claimQueries marks every claim it writes (a claim whose transaction then
-- fails only costs one more read); a generation per inventory keeps a read
-- that raced a new claim from clearing it.
local claimable,claimGeneration={},{}
local CLAIM_HORIZON_MS=86400000 -- claims are available within seconds or minutes of their round
local function markClaim(inventory,at)
 claimGeneration[inventory]=(claimGeneration[inventory] or 0)+1
 local due=claimable[inventory]
 if due==nil then return end -- unknown: the next claim pass reads anyway
 at=tonumber(at) or 0
 claimable[inventory]=type(due)=="number" and math.min(due,at) or at
end
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_roulette_claims (
 round_key VARCHAR(128) NOT NULL, inventory_id VARCHAR(96) NOT NULL,
 amount BIGINT NOT NULL, available_at BIGINT NOT NULL, paid TINYINT NOT NULL DEFAULT 0,
 PRIMARY KEY(round_key,inventory_id), INDEX roulette_unpaid(inventory_id,paid,available_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
function X.now() return math.floor(Open77.time.unix()*1000) end
function X.register(kind,handler) X.games[kind]=handler end
function X.supports(kind) return X.games[kind]~=nil end
function X.openPlay(kind) local h=X.games[kind];return h~=nil and h.openPlay==true end
local function copy(t) if type(t)~="table" then return t end;local n={};for k,v in pairs(t) do n[k]=copy(v) end;return n end
X.copy=copy
-- A copy without private ("_"-prefixed) keys at any depth, for clients.
function X.strip(t)
 if type(t)~="table" then return t end
 local n={};for k,v in pairs(t) do if not(type(k)=="string" and k:sub(1,1)=="_") then n[k]=X.strip(v) end end
 return n
end
local function seatOf(b,player) for seat,id in pairs(b.players) do if id==player then return seat end end end
-- Debit a whole-dollar stake: answers inventory and draft for commit's changes.
-- A locked inventory (a payout, a shop, a transfer being saved) answers a
-- clear retry message; the request handler does not lock it for game
-- operations, the commit does (board_games.lua commitGame).
X.BUSY="Your inventory is saving another payment. Try again in a moment."
function X.stake(player,amount)
 if type(amount)~="number" or amount~=math.floor(amount) or amount<1 or amount>1000000 then return nil,"Bet between 1 and 1,000,000 in whole RP dollars." end
 local inv=Inv.player(player);if not inv or not inv.persistent then return nil,"Your inventory is not ready." end
 if inv.busy then
  LightRP.log("tabletop stake refused player=%s inventory=%s: inventory busy",tostring(player),tostring(inv.id))
  return nil,X.BUSY
 end
 local draft=Inv.draft(inv);local ok,reason=Inv.adjustCash(draft,-amount)
 if not ok then return nil,reason=="insufficient_funds" and "Not enough cash for this bet." or reason end
 return inv,draft
end
local function claimQueries(key,totals,at)
 local out={}
 for inventory,amount in pairs(totals) do if amount>0 then
  out[#out+1]={query="INSERT INTO lightrp_roulette_claims (round_key,inventory_id,amount,available_at,paid) VALUES (?,?,?,?,0)",values={key,inventory,amount,at}}
  markClaim(inventory,at)
 end end
 return out
end
X.claimQueries=claimQueries
function X.new(kind,mode) return X.games[kind].new(mode or "duel") end
function X.view(b,inv)
 local h=X.games[b.kind]
 if h.view then return h.view(b,inv) end
 return X.strip(b.game)
end
function X.refunds(b)
 local h=X.games[b.kind]
 if h and h.refunds then return h.refunds(b) end
 return {}
end
-- World presence of a table (e.g. the blackjack dealer NPC). Never raises.
local function lifecycle(hook,b)
 local h=type(b)=="table" and X.games[b.kind]
 if not h or type(h[hook])~="function" then return end
 local ok,why=pcall(h[hook],b)
 if not ok then LightRP.log("tabletop_extra %s hook failed board=%s kind=%s: %s",hook,tostring(b.id),tostring(b.kind),tostring(why)) end
end
-- The table's own NPC id (nil: none, or not spawned yet). Never raises.
function X.npc(b)
 local h=type(b)=="table" and X.games[b.kind]
 if not h or type(h.npc)~="function" then return nil end
 local ok,id=pcall(h.npc,b)
 return ok and id or nil
end
function X.placed(b) lifecycle("placed",b) end
function X.removed(b) lifecycle("removed",b) end
function X.act(player,b,operation,data,commit)
 local h=X.games[b.kind];if not h then return false,"Unknown table." end
 local seat=seatOf(b,player)
 if not seat then return false,"Join the table first." end
 if type(operation)~="string" or type(data)~="table" then return false,"Invalid tabletop action." end
 return h.act(player,b,seat,operation,data,commit)
end
-- Roulette ------------------------------------------------------------------
local function rouletteRefunds(b)
 if b.kind=="roulette" and b.game.phase=="spinning" then return nil,"Wait for the roulette spin to finish." end
 if b.kind~="roulette" or not b.game._money or #b.game._money==0 then return {} end
 if b.game.phase~="betting" then return {} end
 local sums={};for _,bet in ipairs(b.game._money) do sums[bet.inventory]=(sums[bet.inventory] or 0)+bet.amount end
 return claimQueries(b.game._roundKey..":refund",sums,X.now())
end
local function rouletteAct(player,b,seat,operation,data,commit)
 local R=LightRpTabletopExtraRules
 if operation=="bet" then
  local amount=tonumber(data.amount)
  if not amount or amount~=math.floor(amount) or amount<R.MIN_BET or amount>R.MAX_BET then return false,("Bet between %d and %d whole RP dollars."):format(R.MIN_BET,R.MAX_BET) end
  local game,why=R.act(b.game,seat,"bet",{bet=data.bet,amount=amount})
  if not game then return false,why end
  -- R.MAX_ROUND per character and spin, whatever seat it bets from
  local mine=Inv.player(player)
  if mine and b.game.phase=="betting" then
   local staked=0
   for _,bet in ipairs(b.game._money or {}) do if bet.inventory==mine.id then staked=staked+bet.amount end end
   if staked+amount>R.MAX_ROUND then return false,("Your stakes are limited to %d per spin."):format(R.MAX_ROUND) end
  end
  local inv,draft=X.stake(player,amount)
  if not inv then return false,draft end
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
X.register("roulette",{
 openPlay=true,
 new=function(mode) return LightRpTabletopExtraRules.new("roulette",mode) end,
 act=rouletteAct,
 refunds=rouletteRefunds,
 view=function(b,inv)
  local game=LightRpTabletopExtraRules.view(b.game)
  game.yourStake=0
  for _,bet in ipairs(b.game._money or {}) do if inv and bet.inventory==inv.id then game.yourStake=game.yourStake+bet.amount end end
  return game
 end,
 due=function(b,now) return b.game.phase=="spinning" and type(b.game.spin)=="table" and now>=b.game.spin.endsAt end,
 settle=function(b,now) return LightRpTabletopExtraRules.act(b.game,"white","settle",{nowMs=now}) end,
})
local function claimFailed(inv,why)
 local at=X.now()
 if not lastClaimFailure[inv.id] or at-lastClaimFailure[inv.id]>10000 then
  lastClaimFailure[inv.id]=at
  LightRP.log("roulette claim failed inventory=%s: %s",inv.id,tostring(why))
 end
end
-- Pays what is due to a character (table winnings and refunds), exactly once:
-- the claims are marked paid in the same transaction as the cash. Runs every
-- second for every player; the inventory is locked only when something is
-- due (see claimable above).
function X.claim(player)
 if not Db.ready then return end
 local inv=Inv.player(player);if not inv or not inv.persistent or inv.busy then return end
 if paying[inv.id] then return end
 local id,now=inv.id,X.now()
 local due=claimable[id]
 if due==false or (type(due)=="number" and due>now) then return end
 paying[id]=true
 -- A lock-free look first: the earliest unpaid claim, if any.
 local generation=claimGeneration[id] or 0
 local called,read,rows=pcall(Db.read,"SELECT round_key,amount,available_at FROM lightrp_roulette_claims WHERE inventory_id=? AND paid=0 AND available_at<=? ORDER BY available_at LIMIT 1",{id,now+CLAIM_HORIZON_MS})
 if not called or not read then paying[id]=nil;claimFailed(inv,called and "Roulette claim storage is unavailable." or read);return end
 local first=rows[1]
 local at=first and tonumber(first.available_at)
 if (claimGeneration[id] or 0)~=generation then claimable[id]=nil -- a claim was written meanwhile: look again
 elseif not first then claimable[id]=false
 elseif at and at>now then claimable[id]=at end
 if not first or (at and at>now) then paying[id]=nil;return end
 local ok,amount
 called,ok,amount=pcall(function()
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
 paying[id]=nil
 -- Paid or not, look again next pass (more than 30 rows, a failed commit, a
 -- busy lock); the look is a cheap read until the inventory is settled.
 claimable[id]=nil
 if not called or (not ok and amount and amount~="busy") then claimFailed(inv,called and amount or ok) end
 local current=Inv.player(player)
 if called and ok and current and current.id==inv.id then LightRP.notice(player,{kind="success",title="Casino",body="Received €$ "..tostring(amount).." in table winnings/refunds."}) end
end
-- A character (re)loaded: what it is owed is unknown again (one cheap read).
function X.forget(inventory) if inventory then claimable[inventory]=nil end end
LightRP.module("tabletop_extra",{onCharacterLoaded=function(player)
 local inv=Inv.player(player);if inv then X.forget(inv.id) end
 X.claim(player)
end})
CreateThread(function()
 while true do Wait(1000);if Db.ready then for _,id in ipairs(GetPlayers()) do X.claim(tonumber(id)) end end end
end)
