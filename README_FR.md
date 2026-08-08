# PinteMod v2.1.1

[English documentation](README.md)

PinteMod est un framework serveur d'administration, de communauté, de localisation et de records pour les serveurs dédiés **Call of Duty: Black Ops III Zombies** utilisant **BOIII/Ezz**.

Créé et maintenu par **BiereFraiche**, avec l'aide de ChatGPT pour le développement.

Les joueurs n'ont pas besoin d'installer de mod client. PinteMod fonctionne côté serveur depuis `boiii/custom_scripts/` et fournit aussi des outils Windows optionnels pour GeoIP, les sanctions XUID persistantes, la Live Console et l'administration RCON sur le LAN.

> **Base stable :** PinteMod **v2.1.1 FINAL** reste la base stable figée.  
> **Ajouts expérimentaux post-v2.1.1 :** Community Soft Pause v0.3, retour RCON distant et événements Pause dans la Live Console.  
> Ils restent documentés séparément afin de ne pas les présenter comme faisant déjà partie du cœur stable v2.1.1.

## Points forts de la v2.1.1

- diagnostics GSC globaux avec `ezzhealth` et `ezzhealth full` ;
- vérificateur d'installation Windows avec résultats `PASS`, `WARNING` et `ERROR` ;
- suite groupée `ezzv211test suite` et `Test_PinteMod_v2.1.1.bat` ;
- statistiques anonymisées de population/langues via `ezzlangstats` ;
- modération centralisée par XUID : mute, unmute, kick, bans et historique ;
- hiérarchie stricte Owner/Admin/Moderator/Helper/User ;
- catégorie **Moderation** du menu filtrée par rôle et cible ;
- audit de compatibilité de map via `ezzmapaudit` ;
- Live Console sombre en lecture seule avec filtres et tableau des joueurs ;
- heartbeats locaux sans secret pour Ban Service, GeoIP, Live Console et Supervisor ;
- socle v2.1.0 déjà validé : identité XUID, stockage, Community, localisation, GeoIP, Ranks, EE, maps, musique, events et modules de gameplay.

La **v2.1.1 stable** consolide les correctifs trouvés pendant les validations serveur réel. Le démarrage, les outils Windows, les 28 modules GSC stables, Health, Langstats, Map Audit, la Live Console et la suite non destructive `88/88` sont validés. Les tests de modération à deux comptes restent volontairement non revendiqués.

## Ajouts expérimentaux post-v2.1.1

### Community Soft Pause v0.3

Module expérimental :

```text
boiii/custom_scripts/ezz_admin_pause_community_experimental.gsc
```

Commandes publiques :

```text
.pause
!pause

.resume
!resume

.yes
!yes

.no
!no
```

Règles actuelles :

- `.pause` / `!pause` lance un **vote majoritaire de 20 secondes** ;
- le demandeur vote automatiquement OUI ;
- si le vote passe, la partie entre en Soft Pause pour **180 secondes réelles maximum** ;
- `.resume` / `!resume` lance un **vote majoritaire de 15 secondes** pour reprendre avant la fin ;
- chaque XUID BOIII stable ne peut proposer qu'une pause par map/partie ;
- maximum **2 pauses réussies** par map/partie ;
- cooldown de 60 s après un vote Pause terminé ;
- cooldown de 30 s après un vote Resume terminé/échoué ;
- impossible de lancer la pause si un joueur est à terre/last stand ;
- un spectateur ne peut pas démarrer un vote Pause/Resume.

Pendant la Soft Pause, PinteMod :

- bloque les contrôles des joueurs actifs ;
- active temporairement l'invulnérabilité native ;
- sauvegarde/restaure santé et santé max ;
- utilise le compteur natif d'ignore zombie ;
- force temporairement `ai_DisableSpawn=1` en restaurant ensuite sa valeur précédente ;
- bloque les respawns spectateur PinteMod `ezzspawn` et `ezzjoin` ;
- conserve le serveur et le RCON actifs ;
- affiche des avertissements à 30 s et 10 s avant la reprise automatique ;
- fournit `ezzresume` comme reprise de secours admin/serveur.

Le cœur de la pause, le timer 180 s, la protection temporaire, le blocage des respawns spectateurs, la reprise anticipée et le retour RCON distant ont été validés sur serveur dédié réel dans les scénarios testés. Le rappel périodique ajouté en v0.3 doit encore recevoir une validation rapide de chargement/affichage avant d'être déclaré validé.

