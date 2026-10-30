# op77_ripperdoc — interface de clinique ripperdoc

Interface plein écran du ripperdoc, dans la DA LightRP (jaune et noir). Elle est construite à partir
des propres assets du jeu, retravaillés (étalonnage ambre et graphite) :

- les vidéos « paperdoll » : le corps entier qui boucle et un gros plan par système ;
- les calques plein corps de chaque système (circulatoire, immunitaire, nerveux, peau, squelette) ;
- les icônes de cyberware de l'inventaire ;
- les sons de l'onglet cyberware, du zoom du paperdoll, de la pose d'implant et du menu.

**Sur LightRP, la clinique est réelle** (`op77_lightrp/server/modules/cyberware.lua`) :
- le catalogue, les prix, les pièces et les effets viennent du serveur (`server/config/cyberware.lua`) ;
- chaque opération est payée en eurodollars (banque), puis persistée par personnage ;
- les implants sont réappliqués à chaque connexion, changement de personnage et réapparition.

Sans serveur (aperçu navigateur, console `ripperdoc.open`), la page reprend son catalogue de démo et
simule les opérations. Voir PROTOCOL.md.

## Cyberware LightRP (ce que la clinique pose vraiment)

| Système | Implants | Effet réel (plateforme) |
|---|---|---|
| Jambes | Reinforced Tendons, Mk.2 / Fortified Ankles | Double saut durable (`Open77.cyberware`, legs) / plus de dégâts de chute |
| Bras | Gorilla Arms, Mk.2 / Mantis Blades, Electric | Poings durables (`gorilla_arms`) / lames sur l'emplacement de bras, touche **B** |
| Nerveux | Neofiber, Mk.2 | Dash et Air Dash (`Open77.dash`), **Ctrl** + direction |
| Système d'exploitation | Sandevistan Mk.1, Mk.3 | Overdrive réflexe (`Open77.reflex`), touche **X** |
| Squelette | Kinetic Impact Frame / Titanium Bones, Epimorphic Skeleton | Ground Slam (`Open77.abilities`), **G** en l'air / santé max |
| Peau | Subdermal Armor, Mk.2 | Armure |
| Circulatoire | Biomonitor, Iron Lungs, Adrenaline Booster | Régénération de la santé, endurance max, régénération de l'endurance |

Les autres systèmes (cortex, yeux, visage, mains, immunitaire) restent vides : aucun implant que la
plateforme sait appliquer pour l'instant.

**Économie.** Tout s'achète en eurodollars (banque), sans autre ressource. Les prix sont calés sur
le travail : environ 2 000 à 3 000 €$/h, en ignorant les récompenses de missions et de raids, qui
ne sont pas encore équilibrées.
- **Aucune limite** : pas de capacité, pas de prérequis, on équipe ce qu'on veut.
- Une famille correspond à un seul emplacement natif (bras, jambes, Dash, Overdrive…) : un autre
  modèle de la même famille remplace celui qui est installé.
- Un retrait coûte 250 €$.

Staff (console) : `lightrp.cyberware <id> list|status|blades|give <item>|take <item>`,
`ripperdoc.action <id> install|remove <item>`.

## Parcours

1. **Ouverture** : handshake neural, puis balayage biométrique du corps. Les 12 systèmes se placent
   de part et d'autre du corps, comme dans le jeu.
2. **Vue d'ensemble** : la souris incline la pièce (parallaxe 3D). Au survol d'un système :
   - le calque du jeu ou un halo s'allume sur la zone ;
   - un tracé relie le groupe au point du corps ;
   - une carte holographique flotte devant le corps.
3. **Plongée** : un clic fait foncer la caméra dans la zone (zoom, flou, flash) jusqu'au gros plan
   du système (la vidéo du jeu), incliné en profondeur.
   - À gauche : les slots installés et le stock de la clinique (filtres, rareté, prix, REQ).
   - À droite : la carte de l'implant.
   - A/D : système précédent ou suivant.
4. **Opération** : on maintient E ou le bouton, puis une procédure chirurgicale se déroule (étapes,
   barre). La dernière étape attend la réponse du serveur. En cas d'échec, la procédure s'interrompt
   et le paiement est remboursé.
5. **Échap** remonte au corps entier, puis quitte. Sur LightRP, quitter fait se lever du fauteuil.

## Déclenchement sur LightRP

`op77_lightrp/server/modules/ripperdoc.lua` :
- quand `op77_scenes` démarre la scène « ripperdoc » sur un fauteuil chirurgical, il ouvre
  l'interface après l'animation d'assise (6,6 s) ;
- il la ferme si la scène se termine autrement ;
- il fait se lever le joueur quand celui-ci ferme l'interface.

## Construire

```powershell
cd ripperdoc-ui
npm install
python scripts/build-assets.py --probe <NCWE.Probe.exe>   # médias depuis le jeu local (public/media)
npm run dev                                              # aperçu : http://localhost:5179/?body=female&section=circulatory
npm run build                                            # écrit resources/standalone/op77_ripperdoc/web
```

Le script de build des assets :
- décode les vidéos Bink 2 avec le `bin/x64/bink2w64.dll` du jeu (ffmpeg ne les lit pas) ;
- les étalonne, puis les encode en VP9 avec alpha ;
- exporte les icônes et les calques via WolvenKit ;
- exporte les sons via la sonde NCWE (`--sound-export`).

Il ne lit que l'installation locale. Les droits sur l'art et les sons restent à CD PROJEKT RED : il
faut les remplacer avant toute publication publique ou commerciale.
