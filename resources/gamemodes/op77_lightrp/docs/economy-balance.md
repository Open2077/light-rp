# Équilibrage de l'économie (ouverture publique)

Monnaie : eddies (€$). Tous les chiffres ci-dessous sont dans des fichiers de
configuration ; le code ne porte que les règles (partage du pot, recharge, plafonds,
factures, paie des activités). Les décisions du propriétaire du 2026-11-03 (D1 à D7)
sont appliquées sur la branche `lightrp/economy-balance` ; ce qui reste à trancher est
au §12.

## 1. Constat de départ (branche `lightrp/activities`, avant équilibrage)

**Revenus horaires mesurés** (simulation sur les vraies coordonnées des points ;
hypothèses : voiture avec coffre, 50 à 70 km/h de moyenne, route réelle = 1,35 × la
ligne droite, 1 min par arrêt de livraison, 3 min de manutention par boucle) :

| Source | Avant | Détail |
| --- | --- | --- |
| Sanitation | 1 800 – 2 100 €$/h | 30 sacs (sac 40 kg + coffre 80 kg) × 18 €$, boucle 6 km |
| Scrapper | 1 700 – 2 200 €$/h | 30 lots × 24 €$, boucle 8 à 9,6 km |
| Courier | 2 300 – 2 900 €$/h | 748 €$ en moyenne par course de 7,5 km (vol d'oiseau), **39 % des courses butent sur le plafond de 900** |
| Toit (AC Cleaner, hérité) | ~2 400 €$/h | 260 €$ pour 5 à 8 min |
| Paie | 80 – 220 €$/h | 40 à 110 €$ toutes les 30 min, versée à tout joueur connecté (même immobile) |
| Mission Chimera standard | **43 000 €$/h par tête** | 18 000 €$ pour 20 min, faisable seul, **versés en entier à chaque membre**, sans recharge |
| Braquage Sector 04 critique | 40 000 €$ × 8 = **320 000 €$ créés** par partie | idem |
| Gigs de fixers | 8 000 / 15 000 / 30 000 €$ par tête | 15 à 20 min, valeurs par défaut de l'éditeur |
| Activités (arène, courses, poursuites, turf) | 0 €$ | réputation seulement |

Une Chimera standard valait 6 à 9 h de travail ; une équipe de 4 créait 72 000 €$ en
20 min. Les achats (voitures 4 000 – 60 000, cyberware 6 000 – 64 000, armes 1 200 –
10 500) étaient épuisés après quelques missions, et il n'existait presque aucune
dépense récurrente : l'argent s'accumulait puis ne valait plus rien.

**Dépenses récurrentes vérifiées** : nourriture et boisson ≈ 33 €$/h, carburant 3 €$/L
(1,1 L/km, ≈ 200 €$/h au volant), location 50 – 100 €$ par 30 min, fourrière 150 – 250 €$,
peinture 1 000 €$. Gratuits : l'hôpital, la cabine d'essayage. Les kits de réanimation
(`trauma_kit`) n'étaient vendus nulle part.

## 2. Courbe cible (décisions D1 du 2026-11-03)

Référence : **J = 3 500 €$/h** pour un joueur actif au grade d'entrée, avec voiture
(≈ 3 400 €$/h nets de carburant, nourriture et frais).

| Objectif du propriétaire | Cible | Résultat (joueur régulier, §7) |
| --- | --- | --- |
| Pas trop facile de maxer le cyberware ni d'avoir les meilleures voitures | — | voir les lignes suivantes |
| Première voiture correcte (10 000 – 15 000) | ≈ 3 – 5 h | Hella 12 000 à 2,5 h, Colby 14 000 à 2,9 h, Supron 16 000 vers 3,5 h |
| Meilleures voitures | ≈ 20 – 30 h | Kusanagi 80 000 à 18,8 h, Semimaru 100 000 à 23,7 h |
| Set complet rang V+ | ≈ 60 – 90 h | 330 000 €$ (prix proposés, §9) : 80,3 h d'épargne |
| Loadout complet haut de gamme | coûte plus que ce qu'on gagne en atteignant Legend | 557 000 €$ contre 197 000 €$ gagnés à Legend (48 h) |
| Missions | ne doivent pas écraser les métiers | 1,7 à 1,8 × J par heure dans les 6 paies pleines, puis 0,44 × J |
| Plafond 250 €$/min | tenu | missions 220 €$/min au plus, activités 87,5 €$/min au plus |
| Activités PvP classées | joueur moyen ≈ J, bon joueur un peu plus | 0,91 × J (moyen), 1,04 × J (bon), plafond journalier |
| Activités PvE | modestes, sous les missions | 0,48 à 0,60 × J, 0,27 à 0,36 × missions |
| Premier jour | gratuit / abordable | studio gratuit, tutoriel inchangé, hôpital et cabine offerts les 120 premières minutes de jeu |

## 3. Missions et gigs (`server/config/economy.lua` → `missions`, D2 et D3)

1. **`payout` change de sens** : c'est la part **de chaque opérateur à l'équipage
   minimum** de la difficulté (ce que le tableau affiche reste donc un maximum honnête).
2. **Pot sous-linéaire, partagé** : au-delà du minimum, la part vaut
   `payout × (équipage / minimum) ^ (exposant − 1)`, exposant **0,7**. Le pot total
   grandit comme `équipage ^ 0,7` au lieu de `équipage` : 4 opérateurs créent 2,64 parts,
   pas 4. L'équipage compté est celui qui termine.

   | Équipage / minimum | 1 | 1,5 | 2 | 3 | 4 | 6 | 8 |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | Part par tête | 100 % | 88,5 % | 81 % | 72 % | 66 % | 58 % | 54 % |
   | Pot total (en parts) | 1 | 1,33 | 1,62 | 2,16 | 2,64 | 3,51 | 4,29 |

3. **Recharge par personnage et par point (D3)** : après une paie pleine, le même point
   de mission (tableau ou gig) ne repaie en entier qu'après **60 min**.
4. **Plafond journalier par compte (D2, D3)** : **6 paies pleines** par jour UTC, tous
   personnages du compte confondus (`capScope = "account"`).
5. **Au-delà** : la mission paie **25 %** de la part. Aider ses amis reste payé, farmer
   ne l'est plus. La réputation reste entière (et suit le palier de chacun : un équipier
   sous le palier gagne la réputation de son palier, `docs/pve-progression.md`).
