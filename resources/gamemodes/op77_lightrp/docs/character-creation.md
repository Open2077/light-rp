# Character creation

The first-join interface uses the Light RP charcoal/yellow theme, a locally bundled
Night City backdrop, a live identity card and a four-step guided flow:

1. **Identity:** first/last name, optional birth date, inline validation and age in
   the configured Night City year.
2. **Background:** optional origin cards and a 600-character story. Neither is
   required to continue. Back navigation keeps all unsaved inputs in memory.
3. **Appearance:** choose a body and open the existing native appearance editor.
   A saved appearance can be reviewed without editing it again.
4. **Ready to go:** review the server-saved identity and appearance, return to edit,
   then explicitly enter the city. The existing welcome briefing follows.

## Authority and persistence

The visual Background step is local; `character.identity` saves the identity and
background together. The browser waits for both the matching action result and
the authoritative character snapshot. It does not activate the character or grant
starter items. `character.finish` retains the server-side appearance requirement
when the database is available and activates the character only once.

Names and age limits come from `LightRpConfig.names` and `LightRpConfig.characters`.
Both client and server reject impossible dates (including leap-day errors). Story
truncation is Unicode-aware, not a byte slice. Origins/slots tolerate empty Lua
tables serialized as objects. No draft identity is written to browser storage.

Returning to a previous step preserves inputs during this session. Reconnection
resumes the server-saved workflow; unsaved edits are not persisted. A different
character slot gets a fresh form. Without database persistence, appearance remains
optional, as before, and the interface explicitly labels this as a local session.

## Native editor handoff

The Lua bridge emits `lightrp:ui:character:editor` with `{ active, error? }`. The
wizard becomes invisible and releases keyboard/mouse focus while the native mirror
is open. Lua observes `Open77.appearance.isOpen()` at 250 ms intervals while creation
is active, also handling native confirmed/cancelled events. Closing or cancelling
restores the wizard. A refused request or a request that never opens after 15 seconds
returns a useful error. No timeout is applied while the native editor is open.

F1 cannot take focus away from creation. Escape does not dismiss an unfinished
character. Keyboard navigation is contained in the wizard, headings receive focus
on step changes, inputs expose their validation state, and reduced-motion settings
disable transitions. Footer actions stay visible independently of content scrolling.

The separate `open-voice` HUD is suppressed before the initial state, through
creation (including the native mirror) and the first-spawn welcome. Its higher
WebUI surface is hidden immediately, so it cannot cover the Continue button.
The indicator returns when the character is active and the welcome is dismissed;
microphone capture and proximity are unchanged. Resource restarts reapply this
suppression, and stopping Light RP releases only its own visibility reason.

## Development and checks

Browser preview: `http://127.0.0.1:5177/` while the UI dev server runs.
`?step=appearance` and `?step=confirm` preview later steps. The browser's appearance
editor is only a mock; it simulates saving after two seconds.

From `ui/`:

```powershell
npm run build
node --experimental-strip-types --test tests/character-model.test.ts
node tests/character.browser.cjs
```

The browser runner needs Playwright (`PLAYWRIGHT_MODULE` may point to an existing
installation). `SCREENSHOT_DIR` optionally saves screenshots. It covers validation,
back navigation, pending/error replies, duplicate protection, state/result ordering,
native-editor cancellation/save, activation, character-slot reset, reduced motion
and each step at desktop, ultrawide and narrow viewport sizes.

From the repository root:

```powershell
pwsh -NoProfile -File resources/gamemodes/op77_lightrp/tests/run-lua.ps1 -Test characters_test.lua
pwsh -NoProfile -File resources/gamemodes/op77_lightrp/tests/run-lua.ps1 -Test creator_bridge_test.lua
```

These are isolated checks, not in-game tests. After deployment, reconnect to load
the rebuilt WebUI and the updated Lua bridge (`reload_policy "reconnect"`). Existing
active characters are not reset. Create a new character slot to see the wizard.
