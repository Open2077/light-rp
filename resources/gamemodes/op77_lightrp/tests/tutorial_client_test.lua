dofile("shared/events.lua");dofile("shared/config.lua");dofile("shared/tutorial.lua")
local time,grounded,alive,loading=0,true,true,false
local position={x=-1529,y=982,z=23}
local threads,net,events,callbacks={}, {}, {}, {}
local world,worldSerial,pageSent={},0,{}
local cameras,sounds,markers,sequence={}, {}, {}, 0
local frozen,hud,chat=false,true,true
local sent,aimed,pressed,shots={},0,{},{}
local function id(set) sequence=sequence+1;set[sequence]=true;return sequence end
Open77={time={monotonic=function() return time end},input={keyFor=function() return nil end},
 character={state=function() return {alive=alive,grounded=grounded,position=position} end,setFrozen=function(v) frozen=v;return true end},
 screen={isLoading=function() return loading end},hud={setVisible=function(_,v) hud=v;return true end},
 camera={create=function(v) shots[#shots+1]=v;return id(cameras) end,activate=function() return true end,destroy=function(i) cameras[i]=nil end,setTransform=function() end,lookAt=function(_,p) assert(p==LightRpTutorialConfig.opening.lookAt);aimed=aimed+1 end},
 audio={play2D=function() return id(sounds) end,destroy=function(i) sounds[i]=nil end},
 markers={create=function(v) worldSerial=worldSerial+1;world[worldSerial]=v;return worldSerial end,
  update=function(i,v) assert(world[i],"update of a removed marker");for k,x in pairs(v) do world[i][k]=x end;return true end,
  remove=function(i) world[i]=nil;return true end}}
LightRpUi={send=function(_,v) pageSent[#pageSent+1]=v end,log=function() end}
LightRpInteract={setLocal=function(name,v) markers[name]=v;return v and 1 end,trackBlip=function() return true end}
exports={open77_chat={isEnabled=function() return chat end,setEnabled=function(_,v) chat=v end}}
TriggerEvent=function() end
TriggerServerEvent=function(e,v) if e==LightRpEvents.net.interact then pressed[#pressed+1]=v else sent[#sent+1]=v end;return true end
RegisterNetEvent=function(e,fn) net[e]=fn end
AddEventHandler=function(e,fn) events[e]=fn end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
GetCurrentResourceName=function() return "op77_lightrp" end
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
state("meet",{dialogue="meet",camera=talkShot});tick();events.onClientResourceStop("op77_lightrp")
assert(not next(cameras) and not next(sounds) and not next(markers) and not frozen and hud and chat)
-- Where to go: an arrow over the objective, dots leading to it from the player, the distance on the card.
local function shapes() local n={arrow=0,sphere=0};for _,m in pairs(world) do n[m.shape]=n[m.shape]+1 end;return n end
local function distance() for i=#pageSent,1,-1 do if pageSent[i].distance~=nil then return pageSent[i].distance end end end
assert(not next(world),"no objective shown, nothing in the world")
local guide=LightRpTutorialConfig.contacts.guide.position
position={x=guide.x,y=guide.y-40,z=guide.z};state("meet",{revision=7});tick();tick()
assert(shapes().arrow==1 and shapes().sphere==5,"an arrow and its leading dots")
for _,m in pairs(world) do
 if m.shape=="arrow" then assert(m.position.x==guide.x and m.position.y==guide.y and m.position.z>guide.z+2,"the arrow hangs over the objective")
 else assert(m.position.x==position.x and m.position.y>position.y and m.position.y<guide.y,"the dots lead from the player towards the objective") end
end
assert(distance()==40,"the card is told the distance")
position={x=guide.x,y=guide.y-3,z=guide.z};tick();assert(shapes().arrow==1 and shapes().sphere==0 and distance()==3,"close by, the arrow is enough")
state("meet",{dialogue="meet",camera=talkShot,revision=8});tick();tick();assert(not next(world) and distance()==false,"a conversation clears the world")
state("identity",{objective=false,revision=9});tick();assert(not next(world),"a menu step points nowhere")
state("meet",{revision=10});tick();assert(shapes().arrow==1)
net[LightRpEvents.net.state]({tutorial={active=false,available=true,status="paused"}});assert(not next(world),"pausing removes the arrow at once")
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
-- The way to a new destination: a flight after the step changes, dots lit along the route, blended back.
LightRpInteract.setLocal=function(name,v) markers[name]=v;return v and 1 end
local looks,deactivated={},0
Open77.camera.lookAt=function(_,p) looks[#looks+1]=p end
Open77.camera.view=function() return {position={x=position.x,y=position.y-3,z=position.z+1.8},forward={x=0,y=1,z=0},fov=70} end
Open77.camera.deactivate=function(v) assert(v.blendMs>0);deactivated=deactivated+1;return true end
local function reveals() local n=0;for _,v in ipairs(pageSent) do if type(v.reveal)=="table" then n=n+1 end end;return n end
local function routeDots() local n=0;for _,m in pairs(world) do if m.shape=="sphere" and m.maxDistance==300 then n=n+1 end end;return n end
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
LightRpUi.menuOpen=false;tick();assert(next(cameras) and frozen and not hud and reveals()==1,"the flight starts")
assert(shots[#shots].thirdPersonBody and shots[#shots].position.y==position.y-3,"it starts from the player's own view")
tick(2);assert(routeDots()>0 and routeDots()<20,"the route lights up as the camera passes")
tick(2.1);assert(routeDots()==20,"60 m of route, a dot every 3 m")
local last=looks[#looks];assert(math.abs(last.x-bank.x)<.01 and math.abs(last.y-bank.y)<.01,"it settles on the destination")
tick(1.5);assert(deactivated==1 and not frozen and hud and routeDots()==0 and next(cameras),"the view blends home, the body is free at once")
tick(1);assert(not next(cameras),"the definition is gone after the blend")
local flights=#shots
callbacks[LightRpEvents.page.tutorial]({operation="way"});tick();assert(#shots==flights+1,"the way key flies again at once")
callbacks[LightRpEvents.page.tutorial]({operation="way"});tick()
assert(#shots==flights+1,"no second flight over the first")
step("bank",22,{dialogue="bank"});assert(not next(world) or routeDots()==0,"a conversation cuts the flight")
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
events.onClientResourceStop("op77_lightrp");tick(2);assert(#sent==before+2 and not next(cameras))
print("PASS: arrival/loading gates, intro acknowledgement retries and timeout recovery, camera/audio/freeze/HUD/chat cleanup, death, pause, character change and stop, destination flights")
