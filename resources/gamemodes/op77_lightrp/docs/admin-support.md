# Bureau staff RP et reports

## Accès en jeu

- `/admin` (et `/lightrp.admin`) ouvre le menu admin **LIGHT/RP**, au même
  emplacement que le menu joueur. C'est le seul menu admin du serveur : il
  réunit l'ancien menu compact de la plateforme et le bureau staff (voir
  « Menu admin unifié » plus bas).
- `/report` et `/reports` ouvrent les dossiers privés du joueur.
- `/report message` ouvre un nouveau brouillon prérempli. Le joueur complète
  la catégorie et le sujet avant d'envoyer.
- **F1 → Reports & support** donne accès au même suivi. L'entrée staff apparaît
  selon les droits du compte.
- **↑ / ↓** sélectionnent une ligne, **Entrée** ouvre le sous-menu ou l'action.
  **← / →** changent les filtres et cases à cocher.
- **Retour arrière / Échap** remontent d'un niveau, puis ferment à la racine.
  La ligne sélectionnée est conservée au retour.
- Les déplacements et la caméra restent disponibles dans les listes. Le clavier
  et le curseur sont capturés uniquement pendant la saisie d'un formulaire.
  **Échap** quitte ce formulaire et revient au menu.
- Les conversations et fiches apparaissent dans un panneau voisin. **Page Up /
  Page Down** font défiler ses détails. La ligne **Conversation** permet de
  masquer ce panneau pendant le traitement d'un dossier.
- `/adminfull` conserve la console technique officielle, avec son ACL habituelle.

`op77_lightrp` enregistre lui-même `/admin` (droit `command.admin`, le même que
la plateforme). Le serveur cherche une commande dans les ressources lancées par
ordre ordinal de nom, et `op77_lightrp` passe avant `open77_admin` : c'est donc
ce menu qui répond. Le menu compact de la plateforme ne s'ouvre plus par-dessus.
Aucune modification de `open77_admin` n'est nécessaire, et une mise à jour de la
distribution ne casse rien. Sans LightRP, le `/admin` officiel reste disponible.

## Menu admin unifié

Les outils de la plateforme et ceux de LightRP sont lancés depuis le menu sous
forme des commandes restreintes qu'ils sont déjà (`open77:command:execute`). L'ACL
de l'hôte décide donc de chacune, comme si elle était tapée. La page n'accorde
rien : la vue d'ensemble envoie la liste des commandes autorisées pour
l'opérateur (`server/modules/admin.lua`, `COMMANDS`, une seule chaîne) et masque
le reste. La réponse de chaque commande s'affiche sous le menu, en vert si elle a
réussi, en rouge si elle a été refusée.

| Section | Contenu |
| --- | --- |
| Reports | file des dossiers (inchangé) |
| Players | fiche RP, puis aller à / ramener / spectate / soigner / ranimer / envoyer vers un lieu ; groupes **Moderation** (avertissement, kick, ban audités, god mode, kill), **Character & money** (nom, job, affiliation, argent audités, faim et soif, street cred, compte), **Give** (objet, véhicule au garage, véhicule à côté), **Missions & activities** (gig, mission en cours, contrats, salle TCG) |
| Personal tools | noclip, fly, vitesse, god mode, soin, réanimation, faim et soif, compte, console plateforme (`/adminfull`) |
| Teleport | sur la carte (double-clic), coordonnées, lieux de `LightRpConfig.locations`, ramener tout le monde |
| Vehicles | catalogue LightRP (`lightrp.car`), n'importe quel record du jeu, réparer et refaire le plein (`lightrp.repair`), plein seul, fourrière, locations, consommation, nettoyage, tout supprimer |
| Items & weapons | chaque objet du serveur par catégorie (armes et munitions comprises), à soi-même |
| World | **Time** (préréglages, heure exacte, figer, reprendre), **Weather** (chaque météo, suivante, aléatoire), **Announcements & voice** (annonce, broadcast vocal serveur / 150 m / off) |
| Missions & events | éditeur de missions ; **World bosses** (planning, lancer, lancer celui choisi, programmer, finir en victoire, annuler), **Fixer gigs**, **Contracts & activities** (contrats du jour, activités, turf, Dogtown, salles TCG) |
| Places & content | tables posées, Maneki-neko, housing, safe zones, panneau des jobs, PNJ guide, hall of fame |
| Server | statut LightRP et plateforme, bots d'ambiance, ramener tout le monde, tout supprimer, annuler l'action de masse, console plateforme |
| Staff history | journal des interventions auditées |

