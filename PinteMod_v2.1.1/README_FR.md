# PinteMod v2.1.1

[English documentation](README.md)

PinteMod est un framework serveur d’administration, de communauté, de localisation et de records pour les serveurs dédiés **Call of Duty: Black Ops III Zombies** fonctionnant sous **BOIII/Ezz**.

Créé et maintenu par **BiereFraiche**, avec l’assistance de développement de ChatGPT.

Les joueurs n’ont aucun mod client à installer. PinteMod fonctionne depuis `boiii/custom_scripts/` et fournit des outils Windows optionnels pour la localisation GeoIP, les bannissements XUID persistants et une Live Console en lecture seule.

## Nouveautés principales de la v2.1.1

- diagnostic global GSC avec `ezzhealth` et `ezzhealth full` ;
- vérificateur d’installation Windows avec résultats `PASS`, `WARNING` et `ERROR` ;
- suite globale `ezzv211test suite` et lanceur `Test_PinteMod_v2.1.1.bat` ;
- statistiques anonymisées de population et de langues avec `ezzlangstats` ;
- modération XUID centralisée : mute, unmute, kick, bans et historique ;
- hiérarchie stricte Owner/Admin/Moderator/Helper/User, refus journalisés et Owner bootstrap protégé ;
- catégorie **Moderation** dans le menu, filtrée par rôle et par cible ;
- audit conservateur de la carte active avec `ezzmapaudit` ;
- exemple documenté de profil de carte custom, séparé du runtime ;
- Live Console sombre, toujours en lecture seule, avec filtres Warn/Mute/Ban et tableau de bord joueurs ;
- heartbeats locaux sans secret pour Ban Service, GeoIP, Live Console et superviseur ;
- superviseur lancé discrètement par le lanceur principal, avec erreurs conservées dans les journaux ;
- conservation de toutes les fonctions v2.1.0 déjà validées : identité XUID, stockage, communauté, localisation, GeoIP, Ranks, EE, Maps, musique, événements et gameplay.

La **v2.1.1 stable** consolide tous les correctifs issus de la validation réelle. Le démarrage, les outils Windows, les 28 modules GSC, Health, Langstats, Map Audit, la Live Console et la suite non destructive `88/88` sont validés sur le serveur réel. La Live Console a également été validée avec présence dynamique et suppression du rafraîchissement vide répétitif. Les actions de modération avec un second compte restent volontairement non validées officiellement.

## Cartes prises en charge

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

Les cartes personnalisées peuvent charger le framework générique, mais leurs ouvertures, armes, musiques, événements et quêtes spécifiques ne sont pas garantis.

## Installation

1. arrêter complètement BOIII et tous les outils PinteMod ;
2. sauvegarder `boiii/custom_scripts/` et `boiii/scriptdata/pintemod/` ;
3. supprimer les anciens scripts PinteMod de `boiii/custom_scripts/` afin d’éviter les modules en double ;
4. extraire l’archive directement dans le dossier qui contient déjà `boiii` et `zone` ;
5. vérifier que `hotfix.gsc` appartient bien à votre installation BOIII : il est requis localement mais n’est jamais distribué par PinteMod ;
6. lancer `Verify_PinteMod_Installation.bat` et corriger les lignes `ERROR` ;
7. lancer `Launch_PinteMod_Server.bat` depuis la racine de `UnrankedServer` ;
8. au premier lancement, définir le mot de passe RCON local et sélectionner le vrai lanceur BOIII ;
9. exécuter `Test_PinteMod_v2.1.1.bat`, puis la validation serveur regroupée avant ouverture publique.

Structure attendue :

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

`hotfix.gsc` n’est volontairement pas fourni : il appartient à l’environnement de compatibilité BOIII, pas à PinteMod.

Voir [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt) et [`docs/HEALTH_VERIFIER_FR.txt`](docs/HEALTH_VERIFIER_FR.txt).

