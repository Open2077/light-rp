# Open//77 Official Roleplay — starter Light RP

Projet de démarrage d'un serveur **Light Roleplay** pour OPEN//77 : la distribution serveur
officielle (`2.31.13+op77.82`, Windows x64) déjà extraite ici, une configuration prête, un ACL, et
le framework `op77_lightrp` (personnages, chat de proximité, besoins, véhicules civils, hôpital, staff) avec
sa WebUI globale React + TypeScript habillée du design system Open//77 RP.

```
E:\Open77\LightRP
├── Open77.Server.exe, *.dll        distribution officielle (non versionnée)
├── server.jsonc                    configuration de production (master + licence)
├── server.local.jsonc              profil de test local (sans master ni licence)
├── acl.jsonc                       droits en jeu : rôles helper/moderator/operator, owner
├── server.env.example              variables d'environnement à copier dans server.env
├── Start-LightRP.cmd               démarrage production (lit server.env)
├── Start-LightRP-Local.cmd         démarrage local
├── templates\op77_lightrp\         template pour l'assistant de première installation
├── ui\                             source de la WebUI (Vite + React + TS) → build dans resources\...\op77_lightrp\web
└── resources\gamemodes\op77_lightrp\  le framework (voir son README)
```

Seuls la configuration, l'ACL, les scripts de démarrage, le template, `ui/` (sans `node_modules`) et
`resources/gamemodes/op77_lightrp` sont suivis par git (`.gitignore` en liste blanche). Les binaires
viennent du zip.

## WebUI

La page du framework se construit avec Node 20+ : `cd ui && npm install && npm run build`. Le
résultat (`web/`) est versionné, donc un clone démarre sans Node. `npm run dev` ouvre la page dans
un navigateur avec un bridge simulé pour travailler le design sans le jeu.

## Démarrer en local (aujourd'hui)

1. Base de données (facultatif mais recommandé) : MariaDB/MySQL locale avec une base
   `open77_lightrp`. `server.env` contient déjà la chaîne pour la MariaDB de cette machine.
2. Double-cliquer `Start-LightRP-Local.cmd`. Le serveur écoute en loopback : jeu `127.0.0.1:11828`,
   téléchargement des ressources `11829`, Warden `http://127.0.0.1:11830`.
3. Au premier démarrage la console affiche `Warden setup PIN: ########`. Ouvrir Warden, entrer le
   PIN, créer le compte administrateur.
4. Se connecter avec le client Open//77 en preset développement (source « Local development » du
   launcher ou connexion directe) sur `127.0.0.1:11828`.

Le profil local accepte des clients non authentifiés (`devLocalAuth`) et refuse de tourner en
public : c'est un bac à sable.

## Passer en production

1. **Licence** : créer une clé `op77_live_…` sur <https://open2077.net/account/keys> et la coller
   dans `server.env` (`OP77_LICENSE_KEY=`). Sans clé, `server.jsonc` refuse de démarrer.
2. **Base de données** : créer une base et un utilisateur dédiés (modèle dans
   `server.env.example`), renseigner `OP77_DATABASE_CONNECTION`.
3. **Adresse** : dans `server.jsonc`, `network.publicEndpoint` = `IP.PUBLIQUE:11828` et
   `resources.download.publicBaseUrl` = l'URL que les joueurs atteignent pour le port 11829.
   Ouvrir 11828/UDP et 11829/TCP. Recommandé : un proxy TLS (Caddy, nginx) devant 11829 et
   `publicBaseUrl` en `https://`, puis `allowInsecureHttp: false`.
4. **Visibilité** : `identity.visibility` passe de `unlisted` à `public` quand tout répond.
5. **Warden** : reste sur `127.0.0.1:11830`. L'atteindre par tunnel SSH
   (`ssh -L 11830:127.0.0.1:11830 user@serveur`) ou derrière un proxy TLS. Jamais en HTTP nu
   sur Internet.
6. `Start-LightRP.cmd` (ou un service qui exécute `Open77.Server.exe --config server.jsonc --no-setup`
   avec les mêmes variables d'environnement).

Sur un Linux, la même arborescence fonctionne avec l'archive `linux-x64` et `./Open77.Server`.

## Droits en jeu

`acl.jsonc` définit trois rôles (`helper`, `moderator`, `operator`, repris de `open77_admin`) et
deux principaux : le propriétaire (`*`) et `w0dm4n` en `operator`. Pour ajouter quelqu'un :
Warden → *In-game rights* → *Known identities* → *Rights*, ou à la main dans le fichier puis
`acl.reload` dans la console. L'identité d'un joueur se lit avec `identity.dump` dans sa console
de jeu, ou dans Warden.

Les commandes du framework réservées au staff sont sous `command.lightrp.*`.
`/admin` ouvre désormais le bureau RP (ACL `command.admin`) ; `/adminfull` conserve
la console technique officielle. Les reports ont leurs droits dédiés :
[bureau staff et suivi des tickets](resources/gamemodes/op77_lightrp/docs/admin-support.md).

## Jouer

Les pistolets d'inventaire, boîtes de 30 balles et équipement des deux mains
disposent d'un [guide de prototype et de ses limites natives](resources/gamemodes/op77_lightrp/docs/armament.md).
Aucun grant d'arme ni de munitions n'est automatique à la connexion.

**1–5** utilisent les objets de la première ligne des poches ; maintenir **Tab**
affiche la [hotbar](resources/gamemodes/op77_lightrp/docs/hotbar.md).

Un joueur inconscient attend au moins **90 secondes** avant de pouvoir abandonner.
Un autre joueur peut le stabiliser en **8 secondes** avec un `trauma_kit` :
[système médical](resources/gamemodes/op77_lightrp/docs/medical.md).

**F1** ouvre le menu joueur ; à la première connexion le parcours de création
présente l'identité, l'apparence et l'arrivée en ville. Le chat normal est la parole en jeu à 20 m, `/ooc` pour le
hors-jeu, `/me` `/do` `/try` `/roll`, `/car <modèle>` et `/dv` pour un véhicule, `/report` pour
ouvrir un dossier privé suivi par le staff. Détails et réglages dans `resources/gamemodes/op77_lightrp/README.md`.

## Mettre à jour le serveur

Le zip est une installation neuve, pas une migration. Arrêter le serveur, sauvegarder `server.jsonc`,
`acl.jsonc`, `server.env`, `.open77/` (identité Master et clé de signature des ressources) et la
base, extraire la nouvelle archive par-dessus, remettre ces fichiers, redémarrer. Le framework
`op77_lightrp` n'est pas dans l'archive : il ne bouge pas.

## Packages plateforme rehabillés

`resources/system/open77_contextmenu` (menu ALT + clic), `resources/system/open-voice` (indicateur vocal F11) , `resources/system/open77_chat` (chat T) et `resources/system/open77_wardrobe_ui` (garde-robe) sont des copies de la distribution dont la page `web/` a été réécrite dans le design system Open//77 RP (tokens et polices copiés dans chaque `web/`, car une page WebUI ne charge que les fichiers de sa propre ressource). Le protocole Lua ↔ page est inchangé. Ils sont versionnés ici : après une mise à jour du serveur, vérifier avec `git status` que la nouvelle distribution n'a pas écrasé `web/` et rejouer le commit si besoin.

## Ports utilisés

| Port | Protocole | Rôle |
|---|---|---|
| 11828 | UDP | Jeu |
| 11829 | TCP | Téléchargement des ressources par les joueurs |
| 11830 | TCP | Warden (loopback) |