Les actions destructrices (kill, ramener tout le monde, tout supprimer, fourrière,
fin de world boss, arrêt du turf) passent par une étape **Confirm?**, avec
**Cancel** sélectionné et la commande exacte affichée. Les listes (véhicules,
objets, lieux, météos) viennent de `adminCatalog`, sous forme de lignes `a|b|c`
pour rester sous la limite de 1024 valeurs d'un événement réseau. Le clic droit
sur un véhicule ou une porte (`open77_contextmenu`) ouvre toujours les actions
ciblées de la plateforme.

Test : `tests/admin_menu_test.lua` vérifie l'enregistrement de `/admin`, la
projection ACL, la taille du catalogue et `/lightrp.repair`. En dev, le menu
s'ouvre avec `ui` + `?admin=1`.

## Parcours joueur / admin

1. Le joueur crée un report : catégorie, sujet, description et éventuellement
   un autre joueur connecté. Le serveur enregistre le compte, le personnage,
   la position et l'instance. Les liens de preuves peuvent être collés dans le
   texte ; il n'y a pas d'envoi de pièces jointes.
2. Les admins autorisés reçoivent une notification. **Take this case** affecte
   le dossier à l'admin et passe son statut à **In progress**. Le joueur voit
   qui s'en occupe et si cet admin est connecté.
3. Les deux côtés répondent dans la conversation. **Ask player for information**
   attend une réponse ; la réponse du joueur remet le dossier en cours.
4. **Internal staff note** ajoute une note privée, uniquement envoyée aux
   comptes disposant du droit de consultation des reports.
5. L'admin assigné ou un superviseur explique la résolution puis utilise
   **Resolve case**. Le joueur peut aussi fermer son propre dossier avec une raison.
6. Les dossiers terminés restent consultables avec **Finished / All cases**.
   Le propriétaire peut demander une réouverture motivée pendant sept jours.
   Une réouverture remet le dossier dans la file sans admin assigné.

Les réponses, affectations, statuts et notes persistent après déconnexion et
redémarrage. Le propriétaire est le **compte Open77**, indépendamment du slot
de personnage. Les noms du personnage et du joueur signalé sont ceux du moment
du signalement. Un transfert vers un autre admin connecté demande un droit
supplémentaire. Quitter le serveur ne désaffecte pas automatiquement un dossier.

| Statut | Signification |
|---|---|
| `open` | Attend la prise en charge du staff |
| `in_progress` | Dossier pris en charge / réponse du joueur reçue |
| `waiting_player` | Le staff attend une précision du joueur |
| `resolved` | Résolution expliquée par le staff |
| `closed` | Dossier fermé avec une raison |

La file propose recherche par numéro, sujet ou nom, filtre de statut, dossiers
assignés à soi, priorité normale/urgente et indicateur de nouveautés. Les lectures
joueur et staff sont indépendantes. Les changements sont poussés aux personnes
concernées ; un rafraîchissement toutes les douze secondes complète ce suivi.

## Fiches RP et interventions

**Citizens** affiche le personnage, le nom du compte, le métier, l'affiliation
et l'état de vie. La fiche ajoute identité RP, histoire, argent liquide,
banque, position et historique autorisé. La sélection conserve aussi le compte
et le slot : si le numéro joueur est réutilisé ou le personnage changé,
l'intervention est refusée et il faut rafraîchir.

Selon les permissions : rejoindre un joueur, le ramener, le renvoyer à la
position précédant le dernier déplacement staff, soigner/réanimer, renommer,
changer métier/grade ou affiliation, créditer/débiter cash ou banque, avertir,
exclure, bannir temporairement/définitivement, publier une annonce.

Chaque intervention demande une raison et une confirmation indiquant la cible
et les valeurs choisies. Les changements RP attendent la fin de création du
personnage. Les déplacements entre instances sont refusés. La position de
retour est limitée à la session en cours et disparaît à la reconnexion.

