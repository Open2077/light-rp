# op77_fireworks

Staff fireworks shows and server-wide announcements for Light RP, with an
opening-night macro over **The Crossing** (the Westbrook esplanade where every
newcomer arrives). Server only: every shell is fired by the server, so
everybody sees the same show at the same moment.

Ported from `base/resources/examples/rp_fireworks` (MIT, see `LICENSE`).

## Commands

One restricted command: the platform checks **`command.fireworks`** before the
handler runs; the dedicated console is always allowed.

```text
/fireworks [show] [place|here]              now; a player's default is over them, the console's is the hub
/fireworks in <delay> [show] [place|here]   scheduled, with countdown announcements
/fireworks opening [delay] [place]          opening night: announcement, countdown, finale, closing line
/fireworks announce <text>                  banner + chat line to every player
/fireworks stop                             stop the running show and cancel the scheduled one
/fireworks cancel                           cancel the scheduled show only
/fireworks status                           what runs, what is scheduled, shows and places
```

A delay is minutes (`10`, `2.5`) or has its unit (`90s`, `5m`), from 10 s to
3 h. One show runs at a time and one is scheduled at a time; a new one replaces
the old. Shows: `burst` (~10 s), `finale` (~45 s), `celebration` (confetti,
indoor-safe). Places: `crossing`, plus anything added to `server/config.lua`.

## Exports (synchronous, never yield, answer `true` or `false, reason`)

```lua
exports.op77_fireworks:play("burst", "crossing")            -- a place keeps its own bucket
exports.op77_fireworks:play("burst", { x = 1, y = 2, z = 3 }, bucket)
exports.op77_fireworks:playFor(playerId, "celebration")     -- over a player, in their bucket
exports.op77_fireworks:schedule("finale", "crossing", 600)  -- seconds
exports.op77_fireworks:opening(300)
exports.op77_fireworks:announce("ARENA NIGHT", "The arena opens at 21:00.")
exports.op77_fireworks:stop()
exports.op77_fireworks:status()
```

## Announcements

There is no announce export or event in `op77_lightrp` (its `/lightrp.announce`
is a command, `LightRP.broadcastNotice` is internal), so this resource uses the
platform's own channels, no client script: an `announcement` row in chat
(`Open77.chat.broadcast`) and a banner from `open77_notifications`
(`Open77.notifications.broadcast`, top centre). The countdown is one banner
updated in place. Set `announce.lightrpEvent` in the config to also raise a
host-wide event `{ title, body, kind, durationMs }` once the gamemode handles one.

## The client effect budget

Every server-driven effect lands in one client quota (192 slots, shared by
every resource) and a shell holds a slot while it lives. Before a show runs, its
beats are **sliced** (at most 8 per server tick, the rest 60 ms later) and
**budgeted** (at most 60 alive at once, counting 10 s per shell; extras are
thinned, never delayed). A thread that falls behind never fires more than one
slice per tick. The presets fit untouched (peaks: burst 37, celebration 18,
finale 39), which `tests/fireworks_test.lua` checks.

**Shell mode.** In the current client source a world one-shot
(`Open77.effects.play`) arrives with no duration and keeps its slot until the
player leaves the world. So by default (`shellMode = "registry"`) a silent shell
is a registry entry (`Open77.effects.create`, `ttlMs` 10 s) that the server
retires. Only the shells carrying the boom stay one-shots (3 per burst, 10 per
finale). `shellMode = "oneshot"` is rp_fireworks' behaviour. To choose, run the
debug bridge's `effects.list` on a client after a show: spent one-shots still
listed mean the leak is real.

## Tests

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <server>/lua54.dll
```
