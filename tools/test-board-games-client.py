#!/usr/bin/env python3
"""Exercise the board client (free mode only: crosshair + left click, no panel,
no HUD, no scripted camera) using mocked documented natives."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
events, handlers, pageHandlers, requests, batches, threads, keys = {}, {}, {}, {}, {}, {}, {}
played,soundHandles={},{}
nativeProps,nextNativeId={},0
createdProps,removedProps,movedProps=0,0,0
clock=0; focus=false; placeAt={x=0,y=0,z=0}
LightRpEvents={page={notice='notice',ready='ready',dialogClose='dialogClose'}}
LightRpUi={characterReady=true,ready=true,dialogs={},page={}}
function LightRpUi.page:setFocus(k,c) focus=c;return true end
notices={}
function LightRpUi.send(name,p)
 assert(not name:find('boardGames',1,true),'no table page payload: '..name)
 if name=='dialogClose' then closeRequest=p
 elseif name=='notice' then lastNotice=p.body;notices[#notices+1]=p.body end
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
function TriggerEvent(name) error('unexpected local event '..tostring(name)) end
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
-- The board client never talks to the context menu itself: the table menu
-- (client/core/table_menu.lua, tools/test-table-menu.py) owns that.
function Open77.exports.call(resource,name) error('unexpected export '..tostring(resource)..'.'..tostring(name)) end
function Open77.character.state() return char end
function Open77.character.setFrozen() error('free mode never freezes the character') end
function Open77.input.isDown(k) return keys[k]==true end
function Open77.input.isCaptured() return captured==true or focus end
function Open77.input.cursor() error('free mode never reads the cursor') end
function Open77.camera.create() error('free mode never creates a camera') end
function Open77.hud.setCinematic() error('free mode never hides the HUD') end
function Open77.camera.screenRay(x,y)
 assert(x==.5 and y==.5,'the crosshair (screen centre) is the only pointer')
 if forcedRay then return forcedRay end
 return {origin={x=0,y=0,z=2},direction={x=0,y=0,z=-1}}
end
function Open77.camera.screenRaycast(x,y)
 assert(x==.5 and y==.5)
 return {hit=true,position={x=placeAt.x,y=placeAt.y,z=placeAt.z}}
end
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
 -- Table bases get a solid, mesh-less collider at scale 1; everything else stays non-solid.
 if options.model:find('_collider.ent',1,true) then assert(options.collision==true and options.physics=='static' and options.scale==1)
 else assert(options.collision==false and options.physics=='none' and options.scale==.65) end
 nextNativeId=nextNativeId+1;local id=tostring(nextNativeId)
 local name=options.model:match('([^\\]+)%.ent$')
 local row={id=id,name=name,model=options.model,position={x=options.position.x,y=options.position.y,z=options.position.z},
  yaw=options.yaw,rendered=not mockLoading,failed=false,backend='raw_entity'}
 if name:match('_board$')then row.group=id
 elseif name:match('_collider$')then row.collider=true -- solid volume, not one of the board's pieces
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
 transformsInStep[id]=(transformsInStep[id] or 0)+1
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
transformsInStep={}
BOARD_BUDGET=tonumber(os.getenv('BOARD_BUDGET')) or 8000
function step()
 clock=clock+50
 transformsInStep={}
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
-- Free mode: the crosshair ray (screen centre) straight down on a square.
function aimAt(col,row,n)
 n=n or 8
 forcedRay={origin={x=((col-.5)/n-.5)*.65,y=((row-.5)/n-.5)*.65,z=2},direction={x=0,y=0,z=-1}}
end
function click() keys.mouse1=true;step();keys.mouse1=false;step() end
-- Crosshair move: aim at the piece and click, aim at the destination and click.
function play(fc,fr,tc,tr,n) aimAt(fc,fr,n);click();aimAt(tc,tr,n);click() end
function outlines() local b=batches['boardGames:preview'];return b and #b.lines or 0 end
function last() return requests[#requests] end
page={on=function(self,n,f)pageHandlers[n]=f end}
''')
for name in ['shared/board_game_models.lua', 'shared/board_games_rules.lua', 'client/core/board_games.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text())
lua.execute(r'''
LightRpBoardGameModels={board=function()error('debug models must not be used')end,piece=function()error('debug models must not be used')end}
local C=LightRpBoardGamesClient
C.bind(page);assert(pageHandlers.ready and not pageHandlers['lightrp:boardGames:pointer'],'only the ready sync is bound')
C.start();assert(#requests==0);step();assert(last().action=='sync')
-- Item use must hand off inventory focus before opening placement.
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
LightRpUi.menuOpen=true
events['lightrp:boardGames:place']({kind='chess'})
assert(closeRequest and closeRequest.kind=='inventory' and not LightRpUi.menuOpen)
assert(not C.isActive() and focus,'inventory keeps focus until its real cleanup')
step();assert(not C.isActive())
-- dialogState(false) alone is not sufficient while the focus cleanup is pending.
LightRpUi.dialogs.inventory=false;step();assert(not C.isActive())
LightRpUi.promptActive=false;focus=false;step();assert(C.isActive() and not focus,'placement is free mode: no cursor')
assert(lastNotice:find('E: place',1,true),'placement keys are told in a notice')
edge('BACKSPACE');assert(not C.isActive() and not focus)
-- The inverse callback order also waits for dialogState(false).
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
events['lightrp:boardGames:place']({kind='checkers'})
LightRpUi.promptActive=false;focus=false;step();assert(not C.isActive())
LightRpUi.dialogs.inventory=false;step();assert(C.isActive())
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
mockLoading=false;edge('E');assert(last().action=='place' and not C.isActive())
local confirmed=#requests;edge('E');assert(#requests==confirmed,'E cannot place twice')
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
-- Free-mode placement: the preview follows the crosshair hit, the arrows turn
-- it, PgUp raises it, E places it there.
events['lightrp:boardGames:place']({kind='chess'});assert(C.isActive() and not focus)
placeAt={x=.13,y=-.2,z=.4};step()
local ghost=nativeProps[boardProp(.13,'chess')];assert(ghost and math.abs(ghost.position.z-.415)<1e-6,'the ghost stands on the aimed surface')
keys.RIGHT=true;step();step();keys.RIGHT=false
keys.PAGEUP=true;step();keys.PAGEUP=false
captured=true;edge('E');assert(C.isActive(),'typing never places');captured=false
edge('E');assert(last().action=='place' and last().kind=='chess')
assert(math.abs(last().position.x-.13)<.001 and math.abs(last().position.y+.2)<.001 and last().position.z>.415 and last().rotation>0)
assert(not C.isActive() and not focus)
placeAt={x=0,y=0,z=0}
-- Existing board creates proximity interaction; only server membership seats.
local board={id=1,owned=true,position={x=0,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={board}});step()
assert(not C.isActive());LightRpInteract.points['boardGames.1'].callback();assert(last().action=='join')
board.players={white=7,black=9};events['lightrp:boardGames:state']({boards={board}});step()
-- Free mode only: no scripted camera, nothing frozen, the HUD and the mouse
-- stay with the game (the mocks raise otherwise).
assert(C.isActive() and not focus and C.seated()==board)
waitUntil(function()return nativeCount(1)==33 end,'complete initial chess mesh (free mode)')
-- The menu finds the table from any of its props.
assert(C.boardOfProp(boardProp(0))==board and C.isRendered(board) and C.boardOfProp('nope')==nil)
-- The crosshair aims; the aimed square is outlined on the board itself, with a
-- small cross where the screen centre meets the board.
aimAt(5,7);step();step()
local preview=batches['boardGames:preview'];assert(preview and #preview.lines==6,'aimed square outline and aim cross')
for i=1,4 do local l=preview.lines[i];assert(math.abs(l.a.x-.0625*.65)<=.0625*.65+1e-9 and math.abs(l.a.y-.3125*.65)<=.0625*.65+1e-9,'outline on e2') end
-- Click e2, then click e4: one move request.
local freeCount=#requests
click();assert(#requests==freeCount,'a click selects')
aimAt(5,5);step();assert(outlines()==10,'selection and aim outlined')
click();assert(#requests==freeCount+1 and last().action=='move' and last().fromRow==7 and last().fromCol==5 and last().toRow==5 and last().toCol==5)
-- Hold on d2, move the aim to d4, release: a drag, the held piece follows the aim.
aimAt(4,7);keys.mouse1=true;step();aimAt(4,5);step();step()
local held=false
for _,p in pairs(nativeProps) do if p.name=='chess_white_pawn' and math.abs(p.position.x+.0625*.65)<.001 and math.abs(p.position.y-.0625*.65)<.001 then held=true end end
assert(held,'the held piece follows the crosshair')
keys.mouse1=false;step()
assert(#requests==freeCount+2 and last().fromRow==7 and last().fromCol==4 and last().toRow==5 and last().toCol==4)
-- Chat (or another page) typing: table keys are inert.
captured=true;edge('BACKSPACE');aimAt(5,7);click();assert(C.isActive() and #requests==freeCount+2,'typing never leaves or plays');captured=false
-- Holding ALT (the target menu) or an open menu borrows the left button.
keys.ALT=true;play(5,7,5,5);keys.ALT=false;step();assert(#requests==freeCount+2,'ALT clicks are menu clicks')
handlers['open77:contextmenu:opened']();play(5,7,5,5);handlers['open77:contextmenu:closed']()
assert(#requests==freeCount+2,'an open target menu owns the clicks')
-- A side-view click on a queen's head selects its actual square, and does
-- not accidentally submit a move to the square behind it on mouse-up.
local headRequests=#requests
forcedRay={origin={x=-.0625*.65,y=.4375*.65+.9,z=.065+.35},direction={x=0,y=-.9,z=-.35}}
keys.mouse1=true;step();keys.mouse1=false;step();assert(#requests==headRequests,'clicking a head must not move the piece')
-- The head was picked: a click on d6 (a legal-looking target in front) is the selected queen's move.
aimAt(4,6);click();assert(#requests==headRequests+1 and last().fromRow==8 and last().fromCol==4,'tall-piece picking must use the native piece bounds')
forcedRay=nil
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
local before=pawnY();assert(before)
local oldCreates,oldRemoves=createdProps,removedProps
board.game=assert(LightRPBoardRules.move(board.game,7,5,5,5));board.revision=2
events['lightrp:boardGames:state']({boards={board}});step()
waitUntil(function()return pawnY() and pawnY()<before end,'pawn animation')
local after=pawnY();assert(after and after<before and after>.04,'piece interpolation expected')
assert(nativeProps[pawnHandle] and createdProps==oldCreates and removedProps==oldRemoves,'normal moves must retain native prop handles')
-- Captured pieces retain their cached mesh and slide into the capturing camp.
waitUntil(function() return next(transformsInStep)==nil end,'every piece at rest')
board.game=assert(LightRPBoardRules.move(board.game,2,4,4,4));board.revision=3
events['lightrp:boardGames:state']({boards={board}})
-- Smooth motion: the moving pawn gets a transform on every frame until it
-- lands, and it is the only prop of the 33 that does.
local function blackPawnY()
 for _,p in pairs(nativeProps)do
  if p.name=='chess_black_pawn' and math.abs(p.position.x+.0625*.65)<.001 and p.position.y<0 then return p.position.y end
 end
end
step();step() -- the animation thread picks up the new snapshot's goals
local samples={blackPawnY()}
for i=1,6 do
 step();samples[#samples+1]=blackPawnY()
 local ids=0;for _ in pairs(transformsInStep) do ids=ids+1 end
 assert(ids==1,'only the moving piece is transformed ('..ids..' props this frame)')
 assert(samples[#samples]>samples[#samples-1],'the pawn advances on every frame')
end
waitUntil(function() return math.abs(blackPawnY()+.0625*.65)<1e-9 end,'pawn lands exactly on d5')
step();step();assert(next(transformsInStep)==nil,'a landed piece costs no transform')
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
edge('BACKSPACE');assert(last().action=='leave' and not C.isActive() and not focus)
-- Membership removal snapshot prevents reopening; ALT alone does nothing.
board.players={};events['lightrp:boardGames:state']({boards={board}})
local altCount=#requests;edge('ALT');assert(#requests==altCount,'ALT alone must never act')
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
-- Several complete tables nearby must not add up to one render resume over budget
-- (live: the render thread died with 7-8 tables in range and new pieces never appeared).
local many={}
for i=1,6 do many[i]={id=100+i,owned=false,position={x=4+i*3,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')} end
events['lightrp:boardGames:state']({boards=many});step()
waitUntil(function() local n=0;for i=1,6 do n=n+propsForBoard(4+i*3,'chess') end;return n==6*33 end,'six nearby chess boards')
for i=1,40 do step() end
local idleMoves=movedProps
for i=1,20 do step() end
assert(movedProps==idleMoves,'seven still tables cost no transform at all')
-- Solo: the human plays without a black seat.
Open77.character.state().position.x=0
local solo={id=3,owned=true,position={x=0,y=0,z=0},rotation=0,players={white=7},revision=1,
 kind='chess',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('chess')}
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step()
assert(C.isActive() and C.isActor(solo) and C.isReady(solo) and C.member(solo)=='white')
waitUntil(function()return nativeCount(3)==33 end,'solo board')
play(5,7,5,5);assert(last().action=='move' and last().boardId==3,'solo human can play without a black seat')
-- A stale snapshot right after a leave must not reopen the seat; a later one may.
edge('BACKSPACE');events['lightrp:boardGames:state']({boards={solo}});step();assert(not C.isActive(),'stale seat after a leave')
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step();assert(C.isActive())
-- Teammates share a colour, but only the server-designated actor may move.
solo.mode='teams';solo.players={white=8,black=9,white2=7,black2=10};solo.actor=8
solo.revision=2;events['lightrp:boardGames:state']({boards={solo}});step()
local count=#requests;play(5,7,5,5);assert(#requests==count,'a teammate waits for the actor')
solo.actor=7;solo.revision=3;events['lightrp:boardGames:state']({boards={solo}});step()
play(5,7,5,5);assert(last().action=='move')
edge('BACKSPACE')
-- Connect Four uses the vertical board plane, including rotated placements.
local four={id=4,owned=true,position={x=0,y=0,z=0},rotation=90,players={white=7},revision=1,
 kind='connect4',moveSequence=0,lastSound='connect4-drop',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('connect4')}
clock=clock+3100;events['lightrp:boardGames:state']({boards={four}});step()
assert(C.isActive())
-- Free mode: aim at a column of the upright (rotated) grid and click.
forcedRay={origin={x=-2,y=0,z=.4*.65},direction={x=1,y=0,z=0}}
local freeDrop=#requests
keys.mouse1=true;step();assert(#requests==freeDrop,'the drop waits for the release')
assert(outlines()==4,'aimed cell outlined on the grid')
keys.mouse1=false;step();assert(#requests==freeDrop+1 and last().action=='move' and last().toCol==4)
count=#requests
-- An AI turn accepts no extra human clicks.
four.actor=0;events['lightrp:boardGames:state']({boards={four}});step()
click();assert(#requests==count)
forcedRay=nil
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
waitUntil(function()return not C.isActive() and nativeCount(4)==0 end,'placeholder projection rejected')
assert(lastNotice:find('rejoin through the launcher',1,true))
events['lightrp:boardGames:state']({boards={four}})
assert(not C.isActive() and last().action=='leave','failed board projections must not reopen a seat')
-- Walking away: a step past 3.5 m only warns and coming back keeps the seat;
-- staying out 1.5 s, or passing the server's 5 m, leaves with a notice.
clock=clock+3100;Open77.character.state().position.x=0
local walk={id=6,owned=false,position={x=0,y=0,z=0},rotation=0,players={white=7,black=9},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={walk}});step()
assert(C.isActive())
Open77.character.state().position.x=3.8;step();assert(C.isActive() and lastNotice:find('Too far',1,true),'a notice warns')
Open77.character.state().position.x=1;step();assert(C.isActive(),'a step back does not kick')
Open77.character.state().position.x=3.8
local walkStart=clock
for i=1,40 do step();if not C.isActive() then break end end
assert(not C.isActive() and clock-walkStart>=1500 and last().action=='leave' and last().boardId==6)
assert(lastNotice:find('walked away',1,true))
clock=clock+3100;Open77.character.state().position.x=0;walk.revision=2
events['lightrp:boardGames:state']({boards={walk}});step();assert(C.isActive())
assert(C.leave('menu_leave') and last().action=='leave' and not C.isActive(),'the menu leaves through the same stop')
clock=clock+3100;walk.revision=3;events['lightrp:boardGames:state']({boards={walk}});step();assert(C.isActive())
Open77.character.state().position.x=5.5;step();assert(not C.isActive() and last().action=='leave','past 5 m leaves at once')
Open77.character.state().position.x=0
-- Resource cleanup removes every surface and interaction.
handlers.onClientResourceStop('test');assert(next(batches)==nil and next(LightRpInteract.points)==nil and next(soundHandles)==nil and next(nativeProps)==nil)
for i=1,20 do step()end
assert(next(batches)==nil and next(nativeProps)==nil,'cancelled renderer jobs must not resurrect native props')
print('board games client (free mode only) inventory handoff, crosshair placement, moves, ALT click isolation, teams, Connect Four drop, spatial audio, native props, streaming and budgets, failures and cleanup: OK; peak Lua instructions per tick: '..peakInstructions)
''')

# Run the real interaction guard independently: the ordinary E prompt must not
# compete with board controls while either playing or placing a board.
interact = LuaRuntime(unpack_returned_tuples=True)
interact.execute(r'''
LightRpEvents={net={interactions='interactions'},page={interact='interact'}}
LightRpConfig={};threads={};playing=true;interactions=0
Open77={character={state=function()return{position={x=0,y=0,z=0},attached=true,alive=true}end},vehicles={getPlayerSeat=function()return nil end}}
function GetGameTimer()return 0 end
LightRpBoardGamesClient={isActive=function()return playing end}
LightRpUi={send=function(name,p)lastPrompt=p end,log=function()end}
function RegisterNetEvent()end
function AddEventHandler()end
function exports()end
function CreateThread(fn)threads[#threads+1]=coroutine.create(fn)end
function Wait()coroutine.yield()end
function TriggerServerEvent()interactions=interactions+1 end
''')
interact.execute((ROOT/'resources/gamemodes/op77_lightrp/client/core/interact.lua').read_text())
interact.execute(r'''
local I=LightRpInteract
I.near={position={x=0,y=0,z=0},callback=function()interactions=interactions+1 end}
assert(I.press()==false and interactions==0)
-- The prompt loop is the last thread interact.lua starts (main added an
-- attachment watcher before it).
local prompt=threads[#threads]
local ok,why=coroutine.resume(prompt);assert(ok,why)
ok,why=coroutine.resume(prompt);assert(ok,why)
assert(I.near==nil and next(lastPrompt)==nil,'board mode must clear the ordinary E prompt')
playing=false;I.near={callback=function()interactions=interactions+1 end}
assert(I.press()==true and interactions==1,'ordinary interactions return after leaving')
''')
print('native interaction prompt and E suppression/restoration: OK')
