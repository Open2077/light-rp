-- The notice lane on NativeUI (ui/native/notices.rml), the page's NoticeLane.tsx: server
-- notices (`lightrp:ui:notice`) and action results (`lightrp:ui:result`), FIFO, six deep,
-- each with its own lifetime bar; wiped in, wiped out, then removed.
--
-- The store's rules (ui/src/state/store.ts, App.tsx):
--   * a notice: { id?, kind = "info", title?, body?, source?, durationMs = 8000 }
--   * a result: success, or error titled DENIED, source LIGHT RP, 6 s; a successful
--     "dailies.claim" shows nothing (dailies.lua already sent the "+€$ N" money notice)
--   * a seventh notice drops the oldest at once
--   * the lane shows whatever the HUD does (never bound to the shell: it stays over a
--     dialog), except during the character creation, a first-day cinematic (intro,
--     dialogue, outro), the vehicle workshop and the arrival tour; notices keep ageing
--     meanwhile, as they did.
-- Other native modules: LightRpNativeNotices.push(notice), .suppress(name, on),
-- .setLeft(dp | nil) (the crew frame steps the lane to its right).
local N = LightRpNative
local E = LightRpEvents
local M = {}
LightRpNativeNotices = M

local KINDS = {
    info = { icon = "info", tag = "SYS" }, success = { icon = "check-check", tag = "OK" },
    warning = { icon = "triangle-alert", tag = "WARN" }, error = { icon = "octagon-alert", tag = "FAIL" },
    police = { icon = "siren", tag = "DISPATCH" }, money = { icon = "banknote", tag = "BANK" },
    item = { icon = "package", tag = "INVENTORY" }, message = { icon = "message-square", tag = "PHONE" },
    contract = { icon = "file-text", tag = "CONTRACT" }, staff = { icon = "shield-alert", tag = "STAFF" },
}
M.KINDS = KINDS
local MAX = 6            -- pushNotice: the last five and the new one
local WIDTH = 320        -- the card, dp
local WIPE = 0.18        -- --dur-base
local REMOVE_MS = 200    -- setTimeout(remove, 200) after the dismissal
local EASE_MECH = "cubic-bezier(.85,0,.15,1)"

local doc
local list = {}          -- oldest first: { el, kind, title, body, source, createdAt, durationMs, dismissing, removeAt, mounted, click }
local seq = 0
local ticking = false
local suppressed = {}    -- name -> true (the arrival tour)
local lane = { off = false, tour = false, left = nil }

