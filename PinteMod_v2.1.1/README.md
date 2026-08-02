# PinteMod v2.1.1

[Documentation française](README_FR.md)

PinteMod is a server-side administration, community, localization and records framework for **Call of Duty: Black Ops III Zombies** dedicated servers running **BOIII/Ezz**.

Created and maintained by **BiereFraiche**, with development assistance from ChatGPT.

Players do not need to install a client mod. PinteMod runs from the dedicated server's `boiii/custom_scripts/` directory and provides optional Windows operator tools for GeoIP localization, persistent XUID bans and a read-only Live Console.

## Highlights in v2.1.1

- global GSC diagnostics with `ezzhealth` and `ezzhealth full`;
- Windows installation verifier with clear `PASS`, `WARNING` and `ERROR` results;
- aggregate `ezzv211test suite` and `Test_PinteMod_v2.1.1.bat` validation entry points;
- anonymized population and language statistics through `ezzlangstats`;
- centralized XUID moderation for mute, unmute, kick, bans and player history;
- strict Owner/Admin/Moderator/Helper/User hierarchy, logged denials and protected bootstrap Owner;
- role- and target-filtered **Moderation** menu category;
- conservative active-map compatibility audit through `ezzmapaudit`;
- documented custom-map profile example kept outside the runtime;
- dark read-only Live Console with Warn/Mute/Ban filters and a player dashboard;
- secret-free local heartbeats for Ban Service, GeoIP, Live Console and the supervisor;
- discreet background supervisor with failures preserved in operator logs;
- unchanged v2.1.0 foundations already validated on the real server: XUID identity, storage, community, localization, GeoIP, Ranks, EE, maps, music, events and gameplay modules.

The **stable v2.1.1** release consolidates every fix found during real-server validation. Startup, Windows tools, all 28 GSC modules, Health, Langstats, Map Audit, the Live Console and the non-destructive `88/88` suite are validated on the real server. The Live Console was also validated with dynamic presence and suppression of repeated empty-player refreshes. Second-account moderation actions remain intentionally unclaimed.

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

1. fully stop BOIII and every PinteMod tool;
2. back up `boiii/custom_scripts/` and `boiii/scriptdata/pintemod/`;
3. remove old PinteMod scripts from `boiii/custom_scripts/` to avoid duplicate modules;
4. extract the archive directly into the directory that already contains `boiii` and `zone`;
5. confirm that your BOIII installation provides `hotfix.gsc`; it is required locally but never distributed by PinteMod;
6. run `Verify_PinteMod_Installation.bat` and resolve every `ERROR`;
7. run `Launch_PinteMod_Server.bat` from the `UnrankedServer` root;
8. on first launch, set the local RCON password and select the real BOIII launcher;
9. run `Test_PinteMod_v2.1.1.bat`, then complete the grouped server validation before public use.

