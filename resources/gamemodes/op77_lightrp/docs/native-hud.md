# The HUD on NativeUI

Every heads-up element of Light RP (what the player reads while playing) is a NativeUI
document: RmlUi drawn by the client on the game's own Direct3D device. The WebUI page
(`ui/`, React, built into `web/`) keeps the menus and the dialogs. Reference for the API:
`wiki/native-ui.md` in open77-base.

## Layout

| Path | |
|---|---|
| `client/native/host.lua` | the host: taps `LightRpUi.send` and the state patches, the shell (may the HUD show), fonts, helpers |
| `client/native/icons.lua` | generated: the page's Lucide glyphs as one path each (`ui/tools/gen-native-icons.mjs`) |
| `client/native/<hud>.lua` | one module per HUD document |
| `ui/native/lightrp.rcss` | the design tokens as RCSS classes (read its header: the colour table) |
| `ui/native/<hud>.rml`, `<hud>.rcss` | the document and its sheet |
| `ui/native/fonts/` | Share Tech Mono, Zen Dots (Chakra Petch is built into the client) |

## A module

```lua
local N = LightRpNative
local E = LightRpEvents
local doc
local function model() return { ready = false, hidden = true, quiet = false --[[ every bound name, with a default ]] } end

N.onStart(function()
    doc = N.create({ document = "ui/native/example.rml", zIndex = 20, models = { hud = model() } })
end)
N.onShell(function(shell) N.patch(doc, "hud", { ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet }) end)
N.on(E.page.hud, function(hud) N.patch(doc, "hud", { health = N.round(hud.health.value) }) end)   -- a page event
N.onState("rental", function(rental, state) ... end)                                                -- a state key
```

- `N.on(name, fn)` receives exactly what the React page received for that page event
  (`shared/events.lua`, `E.page.*`; a few modules use literal names such as
  `"lightrp:ui:hotbar"`). `N.onState(key, fn)` fires when the server (or a client
  module) patches that top-level state key; `N.state` is the merged state, `N.hud` the
  last HUD sample.
- `N.patch(doc, model, values)` merges only what changed: call it freely (10 Hz samples).
- Every name a document binds must exist in the model given to `N.create` (a missing name
  is an RmlUi error on every frame). `{}` is an empty array.
- Timers and animations live in Lua threads (`CreateThread`, `Wait`) or in RCSS
  (`transition`, `animation`, `ui:animate`): the React components' `setTimeout`s become one of the two.
- Keep the model flat and the logic in pure local functions that turn a payload into
  model values; they are what `tests/` can check without the game.
- The client Lua sandbox has **no `setmetatable`**, no `os`, no `io`.

## Showing and hiding

`N.shell` = `{ ready, hidden, quiet }` (see `host.lua`). Put the class `shell` on the
document's root element with `data-class-is-ready="ready" data-class-is-hidden="hidden"
data-class-is-quiet="quiet"`: the HUD then fades as the page's did. NativeUI draws
**above** every WebUI page, so a HUD that used to sit under a dialog must hide with the
shell. Elements that must stay over a dialog (notices, a staff broadcast) simply do not
bind `hidden`.

A module that covers the world calls `N.cover("name", true|false)`.

## Design rules

The look is the page's, value for value: same sizes, colours, spacing, wording, motion.
Read the component's `.tsx` and `.css` (and `ui/src/design/tokens.css` for the variables
it uses) and reproduce it; do not restyle. Positions are the 1920 x 1080 page's, in `dp`.

## RCSS / RmlUi: what differs from CSS

- **Every document links `nui://open77/open77.rcss` first**, then `lightrp.rcss`, then its own
  sheet. RmlUi has no default stylesheet: without it `body` has no size and every `div` is
  inline (full-screen roots come out 0 x 0, text wraps one word per line, a backdrop-filter
  plate takes the whole screen).

```html
<head>
    <link type="text/rcss" href="nui://open77/open77.rcss"/>
    <link type="text/rcss" href="lightrp.rcss"/>
    <link type="text/rcss" href="example.rcss"/>
</head>
```

- No `var()`, no `calc()`, no `inset`, no `::before` / `::after`, no `clip-path`, no
  `@media`, no CSS grid. Flexbox works (`gap` too). Write `position: absolute` with
  `left/top/right/bottom`.
- Units: `dp` everywhere (never `px`). `em` and `%` work.
- Chamfered corners (`clip-path: polygon(...)` in the page): `decorator: fx(chamfer <cut>
  <hairline> <fill opacity> 0 <hairline colour>)`, or `fx(chamfer-solid ...)` for a
  filled shape with a transparent `background-color`.
  The parameters are `chamfer(cut dp, hairline dp, fill alpha, glow dp)`. It cuts the
  **top-right and bottom-left** corners; the page's `--clip-chamfer` cuts top-left and
  bottom-right and `--clip-notch` top-right only: when the corner matters, draw the plate
  on a mirrored background child (`transform: scaleX(-1)`) or with a `<path>`.
