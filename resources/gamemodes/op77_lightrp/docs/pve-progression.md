# PvE progression: reputation, difficulties and cyberware

Proposal of 2026-11-03, based on the owner's brief:

> "Add new cyberware that matches the difficulty levels of PvE content; PvP
> only raises your wins, etc."

PvE (missions, the Chimera raid, fixer gigs, PvE activities) is **the only progression
path**: it earns reputation, reputation tiers unlock the higher difficulties
**and** the higher cyberware ranks at the ripperdoc, and the new top-end cyberware
matches the hardest difficulty. PvP (arena PvP modes, street races,
NCPD 1v1 / Most Wanted chases, Turf War PvP) gives **neither reputation nor power**:
wins, stats, leaderboards, ranks.

**Approved by the owner on 2026-11-03 and merged into `lightrp/pve-merge`** (with the
crews from `lightrp/activities`), with one change: crew members below the tier are never
refused anymore (§8, decision 5). All the numbers live in the configuration
(`server/config/missions.lua`, `server/config/activities.lua`, `server/config/cyberware.lua`) and
can be tuned without touching the code.

## 1. Reputation tiers ("Street Cred")

Reputation stays per character (`lightrp_mission_rep`). The first three thresholds do not
change (`0, 500, 1500`): an existing character keeps their tier. Two tiers are
added.

| Tier | Name | Threshold | Gap | What it unlocks |
|---|---|---:|---:|---|
| I | Street | 0 | — | **Standard** difficulty everywhere; cyberware ranks I–II |
| II | Merc | 500 | 500 | **Hard** difficulty; cyberware rank III |
| III | Operator | 1,500 | 1,000 | **Critical** difficulty; cyberware rank IV |
| IV | Edgerunner | 4,000 | 2,500 | Cyberware rank V (current legendaries + new ones) |
| V | Legend | 10,000 | 6,000 | Cyberware rank **V+** (new top end) |

### Where reputation comes from

| Source | Standard | Hard | Critical | Cap |
|---|---:|---:|---:|---|
| Mission (Sector 04, editor missions) | 100 | 220 | 450 | 25% at the same point for 60 min after a full-reputation payout |
| Chimera raid | 100 | 220 | 450 | same |
| Fixer gig | 100 | 220 | 450 | same |
| PvE activity (per result, weight 1.0) | 30 | 60 | 100 | 500 / account / day |
| PvP activity, race, chase, Turf War PvP | 0 | 0 | 0 | — |

Mission amounts are today's values (`reputationGain`). A failed mission earns
nothing. A PvE activity is weighted by its length (§4).

Since the production audit of 2026-11-04 (`docs/economy-balance.md` §15), an **editor**
mission or gig pays its reputation in proportion to its size, like its eddies:
enemies to defeat ÷ 12 / 18 / 24 (Standard / Hard / Critical), capped at 1. A
3-enemy contract gives 25 / 61 / 113 instead of 100 / 220 / 450; Sector 04, the Chimera raid
and full contracts are unchanged.

Since the owner's decision of 2026-11-04 (`docs/economy-balance.md` §16),
reputation from missions, gigs, Sector 04 and the Chimera raid follows the same repeat rule
as money, per character and per mission point: after a success that paid
full reputation, the same point only pays **25%** of its reputation for
**60 min** (`missions.reputationRepeatShare` / `reputationCooldownMinutes` in
`server/config/economy.lua`). The end notice says so ("+25 reputation (25% of 100: this
job gave you its full reputation less than 60 min ago, full reputation again in 42 min)"),
as does the announcement at launch. Switching to another mission point restores full reputation; the
daily money cap does not affect reputation.

### Time to reach each tier

Assumption, a "regular player who does PvE": counting queues, travel and failures
(estimated success 85% in Standard, 70% in Hard, 55% in Critical), they earn about
**180 reputation/h** in Standard, **280/h** in Hard and **350–400/h** in Critical, mixing missions and
PvE activities. Baseline of about 1 h 30 of PvE per day played.

