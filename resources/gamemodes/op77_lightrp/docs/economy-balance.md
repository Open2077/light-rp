# Economy balance (public opening)

Currency: eddies (€$). All the figures below live in configuration
files; the code only holds the rules (pot sharing, cooldown, caps,
bills, activity pay). The owner's decisions of 2026-11-03 (D1 to D7)
are applied on the `lightrp/economy-balance` branch; what is still to be decided is
in §12. The prod audit of 2026-11-04 (editor contracts, world bosses, casino)
is in §15, its questions in §15.7.

## 1. Starting point (`lightrp/activities` branch, before balancing)

**Measured hourly income** (simulation on the real coordinates of the points;
assumptions: car with a trunk, 50 to 70 km/h on average, real road = 1.35 × the
straight line, 1 min per delivery stop, 3 min of handling per loop):

| Source | Before | Detail |
| --- | --- | --- |
| Sanitation | 1,800 – 2,100 €$/h | 30 bags (40 kg bag + 80 kg trunk) × 18 €$, 6 km loop |
| Scrapper | 1,700 – 2,200 €$/h | 30 lots × 24 €$, 8 to 9.6 km loop |
| Courier | 2,300 – 2,900 €$/h | 748 €$ on average per 7.5 km run (as the crow flies), **39% of runs hit the 900 cap** |
| Rooftop (AC Cleaner, legacy) | ~2,400 €$/h | 260 €$ for 5 to 8 min |
| Paycheck | 80 – 220 €$/h | 40 to 110 €$ every 30 min, paid to every connected player (even idle ones) |
| Standard Chimera mission | **43,000 €$/h per head** | 18,000 €$ for 20 min, doable solo, **paid in full to each member**, no cooldown |
| Critical Sector 04 heist | 40,000 €$ × 8 = **320,000 €$ created** per run | same |
| Fixer gigs | 8,000 / 15,000 / 30,000 €$ per head | 15 to 20 min, editor default values |
| Activities (arena, races, chases, turf) | 0 €$ | reputation only |

A standard Chimera was worth 6 to 9 h of work; a crew of 4 created 72,000 €$ in
20 min. Purchases (cars 4,000 – 60,000, cyberware 6,000 – 64,000, weapons 1,200 –
10,500) were used up after a few missions, and there was almost no
recurring spending: money piled up and then was worth nothing.

**Verified recurring spending**: food and drink ≈ 33 €$/h, fuel 3 €$/L
(1.1 L/km, ≈ 200 €$/h behind the wheel), rental 50 – 100 €$ per 30 min, impound 150 – 250 €$,
paint 1,000 €$. Free: the hospital, the fitting booth. Revive kits
(`trauma_kit`) were not sold anywhere.

## 2. Target curve (decisions D1 of 2026-11-03)

Reference: **J = 3,500 €$/h** for an active player at the entry grade, with a car
(≈ 3,400 €$/h net of fuel, food and costs).

| Owner's goal | Target | Result (regular player, §7) |
| --- | --- | --- |
| Not too easy to max out cyberware or own the best cars | — | see the following rows |
| First decent car (10,000 – 15,000) | ≈ 3 – 5 h | Hella 12,000 at 2.5 h, Colby 14,000 at 2.9 h, Supron 16,000 around 3.5 h |
| Best cars | ≈ 20 – 30 h | Kusanagi 80,000 at 18.8 h, Semimaru 100,000 at 23.7 h |
| Full rank V+ set | ≈ 60 – 90 h | 330,000 €$ (proposed prices, §9): 80.3 h of saving |
| Full high-end loadout | costs more than you earn by reaching Legend | 557,000 €$ against 197,000 €$ earned at Legend (48 h) |
| Missions | must not crush jobs | 1.7 to 1.8 × J per hour within the 6 full payouts, then 0.44 × J |
| 250 €$/min cap | held | missions 220 €$/min at most, activities 87.5 €$/min at most |
| Ranked PvP activities | average player ≈ J, good player a bit more | 0.91 × J (average), 1.04 × J (good), daily cap |
| PvE activities | modest, below missions | 0.48 to 0.60 × J, 0.27 to 0.36 × missions |
| First day | free / affordable | free studio, tutorial unchanged, hospital and booth free for the first 120 minutes of play |

## 3. Missions and gigs (`server/config/economy.lua` → `missions`, D2 and D3)

1. **`payout` changes meaning**: it is the share **of each operative at the minimum
   crew** of the difficulty (so what the board shows stays an honest maximum).
2. **Sub-linear, shared pot**: above the minimum, the share is
   `payout × (crew / minimum) ^ (exponent − 1)`, exponent **0.7**. The total pot
   grows like `crew ^ 0.7` instead of `crew`: 4 operatives create 2.64 shares,
   not 4. The crew counted is the one that finishes.

   | Crew / minimum | 1 | 1.5 | 2 | 3 | 4 | 6 | 8 |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | Share per head | 100% | 88.5% | 81% | 72% | 66% | 58% | 54% |
   | Total pot (in shares) | 1 | 1.33 | 1.62 | 2.16 | 2.64 | 3.51 | 4.29 |

3. **Cooldown per character and per point (D3)**: after a full payout, the same mission
   point (board or gig) only pays in full again after **60 min**.
4. **Daily cap per account (D2, D3)**: **6 full payouts** per UTC day, across all
   characters of the account (`capScope = "account"`).
5. **Beyond that**: the mission pays **25%** of the share. Helping your friends still pays;
   farming no longer does. Reputation follows each player's tier (a crew member below the tier
   earns the reputation of their own tier, `docs/pve-progression.md`) and, since
   2026-11-04, the same per-point cooldown: 25% for 60 min after a full
   reputation grant (§16.2); the daily cap does not affect it.
6. **Safety cap**: a share never goes above **250 €$ per clock minute** of the
   difficulty.
7. **Announcement**: at launch, each operative gets their expected pay (and the reason
   for any reduction); at the end, the notice gives the amount, the crew and the reduction.

**Editor missions already saved**: `/lightrp.missions.repay` (preview) then
`/lightrp.missions.repay apply` (staff, ACL `command.lightrp.missions.repay`). A
difficulty whose pay is above the safety cap (250 €$ × its minutes) is on the old
scale: it is multiplied by new / old default of its difficulty (8,000 →
2,400, 15,000 → 3,000, 30,000 → 4,400), rounded to 50 and kept below the safety cap;
a pay already below the safety cap stays as the staff set it. Each mission is rewritten with
a revision check (a mission edited in the meantime is skipped, never overwritten) and then
republished, so its board shows the new amount. Running it again changes nothing.
*Extended on 2026-11-04 (§15.5): editor missions also have a band per
difficulty and pay according to their size; the command takes this into account.*

## 4. Job pay: active players only (D4)

`server/modules/work_activity.lua`, `economy.lua` → `paychecks`. Light RP has no
clock-in: **being on duty = having a salaried job**. Grade pay
(every 30 min) is only paid to a player who did something real in the
**last 30 minutes**, based on what the server sees itself, never on a
claim from the client:

- a job task: a free-work lot (`onJobWorkCompleted`), a work order
  accepted (`onJobRunStarted`) or paid (`job_run`);
- a patient stabilized with a kit (`onPatientStabilized`, new hook in `medical.lua`);
- a transfer of at least **50 €$** received from another player (a customer served);
- **75 m** traveled in the city: positions sampled by the server every 20 s, in
  bucket 0, alive, outside activities and missions; a jump of more than 2 km (teleport,
  return from an activity) does not count, it re-anchors the measurement.

An idle player gets nothing; they are warned **once** per idle
period (notice "No paycheck") and the server logs it. Everything is configurable;
`requireActivity = false` restores the old rule.

## 5. Activities: pay in eddies (requirement of 2026-11-03)

`server/modules/activity_pay.lua`, `economy.lua` → `activities`. The core
(`activities.lua`) hands it every accepted result through **one line**, after filtering out
the staff bot mode and `test` results.

**Ranked PvP** (`arena.ffa`, `arena.blade`, `arena.teams`, `arena.duel`, `race.trial`,
`race.grid`, `race.foot`, `chase.1v1`, `chase.wanted`, `turf.war`):

```
pay = 70 €$ × mode rate × minutes played (≤ the mode's maxSeconds)
      × min(1, real players / the mode's full lobby)
      × (0.75 participation + 0.5 × result)
```

- **Result**: 1 for a win or first place, down to 0 for last
  place (ranking modes: `(n − place) / (n − 1)`), 0.5 for a draw, 0 for a
  loss; a time trial (`race.trial`, rate 0,5, solo) scores a personal record
  or a track record.
- **Real players**: accounts the server saw in the same activity and the same
  bucket during the match (sampled every 10 s and at the result). Never a number
  sent by the provider or the client. Full lobby: 4 (FFA, blade, teams, races,
  wanted), 2 (duel, 1v1), 6 (turf), 1 (time trial).
- **Minutes played**: the provider's measurement (`durationMs`, `timeMs`, `seconds`),
  never more than what the core saw since the entry or the previous result.
- Average player ≈ 3,360 €$/h gross from matches (80% of the hour in matches), good player
  ≈ 3,860, winner of everything 4,200.

**PvE** (`arena.pve`, `race.pve`, `chase.pve`, `turf.pve`): **40 / 50 / 60 €$ per
minute** on Standard / Hard / Critical, half on a loss. The difficulty is
the one picked at entry (chosen in the panel, `docs/pve-progression.md`), else the one in the
result, else the mode's (Standard for the arena and the race, Hard for the chase
and turf). Bots are the opponents there: they cancel nothing.

**Nothing** for:

- an unranked result: staff bot mode and `result.test` (filtered out by the core),
  `result.unranked = true`, a PvP match with bots (`stats.bots`, `vsAi`);
- leaving: `stats.quit`, `stats.forfeit` (the one who stays when the other gives up
  keeps only the participation share), an abandoned race (`dnfReason` `left`,
  `dropped`, `disconnect`);
- an AFK: none of the mode's progress stats (kill or assist in the arena,
  round won in duel / 1v1, points in wanted, capture, kill or 30 s of holding in turf,
  finish or 2 checkpoints in a race, escape or shake-off in a chase);
- a match shorter than the mode's minimum (1 to 3 min);
- a match where **all the real players are in the same crew**.

**Anti-farm**: the same accounts are only paid together **4 / 3 / 4 / 5 times per
hour** (sets of 1 / 2 / 3 / 4 accounts; beyond that, no limit), with a notice
when the limit kicks in. **Daily cap per account** (all characters): **12,000 €$
in PvP, 6,000 €$ in PvE** per UTC day, stored in the database (`lightrp_activity_pay_daily`), with a
notice once it is reached.

Each payout goes through `LightRP.money.addBank` with the line `activity_pvp` or
`activity_pve` and a notice "+€$ N — Combat Zone · #1 of 4 · 10 min".