Il s'agit d'une **Soft Pause**, pas d'une vraie pause moteur. Les scripts de map, Easter Eggs, pièges, quêtes et autres threads indépendants peuvent continuer.

### Rappel périodique de la pause

La v0.3 ajoute un rappel léger dans le chat :

```text
Besoin d'une pause ? .pause ou !pause lance un vote (3 min max).
```

Le premier rappel est prévu après environ **5 minutes**, puis environ toutes les **12 minutes**, uniquement si :

- au moins un joueur est connecté ;
- aucune pause n'est active ;
- aucun vote Community n'est actif ;
- la limite de deux pauses réussies n'est pas déjà atteinte.

Le message reste volontairement rare pour éviter le spam.

### Contrôle LAN distant et retour PinteMod

Le PC opérateur peut utiliser un pack séparé pendant que BOIII reste sur le portable/serveur.

Structure recommandée :

```text
remote_control/
├── Launch_PinteMod_Remote_Control.bat
├── PinteMod_Remote_Control.ps1
├── PinteMod_Remote_RCON.ps1
├── PinteMod_LiveConsole.ps1
└── TUTO_PINTE_MOD_REMOTE_LAN_FR.txt
```

La console Remote RCON envoie les commandes BOIII en UDP. Le mot de passe RCON est stocké localement avec Windows DPAPI pour le compte Windows qui l'a créé.

Pour les commandes PinteMod compatibles, le GSC peut publier un retour structuré non secret ici :

```text
boiii/scriptdata/pintemod/remote/feedback.latest.txt
```

Le PC fixe lit ce fichier via le partage LAN de données PinteMod en **lecture seule**. Aucun nouveau port public n'est nécessaire.

Le premier retour structuré branché est :

```text
ezzpausestatus
```

Exemple :

```text
[PinteMod feedback]
  PinteMod Community Pause - EXPERIMENTAL v0.3
  Active: true
  Automatic resume in: 137s
  Successful pauses: 1/2
  Pause proposals used: 1
  Temporary God Mode: ON
  Spectator spawn guard: ON
  New AI spawning: blocked
```

Les commandes RCON non sensibles sont également journalisées **uniquement sur le PC opérateur** :

```text
runtime/PinteMod_Remote_RCON.audit.log
```

Les commandes contenant des termes de mot de passe/secret/token ne sont pas journalisées. Si l'entrée contient le mot de passe RCON actif, elle est refusée localement au lieu d'être envoyée à BOIII.

### Événements Pause dans la Live Console

La Live Console distante lit les données partagées PinteMod en lecture seule et peut afficher :

```text
[RCON] SEND | ezzpausestatus
[PAUSE] STATUS | active=true | remaining 137s | pauses 1/2 | proposals 1
[PAUSE] VOTE START | pause | PlayerName | majority 2/3 | 20s
[PAUSE] VOTE PASSED | pause | PlayerName | YES 2/3 | NO 0 | Majority approval
[PAUSE] ACTIVE | max 180s | ...
[PAUSE] RESUMED | automatic 180-second timeout | ...
```

La vue normale évite d'afficher les XUID complets. Les détails techniques restent dans les logs/diagnostics.

## Maps supportées

### BO3 principal et DLC

- Shadows of Evil
- The Giant
- Der Eisendrache
- Zetsubou No Shima
- Gorod Krovi
- Revelations

### Zombies Chronicles

- Nacht der Untoten
- Verrückt
- Shi No Numa
- Kino der Toten
- Ascension
- Shangri-La
- Moon
- Origins

Les maps custom peuvent charger le framework générique, mais les unlocks, armes, musiques, événements, quêtes et le comportement Soft Pause ne sont pas garantis.

## Installation

Pour la base stable v2.1.1 :

1. arrêter complètement BOIII et tous les outils PinteMod ;
2. sauvegarder `boiii/custom_scripts/` et `boiii/scriptdata/pintemod/` ;
3. supprimer les vieux scripts PinteMod de `boiii/custom_scripts/` pour éviter les doublons ;
4. extraire l'archive dans le dossier qui contient déjà `boiii` et `zone` ;
5. vérifier les composants de compatibilité BOIII requis par l'installation ;
6. lancer `Verify_PinteMod_Installation.bat` et corriger chaque `ERROR` ;
7. lancer `Launch_PinteMod_Server.bat` depuis la racine `UnrankedServer` ;
8. au premier lancement, configurer le mot de passe RCON local et le vrai launcher BOIII ;
9. lancer `Test_PinteMod_v2.1.1.bat`, puis la validation groupée avant utilisation publique.

