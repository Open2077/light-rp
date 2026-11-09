# op77_map3d — 3D city map, minimap and GPS

A standalone Open77 resource that replaces the game's map and minimap with a fully
customizable 3D map of Night City, built from the game's own 3D map assets and drawn
by **NativeUI**: the client's own D3D12 scene layer and RmlUi, no browser. One native
document holds the minimap and the full map as two views of one city
loaded once; the map renders in the game's frame (no page texture, no IPC), redraws
only what moves, and shows what it costs live (the NATIVEUI panel on the open map).

- **The city in 3D**: terrain, water, roads and road lines, metro, cliffs, landmarks
  and the 255,532 building volumes of every district (Phantom Liberty's Dogtown and
  the NCX spaceport included), drawn with flat, theme-driven shaders: black volumes,
  yellow outlines, the LightRP look by default.
- **Orbit view like Google Maps**: drag to pan, right-drag (or Ctrl+drag) to rotate
  and tilt, wheel to zoom toward the cursor, 2D/3D toggle, north-up, recenter.
  Keyboard: WASD/arrows pan, Q/E rotate, R/F tilt, +/- zoom, Space recenter, N north,
  G route to the selected place, Delete (or the route bar's Clear route) clears the route,
  / searches, M/Esc close.
- **Search**: the box over the legend finds blips by name, description, category or
  district, and district names; arrows + Enter or a click fly there and open the card.
- **Minimap**: the same city around you, heading-up (or north-up), tilted, zooming out
  with speed, blips pinned to its edge when they matter, district and distance below.
- **Blips** for any resource (client or server): built-in icons or your own SVG, colour,
  label, description, category (legend with toggles and counts), pulse, heading arrows,
  edge pinning. Other players are not shown (`nearbyPlayers.enabled = false`, 0.2.1): the influence zones show where people gather.
- **Areas** for any client resource: polygons (a danger zone, a turf, a no-go zone)
  draped over the ground, the roads and the buildings of the map and the minimap, with a
  translucent fill (solid or diagonal danger hatching), a border and a label.
- **GPS**: routes computed on the game's own traffic network (15,906 vehicle lanes,
  one-way aware, speed-weighted A*, about 1 ms per route), drawn as an animated ribbon of
  chevrons on the map and the minimap; next maneuver and distance banner, remaining
  distance and ETA, automatic rerouting when you leave the route, arrival event.
  The waypoint is shared with the game's own (`Open77.blips` waypoint): a waypoint set by
  any other resource becomes this map's destination, and vice versa.

- **Display quality**: **performance** by default, a flat 2D map seen from straight
  above for small configurations; **quality**, the 3D city with every effect. The first
  time a player opens the map they choose; the choice is kept on their machine and
  switched at any time under DISPLAY in the legend (see "Display quality").

The game's map key opens this map (rebindable: "City map (3D)" in the key settings);
the game's own map and HUD minimap are switched off while the resource runs and come
back when it stops.

## Install

1. Put the folder in `resources/` (it is self-contained) and add `op77_map3d` to the
   server's resource load list.
2. Players need nothing else: the native UI and its data (about 11 MB) download with
   the resource. It needs a client with NativeUI views (Open77 0.6, scene views, graph
   routes and anchors: see `wiki/native-ui.md`).

## Configuration

`shared/config.lua`:

| Key | Meaning |
| --- | --- |
| `key` | Key mapping that opens the map (default `M`). |
| `zoomKeys` | `{ zoomIn, zoomOut }` key mappings that zoom the minimap while held (default numpad `+` / `-`, `NUMPADPLUS` / `NUMPADMINUS`: needs a client that knows the numpad names; `PAGEUP` / `PAGEDOWN` work everywhere). The level is remembered. |
| `replaceNativeMap` | Block the game's map key/menu while the resource runs. |
| `zIndex` | Kept for older configs; the native document draws above WebUI pages (NativeUI's layer), `hideUnderMenus` steps it aside under other interfaces. |
| `hideUnderMenus` | Hide the minimap while another interface holds the cursor (inventory, F1 menu, phone). |
| `pauseMenuMap`, `pauseMenuPriority` | Register as the pause menu's CITY MAP (open77_pause map providers, `wiki/map-providers.md`); the highest priority wins. |
| `hideNativeMinimap` | Hide the vanilla HUD minimap. |
| `mirrorNativeWaypoint` | Share the waypoint with the game's (both ways). |
| `playerRate` | Player position updates per second fed to the map (the minimap camera eases between them every frame). |
| `fps` | Kept for older configs: `page.minimap.fps` caps the minimap's redraws, `page.map.idleFps` the open map's while only the route or zones animate. |
| `debug` | Print open/close, waypoint changes (with their origin) and page keys to the client log. |
| `nearbyPlayers` | `{ enabled, radius, interval, color }` other players as blips. Off by default since 0.2.1 (no positions on the map; no loop runs). |
| `page` | Everything the native map uses, deep-merged over its defaults (below). |

`page` (defaults in `client/native/defaults.lua`):

- `theme`: `background, terrain, terrainGrid, water, waterLine, road, roadEdge, metro,
  building, buildingTop, buildingEdge, landmark, accent, accentSoft, text, textDim,
  panel, danger` (CSS colours) and `fog` (0..1).
- `minimap`: `enabled, anchor (top-right|top-left|bottom-right|bottom-left), size,
  margin, shape (chamfer|circle|square), tilt (on foot), vehicleTilt, vehicleFollow (camera|vehicle), rotate, radius, vehicleRadius, fps,
  showRoute, supersample, xray` (minimap drawn at that multiple of the screen resolution;
  buildings between the camera and you cut away within `xray` metres, 0 = off).
- `map`: `initialDistance, minDistance, maxDistance, initialPitch, maxPitch, buildings,
  roadBorders, districtLabels, showCoordinates, doubleClickWaypoint, rightClickWaypoint,
  title, subtitle, resolution, idleFps, search` (render scale, redraws per second while
  only the route animates, the search box).
- `gps`: `enabled, rerouteDistance, rerouteDelay, arriveDistance, snapMainNetwork,
  avoidHighways, units (metric|imperial), routeWidth, animationSpeed`.
- `areas`: `labels` (each area's label on the open map), `hatch` / `minimapHatch` (pixels
  between two hatching stripes), `minimapStrength` (0..1), `minimapLabel` (the line under
  the minimap names the labelled area you stand in instead of the district).
- `categories`: `{ id, label, icon, color }` rows of the legend.
- `locale`: the texts (`setRoute, clearRoute, waypoint, arrived, noRoute, rerouting...`).

## Client API

```lua
local map = exports.op77_map3d

local id = map:addBlip({
    position = { x = -1188, y = 320, z = 20 },
    icon = "store",            -- built-in name, "<svg ...>" or an image URL
    color = "#FFCC00",
    label = "24/7 Store",
    description = "Snacks, water and phone credit.",
    category = "service",      -- a legend row (config.page.categories)
    scale = 1.0, pulse = false, edge = false,   -- edge: pinned to the minimap's border
    heading = nil,             -- game yaw: an arrow instead of an icon
    map = true, minimap = true, routable = true,
    id = "store-1",            -- optional stable id (namespaced to your resource)
})
map:updateBlip(id, { label = "24/7 (open)", x = -1190 })
map:removeBlip(id)
map:clearBlips()               -- every blip of the calling resource
map:getBlip(id)

map:setWaypoint({ x = -747.8, y = 914.6, z = 30 })   -- starts the GPS
map:clearWaypoint()
map:getWaypoint()              -- { x, y, z } or nil
map:getRoute()                 -- { active, remaining, next = { kind, distance }, ... }

map:open({ x = -2044, y = -2406 })   -- optional focus point
map:close(); map:toggle(); map:isOpen(); map:isReady()
map:focus({ x = 0, y = 0 }, 800)     -- fly the open map's camera there

map:setTheme({ accent = "#3FE0D0", buildingEdge = "#3FE0D0", roadEdge = "#3FE0D0" })
map:setConfig({ minimap = { anchor = "bottom-right", shape = "circle" } })
map:setMinimapVisible(false)
map:setPlayerDotsHidden(true, { 12 })   -- see "Player dots"
map:getQuality()               -- "performance" | "quality", and whether the player chose
map:setQuality("performance")  -- see "Display quality"
```

Blips belong to the resource that created them and disappear when it stops.

### Display quality

Two ways to draw the map and the minimap, the same look (colours, outlines, blips, areas,
route, zones):

| | performance (default) | quality |
|---|---|---|
| view | 2D, straight above (orthographic), rotation kept, no tilt | 3D orbit, tilt, 2D/3D button |
| buildings | roofs only (one quad per box), outlined | lit volumes, outlines, x-ray cut on the minimap |
| ground, water, landmarks | one flat colour (major grid kept) | lighting, minor grid, scan lines, rim light |
| route | still chevrons | flowing chevrons, pulsing destination |
| activity zones | still disc and rim | animated field, beacons, lit buildings |
| antialiasing, resolution | none; map at screen pixels at most, minimap x1.25 | 4x MSAA; map up to x2, minimap x1.75 |
| redraws | only on change; the player's arrow moves every update, the map under it 4 times a second; minimap 30 fps at most | idle animation 30 fps, minimap up to 60 fps |
| open/close | short fade | blur, scale and scan line |

The first time a player opens the map (never chosen: nothing in KVP), a DISPLAY MODE
panel asks which one (1 / 2, arrows + Enter, or a click; Esc closes the map and asks
again next time). The map behind it is already drawn in performance mode. The choice is
kept in the client's KVP (`Open77.kvp`, key `map3d:quality`, per server) and reaches the
minimap's surface at once; the legend's DISPLAY switch changes it at any time, without
reloading the page.

`config.quality = { default = "performance", ask = true }`: `ask = false` never asks
(`default` until the player switches). A gamemode's settings menu can use
`exports.op77_map3d:setQuality(mode)` / `getQuality()`; `op77_map3d:qualityChanged`
(client event, the mode) fires on a change.

### Player dots

With `nearbyPlayers.enabled = true` (off by default since 0.2.1), the map draws the players within `nearbyPlayers.radius` (350 m) as dots. An activity
where that would give the game away (a chase: the cops would see the runner) hides them,
opt-in, for as long as it needs:

```lua
map:setPlayerDotsHidden(true, { runnerId })  -- hide these players (server ids)
map:setPlayerDotsHidden(true)                -- hide every player
map:setPlayerDotsHidden(false)               -- show again what this resource hid
map:arePlayerDotsHidden(runnerId)            -- true if any resource hides that player
```

Each call replaces the calling resource's previous choice; several resources' choices
add up; a hidden dot goes at once, not at the next refresh. Everything a resource hid
comes back when it stops. Blips and the player's own arrow are not affected.

### Jamming

The map and minimap can drown in static: an unmapped place, a custom map zone, an RP
action (a scrambler, a blindfold, a dead phone). `strength` 1 hides everything (map,
blips, route) under "NO SIGNAL"; below 1 the map shows through the
static. Several jams combine, the strongest wins; they belong to their resource.

```lua
local id = map:jam({ strength = 1, label = "SIGNAL LOST" })        -- on until unjam
map:unjam(id)
local zone = map:addJamZone({ position = { x = -2044, y = -2406 }, radius = 180,
    fade = 60, strength = 1, label = "NO MAP" })                    -- full inside, fading over 60 m
map:removeJamZone(zone)
map:clearJams()               -- every jam of the calling resource
map:getJam()                  -- { strength, label } where the player stands
map:isJammed()
```

`op77_map3d:jammed (jammed, strength)` fires when the map becomes jammed or clear.

### Areas

Polygons drawn on the open map and the minimap: a translucent fill (plain, or diagonal
danger hatching), a solid border and a label. They lie on the ground, the roads and the
buildings (the city's relief is 140 m in Dogtown alone, so a flat shape would float or
sink), under the blips, the route and the labels.

```lua
local id = map:addArea({
    id = "dogtown",                    -- optional stable id (namespaced to your resource)
    points = { { x = -2550, y = -2726.6 }, { -2410, -2846.6 }, ... },   -- world metres, 3 to 160
    fill = "#FF2E3C",                  -- #rrggbb or #rgb (default: the danger red)
    fillOpacity = 0.22,                -- 0..1
    stroke = "#FF2E3C",                -- the border (default: the fill)
    strokeWidth = 2.5,                 -- pixels, 0..8 (0: no border)
    pattern = "hatch",                 -- "hatch" (diagonal stripes) or "solid"
    label = "DOGTOWN · DANGER ZONE",   -- optional, 64 characters at most
    labelPosition = { x = -1420, y = -2560 },   -- default: inside the shape, near its middle
    map = true, minimap = true,        -- where it shows
    pulse = false,                     -- the fill and border breathe
})
map:updateArea(id, { fill = "#FFCC00", label = false })   -- the fields given; false clears label / labelPosition
map:removeArea(id)
map:clearAreas()                       -- every area of the calling resource
map:getArea(id)                        -- a copy of the definition, or nil
```

- A refused definition returns `nil, reason` (`updateArea`: `false, reason`): fewer than 3
  or more than 160 points, a point that is not a finite `{ x, y }` (or `{ x = .., y = .. }`),
  points that enclose nothing, a colour that is not `#rrggbb`, an unknown `pattern`.
- Areas belong to the resource that created them: only it can update or remove them, an
  id it gave is its own (`"dogtown"` is `"<resource>:dogtown"`, either form works for it),
  and they go when it stops. 16 per resource: the map draws 16 at a time (the oldest).
  Adding again with the same `id` replaces the area and keeps its place in the drawing
  order; where two areas overlap, the newer one is on top.
- Inside is decided with the even-odd rule, like `Map3DArea.contains(area, x, y)`.
- The border and the hatching keep the same width in pixels at every zoom; the stripes
  stay anchored to the ground but always run diagonally across the screen.
- Areas are client-only: a server resource sends its outline to its own client script,
  which calls `addArea` (Light RP does this for Dogtown). A 160-point definition is about
  990 values, under the 1024 an export argument may hold; each area reaches the page in a
  message of its own.
Built-in icons: `pin user car store briefcase target home flag star skull shield police
hospital fuel wrench shirt gun phone dollar bed food info warning garage crosshair
waypoint bank mission bus`.

Client events (`AddEventHandler`): `op77_map3d:ready`, `op77_map3d:opened`,
`op77_map3d:closed`, `op77_map3d:waypointChanged (pos|nil)`, `op77_map3d:route (info)`,
`op77_map3d:arrived (pos)`, `op77_map3d:blipClicked (id)`.

## Server API

```lua
local map = exports.op77_map3d
local id = map:addBlip(-1, { id = "depot", position = { x = 1, y = 2 }, icon = "briefcase", label = "Courier depot", category = "job" })
map:addBlip(playerId, { ... })          -- one player
map:addBlip({ 1, 4, 9 }, { ... })       -- a list
map:updateBlip(id, { label = "Depot (closed)" })
map:removeBlip(id)
map:clearBlips()
map:setWaypoint(playerId, { x = ..., y = ..., z = ... })   -- or false to clear
map:openMap(playerId, { x = ..., y = ... })
map:jam(-1 | playerId | { ids }, { strength = 1, label = "BLACKOUT" })   -- jamming, same targets
map:addJamZone(-1, { id = "dogtown", position = { x = -2044, y = -2406 }, radius = 400 })
map:unjam(id); map:removeJamZone(id); map:clearJams()
```

Server blips are sent again to players who join later; a stopping resource takes its
blips along.

## The map data

`web/data` is generated from the game files by `tools/export_web.py`:

- `world.glb` (4.8 MB, quantized): the meshes of `base\entities\cameras\3dmap`
  (`3dmap_view.ent` component transforms baked in);
- `buildings.bin` (4.1 MB): the `3d_map_cubes.mt` point clouds (`*_data.xbm`,
  R16G16B16A16: position, orientation quaternion and size of every box), 16 bytes a box;
- `roads.bin` (1.8 MB): the vehicle lanes of
  `base\worlds\03_night_city\sectors\_generated\traffic` (outlines, links, speeds,
  flags) with the main strongly connected network marked;
- `manifest.json`: layout and conventions (scene = game (x, z, -y)).

To regenerate (for instance after a game update), extract with WolvenKit CLI then run
the exporter; `tools/mapdata.py` documents every format it reads:

```
WolvenKit.CLI uncook <content>\basegame_1_engine.archive <content>\basegame_4_gamedata.archive -r "(?i)3dmap" -o cooked -or raw
WolvenKit.CLI uncook ... -r "(?i)3dmap.*_data" --uext dds -o cooked-dds -or raw-dds     # 16-bit point clouds
WolvenKit.CLI unbundle <ep1>\ep1_1_nightcity.archive -r "(?i)_generated.traffic.all\.(lane_polygons|traffic_persistent|lane_connections)" -o traffic-ep1
WolvenKit.CLI convert serialize <each traffic file and 3dmap_view.ent, 3dmap_triangle_soup.mesh> -o json / json-traffic
python tools/export_web.py out
npx @gltf-transform/cli weld out/world.raw.glb out/w.glb && npx @gltf-transform/cli quantize out/w.glb out/world.glb
```

The client reads these files itself (NativeUI scene ops `mesh`, `instances`, `graph` and
`lines`, on loader threads): Lua only reads `manifest.json`.

The data is derived from Cyberpunk 2077 (CD PROJEKT RED); it only makes sense with the
game and is distributed for use with it.

## The native map

`client/native/` and `ui/native/` (no build step):

| File | |
| --- | --- |
| `ui/native/map.rml`, `map.rcss` | The document: minimap and full map (layout, motion, effects). Colours are a theme layer. |
| `client/native/theme.lua` | The theme as one RCSS layer (`ui:stylesheet("theme", ...)`): `setTheme` reaches every rule live. |
| `client/native/icons.lua` | The built-in icons, and a resource's own `<svg>` turned into NativeUI `<path>` data. |
| `client/native/defaults.lua` | The `page` defaults and the config merge. |
| `client/native/app.lua` | The two roles `client/main.lua` talks to (send / on / show / hide / focus): scene, views, blips, GPS, areas, zones, jamming, search, legend, card, quality chooser, perf panel. |

What the client does natively (and any resource can use, `wiki/native-ui.md`):

- one scene, two **views** (`<scene3d view="mini|full">`): own cameras, MSAA,
  redraw caps, render scale, x-ray; the city is loaded once;
- **areas** and **activity zones** drawn in the scene's shaders (`areas`, `zones` ops);
- the **GPS search**: the traffic network as a scene `graph`, A* off the game thread
  (`route`), the route drawn as chevron lines;
- **anchors** for the blips: pinned to the minimap's edge, turned to a heading,
  clustered with a count, fanned out under the mouse, moved by transform (no relayout);
- the open map's backdrop blurs the game behind it, the minimap is glass: the city is
  drawn translucent over the frosted frame.

Fonts: Zen Dots and Share Tech Mono (SIL OFL), `ui/native/fonts`, converted to TTF from
the former web page's WOFF2 files; Chakra Petch is built into NativeUI.

## Tests

```
pwsh -File tests/run-lua.ps1                        # blips, areas, owners, surfaces, waypoint mirror, server targets
pwsh -File tests/run-lua.ps1 -Test native_test.lua  # icons (SVG to paths), theme layer, config merge
```
