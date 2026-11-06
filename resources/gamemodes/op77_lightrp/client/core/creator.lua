-- Presentation is strictly local. World placement, chair playback and the sunny
-- private bucket are server-owned; the native body editor always takes priority.
local C = LightRpConfig.characters.arrivalScene
local EVENT, PAGE = LightRpEvents.net.creator, LightRpEvents.page.creator
local Creator = {}
LightRpCreator = Creator
local character, editing, phase = nil, false, "waiting"
local placing = false
function Creator.isPlacing() return placing end
local cam, bench, sound, frozen, hud = nil, nil, nil, false, false
local shot, from, target, changedAt, blendSeconds = "identity", nil, nil, 0, 4.5
local muted, reduced, volume, lastAudio, lastRequest = false, false, 0, 0, -100
local message, placingAt, runningAt = nil, nil, nil
local phaseAt, lostSeatAt = 0, nil
-- The scene is always shown (owner, 2026-11-05: "ça reste noir ... fiabilise que ça s'affiche
-- anyway"). The page covers the screen until the phase is "ready"; every step that waits on the
-- world (the server's start, the streamed arrival, the seat, the native pose) now has a deadline,
-- after which the camera frames the character where they stand: never a black screen for good.
local anchor = nil         -- what the shots frame: the bench (nil = the configured seat) or the body
local fallback = false     -- the scene shows without the seated arrival
local waitingAt = nil      -- since when the start has been asked with no answer
local lastSeatAsk = -100
local showWanted = nil     -- a fallback asked (net events, timeouts): the scene thread performs it
local bodyWaitAt = nil     -- since when a draft has waited for its body with nothing on screen
local SHOW_AFTER = { waiting = 10, placed = 8, seated = 3, preparing = 20, camera = 8 }
local chatEnabled, generation = nil, 0
local clock = function() return Open77.time.monotonic() end
local function draft() return character and character.status ~= "active" end
local function nativeOpen() return editing or (Open77.appearance and Open77.appearance.isOpen()) end
local function loading() return Open77.screen and Open77.screen.isLoading() == true end
local function readyBody() return draft() and (character.bodyFamily ~= nil or character.appearanceTracked == false) end

function Creator.publish()
    LightRpUi.send(PAGE, { phase = phase, error = message, muted = muted, reducedMotion = reduced })
end
local function setPhase(value, reason)
    if phase == value and message == reason then return end
    phase, message = value, reason
    phaseAt = clock()
    Creator.publish()
end
local function world(x, y, z)
    local base, heading = C.position, C.heading
    if anchor then base, heading = anchor.position, anchor.heading end
    local angle = math.rad(heading)
    return { x = base.x + math.cos(angle)*x - math.sin(angle)*y,
        y = base.y + math.sin(angle)*x + math.cos(angle)*y, z = base.z + z }
end
local function release(keepChatHidden)
    generation = generation + 1
    if cam then Open77.camera.destroy(cam); cam = nil end
    if bench then Open77.props.remove(bench); bench = nil end
    if sound then Open77.audio.destroy(sound); sound = nil end
    if frozen then Open77.character.setFrozen(false); frozen = false end
    if hud then if LightRpHud then LightRpHud.restoreVanilla() else Open77.hud.setVisible("all", true) end; hud = false end
    if chatEnabled ~= nil and not keepChatHidden then
        pcall(function() exports.open77_chat:setEnabled(chatEnabled) end)
        chatEnabled = nil
    end
    from, target, placingAt, runningAt, volume, lostSeatAt = nil, nil, nil, nil, 0, nil
    anchor, fallback, waitingAt = nil, false, nil
end
local function request(operation)
    lastRequest = clock()
    return TriggerServerEvent(EVENT, { operation = operation })
end
function Creator.sync(value)
    local previous = character
    character = value
    if not draft() then release(); setPhase("closed"); return end
    if previous and previous.key ~= value.key then release(); setPhase("waiting"); lastRequest = -100 end
end
function Creator.editor(active)
    editing = active
    if placing then return end
    if active then
        release(true)
        if draft() then request("pause") end
        setPhase("editor")
    elseif draft() then
        setPhase("waiting"); lastRequest = -100
    end
end
function Creator.bind(page)
    page:on(PAGE, function(value)
        if type(value) ~= "table" then return end
        if type(value.muted) == "boolean" then muted = value.muted end
        if type(value.reducedMotion) == "boolean" then reduced = value.reducedMotion end
        if C.shots[value.shot] and value.shot ~= "arrival" and shot ~= value.shot then
            shot = value.shot
            if target then
                local ratio = math.min(1, (clock()-changedAt)/blendSeconds)
                ratio = ratio*ratio*ratio*(ratio*(ratio*6-15)+10)
                local current = {}; for k,v in pairs(target) do current[k] = from[k] + (v-from[k])*ratio end
                from, target, changedAt, blendSeconds = current, C.shots[shot], clock(), 2.4
            end
        end
        if value.retry and draft() and not nativeOpen() and not placing then release(); setPhase("waiting"); lastRequest = -100 end
        Creator.publish()
    end)
end
RegisterNetEvent(EVENT, function(value)
    if type(value) ~= "table" then return end
    if value.phase == "placement" then
        placing = true
        release()
        LightRpUi.setMenuOpen(false)
        LightRpUi.setPromptFocus(false)
        setPhase("placement")
        return
    elseif value.phase == "placement_closed" then
        placing = false
        release()
        setPhase("waiting")
        lastRequest = -100
        return
    end
    if placing then return end
    if value.phase == "closed" then release(); setPhase("closed"); return end
    if not draft() or nativeOpen() then return end
    if value.phase == "error" then
        release()
        LightRpUi.log("creator: the server refused the arrival scene (%s): shown where the character stands", tostring(value.error))
        Creator.showAnyway("server_" .. tostring(value.error))
        return
    end
    if value.phase == "preparing" then release(); setPhase("preparing")
    elseif value.phase == "placed" and phase ~= "ready" and phase ~= "camera" then
        if phase ~= "placed" then placingAt = clock(); setPhase("placed") end
    elseif value.phase == "seated" and phase ~= "ready" and phase ~= "camera" then
        if phase ~= "seated" then placingAt = clock(); setPhase("seated") end
    end
end)

local function takeCamera()
    local token = generation
    if C.bench and not bench and not anchor then
        local o = C.benchOffset
        local why
        bench, why = Open77.props.create({ model = C.bench, position = world(o.x,o.y,o.z), yaw = C.heading + C.benchYawOffset, collision = false })
        if not bench then return false, why end
    end
    local s = C.shots[reduced and shot or "arrival"]
    local why
    cam, why = Open77.camera.create({ position = world(s.x,s.y,s.z), lookAt = world(s.aimX,0,s.aimZ), fov = s.fov, thirdPersonBody = true })
    if not cam then return false, why end
    local accepted, transition = Open77.camera.activate(cam, { blendMs = reduced and 0 or 700 })
    if not accepted then Open77.camera.destroy(cam); cam = nil; return false, transition end
    if transition then
        local _, reason = transition:await()
        if token ~= generation then return false, "scene_changed" end
        if reason then return false, reason end
    end
    if not draft() or nativeOpen() or not cam then return false, "scene_changed" end
    frozen = Open77.character.setFrozen(true) == true
    hud = Open77.hud.setVisible("all", false) == true
    local queried, enabled = pcall(function() return exports.open77_chat:isEnabled() end)
    if queried and type(enabled) == "boolean" then
        if chatEnabled == nil then chatEnabled = enabled end
        pcall(function() exports.open77_chat:setEnabled(false) end)
    end
    from, target, changedAt, blendSeconds = s, C.shots[shot], clock(), 4.5
    runningAt = clock()
    lastAudio = runningAt
    if not sound then
        sound, why = Open77.audio.play2D(C.music, { volume = 0, loop = true })
        if not sound then LightRpUi.log("creator soundtrack: %s", tostring(why)) end
    end
    setPhase("ready")
    return true
end

-- The scene without the seated arrival: the camera frames the body where it stands (the seat's own
-- framing when the body is on it). Should even the camera fail, the cover goes anyway and the game's
-- own view shows: the form is never behind a black screen.
local function bodyAnchor()
    local state = Open77.character.state()
    local p = state and state.position
    if type(p) ~= "table" or not tonumber(p.x) then return nil end
    if (p.x-C.position.x)^2 + (p.y-C.position.y)^2 + (p.z-C.position.z)^2 < 4 then return nil end -- on the bench
    local yaw = tonumber(state.yaw) or tonumber(state.heading) or 0
    -- the shots are authored for a seated body: lift them for a standing one
    return { position = { x = p.x, y = p.y, z = p.z + 0.35 }, heading = yaw }
end
-- Asked from anywhere; performed by the scene thread (the camera transition is awaited there).
function Creator.showAnyway(why) showWanted = tostring(why) end
local function show(why)
    showWanted = nil
    if placing or not draft() or nativeOpen() then return end
    release(true)
    anchor = bodyAnchor()
    fallback = true
    LightRpUi.log("creator: scene shown without the seated arrival (%s)", tostring(why))
    setPhase("camera")
    local ok, reason = takeCamera()
    if not ok then
        if cam then Open77.camera.destroy(cam); cam = nil end
        LightRpUi.log("creator: fallback camera refused (%s): the game's own view shows", tostring(reason))
        fallback = true
        setPhase("ready")
    end
end

CreateThread(function()
    while true do
        Wait(cam and 0 or 100)
        -- A draft whose body never reached us (the appearance record late, lost) still sees the scene.
        if draft() and not placing and not nativeOpen() and not readyBody() and phase == "waiting" then
            bodyWaitAt = bodyWaitAt or clock()
            if clock()-bodyWaitAt > 15 then bodyWaitAt = nil; showWanted = showWanted or "body_not_received" end
        else bodyWaitAt = nil end
        if showWanted and not placing and draft() and not nativeOpen() then
            show(showWanted)
        elseif not placing and C.autoStart ~= false and readyBody() and not nativeOpen() then
            local now = clock()
            local state = Open77.character.state()
            local p = state and state.position
            local atSeat = p and (p.x-C.position.x)^2+(p.y-C.position.y)^2+(p.z-C.position.z)^2 < 1
            -- In third person the seated workspot belongs to the local visual
            -- puppet; character.inWorkspot reads the gameplay body and stays
            -- false. current(0) resolves the animation actually presented.
            local seated = atSeat and Open77.animations.current(0) == "sit_chair_lean180__2h_on_lap__01__long__01"
            if phase == "waiting" then waitingAt = waitingAt or now else waitingAt = nil end
            if phase == "waiting" and now-waitingAt > SHOW_AFTER.waiting then
                Creator.showAnyway("no_answer_to_start")
            elseif (phase == "waiting" or phase == "editor") and now-lastRequest > 3 then
                request("start")
            elseif phase == "placed" and not loading() and now-(placingAt or now) > 0.4 then
                if state and state.grounded and now-lastRequest > 0.6 then request("seat") end
            elseif phase == "seated" and not loading()
                and ((seated and now-(placingAt or now) > 1) or (atSeat and now-(placingAt or now) > SHOW_AFTER.seated)) then
                -- the server seated the body; the native pose is the best proof, its absence (another
                -- clip name, a puppet not presenting it yet) no longer holds the scene back
                if not seated then LightRpUi.log("creator: seated pose not presented, scene shown anyway") end
                setPhase("camera")
                local ok, why = takeCamera()
                if not ok then
                    release()
                    LightRpUi.log("creator camera: %s", tostring(why))
                    if why ~= "scene_changed" then Creator.showAnyway("camera_" .. tostring(why)) end
                end
            elseif phase == "ready" and cam and target then
                -- off the seat (a push, a pose that ended): ask the seat again, keep the scene on screen
                if not fallback and not seated then
                    lostSeatAt = lostSeatAt or now
                    if now-lostSeatAt > 2 and now-lastSeatAsk > 3 and atSeat then lastSeatAsk = now; request("seat") end
                else lostSeatAt = nil end
                if not cam then goto nextTick end
                local t = reduced and 1 or math.min(1, (now-changedAt)/blendSeconds)
                t = t*t*t*(t*(t*6-15)+10)
                local s = {}; for k,v in pairs(target) do s[k] = from[k]+(v-from[k])*t end
                -- A slow, centimetre-scale dolly, not handheld shake. No camera input.
                local drift = reduced and 0 or math.sin((now-runningAt)*0.12)*0.065
                Open77.camera.setTransform(cam, { position = world(s.x+drift,s.y,s.z), fov = s.fov })
                Open77.camera.lookAt(cam, world(s.aimX,0,s.aimZ))
            end
            local limit = SHOW_AFTER[phase]
            if limit and phase ~= "waiting" and now-phaseAt > limit then
                Creator.showAnyway(phase .. "_timeout")
            end
            if sound and now-lastAudio >= 0.08 then
                local desired = (muted or loading()) and 0 or C.musicVolume
                local step = math.min(1, (now-lastAudio)/1.3)
                volume = volume+(desired-volume)*step
                Open77.audio.setVolume(sound, volume)
                lastAudio = now
            end
        elseif cam and not placing and not (fallback and draft() and not nativeOpen()) then release() end
        ::nextTick::
    end
end)
RegisterNetEvent(EVENT .. ":preview", function(value)
    if not placing or type(value) ~= "table" or nativeOpen() then return end
    local p, s, a = value.position, value.shot, math.rad(value.heading)
    local function point(x,y,z)
        return { x=p.x+math.cos(a)*x-math.sin(a)*y, y=p.y+math.sin(a)*x+math.cos(a)*y, z=p.z+z }
    end
    local position, aim = point(s.x,s.y,s.z), point(s.aimX,0,s.aimZ)
    if cam then
        Open77.camera.setTransform(cam, {position=position, fov=s.fov})
        Open77.camera.lookAt(cam, aim)
    else
        local why
        cam, why = Open77.camera.create({position=position, lookAt=aim, fov=s.fov, thirdPersonBody=true})
        if not cam then return LightRpUi.log("placement camera: %s", tostring(why)) end
        local ok, reason = Open77.camera.activate(cam, {blendMs=700})
        if not ok then release(); return LightRpUi.log("placement camera: %s", tostring(reason)) end
        hud = Open77.hud.setVisible("all", false) == true
        local queried, enabled = pcall(function() return exports.open77_chat:isEnabled() end)
        if queried and type(enabled) == "boolean" then
            chatEnabled = enabled
            pcall(function() exports.open77_chat:setEnabled(false) end)
        end
        sound = Open77.audio.play2D(C.music, {volume=C.musicVolume, loop=true})
    end
end)
-- Only a restricted server command requests a sample. The server checks the
-- nonce, ACL, readiness and proximity again before using this heading.
RegisterNetEvent(EVENT .. ":sample", function(nonce)
    if not placing then return end
    local state = Open77.character.state()
    TriggerServerEvent(EVENT .. ":sample", nonce, state and {
        position = state.position, yaw = state.yaw,
        grounded = state.grounded, mounted = state.vehicle and state.vehicle.mounted,
    } or {})
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then release() end
end)