| Tier | Cumulative PvE hours | Calendar (≈ 1 h 30/day) | Dedicated player (≈ 3 h/day) |
|---|---:|---|---|
| II Merc | ≈ 3 h | 2nd evening | 1st evening |
| III Operator | ≈ 6–7 h | end of the 1st week | 3rd day |
| IV Edgerunner | ≈ 13–14 h | ≈ 2 weeks | ≈ 1 week |
| V Legend | ≈ 30 h | ≈ 3–4 weeks | ≈ 1.5–2 weeks |

Tier V is the long-term goal for the first weeks after launch. Lowering its threshold
to 8,000 brings it down to ≈ 25 h (question for the owner, §8).

## 2. What each tier unlocks

| | I Street | II Merc | III Operator | IV Edgerunner | V Legend |
|---|:-:|:-:|:-:|:-:|:-:|
| Missions and raid: Standard | ● | ● | ● | ● | ● |
| Missions and raid: Hard | | ● | ● | ● | ● |
| Missions and raid: Critical | | | ● | ● | ● |
| Fixer gigs offered up to | Standard | Hard | Critical | Critical | Critical |
| PvE activities: max difficulty | Standard | Hard | Critical | Critical | Critical |
| Cyberware: max rank | II | III | IV | V | V+ |

**Missions and raid.** A difficulty unlocks when the tier is reached **and** the previous
difficulty has been cleared at the same point (the current "Standard before Hard" ladder is kept:
you learn the mission before making it harder). The two conditions are tuned separately
(`reputation.requireTier`, `reputation.requireClear`). The required tier comes from the
difficulty id (`standard` → I, `hard` → II, `critical` → III): editor missions, which have
no tier, follow the same rule. These two conditions limit the choice of the crew **leader**
(and of a solo player); a crew **member** below the chosen difficulty is never refused: they
are signed up and launched with the crew, play the full difficulty, get the full pay, and earn the
reputation of the highest difficulty they have unlocked (tier **and** clears;
`Missions.rewardBasis`). They see this once, in a "STREET CRED" notice, at sign-up.

**Fixer gigs.** The fixer only offers the gig owner difficulties within their tier.
A crew member invited through sharing can be a lower tier (the owner vouches for them),
but they only earn the reputation of the highest difficulty their tier allows: a
Street carried through a Critical gig earns 100, not 450. This prevents "boosting" without banning
play between friends.

**PvE activities.** The core refuses a solo player or a crew leader any difficulty above
their tier. A crew member gets the leader's difficulty, even above their own tier:
they play all of it, and their result counts at the highest difficulty their tier allows (told
once in a notice). The staff bot mode still records no results, PvE included.

## 3. Cyberware after the change

Rule: an implant requires the reputation tier of its rank. Ranks I–II → tier I (open to
everyone, including pure RP players), III → II, IV → III, V → IV, V+ → V. The server refuses
the install (message "Street cred too low"); the clinic shows the implant locked with
the required tier. **Removal** is always possible. An implant **already installed** above the
tier stays active (nothing is taken away from anyone). The staff command `/lightrp.cyberware <id> give`
ignores the tier.

The new top end is deliberately made of effects the platform already applies on
dist 177: passive stats (max health, armor, stamina, regeneration) and new Dash and Overdrive
presets (one new definition per preset; no existing definition is
changed). No new legs or arms: their durable definitions are
immutable, and adding a grade would force a version change on implants already paid for.

