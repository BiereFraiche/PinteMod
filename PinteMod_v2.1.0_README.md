# PinteMod v2.1.0

[Documentation française](README_FR.md)

PinteMod is a server-side administration, community, localization and records framework for **Call of Duty: Black Ops III Zombies** dedicated servers running **BOIII/Ezz**.

Created and maintained by **BiereFraiche**, with development assistance from ChatGPT.

Players do not need to install a client mod. PinteMod runs from the dedicated server's `boiii/custom_scripts/` directory and provides optional Windows operator tools for GeoIP localization, persistent XUID bans and a read-only Live Console.

## Highlights in v2.1.0

- Validated public Spawn / Late Join workflow
- Stable permissions and persistent data keyed by `BOIII_XUID`
- French, English and Spanish per-player localization
- Manual language selection with optional GeoIP country detection
- No persistent player-IP storage in PinteMod tools
- Persistent local RCON setup protected with Windows DPAPI
- Clean read-only Live Console with separate Chat and command streams
- Permanent and UTC-based temporary XUID bans for Owner/Admin
- Official Origins EE record profile and short `ezzeeval` validation alias
- Session-based managed logs with privacy controls and rotation
- Ranks, map records and Easter Egg records on isolated XUID databases
- Uniform and reduced module startup output
- Local, server-only and remote-tools launch modes
- Root-level all-in-one launcher for direct `UnrankedServer` installation

## Supported maps

### BO3 core and DLC

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

Custom maps may load the generic framework, but map-specific unlocks, weapons, music, events and quest profiles are not guaranteed.

## Installation

1. Fully stop BOIII and every PinteMod tool.
2. Back up the current `boiii/custom_scripts/` and `boiii/scriptdata/pintemod/` folders.
3. Remove previous PinteMod scripts from `boiii/custom_scripts/` to prevent duplicate modules.
4. Extract the archive directly into the directory that already contains `boiii` and `zone`.
5. Run `Launch_PinteMod_Server.bat` from the `UnrankedServer` root.
6. On first launch, configure a local RCON password and select the existing BOIII server launcher.
7. Run the recommended post-installation verification before opening the server publicly.

Expected layout:

```text
<UnrankedServer>/
├── Launch_PinteMod_Server.bat
├── Launch_PinteMod_Server_Only.bat
├── Launch_PinteMod_Remote_Tools.bat
├── boiii/
│   ├── custom_scripts/
│   │   ├── ezz_admin_00_banner.gsc
│   │   ├── ezz_admin_01_main.gsc
│   │   ├── ...
│   │   └── ezz_admin_zombies.gsc
│   └── tools/
├── docs/
└── zone/
```

`hotfix.gsc` is intentionally not included. It belongs to the BOIII compatibility environment, not to PinteMod.

See [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt) for the detailed installation procedure.

## Launch modes

### Local all-in-one

```text
Launch_PinteMod_Server.bat
```

Starts the Ban Service, BOIII server, GeoIP bridge and Live Console. The first launch creates machine-local configuration; later launches reuse it.

### Server only

```text
Launch_PinteMod_Server_Only.bat
```

Starts BOIII using the saved local launcher configuration without starting the operator tools.

### VM, LAN or remote tools host

```text
Launch_PinteMod_Remote_Tools.bat
```

Starts the Ban Service, GeoIP bridge and Live Console from another Windows machine that can access both RCON and `boiii/scriptdata/pintemod`.

The default setup assumes every component runs on the same machine and therefore uses `127.0.0.1`. A VM host, another LAN machine or a remote administration host must use a stable LAN/VPN address, suitable share permissions and a restricted firewall rule. DPAPI secrets are tied to the Windows account and machine that created them.

See [`docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt`](docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt).

## Default Owner

The public package contains one bootstrap Owner:

```text
Display metadata: BiereFraiche
BOIII_XUID: 9cf34426f668fb8b
Role: owner
```

No Admin, Moderator or Helper is preconfigured. No runtime role database, player profile, record, ban database, vote, log or server backup is distributed.

Other server owners should replace or remove this XUID in `boiii/custom_scripts/ezz_admin_config.gsc`, or assign their own persistent Owner from the dedicated console:

```text
ezzidsetrole <PlayerName|BOIII_XUID|ClientNumber> owner
```

## Stable identity and secure targeting

Authentication, permissions, language preferences, bans and persistent records use the hexadecimal value exposed by BOIII's stable XUID interface.

Console commands can target a connected player using:

```text
<PlayerName|BOIII_XUID|ClientNumber>
```

Examples:

```text
ezzidentity 9cf34426f668fb8b
ezzidentity #0
ezzidentity client:0
ezzidentity BiereFraiche
```

Display names are only an unambiguous convenience fallback. When two connected players share the same display name, PinteMod rejects the name selector and requires an XUID or client number.

Chat and menu actions transport an XUID or client slot internally instead of trusting a raw display name. Unsafe command separators and line breaks are rejected before server command execution.

## Roles

| Level | Role | Typical access |
|---:|---|---|
| 4 | Owner | Permission management, bans, revive and protected maintenance |
| 3 | Admin | Bans, maps, rounds, unlocks, Events and server-impact commands |
| 2 | Moderator | Gameplay administration, weapons, perks and points |
| 1 | Helper | Read-only diagnostics and limited player assistance |
| 0 | User | Public menu, votes, late join, ranks and public records |

Persistent runtime role changes are stored locally in:

```text
boiii/scriptdata/pintemod/identity/roles.json
```

## Chat commands

The primary prefix is `.`. The legacy `!` prefix remains accepted.

Public examples:

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
.votekick <player> [reason]
.rank
.ranks
.record
.records 2
.eerecord
.eerecords 4
```

Staff examples depend on the assigned role:

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
.ban <player|xuid> 2h reason
.unban <player|xuid>
.baninfo <player|xuid>
.banlist
```

The complete dedicated-console reference is in [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt).

## Menu

Open the menu with:

```text
.menu
```

Current controls shown by the server HUD:

- **Action Slot 2 / key 2:** move up
- **Action Slot 4 / key 4:** move down
- **Use / Reload:** select
- **Melee:** back or close

Sections include Community / Players, Administration, Perks, Weapons, Rounds, Power-Ups, Fun and Rankings & Records. Content is filtered by role and active map. Internal target values remain XUID/client selectors; display names are labels only.

## Community features

- Welcome HUD and public reminders
- Public late join through `.spawn` or Player Menu
- Administrative spectator respawn
- Owner-only native revive for players in last stand
- Next-map vote without interrupting the current match
- Restart vote with warning
- Protected vote-kick with reconnect blocking
- Automatic map change after the match
- Presence tracking that survives reconnects and name changes during a map
- Live connection, vote and moderation reports

### Spawn, respawn and revive

These operations are intentionally separate:

- `ezzjoin` / `.spawn`: public Late Join for an eligible spectator
- `ezzspawn`: administrative spectator respawn
- `ezzrevive`: native last-stand revive; Chat/menu access is Owner-only

## Persistent XUID bans

PinteMod bans complement kick and vote-kick. They are keyed by `BOIII_XUID`; no player IP is stored.

Console commands:

```text
ezzban <Player|BOIII_XUID|ClientNumber> [30m|2h|7d|4w|perm] [reason]
ezzunban <Player|BOIII_XUID|ClientNumber>
ezzbaninfo <Player|BOIII_XUID|ClientNumber>
ezzbanlist
ezzbanstatus
ezzbantest suite
```

Owner/Admin Chat commands:

```text
.ban <Player|BOIII_XUID> [duration] [reason]
.unban <Player|BOIII_XUID>
.baninfo <Player|BOIII_XUID>
.banlist
```

Authorization rules:

- Owner can ban Admin, Moderator, Helper and User, but not another Owner.
- Admin can ban Moderator, Helper and User, but not Owner or Admin.
- Self-ban is rejected.
- The bundled bootstrap Owner XUID is protected.

Temporary expirations are maintained in UTC by `PinteMod_Ban_Service.ps1` and survive map changes, reconnects and server restarts while the service is available. A connected-player ban marks the current match UNRANKED.

Ban data is stored locally under:

```text
boiii/scriptdata/pintemod/bans/
```

