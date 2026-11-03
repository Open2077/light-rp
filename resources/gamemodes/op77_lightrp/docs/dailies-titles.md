# Dailies, métiers à plusieurs et titres de prestige

Document de contenu de la branche `lightrp/dailies-titles` (propositions 1, 3 et 4 validées dans
`lightrp-design-propositions.md`), révisé le 2026-11-03 après la passe « chaque contrat change la
façon de jouer ». **C'est ce document que le propriétaire juge** : le code suit le contenu, jamais
l'inverse. Les textes en anglais sont ceux que le joueur voit en jeu.

Le joueur voit la fonctionnalité sous le nom **Dailies** (F1, panneau, notices, guide). Le code et
les identifiants gardent `contracts` / `dailies` (`server/config/dailies.lua`,
`server/modules/dailies.lua`, `features/dailies/`). L'onglet **Contracts** du terminal des
activités reste celui des tableaux de missions.

| Fixer | Voix | Emploi ici |
|---|---|---|
| **Mama Okoro** (Heywood) | chaleureuse, autoritaire, « choom » | la rue, le quartier, le travail honnête |
| **Silas "Ledger" Varga** | corpo, sec, comptable | les chiffres, la propreté du travail |
| **Nix Delacroix** (Pacifica) | minuscules, abréviations, rapide | la vitesse, le style, le chaos |

Sommaire : §1 règles · §2 dailies du jour (Street, Action, Shift) · §3 crew · §4 semaine ·
§5 métiers à plusieurs · §6 titres · §7 ce qui a été remplacé ou borné · §8 mesures et
arithmétique des seuils · §9 écarts volontaires · §10 questions au propriétaire · §11 crochets et
preuves. La recette en jeu, contrat par contrat, est dans `dailies-ingame-checklist.md`.

---

## 1. Règles

### 1.1 Les trois règles de conception

Elles s'appliquent à **chaque** contrat et à chaque titre ; un contrat qui en viole une sort de la
liste.

1. **Un contrat change la façon de jouer** : une contrainte, une astuce, ou une interaction avec
   un autre système. Jamais « plus vite », « plus », ni « une fois ».
2. **Faisable seul sur un serveur calme.** Un contrat qui demande d'autres joueurs n'est tiré que
   si assez de comptes distincts sont en ligne (`social.minAccounts = 4`), et ne paie jamais deux
   fois pour le même partenaire dans la semaine (§1.4).
3. **Chaque seuil est mesuré, pas deviné.** Le calcul est écrit au §8 ; aucun objectif gratuit.

### 1.2 Ce que voit le joueur

- **F1 → Dailies** ouvre un panneau à deux onglets, **Today** et **Titles**. Le terminal des
  activités (The Crossing) a un onglet **DAILIES** qui montre la même page *Today* et envoie les
  mêmes actions (`dailies.claim`, `dailies.swap`) sur le même état `dailies` : un encaissement
  dans l'un apparaît dans l'autre à la poussée suivante. L'onglet demande un rafraîchissement à
  l'ouverture (`dailies.refresh`).
- *Today* montre trois dailies du jour (**Street**, **Action**, **Shift**), un **crew**, le
  **weekly**, la série de jours, le budget du jour, l'échange gratuit et les comptes à rebours.
- Chaque carte affiche le fixer, son message, l'objectif tel que le serveur le vérifie, la
  progression et la récompense. Un contrat social porte la pastille **WITH OTHERS**.
- **Carte de crew verrouillée** : sans coéquipier en ligne et tant qu'il n'est pas commencé, le
  contrat de crew est remplacé par une carte « Crew daily · Shows up when a crewmate is online ».
  Un contrat commencé ou fini n'est jamais caché.
- À la réussite : notice **DAILY COMPLETE** « *titre* · *fixer*. Claim €$ N in F1 > Dailies. » ;
  le bouton **Claim** verse la somme.

### 1.3 Rotation, foule et remise à zéro

- **Jour = jour UTC**, remise à zéro à **00:00 UTC** ; **semaine = lundi 00:00 UTC**.
- **Le tirage de la ville** : Street, Action et Crew sont les mêmes pour tout le serveur ce
  jour-là (tirage FNV-1a déterministe sur le numéro du jour), le weekly pour toute la semaine.
  Chaque case suit un cycle : sur *n* jours, chaque contrat passe une fois, jamais deux jours de
  suite le même, retour au plus tard 2*n* − 1 jours après. Le tirage saute un contrat dont la
  source manque et se fige deux minutes après le démarrage du serveur.
- **Le remplaçant solo** : chaque case a aussi son propre ordre de contrats **non sociaux**
  (`soloDraw`). Quand le contrat de la ville est social et que moins de 4 comptes distincts sont
  en ligne, le joueur reçoit le remplaçant solo du jour.
- **Une fois donné, un contrat reste** (`choose`), dans cet ordre :
  1. un contrat donné par le staff (`give`) l'emporte ;
  2. un contrat commencé (progression non nulle) est gardé, même si la ville se vide ;
  3. un contrat non commencé est gardé tant qu'il reste faisable ;
  4. sinon le contrat de la ville s'il est faisable, ou le remplaçant solo.
  Le serveur mémorise ce qu'il a donné (`locks`) : un joueur passé au remplaçant solo ne
  rebascule pas sur le contrat social si la foule revient le même jour. Pas de va-et-vient.
- **Shift** suit le métier :
  - deux contrats ou plus : ils alternent dans l'ordre du métier (Sanitation, Scrapper, Courier,
    mécano) ;
  - un seul contrat (Trauma Team, AC Cleaner) : un jour sur deux ; les autres jours, la case
    Shift reçoit un contrat **Street solo différent** de celui de la case Street ;
  - pas de contrat (NCPD, sans emploi) : le même remplaçant Street ;
  - un contrat social de métier (*On Call*, *Fare Paid*, *Pit Crew*) non faisable est remplacé
    par un autre contrat du métier, sinon par le remplaçant Street ;
  - **Roadside** n'est jamais tiré au hasard : il prend la case d'un mécano non engagé dès qu'un
    appel réel existe (§2.3), et la rend quand la voiture a été servie ailleurs.
  Un changement de métier remet la case à zéro, sauf contrat fini ou donné par le staff.
