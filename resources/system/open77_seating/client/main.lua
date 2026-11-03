-- =============================================================================
-- open77_seating -- client/main.lua
-- =============================================================================
-- Presentation only. This half:
--   * turns the server's short list of nearby seats (at most three within
--     3 m for cards, at most eight within 3.5 m for the menu; chosen and
--     filtered on the server) into open77_interactions prompts and/or ALT +
--     click actions of open77_contextmenu (the server's `ui` mode), and a
--     chosen prompt or clicked seat into the minimum intent (a furniture id);
--   * offers a rebindable "stand up" key while the server says the player
--     is seated;
--   * says why a request was refused.
--
-- It never decides anything: no pose, no distance, no occupancy and no world
-- query (a world query costs hundreds of milliseconds in a crowd). It holds no
-- control or camera claim either: the workspot holds the body while it plays
-- and the platform restores the view when the playback ends.
-- =============================================================================

local M = Open77SeatingModel
local RESOURCE = GetCurrentResourceName()
local STAND_KEY_ID = "open77_seating_stand"

local state = {
    generation = nil,
    ui = "prompts",        -- the server's mode: prompts | menu | both
    seats = {},            -- [id] = seat as sent by the server
    list = {},             -- the same seats, in the server's order (menu matching)
    live = {},             -- [id] = { handle, signature }
    menu = { registered = false, retryIn = 0 },
    seated = false,
    running = true,
    dirty = false,
}

local function interactions(name, ...)
    local promise, reason = Open77.exports.call("open77_interactions", name, ...)
    if not promise then return nil, reason end
    return promise:await()
end

local function notify(text)
    if Open77.hud and Open77.hud.notify then
        pcall(Open77.hud.notify, text, { replace = true })   -- generic: the vanilla action_blocked preset drops the text
    else
        print("[seating] " .. text)
    end
end

-- A message from another server generation: what this client held is void.
local function accept(payload)
    if type(payload) ~= "table" then return false end
    if state.generation ~= nil and payload.generation ~= state.generation then
        if type(payload.generation) == "number" and type(state.generation) == "number" and
            payload.generation < state.generation then
            return false
        end
        state.seats, state.list, state.seated, state.dirty = {}, {}, false, true
    end
    state.generation = payload.generation
    return true
end

local REFUSALS = {
    seat_taken = "Someone is already sitting there.",
    target_claimed = "This seat is in use.",
    npc_occupied = "Someone is already sitting there.",
    too_far = "Too far away.",
    already_seated = "You are already seated.",
    not_seated = "You are not seated.",
    actor_busy = "Finish what you are doing first.",
    in_combat = "Not while fighting.",
    player_in_vehicle = "Not from a vehicle.",
    no_playable_pose = "There is no free seat here.",
    approach_blocked = "Something is in the way.",
    approach_failed = "You cannot get there.",
    indexing = "Seats are not ready yet.",
}

RegisterNetEvent("open77:seating:refused", function(payload)
    if not accept(payload) then return end
    local reason = tostring(payload.reason)
    notify(REFUSALS[reason] or ("Refused: " .. reason))
end)

RegisterNetEvent("open77:seating:state", function(payload)
    if not accept(payload) then return end
    local was = state.seated
    state.seated = payload.seated == true
    if state.seated then
        state.seats, state.list, state.dirty = {}, {}, true
        if not was then
            local key = Open77.input and Open77.input.keyFor and Open77.input.keyFor(STAND_KEY_ID) or "X"
            notify(("Press %s to stand up"):format(tostring(key or "X")))
        end
    elseif was and payload.reason ~= nil and payload.reason ~= "stood" and payload.reason ~= "cancelled_by_player" then
        notify("You stood up: " .. tostring(payload.reason))
    end
end)

RegisterNetEvent("open77:seating:seats", function(payload)
    if not accept(payload) then return end
    local seats, list = {}, {}
    for _, seat in ipairs(type(payload.seats) == "table" and payload.seats or {}) do
        if type(seat) == "table" and type(seat.id) == "string" and type(seat.position) == "table" then
            seats[seat.id] = seat
            list[#list + 1] = seat
        end
    end
    if M.UI_MODES[payload.ui] then state.ui = payload.ui end
    state.seats, state.list, state.dirty = seats, list, true
end)

-- ---------------------------------------------------------------------------
-- Seats -> prompts (at most the three the server sent; nothing is ranked here)
-- ---------------------------------------------------------------------------
local function signature(seat)
    local p = seat.position
    return table.concat({ seat.id, tostring(p.x), tostring(p.y), tostring(p.z), tostring(seat.label) }, "|")
end

-- The card is lifted above the seat and live whenever the player is in reach and the card is
-- on screen, as open77_actions does: open77_interactions otherwise requires the crosshair on
-- the card (requireLookAt), and a card at mattress or seat height sits at the bottom of the
-- screen where E never reached it (a bed prompt was drawn, and E did nothing). The reach is
-- measured to the lifted point, hence the hypotenuse.
local PROMPT_LIFT = 0.8
local PROMPT_REACH = 2.0

local function promptDefinition(seat)
    return {
        id = ("seat:" .. seat.id):sub(1, 96),
        position = seat.position, offset = { x = 0.0, y = 0.0, z = PROMPT_LIFT },
        distance = math.sqrt(PROMPT_REACH * PROMPT_REACH + PROMPT_LIFT * PROMPT_LIFT),
        markerDistance = 4.0, marker = "dot", requireLookAt = false,
        priority = 5,
        choices = { {
            id = "sit", label = seat.label or "Sit", key = "E",
            event = "open77_seating:choice", data = { furniture = seat.id },
        } },
    }
end

local function sync()
    if not state.dirty then return end
    state.dirty = false
    local wanted = (state.seated or not M.uiPrompts(state.ui)) and {} or state.seats
    for id, entry in pairs(state.live) do
        local seat = wanted[id]
        if seat == nil or signature(seat) ~= entry.signature then
            state.live[id] = nil
            if entry.handle then interactions("remove", entry.handle) end
        end
    end
    for id, seat in pairs(wanted) do
        if state.live[id] == nil then
            local answer = interactions("create", promptDefinition(seat))
            if type(answer) == "table" and answer.ok then
                state.live[id] = { handle = answer.handle, signature = signature(seat) }
            end
        end
    end
end

AddEventHandler("open77_seating:choice", function(payload)
    if type(payload) ~= "table" or payload.owner ~= RESOURCE or type(payload.data) ~= "table" then return end
    if state.seated then return end
    TriggerServerEvent("open77:seating:sit", payload.data.furniture)
end)

-- ---------------------------------------------------------------------------
-- ALT + click (open77_contextmenu): click the chair, the bench, the wall
-- ---------------------------------------------------------------------------
-- The menu is optional: no manifest dependency (a server without it keeps the
-- cards), registration retried until open77_contextmenu answers. A click is
-- matched against the seats the server sent (M.menuMatch); the server
-- re-checks reach, occupancy and the player exactly as for a card.
local MENU_TYPES = { "world", "prop", "object", "device", "item" }
local MENU_RETRY_TICKS = 8 -- x 250 ms

local function menu(name, ...)
    local promise, reason = Open77.exports.call("open77_contextmenu", name, ...)
    if not promise then return nil, reason end
    return promise:await()
end

local function fromMenu()
    return GetInvokingResource == nil or GetInvokingResource() == "open77_contextmenu"
end

-- The seat a menu context designates, for the action's posture.
local function seatFor(ctx)
    if not fromMenu() or state.seated or not M.uiMenu(state.ui) then return nil end
    if type(ctx) ~= "table" or ctx.hasSurface ~= true or type(ctx.position) ~= "table" then return nil end
    local data = type(ctx.action) == "table" and type(ctx.action.data) == "table" and ctx.action.data or {}
    return M.menuMatch(state.list, ctx.position, data.posture)
end

exports("seatingMenuCan", function(ctx)
    return seatFor(ctx) ~= nil
end)

-- The clicked point travels with the seat: on a bench row the server sits the
-- body there (when the hit is on the seat, not the floor), off anyone in the way.
exports("seatingMenuSelect", function(ctx)
    local seat = seatFor(ctx)
    if seat == nil then return false end
    local p = ctx.position
    TriggerServerEvent("open77:seating:sit", seat.id, { x = p.x, y = p.y, z = p.z })
    return true
end)

exports("seatingMenuSeated", function()
    return fromMenu() and state.seated == true
end)

exports("seatingMenuStand", function()
    if not fromMenu() or not state.seated then return false end
    TriggerServerEvent("open77:seating:stand")
    return true
end)

local MENU_ACTIONS = {
    { id = "seat_sit", label = "Sit", icon = "interact", data = { posture = "sit" } },
    { id = "seat_lean", label = "Lean", icon = "interact", data = { posture = "lean" } },
    { id = "seat_lie", label = "Lie down", icon = "interact", data = { posture = "lie" } },
}

local function registerMenu()
    local definitions = {}
    for index, action in ipairs(MENU_ACTIONS) do
        definitions[index] = {
            id = action.id, label = action.label, icon = action.icon, group = "Seat",
            types = MENU_TYPES, distance = 4.0, order = -20,
            canInteract = "seatingMenuCan", onSelect = "seatingMenuSelect", data = action.data,
        }
    end
    local tokens, why = menu("registerMany", definitions)
    if type(tokens) ~= "table" then return nil, why end
    local token, standWhy = menu("registerSelf", {
        id = "seat_stand", label = "Stand up", icon = "person", group = "Seat", order = -20,
        canInteract = "seatingMenuSeated", onSelect = "seatingMenuStand",
    })
    if token == nil then return nil, standWhy end
    return true
end

local function menuSync()
    local m = state.menu
    if M.uiMenu(state.ui) then
        if m.registered then return end
        if m.retryIn > 0 then m.retryIn = m.retryIn - 1; return end
        local ok, why = registerMenu()
        if ok then
            m.registered = true
        else
            m.retryIn = MENU_RETRY_TICKS
            if why ~= m.lastWhy then print("[seating] context menu unavailable: " .. tostring(why)) end
            m.lastWhy = why
        end
    elseif m.registered then
        menu("clear")
        m.registered, m.retryIn = false, 0
    end
end

-- ---------------------------------------------------------------------------
-- The stand-up key (rebindable from Pause -> Settings -> KEY BINDINGS)
-- ---------------------------------------------------------------------------
pcall(Open77.input.registerKeyMapping, {
    id = STAND_KEY_ID, name = "Stand up from a seat", key = "X",
    onPressed = function()
        if state.seated then TriggerServerEvent("open77:seating:stand") end
    end,
})

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
AddEventHandler("onClientResourceStop", function(name)
    if name ~= RESOURCE then return end
    state.running = false
    pcall(Open77.exports.callSync, "open77_interactions", "clear")
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent("open77:seating:sync")
    while state.running do
        local ok, err = pcall(sync)
        if not ok then print("[seating] prompt sync raised: " .. tostring(err)) end
        ok, err = pcall(menuSync)
        if not ok then print("[seating] menu sync raised: " .. tostring(err)) end
        Wait(250)
    end
end)
