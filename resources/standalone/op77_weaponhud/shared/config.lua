-- op77_weaponhud configuration (server owners edit this file). Runtime patches, deep-merged:
--   exports.op77_weaponhud:setConfig({ theme = { accent = "#3FE0D0" } })              -- server, everyone
--   exports.op77_weaponhud:setConfig({ layout = { scale = 0.7 } }, playerId)          -- server, one player
--   exports.op77_weaponhud:setConfig({ enabled = false })                            -- client, this player
WeaponHudConfig = {
    enabled = true,

    -- Hide the game's own weapon HUD (ammo counter) while this resource runs (ui.vanilla.hud).
    hideNativeWeaponHud = true,
    -- Hide it while another interface holds the mouse cursor (inventory, menus, phone...).
    hideUnderMenus = true,
    -- Keep it in vehicles: the speedometer is on the other side of the screen, and a drawn
    -- weapon in a car means drive-by shooting, where the ammo count matters.
    showInVehicles = true,

    -- Where it sits, in CSS pixels of a 1080-pixel-high screen: distances from the LEFT and
    -- bottom edges to the display's box (420 x 210 at scale 1). The default sits just above
    -- LightRP's circular gauges (they start at y 950) and is the mirror of op77_speedometer.
    -- A gamemode whose bottom-left stack grows (LightRP's grenade chip) lifts it with
    -- op77_weaponhud:inset; the surface's crop leaves room for `maxInset` px of lift.
    layout = {
        left = 36,
        bottom = 142,
        offsetX = 0,        -- extra shift, + = right
        offsetY = 0,        -- extra shift, + = down
        scale = 0.6,        -- 0.4 .. 1.6
        tilt = true,
        tiltX = 8,          -- degrees, + = the top edge leans away
        tiltY = 16,         -- degrees, + = the right side recedes (faces the screen centre)
        maxInset = 60,
    },

    theme = {
        accent = "#FFCC00",
        core = "#FFF7DA",
        warn = "#FF3B3B",
        cool = "#7FD8FF",   -- reloading
        glow = 1.0,
        opacity = 1.0,
        scanlines = true,
        flicker = true,
    },

    -- Leading zeros of the magazine count ("021"): "dim", "lit" or "off".
    leadingZeros = "dim",
    -- Low-ammo warning at or under this share of the magazine (and never above `lowAmmoMax` rounds).
    lowAmmo = 0.25,
    lowAmmoMax = 10,
    -- Most cells drawn for the magazine bar; bigger magazines put several rounds in a cell.
    maxCells = 36,

    -- Names: records -> label. Gamemodes can also send labels at runtime (op77_weaponhud:labels).
    weaponNames = {},

    -- Sampling: one Open77.weapons.snapshot() in flight, at most every `pollMs` while a weapon
    -- is drawn; `idleMs` otherwise.
    pollMs = 100,
    idleMs = 300,

    fps = 30,
    zIndex = 705,     -- under LightRP's page (720), next to the speedometer (710)
    debug = false,
}
