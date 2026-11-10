-- The work order tracker and the pump approach hint on NativeUI (ui/native/workorder.rml).
--
-- The tracker is the page's JobRunHud.tsx, a dispatch sheet docked right: the next stop
-- and how far it is, every stop of the route (a courier's orders as pickup -> drop-off
-- pairs), the pay, the time left, and where the options are. It only displays: the server
-- owns the run (state key `jobRun`), client/core/job_runs.lua sends the live readout
-- (E.page.jobRun: metres to the stop, the player menu key, whether the GPS routes there).
-- Hidden as the page hid it: under a dialog or the player menu (the shell), while the
-- character's welcome is pending and during the tutorial's outro.
--
-- The hint is FuelApproach (features/fuel/FuelDialog.tsx): "lightrp:ui:fuel:state" with
-- phase "approach" from client/core/refueling.lua, any other phase takes it away.
local N = LightRpNative
local E = LightRpEvents
local W = {}
LightRpNativeWorkOrder = W

local KIND = {
    pickup = { tag = "PICK UP", icon = "package" },
    dropoff = { tag = "DELIVER", icon = "house" },
    work = { tag = "TASK", icon = "wrench" },
    lift = { tag = "ACCESS", icon = "arrow-down" },
    ["return"] = { tag = "RETURN", icon = "building-2" },
}

local icon = N.icon

