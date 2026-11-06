local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
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
-- once the reveal animation ends, and one net ledger line per stake owner
-- (X.ledgerLines). `unsettled`: the stakes debited by this same commit (a
-- double). Answers the queries and the function to run once committed.
local function claims(before,after,unsettled)
 if after.phase~="result" or before.phase=="result" then return {},nil end
 local returned=B.returns(after)
 local queries=X.claimQueries(after._roundKey,returned,after.resultAt)
 local staked={}
 for _,hand in pairs(after.hands or {}) do
  if hand._inv then staked[hand._inv]=(staked[hand._inv] or 0)+(hand.stake or hand.bet or 0) end
 end
 local lines,logged=X.ledgerLines("Blackjack",staked,returned,unsettled)
 for _,query in ipairs(lines) do queries[#queries+1]=query end
 return queries,logged
end
local function commitWith(commit,game,queries,changes,logged)
 local ok,why=commit(game,queries,changes)
 if ok and logged then logged() end
 return ok,why
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
  local queries,logged=claims(b.game,game,{[inv.id]=hand.bet})
  return commitWith(commit,game,queries,{{inv,draft}},logged)
 elseif operation=="hit" or operation=="stand" or operation=="deal" then
  local game,why=B.act(b.game,seat,operation,{nowMs=now,inventory=inventory,seed=seed()})
  if not game then return false,why end
  local queries,logged=claims(b.game,game)
  return commitWith(commit,game,queries,nil,logged)
 end
 return false,"Unknown blackjack action."
end
-- The croupier ---------------------------------------------------------------
-- One server NPC per placed table, on the dealer side (behind the shoe and the
-- chip rack), facing the players: spawned when the table is placed or loaded
-- from the database at start, removed when it is picked up. The framework
-- (server/core/framework.lua) clears every NPC this resource owns when it
-- starts and stops, so a restart or a hot reload never leaves a double.
-- Like the other service NPCs: invulnerable, no combat, perception or voice,
-- native AI off for good, so the body stands still and never walks into a
-- player. (A dealing gesture, played by switching the AI on during each deal,
-- looked wrong in game and was removed.)
local SCALE=.65   -- the casino tables' model scale (Extra.SCALE in client/core/tabletop_extra.lua)
local TICK=250
local RETRY_MS,MAX_ATTEMPTS=10000,6
local dealers={}  -- boardId -> {board, npc, record, attempts, retryAt}
B.dealers=dealers  -- server only; read by the tests
local function npcApi()
 local N=Open77 and Open77.npcs
 if type(N)=="table" and type(N.create)=="function" then return N end
end
-- Where the dealer stands for a table, and the yaw that faces the players.
-- Same transform as Extra.world on the client; NPC yaw 0 faces +Y and turns
-- counter-clockwise, and the players sit at board-local -Y.
function B.dealerStand(b)
 local a=math.rad(tonumber(b.rotation) or 0);local c,s=math.cos(a),math.sin(a)
 local x,y=B.DEALER.x,B.DEALER.y
 local p=b.position
 local yaw=((tonumber(b.rotation) or 0)+180)%360
 return {x=p.x+(x*c-y*s)*SCALE,y=p.y+(x*s+y*c)*SCALE,z=p.z},yaw
end
local function spawnDealer(d)
 local N=npcApi()
 if not N then return false,"npcs_unavailable" end
 local b=d.board
 local at,yaw=B.dealerStand(b)
 local refusals={}
 for _,candidate in ipairs(B.DEALER.candidates) do
  local definition={position=at,yaw=yaw,bucket=b.bucket or 0,persistent=false,despawnWhenUnobserved=false,
   streamingRadius=B.DEALER.streamingRadius,record=candidate.record,
   behavior={combatEnabled=false,perceptionEnabled=false,voiceEnabled=false}}
  if type(N.damage)=="table" then definition.damagePolicy=N.damage.invulnerable or N.damage.immortal end
  if type(N.ai)=="table" then definition.aiMode=N.ai.tasks end
  local ok,id,reason=pcall(N.create,definition)
  if ok and id then
   local stillOk,stillErr=pcall(N.setAIEnabled,id,false)
   if not stillOk or stillErr==false then LightRP.log("blackjack dealer board=%s: setAIEnabled refused: %s",b.id,tostring(stillErr)) end
   d.npc,d.record=id,candidate.record
   LightRP.log("blackjack dealer board=%s: NPC %s spawned as %s at %.2f, %.2f, %.2f yaw %.1f bucket %d (AI off)",
    b.id,tostring(id),candidate.record,at.x,at.y,at.z,yaw,b.bucket or 0)
   return true
  end
  refusals[#refusals+1]=candidate.record.."="..tostring(ok and reason or id)
 end
 return false,table.concat(refusals,", ")
end
local function removeDealer(d)
 local N=npcApi()
 if d.npc and N and type(N.remove)=="function" then
  local ok,why=pcall(N.remove,d.npc)
  LightRP.log("blackjack dealer board=%s: NPC %s removed ok=%s %s",d.board.id,tostring(d.npc),tostring(ok and why~=false),ok and "" or tostring(why))
 end
 d.npc=nil
end
local function placed(b)
 local d=dealers[b.id]
 if d then removeDealer(d) end
 dealers[b.id]={board=b,attempts=0,retryAt=0}
end
local function removed(b)
 local d=dealers[b.id]
 if not d then return end
 dealers[b.id]=nil
 removeDealer(d)
end
function B.dealerTick(now)
 for _,d in pairs(dealers) do
  if not d.npc and d.attempts<MAX_ATTEMPTS and now>=d.retryAt then
   d.attempts=d.attempts+1
   local ok,why=spawnDealer(d)
   -- Clients learn the dealer's id at once (the ALT menu resolves it to its table).
   if ok and LightRP.boardGames and type(LightRP.boardGames.broadcast)=="function" then pcall(LightRP.boardGames.broadcast) end
   if not ok then
    d.retryAt=now+RETRY_MS
    LightRP.log("blackjack dealer board=%s: no NPC (attempt %d/%d): %s",d.board.id,d.attempts,MAX_ATTEMPTS,tostring(why))
   end
  end
 end
end
CreateThread(function()
 Wait(1000) -- let the platform finish its own start-up before the world gets NPCs
 lightrpEvery(TICK, function()
  local ok,why=pcall(B.dealerTick,X.now())
  if not ok then LightRP.log("blackjack dealer tick failed: %s",tostring(why)) end
  
 end, "casino_blackjack:152")
end)
AddEventHandler("onResourceStop",function(name)
 if name~=GetCurrentResourceName() then return end
 for id,d in pairs(dealers) do removeDealer(d);dealers[id]=nil end
end)
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
 placed=placed,
 removed=removed,
 -- The croupier's NPC id: the ALT menu on the dealer opens the table's menu.
 npc=function(b) local d=dealers[b.id];return d and d.npc or nil end,
 settle=function(b,now)
  local game=B.settle(b.game,now,seed())
  if not game then return nil end
  return game,claims(b.game,game) -- queries, then the ledger refresh (board loop)
 end,
})
