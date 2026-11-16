# open77_preflight

The server check every server ships with. When a player presses **Join** in the OPEN//77
launcher, the launcher asks the server "may this player come in?" before it starts the game;
this resource is the default answer. It shows a welcome screen on the server's page, turns
Warden bans and the whitelist into proper pages (reason, "Banned until ... UTC", the player id
to give to the staff, a whitelist application form), and can ask for rules to be accepted, a
linked Discord account, or tell players about maintenance and a full server.

- **Docs:** [Connection preflight](https://open2077.net/docs/connection-preflight)
- **Starts:** on its own
- **Needs:** nothing. A `server.jsonc` that does not name `preflight.resource` uses it.
- **Runs on:** server

## What it does out of the box

- Welcome screen: the server's name, description, player count and whitelist state.
- A banned player reads why, until when, and their player id, instead of one sentence.
- With the whitelist on, an unlisted player can apply from the launcher. The request appears in
  Warden (*Whitelist & bans > Requests*), at the console (`whitelist.requests`) and through the
  exports; approving it lets a player who is still waiting straight in.
- A ban, an unban or a whitelisting made in Warden, at the console or from Lua reaches a player
  who is on the launcher's screen at that moment.

Bans and the whitelist are not stored here: they are the server's own door list
(`access.json`), the one Warden edits.

## Settings

Edit `config.lua`, then `ensure open77_preflight` at the console. No server restart.

| Section | What it switches on |
|---|---|
| `links` | Your Discord, appeal and website links on the screens (https only). |
| `welcome`, `announcements` | The welcome screen's title and text, and short news lines. |
| `rules` | Rules accepted once per player; bump `version` to ask everybody again. |
| `discord` | Refuse accounts without a linked Discord (verified by the master server). |
| `whitelist` | The application form, its question, invite codes that whitelist at once. |
| `maintenance` | Refuse everybody with a message, except the ids you list. |
| `full` | A waiting screen (or a refusal) when the server is full. |
| `bans` | Whether a ban page shows the reason and the staff member. |
| `api.trusted` | Which resources may call the exports that list or change the door list. |
| `greeting` | A short screen for admitted players right before the game starts. |
| `ui` | Your own screens, values every screen gets, and a resource that completes them per player. |

## Console

```
preflight.status
preflight.maintenance on [message] | off | default
preflight.announce <text> | clear
preflight.rules.reset [userId]
```

## Exports

```lua
local door = exports.open77_preflight

door:ban(userId, "Griefing", 86400, "Judy")   -- seconds; 0 or nil = permanent
door:unban(userId)
door:isBanned(userId)                          -- open to every resource
door:whitelistAdd(userId, "V")
door:whitelistRemove(userId)
door:isWhitelisted(userId)                     -- open to every resource
for _, request in ipairs(door:requests("pending")) do door:approve(request.userId) end
door:deny(userId, "Applications are closed this week.")
door:kick(playerId, "AFK for too long")       -- a player id or an account id
```

Also: `getBan`, `bans`, `whitelist`, `whitelistEnabled`, `setWhitelist`, `getRequest`,
`refusals`, `sessions`, `maintenance`, `setMaintenance`, `hasAcceptedRules`, `resetRules`.
Everything goes through `Open77.access`, so Warden shows the same state, with
`resource:open77_preflight/<your resource>` as the actor. The exports that list or change
anything answer `nil, "caller_denied"` unless `config.lua` names the calling resource in
`api.trusted`.

## Screens

`ui/*.rml` are written in the launcher's markup subset ("NativeUI Lite"): edit the text and the
styles freely, keep the `{{ ... }}` bindings and the `data-event-click` names. A screen that is
not well-formed XML is not sent; the player then gets the plain message.

The screens are `welcome` (the server page), `rules`, `apply` (the whitelist form), `refused`
(every refusal page, told apart by `kind`), `full` (the waiting screen) and `greeting`.

## Your own look

Keep this resource's logic and change what it shows, in `config.lua`:

```lua
greeting = { enabled = true, seconds = 5 },   -- 0: wait for the button
ui = {
    documents = { welcome = "ui/custom/welcome.rml", greeting = "ui/custom/greeting.rml" },
    data = { tagline = "Roleplay in the dark future." },
    provider = "my_gamemode",                  -- optional, see below
},
```

- **Documents**: a screen you name is read from that file of this resource; the others stay the
  shipped ones. Start from the shipped file: same bindings, same event names. If yours cannot
  be sent (not well-formed, over 64 KiB, missing), the shipped one is used and the log says why.
- **Images**: put them in `ui/custom/` (png, jpeg, webp; the manifest serves that folder) and
  show them with `<img src="asset:ui/custom/banner.jpg" style="width: 1600px; height: 400px;"/>`.
  Give both sizes: the launcher keeps the ratio and shrinks the picture to the page.
- **Data**: `ui.data` is added to every screen's data.
- **Provider**: a server resource of yours that completes each screen for the player who sees it
  (their characters, their last visit...). Before showing a screen, this resource calls its
  export asynchronously and merges the table it returns into the screen's data:

  ```lua
  -- my_gamemode: screen = "welcome" (no player) | "rules" | "apply" | "refused" | "full"
  --              | "greeting" | "allowed"; may query a database
  exports("preflightScreen", function(screen, context)
      if GetInvokingResource() ~= "open77_preflight" then return nil end
      if screen == "welcome" then return { residents = 1284 } end
      local userId = context.player.userId          -- the verified account id
      return { character = "Kira Tanaka", allowedMessage = "Welcome back, {character}." }
  end)
  ```

  `context` is `{ screen, server = { name, players, maxPlayers, whitelist }, player = { userId,
  name, ticket, discord? }, locale?, kind? }` (`kind` on refusal pages). The welcome is asked
  again every 15 seconds. `allowedMessage` in the answer replaces `config.lua`'s line for that
  player; `{key}` in either is filled from the screen's data. Lists follow the shipped rule:
  never send an empty one, send a `has...` flag beside it. A provider that errors, is stopped or
  takes longer than `ui.providerTimeoutMs` (1500 ms) only means the screen is shown without its
  values: nobody waits for it.
- **Greeting**: data `message` (the allowed line), `left` (seconds before the game starts,
  counting down) and `counting`; the button sends `enter`.

## Fail safe

If this resource errors or stops, a player the door list admits is allowed and a player it
refuses reads the server's plain sentence. The in-game handshake checks the door list again
whatever happened here.