## 6. Recurring spending

| Spending | Rule | Amount |
| --- | --- | --- |
| **Hospital bill** | only on "Give up and go to hospital"; never on a revive, in a mission or in an activity, nor during the first day and the first 120 minutes; bank first, then cash, **never below zero** | **300 €$** |
| **Fitting booth** (D7) | a visit to a public booth that ends with a saved look; housing, character creation, the first day and the first 120 minutes are free; free if the player cannot pay | **50 €$** |
| **Revive kit** (D5) | sold at the Corner Market (`street_food`), not bought back; revives a downed ally, never yourself; cheaper than the hospital bill | **250 €$** |
| **Impound** (D6) | **wreck** (destroyed, exploded or at 0 health: game-engine flags, damage event or captured properties), on restart, on removal or when sent by the owner: insurance deductible, the insurance repairs it. **Lost without a trace** (deleted, cleaned up, lost to a bug): 150. Sent by the owner, vehicle intact: 250. Staff: 500. Restart of an intact vehicle: free. A wreck cannot be parked. | **400 / 150 / 250 / 500** |
| Fuel | 1.1 L/km: ≈ 260 €$/h behind the wheel | 4 €$/L |
| Food | +50%: ≈ 50 €$/h, 1.5% of income | 9 – 36 €$ |

D6, known limit: a vehicle that explodes and then disappears **without any damage
signal reaching the server** (no update, no event, no captured
properties) cannot be told apart from a lost vehicle: it is billed **150**.

## 7. Progression pace (pacing)

Model: `pacing` of 2026-11-03, hours **of play**. Assumptions: money net of 8%
running costs; start 1,750 €$; job 3,700 €$/h gross (active pay included);
missions: Chimera, Sector 04 and gigs mixed, average crew 1.5 × the minimum, success
85 / 70 / 55%, a success takes 70% of the clock plus the approach; activities: 80%
of the hour in matches, PvE won at 85 / 70 / 55% depending on the difficulty. Reputation (rules
of `docs/pve-progression.md`): 180 / 280 / 375 per hour of PvE (missions and PvE
activities), PvE activities capped at 500 per day, **no reputation in PvP**. The player
picks the highest open difficulty. The "saving" columns assume they buy
nothing else; the cumulative path buys in order.

Profiles:

- **Regular**: 2.5 h/day = 1 h of missions, 0.5 h of PvE activities, 1 h of job
  (≈ 4,100 €$/h).
- **Grinder**: 6 h/day = missions up to the 6 full payouts, 0.5 h of PvE, job
  afterwards (≈ 5,300 €$/h).
- **PvP**: 2.5 h/day of ranked PvP, average player ≈ 3,090 €$/h (good player ≈ 3,560 in
  parentheses).
- **PvE**: 2.5 h/day of PvE activities only (≈ 1,850 to 2,030 €$/h depending on the tier).

### 7.1 Cars and tiers

| Hours of play until… | Regular | Grinder | PvP (good) | PvE |
| --- | --- | --- | --- | --- |
| Hella 12,000 | 2.5 | 1.7 | 3.3 (2.9) | 5.8 |
| Colby 14,000 (first decent car) | 2.9 | 2.1 | 4.0 (3.5) | 6.9 |
| Kusanagi 80,000 | 18.8 | 15.1 | 25.3 (22.0) | 39.1 |
| Semimaru 100,000 (best car) | 23.7 | 18.9 | 31.8 (27.6) | 48.8 |
| Tier II (500): rank III | 3.8 | 2.8 | never | 2.8 |
| Tier III (1,500): rank IV | 10.4 | 8.5 | never | 7.7 |
| Tier IV (4,000): rank V | 21.0 | 15.1 | never | 20.1 |
| Tier V Legend (10,000): rank V+ | 48.0 | 31.1 | never | 50.1 |
| Earned on reaching Legend | 197,000 | 164,800 | — | 100,900 |

### 7.2 Implants (saving only, from when the rank opens)

| Rank (price) | Regular: first / full rank | Grinder | PvP (good) | PvE |
| --- | --- | --- | --- | --- |
| II (6,000 ; 29,500) | 0.7 / 6.6 | 0.7 / 6.1 | 1.4 / 9.0 (1.2 / 7.8) | 2.6 / 14.5 |
| III (8,500 ; 56,500) | 3.8 / 13.1 | 2.8 / 10.7 | never | 4.0 / 27.7 |
| IV (16,000 ; 202,000) | 10.4 / 48.7 | 8.5 / 37.6 | never | 7.9 / 98.5 |
| V (34,000 ; 238,000) | 21.0 / 57.8 | 15.1 / 44.2 | never | 20.1 / 116.1 |
| V+ (70,000 ; set 330,000) | 48.0 / **80.3** | 31.1 / 61.1 | never | 50.1 / 160.9 |
| Full high-end loadout (557,000) | 135.8 | 102.8 | rank V+ closed | 271.4 |
| The whole catalog (828,000) | 202.6 | 152.4 | ranks closed | > 400 |

Full high-end loadout: the V+ set, the best rank V implant of every other
family (Iron Lungs Mk.2, Adrenaline Booster Mk.2, Bioplastic Blood Vessels, Electric
Mantis Blades) and Reinforced Tendons Mk.2, Fortified Ankles, Kinetic Impact Frame.

### 7.3 Cumulative path

Order: Colby, Reinforced Tendons, Neofiber, Sandevistan Mk.1, Semimaru, Sandevistan
Mk.3, then the V+ set (Neofiber Mk.3, Aegis, Rara Avis, Apogee). Hour of play of each
purchase:

| Purchase | Regular | Grinder | PvP (good) | PvE |
| --- | --- | --- | --- | --- |
| Colby | 2.9 | 2.1 | 4.0 (3.5) | 6.9 |
| Reinforced Tendons | 5.2 | 4.5 | 7.0 (6.1) | 11.6 |
| Neofiber | 8.2 | 7.3 | rank closed | 17.9 |
| Sandevistan Mk.1 | 14.8 | 12.1 | rank closed | 30.6 |
| Semimaru | 39.2 | 30.4 | 39.4 (34.3) | 79.3 |
| Sandevistan Mk.3 | 55.0 | 42.2 | rank closed | 110.4 |
| Neofiber Mk.3 | 72.1 | 55.0 | rank closed | 144.5 |
| Aegis Dermal Plating | 90.4 | 68.6 | rank closed | 181.1 |
| Rara Avis | 110.2 | 83.2 | rank closed | 220.0 |
| Zetatech Apogee (end) | **135.7** | **102.7** | — | 271.2 |

### 7.4 Checks

- **Missions and jobs**: within the 6 full payouts, 5,760 – 6,020 €$/h net, i.e. 1.7 to
  1.8 × the job; beyond that (25%), ≈ 1,450 – 1,500 €$/h, less than the job. So the grinder
  goes back to the job after ≈ 2.5 to 5.5 h of missions per day.
- **Activities**: average PvP 0.91 × the job, good player 1.04 ×, cap 12,000 €$/day
  (≈ 3.9 h of average PvP); PvE 0.48 to 0.60 × the job, 6,000 €$/day.
- **250 €$/min cap**: the most expensive mission per minute pays 220 €$ (editor
  critical, 4,400 for 20 min); PvP activity 87.5 €$/min at most (win, full
  lobby), PvE 60 €$/min.
- **High-end loadout > money earned up to Legend**: 557,000 against 197,000
  (regular), 164,800 (grinder), 100,900 (PvE); a pure PvP player never reaches Legend.
- **V+ set in 60 – 90 h for the regular**: 80.3 h of saving with the proposed prices
  (330,000); at current prices (390,000) it would take ≈ 95.

## 8. Before / after table (every number changed)

| File | Key | Before | After |
| --- | --- | --- | --- |
| `server/config/job_work.lua` | `sanitation.price` | 18 | **30** |
| | `scrapper.price` | 24 | **40** |
| `server/config/delivery.lua` | `pay.base` / `perStop` / `perKm` | 40 / 20 / 90 | **60 / 30 / 120** |
| | `pay.min` / `pay.max` | 80 / 900 | **150 / 1,400** |
| `server/config/job_runs.lua` | `ac_cleaner.reward` | 260 | **400** |
| `server/config/economy.lua` | `jobs.gradeBonus` | — | **0.10** per grade (sales, runs) |
| `shared/jobs.lua` (pay / 30 min) | Sanitation 0–3 | 40 / 60 / 80 / 110 | **100 / 150 / 200 / 275** |
| | Scrapper 0–2 | 45 / 65 / 90 | **110 / 160 / 225** |
| | AC Cleaner 0–2 | 50 / 75 / 100 | **110 / 160 / 225** |
| | Courier 0–2 | 45 / 65 / 95 | **110 / 160 / 240** |
| | Mechanic 0–3 | 50 / 75 / 105 / 140 | **200 / 275 / 350 / 450** |
| | Taxi 0–1 | 50 / 70 | **200 / 275** |
| | Medic 0–2 | 55 / 85 / 120 | **225 / 325 / 425** |
| | NCPD 0–3 | 60 / 90 / 120 / 150 | **250 / 325 / 400 / 500** |
| `server/config/economy.lua` | `paychecks` (D4) | paid to everyone connected | **active only**: 30 min, 75 m, transfer ≥ 50, sampling 20 s, jump 2 km |
| `server/config/missions.lua` | Sector 04 standard / hard / critical | 12,000 / 22,500 / 40,000 (per head) | **3,500 / 5,000 / 9,000** (per head at 2 / 4 / 6) |
| | Chimera standard / hard / critical | 18,000 / 34,000 / 60,000 (per head) | **3,000 / 4,500 / 6,000** (per head at 1 / 2 / 4) |
| `shared/mission_defs.lua` + editor | standard / hard / critical defaults | 8,000 / 15,000 / 30,000 | **2,400 / 3,000 / 4,400**; missions already saved: `/lightrp.missions.repay` |
| `server/config/economy.lua` | `missions.crewExponent` | (full pay per head) | **0.7** |
| | `missions.cooldownMinutes` | — | **60** |
| | `missions.dailyFullPayouts` / `capScope` | — | **6** / `account` |
| | `missions.repeatShare` | — | **0.25** |
| | `missions.maxSharePerMinute` | — | **250** |
| | `activities.pvp` | 0 (no eddies) | **70 €$/min**, participation **0.75**, result **0.5**, cap **12,000/day**, repeats **4 / 3 / 4 / 5 per hour** |
| | `activities.pve` | 0 (no eddies) | **40 / 50 / 60 €$/min**, loss **0.5**, cap **6,000/day** |
| | `hospital.bill` / `graceMinutes` | free | **300** / **120** |
| | `fitting.fee` / `graceMinutes` | free | **50** / **120** |
| `server/config/garages.lua` | `impound.fees` destroyed / lost / requested / staff | — / 150 / 150 / 250 | **400 / 150 / 250 / 500** (restart 0 unchanged) |
| `server/config/shops.lua` (`street_food`) | `trauma_kit` (purchase) | not sold | **250** (not bought back) |
| | water, burrito, noodles, dumplings, pizza | 8, 18, 24, 20, 16 | **12, 26, 36, 30, 24** |
| | synth-meat, onigiri, apple, candy, bar | 15, 12, 10, 6, 14 | **22, 18, 15, 9, 20** |
| | soda, coffee, juice, energy, electrolytes | 10, 12, 12, 18, 16 | **15, 18, 18, 26, 24** |
| `shared/config.lua` | `fuel.pricePerLitre` | 3 | **4** |
| `server/config/dealerships.lua` | Hella / Colby / Supron | 10,000 / 12,000 / 14,000 | **12,000 / 14,000 / 16,000** |
| | Quartz / Hozuki / Columbus | 16,000 / 19,000 / 22,000 | **19,000 / 24,000 / 30,000** |
| | Cortes / Merrimac / Bandit | 28,000 / 32,000 / 35,000 | **38,000 / 46,000 / 52,000** |
| | Thrax / Kusanagi / Semimaru | 42,000 / 45,000 / 60,000 | **62,000 / 80,000 / 100,000** |
| `server/config/cyberware.lua` (**not changed here**, §9) | V+: Neofiber Mk.3 / Aegis / Rara Avis / Apogee | 85,000 / 90,000 / 95,000 / 120,000 | **70,000 / 75,000 / 80,000 / 105,000** (proposed) |

