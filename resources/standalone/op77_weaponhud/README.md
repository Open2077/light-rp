# op77_weaponhud

A holographic weapon HUD floating at the bottom left while a weapon is drawn, the mirror of
`op77_speedometer` (same projection, tilted the other way so both frame the screen): the weapon's
name, its class (POWER / TECH / SMART / BLADE / BLUNT) and type, the magazine in seven-segment
digits with ghost leading zeros, the reserve, a bar of cells that empties shot by shot, LOW AMMO,
RELOAD / NO AMMO and RELOADING, and the left hand's magazine when dual-wielding.

Each shot flickers the digits, ejects the emptied cells and kicks the plate; a reload sweeps the
cells with a progress line, then the count rolls up as they refill; an empty magazine pulses red;
drawing or switching unfolds it with a self-test, holstering folds it away.

- **Starts:** on its own (add `"op77_weaponhud"` to `resources.load`; a new name needs a server restart)
- **Needs:** nothing. With `op77_lightrp`, the gamemode's weapon readout stands down while it runs,
  the HUD is lifted above LightRP's grenade chip and shows the RP names of the weapons.
- **Runs on:** client (the page, the samples) and server (runtime configuration)

## Data, and what the API does not give

| Shown | From |
|---|---|
| magazine, capacity, reserve, drawn, reloading | `Open77.weapons.snapshot()` rows (`open77:weapons:state`, one request in flight, every `pollMs` while armed) |
| reloading | also `Open77.players.isReloading()` |
| name, type | `Open77.data.weapon(record)` (the game's localized name), else the record |
| class | `client/catalogue.lua`, generated from the game's TweakDB (`tools/gen_catalogue.py`, weapons-2.31.csv) |
| shots | magazine deltas between two snapshots: there is no shot event, so a fast burst shows as several cells at once |

Not available from the API, so not shown: the fire mode (semi / burst / auto / charge) and a
tech weapon's charge. A record equipped by another pipeline may come back without a name
(`record` empty): it shows as WEAPON.

## Placement

Default `layout.left = 36`, `layout.bottom = 142`, `layout.scale = 0.6` (CSS px of a 1080-high
screen): just above LightRP's circular gauges (y 950), left of op77_map3d's holo GPS. A gamemode
whose bottom-left stack grows lifts it with `TriggerEvent("op77_weaponhud:inset", owner, px)` or
`exports.op77_weaponhud:setInset(px)` (up to `layout.maxInset`; LightRP sends 30 while its grenade
chip shows). Surface cropped to that corner, 30 fps, zIndex 705. Kept in vehicles (drive-by): the
speedometer is on the other side.

## Configuration

`shared/config.lua`: `enabled`, `hideNativeWeaponHud`, `hideUnderMenus`, `showInVehicles`, `layout`
(left, bottom, offsetX, offsetY, scale, tilt, tiltX, tiltY, maxInset), `theme` (accent, core, warn,
cool, glow, opacity, scanlines, flicker), `leadingZeros`, `lowAmmo`, `lowAmmoMax`, `maxCells`,
`weaponNames`, `pollMs`, `idleMs`, `fps`, `zIndex`, `debug`.

## API

Server: `exports.op77_weaponhud:setConfig(patch[, playerId])`, `resetConfig()`.

Client: `setConfig(patch)`, `getConfig()`, `setEnabled(bool)`, `isEnabled()`, `isShown()`,
`hide(reason)` / `show(reason)`, `setInset(px)`, `setLabels({ [record] = label })`.

Events (client, local): `op77_weaponhud:state { active }`, `op77_weaponhud:query`,
`op77_weaponhud:inset (owner, px)`, `op77_weaponhud:labels (owner, map)`.

## Development

- Tests: `pwsh -NoProfile -File tests/run-lua.ps1`.
- Preview without the game: `web/index.html?mag=18&cap=21&reserve=120&state=low|empty|reloading|melee&left=8&demo=1`;
  `window.__weaponPreview.fire(n) / reload("start"|"end") / holster()`.
