# Housing : appartements, maisons et instances

Le housing utilise MySQL et le menu compact de LightRP. Les logements et modèles
d'intérieur se créent en jeu et persistent sans modification des fichiers Lua.

## Accès joueur

- **F1 → My homes** ou **E** devant une entrée. Chaque logement du joueur (ou dont il a une clé)
  a son point **My home** sur la carte, et la fiche d'un logement propose **Set GPS to the entrance**.
- **At this entrance** liste tous les appartements de l'immeuble : plusieurs
  logements peuvent partager le même point extérieur.
- Les listes proposent une recherche et des pages de dix logements. La carte
  montre les 32 entrées les plus proches, actualisées lors des déplacements.
  Les appartements d'une même porte partagent un repère.
- Acheter ou louer demande d'être devant l'entrée. Le prix affiché doit être
  confirmé et le paiement est débité du **compte bancaire**.
- Une location se paie d'avance en **jours réels**. Le renouvellement est manuel,
  ajoute une période à la date d'expiration et utilise le tarif actuel du logement.
  Aucun prélèvement automatique n'est effectué.
- Le résident peut verrouiller/déverrouiller l'entrée et donner ou révoquer des
  clés à d'autres personnages connectés. Les clés persistent après déconnexion.
- Une porte déverrouillée autorise les visiteurs. Le coffre et le vestiaire sont
  réservés au résident et aux détenteurs d'une clé.
- **E** à la sortie ramène au point extérieur. **Leave** (racine de F1 → My homes) permet également
  de sortir, notamment après un échec de chargement.
- Un logement acheté peut être revendu au serveur, par défaut à **50 % du prix
  réellement payé**. Abandonner une location ou une attribution ne rembourse rien.

À la fin d'une location, lors d'une revente ou d'une révocation administrative,
les occupants sont renvoyés dehors et les clés cessent de fonctionner. Les objets
restants sont conservés dans le coffre de l'ancien contrat : **My homes → Recover
stored belongings**, depuis l'ancienne entrée, permet de les récupérer en retrait
seul. Un nouveau résident reçoit un autre coffre. Supprimer le logement ne supprime
pas ces affaires.

## Création d'un intérieur

Permission : **`command.lightrp.housing`**. Les rôles disposant de
`command.lightrp.*` ou `*` la possèdent déjà. Ouvrir **/admin → Housing** ou
`/housingadmin` avec un personnage actif.

1. Aller dans un intérieur existant et praticable. Le housing instancie les joueurs
   et objets réseau ; il ne fabrique pas la géométrie. Un intérieur provenant d'un
   mod doit être déclaré comme mod requis du serveur.
2. **Interior templates → Create interior template** : saisir le nom et la
   capacité du coffre en cases et kilogrammes.
3. Se placer à l'emplacement d'arrivée, orienté comme souhaité, puis choisir
   **Capture spawn here**. Le serveur relève la position et l'orientation réelles.
4. Capturer séparément **exit** et **storage**, en laissant de l'espace pour que
   leurs interactions ne se superposent pas.
5. Capturer éventuellement **wardrobe**. Ce point utilise le vestiaire LightRP
   existant ; il peut être supprimé sans supprimer l'intérieur.
6. **Preview private instance** permet de visiter le modèle dans une instance de
   test. **Leave** (F1 → My homes) revient exactement au point de départ.

Le menu conserve les contrôles de déplacement et de caméra. Seuls les formulaires
prennent la souris et le clavier. Un modèle est utilisable après capture des trois
points obligatoires. Les points doivent rester dans le rayon configuré autour de
l'arrivée (200 m par défaut).

Les résidents doivent sortir avant de déplacer les points d'un modèle ou d'éditer
sa capacité. Une nouvelle capacité s'applique aux **futurs contrats** : elle ne
réduit jamais le coffre d'un résident existant. Un modèle utilisé par un logement
ne peut pas être supprimé.

## Création et attribution d'un logement

1. Se placer devant la porte extérieure, dans l'instance publique.
2. **Dwellings → Create dwelling here** : choisir un modèle d'intérieur terminé
   (recherche et pagination disponibles), puis nommer le logement et choisir
   **Apartment** ou **House**.
3. Définir le prix d'achat, le loyer et la durée d'une période (1 à 90 jours).
   **0** désactive respectivement l'achat ou la location. Les deux à 0 réservent
   l'attribution à l'administration.
4. Laisser le logement activé pour afficher son entrée. Chaque logement créé
   obtient une instance distincte, même si son modèle et sa porte sont communs.
5. **Assign a resident** attribue gratuitement le logement sans échéance à un
   personnage connecté. **Assign an offline character** accepte l'identifiant
   joueur Open77 et la clé du personnage sauvegardé ; leur existence est vérifiée.

Un logement déjà occupé doit d'abord être libéré. **Revoke current tenancy** exige
un motif, conserve les affaires et n'émet aucun remboursement. Attendre que les
occupants aient quitté l'instance avant **Delete dwelling**. Il est également
possible de déplacer l'entrée d'un logement vacant, de modifier ses tarifs, son
nom ou son modèle. Changer le modèle ou désactiver un logement exige la fin du
contrat en cours.

## Persistance et configuration

Le fichier [`server/config/housing.lua`](../server/config/housing.lua) définit :

