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
- **Runs on:** client (the NativeUI document, the samples) and server (runtime configuration)

## How it is drawn

A NativeUI document (`Open77.ui`: RmlUi on the game's own Direct3D device, no browser):
`ui/speedometer.rml` + `ui/speedometer.rcss`, driven by `client/ui.lua` through one data model
(only the values that changed are merged; the numbers are smoothed between two samples `fps`
times a second). `client/ui.lua` offers `client/main.lua` the page API the former WebUI page
had (`on`, `send`, `destroy`), so the sampling code did not change. The tilt is RCSS 3D (a
perspective on `#rig`, `rotateX` / `rotateY` on `#plane` from `layout.tiltX` / `tiltY`); the
bloom and the scanlines are filters on `#holo`; the theme's colours are a stylesheet layer
built from the sheet itself. Fonts: Chakra Petch (built into the client) and Share Tech Mono
(`ui/fonts`). A client without NativeUI logs one line and shows nothing (the gamemode's own
cluster and the game's speedometer stay).

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

It shows for the driver (passengers with `showForPassengers`), and hides while another
interface holds the mouse cursor (`Open77.input.isCaptured()`: inventory, menus, phone).
NativeUI draws above every WebUI page: besides `hideUnderMenus` (the fold), the display steps
aside at once for as long as the cursor is held.

## Placement

At the default (`layout.right = 36`, `layout.bottom = 146`, `layout.scale = 0.6`, dp: pixels of a
1080-pixel-high screen) the display sits in the band at the right edge between LightRP's
work-order tracker (ends at y 766, 785 on 4:3) and its rental chip (y 946), above the voice HUD
(open-voice composites the bottom 160 px) and to the right of op77_map3d's holo GPS (bottom
centre, 780 x 320); on screens too narrow for that (5:4) it shrinks down to `layout.minScale`.
`zIndex` 710 is its order among the NativeUI documents of the `hud` layer.

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
exports.op77_speedometer:setConfig(patch)      -- deep-merged; a new layout moves the same document
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

- Tests: `pwsh -NoProfile -File tests/run-lua.ps1` (`-LuaDll <path to lua54.dll>` when the
  server's is not four folders up): the shared logic, the adapter (digits, ticks, scale, shake,
  theme layer, every name the document binds), the client with the host and NativeUI stubbed,
  the LightRP handshake.
- `ui/speedometer.rcss` keeps one rule per line with lowercase `#rrggbb[aa]` colours: the theme
  layer is derived from those lines (see its header).
- In game: `nui.reload` re-reads the document; `nui.debug <id>` inspects it.