See [`docs/BANNISSEMENTS_FR.txt`](docs/BANNISSEMENTS_FR.txt).

## Localization and GeoIP

Integrated languages:

```text
fr  Français
en  English
es  Español
```

A player's manual choice has priority over GeoIP and is restored by XUID:

```text
.lang fr
.lang en
.lang es
.lang auto
```

The GeoIP bridge reads a fresh connection address through RCON, resolves a country/language in memory and does not persist that address. PinteMod stores only XUID, country code where applicable and language preference. BOIII itself may still echo the raw `status` response in its native server console.

The bridge batches pending requests and reuses a validated short-lived status snapshot to reduce native console noise. Additional languages can be added later according to the countries observed on the server.

See [`docs/LOCALISATION_GEOIP_FR.txt`](docs/LOCALISATION_GEOIP_FR.txt).

## Ranks & Records

Ranks use the isolated v2 storage root:

```text
boiii/scriptdata/pintemod/ranks_v2/
```

Features include:

- playtime and session statistics by XUID
- best round and global activity position
- Top 5 records per map and 1P/2P/3P/4P category
- at least 70% match presence required for record participation
- highest round first, then shortest elapsed time as tie-breaker
- connected and eligible disconnected participants handled by XUID
- automatic UNRANKED protection after gameplay-affecting administration
- rollback of personal/team records created earlier in the same match
- audit, backup and protected reset commands

Public commands:

```text
.rank
.ranks
.record
.records [1-4]
```

Maintenance:

```text
ezzrankstatus
ezzranktest suite <selector>
ezzrankaudit
ezzrankbackup [label]
ezzrankreset prepare
ezzrankreset confirm <token>
```

No legacy name-based records are imported automatically.

## Easter Egg Records

EE storage uses a separate clean v2 root:

```text
boiii/scriptdata/pintemod/easter_eggs_v2/
```

The structural system records diagnostic candidates with completion XUIDs, active holder XUIDs, excluded participants, elapsed time, player category, ranked/unranked status, acceptance/rejection reason and an anti-duplicate signature.

Official writes are controlled **per map**. A profile remains diagnostic until its native main-quest completion signal is confirmed on a real server. The Origins profile is validated for official writes in v2.1.0.

Useful commands:

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

Do not enable official writes for an unvalidated map. See [`docs/VALIDATION_EE_FR.txt`](docs/VALIDATION_EE_FR.txt).

## Safe JSON storage

Identity, Ranks and EE registries use `ezz_admin_storage.gsc`.

For each protected JSON write, PinteMod:

1. writes a `.tmp` file;
2. reads it back and validates it;
3. preserves the previous valid file as `.bak`;
4. writes and verifies the active file;
5. restores the previous version when active verification fails.

Invalid JSON found during loading is copied to:

```text
boiii/scriptdata/pintemod/backups/corrupt/
```

A valid `.bak` is restored when available. This is a recoverable two-phase strategy using the file helpers exposed by BOIII, not a filesystem-level atomic rename.

Diagnostics:

```text
ezzstoragestatus
ezzstoragetest suite
```

## Managed logs and privacy

Current public defaults include:

```gsc
level.pintemod_log_chat_messages = true;
level.pintemod_log_xuids = true;
level.pintemod_log_guids = false;
level.pintemod_log_max_size_kb = 2048;
```

Logs are grouped by map/session under:

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

Normal Chat logging is enabled in the v2.1.0 public configuration so the Live Console can display player messages and moderation evidence. Server owners should disclose that policy to players where required and can disable it in `ezz_admin_config.gsc`. GUID logging remains disabled. XUID/GUID redaction settings are applied centrally to managed log text.

## Read-only Live Console

The all-in-one and remote-tools launchers start the Live Console automatically. It can also be launched directly with:

```text
boiii\tools\Launch_PinteMod_LiveConsole.bat
```

The Live Console:

- detects the active PinteMod map/session manifest
- follows Chat and commands separately
- follows joins, Community, votes, kicks, bans, Identity, Ranks, EE, Storage and Localization logs
- highlights failures, corrupt data and important moderation/record events
- hides routine diagnostic noise by default
- exposes diagnostics on demand with `D`
- provides category filters, search, export and active-log-folder opening
- optionally plays a short sound for critical errors
- archives completed sessions by operating-system date
- never sends a command to the game server

