# Progression PvE : réputation, difficultés et cyberware

Proposition du 2026-11-03, d'après la consigne du propriétaire :

> « Ajouter du nouveau cyberware à la hauteur des niveaux de difficulté du contenu PvE ; le PvP
> ne fait qu'augmenter tes victoires, etc. »

Le PvE (missions, raid Chimera, gigs de fixers, activités PvE) est **le seul chemin de
progression** : il rapporte de la réputation, les paliers de réputation ouvrent les difficultés
supérieures **et** les rangs de cyberware supérieurs chez le ripperdoc, et le nouveau cyberware
de pointe correspond à la difficulté la plus dure. Le PvP (modes PvP de l'arène, courses de rue,
poursuite NCPD 1v1 / Most Wanted, Turf War PvP) ne donne **ni réputation ni puissance** :
victoires, statistiques, classements, rangs.

**Rien n'est fusionné avant que le propriétaire ait validé les chiffres ci-dessous.** Tous sont
dans la configuration (`server/config/missions.lua`, `server/config/activities.lua`,
`server/config/cyberware.lua`) et se règlent sans toucher au code.

## 1. Les paliers de réputation (« Street Cred »)

La réputation reste par personnage (`lightrp_mission_rep`). Les trois premiers seuils ne
changent pas (`0, 500, 1500`) : un personnage existant garde son palier. Deux paliers sont
ajoutés.

| Palier | Nom | Seuil | Écart | Ce qu'il ouvre |
|---|---|---:|---:|---|
| I | Street | 0 | — | Difficulté **Standard** partout ; cyberware rangs I–II |
| II | Merc | 500 | 500 | Difficulté **Hard** ; cyberware rang III |
| III | Operator | 1 500 | 1 000 | Difficulté **Critical** ; cyberware rang IV |
| IV | Edgerunner | 4 000 | 2 500 | Cyberware rang V (légendaires actuels + nouveaux) |
| V | Legend | 10 000 | 6 000 | Cyberware rang **V+** (nouveau haut de gamme) |

### D'où vient la réputation

