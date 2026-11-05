# Événements staff (modes anim)

Le staff lance des événements de monde là où il veut et les enchaîne en soirées :
**/admin > Events**, ou `/lightrp.event` dans le chat. Tout tourne sur le moteur des
world bosses (`server/modules/world_bosses.lua`) : monde ouvert (instance 0), HUD de
zone, parts à la contribution (dégâts et kills validés par le serveur), laisse des
ennemis, renforts à 66 % et 33 % de la vie du boss, épingle de carte et avis de fin.

Fichiers : `server/modules/staff_events.lua` (la logique, le bureau, la commande),
`server/config/staff_events.lua` (réglages), `ui/src/features/support/EventsTools.tsx`
(les pages du bureau), tests `tests/staff_events_test.lua` et
`ui/tests/staff-events.browser.cjs`.

## Les trois types

| Type | Ce qui sort | Réglages (`server/config/staff_events.lua`) |
|---|---|---|
| **Cyberpsycho** | Un seul cyberpsycho (un des 16 enregistrements *Psycho Squad* de `shared/mission_defs.lua`, ou au hasard), vie ×12, comportement *assault* : il chasse qui entre dans sa zone. Le nom affiché (« Static », « Red Line »…) est tiré de `psycho.names` si le staff n'en donne pas. | `psycho` |
| **Gang attack** | Un chef de gang (vie ×15) qui tient le point, son escouade sur un anneau de 8 m, et deux vagues de renfort qui arrivent du bord de la zone (0,8 × le rayon). Sept gangs : 6th Street, Valentinos, Tyger Claws, Maelstrom, Voodoo Boys, Wraiths, Militech. | `gang.crews` |
| **World boss** | Un world boss du catalogue (les missions tagguées *World boss* dans `/lightrp.missions`), à sa place d'origine avec son décor, ou déplacé. | — |

Un world boss **déplacé** (ici, sur un joueur, à un spot) prend une disposition compacte,
car le décor écrit pour sa place d'origine ne veut plus rien dire ailleurs : le boss sur le
point, ses autres groupes de départ sur un anneau de 9 m, ses renforts au bord de la zone,
les patrouilles deviennent *defend* et les routes sont effacées. Il garde l'identifiant du
catalogue, donc ses drops iconiques s'il est payé. Le staff peut le renommer.

## Où

- **Its own place** (world boss seulement) : la zone et le décor d'origine ;
- **Here** : un cercle autour du staff, refusé s'il est dans une instance ;
- **On a player** : autour de la position du joueur au lancement, refusé s'il est dans
  une instance (mission, activité, intérieur) ;
- **Saved spot** : un point nommé enregistré à l'avance (`lightrp_event_spots`, 80 au
  plus). On le prépare en noclip, on l'enregistre, on le réutilise.

