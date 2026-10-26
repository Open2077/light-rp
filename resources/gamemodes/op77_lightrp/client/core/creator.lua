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
    local angle = math.rad(C.heading)
    return { x = C.position.x + math.cos(angle)*x - math.sin(angle)*y,
        y = C.position.y + math.sin(angle)*x + math.cos(angle)*y, z = C.position.z + z }
end
local function release(keepChatHidden)
    generation = generation + 1
    if cam then Open77.camera.destroy(cam); cam = nil end
    if bench then Open77.props.remove(bench); bench = nil end
    if sound then Open77.audio.destroy(sound); sound = nil end
    if frozen then Open77.character.setFrozen(false); frozen = false end
    if hud then Open77.hud.setVisible("all", true); hud = false end
    if chatEnabled ~= nil and not keepChatHidden then
        pcall(function() exports.open77_chat:setEnabled(chatEnabled) end)
        chatEnabled = nil
    end
    from, target, placingAt, runningAt, volume, lostSeatAt = nil, nil, nil, nil, 0, nil
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
    if value.phase == "error" then release(); setPhase("error", value.error); return end
    if value.phase == "preparing" then release(); setPhase("preparing")
    elseif value.phase == "placed" and phase ~= "ready" and phase ~= "camera" then
        if phase ~= "placed" then placingAt = clock(); setPhase("placed") end
    elseif value.phase == "seated" and phase ~= "ready" and phase ~= "camera" then
        if phase ~= "seated" then placingAt = clock(); setPhase("seated") end
    end
end)

local function takeCamera()
    local token = generation
    if C.bench and not bench then
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

CreateThread(function()
    while true do
        Wait(cam and 0 or 100)
        if not placing and C.autoStart ~= false and readyBody() and not nativeOpen() then
            local now = clock()
            local state = Open77.character.state()
            local p = state and state.position
            local atSeat = p and (p.x-C.position.x)^2+(p.y-C.position.y)^2+(p.z-C.position.z)^2 < 1
            -- In third person the seated workspot belongs to the local visual
            -- puppet; character.inWorkspot reads the gameplay body and stays
            -- false. current(0) resolves the animation actually presented.
            local seated = atSeat and Open77.animations.current(0) == "sit_chair_lean180__2h_on_lap__01__long__01"
            if (phase == "waiting" or phase == "editor") and now-lastRequest > 3 then
                request("start")
            elseif phase == "placed" and not loading() and now-(placingAt or now) > 0.4 then
                if state and state.grounded and now-lastRequest > 0.6 then request("seat") end
            elseif phase == "seated" and seated and not loading() and now-(placingAt or now) > 1 then
                setPhase("camera")
                local ok, why = takeCamera()
                if not ok then
                    release()
                    if why ~= "scene_changed" then setPhase("error", "The camera could not settle. Retry the arrival scene.") end
                    LightRpUi.log("creator camera: %s", tostring(why))
                end
            elseif phase == "ready" and cam and target then
                if not seated then
                    lostSeatAt = lostSeatAt or now
                    if now-lostSeatAt > 2 then
                        release(); setPhase("waiting"); lastRequest = -100
                    end
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
            if ((phase == "placed" or phase == "seated") and now-phaseAt > 15)
                or (phase == "preparing" and now-phaseAt > 35) then
                release(); request("pause")
                setPhase("error", "The arrival scene did not settle. Please retry.")
            end
            if sound and now-lastAudio >= 0.08 then
                local desired = (muted or loading()) and 0 or C.musicVolume
                local step = math.min(1, (now-lastAudio)/1.3)
                volume = volume+(desired-volume)*step
                Open77.audio.setVolume(sound, volume)
                lastAudio = now
            end
        elseif cam and not placing then release() end
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