6. **Garde-fou** : une part ne dépasse jamais **250 €$ par minute d'horloge** de la
   difficulté.
7. **Annonce** : au lancement, chaque opérateur reçoit sa paie attendue (et la raison
   d'une réduction) ; à la fin, l'avis donne le montant, l'équipage et la réduction.

**Missions de l'éditeur déjà enregistrées** : `/lightrp.missions.repay` (aperçu) puis
`/lightrp.missions.repay apply` (staff, ACL `command.lightrp.missions.repay`). Une
difficulté dont la paie dépasse le garde-fou (250 €$ × ses minutes) est à l'ancienne
échelle : elle est multipliée par nouveau / ancien défaut de sa difficulté (8 000 →
2 400, 15 000 → 3 000, 30 000 → 4 400), arrondie à 50 et gardée sous le garde-fou ;
une paie déjà sous le garde-fou reste celle du staff. Chaque mission est réécrite avec
contrôle de révision (une mission éditée entre-temps est sautée, jamais écrasée) puis
republiée, donc son tableau affiche le nouveau montant. Relancer ne change rien.

## 4. Paie des métiers : seulement aux joueurs actifs (D4)

`server/modules/work_activity.lua`, `economy.lua` → `paychecks`. Light RP n'a pas de
prise de service : **être en service = avoir un métier salarié**. La paie de grade
(toutes les 30 min) n'est versée qu'à un joueur qui a fait quelque chose de réel dans les
**30 dernières minutes**, d'après ce que le serveur voit lui-même, jamais une
déclaration du client :

- une tâche du métier : un lot de travail libre (`onJobWorkCompleted`), un ordre de
  travail accepté (`onJobRunStarted`) ou payé (`job_run`) ;
- un patient stabilisé au kit (`onPatientStabilized`, nouveau crochet de `medical.lua`) ;
- un virement reçu d'un autre joueur d'au moins **50 €$** (un client servi) ;
- **75 m** parcourus en ville : positions relevées par le serveur toutes les 20 s, en
  bucket 0, vivant, hors activité et hors mission ; un saut de plus de 2 km (téléport,
  retour d'activité) ne compte pas, il réancre la mesure.

Un joueur inactif ne touche rien ; il en est averti **une fois** par période
d'inactivité (notice « No paycheck ») et le serveur le journalise. Tout est réglable ;
`requireActivity = false` rétablit l'ancienne règle.

## 5. Activités : paie en eddies (exigence du 2026-11-03)

`server/modules/activity_pay.lua`, `economy.lua` → `activities`. Le noyau
(`activities.lua`) lui passe chaque résultat accepté en **une ligne**, après avoir écarté
le mode bots du staff et les résultats `test`.

**PvP classé** (`arena.ffa`, `arena.blade`, `arena.teams`, `arena.duel`, `race.trial`,
`race.grid`, `race.foot`, `chase.1v1`, `chase.wanted`, `turf.war`) :

```
paie = 70 €$ × taux du mode × minutes jouées (≤ maxSeconds du mode)
       × min(1, joueurs réels / lobby plein du mode)
       × (0,75 participation + 0,5 × résultat)
```

- **Résultat** : 1 pour une victoire ou la première place, jusqu'à 0 pour la dernière
  place (modes à classement : `(n − place) / (n − 1)`), 0,5 pour un nul, 0 pour une
  défaite ; un contre-la-montre (`race.trial`, taux 0,5, solo) score un record personnel
  ou de piste.
- **Joueurs réels** : comptes que le serveur a vus dans la même activité et le même
  bucket pendant le match (relevé toutes les 10 s et au résultat). Jamais un nombre
  envoyé par le fournisseur ou le client. Lobby plein : 4 (FFA, blade, équipes, courses,
  wanted), 2 (duel, 1v1), 6 (turf), 1 (contre-la-montre).
- **Minutes jouées** : la mesure du fournisseur (`durationMs`, `timeMs`, `seconds`),
  jamais plus que ce que le noyau a vu depuis l'entrée ou le résultat précédent.
- Joueur moyen ≈ 3 360 €$/h bruts de match (80 % de l'heure en match), bon joueur
  ≈ 3 860, gagnant de tout 4 200.

**PvE** (`arena.pve`, `race.pve`, `chase.pve`, `turf.pve`) : **40 / 50 / 60 €$ par
minute** en Standard / Hard / Critical, la moitié sur une défaite. La difficulté est
celle de l'entrée (choisie au panneau, `docs/pve-progression.md`), sinon celle du
résultat, sinon celle du mode (Standard pour l'arène et la course, Hard pour l'évasion
et le turf). Les bots y sont les adversaires : ils n'annulent rien.

**Rien** pour :

- un résultat non classé : mode bots du staff et `result.test` (écartés par le noyau),
  `result.unranked = true`, un match PvP avec des bots (`stats.bots`, `vsAi`) ;
- un départ : `stats.quit`, `stats.forfeit` (celui qui reste quand l'autre abandonne
  garde la seule part de participation), une course abandonnée (`dnfReason` `left`,
  `dropped`, `disconnect`) ;
- un AFK : aucune des statistiques de progression du mode (kill ou assist en arène,
  manche gagnée en duel / 1v1, points en wanted, capture, kill ou 30 s de tenue en turf,
  arrivée ou 2 checkpoints en course, fuite ou semée en évasion) ;
- un match plus court que le minimum du mode (1 à 3 min) ;
- un match dont **tous les joueurs réels sont du même crew**.

**Anti-farm** : les mêmes comptes ne sont payés ensemble que **4 / 3 / 4 / 5 fois par
heure** (ensembles de 1 / 2 / 3 / 4 comptes ; au-delà, pas de limite), avec une notice
quand la limite tombe. **Plafond journalier par compte** (tous personnages) : **12 000 €$
en PvP, 6 000 €$ en PvE** par jour UTC, en base (`lightrp_activity_pay_daily`), avec une
notice une fois atteint.

Chaque paie passe par `LightRP.money.addBank` avec la ligne `activity_pvp` ou
`activity_pve` et une notice « +€$ N — Combat Zone · #1 of 4 · 10 min ».

## 6. Dépenses récurrentes

| Dépense | Règle | Montant |
| --- | --- | --- |
| **Facture d'hôpital** | uniquement « Give up and go to hospital » ; jamais sur une réanimation, en mission ou en activité, ni pendant le premier jour et les 120 premières minutes ; banque puis liquide, **jamais en négatif** | **300 €$** |
| **Cabine d'essayage** (D7) | une visite d'une cabine publique qui se termine par un look enregistré ; logement, création, premier jour et 120 premières minutes gratuits ; offerte si le joueur ne peut pas payer | **50 €$** |
| **Kit de réanimation** (D5) | vendu au Corner Market (`street_food`), non repris ; réanime un allié à terre, jamais soi-même ; moins cher que la facture d'hôpital | **250 €$** |
| **Fourrière** (D6) | **épave** (détruite, explosée ou santé 0 : drapeaux du moteur, événement de dégâts ou propriétés capturées), au redémarrage, au retrait ou à l'envoi par le propriétaire : franchise d'assurance, l'assurance la répare. **Perdu sans trace** (supprimé, nettoyé, perdu sur un bug) : 150. Envoi par le propriétaire d'un véhicule intact : 250. Staff : 500. Redémarrage d'un véhicule intact : gratuit. Une épave ne peut pas être garée. | **400 / 150 / 250 / 500** |
| Carburant | 1,1 L/km : ≈ 260 €$/h au volant | 4 €$/L |
| Nourriture | +50 % : ≈ 50 €$/h, 1,5 % du revenu | 9 – 36 €$ |

D6, limite connue : un véhicule qui explose puis disparaît **sans qu'aucun signal de
dégâts ne soit parvenu au serveur** (ni mise à jour, ni événement, ni propriétés
capturées) ne peut pas être distingué d'un véhicule perdu : il est facturé **150**.

## 7. Rythme de progression (pacing)

Modèle : `pacing` du 2026-11-03, heures **de jeu**. Hypothèses : argent net de 8 % de
frais courants ; départ 1 750 €$ ; métier 3 700 €$/h bruts (paie active comprise) ;
missions : Chimera, Sector 04 et gigs mêlés, équipage moyen 1,5 × le minimum, réussite
85 / 70 / 55 %, une réussite prend 70 % de l'horloge plus l'approche ; activités : 80 %
de l'heure en match, PvE gagné à 85 / 70 / 55 % selon la difficulté. Réputation (règles
de `docs/pve-progression.md`) : 180 / 280 / 375 par heure de PvE (missions et activités
PvE), activités PvE plafonnées à 500 par jour, **aucune réputation en PvP**. Le joueur
choisit la plus haute difficulté ouverte. Les colonnes « épargne » supposent qu'il
n'achète rien d'autre ; le parcours cumulé achète dans l'ordre.

Profils :

- **Régulier** : 2,5 h/jour = 1 h de missions, 0,5 h d'activités PvE, 1 h de métier
  (≈ 4 100 €$/h).
- **Grinder** : 6 h/jour = missions jusqu'aux 6 paies pleines, 0,5 h de PvE, métier
  ensuite (≈ 5 300 €$/h).
- **PvP** : 2,5 h/jour de PvP classé, joueur moyen ≈ 3 090 €$/h (bon joueur ≈ 3 560 entre
  parenthèses).
- **PvE** : 2,5 h/jour d'activités PvE seulement (≈ 1 850 à 2 030 €$/h selon le palier).

### 7.1 Voitures et paliers

| Heures de jeu jusqu'à… | Régulier | Grinder | PvP (bon) | PvE |
| --- | --- | --- | --- | --- |
| Hella 12 000 | 2,5 | 1,7 | 3,3 (2,9) | 5,8 |
| Colby 14 000 (première voiture correcte) | 2,9 | 2,1 | 4,0 (3,5) | 6,9 |
| Kusanagi 80 000 | 18,8 | 15,1 | 25,3 (22,0) | 39,1 |
| Semimaru 100 000 (meilleure voiture) | 23,7 | 18,9 | 31,8 (27,6) | 48,8 |
| Palier II (500) : rang III | 3,8 | 2,8 | jamais | 2,8 |
| Palier III (1 500) : rang IV | 10,4 | 8,5 | jamais | 7,7 |
| Palier IV (4 000) : rang V | 21,0 | 15,1 | jamais | 20,1 |
| Palier V Legend (10 000) : rang V+ | 48,0 | 31,1 | jamais | 50,1 |
| Gagné en atteignant Legend | 197 000 | 164 800 | — | 100 900 |

### 7.2 Implants (épargne seule, à partir de l'ouverture du rang)

| Rang (prix) | Régulier : premier / rang complet | Grinder | PvP (bon) | PvE |
| --- | --- | --- | --- | --- |
| II (6 000 ; 29 500) | 0,7 / 6,6 | 0,7 / 6,1 | 1,4 / 9,0 (1,2 / 7,8) | 2,6 / 14,5 |
| III (8 500 ; 56 500) | 3,8 / 13,1 | 2,8 / 10,7 | jamais | 4,0 / 27,7 |
| IV (16 000 ; 202 000) | 10,4 / 48,7 | 8,5 / 37,6 | jamais | 7,9 / 98,5 |
| V (34 000 ; 238 000) | 21,0 / 57,8 | 15,1 / 44,2 | jamais | 20,1 / 116,1 |
| V+ (70 000 ; set 330 000) | 48,0 / **80,3** | 31,1 / 61,1 | jamais | 50,1 / 160,9 |
| Loadout complet haut de gamme (557 000) | 135,8 | 102,8 | rang V+ fermé | 271,4 |
| Tout le catalogue (828 000) | 202,6 | 152,4 | rangs fermés | > 400 |

Loadout complet haut de gamme : le set V+, le meilleur implant de rang V de chaque autre
famille (Iron Lungs Mk.2, Adrenaline Booster Mk.2, Bioplastic Blood Vessels, Electric
Mantis Blades) et Reinforced Tendons Mk.2, Fortified Ankles, Kinetic Impact Frame.

### 7.3 Parcours cumulé

Ordre : Colby, Reinforced Tendons, Neofiber, Sandevistan Mk.1, Semimaru, Sandevistan
Mk.3, puis le set V+ (Neofiber Mk.3, Aegis, Rara Avis, Apogee). Heure de jeu de chaque
achat :

| Achat | Régulier | Grinder | PvP (bon) | PvE |
| --- | --- | --- | --- | --- |
| Colby | 2,9 | 2,1 | 4,0 (3,5) | 6,9 |
| Reinforced Tendons | 5,2 | 4,5 | 7,0 (6,1) | 11,6 |
| Neofiber | 8,2 | 7,3 | rang fermé | 17,9 |
| Sandevistan Mk.1 | 14,8 | 12,1 | rang fermé | 30,6 |
| Semimaru | 39,2 | 30,4 | 39,4 (34,3) | 79,3 |
| Sandevistan Mk.3 | 55,0 | 42,2 | rang fermé | 110,4 |
| Neofiber Mk.3 | 72,1 | 55,0 | rang fermé | 144,5 |
| Aegis Dermal Plating | 90,4 | 68,6 | rang fermé | 181,1 |
| Rara Avis | 110,2 | 83,2 | rang fermé | 220,0 |
| Zetatech Apogee (fin) | **135,7** | **102,7** | — | 271,2 |

### 7.4 Contrôles

- **Missions et métiers** : dans les 6 paies pleines, 5 760 – 6 020 €$/h nets, soit 1,7 à
  1,8 × le métier ; au-delà (25 %), ≈ 1 450 – 1 500 €$/h, moins que le métier. Le grinder
  repasse donc au métier après ≈ 2,5 à 5,5 h de missions par jour.
- **Activités** : PvP moyen 0,91 × le métier, bon joueur 1,04 ×, plafond 12 000 €$/jour
  (≈ 3,9 h de PvP moyen) ; PvE 0,48 à 0,60 × le métier, 6 000 €$/jour.
- **Plafond 250 €$/min** : mission la plus chère par minute 220 €$ (critique de
  l'éditeur, 4 400 pour 20 min) ; activité PvP 87,5 €$/min au plus (victoire, lobby
  plein), PvE 60 €$/min.
- **Loadout haut de gamme > argent gagné jusqu'à Legend** : 557 000 contre 197 000
  (régulier), 164 800 (grinder), 100 900 (PvE) ; un joueur PvP pur n'atteint pas Legend.
- **Set V+ en 60 – 90 h pour le régulier** : 80,3 h d'épargne avec les prix proposés
  (330 000) ; aux prix actuels (390 000) il en faudrait ≈ 95.

## 8. Tableau avant / après (chaque nombre modifié)

| Fichier | Clé | Avant | Après |
| --- | --- | --- | --- |
| `server/config/job_work.lua` | `sanitation.price` | 18 | **30** |
| | `scrapper.price` | 24 | **40** |
| `server/config/delivery.lua` | `pay.base` / `perStop` / `perKm` | 40 / 20 / 90 | **60 / 30 / 120** |
| | `pay.min` / `pay.max` | 80 / 900 | **150 / 1 400** |
| `server/config/job_runs.lua` | `ac_cleaner.reward` | 260 | **400** |
| `server/config/economy.lua` | `jobs.gradeBonus` | — | **0,10** par grade (vente, courses) |
| `shared/jobs.lua` (paie / 30 min) | Sanitation 0–3 | 40 / 60 / 80 / 110 | **100 / 150 / 200 / 275** |
| | Scrapper 0–2 | 45 / 65 / 90 | **110 / 160 / 225** |
| | AC Cleaner 0–2 | 50 / 75 / 100 | **110 / 160 / 225** |
| | Courier 0–2 | 45 / 65 / 95 | **110 / 160 / 240** |
| | Mécano 0–3 | 50 / 75 / 105 / 140 | **200 / 275 / 350 / 450** |
| | Taxi 0–1 | 50 / 70 | **200 / 275** |
| | Médecin 0–2 | 55 / 85 / 120 | **225 / 325 / 425** |
| | NCPD 0–3 | 60 / 90 / 120 / 150 | **250 / 325 / 400 / 500** |
| `server/config/economy.lua` | `paychecks` (D4) | versée à tout connecté | **active seulement** : 30 min, 75 m, virement ≥ 50, relevé 20 s, saut 2 km |
| `server/config/missions.lua` | Sector 04 standard / hard / critical | 12 000 / 22 500 / 40 000 (par tête) | **3 500 / 5 000 / 9 000** (par tête à 2 / 4 / 6) |
| | Chimera standard / hard / critical | 18 000 / 34 000 / 60 000 (par tête) | **3 000 / 4 500 / 6 000** (par tête à 1 / 2 / 4) |
| `shared/mission_defs.lua` + éditeur | défauts standard / hard / critical | 8 000 / 15 000 / 30 000 | **2 400 / 3 000 / 4 400** ; missions déjà enregistrées : `/lightrp.missions.repay` |
| `server/config/economy.lua` | `missions.crewExponent` | (paie pleine par tête) | **0,7** |
| | `missions.cooldownMinutes` | — | **60** |
| | `missions.dailyFullPayouts` / `capScope` | — | **6** / `account` |
| | `missions.repeatShare` | — | **0,25** |
| | `missions.maxSharePerMinute` | — | **250** |
| | `activities.pvp` | 0 (aucun eddie) | **70 €$/min**, participation **0,75**, résultat **0,5**, plafond **12 000/jour**, répétition **4 / 3 / 4 / 5 par heure** |
| | `activities.pve` | 0 (aucun eddie) | **40 / 50 / 60 €$/min**, défaite **0,5**, plafond **6 000/jour** |
| | `hospital.bill` / `graceMinutes` | gratuit | **300** / **120** |
| | `fitting.fee` / `graceMinutes` | gratuit | **50** / **120** |
| `server/config/garages.lua` | `impound.fees` destroyed / lost / requested / staff | — / 150 / 150 / 250 | **400 / 150 / 250 / 500** (restart 0 inchangé) |
| `server/config/shops.lua` (`street_food`) | `trauma_kit` (achat) | non vendu | **250** (non repris) |
| | eau, burrito, nouilles, raviolis, pizza | 8, 18, 24, 20, 16 | **12, 26, 36, 30, 24** |
| | synthviande, onigiri, pomme, bonbon, barre | 15, 12, 10, 6, 14 | **22, 18, 15, 9, 20** |
| | soda, café, jus, énergie, électrolytes | 10, 12, 12, 18, 16 | **15, 18, 18, 26, 24** |
| `shared/config.lua` | `fuel.pricePerLitre` | 3 | **4** |
| `server/config/dealerships.lua` | Hella / Colby / Supron | 10 000 / 12 000 / 14 000 | **12 000 / 14 000 / 16 000** |
| | Quartz / Hozuki / Columbus | 16 000 / 19 000 / 22 000 | **19 000 / 24 000 / 30 000** |
| | Cortes / Merrimac / Bandit | 28 000 / 32 000 / 35 000 | **38 000 / 46 000 / 52 000** |
| | Thrax / Kusanagi / Semimaru | 42 000 / 45 000 / 60 000 | **62 000 / 80 000 / 100 000** |
| `server/config/cyberware.lua` (**non modifié ici**, §9) | V+ : Neofiber Mk.3 / Aegis / Rara Avis / Apogee | 85 000 / 90 000 / 95 000 / 120 000 | **70 000 / 75 000 / 80 000 / 105 000** (proposé) |

**Inchangé, volontairement** : argent de départ (250 + 1 500), studio de départ
gratuit, paie de l'entraînement du tutoriel (40), premières voitures (MaiMai 4 000,
Apollo 5 000, Galena 6 500), peinture (1 000), armes et munitions, location (50 – 100 €$
par 30 min), virements gratuits, reprise en boutique, multiplicateur des gigs (1,0),
cyberware des rangs II à V.

## 9. Cyberware : liste de prix exacte (pour le propriétaire du cyberware)

> Mise à jour 2026-11-03 : les prix « Actuel » restent en place (set V+ à 390 000), six
> implants s'ajoutent et chaque implant coûte des points de capacité : voir §14.

`server/config/cyberware.lua` appartient à l'agent cyberware et n'est **pas modifié**
par cette branche. Prix à appliquer, par id (`price`) :

| Rang | id | Actuel | Proposé |
| --- | --- | --- | --- |
| II | `iron_lungs` | 6 000 | 6 000 |
| II | `subdermal_armor` | 6 500 | 6 500 |
| II | `titanium_bones` | 7 500 | 7 500 |
| II | `reinforced_tendons` | 9 500 | 9 500 |
| III | `adrenaline_booster` | 8 500 | 8 500 |
| III | `biomonitor` | 9 000 | 9 000 |
| III | `fortified_ankles` | 11 000 | 11 000 |
| III | `neofiber` | 13 000 | 13 000 |
| III | `gorilla_arms` | 15 000 | 15 000 |
| IV | `subdermal_armor_mk2` | 16 000 | 16 000 |
| IV | `impact_frame` | 18 000 | 18 000 |
| IV | `reinforced_tendons_mk2` | 24 000 | 24 000 |
| IV | `epimorphic_skeleton` | 24 000 | 24 000 |
| IV | `sandevistan_mk1` | 26 000 | 26 000 |
| IV | `mantis_blades` | 28 000 | 28 000 |
| IV | `neofiber_mk2` | 30 000 | 30 000 |
| IV | `gorilla_arms_mk2` | 36 000 | 36 000 |
| V | `iron_lungs_mk2` | 34 000 | 34 000 |
| V | `adrenaline_booster_mk2` | 36 000 | 36 000 |
| V | `bioplastic_blood_vessels` | 42 000 | 42 000 |
| V | `mantis_blades_electric` | 62 000 | 62 000 |
| V | `sandevistan_mk3` | 64 000 | 64 000 |
| **V+** | **`neofiber_mk3`** | 85 000 | **70 000** |
| **V+** | **`aegis_dermal_plating`** | 90 000 | **75 000** |
| **V+** | **`rara_avis`** | 95 000 | **80 000** |
| **V+** | **`zetatech_apogee`** | 120 000 | **105 000** |

Pourquoi baisser le V+ : aux prix actuels le set coûte 390 000 €$, ≈ 95 h d'épargne du
joueur régulier, au-delà des 60 – 90 h visées ; à 330 000 il en faut 80. Le rang reste
gardé par le palier Legend (48 h pour le régulier) : ces prix n'avancent pas l'accès,
seulement la complétion. Les rangs II à V tiennent déjà la courbe (§7.2).

## 10. Bandes de prix pour les autres équipes

**Logement** (`/housingadmin`, valeurs en base) : bail de 7 jours ≈ 1,5 à 3 h de
travail pour un petit appartement (5 000 – 10 000 €$), 15 000 – 25 000 €$ pour un moyen ;
achat 60 000 – 250 000 €$ (revente à 50 % déjà en place). Le studio de Kabuki reste
gratuit.

**Nouveaux véhicules** : 12 000 – 16 000 pour un véhicule « correct », 30 000 – 60 000
pour le milieu de gamme, 80 000 – 100 000 pour le haut de gamme (≈ 20 – 25 h du joueur
régulier).

## 11. Vérifier en jeu

- `/work sanitation sell` avec des lots : 30 €$ le lot (×1,1 au grade 1).
- Chimera standard seul : 3 000 €$ ; à deux : 2 437 €$ chacun. Relancer aussitôt : 25 %.
  Sept paies pleines dans la journée : la septième paie 25 %.
- Paie : rester immobile 30 min avec un métier salarié → pas de paie, une notice
  « No paycheck », une ligne de journal ; un lot vendu, un patient stabilisé ou 75 m à
  pied → la paie suivante tombe.
- Kit : Corner Market, 250 €$ ; non repris à la vente ; il réanime un allié.
- Fourrière : faire exploser sa voiture puis la ramener → 400 €$, réparée ; une voiture
  supprimée par le staff sans dégâts → 150 €$ ; épave impossible à garer.
- Activités : FFA à 4 joueurs réels, 10 min, première place → +875 €$ et notice
  « Combat Zone · #1 of 4 · 10 min » ; dernière avec un kill → 525 ; à deux → la moitié ;
  quatrième duel de la même paire dans l'heure → rien, notice ; FFA avec bots → rien.
  PvE arène Standard gagnée 10 min → 400.
- `/lightrp.missions.repay` puis `apply` : les missions de l'éditeur passent au nouveau
  barème ; un second passage ne change rien.
- `/lightrp.account me` et `/bank` montrent les lignes `mission`, `gig`, `salary`,
  `activity_pvp`, `activity_pve`, `hospital`, `fitting`.

## 12. À décider par le propriétaire

1. **Paie active (D4)** : elle s'applique à **tous** les métiers salariés (y compris les
   métiers à boucle), faute de prise de service. Le signal « 75 m en 30 min » est
   volontairement large (un taxi qui roule est actif) ; un joueur obstiné peut tourner
   en rond. Une vraie prise de service serait le correctif durable.
