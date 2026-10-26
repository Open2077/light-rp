# Safe zones and the staff menu

Open `/admin` → **Safe zones**, or `/safezones` with the direct-command
permission. The manager uses the same keyboard-driven RageMenu shell as the
staff and player menus, without a separate inspector, form or mouse-driven page.

## Controls and authoring

- **Up/Down** selects a row; **Enter** opens it or toggles a checkbox.
- **Left/Right** changes shapes, checkboxes, the adjustment step and numbers.
- **Backspace/Escape** goes back. Leaving a modified zone asks whether to keep
  editing or discard the unpublished draft.
- **Enter** on Name, Search or a number edits that menu row directly. Type the
  replacement, then Enter applies it or Escape cancels. Ctrl+A selects all;
  Delete clears the value. Gameplay keys are captured without a cursor until
  typing ends. No separate text form opens.
- **F9** switches world/menu; **F10** captures the server-observed position.
  Both ignore presses during row typing. They use normal rebindable mappings.

Choose **Create a zone**, set its name and shape, then open **Geometry and
placement**. Cylinders have a radius; oriented boxes have length/width/heading.
The centre and floor/ceiling support arrows and exact keyboard values. The
adjustment step changes arrow increments without limiting exact entry.

**Polygon vertices** adds points at your feet in outline order. Undo the last
point or open any vertex to replace, move or remove it. F10 adds points in the
list and replaces the selected point while its individual submenu is open.

Set **Restrictions**, inspect the outline in the world, then **Publish zone**.
Only you see the private draft. The server validates and persists before
updating live protection. Activation/deactivation is also a draft setting until
published. Duplication starts an independent draft. Deletion has a menu
confirmation and removes only that zone; overlapping zones keep their rules.
View-only staff can inspect all settings without an editing session.

Timed-out writes keep the exact mutation and lock the draft. **Check
publication/deletion** retrieves the result without repeating a new mutation.
Concurrent-edit conflicts never silently overwrite a newer revision.

## Protection, height and restrictions

The server refuses PvP hits if the attacker **or** victim is inside an active
zone in their routing instance, including shots from inside to outside.
Floor/ceiling avoid protecting another storey. **Full height (above and below)**
applies the horizontal outline at every altitude; saved floor/ceiling values
are retained but ignored. Its preview draws a bounded local slice, not infinite walls.

| Setting | Native input action | Existing-zone default |
| --- | --- | --- |
| Block running | Sprint and the existing walk-speed cap | Off |
| Block shooting | Attack | On |
| Block jumping | Jump | Off |
| Block melee | Melee | Off |
| Block grenades | Grenade | Off |
| Block native consumables | Consumable | Off |
| Block reloading | Reload | Off |
| Block weapon wheel | WeaponWheel | Off |

Native consumables mean healing/inhaler hotkeys, not RP inventory food/drinks.
Direct weapon switching stays available; no NextWeapon restriction is applied.
Allowing the native shooting action never disables server PvP protection.
Overlapping rules combine with OR and are published even when a player remains
in the same zone. The effective status sits above the bottom-left vitals and
follows normal gameplay HUD visibility. Claims release on exit, death and stop;
slower preferred walk modes are preserved. The MCP `.156` catalogue marks
Jump/Melee as inferred mappings: verify their native effect in game.

## Access and persistence

Every request checks player ACL: `command.admin.safezones.view`, `.edit`,
`.publish`, `.delete`. Publication requires view+edit+publish; deletion requires
view+edit+delete. `/safezones` additionally requires `command.safezones`.
Resource capabilities such as `combat.config` are separate. No staff privilege
implicitly bypasses the published protection.

Sessions bind the authenticated player, routing instance and server-captured
anchor. They expire after five minutes without capture/heartbeat and invalidate
on instance/access changes or movement beyond 500 metres. The entire published
volume must stay within 500 metres of the anchor.

Limits: 64 non-deleted zones; 3–32 polygon vertices; radius 0.5–250 metres; box
dimensions 0.5–500 metres; finite height 0.1–200 metres; finite coordinates
within ±100,000; polygon horizontal extent at most 500 metres. Duplicate
points, touching/crossed edges and negligible polygon areas are rejected.
Full-height zones retain finite floor/ceiling values without a thickness check.
Missing rule flags receive compatible defaults; no bulk SQL rewrite is needed.

`lightrp_safezones` stores canonical definitions/tombstones, while
`lightrp_safezones_audit` stores idempotent actor/mutation receipts. Zone and
audit commit atomically before cache publication. Revisions, checked affected
rows and a failing audit constraint roll back conflicting SQL updates; a mutex
also serializes yielding mutations. Client-generated Lua is never executed.

The arbiter has no SQL/network/yield calls. It uses normalized geometry and
server positions with explicit instance, `maxAgeMs=2000`, `grace=0`. Unknown
positions in protected instances or arbiter errors refuse the hit. Player-vs-player
damage is refused while initial policy loading is pending. Missing APIs or
invalid stored definitions expose unavailable protection, never a reassuring HUD.
This covers the server PvP pipeline, not automatically every NPC hit, fall,
local explosion or uncredited vehicle impact. No god-mode or post-hit healing
is used; real two-player/native input coverage still requires an in-game test.

## Verification

From the repository root, with `lupa` available:

```sh
python3 tools/test-safezones.py
python3 tools/test-safezones-client.py
```

These exercise actual Lua validation, ACL, rollback/reload, revision races,
arbitration, previews, keyboard focus and cleanup using isolated/mocked services.
For browser verification, install UI dependencies, start Vite separately, then
run the Playwright/Chromium test:

```sh
cd ui
npm ci
npm run dev -- --host 127.0.0.1 --port 5183 --strictPort
# Another terminal, repository root:
node tools/test-safezones-menu-ui.cjs
```

Optional variables: `PLAYWRIGHT_MODULE`, `CHROMIUM_PATH`, `SAFEZONE_MENU_URL`.
The fixture uses `?registered=1&staff=1&safezones=1`; switches
`safezonesLegacy=1`, `safezonesPresence=1`, `safezonesReadOnly=1` exercise
compatibility, effective HUD rules and view-only access. Screenshots go to `/tmp`.
