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