- **Un échange gratuit par jour** : le joueur remplace un de ses trois dailies par un autre de la
  même case, tiré pour lui seul **parmi les contrats faisables maintenant** (jamais un contrat
  social sur un serveur calme). Pas d'échange pour le crew, le weekly, ni un contrat donné par le
  staff. La progression du contrat échangé est perdue.
- Un contrat fini reste **réclamable jusqu'à la fin du jour suivant** ; le weekly de la semaine
  passée, le lundi.

### 1.4 La règle du partenaire

Un contrat social ne paie qu'une fois par **partenaire** (autre compte) et par **semaine ISO**.
Le serveur garde, par compte et par contrat, la semaine de chaque partenaire
(`meta.partners[contrat][compte] = semaine`, persistant en base avec le reste du méta).

- Si tous les partenaires possibles ont déjà servi cette semaine pour ce contrat, rien ne se
  valide, la barre attend juste sous la fin, et le joueur lit une fois : « *titre* · already done
  with this citizen this week. It takes somebody new. »
- La règle est par contrat : finir *Ride Along* avec Rosa n'empêche pas *Nobody Eats Alone* avec
  elle. Elle repart chaque lundi.
- Elle s'applique aussi aux contrats de crew (le coéquipier est le partenaire).

### 1.5 Récompenses et plafonds

| Case | Récompense | Pourquoi |
|---|---:|---|
| Street | 250 €$ | court, souvent gratuit |
| Action | 400 €$ | demande une mission ou une activité réelle, avec une contrainte |
| Shift | 250 €$ | s'ajoute à la paie du métier |
| Crew | 300 €$ chacun | il faut être deux comptes distincts |
| Weekly | 3 000 €$ | un vrai défi, une fois par semaine |

- **Plafond par compte et par jour UTC** : `dailyBudget = 1200` €$ pour les dailies et le crew ;
  le weekly est hors budget. Au-delà, le serveur refuse et le dit (« Dailies budget reached »).
- Effet sur la courbe (`economy-balance.md` §7) : tout faire tous les jours ajoute ≈ 650 €$ par
  heure jouée à 2,5 h par jour ; la meilleure voiture passe de 23,7 h à ≈ 20,5 h, dans la cible.
- **Aucune réputation** (décision du 2026-11-03). Paiement par `LightRP.money.addBank`, motif
  `contract`, titre du contrat dans le relevé.

### 1.6 Anti-abus

