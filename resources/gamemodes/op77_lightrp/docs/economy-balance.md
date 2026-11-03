# Équilibrage de l'économie (ouverture publique)

Proposition à valider par le propriétaire. Monnaie : eddies (€$). Tous les chiffres
ci-dessous sont dans des fichiers de configuration ; le code ne porte que les règles
(partage du pot, recharge, plafond journalier, factures).

## 1. Constat (lecture du code, branche `lightrp/activities`)

**Revenus horaires mesurés** (simulation sur les vraies coordonnées des points ;
hypothèses : voiture avec coffre, 50 à 70 km/h de moyenne, route réelle = 1,35 × la
ligne droite, 1 min par arrêt de livraison, 3 min de manutention par boucle) :

| Source | Aujourd'hui | Détail |
| --- | --- | --- |
| Sanitation | 1 800 – 2 100 €$/h | 30 sacs (sac 40 kg + coffre 80 kg) × 18 €$, boucle 6 km |
| Scrapper | 1 700 – 2 200 €$/h | 30 lots × 24 €$, boucle 8 à 9,6 km |
| Courier | 2 300 – 2 900 €$/h | 748 €$ en moyenne par course de 7,5 km (vol d'oiseau), **39 % des courses butent sur le plafond de 900** |
| Toit (AC Cleaner, hérité) | ~2 400 €$/h | 260 €$ pour 5 à 8 min |
| Paie | 80 – 220 €$/h | 40 à 110 €$ toutes les 30 min, versée à tout joueur connecté (même immobile) |
| Mission Chimera standard | **43 000 €$/h par tête** | 18 000 €$ pour 20 min, faisable seul, **versés en entier à chaque membre**, sans recharge |
| Braquage Sector 04 critique | 40 000 €$ × 8 = **320 000 €$ créés** par partie | idem |
| Gigs de fixers | 8 000 / 15 000 / 30 000 €$ par tête | 15 à 20 min, valeurs par défaut de l'éditeur |

Une Chimera standard vaut 6 à 9 h de travail ; une équipe de 4 crée 72 000 €$ en
20 min. Les achats (voitures 4 000 – 60 000, cyberware 6 000 – 64 000, armes 1 200 –
10 500) sont épuisés après quelques missions, et il n'existe presque aucune dépense
récurrente : l'argent s'accumule puis ne vaut plus rien.

**Dépenses récurrentes vérifiées** : nourriture et boisson ≈ 33 €$/h (faim 36 pts/h,
soif 54 pts/h ; burrito 35 pts pour 18 €$, eau 30 pts pour 8 €$), carburant 3 €$/L
(1,1 L/km, ≈ 200 €$/h au volant), location 50 – 100 €$ par 30 min, fourrière 150 – 250 €$,
peinture 1 000 €$. **Confirmé gratuit** : l'hôpital (`medical.lua` « Give up », et le
repli de `server/main.lua` dont l'avis dit « The bill went to your insurance »), les
vêtements (la cabine est l'interface de la plateforme ; l'emport en objets ne coûte
rien). Les kits de réanimation (`trauma_kit`) ne sont vendus nulle part.

## 2. Courbe cible

Référence : **J = 3 500 €$/h** pour un joueur actif au grade d'entrée, avec voiture.

| Objectif | Cible | Résultat avec la proposition |
| --- | --- | --- |
| Métiers, grade 0 | 3 000 – 5 000 €$/h | Sanitation 2 900 – 3 400, Scrapper 2 800 – 3 700, Courier 3 400 – 4 100 (+ paie ≈ 200 €$/h) |
| Métiers, grade max | « un peu plus » | +10 % par grade sur la vente et les courses (grade 2 : +20 %, grade 3 : +30 %) et paie ×2,5 |
| Paie | petit bonus | 100 – 275 €$ toutes les 30 min selon le grade (≈ 6 % du revenu actif) |
| Première voiture (4 000 – 8 000) | 1 – 2 h | MaiMai ≈ 0,7 h, Galena ≈ 1,5 h (départ 1 750 €$, net de carburant et nourriture ≈ 3 200 €$/h) |
| Voiture moyenne (Hozuki 19 000) | 5 – 6 h | ≈ 5,4 h |
| Haut de gamme (60 000) | 15 – 20 h, plus vite en mission | ≈ 18 h de métier ; 1,5 à 2 jours de missions critiques au plafond |
| Missions | meilleur €$/h, sans ordre de grandeur | 2× à 3× J par tête à l'équipage minimum, pot partagé, recharge et plafond journalier |
| Premier jour | gratuit / abordable | studio gratuit, tutoriel inchangé, hôpital et cabine offerts les 120 premières minutes de jeu |

## 3. Missions et gigs : nouvelles règles (`server/config/economy.lua` → `missions`)

1. **`payout` change de sens** : c'est la part **de chaque opérateur à l'équipage
   minimum** de la difficulté (ce que le tableau affiche reste donc un maximum honnête).
2. **Pot sous-linéaire, partagé** : au-delà du minimum, la part vaut
   `payout × (équipage / minimum) ^ (exposant − 1)`, exposant **0,7**. Le pot total
   grandit comme `équipage ^ 0,7` au lieu de `équipage` : 4 opérateurs créent 2,64 parts,
   pas 4. L'équipage compté est celui qui termine (un départ ne rapporte rien à personne
   et ne fait jamais dépasser `payout`).

   | Équipage / minimum | 1 | 1,5 | 2 | 3 | 4 | 6 | 8 |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | Part par tête | 100 % | 88,5 % | 81 % | 72 % | 66 % | 58 % | 54 % |
   | Pot total (en parts) | 1 | 1,33 | 1,62 | 2,16 | 2,64 | 3,51 | 4,29 |

