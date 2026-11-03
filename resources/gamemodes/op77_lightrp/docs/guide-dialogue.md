# Parler à Johnny : le dialogue

Johnny Silverhand, à The Crossing, ne s'ouvre plus sur le panneau FAQ. Il parle d'abord,
comme un dialogue du jeu : sa réplique en sous-titre en bas de l'écran, quelques choix
pour le joueur à droite du centre, le monde et Johnny restent visibles. La FAQ complète
reste à un choix de distance (« Write it down for me. », « Let me type it. »).

Le texte en jeu est en anglais. Ce document reprend l'arbre en français pour relecture ;
les choix sont cités tels qu'ils s'affichent.

- Contenu : `server/config/guide_dialogue.lua` (modifiable sans rebuild de la page).
- Module : `server/modules/guide_dialogue.lua` (nœuds, pagination, GPS, Hall of Fame).
- Page : `ui/src/features/guide/TalkView.tsx`, `talk.ts`, `talk.css`.
- Tests : `tests/guide_dialogue_test.lua`, `ui/tests/guide-talk.test.ts`.

## Ce que voit le joueur

1. **E « Talk to Johnny »** (ou ALT + clic). Johnny salue, une salutation tirée au sort
   parmi trois. À droite, sept choix numérotés ; en dessous, son nom, la mention
   « ROCKERBOY · GHOST IN THE MACHINE » et sa réplique.
2. **↑ ↓** ou la souris choisissent, **Entrée**, **F** ou un clic valident, **1 à 9**
   choisissent directement. La ligne sélectionnée est jaune, avec la touche F.
3. Johnny répond en **trois lignes au plus à l'écran**. Si sa réponse est plus longue, le
   seul choix est « Go on. » (des repères en haut à droite montrent la page) ; **← →**
   tournent aussi les pages. Les choix suivants arrivent sur la dernière page.
4. Chaque nœud finit par **« Back. »** (sauf la salutation) et **« That's all. »**.
   **Retour arrière** ou **clic droit** reviennent en arrière, sur la page où étaient les
   choix, le curseur là où il était. Un choix déjà pris est grisé.
5. Un choix peut **agir** : il pose un itinéraire GPS (la confirmation s'affiche sous la
   réplique, Johnny reste ouvert), ouvre un panneau (activités, contrats, guide du job,
   Hall of Fame), ou ouvre la **FAQ écrite** à la bonne réponse. Depuis la FAQ, le bouton
   **« TALK TO JOHNNY »** ou **clic droit** depuis la réponse ouverte ramène au dialogue,
   à la réplique quittée.
6. **« That's all. »** : Johnny dit au revoir (une phrase au hasard parmi trois), le
   dialogue se ferme après 1,8 s ou à la première touche. **Échap** ferme tout de suite.

Les réponses tirées de la FAQ trop longues pour le dialogue (plus de quatre pages) sont
coupées après deux pages par « There's more. A lot more. Want it written down? » ; le
premier choix devient alors « Write it down for me. » (la FAQ à cette réponse).

## L'arbre

Notation : `→ nœud` mène à un autre nœud ; `FAQ x.y` fait répondre Johnny avec la
réponse x.y de la FAQ (sa réplique, puis la réponse paginée ; les actions et les questions
liées de cette réponse deviennent les choix suivants) ; `Sujet x` liste les questions du
sujet x ; `GPS x` pose un itinéraire ; `Ouvre x` ouvre un panneau. Les valeurs entre
accolades suivent la config (prix, touches, lieux).

### Salutation (`hello`)

