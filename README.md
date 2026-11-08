# Open//77 Official Roleplay — Light RP starter

Starter project for an OPEN//77 **Light Roleplay** server: the official server distribution
(Windows x64 or Linux x64, the latest is named in <https://cdn.open2077.net/server/latest.json>)
extracted here, a ready-to-use configuration, an ACL, and
the `op77_lightrp` framework (characters, proximity chat, needs, civilian vehicles, hospital, staff) with
its global React + TypeScript WebUI, styled with the Open//77 RP design system.

```
E:\Open77\LightRP
├── Open77.Server.exe, *.dll        official distribution (not versioned)
├── server.jsonc                    production configuration (master + licence)
├── server.local.jsonc              local test profile (no master, no licence)
├── acl.jsonc                       in-game rights: helper/moderator/operator roles, owner
├── server.env.example              environment variables to copy into server.env
├── Start-LightRP.cmd               production start (reads server.env)
├── Start-LightRP-Local.cmd         local start
├── templates\op77_lightrp\         template for the first-install wizard
├── ui\                             WebUI source (Vite + React + TS) → builds into resources\...\op77_lightrp\web
└── resources\gamemodes\op77_lightrp\  the framework (see its README)
```

Only the configuration, the ACL, the start scripts, the template, `ui/` (without `node_modules`) and
`resources/gamemodes/op77_lightrp` are tracked by git (`.gitignore` works as an allowlist). The binaries
come from the zip.

## WebUI

The framework page is built with Node 20+: `cd ui && npm install && npm run build`. The
output (`web/`) is committed, so a fresh clone starts without Node. `npm run dev` opens the page in
a browser with a mock bridge, so you can work on the design without the game.

## Running locally (today)

1. Database (optional but recommended): a local MariaDB/MySQL with an `open77_lightrp`
   database. `server.env` already holds the connection string for this machine's MariaDB.
2. Double-click `Start-LightRP-Local.cmd`. The server listens on loopback: game `127.0.0.1:11828`,
   resource downloads `11829`, Warden `http://127.0.0.1:11830`.
3. On first start, the console shows `Warden setup PIN: ########`. Open Warden, enter the
   PIN and create the administrator account.
4. Connect with the Open//77 client using the development preset (the launcher's "Local development"
   source, or a direct connection) to `127.0.0.1:11828`.

The local profile accepts unauthenticated clients (`devLocalAuth`) and refuses to run in
public: it is a sandbox.

## Going to production

1. **License**: create an `op77_live_…` key at <https://open2077.net/account/keys> and paste it
   into `server.env` (`OP77_LICENSE_KEY=`). Without a key, `server.jsonc` refuses to start.
2. **Database**: create a dedicated database and user (template in
   `server.env.example`), then fill in `OP77_DATABASE_CONNECTION`.
3. **Address**: in `server.jsonc`, `network.publicEndpoint` = `PUBLIC.IP:11828` and
   `resources.download.publicBaseUrl` = the URL players use to reach port 11829.
   Open 11828/UDP and 11829/TCP. Recommended: a TLS proxy (Caddy, nginx) in front of 11829, with
   `publicBaseUrl` in `https://`, then `allowInsecureHttp: false`.
4. **Visibility**: switch `identity.visibility` from `unlisted` to `public` once everything responds.
5. **Warden**: stays on `127.0.0.1:11830`. Reach it through an SSH tunnel
   (`ssh -L 11830:127.0.0.1:11830 user@server`) or behind a TLS proxy. Never over plain HTTP
   on the Internet.
6. `Start-LightRP.cmd` (or a service that runs `Open77.Server.exe --config server.jsonc --no-setup`
   with the same environment variables).

On Linux, the same layout works with the `linux-x64` archive and `./Open77.Server`.

## In-game rights

`acl.jsonc` defines three roles (`helper`, `moderator`, `operator`, taken from `open77_admin`) and
two principals: the owner (`*`) and `w0dm4n` as `operator`. To add someone:
Warden → *In-game rights* → *Known identities* → *Rights*, or by hand in the file, then
`acl.reload` in the console. You can read a player's identity with `identity.dump` in their game
console, or in Warden.

The framework's staff-only commands live under `command.lightrp.*`.
`/admin` now opens the RP desk (ACL `command.admin`); `/adminfull` keeps
the official technical console. Reports have their own rights:
[staff desk and ticket tracking](resources/gamemodes/op77_lightrp/docs/admin-support.md).

## Playing

Inventory pistols, 30-round boxes and two-hand equipping
come with a [prototype guide and its native limits](resources/gamemodes/op77_lightrp/docs/armament.md).
No weapon or ammo is granted automatically on connect.

**1–5** use the items in the first row of your pockets; hold **Tab**
to show the [hotbar](resources/gamemodes/op77_lightrp/docs/hotbar.md).

An unconscious player waits at least **90 seconds** before they can give up.
Another player can stabilize them in **8 seconds** with a `trauma_kit`:
[medical system](resources/gamemodes/op77_lightrp/docs/medical.md).

**F1** opens the player menu; on first connect, the creation flow
walks through identity, appearance and arrival in the city. Normal chat is in-character speech within 20 m, `/ooc` for
out-of-character, `/me` `/do` `/try` `/roll`, `/car <model>` and `/dv` for a vehicle, `/report` to
open a private case followed by staff. Details and settings in `resources/gamemodes/op77_lightrp/README.md`.

## Optional: the Chimera raid

The "Chimera Protocol" raid needs the `open77_chimera` resource, which is not in the server
distribution. Without it the server starts normally and the raid board answers "The Chimera is not
deployed on this server." To turn the raid on, copy
[`gamemodes/open77_chimera`](https://github.com/Open2077/open77-resources/tree/main/gamemodes/open77_chimera)
from open77-resources into `resources/gamemodes/` and restart: the configurations already list it
in `resources.load`.

## Updating the server

The zip is a fresh install, not a migration. Stop the server, back up `server.jsonc`,
`acl.jsonc`, `server.env`, `.open77/` (Master identity and resource signing key) and the
database, extract the new archive on top, put those files back, and restart. The `op77_lightrp`
framework is not in the archive: it stays untouched.

## Restyled platform packages

`resources/system/open77_contextmenu` (ALT + click menu), `resources/system/open-voice` (F11 voice indicator), `resources/system/open77_chat` (T chat) and `resources/system/open77_wardrobe_ui` (wardrobe) are copies from the distribution whose `web/` page was rewritten in the Open//77 RP design system (tokens and fonts are copied into each `web/`, because a WebUI page only loads files from its own resource). The Lua ↔ page protocol is unchanged. They are tracked here: after a server update, check with `git status` that the new distribution did not overwrite `web/`, and replay the commit if needed.

## Ports used

| Port | Protocol | Role |
|---|---|---|
| 11828 | UDP | Game |
| 11829 | TCP | Resource downloads by players |
| 11830 | TCP | Warden (loopback) |
