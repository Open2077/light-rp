# RP staff desk and reports

## In-game access

- `/admin` (and `/lightrp.admin`) opens the **LIGHT/RP** admin menu, in the same
  spot as the player menu. It is the server's only admin menu: it
  combines the platform's old compact menu and the staff desk (see
  "Unified admin menu" below).
- `/report` and `/reports` open the player's private cases.
- `/report message` opens a new, prefilled draft. The player fills in
  the category and subject before sending.
- **F1 → Reports & support** gives access to the same tracking. The staff entry shows up
  depending on the account's rights.
- **↑ / ↓** select a row, **Enter** opens the submenu or the action.
  **← / →** change filters and checkboxes.
- **Backspace / Esc** go up one level, then close at the root.
  The selected row is kept when you come back.
- Movement and the camera stay available in lists. The keyboard
  and cursor are captured only while you type in a form.
  **Esc** leaves that form and returns to the menu.
- Conversations and records appear in a side panel. **Page Up /
  Page Down** scroll its details. The **Conversation** row lets you
  hide this panel while you handle a case.
- `/adminfull` keeps the official technical console, with its usual ACL.

`op77_lightrp` registers `/admin` itself (right `command.admin`, the same as
the platform). The server looks up a command across running resources in
ordinal name order, and `op77_lightrp` comes before `open77_admin`: so
this menu is the one that answers. The platform's compact menu no longer opens on top.
No change to `open77_admin` is needed, and a
distribution update breaks nothing. Without LightRP, the official `/admin` remains available.

## Unified admin menu

Platform tools and LightRP tools are launched from the menu as
the restricted commands they already are (`open77:command:execute`). So the host
ACL decides on each one, as if it were typed. The page grants
nothing: the overview sends the list of commands allowed for
the operator (`server/modules/admin.lua`, `COMMANDS`, a single string) and hides
the rest. Each command's reply shows under the menu, in green if it
succeeded, in red if it was refused.

| Section | Content |
| --- | --- |
| Reports | case queue (unchanged) |
| Players | RP record, then go to / bring / spectate / heal / revive / send to a place; groups **Moderation** (audited warning, kick and ban, god mode, kill), **Character & money** (audited name, job, affiliation and money, hunger and thirst, street cred, account), **Give** (weapon + ammo of its type, ammo, their weapons and ammo, remove a weapon they are not holding, item, vehicle to the garage, vehicle next to them), **Missions & activities** (gig, current mission, contracts, TCG room) |
| Personal tools | ghost mode, noclip, fly, speed, god mode, heal, revive, hunger and thirst, account, platform console (`/adminfull`) |
| Teleport | on the map (double-click), coordinates, places from `LightRpConfig.locations`, bring everyone |
| Vehicles | LightRP catalog (`lightrp.car`), any game record, repair and refuel (`lightrp.repair`), refuel only, impound, rentals, fuel consumption, cleanup, delete all |
| Items & weapons | **Weapons** by class (with ammo of its type; the weapon arrives in the weapon wheel), **Ammunition** by type or all, your own weapons and ammo, then every other item by category |
| World | **Time** (presets, exact time, freeze, resume), **Weather** (each weather, next, random), **Announcements & voice** (announcement, server voice broadcast / 150 m / off) |
| Missions & events | mission editor; **Staff events** (cyberpsychos, gang attacks, world bosses wherever you want, event nights, spots: [staff-events.md](staff-events.md)); **World bosses** (schedule, launch, launch the selected one, schedule one, end as a win, cancel), **Fixer gigs**, **Contracts & activities** (daily contracts, activities, turf, Dogtown, TCG rooms) |
| Places & content | placed tables, Maneki-neko, housing, safe zones, job board, guide NPC, hall of fame |
| Server | LightRP and platform status, ambient bots, bring everyone, delete all, undo the mass action, platform console |
| Staff history | log of audited interventions |

