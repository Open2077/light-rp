-- Staff announcements, client side (server/modules/staff.lua Staff.announce): the banner is
-- the page's (ui/src/features/announce/StaffBroadcast.tsx); here the game's own sounds play
-- with it: a hacking glitch as it tears in, a jingle once it settles.
local E, Ui = LightRpEvents, LightRpUi

local function sound(event)
    if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, event) end
end

RegisterNetEvent(E.net.staffAnnounce, function(p)
    if type(p) ~= "table" or type(p.text) ~= "string" or p.text == "" then return end
    Ui.send(E.page.staffAnnounce, {
        title = type(p.title) == "string" and p.title:sub(1, 48) or "Staff announcement",
        text = p.text:sub(1, 240),
        from = type(p.from) == "string" and p.from:sub(1, 48) or nil,
        durationMs = math.max(4000, math.min(30000, math.floor(tonumber(p.durationMs) or 10000))),
    })
    sound("ui_fx_hacking_glitch_fullscreen_low")
    CreateThread(function()
        Wait(380)
        sound("ui_jingle_new_area")
    end)
end)