| Source | Standard | Hard | Critical | Plafond |
|---|---:|---:|---:|---|
| Mission (Sector 04, missions de l'éditeur) | 100 | 220 | 450 | aucun |
| Raid Chimera | 100 | 220 | 450 | aucun |
| Gig de fixer | 100 | 220 | 450 | aucun |
| Activité PvE (par résultat, poids 1,0) | 30 | 60 | 100 | 500 / compte / jour |
| Activité PvP, course, poursuite, Turf War PvP | 0 | 0 | 0 | — |

Les montants des missions sont ceux d'aujourd'hui (`reputationGain`). Une mission ratée ne
rapporte rien. Une activité PvE pèse selon sa durée (§4).

### Temps pour atteindre chaque palier

Hypothèse « joueur régulier qui fait du PvE » : file d'attente, trajets et échecs compris
(réussite estimée 85 % en Standard, 70 % en Hard, 55 % en Critical), il gagne environ
**180 réputation/h** en Standard, **280/h** en Hard et **350–400/h** en Critical, missions et
activités PvE mêlées. Base d'environ 1 h 30 de PvE par jour de jeu.

| Palier | Heures de PvE cumulées | Calendrier (≈ 1 h 30/jour) | Joueur assidu (≈ 3 h/jour) |
|---|---:|---|---|
| II Merc | ≈ 3 h | 2e soir | 1er soir |
| III Operator | ≈ 6–7 h | fin de la 1re semaine | 3e jour |
| IV Edgerunner | ≈ 13–14 h | ≈ 2 semaines | ≈ 1 semaine |
| V Legend | ≈ 30 h | ≈ 3–4 semaines | ≈ 1,5–2 semaines |

Le palier V est l'objectif de fond des premières semaines après l'ouverture. Abaisser son seuil
à 8 000 le ramène à ≈ 25 h (question au propriétaire, §8).

## 2. Ce que chaque palier ouvre

| | I Street | II Merc | III Operator | IV Edgerunner | V Legend |
|---|:-:|:-:|:-:|:-:|:-:|
| Missions et raid : Standard | ● | ● | ● | ● | ● |
| Missions et raid : Hard | | ● | ● | ● | ● |
| Missions et raid : Critical | | | ● | ● | ● |
| Gigs de fixers proposés jusqu'à | Standard | Hard | Critical | Critical | Critical |
| Activités PvE : difficulté max | Standard | Hard | Critical | Critical | Critical |
| Cyberware : rang max | II | III | IV | V | V+ |

**Missions et raid.** Une difficulté s'ouvre quand le palier est atteint **et** que la difficulté
précédente a été réussie au même point (l'échelle actuelle « Standard avant Hard » est gardée :
on apprend la mission avant de la durcir). Les deux conditions se règlent séparément
(`reputation.requireTier`, `reputation.requireClear`). Le palier requis vient de l'id de la
difficulté (`standard` → I, `hard` → II, `critical` → III) : les missions de l'éditeur, qui n'ont
pas de palier, suivent la même règle. Chaque membre d'une escouade doit avoir le palier.

**Gigs de fixers.** Le fixer ne propose au propriétaire du gig que des difficultés de son palier.
Un équipier invité par partage peut être d'un palier inférieur (le propriétaire se porte garant),
mais il ne gagne que la réputation de la difficulté la plus haute que son palier autorise : un
Street porté dans un gig Critical gagne 100, pas 450. Cela empêche le « boost » sans interdire de
jouer entre amis.

**Activités PvE.** Le noyau refuse de rejoindre une difficulté au-dessus du palier du joueur. Un
équipier entré par le fournisseur sans être passé par le panneau est vérifié au moment du
résultat : sa réputation est calculée sur la difficulté la plus haute de son palier.

## 3. Le cyberware après le changement

Règle : un implant exige le palier de réputation de son rang. Rangs I–II → palier I (ouvert à
tous, y compris aux joueurs purement RP), III → II, IV → III, V → IV, V+ → V. Le serveur refuse
l'installation (message « Street cred too low ») ; la clinique affiche l'implant verrouillé avec
le palier demandé. La **dépose** reste toujours possible. Un implant **déjà posé** au-dessus du
palier reste actif (rien n'est retiré à personne). La commande staff `/lightrp.cyberware <id> give`
ignore le palier.

Le nouveau haut de gamme est volontairement fait d'effets que la plateforme applique déjà sur la
dist 177 : statistiques passives (vie max, armure, endurance, régénérations) et nouveaux préréglages
de Dash et d'Overdrive (une nouvelle définition par préréglage, aucune définition existante n'est
modifiée). Pas de nouvelles jambes ni de nouveaux bras : leurs définitions durables sont
immuables, en ajouter un grade imposerait un changement de version sur des implants déjà payés.

| Implant | Système | Rang | Palier | Prix (€$) | Effet |
|---|---|:-:|:-:|---:|---|
| Iron Lungs | Circulatoire | II | I | 6 000 | +40 endurance max |
| Subdermal Armor | Tégumentaire | II | I | 6 500 | +30 armure |
| Titanium Bones | Squelette | II | I | 7 500 | +25 vie max |
| Reinforced Tendons | Jambes | II | I | 9 500 | Double saut (15 endurance) |
| Adrenaline Booster | Circulatoire | III | II | 8 500 | +8 endurance/s |
| Biomonitor | Circulatoire | III | II | 9 000 | +1,5 vie/s |
| Fortified Ankles | Jambes | III | II | 11 000 | Aucun dégât de chute |
| Neofiber Actuators | Nerveux | III | II | 13 000 | Dash, 1 charge |
| Gorilla Arms | Bras | III | II | 15 000 | Poings hydrauliques, non létaux |
| Subdermal Armor Mk.2 | Tégumentaire | IV | III | 16 000 | +60 armure |
| Kinetic Impact Frame | Squelette | IV | III | 18 000 | Ground Slam |
| Reinforced Tendons Mk.2 | Jambes | IV | III | 24 000 | Double saut (8 endurance, 0,5 s) |
| Epimorphic Skeleton | Squelette | IV | III | 24 000 | +60 vie max |
| Sandevistan Mk.1 | Système | IV | III | 26 000 | Overdrive 10 s |
| Mantis Blades | Bras | IV | III | 28 000 | Lames d'avant-bras |
| Neofiber Actuators Mk.2 | Nerveux | IV | III | 30 000 | Dash, 3 charges |
| Gorilla Arms Mk.2 | Bras | IV | III | 36 000 | Poings industriels, charge létale |
| **Iron Lungs Mk.2** *(nouveau)* | Circulatoire | V | IV | 34 000 | +80 endurance max |
| **Adrenaline Booster Mk.2** *(nouveau)* | Circulatoire | V | IV | 36 000 | +15 endurance/s |
| **Bioplastic Blood Vessels** *(nouveau)* | Circulatoire | V | IV | 42 000 | +3 vie/s |
| Electric Mantis Blades | Bras | V | IV | 62 000 | Lames, tranchant électrique |
| Sandevistan Mk.3 | Système | V | IV | 64 000 | Overdrive lourd, 2 charges |
| **Neofiber Actuators Mk.3** *(nouveau)* | Nerveux | V+ | V | 85 000 | Dash, 3 charges, 5 endurance, 0,3 s, recharge 1 s |
| **Aegis Dermal Plating** *(nouveau)* | Tégumentaire | V+ | V | 90 000 | +100 armure |
| **Rara Avis** *(nouveau)* | Squelette | V+ | V | 95 000 | +100 vie max |
| **Zetatech Apogee** *(nouveau)* | Système | V+ | V | 120 000 | Overdrive lourd 11 s, 2 charges, recharge 22 s, 30 endurance |

Fourchettes de prix : rang II 6–10 k, III 8–15 k, IV 16–36 k, V 34–64 k, **V+ 85–120 k**. Les
familles restent un seul emplacement natif : un modèle supérieur remplace l'inférieur, rien ne
s'additionne (Rara Avis remplace Epimorphic Skeleton, Aegis remplace la Subdermal Armor…).

Ordre de grandeur, palier V tout équipé : 200 vie + 100 armure, soit environ trois fois la
résistance d'un corps nu. C'est voulu pour le Critical (dégâts ennemis × 1,6, barrage Chimera à
55) ; c'est aussi la raison de la question PvP du §8.

Les prix du haut de gamme dépendent des gains que l'agent économie fixe pour les missions et les
gigs : ils sont à revoir avec lui avant validation.

## 4. Les difficultés des activités PvE

Mêmes trois difficultés que les missions, mêmes multiplicateurs que l'éditeur de missions
(`shared/mission_defs.lua`), pour que « Hard » veuille dire la même chose partout.

| | Standard | Hard | Critical |
|---|:-:|:-:|:-:|
| Palier minimum | I | II | III |
| Réputation de base (victoire, poids 1,0) | 30 | 60 | 100 |
| Nombre d'ennemis | × 1 | × 1,5 | × 2 |
| Vie des ennemis | × 1 | × 1,5 | × 2,25 |
| Dégâts des ennemis | × 1 | × 1,25 | × 1,6 |
| IA | `standard` | `veteran` | `veteran`, agressive, pas de réapparition joueur si le mode le permet |

Le noyau transmet au fournisseur `options.difficulty` (`standard` | `hard` | `critical`) et
`options.scaling = { enemies, health, damage, ai }` tirés de `server/config/activities.lua`
(`pve.difficulties`) : le propriétaire règle tout au même endroit, le fournisseur traduit dans son
moteur.

**Réputation par résultat** = réputation de base de la difficulté × poids de l'activité, arrondie.
Si le fournisseur n'envoie pas de `reputation`, une victoire (`won = true`) rapporte le montant
plein et une défaite rien ; s'il en envoie une (crédit partiel, une 2e place), le noyau la borne au
montant plein. Plafond quotidien commun aux activités PvE : **500 par compte** (tous ses
personnages), par jour UTC.

| Activité | Poids | Standard | Hard | Critical | Pourquoi ce poids |
|---|:-:|---:|---:|---:|---|
| `arena.pve` Combat Zone · PvE | 1,0 | 30 | 60 | 100 | manche d'environ 10 min |
| `race.pve` Street Race vs AI | 0,5 | 15 | 30 | 50 | course de 2 à 5 min |
| `turf.pve` Gang Sweep | 1,2 | 36 | 72 | 120 | nettoyage d'environ 15 min |
| `chase.pve` NCPD Escape | 0,6 | 18 | 36 | 60 | fuite de 3 à 6 min |

## 5. Le côté PvP

- **Aucune réputation**, quel que soit le montant que le fournisseur propose : le noyau met la
  réputation à 0 pour toute activité qui n'est pas PvE. La notice de fin le dit sans « +rep ».
- Conservé tel quel : parties, victoires, kills, morts, meilleur score / temps / place
  (`lightrp_activity_stats`), classements du panneau (top 5, au temps pour les courses), et les
  classements propres aux fournisseurs (cote de l'arène classée, poursuite classée, influence
  hebdomadaire des gangs de Turf War).
- Rappel : l'activité `arena.pve` s'enregistre aujourd'hui avec `kind = "pvp"`. Le genre ne suffit
  donc pas à reconnaître le PvE, d'où le drapeau explicite `pve = true` (§6).
- Retour arrière possible : `reputation.pvpGrants = true` rend l'ancien comportement (réputation
  PvP bornée à 50 par résultat).