- **Progression et récompense par compte** (l'`identifier` Master) : un alt ne double rien et
  n'est pas un partenaire.
- **Seules les sources déjà filtrées comptent** : pour une activité, le verdict d'`activity_pay`
  (résultats classés ou PvE, ni bots en PvP, ni match amical, ni test du staff) ; pour une
  mission, une mission réussie hors test ; pour un world boss, une part `eligible`.
- **« Payé » veut dire « qui ouvre droit à la paie »** : un résultat que `activity_pay` chiffre
  (assez long, avec progrès, pas de bots, pas de répétition). Le plafond de paie du jour, ou la
  paie d'activité coupée sur le serveur, ne fait pas rater un contrat : le crochet passe avant
  ces deux contrôles (`activity_pay.lua:318`), et les dailies ont leur propre budget. Seule
  exception : une **extraction NCPD** plus courte que le plancher de 60 s compte (§8).
- **Une victoire, c'est battre quelque chose** : en PvE, ou en PvP avec au moins un autre joueur.
  Un contre-la-montre fini seul est « gagné » pour `op77_race`, pas pour les dailies.
- **« Le même match », c'est la même instance** (bucket de routage) **et** des entrées à 30 s
  près : deux matchs lancés côte à côte restent deux matchs.
- **Le serveur mesure lui-même** positions, sièges, animations et santé des véhicules toutes les
  5 s ; le client n'envoie jamais de progression. Un déplacement de plus de 70 m/s (`maxSpeed`, une téléportation) ne compte
  pas comme distance.

### 1.7 Outils du staff

`/lightrp.dailies` (commande restreinte) :

| Verbe | Effet |
|---|---|
| `give <joueur> <contrat>` | met ce contrat dans la case du joueur aujourd'hui (ou cette semaine), progression à zéro, quels que soient la foule, le métier ou le tirage ; non échangeable, survit à un changement de métier et à un redémarrage |
| `status <joueur>` | jour, comptes en ligne (social on/off), chaque case avec sa progression, `done`, `claimed`, `(given)`, échanges, budget, appels Roadside visibles |
| `reset <joueur>` | efface le jour et la semaine du joueur (mémoire et base), ses partenaires de la semaine et ses cadeaux en cours ; la série et les compteurs restent |
| `complete <joueur> <contrat>` | valide un contrat ouvert (recette) |
| `reroll <case>` · `day <décalage>` · `on` / `off` · `status` | retirage du jour, jour simulé, pause, état global |

---

## 2. Dailies du jour

Notation : **titre en jeu** (fixer) · *objectif vérifié* · ce qui change dans la façon de jouer ·
seuil (le calcul est au §8) · **solo** ou **multi** · crochet.

### 2.1 Street (250 €$)

**Ledger's Lucky Number** (Ledger) — **solo**
- *Objectif* : faire finir son solde bancaire par **777** à la suite d'un paiement ; dépôts,
  retraits et virements entre joueurs ne comptent pas.
- *Change le jeu* : on fait ses courses avec une calculette. Il faut viser la bonne somme avec ce
  qu'on achète, vend ou touche (paie, vente de marchandises, plein au litre près).
- *Seuil* : la fin de solde, pas une quantité ; le correctif est le refus des mouvements
  « neutres » (§7).
- *Crochet* : `onMoneyChanged` (`economy.lua:165`), types ignorés `deposit`, `withdraw`,
  `transfer_out`, `transfer_in`.

**Running on Fumes** (Nix) — **solo**
- *Objectif* : faire le plein à la pompe d'une voiture tombée **sous 10 %**, jusqu'à **au moins
  50 %**. Le jerrycan ne compte pas.
- *Change le jeu* : on roule exprès sur la réserve, on surveille la jauge et on choisit sa pompe.
  Croise *Roadside* : la réserve (15 %) déclenche un appel aux mécanos, et un mécano qui verse son
  jerrycan fait rater le contrat. Accepter l'aide ou la refuser est un choix.
- *Crochet* : `onRefuelled` (`refueling.lua:275`), `kind = "vehicle"`, `before / capacity`.

**Nightcap** (Okoro) — **solo**
- *Objectif* : dans les **10 minutes** après une victoire payée en activité (contre des bots,
  la police ou un autre joueur : un contre-la-montre seul ne compte pas), boire un verre dans
  un **bar** (à 25 m d'un bar de la carte).
- *Change le jeu* : la victoire ne se termine plus dans l'écran de file d'attente ; on sort du
  terminal et on traverse la rue pour trinquer. Relie les activités, l'inventaire et la carte.
- *Crochet* : `onActivityResult` (`activity_pay.lua:318`) puis `onItemUsed`
  (`inventory.lua:776`) avec une boisson.

**Nobody Eats Alone** (Okoro) — **multi**
- *Objectif* : finir un repas à **15 m** d'un autre citoyen qui finit le sien dans les **8 s**.
- *Change le jeu* : manger devient un rendez-vous (« à trois, on mord »).
- *Crochet* : `onItemUsed` (`inventory.lua:776`), nourriture.

**Housewarming** (Okoro) — **multi**
- *Objectif* : chez soi (on a la clé), donner une boisson à un invité ; il la boit avant de
  partir.
- *Change le jeu* : le logement sert enfin à recevoir ; l'invité doit rester.
- *Crochet* : `onItemGiven` (nouveau, `inventory.lua:1046` dans `Inv.give`) puis `onItemUsed`
  du côté de l'invité, dans le même logement.

**Ride Along** (Okoro) — **multi**
- *Objectif* : rouler **1,2 km** dans le même véhicule qu'un autre citoyen.
- *Change le jeu* : on propose une place ; conducteur et passager parlent.
- *Seuil* : Job Center → The Crossing.
- *Crochet* : l'échantillonneur (sièges et positions).

**Street Performer** (Nix) — **multi**
- *Objectif* : à The Crossing, tenir une animation **60 s** avec un autre citoyen à **15 m**.
- *Change le jeu* : on se donne en spectacle, et on garde son public.
- *Crochet* : l'échantillonneur (animations, positions).

**The Tour** (Okoro) — **multi**
- *Objectif* : parcourir **750 m** à **15 m** d'un citoyen dans ses **2 premières heures**.
- *Change le jeu* : un ancien accueille un nouveau ; un même nouveau ne compte qu'une fois.
- *Seuil* : The Crossing → Afterlife ; « nouveau » = la fenêtre d'accueil de l'hôpital.
- *Crochet* : l'échantillonneur, `playtimeMs` du personnage.

### 2.2 Action (400 €$, tous **solo**)

**Clean Invoice** (Ledger)
- *Objectif* : abattre la Chimera, à n'importe quelle difficulté, **sans un seul opérateur à
  terre** pendant le combat.
- *Change le jeu* : on joue la défense (couvert, soins) au lieu de la course au DPS. Standard se
  fait seul.
- *Crochet* : `onMissionFinished` (`missions.lua:627`), `inst.report.downs`
  (`mission_chimera.lua`).

**Lose Them, Don't Wait** (Nix)
- *Objectif* : en **NCPD Escape**, atteindre l'**extraction** (pas l'horloge) avec **3 étoiles
  ou plus**, contre la vraie NCPD.
- *Change le jeu* : tenir jusqu'à la fin ne paie plus ; il faut traîner la police à pleine
  chaleur puis sortir au bon moment.
- *Crochet* : `onActivityResult`, statistiques `how`, `stars`, `police`, `policeBlocked`
  (`op77_chase` `P.resultFor`).

**Leg Day** (Nix)
- *Objectif* : en NCPD Escape, choisir **On foot** et s'en sortir (extraction ou horloge), contre
  la vraie NCPD.
- *Change le jeu* : ruelles, escaliers, grillages au lieu de la voiture.
- *Crochet* : `onActivityResult`, `stats.mode == "foot"`, `escaped` (une extraction rapide
  sous le plancher de paie compte, §8).

**Five Without a Dirt Nap** (Nix)
- *Objectif* : une série de **5 kills sans mourir** dans un match d'arène PvE payé.
- *Change le jeu* : on joue sa survie, pas son score.
- *Crochet* : `onActivityResult`, statistique de série du match.

**Support Act** (Okoro)
- *Objectif* : gagner un match d'arène PvE payé avec **plus d'assistances que de kills** (au
  moins une).
- *Change le jeu* : on affaiblit et on laisse le coup final à un coéquipier ou aux alliés bots du
  terminal.
- *Crochet* : `onActivityResult`, `stats.assists`, `stats.kills`, `won`, `eligible`.

### 2.3 Shift (250 €$)

**Full Truck** — Sanitation, Scrapper (Okoro) — **solo**
- *Objectif* : vendre **au moins 11** marchandises en une vente.
- *Change le jeu* : on ne vend plus à chaque sac plein : on transforme, on repart pour un
  deuxième ramassage, et on vend tout d'un coup (le coffre aide à porter, il n'est pas exigé).
- *Crochet* : `onJobWorkCompleted` (`job_work.lua:182`), `info.count`.

**The Full Round** — Sanitation, Scrapper (Okoro) — **solo**
- *Objectif* : collecter aux **deux** sites, puis vendre, sans vente entre les deux (3 étapes).
- *Change le jeu* : on ne refait plus le site le plus proche en boucle.
- *Crochet* : `onJobWorkCompleted`, `info.point`.

**Two Wheels** — Courier (Nix) — **solo**
- *Objectif* : une course Courier entière **à moto** (catégorie `Bikes`).
- *Change le jeu* : on change de véhicule, de trajet (ruelles) et de risque (chute).
- *Crochet* : `onJobRunStarted` / `onJobRunCompleted` (`job_runs.lua:270/315/405`),
  l'échantillonneur (conducteur et catégorie du véhicule).

**Fragile** — Courier (Ledger) — **solo**
- *Objectif* : une course entière dans la même voiture en perdant **au plus 5 %** de sa santé.
- *Change le jeu* : conduite prudente dans le trafic.
- *Crochet* : `onJobRunStarted`, `onJobRunCompleted`, `Open77.vehicles.getHealth`.

**Water Break** — AC Cleaner (Okoro) — **solo**
- *Objectif* : sur une tournée des toits, **boire** entre la première et la dernière unité, puis
  finir la tournée.
- *Change le jeu* : on emporte à boire sur le toit ; relie le métier et l'inventaire.
- *Crochet* : `onJobRunStep` (`job_runs.lua:391`), `onItemUsed`, `onJobRunCompleted`.

