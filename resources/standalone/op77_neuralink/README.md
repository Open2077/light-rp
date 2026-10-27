# op77_neuralink — the Neural-Link

In Night City nobody carries a smartphone: the Neural-Link is an implant that
projects a holographic interface in front of the eyes. This resource is a
complete neural phone for Open77 roleplay servers:

- **an implant to install first**: a character starts without one; F2 then shows
  a Kiroshi diagnostic seen through the player's eyes, over the game dimmed
  behind dark glass: the eyelids open, the ocular suite boots, a WebGL wireframe
  scan of the head finds no Neural-Link and waits for Install or Cancel. The
  installation then runs the uplink, cortex mapping, optic nerve and spinal
  binding, the implant docking on cortical port C7 and a hologram self-test
  (about 22 seconds, faster with reduced motion), and the eyelids close on the
  interface. Each beat has its Cyberpunk 2077 sound (generated cue table:
  `neuralink-ui/src/implant/sounds.ts`). A refused installation stops on a fault
  panel with Retry.
  `config.implant` turns the requirement off or leaves the
  installation to a ripperdoc resource (exports `install`, `uninstall`,
  `isInstalled`);
- **a phone line per character** (`NNN-NNNN`), assigned on first use and kept
  in MariaDB; with `op77_lightrp` the line follows the active character, without
  it the account;
- **contacts** (favorites, online status);
- **messages**: direct conversations and **groups** (2 to 15 other members,
  owner, rename, add/remove, leave, system messages), unread counters, offline
  delivery;
- **voice calls**: outgoing, incoming (networked 3D ringtone that the callee and
  bystanders hear), **group calls**, adding participants mid-call (up to 6),
  mute, call history (recents, missed calls);
- **voice inside the call** through a native `phone` voice channel with a
  neural-implant effect; speaking during a call is also heard around the player
  (the normal push-to-talk sends to proximity and to the call);
- the game's **blue holocall eyes** on everyone connected to a call;
- **Screamsheet**, the players' social network: screams of 280 characters
  stamped with the Night City district they come from, replies, echoes and
  quotes, Street Cred, #tags and @mentions, profiles with followers, three feeds
  (Pulse, Crew, Hot), pings, search and **Net Heat** (trending tags and district
  activity); moderation with `/screamsheet.delete <id>` and player reports;
- an **app system**: other client resources add their own apps to the menu.

The interface is built from
`E:/Open77/LightRP/neuralink-ui` into `web/` (`npm run build`). The contract
between the page and the client Lua is [PROTOCOL.md](PROTOCOL.md). Two looks, chosen
in Settings > Display (`settings.style`): **Night City** by default (navy glass, cut
corners, cyan lines, red selection, octagonal buttons, glitch transitions;
`src/styles/cyberpunk.css`) and **Aincrad**, the original SAO-style white glass.

## Use

| Key | Action |
|---|---|
| `F2` (rebindable: Pause > Settings > Key bindings) | Open / close the interface |
| Mouse | Everything in the interface; the player keeps walking while it is open |
| Typing in a field | The keyboard goes to the interface (the player stops); Escape leaves the field |
| Push-to-talk (`N` by default) | Speak in a call |

## Server configuration

`shared/config.lua`: key, limits (contacts, message length, group size, call
participants), rate limits, ring duration, the call voice effect, the ringtone
radius and files. Every sound (`audio/*`, all played from Lua: interface, ringtones,
implant installation) is a Cyberpunk 2077 UI or phone sample (extracted from a local
install). All mono; ringtones keep their full length, which is their declared duration (the server
loops them with it). The samples' rights stay with their holders: replace them
before any public or commercial release.

Requires `open77_voice` and a database (`database.access`). Tables: `nl_lines`,
`nl_contacts`, `nl_threads`, `nl_members`, `nl_messages`, `nl_calls` (created at
start). Ids are integers or VARCHAR — never CHAR(36), which the server's driver
reads back as a GUID.

## Exports

Server:

```lua
exports.op77_neuralink:getNumber(playerId)          -- "NNN-NNNN" or nil
exports.op77_neuralink:getPlayerByNumber(number)    -- player id or nil
exports.op77_neuralink:notify(playerId, title, body) -- a system toast on their interface
exports.op77_neuralink:closeInterface(playerId)     -- put their interface away (a gamemode panel needs the screen)
exports.op77_neuralink:isInstalled(playerId)        -- the player's line has an implant
exports.op77_neuralink:install(playerId)            -- true | false, reason (a ripperdoc installs it)
exports.op77_neuralink:uninstall(playerId)          -- true | false, reason (ends a call in progress)
```

Client:

```lua
-- An app in the Neural-Link menu; `event` is a local event fired with the app id.
exports.op77_neuralink:registerApp({
    id = "bank", label = "Bank", icon = "landmark", color = "#f5c518",
    event = "mybank:openFromNeuralink", closeOnLaunch = true,
})
exports.op77_neuralink:unregisterApp("bank")
exports.op77_neuralink:open({ app = "messages", threadId = 12 })   -- deep link
exports.op77_neuralink:close()
exports.op77_neuralink:isOpen()
```

`icon` is a [lucide](https://lucide.dev) icon name. Apps of a resource that
stops disappear with it.

## LightRP bridge

`op77_lightrp/server/modules/neuralink_bridge.lua` exports
`characterIdentity(playerId)` and emits the host events
`op77_lightrp:characterReady` / `op77_lightrp:characterChanged`; this resource
attaches the line of the active character on those events.
