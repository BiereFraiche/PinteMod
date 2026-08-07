# PinteMod v2.1.1 architecture

## Principles

PinteMod is a server-side BOIII Zombies framework. GSC runtime modules stay in
`boiii/custom_scripts/`. Windows operator tools stay in `boiii/tools/`. Principal
launchers stay at `UnrankedServer/` root. Player identity, roles, moderation,
languages, ranks and records use BOIII XUID; display names are metadata only.

The public package never contains runtime data or local secrets.

## Runtime layers

### 1. Foundation

- `ezz_admin_00_banner.gsc`: release banner.
- `ezz_admin_01_main.gsc`: Core lifecycle and module bootstrap state.
- `ezz_admin_config.gsc`: public defaults and single bootstrap Owner.
- `ezz_admin_storage.gsc`: session logs, protected JSON writes, backup/recovery.
- `ezz_admin_identity.gsc`: XUID normalization, selectors and persistent roles.
- `ezz_admin_registry.gsc`: maps, aliases, command roles and gameplay metadata.

### 2. Player-facing services

- `ezz_admin_chat.gsc`: Chat router and permission gate.
- `ezz_admin_menu.gsc`: localized HUD menu and safe target selectors.
- `ezz_admin_community.gsc`: votes, presence, Spawn/Late Join.
- `ezz_admin_localization.gsc`: FR/EN/ES, manual preference and GeoIP requests.
- `ezz_admin_langstats.gsc`: aggregate language counters and country summary.

### 3. Security and moderation

- `ezz_admin_bans.gsc`: request/response bridge for persistent XUID bans.
- `ezz_admin_moderation.gsc`: hierarchy, mute state, kick and player history.
- `PinteMod_Ban_Service.ps1`: UTC expiration, active markers and ban history.

The hierarchy is always checked against the actor and target XUID roles:
Owner > Admin > Moderator > Helper > User. Equal/higher targets, self-actions
and the bootstrap Owner are refused and logged.

### 4. Gameplay modules

Maps, Music, Events, Navigation, Commands, Perks, Power-Ups, Rounds, Weapons
and Zombies remain separate modules to reduce regression risk.

### 5. Competitive data

- `ezz_admin_ranks.gsc`: ranks and round records.
- `ezz_admin_ee_records.gsc`: EE profiles and records.
- Origins is the only EE profile enabled for official writes in this package.

### 6. Quality diagnostics

- `ezz_admin_health.gsc`: safe GSC/external-tool status.
- `ezz_admin_map_audit.gsc`: declared compatibility for the active map.
- `ezz_admin_validation.gsc`: grouped non-destructive runtime test suite.
- `Verify_PinteMod_Installation.ps1`: Windows installation and privacy audit.

## External tool communication

GSC and Windows tools communicate only through files under local
`boiii/scriptdata/pintemod/`:

```text
health/*.json                     non-secret heartbeats
localization/requests/*.json      XUID + client slot, never an IP
localization/responses/*.json     XUID + language + country labels
localization/stats/*               aggregate counters only
bans/requests/*.json               XUID moderation request
bans/responses/*.json              request result
moderation/history/*.json          aggregate action history per XUID
logs/sessions/*                    managed session logs
```

GeoIP temporarily reads player addresses from an RCON status response in
memory. It does not write those addresses to disk. Heartbeats contain only tool,
version, state, sequence, UTC timestamp and a non-sensitive error code.

## Launcher process model

`Launch_PinteMod_Server.bat` starts the Supervisor hidden. The Supervisor:

1. verifies local RCON/DPAPI coherence;
2. starts Ban Service hidden;
3. starts the existing BOIII launcher visibly;
4. starts GeoIP hidden;
5. starts Live Console visibly;
6. monitors BOIII and child tools;
7. logs failures and writes a heartbeat;
8. terminates owned child tools when BOIII stops.

No tool is an interactive RCON administration console. Live Console remains
read-only and only tails local logs.

## Custom map extension

A custom map can register a profile through:

```gsc
ezz_admin_map_audit::register_custom_map_profile(profile);
```

The example in `docs/examples/custom_map_profile.example.gsc` is documentation,
not runtime code. It has no `autoexec` and is never loaded from `docs/`.

## Public/private boundary

Public source:

```text
README*, LICENSE, SECURITY, THIRD_PARTY_NOTICES, CHANGELOG, SHA256SUMS
Launch_*.bat, Verify_*.bat, Test_*.bat
boiii/custom_scripts/*.gsc
boiii/tools/*.ps1, *.bat, *.example.json, .gitignore
docs/**
```

Private local state:

```text
zone/pintemod_server_secrets.cfg
boiii/tools/*.local.json
boiii/tools/*.secret.txt
boiii/tools/runtime/
boiii/scriptdata/
server_zm.cfg and other server-specific configuration
hotfix.gsc (legacy BOIII compatibility file; obsolete on BOIII v2.0.0 and never distributed by PinteMod)
```
