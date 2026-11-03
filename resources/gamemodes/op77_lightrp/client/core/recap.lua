-- The end-of-match recap (server/modules/recap.lua): the server sends it once the
-- player is free, alive and back in the city; this side waits for the screen to be
-- clear too before the page opens it -- no loading screen or fade cover, a living
-- body on its feet, no character creator, no F1 menu, no other dialog, no action bar.
-- F1 > Last match (recap.open) asks for it again: shown at once (`reopened`).
-- The payload arrives as a plain or a latent event under the same name.
local E = LightRpEvents
local Ui = LightRpUi
local Recap = { queued = nil, waitedMs = 0, clearMs = 0 }
LightRpRecap = Recap

local PERIOD_MS = 250
local GIVE_UP_MS = 60000 -- the screen never cleared: F1 still has it, nothing pops up late
local CLEAR_MS = 750     -- clear this long in a row (a fade or a cover can start right after a teleport)

local function standing()
    if type(Open77) ~= "table" or type(Open77.character) ~= "table" or type(Open77.character.state) ~= "function" then return true end
    local ok, state = pcall(Open77.character.state)
    if not ok or type(state) ~= "table" then return false end
    return state.alive ~= false
end

-- Nothing else on screen, the body on its feet.
function Recap.clear()
    if not Ui.ready or not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.actionFocus then return false end
    if Ui.loadingScreen() then return false end
    for _, open in pairs(Ui.dialogs or {}) do if open then return false end end
    if LightRpMedical and LightRpMedical.isActive() then return false end
    if LightRpActions and LightRpActions.isActive() then return false end
    return standing()
end

local function show(payload)
    payload.kind = "recap"
    Ui.send(E.page.dialog, payload)
end

function Recap.receive(payload)
    if type(payload) ~= "table" or type(payload.rows) ~= "table" then return end
    if payload.reopened == true then
        -- asked from F1 or /recap: the menu closes as it asks, the recap opens now
        Recap.queued = nil
        show(payload)
        return
    end
    -- the newest match replaces one still waiting
    Recap.queued, Recap.waitedMs, Recap.clearMs = payload, 0, 0
end
RegisterNetEvent(E.net.recap, Recap.receive)

function Recap.tick(elapsedMs)
    local payload = Recap.queued
    if not payload then return end
    Recap.waitedMs = Recap.waitedMs + (elapsedMs or PERIOD_MS)
    if Recap.waitedMs > GIVE_UP_MS then Recap.queued = nil return end
    if not Recap.clear() then Recap.clearMs = 0 return end
    Recap.clearMs = Recap.clearMs + (elapsedMs or PERIOD_MS)
    if Recap.clearMs >= CLEAR_MS then
        Recap.queued = nil
        show(payload)
    end
end

CreateThread(function()
    while true do
        Wait(PERIOD_MS)
        Recap.tick(PERIOD_MS)
    end
end)
