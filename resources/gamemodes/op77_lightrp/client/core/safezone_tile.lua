-- Safe-zone tile: a small green holographic tile on the voice plate's top-left corner (the
-- bottom-right cluster with op77_speedometer and open-voice), replacing the page's old
-- bottom-left panel. Entering a zone, a label unfolds out of it ("SAFE ZONE" and what the
-- zone enforces) and folds back after a moment; leaving, an amber "LEAVING SAFE ZONE"
-- unfolds and the tile goes. Its own small surface (web/safezone/), cropped to that corner.
-- The zone comes from client/core/safezones.lua (the server's presence); the hint lists the
-- rules of shared/safezones.lua that the zone applies, nothing else.
local Ui = LightRpUi
local Tile = { page = nil, ready = false, sent = nil, shownOnce = false }
LightRpSafezoneTile = Tile

-- What each blocked rule means for the player (keys of LightRpSafezoneGeometry.RULES).
local RULE_TEXT = {
    blockShoot = "No shooting", blockRun = "Walk only", blockJump = "No jumping", blockMelee = "No melee",
    blockGrenades = "No grenades", blockConsumables = "No healing items", blockReload = "No reload",
    blockWeaponWheel = "No weapon wheel",
}
local MAX_PARTS = 3

-- "No PvP · No shooting · Walk only +2": PvP is always refused inside a zone (the server's
-- damage arbiter); the rest is what this zone blocks, defaults included.
function Tile.hint(zone)
    local parts = { "No PvP" }
    local more = 0
    local rules = LightRpSafezoneGeometry and LightRpSafezoneGeometry.RULES or {}
    for _, rule in ipairs(rules) do
        local blocked = type(zone) == "table" and zone[rule.key]
        if blocked == nil then blocked = rule.default end
        if blocked == true and RULE_TEXT[rule.key] then
            if #parts < MAX_PARTS then parts[#parts + 1] = RULE_TEXT[rule.key] else more = more + 1 end
        end
    end
    return table.concat(parts, " · ") .. (more > 0 and (" +" .. more) or "")
end

-- Inside a zone right now, as the controls see it (safezones.lua syncControls): a zone in
-- the presence, a character in the world, alive.
function Tile.current()
    if not (LightRpSafezones and LightRpSafezones.presenceZone) then return nil end
    local zone = LightRpSafezones.presenceZone()
    if type(zone) ~= "table" or not Ui.characterReady or Ui.creationActive then return nil end
    local ok, body = pcall(Open77.character.state)
    if not ok or type(body) ~= "table" or not body.alive or not body.attached then return nil end
    return zone
end

local function send(name, payload) if Tile.page and Tile.ready then pcall(Tile.page.send, Tile.page, name, payload) end end

function Tile.sync(instant)
    if not (Tile.page and Tile.ready) then return end
    local zone = Tile.current()
    local state = zone and { inside = true, label = tostring(zone.label or ""), hint = Tile.hint(zone) } or { inside = false }
    local key = state.inside and (state.label .. "|" .. state.hint) or "out"
    if key == Tile.sent then return end
    Tile.sent = key
    state.instant = instant == true
    if state.inside then Tile.shownOnce = true end
    send("zone:state", state)
end

-- The crop: the voice plate's top-left corner and the band left of the rental chip (CSS px of
-- a 1080-high screen, from the bottom-right corner); the page places the tile inside it.
Tile.BOUNDS = { x = -410, y = -175, width = 250, height = 95 }

local function create()
    local created, why
    for _ = 1, 120 do
        created, why = WebUI.create({ entry = "web/safezone/index.html", layer = "hud", width = 1920, height = 1080,
            transparent = true, visible = true, fps = 30, zIndex = 758, drawBounds = Tile.BOUNDS })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then Ui.log("safe-zone tile unavailable: %s", tostring(why)) return end
    Tile.page = created
    created:on("zone:ready", function()
        Tile.ready = true
        Tile.sent = nil
        -- a page reload replays the state without the animation; the first one teaches it
        Tile.sync(Tile.shownOnce)
    end)
end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    CreateThread(function()
        create()
        while true do
            Tile.sync(false)
            Wait(250)
        end
    end)
end)
