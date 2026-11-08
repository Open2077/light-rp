# Dailies, jobs worked together and prestige titles

Content document for the `lightrp/dailies-titles` branch (proposals 1, 3 and 4 approved in
`lightrp-design-propositions.md`), revised on 2026-11-03 after the "every contract changes the
way you play" pass. **This is the document the owner judges**: the code follows the content, never
the other way round. The in-game texts quoted here are exactly what the player sees.

The player sees the feature under the name **Dailies** (F1, panel, notices, guide). The code and
identifiers keep `contracts` / `dailies` (`server/config/dailies.lua`,
`server/modules/dailies.lua`, `features/dailies/`). The **Contracts** tab of the activities
terminal is still the one for mission boards.

| Fixer | Voice | Role here |
|---|---|---|
| **Mama Okoro** (Heywood) | warm, commanding, "choom" | the street, the neighbourhood, honest work |
| **Silas "Ledger" Varga** | corpo, curt, an accountant | numbers, clean work |
| **Nix Delacroix** (Pacifica) | lowercase, abbreviations, fast | speed, style, chaos |

Contents: §1 rules · §2 the day's dailies (Street, Action, Shift) · §3 crew · §4 weekly ·
§5 jobs worked together · §6 titles · §7 what was replaced or restricted · §8 measurements and
threshold arithmetic · §9 deliberate deviations · §10 questions for the owner · §11 hooks and
evidence. The in-game checklist, contract by contract, is in `dailies-ingame-checklist.md`.

---

## 1. Rules

### 1.1 The three design rules

They apply to **every** contract and every title; a contract that breaks one is taken off the
list.

1. **A contract changes the way you play**: a constraint, a trick, or an interaction with
   another system. Never "faster", "more", or "once".
2. **Doable alone on a quiet server.** A contract that needs other players is only drawn
   if enough distinct accounts are online (`social.minAccounts = 4`), and never pays twice
   for the same partner in the same week (§1.4).
3. **Every threshold is measured, not guessed.** The calculation is written out in §8; no free
   objectives.

### 1.2 What the player sees

- **F1 → Dailies** opens a panel with two tabs, **Today** and **Titles**. The activities
  terminal (The Crossing) has a **DAILIES** tab that shows the same *Today* page and sends the
  same actions (`dailies.claim`, `dailies.swap`) on the same `dailies` state: a claim
  in one shows up in the other on the next push. The tab asks for a refresh when it
  opens (`dailies.refresh`).
- *Today* shows three dailies for the day (**Street**, **Action**, **Shift**), a **crew** one, the
  **weekly**, the day streak, the day's budget, the free swap and the countdowns.
- Each card shows the fixer, their message, the objective as the server checks it, the
  progress and the reward. A social contract carries the **WITH OTHERS** badge.
- **Locked crew card**: with no teammate online, and as long as it hasn't been started, the
  crew contract is replaced by a card "Crew daily · Shows up when a crewmate is online".
  A contract that is started or finished is never hidden.
- On success: **DAILY COMPLETE** notice "*title* · *fixer*. Claim €$ N in F1 > Dailies.";
  the **Claim** button pays out the sum.

### 1.3 Rotation, crowd and reset

- **Day = UTC day**, reset at **00:00 UTC**; **week = Monday 00:00 UTC**.
- **The city draw**: Street, Action and Crew are the same for the whole server that
  day (deterministic FNV-1a draw on the day number), and the weekly for the whole week.
  Each slot follows a cycle: over *n* days, each contract comes up once, never the same one two
  days in a row, and it comes back at most 2*n* − 1 days later. The draw skips a contract whose
  source is missing and freezes two minutes after the server starts.
- **The solo fallback**: each slot also has its own order of **non-social** contracts
  (`soloDraw`). When the city's contract is social and fewer than 4 distinct accounts are
  online, the player gets the day's solo fallback.
- **Once given, a contract stays** (`choose`), in this order:
  1. a contract given by staff (`give`) wins;
  2. a started contract (non-zero progress) is kept, even if the city empties;
  3. a contract not yet started is kept as long as it stays doable;
  4. otherwise the city's contract if it's doable, or the solo fallback.
  The server remembers what it gave (`locks`): a player switched to the solo fallback doesn't
  switch back to the social contract if the crowd returns the same day. No flip-flopping.
- **Shift** follows the job:
  - two or more contracts: they alternate in the job's order (Sanitation, Scrapper, Courier,
    mechanic);
  - a single contract (Trauma Team, AC Cleaner): every other day; on the other days, the
    Shift slot gets a **solo Street contract different** from the one in the Street slot;
  - no contract (NCPD, unemployed): the same Street fallback;
  - a job's social contract (*On Call*, *Fare Paid*, *Pit Crew*) that isn't doable is replaced
    by another contract of the job, otherwise by the Street fallback;
  - **Roadside** is never drawn at random: it takes the slot of an idle mechanic as soon as a
    real call exists (§2.3), and gives it back when the car has been served elsewhere.
  A job change resets the slot, unless the contract is finished or was given by staff.
- **One free swap per day**: the player replaces one of their three dailies with another from the
  same slot, drawn for them alone **among the contracts doable right now** (never a social
  contract on a quiet server). No swap for the crew, the weekly, or a contract given by
  staff. Progress on the swapped contract is lost.
- A finished contract stays **claimable until the end of the next day**; last week's weekly,
  through Monday.

### 1.4 The partner rule

A social contract only pays once per **partner** (another account) and per **ISO week**.
The server keeps, per account and per contract, the week of each partner
(`meta.partners[contract][account] = week`, persisted in the database with the rest of the meta).

- If every possible partner has already counted this week for this contract, nothing
  validates, the progress bar waits just short of the end, and the player reads once: "*title* ·
  already done with this citizen this week. It takes somebody new."
- The rule is per contract: finishing *Ride Along* with Rosa doesn't block *Nobody Eats Alone*
  with her. It resets every Monday.
- It also applies to crew contracts (the teammate is the partner).

### 1.5 Rewards and caps

