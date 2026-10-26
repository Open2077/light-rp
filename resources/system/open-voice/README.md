# open-voice

This resource gives players three voice ranges (whisper, normal and shout) that they cycle with F11, and a small HUD line that shows the active range and whether they are talking.
`open-voice` is a compact, pma-voice-inspired reach-mode companion for the
native OPEN//77 voice stack. It depends on `open77_voice`, which remains the
only owner of microphone capture, PTT/VAD, Opus, routing, playback and network
media. This package never reads PCM/Opus and never calls `setTransmitting`.

- **Docs:** [Integrated voice chat](https://open2077.net/docs/voice)
- **Starts:** on its own
- **Needs:** `open77_voice`
- **Runs on:** server and client

## Defaults

The server owns and validates every mode in `server/config.lua`:

| Mode | Distance |
|---|---:|
| `whisper` | 3 m |
| `normal` | 20 m |
| `shout` | 40 m |

F11 cycles the modes by sending `open-voice:cycle` to the authenticated server.
The server rate-limits the request, chooses the next mode from its own current
state, and applies it through `Open77.voice.setProximity`. The client never sends
or applies an arbitrary distance. Names, labels, colors, distances, default mode,
key and cooldown are checked at server resource load; invalid configuration
fails the resource rather than silently weakening policy.

Supported cycle keys are A-Z, 0-9, F1-F12, SPACE, ENTER/RETURN and the arrow
keys. Input is ignored while another WebUI captures the keyboard.

## HUD states

### Range preview (LightRP)

After a confirmed F11 range change, a yellow **3D ground ring** shows the actual
server-applied radius (3 / 20 / 40 m by default) around the local player for
three seconds. It follows the player; another change resizes the same marker
and restarts the timer. Other players do not see it. Initial/replayed state and
rejected changes do not flash a ring. HUD blockers also remove the preview;
death, resource stop and disconnect clean it up.

This uses the native `Open77.anchors` ground ring renderer, not another WebUI
or an audio change. The accent and duration live at the top of
`client/range_preview.lua`. There is no idle polling, streamed mesh/material or
per-frame recolouring. Unsupported client APIs produce a deduplicated console
warning without interrupting voice. Custom ranges up to 50 m are represented
exactly; larger ranges keep working for voice but have no preview (ring API limit).

The renderer projects a circle defined in world metres and samples the ground
and occlusion along it. Uneven terrain/obstacles can hide parts of the ring;
it is a range guide, not an audibility guarantee (routing/mute still apply).

### Voice activity

The 60 fps HUD is one compact line in the bottom-right corner with no panel or
background: a mic glyph tinted by state, a twelve-segment input meter, the
active range with its distance in the range's colour, the cycle key, and a
pulsing "heard" counter that only appears while someone is audible. States:
`idle` (grey), `detected` (cyan), `talking` (mint, glowing mic), `muted` (red,
slashed mic, meter dark), `offline` (dark grey, slashed). A server rejection
shows as a red line above it for a few seconds. `setHudVisible(false)` hides
the whole line.

## Client integration

Other client packages can call `getState()`, `getModes()`, `requestCycle()` and
`setHudVisible(visible)` through `Open77.exports.call("open-voice", ...)`.
`open-voice:modeChanged(mode, distance, label, color)` is emitted locally after
each canonical server response. `open-voice:cycle` and
`open-voice:setHudVisible` are equivalent local events. None of these APIs can
submit an arbitrary distance; reach remains server-owned.

Full-screen flows can emit the local event `open-voice:setHudBlocked(reason, blocked)`
using a stable, resource-prefixed reason (for example `op77_lightrp:onboarding`).
Blocking hides the WebUI surface immediately, without waiting for the cosmetic fade.
The HUD returns only after all reasons are released and `setHudVisible` still allows
it. Release your reason when the flow finishes and on resource stop; reapply it when
`open-voice` starts again. This only affects the indicator, never microphone capture.

Trusted server packages can emit
`open-voice:setPlayerMode(playerId, modeName)` or
`open-voice:cyclePlayerMode(playerId)`. After a canonical application,
`open-voice:modeApplied(playerId, modeName, distance, label, color)` is emitted
locally on the server. These are local events, not registered network events.
