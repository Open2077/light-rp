# NativeUI HUD lab

Checks the Light RP HUD (NativeUI documents) in the real client without a server: the
real `client/native` modules and `ui/native` documents of `op77_lightrp`, fed by scenes
that play what the framework would send. The standalone UI resources (weapon HUD,
speedometer, nameplates, bubbles, voice plate, chat, context menu) have labs of their own.

    python tools/native-lab/build.py --install <game dir>                      # lrp_hudlab (game mode HUD)
    python tools/native-lab/build.py --standalone <name> --install <game dir>  # lab_<name>, see standalone/
    python tools/native-lab/build.py --remove <game dir>                       # every lab, afterwards

The resource lands in the client's bootstrap folder. With the game at the main menu,
on the debug bridge: `resource.start lrp_hudlab`, then `resource.emit hudlab:<scene>`
(`hudlab:list`, `hudlab:all`). The lab draws on the `debug` layer, above the pre-game
shell, and ignores the shell's cursor capture.

- `lab/driver.lua`, `lab/stubs.lua`: the scene API (`HudLab.scene(name, fn(lab))`: `lab.hud`,
  `lab.state`, `lab.page`, `lab.dialog`, `lab.menu`, `lab.wait`) and the framework stub.
- `scenes/*.lua`: one file per group of HUD documents.
- `standalone/<name>/lab.json` + `scenes.lua`: a standalone resource's lab
  (`lab/driver_standalone.lua`; adapters draw on `Op77UiLab.layer`).

What it cannot show: the real session (anchors, voice levels, server answers), real input
(scenes fake the pointer where a module hit-tests it), and anything under a WebUI dialog.
