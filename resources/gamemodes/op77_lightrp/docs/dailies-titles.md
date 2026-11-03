# Contrats du jour, métiers à plusieurs et titres de prestige

Document de contenu du 2026-11-03, branche `lightrp/dailies-titles`, pour les propositions 1, 3
et 4 validées dans `lightrp-design-propositions.md`. **C'est ce document que le propriétaire
juge** : le code suit le contenu, jamais l'inverse.

La consigne : « des vrais événements, drôles, amusants et bien pensés », pas une liste du type
« tue 10 ennemis » ou « roule 5 km ». Chaque contrat est donc une petite histoire de Night City,
racontée par un des trois fixers existants (`server/config/fixers.lua`), avec un détail qui le
rend racontable après coup. Chacun repose **uniquement** sur un système existant que le serveur
sait vérifier ; le crochet est nommé à chaque fois. Les textes en anglais sont ceux que le joueur
voit en jeu.

| Fixer | Voix | Emploi ici |
|---|---|---|
| **Mama Okoro** (Heywood) | chaleureuse, autoritaire, « choom » | la rue, le quartier, le travail honnête |
| **Silas "Ledger" Varga** | corpo, sec, comptable | les chiffres, la propreté du travail |
| **Nix Delacroix** (Pacifica) | minuscules, abréviations, rapide | la vitesse, le style, le chaos |

Sommaire : §1 règles des contrats · §2 contrats du jour (Rue, Action, Métier) · §3 contrats de
crew · §4 contrats de la semaine · §5 métiers à plusieurs · §6 titres · §7 écarts volontaires
avec la proposition · §8 questions au propriétaire.

---

## 1. Règles des contrats

### 1.1 Ce que voit le joueur

F1 → **Contracts** ouvre un panneau à deux onglets, **Today** et **Titles**. *Today* montre :

- trois **contrats du jour**, un par case : **Street** (la ville, le social), **Action**
  (missions et activités), **Shift** (le métier du joueur) ;
- un **contrat de crew**, qui se valide quand deux membres du même crew le font ensemble ;
- le **contrat de la semaine**, plus long et mieux payé ;
- la série de jours en cours et le compte à rebours jusqu'à la remise à zéro.

Chaque carte affiche le fixer, son message (1 à 2 lignes), l'objectif tel que le serveur le
vérifie, la progression (« 1.2 / 1.5 km », « 0 / 1 ») et la récompense. Une fois l'objectif
atteint, une notice « Contract complete » apparaît ; le bouton **Claim** verse la somme et affiche
« +€$ 300 ».

### 1.2 Rotation et remise à zéro

- **Jour = jour UTC.** Remise à zéro à **00:00 UTC** (01:00 à Paris l'hiver, 02:00 l'été), comme
  les plafonds journaliers des missions et des activités (`dayIndex` = `floor(unix / 86400)`).
- **Semaine = lundi 00:00 UTC.**
- **Street, Action et Crew sont les mêmes pour tout le serveur** ce jour-là (tirage déterministe
  à partir du numéro du jour). C'est voulu : le jour de *Street Performer*, The Crossing se remplit
  de danseurs, et tout le monde sait pourquoi. **Shift** est commun à tous ceux du même métier.
  Le contrat de la semaine est commun à tout le serveur.
- Le tirage **saute un contrat dont la source manque** (ressource `op77_chase` arrêtée, métier sans
  route, Chimera absente) et ne reprend pas le contrat de la veille dans la même case. Un contrat
  devenu impossible en cours de journée reste affiché mais peut être échangé gratuitement.
- **Un échange gratuit par jour** : le joueur remplace un de ses trois contrats du jour par un
  autre de la même case, tiré pour lui seul. C'est la soupape des contrats sociaux sur un serveur
  calme. La progression du contrat échangé est perdue. Pas d'échange pour le crew ni la semaine.
- Un contrat terminé reste **réclamable jusqu'à la fin du jour suivant** : finir à 23:58 UTC ne
  fait rien perdre.

### 1.3 Récompenses et plafonds

| Case | Récompense | Pourquoi |
|---|---:|---|
| Street | 250 €$ | court, social, souvent gratuit |
| Action | 400 €$ | demande une mission ou une activité réelle, avec une contrainte |
| Shift | 250 €$ | s'ajoute à la paie du métier, qui tourne déjà |
| Crew | 300 €$ chacun | il faut être deux comptes distincts |
| Semaine | 3 000 €$ | un vrai défi, une fois par semaine |

- Les trois contrats du jour font **900 €$** : les 3 × 300 de la proposition, répartis selon
  l'effort. Avec le crew, **1 200 €$ par jour au plus**, plus la semaine (≈ 430 €$ par jour).
