# Action UI — progress, hold and timing checks

Client-side interaction kit for future Light RP jobs. Yellow/black, compact bottom-centre widgets, keyboard-only interaction, animated progress and explicit success/failure/cancellation feedback. No job, payout or item mutation is bundled with the kit.

## Try it

- Browser: run `npm run dev -- --host 127.0.0.1` in `LightRP/ui`, then open `http://127.0.0.1:5177/?registered=1&actions=1`.
- In-game, staff: `/lightrp.uitest progress`, `circle`, `hold`, `timing` or `sequence`. `/lightrp.uitest cancel` stops the preview. Requires `command.lightrp.uitest`; the existing operator/moderator wildcard covers it.
- Nothing appears automatically. The browser playground is absent from the game.

## Inside the gamemode (client Lua)

```lua
local id, reason = LightRpActions.progress({
    label = "Repair the engine",
    description = "Replacing the damaged components.",
    icon = "wrench",
    durationMs = 6000,
    style = "bar", -- "ring" for circular progress
}, function(result)
    if result.status == "success" then
        -- Continue local presentation or ask the job SERVER to validate completion.
        -- Never award money/items purely because the UI succeeded.
    end
end)
if not id then print("Action refused: " .. reason) end
```

`LightRpActions.hold(options, callback)` uses the same options, plus `key = "E"` and `release = "reset" | "cancel"`. Releasing either resets progress (default) or cancels. A fresh press is required: opening a widget while E is already down cannot complete it accidentally.

```lua
local id, reason = LightRpActions.skillCheck({
    label = "Calibrate the relay",
    description = "Stop the cursor inside the yellow zone.",
    steps = {
        { difficulty = "easy", key = "E" },
        { difficulty = "normal", key = "R" },
        { difficulty = "hard", key = "E" },
    },
    maxMistakes = 0,
}, function(result)
    print(result.status, result.reason, result.hits, result.score)
end)
```

Timing checks use one cursor pass per step. Missing the zone or letting the cursor pass counts as a mistake. Extra keys are ignored; key repeat cannot score multiple steps. There is a 400 ms preparation period and 450 ms feedback between steps. The hit position is calculated at the instant of the press, not from the previous rendered frame. The striped zone and instructions make the target identifiable without colour alone.

## From another client resource

Declare `"op77_lightrp >=0.2.0"` as a dependency. Exports are synchronous start requests: they return an action ID or `nil, reason`, not the final outcome.

```lua
local pending
exports("onRepairFinished", function(result)
    if result.id ~= pending then return end
    pending = nil
    if result.status == "success" then
        -- Send your server-held job ticket, not a client-supplied reward amount.
    end
end)

local reason
pending, reason = exports.op77_lightrp:ActionProgress({
    label = "Repair the engine", durationMs = 6000,
    onFinish = "onRepairFinished", -- an export on THIS calling resource
})
```

Functions cannot cross Open77 resource VMs. Use the `onFinish` export name, **not a function**, for cross-resource calls. A function callback is supported only by the internal `LightRpActions.*` facade.

| Client export | Purpose |
|---|---|
| `ActionProgress(options)` | Start a timed bar or ring. |
| `ActionHold(options)` | Start a hold-to-complete action. |
| `ActionSkillCheck(options)` | Start a single/multi-step timing check. |
| `ActionCancel(id)` | Cancel a caller-owned action, even when player cancellation is disabled. |
| `ActionIsActive()` | Whether any action currently occupies the kit. |
| `ActionResult(id)` | Read a caller-owned finished result, or `nil, reason`. Last 32 retained for this running generation. |

Internal equivalents: `progress`, `hold`, `skillCheck`, `cancel`, `isActive`, `result`. The local event `lightrp:action:finished` also carries the result (not a network event). Owner stop releases focus but does not call the stopped owner's export. Results belong to the resource **and generation** that started them.

## Options

