-- op77_tcg: a Cyberpunk TCG collection, standalone (no gamemode needed).
--
-- Sealed boosters and display boxes, 12-card packs opened in your hands with the real 3D cards dealt on the
-- table in front of you for everyone around to see, a sleeved binder of the 320 editions (151 cards, Common to
-- Secret, sleeved / foil / premium / metal finishes), duplicates recycled into Dust, editions printed at a TCG
-- shop, cards shown in hand, laid on a table or handed to another collector.
--
-- Assets: the Cyberpunk TCG Collectibles mod (Nexus 34654) archives, repacked into four preload packages
-- (tools/build-assets.ps1). Server data: data/tcg.db (SQLite). Admin: ACL command.tcg.* (give, card, dust, shop).
resource "op77_tcg"
version "1.0.0"
open77_version ">=0.0.1"
auto_start true
-- The client owns a WebUI surface: a live reload would leave a stale one.
reload_policy "reconnect"

preload_mod "dist/op77_tcg_1.zip"
preload_mod "dist/op77_tcg_2.zip"
preload_mod "dist/op77_tcg_3.zip"
preload_mod "dist/op77_tcg_4.zip"

shared_script "shared/config.lua"
shared_script "shared/catalogue.lua"
shared_script "shared/rules.lua"
server_script "server/main.lua"
client_script "client/main.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }
files { "sounds/*.wav", "sounds/*.mp3" }

permissions {
    "network.events",
    -- server: the collection database (data/tcg.db), the shop counters and physical cards (replicated props)
    "sqlite.access",
    "world.props",
    -- client: the cards dealt on the table (local props), the surface under the hands, the pack and shop sounds
    "world.query",
    "audio.play",
}