- **Plafond serveur par compte et par jour UTC** : `dailyBudget = 1200` €$ pour les contrats du
  jour et de crew. La semaine a son propre plafond (un seul contrat). Au-delà, le serveur refuse
  le versement et le dit.
- Effet sur la courbe (`economy-balance.md` §7, joueur régulier à 2,5 h par jour) : s'il fait
  **tout, tous les jours**, il gagne ≈ 650 €$ de plus par heure jouée (4 100 → 4 750 €$/h) et la
  meilleure voiture passe de 23,7 h à ≈ 20,5 h, encore dans la cible de 20 à 30 h. Un joueur qui
  fait deux contrats par jour en moyenne reste à ≈ 22 h, le chiffre de la proposition.
- **Aucune réputation** : elle reste la récompense du PvE (décision du 2026-11-03).
- Paiement par `LightRP.money.addBank` avec le motif `contract` et le titre du contrat dans le
  relevé (`/bank`).

### 1.4 Anti-abus, une fois pour toutes

- **Progression et récompense par compte** (l'`identifier` Master), comme le `capScope =
  "account"` des missions : un alt ne double rien.
- **Seules les sources déjà filtrées comptent.** Pour une activité, c'est le verdict
  d'`activity_pay` (pas de bots, pas de partie tout-un-crew, pas de forfait, durée et progression
  minimales, limites de répétition par paire) ; un résultat `test` ne compte jamais. Pour une
  mission, une mission réussie hors test. Pour un world boss, une part `eligible`.
- **Tout contrat « avec quelqu'un » exige un autre compte**, et le serveur mesure lui-même
  positions, sièges et animations par échantillonnage (toutes les 5 s). Le client n'envoie
  jamais de progression.
- **Rien ne s'achète** : aucun contrat ne se valide en dépensant plus qu'il ne rapporte, sauf le
  kit de soin de *Good Samaritan*, payé par le contrat.

---

## 2. Contrats du jour

Notation de chaque entrée : **titre en jeu** (fixer) · message · *objectif vérifié* · crochet ·
pourquoi c'est amusant · récompense.

### 2.1 Street (la ville, 250 €$)

**Ledger's Lucky Number** (Ledger)
> "My accountant believes in luck. I believe in clean numbers. End a bank transaction on a balance
> ending in 777. Naturally, my payment will ruin it."

- *Objectif* : après un mouvement de banque, le solde bancaire se termine par **777**
  (`solde % 1000 == 777`).
- *Crochet* : `onMoneyChanged(id, "bank", delta, balance, kind)`.
- *Pourquoi* : c'est une énigme avec la vraie économie. Il faut acheter un soda pour 3 €$,
  vendre un sac au bon moment, ou demander à un ami un virement de 23 €$ pile. Et la paie de
  Ledger casse aussitôt le 777, ce qu'il annonce lui-même.

**Nobody Eats Alone** (Okoro)
> "You eat noodles over the sink like a gonk. Find somebody, sit down, eat together. Mama's
> orders."

- *Objectif* : finir un plat à moins de **10 m** d'un citoyen (autre compte) qui finit lui aussi
  un plat dans les **2 minutes**. Les deux valident.
- *Crochet* : `onItemUsed` (objets `use.food`), puis positions serveur.
- *Pourquoi* : « On se prend un ramen ? » devient une phrase qu'on entend à The Crossing. Celui
  qui invite un inconnu fait aussi son contrat à lui.

**Housewarming** (Okoro)
> "Got a place and nobody's ever seen it? A home without guests is a box with a lock. Invite
> someone in. Three minutes. Offer them a drink, I don't care."

- *Objectif* : **3 minutes** dans un logement avec un citoyen d'un autre compte, l'un des deux
  ayant la clé. L'hôte et l'invité valident.
- *Crochet* : sessions de `housing.lua` (même `property`, `H.hasKey`), échantillonnées.
- *Pourquoi* : c'est la visite d'appart, avec le studio gratuit du premier jour comme décor. Et
  une raison de donner enfin cette clé.

**Running on Fumes** (Nix)
> "real ones don't fill up til the light's blinking. bring her in under 10%. jerrycan doesn't
> count, that's cheating lol"

- *Objectif* : faire le plein **à la pompe** d'une voiture dont le réservoir était **sous 10 %**,
  et le remonter **au moins à 50 %**.
- *Crochet* : nouvel appel `onRefuelled` à la validation de la pompe (`refueling.lua`), avec le
  niveau avant le plein.
- *Pourquoi* : il faut brûler son essence exprès, en surveillant la jauge, et risquer la panne
  sèche à 300 m de la station. Une panne oblige à acheter un jerrycan, qui ne compte pas. Les
  histoires « j'étais à 2 % » viennent toutes seules.

**Ride Along** (Okoro)
> "A million cars in this city and every one of them has one gonk in it. Share a ride. Driver,
> passenger, a kilometre and a half. Talk about something."

- *Objectif* : conducteur et passager de comptes différents dans le même véhicule pendant
  **1,5 km** parcourus ensemble. Les deux valident.
- *Crochet* : `Open77.vehicles.getPlayerSeat` (même `vehicleId`) et positions, échantillonnés.
- *Pourquoi* : proposer de déposer quelqu'un devient naturel, et un taxi improvisé apparaît.

**Street Performer** (Nix)
> "the crossing needs ✨culture✨. pick an emote, hold it a full minute, and somebody has to watch.
> if ur audience walks off u start over"

- *Objectif* : à **The Crossing** (rayon 40 m), tenir **la même animation 60 s** pendant qu'au
  moins un citoyen d'un autre compte reste à moins de **12 m**. Si le public part, le compteur
  repart à zéro.
- *Crochet* : `Open77.animations.current` (même `playbackId`), positions, échantillonnés.
- *Pourquoi* : c'est le contrat le plus visible. Les gens dansent au hub et demandent à des
  inconnus « regarde-moi une minute ». Et le public peut partir exprès à 55 s.

**The Tour** (Okoro)
> "There's a fresh face at the Crossing with eyes like a lost cat. Show them the city. A
> kilometre, together, no ditching. Be nice, they'll remember."

- *Objectif* : parcourir **1 km** en restant à moins de **30 m** d'un citoyen d'un autre compte
  dont le personnage a **moins de 5 h de jeu**. Chaque nouveau ne compte qu'une fois par vétéran.
- *Crochet* : `playtimeMs` du personnage (`characters.lua`), positions, échantillonnés.
- *Pourquoi* : c'est le seul contrat qui paie pour accueillir. Le nouveau reçoit un mot d'Okoro
  (« Somebody showed you around. Pay it forward. ») et découvre la ville avec un guide.

### 2.2 Action (missions et activités, 400 €$)

**Before the Overclock** (Ledger)
> "The Chimera's core overclocks if you dawdle. I do not pay overtime. Put it down before it
> heats up."

- *Objectif* : abattre la Chimera, à n'importe quelle difficulté, **avant l'overclock** (enrage
  à 12, 10 ou 8 minutes de combat).
- *Crochet* : `onMissionFinished`, plus un rapport de fin de raid dans `mission_chimera.lua`
  (`inst.report.enraged`).
- *Pourquoi* : le raid devient une course contre le chrono déjà affiché (`enrageInMs`). On
  change de kit, on rush le cœur, et on sacrifie sa sécurité.

**Lose Them, Don't Wait** (Nix)
> "anyone can hide til the timer runs out. boring. i want u to SHAKE them. actually lose the
> cops"

- *Objectif* : s'échapper d'**NCPD Escape** (`chase.pve`) en semant la police (`how == "shake"`),
  pas au chrono ni par extraction.
- *Crochet* : nouvel appel `onActivityResult` (verdict d'`activity_pay`), statistiques `outcome`
  et `how`.
- *Pourquoi* : la stratégie habituelle (tenir jusqu'à la fin) ne paie plus. Il faut jouer les
  ruelles, les tunnels et la casse.

**Run It Back** (Ledger)
> "Set a time on any time trial. Then beat it. The first run is the invoice, the second is the
> payment. And don't sandbag the first one. I'll know."

- *Objectif* : finir deux fois le même contre-la-montre aujourd'hui, la seconde au moins **1 s**
  plus vite que la première. Le serveur garde le premier temps du jour.
- *Crochet* : `onActivityResult` sur `race.trial` (`finished`, `timeMs`, `courseId`).
- *Pourquoi* : on se bat contre soi-même, et le chiffre affiché à l'arrivée compte enfin.
  (Ledger ne sait pas vraiment : lever le pied au premier passage reste possible, et c'est
  assumé.)

**Billable Hours** (Ledger)
> "Clients pay for results, not for hours. Finish any job with half the clock still on it."

- *Objectif* : réussir une mission (tableau, gig, Chimera, Sector 04) avec **au moins la moitié**
  du temps limite restant.
- *Crochet* : `onMissionFinished` (`inst.startedAt`, `inst.endsAt`).
- *Pourquoi* : une mission connue devient un speedrun, et le crew se dispute l'itinéraire.

**Answer the Phone** (Okoro)
> "When a fixer texts, you answer. Even Ledger. Even Nix, god help you. Finish one gig today."

- *Objectif* : réussir un **gig de fixer** (offert par SMS, `inst.gig`).
- *Crochet* : `onMissionFinished`.
- *Pourquoi* : les SMS des fixers comptent enfin, et accepter un gig en pleine balade devient un
  vrai choix.

**Five Without a Dirt Nap** (Nix)
> "5 kills in a row in the arena without dying. bots count. ur ego doesn't"

- *Objectif* : une série de **5 éliminations sans mourir** dans une partie d'arène PvE payée
  (`bestStreak >= 5`).
- *Crochet* : `onActivityResult` sur l'arène PvE.
- *Pourquoi* : l'arène PvE devient une question de survie plutôt que de volume, et on joue plus
  prudemment juste après la quatrième élimination.

### 2.3 Shift (le métier, 250 €$)

La case Shift dépend du métier actuel. **NCPD** n'a pas encore de système vérifiable et reçoit un
contrat Street tiré pour lui.

**Full Truck** — Sanitation, Scrapper (Okoro)
> "One bag at a time is how you get a bad back, choom. Load the trunk and sell twenty in one go."

- *Objectif* : une seule vente d'**au moins 20** marchandises, ce qui exige un coffre de voiture
  (le sac porte 40 kg, le coffre 80 kg).
- *Crochet* : `onJobWorkCompleted`, avec un quatrième argument `{ count, total, point }` ajouté
  à la vente (`job_work.lua`).
- *Pourquoi* : le coffre devient un outil de travail : allers-retours entre le point de collecte
  et la voiture, calcul du poids, et une grosse vente à la fin.

**The Full Round** — Sanitation, Scrapper (Okoro)
> "A real round: both pickups, then the buyer, inside thirty minutes. The city doesn't clean
> itself one block at a time."

- *Objectif* : un lot collecté aux **deux** sites de collecte (Sanitation : West et Center ;
  Scrapper : South et North), puis une vente, le tout en **30 minutes**.
- *Crochet* : `onJobWorkCompleted` avec l'identifiant du point.
- *Pourquoi* : un vrai trajet à planifier, avec une voiture et un chrono, au lieu de camper un
  seul point.

**Still Hot** — Courier (Nix)
> "food's gotta land HOT. beat dispatch's clock or the customer leaves 1 star and i cry"

- *Objectif* : finir une course Courier plus vite que l'estimation du dispatch (**3 min +
  1,5 min par km** de la route).
- *Crochet* : `onJobRunStarted` et nouvel appel `onJobRunCompleted` (`job_runs.lua`).
- *Pourquoi* : la tournée devient une course, avec un objectif chiffré visible dès le départ.

**Fragile** — Courier (Ledger)
> "Today's cargo is porcelain. Corporate porcelain. One route, and the car arrives with no more
> than five percent damage. Drive like you're being audited."

- *Objectif* : une course Courier entière dans la même voiture, sans perdre plus de **5 %** de
  sa santé entre la première étape et la livraison finale.
- *Crochet* : `onJobRunStarted`, `onJobRunCompleted`, `Open77.vehicles.getHealth` (fusionné au
  minimum par le serveur, donc impossible à « réparer » côté client) et `getPlayerSeat`.
- *Pourquoi* : conduire prudemment dans le trafic de Night City, c'est drôle. Le moindre poteau
  et c'est raté.

**Heat Wave** — AC Cleaner (Okoro)
> "It's an oven up there and the tenants are melting. One rooftop route, under five minutes.
> Move."

- *Objectif* : finir la tournée des toits en **moins de 5 minutes** (l'estimation affichée est
  de 5 à 8).
- *Crochet* : `onJobRunStarted` et `onJobRunCompleted`.
- *Pourquoi* : la tournée connue devient un enchaînement serré entre accès, unités et rapport.
  (Les points d'AC Cleaner sont encore provisoires : la route actuelle se fait en 4 min environ,
  à régler quand les vrais emplacements arriveront.)

**On Call** — Street Medic (Okoro)
> "Somebody's bleeding out tonight. Be there before Trauma Team. One patient, stabilized."

- *Objectif* : stabiliser un patient d'un autre compte.
- *Crochet* : `onPatientStabilized(actor, patient)` (`medical.lua`).
- *Pourquoi* : le médic part en patrouille au lieu d'attendre un appel.

**Fare Paid** — Delamain Partner, taxi (Ledger)
> "A ride is a service. A service is invoiced. Drive a citizen two kilometres, let them out, and
> collect the fare. At least twenty. Tips encouraged."

- *Objectif* : conduire un passager d'un autre compte sur **2 km**, puis recevoir de lui un
  virement d'**au moins 20 €$** dans les **3 minutes** après sa sortie.
- *Crochet* : `getPlayerSeat` échantillonné, puis `onMoneyChanged` (`transfer_in` venant de ce
  passager).
- *Pourquoi* : le taxi n'avait aucune boucle. Celle-ci est du vrai RP : le client paie sa course,
  et donne un pourboire s'il est content.

**Roadside Assistance** — Rust & Chrome, mécanicien (Okoro)
> "Some fool ran dry on the highway again. Grab a jerrycan and go save their evening."

- *Objectif* : verser un jerrycan dans une voiture tombée en **panne sèche** moins de
  **20 minutes** plus tôt, conduite par un autre compte.
- *Crochet* : `onFuelEmpty(vehicleId, driver)` et `onRefuelled` (versement au jerrycan).
- *Pourquoi* : c'est le revers comique de *Running on Fumes*. Les joueurs qui tentent le 10 %
  tombent en panne, et le mécano les sauve. Deux métiers se croisent sans script.

**Clock In** — sans emploi (Okoro)
> "No job? Mama knows people. Job Center, City Center. Get hired and finish your first shift. Then
> we talk."

- *Objectif* : se faire embaucher au Job Center et terminer un premier cycle de travail (un lot
  vendu ou une course finie).
- *Crochet* : `onJobChanged`, `onJobWorkCompleted`, `onJobRunCompleted`.
- *Pourquoi* : c'est le seul contrat qui mène quelque part au lieu de récompenser une routine.

---

## 3. Contrats de crew (300 €$ chacun)

Un crew, c'est le groupe de `parties.lua` (le cadre de crew à l'écran). Il faut au moins **deux
membres sur des comptes distincts**, et chaque membre qui remplit l'objectif valide le contrat une
seule fois.

**Convoy** (Nix)
> "two cars, one vibe. drive ur own rides side by side for 3 km. no passengers, no ditching"

- *Objectif* : deux membres au volant de **deux voitures différentes**, à moins de **40 m** l'un
  de l'autre, sur **3 km**.
- *Crochet* : `getPlayerSeat` (`seat_front_left`) et positions, échantillonnés.
- *Pourquoi* : rouler en convoi dans Night City, dans les bouchons et les virages, c'est déjà une
  scène de film. Se perdre de vue fait repartir le compteur.

**Back to Back** (Ledger)
> "Two operators, one arena, one result. Win it together, and both of you contribute. I don't pay
> passengers."

- *Objectif* : gagner une partie d'arène PvE payée ensemble, avec **au moins une élimination
  chacun**.
- *Crochet* : `onActivityResult` (même partie, `won`, `kills`).
- *Pourquoi* : personne ne se fait porter. Le plus fort doit laisser des cibles au plus faible.

**Bar Crawl** (Okoro)
> "Three bars, one night, same crew. Drink something at each. Different districts, choom, I want
> you to see the city."

- *Objectif* : boire (objets `use.drink`) ensemble à moins de **25 m** de **trois bars** de la
  carte dans **trois quartiers différents**, en moins d'une heure. Tous les membres présents
  boivent.
- *Crochet* : `onItemUsed`, les 15 bars réels de `LightRpConfig.mapPlaces` (El Coyote Cojo,
  Afterlife, Ho-Oh, Riot…), positions.
- *Pourquoi* : c'est une tournée des bars, en voiture, avec la voix de proximité, et la carte des
  lieux nocturnes sert enfin à quelque chose.

**Album Cover** (Nix)
> "crew pic at the crossing. everybody strike a pose at the same time, 10 seconds, nobody blinks"

- *Objectif* : à The Crossing, **tous** les membres du crew (deux au moins) jouent une animation
  en même temps, à moins de **6 m** les uns des autres, pendant **10 s**.
- *Crochet* : `Open77.animations.current` et positions, échantillonnés.
- *Pourquoi* : chaque crew repart avec une capture d'écran. Le contrat est court, mais il faut
  se coordonner, et c'est drôle à voir de l'extérieur.

**Nobody Left Behind** (Nix)
> "NCPD Escape as a crew. EVERYONE gets out or nobody gets paid. go"

- *Objectif* : une partie d'NCPD Escape en crew (`crew = true`) où **tous** les membres du crew
  présents s'échappent.
- *Crochet* : `onActivityResult` sur `chase.pve`.
- *Pourquoi* : le plus rapide doit revenir chercher les autres, et c'est le genre de partie dont
  on parle après.

Le **Big Contract** Courier (§5.2) n'est pas un contrat de crew : il exige deux coursiers, ce
que la plupart des crews ne sont pas. C'est une offre du métier.

---

## 4. Contrats de la semaine (3 000 €$)

Un seul par semaine, commun à tout le serveur, remis à zéro le lundi à 00:00 UTC.

**Two Against the Machine** (Ledger)
> "The Chimera at Hard or above, with exactly two operators. The budget doesn't allow a third."

- *Objectif* : abattre la Chimera en **Hard ou Critical** à **exactement deux**.
- *Crochet* : `onMissionFinished` (`#inst.members == 2`, difficulté).
- *Pourquoi* : c'est le raid prévu pour deux au minimum, sans marge. Ceux qui le font ont une
  histoire à raconter, et le titre *Two-Man Army*.

**All the Way** (Ledger)
> "I don't pay for blowouts. Win a ranked duel that goes to the deciding round."

- *Objectif* : gagner un duel classé payé **à la manche décisive** (par exemple 3-2 en
  meilleur des 5).
- *Crochet* : `onActivityResult`, `roundsWon` et `roundsLost` du duel.
- *Pourquoi* : le score serré devient l'objectif. Une victoire 3-0 ne vaut rien ici, et ça se
  dit pendant le match.

**Lion's Share** (Ledger)
> "When the big one goes down, I want your name at the top of the invoice."

- *Objectif* : être **premier contributeur** (score) d'un world boss abattu.
- *Crochet* : nouvel appel `onWorldEventEnded(ev, success)` (`world_bosses.lua`), `ev.contrib`.
- *Pourquoi* : un événement public devient une compétition entre alliés.

**Both Sides of the Law** (Nix)
> "most wanted. bust somebody as a cop AND get away as the runner. same match. be a hypocrite"

- *Objectif* : dans une même partie de **Most Wanted** (`chase.wanted`), au moins **une
  arrestation** et au moins **une fuite réussie** (extraction ou survie).
- *Crochet* : `onActivityResult` (`arrests`, `extractions`, `survivals`).
- *Pourquoi* : il faut bien jouer les deux rôles dans la même partie, et le titre est assumé.

**Good Samaritan** (Okoro)
> "Three strangers this week. Not your crew. Somebody you don't know, bleeding on a street you
> don't live on. Mama covers the kits."

- *Objectif* : stabiliser **trois citoyens différents**, d'autres comptes, hors de son crew.
- *Crochet* : `onPatientStabilized`, `Party.of`.
- *Pourquoi* : c'est la version semaine du médic de rue, ouverte à tous ceux qui ont un kit (le
  prix de trois kits, 750 €$, est largement couvert).

