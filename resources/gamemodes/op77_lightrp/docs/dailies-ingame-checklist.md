# Dailies : recette en jeu

Une fiche par contrat, pour vérifier en jeu ce que les tests automatiques prouvent avec des natifs
simulés (`tests/dailies_test.lua`, `tests/dailies_flow_*_test.lua`). Le contenu et les seuils sont
dans `dailies-titles.md` ; cette page ne dit que **quoi taper, quoi faire, quoi voir**.

## 0. Avant de commencer

- **Clients** : « 1 client » = un seul compte suffit. « 2 clients » = deux comptes distincts
  (`open77_client_launch` avec un autre `identity_profile`), sinon la règle du partenaire et
  l'anti-alt refusent tout. Un contrat **social** donné par `give` se teste à deux même si moins
  de 4 comptes sont en ligne : `give` passe outre la foule, les vérifications restent.
- **Mise en place**, depuis la console serveur (commande restreinte) :
  - `/lightrp.dailies give <joueur> <contrat>` met le contrat dans sa case, progression à zéro ;
  - `/lightrp.dailies status <joueur>` affiche chaque case : `<case>=<contrat> <valeur>/<cible>`,
    puis `done`, `claimed`, `(given)` ; c'est la preuve côté serveur ;
  - `/lightrp.dailies reset <joueur>` remet sa journée et sa semaine à zéro entre deux essais
    (la série et les titres restent).
- **Ce qui doit apparaître à chaque réussite** :
  1. la notice **DAILY COMPLETE** « *titre* · *fixer*. Claim €$ N in F1 > Dailies. » ;
  2. F1 → **Dailies** : la carte passe à **DONE**, bouton **CLAIM €$ N** ;
  3. le terminal de The Crossing → onglet **DAILIES** : la même carte, le même état ;
  4. après **CLAIM** dans l'un des deux, la carte est **PAID** dans l'autre, et `/bank` montre
     la ligne `contract` avec le titre du contrat.
- **Ce qui ne doit jamais arriver** : une réussite sans la condition ; une deuxième réussite avec
  le même partenaire dans la semaine (notice **DAILIES** « … It takes somebody new. ») ; un
  contrat social tiré tout seul sur un serveur à moins de 4 comptes.

## 1. Les règles générales (une fois)

| Vérification | Clients | Faire | Voir |
|---|---|---|---|
| Serveur calme | 1-2 | ne rien donner, ouvrir F1 → Dailies | aucune pastille **WITH OTHERS** en Street, Shift ni Weekly ; la carte Crew « Crew daily · Shows up when a crewmate is online » |
| Foule | 4 | quatre comptes en ligne, `status` | `(social on)` ; un contrat social de la ville peut apparaître pour ceux qui n'avaient encore rien reçu |
| Pas de va-et-vient | 4 → 2 → 4 | un joueur reçoit le contrat social, deux partent puis reviennent | non commencé : il passe au remplaçant solo et n'y revient pas le même jour ; commencé : il reste |
| Échange | 1 | **SWAP · FREE** deux fois sur la carte Street | « New daily: … », jamais un contrat social sur un serveur calme ; « SWAP » disparaît |
| Carte de crew | 2 | créer un crew (ALT + clic), puis le quitter | la carte de crew s'ouvre ; elle se referme si personne n'a commencé |

## 2. Street

### Ledger's Lucky Number — 1 client
- Mise en place : `give <id> lucky_number`.
- Faire : `/bank`, calculer l'écart à la prochaine fin en 777 ; l'atteindre par des achats ou
  ventes en boutique (bonbon 9 €$, revente 1 €$) ou un plein au litre près.
- Voir : DAILY COMPLETE au paiement qui fait tomber le solde sur …777.
- Échec attendu : un dépôt ou un retrait au guichet / distributeur qui tombe sur …777 ne valide
  rien ; un virement d'un autre joueur non plus.

### Running on Fumes — 1 client
- Mise en place : `give <id> running_on_fumes` ; louer une moto (30 L) ou prendre sa voiture.
- Faire : rouler jusqu'à la réserve (notice de réserve à 15 %), puis sous 10 % ; à la pompe,
  remplir jusqu'à au moins 50 %.