Le rayon de zone (25 à 150 m, 50 par défaut) et la durée (5 à 60 min, 15 par défaut ;
pour un world boss, 0 garde sa durée d'origine) se règlent au lancement. Le nom du lieu
annoncé vient du champ *Place name*, sinon du nom du spot, sinon du district que le client
envoie (`Open77.world.district()`, un libellé jamais vérifié), sinon « Night City ».

## Niveaux

| Niveau | Vie | Dégâts | Nombre |
|---|---|---|---|
| Normal | ×1 | ×1 | ×1 |
| Hard | ×1,6 | ×1,25 | ×1,5 |
| Brutal | ×2,5 | ×1,6 | ×2 |

Ils s'appliquent en plus de l'événement : la vie du cyberpsycho, la vie et les dégâts des
ennemis d'un gang, la première difficulté et le nombre de gardes d'un world boss (le boss
reste seul, un groupe ne dépasse jamais 12).

## Payé ou pour le fun

- **Sans paie** (le défaut, droit `command.lightrp.events`) : rien n'est payé ni compté.
  Pas d'argent, pas de réputation, rien pour les dailies, les titres, les contrats ni les
  drops iconiques (`onWorldBossFinished` / `onWorldEventEnded` ne partent pas). Les avis et
  le HUD disent « staff event: no pay, just the glory », le récap affiche la raison
  `staff_event`.
- **Payé** (droit `command.worldboss.start` en plus) : exactement un world boss. Cagnotte
  `LightRpEconomy.worldBosses`, plafond quotidien `dailyPaid` partagé avec les world bosses
  aléatoires, réputation, hooks.

**Silent** : ni avis à la ville ni épingle de carte, les joueurs tombent dessus. Un
événement silencieux n'est jamais la « tête d'affiche » du tableau des événements.

## Plusieurs à la fois

Le moteur des world bosses tient jusqu'à `LightRpWorldBosses.maxLive` événements à la
fois (4), le world boss aléatoire compris. L'aléatoire ne sort que quand aucun événement
n'est dehors. Un même world boss du catalogue ne peut pas sortir deux fois en même temps.
Chaque zone a son HUD (le tag : WORLD BOSS, CYBERPSYCHO, GANG ATTACK). Un événement staff
construit de toutes pièces (cyberpsycho, gang) ne relance pas l'horloge de l'aléatoire ;
un world boss du catalogue, si.

## Soirées (Event nights)

Des rounds annoncés à toute la ville : 30 s avant le premier, 60 s de pause entre deux,
un résumé à la fin (« 3 of 5 fight(s) won »). Un seul à la fois.

| Soirée | Déroulé |
|---|---|
| **Psycho Night** | Un cyberpsycho par round, à un spot différent à chaque fois (mélangés), de plus en plus dur. Avec deux spots ou plus, le dernier round en lâche deux en même temps. |
| **Boss Rush** | Les world bosses du catalogue l'un après l'autre, chacun à sa place. |
| **Gang War** | Un seul round : N gangs (2 à `maxLive`) frappent N spots en même temps. Il faut N spots enregistrés. |
| **Siege** | Gang après gang au même endroit, de plus en plus dur ; un cyberpsycho mène le dernier. |

Le niveau part de celui choisi et monte au fil des rounds (sauf Gang War et Boss Rush).
Un round qui ne peut pas sortir (moteur plein) est retenté six fois à 10 s d'intervalle,
puis passé. *Stop the night* arrête les rounds ; l'option *call off* termine aussi les
événements encore dehors, sans paie.

## Le bureau : /admin > Events

- **Live now** : les événements dehors (boss, lieu, vie, combattants, temps restant, qui
  l'a lancé, payé ou non). Sur un événement : *Go to the event* (au bord de la zone),
  *End it as a win* (payé : les parts comme pour un kill, droit world boss requis),
  *Call it off* (personne n'est payé).
- **Launch an event** : le configurateur (type, boss / cyberpsycho / gang, où, joueur ou
  spot, niveau, durée, rayon, paie, silencieux), un résumé de ce qui va se passer et ce qui
  bloque, puis *Review and launch* : nom du lieu, nom du boss, note, confirmation.
- **Event nights** : le choix de la soirée, des rounds (ou des gangs), du lieu, du niveau
  de départ, de la paie ; l'état de la soirée en cours.
- **Saved spots** : enregistrer sa position, aller à un spot, lancer à un spot, supprimer.
- **Random world bosses** (droit world boss) : couper ou rallumer l'aléatoire jusqu'au
  prochain redémarrage, et *Next random boss now*.

Chaque action est inscrite dans `lightrp_staff_audit` avant d'agir, sous la clé de
mutation de la page : une requête rejouée rend la première réponse, sans second
lancement. Actions : `eventLaunch`, `eventStop`, `eventWin`, `eventGoto`, `eventNight`,
`eventNightStop`, `eventSpotSave`, `eventSpotDelete`, `eventRandom`, `eventNext`.

## /lightrp.event

Pour aller vite depuis le chat, toujours ici, sans paie, annoncé :

```text
/lightrp.event psycho [psycho_id|random] [normal|hard|brutal]
/lightrp.event gang [sixthstreet|valentinos|...|random] [niveau]
/lightrp.event boss <titre> [here] [niveau]      (sans here : à sa place)
/lightrp.event night <psycho_night|boss_rush|gang_war|siege> [rounds] [here]
/lightrp.event stopnight
/lightrp.event stop [all]                         (all : l'aléatoire aussi)
/lightrp.event list
```

`/worldboss.list` et `/worldboss.stop [win] [all]` voient aussi tous les événements.

## Permissions

| Permission | Accès |
|---|---|
| `command.lightrp.events` | Bureau Events, événements sans paie, spots, soirées sans paie (moderator / operator par `command.lightrp.*`) |
| `command.worldboss.start` | En plus : événements et soirées payés, victoire d'un événement payé, world bosses aléatoires (operator par `command.worldboss.*`) |
| `command.lightrp.event` | La commande `/lightrp.event` (par `command.lightrp.*`) |

## À valider en jeu

Testé hors jeu (`tests/staff_events_test.lua`, `ui/tests/staff-events.browser.cjs`).
Pas encore vu en jeu :

- un cyberpsycho « here » et un gang « on a player » apparaissent au bon endroit,
  projetés sur la navmesh, et chassent ;
- un world boss déplacé en ville, renforts compris ;
- deux événements à la fois, chacun avec son HUD ;
- une Psycho Night de deux rounds, avec ses annonces.