**On Call** — Trauma Team (Okoro) — **multi**
- *Objectif* : stabiliser un autre citoyen.
- *Change le jeu* : on écoute les appels et on se déplace vers un blessé.
- *Crochet* : `onPatientStabilized` (`medical.lua:228`) ; le patient est le partenaire.

**Fare Paid** — Taxi (Ledger) — **multi**
- *Objectif* : conduire un passager sur **1,2 km**, puis recevoir **au moins 6 €$** de lui dans
  les **3 minutes**.
- *Change le jeu* : on négocie un prix et on se fait payer à la descente.
- *Crochet* : l'échantillonneur (siège passager, distance) et `onMoneySent`
  (`economy.lua:529` virement, `:559` liquide).

**Roadside Assistance** — Mécano (Okoro) — **multi, sur appel**
- *Objectif* : verser un jerrycan dans la voiture d'un autre citoyen qui est **sur la réserve ou
  à sec**.
- *Change le jeu* : un vrai dépannage. Le contrat n'existe que s'il y a une voiture en panne : la
  réserve (15 %) ou la panne sèche d'un autre compte ouvre un **appel** de 30 minutes ; les mécanos
  non engagés reçoivent « Roadside call: … %.1f km from you. » et le contrat prend leur case. Si la
  voiture est servie ailleurs (pompe ou jerrycan de quelqu'un d'autre), l'appel se ferme et la case
  revient au contrat du métier.
- *Crochet* : `onFuelLow` (`fuel.lua:287`), `onFuelEmpty` (`fuel.lua:148`), `onRefuelled`
  `kind = "pour"`.

**Pit Crew** — Mécano (Ledger) — **multi**
- *Objectif* : remplir à la pompe la voiture d'un autre citoyen (son dernier conducteur) pendant
  qu'il reste à **15 m**, puis être payé **au moins le prix du carburant** par lui.
- *Change le jeu* : un service de station : on fait le plein pour le client et on encaisse.
- *Crochet* : `onRefuelled` `kind = "vehicle"`, l'échantillonneur (`lastDriver`), `onMoneySent`.

---

## 3. Crew (300 €$ chacun, **multi** : un coéquipier en ligne)

**Convoy** (Nix)
- *Objectif* : conduire **sa propre voiture** à **40 m** d'un coéquipier qui conduit la sienne,
  sur **2,4 km**. Un échantillon manqué est pardonné, deux de suite remettent à zéro.
- *Change le jeu* : on roule en formation.

**Back to Back** (Ledger)
- *Objectif* : gagner un match d'arène PvE payé avec un coéquipier, au moins un kill chacun
  (résultats à **120 s** l'un de l'autre, **même instance**, entrées à **30 s** près).
- *Change le jeu* : on couvre son coéquipier au lieu de voler ses kills.

**Bar Crawl** (Okoro)
- *Objectif* : boire avec un coéquipier dans **3 bars de 3 quartiers** en moins d'**une heure**.
- *Change le jeu* : une soirée à travers la ville.

**Album Cover** (Nix)
- *Objectif* : à The Crossing, tout le crew présent joue une animation à **6 m** les uns des
  autres pendant **10 s**.
- *Change le jeu* : on se coordonne pour la photo.

**Nobody Left Behind** (Nix)
- *Objectif* : s'échapper d'un NCPD Escape en crew, **chaque** coéquipier de la partie s'en
  sortant (résultats à 240 s, même instance, entrées à 30 s près).
- *Change le jeu* : on attend et on couvre le plus lent.

---

## 4. Weekly (3 000 €$)

**Two Against the Machine** (Ledger) — **multi**
- *Objectif* : abattre la Chimera en **Hard** avec **exactement deux opérateurs** au début du
  combat, et deux à la fin.
- *Change le jeu* : le raid à son minimum ; chaque rôle compte double.

**All the Way** (Ledger) — **multi**
- *Objectif* : gagner un duel classé payé **à la manche décisive** (1-1, troisième manche).

**Lion's Share** (Ledger) — **multi**
- *Objectif* : être le premier contributeur d'un world boss abattu.

**Both Sides of the Law** (Nix) — **multi**
- *Objectif* : dans un même match Most Wanted payé, faire une arrestation **et** s'en sortir.

**Good Samaritan** (Okoro) — **multi**
- *Objectif* : stabiliser **3 citoyens différents** hors de son crew.

**One-Man Army** (Ledger) — **solo**
- *Objectif* : abattre la Chimera **seul** : un opérateur au début du combat, un à la fin.
- *Change le jeu* : le raid à quatre joué seul en Standard.

**Walk of Shame** (Nix) — **solo**
- *Objectif* : laisser sa voiture tomber à sec à **au moins 1 km** de la station, puis revenir
  avec un jerrycan et la remettre en route (2 étapes).
- *Change le jeu* : on ignore la jauge exprès, puis on marche jusqu'à la pompe et retour, 16 kg
  sur le dos.
- *Crochet* : `onFuelEmpty` (`fuel.lua:148`) avec la distance à la pompe la plus proche, puis
  `onRefuelled` `kind = "pour"` dans le même véhicule.

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
    environ 13 000 €$ de ventes. Ce compteur vit en mémoire : un redémarrage du serveur le remet
    à zéro (au pire 2 000 €$ de plus ce jour-là) ;
  - un coéquipier inactif ne déclenche rien, puisqu'il faut son propre cycle récent ;
  - les sites d'entraînement du tutoriel sont exclus, tout comme le Big Contract, qui a sa
    propre prime.
- **Effet** : J passe de 3 500 à ≈ 4 000 €$/h à deux, toujours sous les missions (1,7 × J).
- `crewBonus.rate = 0` coupe tout.

### 5.2 Le Big Contract (Courier, deux coursiers)

> Okoro : "Wedding in Heywood. Five, six orders, two couriers. And the bride wants everything on the
> table at once: last two drops inside two minutes of each other, or it's cold canapés."

- **Comment ça se joue** :
  - au Job Center, un coursier en crew avec un autre coursier (compte distinct, à moins de 30 m,
    aucun des deux en course) voit l'option **Big Contract · 2 couriers** (ou tape `/job duo`) ;
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
  (`identifier#characterKey`). Les titres gagnés par le compte (série de jours, dailies) vont au
  personnage actif au moment du gain.
