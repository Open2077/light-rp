# Prod configuration snapshot (Light RP Testing, Germany)

`server.jsonc` and `acl.jsonc` here are copies of the files the prod server runs with
(`/opt/op77-lightrp`), taken on **2026-11-04 ~01:30 CET** (prod `server.jsonc` dated
2026-11-04 00:19, `acl.jsonc` 2026-11-03 20:50). The owner asked for them on 2026-11-04 so
that a change to the repo's own `server.jsonc` / `acl.jsonc` can be compared with what prod
really loads, instead of discovering the gap in game.

**They are a reference, not something to deploy.** Redacted before anyone read them:

- every environment-variable name, the signing key file and the master public key: `"<redacted>"`;
- the public endpoint's address: `<ip>`;
- ACL principals: account ids `"<redacted>"`, staff names `<staff-N>` (only `owner` kept).

## The deploy rule

Prod is a plain file copy of `main` (no git there). When copying `main` over it:

1. **Never copy** the root `server.jsonc`, `acl.jsonc`, `server.local.jsonc` or any `.env` file:
   prod keeps its own.
2. Diff the repo's root `server.jsonc` / `acl.jsonc` against this folder and port **by hand**
   what prod lacks (a new resource in `resources.load`, a new `startup.commands` entry, a new
   convar, a new ACL permission). `resources.load` is a silent allowlist: a resource missing
   from it never starts and logs nothing.
3. After a hand edit on prod, refresh this snapshot (same redactions) so it stays true.

## Differences at the snapshot

- `resources.load`: prod also loads `winter_in_nc` and `open77_pedestrians` (the repo does not).
- ACL: prod's `operator` role lacks `command.lightrp.tables` (the repo has it).
- Prod convars thin the pedestrian crowd and keep pedestrians 40 m away from the spawn
  (`open77_pedestrians_*`, added for the `playback_timeout` animation failures of 2026-11-04).
- Prod keeps `httpHandlers.enabled = false`: the events board TV page is not served there.

## To port by hand after the snapshot

- **2026-11-05, game maps (`/lightrp.maps`):** no ACL change where a role holds
  `command.lightrp.*`; a role with an explicit list needs `command.lightrp.maps`. The tables
  `lightrp_game_maps` and `lightrp_game_map_marks` create themselves, and the maps that used to ship
  in `op77_games` are imported once, on the first start with the database up and `op77_games`
  running: the load order of the two does not matter, but until then no game is offered. The
  import is logged (`game maps: import done: 22 map(s)`).
- **2026-11-05, minigames and game rooms:** add `op77_games` to `resources.load`, after
  `op77_lightrp` (a silent allowlist: without it the new games never register and the rooms
  menu simply does not list them). The rooms NPC at The Crossing needs no entry.
- **2026-11-04, economy decisions:** one staff money grant is capped at 10 000 €$
  (`/lightrp.givemoney` and the staff desk's Credit, a reason is now required). The bypass is
  the permission `lightrp.money.unlimited`, deliberately outside `command.lightrp.*` so the
  moderator and operator wildcards do not grant it. The owner's `"*"` covers it; add it to a
  principal or role only for staff who must credit more in one go.
