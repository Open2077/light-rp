# Équilibrage de l'économie (ouverture publique)

Monnaie : eddies (€$). Tous les chiffres ci-dessous sont dans des fichiers de
configuration ; le code ne porte que les règles (partage du pot, recharge, plafonds,
factures, paie des activités). Les décisions du propriétaire du 2026-11-03 (D1 à D7)
sont appliquées sur la branche `lightrp/economy-balance` ; ce qui reste à trancher est
au §12. L'audit de la prod du 2026-11-04 (contrats de l'éditeur, boss mondiaux, casino)
est au §15, ses questions au §15.7.

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
   ne l'est plus. La réputation suit le palier de chacun (un équipier sous le palier
   gagne la réputation de son palier, `docs/pve-progression.md`) et, depuis le
   2026-11-04, la même recharge par point : 25 % pendant 60 min après une réputation
   pleine (§16.2) ; le plafond journalier ne la touche pas.
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
*Étendu le 2026-11-04 (§15.5) : les missions de l'éditeur ont aussi une bande par
difficulté et paient selon leur taille ; la commande en tient compte.*

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

## 15. Audit de la prod 2026-11-04 (branche `lightrp/economy-prod-audit`)

Sources : copie en lecture seule de `/opt/op77-lightrp` sur l'hôte de prod (sha256 de chaque
`.lua`, `.json`, `.jsonc` et `.md` sous `resources/`, hors `data/`, plus `server.jsonc`),
comparée à `origin/main` 0f01709 ; base MariaDB de Light RP en lecture, **agrégats
seulement** (aucun identifiant de compte, aucune adresse). Modèle horaire : celui du §7
(équipage 1,5 × le minimum, réussite 85 / 70 / 55 %, une réussite prend 70 % de l'horloge
plus 6 min d'approche, 8 % de frais), J = 3 500 €$/h.

### 15.1 Dérive prod / main

| Ensemble | État en prod | Détail |
| --- | --- | --- |
| `op77_lightrp` | **identique à main**, sauf 7 fichiers | 686 fichiers au même sha256 |
| 7 fichiers en retard d'**un** commit | plus anciens (PR #55 et #56) | `server/config/activities.lua`, `server/config/halloffame.lua`, `tests/activities_hub_test.lua`, `tests/halloffame_test.lua` (prod = 2157054 / f67c4ed, main = 2cd3084, placements du crossing) ; `server/config/events_board.lua`, `server/modules/events_board.lua`, `tests/events_board_test.lua` (prod = eb85a3c, main = f3feb3d, masquage du tableau) |
| `op77_playermarks` (PR #57) | **absent** | 5 fichiers, et absent de la liste `resources.load` de prod |
| `op77_race`, `op77_chase`, `op77_turf`, `op77_arena`, `op77_fireworks` | identiques | — |
| `server.jsonc`, `acl.jsonc` (racine) | **modifiés en prod seulement** | voir plus bas : un déploiement des fichiers racine de main les écraserait |
| 292 fichiers propres à la prod | hors dépôt light-rp | distribution serveur : `gamemodes/freeroam`, `open77_chimera`, `open77_cyberware_lab`, `open77_freeroam`, `open77_equipment`, `open77_gizmos_*`, `open77_wardrobe`, `polyzone`, `assets/mods/winter_in_nc`, `system/open77_*` |

**Toutes nos modifications d'économie sont en prod** (2056471, 1cbf63a, 18f1ab8, 42d982a,
7e7b80a, d90597b, 8c9739c) : les fichiers sont identiques, et le registre le confirme (parts
de 1 949 = 2 400 à deux, une paie de recharge à 25 % le 2026-11-03, PvE à 40 €$/min). Ce
qui manque à la prod n'est pas de l'économie : les PR #55, #56 et #57.

`server.jsonc` de prod (à ne **jamais** écraser par celui du dépôt) : nom et tags du serveur,
visibilité publique, bloc `query`, point d'accès public, 32 places, bloc `combat`, limites de
PNJ et de véhicules IA, réplication, voix 32 / 8, `winter_in_nc` et `open77_pedestrians` dans
`resources.load` (et pas `op77_playermarks`), rcon désactivé, métriques, URL publique de
Warden, limites HTTP. `acl.jsonc` de prod : sa propre équipe, et **pas**
`command.lightrp.tables` (la gestion des tables n'est donc pas ouverte au staff en prod).

### 15.2 Ce que dit la base (agrégats du 2026-11-04)

- 11 comptes, 11 personnages, tous actifs ; 6 vus dans les 24 h, 10 dans les 7 jours ;
  49,4 h de jeu cumulées (moyenne 4,5 h, maximum 14,5 h).
- Masse monétaire : 304 348 €$ en banque + 3 070 en liquide = **307 418 €$**. Par
  personnage (banque + liquide) : minimum 814, **médiane ≈ 19 540**, moyenne 27 668,
  maximum 143 078.
- Registre `lightrp_transactions` : 143 lignes du 2026-10-05 au 2026-11-04.

| Ligne | Lignes | Somme | Remarque |
| --- | --- | --- | --- |
| `mission` | 22 | 237 116 | 180 000 = 10 Chimera standard à 18 000 (ancienne échelle, 10-28 → 11-02) ; 48 000 = 6 × 8 000 sur « BOUM BOUM » (contrat supprimé depuis), le 11-02 ; 4 000 The House ; après l'équilibrage : 2 × 1 949 et 2 × 609 sur WORLD BOSS A FINIR 4, **un seul ennemi** |
| `staff` | — | 116 200 | 112 000 en banque + 4 200 en liquide |
| ouverture | — | 19 250 | 16 500 + 2 750 |
| `salary` | 49 | 3 165 | |
| `activity_pve` | 6 | 308 | |
| `shop_sell` | — | 514 | |
| `vehicle_purchase` | — | −63 000 | Colby, Hozuki, Merrimac |
| `shop_buy`, `hospital`, `rental`, `fuel` | — | −2 156, −600, −580, −183 | |

- **77 % de l'argent des missions date de l'ancienne échelle** : l'équilibrage n'est pas
  rétroactif (§13). Les **dons du staff (116 200) pèsent 38 % de la masse**, plus que toutes
  les missions payées depuis l'équilibrage.
- Sources − dépenses du registre = 310 034 €$ pour 307 418 en circulation : 2 616 €$
  (0,9 %) sont sortis **hors registre** (inférence : le liquide du casino, qui n'y passe pas,
  §15.4 point 7 ; non vérifié).
- Aucune ligne `worldboss` ; `lightrp_roulette_claims` est vide : aucun boss mondial ni gain
  de table n'a encore été payé en prod. Tables posées : un blackjack, des dames, des échecs,
  un puissance 4. Réputation de mission : 7 personnages, maximum 938, moyenne 357. Logement :
  les 7 studios de départ gratuits.

### 15.3 Les contrats de l'éditeur en prod

19 définitions en base (`lightrp_mission_defs`), ajoutées en jeu par l'équipe de Nightwolf :
15 au tableau, 1 gig, 3 boss mondiaux. Partout : horloge 15 / 15 / 20 min, équipage
minimum 1 / 1 / 2, multiplicateurs d'ennemis 1 / 1,5 / 2. « Ennemis » = ceux qu'il faut
battre à la difficulté (départ, points de passage obligatoires, chaque vague). Par tête, à
l'équipage minimum, Standard / Hard / Critical :

| Contrat | Ennemis | Enregistré | Payé jusqu'ici | Payé avec cette branche | Après `/lightrp.missions.repay` |
| --- | --- | --- | --- | --- | --- |
| The House | 30 / 48 / 60 | 2 000 / 4 000 / 6 000 | 2 000 / 3 750 / 5 000 | 2 000 / 3 300 / 5 000 | 2 000 / 3 000 / 4 400 |
| WAREHOUSE | 18 / 29 / 36 | 8 000 / 15 000 / 30 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| SHADY CORNER (survie) | 30 / 45 / 60 | 8 000 / 15 000 / 30 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| VALENTINOS DEAL | 12 / 18 / 24 | 5 000 / 10 000 / 15 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| FAVELA (survie) | 45 / 69 / 90 | 8 000 / 15 000 / 30 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| RUN MOTHERFUCKER RUN | 15 / 25 / 30 | 8 000 / 15 000 / 30 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| SNIPA | 28 / 42 / 56 | 8 000 / 15 000 / 30 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 400 / 3 000 / 4 400 |
| THE PIER OF DEATH (survie) | 54 / 81 / 108 | 10 000 / 30 000 / 60 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 600 / 3 300 / 5 000 |
| CORPO COLLABS | 17 / 29 / 34 | 10 000 / 25 000 / 50 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 600 / 3 300 / 5 000 |
| VAMOS (survie) | 72 / 108 / 144 | 15 000 / 30 000 / 80 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 600 / 3 300 / 5 000 |
| TERMINAL B | 20 / 30 / 40 | 12 000 / 25 000 / 80 000 | 3 750 / 3 750 / 5 000 | 2 600 / 3 300 / 5 000 | 2 600 / 3 300 / 5 000 |
| GIG 1 (gig) | 3 / 5 / 6 | 1 000 / 1 500 / 2 000 | 1 000 / 1 500 / 2 000 | **250 / 417 / 500** | inchangé |
| 6 7 TH STREET A FINIR | 3 / 5 / 6 | 2 400 / 3 000 / 4 400 | 2 400 / 3 000 / 4 400 | **600 / 833 / 1 100** | inchangé |
| WORLD BOSS A FINIR 1, 3, 5 (au tableau) | 3 / 5 / 6 | 2 400 / 3 000 / 4 400 | 2 400 / 3 000 / 4 400 | **600 / 833 / 1 100** | inchangé |
| WORLD BOSS TEST, A FINIR 4, A FINIR 2 | boss mondiaux, cagnottes 10 000 / 10 000 / 30 000 | | | §15.5 | WORLD BOSS TEST réécrit, sans effet (pas de tableau) |

Réputation par passage, Standard / Hard / Critical : 100 / 220 / 450 jusqu'ici partout ;
avec cette branche, inchangée pour les contrats complets, **25 / 61 / 113** pour les
contrats de 3 ennemis (GIG 1 compris).

### 15.4 Échelles cassées (avant cette branche)

1. **Le garde-fou était le seul plafond** : tout contrat enregistré à l'ancienne échelle
   payait 250 × ses minutes, soit 3 750 / 3 750 / 5 000 = **2,59 / 2,05 / 1,69 × J** dans
   les 6 paies pleines (cible §2 : 1,7 à 1,8 × J ; défauts de l'éditeur 1,66 / 1,64 / 1,49).
   Plafond journalier d'un compte en Standard : 6 × 3 750 = 22 500 au lieu de 14 400.
2. **Contournable** : le garde-fou suit l'horloge, que l'éditeur accepte jusqu'à 120 min ;
   un contrat à 30 000 et 120 min payait 30 000 par tête.
3. **Le tableau mentait** : il affichait le chiffre enregistré (jusqu'à 80 000), pas la paie.
4. **Les petits contrats payaient plein** : un contrat de 3 ennemis bouclé en ≈ 9 min
   (3 de combat, 6 d'approche) rapportait 2 400, ≈ **16 000 €$/h (4,6 × J)** dans les 6 paies
   pleines, et sa réputation entière **sans plafond** : 100 / 220 / 450 par passage, ≈ 670 /
   1 470 / 3 000 par heure contre 180 / 280 / 375 visés (§7) ; Legend (10 000) en 3 à 7 h de
   farm au lieu de ≈ 48 h. Cinq contrats de ce genre sont au tableau (placeholders « A
   FINIR » et GIG 1) ; le 11-03, deux joueurs ont touché 1 949 chacun pour **un** ennemi.
5. **Boss mondiaux** : la cagnotte de l'éditeur (défaut 30 000) est partagée entre ceux qui
   frappent, sans plafond par tête ni par jour. Il faut 3 joueurs en ligne ; à 3
   combattants, **10 000 chacun** par boss, seul 30 000. Un boss toutes les ≈ 80 min (20
   min d'attente au démarrage, puis 45 à 90 min après la fin du précédent) : jusqu'à
   7 500 €$/h (2,1 × J) en plus, hors recharge et hors plafond journalier des missions.
6. **Roulette sans limite** : 1 à 1 000 000 par pari, autant de paris que voulu par tour ;
   100 000 sur un numéro plein rendent 3 600 000 (≈ 1 000 h de J). La roue de la fortune
   (1 000 par pari, 5 000 par tour) et les machines à sous (1 000 par tirage) sont bornées.
7. **Le casino n'est pas au registre** : mises et gains passent par le liquide de
   l'inventaire et `lightrp_roulette_claims`, jamais par `lightrp_transactions`. En
   espérance c'est un puits (avantage de la maison : roulette 2,7 %, machines à sous 5,6 %
   (RTP 1 632 / 1 728), roue 11 à 24 % selon la case, blackjack ≈ 1 %), mais il est
   invisible dans les comptes.
8. Inchangés et sains : Dogtown (décisions du propriétaire : mise 1 000, perte 10 %, bonus
   serveur 25 %, prime 250 par kill jusqu'à 1 500, bonus + primes ≤ 3 000 par jour et par
   compte), quotidiens (250 / 400 / 250 / 300, hebdomadaire 3 000, budget 1 200 par jour),
   bonus d'équipe des métiers (15 %, 2 000 par jour), Big Contract (20 / 35 %), gigs ×1,0,
   Chimera 3 000 / 4 500 / 6 000 et Sector 04 3 500 / 5 000 / 9 000.

### 15.5 Ce que change cette branche (chiffres en configuration, règles dans le code)

| Fichier | Clé | Avant | Après |
| --- | --- | --- | --- |
| `server/config/economy.lua` | `missions.authored.maxShare` | — (seul 250 × minutes) | **2 600 / 3 300 / 5 000** par tête, quelle que soit l'horloge : 1,80 / 1,81 / 1,69 × J (*remplacé au §16.1 : 2 400 / 3 000 / 4 400*) |
| | `missions.authored.fullPayEnemies` | — | **12 / 18 / 24** : paie et réputation × ennemis ÷ ce seuil (au plus 1) |
| `server/modules/mission_pay.lua` | `cap`, `contentScale` | garde-fou seul | garde-fou, puis bande, puis taille ; un gig n'est pas réduit deux fois |
| `server/modules/missions.lua` | tableau, réputation | `payout` enregistré, 100 / 220 / 450 | **la paie réelle** ; réputation × la même taille (missions de l'éditeur et gigs) |
| `shared/mission_defs.lua` | `M.enemies`, `point.difficulties[i].enemies` | — | ennemis à battre par difficulté, comme le moteur les met en file |
| `server/config/economy.lua` | `worldBosses` | cagnotte = récompense de l'éditeur | **3 000 × combattants payés ^ 0,7**, au plus la récompense ; une part ≤ **250 × minutes** de l'événement |
| `server/config/world_bosses.lua` | `announce.body` | « a share of {reward} » | « a share of **up to** {reward} » : la cagnotte maximale avec tous les joueurs en ligne |
| `shared/tabletop_extra_rules.lua` | `R.MAX_BET`, `R.MAX_ROUND` | 1 000 000 par pari, aucune limite par tour | **1 000** par pari, **5 000** par personnage et par tour (comme la roue) (*divisés par 10 au §16.4*) |
| `server/modules/mission_repay.lua` | règle de `/lightrp.missions.repay` | plafond = garde-fou | plafond = min(garde-fou, bande) ; au-dessus du garde-fou : ancienne échelle, jamais sous le nouveau défaut ; entre la bande et le garde-fou : la bande |

Pourquoi ces nombres :

- **Bande** : le haut de la cible du propriétaire (1,8 × J, §2) à l'horloge par défaut de
  l'éditeur ; 2 600 en Standard = 1,80 × J, 3 300 en Hard = 1,81 × J (220 €$/min, le chiffre
  du §7.4) ; en Critical 1,8 × J dépasserait le garde-fou de 20 min, la bande vaut donc le
  garde-fou (5 000, 1,69 × J). Chimera et Sector 04 n'ont pas d'`enemies` : non concernés.
- **Taille** : 12 / 18 / 24, c'est 12 ennemis multipliés par les multiplicateurs par défaut
  (1 / 1,5 / 2), soit un point d'apparition au maximum de l'éditeur ou six groupes de deux.
  Le plus petit contrat complet de la prod (VALENTINOS DEAL : 12 / 18 / 24) touche la paie
  entière ; les placeholders de 1 à 3 ennemis en touchent 8 à 25 %. Par ennemi, un petit
  contrat rapporte désormais ce que rapporte un grand, et l'approche le rend moins rentable
  à l'heure : le contrat de 3 ennemis du point 4 tombe à ≈ 4 000 €$/h (1,1 × J) et à
  170 / 410 / 750 réputation par heure.
- **Boss mondiaux** : même forme que le pot des missions (exposant 0,7). Par tête, avec la
  récompense de 30 000 de l'éditeur :

  | Combattants payés | 1 | 2 | 3 | 5 | 10 | 20 | 30 |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | Avant, par tête | 30 000 | 15 000 | 10 000 | 6 000 | 3 000 | 1 500 | 1 000 |
  | Cagnotte après | 3 000 | 4 874 | 6 473 | 9 256 | 15 036 | 24 425 | 30 000 |
  | Après, par tête (moyenne) | 3 000 | 2 437 | 2 157 | 1 851 | 1 503 | 1 221 | 1 000 |

  Une part ne dépasse jamais 250 × les minutes du boss (5 000 pour 20 min) ; ce qui
  dépasserait n'est pas versé. À 3 combattants et ≈ 0,75 boss par heure, ≈ 1 600 €$/h
  (0,46 × J) au lieu de 7 500. L'annonce, la notice de zone et le HUD (`reward`, et
  `rewardMax` pour la récompense de l'éditeur) donnent la cagnotte réelle.
- **Roulette** : retour maximal par tour 36 000 (1 000 sur un numéro plein, mise comprise),
  au niveau de la roue (41 000) ; refus avant tout débit. La barre de table du client borne le jeton et le
  bouton à ces limites.

### 15.6 À déployer en prod (Nightwolf)

*Complété par le §16.8 (décisions du 2026-11-04), qui change aussi les chiffres à vérifier
ci-dessous : bande 2 400 / 3 000 / 4 400, roulette 100 / 500.*

Copier dans `/opt/op77-lightrp/resources/gamemodes/op77_lightrp/` :

- de cette branche : `server/config/economy.lua`, `server/config/world_bosses.lua`,
  `server/modules/mission_pay.lua`, `server/modules/mission_repay.lua`,
  `server/modules/missions.lua`, `server/modules/world_bosses.lua`,
  `server/modules/tabletop_extra.lua`, `shared/mission_defs.lua`,
  `shared/tabletop_extra_rules.lua`, `client/core/table_bar.lua` (les tests et la doc ne
  servent pas à l'exécution) ;
- de main, s'ils sont voulus : les 7 fichiers en retard du §15.1 et
  `resources/standalone/op77_playermarks` (à ajouter alors à `resources.load`).

**Ne pas copier** `server.jsonc` ni `acl.jsonc` du dépôt. Redémarrer Light RP, puis en jeu
(staff) `/lightrp.missions.repay` (aperçu : 12 contrats) et `/lightrp.missions.repay apply`.
La paie est juste dès le redémarrage ; la commande ne fait que mettre l'éditeur d'accord.

À vérifier en jeu : le tableau de WAREHOUSE affiche 2 600 / 3 300 / 5 000 avant la commande
et 2 400 / 3 000 / 4 400 après ; 6 7 TH STREET en Standard affiche et paie 600, +25
réputation ; un boss mondial à 3 joueurs annonce « up to » la cagnotte des joueurs en ligne
et paie ≈ 2 160 chacun ; une mise de roulette de 1 001 est refusée, une sixième mise de 1 000
dans le même tour aussi.

### 15.7 Questions au propriétaire

*Réponses du 2026-11-04 au §16 : 1 → les défauts de l'éditeur (§16.1) ; 2 → oui, 25 %
pendant 60 min par point (§16.2) ; 3 → 3 boss payés par jour, réputation comprise
(§16.3) ; 4 → mises ÷ 10 (§16.4) ; 5 → une ligne nette `casino` par manche (§16.5) ;
6 → motif obligatoire, 10 000 par don (§16.6). 7 et 8 restent ouverts.*

1. **Bande des contrats** : 2 600 / 3 300 / 5 000 (le haut de la cible) — ou les défauts de
   l'éditeur (2 400 / 3 000 / 4 400), plus prudents ?
2. **Réputation des missions** : elle reste « sans plafond » (`docs/pve-progression.md`) ;
   la taille ne règle que les petits contrats. Ajouter une recharge par point comme pour
   l'argent (60 min) ?
3. **Boss mondiaux** : un plafond par jour (aucun aujourd'hui) ? Et la réputation fixe de
   150 par boss ?
4. **Machines à sous** : jusqu'à 1 000 par tirage, triple sept ×200 = **200 000** (≈ 57 h de
   J) une fois sur 1 728. À la mise maximale, jusqu'à ≈ 900 tirages par heure (3 s le
   tirage) : ≈ 40 % de chances de toucher le jackpot dans l'heure pour 50 000 de perte
   moyenne. À la roulette (5 000 par tour) ou au blackjack (5 000 par main), une heure à la
   mise maximale fait varier un solde d'environ ±50 000 (≈ 14 h de J). Proposition : diviser les mises maximales par 10 (100 par pari ou tirage, 500
   par tour, blackjack 500), si le casino doit rester du RP plutôt qu'un moyen de gagner une
   voiture en une heure. Non modifié ici.
5. **Casino au registre** : écrire mises et gains dans `lightrp_transactions`
   (`casino_stake`, `casino_win`) pour suivre ce puits ?
6. **Dons du staff** : 116 200 €$, 38 % de la masse monétaire. Les borner ou les tracer par
   motif ?
7. **Fichiers de prod** : versionner un `server.prod.jsonc` et un `acl.prod.jsonc` sans
   secrets pour qu'aucun déploiement ne les écrase ; ouvrir `command.lightrp.tables` au staff
   de prod ?
8. **Dogtown et quotidiens** : décisions du propriétaire, non touchées ici (§15.4 point 8).

Risques et limites : la taille compte des têtes, pas leur santé (un contrat de 3 ennemis à
santé ×5 reste payé 25 %) ; un contrat dont tous les ennemis sont derrière des points de
passage facultatifs compte 0 et ne paie rien ; rien n'a été testé en jeu (tests unitaires
Lua seulement).

## 16. Décisions du propriétaire 2026-11-04 (branche `lightrp/economy-decisions`)

Réponses aux questions du §15.7 (1 à 6). Chaque nombre est en configuration ; les règles
sont dans le code. Rien n'a été testé en jeu (tests Lua et Python seulement, §16.9).

### 16.1 Bande des contrats de l'éditeur = défauts de l'éditeur

| Clé (`server/config/economy.lua`) | Avant (§15.5) | Après |
| --- | --- | --- |
| `missions.authored.maxShare` | 2 600 / 3 300 / 5 000 | **2 400 / 3 000 / 4 400** (= `shared/mission_defs.lua`), 1,66 / 1,64 / 1,49 × J |
| `missions.authored.fullPayEnemies` | 12 / 18 / 24 | inchangé |

Le tableau, la paie et `/lightrp.missions.repay` suivent la bande sans autre changement
(`mission_repay.lua` plafonne à min(garde-fou, bande)). Le §15.3 devient, pour les onze
contrats complets : **2 400 / 3 000 / 4 400 payés dès le redémarrage, et après la
commande** (THE PIER OF DEATH, CORPO COLLABS, VAMOS et TERMINAL B compris, qui restaient à
2 600 / 3 300 / 5 000) ; The House 2 000 / 3 000 / 4 400 ; les petits contrats ne
changent pas (600 / 833 / 1 100, GIG 1 250 / 417 / 500 : ils sont sous la bande). Plafond
journalier d'un compte en Standard : 6 × 2 400 = **14 400** (la cible du §15.4 point 1).

### 16.2 Réputation des missions : même règle de répétition que l'argent

| Clé (`missions`) | Valeur | Effet |
| --- | --- | --- |
| `reputationCooldownMinutes` | **60** | fenêtre par personnage et par point de mission |
| `reputationRepeatShare` | **0,25** | part de la réputation pendant la fenêtre (1 ou 0 min : règle coupée) |

Après une réussite qui lui a donné la réputation **pleine**, le même point (tableau, gig,
Sector 04, raid Chimera) ne donne à ce personnage que 25 % de sa réputation pendant 60 min :
100 / 220 / 450 → **25 / 55 / 113** (petits contrats 25 / 61 / 113 → 6 / 15 / 28). Une
réputation réduite ne prolonge pas la fenêtre ; elle a sa propre fenêtre (table
`lightrp_mission_rep_cooldowns`, créée au démarrage), lancée par chaque réputation pleine,
même au-delà du plafond journalier de l'argent, lequel ne touche pas la réputation. Le
joueur le lit à deux endroits : l'annonce au lancement (« Reputation: 25% of it, this job
gave you its full reputation less than 60 min ago (full again in 42 min). ») et la notice
de fin (« +55 reputation (25% of 220: this job gave you its full reputation less than
60 min ago, full reputation again in 42 min). »). Sur un seul point, une heure de farm en
Standard (≈ 3 passages) rapporte 100 + 25 + 25 = 150 au lieu de 300 ; changer de point
garde la réputation pleine, comme pour l'argent. Fichiers : `server/modules/mission_pay.lua`
(`Pay.reputation`, `reputationQuote`, `reputationStatus`), `server/modules/missions.lua`.

### 16.3 Boss mondiaux : 3 paies par personnage et par jour UTC

`server/config/world_bosses.lua` → **`dailyPaid = 3`** (0 coupe le plafond). Un personnage
payé pour 3 boss mondiaux depuis 00:00 UTC (le même jour que le reste de l'économie,
`floor(unix / 86400)`) ne touche plus ni part ni les 150 de réputation fixe jusqu'au
lendemain. Le combat reste ouvert : il marque des points, aide les autres, voit le HUD ;
il ne compte plus parmi les combattants payés (la cagnotte suit les autres). Sa part
continue de compter pour ce qui n'est pas de la paie (contrats quotidiens, titres,
tirages d'iconiques : `results.eligible`) ; seuls l'argent et la réputation s'arrêtent.
Il est prévenu en entrant dans la zone et à la fin (« Daily world boss pay reached: you
were paid for 3 world bosses today. Fight on if you like; no pay or reputation from world
bosses until 00:00 UTC. »), et le récapitulatif de fin affiche le motif `daily_cap`. Un
boss raté ou une part sous le minimum ne compte pas ; une paie refusée par la banque non
plus (le joueur est prévenu). Compte tenu dans `lightrp_worldboss_daily` (créée au
démarrage), relu après un redémarrage. Maximum par jour à 3 combattants : ≈ 3 × 2 157 =
6 500 €$ et 450 réputation ; seul, 3 × 3 000. Limite connue : le HUD web n'a pas de texte
pour ce cas ; pour un personnage au plafond, il affiche la ligne générique « no reward »
(la notice donne la raison). Le bundle `web/` de main n'est pas reproductible depuis
`ui/` (une reconstruction change `app.js` et `app.css` et efface `web/safezone`), il n'a
donc pas été reconstruit ici.

### 16.4 Casino : mises maximales divisées par 10

| Jeu (fichier `shared/`) | Avant | Après |
| --- | --- | --- |
| Machines à sous (`casino_slots.lua`, `S.MAX_BET`) | 1 – 1 000 par tirage | **1 – 100** |
| Roulette (`tabletop_extra_rules.lua`, `R.MAX_BET` / `R.MAX_ROUND`) | 1 – 1 000 par pari, 5 000 par personnage et par tour | **1 – 100**, **500** |
| Roue de la fortune (`casino_fortune.lua`, `F.MAX_BET` / `F.MAX_ROUND`) | 1 – 1 000 par pari, 5 000 par tour | **1 – 100**, **500** |
| Blackjack (`casino_blackjack.lua`, `B.MAX_BET`) | 5 – 5 000 par main | **5 – 500** (un double porte la main à 1 000) |

Il n'y a pas d'autre table d'argent (billard, échecs, dames, puissance 4 : sans mise). Le
serveur refuse au-delà avant tout débit ; la barre de table du client lit ces constantes
(jetons 1, 5, 10, 25, 50, 100 ; blackjack 5 à 500) : rien à reconstruire côté web.
Seules les textures cuites gardent les anciens chiffres : le tapis du blackjack porte
« TABLE LIMITS 5 – 5,000 » et la vitre des machines « BET 1 - 1000 ». Les scripts de
cuisson les lisent dans ces constantes (`tools/build-casino-blackjack-props.py`,
`tools/build-casino-slots-props.py`) : une recuisson et un nouvel archive client les
mettront à jour (hors de cette branche, qui ne touche aucun asset).

**Jackpot des machines à sous** : il n'est pas fixe. Toute combinaison paie un multiple de
la mise (`S.THREE.seven = 200`, mise comprise) : le triple sept rapporte 200 × la mise,
donc **20 000** à 100 (il en valait 200 000 à 1 000). Rien d'autre à mettre à l'échelle.
À la mise maximale, une heure de machine à sous (≈ 900 tirages) coûte ≈ 5 000 en
espérance et touche le jackpot avec ≈ 40 % de chances ; à la roulette ou au blackjack,
une heure à la mise maximale fait varier un solde d'environ ±5 000 (≈ 1,4 h de J) au lieu
de ±50 000.

### 16.5 Casino au registre : une ligne nette par personnage et par manche

Chaque manche réglée (tour de roulette, tirage, tour de roue, résultat de blackjack)
écrit **une** ligne `lightrp_transactions` par personnage qui y a misé : `kind = "casino"`,
portefeuille `cash`, montant = retours bruts − mises de la manche (doubles compris),
contrepartie « Roulette table » (« Slots table », « Fortune Wheel table », « Blackjack
table »), note « Roulette: staked €$ 30, returned €$ 360 ». Elle est écrite dans la même
transaction SQL que les créances de la manche (`lightrp_roulette_claims`) : une manche qui
échoue n'écrit rien. Les jetons eux-mêmes n'écrivent plus de ligne : la mise, le paiement
de la créance et le remboursement passent par une étiquette `silent` du brouillon
d'inventaire (`Money.inventoryReceipt`) ; une manche remboursée (table rangée ou remise à
zéro) ne laisse donc aucune ligne. `balance_after` = la poche une fois les gains arrivés ;
0 si le personnage est hors ligne au règlement (la poche est dans l'inventaire, hors de
portée du SQL). L'historique en jeu (`/bank`, état `money`) reçoit la ligne dès le
règlement. Aucun changement de schéma. Code : `server/modules/economy.lua`
(`Money.casinoLine`, étiquette `silent`), `server/modules/inventory.lua`,
`server/modules/tabletop_extra.lua` (`X.ledgerLines`, `X.commitRound`, `X.stake`,
`X.claim`), `casino_slots.lua`, `casino_fortune.lua`, `casino_blackjack.lua`,
`board_games.lua` (le règlement minuté rafraîchit l'historique).

**Les 2 616 €$ hors registre (§15.2).** Le casino n'était pas absent du registre : toute
variation de la poche d'un joueur écrivait déjà une ligne, mais anonyme — `kind =
"inventory"`, note « Physical cash moved » —, une par jeton misé et une par paiement de
créance. Le tableau du §15.2 ne somme que les lignes nommées (`mission`, `staff`,
`salary`…) ; il manque donc les lignes `inventory`. Or la seule table de casino posée en
prod était un blackjack et `lightrp_roulette_claims` est vide : aucune main n'a jamais été
payée, chaque mise perdue est sortie de la poche par une ligne `inventory` négative.
Les autres mouvements de liquide hors de la poche (dépôt dans un coffre ou un coffre de
véhicule, liquide posé au sol) passent par le même chemin : l'argent existe encore mais
plus dans la masse comptée. **Inférence** : les 2 616 €$ sont la somme des lignes
`inventory` (mises de blackjack perdues, plus le liquide rangé ou posé) ; à vérifier par
`SELECT SUM(amount) FROM lightrp_transactions WHERE kind = 'inventory'` (non exécuté :
pas d'accès à la base pour cette branche). Depuis cette branche, le casino a ses lignes
`casino` et les lignes `inventory` ne décrivent plus que ces rangements.

Transition : une créance écrite avant le déploiement et payée après passe sans ligne (sa
mise avait sa ligne `inventory`) ; une mise posée avant le redémarrage sur une manche
réglée après compte deux fois (ligne `inventory` et ligne `casino`). Une seule fois, et de
l'ordre d'une mise.

### 16.6 Dons du staff : motif obligatoire, 10 000 par don

`server/config/economy.lua` → `staffGrants` :

| Clé | Valeur | Effet |
| --- | --- | --- |
| `maxGrant` | **10 000** | plafond d'un don (0 : pas de plafond) |
| `minReason` | **4** | caractères minimum du motif |
| `unlimitedPermission` | **`lightrp.money.unlimited`** | permission ACL qui lève le plafond |

`/lightrp.givemoney <id|me> <cash|bank> <montant> <motif>` refuse un don sans motif (il
répond l'usage) et, au-delà de 10 000, un donneur qui n'a pas `lightrp.money.unlimited`.
La console du serveur n'est pas plafonnée. Le motif devient la note de la ligne `staff`
du registre. Le *Crédit* du bureau staff (`admin.lua`) suit la même règle ; son motif
d'audit (4 à 500 caractères) est coupé à 160 octets, sans couper un caractère UTF-8,
pour la note — auparavant un motif de plus de 160 caractères faisait échouer l'insertion
de la ligne (MariaDB en mode strict) alors que l'argent était déjà versé. Le débit
(`takemoney`) n'est pas plafonné.

**Pourquoi pas `command.lightrp.money.unlimited`** : `PermissionMatches` (base) accorde
une permission par `*`, par égalité ou par préfixe `xxx.*`, sans refus. Les rôles
moderator et operator du dépôt détiennent `command.lightrp.*` : ils recevraient la levée
du plafond d'office. `lightrp.money.unlimited` est hors de l'espace `command.` : seul `*`
(le propriétaire) ou une ligne explicite l'accorde. **À ajouter par Nightwolf dans
l'`acl.jsonc` de prod**, au rôle voulu, puis `acl.reload` ; les fichiers `acl.jsonc` et
`server.jsonc` ne sont pas modifiés ici.

### 16.7 Ce qui reste ouvert

§15.7 points 7 (fichiers de prod versionnés, `command.lightrp.tables`) et 8 (Dogtown,
quotidiens) : non traités. Le HUD des boss mondiaux pour un personnage au plafond (§16.3)
attend une reconstruction du bundle web ; les limites imprimées sur le tapis du blackjack
et la vitre des machines (§16.4), une recuisson des props.

### 16.8 À déployer en prod (Nightwolf)

Copier de cette branche dans `/opt/op77-lightrp/resources/gamemodes/op77_lightrp/` :

- `server/config/economy.lua`, `server/config/world_bosses.lua` ;
- `server/modules/admin.lua`, `server/modules/board_games.lua`,
  `server/modules/casino_blackjack.lua`, `server/modules/casino_fortune.lua`,
  `server/modules/casino_slots.lua`, `server/modules/economy.lua`,
  `server/modules/inventory.lua`, `server/modules/mission_pay.lua`,
  `server/modules/missions.lua`, `server/modules/recap.lua`,
  `server/modules/tabletop_extra.lua`, `server/modules/world_bosses.lua` ;
- `shared/casino_blackjack.lua`, `shared/casino_fortune.lua`, `shared/casino_slots.lua`,
  `shared/tabletop_extra_rules.lua`.

Si le §15.6 n'a pas encore été déployé, copier aussi ses fichiers (identiques à main) :
`server/modules/mission_repay.lua`, `shared/mission_defs.lua`, `client/core/table_bar.lua`.
Ne pas copier `server.jsonc` ni `acl.jsonc` ; ajouter `lightrp.money.unlimited` à l'ACL de
prod pour qui doit pouvoir dépasser 10 000. Redémarrer Light RP (les tables
`lightrp_mission_rep_cooldowns` et `lightrp_worldboss_daily` se créent seules), puis
`/lightrp.missions.repay` (aperçu) et `/lightrp.missions.repay apply`.

À vérifier en jeu : WAREHOUSE affiche et paie 2 400 / 3 000 / 4 400 ; refaire le même
contrat dans l'heure donne 25 % de la réputation avec le motif ; un quatrième boss mondial
payé dans la journée est refusé avec la notice ; une mise de 101 est refusée à la
roulette, à la roue et aux machines, 501 au blackjack ; après un tour de roulette, `/bank`
montre une ligne `casino` nette et aucune ligne `inventory` ; `/lightrp.givemoney me bank
500` répond l'usage, `/lightrp.givemoney me bank 20000 test du plafond` est refusé sans la
permission.

### 16.9 Tests

Lua (`tests/run-lua.ps1`) : `mission_pay_test` (bande, réputation répétée), `mission_repay_test`,
`missions_test` (notice de réputation réduite), `world_boss_test` (plafond journalier),
`roulette_limits_test` (100 / 500), `cash_test` (ligne `casino`, étiquettes `silent`),
`staff_money_test` (nouveau : motif, plafond, permission, console, notes UTF-8, bureau),
`dailies_flow_street_test` (`givemoney` avec motif). Python (`tools/`) : les tests du casino
et des tables suivent les nouvelles limites ; `test-tabletop-extra-server.py`,
`test-casino-slots-server.py`, `test-casino-fortune-server.py` et
`test-casino-blackjack-server.py` vérifient une ligne nette par personnage et par manche,
rien pour un remboursement, et que chaque mouvement de jetons est `silent`.

## 17. Économie exigeante, 2026-11-05 (branche `feat/lightrp-economy-hard`)

Demande du propriétaire : « un serveur pas simple, prendre du temps, que ce soit gratifiant d'acheter des choses ». Le
revenu de référence passe de **J = 3 500 €$/h** à **J ≈ 2 200 €$/h** au grade d'entrée. Monter en grade compte davantage :
le bonus par grade passe de 10 % à 15 %, soit environ 3 300 €$/h au grade 3. Les prix s'étalent pour que chaque achat
soit un palier.

### État de Testing avant la refonte (base de données, 2026-11-05)

- 11 personnages pour environ 82 h de jeu cumulées, et 265 k €$ en banque.
- 470 k €$ ont été créés en un mois et 108 k €$ seulement détruits.
- Missions : 261 k €$, presque tout payé avant les plafonds du 2026-11-04 (Chimera à 18 000 €$ par tête, 11 fois).
- Crédits staff : 156 k €$, dont un seul crédit de 100 k €$.
- Les soldes ne sont **pas** remis à zéro : c'est irréversible et ça demande une décision explicite du propriétaire.

### Failles fermées

| Faille | Correction |
|---|---|
| AC Cleaner : 400 €$ toutes les 1 à 1,5 min sur le parcours de test (~20 k €$/h) | 120 €$ par tournée et `cooldownMs` de 3 min propre à la route (job_runs.lua) |
| Bonus Big Contract hors de tout plafond | il compte maintenant dans `crewBonus.dailyCap`, réduit à 1 500 €$/jour (job_crew.lua) |
| Relance gratuite des courses de coursier | `cancelCooldownMs` = 2 min après un abandon par le joueur (pas après une expiration, une chute ou un changement de métier) |
| Sector 04 affichée mais sans script (expirait toujours sans payer) | `disabled = true` : ni tableau ni blip tant qu'elle n'a pas de script |
| Crédits staff sans plafond journalier | `staffGrants.dailyCapPerStaff` = 25 000 €$ par compte staff et jour UTC (console et `lightrp.money.unlimited` exemptés) |
| Personnages secondaires : 1 500 €$ en banque à chaque création, virements gratuits | `startingBankExtraCharacters = 0`, frais de virement de 2 % (minimum 10 €$) |

### Revenus

| Source | Avant | Après |
|---|---|---|
| Éboueur / ferrailleur (par unité) | 30 / 40 | 20 / 26 |
| Coursier (base, par arrêt, par km, bornes) | 60, 30, 120, 150–1 400 | 40, 20, 80, 100–900 |
| Bonus par grade | 10 % | 15 % |
| Salaires (toutes les 30 min) | 100 à 500 | divisés par deux (50 à 250) |
| Déplacement qui vaut une activité pour le salaire | 75 m | 600 m |
| Missions de l'éditeur, part max Standard / Hard / Critical | 2 400 / 3 000 / 4 400 | 1 500 / 2 400 / 3 600 |
| Missions : plafond par minute, paies pleines par jour, attente, part en répétition | 250, 6, 60 min, 25 % | 150, 4, 90 min, 15 % |
| Chimera par tête | 3 000 / 4 500 / 6 000 | 2 000 / 3 000 / 4 000 |
| Boss de monde : par combattant, par minute, paies par jour | 3 000, 250, 3 | 2 000, 150, 2 |
| Activités PvP : par minute, plafond par jour | 70, 12 000 | 45, 7 500 |
| Activités PvE : par minute, plafond par jour | 40 / 50 / 60, 6 000 | 25 / 32 / 40, 4 000 |
| Contrats quotidiens et budget du jour | 250 / 400 / 250 / 300, 1 200 | 175 / 275 / 175 / 200, 800 (l'hebdomadaire reste à 3 000) |
| Maneki-neko : par chat, paliers | 500, 5 k / 15 k / 40 k | 250, 2,5 k / 7,5 k / 20 k |

### Dépenses

| Poste | Avant | Après |
|---|---|---|
| Armes | 1 200 à 10 500 | ×1,5, arrondi à 50 (1 800 à 15 750) |
| Munitions (boîte : 9 mm, chevrotine, fusil, sniper) | 75 / 90 / 110 / 150 | 110 / 135 / 165 / 225 (rachat 25 / 30 / 40 / 55) |
| Boosters TCG WNC / Beta, display | 120 / 180, 2 600 | 400 / 600, 8 500 (rachat 150 / 220 / 3 000) |
| Véhicules | 4 000 à 100 000 | ×2,5, arrondi à 500 (MaiMai 10 000 … Semimaru 250 000) |
| Fourrière : détruit / perdu / demandé / staff | 400 / 150 / 250 / 500 | 1 500 / 600 / 500 / 750 |
| Peinture | 1 000 | 2 500 |
| Essence | 4 €$/L | 6 €$/L (~400 €$/h au volant) |
| Hôpital | 300 | 750 |
| Nourriture | inchangée : ~12 €$/h, car la faim et la soif baissent 4 fois moins vite (choix du propriétaire) | |

Les 24 boosters d'un display, revendus, rapportent 3 600 €$, bien moins que les 8 500 €$ du display : aucune boucle
d'achat-revente n'est possible.

### Pas encore fait (code à écrire)

- **Dette d'hôpital :** aujourd'hui, la facture n'est prélevée que sur l'argent disponible, jamais en négatif.
- **Assurance véhicule :** optionnelle, 1 % du prix par semaine.
- **Fourrière en % du prix du véhicule :** ce sont des forfaits pour l'instant.
- **Paliers maneki par compte :** ils comptent encore par personnage.
- **Plafond absolu des répétitions de mission :** la part tombe à 15 %, mais sans limite.
- **Loyers et prix d'achat des logements :** ils sont en base, à régler avec `/housingadmin` (cible : petit appartement à 6 000 €$/semaine, moyen à 18 000 €$/semaine, achat de 120 k à 500 k €$).

## 18. Auto Studio : prix provisoires (branche `vc/a3-studio-full`)

Le studio complet propose dix catégories ; neuf sont en vente, les vitres sont fermées
(voir la ligne Vitres). La vague 2 (branche `lr/studio-extras`) en ajoute cinq :
animation du néon, couleurs des feux, son moteur, autocollants et tag. Elles restent
grisées tant que leurs natifs et le registre de catégories du garage manquent. Tous les tarifs sont dans **un seul tableau**
serveur, `LightRpCustomizationPricing` (`server/config/vehicle_customization.lua`).
Le client n'envoie jamais de prix. Seule la peinture est décidée (propriétaire,
2026-11-05). Tout le reste est **provisoire**, marqué `-- PROVISIONAL`, et attend la
décision du propriétaire.

Chaque achat est une destruction de monnaie pure : aucun revenu ne s'y rattache.
Chaque achat passe une ligne au registre, dans la même transaction SQL que le débit et
l'enregistrement du véhicule. Les heures ci-dessous sont comptées au revenu de
référence de la §17 : J ≈ 2 200 €$/h au grade d'entrée, environ 3 300 €$/h au grade 3.

| Catégorie | Prix | Unité | Heures (grade d'entrée) | Registre | Raisonnement |
|---|---|---|---|---|---|
| Peinture | 2 500 | les deux canaux | 1,1 | `vehicle_paint` | décidée le 2026-11-05 (§17) |
| Livrée | 4 000 | un schéma deux tons d'usine, ou retour à la peinture unie | 1,8 | `vehicle_livery` | au-dessus de la peinture : deux tons, posés sur la couche d'usine |
| Jantes | 6 000 | le jeu complet (toutes les roues, une finition), ou retour aux jantes d'usine | 2,7 | `vehicle_rims` | 20 % d'une Hella (30 000) : le premier achat visible de loin |
| Carrosserie | 3 500 | **par groupe changé** (aileron, ouïes arrière, lame, canards, bas de caisse, diffuseur, capot, toit, protection avant) | 1,6 par groupe | `vehicle_bodykit` | 9 groupes au plus (Thrax) : 31 500, soit environ 14 h ; 7 groupes sur une Hella : 24 500 |
| Néon | 5 000 | le kit avec couleur et intensité, ou son retrait | 2,3 | `vehicle_neon` | visible de nuit par tous, au niveau des jantes |
| Phares | 500 | une teinte, ou retour aux phares d'usine | 0,2 | `vehicle_lights` | phase 1 : un seul paramètre (la teinte) |
| Finition | 2 500 | une variante d'usine | 1,1 | `vehicle_trim` | phase 1 : au prix de la peinture |
| Plaque | 2 500 | une nouvelle immatriculation | 1,1 | `vehicle_plate` | unique sur le serveur ; le prix freine les changements à répétition |
| Vitres | 1 500 | une teinte, tout niveau, ou retour au verre d'usine | 0,7 | `vehicle_tint` | configuré mais **non vendu** : le natif existe et la bascule marche, mais le verre s'affiche encore comme celui d'usine ; catégorie fermée (« Coming soon ») |
| Performance | par modèle et par palier (tableau ci-dessous) | les paliers entre l'actuel et la cible | — | `vehicle_stage` | proposition E5 |
| Retrait d'un palier | 1 000 | redescendre, ou revenir au stock | 0,5 | `vehicle_stage` | rien n'est remboursé |
| Animation du néon (vague 2) | 2 500 | un mode (pulsation, stroboscope, chenillard…), ou retour au néon fixe | 1,1 | `vehicle_neon_anim` | la moitié du néon : elle n'existe que sur un néon déjà posé |
| Couleurs des feux (vague 2) | 1 500 | stop, recul, clignotants et habitacle, autant de groupes qu'on veut, ou retour à l'usine | 0,7 | `vehicle_lamps` | plus que la teinte des phares (500) : quatre groupes en un achat |
| Son moteur (vague 2) | 6 000 | un son, ou retour au son d'usine | 2,7 | `vehicle_engine_sound` | au prix des jantes : la voiture est reconstruite, et on l'entend de loin |
| Autocollants (vague 2) | 1 500 | **par autocollant ajouté** ; n'en retirer coûte un autocollant | 0,7 par autocollant | `vehicle_stickers` | 12 décalques au plus, livrée comprise : 12 autocollants coûtent 18 000 |
| Tag (vague 2) | 2 000 | un texte peint (police, couleur, emplacement), ou son retrait | 0,9 | `vehicle_tag` | objectif secondaire W2.5 : le contrat ne donne pas de prix |

**Règles de prix.**

- **Carrosserie.** Le prix est 3 500 multiplié par le nombre de groupes qui diffèrent
  du kit confirmé, avec un minimum de 1. Changer d'aileron et ajouter une lame coûte
  donc 7 000.
- **Montée de palier.** Elle paie chaque palier entre l'actuel et la cible : passer
  du stock au palier 3 sur une Hella coûte 2 500 + 3 500 + 5 000 = 11 000.
- **Descente de palier.** Redescendre coûte 1 000, quelle que soit la cible, sans
  remboursement.
- **Délai.** Un véhicule peut être modifié une fois toutes les 10 min
  (`stages.cooldownMs`).
- **Lien peinture–livrée.** Peinture et livrée sont liées. Acheter une peinture
  enlève la livrée, et acheter une livrée remet la peinture d'usine. On paie
  seulement la catégorie choisie.
- **Autocollants.** Le prix est 1 500 multiplié par le nombre d'autocollants qui ne
  sont pas déjà sur la voiture, avec un minimum de 1. Retirer des autocollants sans en
  ajouter coûte donc 1 500.
- **Son moteur.** Chaque essai reconstruit la voiture : un essai toutes les 4 s au plus,
  gratuit. Seul l'achat est payant.

### 18.1 Paliers de performance (proposition E5)

E5 fixe le prix de chaque palier ainsi :

- prix concession × 10 / 15 / 20 % × poids de valeur ;
- poids de valeur = 0,5 + 0,5 × la part de moteur réellement livrée (un modèle bridé
  par le plafond de sa classe paie moins) ;
- minimum de 1 000 / 1 500 / 2 000, arrondi au 500 supérieur.

La source est `scripts/vehicle-kit/stages/STAGES.md`, dans le dépôt Open77.

| Modèle | Prix concession | Palier 1 | Palier 2 | Palier 3 | Les trois | Part du prix |
|---|---|---|---|---|---|---|
| Makigai MaiMai | 10 000 | 1 000 | 1 500 | 2 000 | 4 500 | 45 % |
| Brennan Apollo | 12 500 | 1 000 | 1 500 | 2 000 | 4 500 | 36 % |
| Thorton Galena | 16 000 | 1 500 | 2 000 | 2 500 | 6 000 | 38 % |
| Archer Hella | 30 000 | 2 500 | 3 500 | 5 000 | 11 000 | 37 % |
| Thorton Colby | 35 000 | 3 000 | 4 000 | 5 500 | 12 500 | 36 % |
| Mahir Supron | 40 000 | 3 500 | 5 000 | 7 000 | 15 500 | 39 % |
| Archer Quartz | 47 500 | 2 500 | 4 000 | 5 000 | 11 500 | 24 % |
| Mizutani Hozuki | 60 000 | 6 000 | 9 000 | 12 000 | 27 000 | 45 % |
| Villefort Columbus | 75 000 | 7 500 | 11 500 | 15 000 | 34 000 | 45 % |
| Villefort Cortes | 95 000 | 9 500 | 14 500 | 19 000 | 43 000 | 45 % |
| Thorton Merrimac | 115 000 | 11 500 | 17 500 | 23 000 | 52 000 | 45 % |
| Archer Bandit | 130 000 | 11 000 | 16 500 | 22 000 | 49 500 | 38 % |
| Chevalier Thrax | 155 000 | 15 500 | 23 500 | 31 000 | 70 000 | 45 % |
| Yaiba Kusanagi | 200 000 | 20 000 | 30 000 | 40 000 | 90 000 | 45 % |
| Yaiba Semimaru | 250 000 | 25 000 | 37 500 | 50 000 | 112 500 | 45 % |

### 18.2 Ordres de grandeur

- **Cosmétique complet.** Une Hella avec peinture, jantes, kit complet (les 7 groupes
  qui lui vont), néon, plaque et phares coûte 41 000 €$ (137 % du prix de la voiture).
  Cela représente environ 19 h au grade d'entrée, ou 12,5 h au grade 3. Avec le kit de
  5 groupes de la première version, c'était 34 000 €$ (113 %).
- **Cosmétique et palier 3.** Avec le palier 3 en plus, la même Hella coûte 52 000 €$
  (173 % de la voiture), soit environ 24 h au grade d'entrée.
- **Coût fixe.** Les prix cosmétiques ne dépendent pas du modèle ; seul le nombre de
  groupes de carrosserie qui lui vont change le total. Le cosmétique complet pèse donc
  lourd sur une MaiMai (34 000, 340 % de 10 000, 5 groupes) et peu sur une Semimaru
  (37 500, 15 %, 6 groupes). C'est voulu, pour que le style soit accessible. Si le
  propriétaire préfère un prix proportionnel au véhicule, il faut un coefficient par
  modèle, comme pour les paliers.
- **Vague 2.** Animation, feux, son moteur, 4 autocollants et un tag coûtent
  18 000 €$, soit environ 8 h au grade d'entrée. Ajoutés au cosmétique complet de la
  Hella, cela fait 59 000 €$ (197 % de la voiture), 70 000 €$ avec le palier 3.

### 18.3 Questions au propriétaire

- **Prix cosmétiques.** Faut-il garder les prix provisoires (livrée 4 000, jantes
  6 000, carrosserie 3 500 par groupe, néon 5 000, plaque 2 500, phares 500, finition
  2 500, vitres 1 500 à la réouverture) ? Faut-il les rendre proportionnels au prix
  du véhicule ?
- **Paliers.** Faut-il garder la proposition E5, le retrait à 1 000 sans remboursement
  et le délai de 10 min ?
- **Plaque.** Le format provisoire est de 7 caractères A-Z/0-9, et les listes de mots
  interdits et réservés sont à compléter. Une plaque personnalisée doit-elle coûter
  plus cher qu'une plaque tirée au hasard ? (La plaque aléatoire n'existe pas encore.)
- **Vague 2.** Faut-il garder l'animation du néon à 2 500, les couleurs des feux à
  1 500 pour tous les groupes, le son moteur à 6 000, les autocollants à 1 500 pièce et
  le tag à 2 000 ? Un autocollant doit-il coûter selon sa taille (ses décalques) plutôt
  qu'à la pièce ? L'essai du son moteur doit-il rester gratuit ?
