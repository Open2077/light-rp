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

## Architecture

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

Un portefeuille par personnage actif : argent liquide + compte bancaire numéroté `XXX-XXX` (lettres et chiffres sans O/I/0/1). Tables `lightrp_wallets` (compte, propriétaire, cash, bank) et `lightrp_transactions` (registre signé : opening, deposit, withdraw, transfer_in/out, pay_in/out, fee, refund, staff, salary…). Le portefeuille s'ouvre à l'activation du personnage (`economy.startingCash` / `startingBank`) ou au premier chargement d'un personnage actif qui n'en a pas ; il suit le slot (hook `onCharacterLoaded`).

API pour les autres modules (jobs, boutiques, loyers) : `LightRP.money.addCash/removeCash/addBank/removeBank(playerId, amount, kind, note, counterparty)`, `deposit/withdraw`, `transfer(playerId, "XXX-XXX", amount, note)`, `pay(playerId, targetId, amount)` (main à main, `economy.payRange`), `creditAccount(number, …)` (fonctionne hors ligne), `findAccount`, `format`. Hook `onMoneyChanged(playerId, wallet, delta, balance, kind)`. Les soldes ne passent jamais sous zéro ; un drapeau `busy` par portefeuille évite deux opérations entrelacées.

Page : état `money` (`cash`, `bank { number, balance }`, `history`), actions `money.deposit|withdraw|transfer|pay` (prêtes pour la future page ATM). Commandes : `/money`, `/bank`, `/pay <id> <montant>`, `/transfer <compte> <montant> [note]`, `/deposit`, `/withdraw` (tant que `economy.counterCommands`), staff `/lightrp.givemoney`, `/lightrp.takemoney`, `/lightrp.account`.

## Menu joueur (F1)

Menu liste façon RageUI (design system : Menus / RageMenu, porté en `ui/src/design/components/RageMenu.tsx` avec des classes `o77-rage*`) : une colonne, une ligne surlignée, flèches pour bouger, Entrée pour descendre, Retour arrière / Échap pour remonter, F1 pour fermer. `features/menu/PlayerMenu.tsx` construit l'arbre depuis l'état serveur à chaque rendu et garde une pile `{ key, index }`. Premier sous-menu : **Identity** (ID citoyen, prénom, nom, naissance, origine, compte bancaire, temps de jeu, statut). Le client Lua prend le clavier seul (`setFocus(true, false)`) ; le menu ne s'ouvre qu'avec un personnage actif et hors briefing. Il n'y a plus de menu « terminal », ni de commandes de spawn ou de dépôt pour les joueurs : véhicules par `/lightrp.car` et `/lightrp.dv` (staff), argent par l'ATM à venir.

## Ce que voit le joueur

- HUD : vie, armure, endurance, faim, soif, micro avec portée (WHISPER 4 m / NORMAL 15 m /
  SHOUT 40 m), id de session, population, horloge ; compteur véhicule quand il conduit.
- À la première connexion, un dialogue d'identité demande prénom et nom ; tant qu'il n'est pas
  rempli, seul `/ooc` fonctionne dans le chat.
- **F5** ouvre le menu terminal : Personnage, Véhicules, Staff (si ACL), Aide.
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

Tables `lightrp_characters` (identité Master, compte, prénom/nom, dernière position, faim, soif,
temps de jeu) et `lightrp_reports`. Sans base configurée le framework démarre et le dit dans le
journal ; tout vit alors le temps de la session.

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
