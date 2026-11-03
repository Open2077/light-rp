# op77_map3d — 3D city map, minimap and GPS

A standalone Open77 resource that replaces the game's map and minimap with a fully
customizable 3D map of Night City, built from the game's own 3D map assets:

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
  edge pinning. Other players near you are shown.
- **Areas** for any client resource: polygons (a danger zone, a turf, a no-go zone)
  draped over the ground, the roads and the buildings of the map and the minimap, with a
  translucent fill (solid or diagonal danger hatching), a border and a label.
- **GPS**: routes computed on the game's own traffic network (15,906 vehicle lanes,
  one-way aware, speed-weighted A*, about 1 ms per route), drawn as an animated ribbon of
  chevrons on the map and the minimap; next maneuver and distance banner, remaining
  distance and ETA, automatic rerouting when you leave the route, arrival event.
  The waypoint is shared with the game's own (`Open77.blips` waypoint): a waypoint set by
  any other resource becomes this map's destination, and vice versa.

The game's map key opens this map (rebindable: "City map (3D)" in the key settings);
the game's own map and HUD minimap are switched off while the resource runs and come
back when it stops.

## Install

1. Put the folder in `resources/` (it is self-contained) and add `op77_map3d` to the
   server's resource load list.
2. Players need nothing else: the page and its data (about 11 MB) download with the
   resource.

## Configuration

`shared/config.lua`:

| Key | Meaning |
| --- | --- |
| `key` | Key mapping that opens the map (default `M`). |
| `zoomKeys` | `{ zoomIn, zoomOut }` key mappings that zoom the minimap while held (default numpad `+` / `-`, `NUMPADPLUS` / `NUMPADMINUS`: needs a client that knows the numpad names; `PAGEUP` / `PAGEDOWN` work everywhere). The level is remembered. |
| `replaceNativeMap` | Block the game's map key/menu while the resource runs. |
| `zIndex` | `{ minimap, holo, map }` surface order: the minimap (700) and the holo GPS (699) under a gamemode's interfaces (LightRP's page is 720), the open map (781) above. |
| `hideUnderMenus` | Hide the minimap and the holo GPS while another interface holds the cursor (inventory, F1 menu, phone). |
| `pauseMenuMap`, `pauseMenuPriority` | Register as the pause menu's CITY MAP (open77_pause map providers, `wiki/map-providers.md`); the highest priority wins. |
| `hideNativeMinimap` | Hide the vanilla HUD minimap. |
| `mirrorNativeWaypoint` | Share the waypoint with the game's (both ways). |
| `playerRate` | Player position updates per second sent to the page. |
| `fps` | `{ minimap, map }`: the two WebUI surfaces' frame rates (default 60 and 60). The minimap has its own surface cropped to its corner; the map's full-screen surface is hidden while closed. |
| `debug` | Print open/close, waypoint changes (with their origin) and page keys to the client log. |
| `nearbyPlayers` | `{ enabled, radius, interval, color }` other players as blips. |
| `page` | Everything the page uses, deep-merged over its defaults (below). |

`page` (defaults in `ui/src/config.ts`):

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
```

Blips belong to the resource that created them and disappear when it stops.

### Player dots

The map draws the players within `nearbyPlayers.radius` (350 m) as dots. An activity
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
blips, route, the holographic GPS) under "NO SIGNAL"; below 1 the map shows through the
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

The page reads these files through `open77://op77_map3d/web/data/...` (a WebUI page may
only fetch declared resource files, and WebAssembly is refused, hence no meshopt). If you
rename the folder, set `window.MAP3D_RESOURCE` in `web/index.html` to the new name.

The data is derived from Cyberpunk 2077 (CD PROJEKT RED); it only makes sense with the
game and is distributed for use with it.

## The page

`ui/` is the source (Vite + TypeScript + three.js 0.169), built into `web/`:

```
cd ui && npm ci && npm run build      # npm run dev -> http://localhost:5181/?open=1&route=1
```

The browser preview (`npm run dev`) runs a mock player and blips: `?open=1` opens the
map, `?route=1` sets a route, `?drive=1` drives, `?dist=700&fx=-1450&fy=150` zooms,
`?areas=1` (or `?areas=pulse`) adds Light RP's Dogtown danger zone and a solid area
(`?areas=1&open=1&dist=2600&fx=-1750&fy=-2450`), `?px=-1800&py=-2550&pyaw=0` puts the
player there (the minimap over a place).

`npm run build` empties `web/` first (Vite's `emptyOutDir`), `web/data` included: restore
it with `git checkout -- web/data`, or build with `npx vite build --outDir <elsewhere>` and
copy `index.html` and `assets/` over.

What the game's browser does differently from a desktop browser (all handled):

- `fetch` only reaches `open77://` URLs and WebAssembly is refused (see above);
- every click arrives with a click count of 1, so `dblclick` never fires: the page
  detects two still clicks within 450 ms itself;
- key events arrive without `KeyboardEvent.code`: keys are read through `keyName()`
  (`ui/src/controls.ts`), which falls back to `keyCode`;
- Escape is consumed while the map is open (`page:setConsumedKeys`), otherwise it also
  opens the pause menu.

## Tests

```
pwsh -File tests/run-lua.ps1      # blips, areas, owners, page lifecycle, waypoint mirror, server targets
node tests/gps_test.mjs           # 200 random routes on the real network (needs ui/node_modules)
node tests/areas_test.mjs         # what the shaders get from an area: distances, slots, Dogtown (needs ui/node_modules)
```