- **Un seul titre affiché**, choisi dans F1 → Identity → **Title**, ou dans l'onglet **Titles**
  du panneau Dailies. « No title » est toujours possible.
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
| **Ghost** | 10 extractions avec au moins 3 étoiles en NCPD Escape, contre la vraie NCPD (`police == "ncpd"`, jamais `policeBlocked`), compteur `pve_hot_extractions` | `onActivityResult` | Epic |
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
| **Most Wanted** | 5 kills crédités d'affilée à Dogtown, la série qui met une prime sur la tête | statistiques de `dogtown.lua` (`bestStreak`) | Rare |
| **Bounty Hunter** | Mettre fin à 3 primes de Dogtown | nouvel appel `onDogtownKill` | Epic |
| **Barghest's Problem** | 50 kills crédités à Dogtown | statistiques de `dogtown.lua` (`kills`) | Epic |
| **King of Dogtown** | Meilleur tueur crédité de Dogtown la semaine passée ; la couronne tient jusqu'à la fin de la semaine | table `lightrp_dogtown_stats` | Legendary |

Notes :

- **Les titres Live** se lisent dans le cache du Hall of Fame au moment de l'affichage. Perdre la
  première place cache le titre automatiquement, sans écrire en base, et le reprendre le rend.
- **Les titres PvP** répondent au point 12.6 d'`economy-balance.md` : le joueur 100 % PvP, que la
  réputation ignore, a enfin une piste. Ils ne comptent que des résultats déjà filtrés par
  `activity_pay`, donc pas de bots, pas de farm entre deux comptes au-delà des limites par paire.
- **Les titres de Dogtown** lisent les vraies statistiques de la zone (fusion de
  `lightrp/dogtown-rules`) : uniquement des kills **crédités** (pas le même compte, pas un
  coéquipier, pas la même paire avant le délai de `pairCooldownMs`). *Most Wanted* et
  *Barghest's Problem* lisent `LightRP.dogtown.statsFor` (compteurs à vie du personnage) ;
  *Bounty Hunter* compte un kill crédité sur un joueur qui avait une prime (`onDogtownKill`).
- **King of Dogtown** : chaque lundi, `titles.lua` lit dans `lightrp_dogtown_stats` le premier
  de la semaine écoulée (kills, puis butin, puis morts), saute les comptes exclus du Hall of
  Fame (staff, tests) et lui donne la couronne jusqu'au dimanche 23:59 UTC. Elle s'affiche
  « King of Dogtown · W45 » (semaine ISO de la semaine gagnée). Une semaine sans kill crédité
  ne couronne personne. Il faut la base de données.
- **Les trois titres « drôles »** (*Lucky Seven*, *Crowd Pleaser*, *Fumes Connoisseur*) gardent
  une trace des contrats dont on parle le plus. Ils demandent que le contrat repasse trois fois
  dans la rotation (ou par échange), donc quelques semaines.


---

## 7. Ce qui a été remplacé ou borné (passe du 2026-11-03)

### 7.1 Remplacés

