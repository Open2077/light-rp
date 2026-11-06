#!/usr/bin/env python3
"""Exercise the board client in the game view (scripted camera, frozen
character, hidden HUD, page cursor, bottom bar), the Free view on the
character (crosshair, left click, the cursor key) and cursor placement (the
bar's placement mode, drag on the ground, keys read physically and from the
page), using mocked documented natives. Cursor picking goes through
Open77.camera.screenRay: straight down at board-local ((x-.5),(y-.5)) for the
overhead view, a forced ray elsewhere."""
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
frozen=false; camera=nil; stoppedCamera=false; views={}
LightRpEvents={page={notice='notice',ready='ready',dialogClose='dialogClose'},net={state='state'}}
LightRpItems={}
LightRpUi={characterReady=true,ready=true,dialogs={},page={}}
-- Seated or placing, the page takes the keyboard WITH gameplay input kept and
-- consumes Escape (the pause menu stays shut); refuseConsume simulates a client
-- without consumed keys (cursor only, Escape reaches open77:pauseKey).
keyboard=false;keepInput=false;consumedKeys={}
function LightRpUi.page:setFocus(k,c,keep)
 assert(k==false or keep==true,'the table never takes gameplay input away from the game')
 if k then assert(consumedKeys[1]=='escape','Escape is consumed before the keyboard is taken') end
 keyboard=k;focus=c;keepInput=keep==true;return true
end
function LightRpUi.page:setConsumedKeys(list)
 if refuseConsume and #list>0 then return false,'webui_key_capture_unavailable' end
 consumedKeys=list;return true