---

## 5. Métiers à plusieurs

### 5.1 Bonus de crew : +15 %

- **Qui** : deux membres du même crew, sur des **comptes distincts**, dans le **même métier**.
- **Quand** : à chaque vente de Sanitation ou de Scrapper, et à chaque course payée (Courier, AC
  Cleaner).
- **Conditions vérifiées au moment de la paie** :
  - **sites fixes** (Sanitation, Scrapper) : un coéquipier à moins de **60 m** du vendeur, qui a
    lui-même terminé un cycle de travail (collecte, transformation, vente) dans les
    **5 dernières minutes** ;
  - **courses** (Courier, AC Cleaner) : un coéquipier du même métier qui a lui aussi validé une
    étape de course dans les 5 dernières minutes, sans condition de distance. Deux coursiers
    partent chacun de leur côté et se retrouvent au dispatch, c'est le métier.
- **Montant** : 15 % de la paie (grade compris), versé sur une ligne séparée du relevé, motif
  `crew_bonus`. Le joueur voit « Crew bonus +15% » dans la notice de vente.
- **Limites** :
  - un compte n'est payé qu'une fois par vente, quel que soit le nombre de coéquipiers ;
  - au plus **2 000 €$** de bonus par compte et par jour UTC (`crewBonus.dailyCap`), soit
    environ 13 000 €$ de ventes ;
  - un coéquipier inactif ne déclenche rien, puisqu'il faut son propre cycle récent ;
  - les sites d'entraînement du tutoriel sont exclus, tout comme le Big Contract, qui a sa
    propre prime.