- **Option, non implémentée : titres cosmétiques.** Un titre par activité selon les victoires
  (10 « Contender », 50 « Veteran », 200 « Champion »), affiché dans le panneau et le classement.
  Aucun effet de jeu. À décider (§8).

## 6. Le contrat pour les fournisseurs (ajouts rétrocompatibles)

- `activityRegister(def)` accepte `def.pve = true` (les résultats rapportent de la réputation) et
  `def.difficulties = { "standard", "hard", "critical" }` (les difficultés que le fournisseur sait
  vraiment jouer ; un id inconnu est ignoré). Sans `pve`, la liste `pve.activities` de la config
  peut marquer une activité comme PvE (c'est le cas de `arena.pve`, `race.pve`, `turf.pve` et
  `chase.pve` en attendant que chaque fournisseur pose le drapeau). `pve = false` l'emporte sur la
  liste. Une activité PvE sans `difficulties` n'a qu'une difficulté implicite, Standard.
- Le panneau propose la difficulté (cadenas et palier requis sur celles qui sont fermées) ; le
  noyau refuse la demande au-dessus du palier et transmet `options.difficulty` et
  `options.scaling`.
- `activityCheck(id, activityId, { difficulty })` : vérifie aussi le palier (pour les équipiers
  qu'un fournisseur fait entrer avec un chef de groupe).
- `activityEnter(id, activityId, { difficulty })` : refuse au-dessus du palier et retient la
  difficulté sur l'entrée ; sans ce troisième argument, l'entrée reprend celle de la demande du
  panneau.
- Résultat : `result.difficulty` facultatif (utilisé seulement si l'entrée n'en a pas). La
  réputation suit le §4.
- Rien ne change pour un fournisseur PvP : ses résultats sont enregistrés comme avant, à 0 de
  réputation.

### Ce que chaque fournisseur PvE doit changer (suivi)

| Fournisseur | À faire |
|---|---|
| `op77_arena` (`arena.pve`) | `pve = true`, `difficulties = { "standard", "hard", "critical" }` ; lire `options.difficulty` / `options.scaling` à la demande et les garder sur l'instance (une instance par difficulté, ou refuser de mélanger) ; bots : `botsFirst`/`botsPerPlayer` × `scaling.enemies` (plafond `botsMax`), profil `relaxed`→`standard` / `veteran` / `veteran`, vie et dégâts des bots × `scaling` si le moteur le permet ; résultat : `difficulty`, `won` et **ne plus envoyer `reputation`** (ou une part ≤ au montant plein) ; garder `minRoundMs` ; corriger `kind = "pvp"` n'est pas nécessaire. |
| `op77_race` (`race.pve`) | `pve = true`, `difficulties` ; Hard : pilotes IA plus rapides (≈ +5 % de vitesse cible, rattrapage réduit), Critical : grille pleine, +10 %, pas d'aide au rattrapage ; réputation : victoire = montant plein (omettre), podium = moitié en crédit partiel, sinon 0 ; garder `minimumMetres` / `minimumSeconds`. |
| `op77_turf` (`turf.pve`, à venir) | `pve = true`, `difficulties` ; vagues : nombre d'ennemis × `scaling.enemies`, vie / dégâts × `scaling`, Critical : ennemis blindés et chrono serré ; résultat avec `difficulty` et `won`. Turf War PvP inchangé (0 réputation, influence de gang conservée). |
| `op77_chase` (`chase.pve`, à venir) | `pve = true`, `difficulties` ; niveau de recherche et nombre de poursuivants NCPD × `scaling.enemies`, MaxTac en Critical ; résultat : `won` = évadé. 1v1 et Most Wanted inchangés (0 réputation). |

Tous : lire `options.squad` comme aujourd'hui, et appeler `activityCheck(membre, id, { difficulty })`
avant de faire entrer un équipier qui n'est pas passé par le panneau.

## 7. Implémentation (branche `lightrp/pve-progression`)

- `server/config/missions.lua` : cinq seuils, noms des paliers, palier par difficulté,
  `requireTier` / `requireClear`.
- `server/modules/missions.lua` : `Missions.tierInfo`, `Missions.requiredTier`,
  `Missions.tierAllows`, `Missions.reputationFor` ; le tableau de mission montre et applique le
  palier requis ; la réputation d'un gig suit le palier de chaque équipier.
- `server/modules/fixers.lua` : le fixer ne tire que des difficultés du palier du propriétaire.
- `server/config/activities.lua` + `server/modules/activities.lua` : `pve`, `difficulties`, porte
  de difficulté, réputation PvE par difficulté et par poids, PvP à 0, palier dans l'état du panneau,
  crochet `onActivityChanged` pour les modules.
- `server/config/cyberware.lua` + `server/modules/cyberware.lua` : sept implants, palier par rang,
  refus serveur, catalogue verrouillé envoyé à la clinique, interrupteur `activeInPvp`.
- Clinique (`ripperdoc-ui`) : implants verrouillés avec le palier demandé, réputation du patient
  dans l'en-tête. **Le bundle `op77_ripperdoc/web` n'est pas reconstruit dans la branche** : à
  reconstruire au moment de fusionner (`npm run build` dans `ripperdoc-ui`).
- Panneau Activités et tableau de mission (`ui/`) : choix de difficulté verrouillé, palier requis,
  palier du joueur.

## 8. À décider par le propriétaire

1. **Cyberware en PvP classé.** Aujourd'hui les implants restent actifs dans toutes les activités
   (sauf les lames Mantis, refusées quand l'activité range les armes RP). Faut-il les couper en PvP
   par équité ? Interrupteur `LightRpCyberwareConfig.activeInPvp`, **par défaut `true`
   (comportement actuel)**. À `false`, entrer dans une activité non PvE suspend Dash, Overdrive,
   Ground Slam et les bonus passifs, rendus à la sortie. Limite : les jambes et bras durables
   (double saut, Gorilla Arms) restent actifs, la plateforme les tient en enregistrement durable.
2. **Seuils** `0 / 500 / 1 500 / 4 000 / 10 000` et noms des paliers.
3. **Prix du haut de gamme** (85–120 k) à caler sur les gains de missions de l'agent économie.
4. **Échelle des missions** : garder « réussir la difficulté précédente » en plus du palier ?
5. **Équipiers sous le palier** : refusés aux tableaux de mission (chaque membre doit avoir le
   palier), acceptés dans un gig partagé avec la réputation de leur palier. Convient-il ?
6. **Implants déjà posés** au-dessus du palier : conservés (proposé) ou déposés et remboursés ?
7. **Titres cosmétiques PvP** : oui / non.
8. **Réputation des activités PvE** : 30 / 60 / 100 par résultat, poids par activité, 500 par
   jour.

## 9. Vérifier en jeu

1. `/missions.rep <id> 0`, ouvrir le tableau Sector 04 : Hard et Critical verrouillés, « REP TIER
   II » / « REP TIER III ». `/missions.rep <id> 500` puis `/missions.unlock <id> sector04_blackout
   standard` : Hard s'ouvre. `/missions.rep <id>` seul affiche le palier.
2. S'asseoir sur une chaise de ripperdoc à 0 réputation : les rangs III et plus sont marqués « REP
   II » à « REP V », l'installation est refusée côté serveur ; à 10 000 tout s'ouvre.
3. Panneau Activités : `Combat Zone · PvE` propose Standard / Hard / Critical, les difficultés au-
   dessus du palier sont fermées ; une demande forcée (`/activity join arena.pve`) en Hard à 0
   réputation est refusée.
4. Une manche `arena.ffa` : la notice de fin n'affiche plus de réputation, le classement compte la
   victoire.
5. `LightRpCyberwareConfig.activeInPvp = false`, `ensure op77_lightrp`, entrer en `arena.duel` avec
   un Sandevistan : `/lightrp.cyberware <id> status` montre `overdrive=none` pendant le duel, la
   concession revient au retour.
