# Safezones et création visuelle

Le module ajoute des zones statiques qui refusent le PvP avant application du
dégât. Un coup est refusé si sa victime **ou** son attaquant se trouve dans une
zone active de son routing bucket. Les dégâts du monde non attribués à un
autre joueur gardent leur politique ; ce module n'est pas un god mode général.

## Gestion staff

Le bureau `/admin` ouvre le gestionnaire de zones ; `/safezones` fournit aussi
une entrée directe, avec le droit de commande correspondant. Le gestionnaire
permet de créer un cercle/cylindre, une boîte orientée ou un polygone avec
plancher et plafond. Le placement utilise la position acceptée par le serveur.
La prévisualisation est un brouillon : elle ne protège personne avant publication.

Trois cases configurent chaque zone :

- **Interdire de courir** : force la marche et bloque le sprint ; la préférence
  de déplacement précédente est restaurée à la sortie, sans empêcher une marche lente.
- **Interdire de tirer** : bloque la commande native de tir. Décocher permet
  l'animation de tir, mais ne retire pas la protection PvP serveur de la safezone.
- **Toute la hauteur (haut et bas)** : le contour horizontal s'applique à tous
  les étages, au ciel et au sous-sol. Plancher/plafond sont conservés dans le
  brouillon mais ignorés tant que cette case est cochée.

Les anciennes zones reçoivent les valeurs `blockRun=false`, `blockShoot=true`,
`fullHeight=false`, sans réécriture SQL obligatoire. Les règles des zones qui
se chevauchent se cumulent : une restriction active suffit. Leur état apparaît
dans le HUD bas-gauche, au-dessus des jauges, uniquement en phase de jeu.

Six restrictions supplémentaires sont indépendantes, décochées par défaut :

| Champ | Case de l'éditeur | Action native |
| --- | --- | --- |
| `blockJump` | Interdire de sauter | `Jump` (peut aussi bloquer le franchissement) |
| `blockMelee` | Interdire le corps à corps | `Melee` |
| `blockGrenades` | Interdire les grenades | `Grenade` |
| `blockConsumables` | Interdire les consommables natifs | `Consumable` |
| `blockReload` | Interdire de recharger | `Reload` |
| `blockWeaponWheel` | Bloquer la roue des armes | `WeaponWheel` |

Les consommables natifs sont les raccourcis de soins du jeu ; cette case ne
bloque pas la nourriture et les boissons de l'inventaire RP. Le changement
d'arme reste disponible : aucune restriction `NextWeapon` n'est appliquée.
Les drapeaux sont validés comme booléens, persistés dans la définition JSON et
agrégés sur toutes les zones superposées. Le contrat partagé `G.RULES` aligne
validation, cumul serveur, présence et claims client. Une modification de règle
est diffusée même si le joueur reste dans la même zone.

Le MCP Devkit `.156` confirme ces actions pour `input.actions`. Les mécanismes
`Jump` et `Melee` y restent qualifiés d'inférés : vérifier leur effet natif sur
le client cible ; une simulation Lua ne prouve pas le comportement REDengine.

Les droits joueur sont vérifiés sur chaque opération :

- `command.admin.safezones.view` : consulter et ouvrir le gestionnaire.
- `command.admin.safezones.edit` : capturer une session et préparer une zone.
- `command.admin.safezones.publish` : créer/modifier/activer une zone.
- `command.admin.safezones.delete` : supprimer une zone.
- `command.safezones` : entrée par la commande directe restreinte.

Publier demande `view`, `edit` et `publish` ; supprimer demande `view`, `edit`
et `delete`. Les permissions de ressource, dont `combat.config`, sont déclarées
séparément dans le manifeste. Aucun privilège staff implicite ne permet de
tirer dans une zone protégée.

## Limites et stockage

Une session est liée au joueur, à son bucket et à un point capturé côté serveur.
Elle expire après cinq minutes sans capture/heartbeat et est invalidée si le
joueur change de bucket, perd son droit d'édition ou s'éloigne de plus de 500 m.
Le volume entier publié doit rester à 500 m de cette ancre. Supprimer ne demande
pas de se déplacer jusqu'à la zone, mais exige une session valide.

Limites de cette version : 64 zones non supprimées au total, 3–32 sommets par
polygone, rayon de 0,5–250 m, longueur/largeur de boîte de 0,5–500 m, hauteur
de 0,1–200 m, coordonnées finies dans ±100 000. Les polygones croisés, touchant
leurs propres arêtes, de surface trop faible ou avec sommets répétés sont refusés.
Leur étendue sur X et Y ne peut pas dépasser 500 m.

Les définitions canoniques sont stockées dans `lightrp_safezones`. Chaque
mutation et sa réponse sont enregistrées dans `lightrp_safezones_audit` avec
une clé unique acteur/mutation. Une transaction persiste zone et audit avant
publication. Les retries réutilisent leur clé, les modifications présentent
`baseRevision`, et une seule publication peut traverser la section SQL à la fois.
L'insert d'audit exige que le `ROW_COUNT()` de l'écriture de zone soit égal à 1 ;
un conflit SQL qui affecte zéro ligne fait échouer la contrainte NOT NULL de
l'auteur et annule la transaction entière, même avec un autre écrivain SQL.
Une suppression conserve une tombstone et incrémente la révision.