Structure stable attendue :

```text
<UnrankedServer>/
├── Launch_PinteMod_Server.bat
├── Launch_PinteMod_Server_Only.bat
├── Launch_PinteMod_Remote_Tools.bat
├── Configure_PinteMod_RCON.bat
├── Verify_PinteMod_Installation.bat
├── Test_PinteMod_v2.1.1.bat
├── boiii/
│   ├── custom_scripts/
│   │   ├── ezz_admin_00_banner.gsc
│   │   ├── ezz_admin_01_main.gsc
│   │   ├── ezz_admin_health.gsc
│   │   ├── ezz_admin_langstats.gsc
│   │   ├── ezz_admin_moderation.gsc
│   │   ├── ezz_admin_map_audit.gsc
│   │   ├── ezz_admin_validation.gsc
│   │   └── autres modules PinteMod
│   └── tools/
├── docs/
└── zone/
```

Le module Pause reste un fichier expérimental post-v2.1.1 et ne doit pas être compté dans le cœur stable tant qu'il n'est pas intégré officiellement.

## Modes de lancement

### Local tout-en-un

```text
Launch_PinteMod_Server.bat
```

Recommandé lorsque BOIII, Ban Service, GeoIP et Live Console tournent sur la même machine.

### Serveur seul

```text
Launch_PinteMod_Server_Only.bat
```

Démarre BOIII sans GeoIP, Ban Service ni Live Console.

### Outils distants stables

```text
Launch_PinteMod_Remote_Tools.bat
```

Démarre les outils Windows stables v2.1.1 depuis une autre machine disposant des accès nécessaires.

### Pack expérimental de contrôle LAN

```text
remote_control/Launch_PinteMod_Remote_Control.bat
```

Ce mode ouvre sur le PC fixe :

1. une Live Console distante en lecture seule ;
2. une console RCON distante interactive.

Restreindre SMB et RCON au LAN/VPN de confiance. **Ne jamais exposer TCP 445/SMB sur Internet.**

## Owner par défaut

Le paquet public contient un bootstrap Owner :

```text
Display metadata: BiereFraiche
BOIII_XUID: 9cf34426f668fb8b
Role: owner
```

Aucun Admin, Moderator ou Helper n'est préconfiguré.

## Identité stable et ciblage sécurisé

Authentification, permissions, langues, sanctions, bans et données persistantes utilisent le XUID hexadécimal stable fourni par BOIII.

Les cibles connectées peuvent être sélectionnées par :

```text
<PlayerName|BOIII_XUID|ClientNumber>
```

Le pseudo reste un nom d'affichage/confort. En cas d'ambiguïté, PinteMod exige un XUID ou un numéro client.

## Rôles

| Niveau | Rôle | Accès typique |
|---:|---|---|
| 4 | Owner | Accès complet, rôles, resets protégés |
| 3 | Admin | Modération des rôles inférieurs, maps, rounds, Events, maintenance |
| 2 | Moderator | Administration courante de partie |
| 1 | Helper | Assistance limitée et diagnostics |
| 0 | User | Menu public, votes, Late Join, langue, ranks et records |

Règles :

- impossible de sanctionner un rôle égal ou supérieur ;
- auto-sanction refusée ;
- Owner bootstrap protégé ;
- tentatives refusées journalisées ;
- le pseudo n'est jamais une clé de persistance.

## Commandes Chat

Préfixe principal : `.`. Le préfixe historique `!` reste accepté.

Exemples publics :

```text
.menu
.spawn

.pause
.resume
.yes
.no
.votestatus

.votemap origins
.voterestart
.votekick <player> [reason]

.lang fr
.lang en
.lang es
.lang auto

.rank
.ranks
.record
.records 2
.eerecord
.eerecords 4
```

Diagnostics/statistiques selon rôle :

```text
.health
.health full
.mapaudit
.mapaudit full
.langstats
.langstats countries
.langstats languages
.history <player|xuid|client>
```

Modération selon rôle :

