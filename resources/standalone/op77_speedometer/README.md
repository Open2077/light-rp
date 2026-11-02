# op77_speedometer

A holographic speedometer that floats at the bottom right of the screen while the player drives,
in the LightRP black-and-yellow style: the speed in seven-segment digits ("063", leading zeros as
ghosts), an RPM strip with its redline, the gear, the unit, a speed bar, the HBK / ABS / TCS
indicators, lights, engine and tyre icons, and fuel and condition gauges. The display is tilted
in 3D and glows, with scanlines, a scan sweep and the odd flicker. It unfolds from a line when
the player sits down, folds away when they get out, smooths its numbers between samples and
shakes a little at high speed.

- **Starts:** on its own (add `"op77_speedometer"` to `resources.load`)
- **Needs:** nothing. With `op77_lightrp`, the gamemode's own vehicle cluster stands down while
  this display is on (`op77_speedometer:state` / `op77_speedometer:query`).
- **Runs on:** client (the page, the samples) and server (runtime configuration)

## What it reads

| Shown | From |
|---|---|
| speed, gear (R / N / 1-9) | `Open77.vehicles.get(id)`: `speed` (m/s), `gear`, `reversing` |
| RPM strip | `rpm / rpmMax` (falls back to the speed when the car reports no RPM) |
| HBK | the handbrake keys held (`handbrakeKeys`, physical reads: `Open77.input.isDown`) |
| ABS | `brake` above `absBrake` while moving faster than `absMinKph` |
| TCS | `burnout`, or `totalSlip` above `tcsSlip` |
| lights / high beams | `flags` (`lightsOn`, `highBeams`), red when lights are broken |
| engine | `flags.engineOn`; red, blinking, when `health` is below `damageWarn` |
| tyres | flat tyres counted from `damage.tires` |
| fuel | the vehicle's state bag `fuel` / `fuelMax` (LightRP's fuel module); no value, no gauge |
| condition | `health` |

It shows for the driver (passengers with `showForPassengers`), and hides while another page
holds the mouse cursor (`Open77.input.isCaptured()`: inventory, menus, phone).

## Placement

At the default (`layout.right = 36`, `layout.bottom = 146`, `layout.scale = 0.6`, CSS pixels of a
1080-pixel-high screen) the display sits in the band at the right edge between LightRP's
work-order tracker (ends at y 766, 785 on 4:3) and its rental chip (y 946), above the voice HUD
(open-voice composites the bottom 160 px) and to the right of op77_map3d's holo GPS (bottom
centre, 780 x 320); on screens too narrow for that (5:4) it shrinks down to `layout.minScale`.
Its surface is cropped to that corner (`drawBounds`), 30 fps, zIndex 710: under LightRP's page
(720) and the voice HUD (760), above the 3D minimap (700).

## Configuration

`shared/config.lua` documents every key: `enabled`, `units` (`kph` | `mph`), `speedMax`,
`showForPassengers`, `hideUnderMenus`, `hideNativeSpeedometer`, `showVehicleName`,
`vehicleNames`, `layout` (right, bottom, offsetX, offsetY, scale, tilt, tiltX, tiltY,
avoidHoloGps, minScale), `theme` (accent, core, gear, warn, cool, glow, opacity, scanlines,
flicker), `leadingZeros`, `shake`, `handbrakeKeys`, `absBrake`, `absMinKph`, `tcsSlip`, `fuel`,
`damageWarn`, `rate`, `fps`, `zIndex`, `exitAnimationMs`, `debug`.

## API

Server:

```lua
exports.op77_speedometer:setConfig({ units = "mph", theme = { accent = "#3FE0D0" } }) -- everyone, now and later
exports.op77_speedometer:setConfig({ layout = { scale = 0.8 } }, playerId)            -- one player, this session
exports.op77_speedometer:resetConfig()                                                 -- back to shared/config.lua
```

Client:

```lua
exports.op77_speedometer:setConfig(patch)      -- deep-merged; a new layout recreates the surface
exports.op77_speedometer:getConfig()
exports.op77_speedometer:setEnabled(false)     -- the native speedometer and LightRP's cluster come back
exports.op77_speedometer:isEnabled()
exports.op77_speedometer:isShown()
exports.op77_speedometer:hide("my_cutscene")   -- hidden until show("my_cutscene") (or that resource stops)
exports.op77_speedometer:show("my_cutscene")
```

Events (client, local): `op77_speedometer:state` `{ active }` when it turns on or off,
`op77_speedometer:query` makes it announce again.

## Development

- Tests: `pwsh -NoProfile -File tests/run-lua.ps1` (shared logic, the client with the host
  stubbed, the LightRP handshake).
- Preview without the game: serve `web/` and open `index.html?speed=63&gear=3&rpm=0.55&hbk=1`
  (also `abs tcs lights fuel health engine tires name units tilt scale accent zeros instant=0
  demo=1`); `demo=1` drives a loop.
