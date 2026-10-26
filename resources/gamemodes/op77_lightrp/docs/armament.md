# Armes d'inventaire et munitions — prototype RP

Cette version ajoute deux objets sérialisés, `weapon_lexington` et `weapon_nue`,
et une boîte `ammo_pistol_box` de **30 balles**. Aucune arme ni munition n'est
donnée automatiquement à la connexion. Le staff peut les accorder avec le
mécanisme de grant d'inventaire existant ; un grant natif `/weapon.give` ne
crée pas une arme possédée dans l'inventaire RP.

## Utilisation

La sélection native (`WeaponWheel`, `NextWeapon`) est bloquée par le module
inventaire pour toute la session, indépendamment des safezones. Les tirs et la
recharge restent disponibles selon leurs règles habituelles. Les appels serveur
`assign`/`setActive` restent autorisés. Sélectionner un objet pour l'équiper,
puis **Use weapon** pour le ressortir après **Holster weapons** ; retirer la
référence avec **Unequip this hand**. Les libellés joueurs sont en anglais.

Depuis l'inventaire, équiper le Lexington ou le Nue à droite, puis éventuellement
l'autre modèle à gauche. Les emplacements natifs utilisés sont **1 et 4**.
Une arme ne peut pas occuper les deux mains ; deux instances du même modèle
ne sont pas prises en charge par ce prototype. Ranger visuellement conserve
l'équipement ; déséquiper retire sa référence et permet de transférer l'objet.
Déséquiper la main droite retire aussi la référence gauche.

Ouvrir une boîte consomme un objet et crédite 30 balles dans une même transaction.
Le stock affiché est le **total du personnage**, chargeurs et réserve compris,
avec un plafond de 600 balles. Il n'est pas multiplié par le nombre d'armes.
Le personnage conserve ce stock lorsqu'une arme est déséquipée ou transférée ;
le transfert du pistolet ne donne pas un deuxième stock au destinataire.

Les armes équipées ou en cours de synchronisation ne peuvent pas être vendues,
données, supprimées ou transférées. Les piles au sol et coffres temporaires
ne sont pas des destinations autorisées pour les armes : utiliser un autre
inventaire persistant après déséquipement. Les mouvements dans la même grille
conservent l'identité par UUID, indépendamment du numéro du slot.

## Dual wield : restriction du prototype

La paire Lexington/Nue est proposée pour essais, pas certifiée par un test
complet en jeu dans cette livraison. Les deux mains ont leurs chargeurs et
partagent une réserve. Le moteur `.156` documente encore une répartition
incohérente lors de recharges dual avec une faible réserve.

Le module exige donc, avant activation dual, au moins deux fois la somme des
capacités natives des deux pistolets en stock total. En observation, si la réserve
devient inférieure à la somme des capacités, la projection passe en erreur et
le tir est suspendu : ajouter des boîtes ou déséquiper la main gauche puis
synchroniser. Le module ne rajoute jamais des balles pour contourner ce bug.
Cette garde réduit l'exposition mais ne répare pas le moteur entre deux lectures.

## Autorité et limites

L'inventaire RP et son registre SQL décident de la propriété. Les templates et
records natifs viennent d'une allowlist serveur. Les requêtes de la page
désignent un slot, un UUID et une révision, jamais un record `Items.*` arbitraire,
une capacité choisie ou un nombre de balles à accorder.

Les tableaux `lightrp_weapon_instances` et leurs audits participent à la même
transaction que les JSON d'inventaire. Un UUID ne peut pas être recréé chez un
autre propriétaire. Les changements d'équipement et crédits de boîtes sont dans
`lightrp_armament`, avec reçus idempotents `lightrp_armament_operations`.
Une même clé de requête ne consomme pas une deuxième boîte.

Le moteur natif reste projeté chez le propriétaire du client : les snapshots,
completions et nombres de balles sont ses observations. Le module peut seulement
**réduire** son budget sur un total natif observé ; il n'en crée jamais depuis
un rapport client. Le stock accordé par les boîtes est contrôlé par SQL, mais
la consommation de chaque balle n'est pas une preuve indépendante du client.
Les tirs ratés et gratuits empêchent de remplacer cela par un décompte des dégâts.