Une panne d'écriture conserve l'ancienne zone active et le brouillon côté UI.
Au démarrage, toutes les données sont validées et normalisées avant que le
module annonce `ready`. Des données invalides rendent le module indisponible.
Si l'arbitre est installé mais le chargement n'est pas prêt, le PvP est refusé
jusqu'à la disponibilité de la politique ; cela ne bloque pas les dégâts sans
attaquant joueur. Un moteur sans API d'arbitrage ne peut pas assurer cette
protection : le module expose l'indisponibilité et ne doit pas être présenté
comme opérationnel.

## Autorité et HUD

`Open77.combat.onDamage` porte la règle serveur ; ni le booléen client ni la
notification après dégât ne décident de l'immunité. Le handler ne fait aucun
appel SQL, réseau ou yield. Il utilise des géométries normalisées en mémoire et
`Open77.zones.containsPlayer` sur les positions serveur, avec bucket explicite,
`maxAgeMs=2000` et `grace=0`. Une lecture inconnue
dans un bucket avec zone active refuse le coup ; une erreur d'arbitre refuse
également le dégât et journalise avec limitation de fréquence.

Les snapshots portent `generation` et uniquement les zones publiées non
supprimées. Un événement de présence serveur donne la zone et son nom pour le
HUD, au plus vite sur une boucle de 500 ms ; il sert uniquement à l'affichage.
Les champs audit et identités d'auteur ne sont pas envoyés aux joueurs.

La protection des collisions de véhicules, PNJ natifs et effets du monde dépend
de leur passage et de leur attribution dans le pipeline de dégâts. Les tirs
entre joueurs entrants et sortants constituent le périmètre garanti à valider
en jeu. Pas de changement des équipes, friendly fire global, santé ou god mode.

La géométrie en hauteur complète reste exacte horizontalement : polygone sans
bornes Z ; cercle et boîte interrogés à l'altitude du joueur avec `options.origin`
sur le même snapshot frais contrôlé par `containsPlayer`. Le dessin de l'éditeur
montre seulement une tranche locale, pas des murs infinis.

Les commandes client sont des claims `Sprint`/`Attack` de `input.actions`,
libérés en sortie, indisponibilité de politique, mort et arrêt de ressource.
Le mode marche conserve séparément le choix du joueur, pour que la touche de
déplacement ne puisse pas contourner la restriction ou perdre ce choix.

## Contrat réseau

Événement dédié `op77_lightrp:safezones` :

- Requête `{request, operation, ...}` ; `snapshot` est ouvert aux joueurs,
  `open/list` nécessitent la lecture et les autres opérations leurs droits.
- Réponse `{kind:'response', request, ok, data?, error?}`.
- `capture` reçoit éventuellement `session` pour continuer la même ancre ;
  sans session elle ouvre une nouvelle ancre. Résultat `{position,bucket,session}`.
- `save` reçoit `{zone,baseRevision,mutation,session}`, répond `{zone}`.
- `delete` reçoit `{id,baseRevision,mutation,session}`, répond `{id}`.
- `heartbeat` reçoit `{session}` ; `cancel` libère la session courante.
- Push `{kind:'snapshot',ready,zones,generation}`, `{kind:'presence',ready,zone?}`
  et `{kind:'invalidate',error}`. Les nouvelles connexions peuvent demander un
  snapshot après disponibilité de la page.

Les requêtes sont limitées par joueur ; sérialiser les requêtes UI et ne jamais
publier à chaque mouvement de prévisualisation. Les retries après délai gardent
la même clé de mutation. Le client ne choisit pas les IDs des nouvelles zones.

## Validation locale

`python3 tools/test-safezones.py` exécute les vrais modules Lua avec Lupa/Lua 5.4,
un host et un adaptateur SQL isolés en mémoire. Il ne lit aucun `server.env` et
ne se connecte à aucune base. Il couvre ACL, validation, session, frontières,
hauteur, bucket, stale snapshots, publication/rollback/reload, idempotence,
révision, exclusion des publications concurrentes et erreur d'arbitre.

Pour utiliser une MariaDB locale de test, définir `SAFEZONES_TEST_SOCKET` vers
son socket Unix (et, si nécessaire, `SAFEZONES_TEST_USER` et
`SAFEZONES_TEST_PASSWORD`). Le test crée puis supprime sa propre base
`open77_safezones_test_*` et vérifie aussi un conflit SQL indépendant avec
rollback de l'audit. L'utilisateur SQL doit pouvoir créer cette base de test.
Il faut alors installer `pymysql` en plus de Lupa ; aucun hôte TCP ni nom de
base de production ne peut être passé au runner.

Compléter avec une base de test et un serveur/client cibles pour vérifier les
bindings réels, le rendu, les entrées, la persistance après redémarrage et les
tirs de deux joueurs de part et d'autre de la frontière. Les mocks UI ne
remplacent pas ces contrôles natifs.