end
-- Another page typing (captured) owns the focus.
function LightRpUi.page:hasFocus() return not captured and (keyboard or focus)==true end
notices={}
function LightRpUi.send(name,p)
 if name=='lightrp:boardGames:view' then view=p;views[#views+1]=p
 elseif name=='dialogClose' then closeRequest=p
 elseif name=='notice' then lastNotice=p.body;notices[#notices+1]=p.body
 else error('unexpected page event '..tostring(name)) end
end
logs,diagnostics={},{}
function LightRpUi.log(...)
 local text=string.format(...)
 logs[#logs+1]=text
 if not text:find('board games stop:',1,true) and not text:find('Escape cannot be consumed',1,true) and not text:find('cannot be drawn',1,true) then error(text) end
end
function LightRpUi.setMenuOpen(v) LightRpUi.menuOpen=v end
function RegisterNetEvent(n,f) events[n]=f end
function AddEventHandler(n,f) handlers[n]=f end
function TriggerServerEvent(n,p)
 if p.action=='diagnostic' then diagnostics[#diagnostics+1]=p else requests[#requests+1]=p end
 return true
end
function TriggerEvent(name,owner,value)
 assert(name=='open-voice:setHudBlocked' and owner=='op77_lightrp:boardGames','unexpected local event '..tostring(name))
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
Open77={network={status=function()return {playerId=7}end},character={},input={},camera={},debugDraw={},audio={},props={},hud={},exports={},
 players={freezeRotation=function(v) assert(type(v)=='boolean');rotationFrozen=v;return true end}}
-- The game view only disables (then re-enables) the target menu and closes it.
contextTargetingEnabled=true;contextCloseCalls=0
function Open77.exports.call(resource,name,value)
 assert(resource=='open77_contextmenu','unexpected export '..tostring(resource))
 local result
 if name=='setTargetingEnabled' then contextTargetingEnabled=value;result=true
 elseif name=='close' then contextCloseCalls=contextCloseCalls+1;result=true
 else error('unexpected context export '..tostring(name)) end
 return {await=function() return result end}
end
function Open77.character.state() return char end
function Open77.character.setFrozen(v) frozen=v;return true end
function Open77.input.isDown(k) if deafKeys then return false end;return keys[k]==true end
function Open77.input.isCaptured() return captured==true or focus end
-- As live on 176: any page holding the keyboard, ours included, is a "menu".
Open77.session={isMenuOpen=function() return captured==true or keyboard==true or focus==true end}
kvpStore={}
Open77.kvp={get=function(k) return kvpStore[k] end,set=function(k,v) kvpStore[k]=v;return true end,delete=function(k) kvpStore[k]=nil;return true end}
function Open77.input.cursor() error('picking uses the page pointer, never the OS cursor') end
function Open77.camera.cameras()
 if registryNil then return nil end
 if registryOverride then return registryOverride end
 return {held=camera~=nil or foreignHeld==true,activeCamera=camera}
end
function Open77.camera.create(spec)
 cameraOptions=spec
 if refuseThirdPerson and spec.thirdPersonBody~=nil then return nil,'unknown camera field thirdPersonBody' end
 assert(spec.thirdPersonBody==true or refuseThirdPerson,'the table cameras render the player body (thirdPersonBody=true)')
 if spec.lookAt then assert(spec.position.y~=spec.lookAt.y or spec.position.x~=spec.lookAt.x)
 else assert(spec.rotation.pitch < -85)end
 cameraSpec=spec;cameraCreates=(cameraCreates or 0)+1;return cameraReturnId or 'camera'
end
function Open77.camera.activate(id,options)assert(options.blendMs==250);camera=id;return true end
function Open77.camera.setTransform(id,p)
 assert(id==camera);cameraSpec.position=p.position;cameraSpec.rotation=p.rotation
 if p.rotation then cameraSpec.lookAt=nil end
 return true
end
function Open77.camera.lookAt(id,p)assert(id==camera);cameraSpec.lookAt=p;return true end
function Open77.hud.setCinematic(value,height)
 if value then assert(height==.01) end
 cinematic=value;return true
end
function Open77.camera.destroy(id) assert(id==camera,'destroying a camera that is not ours');camera=nil;stoppedCamera=true;return true end
function Open77.camera.screenRay(x,y)
 assert(type(x)=='number' and type(y)=='number' and x>=0 and x<=1 and y>=0 and y<=1,'picking needs a cursor point')
 if forcedRay then return forcedRay end
 return {origin={x=(x-.5)*.65,y=(y-.5)*.65,z=2},direction={x=0,y=0,z=-1}}
end
raycasts={}
function Open77.camera.screenRaycast(x,y)
 assert(type(x)=='number' and x>=0 and x<=1 and y>=0 and y<=1,'placement aims with a screen point')
 raycasts[#raycasts+1]={x=x,y=y}
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
threadPeaks={}
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
  threadPeaks[co]=math.max(threadPeaks[co] or 0,count)
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
-- Escape on the page (consumed: the pause menu does not open): TableBar.tsx emits leave.
function escape() assert(keyboard and consumedKeys[1]=='escape','Escape reaches the page only while it holds the keyboard')
 pageHandlers['lightrp:boardGames:leave']({key='escape'});step() end
-- The page cursor: overhead, cursor (x,y) is board-local (x-.5, y-.5) on board 1.
cursorX,cursorY=.5,.5
function pointer(p) pageHandlers['lightrp:boardGames:pointer'](p) end
function aimAt(col,row,n)
 n=n or 8
 cursorX,cursorY=(col-.5)/n,(row-.5)/n
 pointer({x=cursorX,y=cursorY})
end
function click()
 pointer({x=cursorX,y=cursorY,pressed=true});step()
 pointer({x=cursorX,y=cursorY,released=true});step()
end
function play(fc,fr,tc,tr,n) aimAt(fc,fr,n);click();aimAt(tc,tr,n);click() end
function outlines() local b=batches['boardGames:preview'];return b and #b.lines or 0 end
-- The faint marks of what can be clicked now (THREADS.marks).
function marks() local b=batches['boardGames:marks'];return b and #b.lines or 0 end
function last() return requests[#requests] end
-- A table key from the page (it holds the keyboard): TableBar.tsx forwards keydown/keyup.
function pageKey(key,down,rep) pageHandlers['lightrp:boardGames:key']({key=key,down=down,['repeat']=rep}) end
function traced(reason) for i=#diagnostics,1,-1 do local d=diagnostics[i];if d.event=='trace' and d.reason==reason then return d end end end
function bar(key) for _,a in ipairs(view.actions or {}) do if a.key==key then return a end end end
function press(key) pageHandlers['lightrp:boardGames:action']({key=key}) end
page={on=function(self,n,f)pageHandlers[n]=f end}
''')
for name in ['shared/board_game_models.lua', 'shared/board_games_rules.lua', 'shared/board_games.lua', 'client/core/freecam_motion.lua', 'client/core/tabletop_extra.lua',
             'client/core/board_games.lua', 'client/core/table_menu.lua', 'client/core/table_bar.lua']:
    lua.execute((ROOT/'resources/gamemodes/op77_lightrp'/name).read_text(), name=name)
lua.execute(r'''
LightRpBoardGameModels={board=function()error('debug models must not be used')end,piece=function()error('debug models must not be used')end}
local C=LightRpBoardGamesClient
C.bind(page);assert(pageHandlers.ready and pageHandlers['lightrp:boardGames:pointer'] and pageHandlers['lightrp:boardGames:action'] and pageHandlers['lightrp:boardGames:camera'])
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
LightRpUi.promptActive=false;focus=false;step();assert(C.isActive() and focus,'placement shows the page cursor')
assert(keyboard and keepInput and consumedKeys[1]=='escape','placement holds the keyboard with gameplay kept, Escape consumed')
local consumed={};for _,k in ipairs(consumedKeys) do consumed[k]=true end
assert(consumed.left and consumed.right and consumed.pageup and consumed.pagedown,'the arrows and PgUp/PgDn go to the page, not the game')
assert(rotationFrozen==true,'the mouse that moves the cursor never turns the view')
-- The bar in its placement mode: the kind, the hints, the buttons.
assert(view.active and view.placing and view.mode=='placement' and view.title=='Place: Chess' and view.status and view.detail:find('Turn 0',1,true))
local labels={};for _,a in ipairs(view.actions) do labels[#labels+1]=a.key..'='..a.keycap end
assert(table.concat(labels,',')=='place.left=←,place.right=→,place.up=PgUp,place.down=PgDn,place.confirm=E',table.concat(labels,','))
assert(bar('place.confirm').primary and bar('place.confirm').label=='Place')
assert(lastNotice:find('E: place',1,true) and lastNotice:find('Escape: cancel',1,true),'placement keys are told in a notice')
assert(traced('place_ghost').details:find('focus=keyboard',1,true),'the placement start traces the focus it got')
edge('BACKSPACE');assert(C.isActive(),'Backspace no longer cancels')
escape();assert(not C.isActive() and not focus and not keyboard and #consumedKeys==0,'Escape cancels and gives the keyboard back')
assert(not view.active and not view.placing and rotationFrozen==false)
assert(traced('place_end').details:find('reason=key_escape',1,true),'the cancel is traced')
-- The inverse callback order also waits for dialogState(false).
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
events['lightrp:boardGames:place']({kind='checkers'})
LightRpUi.promptActive=false;focus=false;step();assert(not C.isActive())
LightRpUi.dialogs.inventory=false;step();assert(C.isActive())
-- The bar's Cancel cancels too.
pageHandlers['lightrp:boardGames:leave']({});step();assert(not C.isActive() and traced('place_end').details:find('reason=ui_cancel',1,true))
-- Failed handoff times out without stealing the inventory's focus.
LightRpUi.dialogs.inventory=true;LightRpUi.promptActive=true;focus=true
events['lightrp:boardGames:place']({kind='chess'});clock=clock+2600;step()
assert(not C.isActive() and focus and lastNotice:find('inventory did not close',1,true))
assert(traced('place_cancelled'),'a failed handoff is traced')
LightRpUi.dialogs.inventory=false;LightRpUi.promptActive=false;focus=false
-- Support and other dialogs receive an explicit refusal, retaining their focus.
LightRpUi.dialogs.support=true;LightRpUi.supportMode='menu';focus=true
events['lightrp:boardGames:place']({kind='chess'});step()
assert(not C.isActive() and focus and lastNotice:find('Close the current dialog',1,true))
LightRpUi.dialogs.support=false;LightRpUi.supportMode=nil;focus=false
-- A first-use Connect Four ghost builds the real lazy grid within one task budget.
events['lightrp:boardGames:place']({kind='connect4'});step();assert(C.isActive())
escape()
-- A real native preview must load before placement can be confirmed (E or the bar's Place).
mockLoading=true;events['lightrp:boardGames:place']({kind='chess'})
assert(C.isActive() and boardProp(0,'chess'))
step();assert(view.status:find('Loading',1,true) and bar('place.confirm').enabled==false,'Place waits for the model')
local pendingCount=#requests;edge('E')
assert(C.isActive() and #requests==pendingCount and lastNotice:find('still loading',1,true))
assert(traced('place_not_ready').details:find('why=loading',1,true),'a refused E is traced with its reason')
press('place.confirm');assert(C.isActive() and #requests==pendingCount)
mockLoading=false;for i=1,8 do step() end
assert(bar('place.confirm').enabled==true and not view.status:find('Loading',1,true),'the bar follows the model loading')
edge('E');assert(last().action=='place' and not C.isActive())
assert(traced('place_confirm').details:find('via=key',1,true))
local confirmed=#requests;edge('E');assert(#requests==confirmed,'E cannot place twice')
-- A missing asset or a renderer placeholder never becomes a successful board.
events['lightrp:boardGames:place']({kind='checkers'})
nativeProps[boardProp(0,'checkers')].backend='marker_fallback'
pendingCount=#requests;step();assert(not C.isActive() and #requests==pendingCount)
do local drawn=false;for _,l in ipairs(logs) do if l:find('cannot be drawn',1,true) then drawn=true end end;for _,n in ipairs(notices) do assert(not tostring(n):find('rejoin through the launcher',1,true),'never shown: '..tostring(n)) end;assert(drawn,'logged: '..tostring(logs[#logs])..' / notice '..tostring(lastNotice)) end
assert(traced('place_end').details:find('reason=preview_model_failed',1,true))
mockCreateFailure=true;events['lightrp:boardGames:place']({kind='chess'})
assert(not C.isActive() and not focus and logs[#logs]:find('invalid_model',1,true) and not (lastNotice or ''):find('invalid_model',1,true))
assert(traced('place_ghost_failed'))
mockCreateFailure=false
mockLoading=true;events['lightrp:boardGames:place']({kind='connect4'})
clock=clock+3100;step();assert(C.isActive(),'a slow model keeps loading within the grace period')
clock=clock+12000;step();assert(not C.isActive() and next(nativeProps)==nil)
mockLoading=false
-- Cursor placement: a press puts the preview where the cursor ray meets the
-- ground, a drag carries it, a release lets it be; out of reach it stays.
-- The keys come from the page (it holds the keyboard) or the game; the bar's
-- buttons step.
placeAt={x=.3,y=.3,z=0}
events['lightrp:boardGames:place']({kind='chess'});assert(C.isActive() and focus)
local ghost=nativeProps[boardProp(.3,'chess')];assert(ghost,'it starts at the crosshair')
raycasts={};step();assert(#raycasts==0,'no ray while the cursor only hovers')
placeAt={x=.13,y=-.2,z=.4};pointer({x=.6,y=.6,pressed=true});step()
assert(raycasts[#raycasts].x==.6 and raycasts[#raycasts].y==.6,'the ray goes through the cursor')
ghost=nativeProps[boardProp(.13,'chess')];assert(ghost and math.abs(ghost.position.z-.415)<1e-6,'the ghost stands on the pointed surface')
placeAt={x=.5,y=.25,z=.4};pointer({x=.65,y=.55});step()
assert(nativeProps[boardProp(.5,'chess')],'a drag carries it')
pointer({x=.65,y=.55,released=true});step()
placeAt={x=-.4,y=.1,z=.4};pointer({x=.3,y=.4});step()
assert(nativeProps[boardProp(.5,'chess')],'released, it stays')
pointer({blocked=true});pointer({x=.3,y=.4,pressed=true});pointer({blocked=true});step()
placeAt={x=9,y=0,z=0};pointer({x=.9,y=.5,pressed=true});step();pointer({x=.9,y=.5,released=true});step()
assert(nativeProps[boardProp(-.4,'chess')] and view.status:find('Too far',1,true) and view.tone=='warn','out of reach it stays where it was')
placeAt={x=.13,y=-.2,z=.4};pointer({x=.6,y=.6,pressed=true});step();pointer({x=.6,y=.6,released=true});for i=1,5 do step() end
assert(not view.status:find('Too far',1,true),'back within reach (the bar follows within 200 ms)')
-- The page's keys (the live client: the page holds the keyboard): a held
-- arrow turns it until its keyup; a lost keyup expires.
deafKeys=true
pageKey('RIGHT',true);step();step();pageKey('RIGHT',false)
local turned=nativeProps[boardProp(.13,'chess')].yaw;assert(turned>0,'a page arrow turns it')
step();assert(nativeProps[boardProp(.13,'chess')].yaw==turned,'the keyup stops it')
pageKey('PAGEUP',true);step();clock=clock+1300;step();local lifted=nativeProps[boardProp(.13,'chess')].position.z
step();assert(nativeProps[boardProp(.13,'chess')].position.z==lifted and lifted>.415,'a lost keyup expires')
deafKeys=false
keys.RIGHT=true;step();step();keys.RIGHT=false;for i=1,5 do step() end
-- The bar's buttons step: 15 degrees, 5 cm.
local rotation=tonumber(view.detail:match('Turn (%d+)'))
press('place.left');assert(tonumber(view.detail:match('Turn (%d+)'))==(rotation-15)%360)
local z0=nativeProps[boardProp(.13,'chess')].position.z
press('place.up');step();assert(math.abs(nativeProps[boardProp(.13,'chess')].position.z-z0-.05)<1e-6,'Up raises it 5 cm')
press('place.down');step()
keys.PAGEUP=true;step();keys.PAGEUP=false
captured=true;edge('E');pageKey('E',true);step();pageKey('E',false);assert(C.isActive(),'typing never places');captured=false
assert(keyboard and C.isActive(),'our own keyboard focus is not typing')
-- E from the page and from the game in the same stroke: one request.
local before=#requests;keys.E=true;pageKey('E',true);step();keys.E=false;pageKey('E',false);step()
assert(#requests==before+1 and last().action=='place' and last().kind=='chess')
assert(math.abs(last().position.x-.13)<.001 and math.abs(last().position.y+.2)<.001 and last().position.z>.415 and last().rotation>0)
assert(not C.isActive() and not focus and rotationFrozen==false)
-- Physical keys unreadable while the page holds the keyboard (the live
-- report): E from the page alone places it; so does the bar's Place.
deafKeys=true
events['lightrp:boardGames:place']({kind='checkers'});for i=1,6 do step() end
before=#requests;pageKey('E',true);step();pageKey('E',false)
assert(#requests==before+1 and last().action=='place' and last().kind=='checkers' and not C.isActive(),'E from the page places')
events['lightrp:boardGames:place']({kind='connect4'});step()
before=#requests;press('place.confirm');assert(#requests==before+1 and last().kind=='connect4' and not C.isActive(),'the bar places')
assert(traced('place_confirm').details:find('via=bar',1,true))
deafKeys=false
-- Silence never lasts: a placement left alone reports what it waits for.
events['lightrp:boardGames:place']({kind='chess'});step()
clock=clock+10100;step();assert(traced('place_wait') and traced('place_wait').details:find('ready=true',1,true),'the placement heartbeat')
escape()
-- Without consumed keys: cursor only; Escape reaches the pause key and cancels.
refuseConsume=true
events['lightrp:boardGames:place']({kind='chess'});step()
assert(C.isActive() and focus and not keyboard,'cursor-only placement on a client without consumed keys')
keys.E=true;step();keys.E=false;step();assert(not C.isActive() and last().action=='place','physical E places in the cursor-only fallback')
events['lightrp:boardGames:place']({kind='checkers'});step()
handlers['open77:pauseKey']();assert(not C.isActive() and not focus)
refuseConsume=false
placeAt={x=0,y=0,z=0}
-- Existing board creates proximity interaction; only server membership seats.
local board={id=1,owned=true,position={x=0,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={board}});step()
assert(not C.isActive() and not camera);LightRpInteract.points['boardGames.1'].callback();assert(last().action=='join')
board.players={white=7,black=9};events['lightrp:boardGames:state']({boards={board}});step()
-- E to sit = the game view: a scripted overhead camera, the character frozen,
-- the HUD hidden, the cursor on the page, the target menu disabled.
assert(C.isActive() and C.seated()==board and camera and frozen and focus and cinematic and voiceHudBlocked)
assert(keyboard and keepInput and consumedKeys[1]=='escape','seated: keyboard with gameplay kept, Escape consumed (no pause menu)')
assert(rotationFrozen==true,'the mouse that moves the cursor never turns the seated body')
step();assert(contextTargetingEnabled==false and contextCloseCalls==1,'the target menu is disabled and closed')
assert(cameraSpec.rotation and cameraSpec.rotation.pitch<-85,'boards open overhead')
assert(view.active and view.kind=='chess' and view.title=='Chess' and view.view=='top' and view.camera)
assert(#view.views==5 and view.views[1].key=='top' and view.views[4].key=='orbit' and view.views[5].key=='free' and view.views[5].label=='Free')
assert(view.status=='Your turn' and view.tone=='turn' and view.detail=='You play White · 1v1' and view.hint:find('Click a piece',1,true))
assert(bar('mode') and bar('mode').label=='Mode: 1v1' and not bar('reset'),'the owner sets the mode before the first move')
assert(lastNotice:find('You play White',1,true) and lastNotice:find('Escape leaves',1,true),'seating explains the controls')
waitUntil(function()return nativeCount(1)==33 end,'complete initial chess mesh')
-- Clickable now: White's opening, 8 pawns and 2 knights (legal moves from
-- the shared rules, computed off the render resume), one faint square each.
waitUntil(function() return marks()==40 end,'the movable pieces are marked')
local markBatch=batches['boardGames:marks']
assert(markBatch.lines[1].color=='#d8ecff5c' and markBatch.ttl>=1 and markBatch.thickness<2,'marks are faint and thin')
local refreshed=0;for i=1,30 do step();if batches['boardGames:marks']~=markBatch then refreshed=refreshed+1;markBatch=batches['boardGames:marks'] end end
assert(refreshed==0,'a still table re-sends the very same batch (no rebuild)')
-- The menu finds the table from any of its props.
assert(C.boardOfProp(boardProp(0))==board and C.isRendered(board) and C.boardOfProp('nope')==nil)
-- The cursor picks; the hovered square is outlined on the board itself.
aimAt(5,7);step();step()
local preview=batches['boardGames:preview'];assert(preview and #preview.lines==4,'hovered square outline')
for i=1,4 do local l=preview.lines[i];assert(math.abs(l.a.x-.0625*.65)<=.0625*.65+1e-9 and math.abs(l.a.y-.3125*.65)<=.0625*.65+1e-9,'outline on e2') end
-- Click e2, then click e4: one move request.
local freeCount=#requests
click();assert(#requests==freeCount,'a click selects')
aimAt(5,5);step();assert(outlines()==8,'selection and hover outlined')
assert(batches['boardGames:preview'].lines[1].color=='#38f2ffff' and batches['boardGames:preview'].lines[5].color=='#ffcc00ff','selected cyan, hovered amber')
-- The selected pawn's destinations (e3, e4) join the marks.
waitUntil(function() return marks()==48 end,'destinations of the selected piece')
click();assert(#requests==freeCount+1 and last().action=='move' and last().fromRow==7 and last().fromCol==5 and last().toRow==5 and last().toCol==5 and last().revision==1)
-- Press on d2, move the cursor to d4, release: a drag, the held piece follows the cursor.
aimAt(4,7);pointer({x=cursorX,y=cursorY,pressed=true});step();aimAt(4,5);step();step()
local held=false
for _,p in pairs(nativeProps) do if p.name=='chess_white_pawn' and math.abs(p.position.x+.0625*.65)<.001 and math.abs(p.position.y-.0625*.65)<.001 then held=true end end
assert(held,'the held piece follows the cursor')
assert(#requests==freeCount+1,'dragging alone sends nothing')
pointer({x=cursorX,y=cursorY,released=true});step()
assert(#requests==freeCount+2 and last().fromRow==7 and last().fromCol==4 and last().toRow==5 and last().toCol==4)
-- A press that lands on the bar never reaches the table.
aimAt(5,7);pointer({blocked=true});step();aimAt(5,5);pointer({blocked=true});step()
assert(#requests==freeCount+2,'bar clicks never move pieces')
-- A fast press/release pair in one frame keeps its source square.
aimAt(5,7);pointer({x=cursorX,y=cursorY,pressed=true});aimAt(5,5);pointer({x=cursorX,y=cursorY,released=true});step()
assert(#requests==freeCount+3 and last().fromRow==7 and last().toRow==5,'press e2 + release e4 in one frame is a move')
-- Cursor moves between edges are coalesced: one frame never queues dozens of rays.
for i=1,40 do pointer({x=.5+i/1000,y=.5}) end
step();assert(C.isActive())
-- The bar: the owner's mode button sends the request; an unknown or stale key is dropped.
press('mode');assert(last().action=='mode' and last().mode=='solo' and last().boardId==1)
local count=#requests;press('reset');press('nope');assert(#requests==count,'only offered buttons run')
-- Camera views: cycle overhead -> white side -> black side -> orbit -> overhead.
local cam=pageHandlers['lightrp:boardGames:camera']
cam({cycle=true});assert(view.view=='white' and cameraSpec.lookAt and cameraSpec.position.y>0 and cameraCreates==1,'one camera, moved')
cam({cycle=true});assert(view.view=='black' and cameraSpec.position.y<0)
cam({cycle=true});assert(view.view=='orbit' and view.orbit)
-- Orbit: right-drag turns, the wheel zooms; neither is a table click.
local oldX,oldZ=cameraSpec.position.x,cameraSpec.position.z
pointer({x=.5,y=.5,rightPressed=true});step();pointer({x=.6,y=.45});step();pointer({x=.6,y=.45,rightReleased=true});step()
assert(cameraSpec.position.x~=oldX and cameraSpec.position.z~=oldZ and #requests==count,'right-drag orbits')
local function span() local p,t=cameraSpec.position,cameraSpec.lookAt;return math.sqrt((p.x-t.x)^2+(p.y-t.y)^2) end
local wide=span();cam({zoom=-1});assert(span()<wide,'the wheel zooms in')
cam({view='nope'});assert(view.view=='orbit','unknown views are ignored')
-- Free: on the character. No scripted camera, the character walks and looks
-- around, the HUD is back, no page cursor; the page keeps the keyboard (Escape).
stoppedCamera=false
cam({cycle=true});assert(view.view=='free' and view.free and view.free.cursor==false and view.free.key=='H' and view.camera==false)
assert(not camera and stoppedCamera and not frozen and not cinematic and voiceHudBlocked==false and rotationFrozen==false,'Free gives the character, the look and the HUD back')
assert(keyboard and keepInput and not focus and consumedKeys[1]=='escape','Free: the keyboard for Escape, no cursor')
assert(traced('view_free'),'entering Free traces the focus it got')
assert(kvpStore['boardGames:view']=='free','choosing Free is remembered')
-- The crosshair aims (the screen-centre ray), the left button plays: e2 then e4.
local function aimSquare(col,row) forcedRay={origin={x=((col-.5)/8-.5)*.65,y=((row-.5)/8-.5)*.65,z=2},direction={x=0,y=0,z=-1}} end
aimSquare(5,7);step();step()
assert(outlines()==4,'the hovered square is outlined in Free')
assert(marks()>0,'the clickable marks stay in Free')
count=#requests
edge('mouse1');assert(#requests==count,'a click selects')
aimSquare(5,5);edge('mouse1')
assert(#requests==count+1 and last().action=='move' and last().fromRow==7 and last().fromCol==5 and last().toRow==5 and last().toCol==5,'crosshair click, click: a move')
-- Hold on d2, turn the aim to d4, release: a drag.
aimSquare(4,7);keys.mouse1=true;step();aimSquare(4,5);step();step();keys.mouse1=false;step()
assert(#requests==count+2 and last().fromRow==7 and last().fromCol==4 and last().toRow==5 and last().toCol==4,'crosshair drag: a move')
-- Typing elsewhere (chat): the button is inert.
captured=true;aimSquare(5,7);edge('mouse1');aimSquare(5,5);edge('mouse1');captured=false
assert(#requests==count+2,'clicks are inert while another page types')
-- H takes the cursor for the bar (the look frozen meanwhile) and gives it
-- back; the page's keydown and the game's key in one stroke toggle once.
for i=1,6 do step() end
keys.H=true;pageKey('H',true);step();keys.H=false;pageKey('H',false);step()
assert(focus and keyboard and rotationFrozen==true and view.free.cursor==true and not camera and not frozen,'H: the cursor for the bar')
forcedRay=nil;play(5,7,5,5);assert(#requests==count+3 and last().action=='move','the cursor picks through the game camera')
press('mode');assert(last().action=='mode','the bar works with the cursor out')
for i=1,6 do step() end
pageKey('H',true);step();pageKey('H',false);step()
assert(not focus and keyboard and rotationFrozen==false and view.free.cursor==false,'H again: back to the crosshair')
-- Back to a scripted view: the camera, the freeze, the cursor and the hidden HUD again.
count=#requests
cam({cycle=true});assert(view.view=='top' and camera and cameraCreates==2 and frozen and focus and cinematic and voiceHudBlocked and rotationFrozen==true and not view.free)
assert(cameraOptions.thirdPersonBody==true,'the recreated camera renders the player body')
assert(kvpStore['boardGames:view']==nil,'a scripted view forgets Free')
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
-- After the first move the owner's button is New game.
assert(bar('reset') and bar('reset').label=='New game' and not bar('mode'))
press('reset');assert(last().action=='reset' and last().boardId==1)
-- Backspace is not a leave key any more; Escape (consumed by the page) leaves and restores everything.
local seatedRequests=#requests;edge('BACKSPACE');assert(C.isActive() and #requests==seatedRequests,'Backspace stays on the table')
escape();assert(last().action=='leave' and not C.isActive() and diagnostics[#diagnostics].reason=='key_escape')
assert(not keyboard and #consumedKeys==0 and marks()==0,'the keyboard, Escape and the marks are released')
assert(rotationFrozen==false,'the body turns again')
assert(not camera and stoppedCamera and not frozen and not focus and cinematic==false and voiceHudBlocked==false and view.active==false)
step();assert(contextTargetingEnabled==true,'the target menu is back')
-- Free chosen once opens every table in Free (remembered on this machine).
kvpStore['boardGames:view']='free';clock=clock+5000
board.revision=board.revision+1;events['lightrp:boardGames:state']({boards={board}});step()
assert(C.isActive() and view.view=='free' and not camera and not frozen and keyboard and not focus,'the remembered Free view opens the table')
assert(not traced('camera_refused'),'Free needs no table camera')
escape();assert(not C.isActive());kvpStore={};clock=clock+5000
-- Membership removal snapshot prevents reopening.
board.players={};events['lightrp:boardGames:state']({boards={board}})
-- Switching nearest full boards must release old tags BEFORE allocating replacements.
local second={id=2,owned=false,position={x=2,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')}
events['lightrp:boardGames:state']({boards={board,second}});step()
Open77.character.state().position.x=2;step()
waitUntil(function()return nativeCount(2)==33 end,'new nearest chess cache')
local hasSecond=boardProp(2)~=nil
assert(hasSecond,'new nearest board should be rendered')
-- Seen from 60 m the tables stay drawn, pieces included, without colliders.
local function colliders() local n=0;for _,p in pairs(nativeProps) do if p.name:find('_collider$') then n=n+1 end end;return n end
assert(colliders()==2,'two solid tables nearby')
Open77.character.state().position.x=60;step()
waitUntil(function()return colliders()==0 end,'far tables shed their colliders')
assert(nativeCount(1)==33 and nativeCount(2)==33,'far tables keep their pieces')
assert(traced('collider_create_failed')==nil)
-- Beyond FAR_RADIUS they stream out.
Open77.character.state().position.x=200;step();assert(next(nativeProps)==nil,'distant native props must stream out')
Open77.character.state().position.x=0;step()
waitUntil(function()return nativeCount(1)==33 and nativeCount(2)==33 and colliders()==2 end,'nearby native boards stream back in, solid')
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
-- Twelve tables seen from far: the nearest keep their pieces while the quota
-- allows, the rest show their base alone (1 prop), and coming closer brings
-- the pieces back.
local crowd={}
for i=1,12 do crowd[i]={id=200+i,owned=false,position={x=60+i*4,y=0,z=0},rotation=0,players={},revision=1,kind='chess',game=LightRPBoardRules.new('chess')} end
events['lightrp:boardGames:state']({boards=crowd});step()
waitUntil(function() return propsForBoard(108,'chess')==1 and propsForBoard(64,'chess')==33 end,'far crowd: pieces near, bases beyond the quota')
local total=0;for _ in pairs(nativeProps) do total=total+1 end
assert(total<=220,'the far crowd stays within the prop budget: '..total)
local bases=0;for i=1,12 do if propsForBoard(60+i*4,'chess')==1 then bases=bases+1 end end
assert(bases>=5 and propsForBoard(64,'chess')==33,'the farthest tables are drawn as bases: '..bases)
assert(traced('render_base'),'a base-only table is traced')
local peak=0
Open77.character.state().position.x=104;step()
waitUntil(function()
 local n=0;for _ in pairs(nativeProps) do n=n+1 end;peak=math.max(peak,n)
 return propsForBoard(108,'chess')==33 and propsForBoard(64,'chess')==1
end,'walking over swaps the detail')
assert(peak<=230,'never over the client quota on the way: '..peak)
Open77.character.state().position.x=0
events['lightrp:boardGames:state']({boards=many});step()
-- Solo: the human plays without a black seat. A camera held by another
-- script: the cursor and the bar still work over the game camera.
Open77.character.state().position.x=0
local solo={id=3,owned=true,position={x=0,y=0,z=0},rotation=0,players={white=7},revision=1,
 kind='chess',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('chess')}
foreignHeld=true;local creates=cameraCreates
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step()
assert(C.isActive() and C.isActor(solo) and C.isReady(solo) and C.member(solo)=='white')
assert(not camera and cameraCreates==creates and focus and frozen and view.active and view.camera==false,'no camera: cursor and bar only')
assert(notices[#notices-1]:find('camera is unavailable',1,true),notices[#notices-1])
waitUntil(function()return nativeCount(3)==33 end,'solo board')
play(5,7,5,5);assert(last().action=='move' and last().boardId==3,'solo human can play without a black seat')
escape();foreignHeld=false;assert(not frozen and not focus)
-- Another script taking the camera over (string or numeric ids alike) ends the view.
cameraReturnId=77
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step();assert(C.isActive() and camera==77)
clock=clock+1300;registryOverride={held=true,activeCamera='77'};step()
assert(C.isActive(),'numeric and string camera IDs represent the same camera')
registryOverride={held=false};for i=1,20 do step()end
assert(C.isActive(),'unknown camera IDs must not close the game')
registryOverride={held=true,activeCamera='other-owner'};step();for i=1,6 do step()end
assert(C.isActive(),'a transient foreign camera must respect the ownership grace')
for i=1,12 do step()end
assert(not C.isActive() and diagnostics[#diagnostics].reason=='camera_switched' and not frozen and not focus)
registryOverride=nil;cameraReturnId=nil
-- A client that refuses thirdPersonBody still gets the camera (retried
-- without it, traced).
refuseThirdPerson=true;clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step()
assert(C.isActive() and camera and cameraOptions.thirdPersonBody==nil and traced('camera_option_refused'),'the view survives a refused camera option')
escape();refuseThirdPerson=false
-- A stale snapshot right after a leave must not reopen the seat; a later one may.
events['lightrp:boardGames:state']({boards={solo}});step();assert(not C.isActive(),'stale seat after a leave')
clock=clock+3100;events['lightrp:boardGames:state']({boards={solo}});step();assert(C.isActive())
-- A side-view click on a queen's head selects its actual square, and does
-- not accidentally submit a move to the square behind it on mouse-up.
pageHandlers['lightrp:boardGames:camera']({view='white'})
local headRequests=#requests
forcedRay={origin={x=-.0625*.65,y=.4375*.65+.9,z=.065+.35},direction={x=0,y=-.9,z=-.35}}
pointer({x=.5,y=.5,pressed=true});step();pointer({x=.5,y=.5,released=true});step()
assert(#requests==headRequests,'clicking a head must not move the piece')
forcedRay=nil;pageHandlers['lightrp:boardGames:camera']({view='top'})
-- The head was picked: a click on d6 is the selected queen's move.
aimAt(4,6);click();assert(#requests==headRequests+1 and last().fromRow==8 and last().fromCol==4,'tall-piece picking must use the native piece bounds')
-- Teammates share a colour, but only the server-designated actor may move.
solo.mode='teams';solo.players={white=8,black=9,white2=7,black2=10};solo.actor=8
solo.revision=2;events['lightrp:boardGames:state']({boards={solo}});step()
local count=#requests;play(5,7,5,5);assert(#requests==count,'a teammate waits for the actor')
solo.actor=7;solo.revision=3;events['lightrp:boardGames:state']({boards={solo}});step()
play(5,7,5,5);assert(last().action=='move')
escape()
-- Connect Four uses the vertical board plane, including rotated placements.
local four={id=4,owned=true,position={x=0,y=0,z=0},rotation=90,players={white=7},revision=1,
 kind='connect4',moveSequence=0,lastSound='connect4-drop',mode='solo',ready=true,actor=7,game=LightRPBoardRules.new('connect4')}
clock=clock+3100;events['lightrp:boardGames:state']({boards={four}});step()
assert(C.isActive() and view.view=='front' and cameraSpec.lookAt and #view.views==4,'Connect Four opens on the front of the grid')
-- Connect Four: the seven open columns are marked on the grid's face.
waitUntil(function() return marks()==28 end,'open columns marked')
assert(view.hint=='Click a column to drop a disc' and view.detail=='You play Red · Solo vs AI')
-- Point at a column of the upright (rotated) grid and click.
forcedRay={origin={x=-2,y=0,z=.4*.65},direction={x=1,y=0,z=0}}
local freeDrop=#requests
pointer({x=.5,y=.5,pressed=true});step();assert(#requests==freeDrop,'the drop waits for the release')
assert(outlines()==4,'hovered cell outlined on the grid')
pointer({x=.5,y=.5,released=true});step();assert(#requests==freeDrop+1 and last().action=='move' and last().toCol==4)
count=#requests
-- An AI turn accepts no extra human clicks.
four.actor=0;events['lightrp:boardGames:state']({boards={four}});step()
click();assert(#requests==count)
waitUntil(function() return marks()==0 end,'no marks on the AI turn')
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
do local drawn=false;for _,l in ipairs(logs) do if l:find('cannot be drawn',1,true) then drawn=true end end;for _,n in ipairs(notices) do assert(not tostring(n):find('rejoin through the launcher',1,true),'never shown: '..tostring(n)) end;assert(drawn,'logged: '..tostring(logs[#logs])..' / notice '..tostring(lastNotice)) end
events['lightrp:boardGames:state']({boards={four}})
assert(not C.isActive() and last().action=='leave','failed board projections must not reopen a seat')
-- Checkers: a capture is mandatory, so only the man that can take is marked
-- (the shared rules, not a geometric guess); selecting it marks its landing square.
clock=clock+3100
local cg=LightRPBoardRules.new('checkers')
for r=1,10 do for c=1,10 do cg.board[r][c]=false end end
cg.board[7][2]={id=1,side='white',kind='man'};cg.board[6][5]={id=2,side='white',kind='man'}
cg.board[5][6]={id=3,side='black',kind='man'};cg.board[1][2]={id=4,side='black',kind='man'}
local draughts={id=7,owned=false,position={x=0,y=0,z=0},rotation=0,players={white=7,black=9},revision=1,kind='checkers',game=cg}
events['lightrp:boardGames:state']({boards={draughts}});step();assert(C.isActive())
waitUntil(function() return marks()==4 end,'only the capturing man is marked')
aimAt(5,6,10);click()
waitUntil(function() return marks()==8 end,'its landing square joins the marks')
escape();assert(not C.isActive() and marks()==0)
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
-- Chat took the keyboard and released it: the game view takes it back, so Escape stays ours.
clock=clock+3100;walk.revision=4;events['lightrp:boardGames:state']({boards={walk}});step();assert(C.isActive() and keyboard)
keyboard=false;focus=false;for i=1,12 do step() end
assert(keyboard and focus and consumedKeys[1]=='escape','focus reclaimed after another page let go')
escape();assert(not C.isActive())
-- A client without consumed keys: cursor only, Escape reaches the pause key,
-- which still leaves (the pause menu opens as well there).
refuseConsume=true;clock=clock+3100;walk.revision=5;events['lightrp:boardGames:state']({boards={walk}});step()
local warned=false;for _,line in ipairs(logs) do if line:find('Escape cannot be consumed',1,true) then warned=true end end
assert(C.isActive() and focus and not keyboard and warned)
handlers['open77:pauseKey']();assert(not C.isActive() and last().action=='leave' and diagnostics[#diagnostics].reason=='key_escape_pause')
refuseConsume=false
-- Resource cleanup removes every surface and interaction.
handlers.onClientResourceStop('test');assert(next(batches)==nil and next(LightRpInteract.points)==nil and next(soundHandles)==nil and next(nativeProps)==nil)
for i=1,20 do step()end
assert(next(batches)==nil and next(nativeProps)==nil,'cancelled renderer jobs must not resurrect native props')
local names={'table menu','render','animate','validate','marks','main loop'}
local parts={};for i,co in ipairs(threads) do if i<=6 then parts[#parts+1]=names[i]..' '..(threadPeaks[co] or 0) end end
print('peak per thread: '..table.concat(parts,', '))
print('board games client: inventory handoff, cursor placement (bar mode, drag on the ground, reach, page and physical keys, buttons, traces on every exit, heartbeat), Escape (consumed, pause-key fallback, focus reclaim), game view (camera with thirdPersonBody, freeze, cursor, HUD, target menu), clickable marks (chess, checkers capture, Connect Four), Free on the character (crosshair hover, click and drag, typing guard, H cursor toggle, back to a scripted view), cursor picking and drag, bar buttons, camera views and orbit, camera refusal and takeover, teams, Connect Four drop, spatial audio, native props, streaming and budgets, failures and cleanup: OK; peak Lua instructions per resume: '..peakInstructions)
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
