-- Fortune Wheel presentation. The segment, laps and timing come from the
-- server; this file only turns the shared plan into native prop poses.
--
-- A vertical wheel turns about a horizontal axis, which the prop API cannot do
-- (position + yaw only). The rotor is therefore a set of authored pose meshes:
-- the face has two-fold symmetry, so 27 poses (one per segment of a half turn)
-- show every one of the 54 rest positions exactly. The active pose sits in the
-- drum, the others are parked behind it, all with snap=true so they jump.
-- Two 40x segments look alike on the symmetric face; their own medallions
-- (rotation-invariant round art) orbit by translation and tell them apart.
-- Above ~22 segments/s two radial-blur discs replace the crisp poses.
-- The flapper is 4 pose meshes, kicked by the timing of each passing peg.
-- About 40 props per table; pieceTargets has no searches or nested loops.
local Extra=LightRpTabletopExtraClient
local F=LightRpCasinoFortune
local DEPOT="open77\\assets\\op77_lightrp\\casino_fortune\\"
-- Board-local unscaled metres; these match tools/build-casino-fortune-props.py.
local WY,WZ=.10,2.15              -- rotor face plane and wheel centre
local PARK_Y,SMALL_PARK_Y=.195,.235 -- inside the drum, behind the active rotor
local PIVOT_Y,PIVOT_Z=.042,WZ+.74 -- flapper hinge
local MEDALLION_R=.42
local FELT_Z,SPOT_Y,PAYOUT_Y,SWEEP_Y=1.252,-.68,-.84,-.42
local STEP=360/F.SEGMENTS
local BLUR_SPEED=.022             -- segments per ms (~22 per second)
local SNAP={snap=true}
local function asset(name) return Extra.asset(DEPOT,name) end
local DISCS,DISC_IDS={},{}
for i=0,F.POSES-1 do
    local name=("fortune_disc_%02d"):format(i)
    DISCS[i]=asset(name);DISC_IDS[i]="fw-"..name
end
local BLUR={[0]=asset("fortune_blur_0"),asset("fortune_blur_1")}
local FLAPS={[0]=asset("fortune_flapper_0"),asset("fortune_flapper_1"),asset("fortune_flapper_2"),asset("fortune_flapper_3")}
local FLAP_IDS={[0]="fw-flapper-0","fw-flapper-1","fw-flapper-2","fw-flapper-3"}
local CHIPS={};for level=1,6 do CHIPS[level]=asset("fortune_chips_"..level) end
local EYE,STAR=asset("fortune_eye"),asset("fortune_star")
local SPOT_X={};for i,spot in ipairs(F.SPOTS) do SPOT_X[spot]=-.6+.2*(i-1) end
local function level(amount)
    if amount<10 then return 1 elseif amount<50 then return 2 elseif amount<200 then return 3
    elseif amount<1000 then return 4 elseif amount<5000 then return 5 end
    return 6
end
-- Flapper poses: 0 overshoot (tip left), 1 rest, 2 half kick, 3 full kick.
local function flapPose(spin,now,blur)
    if blur then local f=math.floor(now/45)%4;return f==1 and 2 or f==3 and 0 or 3 end
    if type(spin)~="table" then return 1 end
    local ended=now-spin.startedAt-spin.spinMs
    if ended>=0 then -- the settle: the rotor rocks back against the flapper
        if ended<200 then return 2 elseif ended<340 then return 0 end
        return 1
    end
    local since=F.sincePeg(spin,now)
    if not since then return 1 elseif since<50 then return 3 elseif since<100 then return 2 elseif since<170 then return 0 end
    return 1
