-- Branding of the platform screens: the pause menu (accent + logo beside the
-- OPEN//77 mark; the manifest declares the logo with pause_menu_logo) and the
-- native map (title + accent of the selected tab). Applied at start so a
-- reload keeps everything.
local Branding = {}
LightRpBranding = Branding

local ACCENT = "#FFCC00"
local LOGO = "assets/logo.png"
local MAP_TITLE = "OPEN//77 / OFFICIAL ROLEPLAY"

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
    Branding.applyMap()
end

function Branding.applyMap()
    if type(Open77.map) ~= "table" then
        LightRpUi.log("map API unavailable: no map branding")
        return
    end
    if type(Open77.map.setTitle) == "function" then
        local ok, reason = Open77.map.setTitle(MAP_TITLE)
        if not ok then LightRpUi.log("map title refused: %s", tostring(reason)) end
    end
    if type(Open77.map.setAccentColor) == "function" then
        local ok, reason = Open77.map.setAccentColor(ACCENT)
        if not ok then LightRpUi.log("map accent refused: %s", tostring(reason)) end
    end
end