**Everything runs right away** (owner's choice, 2026-11-05: "it has to
be fast"): no confirmation step, no reason to type. Actions
with no field (go to, bring, heal, kick, warn, kill, go to a table, delete
it, a Maneki, end or cancel an event, launch and start an event
night…) run as soon as you press **Enter**; the others only show their useful fields
(amount, ban length, name…) then **Apply / Run**. Staff history still
records every intervention, with a default line in place of the reason. The lists (vehicles,
items, places, weathers) come from `adminCatalog`, as `a|b|c` rows
to stay under the 1024-value limit of a network event. Right-clicking
a vehicle or a door (`open77_contextmenu`) still opens the platform's
targeted actions.

Test: `tests/admin_menu_test.lua` checks the `/admin` registration, the
ACL projection, the catalog size and `/lightrp.repair`. In dev, the menu
opens with `ui` + `?admin=1`.

## Player / admin flow

1. The player creates a report: category, subject, description and optionally
   another online player. The server records the account, the character,
   the position and the instance. Evidence links can be pasted into the
   text; there is no attachment upload.
2. Authorized admins get a notification. **Take this case** assigns
   the case to the admin and sets its status to **In progress**. The player sees
   who is handling it and whether that admin is online.
3. Both sides reply in the conversation. **Ask player for information**
   waits for an answer; the player's reply puts the case back in progress.
4. **Internal staff note** adds a private note, sent only to
   accounts that have the right to view reports.
5. The assigned admin or a supervisor explains the resolution, then uses
   **Resolve case**. The player can also close their own case with a reason.
6. Finished cases stay viewable with **Finished / All cases**.
   The owner can ask for a reopening, with a reason, for seven days.
   A reopening puts the case back in the queue with no assigned admin.

Replies, assignments, statuses and notes persist across disconnects and
restarts. The owner is the **Open77 account**, regardless of the character
slot. The names of the character and of the reported player are the ones at the time
of the report. Transferring to another online admin requires an extra
right. Leaving the server does not automatically unassign a case.

| Status | Meaning |
|---|---|
| `open` | Waiting for staff to take it |
| `in_progress` | Case taken / player reply received |
| `waiting_player` | Staff is waiting for more details from the player |
| `resolved` | Resolution explained by staff |
| `closed` | Case closed with a reason |

The queue offers search by number, subject or name, a status filter, cases
assigned to you, normal/urgent priority and an unread indicator. Player and staff
read states are independent. Changes are pushed to the people
involved; a refresh every twelve seconds backs this up.

## RP records and interventions

**Citizens** shows the character, account name, job, affiliation
and life state. The record adds RP identity, backstory, cash,
bank, position and permitted history. The selection also keeps the account
and slot: if the player number is reused or the character changed,
the intervention is refused and you need to refresh.

Depending on permissions: go to a player, bring them, send them back to the
position before the last staff move, heal/revive, rename,
change job/grade or affiliation, credit/debit cash or bank, warn,
kick, ban temporarily/permanently, post an announcement.

Each intervention asks for a reason and a confirmation that shows the target
and the chosen values. RP changes wait until character creation
is finished. Moves between instances are refused. The return
position is limited to the current session and is lost on reconnect.

The intent is saved **before** the action in `lightrp_staff_audit`, then
its result (`success`, `failed`, `pending`). A `pending` state means you
must check the situation before trying again. Retrying the same request does not
credit the money again. The history keeps the author, the target, the character,
the reason, the parameters and the result. Warnings are kept
in this history; they do not trigger any automatic sanction.

## Placed tables

**Placed tables** (right `command.lightrp.tables`) lists every placed table
(board games and casino tables): ID, type, owner
character and inventory ID, online or not, position, instance,
placement date, revision, seated players, phase and open bets (or *Resolving*
during a draw). Pages of 15, sort by recent / nearby, search by
ID, type or owner.

- **Go to table**: teleport next to the table, facing it, via
  `LightRP.staff.moveTo`. From a private instance to a city table,
  you arrive in instance 0; a table in another private instance is refused.
- **Remove table** (right `command.lightrp.tabledelete`): same rules as
  pickup by the owner. Open bets are refunded; it is refused while
  a wheel or reels are spinning; the blackjack dealer disappears; seated
  players are stood up with a notification. *Give the item back* returns
  the item to the owner character's inventory in the same transaction;
  if they are offline (or the inventory is full), it is delivered the next time that
  character loads.

Reason and confirmation required, audit in `lightrp_staff_audit` before and
after the action (`tableTeleport`, `tableDelete`), visible in **Staff history**.
Equivalent commands: `/lightrp.tables [page | near]`,
`/lightrp.tables tp <id>`, `/lightrp.tables delete <id> [return]` (the server
console can list and delete). Details: `docs/board-games.md`.

## Events (staff event modes)

**Events** (right `command.lightrp.events`) launches world bosses, cyberpsychos and
gang attacks wherever staff want (their position, a player, a saved spot, or
a world boss's home location), at three levels, either for fun (nothing is paid or
counted) or paid like a world boss (right `command.worldboss.start`). It also lists
running events (go and watch, end as a win, cancel), chained event nights
(Psycho Night, Boss Rush, Gang War, Siege), saved spots and the random world boss
toggle. Every action is audited (`eventLaunch`, `eventStop`…).
Equivalent command: `/lightrp.event`. Details: `docs/staff-events.md`.

**Ghost mode** (`/lightrp.ghost [on|off]`, `server/modules/staff_ghost.lua`): noclip, body
hidden from other players (`Open77.players.setVisible`, reapplied every 2 s because the platform lifts it
on death, respawn and instance change), no nametag and no dot on the map. The
ghost list goes to every client (`op77_lightrp:staff:ghosts`), which removes them from the map
(op77_map3d) and from nametags (op77_playermarks, along with players in PvP). The noclip is the platform's
`/admin.self.noclip` command, run by the ghost's client: the ACL still decides.
Right: `command.lightrp.ghost` (staff have `command.lightrp.*`).

The **Noclip**, **God mode** and **Advanced console** personal tools reuse
the native commands and their permissions. Their logging stays that
of the official package; `lightrp_staff_audit` covers RP desk interventions.
The old staff commands remain available.

## Server permissions

Rights come only from the host ACL. The browser supplies
no authoritative role or identity. Every read and mutation
is checked on the server, including after asynchronous SQL reads.

| Permission | Access |
|---|---|
| `command.admin` | Desk, citizen list and RP records |
| `command.lightrp.reports` | Staff queue, conversations and private notes, taking cases |
| `command.lightrp.reportassign` | Transferring and managing other admins' cases |
| `command.lightrp.audit` | Staff intervention history |
| `command.lightrp.goto` | Go to a player |
| `command.lightrp.bring` | Bring / send back a player |
| `command.lightrp.heal` | Heal / revive |
| `command.lightrp.setname` | Rename the character |
| `command.lightrp.setjob` / `setgang` | Job / affiliation and grade |
| `command.lightrp.givemoney` / `takemoney` | Credit / debit (credit: reason required, at most 10,000 €$ per grant) |
| `lightrp.money.unlimited` | Credit above the per-grant cap (`/lightrp.givemoney` and desk) |
| `command.lightrp.warn` | Warning |
| `command.admin.moderate.kick` / `ban` | Kick / ban |
| `command.lightrp.announce` | Server announcement |
| `command.lightrp.tables` | Placed tables: list and teleport |
| `command.lightrp.tabledelete` | Placed tables: delete |
| `command.lightrp.events` | Events: launch, stop, spots, event nights, unpaid |
| `command.worldboss.start` | Paid events, random world bosses |
| `command.admin.self.noclip` / `god` | Personal tools |
| `command.adminfull` | Technical console |

Short suffixes in this table keep the prefix of the first permission.

Staff money grants (owner's decision of 2026-11-04,
`docs/economy-balance.md` §16, `staffGrants` settings in `server/config/economy.lua`):
`/lightrp.givemoney <id|me> <cash|bank> <amount> <reason>` refuses a grant without a reason
of at least 4 characters (it replies with the usage); the reason becomes the note on the
`staff` line of the ledger (`lightrp_transactions`, 160 bytes at most). A grant can exceed
10,000 €$ only if the giver holds **`lightrp.money.unlimited`**; the server
console is not capped. The desk's *Credit* follows the same rule (its audit reason
of 4 to 500 characters is cut to 160 bytes for the note). This permission
is deliberately **not** under `command.lightrp.*`: moderator/operator roles
that hold that wildcard do not get it; only `*` (the owner) or an explicit line
in `acl.jsonc` grants it, for example for an "owner" role:
`"lightrp.money.unlimited"`, then `acl.reload`. Debit (`takemoney`) is not
capped.
For a minimal support role, grant `command.admin` and
`command.lightrp.reports`. Add `command.lightrp.reportassign` only
for supervisors. The generic `command.lightrp.*` permission includes these new
rights; existing moderator/operator roles already have them. The current helper
role is not extended automatically: add the reports right explicitly
in `acl.jsonc` if you want it, then run `acl.reload` on the server. The helper role in the example `acl.jsonc` gets
`command.lightrp.tables` (list and teleport, no delete).

