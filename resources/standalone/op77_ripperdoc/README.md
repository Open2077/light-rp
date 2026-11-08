# op77_ripperdoc — ripperdoc clinic interface

Full-screen ripperdoc interface, in the LightRP art direction (yellow and black). It is built from
the game's own assets, reworked (amber and graphite color grading):

- the "paperdoll" videos: the full body on a loop and one close-up per system;
- the full-body layers of each system (circulatory, immune, nervous, skin, skeleton);
- the cyberware icons from the inventory;
- the sounds of the cyberware tab, the paperdoll zoom, implant installation and the menu.

**On LightRP, the clinic is real** (`op77_lightrp/server/modules/cyberware.lua`):
- the catalog, prices, parts and effects come from the server (`server/config/cyberware.lua`);
- each operation is paid in eurodollars (bank), then saved per character;
- implants are reapplied on every connect, character switch and respawn.

**Large messages.** The WebUI bridge silently drops any message with more than 1,024 values, and
opening the clinic (the whole catalog) takes about 1,600. So the client sends `rd:open` and `rd:state`
as JSON text (`{ __json }`, or `{ __part }` in 48 KB chunks), and `web/bridge-parts.js`, loaded
before `app.js`, decodes them before the page handlers. This file is not part of the
`ripperdoc-ui` build: keep it in `index.html` when the page is rebuilt.

Without a server (browser preview, `ripperdoc.open` console), the page falls back to its demo catalog and
simulates the operations. See PROTOCOL.md.

## LightRP cyberware (what the clinic actually installs)

| System | Implants | Real effect (platform) |
|---|---|---|
| Legs | Reinforced Tendons, Mk.2 / Fortified Ankles | Durable double jump (`Open77.cyberware`, legs) / no fall damage |
| Arms | Gorilla Arms, Mk.2 / Mantis Blades, Electric | Durable fists (`gorilla_arms`) / blades on the arm slot, **B** key |
| Nervous | Neofiber, Mk.2 | Dash and Air Dash (`Open77.dash`), **Ctrl** + direction |
| Operating System | Sandevistan Mk.1, Mk.3 | Reflex overdrive (`Open77.reflex`), **X** key |
| Skeleton | Kinetic Impact Frame / Titanium Bones, Epimorphic Skeleton | Ground Slam (`Open77.abilities`), **G** in the air / max health |
| Skin | Subdermal Armor, Mk.2 | Armor |
| Circulatory | Biomonitor, Iron Lungs, Adrenaline Booster | Health regeneration, max stamina, stamina regeneration |

The other systems (cortex, eyes, face, hands, immune) stay empty: there is no implant the
platform can apply yet.

**Economy.** Everything is bought with eurodollars (bank), no other resource. Prices are pegged to
job income: about 2,000 to 3,000 €$/h, ignoring mission and raid rewards, which
are not balanced yet.
- **No limits**: no capacity, no prerequisites, equip whatever you want.
- A family maps to a single native slot (arms, legs, Dash, Overdrive…): another
  model from the same family replaces the installed one.
- A removal costs 250 €$.

Staff (console): `lightrp.cyberware <id> list|status|blades|give <item>|take <item>`,
`ripperdoc.action <id> install|remove <item>`.

## Walkthrough

1. **Opening**: neural handshake, then a biometric scan of the body. The 12 systems line up
   on both sides of the body, as in the game.
2. **Overview**: the mouse tilts the room (3D parallax). When you hover a system:
   - the game's layer or a glow lights up on the area;
   - a line links the group to its point on the body;
   - a holographic card floats in front of the body.
3. **Dive**: a click sends the camera rushing into the area (zoom, blur, flash) down to the close-up
   of the system (the game's video), tilted in depth.
   - Left: the installed slots and the clinic's stock (filters, rarity, price, REQ).
   - Right: the implant card.
   - A/D: previous or next system.
4. **Operation**: hold E or the button, then a surgical procedure plays out (steps,
   progress bar). The last step waits for the server's answer. If it fails, the procedure stops
   and the payment is refunded.
5. **Esc** goes back up to the full body, then quits. On LightRP, quitting makes you get up from the chair.

## How LightRP triggers it

`op77_lightrp/server/modules/ripperdoc.lua`:
- when `op77_scenes` starts the "ripperdoc" scene on a surgical chair, it opens
  the interface after the sit-down animation (6.6 s);
- it closes it if the scene ends some other way;
- it makes the player stand up when they close the interface.

## Build

```powershell
cd ripperdoc-ui
npm install
python scripts/build-assets.py --probe <NCWE.Probe.exe>   # media from the local game (public/media)
npm run dev                                              # preview: http://localhost:5179/?body=female&section=circulatory
npm run build                                            # writes resources/standalone/op77_ripperdoc/web
```

The asset build script:
- decodes the Bink 2 videos with the game's `bin/x64/bink2w64.dll` (ffmpeg cannot read them);
- color-grades them, then encodes them in VP9 with alpha;
- exports the icons and layers through WolvenKit;
- exports the sounds through the NCWE probe (`--sound-export`).

It only reads the local install. The rights to the art and sounds remain with CD PROJEKT RED: they
must be replaced before any public or commercial release.
