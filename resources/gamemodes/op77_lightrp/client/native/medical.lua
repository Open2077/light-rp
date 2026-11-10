-- The flatline cover and the downed screen on NativeUI (were
-- ui/src/features/medical/DeathCover.tsx and Medical.tsx). Both listen to the medical
-- channel "lightrp:ui:medical": { kind = "cover", down } from client/core/death_cover.lua
-- and { kind = "state", state } from client/core/medical.lua.
--
-- Two documents, at the page's z-order: the cover (28) under the activity / mission HUDs,
-- the downed screen (55) above them. Neither follows the shell: they cover the world.
--
-- The give-up buttons stay cursor driven. client/core/medical.lua hands the WebUI page the
-- cursor only (the keyboard stays with the game: the voice keys work while down); a
-- NativeUI focus lease would take the keyboard too, so this module takes no focus: it
-- reads the pointer the page holds (Open77.input.pointer, isDown("mouse1")) and hit-tests
-- its own buttons. The request is the one the page sent: { operation = "giveup" }.
local N = LightRpNative

local M = {}
LightRpNativeMedical = M

local PAGE = "lightrp:ui:medical"
local NET = "op77_lightrp:medical"
local COVER_OUT_MS = 1100
local BUTTONS = { ask = "#md-ask", confirm = "#md-confirm", keep = "#md-keep" }