local function esc(s)
    -- markup, and "{{" which RmlUi reads as the start of a data binding in any text
    return (tostring(s == nil and "" or s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
        :gsub("{{", "{ {"):gsub("}}", "} }"))
end
local function text(v)
    if v == nil or v == false then return nil end
    v = tostring(v)
    return v ~= "" and v or nil
end

--- The store's notice from a page payload (pure).
function M.normalize(n)
    n = type(n) == "table" and n or {}
    local kind = type(n.kind) == "string" and KINDS[n.kind] and n.kind or "info"
    local duration = tonumber(n.durationMs)
    return { kind = kind, title = text(n.title), body = text(n.body), source = text(n.source) or KINDS[kind].tag,
        durationMs = duration and duration > 0 and duration or 8000 }
end

--- The notice a command result becomes, or nil (pure).
function M.fromResult(r)
    if type(r) ~= "table" then return nil end
    local ok = r.ok and true or false
    if ok and r.action == "dailies.claim" then return nil end
    return { kind = ok and "success" or "error", title = (not ok) and "DENIED" or nil, body = r.text, source = "LIGHT RP", durationMs = 6000 }
end

--- The card's RML (pure).
function M.card(entry)
    local out = {
        '<div id="', entry.el, '" class="nt nt-', entry.kind, '"><div class="nt-card">',
        '<div class="nt-bg-top"></div><path class="nt-bg-tri" view-box="0 0 14 14" d="M0 0L14 14H0Z"/><div class="nt-bg-body"></div>',
        '<div class="nt-rule"></div><div class="nt-body"><div class="nt-head">',
        '<path class="ic nt-icon" view-box="0 0 24 24" d="', esc(N.icon(KINDS[entry.kind].icon)), '"/>',
        '<span class="nt-source">', esc(entry.source), '</span><span class="grow"></span>',
        '<div class="nt-close"><path class="ic" view-box="0 0 24 24" d="', esc(N.icon("x")), '"/></div></div>',
    }
    if entry.title then out[#out + 1] = '<div class="nt-title">' .. esc(entry.title) .. '</div>' end
    if entry.body then out[#out + 1] = '<div class="nt-text">' .. esc(entry.body) .. '</div>' end
    out[#out + 1] = '</div><div class="nt-life"></div></div></div>'
    return table.concat(out)
end

--- May the lane show? (pure: the merged state and the two outside flags)
function M.laneOff(state, customization)
    if customization then return true end
    state = type(state) == "table" and state or {}
    local connected = next(state) ~= nil
    local character = state.character
    local status = type(character) == "table" and character.status or "draft"
    if connected and status ~= "active" then return true end
    local t = state.tutorial
    if type(t) == "table" and t.active then
        local dialogue = t.dialogue ~= nil and t.dialogue ~= false and t.dialogue ~= ""
        if t.step == "intro" or t.step == "outro" or dialogue then return true end
    end
    return false
end

local function customizing()
    local c = LightRpVehicleCustomizationClient
    if type(c) ~= "table" or type(c.isActive) ~= "function" then return false end
    local ok, active = pcall(c.isActive)
    return ok and active == true
end

local function syncLane()
    if not doc then return end
    local off = M.laneOff(N.state, customizing())
    -- under a loading screen (the zone cover is a WebUI page, below every NativeUI
    -- document): the page's notices sat under it, so the lane waits it out
    local ui = LightRpUi
    local loading = ui and type(ui.loadingScreen) == "function" and ui.loadingScreen() == true
    local tour = next(suppressed) ~= nil or loading
    if off ~= lane.off then lane.off = off; doc:class("#lane", "is-off", off) end
    if tour ~= lane.tour then lane.tour = tour; doc:class("#lane", "is-tour", tour) end
end

local dismiss

local function mount(entry)
    if not doc or entry.mounted then return end
    local left = entry.durationMs - (N.now() - entry.createdAt)
    if left <= 0 then return end
    entry.mounted = true
    local sel = "#" .. entry.el
    doc:batch(function()
        doc:insert("#lane", M.card(entry), "end")
        -- o77-wipe-in: clip-path inset(0 100% 0 0) -> inset(0), --dur-base, --ease-mech
        doc:animate(sel, { from = { x = -WIDTH }, to = { x = 0 }, duration = WIPE, easing = EASE_MECH })
        doc:animate(sel .. " .nt-card", { from = { x = WIDTH }, to = { x = 0 }, duration = WIPE, easing = EASE_MECH })
        -- the life bar: width = remaining, stepped every 100 ms with a linear transition in the page
        doc:animate(sel .. " .nt-life", { from = { width = ("%.2f%%"):format(N.clamp(left / entry.durationMs, 0, 1) * 100) },
            to = { width = "0%" }, duration = left / 1000, easing = "linear" })
    end)
    entry.click = doc:on("click", sel .. " .nt-close", function() dismiss(entry) end)
end

local function unmount(entry)
    if not entry.mounted then return end
    entry.mounted = false
    if not doc then return end
    if entry.click then pcall(doc.off, doc, entry.click); entry.click = nil end
    doc:remove("#" .. entry.el)
end

local function drop(index)
    local entry = table.remove(list, index)
    if entry then unmount(entry) end
end

-- o77-wipe-out (clip-path inset(0 0 0 100%), opacity 0, --dur-base), removed 200 ms later
dismiss = function(entry)
    if entry.dismissing then return end
    entry.dismissing = true
    entry.removeAt = N.now() + REMOVE_MS
    if doc and entry.mounted then
        local sel = "#" .. entry.el
        doc:batch(function()
            doc:animate(sel, { to = { x = WIDTH, opacity = 0 }, duration = WIPE, easing = EASE_MECH })
            doc:animate(sel .. " .nt-card", { to = { x = -WIDTH }, duration = WIPE, easing = EASE_MECH })
        end)
    end
end

local function tick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while #list > 0 do
            local now = N.now()
            for i = #list, 1, -1 do
                local entry = list[i]
                if entry.dismissing then
                    if now >= entry.removeAt then drop(i) end
                elseif now - entry.createdAt >= entry.durationMs then
                    dismiss(entry)
                end
            end
            syncLane()
            Wait(100)
        end
        ticking = false
    end)
end

--- Adds a notice ({ kind, title, body, source, durationMs }), as the store's pushNotice.
function M.push(notice)
    local entry = M.normalize(notice)
    seq = seq + 1
    entry.el = "nt" .. seq
    entry.createdAt = N.now()
    while #list >= MAX do drop(1) end
    list[#list + 1] = entry
    syncLane()
    mount(entry)
    tick()
    return entry.el
end

--- Another native module hides the lane while it plays (the arrival tour).
function M.suppress(name, on)
    suppressed[tostring(name)] = on == true or nil
    syncLane()
end

--- The lane's left edge in dp (nil: the HUD's safe margin). The page moved the lane right of
--- the crew frame when the two met; the crew document may do the same through this.
function M.setLeft(dp)
    dp = tonumber(dp)
    if dp == lane.left then return end
    lane.left = dp
    if doc then doc:style("#lane", "left", ("%ddp"):format(dp and math.floor(dp + 0.5) or 32)) end
end

function M.count() return #list end

N.onStart(function()
    doc = N.create({ document = "ui/native/notices.rml", zIndex = 60 })
    if not doc then return end
    lane.off, lane.tour = false, false
    local function restore()
        -- a reloaded document is empty: the live notices come back, without their age
        lane.off, lane.tour = false, false
        for _, entry in ipairs(list) do entry.mounted = false; entry.click = nil end
        if lane.left then doc:style("#lane", "left", ("%ddp"):format(math.floor(lane.left + 0.5))) end
        syncLane()
        for _, entry in ipairs(list) do if not entry.dismissing then mount(entry) end end
    end
    doc:onEvent("reloaded", restore)
    restore()
    if #list > 0 then tick() end
end)

N.on(E.page.notice, function(n) M.push(n) end)
N.on(E.page.result, function(r)
    local notice = M.fromResult(r)
    if notice then M.push(notice) end
end)
N.onState("character", syncLane)
N.onState("tutorial", syncLane)