L'intention est sauvegardée **avant** l'action dans `lightrp_staff_audit`, puis
son résultat (`success`, `failed`, `pending`). Un état `pending` signifie qu'il
faut contrôler la situation avant de recommencer. Réessayer la même requête ne
recrédite pas l'argent. L'historique conserve l'auteur, la cible, le personnage,
la raison, les paramètres et le résultat. Les avertissements sont conservés
dans cet historique ; ils ne déclenchent pas de sanction automatique.

## Tables posées

**Placed tables** (droit `command.lightrp.tables`) liste toutes les tables posées
(jeux de plateau et tables de casino) : identifiant, type, personnage
propriétaire et identifiant d'inventaire, connecté ou non, position, instance,
date de pose, révision, joueurs assis, phase et mises ouvertes (ou *Resolving*
pendant un tirage). Pages de 15, tri récentes / proches, recherche par
identifiant, type ou propriétaire.

- **Go to table** : téléportation à côté de la table, face à elle, via
  `LightRP.staff.moveTo`. Depuis une instance privée vers une table de la ville,
  arrivée en instance 0 ; une table dans une autre instance privée est refusée.
- **Remove table** (droit `command.lightrp.tabledelete`) : mêmes règles que le
  ramassage par le propriétaire. Les mises ouvertes sont remboursées, refus tant
  qu'une roue ou des rouleaux tournent, le croupier du blackjack disparaît, les
  joueurs assis sont levés avec une notification. *Give the item back* rend
  l'objet à l'inventaire du personnage propriétaire dans la même transaction ;
  hors ligne (ou inventaire plein), il est livré au prochain chargement de ce
  personnage.

Raison et confirmation obligatoires, audit dans `lightrp_staff_audit` avant et
après l'action (`tableTeleport`, `tableDelete`), visible dans **Staff history**.
Commandes équivalentes : `/lightrp.tables [page | near]`,
`/lightrp.tables tp <id>`, `/lightrp.tables delete <id> [return]` (la console
serveur peut lister et supprimer). Détails : `docs/board-games.md`.

Les outils personnels **Noclip**, **God mode** et **Advanced console** réutilisent
les commandes natives et leurs permissions. Leur journalisation reste celle
du package officiel ; `lightrp_staff_audit` couvre les interventions du bureau RP.
Les anciennes commandes staff restent disponibles.

## Permissions serveur

Les droits proviennent exclusivement de l'ACL de l'hôte. Le navigateur ne
fournit ni rôle ni identité faisant autorité. Toutes les lectures et mutations
sont contrôlées côté serveur, y compris après les lectures SQL asynchrones.

| Permission | Accès |
|---|---|
| `command.admin` | Bureau, liste des citoyens et fiches RP |
| `command.lightrp.reports` | File staff, conversations et notes privées, prise en charge |
| `command.lightrp.reportassign` | Transfert et gestion des dossiers d'autres admins |
| `command.lightrp.audit` | Historique des interventions staff |
| `command.lightrp.goto` | Rejoindre un joueur |
| `command.lightrp.bring` | Ramener / renvoyer un joueur |
| `command.lightrp.heal` | Soigner / réanimer |
| `command.lightrp.setname` | Renommer le personnage |
| `command.lightrp.setjob` / `setgang` | Métier / affiliation et grade |
| `command.lightrp.givemoney` / `takemoney` | Crédit / débit (crédit : motif obligatoire, 10 000 €$ au plus par don) |
| `lightrp.money.unlimited` | Crédit au-delà du plafond par don (`/lightrp.givemoney` et bureau) |
| `command.lightrp.warn` | Avertissement |
| `command.admin.moderate.kick` / `ban` | Exclusion / bannissement |
| `command.lightrp.announce` | Annonce serveur |
| `command.lightrp.tables` | Tables posées : liste et téléportation |
| `command.lightrp.tabledelete` | Tables posées : suppression |
| `command.admin.self.noclip` / `god` | Outils personnels |
| `command.adminfull` | Console technique |

Les suffixes abrégés dans ce tableau gardent le préfixe de la première permission.