Expected layout:

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
│   │   └── other PinteMod modules
│   └── tools/
├── docs/
└── zone/
```

`hotfix.gsc` is intentionally not included: it belongs to the BOIII compatibility environment, not PinteMod.

See [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt) and [`docs/HEALTH_VERIFIER_FR.txt`](docs/HEALTH_VERIFIER_FR.txt).

## Launch modes

### Local all-in-one

```text
Launch_PinteMod_Server.bat
```

Recommended when BOIII, Ban Service, GeoIP and Live Console run on the same machine. BOIII and Live Console remain visible; Ban Service, GeoIP and the supervisor run in the background.

The supervisor watches BOIII and its child tools, blocks duplicate instances and shuts them down cleanly. It no longer leaves a permanent extra window. Failures remain available in:

```text
boiii/tools/runtime/PinteMod_Supervisor.log
boiii/tools/runtime/PinteMod_Supervisor.bootstrap.error.log
```

### Server only

```text
Launch_PinteMod_Server_Only.bat
```

Starts BOIII without GeoIP, Ban Service or Live Console. Health diagnostics will report these tools as absent or configured but inactive.

### VM, LAN or remote tools host

```text
Launch_PinteMod_Remote_Tools.bat
```

Starts Ban Service, GeoIP and Live Console from another Windows host with RCON access and access to `boiii/scriptdata/pintemod`.

The local default uses `127.0.0.1`. For VM, LAN or VPN use, select a stable address, restrict firewall/share permissions, and recreate DPAPI secrets on the Windows machine and account that run the tools. Copied DPAPI files cannot be decrypted by another account or machine.

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
| 4 | Owner | All permissions, role management, protected resets and actions against lower roles |
| 3 | Admin | Moderation of Moderator, Helper and User; maps, rounds, Events and server maintenance |
| 2 | Moderator | Routine match administration; no persistent sanctions in v2.1.1 |
| 1 | Helper | Limited assistance and diagnostics; no persistent sanctions |
| 0 | User | Public menu, votes, Late Join, language, ranks and public records |

Sanction hierarchy rules:

- a role cannot sanction an equal or higher role;
- self-sanction is rejected;
- bootstrap Owner `9cf34426f668fb8b` is protected;
- denied attempts are logged;
- display names are never persistence keys.

Persistent role changes are stored locally in:

```text
boiii/scriptdata/pintemod/identity/roles.json
```

See [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt).

## Chat commands

The primary prefix is `.`. Legacy prefix `!` remains accepted.

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

Role-filtered diagnostics and statistics:

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

Role-filtered moderation:

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

Other staff examples:

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

The full console reference is in [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt).

## Menu

Open the menu with:

```text
.menu
```

HUD controls:

- **Action Slot 2 / key 2:** move up;
- **Action Slot 3 / key 3:** move down;
- **Use / Reload:** select;
- **Melee:** back or close.

Sections include Community/Players, Administration, **Moderation**, Perks, Weapons, Rounds, Power-Ups, Fun and Ranks & Records.

The Moderation category exposes, according to role:

```text
Mute
Unmute
Kick
Temporary Ban
Permanent Ban
Ban Information
Player History
```

Targets are filtered before display according to hierarchy. Actions carry XUID/client selectors internally; names are display labels only. The bootstrap Owner and equal-or-higher roles cannot become valid sanction targets.

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

v2.1.1 keeps the existing ban system and adds a shared hierarchy, history, mute and direct-kick layer.

Main console commands:

```text
ezzmute <PlayerName|BOIII_XUID|ClientNumber> [reason]
ezzunmute <PlayerName|BOIII_XUID|ClientNumber>
ezzkick <PlayerName|BOIII_XUID|ClientNumber> [reason]
ezzban <PlayerName|BOIII_XUID|ClientNumber> <duration|permanent> [reason]
ezzunban <PlayerName|BOIII_XUID|ClientNumber>
ezzbaninfo <PlayerName|BOIII_XUID|ClientNumber>
ezzhistory <PlayerName|BOIII_XUID|ClientNumber>
```

Accepted durations include:

```text
30m  2h  7d  permanent
```

Temporary bans use UTC and are maintained by `PinteMod_Ban_Service.ps1`. Banning a connected player marks the current match `UNRANKED`.

XUID-indexed history summarizes at least:

```text
Kicks
Mutes / Unmutes
Temporary bans
Permanent bans
Last action
```

No IP address is stored. Local data lives under:

```text
boiii/scriptdata/pintemod/bans/
boiii/scriptdata/pintemod/moderation/
```

PinteMod mute blocks Chat routes handled by the framework and persists its state. Suppression of BOIII's separate native Chat display must be confirmed in the two-account test and is not claimed as validated in this TEST build.

See [`docs/BANNISSEMENTS_FR.txt`](docs/BANNISSEMENTS_FR.txt) and [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt).

## Localization and GeoIP

Fully integrated languages:

```text
fr  Français
en  English
es  Español
```

Manual choice has priority over GeoIP and is restored by XUID:

```text
.lang fr
.lang en
.lang es
.lang auto
```

The GeoIP bridge temporarily reads a new connection address through RCON, resolves country/language in memory, and does not persist that address. BOIII may still print the raw `status` response in its native console.

v2.1.1 adds aggregate counters without a public player/country association:

```text
ezzlangstats
ezzlangstats countries
ezzlangstats languages
ezzlangstats reset prepare
ezzlangstats reset confirm <token>
```

Only country codes, selected languages and connection counts are stored. This system keeps neither IP lists nor unique-XUID lists. Results can guide a future complete German, Brazilian Portuguese, Italian, Polish or Russian translation; no partial translation is shipped.

See [`docs/LOCALISATION_GEOIP_FR.txt`](docs/LOCALISATION_GEOIP_FR.txt) and [`docs/LANGSTATS_FR.txt`](docs/LANGSTATS_FR.txt).

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

Official writes are controlled **per map**. A profile remains diagnostic until its native main-quest completion signal is confirmed on a real server. The Origins profile is validated for official writes since v2.1.0 and remains unchanged in v2.1.1.

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

Normal Chat logging is enabled in the v2.1.1 public configuration so the Live Console can display player messages and moderation evidence. Server owners should disclose that policy to players where required and can disable it in `ezz_admin_config.gsc`. GUID logging remains disabled. XUID/GUID redaction settings are applied centrally to managed log text.

## Read-only Live Console

The local all-in-one and remote-tools launchers start Live Console automatically. It can also be launched directly with:

```text
boiii\tools\Launch_PinteMod_LiveConsole.bat
```

Live Console v2.1.1:

- forces a dark/black presentation;
- detects the active map/session manifest;
- separates normal Chat messages from commands;
- follows connections, Community, votes, kicks, warnings, mutes, bans, Identity, Ranks, EE, Storage and Localization;
- displays a connected-player dashboard with abbreviated XUID, role, language, country, presence, mute/ban, Ranked state and recent event;
- displays no IP and no GUID;
- throttles refreshes and redraws the dashboard only when content changes;
- follows supervisor, Ban Service and GeoIP failures;
- provides filters, search, export and active-folder access;
- can play a short critical-error sound;
- archives completed sessions by system date;
- **creates no RCON client and never sends a command to the server**.

Secret-free local heartbeats let `ezzhealth` distinguish connected, absent, stopped and failed tools.

See [`docs/LIVE_CONSOLE_FR.txt`](docs/LIVE_CONSOLE_FR.txt).

## Shared registries

`ezz_admin_registry.gsc` centralizes:

- official map codes, names and aliases;
- main-quest presence and EE minimum-player counts;
- minimum Chat roles;
- gameplay-impact metadata used by record protection.

`ezz_admin_map_audit.gsc` adds a conservative per-map capability registry: power, Pack-a-Punch, passages, music, events, bosses, dog rounds, EE, special weapons, Spawn/Late Join and known limitations.

Diagnostics:

```text
ezzregistrystatus
ezzmapaudit
ezzmapaudit full
```

`SUPPORTED`, `PARTIAL`, `DIAGNOSTIC`, `OFFICIAL`, `UNSUPPORTED` and `NOT_DECLARED` remain distinct states. The audit never turns a declaration into a real-server validation claim.

Custom-map authors can start from [`docs/examples/custom_map_profile.example.gsc`](docs/examples/custom_map_profile.example.gsc). The example is outside runtime and never loaded automatically.

## Validation status

### v2.1.0 foundation already validated on the real server

```text
Global module loading              PASS
XUID identity and Owner role       PASS
Protected storage                  PASS
Chat and menu                      PASS
Community / Spawn / Late Join      PASS
FR / EN / ES localization          PASS
Manual language preference         PASS
GeoIP without IP storage           PASS
v2.1.0 Live Console                PASS
Ranks & Records                    PASS
Easter Egg Records                 PASS
Official Origins EE profile        PASS
Maps, music and events             PASS
Perks, power-ups, rounds, weapons  PASS
Zombies                            PASS
Persistent RCON                    PASS
Chat/command separation            PASS
```

These features must remain regression-free.

### v2.1.1 real-server validation

```text
Installation Verifier             PASS — 50 PASS / 1 initial warning; net_port detection strengthened
Launcher and supervisor            PASS
BOIII client open before server    PASS
Ban Service / GeoIP / heartbeats   PASS
28 GSC modules                     PASS
Health full                        PASS
Language/country statistics        PASS
Origins Map Audit                  PASS
Dark read-only Live Console        PASS
ezzv211test suite                  PASS — 88/88, failed=0, skipped=0
```

Real second-account moderation is deferred: native mute suppression, kick, bans, reconnect behavior, real history and the Moderation menu are not officially claimed as validated. The static hierarchy matrix, Owner protection and non-destructive tests are validated.

See [`docs/VALIDATION_v2.1.1_FR.txt`](docs/VALIDATION_v2.1.1_FR.txt) for the remaining procedure.

## Known limitations

- framework-managed Chat blocking is implemented, but suppression of BOIII's native Chat display for a muted player must be confirmed with a second account;
- BOIII may print a native `status` block during a new GeoIP connection batch;
- native EE completion signals are not validated on every map;
- map audit only reports explicitly declared capabilities and their validation state;
- a temporary ban may remain active until Ban Service returns if the service was stopped at expiry time;
- remote deployment requires explicit LAN/VPN, firewall and share configuration;
- DPAPI files must be created by the Windows account and machine that use them;
- noclip is not a priority and is not presented as fixed;
- no AFK command is included;
- no round-transition lock is included;
- custom maps need their own profiles;
- GSC has no guaranteed atomic rename; `.tmp` and `.bak` reduce recovery risk;
- operator tools require Windows PowerShell 5.1 or a compatible environment.

## Public package contents

```text
README.md                               Complete English documentation
README_FR.md                            Complete French documentation
LICENSE                                 GNU GPL version 3
SECURITY.md                             Security policy
THIRD_PARTY_NOTICES.md                  Legal and third-party notices
CHANGELOG_v2.1.1.txt                    Release changelog
SHA256SUMS.txt                          SHA-256 checksums
.gitignore                              Git exclusions
Launch_PinteMod_Server.bat              Local all-in-one launcher
Launch_PinteMod_Server_Only.bat         BOIII-only launcher
Launch_PinteMod_Remote_Tools.bat        VM/LAN/VPN tools launcher
Configure_PinteMod_RCON.bat             RCON/DPAPI reconfiguration
Verify_PinteMod_Installation.bat        PASS/WARNING/ERROR verifier
Test_PinteMod_v2.1.1.bat                Deep Windows integration test
boiii/custom_scripts/                   Public GSC modules
boiii/tools/                            GeoIP, Ban Service, Live Console and supervisor
docs/                                   Architecture, guides, examples and validation
```

Main documents:

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md);
- [`docs/PACKAGE_MANIFEST_v2.1.1.txt`](docs/PACKAGE_MANIFEST_v2.1.1.txt);
- [`docs/MODIFIED_FILES_v2.1.1.txt`](docs/MODIFIED_FILES_v2.1.1.txt);
- [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt);
- [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt);
- [`docs/HEALTH_VERIFIER_FR.txt`](docs/HEALTH_VERIFIER_FR.txt);
- [`docs/MODERATION_FR.txt`](docs/MODERATION_FR.txt);
- [`docs/LANGSTATS_FR.txt`](docs/LANGSTATS_FR.txt);
- [`docs/MAP_AUDIT_CUSTOM_FR.txt`](docs/MAP_AUDIT_CUSTOM_FR.txt);
- [`docs/LIVE_CONSOLE_FR.txt`](docs/LIVE_CONSOLE_FR.txt);
- [`docs/VALIDATION_EE_FR.txt`](docs/VALIDATION_EE_FR.txt);
- [`docs/VALIDATION_v2.1.1_FR.txt`](docs/VALIDATION_v2.1.1_FR.txt);
- [`docs/STATIC_VALIDATION_v2.1.1.txt`](docs/STATIC_VALIDATION_v2.1.1.txt).

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