2. **Fourrière** : le redémarrage d'un véhicule **intact** reste gratuit ; et une épave
   qui disparaît sans aucun signal de dégâts est facturée 150 (perdu), pas 400.
3. **Prix V+** à appliquer côté cyberware (§9) — ou garder 390 000 et accepter ≈ 95 h.
   *Tranché le 2026-11-03 : 390 000 gardé ; la capacité borne la puissance à la place
   (§14).*
4. **Hausse des voitures** : le haut de gamme passe de 60 000 à 100 000. La Kusanagi
   (80 000) tombe à 18,8 h pour le régulier, juste sous les 20 h ; la monter à 85 000 la
   remettrait à ≈ 20 h.
5. **Paie des activités** : 70 €$/min, 0,75 + 0,5 × résultat, lobbies pleins (4, 2, 6),
   minimums de durée, plafonds 12 000 / 6 000, répétition 3 à 5 par heure.
6. **PvP pur et cyberware** : avec les règles de `docs/pve-progression.md`, le PvP ne
   donne aucune réputation ; un joueur 100 % PvP gagne de quoi tout acheter mais reste
   au rang II. Accepter (le cyberware est la récompense du PvE), ou lui donner un filet
   de réputation (`pvpGrants`).
7. **Cas sévères assumés** : un 1v1 perdu 0-2 et une manche de FFA sans kill ni assist
   ne paient rien (impossible de les distinguer d'un AFK avec les statistiques
   actuelles) ; un vainqueur par forfait ne garde que la participation.