- Voir : DAILY COMPLETE en fin de plein.
- Échec attendu : plein commencé au-dessus de 10 %, ou arrêté sous 50 % ; jerrycan.

### Nightcap — 1 client
- Mise en place : `give <id> nightcap`.
- Faire : gagner une activité payée (arène PvE, par exemple), sortir, rejoindre un bar (Ho-Oh à
  636 m de The Crossing) et boire une boisson de l'inventaire dans les 10 minutes.
- Voir : DAILY COMPLETE à la gorgée.
- Échec attendu : boire hors d'un bar, ou après 10 minutes ; boire après un contre-la-montre
  fini seul (Time Trial).

### Nobody Eats Alone — 2 clients
- Mise en place : `give` aux deux joueurs, `eat_together`.
- Faire : à moins de 15 m, manger chacun un plat à moins de 8 s d'écart.
- Voir : DAILY COMPLETE pour les deux.
- Échec attendu : 20 m d'écart ; 10 s d'écart ; deux sodas (boire n'est pas manger) ; le
  lendemain dans la même semaine avec le même partenaire (notice DAILIES).

### Housewarming — 2 clients
- Mise en place : `give <hôte> housewarming` ; l'hôte a la clé d'un logement, l'invité y entre.
- Faire : l'hôte donne une boisson à l'invité (inventaire → Give) dans le logement ; l'invité la
  boit sur place.
- Voir : DAILY COMPLETE chez l'hôte.
- Échec attendu : l'invité sort avant de boire, même s'il rentre aussitôt ; un hôte sans clé ;
  le don fait dehors ; une pomme à la place d'une boisson.

### Ride Along — 2 clients
- Mise en place : `give` aux deux, `ride_along`.
- Faire : conducteur et passager dans le même véhicule, rouler 1,2 km (Job Center → The Crossing).
- Voir : la barre monte en mètres pendant le trajet, DAILY COMPLETE pour les deux.
- Échec attendu : seul dans la voiture ; son propre second personnage comme passager.

### Street Performer — 2 clients
- Mise en place : `give <artiste> street_performer`.
- Faire : à The Crossing, jouer une animation 60 s, le second joueur à moins de 15 m.
- Voir : la barre en secondes, DAILY COMPLETE à 1:00.
- Échec attendu : le public s'éloigne à plus de 15 m (retour à 0:00) ; changer d'animation.

### The Tour — 2 clients
- Mise en place : `give <guide> the_tour` ; le second compte est un **nouveau personnage** (moins
  de 2 h de jeu).
- Faire : marcher ou rouler 750 m ensemble à moins de 15 m (The Crossing → Afterlife).
- Voir : DAILY COMPLETE chez le guide, notice d'Okoro chez le nouveau (« showed you around »).
- Échec attendu : un personnage de plus de 2 h ; s'écarter à plus de 15 m.

## 3. Action

### Clean Invoice — 1 client
- Mise en place : `give <id> clean_invoice`.
- Faire : Chimera en Standard, seul, sans tomber à terre pendant le combat.
- Voir : DAILY COMPLETE à la victoire.
- Échec attendu : une mise à terre ; un raid de test du staff.

### Lose Them, Don't Wait — 1 client
- Mise en place : `give <id> lose_them`.
- Faire : NCPD Escape, tenir jusqu'à 3 étoiles puis rejoindre l'extraction.
- Voir : DAILY COMPLETE au résultat.
- Échec attendu : s'en sortir à l'horloge ; extraction à 2 étoiles.
- À noter : une extraction rapide (avant 60 s de partie) n'est pas payée par l'activité
  (ACTIVITY PAY muet, récap `too_short`) mais **valide** le contrat.

### Leg Day — 1 client
- Mise en place : `give <id> leg_day`.
- Faire : NCPD Escape, choisir **On foot**, s'en sortir.
- Voir : DAILY COMPLETE au résultat.
- Échec attendu : le mode voiture ; une arrestation ; quitter la partie.

### Five Without a Dirt Nap — 1 client
- Mise en place : `give <id> five_streak`.
- Faire : arène PvE payée, enchaîner 5 kills sans mourir.
- Voir : DAILY COMPLETE au résultat du match.
- Échec attendu : mourir à 4.

### Support Act — 1 client
- Mise en place : `give <id> support_act` ; au terminal, cocher les alliés bots.
- Faire : gagner l'arène PvE en blessant (30 % de la vie d'un bot) des ennemis que les alliés
  achèvent, avec plus d'assistances que de kills.