end
local function pieceTargets(board,result)
    local game=board.game
    local spin=type(game.spin)=="table" and game.spin or nil
    local now=Extra.serverTime(board)
    local pos,speed=tonumber(game.rest) or 0,0
    if spin then pos,speed=F.progress(spin,now) end
    local blur=speed>BLUR_SPEED
    local r=math.floor(pos+.5)
    local pose=blur and -1 or r%F.POSES
    local put=Extra.put
    -- Spin, settle kick, chip sweep (600 ms) and payout rise; still otherwise.
    if spin then Extra.animatingUntil(board,spin.startedAt+spin.spinMs+650) end
    Extra.stillUntil(board,math.huge)
    for i=0,F.POSES-1 do put(result,DISC_IDS[i],"fortune_disc",DISCS[i],0,i==pose and WY or PARK_Y,WZ,0,SNAP) end
    local b=blur and math.floor(now/70)%2 or -1
    put(result,"fw-blur-0","fortune_blur",BLUR[0],0,b==0 and WY or PARK_Y,WZ,0,SNAP)
    put(result,"fw-blur-1","fortune_blur",BLUR[1],0,b==1 and WY or PARK_Y,WZ,0,SNAP)
    if blur then
        put(result,"fw-eye","fortune_medallion",EYE,0,SMALL_PARK_Y,WZ,0,SNAP)
        put(result,"fw-star","fortune_medallion",STAR,0,SMALL_PARK_Y,WZ,0,SNAP)
    else
        -- Segment 0 (eye) sits at r steps clockwise from the top, 27 (star) opposite.
        local a=math.rad(r*STEP);local x,z=MEDALLION_R*math.sin(a),MEDALLION_R*math.cos(a)
        put(result,"fw-eye","fortune_medallion",EYE,x,WY,WZ+z,0,SNAP)
        put(result,"fw-star","fortune_medallion",STAR,-x,WY,WZ-z,0,SNAP)
    end
    local flap=flapPose(spin,now,blur)
    for i=0,3 do
        if i==flap then put(result,FLAP_IDS[i],"fortune_flapper",FLAPS[i],0,PIVOT_Y,PIVOT_Z,0,SNAP)
        else put(result,FLAP_IDS[i],"fortune_flapper",FLAPS[i],0,SMALL_PARK_Y,WZ+.25,0,SNAP) end
    end
    -- Chips: one stack per wagered spot. When the rotor stops, losing stacks
    -- are swept toward the wheel and the winning spot's payout rises beside it.
    local pot=type(game.pot)=="table" and game.pot or {}
    local ended=spin and now-spin.startedAt-spin.spinMs
    if ended and ended<0 then ended=nil end
    local win=ended and F.layout[spin.outcome]
    for spot,x in pairs(SPOT_X) do
        local amount=tonumber(pot[spot])
        if amount and amount>0 then
            local id="fw-chips-"..spot
            if not ended or spot==win then
                put(result,id,"fortune_chips",CHIPS[level(amount)],x,SPOT_Y,FELT_Z,0,SNAP)
            elseif ended<600 then
                local k=ended/600
                put(result,id,"fortune_chips",CHIPS[level(amount)],x,SPOT_Y+(SWEEP_Y-SPOT_Y)*k,FELT_Z-.03*k*k,0,SNAP)
            end
            if spot==win then
                local rise=math.min(1,ended/450)
                put(result,"fw-payout","fortune_chips",CHIPS[level(amount*F.MULTIPLIER[spot])],x,PAYOUT_Y,FELT_Z-.07*(1-rise),0,SNAP)
            end
        end
    end
end
-- Clicking a betting spot on the felt only selects it in the panel; money is
-- wagered explicitly with the Place bet button.
local picked,pickSerial=nil,0
-- The betting spot under a screen point (cursor or crosshair), or nil.
local function spotAt(board,sx,sy)
    local ray=Open77.camera.screenRay(sx,sy,15)
    if not ray or not ray.origin or not ray.direction or math.abs(ray.direction.z)<.001 then return end
    local planeZ=board.position.z+FELT_Z*Extra.SCALE
    local t=(planeZ-ray.origin.z)/ray.direction.z
    if t<=0 then return end
    local a=math.rad(board.rotation or 0)
    local dx,dy=ray.origin.x+ray.direction.x*t-board.position.x,ray.origin.y+ray.direction.y*t-board.position.y
    local x,y=(dx*math.cos(a)+dy*math.sin(a))/Extra.SCALE,(-dx*math.sin(a)+dy*math.cos(a))/Extra.SCALE
    if math.abs(y-SPOT_Y)>.11 then return end
    for spot,px in pairs(SPOT_X) do
        if math.abs(x-px)<.095 then return spot,px end
    end
end
local function pointer(board,event)
    if not event.pressed or event.blocked then return true end
    local spot=spotAt(board,event.x,event.y)
    if spot then picked=spot;pickSerial=pickSerial+1 end
    return true
end
-- Outline the aimed spot on the felt, and keep the picked one outlined.
local function aim(board,sx,sy,line)
    local spot,px=spotAt(board,sx,sy)
    local w,z=Extra.world,FELT_Z+.006
    local function box(x)
        local a,b,c,d=w(board,x-.09,SPOT_Y-.1,z),w(board,x+.09,SPOT_Y-.1,z),w(board,x+.09,SPOT_Y+.1,z),w(board,x-.09,SPOT_Y+.1,z)
        line(a,b);line(b,c);line(c,d);line(d,a)
    end
    if spot then box(px) end
    if picked and picked~=spot and SPOT_X[picked] then box(SPOT_X[picked]) end
end
Extra.register("fortune",{
    operations={bet=true,spin=true},
    boardModel=function() return asset("fortune_stand") end,
    pieceTargets=pieceTargets,
    pointer=pointer,
    aim=aim,
    camera=function(board,view)
        local world=Extra.world
        if view=="white" then -- the betting felt, from the player's side
            return {position=world(board,0,-1.75,2.45),lookAt=world(board,0,-.66,1.25),fov=50}
        elseif view=="black" then -- close on the flapper and the top segments
            return {position=world(board,0,-1.35,2.75),lookAt=world(board,0,WY,2.55),fov=48}
        end
        -- Default (top/orbit): the whole wheel above the betting table.
        return {position=world(board,0,-2.9,2.2),lookAt=world(board,0,-.1,1.9),fov=52}
    end,
    view=function(board)
        local extra={}
        for key,value in pairs(board.game) do extra[key]=value end
        extra.picked=picked;extra.pickSerial=pickSerial
        return {extra=extra,text="Pick a multiplier on the felt or in the panel, place your cash, then spin. The server decides every result."}
    end,
})