```text
.mute <player|xuid|client> [reason]
.unmute <player|xuid|client>
.kick <player|xuid|client> [reason]
.ban <player|xuid|client> 30m reason
.ban <player|xuid|client> permanent reason
.unban <player|xuid|client>
.baninfo <player|xuid|client>
.banlist
```

Autres exemples staff :

```text
.points 50000
.ammo
.weapon raygun
.perk jug
.god
.ignore
.respawn <player>
.revive <player>
.setrole <player> moderator
```

## Menu

Ouvrir le menu stable avec :

```text
.menu
```

Contrôles HUD :

- **Action Slot 2 / touche 2 :** haut ;
- **Action Slot 3 / touche 3 :** bas ;
- **Use / Reload :** sélectionner ;
- **Melee :** retour/fermeture.

La Soft Pause expérimentale n'est pas encore intégrée officiellement au menu stable.

## Fonctions Community

Fonctions stables :

- accueil HUD et rappels publics ;
- Late Join public via `.spawn` ou menu ;
- respawn spectateur administratif ;
- revive natif Owner-only en last stand ;
- vote prochaine map ;
- vote restart ;
- vote-kick protégé ;
- changement automatique de map ;
- présence suivie par XUID ;
- rapports connexion/votes/modération.

Ajouts expérimentaux :

- vote Pause à majorité ;
- vote Resume anticipé ;
- quota de proposition par XUID ;
- maximum deux pauses réussies ;
- reprise automatique 180 s ;
- rappel périodique ;
- blocage des respawns PinteMod pendant la pause.

### Spawn, respawn et revive

- `ezzjoin` / `.spawn` : Late Join public d'un spectateur éligible ;
- `ezzspawn` : respawn spectateur administratif ;
- `ezzrevive` : revive natif last stand, réservé Owner via Chat/menu.

Pendant une Soft Pause active, les deux chemins de respawn PinteMod sont refusés.

## Bans XUID persistants

Le système stable v2.1.1 conserve la persistance par XUID et la hiérarchie de modération.

Données locales :

```text
boiii/scriptdata/pintemod/bans/
boiii/scriptdata/pintemod/moderation/
```

PinteMod ne cherche pas à conserver des listes d'IP dans ce système.

Les validations réelles à deux comptes restent différées lorsqu'elles sont déjà indiquées comme telles.

## Localisation et GeoIP

Langues intégrées :

```text
fr  Français
en  English
es  Español
```

Le choix manuel est prioritaire :

```text
.lang fr
.lang en
.lang es
.lang auto
```

Le bridge GeoIP lit temporairement l'adresse nécessaire via RCON, résout pays/langue en mémoire et ne persiste pas cette adresse dans les données PinteMod.

## Ranks & Records

Stockage :

```text
boiii/scriptdata/pintemod/ranks_v2/
```

Le système utilise le XUID pour la persistance, gère la présence, les records par taille d'équipe, l'ordre round/temps, les protections UNRANKED et les opérations d'audit/backup/reset.

Commandes publiques :

```text
.rank
.ranks
.record
.records [1-4]
```

## Easter Egg Records

Stockage :

```text
boiii/scriptdata/pintemod/easter_eggs_v2/
```

Les écritures officielles restent contrôlées map par map. Un détecteur doit être validé sur serveur réel avant activation officielle.

La Soft Pause n'est pas présentée comme gelant les timers de scripts Easter Egg.

## Stockage JSON protégé

Les registres sensibles utilisent une stratégie d'écriture/vérification/récupération avec fichiers temporaires et sauvegardes.

## Logs et confidentialité

Logs stables :

```text
boiii/scriptdata/pintemod/logs/
```

La Pause expérimentale ajoute :

```text
boiii/scriptdata/pintemod/logs/pause.log
```

Le retour distant ajoute :

```text
boiii/scriptdata/pintemod/remote/feedback.latest.txt
```

Ce fichier ne doit contenir aucun secret RCON.

## Live Console en lecture seule

La Live Console stable reste un outil de lecture : elle ne devient pas elle-même un client RCON d'administration.

Elle suit notamment Chat, connexions, Community, votes, sanctions, Ranks, EE, Storage, Localization et erreurs des services.

La variante distante expérimentale lit aussi :

```text
logs/pause.log
runtime/PinteMod_Remote_RCON.audit.log
```

et produit des événements compacts `[PAUSE]` et `[RCON]`.

