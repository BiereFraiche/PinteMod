============================================================
PINTE MOD - SERVEUR SUR PORTABLE / CONTROLE DEPUIS TON PC
TUTO TRES SIMPLE
============================================================

BUT :
- Le PC PORTABLE fait tourner BOIII + PinteMod.
- Ton PC PRINCIPAL affiche la Live Console.
- Ton PC PRINCIPAL a aussi une console RCON pour taper les commandes.
- Les joueurs Internet continuent de rejoindre le serveur normalement.

------------------------------------------------------------
ETAPE 1 - METTRE LE SERVEUR SUR LE PORTABLE
------------------------------------------------------------

1. Copie ton dossier serveur BOIII/PinteMod actuel sur le portable.
2. Garde exactement ta configuration actuelle.
3. Lance le serveur normalement avec ton launcher PinteMod.
4. Si Windows demande l'autorisation pare-feu pour BOIII :
   autorise le RESEAU PRIVE.

Conseil : branche le portable en Ethernet si possible.

------------------------------------------------------------
ETAPE 2 - TROUVER L'IP DU PORTABLE
------------------------------------------------------------

Sur le portable :
1. Appuie sur Windows + R.
2. Tape : cmd
3. Tape : ipconfig
4. Cherche "Adresse IPv4".

Exemple :
192.168.1.90

NOTE CETTE ADRESSE.

Il est fortement conseille de reserver cette IP dans la Freebox
avec un bail DHCP statique, pour qu'elle ne change pas.

------------------------------------------------------------
ETAPE 3 - FREEBOX / SERVEUR PUBLIC
------------------------------------------------------------

Tu as deja des redirections qui rendent ton serveur actuel public.
NE CREE PAS DE NOUVEAUX PORTS AU HASARD.

Dans Freebox OS :
- garde les memes ports ;
- garde les memes protocoles ;
- change seulement l'IP de destination ;
- mets l'IP du PORTABLE a la place de l'ancien PC.

Ton serveur actuel utilise notamment le port BOIII 27018.
La regle correspondante doit donc maintenant pointer vers le portable.

IMPORTANT :
NE REDIRIGE JAMAIS le port Windows SMB 445 vers Internet.
Le partage de fichiers PinteMod doit rester uniquement sur ton reseau local.

------------------------------------------------------------
ETAPE 4 - PARTAGER UNIQUEMENT LES DONNEES PINTE MOD
------------------------------------------------------------

Sur le portable, ouvre :
<ton serveur>\boiii\scriptdata\pintemod

1. Clic droit sur le dossier "pintemod".
2. Proprietes.
3. Onglet Partage.
4. Partage avance.
5. Coche "Partager ce dossier".
6. Nom du partage : PinteModData
7. Permissions : LECTURE uniquement.
8. Valide tout.

Si Windows te demande d'activer la decouverte reseau / partage de fichiers :
active-la uniquement pour le RESEAU PRIVE.

------------------------------------------------------------
ETAPE 5 - VERIFIER DEPUIS TON PC PRINCIPAL
------------------------------------------------------------

Sur ton PC principal :
1. Windows + R.
2. Tape par exemple :

\\192.168.1.90\PinteModData

(remplace 192.168.1.90 par l'IP du portable)

Tu dois voir des dossiers comme :
logs
ranks_v2
localization
etc.

Si Windows demande un identifiant :
utilise le compte Windows du portable et coche la memorisation.

------------------------------------------------------------
ETAPE 6 - INSTALLER LE PACK DE CONTROLE SUR TON PC PRINCIPAL
------------------------------------------------------------

Cree par exemple :
C:\PinteMod_Remote_Control

Mets les 4 fichiers du pack dedans :
- Launch_PinteMod_Remote_Control.bat
- PinteMod_Remote_Control.ps1
- PinteMod_Remote_RCON.ps1
- PinteMod_LiveConsole.ps1

Puis double-clique :
Launch_PinteMod_Remote_Control.bat

Au premier lancement il demande seulement :
1. IP du portable : exemple 192.168.1.90
2. Port BOIII : 27018
3. Partage : exemple \\192.168.1.90\PinteModData
4. Mot de passe RCON

Le mot de passe RCON est chiffre localement par Windows.
Il n'est pas ecrit dans le fichier JSON de configuration.

------------------------------------------------------------
ETAPE 7 - CE QUE TU VAS VOIR
------------------------------------------------------------

Deux fenetres vont s'ouvrir.

1. PINTE MOD LIVE CONSOLE
   - joueurs
   - joins/leaves
   - chat
   - records
   - votes
   - erreurs utiles

2. PINTE MOD REMOTE RCON
   Tu peux taper directement :

   ezzhealth full
   status
   say Bonjour
   ezzcommunitystatus
   map zm_castle

   etc.

La vraie fenetre graphique BOIII reste sur le portable.
La console RCON sert a envoyer les commandes depuis ton PC principal.

------------------------------------------------------------
ETAPE 8 - TEST FINAL
------------------------------------------------------------

Dans Remote RCON tape :

ezzhealth full

Si tu obtiens une reponse : RCON OK.

Ensuite connecte-toi au serveur ou attends un joueur.
La Live Console doit afficher la connexion : Live Console OK.

Enfin demande a quelqu'un hors de chez toi de rejoindre :
si ca fonctionne, Freebox / serveur public OK.

------------------------------------------------------------
SECURITE - 3 REGLES SEULEMENT
------------------------------------------------------------

1. Mot de passe RCON long et unique.
2. Ne partage jamais le mot de passe RCON.
3. Ne redirige jamais le partage Windows/SMB vers Internet.

Le partage PinteModData doit rester sur le reseau local.
============================================================

============================================================
RETOUR RCON PINTE MOD + LIVE CONSOLE
============================================================

Le Remote RCON peut afficher un retour structure pour les commandes PinteMod
qui publient un fichier de feedback sous le partage PinteModData.

Commande actuellement prise en charge :

  ezzpausestatus

Le serveur ecrit :

  boiii\scriptdata\pintemod\remote\feedback.latest.txt

Le PC operateur lit ce fichier en lecture seule apres l'envoi RCON. Aucun port
supplementaire n'est ouvert et le mot de passe RCON n'est jamais ecrit dans ce
feedback.

La Live Console peut aussi afficher les evenements de pause et l'echo local des
commandes RCON non sensibles :

  [RCON] SEND | ezzpausestatus
  [PAUSE] STATUS | active=true | remaining 120s | pauses 1/2 | proposals 1

Le journal RCON local est cree dans :

  runtime\PinteMod_Remote_RCON.audit.log

Les commandes contenant des mots de passe, secrets ou tokens ne sont pas
journalisees. Le partage SMB doit rester LAN/VPN uniquement. Ne jamais exposer
TCP 445 sur Internet.
