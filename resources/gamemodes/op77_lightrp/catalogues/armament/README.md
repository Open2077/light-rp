# Armament reference data

- `native-weapons-2.31.json`: all 1,925 rows returned by Open77 Devkit MCP `open77_data(catalogue="weapons",query=".")`, build 2.50.0+op77.156. This includes non-player and technical records.
- `weapon-catalogue.json`: the 198 named weapon/grenade rows in the user’s wiki index, with English labels, stable inventory IDs, verified record crosswalks, local art paths and source/hash provenance. 195 rows resolve; three remain unresolved.

These files are reference data. Runtime allowlists live in `shared/armament.lua`; catalogue presence is not permission to grant arbitrary native records. The playable weapon controller currently supports two pistols. See `docs/weapon-catalogue.md` and `docs/grenades-inventory-design.md`.