## Registres partagés

`ezz_admin_registry.gsc` centralise métadonnées de maps, alias, rôles de commandes et impact gameplay.

`ezz_admin_map_audit.gsc` fournit l'audit conservateur de la map active.

Le module Pause reste extérieur à l'intégration stable jusqu'au prochain passage propre.

## État de validation

### Socle stable v2.1.0 / v2.1.1

```text
Chargement modules stables           PASS
Identité XUID / Owner                PASS
Stockage protégé                     PASS
Chat / Menu                          PASS
Community / Spawn / Late Join        PASS
FR / EN / ES                         PASS
GeoIP sans stockage IP PinteMod      PASS
Ranks & Records                      PASS
Structure Easter Egg Records         PASS
Maps / Music / Events                PASS
Perks / Power-Ups / Rounds           PASS
Weapons / Zombies                    PASS
RCON persistant                      PASS
Séparation Chat/commandes            PASS
Vérificateur installation            PASS
ezzhealth full                       PASS
Live Console sombre                  PASS
ezzv211test suite                    PASS — 88/88
```

Les tests réels de modération à deux comptes restent différés lorsqu'indiqué.

### Community Soft Pause expérimentale

Validé sur serveur réel pour les scénarios testés :

```text
Prototype 10 s                       PASS
Timeout réel 180 s                   PASS
Freeze joueur                        PASS
Invulnérabilité temporaire           PASS
Écrasement géant Origins             PASS (scénario testé)
Blocage nouveaux spawns IA           PASS
Blocage ezzspawn pendant pause       PASS
Blocage ezzjoin pendant pause        PASS
Reprise anticipée                    PASS
Workflow Community Pause             PASS
Retour distant ezzpausestatus        PASS
Événements Pause Live Console        PASS
```

Le rappel périodique v0.3 doit encore être confirmé rapidement sur serveur réel.

## Limitations connues

- la Soft Pause n'est pas une vraie pause moteur ;
- des timers/scripts de map, EE, pièges ou quêtes peuvent continuer ;
- le comportement Pause n'est pas garanti sur toutes les maps/custom maps ;
- tous les signaux EE natifs ne sont pas validés ;
- certains tests de modération deux comptes restent différés ;
- BOIII peut afficher ses propres blocs `status` dans sa console native ;
- le déploiement distant exige une configuration explicite LAN/VPN/firewall/partages ;
- **ne jamais exposer SMB/TCP 445 sur Internet** ;
- les secrets DPAPI sont propres à la machine/au compte Windows ;
- le retour RCON structuré ne couvre pour l'instant que certaines commandes PinteMod, en commençant par `ezzpausestatus` ;
- noclip n'est pas présenté comme corrigé ;
- aucune fonction AFK n'est incluse ;
- aucun verrou de transition de round n'est inclus ;
- les maps custom demandent une validation/profil spécifique.

## Contenu public

Base stable :

```text
README.md
README_FR.md
LICENSE
SECURITY.md
THIRD_PARTY_NOTICES.md
CHANGELOG_v2.1.1.txt
SHA256SUMS.txt

Launch_PinteMod_Server.bat
Launch_PinteMod_Server_Only.bat
Launch_PinteMod_Remote_Tools.bat
Configure_PinteMod_RCON.bat
Verify_PinteMod_Installation.bat
Test_PinteMod_v2.1.1.bat

boiii/custom_scripts/
boiii/tools/
docs/
```

Ajouts expérimentaux post-v2.1.1 :

```text
boiii/custom_scripts/ezz_admin_pause_community_experimental.gsc
remote_control/
```

## Fichiers locaux à ne jamais publier

```text
zone/pintemod_server_secrets.cfg
boiii/tools/*.local.json
boiii/tools/*.secret.txt
boiii/tools/runtime/
boiii/scriptdata/pintemod/
configuration serveur privée
```

Le dossier `remote_control/runtime/` et le secret DPAPI Remote RCON restent également locaux.

## Licence

Copyright © 2026 BiereFraiche.

PinteMod est distribué sous **GNU General Public License version 3**. Voir `LICENSE` et `THIRD_PARTY_NOTICES.md`.

Cette licence couvre le code propre à PinteMod. Elle ne donne aucun droit sur Call of Duty: Black Ops III, BOIII/Ezz ou des composants propriétaires externes.
