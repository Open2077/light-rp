-- Persistent onboarding in the arrival hall (map resource `lobby`), driven by
-- successful actions in the actual systems. Browser observations never grant
-- items, money, jobs or a completed work order.
--
-- The hall lives in its own routing bucket (shared/tutorial.lua, `lobby`): the
-- "lobby" steps are done there, the last ones in Night City. This module owns
-- the hall's contacts (NPCs), says where a character in the guide wakes up
-- (spawnPoint / deathPoint, read by server/main.lua) and moves the player
-- between the hall and the city when the guide starts, pauses or ends.
local C, Db = LightRpTutorialConfig, LightRP.db
local L = C.lobby
local Tutorial = LightRP.module("tutorial", {})
local sessions, loading, lastAction = {}, {}, {}
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_tutorial (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
    step VARCHAR(24) NOT NULL DEFAULT 'intro', status VARCHAR(16) NOT NULL DEFAULT 'active',
    revision INT NOT NULL DEFAULT 1, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY(identifier, character_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local following = {}
for i, step in ipairs(C.order) do following[step] = C.order[i + 1] end
local function inHall(step) return C.steps[step].where == "lobby" end
local function bucketOf(player,step)
    if C.steps[step].kind=="context" then return C.practice.bucketBase+player end
    return inHall(step) and L.bucket or 0
end
local function insideHall(p)
    return p ~= nil and p.x >= L.min.x and p.x <= L.max.x and p.y >= L.min.y and p.y <= L.max.y
        and p.z >= L.min.z and p.z <= L.max.z
end
local function cityArrival()
    local a = LightRpConfig.spawn.arrival
    return { name = a.name, position = a.position, heading = a.heading, bucket = 0 }
end
local function hallArrival(player,step)
    if step and C.steps[step].kind=="context" then
        local a=C.practice.position
        return {name="tutorial_practice",position={x=a.x+3,y=a.y-5,z=a.z},heading=0,bucket=bucketOf(player,step)}
    end
    return { name = L.arrival.name, position = L.arrival.position, heading = L.arrival.heading, bucket = L.bucket }
end

local function current(player, s)
    return s and sessions[player] == s and LightRP.characters.get(player) == s.character
        and s.character.status == "active"
end
local function active(player)
    local s = sessions[player]
    return C.enabled and current(player, s) and s.status == "active" and s or nil
end
local function readiness(player, step)
    local life, p = Open77.players.getLifeState(player), Open77.players.position(player)
    if life and (life.phase=="dead" or life.phase=="dying") then return false,"Get back on your feet to continue." end
    if not life or life.phase~="alive" or not p then return false,"Your character is still arriving. Please wait a moment." end
    if (p.bucket or 0)~=bucketOf(player,step) then return false,"The guide is waiting in another area. Use /tutorial to return." end
    return true
end
local function alive(player, step)
    return readiness(player,step)
end
local function near(player, step, position, radius)
    return alive(player, step) and LightRP.nearInteraction(player, {position=position, radius=radius, bucket=bucketOf(player,step)}, 0.4)
end
local function push(player) LightRP.state(player, "tutorial") end
-- The implant step (op77_neuralink). Without that resource nothing is blocked.
local function implantReady(player)
    local ok, installed = pcall(function() return exports.op77_neuralink:isInstalled(player) end)
    return not ok or installed == true
end
local function syncPractice(player,s)
    if not LightRP.tutorialPractice then return end
    if current(player,s) and s.status=="active" and C.steps[s.step].kind=="context" then
        local scene,why=LightRP.tutorialPractice.ensure(player,s.step)
        s.practiceError=not scene and why or nil
    else
        local ok,why=LightRP.tutorialPractice.clear(player)
        if s then s.practiceError=not ok and why or nil end
    end
end
local function byId(list, id)
    for _, entry in ipairs(list or {}) do if entry.id == id then return entry end end
end
-- The practice activity's sites (server/config/job_work.lua), by stage.
local function site(stage)
    local job = LightRpJobWork and LightRpJobWork.jobs[L.work]
    for _, point in ipairs(job and job.points or {}) do
        if point.kind == stage then return point, "work." .. L.work .. "." .. point.id end
    end
end
local STAGES = { collect = 1, process = 2, sell = 3 }
local LEGACY = { employment = "collect", shift = "outro" }

-- Where the step is played: the hall for its steps, the city for the others.
-- Never called for a join (main.lua asks spawnPoint) nor behind the player's
-- back: only when they start, resume, pause or finish the hall themselves.
local function relocate(player, step)
    local p = Open77.players.position(player)
    local there = p and (p.bucket or 0) == bucketOf(player,step) and insideHall(p)
    local point
    if inHall(step) and not there then
        -- Recovery after a refused bucket change preserves the current pose.
        if insideHall(p) and ((p.bucket or 0)==L.bucket or (p.bucket or 0)==C.practice.bucketBase+player) then
            return SetPlayerRoutingBucket(player,bucketOf(player,step))
        end
        point = hallArrival(player,step)
    elseif not inHall(step) and (there or insideHall(p)) then point = cityArrival() end
    if not point then return true end
    if not (LightRP.spawn and LightRP.spawn.place) then return false, "placement_unavailable" end
    local ok, why = LightRP.spawn.place(player, point, "lightrp:tutorial")
    if not ok then LightRP.log("tutorial placement for %d at %s rejected: %s", player, point.name, tostring(why)) end
    return ok, why
end

local function change(player, s, step, status)
    if not current(player, s) or s.busy then return false, "Please retry in a moment." end
    s.busy = true
    if Db.ready and s.character.identifier then
        local ok, affected = Db.run([[UPDATE lightrp_tutorial SET step=?, status=?, revision=revision+1
            WHERE identifier=? AND character_key=? AND revision=?]],
            {step, status, s.character.identifier, s.character.key, s.revision})
        if not ok or tonumber(affected) ~= 1 then
            s.busy = false
            return false, "Your guide could not be saved. Please try again."
        end
    end
    if not current(player, s) then return false, "Your character changed." end
    s.step, s.status, s.revision, s.busy, s.dialogue = step, status, s.revision+1, false, nil
    syncPractice(player,s)
    push(player)
    -- an implant already in place (a restart, a ripperdoc) passes its step at once
    if status=="active" and C.steps[step].kind=="neuralink" and implantReady(player) and following[step] then
        return change(player, s, following[step], "active")
    end
    return true
end
local function advance(player, from, to)
    local s = active(player)
    if not s or s.step ~= from then return false end
    local ok, why = change(player, s, to, "active")
    if not ok then LightRP.notice(player, {kind="error", title="First day guide", body=why}) end
    return ok
end

function Tutorial.onCharacterLoaded(player, character)
    sessions[player] = nil
    loading[player] = nil
    if not C.enabled or not Db.ready or not character.identifier then return end
    local token = {}; loading[player] = token
    local ok, rows = Db.read("SELECT step,status,revision FROM lightrp_tutorial WHERE identifier=? AND character_key=?", {character.identifier,character.key})
    if loading[player] ~= token or LightRP.characters.get(player) ~= character then return end
    loading[player] = nil
    if not ok then return end
    local row = rows[1]
    if row and (row.status=="active" or row.status=="paused" or row.status=="done") then
        -- A checkpoint saved by an earlier version of the guide may name a step
        -- that no longer exists (a job was once chosen in the hall): it resumes
        -- at the step that replaced it, or at the guide's first meeting.
        local step = C.steps[row.step] and row.step or LEGACY[row.step] or "meet"
        sessions[player] = {character=character, step=step, status=row.status, revision=tonumber(row.revision) or 1}
    end
    push(player)
end

-- firstArrival: the character was just created; server/main.lua places it (it
-- asks spawnPoint). Any other start is the player's own request: they are taken
-- to wherever the step is played.
function Tutorial.startFor(player, character, firstArrival)
    if not C.enabled or not character or character.status ~= "active" then return false end
    if loading[player] then return false, "Your guide is still loading." end
    local s = sessions[player]
    if current(player,s) then
        local ok, why = true, nil
        if s.status=="paused" then ok, why = change(player,s,s.step,"active")
        elseif s.status=="done" then ok, why = change(player,s,"meet","active") end
        if not ok then return false, why end
        syncPractice(player,s); push(player)
        relocate(player, s.step)
        return true
    end
    local token = {}; loading[player] = token
    local first = firstArrival and "intro" or "meet"
    if Db.ready and character.identifier then
        local ok = Db.run("INSERT IGNORE INTO lightrp_tutorial (identifier,character_key,step) VALUES (?,?,?)",{character.identifier,character.key,first})
        if loading[player] ~= token or LightRP.characters.get(player) ~= character then return false end
        loading[player] = nil
        if not ok then return false, "Your guide could not be saved. Use /tutorial to try again." end
        Tutorial.onCharacterLoaded(player,character)
        s = sessions[player]
        if not s then return false, "Your guide could not be loaded. Use /tutorial to try again." end
    else
        loading[player] = nil
        s = {character=character,step=first,status="active",revision=1}; sessions[player]=s
    end
    syncPractice(player,s); push(player)
    if not firstArrival and s.status == "active" then relocate(player, s.step) end
    return true
end

-- The whole first day again, opening scene included, for a character that
-- already exists: back to the first step and to the hall's door.
function Tutorial.restart(player, character)
    if not C.enabled or not character or character.status ~= "active" then return false end
    if loading[player] then return false, "Your guide is still loading." end
    local s = sessions[player]
    if not current(player, s) then
        local ok, why = Tutorial.startFor(player, character, true)
        if not ok then return false, why end
        s = sessions[player]
    end
    if s.step ~= "intro" or s.status ~= "active" then
        local ok, why = change(player, s, "intro", "active")
        if not ok then return false, why end
    end
    if not (LightRP.spawn and LightRP.spawn.place) then return false, "The arrival hall is not ready." end
    local placed, why = LightRP.spawn.place(player, hallArrival(), "lightrp:tutorial")
    if not placed then
        LightRP.log("tutorial restart for %d: placement rejected: %s", player, tostring(why))
        return false, "The arrival hall is not ready. Use /tutorial to try again."
    end
    return true
end

function Tutorial.arrivalPending(player) local s=active(player); return s and s.step=="intro" end

-- Where this character wakes up when it joins. The hall while its guide is in
-- a hall step; the city's arrival if it was saved inside the hall with no hall
-- step left (the guide was paused or ended there); nil: the usual rules.
function Tutorial.spawnPoint(player)
    if not C.enabled then return nil end
    local s = active(player)
    if s and inHall(s.step) then return hallArrival(player,s.step) end
    local c = LightRP.characters.get(player)
    if c and c.position and insideHall(c.position) then return cityArrival() end
    return nil
end
-- Where it wakes up after dying: back at the hall's door during a hall step
-- (there is no hospital in the hall's bucket).
function Tutorial.deathPoint(player)
    local s = active(player)
    if s and inHall(s.step) then return hallArrival(player,s.step) end
    return nil
end

function Tutorial.onDisconnected(player) sessions[player],loading[player],lastAction[player]=nil,nil,nil end
function Tutorial.onDatabaseReady()
    for _,player in ipairs(GetPlayers()) do
        local c=LightRP.characters.get(player)
        if c then Tutorial.onCharacterLoaded(player,c) end
    end
end
function Tutorial.onGameplayReady(player) syncPractice(player,sessions[player]); push(player) end

-- The conversation shot: in front of the contact, a step to its side.
local function shot(contact)
    local a, p = math.rad(contact.yaw or 0), contact.position
    local fx, fy = -math.sin(a), math.cos(a)
    return { position = { x = p.x + fx*2.6 + fy*1.0, y = p.y + fy*2.6 - fx*1.0, z = p.z + 1.55 },
        lookAt = { x = p.x, y = p.y, z = p.z + 1.45 }, fov = C.dialogueFov }
end

local function objectiveOf(player, s, def)
    if def.kind=="context" then
        local scene=player and LightRP.tutorialPractice and LightRP.tutorialPractice.get(player)
        local prop=s and s.step=="context_prop" or def==C.steps.context_prop
        return {position=scene and (prop and scene.propPosition or scene.position) or C.practice.position,
            label=prop and "Practice crate · Alt + click" or "Practice car · Alt + click",kind="context",radius=4}
    end
    if def.kind == "intro" or def.kind == "talk" then
        local contact = C.contacts[def.contact or "guide"]
        return { position = contact.position, label = def.prompt or ("Talk to " .. contact.name), kind = "talk", radius = C.radius }
    elseif def.kind == "shop" then
        local spot = byId(LightRpShops and LightRpShops.locations, L.shop)
        return spot and { position = spot.position, label = def.prompt, kind = "interact", interaction = "shop." .. L.shop, radius = 2.5 }
    elseif def.kind == "practice" then
        local point, id = site(def.stage)
        return point and { position = point.position, label = point.label, kind = "interact", interaction = id, radius = 2.5 }
    end
end

-- The hall seen from above, for the page's little maps: every stop with a
-- destination, in metres from the square (x east, y north), and where the
-- player stands in the order. Built once the shops and work sites are loaded.
local stops, rank = nil, {}
for i, step in ipairs(C.order) do rank[step] = i end
local function spot(p) return p and string.format("%.0f:%.0f", p.x, p.y) end
local function hallMap(s, objective)
    if not stops then
        stops = {}
        local seen = {}
        local a = L.arrival.position
        stops[1] = { step = "intro", label = L.arrival.label, x = a.x - L.origin.x, y = a.y - L.origin.y }
        for _, step in ipairs(C.order) do
            local def = C.steps[step]
            local o = inHall(step) and objectiveOf(nil, nil, def)
            local id = o and spot(o.position)
            if id and not seen[id] then
                seen[id] = true
                stops[#stops + 1] = { step = step, id = id, label = def.place or o.label,
                    x = o.position.x - L.origin.x, y = o.position.y - L.origin.y }
            end
        end
    end
    local here, now = objective and spot(objective.position), rank[s.step] or 0
    local out = {}
    for i, stop in ipairs(stops) do
        out[i] = { step = stop.step, label = stop.label, x = stop.x, y = stop.y,
            state = (here and stop.id == here) and "now" or (rank[stop.step] or 0) < now and "done" or "next" }
    end
    return out
end

function Tutorial.snapshot(player)
    local s=sessions[player]
    if not C.enabled or not current(player,s) then return {active=false,available=C.enabled} end
    local def=C.steps[s.step]
    local contact=C.contacts[def.contact or "guide"]
    local objective=objectiveOf(player,s,def)
    local talking=s.dialogue~=nil or def.kind=="outro"
    return {active=s.status=="active",available=true,status=s.status,step=s.step,revision=s.revision,
        key=s.character.key, index=def.index,total=C.total,title=def.title,hint=def.hint,line=def.line,
        kind=def.kind, where=def.where, todo=def.todo, contact=contact.name,role=contact.role, guide=C.contacts.guide.name,
        place=def.place, direction=def.direction, demo=def.demo, map=inHall(s.step) and hallMap(s,objective) or nil,
        dialogue=s.dialogue, lines=talking and def.lines or nil, action=def.action,
        camera=s.dialogue and shot(contact) or nil,
        opening=def.kind=="intro" and {eyebrow=C.opening.eyebrow,title=C.opening.title,subtitle=C.opening.subtitle,place=C.opening.place} or nil,
        practice=LightRP.tutorialPractice and LightRP.tutorialPractice.get(player) or nil, practiceError=s.practiceError,
        objective=objective}
end
LightRP.stateProvider("tutorial",Tutorial.snapshot)

-- "I'll find my own way": the guide stops and, from the hall, the door opens.
local function pause(player, s)
    -- the implant is mandatory: nobody leaves the hall without a Neural-Link
    if not implantReady(player) then return false, "Install your Neural-Link first: press F2." end
    local ok, why = change(player, s, s.step, "paused")
    if ok and insideHall(Open77.players.position(player)) then
        local placed = LightRP.spawn and LightRP.spawn.place and LightRP.spawn.place(player, cityArrival(), "lightrp:tutorial")
        if not placed then LightRP.log("tutorial: %d paused in the hall and could not be taken to the city", player) end
    end
    return ok, why
end

-- The end of the hall: the checkpoint first, then the door. The newcomer is
-- given a starter studio and wakes up in it (server/modules/housing_starter.lua);
-- without one, the door opens on the city's arrival. A refused placement leaves
-- the city step with the player still in the hall; /tutorial retries it.
local function depart(player, s)
    local ok, why = change(player, s, "outro", "active")
    if not ok then return false, why end
    local starter = LightRP.housing and LightRP.housing.starter
    if starter then
        local home, reason = starter.moveIn(player)
        if home then return true end
        LightRP.log("tutorial: no starter studio for %d (%s), going to the city", player, tostring(reason))
    end
    local placed = relocate(player, "outro")
    if not placed then return false, "The way to Night City is not ready. Use /tutorial to try again." end
    return true
end

local function control(player,payload)
    if type(payload)~="table" or not C.enabled then return false end
    local c=LightRP.characters.get(player)
    if not c or c.status~="active" then return false,"Finish your character first." end
    local now=LightRP.nowMs()
    if now-(lastAction[player] or -1000)<300 then return false end
    lastAction[player]=now
    if payload.operation=="resume" then return Tutorial.startFor(player,c) end
    local s=active(player)
    if not s or s.busy or payload.key~=c.key or payload.revision~=s.revision then return false end
    local def=C.steps[s.step]
    if payload.operation=="pause" then return pause(player,s) end
    if payload.operation=="finish" and s.step=="outro" then return change(player,s,"outro","done") end
    if def.kind=="context" and payload.operation=="practice-retry" then
        local life,p=Open77.players.getLifeState(player),Open77.players.position(player)
        if not life or life.phase~="alive" or not insideHall(p) then return false,"Return to the arrival hall to retry practice." end
        if (p.bucket or 0)~=L.bucket and (p.bucket or 0)~=bucketOf(player,s.step) then return false,"Use /tutorial to return to practice." end
        syncPractice(player,s); push(player); return not s.practiceError,s.practiceError
    end
    local ready,why=readiness(player,s.step)
    if not ready then
        -- The client retries intro completion until the placement settles. Do
        -- not turn this normal transition into repeated failure notifications.
        if payload.operation=="intro" and s.step=="intro" then return false end
        return false,why
    end
    if payload.operation=="intro" and s.step=="intro" then return advance(player,"intro","meet") end
    if s.step=="voice" and (payload.operation=="voice-done" or payload.operation=="voice-skip" or payload.operation=="voice-configured") then
        return advance(player,"voice",following.voice)
    end
    if s.step=="context_prop" and payload.operation=="practice-prop" then
        local scene=LightRP.tutorialPractice and LightRP.tutorialPractice.get(player)
        if not scene or type(payload.prop)~="string" or payload.prop~=scene.prop or not near(player,s.step,scene.propPosition,4) then return false,"Inspect the marked practice crate nearby." end
        return advance(player,s.step,following[s.step])
    end
    if def.kind=="talk" then
        local contact=C.contacts[def.contact]
        if payload.operation=="talk" then
            if not near(player,s.step,contact.position,C.radius) then return false,"Walk up to "..contact.name.."." end
            s.dialogue=s.step; push(player); return true
        end
        if payload.operation=="next" and s.dialogue==s.step then
            if not near(player,s.step,contact.position,C.radius) then s.dialogue=nil; push(player); return false,"Walk back to "..contact.name.."." end
            if s.step=="depart" then return depart(player,s) end
            return advance(player,s.step,following[s.step])
        end
    end
    if payload.operation=="identity" and s.step=="identity" then return advance(player,"identity","inventory") end
    if payload.operation=="close" and s.dialogue then s.dialogue=nil; push(player); return true end
    return false
end
RegisterNetEvent(LightRpEvents.net.tutorial,function(payload)
    local ok,why=control(source,payload)
    if not ok and why then LightRP.result(source,false,why,"tutorial.control") end
end)

function Tutorial.onInventoryOpened(player) advance(player,"inventory",following.inventory) end
-- op77_neuralink installed the implant (neuralink_bridge.lua relays it).
function Tutorial.onNeuralinkInstalled(player)
    local s = active(player)
    if not s or s.step~="neuralink" or not implantReady(player) then return end
    -- the next step's panel needs the screen and the keyboard: put the phone away first
    pcall(function() exports.op77_neuralink:closeInterface(player) end)
    advance(player,"neuralink",following.neuralink)
end
-- Called only after the ordinary, server-authorised vehicle action succeeds.
function Tutorial.onVehicleContextAction(player,vehicle,action)
    local s=active(player)
    local expected={vehicle_unlock="unlock",vehicle_open="open_5",vehicle_close="close_5"}
    local scene=LightRP.tutorialPractice and LightRP.tutorialPractice.get(player)
    if s and expected[s.step]==action and scene and scene.vehicle==vehicle and alive(player,s.step) then
        advance(player,s.step,following[s.step])
    end
end
function Tutorial.onItemUsed(player,name)
    local t=LightRpItems and LightRpItems[name]
    if name=="water" or (t and t.use and (tonumber(t.use.drink) or 0)>0) then advance(player,"drink",following.drink) end
end
-- A settled purchase at a vendor (server/modules/shops.lua); selling does not count.
function Tutorial.onShopCheckout(player,mode)
    if mode=="buy" then advance(player,"shop",following.shop) end
end
-- The practice activity (server/modules/job_work.lua): a site only works for
-- the stage being learnt, or an earlier one (a crate lost on the way can be
-- collected again); one settled batch of the stage moves on.
function Tutorial.allowsWork(player,kind)
    local s=active(player)
    local def=s and C.steps[s.step]
    return def~=nil and def.kind=="practice" and STAGES[kind]~=nil and STAGES[kind]<=STAGES[def.stage]
end
function Tutorial.onJobWorkCompleted(player,job,kind)
    if job~=L.work then return end
    local s=active(player)
    if s and C.steps[s.step].kind=="practice" and C.steps[s.step].stage==kind then advance(player,s.step,following[s.step]) end
end
function Tutorial.onLifeState(player,phase)
    local s=active(player)
    if s and phase~="alive" and s.dialogue then s.dialogue=nil; push(player) end
end

LightRP.command("tutorial",{usage="/tutorial [pause|resume|restart]"},function(player,args)
    local c=LightRP.characters.get(player)
    if not c or c.status~="active" then return false,"Finish your character first." end
    local s=active(player)
    if args[1]=="pause" then
        if not s then return true,"The guide is already paused. /tutorial resumes it." end
        local ok,why=pause(player,s); return ok,ok and "Guide paused. /tutorial resumes where you stopped." or why
    end
    if args[1]=="restart" then
        local ok,why=Tutorial.restart(player,c); return ok,ok and "First day restarted. You are back at the door of the arrival hall." or why
    end
    if args[1] and args[1]~="resume" then return false end
    local ok,why=Tutorial.startFor(player,c); return ok,ok and "First day guide ready. Follow the objective." or why
end)

-- The hall's contacts: one still body each, in the hall's bucket. The talking
-- point itself is drawn by the client for the player whose step it is.
CreateThread(function()
    if not C.enabled then return end
    Wait(700) -- after the shops and desks, which share the platform's NPC budget
    local npc = Open77.npcs
    if type(npc) ~= "table" or type(npc.create) ~= "function" then
        LightRP.log("tutorial: NPC API unavailable, the hall's contacts are invisible but still answer")
        return
    end
    for id, contact in pairs(C.contacts) do
        for _, record in ipairs(contact.records) do
            local called, npcId = pcall(npc.create, { record = record, position = contact.position, yaw = contact.yaw or 0, bucket = L.bucket,
                persistent = false, despawnWhenUnobserved = false, streamingRadius = 150,
                behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
                damagePolicy = npc.damage and (npc.damage.invulnerable or npc.damage.immortal), aiMode = npc.ai and npc.ai.tasks })
            if called and npcId then
                pcall(npc.setAIEnabled, npcId, false)
                contact.npcId = npcId
                LightRP.log("tutorial: %s (%s) stands in the hall as %s", contact.name, id, record)
                break
            end
        end
        if not contact.npcId then LightRP.log("tutorial: no body accepted for %s; the contact still answers", contact.name) end
    end
end)