## Modes de lancement

### Mode local complet

```text
Launch_PinteMod_Server.bat
```

Cas recommandé lorsque BOIII, Ban Service, GeoIP et Live Console tournent sur la même machine. BOIII et la Live Console restent visibles. Ban Service, GeoIP et le superviseur fonctionnent en arrière-plan.

Le superviseur surveille BOIII et les outils enfants, bloque les doubles instances et les arrête proprement à la fermeture du serveur. Il n’ouvre plus une fenêtre supplémentaire permanente. Ses erreurs restent consultables dans :

```text
boiii/tools/runtime/PinteMod_Supervisor.log
boiii/tools/runtime/PinteMod_Supervisor.bootstrap.error.log
```

### Serveur uniquement

```text
Launch_PinteMod_Server_Only.bat
```

Lance BOIII sans GeoIP, Ban Service ni Live Console. Le diagnostic indiquera alors que ces outils sont absents ou configurés mais non actifs.

### VM, réseau local ou poste d’administration distant

```text
Launch_PinteMod_Remote_Tools.bat
```

Lance Ban Service, GeoIP et Live Console depuis une autre machine Windows ayant accès au RCON et à `boiii/scriptdata/pintemod`.

La configuration locale standard utilise `127.0.0.1`. Depuis une VM, le LAN ou un VPN, employer une adresse stable, limiter le pare-feu et les droits du partage, puis recréer les secrets DPAPI sur la machine et le compte Windows qui exécuteront les outils. Un fichier DPAPI copié depuis une autre machine ou un autre compte devient illisible.

Voir [`docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt`](docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt).

## Propriétaire par défaut

La distribution publique contient un seul Owner bootstrap :

```text
Métadonnée d’affichage : BiereFraiche
BOIII_XUID : 9cf34426f668fb8b
Rôle : owner
```

Aucun Admin, Moderator ou Helper n’est préconfiguré. Aucune base de rôles active, profil joueur, record, base de bannissements, vote, journal ou sauvegarde serveur n’est distribué.

Les autres propriétaires doivent remplacer ou retirer ce XUID dans `boiii/custom_scripts/ezz_admin_config.gsc`, ou attribuer leur propre rôle depuis la console dédiée :

```text
ezzidsetrole <PlayerName|BOIII_XUID|ClientNumber> owner
```

## Identité stable et ciblage sécurisé

L’authentification, les permissions, les langues, les bannissements et les données persistantes utilisent le XUID hexadécimal fourni par BOIII.

Les commandes console peuvent cibler un joueur connecté avec :

```text
<PlayerName|BOIII_XUID|ClientNumber>
```

Exemples :

```text
ezzidentity 9cf34426f668fb8b
ezzidentity #0
ezzidentity client:0
ezzidentity BiereFraiche
```

Le pseudo n’est qu’un raccourci lorsque le résultat est sans ambiguïté. Si deux joueurs utilisent le même nom, PinteMod refuse le sélecteur par pseudo et exige un XUID ou un numéro client.

Le Chat et le menu transportent en interne un XUID ou un slot client au lieu de faire confiance au pseudo brut. Les séparateurs de commandes dangereux et les retours à la ligne sont rejetés avant l’exécution serveur.

## Rôles

| Niveau | Rôle | Accès habituel |
|---:|---|---|
| 4 | Owner | Toutes les permissions, gestion des rôles, resets protégés et actions sur les rôles inférieurs |
| 3 | Admin | Modération des Moderator, Helper et User ; cartes, manches, Events et maintenance serveur |
| 2 | Moderator | Administration courante de partie, sans sanctions persistantes dans la v2.1.1 |
| 1 | Helper | Assistance et diagnostics limités, sans sanctions persistantes |
| 0 | User | Menu public, votes, Late Join, langues, rangs et records publics |

Règles de hiérarchie appliquées aux sanctions :

