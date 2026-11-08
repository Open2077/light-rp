# Talking to Johnny: the dialogue

Johnny Silverhand, at The Crossing, no longer opens on the FAQ panel. He talks first,
like a dialogue in the game: his line as a subtitle at the bottom of the screen, a few choices
for the player to the right of centre, and the world and Johnny stay visible. The full FAQ
is still one choice away ("Write it down for me.", "Let me type it.").

The in-game text is in English. This document goes over the tree for review;
the choices are quoted as they appear on screen.

- Content: `server/config/guide_dialogue.lua` (editable without rebuilding the page).
- Module: `server/modules/guide_dialogue.lua` (nodes, pagination, GPS, Hall of Fame).
- Page: `ui/src/features/guide/TalkView.tsx`, `talk.ts`, `talk.css`.
- Tests: `tests/guide_dialogue_test.lua`, `ui/tests/guide-talk.test.ts`.

## What the player sees

1. **E "Talk to Johnny"** (or ALT + click). Johnny says hello, with a greeting picked at random
   from three. On the right, seven numbered choices; below them, his name, the tag
   "ROCKERBOY · GHOST IN THE MACHINE" and his line.
2. **↑ ↓** or the mouse pick a choice, **Enter**, **F** or a click confirm it, **1 to 9**
   pick one directly. The selected line is yellow, with the F key.
3. Johnny answers in **three lines at most on screen**. If his answer is longer, the
   only choice is "Go on." (markers at the top right show the page); **← →**
   also turn the pages. The next choices arrive on the last page.
4. Every node ends with **"Back."** (except the greeting) and **"That's all."**.
   **Backspace** or **right-click** go back, to the page where the choices were,
   with the cursor where it was. A choice already taken is greyed out.
5. A choice can **do something**: it sets a GPS route (the confirmation shows under the
   line, Johnny stays open), opens a panel (activities, contracts, job guide,
   Hall of Fame), or opens the **written FAQ** at the right answer. From the FAQ, the
   **"TALK TO JOHNNY"** button, or **right-click** from the open answer, brings you back to the
   dialogue, at the line you left.
6. **"That's all."**: Johnny says goodbye (a random line out of three), and the
   dialogue closes after 1.8 s or at the first key press. **Esc** closes it right away.

FAQ answers too long for the dialogue (more than four pages) are
cut after two pages with "There's more. A lot more. Want it written down?"; the
first choice then becomes "Write it down for me." (the FAQ at that answer).

## The tree

Notation: `→ node` leads to another node; `FAQ x.y` makes Johnny answer with
FAQ answer x.y (his line, then the paginated answer; that answer's actions and related
questions become the next choices); `Topic x` lists the questions of
topic x; `GPS x` sets a route; `Opens x` opens a panel. Values in
curly braces follow the config (prices, keys, places).

### Greeting (`hello`)

Johnny introduces himself (rockerboy, legend, reluctant welcome committee) and invites
questions. Three variants.

- "What do I do first?" → `first`
- "How do I make money?" → `money`
- "Where's the action?" → `action`
- "I need wheels." → `wheels`
- "Tell me about chrome." → `chrome`
- "Crew stuff." → `crew`
- "Something else…" → `other`

### Where to start (`first`)

Starting money in your pocket and in the bank, a free studio (`{v:starterDoor}`), find a job
at the Job Center, eat, come back here for the action.

- "Mark my studio." — GPS studio
- "Mark the Job Center." — GPS Job Center
- "Where am I, exactly?" → `where`
- "Show me my keys." → `keys`
- "Any rules?" — FAQ start.rules

`where`: The Crossing, Westbrook; newcomers arrive here after the first day; the
terminal starts activities; the Job Center, rentals and the garage are in City Center.

- "Show me the activities." — Opens the Activities panel
- "What was that first day guide?" — FAQ start.tutorial
- "Who are you, anyway?" — FAQ help.johnny

`keys`: the main keys with **the player's own bindings** (menu, Neural-Link,
interact, bag, ALT + click) and where to rebind them.

- "Write them all down for me." — Opens the FAQ at controls.keys
- "What's in the menu?" — FAQ controls.f1
- "What does the Neural-Link do?" — FAQ controls.neuralink
- "How do I walk instead of run?" — FAQ controls.walk
- "Camera?" — FAQ controls.camera