- Voir : DAILY COMPLETE au résultat.
- Échec attendu : autant de kills que d'assistances ; une défaite.

## 4. Shift

### Full Truck — 1 client (Sanitation ou Scrapper)
- Mise en place : embauche au Job Center, `give <id> full_truck`.
- Faire : ramasser, transformer, repartir pour un second ramassage (le sac a la place ; le
  coffre aussi), transformer, puis vendre au moins 11 marchandises d'un coup.
- Voir : DAILY COMPLETE à la vente.
- Échec attendu : une vente de 10 (un seul chargement).

### The Full Round — 1 client (Sanitation ou Scrapper)
- Mise en place : `give <id> full_round`.
- Faire : collecter au site A, puis au site B, puis vendre.
- Voir : la barre 1/3, 2/3, puis DAILY COMPLETE à la vente.
- Échec attendu : vendre après un seul site (retour à 0).

### Two Wheels — 1 client (Courier)
- Mise en place : `give <id> two_wheels` ; une moto (catégorie Bikes).
- Faire : une course Courier entière à moto.
- Voir : DAILY COMPLETE à la dernière livraison.
- Échec attendu : une partie de la course en voiture.

### Fragile — 1 client (Courier)
- Mise en place : `give <id> fragile`.
- Faire : une course entière dans la même voiture sans la cogner.
- Voir : DAILY COMPLETE à la dernière livraison.
- Échec attendu : un choc franc (plus de 5 % de santé) ; changer de voiture en cours.
- **À relever** : la perte de santé d'une course propre et d'un petit accrochage (seuil de 5 %
  hérité, à confirmer).

### Water Break — 1 client (AC Cleaner)
- Mise en place : `give <id> water_break` ; une boisson dans le sac.
- Faire : sur la tournée des toits, boire entre la première et la dernière unité, puis finir.
- Voir : DAILY COMPLETE au rapport de fin.
- Échec attendu : boire avant la première unité ou après la dernière.

### On Call — 2 clients (Trauma Team)
- Mise en place : `give <médic> on_call` ; le second joueur à terre.
- Faire : le stabiliser avec un kit.
- Voir : DAILY COMPLETE chez le médic.
- Échec attendu : le même patient une seconde fois dans la semaine.

### Fare Paid — 2 clients (Taxi)
- Mise en place : `give <chauffeur> fare_paid`.
- Faire : passager à l'arrière, 1,2 km, descente, puis paiement d'au moins 6 €$ (liquide ou
  virement) du passager au chauffeur dans les 3 minutes.
- Voir : DAILY COMPLETE au paiement.
- Échec attendu : 5 €$ ; un paiement d'un tiers ; après 3 minutes ; une course de 1,1 km.

