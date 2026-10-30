# op77_scenes — édition LightRP de open77_scenes

Scènes RP synchronisées sur le mobilier du monde. La première : s'allonger sur un fauteuil de
ripperdoc (72 fauteuils chirurgicaux de Night City), avec les animations d'entrée, de pose et de
sortie du prologue. Tous les joueurs du bucket voient la même chose, y compris ceux qui arrivent
en cours de scène.

## Ce qui diffère de `open77_scenes` (plateforme)

- **Prompt « E » de LightRP** : chaque fauteuil libre proche devient un point local
  d'`op77_lightrp` (export client `InteractSetLocal`). C'est le même keycap que les boutiques,
  garages et guichets, et la même touche (`lightrp.interact`). Un appui déclenche l'événement
  client `op77_scenes:choice`, puis l'intention `op77_scenes:start` côté serveur. Le serveur
  revérifie tout : distance, fauteuil libre, joueur vivant, à pied.
- `/scene` et `/standup` sont réservés au staff (pas de commandes hors RP pour les joueurs).
- Noms renommés pour pouvoir coexister dans le dossier `resources/` avec la version plateforme :
  - événements `op77_scenes:*` ;
  - convars `op77_scenes_reach`, `op77_scenes_prompt_radius`, `op77_scenes_turn_before_end_ms` ;
  - touches `op77_scenes_stand` (H, se lever) et `op77_scenes_pose` (G, changer de pose).
- `auto_start true`, dépendances `open77_animations` et `op77_lightrp`.

**Ne pas charger `open77_scenes` en même temps** : les deux réclameraient les mêmes fauteuils.

La partie serveur (`shared/`, `server/`) est celle de `open77_scenes` à l'identique, hormis ces
renommages. Une correction faite en amont (open77-base `resources/system/open77_scenes`) se reporte
ici à la main.

## Joueur

Près d'un fauteuil libre : keycap **E « Lie down »**. Une fois allongé, **H** pour se lever et
**G** pour changer de pose ; les deux touches sont réassignables dans les paramètres. Le prompt
disparaît pendant la scène et quand un autre joueur occupe le fauteuil.

## Client requis

Un client Open77 avec le profil `ripperdoc` et `Open77Scenes.archive` dans `archive/pc/mod`.
Ils sont livrés avec le client à partir de op77.169.

## Tests

```powershell
pwsh resources/standalone/op77_scenes/tests/run-lua.ps1 -Test all.lua
```

Ils exécutent la vraie partie serveur contre `tests/fakes.lua`, via le `lua54.dll` du serveur.

## Console (restreinte)

`scenes.status`, `scenes.near <pid>`, `scenes.start <pid> <spot>`, `scenes.stand <pid>`,
`scenes.idle <pid>`, `scenes.tune <kind> <x> <y> <z> <yaw>`. Guide auteur et recherche : dans
open77-base, `wiki/scenes.md` et `docs/research/rp-scenes.md`.