-- A data-for array never shrinks: RmlUi reads the rows it removes once more and warns for
-- each binding. Rows past the real ones are blanks with gone = true (display: none).
local held = {}
local function hold(name, rows, blank)
    local n = math.max(held[name] or 0, #rows)
    held[name] = n
    for i = 1, #rows do rows[i].gone = false end
    for i = #rows + 1, n do
        local row = {}
        for key, value in pairs(blank) do row[key] = value end
        row.gone = true
        rows[i] = row
    end
    return rows
end

local function digits(v)
    v = tonumber(v) or 0
    if v == math.floor(v) and math.abs(v) < 9e15 then return ("%d"):format(v) end
    return tostring(v)
end
local function two(v) return ("%02d"):format(math.floor(tonumber(v) or 0)) end
--- mm:ss left, rounded up.
local function clock(ms)
    local s = math.max(0, math.ceil(ms / 1000))
    return ("%02d:%02d"):format(s // 60, s % 60)
end
--- bridge/money.ts formatMoney: "€$ 12,500".
local function money(amount, currency)
    amount = tonumber(amount) or 0
    if amount ~= amount or amount == math.huge or amount == -math.huge then amount = 0 end
    local n = amount < 0 and math.ceil(amount) or math.floor(amount)
    local text = ("%d"):format(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if text:sub(1, 1) == "," then text = text:sub(2) end
    return (n < 0 and "-" or "") .. (type(currency) == "string" and currency or "€$") .. " " .. text
end
W.money = money

local BLANK_CELL = { done = false, now = false }
local BLANK_ROW = { n = "", pair = false, live = false, done = false, aDone = false, aNow = false, a = "", bDone = false, bNow = false, b = "" }
local function stopState(stop) return type(stop) == "table" and stop.state or "todo" end
local function find(stops, kind, order)
    for _, s in ipairs(stops) do
        if type(s) == "table" and s.kind == kind and s.order == order then return s end
    end
    return nil
end

--- The tracker's values for a run, its live readout and the time left (ms, nil without a clock).
function W.view(run, live, left, currency)
    local stops = type(run.stops) == "table" and run.stops or {}
    local objective = type(run.objective) == "table" and run.objective or {}
    local kind = KIND[objective.kind or "work"] or KIND.work
    local index = tonumber(run.index) or 1
    local total = math.max(1, tonumber(run.total) or #stops)
    local current = stops[index]
    local order = type(current) == "table" and tonumber(current.order) or nil
    if order == 0 then order = nil end
    local distance = type(live.distance) == "number" and live.distance or nil
    local near = distance ~= nil and distance <= math.max(3, tonumber(objective.radius) or 3)
    local orders = tonumber(run.orders)
    if orders and orders < 1 then orders = nil end

    local cells, delivered = {}, 0
    for i, s in ipairs(stops) do
        local state = stopState(s)
        cells[i] = { done = state == "done", now = state == "now" }
        if type(s) == "table" and s.kind == "dropoff" and state == "done" then delivered = delivered + 1 end
    end
    -- a courier's orders: pickup -> drop-off on one line; other routes: their stops
    local rows, listHead = {}, nil
    if orders then
        for n = 1, math.floor(orders) do
            local pickup, dropoff = find(stops, "pickup", n), find(stops, "dropoff", n)
            local a, b = stopState(pickup), stopState(dropoff)
            rows[n] = {
                n = two(n), pair = true, live = a == "now" or b == "now", done = b == "done",
                aDone = a == "done", aNow = a == "now", a = pickup and tostring(pickup.place or "") or "—",
                bDone = b == "done", bNow = b == "now", b = dropoff and tostring(dropoff.place or "") or "—",
            }
        end
        listHead = ("%s CARRIED · %s/%s DELIVERED"):format(digits(run.carried), digits(delivered), digits(orders))
        if run.distanceKm and run.distanceKm ~= 0 then listHead = listHead .. " · " .. digits(run.distanceKm) .. " KM" end
    else
        for i, s in ipairs(stops) do
            local state = stopState(s)
            rows[i] = {
                n = two(i), pair = false, live = state == "now", done = state == "done",
                aDone = state == "done", aNow = state == "now", a = type(s) == "table" and tostring(s.place or "") or "",
                bDone = false, bNow = false, b = "",
            }
        end
        listHead = ("%s/%s DONE"):format(digits(index - 1), digits(total))
    end

    local duo = type(run.duo) == "table" and run.duo or nil
    local partner = duo and type(duo.partner) == "string" and duo.partner ~= "" and duo.partner or nil
    local status = run.busy and "Confirming with dispatch…" or (run.working and "Working · stay on the marker") or nil
    local menuKey = tostring(live.menuKey or "F1")
    return {
        near = near,
        job = tostring(run.jobLabel or run.label or ""),
        jobIcon = icon(run.icon or "briefcase"),
        hasTimer = left ~= nil, timer = left ~= nil and clock(left) or "", timerLow = left ~= nil and left < 180000,
        hasDuo = duo ~= nil,
        duo = "BIG CONTRACT" .. ((duo and duo.half and duo.half ~= "") and (" · HALF " .. tostring(duo.half)) or ""),
        hasPartner = partner ~= nil, partner = partner and ("WITH " .. partner) or "",
        kind = kind.tag .. (order and (" · " .. two(order)) or ""), kindIcon = icon(kind.icon),
        stop = "STOP " .. two(index), stopOf = "/" .. two(total),
        title = tostring(objective.place or objective.label or ""),
        press = kind.tag == "DELIVER" and "Hand over the order" or (kind.tag == "PICK UP" and "Collect the order" or "Start the task"),
        hasDistance = distance ~= nil,
        distance = distance == nil and "—" or (distance >= 1000 and ("%.1f"):format(distance / 1000) or digits(distance)),
        unit = distance ~= nil and distance >= 1000 and "KM" or "M",
        gps = live.gps == true, noRoute = "NO ROUTE · " .. menuKey .. " › GPS",
        hint = status or tostring(run.hint or ""),
        cells = hold("cells", cells, BLANK_CELL), hasList = #stops > 0, listHead = listHead, rows = hold("rows", rows, BLANK_ROW),
        reward = money(run.reward, currency), rewardWhen = index == total and "ON THIS DROP" or "ON THE LAST STOP",
        menuKey = menuKey,
    }
end

local function model()
    return {
        ready = false, hidden = true, quiet = false,
        icTimer = icon("timer"), icUsers = icon("users"), icNavigation = icon("navigation"),
        icCheck = icon("check"), icArrow = icon("arrow-right"), icFuel = icon("fuel"),
        on = false, near = false, job = "", jobIcon = icon("briefcase"),
        hasTimer = false, timer = "", timerLow = false,
        hasDuo = false, duo = "", hasPartner = false, partner = "",
        swapA = false, swapB = false,
        kind = "", kindIcon = icon("wrench"), stop = "", stopOf = "", title = "", press = "",
        hasDistance = false, distance = "—", unit = "M", gps = false, noRoute = "", hint = "",
        cells = {}, hasList = false, listHead = "", rows = {},
        reward = "", rewardWhen = "", menuKey = "F1",
        fuelOn = false, fuelLeft = "0", fuelLabel = "", fuelCancel = "X",
    }
end

local doc
local run = nil
local live = { distance = false, menuKey = "F1", gps = false }
local base, baseKey = nil, nil  -- the time left when the snapshot came: { at, ms }
local swapKey, swapFlip = nil, false
local fuel = nil                -- { label, deadline, cancelKey }
local ticking, epoch = false, 0

local function suppressed()
    local character, tutorial = N.state.character, N.state.tutorial
    if type(character) == "table" and character.welcomePending then return true end
    return type(tutorial) == "table" and tutorial.active == true and tutorial.step == "outro"
end
local function visible() return N.shell.ready and not N.shell.hidden and not N.shell.quiet end

-- Draws both panels; returns the ms until a clock changes, nil when nothing counts.
local function render()
    if not doc then return nil end
    local now, wait = N.now(), nil
    local match = N.activityPhase ~= nil and N.activityPhase ~= "lobby" -- client/native/activity.lua
    if run and not suppressed() and not match then
        local left = base and (base.ms - (now - base.at)) or nil
        local values = W.view(run, live, left, type(N.state.money) == "table" and N.state.money.currency or nil)
        values.on = true
        -- the next stop's block replays its entrance on every new stop
        local key = tostring(run.id) .. ":" .. tostring(run.index or 1)
        if key ~= swapKey then swapKey, swapFlip = key, not swapFlip end
        values.swapA, values.swapB = swapFlip, not swapFlip
        N.patch(doc, "wo", values)
        if left and left > 0 then wait = (left - 1) % 1000 + 1 end
    else
        N.patch(doc, "wo", { on = false })
    end
    if fuel then
        local left = fuel.deadline - now
        N.patch(doc, "wo", { fuelOn = true, fuelLabel = fuel.label, fuelCancel = fuel.cancelKey, fuelLeft = digits(math.max(0, math.ceil(left / 1000))) })
        if left > 0 then wait = math.min(wait or 1000, (left - 1) % 1000 + 1) end
    else
        N.patch(doc, "wo", { fuelOn = false })
    end
    if not wait or not visible() then return nil end
    return math.max(40, wait + 15)
end
-- One thread at most counts; a push restarts it so the next tick falls on its own second.
local function refresh()
    local wait = render()
    epoch = epoch + 1
    ticking = wait ~= nil
    if not wait then return end
    local mine = epoch
    CreateThread(function()
        while true do
            Wait(wait)
            if mine ~= epoch then return end
            wait = render()
            if not wait then ticking = false; return end
        end
    end)
end
W.refresh = refresh -- another document changed what this one may show (client/native/glue.lua)
-- Something that moves no clock changed: draw, and count again if nothing was counting.
local function redraw()
    if ticking then render() else refresh() end
end

N.onStart(function()
    local values = model()
    values.ready, values.hidden, values.quiet = N.shell.ready, N.shell.hidden, N.shell.quiet
    doc = N.create({ document = "ui/native/workorder.rml", zIndex = 20, models = { wo = values } })
    refresh()
end)
N.onShell(function(shell)
    N.patch(doc, "wo", { ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet })
    refresh()
end)

N.onState("jobRun", function(value)
    run = type(value) == "table" and value.active and value or nil
    -- the clock restarts from a snapshot that names another run, another stop or another time left
    local key = run and (tostring(run.id) .. "|" .. tostring(run.index) .. "|" .. tostring(run.expiresInMs)) or nil
    if key ~= baseKey then
        baseKey = key
        base = run and type(run.expiresInMs) == "number" and { at = N.now(), ms = run.expiresInMs } or nil
    end
    if not run then swapKey = nil end
    refresh()
end)
N.on(E.page.jobRun, function(payload)
    if type(payload) ~= "table" then return end
    for key, value in pairs(payload) do live[key] = value end
    redraw()
end)
N.onState("character", redraw)
N.onState("tutorial", redraw)
N.onState("money", redraw)

N.on("lightrp:ui:fuel:state", function(payload)
    if type(payload) == "table" and payload.phase == "approach" then
        fuel = { label = tostring(payload.label or ""), deadline = N.now() + (tonumber(payload.expiresMs) or 0), cancelKey = tostring(payload.cancelKey or "X") }
    else
        fuel = nil
    end
    refresh()
end)