- aucun rôle ne peut sanctionner un rôle égal ou supérieur ;
- impossible de se sanctionner soi-même ;
- l’Owner bootstrap `9cf34426f668fb8b` est protégé ;
- les actions refusées sont journalisées ;
- le pseudo n’est jamais utilisé comme clé persistante.

Les changements persistants de rôles sont stockés localement dans :

```text
boiii/scriptdata/pintemod/identity/roles.json
```

Voir [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt).

## Commandes Chat

Le préfixe principal est `.`. L’ancien préfixe `!` reste accepté.

Exemples publics :

```text
.menu
.spawn
.lang fr
.lang en
.lang es
.lang auto
.yes
.no
.votestatus
.votemap origins
.voterestart
.votekick <joueur> [raison]
.rank
.ranks
.record
.records 2
.eerecord
.eerecords 4
```

Diagnostics et statistiques selon le rôle :

```text
.health
.health full
.mapaudit
.mapaudit full
.langstats
.langstats countries
.langstats languages
.history <joueur|xuid|client>
```

Modération selon le rôle :

```text
.mute <joueur|xuid|client> [raison]
.unmute <joueur|xuid|client>
.kick <joueur|xuid|client> [raison]
.ban <joueur|xuid|client> 30m raison
.ban <joueur|xuid|client> permanent raison
.unban <joueur|xuid|client>
.baninfo <joueur|xuid|client>
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
.respawn <joueur>
.revive <joueur>
.setrole <joueur> moderator
```

La référence complète des commandes console se trouve dans [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt).

## Menu

Ouvrir le menu avec :

```text
.menu
```

Contrôles affichés dans le HUD serveur :

- **Action Slot 2 / touche 2 :** monter ;
- **Action Slot 3 / touche 3 :** descendre ;
- **Utiliser / Recharger :** sélectionner ;
- **Mêlée :** retour ou fermeture.

Les sections comprennent Communauté/Joueurs, Administration, **Moderation**, Perks, Armes, Manches, Power-Ups, Fun et Ranks & Records.

La catégorie Moderation expose selon le rôle :

```text
Mute
Unmute
Kick
Temporary Ban
Permanent Ban
Ban Information
Player History
```

Les cibles sont filtrées avant affichage selon leur hiérarchie. Les actions utilisent un XUID ou un numéro client en interne ; le pseudo sert uniquement de libellé. L’Owner bootstrap et les rôles égaux ou supérieurs ne peuvent pas être sélectionnés comme cibles valides.

## Fonctions communautaires

- HUD de bienvenue et rappels publics ;
- Late Join public avec `.spawn` ou le menu Joueurs ;
- respawn administratif des spectateurs ;
- revive natif réservé à l’Owner pour un joueur à terre ;
- vote de prochaine carte sans interrompre la partie ;
- vote de redémarrage avec avertissement ;
- vote-kick protégé avec blocage de reconnexion ;
- changement automatique de carte après la partie ;
- suivi de présence résistant aux reconnexions et changements de pseudo ;
- rapports Live de connexion, votes et modération.

### Spawn, respawn et revive

Ces opérations sont distinctes :

- `ezzjoin` / `.spawn` : Late Join public d’un spectateur éligible ;
- `ezzspawn` : respawn administratif d’un spectateur ;
- `ezzrevive` : revive natif d’un joueur à terre, réservé à l’Owner dans le Chat/menu.

## Bannissements XUID persistants

La modération v2.1.1 conserve le système de bans existant et ajoute une couche commune d’historique, de hiérarchie, de mute et de kick.

Commandes console principales :

```text
ezzmute <PlayerName|BOIII_XUID|ClientNumber> [raison]
ezzunmute <PlayerName|BOIII_XUID|ClientNumber>
ezzkick <PlayerName|BOIII_XUID|ClientNumber> [raison]
ezzban <PlayerName|BOIII_XUID|ClientNumber> <durée|permanent> [raison]
ezzunban <PlayerName|BOIII_XUID|ClientNumber>
ezzbaninfo <PlayerName|BOIII_XUID|ClientNumber>
ezzhistory <PlayerName|BOIII_XUID|ClientNumber>
```