## 13. Risques

- **Baisse forte des missions** (÷5 à ÷10) : les soldes existants ne sont ni effacés ni
  migrés, les premiers comptes gardent leur avance.
- **Estimations de revenu horaire** : vitesse, manutention, part de l'heure en match et
  taux de victoire sont supposés ; à recaler avec `lightrp_transactions` après quelques
  jours (somme des `kind` par heure de jeu, en particulier `activity_pvp`).
- **Joueurs réels** : comptés par compte, activité et bucket ; un fournisseur qui mêle
  plusieurs matchs dans un même bucket compterait trop large (la paie reste plafonnée
  au lobby plein). Plusieurs comptes d'une même personne ne sont bornés que par la
  règle du crew, la limite de répétition et le plafond journalier.
- **Limite de répétition et relevés** en mémoire : un redémarrage les remet à zéro (le
  plafond journalier, lui, est en base).
- **Statistiques des fournisseurs** : la détection AFK lit les clés actuelles
  (`kills`, `assists`, `roundsWon`, `points`, `captures`, `checkpoints`, `finished`,
  `shakes`…). Un fournisseur qui les renomme fait tomber ses joueurs en « no_progress » :
  à revoir avec `activity_pay_test.lua` à chaque changement de contrat.
- **Recharge et plafonds des missions** en base (`lightrp_mission_payout_cooldowns`,
  `lightrp_mission_payout_daily`) ; sans base de données ils ne vivent que le temps de
  la session.