The `N` filter displays ban and expiration events. Keyboard help is displayed at startup and with `H`.

## Shared registries

`ezz_admin_registry.gsc` centralizes:

- official map codes and display names
- map aliases and collection names
- main-quest presence and minimum EE player counts
- Chat command minimum roles
- gameplay-impact metadata used by Ranks and record protection

Diagnostics:

```text
ezzregistrystatus
```

## Validation status

The following v2.1.0 base behavior was validated on a real dedicated BOIII server:

```text
Community                  24/24 PASS
Localization               14/14 PASS
Spawn / Late Join          PASS
GeoIP local and external   PASS
COUNTRY_ANNOUNCED          PASS
Live Console Chat          PASS
Chat / command separation  PASS
Persistent RCON            PASS
g_password remains empty   PASS
Automatic root detection   PASS
Official Origins EE        PASS
ezzeeval alias              PASS
Clean startup output       PASS
```

The new Ban Service, temporary-ban expiration and Server Only / Remote Tools launch modes were added after that base validation. Before public deployment, run:

```text
ezzbantest suite
```

Expected static result:

```text
[PinteMod Ban] RESULT 8/8 PASS | failed=0
```

Then perform the real reconnect, expiration and hierarchy tests in [`docs/BANNISSEMENTS_FR.txt`](docs/BANNISSEMENTS_FR.txt) and [`docs/VALIDATION_v2.1.0_FR.txt`](docs/VALIDATION_v2.1.0_FR.txt).

## Known limitations

- BOIII may print one native `status` block for a fresh GeoIP connection batch.
- Native EE completion signals are not yet validated on every map.
- Temporary bans may remain active until the Ban Service runs again if that service was stopped at the expiration time.
- Remote deployment requires manual LAN/VPN, firewall and share configuration.
- Noclip is intentionally unavailable.
- AFK commands are intentionally excluded.
- Round-transition locking is intentionally excluded.
- Custom maps require their own profiles.
- GSC cannot provide a true filesystem atomic rename; `.tmp` verification and `.bak` recovery mitigate interrupted writes.
- The Windows operator tools require Windows PowerShell.

## Public package contents

```text
Launch_PinteMod_Server.bat             Local all-in-one launcher
Launch_PinteMod_Server_Only.bat        BOIII-only launcher
Launch_PinteMod_Remote_Tools.bat       VM/LAN/VPN tools launcher
boiii/custom_scripts/                   PinteMod GSC runtime source
boiii/tools/                            GeoIP, Ban Service and Live Console
docs/                                   Installation, architecture and validation docs
README.md                               Main GitHub documentation
README_FR.md                            Complete French documentation
SECURITY.md                             GitHub-recognized security policy
THIRD_PARTY_NOTICES.md                  Legal and third-party notices
CHANGELOG_v2.1.0.txt                    Release changelog
LICENSE                                 GNU GPL version 3
SHA256SUMS.txt                          Release file checksums
```

Detailed architecture and package inventory are under [`docs/`](docs/):

- `ARCHITECTURE.md`
- `PACKAGE_MANIFEST_v2.1.0.txt`
- `INSTALLATION_FR.txt`
- `COMMANDES_CONSOLE_FR.txt`
- `DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt`
- `LOCALISATION_GEOIP_FR.txt`
- `BANNISSEMENTS_FR.txt`
- `VALIDATION_EE_FR.txt`
- `VALIDATION_v2.1.0_FR.txt`

## Local-only files

Never publish or include in a public release:

```text
zone/pintemod_server_secrets.cfg
boiii/tools/*.local.json
boiii/tools/*.secret.txt
boiii/scriptdata/pintemod/
```

These paths are covered by the supplied `.gitignore` files.

## License

Copyright © 2026 BiereFraiche.

PinteMod is licensed under the **GNU General Public License version 3**. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

This license covers PinteMod's own source. It does not grant rights to Call of Duty: Black Ops III, BOIII/Ezz or any external proprietary component.