local coverDoc, doc
local stage = "off"       -- off | down | out (the page's "in" and "held" differ only by time)
local stageAt = 0
local covered = false
local state, receivedAt = { downed = false }, 0
local confirm = false
local pressedOn

-- ---- pure helpers ----------------------------------------------------------------------
local function formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local digits = ("%d"):format(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. "€$ " .. digits
end

--- The texts of the downed screen for a medical state, `elapsed` ms after it arrived.
local function view(s, elapsed, confirming)
    local remaining = math.max(0, (tonumber(s.remainingMs) or 0) - math.max(0, elapsed))
    local seconds = math.ceil(remaining / 1000)
    local transferring, recovering = s.phase == "hospital", s.phase == "reviving"
    local canAsk = s.persisted and s.canGiveUp and true or false
    local question = "Leave the scene and wake up at the hospital?"
    if s.bill ~= nil then
        question = question .. ((tonumber(s.bill) or 0) > 0 and (" The clinic bills " .. formatMoney(s.bill) .. ".") or " The city covers this visit.")
    end
    return {
        downed = s.downed == true,
        title = transferring and "TRANSFER" or recovering and "RECOVERING" or "DEAD",
        timer = ("%d:%02d"):format(seconds // 60, seconds % 60),
        status = not s.persisted and "Saving medical state…" or transferring and "Transferring to hospital"
            or (recovering or s.receiving) and "Receiving medical assistance"
            or s.canGiveUp and "Hospital transfer available" or "Hospital transfer unlocks in",
        text = transferring and "Your hospital transfer is being synchronized."
            or recovering and "Your treatment is being confirmed. Stay connected."
            or s.receiving and "Someone is stabilizing you. Stay connected until treatment finishes."
            or "Another person can revive you with a Trauma Stabilization Kit.",
        hasError = type(s.error) == "string" and s.error ~= "", error = type(s.error) == "string" and s.error or "",
        askOn = canAsk and not confirming, confirmOn = canAsk and confirming, question = question,
    }
end
M.view, M.formatMoney = view, formatMoney

local function coverModel() return { shown = false, down = false, fresh = false, out = false, downed = false } end
local function model()
    local m = view({ downed = false }, 0, false)
    m.covered, m.hover, m.press = false, "", ""
    return m
end

-- ---- the cover -------------------------------------------------------------------------
local function renderCover()
    N.patch(coverDoc, "cover", {
        shown = stage ~= "off", down = stage == "down", out = stage == "out",
        downed = state.downed == true and stage ~= "out",
    })
end
local function setStage(next, fresh)
    stage, stageAt = next, N.now()
    if fresh ~= nil then N.patch(coverDoc, "cover", { fresh = fresh }) end
    renderCover()
end
local function onCover(down)
    covered = down
    N.patch(doc, "med", { covered = covered })
    if down then
        if stage == "off" then setStage("down", true)
        elseif stage == "out" then setStage("down", false) end -- down again mid-reboot: solid at once
        return
    end
    if stage == "off" then return end
    if stage ~= "out" then
        setStage("out")
        local at = stageAt
        CreateThread(function()
            Wait(COVER_OUT_MS)
            if stage == "out" and stageAt == at then setStage("off") end
        end)
    end
end

-- ---- the downed screen -----------------------------------------------------------------
local function render()
    if not doc then return end
    local values = view(state, N.now() - receivedAt, confirm)
    if not values.askOn and not values.confirmOn then values.hover, values.press = "", "" end
    N.patch(doc, "med", values)
end

local function act(name)
    if name == "ask" then confirm = true
    elseif name == "keep" then confirm = false
    elseif name == "confirm" then
        confirm = false
        TriggerServerEvent(NET, { operation = "giveup" })
    end
    render()
end

--- Which button is under the pointer the page holds (nil when none, or no pointer).
local function buttonUnderPointer(shown)
    local input = Open77.input
    if type(input) ~= "table" or type(input.pointer) ~= "function" then return nil end
    local ok, x, y = pcall(input.pointer)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    local okState, snapshot = pcall(doc.state, doc)
    if not okState or type(snapshot) ~= "table" or type(snapshot.rects) ~= "table" then return nil end
    local width, height = tonumber(snapshot.width) or 0, tonumber(snapshot.height) or 0
    if width <= 0 or height <= 0 then return nil end
    local px, py = x * width, y * height
    for name, selector in pairs(BUTTONS) do
        local r = shown[name] and snapshot.rects[selector]
        if type(r) == "table" and (r.width or 0) > 0 and (r.height or 0) > 0
            and px >= r.x and px <= r.x + r.width and py >= r.y and py <= r.y + r.height then
            return name
        end
    end
    return nil
end

local wasDown = false
local function pollButtons()
    local shown = {}
    local canAsk = state.downed == true and state.persisted and state.canGiveUp
    shown.ask = canAsk and not confirm
    shown.confirm, shown.keep = canAsk and confirm, canAsk and confirm
    if not canAsk then
        pressedOn, wasDown = nil, false
        return false
    end
    local over = buttonUnderPointer(shown)
    local down = false
    if type(Open77.input) == "table" and type(Open77.input.isDown) == "function" then
        local ok, held = pcall(Open77.input.isDown, "mouse1")
        down = ok and held == true
    end
    if down and not wasDown then pressedOn = over end
    if not down and wasDown then
        local target = pressedOn
        pressedOn = nil
        if target and target == over then
            wasDown = down
            act(target)
            return true
        end
    end
    wasDown = down
    N.patch(doc, "med", { hover = over or "", press = down and pressedOn == over and over or "" })
    return true
end

local function onMessage(p)
    if type(p) ~= "table" then return end
    if p.kind == "cover" then
        onCover(p.down == true)
    elseif p.kind == "state" and type(p.state) == "table" then
        state, receivedAt = p.state, N.now()
        if not state.downed then confirm = false end
        render()
        renderCover()
    end
end

N.onStart(function()
    coverDoc = N.create({ document = "ui/native/deathcover.rml", zIndex = 28, models = { cover = coverModel() } })
    doc = N.create({ document = "ui/native/medical.rml", zIndex = 55, models = { med = model() } })
    if doc then
        for _, selector in pairs(BUTTONS) do doc:watch(selector) end
        N.patch(doc, "med", { covered = covered })
        render()
        -- the countdown, every 250 ms as the page did
        CreateThread(function()
            while true do
                Wait(state.downed and 250 or 500)
                if state.downed then render() end
            end
        end)
        CreateThread(function()
            while true do
                local ok, active = pcall(pollButtons)
                if not ok then N.log("medical buttons failed: " .. tostring(active)) end
                Wait(ok and active and 33 or 250)
            end
        end)
    end
    if coverDoc then
        -- a cover that went down before the documents existed
        local core = LightRpDeathCover
        if stage == "off" and (covered or (core and core.down)) then setStage("down", false) else renderCover() end
    end
end)
N.on(PAGE, onMessage)
