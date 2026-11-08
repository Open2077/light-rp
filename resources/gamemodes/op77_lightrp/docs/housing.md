# Housing: apartments, houses and instances

Housing uses MySQL and the LightRP compact menu. Homes and interior templates
are created in game and persist without editing any Lua files.

## Player access

- **F1 → My homes** or **E** in front of an entrance. Each home the player owns (or holds a key for)
  has its **My home** marker on the map, and a home's details page offers **Set GPS to the entrance**.
- **At this entrance** lists every apartment in the building: several
  homes can share the same outside point.
- Lists have a search and pages of ten homes. The map
  shows the 32 nearest entrances, refreshed as you move.
  Apartments behind the same door share one marker.
- Buying or renting requires standing at the entrance. The displayed price must be
  confirmed, and the payment is taken from the **bank account**.
- A rental is paid in advance in **real days**. Renewal is manual,
  adds one period to the expiry date and uses the home's current rate.
  Nothing is ever charged automatically.
- The resident can lock/unlock the entrance and give or revoke
  keys to other online characters. Keys persist after disconnect.
- An unlocked door lets visitors in. The storage and the wardrobe are
  reserved for the resident and key holders.
- **E** at the exit takes you back to the outside point. **Leave** (root of F1 → My homes) also gets you
  out, especially after a failed load.
- A purchased home can be sold back to the server, by default for **50% of the price
  actually paid**. Giving up a rental or an assignment refunds nothing.

When a rental ends, on a resale or on an admin revocation,
occupants are sent outside and keys stop working. Leftover items
are kept in the old contract's storage: **My homes → Recover
stored belongings**, from the old entrance, lets you take them back (withdraw
only). A new resident gets a different storage. Deleting the home does not delete
these belongings.

## Creating an interior

Permission: **`command.lightrp.housing`**. Roles with
`command.lightrp.*` or `*` already have it. Open **/admin → Housing** or
`/housingadmin` with an active character.

1. Go to an existing, walkable interior. Housing puts players
   and network objects in instances; it does not build geometry. An interior coming from a
   mod must be declared as a required mod of the server.
2. **Interior templates → Create interior template**: enter the name and the
   storage capacity in slots and kilograms.
3. Stand at the arrival spot, facing the way you want, then choose
   **Capture spawn here**. The server records the real position and heading.
4. Capture **exit** and **storage** separately, leaving enough room so that
   their interactions do not overlap.
5. Optionally capture **wardrobe**. This point uses the existing LightRP
   wardrobe; it can be deleted without deleting the interior.
6. **Preview private instance** lets you visit the template in a test
   instance. **Leave** (F1 → My homes) brings you back exactly to where you started.

The menu keeps movement and camera controls. Only the forms
take the mouse and keyboard. A template is usable once the three
required points are captured. The points must stay within the configured radius around
the arrival (200 m by default).

Residents must leave before you move a template's points or edit
its capacity. A new capacity applies to **future contracts**: it never
shrinks an existing resident's storage. A template used by a home
cannot be deleted.

## Creating and assigning a home

1. Stand in front of the outside door, in the public instance.
2. **Dwellings → Create dwelling here**: pick a finished interior template
   (search and paging available), then name the home and choose
   **Apartment** or **House**.
3. Set the purchase price, the rent and the length of one period (1 to 90 days).
   **0** disables buying or renting, respectively. With both at 0, only admins
   can assign the home.
4. Leave the home enabled so its entrance shows. Each home you create
   gets its own instance, even when its template and door are shared.
5. **Assign a resident** gives the home for free, with no expiry, to an
   online character. **Assign an offline character** takes the Open77 player
   ID and the saved character's key; both are checked to exist.

An occupied home must be freed first. **Revoke current tenancy** requires
a reason, keeps the belongings and issues no refund. Wait until the
occupants have left the instance before **Delete dwelling**. You can also
move a vacant home's entrance and change its rates, its
name or its template. Changing the template or disabling a home requires the current
contract to end.

## Persistence and configuration

The file [`server/config/housing.lua`](../server/config/housing.lua) sets:

| Setting | Default |
|---|---:|
| Maximum active homes | 1,000 |
| Homes per character | 5 |
| Simultaneous occupants per home | 16 |
| Extra keys per home | 12 |
| New template capacity | 40 slots / 150 kg |
| Rental period offered | 7 days |
| Rent payable in advance | 365 days maximum |
| Resale | 50% of the price paid |
| Maximum native load time | 30 seconds |

Reserve buckets `bucketBase + homeId` for housing. Previews
use `bucketBase + 50000000 + playerId`. Do not reuse these ranges in
another resource.

Tables created automatically: `lightrp_housing_templates`,
`lightrp_housing_properties`, `lightrp_housing_contracts`, `lightrp_housing_audit`.
Storage uses `lightrp_inventories`, under `housing:<contract-id>`.
Back up these tables together with characters, accounts and bank transactions.

The server checks permissions, active character, distance, instance, home
revision and storage rights. Payment, contract, home and bank receipt are
written in the same transaction. An error never creates a free home
and never charges for a purchase that was not recorded. An unreadable database blocks housing
without replacing existing homes with vacant ones.

Disconnecting inside a home saves the outside entrance as the next
spawn point. A character must leave their instance before switching
slot. A death frees the instance and puts the player back in the public world for
the usual hospital handling.

## Developer check

From the LightRP root:

```powershell
python tools/test-housing.py
cd ui
npm run build
```

The first test uses the real housing, inventory and economy modules with
an isolated temporary MySQL database, created then dropped. Among other things it checks
interrupted transactions, the two instances, key revocation, expiry,
resident changes and recovery after a home is deleted.
It also checks a catalog of 1,000 homes and templates, search and the
edge pages, as well as message size with Unicode names.

For the menus, run Vite on `127.0.0.1:5196`, then
`python tools/test-housing-ui.py`. This test uses Chromium and mocked server
replies; it complements the SQL test and does not replace in-game testing.
It covers keyboard navigation, forms, purchase confirmation,
search, next pages, and going from the menu to the storage without closing
the inventory when the server reply arrives late.

Local validation on 6 October 2026, on a separate test database and ports:

- Two clients fully spawned in the same interior, at the same coordinates,
  in instances `1000001` and `1000002`.
- Purchase of the first home and rental of the second, with bank debits.
- Each storage open to its residents; the second home's resident was refused when
  trying to open the first home's storage, including from inside their own interior.
- Back outside, then the admin menu and the storage opened in game.
- After disconnect: outside position saved for both characters,
  contracts read back by the persistence module, and three water bottles kept.

The homes from these tests were not added to the regular server's database.
Paging and search were validated in Chromium and by the SQL tests.

After installing or changing client/WebUI files, reconnect the
players (`reload_policy "reconnect"`). Creating and editing homes in
game needs no restart.

## Starter studio (end of the first day)

Talking to Mara at the end of the guide ("Take me home") gives the character
a **Kabuki Studio** (free assignment, `assigned` contract) and
teleports them straight inside. Configuration:
`server/config/housing.lua` → `LightRpHousing.starter`, module
`server/modules/housing_starter.lua`.

- One studio per character, each in its own instance (bucket), all
  behind the same street door (`entrance`, label `building`). Players only
  see their own; admins see them all.
- The interior is the `kabuki_appart1` map, which the server must load
  (`server.local.jsonc` loads it, `server.jsonc` does not yet).
- The interior template is written **only once** from the config; after that,
  `/housingadmin → Interior templates → Kabuki Studio` lets you recapture the
  storage, the wardrobe, the arrival or the exit, and those captures take precedence.
- A released studio (My homes → Release) is reassigned to the next newcomer.
- It does not count toward `maxProperties`; the cap is `starter.maxUnits`.
- When no studio is possible (data storage unavailable…), the guide falls back to the
  city arrival as before.

## Waking up at home

`wakeUpAtHome = true`: a resident (owner or tenant) who disconnects
inside their home wakes up there on the next connect. The flag
is stored in the contract (`asleep`) and consumed on arrival; the saved
position stays the street door, so a failure brings you back in front of the building.
Test: `tests/run-lua.ps1 -Test housing_starter_test.lua` (pwsh 7).
