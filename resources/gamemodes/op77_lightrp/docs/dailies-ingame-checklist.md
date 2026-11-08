# Dailies: in-game checklist

One sheet per contract, to check in game what the automated tests prove with mocked natives
(`tests/dailies_test.lua`, `tests/dailies_flow_*_test.lua`). The content and thresholds are
in `dailies-titles.md`; this page only says **what to type, what to do, what to see**.

## 0. Before you start

- **Clients**: "1 client" = a single account is enough. "2 clients" = two separate accounts
  (`open77_client_launch` with another `identity_profile`), otherwise the partner rule and
  the anti-alt check refuse everything. A **social** contract handed out with `give` can be tested
  with two even if fewer than 4 accounts are online: `give` overrides the crowd rule, the checks
  still apply.
- **Setup**, from the server console (restricted command):
  - `/lightrp.dailies give <player> <contract>` puts the contract in their slot, progress at zero;
  - `/lightrp.dailies status <player>` shows each slot: `<slot>=<contract> <value>/<target>`,
    then `done`, `claimed`, `(given)`; this is the server-side proof;
  - `/lightrp.dailies reset <player>` resets their day and week between two attempts
    (the streak and titles stay).
- **What must appear on each success**:
  1. the **DAILY COMPLETE** notice "*title* · *fixer*. Claim €$ N in F1 > Dailies.";
  2. F1 → **Dailies**: the card switches to **DONE**, with a **CLAIM €$ N** button;
  3. The Crossing terminal → **DAILIES** tab: the same card, the same state;
  4. after **CLAIM** in either one, the card is **PAID** in the other, and `/bank` shows
     the `contract` line with the contract's title.
- **What must never happen**: a success without the condition; a second success with
  the same partner in the same week (**DAILIES** notice "… It takes somebody new."); a
  social contract drawn on its own on a server with fewer than 4 accounts.

## 1. General rules (once)

| Check | Clients | Do | See |
|---|---|---|---|
| Quiet server | 1-2 | give nothing, open F1 → Dailies | no **WITH OTHERS** badge on Street, Shift or Weekly; the Crew card "Crew daily · Shows up when a crewmate is online" |
| Crowd | 4 | four accounts online, `status` | `(social on)`; a city social contract can appear for those who hadn't received anything yet |
| No flip-flopping | 4 → 2 → 4 | a player gets the social contract, two leave then come back | not started: it switches to the solo fallback and doesn't come back the same day; started: it stays |
| Swap | 1 | **SWAP · FREE** twice on the Street card | "New daily: …", never a social contract on a quiet server; "SWAP" disappears |
| Crew card | 2 | create a crew (ALT + click), then leave it | the crew card opens; it closes again if nobody has started |

## 2. Street

### Ledger's Lucky Number — 1 client
- Setup: `give <id> lucky_number`.
- Do: `/bank`, work out the gap to the next balance ending in 777; reach it with shop purchases or
  sales (candy 9 €$, resold for 1 €$) or a fill-up to the exact litre.
- See: DAILY COMPLETE on the payment that lands the balance on …777.
- Expected failure: a deposit or withdrawal at the counter / ATM that lands on …777 validates
  nothing; neither does a transfer from another player.

### Running on Fumes — 1 client
- Setup: `give <id> running_on_fumes`; rent a bike (30 L) or take your own car.
- Do: drive until the reserve (reserve notice at 15%), then below 10%; at the pump,
  fill up to at least 50%.
- See: DAILY COMPLETE at the end of the fill-up.
- Expected failure: a fill-up started above 10%, or stopped below 50%; a jerrycan.

### Nightcap — 1 client
- Setup: `give <id> nightcap`.
- Do: win a paid activity (the PvE arena, for example), leave, go to a bar (Ho-Oh, 636 m
  from The Crossing) and drink a drink from your inventory within 10 minutes.
- See: DAILY COMPLETE on the sip.
- Expected failure: drinking outside a bar, or after 10 minutes; drinking after a time trial
  finished alone (Time Trial).

