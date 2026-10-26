# Aperçu de portée vocale

F11 change le mode vocal dans `open-voice`. Chaque changement **confirmé par le
serveur** affiche un cercle 3D jaune au sol pendant trois secondes, uniquement
pour le joueur concerné. Il suit sa position et prend le rayon exact du mode :
chuchotement 3 m, normal 20 m, cri 40 m.

Les distances se configurent dans `resources/system/open-voice/server/config.lua`.
`LightRpConfig.voice.ranges` est une ancienne configuration du HUD, **pas** la
source des portées F11. Le cercle utilise directement la réponse serveur.
La couleur et la durée sont au début de `open-voice/client/range_preview.lua`.

Le rendu natif `Open77.anchors.create({ render = "ring", ... })` projette des
sommets définis dans le monde et échantillonne le relief/les obstacles. Il ne
crée pas de surface CEF ni d'entité mesh. Les grandes portées peuvent sortir
du champ de vision ; les obstacles peuvent masquer une partie du cercle.
La limite de ce rendu est de 50 m de rayon : au-delà, un diagnostic est écrit
sans bloquer la voix ni afficher un cercle de taille trompeuse.

Un seul handle et une seule tâche temporaire : les changements rapides réutilisent
le cercle et relancent son délai. La tâche s'arrête à l'expiration, à la mort,
à la disparition du personnage ou au masquage du HUD vocal. Le cycle de vie de
la ressource nettoie également les ancres à la déconnexion/à l'arrêt.
La première synchronisation, les doublons et les demandes refusées ne l'affichent pas.

## Validation — 22 septembre 2026

Tests Lua réels, avec doubles déterministes des API natives :

```powershell
pwsh -NoProfile -File tests/run-lua.ps1 -Test voice_range_test.lua
pwsh -NoProfile -File tests/run-lua.ps1 -Test voice_hud_test.lua
```

Résultats : rayon, suivi, changements rapides, expiration non prolongée par les
doublons, demandes refusées, NaN/infini, mort, perte du personnage, erreurs du
rendu, indépendance des blocages UI et arrêt/reprise de ressource validés.

Validation en jeu local sur `127.0.0.1:11828` : entrée en monde confirmée par
bootstrap terminé et personnage vivant ; F11 réel, cercles 3/20/40 m, suivi
pendant la marche, disparition après trois secondes. Captures locales dans
`.open77/voice-range-{whisper,normal,shout,follow,expired}.png` à la racine LightRP.
Aucun nouveau diagnostic d'échec du cercle ni erreur Lua dans le journal.
Le test concerne le retour visuel ; aucun changement de codec/routage audio
et aucune nouvelle validation micro/réseau multi-joueurs ne sont revendiqués.
