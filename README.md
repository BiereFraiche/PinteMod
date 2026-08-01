# PinteMod v2.0.0


PinteMod is a server-side administration, community and records framework for **Call of Duty: Black Ops III Zombies** dedicated servers running **BOIII/Ezz**.

Created and maintained by **BiereFraiche**, with development assistance from ChatGPT.

Players do not need to install a client mod. The framework is loaded from the dedicated server's `boiii/custom_scripts/` directory.

## Highlights in v2.0.0

- Stable permissions and persistent data keyed by `BOIII_XUID`
- Internal Chat and menu targeting transported by XUID or numeric client slot
- Duplicate display names rejected instead of silently selecting one player
- Dangerous command separators rejected before `executecommand()`
- Safe JSON writes with temporary validation, `.bak` recovery and corrupt-file quarantine
- Session-based managed logs with size rotation and configurable privacy
- Read-only Live Console with filters, search, export, error highlighting and session archives
- Persistent Ranks & Records on a clean XUID database
- Easter Egg candidate and record storage on an isolated clean XUID database
- Owner-only native revive command from Chat/menu
- Shared map registry and shared Chat command permission metadata
- 14 official BO3 Zombies map profiles
- 123 dedicated-server console commands

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

1. Fully stop the dedicated server.
2. Back up the existing `boiii/custom_scripts/` and `boiii/scriptdata/pintemod/` folders.
3. Remove old PinteMod scripts to prevent duplicate modules.
4. Copy the package's `custom_scripts/` directory into the server's `boiii/` directory.
5. Keep `tools/` beside `boiii/` when using the Live Console.
6. Edit `boiii/custom_scripts/ezz_admin_config.gsc`.
7. Replace or remove the bundled Owner XUID before opening another public server.
8. Fully restart the server and run the recommended installation verification.

Expected layout:

```text
<server root>/
├── boiii/
│   └── custom_scripts/
│       ├── ezz_admin_00_banner.gsc
│       ├── ezz_admin_01_main.gsc
│       ├── ...
│       ├── ezz_admin_registry.gsc
│       └── ezz_admin_storage.gsc
└── tools/
    ├── Launch_PinteMod_LiveConsole.bat
    └── PinteMod_LiveConsole.ps1
```

`hotfix.gsc` is intentionally not included. It belongs to the BOIII compatibility environment, not to PinteMod.

See [`docs/INSTALLATION_FR.txt`](docs/INSTALLATION_FR.txt) for the detailed French procedure.

## Default Owner

The public package contains one bootstrap Owner:

```text
Display metadata: BiereFraiche
BOIII_XUID: 9cf34426f668fb8b
Role: owner
```

No Admin, Moderator or Helper is preconfigured. No `roles.json`, player profile, record, sanction, vote, log or server backup is distributed.

Other server owners must replace or remove that XUID in `ezz_admin_config.gsc`, or assign their own persistent Owner from the dedicated console:

```text
ezzidsetrole <PlayerName|BOIII_XUID|ClientNumber> owner
```

## Stable identity and secure targeting

Authentication and persistent data use the hexadecimal value returned by BOIII's stable XUID interface.

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

Display names are only an unambiguous fallback. When two connected players share the same name, PinteMod refuses the name selector and requires XUID or client number.

Chat and menu actions do not place raw player names in internal command strings. They pass the stable XUID, or the numeric client slot when an XUID is unavailable. Vote-kick uses `clientkick <client number>` at execution time.

Quotes, semicolons and line breaks are rejected from internal command text and vote-kick reasons.

## Roles

| Level | Role | Typical access |
|---:|---|---|
| 4 | Owner | Permission management, revive, protected maintenance |
| 3 | Admin | Maps, rounds, unlocks, Events and server-impact commands |
| 2 | Moderator | Gameplay administration, weapons, perks and points |
| 1 | Helper | Read-only diagnostics and limited player assistance |
| 0 | User | Public menu, votes, late join, ranks and public records |

Persistent runtime role changes are stored in:

```text
boiii/scriptdata/pintemod/identity/roles.json
```

## Chat commands

The primary prefix is `.`. The legacy `!` prefix remains accepted.

Public examples:

```text
.menu
.spawn
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
```

The complete dedicated-console reference is in [`docs/COMMANDES_CONSOLE_FR.txt`](docs/COMMANDES_CONSOLE_FR.txt).

## Menu

Open the menu with:

```text
.menu
```

Controls:

- **Action Slot 2 / key 2:** move up
- **Action Slot 3 / key 4:** move down
- **Use / Reload:** select
- **Melee:** back or close

Sections include:

- Community / Players
- Administration
- Perks
- Weapons
- Rounds
- Power-Ups
- Fun
- Rankings & Records

Menu content is filtered by role and active map. Internal target values are XUID/client selectors; display names are labels only.

## Community features

- Welcome HUD and public reminders
- Public late join through `.spawn` or Player Menu
- Administrative respawn
- Owner-only native revive for players in last stand
- Next-map vote without interrupting the current match
- Restart vote with warning
- Protected vote-kick with XUID-bound cooldowns and map-level reconnect block
- Automatic map change after the match
- Presence tracking that survives reconnects/name changes during the map
- Live connection, vote and moderation reports

### Spawn, respawn and revive

These are different operations:

- `ezzjoin` / `.spawn`: public late join for an eligible spectator
- `ezzspawn`: administrative spectator respawn
- `ezzrevive`: native last-stand revive; Chat/menu access is Owner-only

