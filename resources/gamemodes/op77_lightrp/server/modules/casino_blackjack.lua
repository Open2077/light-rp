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
-- The croupier ---------------------------------------------------------------
-- One server NPC per placed table, on the dealer side (behind the shoe and the
-- chip rack), facing the players: spawned when the table is placed or loaded
-- from the database at start, removed when it is picked up. The framework
-- (server/core/framework.lua) clears every NPC this resource owns when it
-- starts and stops, so a restart or a hot reload never leaves a double.
-- Like the other service NPCs: invulnerable, no combat, perception or voice,
-- native AI off, so the body stands still and never walks into a player.
local SCALE=.65   -- the casino tables' model scale (Extra.SCALE in client/core/tabletop_extra.lua)
local TICK=250
local RETRY_MS,MAX_ATTEMPTS=10000,6
local dealers={}  -- boardId -> {board, npc, record, attempts, retryAt, seen, from, to, active, animUntil}
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
-- The earliest and latest card moments after `after` (a slide start, or the
-- hole card's flip): what the dealer's hands are doing on the server clock.
local function cardMarks(g,after)
 local first,last
 local function see(t)
  t=tonumber(t)
  if t and t>after then first=first and math.min(first,t) or t;last=last and math.max(last,t) or t end
 end
 local function scan(cards)
  if type(cards)~="table" then return end
  for _,card in ipairs(cards) do if type(card)=="table" then see(card.t);see(card.f) end end
 end
 if type(g)~="table" then return end
 scan(type(g.dealer)=="table" and g.dealer.cards)
 if type(g.hands)=="table" then for _,hand in pairs(g.hands) do if type(hand)=="table" then scan(hand.cards) end end end
 return first,last
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
   -- Cards already on the felt (a table reloaded mid-round) get no gesture.
   local _,last=cardMarks(b.game,-math.huge);d.seen=last or 0
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
-- The dealing gesture. A server NPC runs Open77 tasks only while its AI is on
-- (Open77.npcs.setAIEnabled pauses both), so the clip is queued first, the AI
-- is switched on for the length of the deal, then off again and the body put
-- back on its mark. Perception, combat and voice stay off throughout.
local function gesture(d,now)
 local N=npcApi();local clip=B.DEALER.gesture
 if not d.npc or not N or type(clip)~="string" or type(N.tasks)~="table" or type(N.tasks.playAnimation)~="function" then return end
 local first,last=cardMarks(d.board.game,d.seen or 0)
 if last then
  d.seen=last
  d.from=d.active and d.from or math.min(d.from or first,first)
  d.to=math.max(d.to or 0,last+B.SLIDE+B.FLIP)
 end
 if not d.to then return end
 if now>=d.to then
  if d.active then
   d.active=false
   -- Clear first: a task left in the queue would only be paused by the AI
   -- switch and resume at the next deal with its old remaining time.
   if type(N.tasks.clear)=="function" then pcall(N.tasks.clear,d.npc) end
   pcall(N.setAIEnabled,d.npc,false)
   if type(N.setTransform)=="function" then local at,yaw=B.dealerStand(d.board);pcall(N.setTransform,d.npc,{position=at,yaw=yaw}) end
  end
  d.from,d.to,d.animUntil=nil,nil,nil
  return
 end
 if now<d.from then return end
 if not d.animUntil or d.to>d.animUntil+TICK then
  local ok,task,why=pcall(N.tasks.playAnimation,d.npc,clip,{loop=true,timeoutMs=math.floor(d.to-now)})
  if not ok or not task then LightRP.log("blackjack dealer board=%s: gesture refused: %s",d.board.id,tostring(ok and why or task)) end
  d.animUntil=d.to
 end
 if not d.active then
  d.active=true
  local ok,why=pcall(N.setAIEnabled,d.npc,true)
  if not ok or why==false then LightRP.log("blackjack dealer board=%s: gesture setAIEnabled refused: %s",d.board.id,tostring(why)) end
 end
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
  if d.npc then gesture(d,now) end
 end
end
CreateThread(function()
 Wait(1000) -- let the platform finish its own start-up before the world gets NPCs
 while true do
  local ok,why=pcall(B.dealerTick,X.now())
  if not ok then LightRP.log("blackjack dealer tick failed: %s",tostring(why)) end
  Wait(TICK)
 end
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
  return game,claims(b.game,game)
 end,
})