| Implant | System | Rank | Tier | Price (€$) | Effect |
|---|---|:-:|:-:|---:|---|
| Iron Lungs | Circulatory | II | I | 6,000 | +40 max stamina |
| Subdermal Armor | Integumentary | II | I | 6,500 | +30 armor |
| Titanium Bones | Skeleton | II | I | 7,500 | +25 max health |
| Reinforced Tendons | Legs | II | I | 9,500 | Double jump (15 stamina) |
| Adrenaline Booster | Circulatory | III | II | 8,500 | +8 stamina/s |
| Biomonitor | Circulatory | III | II | 9,000 | +1.5 health/s |
| Fortified Ankles | Legs | III | II | 11,000 | No fall damage |
| Neofiber Actuators | Nervous | III | II | 13,000 | Dash, 1 charge |
| Gorilla Arms | Arms | III | II | 15,000 | Hydraulic fists, non-lethal |
| Subdermal Armor Mk.2 | Integumentary | IV | III | 16,000 | +60 armor |
| Kinetic Impact Frame | Skeleton | IV | III | 18,000 | Ground Slam |
| Reinforced Tendons Mk.2 | Legs | IV | III | 24,000 | Double jump (8 stamina, 0.5 s) |
| Epimorphic Skeleton | Skeleton | IV | III | 24,000 | +60 max health |
| Sandevistan Mk.1 | Operating System | IV | III | 26,000 | Overdrive 10 s |
| Mantis Blades | Arms | IV | III | 28,000 | Forearm blades |
| Neofiber Actuators Mk.2 | Nervous | IV | III | 30,000 | Dash, 3 charges |
| Gorilla Arms Mk.2 | Arms | IV | III | 36,000 | Industrial fists, lethal charge |
| **Iron Lungs Mk.2** *(new)* | Circulatory | V | IV | 34,000 | +80 max stamina |
| **Adrenaline Booster Mk.2** *(new)* | Circulatory | V | IV | 36,000 | +15 stamina/s |
| **Bioplastic Blood Vessels** *(new)* | Circulatory | V | IV | 42,000 | +3 health/s |
| Electric Mantis Blades | Arms | V | IV | 62,000 | Blades, electric edge |
| Sandevistan Mk.3 | Operating System | V | IV | 64,000 | Heavy Overdrive, 2 charges |
| **Neofiber Actuators Mk.3** *(new)* | Nervous | V+ | V | 85,000 | Dash, 3 charges, 5 stamina, 0.3 s, 1 s recharge |
| **Aegis Dermal Plating** *(new)* | Integumentary | V+ | V | 90,000 | +100 armor |
| **Rara Avis** *(new)* | Skeleton | V+ | V | 95,000 | +100 max health |
| **Zetatech Apogee** *(new)* | Operating System | V+ | V | 120,000 | Heavy Overdrive 11 s, 2 charges, 22 s recharge, 30 stamina |

Price ranges: rank II 6–10 k, III 8–15 k, IV 16–36 k, V 34–64 k, **V+ 85–120 k**.
Families are still a single native slot: a higher model replaces the lower one, nothing
stacks (Rara Avis replaces Epimorphic Skeleton, Aegis replaces the Subdermal Armor…).

Ballpark, fully equipped at tier V: 200 health + 100 armor, about three times the
toughness of a bare body. This is intended for Critical (enemy damage × 1.6, Chimera barrage at
55); it is also why §8 asks the PvP question.

Top-end prices depend on the earnings the economy agent sets for missions and
gigs: they need to be reviewed with it before approval.

## 4. PvE activity difficulties

Same three difficulties as missions, same multipliers as the mission editor
(`shared/mission_defs.lua`), so that "Hard" means the same thing everywhere.

| | Standard | Hard | Critical |
|---|:-:|:-:|:-:|
| Minimum tier | I | II | III |
| Base reputation (win, weight 1.0) | 30 | 60 | 100 |
| Enemy count | × 1 | × 1.5 | × 2 |
| Enemy health | × 1 | × 1.5 | × 2.25 |
| Enemy damage | × 1 | × 1.25 | × 1.6 |
| AI | `standard` | `veteran` | `veteran`, aggressive, no player respawn if the mode allows it |

The core passes the provider `options.difficulty` (`standard` | `hard` | `critical`) and
`options.scaling = { enemies, health, damage, ai }`, taken from `server/config/activities.lua`
(`pve.difficulties`): the owner tunes everything in one place, and the provider translates it into its own
engine.

