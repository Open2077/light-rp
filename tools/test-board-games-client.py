#!/usr/bin/env python3
"""Exercise client lifecycle and pointer protocol using mocked documented natives."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
events, handlers, pageHandlers, requests, batches, threads, keys = {}, {}, {}, {}, {}, {}, {}
played,soundHandles={},{}
nativeProps,nextNativeId={},0
createdProps,removedProps,movedProps=0,0,0
clock=0; frozen=false; camera=nil; stoppedCamera=false; focus=false
LightRpEvents={page={notice='notice',ready='ready',dialogClose='dialogClose'}}
LightRpUi={characterReady=true,ready=true,dialogs={},page={}}
function LightRpUi.page:setFocus(k,c) focus=c;return true end
function LightRpUi.send(name,p)
 if name=="lightrp:boardGames:view" then view=p
 elseif name=='dialogClose' then closeRequest=p
 elseif name=='notice' then lastNotice=p.body end
end
logs,diagnostics={},{}
function LightRpUi.log(...)
 local text=string.format(...)
 logs[#logs+1]=text
 if not text:find('board games stop:',1,true) then error(text) end
end
function LightRpUi.setMenuOpen(v) LightRpUi.menuOpen=v end
function RegisterNetEvent(n,f) events[n]=f end
function AddEventHandler(n,f) handlers[n]=f end
function TriggerServerEvent(n,p)
 if p.action=='diagnostic' then diagnostics[#diagnostics+1]=p else requests[#requests+1]=p end
 return true
end
function TriggerEvent(name,owner,value)
 assert(name=='open-voice:setHudBlocked' and owner=='op77_lightrp:boardGames')
 voiceHudBlocked=value
end
function CreateThread(f) threads[#threads+1]=coroutine.create(f) end
function Wait() coroutine.yield() end
function GetGameTimer() return clock end
function GetCurrentResourceName() return 'test' end
LightRpInteract={points={}}
function LightRpInteract.setLocal(id,p,callback) LightRpInteract.points[id]=p and {p=p,callback=callback} or nil end
LightRpControlClaims={set=function() return true end}
exportCallbacks={}
exports=setmetatable({},{__call=function(_,name,fn)exportCallbacks[name]=fn end})
function GetInvokingResource()return invokingResource end
local char={alive=true,attached=true,position={x=0,y=0,z=.5}}
Open77={network={status=function()return {playerId=7}end},character={},input={},camera={},debugDraw={},audio={},props={},hud={},exports={}}
contextTargetingEnabled=true;contextCloseCalls=0
function Open77.exports.call(resource,name,definition)
 assert(resource=='open77_contextmenu')
 local result
 if name=='registerProps' then
  assert(definition.id=='boardGames.pickup' and definition.networked==false and definition.distance==2)
  targetDefinition=definition;result='board-pickup-token'
 elseif name=='setTargetingEnabled' then contextTargetingEnabled=definition;result=true
 elseif name=='close' then contextCloseCalls=contextCloseCalls+1;result=true
 else error('unexpected context export '..tostring(name))end
 return {await=function()
  if delayContext and name=='setTargetingEnabled' then coroutine.yield()end
  return result
 end}
end
function Open77.character.state() return char end
function Open77.character.setFrozen(v) frozen=v;return true end
function Open77.input.isDown(k) return keys[k]==true end
function Open77.input.isCaptured() return focus end
function Open77.input.cursor()return {x=.5,y=.5,inBounds=true}end
function Open77.camera.cameras()
 if registryNil then return nil end
 if registryOverride then return registryOverride end
 return {held=camera~=nil,activeCamera=camera}
end
function Open77.camera.create(spec)
 if spec.lookAt then assert(spec.position.y<spec.lookAt.y or spec.position.x~=spec.lookAt.x)
 else assert(spec.rotation.pitch < -85)end
 cameraSpec=spec;return cameraReturnId or 'camera'
end
function Open77.camera.activate(id)camera=id;return true end
function Open77.camera.setTransform(id,p)
 assert(id==camera);cameraSpec.position=p.position;cameraSpec.rotation=p.rotation
 if p.rotation then cameraSpec.lookAt=nil end
 return true
end
function Open77.camera.lookAt(id,p)assert(id==camera);cameraSpec.lookAt=p;return true end
ordinaryHudClaim=true
function Open77.hud.setCinematic(value,height)
 if value then assert(height==.01)end
 cinematic=value;return true
end
function Open77.camera.destroy(id) assert(id=='camera' or id==cameraReturnId);camera=nil;stoppedCamera=true;return true end
function Open77.camera.screenRay(x,y)
 if forcedRay then return forcedRay end
 if cameraSpec and cameraSpec.lookAt and camera then
  local p,t=cameraSpec.position,cameraSpec.lookAt
  local length=math.sqrt((t.x-p.x)^2+(t.y-p.y)^2)
  local nx,ny=(t.x-p.x)/length,(t.y-p.y)/length
  local offset=(x-.5)*.98*.65
  return {origin={x=t.x-nx*2+ny*offset,y=t.y-ny*2-nx*offset,z=t.z-.47*.65+((1-y)*.84+.04)*.65},direction={x=nx,y=ny,z=0}}
 end
 return {origin={x=(x-.5)*.65,y=(y-.5)*.65,z=2},direction={x=0,y=0,z=-1}}
end
function Open77.camera.screenRaycast()return {hit=true,position={x=0,y=0,z=0}}end
function Open77.debugDraw.set(tag,geo)
 assert(#geo.triangles==0,'board and pieces must be native props, never debug triangles')
 assert(#geo.lines<=512)
 local vertices=(#geo.triangles*3+#geo.lines*2)
 for name,b in pairs(batches) do if name~=tag then vertices=vertices+#b.triangles*3+#b.lines*2 end end
 assert(vertices<=8192,'global geometry quota exceeded')
 batches[tag]=geo;return true
end
function Open77.debugDraw.clear(tag)batches[tag]=nil;return true end
function Open77.props.create(options)
 nativeCreatesInResume=(nativeCreatesInResume or 0)+1
 if mockCreateFailure then return nil,'invalid_model' end
 assert(options.model:find('open77\\assets\\op77_lightrp\\board_games\\',1,true)==1)
 assert(options.model:sub(-4)=='.ent' and options.kind=='prop')
 assert(options.collision==false and options.physics=='none' and options.scale==.65)
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local name=options.model:match('([^\\]+)%.ent$')
 local row={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=not mockLoading,failed=false,backend='raw_entity'}
 if name:match('_board$')then row.group=id
 else
  local best=math.huge
  local kind=name:match('^([^_]+)_')
  for key,p in pairs(nativeProps)do if p.name==kind..'_board' then
   local d=(p.position.x-row.position.x)^2+(p.position.y-row.position.y)^2+(p.position.z-row.position.z)^2
   if d<best then best=d;row.group=key end
  end end
 end
 nativeProps[id]=row;createdProps=createdProps+1;return id
end
function Open77.props.setTransform(id,transform)
 local row=nativeProps[id];assert(row,'transforming removed native prop')
 row.position={x=transform.position.x,y=transform.position.y,z=transform.position.z}
 row.yaw=transform.yaw or row.yaw;movedProps=movedProps+1;return true
end
function Open77.props.remove(id)
 assert(nativeProps[id],'removing unknown native prop')
 nativeProps[id]=nil;removedProps=removedProps+1;return true
end
function Open77.props.list()
 local result={}
 for _,row in pairs(nativeProps)do
  row.rendered=not mockLoading
  result[#result+1]=row
 end
 return result
end
function boardProp(x,kind)
 for id,p in pairs(nativeProps)do if p.name==(kind or 'chess')..'_board' and math.abs(p.position.x-x)<.001 then return id end end
end
function propsForBoard(x,kind)
 local group=boardProp(x,kind);local count=0
 for _,p in pairs(nativeProps)do if p.group==group then count=count+1 end end
 return count
end
function Open77.audio.play3D(asset,position,options)
 assert(asset:find('assets/audio/board-games/',1,true)==1 and options.maxDistance==14 and options.loop==false)
 played[#played+1]=asset;local id=#played;soundHandles[id]=true;return id
end
function Open77.audio.destroy(id)assert(soundHandles[id]);soundHandles[id]=nil;return true end
peakInstructions=0
BOARD_BUDGET=tonumber(os.getenv('BOARD_BUDGET')) or 8000
function step()
 clock=clock+50
 -- Two resumes per step: the main loop splits each tick into an input resume
 -- and a render resume. The budget is still checked per resume.
 for _,co in ipairs(threads) do for _=1,2 do if coroutine.status(co)~='dead' then
  local count=0
  nativeCreatesInResume=0
  -- Like the 176 client: the hook raises inside the coroutine at the budget.
  debug.sethook(co,function()
   count=count+100
   if count>=BOARD_BUDGET then debug.sethook();error('Open77 script execution budget exceeded '..debug.traceback('',2),0) end
  end,'',100)
  local ok,why=coroutine.resume(co)
  debug.sethook(co)
  peakInstructions=math.max(peakInstructions,count)
  assert(nativeCreatesInResume<=1,'native spawns must be staggered across resumes')
  assert(ok,why)
 end end end
end
function waitUntil(predicate,label)
 for i=1,600 do if predicate() then return end;step()end
 error('timed out waiting for '..label)
end
function nativeCount(id)
 return propsForBoard(id==2 and 2 or 0,id==4 and 'connect4' or 'chess')
end
function edge(key) keys[key]=true;step();keys[key]=false;step()end
function last() return requests[#requests] end
page={on=function(self,n,f)pageHandlers[n]=f end}
''')
for name in ['shared/board_game_models.lua', 'shared/board_games_rules.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text())
lua.execute(r'''
LightRpBoardGameModels={board=function()error('debug models must not be used')end,piece=function()error('debug models must not be used')end}
local C=LightRpBoardGamesClient
C.bind(page);C.start();assert(#requests==0);step();assert(last().action=='sync')
-- A delayed target-disable export cannot win after a rapid game exit.
delayContext=true
events['lightrp:boardGames:place']({kind='chess'});step();step()
assert(contextTargetingEnabled==false)
pageHandlers['lightrp:boardGames:leave']({});step();step();step()
delayContext=false
assert(not C.isActive() and contextTargetingEnabled==true and not focus,'late target claims must restore the final state')
-- Item use must hand off inventory focus before opening placement.
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
LightRpUi.menuOpen=true
events['lightrp:boardGames:place']({kind='chess'})
assert(closeRequest and closeRequest.kind=='inventory' and not LightRpUi.menuOpen)
assert(not C.isActive() and focus,'inventory keeps focus until its real cleanup')
step();assert(not C.isActive())
-- dialogState(false) alone is not sufficient while the focus cleanup is pending.
LightRpUi.dialogs.inventory=false;step();assert(not C.isActive())
LightRpUi.promptActive=false;focus=false;step();assert(C.isActive() and focus)
edge('BACKSPACE');assert(not C.isActive() and not focus)
-- The inverse callback order also waits for dialogState(false).
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
events['lightrp:boardGames:place']({kind='checkers'})
LightRpUi.promptActive=false;focus=false;step();assert(not C.isActive())
LightRpUi.dialogs.inventory=false;step();assert(C.isActive() and focus)
edge('BACKSPACE')
-- Failed handoff times out without stealing the inventory's focus.
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
events['lightrp:boardGames:place']({kind='chess'});clock=clock+2600;step()
assert(not C.isActive() and focus and lastNotice:find('inventory did not close',1,true))
LightRpUi.dialogs.inventory=false;LightRpUi.promptActive=false;focus=false
-- Support and other dialogs receive an explicit refusal, retaining their focus.
LightRpUi.dialogs.support=true;LightRpUi.supportMode='menu';focus=true
events['lightrp:boardGames:place']({kind='chess'});step()
assert(not C.isActive() and focus and lastNotice:find('Close the current dialog',1,true))
LightRpUi.dialogs.support=false;LightRpUi.supportMode=nil;focus=false
-- A first-use Connect Four ghost builds the real lazy grid within one task budget.
events['lightrp:boardGames:place']({kind='connect4'});step();assert(C.isActive())
edge('BACKSPACE')
-- A real native preview must load before placement can be confirmed.
mockLoading=true;events['lightrp:boardGames:place']({kind='chess'})
assert(C.isActive() and boardProp(0,'chess'))
local pendingCount=#requests;edge('E')
assert(C.isActive() and #requests==pendingCount and lastNotice:find('still loading',1,true))
mockLoading=false;pageHandlers['lightrp:boardGames:confirm']({});assert(last().action=='place' and not C.isActive())
local confirmed=#requests;pageHandlers['lightrp:boardGames:confirm']({});assert(#requests==confirmed,'confirm cannot place twice')
-- A missing asset or a renderer placeholder never becomes a successful board.
events['lightrp:boardGames:place']({kind='checkers'})
nativeProps[boardProp(0,'checkers')].backend='marker_fallback'
pendingCount=#requests;step();assert(not C.isActive() and #requests==pendingCount)
assert(lastNotice:find('rejoin through the launcher',1,true))
mockCreateFailure=true;events['lightrp:boardGames:place']({kind='chess'})
assert(not C.isActive() and not focus and lastNotice:find('invalid_model',1,true))
mockCreateFailure=false
mockLoading=true;events['lightrp:boardGames:place']({kind='connect4'})
clock=clock+3100;step();assert(C.isActive(),'a slow model keeps loading within the grace period')
clock=clock+12000;step();assert(not C.isActive() and next(nativeProps)==nil)
mockLoading=false
-- Placement uses the precise WebUI pointer; held pointer works with physical mouse up.
events['lightrp:boardGames:place']({kind='chess'});assert(C.isActive() and focus)
pageHandlers['lightrp:boardGames:pointer']({x=.7,y=.6,pressed=true});step()
edge('E');assert(last().action=='place' and last().kind=='chess')
assert(math.abs(last().position.x-.2*.65)<.001);assert(not C.isActive() and not focus)
-- Existing board creates proximity interaction; only server membership opens camera.
local board={id=1,owned=true,position={x=0,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={board}});step()
assert(not C.isActive());LightRpInteract.points['boardGames.1'].callback();assert(last().action=='join')
board.players={white=7,black=9};events['lightrp:boardGames:state']({boards={board}});step()
assert(C.isActive() and camera and frozen and focus and cinematic and voiceHudBlocked)
-- Press at e2, release at e4: one authoritative move request with snapshot revision.
local pointer=pageHandlers['lightrp:boardGames:pointer']
pointer({x=4.5/8,y=6.5/8,pressed=true});step()
pointer({x=4.5/8,y=4.5/8,released=true});step()
assert(last().action=='move' and last().fromRow==7 and last().fromCol==5 and last().toRow==5 and last().revision==1)
-- A later snapshot animates the same piece rather than moving instantly.
local pawnHandle
local function pawnY()
 if pawnHandle then return nativeProps[pawnHandle] and nativeProps[pawnHandle].position.y end
 for id,p in pairs(nativeProps)do
  if p.name=='chess_white_pawn' and math.abs(p.position.x-.0625*.65)<.001 and p.position.y>0 and p.position.y<.4*.65 then
   pawnHandle=id;return p.position.y
  end
 end
end
waitUntil(function()return nativeCount(1)==33 end,'complete initial chess mesh')
-- Left press and an in-flight camera snapshot must retain the playing session.
local leftCount=#requests
registryNil=true;pointer({x=4.5/8,y=6.5/8,pressed=true});step()
assert(C.isActive() and camera and #requests==leftCount)
pointer({blocked=true});step();registryNil=false
assert(C.isActive() and cinematic and voiceHudBlocked)
local before=pawnY();assert(before)
local oldCreates,oldRemoves=createdProps,removedProps
local heldRequestCount=#requests
pointer({x=4.5/8,y=6.5/8,pressed=true});step()
pointer({x=4.5/8,y=4.5/8});step();step()
assert(math.abs(nativeProps[pawnHandle].position.y-.0625*.65)<.001,'held piece must follow the cursor immediately')
assert(#requests==heldRequestCount,'dragging alone must not send a move')
pointer({x=4.5/8,y=4.5/8,released=true});step();assert(#requests==heldRequestCount+1)
board.game=assert(LightRPBoardRules.move(board.game,7,5,5,5));board.revision=2
events['lightrp:boardGames:state']({boards={board}});step()
waitUntil(function()return pawnY() and pawnY()<before end,'pawn animation')
local after=pawnY();assert(after and after<before and after>.04,'piece interpolation expected')
assert(nativeProps[pawnHandle] and createdProps==oldCreates and removedProps==oldRemoves,'normal moves must retain native prop handles')
-- Captured pieces retain their cached mesh and slide into the capturing camp.
board.game=assert(LightRPBoardRules.move(board.game,2,4,4,4));board.revision=3
events['lightrp:boardGames:state']({boards={board}})
board.game=assert(LightRPBoardRules.move(board.game,5,5,4,4));board.revision=4
events['lightrp:boardGames:state']({boards={board}})
local function capturedInTray()
 for _,p in pairs(nativeProps)do
  if p.name=='chess_black_pawn' and p.position.y>.57*.65 and p.position.x<-.4*.65 then return true end
 end
end
waitUntil(capturedInTray,'captured piece tray animation')
-- A promoted mesh changes shape: repack cached faces without a synchronous rebuild.
board.game.board[4][4].kind='queen';board.revision=5
events['lightrp:boardGames:state']({boards={board}})
waitUntil(function()
 for _,p in pairs(nativeProps)do if p.name=='chess_white_queen' and p.position.y<.2 then return true end end
end,'promoted native prop')
assert(not nativeProps[pawnHandle],'promotion replaces the pawn handle')
edge('BACKSPACE');assert(last().action=='leave' and not camera and not frozen and not focus and stoppedCamera and cinematic==false and ordinaryHudClaim and voiceHudBlocked==false)
-- Membership removal snapshot prevents reopening; nearby owner can retrieve via Alt.
board.players={};events['lightrp:boardGames:state']({boards={board}})
local altCount=#requests;edge('ALT');assert(#requests==altCount,'ALT alone must never pick up a board')
assert(targetDefinition and targetDefinition.canInteract=='boardGamesCanPickup' and targetDefinition.onSelect=='boardGamesPickup')
local pickupContext={target={kind='prop',propId=boardProp(0),networked=false}}
invokingResource='forged';assert(exportCallbacks.boardGamesCanPickup(pickupContext)==false)
invokingResource='open77_contextmenu'
assert(exportCallbacks.boardGamesCanPickup(pickupContext)==true)
local pieceContext={target={kind='prop',propId=pawnHandle,networked=false}}
assert(exportCallbacks.boardGamesCanPickup(pieceContext)==false,'targeting a piece cannot retrieve its board')
board.owned=false;assert(exportCallbacks.boardGamesCanPickup(pickupContext)==false);board.owned=true
Open77.character.state().position.x=3;assert(exportCallbacks.boardGamesCanPickup(pickupContext)==false)
Open77.character.state().position.x=0
assert(exportCallbacks.boardGamesPickup(pickupContext)==true and last().action=='pickup' and last().boardId==1)
invokingResource=nil
-- Switching nearest full boards must release old tags BEFORE allocating replacements.
local second={id=2,owned=false,position={x=2,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={board,second}});step()
Open77.character.state().position.x=2;step()
waitUntil(function()return nativeCount(2)==33 end,'new nearest chess cache')
local hasSecond=boardProp(2)~=nil
assert(hasSecond,'new nearest board should be rendered')
Open77.character.state().position.x=60;step();assert(next(nativeProps)==nil,'distant native props must stream out')
Open77.character.state().position.x=0;step()
waitUntil(function()return nativeCount(1)==33 and nativeCount(2)==33 end,'nearby native boards stream back in')
-- Lobby mode protocol is owner-only and locks once the game has started.
Open77.character.state().position.x=0
cameraReturnId=77
local solo={id=3,owned=true,position={x=0,y=0,z=0},rotation=0,players={white=7},revision=1,
 kind='chess',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={solo}});step()
assert(view.mode=='solo' and view.owned and view.ready and view.isActor and view.playerCount==1)
assert(view.cameraView=='top' and #view.cameraViews==4)
clock=clock+1300;registryOverride={held=true,activeCamera='77'};step()
assert(C.isActive(),'numeric and string camera IDs represent the same camera')
registryOverride={held=false};for i=1,20 do step()end
assert(C.isActive(),'unknown camera IDs must not close the game')
registryOverride={held=true,activeCamera='other-owner'};step();for i=1,6 do step()end
assert(C.isActive(),'a transient foreign camera must respect the ownership grace')
for i=1,12 do step()end
assert(not C.isActive() and diagnostics[#diagnostics].reason=='camera_switched')
-- A stale snapshot right after a leave must not reopen the view; a later one may.
registryOverride=nil;events['lightrp:boardGames:state']({boards={solo}});step();assert(not C.isActive(),'stale seat after a leave')
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step();assert(C.isActive())
for _,name in ipairs({'white','black','orbit','top'})do
 pageHandlers['lightrp:boardGames:camera']({view=name});assert(view.cameraView==name)
end
-- A side-view click on a queen's head selects its actual square, and does
-- not accidentally submit a move to the square behind it on mouse-up.
pageHandlers['lightrp:boardGames:camera']({view='white'})
local headRequests=#requests
forcedRay={origin={x=-.0625*.65,y=.4375*.65+.9,z=.065+.35},direction={x=0,y=-.9,z=-.35}}
pointer({x=.5,y=.5,pressed=true});step()
assert(view.selected and view.selected.row==8 and view.selected.col==4,'tall-piece picking must use the native piece bounds')
pointer({x=.5,y=.5,released=true});step();assert(#requests==headRequests,'clicking a head must not move the piece')
forcedRay=nil
pageHandlers['lightrp:boardGames:camera']({view='top'})
local buttonCount=#requests
pointer({blocked=true});keys.mouse1=true;step();keys.mouse1=false;step();assert(#requests==buttonCount,'UI clicks cannot move pieces')
-- Orbit owns only right-drag; left-drag remains a game action.
pageHandlers['lightrp:boardGames:camera']({view='orbit'})
local oldCameraX=cameraSpec.position.x
pointer({x=.5,y=.5,rightPressed=true});step();pointer({x=.6,y=.5});step();pointer({x=.6,y=.5,rightReleased=true});step()
assert(cameraSpec.position.x~=oldCameraX and #requests==buttonCount)
pageHandlers['lightrp:boardGames:camera']({view='top'})
-- Click/click and fast press/release queues both preserve the source square.
pointer({x=4.5/8,y=6.5/8,pressed=true});pointer({x=4.5/8,y=6.5/8,released=true});step();assert(#requests==buttonCount)
pointer({x=4.5/8,y=4.5/8,pressed=true});step();assert(#requests==buttonCount)
pointer({x=4.5/8,y=4.5/8,released=true});step();assert(#requests==buttonCount+1)
pointer({x=4.5/8,y=6.5/8,pressed=true});pointer({x=4.5/8,y=4.5/8,released=true});step()
assert(last().fromRow==7 and last().fromCol==5 and last().toRow==5 and last().toCol==5)

pageHandlers['lightrp:boardGames:mode']({mode='teams'});assert(last().action=='mode' and last().mode=='teams')
pointer({x=4.5/8,y=6.5/8,pressed=true});step();pointer({x=4.5/8,y=4.5/8,released=true});step()
assert(last().action=='move','solo human can play without a black seat')
solo.game.ply=1
local count=#requests;pageHandlers['lightrp:boardGames:mode']({mode='duel'});assert(#requests==count)
pageHandlers['lightrp:boardGames:reset']({});assert(last().action=='reset' and last().boardId==3)
solo.owned=false;count=#requests;pageHandlers['lightrp:boardGames:reset']({});assert(#requests==count)
solo.owned=true;solo.game.ply=0;solo.game.chain={row=4,col=3}
count=#requests;pageHandlers['lightrp:boardGames:mode']({mode='duel'});assert(#requests==count)
solo.game.chain=nil
-- Teammates share a colour, but only the server-designated actor may move.
solo.mode='teams';solo.game.ply=0;solo.players={white=8,black=9,white2=7,black2=10};solo.actor=8
solo.revision=2;events['lightrp:boardGames:state']({boards={solo}});step()
assert(view.side=='white' and view.playerCount==4 and not view.isActor)
count=#requests;pointer({x=4.5/8,y=6.5/8,pressed=true});step();pointer({x=4.5/8,y=4.5/8,released=true});step();assert(#requests==count)
solo.actor=7;events['lightrp:boardGames:state']({boards={solo}});step()
pointer({x=4.5/8,y=6.5/8,pressed=true});step();pointer({x=4.5/8,y=4.5/8,released=true});step();assert(last().action=='move')
edge('BACKSPACE')
-- Connect Four uses the vertical board plane, including rotated placements.
local four={id=4,owned=true,position={x=0,y=0,z=0},rotation=90,players={white=7},revision=1,
 kind='connect4',moveSequence=0,lastSound='connect4-drop',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('connect4')}
events['lightrp:boardGames:state']({boards={four}});step()
assert(C.isActive() and cameraSpec.lookAt and view.kind=='connect4')
local beforeDrop=#requests
pointer({x=3.5/7,y=.5,pressed=true});step();assert(#requests==beforeDrop,'disc drop waits for mouse release')
pointer({x=3.5/7,y=.5,released=true});step()
assert(last().action=='move' and last().boardId==4 and last().toCol==4)
count=#requests
-- An AI turn accepts no extra human clicks.
four.actor=0;events['lightrp:boardGames:state']({boards={four}});step()
pointer({x=2.5/7,y=.5,pressed=true});step();pointer({x=2.5/7,y=.5,released=true});step();assert(#requests==count)
-- A newly replicated disc starts above the grid and descends over subsequent frames.
assert(#played==0,'initial sync and lobby updates should be silent')
four.game=assert(LightRPBoardRules.move(four.game,0,0,3,4));four.revision=2;four.moveSequence=1
events['lightrp:boardGames:state']({boards={four}});step()
local function tokenZ()
 local top=0
 for _,p in pairs(nativeProps)do if p.name=='connect4_white_disc' then top=math.max(top,p.position.z)end end
 return top
end
waitUntil(function()return tokenZ()>.1 end,'new disc mesh')
local first=tokenZ();waitUntil(function()return tokenZ()<first end,'disc animation')
local nextZ=tokenZ();assert(first>nextZ and nextZ>.1,'disc must drop smoothly')
-- A fully populated Connect Four renders every real mesh within the native task quota.
for row=1,6 do for col=1,7 do
 four.game.board[row][col]={id=(row-1)*7+col,kind='disc',side=(row+col)%2==0 and 'white' or 'black'}
end end
four.revision=3;events['lightrp:boardGames:state']({boards={four}});step()
waitUntil(function()return nativeCount(4)==43 end,'complete Connect Four mesh')
-- Audio plays once per actual move sequence, within hearing range only.
assert(#played==1 and played[1]:find('connect4%-drop.wav'))
events['lightrp:boardGames:state']({boards={four}});assert(#played==1)
Open77.character.state().position.x=50;four.moveSequence=2
events['lightrp:boardGames:state']({boards={four}});assert(#played==1)
Open77.character.state().position.x=0;events['lightrp:boardGames:state']({boards={four}});assert(#played==1)
four.moveSequence=3;four.lastSound='game-win';events['lightrp:boardGames:state']({boards={four}})
assert(#played==2 and played[2]:find('game%-win.wav'))
clock=clock+3100;step();assert(next(soundHandles)==nil,'one-shot sound handles must expire')
four.moveSequence=4;four.lastSound='connect4-drop';events['lightrp:boardGames:state']({boards={four}})
assert(next(soundHandles)~=nil)
-- Existing games reject failed native projections instead of leaving placeholder pieces.
local failedHandle
for id,p in pairs(nativeProps)do if p.name=='connect4_white_disc' then failedHandle=id;break end end
assert(failedHandle);nativeProps[failedHandle].backend='placeholder_cube'
waitUntil(function()return not C.isActive() and not camera and not frozen and nativeCount(4)==0 end,'placeholder projection rejected')
assert(lastNotice:find('rejoin through the launcher',1,true))
events['lightrp:boardGames:state']({boards={four}})
assert(not C.isActive() and last().action=='leave','failed board projections must not reopen a camera')
-- Resource cleanup removes every surface and interaction, releasing input/camera.
handlers.onClientResourceStop('test');assert(next(batches)==nil and next(LightRpInteract.points)==nil and next(soundHandles)==nil and next(nativeProps)==nil)
for i=1,20 do step()end
assert(next(batches)==nil and next(nativeProps)==nil,'cancelled renderer jobs must not resurrect native props')
assert(voiceHudBlocked==false,'resource stop restores the voice HUD claim')
print('board games client inventory handoff, lifecycle, modes, teams, Connect Four drop, spatial audio, native props, streaming and budgets, failures and cleanup: OK; peak Lua instructions per tick: '..peakInstructions)
''')

# Run the real interaction guard independently: the ordinary E prompt must not
# compete with board controls while either playing or placing a board.
interact = LuaRuntime(unpack_returned_tuples=True)
interact.execute(r'''
LightRpEvents={net={interactions='interactions'},page={interact='interact'}}
LightRpConfig={};Open77={};threads={};playing=true;interactions=0
LightRpBoardGamesClient={isActive=function()return playing end}
LightRpUi={send=function(name,p)lastPrompt=p end,log=function()end}
function RegisterNetEvent()end
function CreateThread(fn)threads[#threads+1]=coroutine.create(fn)end
function Wait()coroutine.yield()end
function TriggerServerEvent()interactions=interactions+1 end
''')
interact.execute((ROOT/'resources/gamemodes/op77_lightrp/client/core/interact.lua').read_text())
interact.execute(r'''
local I=LightRpInteract
I.near={position={x=0,y=0,z=0},callback=function()interactions=interactions+1 end}
assert(I.press()==false and interactions==0)
local ok,why=coroutine.resume(threads[1]);assert(ok,why)
ok,why=coroutine.resume(threads[1]);assert(ok,why)
assert(I.near==nil and next(lastPrompt)==nil,'board mode must clear the ordinary E prompt')
playing=false;I.near={callback=function()interactions=interactions+1 end}
assert(I.press()==true and interactions==1,'ordinary interactions return after leaving')
''')
print('native interaction prompt and E suppression/restoration: OK')