| Slot | Reward | Why |
|---|---:|---|
| Street | 250 €$ | short, often free |
| Action | 400 €$ | requires a real mission or activity, with a constraint |
| Shift | 250 €$ | comes on top of the job's pay |
| Crew | 300 €$ each | needs two distinct accounts |
| Weekly | 3,000 €$ | a real challenge, once a week |

- **Cap per account per UTC day**: `dailyBudget = 1200` €$ for the dailies and the crew contract;
  the weekly is outside the budget. Beyond that, the server refuses and says so ("Dailies budget reached").
- Effect on the curve (`economy-balance.md` §7): doing everything every day adds ≈ 650 €$ per
  hour played at 2.5 h per day; the best car goes from 23.7 h to ≈ 20.5 h, within the target.
- **No reputation** (decision of 2026-11-03). Payment through `LightRP.money.addBank`, reason
  `contract`, with the contract's title in the statement.

### 1.6 Anti-abuse

- **Progress and reward per account** (the Master `identifier`): an alt doubles nothing and
  isn't a partner.
- **Only sources that are already filtered count**: for an activity, the `activity_pay` verdict
  (ranked or PvE results, no bots in PvP, no friendly match, no staff test); for a
  mission, a successful mission outside test mode; for a world boss, an `eligible` share.
- **"Paid" means "eligible for pay"**: a result that `activity_pay` puts a value on
  (long enough, with progress, no bots, no repetition). The day's pay cap, or activity
  pay switched off on the server, doesn't make a contract fail: the hook runs before
  these two checks (`activity_pay.lua:318`), and dailies have their own budget. The only
  exception: an **NCPD extraction** shorter than the 60 s floor counts (§8).
- **A win means beating something**: in PvE, or in PvP with at least one other player.
  A time trial finished alone is "won" for `op77_race`, not for dailies.
- **"The same match" means the same instance** (routing bucket) **and** entries within
  30 s of each other: two matches started side by side are still two matches.
- **The server itself measures** positions, seats, animations and vehicle health every
  5 s; the client never sends progress. A move faster than 70 m/s (`maxSpeed`, a teleport) doesn't count
  as distance.

### 1.7 Staff tools

`/lightrp.dailies` (restricted command):

| Verb | Effect |
|---|---|
| `give <player> <contract>` | puts this contract in the player's slot today (or this week), progress at zero, regardless of crowd, job or draw; can't be swapped, survives a job change and a restart |
| `status <player>` | day, accounts online (social on/off), each slot with its progress, `done`, `claimed`, `(given)`, swaps, budget, visible Roadside calls |
| `reset <player>` | clears the player's day and week (memory and database), their partners for the week and their pending gifts; the streak and counters stay |
| `complete <player> <contract>` | validates an open contract (for testing) |
| `reroll <slot>` · `day <offset>` · `on` / `off` · `status` | redraw the day, simulated day, pause, global state |

---

## 2. The day's dailies

Notation: **in-game title** (fixer) · *checked objective* · what changes in the way you play ·
threshold (the calculation is in §8) · **solo** or **multi** · hook.

### 2.1 Street (250 €$)

**Ledger's Lucky Number** (Ledger) — **solo**
- *Objective*: make your bank balance end in **777** as the result of a payment; deposits,
  withdrawals and transfers between players don't count.
- *Changes the game*: you go shopping with a calculator. You have to hit the right sum with what
  you buy, sell or earn (pay, selling goods, a fill-up to the exact litre).
- *Threshold*: the balance ending, not a quantity; the fix is refusing the "neutral"
  movements (§7).
- *Hook*: `onMoneyChanged` (`economy.lua:165`), ignored types `deposit`, `withdraw`,
  `transfer_out`, `transfer_in`.

**Running on Fumes** (Nix) — **solo**
- *Objective*: fill up at the pump a car that dropped **below 10%**, up to **at least
  50%**. The jerrycan doesn't count.
- *Changes the game*: you drive on the reserve on purpose, watch the gauge and pick your pump.
  Crosses with *Roadside*: the reserve (15%) triggers a call to mechanics, and a mechanic who pours
  their jerrycan makes the contract fail. Accepting the help or refusing it is a choice.
- *Hook*: `onRefuelled` (`refueling.lua:275`), `kind = "vehicle"`, `before / capacity`.