- Shadows on text: `font-effect: shadow(1dp 1dp #000000)` / `glow(...)` / `outline(...)`,
  not `text-shadow`. On boxes: `box-shadow` works; `filter: drop-shadow(#000 0dp 2dp 3dp)`
  (colour first).
- Gradients are decorators: `decorator: linear-gradient(90deg, #a 0%, #b 100%)`,
  `radial-gradient(...)`; several decorators are comma separated.
- Transitions name the tween, not a bezier: `transition: width 0.3s cubic-out;`
  (`linear`, `quadratic-in-out`, `cubic-out`, `back-out`, `sine-in-out`, `elastic-out`...).
  Animations: `animation: 0.9s sine-in-out infinite name;` (duration first).
- **Text directly inside a flex container is not drawn**: wrap it in a `<span>` / `<div>`.
  Text in `inline-flex` is not drawn either.
- Flex children shrink to nothing under long content: give fixed parts `flex-shrink: 0`.
- `pointer-events` is not inherited: `body { pointer-events: none }` is in
  `lightrp.rcss`; an interactive element sets `auto` itself.
- A percentage width inside an absolutely positioned shrink-to-fit element resolves
  against the screen: size rows by content or give the parent a width.
- `backdrop-filter` is still drawn at `opacity: 0`: hide with `visibility` or `display`.
- `opacity: 0` on a container does not reliably hide its children: an animated child
  (a blinking dot) and children styled before the change kept drawing (the flatline
  cover's header showed through the downed screen). To hide a subtree, use `visibility`.
- The document *is* `<body>`: selectors and `ui:class("body", ...)` do not match it. Wrap
  everything in a root `<div>`.
- SVG: `<path d="..." view-box="0 0 24 24" class="ic"/>` with `fill`, `stroke`,
  `stroke-width` (always in dp, whatever the view box), `stroke-dasharray`,
  `trim-start` / `trim-end` (0..1 along the path, animatable: a gauge is `trim-end`).
  `<shape type="circle|rect|ellipse|polygon|star|chamfer">` for primitives. No `<svg>`,
  no `<circle>`: a circle is a path (`M14 50a36 36 0 1 0 72 0a36 36 0 1 0 -72 0z`).
- Data binding: `{{name}}`, `data-if`, `data-for="item : items"`, `data-class-x="expr"`,
  `data-style-width="pct + '%'"`, `data-attr-d="icon"`, `data-event-click="fn(args)"`.
  In RML attributes write `&amp;&amp;`, `&lt;`; prefer `25 > x` to `x &lt; 25`.
  Shrinking a `data-for` array can read removed rows for a frame: replace the whole array.
- Images: `<img src="img/x.png"/>` relative to the document, or a `data:` URL; every file
  must be declared in the manifest's `files` (`ui/native/**` is).

## Reference documents (validated in game)

- `resources/standalone/op77_map3d/ui/native/` + `client/native/` (this repo): the Light RP
  look on NativeUI, icons, anchors, theme layer.
- open77-base `resources/gamemodes/freeroam/ui/hud.rml|rcss` + `client/hud.lua`: a vitals /
  weapon HUD driven by a data model at 10 Hz.
- open77-base `resources/system/open77_chat`, `open-voice`, `open77_contextmenu`: page
  adapters (`client/ui.lua`) that keep a WebUI resource's Lua unchanged.
- A model variable named `size` is refused ("Name is reserved"), and with it the whole model: every other binding of that document then fails. Tween names are `linear-in-out`, never `linear`; `ease`, `steps()` and `cubic-bezier()` do not exist.
- An absolutely positioned child of an auto-height flex container gets no height from
  `top`/`bottom`: make the container a block, or give it a height.
- A `data-for` array that shrinks makes RmlUi read the removed rows once more ("Could not get
  value from data variable 'rows[3].x'"): keep bindings off the repeating element itself (put
  them on an inner child), or never shrink the array (pad with rows flagged off).
- Two animations (or a transition and an animation) on one element animating the same
  property: the second is refused. Split them over a wrapper and its child.
- Image paths: `/web/img/...` (from the resource root), not `../../web/...`.
- Text put into a document with `ui:rml` / `ui:insert` / `ui:create` is markup: escape `& < > "`
  and break `{{` / `}}` (RmlUi reads them as a data binding even in plain text). Text given
  through a data model (`{{name}}`) needs neither.
- The built-in Chakra Petch has no italic face: `font-style: italic` logs "No font face defined".
