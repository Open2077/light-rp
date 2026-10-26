# RP animation browser

The dedicated right-hand panel leaves the world visible. It uses the existing
`open77_animations` service and its live catalogue; it does not copy native
animation data or invent local-only emotes.

## Player controls

- **F3** opens the browser. **F1 → Animations** and **/anim** also open it.
- **Escape / F3** closes it. Selecting an animation does not start it: use **Play
  animation** so you can choose its exact variant and duration first.
- **X** stops playback (including a pending start), without opening the panel.
  Both native bindings can be changed in the pause menu's key-binding settings.
- Search names, clip variants or common French aliases; filter categories; use
  the grid or list layout. Only categories available on the server are shown.
- Star an exact variant to save it. Recent animations are recorded after the
  platform accepts playback, never on an unsuccessful click.
- Select a variant, choose **Assign selected**, then one of the four quick slots.
  Clicking a filled slot or pressing the corresponding **1–4 key while browsing**
  starts that variant. Empty slots assign the selected variant. The number row
  also works on AZERTY without Shift. Typing in search never triggers a slot.
- Favorites, recent variants, slots and layout are saved in native client KVP,
  scoped to the server, resource and authenticated account. They survive resource
  downloads/reconnects and are independent of the temporary CEF cache. Browser
  previews use localStorage as a fallback. Storage failures are shown explicitly.

The panel closes before playback to return mouse and keyboard control to the
game. A small non-interactive status badge shows the current animation, remaining
time for timed playback, and the actual rebound stop/browser keys. Stationary
workspots use the platform's temporary third-person presentation and automatic
props. Furniture-dependent poses require positioning by suitable furniture;
the browser does not spawn chairs or teleport the player.

## Integration and safety

`client/core/animations.lua` binds the shared LightRP WebUI; the React feature
lives in `ui/src/features/animations`. The adapter uses only the public Promise
API (`list`, `request`, `state`, `cancel`) and canonical playback events. The
platform owns replication, late joining, native props and camera cleanup.

Catalogue messages contain at most four profiles each. The browser commits only
complete revisions and rejects stale or malformed batches. Variant and duration
inputs are checked against the live catalogue before calling the platform.
Serial/revision guards prevent late Promise replies from reviving cancelled UI
playback. The service also cancels abandoned pending requests.

F3 closes on release, with a native debounce: it cannot immediately reopen the
menu by leaking its still-held key into the game. Embedded Chromium may omit
`KeyboardEvent.code`; quick-slot input also accepts logical digits and AZERTY
number-row characters. Search fields are excluded from all quick-slot input.

Creation, welcome, inventory/dialog focus and timed job/consumption actions take
precedence. X never cancels a LightRP consumable or job. Taking a different dialog
closes the animation panel without releasing that dialog's focus. Playback errors
are shown in the panel and as a notice because playback normally closes the panel.
The voice-range HUD is suppressed only while this panel is open and restored
on close/playback/resource stop, including if the voice resource restarts.

No native client build or protocol change is required. Build the UI into a
staging directory and copy only `app.js` / `app.css` into the resource to preserve
its existing item, job and vehicle assets. The resource's reconnect reload policy
requires clients to reconnect after deployment.

## Checks

- `tests/animations_client_test.lua`: catalogue batching, validated variants and
  durations, focus release before play, canonical state, pending cancellation,
  stale messages, protected actions, readiness and resource teardown.
- `ui/tests/animations.browser.cjs`: atomic catalogue revisions, search, variants,
  persisted favorites/slots/history, keyboard input, other-menu precedence,
  responsive layouts at 720p, 1080p, 1440p and ultrawide. Cards must scroll rather
  than compress and crop their labels.

Actual animation availability depends on the installed system resource. The local
LightRP installation has 76 stationary profiles; newer walking-layer profiles
will appear automatically if the platform catalogue is upgraded. This interface
does not claim that every authored clip/body-family combination is verified.

Live local acceptance (2026-09-23): F3 open/close, real 76-profile catalogue,
Arms crossed playback, temporary TPP and restored FPP, X stop, AZERTY quick slot 1,
favorites/slot restored after a fresh connection with a different player ID,
voice-HUD suppression and working inventory after animation playback. Build and
Lua/browser regressions pass. LightRP local was restarted; no CDN or remote
deployment was performed.