**Unchanged, on purpose**: starting money (250 + 1,500), free starting
studio, tutorial training pay (40), first cars (MaiMai 4,000,
Apollo 5,000, Galena 6,500), paint (1,000), weapons and ammo, rental (50 – 100 €$
per 30 min), free transfers, shop buy-back, gig multiplier (1.0),
rank II to V cyberware.

## 9. Cyberware: exact price list (for the cyberware owner)

> Update 2026-11-03: the "Current" prices stay in place (V+ set at 390,000), six
> implants are added and every implant costs capacity points: see §14.

`server/config/cyberware.lua` belongs to the cyberware agent and is **not changed**
by this branch. Prices to apply, by id (`price`):

| Rank | id | Current | Proposed |
| --- | --- | --- | --- |
| II | `iron_lungs` | 6,000 | 6,000 |
| II | `subdermal_armor` | 6,500 | 6,500 |
| II | `titanium_bones` | 7,500 | 7,500 |
| II | `reinforced_tendons` | 9,500 | 9,500 |
| III | `adrenaline_booster` | 8,500 | 8,500 |
| III | `biomonitor` | 9,000 | 9,000 |
| III | `fortified_ankles` | 11,000 | 11,000 |
| III | `neofiber` | 13,000 | 13,000 |
| III | `gorilla_arms` | 15,000 | 15,000 |
| IV | `subdermal_armor_mk2` | 16,000 | 16,000 |
| IV | `impact_frame` | 18,000 | 18,000 |
| IV | `reinforced_tendons_mk2` | 24,000 | 24,000 |
| IV | `epimorphic_skeleton` | 24,000 | 24,000 |
| IV | `sandevistan_mk1` | 26,000 | 26,000 |
| IV | `mantis_blades` | 28,000 | 28,000 |
| IV | `neofiber_mk2` | 30,000 | 30,000 |
| IV | `gorilla_arms_mk2` | 36,000 | 36,000 |
| V | `iron_lungs_mk2` | 34,000 | 34,000 |
| V | `adrenaline_booster_mk2` | 36,000 | 36,000 |
| V | `bioplastic_blood_vessels` | 42,000 | 42,000 |
| V | `mantis_blades_electric` | 62,000 | 62,000 |
| V | `sandevistan_mk3` | 64,000 | 64,000 |
| **V+** | **`neofiber_mk3`** | 85,000 | **70,000** |
| **V+** | **`aegis_dermal_plating`** | 90,000 | **75,000** |
| **V+** | **`rara_avis`** | 95,000 | **80,000** |
| **V+** | **`zetatech_apogee`** | 120,000 | **105,000** |

Why lower V+: at current prices the set costs 390,000 €$, ≈ 95 h of saving for the
regular player, beyond the 60 – 90 h target; at 330,000 it takes 80. The rank stays
gated by the Legend tier (48 h for the regular): these prices do not bring access forward,
only completion. Ranks II to V already fit the curve (§7.2).

## 10. Price bands for the other teams

**Housing** (`/housingadmin`, values in the database): a 7-day lease ≈ 1.5 to 3 h of
work for a small apartment (5,000 – 10,000 €$), 15,000 – 25,000 €$ for a medium one;
purchase 60,000 – 250,000 €$ (resale at 50% already in place). The Kabuki studio stays
free.

**New vehicles**: 12,000 – 16,000 for a "decent" vehicle, 30,000 – 60,000
for the mid-range, 80,000 – 100,000 for the high end (≈ 20 – 25 h for the regular
player).

## 11. Check in game

- `/work sanitation sell` with lots: 30 €$ per lot (×1.1 at grade 1).
- Standard Chimera solo: 3,000 €$; as a duo: 2,437 €$ each. Run it again right away: 25%.
  Seven full payouts in one day: the seventh pays 25%.
- Paycheck: stand still for 30 min with a salaried job → no paycheck, a notice
  "No paycheck", a log line; a lot sold, a patient stabilized or 75 m on
  foot → the next paycheck comes in.
- Kit: Corner Market, 250 €$; not bought back when sold; it revives an ally.
- Impound: blow up your car, then bring it back → 400 €$, repaired; a car
  deleted by staff without damage → 150 €$; a wreck cannot be parked.
- Activities: FFA with 4 real players, 10 min, first place → +875 €$ and notice
  "Combat Zone · #1 of 4 · 10 min"; last with one kill → 525; with two → half;
  fourth duel of the same pair within the hour → nothing, notice; FFA with bots → nothing.
  Standard PvE arena won in 10 min → 400.
- `/lightrp.missions.repay` then `apply`: editor missions move to the new
  scale; a second pass changes nothing.
- `/lightrp.account me` and `/bank` show the lines `mission`, `gig`, `salary`,
  `activity_pvp`, `activity_pve`, `hospital`, `fitting`.

## 12. For the owner to decide

1. **Active pay (D4)**: it applies to **all** salaried jobs (including
   loop jobs), since there is no clock-in. The "75 m in 30 min" signal is
   deliberately broad (a taxi that drives around is active); a stubborn player can drive
   in circles. A real clock-in would be the lasting fix.
2. **Impound**: restarting an **intact** vehicle stays free; and a wreck
   that disappears without any damage signal is billed 150 (lost), not 400.
3. **V+ prices** to apply on the cyberware side (§9) — or keep 390,000 and accept ≈ 95 h.
   *Decided on 2026-11-03: 390,000 kept; capacity limits power instead
   (§14).*
4. **Car price increase**: the high end goes from 60,000 to 100,000. The Kusanagi
   (80,000) drops to 18.8 h for the regular, just under 20 h; raising it to 85,000 would
   put it back at ≈ 20 h.
5. **Activity pay**: 70 €$/min, 0.75 + 0.5 × result, full lobbies (4, 2, 6),
   minimum durations, caps 12,000 / 6,000, repeats 3 to 5 per hour.
6. **Pure PvP and cyberware**: with the rules of `docs/pve-progression.md`, PvP gives
   no reputation; a 100% PvP player earns enough to buy everything but stays
   at rank II. Accept it (cyberware is the PvE reward), or give them a reputation
   safety net (`pvpGrants`).
7. **Harsh cases, accepted**: a 1v1 lost 0-2 and an FFA round with no kill or assist
   pay nothing (impossible to tell apart from an AFK with the current
   stats); a winner by forfeit keeps only the participation share.

## 13. Risks

- **Sharp cut in missions** (÷5 to ÷10): existing balances are neither wiped nor
  migrated; the first accounts keep their head start.
- **Hourly income estimates**: speed, handling, share of the hour in matches and
  win rate are assumed; recalibrate with `lightrp_transactions` after a few
  days (sum of each `kind` per hour of play, especially `activity_pvp`).
- **Real players**: counted by account, activity and bucket; a provider that mixes
  several matches in the same bucket would count too broadly (the pay stays capped
  at the full lobby). Several accounts of the same person are only limited by the
  crew rule, the repeat limit and the daily cap.
- **Repeat limit and samples** are in memory: a restart resets them (the
  daily cap, however, is in the database).
- **Provider stats**: AFK detection reads the current keys
  (`kills`, `assists`, `roundsWon`, `points`, `captures`, `checkpoints`, `finished`,
  `shakes`…). A provider that renames them makes its players fall into "no_progress":
  review with `activity_pay_test.lua` at every contract change.
- **Mission cooldown and caps** are in the database (`lightrp_mission_payout_cooldowns`,
  `lightrp_mission_payout_daily`); without a database they only last for
  the session.
- **Merge**: `activities.lua` is touched by only one line (the pay hook),
  `missions.lua` by the pay lines and the launch announcement, `medical.lua` by the
  `onPatientStabilized` hook.

## 14. Cyberware: capacity, builds and expected kit in PvE (`lightrp/cyberware-v2` branch)