3. **Recharge par personnage et par point** : après une paie pleine, le même point de
   mission (tableau ou gig) ne repaie en entier qu'après **60 min**.
4. **Plafond journalier par compte** : **6 paies pleines** par jour UTC, tous
   personnages du compte confondus (pas de contournement par un second personnage).
5. **Au-delà** (recharge active ou plafond atteint) : la mission paie **25 %** de la
   part. Aider ses amis reste payé, farmer ne l'est plus. La réputation reste entière.
6. **Garde-fou** : une part ne dépasse jamais **250 €$ par minute d'horloge** de la
   difficulté. Il protège contre les missions de l'éditeur déjà enregistrées avec les
   anciennes valeurs (8 000 €$ pour 15 min → 3 750 €$).
7. **Annonce** : au lancement, chaque opérateur reçoit sa paie attendue (et la raison
   d'une réduction) ; à la fin, l'avis donne le montant, l'équipage et la réduction.
   Les gigs affichent « up to € X each » et le dernier SMS du fixer donne la vraie part.

Tests et éditeur : les lancements de test (`inst.test`) ne paient toujours rien. Les
gigs passent par le même calcul (`payoutMultiplier` 1,0 inchangé).

## 4. Nouvelles dépenses récurrentes

| Dépense | Règle | Montant |
| --- | --- | --- |
| **Facture d'hôpital** | uniquement quand le joueur choisit « Give up and go to hospital » (`medical.lua`) ; jamais sur une réanimation, jamais en mission/activité (la mort n'y est pas capturée, et la règle revérifie `activities.owns` et `missions.handlesDeath`), jamais pendant le premier jour ni les 120 premières minutes de jeu ; banque puis liquide, **jamais en négatif** (on prend ce qu'il y a, le reste est effacé). Le montant est affiché dans l'écran d'inconscience avant confirmation. | **300 €$** |
| **Cabine d'essayage** | une visite d'une cabine publique en ville (bucket 0) qui se termine par un look enregistré ; jamais la création de personnage, le logement, le premier jour ni les 120 premières minutes ; prélevée une fois par visite, banque puis liquide, offerte si le joueur ne peut pas payer. Prix affiché sur le marqueur et la balise. | **50 €$** |
| Fourrière | frais existants relevés : véhicule disparu/détruit (« franchise d'assurance »), envoi par le propriétaire, remorquage staff ; redémarrage serveur toujours gratuit | 400 / 250 / 500 €$ |
| Carburant | 1,1 L/km : ≈ 260 €$/h au volant, ≈ 45 €$ par course de livraison | 4 €$/L |
| Nourriture | +50 % : ≈ 50 €$/h, 1,5 % du revenu | 9 – 36 €$ |

Avec ces postes, un joueur actif dépense ≈ 8 à 10 % de ce qu'il gagne en frais
courants ; les gros achats restent le puits principal. Le levier récurrent le plus fort
reste **le loyer des logements** (saisi par le staff, voir §6).

## 5. Tableau avant / après (chaque nombre modifié)

| Fichier | Clé | Avant | Après |
| --- | --- | --- | --- |
| `server/config/job_work.lua` | `sanitation.price` | 18 | **30** |
| | `scrapper.price` | 24 | **40** |
| `server/config/delivery.lua` | `pay.base` / `perStop` / `perKm` | 40 / 20 / 90 | **60 / 30 / 120** |
| | `pay.min` / `pay.max` | 80 / 900 | **150 / 1 400** |
| `server/config/job_runs.lua` | `ac_cleaner.reward` | 260 | **400** |
| `server/config/economy.lua` (nouveau) | `jobs.gradeBonus` | — | **0,10** par grade (vente, courses) |
| `shared/jobs.lua` (paie / 30 min) | Sanitation 0–3 | 40 / 60 / 80 / 110 | **100 / 150 / 200 / 275** |
| | Scrapper 0–2 | 45 / 65 / 90 | **110 / 160 / 225** |
| | AC Cleaner 0–2 | 50 / 75 / 100 | **110 / 160 / 225** |
| | Courier 0–2 | 45 / 65 / 95 | **110 / 160 / 240** |
| | Mécano 0–3 | 50 / 75 / 105 / 140 | **200 / 275 / 350 / 450** |
| | Taxi 0–1 | 50 / 70 | **200 / 275** |
| | Médecin 0–2 | 55 / 85 / 120 | **225 / 325 / 425** |
| | NCPD 0–3 | 60 / 90 / 120 / 150 | **250 / 325 / 400 / 500** |
| `server/config/missions.lua` | Sector 04 standard / hard / critical | 12 000 / 22 500 / 40 000 (par tête) | **3 500 / 5 000 / 9 000** (par tête à 2 / 4 / 6) |
| | Chimera standard / hard / critical | 18 000 / 34 000 / 60 000 (par tête) | **3 000 / 4 500 / 6 000** (par tête à 1 / 2 / 4) |
| `shared/mission_defs.lua` + éditeur (`ui/.../missioneditor/model.ts`) | défauts standard / hard / critical | 8 000 / 15 000 / 30 000 | **2 400 / 3 000 / 4 400** |
| `server/config/economy.lua` | `missions.crewExponent` | (paie pleine par tête) | **0,7** |
| | `missions.cooldownMinutes` | — | **60** |
| | `missions.dailyFullPayouts` / `capScope` | — | **6** / `account` |
| | `missions.repeatShare` | — | **0,25** |
| | `missions.maxSharePerMinute` | — | **250** |
| | `hospital.bill` / `graceMinutes` | gratuit | **300** / **120** |
| | `fitting.fee` / `graceMinutes` | gratuit | **50** / **120** |
| `server/config/garages.lua` | `impound.fees` lost / requested / staff | 150 / 150 / 250 | **400 / 250 / 500** (restart 0 inchangé) |
| `shared/config.lua` | `fuel.pricePerLitre` | 3 | **4** |
| `server/config/shops.lua` (`street_food`, achat) | eau, burrito, nouilles, raviolis, pizza | 8, 18, 24, 20, 16 | **12, 26, 36, 30, 24** |
| | synthviande, onigiri, pomme, bonbon, barre | 15, 12, 10, 6, 14 | **22, 18, 15, 9, 20** |
| | soda, café, jus, énergie, électrolytes | 10, 12, 12, 18, 16 | **15, 18, 18, 26, 24** |

**Inchangé, volontairement** : argent de départ (250 + 1 500), studio de départ
gratuit, paie de l'entraînement du tutoriel (40), prix des voitures (ce sont les
ancres de la courbe), peinture (1 000), armes et munitions, location (50 – 100 €$ par
30 min : 3 à 6 % du revenu, la voie d'accès des nouveaux), virements gratuits, reprise
en boutique, multiplicateur des gigs (1,0). Les activités (arène, courses, poursuites,
turf) ne paient toujours **aucun eddie**.

**Missions de l'éditeur déjà enregistrées** : leurs paies sont en base, saisies par le
staff ; elles ne sont pas migrées. Le garde-fou de 250 €$/min les borne, mais il faut
les repasser dans `/lightrp.missions` aux nouvelles valeurs (2 400 / 3 000 / 4 400 pour
15 / 15 / 20 min).

## 6. Bandes de prix pour les autres équipes

**Cyberware** (appliqué par l'agent cyberware, `server/config/cyberware.lua` n'est pas
modifié ici), en heures de métier au grade d'entrée (≈ 3 200 €$/h net) :

| Palier | Heures de métier | Bande |
| --- | --- | --- |
| Entrée (tier 2) | 1,5 – 2,5 h | 5 000 – 8 000 €$ |
| Tier 3 | 2,5 – 4,5 h | 8 000 – 15 000 €$ |
| Tier 4 | 5 – 11 h | 16 000 – 36 000 €$ |
| Tier 5 / haut de gamme actuel | 15 – 20 h | 50 000 – 65 000 €$ |
| Nouveaux implants PvE de prestige | 25 – 40 h, soit ≈ 1 semaine de missions au plafond | 80 000 – 130 000 €$ |

Les prix actuels (6 000 – 64 000) tombent déjà dans ces bandes ; seuls les nouveaux
implants de prestige sont à placer.

**Logement** (`/housingadmin`, valeurs en base) : bail de 7 jours ≈ 1,5 à 3 h de
travail pour un petit appartement (5 000 – 10 000 €$), 15 000 – 25 000 €$ pour un
moyen ; achat 60 000 – 250 000 €$ (revente à 50 % déjà en place). Le studio de Kabuki
reste gratuit.

## 7. À décider par le propriétaire

1. **Les chiffres eux-mêmes**, surtout J = 3 500 €$/h, l'exposant 0,7, la recharge
   de 60 min, le plafond de 6 paies pleines et les 25 % au-delà.
2. **Portée du plafond** : par compte (proposé, contre les doubles comptes) ou par
   personnage (`capScope = "character"`).
3. **Paie des métiers de service** (mécano, taxi, médecin, NCPD) : sans boucle de
   travail, leur paie est tout leur revenu. Elle est versée à tout joueur connecté,
   même immobile (pas de prise de service ni de détection d'inactivité). Proposé :
   ×4 environ, à garder sous contrôle du staff qui attribue ces grades ; une vraie
   prise de service serait le correctif durable.
4. **Kits de réanimation** introuvables en boutique : les vendre (par exemple
   200 €$ au marché ou dans une clinique) rendrait la réanimation par les joueurs
   plus intéressante que la facture d'hôpital.
5. **Fourrière « lost »** couvre aussi les véhicules perdus sur un bug ; 400 €$ reste
   ≈ 7 min de travail, le staff peut rembourser.
6. **Cabine d'essayage payante** ou non (`fitting.fee = 0` la rend gratuite).
7. Revoir les missions de l'éditeur déjà publiées (voir §5).

## 8. Vérifier en jeu

- `/work sanitation sell` avec des lots : 30 €$ le lot (×1,1 au grade 1).
- Une course Courier : la paie annoncée tombe entre 150 et 1 400 €$.
- Chimera standard seul : 3 000 €$ ; à deux : 2 437 €$ chacun, avis « crew of 2 ».
  Relancer aussitôt : avis au lancement « 25 % — paid in full less than 60 min ago »,
  750 / 609 €$ à la fin. Sept paies pleines dans la journée : la septième paie 25 %.
- Tomber à terre en ville, attendre 90 s, « Give up » : l'écran annonce 300 €$, la
  banque baisse de 300 (ou de ce qu'il reste, jamais en dessous de zéro). Un
  personnage de moins de 120 min de jeu n'est pas facturé. Réanimé avec un kit : rien.
- Cabine publique en ville, enregistrer un look : −50 €$, une seule fois par visite ;
  la cabine du logement et l'assistant de création restent gratuits.
- `/lightrp.account me` et `/bank` montrent les lignes `mission`, `gig`, `hospital`,
  `fitting`.

## 9. Risques

- **Baisse forte des missions** (÷5 à ÷10) : les joueurs qui ont connu l'ancienne
  version la ressentiront. Les soldes existants ne sont ni effacés ni migrés : les
  premiers comptes gardent leur avance.
- **Estimations de revenu horaire** : elles reposent sur une vitesse et une
  manutention supposées ; à recaler avec les journaux `lightrp_transactions` après
  quelques jours (somme des `kind` par heure de jeu).
- **Paie à l'inactivité** : relever les paies relève aussi ce que rapporte un joueur
  immobile (100 – 500 €$ par 30 min selon le métier).
- **Recharge et plafond** sont en base (`lightrp_mission_payout_cooldowns`,
  `lightrp_mission_payout_daily`) ; sans base de données ils ne vivent que le temps de
  la session.
- **Fusion** : `missions.lua` n'est touché qu'aux lignes de paie et par une ligne
  d'annonce au lancement ; les tests de missions, de raid et de gigs chargent désormais
  `server/config/economy.lua` et `server/modules/mission_pay.lua`.
