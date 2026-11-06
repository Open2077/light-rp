dofile("shared/events.lua");dofile("shared/config.lua");dofile("shared/tutorial.lua")
local time,grounded,alive,loading=0,true,true,false
local position={x=-1529,y=982,z=23}
local threads,net,events,callbacks={}, {}, {}, {}
local world,worldSerial,pageSent={},0,{}
local cameras,sounds,markers,sequence={}, {}, {}, 0
local frozen,hud,chat=false,true,true
local sent,aimed,pressed,shots={},0,{},{}
-- The world the guide places: markers (never updated), page anchors, drawings, and what the page is told.
local updates,anchorSet,anchorSerial,drawn,guideSent,failed,othersUsed,peak,groundAt={},{},0,{},{},{},0,0,nil
local function id(set) sequence=sequence+1;set[sequence]=true;return sequence end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
Open77={time={monotonic=function() return time end},input={keyFor=function() return nil end},
 character={state=function() return {alive=alive,grounded=grounded,position=position} end,setFrozen=function(v) frozen=v;return true end},
 screen={isLoading=function() return loading end},hud={setVisible=function(_,v) hud=v;return true end},
 camera={create=function(v) shots[#shots+1]=v;return id(cameras) end,activate=function() return true end,destroy=function(i) cameras[i]=nil end,setTransform=function() end,lookAt=function(_,p) assert(p==LightRpTutorialConfig.opening.lookAt);aimed=aimed+1 end},
 audio={play2D=function() return id(sounds) end,destroy=function(i) sounds[i]=nil end},
 markers={create=function(v)
   assert(v.shape=="ring" or v.shape=="cylinder","only the reliable shapes: "..tostring(v.shape))
   assert(v.radius>=.1 and v.radius<=50 and v.height>=.01 and v.height<=100 and v.maxDistance<=500,"inside the marker API's ranges")
   if count(world)+othersUsed>=64 then return nil,"quota_exceeded" end
   worldSerial=worldSerial+1;local i="m"..worldSerial;world[i]=v;peak=math.max(peak,count(world));return i end,
  update=function(i,v) updates[#updates+1]=i;return true end,
  remove=function(i) world[i]=nil;return true end,
  list=function() local l={};for i in pairs(world) do l[#l+1]={id=i,failed=failed[i]==true,error=failed[i] and "marker_streaming_timeout" or nil} end
   for n=1,othersUsed do l[#l+1]={id="other"..n} end;return l end},
 anchors={create=function(v) assert(v.page and v.tag=="tutorial.guide" and v.maxDistance<=1000);anchorSerial=anchorSerial+1
   local i=tostring(anchorSerial);anchorSet[i]=v;return i end,
  remove=function(i) anchorSet[i]=nil;return true end,
  list=function() local l={};for i,v in pairs(anchorSet) do l[#l+1]={id=i,tag=v.tag} end;return l end},
 debugDraw={set=function(tag,g)
   assert(#(g.triangles or {})<=256 and #(g.lines or {})<=512 and g.ttl>=.05 and g.ttl<=10,"inside the debugDraw quotas")
   drawn[tag]={geometry=g,at=time};return true end,clear=function(tag) drawn[tag]=nil;return true end},
 world={groundZ=function(x,y,from) return groundAt end}}
LightRpUi={page={},send=function(name,v) if name==LightRpEvents.page.tutorialGuide then guideSent[#guideSent+1]=v else pageSent[#pageSent+1]=v end end,log=function() end}
LightRpInteract={setLocal=function(name,v) markers[name]=v;return v and 1 end,trackBlip=function() return true end}
exports={open77_chat={isEnabled=function() return chat end,setEnabled=function(_,v) chat=v end}}
TriggerEvent=function() end
TriggerServerEvent=function(e,v) if e==LightRpEvents.net.interact then pressed[#pressed+1]=v else sent[#sent+1]=v end;return true end
RegisterNetEvent=function(e,fn) net[e]=fn end
AddEventHandler=function(e,fn) events[e]=events[e] or {};table.insert(events[e],fn) end
local function stop() for _,fn in ipairs(events.onClientResourceStop) do fn("op77_lightrp") end end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
GetCurrentResourceName=function() return "op77_lightrp" end
dofile("client/core/tutorial_guide.lua")
dofile("client/core/tutorial.lua")
LightRpTutorial.bind({on=function(_,e,fn) callbacks[e]=fn end})
local function tick(dt) time=time+(dt or .1);for _,thread in ipairs(threads) do local ok,why=coroutine.resume(thread);assert(ok,why) end end
local function state(step,extra)
 local v={active=true,key="default",step=step,revision=1,objective={position=LightRpTutorialConfig.contacts.guide.position,label="Mara",kind="talk",radius=2.7}}
 for k,x in pairs(extra or {}) do v[k]=x end
 net[LightRpEvents.net.state]({tutorial=v})
end
state("intro");tick();tick(5)
assert(not next(cameras) and #sent==0,"creation-to-arrival relocation is not mistaken for a completed intro")
position=LightRpTutorialConfig.lobby.arrival.position;loading=true;tick();assert(not next(cameras))
loading=false;tick();assert(next(cameras) and next(sounds) and frozen and not hud and not chat)
tick(1);assert(aimed>0,"the moving camera keeps the contact in frame")
tick(8);assert(not next(cameras) and not next(sounds) and not frozen and hud and chat)
assert(sent[#sent].operation=="intro")
tick(.2);assert(#sent==1,"completion retries are throttled")
tick(2);assert(#sent==2 and sent[2].revision==sent[1].revision,"an unacknowledged completion retries the same checkpoint")
assert(not next(cameras) and not frozen and hud and chat,"a retry never replays the shot or freezes the player")
loading=true;tick(2);assert(#sent==2,"no requests during loading")
loading=false;tick();assert(#sent==3,"loading completion resumes the acknowledgement")
tick(31);assert(#sent==3 and pageSent[#pageSent].phase=="intro_retry","bounded retries leave an explicit recovery action")
callbacks[LightRpEvents.page.tutorial]({operation="intro"});tick()
assert(#sent==4 and not next(cameras),"manual retry starts a new acknowledgement window without a shot")
local talkShot={position={x=1,y=2,z=3},lookAt={x=4,y=5,z=6},fov=46}
state("meet",{dialogue="meet"});tick();assert(not next(cameras),"no conversation shot, no camera")
tick(2);assert(#sent==4,"the server's next checkpoint cancels intro retries")
state("meet",{dialogue="meet",camera=talkShot,revision=2});tick();assert(next(cameras))
assert(shots[#shots].position==talkShot.position and shots[#shots].lookAt==talkShot.lookAt,"a conversation uses the shot of the contact talked to")
alive=false;tick();assert(not next(cameras) and not frozen and hud and chat,"incapacitation releases the cinematic")
alive=true;tick();assert(next(cameras))
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="paused"}})
assert(not next(cameras) and not next(markers) and not frozen,"pausing releases every presentation claim")
state("meet",{dialogue="meet",camera=talkShot});tick();assert(next(cameras))
net[LightRpEvents.net.state]({character={status="draft"}})
assert(not next(cameras) and not next(markers),"changing character removes the old guide")
state("meet",{dialogue="meet",camera=talkShot});tick();stop()
assert(not next(cameras) and not next(sounds) and not next(markers) and not frozen and hud and chat)
-- Where to go: a beacon on the objective (a ring and a light column, created once, never
-- updated), one page anchor over it, and the bearing with the distance for the page.
local function shapes() local n={ring=0,cylinder=0};for _,m in pairs(world) do n[m.shape]=n[m.shape]+1 end;return n end
local function pointer() return guideSent[#guideSent] end
local function nothingPlaced(why)
 assert(not next(world),why..": no marker left");assert(not next(anchorSet),why..": no anchor left")
 assert(not drawn[LightRpTutorialGuide.ROUTE_TAG],why..": no drawing left")
 assert(pointer()==nil or pointer().hide==true,why..": the page's pointer is hidden")
end
nothingPlaced("no objective shown")
local guide=LightRpTutorialConfig.contacts.guide.position
local created=worldSerial
LightRpTutorialConfig.reveal.enabled=false -- no flight in this part (tested below)
position={x=guide.x,y=guide.y-40,z=guide.z};state("meet",{revision=7});tick()
assert(not next(world),"placed only once the objective has been wanted a moment (no churn on a flicker)")
tick(.3);tick(.3)
assert(shapes().ring==1 and shapes().cylinder==1 and count(world)==2 and count(anchorSet)==1,"a ring, a light column and one anchor")
for _,m in pairs(world) do
 assert(m.position.x==guide.x and m.position.y==guide.y,"the beacon stands on the objective")
 if m.shape=="cylinder" then assert(m.position.z>guide.z+2 and m.height>=50,"the column rises from above head height") end
end
local _,anchor=next(anchorSet);assert(anchor.position.x==guide.x and anchor.position.z>guide.z+2 and anchor.page==LightRpUi.page)
assert(pointer().distance==40 and pointer().angle==0 and pointer().label=="Mara","the page is told the way: straight ahead, 40 m")
created=worldSerial
for i=1,40 do position={x=guide.x+math.sin(i)*3,y=guide.y-40+i*0.9,z=guide.z};grounded=i%3~=0;tick(.1) end
grounded=true
assert(worldSerial==created and #updates==0,"walking and jumping never touch the beacon: no update, no new marker")
assert(pointer().distance<6,"the distance follows the player")
position={x=guide.x+20,y=guide.y,z=guide.z};tick(1.1);assert(pointer().angle==90,"the objective on the left: +90 degrees")
Open77.camera.view=function() return {forward={x=-1,y=0,z=0}} end;tick(1.1)
assert(pointer().angle==0,"the bearing is taken from the camera");Open77.camera.view=nil
tick(.1);local told=#guideSent;tick(.1);assert(#guideSent==told,"nothing new, nothing sent")
LightRpTutorial.publish();tick(.1);assert(#guideSent==told+1,"a page that reloads is told the way again at once")
state("meet",{dialogue="meet",camera=talkShot,revision=8});tick();tick()
assert(not next(world) and not next(anchorSet) and pointer().hide,"a conversation takes the beacon and the pointer away")
state("identity",{objective=false,revision=9});tick();tick(1);nothingPlaced("a menu step points nowhere")
state("meet",{revision=10});tick();tick(.6);assert(count(world)==2 and count(anchorSet)==1)
-- every way out removes everything, at once
alive=false;tick();assert(not next(world) and not next(anchorSet) and pointer().hide,"death")
alive=true;tick();tick(.6);assert(count(world)==2,"back after the respawn")
loading=true;tick();assert(not next(world),"a loading screen (teleport, bucket change)")
loading=false;tick();tick(.6);assert(count(world)==2)
LightRpInteract.hidden=true;tick();assert(not next(world),"a full-screen page (the fitting room)")
LightRpInteract.hidden=nil;tick();tick(.6);assert(count(world)==2)
local guideIds={};for i in pairs(world) do guideIds[#guideIds+1]=i end
state("bank",{revision=11,objective={position=LightRpTutorialConfig.contacts.banker.position,label="Idris",kind="talk",radius=2.7}})
for _,i in ipairs(guideIds) do assert(not world[i],"a new step removes the old beacon at once") end
tick();tick(.6);assert(count(world)==2 and #updates==0,"and places the new one")
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="paused"}});nothingPlaced("pausing")
state("meet",{revision=12});tick();tick(.6);assert(count(world)==2)
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="done"}});nothingPlaced("the end of the guide")
state("meet",{revision=13});tick();tick(.6);assert(count(world)==2)
net[LightRpEvents.net.state]({character={status="draft"}});nothingPlaced("another character")
state("meet",{revision=14});tick();tick(.6);assert(count(world)==2)
stop();nothingPlaced("the resource stopping")
-- A marker that failed (spawned during a loading) is placed again, a few times, then given up; logged.
local logs={};LightRpUi.log=function(f,...) logs[#logs+1]=string.format(f,...) end
state("meet",{revision=15});tick();tick(.6);assert(count(world)==2)
for i in pairs(world) do failed[i]=true end
tick(2.1);assert(not next(world) and #logs>0 and logs[#logs]:find("again"),"a failed beacon is removed, the reason logged")
tick(2);tick(2.1);assert(count(world)==2,"and placed again a little later")
for round=1,3 do for i in pairs(world) do failed[i]=true end;tick(2.1);tick(2);tick(2.1) end
assert(not next(world) and logs[#logs]:find("given up"),"not forever: given up after a few tries")
assert(pointer().distance~=nil,"the page's pointer still guides");failed={}
-- A creation refused (the world not ready) is tried again too.
local create=Open77.markers.create
Open77.markers.create=function() return nil,"world_unavailable" end
stop();state("meet",{revision=18});tick();tick(.6);assert(not next(world) and logs[#logs]:find("refused"),"refused, and said")
Open77.markers.create=create;tick(2.1);tick(2);tick(2.1);assert(count(world)==2,"placed once the world accepts it")
-- The marker budget is shared (64 per resource): the guide takes what is left, and says so.
stop();othersUsed=57;state("meet",{revision=16});tick();tick(.6)
assert(count(world)==1 and shapes().cylinder==1,"one slot: the column, seen from afar")
stop();othersUsed=58;state("meet",{revision=17});tick();tick(.6)
assert(not next(world) and logs[#logs]:find("no marker left"),"no slot: no beacon, logged")
assert(count(anchorSet)==1 and pointer().distance,"the page still points the way")
stop();othersUsed=0;LightRpUi.log=function() end;LightRpTutorialConfig.reveal.enabled=true
assert(peak<=LightRpTutorialGuide.MAX_MARKERS and #updates==0,"never more than two markers, never an update")
-- The objective's key: a contact talks, a real point of the framework is pressed.
state("meet");markers["tutorial.current"]=nil
net[LightRpEvents.net.state]({tutorial={active=true,key="default",step="bank",revision=3,objective={position={x=0,y=0,z=0},label="Banker",kind="talk",radius=2.7}}})
LightRpUi.promptActive=false;LightRpUi.menuOpen=false
local handlers={}
LightRpInteract.setLocal=function(name,v,fn) markers[name]=v;handlers[name]=fn;return v and 1 end
net[LightRpEvents.net.state]({tutorial={active=true,key="default",step="shop",revision=4,objective={position={x=0,y=0,z=0},label="Browse shop",kind="interact",interaction="shop.lobby_market",radius=2.5}}})
handlers["tutorial.current"]();assert(pressed[#pressed]=="shop.lobby_market","the shop objective presses the real shop point")
local before=#sent
net[LightRpEvents.net.state]({tutorial={active=true,key="default",step="garage",revision=5,objective={position={x=0,y=0,z=0},label="Mechanic",kind="talk",radius=2.7}}})
handlers["tutorial.current"]();assert(#sent==before+1 and sent[#sent].operation=="talk","a contact objective asks to talk")
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="paused"}})
-- The way to a new destination: a flight after the step changes, chevrons drawn along the route, blended back.
LightRpInteract.setLocal=function(name,v) markers[name]=v;return v and 1 end
local looks,deactivated={},0
Open77.camera.lookAt=function(_,p) looks[#looks+1]=p end
Open77.camera.view=function() return {position={x=position.x,y=position.y-3,z=position.z+1.8},forward={x=0,y=1,z=0},fov=70} end
Open77.camera.deactivate=function(v) assert(v.blendMs>0);deactivated=deactivated+1;return true end
local function reveals() local n=0;for _,v in ipairs(pageSent) do if type(v.reveal)=="table" then n=n+1 end end;return n end
-- The route is a drawing (4 triangles a chevron) that lives its ttl unless drawn again.
local function routeDots()
 local d=drawn[LightRpTutorialGuide.ROUTE_TAG]
 if not d or time-d.at>d.geometry.ttl then return 0 end
 return #d.geometry.triangles/4
end
local bank=LightRpTutorialConfig.contacts.banker.position
position={x=bank.x,y=bank.y-60,z=bank.z}
local function step(name,revision,extra)
 local v={active=true,key="default",step=name,revision=revision,place="Night City Bank",index=5,total=10,objective={position=bank,label="Banker",kind="talk",radius=2.7}}
 for k,x in pairs(extra or {}) do v[k]=x end
 net[LightRpEvents.net.state]({tutorial=v})
end
step("garage",20);tick()
assert(not next(cameras),"the destination found on joining is not flown to")
step("bank",21);tick(.5);assert(not next(cameras),"the done banner reads first")
LightRpUi.menuOpen=true;tick(1.5);assert(not next(cameras),"never over an open menu")
local beacon=worldSerial
LightRpUi.menuOpen=false;tick();assert(next(cameras) and frozen and not hud and reveals()==1,"the flight starts")
assert(count(world)==2 and pointer().hide,"the beacon marks the place during the flight; the page's pointer waits")
assert(shots[#shots].thirdPersonBody and shots[#shots].position.y==position.y-3,"it starts from the player's own view")
tick(2);assert(routeDots()>0 and routeDots()<19,"the route lights up as the camera passes")
tick(2.1);assert(routeDots()==19,"60 m of route, a chevron every 3 m")
assert(#drawn[LightRpTutorialGuide.ROUTE_TAG].geometry.lines>20,"a ring drawn round the place once reached")
assert(worldSerial==beacon and #updates==0,"the route places no marker")
local last=looks[#looks];assert(math.abs(last.x-bank.x)<.01 and math.abs(last.y-bank.y)<.01,"it settles on the destination")
tick(1.55);assert(deactivated==1 and not frozen and hud and not drawn[LightRpTutorialGuide.ROUTE_TAG] and next(cameras),"the view blends home, the body is free at once, the route is gone")
tick(1);assert(not next(cameras),"the definition is gone after the blend")
local flights=#shots
groundAt=bank.z-.5
callbacks[LightRpEvents.page.tutorial]({operation="way"});tick();assert(#shots==flights+1,"the way key flies again at once")
callbacks[LightRpEvents.page.tutorial]({operation="way"});tick()
assert(#shots==flights+1,"no second flight over the first")
tick(1.5);assert(routeDots()>0)
local route=drawn[LightRpTutorialGuide.ROUTE_TAG].geometry
assert(route.ttl<=1,"a drawing nobody refreshes goes by itself within a second")
assert(math.abs(route.triangles[1].a.z-(bank.z-.4))<.01,"the chevrons lie on the ground under them")
step("bank",22,{dialogue="bank"});assert(not drawn[LightRpTutorialGuide.ROUTE_TAG],"a conversation cuts the flight and its route")
assert(not frozen and hud,"and gives the body back")
position={x=bank.x,y=bank.y-5,z=bank.z};step("station",23);tick(2);tick()
assert(#shots==flights+1 and not next(cameras),"a close destination needs no flight")
-- F1 > Skip the tutorial: the page asks for confirmation; only the confirmed skip reaches the server.
local beforeSkip,shown=#sent,#pageSent
callbacks[LightRpEvents.page.tutorial]({operation="skip-ask"})
assert(#sent==beforeSkip and #pageSent==shown+1 and pageSent[#pageSent].skipAsk==true,"asking to skip stays on the page")
callbacks[LightRpEvents.page.tutorial]({operation="skip"})
assert(#sent==beforeSkip+1 and sent[#sent].operation=="skip" and sent[#sent].key=="default","the confirmed skip is the server's decision, for this slot")
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="paused"}})
assert(not next(cameras) and not frozen and hud)
-- Skipping while the server relocates must not replay the scene or send during loading.
state("intro",{revision=30});loading=true;callbacks[LightRpEvents.page.tutorial]({operation="intro"});before=#sent;tick()
assert(#sent==before and not next(cameras))
loading=false;tick();assert(#sent==before+1)
state("intro",{revision=30});tick(1);assert(#sent==before+2 and not next(cameras),"a repeated snapshot does not replay the shot")
net[LightRpEvents.net.state]({character={status="draft"}});tick(2);assert(#sent==before+2,"changing characters cancels pending retries")
state("intro",{revision=30});position=LightRpTutorialConfig.lobby.arrival.position;tick();assert(next(cameras),"a fresh character can play its own intro")
stop();tick(2);assert(#sent==before+2 and not next(cameras))
assert(peak<=LightRpTutorialGuide.MAX_MARKERS and #updates==0,"never more than two markers, never an update")
print("PASS: arrival/loading gates, intro acknowledgement retries and timeout recovery, camera/audio/freeze/HUD/chat cleanup, death, pause, character change and stop, destination flights; the guide: beacon created once and never updated (walk, jump), removed at once on conversation, step change, death, loading, full-screen page, pause, end, character change, resource stop; failed markers retried then given up, the shared marker budget, page pointer bearing/distance/republish, the flight's route drawn on the ground with a ttl and cleared")
