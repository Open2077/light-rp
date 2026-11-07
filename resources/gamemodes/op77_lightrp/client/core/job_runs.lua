local E = LightRpEvents
local run, key, blip, workToken, actionId, lastPress = nil, nil, nil, nil, nil, 0

-- GPS: the run's route is the native waypoint (Open77.blips.setWaypoint), the
-- same GPS as a map waypoint. It does not depend on the objective's map pin,
-- which may fall back to a native sprite when the shared custom-icon budget
-- is full. Set on every new stop and on "GPS to my next stop"; put back when
-- the waypoint disappears during a run; cleared at the end if it is still ours.
local gps = { target = nil, on = false, lastSet = -10, failure = nil }
local function near2d(a, b, metres)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy <= metres * metres
end
local function setGps(force)
    local target = gps.target
    if not target or type(Open77.blips) ~= "table" or type(Open77.blips.setWaypoint) ~= "function" then return end
    local now = Open77.time.monotonic()
    if not force and now - gps.lastSet < 3 then return end
    gps.lastSet = now
    local ok, why = Open77.blips.setWaypoint({ x = target.x, y = target.y, z = target.z })
    if ok then gps.failure = nil
    elseif why ~= gps.failure then gps.failure = why; LightRpUi.log("work order GPS refused: %s", tostring(why)) end
end
local function readGps()
    if not gps.target or type(Open77.blips) ~= "table" or type(Open77.blips.waypoint) ~= "function" then return false, false end
    local ok, point, why = pcall(Open77.blips.waypoint)
    if not ok or why then return false, false end           -- the question could not be asked
    if type(point) ~= "table" then return false, true end   -- no waypoint at all
    return near2d(point, gps.target, 6), false
end
local function clearGps()
    local target = gps.target
    gps.target, gps.on = nil, false
    if not target or type(Open77.blips) ~= "table" or type(Open77.blips.waypoint) ~= "function" then return end
    local ok, point = pcall(Open77.blips.waypoint)
    if ok and type(point) == "table" and near2d(point, target, 6) then pcall(Open77.blips.clearWaypoint) end
end
local function track() setGps(true) end
local function clearWork()
    workToken = nil
    if actionId then LightRpActions.cancel(actionId); actionId = nil end
end
local function update(state)
    if type(state) ~= "table" then return end
    run = state.active and state or nil
    local nextKey = run and (run.id .. ":" .. run.index) or nil
    if key == nextKey then return end
    clearWork(); key = nextKey
    LightRpInteract.setLocal("job.current", nil); blip = nil
    if not run then clearGps(); return end
    local objective = run.objective
    if type(objective) ~= "table" or type(objective.position) ~= "table" then clearGps(); return end
    gps.target = { x = objective.position.x, y = objective.position.y, z = objective.position.z }
    local jobIcons = { sanitation = "trash-2", scrapper = "recycle", ac_cleaner = "fan", delivery = "package" }
    local icon = objective.kind == "return" and "warehouse"
        or objective.kind == "lift" and "arrow-up-down"
        or objective.kind == "pickup" and "package" or objective.kind == "dropoff" and "house"
        or jobIcons[run.job] or "map-pin"
    blip = LightRpInteract.setLocal("job.current", {
        position = objective.position, radius = objective.radius, prompt = objective.label,
        verticalReach = tonumber(objective.verticalReach), -- a stop whose marker sits above the street (Coastview depot)
        -- the pin marks the stop; the route is the waypoint (routable here would compete for tracking)
        blip = { icon = icon, size = 48, sprite = "objective", routable = false, title = "Work order", description = objective.label },
        marker = { shape = "cylinder", radius = 0.6, height = 0.45, color = { r = 255, g = 204, b = 0, a = 160 }, style = "objective", maxDistance = 45 },
    }, function()
        if not run or run.busy or run.working or LightRpUi.promptActive or LightRpUi.menuOpen then return end
        local now = Open77.time.monotonic()
        if now - lastPress < 0.75 then return end
        lastPress = now
        TriggerServerEvent(E.net.jobBegin, { id = run.id, index = run.index })
    end)
    track()
end
RegisterNetEvent(E.net.state, function(patch) if type(patch) == "table" and patch.jobRun then update(patch.jobRun) end end)

-- The tracker's live readout: metres to the current stop (on the ground plane),
-- whether the GPS really routes there, and the player menu key; sent on change.
-- A run whose waypoint vanished gets it back (a player waypoint elsewhere is kept).
CreateThread(function()
    local sent, sentKey, sentGps
    while true do
        Wait(250)
        local metres = false
        local objective = run and run.objective
        if objective and type(objective.position) == "table" and type(Open77.character) == "table" then
            local ok, state = pcall(Open77.character.state)
            local p = ok and type(state) == "table" and state.position
            if type(p) == "table" then
                local dx, dy = objective.position.x - p.x, objective.position.y - p.y
                metres = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
                if metres > 50 then metres = math.floor(metres / 10 + 0.5) * 10 end
            end
        end
        local on, absent = readGps()
        if gps.target and absent then setGps(false); on = readGps() end
        gps.on = on
        local binding = LightRpConfig.keys.menu
        local menuKey = binding and (Open77.input.keyFor(binding.id) or binding.key) or "F1"
        if metres ~= sent or menuKey ~= sentKey or on ~= sentGps then
            sent, sentKey, sentGps = metres, menuKey, on
            LightRpUi.send(E.page.jobRun, { distance = metres, menuKey = menuKey, gps = on })
        end
    end
end)
RegisterNetEvent(E.net.jobGps, track)
RegisterNetEvent(E.net.jobWork, function(p)
    if type(p) ~= "table" then return end
    if p.cancel then clearWork(); return end
    if not run or type(p.token) ~= "string" or type(p.durationMs) ~= "number" then return end
    clearWork(); workToken = p.token
    local token = p.token
    local id = LightRpActions.progress({ label = p.label, description = "Stay at the work point · Your route is kept if you stop",
        icon = p.icon, durationMs = p.durationMs, cancellable = true }, function(result)
        if workToken ~= token then return end
        workToken, actionId = nil, nil
        TriggerServerEvent(E.net.jobFinish, { token = token, status = result.status })
    end)
    actionId = id
    if not id then workToken = nil; TriggerServerEvent(E.net.jobFinish, { token = token, status = "cancelled" }) end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    clearWork(); LightRpInteract.setLocal("job.current", nil); clearGps()
end)
