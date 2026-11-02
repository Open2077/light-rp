# op77_chase_hud — NCPD Chase overlay

The overlay of `op77_chase`. A transparent WebUI surface on the `hud` layer, top centre: role,
clock, round and score, the arrest or escape meter, the gap (runner only), hints (boarding,
crash stall, head start) and a centre card for the countdown, the round result and the match
result. While queued, a one-line strip ("/chase leave to cancel").

It draws what the server sends (`op77_chase:hud`, `op77_chase:queue`) and nothing else: no
key, no input, no part of Light RP's own HUD. Empty outside a chase or a queue.

Plain HTML/CSS/JS, no build step. Browser preview: open `web/index.html?demo=active`
(`countdown`, `intermission`, `resolved`, `queue`).

Test: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests\run-lua.ps1 -LuaDll <path>\lua54.dll -Test hud_client_test.lua`
