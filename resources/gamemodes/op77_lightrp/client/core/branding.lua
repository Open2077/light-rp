-- Pause menu branding: the server's accent and logo beside the OPEN//77 mark.
-- The manifest already declares the logo (pause_menu_logo); this applies the
-- accent and re-asserts the logo at start so a reload keeps both.
local Branding = {}
LightRpBranding = Branding

local ACCENT = "#FFCC00"
local LOGO = "assets/logo.png"

function Branding.apply()
    if type(Open77.pauseMenu) ~= "table" then
        LightRpUi.log("pause menu API unavailable: no branding")
        return
    end
    if type(Open77.pauseMenu.setAccentColor) == "function" then
        local ok, reason = Open77.pauseMenu.setAccentColor(ACCENT)
        if not ok then LightRpUi.log("pause menu accent refused: %s", tostring(reason)) end
    end
    if type(Open77.pauseMenu.setLogo) == "function" then
        local ok, reason = Open77.pauseMenu.setLogo(LOGO)
        if not ok then LightRpUi.log("pause menu logo refused: %s", tostring(reason)) end
    end
end
