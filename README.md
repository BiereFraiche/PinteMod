# PinteMod v2.1.1

[Documentation française](README_FR.md)

PinteMod is a server-side administration, community, localization and records framework for **Call of Duty: Black Ops III Zombies** dedicated servers running **BOIII/Ezz**.

Created and maintained by **BiereFraiche**, with development assistance from ChatGPT.

Players do not need to install a client mod. PinteMod runs from the dedicated server's `boiii/custom_scripts/` directory and provides optional Windows operator tools for GeoIP localization, persistent XUID bans, Live Console monitoring and LAN RCON administration.

> **Stable baseline:** PinteMod **v2.1.1 FINAL** remains the stable release baseline.
> **Post-v2.1.1 experimental additions:** Community Soft Pause v0.3, Remote LAN Control feedback and Pause events in Live Console.
> They are intentionally documented separately so experimental work is not confused with the frozen v2.1.1 stable core.

## PinteMod Control Center

Prefer a modern graphical operator experience? **[PinteMod Control Center v2.2.0](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.2.0)** is the official companion Windows application for PinteMod.

[![Download Control Center](https://img.shields.io/badge/Download-Control%20Center%20v2.2.0-168BFF)](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.2.0)
[![Control Center tests](https://img.shields.io/badge/tests-460%20passing-24C875)](https://github.com/BiereFraiche/PinteModControlCenter)

[![PinteMod Control Center dashboard](https://raw.githubusercontent.com/BiereFraiche/PinteModControlCenter/main/design/pintemod-control-center-reference.png)](https://github.com/BiereFraiche/PinteModControlCenter)

It provides:

- a dark, responsive dashboard with up to eight isolated server tabs;
- map, session, service, player, Rank, record and structured-log views;
- explicit local or read-only LAN data sources, with no automatic installation discovery;
- manual allowlisted RCON diagnostics and confirmed server/player actions;
- BOIII_XUID-based targeting, DPAPI-protected RCON secrets and conservative no-retry delivery rules;
- per-server visual accents and a color-aware public server-name editor.

Real controls appear only when the installed PinteMod runtime publishes fresh, compatible capabilities. Unsupported or unverifiable controls remain disabled or simulated. The Control Center does not start or stop BOIII and does not rewrite PinteMod server files.

- [Download PinteMod Control Center v2.2.0](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.2.0)
- [View its source and security model](https://github.com/BiereFraiche/PinteModControlCenter)

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

The **stable v2.1.1** release consolidates every fix found during real-server validation. Startup, Windows tools, all 28 stable GSC modules, Health, Langstats, Map Audit, Live Console and the non-destructive `88/88` suite are validated on the real server. Second-account moderation actions remain intentionally unclaimed.

## Post-v2.1.1 experimental additions

### Community Soft Pause v0.3

Experimental module:

```text
boiii/custom_scripts/ezz_admin_pause_community_experimental.gsc
```

Public commands:

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

Current rules:

- `.pause` / `!pause` starts a **20-second majority vote**;
- the requester automatically votes YES;
- if accepted, the game enters a cooperative soft pause for a maximum of **180 real seconds**;
- `.resume` / `!resume` starts a **15-second majority vote** for early resume;
- each stable BOIII XUID may propose a pause only once per map/match;
- a maximum of **2 successful pauses** is allowed per map/match;
- a 60-second cooldown follows a completed pause vote;
- a 30-second cooldown follows a completed/failed resume vote;
- a pause cannot start while a player is in last stand/downed state;
- spectators cannot start pause/resume votes.

During the soft pause PinteMod:

- freezes active player controls;
- temporarily enables native player invulnerability;
- preserves/restores health and max health around the pause;
- increments BO3's native zombie-ignore counter;
- sets `ai_DisableSpawn=1` while preserving its previous value;
- blocks PinteMod spectator respawn paths `ezzspawn` and `ezzjoin`;
- keeps RCON/server processing available;
- displays 30-second and 10-second automatic-resume warnings;
- exposes `ezzresume` as an emergency server/admin resume command.

The tested pause core, 180-second timer, temporary protection, spectator respawn blocking, early resume and Remote RCON feedback were validated on the real dedicated server for the tested scenarios. The v0.3 periodic reminder is a later small addition and should still receive a quick compile/load check before being considered validated.

This remains a **soft pause**, not an engine pause. BO3 map scripts, Easter Egg scripts, trap timers, quest timers and other independent script threads are not guaranteed to stop.

### Periodic pause reminder

v0.3 includes a lightweight public reminder:

```text
Besoin d'une pause ? .pause ou !pause lance un vote (3 min max).
```

The first reminder is scheduled after approximately **5 minutes**, then approximately every **12 minutes**, only while:

- at least one player is connected;
- no pause is active;
- no Community vote is active;
- the match has not already reached the two-successful-pause limit.

It is deliberately infrequent to avoid Chat spam.

### Remote LAN Control and PinteMod feedback

The desktop/operator PC can run a separate LAN control pack while BOIII remains on the server/laptop.

Recommended layout:

```text
boiii/tools/
├── Launch_PinteMod_Remote_Control.bat
├── PinteMod_Remote_Control.ps1
├── PinteMod_Remote_RCON.ps1
├── PinteMod_LiveConsole.ps1
└── TUTO_PINTE_MOD_REMOTE_LAN_FR.txt
```

The Remote Control files intentionally live in `boiii/tools/` alongside the other PinteMod Windows operator tools. The same `PinteMod_LiveConsole.ps1` supports both local and `-RemoteDataRoot` read-only operation.

The Remote RCON console sends BOIII RCON commands over UDP. Its password is stored locally with Windows DPAPI for the Windows account that created it.

For supported PinteMod commands, GSC can also publish non-secret structured feedback under:

```text
boiii/scriptdata/pintemod/remote/feedback.latest.txt
```

The Remote RCON tool reads this through the existing **read-only LAN data share**. No additional public port is required.

Currently structured feedback is connected to:

```text
ezzpausestatus
```

Example:

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

Safe RCON commands are also written to a **local operator-PC audit**:

```text
runtime/PinteMod_Remote_RCON.audit.log
```

Commands containing password/secret/token keywords are not journaled. Input containing the active RCON password is refused locally instead of being sent to BOIII.

### Pause events in Live Console

The Remote Live Console reads the shared PinteMod runtime data read-only and can display compact operator events such as:

```text
[RCON] SEND | ezzpausestatus
[PAUSE] STATUS | active=true | remaining 137s | pauses 1/2 | proposals 1
[PAUSE] VOTE START | pause | PlayerName | majority 2/3 | 20s
[PAUSE] VOTE PASSED | pause | PlayerName | YES 2/3 | NO 0 | Majority approval
[PAUSE] ACTIVE | max 180s | ...
[PAUSE] RESUMED | automatic 180-second timeout | ...
```

Normal operator output avoids exposing full XUID values. Technical details remain available in source logs/diagnostics when needed.

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

Custom maps may load the generic framework, but map-specific unlocks, weapons, music, events, quest profiles and Soft Pause behavior are not guaranteed.

## Installation

For the stable v2.1.1 package:

1. fully stop BOIII and every PinteMod tool;
2. back up `boiii/custom_scripts/` and `boiii/scriptdata/pintemod/`;
3. remove old PinteMod scripts from `boiii/custom_scripts/` to avoid duplicate modules;
4. extract the archive directly into the directory that already contains `boiii` and `zone`;
5. confirm that your BOIII environment provides every required BOIII compatibility component;
6. run `Verify_PinteMod_Installation.bat` and resolve every `ERROR`;
7. run `Launch_PinteMod_Server.bat` from the `UnrankedServer` root;
8. on first launch, configure the local RCON password and real BOIII launcher;
9. run `Test_PinteMod_v2.1.1.bat`, then complete grouped server validation before public use.

Expected stable layout:

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

The experimental pause module is an additional post-v2.1.1 file and must not be presented as part of the frozen stable module count until it is formally integrated.

## Launch modes

### Local all-in-one

```text
Launch_PinteMod_Server.bat
```

Recommended when BOIII, Ban Service, GeoIP and Live Console run on the same machine.

The supervisor watches BOIII and child tools, blocks duplicate instances, logs failures and shuts down owned tools when BOIII stops.

### Server only

```text
Launch_PinteMod_Server_Only.bat
```

Starts BOIII without GeoIP, Ban Service or Live Console. Health diagnostics report those tools as absent/configured-not-active as appropriate.

### Stable remote-tools host

```text
Launch_PinteMod_Remote_Tools.bat
```

Starts the stable v2.1.1 Windows tools from another Windows host with the required RCON and filesystem access.

### Experimental LAN operator control pack

```text
boiii/tools/Launch_PinteMod_Remote_Control.bat
```

This is the newer operator-PC workflow used when the dedicated BOIII server stays on another machine. It opens:

1. a read-only Remote Live Console;
2. an interactive Remote RCON console.

Keep SMB and RCON restricted to a trusted LAN/VPN. **Never expose TCP 445/SMB to the Internet.**

## Default Owner

The public package contains one bootstrap Owner:

```text
Display metadata: BiereFraiche
BOIII_XUID: 9cf34426f668fb8b
Role: owner
```

No Admin, Moderator or Helper is preconfigured.

Other server owners should replace/remove the bootstrap XUID in `boiii/custom_scripts/ezz_admin_config.gsc`, or assign their persistent Owner using the supported dedicated-console identity commands.

## Stable identity and secure targeting

Authentication, permissions, language preferences, moderation, bans and persistent records use the stable hexadecimal XUID exposed by BOIII.

Connected targets may use:

```text
<PlayerName|BOIII_XUID|ClientNumber>
```

Display names are a convenience/display field only. If a name is ambiguous, PinteMod requires an XUID or client number.

Chat/menu actions internally transport stable selectors rather than trusting raw display names. Unsafe command separators and line breaks are rejected before server command execution.

## Roles

| Level | Role | Typical access |
|---:|---|---|
| 4 | Owner | Full access, role management, protected resets and actions against lower roles |
| 3 | Admin | Moderation of lower roles, maps, rounds, Events and server maintenance |
| 2 | Moderator | Routine gameplay administration |
| 1 | Helper | Limited assistance and diagnostics |
| 0 | User | Public menu, votes, Late Join, language, ranks and public records |

Hierarchy rules:

- a role cannot sanction an equal or higher role;
- self-sanction is rejected;
- the bootstrap Owner is protected;
- denied attempts are logged;
- display names are never persistence keys.

Persistent roles live under:

```text
boiii/scriptdata/pintemod/identity/roles.json
```

## Chat commands

The primary prefix is `.`. Legacy prefix `!` remains accepted.

Public examples:

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

Role-filtered diagnostics/statistics include:

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

Role-filtered moderation includes:

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

The full stable console reference remains in `docs/COMMANDES_CONSOLE_FR.txt`.

## Menu

Open the stable HUD menu with:

```text
.menu
```

HUD controls:

- **Action Slot 2 / key 2:** move up;
- **Action Slot 3 / key 3:** move down;
- **Use / Reload:** select;
- **Melee:** back or close.

Sections include Community/Players, Administration, Moderation, Perks, Weapons, Rounds, Power-Ups, Fun and Ranks & Records.

The experimental Soft Pause has not yet been formally merged into the stable menu layer.

## Community features

Stable Community features include:

- Welcome HUD and public reminders;
- public Late Join through `.spawn` or Player Menu;
- administrative spectator respawn;
- Owner-only native revive for players in last stand;
- next-map vote without interrupting the current match;
- restart vote with warning;
- protected vote-kick with reconnect blocking;
- automatic map change after the match;
- XUID-based presence tracking across reconnect/name changes;
- connection, vote and moderation reports.

Experimental post-v2.1.1 Community work adds:

- majority-based pause vote;
- early-resume vote;
- XUID proposal quota;
- two-successful-pause cap;
- automatic 180-second resume;
- periodic availability reminder;
- pause-aware PinteMod spectator respawn guards.

### Spawn, respawn and revive

These remain separate:

- `ezzjoin` / `.spawn`: public Late Join for an eligible spectator;
- `ezzspawn`: administrative spectator respawn;
- `ezzrevive`: native last-stand revive; Chat/menu access is Owner-only.

During an active experimental Soft Pause, both PinteMod spectator respawn paths are refused until gameplay resumes.

## Persistent XUID bans

The stable v2.1.1 ban system uses XUID persistence and a shared moderation hierarchy.

Main console actions include mute, unmute, kick, temporary/permanent bans, unban, ban information and player history.

Local runtime data lives under:

```text
boiii/scriptdata/pintemod/bans/
boiii/scriptdata/pintemod/moderation/
```

No IP address is intentionally stored by the PinteMod ban/history system.

Real second-account moderation validation remains deferred where already documented.

## Localization and GeoIP

Fully integrated languages:

```text
fr  Français
en  English
es  Español
```

Manual language choice has priority over GeoIP and is restored by XUID:

```text
.lang fr
.lang en
.lang es
.lang auto
```

The GeoIP bridge temporarily reads connection addresses through RCON, resolves country/language in memory and does not persist those addresses in PinteMod data.

Aggregate statistics are available through `ezzlangstats`.

## Ranks & Records

Ranks use:

```text
boiii/scriptdata/pintemod/ranks_v2/
```

Features include:

- playtime/session statistics by XUID;
- best round/global activity position;
- Top 5 records per map and 1P/2P/3P/4P category;
- presence eligibility;
- round-first/time-second tie breaking;
- connected and eligible-disconnected participant handling by XUID;
- automatic UNRANKED protection after gameplay-affecting administration;
- rollback of records created earlier in the same match where applicable;
- audit, backup and protected reset commands.

Public commands:

```text
.rank
.ranks
.record
.records [1-4]
```

No legacy display-name database is used as a persistence identity.

## Easter Egg Records

EE storage uses:

```text
boiii/scriptdata/pintemod/easter_eggs_v2/
```

The structural system tracks diagnostic/official candidates by stable identities, elapsed time, team category, eligibility and anti-duplicate signatures.

Official writes remain controlled per map. A detector must be validated on a real server before official writes are enabled for that map.

Soft Pause is not claimed to freeze Easter Egg script timers.

## Safe JSON storage

Identity, Ranks and EE registries use protected write/verify/recovery logic with temporary and backup files.

Invalid protected JSON can be preserved under the configured corruption-backup area, and valid backups can be restored when available.

## Managed logs and privacy

Stable session logs are grouped below:

```text
boiii/scriptdata/pintemod/logs/
```

Experimental pause adds:

```text
boiii/scriptdata/pintemod/logs/pause.log
```

Remote structured feedback adds:

```text
boiii/scriptdata/pintemod/remote/feedback.latest.txt
```

The feedback file contains status data only. It must never contain the RCON password.

Normal operator views should avoid exposing full XUIDs unless diagnostics explicitly require them.

## Read-only Live Console

The stable Live Console remains a read-only monitoring tool: it reads files and does not itself become an RCON administration client.

Stable capabilities include:

- dark presentation;
- active map/session detection;
- Chat/command separation;
- connection/Community/vote/moderation/Rank/EE/Storage/Localization streams;
- player dashboard;
- no IP/GUID display;
- filters, search and exports;
- service/supervisor error tracking.

The experimental remote variant additionally reads:

```text
logs/pause.log
runtime/PinteMod_Remote_RCON.audit.log
```

and converts them into compact `[PAUSE]` / `[RCON]` operator events.

## Shared registries

`ezz_admin_registry.gsc` centralizes map metadata, aliases, command roles and gameplay-impact metadata.

`ezz_admin_map_audit.gsc` provides a conservative active-map capability report.

Experimental Pause currently stays outside the stable registry/module integration until the prototype is formally merged.

## Validation status

### v2.1.0 / v2.1.1 stable foundations

Validated real-server foundations include:

```text
Global stable module loading        PASS
XUID identity and Owner role        PASS
Protected storage                   PASS
Chat and menu                       PASS
Community / Spawn / Late Join       PASS
FR / EN / ES localization           PASS
GeoIP without PinteMod IP storage   PASS
Ranks & Records                     PASS
Easter Egg Records structure        PASS
Maps, music and events              PASS
Perks / power-ups / rounds          PASS
Weapons / Zombies                   PASS
Persistent RCON                     PASS
Chat/command separation             PASS
Installation verifier              PASS
Health full                         PASS
Dark Live Console                   PASS
ezzv211test suite                   PASS — 88/88
```

Second-account moderation remains deferred where already documented.

### Experimental Community Soft Pause

Real-server tested successfully for the tested scenarios:

```text
10-second prototype                PASS
180-second real-time timeout       PASS
player freeze                      PASS
temporary invulnerability          PASS
Origins giant stomp protection     PASS (tested scenario)
AI spawn block                     PASS
ezzspawn block during pause        PASS
ezzjoin block during pause         PASS
early resume                       PASS
Community pause workflow           PASS
Remote ezzpausestatus feedback     PASS
Pause events in Remote LiveConsole PASS
```

The periodic v0.3 reminder still needs a quick real-server load/display confirmation before being marked validated.

## Known limitations

- Soft Pause is not a true engine pause;
- map/EE/trap/timed script threads may continue during Soft Pause;
- map-specific Soft Pause behavior is not claimed on every official/custom map;
- native EE completion signals are not validated on every map;
- second-account moderation behavior remains deferred where documented;
- BOIII may print native `status` data in its own console;
- remote deployment requires deliberate LAN/VPN/firewall/share configuration;
- **never expose SMB/TCP 445 to the Internet**;
- DPAPI secrets are machine/account-specific;
- structured Remote RCON feedback is currently implemented only for selected PinteMod status commands, beginning with `ezzpausestatus`;
- noclip is not presented as fixed;
- no AFK command is included;
- no round-transition lock is included;
- custom maps require their own validation/profile work.

## Public package contents

Stable v2.1.1 remains organized around:

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

Post-v2.1.1 experimental source adds or updates:

```text
boiii/custom_scripts/ezz_admin_pause_community_experimental.gsc
boiii/tools/Launch_PinteMod_Remote_Control.bat
boiii/tools/PinteMod_Remote_Control.ps1
boiii/tools/PinteMod_Remote_RCON.ps1
boiii/tools/PinteMod_LiveConsole.ps1
boiii/tools/TUTO_PINTE_MOD_REMOTE_LAN_FR.txt
```

## Local-only files

Never publish runtime/private state such as:

```text
zone/pintemod_server_secrets.cfg
boiii/tools/*.local.json
boiii/tools/*.secret.txt
boiii/tools/runtime/
boiii/scriptdata/pintemod/
server-specific configuration
```

The `boiii/tools/runtime/` directory, `boiii/tools/*.local.json` files and Remote RCON DPAPI secret are also local-only.

## License

Copyright © 2026 BiereFraiche.

PinteMod is licensed under the **GNU General Public License version 3**. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

This license covers PinteMod's own source. It does not grant rights to Call of Duty: Black Ops III, BOIII/Ezz or external proprietary components.