- **Effet** : J passe de 3 500 à ≈ 4 000 €$/h à deux, toujours sous les missions (1,7 × J).
- `crewBonus.rate = 0` coupe tout.

### 5.2 Le Big Contract (Courier, deux coursiers)

> Okoro : "Wedding in Heywood. Six orders, two couriers. And the bride wants everything on the
> table at once: last two drops inside two minutes of each other, or it's cold canapés."

- **Comment ça se joue** :
  - au Job Center, un coursier en crew avec un autre coursier (compte distinct, à moins de 30 m,
    aucun des deux en course) voit l'option **Big Contract** ;
  - le dispatch tire **5 à 6 commandes** et les partage en **deux moitiés**, avec des adresses
    différentes : chacun a sa route, son GPS et ses commandes dans le sac ;
  - chacun est payé de sa moitié à sa dernière livraison, au tarif normal d'une course.
- **La prime** :
  - si **les deux moitiés** sont livrées, chacun touche **+20 %** de sa moitié ;
  - **+35 %** si les deux dernières livraisons tombent à moins de **2 minutes** d'intervalle
    (« Served together »).
- **Pourquoi c'est amusant à deux** : chacun a sa propre route, mais la fin se joue en même
  temps. « Je suis devant la porte, t'en es où ? », « Trente secondes ! », et l'un attend sur le
  palier pendant que l'autre fonce. On peut aussi faire les deux moitiés dans la même voiture,
  l'un conduit et l'autre descend. Les deux façons de jouer sont bonnes.