Avant une mutation ou une resynchronisation, le dernier pool natif connu est
relu et rapproché pour éviter qu'un clic entre un tir et le poll rembourse les
balles déjà observables. Les lectures de routine se font toutes les deux secondes,
sans bloquer le tir pendant une lecture seule. Leurs résultats ne peuvent pas
augmenter le stock. Des tirs non rapportés avant un crash/départ restent une
limite d'autorité du moteur ; cette version ne promet pas une économie par balle
inviolable face à un client falsifié.

L'arbitre serveur refuse les dégâts à distance sans arme RP équipée, les hashes
qui ne correspondent pas aux mains projetées, le tir pendant une mutation native,
une projection non prête ou un stock nul. Il s'ajoute à l'arbitre des safezones :
il ne remplace pas leur protection. Les coups de véhicules et attaques sans
rapport avec les armes gérées gardent leurs politiques distinctes.

## Synchronisation et reprise

Les opérations natives sont ordonnées : politique dual, réutilisation/assignation,
normalisation des deux chargeurs, activation, puis snapshot de vérification.
Un ID de queue n'est pas un succès d'équipement. Les réponses sont corrélées
par joueur, request ID, opération et incarnation. Un échec de transaction est
retourné comme échec ; le succès de crédit précède ensuite la projection native.

Un timeout peut laisser une opération native en vol. Le module met cette
incarnation en quarantaine et refuse de superposer une nouvelle projection.
Une completion tardive authentifiée libère la quarantaine mais exige une
resynchronisation explicite ; sans réponse, reconnecter/remplacer le personnage.
La mort et le changement de personnage retirent les jobs de l'ancienne génération.
Les confirmations anciennes ne s'appliquent pas au nouveau corps.

Le démarrage réutilise les items natifs déjà possédés lorsque possible ; il ne
crée une présentation qu'après un refus définitif `weapon_not_owned`. Retirer
un slot natif ne supprime pas son item natif local. Le registre RP ne doit
jamais reconstruire une propriété depuis ces objets locaux.

## HUD d’armes

Le composant natif `weapon` est masqué ; le HUD RP en bas à droite affiche
les armes réellement sorties, le chargeur/capacité de chaque main et une seule
réserve partagée. Les états **RELOADING** et **EMPTY** sont en anglais. Une arme
rangée, un personnage mort, un changement d’inventaire ou une lecture périmée
retirent le panneau. Le réticule reste géré par le jeu.

Les compteurs sont des snapshots natifs locaux en lecture seule, demandés au
plus toutes les 200 ms avec une seule lecture en vol. Seule une completion
réussie publie un panneau complet ; les valeurs inconnues restent `—` et ne
sont jamais affichées comme zéro. Ces lectures ne modifient pas le stock SQL.

## Code et vérification

- `shared/armament.lua` : catalogue public et templates d'objets.
- `server/modules/armament_store.lua` : registre des UUID et préparation des
  mutations d'inventaire ; aucun cache propriétaire modifié avant le commit.
- `server/modules/armament.lua` : état, stock, requêtes, queue native et arbitre.
- `inventory.lua` : deep clone des métadonnées, hook `prepare`, transaction commune.
- `client/core/armament.lua` et feature UI d'inventaire : affichage et demandes.

`python3 tools/test-armament.py` charge les vrais modules inventaire/armement
avec SQL en mémoire et completions natives simulées. Les contrôles couvrent les
UUID, drafts, rollback, boîtes/replay, équipements asynchrones, interdictions de
transfert, stock partagé dual, tirs avant Sync, crédits pendant équipement,
timeout, faux répondant et changement d'incarnation. Ils ne simulent pas
REDengine : confirmer en jeu le rendu, les capacités, les animations, la recharge
et les refus natifs sur la build `.156` avec sa ressource officielle actualisée.

Contrat réseau : `op77_lightrp:armament`, opérations `state`, `equip`, `unequip`,
`holster`, `ammo`, `sync`. Les réponses portent `{kind:'response',request,ok,data:{state},error}`
et les états sont poussés via `{kind:'state',state}`. Le bridge de page est
`lightrp:ui:armament`. Les mutations demandent révision et clé idempotente.