Durées acceptées :

```text
30m  2h  7d  permanent
```

Les bans temporaires sont calculés en UTC par `PinteMod_Ban_Service.ps1`. Le service conserve l’état actif et expire les sanctions sans dépendre de l’horloge d’une manche. Bannir un joueur connecté marque la partie actuelle `UNRANKED`.

L’historique est indexé par XUID et synthétise notamment :

```text
Kicks
Mutes / Unmutes
Temporary bans
Permanent bans
Last action
```

Aucune adresse IP n’est stockée. Les données locales se trouvent sous :

```text
boiii/scriptdata/pintemod/bans/
boiii/scriptdata/pintemod/moderation/
```

Le mute PinteMod bloque les routes Chat gérées par le framework et conserve l’état persistant. La capacité à empêcher également l’affichage natif BOIII doit être confirmée lors du test à deux comptes ; elle n’est pas déclarée validée dans ce paquet TEST.

Voir [`docs/BANNISSEMENTS_FR.txt`](docs/BANNISSEMENTS_FR.txt) et [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt).

## Localisation et GeoIP

Langues intégrées complètement :

```text
fr  Français
en  English
es  Español
```

Le choix manuel est prioritaire sur GeoIP et restauré par XUID :

```text
.lang fr
.lang en
.lang es
.lang auto
```

Le bridge GeoIP lit temporairement l’adresse d’une nouvelle connexion par RCON, résout le pays et la langue en mémoire, puis ne conserve pas cette adresse. BOIII peut malgré tout afficher la réponse brute de `status` dans sa console native.

La v2.1.1 ajoute des compteurs agrégés sans association publique joueur/pays :

```text
ezzlangstats
ezzlangstats countries
ezzlangstats languages
ezzlangstats reset prepare
ezzlangstats reset confirm <token>
```

Seuls les codes pays, langues sélectionnées et nombres de connexions sont comptés. Aucune liste d’IP et aucune liste de XUID uniques n’est conservée par ce système. Les données guideront une éventuelle future traduction allemande, portugaise brésilienne, italienne, polonaise ou russe ; aucune traduction partielle n’est incluse.

Voir [`docs/LOCALISATION_GEOIP_FR.txt`](docs/LOCALISATION_GEOIP_FR.txt) et [`docs/LANGSTATS_FR.txt`](docs/LANGSTATS_FR.txt).

## Ranks & Records

Les rangs utilisent la racine de stockage isolée :

```text
boiii/scriptdata/pintemod/ranks_v2/
```

Fonctions :

- temps de jeu et statistiques de sessions par XUID ;
- meilleure manche et position d’activité globale ;
- Top 5 par carte et catégorie 1P/2P/3P/4P ;
- présence minimale de 70 % pour participer à un record ;
- meilleure manche prioritaire, puis temps le plus court en cas d’égalité ;
- gestion des participants connectés et déconnectés éligibles par XUID ;
- protection UNRANKED automatique après une commande qui affecte le gameplay ;
- rollback des records personnels/équipe créés plus tôt dans la même partie ;
- commandes d’audit, sauvegarde et réinitialisation protégée.

Commandes publiques :

```text
.rank
.ranks
.record
.records [1-4]
```

Maintenance :

```text
ezzrankstatus
ezzranktest suite <selector>
ezzrankaudit
ezzrankbackup [label]
ezzrankreset prepare
ezzrankreset confirm <token>
```

Aucun ancien record basé sur le pseudo n’est importé automatiquement.

## Records Easter Egg

Le stockage EE utilise une base v2 séparée :

```text
boiii/scriptdata/pintemod/easter_eggs_v2/
```