Decision of 2026-11-03: **prices do not move**, the V+ set stays at 390,000 €$
(Neofiber Mk.3 85,000, Aegis 90,000, Rara Avis 95,000, Apogee 120,000; the proposal
in §9 is not applied). What limits power is no longer money alone but the body's
**capacity**: each implant costs points, and the reputation tier
(PvE only) sets the total. Everything is in `server/config/cyberware.lua`
(`capacity.byTier`, each implant's `capacity`, `fittingFee`, `iconics`).

### 14.1 Capacity per tier

| Tier (reputation) | Ranks opened | Capacity | What it holds |
| --- | --- | --- | --- |
| I Street (0) | I – II | **10** | all of rank II (2 + 2 + 1 + 2 + 3 = 10) |
| II Merc (500) | III | **14** | rank II, or a II / III mix (II + III = 26 points) |
| III Operator (1,500) | IV | **18** | a rank IV core: 3 to 4 implants |
| IV Edgerunner (4,000) | V | **22** | 4 to 5 high-rank implants |
| V Legend (10,000) | V+ | **26** | one build: the four V+ alone make **28**, the best of each family **67** |

Rules: capacity is checked by the server on every install (message "Not enough
capacity: X takes N points, F of your T are free"), and the page shows it (used / total,
points of each implant). A character already over the limit keeps everything, can only install a
lighter swap, and a log line flags it once. Without the missions module
(reputation unreadable), capacity is 26.

### 14.2 Points per implant (32 in the shop + 2 iconics)

| Rank | Implants (points) |
| --- | --- |
| II | Kiroshi Optics 1 · Iron Lungs 2 · Subdermal Armor 2 · Titanium Bones 2 · Reinforced Tendons 3 |
| III | Adrenaline Booster 2 · Fortified Ankles 2 · Biomonitor 3 · Pain Editor 3 · Neofiber 3 · Gorilla Arms 3 |
| IV | Kiroshi Clairvoyant 3 · Subdermal Mk.2 4 · Impact Frame 4 · Tendons Mk.2 4 · Epimorphic 4 · Neofiber Mk.2 4 · Sandevistan Mk.1 5 · Berserk Mk.1 5 · Mantis Blades 5 · Gorilla Mk.2 5 |
| V | Iron Lungs Mk.2 3 · Adrenaline Mk.2 3 · Bioplastic 5 · Second Heart 6 · Electric Mantis 6 · Sandevistan Mk.3 7 · Berserk Mk.3 7 |
| V+ | Neofiber Mk.3 6 · Aegis 7 · Rara Avis 7 · Apogee 8 |
| Iconic | Feral Biomonitor 6 (world bosses) · Chimera Plating 7 (Chimera on Critical) |

Prices of the six new ones: Kiroshi Optics 7,000, Pain Editor 12,000, Kiroshi Clairvoyant
22,000, Berserk Mk.1 26,000, Second Heart 55,000, Berserk Mk.3 64,000. Iconics cannot be
bought. Berserk and Sandevistan share the "os" family (only one installed).

### 14.3 Typical builds

| Tier | Build | Implants (points) | Total | Price |
| --- | --- | --- | --- | --- |
| Merc (14) | All-rounder | Neofiber 3, Tendons 3, Biomonitor 3, Subdermal 2, Titanium 2, Kiroshi 1 | 14 | 52,500 |
| Operator (18) | Duelist | Sandevistan Mk.1 5, Neofiber Mk.2 4, Subdermal Mk.2 4, Epimorphic 4, Kiroshi 1 | 18 | 103,000 |
| Operator (18) | Tenacious | Berserk Mk.1 5, Subdermal Mk.2 4, Epimorphic 4, Biomonitor 3, Ankles 2 | 18 | 86,000 |
| Legend (26) | **Tank** | Aegis 7, Rara Avis 7, Berserk Mk.3 7, Bioplastic 5 | 26 | 291,000 |
| Legend (26) | **Mobility** | Apogee 8, Neofiber Mk.3 6, Electric Mantis 6, Tendons Mk.2 4, Ankles 2 | 26 | 302,000 |
| Legend (26) | **Support** | Second Heart 6, Bioplastic 5, Subdermal Mk.2 4, Epimorphic 4, Clairvoyant 3, Pain Editor 3 | 25 | 171,000 |
| Legend (26) | **Brawler** | Berserk Mk.3 7, Gorilla Mk.2 5, Impact Frame 4, Tendons Mk.2 4, Adrenaline Mk.2 3, Iron Lungs Mk.2 3 | 26 | 212,000 |

The Tank carries +100 armor, +100 max health, +3 health / s, and +150 armor for 10 s
(Berserk Mk.3). The Support trades raw defense for help to the crew: the
Clairvoyant's marking, the Pain Editor's repair, self-revive in the city (Second Heart). The
Apogee + Aegis + Rara Avis trio fits (22 points) but leaves only 4 points: no dash, no
regeneration.

### 14.4 Expected kit in hard PvE

A reminder of the scales: PvE activities (`activities.lua` `pve.difficulties`) Hard =
enemies × 1,5, health × 1,5, damage × 1,25, veteran AI, tier II; Critical = enemies × 2,
health × 2,25, damage × 1,6, tier III. Chimera raid (`missions.lua`
`LightRpRaid.scaling`) Hard = health × 1.8 (+ 0.6 per operative), damage × 1,1, 6 lives,
respawn 18 s, 4 waves, enrage at 10 min; Critical = health × 3 (+ 0.75 per operative),
damage × 1,5, **no respawn**, 5 waves, enrage at 8 min; rocket 35 / 55, purge
40 / 60. Armor is used up point for point before health: the "buffer" below
is added armor + added max health.

| Content | Minimum tier | Expected kit | Added buffer |
| --- | --- | --- | --- |
| Hard activities | Merc (14) | Subdermal + Titanium + Biomonitor, plus mobility (Neofiber or Tendons) | ≈ 55 (30 + 25) and 1.5 / s: one and a half Hard rockets |
| Chimera Hard | Merc (14) | the same, as a crew; the 6 lives are forgiving | ≈ 55 |
| Critical activities | Operator (18) | Subdermal Mk.2 + Epimorphic + Berserk Mk.1 or Sandevistan Mk.1 | ≈ 120 (60 + 60), + 80 for 8 s with the Berserk |
| Chimera Critical | Operator (18), realistic at Edgerunner (22) | Tank or Brawler, with a Support in the crew | 120 to 200 permanent (≈ 2 to 3.5 Critical rockets), + 150 with the Berserk Mk.3 |

Critical without respawn is the content that justifies a defensive build: an
Operator player tries it with a buffer of ≈ 120, a Legend Tank with ≈ 200 and
+ 3 health / s. Second Heart plays **no** role there: missions and activities handle
their own deaths, and it is disabled in Dogtown and in any ranked or PvP activity.

### 14.5 Iconics

Never bought, sold or traded; rolled server-side, announced to the whole city,
logged, put in storage (install 50 €$, points counted). A player who already owns
the item from a source is no longer rolled for it.

| Source | Item | Chance | Guaranteed at | Average (with the guarantee) |
| --- | --- | --- | --- | --- |
| World boss defeated, paid share (`eligible`) | Feral Biomonitor (6 pts: + 3.5 / s, + 20 max health) | 8% | 12th miss in a row | ≈ 7.9 wins |
| Chimera raid won on Critical (not a test) | Chimera Plating (7 pts: + 110 armor, + 1 / s) | 12% | 8th miss in a row | ≈ 5.3 wins |

They are slightly better than their shop equivalent at the same point cost
(Chimera Plating vs Aegis: + 10 armor and + 1 / s; Feral vs Bioplastic:
+ 0.5 / s and + 20 health for 1 more point), not a jump in power: showing it off
matters more than the numbers.

### 14.6 What capacity changes in the pace

- **Early game unchanged**: up to Operator, money is the limit. At tier
  II (≈ 3.8 h for the regular, §7.1), they have earned ≈ 15,000 €$; ranks II and III
  cost 105,000. Capacity does not bite yet.
- **Late game bounded**: at Legend (≈ 48 h, ≈ 197,000 €$ earned), a full build
  costs 170,000 to 300,000 €$, i.e. ≈ 41 to 73 h of saving alone at ≈ 4,100 €$/h, instead
  of aiming for the whole V+ set (390,000, ≈ 95 h) and then the full loadout (617,000 at current
  prices). So the first full Legend build arrives **earlier** than the old
  "V+ set" goal.
- **The late money sink becomes the collection**: every implant bought stays in
  storage; switching builds costs 50 €$ per install. Owning Tank and Mobility ≈ 590,000;
  the whole V+ set still costs 390,000 but can never be worn all at once.
- **Reputation matters more**: +4 points per tier, so PvE is what unlocks
  power (the 100% PvP player stays at 10 points, §12 point 6).
- **Ranked PvP**: capacity narrows the gap between a rich Legend and an Edgerunner
  (26 vs 22 points instead of "everything" vs "rank V"); matchmaking by cyberware
  rank (`activities.lua` `lobby.matchmaking`) stays relevant.

To check in game: the page shows used / total and the points per implant; an install
over the limit is refused with the server's message; removing an implant (50 €$) puts it in
storage, and installing it again costs 50 €$; a rolled iconic appears in storage with the
announcement to the city.

## 15. Prod audit 2026-11-04 (`lightrp/economy-prod-audit` branch)

Sources: a read-only copy of `/opt/op77-lightrp` on the prod host (sha256 of every
`.lua`, `.json`, `.jsonc` and `.md` file under `resources/`, excluding `data/`, plus `server.jsonc`),
compared with `origin/main` 0f01709; the Light RP MariaDB database, read-only, **aggregates
only** (no account identifier, no address). Hourly model: the one from §7
(crew 1.5 × the minimum, success 85 / 70 / 55%, a success takes 70% of the clock
plus 6 min of approach, 8% costs), J = 3,500 €$/h.

### 15.1 Prod / main drift

| Set | State in prod | Detail |
| --- | --- | --- |
| `op77_lightrp` | **identical to main**, except 7 files | 686 files with the same sha256 |
| 7 files **one** commit behind | older (PR #55 and #56) | `server/config/activities.lua`, `server/config/halloffame.lua`, `tests/activities_hub_test.lua`, `tests/halloffame_test.lua` (prod = 2157054 / f67c4ed, main = 2cd3084, crossing placements); `server/config/events_board.lua`, `server/modules/events_board.lua`, `tests/events_board_test.lua` (prod = eb85a3c, main = f3feb3d, board hiding) |
| `op77_playermarks` (PR #57) | **missing** | 5 files, and missing from the prod `resources.load` list |
| `op77_race`, `op77_chase`, `op77_turf`, `op77_arena`, `op77_fireworks` | identical | — |
| `server.jsonc`, `acl.jsonc` (root) | **changed in prod only** | see below: deploying main's root files would overwrite them |
| 292 prod-only files | outside the light-rp repo | server distribution: `gamemodes/freeroam`, `open77_chimera`, `open77_cyberware_lab`, `open77_freeroam`, `open77_equipment`, `open77_gizmos_*`, `open77_wardrobe`, `polyzone`, `assets/mods/winter_in_nc`, `system/open77_*` |

**All our economy changes are in prod** (2056471, 1cbf63a, 18f1ab8, 42d982a,
7e7b80a, d90597b, 8c9739c): the files are identical, and the ledger confirms it (shares
of 1,949 = 2,400 for two, one cooldown payout at 25% on 2026-11-03, PvE at 40 €$/min). What
prod is missing is not economy: PRs #55, #56 and #57.

Prod `server.jsonc` (**never** to be overwritten by the repo's): server name and tags,
public visibility, `query` block, public endpoint, 32 slots, `combat` block, NPC and AI
vehicle limits, replication, voice 32 / 8, `winter_in_nc` and `open77_pedestrians` in
`resources.load` (and not `op77_playermarks`), rcon disabled, metrics, public Warden
URL, HTTP limits. Prod `acl.jsonc`: its own team, and **not**
`command.lightrp.tables` (so table management is not open to staff in prod).

### 15.2 What the database says (aggregates of 2026-11-04)

- 11 accounts, 11 characters, all active; 6 seen in the last 24 h, 10 in the last 7 days;
  49.4 h of cumulative play (average 4.5 h, maximum 14.5 h).
- Money supply: 304,348 €$ in the bank + 3,070 in cash = **307,418 €$**. Per
  character (bank + cash): minimum 814, **median ≈ 19,540**, average 27,668,
  maximum 143,078.
- Ledger `lightrp_transactions`: 143 lines from 2026-10-05 to 2026-11-04.

| Line | Rows | Sum | Note |
| --- | --- | --- | --- |
| `mission` | 22 | 237,116 | 180,000 = 10 standard Chimeras at 18,000 (old scale, 10-28 → 11-02); 48,000 = 6 × 8,000 on "BOUM BOUM" (contract deleted since), on 11-02; 4,000 The House; after balancing: 2 × 1,949 and 2 × 609 on WORLD BOSS A FINIR 4, **a single enemy** |
| `staff` | — | 116,200 | 112,000 in the bank + 4,200 in cash |
| account opening | — | 19,250 | 16,500 + 2,750 |
| `salary` | 49 | 3,165 | |
| `activity_pve` | 6 | 308 | |
| `shop_sell` | — | 514 | |
| `vehicle_purchase` | — | −63,000 | Colby, Hozuki, Merrimac |
| `shop_buy`, `hospital`, `rental`, `fuel` | — | −2,156, −600, −580, −183 | |

- **77% of mission money dates from the old scale**: balancing is not
  retroactive (§13). **Staff grants (116,200) make up 38% of the money supply**, more than all
  the missions paid since balancing.
- Ledger sources − spending = 310,034 €$ for 307,418 in circulation: 2,616 €$
  (0.9%) left **outside the ledger** (inference: casino cash, which does not go through it,
  §15.4 point 7; not verified).
- No `worldboss` line; `lightrp_roulette_claims` is empty: no world boss or table
  winnings have been paid in prod yet. Tables placed: a blackjack, a checkers board, a chess board,
  a Connect 4. Mission reputation: 7 characters, maximum 938, average 357. Housing:
  the 7 free starting studios.

### 15.3 Editor contracts in prod

19 definitions in the database (`lightrp_mission_defs`), added in game by Nightwolf's team:
15 on the board, 1 gig, 3 world bosses. Everywhere: clock 15 / 15 / 20 min, minimum
crew 1 / 1 / 2, enemy multipliers 1 / 1.5 / 2. "Enemies" = the ones you have to
beat at that difficulty (start, mandatory waypoints, every wave). Per head, at the
minimum crew, Standard / Hard / Critical:

| Contract | Enemies | Saved | Paid so far | Paid with this branch | After `/lightrp.missions.repay` |
| --- | --- | --- | --- | --- | --- |
| The House | 30 / 48 / 60 | 2,000 / 4,000 / 6,000 | 2,000 / 3,750 / 5,000 | 2,000 / 3,300 / 5,000 | 2,000 / 3,000 / 4,400 |
| WAREHOUSE | 18 / 29 / 36 | 8,000 / 15,000 / 30,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| SHADY CORNER (survival) | 30 / 45 / 60 | 8,000 / 15,000 / 30,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| VALENTINOS DEAL | 12 / 18 / 24 | 5,000 / 10,000 / 15,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| FAVELA (survival) | 45 / 69 / 90 | 8,000 / 15,000 / 30,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| RUN MOTHERFUCKER RUN | 15 / 25 / 30 | 8,000 / 15,000 / 30,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| SNIPA | 28 / 42 / 56 | 8,000 / 15,000 / 30,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,400 / 3,000 / 4,400 |
| THE PIER OF DEATH (survival) | 54 / 81 / 108 | 10,000 / 30,000 / 60,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,600 / 3,300 / 5,000 |
| CORPO COLLABS | 17 / 29 / 34 | 10,000 / 25,000 / 50,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,600 / 3,300 / 5,000 |
| VAMOS (survival) | 72 / 108 / 144 | 15,000 / 30,000 / 80,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,600 / 3,300 / 5,000 |
| TERMINAL B | 20 / 30 / 40 | 12,000 / 25,000 / 80,000 | 3,750 / 3,750 / 5,000 | 2,600 / 3,300 / 5,000 | 2,600 / 3,300 / 5,000 |
| GIG 1 (gig) | 3 / 5 / 6 | 1,000 / 1,500 / 2,000 | 1,000 / 1,500 / 2,000 | **250 / 417 / 500** | unchanged |
| 6 7 TH STREET A FINIR | 3 / 5 / 6 | 2,400 / 3,000 / 4,400 | 2,400 / 3,000 / 4,400 | **600 / 833 / 1,100** | unchanged |
| WORLD BOSS A FINIR 1, 3, 5 (on the board) | 3 / 5 / 6 | 2,400 / 3,000 / 4,400 | 2,400 / 3,000 / 4,400 | **600 / 833 / 1,100** | unchanged |
| WORLD BOSS TEST, A FINIR 4, A FINIR 2 | world bosses, pools 10,000 / 10,000 / 30,000 | | | §15.5 | WORLD BOSS TEST rewritten, no effect (no board) |

Reputation per run, Standard / Hard / Critical: 100 / 220 / 450 everywhere so far;
with this branch, unchanged for full contracts, **25 / 61 / 113** for
3-enemy contracts (GIG 1 included).

### 15.4 Broken scales (before this branch)

1. **The safety cap was the only cap**: every contract saved at the old scale
   paid 250 × its minutes, i.e. 3,750 / 3,750 / 5,000 = **2.59 / 2.05 / 1.69 × J** within
   the 6 full payouts (target in §2: 1.7 to 1.8 × J; editor defaults 1.66 / 1.64 / 1.49).
   Daily cap of an account on Standard: 6 × 3,750 = 22,500 instead of 14,400.
2. **It could be bypassed**: the safety cap follows the clock, which the editor accepts up to 120 min;
   a contract at 30,000 and 120 min paid 30,000 per head.
3. **The board lied**: it showed the saved figure (up to 80,000), not the pay.
4. **Small contracts paid in full**: a 3-enemy contract done in ≈ 9 min
   (3 of combat, 6 of approach) brought in 2,400, ≈ **16,000 €$/h (4.6 × J)** within the 6 full
   payouts, and its full reputation **with no cap**: 100 / 220 / 450 per run, ≈ 670 /
   1,470 / 3,000 per hour against the 180 / 280 / 375 targeted (§7); Legend (10,000) in 3 to 7 h of
   farming instead of ≈ 48 h. Five contracts of this kind are on the board ("A
   FINIR" placeholders and GIG 1); on 11-03, two players got 1,949 each for **one** enemy.
5. **World bosses**: the editor's pool (default 30,000) is split among those who
   hit the boss, with no cap per head or per day. It takes 3 players online; with 3
   fighters, **10,000 each** per boss, 30,000 solo. One boss every ≈ 80 min (20
   min of waiting at startup, then 45 to 90 min after the previous one ends): up to
   7,500 €$/h (2.1 × J) on top, outside the cooldown and outside the missions' daily cap.
6. **Roulette with no limit**: 1 to 1,000,000 per bet, as many bets as you like per round;
   100,000 on a single number returns 3,600,000 (≈ 1,000 h of J). The fortune wheel
   (1,000 per bet, 5,000 per round) and the slot machines (1,000 per pull) are capped.
7. **The casino is not in the ledger**: stakes and winnings go through inventory
   cash and `lightrp_roulette_claims`, never through `lightrp_transactions`. On
   expectation it is a sink (house edge: roulette 2.7%, slot machines 5.6%
   (RTP 1,632 / 1,728), wheel 11 to 24% depending on the segment, blackjack ≈ 1%), but it is
   invisible in the accounts.
8. Unchanged and healthy: Dogtown (owner decisions: stake 1,000, loss 10%, server bonus
   25%, bounty 250 per kill up to 1,500, bonus + bounties ≤ 3,000 per day and per
   account), dailies (250 / 400 / 250 / 300, weekly 3,000, budget 1,200 per day),
   job crew bonus (15%, 2,000 per day), Big Contract (20 / 35%), gigs ×1,0,
   Chimera 3,000 / 4,500 / 6,000 and Sector 04 3,500 / 5,000 / 9,000.

### 15.5 What this branch changes (numbers in configuration, rules in the code)

| File | Key | Before | After |
| --- | --- | --- | --- |
| `server/config/economy.lua` | `missions.authored.maxShare` | — (only 250 × minutes) | **2,600 / 3,300 / 5,000** per head, whatever the clock: 1.80 / 1.81 / 1.69 × J (*replaced in §16.1: 2,400 / 3,000 / 4,400*) |
| | `missions.authored.fullPayEnemies` | — | **12 / 18 / 24**: pay and reputation × enemies ÷ this threshold (at most 1) |
| `server/modules/mission_pay.lua` | `cap`, `contentScale` | safety cap only | safety cap, then band, then size; a gig is not reduced twice |
| `server/modules/missions.lua` | board, reputation | saved `payout`, 100 / 220 / 450 | **the real pay**; reputation × the same size (editor missions and gigs) |
| `shared/mission_defs.lua` | `M.enemies`, `point.difficulties[i].enemies` | — | enemies to beat per difficulty, as the engine queues them |
| `server/config/economy.lua` | `worldBosses` | pool = editor reward | **3,000 × paid fighters ^ 0.7**, at most the reward; a share ≤ **250 × minutes** of the event |
| `server/config/world_bosses.lua` | `announce.body` | "a share of {reward}" | "a share of **up to** {reward}": the maximum pool with every player online |
| `shared/tabletop_extra_rules.lua` | `R.MAX_BET`, `R.MAX_ROUND` | 1,000,000 per bet, no limit per round | **1,000** per bet, **5,000** per character and per round (like the wheel) (*divided by 10 in §16.4*) |
| `server/modules/mission_repay.lua` | rule of `/lightrp.missions.repay` | cap = safety cap | cap = min(safety cap, band); above the safety cap: old scale, never below the new default; between the band and the safety cap: the band |

Why these numbers:

- **Band**: the top of the owner's target (1.8 × J, §2) at the editor's default
  clock; 2,600 on Standard = 1.80 × J, 3,300 on Hard = 1.81 × J (220 €$/min, the figure
  from §7.4); on Critical, 1.8 × J would exceed the safety cap for 20 min, so the band equals the
  safety cap (5,000, 1.69 × J). Chimera and Sector 04 have no `enemies`: not affected.
- **Size**: 12 / 18 / 24 is 12 enemies multiplied by the default multipliers
  (1 / 1.5 / 2), i.e. one spawn point at the editor's maximum or six groups of two.
  The smallest full contract in prod (VALENTINOS DEAL: 12 / 18 / 24) gets the
  full pay; the 1- to 3-enemy placeholders get 8 to 25%. Per enemy, a small
  contract now earns what a big one earns, and the approach makes it less profitable
  per hour: the 3-enemy contract from point 4 drops to ≈ 4,000 €$/h (1.1 × J) and to
  170 / 410 / 750 reputation per hour.
- **World bosses**: same shape as the mission pot (exponent 0.7). Per head, with the
  editor's 30,000 reward:

  | Paid fighters | 1 | 2 | 3 | 5 | 10 | 20 | 30 |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Before, per head | 30,000 | 15,000 | 10,000 | 6,000 | 3,000 | 1,500 | 1,000 |
  | Pool after | 3,000 | 4,874 | 6,473 | 9,256 | 15,036 | 24,425 | 30,000 |
  | After, per head (average) | 3,000 | 2,437 | 2,157 | 1,851 | 1,503 | 1,221 | 1,000 |

  A share never exceeds 250 × the boss's minutes (5,000 for 20 min); anything
  above that is not paid. With 3 fighters and ≈ 0.75 bosses per hour, ≈ 1,600 €$/h
  (0.46 × J) instead of 7,500. The announcement, the zone notice and the HUD (`reward`, and
  `rewardMax` for the editor's reward) give the real pool.
- **Roulette**: maximum return per round 36,000 (1,000 on a single number, stake included),
  on par with the wheel (41,000); refused before any debit. The client's table bar caps the chip and the
  button at these limits.

### 15.6 To deploy in prod (Nightwolf)

*Completed by §16.8 (decisions of 2026-11-04), which also changes the figures to check
below: band 2,400 / 3,000 / 4,400, roulette 100 / 500.*

Copy into `/opt/op77-lightrp/resources/gamemodes/op77_lightrp/`:

- from this branch: `server/config/economy.lua`, `server/config/world_bosses.lua`,
  `server/modules/mission_pay.lua`, `server/modules/mission_repay.lua`,
  `server/modules/missions.lua`, `server/modules/world_bosses.lua`,
  `server/modules/tabletop_extra.lua`, `shared/mission_defs.lua`,
  `shared/tabletop_extra_rules.lua`, `client/core/table_bar.lua` (the tests and docs are not
  needed at runtime);
- from main, if wanted: the 7 lagging files from §15.1 and
  `resources/standalone/op77_playermarks` (then add it to `resources.load`).

**Do not copy** the repo's `server.jsonc` or `acl.jsonc`. Restart Light RP, then in game
(staff) `/lightrp.missions.repay` (preview: 12 contracts) and `/lightrp.missions.repay apply`.
The pay is correct from the restart; the command only brings the editor into line.

To check in game: the WAREHOUSE board shows 2,600 / 3,300 / 5,000 before the command
and 2,400 / 3,000 / 4,400 after it; 6 7 TH STREET on Standard shows and pays 600, +25
reputation; a world boss with 3 players announces "up to" the pool for the players online
and pays ≈ 2,160 each; a roulette stake of 1,001 is refused, and so is a sixth stake of 1,000
in the same round.

### 15.7 Questions for the owner

*Answers of 2026-11-04 in §16: 1 → the editor defaults (§16.1); 2 → yes, 25%
for 60 min per point (§16.2); 3 → 3 paid bosses per day, reputation included
(§16.3); 4 → stakes ÷ 10 (§16.4); 5 → one net `casino` line per round (§16.5);
6 → reason required, 10,000 per grant (§16.6). 7 and 8 remain open.*

1. **Contract band**: 2,600 / 3,300 / 5,000 (the top of the target) — or the editor
   defaults (2,400 / 3,000 / 4,400), which are more cautious?
2. **Mission reputation**: it stays "uncapped" (`docs/pve-progression.md`);
   size only fixes small contracts. Add a per-point cooldown as for
   money (60 min)?
3. **World bosses**: a daily cap (none today)? And the fixed reputation of
   150 per boss?
4. **Slot machines**: up to 1,000 per pull, triple seven ×200 = **200,000** (≈ 57 h of
   J) once in 1,728. At the maximum stake, up to ≈ 900 pulls per hour (3 s per
   pull): ≈ 40% chance of hitting the jackpot within the hour, for an average loss
   of 50,000. At roulette (5,000 per round) or blackjack (5,000 per hand), an hour at the
   maximum stake swings a balance by about ±50,000 (≈ 14 h of J). Proposal: divide the maximum stakes by 10 (100 per bet or pull, 500
   per round, blackjack 500), if the casino should stay RP rather than a way to win a
   car in an hour. Not changed here.
5. **Casino in the ledger**: write stakes and winnings to `lightrp_transactions`
   (`casino_stake`, `casino_win`) to track this sink?
6. **Staff grants**: 116,200 €$, 38% of the money supply. Cap them, or track them by
   reason?
7. **Prod files**: version a `server.prod.jsonc` and an `acl.prod.jsonc` without
   secrets so that no deploy overwrites them; open `command.lightrp.tables` to prod
   staff?
8. **Dogtown and dailies**: owner decisions, not touched here (§15.4 point 8).

Risks and limits: size counts heads, not their health (a 3-enemy contract with
health ×5 is still paid 25%); a contract whose enemies are all behind optional
waypoints counts 0 and pays nothing; nothing has been tested in game (Lua unit
tests only).

## 16. Owner decisions 2026-11-04 (`lightrp/economy-decisions` branch)

Answers to the questions in §15.7 (1 to 6). Every number is in configuration; the rules
are in the code. Nothing has been tested in game (Lua and Python tests only, §16.9).

### 16.1 Editor contract band = editor defaults

| Key (`server/config/economy.lua`) | Before (§15.5) | After |
| --- | --- | --- |
| `missions.authored.maxShare` | 2,600 / 3,300 / 5,000 | **2,400 / 3,000 / 4,400** (= `shared/mission_defs.lua`), 1.66 / 1.64 / 1.49 × J |
| `missions.authored.fullPayEnemies` | 12 / 18 / 24 | unchanged |

The board, the pay and `/lightrp.missions.repay` follow the band with no other change
(`mission_repay.lua` caps at min(safety cap, band)). For the eleven full contracts,
§15.3 becomes: **2,400 / 3,000 / 4,400 paid from the restart, and after the
command** (THE PIER OF DEATH, CORPO COLLABS, VAMOS and TERMINAL B included, which stayed at
2,600 / 3,300 / 5,000); The House 2,000 / 3,000 / 4,400; small contracts do not
change (600 / 833 / 1,100, GIG 1,250 / 417 / 500: they are below the band). Daily
cap of an account on Standard: 6 × 2,400 = **14,400** (the target from §15.4 point 1).

### 16.2 Mission reputation: same repeat rule as money

| Key (`missions`) | Value | Effect |
| --- | --- | --- |
| `reputationCooldownMinutes` | **60** | window per character and per mission point |
| `reputationRepeatShare` | **0.25** | share of reputation during the window (1 or 0 min: rule off) |

After a completion that gave **full** reputation, the same point (board, gig,
Sector 04, Chimera raid) gives that character only 25% of its reputation for 60 min:
100 / 220 / 450 → **25 / 55 / 113** (small contracts 25 / 61 / 113 → 6 / 15 / 28). A
reduced reputation grant does not extend the window; it has its own window (table
`lightrp_mission_rep_cooldowns`, created at startup), started by each full reputation grant,
even beyond the daily money cap, which does not affect reputation. The
player sees it in two places: the announcement at launch ("Reputation: 25% of it, this job
gave you its full reputation less than 60 min ago (full again in 42 min).") and the end
notice ("+55 reputation (25% of 220: this job gave you its full reputation less than
60 min ago, full reputation again in 42 min)."). On a single point, an hour of farming on
Standard (≈ 3 runs) brings 100 + 25 + 25 = 150 instead of 300; switching points
keeps full reputation, as with money. Files: `server/modules/mission_pay.lua`
(`Pay.reputation`, `reputationQuote`, `reputationStatus`), `server/modules/missions.lua`.

### 16.3 World bosses: 3 payouts per character and per UTC day

`server/config/world_bosses.lua` → **`dailyPaid = 3`** (0 turns the cap off). A character
paid for 3 world bosses since 00:00 UTC (the same day as the rest of the economy,
`floor(unix / 86400)`) no longer gets a share or the 150 fixed reputation until the
next day. The fight stays open to them: they score points, help others, see the HUD;
they no longer count among the paid fighters (the pool follows the others). Their share
still counts for anything that is not pay (daily contracts, titles,
iconic rolls: `results.eligible`); only money and reputation stop.
They are warned when entering the zone and at the end ("Daily world boss pay reached: you
were paid for 3 world bosses today. Fight on if you like; no pay or reputation from world
bosses until 00:00 UTC."), and the end recap shows the reason `daily_cap`. A
failed boss or a share below the minimum does not count; neither does a payment refused by the bank
(the player is warned). Counted in `lightrp_worldboss_daily` (created at
startup), read back after a restart. Daily maximum with 3 fighters: ≈ 3 × 2,157 =
6,500 €$ and 450 reputation; solo, 3 × 3,000. Known limit: the web HUD has no text
for this case; for a character at the cap, it shows the generic "no reward" line
(the notice gives the reason). The `web/` bundle on main cannot be reproduced from
`ui/` (a rebuild changes `app.js` and `app.css`), so it
was not rebuilt here.

### 16.4 Casino: maximum stakes divided by 10

| Game (file in `shared/`) | Before | After |
| --- | --- | --- |
| Slot machines (`casino_slots.lua`, `S.MAX_BET`) | 1 – 1,000 per pull | **1 – 100** |
| Roulette (`tabletop_extra_rules.lua`, `R.MAX_BET` / `R.MAX_ROUND`) | 1 – 1,000 per bet, 5,000 per character and per round | **1 – 100**, **500** |
| Fortune wheel (`casino_fortune.lua`, `F.MAX_BET` / `F.MAX_ROUND`) | 1 – 1,000 per bet, 5,000 per round | **1 – 100**, **500** |
| Blackjack (`casino_blackjack.lua`, `B.MAX_BET`) | 5 – 5,000 per hand | **5 – 500** (a double takes the hand to 1,000) |

There is no other money table (pool, chess, checkers, Connect 4: no stakes). The
server refuses anything above the limit before any debit; the client's table bar reads these constants
(chips 1, 5, 10, 25, 50, 100; blackjack 5 to 500): nothing to rebuild on the web side.
Only the baked textures keep the old figures: the blackjack felt reads
"TABLE LIMITS 5 – 5,000" and the slot machine glass "BET 1 - 1000". The baking
scripts read them from these constants (`tools/build-casino-blackjack-props.py`,
`tools/build-casino-slots-props.py`): a re-bake and a new client archive will
update them (outside this branch, which touches no asset).

**Slot machine jackpot**: it is not fixed. Every combination pays a multiple of
the stake (`S.THREE.seven = 200`, stake included): triple seven returns 200 × the stake,
so **20,000** at 100 (it was worth 200,000 at 1,000). Nothing else to scale.
At the maximum stake, an hour of slots (≈ 900 pulls) costs ≈ 5,000 on
expectation and hits the jackpot with a ≈ 40% chance; at roulette or blackjack,
an hour at the maximum stake swings a balance by about ±5,000 (≈ 1.4 h of J) instead
of ±50,000.

### 16.5 Casino in the ledger: one net line per character and per round

Each settled round (roulette round, slot pull, wheel spin, blackjack result)
writes **one** `lightrp_transactions` line per character who staked in it: `kind = "casino"`,
wallet `cash`, amount = gross returns − stakes of the round (doubles included),
counterparty "Roulette table" ("Slots table", "Fortune Wheel table", "Blackjack
table"), note "Roulette: staked €$ 30, returned €$ 360". It is written in the same
SQL transaction as the round's claims (`lightrp_roulette_claims`): a round that
fails writes nothing. The chips themselves no longer write a line: the stake, the claim
payment and the refund go through a `silent` tag on the inventory
draft (`Money.inventoryReceipt`); so a refunded round (table packed away or
reset) leaves no line. `balance_after` = the pocket once the winnings have arrived;
0 if the character is offline at settlement (the pocket is in the inventory, out of
SQL's reach). The in-game history (`/bank`, `money` state) gets the line as soon as the round
settles. No schema change. Code: `server/modules/economy.lua`
(`Money.casinoLine`, `silent` tag), `server/modules/inventory.lua`,
`server/modules/tabletop_extra.lua` (`X.ledgerLines`, `X.commitRound`, `X.stake`,
`X.claim`), `casino_slots.lua`, `casino_fortune.lua`, `casino_blackjack.lua`,
`board_games.lua` (the timed settlement refreshes the history).

**The 2,616 €$ outside the ledger (§15.2).** The casino was not missing from the ledger: every
change to a player's pocket already wrote a line, but an anonymous one — `kind =
"inventory"`, note "Physical cash moved" —, one per chip staked and one per claim
payment. The table in §15.2 only sums the named lines (`mission`, `staff`,
`salary`…), so it leaves out the `inventory` lines. And the only casino table placed in
prod was a blackjack, and `lightrp_roulette_claims` is empty: no hand was ever
paid, and every lost stake left the pocket through a negative `inventory` line.
Other cash movements out of the pocket (a deposit in a stash or a vehicle
trunk, cash dropped on the ground) take the same path: the money still exists, but
no longer in the counted supply. **Inference**: the 2,616 €$ are the sum of the
`inventory` lines (lost blackjack stakes, plus the cash stored or dropped); to be checked with
`SELECT SUM(amount) FROM lightrp_transactions WHERE kind = 'inventory'` (not run:
no database access for this branch). Since this branch, the casino has its own
`casino` lines and the `inventory` lines only describe that storing and dropping.

Transition: a claim written before the deployment and paid after it goes through with no line (its
stake had its `inventory` line); a stake placed before the restart on a round
settled after it counts twice (an `inventory` line and a `casino` line). This happens only once, and
is on the order of one stake.

### 16.6 Staff grants: reason required, 10,000 per grant

`server/config/economy.lua` → `staffGrants`:

| Key | Value | Effect |
| --- | --- | --- |
| `maxGrant` | **10,000** | cap on one grant (0: no cap) |
| `minReason` | **4** | minimum characters in the reason |
| `unlimitedPermission` | **`lightrp.money.unlimited`** | ACL permission that lifts the cap |

`/lightrp.givemoney <id|me> <cash|bank> <amount> <reason>` refuses a grant with no reason (it
replies with the usage) and, above 10,000, a giver who does not have `lightrp.money.unlimited`.
The server console is not capped. The reason becomes the note of the `staff` line
in the ledger. The staff desk's *Credit* (`admin.lua`) follows the same rule; its audit
reason (4 to 500 characters) is cut to 160 bytes, without splitting a UTF-8 character,
for the note — before, a reason longer than 160 characters made the line insert
fail (MariaDB in strict mode) even though the money had already been paid. The debit
(`takemoney`) is not capped.

**Why not `command.lightrp.money.unlimited`**: `PermissionMatches` (base) grants
a permission through `*`, by exact match or by an `xxx.*` prefix, with no deny. The
repo's moderator and operator roles hold `command.lightrp.*`: they would get the cap lift
automatically. `lightrp.money.unlimited` is outside the `command.` namespace: only `*`
(the owner) or an explicit line grants it. **Nightwolf must add it to the prod
`acl.jsonc`**, on the intended role, then run `acl.reload`; the `acl.jsonc` and
`server.jsonc` files are not changed here.

### 16.7 What remains open

§15.7 points 7 (versioned prod files, `command.lightrp.tables`) and 8 (Dogtown,
dailies): not addressed. The world boss HUD for a character at the cap (§16.3)
awaits a rebuild of the web bundle; the limits printed on the blackjack felt
and the slot machine glass (§16.4) await a re-bake of the props.

### 16.8 To deploy in prod (Nightwolf)

Copy from this branch into `/opt/op77-lightrp/resources/gamemodes/op77_lightrp/`:

- `server/config/economy.lua`, `server/config/world_bosses.lua`;
- `server/modules/admin.lua`, `server/modules/board_games.lua`,
  `server/modules/casino_blackjack.lua`, `server/modules/casino_fortune.lua`,
  `server/modules/casino_slots.lua`, `server/modules/economy.lua`,
  `server/modules/inventory.lua`, `server/modules/mission_pay.lua`,
  `server/modules/missions.lua`, `server/modules/recap.lua`,
  `server/modules/tabletop_extra.lua`, `server/modules/world_bosses.lua`;
- `shared/casino_blackjack.lua`, `shared/casino_fortune.lua`, `shared/casino_slots.lua`,
  `shared/tabletop_extra_rules.lua`.

If §15.6 has not been deployed yet, also copy its files (identical to main):
`server/modules/mission_repay.lua`, `shared/mission_defs.lua`, `client/core/table_bar.lua`.
Do not copy `server.jsonc` or `acl.jsonc`; add `lightrp.money.unlimited` to the prod ACL
for whoever must be able to go above 10,000. Restart Light RP (the tables
`lightrp_mission_rep_cooldowns` and `lightrp_worldboss_daily` create themselves), then run
`/lightrp.missions.repay` (preview) and `/lightrp.missions.repay apply`.

To check in game: WAREHOUSE shows and pays 2,400 / 3,000 / 4,400; doing the same
contract again within the hour gives 25% of the reputation, with the reason; a fourth paid world boss
in the same day is refused, with the notice; a stake of 101 is refused at
roulette, the wheel and the slots, and 501 at blackjack; after a roulette round, `/bank`
shows one net `casino` line and no `inventory` line; `/lightrp.givemoney me bank
500` replies with the usage, and `/lightrp.givemoney me bank 20000 cap test` is refused without the
permission.

### 16.9 Tests

Lua (`tests/run-lua.ps1`): `mission_pay_test` (band, repeated reputation), `mission_repay_test`,
`missions_test` (reduced reputation notice), `world_boss_test` (daily cap),
`roulette_limits_test` (100 / 500), `cash_test` (`casino` line, `silent` tags),
`staff_money_test` (new: reason, cap, permission, console, UTF-8 notes, desk),
`dailies_flow_street_test` (`givemoney` with a reason). Python (`tools/`): the casino
and table tests follow the new limits; `test-tabletop-extra-server.py`,
`test-casino-slots-server.py`, `test-casino-fortune-server.py` and
`test-casino-blackjack-server.py` check one net line per character and per round,
nothing for a refund, and that every chip movement is `silent`.

## 17. Demanding economy, 2026-11-05 (`feat/lightrp-economy-hard` branch)

The owner's request: "a server that isn't easy, that takes time, where buying things feels rewarding". The
reference income goes from **J = 3,500 €$/h** to **J ≈ 2,200 €$/h** at the entry grade. Moving up in grade counts for more:
the bonus per grade goes from 10% to 15%, about 3,300 €$/h at grade 3. Prices are spread out so that each purchase
is a milestone.

### State of Testing before the overhaul (database, 2026-11-05)

- 11 characters for about 82 h of cumulative play, and 265 k €$ in the bank.
- 470 k €$ were created in one month and only 108 k €$ destroyed.
- Missions: 261 k €$, almost all of it paid before the caps of 2026-11-04 (Chimera at 18,000 €$ per head, 11 times).
- Staff credits: 156 k €$, including a single credit of 100 k €$.
- Balances are **not** reset to zero: that is irreversible and needs an explicit decision from the owner.

### Loopholes closed

| Loophole | Fix |
|---|---|
| AC Cleaner: 400 €$ every 1 to 1.5 min on the test route (~20 k €$/h) | 120 €$ per run and a 3 min `cooldownMs` specific to the route (job_runs.lua) |
| Big Contract bonus outside any cap | it now counts toward `crewBonus.dailyCap`, lowered to 1,500 €$/day (job_crew.lua) |
| Free rerolls of courier runs | `cancelCooldownMs` = 2 min after the player abandons a run (not after an expiry, a fall or a job change) |
| Sector 04 shown but with no script (it always expired without paying) | `disabled = true`: no board entry and no blip until it has a script |
| Staff credits with no daily cap | `staffGrants.dailyCapPerStaff` = 25,000 €$ per staff account and per UTC day (console and `lightrp.money.unlimited` exempt) |
| Alt characters: 1,500 €$ in the bank on every creation, free transfers | `startingBankExtraCharacters = 0`, 2% transfer fee (minimum 10 €$) |

### Income

| Source | Before | After |
|---|---|---|
| Sanitation / Scrapper (per unit) | 30 / 40 | 20 / 26 |
| Courier (base, per stop, per km, bounds) | 60, 30, 120, 150–1,400 | 40, 20, 80, 100–900 |
| Bonus per grade | 10% | 15% |
| Salaries (every 30 min) | 100 to 500 | halved (50 to 250) |
| Distance traveled that counts as activity for the salary | 75 m | 600 m |
| Editor missions, max share Standard / Hard / Critical | 2,400 / 3,000 / 4,400 | 1,500 / 2,400 / 3,600 |
| Missions: cap per minute, full payouts per day, wait, repeat share | 250, 6, 60 min, 25% | 150, 4, 90 min, 15% |
| Chimera per head | 3,000 / 4,500 / 6,000 | 2,000 / 3,000 / 4,000 |
| World boss: per fighter, per minute, payouts per day | 3,000, 250, 3 | 2,000, 150, 2 |
| PvP activities: per minute, daily cap | 70, 12,000 | 45, 7,500 |
| PvE activities: per minute, daily cap | 40 / 50 / 60, 6,000 | 25 / 32 / 40, 4,000 |
| Daily contracts and daily budget | 250 / 400 / 250 / 300, 1,200 | 175 / 275 / 175 / 200, 800 (the weekly stays at 3,000) |
| Maneki-neko: per cat, tiers | 500, 5 k / 15 k / 40 k | 250, 2.5 k / 7.5 k / 20 k |

### Spending

| Item | Before | After |
|---|---|---|
| Weapons | 1,200 to 10,500 | ×1,5, rounded to 50 (1,800 to 15,750) |
| Ammo (box: 9 mm, buckshot, rifle, sniper) | 75 / 90 / 110 / 150 | 110 / 135 / 165 / 225 (buy-back 25 / 30 / 40 / 55) |
| TCG boosters WNC / Beta, display | 120 / 180, 2,600 | 400 / 600, 8,500 (buy-back 150 / 220 / 3,000) |
| Vehicles | 4,000 to 100,000 | ×2,5, rounded to 500 (MaiMai 10,000 … Semimaru 250,000) |
| Impound: destroyed / lost / requested / staff | 400 / 150 / 250 / 500 | 1,500 / 600 / 500 / 750 |
| Paint | 1,000 | 2,500 |
| Fuel | 4 €$/L | 6 €$/L (~400 €$/h behind the wheel) |
| Hospital | 300 | 750 |
| Food | unchanged: ~12 €$/h, because hunger and thirst drop 4 times more slowly (owner's choice) | |

The 24 boosters of a display bring in 3,600 €$ when resold, far less than the 8,500 €$ of the display: no buy-and-resell
loop is possible.

### Not done yet (code to write)

- **Hospital debt:** today, the bill is only taken from the money available, never below zero.
- **Vehicle insurance:** optional, 1% of the price per week.
- **Impound as a % of the vehicle price:** these are flat fees for now.
- **Maneki tiers per account:** they still count per character.
- **Hard cap on mission repeats:** the share drops to 15%, but with no limit.
- **Housing rents and purchase prices:** they are in the database, to be set with `/housingadmin` (target: small apartment at 6,000 €$/week, medium at 18,000 €$/week, purchase from 120 k to 500 k €$).

## 18. Auto Studio: provisional prices (`vc/a3-studio-full` branch)

The full studio offers ten categories; nine are on sale, and windows are closed
(see the Windows row). Wave 2 (`lr/studio-extras` branch) adds five more:
neon animation, lamp colors, engine sound, stickers and tag. They stay
grayed out as long as their natives and the garage's category registry are missing. All prices are in **a single server
table**, `LightRpCustomizationPricing` (`server/config/vehicle_customization.lua`).
The client never sends a price. Only paint is decided (owner,
2026-11-05). Everything else is **provisional**, marked `-- PROVISIONAL`, and awaits the
owner's decision.

Every purchase is pure money destruction: no income is tied to it.
Every purchase writes a line to the ledger, in the same SQL transaction as the debit and
the vehicle save. The hours below are counted at the reference income
from §17: J ≈ 2,200 €$/h at the entry grade, about 3,300 €$/h at grade 3.

| Category | Price | Unit | Hours (entry grade) | Ledger | Reasoning |
|---|---|---|---|---|---|
| Paint | 2,500 | both channels | 1.1 | `vehicle_paint` | decided on 2026-11-05 (§17) |
| Livery | 4,000 | a factory two-tone scheme, or back to solid paint | 1.8 | `vehicle_livery` | above paint: two tones, applied over the factory layer |
| Rims | 6,000 | the full set (all wheels, one finish), or back to factory rims | 2.7 | `vehicle_rims` | 20% of a Hella (30,000): the first purchase you can see from afar |
| Body kit | 3,500 | **per group changed** (wing, rear louvers, front lip, canards, side skirts, diffuser, hood, roof, front protection) | 1.6 per group | `vehicle_bodykit` | 9 groups at most (Thrax): 31,500, i.e. about 14 h; 7 groups on a Hella: 24,500 |
| Neon | 5,000 | the kit with color and intensity, or its removal | 2.3 | `vehicle_neon` | visible at night to everyone, on a par with rims |
| Headlights | 500 | a tint, or back to factory headlights | 0.2 | `vehicle_lights` | phase 1: a single parameter (the tint) |
| Trim | 2,500 | a factory variant | 1.1 | `vehicle_trim` | phase 1: at the price of paint |
| Plate | 2,500 | a new registration | 1.1 | `vehicle_plate` | unique on the server; the price discourages repeated changes |
| Windows | 1,500 | a tint, any level, or back to factory glass | 0.7 | `vehicle_tint` | configured but **not sold**: the native exists and the toggle works, but the glass still displays as factory glass; category closed ("Coming soon") |
| Performance | per model and per stage (table below) | the stages between the current one and the target | — | `vehicle_stage` | proposal E5 |
| Stage removal | 1,000 | step down, or go back to stock | 0.5 | `vehicle_stage` | nothing is refunded |
| Neon animation (wave 2) | 2,500 | a mode (pulse, strobe, chaser…), or back to steady neon | 1.1 | `vehicle_neon_anim` | half the neon price: it only exists on a neon already installed |
| Lamp colors (wave 2) | 1,500 | brake, reverse, indicators and cabin, as many groups as you like, or back to factory | 0.7 | `vehicle_lamps` | more than the headlight tint (500): four groups in one purchase |
| Engine sound (wave 2) | 6,000 | a sound, or back to the factory sound | 2.7 | `vehicle_engine_sound` | at the price of rims: the car is rebuilt, and you hear it from afar |
| Stickers (wave 2) | 1,500 | **per sticker added**; removing some costs one sticker | 0.7 per sticker | `vehicle_stickers` | 12 decals at most, livery included: 12 stickers cost 18,000 |
| Tag (wave 2) | 2,000 | a painted text (font, color, placement), or its removal | 0.9 | `vehicle_tag` | secondary objective W2.5: the contract gives no price |

**Pricing rules.**

- **Body kit.** The price is 3,500 times the number of groups that differ
  from the confirmed kit, with a minimum of 1. So changing the wing and adding a front lip costs
  7,000.
- **Stage upgrade.** You pay for every stage between the current one and the target: going
  from stock to stage 3 on a Hella costs 2,500 + 3,500 + 5,000 = 11,000.
- **Stage downgrade.** Stepping down costs 1,000, whatever the target, with no
  refund.
- **Cooldown.** A vehicle can be modified once every 10 min
  (`stages.cooldownMs`).
- **Paint–livery link.** Paint and livery are linked. Buying a paint
  removes the livery, and buying a livery restores the factory paint. You only pay
  for the category you chose.
- **Stickers.** The price is 1,500 times the number of stickers that are not
  already on the car, with a minimum of 1. So removing stickers without adding any
  costs 1,500.
- **Engine sound.** Each preview rebuilds the car: one preview every 4 s at most,
  free. Only the purchase costs money.

### 18.1 Performance stages (proposal E5)

E5 sets the price of each stage like this:

- dealership price × 10 / 15 / 20% × value weight;
- value weight = 0.5 + 0.5 × the engine share actually delivered (a model held back
  by its class ceiling pays less);
- minimum of 1,000 / 1,500 / 2,000, rounded up to the next 500.

The source is `scripts/vehicle-kit/stages/STAGES.md`, in the Open77 repository.

| Model | Dealership price | Stage 1 | Stage 2 | Stage 3 | All three | Share of the price |
|---|---|---|---|---|---|---|
| Makigai MaiMai | 10,000 | 1,000 | 1,500 | 2,000 | 4,500 | 45% |
| Brennan Apollo | 12,500 | 1,000 | 1,500 | 2,000 | 4,500 | 36% |
| Thorton Galena | 16,000 | 1,500 | 2,000 | 2,500 | 6,000 | 38% |
| Archer Hella | 30,000 | 2,500 | 3,500 | 5,000 | 11,000 | 37% |
| Thorton Colby | 35,000 | 3,000 | 4,000 | 5,500 | 12,500 | 36% |
| Mahir Supron | 40,000 | 3,500 | 5,000 | 7,000 | 15,500 | 39% |
| Archer Quartz | 47,500 | 2,500 | 4,000 | 5,000 | 11,500 | 24% |
| Mizutani Hozuki | 60,000 | 6,000 | 9,000 | 12,000 | 27,000 | 45% |
| Villefort Columbus | 75,000 | 7,500 | 11,500 | 15,000 | 34,000 | 45% |
| Villefort Cortes | 95,000 | 9,500 | 14,500 | 19,000 | 43,000 | 45% |
| Thorton Merrimac | 115,000 | 11,500 | 17,500 | 23,000 | 52,000 | 45% |
| Archer Bandit | 130,000 | 11,000 | 16,500 | 22,000 | 49,500 | 38% |
| Chevalier Thrax | 155,000 | 15,500 | 23,500 | 31,000 | 70,000 | 45% |
| Yaiba Kusanagi | 200,000 | 20,000 | 30,000 | 40,000 | 90,000 | 45% |
| Yaiba Semimaru | 250,000 | 25,000 | 37,500 | 50,000 | 112,500 | 45% |

### 18.2 Orders of magnitude

- **Full cosmetics.** A Hella with paint, rims, a full kit (the 7 groups
  that fit it), neon, plate and headlights costs 41,000 €$ (137% of the car's price).
  That is about 19 h at the entry grade, or 12.5 h at grade 3. With the
  5-group kit of the first version, it was 34,000 €$ (113%).
- **Cosmetics and stage 3.** With stage 3 on top, the same Hella costs 52,000 €$
  (173% of the car), about 24 h at the entry grade.
- **Fixed cost.** Cosmetic prices do not depend on the model; only the number of
  body kit groups that fit it changes the total. So full cosmetics weigh
  heavily on a MaiMai (34,000, 340% of 10,000, 5 groups) and lightly on a Semimaru
  (37,500, 15%, 6 groups). This is intended, so that style stays affordable. If the
  owner prefers a price proportional to the vehicle, a coefficient per
  model is needed, as for stages.
- **Wave 2.** Animation, lamps, engine sound, 4 stickers and a tag cost
  18,000 €$, about 8 h at the entry grade. Added to the Hella's full cosmetics,
  that makes 59,000 €$ (197% of the car), or 70,000 €$ with stage 3.

### 18.3 Questions for the owner

- **Cosmetic prices.** Should the provisional prices be kept (livery 4,000, rims
  6,000, body kit 3,500 per group, neon 5,000, plate 2,500, headlights 500, trim
  2,500, windows 1,500 when they reopen)? Should they be made proportional to the
  vehicle's price?
- **Stages.** Should proposal E5, the removal at 1,000 with no refund
  and the 10 min cooldown be kept?
- **Plate.** The provisional format is 7 characters A-Z/0-9, and the lists of banned
  and reserved words still need to be completed. Should a custom plate cost
  more than a randomly drawn one? (Random plates do not exist yet.)
- **Wave 2.** Should the neon animation stay at 2,500, the lamp colors at
  1,500 for all groups, the engine sound at 6,000, the stickers at 1,500 each and
  the tag at 2,000? Should a sticker cost according to its size (its decals) rather than
  per piece? Should the engine sound preview stay free?
