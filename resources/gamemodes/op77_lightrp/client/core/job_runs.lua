local E = LightRpEvents
local run, key, blip, workToken, actionId, lastPress = nil, nil, nil, nil, nil, 0
local function track()
    if blip then
        local ok, why = LightRpInteract.trackBlip(blip)
        if not ok then LightRpUi.log("work order GPS: %s", tostring(why)) end
    end
end
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
    if not run then return end
    local objective = run.objective
    if type(objective) ~= "table" or type(objective.position) ~= "table" then return end
    local jobIcons = { sanitation = "trash-2", scrapper = "recycle", ac_cleaner = "fan" }
    local icon = objective.kind == "return" and "warehouse"
        or objective.kind == "lift" and "arrow-up-down" or jobIcons[run.job] or "map-pin"
    blip = LightRpInteract.setLocal("job.current", {
        position = objective.position, radius = objective.radius, prompt = objective.label,
        blip = { icon = icon, size = 48, sprite = "objective", routable = true, title = "Work order", description = objective.label },
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
    clearWork(); LightRpInteract.setLocal("job.current", nil)
end)
