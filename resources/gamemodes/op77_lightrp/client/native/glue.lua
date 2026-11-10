-- What two HUD documents owe each other. In the page these were CSS selectors and DOM
-- measures across components; here each document is on its own, so the facts travel in Lua.
local N = LightRpNative

-- The notice lane sits to the right of the crew frame (or its invite) when there is one:
-- the frame is 236 dp wide at the HUD's left margin (32 dp), the page kept 16 dp between them.
local CREW_RIGHT = 32 + 236
-- setLeft is a no-op when the value does not change, so it is simply re-asserted.
local function syncLane()
    local hud = LightRpNativeHud and LightRpNativeHud.model
    local crew = type(hud) == "table" and (hud.crewOn == true or hud.inviteOn == true)
    if LightRpNativeNotices and LightRpNativeNotices.setLeft then LightRpNativeNotices.setLeft(crew and CREW_RIGHT + 16 or nil) end
end

-- The work order hides during a match (client/native/workorder.lua reads N.activityPhase
-- when it draws): a phase change has to make it draw again.
if LightRpNativeActivity and LightRpNativeActivity.on then
    LightRpNativeActivity.on(function()
        if LightRpNativeWorkOrder and LightRpNativeWorkOrder.refresh then LightRpNativeWorkOrder.refresh() end
    end)
end

-- The minimap (op77_map3d, NativeUI too) draws above every WebUI page: it steps aside with
-- the rest of the HUD under the F1 menu, a dialog or a cursor interface.
local minimapShown = nil
local function syncMinimap(shell)
    local show = not (shell.ready and shell.hidden)
    if show == minimapShown then return end
    local ok = pcall(function() exports.op77_map3d:setMinimapVisible(show) end)
    if ok then minimapShown = show end
end
N.onShell(syncMinimap)
AddEventHandler("op77_map3d:ready", function() minimapShown = nil; syncMinimap(N.shell) end)

N.onStart(function()
    CreateThread(function()
        while true do
            syncLane()
            Wait(200)
        end
    end)
end)
