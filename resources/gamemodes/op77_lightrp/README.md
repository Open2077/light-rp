# op77_lightrp

Le framework Light Roleplay d'**Open//77 Official Roleplay**, en un seul package : serveur,
client et une WebUI globale React + TypeScript habillée du design system Open//77 RP
(jaune sur noir, chanfreins, lisibilités mono, mouvement mécanique).

```
op77_lightrp/
├── open77.lua                 manifeste : scripts, dépendances, permissions, page WebUI
├── shared/
│   ├── events.lua             tous les noms d'événements (miroir de ui/src/bridge/protocol.ts)
│   └── config.lua             spawn, lieux, chat, besoins, voix, véhicules, touches (téléchargé par les clients)
├── server/
│   ├── core/framework.lua     LightRP : modules, actions, commandes, état de la page, notices
│   ├── core/persistence.lua   LightRP.db : le bridge MySQL, schémas, dégradation sans base
│   ├── modules/characters.lua personnages (nom, position, temps de jeu), /register
│   ├── modules/needs.lua      faim / soif
│   ├── modules/chat.lua       parole RP par distance, /me /do /try /roll /w /s /ooc /pm /who /rules /help
│   ├── modules/vehicles.lua   un véhicule civil par joueur, /car /cars /dv
│   ├── modules/staff.lua      ACL, /lightrp.*, /report, actions staff de la page
│   ├── modules/ui.lua         clé `server` de l'état, diffusion périodique
│   └── main.lua               arrivée (dernière position) et réveil à l'hôpital
├── client/
│   ├── core/ui.lua            la surface WebUI, le bridge, le focus, les relais réseau
│   ├── core/hud.lua           échantillonnage vitaux / véhicule / voix / horloge → page
│   └── main.lua               création, touche F5 (rebindable)
└── web/                       la page construite (ne pas éditer : `npm run build` dans ../../../ui)
```

## Bureau staff RP et reports

`/admin` (ou `/lightrp.admin`) ouvre **le** menu admin du serveur, compact façon
RageUI et dans la DA LIGHT/RP. Il réunit les outils de la plateforme (`open77_admin` :
noclip, véhicules, météo, actions de masse…) et ceux de LightRP (missions, world
bosses, gigs, objets, contenu) : reports, joueurs, outils perso, téléport,
véhicules, objets et armes, monde, missions et événements, lieux et contenu,
serveur, historique. Chaque entrée n'apparaît que si l'ACL l'autorise. Les
déplacements restent libres pendant la navigation.
`/report`, `/reports` ou **F1 → Reports & support** donnent aux
joueurs un suivi privé et persistant, avec admin assigné, réponses, statuts,
notifications et possibilité de réouverture. Les notes internes restent réservées
au staff. `/adminfull` conserve la console technique officielle.

[Parcours, permissions, stockage, limites et tests](docs/admin-support.md).

**Éditeur de missions** (`/lightrp.missions`, ACL `command.lightrp.missions`) : créer en jeu des missions Élimination ou Survie (vagues),
avec périmètre (avertissement puis mort hors zone), points de spawn ennemis, checkpoints déclencheurs, vagues, difficultés et test immédiat.
Les missions enregistrées avant l'équilibrage passent au nouveau barème avec `/lightrp.missions.repay` (aperçu) puis
`/lightrp.missions.repay apply` (staff). Voir [docs/mission-editor.md](docs/mission-editor.md).

## Création de personnage et scène d'arrivée

### Placement de la scène

Commande staff : `/lightrp.scene` (ACL `command.lightrp.scene`). Elle masque
l'assistant de création, libère les contrôles et réserve un bucket privé à midi,
par temps ensoleillé. Aucun déplacement automatique : marcher jusqu'au lieu choisi.

- `/lightrp.scene sit` : pose assise à la position et dans la direction actuelles.
- `/lightrp.scene walk` : se relever pour changer de lieu ; F7 change la perspective.
- `/lightrp.scene move 0 0 0.05` : monter l'ancrage de 5 cm (axes monde X/Y/Z,
  valeurs entre -1 et 1 m). La pose est relancée après chaque ajustement.
- `/lightrp.scene turn 15` : ajouter 15 degrés à l'orientation.
- `/lightrp.scene preview 3.6 -1.5 0.4 1.2 48` : aperçu caméra devant le
  personnage (distance, décalage latéral, hauteur caméra, hauteur visée, FOV).
  Masque le HUD et joue la musique à faible volume ; `walk` restaure la vue.
- `/lightrp.scene save` : enregistrer l'ancrage de la pose et son orientation dans
  le KVP `creator.placement.draft`, avec copie lisible dans le journal serveur.
- `/lightrp.scene stop` : terminer le réglage et restaurer le bucket précédent.

L'enregistrement reste un brouillon : reporter les valeurs validées dans
`characters.arrivalScene.position/heading` de `shared/config.lua`. `autoStart`
active la scène à la fin du choix natif du corps. Le banc validé est celui du
décor : `bench = false` évite de créer un second meuble au même endroit.

Le parcours propose identité, origine/histoire facultatives, révision de
l'apparence puis confirmation. Chaque étape dispose d'un plan dans `shots`, en
coordonnées relatives au personnage (X droite, Y devant, Z hauteur). Les plans
s'enchaînent en douceur ; le bouton **Still camera** et la préférence système
de mouvement réduit suppriment les mouvements. **Cloudy Day** se joue localement
à `musicVolume = 0.12`, avec un bouton de sourdine.

La scène possède un bucket isolé, ensoleillé à midi, libéré au départ. L'arrivée
charge le quartier via la transaction de respawn avant d'asseoir le personnage ;
`approachOffset` place les pieds sur le trottoir, hors du collider du banc.
L'image reste couverte tant que la pose native n'est pas présentée. Un échec de
chargement ou de caméra donne un bouton de nouvelle tentative. L'éditeur natif
rend ensuite la main à la scène ; confirmer le personnage libère caméra, musique,
HUD et immobilisation avant le spawn du joueur. Les modifications d'apparence
restent gérées et sauvegardées par `open77_appearance`.

Le manifeste doit conserver `player.appearance.read` : la scène attend la
fermeture réelle de l'éditeur, y compris après annulation, avant de reprendre
la caméra et le focus. Les brouillons enregistrés reprennent à la bonne étape
après reconnexion ; un personnage confirmé rejoint directement la ville.

## Premier jour : tutoriel dans le hall d'arrivée

Après la confirmation du personnage, **Your first day** se joue dans le hall
d'arrivée : la ville blanche de la ressource de carte `lobby`, hors de Night
City, dans son propre bucket de routage (620000). Le paquet `open77_lobby_cubes`
y tient la nuit et le ciel dégagé. Un travelling remonte l'avenue, puis Mara, la
guide, attend sur la place. Les dialogues sont textuels ; la musique reste
locale et discrète.

Le parcours apprend les vraies mécaniques, dans cet ordre. Les nouveaux chapitres
voix et Alt sont détaillés dans le [guide d'intégration](docs/first-day-interactions-voice.md).

1. Marcher jusqu'à Mara et lui parler : la vie en ville et les règles RP.
2. Installer le **Neural-Link** (F2, séquence Kiroshi d'`op77_neuralink`) : obligatoire,
   l'étape attend l'implant et range le téléphone à la fin.
3. Configurer la voix : périphériques, push-to-talk clavier/souris ou activation,
   puis test local. « Déjà configuré » et « Passer » restent disponibles.
4. **S'habiller** : le nouveau venu arrive en sous-vêtements. La cabine d'essayage au
   fond de la boutique du hall (`wardrobes.spots.lobby_fitting`) ouvre la garde-robe ;
   l'étape attend une tenue enregistrée avec un haut et un bas
   (`open77:presentation:committed`, `Wardrobe.dressed`), et passe d'elle-même si le
   personnage est déjà habillé. Comme toute garde-robe d'un lieu partagé (ville ou
   hall), la cabine est **privée** : le joueur se change dans son propre bucket
   (`wardrobes.privateBucketBase` + son id, même heure et même météo) et revient à la
   fermeture ; dans un logement, déjà privé, rien ne bouge.
5. Ouvrir le menu joueur et consulter **Identity** (identité, compte bancaire).
6. Ouvrir l'inventaire.
7. Aller à la boutique du hall et **acheter** une boisson : un vrai panier, un
   vrai paiement (`onShopCheckout`, émis par `server/modules/shops.lua`).
8. Boire : l'étape attend la fin réelle de l'action, validée côté serveur.
9. Parler au banquier (compte, espèces, virements, `/pay`) puis au mécano.
10. Pratiquer **Alt + clic gauche** : inspecter une caisse, déverrouiller sa voiture
   d'entraînement, ouvrir puis fermer le coffre avec le vrai menu contextuel.
11. Parler au pompiste (carburant, jerrican).
12. Activité d'entraînement à la foire aux métiers : **collecter** une caisse,
   la **transformer** à l'établi, **vendre** les pièces à Juno. C'est le module
   des activités libres (`job_work`) avec un métier `tutorial` : vrais objets,
   vrai paiement en banque, un seul lot par appui. Chaque site ne s'ouvre que
   pour l'étape du guide qui le demande (`Tutorial.allowsWork`) : ce n'est pas
   un revenu. Aucun métier n'est choisi dans le hall.
13. Retourner voir Mara : elle ouvre la porte, le personnage reçoit son studio de
   départ à Kabuki (sa porte est sur la carte) et arrive au point
   `spawn.afterTutorial` (`shared/config.lua`), une esplanade de Westbrook à
   environ 115 m de cette porte, dans le bucket de la ville. Mara conclut par
   message. Sans `spawn.afterTutorial`, il se réveille directement dans le studio.

**Passer le premier jour.** Dès l'arrivée, l'écran d'ouverture propose **Skip
the tutorial**. Ensuite, la carte d'objectif affiche en permanence **Press F1 to
skip the tutorial** : tant que le guide tourne, le menu joueur (F1) porte l'entrée
**Skip the tutorial**, juste sous **First day guide** (qui la propose aussi), et
`/tutorial skip` fait de même. Une confirmation précède toujours le saut. Le serveur installe
le Neural-Link s'il manque (événement `op77_neuralink:requestInstall`, l'implant
reste obligatoire en ville), marque le guide terminé, puis fait exactement comme
la fin normale (étape 13) : studio de départ donné, arrivée au point
`spawn.afterTutorial`. Sauter le vestiaire du hall peut laisser le personnage dans
les vêtements du créateur : l'armoire du studio, à deux pas, l'habille. Un joueur
déjà en ville reste où il est. Seule la paie d'entraînement n'est pas gagnée ;
l'argent et le sac de départ viennent de la création du personnage.

**F1 → First day guide** permet de mettre en pause, reprendre ou revisiter le
parcours. `/tutorial` reprend au dernier objectif, `/tutorial pause` laisse
jouer librement, `/tutorial skip` passe le premier jour et `/tutorial restart`
rejoue tout le premier jour, scène d'ouverture comprise, pour un personnage existant. Les touches affichées suivent les raccourcis reconfigurés.

Présentation (`LightRpTutorialConfig.reveal`, `ui/src/features/tutorial/`) :

- **Montrer le chemin** : à chaque nouvelle destination à plus de 12 m, après
  le bandeau « Step complete », la caméra s'élève derrière le joueur, survole
  l'itinéraire (des points dorés s'allument au sol à son passage), se pose sur
  le lieu puis revient en fondu (~5,6 s). Le joueur est figé pendant le vol et
  libéré dès le retour. Bandes cinéma, nom du lieu, direction, distance et plan
  du hall à l'écran. `SPACE` passe (`lightrp.tutorial.skip`), `G` rejoue le vol
  à tout moment (`lightrp.tutorial.way`) : deux RegisterKeyMapping. Jamais par
  dessus un menu, un dialogue, la caméra libre ou en véhicule.
- **Exemples d'interface** : une réplique peut être `{ text, demo }` ; la démo
  joue au-dessus du dialogue (compteur du véhicule avec la jauge qui descend en
  réserve, étapes de la pompe, clé et bips, location, carte d'identité, espèces
  et banque, virement, menu véhicule, plan du hall, collecter/transformer/vendre).
  Une étape peut avoir `demo` : une mini animation dans la carte d'objectif
  (touche F1 puis Identity, inventaire, panier, boire, activités). Ce sont des
  images des vrais écrans : elles n'envoient aucune action.
- Les répliques s'écrivent à l'écran ; `SPACE`/`Entrée` affiche la ligne
  entière, puis passe à la suivante.