- **Fusion** : `activities.lua` n'est touché que par une ligne (le crochet de paie),
  `missions.lua` par les lignes de paie et l'annonce au lancement, `medical.lua` par le
  crochet `onPatientStabilized`.

## 14. Cyberware : capacité, builds et kit attendu en PvE (branche `lightrp/cyberware-v2`)

Décision du 2026-11-03 : **les prix ne bougent pas**, le set V+ reste à 390 000 €$
(Neofiber Mk.3 85 000, Aegis 90 000, Rara Avis 95 000, Apogee 120 000 ; la proposition
du §9 n'est pas appliquée). Ce qui borne la puissance n'est plus l'argent seul mais la
**capacité** du corps : chaque implant coûte des points, et le palier de réputation
(PvE seulement) fixe le total. Tout est dans `server/config/cyberware.lua`
(`capacity.byTier`, `capacity` de chaque implant, `fittingFee`, `iconics`).

### 14.1 Capacité par palier

| Palier (réputation) | Rangs ouverts | Capacité | Ce qu'elle porte |
| --- | --- | --- | --- |
| I Street (0) | I – II | **10** | tout le rang II (2 + 2 + 1 + 2 + 3 = 10) |
| II Merc (500) | III | **14** | rang II, ou un mélange II / III (II + III = 26 points) |
| III Operator (1 500) | IV | **18** | un cœur de rang IV : 3 à 4 implants |
| IV Edgerunner (4 000) | V | **22** | 4 à 5 implants de haut rang |
| V Legend (10 000) | V+ | **26** | un build : les quatre V+ seuls font **28**, le meilleur de chaque famille **67** |

Règles : la capacité est vérifiée par le serveur à chaque pose (message « Not enough
capacity: X takes N points, F of your T are free »), la page l'affiche (used / total,
points de chaque implant). Un personnage déjà au-delà garde tout, ne pose plus qu'un
échange plus léger, et une ligne de journal le signale une fois. Sans module de missions
(réputation illisible), la capacité vaut 26.

