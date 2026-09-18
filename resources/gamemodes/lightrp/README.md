# lightrp

Le gamemode Light Roleplay d'**Open//77 Official Roleplay**. Petit, autoritaire côté serveur, et
prévu pour être lu puis modifié : trois scripts serveur, une configuration partagée, aucun script
client (le shell, le chat, les notifications et les véhicules sont fournis par les ressources
système officielles).

| Fichier | Rôle |
|---|---|
| `open77.lua` | Manifeste : dépendances, scripts, permissions. |
| `shared/config.lua` | Spawn, hôpital, lieux, portées du chat, catalogue de véhicules, règles. Téléchargé par les clients : aucun secret. |
| `server/persistence.lua` | Personnages (`/register`), dernière position, signalements. MySQL optionnel : sans base, tout vit le temps de la session. |
| `server/chat.lua` | Le veto sur `chatMessage` et toutes les commandes de parole. |
| `server/main.lua` | Arrivée, réveil à l'hôpital, véhicules, commandes du staff. |

## Ce que voit un joueur

- À l'arrivée il est placé à sa **dernière position** (ou au point d'arrivée la première fois) et
  lit le message de bienvenue.
- **Le chat normal est en jeu (IC)** et porte à 20 m, sous le nom du personnage. Tant qu'il n'a
  pas fait `/register Prénom Nom`, seul `/ooc` fonctionne.
- Mort : après 10 s au sol, il se réveille à l'hôpital.
- Un véhicule civil à la fois, `/car <modèle>` et `/dv`.

| Commande | Effet |
|---|---|
| `/register <Prénom> <Nom>` | Crée ou renomme le personnage (lettres, tirets, apostrophes, accents). |
| texte | Parole IC, 20 m. |
| `/w <texte>` | Chuchoter, 4 m. |
| `/s <texte>` | Crier, 45 m. |
| `/ooc <texte>` | Hors-jeu, tout le serveur, sous le nom du compte. |
| `/me <action>` | Action, 20 m. |
| `/do <description>` | Description de scène, 20 m. |
| `/try <action>` | Réussit ou échoue à 50 %. |
| `/roll [max]` | Lance un dé. |
| `/pm <id> <texte>` | Message privé par id de session (`/id`). |
| `/car <modèle>`, `/cars`, `/dv` | Appeler, lister, rendre un véhicule. |
| `/who`, `/rules`, `/help`, `/report <texte>` | Présents, règles, aide, signalement au staff. |

## Commandes du staff

Restreintes : le joueur doit tenir `command.lightrp.<nom>` dans `acl.jsonc` (les rôles
`helper`, `moderator` et `operator` livrés les portent déjà).

| Commande | Effet |
|---|---|
| `/lightrp.tp <id\|me> <lieu \| x y z>` | Téléporter (vivant : déplacement, mort : réapparition). |
| `/lightrp.bring <id>` / `/lightrp.goto <id>` | Amener un joueur / le rejoindre. |
| `/lightrp.heal <id\|me>` | Soigner, ou réanimer s'il est mort. |
| `/lightrp.announce <texte>` | Annonce chat + notification à tous. |
| `/lightrp.setname <id> <Prénom> <Nom>` | Renommer un personnage. |
| `/lightrp.car <modèle>` | Appeler un véhicule, y compris ceux marqués `staffOnly`. |
| `/lightrp.status` | Joueurs, personnages, véhicules, état de la base. |

## Persistance

Avec `database.enabled` et `OP77_DATABASE_CONNECTION`, la ressource crée `lightrp_characters`
(identifiant Master, nom du compte, prénom/nom, dernière position, temps de jeu) et
`lightrp_reports`. La clé est `GetPlayerIdentifier()`, l'identité durable du Master : un joueur
qui change de pseudo garde son personnage. Sans base, la ressource démarre quand même et l'indique
dans le journal.

## Modifier

- Points et lieux : `shared/config.lua` → `spawn` et `locations` (coordonnées monde en mètres).
- Portées : `chat.icRange`, `whisperRange`, `shoutRange`, `meRange`.
- Véhicules : `vehicles.catalog` (`record` = enregistrement TweakDB `Vehicle.*`), `staffOnly` pour
  les réserver au staff, `maxPerPlayer`, `cooldownMs`.
- Exiger un personnage avant de parler IC : `chat.requireCharacterForIc`.

Après une modification serveur : `ensure lightrp` dans la console du serveur (ou Warden →
Resources → Restart).
