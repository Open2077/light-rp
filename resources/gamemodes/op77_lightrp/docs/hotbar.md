# Quick slots

The first five pocket slots are the hotbar. Move an item into that row in the
inventory, then press its **1–5** shortcut during gameplay to use it without
opening the inventory. These bindings and **Tab** are rebindable in game settings.
Hold **Tab** to display all five slots; a shortcut also flashes the bar briefly.
The first inventory row shows the corresponding keycaps.

Quick use runs the existing server inventory item handler: weapons draw through
the authorized equipment queue, grenades select their finite kit, and food or
medical items keep their timed-use behavior. Selection does not manufacture or
consume a second copy. Unsupported items show an error. The hotbar never takes
keyboard/cursor focus and its bindings pause while a WebUI owns input.

The bar is a view of the inventory, not another container. Server inventory
publication also sends the first-row snapshot to its owner when the full
inventory is closed. Requests carry only slot, inventory ID, revision and a
correlation ID. A stale revision or another character's inventory is refused
and refreshed, so an old shortcut cannot use a newly moved item by accident.
Death, character setup, dialogs and in-progress actions gate quick use.

`tools/test-hotbar.py` loads the real inventory/weapon/grenade controllers and
checks closed-inventory updates, ownership/staleness, timed handlers and life
checks. `tools/test-hotbar-client.py` checks held Tab, five consumed/rebindable
mappings, visibility expiry and UI/action/death gates. Browser checks cover
five-card layout, local illustrations, request/error correlation, authoritative
counts and no overlap with status gauges at 1920, 1280, 1024 and 600 px.
