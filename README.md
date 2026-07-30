# PinteMod v1.3 FINAL

Framework d’administration et de fonctionnalités communautaires pour serveur dédié BOIII Zombies.

## Contenu principal

- menu public et administrateur avec `.menu` ;
- commandes Chat avec préfixe `.` et compatibilité historique `!` ;
- late join public avec `.spawn` et respawn administratif ;
- votes prochaine map, restart et votekick ;
- blocage de reconnexion après votekick jusqu’au changement de map ;
- changement automatique de map en fin de partie ;
- Live Console et journaux ;
- modules Maps, Music, Events, Perks, Weapons, Power-Ups, Rounds et Zombies ;
- Ranks & Records persistants, catégories 1P à 4P et Top 5 par catégorie ;
- parties automatiquement non classées après une commande influençant le gameplay ;
- sauvegarde, audit et remise à zéro protégée des classements.

## Installation

Copier le contenu de `custom_scripts/` dans le dossier `boiii/custom_scripts/` du serveur, puis redémarrer complètement le serveur.

Les outils de Live Console se trouvent dans `tools/`.

## Commandes publiques principales

- `.menu`
- `.spawn`
- `.yes` / `.no`
- `.votemap <map>`
- `.voterestart`
- `.votekick <joueur> [raison]`
- `.rank` / `.ranks`
- `.record` / `.records [1-4]`

## Stockage

Les données persistantes sont écrites dans `boiii/scriptdata/pintemod/`.

## Limites connues

- authentification et records encore liés au pseudo ;
- les pseudos contenant des espaces ne sont pas uniformément supportés ;
- un joueur votekick peut contourner le blocage de la map en changeant de pseudo ;
- SteamID64/XUID et remise à zéro des records sont prévus ultérieurement ;
- les records Easter Egg seront ajoutés carte par carte, uniquement avec une détection fiable.

## Crédits

Créé par BiereFraiche et ChatGPT.