**Reputation per result** = the difficulty's base reputation × the activity weight, rounded.
If the provider sends no `reputation`, a win (`won = true`) pays the full
amount and a loss nothing; if it sends one (partial credit, a 2nd place), the core caps it at the
full amount. Daily cap shared by all PvE activities: **500 per account** (all its
characters), per UTC day.

| Activity | Weight | Standard | Hard | Critical | Why this weight |
|---|:-:|---:|---:|---:|---|
| `arena.pve` Combat Zone · PvE | 1.0 | 30 | 60 | 100 | round of about 10 min |
| `race.pve` Street Race vs AI | 0.5 | 15 | 30 | 50 | race of 2 to 5 min |
| `turf.pve` Gang Sweep | 1.2 | 36 | 72 | 120 | sweep of about 15 min |
| `chase.pve` NCPD Escape | 0.6 | 18 | 36 | 60 | escape of 3 to 6 min |

## 5. The PvP side

- **No reputation**, whatever amount the provider offers: the core sets
  reputation to 0 for any activity that is not PvE. The end notice shows it without "+rep".
- Kept as is: matches, wins, kills, deaths, best score / time / place
  (`lightrp_activity_stats`), panel leaderboards (top 5, by time for races), and the
  providers' own rankings (ranked arena rating, ranked chase, weekly
  Turf War gang influence).
- Reminder: the `arena.pve` activity currently registers with `kind = "pvp"`. So the kind is not
  enough to recognize PvE, hence the explicit `pve = true` flag (§6).
- Rollback possible: `reputation.pvpGrants = true` restores the old behavior (PvP reputation
  capped at 50 per result).
- **Option, not implemented: cosmetic titles.** One title per activity based on wins
  (10 "Contender", 50 "Veteran", 200 "Champion"), shown in the panel and the leaderboard.
  No gameplay effect. To be decided (§8).

## 6. The provider contract (backward-compatible additions)

- `activityRegister(def)` accepts `def.pve = true` (results earn reputation) and
  `def.difficulties = { "standard", "hard", "critical" }` (the difficulties the provider can
  actually play; an unknown id is ignored). Without `pve`, the config's `pve.activities` list
  can mark an activity as PvE (that is the case for `arena.pve`, `race.pve`, `turf.pve` and
  `chase.pve` until each provider sets the flag). `pve = false` wins over the
  list. A PvE activity without `difficulties` has only one implicit difficulty, Standard.
- The panel offers the difficulty (padlock and required tier on the locked ones); the
  core refuses a request above the tier and passes `options.difficulty` and
  `options.scaling`.
- `activityCheck(id, activityId, { difficulty })`: also checks the tier — the player's, or
  for a crew member, their leader's: a member below the difficulty gets through as soon as their leader
  can pick it.