Le système structurel enregistre notamment les XUID de complétion, les détenteurs actifs, les participants exclus, le temps, la catégorie de joueurs, l’état ranked/unranked, la raison d’acceptation/rejet et une signature anti-doublon.

Les écritures officielles sont contrôlées **carte par carte**. Un profil reste en diagnostic tant que son signal natif de fin de quête principale n’a pas été confirmé sur un serveur réel. Le profil Origins est validé pour les écritures officielles depuis la v2.1.0 et reste inchangé dans la v2.1.1.

Commandes utiles :

```text
ezzeestatus
ezzeemaps
ezzeeplayers
ezzeetest suite
ezzeeaudit
ezzeecandidates <map>
ezzeevalidate <map> confirm
ezzeeval <map>
ezzeeofficial <map> enable
```

Ne pas activer les écritures officielles sur une carte non validée. Voir [`docs/VALIDATION_EE_FR.txt`](docs/VALIDATION_EE_FR.txt).

## Stockage JSON protégé

Les registres Identity, Ranks et EE utilisent `ezz_admin_storage.gsc`.

Pour chaque écriture protégée, PinteMod :

1. écrit un fichier `.tmp` ;
2. le relit et le valide ;
3. conserve l’ancienne version valide en `.bak` ;
4. écrit et vérifie le fichier actif ;
5. restaure la version précédente si la vérification échoue.

Les JSON invalides trouvés au chargement sont copiés dans :

```text
boiii/scriptdata/pintemod/backups/corrupt/
```

Un `.bak` valide est restauré lorsqu’il existe. Il s’agit d’une stratégie récupérable en deux phases utilisant les fonctions fichiers de BOIII, pas d’un renommage atomique garanti par le système de fichiers.

Diagnostics :

```text
ezzstoragestatus
ezzstoragetest suite
```

## Journaux et confidentialité

La configuration publique actuelle contient notamment :

```gsc
level.pintemod_log_chat_messages = true;
level.pintemod_log_xuids = true;
level.pintemod_log_guids = false;
level.pintemod_log_max_size_kb = 2048;
```

Les journaux sont regroupés par carte/session sous :

```text
boiii/scriptdata/pintemod/logs/
├── current_session.json
├── sessions/<map>_s<counter>_<GetTime>/
│   ├── connections.log
│   ├── identity.log
│   ├── community.log
│   ├── ranks.log
│   ├── easter_eggs.log
│   ├── storage.log
│   ├── bans.log
│   ├── chat/
│   └── votekick/
└── archive/YYYY-MM-DD/
```

La journalisation du Chat normal est activée dans la configuration publique v2.1.1 afin que la Live Console affiche les messages et conserve les éléments utiles à la modération. Le propriétaire du serveur doit informer les joueurs lorsque la réglementation applicable l’exige et peut désactiver cette option dans `ezz_admin_config.gsc`. Les GUID restent désactivés. Les règles de masquage XUID/GUID sont appliquées centralement aux journaux gérés.

## Live Console en lecture seule

Les lanceurs local complet et outils distants démarrent automatiquement la Live Console. Elle peut aussi être lancée directement avec :

```text
boiii\tools\Launch_PinteMod_LiveConsole.bat
```

La Live Console v2.1.1 :

- utilise un fond noir et une présentation plus sobre ;
- détecte le manifeste de carte/session actif ;
- sépare les messages Chat des commandes ;
- suit connexions, Communauté, votes, kicks, warnings, mutes, bans, Identity, Ranks, EE, Storage et Localisation ;
- affiche un tableau de bord des joueurs connectés avec XUID abrégé, rôle, langue, pays, présence, mute/ban, statut Ranked et événement récent ;
- masque les IP et n’affiche pas les GUID ;
- limite les rafraîchissements et ne redessine le tableau que lorsque son contenu change ;
- suit aussi les erreurs du superviseur, de Ban Service et de GeoIP ;
- propose filtres, recherche, export et ouverture du dossier actif ;
- peut jouer un son court pour les erreurs critiques ;
- archive les sessions terminées selon la date du système ;
- **n’instancie aucun client RCON et n’envoie jamais de commande au serveur**.

