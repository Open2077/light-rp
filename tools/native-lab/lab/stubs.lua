-- What the HUD modules look up in the framework, reduced to what a document needs to
-- draw. Loaded after shared/events.lua and before client/native/host.lua.
LightRpUi = {
    menuOpen = false, dialogs = {}, characterReady = true, creationActive = false,
    loadingScreen = function() return false end,
}
function LightRpUi.send(name, payload)
    if LightRpNative then LightRpNative.page(name, payload) end
    return true
end
function LightRpUi.sendState(patch)
    if LightRpNative then LightRpNative.patchState(patch) end
    return true
end
-- Without a session the pre-game shell holds the cursor: the lab shows the HUD anyway.
-- It also draws on the debug layer: the shell is an opaque document of the system layer.
LightRpNativeLab = { ignoreCapture = true, layer = "debug" }