- `activityEnter(id, activityId, { difficulty })`: refuses above the tier of a solo player or
  a leader, and stores the difficulty on the entry; without this third argument, the entry takes
  the one from the panel request (the leader's, for a member queued with them), otherwise the
  first one offered. A crew member below the tier of the leader's difficulty **enters** at that
  difficulty (the provider signs them into the leader's instance, nothing to change); only their
  reputation is lowered (`e.carried`, "STREET CRED" notice once).
- Module hook `onActivityChanged(id, activityId, { pve, kind, difficulty })` on entry,
  `onActivityChanged(id, nil, { left, reason })` on release (used by cyberware).
- Player command: `/activity join <id> <difficulty>` (e.g. `arena.pve hard`).
- Result: optional `result.difficulty` (only used if the entry has none). The
  reputation follows §4.
- Nothing changes for a PvP provider: its results are recorded as before, at 0
  reputation.

### What each PvE provider must change (tracking)

| Provider | To do |
|---|---|
| `op77_arena` (`arena.pve`) | `pve = true`, `difficulties = { "standard", "hard", "critical" }`; read `options.difficulty` / `options.scaling` on request and keep them on the instance (one instance per difficulty, or refuse to mix); bots: `botsFirst`/`botsPerPlayer` × `scaling.enemies` (cap `botsMax`), profile `relaxed`→`standard` / `veteran` / `veteran`, bot health and damage × `scaling` if the engine allows it; result: `difficulty`, `won` and **stop sending `reputation`** (or a share ≤ the full amount); keep `minRoundMs`; fixing `kind = "pvp"` is not needed. |
| `op77_race` (`race.pve`) | `pve = true`, `difficulties`; Hard: faster AI drivers (≈ +5% target speed, reduced catch-up), Critical: full grid, +10%, no catch-up help; reputation: win = full amount (omit it), podium = half as partial credit, otherwise 0; keep `minimumMetres` / `minimumSeconds`. |
| `op77_turf` (`turf.pve`, upcoming) | `pve = true`, `difficulties`; waves: enemy count × `scaling.enemies`, health / damage × `scaling`, Critical: armored enemies and a tight timer; result with `difficulty` and `won`. Turf War PvP unchanged (0 reputation, gang influence kept). |
| `op77_chase` (`chase.pve`, upcoming) | `pve = true`, `difficulties`; wanted level and number of NCPD pursuers × `scaling.enemies`, MaxTac in Critical; result: `won` = escaped. 1v1 and Most Wanted unchanged (0 reputation). |

All of them: read `options.squad` as today, and call `activityCheck(member, id, { difficulty })`
before letting in a crew member who did not go through the panel.

## 7. Implementation (branch `lightrp/pve-progression`, merged into `lightrp/pve-merge`)

- `server/config/missions.lua`: five thresholds, tier names, tier per difficulty,
  `requireTier` / `requireClear`.
- `server/modules/missions.lua`: `Missions.tierInfo`, `Missions.requiredTier`,
  `Missions.tierAllows`, `Missions.reputationFor`; the mission board shows and enforces the
  required tier; a gig's reputation follows each crew member's tier.
- `server/modules/fixers.lua`: the fixer only rolls difficulties within the owner's tier.
- `server/config/activities.lua` + `server/modules/activities.lua`: `pve`, `difficulties`, difficulty
  gate, PvE reputation by difficulty and by weight, PvP at 0, tier in the panel state,
  `onActivityChanged` hook for modules.
- `server/config/cyberware.lua` + `server/modules/cyberware.lua`: seven implants, tier per rank,
  server refusal, locked catalog sent to the clinic, `activeInPvp` switch.
- Clinic (`ripperdoc-ui`): locked implants with the required tier, the patient's reputation
  in the header. **The `op77_ripperdoc/web` bundle is not rebuilt in the branch**: rebuild
  it at merge time (`npm run build` in `ripperdoc-ui`).
- Activities panel and mission board (`ui/`): locked difficulty choice, required tier,
  player's tier.
- After the 2026-11-03 decision (`lightrp/pve-merge`): `Missions.rewardBasis` /
  `Missions.reputationFor(id, d, point, ladder)` (the reward of the highest unlocked
  difficulty), `Missions.tellCarried` (the notice), the `carried` flag on board members
  (no gate at sign-up or launch); `difficultyFor` in `activities.lua` (the leader's gate
  for a member), the leader's difficulty on the members' queue; the end notice names
  the difficulty played and the one that paid; the mission board exposes `reputation`, `earns`,
  `earnsAs` per difficulty (a member can open the board for a difficulty that is locked to them).

## 8. Owner decisions (2026-11-03)

In short: tiers, names, top-end prices, PvE weights and 500/day approved as proposed;
the "clear the previous one" ladder is kept; cyberware stays active in ranked PvP; implants
already installed above the tier stay installed and active; **a crew member below the tier
is never refused** (they play, for the reward of what they have unlocked); PvP cosmetic titles
wanted later, not built now. The questions as they were asked:

1. **Cyberware in ranked PvP.** Today implants stay active in every activity
   (except Mantis blades, refused when the activity holsters RP weapons). Should they be turned off in PvP
   for fairness? Switch `LightRpCyberwareConfig.activeInPvp`, **default `true`
   (current behavior)**. At `false`, entering a non-PvE activity suspends Dash, Overdrive,
   Ground Slam and passive bonuses, which come back on exit. Limit: durable legs and arms
   (double jump, Gorilla Arms) stay active, since the platform holds them in a durable registration.
   → **Decided: active** (`activeInPvp = true`, the default).
2. **Thresholds** `0 / 500 / 1 500 / 4 000 / 10 000` and tier names. → **Approved.**
3. **Top-end prices** (85–120 k), to be aligned with the economy agent's mission earnings.
   → **Approved as proposed.**
4. **Mission ladder**: keep "clear the previous difficulty" on top of the tier?
   → **Kept.**
5. **Crew members below the tier**: refused on mission boards (every member must have the
   tier), accepted in a shared gig with their own tier's reputation. Is that OK?
   → **Changed: never refused.** When the leader picks a difficulty (mission board, Chimera
   raid, gig, PvE activity through `activityCheck` / `activityEnter` with `{ difficulty }` or through
   the crew queue), a member whose tier (or previous clear) does not unlock it still gets in
   and plays it in full; only their reputation drops to that of the highest difficulty they have
   unlocked (the gig rule, everywhere). The leader's gate stays (they only pick what they have
   unlocked); a solo player is still subject to the gate. The member sees it once: "Critical is
   above your street cred: you play it, you earn the Standard reward."
6. **Implants already installed** above the tier: kept (proposed) or removed and refunded?
   → **Kept and active.**
7. **PvP cosmetic titles**: yes / no. → **Wanted later, not built now.**
8. **PvE activity reputation**: 30 / 60 / 100 per result, weight per activity, 500 per
   day. → **Approved.**

## 9. Checking in game

1. `/missions.rep <id> 0`, open the Sector 04 board: Hard and Critical locked, "REP TIER
   II" / "REP TIER III". `/missions.rep <id> 500` then `/missions.unlock <id> sector04_blackout
   standard`: Hard unlocks. `/missions.rep <id>` alone shows the tier.
2. Sit on a ripperdoc chair at 0 reputation: ranks III and up are marked "REP
   II" to "REP V", and the install is refused server-side; at 10,000 everything unlocks.
3. Activities panel: `Combat Zone · PvE` offers Standard / Hard / Critical, and difficulties
   above the tier are locked; a forced request (`/activity join arena.pve hard`) at 0
   reputation is refused ("Hard needs reputation tier II (Merc)"). As long as `op77_arena` does not read
   `options.difficulty`, the round plays at its current difficulty; it still sends
   `reputation` 18 (win) or 3 (loss), which the core caps at the difficulty's ceiling: the
   end notice says "Standard · won · +18 reputation" today, and "+30" once the provider
   stops sending an amount for a win.
4. An `arena.ffa` round: the end notice no longer shows reputation, and the leaderboard counts the
   win.
5. `LightRpCyberwareConfig.activeInPvp = false`, `ensure op77_lightrp`, enter `arena.duel` with
   a Sandevistan: `/lightrp.cyberware <id> status` shows `overdrive=none` during the duel, and the
   grant comes back on return.
6. The clinic bundle must be rebuilt first (`npm run build` in `ripperdoc-ui`,
   which writes `resources/standalone/op77_ripperdoc/web`) to see the locks; without it the
   server still refuses the install, and the page only shows the error.
7. Crew below the tier: a leader at 5,000 with Standard and Hard cleared (`/missions.unlock`), a
   member at 0 in their crew, `/missions.size sector04_blackout critical 2 8`. The member's
   board shows Critical locked "WITH THE CREW +100 REP"; the leader signs up for Critical, the
   reply says "reduced reward: <member> (Standard)", and the member reads the STREET CRED notice;
   `/missions.complete <leader>`: pays Critical to both, +450 to the leader, "+100 reputation
   (Standard reward)" to the member. The same member on their own is refused Critical.
