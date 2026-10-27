-- Walk modes: one key cycles run -> walk -> slow walk -> run, through the
-- platform's Open77.movement.setWalkMode (players.controls). The HUD shows the
-- current mode next to the character name so a walking player knows why.
local Config = LightRpConfig
local Movement = { index = 1 }
LightRpMovement = Movement

local function log(format, ...) LightRpUi.log(format, ...) end

local function modes() return Config.movement and Config.movement.modes or { { id = "run", label = "RUN" } } end

local function available()
    return type(Open77.movement) == "table" and type(Open77.movement.setWalkMode) == "function"
end

function Movement.apply(index)
    local list = modes()
    index = ((index - 1) % #list) + 1
    local mode = list[index]
    Movement.index = index
    if Movement.safezone and (not mode.speed or mode.speed>1.5) then
        mode={id="safezone",label="WALK",speed=1.5}
    end
    if available() then
        local ok, result, reason
        if mode.speed then
            ok, result, reason = pcall(Open77.movement.setWalkMode, true, mode.speed)
        else
            ok, result, reason = pcall(Open77.movement.setWalkMode, false)
        end
        if not ok or result == false then log("walk mode %s refused: %s", mode.id, tostring(ok and reason or result)) end
    else
        log("Open77.movement unavailable: walk modes are display-only")
    end
    if LightRpHud and LightRpHud.setWalk then
        LightRpHud.setWalk({ mode = mode.id, label = mode.label, speed = mode.speed, index = index, count = #list })
    end
    return mode
end

function Movement.cycle() return Movement.apply(Movement.index + 1) end
function Movement.setSafezone(blocked)
    blocked=blocked==true
    if Movement.safezone==blocked then return end
    Movement.safezone=blocked
    Movement.apply(Movement.index)
end

function Movement.bind()
    local key = Config.keys.walk
    if key == nil then return end
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Movement.cycle() end)
    if ok then log("walk mode bound to %s", tostring(effective)) else log("walk mode key mapping failed: %s", tostring(effective)) end
end