The gamemode manifest uses `players.disconnect` and `players.access` for
sanctions. Bans go through the server's persistent access list,
on the account identity, and disconnect its sessions. Warden / the official
console remain available for managing unbans.

## Storage and limits

Server configuration: `server/config/support.lua`.

- Three active cases per account, creations and reopenings included.
- One minute between two successful creations.
- Reopening allowed for seven days after resolution / closing.
- Subject from 4 to 120 characters, description from 10 to 2,000 characters.
- Messages limited to 2,000 characters; intervention reasons to 500.
- Lists of 25 cases, history loaded in blocks of 50 messages.

Creations/reopenings from the same account are serialized, even from
two sessions. A single revision per ticket protects concurrent status
and assignment changes; on a conflict, refresh before sending again.
Write requests carry a deduplication key. The draft stays on screen
on failure; closing the panel on purpose discards it.

Tables: `lightrp_support_tickets`, `lightrp_support_messages`,
`lightrp_support_reads`, `lightrp_staff_audit`. Old rows from
`lightrp_reports` are imported at startup, with their handled flag,
without deleting the original table. The import can be repeated without duplicates.
An unavailable database blocks writes and audited interventions, without
showing a fake success. Back up these tables with the rest of the RP database.

## Validation

- `python tools/test-tables-admin.py`: pickup restricted to the owner
  character, list, teleport, delete (refunds, dealer,
  players stood up, deferred item return), permissions and commands.
