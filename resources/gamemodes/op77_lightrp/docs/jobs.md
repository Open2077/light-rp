# Item work and employment

Sanitation and Scrapper are free **collect → process → sell** activities. Any
active, living character can use their public points on foot, even while
unemployed or holding another job. There is no shift, mission, ordered route or
completion bonus for these two activities. AC Cleaner retains its work orders.

## Player flow

1. Find a collection point on the map or use the employment office's GPS button.
2. Press **E** once. Collection repeats after each completed progress bar.
   A networked work animation runs continuously between batches, with the
   platform's temporary third-person view. Sanitation searches/sorts on the
   ground; Scrapper dismantles with a screwdriver and processes with a tool.
   Escape, a full bag, missing inputs, death or interrupted playback ends the
   activity and restores the previous camera. Other players see the same
   animation through `open77_animations`.
3. **Escape** stops immediately. Completed batches remain in the inventory.
4. When weight or slots run out, collection stops with a trunk-storage hint.
   Open an unlocked nearby vehicle's trunk (inventory or vehicle context menu)
   and transfer a load. Return to the point and press E to collect again.
5. Take raw goods out of the trunk and press E at the processor. It converts one
   recipe per cycle until materials or output space run out; Escape also stops it.
6. At the matching buyer, E sells the finished goods carried when the action
   starts. After its short progress bar, items and bank credit commit together.

The current bag capacity is **40 kg**, a default trunk **80 kg**. Existing saved
inventories retain their configured capacities. Only carried goods are processed
or sold: processors never remotely pull stock from vehicles. Ordinary temporary
vehicle trunks remain session storage; owned vehicle trunks persist through
parking/retrieval using the ownership ID. Pocket goods persist with the character.

| Activity | Collection per cycle | Processing per cycle | Buyer |
| --- | --- | --- | --- |
| Sanitation | 1 `trashbag`, 4 kg, 6.5 s | 1 bag → 1 `recyclables`, 2 kg, 5 s | €$18 per bundle |
| Scrapper | 4 `scrap`, 4 kg total, 8 s | 4 scrap → 1 `salvaged_parts`, 2 kg, 6 s | €$24 per parts bundle |

Sales take 2.5 seconds and deposit in the bank. Raw goods earn nothing by
collection alone. The existing grade paychecks are separate and unchanged.
Choosing Sanitation/Scrapper as a character's job remains optional at the office.

Commands:

```text
/work sanitation collect
/work sanitation process
/work sanitation sell
/work scrapper collect
/work scrapper process
/work scrapper sell
/work stop
```

The first three stages select the nearest matching GPS point; they never
teleport, start remote work or grant goods. All stages also have public map blips.

## Locations and configuration

`server/config/job_work.lua` owns points, recipes, durations and prices.
Existing coordinates are reused with the following roles (not a travel order):

| Activity / point | X | Y | Z |
| --- | --- | --- | --- |
| Sanitation collection west | -1451.922119 | 1276.606934 | 23.096848 |
| Sanitation collection city | -1066.948486 | -108.389893 | 7.478088 |
| Sanitation processing | -271.248352 | -1566.478760 | 7.620689 |
| Sanitation buyer | 1353.187500 | -1131.332520 | 44.744698 |
| Scrap collection south | 435.379822 | -1354.325317 | 19.512596 |
| Scrap collection north | -1754.117798 | 2074.827637 | 18.156219 |
| Scrap processing | -700.594360 | -935.791931 | 7.369400 |
| Parts buyer | -1243.482300 | 2885.109863 | 7.156265 |

Weights, stack limits and labels are in `shared/items.lua`. The established
`trashbag` and `scrap` IDs/weights are preserved. Finished goods are new templates.
No schema migration or inventory reset is required. Old mission receipts remain
in the database as history, but cannot issue new Sanitation/Scrapper payouts.

Each configured activity supplies `raw`, `collected`, `collectMs`, `input`,
`product`, `produced`, `processMs`, `price`, `sellMs` and `points`. A point has a
unique `id`, `kind` (`collect`, `process`, `sell`), `label` and `position`.
Use valid positive integer quantities/prices and durations, known item IDs,
and reachable locations. Restart the server and reconnect after editing.

## Authority and persistence

- Server-owned recipe, price, point and elapsed duration. Client completion only
  supplies a one-use token and status; injected counts/prices are ignored.
- One active production session per player. Each cycle checks the same active
  character/inventory, life, public instance, on-foot state and 3D proximity.
- Leaving, death, entering a vehicle, switching character, disconnecting or a
  timed-out progress bar ends the loop. Completed goods are not rolled back.
- Input removal and output insertion share a detached inventory draft and one
  SQL transaction. Capacity is checked **after** consuming inputs. A full bag
  may process a lighter recipe; no output space means no materials are removed.
- Commodity recipes and buyers accept plain items only, preserving custom or
  unique metadata. Empty metadata has the same meaning as absent metadata.
- Inventory locks cover yielding SQL, preventing transfers, drops, a second
  recipe or duplicate completion from interleaving. Character switching is
  blocked while a settlement is in flight. Cancellation during that commit
  allows that already-authorized batch to settle, then stops further cycles.
- Sales use the existing atomic inventory + wallet + bank-ledger transaction
  (`shop_sell`). SQL failures leave both stock and money unchanged. A disconnected
  transaction remains bound to its captured inventory/account, never a new player.
- Database unavailable: no new production or sale; no session-only reward fallback.

Internal server APIs: `LightRP.jobWork.preview(job)`, `locate(player,job,stage)`,
`begin(player,pointId)`, `cancel(player)`, `isActive(player)` and `isBusy(player)`.
`LightRP.inventory.canProduce(inv,inputs,outputs)` previews a recipe;
`produce(player,inputs,outputs)` commits it under the normal inventory lock.
These recipe APIs are server-only, not client resource events.

The first-day guide points item workers to collection. Its checkpoint advances
after the first saved batch and survives reconnection; it no longer requires a
Sanitation/Scrapper shift. Hook: `onJobWorkCompleted(player,job,kind)`.

## AC maintenance

AC Cleaner alone keeps `/job start|status|gps|cancel`, the employment desk,
three timed rooftop tasks, public service exits and a €$260 bank payment on
completion. Its temporary test locations remain in `server/config/job_runs.lua`.
An AC order and an item-work loop cannot run simultaneously.

## Verification

Lua 5.4: `tests/job_work_test.lua` covers both complete item chains with the real
inventory/economy code, trunk locks/capacity, slots/weight, SQL rollback, replay,
proximity/life/seat/instance guards, cancellation and disconnect during commits.
`job_work_client_test.lua` covers progress handoff, stale callbacks, UI conflicts,
GPS and cleanup. Existing cash, AC, tutorial and item tests cover integration.

UI: `npm run build` in `ui`; `node tests/jobs.browser.cjs` against Vite at port
5197 (`PLAYWRIGHT_MODULE` can select an existing installation). Covers all three
free-work GPS stages without employment, absence of a duplicate work panel, AC
orders and responsive UI. The shared activity bar shows the current bag weight
and Escape shortcut directly over the game, without a background panel.
