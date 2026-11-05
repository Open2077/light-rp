-- Free item work: no employment check, shift, route or mission inventory.
-- Existing locations are reused: two collection sites, a processor and a buyer.
-- Prices, quantities and durations are server-owned; weights live in shared/items.lua.
LightRpJobWork = {
    range = 2.6,
    jobs = {
        -- The practice activity of the first day guide (shared/tutorial.lua), at
        -- the job fair of the arrival hall, in the hall's routing bucket. Not a
        -- job: `tutorial` opens each site only for the guide's matching step, and
        -- `once` ends the loop after one batch.
        tutorial = {
            label = "Practice run", icon = "package", tutorial = true, once = true, bucket = 620000,
            raw = "practice_crate", collected = 1, collectMs = 5000,
            input = 1, product = "practice_parts", produced = 1, processMs = 5000,
            price = 40, sellMs = 2500,
            animations = {
                collect = { profile="examine", clip="kneel__rk_on_ground__01__inspect_ground__01" },
                process = { profile="examine", clip="kneel__rk_on_ground__01__inspect_ground__01" },
                sell = { profile="tablet2", clip="stand__2h_tablet__02__use_tablet__01" },
            },
            points = {
                { id = "crates", kind = "collect", label = "Practice · Supply crates", position = { x=6746.0, y=2353.4, z=400.03 } },
                { id = "bench", kind = "process", label = "Practice · Workbench", position = { x=6760.0, y=2353.4, z=400.03 } },
                { id = "buyer", kind = "sell", label = "Practice · Buyer", position = { x=6754.0, y=2339.0, z=400.03 } },
            },
        },
        sanitation = {
            label = "Sanitation", icon = "trash-2",
            raw = "trashbag", collected = 1, collectMs = 6500,
            input = 1, product = "recyclables", produced = 1, processMs = 5000,
            price = 20, sellMs = 2500, -- ≈ 2,000 €$/h with a car (docs/economy-balance.md §17)
            animations = {
                collect = { profile="examine", clip="kneel__rk_on_ground__01__inspect_ground__01" },
                process = { profile="examine", clip="kneel__rk_on_ground__01__inspect_ground__01" },
                sell = { profile="tablet2", clip="stand__2h_tablet__02__use_tablet__01" },
            },
            points = {
                { id = "collection_west", kind = "collect", label = "Waste collection · West", position = { x=-1451.922119, y=1276.606934, z=23.096848 } },
                { id = "collection_center", kind = "collect", label = "Waste collection · City", position = { x=-1066.948486, y=-108.389893, z=7.478088 } },
                { id = "recycling", kind = "process", label = "Waste sorting station", position = { x=-271.248352, y=-1566.478760, z=7.620689 } },
                { id = "buyer", kind = "sell", label = "Recycling buyer", position = { x=1353.187500, y=-1131.332520, z=44.744698 } },
            },
        },
        scrapper = {
            label = "Scrapper", icon = "hammer",
            raw = "scrap", collected = 4, collectMs = 8000,
            input = 4, product = "salvaged_parts", produced = 1, processMs = 6000,
            price = 26, sellMs = 2500, -- longer loop than sanitation: ≈ 2,100 €$/h with a car
            animations = {
                collect = { profile="repair", clip="kneel__rh_screwdriver__01__repair_01" },
                process = { profile="mechanic", clip="kneel__rh_tool_fix__01__long__01" },
                sell = { profile="tablet2", clip="stand__2h_tablet__02__use_tablet__01" },
            },
            points = {
                { id = "salvage_south", kind = "collect", label = "Scrap collection · South", position = { x=435.379822, y=-1354.325317, z=19.512596 } },
                { id = "salvage_north", kind = "collect", label = "Scrap collection · North", position = { x=-1754.117798, y=2074.827637, z=18.156219 } },
                { id = "workshop", kind = "process", label = "Scrap processing workshop", position = { x=-700.594360, y=-935.791931, z=7.369400 } },
                { id = "buyer", kind = "sell", label = "Salvaged parts buyer", position = { x=-1243.482300, y=2885.109863, z=7.156265 } },
            },
        },
    },
}