Qui est où : le guide décide du lieu de réveil tant qu'une étape du hall est en
cours (`Tutorial.spawnPoint` / `deathPoint`, lus par `server/main.lua`) : à la
connexion et après une mort, le personnage revient à la porte du hall. Mettre le
guide en pause dans le hall ramène en ville (personne n'y reste enfermé) ;
reprendre une étape du hall y ramène ; revisiter un guide terminé repart du hall
sans la scène d'ouverture. Un personnage enregistré dans le hall sans étape du
hall en cours se réveille en ville. Les citoyens déjà créés ne sont pas forcés à
suivre le tutoriel.

La table `lightrp_tutorial` stocke le checkpoint par compte et personnage, avec
une révision pour refuser les réponses périmées et les doublons. La progression
vient des hooks `onInventoryOpened`, `onShopCheckout`, `onItemUsed` et
`onJobWorkCompleted` ; les messages du
navigateur ne peuvent créer ni métier, ni objets, ni argent. Parler à un contact
exige d'être vivant, près de lui et dans le bucket du hall. La pause, un
changement de personnage, la mort et l'arrêt de la ressource libèrent caméra,
son et contrôles.

Configuration : `shared/tutorial.lua` contient le hall (`lobby` : origine,
bucket, point d'arrivée, boîte), les contacts (nom, rôle, position, orientation,
fiches de PNJ essayées dans l'ordre), l'ordre et les textes des étapes, le plan
d'ouverture et le volume. Les positions sont en mètres depuis le centre de la
place, comme les pose le générateur de la carte : si le hall est déplacé, seule
`origin` change, avec les deux entrées qui en dépendent (`lobby_market` dans
`server/config/shops.lua`, le métier `tutorial` dans
`server/config/job_work.lua`) et la boîte de `open77_lobby_cubes/zone.lua`. Le bucket doit
être le même dans `shared/tutorial.lua`, ces deux entrées et
`open77_lobby_cubes/server.lua`. `enabled = false` désactive le guide et remet le
briefing initial. La préférence système de mouvement réduit désactive le
travelling.

Tests dédiés : `tests/tutorial_test.lua`, `tests/tutorial_client_test.lua`,
`tests/hospital_respawn_test.lua` (réveil dans le hall, placement avec bucket)
et `ui/tests/tutorial.browser.cjs`. Reste à vérifier en jeu : la pose des PNJ
sur leurs dalles, les plans de caméra, le trajet complet et le passage du hall
à la ville.

## Kit d'interactions : progression et QTE

Les points de carte utilisent maintenant les SVG du package standalone
`open77_icons` : icônes dédiées par activité, accent jaune, groupes conservés
et objectifs de tournée spécifiques. [Catalogue LightRP et intégration](docs/map-blips.md).

La même barre jaune sans panneau de fond sert à manger, boire, fumer, faire le plein
et travailler. Toute nouvelle action temporisée passe par `LightRpActions.progress`
ou l'export `ActionProgress`. Le kit conserve aussi l'anneau, le maintien de touche
et les QTE via `ActionHold`, `ActionSkillCheck`, `ActionCancel`, `ActionIsActive`
et `ActionResult`. [Contrats, exemples Lua, options et tests](docs/action-ui.md).

Aperçu navigateur : `http://127.0.0.1:5177/?registered=1&actions=1` (Vite).
En jeu, staff : `/lightrp.uitest progress|circle|hold|timing|sequence|cancel`.
Les démonstrations n'attribuent aucune récompense ; les futurs jobs doivent valider leurs actions côté serveur.

## Job Center et activités libres

Trois métiers publics : **Sanitation**, **Scrapper**, **Courier** (livreur, qui a remplacé AC Cleaner). Le bureau utilise trois
panneaux inclinés illustrés qui s'agrandissent au survol ou au clavier.
**Sanitation/Scrapper** : récolte → transformation → vente, sans prise de service
ni métier obligatoire. E démarre la boucle au point ; Échap l'arrête. Les objets
ont un poids et passent par le vrai inventaire et les coffres. Le bureau propose
les GPS des trois étapes et une embauche facultative. `/work sanitation|scrapper
[collect|process|sell]`, `/work stop`.

Les points, recettes, durées et prix des activités libres sont dans
`server/config/job_work.lua`. Le **Courier** fonctionne par ordres de travail
(`/job start|status|gps|cancel`, ou « Start a run » au bureau) : à chaque prise de
course, le serveur tire 2 à 3 commandes, un point de récupération par commande puis
un point de livraison par commande ; chaque commande passe réellement dans le sac
(`delivery_order`, 1 kg) et la paie, versée en banque à la dernière livraison, suit la
longueur du trajet. Points (de test pour l'instant), nombre de commandes, durées et
barème : `server/config/delivery.lua`. AC Cleaner n'est plus proposé au bureau ; ses
détenteurs gardent leur route (`server/config/job_runs.lua`). Revenu visé : 3 000 à
5 000 €$/h au grade 0 ; chaque grade du métier ajoute 10 % à la vente et aux courses
(`server/config/economy.lua` → `jobs.gradeBonus`), la paie de grade (toutes les 30 min,
`shared/jobs.lua`) reste un petit bonus. **La paie ne va qu'aux joueurs actifs**
(`server/modules/work_activity.lua`, `economy.lua` → `paychecks`) : dans les 30 dernières
minutes, une tâche du métier (lot de job_work, ordre de travail accepté ou payé), un
patient stabilisé au kit, un virement reçu d'au moins 50 €$, ou 75 m parcourus en ville
(positions relevées par le serveur toutes les 20 s, téléportations et retours d'activité
exclus). Un joueur inactif ne touche rien et en est averti une fois. Barème complet :
[docs/economy-balance.md](docs/economy-balance.md).

Après une embauche, à la fermeture du bureau, un **guide du métier** s'ouvre : une
fenêtre guidée, page par page, avec des visuels animés (pages `guide` de
`shared/jobs.lua`). Il se rouvre depuis **F1 → My job**, qui permet aussi de lancer une
course n'importe où (Courier), de remettre le GPS sur l'étape suivante, d'abandonner la
course, ou de poser le GPS des trois étapes des activités libres.
[Configuration, sécurité, fonctionnement et tests](docs/jobs.md) · [Prompts des artworks](docs/job-art-prompts.md).

## Location de véhicules

Catalogue photo avec recherche, catégories et tri, récapitulatif avant paiement,
choix cash/banque et retour confirmé. Banque locale de **18 visuels** des véhicules
du catalogue. [Configuration, sources des images et tests](docs/vehicle-rental.md).
Aperçu : `http://127.0.0.1:5177/?registered=1&dialog=rental`.

## Boutiques NPC

Catalogue illustré jaune/noir, recherche et catégories, panier multi-objets,
achat/revente, quantités, cash/banque et capacité du sac. Premier vendeur de nourriture
au City Center : `(-667.559082, -378.390808, 9.193733)`, yaw `-125.597023`, interaction **E**.

Les NPC partagent un **template** (`street_food`) défini dans `server/config/shops.lua` :
changer le template met à jour toutes les boutiques liées. Achats/ventes atomiques
(argent, inventaire et reçu en une transaction), anti-double paiement et validations
côté serveur ; base de données requise. [Configuration et API](docs/shops.md).
Aperçu navigateur : `http://127.0.0.1:5177/?registered=1&dialog=shop`.

## Architecture du framework

### Portée vocale

**F11** alterne chuchotement / normal / cri. Le package `open-voice` affiche un
cercle 3D jaune pendant **3 secondes**, au rayon confirmé par le serveur
(**3 / 20 / 40 m**). Il suit le joueur et disparaît automatiquement, sans nouvelle
WebUI. [Configuration et validation](docs/voice-range.md).

Catalogue RP : **30 objets dont 18 consommables illustrés** (9 aliments, 6 boissons,
3 soins), avec effets, poids et piles configurables dans `shared/items.lua`.
[Catalogue et ajout d'items](docs/item-catalogue.md) · Aperçu :
`http://127.0.0.1:5177/?registered=1&items=1`.

**Une page, un état.** Le serveur publie l'état du joueur par clés (`server`, `character`,
`needs`, `vehicles`, `staff`, `locations`, `online`), chaque module fournissant la sienne via
`LightRP.stateProvider(clé, fn)`. `LightRP.state(playerId, clés)` pousse la clé au client, qui
la relaie à la page (`lightrp:ui:state`) ; la page fusionne le patch dans son store (zustand).

**Actions validées côté serveur.** La page émet `lightrp:ui:action { type, ... }`, le client
le transmet tel quel (`op77_lightrp:action`), le serveur dispatch vers `LightRP.action(type, fn)`.
La réponse revient par `LightRP.result(playerId, ok, texte)` et s'affiche en toast. Les actions
staff vérifient la même permission ACL que la commande équivalente.

**Le client ne décide rien.** Il crée la surface, échantillonne le HUD dix fois par seconde,
prend le focus quand le menu ou le dialogue d'identité est ouvert, et relaie.

### Écrire un module

```lua
-- server/modules/bank.lua
local Bank = LightRP.module("bank", {})
LightRP.db.schema([[CREATE TABLE IF NOT EXISTS lightrp_bank (...)]])
LightRP.stateProvider("bank", function(playerId) return { balance = Bank.balance(playerId) } end)
LightRP.action("bank.withdraw", function(playerId, payload) ... LightRP.result(playerId, true, "Retrait effectué.") end)
LightRP.command("bank", { usage = "/bank" }, function(source) LightRP.openMenu(source, "bank") return true, "Banque ouverte." end)
function Bank.onConnected(playerId) ... end   -- aussi onDisconnected, onReady, onGameplayReady, onLifeState, onDatabaseReady, onUiReady
```

Ajoutez la ligne `server_script` dans `open77.lua`, la clé dans `UiState` (`protocol.ts`) et
l'onglet dans `features/menu/Menu.tsx`.

## Création de personnage et identité persistante

Un compte (identité Master, `GetPlayerIdentifier`) possède jusqu'à `characters.maxSlots` personnages,
chacun sous une `character_key` (`default`, `slot2`, `slot3`). La même clé sert à `open77_appearance`
(corps et visage, table `open77_characters` + `open77_player_appearances`) et à `open77_wardrobe`
(tenues, `open77_character_presentation`) : le framework ne stocke jamais l'apparence lui-même, il
lit ces tables et écoute les événements hôte `open77:appearance:characterCreated` et
`open77:appearance:saved` pour tenir `body_family`, `appearance_rev`, `appearance_at`.

Tables : `lightrp_accounts` (compte → slot actif) et `lightrp_characters` (état civil, statut
`draft`/`active`/`archived`, position, besoins, temps de jeu). Une ancienne table v1 (un
personnage par compte) est renommée `lightrp_characters_v1` au premier démarrage.

**Le workflow**, piloté par `character.step` que le serveur calcule (`identity` → `appearance` →
`confirm` → `done`) :

1. Première connexion : `open77_appearance` tient la porte de préparation et ouvre l'éditeur natif
   avant le monde ; le corps est validé et sauvegardé par lui (`characterCreated`).
2. Dans le monde, le wizard « Nouveau personnage » (dialogue avec focus) demande l'état civil :
   prénom, nom, date de naissance (calendrier 2077, âge minimum configurable), origine, histoire
   → action `character.identity`.
3. Étape « Corps et visage » : boutons *Corps féminin* / *Corps masculin* / *Coiffeur*. Le client
   ferme la page et demande le miroir au package apparence (`open77:appearance:requestOpen`). La
   sauvegarde revient par `saved` et le serveur pousse la révision.
4. Étape « Confirmation » : résumé, *Garde-robe* (`/wardrobe` via le bus de commandes) et *Entrer
   dans Night City* → `character.finish` : statut `active`, slot actif, placement au point d'arrivée
   (`onCharacterActivated`).

Ensuite l'onglet **Personnage** du menu : modifier l'état civil, rouvrir miroir / coiffeur /
garde-robe, gérer les emplacements (*Jouer* → `character.select` déclenche
`open77:appearance:setCharacter` et replace le joueur à la dernière position de ce personnage ;
*Nouveau* → `character.new` ouvre un brouillon ; *×* → `character.archive`). Les hooks de module
`onCharacterActivated(playerId, character)` et `onCharacterSwitched(playerId, character)` sont
disponibles pour les autres modules.

Sans base de données, l'étape apparence est ignorée (`appearanceTracked = false`) et tout vit le
temps de la session.

### Briefing de premier spawn

Quand le personnage devient actif pour la première fois (`character.finish`), le serveur pousse `character.welcomePending = true` (colonne `lightrp_accounts.welcome_seen_at` NULL, une fois par compte). La page affiche `features/welcome/WelcomeModal` : image de Night City (`web/img/night-city.jpg`), texte anglais qui explique le Light Roleplay, et un bouton OK verrouillé pendant `welcome.readSeconds` (config, 15 s). Le clic envoie l'action `welcome.ack`, qui date la colonne et ne remontre plus la modale. L'onglet Aide (bouton « Welcome briefing ») la rejoue sans délai.

Tous les textes joueur (page, notices, réponses de commandes, libellés de la config) sont en anglais.

## Argent et banque (`server/modules/economy.lua`)

Le liquide est l'item **`cash` / Eurodollars** : 1 unité = €$1, **0 kg**, transférable, divisible, stockable et échangeable comme les autres objets. Seul l'argent dans les poches est dépensable ; le HUD le compte directement dans l'inventaire. Le compte bancaire `XXX-XXX` reste séparé dans `lightrp_wallets.bank`. Les anciens soldes sont convertis une seule fois, avec sauvegarde avant conversion dans `lightrp_cash_migrations` et transaction atomique. Les nouveaux personnages reçoivent `economy.startingCash` en item et `startingBank` en banque. Voir [docs/cash-inventory.md](docs/cash-inventory.md) pour migration, persistance et tests.

API pour les autres modules (jobs, boutiques, loyers) : `LightRP.money.addCash/removeCash/addBank/removeBank(playerId, amount, kind, note, counterparty)`, `deposit/withdraw`, `transfer(playerId, "XXX-XXX", amount, note)`, `pay(playerId, targetId, amount)` (main à main, `economy.payRange`), `creditAccount(number, …)` (fonctionne hors ligne), `findAccount`, `format`. Hook `onMoneyChanged(playerId, wallet, delta, balance, kind)`. Les soldes ne passent jamais sous zéro ; un drapeau `busy` par portefeuille évite deux opérations entrelacées.

Page : état `money` (`cash`, `bank { number, balance }`, `history`), actions `money.deposit|withdraw|transfer|pay` (prêtes pour la future page ATM). Commandes : `/money`, `/bank`, `/pay <id> <montant>`, `/transfer <compte> <montant> [note]`, `/deposit`, `/withdraw` (tant que `economy.counterCommands`), staff `/lightrp.givemoney`, `/lightrp.takemoney`, `/lightrp.account`.

### Équilibrage et dépenses récurrentes (`server/config/economy.lua`)

La courbe visée, ses mesures et le tableau avant/après de chaque prix sont dans
[docs/economy-balance.md](docs/economy-balance.md). Les prix restent avec leurs
fonctionnalités ; `server/config/economy.lua` porte les règles transversales :

- **Missions et gigs** (`server/modules/mission_pay.lua`) : la paie d'une difficulté est
  la part de **chaque** opérateur à l'équipage minimum. Au-delà, la cagnotte croît comme
  équipage^0,7 et se partage. Une paie pleine au même point de mission n'est reversée
  qu'après 60 min au même personnage, et un compte touche 6 paies pleines par jour UTC ;
  au-delà, 25 %. Plafond de 250 €$ par minute de durée. Les opérateurs voient la paie
  attendue au lancement et la raison d'une réduction à la fin. Tables
  `lightrp_mission_payout_cooldowns` et `lightrp_mission_payout_daily`.
- **Hôpital** : 300 €$ après *Give up and go to hospital*, banque puis liquide, sans jamais
  passer sous zéro (le reste est effacé). Gratuit sur un sauvetage au kit, en mission, en
  activité, pendant le premier jour et les 120 premières minutes de jeu du personnage.
- **Cabine d'essayage** : 50 €$ par visite d'une cabine de la ville qui enregistre une
  tenue ; logement, hall d'arrivée, wizard et nouveaux venus gratuits, offert si le joueur
  ne peut pas payer.
- **Activités** (`server/modules/activity_pay.lua`, `economy.lua` → `activities`) : un
  résultat PvP classé paie 70 €$ par minute jouée × (0,75 + 0,5 × résultat), le résultat
  allant de 1 (victoire, première place) à 0 (dernière place, défaite), multiplié par la
  part du lobby plein réellement présente (joueurs vus par le serveur dans la même
  activité et le même bucket, par compte ; jamais un chiffre du fournisseur). Un joueur
  moyen gagne à peu près le taux d'un métier, un bon joueur un cinquième de plus. Le PvE
  paie 40 / 50 / 60 €$ la minute selon la difficulté, moitié sur une défaite. Rien pour un
  résultat non classé (bots, `result.unranked`, mode bots staff, `test`), un départ ou un
  forfait, un AFK (aucune statistique de progression), un match plus court que le minimum
  du mode, ni un match dont tous les joueurs réels sont du même crew. Les mêmes comptes
  ne sont payés ensemble que 3 à 5 fois par heure, et un compte touche au plus
  12 000 €$ PvP et 6 000 €$ PvE par jour UTC (table `lightrp_activity_pay_daily`).
  Chaque paie passe par la banque (`activity_pvp` / `activity_pve`) avec une notice
  « +€$ N — raison ».
- **Voitures** (`server/config/dealerships.lua`) : premières 4 000 – 6 500 €$, correctes
  12 000 – 16 000 (≈ 3 h de jeu mêlé), haut de gamme 80 000 – 100 000 (≈ 20 – 25 h).
  Le rythme complet par profil (régulier, grinder, PvP, PvE) est au §7 du barème.
- Fourrière (`server/config/garages.lua`), carburant (4 €$/L, `shared/config.lua`) et
  nourriture (`server/config/shops.lua`) sont relevés. Aucun solde existant n'est modifié.

## Menu joueur (F1)

Menu liste façon RageUI (design system : Menus / RageMenu, porté en `ui/src/design/components/RageMenu.tsx` avec des classes `o77-rage*`) : une colonne, une ligne surlignée, flèches pour bouger, Entrée pour descendre, Retour arrière / Échap pour remonter, F1 pour fermer. `features/menu/PlayerMenu.tsx` construit l'arbre depuis l'état serveur à chaque rendu et garde une pile `{ key, index }`. Premier sous-menu : **Identity** (ID citoyen, prénom, nom, naissance, origine, compte bancaire, temps de jeu, statut). Le client Lua prend le clavier seul (`setFocus(true, false)`) ; le menu ne s'ouvre qu'avec un personnage actif et hors briefing. Il n'y a plus de menu « terminal », ni de commandes de spawn ou de dépôt pour les joueurs : véhicules par `/lightrp.car` et `/lightrp.dv` (staff), argent par l'ATM à venir.

## Caméra libre (`client/core/freecam.lua`, page `features/freecam/`)

La vue se détache du personnage et vole autour de lui pour regarder une scène sous un autre angle. Le corps reste où il est, complet et en troisième personne (`thirdPersonBody`), quelle que soit la perspective de départ : c'est une caméra, pas un noclip. Elle s'ouvre depuis le menu joueur (ligne **Free camera**) ou avec sa touche (F5 par défaut) ; à pied uniquement, jamais pendant une action, un dialogue, la création ou une caméra du tutoriel.

- **Rayon** : l'objectif reste à `freecam.radius` mètres du personnage (25 par défaut, 100 au plus) et ne descend pas à plus de `freecam.below` mètres sous ses pieds. La limite se longe en glissant ; la jauge du bandeau vire à l'orange puis au rouge.
- **Touches** : toutes passent par `RegisterKeyMapping` (`Config.freecam.keys`), donc réglables dans Pause > Paramètres > Raccourcis. Avancer / reculer / gauche / droite suivent la disposition du clavier (WASD, ZQSD en AZERTY), Espace / C montent et descendent, Maj accélère, Ctrl ralentit, molette = vitesse, Ctrl + molette = zoom, R revient derrière le personnage, H masque le rappel, Retour arrière ou la touche d'ouverture quittent.
- **Fluidité** : vitesse, rotation et zoom sont lissés (`freecam.smoothing`), l'entrée et la sortie fondent sur `blendMs`. Parti de la troisième personne, le plan démarre exactement où était la vue.
- **Vol partagé** : le pas de vol (regard, vitesse, déplacement, laisse sphérique et plancher) est dans `client/core/freecam_motion.lua`, réutilisé par la vue *Free* des tables (`docs/board-games.md`) avec les mêmes touches.
- **Rappel des touches** : bandeau passif en bas de l'écran, dessiné depuis les touches effectives, avec distance / rayon, vitesse et focale. Le chat, la pause ou le menu F1 figent le plan sans le fermer.
- **Fermeture automatique** : mort, montée en véhicule, dialogue ouvert, personnage déplacé de plus de `freecam.leash` mètres, vue reprise par le moteur, arrêt de la ressource. Les blocages du personnage sont rendus un par un (pas de `resetControls`, qui lâcherait aussi le mode de marche).

Limites de la plateforme : pas de collision de l'objectif (il traverse les murs dans le rayon) et le monde reste chargé autour du corps, pas de la caméra. Tests : `tests/freecam_client_test.lua`, `ui/tests/freecam.browser.cjs`.

## Interactions de proximité et location de véhicules

**Interactions** (`server/core/interact.lua`, `client/core/interact.lua`) : un module déclare un point avec `LightRP.interaction(id, { position, radius, label, prompt, key })`. Chaque client reçoit la liste (`op77_lightrp:interactions`). Si `marker` est renseigné, il crée un marqueur 3D natif via `Open77.markers` ; sinon il conserve le cercle au sol historique, sauf si `ring = false`. L'ancre WebUI partagée affiche « E · Rent a vehicle » au-dessus du point seulement quand le joueur est dans le rayon. E (touche `lightrp.interact`, rebindable) envoie l'id au serveur, qui revérifie la distance depuis sa propre position puis appelle `onInteract(playerId, id)` sur les modules. `LightRP.dialog(playerId, kind, payload)` ouvre une fenêtre de la page (`lightrp:ui:dialog`).

Les agences utilisent désormais un **cylindre 3D jaune translucide, avec un dégradé vers le haut**, sans cercle superposé. `shared/config.lua` → `rentals.marker` règle `shape`, `radius`, `height`, `color` (RGBA 0–255), `minDistance` / `maxDistance`, `groundOffset` (mètres), ainsi que `scale`, `rotation`, `style` et `visible` si nécessaire. Le rayon visuel ne change pas `rentals.interactRadius` : le PNJ, la touche E, le blip et la validation serveur restent indépendants du marqueur. Les handles sont supprimés au remplacement de la liste ; la plateforme les nettoie aussi à la déconnexion ou à l'arrêt de la ressource. Il faut un client Open77 avec l'API **et l'archive des marqueurs 3D**, ainsi que la permission `world.markers` (déjà déclarée). Sur un ancien client, un diagnostic est journalisé sans bloquer la location ni réafficher le cercle.

**Location** (`server/modules/rental.lua`, page `features/rental/RentalDialog.tsx`) : les agences sont dans `config.rentals.spots` (PNJ via `Open77.npcs.create`, candidats essayés dans l'ordre ; stock = clés de `vehicles.catalog` avec prix ; `parking` = point d'apparition à relever avec `/pos`). Un joueur ne peut avoir qu'une location à la fois ; il paie en cash ou en banque via `LightRP.money`, le véhicule apparaît sur le parking pour `durationMinutes`, puis est repris (notice) ; retour possible à n'importe quelle agence (bouton « Return vehicle »), et nettoyage à la déconnexion ou au changement de personnage. Historique dans `lightrp_rentals`. Staff : `/lightrp.rentals`. État page `rental.active` (puce HUD avec le décompte), actions `rental.rent { spot, key, pay }` et `rental.return`.

## Clés de véhicule (`server/modules/keys.lua`, `client/core/keys.lua`)

Une clé autorise à verrouiller / déverrouiller explicitement : **un véhicule verrouillé est fermé pour tout le monde, propriétaire compris**. Les deux opérations passent par `Open77.vehicles.setLockedForAll` pour supprimer les exceptions individuelles. Une clé est une entrée du registre `LightRP.keys.ledger[vehicleId].holders[identifier#slot]`, liée au personnage, pas à la session. La reconnexion, le changement de personnage ou le partage de clés ne déverrouillent jamais la voiture. Réplication par state bags : `Open77.state.entity("vehicle", id).keys = { label, owner, holders }` et `Open77.state.player(id).vehicleKeys = { [vehicleId] = label }` (lu par le client pour savoir s'il peut appuyer sur L).

API : `LightRP.keys.give(vehicleId, playerId, { label, owner })`, `take`, `clear`, `has`, `holders`, `lock(vehicleId, locked)`, `toggle(playerId, vehicleId)` (validé : clé, même bucket, distance `vehicleKeys.range` ou assis dedans, klaxon court). Hook `onVehicleLockChanged`. Touche L (`lightrp.vehiclelock`, rebindable) : le véhicule occupé, sinon le plus proche. Les clés disparaissent avec le véhicule (`onVehicleRemoved`). Staff : `/lightrp.givekeys`, `/lightrp.takekeys`. La location livre la voiture verrouillée avec la clé dans la poche du loueur : appuyer sur L pour entrer.

## Menu véhicule Alt + clic

Les détenteurs des clés disposent d'un menu principal limité à quatre entrées : verrouillage, **Coffre & capot**, **Commandes véhicule** et état. Le premier sous-menu contient les ouvrants coffre/capot et l'inventaire du coffre ciblé ; le second contient le moteur à l'arrêt, les feux et le klaxon. Les portes latérales, leurs commandes générales et les vitres sont retirées, y compris de la liste des actions acceptées côté serveur. Les choix suivent l'état courant ; les motos n'affichent pas de coffre/capot. Retour, flèche gauche, Retour arrière ou clic droit remonte au menu principal ; Échap ferme tout. Le package contextmenu reste générique, sans action par défaut.

Chaque demande est revérifiée côté serveur (clés, personnage actif et vivant, proximité, bucket, conducteur / occupants, vitesse, anti-spam). Le déverrouillage reste obligatoire pour ouvrir un coffre ou un capot. Paramètres : `shared/config.lua` → `vehicleContext`. Détails, API et tests : [docs/vehicle-context.md](docs/vehicle-context.md).

## Inventaire (`shared/items.lua`, `server/modules/inventory.lua`, page `features/inventory/`)

Modèle ox_inventory : grilles de cases à poids maximum, stacks d'items identiques (même `name` + mêmes `metadata`, jusqu'à `stack` du template), tout mouvement validé côté serveur. Kinds : `player:<identifier>#<slot>` (persistant, chargé avec le personnage, items de départ dans `config.inventory.starting`), `trunk:<vehicleId>` (session, véhicule proche dans le même bucket, obligatoirement déverrouillé, même avec les clés), `drop:<n>` (session, tas au sol avec point d'interaction E « Pick up », expire après `drop.ttlMinutes`), `stash:<id>` (persistant, points de `config.inventory.stashes`). Table `lightrp_inventories` (items en JSON).

Verrouiller retire immédiatement le coffre de l'inventaire de tous ses utilisateurs, sans fermer leurs poches ni déplacer d'objets. Les transferts déjà en cours sont revérifiés côté serveur et refusés si le coffre est devenu verrouillé, distant ou dans un autre bucket. Les abonnements périmés sont retirés avant toute publication. I près d'un véhicule verrouillé ouvre uniquement les poches et explique qu'il faut déverrouiller le coffre. Tests isolés : `pwsh -NoProfile -File tests/run-lua.ps1 -Test vehicle_access_test.lua` depuis la ressource (aucun jeu requis).

Templates dans `shared/items.lua` : `label`, `description`, `weight` (kg), `stack`, `icon` (nom Lucide connu de la page, repli `package`), `category`, `use = { consume, food, drink, health, notice }`. Un autre module peut brancher `LightRP.inventory.onUse(name, fn)`. API : `addItem(invId, name, count, metadata)`, `removeItem`, `count`, `canHold`, `move`, `use`, `drop`, `give`, `open(playerId, invId?)`, `playerId(playerId)`; hook `onItemUsed`. Actions page : `inventory.open|close|move|use|drop|give`. Touche I (`lightrp.inventory`). Staff : `/lightrp.giveitem <id|me> <item> [n]`, `/lightrp.items`.

Page : deux grilles aérées (poches à gauche, coffre / tas / stockage au centre) et une fiche objet à droite. Sans stockage proche, une zone de dépôt remplace la seconde grille. Un clic sélectionne ; un déplacement de plus de 6 px commence le glisser-déposer. La fiche affiche description, poids unitaire / total, quantité (1 / moitié / tout), utilisation, transfert, division, don au joueur le plus proche et dépôt. Les boutons Don / Dépôt demandent confirmation ; déposer par glisser-déposer reste direct. Le serveur vérifie toujours propriété, proximité, poids, métadonnées et quantités. Un coffre ne peut pas être glissé vers le sol en visant par erreur une case du joueur : il faut d'abord prendre l'objet.

Recherche indépendante par panneau sans renumérotation des cases, clic droit pour les actions rapides, flèches pour naviguer dans la grille, 1–5 pour sélectionner les premières cases, Shift + glisser pour la moitié d'une pile. Échap ferme d'abord une confirmation / un menu contextuel / un drag, puis l'inventaire, même depuis un champ texte. Tab reste dans la fenêtre. Les actions attendent le serveur (pas de modification optimiste ni de double envoi pendant l'attente) ; les snapshots frais arrivent par `lightrp:ui:inventory` à tous ceux qui regardent l'inventaire modifié. Une mise à jour ou une perte de focus annule les glisser-déposer devenus périmés. Grilles défilantes, états vides et erreurs explicites, transitions courtes avec respect de `prefers-reduced-motion`.

Tests UI : `ui/tests/inventory.browser.cjs` contre le serveur Vite. Le bridge simulé vérifie les actions réellement émises, les réponses serveur, les quantités, le focus, les annulations de drag, les tableaux Lua vides, les résolutions 720p / 1080p / 1440p / ultralarge et les alertes HUD. Installer Playwright dans l'environnement de test (ou fournir `PLAYWRIGHT_MODULE`), puis lancer `node tests/inventory.browser.cjs` depuis `ui`. `UI_URL` et `BROWSER_CHANNEL` permettent de changer le serveur et le navigateur ; par défaut Vite sur `127.0.0.1:5177` et Edge.

Le HUD et l'inventaire gardent l'identité jaune / noir du serveur : `--accent` du design system pour les actions principales, les sélections, les jauges de vie / endurance et les repères de navigation. Typographie sobre, fonds noirs translucides, aucune grosse plaque derrière les besoins. Les alertes et les autres besoins conservent leurs couleurs sémantiques.

**I ouvre et referme l'inventaire**. Le raccourci de fermeture est fourni par `Open77.input.keyFor` : il suit une éventuelle réaffectation dans les paramètres. Une fois le clavier capturé, la page ferme au relâchement d'un nouvel appui, sans réagir au relâchement initial ni aux répétitions de touche ; la lettre reste saisissable dans la recherche. Le client applique un court anti-rebond au retour du focus pour éviter une réouverture immédiate. Échap reste disponible depuis les champs texte. Tests des helpers : `node --experimental-strip-types --test tests/inventory-model.test.ts` (Node 22.6+).

## Ce que voit le joueur

- HUD bas gauche : vie principale et quatre jauges distinctes (armure, endurance, faim, soif),
  sans grosse plaque ni répétition du nom / logo. Les jauges évoluent en douceur, les variations
  de vie sont affichées brièvement, les alertes n'apparaissent que sous les seuils critiques.
  Une ombre diffuse garde les libellés lisibles sur le monde. Le HUD s'efface pendant l'inventaire.
  Voix et compteur véhicule restent dans leurs emplacements habituels.
- À la première connexion, un [wizard en quatre étapes](docs/character-creation.md)
  guide l'identité, l'histoire facultative, l'apparence et le récapitulatif. Design noir/jaune,
  retour arrière sans perdre les saisies, validation serveur et navigation clavier.
  Tant que l'identité n'est pas remplie, seul `/ooc` fonctionne dans le chat.
- **F1** ouvre le menu joueur (identité, informations et aide) ; **I** ouvre l'inventaire.
- Le chat normal est la parole en jeu à 20 m, sous le nom du personnage.

| Commande | Effet |
|---|---|
| `/register <Prénom> <Nom>` | Crée ou renomme le personnage. |
| `/w` · `/s` · `/ooc` | Chuchoter (4 m) · crier (45 m) · hors-jeu (global). |
| `/me` · `/do` · `/try` · `/roll [max]` | Action · scène · tentative (50 %) · dé. |
| `/pm <id> <texte>` | Message privé. |
| `/car <modèle>` · `/cars` · `/dv` | Appeler · ouvrir le garage · rendre. |
| `/who` · `/rules` · `/help` · `/report <texte>` | Présents · règles · aide · signalement au staff. |

Staff (`command.lightrp.<nom>` dans `acl.jsonc`) : `/lightrp.tp <id|me> <lieu|x y z>`,
`/lightrp.bring <id>`, `/lightrp.goto <id>`, `/lightrp.heal <id|me>`, `/lightrp.announce <texte>`,
`/lightrp.setname <id> <Prénom> <Nom>`, `/lightrp.car <modèle>`, `/lightrp.status`.

## Persistance

### Véhicules personnels et concessionnaire

**Night City Motors** (la map `cardealer`) propose un catalogue de véhicules à
acheter (cash ou banque) : **E** auprès du vendeur, à l'accueil du showroom. Le
véhicule acheté sort aussitôt sur la baie de livraison, verrouillé, clés en main, et
une balise avec route GPS y mène ; si la baie est prise ou qu'un autre véhicule
personnel est déjà dehors, il attend au garage et la GPS mène au garage. Quatre
voitures d'exposition (verrouillées, figées) occupent les podiums. Le **Public Garage** permet de sortir
et ranger les voitures personnelles ; elles restent récupérables après reboot ou
suppression admin. **Aucune voiture de départ n'est attribuée.**
**Fourrière** : un véhicule resté dehors lors d'un redémarrage, ou disparu du monde
(détruit, supprimé, bug), part en fourrière ; depuis n'importe quel garage, le
propriétaire peut y envoyer le sien (volé, perdu, bloqué), ce qui le retire du monde
où qu'il soit. On le récupère dans n'importe quel garage public (onglet Impound),
contre des frais selon le motif (`impound.fees` dans `server/config/garages.lua` :
gratuit après un redémarrage pour un véhicule intact, 400 €$ pour une épave (détruit,
explosé ou à 0 de santé, quel qu'en soit l'auteur ; l'assurance la répare), 150 €$ pour
un véhicule disparu sans trace d'épave (supprimé, nettoyé, bug), 250 €$ sur demande du
propriétaire, 500 €$ après un enlèvement par le staff). Une épave ne se range pas au
garage. Staff : `/lightrp.givevehicle <id|me> <modèle> [garage]`,
`/lightrp.impound` à côté du véhicule (ou avec son id réseau).
SQL est obligatoire pour ces fonctionnalités ; elles se ferment en cas d'erreur
de stockage. Voir [configuration, API et garanties](docs/personal-vehicles.md).

Tables `lightrp_characters` (identité Master, compte, prénom/nom, dernière position, faim, soif,
temps de jeu) et `lightrp_reports`. Sans base configurée le framework démarre et le dit dans le
journal ; tout vit alors le temps de la session.

## Crews (`server/modules/parties.lua`, `client/core/crew.lua`, page `features/crew/`)

Le **crew** est la seule façon de se grouper : missions, raid Chimera, activités (arène, courses,
poursuites, turf) et gigs de fixers. Le serveur fait foi ; le crew vit en mémoire (un
redémarrage le dissout). Réglages dans `server/config/missions.lua`, bloc `party` :
`maxSize` (8), `inviteSeconds` (60), `nearby` (15 m, liste « Nearby » des panneaux),
`inviteRange` (300 m, portée d'une invitation), `farRange` (250 m, au-delà un membre est
marqué FAR), `refreshMs` (2 s, rafraîchissement de l'état des membres).

- **Inviter** : **Alt + clic** sur un joueur › *Invite to crew* (`open77_contextmenu`, groupe
  « Crew », 15 m), ou `/crew invite <id>`, ou le bouton *Invite* des panneaux. Seul le chef
  invite ; le joueur doit être dans la même instance et à moins de 300 m. Le premier envoi crée
  un crew d'une personne qui reste **solo** tant que personne n'a accepté.
- **Répondre** : invite à l'écran au-dessus du cadre du crew, **Y** accepter / **N** refuser
  (touches réassignables, « Light RP: accept crew invite » et « Light RP: decline crew invite » ;
  l'invite affiche la touche effective), boutons cliquables quand le curseur est visible, ou
  **F1 › Crew**, l'onglet *Crew* du panneau Activités, `/crew accept` · `/crew decline`.
  Pendant le ready-check du raid, si les deux actions partagent la même touche, c'est le raid
  qui la prend. Pour rejoindre un autre crew, il faut quitter le sien (un crew d'une personne
  qui attend encore des réponses s'efface de lui-même).
- **Gérer** : Alt + clic › *Make crew leader* / *Kick from crew* (chef seulement) et, sur
  soi-même, *Leave crew* ; ou `/crew lead <id>`, `/crew kick <id>`, `/crew leave`, et les
  mêmes boutons dans F1 › Crew et l'onglet *Crew*. Si le chef part, le commandement passe au
  plus ancien membre ; un crew réduit à une personne se dissout.
- **Commandes** : `/crew` (état), `/crew invite <id> · accept · decline · leave · kick <id> ·
  lead <id> · matchmaking on|off` ; `/party` est un alias.
- **Cadre HUD** en bas à gauche, au-dessus de l'arme et des jauges : couronne du chef, YOU,
  DOWN / DEAD, MISSION / BOARD / ACTIVITY (ce qui occupe le membre), FAR. Huit lignes en 1080p,
  cinq sur un écran court (≤ 800 px de haut), le reste dans F1 › Crew ; votre ligne reste
  toujours visible. Pendant une mission, le même cadre montre la vie et l'armure de chaque
  opérateur (les inconnus du matchmaking en grisé). Les notices se décalent à droite du cadre
  quand les deux se touchent.

**Missions et raid Chimera.** Le **chef inscrit le crew** sur le tableau (**E**) ; un membre ne
peut pas s'inscrire seul (« Your crew leader tags the crew in. Leave the crew to go solo. »).
L'interrupteur **matchmaking** (touche **M** sur le tableau, F1 › Crew, onglet *Crew*,
`/crew matchmaking on|off`, réservé au chef) est **coupé par défaut** :

- coupé : tableau privé, personne d'autre n'entre ; le compte à rebours part dès que le crew
  atteint le minimum de la difficulté ; en dessous, l'inscription est refusée avec la marche à
  suivre (inviter, ou ouvrir le matchmaking) ;
- ouvert : le crew rejoint le tableau ouvert le plus rempli qui a la place, des joueurs solo en
  matchmaking complètent ; le compte à rebours part au maximum, ou l'hôte lance (**R**) dès le
  minimum atteint.

Un joueur solo suit la même règle : matchmaking coupé, il n'entre que dans une difficulté
jouable seul ; ouvert, il rejoint les tableaux ouverts. Le tableau signale les tableaux ouverts
voisins. Quitter le crew retire le joueur du tableau où le crew l'avait inscrit, en rejoindre un
annule son inscription solo ; fermer le matchmaking ferme le tableau du crew, ou retire le crew
d'un tableau partagé. La puce de file affiche FILLING (ouvert) ou CREW ONLY.

**Un membre sous la difficulté n'est jamais refusé** (décision du propriétaire, 2026-11-03).
Le chef choisit, et seul son palier (plus l'échelle « terminer la précédente ») borne ce choix ;
un membre dont le palier ou les clears n'ouvrent pas la difficulté est inscrit et lancé avec le
crew, joue la difficulté pleine et touche la paie entière, mais sa réputation est celle de la
plus haute difficulté que lui a ouverte (`Missions.rewardBasis`) : un Street porté en Critical
gagne 100, pas 450. Il le lit une fois, en notice « STREET CRED » (« Critical is above your
street cred: you play it, you earn the Standard reward (+100 reputation). »), le chef voit la
liste des récompenses réduites dans la réponse d'inscription, la notice de fin dit laquelle a
payé, et le tableau du membre montre la difficulté verrouillée « WITH THE CREW +100 REP ». Un
joueur solo, et un inconnu du matchmaking (inscrit pour lui-même), restent soumis au palier.

**Activités.** Le chef rejoint (*Join with the crew*) : chaque membre éligible est mis en file
avec les mêmes `options` et le même `options.squad = { id, leader, members }` ; un membre
inéligible reste dehors avec la raison en notice. Un membre ne lance pas d'activité seul ;
`/leave` le sort de la file, et si le chef annule, les membres mis en file avec lui sortent aussi.
En PvE, le membre reçoit la difficulté du chef (`options.difficulty`) même au-dessus de son
palier : il la joue et son résultat compte à la plus haute difficulté que son palier ouvre
(même règle que les missions, dite une fois en notice).

**Gigs de fixers.** Les offres ne vont qu'au chef d'un crew (ou aux joueurs solo) ; quand il
accepte, les membres libres qui ont un implant Neural-Link rejoignent le gig avec lui.

## Gigs de fixers (`server/modules/fixers.lua`, `server/config/fixers.lua`)

Des fixers fictifs (côté serveur : Mama Okoro, Silas "Ledger" Varga, Nix Delacroix) envoient au
hasard, par SMS Neural-Link, un « gig » tiré du catalogue : les missions de l'éditeur marquées
**Fixer gig** (`/lightrp.missions` › mission › Fixer gig : interrupteur, fixer, brief). Une mission
de fixer n'a **pas de tableau** dans la ville : on ne peut pas s'y inscrire, on la reçoit.

- **Offre** : carte du job (paie maximale par opérateur, durée), boutons *Take the job* / *Pass* (3 min).
- **Brief** une fois acceptée : l'objectif (le brief du fixer, sinon la description), le point de
  rendez-vous (= position du tableau dans l'éditeur) avec *Pin the meet point* (waypoint sur la
  carte), *Share the job* (un contact ou un numéro reçoit l'offre et peut *Join the crew*),
  *Go now* (le chef lance avec les présents, au moins le minimum de la difficulté) et *Bail*.
- **Rendez-vous** : quand tout l'équipage est au point (20 m), compte à rebours de 10 s puis la
  mission démarre comme une mission normale (kit, instance). Sans tout le monde après 20 min :
  lancement avec les présents s'ils suffisent, sinon le job tombe.
- **Crew** : quand le chef d'un crew accepte, ses membres libres (avec implant) rejoignent le
  gig ; les offres automatiques ne vont pas aux membres d'un crew qu'ils ne mènent pas.
- **Fin** : chaque opérateur est payé (`gig` à la banque) selon les règles des missions
  (cagnotte partagée, recharge de 60 min, plafond journalier, voir « Équilibrage ») +
  réputation ; le fixer envoie un message avec la somme réellement versée.
  La réputation suit le palier de chacun : un équipier invité sous le palier de la difficulté
  reçoit celle de la plus haute difficulté que son palier ouvre (`docs/pve-progression.md`) ; il
  le lit une fois en notice « STREET CRED » en rejoignant le gig.
- Les offres ne tirent que des difficultés ouvertes au palier de réputation du joueur
  (Standard au palier I, Hard au II, Critical au III).
- Puce HUD « GIG » (état `fixerGig`) : présents au point, horloge du rendez-vous, compte à rebours.
- Envoi automatique : un passage par minute, chance 8 % par joueur éligible (implant, en ville,
  libre, 2 min après l'arrivée), 20 min entre deux offres, 6 gigs ouverts au maximum.
- Staff : `/fixers.offer <id> [missionId] [difficulté]`, `/fixers.list`, `/fixers.cancel <gig>`,
  `/fixers.dispatch on|off|now`.
- Les gigs vivent en mémoire : un redémarrage les annule (leurs boutons répondent « Expired »).

## Activités et The Crossing (`server/modules/activities.lua`, `activities_hub.lua`)

Arène, courses, poursuites et événements sont des **ressources fournisseuses** séparées
(`op77_arena`, `op77_race`, `op77_chase`, `op77_fireworks`…) qui gèrent leurs propres instances.
Light RP en est le **noyau** : il possède le joueur pendant l'activité, capture son point de
retour, met ses armes RP de côté, gèle la faim et la soif, refuse objets RP, véhicules RP,
logement et ordres de travail selon les `caps` de l'activité, n'applique ni inconscience ni
hôpital, ne sauvegarde jamais la position de l'instance et ramène le joueur à la fin. Les
résultats deviennent statistiques et classements, **jamais d'objet** ; les résultats classés
paient des eddies (`server/modules/activity_pay.lua`, voir « Équilibrage ») et seules les
activités **PvE** rapportent en plus de la réputation (voir « Progression PvE » plus bas).

### Le contrat (exports serveur de `op77_lightrp`)

Tous synchrones : ils ne cèdent jamais la main et n'écrivent pas la base (un export qui attend
échoue chez l'appelant avec `export_yielded`). Un fournisseur n'agit que sur ses propres
activités (`GetInvokingResource`).

| Export | Rôle |
|---|---|
| `activityRegister(def)` → `true` \| `false, raison` | `def = { id, resource, label, kind, description, minPlayers, maxPlayers, caps }`. `id` préfixé par le fournisseur (`arena.ffa`, `race.trial`, `chase.1v1`), `kind` ∈ `pvp`, `race`, `chase`, `event`, `caps = { rpWeapons, rpItems, needs, vehicles }` (tout à `false` par défaut). Réenregistrer remplace. Facultatif : `modes = { { id, label } }` et `modeKey` (choix proposés par le panneau, rendus dans `options[modeKey]` ; un choix inconnu est refusé avant d'atteindre le fournisseur ; sans `modes`, `joinChoices` de la config peut en fournir — voiture ou à pied pour `chase.1v1`). Facultatif aussi : `pve = true` (joueurs contre bots, seule source de réputation ; sans le drapeau, la liste `pve.activities` de la config peut marquer l'id, `pve = false` l'emporte) et `difficulties = { "standard", "hard", "critical" }` (celles que le fournisseur joue vraiment ; sans elles, Standard seule). `botFill = true` : le fournisseur sait compléter avec des bots (`options.fill`, `options.match.bots`) — sans lui, le panneau ne propose jamais de bots ; un mode s'en exclut par `modes = { { id, label, botFill = false } }`. |
| `activityCheck(id, activityId, opts)` → `true` \| `false, raison` | Éligibilité seule, dans cet ordre : personnage actif, vivant et pas à terre, ni en mission ni dans une autre activité, pas dans le premier jour, pas dans un logement, pas en véhicule, pas blessé depuis 60 s, et dans la ville partagée (bucket 0). Avec `opts.difficulty` sur une activité PvE : aussi le palier de réputation qu'elle demande — pour un membre de crew, celui de son chef (un membre sous la difficulté passe, pour la récompense de son palier). La raison est une phrase anglaise montrée au joueur. |
| `activityEnter(id, activityId, opts)` | Revérifie, enregistre la possession, capture `{ x, y, z, heading, bucket }`, range les armes RP si `caps.rpWeapons` est faux. Le fournisseur déplace ensuite le joueur dans son bucket. PvE : la difficulté jouée est `opts.difficulty`, sinon celle choisie au panneau (celle du chef pour un membre mis en file avec lui), sinon la première proposée ; refusée au-dessus du palier d'un joueur solo ou d'un chef. Un membre de crew sous le palier n'est **jamais refusé** si son chef peut choisir cette difficulté : il la joue en entier, son résultat compte à la plus haute difficulté que son palier ouvre, et il le lit une fois en notice. |
| `activityLeave(id, activityId, opts)` | Libère. `opts.returnPlayer` (vrai par défaut) : retour au point capturé, bucket compris, en descendant du véhicule ; un joueur mort y réapparaît (jamais laissé mort), puis soin complet et armes RP rendues, sur le thread de Light RP. |
| `activityOwner(id)` | L'id de l'activité, `"missions"` pendant une mission, sinon `nil`. |
| `activityPlayer(id)` | `{ name, identifier, characterKey, gang = { id, label, grade, gradeLabel, tag, color } \| nil, job = { id, label, grade, gradeLabel, tag } }` — `nil` sans personnage actif ; `gang` vaut `nil` sans affiliation, `job.id` vaut `unemployed` sans emploi. Le gang et le métier sont lus dans `server/modules/jobs.lua` (mêmes vues que les state bags `gang` / `job`). `job.onDuty` reste absent : Light RP n'a pas de prise de service. |
| `notice(id, notice)` → `true` \| `false, raison` | Un message au joueur dans la notice de Light RP (sa page, son design) : **un fournisseur n'affiche jamais d'interface à lui** (règle du 2026-11-02), il passe par là et ne retombe sur `open77_notifications` que sans Light RP. `notice = { kind, title, body, durationMs, source }` nettoyé par `shared/notice.lua` : `kind` ∈ `info`, `success`, `warning`, `error` (`danger` lu `warning`, autre → `info`), titre 48 car., texte 280 (requis ; `text` ou `message` acceptés), durée 2 à 20 s (6 s par défaut). Un seul joueur, jamais `-1`. Raisons : `Invalid player.`, `invalid_notice`, `empty_notice`. Ce que le noyau dit déjà (réponse d'inscription « Request sent to … », sortie de file, MATCH FOUND, panneau de file) n'est pas répété par le fournisseur. |

Événements serveur, `TriggerEvent` / `AddEventHandler` uniquement (jamais `RegisterNetEvent` :
un client ne peut pas les lever) :

- fournisseur → noyau `op77_lightrp:activity:result (id, activityId, result)` avec
  `result = { placement, score, won, stats = { kills, deaths, timeMs, courseId, courseRevision… }, reputation, difficulty }`.
  Un résultat par entrée toutes les 15 s, et un seul jusqu'à 10 min après la sortie. `reputation`
  ne compte que pour une activité PvE (voir plus bas) ; ailleurs il est ignoré.
  Un résultat **non classé** n'enregistre rien — ni statistique (donc aucune ligne au Hall of
  Fame), ni classement, ni réputation, ni paie : mode bots staff, entrée non classée (match
  amical, PvP complété par des bots), `result.test = true`, `result.unranked = true` du
  fournisseur, ou résultat PvP portant `stats.bots` / `stats.vsAi`. Le noyau le marque alors
  `result.unranked = true` et `result.ranked = false` (voir *Lobby* plus bas). Les eddies d'un résultat accepté sont
  calculés par `server/modules/activity_pay.lua` (voir *Équilibrage*), à partir de
  `stats.durationMs` / `timeMs` / `seconds`, `quit`, `forfeit`, `bots`, `dnfReason`, de la
  difficulté de l'entrée et des statistiques de progression du mode.
- fournisseur → noyau `op77_lightrp:activity:status (activityId, { phase, players, queued, joinable, detail })`,
  à chaque changement (les envois rapprochés sont regroupés avant d'atteindre les joueurs).
- noyau → fournisseur `op77_lightrp:activity:join (id, activityId, options)` : le joueur l'a demandé
  depuis le panneau (`activityCheck` déjà passé). `options` contient le choix du panneau
  (`options.mode`, `options.course`…), `options.from` et, pour un crew, `options.squad = { id, leader, members }`
  (le même pour chaque membre mis en file par le chef ; voir *Crews*).
  Pour une activité PvE à difficultés : `options.difficulty` (celle du chef, déjà vérifiée contre son
  palier) et `options.scaling = { enemies, health, damage, ai }`, que le fournisseur traduit en bots.
  Toujours `options.ranked` ; selon le cas `options.fill = { allies, enemies }` et
  `options.match = { id, ranked, friendly, format, players, teams, side, bots }` (voir *Lobby*).
- noyau → fournisseur `op77_lightrp:activity:leaveRequest (id, activityId)` : le joueur veut
  partir (panneau, F1, `/leave`) — y compris s'il n'est qu'en file. Sans `activityLeave` du
  fournisseur sous 15 s, le noyau libère et ramène le joueur lui-même (`dropped`, raison `timeout`).
- noyau → fournisseur `op77_lightrp:activity:dropped (id, activityId, raison)` : `disconnect`,
  `character`, `provider_stopped`, `timeout` ou `core_stopped`. La possession est déjà libérée.
- noyau → tous `op77_lightrp:activity:ready ()` : Light RP vient de démarrer, les fournisseurs se
  réenregistrent (en plus de leur propre écoute de `onResourceStart`).
- `op77_lightrp:announce (text, { title, durationMs })` — ou une table `{ body, title, durationMs }`,
  la forme d'`op77_fireworks` : annonce diffusée par le même chemin que `/lightrp.announce`
  (chat + notice). Texte nettoyé, 2 à 200 caractères, titre 40, durée 3 à 30 s, une par seconde.

Quand un fournisseur s'arrête, ses activités sont oubliées et ses joueurs ramenés ; lors d'un
rechargement, ce que la nouvelle VM a déjà réenregistré est conservé.

Buckets : arène `4100000–4199999`, course `4200000–4299999`, poursuite `4300000–4399999`
(ville 0, hall 620000, pratique 700000+id, cabines 710000+id, logements 1000000+id, missions
3000000+n). Le carburant ignore les véhicules de ces buckets ; clés et fourrière ne concernent
que les véhicules du système RP (personnels, location, `/car`), jamais ceux qu'une activité crée.

### À l'intérieur de Light RP

`LightRP.activities.owns(id)`, `owner(id)`, `allows(id, cap)` et `savedPosition(id, repli)`
sont les crochets d'une ligne posés dans `server/main.lua` (pas de réapparition RP),
`medical.lua` (pas d'inconscience), `armament.lua` (armes RP rangées, la porte de dégâts laisse
passer les armes de l'activité), `needs.lua` (faim et soif gelées), `characters.lua` (position
sauvegardée = point de retour), `inventory.lua` (utiliser, donner, jeter — donc consommables,
grenades et barre rapide), `grenades.lua`, `cyberware.lua` (lames Mantis), `rental.lua`,
`garages.lua`, `vehicles.lua` (`/car`), `keys.lua`, `fuel.lua`, `housing.lua`, `job_runs.lua`,
`job_work.lua` et `fixers.lua`. Les **missions** sont un fournisseur interne : un opérateur en
mission est refusé par `activityCheck`, et une déconnexion en mission sauvegarde le point du
tableau, plus les coordonnées de l'arène.

### Statistiques, classements, réputation

Tables `lightrp_activity_stats` (par compte + personnage + activité, et par parcours
`courseId@révision` pour les courses : parties, victoires, kills, morts, meilleur score, meilleur
temps, meilleure place, réputation) et `lightrp_activity_rep_daily` (réputation accordée par
compte et par jour UTC).

**Seules les activités PvE donnent de la réputation.** PvP, courses, poursuites et événements
enregistrent parties, victoires et classements à 0 réputation, quoi que demande le résultat. Un
résultat PvE vaut la réputation de sa difficulté (`pve.difficulties` : Standard 30, Hard 60,
Critical 100) × le poids de l'activité (`pve.activities` : `arena.pve` 1,0, `race.pve` 0,5,
`turf.pve` 1,2, `chase.pve` 0,6) : en entier pour une victoire qui ne précise rien, sinon
`min(reputation, ce plafond)`. La difficulté comptée est celle de l'entrée, abaissée à la plus
haute que le palier du joueur ouvre. Le tout reste sous `reputation.dailyCap` (500) par compte
et par jour ; avec `grantTo = "missions"` elle s'ajoute à la réputation de rue des missions.
`reputation.pvpGrants = true` rétablit l'ancienne règle (tous les genres, bornés à
`maxPerResult` = 50). Classements : top 5 par activité, au meilleur temps pour les courses, aux
victoires sinon. Sans base, tout vit le temps de la session.

### Ce que voit le joueur

- **The Crossing**, l'esplanade de Westbrook où arrivent les nouveaux : deux terminaux (marqueur
  jaune, **E**) — *The Crossing* ouvre le panneau Activités, *Contracts* liste les tableaux de
  mission de la ville avec un itinéraire GPS vers chacun (les tableaux eux-mêmes ne changent
  pas). Une épingle « Activities » sur la carte (`op77_map3d`, catégorie Missions).
- **Panneau Activités** (`ui/src/features/activities/`) : la liste (état, joueurs, file), le
  détail (choix du mode quand il y en a, badge PVE et choix de la difficulté — les verrouillées
  disent quel palier les ouvre —, Rejoindre / Partir / Annuler, la raison d'un refus),
  votre bilan et le classement ; onglets *Contracts* et *Crew* (invitations, membres, matchmaking
  des missions, joueurs à 15 m). Bandeau d'état en tête : dans une activité, en attente, en
  mission, ou pourquoi pas.
- **F1 → Activities** (ouvre le panneau, et *Leave …* / *Cancel …* direct) et **F1 → Crew**
  (accepter ou refuser une invitation, membres, passer le commandement, exclure, matchmaking,
  quitter).
- **Neural-Link → Gigs & Arena** (`client/core/activities.lua`) : ouvre le même panneau partout.
- À la fin du premier jour (terminé ou passé) : une notice qui pointe vers The Crossing, et un
  itinéraire si le joueur en est loin. Les répliques voix de Mara ne changent pas.
- Pied du panneau : palier de réputation (« Street cred ») et réputation PvE du jour.
- Commandes : `/leave` (quitter l'activité ou sa file), `/activity [list · join <id> [mode|difficulté] · leave]`.
  Staff : `/lightrp.activities` (activités, propriétaires, files, opérateurs en mission) et
  `/lightrp.survey [libellé]` (position et cap, au format de la config).

### Lobby : bots, file classée, match amical (`server/config/activities.lua` → `lobby`)

Les bots sont un **choix du panneau**, plus une commande. Une activité n'en propose que si elle
figure dans `lobby.activities` **et** que son fournisseur a déclaré `botFill = true` (un mode peut
s'en exclure) ; une activité absente de la liste se rejoint comme avant (classée, sans bots ni
match amical). Les poursuites (`op77_chase`) n'y sont pas : joueurs réels ou NCPD du jeu seulement.

- **PvE, « Fill empty slots with bots »** (`allies = true`) : des bots alliés complètent le crew
  jusqu'à `seats` places (par défaut `maxPlayers`) — 6 places et un crew de 4 donnent 2 alliés.
  Le fournisseur les reçoit dans `options.fill.allies` ; ils ne prennent aucun multiplicateur de
  difficulté. **Toujours classé** : réputation, paie et Hall of Fame comme d'habitude.
- **PvP, « Play with bots »** (`bots = true`) : le noyau forme tout de suite un match avec des bots
  (`options.match`, `bots` par camp). **Non classé.**
- **File classée** (`queue = true` : `arena.duel`, `arena.teams`, `race.grid`, `race.foot`) : une
  demande PvP sans bots devient un ticket dans la file du noyau. Un crew reste entier, du même
  côté, et compte pour la taille d'équipe (`teams`, `teamSize`, une taille par mode possible) ; un
  crew trop grand est refusé. Appariement par **tranche de cyberware** : le rang que débloque le
  street cred (`cyberware.lua` → `gating.byRank`, le plus haut membre pour un crew), ramené à une
  tranche par `matchmaking.brackets`. D'abord la même tranche ou la voisine, puis l'écart s'élargit
  selon l'attente du plus ancien (`matchmaking.widen` : 2 tranches à 60 s, 3 à 80 s, tout le monde à
  100 s) ; les courses ignorent les tranches (`brackets = false`) et attendent `gatherMs` (15 s)
  d'autres joueurs une fois le minimum atteint. Le panneau montre le chrono, trouvés / requis,
  *Near your rank* ou *All ranks*, et *Cancel*. Après `fillAfterMs` (2 min), le chef se voit
  proposer *Fill with bots* (match non classé) ou *Keep waiting*. `turf.war` garde la file de son
  fournisseur (une guerre à la fois) ; la proposition de bots y vaut aussi.
- **Match amical** (`friendly = true`) : le chef de crew ouvre *Friendly match* ; le noyau répartit
  le crew par street cred (*Auto-balance*), le chef déplace les joueurs (flèches ou clic, un camp
  plein échange), met des bots dans les places vides si le mode le permet, puis *Start*. Les membres
  voient la répartition sans la modifier. Toujours **non classé**.

**Ce qui compte.** Le noyau seul décide : `options.ranked` sur chaque `join`,
`A.isRanked(entrée | match | joueur)` et l'export `activityRanked(id)`. Un résultat non classé
(match amical, PvP avec bots, mode bots staff, `test`, `unranked` du fournisseur, `stats.bots` /
`stats.vsAi` en PvP — jamais un PvE avec alliés) est marqué `result.unranked = true`,
`result.ranked = false` dans `A.result` et s'arrête là : aucune statistique (donc aucune ligne du
Hall of Fame, dont les lignes d'activité viennent de `lightrp_activity_stats`), aucun classement, aucune réputation, et
`activity_pay.lua` n'est pas appelé (il refuse aussi `result.unranked` de lui-même). Un résultat
classé porte `result.ranked = true`.

Le panneau envoie l'action `activities.lobby` (`fill`, `friendly`, `move`, `balance`, `bots`,
`cancel`, `start`). Un ticket expire après 15 min, un match formé qui n'a pas démarré après 2 min.
`/lightrp.bots on|off` (staff) reste disponible pour tester seul : rien n'est enregistré.

### Mise en place de The Crossing (en jeu)

Les positions des terminaux sont des décalages plausibles depuis le point d'arrivée
(`server/config/activities.lua`, `hub.terminals`, marqués `-- survey in game`). Sur place :
`/lightrp.survey board`, coller la ligne en `position = { ... }` du terminal, idem pour
`contracts`, puis `ensure op77_lightrp`. La zone de sécurité ne peut pas venir de la config
(ce sont des enregistrements audités en base) : **/admin → Safe zones**, nouvelle zone centrée
sur l'esplanade (`-756.6, 777.3`), rayon d'environ 30 m, *blockShoot*, *blockMelee* et
*blockGrenades* cochés, puis publier.

## Dogtown, zone PvP ouverte (`server/modules/dogtown.lua`, `server/config/dogtown.lua`, `client/core/dogtown.lua`, page `features/dogtown/`)

Dans la ville partagée (bucket 0), Dogtown est une zone de danger : passé les murs, quiconque
porte la **mise** peut tuer quiconque la porte aussi, et une mort coûte une part de l'argent
liquide — jamais la banque. Les membres d'une même escouade ne se blessent pas. **Ailleurs, rien
ne change** : le tir ami global reste coupé (défaut de la plateforme), les zones de sécurité
restent sûres (y compris celles posées dans Dogtown), missions et activités gardent leurs buckets
et leurs règles. Les règles sont celles du propriétaire (2026-11-03) ; tous les nombres sont dans
`server/config/dogtown.lua`, commentés, et le guide (Johnny) les cite depuis cette config.

### Comment le PvP est accordé

- Le tir ami global n'est jamais activé. Toutes les 500 ms (`sweepMs`), chaque joueur est placé
  dedans ou dehors (polygone plan, toute hauteur : toits et stade compris) et les joueurs
  **qualifiés** reçoivent une portée de combat (`Open77.combat.createScope`) dans le bucket 0.
  Qualifié = personnage actif, bucket 0, ni activité ni mission, vivant ou en récupération, zone
  allumée, **mise en poche**, **et** dans le polygone ou marqué au combat. Une position de plus
  de 2,5 s (`positionMaxAgeMs`) garde la dernière réponse.
- **Escouades** : les membres d'une escouade `LightRP.parties` partagent une équipe de combat
  (`Open77.combat.setTeam`, `teamBase` + numéro de l'escouade) : la plateforme refuse les coups
  entre eux. L'équipe suit chaque changement d'escouade (`onPartyChanged`) ; en quittant la
  portée, le joueur repasse sans équipe, sauf s'il est passé dans un autre bucket ou une
  activité, qui gère alors la sienne. L'arbitre refuse aussi entre équipiers, le temps d'une mise
  à jour.
- **Marque de combat** : un coup entre deux joueurs de la zone marque les deux pendant 20 s
  (`combatTagMs`), renouvelée à chaque coup. Un joueur marqué qui sort reste attaquable jusqu'à
  la fin de la marque.
- L'arbitre de dégâts (`Open77.combat.onDamage`) ne fait que **refuser** : il ferme l'écart entre
  deux balayages quand l'un des deux ne qualifie plus. Zones de sécurité, porte d'armement,
  activités refusent comme avant (le premier refus gagne).
- Limites de la plateforme : 32 joueurs par portée, 8 portées par ressource (`maxScopes`), 64 sur
  tout le serveur, partagées avec les autres ressources. Au-delà de 32 joueurs qualifiés, le
  groupe est découpé par position (d'ouest en est) et deux joueurs de groupes différents ne
  peuvent pas se blesser.
- Prérequis : les permissions `combat.scope.control`, `combat.config` (équipes),
  `players.teleport` (escorte) et `world.vehicles` (voiture de l'escorte), déclarées dans
  `open77.lua`, et **la base de données** — sans elle, les zones de sécurité sont indisponibles
  et leur arbitre refuse tout PvP, et l'argent ne bouge pas (`database_unavailable`).

### La mise

- Il faut `stake.minCash` (€$ 1 000) **en poche** pour se battre ; la banque ne compte pas. En
  dessous, dans la zone : pas de PvP (ni tirer, ni être touché), une notice avec **le montant
  manquant**, et la tuile passe au jaune avec un compte à rebours.
- Après `stake.graceMs` (10 s), toujours dedans et toujours sous la mise : téléporté à la
  **sortie la plus proche** (`exits`, points hors du polygone, distance plane ; sans sortie
  utilisable, l'hôpital). À pied (`dismount`), sauf le conducteur seul dans sa voiture : la
  voiture est posée 4 m à côté de lui (`Open77.vehicles.setTransform`). Un passager laisse le
  véhicule aux autres. Un téléport refusé est retenté 3 s plus tard.
- Même chose après une mort : relevé dedans sous la mise → notice, délai, escorte. Revenir
  au-dessus de la mise (DAB, virement) arrête le compte à rebours.
- Les quatre sorties livrées sont **à relever en jeu** (`-- survey in game`, `z` estimés) :
  `/lightrp.dogtown survey exit [nom]` imprime la ligne (refusé dans le polygone). Une sortie
  dans le polygone est ignorée et signalée au démarrage.

### Mort, sac, bonus

- La mort suit le **parcours médical normal** (inconscience, trauma kit, transfert à l'hôpital,
  hors de Dogtown). **Pas de facture d'hôpital** après une mort dans un combat de Dogtown
  (`waiveHospitalBill`, exemption `dogtown` de `economy_sinks.lua`) : la zone a déjà pris sa part
  et la banque reste hors du jeu. La dispense vaut jusqu'à 15 s après la remise sur pied (au plus
  30 min après la mort).
- Un kill compte quand les deux joueurs partagent une portée, ou que le tueur a touché la victime
  dans les 20 dernières secondes ; victime dans le bucket 0, aucun des deux en activité.
- **Perte** : `loot.share` (10 %) de l'argent porté, au moins `loot.min` (€$ 100), au plus
  `loot.max` (€$ 750), jamais plus que ce qui est porté.
- **Sac** (`loot.mode = "bag"`) : un sac scellé (on ne peut rien y déposer) tombe là où la victime
  est tombée, avec la perte **plus un bonus serveur** de `loot.bonus` (25 % de la perte) : de
  l'argent neuf (`Inv.dropCash`, option `mint`), payé par personne. Le sac est **réservé au tueur
  et à son escouade** pendant `loot.reserveMs` (15 s ; l'escouade au moment du ramassage), puis
  n'importe qui peut le prendre, victime comprise : le tueur a la priorité, ensuite c'est
  Dogtown. C'est un tas au sol de l'inventaire, en mémoire seulement : perdu au redémarrage et
  après `LightRpConfig.inventory.drop.ttlMinutes`.
- **Plafond du bonus** : `loot.bonusDailyCap` (€$ 3 000) par **compte** (tous ses personnages) et
  par jour UTC, bonus de kill et primes compris. Table `lightrp_dogtown_bonus_daily`
  (identifiant, jour, total), cache en écriture relu une fois par jour, comme
  `activity_pay.lua`. Le bonus compte quand le sac est posé, même si un autre le ramasse. Journal
  : `dogtown bonus: +N minted into a cash bag for <compte> (killer …, victim …)`.
- `"transfer"` : la perte passe dans la poche du tueur et le bonus est versé à côté (écriture
  `dogtown_bonus`). Un sac impossible à poser retombe sur le transfert.

### Anti-gank, primes

- Escouade du tueur avec `antiGank.crewSize` (4) membres ou plus **dans la zone** (dedans, ou
  marqués dehors ; la mise n'est pas exigée pour compter) : la perte est multipliée par
  `antiGank.lossFactor` (0,5), après le minimum et le plafond — le sac et son bonus rétrécissent
  avec.
- Victime d'une escouade plus nombreuse dans la zone que celle du tueur : bonus × (1 +
  `antiGank.underdogBonus`), soit × 1,5, toujours dans le plafond.
- **Prime** : `bounty.streak` (5) kills comptés d'affilée dans la zone sans mourir → une épingle
  `op77_map3d` (`addBlip(-1, …)`, réticule rouge pulsant, « BOUNTY · Nom ») qui suit la cible
  toutes les `bounty.refreshMs` (3 s) sur la carte de tout le monde. Retirée à la mort (quelle
  qu'en soit la cause), en quittant la zone (dehors et plus marqué : la série s'arrête), à la
  déconnexion, au changement de personnage, à l'arrêt de la zone ou de la ressource. Celui qui
  l'abat (kill compté) reçoit `bounty.perKill` (€$ 250) par kill de la série, au plus
  `bounty.max` (€$ 1 500), **en liquide** (écriture `dogtown_bounty`), dans son plafond. Journal :
  `dogtown bounty: +N to <compte> (…)`.

### Anti-farm, déconnexion en combat

- **Paires bloquées** : même compte (`lootSameAccount`), même escouade (`lootCrewmates`), ou même
  tueur sur la même victime en moins de 10 min (`pairCooldownMs`, par personnage et dans ce
  sens : la revanche reste possible). **Rien du tout** : ni kill, ni mort, ni perte, ni sac, ni
  bonus. Chaque refus est expliqué aux deux joueurs.
- **Déconnexion en combat** (`combatLog`) : un joueur marqué qui se déconnecte dans la zone lâche
  le sac d'une mort (même perte, **sans bonus**) à sa dernière position, réservé à l'escouade de
  son dernier attaquant ; journal `combat log by …`. Rien s'il était déjà à terre (le kill
  compte) ou mort depuis moins d'une marque. Nouveau crochet de framework `onDisconnecting`,
  appelé avant `onDisconnected` tant que l'inventaire et le portefeuille sont chargés (il peut
  attendre).
- **Tout passe par `LightRP.money`** : `dogtown_loss` chez la victime, `dogtown_loot` chez celui
  qui ramasse (la note nomme le bonus), `dogtown_bonus` (transfert), `dogtown_bounty`. Ramasser
  son propre sac reste une écriture `inventory`. Fichiers partagés touchés : `inventory.lua`
  (tas scellés, `mint`, `reserve`, raison `reserved`), `economy.lua` (étiquettes),
  `economy_sinks.lua` (exemption), `framework.lua` (`onDisconnecting`). À l'arrêt de la
  ressource, portées, équipes, épingles de prime et sacs en cours sont retirés.

### Statistiques, Temple de la renommée

Table `lightrp_dogtown_stats` (compte + personnage + semaine, la semaine 0 portant le cumul) :
kills comptés, morts, meilleure série (`best_streak`, colonne ajoutée par migration au démarrage
sur une table plus ancienne), eddies ramassés (`dogtown_loot` et `dogtown_bonus` positifs ; une
prime n'est pas du butin). Semaines UTC, du lundi 00:00. Classement F1 : les 5 meilleurs tueurs
de la semaine (`stats.leaderboardSize`), relus toutes les 60 s. **Temple de la renommée**
(`halloffame.lua`, onglet PvP) : `dogtown.kills` (kills à vie, détail K/D et meilleure série) et
`dogtown.streak` (meilleures séries, hors vue d'ensemble) ; `hallOfFame = false` les retire.
**Aucune réputation.** Sans base, tout vit en mémoire le temps de la session.

### Ce que voit le joueur

- **À l'entrée** : un bandeau rouge « DOGTOWN — NO LAW · ANYONE CAN KILL YOU », l'argent porté et
  ce qu'un tueur en prendrait (plus le bonus) ; sans la mise, « NO STAKE · YOU CAN'T FIGHT
  HERE » et le montant manquant. Une ligne de chat (mise, argent porté) au plus toutes les 2 min
  (`entryChatMs`).
- **Tuile en haut à gauche** tant qu'il est dedans ou marqué : marque de combat, argent en jeu,
  série en cours, « BOUNTY · ON EVERYONE'S MAP » ; sans la mise, tuile jaune « €$ X missing » et
  « ESCORTED OUT IN N S ».
- **F1 → Dogtown** : les règles chiffrées depuis la config (mise, perte, bonus et plafond avec le
  bonus gagné aujourd'hui, escouades, prime, fair-play), son bilan (semaine, total, meilleure
  série, série en cours ou prime), les meilleurs tueurs de la semaine.
- **Guide (Johnny)** : le sujet « Dogtown PvP » (mise, mort et sac, bonus, escouades, prime,
  anti-farm, déconnexion, hôpital) et les réponses PvP de la ville suivent `enabled` dans la
  config, pas l'interrupteur `/lightrp.dogtown`.
- **Carte 3D (`op77_map3d`, touche M) et minicarte** : la zone elle-même, le polygone du serveur
  posé sur le sol, les routes et les bâtiments : remplissage rouge translucide hachuré en
  diagonale, bordure rouge pleine, étiquette « DOGTOWN · DANGER ZONE » lisible à l'échelle de la
  ville ; sur la minicarte, la ligne sous la carte affiche ce nom tant qu'on est dedans. La tête
  de mort rouge reste au centre. Réglages dans `area` de `server/config/dogtown.lua` (couleurs,
  opacité, motif `hatch` ou `solid`, épaisseur de bordure, position de l'étiquette, minicarte,
  pulsation ; `area = false` n'affiche que l'épingle). La zone suit `/lightrp.dogtown on|off`
  (retirée à l'arrêt) et `survey apply|reset` (redessinée chez tout le monde) ; le serveur envoie
  au plus 150 points (un relevé plus long perd d'abord ses sommets les moins marquants). Les
  primes y ajoutent leur épingle mobile.
- **Carte du jeu** : le sprite de la porte de Dogtown (panneau de danger en repli), rien de plus.
  La plateforme n'y pose que des épingles (`Open77.blips` : sprite, titre, distance de
  visibilité) et `Open77.map` ne donne ni projection monde-écran ni distance de zoom : aucun
  polygone, cercle ou calque n'est possible sur la carte native (vérifié dans
  `wiki/data/api.json`).

### Staff : `/lightrp.dogtown`

ACL `command.lightrp.dogtown` (couverte par `command.lightrp.*`).

| Sous-commande | Effet |
|---|---|
| `status` | État, joueurs dedans (dont sous la mise), marqués, portées, primes, source du polygone, sorties, mise, perte, bonus, plafond, réserve. |
| `on` · `off` | Allume ou coupe la zone jusqu'au prochain redémarrage (`enabled` fixe le défaut). `off` retire portées, équipes, marques, séries et primes. |
| `survey add` · `undo` · `clear` | Ajoute un point à sa position (avec le district que voit le moteur), retire le dernier, vide le brouillon. |
| `survey list` | Écrit le brouillon au format de `polygon` dans le journal serveur. |
| `survey apply` · `reset` | Le brouillon devient la zone pour la session ; retour au polygone de la config. La zone dessinée sur la carte 3D suit. |
| `survey test` | Dedans ou dehors ici, et district du moteur. |
| `survey passage` | Ligne `{ x, y, z, heading }` pour une extrémité de passage. |
| `survey exit [nom]` | Ligne d'une sortie pour `exits` (dehors seulement ; se placer sur la route, dos à Dogtown). |

Chaque client signale aussi les frontières de district que franchit le moteur ; un désaccord
avec le polygone est journalisé (`logDistrictMismatch`). C'est une aide au relevé, jamais une
source d'autorisation : le serveur ne connaît pas les districts.

### Mise en place (en jeu)

Le polygone livré (30 points) est dérivé des volumes du district `ep1_dogtown` des données de
`op77_map3d` : il épouse l'extérieur des murs, donc un peu large, et chaque point est marqué
`-- survey in game`. Longer les murs avec `/lightrp.dogtown survey add` à chaque angle,
`survey apply` pour essayer, `survey list`, coller les lignes dans `polygon`. Relever ensuite les
sorties avec `survey exit` (une par porte ou route principale) et les coller dans `exits`, puis
`ensure op77_lightrp`.

**Phantom Liberty.** Dogtown appartient à l'extension, que le lanceur exige. Sur une sauvegarde
où l'extension n'a jamais commencé, les portes du district peuvent rester fermées ; Open77 coupe
le téléport de frontière, mais l'accès réel est à vérifier en jeu. Si les portes restent closes,
`passages` ajoute des points **E** (dehors → dedans et retour, sortie refusée en étant marqué,
entrée refusée sans la mise), relevés avec `survey passage`.

## Progression PvE : paliers de réputation, difficultés, cyberware

Proposition complète et décisions du propriétaire (2026-11-03) : `docs/pve-progression.md`.
Paliers, noms, prix du haut de gamme, poids PvE et plafond de 500 par jour sont validés tels que
proposés. En bref :

- **Cinq paliers** de réputation de rue (`server/config/missions.lua`, `reputation`) : I Street
  (0), II Merc (500), III Operator (1 500), IV Edgerunner (4 000), V Legend (10 000). Missions,
  raid Chimera et gigs rapportent 100 / 220 / 450 par difficulté ; les activités PvE 30 / 60 / 100
  × poids, 500 par jour ; le PvP rien. Une notice « STREET CRED » annonce chaque palier ;
  `/missions.rep <id>` affiche points, palier et prochain seuil.
- **Difficultés** : Hard demande le palier II, Critical le III (`difficultyTiers`), en plus de
  l'échelle « terminer la difficulté précédente » au même point (`requireClear`, gardée). Le
  contrôle vaut pour le chef d'un crew et pour un joueur solo, sur les tableaux de mission et le
  raid, pour les offres de fixers et pour les activités PvE (`activityCheck` / `activityEnter` /
  panneau). **Un membre de crew sous la difficulté choisie par son chef n'est jamais refusé** :
  il joue la difficulté pleine et gagne la réputation de la plus haute difficulté qu'il a ouverte
  (voir *Crews*).
- **Cyberware** (`server/config/cyberware.lua`, `gating`) : rangs I–II ouverts à tous, III au
  palier II, IV au III, V au IV, V+ au V (le champ `repTier` d'un implant l'emporte). Le serveur
  refuse la pose avant tout paiement ; la dépose reste possible, un implant déjà posé reste actif
  et `lightrp.cyberware <id> give` ignore le palier. La clinique montre les implants verrouillés
  (badge `REP III`, ligne « Street cred », bouton `LOCKED`) ; le bundle `op77_ripperdoc/web` doit
  être reconstruit depuis `ripperdoc-ui` pour l'afficher.
- **Haut de gamme** : rang V — Iron Lungs Mk.2 (+80 endurance max), Adrenaline Booster Mk.2
  (+15 endurance/s), Bioplastic Blood Vessels (+3 vie/s) ; rang V+ — Neofiber Actuators Mk.3
  (dash `apex`), Aegis Dermal Plating (+100 armure), Rara Avis (+100 vie max), Zetatech Apogee
  (overdrive `apex`, 11 s).
- **PvP classé** : `activeInPvp` (vrai par défaut, décision du propriétaire : le cyberware reste
  actif en PvP classé). À `false`, les dons de session (dash, overdrive, slam) et les stats
  passives sont suspendus dans une activité non PvE et rendus à la sortie (crochet de module
  `onActivityChanged`) ; jambes et bras durables restent.
- **Titres cosmétiques PvP** : voulus plus tard, pas construits.

### Hall of Fame (`server/modules/halloffame.lua`, page `features/halloffame/`)

Un vrai prop serveur (par défaut la borne d'arcade `electronics.arcade`, collision active) à
environ 4 m à gauche du terminal *The Crossing*, face tournée vers le point d'arrivée, plus un
point **E** devant lui : pas de marqueur au sol, une icône trophée flottante (avec la distance)
et une épingle sur la carte (`board.blip`). **ALT + clic** sur le prop (`open77_contextmenu`,
modèles avec collision seulement) ou **E** ouvrent le dialogue
`halloffame` de la page Light RP : onglets *Overview* (podiums), *PvP*, *Races*, *PvE*,
*Missions*, *Wealth* ; podium du top 3, rangs 4 à 10, la ligne du joueur surlignée ou « YOU #N »
sous chaque tableau. Noms de personnages uniquement, jamais d'identifiant de compte.

- Sources : `lightrp_activity_stats` (victoires et kills PvP / PvE, meilleurs temps sur le
  parcours courant de chaque course), `lightrp_mission_rep` et `lightrp_mission_clears`
  (contrats, braquages et raid Chimera classés par difficulté), `lightrp_wallets` + l'objet
  `cash` de l'inventaire (fortune, coupée par `showWealth = false`). Sans base : les résultats de
  la session (`LightRP.activities.memoryRows`), et la page le dit.
- Cache serveur : reconstruit toutes les 5 min ; le bouton REFRESH au plus une fois par 30 s et
  par joueur (10 s minimum pour tout le serveur). Ouvrir le panneau ne lit que le cache.
- Extension : `LightRP.hallOfFame.registerBoard(key, { tab, title, unit, provider })` (exemple en
  tête du module).
- Staff : `/lightrp.halloffame place` (se placer devant l'emplacement, face à là où l'écran doit
  regarder : le panneau se pose 0,8 m derrière, le point E suit, la ligne de config est
  affichée), `where` (position, modèle, échelle, rotation et ligne de config), `refresh`. Coller
  la ligne dans `server/config/halloffame.lua` (`board`).
- Choix du prop en jeu (staff) : `/lightrp.halloffame model` liste les candidats numérotés de
  `board.models` (alias, échelle, décalage de lacet, libellé ; `*` = en place) ;
  `model <n|alias> [échelle|-] [rotation]` remplace le prop tout de suite (le nouveau d'abord :
  un modèle refusé laisse l'ancien debout ; le point E, l'icône et l'ALT + clic suivent) et
  garde le choix en kvp (`halloffame.board.model`), prioritaire sur `board.model` au
  démarrage ; `model reset` revient au défaut de la config. La rotation s'ajoute au décalage
  de la ligne (« - » : l'échelle de la ligne). Le balayage des orphelins reconnaît tous les
  candidats.
- Exclusions (`exclude` dans `server/config/halloffame.lua`) : staff et personnages de test ne
  figurent sur **aucun** tableau, y compris ceux ajoutés par `registerBoard` (un seul filtre
  dans `HoF.refresh`, après tous les fournisseurs, avant le classement : les autres
  remontent). Un joueur exclu ne voit pas de « YOU #N ». Les lignes portent le compte Open77
  (`GetPlayerIdentifier`, le même `userId` que les principaux d'`acl.jsonc`) et la clé du
  personnage (`<compte>#<clé>`).
  - Staff (`staff = true`) : le test de Light RP (`LightRP.staff.isStaff`, les
    `LightRpConfig.staffPermissions` dans l'ACL). L'ACL ne répond que pour un joueur en ligne
    (une ressource ne peut pas lire `acl.jsonc`) : chaque compte staff vu en ligne est retenu
    dans le magasin kvp de la ressource (`data/`, conservé aux redémarrages) et reste exclu
    hors ligne ; un compte retenu revu en ligne sans les droits est oublié. **Limite** : un
    staff jamais vu en ligne depuis cette version est inconnu — mettre son `userId` dans
    `staffAccounts`. Une ACL qui ne répond pas (pas d'`acl.read`) n'oublie personne.
  - Tests (`tests = true`) : `characters` (`<compte>#<clé>`), `accounts` (`<compte>`, tous ses
    personnages), plus la liste de la commande `/lightrp.halloffame exclude <playerId [account]
    | compte#clé | compte>`, `include <…>` (retire de la liste ; sur un compte, oublie aussi
    un staff retenu), `excluded` (état). Conservée en kvp ; chaque changement relance la
    reconstruction des tableaux.

## Housing

Appartements et maisons instanciés, achat/location, clés persistantes, coffre par
contrat et attribution administrative. **F1 → My homes** ou `/housing` pour les
joueurs ; **/admin → Housing** ou `/housingadmin` pour créer les modèles, capturer
les points et ajouter/supprimer des logements. SQL est obligatoire.
Voir le [guide housing](docs/housing.md) pour le parcours complet et les garanties.

## HUD d'activité (`client/core/activity_hud.lua`, page `features/activityhud/`)

Le HUD commun des activités (arène, course, poursuite, guerre de territoire…) : une ressource
fournisseur décrit son état, Light RP le dessine dans son design. C'est un pur calque, sans focus,
sans entrée et sans touche. Un seul HUD à la fois : un `Show` plus récent remplace l'ancien, quelle
que soit la ressource qui l'envoie. Exports **client** (toujours sous `pcall`, l'appel lève si
`op77_lightrp` est arrêté) :

```lua
local ok, why = exports.op77_lightrp:ActivityHudShow(hud)      -- remplace tout l'état
exports.op77_lightrp:ActivityHudPush("feed", { text = "Vi took the zone", tone = "success" })
exports.op77_lightrp:ActivityHudPush("banner", { title = "FINAL LAP", text = "...", tone = "accent", durationMs = 2500 })
exports.op77_lightrp:ActivityHudPush("result", { title = "Street Race", placement = 2, subtitle = "Watson Loop",
    lines = { { label = "Time", value = "3:02.48" } }, durationMs = 9000 })
exports.op77_lightrp:ActivityHudClear()
exports.op77_lightrp:Notice({ kind = "warning", title = "NCPD Chase", body = "Crash! Engine stalled." })
```

`Notice` est la notice côté client, mêmes règles que l'export serveur `notice` (`shared/notice.lua`,
même limite de débit que le HUD) : c'est le repli d'un fournisseur quand son HUD n'est pas affiché.

Chaque appel rend `true` ou `false, raison` (`invalid_hud`, `invalid_kind`, `invalid_payload`,
`not_owner`, `rate_limited`, `ui_unavailable`). Tout est validé et borné côté Lua ; un champ
invalide est ignoré, jamais transmis tel quel.

| Champ de `hud` | Contenu | Bornes |
| --- | --- | --- |
| `activity` | identifiant libre (`race.grid`) | 48 car., `[%w_%-.:]` |
| `title`, `subtitle` | nom de l'activité, lieu ou mode | 48 / 80 car., titre par défaut « Activity » |
| `phase` | `lobby` · `countdown` · `running` · `ended` | autre valeur → `running` |
| `timer` | `{ remainingMs, label, countUp }` | 0 à 24 h, libellé 16 car. |
| `countdown` | ms avant le départ (phase `countdown`) | ≤ 60 s ; **≤ 10 est lu en secondes** |
| `objective` | une ligne sous le bandeau | 120 car. |
| `stats` | `{ { label, value } }` | 4 au plus, 24 car. chacun |
| `progress` | `{ { id, label, value 0..1, tone } }` | 3 au plus |
| `teams` | `{ { name, color, score, self } }` | 4 au plus ; `color` = `#rgb`/`#rrggbb` ou un ton |
| `scoreboard` | `{ columns = {...}, rows = { { name, values, self, team } } }` | 4 colonnes, 16 lignes, une seule `self` |
| `hints` | `{ { key, label } }` | 4 au plus |

- **Temps relatifs** : `timer.remainingMs` et `countdown` valent au moment de l'envoi, la page
  décompte seule. Un `countUp` n'avance qu'en phase `running` (un temps final reste figé). Ne pas
  renvoyer le HUD à chaque frame : à chaque changement d'état suffit (30 appels/s au plus).
- Un `countdown` en millisecondes qui tombe à 10 ou moins serait lu en secondes : envoyer `0`.
- `countdown` absent en phase `countdown` : « GET READY ». Au-delà de 5 s, une puce « STARTS IN » ;
  les 5 dernières secondes en grands chiffres, puis « GO ».
- Tons : `accent` (jaune, réservé au joueur et aux temps forts), `danger`, `info`, `success`.
- `team` d'une ligne : index (1..4) ou nom d'une équipe de `teams`.
- Pushs : `feed` (5 lignes au plus, effacées après ~5 s), `banner` (0,8 à 10 s, 3 s par défaut),
  `result` (titre ou `placement` 1..999 / court texte comme « DNF », 2 à 30 s, 8 s par défaut,
  6 lignes au plus).
- **Propriété** : `Push` et `Clear` sont refusés (`not_owner`) quand le HUD affiché appartient à
  une autre ressource. Un `Clear` du propriétaire laisse la carte de résultat et la dernière
  bannière finir leur temps.
- **Fin de vie** : le HUD disparaît à l'arrêt ou au redémarrage de la ressource propriétaire, et
  à un changement de personnage.

À l'écran : bandeau en haut au centre (phase, titre, horloge, deux équipes de part et d'autre ou
puces d'équipes dessous, objectif), panneau à droite à la place du bon de travail (stats, barres,
classement centré sur le joueur, raccourcis), fil en haut à droite près de la minimap (en haut à
gauche sous 1600 px), compte à rebours, bannières et carte de résultat au centre. Pendant un match
(toute phase sauf `lobby`), les cadrans faim/soif, leur alerte et le bon de travail s'effacent
(besoins gelés dans les activités) ; santé, armure, énergie, chat, voix et notifications restent.
En `lobby` à côté d'un bon de travail, le bon garde sa place et les raccourcis montent sous le
bandeau. Le HUD se masque quand le menu F1 ou une boîte de dialogue est ouvert.

Aperçu sans jeu : `npm run dev` puis `?registered=1&activity=race` (`trial`, `arena`, `turf`,
`lobby`, `countdown`, `result`, `editor`, `demo` pour une course complète). Tests :
`tests/activity_hud_client_test.lua`.

## WebUI

Source dans `ui/` à la racine du projet (Vite, React 18, TypeScript strict, zustand,
lucide-react). `npm run build` type-vérifie puis écrit `web/` (app.js, app.css, index.html,
polices auto-hébergées). `npm run dev` sert la page dans un navigateur avec un bridge simulé :
`?menu=1&view=vehicles&staff=1&registered=1&vehicle=1` pour forcer un état.

Le design system est porté dans `ui/src/design` : `tokens.css` (jetons du kit), `components/`
(Button, Panel, Badge, SectionHeader, HazardStripe, Keycap, StatusChip, VitalBar, MicIndicator,
Notification, Input, Toggle, Tabs, ListRow, Modal). Aucune ressource externe : polices et icônes
sont embarquées, l'hôte WebUI ne sert que les fichiers de la ressource.

Après une modification serveur : `ensure op77_lightrp` dans la console. Après un changement de la
page ou du client, reconnexion des joueurs (`reload_policy "reconnect"`).