**Nightcap** (Okoro) — **solo**
- *Objective*: within **10 minutes** of a paid activity win (against bots,
  the police or another player: a solo time trial doesn't count), have a drink in
  a **bar** (within 25 m of a bar on the map).
- *Changes the game*: the win no longer ends on the queue screen; you leave the
  terminal and cross the street for a toast. Links activities, the inventory and the map.
- *Hook*: `onActivityResult` (`activity_pay.lua:318`) then `onItemUsed`
  (`inventory.lua:776`) with a drink.

**Nobody Eats Alone** (Okoro) — **multi**
- *Objective*: finish a meal within **15 m** of another citizen who finishes theirs within **8 s**.
- *Changes the game*: eating becomes a meet-up ("on three, we bite").
- *Hook*: `onItemUsed` (`inventory.lua:776`), food.

**Housewarming** (Okoro) — **multi**
- *Objective*: at home (you have the key), give a drink to a guest; they drink it before
  leaving.
- *Changes the game*: the home is finally used for hosting; the guest has to stay.
- *Hook*: `onItemGiven` (new, `inventory.lua:1046` in `Inv.give`) then `onItemUsed`
  on the guest's side, in the same home.

**Ride Along** (Okoro) — **multi**
- *Objective*: ride **1.2 km** in the same vehicle as another citizen.
- *Changes the game*: you offer a seat; driver and passenger talk.
- *Threshold*: Job Center → The Crossing.
- *Hook*: the sampler (seats and positions).

**Street Performer** (Nix) — **multi**
- *Objective*: at The Crossing, hold an animation for **60 s** with another citizen within **15 m**.
- *Changes the game*: you put on a show, and you keep your audience.
- *Hook*: the sampler (animations, positions).

**The Tour** (Okoro) — **multi**
- *Objective*: travel **750 m** within **15 m** of a citizen in their **first 2 hours**.
- *Changes the game*: a veteran welcomes a newcomer; the same newcomer only counts once.
- *Threshold*: The Crossing → Afterlife; "new" = the hospital's grace window.
- *Hook*: the sampler, the character's `playtimeMs`.

### 2.2 Action (400 €$, all **solo**)

**Clean Invoice** (Ledger)
- *Objective*: take down the Chimera, at any difficulty, **without a single operator
  going down** during the fight.
- *Changes the game*: you play defence (cover, healing) instead of racing for DPS. Standard can
  be done alone.
- *Hook*: `onMissionFinished` (`missions.lua:627`), `inst.report.downs`
  (`mission_chimera.lua`).

**Lose Them, Don't Wait** (Nix)
- *Objective*: in **NCPD Escape**, reach the **extraction** (not the clock) with **3 stars
  or more**, against the real NCPD.
- *Changes the game*: holding out to the end no longer pays; you have to drag the police along at
  full heat and then get out at the right moment.
- *Hook*: `onActivityResult`, stats `how`, `stars`, `police`, `policeBlocked`
  (`op77_chase` `P.resultFor`).

**Leg Day** (Nix)
- *Objective*: in NCPD Escape, choose **On foot** and get away (extraction or clock), against
  the real NCPD.
- *Changes the game*: alleys, stairs, fences instead of the car.
- *Hook*: `onActivityResult`, `stats.mode == "foot"`, `escaped` (a quick extraction
  under the pay floor counts, §8).

**Five Without a Dirt Nap** (Nix)
- *Objective*: a streak of **5 kills without dying** in a paid PvE arena match.
- *Changes the game*: you play for survival, not for score.
- *Hook*: `onActivityResult`, the match's streak stat.

**Support Act** (Okoro)
- *Objective*: win a paid PvE arena match with **more assists than kills** (at
  least one).
- *Changes the game*: you weaken enemies and leave the final blow to a teammate or to the
  terminal's bot allies.
- *Hook*: `onActivityResult`, `stats.assists`, `stats.kills`, `won`, `eligible`.

### 2.3 Shift (250 €$)

**Full Truck** — Sanitation, Scrapper (Okoro) — **solo**
- *Objective*: sell **at least 11** goods in one sale.
- *Changes the game*: you no longer sell every time the bag is full: you process, head out for a
  second collection, and sell everything at once (the trunk helps carry, it isn't required).
- *Hook*: `onJobWorkCompleted` (`job_work.lua:182`), `info.count`.

**The Full Round** — Sanitation, Scrapper (Okoro) — **solo**
- *Objective*: collect at **both** sites, then sell, with no sale in between (3 steps).
- *Changes the game*: you stop looping the nearest site.
- *Hook*: `onJobWorkCompleted`, `info.point`.

**Two Wheels** — Courier (Nix) — **solo**
- *Objective*: a whole Courier run **on a bike** (`Bikes` category).
- *Changes the game*: you change vehicle, route (alleys) and risk (falling off).
- *Hook*: `onJobRunStarted` / `onJobRunCompleted` (`job_runs.lua:270/315/405`),
  the sampler (driver and vehicle category).

**Fragile** — Courier (Ledger) — **solo**
- *Objective*: a whole run in the same car, losing **at most 5%** of its health.
- *Changes the game*: careful driving in traffic.
- *Hook*: `onJobRunStarted`, `onJobRunCompleted`, `Open77.vehicles.getHealth`.

**Water Break** — AC Cleaner (Okoro) — **solo**
- *Objective*: on a rooftop route, **drink** between the first and the last unit, then
  finish the route.
- *Changes the game*: you bring a drink up to the roof; links the job and the inventory.
- *Hook*: `onJobRunStep` (`job_runs.lua:391`), `onItemUsed`, `onJobRunCompleted`.

**On Call** — Trauma Team (Okoro) — **multi**
- *Objective*: stabilize another citizen.
- *Changes the game*: you listen for calls and travel to someone injured.
- *Hook*: `onPatientStabilized` (`medical.lua:228`); the patient is the partner.

**Fare Paid** — Taxi (Ledger) — **multi**
- *Objective*: drive a passenger for **1.2 km**, then receive **at least 6 €$** from them within
  **3 minutes**.
- *Changes the game*: you negotiate a price and get paid at drop-off.
- *Hook*: the sampler (passenger seat, distance) and `onMoneySent`
  (`economy.lua:529` transfer, `:559` cash).

**Roadside Assistance** — Mechanic (Okoro) — **multi, on call**
- *Objective*: pour a jerrycan into the car of another citizen who is **on reserve or
  out of fuel**.
- *Changes the game*: a real breakdown service. The contract only exists if there is a broken-down
  car: the reserve (15%) or another account running dry opens a 30-minute **call**; idle
  mechanics get "Roadside call: … %.1f km from you." and the contract takes their slot. If the
  car is served elsewhere (pump or someone else's jerrycan), the call closes and the slot
  goes back to the job's contract.
- *Hook*: `onFuelLow` (`fuel.lua:287`), `onFuelEmpty` (`fuel.lua:148`), `onRefuelled`
  `kind = "pour"`.

**Pit Crew** — Mechanic (Ledger) — **multi**
- *Objective*: fill up at the pump another citizen's car (they were its last driver) while
  they stay within **15 m**, then get paid **at least the fuel price** by them.
- *Changes the game*: a station service: you fill up for the customer and collect the money.
- *Hook*: `onRefuelled` `kind = "vehicle"`, the sampler (`lastDriver`), `onMoneySent`.

---

## 3. Crew (300 €$ each, **multi**: a teammate online)

**Convoy** (Nix)
- *Objective*: drive **your own car** within **40 m** of a teammate driving theirs,
  over **2.4 km**. One missed sample is forgiven, two in a row reset to zero.
- *Changes the game*: you drive in formation.

**Back to Back** (Ledger)
- *Objective*: win a paid PvE arena match with a teammate, at least one kill each
  (results within **120 s** of each other, **same instance**, entries within **30 s**).
- *Changes the game*: you cover your teammate instead of stealing their kills.

**Bar Crawl** (Okoro)
- *Objective*: drink with a teammate in **3 bars in 3 districts** in less than **an hour**.
- *Changes the game*: a night out across the city.

**Album Cover** (Nix)
- *Objective*: at The Crossing, the whole crew present plays an animation within **6 m** of each
  other for **10 s**.
- *Changes the game*: you coordinate for the photo.

**Nobody Left Behind** (Nix)
- *Objective*: escape an NCPD Escape as a crew, with **every** teammate in the match getting
  away (results within 240 s, same instance, entries within 30 s).
- *Changes the game*: you wait for the slowest one and cover them.

---

## 4. Weekly (3,000 €$)

**Two Against the Machine** (Ledger) — **multi**
- *Objective*: take down the Chimera on **Hard** with **exactly two operators** at the start of the
  fight, and two at the end.
- *Changes the game*: the raid at its minimum; every role counts double.

**All the Way** (Ledger) — **multi**
- *Objective*: win a paid ranked duel **in the deciding round** (1-1, third round).

**Lion's Share** (Ledger) — **multi**
- *Objective*: be the top contributor on a world boss that goes down.

**Both Sides of the Law** (Nix) — **multi**
- *Objective*: in a single paid Most Wanted match, make an arrest **and** get away.

**Good Samaritan** (Okoro) — **multi**
- *Objective*: stabilize **3 different citizens** outside your crew.

**One-Man Army** (Ledger) — **solo**
- *Objective*: take down the Chimera **alone**: one operator at the start of the fight, one at the end.
- *Changes the game*: the four-player raid played alone on Standard.

**Walk of Shame** (Nix) — **solo**
- *Objective*: let your car run dry **at least 1 km** from the station, then come back
  with a jerrycan and get it running again (2 steps).
- *Changes the game*: you ignore the gauge on purpose, then walk to the pump and back, 16 kg
  on your back.
- *Hook*: `onFuelEmpty` (`fuel.lua:148`) with the distance to the nearest pump, then
  `onRefuelled` `kind = "pour"` in the same vehicle.

---

## 5. Jobs worked together

### 5.1 Crew bonus: +15%

- **Who**: two members of the same crew, on **distinct accounts**, in the **same job**.
- **When**: on every Sanitation or Scrapper sale, and on every paid run (Courier, AC
  Cleaner).
- **Conditions checked at payout**:
  - **fixed sites** (Sanitation, Scrapper): a teammate within **60 m** of the seller, who has
    finished a work cycle of their own (collect, process, sell) in the
    **last 5 minutes**;
  - **runs** (Courier, AC Cleaner): a teammate in the same job who has also completed a run
    step in the last 5 minutes, with no distance condition. Two couriers each head off
    their own way and meet up again at dispatch: that's the job.
- **Amount**: 15% of the pay (grade included), paid on a separate line of the statement, reason
  `crew_bonus`. The player sees "Crew bonus +15%" in the sale notice.
- **Limits**:
  - an account is only paid once per sale, however many teammates there are;
  - at most **2,000 €$** of bonus per account per UTC day (`crewBonus.dailyCap`), i.e.
    about 13,000 €$ of sales. This counter lives in memory: a server restart resets
    it (at worst 2,000 €$ more that day);
  - an idle teammate triggers nothing, since their own recent cycle is required;
  - the tutorial training sites are excluded, as is the Big Contract, which has its
    own bonus.
- **Effect**: J goes from 3,500 to ≈ 4,000 €$/h for two, still below missions (1.7 × J).
- `crewBonus.rate = 0` turns it all off.

### 5.2 The Big Contract (Courier, two couriers)

> Okoro: "Wedding in Heywood. Five, six orders, two couriers. And the bride wants everything on the
> table at once: last two drops inside two minutes of each other, or it's cold canapés."

- **How it plays**:
  - at the Job Center, a courier in a crew with another courier (distinct account, within 30 m,
    neither of them on a run) sees the **Big Contract · 2 couriers** option (or types `/job duo`);
  - dispatch draws **5 to 6 orders** and splits them into **two halves**, with different
    addresses: each courier has their own route, their own GPS and their own orders in the bag;
  - each is paid for their half on their last delivery, at the normal rate for a run.
- **The bonus**:
  - if **both halves** are delivered, each gets **+20%** of their half;
  - **+35%** if the last two deliveries land less than **2 minutes** apart
    ("Served together").
- **Why it's fun as a pair**: each has their own route, but the finish plays out at the same
  time. "I'm at the door, where are you?", "Thirty seconds!", and one waits on the
  doorstep while the other floors it. You can also do both halves in the same car:
  one drives and the other hops out. Both ways of playing are good.
- **Limits**:
  - abandoning pays nothing to whoever abandons; the other keeps their half at the normal rate,
    without the bonus;
  - the contract expires like a run (45 min);
  - the crew bonus (+15%) doesn't stack with the Big Contract;
  - the two couriers must be on distinct accounts.

---

## 6. Prestige titles

### 6.1 Rules

- **Per character**, like reputation and Hall of Fame entries
  (`identifier#characterKey`). Titles earned by the account (day streak, dailies) go to the
  character that is active when they're earned.
- **Only one title shown**, chosen in F1 → Identity → **Title**, or in the **Titles** tab
  of the Dailies panel. "No title" is always an option.
- **Where it shows**:
  - in the proximity RP chat ("Kaito Mori · Legend");
  - under the name in the crew frame;
  - next to the name in the Hall of Fame;
  - on the end-of-match screen, through `LightRP.titles.shown(id)`, which the recap agent
    can hook up.
- **Rarities**: *Common*, *Rare*, *Epic*, *Legendary*, and *Live* (a leaderboard title, held
  only while you're first). The colour follows the rarity.
- **No free text**, so nothing offensive. A title whose source is missing (resource stopped)
  is hidden from the catalogue, unless it's already earned.
- **Locked titles are visible**, greyed out, with their condition: it's the player's
  wish list.
- **No money**: prestige costs the economy nothing.
- Staff: `/lightrp.titles grant|revoke <player> <title>`.

### 6.2 Catalogue

| Title | How to earn it | Verified source | Rarity |
|---|---|---|---|
| **Merc** | Reputation tier II | `Missions.tier` | Common |
| **Operator** | Tier III | `Missions.tier` | Rare |
| **Edgerunner** | Tier IV | `Missions.tier` | Epic |
| **Legend** | Tier V (10,000 reputation) | `Missions.tier` | Legendary |
| **Chimera Breaker** | Chimera Standard cleared | `Missions.cleared` | Common |
| **Core Cracker** | Chimera Hard cleared | `Missions.cleared` | Rare |
| **Chimera Critical** | Chimera Critical cleared | `Missions.cleared` | Epic |
| **Blackout** | Sector 04 Blackout cleared on Critical | `Missions.cleared` | Epic |
| **Overclock Denied** | Chimera Hard or Critical taken down before the overclock | raid report | Rare |
| **Two-Man Army** | Chimera Hard or Critical with exactly two | `onMissionFinished` | Epic |
| **Flawless** | Chimera Critical without a single operator going down during the fight | raid report | Legendary |
| **Boss Killer** | Killing blow on a world boss | `world_bosses.lua` (last hit) | Rare |
| **Lion's Share** | Top contributor on a world boss that goes down | `onWorldEventEnded` | Epic |
| **Duelist** | 10 ranked duels won (paid verdict) | `onActivityResult` | Rare |
| **Sudden Death** | 5 duels won in the deciding round | `onActivityResult` | Epic |
| **Street Racer** | 10 grid races won with at least 3 real drivers | `onActivityResult` | Rare |
| **Getaway Driver** | 10 extractions in Most Wanted | `onActivityResult` | Rare |
| **Long Arm of the Law** | 10 arrests in Most Wanted | `onActivityResult` | Rare |
| **Ghost** | 10 extractions with at least 3 stars in NCPD Escape, against the real NCPD (`police == "ncpd"`, never `policeBlocked`), counter `pve_hot_extractions` | `onActivityResult` | Epic |
| **Seven Days Straight** | 7 UTC days in a row with at least one contract claimed | contracts | Rare |
| **Clockwork** | 30 days in a row | contracts | Epic |
| **Okoro's Favourite** | 30 contracts claimed | contracts | Rare |
| **Lucky Seven** | *Ledger's Lucky Number* completed 3 times | contracts | Rare |
| **Crowd Pleaser** | *Street Performer* completed 3 times | contracts | Rare |
| **Fumes Connoisseur** | *Running on Fumes* completed 3 times | contracts | Rare |
| **Top Gun** | No. 1 on the PvP *kills* leaderboard | Hall of Fame | Live |
| **Champion** | No. 1 on the PvP *wins* leaderboard | Hall of Fame | Live |
| **Track Record** | No. 1 in the time trial | Hall of Fame | Live |
| **Raid Lead** | No. 1 in raids cleared | Hall of Fame | Live |
| **Eddie Baron** | No. 1 in wealth | Hall of Fame | Live |
| **Most Wanted** | 5 credited kills in a row in Dogtown, the streak that puts a bounty on your head | `dogtown.lua` stats (`bestStreak`) | Rare |
| **Bounty Hunter** | End 3 Dogtown bounties | new `onDogtownKill` call | Epic |
| **Barghest's Problem** | 50 credited kills in Dogtown | `dogtown.lua` stats (`kills`) | Epic |
| **King of Dogtown** | Top credited killer in Dogtown last week; the crown holds until the end of the week | `lightrp_dogtown_stats` table | Legendary |

Notes:

- **Live titles** are read from the Hall of Fame cache at display time. Losing
  first place hides the title automatically, without writing to the database, and taking it back restores it.
- **PvP titles** answer point 12.6 of `economy-balance.md`: the 100% PvP player, whom
  reputation ignores, finally has a path. They only count results already filtered by
  `activity_pay`, so no bots and no farming between two accounts beyond the per-pair limits.
- **Dogtown titles** read the zone's real stats (merge of
  `lightrp/dogtown-rules`): only **credited** kills (not the same account, not a
  teammate, not the same pair before the `pairCooldownMs` delay). *Most Wanted* and
  *Barghest's Problem* read `LightRP.dogtown.statsFor` (the character's lifetime counters);
  *Bounty Hunter* counts a credited kill on a player who had a bounty (`onDogtownKill`).
- **King of Dogtown**: every Monday, `titles.lua` reads from `lightrp_dogtown_stats` the top player
  of the past week (kills, then loot, then deaths), skips the accounts excluded from the Hall of
  Fame (staff, tests) and gives them the crown until Sunday 23:59 UTC. It shows as
  "King of Dogtown · W45" (ISO week of the week won). A week without a credited kill
  crowns nobody. It needs the database.
- **The three "fun" titles** (*Lucky Seven*, *Crowd Pleaser*, *Fumes Connoisseur*) keep
  a record of the contracts people talk about most. They need the contract to come up three times
  in the rotation (or through a swap), so a few weeks.


---

## 7. What was replaced or restricted (2026-11-03 pass)

### 7.1 Replaced

| Old contract | Why it's out | Replaced by |
|---|---|---|
| **Still Hot** (Courier: beat the dispatch estimate) | "faster" | *Two Wheels* |
| **Heat Wave** (AC Cleaner: route in under 5 min) | "faster" | *Water Break* |
| **Billable Hours** (mission with half the timer left) | "faster" | *Support Act* |
| **Answer the Phone** (finish a fixer gig) | "once", and no gig is shipped: an impossible contract | *Leg Day* |
| **Before the Overclock** (Chimera before the enrage) | "faster" | *Clean Invoice* (nobody down) |
| **Run It Back** (beat your own time) | "faster" | removed |
| **Clock In** (unemployed: get hired) | "once" | the solo Street fallback in the Shift slot |

New solo contracts so that every slot has something to play alone: *Nightcap* (Street),
*Pit Crew* (mechanic, when the crowd is there), *One-Man Army* and *Walk of Shame* (weekly).

### 7.2 Restricted

- **On Call**: drawn only when the crowd is there; the patient is the partner (once
  per patient per week). Otherwise a Trauma Team's Shift slot gets the Street fallback.
- **Fare Paid**: same; the minimum price (6 €$) is the fuel cost of the ride (§8).
- **Roadside**: only exists on a real call (reserve or running dry on another account,
  valid for 30 min); gives the slot back when the car is served elsewhere; your own car
  isn't a call for you.

### 7.3 Kept, thresholds rechecked

- **Lucky Number**: *bug* — deposits and withdrawals at the counter or the ATM move
  any sum anywhere, so the contract was free. They are ignored, like
  transfers between players (an accomplice would have done the same thing).
- **Full Truck**: *bug* — 20 goods is exactly a full bag of finished products
  (40 kg ÷ 2 kg): anything else in the bag made the contract impossible. The threshold
  drops to 11, more than one collection bag (10), which proves a second collection before the
  sale. The text no longer promises the trunk: processing halves the weight, so the
  bag alone is enough for two collections (as the jobs flow test showed).
- **Two Against the Machine** (and the **Two-Man Army** title): *bug* — a raid of three where one
  operator left before the Chimera died ended with two members and counted. Operators
  are now counted at the start of the fight (`report.operators`). The contract is also
  **Hard only**: Critical needs at least 4 players.
- **Back to Back**: *bug* — two teammate wins in two different matches less than
  120 s apart counted; it now takes the same match (entries within 30 s).
- **Bugs found by the flow tests** (real producer modules), all fixed:
  - *Lucky Number*: the refund of a failed transfer (amount 0, type `refund`) validated
    the contract without a payment → `refund` ignored, and a zero movement never counts;
  - *Nobody Eats Alone*, *Bar Crawl*, *Housewarming*, *Nightcap*, *Water Break*: eating and drinking
    were read from the item's stats, so a soda counted as a meal and an apple
    as a drink → we read what the player does (`consumeAction`: bottle or can = drink,
    meal or snack = eat);
  - *Housewarming*: stepping out and back in under 5 s kept the gift → the gift is tied to
    the visit (a new housing session on each entry);
  - *Pit Crew*: the customer's distance was only checked at the end of the fill-up → it's checked
    over the whole fill;
  - *Two Against the Machine*: the partner rule wasn't applied (the same pair twice
    in the week, or two characters of the same account) → the other operator is the
    partner;
  - *Fragile*: only the front left seat counted as the driver → same rule as *Two
    Wheels* (the driver reported by the engine);
  - *Back to Back*, *Nobody Left Behind*: "the same match" was judged only by entry time;
    two teammates each winning **their own** arena match, started in the same second,
    validated → it also takes the same instance (routing bucket at result time,
    like the `activity_pay` roster);
  - *Nightcap*: finishing a time trial alone (`won = true` for any finished attempt,
    `op77_race engine.lua` `sendResult`, paid as PvP to one player) opened the window → it takes
    a PvE win, or a PvP win with at least two players;
  - *Lose Them*, *Leg Day*, *Nobody Left Behind*: on Standard the extraction opens at 40 s and
    sits 450 m away at the closest by car, so a real extraction often lands before the
    60 s pay floor (`too_short`) and didn't count — a fast teammate even made
    the whole crew fail → a real NCPD extraction counts even under that floor (not
    paid by the activity, paid by the contract).
- **Street Performer**, **Running on Fumes**, **Album Cover**, **Bar Crawl**, **Convoy**,
  **Fragile**, the weeklies: thresholds recalculated in §8; *Fragile* keeps 5%, a value to be confirmed
  by an in-game measurement (§10).

---

## 8. Measurements and threshold arithmetic

### 8.1 Measured facts

| Fact | Value | Source |
|---|---|---|
| Consumption | 1.1 L/km while driving, 0.6 L/min idling | `shared/config.lua` `fuel` |
| Reserve | 15% of the tank (`onFuelLow`) | `shared/config.lua`, `fuel.lua:287` |
| Tanks | default 60 L, Street 55, Utility 90, Sport 65, Bikes 30 | `fuel.tanks` |
| Fuel | 4 €$/L, 1.2 L/s at the pump | `fuel.pricePerLitre`, flow rate |
| Jerrycan | 20 L, 16 kg full, 25 €$ deposit | `shared/config.lua` |
| Station | only one, 12 pumps around (−594, −711) | `fuel.stations` |
| Rental | starting tank between 35 and 75%, 30 min | `shared/config.lua` `rentals` |
| Voice | 4 m (whisper), 15 m (normal), 40 m (shout) | `shared/config.lua` `voice` |
| New player | first 120 minutes | `LightRpEconomy.hospital.graceMinutes` |
| Bag / trunk | 40 kg and 30 slots / 80 kg | `shared/config.lua` `inventory` |
| Sanitation | 4 kg trash bag → 1 recyclable of 2 kg | `job_work.lua` |
| Scrapper | 4 scraps of 1 kg → 1 part of 2 kg | `job_work.lua` |
| Distances | Job Center → The Crossing 1,195 m; The Crossing → Afterlife 743 m; The Crossing → Ho-Oh bar 636 m; shortest round of 3 bars in 3 districts 1,173 m | `mapPlaces` coordinates |
| PvE arena | 3 bots for the first player, +2 per player, 10 at most; bot allies in the free spots (6 players); assist = 30% of a bot's health | `op77_arena/shared/lightrp.lua`, `scoring.lua` |
| Chimera | Standard 1 to 4 players, Hard 2 to 6, Critical 4 to 8 | `server/config/missions.lua` |
| NCPD Escape | head start of 6 s by car, 8 s on foot | `op77_chase` |
| Duel | best of three rounds | `op77_arena/shared/lightrp.lua` |
| Sampling | every 5 s, 70 m/s at most | `server/config/dailies.lua` |
| Lowest prices | candy 9 €$ to buy, resold for 1 €$; water 12 / 2 €$ | `server/config/shops.lua` |

### 8.2 The calculation, contract by contract

- **Lucky Number**: the finest step is 1 €$ (reselling a candy), the cheapest purchase
  9 €$, fuel 4 €$ a litre. Any balance ending can be reached; the gap to 777 is at
  most 999 €$ in one direction, and the player picks the direction (wait for their pay or a sale, or
  spend), so at most ≈ 500 €$ of real purchases or sales. Nothing is free: every step
  is a real payment.
- **Running on Fumes**: a rental bike (30 L, starting at 10.5 to 22.5 L) must burn 7.5 to
  19.5 L to drop below 3 L, i.e. **6.8 to 17.7 km**; a Street (55 L, starting at 19.3 to 41.3 L)
  **12.5 to 32.5 km**. Filling up to 50% costs at least 12 L (48 €$, 10 s) for the bike, 22 L
  (88 €$, 18 s) for the Street. Doable within the 30 min of a rental, or with your own car
  over the course of the day. The reserve (15%) warns you before the 10%.
- **Nightcap**: leaving an activity takes you back to The Crossing; the nearest bar is
  636 m away. 10 minutes leave time to walk or drive there and buy a drink, but not
  to chain a second match.
- **Nobody Eats Alone**: 15 m = the range of normal voice; 8 s = enough for "on three", not
  for two unrelated meals.
- **Ride Along**: 1,200 m ≥ Job Center → The Crossing (1,195 m), the trip every newcomer makes.
- **Street Performer**: 60 s = 12 samples; audience within 15 m (normal voice).
- **The Tour**: 750 m ≥ The Crossing → Afterlife (743 m); 15 m to stay together; the
  120 min window is the hospital's newcomer grace window.
- **Clean Invoice** / **One-Man Army**: Standard accepts one player, so both can be done alone.
- **Lose Them, Don't Wait**: on Standard, 3 stars is the cap, reached 75 s after the head start
  (81 s after GO by car), before the end of the 150 s: you have to hold full heat and then
  reach the extraction. On Hard (3 stars at 30 s) and Critical (25 s), the extraction only appears
  afterwards (55 and 70 s), so any extraction counts. Playable at tier I.
- **Quick extraction**: the extraction opens at 40 s (Standard), 55 s (Hard), 70 s (Critical),
  drawn between 450 and 1,300 m by car (200 to 500 m on foot). At 30 m/s, 450 m take 15 s:
  arrival at **55 s**, under the 60 s floor of `activity_pay` (`too_short`). A real extraction
  therefore counts for *Lose Them*, *Leg Day* and *Nobody Left Behind* even when the activity
  doesn't pay it; the clock (150 s and more) always passes the floor. The extraction can't
  come earlier than its opening, which `op77_chase` sets on the server side.
- **Leg Day**: the head start on foot (8 s) makes up for the car (6 s); the player chooses the
  mode at launch.
- **Five Without a Dirt Nap**: alone, the PvE arena fields 3 bots; a streak of 5 forces you to survive
  their respawn, so you have to change position instead of camping the spawn.
- **Support Act**: an assist needs 30% of a bot's health and then someone else's final blow;
  alone, the terminal's bot allies (free spots, still ranked) make it doable.
- **Full Truck**: a bag (40 kg) carries 10 trash bags (4 kg) or 40 scraps (1 kg) → **10**
  goods. 11 in one sale proves a second collection before the sale: after processing
  the 10 products only weigh 20 kg, which leaves 20 kg to head out again (or the trunk, 80 kg).
  The maximum for one sale is 20 (40 kg ÷ 2 kg of finished products), hence the old impossible threshold.
- **The Full Round**: 3 steps = site A, site B, sale; a sale before both sites resets to
  zero.
- **Water Break**: the AC Cleaner route has 3 units (`lift`, 3 × `work`, `return`): the window runs
  from the first to the third; the contract is only drawn if the route has at least 2 units.
- **Fare Paid**: 1.2 km × 1.1 L/km = 1.32 L × 4 €$ = 5.28 €$ → **6 €$** covers the fuel. 3 min
  to pay at drop-off.
- **Roadside**: at 15%, a Street has 8.25 L, i.e. 7.5 km before running dry: the call comes before the
  breakdown, and the call lives for 30 min. A jerrycan (20 L, 80 €$ of fuel plus a 25 €$ deposit,
  16 kg in a 40 kg bag) takes a Street from 15 to 51%.
- **Pit Crew**: due = ⌈litres × 4 €$⌉, for example 30 L → 120 €$; 15 m = normal voice. The customer
  stays in range **for the whole fill-up**: every sample during the fill
  (litres ÷ 1.2 L/s, at least 5 s) must have them within 15 m, and the end too.
- **Convoy**: 2.4 km within 40 m (shouting voice); one missed sample forgiven.
- **Back to Back**: results within 120 s, same instance and entries within 30 s (each PvE arena
  match has its own routing bucket).
- **Bar Crawl**: the shortest round of 3 bars in 3 districts is 1,173 m; an hour leaves time for the
  trip and three drinks; both drink in the same bar (25 m).
- **Album Cover**: 10 s = 3 consecutive samples; 6 m = everyone in the frame.
- **Nobody Left Behind**: results within 240 s (the time of the last round), same match within 30 s.
- **Two Against the Machine**: Hard accepts 2 to 6 players: two is the minimum; Critical
  (4 minimum) is excluded.
- **All the Way**: best of three, the deciding round is the third at 1-1.
- **Walk of Shame**: 1 km from the only station, then 2 km on foot there and back with 16 kg; the
  jerrycan costs 80 €$ of fuel and a 25 €$ deposit. Emptying a full Street takes 50 km of driving (or 92 min of idling),
  hence a weekly you prepare over the week.

---

## 9. Deliberate deviations from the approved proposal

- **Varied rewards**: 250 / 400 / 250 instead of 300 everywhere; crew 300, weekly 3,000.
- **"Revive a citizen"** becomes *On Call* (Trauma Team) and *Good Samaritan* (weekly).
- **Generic objectives dropped** ("2 Courier runs", "finish a mission as a crew"), and
  since this pass everything that asked for "faster", "more" or "once" (§7).
- **Panel**: F1 → Dailies has its own panel, and the **DAILIES** tab of the activities
  terminal shows the same page. The terminal's "Contracts" tab is still the one for mission
  boards.
- **`onActivityResult` hook**: in `activity_pay.lua`, right after the verdict.
- **NCPD Escape against the real NCPD**: losing the police is no longer visible to the server; *Lose
  Them* and **Ghost** require the extraction with at least 3 stars.

## 10. Questions for the owner

1. **Crowd**: `social.minAccounts = 4` distinct accounts online to draw a social contract.
   Is that the right number for your off-peak hours?
2. **Cap**: `dailyBudget` at 1,200 €$ per account; should it be 900 €$?
3. **Titles**: hide your title while keeping it? For now "No title" is enough.
4. **King of Dogtown**: a "W45" suffix or a date?
5. **Fragile**: 5% health lost over a run is still to be confirmed in game (measure the loss
   on a clean run, §2 of the checklist).
6. **Pay cap**: a result that is eligible for pay counts even when the day's PvE
   or PvP cap is reached (paid 0) or activity pay is switched off. This is intended (the
   dailies have their own budget); would you prefer the opposite?
   **Decided on 2026-11-03: we keep it.** The contract has its own cap (once a day);
   a result not eligible for pay (test, too short, staff-mode bots) still doesn't count.
7. **On Call**: a healed teammate counts (once a week, partner rule), whereas
   *Good Samaritan* excludes the crew. Exclude them too?
   **Decided on 2026-11-03: excluded**, as for *Good Samaritan* (`K.on_call`, flow test).

## 11. Hooks and evidence

All the logic lives in `dailies.lua`, `titles.lua` and `job_crew.lua`; the shared files
only get a one-line call. Each hook below was tracked down to its real call
site:

| File:line | Hook | Used for |
|---|---|---|
| `economy.lua:165` | `onMoneyChanged(id, wallet, delta, balance, kind)` | *Lucky Number* |
| `economy.lua:529` / `:559` | `onMoneySent(from, to, amount, "transfer" \| "cash")` | *Fare Paid*, *Pit Crew* |
| `inventory.lua:776` | `onItemUsed(id, name, item)` | *Nobody Eats Alone*, *Housewarming*, *Bar Crawl*, *Nightcap*, *Water Break* |
| `inventory.lua:1046` | `onItemGiven(from, to, name, count)` (**new**, `Inv.give`) | *Housewarming* |
| `refueling.lua:275` | `onRefuelled(id, { kind, vehicle, litres, before, capacity })` | *Running on Fumes*, *Roadside*, *Pit Crew*, *Walk of Shame* |
| `fuel.lua:287` / `:148` | `onFuelLow(vehicle, driver)` / `onFuelEmpty(vehicle, driver)` | *Roadside* calls, *Walk of Shame* |
| `activity_pay.lua:318` | `onActivityResult(id, entry, r, raw, verdict)` | Action, activity crew contracts, *Nightcap*, activity weeklies |
| `missions.lua:627` | `onMissionFinished(inst, point, d, success, why, payouts)` | Chimera (contracts and titles) |
| `mission_chimera.lua` | `raid.operators` at the start of the fight, `inst.report = { enraged, downs, operators }` | *Clean Invoice*, *One-Man Army*, *Two Against the Machine*, titles |
| `world_bosses.lua:349` | `onWorldEventEnded(ev, success)` | *Lion's Share* |
| `medical.lua:228` | `onPatientStabilized(actor, patient)` | *On Call*, *Good Samaritan* |
| `job_work.lua:182` / `:187` / `:191` | `onJobWorkCompleted(id, job, kind, info)` | *Full Truck*, *The Full Round* |
| `job_runs.lua:270` / `:315` | `onJobRunStarted(id, run)` | *Two Wheels*, *Fragile* |
| `job_runs.lua:391` | `onJobRunStep(id, run, step)` | *Water Break* |
| `job_runs.lua:405` | `onJobRunCompleted(id, run)` | *Two Wheels*, *Fragile*, *Water Break* |
| `jobs.lua:89` | `onJobChanged(id, job, previous)` | Shift slot |
| `parties.lua`, `chat.lua`, `halloffame.lua` | `title` / `titleRarity` | title display |

Page side (`ui/`): `features/dailies/` (model, panel, `DailiesToday` for the terminal,
mock-up), `features/activities/ActivitiesDialog.tsx` (DAILIES tab), `bridge/protocol.ts`
(`crewLocked`, `social`, `dailies.refresh`, `dailies` tab), `features/menu/PlayerMenu.tsx`
(F1 → **Dailies**). The `web/` bundle is regenerated by `npm run build` in `ui/`.

**Automated evidence** (`tests/`, run by `tests/run-lua.ps1`):

- `dailies_test.lua`: rotation, solo fallbacks, social gate (relock, no flip-flopping),
  Roadside call, partner rule, sampler contracts, claims, swap,
  staff tools, database round trip, the "Dailies" name in notices;
- `titles_test.lua`: including the three-player raid where one leaves (no Two-Man Army);
- `dailies_flow_*_test.lua`: each contract fed by another module, driven **by the real
  producer module**, with only the natives mocked, with the failure cases and one
  regression case per bug found:
  - `dailies_flow_street_test.lua`: economy, inventory and consumables, housing, fuel,
    pump and jerrycan (*Lucky Number*, *Nobody Eats Alone*, *Housewarming*, *Bar Crawl*,
    *Running on Fumes*, *Roadside*, *Pit Crew*, *Fare Paid*, *Walk of Shame*);
  - `dailies_flow_missions_test.lua`: a real Chimera raid, from the board to the win (*Clean
    Invoice*, *One-Man Army*, *Two Against the Machine* and its partner rule);
  - `dailies_flow_jobs_test.lua`: `job_work` and `job_runs` (*Full Truck*, *The Full Round*,
    *Two Wheels*, *Fragile*, *Water Break*);
  - `dailies_flow_activities_test.lua`: `activities.lua` and `activity_pay.lua` with the exact
    payloads of `op77_chase`, `op77_arena` and `op77_race`, world boss and medical (*Lose Them*,
    *Leg Day*, *Five Without a Dirt Nap*, *Support Act*, *Nightcap*, *Back to Back*, *Nobody
    Left Behind*, *All the Way*, *Both Sides*, *Lion's Share*, *On Call*, *Good Samaritan*);
  - the sampler contracts (*Street Performer*, *The Tour*, *Ride Along*, *Convoy*,
    *Album Cover*) have no producer other than the positions, seats and animations read
    by `dailies.lua` itself: they're in `dailies_test.lua`.
- `guide_test.lua`, `guide_dialogue_test.lua`: the `money.dailies` FAQ (F1 → Dailies, the
  Dailies tab of the Activities panel, what each slot pays, reset) and Johnny's choice
  under "How do I make money?".