Dons d'argent du staff (décision du propriétaire du 2026-11-04,
`docs/economy-balance.md` §16, réglages `staffGrants` de `server/config/economy.lua`) :
`/lightrp.givemoney <id|me> <cash|bank> <montant> <motif>` refuse un don sans motif
d'au moins 4 caractères (il répond l'usage) ; le motif devient la note de la ligne
`staff` du registre (`lightrp_transactions`, 160 octets au plus). Un don dépasse
10 000 €$ seulement si le donneur détient **`lightrp.money.unlimited`** ; la console
du serveur n'est pas plafonnée. Le *Crédit* du bureau suit la même règle (son motif
d'audit de 4 à 500 caractères est coupé à 160 octets pour la note). Cette permission
n'est volontairement **pas** sous `command.lightrp.*` : les rôles moderator/operator
qui détiennent ce joker ne la reçoivent pas ; seul `*` (le propriétaire) ou une ligne
explicite dans `acl.jsonc` l'accorde, par exemple pour un rôle « owner » :
`"lightrp.money.unlimited"`, puis `acl.reload`. Le débit (`takemoney`) n'est pas
plafonné.
Pour un rôle support minimal, accorder `command.admin` et
`command.lightrp.reports`. Ajouter `command.lightrp.reportassign` uniquement
aux superviseurs. La permission générique `command.lightrp.*` inclut ces nouveaux
droits ; les rôles moderator/operator existants en bénéficient déjà. Le rôle
helper actuel n'est pas élargi automatiquement : ajouter explicitement le droit
reports dans `acl.jsonc` si souhaité, puis exécuter `acl.reload` côté serveur. Le rôle helper du `acl.jsonc` d'exemple reçoit
`command.lightrp.tables` (liste et téléportation, sans suppression).

Le manifeste du gamemode utilise `players.disconnect` et `players.access` pour
les sanctions. Le bannissement passe par la liste d'accès persistante du serveur,
sur l'identité du compte, et déconnecte ses sessions. Warden / la console
officielle restent disponibles pour la gestion des dé-bannissements.

## Stockage et limites

Configuration serveur : `server/config/support.lua`.

- Trois dossiers actifs par compte, créations et réouvertures comprises.
- Une minute entre deux créations réussies.
- Réouverture pendant sept jours après résolution / fermeture.
- Sujet de 4 à 120 caractères, description de 10 à 2 000 caractères.
- Messages limités à 2 000 caractères ; raisons d'intervention à 500.
- Listes de 25 dossiers, historique chargé par blocs de 50 messages.

Les créations/réouvertures d'un même compte sont sérialisées, y compris depuis
deux sessions. Une révision unique par ticket protège les changements concurrents
de statut et d'affectation ; en cas de conflit, rafraîchir avant de renvoyer.
Les requêtes d'écriture ont une clé de déduplication. Le brouillon reste affiché
en cas d'échec ; fermer volontairement le panneau le quitte.

Tables : `lightrp_support_tickets`, `lightrp_support_messages`,
`lightrp_support_reads`, `lightrp_staff_audit`. Les anciennes lignes de
`lightrp_reports` sont importées au démarrage, avec leur indicateur de traitement,
sans suppression de la table d'origine. L'import peut être répété sans doublons.
Une base indisponible empêche les écritures et interventions auditées, sans
afficher une réussite fictive. Sauvegarder ces tables avec le reste de la base RP.

## Validation

- `python tools/test-tables-admin.py` : ramassage réservé au personnage
  propriétaire, liste, téléportation, suppression (remboursements, croupier,
  joueurs levés, retour d'objet différé), permissions et commandes.
- `python tools/test-support.py` depuis la racine : vrais modules Lua et
  transactions MySQL dans une base temporaire dédiée, supprimée en fin de test.
  Nécessite `pymysql`, `lupa` (Lua 5.4) et un accès local permettant de créer cette
  base. Les paramètres sont lus dans `server.env` sans être affichés.
- `tests/creator_bridge_test.lua` : priorité clavier, fermeture, masquage vocal,
  relais support et compatibilité avec l'éditeur de personnage.
- `ui/tests/support.browser.cjs` : menus RageUI, pile de navigation, sélection
  conservée, alternance navigation/saisie, création, réponses, erreur avec brouillon
  conservé, réouverture, notes, fiche RP, confirmation, historique et quatre
  dimensions d'écran. `UI_URL` pointe vers la page construite et
  `PLAYWRIGHT_MODULE` peut désigner une installation de Playwright.
- `npm run build` depuis `ui` : vérification TypeScript et production de la WebUI.

En jeu, vérifier avec un joueur et un admin : `/report`, prise en charge dans
`/admin`, réponse publique, note privée absente côté joueur, résolution,
reconnexion et consultation du dossier terminé.
