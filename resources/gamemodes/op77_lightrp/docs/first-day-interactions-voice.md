# First day: voice and Alt interactions

The arrival-hall guide includes 13 chapters. Voice comes immediately after meeting
Mara. The Alt lessons follow Rook's garage introduction, before the fuel station.
Existing characters can use **F1 → First day guide** or `/tutorial restart`.
`/tutorial` resumes the saved checkpoint; `/tutorial pause` pauses the guide.
A newcomer who does not want the guide picks **Skip the tutorial** on the arrival
screen (or **F1 → First day guide → Skip the first day**, or `/tutorial skip`):
the implant is installed, the guide is marked done and they arrive where the
guide's end leaves everyone (`spawn.afterTutorial`, near their Kabuki starter
studio). See the README, "Passer le premier jour".

## Voice, at the player's pace

The four-page guide explains devices, transmission mode and a local sound check.
Players can keep their existing configuration or skip setup at any stage. Skipping
does not mute or change their current preferences. A previous completed setup is
recognized for this server; it can be checked again.

- Select the actual microphone and voice output device, refresh the list, enable
  capture and adjust microphone/other-player volume independently of game audio.
- Choose push-to-talk or voice activation. Keyboard and all five mouse buttons
  are supported. Escape cancels binding capture. The actual current key and
  server voice-range shortcut are shown.
- Start local microphone playback, watch the genuine input meter, and confirm
  that playback sounds clear. Completion requires observed microphone input and
  the player's listening confirmation. Missing hardware never blocks arrival:
  troubleshooting and Skip remain available.

Preferences are applied through `Open77.voice.setup`, a `voice.client` API backed
by the trusted `open77_pause` resource. It uses the same setters and server-scoped
KVP values as Pause → Settings → Voice. The downloaded gamemode must **not** depend
on `open77_pause`: it belongs to a separate trusted client host. Ordinary exports
do not cross that boundary. Older clients without this API show an update hint and
retain the skip paths.

The setup lease temporarily suspends voice activation while preserving the desired
mode. Local playback stops on leaving setup, changing its input device or stopping
the resource. A three-second heartbeat timeout covers lost consumers. The normal
voice mode is restored afterwards. No microphone samples pass through Lua or the
server tutorial protocol. The UI does not fabricate sound-meter activity.

## Alt: learn by doing

The objective card teaches the actual gesture: **hold Alt, left-click the object,
then select an action while holding Alt**. Releasing Alt or pressing Escape closes
the menu; right-click or Back returns from a submenu. The configured activation
key is read from `open77_contextmenu`.

The hall is shared in bucket `620000`. Only the Alt lesson moves each participant
into a private bucket (`practice.bucketBase + player ID`, default `700000 + ID`).
Their temporary crate and keyed Hella spawn in that same bucket, invisible to
other participants. The four checkpoints require real actions:

1. Select **Inspect practice crate** on that player's crate.
2. **Unlock** the practice car.
3. **Trunk & hood → Open trunk**.
4. **Trunk & hood → Close trunk**.

Vehicle actions use the normal context-menu handler and its key, bucket, life and
distance checks. Only successful actions on that player's training vehicle advance
the guide. The prop step also checks ownership, distance, bucket and life state on
the server. Pressing E cannot complete these lessons; context objectives retain
their navigation marker without advertising an unrelated E interaction.

Closing the trunk returns the participant to the shared hall at the same position,
before the fuel-station objective. Entry and normal return only change routing;
they do not respawn or teleport the player. The private environment inherits the
hall's clock and weather. The map's preloaded geometry and local decorations remain
visible, while the shared NPCs return when the player rejoins the hall.

Practice objects, keys and the private environment are removed when the player
leaves these lessons, pauses/restarts the guide, switches characters, disconnects
or the resource stops. Cleanup never overwrites a bucket already claimed by another
system. Pause retains the normal exit to Night City. Reconnection, death and resume
restore the private checkpoint beside the practice area, with the appropriate
lock and trunk state. There is no shared twelve-bay limit. Spawn/entry failure
offers Retry; a refused return retains the scene until recovery succeeds.
No player-owned vehicle is borrowed or removed.

## Validation

The opening shot ends locally before its server checkpoint is acknowledged.
While the server finishes placement (`recovering`, missing position or a pending
bucket change), the client retries the same character/revision once per second
for up to 30 seconds. It releases camera, freeze, audio and HUD claims first.
The next server checkpoint cancels retries. A timeout offers **Retry arrival**
and Escape still opens the guide's pause options. No life or bucket check is
bypassed, and the world is not covered again while awaiting acknowledgement.

Full walkthrough tests require a database and a normally loaded active character.
Setting a test character's `status` directly does not run inventory/wallet
activation. Disabling persistence also prevents the economy from loading a
wallet, even when the puppet is alive and walking. Shops now report an unavailable
database before reporting a missing wallet; secure checkout remains mandatory.

On 2026-10-14, the disposable loopback server was moved from its database-disabled
fixture to an isolated MariaDB database. The saved shop checkpoint was restored
through the normal character-load hooks. PID 40908 completed pristine bootstrap
(session 4, puppet 8); the server confirmed `character=active`, `life=alive`,
`bucket=620000`, `database=true`, `inventory=true`, `wallet=true`, `cash=250`.
The player resumed beside the vendor at chapter 5/13. No purchase was performed
on their behalf. The normal LightRP server and database were not modified.

Regression coverage includes delayed intro acknowledgement, loading interruptions,
duplicate/stale packets, missing position, wrong bucket, death, bounded retries,
manual recovery, character cleanup, and the database-disabled shop diagnostic.
The targeted Lua suites, tutorial browser suite and production UI build passed.

Run the Lua tests with `tests/run-lua.ps1 -Test <filename>`:
`tutorial_test.lua`, `tutorial_practice_test.lua`, `tutorial_client_test.lua`, `tutorial_voice_setup_test.lua`,
`tutorial_voice_client_test.lua`, and `vehicle_context_test.lua`.

The UI build runs TypeScript checks. Browser coverage is in
`ui/tests/tutorial-alt-voice.browser.cjs`, with the existing tutorial and experience
suites. It covers the optional paths, keyboard/mouse capture, real-state meter
gating, test cleanup, unavailable audio and layouts from 1024 to 3440 pixels.
Browser audio is mocked; it cannot establish microphone or playback quality.

The private-practice Lua tests simulate two participants and check distinct
buckets, matching prop/vehicle buckets, independent cleanup, unchanged position,
shared-hall return, environment inheritance, interrupted checkpoints, failure
rollback and character/disconnect/resource-stop cleanup. Tutorial integration
tests also cover pause/resume/restart, failed persistence and retry after refused
bucket entry. These tests do not constitute a two-client visual replication test.

The native `Open77.Scripting.Tests` suite covers the two-host voice service,
permission checks, serializable values, provider absence and ordinary-export
isolation. Live acceptance must additionally exercise actual context selection and
the native device/test state; audible quality still requires a human listener.