- `python tools/test-support.py` from the root: real Lua modules and
  MySQL transactions in a dedicated temporary database, dropped at the end of the test.
  Requires `pymysql`, `lupa` (Lua 5.4) and local access that can create this
  database. Settings are read from `server.env` without being printed.
- `tests/creator_bridge_test.lua`: keyboard priority, closing, voice hiding,
  support relay and compatibility with the character editor.
- `ui/tests/support.browser.cjs`: RageUI menus, navigation stack, kept
  selection, switching between navigation and typing, creation, replies, error with the draft
  kept, reopening, notes, RP record, confirmation, history and four
  screen sizes. `UI_URL` points to the built page and
  `PLAYWRIGHT_MODULE` can point to a Playwright install.
- `npm run build` from `ui`: TypeScript check and WebUI production build.

In game, check with one player and one admin: `/report`, taking the case in
`/admin`, public reply, private note not visible to the player, resolution,
reconnect and viewing the finished case.

### Staff-given weapons

`server/modules/armament_admin.lua` handles weapons given by staff.

**Commands**

| Command | Effect |
| --- | --- |
| `/lightrp.giveweapon <id\|me> <weapon> [ammo]` | gives a weapon and, optionally, ammo of its type; `<weapon>` accepts `weapon_lexington`, `lexington`, the record or the display name |
| `/lightrp.giveammo <id\|me> <pistol\|rifle\|shotgun\|sniper\|all> <ammo>` | gives loose ammo |
| `/lightrp.takeweapon <id\|me> <weapon>` | removes a copy they are not holding |
| `/lightrp.weapons <id\|me>` | shows what their wheel lists and their ammo by type |

Rights come from `command.lightrp.*`. A grant is capped at 2000 rounds.

**Why the weapon shows up in the wheel:** a given weapon is a real serialized item. Its serial number is created in the inventory transaction (`armament_store`), in the same write as its ammo. Then:

- the player's weapon wheel refreshes right away;
- a weapon in hand loads the new ammo immediately.

**Avoid:** the platform's native weapons (`admin.weap.give`, `/adminfull` console) are not LightRP items. The projection takes them back, and they do not show up in the wheel.

Test: `tests/armament_admin_test.lua`, which uses the real inventory and serial number registry.