Johnny se présente (rockerboy, légende, comité d'accueil malgré lui) et invite à
demander. Trois variantes.

- « What do I do first? » → `first`
- « How do I make money? » → `money`
- « Where's the action? » → `action`
- « I need wheels. » → `wheels`
- « Tell me about chrome. » → `chrome`
- « Crew stuff. » → `crew`
- « Something else… » → `other`

### Par où commencer (`first`)

Argent de départ en poche et en banque, studio gratuit (`{v:starterDoor}`), trouver un job
au Job Center, manger, revenir ici pour l'action.

- « Mark my studio. » — GPS studio
- « Mark the Job Center. » — GPS Job Center
- « Where am I, exactly? » → `where`
- « Show me my keys. » → `keys`
- « Any rules? » — FAQ start.rules

`where` : The Crossing, Westbrook ; les nouveaux arrivent ici après le premier jour ; le
terminal lance les activités ; Job Center, location et garage sont à City Center.

- « Show me the activities. » — Ouvre le panneau Activités
- « What was that first day guide? » — FAQ start.tutorial
- « Who are you, anyway? » — FAQ help.johnny

`keys` : les touches principales avec **les touches du joueur** (menu, Neural-Link,
interagir, sac, ALT + clic) et où les réassigner.

- « Write them all down for me. » — Ouvre la FAQ à controls.keys
- « What's in the menu? » — FAQ controls.f1
- « What does the Neural-Link do? » — FAQ controls.neuralink
- « How do I walk instead of run? » — FAQ controls.walk
- « Camera? » — FAQ controls.camera

### Gagner de l'argent (`money`)

Travail honnête ou sale. Le job paie toutes les N minutes (« quand tu fais vraiment
quelque chose » si la paie exige une activité), les missions paient le plus en crew ; si
les activités paient, les matchs de The Crossing paient à la minute.

- « Get me a job. » → `job`
- « Tell me about missions. » → `missions`
- « Cash or bank? » → `cash`
- « How do I pay someone? » — FAQ money.pay
- « What does stuff cost? » — FAQ money.spend

`job` : aller au Job Center, E au guichet, les jobs proposés ; tout le monde commence en
bas.

- « Mark the Job Center. » — GPS Job Center
- « What's each job like? » → `jobs` (Sanitation, Scrapper, Courier en deux lignes)
- « What's the pay? » — FAQ jobs.pay
- « Open my job guide. » — Ouvre le guide du job (caché sans job)
- « How do I quit? » — FAQ jobs.quit

`jobs` : « Tell me about Sanitation. » / « … Scrapper. » / « … Courier runs. » (FAQ
jobs.sanitation, jobs.scrapper, jobs.courier), « Mark the Job Center. ».

`cash` : liquide en poche (seul le liquide en poche paie), banque par personnage, pas
encore de distributeur.

- « How do I check my balance? » — FAQ money.check
- « How do I pay someone? » — FAQ money.pay
- « Every way to earn? » — FAQ money.earn

### L'action (`action`)

Le terminal de The Crossing (arène, courses, poursuites, guerres de territoire) ; « en ce
moment : … » si des activités tournent ; les missions dans toute la ville, et Dogtown
s'il est activé.

- « Show me the activities. » — Ouvre le panneau Activités
- « Do they pay? » — FAQ activities.pay_rebalance ou activities.rewards (celle qui est
  visible selon la config)
- « Tell me about missions. » → `missions`
- « Dogtown? » → `dogtown` (si Dogtown est activé)
- « Open the Hall of Fame. » — Ouvre le Hall of Fame (si le module est là)

`missions` : un tableau de missions, E, difficulté, on y va en crew dans une instance à
soi avec un kit fourni ; la réputation requise pour les difficultés hautes si elle est
exigée.

- « Show me the contracts. » — Ouvre le panneau Activités, onglet Contrats
- « What do they pay? » — FAQ missions.rewards
- « Street cred? » — FAQ missions.tiers_gate ou missions.reputation (selon la config)
- « Who are the fixers? » — FAQ missions.fixers
- « What if I die? » — FAQ missions.death
- « The Chimera Protocol? » — FAQ missions.chimera (si la ressource est là)

`dogtown` (si activé) : pas de loi derrière les murs ; mise minimale en liquide ; à la
mort, une part du liquide tombe dans un sac pour le tueur ; la banque est à l'abri.

- « Mark Dogtown. » — GPS Dogtown
- « What's in it for me? » — FAQ dogtown.bonus
- « Crews in there? » — FAQ dogtown.crews
- « Bounties? » — FAQ dogtown.bounty
- « Give me the fine print. » — FAQ dogtown.what

### Les véhicules (`wheels`)

Louer chez Rent-a-Ride (prix, durée) ou acheter chez Night City Motors (fourchette) ; pas
de voiture de départ gratuite.

- « Mark the rental desk. » — GPS location
- « Mark the dealership. » — GPS concession
- « What's for sale? » — FAQ vehicles.prices
- « Fuel? » → `fuel`
- « Where do I keep it? » → `garage`

`fuel` : prix au litre, la marche à suivre à la pompe ; en panne sèche le moteur s'arrête,
un jerrycan évite la marche.

- « Mark a fuel station. » — GPS station
- « Jerrycan? » — FAQ vehicles.jerrycan
- « Step by step. » — FAQ vehicles.fuel

`garage` : garer au garage public (E ou `/garage`), nombre de voitures par personnage ;
fourrière et prix de sortie.

- « Mark the garage. » — GPS garage
- « Impound prices? » — FAQ vehicles.impound
- « Keys and locks? » — FAQ vehicles.lock
- « Can I paint it? » — FAQ vehicles.paint

### Le chrome (`chrome`)

Mise en garde de Johnny ; trouver un fauteuil de ripperdoc, E pour s'allonger, la clinique
s'ouvre ; nombre d'implants, fourchette de prix, payé en banque. Tant qu'aucune clinique
n'est configurée : « les cliniques ne sont pas sur la carte, ouvre l'œil ».

- « Mark the nearest clinic. » — GPS clinique la plus proche (caché tant que `clinics`
  est vide)
- « What's on the menu? » — FAQ cyberware.price
- « Sandevistan or Berserk? » — FAQ cyberware.os
- « How do I use them? » — FAQ cyberware.use
- « Any limits? » → `limits`

`limits` : rang des implants et réputation, capacité du corps ; ou « aucune, si ta banque
paie, ça rentre » quand rien de cela n'est activé.

- « Which rank needs what? » — FAQ cyberware.tiers
- « How many points do I get? » — FAQ cyberware.capacity
- « Swapping and taking them out? » — FAQ cyberware.install
- « Iconic implants? » — FAQ cyberware.iconics

### Le crew (`crew`)

Personne ne s'en sort seul ; ALT + clic sur un joueur, « Invite to crew » ; taille max ;
le chef lance les missions et la file d'attente des activités.

- « How do I accept an invite? » — FAQ crews.accept
- « What can the leader do? » — FAQ crews.leader
- « Matchmaking? » — FAQ crews.matchmaking
- « What's that list at the bottom left? » — FAQ crews.frame
- « How do I leave? » — FAQ crews.leave

### Autre chose (`other`)

« Vas-y, ça ne peut pas être plus bizarre que la question du dernier. »

- « Got a place for me to crash? » — Sujet housing
- « Food, health, getting shot. » — Sujet health
- « Guns. » — Sujet weapons
- « Clothes. » — Sujet appearance
- « Controls, chat, my bag… » → `more`
- « Let me type it. » — Ouvre la FAQ, curseur dans la recherche

`more` : « Les petits trucs. Bon. Il faut bien que quelqu'un sache. »

- « Controls and menus. » — Sujet controls
- « Chat and voice. » — Sujet chat
- « My inventory. » — Sujet inventory
- « Animations. » — Sujet animations
- « I need the staff. » — Sujet help
- « Let me type it. » — Ouvre la FAQ, recherche

Un sujet affiche la réplique de Johnny pour ce sujet, puis ses questions comme choix
(chacune mène à la réponse en dialogue).

### Au revoir

Une phrase au hasard : « Don't die out there. Or do. Keeps things interesting. »,
« See you around, choom. I'll be here. Not like I've got a choice. », « Go on. The city's
not gonna burn itself down. ».

## Ce que font les actions

| Choix | Effet |
|---|---|
| GPS (studio, Job Center, location, concession, station, garage, Dogtown, clinique) | itinéraire vers le lieu le plus proche de ce type (`guide.gps`, comme la FAQ) ; confirmation sous la réplique, le dialogue reste ouvert |
| Activités / Contrats | ferme Johnny, ouvre le panneau Activités sur l'onglet voulu |
| Guide du job | ferme Johnny, ouvre le guide du job actuel (choix caché sans job) |
| Hall of Fame | nouvelle action serveur `guide.panel` : ouvre le Hall of Fame à 12 m de Johnny ou près du tableau ; sinon un message (« Walk up to the Hall of Fame board first. ») |
| Write it down / Write them all down | ouvre la FAQ à la réponse, Retour ramène au dialogue |
| Let me type it. | ouvre la FAQ, curseur dans la recherche |

Un choix dont la cible est cachée (question filtrée par la config, type de lieu sans lieu,
module absent) n'est pas proposé ; un nœud qui n'a plus rien à dire disparaît avec ses
choix.

## Transport

Le nœud d'ouverture arrive avec le dialogue `guide` ; ses enfants suivent aussitôt (avant
l'index de recherche). Ensuite la page demande chaque nœud par `guide.node` et reçoit le
nœud **et ses enfants** : le clic suivant est déjà en cache. Chaque message reste sous
800 valeurs et 32 Kio (le plus gros mesuré : 407 valeurs, 5,2 Kio). Une demande perdue
sous la limite de 250 ms par action est retentée (quatre essais, 700 ms d'écart). Une
révision du contenu (une fonction activée ou coupée) vide le cache de la page.

## Limites (natives existantes)

- **Cliniques** : aucune position de ripperdoc accessible n'existe côté Light RP (les
  fauteuils d'op77_scenes sont du mobilier scanné, sans savoir lesquels sont entrables).
  Le choix GPS est prêt mais caché tant que `clinics` est vide ; il faut relever des
  cliniques en jeu.
- **Menu F1** : la page ne peut pas ouvrir le menu F1 elle-même. « Show me my keys. » est
  donc une réplique avec les touches du joueur, et « Write them all down for me. » ouvre la
  FAQ à la liste complète.
- **Hall of Fame** : l'action de page existante exige d'être à 10 m du tableau ; Johnny en
  est à quelques mètres, d'où l'action serveur `guide.panel` (même ouverture, portée de
  12 m autour de Johnny).
- **Dogtown** : le GPS vise l'épingle de zone (`blip.position`), à vérifier en jeu.
- **Voix** : pas de doublage ; le texte seul.
- Trois réponses de la FAQ ne sont pas atteignables par le dialogue (activities.commands,
  cyberware.where, dogtown.logout) ; elles restent dans la FAQ et la recherche.