### 14.2 Points par implant (32 en boutique + 2 iconiques)

| Rang | Implants (points) |
| --- | --- |
| II | Kiroshi Optics 1 · Iron Lungs 2 · Subdermal Armor 2 · Titanium Bones 2 · Reinforced Tendons 3 |
| III | Adrenaline Booster 2 · Fortified Ankles 2 · Biomonitor 3 · Pain Editor 3 · Neofiber 3 · Gorilla Arms 3 |
| IV | Kiroshi Clairvoyant 3 · Subdermal Mk.2 4 · Impact Frame 4 · Tendons Mk.2 4 · Epimorphic 4 · Neofiber Mk.2 4 · Sandevistan Mk.1 5 · Berserk Mk.1 5 · Mantis Blades 5 · Gorilla Mk.2 5 |
| V | Iron Lungs Mk.2 3 · Adrenaline Mk.2 3 · Bioplastic 5 · Second Heart 6 · Electric Mantis 6 · Sandevistan Mk.3 7 · Berserk Mk.3 7 |
| V+ | Neofiber Mk.3 6 · Aegis 7 · Rara Avis 7 · Apogee 8 |
| Iconique | Feral Biomonitor 6 (boss mondiaux) · Chimera Plating 7 (Chimera en Critical) |

Prix des six nouveaux : Kiroshi Optics 7 000, Pain Editor 12 000, Kiroshi Clairvoyant
22 000, Berserk Mk.1 26 000, Second Heart 55 000, Berserk Mk.3 64 000. Les iconiques ne
s'achètent pas. Berserk et Sandevistan partagent la famille « os » (un seul posé).