### Nobody Eats Alone — 2 clients
- Setup: `give` to both players, `eat_together`.
- Do: within 15 m of each other, each eats a meal less than 8 s apart.
- See: DAILY COMPLETE for both.
- Expected failure: 20 m apart; 10 s apart; two sodas (drinking isn't eating); the
  next day in the same week with the same partner (DAILIES notice).

### Housewarming — 2 clients
- Setup: `give <host> housewarming`; the host has the key to a home, the guest goes in.
- Do: the host gives the guest a drink (inventory → Give) inside the home; the guest
  drinks it there.
- See: DAILY COMPLETE for the host.
- Expected failure: the guest steps out before drinking, even if they come straight back in; a
  host without a key; the gift made outside; an apple instead of a drink.

### Ride Along — 2 clients
- Setup: `give` to both, `ride_along`.
- Do: driver and passenger in the same vehicle, drive 1.2 km (Job Center → The Crossing).
- See: the progress bar goes up in metres during the ride, DAILY COMPLETE for both.
- Expected failure: alone in the car; your own second character as the passenger.

### Street Performer — 2 clients
- Setup: `give <artist> street_performer`.
- Do: at The Crossing, play an animation for 60 s, with the second player within 15 m.
- See: the progress bar in seconds, DAILY COMPLETE at 1:00.
- Expected failure: the audience moves more than 15 m away (back to 0:00); switching animations.

### The Tour — 2 clients
- Setup: `give <guide> the_tour`; the second account is a **new character** (less
  than 2 h of play).
- Do: walk or drive 750 m together, within 15 m (The Crossing → Afterlife).
- See: DAILY COMPLETE for the guide, Okoro's notice for the newcomer ("showed you around").
- Expected failure: a character with more than 2 h; drifting more than 15 m apart.

## 3. Action

### Clean Invoice — 1 client
- Setup: `give <id> clean_invoice`.
- Do: Chimera on Standard, alone, without going down during the fight.
- See: DAILY COMPLETE on the win.
- Expected failure: going down once; a staff test raid.

### Lose Them, Don't Wait — 1 client
- Setup: `give <id> lose_them`.
- Do: NCPD Escape, hold out until 3 stars then reach the extraction.
- See: DAILY COMPLETE on the result.
- Expected failure: getting away by running out the clock; extraction at 2 stars.
- Note: a quick extraction (before 60 s of play) is not paid by the activity
  (ACTIVITY PAY silent, recap `too_short`) but it **does validate** the contract.

### Leg Day — 1 client
- Setup: `give <id> leg_day`.
- Do: NCPD Escape, choose **On foot**, get away.
- See: DAILY COMPLETE on the result.
- Expected failure: car mode; an arrest; quitting the match.

### Five Without a Dirt Nap — 1 client
- Setup: `give <id> five_streak`.
- Do: paid PvE arena, chain 5 kills without dying.
- See: DAILY COMPLETE on the match result.
- Expected failure: dying at 4.

### Support Act — 1 client
- Setup: `give <id> support_act`; at the terminal, tick the bot allies.
- Do: win the PvE arena by wounding enemies (30% of a bot's health) that the allies
  finish off, with more assists than kills.
- See: DAILY COMPLETE on the result.
- Expected failure: as many kills as assists; a loss.

## 4. Shift

### Full Truck — 1 client (Sanitation or Scrapper)
- Setup: get hired at the Job Center, `give <id> full_truck`.
- Do: collect, process, head out for a second collection (the bag has room; so does the
  trunk), process, then sell at least 11 goods at once.
- See: DAILY COMPLETE on the sale.
- Expected failure: a sale of 10 (a single load).

### The Full Round — 1 client (Sanitation or Scrapper)
- Setup: `give <id> full_round`.
- Do: collect at site A, then at site B, then sell.
- See: the progress bar at 1/3, 2/3, then DAILY COMPLETE on the sale.
- Expected failure: selling after a single site (back to 0).

### Two Wheels — 1 client (Courier)
- Setup: `give <id> two_wheels`; a bike (Bikes category).
- Do: a whole Courier run on a bike.
- See: DAILY COMPLETE on the last delivery.
- Expected failure: part of the run in a car.

### Fragile — 1 client (Courier)
- Setup: `give <id> fragile`.
- Do: a whole run in the same car without hitting anything.
- See: DAILY COMPLETE on the last delivery.
- Expected failure: a solid crash (more than 5% health); switching cars mid-run.
- **To measure**: the health lost on a clean run and on a small scrape (5% threshold
  inherited, to be confirmed).

### Water Break — 1 client (AC Cleaner)
- Setup: `give <id> water_break`; a drink in the bag.
- Do: on the rooftop route, drink between the first and the last unit, then finish.
- See: DAILY COMPLETE on the end report.
- Expected failure: drinking before the first unit or after the last.

### On Call — 2 clients (Trauma Team)
- Setup: `give <medic> on_call`; the second player downed.
- Do: stabilize them with a kit.
- See: DAILY COMPLETE for the medic.
- Expected failure: the same patient a second time in the week.

### Fare Paid — 2 clients (Taxi)
- Setup: `give <driver> fare_paid`.
- Do: passenger in the back, 1.2 km, drop-off, then a payment of at least 6 €$ (cash or
  transfer) from the passenger to the driver within 3 minutes.
- See: DAILY COMPLETE on the payment.
- Expected failure: 5 €$; a payment from a third player; after 3 minutes; a 1.1 km ride.

### Roadside Assistance — 2 clients (mechanic)
- Setup: hire the mechanic **without** `give` (the contract must come from the call); the
  second player drives until the reserve or until running dry.
- Do: the mechanic reads the call "Roadside call: … km from you.", fills a jerrycan at the pump
  and pours it into the second player's car.
- See: the mechanic's Shift slot becomes *Roadside Assistance* on the call; DAILY COMPLETE on the
  pour.
- Expected failure: your own car doesn't open a call; if the car is filled at the pump
  by its driver, the slot goes back to the job's contract.

### Pit Crew — 2 clients (mechanic)
- Setup: `give <mechanic> pit_crew`; the second player drives their car to the pump and
  gets out.
- Do: the mechanic fills that car while the customer stays within 15 m, then the
  customer pays them at least ⌈litres × 4 €$⌉.
- See: DAILY COMPLETE on the payment.
- Expected failure: paid less than the fuel; the mechanic's own car; the customer
  moves more than 15 m away during the fill-up, then comes back for the end.

## 5. Crew (all with 2 clients, in a crew)

### Convoy
- Setup: a crew of two, `give` to both, `convoy`.
- Do: each in their own car, 2.4 km within 40 m.
- See: the progress bar in metres for both; DAILY COMPLETE together.
- Expected failure: passenger in the other's car; falling behind on two samples in a row
  (back to 0).

### Back to Back
- Setup: `give` to both, `back_to_back`.
- Do: enter the PvE arena together, win, at least one kill each.
- See: DAILY COMPLETE for both.
- Expected failure: two separate matches, even when each player starts their own in the same
  second (two instances).

### Bar Crawl
- Setup: `give` to both, `bar_crawl`.
- Do: drink together in 3 bars in 3 districts in less than an hour.
- See: the progress bar at 1/3, 2/3, 3/3, DAILY COMPLETE.
- Expected failure: two bars in the same district; drinking outside a bar.

### Album Cover
- Setup: `give` to the whole crew present, `album_cover`.
- Do: at The Crossing, everyone within 6 m plays an animation for 10 s.
- See: DAILY COMPLETE for everyone.
- Expected failure: a member present without an animation.

### Nobody Left Behind
- Setup: `give` to both, `nobody_left_behind`.
- Do: NCPD Escape as a crew, each one gets away.
- See: DAILY COMPLETE for both on the last result.
- Expected failure: only one gets away; a teammate who disconnects.
- Note: a teammate who reaches the extraction before 60 s doesn't make the crew fail.

## 6. Weekly

### Two Against the Machine — 2 clients
- Setup: `give` to both, `two_vs_machine`.
- Do: Chimera on **Hard** with exactly two players.
- See: DAILY COMPLETE for both, title **Two-Man Army**.
- Expected failure: a raid started with three where one leaves before the end; Critical or
  Standard.

### All the Way — 2 clients
- Setup: `give <id> all_the_way`.
- Do: ranked duel, win the deciding round (1-1 then the third).
- Expected failure: a 2-0 win.

### Lion's Share — 1 to 2 clients
- Setup: `give <id> lions_share`; start a world boss.
- Do: be its top contributor, the boss goes down.
- Expected failure: the boss survives; someone else does more damage.

### Both Sides of the Law — 2 clients
- Setup: `give <id> both_sides`.
- Do: in a single Most Wanted match, an arrest then an extraction or survival.
- Expected failure: the arrest alone.

### Good Samaritan — 2 clients (at least)
- Setup: `give <id> good_samaritan`.
- Do: stabilize 3 different citizens outside your crew during the week.
- See: 1/3, 2/3, DAILY COMPLETE.
- Expected failure: a teammate; the same citizen twice.

### One-Man Army — 1 client
- Setup: `give <id> one_man_army`.
- Do: Chimera on Standard, alone from start to finish.
- Expected failure: a second operator at the start of the fight.

### Walk of Shame — 1 client
- Setup: `give <id> walk_of_shame`; your own car almost empty.
- Do: let it run dry more than 1 km from the station, walk back, fill a
  jerrycan, go back and get it running again.
- See: 1/2 at the breakdown, DAILY COMPLETE on the pour.
- Expected failure: running dry less than 1 km away; pouring into another car.