| Option | Default / contract |
|---|---|
| `label`, `description` | `"Working"`, `""`; plain text, max 100 / 180 bytes. |
| `icon` | `"wrench"` or `"zap"`; bundled icon name, no remote asset. |
| `style` | `"bar"` or `"ring"`. Timing always uses its precision track. |
| `durationMs` | 5000; 250–300000. Used by progress/hold. |
| `key` | `"E"`; A–Z, 0–9 or `"SPACE"`. Step key can override it. |
| `cancellable` | `true`. Escape cancels; false still allows forced cancellation on focus loss, death, etc. |
| `allowMovement` | `false` (full keyboard capture, no cursor). True keeps gameplay input and selectively consumes Escape/interaction keys. The current native API accepts navigation keys only: progress supports this mode, hold/QTE support `SPACE`, but E/R/other letters or digits are rejected with `unsupported_consumed_key`. Use the default for letter-based QTEs. Does not freeze/unfreeze the character or change animations. |
| `release` | `"reset"`; hold only, or `"cancel"`. |
| `steps` | Timing only, 1–12 entries. Defaults to easy/normal/hard; strings or tables. |
| `maxMistakes` | 0; integer smaller than the number of steps. Failure occurs when the budget is exceeded. |
| `timeoutMs` | Automatically bounded for the interaction. Explicit values must cover its full nominal duration and be ≤600000 ms. Hold's default allows time to retry. |
| `onFinish` | Optional callback export on the calling resource. |

Step tables accept `difficulty = "easy" | "normal" | "hard"`, `key`, `durationMs` (700–10000), `zoneWidth` (.05–.5 of the track), and `zoneStart` (.1 to .9 minus width). Defaults are 2600/2000/1450 ms and .24/.16/.09 width. The zone is randomly placed at the start of each action unless supplied explicitly.

## Results and lifecycle

```lua
{ id = "1:7", status = "success", reason = "completed",
  elapsedMs = 5420, hits = 3, mistakes = 0, score = 94 }
```

`status`: `success`, `failed`, `cancelled`. Reasons: `completed`, `cancelled`, `released`, `too_early`, `missed`, `timeout`, `focus_lost`, `interrupted`, `dead`, `owner_stopped`, `ui_timeout`.

`score` is 0–100 timing precision averaged across all steps; misses count as zero. It is 0 for non-timing interactions. Results fire once; stale/duplicate page messages are ignored. Focus is released before callbacks, so a callback may immediately start another action. Visual result feedback lasts 1.4 seconds without capturing input.

Only one action runs at a time (`busy` on overlap). Start is refused before WebUI/character readiness or when a Light RP menu/dialog owns focus (`ui_unavailable`, `character_not_ready`, `ui_busy`). Invalid configuration returns `invalid_*`. Another resource cannot cancel or read your action (`not_owner`). Opening another framework screen, losing focus or dying cancels it. A Lua watchdog releases focus if the page never acknowledges or stops responding. No animation, entity freeze, money, inventory or job state is altered by cancellation.

## Authority for future jobs

This is a **client presentation contract**, not an anti-cheat or proof of work. The job server should issue a single-use action ticket and validate its expiry, minimum elapsed time, player life state, position/bucket, job membership, required items and cooldown before consuming inputs or granting rewards. Invalidate tickets on disconnect/death and reject duplicate completions. Even a perfect QTE report is untrusted client input.

## Checks

From `LightRP/ui`: `npm run build`, `node --experimental-strip-types --test tests/actions-model.test.ts`, then `node tests/actions.browser.cjs` with Vite running and Playwright available (`PLAYWRIGHT_MODULE` can point to an existing installation). Browser checks cover 720p–ultrawide layouts, CEF-style keys, hold/reset, failure/success/cancel, focus conflicts and duplicate results.

Lua: `lua tests/actions_test.lua` from the gamemode directory, or on Windows `pwsh -File tests/run-lua.ps1` using the server's existing `lua54.dll`. The tests stub engine/bridge calls and never contact a server or database.