### 14.3 Builds types

| Palier | Build | Implants (points) | Total | Prix |
| --- | --- | --- | --- | --- |
| Merc (14) | Polyvalent | Neofiber 3, Tendons 3, Biomonitor 3, Subdermal 2, Titanium 2, Kiroshi 1 | 14 | 52 500 |
| Operator (18) | Duelliste | Sandevistan Mk.1 5, Neofiber Mk.2 4, Subdermal Mk.2 4, Epimorphic 4, Kiroshi 1 | 18 | 103 000 |
| Operator (18) | Tenace | Berserk Mk.1 5, Subdermal Mk.2 4, Epimorphic 4, Biomonitor 3, Ankles 2 | 18 | 86 000 |
| Legend (26) | **Tank** | Aegis 7, Rara Avis 7, Berserk Mk.3 7, Bioplastic 5 | 26 | 291 000 |
| Legend (26) | **Mobilité** | Apogee 8, Neofiber Mk.3 6, Electric Mantis 6, Tendons Mk.2 4, Ankles 2 | 26 | 302 000 |
| Legend (26) | **Soutien** | Second Heart 6, Bioplastic 5, Subdermal Mk.2 4, Epimorphic 4, Clairvoyant 3, Pain Editor 3 | 25 | 171 000 |
| Legend (26) | **Bagarreur** | Berserk Mk.3 7, Gorilla Mk.2 5, Impact Frame 4, Tendons Mk.2 4, Adrenaline Mk.2 3, Iron Lungs Mk.2 3 | 26 | 212 000 |