| Réglage | Défaut |
|---|---:|
| Logements actifs maximum | 1 000 |
| Logements par personnage | 5 |
| Occupants simultanés par logement | 16 |
| Clés supplémentaires par logement | 12 |
| Capacité d'un nouveau modèle | 40 cases / 150 kg |
| Période de location proposée | 7 jours |
| Location payable à l'avance | 365 jours maximum |
| Revente | 50 % du prix payé |
| Temps maximal de chargement natif | 30 secondes |

Réserver les buckets `bucketBase + idDuLogement` au housing. Les prévisualisations
utilisent `bucketBase + 50000000 + playerId`. Ne pas réutiliser ces plages dans
une autre ressource.

Tables créées automatiquement : `lightrp_housing_templates`,
`lightrp_housing_properties`, `lightrp_housing_contracts`, `lightrp_housing_audit`.
Les coffres utilisent `lightrp_inventories`, sous `housing:<id-du-contrat>`.
Sauvegarder ces tables avec les personnages, comptes et transactions bancaires.

Le serveur contrôle permissions, personnage actif, distance, instance, révision
du logement et droits de coffre. Paiement, contrat, logement et reçu bancaire sont
enregistrés dans la même transaction. Une erreur ne crée pas de logement gratuit
et ne débite pas un achat non enregistré. Une base illisible bloque le housing
sans remplacer les logements existants par des logements vacants.

La déconnexion dans un logement sauvegarde l'entrée extérieure comme prochain
point de connexion. Un personnage doit quitter son instance avant de changer de
slot. Un décès libère son instance et remet le joueur dans le monde public pour
le traitement habituel de l'hôpital.

## Vérification développeur

Depuis la racine LightRP :

```powershell
python tools/test-housing.py
cd ui
npm run build
```

Le premier test utilise les vrais modules housing, inventaire et économie avec
une base MySQL temporaire isolée, créée puis supprimée. Il vérifie notamment les
transactions interrompues, les deux instances, la révocation de clés, l'expiration,
le changement de résident et la récupération après suppression du logement.
Il vérifie aussi un catalogue de 1 000 logements et modèles, la recherche et les
pages extrêmes, ainsi que la taille des messages avec des noms Unicode.

Pour les menus, lancer Vite sur `127.0.0.1:5196`, puis
`python tools/test-housing-ui.py`. Ce test utilise Chromium et des réponses serveur
simulées ; il complète le test SQL et ne remplace pas les essais en jeu.
Il couvre la navigation au clavier, les formulaires, la confirmation des achats,
la recherche, les pages suivantes et le passage du menu au coffre sans fermer
l'inventaire lors de l'arrivée tardive de la réponse serveur.

Validation locale du 6 octobre 2026, sur une base et des ports de test séparés :

- Deux clients réellement incarnés dans le même intérieur, aux mêmes coordonnées,
  dans les instances `1000001` et `1000002`.
- Achat du premier logement et location du second avec débit bancaire.
- Coffres accessibles par leurs résidents ; tentative d'ouverture du coffre du
  premier logement refusée au résident du second, y compris depuis son intérieur.
- Retour à l'extérieur et ouverture du menu d'administration et du coffre en jeu.
- Après déconnexion : position extérieure sauvegardée pour les deux personnages,
  contrats relus par le module de persistance et trois bouteilles d'eau conservées.

Les logements de ces essais n'ont pas été ajoutés à la base du serveur habituel.
La pagination et la recherche ont été validées dans Chromium et par les tests SQL.

Après installation ou modification des fichiers client/WebUI, reconnecter les
joueurs (`reload_policy "reconnect"`). La création et l'édition des logements en
jeu n'exigent aucun redémarrage.

## Studio de départ (fin du premier jour)

En parlant à Mara à la fin du guide (« Take me home »), le personnage reçoit
un **Kabuki Studio** (attribution gratuite, contrat `assigned`) et il est
téléporté directement à l'intérieur. Configuration :
`server/config/housing.lua` → `LightRpHousing.starter`, module
`server/modules/housing_starter.lua`.

- Un studio par personnage, chacun dans sa propre instance (bucket), tous
  derrière la même porte de rue (`entrance`, libellé `building`). Les joueurs ne
  voient que le leur ; l'administration les voit tous.
- L'intérieur est la carte `kabuki_appart1`, que le serveur doit charger
  (`server.local.jsonc` la charge, pas encore `server.jsonc`).
- Le modèle d'intérieur est écrit **une seule fois** depuis la config ; ensuite
  `/housingadmin → Interior templates → Kabuki Studio` permet de recapturer le
  coffre, le vestiaire, l'arrivée ou la sortie, et ces captures font foi.
- Un studio libéré (My homes → Release) est réattribué au prochain arrivant.
- Ne compte pas dans `maxProperties` ; plafond `starter.maxUnits`.
- Sans studio possible (stockage indisponible…), le guide retombe sur l'arrivée
  en ville comme avant.

## Se réveiller chez soi

`wakeUpAtHome = true` : un résident (propriétaire ou locataire) qui se déconnecte
à l'intérieur de son logement s'y réveille à la connexion suivante. Le drapeau
est stocké dans le contrat (`asleep`) et consommé à l'arrivée ; la position
sauvegardée reste la porte de rue, donc un échec ramène devant l'immeuble.
Test : `tests/run-lua.ps1 -Test housing_starter_test.lua` (pwsh 7).