### Making money (`money`)

Honest work or dirty work. A job pays every N minutes ("while you're actually doing
something" if pay requires activity), missions pay the most with a crew; if
activities pay, The Crossing matches pay by the minute.

- "Get me a job." → `job`
- "Tell me about missions." → `missions`
- "Cash or bank?" → `cash`
- "How do I pay someone?" — FAQ money.pay
- "What does stuff cost?" — FAQ money.spend
- "What are these Dailies?" — FAQ money.dailies (where to open them: F1 → Dailies and the Dailies tab of the Activities panel, at Adam Smasher's; reset at 00:00 UTC, weekly on Monday; what they pay)

`job`: go to the Job Center, E at the counter, the jobs on offer; everyone starts at
the bottom.

- "Mark the Job Center." — GPS Job Center
- "What's each job like?" → `jobs` (Sanitation, Scrapper, Courier in two lines)
- "What's the pay?" — FAQ jobs.pay
- "Open my job guide." — Opens the job guide (hidden without a job)
- "How do I quit?" — FAQ jobs.quit

`jobs`: "Tell me about Sanitation." / "… Scrapper." / "… Courier runs." (FAQ
jobs.sanitation, jobs.scrapper, jobs.courier), "Mark the Job Center.".

`cash`: cash in your pocket (only pocket cash pays), a bank account per character, no
ATM yet.

- "How do I check my balance?" — FAQ money.check
- "How do I pay someone?" — FAQ money.pay
- "Every way to earn?" — FAQ money.earn

### The action (`action`)

The Crossing terminal (arena, races, chases, turf wars); "right now: …" if activities
are running; missions all over the city, and Dogtown
if it is enabled.

- "Show me the activities." — Opens the Activities panel
- "Do they pay?" — FAQ activities.pay_rebalance or activities.rewards (whichever is
  visible under the config)
- "Tell me about missions." → `missions`
- "Dogtown?" → `dogtown` (if Dogtown is enabled)
- "Open the Hall of Fame." — Opens the Hall of Fame (if the module is there)

`missions`: a mission board, E, difficulty, you go in with your crew in your own instance
with a kit provided; the reputation required for the higher difficulties, if it is
required.

- "Show me the contracts." — Opens the Activities panel, Contracts tab
- "What do they pay?" — FAQ missions.rewards
- "Street cred?" — FAQ missions.tiers_gate or missions.reputation (depending on the config)
- "Who are the fixers?" — FAQ missions.fixers
- "What if I die?" — FAQ missions.death
- "The Chimera Protocol?" — FAQ missions.chimera (if the resource is there)

`dogtown` (if enabled): no law behind the walls; a minimum stake in cash; on
death, part of your cash drops in a bag for the killer; the bank is safe.

- "Mark Dogtown." — GPS Dogtown
- "What's in it for me?" — FAQ dogtown.bonus
- "Crews in there?" — FAQ dogtown.crews
- "Bounties?" — FAQ dogtown.bounty
- "Give me the fine print." — FAQ dogtown.what

### Vehicles (`wheels`)

Rent at Rent-a-Ride (price, duration) or buy at Night City Motors (price range); no
free starter car.

- "Mark the rental desk." — GPS rental desk
- "Mark the dealership." — GPS dealership
- "What's for sale?" — FAQ vehicles.prices
- "Fuel?" → `fuel`
- "Where do I keep it?" → `garage`

`fuel`: price per litre, the steps at the pump; when you run dry the engine stops,
and a jerrycan saves you the walk.

- "Mark a fuel station." — GPS fuel station
- "Jerrycan?" — FAQ vehicles.jerrycan
- "Step by step." — FAQ vehicles.fuel

`garage`: park at the public garage (E or `/garage`), number of cars per character;
impound and release fee.

- "Mark the garage." — GPS garage
- "Impound prices?" — FAQ vehicles.impound
- "Keys and locks?" — FAQ vehicles.lock
- "Can I paint it?" — FAQ vehicles.paint

### Chrome (`chrome`)

Johnny's warning; find a ripperdoc chair, E to lie down, the clinic
opens; number of implants, price range, paid from the bank. As long as no clinic
is configured: "clinics aren't on the map, keep your eyes open".

- "Mark the nearest clinic." — GPS nearest clinic (hidden as long as `clinics`
  is empty)
- "What's on the menu?" — FAQ cyberware.price
- "Sandevistan or Berserk?" — FAQ cyberware.os
- "How do I use them?" — FAQ cyberware.use
- "Any limits?" → `limits`

`limits`: implant rank and reputation, body capacity; or "none, if your bank
can pay, it fits" when none of that is enabled.

- "Which rank needs what?" — FAQ cyberware.tiers
- "How many points do I get?" — FAQ cyberware.capacity
- "Swapping and taking them out?" — FAQ cyberware.install
- "Iconic implants?" — FAQ cyberware.iconics

### The crew (`crew`)

Nobody makes it alone; ALT + click on a player, "Invite to crew"; maximum size;
the leader starts missions and the activity queue.

- "How do I accept an invite?" — FAQ crews.accept
- "What can the leader do?" — FAQ crews.leader
- "Matchmaking?" — FAQ crews.matchmaking
- "What's that list at the bottom left?" — FAQ crews.frame
- "How do I leave?" — FAQ crews.leave

### Something else (`other`)

"Shoot. Can't be weirder than the last guy's question."

- "Got a place for me to crash?" — Topic housing
- "Food, health, getting shot." — Topic health
- "Guns." — Topic weapons
- "Clothes." — Topic appearance
- "Controls, chat, my bag…" → `more`
- "Let me type it." — Opens the FAQ, cursor in the search box

`more`: "The small stuff. Fine. Somebody's gotta know it."

- "Controls and menus." — Topic controls
- "Chat and voice." — Topic chat
- "My inventory." — Topic inventory
- "Animations." — Topic animations
- "I need the staff." — Topic help
- "Let me type it." — Opens the FAQ, search

A topic shows Johnny's line for that topic, then its questions as choices
(each one leads to the answer in dialogue).

### Goodbye

A random line: "Don't die out there. Or do. Keeps things interesting.",
"See you around, choom. I'll be here. Not like I've got a choice.", "Go on. The city's
not gonna burn itself down.".

## What the actions do

| Choice | Effect |
|---|---|
| GPS (studio, Job Center, rental desk, dealership, fuel station, garage, Dogtown, clinic) | route to the nearest place of that type (`guide.gps`, like the FAQ); confirmation under the line, the dialogue stays open |
| Activities / Contracts | closes Johnny, opens the Activities panel on the right tab |
| Job guide | closes Johnny, opens the guide for the current job (choice hidden without a job) |
| Hall of Fame | new server action `guide.panel`: opens the Hall of Fame within 12 m of Johnny or near the board; otherwise a message ("Walk up to the Hall of Fame board first.") |
| Write it down / Write them all down | opens the FAQ at the answer, Back returns to the dialogue |
| Let me type it. | opens the FAQ, cursor in the search box |

A choice whose target is hidden (question filtered out by the config, place type with no place,
module missing) is not offered; a node with nothing left to say disappears along with its
choices.

## Transport

The opening node arrives with the `guide` dialogue; its children follow right away (before
the search index). After that the page requests each node with `guide.node` and receives the
node **and its children**: the next click is already cached. Each message stays under
800 values and 32 KiB (the largest measured: 407 values, 5.2 KiB). A request dropped
by the 250 ms per-action limit is retried (four tries, 700 ms apart). A content
revision (a feature turned on or off) clears the page's cache.

## Limits (existing natives)

- **Clinics**: no reachable ripperdoc position exists on the Light RP side (the
  chairs in op77_scenes are scanned furniture, with no way to know which ones can be entered).
  The GPS choice is ready but hidden as long as `clinics` is empty; clinics have to be
  surveyed in game.
- **F1 menu**: the page can't open the F1 menu itself. "Show me my keys." is
  therefore a line with the player's keys, and "Write them all down for me." opens the
  FAQ at the full list.
- **Hall of Fame**: the existing page action requires being within 10 m of the board; Johnny
  is a few metres from it, hence the server action `guide.panel` (same opening, range of
  12 m around Johnny).
- **Dogtown**: the GPS targets the zone pin (`blip.position`); to be checked in game.
- **Voice**: no voice acting; text only.
- Three FAQ answers can't be reached through the dialogue (activities.commands,
  cyberware.where, dogtown.logout); they stay in the FAQ and the search.
