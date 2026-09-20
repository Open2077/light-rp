-- Reusable client presentation for jobs. A successful QTE is NEVER authority
-- to grant an item/money: the job's server must validate its own transaction.
local E = LightRpEvents.page
local Actions = {}
LightRpActions = Actions
local resource = GetCurrentResourceName()
local active, sequence = nil, 0
local results, order = {}, {}
local function now() return GetGameTimer() end
local function owner()
    local name = GetInvokingResource()
    return name or resource, name and GetInvokingResourceGeneration() or Open77.resource.generation(resource)
end
local function finite(value, default, low, high)
    if value == nil then return default end
    if type(value) ~= "number" or value ~= value or value < low or value > high then return nil end
    return value
end
local function text(value, fallback, max)
    if value == nil then return fallback end
    if type(value) ~= "string" or #value > max then return nil end
    return value
end
local function key(value)
    if type(value) ~= "string" then return nil end
    value = value:upper()
    if value:match("^[A-Z0-9]$") or value == "SPACE" then return value end
    return nil
end
local presets = { easy = { 2600, .24 }, normal = { 2000, .16 }, hard = { 1450, .09 } }
local function normalize(kind, options)
    if type(options) ~= "table" then return nil, "invalid_options" end
    local d = { kind = kind, label = text(options.label, "Working", 100), description = text(options.description, "", 180),
        icon = text(options.icon, kind == "timing" and "zap" or "wrench", 40), style = options.style or "bar",
        key = key(options.key or "E"), cancellable = options.cancellable ~= false, release = options.release or "reset",
        durationMs = finite(options.durationMs, 5000, 250, 300000), steps = {}, maxMistakes = 0 }
    if not d.label or not d.description or not d.icon or not d.key or not d.durationMs
        or (d.style ~= "bar" and d.style ~= "ring") or (d.release ~= "reset" and d.release ~= "cancel") then return nil, "invalid_options" end
    if options.onFinish ~= nil and (type(options.onFinish) ~= "string" or #options.onFinish < 1 or #options.onFinish > 100) then return nil, "invalid_callback_export" end
    local budget = d.durationMs + 400
    if kind == "timing" then
        local list = options.steps or { "easy", "normal", "hard" }
        if type(list) ~= "table" or #list < 1 or #list > 12 then return nil, "invalid_steps" end
        budget = 400
        for _, raw in ipairs(list) do
            local item = type(raw) == "string" and { difficulty = raw } or raw
            if type(item) ~= "table" then return nil, "invalid_step" end
            local preset = presets[item.difficulty or "normal"]
            if not preset then return nil, "invalid_difficulty" end
            local duration = finite(item.durationMs, preset[1], 700, 10000)
            local width = finite(item.zoneWidth, preset[2], .05, .5)
            local input = key(item.key or d.key)
            if not duration or not width or not input then return nil, "invalid_step" end
            local start = finite(item.zoneStart, .28 + math.random() * (.6 - width), .1, .9 - width)
            if not start then return nil, "invalid_zone" end
            d.steps[#d.steps + 1] = { key = input, durationMs = duration, zoneStart = start, zoneWidth = width }
            budget = budget + duration + 450
        end
        d.maxMistakes = finite(options.maxMistakes, 0, 0, #list - 1)
        if not d.maxMistakes or d.maxMistakes % 1 ~= 0 then return nil, "invalid_mistakes" end
    end
    d.timeoutMs = finite(options.timeoutMs, kind == "hold" and math.min(600000, math.max(15000, d.durationMs * 3 + 400)) or budget + 1500, budget, 600000)
    if not d.timeoutMs then return nil, "invalid_timeout" end
    return d
end

local function finish(status, reason, report, notify)
    local a = active
    if not a then return false end
    active = nil -- release before callbacks: a job may start its next step there
    local result = { id = a.definition.id, status = status, reason = reason, elapsedMs = math.max(0, now() - (a.startedAt or a.createdAt)),
        hits = math.floor(finite(report and report.hits, 0, 0, #a.definition.steps) or 0),
        mistakes = math.floor(finite(report and report.mistakes, 0, 0, #a.definition.steps) or 0),
        score = math.floor(finite(report and report.score, 0, 0, 100) or 0) }
    results[result.id] = { owner = a.owner, generation = a.generation, value = result }
    order[#order + 1] = result.id
    if #order > 32 then results[table.remove(order, 1)] = nil end
    LightRpUi.releaseActionFocus()
    LightRpUi.send(E.actionFinish, result)
    if notify ~= false then
        if a.callback then
            local ok, err = pcall(a.callback, result)
            if not ok then LightRpUi.log("action callback failed: %s", tostring(err)) end
        elseif a.onFinish and GetResourceState(a.owner) == "running" and Open77.resource.generation(a.owner) == a.generation then
            local promise, err = Open77.exports.call(a.owner, a.onFinish, result)
            if not promise then LightRpUi.log("action result callback refused: %s", tostring(err)) end
        end
        TriggerEvent("lightrp:action:finished", result)
    end
    return true
end

function Actions.interrupt(reason) return finish("cancelled", reason or "interrupted") end
local function start(kind, options, callback)
    if active then return nil, "busy" end
    if callback ~= nil and type(callback) ~= "function" then return nil, "invalid_callback" end
    if not LightRpUi.ready or not LightRpUi.page then return nil, "ui_unavailable" end
    if not LightRpUi.characterReady then return nil, "character_not_ready" end
    if LightRpUi.menuOpen or LightRpUi.promptActive then return nil, "ui_busy" end
    for _, open in pairs(LightRpUi.dialogs) do if open then return nil, "ui_busy" end end
    local d, err = normalize(kind, options)
    if not d then return nil, err end
    local state = Open77.character.state()
    if not state or state.alive == false then return nil, "character_not_ready" end
    local provider, generation = owner()
    sequence = sequence + 1
    d.id = tostring(Open77.resource.generation(resource)) .. ":" .. tostring(sequence)
    local keys = { "ESCAPE" }
    -- With full keyboard focus all gameplay keys are already withheld. The
    -- native selective API only accepts navigation keys (not E/R/etc.). Only
    -- request extra consumption in keep-input mode, and fail closed if a key
    -- is unsupported rather than leaking it into gameplay.
    if options.allowMovement == true then
        if kind == "hold" then keys[#keys + 1] = d.key end
        if kind == "timing" then for _, s in ipairs(d.steps) do keys[#keys + 1] = s.key end end
    end
    local focused, why = LightRpUi.claimActionFocus(keys, options.allowMovement == true)
    if not focused then return nil, why or "focus_unavailable" end
    active = { definition = d, owner = provider, generation = generation, callback = callback, onFinish = options.onFinish, createdAt = now() }
    local sent, sendError = LightRpUi.send(E.actionStart, d)
    if sent == false then active = nil; LightRpUi.releaseActionFocus(); return nil, sendError or "ui_unavailable" end
    return d.id
end
function Actions.progress(options, callback) return start("progress", options, callback) end
function Actions.hold(options, callback) return start("hold", options, callback) end
function Actions.skillCheck(options, callback) return start("timing", options, callback) end
function Actions.cancel(id)
    local provider, generation = owner()
    if not active or active.definition.id ~= id then return false, "not_active" end
    if active.owner ~= provider or active.generation ~= generation then return false, "not_owner" end
    return finish("cancelled", "cancelled") -- provider can always cancel, even cancellable=false
end
function Actions.isActive() return active ~= nil end
function Actions.result(id)
    local entry = results[id]
    local provider, generation = owner()
    if not entry then return nil, "result_unavailable" end
    if entry.owner ~= provider or entry.generation ~= generation then return nil, "not_owner" end
    -- Copy: an internal module must not mutate the retained result.
    local copy = {}; for k, v in pairs(entry.value) do copy[k] = v end; return copy
end
function Actions.bind(page)
    page:on(E.actionStarted, function(p)
        if active and type(p) == "table" and p.id == active.definition.id and not active.startedAt then active.startedAt = now() end
    end)
    page:on(E.actionResult, function(p)
        if not active or type(p) ~= "table" or p.id ~= active.definition.id or not active.startedAt then return end
        if p.status ~= "success" and p.status ~= "failed" and p.status ~= "cancelled" then return end
        if p.status == "cancelled" and p.reason == "cancelled" and not active.definition.cancellable then return end
        if p.status == "success" and active.definition.kind ~= "timing" and now() - active.startedAt < active.definition.durationMs then return end
        local reasons = { completed = true, cancelled = true, released = true, too_early = true, missed = true, timeout = true, focus_lost = true, interrupted = true, dead = true }
        if not reasons[p.reason] then return end
        finish(p.status, p.reason, p)
    end)
end

CreateThread(function()
    while true do
        Wait(100)
        if active then
            local a = active
            if GetResourceState(a.owner) ~= "running" or Open77.resource.generation(a.owner) ~= a.generation then finish("cancelled", "owner_stopped", nil, false)
            elseif not a.startedAt and now() - a.createdAt > 3000 then finish("failed", "ui_timeout")
            elseif a.startedAt and now() - a.startedAt > a.definition.timeoutMs + 1500 then finish("failed", "ui_timeout")
            else
                local state = Open77.character.state()
                if not state or state.alive == false then finish("cancelled", "dead") end
            end
        end
    end
end)
AddEventHandler("onClientResourceStop", function(name)
    if active and (name == resource or name == active.owner) then finish("cancelled", "owner_stopped", nil, false) end
end)
exports("ActionProgress", Actions.progress)
exports("ActionHold", Actions.hold)
exports("ActionSkillCheck", Actions.skillCheck)
exports("ActionCancel", Actions.cancel)
exports("ActionIsActive", Actions.isActive)
exports("ActionResult", Actions.result)

-- Server permits this event only through the restricted /lightrp.uitest command.
-- It intentionally creates no items, payouts, cooldowns or persistent state.
RegisterNetEvent(LightRpEvents.net.actionDemo, function(mode)
    if mode == "cancel" then Actions.interrupt("cancelled"); return end
    local options = { label = "Prepare the equipment", description = "A reusable interaction for your next job.", durationMs = 5000 }
    local fn = Actions.progress
    if mode == "circle" then options.style = "ring"
    elseif mode == "hold" then fn = Actions.hold; options.style = "ring"; options.label = "Secure the connection"
    elseif mode == "timing" or mode == "sequence" then
        fn = Actions.skillCheck; options.label = "Calibrate the relay"; options.description = "Stop the cursor inside the yellow zone."
        options.steps = mode == "timing" and { "easy" } or { { difficulty = "easy", key = "E" }, { difficulty = "normal", key = "R" }, { difficulty = "hard", key = "E" } }
    elseif mode ~= "progress" then return end
    local id, err = fn(options, function(r) LightRpUi.log("action demo %s: %s (%s), score=%d", r.id, r.status, r.reason, r.score) end)
    if not id then LightRpUi.send(E.notice, { kind = "warning", title = "Action unavailable", body = err, durationMs = 3000 }) end
end)