- **Limites** :
  - un abandon ne paie rien à celui qui abandonne ; l'autre garde sa moitié au tarif normal,
    sans la prime ;
  - le contrat expire comme une course (45 min) ;
  - le bonus de crew (+15 %) ne s'ajoute pas au Big Contract ;
  - les deux coursiers doivent être sur des comptes distincts.

---

## 6. Titres de prestige

### 6.1 Règles

- **Par personnage**, comme la réputation et les lignes du Hall of Fame
  (`identifier#characterKey`). Les titres gagnés par le compte (série de jours, contrats) vont au
  personnage actif au moment du gain.
- **Un seul titre affiché**, choisi dans F1 → Identity → **Title**, ou dans l'onglet **Titles**
  du panneau Contracts. « No title » est toujours possible.
- **Où il s'affiche** :
  - dans le chat RP de proximité (« Kaito Mori · Legend ») ;
  - sous le nom dans le cadre du crew ;
  - à côté du nom dans le Hall of Fame ;
  - dans l'écran de fin de match, via `LightRP.titles.shown(id)`, que l'agent du récapitulatif
    pourra brancher.
- **Raretés** : *Common*, *Rare*, *Epic*, *Legendary*, et *Live* (titre de classement, tenu
  seulement tant qu'on est premier). La couleur suit la rareté.
- **Aucun texte libre**, donc rien d'offensant. Un titre dont la source manque (ressource arrêtée)
  est caché du catalogue, sauf s'il est déjà gagné.
- **Les titres verrouillés sont visibles**, grisés, avec leur condition : c'est la liste
  d'envies du joueur.
- **Aucun argent** : le prestige ne coûte rien à l'économie.
- Staff : `/lightrp.titles grant|revoke <joueur> <titre>`.

### 6.2 Catalogue

| Titre | Comment on le gagne | Source vérifiée | Rareté |
|---|---|---|---|
| **Merc** | Palier de réputation II | `Missions.tier` | Common |
| **Operator** | Palier III | `Missions.tier` | Rare |
| **Edgerunner** | Palier IV | `Missions.tier` | Epic |
| **Legend** | Palier V (10 000 de réputation) | `Missions.tier` | Legendary |
| **Chimera Breaker** | Chimera Standard réussie | `Missions.cleared` | Common |
| **Core Cracker** | Chimera Hard réussie | `Missions.cleared` | Rare |
| **Chimera Critical** | Chimera Critical réussie | `Missions.cleared` | Epic |
| **Blackout** | Sector 04 Blackout réussi en Critical | `Missions.cleared` | Epic |
| **Overclock Denied** | Chimera Hard ou Critical abattue avant l'overclock | rapport de raid | Rare |
| **Two-Man Army** | Chimera Hard ou Critical à exactement deux | `onMissionFinished` | Epic |
| **Flawless** | Chimera Critical sans un seul opérateur à terre pendant le combat | rapport de raid | Legendary |
| **Boss Killer** | Coup fatal sur un world boss | `world_bosses.lua` (dernier coup) | Rare |
| **Lion's Share** | Premier contributeur d'un world boss abattu | `onWorldEventEnded` | Epic |
| **Duelist** | 10 duels classés gagnés (verdict payé) | `onActivityResult` | Rare |
| **Sudden Death** | 5 duels gagnés à la manche décisive | `onActivityResult` | Epic |
| **Street Racer** | 10 courses en grille gagnées avec au moins 3 vrais pilotes | `onActivityResult` | Rare |
| **Getaway Driver** | 10 extractions en Most Wanted | `onActivityResult` | Rare |
| **Long Arm of the Law** | 10 arrestations en Most Wanted | `onActivityResult` | Rare |
| **Ghost** | Semer l'NCPD 10 fois (NCPD Escape, `shake`) | `onActivityResult` | Epic |
| **Seven Days Straight** | 7 jours UTC d'affilée avec au moins un contrat réclamé | contrats | Rare |
| **Clockwork** | 30 jours d'affilée | contrats | Epic |
| **Okoro's Favourite** | 30 contrats réclamés | contrats | Rare |
| **Lucky Seven** | *Ledger's Lucky Number* réussi 3 fois | contrats | Rare |
| **Crowd Pleaser** | *Street Performer* réussi 3 fois | contrats | Rare |
| **Fumes Connoisseur** | *Running on Fumes* réussi 3 fois | contrats | Rare |
| **Top Gun** | N° 1 du classement PvP *kills* | Hall of Fame | Live |
| **Champion** | N° 1 du classement PvP *wins* | Hall of Fame | Live |
| **Track Record** | N° 1 du contre-la-montre | Hall of Fame | Live |
| **Raid Lead** | N° 1 des raids réussis | Hall of Fame | Live |
| **Eddie Baron** | N° 1 des fortunes | Hall of Fame | Live |
| **King of Dogtown** | Accordé par Dogtown chaque semaine, expire à la fin de la semaine suivante | crochet `LightRP.titles.grant` | Legendary |

Notes :

- **Les titres Live** se lisent dans le cache du Hall of Fame au moment de l'affichage. Perdre la
  première place cache le titre automatiquement, sans écrire en base, et le reprendre le rend.
- **Les titres PvP** répondent au point 12.6 d'`economy-balance.md` : le joueur 100 % PvP, que la
  réputation ignore, a enfin une piste. Ils ne comptent que des résultats déjà filtrés par
  `activity_pay`, donc pas de bots, pas de farm entre deux comptes au-delà des limites par paire.
- **King of Dogtown** est un crochet : Dogtown (branche `lightrp/dogtown-rules`) appelle
  `LightRP.titles.grant(id, "dogtown_king", { suffix = "W45", expiresAt = … })`. Le titre
  s'affiche « King of Dogtown · W45 ». Rien n'est câblé côté Dogtown sur cette branche.
- **Les trois titres « drôles »** (*Lucky Seven*, *Crowd Pleaser*, *Fumes Connoisseur*) gardent
  une trace des contrats dont on parle le plus. Ils demandent que le contrat repasse trois fois
  dans la rotation (ou par échange), donc quelques semaines.

---

## 7. Écarts volontaires avec la proposition validée

- **Récompenses modulées** : 250 / 400 / 250 au lieu de 300 partout. La moyenne reste à 300 et
  le total du jour à 900 €$ ; Action paie plus parce qu'il demande une mission ou une activité.
  Le crew paie 300 et la semaine 3 000, comme proposé.
- **Le contrat « Réanimer un citoyen »** de la proposition devient *On Call* (médic) et *Good
  Samaritan* (semaine). Sur un serveur calme, trouver un blessé chaque jour est trop aléatoire
  pour un contrat du jour ouvert à tous.
- **« 2 courses Courier » et « Finir une mission en crew »** ont été écartés : ce sont exactement
  les objectifs génériques que le propriétaire refuse. Ils sont remplacés par *Still Hot*,
  *Fragile*, *Billable Hours* et *Answer the Phone*.
- **Panneau** : F1 → Contracts ouvre son propre panneau. L'onglet dans le panneau Activités
  attendra que la branche `lightrp/activity-lobby`, qui réécrit ce panneau, soit fusionnée.
- **Crochet `onActivityResult`** : il est placé dans `activity_pay.lua`, juste après le calcul du
  verdict, et non dans `activities.lua`, que la branche `lightrp/activity-lobby` modifie.

## 8. Questions au propriétaire

1. **Contrats sociaux** (*Nobody Eats Alone*, *Housewarming*, *Ride Along*, *Street Performer*,
   *The Tour*) : ils supposent du monde. Un échange gratuit par jour suffit-il, ou faut-il ne pas
   les tirer quand moins de N joueurs sont en ligne ?
2. **Plafond** : `dailyBudget` à 1 200 €$ par compte. Faut-il descendre à 900 €$ pour coller aux
   « ≈ 9 % » de la proposition ?
3. **Titres** : faut-il qu'un joueur puisse cacher son titre aux autres tout en le gardant ? Pour
   l'instant, choisir « No title » suffit.
4. **King of Dogtown** : quel suffixe afficher, le numéro de semaine ISO (« W45 ») ou une date ?
5. **Taxi et mécano** : *Fare Paid* et *Roadside Assistance* donnent une première boucle à ces
   métiers. Faut-il aller plus loin (appel de taxi, dépanneuse) dans une autre branche ?
