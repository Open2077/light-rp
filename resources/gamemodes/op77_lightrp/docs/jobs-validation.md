# Job Center validation — 2026-09-21

## Automated

- TypeScript typecheck and production Vite build: passed. Fonts and three WebP artworks are present in the built resource. Vite emits the existing static `fonts.css` build-time warning; the file is copied from `ui/public` and served correctly.
- `ui/tests/jobs.browser.cjs`: passed. Three artworks load; hover and keyboard expansion do not hire; explicit confirmation; duplicate-click guard; unrelated response isolation; hire/start/cancel; HUD; focus/voice-dialog lifecycle; empty jobs; reduced motion; 1920×1080, 1280×720, 1024×600 and 800×900 layouts.
- `tests/job_runs_test.lua`: passed with the actual jobs/economy/run modules and deterministic native/SQL boundaries. Three routes; minimum work duration; step/token replay; server prices; distance/life/bucket/character/DB/desk guards; cancellation/expiry; transactional receipts; failure/retry; payment locks; disconnect in flight; permanent service exit.
- `tests/job_runs_client_test.lua`: passed. Objective lifecycle, native RGBA marker shape, stable GPS, debounce, menu guard, progress callbacks, server cancellation, stale work and cleanup.
- Full Lua test sweep: **13/14 passed**. Existing `rental_test.lua:45` still assumes five stock entries; the current configured rental stock differs. No rental implementation or catalogue changes were made in this job pass. This unrelated fixture was left intact.

## Real game

One client connected to LightRP on `127.0.0.1:11828`, using `server.local.jsonc` for the autonomous tests. Actual appearance/bootstrap completion, alive player and screenshots were checked. The normal `server.jsonc` ticket policy was not changed.

- Opened the employment desk with E, navigated all three jobs with the keyboard, accepted AC Cleaner through the real confirmation UI and started the run through its button.
- AC Cleaner: actual service access to the test deck, three timed operations, return lift and dispatch completion. Server logged a single **260** bank payment; balance 850 → 1110.
- Scrapper: cancelled an action with Escape, retried, completed all three work steps and returned to dispatch. Single **220** bank payment; balance 1110 → 1330.
- Sanitation: completed all three work steps and returned to dispatch. Single **180** bank payment; balance 1330 → 1510.
- Test rewards were removed with the restricted money command (660 total), original unemployed job restored and player returned to the saved pre-test position. No inventory items were granted or consumed by these work orders.
- Confirmed cleanup balance: cash 50, bank 850. Disconnected the test client and restarted the server with its original `server.jsonc` profile; persistence, employment desk, UDP listener and Master registration succeeded. Rejoin normally through the launcher.
- Corrected a native marker color contract issue found in the first game pass. Moved the mission HUD below the minimap. Replaced one unsuitable temporary ground point with the existing City Center wardrobe location.

**Test boundary:** staff teleport was used between the temporary work points to test the actual E/action/receipt pipeline efficiently. This is not a claim that permanent walking routes or real HVAC placements were surveyed. The AC test deck uses one placeholder work position for its three tasks. The owner will supply final locations.

Local screenshots: `ui/artifacts/jobs-ingame-ready.png`, `jobs-key-confirm.png`, `jobs-ac-progress.png`, `jobs-ac-paid.png`, `jobs-scrap-cancel.png`, `jobs-scrap-paid.png`, `jobs-sanitation-paid.png`. Automated viewport captures are also in `ui/artifacts` (ignored by Git). Server evidence is in `.open77/ui-rework/server-jobs-final.out.log` and `server-jobs-verified.out.log` (not committed).