## Ranks & Records

Ranks use the isolated v2 storage root:

```text
boiii/scriptdata/pintemod/ranks_v2/
```

Features:

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

The structural system records diagnostic candidates with:

- completion XUIDs
- active holder XUIDs
- excluded participants
- elapsed time and player category
- ranked/unranked status
- acceptance/rejection reason
- anti-duplicate signature

Official writes are controlled **per map**. A profile remains `DIAGNOSTIC` until its native quest-completion signal is confirmed on a real server by completing that map's main quest.

Useful commands:

```text
ezzeestatus
ezzeemaps
ezzeeplayers
ezzeetest suite
ezzeeaudit
ezzeecandidates <map>
ezzeevalidate <map> confirm
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

A valid `.bak` is restored when available. The runtime uses the file helpers exposed by the BOIII environment; this is a recoverable two-phase strategy rather than a filesystem-level atomic rename.

Diagnostics:

```text
ezzstoragestatus
ezzstoragetest suite
```

## Managed logs and privacy

Configuration defaults:

```gsc
level.pintemod_log_chat_messages = false;
level.pintemod_log_xuids = true;
level.pintemod_log_guids = false;
level.pintemod_log_max_size_kb = 2048;
```

Logs are grouped by map/session:

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
│   ├── chat/
│   └── votekick/
└── archive/YYYY-MM-DD/       # created by the Live Console
```

Each managed log file receives a session/map header. Files rotate when they exceed the configured size. Normal Chat messages are not persisted by default; command, moderation, identity, record and diagnostic events remain available. XUID and GUID redaction settings are applied centrally to managed log text.

## Read-only Live Console

Run:

```text
tools\Launch_PinteMod_LiveConsole.bat
```

The Live Console:

- detects the active PinteMod map/session manifest
- shows a startup summary and inferred connected players
- follows Chat, joins, Community, votes, kicks, Identity, Ranks, EE, Menu and Storage logs
- highlights failures, corrupt data, unresolved externals, clientfield mismatches and hitch warnings
- highlights records, candidates, Owner/Admin identities, UNRANKED and rollback events
- filters by category
- searches displayed lines
- opens the active log folder
- exports the visible session to `tools/exports/`
- optionally plays a short sound for critical errors
- archives completed sessions by operating-system date
- never sends a command to the game server

Keyboard help is displayed at startup and with `H`.

## Shared registries

`ezz_admin_registry.gsc` centralizes:

- official map codes and display names
- map aliases and collection names
- main-quest presence and minimum EE player counts
- Chat command minimum roles
- gameplay-impact metadata used by the framework

This removes the most error-prone duplicated map/permission tables while keeping the already validated large Community, Ranks, Menu and EE modules intact for v2.0.0.

Diagnostics:

```text
ezzregistrystatus
```

## Post-installation validation

Run these from the dedicated-server console after joining a match:

```text
ezztest
ezzidentity BiereFraiche
ezzidentitytest suite BiereFraiche
ezzstoragestatus
ezzstoragetest suite
ezzregistrystatus
ezzcommunitytest suite BiereFraiche
ezzrevivetest suite BiereFraiche
ezzranktest suite BiereFraiche
ezzeetest suite
ezzeeaudit
```

Expected grouped results:

```text
Identity: 19/19 PASS
Storage: 10/10 PASS
Community: 20/20 PASS
Revive: 10/10 PASS
Ranks: 17/17 PASS
EE: 20/20 PASS
EE audit: 9/9 passed
```

These suites were validated on a real dedicated BOIII server. Running them after installation remains recommended to confirm the local environment.

## Known limitations

- Native EE completion signals are not yet validated on every map.
- Noclip is intentionally unavailable.
- AFK commands are intentionally excluded.
- Round-transition locking is intentionally excluded.
- Custom maps require their own profiles.
- GSC cannot provide a true filesystem atomic rename; `.tmp` verification and `.bak` recovery mitigate interrupted writes.
- The Live Console requires Windows PowerShell and is optional.

## Package contents

```text
custom_scripts/             PinteMod runtime source
tools/                      Read-only Live Console
docs/                       Installation, commands, verification, EE and developer documentation
README.md                   English documentation
README_FR.md                Complete French documentation
SECURITY.md                 Security policy
THIRD_PARTY_NOTICES.md      Third-party notices
CHANGELOG_v2.0.0.txt        Release changelog
LICENSE                     GNU GPL version 3
SHA256SUMS.txt              File checksums
```

The `docs/` directory contains:

- `INSTALLATION_FR.txt`
- `COMMANDES_CONSOLE_FR.txt`
- `VERIFICATION_APRES_INSTALLATION_FR.txt`
- `VALIDATION_EE_FR.txt`
- `ARCHITECTURE.md`
- `AUDIT_VALIDATION_v2.0.0.txt`
- `FORUM_POST_FR.md`

## License

Copyright © 2026 BiereFraiche.

PinteMod is licensed under the **GNU General Public License version 3**. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

This licence covers PinteMod's own source. It does not grant rights to Call of Duty: Black Ops III, BOIII/Ezz or any external proprietary component.

### Chat log privacy

Normal player chat is not written to disk by default. Set `level.pintemod_log_chat_messages = true;` in `ezz_admin_config.gsc` only if you intentionally want the Live Console Chat filter and chat evidence in vote-kick reports. Commands, votes, joins, errors and administrative events remain logged. XUID logging is enabled by default; GUID logging is disabled.
