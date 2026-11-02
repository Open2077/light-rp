-- Inventory commands carry instance references. The server owns records, ammo
-- budgets and native projection; this bridge never grants a weapon locally.
local NET, PAGE = "op77_lightrp:armament", "lightrp:ui:armament"
local Ui = LightRpUi
local Armament = {}
LightRpArmamentClient = Armament
local cached, queue, draining = nil, {}, false
local sequence, lastSent = 0, -1000
-- Inventory is the weapon-selection owner. These claims do not affect native
-- Lua equip/setActive operations, firing or the independent safezone claims.
local function selectionControls(blocked)
    if not LightRpControlClaims then return end
    for _, action in ipairs({"WeaponWheel", "NextWeapon"}) do
        local ok, reason = LightRpControlClaims.set("inventory-weapons", action, blocked)
        if ok ~= true then Ui.log("inventory weapon control %s unavailable: %s", action, tostring(reason)) end
    end
end
local function syncControls(state)
    if not LightRpControlClaims then return end
    local equipped = state and (state.right or state.left)
    local blocked = state and (state.busy == true or (equipped and state.ready ~= true)) or false
    for _, action in ipairs({"Attack", "Reload", "Grenade"}) do
        LightRpControlClaims.set("armament", action, blocked == true)
    end
end
local function send(payload) Ui.send(PAGE, payload) end
local function forward(payload)
    if type(payload) ~= "table" or type(payload.operation) ~= "string" then return end
    if type(payload.request) ~= "string" then
        sequence = sequence + 1
        payload.request = "armament:" .. tostring(GetGameTimer()) .. ":" .. tostring(sequence)
    end
    if #queue >= 32 then
        send({kind="response", request=payload.request, ok=false, error="busy"})
        return
    end
    queue[#queue + 1] = payload
    if draining then return end
    draining = true
    CreateThread(function()
        while #queue > 0 do
            local delay = 180 - (GetGameTimer() - lastSent)
            if delay > 0 then Wait(delay) end
            local request = table.remove(queue, 1)
            lastSent = GetGameTimer()
            local ok, reason = TriggerServerEvent(NET, request)
            if ok == false then
                send({kind="response", request=request.request, ok=false, error=tostring(reason or "network_refused")})
            end
        end
        draining = false
    end)
end
RegisterNetEvent(NET, function(payload)
    if type(payload) ~= "table" then return end
    if payload.kind == "state" and type(payload.state) == "table" then cached = payload end
    if payload.kind == "response" and payload.ok and type(payload.data) == "table" and type(payload.data.state) == "table" then
        cached = {kind="state", state=payload.data.state}
    end
    selectionControls(true)
    if cached then syncControls(cached.state) end
    send(payload)
end)
function Armament.state() return cached and cached.state end
-- a fresh state push (the weapon wheel asks when it opens)
function Armament.refresh() forward({operation="state"}) end

function Armament.bind(page)
    selectionControls(true)
    page:on(PAGE, forward)
    page:on(LightRpEvents.page.ready, function()
        if cached then send(cached) end
        forward({operation="state"})
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then syncControls(nil); selectionControls(false) end
end)
