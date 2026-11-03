-- Pool table handler (see the contract in tabletop_extra.lua). No money: the
-- rules and the shot simulation live in shared/casino_pool.lua; this file
-- validates the request, seeds racks and passes the server clock.
--
-- A shot is simulated synchronously inside the request handler. That is safe
-- on the 176 server's 1 s per-handler quota because the simulation is bounded
-- by construction (P.MAX_EVENTS, P.MAX_SEGMENTS, P.MAX_WORK, P.MAX_TIME):
-- tools/test-casino-pool.py measures the worst case at a few million VM
-- instructions (milliseconds), and logs here report each shot's cost.
local X=LightRP.tabletopExtra
local P=LightRpPool
local function seed() return math.random(1,2147483646) end
local function number(v) v=tonumber(v);if v and v==v and math.abs(v)<1e9 then return v end end
local function act(player,b,seat,operation,data,commit)
 local now=X.now()
 if operation=="shoot" then
  local game,why=P.shoot(b.game,seat,{yaw=number(data.yaw),power=number(data.power),nowMs=now})
  if not game then return false,why end
  local shot=game.shot
  local bytes=0;for i=1,16 do bytes=bytes+#shot.segs[i] end
  LightRP.log("pool shot board=%s seat=%s yaw=%.2f power=%.3f dur=%dms segments=%d bytes=%d foul=%s potted=%s",
   b.id,seat,shot.yaw,shot.power,shot.dur,math.floor(bytes/P.REC),bytes,tostring(game.last and game.last.foul),
   tostring(game.last and game.last.potted))
  return commit(game)
 elseif operation=="place" then
  local game,why=P.place(b.game,seat,{x=number(data.x),y=number(data.y),nowMs=now})
  if not game then return false,why end
  return commit(game)
 elseif operation=="rerack" then
  local game,why=P.rerack(b.game,seat,{nowMs=now,seed=seed()})
  if not game then return false,why end
  return commit(game)
 end
 return false,"Unknown pool action."
end
X.register("pool",{
 new=function(mode) return P.new(mode,seed()) end,
 act=act,
 view=function(b) return P.view(b.game) end,
 -- Practice is the owner's solo table; 1v1 seats two players. No 2v2.
 modes={duel=true,solo=true},
})