### Roadside Assistance — 2 clients (mécano)
- Mise en place : embaucher le mécano **sans** `give` (le contrat doit venir de l'appel) ; le
  second joueur roule jusqu'à la réserve ou la panne sèche.
- Faire : le mécano lit l'appel « Roadside call: … km from you. », remplit un jerrycan à la pompe
  et le verse dans la voiture du second.
- Voir : la case Shift du mécano devient *Roadside Assistance* à l'appel ; DAILY COMPLETE au
  versement.
- Échec attendu : sa propre voiture n'ouvre pas d'appel ; si la voiture est remplie à la pompe
  par son conducteur, la case revient au contrat du métier.

### Pit Crew — 2 clients (mécano)
- Mise en place : `give <mécano> pit_crew` ; le second joueur conduit sa voiture à la pompe et
  en descend.
- Faire : le mécano remplit cette voiture pendant que le client reste à moins de 15 m, puis le
  client le paie au moins ⌈litres × 4 €$⌉.
- Voir : DAILY COMPLETE au paiement.
- Échec attendu : payé moins que le carburant ; la voiture du mécano lui-même ; le client
  s'éloigne à plus de 15 m pendant le plein puis revient pour la fin.

## 5. Crew (tous à 2 clients, en crew)

### Convoy
- Mise en place : crew de deux, `give` aux deux, `convoy`.
- Faire : chacun sa voiture, 2,4 km à moins de 40 m.
- Voir : la barre en mètres pour les deux ; DAILY COMPLETE ensemble.
- Échec attendu : passager dans la voiture de l'autre ; décrocher deux échantillons de suite
  (retour à 0).

### Back to Back
- Mise en place : `give` aux deux, `back_to_back`.
- Faire : entrer ensemble dans l'arène PvE, gagner, au moins un kill chacun.
- Voir : DAILY COMPLETE pour les deux.
- Échec attendu : deux matchs séparés, même lancés dans la même seconde par chacun de son
  côté (deux instances).

### Bar Crawl
- Mise en place : `give` aux deux, `bar_crawl`.
- Faire : boire ensemble dans 3 bars de 3 quartiers en moins d'une heure.
- Voir : la barre 1/3, 2/3, 3/3, DAILY COMPLETE.
- Échec attendu : deux bars du même quartier ; boire hors d'un bar.

### Album Cover
- Mise en place : `give` à tout le crew présent, `album_cover`.
- Faire : à The Crossing, tout le monde à moins de 6 m joue une animation pendant 10 s.
- Voir : DAILY COMPLETE pour tous.
- Échec attendu : un membre présent sans animation.

### Nobody Left Behind
- Mise en place : `give` aux deux, `nobody_left_behind`.
- Faire : NCPD Escape en crew, chacun s'en sort.
- Voir : DAILY COMPLETE pour les deux au dernier résultat.
- Échec attendu : un seul s'en sort ; un coéquipier qui se déconnecte.
- À noter : un coéquipier qui rejoint l'extraction avant 60 s ne fait pas rater le crew.

## 6. Weekly

### Two Against the Machine — 2 clients
- Mise en place : `give` aux deux, `two_vs_machine`.
- Faire : Chimera en **Hard** à deux exactement.
- Voir : DAILY COMPLETE pour les deux, titre **Two-Man Army**.
- Échec attendu : un raid commencé à trois dont un part avant la fin ; Critical ou Standard.

### All the Way — 2 clients
- Mise en place : `give <id> all_the_way`.
- Faire : duel classé, gagner la manche décisive (1-1 puis la troisième).
- Échec attendu : une victoire 2-0.

### Lion's Share — 1 à 2 clients
- Mise en place : `give <id> lions_share` ; lancer un world boss.
- Faire : en être le premier contributeur, le boss tombe.
- Échec attendu : le boss survit ; un autre fait plus de dégâts.

### Both Sides of the Law — 2 clients
- Mise en place : `give <id> both_sides`.
- Faire : dans un même match Most Wanted, une arrestation puis une extraction ou la survie.
- Échec attendu : l'arrestation seule.

### Good Samaritan — 2 clients (au moins)
- Mise en place : `give <id> good_samaritan`.
- Faire : stabiliser 3 citoyens différents hors de son crew dans la semaine.
- Voir : 1/3, 2/3, DAILY COMPLETE.
- Échec attendu : un coéquipier ; le même citoyen deux fois.

### One-Man Army — 1 client
- Mise en place : `give <id> one_man_army`.
- Faire : Chimera en Standard, seul du début à la fin.
- Échec attendu : un second opérateur au début du combat.

### Walk of Shame — 1 client
- Mise en place : `give <id> walk_of_shame` ; sa propre voiture presque vide.
- Faire : la laisser tomber à sec à plus de 1 km de la station, revenir à pied, remplir un
  jerrycan, retourner la remettre en route.
- Voir : 1/2 à la panne, DAILY COMPLETE au versement.
- Échec attendu : panne à moins de 1 km ; verser dans une autre voiture.