Le Tank porte +100 armure, +100 santé max, +3 santé / s, et +150 armure pendant 10 s
(Berserk Mk.3). Le Soutien échange la défense brute contre l'équipage : marquage du
Clairvoyant, réparation du Pain Editor, relève seul en ville (Second Heart). Le trio
Apogee + Aegis + Rara Avis tient (22 points) mais ne laisse que 4 points : ni dash, ni
régénération.

### 14.4 Kit attendu en PvE difficile

Rappel des échelles : activités PvE (`activities.lua` `pve.difficulties`) Hard =
ennemis × 1,5, santé × 1,5, dégâts × 1,25, IA vétéran, palier II ; Critical = ennemis × 2,
santé × 2,25, dégâts × 1,6, palier III. Raid Chimera (`missions.lua`
`LightRpRaid.scaling`) Hard = santé × 1,8 (+ 0,6 par opérateur), dégâts × 1,1, 6 vies,
réapparition 18 s, 4 vagues, rage à 10 min ; Critical = santé × 3 (+ 0,75 par opérateur),
dégâts × 1,5, **aucune réapparition**, 5 vagues, rage à 8 min ; roquette 35 / 55, purge
40 / 60. L'armure se consomme point pour point avant la santé : le « tampon » ci-dessous
est armure + santé max ajoutées.

| Contenu | Palier minimum | Kit attendu | Tampon ajouté |
| --- | --- | --- | --- |
| Activités Hard | Merc (14) | Subdermal + Titanium + Biomonitor, plus mobilité (Neofiber ou Tendons) | ≈ 55 (30 + 25) et 1,5 / s : une roquette Hard et demie |
| Chimera Hard | Merc (14) | le même, en équipage ; les 6 vies pardonnent | ≈ 55 |
| Activités Critical | Operator (18) | Subdermal Mk.2 + Epimorphic + Berserk Mk.1 ou Sandevistan Mk.1 | ≈ 120 (60 + 60), + 80 pendant 8 s avec le Berserk |
| Chimera Critical | Operator (18), réaliste à Edgerunner (22) | Tank ou Bagarreur, un Soutien dans l'équipage | 120 à 200 permanents (≈ 2 à 3,5 roquettes Critical), + 150 au Berserk Mk.3 |

Le Critical sans réapparition est le contenu qui justifie un build défensif : un
joueur Operator le tente avec un tampon de ≈ 120, un Legend Tank avec ≈ 200 et
+ 3 santé / s. Le Second Heart n'y joue **aucun** rôle : missions et activités gèrent
leurs morts, et il est coupé dans Dogtown et dans toute activité classée ou PvP.

### 14.5 Iconiques

Jamais achetés, vendus ni échangés ; tirés côté serveur, annoncés à toute la ville,
journalisés, rangés dans le stockage (pose 50 €$, points comptés). Un joueur qui possède
déjà l'objet d'une source n'est plus tiré pour elle.

| Source | Objet | Chance | Garanti au | Moyenne (avec garantie) |
| --- | --- | --- | --- | --- |
| Boss mondial vaincu, part payée (`eligible`) | Feral Biomonitor (6 pts : + 3,5 / s, + 20 santé max) | 8 % | 12e échec consécutif | ≈ 7,9 victoires |
| Raid Chimera gagné en Critical (hors test) | Chimera Plating (7 pts : + 110 armure, + 1 / s) | 12 % | 8e échec consécutif | ≈ 5,3 victoires |

Ils valent un léger mieux que leur équivalent de boutique au même prix en points
(Chimera Plating contre Aegis : + 10 armure et + 1 / s ; Feral contre Bioplastic :
+ 0,5 / s et + 20 santé pour 1 point de plus), pas un saut de puissance : la vitrine
compte plus que le chiffre.

### 14.6 Ce que la capacité change au rythme

- **Début de parcours inchangé** : jusqu'à Operator, c'est l'argent qui borne. Au palier
  II (≈ 3,8 h pour le régulier, §7.1), il a gagné ≈ 15 000 €$ ; les rangs II et III
  coûtent 105 000. La capacité ne mord pas encore.
- **Fin de parcours bornée** : à Legend (≈ 48 h, ≈ 197 000 €$ gagnés), un build complet
  coûte 170 000 à 300 000 €$, soit ≈ 41 à 73 h d'épargne seule à ≈ 4 100 €$/h, au lieu
  de viser tout le set V+ (390 000, ≈ 95 h) puis le loadout complet (617 000 aux prix
  actuels). Le premier build Legend complet arrive donc **plus tôt** que l'ancien
  objectif « set V+ ».
- **Le puits d'argent tardif devient la collection** : chaque implant acheté reste au
  stockage ; changer de build coûte 50 €$ par pose. Posséder Tank et Mobilité ≈ 590 000,
  le set V+ en entier reste à 390 000 mais ne se porte jamais d'un bloc.
- **La réputation pèse plus** : +4 points par palier, c'est le PvE qui débloque la
  puissance (le joueur 100 % PvP reste à 10 points, §12 point 6).
- **PvP classé** : la capacité resserre l'écart entre un Legend riche et un Edgerunner
  (26 contre 22 points au lieu de « tout » contre « rang V ») ; le matchmaking par rang
  de cyberware (`activities.lua` `lobby.matchmaking`) reste pertinent.

À vérifier en jeu : la page affiche used / total et les points par implant ; une pose
au-delà est refusée avec le message du serveur ; retirer un implant (50 €$) le range au
stockage, le reposer coûte 50 €$ ; un iconique tiré apparaît au stockage avec l'annonce
en ville.