Des heartbeats locaux permettent à `ezzhealth` de distinguer un outil connecté, absent, arrêté ou en erreur. Ces fichiers ne contiennent aucun secret.

Voir [`docs/LIVE_CONSOLE_FR.txt`](docs/LIVE_CONSOLE_FR.txt).

## Registres partagés

`ezz_admin_registry.gsc` centralise :

- les codes, noms et alias des cartes officielles ;
- la présence des quêtes principales et le minimum de joueurs EE ;
- les rôles minimums des commandes Chat ;
- les métadonnées d’impact gameplay utilisées par la protection des records.

`ezz_admin_map_audit.gsc` ajoute un registre conservateur des capacités déclarées par carte : alimentation, Pack-a-Punch, passages, musique, événements, boss, dog rounds, EE, armes spéciales, Spawn/Late Join et limites connues.

Diagnostics :

```text
ezzregistrystatus
ezzmapaudit
ezzmapaudit full
```

Les états `SUPPORTED`, `PARTIAL`, `DIAGNOSTIC`, `OFFICIAL`, `UNSUPPORTED` et `NOT_DECLARED` sont distincts. L’audit ne transforme jamais une simple déclaration en validation réelle.

Un créateur de carte custom peut partir de [`docs/examples/custom_map_profile.example.gsc`](docs/examples/custom_map_profile.example.gsc). Cet exemple est séparé du runtime et n’est jamais chargé automatiquement.

## État des validations

### Base v2.1.0 déjà validée sur serveur réel

```text
Chargement global des modules      PASS
Identité XUID et rôle Owner        PASS
Stockage sécurisé                  PASS
Chat et menu                       PASS
Communauté / Spawn / Late Join     PASS
Localisation FR / EN / ES          PASS
Préférence manuelle de langue      PASS
GeoIP sans stockage des IP         PASS
Live Console v2.1.0                PASS
Ranks & Records                    PASS
Easter Egg Records                 PASS
Origins EE officiel                PASS
Maps, musique et événements        PASS
Perks, power-ups, rounds, weapons  PASS
Zombies                            PASS
RCON persistant                    PASS
Séparation Chat/commandes          PASS
```

Ces fonctions doivent rester non régressives.

### Validation réelle v2.1.1

```text
Installation Verifier             PASS — 50 PASS / 1 warning initial ; détection net_port renforcée
Lanceur et superviseur             PASS
Client BOIII ouvert avant serveur  PASS
Ban Service / GeoIP / heartbeats   PASS
28 modules GSC                     PASS
Health full                        PASS
Langstats langue/pays              PASS
Map Audit Origins                  PASS
Live Console sombre/read-only      PASS
Suite ezzv211test                   PASS — 88/88, failed=0, skipped=0
```

La modération réelle avec second compte est différée : mute natif, kick, bans, reconnexion, historique réel et menu Moderation ne sont pas déclarés officiellement validés. La matrice statique de hiérarchie, la protection Owner et les tests non destructifs sont cependant validés.

Voir [`docs/VALIDATION_v2.1.1_FR.txt`](docs/VALIDATION_v2.1.1_FR.txt) pour la procédure restante.

## Limites connues

