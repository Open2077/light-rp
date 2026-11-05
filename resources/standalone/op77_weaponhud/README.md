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
  the HUD is lifted above LightRP's grenade chip, shows the RP names of the weapons and BT-7274's
  weapon while a Titan is piloted (`setExternal`).
- **Runs on:** client (the page, the samples) and server (runtime configuration)

## Data, and what the API does not give

| Shown | From |
|---|---|
| magazine, capacity, reserve, drawn, reloading | `Open77.weapons.snapshot()` rows (`open77:weapons:state`, one request in flight, every `pollMs` while armed) |
| reloading | also `Open77.players.isReloading()` |
| name, type | `Open77.data.weapon(record)` (the game's localized name), else the record |
| class | `client/catalogue.lua`, generated from the game's TweakDB (`tools/gen_catalogue.py`, weapons-2.31.csv) |
| shots | magazine deltas between two snapshots: there is no shot event, so a fast burst shows as several cells at once |
| a weapon that is not V's (a piloted Titan's) | whatever the gamemode hands over with `setExternal` (below), instead of all of the above: no snapshot |

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
`hide(reason)` / `show(reason)`, `setInset(px)`, `setLabels({ [record] = label })`,
`setExternal(state)` / `setExternal(nil)`.

`setExternal({ key, name, class?, type?, melee?, magazine?, capacity?, reserve?, reloading?, boost? })` shows a weapon that
is not one of V's (a piloted Titan's, for instance) instead of the drawn weapon, through the same display: the
unfold when `key` is new (a new `key` is a new weapon), `name` / `class` (the badge) / `type` as given in upper case,
the magazine, capacity and reserve as whole numbers (unknown ones read `---`), `reloading`. Call it again with the new
magazine whenever it changes: shots are the magazine deltas between two calls, low and empty come from `lowAmmo`
like any weapon. `melee = true` has no magazine or reserve and reads MELEE, with BLADE or BLUNT taken from `class`
(BLADE unless it says BLUNT). While one is set no snapshot is asked and the weapon is shown whether or not V holds one
(the same rules hide it: a menu on the cursor, `hide(reason)`, `showInVehicles = false` in a vehicle, `enabled = false`).
`setExternal(nil)` clears it and the drawn weapon is sampled again (the display folds away when nothing is drawn). A
state that names neither `key` nor `name` is refused (`false`). The weapon belongs to the calling resource and goes
when it stops; with several owners the one that set a weapon last is shown, and clearing it shows the other again.
`boost = true` makes the readout glow, melee or not: the digits, the frame and the cells burn brighter with a slow pulse
(a CSS animation on the page, nothing to resend while it lasts); anything but `true` (absent, `false`, junk) is off, and
it is part of the state like the magazine, so send the state again when it flips.
LightRP uses it for BT-7274 (`class = "TITAN"`, `type` RIFLE / CANNON / CHARGE RIFLE, SWORD and FISTS carrying the
class BLADE or BLUNT), sampled every 100 ms and sent only when something changed, with `boost` while a Burst, Sword or
Berserker core burns (not for Northstar's flight strike, which boosts no weapon).

Events (client, local): `op77_weaponhud:state { active }`, `op77_weaponhud:query`,
`op77_weaponhud:inset (owner, px)`, `op77_weaponhud:labels (owner, map)`.

## Development

- Tests: `pwsh -NoProfile -File tests/run-lua.ps1`.
- Preview without the game: `web/index.html?mag=18&cap=21&reserve=120&state=low|empty|reloading|melee&left=8&boost=1&demo=1`;
  `window.__weaponPreview.fire(n) / reload("start"|"end") / holster()`.