| Ancien contrat | Pourquoi il sort | Remplacé par |
|---|---|---|
| **Still Hot** (Courier : battre l'estimation du dispatch) | « plus vite » | *Two Wheels* |
| **Heat Wave** (AC Cleaner : tournée en moins de 5 min) | « plus vite » | *Water Break* |
| **Billable Hours** (mission avec la moitié du chrono restant) | « plus vite » | *Support Act* |
| **Answer the Phone** (finir un gig de fixer) | « une fois », et aucun gig n'est livré : contrat impossible | *Leg Day* |
| **Before the Overclock** (Chimera avant l'enrage) | « plus vite » | *Clean Invoice* (personne à terre) |
| **Run It Back** (battre son propre temps) | « plus vite » | retiré |
| **Clock In** (sans emploi : se faire embaucher) | « une fois » | le remplaçant Street solo de la case Shift |

Nouveaux contrats solo pour que chaque case ait de quoi jouer seul : *Nightcap* (Street),
*Pit Crew* (mécano, quand la foule est là), *One-Man Army* et *Walk of Shame* (weekly).

### 7.2 Bornés

- **On Call** : tiré seulement quand la foule est là ; le patient est le partenaire (une fois
  par patient et par semaine). Sinon la case Shift d'un Trauma Team reçoit le remplaçant Street.
- **Fare Paid** : idem ; le prix minimum (6 €$) est le coût du carburant de la course (§8).
- **Roadside** : n'existe que sur un appel réel (réserve ou panne sèche d'un autre compte,
  valable 30 min) ; rend la case quand la voiture est servie ailleurs ; votre propre voiture
  n'est pas un appel pour vous.

### 7.3 Gardés, seuils revérifiés

- **Lucky Number** : *bug* — les dépôts et retraits au guichet ou au distributeur déplacent
  n'importe quelle somme n'importe où, donc le contrat était gratuit. Ils sont ignorés, comme
  les virements entre joueurs (un complice aurait fait la même chose).
- **Full Truck** : *bug* — 20 marchandises, c'est exactement un sac plein de produits finis
  (40 kg ÷ 2 kg) : la moindre autre chose dans le sac rendait le contrat impossible. Le seuil
  passe à 11, plus qu'un sac de ramassage (10), ce qui prouve un deuxième ramassage avant la
  vente. Le texte ne promet plus le coffre : la transformation divise le poids par deux, donc le
  sac seul suffit à deux ramassages (relevé par le test de flux des métiers).
- **Two Against the Machine** (et le titre **Two-Man Army**) : *bug* — un raid à trois dont un
  opérateur partait avant la mort de la Chimera finissait avec deux membres et comptait. Les
  opérateurs sont désormais comptés au début du combat (`report.operators`). Le contrat est en
  plus **Hard seulement** : Critical demande au moins 4 joueurs.
- **Back to Back** : *bug* — deux victoires de coéquipiers dans deux matchs différents à moins de
  120 s comptaient ; il faut maintenant le même match (entrées à 30 s près).
- **Bugs trouvés par les tests de flux** (modules producteurs réels), tous corrigés :
  - *Lucky Number* : le remboursement d'un virement échoué (montant 0, type `refund`) validait
    le contrat sans paiement → `refund` ignoré, et un mouvement nul ne compte jamais ;
  - *Nobody Eats Alone*, *Bar Crawl*, *Housewarming*, *Nightcap*, *Water Break* : manger et boire
    se lisaient sur les statistiques de l'objet, donc un soda comptait comme repas et une pomme
    comme verre → on lit ce que fait le joueur (`consumeAction` : bouteille ou canette = boire,
    repas ou en-cas = manger) ;
  - *Housewarming* : sortir et rentrer en moins de 5 s gardait le cadeau → le cadeau est lié à
    la visite (nouvelle session de logement à chaque entrée) ;
  - *Pit Crew* : la distance du client n'était vérifiée qu'à la fin du plein → elle l'est sur
    toute la durée du remplissage ;
  - *Two Against the Machine* : la règle du partenaire n'était pas appliquée (même binôme deux
    fois dans la semaine, ou deux personnages d'un même compte) → l'autre opérateur est le
    partenaire ;
  - *Fragile* : seul le siège avant gauche comptait comme conducteur → même règle que *Two
    Wheels* (le conducteur rendu par le moteur) ;
  - *Back to Back*, *Nobody Left Behind* : « le même match » ne se jugeait qu'à l'heure d'entrée ;
    deux coéquipiers gagnant chacun **son** match d'arène, lancés dans la même seconde,
    validaient → il faut aussi la même instance (bucket de routage au moment du résultat,
    comme le roster d'`activity_pay`) ;
  - *Nightcap* : finir un contre-la-montre seul (`won = true` pour tout essai fini,
    `op77_race engine.lua` `sendResult`, payé en PvP à un joueur) ouvrait la fenêtre → il faut
    une victoire PvE, ou PvP avec au moins deux joueurs ;
  - *Lose Them*, *Leg Day*, *Nobody Left Behind* : en Standard l'extraction s'ouvre à 40 s et
    se trouve à 450 m au plus près en voiture, donc une vraie extraction tombe souvent avant le
    plancher de paie de 60 s (`too_short`) et ne comptait pas — un coéquipier rapide faisait
    même rater tout le crew → une extraction NCPD réelle compte même sous ce plancher (non
    payée par l'activité, payée par le contrat).
- **Street Performer**, **Running on Fumes**, **Album Cover**, **Bar Crawl**, **Convoy**,
  **Fragile**, les weeklies : seuils recalculés au §8 ; *Fragile* garde 5 %, valeur à confirmer
  par une mesure en jeu (§10).

---

## 8. Mesures et arithmétique des seuils

### 8.1 Faits mesurés

| Fait | Valeur | Source |
|---|---|---|
| Consommation | 1,1 L/km en roulant, 0,6 L/min au ralenti | `shared/config.lua` `fuel` |
| Réserve | 15 % du réservoir (`onFuelLow`) | `shared/config.lua`, `fuel.lua:287` |
| Réservoirs | défaut 60 L, Street 55, Utility 90, Sport 65, Bikes 30 | `fuel.tanks` |
| Carburant | 4 €$/L, 1,2 L/s à la pompe | `fuel.pricePerLitre`, débit |
| Jerrycan | 20 L, 16 kg plein, 25 €$ de consigne | `shared/config.lua` |
| Station | une seule, 12 pompes autour de (−594, −711) | `fuel.stations` |
| Location | réservoir de départ entre 35 et 75 %, 30 min | `shared/config.lua` `rentals` |
| Voix | 4 m (chuchoter), 15 m (normal), 40 m (crier) | `shared/config.lua` `voice` |
| Nouveau joueur | 120 premières minutes | `LightRpEconomy.hospital.graceMinutes` |
| Sac / coffre | 40 kg et 30 cases / 80 kg | `shared/config.lua` `inventory` |
| Sanitation | sac poubelle 4 kg → 1 recyclable de 2 kg | `job_work.lua` |
| Scrapper | 4 ferrailles de 1 kg → 1 pièce de 2 kg | `job_work.lua` |
| Distances | Job Center → The Crossing 1 195 m ; The Crossing → Afterlife 743 m ; The Crossing → bar Ho-Oh 636 m ; plus court tour de 3 bars dans 3 quartiers 1 173 m | coordonnées de `mapPlaces` |
| Arène PvE | 3 bots pour le premier joueur, +2 par joueur, 10 au plus ; alliés bots sur les places libres (6 joueurs) ; assistance = 30 % de la vie d'un bot | `op77_arena/shared/lightrp.lua`, `scoring.lua` |
| Chimera | Standard 1 à 4 joueurs, Hard 2 à 6, Critical 4 à 8 | `server/config/missions.lua` |
| NCPD Escape | avance de 6 s en voiture, 8 s à pied | `op77_chase` |
| Duel | au meilleur des trois manches | `op77_arena/shared/lightrp.lua` |
| Échantillonnage | toutes les 5 s, 70 m/s au plus | `server/config/dailies.lua` |
| Prix les plus bas | bonbon 9 €$ à l'achat, revendu 1 €$ ; eau 12 / 2 €$ | `server/config/shops.lua` |

### 8.2 Le calcul, contrat par contrat

- **Lucky Number** : le pas le plus fin vaut 1 €$ (revendre un bonbon), l'achat le moins cher
  9 €$, le carburant 4 €$ le litre. Toute fin de solde est atteignable ; l'écart à 777 vaut au
  plus 999 €$ dans un sens, et le joueur choisit le sens (attendre sa paie ou une vente, ou
  dépenser), donc au plus ≈ 500 €$ d'achats ou de ventes réels. Rien n'est gratuit : chaque pas
  est un vrai paiement.
- **Running on Fumes** : une moto de location (30 L, départ 10,5 à 22,5 L) doit brûler 7,5 à
  19,5 L pour passer sous 3 L, soit **6,8 à 17,7 km** ; une Street (55 L, départ 19,3 à 41,3 L)
  **12,5 à 32,5 km**. Le plein jusqu'à 50 % coûte au moins 12 L (48 €$, 10 s) pour la moto, 22 L
  (88 €$, 18 s) pour la Street. Faisable dans les 30 min d'une location, ou avec sa propre voiture
  au fil de la journée. La réserve (15 %) prévient avant les 10 %.
- **Nightcap** : la sortie d'une activité ramène à The Crossing ; le bar le plus proche est à
  636 m. 10 minutes laissent le temps d'y aller à pied ou en voiture et d'acheter à boire, pas
  celui d'enchaîner un deuxième match.
- **Nobody Eats Alone** : 15 m = la portée de la voix normale ; 8 s = assez pour « à trois », pas
  pour deux repas sans rapport.
- **Ride Along** : 1 200 m ≥ Job Center → The Crossing (1 195 m), le trajet que fait tout nouveau.
- **Street Performer** : 60 s = 12 échantillons ; public à 15 m (voix normale).
- **The Tour** : 750 m ≥ The Crossing → Afterlife (743 m) ; 15 m pour rester ensemble ; la
  fenêtre de 120 min est celle de l'accueil à l'hôpital.
- **Clean Invoice** / **One-Man Army** : Standard accepte un joueur, donc les deux se font seul.
- **Lose Them, Don't Wait** : en Standard, 3 étoiles est le plafond, atteint 75 s après l'avance
  (81 s après le GO en voiture), avant la fin des 150 s : il faut tenir la pleine chaleur puis
  rejoindre l'extraction. En Hard (3 étoiles à 30 s) et Critical (25 s), l'extraction n'apparaît
  qu'après (55 et 70 s), donc toute extraction compte. Jouable au palier I.
- **Extraction rapide** : l'extraction s'ouvre à 40 s (Standard), 55 s (Hard), 70 s (Critical),
  tirée entre 450 et 1 300 m en voiture (200 à 500 m à pied). À 30 m/s, 450 m prennent 15 s :
  arrivée à **55 s**, sous le plancher de 60 s d'`activity_pay` (`too_short`). Une extraction
  réelle compte donc pour *Lose Them*, *Leg Day* et *Nobody Left Behind* même non payée par
  l'activité ; l'horloge (150 s et plus) passe toujours le plancher. L'extraction ne peut pas
  être plus précoce que son ouverture, fixée côté serveur par `op77_chase`.
- **Leg Day** : l'avance à pied (8 s) compense la voiture (6 s) ; le mode est choisi par le
  joueur au lancement.
- **Five Without a Dirt Nap** : seul, l'arène PvE aligne 3 bots ; une série de 5 oblige à survivre
  à leur réapparition, donc à changer de position au lieu de camper le spawn.
- **Support Act** : une assistance demande 30 % de la vie d'un bot puis le coup final d'un autre ;
  seul, les alliés bots du terminal (places libres, toujours classé) le rendent faisable.
- **Full Truck** : un sac (40 kg) porte 10 sacs poubelle (4 kg) ou 40 ferrailles (1 kg) → **10**
  marchandises. 11 en une vente prouve un second ramassage avant la vente : après transformation
  les 10 produits ne pèsent plus que 20 kg, il reste 20 kg pour repartir (ou le coffre, 80 kg).
  Le maximum d'une vente est 20 (40 kg ÷ 2 kg de produits finis), d'où l'ancien seuil impossible.
- **The Full Round** : 3 étapes = site A, site B, vente ; une vente avant les deux sites remet à
  zéro.
- **Water Break** : la route AC Cleaner a 3 unités (`lift`, 3 × `work`, `return`) : la fenêtre va
  de la première à la troisième ; le contrat n'est tiré que si la route a au moins 2 unités.
- **Fare Paid** : 1,2 km × 1,1 L/km = 1,32 L × 4 €$ = 5,28 €$ → **6 €$** couvre le carburant. 3 min
  pour payer à la descente.
- **Roadside** : à 15 %, une Street a 8,25 L, soit 7,5 km avant la panne : l'appel arrive avant la
  panne, et l'appel vit 30 min. Un jerrycan (20 L, 80 €$ de carburant plus 25 €$ de consigne,
  16 kg dans un sac de 40 kg) remonte une Street de 15 à 51 %.
- **Pit Crew** : dû = ⌈litres × 4 €$⌉, par exemple 30 L → 120 €$ ; 15 m = voix normale. Le client
  reste à portée **pendant tout le plein** : chaque échantillon de la durée du remplissage
  (litres ÷ 1,2 L/s, au moins 5 s) doit l'avoir à moins de 15 m, et la fin aussi.
- **Convoy** : 2,4 km à 40 m (la voix criée) ; un échantillon raté pardonné.
- **Back to Back** : résultats à 120 s, même instance et entrées à 30 s près (chaque match
  d'arène PvE a son bucket de routage).
- **Bar Crawl** : le plus court tour de 3 bars dans 3 quartiers fait 1 173 m ; une heure laisse le
  trajet et trois verres ; les deux boivent dans le même bar (25 m).
- **Album Cover** : 10 s = 3 échantillons consécutifs ; 6 m = tout le monde dans le cadre.
- **Nobody Left Behind** : résultats à 240 s (le temps de la dernière manche), même partie à 30 s.
- **Two Against the Machine** : Hard accepte 2 à 6 joueurs : deux, c'est le minimum ; Critical
  (4 minimum) exclu.
- **All the Way** : au meilleur des trois, la manche décisive est la troisième à 1-1.
- **Walk of Shame** : 1 km de la seule station, puis 2 km à pied aller-retour avec 16 kg ; le
  jerrycan coûte 80 €$ de carburant et 25 €$ de consigne. Vider une Street pleine demande 50 km de route (ou 92 min de ralenti),
  d'où un weekly qu'on prépare dans la semaine.

---

## 9. Écarts volontaires avec la proposition validée

- **Récompenses modulées** : 250 / 400 / 250 au lieu de 300 partout ; crew 300, weekly 3 000.
- **« Réanimer un citoyen »** devient *On Call* (Trauma Team) et *Good Samaritan* (weekly).
- **Objectifs génériques écartés** (« 2 courses Courier », « finir une mission en crew »), et
  depuis cette passe tout ce qui demandait « plus vite », « plus » ou « une fois » (§7).
- **Panneau** : F1 → Dailies a son propre panneau, et l'onglet **DAILIES** du terminal des
  activités montre la même page. L'onglet « Contracts » du terminal reste celui des tableaux de
  missions.
- **Crochet `onActivityResult`** : dans `activity_pay.lua`, juste après le verdict.
- **NCPD Escape contre la vraie NCPD** : semer la police n'est plus visible du serveur ; *Lose
  Them* et **Ghost** demandent l'extraction avec au moins 3 étoiles.

## 10. Questions au propriétaire

1. **Foule** : `social.minAccounts = 4` comptes distincts en ligne pour tirer un contrat social.
   Le bon chiffre pour vos heures creuses ?
2. **Plafond** : `dailyBudget` à 1 200 €$ par compte ; faut-il 900 €$ ?
3. **Titres** : cacher son titre en le gardant ? Pour l'instant « No title » suffit.
4. **King of Dogtown** : suffixe « W45 » ou une date ?
5. **Fragile** : 5 % de santé perdue sur une course reste à confirmer en jeu (relever la perte
   d'une course propre, §2 de la recette).
6. **Plafond de paie** : un résultat qui ouvre droit à la paie compte même quand le plafond PvE
   ou PvP du jour est atteint (payé 0) ou que la paie d'activité est coupée. C'est voulu (les
   dailies ont leur budget) ; préférez-vous l'inverse ?
7. **On Call** : un coéquipier soigné compte (une fois par semaine, règle du partenaire), alors
   que *Good Samaritan* exclut le crew. L'exclure aussi ?

## 11. Crochets et preuves

Toute la logique vit dans `dailies.lua`, `titles.lua` et `job_crew.lua` ; les fichiers partagés
ne reçoivent qu'un appel d'une ligne. Chaque crochet ci-dessous a été retrouvé à son site
d'appel réel :

| Fichier:ligne | Crochet | Sert à |
|---|---|---|
| `economy.lua:165` | `onMoneyChanged(id, wallet, delta, balance, kind)` | *Lucky Number* |
| `economy.lua:529` / `:559` | `onMoneySent(from, to, amount, "transfer" \| "cash")` | *Fare Paid*, *Pit Crew* |
| `inventory.lua:776` | `onItemUsed(id, name, item)` | *Nobody Eats Alone*, *Housewarming*, *Bar Crawl*, *Nightcap*, *Water Break* |
| `inventory.lua:1046` | `onItemGiven(from, to, name, count)` (**nouveau**, `Inv.give`) | *Housewarming* |
| `refueling.lua:275` | `onRefuelled(id, { kind, vehicle, litres, before, capacity })` | *Running on Fumes*, *Roadside*, *Pit Crew*, *Walk of Shame* |
| `fuel.lua:287` / `:148` | `onFuelLow(vehicle, driver)` / `onFuelEmpty(vehicle, driver)` | appels *Roadside*, *Walk of Shame* |
| `activity_pay.lua:318` | `onActivityResult(id, entry, r, raw, verdict)` | Action, crew d'activité, *Nightcap*, weeklies d'activité |
| `missions.lua:627` | `onMissionFinished(inst, point, d, success, why, payouts)` | Chimera (contrats et titres) |
| `mission_chimera.lua` | `raid.operators` au début du combat, `inst.report = { enraged, downs, operators }` | *Clean Invoice*, *One-Man Army*, *Two Against the Machine*, titres |
| `world_bosses.lua:349` | `onWorldEventEnded(ev, success)` | *Lion's Share* |
| `medical.lua:228` | `onPatientStabilized(actor, patient)` | *On Call*, *Good Samaritan* |
| `job_work.lua:182` / `:187` / `:191` | `onJobWorkCompleted(id, job, kind, info)` | *Full Truck*, *The Full Round* |
| `job_runs.lua:270` / `:315` | `onJobRunStarted(id, run)` | *Two Wheels*, *Fragile* |
| `job_runs.lua:391` | `onJobRunStep(id, run, step)` | *Water Break* |
| `job_runs.lua:405` | `onJobRunCompleted(id, run)` | *Two Wheels*, *Fragile*, *Water Break* |
| `jobs.lua:89` | `onJobChanged(id, job, previous)` | case Shift |
| `parties.lua`, `chat.lua`, `halloffame.lua` | `title` / `titleRarity` | affichage des titres |

Côté page (`ui/`) : `features/dailies/` (modèle, panneau, `DailiesToday` pour le terminal,
maquette), `features/activities/ActivitiesDialog.tsx` (onglet DAILIES), `bridge/protocol.ts`
(`crewLocked`, `social`, `dailies.refresh`, onglet `dailies`), `features/menu/PlayerMenu.tsx`
(F1 → **Dailies**). Le paquet `web/` se régénère par `npm run build` dans `ui/`.

**Preuves automatiques** (`tests/`, lancées par `tests/run-lua.ps1`) :

- `dailies_test.lua` : rotation, remplaçants solo, porte sociale (relock, pas de va-et-vient),
  appel Roadside, règle du partenaire, contrats de l'échantillonneur, encaissements, échange,
  outils du staff, aller-retour en base, nom « Dailies » des notices ;
- `titles_test.lua` : dont le raid à trois avec un départ (pas de Two-Man Army) ;
- `dailies_flow_*_test.lua` : chaque contrat alimenté par un autre module, piloté **par le vrai
  module producteur**, seuls les natifs étant simulés, avec les cas d'échec et un cas de
  régression par bug trouvé :
  - `dailies_flow_street_test.lua` : économie, inventaire et consommables, logement, carburant,
    pompe et jerrycan (*Lucky Number*, *Nobody Eats Alone*, *Housewarming*, *Bar Crawl*,
    *Running on Fumes*, *Roadside*, *Pit Crew*, *Fare Paid*, *Walk of Shame*) ;
  - `dailies_flow_missions_test.lua` : vrai raid Chimera, du tableau à la victoire (*Clean
    Invoice*, *One-Man Army*, *Two Against the Machine* et sa règle du partenaire) ;
  - `dailies_flow_jobs_test.lua` : `job_work` et `job_runs` (*Full Truck*, *The Full Round*,
    *Two Wheels*, *Fragile*, *Water Break*) ;
  - `dailies_flow_activities_test.lua` : `activities.lua` et `activity_pay.lua` avec les charges
    exactes d'`op77_chase`, `op77_arena` et `op77_race`, world boss et médical (*Lose Them*,
    *Leg Day*, *Five Without a Dirt Nap*, *Support Act*, *Nightcap*, *Back to Back*, *Nobody
    Left Behind*, *All the Way*, *Both Sides*, *Lion's Share*, *On Call*, *Good Samaritan*) ;
  - les contrats de l'échantillonneur (*Street Performer*, *The Tour*, *Ride Along*, *Convoy*,
    *Album Cover*) n'ont pas d'autre producteur que les positions, sièges et animations lus
    par `dailies.lua` lui-même : ils sont dans `dailies_test.lua`.
- `guide_test.lua`, `guide_dialogue_test.lua` : la FAQ `money.dailies` (F1 → Dailies, onglet
  Dailies du panneau Activities, ce que paie chaque case, remise à zéro) et le choix de Johnny
  sous « How do I make money? ».