- le blocage du Chat géré par PinteMod est implémenté, mais le blocage de l’affichage natif BOIII pour un joueur mute doit être confirmé avec un second compte ;
- BOIII peut afficher un bloc natif `status` lors d’un nouveau lot de connexions GeoIP ;
- les signaux natifs de fin EE ne sont pas validés sur toutes les cartes ;
- l’audit de carte reflète uniquement les capacités explicitement déclarées et leur état de validation ;
- un ban temporaire peut rester actif jusqu’au retour du Ban Service si celui-ci était arrêté au moment de l’expiration ;
- un déploiement distant nécessite une configuration manuelle LAN/VPN, pare-feu et partage ;
- les fichiers DPAPI doivent être créés sur la machine et le compte Windows qui les utilisent ;
- le noclip n’est pas prioritaire et n’est pas présenté comme corrigé ;
- aucune commande AFK n’est incluse ;
- aucun verrou de transition de manche n’est inclus ;
- les cartes personnalisées nécessitent un profil spécifique ;
- GSC ne fournit pas de renommage atomique réel ; les fichiers `.tmp` et `.bak` réduisent les risques ;
- les outils opérateur nécessitent Windows PowerShell 5.1 ou une version compatible avec les APIs utilisées.

## Contenu du paquet public

```text
README.md                               Documentation anglaise complète
README_FR.md                            Documentation française complète
LICENSE                                 GNU GPL version 3
SECURITY.md                             Politique de sécurité
THIRD_PARTY_NOTICES.md                  Mentions légales et tierces
CHANGELOG_v2.1.1.txt                    Journal de la version
SHA256SUMS.txt                          Empreintes SHA-256
.gitignore                              Exclusions Git
Launch_PinteMod_Server.bat              Lanceur local complet
Launch_PinteMod_Server_Only.bat         Lanceur BOIII uniquement
Launch_PinteMod_Remote_Tools.bat        Outils VM/LAN/VPN
Configure_PinteMod_RCON.bat             Reconfiguration RCON/DPAPI
Verify_PinteMod_Installation.bat        Vérificateur lisible PASS/WARNING/ERROR
Test_PinteMod_v2.1.1.bat                Test Windows global approfondi
boiii/custom_scripts/                   Tous les modules GSC publics
boiii/tools/                            GeoIP, Ban Service, Live Console et superviseur
docs/                                   Architecture, guides, exemples et validation
```

Documents principaux :

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) ;
- [`docs/PACKAGE_MANIFEST_v2.1.1.txt`](docs/PACKAGE_MANIFEST_v2.1.1.txt) ;
- [`docs/MODIFIED_FILES_v2.1.1.txt`](docs/MODIFIED_FILES_v2.1.1.txt);
- [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt) ;
- [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt) ;
- [`docs/HEALTH_VERIFIER_FR.txt`](docs/HEALTH_VERIFIER_FR.txt) ;
- [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt) ;
- [`docs/LANGSTATS_FR.txt`](docs/LANGSTATS_FR.txt) ;
- [`docs/MAP_AUDIT_CUSTOM_FR.txt`](docs/MAP_AUDIT_CUSTOM_FR.txt) ;
- [`docs/LIVE_CONSOLE_FR.txt`](docs/LIVE_CONSOLE_FR.txt) ;
- [`docs/VALIDATION_EE_FR.txt`](docs/VALIDATION_EE_FR.txt) ;
- [`docs/VALIDATION_v2.1.1_FR.txt`](docs/VALIDATION_v2.1.1_FR.txt);
- [`docs/STATIC_VALIDATION_v2.1.1.txt`](docs/STATIC_VALIDATION_v2.1.1.txt).

## Fichiers locaux à ne jamais publier

```text
zone/pintemod_server_secrets.cfg
boiii/tools/*.local.json
boiii/tools/*.secret.txt
boiii/scriptdata/pintemod/
```

Ces chemins sont couverts par les fichiers `.gitignore` fournis.

## Licence

Copyright © 2026 BiereFraiche.

PinteMod est distribué sous **GNU General Public License version 3**. Voir `LICENSE` et `THIRD_PARTY_NOTICES.md`.

Cette licence couvre uniquement les sources propres à PinteMod. Elle n’accorde aucun droit sur Call of Duty: Black Ops III, BOIII/Ezz ou tout composant propriétaire externe.
