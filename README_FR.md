# PinteMod

[Read this guide in English](README.md)

PinteMod est un framework côté serveur pour **Call of Duty: Black Ops III Zombies** avec BOIII/Ezz. Il apporte l’administration, des fonctions communautaires, la localisation, les records et des informations de santé utiles pour le serveur.

Les joueurs n’ont rien à installer : PinteMod tourne uniquement sur le serveur.

La base stable de PinteMod est **v2.1.1**. Le moyen le plus simple de l’installer et de l’utiliser est **PinteMod Control Center v2.4.5**.

## Lancer son serveur en quelques clics — recommandé

1. Téléchargez un serveur BOIII/Ezz vierge prêt à utiliser depuis [le dossier Mega partagé](https://mega.nz/folder/MYsTGa6I#gJviuei7G6XuFicNy_L9BQ).
2. Téléchargez [PinteMod Control Center](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.4.5).
3. Ouvrez le Control Center puis ajoutez le dossier qui contient `boiii` et `Server.bat`.
4. Choisissez **Installer PinteMod**. Le Control Center détecte le serveur et prépare les fichiers locaux compatibles.
5. Définissez le mot de passe RCON quand il est demandé, puis démarrez le serveur depuis le Control Center.
6. Une fois le serveur en ligne, lancez le contrôle de santé PinteMod.

Pour un serveur local normal, cela suffit. Le Control Center peut aussi gérer plusieurs serveurs, afficher les joueurs, les logs, les records et l’état des services.

[![Télécharger PinteMod Control Center](https://img.shields.io/badge/Télécharger-Control%20Center%20v2.4.5-168BFF)](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.4.5)

[![Tableau de bord PinteMod Control Center](https://raw.githubusercontent.com/BiereFraiche/PinteModControlCenter/main/design/pintemod-control-center-reference.png)](https://github.com/BiereFraiche/PinteModControlCenter)

## Ce que PinteMod apporte

- un menu en jeu clair pour l’administration et la communauté ;
- les rôles owner, admin, moderator, helper et joueur ;
- les bans, mutes et l’historique de modération persistants par XUID ;
- les préférences de langue et les statistiques de langues anonymisées ;
- les informations de pays GeoIP, stockées localement en respectant la confidentialité ;
- les ranks, records de manches et records d’Easter Egg ;
- les contrôles de compatibilité de map, diagnostics de santé et état des services ;
- des outils Windows optionnels pour le Ban Service, le bridge GeoIP et la Live Console.

Le framework stable prend en charge les maps Zombies BO3 et Zombies Chronicles. Les maps custom profitent du socle générique, mais les quêtes, musiques et fonctions propres à chaque map ne sont pas garanties.

## Installation manuelle — utilisateurs avancés

Utilisez cette méthode seulement si vous ne souhaitez pas passer par le Control Center.

1. Arrêtez BOIII et tous les outils PinteMod.
2. Sauvegardez `boiii/custom_scripts/` et `boiii/scriptdata/pintemod/`.
3. Extrayez le package dans le dossier serveur existant qui contient déjà `boiii` et `zone`.
4. Lancez `Verify_PinteMod_Installation.bat` et corrigez chaque `ERROR`.
5. Lancez `Launch_PinteMod_Server.bat`.
6. Configurez le RCON localement s’il est demandé ; ne partagez jamais son mot de passe.

Lanceurs utiles :

- `Launch_PinteMod_Server.bat` — serveur local tout-en-un et outils optionnels ;
- `Launch_PinteMod_Server_Only.bat` — BOIII seul ;
- `Launch_PinteMod_Remote_Tools.bat` — outils depuis un autre PC Windows de confiance ;
- `Configure_PinteMod_RCON.bat` — configuration RCON manuelle ;
- `Test_PinteMod_v2.1.1.bat` — vérification manuelle.

## Utilisation sûre

- Ne publiez jamais un mot de passe RCON, un fichier `*.secret`, un XUID joueur, des données runtime ou des logs.
- Gardez RCON et SMB accessibles uniquement depuis un LAN ou VPN de confiance.
- N’exposez jamais SMB/TCP 445 directement sur Internet.
- Pour le premier démarrage, privilégiez le Control Center : il guide les étapes nécessaires et évite les modifications manuelles inutiles.

## Aide complémentaire

- [Guide d’installation manuelle](docs/INSTALLATION_FR.txt)
- [Guide VM et déploiement distant](docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt)
- [Référence des commandes console](docs/COMMANDES_CONSOLE_FR.txt)
- [Guide des bans et de la modération](docs/BANNISSEMENTS_FR.txt)
- [PinteMod Control Center](https://github.com/BiereFraiche/PinteModControlCenter)
- [Politique de sécurité](SECURITY.md)
- [Journal des changements](CHANGELOG.md)

## Stable et expérimental

PinteMod **v2.1.1** est le socle stable public. La Community Soft Pause et certains retours de contrôle distant restent expérimentaux : testez-les d’abord sur un serveur privé avant de les utiliser pour un événement public.

Créé et maintenu par **BiereFraiche**, avec l’assistance de développement de ChatGPT et Codex.

## Licence

Voir [LICENSE](LICENSE).
